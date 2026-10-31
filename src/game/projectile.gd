class_name Projectile
extends RigidBody2D
## A hero fired from the catapult. kind: stone | fire | bomb | cyclone | quake (data/projectiles.json).

var kind: String = ""
var cfg: Dictionary = {}
var level: Level = null
var ability_used: bool = false
var impacted: bool = false
var done: bool = false
var age: float = 0.0
var since_impact: float = 0.0

var _sprite: Sprite2D
var _rest_t: float = 0.0
var _fuse: float = -1.0
var _whirl_left: float = 0.0
var _funnel: Array[Node2D] = []
var _dashing: bool = false
var _quake_done: bool = false
var _trail_d: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _radius: float = 1.0
var _splashed: bool = false
var _speed: float = 0.0
var _weapon_damage_mult: float = 1.0


func setup(p_kind: String, p_level: Level, damage_mult: float = 1.0, ability_mult: float = 1.0) -> void:
	kind = p_kind
	level = p_level
	_weapon_damage_mult = damage_mult
	cfg = Workshop.config(kind)
	_apply_ability_mult(ability_mult)
	_radius = float(cfg["radius"])
	var col: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = _radius
	col.shape = c
	add_child(col)
	mass = float(cfg["mass"])
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = float(cfg["friction"])
	pm.bounce = float(cfg["bounce"])
	physics_material_override = pm
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	collision_layer = int(Data.b("layers", "projectiles"))
	collision_mask = int(Data.b("layers", "world")) | int(Data.b("layers", "blocks")) | int(Data.b("layers", "archers")) | int(Data.b("layers", "shield"))
	contact_monitor = true
	max_contacts_reported = 4
	angular_damp = 1.5
	body_entered.connect(_on_body_entered)
	_sprite = Projectile.make_sprite(kind)
	add_child(_sprite)
	z_index = 2




func _apply_ability_mult(mult: float) -> void:
	if is_equal_approx(mult, 1.0):
		return
	match kind:
		"stone":
			cfg["slam_mass_mult"] = float(cfg["slam_mass_mult"]) * mult
		"fire":
			for key: String in ["burst_radius", "burst_radius_dashed", "burst_damage"]:
				cfg[key] = float(cfg[key]) * mult
		"bomb":
			var explosion: Dictionary = cfg["explosion"]
			for key: String in ["radius", "impulse", "damage"]:
				explosion[key] = float(explosion[key]) * mult
		"cyclone":
			for key: String in ["whirl_s", "whirl_radius", "lift_accel", "pull_accel", "swirl_accel", "fling_impulse"]:
				cfg[key] = float(cfg[key]) * mult
		"quake":
			cfg["slam_mass_mult"] = float(cfg["slam_mass_mult"]) * mult
			for key: String in ["shockwave_radius", "shockwave_height", "shockwave_damage", "shockwave_impulse", "archer_damage"]:
				cfg[key] = float(cfg[key]) * mult
## Sprite of a hero sized to its physics radius. Shared with the catapult and waiting queue.
static func make_sprite(hero_kind: String, suffix: String = "") -> Sprite2D:
	var c: Dictionary = Data.projectiles[hero_kind]
	var art: String = String(c["texture"])
	if hero_kind == "stone" and not rock_skin().is_empty():
		return Art.hero_sprite("hero_stone_" + rock_skin(), float(c["radius"]))  # skins have no hit pose
	return Art.hero_sprite(art + suffix, float(c["radius"]))


## Equipped Rocky skin id ("" = classic). Only counts while the Play purchase is owned.
static func rock_skin() -> String:
	var id: String = String(Save.data.get("rock_skin", ""))
	var skins: Dictionary = Data.balance["cosmetics"]["rock_skins"]
	if id.is_empty() or not skins.has(id) or not Store.owns(String(skins[id]["product"])):
		return ""
	return id


func launch(pos: Vector2, vel: Vector2) -> void:
	global_position = pos
	linear_velocity = vel
	angular_velocity = vel.x * 0.004
	_last_pos = pos


func radius() -> float:
	return _radius


func material_mult(mat_id: String) -> float:
	var m: Dictionary = cfg.get("material_mult", {})
	var v: float = float(m.get(mat_id, 1.0))
	return v * _weapon_damage_mult * (float(cfg["slam_mass_mult"]) if kind in ["stone", "quake"] and ability_used else 1.0)


func _physics_process(delta: float) -> void:
	if done:
		return
	age += delta
	if impacted:
		since_impact += delta
	if _whirl_left > 0.0:
		_tick_whirl(delta)
		return
	if not impacted:
		_trail_d += global_position.distance_to(_last_pos)
		if _trail_d > Data.bf("fx", "trail_spacing_px"):
			_trail_d = 0.0
			level.fx.trail(global_position, _dashing)
	_last_pos = global_position
	_speed = linear_velocity.length()
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse < 0.0:
			_explode()
			return
	if _dashing and not impacted:
		level.fx.flame_puff(global_position)
	if impacted and linear_velocity.length() < float(Data.projectiles["common"]["rest_speed"]):
		_rest_t += delta
		if _rest_t > float(Data.projectiles["common"]["rest_s"]):
			finish()
	else:
		_rest_t = 0.0
	if not _splashed and global_position.y > level.surface_line():
		_splashed = true
		level.splash(global_position, _radius * 2.0)
	if global_position.y > level.kill_line() or global_position.x > level.world_right + 600.0:
		finish()


