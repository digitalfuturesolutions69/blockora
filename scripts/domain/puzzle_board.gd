class_name PuzzleBoard
extends RefCounted

enum CellState { EMPTY, OCCUPIED }
const SIZE := 8
var _rows := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])

static func valid_coordinate(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < SIZE and cell.y >= 0 and cell.y < SIZE

func read_cell(cell: Vector2i) -> int:
	if not valid_coordinate(cell):
		return -1
	return CellState.OCCUPIED if (_rows[cell.y] & (1 << cell.x)) != 0 else CellState.EMPTY

func serialize() -> Array:
	return Array(_rows)

static func deserialize(value: Variant) -> PuzzleBoard:
	if not value is Array or value.size() != SIZE:
		return null
	var board := PuzzleBoard.new()
	for y in SIZE:
		var row: Variant = value[y]
		if not (row is int or row is float) or not is_finite(float(row)) or row < 0 or row > 255 or int(row) != row:
			return null
		board._rows[y] = int(row)
	return board

func can_place(piece: GamePiece, origin: Vector2i) -> bool:
	if piece == null or piece.cell_count() == 0:
		return false
	var dimensions := piece.dimensions()
	if origin.x < 0 or origin.y < 0 or origin.x + dimensions.x > SIZE or origin.y + dimensions.y > SIZE:
		return false
	for cell in piece._cells:
		if (_rows[origin.y + cell.y] & (1 << (origin.x + cell.x))) != 0:
			return false
	return true

func completed_rows() -> Array[int]:
	var result: Array[int] = []
	for y in SIZE:
		if _rows[y] == 255:
			result.append(y)
	return result

func completed_columns() -> Array[int]:
	var mask := 255
	for row in _rows:
		mask &= row
	var result: Array[int] = []
	for x in SIZE:
		if mask & (1 << x):
			result.append(x)
	return result

func has_move(piece: GamePiece) -> bool:
	if piece == null:
		return false
	var dimensions := piece.dimensions()
	for y in SIZE - dimensions.y + 1:
		for x in SIZE - dimensions.x + 1:
			if can_place(piece, Vector2i(x, y)):
				return true
	return false

func clear_completed_lines() -> Dictionary:
	# Detect both directions before removing their union.
	var rows := completed_rows()
	var columns := completed_columns()
	var column_mask := 0
	for x in columns:
		column_mask |= 1 << x
	for y in SIZE:
		_rows[y] = 0 if rows.has(y) else _rows[y] & (255 ^ column_mask)
	return {"cleared_rows": rows, "cleared_columns": columns, "unique_cleared_cells": rows.size() * SIZE + columns.size() * SIZE - rows.size() * columns.size()}

func place_and_clear(piece: GamePiece, origin: Vector2i) -> Dictionary:
	if not can_place(piece, origin):
		return {"status": "invalid"}
	for cell in piece._cells:
		_rows[origin.y + cell.y] |= 1 << (origin.x + cell.x)
	var result := clear_completed_lines()
	result.merge({"status": "ok", "piece_id": piece.shape_id(), "placed_cells": piece.cell_count(), "board": serialize()})
	return result
