extends Node
## AdMob wrapper. Gameplay calls only this. Works as a no-op stub when the plugin is missing.
## Plugin integration: phase 3 (docs/MONETIZATION.md).

signal rewarded_earned(reward_id: String)
signal rewarded_failed(reward_id: String)

var _last_interstitial_ms: int = -1000000000
var _levels_since: int = 0


func available() -> bool:
	return Engine.has_singleton("PoingGodotAdMob")


## Called by the result screen when the player continues. Respects every frequency rule.
func maybe_show_interstitial(level_id: int) -> void:
	_levels_since += 1
	if bool(Save.data.get("no_ads", false)):
		return
	if bool(Data.b("ads", "skip_first_session")) and int(Save.data["sessions"]) <= 1:
		return
	if level_id < int(Data.b("ads", "interstitial_min_level")):
		return
	if _levels_since < int(Data.b("ads", "interstitial_every_levels")):
		return
	if Time.get_ticks_msec() - _last_interstitial_ms < int(Data.b("ads", "interstitial_min_gap_s")) * 1000:
		return
	_levels_since = 0
	_last_interstitial_ms = Time.get_ticks_msec()
	if available():
		pass # TODO(phase 3): show loaded interstitial via plugin


## Debug builds without the plugin grant the reward (flow testing); release builds fail.
func show_rewarded(reward_id: String) -> void:
	if available():
		pass # TODO(phase 3)
	elif OS.is_debug_build():
		rewarded_earned.emit.call_deferred(reward_id)
	else:
		rewarded_failed.emit.call_deferred(reward_id)
