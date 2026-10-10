class_name LocalStorageService
extends RefCounted

func write_record(_key: String, _value: Dictionary) -> Error:
	return ERR_UNAVAILABLE

func read_record(_key: String) -> Dictionary:
	return {"status": "unavailable", "data": {}}
