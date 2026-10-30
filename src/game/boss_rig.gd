class_name BossRig
extends Node2D
## Boss stages: disable the defences, expose the core, finish the boss.
##   power cores  ("power_core" blocks, material "core"): while any stands the boss is shielded.
##   cannons      ("cannon_turret" blocks): fire cannonballs at soldiers; toppled cannons stop firing.
##   engineers    (level JSON "engineers": [{x, y}]): rebuild broken fortress blocks every repair_s.
##   armor        shield_ring mechanisms (orbiting plates) are counted for the boss bar.
## Tunables: data/balance.json -> boss_rig. Built by Level when a level has any of these.

signal status_changed

var level: Level
var cores: Array[Block] = []
var cannons: Array[Block] = []
var engineers: Array[Archer] = []
var cores_total: int = 0
var cannons_total: int = 0
var engineers_total: int = 0
var core_down: bool = false
var repairs: int = 0
var shots: int = 0

var _cool: Dictionary = {}
var _repair_t: Dictionary = {}
var _queue: Array[Dictionary] = []
var _glows: Dictionary = {}
var _t: float = 0.0


static func wanted(lv: Level) -> bool:
	if not lv.data.get("engineers", []).is_empty():
		return true
	for b: Block in lv.blocks:
		if b.mat_id in ["core", "cannon"]:
			return true
	return false


func setup(p_level: Level) -> void:
	level = p_level
	for b: Block in level.blocks:
		if b.mat_id == "core":
			cores.append(b)
			var g: Sprite2D = Art.sprite("core_glow", maxf(b.size.x, b.size.y) / 52.0)
			g.material = CanvasItemMaterial.new()
			(g.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			g.z_index = 2
			b.add_child(g)
			_glows[b] = g
		elif b.mat_id == "cannon":
			cannons.append(b)
			_cool[b] = Data.bf("boss_rig", "cannon_first_s") + randf() * 1.5
	for e: Variant in level.data.get("engineers", []):
		var a: Archer = level.spawn_archer(Vector2(float(e["x"]), float(e["y"])))
		a.make_engineer()
		engineers.append(a)
		_repair_t[a] = Data.bf("boss_rig", "repair_s")
	cores_total = cores.size()
	cannons_total = cannons.size()
	engineers_total = engineers.size()
	if cores_total > 0 and is_instance_valid(level.boss):
		level.boss.lock_shield(true)


func tick(delta: float) -> void:
	_t += delta
	var k: float = 0.5 + 0.5 * sin(_t * TAU * Data.bf("boss_rig", "glow_hz"))
	for b: Block in cores:
		if is_instance_valid(b) and _glows.has(b):
			(_glows[b] as Sprite2D).modulate.a = 0.45 + 0.55 * k
	if level._living_soldiers().is_empty():
		return
	for c: Block in cannons:
		if not is_instance_valid(c) or c.dead:
			continue
		if absf(wrapf(c.rotation, -PI, PI)) > 0.6 or c.speed() > Data.bf("archers", "busy_speed"):
			continue
		_cool[c] = float(_cool[c]) - delta
		if float(_cool[c]) <= 0.0:
			_cool[c] = randf_range(Data.bf("boss_rig", "cannon_fire_min_s"), Data.bf("boss_rig", "cannon_fire_max_s"))
			_fire(c)
	for e: Archer in engineers:
		if not is_instance_valid(e) or e.dead:
			continue
		_repair_t[e] = float(_repair_t[e]) - delta
		if float(_repair_t[e]) <= 0.0:
			_repair_t[e] = Data.bf("boss_rig", "repair_s")
			_repair(e)


func muzzle(c: Block) -> Vector2:
	return c.to_global(Vector2(-c.size.x * 0.5, -c.size.y * 0.15))


func _fire(c: Block) -> void:
	var living: Array[Soldier] = level._living_soldiers()
	var target: Soldier = living[randi() % living.size()]
	var spread: float = Data.bf("boss_rig", "cannon_aim_spread_px")
	var ball: Arrow = Arrow.new()
	level.world.add_child(ball)
	ball.setup(muzzle(c), target.body_center() + Vector2(randf_range(-spread, spread), 0),
			Data.bf("boss_rig", "cannon_flight_s"), level.soldiers, level.stage, "cannonball", int(Data.b("boss_rig", "cannon_hits")))
	level.fx.puff(muzzle(c), 5, Color(0.85, 0.85, 0.85, 0.9), 0.9)
	level.fx.flash(muzzle(c), 40.0)
	c.push(Vector2(260, -40))
	shots += 1
	Sound.play("cannon", 0.85)


## Fortress blocks broken near a living engineer are queued for rebuilding.
func on_block_destroyed(b: Block) -> void:
	if b in cores:
		cores.erase(b)
		if cores.is_empty() and not core_down:
			_all_cores_down(b.global_position)
		status_changed.emit()
		return
	if b in cannons:
		cannons.erase(b)
		status_changed.emit()
		return
	if b.held or b.mat_id in ["core", "cannon"] or not _engineer_near(b.start_pos):
		return
	_queue.append({"shape": b.shape_id, "pos": b.start_pos, "rot": rad_to_deg(b.start_rot)})


func on_archer_defeated(a: Archer) -> void:
	if a in engineers:
		engineers.erase(a)
		status_changed.emit()


func _engineer_near(p: Vector2) -> bool:
	for e: Archer in engineers:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(p) < Data.bf("boss_rig", "repair_radius"):
			return true
	return false


func _spot_clear(shape: String, p: Vector2) -> bool:
	var sz: Vector2 = Vector2(float(Data.shapes[shape]["size"][0]), float(Data.shapes[shape]["size"][1]))
	for b: Block in level.blocks:
		if is_instance_valid(b) and not b.dead:
			var r: float = (maxf(sz.x, sz.y) + maxf(b.size.x, b.size.y)) * 0.32
			if b.global_position.distance_to(p) < r:
				return false
	for a: Archer in level.archers:
		if is_instance_valid(a) and a.global_position.distance_to(p) < maxf(sz.x, sz.y) * 0.5 + 30.0:
			return false
	return true


func _repair(e: Archer) -> void:
	var best: int = -1
	var best_d: float = INF
	for i: int in _queue.size():
		var q: Dictionary = _queue[i]
		var d: float = e.global_position.distance_to(q["pos"])
		if d < Data.bf("boss_rig", "repair_radius") and d < best_d and _spot_clear(String(q["shape"]), _home(q["pos"])):
			best = i
			best_d = d
	if best < 0:
		return
	var q2: Dictionary = _queue[best]
	_queue.remove_at(best)
	var b: Block = level.spawn_block(String(q2["shape"]), _home(q2["pos"]))
	b.rotation_degrees = float(q2["rot"])
	b.sleeping = true
	b.modulate = Color(1.6, 1.5, 1.0, 0.0)
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "modulate", Color.WHITE, Data.bf("boss_rig", "repair_pop_s"))
	repairs += 1
	e.swing_hammer()
	level.fx.beam(e.global_position + Vector2(0, -30), b.global_position, 10.0)
	level.fx.sparks(b.global_position, 10)
	level.fx.float_text(b.global_position, "REPAIRED!", Color("#ffb04a"), 26)
	Sound.play("repair", 0.9)
	status_changed.emit()


