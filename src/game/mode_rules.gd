class_name ModeRules
extends Node
## Level rules beyond the default siege, picked by level JSON "mode" (+ "mode_cfg"):
##   heist          break open the treasure chests; a chest that falls into the gap is lost.
##   time_attack    clear the fortress before the clock runs out; heroes keep coming.
##   one_shot       a single hero: bring it all down with one chain reaction.
##   survival       guards arrive in waves (mode_cfg.waves); survive them all.
##   reverse_siege  enemy engines (moving_platform with "approach") cross the gap; sink each one
##                  (defeat its crew) before it docks.
##   boss_rush      Game.rush is active: the five bosses back to back with a shared hero pool.
## Tunables: data/balance.json -> modes. See docs/SIGNATURE_FEATURES.md section 5.

const ICONS: Dictionary = {"heist": "icon_mode_heist", "time_attack": "icon_mode_time", "one_shot": "icon_mode_oneshot",
		"survival": "icon_mode_survival", "reverse_siege": "icon_mode_reverse", "boss_rush": "icon_mode_rush"}
const NAMES: Dictionary = {"siege": "Siege", "heist": "Treasure Heist", "time_attack": "Time Attack", "one_shot": "One Shot",
		"survival": "Survival Siege", "reverse_siege": "Reverse Siege", "boss_rush": "Boss Rush"}

var level: Level
var kind: String = ""
var cfg: Dictionary = {}

# heist
## Untyped: a chest can be freed by physics before the mode sees it.
var chests: Array = []
var chests_total: int = 0
var opened: int = 0
var lost: int = 0
# time attack
var time_left: float = 0.0
var _refill_i: int = 0
# survival
var wave: int = 1
var waves_total: int = 1
var _wave_wait: float = -1.0
# reverse siege
var engines: Array[Dictionary] = []
var sunk: int = 0


static func make(lv: Level) -> ModeRules:
	var k: String = String(lv.data.get("mode", ""))
	if not Game.rush.is_empty() and bool(lv.data.get("boss", false)):
		k = "boss_rush"
	if k.is_empty() or k == "siege":
		return null
	var m: ModeRules = ModeRules.new()
	m.level = lv
	m.kind = k
	m.cfg = lv.data.get("mode_cfg", {})
	return m


static func display_name(k: String) -> String:
	return String(NAMES.get(k, "Siege"))


func setup() -> void:
	match kind:
		"heist":
			for b: Block in level.blocks:
				if b.mat_id == "chest":
					chests.append(b)
			chests_total = chests.size()
		"time_attack":
			time_left = float(cfg.get("time_s", Data.bf("modes", "time_s")))
		"survival":
			waves_total = 1 + (cfg.get("waves", []) as Array).size()
		"reverse_siege":
			for m: CastleMechanism in level.mechanisms:
				if m.kind == "moving_platform" and m.cfg.has("approach"):
					var half: float = float(m.cfg["size"][0]) * 0.5
					var crew: Array[Archer] = []
					for a: Archer in level.archers:
						if absf(a.global_position.x - m.global_position.x) < half + 20.0 and a.global_position.y < m.global_position.y:
							crew.append(a)
					engines.append({"m": m, "crew": crew, "sunk": false})
		"boss_rush":
			var hp: Array = Game.rush.get("soldier_hp", [])
			for i: int in mini(hp.size(), level.soldiers.size()):
				level.soldiers[i].set_hp(int(hp[i]))
	refresh_hud()


## Heroes for this level; empty = keep the level's own queue.
func heroes_override() -> Array:
	if kind == "boss_rush":
		return (Game.rush.get("pool", []) as Array).duplicate()
	return []


func tick(delta: float) -> void:
	match kind:
		"time_attack":
			time_left = maxf(0.0, time_left - delta)
			if level.hero_index >= level.heroes.size() - 1:
				var refill: Array = cfg.get("refill", ["stone", "bomb"])
				level.add_heroes([refill[_refill_i % refill.size()]])
				_refill_i += 1
			refresh_hud()
		"heist":
			for v: Variant in chests.duplicate():
				if not is_instance_valid(v):
					chests.erase(v)
					continue
				var c: Block = v
				if not c.dead and c.global_position.y > level.surface_line():
					chests.erase(c)
					lost += 1
					level.fx.float_text(c.global_position + Vector2(0, -80), "CHEST LOST!", Color("#ff8a7a"), 34)
					Sound.play("splash", 0.9)
					c.destroy(false)
					refresh_hud()
		"survival":
			if _wave_wait >= 0.0:
				_wave_wait -= delta
				if _wave_wait < 0.0:
					_spawn_wave()
		"reverse_siege":
			for e: Dictionary in engines:
				if bool(e["sunk"]):
					continue
				var m: CastleMechanism = e["m"]
				var alive: int = 0
				for a: Archer in e["crew"]:
					if is_instance_valid(a) and not a.dead:
						alive += 1
				if alive == 0:
					e["sunk"] = true
					sunk += 1
					level._stat("engines")
					m.sink()
					level.fx.float_text(m.body.global_position + Vector2(0, -120), "SUNK!", Color("#9af6ff"), 40)
					level.on_mode_bonus(int(Data.b("modes", "engine_score")), m.body.global_position)
					refresh_hud()
				elif m.body.global_position.x - float(m.cfg["size"][0]) * 0.5 <= float(m.cfg["approach"]["dock_x"]):
					level.lose_reason = "A siege engine docked!"
					level.force_finish(false)
					return


