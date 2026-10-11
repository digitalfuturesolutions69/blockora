extends "res://tests/integration/run_input_tests.gd"

var switch_us: Array[int] = []
var memory_samples: Array[int] = []

func _initialize() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Relax input timed out"); quit(1))
	_run.call_deferred()

func first_origin(slot: int) -> Vector2i:
	for y in 8:
		for x in 8:
			if app.relax_controller.session().can_place(slot,Vector2i(x,y)): return Vector2i(x,y)
	return Vector2i(-1,-1)

func _run() -> void:
	root.size = Vector2i(720,1280)
	root.gui_embed_subwindows = true
	path = "user://relax_input_" + str(Time.get_ticks_usec())
	storage = Storage.new(path)
	app = ClassicApp.new()
	app.configure(storage)
	root.add_child(app)
	await settle()
	app.controller.new_game(222)
	app.controller.home()
	await settle()
	var classic_before: Dictionary = storage.read_record(ClassicController.SAVE_KEY).data
	var best_before: Dictionary = storage.read_record(ClassicController.BEST_KEY).data
	cases += 1
	await _tap("Relax Mode")
	check(app._relax_mode and app.relax_controller.state() == SessionStateMachine.State.PLAYING and app.surface != null,"touch opens Relax")
	app.relax_controller.move_completed.connect(func(_result: Dictionary) -> void: moves[0] += 1)
	var before := app.relax_controller.session().snapshot()
	var surface := app.surface
	var origin := first_origin(0)
	var target := global_point(surface.pointer_for_origin(0,origin))
	cases += 1
	_touch(global_point(surface.tray_rect(0).get_center()),0,true)
	await settle()
	check(surface.is_dragging() and surface._pointer_id == 0,"native touch owns Relax drag")
	_touch(global_point(surface.tray_rect(1).get_center()),1,true)
	_move(target,0)
	await settle()
	check(surface.preview_valid() and app.relax_controller.session().snapshot() == before,"preview immutable")
	_touch(target,1,false)
	await settle()
	check(surface.is_dragging(),"second finger cannot finish")
	_touch(target,0,false)
	await settle()
	check(moves[0] == 1 and app.relax_controller.session().piece_at(0) == null,"exactly one placement")
	check(not is_instance_valid(surface) and is_instance_valid(app.surface),"deferred refresh safely replaces old surface")
	_touch(target,0,false)
	await settle()
	check(moves[0] == 1,"stale release cannot double count")
	cases += 1
	surface = app.surface
	before = app.relax_controller.session().snapshot()
	_touch(global_point(surface.tray_rect(1).get_center()),0,true)
	await settle()
	target = global_point(surface.pointer_for_origin(1,Vector2i(-1,0)))
	_move(target,0)
	await settle()
	check(not surface.preview_valid(),"invalid boundary preview")
	_touch(target,0,false)
	await settle()
	check(app.relax_controller.session().snapshot() == before and moves[0] == 1,"invalid release atomic")
	if not is_instance_valid(surface): check(false,"invalid release freed surface"); quit(1); return
	cases += 1
	_touch(global_point(surface.tray_rect(1).get_center()),0,true)
	await settle()
	app.interrupt()
	await settle()
	check(app.relax_controller.state() == SessionStateMachine.State.PAUSED and app.relax_controller.session().snapshot() == before,"background pause retains Relax")
	_touch(target,0,false)
	await settle()
	await _tap("Resume")
	check(not app.surface.is_dragging() and app.relax_controller.session().snapshot() == before,"resume no stale pointer")
	cases += 1
	await _tap("Pause")
	await _tap("Restart")
	check(app._dialog.visible,"restart confirmation visible")
	await _tap_button(app._dialog.get_cancel_button())
	check(app.relax_controller.session().snapshot() == before,"cancel restart preserves board")
	await _tap("Restart")
	await _tap_button(app._dialog.get_ok_button())
	check(app.relax_controller.session().score() == 0 and app.relax_controller.state() == SessionStateMachine.State.PLAYING,"confirmed restart resets Relax")
	cases += 1
	before = app.relax_controller.session().snapshot()
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(app.relax_controller.state() == SessionStateMachine.State.PAUSED,"Android Back pauses Relax")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(not app._relax_mode and app.controller.state() == SessionStateMachine.State.HOME,"Back reaches shared menu")
	await _tap("Resume Relax")
	check(app._relax_mode and app.relax_controller.session().snapshot() == before,"menu resume exact")
	cases += 1
	root.size = Vector2i(540,960)
	await settle()
	check(app.surface.board_rect().end.y <= app.surface.size.y and app.surface.tray_rect(2).end.y <= app.surface.size.y,"Relax board/tray fit narrow Android")
	root.size = Vector2i(720,1280)
	await settle()
	cases += 1
	var initial_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	for index in 1000:
		var started := Time.get_ticks_usec()
		app._go_home()
		await settle()
		app._open_relax()
		await settle()
		switch_us.append(Time.get_ticks_usec()-started)
		check(is_instance_valid(app.surface) and not app.surface.is_dragging() and app.relax_controller.session().snapshot() == before,"switch preserves session %d" % index)
		if (index+1)%200 == 0: memory_samples.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	check(memory_samples[-1]-initial_memory <= 20*1024*1024 and memory_samples[-1]-memory_samples[-2] <= 1024*1024,"bounded memory plateau")
	check(storage.read_record(ClassicController.SAVE_KEY).data == classic_before and storage.read_record(ClassicController.BEST_KEY).data == best_before,"Relax did not alter Classic saves")
	# App restart restores Relax but only enters gameplay on explicit resume.
	app.queue_free()
	await settle()
	app = ClassicApp.new()
	app.configure(storage)
	root.add_child(app)
	await settle()
	await _tap("Resume Relax")
	check(app.relax_controller.session().snapshot() == before,"app restart restores Relax")
	switch_us.sort()
	print("RELAX SWITCH BENCHMARK: ",JSON.stringify({"switches":1000,"p95_us":switch_us[949],"max_us":switch_us[-1],"includes_four_scene_frames":true,"initial_static_bytes":initial_memory,"memory_samples_bytes":memory_samples}))
	print("RELAX INPUT RESULT: %d cases, %d assertions, %d failures" % [cases,checks,failures])
	app.queue_free()
	await settle()
	for key in [ClassicController.SAVE_KEY,ClassicController.BEST_KEY,ClassicController.SETTINGS_KEY]+RelaxSessionStore.KEYS: DirAccess.remove_absolute(path.path_join(key+".json"))
	DirAccess.remove_absolute(path)
	quit(0 if failures == 0 else 1)
