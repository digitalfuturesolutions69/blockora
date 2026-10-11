extends SceneTree

const Storage = preload("res://scripts/infrastructure/json_local_storage.gd")
var checks := 0
var cases := 0
var failures := 0
var app: ClassicApp
var storage: LocalStorageService
var path: String

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL [input integration]: " + label)

func settle() -> void:
	await process_frame
	await process_frame

func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = pressed
	Input.parse_input_event(event)

func _touch(position: Vector2, index: int, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)

func _move(position: Vector2, index: int = -1) -> void:
	if index == -1:
		var event := InputEventMouseMotion.new()
		event.position = position
		Input.parse_input_event(event)
	else:
		var event := InputEventScreenDrag.new()
		event.index = index
		event.position = position
		Input.parse_input_event(event)

func global_point(local: Vector2) -> Vector2:
	return app.surface.get_global_transform_with_canvas() * local

func _run() -> void:
	root.size = Vector2i(720, 1280)
	path = "user://phase1_input_" + str(Time.get_ticks_usec())
	storage = Storage.new(path)
	app = ClassicApp.new()
	app.configure(storage)
	root.add_child(app)
	await settle()
	cases += 1
	check(app.controller.state() == SessionStateMachine.State.HOME, "Home visible")
	var coming_soon := 0
	for button in app._content.find_children("*", "Button", true, false):
		if "Coming Soon" in button.text:
			coming_soon += 1
			check(button.disabled, "Coming Soon disabled")
	check(coming_soon == 2, "two Coming Soon controls")
	app.controller.new_game(42)
	await settle()
	cases += 1
	check(app.surface != null and app.surface.board_rect().size.x > 0, "real board and tray loaded")
	var surface := app.surface
	var before := app.controller.session().snapshot()
	_mouse(global_point(surface.tray_rect(0).get_center()), true)
	await settle()
	check(surface.is_dragging(), "mouse selects tray piece")
	var target := global_point(surface.pointer_for_origin(0, Vector2i.ZERO))
	_move(target)
	await settle()
	check(surface.preview_valid() and surface.drag_origin() == Vector2i.ZERO, "valid mouse preview")
	check(app.controller.session().snapshot() == before, "drag does not mutate session")
	check(ClassicSession.restore(storage.read_record(ClassicController.SAVE_KEY).data).snapshot() == before, "drag not persisted")
	_mouse(target, false)
	await settle()
	check(app.controller.session().score() > 0 and app.controller.session().piece_at(0) == null, "release commits board score tray")
	cases += 1
	surface = app.surface
	before = app.controller.session().snapshot()
	_mouse(global_point(surface.tray_rect(1).get_center()), true)
	await settle()
	target = global_point(surface.pointer_for_origin(1, Vector2i.ZERO))
	_move(target)
	await settle()
	check(not surface.preview_valid(), "overlap invalid preview")
	_mouse(target, false)
	await settle()
	check(app.controller.session().snapshot() == before, "invalid release changes nothing")
	check(not surface.is_dragging(), "invalid release returns piece to tray")
	cases += 1
	_mouse(global_point(surface.tray_rect(1).get_center()), true)
	await settle()
	_mouse(Vector2(-40, -40), false)
	await settle()
	check(not surface.is_dragging() and app.controller.session().snapshot() == before, "outside release canceled")
	cases += 1
	_touch(global_point(surface.tray_rect(1).get_center()), 0, true)
	await settle()
	check(surface.is_dragging(), "touch selects")
	target = global_point(surface.pointer_for_origin(1, Vector2i(0, 4)))
	_move(target, 0)
	await settle()
	check(surface.preview_valid(), "touch valid preview")
	_touch(target, 1, false)
	await settle()
	check(surface.is_dragging(), "unrelated finger cannot end drag")
	_touch(target, 0, false, true)
	await settle()
	check(not surface.is_dragging() and app.controller.session().snapshot() == before, "OS touch cancellation atomic")
	cases += 1
	_touch(global_point(surface.tray_rect(1).get_center()), 0, true)
	await settle()
	_move(target, 0)
	await settle()
	_touch(target, 0, false)
	await settle()
	check(app.controller.session().piece_at(1) == null and app.controller.session().score() > int(before.score), "touch commits through actual event interface")
	cases += 1
	surface = app.surface
	before = app.controller.session().snapshot()
	_touch(global_point(surface.tray_rect(2).get_center()), 0, true)
	await settle()
	check(surface.is_dragging(), "drag before interruption")
	app.interrupt()
	await settle()
	check(app.controller.state() == SessionStateMachine.State.PAUSED, "interruption pauses app")
	check(app.controller.session().snapshot() == before, "interruption preserves committed session")
	_touch(target, 0, false)
	await settle()
	check(app.controller.session().snapshot() == before, "stale touch release cannot place")
	app.controller.resume()
	await settle()
	check(app.surface != null and not app.surface.is_dragging(), "resume cancels selection")
	cases += 1
	app.controller.pause()
	await settle()
	for button in app._content.find_children("*", "Button", true, false):
		if button.text == "Restart":
			button.pressed.emit()
	await settle()
	check(app._dialog.visible and app.controller.session().snapshot() == before, "restart requires confirmation")
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(app.controller.session().snapshot() == before, "declined restart unchanged")
	app._dialog.confirmed.emit()
	app._dialog.hide()
	await settle()
	check(app.controller.state() == SessionStateMachine.State.PLAYING and app.controller.session().score() == 0, "confirmed restart")
	cases += 1
	surface = app.surface
	before = app.controller.session().snapshot()
	_mouse(global_point(surface.tray_rect(0).get_center()), true)
	await settle()
	check(surface.is_dragging(), "selected before window resize")
	root.size = Vector2i(540, 960)
	await settle()
	var resized_surface := app.surface
	check(not resized_surface.is_dragging() and app.controller.session().snapshot() == before, "resize cancels drag without mutation")
	_mouse(Vector2.ZERO, false)
	await settle()
	check(resized_surface.board_rect().end.x <= resized_surface.size.x and resized_surface.board_rect().end.y <= resized_surface.size.y, "board fits narrow portrait")
	check(resized_surface.tray_rect(2).end.y <= resized_surface.size.y, "tray fits portrait")
	check(resized_surface.tray_rect(0).size.x >= 48 and resized_surface.tray_rect(0).size.y >= 48, "comfortable tray targets")
	cases += 1
	app.controller.home()
	await settle()
	for button in app._content.find_children("*", "Button", true, false):
		if button.text == "Settings":
			button.pressed.emit()
	await settle()
	check(app._settings_open, "settings screen")
	for button in app._content.find_children("*", "Button", true, false):
		if button.text.begins_with("Sound"):
			button.pressed.emit()
	await settle()
	check(not app.controller.preferences().sound, "sound preference toggles")
	check(not ClassicController.new(storage).preferences().sound, "sound preference persists")
	for button in app._content.find_children("*", "Button", true, false):
		if button.text.begins_with("Vibration"):
			button.pressed.emit()
	await settle()
	check(not app.controller.preferences().vibration and not ClassicController.new(storage).preferences().vibration, "vibration preference persists")
	cases += 1
	app.queue_free()
	await settle()
	var fixture := ClassicSession.new().snapshot()
	fixture.board = [170, 85, 170, 85, 170, 85, 170, 85]
	fixture.tray = ["single", "square2", ""]
	storage.write_record(ClassicController.SAVE_KEY, fixture)
	app = ClassicApp.new()
	app.configure(storage)
	root.add_child(app)
	await settle()
	app.controller.resume()
	await settle()
	app.controller.place(0, Vector2i.ZERO)
	await settle()
	check(app.controller.state() == SessionStateMachine.State.GAME_OVER and app.surface == null, "game over screen replaces board")
	var replay_button: Button
	for button in app._content.find_children("*", "Button", true, false):
		if button.text == "Play Again":
			replay_button = button
	check(replay_button != null, "play again control exists")
	if replay_button != null:
		replay_button.pressed.emit()
	await settle()
	check(app.controller.state() == SessionStateMachine.State.PLAYING and app.controller.session().score() == 0, "play again works")
	app.queue_free()
	await settle()
	for key in [ClassicController.SAVE_KEY, ClassicController.BEST_KEY, ClassicController.SETTINGS_KEY]:
		DirAccess.remove_absolute(path.path_join(key + ".json"))
	DirAccess.remove_absolute(path)
	print("INPUT RESULT: %d cases, %d assertions, %d failures (injected Godot events; not device acceptance)" % [cases, checks, failures])
	quit(0 if failures == 0 else 1)
