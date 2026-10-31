extends Node
## Ads wrapper. Gameplay and UI call only this (docs/MONETIZATION.md).
## On Android with the AdMob plugin (addons/admob) it drives src/autoload/ads_admob.gd. Everywhere
## else it is a stub: debug builds grant rewarded ads so flows can be tested, release builds fail.
## Remove Ads (Store entitlement) turns off EVERY format: nothing loads or shows, and opt-in ad
## bonuses (extra Rocky, spins, double coins) are granted instantly instead.
## Unit IDs: debug builds always use Google's public test units. Release builds read the real ones
## from res://ad_ids.cfg (git-ignored, see docs/MONETIZATION.md) and fall back to the test units.

signal rewarded_earned(reward_id: String)
signal rewarded_failed(reward_id: String)

const BACKEND: String = "res://src/autoload/ads_admob.gd"
const IDS_FILE: String = "res://ad_ids.cfg"
## Google's public Android test units (https://developers.google.com/admob/android/test-ads).
const TEST_INTERSTITIAL: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED: String = "ca-app-pub-3940256099942544/5224354917"

var _last_interstitial_ms: int = -1000000000
var _backend: RefCounted = null


func _ready() -> void:
	Store.entitlements_changed.connect(_on_entitlements)
	if not available() or ads_removed():
		return
	_start_backend()


func _start_backend() -> void:
	if _backend != null:
		return
	_backend = (load(BACKEND) as GDScript).new()
	var ids: Array[String] = unit_ids()
	_backend.set("interstitial_id", ids[0])
	_backend.set("rewarded_id", ids[1])
	_backend.connect("rewarded_earned", func(id: String) -> void: rewarded_earned.emit(id))
	_backend.connect("rewarded_failed", func(id: String) -> void: rewarded_failed.emit(id))
	_backend.call("start")


func available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("PoingGodotAdMob")


func ads_removed() -> bool:
	return bool(Save.data.get("no_ads", false))


## Remove Ads restored or bought: unload and stop everything. Refunded: ads may start again.
func _on_entitlements() -> void:
	if ads_removed():
		if _backend:
			_backend.call("shutdown")
			_backend = null
	elif available():
		_start_backend()


## [interstitial, rewarded] unit ids for this build.
func unit_ids() -> Array[String]:
	var ids: Array[String] = [TEST_INTERSTITIAL, TEST_REWARDED]
	if OS.is_debug_build():
		return ids
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(IDS_FILE) != OK:
		push_warning("Ads: %s missing, release build uses Google test ads" % IDS_FILE)
		return ids
	ids[0] = String(cfg.get_value("android", "interstitial", TEST_INTERSTITIAL))
	ids[1] = String(cfg.get_value("android", "rewarded", TEST_REWARDED))
	return ids


## One match played (a level finished, or left/restarted after a shot). Saved, so the count
## survives app restarts.
func match_played() -> void:
	Save.data["ad_matches"] = int(Save.data.get("ad_matches", 0)) + 1


func matches_since() -> int:
	return int(Save.data.get("ad_matches", 0))


## True when the next break may show an interstitial (every frequency rule).
func interstitial_due(level_id: int) -> bool:
	if ads_removed():
		return false
	if bool(Data.b("ads", "skip_first_session")) and int(Save.data["sessions"]) <= 1:
		return false
	if level_id < int(Data.b("ads", "interstitial_min_level")):
		return false
	if matches_since() < int(Data.b("ads", "interstitial_every_matches")):
		return false
	return Time.get_ticks_msec() - _last_interstitial_ms >= int(Data.b("ads", "interstitial_min_gap_s")) * 1000


## A break between matches (results NEXT / RETRY / MAP, pause MAP / RESTART): show the
## interstitial if due, then run `then` once it closes (or right away). If no ad is loaded the
## count is kept, so it shows at the next break instead.
func match_break(level_id: int, then: Callable) -> void:
	if not interstitial_due(level_id) or _backend == null or not bool(_backend.call("has_interstitial")):
		if _backend != null and interstitial_due(level_id):
			_backend.call("load_interstitial")
		then.call()
		return
	Save.data["ad_matches"] = 0
	Save.write()
	_last_interstitial_ms = Time.get_ticks_msec()
	Analytics.event("interstitial_shown", {"level_id": level_id})
	Analytics.set_crash_key("phase", "ad_interstitial")
	_backend.connect("interstitial_closed", then, CONNECT_ONE_SHOT)
	if not bool(_backend.call("show_interstitial")):
		_backend.disconnect("interstitial_closed", then)
		then.call()


## True where the law needs an "Ad privacy" entry in Settings (EEA, UK, Switzerland).
func privacy_options_required() -> bool:
	return _backend != null and bool(_backend.call("privacy_options_required"))


## Re-opens Google's consent form so the player can change their ad choices.
func show_privacy_options() -> void:
	if _backend:
		_backend.call("show_privacy_options")


func rewarded_ready() -> bool:
	if ads_removed():
		return true
	if _backend:
		return bool(_backend.call("has_rewarded"))
	return OS.is_debug_build()


func show_rewarded(reward_id: String) -> void:
	Analytics.set_crash_key("phase", "ad_rewarded")
	Analytics.breadcrumb("rewarded:" + reward_id)
	if ads_removed():
		rewarded_earned.emit.call_deferred(reward_id)
	elif _backend:
		_backend.call("show_rewarded", reward_id)
	elif OS.is_debug_build():
		rewarded_earned.emit.call_deferred(reward_id)
	else:
		rewarded_failed.emit.call_deferred(reward_id)
