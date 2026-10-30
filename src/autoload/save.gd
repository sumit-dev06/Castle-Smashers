extends Node
## Player progress + settings, stored in user://save.json (versioned, atomic write).

const PATH: String = "user://save.json"
const VERSION: int = 3

var data: Dictionary = {}


func _ready() -> void:
	data = _defaults()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			data.merge(parsed, true)
	data["version"] = VERSION
	data["sessions"] = int(data["sessions"]) + 1
	write()


func _defaults() -> Dictionary:
	return {
		"version": VERSION, "unlocked": 1, "stars": {}, "best": {}, "coins": 0,
		"gems": int(Data.b("currencies", "start")["gems"]), "blueprints": 0,
		"sessions": 0, "levels_played": 0, "no_ads": false,
		"music": true, "sfx": true, "haptics": true, "loadouts": {},
		"challenges": {}, "daily_paid": "", "rush_best": 0.0,
	}


func write() -> void:
	var tmp: String = PATH + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save: cannot write")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
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


## Wallet: "coins", "gems", "blueprints".
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


## cost: {"coins": 500, "blueprints": 1}
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


## Returns what was earned: {"coins": n, "gems": n, "blueprints": n} (zero kinds left out).
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
	if stars_got == 3 and old < 3:
		out["gems"] = int(c["gems_three_star_first"])
	if boss and first:
		out["gems"] = int(out.get("gems", 0)) + int(c["gems_boss_first_clear"])
		out["blueprints"] = int(c["blueprints_boss_first_clear"])
	elif first and level_id % int(c["blueprints_realm_every"]) == 0:
		out["blueprints"] = 1
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
	if stars_got == 3 and old < 3:
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
func daily_challenge_id(date: String = "") -> int:
	var list: Array = Data.challenge_list()
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

