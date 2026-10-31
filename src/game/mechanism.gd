class_name CastleMechanism
extends Node2D
## Data-driven moving castle parts and hazards. Triggered mechanisms listen to weak-point IDs.
## Phase C kinds:
##   rope_load        a heavy load (boulder, block) on a rope from a hook; cut the rope to drop it.
##                    "load": shape id, "length": px, "releases": trigger fired when the rope is cut.
##   hanging_platform a deck hung from two ropes over the gap ("span": px between hooks, "drop": rope
##                    length). Cut one rope and it tips; cut both and it falls.
##   crusher          an iron-bound stone that slams down "travel_y" px. "mode": "cycle" (timed, a gate
##                    you must shoot through) or "trigger" (drops once on a weak point, crushes below).
##   geyser           an eruption from the gap surface that lifts shots and pieces ("height", "period_s",
##                    "burst_s"). Water spout, lava plume (burns) or sky updraft by the gap kind.
## Phase D kinds:
##   lever            hit by a shot, a moving block or a blast: flips and fires "triggers" (array).
##   windmill         hub with "arms" sails of "arm_len" turning at "dps"; a hit on the hub jams it.
##                    "hits_blocks": true lets the arms push blocks (default: shots only).
##   shield_ring      "plates" iron plates ("plate_len" px) orbiting at "radius" at "dps"; shots only.
##                    A trigger stops the ring.
##   rune_switch      hidden in the fortress; glows once no block covers it, then a hit fires "triggers".
##   trapdoor         floor panel ("size") hinged on "hinge" (-1 left, 1 right); a trigger drops it open.
##                    "style": "rock" draws it as a cracked rock ledge (breakable ground).
## Round 3 kinds:
##   flood            sluice gate ("size") holding a pool ("pool" px upstream, "pool_h"). A hit on the
##                    gate or its trigger opens it: a wave runs "reach" px downstream (see Flood).
##   windmill + "start_on": a water wheel that stands still until that trigger fires, then turns
##                    ("style": "wheel" draws a rim and paddles).

var kind: String = ""
var trigger_id: String = ""
var active: bool = false
var level: Level
var cfg: Dictionary = {}
var body: AnimatableBody2D

var _time: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _rope: Line2D
var _counterweight: Sprite2D
var _hazard: Area2D
var _collision: CollisionShape2D
## Time multiplier for timed motion (boss "charge" phase speeds it up).
var speed_mult: float = 1.0
var load_block: Block
var _ropes_cut: Array[bool] = []
var _rope_lines: Array[Line2D] = []
var _tip: float = 0.0
var _column: Sprite2D
var _crush_state: String = "up"
var _crush_t: float = 0.0
var _slammed: bool = false
var _geyser_on: bool = false
var _warned: bool = false
var _sensor: Area2D
var _approach_x: float = 0.0
var _sinking: bool = false
var _sink_y: float = 0.0
var _handle: Sprite2D
var _hub: Sprite2D
var _angle: float = 0.0
var _spin: float = 0.0
var jammed: bool = false
var revealed: bool = false
var _check_t: float = 0.0
var _glyph: Sprite2D
var _glow_t: float = 0.0
var flood: Flood
var _gate_col: CollisionShape2D


func setup(p_level: Level, data: Dictionary) -> void:
	level = p_level
	cfg = data
	kind = String(data["type"])
	trigger_id = String(data.get("trigger", ""))
	position = Vector2(float(data["x"]), float(data["y"]))
	_origin = position
	if data.has("frame"):
		_build_frame(data["frame"])
	match kind:
		"gate":
			_build_gate()
		"drawbridge":
			_build_drawbridge()
		"moving_platform":
			_build_platform()
		"swing":
			_build_swing()
		"spikes", "lava":
			_build_hazard()
		"rope_load":
			_build_rope_load()
		"hanging_platform":
			_build_hanging_platform()
		"crusher":
			_build_crusher()
		"geyser":
			_build_geyser()
		"lever":
			_build_lever()
		"windmill", "shield_ring":
			_build_rotor()
		"rune_switch":
			_build_rune_switch()
		"trapdoor":
			_build_trapdoor()
		"flood":
			_build_flood()
		_:
			push_error("Unknown castle mechanism: %s" % kind)


func _size() -> Vector2:
	var raw: Array = cfg["size"]
	return Vector2(float(raw[0]), float(raw[1]))


func _make_body(size: Vector2, art_name: String) -> AnimatableBody2D:
	var b: AnimatableBody2D = AnimatableBody2D.new()
	b.collision_layer = int(Data.b("layers", "world"))
	b.collision_mask = 0
	b.sync_to_physics = true
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = size
	col.shape = rect_shape
	b.add_child(col)
	var sprite: Sprite2D = _sized_sprite(art_name, size)
	b.add_child(sprite)
	add_child(b)
	return b


