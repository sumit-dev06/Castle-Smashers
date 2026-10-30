class_name Progression
extends RefCounted
## Kingdom progression (docs/SIGNATURE_FEATURES.md section 6): siege weapons, Vanguard and weapon
## upgrades, cosmetics, realm chests, kingdom rank, achievements and secret scrolls.
## Everything is stored in Save.data; numbers in data/balance.json (siege_weapons, upgrades,
## cosmetics, realm_chests, rank, secrets, achievements).


static func _dict(key: String) -> Dictionary:
	if not (Save.data.get(key, null) is Dictionary):
		Save.data[key] = {}
	return Save.data[key]


# ---------------------------------------------------------------------------------- stats
## Lifetime counters for achievements (blocks, archers, wins, chain_best, ...). Saved with the level.
static func bump(stat: String, n: int = 1) -> void:
	var s: Dictionary = _dict("stats")
	s[stat] = int(s.get(stat, 0)) + n


static func best(stat: String, v: int) -> void:
	var s: Dictionary = _dict("stats")
	s[stat] = maxi(int(s.get(stat, 0)), v)


static func stat(name: String) -> int:
	match name:
		"stars":
			return Save.total_stars()
		"secrets":
			return _dict("secrets").size()
	return int(_dict("stats").get(name, 0))


# ---------------------------------------------------------------------------------- siege weapons
static func weapon_cfg(id: String = "") -> Dictionary:
	var sw: Dictionary = Data.balance["siege_weapons"]
	return sw.get(weapon() if id.is_empty() else id, sw["catapult"])


static func weapons() -> Array:
	return Data.balance["siege_weapons"]["order"]


static func weapon_unlocked(id: String) -> bool:
	var need: int = int(weapon_cfg(id)["unlock_level"])
	return need <= 1 or Save.is_unlocked(need)


static func weapon() -> String:
	var w: String = String(Save.data.get("weapon", "catapult"))
	return w if weapon_unlocked(w) else "catapult"


static func set_weapon(id: String) -> void:
	if weapon_unlocked(id):
		Save.data["weapon"] = id
		Save.write()


# ---------------------------------------------------------------------------------- upgrades
## group: "vanguard" or "weapon"; track: armor, shields, power, reload.
static func up_cfg(group: String, track: String) -> Dictionary:
	return Data.balance["upgrades"][group][track]


static func up_level(group: String, track: String) -> int:
	return int(_dict("ups_" + group).get(track, 0))


static func up_cost(group: String, track: String) -> Dictionary:
	var c: Dictionary = up_cfg(group, track)
	var lv: int = up_level(group, track)
	return {} if lv >= int(c["max"]) else (c["cost"] as Array)[lv]


static func buy_up(group: String, track: String) -> bool:
	var cost: Dictionary = up_cost(group, track)
	if cost.is_empty() or not Save.spend(cost):
		return false
	_dict("ups_" + group)[track] = up_level(group, track) + 1
	Save.write()
	return true


static func soldier_hp() -> int:
	return int(Data.b("soldiers", "hp")) + up_level("vanguard", "armor") * int(up_cfg("vanguard", "armor")["per_level"])


static func shield_chance() -> float:
	return Data.bf("soldiers", "shield_block_chance") + up_level("vanguard", "shields") * float(up_cfg("vanguard", "shields")["per_level"])


## Launch speed multiplier from the weapon and its power upgrade.
static func speed_mult() -> float:
	return float(weapon_cfg()["speed_mult"]) * (1.0 + up_level("weapon", "power") * float(up_cfg("weapon", "power")["per_level"]))


static func reload_mult() -> float:
	return float(weapon_cfg()["reload_mult"]) * (1.0 - up_level("weapon", "reload") * float(up_cfg("weapon", "reload")["per_level"]))


static func gravity_scale() -> float:
	return float(weapon_cfg()["gravity_scale"])


static func mass_mult() -> float:
	return float(weapon_cfg()["mass_mult"])


# ---------------------------------------------------------------------------------- cosmetics
## kind: "skins" or "trails".
static func cosmetic(kind: String, id: String) -> Dictionary:
	return Data.balance["cosmetics"][kind].get(id, {})


static func owns(kind: String, id: String) -> bool:
	var c: Dictionary = cosmetic(kind, id)
	if c.is_empty():
		return false
	if (c["price"] as Dictionary).is_empty() and not c.has("source"):
		return true
	return (_dict("owned").get(kind, []) as Array).has(id)


static func grant(kind: String, id: String) -> void:
	var o: Dictionary = _dict("owned")
	var list: Array = o.get(kind, [])
	if not list.has(id):
		list.append(id)
	o[kind] = list


static func buy_cosmetic(kind: String, id: String) -> bool:
	var c: Dictionary = cosmetic(kind, id)
	if owns(kind, id) or c.is_empty() or (c["price"] as Dictionary).is_empty():
		return false
	if not Save.spend(c["price"]):
		return false
	grant(kind, id)
	Save.write()
	return true


