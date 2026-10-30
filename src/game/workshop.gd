class_name Workshop
extends RefCounted
## Master Orin's Workshop: spend coins to upgrade each hero (3 levels). Tracks, costs and stat
## multipliers live in balance.json "workshop". Upgrades are applied to a copy of the hero config
## when a projectile is created, so data/projectiles.json stays the base values.


static func level_of(kind: String) -> int:
	var ups: Variant = Save.data.get("upgrades", {})
	return int((ups as Dictionary).get(kind, 0)) if ups is Dictionary else 0


static func max_level() -> int:
	return int(Data.b("workshop", "max_level"))


static func track(kind: String) -> Dictionary:
	return (Data.b("workshop", "tracks") as Dictionary).get(kind, {})


## Cost of the next level, or -1 when maxed.
static func next_cost(kind: String) -> int:
	var lv: int = level_of(kind)
	var costs: Array = Data.b("workshop", "costs")
	return int(costs[lv]) if lv < mini(max_level(), costs.size()) else -1


static func can_buy(kind: String) -> bool:
	var c: int = next_cost(kind)
	return c >= 0 and Save.coins() >= c and not track(kind).is_empty()


static func buy(kind: String) -> bool:
	if not can_buy(kind):
		return false
	var c: int = next_cost(kind)
	if not (Save.data.get("upgrades", null) is Dictionary):
		Save.data["upgrades"] = {}
	Save.data["upgrades"][kind] = level_of(kind) + 1
	Save.add_coins(-c)
	return true


## Hero config with upgrades applied. Keys like "explosion.radius" reach into nested dictionaries.
static func config(kind: String) -> Dictionary:
	var cfg: Dictionary = (Data.projectiles[kind] as Dictionary).duplicate(true)
	var lv: int = level_of(kind)
	if lv <= 0:
		return cfg
	var mult: Dictionary = track(kind).get("mult", {})
	for key: Variant in mult.keys():
		var parts: PackedStringArray = String(key).split(".")
		var target: Dictionary = cfg
		for i: int in parts.size() - 1:
			target = target[parts[i]]
		var leaf: String = parts[parts.size() - 1]
		target[leaf] = float(target[leaf]) * (1.0 + float(mult[key]) * lv)
	return cfg
