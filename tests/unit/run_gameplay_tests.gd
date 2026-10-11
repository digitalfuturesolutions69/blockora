extends SceneTree

const Storage = preload("res://scripts/infrastructure/json_local_storage.gd")
var checks := 0
var cases := 0
var failures := 0
var _case := ""
var library := PieceLibrary.new()

class FixedProvider extends PieceProvider:
	var draws := 0
	var bad_second := false
	func next_tray() -> Array[String]:
		draws += 1
		if bad_second and draws > 1:
			return ["missing"]
		return ["single", "single", "single"]
	func snapshot() -> Dictionary:
		return {"draws": draws}
	func restore(value: Dictionary) -> bool:
		draws = value.draws
		return true

class FailingStorage extends LocalStorageService:
	func write_record(_key: String, _value: Dictionary) -> Error:
		return ERR_CANT_CREATE
	func read_record(_key: String) -> Dictionary:
		return {"status": "missing", "data": {}}

func _initialize() -> void:
	_run.call_deferred()

func begin(name_value: String) -> void:
	cases += 1
	_case = name_value

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL [%s]: %s" % [_case, label])

func single() -> GamePiece:
	return library.get_piece("single")

func _run() -> void:
	_test_board()
	_test_pieces()
	_test_scoring()
	_test_generation_and_session()
	_test_state_machine()
	_test_persistence()
	print("GAMEPLAY RESULT: %d cases, %d assertions, %d failures" % [cases, checks, failures])
	quit(0 if failures == 0 else 1)

func _test_board() -> void:
	begin("empty board and boundaries")
	var board := PuzzleBoard.new()
	check(board.serialize() == [0, 0, 0, 0, 0, 0, 0, 0], "eight empty rows")
	for y in 8:
		for x in 8:
			check(board.read_cell(Vector2i(x, y)) == PuzzleBoard.CellState.EMPTY, "all 64 cells empty")
	for cell in [Vector2i(-1, 0), Vector2i(8, 7), Vector2i(0, 8), Vector2i(7, -1)]:
		check(board.read_cell(cell) == -1 and not board.can_place(single(), cell), "out of bounds rejected")
	check(board.can_place(single(), Vector2i(7, 7)), "last cell legal")
	begin("atomic legal placement and collision")
	check(board.place_and_clear(single(), Vector2i(7, 7)).status == "ok", "place last cell")
	check(board.read_cell(Vector2i(7, 7)) == PuzzleBoard.CellState.OCCUPIED, "last row/bit retained")
	var before := board.serialize()
	for piece in [single(), library.get_piece("square2"), null]:
		check(board.place_and_clear(piece, Vector2i(7, 7)).status == "invalid", "invalid rejected")
		check(board.serialize() == before, "invalid never partially places")
	check(not board.can_place(library.get_piece("line5_h"), Vector2i(4, 0)), "shape extending over edge")
	begin("board serialization and corrupt inputs")
	check(PuzzleBoard.deserialize(before).serialize() == before, "round trip")
	for bad in [null, {}, [], [0, 0, 0, 0, 0, 0, 0, -1], [0, 0, 0, 0, 0, 0, 0, 256], [0, 0, 0, 0, 0, 0, 0, 1.5], [true, 0, 0, 0, 0, 0, 0, 0], ["0", 0, 0, 0, 0, 0, 0, 0]]:
		check(PuzzleBoard.deserialize(bad) == null, "reject corrupt board")
	check(PuzzleBoard.deserialize([0.0, 0, 0, 0, 0, 0, 0, 128.0]) != null, "JSON integral number supported")
	begin("full row clear")
	board = PuzzleBoard.deserialize([127, 0, 0, 0, 0, 0, 0, 0])
	var result := board.place_and_clear(single(), Vector2i(7, 0))
	check(result.cleared_rows == [0] and result.cleared_columns.is_empty(), "row detected")
	check(result.unique_cleared_cells == 8 and result.board == [0, 0, 0, 0, 0, 0, 0, 0], "row removed")
	check(result.piece_id == "single" and result.placed_cells == 1, "structured placement metadata")
	begin("full column clear")
	board = PuzzleBoard.deserialize([128, 128, 128, 128, 128, 128, 128, 0])
	result = board.place_and_clear(single(), Vector2i(7, 7))
	check(result.cleared_columns == [7] and result.cleared_rows.is_empty(), "column detected")
	check(result.unique_cleared_cells == 8 and result.board == [0, 0, 0, 0, 0, 0, 0, 0], "column removed")
	begin("simultaneous cross clear")
	board = PuzzleBoard.deserialize([254, 1, 1, 1, 1, 1, 1, 1])
	result = board.place_and_clear(single(), Vector2i.ZERO)
	check(result.cleared_rows == [0] and result.cleared_columns == [0], "detect before clearing")
	check(result.unique_cleared_cells == 15, "intersection counted once")
	check(result.board == [0, 0, 0, 0, 0, 0, 0, 0], "cross union removed")
	begin("multiple rows and columns union")
	board = PuzzleBoard.deserialize([252, 252, 3, 3, 3, 3, 3, 3])
	result = board.place_and_clear(library.get_piece("square2"), Vector2i.ZERO)
	check(result.cleared_rows == [0, 1] and result.cleared_columns == [0, 1], "four simultaneous lines")
	check(result.unique_cleared_cells == 28, "four intersections removed once")
	check(result.board == [0, 0, 0, 0, 0, 0, 0, 0], "all lines removed")
	begin("legal move search")
	board = PuzzleBoard.deserialize([170, 85, 170, 85, 170, 85, 170, 85])
	check(board.has_move(single()), "single fits checkerboard")
	check(not board.has_move(library.get_piece("square2")), "square cannot fit checkerboard")
	check(not board.has_move(null), "null cannot fit")
	begin("placement boundary property")
	for id in library.ids():
		var piece := library.get_piece(id)
		for y in range(-1, 9):
			for x in range(-1, 9):
				board = PuzzleBoard.new()
				before = board.serialize()
				var expected := x >= 0 and y >= 0 and x + piece.dimensions().x <= 8 and y + piece.dimensions().y <= 8
				result = board.place_and_clear(piece, Vector2i(x, y))
				check((result.status == "ok") == expected, "bounds agreement")
				check(board.serialize().size() == 8, "dimensions invariant")
				if not expected:
					check(board.serialize() == before, "illegal property atomic")

