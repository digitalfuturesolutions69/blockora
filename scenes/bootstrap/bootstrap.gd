extends Control

const Services = preload("res://scripts/platform/platform_services.gd")
const App = preload("res://scripts/presentation/classic_app.gd")
var services: Dictionary
var initialized := false
var app: ClassicApp

func _ready() -> void:
	# External SDK requests remain opt-in; offline bootstrap uses no-op adapters.
	services = Services.create()
	initialized = services.size() == 5
	app = App.new()
	app.configure(services.storage)
	add_child(app)
	print("BLOCKORA_BOOTSTRAP_READY")
