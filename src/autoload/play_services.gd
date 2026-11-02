extends Node
## Google Play In-App Review and In-App Updates (CastlePlay Android plugin, in castle_notify.aar).
## No-op on desktop and in copies not installed from Play. Settings: balance.json "play".
##
## Review: after a 3-star campaign win, from `review.min_level`, at most `max_asks` times and
## `gap_days` apart. The game never asks "do you like it?" first: Play's own card appears or not.
## Updates: checked on the home screen once per session. Release priority (tools/release.py upload
## --priority) >= `immediate_priority` opens Play's blocking update screen; anything lower offers
## the flexible download, at most every `ask_gap_hours` per version, and installs it quietly the
## next time the game goes to the background.

var _p: Object = null
var _checked: bool = false
## Google Play Games sign-in: started on the first home screen (never over the intro), checked
## again when the game comes back to the front; Settings has a manual button. Never required.
var games_signed_in: bool = false
var _games_started: bool = false
## Cloud save (Play Games Saved Games). Only while signed in. `cloud_pending` holds a cloud save
## that differs from this phone's progress until the player picks one (CloudPopup on home).
var cloud_ok: bool = false
var cloud_pending: Dictionary = {}
var _cloud_busy: bool = false
var _cloud_rev: int = -1
var _cloud_t: float = -1e9
signal cloud_conflict
var games_name: String = ""
var games_error: String = ""
signal games_changed
var _downloaded: bool = false


func cfg(section: String) -> Dictionary:
	return (Data.balance.get("play", {}) as Dictionary).get(section, {})


func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("CastlePlay"):
		return
	_p = Engine.get_singleton("CastlePlay")
	_p.connect("review_finished", func(_shown: bool) -> void: pass)
	_p.connect("update_checked", _on_update_checked)
	_p.connect("update_downloaded", func() -> void: _downloaded = true)
	_p.connect("update_failed", func(reason: String) -> void: push_warning("PlayServices: update failed: " + reason))
	Events.level_finished.connect(_on_level_finished)
	if _p.has_signal("games_signed_in"):
		_p.connect("games_signed_in", _on_games)
	if _p.has_signal("cloud_loaded"):
		_p.connect("cloud_loaded", _on_cloud_loaded)
		_p.connect("cloud_saved", _on_cloud_saved)


func available() -> bool:
	return _p != null


func games_available() -> bool:
	return _p != null and _p.has_signal("games_signed_in")


## Settings button: Google's own sign-in sheet. Answer arrives through games_changed.
func games_sign_in() -> void:
	if games_available():
		_p.call("gamesSignIn")


func _on_games(signed_in: bool, display_name: String, error: String) -> void:
	games_signed_in = signed_in
	games_name = display_name
	games_error = error
	if not signed_in and not error.is_empty():
		print("PlayServices: Play Games not signed in: ", error)
	games_changed.emit()
	if signed_in and not cloud_ok and not _cloud_busy and _p.has_signal("cloud_loaded"):
		_cloud_busy = true
		_p.call("cloudLoad")


# ------------------------------------------------------------------------------------ cloud save
func _cloud_cfg() -> Dictionary:
	return cfg("cloud")


## A save with no progress yet (new install).
static func cloud_fresh(d: Dictionary) -> bool:
	return int(d.get("unlocked", 1)) <= 1 and (d.get("stars", {}) as Dictionary).is_empty()


## Pure rule (tests call it): "upload" this phone's save, "load" the cloud one, or "ask".
static func cloud_choice(local: Dictionary, cloud: Dictionary) -> String:
	if cloud.is_empty() or cloud_fresh(cloud):
		return "upload"
	if String(cloud.get("save_id", "")) == String(local.get("save_id", "")):
		return "load" if int(cloud.get("rev", 0)) > int(local.get("rev", 0)) else "upload"
	if cloud_fresh(local):
		return "load"
	return "ask"


## Short line for the choice popup: "Level 34 · 87 stars · 1200 coins".
static func cloud_summary(d: Dictionary) -> String:
	var stars: int = 0
	for v: Variant in (d.get("stars", {}) as Dictionary).values():
		stars += int(v)
	return "Level %d · %d stars · %d coins" % [int(d.get("unlocked", 1)), stars, int(d.get("coins", 0))]


func _on_cloud_loaded(ok: bool, text: String, error: String) -> void:
	_cloud_busy = false
	if not ok:
		print("PlayServices: cloud load failed: ", error)
		return
	cloud_ok = true
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else {}
	var cloud: Dictionary = parsed if parsed is Dictionary else {}
	match cloud_choice(Save.data, cloud):
		"load":
			cloud_apply(cloud)
		"ask":
			cloud_pending = cloud
			cloud_conflict.emit()
		_:
			cloud_upload(true)


## Player picked the cloud save (or it was the only progress): it replaces this phone's save.
func cloud_apply(cloud: Dictionary) -> void:
	cloud_pending = {}
	Save.replace_with(cloud, _cloud_cfg().get("device_keys", []))
	Analytics.event("cloud_loaded", {"level": int(Save.data.get("unlocked", 1))})
	_cloud_rev = int(Save.data.get("rev", 0))
	Game.goto_menu()


