extends Node
## Scene switching, command-line flags and small global helpers.
## User args come after "--":  --level=N  --screenshot=path.png  --shot-delay=3
##                             --autoshot=angle_deg,power[,ability_delay_s]  --run-tests
##                             --force-win=seconds (debug: win the level for results screenshots)
##                             --map  --story=N

const LevelScript: GDScript = preload("res://src/game/level.gd")
const MenuScript: GDScript = preload("res://src/ui/main_menu.gd")
const MapScript: GDScript = preload("res://src/ui/world_map.gd")
const WorkshopScript: GDScript = preload("res://src/ui/upgrades_screen.gd")
const ChallengesScript: GDScript = preload("res://src/ui/challenges_screen.gd")

var args: Dictionary = {}
## Boss rush run: {levels, index, pool, soldier_hp, time}. Empty = no rush.
var rush: Dictionary = {}
## Next goto_level() skips the fortress flyover (restart, or right after the story scene).
var skip_flyover: bool = false
var current: Node
var _root: Node


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var eq: int = s.find("=")
		if eq == -1:
			args[s] = ""
		else:
			args[s.substr(0, eq)] = s.substr(eq + 1)


## Called by scenes/main.tscn when the game starts.
func boot(root: Node) -> void:
	_root = root
	if args.has("run-tests"):
		var t: Node = (load("res://tests/run_tests.gd") as GDScript).new()
		_root.add_child(t)
		return
	if args.has("screenshot"):
		_take_screenshot.call_deferred()
	if args.has("level"):
		goto_level(int(args["level"]))
	elif args.has("story"):
		goto_story(int(args["story"]))
	elif args.has("loadout"):
		goto_loadout(int(args["loadout"]))
	elif args.has("workshop"):
		goto_workshop()
	elif args.has("map"):
		goto_map()
	elif args.has("challenges"):
		goto_challenges()
	elif args.has("meta"):
		goto_meta(String(args["meta"]))
	elif args.has("challenge"):
		goto_level(Data.CHALLENGE_BASE + int(args["challenge"]))
	else:
		goto_menu()


func _switch(node: Node) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current != null and is_instance_valid(current):
		current.queue_free()
		Sound.play("screen_whoosh", 0.6)
	current = node
	_root.add_child(node)


func goto_menu() -> void:
	_switch(MenuScript.new())


func goto_map() -> void:
	_switch(MapScript.new())


## Routes through a cinematic only for authored campaign moments. The level itself opens the
## plan-the-assault screen after its fortress flyover.
func goto_level_entry(id: int) -> void:
	var safe_id: int = clampi(id, 1, Data.level_count())
	var c: Variant = Data.level(safe_id).get("cinematic", [])
	if c is Array and not (c as Array).is_empty():
		goto_story(safe_id)
	else:
		goto_level(safe_id)


## Kept for old call sites: the loadout now lives inside the level.
func goto_loadout(id: int) -> void:
	goto_level(id)


## Authored cinematic, then the level (flyover skipped, plan screen opens).
func goto_story(id: int) -> void:
	var lvl: Node = LevelScript.new()
	lvl.set("level_id", clampi(id, 1, Data.level_count()))
	lvl.set("cinematic_mode", true)
	_switch(lvl)


## Master Orin's upgrade shop. back_to_level > 0 returns to that level.
func goto_workshop(back_to_level: int = 0) -> void:
	var w: Node = WorkshopScript.new()
	w.set("back_to_level", back_to_level)
	_switch(w)


func goto_level(id: int) -> void:
	var lvl: Node = LevelScript.new()
	lvl.set("level_id", id if id > Data.CHALLENGE_BASE else clampi(id, 1, Data.level_count()))
	_switch(lvl)


const META: Dictionary = {
	"spin": "res://src/ui/spin_wheel.gd", "daily": "res://src/ui/daily_rewards.gd", "shop": "res://src/ui/shop_screen.gd",
	"upgrades": "res://src/ui/upgrades_screen.gd", "skins": "res://src/ui/skins_screen.gd",
	"achievements": "res://src/ui/achievements_screen.gd",
}


## Meta screens by key (spin, daily, shop, upgrades, skins, achievements, challenges, events).
## `props` are set on the screen before it enters the tree (e.g. {"kind": "trails"} for Skins).
func goto_meta(key: String, props: Dictionary = {}) -> void:
	if key in ["challenges", "events"]:
		goto_challenges()
		return
	if not META.has(key):
		goto_menu()
		return
	var screen: Node = (load(String(META[key])) as GDScript).new()
	for k: String in props:
		screen.set(k, props[k])
	_switch(screen)


func goto_challenges() -> void:
	_switch(ChallengesScript.new())


## Back from a level's results/pause: challenges return to the Challenges screen.
func goto_back_from(level_id: int) -> void:
	if (Data.balance["secrets"]["levels"] as Dictionary).values().has(float(level_id)) or (Data.balance["secrets"]["levels"] as Dictionary).values().has(level_id):
		goto_map()
		return
	if level_id > Data.CHALLENGE_BASE or not rush.is_empty():
		rush.clear()
		goto_challenges()
	else:
		goto_map()


func start_rush() -> void:
	var r: Dictionary = Data.balance["modes"]["boss_rush"]
	rush = {"levels": (r["levels"] as Array).duplicate(), "index": 0, "pool": (r["heroes"] as Array).duplicate(),
		"soldier_hp": [], "time": 0.0}
	goto_level(int(rush["levels"][0]))


## A rush fight was won: carry heroes/HP/time into the next boss. False when it was the last.
func rush_advance(lv: Node) -> bool:
	var level: Level = lv as Level
	rush["pool"] = level.heroes.slice(level.hero_index)
	var hp: Array = []
	for s: Soldier in level.soldiers:
		hp.append(s.hp)
	rush["soldier_hp"] = hp
	rush["time"] = float(rush["time"]) + level.play_time()
	rush["index"] = int(rush["index"]) + 1
	if int(rush["index"]) >= (rush["levels"] as Array).size():
		rush["index"] = (rush["levels"] as Array).size() - 1
		return false
	var next: int = int(rush["levels"][rush["index"]])
	level.hud.boss_callout("BOSS DOWN! NEXT: %s" % String(Data.level(next).get("name", "")))
	get_tree().create_timer(Data.bf("modes", "rush_next_s"), true, false, true).timeout.connect(func() -> void:
		goto_level(next))
	return true


func rush_total_time() -> float:
	return float(rush.get("time", 0.0))


func rush_stars() -> int:
	var th: Array = Data.balance["modes"]["boss_rush"]["star_time_s"]
	var t: float = rush_total_time()
	var n: int = 1
	for i: int in th.size():
		if t <= float(th[i]):
			n = maxi(n, 3 - i)
	return n


func haptic(ms: int = -1) -> void:
	if not bool(Save.data.get("haptics", true)):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms if ms > 0 else int(Data.b("fx", "haptic_ms")))


func _take_screenshot() -> void:
	var delay: float = float(args.get("shot-delay", "3.0"))
	await get_tree().create_timer(delay, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = String(args["screenshot"])
	if not path.is_absolute_path():
		path = ProjectSettings.globalize_path("res://").path_join(path)
	img.save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()
