extends BillingService

var _bridge: Object

func _init(bridge: Object) -> void:
	_bridge = bridge

func request_purchase() -> Dictionary:
	# Purchase launch and verified entitlement are outside this feasibility scaffold.
	return {"status": "not_implemented", "product_id": REMOVE_ADS_PRODUCT}

func restore_purchases() -> Dictionary:
	if not is_instance_valid(_bridge) or not _bridge.has_method("restore_purchases"):
		return super.restore_purchases()
	_bridge.call("restore_purchases")
	return {"status": "requested"}
