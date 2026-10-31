class_name Energy
extends RefCounted
## Army energy: each campaign attempt costs bars; bars come back over time, fast at first and
## slower for each further bar (balance.json energy.refill_s, one entry per bar counted up from
## empty). A rewarded ad can top up enough bars for one level, but not twice in a row: the next
## level must be paid with rested bars. Save.data["energy"] = {bars, t, ad_lock}.


static func cfg() -> Dictionary:
	return Data.balance["energy"]


static func enabled() -> bool:
	return bool(cfg()["enabled"])


static func max_bars() -> int:
	return int(cfg()["max"])


## Bars needed to start campaign level `id` (0 for the opening levels and anything else).
static func cost(id: int) -> int:
	if not enabled() or id < 1 or id > Data.level_count() or id <= int(cfg()["free_until_level"]):
		return 0
	var lv: Dictionary = Data.level(id)
	if bool(lv.get("boss", false)):
		return int(cfg()["cost_boss"])
	return int(cfg()["cost_hard"]) if int(lv.get("realm", 1)) >= int(cfg()["hard_from_realm"]) else int(cfg()["cost"])


static func _state() -> Dictionary:
	if not Save.data.has("energy") or not (Save.data["energy"] is Dictionary):
		Save.data["energy"] = {"bars": max_bars(), "t": _now(), "ad_lock": false}
	return Save.data["energy"]


static func _now() -> float:
	return Time.get_unix_time_from_system()


## Seconds the next bar takes when `bars` are full.
static func step_s(bars: int) -> float:
	var steps: Array = cfg()["refill_s"]
	return float(steps[clampi(bars, 0, steps.size() - 1)])


## Applies the time passed since the last update: rested bars are added one by one.
static func _tick() -> Dictionary:
	var s: Dictionary = _state()
	var now: float = _now()
	var bars: int = int(s["bars"])
	var t: float = float(s["t"])
	if now < t:
		t = now  # clock moved back: never refill (or drain) from it
	if bars >= max_bars():
		t = now
	while bars < max_bars() and now - t >= step_s(bars):
		t += step_s(bars)
		bars += 1
	if bars >= max_bars():
		t = now
	s["bars"] = bars
	s["t"] = t
	return s


static func bars() -> int:
	return int(_tick()["bars"])


## Seconds until the next bar (0 when full).
static func next_in_s() -> float:
	var s: Dictionary = _tick()
	if int(s["bars"]) >= max_bars():
		return 0.0
	return maxf(0.0, float(s["t"]) + step_s(int(s["bars"])) - _now())


## Seconds until the bars reach `need`.
static func ready_in_s(need: int) -> float:
	var s: Dictionary = _tick()
	var b: int = int(s["bars"])
	if b >= need:
		return 0.0
	var total: float = next_in_s()
	for k: int in range(b + 1, mini(need, max_bars())):
		total += step_s(k)
	return total


static func can_play(id: int) -> bool:
	return bars() >= cost(id)


## True when a rewarded ad may top up the bars for this level.
static func ad_allowed() -> bool:
	return enabled() and not bool(_state().get("ad_lock", false))


## Takes the level's bars. False (nothing taken) when there are not enough.
static func spend(id: int) -> bool:
	var c: int = cost(id)
	if c <= 0:
		return true
	var s: Dictionary = _tick()
	if int(s["bars"]) < c:
		return false
	var was_full: bool = int(s["bars"]) >= max_bars()
	s["bars"] = int(s["bars"]) - c
	if was_full:
		s["t"] = _now()
	s["ad_lock"] = false
	Save.write()
	Events.currency_changed.emit("energy", int(s["bars"]))
	return true


## Rewarded ad: tops up exactly what level `id` needs and starts it; the next level must wait.
static func ad_refill_and_spend(id: int) -> void:
	var s: Dictionary = _tick()
	var need: int = cost(id)
	s["bars"] = maxi(int(s["bars"]), need) - need
	s["ad_lock"] = true
	Save.write()
	Events.currency_changed.emit("energy", int(s["bars"]))


static func fmt_time(sec: float) -> String:
	var n: int = int(ceil(sec))
	if n >= 3600:
		return "%d:%02d:%02d" % [n / 3600, (n / 60) % 60, n % 60]
	return "%d:%02d" % [n / 60, n % 60]
