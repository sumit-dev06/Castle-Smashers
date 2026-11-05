class_name Gadget
extends Node2D
## Round 4 gadgets for levels 51-75, built from level JSON "gadgets" (numbers in balance.gadgets).
##   portal   a ring paired with another ("pair": gadget index). Shots and small blocks that enter
##            come out of the partner moving along its "dir" (degrees, 0 = right, 90 = down).
##   gravity  a field ("size") that replaces gravity with "g" [x, y] px/s² (applied as a force on
##            everything inside, see _push_bodies). "start_on": false makes
##            it wait for its "trigger"; a trigger on a running field switches it off. With
##            "duration_s" a switched-on field turns itself off again (and drops what it lifted).
##   magnet   pulls iron (or pushes, "push": true) inside "radius". Its "trigger" toggles it.
##   bumper   a springy mushroom ("radius"): shots and blocks bounce off at least "kick" px/s.
##   plate    pressure plate ("width"): fires "triggers" once "mass" worth of blocks or heroes rest on it.
##   relay    lamp board: fires "triggers" when every id in "inputs" fired within "window_s".
##   repair   a glowing crystal ("source": block index) that rebuilds broken blocks within "radius"
##            after "delay_s" while it stands.
##   conveyor belt ("width", top at y) that carries whatever rests on it at "speed" px/s (+ = right)
##            while on. "start_on": false waits for its "trigger"; every trigger toggles it.
##   fan      blower facing "dir" (degrees). While on, everything in its "reach" x "width" stream
##            gets "accel" px/s² along dir on top of gravity (shots, blocks and guards). A hit on the
##            housing jams a running fan or kicks a stopped one into life ("hit_toggles"); its
##            "trigger" toggles it too.
##   fuse     powder trail along "points" (relative to x, y). Fire (Blaze, a burning piece, a fire
##            burst) or a blast at its start lights it; the spark takes "burn_s" to reach the end,
##            then fires "triggers" and (unless "blast": false) sets off the kegs at the end.

var kind: String = ""
var cfg: Dictionary = {}
var level: Level
var index: int = 0
var trigger_id: String = ""
var on: bool = true
var done: bool = false
var partner: Gadget

var _area: Area2D
var _art: Node2D
var _t: float = 0.0
var _check_t: float = 0.0
var _g0: Vector2 = Vector2.ZERO
var _lit: Dictionary = {}
var _lamps: Array[Sprite2D] = []
var _source: Block
var _homes: Array = []
var _rings: Array[Sprite2D] = []
var _off_at: float = -1.0
var _belt: StaticBody2D
var _belt_phase: float = 0.0
var _blade: float = 0.0
var _pts: PackedVector2Array = PackedVector2Array()
var _lit_at: float = -1.0
var _burn: float = 0.0


static func g(key: String) -> float:
	return Data.bf("gadgets", key)


func setup(p_level: Level, data: Dictionary, p_index: int, data_blocks: Array[Block]) -> void:
	level = p_level
	cfg = data
	index = p_index
	kind = String(data["type"])
	trigger_id = String(data.get("trigger", ""))
	on = bool(data.get("start_on", true))
	position = Vector2(float(data["x"]), float(data["y"]))
	_g0 = Vector2.DOWN * float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	match kind:
		"portal":
			_build_portal()
		"gravity":
			_build_gravity()
		"magnet":
			_build_magnet()
		"bumper":
			_build_bumper()
		"plate":
			_build_plate()
		"relay":
			_build_relay()
		"repair":
			var si: int = int(data["source"])
			if si < data_blocks.size():
				_build_repair(data_blocks[si], data_blocks)
		"conveyor":
			_build_conveyor()
		"fan":
			_build_fan()
		"fuse":
			_build_fuse()
		_:
			push_error("Unknown gadget: %s" % kind)


## Called by Level.activate_trigger for every fired trigger id.
func on_trigger(id: String) -> void:
	if kind == "relay":
		if done or not (cfg.get("inputs", []) as Array).has(id):
			return
		_lit[id] = level.play_time()
		_update_lamps()
		Sound.play_at("switch_click", global_position, 0.9)
		for need: Variant in cfg["inputs"]:
			if not _lit.has(String(need)):
				return
		_fire("ALL LIT!")
		return
	if id != trigger_id or trigger_id.is_empty():
		return
	if kind == "fuse":
		_light()
		return
	set_on(not on)


