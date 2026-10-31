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
	if str(Game.args.get("run-tests", "")) == "specials":
		await _special_pack_tests()
		return
	if str(Game.args.get("run-tests", "")) == "billing":
		await _billing_tests()
		return
	var only: String = str(Game.args.get("run-tests", ""))
	var lo: int = 1
	var hi: int = Data.level_count()
	if only.begins_with("stability:"):  # --run-tests=stability:1-6 : stability + framing for a range
		var span: PackedStringArray = only.trim_prefix("stability:").split("-")
		lo = int(span[0])
		hi = int(span[span.size() - 1])
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
					"rope_load", "hanging_platform", "crusher", "geyser", "lever", "windmill", "shield_ring", "rune_switch", "trapdoor", "flood"], "level %d has a known mechanism type" % id)
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
	for id: int in range(lo, hi + 1):
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
			if Game.args.has("debug-drift") and (b.global_position.distance_to(b.start_pos) > 6.0 or absf(angle_difference(b.rotation, b.start_rot)) > 0.035):
				print("DRIFT %d %s from %s to %s" % [id, b.shape_id, b.start_pos, b.global_position])
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
		# Framing: the whole fortress (boss crown and shield included) sits below the HUD band on
		# 20:9 and 16:9 phones, and inside the right edge.
		var fitted: Array = l.fit_camera()
		for view: Vector2 in [Vector2(1600, 720), Vector2(1280, 720)]:
			var zf: Vector2 = GameCamera.fit(view, l.camera.left, float(fitted[1]), float(fitted[0]), l.camera.hud_top)
			var top_y: float = zf.y * view.y + float(fitted[0]) * zf.x
			_check(top_y >= l.camera.hud_top - 1.0, "level %d: fortress top below the HUD at %dx%d (y %.0f, zoom %.2f)" % [id, view.x, view.y, top_y, zf.x])
		_check(l.blocks.size() == total, "level %d: no block broke on its own (%d/%d)" % [id, l.blocks.size(), total])
		_check(l.archers.size() == expected_archers, "level %d: no archer died on its own" % id)
		_check(worst_move < move_limit and worst_rot < rot_limit,
				"level %d: blocks drift %.2f/%.0f px / %.2f/%.0f deg" % [id, worst_move, move_limit, worst_rot, rot_limit])
		_check(archer_move < move_limit, "level %d: archers drift %.2f/%.0f px" % [id, archer_move, move_limit])
		l.queue_free()
		await _wait(0.1)

	if only.begins_with("stability:"):
		return
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

	# Rollers: a nudge sends the free boulder, wheel and cart down their slopes.
	for case: Array in [[11, "log"], [15, "boulder"], [35, "wheel"], [49, "cart"]]:
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

	# Level 19: either suspension rope releases one side of the guarded bridge.
	l = _make(19)
	await _wait(0.2)
	var rope_bridge: CastleMechanism = _mech(l, "hanging_platform")
	var bridge_y: float = rope_bridge.body.global_position.y
	rope_bridge.cut_rope(0)
	await _wait(1.2)
	_check(absf(rad_to_deg(rope_bridge.body.rotation)) > 45.0 and rope_bridge.body.global_position.y > bridge_y,
			"level 19: one cut collapses the rope bridge (%.0f deg)" % absf(rad_to_deg(rope_bridge.body.rotation)))
	l.queue_free()
	await _wait(0.1)

	# Level 18: the drawbridge has a visible pulley and moving counterweight rig.
	l = _make(18)
	await _wait(0.1)
	var pulley_bridge: CastleMechanism = _mech(l, "drawbridge")
	var weight_y: float = pulley_bridge._counterweight.position.y
	pulley_bridge.activate(false)
	await _wait(1.0)
	_check(pulley_bridge.get_node_or_null("Pulley") != null and pulley_bridge._counterweight.position.y > weight_y + 50.0,
			"level 18: pulley raises the bridge counterweight")
	l.queue_free()
	await _wait(0.1)

	# Level 38: the mill wheel waits jammed until its brake trigger breaks, then turns.
	l = _make(38)
	await _wait(0.2)
	var water_wheel: CastleMechanism = _mech(l, "windmill")
	var wheel_angle: float = water_wheel.body.rotation
	var waits: bool = water_wheel.jammed and not water_wheel.active
	l.activate_trigger("mill")
	await _wait(0.5)
	_check(waits and water_wheel.active and not water_wheel.jammed and absf(angle_difference(wheel_angle, water_wheel.body.rotation)) > 0.05,
			"level 38: breaking the brake starts the water wheel")
	l.queue_free()
	await _wait(0.1)

	# Level 32: cutting the brake sends its bolted powder barrels into the crystal mine.
	l = _make(32)
	await _wait(0.2)
	var cart_rope: Tether = _tether_of(l, func(t: Tether) -> bool: return bool(t.cfg.get("lock", false)) and t.a.shape_id == "cart")
	var powder_cart: Block = cart_rope.a
	var cart_x: float = powder_cart.global_position.x
	var barrels_before: int = 0
	for b32: Block in l.blocks:
		if b32.shape_id == "barrel":
			barrels_before += 1
	cart_rope.release(true)
	await _wait(4.0)
	var barrels_after: int = 0
	for b32b: Block in l.blocks:
		if b32b.shape_id == "barrel":
			barrels_after += 1
	_check(cart_rope.cut and (not is_instance_valid(powder_cart) or powder_cart.global_position.x > cart_x + 250.0) and barrels_after < barrels_before,
			"level 32: the released powder cart rolls and explodes (%d/%d kegs left)" % [barrels_after, barrels_before])
	l.queue_free()
	await _wait(0.1)

	# Level 12: slamming the short arm throws the powder keg onto the iron strongroom.
	l = _make(12)
	await _wait(1.3)
	var beam: Tether = _tether_of(l, func(t: Tether) -> bool: return t.payload != null)
	var keg: Block = beam.payload
	var g12: int = l.archers.size()
	beam.a.angular_velocity = 3.0
	var keg_path: Array[Vector2] = []
	for i: int in 30:
		await _wait(0.1)
		if is_instance_valid(keg) and not keg.dead:
			keg_path.append(keg.global_position)
	if Game.args.has("debug-launch"):
		print("KEG path ", keg_path)
	_check(beam.launched and (not is_instance_valid(keg) or keg.dead) and l.archers.size() <= g12 - 1,
			"level 12: the beam throws the keg and it blows the strongroom (%d guards down)" % (g12 - l.archers.size()))
	l.queue_free()
	await _wait(0.1)

	# Level 21: hitting the sluice gate floods the dock and drowns the guards in the iron sheds.
	l = _make(21)
	await _wait(0.3)
	var g21: int = l.archers.size()
	_mech(l, "flood")._hit()
	await _wait(5.0)
	_check(l.archers.size() <= g21 - 2, "level 21: the flood washes out the iron sheds (%d guards down)" % (g21 - l.archers.size()))
	l.queue_free()
	await _wait(0.1)

	# Level 22: breaking the keystone drops the shelf and the strongroom into the sea.
	l = _make(22)
	await _wait(0.3)
	var g22: int = l.archers.size()
	for b22: Block in l.blocks:
		if b22.is_weak_point():
			b22.take_damage(99999.0)
	await _wait(3.5)
	_check(l.archers.size() <= g22 - 2, "level 22: the cracked shelf drops the strongroom (%d guards down)" % (g22 - l.archers.size()))
	l.queue_free()
	await _wait(0.1)

	# Level 2: the hanging rock crushes the wooden watchtower under it.
	l = _make(2)
	await _wait(0.1)
	var rl: CastleMechanism = _mech(l, "rope_load")
	var before: int = l.blocks.size()
	var guards: int = l.archers.size()
	rl.cut_rope(0)
	await _wait(2.5)
	_check(before - l.blocks.size() >= 3 and l.archers.size() < guards,
			"level 2: the dropped rock smashes the tower (%d pieces, %d guards down)" % [before - l.blocks.size(), guards - l.archers.size()])
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
	await _special_pack_tests()
	await _mode_tests()
	await _progression_tests()
	await _meta_tests()
	await _billing_tests()
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
	Save.data["stars"] = {}
	_check(not Save.spend({"coins": 100, "gems": 6}) and Save.coins() == 500,
			"wallet: spend fails whole when one currency is short")
	_check(Save.spend({"coins": 100, "gems": 5}) and Save.coins() == 400 and Save.amount("gems") == 0,
			"wallet: spend takes every currency in the cost")
	_check(Save.WALLET == ["coins", "gems"] and not Save.data.has("blueprints"), "wallet: only coins and gems exist")
	var c: Dictionary = Data.balance["currencies"]
	var r3: Dictionary = Save.rewards_for(7, 3, false)
	_check(not r3.has("gems") and int(r3["coins"]) == 3 * int(Data.b("coins", "per_star_first_clear")) + int(Data.b("coins", "replay_win")),
			"wallet: a first 3-star clear pays coins, not gems")
	var rb: Dictionary = Save.rewards_for(10, 1, true)
	_check(int(rb.get("gems", 0)) == int(c["gems_boss_first_clear"]) and int(rb["coins"]) > int(Data.b("coins", "boss_first_clear")),
			"wallet: a first boss clear is the rare free gem source")
	Save.data["stars"] = {"7": 3, "10": 1}
	var again: Dictionary = Save.rewards_for(7, 3, false)
	var boss_again: Dictionary = Save.rewards_for(10, 1, true)
	_check(not again.has("gems") and not boss_again.has("gems") and int(again["coins"]) > 0,
			"wallet: replays give coins only (no premium farming)")
	# Free gems in a full playthrough stay small next to skin prices.
	var free_gems: int = 5 * int(c["gems_boss_first_clear"])
	for a: Dictionary in Data.balance["achievements"]:
		free_gems += int(a["reward"].get("gems", 0))
	for r: Dictionary in Data.balance["realm_chests"]["rewards"]:
		free_gems += 5 * int(r.get("gems", 0))
	_check(free_gems < int(Data.balance["cosmetics"]["skins"]["shadow"]["price"]["gems"]),
			"wallet: all free gems (%d) buy less than the legendary skin" % free_gems)
	# v3 -> v4 migration: nothing is lost.
	var old: Dictionary = {"coins": 100, "blueprints": 2, "unlocked": 25, "upgrades": {"bomb": 2},
			"ups_weapon": {"power": 1, "reload": 1}}
	Save.migrate_v4(old)
	var refund: Dictionary = c["legacy_refund"]
	var want: int = 100 + 2 * int(c["blueprint_to_coins"]) + int(refund["hero_level"][0]) + int(refund["hero_level"][1]) \
			+ int(refund["weapon_power"][0]) + int(refund["weapon_reload"][0])
	_check(int(old["coins"]) == want and not old.has("blueprints") and not old.has("upgrades"),
			"migration: blueprints and old upgrades become coins (%d)" % int(old["coins"]))
	_check(bool(old["owned_weapons"].get("ballista", false)) and not old["owned_weapons"].has("trebuchet"),
			"migration: engines already unlocked by level stay owned")
	Save.data = saved
	Save.write()


