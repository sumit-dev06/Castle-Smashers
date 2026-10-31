extends Node2D
## Twister's tornado: a funnel of spinning wind streaks from the ground up to the hero, drawn as
## tilted ellipse arcs that turn faster near the bottom. Settings: projectiles.json cyclone.funnel.
## Attach to the flying Twister; `ground_offset` is how far below it the ground is.

var ground_offset: float = 170.0
var cfg: Dictionary = {}
var _t: float = 0.0
var _fade: float = 0.0
var _closing: bool = false
## Two layers: the back half of every streak behind the hero, the front half over it.
var front: bool = false


func setup(p_cfg: Dictionary, p_ground_offset: float, p_front: bool = false) -> void:
	cfg = p_cfg
	ground_offset = p_ground_offset
	front = p_front
	show_behind_parent = not front


## Spins down and removes itself.
func close() -> void:
	_closing = true


func _process(delta: float) -> void:
	_t += delta
	_fade = move_toward(_fade, 0.0 if _closing else 1.0, delta / float(cfg.get("fade_s", 0.25)))
	if _closing and _fade <= 0.0:
		queue_free()
		return
	global_rotation = 0.0
	# The bottom of the funnel always touches the ground (y = 0) below the hovering hero.
	ground_offset = maxf(40.0, -global_position.y)
	queue_redraw()


func _draw() -> void:
	var rings: int = int(cfg.get("rings", 8))
	var top_y: float = -float(cfg.get("above_px", 90.0))
	var bottom_y: float = ground_offset
	var r_top: float = float(cfg.get("top_radius", 150.0))
	var r_bot: float = float(cfg.get("bottom_radius", 22.0))
	var squash: float = float(cfg.get("squash", 0.28))
	var spin: float = float(cfg.get("spin", 7.0))
	var col: Color = Color(String(cfg.get("color", "#e9fffb")))
	var edge: Color = Color(String(cfg.get("edge", "#3a8f8a")))
	var width: float = float(cfg.get("width", 5.0))
	for i: int in rings:
		var k: float = float(i) / float(maxi(rings - 1, 1))  # 0 top .. 1 bottom
		# Funnel shape: wide at the top, narrowing quickly near the ground, with a wobble.
		var y: float = lerpf(top_y, bottom_y, k) + sin(_t * 5.0 + i) * 4.0
		var r: float = lerpf(r_top, r_bot, pow(k, 0.7))
		var sway: float = sin(_t * 3.1 + k * 3.0) * 14.0 * k
		var phase: float = _t * spin * (1.0 + k * 0.9) + i * 1.7
		var a: float = (0.95 - k * 0.3) * _fade
		for s: int in 2:
			var start: float = phase + s * PI
			var pts: PackedVector2Array = PackedVector2Array()
			var is_front: bool = sin(start + 0.95) > 0.0
			if is_front != front:
				continue
			for j: int in 14:
				var ang: float = start + float(j) / 13.0 * 1.9
				pts.append(Vector2(cos(ang) * r + sway, sin(ang) * r * squash + y))
			var w: float = width * (1.0 - k * 0.4)
			draw_polyline(pts, Color(edge, a * (0.7 if front else 0.4)), w + 3.0, true)
			draw_polyline(pts, Color(col, a * (1.0 if front else 0.6)), w, true)
