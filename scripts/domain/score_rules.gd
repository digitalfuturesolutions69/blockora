class_name ScoreRules
extends RefCounted

const MAX_SCORE: int = 9223372036854775807
var _cell_points: int
var _line_points: int
var _multi_points: int
var _combo_points: int
var _combo_cap: int

func _init(cell_points: int = 1, line_points: int = 10, multi_points: int = 5, combo_points: int = 5, combo_cap: int = 5) -> void:
	_cell_points = clampi(cell_points, 0, 1000000)
	_line_points = clampi(line_points, 0, 1000000)
	_multi_points = clampi(multi_points, 0, 1000000)
	_combo_points = clampi(combo_points, 0, 1000000)
	_combo_cap = clampi(combo_cap, 0, 5)

func event(placed_cells: int, lines: int, combo_before: int, total_before: int) -> Dictionary:
	if placed_cells < 1 or placed_cells > 64 or lines < 0 or lines > 16 or total_before < 0:
		return {"status": "invalid"}
	var combo := clampi(combo_before, 0, _combo_cap)
	var delta := _cell_points * placed_cells + _line_points * lines + _multi_points * lines * (lines - 1) + _combo_points * combo
	var granted := mini(delta, MAX_SCORE - total_before)
	return {"status": "ok", "delta": granted, "score": total_before + granted, "combo": mini(combo + 1, _combo_cap) if lines > 0 else 0, "saturated": granted < delta}
