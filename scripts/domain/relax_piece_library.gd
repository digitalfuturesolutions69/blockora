class_name RelaxPieceLibrary
extends PieceLibrary

const VERSION := "relax_catalog_v1"
const ORDER := ["single", "domino_h", "domino_v", "line3_h", "line3_v", "square2", "corner_ne", "corner_nw", "corner_se", "corner_sw"]

func ids() -> Array:
	return ORDER.duplicate()

func get_piece(id: String) -> GamePiece:
	return super.get_piece(id) if ORDER.has(id) else null