func _sized_sprite(art_name: String, size: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Art.sprite(art_name)
	var art_size: Vector2 = Art.svg_size(art_name)
	sprite.scale *= Vector2(size.x / art_size.x, size.y / art_size.y)
	return sprite


func _build_gate() -> void:
	body = _make_body(_size(), "mechanism_gate")
	active = trigger_id.is_empty()


func _build_drawbridge() -> void:
	var size: Vector2 = _size()
	body = AnimatableBody2D.new()
	body.collision_layer = int(Data.b("layers", "world"))
	body.collision_mask = 0
	body.sync_to_physics = true
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = size
	col.shape = rect_shape
	col.position.x = size.x * 0.5
	col.disabled = not trigger_id.is_empty()
	_collision = col
	body.add_child(col)
	var bridge: Sprite2D = _sized_sprite("mechanism_drawbridge", size)
	bridge.position.x = size.x * 0.5
	body.add_child(bridge)
	body.rotation_degrees = float(cfg["start_angle"])
	add_child(body)
	var pulley: Sprite2D = Art.sprite("mechanism_pulley", 0.8)
	pulley.name = "Pulley"
	pulley.position = Vector2(0, -72)
	add_child(pulley)
	_counterweight = Art.sprite("mechanism_counterweight", 0.72)
	_counterweight.position = Vector2(-48, -36)
	add_child(_counterweight)
	_rope = Line2D.new()
	_rope.width = 5.0
	_rope.default_color = Color("#d6ad72")
	_rope.z_index = -1
	add_child(_rope)
	_update_bridge_rope()
	active = trigger_id.is_empty()
	if active:
		activate(false)


## Optional dressing that rides with the platform (boss chassis, ship hull, balloon). No collision.
## "chassis": art drawn under the deck, "chassis_h": its height; "balloon": art above, "balloon_size": [w, h].
func _build_platform() -> void:
	body = _make_body(_size(), "mechanism_platform")
	var size: Vector2 = _size()
	if cfg.has("chassis"):
		var ch_h: float = float(cfg.get("chassis_h", size.y * 2.0))
		var ch: Sprite2D = _sized_sprite(String(cfg["chassis"]), Vector2(size.x * 1.04, ch_h))
		ch.position = Vector2(0, size.y * 0.5 + ch_h * 0.5 - 6.0)
		ch.z_index = -1
		body.add_child(ch)
	if cfg.has("balloon"):
		var raw: Array = cfg["balloon_size"]
		var bsz: Vector2 = Vector2(float(raw[0]), float(raw[1]))
		var bl: Sprite2D = _sized_sprite(String(cfg["balloon"]), bsz)
		bl.position = Vector2(0, float(cfg.get("balloon_y", -size.y * 0.5 - bsz.y * 0.5 - 300.0)))
		bl.z_index = -2
		body.add_child(bl)
	var grip: PhysicsMaterial = PhysicsMaterial.new()
	grip.friction = 1.0
	grip.rough = true
	body.physics_material_override = grip
	active = true


func _build_swing() -> void:
	var diameter: float = float(cfg["diameter"])
	body = AnimatableBody2D.new()
	body.collision_layer = int(Data.b("layers", "world"))
	body.collision_mask = 0
	body.sync_to_physics = true
	var col: CollisionShape2D = CollisionShape2D.new()
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = diameter * 0.46
	col.shape = circle_shape
	body.add_child(col)
	body.add_child(_sized_sprite("mechanism_swing", Vector2.ONE * diameter))
	add_child(body)
	_rope = Line2D.new()
	_rope.width = 7.0
	_rope.default_color = Color("#9a6538")
	_rope.z_index = -1
	add_child(_rope)
	active = true
	_update_swing()


func _build_hazard() -> void:
	var size: Vector2 = _size()
	var sprite: Sprite2D = _sized_sprite("mechanism_" + kind, size)
	sprite.z_index = 2
	add_child(sprite)
	_hazard = Area2D.new()
	_hazard.collision_layer = 0
	_hazard.collision_mask = int(Data.b("layers", "blocks")) | int(Data.b("layers", "projectiles")) | int(Data.b("layers", "archers"))
	var col: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(size.x * 0.9, size.y * 0.7)
	col.shape = rect_shape
	col.position.y = size.y * 0.15
	_hazard.add_child(col)
	_hazard.body_entered.connect(_on_hazard_body)
	add_child(_hazard)
	active = true


func _physics_process(delta: float) -> void:
	_time += delta * speed_mult
	match kind:
		"moving_platform":
			var phase: float = _time * TAU / float(cfg["period_s"]) + float(cfg.get("phase", 0.0))
			# One assignment: with sync_to_physics a second setter would read a stale transform.
			# Ease in over the first seconds so towers riding the deck are not jolted over.
			var ease_k: float = smoothstep(0.0, Data.bf("physics", "platform_ease_s"), _time)
			var p: Vector2 = Vector2(sin(phase) * float(cfg["travel_x"]), sin(phase * 0.5) * float(cfg["travel_y"])) * ease_k
			if bool(cfg.get("floating", false)) and level.stage:
				p.y += level.stage.tide_offset()
			if cfg.has("approach"):
				# Reverse siege: the engine sails toward the player at a steady speed until sunk.
				if not _sinking:
					_approach_x -= float(cfg["approach"]["speed"]) * delta * speed_mult * ease_k
				else:
					_sink_y += Data.bf("modes", "sink_speed") * delta
				p += Vector2(_approach_x, _sink_y)
			body.position = p
		"rope_load":
			_update_rope_load()
		"hanging_platform":
			_update_hanging_platform()
		"crusher":
			_update_crusher(delta)
		"geyser":
			_update_geyser(delta)
		"swing":
			_update_swing()
		"drawbridge":
			_update_bridge_rope()
		"windmill", "shield_ring":
			_update_rotor(delta)
		"rune_switch":
			_update_rune_switch(delta)


func _update_swing() -> void:
	if body == null:
		return
	var angle: float = deg_to_rad(sin(_time * TAU / float(cfg["period_s"])) * float(cfg["arc_deg"]))
	var length: float = float(cfg["length"])
	body.transform = Transform2D(-angle, Vector2(sin(angle), cos(angle)) * length)
	if _rope:
		_rope.points = PackedVector2Array([Vector2.ZERO, body.position])


func _update_bridge_rope() -> void:
	if body == null or _rope == null:
		return
	var end: Vector2 = Vector2(_size().x, 0).rotated(body.rotation)
	_rope.points = PackedVector2Array([Vector2(0, -72), end])


func activate(scored: bool = true) -> void:
	if kind == "windmill" and cfg.has("start_on"):
		_start_wheel(scored)
		return
	if kind in ["windmill", "shield_ring"]:
		jam()
		return
	if kind == "flood":
		_open_flood(scored)
		return
	if kind == "trapdoor":
		_open_trapdoor(scored)
		return
	if active and not (kind == "drawbridge" and trigger_id.is_empty()):
		return
	active = true
	match kind:
		"crusher":
			_crush_state = "falling"
			_crush_t = 0.0
		"gate":
			var target_y: float = body.position.y + float(cfg["travel_y"])
			body.create_tween().tween_property(body, "position:y", target_y, float(cfg["duration_s"])) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"drawbridge":
			var bridge_tween: Tween = body.create_tween()
			bridge_tween.tween_property(body, "rotation_degrees", float(cfg["end_angle"]), float(cfg["duration_s"])) \
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			if _collision:
				bridge_tween.tween_callback(func() -> void: _collision.set_deferred("disabled", false))
			if _counterweight:
				_counterweight.create_tween().tween_property(_counterweight, "position:y", _counterweight.position.y + float(cfg["counterweight_travel"]), float(cfg["duration_s"]))
	if scored:
		level.on_mechanism_activated(self)
	Sound.play_at("chain", global_position, 0.72)
	Sound.play_at("creak", global_position, 0.62)
	var duration: float = float(cfg.get("duration_s", 0.7))
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		Sound.play_at("gate_drop", global_position, 0.82 if kind == "gate" else 0.62))


