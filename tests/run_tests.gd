extends Node
## Headless tests. Run:  $GODOT --headless --path . -- --run-tests
## 1. Data integrity  2. Every level stands still for 10 s with all bodies awake
## 3. A stone shot damages level 1  4. Bomb + fire + cyclone abilities change the world  5. Stars

const STAND_S: float = 10.0
const MAX_MOVE_PX: float = 6.0
const MAX_ROT_DEG: float = 2.0
const MOVING_PLATFORM_EXTRA_PX: float = 50.0
const MOVING_PLATFORM_MAX_ROT_DEG: float = 5.0
## Bolted cantilevers sag a few px under a guard before the pins settle.
const BOLT_SAG_PX: float = 10.0

var _failures: int = 0


func _ready() -> void:
	Engine.time_scale = 3.0
	Engine.max_physics_steps_per_frame = 12
	await _run()
	print("\n==== TESTS %s (%d failure%s) ====" % ["PASSED" if _failures == 0 else "FAILED", _failures, "" if _failures == 1 else "s"])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + msg)
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _make(id: int) -> Level:
	var l: Level = Level.new()
	l.level_id = id
	l.test_mode = true
	add_child(l)
	return l


func _run() -> void:
	if str(Game.args.get("run-tests", "")) == "contraptions":  # --run-tests=contraptions: quick set-piece check
		await _contraption_tests()
		return
	print("-- data")
	for id: int in range(1, Data.level_count() + 1):
		var d: Dictionary = Data.level(id)
		_check(not d.is_empty(), "level %d loads" % id)
		for b: Dictionary in d.get("blocks", []):
			if not Data.shapes.has(b["type"]):
				_check(false, "level %d unknown block type %s" % [id, b["type"]])
		for h: Variant in d.get("heroes", []):
			if not Data.projectiles.has(h):
				_check(false, "level %d unknown hero %s" % [id, h])
		_check(d.get("star_scores", []).size() == 3, "level %d has 3 star thresholds" % id)
		var recommended: Array[String] = LoadoutRules.recommended(d, id)
		_check(LoadoutRules.valid(recommended, id, d), "level %d recommended four-shot loadout is legal" % id)
		for mechanism_data: Dictionary in d.get("mechanisms", []):
			_check(String(mechanism_data.get("type", "")) in ["gate", "drawbridge", "moving_platform", "swing", "spikes", "lava",
					"rope_load", "hanging_platform", "crusher", "geyser", "lever", "windmill", "shield_ring", "rune_switch", "trapdoor"], "level %d has a known mechanism type" % id)
		for bolt_data: Dictionary in d.get("bolts", []):
			_check(int(bolt_data["a"]) < d["blocks"].size() and int(bolt_data["b"]) < d["blocks"].size(), "level %d bolt indices are valid" % id)
		for td: Dictionary in d.get("tethers", []):
			_check(String(td.get("kind", "")) in ["pin", "rope", "spring"], "level %d has a known tether kind" % id)
			_check(int(td["a"]) >= 0 and int(td["a"]) < d["blocks"].size() and int(td.get("b", -1)) < d["blocks"].size(),
					"level %d tether indices are valid" % id)
		for rd: Dictionary in d.get("ramps", []):
			_check(Data.balance["ramps"].has(String(rd.get("kind", ""))) and (rd.get("points", []) as Array).size() >= 3,
					"level %d ramp has a known kind and a polygon" % id)
		var beats: Variant = d.get("cinematic", [])
		_check(beats is Array, "level %d cinematic is a beat list" % id)
		for beat: Dictionary in (beats as Array):
			_check(String(beat.get("t", "")) in ["title", "pan", "enter", "say", "emote", "focus", "demo", "hero", "boss", "exit", "wait", "march"],
					"level %d cinematic beat type %s" % [id, beat.get("t", "")])
		_check(bool(d.get("boss", false)) == d.has("boss_unit"), "level %d boss flag matches boss unit" % id)

	print("-- stability (%.0f s, all bodies awake)" % STAND_S)
	for id: int in range(1, Data.level_count() + 1):
		var l: Level = _make(id)
		await _wait(0.05)
		for b: Block in l.blocks:
			b.sleeping = false
		for a: Archer in l.archers:
			a.sleeping = false
		await _wait(STAND_S)
		var worst_move: float = 0.0
		var worst_rot: float = 0.0
		for b: Block in l.blocks:
			if b.held:
				continue
			worst_move = maxf(worst_move, b.global_position.distance_to(b.start_pos))
			worst_rot = maxf(worst_rot, absf(rad_to_deg(angle_difference(b.rotation, b.start_rot))))
		var archer_move: float = 0.0
		for a: Archer in l.archers:
			archer_move = maxf(archer_move, a.global_position.distance_to(a.start_pos))
		var total: int = Data.level(id).get("blocks", []).size()
		var expected_archers: int = Data.level(id).get("archers", []).size() + (1 if Data.level(id).has("boss_unit") else 0) \
				+ Data.level(id).get("engineers", []).size()
		for md2: Dictionary in Data.level(id).get("mechanisms", []):
			if String(md2["type"]) == "rope_load":
				total += 1
		var tide_amp: float = float(Data.level(id).get("tide", {}).get("amp_px", 0.0))
		var platform_travel: float = 0.0
		for mechanism: CastleMechanism in l.mechanisms:
			if mechanism.kind == "moving_platform":
				var travel: Vector2 = Vector2(float(mechanism.cfg.get("travel_x", 0.0)), float(mechanism.cfg.get("travel_y", 0.0)))
				platform_travel = maxf(platform_travel, travel.length())
				_check(absf(mechanism.body.position.x) <= absf(travel.x) + 1.0 and absf(mechanism.body.position.y) <= absf(travel.y) + tide_amp + 1.0,
						"level %d: moving platform stays inside authored travel" % id)
		platform_travel += tide_amp
		var move_limit: float = MAX_MOVE_PX + (platform_travel + MOVING_PLATFORM_EXTRA_PX if platform_travel > 0.0 else 0.0)
		if not Data.level(id).get("bolts", []).is_empty():
			move_limit += BOLT_SAG_PX
		var rot_limit: float = MOVING_PLATFORM_MAX_ROT_DEG if platform_travel > 0.0 else MAX_ROT_DEG
		_check(l.blocks.size() == total, "level %d: no block broke on its own (%d/%d)" % [id, l.blocks.size(), total])
		_check(l.archers.size() == expected_archers, "level %d: no archer died on its own" % id)
		_check(worst_move < move_limit and worst_rot < rot_limit,
				"level %d: blocks drift %.2f/%.0f px / %.2f/%.0f deg" % [id, worst_move, move_limit, worst_rot, rot_limit])
		_check(archer_move < move_limit, "level %d: archers drift %.2f/%.0f px" % [id, archer_move, move_limit])
		l.queue_free()
		await _wait(0.1)

	print("-- shots")
	# Each hero is tested on the first level that recommends it, aimed at that level's first base.
	await _shot_test(1, "stone", -200.0, -1.0, INF, "stone hit on level 1")
	await _shot_test(11, "stone", -240.0, -1.0, INF, "stone on stone tower, level 11")
	var lf: int = _first_level_with("fire")
	await _shot_test(lf, "fire", -150.0, 0.0, INF, "fire burst on level %d" % lf)
	var lb: int = _first_level_with("bomb")
	await _shot_test(lb, "bomb", -150.0, 0.0, INF, "bomb (explodes after impact) on level %d" % lb)
	var lc: int = _first_level_with("cyclone")
	await _shot_test(lc, "cyclone", -200.0, 0.0, -250.0, "cyclone ability on level %d" % lc)
	var lq: int = _first_level_with("quake")
	await _shot_test(lq, "quake", -40.0, 0.0, -40.0, "quake ability on level %d foundations (slam over the base)" % lq)

	print("-- mechanisms and rescue")
	var rescue_id: int = 0
	var rescue_trigger: String = ""
	for id: int in range(1, Data.level_count() + 1):
		var dd: Dictionary = Data.level(id)
		for c: Dictionary in dd.get("captives", []):
			for m: Dictionary in dd.get("mechanisms", []):
				if rescue_id == 0 and String(m.get("trigger", "")) == String(c["trigger"]):
					rescue_id = id
					rescue_trigger = String(c["trigger"])
	_check(rescue_id > 0, "a level links a mechanism and a captive to one trigger (level %d)" % rescue_id)
	var lm: Level = _make(rescue_id)
	await _wait(0.05)
	var mechanism_score_before: int = lm.score
	lm.activate_trigger(rescue_trigger)
	await _wait(0.05)
	var bridge_active: bool = false
	for mm: CastleMechanism in lm.mechanisms:
		if mm.kind == "drawbridge":
			bridge_active = mm.active
	_check(bridge_active, "weak-point trigger activates the drawbridge")
	_check(not lm.captives.is_empty() and lm.captives[0].rescued and lm.captives_rescued == 1,
			"weak-point trigger releases and counts the captive")
	_check(lm.score > mechanism_score_before, "mechanism and rescue award score")
	lm.queue_free()
	await _wait(0.1)

	print("-- stage and gap")
	var lg: Level = _make(1)
	await _wait(0.05)
	var st: Stage = lg.stage
	_check(st != null and not st.bases.is_empty(), "level 1 has a stage with a fortress base")
	var gap_x: float = (st.ledge_right + st.bases[0].position.x) * 0.5
	_check(not st.ground_at(gap_x) and st.ground_at(0.0) and st.ground_at(st.bases[0].get_center().x),
			"ground_at: ledge and base are solid, the gap is open")
	var fall: Block = lg.blocks[0]
	var n_before: int = lg.blocks.size()
	var gap_score: int = lg.score
	fall.global_position = Vector2(gap_x, -80.0)
	fall.linear_velocity = Vector2.ZERO
	fall.sleeping = false
	await _wait(1.6)
	_check(lg.blocks.size() == n_before - 1 and lg.score > gap_score,
			"a block knocked into the gap is removed and scored (%d -> %d blocks)" % [n_before, lg.blocks.size()])
	var a: Archer = lg.archers[0]
	var archers_before: int = lg.archers.size()
	a.global_position = Vector2(gap_x, -80.0)
	await _wait(1.6)
	_check(lg.archers.size() == archers_before - 1, "an archer that falls into the gap is defeated")
	lg.queue_free()
	await _wait(0.1)

	await _phase_c_tests()
	await _phase_d_tests()
	await _contraption_tests()

	print("-- real time")
	var lr: Level = _make(1)
	await _wait(0.05)
	var reload: float = Data.bf("catapult", "reload_s") + Data.bf("catapult", "hop_s") + 0.25
	var aim: Vector2 = _aim(lr.catapult.launch_point("stone"), Vector2(1450, -200), Data.bf("catapult", "max_speed") * 0.8)
	lr.fire_hero(aim)
	await _wait(reload)
	var first_flying: bool = lr.projectiles.size() > 0
	_check(lr.is_loaded() and first_flying, "catapult reloads in %.2f s while the first hero is still flying" % reload)
	lr.fire_hero(aim)
	_check(lr.projectiles.size() == 2, "second hero fired without waiting (%d in the air)" % lr.projectiles.size())
	lr.queue_free()
	await _wait(0.1)
	var la: Level = _make(2)
	la.archers_in_test = true
	await _wait(Data.bf("archers", "first_max_s") + Data.bf("archers", "fire_max_s") + 0.5)
	_check(la.arrows_fired >= la.archers.size(), "archers shoot on their own timers (%d arrows from %d archers)" % [la.arrows_fired, la.archers.size()])
	var hurt: int = 0
	for s: Soldier in la.soldiers:
		hurt += int(Data.b("soldiers", "hp")) - s.hp
	_check(hurt > 0, "arrows hit soldiers (%d damage)" % hurt)
	la.queue_free()
	await _wait(0.1)

	print("-- stars")
	var l2: Level = _make(1)
	await _wait(0.05)
	l2.archers.clear()
	var th: Array = l2.data["star_scores"]
	l2.score = int(th[2])
	l2.hero_index = 1
	l2._finish(true)
	_check(l2.state == Level.State.WON and l2.stars == 3, "win above the 3-star score = 3 stars (score %d, stars %d)" % [l2.score, l2.stars])
	l2.queue_free()
	await _wait(0.1)


