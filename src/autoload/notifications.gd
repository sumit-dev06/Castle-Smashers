extends Node
## Local notifications (no server needed). Uses the CastleNotify Android plugin
## (addons/castle_notify, source tools/android_plugins/notify); a no-op elsewhere.
## Copy and timing: data/notifications.json. Everything is (re)scheduled when the app goes to the
## background and cancelled when the player returns, so no reminder ever fires while playing.
## Rules: at most max_per_day, never in quiet hours (moved to quiet_end), opt-out in Settings,
## Android 13 permission asked only after the player has played a few levels.
## Push (Firebase Cloud Messaging, src/autoload/notifications_push.gd) uses the same opt-out and
## permission: the player is subscribed to the push topics only while both are on.

const DATA: String = "res://data/notifications.json"
const DAY: int = 86400
const PUSH: String = "res://src/autoload/notifications_push.gd"

var cfg: Dictionary = {}
var _p: Object
var _push: RefCounted


func _ready() -> void:
	cfg = Data.load_json(DATA)
	if OS.get_name() == "Android" and Engine.has_singleton("CastleNotify"):
		_p = Engine.get_singleton("CastleNotify")
	if not Save.data.has("notify_on"):
		Save.data["notify_on"] = bool(cfg.get("enabled_default", true))
	_cancel_all()
	_track_open()
	_start_push()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		reschedule()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_cancel_all()
		_track_open()
		if _push:
			_push.call("resumed")
			_sync_push()


func available() -> bool:
	return _p != null


func enabled() -> bool:
	return bool(Save.data.get("notify_on", true))


func set_enabled(on: bool) -> void:
	Save.data["notify_on"] = on
	Save.write()
	if on:
		request_permission()
	else:
		_cancel_all()
	_sync_push()


func has_permission() -> bool:
	return _p != null and bool(_p.call("hasPermission"))


func request_permission() -> void:
	if _p and not has_permission():
		_p.call("requestPermission")


## Asks for the Android 13+ permission once. Called from the first home screen
## (`ask_on_home_delay_s` after it appears) and, as a fallback, after a won level.
func maybe_ask_permission(level_id: int = 0) -> void:
	if _p == null or bool(Save.data.get("notify_asked", false)) or level_id < int(cfg.get("ask_after_level", 0)):
		return
	Save.data["notify_asked"] = true
	Save.write()
	request_permission()


func ask_on_home(host: Node) -> void:
	if _p == null or bool(Save.data.get("notify_asked", false)):
		return
	host.get_tree().create_timer(float(cfg.get("ask_on_home_delay_s", 1.0))).timeout.connect(func() -> void:
		if is_instance_valid(host) and host.is_inside_tree():
			maybe_ask_permission())


## True while the one-time notification permission ask is still waiting to show on home.
func will_ask() -> bool:
	return _p != null and not bool(Save.data.get("notify_asked", false))


func reschedule() -> void:
	_cancel_all()
	if _p == null or not enabled():
		return
	for n: Dictionary in plan(int(Time.get_unix_time_from_system())):
		_p.call("schedule", int(n["id"]), String(n["title"]), String(n["body"]), int(n["delay"]), String(n["kind"]))
	Save.write()


## Debug builds only: send every reminder kind once, `first_s` seconds from now and then
## `gap_s` apart, so their look and wording can be checked on a phone. Uses ids 900+ so the
## normal reschedule on leaving the app does not cancel them. Returns how many were sent.
func send_test(first_s: int = 10, gap_s: int = 8) -> int:
	if _p == null or not OS.is_debug_build():
		return 0
	var kinds: Dictionary = cfg.get("kinds", {})
	var i: int = 0
	for kind: String in kinds:
		var line: Array = _pick(kind, kinds[kind]["lines"])
		_p.call("schedule", 900 + i, _fill(String(line[0])), _fill(String(line[1])), first_s + i * gap_s, kind)
		i += 1
	return i


## Pure plan for `now` (unix seconds): [{id, kind, title, body, delay}] after caps and quiet hours.
func plan(now: int) -> Array:
	var out: Array = []
	var kinds: Dictionary = cfg.get("kinds", {})
	for kind: String in kinds:
		var k: Dictionary = kinds[kind]
		if not _needs(String(k.get("needs", ""))):
			continue
		var at: int = _when(kind, k, now)
		if at <= now:
			continue
		at = _out_of_quiet(at)
		var line: Array = _pick(kind, k["lines"])
		out.append({"id": int(k["id"]), "kind": kind, "title": _fill(String(line[0])), "body": _fill(String(line[1])), "at": at})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = int(kinds[a["kind"]].get("priority", 5))
		var pb: int = int(kinds[b["kind"]].get("priority", 5))
		return pa < pb if pa != pb else int(a["at"]) < int(b["at"]))
	# Frequency cap: no two reminders on the same local day.
	var used_days: Dictionary = {}
	var capped: Array = []
	var per_day: int = int(cfg.get("max_per_day", 1))
	for n: Dictionary in out:
		var d: int = int(n["at"]) / DAY
		if int(used_days.get(d, 0)) >= per_day:
			continue
		used_days[d] = int(used_days.get(d, 0)) + 1
		n["delay"] = int(n["at"]) - now
		capped.append(n)
	return capped


