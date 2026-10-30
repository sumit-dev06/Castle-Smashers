class_name Block
extends RigidBody2D
## A destructible structure piece. Damage comes from velocity change (impulse) per physics step,
## which covers projectile hits, falling and being crushed, without per-contact bookkeeping.

var shape_id: String = ""
var mat_id: String = ""
var mat: Dictionary = {}
var size: Vector2 = Vector2.ONE
var hp: float = 1.0
var max_hp: float = 1.0
var stage: int = 0
var dead: bool = false
var level: Level = null
var start_pos: Vector2 = Vector2.ZERO
var start_rot: float = 0.0
var trigger_id: String = ""
var weak_point: bool = false
## Damage taken so far (after material scaling). Bolts break when it passes their limit.
var damage_total: float = 0.0
## Held by a rope (frozen, moved by its mechanism) until the rope is cut.
var held: bool = false
## Seconds left as a crushing load (released rope loads): it smashes what it falls on.
var crushing: float = 0.0
var _crushed: Dictionary = {}
var _crush_speed: float = 0.0
## Not crushed by this load (the seesaw beam that throws it).
var crush_ignore: Node
var _crush_partners: Array[Block] = []
## Iron beam bent into a V by a hard hit (shape swapped to its "bent" shape).
var bent: bool = false
## Rune crystal beam direction in degrees, relative to the block (0 = right).
var rune_dir: float = 0.0

var _damage_taken_mult: float = 1.0

var _sprite: Sprite2D
var _flame: Sprite2D
var _prev_vel: Vector2 = Vector2.ZERO
## Seconds of no impact damage (a thrown payload leaving the beam).
var _grace: float = 0.0
var _gravity: Vector2 = Vector2.ZERO
var _burn_left: float = 0.0
var _spread_t: float = 0.0
var _spread_done: bool = false
var _min_impulse: float = 0.0
var _per_impulse: float = 0.0
var _projectile_bonus: float = 0.0
var _splashed: bool = false
var _melt_left: float = 0.0
var _hot_left: float = 0.0
var _glow: Sprite2D
var _rune_charge: float = 0.0
var _rune_cool: float = 0.0
var _rune_mark: Sprite2D


