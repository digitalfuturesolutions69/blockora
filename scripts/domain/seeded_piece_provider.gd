class_name SeededPieceProvider
extends PieceProvider

const MODULUS := 2147483647
const MULTIPLIER := 16807
const ALGORITHM := "park_miller_16807_v1"
var _state := 1
var _ids: Array

func _init(seed_value: int = 1, library: PieceLibrary = null) -> void:
	_state = ((seed_value % (MODULUS - 1)) + (MODULUS - 1)) % (MODULUS - 1) + 1
	_ids = (library if library != null else PieceLibrary.new()).ids()

func next_tray() -> Array[String]:
	var tray: Array[String] = []
	# Rejection sampling avoids modulo bias; duplicate shapes are allowed.
	var limit := (MODULUS - 1) - ((MODULUS - 1) % _ids.size())
	while tray.size() < 3:
		_state = (_state * MULTIPLIER) % MODULUS
		var sample := _state - 1
		if sample < limit:
			tray.append(_ids[sample % _ids.size()])
	return tray

func snapshot() -> Dictionary:
	return {"algorithm": ALGORITHM, "state": _state}

func restore(value: Dictionary) -> bool:
	var candidate: Variant = value.get("state")
	if value.get("algorithm") != ALGORITHM or not (candidate is int or candidate is float):
		return false
	if not is_finite(float(candidate)) or candidate < 1 or candidate >= MODULUS or int(candidate) != candidate:
		return false
	_state = int(candidate)
	return true
