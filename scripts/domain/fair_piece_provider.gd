class_name FairPieceProvider
extends SeededPieceProvider

const POLICY := "immediate_fit_v1"
const MAX_SAMPLE_ATTEMPTS := 8
var _library: PieceLibrary
var _analyzer: BoardAnalyzer
var _generated := 0
var _repairs := 0
var _sampler_fallbacks := 0
var _max_generation_us := 0

func _init(seed_value: int = 1, library: PieceLibrary = null) -> void:
	super(seed_value, library)
	_library = library if library != null else PieceLibrary.new()
	_analyzer = BoardAnalyzer.new(_library)

func _sample(count: int) -> int:
	var limit := (MODULUS - 1) - ((MODULUS - 1) % count)
	var sample := 0
	for _attempt in MAX_SAMPLE_ATTEMPTS:
		_state = (_state * MULTIPLIER) % MODULUS
		sample = _state - 1
		if sample < limit:
			return sample % count
	_sampler_fallbacks += 1
	return sample % count

func next_tray() -> Array[String]:
	return next_tray_for_board(PuzzleBoard.new())

func next_tray_for_board(board: PuzzleBoard) -> Array[String]:
	var tray: Array[String] = []
	if board == null:
		return tray
	var started := Time.get_ticks_usec()
	for _slot in 3:
		tray.append(_ids[_sample(_ids.size())])
	var usable := false
	for id in tray:
		if board.has_move(_library.get_piece(id)):
			usable = true
			break
	if not usable:
		var fitting := _analyzer.fitting_shapes(board)
		if not fitting.is_empty():
			tray[0] = fitting[_sample(fitting.size())]
			_repairs += 1
	_generated += 1
	_max_generation_us = maxi(_max_generation_us, Time.get_ticks_usec() - started)
	return tray

func snapshot() -> Dictionary:
	return {"algorithm": ALGORITHM, "state": _state, "policy": POLICY}

func restore(value: Dictionary) -> bool:
	if value.get("policy") != POLICY or not super.restore(value):
		return false
	_generated = 0
	_repairs = 0
	_sampler_fallbacks = 0
	_max_generation_us = 0
	return true

func diagnostics() -> Dictionary:
	return {"generated": _generated, "repairs": _repairs, "sampler_fallbacks": _sampler_fallbacks, "max_generation_us": _max_generation_us}