func _on_hazard_body(other: Node) -> void:
	if other is Projectile:
		var projectile: Projectile = other as Projectile
		level.on_projectile_impact(projectile)
		projectile.finish()
	elif other is Archer:
		(other as Archer).take_damage(Data.bf("mechanics", "hazard_damage"))
	elif other is Block:
		(other as Block).take_damage(Data.bf("mechanics", "hazard_damage"))
	level.fx.sparks(other.global_position, 5)
	Sound.play_at("hazard_hit", other.global_position, 0.75, 0.78 if kind == "lava" else 1.05)


# ------------------------------------------------------------------------------------ ropes
func _make_rope(color: Color = Color(Data.b("ropes", "rope_color"))) -> Line2D:
	var l: Line2D = Line2D.new()
	l.width = Data.bf("ropes", "rope_width")
	l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.z_index = 1
	add_child(l)
	_rope_lines.append(l)
	_ropes_cut.append(false)
	return l


func _add_hook(at: Vector2) -> void:
	var hook: Sprite2D = Art.sprite("mechanism_hook", 0.9)
	hook.position = at + Vector2(0, -14)
	hook.z_index = 2
	add_child(hook)


func _build_rope_load() -> void:
	_add_hook(Vector2.ZERO)
	_make_rope()
	var shape: String = String(cfg.get("load", "boulder"))
	var length: float = float(cfg["length"])
	var half_h: float = float(Data.shapes[shape]["size"][1]) * 0.5
	load_block = level.spawn_block(shape, global_position + Vector2(0, length + half_h), {"weak_point": cfg.get("weak_point", false)})
	load_block.held = true
	load_block.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	load_block.freeze = true
	active = true
	_update_rope_load()


func _sway_angle() -> float:
	return deg_to_rad(Data.bf("ropes", "sway_deg")) * sin(_time * TAU * Data.bf("ropes", "sway_hz") + position.x * 0.01)


func _update_rope_load() -> void:
	if _ropes_cut[0] or not is_instance_valid(load_block):
		return
	var a: float = _sway_angle()
	var length: float = float(cfg["length"])
	var half_h: float = load_block.size.y * 0.5
	var attach: Vector2 = Vector2(sin(a), cos(a)) * length
	load_block.global_position = global_position + attach + Vector2(sin(a), cos(a)) * half_h
	load_block.rotation = -a
	_rope_lines[0].points = PackedVector2Array([Vector2.ZERO, attach])


func _build_hanging_platform() -> void:
	var span: float = float(cfg["span"])
	var drop: float = float(cfg["drop"])
	for side: int in [-1, 1]:
		_add_hook(Vector2(side * span * 0.5, 0))
		_make_rope()
	body = _make_body(_size(), "mechanism_platform")
	body.position = Vector2(0, drop)
	var grip: PhysicsMaterial = PhysicsMaterial.new()
	grip.friction = 1.0
	grip.rough = true
	body.physics_material_override = grip
	active = true
	_update_hanging_platform()


## Platform end attachment points (local), following its current tilt.
func _platform_end(side: int) -> Vector2:
	return body.position + Vector2(side * _size().x * 0.5, -_size().y * 0.5).rotated(body.rotation)


func _update_hanging_platform() -> void:
	var span: float = float(cfg["span"])
	for i: int in 2:
		var side: int = -1 if i == 0 else 1
		if _ropes_cut[i]:
			_rope_lines[i].visible = false
			continue
		_rope_lines[i].points = PackedVector2Array([Vector2(side * span * 0.5, 0), _platform_end(side)])


## World-space rope segments that can still be cut: [[from, to], ...] (empty if all cut).
func ropes() -> Array:
	var out: Array = []
	if kind == "rope_load":
		if not _ropes_cut[0] and is_instance_valid(load_block):
			var pts: PackedVector2Array = _rope_lines[0].points
			out.append([to_global(pts[0]), to_global(pts[1]), 0])
	elif kind == "hanging_platform":
		for i: int in 2:
			if not _ropes_cut[i]:
				var p: PackedVector2Array = _rope_lines[i].points
				if p.size() == 2:
					out.append([to_global(p[0]), to_global(p[1]), i])
	return out


