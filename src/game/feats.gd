class_name Feats
extends RefCounted
## Level challenges on the Achievements screen (balance.feats). Each feat asks for a special win on
## one campaign level, of a "kind":
##   max_shots   win using at most n heroes          no_ability   win without any hero power
##   all_soldiers win with every soldier standing    chain        make a chain of at least n
##   fast        win within n seconds of play
## A few open feats are on show at a time and the set rotates every rotate_hours. A feat counts
## whenever it is done (shown or not); done feats wait on the screen until claimed.
## Save.data["feats"]: {id: "done" | "claimed"}.


static func cfg() -> Dictionary:
	return Data.balance.get("feats", {})


static func pool() -> Array:
	return cfg().get("pool", [])


static func _states() -> Dictionary:
	if not (Save.data.get("feats", null) is Dictionary):
		Save.data["feats"] = {}
	return Save.data["feats"]


static func state(f: Dictionary) -> String:
	var s: String = String(_states().get(String(f["id"]), ""))
	if not s.is_empty():
		return s
	return "open" if Save.is_unlocked(int(f["level"])) else "locked"


static func describe(f: Dictionary) -> String:
	var n: int = int(f.get("n", 0))
	match String(f["kind"]):
		"max_shots":
			return "Win level %d using %d shot%s or fewer" % [int(f["level"]), n, "" if n == 1 else "s"]
		"no_ability":
			return "Win level %d without using a hero power" % int(f["level"])
		"all_soldiers":
			return "Win level %d without losing a soldier" % int(f["level"])
		"chain":
			return "Make a chain of %d on level %d and win" % [n, int(f["level"])]
		"fast":
			return "Win level %d within %d seconds" % [int(f["level"]), n]
	return ""


## Short line for the in-level hint.
static func goal_text(f: Dictionary) -> String:
	var n: int = int(f.get("n", 0))
	match String(f["kind"]):
		"max_shots":
			return "%d shot%s or fewer" % [n, "" if n == 1 else "s"]
		"no_ability":
			return "no hero powers"
		"all_soldiers":
			return "lose no soldiers"
		"chain":
			return "a chain of %d" % n
		"fast":
			return "win within %d s" % n
	return ""


## Open feats on show now: rotate_hours decides the window, the order is a fixed shuffle per window.
static func showing(now_unix: int = -1) -> Array:
	var t: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var window: int = t / maxi(1, int(float(cfg().get("rotate_hours", 24)) * 3600.0))
	var open: Array = pool().filter(func(f: Dictionary) -> bool: return state(f) == "open")
	# Same shuffle for everyone in one window, a new one next window (seeded Fisher-Yates).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(window) ^ int(cfg().get("seed", 7919))
	for k: int in range(open.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, k)
		var tmp: Dictionary = open[k]
		open[k] = open[j]
		open[j] = tmp
	# Prefer different levels and kinds, then different levels, then anything.
	var out: Array = []
	var cap: int = int(cfg().get("show", 4))
	for strict: int in [2, 1, 0]:
		for f: Dictionary in open:
			if out.size() >= cap:
				break
			if out.has(f):
				continue
			var lvl_used: bool = out.any(func(o: Dictionary) -> bool: return int(o["level"]) == int(f["level"]))
			var kind_used: bool = out.any(func(o: Dictionary) -> bool: return String(o["kind"]) == String(f["kind"]))
			if (strict >= 1 and lvl_used) or (strict == 2 and kind_used):
				continue
			out.append(f)
	return out


## Feats done but not claimed, then the ones on show.
static func listed() -> Array:
	var done: Array = pool().filter(func(f: Dictionary) -> bool: return state(f) == "done")
	return done + showing()


static func for_level(level_id: int) -> Array:
	return pool().filter(func(f: Dictionary) -> bool: return int(f["level"]) == level_id and state(f) == "open")


## The shown feat for this level (for the start-of-level hint), or {}.
static func shown_for_level(level_id: int) -> Dictionary:
	for f: Dictionary in showing():
		if int(f["level"]) == level_id:
			return f
	return {}


static func met(f: Dictionary, facts: Dictionary) -> bool:
	var n: int = int(f.get("n", 0))
	match String(f["kind"]):
		"max_shots":
			return int(facts["shots"]) <= n
		"no_ability":
			return int(facts["abilities"]) == 0
		"all_soldiers":
			return int(facts["soldiers_lost"]) == 0
		"chain":
			return int(facts["chain"]) >= n
		"fast":
			return float(facts["time"]) <= float(n)
	return false


## Called on a campaign win. Returns the feats completed by this win.
static func on_win(level_id: int, facts: Dictionary) -> Array:
	var got: Array = []
	for f: Dictionary in for_level(level_id):
		if met(f, facts):
			_states()[String(f["id"])] = "done"
			got.append(f)
	if not got.is_empty():
		Save.write()
	return got


static func ready_count() -> int:
	return pool().filter(func(f: Dictionary) -> bool: return state(f) == "done").size()


static func claim(id: String) -> Dictionary:
	for f: Dictionary in pool():
		if String(f["id"]) == id and state(f) == "done":
			_states()[id] = "claimed"
			var reward: Dictionary = (f["reward"] as Dictionary).duplicate()
			for k: String in Save.WALLET:
				if reward.has(k):
					Save.add(k, int(reward[k]), false, false)
			Save.write()
			return reward
	return {}
