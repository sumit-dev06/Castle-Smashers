class_name Replay
extends Node
## Records the moving pieces of a level (blocks, archers, heroes, mechanism bodies) at `replay.hz`
## and plays a time window back as ghost sprites, slowed down, with letterbox bars. The live world
## pieces are hidden during playback and shown again afterwards. Tunables: balance.json -> "replay".

signal finished

var level: Level
var playing: bool = false
var frame: int = 0
## Actor: {node, ghost_src: Array[Dictionary], first: int, last: int, xs: PackedFloat32Array,
##         looks: Array [[frame, texture, scale, offset]]}
var _actors: Dictionary = {}
## [frame, kind, pos, size]
var _events: Array = []
var _acc: float = 0.0
var _dt: float = 0.05
var _max_frames: int = 1800

var _ghosts: Array = []
var _hidden: Array = []
var _t: float = 0.0
var _f0: int = 0
var _f1: int = 0
var _next_event: int = 0
var _ui: CanvasLayer
var _cam_saved: Array = []


func _ready() -> void:
	_dt = 1.0 / Data.bf("replay", "hz")
	_max_frames = int(Data.bf("replay", "max_s") * Data.bf("replay", "hz"))
	process_mode = Node.PROCESS_MODE_ALWAYS


func time_of(f: int) -> float:
	return float(f) * _dt


func frame_of(t: float) -> int:
	return int(t / _dt)


func has_footage(t0: float, t1: float) -> bool:
	return t1 - t0 >= Data.bf("replay", "min_s") * 0.5 and frame_of(t0) < frame


func event(kind: String, pos: Vector2, size: float, extra: Variant = "") -> void:
	if not playing:
		_events.append([frame, kind, pos, size, extra])


func _physics_process(delta: float) -> void:
	if playing or level == null or frame >= _max_frames:
		return
	_acc += delta
	if _acc < _dt:
		return
	_acc -= _dt
	_sample()
	frame += 1


func _sample() -> void:
	for n: Node in level.world.get_children():
		var target: Node2D = null
		if n is Block or n is Archer or n is Projectile:
			target = n
		elif n is CastleMechanism and (n as CastleMechanism).body != null:
			target = (n as CastleMechanism).body
		if target != null:
			_record(target)


func _alive(n: Variant) -> bool:
	return is_instance_valid(n) and not (n as Node).is_queued_for_deletion() and (n as Node2D).is_visible_in_tree()


func _record(n: Node2D) -> void:
	if not _alive(n):
		return
	var id: int = n.get_instance_id()
	var a: Dictionary = _actors.get(id, {})
	if a.is_empty():
		a = {"node": n, "src": _snapshot(n), "first": frame, "last": frame,
			"xs": PackedFloat32Array(), "looks": []}
		_actors[id] = a
	elif int(a["last"]) != frame - 1:
		return  # it was gone for a frame: the track ended there
	var gp: Vector2 = n.global_position
	var xs: PackedFloat32Array = a["xs"]
	xs.append(gp.x)
	xs.append(gp.y)
	xs.append(n.global_rotation)
	a["xs"] = xs
	a["last"] = frame
	var main: Sprite2D = _main_sprite(n)
	if main:
		var looks: Array = a["looks"]
		if looks.is_empty() or looks[-1][1] != main.texture or looks[-1][2] != main.scale or looks[-1][4] != main.self_modulate:
			looks.append([frame, main.texture, main.scale, main.offset, main.self_modulate])


func _main_sprite(n: Node) -> Sprite2D:
	for c: Node in n.get_children():
		if c is Sprite2D:
			return c
	return null


## Visual copy data of every sprite directly under the node (first one is the main sprite).
func _snapshot(n: Node2D) -> Array:
	var out: Array = []
	for c: Node in n.get_children():
		if c is Sprite2D and (c as Sprite2D).visible and (c as Sprite2D).texture != null:
			var s: Sprite2D = c
			out.append({"tex": s.texture, "pos": s.position, "rot": s.rotation, "scale": s.scale,
				"offset": s.offset, "centered": s.centered, "flip": s.flip_h, "mod": s.modulate,
				"smod": s.self_modulate, "z": s.z_index})
	return out