func cut_rope(i: int) -> void:
	if i >= _ropes_cut.size() or _ropes_cut[i]:
		return
	_ropes_cut[i] = true
	Sound.play("rope_snap", 0.9)
	var line: Line2D = _rope_lines[i]
	var pts: PackedVector2Array = line.points
	if pts.size() == 2:
		level.fx.puff(to_global(pts[0].lerp(pts[1], 0.5)), 3, Color(1, 0.95, 0.8, 0.9), 0.5)
		# The upper half of the rope swings back up toward its hook.
		var hook: Vector2 = pts[0]
		var upper: PackedVector2Array = PackedVector2Array([hook, pts[0].lerp(pts[1], 0.4)])
		line.points = upper
		var tw: Tween = line.create_tween()
		tw.tween_property(line, "rotation", 0.6 if i == 0 else -0.6, 0.5).set_trans(Tween.TRANS_ELASTIC)
		line.position = hook
		line.points = PackedVector2Array([Vector2.ZERO, upper[1] - hook])
	level.on_rope_cut(self)
	match kind:
		"rope_load":
			if is_instance_valid(load_block):
				var v: Vector2 = Vector2(cos(_sway_angle()), 0) * 0.0
				load_block.freeze = false
				load_block.held = false
				load_block.sleeping = false
				load_block.linear_velocity = v
				load_block.start_crush()
			if cfg.has("releases"):
				level.activate_trigger(String(cfg["releases"]))
		"hanging_platform":
			_settle_platform()


func _settle_platform() -> void:
	var left_cut: bool = _ropes_cut[0]
	var right_cut: bool = _ropes_cut[1]
	var tw: Tween = body.create_tween()
	if left_cut and right_cut:
		var p0: Vector2 = body.position
		var r0: float = body.rotation
		var drop: float = Data.bf("ropes", "drop_px")
		tw.tween_method(func(k: float) -> void:
			body.transform = Transform2D(r0 * (1.0 + 0.4 * k), p0 + Vector2(0, drop * k * k)), 0.0, 1.0, Data.bf("ropes", "drop_s"))
		tw.tween_callback(func() -> void: body.process_mode = Node.PROCESS_MODE_DISABLED)
		if cfg.has("releases"):
			level.activate_trigger(String(cfg["releases"]))
		return
	# One side free: the deck swings down around the attachment that still holds.
	var side: int = 1 if left_cut else -1
	var pivot: Vector2 = _platform_end(side)
	var target: float = deg_to_rad(Data.bf("ropes", "tip_angle_deg")) * (1.0 if left_cut else -1.0) * -1.0
	var half: Vector2 = Vector2(side * _size().x * 0.5, -_size().y * 0.5)
	tw.tween_method(func(ang: float) -> void:
		body.transform = Transform2D(ang, pivot - half.rotated(ang)), body.rotation, target, Data.bf("ropes", "tip_s")) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for b: Block in level.blocks:
		b.sleeping = false
	for a: Archer in level.archers:
		a.sleeping = false


# ------------------------------------------------------------------------------------ crusher
func _build_crusher() -> void:
	body = _make_body(_size(), "mechanism_crusher")
	var chain: Line2D = Line2D.new()
	chain.width = 8.0
	chain.default_color = Color("#5d6670")
	chain.points = PackedVector2Array([Vector2(0, -float(cfg.get("chain_px", 600.0))), Vector2.ZERO])
	chain.z_index = -1
	add_child(chain)
	_rope = chain
	var mode: String = String(cfg.get("mode", "cycle"))
	active = mode == "cycle"
	_crush_t = float(cfg.get("phase", 0.0))


func _cycle_times() -> Array[float]:
	return [Data.bf("crusher", "hold_up_s") * float(cfg.get("hold_k", 1.0)), Data.bf("crusher", "fall_s"),
			Data.bf("crusher", "hold_down_s"), Data.bf("crusher", "rise_s")]


func _update_crusher(delta: float) -> void:
	var travel: float = float(cfg["travel_y"])
	if String(cfg.get("mode", "cycle")) == "trigger":
		if active and _crush_state == "falling":
			_crush_t += delta
			var k: float = clampf(_crush_t / Data.bf("crusher", "fall_s"), 0.0, 1.0)
			body.position.y = travel * k * k
			_crush_sweep()
			if k >= 1.0:
				_crush_state = "down"
				_slam()
		_rope.points = PackedVector2Array([_rope.points[0], body.position - Vector2(0, _size().y * 0.5)])
		return
	_crush_t += delta * speed_mult
	var t: Array[float] = _cycle_times()
	var total: float = t[0] + t[1] + t[2] + t[3]
	var u: float = fposmod(_crush_t, total)
	var y: float = 0.0
	if u < t[0]:
		y = 0.0
		_slammed = false
	elif u < t[0] + t[1]:
		var k2: float = (u - t[0]) / t[1]
		y = travel * k2 * k2
		_crush_sweep()
	elif u < t[0] + t[1] + t[2]:
		y = travel
		if not _slammed:
			_slammed = true
			_slam()
	else:
		y = travel * (1.0 - (u - t[0] - t[1] - t[2]) / t[3])
	body.position.y = y
	_rope.points = PackedVector2Array([_rope.points[0], body.position - Vector2(0, _size().y * 0.5)])


## Everything under the falling stone is crushed.
func _crush_sweep() -> void:
	# Look ahead under the stone: pieces it pushes down must still be crushed.
	var r: Rect2 = Rect2(global_position + body.position - _size() * 0.5, _size()).grow(-4.0)
	r.size.y += Data.bf("crusher", "lookahead_px")
	level.crush(r)


