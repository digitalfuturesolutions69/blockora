extends SceneTree

# Optional exact pre-hotfix snapshot; normal parser checks need no external file.
var before_script: Script
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-surface="):
			before_script = load(arg.trim_prefix("--baseline-surface="))
	_run.call_deferred()

func surface(before: bool) -> Control:
	var node: Control = before_script.new() if before else PuzzleSurface.new()
	root.add_child(node)
	node.size = Vector2(672,880)
	node.show_session(ClassicSession.new(FairPieceProvider.new(222)),true)
	node._layout()
	return node

func _run() -> void:
	print("DRAG ENVIRONMENT: ",JSON.stringify({"display":DisplayServer.get_name(),"max_fps":Engine.max_fps,"physics_ticks":Engine.physics_ticks_per_second,"configured_vsync":ProjectSettings.get_setting("display/window/vsync/vsync_mode",1),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"note":"CPU geometry/submission experiments; no GPU/Android frame-time evidence"}))
	for before in [true,false]:
		if before and before_script == null: continue
		var node = surface(before)
		var start: Vector2 = node.tray_rect(0).get_center()
		node._begin(start,0)
		var previous: Vector2 = node._pointer+node._offset
		var initial_offset: Vector2 = node._offset
		var largest := 0.0
		for distance in range(1,49):
			node._move(start+Vector2(0,-distance))
			if not before: node._process(1.0/60)
			var corner: Vector2 = node._pointer+node._offset
			largest = maxf(largest,corner.distance_to(previous))
			previous = corner
		print("CONTINUITY EXPERIMENT: ",JSON.stringify({"before":before,"pointer_step":1,"max_ghost_step":largest,"offset_drift":node._offset.distance_to(initial_offset)}))
		node.cancel_drag()
		node.queue_free()
		await process_frame
	# Feed 240 packets in 60 frame groups: original immediate work vs latest-frame work.
	for before in [true,false]:
		if before and before_script == null: continue
		var node = surface(before)
		node._begin(node.tray_rect(0).get_center(),0)
		var position: Vector2 = node.pointer_for_origin(0,Vector2i(1,1))
		var durations: Array[float] = []
		for frame in 60:
			var begin := Time.get_ticks_usec()
			for packet in 4: node._move(position+Vector2(float(frame%8)*0.1+packet*0.01,0))
			if not before: node._process(1.0/60)
			durations.append(float(Time.get_ticks_usec()-begin))
		print("UPDATE EXPERIMENT: ",JSON.stringify({"before":before,"packets":240,"frame_groups":60,"candidate_update_opportunities":240 if before else 60,"group_cpu_us":DragDiagnostics.distribution(durations)}))
		node.cancel_drag()
		node.queue_free()
		await process_frame
	# Reducing frame cadence introduces stale coordinates; do not retain that option.
	for cadence in [1,2]:
		var node = surface(false)
		var start: Vector2 = node.tray_rect(0).get_center()
		node._begin(start,0)
		var worst := 0.0
		for frame in 60:
			var latest := start+Vector2(0,-float(frame+1)*5)
			node._move(latest)
			if frame%cadence == 0: node._process(1.0/60)
			worst = maxf(worst,node._render_pointer.distance_to(latest))
		print("CADENCE EXPERIMENT: ",JSON.stringify({"update_every_n_frames":cadence,"worst_latest_pointer_error":worst}))
		node.cancel_drag()
		node.queue_free()
		await process_frame
	quit()