func set_on(v: bool) -> void:
	if on == v:
		return
	on = v
	match kind:
		"gravity":
			_art.visible = on
			for b: Node2D in _area.get_overlapping_bodies():
				_enter_gravity(b) if on else _leave_gravity(b)
			level.on_gadget(self, "GRAVITY FLIPS!" if on else "GRAVITY RETURNS!")
			_off_at = _t + float(cfg["duration_s"]) if on and cfg.has("duration_s") else -1.0
		"magnet":
			_art.modulate = Color.WHITE if on else Color(0.55, 0.55, 0.6)
			level.on_gadget(self, "MAGNET ON!" if on else "MAGNET OFF!")
		"conveyor":
			_belt.constant_linear_velocity = Vector2(float(cfg.get("speed", g("conveyor_speed"))), 0.0) if on else Vector2.ZERO
			level.wake_near(global_position, float(cfg.get("width", g("conveyor_width"))) * 0.5 + 40.0)
			Sound.play_at("switch_click", global_position, 1.0)
			level.on_gadget(self, "BELT RUNNING!" if on else "BELT STOPPED!", int(g("conveyor_score")))
		"fan":
			for b: Node2D in _area.get_overlapping_bodies():
				_enter_stream(b) if on else _leave_gravity(b)
			Sound.play_at("whoosh", global_position, 1.0, 0.7 if on else 1.4)
			level.on_gadget(self, "FAN ON!" if on else "FAN JAMMED!", int(g("fan_score")))
	if level.camera:
		level.camera.add_shake(Data.bf("mechanics", "activation_shake"))


func callout_text() -> String:
	match kind:
		"portal":
			return "PORTAL!"
		"gravity":
			return "GRAVITY FIELD!"
		"magnet":
			return "MAGNET!"
		"bumper":
			return "BOUNCE PAD!"
		"plate":
			return "PRESSURE PLATE!"
		"relay":
			return "HIT BOTH IN TIME!"
		"repair":
			return "BREAK THE CRYSTAL!"
		"conveyor":
			return "CONVEYOR!"
		"fan":
			return "FAN!"
		"fuse":
			return "LIGHT THE FUSE!"
	return "GADGET!"


func hit_point() -> Vector2:
	if kind == "repair" and is_instance_valid(_source):
		return _source.global_position
	return global_position


func _fire(text: String) -> void:
	done = true
	for t: Variant in cfg.get("triggers", []):
		level.activate_trigger(String(t))
	level.on_gadget(self, text)


func _sensor(shape: Shape2D, offset: Vector2 = Vector2.ZERO) -> Area2D:
	var a: Area2D = Area2D.new()
	a.collision_layer = 0
	a.collision_mask = int(Data.b("layers", "blocks")) | int(Data.b("layers", "projectiles")) | int(Data.b("layers", "archers"))
	a.monitorable = false
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = offset
	a.add_child(col)
	add_child(a)
	return a


func _circle(r: float) -> CircleShape2D:
	var c: CircleShape2D = CircleShape2D.new()
	c.radius = r
	return c


func _box(sz: Vector2) -> RectangleShape2D:
	var r: RectangleShape2D = RectangleShape2D.new()
	r.size = sz
	return r


func _sprite(art_name: String, size: Vector2) -> Sprite2D:
	var s: Sprite2D = Art.sprite(art_name)
	var a: Vector2 = Art.svg_size(art_name)
	s.scale *= Vector2(size.x / a.x, size.y / a.y)
	return s


func _static_circle(r: float, offset: Vector2 = Vector2.ZERO, bounce: float = 0.0) -> StaticBody2D:
	var sb: StaticBody2D = StaticBody2D.new()
	sb.collision_layer = int(Data.b("layers", "world"))
	sb.collision_mask = 0
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = _circle(r)
	col.position = offset
	sb.add_child(col)
	if bounce > 0.0:
		var pm: PhysicsMaterial = PhysicsMaterial.new()
		pm.bounce = bounce
		sb.physics_material_override = pm
	add_child(sb)
	return sb


## A timber post drawn like the mechanism frames (dark outline pass, wood pass, highlight).
func _post(from: Vector2, to: Vector2) -> void:
	for pass_i: int in 3:
		var line: Line2D = Line2D.new()
		line.points = PackedVector2Array([from + (Vector2(-3, -3) if pass_i == 2 else Vector2.ZERO), to])
		line.width = [21.0, 16.0, 3.0][pass_i]
		line.default_color = [Color("#3a2212"), Color("#a8642e"), Color(1, 0.85, 0.6, 0.35)][pass_i]
		line.z_index = -2
		add_child(line)


# ------------------------------------------------------------------------------------ portal
func _build_portal() -> void:
	var r: float = float(cfg.get("radius", g("portal_radius")))
	_area = _sensor(_circle(r * 0.8))
	_area.body_entered.connect(_on_portal_body)
	_art = Node2D.new()
	add_child(_art)
	var tint: Color = Color(String(cfg.get("color", "#ff9a2a")))
	var swirl: Sprite2D = _sprite("gadget_portal_swirl", Vector2(r, r) * 2.0)
	if Art.has_ai("gadget_portal_swirl") and String(cfg.get("color", "#ff9a2a")) != "#ff9a2a":
		# The painted swirl is orange: the partner ring uses the white vector swirl, tinted.
		var vt: Texture2D = load(Art.SVG_DIR % "gadget_portal_swirl")
		swirl.texture = vt
		swirl.scale = Vector2(r, r) * 2.0 / vt.get_size()
		swirl.modulate = tint
	elif not Art.has_ai("gadget_portal_swirl"):
		swirl.modulate = tint
	_art.add_child(swirl)
	_rings.append(swirl)
	var ring: Sprite2D = _sprite("gadget_portal_ring", Vector2(r, r) * 2.2)
	_art.add_child(ring)
	var arrow: Sprite2D = Art.sprite("rune_arrow", 0.5)
	arrow.rotation_degrees = float(cfg.get("dir", 0.0))
	arrow.position = Vector2.from_angle(deg_to_rad(float(cfg.get("dir", 0.0)))) * (r + 22.0)
	arrow.modulate = tint
	_art.add_child(arrow)
	z_index = 2


