extends SceneTree

func _initialize() -> void:
	var library := PieceLibrary.new()
	var square := library.get_piece("square2")
	var single := library.get_piece("single")
	var empty := PuzzleBoard.new()
	var occupied := PuzzleBoard.deserialize([1, 0, 0, 0, 0, 0, 0, 0])
	var accepted := 0
	var started := Time.get_ticks_usec()
	for index in 100000:
		if empty.can_place(square, Vector2i(6, 6)):
			accepted += 1
		if occupied.can_place(square, Vector2i.ZERO):
			accepted += 1
	var probe_us := Time.get_ticks_usec() - started
	var cleared := 0
	started = Time.get_ticks_usec()
	for index in 10000:
		var board := PuzzleBoard.deserialize([254, 1, 1, 1, 1, 1, 1, 1])
		cleared += board.place_and_clear(single, Vector2i.ZERO).unique_cleared_cells
	var clear_us := Time.get_ticks_usec() - started
	print("BENCHMARK: 200000 placement probes=%d us; 10000 deserialize+cross-clear=%d us; accepted=%d; cleared=%d (cloud CPU; not Android FPS)" % [probe_us, clear_us, accepted, cleared])
	quit(0 if accepted == 100000 and cleared == 150000 else 1)
