class_name Catapult
extends Node2D
## Our wheeled catapult. The level drives it: set_pull() while aiming, fire() on release.
## The loaded hero sits inside the bowl: the arm sprite draws the bowl's back, the hero is drawn
## over it, and `catapult_cup` (outer wall + near rim) is drawn over the hero.

## Art facts (assets/art/svg/catapult_*.svg, 1x units).
const BASE_CENTER: Vector2 = Vector2(120, 75)
const BASE_GROUND_Y: float = 149.0
const ARM_PIVOT: Vector2 = Vector2(14, 10)
## Centre of the bowl's opening (rim) in arm SVG units. The bowl opens toward +y.
const CUP_RIM: Vector2 = Vector2(172, 50)

var arm: Node2D
var loaded: Sprite2D
var loaded_kind: String = ""
var _rest: float = 0.0
var _pull: float = 0.0
var _fire: float = 0.0
var _rim_local: Vector2 = Vector2.ZERO
var _tween: Tween
var _base_sprite: Sprite2D
var _arm_sprite: Sprite2D
var _cup_sprite: Sprite2D


func _ready() -> void:
	scale = Vector2.ONE * Data.bf("catapult", "visual_scale")
	var base: Sprite2D = Art.sprite("catapult_base")
	base.position = Vector2(0, BASE_CENTER.y - BASE_GROUND_Y)
	var pivot: Vector2 = Data.vec("catapult", "pivot")
	arm = Node2D.new()
	arm.position = pivot
	var arm_sprite: Sprite2D = Art.sprite("catapult_arm")
	arm_sprite.centered = false
	arm_sprite.offset = -ARM_PIVOT / Art.SVG_SCALE
	arm.add_child(arm_sprite)
	var cup: Sprite2D = Art.sprite("catapult_cup")
	cup.centered = false
	cup.offset = -ARM_PIVOT / Art.SVG_SCALE
	cup.z_index = 2
	arm.add_child(cup)
	var shadow: Sprite2D = Art.sprite("shadow", 2.6)
	shadow.position = Vector2(0, -3)
	shadow.modulate.a = 0.8
	add_child(shadow)
	add_child(arm)
	add_child(base)
	_base_sprite = base
	_arm_sprite = arm_sprite
	_cup_sprite = cup
	var tints: Array = Progression.catapult_tints()
	apply_tints(tints[0], tints[1])
	_rest = deg_to_rad(Data.bf("catapult", "rest_angle_deg"))
	_pull = deg_to_rad(Data.bf("catapult", "pull_angle_deg"))
	_fire = deg_to_rad(Data.bf("catapult", "fire_angle_deg"))
	arm.rotation = _rest
	_rim_local = CUP_RIM - ARM_PIVOT


func _process(_delta: float) -> void:
	if loaded:
		loaded.global_position = arm.to_global(_seat(loaded_kind))
		loaded.global_rotation = 0.0


## Hero radius in arm units (the catapult is scaled, heroes keep their world size).
func _radius_arm(hero_kind: String) -> float:
	return float(Data.projectiles[hero_kind]["radius"]) / scale.x if hero_kind != "" else 0.0


## Arm-local centre of a seated hero: just past the rim, so the lower part sits inside the bowl.
func _seat(hero_kind: String) -> Vector2:
	return _rim_local + Vector2(0, _radius_arm(hero_kind) * Data.bf("catapult", "seat_out_frac"))


## Bucket position now (world), where a hopping hero should land.
func bucket_global(hero_kind: String = "stone") -> Vector2:
	return arm.to_global(_seat(hero_kind))


func load_hero(hero_kind: String) -> void:
	unload()
	loaded_kind = hero_kind
	loaded = Projectile.make_sprite(hero_kind)
	loaded.z_index = 1
	# Children of the catapult are scaled with it; keep the hero at its real world size.
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


## power 0..1
func set_pull(power: float) -> void:
	if _tween and _tween.is_running():
		return
	arm.rotation = _rest + _pull * clampf(power, 0.0, 1.0)


## Where a launched hero starts (bucket position at the end of the swing).
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


## Skin / weapon colouring (menus preview other skins with this).
func apply_tints(base_tint: Color, arm_tint: Color) -> void:
	_base_sprite.modulate = base_tint
	_arm_sprite.modulate = arm_tint
	_cup_sprite.modulate = arm_tint
