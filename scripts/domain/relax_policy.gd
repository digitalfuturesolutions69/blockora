class_name RelaxPolicy
extends RefCounted

const RULESET := "relax_small_v1"
const SCORING := "relax_score_v1"

static func new_session(seed_value: int) -> ClassicSession:
	var library := RelaxPieceLibrary.new()
	return ClassicSession.new(FairPieceProvider.new(seed_value, library), library, ScoreRules.new(1,10,0,0,0), RULESET)

static func snapshot(session: ClassicSession) -> Dictionary:
	return {"schema_version":1, "mode":"relax", "catalog_version":RelaxPieceLibrary.VERSION, "scoring_version":SCORING, "session":session.snapshot()}

# Godot JSON decodes numbers as floats. Accept only integer schema tokens in
# persisted JSON; normalize those verified tokens before strict domain restore.
static func restore_json(payload: String) -> ClassicSession:
	var parser := JSON.new()
	var parse_result: Error = parser.parse(payload)
	if parse_result != OK:
		return null
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not parsed.get("session") is Dictionary:
		return null
	var schema_tokens := RegEx.new()
	schema_tokens.compile('"schema_version"\\s*:\\s*1\\s*[,}]')
	if schema_tokens.search_all(payload).size() != 2:
		return null
	var top_schema: Variant = parsed.get("schema_version")
	var inner_schema: Variant = parsed.session.get("schema_version")
	if not _number(top_schema) or not _number(inner_schema) or top_schema != 1 or inner_schema != 1:
		return null
	parsed.schema_version = 1
	parsed.session.schema_version = 1
	return restore(parsed)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func restore(value: Dictionary) -> ClassicSession:
	if value.size() != 5:
		return null
	var schema: Variant = value.get("schema_version")
	if not schema is int or schema != 1:
		return null
	for field in ["mode", "catalog_version", "scoring_version"]:
		if not value.get(field) is String:
			return null
	if value.mode != "relax" or value.catalog_version != RelaxPieceLibrary.VERSION or value.scoring_version != SCORING or not value.get("session") is Dictionary:
		return null
	var session: Dictionary = value.session
	if session.size() != 8:
		return null
	var inner_schema: Variant = session.get("schema_version")
	if not inner_schema is int or inner_schema != 1:
		return null
	if not session.get("ruleset_version") is String or session.ruleset_version != RULESET:
		return null
	if not _number(session.get("combo")) or session.combo != 0:
		return null
	if not session.get("score") is String or ClassicSession.parse_score(session.score) < 0:
		return null
	if not session.get("session_status") is String or not session.session_status in ["active", "game_over"]:
		return null
	if not session.get("rng") is Dictionary:
		return null
	var rng: Dictionary = session.rng
	if rng.size() != 3:
		return null
	if not rng.get("algorithm") is String or not rng.get("policy") is String or not _number(rng.get("state")):
		return null
	if rng.algorithm != SeededPieceProvider.ALGORITHM or rng.policy != FairPieceProvider.POLICY:
		return null
	# Board/tray and RNG ranges are validated by the shared domain primitives.
	var library := RelaxPieceLibrary.new()
	return ClassicSession.restore_configured(session, library, FairPieceProvider.new(1,library), ScoreRules.new(1,10,0,0,0), RULESET)
