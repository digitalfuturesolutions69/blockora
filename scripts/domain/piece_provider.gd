class_name PieceProvider
extends RefCounted

# Future providers may change generation without changing board or presentation.
func next_tray() -> Array[String]:
	return []

# Legacy/injected providers retain their behavior; fair providers use the board.
func next_tray_for_board(_board: PuzzleBoard) -> Array[String]:
	return next_tray()

func snapshot() -> Dictionary:
	return {}

func restore(_value: Dictionary) -> bool:
	return false