## Phase D mechanisms: lever, windmill, shield ring, hidden switch, trap door.
func _mechanism_d_tests() -> void:
	# Drawbridge: landing must hurt (playtest: "the ramp drops and nothing happens").
	var lb: Level = _make(4)
	await _wait(1.0)
	var alive0: int = lb.archers.filter(func(x: Archer) -> bool: return not x.dead).size()
	for m: CastleMechanism in lb.mechanisms:
		if m.kind == "drawbridge":
			m.activate()
	await _wait(4.0)
	var alive1: int = lb.archers.filter(func(x: Archer) -> bool: return is_instance_valid(x) and not x.dead).size()
	_check(alive0 - alive1 >= 2, "a landing drawbridge takes out guards (%d -> %d)" % [alive0, alive1])
	lb.queue_free()
	await _wait(0.1)
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


func _special_has(d: Dictionary, required: String) -> bool:
	var mechanisms: Array = d.get("mechanisms", [])
	var tethers_data: Array = d.get("tethers", [])
	match required:
		"flood":
			return mechanisms.any(func(m: Dictionary) -> bool: return String(m.get("type", "")) == "flood")
		"water_wheel":
			return mechanisms.any(func(m: Dictionary) -> bool: return String(m.get("type", "")) == "windmill" and String(m.get("style", "")) == "wheel" and m.has("start_on"))
		"rope_bridge":
			return mechanisms.any(func(m: Dictionary) -> bool: return String(m.get("type", "")) == "hanging_platform")
		"breakable_ledge":
			return mechanisms.any(func(m: Dictionary) -> bool: return String(m.get("type", "")) == "trapdoor" and String(m.get("style", "")) in ["rock", "timber"])
		"pulley":
			return mechanisms.any(func(m: Dictionary) -> bool: return String(m.get("type", "")) == "drawbridge" and m.has("counterweight_travel"))
		"launch_seesaw":
			return tethers_data.any(func(t: Dictionary) -> bool: return String(t.get("kind", "")) == "pin" and t.has("launch"))
		"explosive_cart":
			var cart_i: int = -1
			for i: int in (d.get("blocks", []) as Array).size():
				if String(d["blocks"][i].get("type", "")) == "cart":
					cart_i = i
					break
			return cart_i >= 0 and tethers_data.any(func(t: Dictionary) -> bool: return int(t.get("a", -1)) == cart_i and bool(t.get("lock", false))) \
					and not (d.get("bolts", []) as Array).is_empty()
	return false


