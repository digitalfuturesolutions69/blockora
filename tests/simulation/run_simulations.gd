extends SceneTree

var assertions := 0
var failures := 0
var moves := 0
var max_moves := 0
var library := PieceLibrary.new()

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		if failures <= 10:
			push_error("SIMULATION FAIL: " + label)

func first_move(session: ClassicSession) -> Array:
	var board := session.board()
	for slot in 3:
		var piece := session.piece_at(slot)
		if piece == null:
			continue
		for y in 8 - piece.dimensions().y + 1:
			for x in 8 - piece.dimensions().x + 1:
				if board.can_place(piece, Vector2i(x, y)):
					return [slot, Vector2i(x, y)]
	return []

func oracle(rows: Array, piece: GamePiece, origin: Vector2i) -> Dictionary:
	# Independent 64-cell boolean grid, not row-mask clearing logic.
	var grid: Array[bool] = []
	for y in 8:
		for x in 8:
			grid.append((rows[y] & (1 << x)) != 0)
	for cell in piece.cells():
		grid[(origin.y + cell.y) * 8 + origin.x + cell.x] = true
	var clear_rows: Array[int] = []
	var clear_columns: Array[int] = []
	for index in 8:
		var full_row := true
		var full_column := true
		for offset in 8:
			full_row = full_row and grid[index * 8 + offset]
			full_column = full_column and grid[offset * 8 + index]
		if full_row:
			clear_rows.append(index)
		if full_column:
			clear_columns.append(index)
	var removed := 0
	var result_rows: Array[int] = []
	for y in 8:
		var row := 0
		for x in 8:
			if grid[y * 8 + x] and (clear_rows.has(y) or clear_columns.has(x)):
				grid[y * 8 + x] = false
				removed += 1
			if grid[y * 8 + x]:
				row |= 1 << x
		result_rows.append(row)
	return {"board": result_rows, "rows": clear_rows, "columns": clear_columns, "removed": removed}

func _run() -> void:
	var count := 10000
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sessions="):
			count = argument.trim_prefix("--sessions=").to_int()
	if count < 1:
		push_error("Session count must be positive")
		quit(1)
		return
	var started := Time.get_ticks_msec()
	for seed_value in count:
		var session := ClassicSession.new(SeededPieceProvider.new(seed_value, library), library)
		var mirror: ClassicSession = ClassicSession.new(SeededPieceProvider.new(seed_value, library), library) if seed_value < 100 else null
		var session_moves := 0
		while not session.finished() and session_moves < 5000:
			var before := session.snapshot()
			check(session.place(0, Vector2i(-1, -1)).status == "invalid" and session.snapshot() == before, "illegal move cannot mutate")
			var action := first_move(session)
			check(not action.is_empty(), "nonterminal session has a move")
			if action.is_empty():
				break
			var piece := session.piece_at(action[0])
			var expected := oracle(before.board, piece, action[1])
			var result := session.place(action[0], action[1])
			check(result.status == "ok", "legal commit")
			check(result.board == expected.board and result.cleared_rows == expected.rows and result.cleared_columns == expected.columns and result.unique_cleared_cells == expected.removed, "simultaneous clear oracle")
			var lines: int = expected.rows.size() + expected.columns.size()
			var delta: int = piece.cell_count() + 10 * lines + 5 * lines * (lines - 1) + 5 * mini(int(before.combo), 5)
			check(session.score() == int(before.score) + delta and session.score() >= int(before.score), "score deterministic and never decreases")
			check(session.board().serialize().size() == 8 and PuzzleBoard.deserialize(session.board().serialize()) != null, "board always valid")
			for id in session.tray():
				check(id.is_empty() or library.get_piece(id) != null, "tray references exist")
			if mirror != null:
				mirror.place(action[0], action[1])
				check(mirror.snapshot() == session.snapshot(), "same seed/actions identical")
			if session_moves == 3 and seed_value < 100:
				mirror = ClassicSession.restore(session.snapshot())
				check(mirror != null, "resume replay restores")
			session_moves += 1
			moves += 1
		check(session.finished() and not session.has_remaining_move(), "ended only when all remaining shapes blocked")
		max_moves = maxi(max_moves, session_moves)
		if (seed_value + 1) % 1000 == 0:
			print("SIMULATION progress: %d/%d sessions, %d moves" % [seed_value + 1, count, moves])
			await process_frame
	var elapsed := Time.get_ticks_msec() - started
	print("SIMULATION RESULT: %d completed sessions, %d moves, %d assertions, %d failures, %d ms, longest=%d moves" % [count, moves, assertions, failures, elapsed, max_moves])
	quit(0 if failures == 0 else 1)
