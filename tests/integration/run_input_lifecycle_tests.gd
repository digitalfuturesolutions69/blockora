extends SceneTree

var assertions := 0
var failures := 0
class MemoryStorage extends LocalStorageService:
	var records := {}
	func write_record(key: String, value: Dictionary) -> Error:
		records[key] = value.duplicate(true)
		return OK
	func read_record(key: String) -> Dictionary:
		return {"status":"ok","data":records[key].duplicate(true)} if records.has(key) else {"status":"missing","data":{}}

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("LIFECYCLE FAIL: " + label)

func settle() -> void:
	await process_frame
	await process_frame

func _run() -> void:
	root.size = Vector2i(720,1280)
	var app := ClassicApp.new()
	app.configure(MemoryStorage.new())
	root.add_child(app)
	app.controller.set_preferences(false,false)
	check(app.controller.new_game(222), "deterministic lifecycle seed accepted")
	await settle()
	var old_surface := app.surface
	var old_id := old_surface.get_instance_id()
	check(app.controller.place(0,Vector2i.ZERO).status == "ok", "single commits")
	await settle()
	check(not is_instance_valid(old_surface), "deferred committed refresh frees old surface")
	check(is_instance_valid(app.surface) and app.surface.get_instance_id() != old_id, "consumer reacquires current surface")
	check(app.controller.place(1,Vector2i.ZERO).status == "ok", "seed 222 same origin is legal without overlap")
	await settle()
	check(app.controller.session().board().serialize() == [3,7,0,0,0,0,0,0] and app.controller.session().score() == 5, "legal behavior that old fixture misclassified")
	var controller := app.controller
	controller.pause() # queues refresh; tear down before the callback executes.
	app.queue_free()
	await settle()
	check(not is_instance_valid(app), "queued refresh and teardown complete safely")
	controller.changed.emit() # Freed receivers must have disconnected automatically.
	await settle()
	check(root.get_child_count() == 0, "no retained UI nodes or live deferred receiver")
	print("LIFECYCLE RESULT: 2 cases, %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