func _block_of(l: Level, shape: String) -> Block:
	for b: Block in l.blocks:
		if is_instance_valid(b) and b.shape_id == shape:
			return b
	return null


func _tether_of(l: Level, pred: Callable) -> Tether:
	for t: Tether in l.tethers:
		if pred.call(t):
			return t
	return null


## Each set-piece does its trick when triggered the way the level hint says.
func _contraption_tests() -> void:
	print("-- contraptions")
	# Seesaw: knock out one support stone and the plank tips.
	var l: Level = _make(7)
	await _wait(0.1)
	var plank: Block = _block_of(l, "plank_xl")
	var support: Block = null
	for b: Block in l.blocks:
		if b.shape_id == "stone_block" and b.global_position.x > plank.global_position.x + 60.0 and absf(b.global_position.x - plank.global_position.x) < 200.0:
			support = b
	_check(plank != null and support != null, "level 7 has a seesaw plank and support")
	if plank and support:
		support.destroy(false)
		await _wait(2.0)
		_check(absf(rad_to_deg(plank.rotation)) > 8.0, "seesaw tips when a support is removed (%.1f deg)" % rad_to_deg(plank.rotation))
	l.queue_free()
	await _wait(0.1)

	# Dominoes: tip the first slab and the last one falls too.
	l = _make(14)
	await _wait(0.1)
	var dom: Array[Block] = []
	for b: Block in l.blocks:
		if b.shape_id == "domino":
			dom.append(b)
	dom.sort_custom(func(p: Block, q: Block) -> bool: return p.global_position.x < q.global_position.x)
	_check(dom.size() >= 4, "level 14 has a domino row (%d)" % dom.size())
	if dom.size() >= 4:
		dom[0].sleeping = false
		dom[0].apply_impulse(Vector2(dom[0].mass * 160.0, 0.0), Vector2(0.0, -dom[0].size.y * 0.4))
		await _wait(4.0)
		var last: Block = dom[dom.size() - 1]
		# The last slab tips past its balance point (10 deg) and falls against the keep wall.
		_check(not is_instance_valid(last) or last.dead or absf(rad_to_deg(last.rotation)) > 11.0,
				"domino chain reaches the last slab (%.0f deg)" % (rad_to_deg(last.rotation) if is_instance_valid(last) else 90.0))
	l.queue_free()
	await _wait(0.1)

	# Rollers: a nudge sends the boulder, wheel and carts down their slopes.
	for case: Array in [[11, "log"], [15, "boulder"], [35, "wheel"], [32, "cart"], [49, "cart"]]:
		l = _make(int(case[0]))
		await _wait(0.1)
		var r: Block = null  # the front-most one (nearest the fort)
		for rb: Block in l.blocks:
			if rb.shape_id == String(case[1]) and (r == null or rb.global_position.x > r.global_position.x):
				r = rb
		_check(r != null, "level %d has a %s" % [case[0], case[1]])
		if r:
			var x0: float = r.global_position.x
			r.push(Vector2(r.mass * 260.0, 0.0))
			await _wait(3.0)
			var moved: float = (r.global_position.x if is_instance_valid(r) and not r.dead else INF) - x0
			_check(moved > 250.0, "level %d: the %s rolls down the slope (%.0f px)" % [case[0], case[1], moved])
		l.queue_free()
		await _wait(0.1)

	# Ropes: cutting a cage rope drops the cage.
	l = _make(37)
	await _wait(0.1)
	var rope: Tether = _tether_of(l, func(t: Tether) -> bool: return t.kind == "rope")
	_check(rope != null, "level 37 has a rope tether")
	if rope:
		var cage: Block = rope.a
		var y0: float = cage.global_position.y
		var score0: int = l.score
		l.cut_ropes_near(rope.hook_point().lerp(rope.attach_point(), 0.5), 8.0)
		_check(rope.cut and l.score > score0, "cutting a rope snaps the tether and scores")
		await _wait(1.0)
		_check(not is_instance_valid(cage) or cage.dead or cage.global_position.y > y0 + 60.0, "the cut cage falls")
	l.queue_free()
	await _wait(0.1)

	# Pendulum: cut the latch and the ball swings into the keep.
	l = _make(39)
	await _wait(0.1)
	var ball: Block = _block_of(l, "iron_ball")
	var latch: Tether = _tether_of(l, func(t: Tether) -> bool: return t.kind == "rope" and t.a == ball and not t.rope_segment().is_empty() and t.hook_point().x < ball.global_position.x)
	_check(ball != null and latch != null, "level 39 has a latched wrecking ball")
	if ball and latch:
		var bx: float = ball.global_position.x
		latch.release(true)
		await _wait(1.5)
		_check(not is_instance_valid(ball) or ball.global_position.x > bx + 250.0, "wrecking ball swings when the latch is cut")
	l.queue_free()
	await _wait(0.1)

	# Spring trap: cut the latch and the platform springs up.
	l = _make(43)
	await _wait(0.1)
	var lock: Tether = _tether_of(l, func(t: Tether) -> bool: return bool(t.cfg.get("lock", false)))
	_check(lock != null and lock.a.freeze, "level 43 spring platform is locked by its latch")
	if lock:
		var pl: Block = lock.a
		var py: float = pl.global_position.y
		var px: float = pl.global_position.x
		lock.release(true)
		var peak: float = py
		for k: int in 8:
			await _wait(0.06)
			if is_instance_valid(pl):
				peak = minf(peak, pl.global_position.y)
		_check(py - peak > 60.0 and (not is_instance_valid(pl) or pl.global_position.x > px + 100.0),
				"spring launches the platform when the latch is cut (rose %.0f px)" % (py - peak))
	l.queue_free()
	await _wait(0.1)

	# Boulder trap: cut the latch and the boulder rolls off the hill.
	l = _make(17)
	await _wait(0.1)
	var trap: Tether = _tether_of(l, func(t: Tether) -> bool: return bool(t.cfg.get("lock", false)))
	_check(trap != null and trap.a.freeze, "level 17 boulder is tied on the slope")
	if trap:
		var boulder: Block = trap.a
		var bx1: float = boulder.global_position.x
		l.cut_ropes_near(trap.hook_point().lerp(trap.attach_point(), 0.5), 8.0)
		await _wait(3.0)
		_check(trap.cut and (not is_instance_valid(boulder) or boulder.global_position.x > bx1 + 250.0), "cut boulder rolls down the hill")
	l.queue_free()
	await _wait(0.1)

	# Bell: a hard push swings it, the rope holds.
	l = _make(23)
	await _wait(0.1)
	var bell: Block = _block_of(l, "bell")
	_check(bell != null, "level 23 has a bell")
	if bell:
		var bx0: float = bell.global_position.x
		bell.push(Vector2(bell.mass * 300.0, 0.0))
		await _wait(0.4)
		_check(is_instance_valid(bell) and absf(bell.global_position.x - bx0) > 20.0, "the bell swings when hit")
	l.queue_free()
	await _wait(0.1)