## Returns true when the mode ended the level this frame (Level skips its own end check).
func check_end(_delta: float) -> bool:
	match kind:
		"time_attack":
			if time_left <= 0.0 and not level.archers.is_empty():
				level.lose_reason = "Time up!"
				level.force_finish(false)
				return true
		"heist":
			var need: int = int(cfg.get("need", chests_total))
			if chests_total - lost < need:
				level.lose_reason = "The treasure was lost!"
				level.force_finish(false)
				return true
			if chests.is_empty() and opened >= need:
				level.force_finish(true)
				return true
		"survival":
			if level.archers.is_empty() and wave < waves_total and _wave_wait < 0.0:
				_wave_wait = Data.bf("modes", "wave_gap_s")
				level.fx.float_text(Vector2(level.world_right - 500.0, -420.0), "WAVE %d INCOMING!" % (wave + 1), Color("#ffd23a"), 44)
				if level.hud:
					level.hud.boss_callout("WAVE %d / %d" % [wave + 1, waves_total])
	return false


## True while the default "all guards down" win must wait (chests left, waves to come, engines afloat).
func blocks_win() -> bool:
	match kind:
		"heist":
			return not chests.is_empty() or opened < int(cfg.get("need", chests_total))
		"survival":
			return wave < waves_total or _wave_wait >= 0.0
		"reverse_siege":
			return sunk < engines.size()
	return false


func _spawn_wave() -> void:
	var w: Dictionary = (cfg["waves"] as Array)[wave - 1]
	wave += 1
	var drop: float = Data.bf("modes", "wave_drop_px")
	for p: Variant in w.get("archers", []):
		var a: Archer = level.spawn_archer(Vector2(float(p[0]), float(p[1]) - drop))
		a.sleeping = false
		level.fx.puff(a.global_position, 4, Color(1, 1, 1, 0.85), 1.0)
	if w.has("heroes"):
		level.add_heroes(w["heroes"])
	Sound.play("boss_roar", 0.6, 1.4)
	Sound.play("whoosh", 0.8)
	level.camera.add_shake(8.0)
	refresh_hud()


func on_block_destroyed(b: Block) -> void:
	if kind != "heist" or not chests.has(b):
		return
	chests.erase(b)
	if b.global_position.y > level.surface_line():
		lost += 1
		level.fx.float_text(b.global_position + Vector2(0, -80), "CHEST LOST!", Color("#ff8a7a"), 34)
		refresh_hud()
		return
	opened += 1
	level._stat("chests")
	level.fx.float_text(b.global_position + Vector2(0, -60), "TREASURE!", Color("#ffd23a"), 34)
	level.fx.sparks(b.global_position, 16)
	level.fx.debris(b.global_position, "gold", 10, 420.0)
	Sound.play("coin_tink", 1.0)
	Sound.play("chest_open", 0.8)
	level.on_mode_bonus(int(Data.b("modes", "chest_score")), b.global_position)
	refresh_hud()


## Stars from the mode's own goal; -1 = use the score thresholds only.
func stars(score_stars: int) -> int:
	match kind:
		"heist":
			var s: int = 3 if opened >= chests_total else (2 if opened > int(cfg.get("need", chests_total)) else 1)
			return mini(s, score_stars)
		"time_attack":
			var th: Array = cfg.get("star_time", Data.b("modes", "star_time"))
			var n: int = 1
			for i: int in th.size():
				if time_left >= float(th[i]):
					n = maxi(n, i + 1)
			return n
	return score_stars


## Chip text for the HUD objective row.
func chip_text() -> String:
	match kind:
		"heist":
			return "%d / %d" % [opened, chests_total]
		"time_attack":
			return "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
		"one_shot":
			return "ONE SHOT"
		"survival":
			return "WAVE %d/%d" % [wave, waves_total]
		"reverse_siege":
			return "%d / %d" % [sunk, engines.size()]
		"boss_rush":
			return "BOSS %d/%d" % [int(Game.rush.get("index", 0)) + 1, (Game.rush.get("levels", []) as Array).size()]
	return ""


func refresh_hud() -> void:
	if level.hud:
		level.hud.set_mode(String(ICONS.get(kind, "icon_mode_heist")), display_name(kind), chip_text(),
				kind == "time_attack" and time_left < Data.bf("modes", "time_warn_s"))


func result_rows() -> Array:
	match kind:
		"heist":
			return [["Chests opened", "%d / %d" % [opened, chests_total]]]
		"time_attack":
			return [["Time left", "%.1f s" % time_left]]
		"survival":
			return [["Waves survived", "%d / %d" % [wave, waves_total]]]
		"reverse_siege":
			return [["Engines sunk", "%d / %d" % [sunk, engines.size()]]]
		"boss_rush":
			return [["Rush time", "%.1f s" % (float(Game.rush.get("time", 0.0)) + level.play_time())]]
	return []
