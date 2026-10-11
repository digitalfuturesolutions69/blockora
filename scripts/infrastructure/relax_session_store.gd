class_name RelaxSessionStore
extends RefCounted

const KEYS := ["relax_session_v1_a", "relax_session_v1_b"]
var _storage: LocalStorageService
var _revision := 0
var _slot := -1
var warning := ""
var incompatible := false

func _init(storage: LocalStorageService) -> void:
	_storage = storage

func load_session() -> ClassicSession:
	var selected: ClassicSession
	warning = ""
	for index in 2:
		var record := _storage.read_record(KEYS[index])
		if record.status == "missing":
			continue
		if record.status != "ok":
			warning = "Relax save could not be read; a valid backup may be available."
			continue
		var value: Dictionary = record.data
		var schema: Variant = value.get("schema_version")
		# LocalStorage JSON numbers may be integral floats; never compare other types.
		if not (schema is int or schema is float) or not is_finite(float(schema)) or schema != 1:
			incompatible = true
			warning = "Relax save version is incompatible. Existing files are preserved."
			continue
		var revision: Variant = value.get("revision")
		var payload: Variant = value.get("payload")
		if not (revision is int or revision is float) or not is_finite(float(revision)) or revision < 1 or revision > 2147483647 or int(revision) != revision or not payload is String or payload.length() > 65536 or not value.get("sha256") is String or value.sha256 != payload.sha256_text():
			warning = "Relax save is damaged; using a valid backup if available."
			continue
		var candidate := RelaxPolicy.restore_json(payload)
		if candidate == null:
			incompatible = true
			warning = "Relax save rules or data are incompatible. Existing files are preserved."
			continue
		if int(revision) > _revision:
			_revision = int(revision)
			_slot = index
			selected = candidate
	return selected

func save_session(session: ClassicSession) -> Error:
	if incompatible or _revision >= 2147483647:
		return ERR_UNAVAILABLE
	var payload := JSON.stringify(RelaxPolicy.snapshot(session))
	if payload.length() > 65536:
		return ERR_OUT_OF_MEMORY
	var next_slot := 0 if _slot != 0 else 1
	var error := _storage.write_record(KEYS[next_slot], {"schema_version":1,"revision":_revision+1,"payload":payload,"sha256":payload.sha256_text()})
	if error == OK:
		_slot = next_slot
		_revision += 1
	return error