## Master Sieges: ten stable, hard mechanic puzzles, unlocked by 25 campaign stars and excluded
## from the daily challenge rotation.
func _special_pack_tests() -> void:
	print("-- master sieges special pack")
	var specials: Array = Data.special_list()
	var first: int = int(Data.b("special_pack", "first_id"))
	var last: int = int(Data.b("special_pack", "last_id"))
	_check(specials.size() == 10 and int(specials[0]["id"]) == first and int(specials[-1]["id"]) == last,
			"special pack has ten ordered levels (%d-%d)" % [first, last])
	var daily_ids: Array[int] = []
	for challenge: Dictionary in Data.challenge_list():
		daily_ids.append(int(challenge["id"]))
	var ids: Array[int] = []
	for card: Dictionary in specials:
		var id: int = int(card["id"])
		ids.append(id)
		var d: Dictionary = Data.challenge(id)
		_check(not d.is_empty() and bool(d.get("special", false)) and bool(d.get("challenge", false)),
				"special %d loads as challenge data" % id)
		_check((d.get("heroes", []) as Array).size() == 4 and (d.get("archers", []) as Array).size() >= 3,
				"special %d is a hard fixed four-shot siege (%d guards)" % [id, (d.get("archers", []) as Array).size()])
		var required: Array = d.get("required_mechanics", [])
		var all_present: bool = not required.is_empty()
		for mechanic: Variant in required:
			all_present = all_present and _special_has(d, String(mechanic))
		_check(all_present, "special %d contains every required mechanic: %s" % [id, ", ".join(required)])
	_check(ids.all(func(id: int) -> bool: return not daily_ids.has(id)), "specials stay out of daily challenge rotation")

	var saved: Dictionary = Save.data.duplicate(true)
	Save.data["stars"] = {}
	Save.data["challenges"] = {str(first): {"stars": 3, "best": 99999}}
	_check(not Save.special_pack_unlocked() and not Game.can_enter_level(first), "special pack stays locked below 25 campaign stars")
	for id: int in range(1, 9):
		Save.data["stars"][str(id)] = 3
	Save.data["stars"]["9"] = 1
	_check(Save.total_stars() == int(Data.b("special_pack", "star_gate")) and Save.special_pack_unlocked() and Game.can_enter_level(first),
			"25 campaign stars unlock every Master Siege")
	Save.data = saved
	Save.write()

	# Every special starts at rest for the full campaign stability window and fits common phones.
	for id: int in ids:
		var l: Level = _make(id)
		await _wait(0.1)
		var total_blocks: int = l.blocks.size()
		var total_guards: int = l.archers.size()
		for b: Block in l.blocks:
			b.sleeping = false
		for a: Archer in l.archers:
			a.sleeping = false
		await _wait(STAND_S)
		var worst: float = 0.0
		for b: Block in l.blocks:
			if not b.held:
				worst = maxf(worst, b.global_position.distance_to(b.start_pos))
		var fitted: Array = l.fit_camera()
		var framed: bool = true
		for view: Vector2 in [Vector2(1600, 720), Vector2(1280, 720)]:
			var zf: Vector2 = GameCamera.fit(view, l.camera.left, float(fitted[1]), float(fitted[0]), l.camera.hud_top)
			framed = framed and zf.y * view.y + float(fitted[0]) * zf.x >= l.camera.hud_top - 1.0
		_check(l.blocks.size() == total_blocks and l.archers.size() == total_guards and worst < MAX_MOVE_PX and framed,
				"special %d stands for 10 s and fits 20:9/16:9 (drift %.1f px)" % [id, worst])
		l.queue_free()
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
	# Special Missions open one by one (index unlock_level), each with its own emblem.
	var keep_u: int = int(Save.data["unlocked"])
	var keep_stars: Dictionary = (Save.data["stars"] as Dictionary).duplicate()
	Save.data["stars"] = {}  # stars on an unlock level also open a mission; start clean
	Save.data["unlocked"] = 11
	var open_ids: Array = []
	var icons: Dictionary = {}
	for c: Dictionary in Data.challenge_list():
		if Save.mission_unlocked(int(c["id"])):
			open_ids.append(int(c["id"]))
		icons[String(c.get("icon", ""))] = true
		_check(int(c.get("unlock_level", 0)) >= int(Data.b("modes", "challenges_unlock_level")) and Art.exists(String(c.get("icon", ""))),
				"mission %d has an unlock level and its own emblem" % int(c["id"]))
	_check(open_ids.size() == 1, "after level 10 only one mission is open (%s)" % [open_ids])
	_check(icons.size() == Data.challenge_list().size(), "no two missions share an icon")
	var locked_id: int = 107
	_check(not Game.can_enter_level(locked_id), "a locked mission can't be entered")
	_check(Save.daily_challenge_id("2026-01-05") in open_ids, "today's mission is always an open one")
	Save.data["unlocked"] = 45
	_check(Game.can_enter_level(locked_id), "clearing its campaign level opens the mission")
	Save.data["unlocked"] = 51
	Save.data["stars"] = keep_stars
	# Daily challenge: picked by date from the list, pays once a day.
	var d1: int = Save.daily_challenge_id("2026-01-01")
	var d2: int = Save.daily_challenge_id("2026-01-02")
	_check(d1 > Data.CHALLENGE_BASE and d1 != d2, "the daily challenge changes by date (%d, %d)" % [d1, d2])
	var saved: Dictionary = Save.data.duplicate(true)
	saved["unlocked"] = keep_u
	Save.data["daily_paid"] = ""
	var daily: int = Save.daily_challenge_id()
	Save.data["challenges"][str(daily)] = {"stars": 1, "best": 0}
	var r1: Dictionary = Save.record_result(daily, true, 1, 1000)
	var r2: Dictionary = Save.record_result(daily, true, 1, 1000)
	_check(int(r1["coins"]) - int(r2["coins"]) == int(Data.b("modes", "daily_coins")), "the daily bonus pays once per day")
	_check(int(Save.data["unlocked"]) == 51, "challenges do not unlock campaign levels")
	Save.data = saved
	Save.write()


