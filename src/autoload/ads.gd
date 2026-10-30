extends Node
## Ads wrapper. Gameplay and UI call only this (docs/MONETIZATION.md).
## On Android with the AdMob plugin (addons/admob) it drives src/autoload/ads_admob.gd. Everywhere
## else it is a stub: debug builds grant rewarded ads so flows can be tested, release builds fail.
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
var _levels_since: int = 0
var _backend: RefCounted = null


func _ready() -> void:
	if not available():
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


## True when the level-end flow may show an interstitial now (every frequency rule).
func interstitial_due(level_id: int) -> bool:
	if bool(Save.data.get("no_ads", false)):
		return false
	if bool(Data.b("ads", "skip_first_session")) and int(Save.data["sessions"]) <= 1:
		return false
	if level_id < int(Data.b("ads", "interstitial_min_level")):
		return false
	if _levels_since < int(Data.b("ads", "interstitial_every_levels")):
		return false
	return Time.get_ticks_msec() - _last_interstitial_ms >= int(Data.b("ads", "interstitial_min_gap_s")) * 1000


## Called by the result screen when the player continues. Respects every frequency rule.
func maybe_show_interstitial(level_id: int) -> void:
	_levels_since += 1
	if not interstitial_due(level_id):
		return
	if _backend and bool(_backend.call("show_interstitial")):
		_levels_since = 0
		_last_interstitial_ms = Time.get_ticks_msec()


func rewarded_ready() -> bool:
	if _backend:
		return bool(_backend.call("has_rewarded"))
	return OS.is_debug_build()


func show_rewarded(reward_id: String) -> void:
	if _backend:
		_backend.call("show_rewarded", reward_id)
	elif OS.is_debug_build():
		rewarded_earned.emit.call_deferred(reward_id)
	else:
		rewarded_failed.emit.call_deferred(reward_id)
