extends SceneTree
const Storage = preload("res://scripts/infrastructure/json_local_storage.gd")

class InterruptedStorage extends "res://scripts/infrastructure/json_local_storage.gd":
	func write_record(key: String, value: Dictionary) -> Error:
		# Fault adapter reproduces a partial temporary-file write; production
		# JsonStorage remains unchanged. The harness kills this process here.
		DirAccess.make_dir_recursive_absolute(_root)
		var file := FileAccess.open(_root.path_join(key+".json.tmp"),FileAccess.WRITE)
		var text := JSON.stringify(value)
		file.store_string(text.substr(0,text.length()/2))
		file.flush()
		print("INTERRUPTED_WRITE_READY")
		while true: OS.delay_msec(100)
		return ERR_CANT_CREATE

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var mode: String = args[0]
	var directory: String = args[1]
	var storage: LocalStorageService = InterruptedStorage.new(directory) if mode == "interrupt" else Storage.new(directory)
	var controller := RelaxController.new(storage)
	if mode == "prepare":
		if not controller.new_game(42): quit(1); return
		if controller.place(0,Vector2i.ZERO).status != "ok": quit(1); return
	elif mode == "interrupt":
		# resume persists the existing snapshot into the inactive slot.
		if not controller.resume(): quit(1); return
	if controller.session() == null: quit(1); return
	print("PROCESS_SNAPSHOT: ",JSON.stringify(controller.session().snapshot()))
	quit(0)