## Progression: weapons, upgrades, cosmetics, realm chests, rank, achievements, secrets.
func _progression_tests() -> void:
	# Story scenes only where something new appears (steer: no previews on every level).
	_check(not Data.novelty(1).is_empty(), "level 1 introduces the game")
	_check("hero:fire" in Data.novelty(3) and "hero:bomb" in Data.novelty(6) and "hero:cyclone" in Data.novelty(12), "each new hero is flagged where it first appears")
	_check("mech:rope_load" in Data.novelty(2) and "mech:crusher" in Data.novelty(13), "each new mechanism is flagged where it first appears")
	_check(Data.novelty(16).is_empty() and Data.novelty(7).is_empty(), "levels with nothing new have no novelty")
	var stories: PackedStringArray = PackedStringArray()
	var skipped: int = 0
	for n: int in range(1, Data.level_count() + 1):
		if (Data.level(n).get("cinematic", []) as Array).is_empty():
			continue
		if Data.novelty(n).is_empty():
			skipped += 1
		else:
			stories.append(str(n))
	print("    story scenes kept on levels ", ",".join(stories), "; skipped ", skipped)
	_check(skipped > 0, "story scenes are skipped on levels that bring nothing new")
	print("-- phase D: progression")
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data["unlocked"] = 1
	Save.data["stars"] = {}
	for k: String in ["stats", "owned", "ups_vanguard", "ups_weapon", "realm_chests", "ach_claimed", "secrets"]:
		Save.data[k] = {}
	Save.data["weapon"] = "trebuchet"
	Save.data["owned_weapons"] = {}
	_check(Progression.weapon() == "catapult", "a locked siege weapon falls back to the catapult")
	Save.data["unlocked"] = 31
	_check(not Progression.set_weapon("trebuchet") and Progression.weapon() == "catapult",
			"reaching level 31 only reveals the trebuchet; it still has to be forged")
	Save.data["coins"] = int(Progression.weapon_cfg("trebuchet")["unlock_cost"]["coins"]) - 1
	_check(not Progression.buy_weapon("trebuchet"), "forging the trebuchet needs its full coin cost")
	Save.data["coins"] = 200000
	_check(Progression.buy_weapon("trebuchet") and Progression.weapon() == "trebuchet" and Progression.mass_mult() > 1.3
			and Progression.reload_mult() > 1.0 and Progression.ability_mult() > 1.0,
			"a forged trebuchet is heavier, reloads slower and boosts abilities")
	var ab0: float = Progression.ability_mult()
	_check(Progression.buy_weapon_up("trebuchet", "sling") and Progression.ability_mult() > ab0, "the sling upgrade raises ability power")
	var cw0: float = Progression.mass_mult()
	_check(Progression.buy_weapon_up("trebuchet", "counterweight") and Progression.mass_mult() > cw0, "the counterweight raises hero mass")
	_check(Progression.buy_weapon("ballista") and Progression.gravity_scale() < 1.0 and Progression.speed_mult() > 1.0
			and Progression.damage_mult() > 1.0, "the ballista shoots flat, fast and hits harder")
	var dm0: float = Progression.damage_mult()
	_check(Progression.buy_weapon_up("ballista", "piercing") and Progression.damage_mult() > dm0, "piercing rail raises direct damage")
	_check(Progression.weapon_up_level("trebuchet", "sling") == 1 and Progression.weapon_up_level("ballista", "sling") == 0,
			"upgrades belong to one engine")
	var cost_steps: Array = Progression.weapon_cfg("catapult")["tracks"]["torsion"]["cost"]
	_check(int(cost_steps[-1]["coins"]) >= 5 * int(cost_steps[0]["coins"]), "upgrade costs climb steeply (heavy coin sink)")
	Save.data["coins"] = int(Data.balance["upgrades"]["vanguard"]["armor"]["cost"][0]["coins"]) + 2000
	var hp0: int = Progression.soldier_hp()
	_check(Progression.buy_up("vanguard", "armor") and Progression.soldier_hp() == hp0 + 1, "Vanguard armor adds soldier HP")
	_check(not Progression.buy_up("vanguard", "armor"), "the next armor level costs more coins than are left")
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
	var c0: int = Save.coins()
	var r: Dictionary = Progression.claim_chest(1, 0)
	_check(not r.is_empty() and Save.coins() > c0 and Progression.chest_state(1, 0) == "claimed", "claiming a realm chest pays once")
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
	# Heroes are not upgradable: fixed power, introduced at authored campaign levels.
	var saved: Dictionary = Save.data.duplicate(true)
	var base_r: float = float(Data.projectiles["bomb"]["explosion"]["radius"])
	var ws_methods: Array = (load("res://src/game/workshop.gd") as GDScript).get_script_method_list().map(func(m: Dictionary) -> String: return String(m["name"]))
	_check(float(Workshop.config("bomb")["explosion"]["radius"]) == base_r and not ws_methods.has("buy"),
			"hero power is fixed (no hero upgrades)")
	Save.data["unlocked"] = Workshop.intro_level("quake") - 1
	_check(not Workshop.introduced("quake") and Workshop.introduced("stone"), "Quaky stays locked before his introduction level")
	Save.data["unlocked"] = Workshop.intro_level("quake")
	_check(Workshop.introduced("quake"), "Quaky is introduced at level %d" % Workshop.intro_level("quake"))
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
	var g0: int = Save.amount("gems") + Save.amount("coins")
	_check(SpinWheel.use_spin(false, 0.0) == 0 and Save.amount("gems") + Save.amount("coins") > g0, "the free spin pays its slice")
	_check(SpinWheel.use_spin(false, 0.5) == -1, "only one free spin a day")
	for i: int in int(Data.b("spin", "ads_per_day")):
		SpinWheel.use_spin(true, 0.5)
	_check(SpinWheel.use_spin(true, 0.5) == -1 and SpinWheel.spins_left() == 0, "ad spins stop at ads_per_day")
	# In-game shop: gold costs gems, a broke wallet cannot buy.
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



# ------------------------------------------------------------------------------------ billing
func _fake_store(cfg: Dictionary = {}) -> RefCounted:
	var fake: RefCounted = (load(Store.FAKE_BACKEND) as GDScript).new()
	for k: String in cfg:
		fake.set(k, cfg[k])
	Store.use_backend(fake)
	await _wait(0.1)
	return fake