func _test_pieces() -> void:
	begin("curated piece library validity")
	check(library.ids().size() == 24, "24 shapes")
	var unique := {}
	for id in library.ids():
		var piece := library.get_piece(id)
		check(piece != null and piece.cell_count() > 0, "valid connected normalized shape")
		check(not unique.has(id), "unique shape ID")
		unique[id] = true
		check(piece.dimensions().x <= 8 and piece.dimensions().y <= 8, "bounds")
		check(GamePiece.create(id, piece.cells()).cells() == piece.cells(), "canonical validation stable")
		check(library.matches_serialized(piece.serialize()), "piece serialization")
		var copy := piece.cells()
		copy.clear()
		check(piece.cell_count() > 0, "coordinates snapshot cannot alter piece")
	begin("invalid shape rejection")
	for coordinates in [[], [Vector2i.ZERO, Vector2i.ZERO], [Vector2i.ZERO, Vector2i(2, 0)], [Vector2i(1, 1)], [Vector2i(-1, 0)], [Vector2i(8, 0)], [[0.5, 0]], [Vector2(0, 0)]]:
		check(GamePiece.create("bad", coordinates) == null, "invalid coordinate/connectivity/origin rejected")
	check(GamePiece.create("", [Vector2i.ZERO]) == null, "empty shape id")
	check(GamePiece.create("a/b", [Vector2i.ZERO]) == null, "invalid shape id")
	check(not library.matches_serialized({"id": "single", "cells": [[1, 0]], "render_key": "mint"}), "changed serialized definition rejected")