func _slam() -> void:
	Sound.play("slam", 1.0, 0.8)
	level.camera.add_shake(Data.bf("crusher", "slam_shake"))
	var foot: Vector2 = global_position + body.position + Vector2(0, _size().y * 0.5)
	level.fx.puff(foot, 6, Color(0.92, 0.88, 0.8, 0.9), 0.9)


# ------------------------------------------------------------------------------------ geyser
func _build_geyser() -> void:
	var vent: Sprite2D = Art.sprite("mechanism_vent", 1.0)
	vent.z_index = -2
	add_child(vent)
	_column = Art.sprite("mechanism_geyser")
	_column.centered = false
	var sz: Vector2 = Art.svg_size("mechanism_geyser")
	var w: float = float(cfg.get("width", 90.0))
	_column.scale *= Vector2(w / sz.x, float(cfg["height"]) / sz.y)
	_column.offset = Vector2(-sz.x * 0.5, -sz.y) / Art.base_scale("mechanism_geyser")
	_column.z_index = 1
	var gap: String = level.stage.gap_kind if level.stage else "water"
	var gcfg: Dictionary = Data.balance["gaps"][gap]
	_column.modulate = Color(String(gcfg.get("geyser_color", gcfg["splash"])), 0.9)
	_column.visible = false
	add_child(_column)
	active = true


func geyser_active() -> bool:
	return _geyser_on


## Column rect in world space (from the gap surface up to the eruption height).
func geyser_rect() -> Rect2:
	var w: float = float(cfg.get("width", 90.0))
	var h: float = float(cfg["height"])
	return Rect2(global_position + Vector2(-w * 0.5, -h), Vector2(w, h))


