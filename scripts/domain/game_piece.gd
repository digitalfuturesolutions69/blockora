class_name GamePiece
extends RefCounted

var _id: String
var _cells: Array[Vector2i] = []
var _dimensions := Vector2i.ZERO
var _render_key: String

static func create(shape_id: String, coordinates: Array, render_key: String = "mint") -> GamePiece:
	if shape_id.is_empty() or not shape_id.is_valid_identifier() or coordinates.is_empty() or coordinates.size() > 64:
		return null
	var seen := {}
	var minimum := Vector2i(8, 8)
	var maximum := Vector2i.ZERO
	for value in coordinates:
		if not value is Vector2i or value.x < 0 or value.y < 0 or value.x >= 8 or value.y >= 8 or seen.has(value):
			return null
		seen[value] = true
		minimum = minimum.min(value)
		maximum = maximum.max(value)
	if minimum != Vector2i.ZERO:
		return null
	var visited := {coordinates[0]: true}
	var pending: Array[Vector2i] = [coordinates[0]]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if seen.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	if visited.size() != seen.size():
		return null
	var piece := GamePiece.new()
	piece._id = shape_id
	piece._render_key = render_key
	for cell in coordinates:
		piece._cells.append(cell)
	piece._cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y * 8 + a.x < b.y * 8 + b.x)
	piece._dimensions = maximum + Vector2i.ONE
	return piece

func shape_id() -> String:
	return _id

func cells() -> Array[Vector2i]:
	return _cells.duplicate()

func cell_count() -> int:
	return _cells.size()

func dimensions() -> Vector2i:
	return _dimensions

func render_key() -> String:
	return _render_key

func serialize() -> Dictionary:
	var coordinates: Array = []
	for cell in _cells:
		coordinates.append([cell.x, cell.y])
	return {"id": _id, "cells": coordinates, "render_key": _render_key}
