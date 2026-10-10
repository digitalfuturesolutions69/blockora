extends SceneTree

const Services = preload("res://scripts/platform/platform_services.gd")
const Storage = preload("res://scripts/infrastructure/json_local_storage.gd")
const AndroidAds = preload("res://scripts/platform/android/android_advertising_service.gd")
const AndroidBilling = preload("res://scripts/platform/android/android_billing_service.gd")
var checks := 0
var failures := 0
var cases := 0

class FakeBridge extends RefCounted:
	var ad_calls := 0
	var restore_calls := 0
	func load_test_rewarded_ad() -> void:
		ad_calls += 1
	func restore_purchases() -> void:
		restore_calls += 1

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var services := Services.create()
	cases += 1
	check(services.size() == 5, "all five service boundaries load")
	check(services.advertising is AdvertisingService, "advertising interface")
	check(services.billing is BillingService, "billing interface")
	check(services.analytics is AnalyticsService, "analytics interface")
	check(services.crash_reporting is CrashReportingService, "crash interface")
	check(services.storage is LocalStorageService, "local storage interface")
	cases += 1
	var ad_result: Dictionary = services.advertising.request_test_ad()
	check(ad_result.status == "unavailable", "no-op ads unavailable")
	check(not ad_result.reward_granted, "no-op ads cannot grant reward")
	cases += 1
	check(not services.billing.has_remove_ads_entitlement(), "no-op premium false")
	check(services.billing.request_purchase().status == "unavailable", "no-op purchase unavailable")
	check(services.billing.restore_purchases().status == "unavailable", "no-op restore unavailable")
	check(not services.billing.has_remove_ads_entitlement(), "restore cannot create fake entitlement")
	cases += 1
	check(not services.analytics.record_event("foundation_test"), "analytics disabled")
	check(not services.crash_reporting.report_error("test"), "remote crash reporting disabled")
	check(not Services.create(true).billing.has_remove_ads_entitlement(), "missing native service fails closed")
	cases += 1
	var bridge := FakeBridge.new()
	var ads := AndroidAds.new(bridge)
	check(ads.request_test_ad().status == "requested", "ad bridge request")
	check(bridge.ad_calls == 1, "ad called once")
	check(not ads.request_test_ad().reward_granted, "load callback does not grant reward")
	var billing := AndroidBilling.new(bridge)
	check(billing.restore_purchases().status == "requested", "billing restore bridge request")
	check(bridge.restore_calls == 1, "restore called once")
	check(billing.request_purchase().status == "not_implemented", "purchase launch honestly scaffolded")
	check(not billing.has_remove_ads_entitlement(), "bridge never invents entitlement")
	check(AndroidAds.new(null).request_test_ad().status == "unavailable", "null bridge ads fallback")
	check(AndroidBilling.new(null).restore_purchases().status == "unavailable", "null bridge billing fallback")
	cases += 1
	var storage_root := "user://phase0b_test_" + str(Time.get_ticks_usec())
	var storage := Storage.new(storage_root)
	check(storage.read_record("settings").status == "missing", "missing record handled")
	check(storage.write_record("../escape", {}) == ERR_INVALID_PARAMETER, "reject path traversal")
	check(storage.write_record("settings", {"language": "id", "sound": false}) == OK, "atomic write")
	check(storage.read_record("settings").data == {"language": "id", "sound": false}, "read equals written record")
	check(storage.write_record("settings", {"language": "en"}) == OK, "replace existing record")
	check(storage.read_record("settings").data == {"language": "en"}, "replace committed")
	check(not FileAccess.file_exists(storage_root.path_join("settings.json.tmp")), "no temporary file after commit")
	var corrupt := FileAccess.open(storage_root.path_join("settings.json"), FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(storage.read_record("settings").status == "corrupt", "corrupt record handled")
	DirAccess.remove_absolute(storage_root.path_join("settings.json"))
	DirAccess.remove_absolute(storage_root)
	cases += 1
	var scene := load("res://scenes/bootstrap/bootstrap.tscn") as PackedScene
	check(scene != null, "bootstrap scene loads")
	var bootstrap := scene.instantiate()
	root.add_child(bootstrap)
	await process_frame
	check(bootstrap.initialized, "bootstrap initialized")
	check(not bootstrap.services.billing.has_remove_ads_entitlement(), "bootstrap premium denied")
	bootstrap.queue_free()
	await process_frame
	print("RESULT: %d cases, %d checks, %d failures" % [cases, checks, failures])
	quit(0 if failures == 0 and checks > 0 else 1)
