class_name Tether
extends Node2D
## Physics links for the set-piece contraptions (seesaws, bells, pendulums, cranes, springs, cages).
## Level JSON: "tethers": [{kind, a, b, x, y, ...}]
##   kind "pin":    block `a` turns around the world point (x, y) (on a static hub, or on block `b`).
##                  Seesaws, crane arms, wheels. Drawn as an iron hub.
##   kind "rope":   block `a` hangs from (x, y) (a static hook, or a point on block `b`). The rope keeps its
##                  length (rigid pin at the hook) so loads swing like pendulums. Shots, fire and blasts
##                  cut it (Level.cut_ropes_near). `attach`: [x, y] world point on `a` where the rope ends.
##   kind "spring": block `a` is pulled toward (x, y) by a damped spring (`rest`, `stiffness`, `damping`).
## Optional "lock": true on a rope freezes block `a` in place until the rope is cut (spring-trap latches).
## Optional "kick": [vx, vy] on a lock: when it is cut, springs on `a` let go and `a` is flung at that velocity
## (Godot springs can't push past their length, so the launch is scripted).
## Optional "frame": {"posts": [x...], "top": y, "bottom": y, "beam": [x0, x1]} draws a wooden gantry.

var level: Level
var kind: String = "pin"
var cfg: Dictionary = {}
var a: Block
var b: Block
var cut: bool = false

var _anchor: StaticBody2D
var _joint: Joint2D
var _line: Line2D
var _hub: Sprite2D
var _attach_local: Vector2 = Vector2.ZERO
var _hook_local_b: Vector2 = Vector2.ZERO
var _hook: Vector2 = Vector2.ZERO
## Launch seesaw ("launch" on a pin): the payload block waits, frozen, over the low end. When the
## beam spins fast enough the right way (the light end was hit), it is thrown at "kick" px/s.
var payload: Block
var launched: bool = false
var _age: float = 0.0


func setup(p_level: Level, data: Dictionary, block_a: Block, block_b: Block) -> void:
	level = p_level
	cfg = data
	kind = String(data.get("kind", "pin"))
	a = block_a
	b = block_b
	_hook = Vector2(float(data["x"]), float(data["y"]))


func _ready() -> void:
	z_index = 2
	if cfg.has("frame"):
		_build_frame(cfg["frame"])
	var hold: PhysicsBody2D = b
	if b == null:
		_anchor = StaticBody2D.new()
		_anchor.collision_layer = 0
		_anchor.collision_mask = 0
		_anchor.global_position = _hook
		add_child(_anchor)
		hold = _anchor
	else:
		_hook_local_b = b.to_local(_hook)
	var attach: Vector2 = Vector2(cfg["attach"][0], cfg["attach"][1]) if cfg.has("attach") else _hook
	_attach_local = a.to_local(attach)
	if bool(cfg.get("lock", false)):
		a.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		a.set_deferred("freeze", true)
	if payload:
		payload.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		payload.set_deferred("freeze", true)
		payload.held = true
	match kind:
		"pin", "rope":
			var j: PinJoint2D = PinJoint2D.new()
			j.global_position = _hook
			j.softness = Data.bf("tethers", "pin_softness")
			j.bias = Data.bf("tethers", "pin_bias")
			j.disable_collision = true
			_joint = j
		"spring":
			var s: DampedSpringJoint2D = DampedSpringJoint2D.new()
			s.global_position = _hook
			var to: Vector2 = attach - _hook
			s.rotation = to.angle() - PI / 2.0
			s.length = maxf(to.length(), 1.0)
			s.rest_length = float(cfg.get("rest", to.length()))
			s.stiffness = float(cfg.get("stiffness", Data.bf("tethers", "spring_stiffness")))
			s.damping = float(cfg.get("damping", Data.bf("tethers", "spring_damping")))
			s.disable_collision = true
			_joint = s
	add_child(_joint)
	_joint.node_a = _joint.get_path_to(hold)
	_joint.node_b = _joint.get_path_to(a)
	if kind == "pin":
		_hub = Art.sprite("bolt", float(cfg.get("hub_scale", 1.2)))
		_hub.global_position = _hook
		_hub.z_index = 4
		add_child(_hub)
	else:
		_line = Line2D.new()
		_line.width = Data.bf("ropes", "rope_width") if kind == "rope" else Data.bf("tethers", "spring_width")
		_line.default_color = Color(Data.b("ropes", "rope_color")) if kind == "rope" else Color(Data.b("tethers", "spring_color"))
		_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_line.z_index = -1
		add_child(_line)
		var hook: Sprite2D = Art.sprite("bolt", 0.7)
		hook.global_position = _hook
		hook.z_index = 3
		add_child(hook)
		if b != null:
			hook.set_meta("follow_b", true)
	_update_visual()


