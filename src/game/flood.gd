class_name Flood
extends Node2D
## Water held in a pool behind a sluice gate (owned by a "flood" CastleMechanism, local origin at the
## gate's foot). Once the gate opens, a wave runs `reach` px downstream: it pushes everything in the
## water, floats light timber (buoyancy by material density) and drowns guards it covers.
## Tunables: balance.json "flood". Level data: "pool" (px upstream), "reach", "depth", "pool_h".

var level: Level
var cfg: Dictionary = {}
var flowing: bool = false
var _t: float = 0.0
var _front: float = 0.0
var _water: Polygon2D
var _pool: Polygon2D
var _foam: Line2D
var _splash_t: float = 0.0
var _g: float = 980.0


func setup(p_level: Level, data: Dictionary) -> void:
	level = p_level
	cfg = data


func _ready() -> void:
	_g = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	var c: Dictionary = Data.balance["flood"]
	var col: Color = Color(String(c["color"]))
	_pool = Polygon2D.new()
	_pool.color = col
	_pool.z_index = 0
	add_child(_pool)
	_water = Polygon2D.new()
	_water.color = col
	_water.z_index = 3
	add_child(_water)
	_foam = Line2D.new()
	_foam.width = float(c["foam_width"])
	_foam.default_color = Color(String(c["foam_color"]))
	_foam.z_index = 4
	add_child(_foam)
	# Stone lip at the upstream end of the pool.
	var lip: Sprite2D = Art.sprite("block_stone_pillar_0")
	var ls: Vector2 = Art.svg_size("block_stone_pillar_0")
	var lip_size: Vector2 = Vector2(36, pool_h() + 20.0)
	lip.scale *= Vector2(lip_size.x / ls.x, lip_size.y / ls.y)
	lip.position = Vector2(-pool_w() - lip_size.x * 0.5, -lip_size.y * 0.5)
	add_child(lip)
	_redraw()


func pool_w() -> float:
	return float(cfg.get("pool", 260.0))


func pool_h() -> float:
	return float(cfg.get("pool_h", 150.0))


func reach() -> float:
	return float(cfg.get("reach", 700.0))


## Current flood depth (0 before the gate opens and after the water drains).
func depth() -> float:
	if not flowing:
		return 0.0
	var c: Dictionary = Data.balance["flood"]
	var d: float = float(cfg.get("depth", c["depth"]))
	var rise: float = float(c["rise_s"])
	var hold: float = float(c["hold_s"])
	var drain: float = float(c["drain_s"])
	if _t < rise:
		return d * smoothstep(0.0, rise, _t)
	if _t < rise + hold:
		return d
	return d * (1.0 - smoothstep(rise + hold, rise + hold + drain, _t))


func release() -> void:
	if flowing:
		return
	flowing = true
	_t = 0.0
	Sound.play_at("splash", global_position, 1.0)
	Sound.play_at("gate_drop", global_position, 0.7)


func _physics_process(delta: float) -> void:
	if not flowing:
		return
	_t += delta
	var c: Dictionary = Data.balance["flood"]
	_front = minf(reach(), _front + float(c["speed"]) * delta)
	var d: float = depth()
	if d > 1.0:
		_soak(delta, d, c)
	_splash_t -= delta
	if _splash_t <= 0.0 and d > 4.0 and _front < reach():
		_splash_t = float(c["splash_every_s"])
		level.fx.puff(to_global(Vector2(_front, -d)), 3, Color(String(c["foam_color"])), 0.6)
	_redraw()


## Pushes, floats and drowns what stands in the water.
func _soak(delta: float, d: float, c: Dictionary) -> void:
	var x0: float = global_position.x
	var x1: float = x0 + _front
	var surface: float = global_position.y - d
	var push: float = float(c["push_accel"])
	var drag: float = float(c["drag"])
	for b: Block in level.blocks:
		if not is_instance_valid(b) or b.dead or b.held or b.freeze:
			continue
		var p: Vector2 = b.global_position
		if p.x < x0 or p.x > x1:
			continue
		var half: float = b.size.y * 0.5
		var f: float = clampf((p.y + half - surface) / maxf(1.0, b.size.y), 0.0, 1.0)
		if f <= 0.0:
			continue
		var buoy: float = clampf(1.0 / maxf(0.1, float(b.mat["density"])), 0.0, float(c["max_buoyancy"]))
		var force: Vector2 = Vector2(push, -_g * buoy) * f - b.linear_velocity * drag * f
		b.sleeping = false
		b.apply_central_force(force * b.mass)
	for a: Archer in level.archers:
		if not is_instance_valid(a) or a.dead:
			continue
		var q: Vector2 = a.global_position
		if q.x < x0 or q.x > x1 or q.y + float(c["archer_half_h"]) < surface:
			continue
		a.sleeping = false
		a.apply_central_force((Vector2(push, -_g * float(c["archer_buoyancy"])) - a.linear_velocity * drag) * a.mass)
		a.take_damage(float(c["drown_dps"]) * delta)


func _redraw() -> void:
	var d: float = depth()
	var ph: float = pool_h()
	if flowing:
		var rise: float = float(Data.balance["flood"]["rise_s"])
		ph = lerpf(ph, 0.0, smoothstep(0.0, rise * 1.6, _t))
	_pool.polygon = PackedVector2Array([Vector2(-pool_w(), 0), Vector2(-pool_w(), -ph), Vector2(0, -ph), Vector2(0, 0)])
	if d <= 0.5 or _front <= 0.0:
		_water.visible = false
		_foam.points = PackedVector2Array([Vector2(-pool_w(), -ph), Vector2(0, -ph)])
		return
	_water.visible = true
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 14
	var wave: float = float(Data.balance["flood"]["wave_px"])
	for i: int in steps + 1:
		var x: float = _front * float(i) / float(steps)
		var y: float = -d - sin(_t * 5.0 + x * 0.03) * wave * minf(1.0, d / 30.0)
		if i == steps:
			y = -d * 0.6
		pts.append(Vector2(x, y))
	_foam.points = pts
	var poly: PackedVector2Array = pts.duplicate()
	poly.append(Vector2(_front + d * 0.5, 0))
	poly.append(Vector2(0, 0))
	_water.polygon = poly