func _update_geyser(delta: float) -> void:
	if level.stage:
		position.y = level.stage.surface_y
	var period: float = float(cfg["period_s"])
	var burst: float = float(cfg["burst_s"])
	var u: float = fposmod(_time + float(cfg.get("phase", 0.0)), period)
	var on: bool = u < burst
	var warn: bool = not on and u > period - Data.bf("geyser", "warn_s")
	if warn and not _warned:
		_warned = true
		level.fx.puff(global_position + Vector2(0, -10), 3, Color(1, 1, 1, 0.8), 0.5)
	if on and not _geyser_on:
		_warned = false
		Sound.play("geyser", 0.7)
		_column.visible = true
		_column.scale.y = absf(_column.scale.y) * 0.2
		var full: float = float(cfg["height"]) / Art.svg_size("mechanism_geyser").y * Art.base_scale("mechanism_geyser").y
		_column.create_tween().tween_property(_column, "scale:y", full, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not on and _geyser_on:
		var tw: Tween = _column.create_tween()
		tw.tween_property(_column, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			_column.visible = false
			_column.modulate.a = 0.9)
	_geyser_on = on
	if on:
		_column.skew = sin(_time * 9.0) * 0.04
		level.geyser_push(self, delta)


## Decorative wooden crane / gantry the rope or crusher hangs from (no collision).
## "frame": {"posts": [world x...], "top": world y of the beam, "bottom": world y of the post feet,
##           "beam": [world x from, world x to]}
func _build_frame(fr: Dictionary) -> void:
	var top: float = float(fr["top"]) - position.y
	var bottom: float = float(fr["bottom"]) - position.y
	var wood: Color = Color("#a8642e")
	var dark: Color = Color("#3a2212")
	var lines: Array = []
	for px: Variant in fr.get("posts", []):
		var x: float = float(px) - position.x
		lines.append([Vector2(x, top - 10.0), Vector2(x, bottom), 16.0])
	var beam: Array = fr.get("beam", [])
	if beam.size() == 2:
		lines.append([Vector2(float(beam[0]) - position.x, top), Vector2(float(beam[1]) - position.x, top), 18.0])
	for pass_i: int in 2:
		for l: Array in lines:
			var line: Line2D = Line2D.new()
			line.points = PackedVector2Array([l[0], l[1]])
			line.width = float(l[2]) + (5.0 if pass_i == 0 else 0.0)
			line.default_color = dark if pass_i == 0 else wood
			line.z_index = -2
			add_child(line)
	for l2: Array in lines:
		var hl: Line2D = Line2D.new()
		hl.points = PackedVector2Array([l2[0] + Vector2(-3, -3), l2[1] + Vector2(-3, -3)])
		hl.width = 3.0
		hl.default_color = Color(1, 0.85, 0.6, 0.35)
		hl.z_index = -2
		add_child(hl)


# ------------------------------------------------------------------------------------ Phase D
## Reverse siege: the engine stops and goes down into the gap, taking its cargo with it.
func sink() -> void:
	if _sinking:
		return
	_sinking = true
	Sound.play("splash", 1.0, 0.8)
	Sound.play("creak", 0.8, 0.7)
	level.wake_near(body.global_position, float(cfg["size"][0]))


## Text the level floats when this mechanism fires.
func callout_text() -> String:
	match kind:
		"lever":
			return "LEVER!"
		"windmill":
			return "JAMMED!"
		"shield_ring":
			return "SHIELD STOPPED!"
		"rune_switch":
			return "SECRET SWITCH!"
		"trapdoor":
			return "THE LEDGE GIVES WAY!" if String(cfg.get("style", "")) in ["rock", "timber"] else "TRAP DOOR!"
		"flood":
			return "FLOOD!"
	if kind == "windmill" and cfg.has("start_on"):
		return "THE WHEEL TURNS!"
	return "MECHANISM!"


func _triggers() -> Array:
	return cfg.get("triggers", [])


func _make_sensor(radius: float, offset: Vector2, mask: int) -> Area2D:
	var a: Area2D = Area2D.new()
	a.collision_layer = 0
	a.collision_mask = mask
	a.monitorable = false
	var col: CollisionShape2D = CollisionShape2D.new()
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = radius
	col.shape = c
	col.position = offset
	a.add_child(col)
	add_child(a)
	return a


## The point a sensor-type mechanism reacts at (lever knob, hub, switch disc).
func hit_point() -> Vector2:
	match kind:
		"lever":
			return global_position + Vector2(0, -Data.bf("lever", "height") * 0.9)
		"windmill", "shield_ring":
			return global_position + follow_offset()
		"rune_switch":
			return global_position
		"trapdoor":
			return to_global(Vector2(-float(cfg.get("hinge", -1)) * _size().x * 0.5, 0))
		"flood":
			return global_position + Vector2(0, -_size().y * 0.5)
	return global_position


func reacts_to_hits() -> bool:
	match kind:
		"lever":
			return not active
		"windmill":
			return not jammed and not cfg.has("start_on")
		"rune_switch":
			return revealed and not active
		"flood":
			return not active
	return false


## Blasts, fire, quakes and beams near the hit point (Level.hit_mechanisms_near).
func on_blast(pos: Vector2, radius: float) -> void:
	if not reacts_to_hits():
		return
	var reach: float = radius + (Data.bf("rotor", "hub_r") if kind == "windmill" else Data.bf("flood", "gate_sensor_r") if kind == "flood" else Data.bf("lever", "sensor_r") * 0.5)
	if pos.distance_to(hit_point()) < reach:
		_hit()


func _hit() -> void:
	match kind:
		"lever":
			_flip_lever()
		"windmill":
			jam()
		"rune_switch":
			_press_switch()
		"flood":
			_open_flood(true)


# ---- flood gate
func _build_flood() -> void:
	var size: Vector2 = _size()
	flood = Flood.new()
	flood.setup(level, cfg)
	add_child(flood)
	body = _make_body(size, "mechanism_gate")
	body.position = Vector2(0, -size.y * 0.5)
	body.z_index = 2
	_gate_col = body.get_child(0) as CollisionShape2D
	_sensor = _make_sensor(Data.bf("flood", "gate_sensor_r"), Vector2(0, -size.y * 0.5), int(Data.b("layers", "projectiles")))
	_sensor.body_entered.connect(func(other: Node) -> void:
		if other is Projectile and reacts_to_hits():
			_hit())


func _open_flood(scored: bool) -> void:
	if active:
		return
	active = true
	_gate_col.set_deferred("disabled", true)
	var h: float = _size().y
	var tw: Tween = body.create_tween().set_parallel()
	tw.tween_property(body, "position:y", body.position.y - h * 0.9, Data.bf("flood", "gate_open_s")).set_trans(Tween.TRANS_BACK)
	tw.tween_property(body, "modulate:a", 0.0, Data.bf("flood", "gate_open_s") * 1.6)
	level.fx.puff(hit_point(), 6, Color(0.9, 0.97, 1.0, 0.9), 0.9)
	flood.release()
	level.camera.add_shake(8.0)
	if scored:
		level.on_mechanism_activated(self, int(Data.b("flood", "score")))


# ---- water wheel (a windmill that waits for its trigger)
func _start_wheel(scored: bool) -> void:
	if not jammed:
		return
	jammed = false
	active = true
	_time = 0.0
	Sound.play("gears", 1.0)
	Sound.play("creak", 0.8)
	if scored:
		level.on_mechanism_activated(self)


# ---- lever
func _build_lever() -> void:
	var h: float = Data.bf("lever", "height")
	var base: Sprite2D = _sized_sprite("mechanism_lever_base", Vector2(h * 0.83, h * 0.62))
	base.position.y = -h * 0.31
	add_child(base)
	_handle = Art.sprite("mechanism_lever_handle")
	var hs: Vector2 = Art.svg_size("mechanism_lever_handle")
	_handle.scale *= h / hs.y
	_handle.offset = Vector2(0, -hs.y * 0.42 / Art.SVG_SCALE)
	_handle.position = Vector2(0, -h * 0.5)
	_handle.rotation = deg_to_rad(-Data.bf("lever", "angle_deg") * float(cfg.get("facing", 1)))
	_handle.z_index = -1
	add_child(_handle)
	var mask: int = int(Data.b("layers", "projectiles")) | int(Data.b("layers", "blocks"))
	_sensor = _make_sensor(Data.bf("lever", "sensor_r"), Vector2(0, -h * 0.9), mask)
	_sensor.body_entered.connect(_on_sensor_body)


func _on_sensor_body(other: Node) -> void:
	if not reacts_to_hits():
		return
	if other is Projectile:
		_hit()
	elif other is Block and (other as Block).linear_velocity.length() > Data.bf("lever", "min_block_speed"):
		_hit()


func _flip_lever() -> void:
	active = true
	var to: float = deg_to_rad(Data.bf("lever", "angle_deg") * float(cfg.get("facing", 1)))
	_handle.create_tween().tween_property(_handle, "rotation", to, Data.bf("lever", "flip_s")) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("lever", 0.9)
	level.fx.sparks(hit_point(), 6)
	level.on_mechanism_activated(self, int(Data.b("lever", "score")))
	for t: Variant in _triggers():
		level.activate_trigger(String(t))


# ---- windmill / shield ring
func _build_rotor() -> void:
	body = AnimatableBody2D.new()
	var hits_blocks: bool = bool(cfg.get("hits_blocks", false))
	body.collision_layer = int(Data.b("layers", "world" if hits_blocks else "shield"))
	body.collision_mask = 0
	body.sync_to_physics = true
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.bounce = 0.35
	body.physics_material_override = pm
	add_child(body)
	_angle = deg_to_rad(float(cfg.get("phase_deg", 0.0)))
	if kind == "windmill":
		var n: int = int(cfg.get("arms", 4))
		var arm_len: float = float(cfg.get("arm_len", 260))
		var arm_w: float = float(cfg.get("arm_w", 56))
		for i: int in n:
			var a: float = TAU * float(i) / float(n)
			_add_rotor_piece("mechanism_windmill_arm", Vector2(arm_len, arm_w), Vector2.from_angle(a) * arm_len * 0.5, a)
		_hub = _sized_sprite("mechanism_windmill_hub", Vector2.ONE * Data.bf("rotor", "hub_r") * 2.2)
		_hub.z_index = 1
		add_child(_hub)
		_sensor = _make_sensor(Data.bf("rotor", "hub_r"), Vector2.ZERO, int(Data.b("layers", "projectiles")))
		_sensor.body_entered.connect(_on_sensor_body_hub)
	else:
		var n2: int = int(cfg.get("plates", 3))
		var radius: float = float(cfg.get("radius", 160))
		var plate_len: float = float(cfg.get("plate_len", 150))
		for i2: int in n2:
			var a2: float = TAU * float(i2) / float(n2)
			_add_rotor_piece("mechanism_shield_plate", Vector2(plate_len, 30), Vector2.from_angle(a2) * radius, a2 + PI * 0.5)
	if kind == "windmill" and String(cfg.get("style", "")) == "wheel":
		_dress_wheel()
	body.rotation = _angle
	active = true
	if cfg.has("start_on"):
		jammed = true
		active = false
		trigger_id = String(cfg["start_on"])


## Water-wheel look: a timber rim and paddle boards on the arm tips.
func _dress_wheel() -> void:
	var r: float = float(cfg.get("arm_len", 240))
	var rim: Line2D = Line2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 33:
		pts.append(Vector2.from_angle(TAU * float(i) / 32.0) * r * 0.86)
	rim.points = pts
	rim.width = 18.0
	rim.default_color = Color("#8a5a2a")
	rim.z_index = -1
	body.add_child(rim)
	var edge: Line2D = rim.duplicate() as Line2D
	edge.width = 24.0
	edge.default_color = Color("#3a2212")
	edge.z_index = -2
	body.add_child(edge)
	var n: int = int(cfg.get("arms", 8))
	for i2: int in n:
		var a: float = TAU * float(i2) / float(n)
		_add_rotor_piece("block_plank_short_0", Vector2(120, 26), Vector2.from_angle(a) * r, a + PI * 0.5)


func _add_rotor_piece(art_name: String, size: Vector2, at: Vector2, rot: float) -> void:
	var col: CollisionShape2D = CollisionShape2D.new()
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = size * Vector2(1.0, 0.7)
	col.shape = r
	col.position = at
	col.rotation = rot
	body.add_child(col)
	var sp: Sprite2D = _sized_sprite(art_name, size)
	sp.position = at
	sp.rotation = rot
	body.add_child(sp)


func _on_sensor_body_hub(other: Node) -> void:
	if other is Projectile and reacts_to_hits():
		_hit()


## Offset of the moving deck this mechanism rides ("follow": mechanism index), else zero.
func follow_offset() -> Vector2:
	var i: int = int(cfg.get("follow", -1))
	if i < 0 or i >= level.mechanisms.size():
		return Vector2.ZERO
	var m: CastleMechanism = level.mechanisms[i]
	return m.body.position if is_instance_valid(m) and m.body else Vector2.ZERO


func target_dps() -> float:
	return 0.0 if jammed else float(cfg.get("dps", 40.0)) * speed_mult


func _update_rotor(delta: float) -> void:
	var ease_k: float = smoothstep(0.0, Data.bf("rotor", "ease_in_s"), _time)
	var goal: float = deg_to_rad(target_dps()) * (ease_k if not jammed else 1.0)
	var rate: float = delta / maxf(0.05, Data.bf("rotor", "jam_s")) if jammed else 1.0
	_spin = lerpf(_spin, goal, clampf(rate, 0.0, 1.0)) if jammed else goal
	_angle += _spin * delta
	# One transform assignment per frame (sync_to_physics). Riders of a moving deck follow it.
	var off: Vector2 = follow_offset()
	body.transform = Transform2D(_angle, off)
	if _hub:
		_hub.position = off
		_hub.rotation = _angle
	if _sensor:
		_sensor.position = off


## Windmill: hub hit. Shield ring: its trigger fired. Both spin down and stay still.
func jam() -> void:
	if jammed:
		return
	jammed = true
	active = true
	Sound.play("gears", 0.9)
	Sound.play("metal_hit", 0.8)
	level.fx.sparks(global_position, 12)
	level.fx.puff(global_position, 5, Color(0.6, 0.6, 0.6, 0.8), 1.0)
	if _hub:
		_hub.modulate = Color(0.6, 0.6, 0.65)
	var pts: int = int(Data.b("rotor", "jam_score" if kind == "windmill" else "shield_stop_score"))
	level.on_mechanism_activated(self, pts)
	for t: Variant in _triggers():
		level.activate_trigger(String(t))


# ---- hidden rune switch
func _build_rune_switch() -> void:
	var r: float = Data.bf("rune_switch", "sensor_r")
	var disc: Sprite2D = _sized_sprite("mechanism_rune_switch", Vector2.ONE * r * 1.7)
	disc.z_index = -1
	disc.modulate = Color(0.55, 0.55, 0.6)
	add_child(disc)
	_glyph = disc
	_sensor = _make_sensor(r, Vector2.ZERO, int(Data.b("layers", "projectiles")))
	_sensor.body_entered.connect(func(other: Node) -> void:
		if other is Projectile and reacts_to_hits():
			_hit())


func is_covered() -> bool:
	var p: Vector2 = global_position
	for b: Block in level.blocks:
		if not is_instance_valid(b) or b.dead:
			continue
		var local: Vector2 = b.global_transform.affine_inverse() * p
		if absf(local.x) < b.size.x * 0.5 and absf(local.y) < b.size.y * 0.5:
			return true
	return false


func _update_rune_switch(delta: float) -> void:
	if active:
		return
	if revealed:
		_glow_t += delta
		var k: float = 0.5 + 0.5 * sin(_glow_t * TAU * Data.bf("rune_switch", "pulse_hz"))
		_glyph.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.6, 2.0, 2.2), k)
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = Data.bf("rune_switch", "check_s")
	if not is_covered():
		revealed = true
		Sound.play("switch_click", 0.6)
		level.fx.sparks(global_position, 8)
		level.fx.float_text(global_position + Vector2(0, -40), "?", Color("#7ae8ff"), 40)