func _physics_process(delta: float) -> void:
	_age += delta
	if cut:
		return
	if not is_instance_valid(a) or a.dead or (b != null and (not is_instance_valid(b) or b.dead)):
		release(false)
		return
	if payload and not launched:
		var lc: Dictionary = cfg["launch"]
		if not is_instance_valid(payload) or payload.dead:
			launched = true
		elif _age > Data.bf("tethers", "launch_arm_s") and a.angular_velocity * float(lc.get("dir", 1.0)) > deg_to_rad(Data.bf("tethers", "launch_min_dps")):
			_launch(lc)
	_update_visual()


func _launch(lc: Dictionary) -> void:
	if Game.args.has("debug-launch"):
		print("LAUNCH av %.2f t %d" % [a.angular_velocity, Engine.get_physics_frames()])
	launched = true
	payload.held = false
	payload.call_deferred("throw", Vector2(float(lc["kick"][0]), float(lc["kick"][1])), float(lc.get("spin", 4.0)))
	payload.start_crush()
	payload.crush_ignore = a
	payload.set_meta("blast_mult", Data.bf("tethers", "launch_blast_mult"))
	Sound.play("launch", 1.0)
	Sound.play("creak", 0.8)
	level.on_contraption(payload.global_position + Vector2(0, -60), "LAUNCH!", int(Data.b("tethers", "launch_score")))


func hook_point() -> Vector2:
	return b.to_global(_hook_local_b) if b != null and is_instance_valid(b) else _hook


func attach_point() -> Vector2:
	return a.to_global(_attach_local) if is_instance_valid(a) else _hook


func _update_visual() -> void:
	var h: Vector2 = hook_point()
	if _hub:
		_hub.global_position = h
	if _line == null:
		return
	for c: Node in get_children():
		if c is Sprite2D and c.has_meta("follow_b"):
			(c as Sprite2D).global_position = h
	var p0: Vector2 = to_local(h)
	var p1: Vector2 = to_local(attach_point())
	if kind == "spring":
		var pts: PackedVector2Array = PackedVector2Array()
		var coils: int = int(Data.b("tethers", "spring_coils"))
		var side: Vector2 = (p1 - p0).orthogonal().normalized() * Data.bf("tethers", "spring_radius")
		pts.append(p0)
		for i: int in coils * 2:
			var k: float = (i + 0.5) / float(coils * 2)
			pts.append(p0.lerp(p1, k) + side * (1.0 if i % 2 == 0 else -1.0))
		pts.append(p1)
		_line.points = pts
	else:
		_line.points = PackedVector2Array([p0, p1])


## [from, to] world segment for rope cutting, or [] when this link can't be cut.
func rope_segment() -> Array:
	if cut or kind != "rope" or not bool(cfg.get("cuttable", true)):
		return []
	return [hook_point(), attach_point()]


## Snaps the link. scored = cut by the player (SNAP! points and a chain link).
func release(scored: bool = true) -> void:
	if cut:
		return
	cut = true
	if is_instance_valid(_joint):
		_joint.queue_free()
	if is_instance_valid(a):
		if bool(cfg.get("lock", false)):
			a.set_deferred("freeze", false)
		if cfg.has("kick"):
			for t: Tether in level.tethers:
				if t != self and t.a == a and t.kind == "spring":
					t.release(false)
			a.set_deferred("linear_velocity", Vector2(float(cfg["kick"][0]), float(cfg["kick"][1])))
		a.sleeping = false
		a.held = false
		if kind == "rope" and scored:
			a.start_crush()
	if b != null and is_instance_valid(b):
		b.sleeping = false
	if _line:
		var tw: Tween = _line.create_tween()
		tw.tween_property(_line, "modulate:a", 0.0, 0.4)
	if scored:
		Sound.play("rope_snap", 0.9)
		level.on_tether_cut(self)


func _build_frame(fr: Dictionary) -> void:
	var top: float = float(fr["top"])
	var bottom: float = float(fr["bottom"])
	var lines: Array = []
	for px: Variant in fr.get("posts", []):
		lines.append([Vector2(float(px), top - 10.0), Vector2(float(px), bottom), 16.0])
	var beam: Array = fr.get("beam", [])
	if beam.size() == 2:
		lines.append([Vector2(float(beam[0]), top), Vector2(float(beam[1]), top), 18.0])
	for pass_i: int in 2:
		for l: Array in lines:
			var line: Line2D = Line2D.new()
			line.points = PackedVector2Array([l[0], l[1]])
			line.width = float(l[2]) + (5.0 if pass_i == 0 else 0.0)
			line.default_color = Color("#3a2212") if pass_i == 0 else Color("#a8642e")
			line.z_index = -3
			add_child(line)