func _test_scoring() -> void:
	var rules := ScoreRules.new()
	begin("no line clear score")
	var result := rules.event(4, 0, 0, 0)
	check(result.score == 4 and result.delta == 4 and result.combo == 0, "P only")
	begin("one line clear score")
	result = rules.event(3, 1, 0, 7)
	check(result.delta == 13 and result.score == 20 and result.combo == 1, "P + 10L")
	begin("simultaneous line bonuses")
	check(rules.event(4, 2, 0, 0).delta == 34, "two lines")
	check(rules.event(4, 4, 0, 0).delta == 104, "four lines")
	begin("combo progression and cap")
	var combo := 0
	for index in 9:
		result = rules.event(1, 1, combo, 0)
		check(result.delta == 11 + 5 * mini(index, 5), "pre-event combo bonus")
		check(result.combo == mini(index + 1, 5), "increase after scoring")
		combo = result.combo
	check(rules.event(1, 1, 99, 0).delta == 36, "large combo capped")
	check(rules.event(1, 1, -4, 0).combo == 1, "negative combo clamped")
	begin("combo reset")
	result = rules.event(3, 0, 3, 0)
	check(result.delta == 18 and result.combo == 0, "formula grants previous combo then resets on no clear")
	begin("score overflow saturation")
	result = rules.event(5, 4, 5, ScoreRules.MAX_SCORE - 2)
	check(result.score == ScoreRules.MAX_SCORE and result.delta == 2 and result.saturated, "saturates without wrap")
	check(rules.event(1, 0, 0, ScoreRules.MAX_SCORE).score == ScoreRules.MAX_SCORE, "max remains nonnegative")
	check(ClassicSession.parse_score(str(ScoreRules.MAX_SCORE)) == ScoreRules.MAX_SCORE, "decimal max parses")
	for bad in ["9223372036854775808", "-1", "1.2", "01", "", 3, "NaN"]:
		check(ClassicSession.parse_score(bad) == -1, "bad score rejected")
	begin("configurable scoring validation")
	check(ScoreRules.new(2, 20, 3, 4).event(2, 2, 1, 0).delta == 54, "configurable coefficients")
	check(ScoreRules.new(-1, -1, -1, -1).event(1, 1, 0, 0).delta == 0, "no negative score coefficient")
	for values in [[0, 0, 0, 0], [1, -1, 0, 0], [1, 17, 0, 0], [1, 0, 0, -1]]:
		check(rules.event(values[0], values[1], values[2], values[3]).status == "invalid", "invalid event rejected")