func _on_portal_body(b: Node2D) -> void:
	if partner == null or not on or not (b is RigidBody2D) or b is Archer:
		return
	if b is Block:
		var blk: Block = b as Block
		if blk.held or maxf(blk.size.x, blk.size.y) > float(cfg.get("radius", g("portal_radius"))) * 1.7:
			return
	var now: float = level.play_time()
	if float(b.get_meta("portal_t", -10.0)) > now - g("portal_cooldown_s"):
		return
	b.set_meta("portal_t", now)
	_teleport.call_deferred(b as RigidBody2D)


func _teleport(b: RigidBody2D) -> void:
	if not is_instance_valid(b) or partner == null:
		return
	var a_in: float = deg_to_rad(float(cfg.get("dir", 0.0))) + PI
	var a_out: float = deg_to_rad(float(partner.cfg.get("dir", 0.0)))
	var speed: float = maxf(b.linear_velocity.length(), g("portal_min_speed"))
	var v: Vector2 = b.linear_velocity.rotated(a_out - a_in)
	v = v.normalized() * speed if v.length() > 1.0 else Vector2.from_angle(a_out) * speed
	var out_r: float = float(partner.cfg.get("radius", g("portal_radius")))
	var pos: Vector2 = partner.global_position + Vector2.from_angle(a_out) * out_r * 0.4
	PhysicsServer2D.body_set_state(b.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(b.rotation, pos))
	PhysicsServer2D.body_set_state(b.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, v)
	b.global_position = pos
	b.linear_velocity = v
	b.sleeping = false
	if b is Block:
		(b as Block).set("_prev_vel", v)
		(b as Block).set("_grace", g("portal_grace_s"))
	elif b is Projectile:
		(b as Projectile).set("_last_pos", pos)
	level.fx.flash(global_position, 60.0)
	level.fx.flash(pos, 60.0)
	level.fx.sparks(pos, 10)
	Sound.play_at("whoosh", pos, 1.0, 1.3)
	if not bool(get_meta("used", false)):
		set_meta("used", true)
		level.on_gadget(self, "PORTAL!", int(g("portal_score")))


# ------------------------------------------------------------------------------------ gravity
func _build_gravity() -> void:
	var sz: Vector2 = Vector2(float(cfg["size"][0]), float(cfg["size"][1]))
	_area = _sensor(_box(sz))
	_area.monitorable = true
	var gv: Vector2 = Vector2(float(cfg["g"][0]), float(cfg["g"][1]))
	_area.body_entered.connect(func(b: Node2D) -> void:
		if on:
			_enter_gravity(b))
	_area.body_exited.connect(_leave_gravity)
	_art = Node2D.new()
	add_child(_art)
	var field: Sprite2D = _sprite("gadget_gravity_field", sz)
	field.modulate = Color(1, 1, 1, 0.75)
	_art.add_child(field)
	var n: int = maxi(1, int(sz.x / 110.0))
	for i: int in n:
		var ar: Sprite2D = Art.sprite("rune_arrow", 0.55)
		ar.rotation = gv.angle()
		ar.position = Vector2(-sz.x * 0.5 + sz.x * (i + 0.5) / n, 0)
		ar.modulate = Color(0.75, 0.9, 1.0, 0.8)
		_art.add_child(ar)
		_rings.append(ar)
	_art.visible = on
	z_index = -1


func _enter_gravity(b: Node2D) -> void:
	if b is RigidBody2D:
		(b as RigidBody2D).sleeping = false
	if b is Block:
		(b as Block).set("_gravity", Vector2(float(cfg["g"][0]), float(cfg["g"][1])))
		(b as Block).set("_grace", g("field_grace_s"))


func _leave_gravity(b: Node2D) -> void:
	if b is Block and is_instance_valid(b):
		(b as Block).set("_gravity", _g0)
		(b as Block).set("_grace", g("field_grace_s"))


