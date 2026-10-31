class_name Captive
extends Node2D
## Rescue objective released by a weak-point trigger.

var rescue_id: String = ""
var rescued: bool = false
var level: Level
var _person: Sprite2D
var _cage: Sprite2D
var _base_scale: Vector2
var _time: float = 0.0


func setup(p_level: Level, data: Dictionary) -> void:
	level = p_level
	rescue_id = String(data["trigger"])
	position = Vector2(float(data["x"]), float(data["y"]))
	_person = Art.unit_sprite("captive_idle", float(data["height"]))
	_person.modulate = Color(0.9, 0.9, 0.94)
	_base_scale = _person.scale
	add_child(_person)
	_cage = Art.sprite("mechanism_cage")
	_cage.position.y = -70
	_cage.z_index = 2
	add_child(_cage)


func _process(delta: float) -> void:
	_time += delta
	if rescued:
		_person.position.y = -absf(sin(_time * 7.0)) * 18.0
		_person.rotation = sin(_time * 7.0) * 0.08
	else:
		var squash: float = 1.0 + 0.02 * sin(_time * 2.4)
		_person.scale = Vector2(_base_scale.x * (2.0 - squash), _base_scale.y * squash)


func rescue() -> void:
	if rescued:
		return
	rescued = true
	_person.modulate = Color.WHITE
	if _cage:
		level.fx.debris(global_position + Vector2(0, -60), "wood", 8, 440.0)
		_cage.queue_free()
		_cage = null
	level.on_captive_rescued(self)
	Sound.play_at("cage_break", global_position, 0.85)
	Sound.play_at("rescue", global_position, 0.8)
