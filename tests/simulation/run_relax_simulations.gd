extends "res://tests/simulation/run_simulations.gd"

var seed_value := 0
var snapshot_before := {}
var action: Array = []
var lengths: Array[int] = []
var scores: Array[int] = []
var fresh := 0
var violations := 0
var repairs := 0
var sampler_fallbacks := 0
var max_generation_us := 0

func check(ok: bool, label: String) -> void:
	if not ok: label += " seed=%d action=%s snapshot=%s" % [seed_value,str(action),JSON.stringify(snapshot_before)]
	super.check(ok,label)

func distribution(values: Array[int]) -> Dictionary:
	values.sort()
	var sum := 0
	for value in values: sum += value
	return {"min":values[0],"p50":values[(values.size()-1)/2],"p95":values[int((values.size()-1)*0.95)],"max":values[-1],"mean":float(sum)/values.size()}

func _run() -> void:
	library = RelaxPieceLibrary.new()
	var analyzer := BoardAnalyzer.new(library)
	var count := 10000
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sessions="): count = argument.trim_prefix("--sessions=").to_int()
	if count < 1: quit(1); return
	var started := Time.get_ticks_msec()
	for seed_index in count:
		seed_value = seed_index
		var provider := FairPieceProvider.new(seed_value,library)
		var session := ClassicSession.new(provider,library,ScoreRules.new(1,10,0,0,0),RelaxPolicy.RULESET)
		var mirror := RelaxPolicy.new_session(seed_value)
		var session_moves := 0
		while not session.finished() and session_moves < 5000:
			snapshot_before = session.snapshot()
			if not session.tray().has(""):
				fresh += 1
				if not analyzer.fitting_shapes(session.board()).is_empty() and analyzer.tray_summary(session.board(),session.tray()).game_over: violations += 1
				check(violations == 0, "fresh tray immediate fit")
			check(session.place(0,Vector2i(-1,-1)).status == "invalid" and session.snapshot() == snapshot_before,"invalid atomic")
			action = first_move(session)
			check(not action.is_empty(), "active session has action")
			if action.is_empty(): break
			var piece := session.piece_at(action[0])
			var expected := oracle(snapshot_before.board,piece,action[1])
			var result := session.place(action[0],action[1])
			check(result.status == "ok" and result.board == expected.board and result.cleared_rows == expected.rows and result.cleared_columns == expected.columns and result.unique_cleared_cells == expected.removed,"independent clear oracle")
			check(session.score() == int(snapshot_before.score)+piece.cell_count()+10*(expected.rows.size()+expected.columns.size()) and session.combo() == 0,"Relax scoring")
			check(mirror.place(action[0],action[1]).status == "ok" and mirror.snapshot() == session.snapshot(),"exact deterministic replay")
			check(session.finished() == not session.has_remaining_move(),"game over invariant")
			if session_moves == 3:
				mirror = RelaxPolicy.restore_json(JSON.stringify(RelaxPolicy.snapshot(session)))
				check(mirror != null and mirror.snapshot() == session.snapshot(),"JSON save resume")
				if mirror == null: break
			session_moves += 1
			moves += 1
			if failures > 0: break
		check(session.finished() and session_moves < 5000,"no simulation cap success")
		if failures > 0: break
		lengths.append(session_moves)
		scores.append(session.score())
		var diagnostic := provider.diagnostics()
		repairs += diagnostic.repairs
		sampler_fallbacks += diagnostic.sampler_fallbacks
		max_generation_us = maxi(max_generation_us,diagnostic.max_generation_us)
		if (seed_index+1)%1000 == 0: print("RELAX progress: ",seed_index+1); await process_frame
	var report := {"policy":RelaxPolicy.RULESET,"seed_range":"0..%d" % (count-1),"completed":lengths.size(),"requested":count,"moves":moves,"assertions":assertions,"failures":failures,"fresh_trays":fresh,"fairness_violations":violations,"repairs":repairs,"sampler_fallbacks":sampler_fallbacks,"session_lengths":distribution(lengths) if not lengths.is_empty() else {},"scores":distribution(scores) if not scores.is_empty() else {},"max_generation_us":max_generation_us,"elapsed_ms":Time.get_ticks_msec()-started}
	print("RELAX SIMULATION RESULT: ",JSON.stringify(report))
	quit(0 if failures == 0 and lengths.size() == count else 1)