# ------------------------------------------------------------------------------------ magnet
func _build_magnet() -> void:
	var r: float = float(cfg.get("radius", g("magnet_radius")))
	_area = _sensor(_circle(r))
	_static_circle(g("magnet_head_r"))
	_art = Node2D.new()
	add_child(_art)
	if cfg.has("post"):
		_post(Vector2(0, -g("magnet_head_r") * 0.6), Vector2(0, float(cfg["post"]) - position.y))
	for i: int in 3:
		var ring: Sprite2D = _sprite("gadget_field_ring", Vector2(r, r) * 2.0)
		ring.modulate = Color("#ff6a6a") if bool(cfg.get("push", false)) else Color("#7ad8ff")
		ring.set_meta("s0", ring.scale)
		_art.add_child(ring)
		_rings.append(ring)
	var head: Sprite2D = _sprite("gadget_magnet", Vector2(g("magnet_head_r"), g("magnet_head_r")) * 2.6)
	head.rotation_degrees = float(cfg.get("facing", 0.0))
	_art.add_child(head)
	if not on:
		_art.modulate = Color(0.55, 0.55, 0.6)
	z_index = 2


func _magnetic(b: Node2D) -> bool:
	if b is Block:
		return (b as Block).mat_id in ["iron", "cart", "cannon"] and not (b as Block).held
	return false


func _tick_magnet(delta: float) -> void:
	var r: float = float(cfg.get("radius", g("magnet_radius")))
	var accel: float = float(cfg.get("accel", g("magnet_accel")))
	var sign_k: float = -1.0 if bool(cfg.get("push", false)) else 1.0
	for b: Node2D in _area.get_overlapping_bodies():
		if not _magnetic(b):
			continue
		var blk: Block = b as Block
		var to: Vector2 = global_position - blk.global_position
		var d: float = to.length()
		if d < 1.0:
			continue
		var a: Vector2 = to / d * accel * sign_k * clampf(1.15 - d / r, 0.2, 1.0)
		blk.sleeping = false
		blk.apply_central_force(a * blk.mass)
		blk.set("_gravity", _g0 + a)
		if not blk.has_meta("magnet_seen"):
			blk.set_meta("magnet_seen", true)
			if not bool(get_meta("used", false)):
				set_meta("used", true)
				level.on_gadget(self, "MAGNET!", int(g("magnet_score")))
	for i: int in _rings.size():
		var k: float = fmod(_t * 0.6 + i / 3.0, 1.0)
		if bool(cfg.get("push", false)):
			k = 1.0 - k
		_rings[i].scale = (_rings[i].get_meta("s0") as Vector2) * (1.0 - k * 0.85)
		_rings[i].modulate.a = 0.15 + 0.6 * k


# ------------------------------------------------------------------------------------ bumper
func _build_bumper() -> void:
	var r: float = float(cfg.get("radius", g("bumper_radius")))
	_static_circle(r, Vector2.ZERO, g("bumper_bounce"))
	_area = _sensor(_circle(r + 10.0))
	_area.body_entered.connect(_on_bumper_body)
	_art = Node2D.new()
	add_child(_art)
	_art.add_child(_sprite("gadget_bumper", Vector2(r, r) * 2.3))
	var stem_h: float = float(cfg.get("stem", 0.0))
	if stem_h > 0.0:
		var stem: Sprite2D = _sprite("gadget_bumper_stem", Vector2(r * 0.6, stem_h))
		stem.position = Vector2(0, r * 0.5 + stem_h * 0.5)
		stem.z_index = -1
		_art.add_child(stem)
	z_index = 1


