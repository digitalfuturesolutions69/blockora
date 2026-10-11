extends SceneTree
const Storage = preload("res://scripts/infrastructure/json_local_storage.gd")

func distribution(values: Array[int]) -> Dictionary:
	values.sort()
	return {"p95_us":values[int((values.size()-1)*0.95)],"max_us":values[-1]}

func _initialize() -> void:
	var path := "user://relax_bench_"+str(Time.get_ticks_usec())
	var storage := Storage.new(path)
	var store := RelaxSessionStore.new(storage)
	store.load_session()
	var session := RelaxPolicy.new_session(42)
	var saves: Array[int] = []
	var loads: Array[int] = []
	var failures := 0
	for _index in 1000:
		var started := Time.get_ticks_usec()
		if store.save_session(session) != OK: failures += 1
		saves.append(Time.get_ticks_usec()-started)
		started = Time.get_ticks_usec()
		var restored := RelaxSessionStore.new(storage).load_session()
		loads.append(Time.get_ticks_usec()-started)
		if restored == null or restored.snapshot() != session.snapshot(): failures += 1
	var generation: Array[int] = []
	var library := RelaxPieceLibrary.new()
	var provider := FairPieceProvider.new(42,library)
	var board := PuzzleBoard.deserialize([170,85,170,85,170,85,170,85])
	var analyzer := BoardAnalyzer.new(library)
	for _index in 10000:
		var started := Time.get_ticks_usec()
		var tray := provider.next_tray_for_board(board)
		generation.append(Time.get_ticks_usec()-started)
		if analyzer.tray_summary(board,tray).game_over: failures += 1
	var save_stats := distribution(saves)
	var load_stats := distribution(loads)
	if save_stats.p95_us > 25000 or load_stats.p95_us > 25000 or save_stats.max_us > 100000 or load_stats.max_us > 100000: failures += 1
	print("RELAX PERFORMANCE RESULT: ",JSON.stringify({"save":save_stats,"load":load_stats,"generation":distribution(generation),"samples":1000,"generations":10000,"failures":failures,"environment":"cloud CPU and filesystem, not Android device"}))
	for key in RelaxSessionStore.KEYS: DirAccess.remove_absolute(path.path_join(key+".json"))
	DirAccess.remove_absolute(path)
	quit(0 if failures == 0 else 1)
