class_name GameplayAudio
extends Node

# Instrumentation reports actual playback requests, including in headless tests.
signal cue_played(event: String, pitch: float, volume_percent: int)
const MAX_VOICES := 2
var _streams: Dictionary
var _players: Array[AudioStreamPlayer] = []
var _enabled := true
var _volume := 70
var _backgrounded := false
var _paused := false
var _recent_transactions: Array[String] = []

func _ready() -> void:
	_streams = SfxLibrary.create()
	for index in MAX_VOICES:
		var player := AudioStreamPlayer.new()
		player.max_polyphony = 1
		add_child(player)
		_players.append(player)

func set_preferences(enabled: bool, volume_percent: int) -> void:
	_enabled = enabled
	_volume = clampi(volume_percent, 0, 100)
	if not _enabled or _volume == 0:
		stop_all()
	else:
		for player in _players:
			player.volume_db = linear_to_db(float(_volume) / 100.0) - 9.0

func set_backgrounded(value: bool) -> void:
	_backgrounded = value
	if value:
		stop_all()

func set_paused(value: bool) -> void:
	_paused = value
	if value:
		stop_all()

func stop_all() -> void:
	for player in _players:
		player.stop()

func handle_move(result: Dictionary, transaction: String) -> void:
	if result.get("status") != "ok" or transaction.is_empty() or transaction in _recent_transactions:
		return
	# Remember even muted/background transactions: enabling sound never replays them.
	_recent_transactions.append(transaction)
	if _recent_transactions.size() > 32:
		_recent_transactions.pop_front()
	var lines: int = result.cleared_rows.size() + result.cleared_columns.size()
	stop_all() # Replace old feedback; never queue an unbounded backlog.
	var event := "piece_placed"
	if lines > 0:
		event = "line_clear_1" if lines == 1 else ("line_clear_2" if lines == 2 else "line_clear_3_plus")
	_play(event, 0)
	if result.get("game_over", false):
		_play("game_over", 1)
	elif lines > 0 and int(result.get("combo", 0)) > 1:
		_play("combo", 1, 1.0 + 0.10 * (mini(int(result.combo), 5) - 2))

func invalid_placement() -> void:
	_play("invalid_placement", 0)

func _play(event: String, voice: int, pitch: float = 1.0) -> void:
	if not _enabled or _volume == 0 or _backgrounded or _paused or _players.is_empty():
		return
	var player := _players[voice]
	player.stop()
	player.stream = _streams[event]
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(float(_volume) / 100.0) - 9.0
	player.play()
	cue_played.emit(event, pitch, _volume)

func _exit_tree() -> void:
	stop_all()
	for player in _players:
		player.stream = null
