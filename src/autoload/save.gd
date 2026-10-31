extends Node
## Player progress + settings, stored in user://save.json (versioned, atomic write).

const PATH: String = "user://save.json"
const BACKUP: String = "user://save.json.bak"
## v4: blueprints retired (converted to coins), hero upgrades refunded, per-engine upgrades.
const VERSION: int = 4
## The two wallet currencies, in display order.
const WALLET: Array[String] = ["coins", "gems"]

var data: Dictionary = {}


func _ready() -> void:
	data = _defaults()
	var old_version: int = VERSION
	var recovered: bool = false
	var parsed: Variant = _read(PATH)
	if parsed == null and FileAccess.file_exists(PATH):
		# Unreadable (cut off by a crash or a full disk): keep it aside and use the last good copy.
		push_warning("Save: save.json unreadable, loading the backup")
		DirAccess.copy_absolute(PATH, PATH + ".broken")
		recovered = true
	if parsed == null:
		parsed = _read(BACKUP)
	if parsed is Dictionary:
		old_version = int((parsed as Dictionary).get("version", 1))
		data.merge(parsed, true)
	if recovered:
		data["save_recovered"] = int(data.get("save_recovered", 0)) + 1
	if old_version < 4:
		migrate_v4(data)
	data["version"] = VERSION
	data["sessions"] = int(data["sessions"]) + 1
	write()


## v3 -> v4. Pure on `d` so tests can run it on a copy. Never takes anything away: blueprints become
## coins, coins spent on removed hero / old weapon upgrades come back, and engines the old rules had
## already unlocked by level stay owned.
static func migrate_v4(d: Dictionary) -> void:
	var c: Dictionary = Data.balance["currencies"]
	var refund: Dictionary = c["legacy_refund"]
	var coins: int = int(d.get("coins", 0)) + int(d.get("blueprints", 0)) * int(c["blueprint_to_coins"])
	d.erase("blueprints")
	var heroes: Variant = d.get("upgrades", {})
	if heroes is Dictionary:
		for kind: Variant in heroes:
			for i: int in mini(int(heroes[kind]), (refund["hero_level"] as Array).size()):
				coins += int(refund["hero_level"][i])
	d.erase("upgrades")
	var old_w: Variant = d.get("ups_weapon", {})
	if old_w is Dictionary:
		for track: String in ["power", "reload"]:
			var lv: Variant = (old_w as Dictionary).get(track, 0)
			if lv is float or lv is int:
				for i: int in mini(int(lv), (refund["weapon_" + track] as Array).size()):
					coins += int(refund["weapon_" + track][i])
				(old_w as Dictionary).erase(track)
	d["coins"] = coins
	var owned: Dictionary = d.get("owned_weapons", {}) if d.get("owned_weapons", {}) is Dictionary else {}
	for id: String in ["ballista", "trebuchet"]:
		if int(d.get("unlocked", 1)) >= int(Data.balance["siege_weapons"][id]["unlock_level"]):
			owned[id] = true
	d["owned_weapons"] = owned


func _defaults() -> Dictionary:
	return {
		"version": VERSION, "unlocked": 1, "stars": {}, "best": {}, "coins": 0,
		"gems": int(Data.b("currencies", "start")["gems"]),
		"sessions": 0, "levels_played": 0, "no_ads": false,
		"music": true, "sfx": true, "haptics": true, "loadouts": {},
		"challenges": {}, "daily_paid": "", "rush_best": 0.0,
	}


## A save file that parses to a Dictionary, or null.
static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary and not (parsed as Dictionary).is_empty() else null


## Atomic write (temp file + rename). Before replacing it, the previous good save becomes
## save.json.bak, so a damaged file never costs more than the last change.
func write() -> void:
	var tmp: String = PATH + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save: cannot write")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if _read(tmp) == null:
		push_error("Save: written file is unreadable (disk full?), keeping the old save")
		DirAccess.remove_absolute(tmp)
		return
	if _read(PATH) != null:
		DirAccess.copy_absolute(PATH, BACKUP)
	DirAccess.rename_absolute(tmp, PATH)


## One-time introductions: story scenes ("story:7"), flyover callouts ("callout:SEESAW!"), boss
## reveals ("boss:10") and hero ability hints ("hint:quake"). Shown only until seen once.
func seen(key: String) -> bool:
	return (data.get("seen", {}) as Dictionary).has(key)


func mark_seen(key: String, save_now: bool = true) -> void:
	if not data.has("seen") or not data["seen"] is Dictionary:
		data["seen"] = {}
	if (data["seen"] as Dictionary).has(key):
		return
	data["seen"][key] = true
	if save_now:
		write()


func stars(level_id: int) -> int:
	return int(data["stars"].get(str(level_id), 0))


func is_unlocked(level_id: int) -> bool:
	return level_id <= int(data["unlocked"])



## The Master Sieges pack uses campaign stars only; challenge and secret stars live separately.
func special_pack_unlocked() -> bool:
	return total_stars() >= int(Data.b("special_pack", "star_gate"))

func total_stars() -> int:
	var t: int = 0
	for v: Variant in data["stars"].values():
		t += int(v)
	return t


func coins() -> int:
	return int(data["coins"])


func add_coins(amount: int) -> void:
	add("coins", amount)


## Wallet: "coins", "gems" (Save.WALLET).
func amount(kind: String) -> int:
	return int(data.get(kind, 0))