## Player kept this phone's progress: it overwrites the cloud copy.
func cloud_keep_local() -> void:
	cloud_pending = {}
	cloud_upload(true)


## Uploads the save if it changed since the last upload (at most every min_interval_s unless forced).
func cloud_upload(force: bool = false) -> void:
	if _p == null or not cloud_ok or _cloud_busy or not cloud_pending.is_empty() or not games_signed_in:
		return
	var rev: int = int(Save.data.get("rev", 0))
	var now: float = Time.get_ticks_msec() / 1000.0
	if not force and (rev == _cloud_rev or now - _cloud_t < float(_cloud_cfg().get("min_interval_s", 60))):
		return
	_cloud_busy = true
	_cloud_rev = rev
	_cloud_t = now
	_p.call("cloudSave", JSON.stringify(Save.data), cloud_summary(Save.data))


func _on_cloud_saved(ok: bool, error: String) -> void:
	_cloud_busy = false
	if not ok:
		_cloud_rev = -1
		print("PlayServices: cloud save failed: ", error)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		cloud_upload(true)
	if what == NOTIFICATION_APPLICATION_RESUMED and _games_started and not games_signed_in and games_available():
		_p.call("gamesCheck")  # signed in from the Play Games app or a late answer
	# A downloaded flexible update installs while the player is away (no restart in their face).
	if what == NOTIFICATION_APPLICATION_PAUSED and _downloaded and _p:
		_p.call("completeUpdate")


# ------------------------------------------------------------------------------------ review
## Pure rule (tests call it): may we ask for a review after this result?
static func review_allowed(d: Dictionary, c: Dictionary, level_id: int, won: bool, stars: int, now: int) -> bool:
	if not won or stars < int(c.get("min_stars", 3)) or level_id < int(c.get("min_level", 8)):
		return false
	if level_id > Data.CHALLENGE_BASE or int(d.get("sessions", 0)) < int(c.get("min_sessions", 2)):
		return false
	if int(d.get("review_asks", 0)) >= int(c.get("max_asks", 3)):
		return false
	return now - int(d.get("review_last", 0)) >= int(c.get("gap_days", 30)) * 86400


func _on_level_finished(level_id: int, won: bool, stars: int, _score: int) -> void:
	cloud_upload.call_deferred()
	var c: Dictionary = cfg("review")
	var now: int = int(Time.get_unix_time_from_system())
	if _p == null or not review_allowed(Save.data, c, level_id, won, stars, now):
		return
	Save.data["review_asks"] = int(Save.data.get("review_asks", 0)) + 1
	Save.data["review_last"] = now
	Save.write()
	# After the results panel has landed and the stars have counted up.
	get_tree().create_timer(float(Data.balance["result_delay_s"]) + float(c.get("delay_s", 2.5)), true).timeout.connect(func() -> void:
		Analytics.event("review_requested", {"level_id": level_id})
		_p.call("requestReview"))


# ------------------------------------------------------------------------------------ updates
## Called by the home screen. One check per session, a little after the screen appears.
func on_home(host: Node) -> void:
	if _p == null:
		return
	if not _games_started and games_available():
		# Play Games sign-in waits for the home screen so it never covers the intro.
		_games_started = true
		host.get_tree().create_timer(float(_cloud_cfg().get("signin_delay_s", 1.0))).timeout.connect(func() -> void:
			_p.call("gamesCheck"))
	if _checked:
		return
	if not bool(Save.data.get("notify_asked", false)):
		return  # the notification question comes first; check on the next home visit
	_checked = true
	host.get_tree().create_timer(float(cfg("updates").get("delay_s", 2.0))).timeout.connect(func() -> void:
		if is_instance_valid(host) and host.is_inside_tree():
			_p.call("checkUpdate"))


## Pure rule (tests call it): "immediate", "flexible" or "".
static func update_mode(d: Dictionary, c: Dictionary, version_code: int, priority: int, now: int) -> String:
	if priority >= int(c.get("immediate_priority", 4)):
		return "immediate"
	var asked: Dictionary = d.get("update_asked", {}) if d.get("update_asked", {}) is Dictionary else {}
	if now - int(asked.get(str(version_code), 0)) < int(c.get("ask_gap_hours", 24)) * 3600:
		return ""
	return "flexible"


func _on_update_checked(available_now: bool, version_code: int, priority: int, staleness_days: int) -> void:
	if not available_now:
		return
	var c: Dictionary = cfg("updates")
	var now: int = int(Time.get_unix_time_from_system())
	var mode: String = update_mode(Save.data, c, version_code, priority, now)
	if mode.is_empty():
		return
	var asked: Dictionary = Save.data.get("update_asked", {}) if Save.data.get("update_asked", {}) is Dictionary else {}
	asked = {str(version_code): now}  # only the newest version matters
	Save.data["update_asked"] = asked
	Save.write()
	Analytics.event("update_prompted", {"mode": mode, "version_code": version_code, "staleness_days": staleness_days})
	_p.call("startUpdate", mode == "immediate")
