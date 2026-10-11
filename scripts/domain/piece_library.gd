class_name PieceLibrary
extends RefCounted

# Stable order is part of ruleset classic_v1 and the seeded generation contract.
const DEFINITIONS := {
	"single": [[0, 0]],
	"domino_h": [[0, 0], [1, 0]], "domino_v": [[0, 0], [0, 1]],
	"line3_h": [[0, 0], [1, 0], [2, 0]], "line3_v": [[0, 0], [0, 1], [0, 2]],
	"line4_h": [[0, 0], [1, 0], [2, 0], [3, 0]], "line4_v": [[0, 0], [0, 1], [0, 2], [0, 3]],
	"line5_h": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]], "line5_v": [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]],
	"square2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"corner_ne": [[0, 0], [1, 0], [1, 1]], "corner_nw": [[0, 0], [1, 0], [0, 1]],
	"corner_se": [[1, 0], [0, 1], [1, 1]], "corner_sw": [[0, 0], [0, 1], [1, 1]],
	"l4_left": [[0, 0], [0, 1], [0, 2], [1, 2]], "l4_right": [[1, 0], [1, 1], [0, 2], [1, 2]],
	"l4_top": [[0, 0], [1, 0], [2, 0], [0, 1]], "l4_bottom": [[0, 0], [0, 1], [1, 1], [2, 1]],
	"t_down": [[0, 0], [1, 0], [2, 0], [1, 1]], "t_up": [[1, 0], [0, 1], [1, 1], [2, 1]],
	"t_right": [[0, 0], [0, 1], [1, 1], [0, 2]], "t_left": [[1, 0], [0, 1], [1, 1], [1, 2]],
	"s4": [[1, 0], [2, 0], [0, 1], [1, 1]], "z4": [[0, 0], [1, 0], [1, 1], [2, 1]],
}
const COLORS := ["mint", "gold", "blue", "rose", "lavender"]
var _pieces := {}

func _init() -> void:
	var index := 0
	for id in DEFINITIONS:
		var coordinates: Array = []
		for cell in DEFINITIONS[id]:
			coordinates.append(Vector2i(cell[0], cell[1]))
		_pieces[id] = GamePiece.create(id, coordinates, COLORS[index % COLORS.size()])
		index += 1

func ids() -> Array:
	return _pieces.keys()

func get_piece(id: String) -> GamePiece:
	return _pieces.get(id)

func matches_serialized(value: Dictionary) -> bool:
	var piece := get_piece(str(value.get("id", "")))
	return piece != null and piece.serialize() == value