func _when(kind: String, k: Dictionary, now: int) -> int:
	match String(k["rule"]):
		"next_local_time":
			var t: Dictionary = Time.get_datetime_dict_from_unix_time(_local(now))
			var today_at: int = now - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"])) + int(k["hour"]) * 3600
			return today_at + DAY if today_at <= now + 600 else today_at
		"energy_full":
			# The moment every bar is back, but never a ping just minutes after closing the game.
			return now + maxi(int(k.get("min_delay_s", 600)), ceili(Energy.ready_in_s(Energy.max_bars())))
		"after_hours":
			return now + int(k["hours"]) * 3600
		"after_days":
			return now + int(k["days"]) * DAY
		"on_version_change":
			var ver: String = String(ProjectSettings.get_setting("application/config/version", ""))
			if String(Save.data.get("notify_version", "")) == ver:
				return 0
			Save.data["notify_version"] = ver
			return now + 3 * 3600 if Save.data.has("notify_seen_once") else 0
	return 0


func _needs(n: String) -> bool:
	match n:
		"":
			return true
		"spin_used_today":
			return not SpinWheel.free_spin_ready()
		"daily_claimed_today":
			return not DailyRewards.can_claim()
		"chest_within_3":
			return _stars_short() > 0 and _stars_short() <= 3
		"energy_spent":
			return Energy.enabled() and int(Save.data["unlocked"]) > int(Energy.cfg().get("free_until_level", 0)) \
					and Energy.bars() < Energy.max_bars()
		"special_pack_new":
			return Save.special_pack_unlocked() and not Save.seen("notify:special")
	return false


## Stars still missing for the next realm chest in the current realm (0 = none pending).
func _stars_short() -> int:
	var realm: int = int(Data.level(clampi(int(Save.data["unlocked"]), 1, Data.level_count())).get("realm", 1))
	for tier: int in 3:
		if Progression.chest_state(realm, tier) == "locked":
			return int(Data.balance["realm_chests"]["stars"][tier]) - Progression.realm_stars(realm)
	return 0


## Never wake anyone up: moves a time inside quiet hours to the next quiet_end.
func _out_of_quiet(at: int) -> int:
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(_local(at))
	var h: int = int(t["hour"])
	var qs: int = int(cfg.get("quiet_start_hour", 22))
	var qe: int = int(cfg.get("quiet_end_hour", 9))
	if h >= qs or h < qe:
		var day_start: int = at - (h * 3600 + int(t["minute"]) * 60 + int(t["second"]))
		return day_start + (DAY if h >= qs else 0) + qe * 3600
	return at


func _local(unix: int) -> int:
	return unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## Picks a line, never the same one twice in a row for a kind.
func _pick(kind: String, lines: Array) -> Array:
	var last: Dictionary = Save.data.get("notify_last", {}) if Save.data.get("notify_last", {}) is Dictionary else {}
	var prev: int = int(last.get(kind, -1))
	var i: int = randi() % lines.size()
	if lines.size() > 1 and i == prev:
		i = (i + 1) % lines.size()
	last[kind] = i
	Save.data["notify_last"] = last
	Save.data["notify_seen_once"] = true
	return lines[i]


func _fill(s: String) -> String:
	var level: int = clampi(int(Save.data["unlocked"]), 1, Data.level_count())
	var d: Dictionary = Data.level(level)
	var boss_name: String = "Iron Baron"
	for b: int in range(level, Data.level_count() + 1):
		if bool(Data.level(b).get("boss", false)):
			boss_name = String(Data.level(b).get("boss_unit", {}).get("name", boss_name))
			break
	return s.replace("{level}", str(level)).replace("{realm}", String(Background.realm_info(int(d.get("realm", 1))).get("name", ""))) \
			.replace("{boss}", boss_name).replace("{coins}", CurrencyBar._fmt(Save.coins())) \
			.replace("{streak_next}", str(DailyRewards.next_day() + 1)).replace("{stars_short}", str(_stars_short()))


func _cancel_all() -> void:
	if _p == null:
		return
	var ids: PackedInt32Array = PackedInt32Array()
	for kind: String in cfg.get("kinds", {}):
		ids.append(int(cfg["kinds"][kind]["id"]))
	_p.call("cancelAll", ids)


func _track_open() -> void:
	if _p == null:
		return
	var kind: String = String(_p.call("lastOpenedKind"))
	if not kind.is_empty():
		Analytics.event("notification_opened", {"kind": kind})
		if kind == "special_unlocked":
			Save.mark_seen("notify:special")


# ------------------------------------------------------------------------------------ push (FCM)
func push_available() -> bool:
	return _push != null and bool(_push.call("is_ready"))


func _start_push() -> void:
	if OS.get_name() != "Android" or not ResourceLoader.exists(PUSH):
		return
	var b: RefCounted = (load(PUSH) as GDScript).new()
	if not bool(b.call("available")):
		return
	_push = b
	var pc: Dictionary = cfg.get("push", {})
	b.connect("opened", func(_title: String) -> void: Analytics.event("notification_opened", {"kind": "push"}))
	b.call("start", pc.get("topics", []), int(pc.get("opened_window_ms", 4000)))
	# Firebase Core answers asynchronously; subscribe once it is up.
	get_tree().create_timer(float(pc.get("sync_delay_s", 3.0))).timeout.connect(_sync_push)


## Topics follow the Settings switch and the Android permission.
func _sync_push() -> void:
	if _push:
		_push.call("sync", enabled() and has_permission())
