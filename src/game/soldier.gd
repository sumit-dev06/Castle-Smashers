class_name Soldier
extends Node2D
## One of our Vanguard soldiers. Not a physics body; arrows test distance to body_center().
## States: marching in, standing guard, cheering, charging the fortress, knocked out.

enum Mode { STAND, MARCH, CHARGE }

var hp: int = 3
var knocked_out: bool = false
var mode: Mode = Mode.STAND
var _sprite: Sprite2D
var _shadow: Sprite2D
var _t: float = 0.0
var _h: float = 86.0
var _base_scale: float = 1.0
var _cheer_left: float = 0.0
var _march_from: Vector2 = Vector2.ZERO
var _march_to: Vector2 = Vector2.ZERO
var _march_t: float = 0.0
var _march_len: float = 1.0
var _charge_speed: float = 0.0
var _charge_limit_x: float = INF


## Vanguard upgrades apply unless upgraded is false (tests).
var upgraded: bool = true


func setup(pos: Vector2, p_upgraded: bool = true) -> void:
	position = pos
	upgraded = p_upgraded
	hp = Progression.soldier_hp() if upgraded else int(Data.b("soldiers", "hp"))
	_h = Data.bf("soldiers", "visual_height")
	_shadow = Art.sprite("shadow", 1.0)
	_shadow.position.y = -2
	add_child(_shadow)
	_sprite = Art.unit_sprite("soldier_idle", _h)
	_base_scale = _sprite.scale.x
	add_child(_sprite)
	_t = randf() * TAU


## Walk from `from` to the current position over `seconds`, starting after `delay`.
func march_in(from: Vector2, seconds: float, delay: float) -> void:
	_march_to = position
	_march_from = from
	position = from
	_march_len = seconds
	_march_t = -delay
	mode = Mode.MARCH


## Run toward the fortress; stop at limit_x (the ledge edge) and cheer there.
func charge(limit_x: float = INF) -> void:
	if knocked_out:
		return
	_charge_limit_x = limit_x
	mode = Mode.CHARGE
	_charge_speed = Data.bf("soldiers", "charge_speed") * randf_range(0.9, 1.15)
	_set_pose("soldier_cheer")


func _process(delta: float) -> void:
	_t += delta
	if knocked_out:
		return
	var walking: bool = false
	match mode:
		Mode.MARCH:
			_march_t += delta
			var k: float = clampf(_march_t / _march_len, 0.0, 1.0)
			position = _march_from.lerp(_march_to, k)
			walking = _march_t > 0.0 and k < 1.0
			if k >= 1.0:
				mode = Mode.STAND
		Mode.CHARGE:
			position.x += _charge_speed * delta
			walking = true
			if position.x >= _charge_limit_x:
				position.x = _charge_limit_x
				mode = Mode.STAND
				_cheer_left = 9999.0
				walking = false
	var y: float = 0.0
	var rot: float = 0.0
	var sq: float = 1.0 + 0.03 * sin(_t * 3.2)
	if walking:
		y = -absf(sin(_t * 11.0)) * 9.0
		rot = sin(_t * 11.0) * 0.08
		sq = 1.0
	elif _cheer_left > 0.0:
		_cheer_left -= delta
		y = -absf(sin(_t * 8.0)) * 22.0
		if _cheer_left <= 0.0:
			_set_pose("soldier_idle")
	_sprite.position.y = y
	_sprite.rotation = rot
	_sprite.scale = Vector2(_base_scale * (2.0 - sq), _base_scale * sq)
	_shadow.scale = Vector2.ONE * Art.SVG_SCALE * (1.0 + y / 80.0)


func _set_pose(art: String) -> void:
	Art.set_unit_tex(_sprite, art, _h)


func body_center() -> Vector2:
	return global_position + Vector2(0, -_h * 0.45)


## Returns true if the arrow was blocked by the shield.
func hit(unblockable: bool = false) -> bool:
	if knocked_out:
		return false
	if not unblockable and randf() < (Progression.shield_chance() if upgraded else Data.bf("soldiers", "shield_block_chance")):
		Sound.play("stone_hit", 0.5, 1.6)
		return true
	hp -= 1
	_sprite.modulate = Color(2.0, 1.2, 1.2)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	if hp <= 0:
		knocked_out = true
		_cheer_left = 0.0
		_set_pose("soldier_ko")
		_sprite.position = Vector2.ZERO
		_sprite.rotation = 0.0
		_sprite.scale = Vector2.ONE * _base_scale
		Sound.play("soldier_ko")
		Events.soldier_knocked_out.emit(self)
	else:
		Sound.play("soldier_hit")
	return false


## Boss rush carries soldier HP between fights; 0 = starts knocked out.
func set_hp(v: int) -> void:
	hp = v
	if hp <= 0:
		knocked_out = true
		_set_pose("soldier_ko")


func cheer(seconds: float = 1.6) -> void:
	if knocked_out or mode != Mode.STAND:
		return
	_cheer_left = seconds
	_set_pose("soldier_cheer")