## Low-arc launch velocity from `from` that passes through `to` at speed v (null if unreachable).
func _aim(from: Vector2, to: Vector2, v: float) -> Vector2:
	var g: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	var x: float = to.x - from.x
	var y: float = from.y - to.y
	var disc: float = v ** 4 - g * (g * x * x + 2.0 * y * v * v)
	if disc < 0.0:
		return Vector2.ZERO
	var a: float = atan((v * v - sqrt(disc)) / (g * x))
	return Vector2(cos(a), -sin(a)) * v


func _first_level_with(kind: String) -> int:
	for id: int in range(1, Data.level_count() + 1):
		if Data.level(id).get("heroes", []).has(kind):
			return id
	return 1


## Fires one `kind` hero at (first base centre, target_y above its top). The ability is used after
## ability_at seconds, or (if ability_dx is finite) once the hero passes target.x + ability_dx.
func _shot_test(id: int, kind: String, target_y: float, ability_at: float, ability_dx: float, label: String) -> void:
	var l: Level = _make(id)
	await _wait(0.05)
	var base0: Rect2 = l.stage.bases[0]
	var target: Vector2 = Vector2(base0.get_center().x, base0.position.y + target_y)
	l.heroes = [kind]
	l.hero_index = 0
	l._load_now()
	await _wait(Data.bf("physics", "damage_grace_s") + 0.1)
	var hp_before: float = 0.0
	for b: Block in l.blocks:
		hp_before += b.hp
	var blocks_before: int = l.blocks.size()
	var archers_before: int = l.archers.size()
	var v: Vector2 = _aim(l.catapult.launch_point(String(l.heroes[0])), target, Data.bf("catapult", "max_speed") * 0.8)
	_check(v != Vector2.ZERO, "%s: target reachable" % label)
	l.fire_hero(v)
	if is_finite(ability_dx):
		var waited: float = 0.0
		while waited < 3.0 and is_instance_valid(l.projectile) and l.projectile.global_position.x < target.x + ability_dx:
			await _wait(0.02)
			waited += 0.02
		if is_instance_valid(l.projectile):
			l.projectile.use_ability()
	elif ability_at > 0.0:
		await _wait(ability_at)
		if is_instance_valid(l.projectile):
			l.projectile.use_ability()
	await _wait(4.5)
	var hp_after: float = 0.0
	for b: Block in l.blocks:
		hp_after += b.hp
	var lost: float = hp_before - hp_after
	var broken: int = blocks_before - l.blocks.size()
	var killed: int = archers_before - l.archers.size()
	_check(lost > 1.0 or broken > 0 or killed > 0,
			"%s: %d blocks broken, %d archers down, %.0f hp of damage" % [label, broken, killed, lost])
	l.queue_free()
	await _wait(0.1)


func _mech(l: Level, kind: String) -> CastleMechanism:
	for m: CastleMechanism in l.mechanisms:
		if m.kind == kind:
			return m
	return null


func _level_with(pred: Callable) -> int:
	for id: int in range(1, Data.level_count() + 1):
		if pred.call(Data.level(id)):
			return id
	return 0


func _has_mech(kind: String) -> Callable:
	return func(d: Dictionary) -> bool:
		for m: Dictionary in d.get("mechanisms", []):
			if String(m["type"]) == kind:
				return true
		return false


func _phase_d_tests() -> void:
	print("-- phase D: chain reactions, replay")
	var c: Chain = Chain.new()
	for i: int in 5:
		c.link(0.1 * i, Vector2(100 * i, 0), 100)
	var want: float = 1.0 + 4.0 * Data.bf("chain", "step")
	_check(is_equal_approx(c.multiplier(), want), "5 links give x%.2f (%.2f)" % [want, c.multiplier()])
	_check(c.tick(0.45) == -1, "a chain stays open inside the window")
	var bonus: int = c.tick(0.4 + Data.bf("chain", "window_s") + 0.01)
	_check(bonus == int(round(500.0 * (want - 1.0))) and c.best == 5 and c.count == 0, "a chain pays its points again at (mult - 1) when it ends (%d)" % bonus)
	c.link(10.0, Vector2.ZERO, 100)
	c.tick(10.0 + Data.bf("chain", "window_s") + 0.05)
	c.link(10.0 + Data.bf("chain", "window_s") + 0.1, Vector2.ZERO, 100)
	_check(c.count == 1, "a link after the window starts a new chain")
	_check(c.finish() == 0, "chains shorter than min_links pay nothing")
	# A blast in a real fortress makes a chain and the level pays the bonus.
	var lb: Level = _make(_level_with(func(d: Dictionary) -> bool:
		for b: Dictionary in d.get("blocks", []):
			if String(b["type"]) == "barrel":
				return true
		return false))
	await _wait(1.2)
	var mid: Vector2 = Vector2.ZERO
	for b: Block in lb.blocks:
		mid += b.global_position
	mid /= float(maxi(1, lb.blocks.size()))
	var before: int = lb.score
	lb.explode(mid, 420.0, 2600.0, 400.0)
	await _wait(Data.bf("chain", "window_s") + 1.5)
	_check(lb.chain.best >= int(Data.b("chain", "min_links")) and lb.chain_bonus > 0,
			"a big blast is a chain of %d with a %d bonus (level %d)" % [lb.chain.best, lb.chain_bonus, lb.level_id])
	_check(lb.score >= before + lb.chain_bonus, "the chain bonus is added to the score")
	# Replay: the recorder has footage and can play the best chain back.
	_check(lb.replay.frame > 20, "the replay recorder has frames (%d)" % lb.replay.frame)
	var live: int = 0
	for b: Block in lb.blocks:
		if b.visible:
			live += 1
	_check(lb.play_best_replay() and lb.replay.playing, "the best chain replay starts")
	var hidden_ok: bool = true
	for b: Block in lb.blocks:
		hidden_ok = hidden_ok and not b.visible
	_check(hidden_ok, "live blocks are hidden during the replay")
	await _wait(0.5)
	lb.replay.stop()
	var shown: int = 0
	for b: Block in lb.blocks:
		if b.visible:
			shown += 1
	_check(not lb.replay.playing and shown == live, "stopping the replay shows the world again (%d/%d)" % [shown, live])
	lb.queue_free()
	await _wait(0.1)
	await _material_tests()
	_wallet_tests()
	await _mechanism_d_tests()
	await _boss_rig_tests()
	await _mode_tests()
	await _progression_tests()
	await _meta_tests()
	await _audio_tests()


