extends SceneTree

# Optional rendered desktop evidence. Requires an X11 display; never a device test.
const Storage = preload("res://scripts/infrastructure/json_local_storage.gd")
var destination := "builds/screenshots"

func _initialize() -> void:
	_run.call_deferred()

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(destination.path_join(name_value + ".png")) != OK:
		push_error("Screen capture failed: " + name_value)
		quit(1)

func mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	root.size = Vector2i(720, 1280)
	DirAccess.make_dir_recursive_absolute(destination)
	# Godot imports PNGs independently of .gitignore; never scan generated captures.
	var ignore_file := FileAccess.open(destination.get_base_dir().path_join(".gdignore"), FileAccess.WRITE)
	ignore_file.close()
	var path := "user://phase1_capture_" + str(Time.get_ticks_usec())
	var app := ClassicApp.new()
	app.configure(Storage.new(path))
	root.add_child(app)
	await capture("home")
	app.controller.new_game(42)
	await capture("classic")
	var surface := app.surface
	var transform := surface.get_global_transform_with_canvas()
	mouse(transform * surface.tray_rect(0).get_center(), true)
	await process_frame
	var target := transform * surface.pointer_for_origin(0, Vector2i.ZERO)
	var movement := InputEventMouseMotion.new()
	movement.position = target
	Input.parse_input_event(movement)
	await capture("valid_preview")
	mouse(target, false)
	await capture("placed")
	surface = app.surface
	transform = surface.get_global_transform_with_canvas()
	mouse(transform * surface.tray_rect(1).get_center(), true)
	await process_frame
	movement = InputEventMouseMotion.new()
	movement.position = transform * surface.pointer_for_origin(1, Vector2i.ZERO)
	Input.parse_input_event(movement)
	await capture("invalid_preview")
	mouse(movement.position, false)
	app.controller.pause()
	await capture("pause")
	app.controller.home()
	await capture("home_resume")
	app._settings_open = true
	app._refresh()
	await capture("settings")
	app._settings_open = false
	app.controller.resume()
	root.size = Vector2i(540, 960)
	await capture("classic_narrow")
	app.queue_free()
	await process_frame
	var fixture := ClassicSession.new().snapshot()
	fixture.board = [170, 85, 170, 85, 170, 85, 170, 85]
	fixture.tray = ["single", "square2", ""]
	Storage.new(path).write_record(ClassicController.SAVE_KEY, fixture)
	app = ClassicApp.new()
	app.configure(Storage.new(path))
	root.add_child(app)
	app.controller.resume()
	app.controller.place(0, Vector2i.ZERO)
	await capture("game_over")
	app.queue_free()
	await process_frame
	for key in [ClassicController.SAVE_KEY, ClassicController.BEST_KEY, ClassicController.SETTINGS_KEY]:
		DirAccess.remove_absolute(path.path_join(key + ".json"))
	DirAccess.remove_absolute(path)
	print("RENDER RESULT: desktop captures saved to " + destination)
	await create_timer(0.2).timeout
	quit(0)