func _on_body_entered(body: Node) -> void:
	if done:
		return
	var first: bool = not impacted
	impacted = true
	if first:
		Art.set_hero_tex(_sprite, String(cfg["texture"]) + "_hit", _radius)
		level.on_projectile_impact(self)
		# A hero that drops back onto our own ledge lands on the Vanguard.
		if level.stage and global_position.x < level.stage.ledge_right and _speed > Data.bf("friendly_fire", "landing_min_speed"):
			level.hurt_soldiers(global_position, Data.bf("friendly_fire", "landing_radius_px") + _radius, 1)
		# Quaky always quakes on landing; the dive (ability) makes it full strength.
		if kind == "quake" and not _quake_done:
			_quake_done = true
			level.quake(global_position, cfg, 1.0 if ability_used else float(cfg.get("unpowered_mult", 0.55)))
	match kind:
		"fire":
			if first:
				_fire_burst()
		"bomb":
			if _fuse < 0.0:
				_fuse = float(cfg["fuse_after_impact_s"])


## Tap ability while flying (and for the bomb, any time before it explodes).
func use_ability() -> bool:
	if done or ability_used:
		return false
	if impacted and kind != "bomb":
		return false
	ability_used = true
	match kind:
		"stone", "quake":
			mass *= float(cfg["slam_mass_mult"])
			linear_velocity = Vector2(linear_velocity.x * float(cfg["slam_keep_x"]), float(cfg["slam_speed"]))
			Sound.play_at("slam", global_position, 1.0, 0.82 if kind == "quake" else 1.0)
			level.fx.puff(global_position, 8 if kind == "quake" else 6, Color("#bdefff") if kind == "quake" else Color(0.95, 0.95, 1.0), 0.8 if kind == "quake" else 0.6)
		"fire":
			_dashing = true
			linear_velocity *= float(cfg["dash_mult"])
			gravity_scale = 0.5
			Sound.play_at("fire", global_position)
		"bomb":
			_explode()
		"cyclone":
			_start_whirl()
	Game.haptic()
	return true


func _fire_burst() -> void:
	var r: float = float(cfg["burst_radius_dashed"] if _dashing else cfg["burst_radius"])
	level.fire_burst(global_position, r, float(cfg["burst_damage"]))
	level.fx.debris(global_position, "clay", 6, 420.0)
	finish()


func _explode() -> void:
	if done:
		return
	var e: Dictionary = cfg["explosion"]
	level.explode(global_position, float(e["radius"]), float(e["impulse"]), float(e["damage"]))
	finish()


func _start_whirl() -> void:
	_whirl_left = float(cfg["whirl_s"])
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	set_deferred("freeze", true)
	set_deferred("collision_mask", 0)
	set_deferred("collision_layer", 0)
	Sound.play_at("wind", global_position)
	var tw: Tween = create_tween()
	tw.tween_property(_sprite, "scale", _sprite.scale * float(cfg["whirl_visual_scale"]), 0.25)
	_sprite.modulate.a = 0.85
	for layer_front: bool in [false, true]:
		var f: Node2D = (load("res://src/game/whirl_fx.gd") as GDScript).new()
		f.call("setup", cfg["funnel"], float(cfg["hover_height"]), layer_front)
		add_child(f)
		_funnel.append(f)


func _tick_whirl(delta: float) -> void:
	_whirl_left -= delta
	var hover_y: float = -float(cfg["hover_height"])
	var drift: Vector2 = Vector2(float(cfg["drift_speed"]), (hover_y - global_position.y) * 2.0)
	global_position += drift * delta
	_sprite.rotation += delta * 14.0
	if randf() < 0.3:
		level.fx.puff(global_position + Vector2(randf_range(-60, 60), randf_range(-40, 60)), 1, Color(0.85, 1.0, 0.98, 0.6), 0.5)
	# Dust kicked up where the funnel touches the ground.
	if randf() < 0.35:
		level.fx.puff(Vector2(global_position.x + randf_range(-40, 40), -6.0), 1, Color(0.86, 0.78, 0.62, 0.7), 0.7)
	level.whirl(global_position, cfg, delta, _whirl_left <= 0.0)
	if _whirl_left <= 0.0:
		for f: Node2D in _funnel:
			if is_instance_valid(f):
				f.reparent(level.world)
				f.call("close")
		finish()


## Marks the hero as finished; the level removes it.
func finish() -> void:
	if done:
		return
	done = true
	if kind in ["stone", "quake"] or (kind == "cyclone" and _whirl_left > 0.0):
		var tw: Tween = create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(self, "modulate:a", 0.0, float(Data.projectiles["common"]["fade_s"]))
		tw.tween_callback(queue_free)
	else:
		visible = false
		set_deferred("freeze", true)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		get_tree().create_timer(0.5).timeout.connect(queue_free)