func _press_switch() -> void:
	active = true
	_glyph.modulate = Color(2.2, 2.4, 2.6)
	_glyph.create_tween().tween_property(_glyph, "modulate", Color(0.8, 1.0, 1.1), 0.6)
	Sound.play("switch_click", 1.0)
	Sound.play("rune_charge", 0.7)
	level.fx.flash(global_position, 90.0)
	level.on_mechanism_activated(self, int(Data.b("rune_switch", "score")))
	for t: Variant in _triggers():
		level.activate_trigger(String(t))


# ---- trap door
func _build_trapdoor() -> void:
	var size: Vector2 = _size()
	var hinge: float = float(cfg.get("hinge", -1))
	# The node sits on the hinge; the panel extends from it.
	position.x += hinge * size.x * 0.5
	_origin = position
	body = AnimatableBody2D.new()
	body.collision_layer = int(Data.b("layers", "world"))
	body.collision_mask = 0
	body.sync_to_physics = true
	var col: CollisionShape2D = CollisionShape2D.new()
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = size
	col.shape = r
	col.position = Vector2(-hinge * size.x * 0.5, 0)
	body.add_child(col)
	if String(cfg.get("style", "")) in ["rock", "timber"]:
		_dress_ledge(size, hinge)
	else:
		var sp: Sprite2D = _sized_sprite("mechanism_trapdoor", size)
		sp.position = col.position
		body.add_child(sp)
	add_child(body)


