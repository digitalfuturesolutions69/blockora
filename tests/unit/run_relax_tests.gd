extends SceneTree

const Storage = preload("res://scripts/infrastructure/json_local_storage.gd")
var checks := 0
var failures := 0
var library := RelaxPieceLibrary.new()

class MemoryStorage extends LocalStorageService:
	var records := {}
	var fail_writes := false
	func read_record(key: String) -> Dictionary:
		return {"status":"ok","data":records[key].duplicate(true)} if records.has(key) else {"status":"missing","data":{}}
	func write_record(key: String, value: Dictionary) -> Error:
		if fail_writes: return ERR_CANT_CREATE
		records[key] = value.duplicate(true)
		return OK

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("RELAX FAIL: " + label)

func _run() -> void:
	check(library.ids() == RelaxPieceLibrary.ORDER and library.ids().size() == 10, "frozen ten-shape order")
	for id in library.ids():
		check(library.get_piece(id).serialize() == PieceLibrary.new().get_piece(id).serialize(), "shared catalog geometry " + id)
	check(library.get_piece("line5_h") == null, "large Classic shape excluded")
	var score := ScoreRules.new(1,10,0,0,0)
	check(score.event(4,4,5,0).delta == 44 and score.event(4,4,5,0).combo == 0, "no combo or multiline bonus")
	var session := RelaxPolicy.new_session(42)
	var before := RelaxPolicy.snapshot(session)
	check(session.place(0,Vector2i(-1,0)).status == "invalid" and RelaxPolicy.snapshot(session) == before, "invalid atomic including RNG")
	check(ClassicSession.restore(session.snapshot()) == null, "Relax cannot load as Classic")
	check(RelaxPolicy.restore(before).snapshot() == session.snapshot(), "restore exact policy")
	var fixture := before.duplicate(true)
	fixture.session.board = [252,252,3,3,3,3,3,3]
	fixture.session.tray = ["square2","single","single"]
	session = RelaxPolicy.restore(fixture)
	var result := session.place(0,Vector2i.ZERO)
	check(result.cleared_rows == [0,1] and result.cleared_columns == [0,1] and session.score() == 44 and session.combo() == 0, "cross clear and exact scoring")
	check(session.tray() == ["","single","single"], "no premature refill")
	session.place(1,Vector2i.ZERO)
	session.place(2,Vector2i(1,0))
	check(not session.tray().has("") and session.tray().size() == 3, "full refill")
	fixture = before.duplicate(true)
	fixture.session.board = [170,85,170,85,170,85,170,85]
	fixture.session.tray = ["single","square2",""]
	session = RelaxPolicy.restore(fixture)
	check(session.place(0,Vector2i.ZERO).game_over and session.finished(), "remaining tray blocked game over")
	check(session.place(1,Vector2i.ZERO).status == "invalid", "no continue after game over")
	fixture.session.session_status = "game_over"
	fixture.session.tray = ["square2","square2",""]
	check(RelaxPolicy.restore(fixture).finished(), "terminal state restores")
	for field in ["schema_version","catalog_version","scoring_version","mode"]:
		var bad := before.duplicate(true)
		bad[field] = "unsupported"
		check(RelaxPolicy.restore(bad) == null, "unknown version rejected " + field)
	var bad := before.duplicate(true)
	bad.session.tray[0] = "line5_h"
	check(RelaxPolicy.restore(bad) == null, "foreign shape rejected")
	bad = before.duplicate(true)
	bad.session.combo = 1
	check(RelaxPolicy.restore(bad) == null, "foreign scoring state rejected")
	var malformed_checks_start := checks
	for schema in ["1",1.0,true,null,-1,2,0]:
		bad = before.duplicate(true)
		bad.schema_version = schema
		check(RelaxPolicy.restore(bad) == null, "reject schema type/version " + str(schema))
	bad = before.duplicate(true)
	bad.erase("schema_version")
	check(RelaxPolicy.restore(bad) == null, "missing schema")
	check(RelaxPolicy.restore(before) != null, "supported integer schema")
	for field in before.keys():
		bad = before.duplicate(true)
		bad.erase(field)
		check(RelaxPolicy.restore(bad) == null,"missing outer field " + field)
	for field in before.session.keys():
		bad = before.duplicate(true)
		bad.session.erase(field)
		check(RelaxPolicy.restore(bad) == null,"missing session field " + field)
	for field in ["mode","catalog_version","scoring_version","session"]:
		for wrong in [null,true,7,1.5,[],{}]:
			bad = before.duplicate(true)
			bad[field] = wrong
			check(RelaxPolicy.restore(bad) == null,"wrong outer type " + field)
	for field in ["schema_version","ruleset_version","score","combo","board","tray","rng","session_status"]:
		for wrong in [null,true,"wrong",[],{}]:
			bad = before.duplicate(true)
			bad.session[field] = wrong
			check(RelaxPolicy.restore(bad) == null,"wrong session field " + field)
	for field in before.session.rng.keys():
		for wrong in [null,true,"wrong",[],{}]:
			bad = before.duplicate(true)
			bad.session.rng[field] = wrong
			check(RelaxPolicy.restore(bad) == null,"wrong RNG field " + field)
	for wrong in [0,-1,2147483647,1.5,INF,NAN]:
		bad = before.duplicate(true)
		bad.session.rng.state = wrong
		check(RelaxPolicy.restore(bad) == null,"RNG range/finiteness")
	for wrong in [["bad",0,0,0,0,0,0,0],[true,0,0,0,0,0,0,0],[256,0,0,0,0,0,0,0],[]]:
		bad = before.duplicate(true)
		bad.session.board = wrong
		check(RelaxPolicy.restore(bad) == null,"malformed board rows")
	for wrong in [[1,"single","single"],[null,"single","single"],["single"], ["","",""]]:
		bad = before.duplicate(true)
		bad.session.tray = wrong
		check(RelaxPolicy.restore(bad) == null,"malformed tray cells")
	var json_save := JSON.stringify(before)
	check(RelaxPolicy.restore_json(json_save).snapshot() == RelaxPolicy.restore(before).snapshot(),"valid persisted integer tokens decoded safely")
	check(RelaxPolicy.restore_json(json_save.replace('"schema_version":1','"schema_version":1.0')) == null,"float schema token rejected in persisted JSON")
	for damaged in ["",json_save.substr(0,json_save.length()/2),"{broken","null","[]","true","123",json_save+" invalid trailing content"]:
		check(RelaxPolicy.restore_json(damaged) == null,"truncated/corrupt payload safely rejected")
	for schema_json in ['"1"','1.0','true','null','-1','2']:
		check(RelaxPolicy.restore_json(json_save.replace('"schema_version":1','"schema_version":'+schema_json)) == null,"parsed JSON schema rejected " + schema_json)
	var missing_schema := before.duplicate(true)
	missing_schema.erase("schema_version")
	check(RelaxPolicy.restore_json(JSON.stringify(missing_schema)) == null,"JSON missing schema rejected")
	var valid_state_before := RelaxPolicy.snapshot(RelaxPolicy.restore(before))
	check(RelaxPolicy.restore_json("{}")==null and RelaxPolicy.snapshot(RelaxPolicy.restore(before)) == valid_state_before,"malformed reads cannot mutate valid state")
	check(ClassicSession.restore(ClassicSession.new().snapshot()) != null,"valid Classic remains loadable")
	print("RELAX MALFORMED MATRIX: %d checks, cumulative failures=%d" % [checks-malformed_checks_start,failures])
	var analyzer := BoardAnalyzer.new(library)
	var board := PuzzleBoard.deserialize([170,85,170,85,170,85,170,85])
	var a := FairPieceProvider.new(123,library)
	var b := FairPieceProvider.new(123,library)
	for index in 1000:
		var tray := a.next_tray_for_board(board)
		check(tray == b.next_tray_for_board(board) and a.snapshot() == b.snapshot(), "deterministic checker draw %d" % index)
		check(not analyzer.tray_summary(board,tray).game_over, "checker immediate fit")
	check(a.diagnostics().repairs > 0, "repair exercised")
	var storage := MemoryStorage.new()
	var classic := ClassicController.new(storage)
	classic.new_game(222)
	var original := storage.records.duplicate(true)
	var relax := RelaxController.new(storage)
	check(relax.new_game(42), "new Relax session")
	before = relax.session().snapshot()
	check(not relax.new_game(7) and relax.session().snapshot() == before, "playing restart rejected")
	check(relax.pause() and relax.resume() and relax.session().snapshot() == before, "pause resume exact")
	check(RelaxController.new(storage).session().snapshot() == before, "controller reload exact")
	storage.fail_writes = true
	result = relax.place(0,Vector2i.ZERO)
	check(result.status == "save_error" and relax.session().snapshot() == before, "failed save cannot commit move")
	storage.fail_writes = false
	check(relax.place(0,Vector2i.ZERO).status == "ok", "valid placement commits")
	for key in original:
		check(storage.records[key] == original[key], "Classic save unchanged " + key)
	relax.pause()
	check(relax.new_game(7) and relax.session().score() == 0, "allowed confirmed restart command")
	var current := RelaxController.new(storage).session().snapshot()
	var newest := 0 if storage.records[RelaxSessionStore.KEYS[0]].revision > storage.records[RelaxSessionStore.KEYS[1]].revision else 1
	storage.records[RelaxSessionStore.KEYS[newest]].sha256 = "damaged"
	var recovered := RelaxController.new(storage)
	check(recovered.session() != null and recovered.session().snapshot() != current and not recovered.save_message().is_empty(), "damaged latest slot recovers backup with warning")
	storage.records[RelaxSessionStore.KEYS[newest]] = {"schema_version":99}
	recovered = RelaxController.new(storage)
	check(not recovered.new_game(9), "future schema preserved read-only")
	var path := "user://relax_unit_" + str(Time.get_ticks_usec())
	var disk := Storage.new(path)
	var writer := RelaxController.new(disk)
	writer.new_game(73)
	writer.place(0,Vector2i.ZERO)
	check(RelaxController.new(Storage.new(path)).session().snapshot() == writer.session().snapshot(), "actual JSON save/reload continuation")
	for key in RelaxSessionStore.KEYS: DirAccess.remove_absolute(path.path_join(key+".json"))
	DirAccess.remove_absolute(path)
	print("RELAX UNIT RESULT: %d assertions, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
