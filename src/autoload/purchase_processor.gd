class_name PurchaseProcessor
extends RefCounted
## Pure purchase logic for Store (no plugin calls, so tests can drive it directly).
## Ledger in Save.data["iap"]:
##   tokens: {purchase_token: {product, state, t}}   state: pending | unverified | granted | finished
##   owned:  {product_id: {token, source}}           non-consumable entitlements (remove_ads)
## Rules: rewards only for state PURCHASED and a known product; a token is granted at most once;
## the reward and the ledger entry are written in ONE Save.write() before the purchase is consumed
## or acknowledged, so a crash, a failed consume or a duplicate callback can never lose or double it.

const STATE_PURCHASED: String = "purchased"
const STATE_PENDING: String = "pending"


static func ledger() -> Dictionary:
	if not (Save.data.get("iap", null) is Dictionary):
		Save.data["iap"] = {}
	var l: Dictionary = Save.data["iap"]
	for k: String in ["tokens", "owned"]:
		if not (l.get(k, null) is Dictionary):
			l[k] = {}
	return l


static func catalog() -> Dictionary:
	return Data.balance["shop"]["products"]


static func is_consumable(product_id: String) -> bool:
	return String((catalog().get(product_id, {}) as Dictionary).get("type", "")) == "consumable"


## Plugin purchase dictionary -> {token, products, state, acknowledged, order_id, json, signature}.
## Accepts the key names used by different Google Play Billing plugin versions.
static func normalize(raw: Dictionary) -> Dictionary:
	var products: Array = []
	for key: String in ["product_ids", "products", "skus"]:
		if raw.get(key, null) is Array:
			products = (raw[key] as Array).duplicate()
			break
	if products.is_empty():
		for key2: String in ["product_id", "sku"]:
			if raw.has(key2):
				products = [String(raw[key2])]
				break
	var st: Variant = raw.get("purchase_state", raw.get("purchaseState", 0))
	var state: String = "unknown"
	if st is String:
		state = String(st).to_lower()
	elif int(st) == 1:
		state = STATE_PURCHASED
	elif int(st) == 2:
		state = STATE_PENDING
	return {
		"token": String(raw.get("purchase_token", raw.get("purchaseToken", raw.get("token", "")))),
		"products": products,
		"state": state,
		"acknowledged": bool(raw.get("is_acknowledged", raw.get("acknowledged", false))),
		"order_id": String(raw.get("order_id", raw.get("orderId", ""))),
		"json": String(raw.get("original_json", raw.get("originalJson", ""))),
		"signature": String(raw.get("signature", "")),
	}


## Shortened token for logs (never log the full purchase token).
static func mask(token: String) -> String:
	return token.substr(0, 6) + "…" if token.length() > 6 else "…"


## Decides and applies one purchase. `verified`: the server (or local debug rules) accepted it.
## Returns {action, product, gives, finish}. action: ignore | pending | hold | granted | already.
## finish: "consume", "acknowledge" or "" (what Store must still tell Google Play).
static func process(p: Dictionary, verified: bool) -> Dictionary:
	var out: Dictionary = {"action": "ignore", "product": "", "gives": {}, "finish": ""}
	var token: String = String(p.get("token", ""))
	var products: Array = p.get("products", [])
	if token.is_empty() or products.size() != 1 or not catalog().has(String(products[0])):
		return out
	var id: String = String(products[0])
	out["product"] = id
	var l: Dictionary = ledger()
	var rec: Dictionary = l["tokens"].get(token, {})
	var done: bool = String(rec.get("state", "")) in ["granted", "finished"]
	if String(p.get("state", "")) == STATE_PENDING:
		if not done:
			l["tokens"][token] = {"product": id, "state": "pending", "t": int(Time.get_unix_time_from_system())}
			Save.write()
		out["action"] = "pending"
		return out
	if String(p.get("state", "")) != STATE_PURCHASED:
		return out
	var finish: String = ""
	if is_consumable(id):
		finish = "" if String(rec.get("state", "")) == "finished" else "consume"
	elif not bool(p.get("acknowledged", false)):
		finish = "acknowledge"
	out["finish"] = finish
	if done:
		# Duplicate callback or recovery after a crash: never grant again, only finish with Play.
		if not is_consumable(id):
			_own(id, token, "play")
			Save.write()
		out["action"] = "already"
		return out
	if not verified:
		l["tokens"][token] = {"product": id, "state": "unverified", "t": int(Time.get_unix_time_from_system())}
		Save.write()
		out["action"] = "hold"
		out["finish"] = ""
		return out
	var gives: Dictionary = (catalog()[id].get("gives", {}) as Dictionary).duplicate()
	for k: String in gives:
		Save.data[k] = Save.amount(k) + int(gives[k])
	if not is_consumable(id):
		_own(id, token, "play")
	l["tokens"][token] = {"product": id, "state": "granted", "t": int(Time.get_unix_time_from_system())}
	Save.write()
	out["action"] = "granted"
	out["gives"] = gives
	return out


## Google Play confirmed consume / acknowledge for this token.
static func mark_finished(token: String) -> void:
	var l: Dictionary = ledger()
	if l["tokens"].has(token):
		l["tokens"][token]["state"] = "finished"
		Save.write()


static func _own(id: String, token: String, source: String) -> void:
	ledger()["owned"][id] = {"token": token, "source": source}
	if id == "remove_ads":
		Save.data["no_ads"] = true


static func owns(id: String) -> bool:
	return ledger()["owned"].has(id)


## A successful, authoritative purchase query: non-consumables Play no longer reports (refunded)
## are revoked, but only if Play granted them (debug grants are left alone).
static func reconcile_owned(play_owned: Array) -> bool:
	var changed: bool = false
	var owned: Dictionary = ledger()["owned"]
	for id: String in owned.keys():
		if not play_owned.has(id) and String(owned[id].get("source", "")) == "play":
			owned.erase(id)
			changed = true
			if id == "remove_ads":
				Save.data["no_ads"] = false
	if changed:
		Save.write()
	return changed
