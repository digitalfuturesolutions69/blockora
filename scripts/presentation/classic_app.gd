class_name ClassicApp
extends Control

const State = SessionStateMachine.State
var controller: ClassicController
var surface: PuzzleSurface
var _margin: MarginContainer
var _content: VBoxContainer
var _settings_open := false
var _dialog: ConfirmationDialog
var _sound_player: AudioStreamPlayer
var _message_label: Label

func configure(storage: LocalStorageService) -> void:
	controller = ClassicController.new(storage)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme_value := Theme.new()
	theme_value.default_font_size = 28
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1c3346") if style_name != "pressed" else Color("284d60")
		style.set_corner_radius_all(12)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 15
		style.content_margin_bottom = 15
		if style_name == "focus":
			style.set_border_width_all(2)
			style.border_color = Color("71e2bf")
		theme_value.set_stylebox(style_name, "Button", style)
	theme = theme_value
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_margin.add_child(_content)
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Start a new game?"
	_dialog.dialog_text = "Your current board will be replaced.\nYour best score will be kept."
	_dialog.ok_button_text = "Restart"
	_dialog.confirmed.connect(_start_new)
	add_child(_dialog)
	_sound_player = AudioStreamPlayer.new()
	_sound_player.stream = _make_sound()
	_sound_player.volume_db = -18
	add_child(_sound_player)
	controller.changed.connect(_refresh)
	controller.move_completed.connect(_move_feedback)
	resized.connect(_safe_margins)
	get_window().size_changed.connect(_safe_margins)
	get_tree().quit_on_go_back = false
	_safe_margins()
	_refresh()

func _safe_margins() -> void:
	if surface != null:
		surface.cancel_drag()
	var left := 24
	var right := 24
	var top := 28
	var bottom := 28
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var ratio := size / Vector2(screen)
			left = maxi(left, ceili(safe.position.x * ratio.x) + 12)
			right = maxi(right, ceili((screen.x - safe.end.x) * ratio.x) + 12)
			top = maxi(top, ceili(safe.position.y * ratio.y) + 12)
			bottom = maxi(bottom, ceili((screen.y - safe.end.y) * ratio.y) + 12)
	for pair in [["margin_left", left], ["margin_right", right], ["margin_top", top], ["margin_bottom", bottom]]:
		_margin.add_theme_constant_override(pair[0], pair[1])

func _label(text: String, font_size: int = 24, color: Color = Color("e9f2f5")) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
	return label

func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 96
	button.pressed.connect(action)
	if primary:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("71e2bf")
		style.set_corner_radius_all(12)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", Color("0b1927"))
	_content.add_child(button)
	return button

func _space() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)

func _refresh() -> void:
	if not is_node_ready():
		return
	if surface != null:
		surface.cancel_drag()
		surface = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if _settings_open:
		_show_settings()
	else:
		match controller.state():
			State.HOME: _show_home()
			State.PLAYING: _show_game()
			State.PAUSED: _show_pause()
			State.GAME_OVER: _show_game_over()
	if not controller.save_message().is_empty():
		_message_label = _label(controller.save_message(), 18, Color("ffd083"))
		_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _show_home() -> void:
	_space()
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size.y = 112
	_content.add_child(logo)
	_label("BLOCKORA", 52)
	_label("A little space. A fresh possibility.", 23, Color("a2b8c9"))
	_label("CLASSIC  ·  OFFLINE", 19, Color("71e2bf"))
	_space()
	_label("BEST  " + str(controller.best_score()), 24, Color("ffd083"))
	_button("Play Classic", _request_new, true)
	if controller.can_resume():
		_button("Resume Game", func() -> void: controller.resume())
	_button("Settings", func() -> void: _settings_open = true; _refresh())
	_button("Relax Mode  ·  Coming Soon", func() -> void: pass).disabled = true
	_button("Daily Challenge  ·  Coming Soon", func() -> void: pass).disabled = true
	_space()
	_label("No timer. Make room for your next move.", 19, Color("8ba4b8"))

func _show_game() -> void:
	var session := controller.session()
	_label("CLASSIC", 20, Color("71e2bf"))
	_label("%s" % session.score(), 48)
	_label("BEST  %s  ·  COMBO  %s" % [controller.best_score(), session.combo()], 20, Color("ffd083"))
	surface = PuzzleSurface.new()
	_content.add_child(surface)
	surface.show_session(session, true)
	surface.placement_requested.connect(func(slot: int, origin: Vector2i) -> void: controller.place(slot, origin))
	_button("Pause", func() -> void: controller.pause())

func _show_pause() -> void:
	_space()
	_label("Take a breath", 44)
	_label("Your board can wait.", 24, Color("a2b8c9"))
	_label("SCORE  " + str(controller.session().score()), 30, Color("ffd083"))
	_space()
	_button("Resume", func() -> void: controller.resume(), true)
	_button("Restart", _confirm_restart)
	_button("Home", func() -> void: controller.home())
	_space()

func _show_game_over() -> void:
	_space()
	_label("No moves left", 44)
	_label("A new board is a new beginning.", 23, Color("a2b8c9"))
	_label("FINAL SCORE", 20, Color("71e2bf"))
	var final_text := str(controller.session().score())
	_label(final_text, 44 if final_text.length() > 12 else 64)
	_label("BEST  " + str(controller.best_score()), 24, Color("ffd083"))
	_space()
	_button("Play Again", _start_new, true)
	_button("Home", func() -> void: controller.home())
	_space()

func _show_settings() -> void:
	_space()
	_label("Settings", 44)
	_label("Make yourself comfortable.", 24, Color("a2b8c9"))
	_space()
	var preferences := controller.preferences()
	_button("Sound  ·  " + ("On" if preferences.sound else "Off"), func() -> void: controller.set_preferences(not controller.preferences().sound, controller.preferences().vibration))
	_button("Vibration  ·  " + ("On" if preferences.vibration else "Off"), func() -> void: controller.set_preferences(controller.preferences().sound, not controller.preferences().vibration))
	_button("Back", func() -> void: _settings_open = false; _refresh(), true)
	_space()

func _request_new() -> void:
	if controller.can_resume():
		_confirm_restart()
	else:
		_start_new()

func _confirm_restart() -> void:
	_dialog.popup_centered(Vector2i(440, 220))

func _start_new() -> void:
	controller.new_game(int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec())

func _move_feedback(_result: Dictionary) -> void:
	var preferences := controller.preferences()
	if preferences.sound:
		_sound_player.play()
	if preferences.vibration and OS.has_feature("android"):
		Input.vibrate_handheld(18)

func _make_sound() -> AudioStreamWAV:
	# Original short sine tone, generated once; no downloaded audio or assets.
	var data := PackedByteArray()
	var count := 1600
	data.resize(count * 2)
	for index in count:
		var amplitude := sin(TAU * 660.0 * index / 16000.0) * (1.0 - float(index) / count) * 9000
		data.encode_s16(index * 2, int(amplitude))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 16000
	stream.data = data
	return stream

func interrupt() -> void:
	if surface != null:
		surface.cancel_drag()
	if controller != null and controller.state() == State.PLAYING:
		controller.pause()

func _exit_tree() -> void:
	if _sound_player != null:
		_sound_player.stop()
		_sound_player.stream = null

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		interrupt()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if controller == null:
			return
		if _dialog.visible:
			_dialog.hide()
		elif _settings_open:
			_settings_open = false
			_refresh()
		elif controller.state() == State.PLAYING:
			interrupt()
		elif controller.state() in [State.PAUSED, State.GAME_OVER]:
			controller.home()
		elif controller.state() == State.HOME:
			get_tree().quit()
