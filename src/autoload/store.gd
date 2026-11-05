extends Node
## Store = BillingManager. All Google Play Billing goes through here (AGENTS rule 5).
## Backends (same interface): store_play_billing.gd on Android with the plugin, store_fake_billing.gd
## in debug builds without it (desktop, tests). Release builds without the plugin report UNAVAILABLE
## and never grant anything.
## Flow: start -> connected -> query product details (localized prices) + query purchases (restore,
## recovery) -> buy -> purchases_updated -> verify -> PurchaseProcessor (reward + ledger saved first)
## -> consume (crates) / acknowledge (Remove Ads) -> mark finished. Unfinished tokens are retried on
## every reconnect and app resume. docs/BILLING_SETUP.md explains activation and testing.

enum Status { OFF, CONNECTING, READY, UNAVAILABLE }

signal status_changed(status: Status)
signal products_changed
## Contents were saved: {coins|gems|hellfire: n} (empty for Remove Ads).
signal granted(product_id: String, gives: Dictionary)
signal purchase_pending(product_id: String)
signal purchase_cancelled(product_id: String)
signal purchase_failed(product_id: String, message: String)
signal entitlements_changed
signal restore_finished(ok: bool)

const PLAY_BACKEND: String = "res://src/autoload/store_play_billing.gd"
const FAKE_BACKEND: String = "res://src/autoload/store_fake_billing.gd"
const VERIFIER: String = "res://src/autoload/purchase_verifier.gd"
const USER_CANCELED: int = 1
const ITEM_ALREADY_OWNED: int = 7

var status: Status = Status.OFF
var backend: RefCounted
## id -> {title, price_text} from Google Play.
var products: Dictionary = {}
## Product of the purchase in progress ("" = none). Only one at a time.
var busy_product: String = ""
var _verifier: Node
var _awaiting: Dictionary = {}
var _finishing: Dictionary = {}
var _retry_i: int = 0
var _restore_requested: bool = false


func _ready() -> void:
	_verifier = (load(VERIFIER) as GDScript).new()
	add_child(_verifier)
	_verifier.connect("finished", _on_verified)
	if not " ".join(OS.get_cmdline_user_args()).contains("--run-tests"):
		start()


func _notification(what: int) -> void:
	# Payments approved while the app was in the background (pending, other device) arrive here.
	if what == NOTIFICATION_APPLICATION_RESUMED and status == Status.READY:
		backend.call("query_purchases")
		refresh_products()


## Asks Play again for any product it has not returned yet (products created in Play Console after
## the app connected, or a query that failed). The shop calls this when it opens.
func refresh_products() -> void:
	if status != Status.READY or backend == null:
		return
	var missing: Array = []
	for id: Variant in Data.balance["shop"]["order"]:
		if not products.has(String(id)):
			missing.append(String(id))
	if not missing.is_empty():
		backend.call("query_products", Data.balance["shop"]["order"])


## Picks the backend and connects. Safe to call repeatedly: one connection attempt at a time.
func start() -> void:
	if status == Status.CONNECTING or status == Status.READY:
		return
	if backend == null:
		var path: String = ""
		if OS.get_name() == "Android" and Engine.has_singleton("GodotGooglePlayBilling"):
			path = PLAY_BACKEND
		elif OS.is_debug_build():
			path = FAKE_BACKEND
		if path.is_empty():
			_set_status(Status.UNAVAILABLE)
			return
		var b: RefCounted = (load(path) as GDScript).new()
		var node: Variant = b.get("client")
		if node is Node:
			add_child(node as Node)
		use_backend(b)
		return
	_set_status(Status.CONNECTING)
	backend.call("start")


## Installs a backend (tests inject a configured fake) and connects.
func use_backend(b: RefCounted) -> void:
	backend = b
	status = Status.OFF
	busy_product = ""
	_awaiting.clear()
	_finishing.clear()
	for pair: Array in [["connected", _on_connected], ["disconnected", _on_disconnected],
			["connect_failed", _on_connect_failed], ["products_loaded", _on_products],
			["products_failed", _on_products_failed], ["purchases_updated", _on_updated],
			["purchases_queried", _on_queried], ["purchase_failed", _on_purchase_failed],
			["consumed", _on_finished], ["acknowledged", _on_finished],
			["consume_failed", _on_finish_failed], ["acknowledge_failed", _on_finish_failed]]:
		b.connect(String(pair[0]), pair[1])
	start()


func _set_status(s: Status) -> void:
	status = s
	status_changed.emit(s)


func available() -> bool:
	return status == Status.READY


func catalog() -> Dictionary:
	return PurchaseProcessor.catalog()


func product(product_id: String) -> Dictionary:
	return catalog().get(product_id, {})


## Localized price from Google Play, "" until loaded (the shop never invents a price).
## Why `product_id` can't be bought right now ("" = it can). Shown when a shop button is tapped.
func buy_block_reason(product_id: String) -> String:
	if not busy_product.is_empty():
		return "A purchase is already in progress. Please wait a moment."
	match status:
		Status.OFF, Status.CONNECTING:
			return "Connecting to Google Play... try again in a moment."
		Status.UNAVAILABLE:
			return "Google Play Store is not available. Check your internet and Play Store sign-in."
	if price_text(product_id).is_empty():
		return "Loading the price from Google Play... try again in a moment."
	return ""


func price_text(product_id: String) -> String:
	return String((products.get(product_id, {}) as Dictionary).get("price_text", ""))


func owns(product_id: String) -> bool:
	return PurchaseProcessor.owns(product_id)


