class_name Archer
extends RigidBody2D
## Enemy Redcap Archer. Physics body that can fall and be crushed; shoots arrows on the enemy turn.

var hp: float = 1.0
var dead: bool = false
var level: Level = null
var start_pos: Vector2 = Vector2.ZERO

var _sprite: Sprite2D
var _shadowless_bob: float = 0.0
var _prev_vel: Vector2 = Vector2.ZERO
var _gravity: Vector2 = Vector2.ZERO
var _burn_left: float = 0.0
var _flame: Sprite2D
var _blink_t: float = 0.0
var _h: float = 80.0
var _base_scale: float = 1.0
## Seconds until the next arrow (Level drives this).
var cooldown: float = 0.0
var drawing: bool = false
var _splashed: bool = false
## Boss Warlord: big crowned archer with lots of HP; phases are run by the Level.
var is_boss: bool = false
var max_hp: float = 1.0
var boss_name: String = ""
var shield_left: float = 0.0
var _shield: Sprite2D
var _tint: Color = Color.WHITE
## Engineer (boss rig): never shoots, rebuilds broken blocks.
var is_engineer: bool = false
var _hammer: Sprite2D
## "archer", or "boss_warlord" etc. when a boss has its own AI poses.
var _pose_prefix: String = "archer"


func setup(p_level: Level, pos: Vector2) -> void:
	level = p_level
	position = pos
	start_pos = pos
	hp = Data.bf("archers", "hp")
	mass = Data.bf("archers", "mass")
	var sz: Vector2 = Data.vec("archers", "size")
	var col: CollisionShape2D = CollisionShape2D.new()
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = sz
	col.shape = r
	add_child(col)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = Data.bf("archers", "friction")
	pm.bounce = 0.05
	physics_material_override = pm
	angular_damp = Data.bf("physics", "block_angular_damp")
	collision_layer = int(Data.b("layers", "archers"))
	collision_mask = int(Data.b("layers", "world")) | int(Data.b("layers", "blocks")) \
			| int(Data.b("layers", "projectiles")) | int(Data.b("layers", "archers"))
	contact_monitor = true
	max_contacts_reported = 4
	sleeping = true
	_h = Data.bf("archers", "visual_height")
	_sprite = Art.unit_sprite("archer_idle", _h)
	_sprite.position.y = sz.y / 2.0
	_base_scale = _sprite.scale.x
	add_child(_sprite)
	_gravity = Vector2.DOWN * float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	_shadowless_bob = randf() * TAU
	max_hp = hp


## Highest world y of what is drawn for this unit (head, boss crown and shield bubble).
func visual_top() -> float:
	var top: float = _sprite.position.y - _h * (Data.bf("boss", "scale") if is_boss else 1.0)
	if is_boss:
		top -= 34.0
		var sh: float = Art.svg_size("boss_shield").y * 0.9 * Data.bf("boss", "scale")
		top = minf(top, -_h * 0.35 - sh * 0.5)
	return global_position.y + top


## Turns this archer into the realm boss.
func make_boss(p_name: String, p_hp: float) -> void:
	is_boss = true
	boss_name = p_name
	hp = p_hp
	max_hp = p_hp
	mass *= 2.0
	_base_scale *= Data.bf("boss", "scale")
	var key: String = "boss_" + String((Data.b("boss", "art_keys") as Dictionary).get(p_name, ""))
	if Art.has_ai(key + "_idle"):
		_pose_prefix = key
		_pose("archer_idle")
		_base_scale = _sprite.scale.x * Data.bf("boss", "scale")
		_tint = Color.WHITE
	else:
		_tint = Color(0.85, 0.75, 1.0)
	_sprite.scale = Vector2.ONE * _base_scale
	_sprite.modulate = _tint
	var crown: Sprite2D = Art.sprite("boss_crown", 0.9)
	crown.position = Vector2(-4, _sprite.position.y - _h * Data.bf("boss", "scale") - 6)
	crown.z_index = 2
	add_child(crown)


## Engineer look: archer art tinted, with a hard hat and a hammer.
func make_engineer() -> void:
	is_engineer = true
	_tint = Color(1.0, 0.9, 0.7)
	_sprite.modulate = _tint
	var hat: Sprite2D = Art.sprite("engineer_hat", 0.9)
	hat.position = Vector2(-2, _sprite.position.y - _h + 6)
	hat.z_index = 2
	add_child(hat)
	_hammer = Art.sprite("engineer_hammer", 0.75)
	_hammer.offset = Vector2(0, -20) / Art.SVG_SCALE
	_hammer.position = Vector2(-22, _sprite.position.y - _h * 0.45)
	_hammer.rotation = -0.4
	_hammer.z_index = 2
	add_child(_hammer)


