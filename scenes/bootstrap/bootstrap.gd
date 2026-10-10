extends Control

const Services = preload("res://scripts/platform/platform_services.gd")
var services: Dictionary
var initialized := false

func _ready() -> void:
	# External SDK requests remain opt-in; offline bootstrap uses no-op adapters.
	services = Services.create()
	initialized = services.size() == 5
	print("BLOCKORA_BOOTSTRAP_READY")
