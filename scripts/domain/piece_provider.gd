class_name PieceProvider
extends RefCounted

# Future providers may change generation without changing board or presentation.
func next_tray() -> Array[String]:
	return []

func snapshot() -> Dictionary:
	return {}

func restore(_value: Dictionary) -> bool:
	return false
