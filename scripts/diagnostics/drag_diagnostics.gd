class_name DragDiagnostics
extends RefCounted

# Debug-only caller opt-in; never print or allocate a record per motion packet.
const CAPACITY := 512
var _samples: Array[Dictionary] = []
var _next := 0
var _events := 0
var _frame_events := 0
var _last_frame_us := 0
var _started_us := Time.get_ticks_usec()
var _accumulated := true
var _draws := 0
var _last_draw_corner := Vector2.ZERO

func _init(accumulated: bool = true) -> void:
	_accumulated = accumulated

func event() -> void:
	_events += 1
	_frame_events += 1

func draw(corner: Vector2) -> void:
	_draws += 1
	_last_draw_corner = corner

func frame(pointer: Vector2, corner: Vector2, origin: Vector2i) -> void:
	var now := Time.get_ticks_usec()
	var interval := now - _last_frame_us if _last_frame_us > 0 else 0
	_last_frame_us = now
	var sample := {"interval_us":interval,"pointer":[pointer.x,pointer.y],"submitted_ghost":[corner.x,corner.y],"offset":[corner.x-pointer.x,corner.y-pointer.y],"candidate":[origin.x,origin.y],"input_events":_frame_events,"draw_calls_total":_draws,"last_draw_corner":[_last_draw_corner.x,_last_draw_corner.y]}
	_frame_events = 0
	if _samples.size() < CAPACITY:
		_samples.append(sample)
	else:
		_samples[_next] = sample
	_next = (_next + 1) % CAPACITY

static func distribution(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count":0,"mean":0.0,"median":0.0,"p95":0.0,"p99":0.0,"max":0.0}
	values.sort()
	var total := 0.0
	for value in values: total += value
	var middle := values.size() / 2
	var median := values[middle] if values.size() % 2 else (values[middle-1] + values[middle]) / 2.0
	return {"count":values.size(),"mean":total/values.size(),"median":median,"p95":values[maxi(0,ceili(values.size()*0.95)-1)],"p99":values[maxi(0,ceili(values.size()*0.99)-1)],"max":values.back()}

func finish(reason: String, emit_output: bool = true) -> Dictionary:
	var ordered: Array[Dictionary] = []
	for index in _samples.size():
		ordered.append(_samples[(_next+index)%CAPACITY] if _samples.size()==CAPACITY else _samples[index])
	var intervals: Array[float] = []
	for sample in ordered:
		if sample.interval_us > 0: intervals.append(float(sample.interval_us)/1000.0)
	var duration := maxf(0.000001,float(Time.get_ticks_usec()-_started_us)/1000000.0)
	var summary := {"reason":reason,"accumulated_input":_accumulated,"engine_fps_counter":Engine.get_frames_per_second(),"frame_intervals_ms":distribution(intervals),"input_events":_events,"events_per_second":_events/duration,"draw_calls":_draws,"retained_frames":ordered.size(),"capacity":CAPACITY,"measurement":"process wall intervals and draw submissions; not GPU presentation or input-to-photon"}
	if not emit_output:
		return summary
	var file := FileAccess.open("user://drag-diagnostics-last.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"summary":summary,"samples":ordered}))
		file.close()
	print("DRAG_DIAGNOSTICS: ",JSON.stringify(summary))
	return summary
