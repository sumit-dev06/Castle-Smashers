extends RefCounted
## Google Play Billing backend for Store. Wraps the official plugin
## (addons/GodotGooglePlayBilling 3.3.0, Play Billing Library 9.1, class BillingClient).
## Only created on Android when the plugin's singleton exists. Every plugin call and signal goes
## through here, so a plugin update only changes this file. Store's backend interface is the
## same as store_fake_billing.gd.

signal connected
signal disconnected
signal connect_failed(code: int, message: String)
signal products_loaded(products: Array)
signal products_failed(code: int, message: String)
signal purchases_updated(purchases: Array)
signal purchases_queried(ok: bool, purchases: Array)
signal purchase_failed(code: int, message: String)
signal consumed(token: String)
signal consume_failed(token: String, code: int, message: String)
signal acknowledged(token: String)
signal acknowledge_failed(token: String, code: int, message: String)

const SINGLETON: String = "GodotGooglePlayBilling"
const CLIENT: String = "res://addons/GodotGooglePlayBilling/BillingClient.gd"
const OK_CODE: int = 0

## The plugin's BillingClient (a Node; kept in the tree by Store so its signals run).
var client: Node


static func plugin_present() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(SINGLETON) and ResourceLoader.exists(CLIENT)


func _init() -> void:
	client = (load(CLIENT) as GDScript).new()
	client.connected.connect(func() -> void: connected.emit())
	client.disconnected.connect(func() -> void: disconnected.emit())
	client.connect_error.connect(func(code: int, msg: String) -> void: connect_failed.emit(code, msg))
	client.query_product_details_response.connect(_on_products)
	client.query_purchases_response.connect(_on_query)
	client.on_purchase_updated.connect(_on_updated)
	client.consume_purchase_response.connect(func(r: Dictionary) -> void:
		if int(r.get("response_code", -1)) == OK_CODE:
			consumed.emit(String(r.get("token", "")))
		else:
			consume_failed.emit(String(r.get("token", "")), int(r.get("response_code", -1)), String(r.get("debug_message", ""))))
	client.acknowledge_purchase_response.connect(func(r: Dictionary) -> void:
		if int(r.get("response_code", -1)) == OK_CODE:
			acknowledged.emit(String(r.get("token", "")))
		else:
			acknowledge_failed.emit(String(r.get("token", "")), int(r.get("response_code", -1)), String(r.get("debug_message", ""))))


func start() -> void:
	client.call("start_connection")


func query_products(ids: Array) -> void:
	client.call("query_product_details", PackedStringArray(ids), 0)  # BillingClient.ProductType.INAPP


func query_purchases() -> void:
	client.call("query_purchases", 0)


func purchase(id: String) -> void:
	var r: Variant = client.call("purchase", id)
	if r is Dictionary and int((r as Dictionary).get("response_code", OK_CODE)) != OK_CODE:
		purchase_failed.emit.call_deferred(int(r["response_code"]), String((r as Dictionary).get("debug_message", "")))


func consume(token: String) -> void:
	client.call("consume_purchase", token)


func acknowledge(token: String) -> void:
	client.call("acknowledge_purchase", token)


func _on_products(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK_CODE:
		products_failed.emit(int(r.get("response_code", -1)), String(r.get("debug_message", "")))
		return
	var out: Array = []
	for d: Variant in r.get("product_details", []):
		if not (d is Dictionary):
			continue
		var price: String = ""
		var offers: Variant = (d as Dictionary).get("one_time_purchase_offer_details_list", null)
		if offers is Array and not (offers as Array).is_empty() and offers[0] is Dictionary:
			price = String(offers[0].get("formatted_price", ""))
		out.append({"id": String(d.get("product_id", "")), "title": String(d.get("name", d.get("title", ""))), "price_text": price})
	products_loaded.emit(out)


func _on_query(r: Dictionary) -> void:
	purchases_queried.emit(int(r.get("response_code", -1)) == OK_CODE, _purchases(r))


## Purchase flow result. Non-OK codes (cancelled, failed, already owned) go to purchase_failed.
func _on_updated(r: Dictionary) -> void:
	var code: int = int(r.get("response_code", -1))
	if code == OK_CODE:
		purchases_updated.emit(_purchases(r))
	else:
		purchase_failed.emit(code, String(r.get("debug_message", "")))


static func _purchases(r: Dictionary) -> Array:
	var out: Array = []
	for p: Variant in r.get("purchases", []):
		if p is Dictionary:
			var d: Dictionary = (p as Dictionary).duplicate()
			d["product_ids"] = Array(d.get("product_ids", []))
			out.append(d)
	return out
