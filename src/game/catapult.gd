class_name Catapult
extends Node2D
## Data-driven siege engine. Level input remains shared, but Catapult, Ballista and Trebuchet use
## different silhouettes, pivots, cradles and swing timing from balance.siege_weapons.<id>.art.

var weapon_id: String = ""
var skin_id: String = ""
var arm: Node2D
var loaded: Sprite2D
var loaded_kind: String = ""
var _rest: float = 0.0
var _pull: float = 0.0
var _fire: float = 0.0
var _rim_local: Vector2 = Vector2.ZERO
var _arm_pivot: Vector2 = Vector2.ZERO
var _tween: Tween
var _base_sprite: Sprite2D
var _arm_sprite: Sprite2D
var _cup_sprite: Sprite2D
var _skin_base: Sprite2D
var _skin_arm: Sprite2D
var _shadow: Sprite2D


func _ready() -> void:
	if weapon_id.is_empty():
		weapon_id = Progression.weapon()
	if skin_id.is_empty():
		skin_id = Progression.equipped("skins")
	arm = Node2D.new()
	arm.z_index = 1
	add_child(arm)
	_shadow = Art.sprite("shadow", 2.6)
	_shadow.position = Vector2(0, -3)
	_shadow.modulate.a = 0.8
	_shadow.z_index = -2
	add_child(_shadow)
	_rebuild_art()


func set_appearance(new_weapon: String, new_skin: String = "") -> void:
	weapon_id = new_weapon if Data.balance["siege_weapons"].has(new_weapon) else "catapult"
	skin_id = new_skin if not new_skin.is_empty() else Progression.equipped("skins")
	if is_inside_tree() and arm != null:
		_rebuild_art()


func _rebuild_art() -> void:
	for old: Sprite2D in [_base_sprite, _arm_sprite, _cup_sprite, _skin_base, _skin_arm]:
		if is_instance_valid(old):
			old.free()
	_base_sprite = null
	_arm_sprite = null
	_cup_sprite = null
	_skin_base = null
	_skin_arm = null
	var cfg: Dictionary = Progression.weapon_cfg(weapon_id)
	var art: Dictionary = cfg["art"]
	scale = Vector2.ONE * Data.bf("catapult", "visual_scale") * float(art.get("visual_scale", 1.0))
	var base_name: String = String(art["base"])
	var base_size: Vector2 = Art.svg_size(base_name)
	_base_sprite = Art.sprite(base_name)
	_base_sprite.position = Vector2(0, base_size.y * 0.5 - float(art["base_ground_y"]))
	_base_sprite.z_index = 0
	add_child(_base_sprite)
	_arm_pivot = _array_vec(art["arm_pivot"])
	arm.position = _array_vec(art["world_pivot"])
	_arm_sprite = _part(String(art["arm"]), _arm_pivot, 0)
	arm.add_child(_arm_sprite)
	_cup_sprite = _part(String(art["cup"]), _arm_pivot, 3)
	arm.add_child(_cup_sprite)
	var skin_base_name: String = "skin_%s_base" % skin_id
	if ResourceLoader.exists("res://assets/art/svg/%s.svg" % skin_base_name):
		_skin_base = Art.sprite(skin_base_name)
		var skin_size: Vector2 = Art.svg_size(skin_base_name)
		_skin_base.position = Vector2(0, -skin_size.y * 0.5)
		_skin_base.z_index = 2
		add_child(_skin_base)
	var skin_arm_name: String = "skin_%s_arm" % skin_id
	if ResourceLoader.exists("res://assets/art/svg/%s.svg" % skin_arm_name):
		_skin_arm = _part(skin_arm_name, _arm_pivot, 4)
		arm.add_child(_skin_arm)
	_rim_local = _array_vec(art["cup_rim"]) - _arm_pivot
	_rest = deg_to_rad(float(art["rest_angle_deg"]))
	_pull = deg_to_rad(float(art["pull_angle_deg"]))
	_fire = deg_to_rad(float(art["fire_angle_deg"]))
	arm.rotation = _rest
	var tints: Array = Progression.catapult_tints(weapon_id, skin_id)
	apply_tints(tints[0], tints[1])
	_process(0.0)


func _part(art_name: String, pivot: Vector2, z: int) -> Sprite2D:
	var sprite: Sprite2D = Art.sprite(art_name)
	sprite.centered = false
	sprite.offset = -pivot / Art.SVG_SCALE
	sprite.z_index = z
	return sprite


static func _array_vec(value: Variant) -> Vector2:
	var a: Array = value
	return Vector2(float(a[0]), float(a[1]))


func _process(_delta: float) -> void:
	if loaded:
		loaded.global_position = arm.to_global(_seat(loaded_kind))
		loaded.global_rotation = 0.0


## Hero radius in arm units (the siege engine is scaled, heroes keep their world size).
func _radius_arm(hero_kind: String) -> float:
	return float(Data.projectiles[hero_kind]["radius"]) / scale.x if hero_kind != "" else 0.0


func _seat(hero_kind: String) -> Vector2:
	return _rim_local + Vector2(0, _radius_arm(hero_kind) * Data.bf("catapult", "seat_out_frac"))


func bucket_global(hero_kind: String = "stone") -> Vector2:
	return arm.to_global(_seat(hero_kind))


func load_hero(hero_kind: String) -> void:
	unload()
	loaded_kind = hero_kind
	loaded = Projectile.make_sprite(hero_kind)
	loaded.z_index = 2
	var full: Vector2 = loaded.scale / scale
	loaded.scale = full * Vector2(1.25, 0.75)
	add_child(loaded)
	create_tween().tween_property(loaded, "scale", full, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_process(0.0)


func unload() -> void:
	if loaded:
		loaded.queue_free()
	loaded = null
	loaded_kind = ""


func set_pull(power: float) -> void:
	if _tween and _tween.is_running():
		return
	arm.rotation = _rest + _pull * clampf(power, 0.0, 1.0)


func launch_point(hero_kind: String) -> Vector2:
	return to_global(arm.position + _seat(hero_kind).rotated(_fire))


func fire() -> void:
	unload()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(arm, "rotation", _fire, Data.bf("catapult", "arm_swing_s")) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(arm, "rotation", _rest, Data.bf("catapult", "arm_return_s")) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func apply_tints(base_tint: Color, arm_tint: Color) -> void:
	if _base_sprite:
		_base_sprite.modulate = base_tint
	if _arm_sprite:
		_arm_sprite.modulate = arm_tint
	if _cup_sprite:
		_cup_sprite.modulate = arm_tint
