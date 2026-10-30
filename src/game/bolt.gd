class_name Bolt
extends Node2D
## Iron bolt plate joining two blocks with two pin joints (two pins also lock rotation), so bolted
## structures can overhang: balconies, cantilevers, spans between towers. The bolt snaps when either
## block has taken `bolts.break_damage`, when an explosion or quake reaches it, or a block is destroyed.
## Level JSON: "bolts": [{"a": block_index, "b": block_index}]

var level: Level
var a: Block
var b: Block
var broken: bool = false

var _joints: Array[PinJoint2D] = []
var _sprite: Sprite2D
var _local_a: Vector2 = Vector2.ZERO


func setup(p_level: Level, block_a: Block, block_b: Block) -> void:
	level = p_level
	a = block_a
	b = block_b


func _ready() -> void:
	var mid: Vector2 = (a.global_position + b.global_position) * 0.5
	var along: Vector2 = (b.global_position - a.global_position).normalized()
	if along == Vector2.ZERO:
		along = Vector2.RIGHT
	var perp: Vector2 = along.orthogonal()
	var spread: float = minf(minf(a.size.x, a.size.y), minf(b.size.x, b.size.y)) * Data.bf("bolts", "pin_spread")
	spread = maxf(spread, 6.0)
	for k: int in [-1, 1]:
		var j: PinJoint2D = PinJoint2D.new()
		j.position = mid + perp * spread * k
		j.softness = Data.bf("bolts", "softness")
		j.bias = Data.bf("bolts", "bias")
		j.disable_collision = true
		add_child(j)
		j.node_a = j.get_path_to(a)
		j.node_b = j.get_path_to(b)
		_joints.append(j)
	_sprite = Art.sprite("bolt", 0.8)
	_sprite.z_index = 4
	add_child(_sprite)
	_local_a = a.to_local(mid)
	_sprite.global_position = mid


func _process(_delta: float) -> void:
	if broken or not is_instance_valid(a):
		return
	_sprite.global_position = a.to_global(_local_a)
	_sprite.rotation = a.rotation


func has_block(block: Block) -> bool:
	return block == a or block == b


func position_now() -> Vector2:
	return _sprite.global_position if _sprite else global_position


## True if this bolt should give way after one of its blocks took damage.
func overloaded() -> bool:
	var limit: float = Data.bf("bolts", "break_damage")
	return (is_instance_valid(a) and a.damage_total >= limit) or (is_instance_valid(b) and b.damage_total >= limit)


func snap() -> void:
	if broken:
		return
	broken = true
	for j: PinJoint2D in _joints:
		if is_instance_valid(j):
			j.queue_free()
	_joints.clear()
	if is_instance_valid(a):
		a.sleeping = false
	if is_instance_valid(b):
		b.sleeping = false
	level.on_bolt_snapped(self)
	var tw: Tween = _sprite.create_tween()
	tw.tween_property(_sprite, "position", _sprite.position + Vector2(randf_range(-40, 40), 160), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_sprite, "rotation", randf_range(-6, 6), 0.6)
	tw.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