## emit = false: saved now, but the UI animates the change itself (UIFx.fly_reward with apply=false).
func add(kind: String, n: int, save_now: bool = true, emit: bool = true) -> void:
	data[kind] = maxi(0, amount(kind) + n)
	if emit:
		Events.currency_changed.emit(kind, amount(kind))
		if kind == "coins":
			Events.coins_changed.emit(amount(kind))
	if save_now:
		write()


## cost: {"coins": 500} or {"gems": 120}
func can_afford(cost: Dictionary) -> bool:
	for k: String in cost:
		if amount(k) < int(cost[k]):
			return false
	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k: String in cost:
		add(k, -int(cost[k]), false)
	write()
	return true


## Returns what was earned: {"coins": n, "gems": n} (zero kinds left out).
func record_result(level_id: int, won: bool, stars_got: int, score: int, boss: bool = false) -> Dictionary:
	data["levels_played"] = int(data["levels_played"]) + 1
	var out: Dictionary = {}
	if won and level_id > Data.CHALLENGE_BASE:
		out = _record_challenge(level_id, stars_got, score)
	elif won:
		out = rewards_for(level_id, stars_got, boss)
		var key: String = str(level_id)
		data["stars"][key] = maxi(stars(level_id), stars_got)
		data["best"][key] = maxi(int(data["best"].get(key, 0)), score)
		data["unlocked"] = clampi(maxi(int(data["unlocked"]), level_id + 1), 1, Data.level_count())
		for k: String in out:
			add(k, int(out[k]), false)
	write()
	return out


## Pure: rewards a win would give against the current save (call before recording).
func rewards_for(level_id: int, stars_got: int, boss: bool) -> Dictionary:
	var c: Dictionary = Data.balance["currencies"]
	var old: int = stars(level_id)
	var first: bool = old == 0
	var out: Dictionary = {"coins": int(Data.b("coins", "replay_win"))}
	if stars_got > old:
		out["coins"] = int(out["coins"]) + (stars_got - old) * int(Data.b("coins", "per_star_first_clear"))
	if stars_got == 3 and old < 3 and int(c["gems_three_star_first"]) > 0:
		out["gems"] = int(c["gems_three_star_first"])
	if boss and first:
		out["coins"] = int(out["coins"]) + int(Data.b("coins", "boss_first_clear"))
		out["gems"] = int(out.get("gems", 0)) + int(c["gems_boss_first_clear"])
	return out


## Challenge results live apart from the campaign: {id: {stars, best}}. First-time stars pay coins;
## the daily challenge pays its bonus once per calendar day.
func _record_challenge(id: int, stars_got: int, score: int) -> Dictionary:
	var key: String = str(id)
	var rec: Dictionary = data["challenges"].get(key, {"stars": 0, "best": 0})
	var out: Dictionary = {"coins": int(Data.b("coins", "replay_win"))}
	var old: int = int(rec["stars"])
	if stars_got > old:
		out["coins"] = int(out["coins"]) + (stars_got - old) * int(Data.b("coins", "per_star_first_clear"))
	if stars_got == 3 and old < 3 and int(Data.b("currencies", "gems_three_star_first")) > 0:
		out["gems"] = int(Data.b("currencies", "gems_three_star_first"))
	if id == daily_challenge_id() and not daily_paid_today():
		out["coins"] = int(out["coins"]) + int(Data.b("modes", "daily_coins"))
		data["daily_paid"] = today()
	rec["stars"] = maxi(old, stars_got)
	rec["best"] = maxi(int(rec["best"]), score)
	data["challenges"][key] = rec
	for k: String in out:
		add(k, int(out[k]), false)
	return out


func challenge_stars(id: int) -> int:
	return int(data["challenges"].get(str(id), {}).get("stars", 0))


func challenge_best(id: int) -> int:
	return int(data["challenges"].get(str(id), {}).get("best", 0))


func today() -> String:
	return Time.get_date_string_from_system()


## Days since 1970-01-01 (local date) pick the daily challenge.
## A Special Mission opens once its campaign level (index "unlock_level") is cleared.
func mission_unlocked(id: int) -> bool:
	var info: Dictionary = Data.mission_info(id)
	var need: int = int(info.get("unlock_level", 0))
	return info.is_empty() or need <= 0 or int(data.get("unlocked", 1)) > need or stars(need) > 0


## Today's mission rotates through the missions the player has opened (all of them if none yet).
func daily_challenge_id(date: String = "") -> int:
	var list: Array = Data.challenge_list().filter(func(c: Dictionary) -> bool: return mission_unlocked(int(c["id"])))
	if list.is_empty():
		list = Data.challenge_list()
	if list.is_empty():
		return 0
	var d: Dictionary = Time.get_datetime_dict_from_datetime_string(today() if date.is_empty() else date, false)
	var days: int = int(Time.get_unix_time_from_datetime_dict(d) / 86400)
	return int(list[days % list.size()]["id"])


func daily_paid_today() -> bool:
	return String(data.get("daily_paid", "")) == today()


## Boss rush: best (lowest) total time; pays like a 3-star first clear the first time.
func record_rush(seconds: float) -> Dictionary:
	var out: Dictionary = {"coins": int(Data.b("modes", "rush_coins"))}
	var best: float = float(data.get("rush_best", 0.0))
	if best <= 0.0:
		out["gems"] = int(Data.b("modes", "rush_gems"))
	if best <= 0.0 or seconds < best:
		data["rush_best"] = seconds
	for k: String in out:
		add(k, int(out[k]), false)
	write()
	return out