func _on_bumper_body(b: Node2D) -> void:
	if not (b is RigidBody2D) or b is Archer:
		return
	var rb: RigidBody2D = b as RigidBody2D
	var n: Vector2 = (rb.global_position - global_position).normalized()
	var v: Vector2 = rb.linear_velocity
	var vn: float = v.dot(n)
	if vn >= 0.0:
		return
	var out: Vector2 = v - n * vn * (1.0 + g("bumper_restitution"))
	if out.length() < float(cfg.get("kick", g("bumper_kick"))):
		out = (out.normalized() if out.length() > 1.0 else n) * float(cfg.get("kick", g("bumper_kick")))
	_apply_bounce.call_deferred(rb, out)
	var tw: Tween = _art.create_tween()
	tw.tween_property(_art, "scale", Vector2(1.18, 0.82), 0.06)
	tw.tween_property(_art, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sound.play_at("pop", global_position, 1.0, 0.75)
	if not bool(get_meta("used", false)):
		set_meta("used", true)
		level.on_gadget(self, "BOING!", int(g("bumper_score")))


func _apply_bounce(rb: RigidBody2D, v: Vector2) -> void:
	if not is_instance_valid(rb):
		return
	rb.linear_velocity = v
	if rb is Block:
		(rb as Block).set("_prev_vel", v)


# ------------------------------------------------------------------------------------ plate
func _build_plate() -> void:
	var w: float = float(cfg.get("width", g("plate_width")))
	_area = _sensor(_box(Vector2(w - 8.0, 40.0)), Vector2(0, -26))
	_static_box_plate(w)
	_art = Node2D.new()
	add_child(_art)
	var base: Sprite2D = _sprite("gadget_plate_base", Vector2(w + 16.0, 26.0))
	base.position = Vector2(0, -8)
	_art.add_child(base)
	var top: Sprite2D = _sprite("gadget_plate_top", Vector2(w, 12.0))
	top.position = Vector2(0, -20)
	_art.add_child(top)
	_rings.append(top)
	_lamps.append(top)


func _static_box_plate(w: float) -> void:
	var sb: StaticBody2D = StaticBody2D.new()
	sb.collision_layer = int(Data.b("layers", "world"))
	sb.collision_mask = 0
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = _box(Vector2(w, 16.0))
	col.position = Vector2(0, -8)
	sb.add_child(col)
	add_child(sb)


func _tick_plate() -> void:
	var total: float = 0.0
	for b: Node2D in _area.get_overlapping_bodies():
		if b is Block or b is Projectile:
			total += (b as RigidBody2D).mass
	var need: float = float(cfg.get("mass", g("plate_mass")))
	_lamps[0].modulate = Color.WHITE.lerp(Color(1.6, 1.4, 0.6), clampf(total / need, 0.0, 1.0))
	if total >= need:
		_lamps[0].position.y = -14
		Sound.play_at("switch_click", global_position, 1.0)
		_fire("PLATE PRESSED!")


# ------------------------------------------------------------------------------------ relay
func _build_relay() -> void:
	_art = Node2D.new()
	add_child(_art)
	var n: int = (cfg.get("inputs", []) as Array).size()
	var w: float = 40.0 + n * 44.0
	var board: Sprite2D = _sprite("gadget_relay_board", Vector2(w, 56.0))
	_art.add_child(board)
	for i: int in n:
		var l: Sprite2D = _sprite("gadget_lamp", Vector2(32, 32))
		l.position = Vector2(-w * 0.5 + 42.0 + i * 44.0, -2)
		l.modulate = Color(0.35, 0.3, 0.3)
		_art.add_child(l)
		_lamps.append(l)
	z_index = 2


func _update_lamps() -> void:
	var inputs: Array = cfg.get("inputs", [])
	for i: int in _lamps.size():
		_lamps[i].modulate = Color(1.5, 1.3, 0.5) if _lit.has(String(inputs[i])) else Color(0.35, 0.3, 0.3)


func _tick_relay() -> void:
	var window: float = float(cfg.get("window_s", g("relay_window_s")))
	var now: float = level.play_time()
	var changed: bool = false
	for id: Variant in _lit.keys():
		if now - float(_lit[id]) > window:
			_lit.erase(id)
			changed = true
	if changed:
		_update_lamps()
		Sound.play_at("deny", global_position, 0.6)
	for i: int in _lamps.size():
		var inputs: Array = cfg.get("inputs", [])
		if _lit.has(String(inputs[i])):
			var left: float = window - (now - float(_lit[String(inputs[i])]))
			_lamps[i].modulate.a = 0.55 + 0.45 * absf(sin(now * (4.0 if left > window * 0.4 else 12.0)))


# ------------------------------------------------------------------------------------ repair
func _build_repair(src: Block, data_blocks: Array[Block]) -> void:
	_source = src
	position = src.global_position
	var r: float = float(cfg.get("radius", g("repair_radius")))
	for b: Block in data_blocks:
		if b != src and b.global_position.distance_to(src.global_position) < r:
			_homes.append({"block": b, "shape": b.shape_id, "pos": b.start_pos, "rot": b.start_rot, "wait": -1.0, "count": 0})
	_art = Node2D.new()
	add_child(_art)
	var aura: Sprite2D = _sprite("gadget_field_ring", Vector2(r, r) * 2.0)
	aura.modulate = Color(0.5, 1.0, 0.6, 0.25)
	_art.add_child(aura)
	var glow: Sprite2D = Art.sprite("heat_glow", 2.4)
	glow.modulate = Color(0.4, 1.0, 0.5, 0.7)
	_art.add_child(glow)
	_rings.append(glow)
	z_index = -1


func _tick_repair(delta: float) -> void:
	if not is_instance_valid(_source) or _source.dead:
		done = true
		if _art:
			_art.visible = false
		level.on_gadget(self, "REPAIRS STOPPED!", int(g("repair_stop_score")))
		return
	global_position = _source.global_position
	_rings[0].modulate.a = 0.45 + 0.3 * sin(_t * 3.0)
	for h: Dictionary in _homes:
		var b: Variant = h["block"]
		var gone: bool = b == null or not is_instance_valid(b) or (b as Block).dead
		if not gone or int(h["count"]) >= int(g("repair_max_per_spot")):
			continue
		if float(h["wait"]) < 0.0:
			h["wait"] = float(cfg.get("delay_s", g("repair_delay_s")))
			continue
		h["wait"] = float(h["wait"]) - delta
		if float(h["wait"]) > 0.0 or not _spot_clear(String(h["shape"]), h["pos"]):
			continue
		var nb: Block = level.spawn_block(String(h["shape"]), h["pos"])
		nb.rotation = float(h["rot"])
		nb.sleeping = true
		nb.modulate = Color(0.8, 1.8, 0.9, 0.0)
		var tw: Tween = nb.create_tween()
		tw.tween_property(nb, "modulate", Color.WHITE, 0.5)
		h["block"] = nb
		h["wait"] = -1.0
		h["count"] = int(h["count"]) + 1
		level.fx.beam(_source.global_position, nb.global_position, 8.0)
		level.fx.sparks(nb.global_position, 8)
		level.fx.float_text(nb.global_position, "REBUILT!", Color("#8dff9a"), 24)
		Sound.play_at("repair", nb.global_position, 0.9)
		return


func _spot_clear(shape: String, p: Vector2) -> bool:
	var sz: Vector2 = Vector2(float(Data.shapes[shape]["size"][0]), float(Data.shapes[shape]["size"][1]))
	for b: Block in level.blocks:
		if is_instance_valid(b) and not b.dead:
			if absf(b.global_position.x - p.x) < (sz.x + b.size.x) * 0.45 and absf(b.global_position.y - p.y) < (sz.y + b.size.y) * 0.45:
				return false
	for a: Archer in level.archers:
		if is_instance_valid(a) and a.global_position.distance_to(p) < maxf(sz.x, sz.y) * 0.5 + 30.0:
			return false
	for pr: Projectile in level.projectiles:
		if is_instance_valid(pr) and pr.global_position.distance_to(p) < maxf(sz.x, sz.y) * 0.5 + 30.0:
			return false
	return true


# ------------------------------------------------------------------------------------ tick
func _physics_process(delta: float) -> void:
	_t += delta
	if level == null or level.is_finished():
		return
	match kind:
		"portal":
			if not _rings.is_empty():
				_rings[0].rotation = -_t * 3.0
				_art.scale = Vector2.ONE * (1.0 + 0.04 * sin(_t * 2.6))
		"bumper":
			if not _art.has_meta("busy"):
				_art.position.y = sin(_t * 1.8) * 2.0
		"magnet":
			if on:
				_tick_magnet(delta)
		"gravity":
			if on:
				_push_bodies(Vector2(float(cfg["g"][0]), float(cfg["g"][1])) - _g0)
			if _off_at > 0.0 and _t >= _off_at:
				_off_at = -1.0
				set_on(false)
			for i: int in _rings.size():
				_rings[i].modulate.a = 0.4 + 0.4 * sin(_t * 4.0 + i)
		"plate":
			_check_t -= delta
			if not done and _check_t <= 0.0:
				_check_t = g("plate_check_s")
				_tick_plate()
		"relay":
			if not done:
				_tick_relay()
		"repair":
			if not done:
				_tick_repair(delta)
		"conveyor":
			if on:
				_belt_phase = fmod(_belt_phase + float(cfg.get("speed", g("conveyor_speed"))) * delta, g("conveyor_dash_px"))
				queue_redraw()
				# A resting body ignores the moving belt: keep the load awake while it runs.
				_check_t -= delta
				if _check_t <= 0.0:
					_check_t = g("plate_check_s")
					level.wake_near(global_position + Vector2(0, -60), float(cfg.get("width", g("conveyor_width"))) * 0.5 + g("conveyor_wake_px"))
		"fan":
			if on:
				_push_bodies(_fan_dir() * float(cfg.get("accel", g("fan_accel"))))
				_blade = fmod(_blade + delta * g("fan_spin"), TAU)
				queue_redraw()
		"fuse":
			_tick_fuse(delta)


## Fields (gravity, fan) push with forces every step instead of an Area2D gravity override: the physics
## server only applies an override to bodies that entered while it was already on, so a field switched
## on later (rune, lever, fan hub) would miss everything resting inside it.
func _push_bodies(extra: Vector2) -> void:
	for b: Node2D in _area.get_overlapping_bodies():
		if b is RigidBody2D and not (b as RigidBody2D).freeze:
			var rb: RigidBody2D = b as RigidBody2D
			if rb.sleeping:
				rb.sleeping = false
			rb.apply_central_force(extra * rb.mass * rb.gravity_scale)


# ------------------------------------------------------------------------------------ shared drawing
const OUTLINE: Color = Color("#3a2212")


## Hits that only matter to gadgets: blasts and fire bursts (Level.explode / Level.fire_burst).
func on_heat(pos: Vector2, radius: float) -> void:
	if kind == "fuse" and _lit_at < 0.0 and not done and pos.distance_to(global_position) < radius + g("fuse_light_r"):
		_light()


# ------------------------------------------------------------------------------------ conveyor
func _build_conveyor() -> void:
	var w: float = float(cfg.get("width", g("conveyor_width")))
	var h: float = g("conveyor_h")
	_belt = StaticBody2D.new()
	_belt.collision_layer = int(Data.b("layers", "world"))
	_belt.collision_mask = 0
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = _box(Vector2(w, h))
	col.position = Vector2(0, h * 0.5)
	_belt.add_child(col)
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = g("conveyor_friction")
	_belt.physics_material_override = pm
	if on:
		_belt.constant_linear_velocity = Vector2(float(cfg.get("speed", g("conveyor_speed"))), 0.0)
	add_child(_belt)
	z_index = 1


func _draw_conveyor() -> void:
	var w: float = float(cfg.get("width", g("conveyor_width")))
	var h: float = g("conveyor_h")
	var r: float = h * 0.5
	draw_rect(Rect2(-w * 0.5 - 3.0, -3.0, w + 6.0, h + 6.0), OUTLINE)
	draw_rect(Rect2(-w * 0.5, 0.0, w, h), Color("#4a4a52"))
	draw_rect(Rect2(-w * 0.5, 0.0, w, 4.0), Color("#8a8a96"))
	var dash: float = g("conveyor_dash_px")
	var x: float = -w * 0.5 + _belt_phase
	while x < w * 0.5 - 6.0:
		draw_line(Vector2(x, 3.0), Vector2(x + 6.0, h * 0.5), Color("#ffd23a") if on else Color("#9a8a50"), 3.0)
		draw_line(Vector2(x + 6.0, h * 0.5), Vector2(x, h - 3.0), Color("#ffd23a") if on else Color("#9a8a50"), 3.0)
		x += dash
	for sx: float in [-w * 0.5, w * 0.5]:
		draw_circle(Vector2(sx, r), r + 3.0, OUTLINE)
		draw_circle(Vector2(sx, r), r, Color("#b07a3a"))
		draw_line(Vector2(sx, r) - Vector2.from_angle(_belt_phase * 0.2) * r, Vector2(sx, r) + Vector2.from_angle(_belt_phase * 0.2) * r, OUTLINE, 3.0)


# ------------------------------------------------------------------------------------ fan
func _fan_dir() -> Vector2:
	return Vector2.from_angle(deg_to_rad(float(cfg.get("dir", 0.0))))


func _build_fan() -> void:
	var reach: float = float(cfg.get("reach", g("fan_reach")))
	var w: float = float(cfg.get("width", g("fan_width")))
	var hr: float = g("fan_housing_r")
	var dv: Vector2 = _fan_dir()
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = int(Data.b("layers", "blocks")) | int(Data.b("layers", "projectiles")) | int(Data.b("layers", "archers"))
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = _box(Vector2(reach, w))
	col.position = dv * (hr + reach * 0.5)
	col.rotation = dv.angle()
	_area.add_child(col)
	add_child(_area)
	_area.body_entered.connect(func(b: Node2D) -> void:
		if on:
			_enter_stream(b))
	_area.body_exited.connect(_leave_gravity)
	_static_circle(hr)
	var hit: Area2D = _sensor(_circle(hr + 10.0))
	hit.body_entered.connect(_on_fan_hit)
	if cfg.has("post"):
		_post(Vector2(0, hr * 0.5), Vector2(0, float(cfg["post"]) - position.y))
	z_index = 1


func _enter_stream(b: Node2D) -> void:
	if b is RigidBody2D:
		(b as RigidBody2D).sleeping = false
	if b is Block:
		(b as Block).set("_gravity", _g0 + _fan_dir() * float(cfg.get("accel", g("fan_accel"))))
		(b as Block).set("_grace", g("field_grace_s"))


func _on_fan_hit(b: Node2D) -> void:
	if not (b is Projectile) or not bool(cfg.get("hit_toggles", true)):
		return
	var now: float = level.play_time()
	if float(get_meta("hit_t", -10.0)) > now - g("fan_hit_cooldown_s"):
		return
	set_meta("hit_t", now)
	set_on.call_deferred(not on)


func _draw_fan() -> void:
	var hr: float = g("fan_housing_r")
	var dv: Vector2 = _fan_dir()
	if on:
		var reach: float = float(cfg.get("reach", g("fan_reach")))
		var w: float = float(cfg.get("width", g("fan_width")))
		var side: Vector2 = dv.orthogonal()
		for i: int in 5:
			var k: float = fmod(_t * 1.6 + i * 0.37, 1.0)
			var off: float = (float(i) / 4.0 - 0.5) * w * 0.8
			var a: Vector2 = dv * (hr + reach * k) + side * off
			draw_line(a, a + dv * 46.0, Color(1, 1, 1, 0.55 * (1.0 - k)), 4.0)
	# Housing: a timber ring with a brass rim, three blades and a hub.
	draw_circle(Vector2.ZERO, hr + 4.0, OUTLINE)
	draw_circle(Vector2.ZERO, hr, Color("#c9a24a"))
	draw_circle(Vector2.ZERO, hr - 7.0, Color("#5a3a1e"))
	for i: int in 3:
		var a2: float = _blade + i * TAU / 3.0
		var tip: Vector2 = Vector2.from_angle(a2) * (hr - 9.0)
		var s: Vector2 = Vector2.from_angle(a2 + 0.5) * (hr - 18.0)
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, s, tip]), Color("#e8e0d0"))
		draw_polyline(PackedVector2Array([Vector2.ZERO, s, tip, Vector2.ZERO]), OUTLINE, 2.0)
	draw_circle(Vector2.ZERO, 9.0, OUTLINE)
	draw_circle(Vector2.ZERO, 6.0, Color("#ffd23a") if on else Color("#8a7a60"))
	draw_line(dv * (hr + 2.0), dv * (hr + 18.0), OUTLINE, 6.0)
	draw_line(dv * (hr + 2.0), dv * (hr + 16.0), Color("#ffd23a"), 3.0)