# ------------------------------------------------------------------------------------ playback
## Plays world time [t0, t1] back. Returns false when there is nothing to show.
func play(t0: float, t1: float, focus: Vector2) -> bool:
	_f0 = clampi(frame_of(maxf(0.0, t0)), 0, maxi(0, frame - 1))
	_f1 = clampi(frame_of(t1), _f0 + 1, maxi(_f0 + 1, frame - 1))
	if _f1 <= _f0 or playing:
		return false
	playing = true
	_t = float(_f0)
	_next_event = 0
	while _next_event < _events.size() and int(_events[_next_event][0]) < _f0:
		_next_event += 1
	for id: int in _actors:
		var a: Dictionary = _actors[id]
		if _alive(a["node"]):
			var nd: Node2D = a["node"]
			nd.visible = false
			_hidden.append(nd)
		if int(a["last"]) < _f0 or int(a["first"]) > _f1:
			continue
		var g: Node2D = Node2D.new()
		for sd: Dictionary in a["src"]:
			var s: Sprite2D = Sprite2D.new()
			s.texture = sd["tex"]
			s.position = sd["pos"]
			s.rotation = sd["rot"]
			s.scale = sd["scale"]
			s.offset = sd["offset"]
			s.centered = sd["centered"]
			s.flip_h = sd["flip"]
			s.modulate = sd["mod"]
			s.self_modulate = sd["smod"]
			s.z_index = sd["z"]
			g.add_child(s)
		g.visible = false
		level.world.add_child(g)
		_ghosts.append([g, a])
	_build_ui()
	var cam: GameCamera = level.camera
	_cam_saved = [cam.cine, cam.position, cam.zoom]
	cam.cine = true
	var dv: Array = cam.default_view()
	var pull: float = Data.bf("chain", "cam_pull")
	cam.position = Vector2(lerpf((dv[0] as Vector2).x, focus.x, pull), (dv[0] as Vector2).y)
	cam.zoom = Vector2.ONE * float(dv[1]) * (1.0 + Data.bf("chain", "cam_zoom"))
	return true


func _process(delta: float) -> void:
	if not playing:
		return
	_t += delta / _dt * Data.bf("replay", "speed")
	if _t >= float(_f1):
		stop()
		return
	var f: int = int(_t)
	var k: float = _t - float(f)
	for pair: Array in _ghosts:
		var g: Node2D = pair[0]
		var a: Dictionary = pair[1]
		var first: int = int(a["first"])
		var last: int = int(a["last"])
		if f < first or f > last:
			g.visible = false
			continue
		g.visible = true
		var xs: PackedFloat32Array = a["xs"]
		var i0: int = (f - first) * 3
		var i1: int = mini(f + 1 - first, last - first) * 3
		g.global_position = Vector2(lerpf(xs[i0], xs[i1], k), lerpf(xs[i0 + 1], xs[i1 + 1], k))
		g.global_rotation = lerp_angle(xs[i0 + 2], xs[i1 + 2], k)
		_apply_look(g, a["looks"], f)
	while _next_event < _events.size() and int(_events[_next_event][0]) <= f:
		_play_event(_events[_next_event])
		_next_event += 1


func _apply_look(g: Node2D, looks: Array, f: int) -> void:
	if looks.is_empty() or g.get_child_count() == 0:
		return
	var pick: Array = looks[0]
	for l: Array in looks:
		if int(l[0]) <= f:
			pick = l
		else:
			break
	var s: Sprite2D = g.get_child(0)
	s.texture = pick[1]
	s.scale = pick[2]
	s.offset = pick[3]
	s.self_modulate = pick[4]


func _play_event(e: Array) -> void:
	var pos: Vector2 = e[2]
	var size: float = float(e[3])
	match String(e[1]):
		"break":
			level.fx.puff(pos, 4, Color(0.95, 0.9, 0.8, 0.8), 1.0)
			level.fx.debris(pos, String(e[4]) if e.size() > 4 else "wood", 4, 420.0)
			Sound.play("wood_break", 0.6)
		"explode":
			level.fx.flash(pos, size)
			level.fx.puff(pos, 8, Color(1, 0.8, 0.5, 0.9), 1.6)
			level.camera.add_shake(10.0)
			Sound.play("explosion", 0.8)
		"ko":
			level.fx.puff(pos, 6, Color(1, 1, 1, 0.9), 0.9)
			Sound.play("enemy_ko", 0.7)
		"splash":
			level.splash(pos, size)
		"beam":
			level.fx.beam(pos, e[4], size)
			Sound.play("rune_beam", 0.7)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			stop())
	_ui.add_child(root)
	var bar_h: float = Data.bf("story", "letterbox_px")
	for top: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color(0.06, 0.04, 0.06)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top:
			bar.offset_bottom = bar_h
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -bar_h
		root.add_child(bar)
	var lbl: Label = UIKit.label("REPLAY", 30, Color("#ffd23a"), 6)
	lbl.position = Vector2(66, 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)
	var dot: ColorRect = ColorRect.new()
	dot.color = Color("#ff4040")
	dot.size = Vector2(16, 16)
	dot.position = Vector2(40, 15)
	root.add_child(dot)
	var blink: Tween = dot.create_tween().set_loops()
	blink.tween_property(dot, "modulate:a", 0.15, 0.4)
	blink.tween_property(dot, "modulate:a", 1.0, 0.4)
	var tip: Label = UIKit.label("Tap to skip", 22, Color(1, 1, 1, 0.8), 4, false)
	tip.anchor_left = 1.0
	tip.anchor_right = 1.0
	tip.offset_left = -230
	tip.offset_top = 10
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tip)


func stop() -> void:
	if not playing:
		return
	playing = false
	for pair: Array in _ghosts:
		(pair[0] as Node2D).queue_free()
	_ghosts.clear()
	for nd: Node2D in _hidden:
		if is_instance_valid(nd):
			nd.visible = true
	_hidden.clear()
	if _ui:
		_ui.queue_free()
		_ui = null
	var cam: GameCamera = level.camera
	cam.cine = bool(_cam_saved[0])
	cam.position = _cam_saved[1]
	cam.zoom = _cam_saved[2]
	finished.emit()