func _test_generation_and_session() -> void:
	begin("Park Miller reference vector")
	var reference := SeededPieceProvider.new(0, library)
	check(reference.next_tray() == ["line4_v", "single", "l4_top"], "known first three draws map to stable catalog")
	check(reference.snapshot().state == 1622650073, "third reference state")
	begin("seed reproducibility and exactly three")
	var a := SeededPieceProvider.new(42, library)
	var b := SeededPieceProvider.new(42, library)
	for index in 30:
		var tray := a.next_tray()
		check(tray.size() == 3 and tray == b.next_tray(), "same seed yields same ordered tray")
		for id in tray:
			check(library.get_piece(id) != null, "known ID only")
	begin("RNG restore and validation")
	var snapshot := a.snapshot()
	var next := a.next_tray()
	check(b.restore(snapshot) and b.next_tray() == next, "exact continuation")
	for bad in [{}, {"algorithm": "unknown", "state": 3}, {"algorithm": a.ALGORITHM, "state": 0}, {"algorithm": a.ALGORITHM, "state": 2147483647}, {"algorithm": a.ALGORITHM, "state": 1.2}]:
		check(not b.restore(bad), "bad state rejected")
	begin("tray consumption and batch replacement")
	var provider := FixedProvider.new()
	var session := ClassicSession.new(provider, library)
	check(provider.draws == 1 and session.tray().size() == 3, "initial batch")
	check(session.place(0, Vector2i.ZERO).status == "ok", "first piece consumed")
	check(session.tray() == ["", "single", "single"] and provider.draws == 1, "no individual refill")
	var before := session.snapshot()
	check(session.place(0, Vector2i(1, 0)).status == "invalid", "piece cannot be reused")
	check(session.snapshot() == before, "reused slot no mutation")
	session.place(1, Vector2i(1, 0))
	check(provider.draws == 1 and session.tray() == ["", "", "single"], "second piece no refill")
	session.place(2, Vector2i(2, 0))
	check(provider.draws == 2 and session.tray() == ["single", "single", "single"], "batch refill after third")
	begin("illegal session atomicity and snapshots")
	before = session.snapshot()
	for slot in [-1, 3, 99]:
		check(session.place(slot, Vector2i.ZERO).status == "invalid", "invalid slot")
	check(session.place(0, Vector2i.ZERO).status == "invalid", "collision")
	check(session.snapshot() == before, "score board RNG tray unchanged")
	var board_copy := session.board()
	board_copy.place_and_clear(single(), Vector2i(7, 7))
	check(session.snapshot() == before, "board snapshot independent")
	begin("provider failure transaction rollback")
	provider = FixedProvider.new()
	provider.bad_second = true
	session = ClassicSession.new(provider, library)
	session.place(0, Vector2i.ZERO)
	session.place(1, Vector2i(1, 0))
	before = session.snapshot()
	check(session.place(2, Vector2i(2, 0)).status == "provider_error", "unknown provider tray refused")
	check(session.snapshot() == before and provider.draws == 1, "board score tray RNG rollback")
	begin("game over checks every remaining piece")
	session = ClassicSession.new()
	var save := session.snapshot()
	save.board = [170, 85, 170, 85, 170, 85, 170, 85]
	save.tray = ["square2", "single", ""]
	session = ClassicSession.restore(save)
	check(session != null and not session.finished(), "single fits even when square does not")
	save.tray = ["square2", "line3_h", ""]
	save.session_status = "game_over"
	session = ClassicSession.restore(save)
	check(session != null and session.finished() and not session.has_remaining_move(), "all blocked ends game")
	before = session.snapshot()
	check(session.place(0, Vector2i.ZERO).status == "invalid" and session.snapshot() == before, "finished cannot mutate")
	begin("session save continuation")
	session = ClassicSession.new(SeededPieceProvider.new(867))
	var piece := session.piece_at(0)
	session.place(0, Vector2i.ZERO)
	var restored := ClassicSession.restore(session.snapshot())
	check(restored != null and restored.snapshot() == session.snapshot(), "all persisted domain fields round trip")
	check(piece != null and restored.piece_at(0) == null, "consumed slot preserved")
	begin("corrupt session semantic validation")
	var valid := ClassicSession.new().snapshot()
	for change in [{"schema_version": 2}, {"ruleset_version": "future"}, {"tray": ["single"]}, {"tray": ["missing", "single", "single"]}, {"tray": ["", "", ""]}, {"combo": -1}, {"combo": 5.5}, {"score": "bad"}, {"rng": {}}, {"session_status": "game_over"}, {"board": [255, 0, 0, 0, 0, 0, 0, 0]}]:
		var malformed := valid.duplicate(true)
		malformed.merge(change, true)
		check(ClassicSession.restore(malformed) == null, "malformed save rejected")

func _test_state_machine() -> void:
	begin("explicit lifecycle transition matrix")
	var machine := SessionStateMachine.new()
	check(machine.state() == SessionStateMachine.State.BOOT, "boot initial")
	check(not machine.transition(SessionStateMachine.State.PLAYING), "boot cannot play directly")
	check(machine.transition(SessionStateMachine.State.HOME), "boot to home")
	check(not machine.transition(SessionStateMachine.State.PAUSED), "home cannot pause")
	check(machine.transition(SessionStateMachine.State.PLAYING), "home to playing")
	check(machine.transition(SessionStateMachine.State.PAUSED), "pause")
	check(not machine.transition(SessionStateMachine.State.GAME_OVER), "paused cannot finish")
	check(machine.transition(SessionStateMachine.State.PLAYING), "resume")
	check(machine.transition(SessionStateMachine.State.GAME_OVER), "finish")
	check(not machine.transition(SessionStateMachine.State.PAUSED), "finished cannot pause")
	check(machine.transition(SessionStateMachine.State.PLAYING), "play again")
	check(machine.transition(SessionStateMachine.State.HOME), "return home")
	check(not machine.transition(999), "unknown state rejected")