## Spawns a block resting on the ground at x (ledge side, away from the fortress).
func _put(l: Level, shape: String, x: float, decor: Dictionary = {}, stack_y: float = 0.0) -> Block:
	var h: float = float(Data.shapes[shape]["size"][1])
	return l.spawn_block(shape, Vector2(x, l.stage.top_at(x) - h * 0.5 - stack_y), decor)


## Wallet: three currencies, spend is all-or-nothing, premium rewards only on first clears.
func _wallet_tests() -> void:
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data["coins"] = 500
	Save.data["gems"] = 5
	Save.data["blueprints"] = 0
	Save.data["stars"] = {}
	_check(not Save.spend({"coins": 100, "blueprints": 1}) and Save.coins() == 500,
			"wallet: spend fails whole when one currency is short")
	_check(Save.spend({"coins": 100, "gems": 5}) and Save.coins() == 400 and Save.amount("gems") == 0,
			"wallet: spend takes every currency in the cost")
	var c: Dictionary = Data.balance["currencies"]
	var r3: Dictionary = Save.rewards_for(7, 3, false)
	_check(int(r3.get("gems", 0)) == int(c["gems_three_star_first"]), "wallet: first 3-star clear gives gems")
	var rb: Dictionary = Save.rewards_for(10, 1, true)
	_check(int(rb.get("gems", 0)) == int(c["gems_boss_first_clear"]) and int(rb.get("blueprints", 0)) == int(c["blueprints_boss_first_clear"]),
			"wallet: first boss clear gives gems and blueprints")
	Save.data["stars"] = {"7": 3, "10": 1}
	var again: Dictionary = Save.rewards_for(7, 3, false)
	var boss_again: Dictionary = Save.rewards_for(10, 1, true)
	_check(not again.has("gems") and not boss_again.has("gems") and not boss_again.has("blueprints") and int(again["coins"]) > 0,
			"wallet: replays give coins only (no premium farming)")
	Save.data = saved
	Save.write()


## Phase D mechanisms: lever, windmill, shield ring, hidden switch, trap door.
func _mechanism_d_tests() -> void:
	print("-- phase D: mechanisms")
	var l: Level = _make(1)
	await _wait(1.0)
	var g: float = l.stage.top_at(300.0)
	# Lever: a blast flips it and opens the gate it is wired to.
	var gate: CastleMechanism = l.spawn_mechanism({"type": "gate", "x": 420, "y": g - 90, "size": [40, 180], "trigger": "lv",
			"travel_y": -170, "duration_s": 0.3})
	var lever: CastleMechanism = l.spawn_mechanism({"type": "lever", "x": 200, "y": g, "triggers": ["lv"]})
	var s0: int = l.score
	l.explode(lever.hit_point() + Vector2(-30, 0), 50.0, 100.0, 10.0)
	await _wait(0.2)
	_check(lever.active and gate.active and l.score > s0, "a blast flips the lever and opens its gate")
	# Windmill: turns, a hub hit jams it.
	var mill: CastleMechanism = l.spawn_mechanism({"type": "windmill", "x": 300, "y": g - 420, "arms": 4, "arm_len": 200, "dps": 60})
	await _wait(1.3)
	var a0: float = mill.body.rotation
	await _wait(0.4)
	_check(absf(mill.body.rotation - a0) > deg_to_rad(10.0), "the windmill turns")
	l.explode(mill.hit_point(), 30.0, 100.0, 10.0)
	await _wait(Data.bf("rotor", "jam_s") * 3.0)
	var a1: float = mill.body.rotation
	await _wait(0.4)
	_check(mill.jammed and absf(mill.body.rotation - a1) < deg_to_rad(1.0), "a hub hit jams the windmill")
	# Shield ring: on its own layer, which shots hit and blocks ignore.
	var ring: CastleMechanism = l.spawn_mechanism({"type": "shield_ring", "x": 300, "y": g - 300, "radius": 120, "plates": 3, "dps": 50})
	var shield_bit: int = int(Data.b("layers", "shield"))
	var probe_b: Block = _put(l, "crate", 520.0)
	_check(ring.body.collision_layer == shield_bit and (probe_b.collision_mask & shield_bit) == 0,
			"shield plates only block shots, not fortress blocks")
	var stone: Projectile = Projectile.new()
	stone.setup("stone", l)
	_check((stone.collision_mask & shield_bit) != 0, "shots collide with shield plates")
	stone.free()
	l.activate_trigger("none")
	ring.activate()
	_check(ring.jammed, "a trigger stops the shield ring")
	l.queue_free()
	await _wait(0.1)
	# Hidden switch: covered by a block it stays dark; once the cover breaks it glows and a hit
	# springs the trap door so the archer on it drops.
	l = _make(1)
	await _wait(1.0)
	g = l.stage.top_at(300.0)
	var trap: CastleMechanism = l.spawn_mechanism({"type": "trapdoor", "x": 340, "y": g - 160, "size": [160, 22], "hinge": -1, "trigger": "td"})
	var ar: Archer = l.spawn_archer(Vector2(340, g - 160 - 11 - Data.vec("archers", "size").y * 0.5 - 2))
	var cover: Block = _put(l, "stone_block", 120.0)
	var sw: CastleMechanism = l.spawn_mechanism({"type": "rune_switch", "x": 120, "y": cover.global_position.y, "triggers": ["td"]})
	await _wait(0.8)
	_check(not sw.revealed, "a covered switch stays hidden")
	l.explode(sw.hit_point(), 20.0, 10.0, 1.0)
	await _wait(0.1)
	_check(not sw.active, "a hidden switch ignores hits while covered")
	cover.destroy(false)
	await _wait(Data.bf("rune_switch", "check_s") + 0.2)
	_check(sw.revealed, "the switch glows once its cover breaks")
	var ay: float = ar.global_position.y
	l.explode(sw.hit_point(), 20.0, 10.0, 1.0)
	await _wait(Data.bf("trapdoor", "open_s") + 0.9)
	_check(sw.active and trap.active, "hitting the revealed switch opens the trap door")
	_check(not is_instance_valid(ar) or ar.dead or ar.global_position.y > ay + 60.0, "the archer on the trap door falls")
	l.queue_free()
	await _wait(0.1)


