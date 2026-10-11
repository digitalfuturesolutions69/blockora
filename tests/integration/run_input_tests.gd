extends SceneTree

const Storage = preload("res://scripts/infrastructure/json_local_storage.gd")
var checks := 0
var cases := 0
var failures := 0
var app: ClassicApp
var storage: LocalStorageService
var path: String
var moves := [0]

class EventObserver extends Node:
	var emulated_buttons := 0
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.device == -1:
			emulated_buttons += 1

func _tap_button(button: Button, mouse: bool = false) -> void:
	if button == null:
		check(false, "GUI button exists")
		return
	var presses := [0]
	button.pressed.connect(func() -> void: presses[0] += 1)
	var position := button.get_global_transform_with_canvas() * (button.size / 2.0)
	if button.get_window() != root:
		position += Vector2(button.get_window().position)
	position = root.get_final_transform() * position
	if mouse:
		_mouse(position, true)
	else:
		_touch(position, 0, true)
	await settle()
	check(presses[0] == 0, "button waits for release")
	if mouse:
		_mouse(position, false)
	else:
		_touch(position, 0, false)
	await settle()
	check(presses[0] == 1, "one input gesture emits exactly one button action")

func _tap(text: String, mouse: bool = false) -> void:
	var target: Button
	for button in app._content.find_children("*", "Button", true, false):
		if button.text.begins_with(text):
			target = button
			break
	await _tap_button(target, mouse)

