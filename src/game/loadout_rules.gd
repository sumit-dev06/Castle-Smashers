class_name LoadoutRules
extends RefCounted
## Pure, data-driven rules for the four-shot pre-battle loadout.


static func slots() -> int:
	return int(Data.b("loadout", "slots"))


static func power_budget(level_data: Dictionary, level_id: int) -> int:
	if level_data.has("power_budget"):
		return int(level_data["power_budget"])
	return int(Data.b("loadout", "late_power_budget")) if level_id >= int(Data.b("loadout", "late_budget_level")) \
			else int(Data.b("loadout", "default_power_budget"))


static func unlocked_kinds(level_id: int, level_data: Dictionary = {}) -> Array[String]:
	var allowed: Array = level_data.get("allowed_heroes", [])
	var out: Array[String] = []
	for key: Variant in Data.projectiles.keys():
		var kind: String = String(key)
		var cfg: Variant = Data.projectiles[kind]
		if not (cfg is Dictionary) or not (cfg as Dictionary).has("name"):
			continue
		if int((cfg as Dictionary).get("unlock_level", 999)) > level_id:
			continue
		if not allowed.is_empty() and not allowed.has(kind):
			continue
		out.append(kind)
	out.sort_custom(func(a: String, b: String) -> bool:
		return int(Data.projectiles[a]["unlock_level"]) < int(Data.projectiles[b]["unlock_level"]))
	return out


static func cost(loadout: Array) -> int:
	var total: int = 0
	for value: Variant in loadout:
		var kind: String = String(value)
		if Data.projectiles.has(kind):
			total += int(Data.projectiles[kind].get("power_cost", 0))
	return total


static func error(loadout: Array, level_id: int, level_data: Dictionary) -> String:
	if loadout.size() != slots():
		return "Choose exactly %d heroes." % slots()
	var available: Array[String] = unlocked_kinds(level_id, level_data)
	var counts: Dictionary = {}
	for value: Variant in loadout:
		var kind: String = String(value)
		if not available.has(kind):
			return "%s is not available for this assault." % kind.capitalize()
		counts[kind] = int(counts.get(kind, 0)) + 1
		if int(counts[kind]) > int(Data.projectiles[kind]["max_per_loadout"]):
			return "Only %d %s allowed." % [int(Data.projectiles[kind]["max_per_loadout"]), String(Data.projectiles[kind]["name"])]
	var budget: int = power_budget(level_data, level_id)
	if cost(loadout) > budget:
		return "Power %d / %d. Replace a specialist with Rocky." % [cost(loadout), budget]
	return ""


static func valid(loadout: Array, level_id: int, level_data: Dictionary) -> bool:
	return error(loadout, level_id, level_data).is_empty()


static func recommended(level_data: Dictionary, level_id: int) -> Array[String]:
	var raw: Array = level_data.get("heroes", [])
	var out: Array[String] = []
	for value: Variant in raw:
		if out.size() >= slots():
			break
		out.append(String(value))
	while out.size() < slots():
		out.append("stone")
	if valid(out, level_id, level_data):
		return out
	# A legal baseline is always possible because Rocky costs one power and allows four copies.
	out.clear()
	for i: int in slots():
		out.append("stone")
	return out


static func saved_or_recommended(level_data: Dictionary, level_id: int) -> Array[String]:
	var saved_all: Variant = Save.data.get("loadouts", {})
	if saved_all is Dictionary:
		var saved: Variant = (saved_all as Dictionary).get(str(level_id), [])
		if saved is Array and valid(saved, level_id, level_data):
			var out: Array[String] = []
			for value: Variant in saved:
				out.append(String(value))
			return out
	return recommended(level_data, level_id)