## Boss stages: power cores shield the boss, cannons hit soldiers twice, engineers rebuild.
func _boss_rig_tests() -> void:
	print("-- phase D: boss rig")
	for lid: int in [10, 20, 30, 40, 50]:
		var d: Dictionary = Data.level(lid)
		var cores: int = 0
		for b: Dictionary in d["blocks"]:
			if b["type"] == "power_core":
				cores += 1
		_check(cores >= 1, "boss level %d has a power core (%d)" % [lid, cores])
	var l: Level = _make(10)
	l.archers_in_test = true
	await _wait(1.5)
	_check(l.rig != null and l.rig.cores_total == 1 and l.rig.cannons_total == 1 and l.rig.engineers_total == 1,
			"level 10 builds its rig (1 core, 1 cannon, 1 engineer)")
	var hp0: float = l.boss.hp
	l.boss.take_damage(50.0)
	_check(is_equal_approx(l.boss.hp, hp0), "the boss is shielded while a core stands")
	_check(l.rig.status().has("core") and l.rig.status().has("cannon") and l.rig.status().has("engineer"), "boss bar status lists core, cannon, engineer")
	# Engineer: a broken fortress block near him is rebuilt after repair_s.
	var eng: Archer = l.rig.engineers[0]
	var near: Block = null
	for b: Block in l.blocks:
		if b.mat_id in ["wood", "stone"] and b.global_position.distance_to(eng.global_position) < 400.0:
			near = b
			break
	var shape: String = near.shape_id
	var home: Vector2 = near.start_pos
	near.destroy(true)
	await _wait(Data.bf("boss_rig", "repair_s") + 0.5)
	var rebuilt: bool = false
	for b: Block in l.blocks:
		if b.shape_id == shape and b.global_position.distance_to(home) < 120.0:
			rebuilt = true
	_check(l.rig.repairs >= 1 and rebuilt, "the engineer rebuilds a broken block (%d repairs)" % l.rig.repairs)
	eng.defeat()
	await _wait(0.1)
	_check(int(l.rig.status()["engineer"][0]) == 0, "a knocked-out engineer is counted down")
	# Cannon: a cannonball ignores shields and takes 2 HP from one soldier.
	var s: Soldier = l.soldiers[0]
	var shp: int = s.hp
	var ball: Arrow = Arrow.new()
	l.world.add_child(ball)
	ball.setup(s.body_center() + Vector2(0, -80), s.body_center(), 0.3, [s], l.stage, "cannonball", int(Data.b("boss_rig", "cannon_hits")))
	await _wait(0.5)
	_check(s.hp == shp - int(Data.b("boss_rig", "cannon_hits")) or s.knocked_out, "a cannonball hits a soldier %d times" % int(Data.b("boss_rig", "cannon_hits")))
	# Core down: shield off, boss can be hurt.
	var core: Block = l.rig.cores[0]
	var s0: int = l.score
	core.destroy(true)
	await _wait(0.4)
	_check(l.rig.core_down and l.boss.shield_left <= 0.0 and l.score > s0, "breaking the last core drops the boss shield")
	var hp1: float = l.boss.hp
	l.boss.take_damage(20.0)
	_check(l.boss.hp < hp1, "the boss takes damage once the core is down")
	l.queue_free()
	await _wait(0.1)
	# Cannon firing loop (archers on in test mode).
	var l2: Level = _make(30)
	l2.archers_in_test = true
	await _wait(1.0)
	await _wait(Data.bf("soldiers", "march_s") + Data.bf("boss_rig", "cannon_first_s") + 2.5)
	_check(l2.rig.shots >= 1, "cannons fire at the soldiers (%d shots)" % l2.rig.shots)
	l2.queue_free()
	await _wait(0.1)


## Game modes: heist, time attack, one shot, survival, reverse siege, boss rush, daily challenge.
func _mode_tests() -> void:
	print("-- phase D: modes")
	var list: Array = Data.challenge_list()
	var modes: Dictionary = {}
	for c: Dictionary in list:
		var d: Dictionary = Data.challenge(int(c["id"]))
		modes[String(d.get("mode", ""))] = true
		_check(not d.is_empty() and int(d["id"]) > Data.CHALLENGE_BASE and d.has("mode"), "challenge %d loads with a mode" % int(c["id"]))
	_check(modes.has("heist") and modes.has("time_attack") and modes.has("one_shot") and modes.has("survival") and modes.has("reverse_siege"),
			"challenges cover every mode (%s)" % ", ".join(modes.keys()))
	# Heist: opening chests counts, a chest in the gap is lost, opening enough wins.
	var lh: Level = _make(101)
	await _wait(1.0)
	_check(lh.mode != null and lh.mode.chests_total == 3, "heist finds its 3 chests")
	var c0: Block = lh.mode.chests[0]
	c0.destroy(true)
	await _wait(0.1)
	_check(lh.mode.opened == 1 and lh.state == Level.State.PLAY, "breaking a chest opens it, the heist goes on")
	var c1: Block = lh.mode.chests[0]
	c1.freeze = true
	c1.global_position = Vector2(c1.global_position.x, lh.surface_line() + 50.0)
	await _wait(0.15)
	_check(lh.mode.lost == 1, "a chest that falls into the gap is lost")
	lh.mode.chests[0].destroy(true)
	await _wait(0.15)
	_check(lh.state == Level.State.WON, "opening the needed chests wins the heist")
	lh.queue_free()
	await _wait(0.1)
	# Time attack: the clock runs, heroes refill, time up loses.
	var lt: Level = _make(103)
	await _wait(1.0)
	var t0: float = lt.mode.time_left
	await _wait(0.5)
	_check(lt.mode.time_left < t0, "the time attack clock runs")
	var n0: int = lt.heroes.size()
	lt.hero_index = lt.heroes.size() - 1
	await _wait(0.1)
	_check(lt.heroes.size() > n0, "time attack keeps the heroes coming (%d -> %d)" % [n0, lt.heroes.size()])
	lt.mode.time_left = 0.05
	await _wait(0.2)
	_check(lt.state == Level.State.LOST and lt.lose_reason == "Time up!", "time up loses")
	lt.queue_free()
	await _wait(0.1)
	var lo: Level = _make(105)
	await _wait(0.3)
	_check(lo.heroes.size() == 1 and lo.mode.kind == "one_shot", "one shot gives a single hero")
	lo.queue_free()
	await _wait(0.1)
	# Survival: clearing a wave brings the next one instead of winning.
	var ls: Level = _make(106)
	await _wait(1.0)
	for a: Archer in ls.archers.duplicate():
		a.defeat()
	await _wait(Data.bf("modes", "wave_gap_s") + 0.4)
	_check(ls.state == Level.State.PLAY and ls.mode.wave == 2 and not ls.archers.is_empty(), "survival sends wave 2 (%d guards)" % ls.archers.size())
	ls.queue_free()
	await _wait(0.1)
	# Reverse siege: engines sail toward the player; defeating a crew sinks the engine.
	var lr: Level = _make(107)
	await _wait(1.5)
	var e0: Dictionary = lr.mode.engines[0]
	var m: CastleMechanism = e0["m"]
	var x0: float = m.body.global_position.x
	await _wait(1.0)
	_check(lr.mode.engines.size() == 2 and m.body.global_position.x < x0 - 5.0, "reverse siege engines sail in (%.0f px)" % (x0 - m.body.global_position.x))
	for a: Archer in e0["crew"]:
		a.defeat()
	await _wait(0.3)
	_check(lr.mode.sunk == 1 and bool(e0["sunk"]), "defeating a crew sinks its engine")
	(lr.mode.engines[1]["m"] as CastleMechanism)._approach_x = -5000.0
	await _wait(0.2)
	_check(lr.state == Level.State.LOST and lr.lose_reason.contains("docked"), "an engine that docks loses")
	lr.queue_free()
	await _wait(0.1)
	# Boss rush: the shared pool replaces the level's heroes.
	Game.rush = {"levels": [10, 20], "index": 0, "pool": ["bomb", "bomb", "stone", "fire", "quake", "stone"], "soldier_hp": [1, 3, 0, 2], "time": 0.0}
	var lb: Level = _make(10)
	await _wait(0.3)
	_check(lb.mode != null and lb.mode.kind == "boss_rush" and lb.heroes.size() == 6, "boss rush uses the shared hero pool")
	_check(lb.soldiers[0].hp == 1 and lb.soldiers[2].knocked_out, "boss rush carries soldier HP")
	Game.rush.clear()
	lb.queue_free()
	await _wait(0.1)
	# Daily challenge: picked by date from the list, pays once a day.
	var d1: int = Save.daily_challenge_id("2026-01-01")
	var d2: int = Save.daily_challenge_id("2026-01-02")
	_check(d1 > Data.CHALLENGE_BASE and d1 != d2, "the daily challenge changes by date (%d, %d)" % [d1, d2])
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data["daily_paid"] = ""
	var daily: int = Save.daily_challenge_id()
	Save.data["challenges"][str(daily)] = {"stars": 1, "best": 0}
	var r1: Dictionary = Save.record_result(daily, true, 1, 1000)
	var r2: Dictionary = Save.record_result(daily, true, 1, 1000)
	_check(int(r1["coins"]) - int(r2["coins"]) == int(Data.b("modes", "daily_coins")), "the daily bonus pays once per day")
	_check(int(Save.data["unlocked"]) == int(saved["unlocked"]), "challenges do not unlock campaign levels")
	Save.data = saved
	Save.write()


