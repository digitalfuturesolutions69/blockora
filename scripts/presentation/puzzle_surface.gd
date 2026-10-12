class_name PuzzleSurface
extends Control

signal placement_requested(slot: int, origin: Vector2i)
signal invalid_placement
const COLORS := {"mint": Color("71e2bf"), "gold": Color("ffd083"), "blue": Color("82bbff"), "rose": Color("f39da9"), "lavender": Color("b5a0ef")}
# Godot InputEvent::DEVICE_ID_EMULATION (core/input/input_event.h).
# GUI buttons need these events; gameplay consumes the original touch only.
const EMULATED_MOUSE_DEVICE := -1
const IDLE := -2
var _board := PuzzleBoard.new()
var _pieces: Array[GamePiece] = []
var _cells: Array = []
var _active := false
var _pointer_id := IDLE
var _selected := -1
var _pointer := Vector2.ZERO
var _offset := Vector2.ZERO
var _origin := Vector2i.ZERO
var _valid := false
var _board_rect := Rect2()
var _tray_rects: Array[Rect2] = []
var _cell_size := 1.0
var _background := StyleBoxFlat.new()
var _minimum_touch_size := 96.0
var _accumulation_before := true
var _owns_accumulation := false
var _candidate_known := false
var _render_pointer := Vector2.ZERO
var _motion_pending := false
var _diagnostics: DragDiagnostics
var _diagnostics_enabled := false
var _diagnostics_raw := false
var _pickup_unit := 27.0
var _ghost_unit := 27.0
var _return_slot := -1
var _return_elapsed := 0.0
var _return_corner := Vector2.ZERO
var _return_unit := 27.0
const RETURN_SECONDS := 0.12

func _ready() -> void:
	custom_minimum_size = Vector2(0, _minimum_touch_size + 216)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background.bg_color = Color("111f2e")
	_background.set_corner_radius_all(14)
	resized.connect(_layout)
	_layout()
	set_process(false)
	_diagnostics_enabled = OS.is_debug_build() and FileAccess.file_exists("user://enable_drag_diagnostics")
	_diagnostics_raw = _diagnostics_enabled and FileAccess.file_exists("user://enable_drag_raw_input")

func show_session(session: ClassicSession, active: bool) -> void:
	cancel_drag()
	_active = active
	_board = session.board()
	_pieces.clear()
	_cells.clear()
	for slot in 3:
		var piece := session.piece_at(slot)
		_pieces.append(piece)
		_cells.append(piece.cells() if piece != null else [])
	queue_redraw()

func set_minimum_touch_size(value: float) -> void:
	_minimum_touch_size = maxf(48.0, value)
	custom_minimum_size = Vector2(0, _minimum_touch_size + 216)
	if is_node_ready():
		_layout()

func _layout() -> void:
	cancel_drag()
	var tray_height := maxf(110, _minimum_touch_size)
	var side := maxf(8, minf(size.x - 16, size.y - tray_height - 56))
	_board_rect = Rect2(Vector2((size.x - side) / 2, 8), Vector2.ONE * side)
	_cell_size = side / 8.0
	_tray_rects.clear()
	var width := (size.x - 16) / 3.0
	for slot in 3:
		_tray_rects.append(Rect2(8 + slot * width, _board_rect.end.y + 40, width - 8, maxf(tray_height, size.y - _board_rect.end.y - 48)))
	queue_redraw()

func board_rect() -> Rect2:
	return _board_rect

func tray_rect(slot: int) -> Rect2:
	return _tray_rects[slot]

func is_dragging() -> bool:
	return _selected >= 0

func drag_origin() -> Vector2i:
	return _origin

func preview_valid() -> bool:
	return _valid

func cancel_drag(reason: String = "canceled") -> void:
	if _diagnostics != null:
		_diagnostics.finish(reason)
		_diagnostics = null
	_motion_pending = false
	if _owns_accumulation:
		Input.use_accumulated_input = _accumulation_before
		_owns_accumulation = false
	_return_slot = -1
	set_process(false)
	_candidate_known = false
	_pointer_id = IDLE
	_selected = -1
	_valid = false
	queue_redraw()

