extends LocalStorageService

var _root: String

func _init(root_path: String = "user://foundation") -> void:
	_root = root_path

func _valid_key(key: String) -> bool:
	return not key.is_empty() and key.length() <= 64 and key.is_valid_identifier()

func write_record(key: String, value: Dictionary) -> Error:
	if not _valid_key(key):
		return ERR_INVALID_PARAMETER
	var directory_error := DirAccess.make_dir_recursive_absolute(_root)
	if directory_error != OK:
		return directory_error
	var target := _root.path_join(key + ".json")
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(temporary, target)

func read_record(key: String) -> Dictionary:
	if not _valid_key(key):
		return {"status": "invalid_key", "data": {}}
	var file := FileAccess.open(_root.path_join(key + ".json"), FileAccess.READ)
	if file == null:
		return {"status": "missing", "data": {}}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		return {"status": "corrupt", "data": {}}
	return {"status": "ok", "data": parser.data}