func _billing_tests() -> void:
	print("-- billing")
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data["iap"] = {}
	Save.data["no_ads"] = false
	Save.data["coins"] = 0
	Save.data["gems"] = 0
	Save.data["hellfire"] = 0
	var fake: RefCounted = await _fake_store()
	_check(Store.available() and not Store.price_text("coin_crate").is_empty(), "store connects and loads Play prices")
	_check(Data.balance["shop"]["order"].size() == 4 + HeroAddons.ids().size() and Store.product("remove_ads")["type"] == "non_consumable"
			and Store.product("hellfire_crate")["gives"]["hellfire"] == 3, "catalog: Remove Ads + 3 crates + Rocky addons (Hellfire gives 3)")
	# Every product delivers exactly its contents once.
	var expect: Dictionary = {"coin_crate": ["coins", 30000], "gem_crate": ["gems", 400], "hellfire_crate": ["hellfire", 3]}
	for id: String in expect:
		var k: String = expect[id][0]
		var before: int = Save.amount(k)
		_check(Store.buy(id), "%s purchase starts" % id)
		await _wait(0.2)
		_check(Save.amount(k) == before + int(expect[id][1]) and fake.get("play_purchases").is_empty(),
				"%s grants %d %s and is consumed" % [id, int(expect[id][1]), k])
	# Repeat purchase of the same crate works.
	var c0: int = Save.coins()
	Store.buy("coin_crate")
	await _wait(0.2)
	_check(Save.coins() == c0 + 30000, "the same crate can be bought again")
	# Busy guard: only one purchase at a time.
	fake.set("next_outcome", "pending")
	_check(Store.buy("coin_crate") and not Store.buy("gem_crate"), "a second purchase is refused while one runs")
	await _wait(0.2)
	_check(Save.coins() == c0 + 30000 and Store.busy_product.is_empty(), "a pending purchase grants nothing yet")
	fake.call("complete_pending")
	await _wait(0.2)
	_check(Save.coins() == c0 + 60000, "the pending purchase is granted once Play confirms it")
	# Cancel and failure grant nothing.
	var c1: int = Save.coins()
	fake.set("next_outcome", "cancel")
	Store.buy("coin_crate")
	await _wait(0.2)
	fake.set("next_outcome", "fail")
	Store.buy("coin_crate")
	await _wait(0.2)
	_check(Save.coins() == c1 and Store.busy_product.is_empty(), "cancelled and failed purchases grant nothing")
	# Duplicate callbacks for one token grant once.
	fake.set("next_outcome", "purchased")
	fake.set("duplicate_callbacks", true)
	Store.buy("coin_crate")
	await _wait(0.3)
	_check(Save.coins() == c1 + 30000, "duplicate purchase callbacks grant only once")
	fake.set("duplicate_callbacks", false)
	# Consume fails: reward kept, never granted again, consume retried on reconnect / restart.
	fake.set("fail_consume", true)
	var g0: int = Save.amount("gems")
	Store.buy("gem_crate")
	await _wait(0.2)
	_check(Save.amount("gems") == g0 + 400 and fake.get("play_purchases").size() == 1, "a failed consume keeps the saved reward")
	fake.set("fail_consume", false)
	var fake2: RefCounted = (load(Store.FAKE_BACKEND) as GDScript).new()
	fake2.set("play_purchases", fake.get("play_purchases"))
	Store.use_backend(fake2)  # app restart / reconnect: Play still reports the unconsumed token
	await _wait(0.3)
	_check(Save.amount("gems") == g0 + 400 and fake2.get("play_purchases").is_empty(),
			"recovery consumes the token without granting twice")
	# A purchase made while the app was closed is granted on the next start.
	var orphan: Dictionary = {"purchase_token": "orphan-1", "product_ids": ["hellfire_crate"], "purchase_state": 1, "is_acknowledged": false}
	var h0: int = Save.amount("hellfire")
	fake2.set("play_purchases", [orphan])
	Store.restore()
	await _wait(0.3)
	_check(Save.amount("hellfire") == h0 + 3, "an unfinished purchase from a crash is recovered")
	# Never grant for an unknown product or a non-purchased state.
	fake2.set("play_purchases", [{"purchase_token": "x1", "product_ids": ["hacked_pack"], "purchase_state": 1},
			{"purchase_token": "x2", "product_ids": ["coin_crate"], "purchase_state": 0}])
	var c2: int = Save.coins()
	Store.restore()
	await _wait(0.3)
	_check(Save.coins() == c2, "unknown products and non-purchased states are ignored")
	fake2.set("play_purchases", [])
	# Remove Ads: acknowledged (never consumed), disables ads, restored from Play, revoked on refund.
	_check(Store.buy("remove_ads"), "remove ads purchase starts")
	await _wait(0.3)
	var ra: Array = fake2.get("play_purchases")
	_check(Store.owns("remove_ads") and Ads.ads_removed() and ra.size() == 1 and bool(ra[0]["is_acknowledged"]),
			"Remove Ads is granted, acknowledged and not consumed")
	_check(not Store.buy("remove_ads") and Ads.rewarded_ready() and not Ads.interstitial_due(99),
			"owned Remove Ads cannot be rebought and turns off every ad format")
	Save.data["iap"] = {}
	Save.data["no_ads"] = false
	Store.restore()
	await _wait(0.3)
	_check(Store.owns("remove_ads") and Ads.ads_removed(), "Remove Ads is restored from Google Play (reinstall / new device)")
	fake2.set("play_purchases", [])
	Store.restore()
	await _wait(0.3)
	_check(not Store.owns("remove_ads") and not Ads.ads_removed(), "a refunded Remove Ads is revoked")
	# Acknowledge failure keeps the entitlement and retries.
	fake2.set("fail_ack", true)
	Store.buy("remove_ads")
	await _wait(0.3)
	_check(Store.owns("remove_ads") and not bool(fake2.get("play_purchases")[0]["is_acknowledged"]), "a failed acknowledge keeps Remove Ads")
	fake2.set("fail_ack", false)
	Store.restore()
	await _wait(0.3)
	_check(bool(fake2.get("play_purchases")[0]["is_acknowledged"]), "the acknowledge is retried on the next query")
	# Store offline: buy is refused, nothing breaks.
	var off: RefCounted = await _fake_store({"connect_ok": false})
	_check(not Store.available() and not Store.buy("coin_crate"), "offline store refuses purchases")
	_check(PurchaseProcessor.mask("abcdefghijkl") == "abcdef…", "purchase tokens are masked in logs")
	Save.data = saved
	Save.write()
	await _fake_store()
	await _ad_flow_tests()