## Progression: weapons, upgrades, cosmetics, realm chests, rank, achievements, secrets.
func _progression_tests() -> void:
	print("-- phase D: progression")
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data["unlocked"] = 1
	Save.data["stars"] = {}
	for k: String in ["stats", "owned", "ups_vanguard", "ups_weapon", "realm_chests", "ach_claimed", "secrets"]:
		Save.data[k] = {}
	Save.data["weapon"] = "trebuchet"
	_check(Progression.weapon() == "catapult", "a locked siege weapon falls back to the catapult")
	Save.data["unlocked"] = 31
	Progression.set_weapon("trebuchet")
	_check(Progression.weapon() == "trebuchet" and Progression.mass_mult() > 1.3 and Progression.reload_mult() > 1.0,
			"the trebuchet unlocks after level 30 (heavier, slower reload)")
	Progression.set_weapon("ballista")
	_check(Progression.gravity_scale() < 1.0 and Progression.speed_mult() > 1.0, "the ballista shoots flat and fast")
	Save.data["coins"] = 5000
	Save.data["blueprints"] = 0
	var hp0: int = Progression.soldier_hp()
	_check(Progression.buy_up("vanguard", "armor") and Progression.soldier_hp() == hp0 + 1, "Vanguard armor adds soldier HP")
	_check(not Progression.buy_up("vanguard", "armor"), "the second armor level needs a blueprint")
	Save.data["blueprints"] = 1
	_check(Progression.buy_up("vanguard", "armor") and Save.amount("blueprints") == 0, "blueprints unlock the next upgrade")
	var sp: float = Progression.speed_mult()
	Progression.buy_up("weapon", "power")
	_check(Progression.speed_mult() > sp, "the power upgrade raises launch speed")
	# Cosmetics: buy, equip, gems; locked ones refuse.
	Save.data["gems"] = 0
	_check(not Progression.buy_cosmetic("skins", "royal") and not Progression.equip("skins", "royal"), "a gem skin needs gems")
	Save.data["gems"] = 500
	_check(Progression.buy_cosmetic("skins", "royal") and Progression.equip("skins", "royal") and Progression.equipped("skins") == "royal",
			"buying a skin with gems equips it")
	_check(Progression.catapult_tints()[0] != Color.WHITE, "the skin tints the catapult")
	_check(not Progression.buy_cosmetic("skins", "desert_gold"), "chest-only skins cannot be bought")
	# Realm chests + rank.
	for id: int in range(1, 11):
		Save.data["stars"][str(id)] = 3
	_check(Progression.realm_stars(1) == 30 and Progression.chest_state(1, 2) == "ready", "realm 1 chests open with 30 stars")
	var g0: int = Save.amount("gems")
	var r: Dictionary = Progression.claim_chest(1, 0)
	_check(not r.is_empty() and Save.amount("gems") > g0 and Progression.chest_state(1, 0) == "claimed", "claiming a realm chest pays once")
	_check(Progression.claim_chest(1, 0).is_empty(), "a claimed chest cannot be claimed again")
	_check(Progression.rank_name() == "Knight", "30 stars makes you a Knight (%s)" % Progression.rank_name())
	# Achievements from stats.
	Progression.best("chain_best", 22)
	var chain_ach: Dictionary = {}
	for a: Dictionary in Progression.achievements():
		if String(a["id"]) == "chain_20":
			chain_ach = a
	_check(Progression.achievements().size() == 20 and Progression.ach_state(chain_ach) == "ready", "20 achievements; a chain of 22 completes Chain of 20")
	Progression.claim_achievement("chain_20")
	_check(Progression.ach_state(chain_ach) == "claimed" and Progression.owns("skins", "sky"), "the Chain of 20 reward grants the Sky skin")
	# Secrets: the scroll crate in level 7 reveals realm 1's secret level.
	var l: Level = _make(int(Data.b("secrets", "scroll_in")["1"]))
	await _wait(0.5)
	var scroll: Block = null
	for b: Block in l.blocks:
		if bool(b.get_meta("scroll", false)):
			scroll = b
	_check(scroll != null, "level %d hides a map scroll" % int(Data.b("secrets", "scroll_in")["1"]))
	var s0: int = l.score
	scroll.destroy(true)
	await _wait(0.1)
	_check(l.score > s0, "breaking the scroll crate scores the secret bonus")
	l.queue_free()
	await _wait(0.1)
	Progression.find_secret(1)
	_check(Progression.secret_found(1) and not Data.challenge(Progression.secret_level(1)).is_empty(), "the secret level exists once its scroll is found")
	Save.data = saved
	Save.write()


func _material_tests() -> void:
	print("-- phase D: materials (ice, iron, rune crystal)")
	var l: Level = _make(1)
	await _wait(1.0)
	# Ice: slippery, and fire melts it fast without flames.
	var ice: Block = _put(l, "ice_block", 200.0)
	_check(absf(ice.physics_material_override.friction - float(Data.materials["ice"]["friction"])) < 0.001, "ice is slippery")
	ice.ignite(Data.bf("fire", "burn_s"))
	_check(ice.is_melting() and not ice.is_burning(), "fire melts ice instead of burning it")
	await _wait(float(Data.materials["ice"]["hp"]) / float(Data.materials["ice"]["melt_dps"]) + 0.6)
	_check(not is_instance_valid(ice) or ice.dead, "melting ice breaks")
	# Iron: red-hot after fire takes x2.5 damage.
	var cold: Block = _put(l, "iron_block", 300.0)
	var hot: Block = _put(l, "iron_block", 380.0)
	hot.ignite(1.0)
	_check(hot.is_hot() and not hot.is_burning(), "fire makes iron red-hot, not burning")
	var c0: float = cold.hp
	var h0: float = hot.hp
	cold.take_damage(60.0)
	hot.take_damage(60.0)
	var ratio: float = (h0 - hot.hp) / maxf(0.001, c0 - cold.hp)
	_check(absf(ratio - float(Data.materials["iron"]["heat"]["damage_mult"])) < 0.01, "red-hot iron takes x%.1f damage" % ratio)
	cold.destroy(false)
	hot.destroy(false)
	# Iron beam: a hard hit bends it into a V with a two-part collider.
	var beam: Block = _put(l, "iron_beam", 330.0)
	beam.take_damage(40.0)
	_check(not beam.bent, "a light hit does not bend iron")
	var before: int = l.score
	beam.take_damage(float(Data.materials["iron"]["hp"]) * float(Data.materials["iron"]["bend"]["hit_frac"]) / float(Data.materials["iron"]["damage_mult"]) * 1.2)
	await _wait(0.1)
	var parts: int = 0
	for c: Node in beam.get_children():
		if c is CollisionShape2D and not c.is_queued_for_deletion():
			parts += 1
	_check(beam.bent and beam.shape_id == "iron_beam_bent" and parts == 2, "a hard hit bends an iron beam (%d collider parts)" % parts)
	_check(l.score > before, "bending iron scores")
	beam.destroy(false)
	await _wait(0.3)
	# Rune crystal: absorbs a blast without damage, then fires a beam along its arrow. A beam that
	# reaches another rune crystal charges it, so beams can be redirected.
	var ra: Block = _put(l, "rune_crystal", 150.0, {"dir": 0.0})
	var rb: Block = _put(l, "rune_crystal", 430.0, {"dir": -90.0})
	var crate: Block = _put(l, "crate", 430.0, {}, 64.0)
	var target: Block = _put(l, "plank_short", 290.0)
	var ra_hp: float = ra.hp
	var t_hp: float = target.hp
	var c_hp: float = crate.hp
	l.explode(ra.global_position + Vector2(-60, 0), 70.0, 600.0, 200.0)
	_check(is_equal_approx(ra.hp, ra_hp), "a rune crystal absorbs a blast")
	await _wait(float(Data.materials["rune"]["rune"]["charge_s"]) + 0.3)
	_check(not is_instance_valid(target) or target.dead or target.hp < t_hp, "the rune beam hits blocks in its path")
	await _wait(float(Data.materials["rune"]["rune"]["charge_s"]) + 0.3)
	_check(not is_instance_valid(crate) or crate.dead or crate.hp < c_hp, "a beam into another rune is redirected along its arrow")
	l.queue_free()
	await _wait(0.1)