## Starts a purchase. false when the store is not ready, another purchase is running, the product is
## unknown or unpriced, or a non-consumable is already owned.
func buy(product_id: String) -> bool:
	if status != Status.READY or not busy_product.is_empty() or not catalog().has(product_id):
		return false
	if price_text(product_id).is_empty():
		return false
	if not PurchaseProcessor.is_consumable(product_id) and owns(product_id):
		return false
	busy_product = product_id
	Analytics.event("purchase_start", {"product_id": product_id})
	backend.call("purchase", product_id)
	return true


func restore() -> void:
	if status == Status.READY:
		_restore_requested = true
		backend.call("query_purchases")
	else:
		restore_finished.emit.call_deferred(false)
		start()


# ------------------------------------------------------------------------------------ backend events
func _on_connected() -> void:
	_retry_i = 0
	_set_status(Status.READY)
	backend.call("query_products", Data.balance["shop"]["order"])
	backend.call("query_purchases")


func _on_disconnected() -> void:
	_set_status(Status.OFF)
	busy_product = ""
	_retry_later()


func _on_connect_failed(code: int, message: String) -> void:
	push_warning("Store: billing connection failed (%d): %s" % [code, message])
	_set_status(Status.OFF)
	_retry_later()


func _retry_later() -> void:
	var delays: Array = Data.balance["shop"]["reconnect_s"]
	var d: float = float(delays[mini(_retry_i, delays.size() - 1)])
	_retry_i += 1
	if is_inside_tree():
		get_tree().create_timer(d, true, false, true).timeout.connect(start)


func _on_products(list: Array) -> void:
	for d: Dictionary in list:
		if catalog().has(String(d["id"])):
			products[String(d["id"])] = d
	products_changed.emit()


func _on_products_failed(code: int, message: String) -> void:
	push_warning("Store: product query failed (%d): %s" % [code, message])
	products_changed.emit()


func _on_purchase_failed(code: int, message: String) -> void:
	var id: String = busy_product
	busy_product = ""
	if code == USER_CANCELED:
		Analytics.event("purchase_failed", {"product_id": id, "reason": "cancelled"})
		purchase_cancelled.emit(id)
	elif code == ITEM_ALREADY_OWNED:
		restore()
	else:
		push_warning("Store: purchase failed (%d): %s" % [code, message])
		Analytics.event("purchase_failed", {"product_id": id, "reason": "code_%d" % code})
		purchase_failed.emit(id, "Purchase failed. You were not charged.")


func _on_updated(list: Array) -> void:
	for raw: Dictionary in list:
		_handle(PurchaseProcessor.normalize(raw))


func _on_queried(ok: bool, list: Array) -> void:
	if ok:
		var owned_now: Array = []
		for raw: Dictionary in list:
			var p: Dictionary = PurchaseProcessor.normalize(raw)
			if p["state"] == PurchaseProcessor.STATE_PURCHASED:
				for id: Variant in p["products"]:
					if not PurchaseProcessor.is_consumable(String(id)):
						owned_now.append(String(id))
		if PurchaseProcessor.reconcile_owned(owned_now):
			entitlements_changed.emit()
	for raw2: Dictionary in list:
		_handle(PurchaseProcessor.normalize(raw2))
	if _restore_requested:
		_restore_requested = false
		restore_finished.emit(ok)


func _handle(p: Dictionary) -> void:
	var token: String = String(p["token"])
	var rec: Dictionary = PurchaseProcessor.ledger()["tokens"].get(token, {})
	var known: bool = String(rec.get("state", "")) in ["granted", "finished"]
	if p["state"] == PurchaseProcessor.STATE_PURCHASED and not known and not token.is_empty():
		if _awaiting.has(token):
			return  # duplicate callback while verifying
		_awaiting[token] = p
		_verifier.call("verify", token, String((p["products"] as Array).front() if not (p["products"] as Array).is_empty() else ""))
		return
	_apply(p, true)


func _on_verified(token: String, valid: bool) -> void:
	if not _awaiting.has(token):
		return
	var p: Dictionary = _awaiting[token]
	_awaiting.erase(token)
	_apply(p, valid)


func _apply(p: Dictionary, verified: bool) -> void:
	var r: Dictionary = PurchaseProcessor.process(p, verified)
	var id: String = String(r["product"])
	match String(r["action"]):
		"granted":
			for k: String in r["gives"]:
				Events.currency_changed.emit(k, Save.amount(k))
			var amount: int = 0
			var kind: String = "remove_ads"
			for k2: String in r["gives"]:
				amount = int(r["gives"][k2])
				kind = k2
			Analytics.event("purchase_success", {"product_id": id, "reward_amount": amount})
			if PurchaseProcessor.is_consumable(id):
				Analytics.event("crate_opened", {"product_id": id, "reward_type": kind, "reward_amount": amount})
			if not PurchaseProcessor.is_consumable(id):
				entitlements_changed.emit()
			granted.emit(id, r["gives"])
		"already":
			if not PurchaseProcessor.is_consumable(id):
				entitlements_changed.emit()
		"pending":
			purchase_pending.emit(id)
		"hold":
			purchase_failed.emit(id, "We could not verify this purchase yet. It will be retried automatically.")
	if id == busy_product and String(r["action"]) != "ignore":
		busy_product = ""
	var token: String = String(p["token"])
	match String(r["finish"]):
		"consume":
			if not _finishing.has(token):
				_finishing[token] = true
				backend.call("consume", token)
		"acknowledge":
			if not _finishing.has(token):
				_finishing[token] = true
				backend.call("acknowledge", token)


func _on_finished(token: String) -> void:
	_finishing.erase(token)
	PurchaseProcessor.mark_finished(token)


## The reward is already saved; Play will report the token again on the next query and we retry.
func _on_finish_failed(token: String, code: int, message: String) -> void:
	_finishing.erase(token)
	push_warning("Store: consume/acknowledge failed for %s (%d): %s" % [PurchaseProcessor.mask(token), code, message])