func setup(p_shape_id: String, p_level: Level, pos: Vector2, rot_deg: float, decor: Dictionary = {}) -> void:
	shape_id = p_shape_id
	level = p_level
	var shape: Dictionary = Data.shapes[shape_id]
	mat_id = String(shape["material"])
	mat = Data.materials[mat_id]
	size = Vector2(float(shape["size"][0]), float(shape["size"][1]))
	max_hp = float(mat["hp"])
	weak_point = bool(decor.get("weak_point", false))
	trigger_id = String(decor.get("trigger", ""))
	if weak_point:
		max_hp *= Data.bf("mechanics", "weak_hp_mult")
		_damage_taken_mult = Data.bf("mechanics", "weak_damage_mult")
	hp = max_hp
	rune_dir = float(decor.get("dir", 0.0))
	position = pos
	rotation_degrees = rot_deg
	start_pos = pos
	start_rot = rotation
	var area: float = size.x * size.y
	_build_collider(shape)
	if String(shape["collider"]) == "circle":
		area *= PI / 4.0
	elif String(shape["collider"]) == "triangle":
		area *= 0.5
	mass = float(mat["density"]) * area / 1000.0
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = float(mat["friction"])
	pm.bounce = float(mat["bounce"])
	physics_material_override = pm
	linear_damp = Data.bf("physics", "block_linear_damp")
	angular_damp = Data.bf("physics", "block_angular_damp")
	collision_layer = int(Data.b("layers", "blocks"))
	collision_mask = int(Data.b("layers", "world")) | int(Data.b("layers", "blocks")) \
			| int(Data.b("layers", "projectiles")) | int(Data.b("layers", "archers"))
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = true
	sleeping = true
	_sprite = Art.sprite(_tex_name())
	add_child(_sprite)
	if mat.has("rune"):
		_rune_mark = Art.sprite("rune_arrow", 0.62)
		_rune_mark.rotation_degrees = rune_dir
		_rune_mark.position = Vector2.from_angle(deg_to_rad(rune_dir)) * minf(size.x, size.y) * 0.18
		_rune_mark.z_index = 3
		add_child(_rune_mark)
		var shine: Tween = _rune_mark.create_tween().set_loops()
		shine.tween_property(_rune_mark, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)
		shine.tween_property(_rune_mark, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	_finish_setup(decor)


## Builds the collision shape(s) for a shape entry. "v" is a bent beam: two half plates meeting
## in a joint below the centre (matches the SVG drawn by gen_art.py iron_bent_block).
func _build_collider(shape: Dictionary) -> void:
	for c: Node in get_children():
		if c is CollisionShape2D:
			remove_child(c)
			c.queue_free()
	var kind: String = String(shape["collider"])
	if kind == "v":
		var t: float = deg_to_rad(float(mat["bend"]["angle_deg"]))
		var a: float = size.x * 0.25 * cos(t)
		var dd: float = size.x * 0.25 * sin(t)
		for side: float in [-1.0, 1.0]:
			var half: CollisionShape2D = CollisionShape2D.new()
			var hr: RectangleShape2D = RectangleShape2D.new()
			hr.size = Vector2(size.x * 0.5, size.y)
			half.shape = hr
			half.position = Vector2(side * a, dd)
			half.rotation = -side * t
			add_child(half)
		return
	var col: CollisionShape2D = CollisionShape2D.new()
	if kind == "circle":
		var circ: CircleShape2D = CircleShape2D.new()
		circ.radius = size.x * 0.5
		col.shape = circ
	elif kind == "triangle":
		var poly: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
		poly.points = PackedVector2Array([Vector2(-size.x / 2, size.y / 2), Vector2(0, -size.y / 2),
				Vector2(size.x / 2, size.y / 2)])
		col.shape = poly
	else:
		var r: RectangleShape2D = RectangleShape2D.new()
		r.size = size
		col.shape = r
	add_child(col)


func _finish_setup(decor: Dictionary) -> void:
	if weak_point:
		var weak_mark: Sprite2D = Art.sprite("weak_point", clampf(minf(size.x, size.y) / 64.0, 0.55, 1.0))
		weak_mark.z_index = 3
		add_child(weak_mark)
		var pulse: Tween = weak_mark.create_tween().set_loops()
		pulse.tween_property(weak_mark, "modulate", Color(1.35, 1.35, 1.1), 0.55).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(weak_mark, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)
	if bool(decor.get("scroll", false)):
		set_meta("scroll", true)
		var sc: Sprite2D = Art.sprite("blueprint", 0.5)
		sc.position = Vector2(size.x * 0.22, -size.y * 0.22)
		sc.rotation = 0.3
		sc.modulate = Color(1, 1, 1, 0.85)
		sc.z_index = 1
		add_child(sc)
	if bool(decor.get("flag", false)):
		var fl: Sprite2D = Art.sprite("flag")
		fl.centered = false
		fl.offset = Vector2(-5, -80) / Art.SVG_SCALE
		fl.position = Vector2(0, -size.y / 2.0 + 6.0)
		fl.z_index = -1
		add_child(fl)
		var tw: Tween = fl.create_tween().set_loops()
		tw.tween_property(fl, "skew", 0.12, 0.7 + randf() * 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fl, "skew", -0.06, 0.7 + randf() * 0.3).set_trans(Tween.TRANS_SINE)
	if bool(decor.get("banner", false)):
		var bn: Sprite2D = Art.sprite("banner")
		bn.centered = false
		bn.offset = Vector2(-22, 0) / Art.SVG_SCALE
		bn.position = Vector2(0, size.y / 2.0 - 4.0)
		bn.z_index = -1
		add_child(bn)
	_gravity = Vector2.DOWN * float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	_min_impulse = Data.bf("damage", "min_impulse")
	_per_impulse = Data.bf("damage", "per_impulse")
	_projectile_bonus = Data.bf("damage", "projectile_bonus")


func _tex_name() -> String:
	return "block_%s_%d" % [shape_id, stage]


func _physics_process(delta: float) -> void:
	if dead:
		return
	var v: Vector2 = linear_velocity
	if not sleeping:
		var dv: Vector2 = v - _prev_vel - _gravity * delta
		var impulse: float = mass * dv.length()
		if _grace > 0.0:
			_grace -= delta
		elif impulse > _min_impulse:
			var mult: float = 1.0
			for body: Node in get_colliding_bodies():
				if body is Projectile:
					mult = _projectile_bonus * (body as Projectile).material_mult(mat_id)
					break
			level.on_impact(self, impulse, mult > 1.0)
			if level.damage_enabled():
				take_damage((impulse - _min_impulse) * _per_impulse * mult)
	_prev_vel = v
	if crushing > 0.0:
		_tick_crush(delta, v)
	if _burn_left > 0.0:
		_tick_fire(delta)
	if _melt_left > 0.0:
		_tick_melt(delta)
	if _hot_left > 0.0:
		_tick_heat(delta)
	if _rune_cool > 0.0:
		_rune_cool -= delta
	if _rune_charge > 0.0:
		_rune_charge -= delta
		if _rune_charge <= 0.0:
			_rune_cool = float(mat["rune"]["cooldown_s"])
			_sprite.modulate = Color.WHITE
			level.rune_beam(self)
	if dead:
		return
	_check_gap()


## Thrown by a contraption: sets the velocity without counting it as an impact.
func throw(v: Vector2, spin: float) -> void:
	freeze = false
	sleeping = false
	linear_velocity = v
	angular_velocity = spin
	_prev_vel = v
	_grace = Data.bf("tethers", "launch_grace_s")


## Starts crushing (Level/CastleMechanism call this when the rope holding it is cut).
func start_crush() -> void:
	crushing = float(Data.b("ropes", "crush")["active_s"])
	_crushed.clear()
	_crush_speed = 0.0
	# Pieces bolted to the load ride with it (a cart's powder barrels) and blow when it hits.
	_crush_partners.clear()
	for bolt: Bolt in level.bolts:
		if is_instance_valid(bolt) and not bolt.broken and (bolt.a == self or bolt.b == self):
			var other: Block = bolt.b if bolt.a == self else bolt.a
			if is_instance_valid(other):
				_crush_partners.append(other)
				_crushed[other] = true


func _tick_crush(delta: float, v: Vector2) -> void:
	crushing -= delta
	var c: Dictionary = Data.b("ropes", "crush")
	var touching: Array[Node2D] = get_colliding_bodies()
	# The contact itself stops the load, so use the fastest speed it reached in free fall.
	_crush_speed = maxf(_crush_speed * 0.9, v.length()) if not touching.is_empty() else maxf(_crush_speed, v.length())
	var spd: float = _crush_speed
	if Game.args.has("debug-crush") and not touching.is_empty():
		print("CRUSH %s spd %.0f touching %s ignore %s" % [shape_id, spd, touching.map(func(n: Node2D) -> String: return (n as Block).shape_id if n is Block else n.get_class()), crush_ignore])
	if spd < float(c["min_speed"]):
		return
	var struck: bool = false
	for body: Node in touching:
		if _crushed.has(body) or not is_instance_valid(body) or body == crush_ignore:
			continue
		_crushed[body] = true
		struck = struck or body is Block or body is Archer or (body is StaticBody2D and bool(mat["explodes"]))
		if body is Block and not (body as Block).dead:
			var tb: Block = body
			tb.push(v.normalized() * spd * mass * float(c["push_mult"]) / maxf(1.0, tb.mass) * 0.1)
			tb.take_damage(spd * float(c["damage_per_speed"]) * mass / 8.0)
		elif body is Archer:
			(body as Archer).take_damage(spd * float(c["archer_damage_per_speed"]))
	if struck:
		level.camera.add_shake(minf(18.0, spd * 0.02))
		for partner: Block in _crush_partners:
			if is_instance_valid(partner) and not partner.dead and bool(partner.mat["explodes"]):
				partner.set_meta("blast_mult", Data.bf("tethers", "launch_blast_mult"))
				partner.destroy(true)
		if bool(mat["explodes"]):
			crushing = 0.0
			destroy(true)


## Knocked into the gap: splash at the surface, then breaks (scored) under the kill line.
func _check_gap() -> void:
	var y: float = global_position.y
	if not _splashed and y > level.surface_line():
		_splashed = true
		level.splash(global_position, maxf(size.x, size.y))
	if y > level.kill_line():
		destroy(true)


## Applies an impulse without counting it as impact damage on the next step.
func push(impulse: Vector2) -> void:
	sleeping = false
	apply_central_impulse(impulse)
	_prev_vel += impulse / mass


func take_damage(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	var dealt: float = amount * float(mat["damage_mult"]) * _damage_taken_mult
	if _hot_left > 0.0:
		dealt *= float(mat["heat"]["damage_mult"])
	if not bent and mat.has("bend") and Data.shapes[shape_id].has("bent") \
			and dealt >= max_hp * float(mat["bend"]["hit_frac"]) and dealt < hp:
		bend()
	hp -= dealt
	damage_total += dealt
	level.on_block_damaged(self)
	if hp <= 0.0:
		destroy(true)
		return
	var new_stage: int = 0 if hp > max_hp * 0.66 else (1 if hp > max_hp * 0.33 else 2)
	if new_stage != stage:
		stage = new_stage
		_sprite.texture = Art.tex(_tex_name())
		if Art.resolve(_tex_name()) != _tex_name():
			# One AI image for every stage: show damage by darkening it instead.
			_sprite.self_modulate = Color.WHITE.darkened(Data.bf("damage", "ai_stage_darken") * stage)
	_sprite.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func destroy(scored: bool) -> void:
	if dead:
		return
	dead = true
	level.on_block_destroyed(self, scored)
	queue_free()


func is_burning() -> bool:
	return _burn_left > 0.0


func ignite(seconds: float) -> void:
	if dead:
		return
	if absorb("fire"):
		return
	if mat.has("melt_dps"):
		if _melt_left <= 0.0:
			Sound.play("sizzle", 0.6)
		_melt_left = maxf(_melt_left, seconds)
		return
	if mat.has("heat"):
		if _hot_left <= 0.0:
			Sound.play("sizzle", 0.7)
			_glow = Art.sprite("heat_glow", maxf(size.x, size.y) / 46.0)
			_glow.scale.y = _glow.scale.x * clampf(minf(size.x, size.y) / maxf(size.x, size.y) * 1.6, 0.35, 1.0)
			var add: CanvasItemMaterial = CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_glow.material = add
			_glow.z_index = 1
			add_child(_glow)
			level.on_block_heated(self)
		_hot_left = maxf(_hot_left, float(mat["heat"]["seconds"]))
		return
	if not bool(mat["flammable"]):
		return
	if _burn_left <= 0.0:
		_flame = Art.sprite("flame", clampf(minf(size.x, size.y) / 30.0, 0.8, 1.6))
		_flame.offset = Vector2(0, -60)
		_flame.z_index = 2
		add_child(_flame)
		Sound.play("fire", 0.5)
	_burn_left = maxf(_burn_left, seconds)
	_spread_t = 0.0
	_spread_done = false


func _tick_fire(delta: float) -> void:
	_burn_left -= delta
	hp -= Data.bf("fire", "burn_dps") * delta
	if _flame:
		_flame.rotation = -rotation
		var flick: float = 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.025 + position.x)
		_flame.scale.y = _flame.scale.x * flick
		_sprite.modulate = Color(1.0, 0.8, 0.65)
	if hp <= 0.0:
		destroy(true)
		return
	_spread_t += delta
	if not _spread_done and _spread_t > Data.bf("fire", "spread_s"):
		_spread_done = true
		level.spread_fire(self)
	if _burn_left <= 0.0 and _flame:
		_flame.queue_free()
		_flame = null
		_sprite.modulate = Color(0.8, 0.7, 0.65)


## Ice melts under fire: steady damage and steam, no flames and no spreading.
func _tick_melt(delta: float) -> void:
	_melt_left -= delta
	hp -= float(mat["melt_dps"]) * delta
	_sprite.modulate = Color(0.85, 0.95, 1.15)
	if randf() < delta * 6.0:
		level.fx.puff(global_position + Vector2(randf_range(-size.x, size.x) * 0.4, -size.y * 0.4), 1,
				Color(1, 1, 1, 0.6), 0.6)
	if hp <= 0.0:
		destroy(true)
	elif _melt_left <= 0.0:
		_sprite.modulate = Color.WHITE


## Red-hot iron: glows and takes extra damage until it cools.
func _tick_heat(delta: float) -> void:
	_hot_left -= delta
	var k: float = clampf(_hot_left / float(mat["heat"]["seconds"]), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	var heat: float = minf(1.0, k * 2.0)
	_sprite.modulate = Color.WHITE.lerp(Color(1.9, 0.85, 0.45), heat * (0.75 + 0.25 * pulse))
	if _glow:
		_glow.modulate.a = (0.6 + 0.3 * pulse) * heat
	if _hot_left <= 0.0:
		_sprite.modulate = Color.WHITE
		if _glow:
			_glow.queue_free()
			_glow = null


func is_hot() -> bool:
	return _hot_left > 0.0


func is_melting() -> bool:
	return _melt_left > 0.0


## Hard hit on a bendable iron beam: it folds into a V (new sprite and collider) and stays bent.
func bend() -> void:
	if bent or dead:
		return
	bent = true
	shape_id = String(Data.shapes[shape_id]["bent"])
	_sprite.texture = Art.tex(_tex_name())
	_sprite.scale = Art.base_scale(_tex_name())
	_build_collider.call_deferred(Data.shapes[shape_id])
	level.on_block_bent(self)


## Rune crystals swallow blasts, fire, quakes and beams, then fire their own beam after a short
## charge. Returns true when this block absorbed the energy (callers then skip its damage).
func absorb(_kind: String) -> bool:
	if dead or not mat.has("rune"):
		return false
	if _rune_charge > 0.0 or _rune_cool > 0.0:
		return true
	_rune_charge = float(mat["rune"]["charge_s"])
	sleeping = false
	_sprite.modulate = Color(1.7, 1.4, 2.0)
	Sound.play("rune_charge", 0.8)
	return true


func is_rune() -> bool:
	return mat.has("rune")


## World direction of the rune beam (follows the block's rotation).
func beam_dir() -> Vector2:
	return Vector2.from_angle(global_rotation + deg_to_rad(rune_dir))


func is_weak_point() -> bool:
	return weak_point


func speed() -> float:
	return linear_velocity.length()