# ------------------------------------------------------------------------------------ fuse
func _build_fuse() -> void:
	_pts.append(Vector2.ZERO)
	for p: Variant in cfg.get("points", []):
		_pts.append(Vector2(float(p[0]), float(p[1])))
	var a: Area2D = _sensor(_circle(g("fuse_light_r")))
	a.body_entered.connect(func(b: Node2D) -> void:
		if b is Projectile and String((b as Projectile).kind) == "fire":
			_light())
	z_index = 1


func _fuse_len() -> float:
	var total: float = 0.0
	for i: int in range(1, _pts.size()):
		total += _pts[i - 1].distance_to(_pts[i])
	return maxf(1.0, total)


## Point `d` px along the trail.
func _fuse_at(d: float) -> Vector2:
	for i: int in range(1, _pts.size()):
		var seg: float = _pts[i - 1].distance_to(_pts[i])
		if d <= seg:
			return _pts[i - 1].lerp(_pts[i], d / maxf(seg, 0.001))
		d -= seg
	return _pts[_pts.size() - 1]


func _light() -> void:
	if _lit_at >= 0.0 or done:
		return
	_lit_at = _t
	Sound.play_at("fire", global_position, 0.7, 1.4)
	level.on_gadget(self, "FUSE LIT!", int(g("fuse_score")))


