extends AdvertisingService

var _bridge: Object

func _init(bridge: Object) -> void:
	_bridge = bridge

func request_test_ad() -> Dictionary:
	if not is_instance_valid(_bridge) or not _bridge.has_method("load_test_rewarded_ad"):
		return super.request_test_ad()
	_bridge.call("load_test_rewarded_ad")
	# Native callback reports load only. No reward or gameplay mutation exists.
	return {"status": "requested", "reward_granted": false}