func _local_pointer(position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * position

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == EMULATED_MOUSE_DEVICE:
		return
	if not _active or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_begin(_local_pointer(event.position), event.index)
		elif event.index == _pointer_id:
			_finish(_local_pointer(event.position), event.canceled)
	elif event is InputEventScreenDrag and event.index == _pointer_id:
		_move(_local_pointer(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(_local_pointer(event.position), -1)
		elif _pointer_id == -1:
			_finish(_local_pointer(event.position), event.canceled)
	elif event is InputEventMouseMotion and _pointer_id == -1:
		_move(_local_pointer(event.position))

func _begin(position: Vector2, pointer_id: int) -> void:
	if _selected != -1:
		return
	for slot in _tray_rects.size():
		if _tray_rects[slot].has_point(position) and _pieces[slot] != null:
			_selected = slot
			_pointer_id = pointer_id
			var dimensions := _pieces[slot].dimensions()
			_return_slot = -1
			set_process(true)
			_pickup_unit = _tray_unit(slot) * 1.04
			var corner := _tray_corner(slot)
			# Retain the actual grab location; lift only eight logical units at pickup.
			var grab := (position - corner).clamp(Vector2.ZERO, Vector2(dimensions) * _tray_unit(slot))
			_offset = -grab * 1.04 - Vector2(0, 8)
			_ghost_unit = _pickup_unit
			_candidate_known = false
			_accumulation_before = Input.use_accumulated_input
			# Keep normal engine accumulation. Raw dispatch is a debug-only A/B option.
			_owns_accumulation = _diagnostics_raw
			if _diagnostics_raw:
				Input.use_accumulated_input = false
			if _diagnostics_enabled:
				_diagnostics = DragDiagnostics.new(Input.use_accumulated_input)
			_apply_pointer(position)
			get_viewport().set_input_as_handled()
			return

func _move(position: Vector2) -> void:
	if _selected < 0:
		return
	_pointer = position
	_motion_pending = true
	if _diagnostics != null:
		_diagnostics.event()
	get_viewport().set_input_as_handled()

func _apply_pointer(position: Vector2) -> void:
	_pointer = position
	_render_pointer = position
	_motion_pending = false
	var relative := (position + _offset - _board_rect.position) / _cell_size
	var candidate := Vector2i(floori(relative.x), floori(relative.y))
	if not _candidate_known or candidate != _origin:
		_origin = candidate
		_valid = _board.can_place(_pieces[_selected], _origin)
		_candidate_known = true
	queue_redraw()

func _finish(position: Vector2, canceled: bool) -> void:
	if _selected < 0:
		return
	get_viewport().set_input_as_handled()
	# Release is authoritative immediately, even before the next visual frame.
	_apply_pointer(position)
	var slot := _selected
	var origin := _origin
	# A release outside this control is always cancellation, even if offset fits.
	var commit := not canceled and _valid and Rect2(Vector2.ZERO, size).has_point(position)
	var corner := _pointer + _offset
	var unit := _ghost_unit
	cancel_drag("accepted" if commit else ("canceled" if canceled else "invalid"))
	if commit:
		placement_requested.emit(slot, origin)
	elif not canceled and Rect2(Vector2.ZERO, size).has_point(position):
		# View-only return; pointer ownership and input mode are already released.
		_return_slot = slot
		_return_corner = corner
		_return_unit = unit
		_return_elapsed = 0.0
		set_process(true)
		invalid_placement.emit()

func pointer_for_origin(slot: int, origin: Vector2i) -> Vector2:
	# Shared coordinate helper used by real event integration tests.
	var dimensions := _pieces[slot].dimensions()
	var offset := _offset if _selected == slot else -Vector2(dimensions) * _tray_unit(slot) * 0.52 - Vector2(0, 8)
	return _board_rect.position + Vector2(origin) * _cell_size + Vector2.ONE * (_cell_size * 0.1) - offset

func _tray_unit(slot: int) -> float:
	var rect := _tray_rects[slot]
	var dimensions := _pieces[slot].dimensions()
	return minf(27, minf((rect.size.x - 24) / dimensions.x, (rect.size.y - 24) / dimensions.y))

func _tray_corner(slot: int) -> Vector2:
	return _tray_rects[slot].get_center() - Vector2(_pieces[slot].dimensions()) * _tray_unit(slot) / 2.0

func _process(delta: float) -> void:
	if _selected >= 0:
		if _motion_pending:
			_apply_pointer(_pointer)
		if _diagnostics != null:
			_diagnostics.frame(_pointer, _render_pointer + _offset, _origin)
		return
	_return_elapsed += delta
	if _return_elapsed >= RETURN_SECONDS:
		_return_slot = -1
		set_process(false)
	queue_redraw()

func _exit_tree() -> void:
	cancel_drag()

func _draw_ghost(slot: int, corner: Vector2, unit: float, alpha: float) -> void:
	var color: Color = COLORS.get(_pieces[slot].render_key(), COLORS.mint)
	color.a = alpha
	var gap := minf(5, unit * 0.12)
	for cell in _cells[slot]:
		var rect := Rect2(corner + Vector2(cell) * unit + Vector2.ONE * gap, Vector2.ONE * (unit - gap * 2))
		draw_rect(Rect2(rect.position + Vector2(2, 4), rect.size), Color(0, 0, 0, 0.20))
		draw_rect(rect, color)
		draw_rect(rect, Color("f4f7f9"), false, 1)

func _draw() -> void:
	draw_style_box(_background, _board_rect.grow(6))
	for y in 8:
		for x in 8:
			var rect := Rect2(_board_rect.position + Vector2(x, y) * _cell_size + Vector2.ONE * 3, Vector2.ONE * (_cell_size - 6))
			var occupied := _board.read_cell(Vector2i(x, y)) == PuzzleBoard.CellState.OCCUPIED
			draw_rect(rect, Color("71e2bf") if occupied else Color("213446"))
			if occupied:
				draw_line(rect.position + Vector2(3, 3), rect.position + Vector2(rect.size.x - 3, 3), Color("b6f5de"), 2)
	for slot in _tray_rects.size():
		var rect := _tray_rects[slot]
		draw_rect(rect, Color("152638"))
		if slot == _selected:
			draw_rect(rect.grow(-2), Color("f4f7f9"), false, 3)
		if slot >= _pieces.size() or _pieces[slot] == null:
			var center := rect.get_center()
			draw_line(center + Vector2(-8, 0), center + Vector2(-1, 7), Color("5a7287"), 3)
			draw_line(center + Vector2(-1, 7), center + Vector2(13, -8), Color("5a7287"), 3)
			continue
		var piece := _pieces[slot]
		var dimensions := piece.dimensions()
		var unit := minf(27, minf((rect.size.x - 24) / dimensions.x, (rect.size.y - 24) / dimensions.y))
		var corner := rect.get_center() - Vector2(dimensions) * unit / 2.0
		var color: Color = COLORS.get(piece.render_key(), COLORS.mint)
		if slot == _selected or slot == _return_slot:
			color.a = 0.35
		for cell in _cells[slot]:
			draw_rect(Rect2(corner + Vector2(cell) * unit + Vector2.ONE * 2, Vector2.ONE * (unit - 4)), color)
	var hint := "Drag a piece onto the board"
	if _selected >= 0:
		hint = "✓ Fits — release to place" if _valid else "× Doesn't fit — release to cancel"
		var color := Color("a3f5d9") if _valid else Color("ffacb9")
		for cell in _cells[_selected]:
			var rect := Rect2(_board_rect.position + Vector2(_origin + cell) * _cell_size + Vector2.ONE * 3, Vector2.ONE * (_cell_size - 6))
			var fill := color
			fill.a = 0.65
			draw_rect(rect, fill)
			draw_rect(rect, Color.WHITE, false, 2)
			var center := rect.get_center()
			if _valid:
				draw_line(center + Vector2(-7, 0), center + Vector2(-1, 6), Color("0b1927"), 3)
				draw_line(center + Vector2(-1, 6), center + Vector2(10, -7), Color("0b1927"), 3)
			else:
				draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), Color("0b1927"), 3)
				draw_line(center + Vector2(6, -6), center + Vector2(-6, 6), Color("0b1927"), 3)
		# The continuous ghost shares its offset with candidate mapping.
		if _diagnostics != null:
			_diagnostics.draw(_render_pointer + _offset)
		_draw_ghost(_selected, _render_pointer + _offset, _ghost_unit, 0.80)
	if _return_slot >= 0:
		var progress := clampf(_return_elapsed / RETURN_SECONDS, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - progress, 3)
		_draw_ghost(_return_slot, _return_corner.lerp(_tray_corner(_return_slot), eased), lerpf(_return_unit, _tray_unit(_return_slot), eased), 0.65)
	var font := ThemeDB.fallback_font
	var font_size := 19
	var text_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - text_width) / 2, _board_rect.end.y + 29), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("bbcbd8"))