## The Hellfire cinematic runs for several seconds: wait until the level is won (or `cap_s`).
func _wait_won(l: Level, cap_s: float) -> void:
	var t: float = 0.0
	while t < cap_s and l.state != Level.State.WON:
		await _wait(0.25)
		t += 0.25


## Rewarded ads, interstitial pacing, second chance (+1 Rocky once), Hellfire, analytics privacy.
func _ad_flow_tests() -> void:
	print("-- ads, second chance, hellfire, analytics")
	var saved: Dictionary = Save.data.duplicate(true)
	Save.data["no_ads"] = false
	Save.data["iap"] = {}
	Save.data["sessions"] = 5
	Save.data["ad_matches"] = 0
	var every: int = int(Data.b("ads", "interstitial_every_matches"))
	for i: int in every - 1:
		Ads.match_played()
	_check(not Ads.interstitial_due(10), "no interstitial before %d matches" % every)
	_check(String(Data.b("settings", "privacy_url")) == "https://castle-smashers.pages.dev/privacy/", "privacy link points at the Pages site")
	_check(not Ads.privacy_options_required() and Ads.has_method("show_privacy_options"), "Ad Privacy entry hidden on desktop, API present")
	var admob_src: String = FileAccess.get_file_as_string("res://src/autoload/ads_admob.gd")
	_check(admob_src.contains("MAX_AD_CONTENT_RATING_T") and admob_src.contains("show_privacy_options_form"), "ads capped at T (no MA), privacy options form wired")
	var policy: String = FileAccess.get_file_as_string("res://web/privacy/index.html")
	_check(policy.is_empty() or (policy.contains("Intercore") and policy.contains("intercoreapp@gmail.com") and policy.contains("Ad Privacy")), "privacy page names the developer, contact and Ad Privacy")
	Ads.match_played()
	_check(Ads.interstitial_due(10) and not Ads.interstitial_due(int(Data.b("ads", "interstitial_min_level")) - 1),
			"interstitial is due after %d matches, never before the minimum level" % every)
	var went: Array = [false]
	Ads.match_break(10, func() -> void: went[0] = true)
	_check(went[0] and Ads.matches_since() == every, "a break always continues; with no ad shown the count is kept")
	var ad_ids: Array[String] = HeroAddons.ids()
	var ad_ok: bool = ad_ids.size() >= 5
	for aid: String in ad_ids:
		ad_ok = ad_ok and ResourceLoader.exists("res://assets/art/svg/addon_%s.svg" % aid) \
				and (Data.balance["shop"]["order"] as Array).has("addon_" + aid) and not HeroAddons.owns(aid)
	var rocky: Sprite2D = Projectile.make_sprite("stone")
	_check(ad_ok and rocky.get_child_count() == 0, "%d Rocky addons: art, Play products, nothing worn unless bought" % ad_ids.size())
	rocky.free()
	var hud_src: String = FileAccess.get_file_as_string("res://src/ui/hud.gd")
	_check(hud_src.count("Ads.match_break(") >= 5, "results Next/Retry/Map and pause Map/Restart are all ad breaks")
	Save.data["no_ads"] = true
	_check(not Ads.interstitial_due(10) and Ads.rewarded_ready(), "Remove Ads: no interstitial, bonuses still available")
	var got: Array = [""]
	var cb: Callable = func(id: String) -> void: got[0] = id
	Ads.rewarded_earned.connect(cb)
	Ads.show_rewarded("extra_rocky")
	await _wait(0.05)
	Ads.rewarded_earned.disconnect(cb)
	_check(got[0] == "extra_rocky", "Remove Ads grants ad bonuses instantly (no video)")
	Save.data["no_ads"] = false
	# Second chance: out of boulders opens the offer, +1 Rocky works once, then Hellfire wins.
	var l: Level = _make(1)
	await _wait(0.2)
	l.test_mode = false
	l.hero_index = l.heroes.size()
	l._out_of_heroes()
	_check(l.second_chance_open and l.state == Level.State.PLAY, "out of boulders opens the second chance (not a loss yet)")
	var n: int = l.heroes.size()
	l.second_chance_rocky()
	_check(not l.second_chance_open and l.heroes.size() == n + 1 and String(l.heroes[-1]) == "stone", "the ad gives exactly one extra Rocky")
	l.second_chance_open = true
	l.second_chance_rocky()
	_check(l.heroes.size() == n + 1, "the extra Rocky is only given once per attempt")
	Save.data["hellfire"] = 0
	_check(not l.use_hellfire(), "Hellfire cannot be used without owning a strike")
	Save.data["hellfire"] = 2
	l.test_mode = true
	_check(l.use_hellfire() and Save.amount("hellfire") == 1, "using Hellfire spends one strike")
	await _wait_won(l, 20.0)
	_check(l.state == Level.State.WON and l.blocks.is_empty() and l.archers.is_empty(), "Hellfire destroys every structure and wins the level")
	l.queue_free()
	await _wait(0.1)
	# Boss level: Hellfire also beats a shielded boss.
	var lb: Level = _make(10)
	await _wait(0.2)
	Save.data["hellfire"] = 1
	lb.use_hellfire()
	await _wait_won(lb, 20.0)
	_check(lb.state == Level.State.WON and lb.archers.is_empty(), "Hellfire beats a boss level too")
	lb.queue_free()
	await _wait(0.1)
	# Analytics: whitelisted names and keys only.
	Analytics.event("purchase_success", {"product_id": "coin_crate", "reward_amount": 30000, "email": "a@b.c", "purchase_token": "secret"})
	var p: Dictionary = Analytics.last("purchase_success")
	_check(p.has("product_id") and not p.has("email") and not p.has("purchase_token"), "analytics drops non-whitelisted (personal) fields")
	var before: int = Analytics.log.size()
	Analytics.event("made_up_event", {})
	_check(Analytics.log.size() == before, "analytics ignores unknown events")
	Save.data = saved
	Save.write()
	await _notification_tests()


