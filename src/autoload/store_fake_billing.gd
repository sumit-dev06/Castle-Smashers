extends RefCounted
## Simulated Google Play Billing for desktop/debug builds and tests. Same signals and methods as
## store_play_billing.gd, so the whole Store -> PurchaseProcessor path runs without a phone.
## Never used in release builds (Store only creates it when OS.is_debug_build()).

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

const USER_CANCELED: int = 1
const ERROR: int = 6

## Test controls.
var connect_ok: bool = true
## purchased | pending | cancel | fail
var next_outcome: String = "purchased"
var fail_consume: bool = false
var fail_ack: bool = false
var duplicate_callbacks: bool = false
var query_ok: bool = true
## What "Google Play" still reports as owned / unconsumed (raw plugin-style dictionaries).
var play_purchases: Array = []
var _n: int = 0


func start() -> void:
	if connect_ok:
		connected.emit.call_deferred()
	else:
		connect_failed.emit.call_deferred(3, "Billing service unavailable (simulated)")


func query_products(ids: Array) -> void:
	var out: Array = []
	for id: Variant in ids:
		var c: Dictionary = Data.balance["shop"]["products"].get(String(id), {})
		if not c.is_empty():
			out.append({"id": String(id), "title": String(c["name"]), "price_text": "$%.2f (test)" % float(c["price_hint_usd"])})
	products_loaded.emit.call_deferred(out)


func query_purchases() -> void:
	purchases_queried.emit.call_deferred(query_ok, play_purchases.duplicate(true))


func purchase(id: String) -> void:
	match next_outcome:
		"cancel":
			purchase_failed.emit.call_deferred(USER_CANCELED, "User cancelled")
			return
		"fail":
			purchase_failed.emit.call_deferred(ERROR, "Simulated error")
			return
	_n += 1
	var p: Dictionary = {"purchase_token": "fake-%d-%d" % [Time.get_ticks_usec(), _n], "product_ids": [id],
			"purchase_state": 2 if next_outcome == "pending" else 1, "is_acknowledged": false,
			"order_id": "GPA.TEST-%d" % _n}
	play_purchases.append(p)
	purchases_updated.emit.call_deferred([p.duplicate(true)])
	if duplicate_callbacks:
		purchases_updated.emit.call_deferred([p.duplicate(true)])


## Test helper: a pending payment completes (Play sends the update later).
func complete_pending() -> void:
	for p: Dictionary in play_purchases:
		if int(p["purchase_state"]) == 2:
			p["purchase_state"] = 1
			purchases_updated.emit.call_deferred([p.duplicate(true)])


func consume(token: String) -> void:
	if fail_consume:
		consume_failed.emit.call_deferred(token, ERROR, "Simulated consume failure")
		return
	play_purchases = play_purchases.filter(func(p: Dictionary) -> bool: return String(p["purchase_token"]) != token)
	consumed.emit.call_deferred(token)


func acknowledge(token: String) -> void:
	if fail_ack:
		acknowledge_failed.emit.call_deferred(token, ERROR, "Simulated acknowledge failure")
		return
	for p: Dictionary in play_purchases:
		if String(p["purchase_token"]) == token:
			p["is_acknowledged"] = true
	acknowledged.emit.call_deferred(token)
