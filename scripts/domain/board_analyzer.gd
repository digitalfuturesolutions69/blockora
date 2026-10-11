class_name BoardAnalyzer
extends RefCounted

const MAX_SEARCH_NODES := 256
var _library: PieceLibrary

func _init(library: PieceLibrary = null) -> void:
	_library = library if library != null else PieceLibrary.new()

func placements(board: PuzzleBoard, piece: GamePiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if board == null or piece == null:
		return result
	var dimensions := piece.dimensions()
	for y in PuzzleBoard.SIZE - dimensions.y + 1:
		for x in PuzzleBoard.SIZE - dimensions.x + 1:
			var origin := Vector2i(x, y)
			if board.can_place(piece, origin):
				result.append(origin)
	return result

func evaluate(board: PuzzleBoard, piece: GamePiece, origin: Vector2i) -> Dictionary:
	if board == null or not board.can_place(piece, origin):
		return {"status": "invalid"}
	var candidate := PuzzleBoard.deserialize(board.serialize())
	return candidate.place_and_clear(piece, origin)

func fitting_shapes(board: PuzzleBoard) -> Array[String]:
	var result: Array[String] = []
	if board != null:
		for id in _library.ids():
			if board.has_move(_library.get_piece(id)):
				result.append(id)
	return result

func tray_summary(board: PuzzleBoard, tray: Variant) -> Dictionary:
	if board == null or not tray is Array or tray.size() != 3:
		return {"status": "invalid"}
	var counts: Array[int] = []
	var total := 0
	for id in tray:
		if not id is String or (not id.is_empty() and _library.get_piece(id) == null):
			return {"status": "invalid"}
		var count := placements(board, _library.get_piece(id)).size()
		counts.append(count)
		total += count
	return {"status": "ok", "counts": counts, "total": total, "game_over": total == 0}

func game_over_cause(board: PuzzleBoard, tray: Variant) -> String:
	var summary := tray_summary(board, tray)
	if summary.status != "ok":
		return "invalid"
	if not summary.game_over:
		return "active"
	return "board_exhausted" if fitting_shapes(board).is_empty() else "remaining_tray_blocked"

func sequential(board: PuzzleBoard, tray: Variant, budget: int = MAX_SEARCH_NODES) -> Dictionary:
	if board == null or not tray is Array or tray.size() != 3 or budget < 1 or budget > MAX_SEARCH_NODES:
		return {"status": "invalid", "nodes": 0, "witness": []}
	var pieces: Array[GamePiece] = []
	for id in tray:
		if not id is String or _library.get_piece(id) == null:
			return {"status": "invalid", "nodes": 0, "witness": []}
		pieces.append(_library.get_piece(id))
	var context := {"nodes": 0, "budget": budget, "exhausted": false, "path": []}
	var found := _search(board, pieces, 7, context)
	return {"status": "found" if found else ("budget_exhausted" if context.exhausted else "impossible"), "nodes": context.nodes, "witness": context.path if found else []}

func _search(board: PuzzleBoard, pieces: Array[GamePiece], remaining: int, context: Dictionary) -> bool:
	if remaining == 0:
		return true
	for slot in 3:
		if (remaining & (1 << slot)) == 0:
			continue
		for origin in placements(board, pieces[slot]):
			if context.nodes >= context.budget:
				context.exhausted = true
				return false
			context.nodes += 1
			var result := evaluate(board, pieces[slot], origin)
			context.path.append({"slot": slot, "origin": origin})
			if _search(PuzzleBoard.deserialize(result.board), pieces, remaining ^ (1 << slot), context):
				return true
			context.path.pop_back()
			if context.exhausted:
				return false
	return false
