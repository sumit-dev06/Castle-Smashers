extends Node
## Scene switching, command-line flags and small global helpers.
## User args come after "--":  --level=N  --screenshot=path.png  --shot-delay=3
##                             --autoshot=angle_deg,power[,ability_delay_s]  --run-tests
##                             --force-win=seconds (debug: win the level for results screenshots)
##                             --map  --story=N  --intro (play the studio intro)  --no-intro

const LevelScript: GDScript = preload("res://src/game/level.gd")
const MenuScript: GDScript = preload("res://src/ui/main_menu.gd")
const MapScript: GDScript = preload("res://src/ui/world_map.gd")
const WorkshopScript: GDScript = preload("res://src/ui/upgrades_screen.gd")
const ChallengesScript: GDScript = preload("res://src/ui/challenges_screen.gd")
const IntroScript: GDScript = preload("res://src/ui/intro_screen.gd")
const CampaignEndScript: GDScript = preload("res://src/ui/campaign_end.gd")

var args: Dictionary = {}
## Boss rush run: {levels, index, pool, soldier_hp, time}. Empty = no rush.
var rush: Dictionary = {}
## Next goto_level() skips the fortress flyover (restart, or right after the story scene).
var skip_flyover: bool = false
## The feature showcase has opened in this app session (the first home visit without another
## popup gets it; later visits only now and then).
var promo_seen: bool = false
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
	elif args.has("energy-popup") and OS.is_debug_build():
		# Preview: home screen with 1 bar left and the exhausted popup for level N (not saved).
		goto_menu()
		Energy.bars()
		Save.data["energy"]["bars"] = 1
		EnergyUI.exhausted.call_deferred(int(args["energy-popup"]), Callable())
	elif args.has("rename-popup") and OS.is_debug_build():
		goto_menu()
		current.call_deferred("_open_rename")
	elif args.has("training"):
		goto_training(String(args["training"]), int(Data.training(String(args["training"])).get("before_level", 1)))
	elif args.has("loadout"):
		goto_loadout(int(args["loadout"]))
	elif args.has("workshop"):
		goto_workshop()
	elif args.has("map"):
		goto_map()
	elif args.has("promo") and OS.is_debug_build():
		goto_menu()
		PromoPopup.open.call_deferred()
	elif args.has("campaign-end"):
		goto_campaign_end()
	elif args.has("challenges"):
		goto_challenges()
	elif args.has("meta"):
		goto_meta(String(args["meta"]), {"tab": String(args["tab"])} if args.has("tab") else {})
	elif args.has("challenge"):
		goto_level(Data.CHALLENGE_BASE + int(args["challenge"]))
	elif args.has("intro") or (IntroScript.due() and not args.has("no-intro")):
		goto_intro()
	else:
		goto_menu()


## Studio intro: on first launch after install and after each update, then the home screen.
func goto_intro() -> void:
	var intro: Node = IntroScript.new()
	# A fresh install watches it once; debug replays (--intro) may skip it with a tap.
	intro.set("skippable", args.has("intro"))
	intro.connect("finished", goto_menu, CONNECT_ONE_SHOT)
	_switch(intro)


func _switch(node: Node) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current != null and is_instance_valid(current):
		current.queue_free()
		Sound.play("screen_whoosh", 0.6)
	# Coins and confetti still flying from the last screen (results) must not land on the next one.
	var fx: Node = get_tree().root.get_node_or_null("UIFxLayer")
	if fx:
		for c: Node in fx.get_children():
			c.queue_free()
	for popup: Node in get_tree().get_nodes_in_group("ui_popup"):
		popup.queue_free()
	current = node
	_root.add_child(node)


func goto_menu() -> void:
	_switch(MenuScript.new())


func goto_map() -> void:
	_switch(MapScript.new())


## After the last campaign level: the "new realms coming soon" screen.
func goto_campaign_end() -> void:
	_switch(CampaignEndScript.new())


## True once the last campaign level has been won.
func campaign_done() -> bool:
	return Save.stars(Data.level_count()) > 0


## Routes through a cinematic only for authored campaign moments. The level itself opens the
## plan-the-assault screen after its fortress flyover.
func goto_level_entry(id: int) -> void:
	var safe_id: int = clampi(id, 1, Data.level_count())
	# A new hero first gets a short practice range that shows how to use the ability.
	var hero: String = Data.training_for(safe_id)
	if not hero.is_empty() and not Save.seen("training:" + hero):
		goto_training(hero, safe_id)
		return
	EnergyUI.enter(safe_id, _enter_level.bind(safe_id))


func _enter_level(safe_id: int) -> void:
	var c: Variant = Data.level(safe_id).get("cinematic", [])
	# Story scenes play once, and only on levels that bring something new (a hero, mechanism,
	# material, gadget, captive, engineer or boss: Data.novelty). Other levels start at the plan
	# screen; the flyover still points out unseen callouts.
	if c is Array and not (c as Array).is_empty() and not Save.seen("story:%d" % safe_id) \
			and not Data.novelty(safe_id).is_empty():
		goto_story(safe_id)
	else:
		goto_level(safe_id)


## Practice range for `hero`, then level `before_id` (its story scene, if any, plays after).
## from_workshop: opened from Master Orin's hero cards; it returns to the Workshop afterwards.
func goto_training(hero: String, before_id: int, from_workshop: bool = false) -> void:
	Analytics.set_crash_key("phase", "loading")
	skip_flyover = true
	var lvl: Node = LevelScript.new()
	lvl.set("level_id", maxi(1, before_id))
	lvl.set("training", hero)
	lvl.set("training_from_workshop", from_workshop)
	_switch(lvl)


## Kept for old call sites: the loadout now lives inside the level.
func goto_loadout(id: int) -> void:
	goto_level(id)


## Authored cinematic, then the level (flyover skipped, plan screen opens).
func goto_story(id: int) -> void:
	Analytics.set_crash_key("phase", "loading")
	var lvl: Node = LevelScript.new()
	lvl.set("level_id", clampi(id, 1, Data.level_count()))
	lvl.set("cinematic_mode", true)
	_switch(lvl)


## Master Orin's upgrade shop. back_to_level > 0 returns to that level.
func goto_workshop(back_to_level: int = 0) -> void:
	var w: Node = WorkshopScript.new()
	w.set("back_to_level", back_to_level)
	_switch(w)


func can_enter_level(id: int) -> bool:
	if Data.is_special(id):
		return Save.special_pack_unlocked()
	return Save.mission_unlocked(id)


func goto_level(id: int) -> void:
	if not can_enter_level(id) and not (OS.is_debug_build() and args.has("preview-special")):
		goto_challenges()
		return
	Analytics.set_crash_key("phase", "loading")
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
	if key == "settings":
		goto_menu()
		SettingsPopup.open.call_deferred(current)
		return
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
