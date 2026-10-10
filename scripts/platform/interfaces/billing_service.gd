class_name BillingService
extends RefCounted

const REMOVE_ADS_PRODUCT := "remove_ads_lifetime"

func has_remove_ads_entitlement() -> bool:
	return false

func request_purchase() -> Dictionary:
	return {"status": "unavailable", "product_id": REMOVE_ADS_PRODUCT}

func restore_purchases() -> Dictionary:
	return {"status": "unavailable"}