func _play_services_tests() -> void:
	print("-- play review / updates, save backup, support")
	var rc: Dictionary = PlayServices.cfg("review")
	var now: int = int(Time.get_unix_time_from_system())
	var fresh: Dictionary = {"sessions": 5}
	_check(PlayServices.review_allowed(fresh, rc, 12, true, 3, now), "review is asked after a 3-star win past min_level")
	_check(not PlayServices.review_allowed(fresh, rc, 12, true, 2, now), "no review ask after a 2-star win")
	_check(not PlayServices.review_allowed(fresh, rc, 12, false, 0, now), "no review ask after a loss")
	_check(not PlayServices.review_allowed(fresh, rc, int(rc["min_level"]) - 1, true, 3, now), "no review ask on early levels")
	_check(not PlayServices.review_allowed({"sessions": 5, "review_last": now - 86400}, rc, 12, true, 3, now), "review asks are gap_days apart")
	_check(not PlayServices.review_allowed({"sessions": 5, "review_asks": int(rc["max_asks"])}, rc, 12, true, 3, now), "review is asked at most max_asks times")
	var uc: Dictionary = PlayServices.cfg("updates")
	_check(PlayServices.update_mode({}, uc, 9, 0, now) == "flexible", "a normal update is offered as a background download")
	_check(PlayServices.update_mode({}, uc, 9, int(uc["immediate_priority"]), now) == "immediate", "a high-priority update opens the blocking update screen")
	_check(PlayServices.update_mode({"update_asked": {"9": now - 600}}, uc, 9, 0, now) == "", "a declined update isn't offered again within ask_gap_hours")
	_check(PlayServices.update_mode({"update_asked": {"9": now - 600}}, uc, 10, 0, now) == "flexible", "a newer version is offered again")
	# Save backup: a damaged save.json loads the last good copy.
	Save.write()
	Save.write()
	_check(FileAccess.file_exists(Save.BACKUP), "every save keeps the previous one as save.json.bak")
	var good: Dictionary = Save._read(Save.BACKUP)
	var f: FileAccess = FileAccess.open(Save.PATH + ".testbroken", FileAccess.WRITE)
	f.store_string("{\"unlocked\": 12, \"coi")
	f.close()
	_check(Save._read(Save.PATH + ".testbroken") == null and good != null and good.has("unlocked"), "a cut-off save is detected as unreadable and the backup is readable")
	DirAccess.remove_absolute(Save.PATH + ".testbroken")
	for e: String in ["tutorial_begin", "level_quit", "purchase_start", "rewarded_ad_failed", "review_requested", "update_prompted"]:
		_check(Analytics.EVENTS.has(e), "analytics event %s is registered" % e)
	var mail: String = SettingsPopup.support_mailto()
	_check(mail.begins_with("mailto:intercoreapp@gmail.com?subject=") and mail.contains(String(ProjectSettings.get_setting("application/config/version", "")).uri_encode()), "Contact Support opens an email with the game version")
	_check(not Ads.showing(), "no full-screen ad is marked open at rest")
	# Auto-pause: leaving the app mid-level opens the pause menu.
	var lp: Level = _make(3)
	await _wait(0.3)
	lp.test_mode = false
	Ads._full_screen(true)
	lp._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not get_tree().paused, "no auto-pause while a full-screen ad has focus")
	Ads._full_screen(false)
	lp._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(get_tree().paused and lp.hud._popup != null, "leaving the app mid-level opens the pause menu")
	lp.hud.close_popup()
	get_tree().paused = false
	lp.test_mode = true
	lp.queue_free()
	await _wait(0.1)


func _notification_tests() -> void:
	print("-- notifications")
	var saved: Dictionary = Save.data.duplicate(true)
	var cfg: Dictionary = Notifications.cfg
	Save.data["spin_free"] = Save.today()
	Save.data["daily_last"] = Save.today()
	var now: int = int(Time.get_unix_time_from_system())
	var plan: Array = Notifications.plan(now)
	var kinds: Array = plan.map(func(n: Dictionary) -> String: return String(n["kind"]))
	_check(kinds.has("spin_ready") or kinds.has("daily_reward"), "a spin/daily reminder is planned after today's spin was used (%s)" % ", ".join(kinds))
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var qs: int = int(cfg["quiet_start_hour"])
	var qe: int = int(cfg["quiet_end_hour"])
	var days: Dictionary = {}
	var ok_quiet: bool = true
	var ok_text: bool = true
	for n: Dictionary in plan:
		var h: int = int(Time.get_datetime_dict_from_unix_time(int(n["at"]) + bias)["hour"])
		ok_quiet = ok_quiet and not (h >= qs or h < qe)
		var d: int = int(n["at"]) / 86400
		days[d] = int(days.get(d, 0)) + 1
		ok_text = ok_text and not String(n["title"]).contains("{") and not String(n["body"]).contains("{") and int(n["delay"]) > 0
	_check(ok_quiet, "no reminder is scheduled in quiet hours (%d-%d)" % [qs, qe])
	_check(days.values().all(func(c: int) -> bool: return c <= int(cfg["max_per_day"])), "at most %d reminder per day" % int(cfg["max_per_day"]))
	_check(ok_text, "every reminder has its placeholders filled")
	_check(kinds.has("idle_2d") or kinds.has("idle_5d"), "idle reminders are planned for players who stop playing")
	Save.data["spin_free"] = ""
	Save.data["daily_last"] = ""
	var fresh: Array = Notifications.plan(now).map(func(n: Dictionary) -> String: return String(n["kind"]))
	_check(not fresh.has("spin_ready") and not fresh.has("daily_reward"), "no spin/daily reminder while today's free one is still unclaimed")
	var a: Array = Notifications._pick("idle_2d", cfg["kinds"]["idle_2d"]["lines"])
	var b: Array = Notifications._pick("idle_2d", cfg["kinds"]["idle_2d"]["lines"])
	_check(a != b, "the same reminder line is never sent twice in a row")
	# Energy: a "refilled" reminder only after bars were spent, at the moment they are full again.
	Save.data["energy"] = {"bars": Energy.max_bars(), "t": Time.get_unix_time_from_system(), "ad_lock": false}
	_check(not Notifications.plan(now).any(func(n: Dictionary) -> bool: return n["kind"] == "energy_full"), "no energy reminder while the bars are full")
	var keep_unlocked: int = int(Save.data["unlocked"])
	Save.data["unlocked"] = int(Energy.cfg()["free_until_level"]) + 3
	Save.data["energy"] = {"bars": 0, "t": Time.get_unix_time_from_system(), "ad_lock": false}
	var en: Array = Notifications.plan(now).filter(func(n: Dictionary) -> bool: return n["kind"] == "energy_full")
	var want: int = maxi(int(cfg["kinds"]["energy_full"]["min_delay_s"]), ceili(Energy.ready_in_s(Energy.max_bars())))
	# Quiet hours may push it later, never earlier.
	_check(en.size() == 1 and int(en[0]["at"]) >= now + want - 2, "after spending energy, a refilled reminder is planned when every bar is back")
	Save.data["unlocked"] = keep_unlocked
	Notifications.set_enabled(false)
	_check(not Notifications.enabled(), "players can turn reminders off")
	await _play_services_tests()
	# Push (FCM via GodotX Firebase): topics exist, the backend loads, and the export preset ships
	# only Core + Messaging from GodotX (Analytics/Crashlytics come from CastleFirebase).
	var push: Dictionary = cfg.get("push", {})
	_check(not (push.get("topics", []) as Array).is_empty(), "push topics are configured")
	_check(load(Notifications.PUSH) is GDScript and not bool((load(Notifications.PUSH) as GDScript).new().call("available")),
			"push backend loads and stays off without the GodotX plugin (desktop)")
	_check(not Notifications.push_available(), "no push on desktop")
	var preset: ConfigFile = ConfigFile.new()
	preset.load("res://export_presets.cfg")
	var o: String = "preset.0.options"
	_check(bool(preset.get_value(o, "firebase/enable_core", false)) and bool(preset.get_value(o, "firebase/enable_messaging", false))
			and not bool(preset.get_value(o, "firebase/enable_analytics", true)) and not bool(preset.get_value(o, "firebase/enable_crashlytics", true)),
			"export ships GodotX Core + Messaging only")
	_check(String(preset.get_value(o, "launcher_icons/adaptive_monochrome_432x432", "")) != "", "notifications have a monochrome small icon")
	_check(FileAccess.file_exists("res://android/firebase_messaging/firebase_messaging.release.aar"), "GodotX Messaging AAR is vendored")
	Save.data = saved
	Save.write()