func _phase_c_tests() -> void:
	print("-- phase C: ropes, platforms, crushers, geysers, bolts, wind, tide, bosses, workshop, cinematics")
	# Rope load: a hero passing through the rope cuts it and the boulder falls.
	var lr: Level = _make(_level_with(_has_mech("rope_load")))
	await _wait(0.05)
	var rope: CastleMechanism = _mech(lr, "rope_load")
	var seg: Array = rope.ropes()[0]
	var load_y: float = rope.load_block.global_position.y
	lr.cut_ropes_near(((seg[0] as Vector2) + (seg[1] as Vector2)) * 0.5, 10.0)
	await _wait(0.8)
	_check(rope.ropes().is_empty() and is_instance_valid(rope.load_block) and rope.load_block.global_position.y > load_y + 40.0 or not is_instance_valid(rope.load_block),
			"cutting the rope drops the load (level %d)" % lr.level_id)
	lr.queue_free()
	await _wait(0.1)
	# Explosion cuts ropes too.
	var lr2: Level = _make(_level_with(_has_mech("rope_load")))
	await _wait(0.05)
	var rope2: CastleMechanism = _mech(lr2, "rope_load")
	lr2.explode(rope2.global_position + Vector2(0, 40), 150.0, 0.0, 0.0)
	_check(rope2.ropes().is_empty(), "an explosion near a rope cuts it")
	lr2.queue_free()
	await _wait(0.1)
	# Hanging platform: one rope cut tips it, guards slide off into the gap.
	var lh: Level = _make(_level_with(_has_mech("hanging_platform")))
	await _wait(0.05)
	var hp: CastleMechanism = _mech(lh, "hanging_platform")
	var guards: int = lh.archers.size()
	hp.cut_rope(0)
	await _wait(2.5)
	_check(absf(hp.body.rotation) > 0.8, "a cut gondola rope tips the platform (%.2f rad)" % hp.body.rotation)
	_check(lh.archers.size() < guards, "guards on a tipped gondola fall into the gap (%d -> %d)" % [guards, lh.archers.size()])
	lh.queue_free()
	await _wait(0.1)
	# Triggered crusher falls and crushes what is under it.
	var lc_id: int = _level_with(func(d: Dictionary) -> bool:
		for m: Dictionary in d.get("mechanisms", []):
			if String(m["type"]) == "crusher" and String(m.get("mode", "")) == "trigger":
				return true
		return false)
	var lc: Level = _make(lc_id)
	await _wait(0.05)
	var cr: CastleMechanism = _mech(lc, "crusher")
	var nb: int = lc.blocks.size()
	lc.activate_trigger(cr.trigger_id)
	await _wait(1.0)
	_check(lc.blocks.size() < nb - 2 and cr.body.position.y > float(cr.cfg["travel_y"]) - 2.0,
			"a triggered crusher falls and crushes the keep (%d -> %d blocks)" % [nb, lc.blocks.size()])
	lc.queue_free()
	await _wait(0.1)
	# Geyser lifts a hero inside its column.
	var lg: Level = _make(_level_with(_has_mech("geyser")))
	await _wait(0.05)
	var gy: CastleMechanism = _mech(lg, "geyser")
	var waited: float = 0.0
	while not gy.geyser_active() and waited < 6.0:
		await _wait(0.05)
		waited += 0.05
	var r: Rect2 = gy.geyser_rect()
	lg.heroes = ["stone"]
	lg.hero_index = 0
	lg._load_now()
	lg.fire_hero(Vector2(0, 0))
	lg.projectile.global_position = r.get_center()
	lg.projectile.linear_velocity = Vector2.ZERO
	await _wait(0.3)
	_check(gy.geyser_active() and lg.projectile.linear_velocity.y < -100.0, "an erupting geyser lifts a hero (vy %.0f)" % lg.projectile.linear_velocity.y)
	lg.queue_free()
	await _wait(0.1)
	# Bolts hold a cantilever balcony, then snap in a blast.
	var lb: Level = _make(_level_with(func(d: Dictionary) -> bool: return not d.get("bolts", []).is_empty()))
	await _wait(0.05)
	for b: Block in lb.blocks:
		b.sleeping = false
	await _wait(3.0)
	var bolts_before: int = lb.bolts.size()
	_check(bolts_before > 0 and lb.blocks.size() == lb.blocks_total, "bolted balconies hold on their own (%d bolts)" % bolts_before)
	var bp: Vector2 = lb.bolts[0].position_now()
	lb.explode(bp, 120.0, 0.0, 0.0)
	_check(lb.bolts.size() < bolts_before, "an explosion snaps nearby bolts")
	lb.queue_free()
	await _wait(0.1)
	# Wind: gust pushes heroes, HUD shows it.
	var lw_id: int = _level_with(func(d: Dictionary) -> bool: return d.has("wind"))
	var lw: Level = _make(lw_id)
	await _wait(0.05)
	var w: Dictionary = lw.data["wind"]
	var peak: float = absf(lw.wind_strength_at(float(w["gust_s"]) * 0.5))
	_check(peak > float(w["strength"]) * 0.9 and absf(lw.wind_strength_at(float(w["gust_s"]) + 0.5)) < 1.0,
			"wind gusts ramp up and die down (level %d)" % lw_id)
	lw.heroes = ["stone"]
	lw.hero_index = 0
	lw._load_now()
	lw._wind_t = float(w["gust_s"]) * 0.5 - 0.02
	lw.fire_hero(Vector2(0, -900))
	await _wait(0.4)
	_check(signf(lw.projectile.linear_velocity.x) == signf(float(w["dir"])) and absf(lw.projectile.linear_velocity.x) > 30.0,
			"a gust pushes a hero sideways (vx %.0f)" % lw.projectile.linear_velocity.x)
	lw.queue_free()
	await _wait(0.1)
	# Tide moves the gap surface.
	var lt: Level = _make(_level_with(func(d: Dictionary) -> bool: return d.has("tide")))
	await _wait(0.05)
	var s0: float = lt.stage.surface_y
	await _wait(float(lt.data["tide"]["period_s"]) * 0.25)
	_check(absf(lt.stage.surface_y - s0) > 10.0, "the tide raises and lowers the water (%.0f -> %.0f)" % [s0, lt.stage.surface_y])
	lt.queue_free()
	await _wait(0.1)
	# Boss phases: reinforcements arrive, shield absorbs damage, defeat wins.
	var lboss: Level = _make(_level_with(func(d: Dictionary) -> bool:
		var ph: Array = d.get("boss_unit", {}).get("phases", [])
		return not ph.is_empty() and (ph[0]["do"] as Array).has("reinforce")))
	await _wait(0.05)
	var boss: Archer = lboss.boss
	boss.lock_shield(false)
	var archers_before: int = lboss.archers.size()
	boss.take_damage(boss.max_hp * 0.45)
	await _wait(0.1)
	_check(lboss.archers.size() > archers_before, "boss phase 1 calls reinforcements (%d -> %d)" % [archers_before, lboss.archers.size()])
	lboss.queue_free()
	await _wait(0.1)
	var lsh: Level = _make(_level_with(func(d: Dictionary) -> bool:
		for ph2: Dictionary in d.get("boss_unit", {}).get("phases", []):
			if (ph2["do"] as Array).has("shield"):
				return true
		return false))
	await _wait(0.05)
	var b2: Archer = lsh.boss
	var phases: Array = lsh.data["boss_unit"]["phases"]
	var shield_at: float = 1.0
	for ph3: Dictionary in phases:
		if (ph3["do"] as Array).has("shield"):
			shield_at = float(ph3["at"])
			break
	b2.take_damage(b2.max_hp * (1.0 - shield_at) + 1.0)
	var hp_shielded: float = b2.hp
	b2.take_damage(50.0)
	_check(b2.shield_left > 0.0 and is_equal_approx(b2.hp, hp_shielded), "boss shield absorbs damage")
	b2.shield_left = 0.0
	b2.take_damage(9999.0)
	_check(lsh.boss == b2 and b2.dead, "the boss can be defeated")
	lsh.queue_free()
	await _wait(0.1)
	# Workshop: buying an upgrade spends coins and boosts the hero config.
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data["coins"] = 1000
	Save.data["upgrades"] = {}
	var base_r: float = float(Data.projectiles["bomb"]["explosion"]["radius"])
	var ok: bool = Workshop.buy("bomb")
	_check(ok and Save.coins() == 1000 - int(Data.b("workshop", "costs")[0]) and Workshop.level_of("bomb") == 1,
			"workshop upgrade costs coins and raises the level")
	_check(float(Workshop.config("bomb")["explosion"]["radius"]) > base_r and float(Data.projectiles["bomb"]["explosion"]["radius"]) == base_r,
			"upgrades boost the hero copy, not the base data")
	Save.data = saved
	Save.write()
	# Cinematics play to the end without errors (a scene with actors, focus, demo, hero and boss).
	for cid: int in [_level_with(func(d: Dictionary) -> bool: return d.get("boss", false) and not d.get("cinematic", []).is_empty()),
			_level_with(func(d: Dictionary) -> bool:
				for bt: Dictionary in d.get("cinematic", []):
					if bt["t"] == "hero":
						return true
				return false)]:
		var lcin: Level = _make(cid)
		await _wait(0.05)
		var c: Cinematic = Cinematic.new()
		c.level = lcin
		c.beats = lcin.data["cinematic"]
		lcin.add_child(c)
		var done: Array = [false]
		c.finished.connect(func() -> void: done[0] = true)
		c.play()
		var t: float = 0.0
		while not done[0] and t < 40.0:
			await _wait(0.25)
			t += 0.25
		_check(done[0] and not lcin.camera.cine, "level %d cinematic plays to the end (%d beats)" % [cid, c.beats.size()])
		lcin.queue_free()
		await _wait(0.1)