## Where a block built at `start` sits now: blocks on a moving deck move with it.
func _home(start: Vector2) -> Vector2:
	for m: CastleMechanism in level.mechanisms:
		if is_instance_valid(m) and m.kind == "moving_platform" and m.body:
			var half: float = float(m.cfg["size"][0]) * 0.5
			if absf(start.x - m.global_position.x) < half + 10.0 and start.y < m.global_position.y:
				return start + m.body.position
	return start


func _all_cores_down(at: Vector2) -> void:
	core_down = true
	level.on_core_down(at)


func armor_left() -> int:
	var n: int = 0
	for m: CastleMechanism in level.mechanisms:
		if is_instance_valid(m) and m.kind == "shield_ring" and not m.jammed:
			n += 1
	return n


func armor_total() -> int:
	var n: int = 0
	for m: CastleMechanism in level.mechanisms:
		if is_instance_valid(m) and m.kind == "shield_ring":
			n += 1
	return n


func _alive(list: Array) -> int:
	var n: int = 0
	for x: Variant in list:
		if is_instance_valid(x) and not x.dead:
			n += 1
	return n


## For the boss bar: kind -> [left, total]; kinds with total 0 are left out.
func status() -> Dictionary:
	var out: Dictionary = {}
	if cores_total > 0:
		out["core"] = [_alive(cores), cores_total]
	if armor_total() > 0:
		out["armor"] = [armor_left(), armor_total()]
	if cannons_total > 0:
		out["cannon"] = [_alive(cannons), cannons_total]
	if engineers_total > 0:
		out["engineer"] = [_alive(engineers), engineers_total]
	return out
