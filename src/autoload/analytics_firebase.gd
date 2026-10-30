extends RefCounted
## Firebase backend for the Analytics autoload (CastleFirebase Android plugin,
## addons/castle_firebase, source tools/android_plugins/firebase). Only created on Android.

var _p: Object


func available() -> bool:
	if _p == null and Engine.has_singleton("CastleFirebase"):
		_p = Engine.get_singleton("CastleFirebase")
	return _p != null and bool(_p.call("available"))


func log_event(name: String, params: Dictionary) -> void:
	_p.call("logEvent", name, params)


func log_message(text: String) -> void:
	_p.call("log", text)


func set_custom_key(key: String, value: String) -> void:
	_p.call("setCustomKey", key, value)


func record_error(message: String) -> void:
	_p.call("recordError", message)


func set_collection(on: bool) -> void:
	_p.call("setCollectionEnabled", on)