func _meta_tests() -> void:
	print("-- phase D: meta screens")
	var saved: Dictionary = Save.data.duplicate(true)
	# Daily rewards: one claim per day, streak advances, currencies land in the save.
	Save.data["daily_last"] = ""
	Save.data["daily_streak"] = 0
	var c0: int = Save.amount("coins")
	var r: Dictionary = DailyRewards.claim()
	_check(not r.is_empty() and Save.amount("coins") == c0 + int(r.get("coins", 0)) and DailyRewards.next_day() == 1,
			"daily reward pays day 1 and advances the streak")
	_check(DailyRewards.claim().is_empty() and not DailyRewards.can_claim(), "the daily reward is claimable once a day")
	# Spin wheel: weighted pick bounds, free spin once, ad spins capped.
	_check(SpinWheel.pick(0.0) == 0 and SpinWheel.pick(1.0) == SpinWheel.slices().size() - 1, "spin pick maps roll 0 and 1 to the ends")
	Save.data["spin_free"] = ""
	Save.data["spin_ads"] = {}
	var g0: int = Save.amount("gems") + Save.amount("coins") + Save.amount("blueprints")
	_check(SpinWheel.use_spin(false, 0.0) == 0 and Save.amount("gems") + Save.amount("coins") + Save.amount("blueprints") > g0, "the free spin pays its slice")
	_check(SpinWheel.use_spin(false, 0.5) == -1, "only one free spin a day")
	for i: int in int(Data.b("spin", "ads_per_day")):
		SpinWheel.use_spin(true, 0.5)
	_check(SpinWheel.use_spin(true, 0.5) == -1 and SpinWheel.spins_left() == 0, "ad spins stop at ads_per_day")
	# Store grants + in-game shop spend.
	Save.data["iap_owned"] = []
	Save.data["no_ads"] = false
	var gm: int = Save.amount("gems")
	Store._grant(String(Data.balance["shop"]["gems"][0].get("iap", Data.balance["shop"]["gems"][0]["id"])))
	_check(Save.amount("gems") > gm, "a gem pack grant adds gems")
	Store._grant("starter_pack")
	_check(bool(Save.data["no_ads"]) and Store.owns("starter_pack"), "the starter pack removes ads and is one-time")
	var gold: Dictionary = Data.balance["shop"]["gold"][0]
	Save.data["gems"] = int(gold["cost"]["gems"])
	var cc: int = Save.amount("coins")
	_check(Save.spend(gold["cost"]) and Save.amount("gems") == 0, "buying gold spends gems")
	Save.add("coins", int(gold["gives"]["coins"]), false, false)
	_check(Save.amount("coins") == cc + int(gold["gives"]["coins"]) and not Save.spend(gold["cost"]), "gold lands and a broke wallet cannot buy")
	# Every meta screen, the home screen, the map and settings build without errors.
	for key: String in Game.META:
		var scr: Node = (load(String(Game.META[key])) as GDScript).new()
		add_child(scr)
		await _wait(0.05)
		_check(is_instance_valid(scr) and scr.get_child_count() > 0, "meta screen '%s' builds" % key)
		scr.queue_free()
	Save.data["daily_popup"] = Save.today()
	for script: GDScript in [MainMenu, WorldMap, SettingsPopup]:
		var n: Node = script.new()
		add_child(n)
		await _wait(0.05)
		_check(n.get_child_count() > 0, "%s builds" % script.resource_path.get_file())
		n.queue_free()
	await _wait(0.05)
	Save.data = saved
	Save.write()



# ------------------------------------------------------------------------------------ audio
func _audio_names_in(dir_path: String, out: Dictionary) -> void:
	var re: RegEx = RegEx.new()
	re.compile("Sound\\.play\\(\"([a-z_]+)\"")
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(dir_path + "/" + f)):
				out[m.get_string(1)] = f
	for sub: String in dir.get_directories():
		_audio_names_in(dir_path + "/" + sub, out)


func _audio_tests() -> void:
	print("-- audio")
	var names: Dictionary = {}
	_audio_names_in("res://src", names)
	for n: Variant in Data.balance["audio"]["ui_sounds"]:
		names[String(n)] = "balance ui_sounds"
	var missing: Array = []
	for n: String in names:
		if not ResourceLoader.exists(Sound.SFX_DIR % [n, 0]):
			missing.append("%s (%s)" % [n, names[n]])
	_check(missing.is_empty() and names.size() > 40, "every Sound.play name has a file (%d names) %s" % [names.size(), missing])
	var songs: Array = ["menu", "boss"]
	for r: Dictionary in Data.balance["realms"]:
		songs.append(String(r["key"]))
	var bad: Array = []
	for sg: String in songs:
		var b: AudioStreamWAV = Sound._looped(Sound.MUSIC_DIR % (sg + "_base")) as AudioStreamWAV
		var a: AudioStreamWAV = Sound._looped(Sound.MUSIC_DIR % (sg + "_action")) as AudioStreamWAV
		if b == null or a == null or absf(b.get_length() - a.get_length()) > 0.002 or b.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			bad.append(sg)
	_check(bad.is_empty(), "songs %s have synced looping base + action stems %s" % [songs, bad])
	var stings: Array = []
	for st: String in ["win", "lose", "boss_intro", "siege_start", "reward"]:
		if not ResourceLoader.exists(Sound.MUSIC_DIR % ("sting_" + st)):
			stings.append(st)
	_check(stings.is_empty(), "all stingers exist %s" % [stings])
	var amb_bad: Array = []
	for r: Dictionary in Data.balance["realms"]:
		var cfg: Dictionary = Data.balance["audio"]["ambience"].get(String(r["key"]), {})
		if cfg.is_empty() or Sound._looped(Sound.AMB_DIR % String(cfg["bed"])) == null:
			amb_bad.append(String(r["key"]))
			continue
		for d: Dictionary in cfg["details"]:
			if Sound._amb_variants(String(d["name"])).is_empty():
				amb_bad.append(String(d["name"]))
	_check(amb_bad.is_empty(), "every realm has an ambience bed and its details %s" % [amb_bad])
	# State machine: game events move the music from aim to flight to destruction, then result.
	Sound.set_music("mines", "aim")
	Sound.set_surroundings("mines")
	var wet: float = float(Data.balance["audio"]["realm_reverb"]["mines"]["wet"])
	_check(Sound.song == "mines" and is_equal_approx(Sound._reverb.wet, wet), "mines music and cave reverb (wet %.2f)" % Sound._reverb.wet)
	Events.projectile_launched.emit("stone")
	var s1: String = Sound.state
	Events.block_destroyed.emit(null, 10)
	var s2: String = Sound.state
	_check(s1 == "flight" and s2 == "destruction" and Sound._energy > 0.0, "launch -> flight, block break -> destruction (%s, %s, energy %.2f)" % [s1, s2, Sound._energy])
	Events.level_finished.emit(1, true, 3, 1000)
	_check(Sound.state == "result", "level end -> result state")
	await _wait(0.3)
	_check(Sound._decks[0].base.playing and Sound._decks[0].song == "mines", "the mines deck is playing")
	Sound.set_music("menu", "menu")
	Sound.set_surroundings("blossom", true)
