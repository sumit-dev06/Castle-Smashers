extends Node
## Analytics + crash reporting facade. Gameplay/UI call only this. Events go to Firebase Analytics
## and Crashlytics (src/autoload/analytics_firebase.gd) when the Android plugin is present;
## everywhere else they are kept in a small in-memory log (tests, debug) and printed with
## --log-analytics. Only whitelisted event names and parameters are sent, never personal data
## (no names, emails, device ids, purchase tokens or free text).
## Setup: docs/FIREBASE_SETUP.md.

const BACKEND: String = "res://src/autoload/analytics_firebase.gd"
## event -> allowed parameter keys.
const EVENTS: Dictionary = {
	"game_start": ["session_number", "days_since_install", "build"],
	"tutorial_begin": ["level_id"],
	"tutorial_complete": ["level_id"],
	"level_start": ["level_id", "attempt", "weapon", "heroes", "mode"],
	"level_complete": ["level_id", "attempt", "stars", "score", "duration_s", "weapon", "shots_used", "used_hellfire"],
	"level_failed": ["level_id", "attempt", "reason", "duration_s", "weapon", "shots_used"],
	"level_retry": ["level_id"],
	"level_quit": ["level_id", "attempt", "duration_s", "shots_used", "how"],
	"rewarded_ad_watched": ["placement", "reward_amount", "level_id"],
	"rewarded_ad_failed": ["placement"],
	"interstitial_shown": ["level_id"],
	"purchase_start": ["product_id"],
	"purchase_success": ["product_id", "reward_amount"],
	"purchase_failed": ["product_id", "reason"],
	"crate_opened": ["product_id", "reward_type", "reward_amount"],
	"hellfire_used": ["level_id", "left"],
	"upgrade_bought": ["weapon", "track", "level", "cost"],
	"engine_forged": ["weapon", "cost"],
	"skin_bought": ["skin_id", "cost"],
	"spin_used": ["paid_with_ad", "reward_type", "reward_amount"],
	"notification_opened": ["kind"],
	"review_requested": ["level_id"],
	"update_prompted": ["mode", "version_code", "staleness_days"],
	"session_end": ["duration_s", "levels_played"],
	"promo_shown": ["card"],
	"promo_tap": ["card"],
}
const MAX_LOG: int = 200

var log: Array[Dictionary] = []
var _backend: RefCounted
var _session_start_ms: int = 0
var _session_levels: int = 0


func _ready() -> void:
	_session_start_ms = Time.get_ticks_msec()
	if OS.get_name() == "Android" and ResourceLoader.exists(BACKEND):
		var b: RefCounted = (load(BACKEND) as GDScript).new()
		if bool(b.call("available")):
			_backend = b
			b.call("set_collection", bool(Save.data.get("analytics_on", true)))
			OS.add_logger(ErrorForwarder.new())
	if not Save.data.has("install_day"):
		Save.data["install_day"] = int(Time.get_unix_time_from_system() / 86400.0)
		Save.write()
	set_crash_key("build", String(ProjectSettings.get_setting("application/config/version", "")))
	if not " ".join(OS.get_cmdline_user_args()).contains("--run-tests"):
		event("game_start", {"session_number": int(Save.data.get("sessions", 1)),
				"days_since_install": int(Time.get_unix_time_from_system() / 86400.0) - int(Save.data["install_day"]),
				"build": String(ProjectSettings.get_setting("application/config/version", ""))})


func _notification(what: int) -> void:
	# Android sends PAUSED when the player leaves; that is the reliable "session end" on mobile.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		event("session_end", {"duration_s": int((Time.get_ticks_msec() - _session_start_ms) / 1000.0), "levels_played": _session_levels})
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_session_start_ms = Time.get_ticks_msec()
		_session_levels = 0


## Logs one event. Unknown events and parameters are dropped (and flagged in debug builds).
func event(name: String, params: Dictionary = {}) -> void:
	if not bool(Save.data.get("analytics_on", true)):
		return
	if not EVENTS.has(name):
		if OS.is_debug_build():
			push_warning("Analytics: unknown event %s" % name)
		return
	var clean: Dictionary = {}
	for k: String in params:
		if (EVENTS[name] as Array).has(k):
			var v: Variant = params[k]
			clean[k] = v if (v is int or v is float or v is bool) else String(v).left(100)
	if name in ["level_complete", "level_failed"]:
		_session_levels += 1
	log.append({"name": name, "params": clean})
	if log.size() > MAX_LOG:
		log.pop_front()
	breadcrumb("%s %s" % [name, JSON.stringify(clean)])
	if _backend:
		_backend.call("log_event", name, clean)
	if OS.is_debug_build() and " ".join(OS.get_cmdline_user_args()).contains("--log-analytics"):
		print("ANALYTICS ", name, " ", clean)


## Crashlytics breadcrumb (shows in the crash report's log tab).
func breadcrumb(text: String) -> void:
	if _backend:
		_backend.call("log_message", text)


## Crash context such as the current scene ("physics", "loading", "ads") or level.
func set_crash_key(key: String, value: String) -> void:
	if _backend:
		_backend.call("set_custom_key", key, value)


## Non-fatal error report (e.g. a failed save write).
func report_error(message: String) -> void:
	if _backend:
		_backend.call("record_error", message)


## Sends engine/script errors (not warnings) to Crashlytics as non-fatal reports with the
## GDScript backtrace. Each distinct error is sent once per session, at most MAX_ERRORS in total.
## Native crashes (engine C++, physics, GPU driver) are caught by Crashlytics NDK itself.
const MAX_ERRORS: int = 10
var _sent_errors: Dictionary = {}


func _forward_error(text: String) -> void:
	if _backend == null or _sent_errors.size() >= MAX_ERRORS or _sent_errors.has(text.left(160)):
		return
	_sent_errors[text.left(160)] = true
	_backend.call("record_error", text)


class ErrorForwarder extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text: String = "%s %s (%s:%d %s)" % [code, rationale, file, line, function]
		for bt: ScriptBacktrace in script_backtraces:
			text += "\n" + bt.format()
		# Loggers can be called from any thread; Crashlytics is touched from the main thread.
		Analytics._forward_error.call_deferred(text)

	func _log_message(_message: String, _error: bool) -> void:
		pass


## Player opt-out (Settings): stops analytics events and crash collection.
func set_enabled(on: bool) -> void:
	Save.data["analytics_on"] = on
	Save.write()
	if _backend:
		_backend.call("set_collection", on)


func last(name: String) -> Dictionary:
	for i: int in range(log.size() - 1, -1, -1):
		if String(log[i]["name"]) == name:
			return log[i]["params"]
	return {}