# ------------------------------------------------------------------------------------ audio
func _audio_names_in(dir_path: String, out: Dictionary) -> void:
	var re: RegEx = RegEx.new()
	re.compile("Sound\\.play(?:_at)?\\(\"([a-z_]+)\"")
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
	# Collapse layer: data-driven sounds exist, and a burst of breaks escalates once per tier.
	var col: Dictionary = Data.balance["audio"]["collapse"]
	var col_missing: Array = []
	for t: Dictionary in col["tiers"]:
		if not ResourceLoader.exists(Sound.SFX_DIR % [String(t["sound"]), 0]):
			col_missing.append(t["sound"])
	if not ResourceLoader.exists(Sound.SFX_DIR % [String(col["settle_sound"]), 0]):
		col_missing.append(col["settle_sound"])
	_check(col_missing.is_empty(), "collapse layer sounds exist %s" % [col_missing])
	Sound._fall.clear()
	Sound._fall_tier = -1
	var dummies: Array = []
	for i: int in 7:
		var dn: Node2D = Node2D.new()
		dn.position = Vector2(1200 + i * 20, -100)
		add_child(dn)
		dummies.append(dn)
		Sound._on_break(dn)
	_check(Sound._fall_tier == 1, "7 quick breaks = a medium collapse (tier %d)" % Sound._fall_tier)
	Sound._fall_last_ms -= 5000
	Sound._settle_fall()
	_check(Sound._fall_tier == -1 and Sound._fall.is_empty(), "the rubble tail ends the fall")
	for dn: Node2D in dummies:
		dn.queue_free()
	_check(int(Data.balance["audio"]["max_voices"]["wood_break"]) > 0, "per-material break voices are capped")
	var songs: Array = ["menu", "boss"]
	for r: Dictionary in Data.balance["realms"]:
		songs.append(String(r["key"]))
	var bad: Array = []
	for sg: String in songs:
		var sync: AudioStreamSynchronized = Sound._song_stream(sg)
		if sync == null or sync.stream_count != Sound.STEMS.size():
			bad.append(sg)
			continue
		var len0: float = sync.get_sync_stream(0).get_length()
		for i: int in sync.stream_count:
			var o: AudioStreamOggVorbis = sync.get_sync_stream(i) as AudioStreamOggVorbis
			if o == null or not o.loop or absf(o.get_length() - len0) > 0.002:
				bad.append("%s_%s" % [sg, Sound.STEMS[i]])
	_check(bad.is_empty(), "songs %s have 3 equal-length looping Ogg stems (base, action, climax) %s" % [songs, bad])
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
	_check(Sound._decks[0].player.playing and Sound._decks[0].song == "mines" and Sound._decks[0].player.stream is AudioStreamSynchronized, "the mines deck is playing its synchronized stems")
	# Climax layer: silent through ordinary destruction, rises only at the peak of a chain.
	Sound.music_state("destruction")
	Sound._energy = 0.3
	Sound._energy_hold = 5.0
	Sound._climax_db = Sound.SILENT_DB
	Sound._mix_music(0.5)
	var c_low: float = Sound._climax_db
	Sound._energy = 1.0
	for i: int in 10:
		Sound._mix_music(0.1)
	var c_high: float = Sound._climax_db
	var vol2: float = Sound._decks[0].sync.get_sync_stream_volume(2)
	_check(c_low <= Sound.SILENT_DB + 0.1 and c_high > -10.0 and absf(vol2 - c_high) < 0.01, "climax stem silent at low energy (%.0f dB), up at peak (%.1f dB) on the synced stream" % [c_low, c_high])
	Sound.music_state("result")
	Sound._energy = 0.0
	# Positional voices: a world sound with a 2D camera goes to an AudioStreamPlayer2D at its position.
	var cam_host: Node2D = Node2D.new()
	add_child(cam_host)
	var cam: Camera2D = Camera2D.new()
	cam_host.add_child(cam)
	cam.make_current()
	Sound._last_ms.erase("stone_hit")
	Sound.play_at("stone_hit", Vector2(321, -45), 0.8)
	var placed: AudioStreamPlayer2D = null
	for v: AudioStreamPlayer2D in Sound._pool_2d:
		if v.playing and v.global_position.is_equal_approx(Vector2(321, -45)):
			placed = v
	_check(placed != null and placed.bus == "SFX", "play_at uses a positional SFX voice at the world position")
	Sound._last_ms.erase("ui_tap")
	var busy_before: int = Sound._pool_2d.filter(func(v: AudioStreamPlayer2D) -> bool: return v.playing).size()
	Sound.play_at("ui_tap", Vector2(10, 10))
	var busy_after: int = Sound._pool_2d.filter(func(v: AudioStreamPlayer2D) -> bool: return v.playing).size()
	_check(busy_after == busy_before, "UI sounds never become positional")
	cam_host.queue_free()
	Sound.set_music("menu", "menu")
	Sound.set_surroundings("blossom", true)