## Breakable-ground look: a rock shelf, thick at the hinge, tapering under the far end, with cracks.
func _dress_ledge(size: Vector2, hinge: float) -> void:
	var rc: Dictionary = Data.balance["ramps"]["rock" if String(cfg.get("style", "")) == "rock" else "wood"]
	var far: float = -hinge * size.x
	var hy: float = size.y * 0.5
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0, -hy), Vector2(far, -hy), Vector2(far, hy * 0.2),
		Vector2(far * 0.7, hy + 18.0), Vector2(far * 0.35, hy + 40.0), Vector2(0, hy + 70.0)])
	var fill: Polygon2D = Polygon2D.new()
	fill.polygon = pts
	fill.color = Color(String(rc["fill"]))
	body.add_child(fill)
	var edge: Line2D = Line2D.new()
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	edge.points = loop
	edge.width = 4.0
	edge.default_color = Color("#3a2212")
	body.add_child(edge)
	var top: Line2D = Line2D.new()
	top.points = PackedVector2Array([Vector2(0, -hy + 4.0), Vector2(far, -hy + 4.0)])
	top.width = 6.0
	top.default_color = Color(String(rc["top"]))
	body.add_child(top)
	var crack: Line2D = Line2D.new()
	var s: float = -hinge
	crack.points = PackedVector2Array([Vector2(s * 14, -hy), Vector2(s * 30, -hy + 18), Vector2(s * 18, 0),
			Vector2(s * 36, hy + 14), Vector2(s * 26, hy + 46)])
	crack.width = 4.0
	crack.default_color = Color("#3a2212")
	body.add_child(crack)


func _open_trapdoor(scored: bool) -> void:
	if active:
		return
	active = true
	var hinge: float = float(cfg.get("hinge", -1))
	var to: float = -hinge * Data.bf("trapdoor", "open_deg")
	var rock: bool = String(cfg.get("style", "")) in ["rock", "timber"]
	var tw: Tween = body.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(func(deg: float) -> void:
		body.rotation_degrees = deg
		_wake_riders(), 0.0, to * (0.45 if rock else 1.0), Data.bf("trapdoor", "open_s")).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if rock:
		# The broken shelf snaps off and drops into the gap with everything on it.
		level.fx.puff(hit_point(), 8, Color(0.75, 0.65, 0.55, 0.9), 1.1)
		level.camera.add_shake(14.0)
		Sound.play("stone_break", 1.0)
		tw.tween_method(func(k: float) -> void:
			body.position = Vector2(0, Data.bf("trapdoor", "ledge_drop_px") * k * k)
			body.rotation_degrees = to * lerpf(0.45, 1.0, k)
			_wake_riders(), 0.0, 1.0, Data.bf("trapdoor", "ledge_drop_s"))
	Sound.play("trapdoor", 0.9)
	if scored:
		level.on_mechanism_activated(self, int(Data.b("trapdoor", "score")))


## Wake whatever rests on the panel (sleeping bodies would otherwise hang in the air).
func _wake_riders() -> void:
	var c: Vector2 = hit_point()
	var half: float = _size().x * 0.6
	for n: Node in level.world.get_children():
		if n is RigidBody2D:
			var p: Vector2 = (n as Node2D).global_position
			if absf(p.x - c.x) < half and p.y < c.y + 10.0 and p.y > c.y - 400.0:
				(n as RigidBody2D).sleeping = false