func _test_persistence() -> void:
	var path := "user://phase1_unit_" + str(Time.get_ticks_usec())
	var storage := Storage.new(path)
	begin("controller lifecycle and inactive moves")
	var controller := ClassicController.new(storage)
	check(controller.state() == SessionStateMachine.State.HOME and not controller.can_resume(), "home starts empty")
	check(controller.place(0, Vector2i.ZERO).status == "inactive", "home cannot place")
	check(controller.new_game(19), "start")
	check(not controller.new_game(20), "no unconfirmed replacement while playing")
	check(controller.pause(), "pause")
	var before := controller.session().snapshot()
	check(controller.place(0, Vector2i.ZERO).status == "inactive", "paused move refused")
	check(controller.session().snapshot() == before, "paused immutable")
	check(controller.resume(), "resume paused")
	check(controller.home() and controller.resume(), "home resume same game")
	check(controller.session().snapshot() == before, "resume unchanged domain")
	begin("transaction persistence and independent best score")
	var move := controller.place(0, Vector2i.ZERO)
	check(move.status == "ok" and controller.best_score() == controller.session().score(), "best follows move")
	check(storage.read_record(ClassicController.SAVE_KEY).status == "ok", "session written")
	var saved := ClassicSession.restore(storage.read_record(ClassicController.SAVE_KEY).data)
	check(saved != null and saved.snapshot() == controller.session().snapshot(), "persist committed transaction")
	var reload := ClassicController.new(storage)
	check(reload.state() == SessionStateMachine.State.HOME and reload.can_resume(), "cold launch resume available")
	check(reload.session().snapshot() == controller.session().snapshot(), "cold launch exact RNG and board")
	check(reload.best_score() == controller.best_score(), "best independent reload")
	check(reload.resume(), "cold resume")
	begin("restart preserves best")
	var best := reload.best_score()
	reload.pause()
	check(reload.new_game(25), "restart accepted while paused")
	check(reload.session().score() == 0 and reload.best_score() == best, "new score reset best retained")
	begin("persistent settings")
	reload.set_preferences(false, false)
	var settings_reload := ClassicController.new(storage)
	check(settings_reload.preferences() == {"sound": false, "vibration": false}, "settings saved")
	begin("corrupt save recovery retains independent best")
	storage.write_record(ClassicController.SAVE_KEY, {"schema_version": 99})
	var recovered := ClassicController.new(storage)
	check(not recovered.can_resume() and recovered.session() == null, "corrupt session ignored")
	check(recovered.best_score() == best, "best survives corrupt session")
	check(not recovered.save_message().is_empty() and recovered.new_game(1), "notice and graceful new game")
	begin("controller game over transaction and play again")
	var fixture := ClassicSession.new().snapshot()
	fixture.board = [170, 85, 170, 85, 170, 85, 170, 85]
	fixture.tray = ["single", "square2", ""]
	storage.write_record(ClassicController.SAVE_KEY, fixture)
	var ending := ClassicController.new(storage)
	check(ending.resume(), "resume fixture")
	check(ending.place(0, Vector2i.ZERO).game_over, "final usable piece placed")
	check(ending.state() == SessionStateMachine.State.GAME_OVER, "controller enters game over")
	check(ending.place(1, Vector2i.ZERO).status == "inactive", "game over disables actions")
	check(ClassicSession.restore(storage.read_record(ClassicController.SAVE_KEY).data).finished(), "terminal state persisted")
	check(ending.new_game(9) and ending.state() == SessionStateMachine.State.PLAYING, "play again starts new session")
	begin("write failure surfaced")
	var failed := ClassicController.new(FailingStorage.new())
	check(failed.new_game(1), "can play when disk unavailable")
	check(not failed.save_message().is_empty(), "write failure visible")
	begin("large JSON record rejected")
	var oversized := FileAccess.open(path.path_join("oversized.json"), FileAccess.WRITE)
	oversized.store_string(" ".repeat(1048577))
	oversized.close()
	check(storage.read_record("oversized").status == "corrupt", "bounded record loading")
	for key in [ClassicController.SAVE_KEY, ClassicController.BEST_KEY, ClassicController.SETTINGS_KEY, "oversized"]:
		DirAccess.remove_absolute(path.path_join(key + ".json"))
	DirAccess.remove_absolute(path)
