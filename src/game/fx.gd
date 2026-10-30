class_name Fx
extends Node2D
## Pooled cosmetic particles (puffs, debris, sparks) updated manually, plus floating score text.

const POOL: int = 180

var _sprites: Array[Sprite2D] = []
var _vel: PackedVector2Array = PackedVector2Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _max_life: PackedFloat32Array = PackedFloat32Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _grav: PackedFloat32Array = PackedFloat32Array()
var _grow: PackedFloat32Array = PackedFloat32Array()
var _base: PackedFloat32Array = PackedFloat32Array()
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _next: int = 0
var _font: Font


func _ready() -> void:
	z_index = 5
	_font = load("res://assets/fonts/lilita-one-latin.woff2")
	for i: int in POOL:
		var s: Sprite2D = Sprite2D.new()
		s.visible = false
		add_child(s)
		_sprites.append(s)
	_vel.resize(POOL)
	_life.resize(POOL)
	_max_life.resize(POOL)
	_spin.resize(POOL)
	_grav.resize(POOL)
	_grow.resize(POOL)
	_base.resize(POOL)
	_alpha.resize(POOL)


func _emit(art: String, pos: Vector2, vel: Vector2, life: float, scale_w: float, grav: float,
		spin: float, grow: float, color: Color = Color.WHITE) -> void:
	var i: int = _next
	_next = (_next + 1) % POOL
	var s: Sprite2D = _sprites[i]
	s.texture = Art.tex(art)
	s.position = pos
	s.rotation = randf() * TAU
	s.scale = Vector2.ONE * scale_w * Art.SVG_SCALE
	s.modulate = color
	s.visible = true
	_vel[i] = vel
	_life[i] = life
	_max_life[i] = life
	_spin[i] = spin
	_grav[i] = grav
	_grow[i] = grow
	_base[i] = scale_w * Art.SVG_SCALE
	_alpha[i] = color.a


func _process(delta: float) -> void:
	for i: int in POOL:
		if _life[i] <= 0.0:
			continue
		var s: Sprite2D = _sprites[i]
		_life[i] -= delta
		if _life[i] <= 0.0:
			s.visible = false
			continue
		var v: Vector2 = _vel[i]
		v.y += _grav[i] * delta
		var p: Vector2 = s.position + v * delta
		if _grav[i] > 0.0 and p.y > -3.0:
			p.y = -3.0
			v = Vector2(v.x * 0.5, -v.y * 0.3)
			_spin[i] *= 0.5
		_vel[i] = v
		s.position = p
		s.rotation += _spin[i] * delta
		var k: float = 1.0 - _life[i] / _max_life[i]
		s.scale = Vector2.ONE * _base[i] * (1.0 + _grow[i] * k)
		s.modulate.a = minf(1.0, (1.0 - k) * 2.5) * _alpha[i]


func puff(pos: Vector2, count: int, color: Color = Color(1, 1, 1, 0.9), size: float = 1.0) -> void:
	for n: int in count:
		var v: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(30, 140)
		_emit("puff", pos + v * 0.15, v + Vector2(0, -30), randf_range(0.5, 0.9), size * randf_range(0.6, 1.1), -20.0, 0.5, 1.2, color)


func debris(pos: Vector2, kind: String, count: int, speed: float) -> void:
	for n: int in count:
		var v: Vector2 = Vector2.from_angle(randf_range(-PI * 0.95, -PI * 0.05)) * randf_range(speed * 0.4, speed)
		_emit("debris_%s_%d" % [kind, randi() % 3], pos + Vector2(randf_range(-15, 15), randf_range(-15, 15)), v,
				Data.bf("fx", "debris_life_s") * randf_range(0.7, 1.1), randf_range(0.8, 1.3), 1400.0, randf_range(-12, 12), 0.0)


func sparks(pos: Vector2, count: int) -> void:
	for n: int in count:
		var v: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(200, 600)
		_emit("spark", pos, v, randf_range(0.25, 0.5), randf_range(0.5, 1.0), 600.0, 8.0, -0.6)


func flash(pos: Vector2, radius: float) -> void:
	_emit("flash", pos, Vector2.ZERO, 0.35, radius / 50.0, 0.0, 0.0, 0.6)
	for n: int in 10:
		var v: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(60, 220)
		_emit("puff", pos + v * 0.3, v, randf_range(0.6, 1.1), randf_range(1.0, 1.8), -60.0, 0.4, 1.0, Color(0.55, 0.5, 0.48, 0.85))


var trail_color: Color = Color(1, 1, 1, 0.85)


func trail(pos: Vector2, hot: bool) -> void:
	_emit("dot", pos, Vector2.ZERO, 2.5, 0.8, 0.0, 0.0, -0.3, Color(1.0, 0.8, 0.4) if hot else trail_color)


func flame_puff(pos: Vector2) -> void:
	_emit("flame", pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Vector2(randf_range(-30, 30), -60),
			0.3, randf_range(0.5, 0.8), 0.0, 0.0, -0.4)


func shockwave(x: float, radius: float, ground_y: float = 0.0) -> void:
	var wave: Sprite2D = Art.sprite("shockwave")
	wave.position = Vector2(x, ground_y - 12)
	var world_size: Vector2 = Art.svg_size("shockwave")
	wave.scale *= Vector2(radius * 2.0 / world_size.x, 0.35)
	wave.modulate.a = 0.9
	wave.z_index = 8
	add_child(wave)
	var duration: float = Data.bf("fx", "shockwave_s")
	var tw: Tween = wave.create_tween()
	tw.tween_property(wave, "scale:y", wave.scale.y * 1.8, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(wave, "modulate:a", 0.0, duration)
	tw.tween_callback(wave.queue_free)
	for i: int in 12:
		var px: float = x - radius + radius * 2.0 * float(i) / 11.0
		puff(Vector2(px, ground_y - 8), 1, Color("#cceeff"), 0.8)


## Rune crystal beam: a bright violet line that flares and fades, with sparks along it.
func beam(from: Vector2, to: Vector2, width: float) -> void:
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for layer: int in 2:
		var line: Line2D = Line2D.new()
		line.points = PackedVector2Array([from, to])
		line.width = width * (1.6 if layer == 0 else 0.55)
		line.default_color = Color(0.72, 0.42, 1.0, 0.75) if layer == 0 else Color(1.0, 0.95, 1.0, 1.0)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.material = add
		add_child(line)
		var tw: Tween = line.create_tween()
		tw.tween_property(line, "width", line.width * 1.3, 0.08)
		tw.tween_property(line, "width", 0.0, 0.45).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(line, "modulate:a", 0.0, 0.45)
		tw.tween_callback(line.queue_free)
	var length: float = from.distance_to(to)
	for i: int in 10:
		_emit("spark", from.lerp(to, randf()), Vector2.from_angle(randf() * TAU) * randf_range(80, 260),
				randf_range(0.3, 0.6), randf_range(0.6, 1.1), 200.0, 6.0, -0.5, Color(0.9, 0.7, 1.0))
	flash(from, width * 1.5)
	if length > 0.0:
		flash(to, width)


func float_text(pos: Vector2, text: String, color: Color, size: int = 34) -> void:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#3a1f0c"))
	l.add_theme_constant_override("outline_size", 10)
	l.position = pos - Vector2(80, 30)
	l.size = Vector2(160, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(80, 30)
	l.scale = Vector2.ONE * 0.3
	l.z_index = 10
	add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 70.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
