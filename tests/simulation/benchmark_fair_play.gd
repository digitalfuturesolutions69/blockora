extends SceneTree

func _initialize() -> void:
	var analyzer := BoardAnalyzer.new()
	var provider := FairPieceProvider.new(0)
	var boards := [PuzzleBoard.new(), PuzzleBoard.deserialize([170,85,170,85,170,85,170,85]), PuzzleBoard.deserialize([254,253,251,247,239,223,191,127]), PuzzleBoard.deserialize([255,255,255,255,255,255,255,255])]
	var latencies: Array[int] = []
	var failures := 0
	for index in 10000:
		var board: PuzzleBoard = boards[index % boards.size()]
		var before := board.serialize()
		var started := Time.get_ticks_usec()
		var tray := provider.next_tray_for_board(board)
		latencies.append(Time.get_ticks_usec()-started)
		if board.serialize() != before or (not analyzer.fitting_shapes(board).is_empty() and analyzer.tray_summary(board,tray).game_over): failures += 1
	latencies.sort()
	var total := 0
	for value in latencies: total += value
	var search_max_us := 0
	for _index in 100:
		var started := Time.get_ticks_usec()
		var result := analyzer.sequential(boards[1], ["single","single","square2"])
		search_max_us = maxi(search_max_us,Time.get_ticks_usec()-started)
		if result.status != "budget_exhausted" or result.nodes != 256: failures += 1
	print("FAIR BENCHMARK: ", JSON.stringify({"generations":10000,"failures":failures,"generation_us":{"min":latencies[0],"p50":latencies[4999],"p95":latencies[9499],"max":latencies[-1],"mean":float(total)/10000},"repairs":provider.diagnostics().repairs,"bounded_search_runs":100,"bounded_search_nodes":256,"search_max_us":search_max_us,"environment":"cloud CPU, not Android frame-time acceptance"}))
	quit(0 if failures == 0 else 1)
