extends SceneTree

var checks := 0
var failures := 0
var cases := 0
var placements := 0
var app: ClassicApp
var confirmed := [0]

class MemoryStorage extends LocalStorageService:
	var records := {}
	func read_record(key: String) -> Dictionary:
		return {"status":"ok","data":records[key].duplicate(true)} if records.has(key) else {"status":"missing","data":{}}
	func write_record(key: String, value: Dictionary) -> Error:
		records[key] = value.duplicate(true)
		return OK

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Responsive layout suite timed out")
		quit(1))
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LAYOUT FAIL case %d: %s" % [cases,label])

func settle() -> void:
	await process_frame
	await process_frame

func touch(canvas_position: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_final_transform() * canvas_position
	event.pressed = pressed
	event.index = index
	event.canceled = canceled
	Input.parse_input_event(event)

func drag(canvas_position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = root.get_final_transform() * canvas_position
	event.index = 0
	Input.parse_input_event(event)

func tap(control: Button) -> void:
	check(control != null,"button exists")
	if control == null:return
	if control.get_window() == root:
		app._scroll.ensure_control_visible(control)
		await settle()
	var pos := control.get_global_transform_with_canvas() * (control.size/2)
	if control.get_window() != root:
		pos += Vector2(control.get_window().position)
	var actions := [0]
	control.pressed.connect(func() -> void: actions[0] += 1)
	touch(pos,true)
	touch(pos,false)
	await settle()
	check(actions[0] == 1,"one native tap invokes exactly one action")

func button(prefix: String) -> Button:
	for child: Button in app._content.find_children("*","Button",true,false):
		if child.text.begins_with(prefix):return child
	return null

func contained(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1.0).encloses(inner)

func validate_screen(gameplay: bool = false) -> void:
	var canvas := root.get_visible_rect()
	check(app.get_global_rect().size.is_equal_approx(canvas.size),"root fills effective viewport")
	check(root.get_final_transform().origin.is_zero_approx(),"no letterbox transform offset")
	check(is_equal_approx(root.get_final_transform().x.length(),root.get_final_transform().y.length()),"uniform axes preserve silhouettes")
	check(contained(app._usable_rect,app._scroll.get_global_rect()),"content lies inside safe area")
	check(app._scroll.size.x > 0 and app._scroll.size.y > 0,"positive usable content")
	if not gameplay:
		for child: Button in app._content.find_children("*","Button",true,false):
			check(child.size.x <= app._scroll.size.x+1 and child.size.y >= app._touch_size-1,"buttons fit width and preserve touch height")
		return
	var surface := app.surface
	check(surface != null,"gameplay surface exists")
	if surface == null:return
	check(app._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,"gameplay never scrolls under touch")
	check(contained(app._usable_rect,surface.get_global_rect()),"entire surface inside safe area")
	var local := Rect2(Vector2.ZERO,surface.size)
	check(contained(local,surface.board_rect()),"board within surface")
	check(is_equal_approx(surface.board_rect().size.x,surface.board_rect().size.y),"8x8 board perfectly square")
	for slot in 3:
		check(contained(local,surface.tray_rect(slot)),"tray fully visible")
		check(surface.tray_rect(slot).size.x >= app._touch_size and surface.tray_rect(slot).size.y >= app._touch_size,"accessible tray touch targets")
	check(not surface.board_rect().intersects(surface.tray_rect(0)),"board and tray do not overlap")
	for child in app._content.get_children():
		if child is Label:
			check(contained(app._usable_rect,child.get_global_rect()),"score and text remain visible")
	var pause := button("Pause")
	check(pause != null and contained(app._usable_rect,pause.get_global_rect()),"Pause remains visible inside safe area")

func _run() -> void:
	root.gui_embed_subwindows = true
	var matrix := [
		{"size":Vector2i(720,1600),"dpi":320.0,"insets":Vector4(0,0,0,0),"font":1.0},
		{"size":Vector2i(1080,1920),"dpi":480.0,"insets":Vector4(0,0,0,0),"font":1.0},
		{"size":Vector2i(1080,2340),"dpi":480.0,"insets":Vector4(0,0,0,0),"font":1.0},
		{"size":Vector2i(1080,2400),"dpi":480.0,"insets":Vector4(0,0,0,0),"font":1.0},
		{"size":Vector2i(1440,3200),"dpi":640.0,"insets":Vector4(0,0,0,0),"font":1.0},
		{"size":Vector2i(1080,2400),"dpi":480.0,"insets":Vector4(24,96,24,144),"font":1.5},
		{"size":Vector2i(1080,1920),"dpi":480.0,"insets":Vector4(60,180,60,240),"font":1.5},
		{"size":Vector2i(540,960),"dpi":240.0,"insets":Vector4(0,24,0,48),"font":2.0}
	]
	# A window inset already removed by Android must not be applied twice.
	var clipped := UsableLayout.safe_canvas_rect(Rect2(0,100,1080,2100),Rect2(0,100,1080,2100),Transform2D(Vector2(1.5,0),Vector2(0,1.5),Vector2.ZERO),Rect2(0,0,720,1400))
	check(clipped == Rect2(0,0,720,1400),"physical window offset avoids double system insets")
	check(UsableLayout.safe_canvas_rect(Rect2(),Rect2(0,0,100,100),Transform2D.IDENTITY,Rect2(0,0,100,100)) == Rect2(0,0,100,100),"missing safe area safely uses canvas")
	for config: Dictionary in matrix:
		cases += 1
		root.size = config.size
		await settle()
		var insets: Vector4 = config.insets
		var safe := Rect2(Vector2(insets.x,insets.y),Vector2(config.size)-Vector2(insets.x+insets.z,insets.y+insets.w))
		var storage := MemoryStorage.new()
		app = ClassicApp.new()
		app.configure(storage)
		app.set_layout_metrics(safe,config.dpi,config.font)
		root.add_child(app)
		await settle()
		validate_screen()
		var projected := root.get_final_transform() * app._usable_rect
		check(projected.position.distance_to(safe.position) < 1 and projected.size.distance_to(safe.size) < 1,"measured safe pixels transform into exact canvas bounds")
		check(app._touch_size * root.get_final_transform().x.length() >= 48*config.dpi/160.0,"physical controls meet 48 dp")
		print("LAYOUT CASE: ",JSON.stringify({"window":str(root.size),"canvas":str(root.get_visible_rect().size),"safe_pixels":str(safe),"safe_canvas":str(app._usable_rect),"dpi":config.dpi,"font_scale":config.font}))
		await tap(button("Settings"))
		check(app._settings_open,"Settings native tap opens screen")
		validate_screen()
		await tap(button("Back"))
		await tap(button("Play Classic"))
		for relax in [false,true]:
			if relax:
				await tap(button("Pause"))
				await tap(button("Home"))
				await tap(button("Relax Mode"))
			var controller := app._active_controller()
			check(controller.state() == SessionStateMachine.State.PLAYING,"mode entered through native GUI input")
			controller.move_completed.connect(func(_result: Dictionary) -> void: confirmed[0] += 1)
			validate_screen(true)
			controller._best = ScoreRules.MAX_SCORE
			controller.session()._score = ScoreRules.MAX_SCORE
			app._refresh()
			await settle()
			validate_screen(true)
			var snapshot := controller.session().snapshot()
			snapshot.board = [0,0,0,0,0,0,0,0]
			snapshot.tray = ["single","single","single"]
			snapshot.score = "0"
			snapshot.combo = 0
			snapshot.session_status = "active"
			var envelope := RelaxPolicy.snapshot(controller.session()) if relax else {}
			for y in 8:
				for x in 8:
					if relax:
						envelope.session = snapshot.duplicate(true)
						controller._session = RelaxPolicy.restore(envelope)
					else:
						controller._session = ClassicSession.restore(snapshot)
					app._refresh()
					await settle()
					var surface := app.surface
					var start := surface.get_global_transform_with_canvas()*surface.tray_rect(0).get_center()
					var end := surface.get_global_transform_with_canvas()*surface.pointer_for_origin(0,Vector2i(x,y))
					var before: int = confirmed[0]
					touch(start,true)
					drag(end)
					await settle() # Input accumulates ScreenDrag until the frame dispatch.
					check(surface.is_dragging() and surface.preview_valid() and surface.drag_origin() == Vector2i(x,y),"drag preview aligns with actual target cell")
					touch(start,true,1)
					touch(end,false,1)
					check(confirmed[0] == before,"secondary pointer cannot place")
					touch(end,false)
					await settle()
					check(confirmed[0] == before+1 and controller.session().board().read_cell(Vector2i(x,y)) == PuzzleBoard.CellState.OCCUPIED and controller.session().score() == 1,"physical drag maps to exact cell with one transaction")
					placements += 1
			var surface := app.surface
			var before_snapshot := controller.session().snapshot()
			var start := surface.get_global_transform_with_canvas()*surface.tray_rect(1).get_center()
			var invalid := surface.get_global_transform_with_canvas()*surface.pointer_for_origin(1,Vector2i(7,7))
			touch(start,true)
			touch(invalid,false)
			await settle()
			check(controller.session().snapshot() == before_snapshot,"invalid overlapping drop preserves all state")
			var board_before := app.surface.board_rect()
			app._last_move_message = "2 lines cleared!"
			app._refresh()
			await settle()
			check(app.surface.board_rect() == board_before,"clear text does not change board or touch geometry")
			await tap(button("Pause"))
			validate_screen()
			await tap(button("Restart"))
			check(app._dialog.visible and contained(app._usable_rect,Rect2(Vector2(app._dialog.position),Vector2(app._dialog.size))),"restart confirmation inside safe bounds")
			await tap(app._dialog.get_cancel_button())
			check(controller.session().snapshot() == before_snapshot,"restart cancel preserves state")
			await tap(button("Restart"))
			await tap(app._dialog.get_ok_button())
			check(controller.state() == SessionStateMachine.State.PLAYING and controller.session().score() == 0,"restart confirmation creates one new game")
			await tap(button("Pause"))
			await tap(button("Resume"))
			check(controller.state() == SessionStateMachine.State.PLAYING,"native pause/resume works")
			# Terminal fixture uses production engine to enter game-over.
			var terminal := controller.session().snapshot()
			terminal.board = [170,85,170,85,170,85,170,85]
			terminal.tray = ["single","square2",""]
			if relax:
				var terminal_envelope := RelaxPolicy.snapshot(controller.session())
				terminal_envelope.session = terminal
				controller._session = RelaxPolicy.restore(terminal_envelope)
			else:
				controller._session = ClassicSession.restore(terminal)
			check(controller.place(0,Vector2i.ZERO).game_over,"real engine enters terminal state")
			await settle()
			validate_screen()
			await tap(button("Home"))
			if not relax:
				# The outer branch enters Relax from playing Classic.
				await tap(button("Play Classic"))
		app.queue_free()
		await settle()
		if failures > 0:
			quit(1)
			return
	await create_timer(0.1).timeout
	print("RESPONSIVE RESULT: %d configurations, %d actual cell placements, %d checks, %d failures" % [cases,placements,checks,failures])
	quit(0 if failures == 0 else 1)