func swing_hammer() -> void:
	if _hammer == null or dead:
		return
	var tw: Tween = _hammer.create_tween()
	for i: int in 3:
		tw.tween_property(_hammer, "rotation", -1.4, 0.08)
		tw.tween_property(_hammer, "rotation", 0.3, 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_hammer, "rotation", -0.4, 0.15)


## Core shield: stays up until unlocked (all power cores broken).
func lock_shield(on: bool) -> void:
	if on:
		raise_shield(1.0e9)
	else:
		shield_left = 0.0
		if _shield:
			var tw: Tween = _shield.create_tween()
			tw.tween_property(_shield, "scale", _shield.scale * 1.6, 0.25)
			tw.parallel().tween_property(_shield, "modulate:a", 0.0, 0.25)
			tw.tween_callback(func() -> void:
				_shield.visible = false
				_shield.modulate.a = 1.0)


func raise_shield(seconds: float) -> void:
	shield_left = maxf(shield_left, seconds)
	if _shield == null:
		_shield = Art.sprite("boss_shield", 0.9 * Data.bf("boss", "scale"))
		_shield.position.y = -_h * 0.35
		_shield.z_index = 3
		add_child(_shield)
	_shield.visible = true
	_shield.scale = Vector2.ONE * 0.1
	_shield.create_tween().tween_property(_shield, "scale", Vector2.ONE * 0.9 * Data.bf("boss", "scale"), 0.3).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	if dead:
		return
	_shadowless_bob += delta * 3.0
	var s: float = 1.0 + 0.025 * sin(_shadowless_bob)
	_sprite.scale = Vector2(_base_scale * (2.0 - s), _base_scale * s)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if shield_left > 0.0:
		shield_left -= delta
		if shield_left <= 0.0 and _shield:
			_shield.visible = false
	var v: Vector2 = linear_velocity
	if not sleeping:
		var dv: Vector2 = v - _prev_vel - _gravity * delta
		var impulse: float = mass * dv.length()
		var min_imp: float = Data.bf("damage", "archer_min_impulse")
		if impulse > min_imp and level.damage_enabled():
			var mult: float = 1.0
			for body: Node in get_colliding_bodies():
				if body is Projectile:
					mult = Data.bf("damage", "projectile_bonus")
			take_damage((impulse - min_imp) * Data.bf("damage", "archer_per_impulse") * mult)
	_prev_vel = v
	if _burn_left > 0.0:
		_burn_left -= delta
		take_damage(Data.bf("fire", "archer_dps") * delta)
		if _burn_left <= 0.0 and _flame:
			_flame.queue_free()
			_flame = null
	if not _splashed and global_position.y > level.surface_line():
		_splashed = true
		level.splash(global_position, 60.0)
	if global_position.y > level.kill_line():
		defeat()


func push(impulse: Vector2) -> void:
	sleeping = false
	apply_central_impulse(impulse)
	_prev_vel += impulse / mass


func take_damage(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	if shield_left > 0.0:
		_shield.modulate = Color(2, 2, 2)
		_shield.create_tween().tween_property(_shield, "modulate", Color.WHITE, 0.2)
		return
	hp -= amount
	if is_boss:
		level.on_boss_damaged(self)
	if amount > 2.0:
		_pose("archer_ko")
		_sprite.modulate = Color(1.8, 1.4, 1.4)
		var tw: Tween = create_tween()
		tw.tween_property(_sprite, "modulate", _tint, 0.2)
		if hp > 0.0:
			tw.tween_callback(func() -> void: _pose("archer_shoot" if drawing else "archer_idle"))
	if hp <= 0.0:
		defeat()


func ignite(seconds: float) -> void:
	if dead:
		return
	if _flame == null:
		_flame = Art.sprite("flame", 0.9)
		_flame.position = Vector2(0, -30)
		add_child(_flame)
	_burn_left = maxf(_burn_left, seconds)


func defeat() -> void:
	if dead:
		return
	dead = true
	_pose("archer_ko")
	_sprite.modulate = Color.WHITE
	level.on_archer_defeated(self)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", int(Data.b("layers", "world")))
	var tw: Tween = create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, Data.bf("archers", "ko_fade_s"))
	tw.tween_callback(queue_free)


func _pose(art: String) -> void:
	if _pose_prefix != "archer":
		var want: String = art.replace("archer", _pose_prefix)
		art = want if Art.has_ai(want) else _pose_prefix + "_idle"
	Art.set_unit_tex(_sprite, art, _h)


func draw_bow() -> void:
	if not dead:
		drawing = true
		_pose("archer_shoot")


func relax() -> void:
	drawing = false
	if not dead:
		_pose("archer_idle")


## Point the arrow leaves from, in world space.
func bow_point() -> Vector2:
	return global_position + Vector2(-34, -6).rotated(rotation)


func speed() -> float:
	return linear_velocity.length()
