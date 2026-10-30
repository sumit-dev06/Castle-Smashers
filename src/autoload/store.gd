extends Node
## Google Play Billing wrapper. No-op stub when the plugin is missing (desktop).
## Product IDs: docs/MONETIZATION.md. Integration: phase 3.

signal purchased(product_id: String)
signal purchase_failed(product_id: String)


## Emitted after a product's contents were added to the save: {coins, gems, blueprints, skin, no_ads}.
signal granted(product_id: String, gives: Dictionary)


func _ready() -> void:
	purchased.connect(_grant)


## Catalogue entry for a Play product id (balance.json -> shop), {} if unknown.
func product(product_id: String) -> Dictionary:
	var shop: Dictionary = Data.balance["shop"]
	for list: String in ["offers", "gems"]:
		for e: Dictionary in shop[list]:
			if String(e.get("iap", e["id"])) == product_id:
				return e
	if product_id == String(shop["remove_ads"]["iap"]):
		return {"id": product_id, "gives": {}, "no_ads": true}
	return {}


func owns(product_id: String) -> bool:
	return (Save.data.get("iap_owned", []) as Array).has(product_id)


func _grant(product_id: String) -> void:
	var e: Dictionary = product(product_id)
	if e.is_empty():
		return
	var gives: Dictionary = (e.get("gives", {}) as Dictionary).duplicate()
	for k: String in ["coins", "gems", "blueprints"]:
		if gives.has(k):
			Save.add(k, int(gives[k]), false, false)
	if e.has("skin"):
		Progression.grant("skins", String(e["skin"]))
		gives["skin"] = e["skin"]
	if bool(e.get("no_ads", false)) or product_id == "starter_pack":
		Save.data["no_ads"] = true
		gives["no_ads"] = true
	if product_id in ["starter_pack", "remove_ads"]:
		var owned: Array = Save.data.get("iap_owned", [])
		if not owned.has(product_id):
			owned.append(product_id)
		Save.data["iap_owned"] = owned
	Save.write()
	granted.emit(product_id, gives)


func available() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling")


## Debug builds without the plugin simulate a successful purchase so the shop flow can be tested.
## Release builds without the plugin fail (nothing is granted).
func buy(product_id: String) -> void:
	if not available():
		if OS.is_debug_build():
			purchased.emit.call_deferred(product_id)
		else:
			purchase_failed.emit.call_deferred(product_id)
		return
	pass # TODO(phase 3)
