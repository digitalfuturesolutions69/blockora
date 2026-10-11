class_name ClassicSession
extends RefCounted

const RULESET := "classic_v1"
var _board := PuzzleBoard.new()
var _library: PieceLibrary
var _provider: PieceProvider
var _scoring: ScoreRules
var _tray: Array[String] = []
var _score := 0
var _combo := 0
var _finished := false
var _ruleset := RULESET

func _init(provider: PieceProvider = null, library: PieceLibrary = null, scoring: ScoreRules = null, ruleset: String = RULESET) -> void:
	_ruleset = ruleset
	_library = library if library != null else PieceLibrary.new()
	_provider = provider if provider != null else FairPieceProvider.new()
	_scoring = scoring if scoring != null else ScoreRules.new()
	_tray = _provider.next_tray_for_board(_board)
	if not _valid_tray(_tray):
		_tray = ["", "", ""]
		_finished = true

func _valid_tray(value: Array[String]) -> bool:
	if value.size() != 3:
		return false
	for id in value:
		if _library.get_piece(id) == null:
			return false
	return true

func board() -> PuzzleBoard:
	# Consumers receive an independent snapshot, never the mutable session board.
	return PuzzleBoard.deserialize(_board.serialize())

func tray() -> Array[String]:
	return _tray.duplicate()

func score() -> int:
	return _score

func combo() -> int:
	return _combo

func finished() -> bool:
	return _finished

func piece_at(slot: int) -> GamePiece:
	return _library.get_piece(_tray[slot]) if slot >= 0 and slot < 3 and not _tray[slot].is_empty() else null

func can_place(slot: int, origin: Vector2i) -> bool:
	return not _finished and _board.can_place(piece_at(slot), origin)

func has_remaining_move() -> bool:
	for id in _tray:
		if not id.is_empty() and _board.has_move(_library.get_piece(id)):
			return true
	return false

func place(slot: int, origin: Vector2i) -> Dictionary:
	if not can_place(slot, origin):
		return {"status": "invalid"}
	var candidate_board := board()
	var result := candidate_board.place_and_clear(piece_at(slot), origin)
	var scored := _scoring.event(result.placed_cells, result.cleared_rows.size() + result.cleared_columns.size(), _combo, _score)
	var candidate_tray := tray()
	candidate_tray[slot] = ""
	if candidate_tray == ["", "", ""]:
		var previous_rng := _provider.snapshot()
		candidate_tray = _provider.next_tray_for_board(candidate_board)
		if not _valid_tray(candidate_tray):
			_provider.restore(previous_rng)
			return {"status": "provider_error"}
	_board = candidate_board
	_tray = candidate_tray
	_score = scored.score
	_combo = scored.combo
	_finished = not has_remaining_move()
	result.merge({"score": _score, "score_delta": scored.delta, "combo": _combo, "game_over": _finished})
	return result

func snapshot() -> Dictionary:
	return {"schema_version": 1, "ruleset_version": _ruleset, "board": _board.serialize(), "tray": _tray.duplicate(), "score": str(_score), "combo": _combo, "rng": _provider.snapshot(), "session_status": "game_over" if _finished else "active"}

static func parse_score(value: Variant) -> int:
	if not value is String or value.is_empty() or value.length() > 19:
		return -1
	if value != "0" and value.begins_with("0"):
		return -1
	for character in value:
		if character < "0" or character > "9":
			return -1
	if value.length() == 19 and value > str(ScoreRules.MAX_SCORE):
		return -1
	return value.to_int()

static func restore(value: Dictionary) -> ClassicSession:
	if not value.get("rng") is Dictionary:
		return null
	var provider: PieceProvider
	if value.rng.has("policy"):
		if value.rng.policy != FairPieceProvider.POLICY:
			return null
		provider = FairPieceProvider.new()
	else:
		provider = SeededPieceProvider.new()
	return restore_configured(value, PieceLibrary.new(), provider, ScoreRules.new(), RULESET)

# Mode policies explicitly supply their versioned catalog, scoring and provider.
# Classic restore above retains its original save contract and defaults.
static func restore_configured(value: Dictionary, library: PieceLibrary, provider: PieceProvider, scoring: ScoreRules, ruleset: String) -> ClassicSession:
	if value.get("schema_version") != 1 or value.get("ruleset_version") != ruleset:
		return null
	var board_value := PuzzleBoard.deserialize(value.get("board"))
	var score_value := parse_score(value.get("score"))
	var combo_value: Variant = value.get("combo")
	var tray_value: Variant = value.get("tray")
	var status: Variant = value.get("session_status")
	if board_value == null or score_value < 0 or not (combo_value is int or combo_value is float):
		return null
	if not is_finite(float(combo_value)) or combo_value < 0 or combo_value > 5 or int(combo_value) != combo_value:
		return null
	if not tray_value is Array or tray_value.size() != 3 or not status in ["active", "game_over"] or not value.get("rng") is Dictionary:
		return null
	# Committed sessions never contain completed lines or an entirely consumed tray.
	if not board_value.completed_rows().is_empty() or not board_value.completed_columns().is_empty() or tray_value == ["", "", ""]:
		return null
	for id in tray_value:
		if not id is String or (not id.is_empty() and library.get_piece(id) == null):
			return null
	if not provider.restore(value.rng):
		return null
	var session := ClassicSession.new(provider, library, scoring, ruleset)
	# Constructor generation is discarded; restore exact next-draw state afterwards.
	provider.restore(value.rng)
	session._board = board_value
	session._tray.assign(tray_value)
	session._score = score_value
	session._combo = int(combo_value)
	session._finished = status == "game_over"
	if session._finished == session.has_remaining_move():
		return null
	return session