func _initialize() -> void:
	# A failed navigation assertion must not leave CI hanging after a null UI.
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Input integration timed out")
		quit(1))
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
	root.gui_embed_subwindows = true
	path = "user://phase1_input_" + str(Time.get_ticks_usec())
	storage = Storage.new(path)
	app = ClassicApp.new()
	app.configure(storage)
	root.add_child(app)
	await settle()
	var observer := EventObserver.new()
	root.add_child(observer)
	cases += 1
	check(Input.is_emulating_mouse_from_touch(), "production touch-to-mouse setting enabled")
	check(app.controller.state() == SessionStateMachine.State.HOME, "Home visible")
	var coming_soon := 0
	for button in app._content.find_children("*", "Button", true, false):
		if "Coming Soon" in button.text:
			coming_soon += 1
			check(button.disabled, "Coming Soon disabled")
	check(coming_soon == 1, "Daily remains Coming Soon; Relax is enabled")
	var relax_enabled := false
	for button in app._content.find_children("*", "Button", true, false):
		if button.text == "Relax Mode": relax_enabled = not button.disabled
	check(relax_enabled, "Relax mode entry enabled")
	cases += 1
	await _tap("Settings")
	check(app._settings_open, "touch opens Settings")
	await _tap("Sound")
	check(not app.controller.preferences().sound, "touch toggles sound once")
	await _tap("Vibration")
	check(not app.controller.preferences().vibration, "touch toggles vibration once")
	await _tap("Back")
	check(not app._settings_open and app.controller.state() == SessionStateMachine.State.HOME, "touch Back returns Home")
	cases += 1
	await _tap("Play Classic")
	check(app.controller.state() == SessionStateMachine.State.PLAYING and app.surface != null, "touch Play Classic opens gameplay")
	check(not app._dialog.visible, "single tap does not reopen restart dialog")
	check(observer.emulated_buttons >= 10, "Godot synthesized mouse events from real touch injection")
	app.controller.move_completed.connect(func(_result: Dictionary) -> void: moves[0] += 1)
	var playing_snapshot := app.controller.session().snapshot()
	check(not app.controller.new_game(42) and app.controller.session().snapshot() == playing_snapshot, "new_game while Playing is rejected atomically")
	check(app.controller.pause(), "deterministic fixture enters an allowed restart state")
	check(app.controller.new_game(42), "deterministic fixture seed accepted")
	await settle()
	var fixture_snapshot := app.controller.session().snapshot()
	check(fixture_snapshot.board == [0,0,0,0,0,0,0,0] and fixture_snapshot.score == "0", "fixture starts on a known empty board")
	check(fixture_snapshot.tray == ["corner_se", "line5_h", "domino_v"] and fixture_snapshot.rng.state == 1054476435, "seed 42 known tray and next RNG state")
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
	var preview_evidence := {"before":before, "pointer":str(target), "origin":str(surface.drag_origin()), "valid":surface.preview_valid(), "incoming_piece_cells":app.controller.session().piece_at(1).cells()}
	check(not surface.preview_valid(), "overlap invalid preview")
	_mouse(target, false)
	await settle()
	print("INPUT OVERLAP EVIDENCE: ", JSON.stringify({"preview":preview_evidence,"after":app.controller.session().snapshot(),"surface_valid":is_instance_valid(surface)}))
	check(app.controller.session().snapshot() == before, "invalid release changes nothing")
	# Never call script methods through a freed Control after a failed invariant.
	# Godot 4.6.3 optimized scripts can crash rather than report a script error.
	if not is_instance_valid(surface):
		check(false, "invalid release unexpectedly destroyed the input surface")
		quit(1)
		return
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
	check(surface.is_dragging() and surface._pointer_id == 0, "original touch owns drag, not its preceding synthesized mouse")
	var initial_origin := surface.drag_origin()
	var synthetic_motion := InputEventMouseMotion.new()
	synthetic_motion.device = PuzzleSurface.EMULATED_MOUSE_DEVICE
	synthetic_motion.position = Vector2.ZERO
	Input.parse_input_event(synthetic_motion)
	await settle()
	check(surface.drag_origin() == initial_origin, "synthetic mouse motion cannot move a touch-owned drag")
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
	var previous_moves: int = moves[0]
	_touch(global_point(surface.tray_rect(1).get_center()), 0, true)
	await settle()
	_move(target, 0)
	await settle()
	_touch(target, 0, false)
	await settle()
	check(moves[0] == previous_moves + 1, "touch plus automatic mouse emulation commits exactly one move")
	check(app.controller.session().piece_at(1) == null and app.controller.session().score() > int(before.score), "touch commits through actual event interface")
	cases += 1
	surface = app.surface
	before = app.controller.session().snapshot()
	# A collision must also be atomic with both touch and emulated mouse enabled.
	_touch(global_point(surface.tray_rect(2).get_center()), 0, true)
	await settle()
	var invalid_target := global_point(surface.pointer_for_origin(2, Vector2i.ZERO))
	_move(invalid_target, 0)
	await settle()
	check(not surface.preview_valid(), "touch collision is invalid")
	_touch(invalid_target, 0, false)
	await settle()
	check(app.controller.session().snapshot() == before and moves[0] == previous_moves + 1, "invalid touch release changes no state or score")
	if not is_instance_valid(surface):
		check(false, "invalid touch release unexpectedly destroyed the input surface")
		quit(1)
		return
	var synthetic_press := InputEventMouseButton.new()
	synthetic_press.device = PuzzleSurface.EMULATED_MOUSE_DEVICE
	synthetic_press.button_index = MOUSE_BUTTON_LEFT
	synthetic_press.position = global_point(surface.tray_rect(2).get_center())
	synthetic_press.pressed = true
	Input.parse_input_event(synthetic_press)
	await settle()
	check(not surface.is_dragging(), "synthetic mouse cannot start a second drag on refreshed surface")
	synthetic_press.pressed = false
	Input.parse_input_event(synthetic_press)
	_touch(target, 0, false)
	await settle()
	check(app.controller.session().snapshot() == before and moves[0] == previous_moves + 1, "stale paired releases cannot duplicate score or placement")
	cases += 1
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
	await _tap("Restart")
	check(app._dialog.visible and app.controller.session().snapshot() == before, "restart requires confirmation")
	await _tap_button(app._dialog.get_cancel_button())
	check(app.controller.session().snapshot() == before, "declined restart unchanged")
	await _tap("Restart")
	await _tap_button(app._dialog.get_ok_button())
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
	await _tap("Settings", true)
	check(app._settings_open, "desktop mouse opens settings")
	await _tap("Sound", true)
	check(app.controller.preferences().sound, "mouse toggles sound back on")
	check(ClassicController.new(storage).preferences().sound, "sound preference persists")
	await _tap("Vibration", true)
	check(app.controller.preferences().vibration and ClassicController.new(storage).preferences().vibration, "mouse vibration preference persists")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(not app._settings_open, "Android Back closes settings")
	await _tap("Resume Game")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(app.controller.state() == SessionStateMachine.State.PAUSED, "Android Back pauses gameplay")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(app.controller.state() == SessionStateMachine.State.HOME, "Android Back returns Home from pause")
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
		await _tap_button(replay_button)
	await settle()
	check(app.controller.state() == SessionStateMachine.State.PLAYING and app.controller.session().score() == 0, "play again works")
	# Let the short original tone finish before the dummy audio server exits.
	await create_timer(0.2).timeout
	app.queue_free()
	observer.queue_free()
	await settle()
	for key in [ClassicController.SAVE_KEY, ClassicController.BEST_KEY, ClassicController.SETTINGS_KEY]:
		DirAccess.remove_absolute(path.path_join(key + ".json"))
	DirAccess.remove_absolute(path)
	print("INPUT RESULT: %d cases, %d assertions, %d failures (injected Godot events; not device acceptance)" % [cases, checks, failures])
	quit(0 if failures == 0 else 1)