func _tick_fuse(delta: float) -> void:
	if done:
		return
	if _lit_at < 0.0:
		_check_t -= delta
		if _check_t <= 0.0:
			_check_t = g("plate_check_s")
			for b: Block in level.blocks:
				if is_instance_valid(b) and b.is_burning() and b.global_position.distance_to(global_position) < g("fuse_light_r") + maxf(b.size.x, b.size.y) * 0.5:
					_light()
					break
		return
	_burn = clampf((_t - _lit_at) / float(cfg.get("burn_s", g("fuse_burn_s"))), 0.0, 1.0)
	queue_redraw()
	if randf() < 0.35:
		level.fx.sparks(global_position + _fuse_at(_burn * _fuse_len()), 1)
	if _burn >= 1.0:
		_fuse_end()


func _fuse_end() -> void:
	done = true
	var end: Vector2 = global_position + _pts[_pts.size() - 1]
	for t: Variant in cfg.get("triggers", []):
		level.activate_trigger(String(t))
	if bool(cfg.get("blast", true)):
		var kegs: int = 0
		for b: Block in level.blocks.duplicate():
			if is_instance_valid(b) and not b.dead and bool(b.mat.get("explodes", false)) and b.global_position.distance_to(end) < g("fuse_keg_r"):
				b.take_damage(b.hp + 1.0)
				kegs += 1
		if kegs == 0:
			var e: Dictionary = Data.materials["barrel"]["explosion"]
			level.explode(end, float(e["radius"]), float(e["impulse"]), float(e["damage"]))
	level.on_gadget(self, "KA-BOOM!" if bool(cfg.get("blast", true)) else "FUSE DONE!", int(g("fuse_score")))
	queue_redraw()


