extends "res://tests/simulation/run_simulations.gd"

var _seed := 0
var _before := {}
var _action: Array = []
var _legacy := false
var _shape_counts := {}
var _trays := 0

class TimedLegacyProvider extends SeededPieceProvider:
	var generated := 0
	var max_generation_us := 0
	func next_tray_for_board(_board: PuzzleBoard) -> Array[String]:
		var started := Time.get_ticks_usec()
		var result := next_tray()
		generated += 1
		max_generation_us = maxi(max_generation_us, Time.get_ticks_usec()-started)
		return result
	func diagnostics() -> Dictionary:
		return {"generated":generated,"repairs":0,"sampler_fallbacks":0,"max_generation_us":max_generation_us}
var _eligible := 0
var _contract_passes := 0
var _repairs := 0
var _sampler_fallbacks := 0
var _max_generation_us := 0
var _replay_success := 0
var _legal_counts: Array[int] = []
var _lengths: Array[int] = []
var _scores: Array[int] = []
var _causes := {}
var _analyzer := BoardAnalyzer.new(library)

func check(condition: bool, label: String) -> void:
	if not condition:
		label += " seed=%d action=%s snapshot=%s" % [_seed, str(_action), JSON.stringify(_before)]
	super.check(condition, label)

func _observe(session: ClassicSession) -> void:
	_trays += 1
	for id in session.tray(): _shape_counts[id] = _shape_counts.get(id,0)+1
	var board := session.board()
	var summary := _analyzer.tray_summary(board, session.tray())
	_legal_counts.append(summary.total)
	if not _analyzer.fitting_shapes(board).is_empty():
		_eligible += 1
		if not summary.game_over: _contract_passes += 1
		# Reference measurement has no immediate-fit promise; enforce it on fair runs.
		if not _legacy: check(not summary.game_over, "fresh tray immediate-fit contract")

func _distribution(values: Array[int]) -> Dictionary:
	values.sort()
	var total := 0
	for v in values: total += v
	return {"min":values[0],"p50":values[int((values.size()-1)/2.0)],"p95":values[int((values.size()-1)*0.95)],"max":values[-1],"mean":float(total)/values.size()}

func _run() -> void:
	var count := 10000
	var randomized := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sessions="): count = argument.trim_prefix("--sessions=").to_int()
		if argument == "--randomized": randomized = true
		if argument == "--legacy": _legacy = true
	if count < 1:
		push_error("Session count must be positive")
		quit(1)
		return
	var started := Time.get_ticks_msec()
	for seed_value in count:
		_seed = seed_value
		var initial_failures := failures
		var provider = TimedLegacyProvider.new(seed_value, library) if _legacy else FairPieceProvider.new(seed_value, library)
		var session := ClassicSession.new(provider, library)
		var mirror := ClassicSession.new(SeededPieceProvider.new(seed_value, library) if _legacy else FairPieceProvider.new(seed_value, library), library)
		var action_rng := RandomNumberGenerator.new()
		action_rng.seed = seed_value + 104729
		_before = session.snapshot()
		_action = []
		check(session.snapshot() == mirror.snapshot(), "initial same-seed replay")
		_observe(session)
		var session_moves := 0
		while not session.finished() and session_moves < 5000:
			_before = session.snapshot()
			check(session.place(0,Vector2i(-1,-1)).status == "invalid" and session.snapshot() == _before, "invalid move atomic including RNG")
			_action = first_move(session)
			if randomized:
				var choices: Array = []
				for slot in 3:
					for origin in _analyzer.placements(session.board(), session.piece_at(slot)):
						choices.append([slot, origin])
				if not choices.is_empty(): _action = choices[action_rng.randi_range(0,choices.size()-1)]
			check(not _action.is_empty(), "active session has legal move")
			if _action.is_empty(): break
			var piece := session.piece_at(_action[0])
			var expected := oracle(_before.board, piece, _action[1])
			var result := session.place(_action[0], _action[1])
			check(result.status == "ok", "legal move commits")
			check(result.board == expected.board and result.cleared_rows == expected.rows and result.cleared_columns == expected.columns and result.unique_cleared_cells == expected.removed, "independent boolean-grid clear oracle")
			var lines: int = expected.rows.size()+expected.columns.size()
			var delta: int = piece.cell_count()+10*lines+5*lines*(lines-1)+5*mini(int(_before.combo),5)
			check(session.score() == int(_before.score)+delta, "approved scoring unchanged")
			check(mirror.place(_action[0],_action[1]).status == "ok" and mirror.snapshot() == session.snapshot(), "same seed/actions exact replay")
			check(session.finished() == not session.has_remaining_move(), "live game-over invariant")
			if not session.tray().has(""): _observe(session)
			if session_moves == 3:
				# Real JSON numeric decoding, consumed slots and persisted policy.
				mirror = ClassicSession.restore(JSON.parse_string(JSON.stringify(session.snapshot())))
				check(mirror != null and mirror.snapshot() == session.snapshot(), "save/resume exact including next RNG state")
				if mirror == null: break
			session_moves += 1
			moves += 1
		check(session.finished() and session_moves < 5000, "session ends without simulation cap")
		var cause := _analyzer.game_over_cause(session.board(), session.tray())
		check(cause in ["remaining_tray_blocked","board_exhausted"], "game-over cause agrees with analyzer")
		_causes[cause] = _causes.get(cause,0)+1
		_lengths.append(session_moves)
		_scores.append(session.score())
		var diagnostics := provider.diagnostics()
		_repairs += diagnostics.repairs
		_sampler_fallbacks += diagnostics.sampler_fallbacks
		_max_generation_us = maxi(_max_generation_us, diagnostics.max_generation_us)
		if failures == initial_failures: _replay_success += 1
		if failures > 0:
			break # Fail fast with a reproducible seed/state; never pad completed count.
		if (seed_value+1)%1000 == 0:
			print("FAIR SIMULATION progress: %d/%d" % [seed_value+1,count])
			await process_frame
	var report := {"policy": "legacy_uniform_v1" if _legacy else FairPieceProvider.POLICY,"player":"random_legal" if randomized else "first_legal_slot_y_x","requested_sessions":count,"completed_sessions":_lengths.size(),"moves":moves,"assertions":assertions,"failures":failures,"fresh_trays":_trays,"eligible_trays":_eligible,"contract_passes":_contract_passes,"contract_percent":100.0*_contract_passes/maxi(1,_eligible),"generator_repairs":_repairs,"sampler_fallbacks":_sampler_fallbacks,"contract_violations":_eligible-_contract_passes,"shape_counts":_shape_counts,"legal_placements":_distribution(_legal_counts),"session_moves":_distribution(_lengths),"scores":_distribution(_scores),"game_over_causes":_causes,"replay_success":_replay_success,"max_generation_us":_max_generation_us,"elapsed_ms":Time.get_ticks_msec()-started}
	print("FAIR SIMULATION RESULT: ",JSON.stringify(report))
	quit(0 if failures == 0 and _lengths.size() == count else 1)
