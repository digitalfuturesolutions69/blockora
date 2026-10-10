@tool
extends EditorPlugin

var _exporter: EditorExportPlugin

func _enter_tree() -> void:
	_exporter = PlatformExport.new()
	add_export_plugin(_exporter)

func _exit_tree() -> void:
	remove_export_plugin(_exporter)
	_exporter = null

class PlatformExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "BlockoraPlatform"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if not debug:
			push_error("Phase 0B supports debug test exports only; release is not configured.")
		return PackedStringArray(["res://addons/blockora_platform/bin/BlockoraPlatform-debug.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"com.google.android.gms:play-services-ads:25.5.0",
			"com.android.billingclient:billing:9.1.0",
		])
