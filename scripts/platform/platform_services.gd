extends RefCounted

const NullAds = preload("res://scripts/platform/noop/null_advertising_service.gd")
const NullBilling = preload("res://scripts/platform/noop/null_billing_service.gd")
const NullAnalytics = preload("res://scripts/platform/noop/null_analytics_service.gd")
const NullCrashes = preload("res://scripts/platform/noop/null_crash_reporting_service.gd")
const JsonStorage = preload("res://scripts/infrastructure/json_local_storage.gd")
const AndroidAds = preload("res://scripts/platform/android/android_advertising_service.gd")
const AndroidBilling = preload("res://scripts/platform/android/android_billing_service.gd")

static func create(enable_android_spike: bool = false) -> Dictionary:
	var result := {
		"advertising": NullAds.new(), "billing": NullBilling.new(),
		"analytics": NullAnalytics.new(), "crash_reporting": NullCrashes.new(),
		"storage": JsonStorage.new(),
	}
	if enable_android_spike and OS.has_feature("android") and Engine.has_singleton("BlockoraPlatform"):
		var bridge := Engine.get_singleton("BlockoraPlatform")
		result.advertising = AndroidAds.new(bridge)
		result.billing = AndroidBilling.new(bridge)
	return result