func _draw_fuse() -> void:
	var lit_d: float = _burn * _fuse_len() if _lit_at >= 0.0 else 0.0
	draw_polyline(_pts, OUTLINE, 9.0)
	draw_polyline(_pts, Color("#2a1a10"), 5.0)
	# Unburnt powder trail ahead of the spark.
	var ahead: PackedVector2Array = PackedVector2Array([_fuse_at(lit_d)])
	var run: float = 0.0
	for i: int in range(1, _pts.size()):
		run += _pts[i - 1].distance_to(_pts[i])
		if run > lit_d:
			ahead.append(_pts[i])
	if ahead.size() >= 2 and not done:
		draw_polyline(ahead, Color("#d8b070"), 4.0)
	draw_circle(Vector2.ZERO, 12.0, OUTLINE)
	draw_circle(Vector2.ZERO, 9.0, Color("#ff7a2a") if _lit_at >= 0.0 else Color("#e8d0a0"))
	if _lit_at >= 0.0 and not done:
		var p: Vector2 = _fuse_at(lit_d)
		draw_circle(p, 9.0, Color(1.0, 0.85, 0.3, 0.9))
		draw_circle(p, 5.0, Color.WHITE)


func _draw() -> void:
	match kind:
		"conveyor":
			_draw_conveyor()
		"fan":
			_draw_fan()
		"fuse":
			_draw_fuse()
