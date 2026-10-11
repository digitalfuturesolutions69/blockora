extends SceneTree

var checks := 0
var failures := 0
var events: Array[Dictionary] = []
var app: ClassicApp

class MemoryStorage extends LocalStorageService:
	var records := {}
	func read_record(key: String) -> Dictionary:
		return {"status":"ok", "data":records[key].duplicate(true)} if records.has(key) else {"status":"missing", "data":{}}
	func write_record(key: String, value: Dictionary) -> Error:
		records[key] = value.duplicate(true)
		return OK

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("AUDIO FAIL: " + label)

func settle() -> void:
	await process_frame
	await process_frame

func listen(manager: GameplayAudio) -> void:
	manager.cue_played.connect(func(event: String, pitch: float, volume: int) -> void:
		events.append({"event":event, "pitch":pitch, "volume":volume}))

func result(rows: Array, columns: Array = [], combo: int = 0, over: bool = false) -> Dictionary:
	return {"status":"ok", "cleared_rows":rows, "cleared_columns":columns, "combo":combo, "game_over":over}

func touch(position: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	event.index = index
	Input.parse_input_event(event)

func tap(button: Button) -> void:
	var pos := button.get_global_transform_with_canvas() * (button.size / 2)
	touch(pos, true)
	await settle()
	touch(pos, false)
	await settle()

func button(prefix: String) -> Button:
	for node in app._content.find_children("*", "Button", true, false):
		if node.text.begins_with(prefix):return node
	return null

func _run() -> void:
	root.size = Vector2i(720,1280)
	var manager := GameplayAudio.new()
	root.add_child(manager)
	listen(manager)
	var bytes := 0
	check(not manager._streams.daily_completed == null, "daily cue prepared but not routed by gameplay")
	for name: String in manager._streams:
		var stream: AudioStreamWAV = manager._streams[name]
		bytes += stream.data.size()
		check(stream.mix_rate == 22050 and not stream.stereo and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "compact offline PCM " + name)
		check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size()-2) == 0, "silent boundaries " + name)
		var peak := 0
		for index in stream.data.size()/2:
			peak = maxi(peak, absi(stream.data.decode_s16(index*2)))
		check(peak < 14746, "headroom without sample clipping " + name)
	check(bytes < 150000 and manager._players.size() == 2, "small cache and exactly two playback voices")
	print("AUDIO ASSETS: 8 original PCM streams, %d bytes" % bytes)
	for lines in [1,2,3,4,16]:
		events.clear()
		manager.handle_move(result(range(lines)), str(lines))
		check(events.size() == 1 and events[0].event == ("line_clear_1" if lines == 1 else ("line_clear_2" if lines == 2 else "line_clear_3_plus")), "actual clear intensity %d" % lines)
		events.clear()
		manager.handle_move(result(range(lines)), str(lines))
		check(events.is_empty(), "same transaction never repeats")
	events.clear()
	manager.handle_move(result([0],[0]), "cross")
	check(events.size() == 1 and events[0].event == "line_clear_2", "simultaneous row and column is one double-clear")
	manager.handle_move({"status":"invalid"}, "invalid")
	check(events.size() == 1, "rejected transaction produces no placement or clear sound")
	manager.invalid_placement()
	check(events.back().event == "invalid_placement", "soft invalid cue")
	var last_pitch := 0.0
	for combo in [2,3,4,5]:
		events.clear()
		manager.handle_move(result([0],[],combo), "combo%d" % combo)
		check(events.size() == 2 and events.back().event == "combo" and events.back().pitch > last_pitch, "combo pitch escalates")
		last_pitch = events.back().pitch
	events.clear()
	manager.handle_move(result([],[],0,true), "end")
	check(events.size() == 2 and events[0].event == "piece_placed" and events[1].event == "game_over", "ending only at accepted game-over transaction")
	for i in 100:
		manager.handle_move(result([0],[],3), "rapid%d" % i)
	check(manager._players.size() == 2 and manager._recent_transactions.size() == 32, "rapid placements bounded voices and dedup storage")
	check(manager._players[0].max_polyphony == 1 and manager._players[1].max_polyphony == 1, "no hidden polyphonic backlog")
	manager.set_preferences(true,25)
	check(is_equal_approx(manager._players[0].volume_db, linear_to_db(0.25)-9.0), "live volume change affects active playback")
	for reason in ["mute","zero","pause","background"]:
		manager.set_preferences(reason != "mute",0 if reason == "zero" else 70)
		manager.set_paused(reason == "pause")
		manager.set_backgrounded(reason == "background")
		events.clear()
		manager.handle_move(result([0]),reason)
		manager.invalid_placement()
		check(events.is_empty() and not manager._players[0].playing and not manager._players[1].playing,"stop and block " + reason)
	manager.set_preferences(true,70)
	manager.set_paused(false)
	manager.set_backgrounded(false)
	events.clear()
	manager.handle_move(result([0]),"background")
	check(events.is_empty(),"foreground does not replay muted/background transaction")
	manager.queue_free()
	await settle()

	# Drive real controllers: accepted engine results, saves, and both modes.
	for relax in [false,true]:
		for fixture in [{"board":[254,0,0,0,0,0,0,0],"piece":"single","lines":1},{"board":[254,254,0,0,0,0,0,0],"piece":"domino_v","lines":2},{"board":[254,254,254,0,0,0,0,0],"piece":"line3_v","lines":3},{"board":[254,1,1,1,1,1,1,1],"piece":"single","lines":2},{"board":[170,85,170,85,170,85,170,85],"piece":"single","lines":0,"over":true},{"board":[254,0,0,0,0,0,0,0],"piece":"single","lines":1,"combo":1}]:
			if relax and fixture.has("combo"):
				continue
			var storage := MemoryStorage.new()
			var session := RelaxPolicy.new_session(42) if relax else ClassicSession.new(FairPieceProvider.new(42))
			var snapshot := session.snapshot()
			snapshot.board = fixture.board
			snapshot.tray = [fixture.piece,"square2",""] if fixture.get("over",false) else [fixture.piece,"single","single"]
			snapshot.combo = fixture.get("combo",0)
			if relax:
				var envelope := RelaxPolicy.snapshot(session)
				envelope.session = snapshot
				check(RelaxSessionStore.new(storage).save_session(RelaxPolicy.restore(envelope)) == OK,"Relax audio fixture saved")
			else:
				storage.write_record(ClassicController.SAVE_KEY,snapshot)
			app = ClassicApp.new()
			app.configure(storage)
			root.add_child(app)
			listen(app.audio)
			app._relax_mode = relax
			var controller := app._active_controller()
			check(controller.resume(),"audio fixture resumed")
			await settle()
			events.clear()
			var before := controller.session().snapshot()
			check(controller.place(0,Vector2i(-1,0)).status == "invalid" and controller.session().snapshot() == before and events.is_empty(),"invalid does not mutate or play clear")
			var move := controller.place(0,Vector2i.ZERO)
			check(move.status == "ok" and move.cleared_rows.size()+move.cleared_columns.size() == fixture.lines,"real engine confirms lines")
			var event_count := 2 if fixture.get("over",false) or fixture.has("combo") else 1
			var expected := "piece_placed" if fixture.lines == 0 else ("line_clear_1" if fixture.lines == 1 else ("line_clear_2" if fixture.lines == 2 else "line_clear_3_plus"))
			check(events.size() == event_count and events[0].event == expected,"both modes route actual engine cue")
			if fixture.get("over",false):
				check(move.game_over and events.back().event == "game_over", "real game-over transition plays ending")
			if fixture.has("combo"):
				check(move.combo == 2 and events.back().event == "combo", "real Classic combo plays accent")
			controller.move_completed.emit(move)
			check(events.size() == event_count,"duplicate confirmation signal cannot replay sound")
			await settle()
			check(app._last_move_message.contains("lines cleared") if fixture.lines > 0 else controller.session().finished(),"visual clear or game-over feedback remains")
			events.clear()
			if fixture.get("over",false):
				controller.home()
			else:
				controller.pause()
			check(not app.audio._players[0].playing,"pause immediately stops sound")
			controller.resume()
			check(events.is_empty(),"save/resume has no feedback")
			app.queue_free()
			await settle()
			app = ClassicApp.new()
			app.configure(storage)
			root.add_child(app)
			listen(app.audio)
			app._relax_mode = relax
			app._active_controller().resume()
			await settle()
			check(events.is_empty(),"app restart never replays saved move")
			app.queue_free()
			await settle()

	var storage := MemoryStorage.new()
	storage.write_record(ClassicController.SETTINGS_KEY,{"schema_version":1,"sound":false,"vibration":false})
	check(ClassicController.new(storage).preferences().sound_volume == 70,"old preferences retain mute and default volume")
	for invalid: Variant in ["90",null,true,-1,101,12.5]:
		storage.records[ClassicController.SETTINGS_KEY].sound_volume = invalid
		check(ClassicController.new(storage).preferences().sound_volume == 70,"invalid volume safely defaults")
	app = ClassicApp.new()
	app.configure(storage)
	root.add_child(app)
	listen(app.audio)
	await settle()
	await tap(button("Settings"))
	await tap(button("Sound"))
	check(app.controller.preferences().sound,"real touchscreen toggle enables SFX")
	var slider: HSlider = app._content.get_node("SfxVolume")
	var point := slider.get_global_transform_with_canvas() * Vector2(slider.size.x*0.25,slider.size.y/2)
	touch(point,true)
	touch(point,false)
	await settle()
	check(is_instance_valid(slider) and app._content.get_node("SfxVolume") == slider,"slider survives touch without rebuilding GUI")
	var volume: int = app.controller.preferences().sound_volume
	check(volume > 15 and volume < 35 and ClassicController.new(storage).preferences().sound_volume == volume,"touch volume persisted")
	check(app.audio._volume == volume,"shared audio preferences applied")
	await tap(button("Back"))
	await tap(button("Play Classic"))
	events.clear()
	var surface := app.surface
	var start := surface.get_global_transform_with_canvas() * surface.tray_rect(0).get_center()
	# Invalid drop inside the control: one native touch, synthetic mouse ignored.
	touch(start,true)
	var invalid := surface.get_global_transform_with_canvas() * Vector2(surface.size.x-2,surface.size.y-2)
	touch(invalid,false)
	await settle()
	check(events.size() == 1 and events[0].event == "invalid_placement","real invalid drag produces one soft cue")
	events.clear()
	var first := app.surface
	start = first.get_global_transform_with_canvas() * first.tray_rect(0).get_center()
	var end := first.get_global_transform_with_canvas() * first.pointer_for_origin(0,Vector2i.ZERO)
	touch(start,true)
	touch(start,true,1)
	touch(end,false,1)
	check(events.is_empty(),"second pointer cannot commit or play sound")
	touch(end,false)
	await settle()
	check(events.size() == 1 and events[0].event == "piece_placed","one physical drag produces one placement cue")
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(app.audio._backgrounded and app.controller.state() == SessionStateMachine.State.PAUSED,"background pauses gameplay and audio")
	check(not app.audio._players[0].playing,"background stops current playback")
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(app.audio._paused and not app.audio._backgrounded,"foreground still waits for explicit resume")
	app.controller.resume()
	check(events.size() == 1,"foreground resume has no duplicated cue")
	app.controller.set_preferences(false,false)
	app.controller.set_sound_volume(0)
	check(not app.audio._players[0].playing and ClassicController.new(storage).preferences().sound_volume == 0,"mute and zero persist across restart")
	app.queue_free()
	await settle()
	# Allow the audio thread to release stopped playback before process teardown.
	await create_timer(0.10).timeout
	# Actual disk restart: numeric JSON decoding and mute/volume survive app recreation.
	var path := "user://audio_preferences_" + str(Time.get_ticks_usec())
	var disk: LocalStorageService = preload("res://scripts/infrastructure/json_local_storage.gd").new(path)
	var persisted := ClassicController.new(disk)
	check(persisted.new_game(222), "Classic disk fixture initialized")
	var classic_before: Dictionary = disk.read_record(ClassicController.SAVE_KEY)
	var best_before: Dictionary = disk.read_record(ClassicController.BEST_KEY)
	var relax_store := RelaxSessionStore.new(disk)
	check(relax_store.load_session() == null, "isolated Relax fixture starts without a save")
	var intended_relax := RelaxPolicy.new_session(42)
	var save_error := relax_store.save_session(intended_relax)
	check(save_error == OK, "Relax disk fixture save succeeds")
	if save_error != OK:
		quit(1)
		return
	# The writer already owns the saved revision. Restart uses a fresh reader.
	var loaded_relax := RelaxSessionStore.new(disk).load_session()
	check(loaded_relax != null, "fresh Relax store loads the committed disk fixture")
	if loaded_relax == null:
		quit(1)
		return
	var relax_before := RelaxPolicy.snapshot(loaded_relax)
	check(relax_before == RelaxPolicy.snapshot(intended_relax), "loaded Relax fixture preserves exact intended state")
	persisted.set_preferences(false,false)
	persisted.set_sound_volume(25)
	var reloaded := ClassicController.new(preload("res://scripts/infrastructure/json_local_storage.gd").new(path))
	check(reloaded.preferences() == {"sound":false,"vibration":false,"sound_volume":25}, "mute and volume survive actual JSON disk restart")
	check(disk.read_record(ClassicController.SAVE_KEY) == classic_before and disk.read_record(ClassicController.BEST_KEY) == best_before, "settings never rewrite Classic save or best")
	var after_preferences := RelaxSessionStore.new(disk).load_session()
	check(after_preferences != null, "Relax remains loadable after audio preferences change")
	if after_preferences == null:
		quit(1)
		return
	check(RelaxPolicy.snapshot(after_preferences) == relax_before, "settings never rewrite Relax session")
	for key in [ClassicController.SETTINGS_KEY,ClassicController.SAVE_KEY,ClassicController.BEST_KEY,"relax_session_v1_a","relax_session_v1_b"]:
		DirAccess.remove_absolute(path.path_join(key+".json"))
	DirAccess.remove_absolute(path)
	print("AUDIO RESULT: %d checks, %d failures (instrumentation, not audible device acceptance)" % [checks,failures])
	quit(0 if failures == 0 else 1)
