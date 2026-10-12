extends SceneTree

var checks := 0
var failures := 0
var app: ClassicApp
var moves := [0]
var cues := [0]

class MemoryStorage extends LocalStorageService:
	var records := {}
	func read_record(key: String) -> Dictionary:
		return {"status":"ok","data":records[key].duplicate(true)} if records.has(key) else {"status":"missing","data":{}}
	func write_record(key: String, value: Dictionary) -> Error:
		records[key] = value.duplicate(true)
		return OK

class CountingBoard extends PuzzleBoard:
	var calls := 0
	func can_place(piece: GamePiece, origin: Vector2i) -> bool:
		calls += 1
		return super.can_place(piece, origin)

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: push_error("Drag suite timeout"); quit(1))
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("DRAG FAIL: " + label)

func settle() -> void:
	await process_frame
	await process_frame

func point(surface: PuzzleSurface, local: Vector2) -> Vector2:
	return root.get_final_transform() * (surface.get_global_transform_with_canvas() * local)

func touch(surface: PuzzleSurface, local: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point(surface,local)
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(surface: PuzzleSurface, local: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point(surface,local)
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	root.size = Vector2i(1080,2400)
	var values: Array[float] = [5,1,4,2,3]
	var stats := DragDiagnostics.distribution(values)
	check(stats.mean == 3 and stats.median == 3 and stats.p95 == 5 and stats.p99 == 5 and stats.max == 5,"diagnostic frame statistics use correct ordered quantiles")
	check(DragDiagnostics.distribution([]).count == 0,"empty frame recording is reported as unmeasured")
	var diagnostics := DragDiagnostics.new()
	for index in 700:
		diagnostics.event()
		diagnostics.frame(Vector2(index,0),Vector2(index,8),Vector2i(index%8,0))
	var summary := diagnostics.finish("test",false)
	check(summary.input_events == 700 and summary.retained_frames == 512 and diagnostics._samples.size() == 512,"diagnostics buffering is bounded with exact motion count")
	check(diagnostics._samples[(diagnostics._next+511)%512].pointer == [699.0,0.0],"ring retains latest chronological sample")
	var original_accumulation := Input.use_accumulated_input
	for relax in [false,true]:
		app = ClassicApp.new()
		app.configure(MemoryStorage.new())
		app.set_layout_metrics(Rect2(24,96,1032,2160),480)
		root.add_child(app)
		app._relax_mode = relax
		var controller := app._active_controller()
		controller.new_game(222)
		controller.move_completed.connect(func(_result: Dictionary) -> void: moves[0] += 1)
		app.audio.cue_played.connect(func(_event: String, _pitch: float, _volume: int) -> void: cues[0] += 1)
		await settle()
		var surface := app.surface
		check(not surface._diagnostics_enabled and surface._diagnostics == null,"normal drag diagnostics are disabled by default")
		var start := surface.tray_rect(0).get_center() + Vector2(4,3)
		var before := controller.session().snapshot()
		var old_corner := surface._tray_corner(0)
		var placed_cells := controller.session().piece_at(0).cell_count()
		touch(surface,start,true)
		await settle()
		check(app.surface == surface,"pickup retains the current surface")
		if app.surface != surface or not surface.is_dragging():
			check(false,"fixture could not establish active drag")
			quit(1)
			return
		check(surface.is_dragging() and Input.use_accumulated_input == original_accumulation,"touch ownership preserves engine accumulation setting")
		check(is_equal_approx(surface._ghost_unit,surface._tray_unit(0)*1.04),"pickup expands only four percent")
		check((surface._pointer+surface._offset).distance_to(old_corner) < 15,"pickup preserves grab relationship with small lift")
		var target := surface.pointer_for_origin(0,Vector2i(2,2))
		motion(surface,target)
		check(surface._pointer.distance_to(target) < 0.001 and surface._motion_pending,"input dispatch stores the latest pointer immediately")
		await settle()
		check(surface._render_pointer.distance_to(target) < 0.001 and not surface._motion_pending,"next visual frame uses latest pointer without trailing interpolation")
		check(surface.preview_valid() and surface.drag_origin() == Vector2i(2,2),"shared lifted offset maps correct candidate")
		check(is_equal_approx(surface._ghost_unit,surface._pickup_unit),"drag unit remains constant instead of resizing with pointer travel")
		var fixed_offset := surface._offset
		var last_pointer := surface._render_pointer
		var last_corner := last_pointer + fixed_offset
		# Exercise reversal, pickup-radius and candidate-cell boundaries.
		for step in range(64):
			var next := start + Vector2(step * 3.0, -step * 4.0)
			motion(surface,next)
			await settle()
			var corner := surface._render_pointer + surface._offset
			check(surface._offset.is_equal_approx(fixed_offset),"pointer-to-piece offset cannot drift during motion")
			check((corner-last_corner).distance_to(next-last_pointer) < 0.001,"ghost displacement matches pointer displacement exactly")
			check(is_equal_approx(surface._ghost_unit,surface._pickup_unit),"ghost scale never changes across candidate boundaries")
			last_pointer = next
			last_corner = corner
		motion(surface,target)
		await settle()
		var node_id := surface.get_instance_id()
		var board := CountingBoard.new()
		surface._board = board
		surface._candidate_known = false
		for i in 10000:
			motion(surface,target+Vector2(float(i%4)*0.01,0))
		check(board.calls == 0,"motion packets cannot trigger per-packet candidate evaluation")
		await settle()
		check(board.calls == 1,"10000 same-cell motions evaluate placement only once at visual frame")
		check(surface.get_instance_id() == node_id and app.surface == surface,"motion never rebuilds surface hierarchy")
		check(controller.session().snapshot() == before,"drag is presentation-only")
		var previous_moves: int = moves[0]
		var previous_cues: int = cues[0]
		touch(surface,start,true,1)
		motion(surface,target+Vector2(100,0),1)
		touch(surface,target,false,1)
		check(moves[0] == previous_moves and surface._pointer.distance_to(target) < 0.1,"secondary pointer cannot move or commit")
		touch(surface,target,false)
		check(moves[0] == previous_moves+1 and cues[0] == previous_cues+1,"one release synchronizes one confirmed move and placement cue")
		check(Input.use_accumulated_input == original_accumulation,"valid release restores prior input mode")
		check(controller.session().score() == placed_cells,"accepted placement scores exactly its placed cells")
		await settle()
		surface = app.surface
		before = controller.session().snapshot()
		start = surface.tray_rect(1).get_center()
		var invalid_found := false
		var dimensions := surface._pieces[1].dimensions()
		for y in 9-dimensions.y:
			for x in 9-dimensions.x:
				var candidate := Vector2i(x,y)
				var location := surface.pointer_for_origin(1,candidate)
				if not surface._board.can_place(surface._pieces[1],candidate) and Rect2(Vector2.ZERO,surface.size).has_point(location):
					target = location
					invalid_found = true
					break
			if invalid_found: break
		check(invalid_found,"invalid fixture chooses an in-control overlapping origin")
		touch(surface,start,true)
		await settle()
		motion(surface,target)
		await settle()
		check(not surface.preview_valid(),"overlapping origin is clearly invalid")
		touch(surface,target,false)
		check(not surface.is_dragging() and surface._return_slot == 1 and surface.is_processing(),"invalid release immediately relinquishes pointer and starts bounded return")
		check(controller.session().snapshot() == before and moves[0] == previous_moves+1,"invalid return leaves board score RNG tray and saves unchanged")
		check(Input.use_accumulated_input == original_accumulation,"invalid release restores prior input mode")
		await create_timer(0.16).timeout
		check(surface._return_slot == -1 and not surface.is_processing(),"return finishes and disables per-frame processing")
		# Cancellation must clean ownership and animations, including pre-disabled input.
		surface._diagnostics_raw = true # Controlled debug A/B override.
		for prior in [true,false]:
			Input.use_accumulated_input = prior
			touch(surface,start,true)
			await settle()
			touch(surface,target,false,0,true)
			check(not surface.is_dragging() and surface._return_slot == -1 and Input.use_accumulated_input == prior,"OS cancellation restores exact prior flag without return effect")
		surface._diagnostics_raw = false
		Input.use_accumulated_input = original_accumulation
		touch(surface,start,true)
		await settle()
		app.interrupt()
		check(not surface.is_dragging() and not surface.is_processing() and Input.use_accumulated_input == original_accumulation,"pause cancels drag and restores input immediately")
		await settle()
		controller.resume()
		await settle()
		check(not app.surface.is_dragging() and controller.session().snapshot() == before,"resume preserves state without delayed drag")
		# Repeat accepted gestures, reacquiring deferred surfaces.
		for seed in range(20):
			check(controller.pause(),"rapid fixture pauses before approved restart")
			var initialized := controller.new_game(seed)
			check(initialized,"rapid fixture restart succeeds")
			if not initialized:
				quit(1)
				return
			await settle()
			surface = app.surface
			var cells := controller.session().piece_at(0).cell_count()
			previous_moves = moves[0]
			previous_cues = cues[0]
			touch(surface,surface.tray_rect(0).get_center(),true)
			await settle()
			target = surface.pointer_for_origin(0,Vector2i.ZERO)
			motion(surface,target + Vector2(150,0))
			touch(surface,target,false)
			check(moves[0] == previous_moves+1 and cues[0] == previous_cues+1 and controller.session().score() == cells,"rapid deterministic gestures have exact score and SFX")
			await settle()
		surface = app.surface
		touch(surface,surface.tray_rect(1).get_center(),true)
		await settle()
		app.queue_free()
		await settle()
		check(Input.use_accumulated_input == original_accumulation,"freeing active drag restores input and leaves no callbacks")
	await create_timer(0.1).timeout
	print("DRAG RESULT: 2 modes, 20000 same-cell motions, 40 rapid placements, %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
