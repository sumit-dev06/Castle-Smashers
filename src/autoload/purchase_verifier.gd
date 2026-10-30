extends Node
## Server-side purchase verification for Store. POSTs {package_name, product_id, purchase_token} as
## JSON to balance.shop.verify_url; the backend calls the Google Play Developer API
## (purchases.products.get) with its service account and answers {"valid": true|false}.
## No credentials ever live in the game. See docs/BILLING_SETUP.md -> "Verification backend".

signal finished(token: String, valid: bool)

const PACKAGE: String = "com.castlesmashers.game"
const TIMEOUT_S: float = 15.0

var _busy: Dictionary = {}


static func url() -> String:
	return String(Data.balance["shop"].get("verify_url", ""))


## true = this build must have server approval before granting.
static func required() -> bool:
	return bool(Data.balance["shop"].get("verify_required", false)) and not OS.is_debug_build()


func verify(token: String, product_id: String) -> void:
	if _busy.has(token):
		return
	if url().is_empty():
		# No backend yet: allowed only while verify_required is false (pre-launch / debug).
		finished.emit.call_deferred(token, not required())
		return
	var req: HTTPRequest = HTTPRequest.new()
	req.timeout = TIMEOUT_S
	add_child(req)
	_busy[token] = req
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		_busy.erase(token)
		req.queue_free()
		var ok: bool = false
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			ok = parsed is Dictionary and bool((parsed as Dictionary).get("valid", false)) \
					and String((parsed as Dictionary).get("product_id", product_id)) == product_id
		finished.emit(token, ok))
	var payload: String = JSON.stringify({"package_name": PACKAGE, "product_id": product_id, "purchase_token": token})
	var err: Error = req.request(url(), PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, payload)
	if err != OK:
		_busy.erase(token)
		req.queue_free()
		finished.emit.call_deferred(token, false)
