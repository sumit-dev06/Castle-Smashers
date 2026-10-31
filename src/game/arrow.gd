class_name Arrow
extends Node2D
## Ballistic enemy arrow (no physics body). Hits the first soldier within range or sticks in the ground.
## A cannonball (hits > 1) ignores shields, hits that many times, and bursts instead of sticking.

signal finished

var velocity: Vector2 = Vector2.ZERO
var flying: bool = true
var _soldiers: Array = []
var _gravity: float = 0.0
var _hit_r: float = 0.0
var _deflected: bool = false
var _stage: Stage
var hits: int = 1
var _spin: float = 0.0


func setup(from: Vector2, to: Vector2, flight_time: float, soldiers: Array, stage: Stage = null, art: String = "arrow", p_hits: int = 1) -> void:
	hits = p_hits
	_stage = stage
	position = from
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	velocity = (to - from - Vector2(0, 0.5 * _gravity * flight_time * flight_time)) / flight_time
	_soldiers = soldiers
	_hit_r = Data.bf("archers", "arrow_hit_radius")
	var s: Sprite2D = Art.sprite(art, Data.bf("archers", "arrow_scale") if art == "arrow" else Data.bf("boss_rig", "cannonball_scale"))
	add_child(s)
	rotation = velocity.angle() if hits == 1 else 0.0
	z_index = 3


func _physics_process(delta: float) -> void:
	if not flying:
		return
	velocity.y += _gravity * delta
	position += velocity * delta
	if hits == 1:
		rotation = velocity.angle()
	else:
		rotation += delta * 8.0
	if not _deflected:
		for s: Soldier in _soldiers:
			if not s.knocked_out and s.body_center().distance_to(global_position) < _hit_r:
				if hits > 1:
					for i: int in hits:
						s.hit(true)
					_burst()
					return
				if s.hit():
					_deflected = true
					velocity = Vector2(-velocity.x * 0.25, -320.0)
					return
				Sound.play_at("arrow_hit", global_position, 0.8)
				_stick(s)
				return
	if _stage and not _stage.ground_at(position.x):
		# Missed over the gap: keep falling and vanish under the surface.
		if position.y > _stage.surface_y:
			flying = false
			queue_free()
		return
	var ground: float = (_stage.top_at(position.x) if _stage else 0.0) - 2.0
	if position.y >= ground:
		position.y = ground
		if hits > 1:
			_burst()
			return
		Sound.play_at("arrow_hit", global_position, 0.5)
		_stick(null)


func _burst() -> void:
	flying = false
	Sound.play_at("explosion", global_position, 0.55, 1.3)
	var lv: Level = get_parent().get_parent() as Level if get_parent() else null
	if lv and lv.fx:
		lv.fx.puff(global_position, 5, Color(0.5, 0.48, 0.45, 0.85), 1.0)
		lv.fx.sparks(global_position, 8)
		lv.camera.add_shake(Data.bf("boss_rig", "cannon_shake"))
	finished.emit()
	queue_free()


func _stick(target: Node2D) -> void:
	flying = false
	if target != null:
		var gp: Vector2 = global_position
		reparent(target)
		global_position = gp
	finished.emit()
	var tw: Tween = create_tween()
	tw.tween_interval(Data.bf("archers", "arrow_stick_s"))
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