static func equipped(kind: String) -> String:
	var key: String = "skin" if kind == "skins" else "trail"
	var id: String = String(Save.data.get(key, "default" if kind == "skins" else "dots"))
	return id if owns(kind, id) else ("default" if kind == "skins" else "dots")


static func equip(kind: String, id: String) -> bool:
	if not owns(kind, id):
		return false
	Save.data["skin" if kind == "skins" else "trail"] = id
	Save.write()
	return true


static func _col(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)


## Catapult tints: weapon look times skin look. [base, arm]
static func catapult_tints() -> Array:
	var w: Dictionary = weapon_cfg()
	var s: Dictionary = cosmetic("skins", equipped("skins"))
	return [_col(w["tint_base"]) * _col(s["tint_base"]), _col(w["tint_arm"]) * _col(s["tint_arm"])]


static func trail_color() -> Color:
	return _col(cosmetic("trails", equipped("trails"))["color"])


# ---------------------------------------------------------------------------------- realm chests + rank
static func realm_stars(realm: int) -> int:
	var t: int = 0
	for id: int in range(1, Data.level_count() + 1):
		if int(Data.level(id).get("realm", 1)) == realm:
			t += Save.stars(id)
	return t


## 0..2 tiers per realm: "ready", "claimed" or "locked".
static func chest_state(realm: int, tier: int) -> String:
	if (_dict("realm_chests").get(str(realm), []) as Array).has(tier):
		return "claimed"
	return "ready" if realm_stars(realm) >= int(Data.balance["realm_chests"]["stars"][tier]) else "locked"


## Returns the reward given (currencies, optional "skin"), or {} when not ready.
static func claim_chest(realm: int, tier: int) -> Dictionary:
	if chest_state(realm, tier) != "ready":
		return {}
	var rc: Dictionary = Data.balance["realm_chests"]
	var reward: Dictionary = (rc["rewards"][tier] as Dictionary).duplicate()
	var skin: String = String((rc["skin_at_tier"] as Dictionary).get(str(realm), {}).get(str(tier), ""))
	if not skin.is_empty():
		grant("skins", skin)
		reward["skin"] = skin
	var claimed: Dictionary = _dict("realm_chests")
	var list: Array = claimed.get(str(realm), [])
	list.append(tier)
	claimed[str(realm)] = list
	_pay(reward)
	return reward


static func rank_index() -> int:
	var th: Array = Data.balance["rank"]["stars"]
	var stars: int = Save.total_stars()
	var r: int = 0
	for i: int in th.size():
		if stars >= int(th[i]):
			r = i
	return r


static func rank_name() -> String:
	return String(Data.balance["rank"]["names"][rank_index()])


## 0..1 progress to the next rank.
static func rank_progress() -> float:
	var th: Array = Data.balance["rank"]["stars"]
	var i: int = rank_index()
	if i >= th.size() - 1:
		return 1.0
	return clampf(float(Save.total_stars() - int(th[i])) / float(int(th[i + 1]) - int(th[i])), 0.0, 1.0)


# ---------------------------------------------------------------------------------- achievements
static func achievements() -> Array:
	return Data.balance["achievements"]


static func ach_progress(a: Dictionary) -> int:
	return mini(stat(String(a["stat"])), int(a["goal"]))


static func ach_state(a: Dictionary) -> String:
	if (_dict("ach_claimed").has(String(a["id"]))):
		return "claimed"
	return "ready" if ach_progress(a) >= int(a["goal"]) else "locked"


static func ready_count() -> int:
	var n: int = 0
	for a: Dictionary in achievements():
		if ach_state(a) == "ready":
			n += 1
	return n


static func claim_achievement(id: String) -> Dictionary:
	for a: Dictionary in achievements():
		if String(a["id"]) == id and ach_state(a) == "ready":
			var reward: Dictionary = (a["reward"] as Dictionary).duplicate()
			_dict("ach_claimed")[id] = true
			if reward.has("skin"):
				grant("skins", String(reward["skin"]))
			_pay(reward)
			return reward
	return {}


static func _pay(reward: Dictionary) -> void:
	for k: String in ["coins", "gems", "blueprints"]:
		if reward.has(k):
			Save.add(k, int(reward[k]), false, false)
	Save.write()


# ---------------------------------------------------------------------------------- secrets
static func secret_level(realm: int) -> int:
	return int(Data.balance["secrets"]["levels"].get(str(realm), 0))


static func secret_found(realm: int) -> bool:
	return _dict("secrets").has(str(realm))


static func find_secret(realm: int) -> bool:
	if secret_found(realm):
		return false
	_dict("secrets")[str(realm)] = true
	Save.write()
	return true
