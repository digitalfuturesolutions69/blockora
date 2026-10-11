extends SceneTree

var checks := 0
var cases := 0
var failures := 0
var library := PieceLibrary.new()
var analyzer := BoardAnalyzer.new(library)

class RecordingProvider extends PieceProvider:
	var boards: Array = []
	func next_tray_for_board(board: PuzzleBoard) -> Array[String]:
		boards.append(board.serialize())
		return ["single", "single", "single"]
	func snapshot() -> Dictionary:
		return {"draws": boards.size()}
	func restore(value: Dictionary) -> bool:
		boards.resize(int(value.draws))
		return true

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIR PLAY FAIL: " + label)

func _run() -> void:
	cases += 1
	var board := PuzzleBoard.new()
	for id in library.ids():
		var piece := library.get_piece(id)
		var dimensions := piece.dimensions()
		check(analyzer.placements(board, piece).size() == (9-dimensions.x)*(9-dimensions.y), "empty board complete placement enumeration " + id)
	check(analyzer.tray_summary(board, ["single", "single", "single"]).total == 192, "slot-specific counts include duplicates")
	cases += 1
	board = PuzzleBoard.deserialize([254, 255, 255, 255, 255, 255, 255, 255])
	check(analyzer.placements(board, library.get_piece("single")) == [Vector2i.ZERO], "exactly one legal placement")
	check(analyzer.fitting_shapes(board) == ["single"], "only supported fitting shape")
	cases += 1
	board = PuzzleBoard.deserialize([255, 255, 255, 255, 255, 255, 255, 255])
	check(analyzer.fitting_shapes(board).is_empty(), "no catalog placement")
	check(analyzer.game_over_cause(board, ["single", "square2", "single"]) == "board_exhausted", "no-placement cause")
	var provider := FairPieceProvider.new(0, library)
	var tray := provider.next_tray_for_board(board)
	check(tray.size() == 3 and provider.diagnostics().repairs == 0, "exhausted board permits dead tray without reroll")
	cases += 1
	board = PuzzleBoard.deserialize([252, 252, 3, 3, 3, 3, 3, 3])
	var before := board.serialize()
	var result := analyzer.evaluate(board, library.get_piece("square2"), Vector2i.ZERO)
	check(result.cleared_rows == [0,1] and result.cleared_columns == [0,1] and result.unique_cleared_cells == 28, "simulation clears simultaneous four lines")
	check(result.board == [0,0,0,0,0,0,0,0] and board.serialize() == before, "analysis never mutates source")
	cases += 1
	board = PuzzleBoard.deserialize([254,253,251,247,239,223,191,127])
	before = board.serialize()
	check(analyzer.placements(board, library.get_piece("domino_h")).is_empty(), "horizontal piece initially blocked")
	check(analyzer.placements(board, library.get_piece("domino_v")).is_empty(), "vertical piece initially blocked")
	result = analyzer.sequential(board, ["domino_h", "domino_v", "single"])
	check(result.status == "found" and result.witness[0].slot == 2, "search permutes order and uses clears to open space")
	var replay := PuzzleBoard.deserialize(before)
	for action in result.witness:
		var ids := ["domino_h", "domino_v", "single"]
		check(replay.place_and_clear(library.get_piece(ids[action.slot]), action.origin).status == "ok", "witness executes live rules")
	check(board.serialize() == before, "lookahead does not mutate original")
	cases += 1
	check(analyzer.sequential(board, ["domino_h", "domino_v", "single"], 1).status == "budget_exhausted", "unknown is distinct from impossible")
	check(analyzer.sequential(PuzzleBoard.new(), ["single", "single", "single"], 3).status == "found", "exact budget boundary")
	board = PuzzleBoard.deserialize([170,85,170,85,170,85,170,85])
	result = analyzer.sequential(board, ["square2", "square2", "square2"])
	check(result.status == "impossible" and result.nodes == 0, "exhaustive zero-move proof")
	var bounded := analyzer.sequential(board, ["single", "single", "square2"])
	check(bounded.status == "budget_exhausted" and bounded.nodes == 256, "adversarial search reaches exact hard bound without claiming impossible")
	check(analyzer.game_over_cause(board, ["square2", "square2", "square2"]) == "remaining_tray_blocked", "blocked tray is not exhausted catalog")
	cases += 1
	for bad in [null, {}, [], ["missing","single","single"], [1,"single","single"]]:
		check(analyzer.tray_summary(board, bad).status == "invalid", "malformed tray rejected")
		check(analyzer.sequential(board, bad).status == "invalid", "malformed search rejected")
	for budget in [0,-1,257]:
		check(analyzer.sequential(board, ["single","single","single"], budget).status == "invalid", "search budget bounded")
	check(analyzer.evaluate(null, library.get_piece("single"), Vector2i.ZERO).status == "invalid", "null board rejected")
	check(analyzer.evaluate(board, null, Vector2i.ZERO).status == "invalid", "null shape rejected")
	check(analyzer.evaluate(board, library.get_piece("single"), Vector2i(-1,0)).status == "invalid", "boundary rejected")
	var state := provider.snapshot()
	check(provider.next_tray_for_board(null).is_empty() and provider.snapshot() == state, "invalid generation has no RNG side effects")
	cases += 1
	var a := FairPieceProvider.new(42, library)
	var b := FairPieceProvider.new(42, library)
	for _draw in 1000:
		var candidate := a.next_tray_for_board(board)
		check(candidate == b.next_tray_for_board(board) and a.snapshot() == b.snapshot(), "same board and seed reproduce repaired/unrepaired draws")
		check(not analyzer.tray_summary(board, candidate).game_over, "every generated checkerboard tray satisfies immediate-fit invariant")
	check(a.diagnostics().repairs > 0, "fallback path exercised")
	state = a.snapshot()
	tray = a.next_tray_for_board(board)
	check(b.restore(state) and b.next_tray_for_board(board) == tray, "repair RNG state resumes exactly")
	for bad in [{"algorithm":SeededPieceProvider.ALGORITHM,"state":1}, {"algorithm":SeededPieceProvider.ALGORITHM,"state":1,"policy":"unknown"}, {"algorithm":SeededPieceProvider.ALGORITHM,"state":0,"policy":FairPieceProvider.POLICY}]:
		state = b.snapshot()
		check(not b.restore(bad) and b.snapshot() == state, "invalid policy/RNG restore atomic")
	cases += 1
	# Randomized board enumeration and invariant, reproducible engine seed.
	var rng := RandomNumberGenerator.new()
	rng.seed = 982451653
	for _sample in 250:
		var rows: Array = []
		for _row in 8: rows.append(rng.randi_range(0,255))
		board = PuzzleBoard.deserialize(rows)
		var id: String = library.ids()[rng.randi_range(0,23)]
		var piece := library.get_piece(id)
		var positions := analyzer.placements(board, piece)
		for y in range(-1,9):
			for x in range(-1,9):
				check(positions.has(Vector2i(x,y)) == board.can_place(piece, Vector2i(x,y)), "enumeration equals live legality including boundaries")
		tray = a.next_tray_for_board(board)
		check(analyzer.fitting_shapes(board).is_empty() or not analyzer.tray_summary(board,tray).game_over, "randomized fresh tray immediate contract")
		check(board.serialize() == rows, "generation leaves random board unchanged")
	cases += 1
	var session := ClassicSession.new(FairPieceProvider.new(867))
	var save := session.snapshot()
	check(save.rng.policy == FairPieceProvider.POLICY and ClassicSession.restore(save).snapshot() == save, "new policy persisted exactly")
	save.rng.policy = "unsupported"
	check(ClassicSession.restore(save) == null, "unknown persisted policy rejected")
	var legacy := ClassicSession.new(SeededPieceProvider.new(867))
	check(not legacy.snapshot().rng.has("policy") and ClassicSession.restore(legacy.snapshot()).snapshot() == legacy.snapshot(), "legacy save remains legacy")
	cases += 1
	var recorder := RecordingProvider.new()
	session = ClassicSession.new(recorder, library)
	for x in 6:
		check(session.place(x % 3, Vector2i(x,0)).status == "ok", "refill fixture builds through legal moves")
	session.place(0, Vector2i(6,0))
	session.place(1, Vector2i(1,1))
	result = session.place(2,Vector2i(7,0))
	check(result.cleared_rows == [0], "last tray piece clears a line before refill")
	check(recorder.boards[-1] == [0,2,0,0,0,0,0,0] and recorder.boards[-1] == session.board().serialize(), "provider receives committed post-placement post-clear board")
	check(recorder.boards.size() == 4, "provider called only for whole batch refill")
	print("FAIR PLAY RESULT: %d cases, %d assertions, %d failures" % [cases,checks,failures])
	quit(0 if failures == 0 else 1)
