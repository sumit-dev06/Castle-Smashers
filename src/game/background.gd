class_name Background
extends CanvasLayer
## Screen-space backdrop. Uses the realm's AI painting, softened (downscaled + blur/haze shader, all
## tunable in balance.json "background") so the sharp fortress reads in front of it, scaled to cover
## the screen and bottom aligned. Falls back to SVG sky + mountains + hills.

const HAZE_SHADER: Shader = preload("res://src/game/background_haze.gdshader")

var camera: Camera2D
var realm: int = 1
var variant: int = 0
## Off for the title screen, which shows the painting sharp.
var blurred: bool = true
## Screen height fraction of the ground line (SVG fallback layers). < 0 = camera default.
var ground_frac: float = -1.0
var _paint: Sprite2D
var _base_zoom: float = 1.0
var _layers: Array[Dictionary] = []
var _clouds: Array[Sprite2D] = []
var _cloud_speed: Array[float] = []
var _cloud_x: Array[float] = []
var _frac: float = 0.8
var _ambient: Array[Sprite2D] = []
var _ambient_speed: PackedFloat32Array = PackedFloat32Array()
var _weather: String = ""
var _hue_range: Array = [0.18, 0.34]
## Horizontal wind in world px/s² (set by the level during gusts); ambient particles drift with it.
var wind: float = 0.0

static var _soft_cache: Dictionary = {}


## Key that picks a realm's stage art, foreground, music and ambience. New realms can borrow an
## older realm's set ("look") until their own art exists.
static func look(info: Dictionary) -> String:
	return String(info.get("look", info.get("key", "blossom")))


## Art key for one kind of realm art (`probe` like "stage_ledge_%s"): the realm's own art when that
## file exists, else the borrowed "look".
static func art_key(info: Dictionary, probe: String) -> String:
	var own: String = String(info.get("key", "blossom"))
	return own if Art.exists(probe % own) else look(info)


static func realm_info(realm_id: int) -> Dictionary:
	var list: Array = Data.balance.get("realms", [])
	for r: Dictionary in list:
		if int(r["id"]) == realm_id:
			return r
	return list[0] if not list.is_empty() else {}


## Painting for a realm: the requested variant if its AI image exists, else any variant, else the
## realm's fallback painting. Empty string = no AI painting (SVG fallback).
static func bg_name(realm_id: int, p_variant: int = 0) -> String:
	var info: Dictionary = realm_info(realm_id)
	var raw: Variant = info.get("bg", [])
	var names: Array = raw if raw is Array else [raw]
	if not names.is_empty():
		var want: String = String(names[posmod(p_variant, names.size())])
		if Art.has_ai(want):
			return want
		for n: Variant in names:
			if Art.has_ai(String(n)):
				return String(n)
	var fb: String = String(info.get("fallback_bg", ""))
	return fb if Art.has_ai(fb) else ""


## Downscaled copy of a painting (cheap, already soft); the shader adds the final blur and haze.
static func soft_texture(art_name: String) -> Texture2D:
	if _soft_cache.has(art_name):
		return _soft_cache[art_name]
	var src: Texture2D = Art.tex(art_name)
	var img: Image = src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	var k: float = Data.bf("background", "downscale")
	img.resize(maxi(8, int(img.get_width() * k)), maxi(8, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_soft_cache[art_name] = t
	return t


func _ready() -> void:
	layer = -10
	# Keeps fitting the screen while the tree is paused (a popup on the first frame, such as the
	# training How-to card, left the painting at its raw size over a black screen).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.is_debug_build() and Game.args.has("sharp-bg"):
		blurred = false  # website / store captures: the full-resolution painting, no haze
	_frac = ground_frac if ground_frac > 0.0 else Data.bf("camera", "ground_screen_frac")
	var info: Dictionary = Background.realm_info(realm)
	_hue_range = info.get("weather_hue", _hue_range)
	var paint_name: String = Background.bg_name(realm, variant)
	if not paint_name.is_empty():
		_paint = Sprite2D.new()
		_paint.centered = false
		_paint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if blurred:
			_paint.texture = Background.soft_texture(paint_name)
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = HAZE_SHADER
			mat.set_shader_parameter("haze_color", Color(String(info.get("haze", "#dceaff"))))
			mat.set_shader_parameter("haze", Data.bf("background", "haze"))
			mat.set_shader_parameter("haze_bottom", Data.bf("background", "haze_bottom"))
			mat.set_shader_parameter("saturation", Data.bf("background", "saturation"))
			mat.set_shader_parameter("brightness", Data.bf("background", "brightness"))
			_paint.material = mat
		else:
			_paint.texture = Art.tex(paint_name)
		add_child(_paint)
		if camera:
			_base_zoom = camera.zoom.x
		_build_ambient(String(info.get("weather", "")))
		return
	_build_svg()
	_build_ambient(String(info.get("weather", "")))


func _build_svg() -> void:
	var sky: TextureRect = TextureRect.new()
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.85, 1.0])
	g.colors = PackedColorArray([Color("#2a8ff0"), Color("#69c3fb"), Color("#bfeaff"), Color("#e8f8ff")])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	_add_layer("bg_mountains", 0.06, 1.15, -60.0)
	for i: int in 6:
		var c: Sprite2D = Art.sprite("cloud_%d" % (i % 2), randf_range(0.5, 0.9))
		c.position = Vector2(randf_range(0, 2000), randf_range(50, 260))
		add_child(c)
		_clouds.append(c)
		_cloud_speed.append(randf_range(6, 16))
		_cloud_x.append(c.position.x)
	_add_layer("bg_hills", 0.22, 1.0, 150.0)


func _add_layer(art: String, factor: float, scale_k: float, y_above_ground: float) -> void:
	var s: Sprite2D = Art.sprite(art, scale_k)
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	var ts: Vector2 = s.texture.get_size()
	s.region_rect = Rect2(0, 0, ts.x * 4.0, ts.y)
	add_child(s)
	_layers.append({"sprite": s, "factor": factor, "w": ts.x * s.scale.x, "h": ts.y * s.scale.y, "y": y_above_ground})


func _process(delta: float) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var ground_y: float = view.y * _frac
	if _paint:
		# Cover the screen, bottom aligned (paintings keep their open gap in the lower third).
		var ts: Vector2 = _paint.texture.get_size()
		var z: float = camera.zoom.x if camera else 1.0
		var zoom_k: float = clampf(1.0 + (z / maxf(_base_zoom, 0.01) - 1.0) * 0.15, 0.9, 1.15)
		var bottom: float = view.y * (1.0 + Data.bf("background", "bottom_overshoot_frac"))
		var sc: float = maxf(view.x / ts.x, bottom / ts.y) * zoom_k
		_paint.scale = Vector2(sc, sc)
		_paint.position = Vector2((view.x - ts.x * sc) / 2.0, bottom - ts.y * sc)
		if not get_tree().paused:
			_tick_ambient(delta, view)
		return
	var cam_x: float = camera.position.x if camera else 0.0
	for L: Dictionary in _layers:
		var s: Sprite2D = L["sprite"]
		s.position = Vector2(-fposmod(cam_x * float(L["factor"]), float(L["w"])), ground_y - float(L["h"]) + float(L["y"]))
	var span: float = view.x + 500.0
	for i: int in _clouds.size():
		_cloud_x[i] -= _cloud_speed[i] * (0.0 if get_tree().paused else delta)
		_clouds[i].position.x = fposmod(_cloud_x[i] - cam_x * 0.03, span) - 250.0
	if not get_tree().paused:
		_tick_ambient(delta, view)


func _build_ambient(weather: String) -> void:
	_weather = weather
	if weather.is_empty():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var count: int = int(Data.b("mechanics", "ambient_count"))
	_ambient_speed.resize(count)
	for i: int in count:
		var art_name: String = "ambient_streak" if weather == "rain" else ("ambient_leaf" if weather in ["leaves", "petals"] else "dot")
		var particle: Sprite2D = Art.sprite(art_name, randf_range(0.35, 0.8))
		particle.position = Vector2(randf_range(0.0, view.x), randf_range(0.0, view.y))
		particle.z_index = -1
		if weather == "embers":
			particle.modulate = Color(1.0, randf_range(0.35, 0.7), 0.12, 0.75)
		elif weather == "pollen":
			particle.modulate = Color(1.0, 0.9, 0.45, 0.45)
		elif weather == "petals":
			particle.modulate = Color.from_hsv(randf_range(0.9, 0.98), randf_range(0.25, 0.45), 1.0, 0.8)
		elif weather == "leaves":
			# A realm may set its own leaf colour range (autumn highlands: red to orange).
			var hue: Array = _hue_range
			particle.modulate = Color.from_hsv(randf_range(float(hue[0]), float(hue[1])), 0.75, 0.9, 0.7)
		else:
			particle.modulate = Color(0.75, 0.88, 1.0, 0.38)
		add_child(particle)
		_ambient.append(particle)
		_ambient_speed[i] = randf_range(Data.bf("mechanics", "ambient_speed_min"), Data.bf("mechanics", "ambient_speed_max"))


func _tick_ambient(delta: float, view: Vector2) -> void:
	for i: int in _ambient.size():
		var particle: Sprite2D = _ambient[i]
		var speed: float = _ambient_speed[i]
		match _weather:
			"rain":
				particle.position += Vector2(-speed * 0.35, speed * 5.0) * delta
			"embers":
				particle.position += Vector2(sin(Time.get_ticks_msec() * 0.001 + i) * speed * 0.2, -speed) * delta
			_:
				particle.position += Vector2(-speed, sin(Time.get_ticks_msec() * 0.0015 + i) * speed * 0.28) * delta
		particle.position.x += wind * Data.bf("wind", "particle_speed_mult") * 0.01 * delta * speed
		if particle.position.x < -30.0:
			particle.position.x = view.x + 30.0
		elif particle.position.x > view.x + 30.0:
			particle.position.x = -30.0
		if particle.position.y < -30.0:
			particle.position.y = view.y + 30.0
		elif particle.position.y > view.y + 30.0:
			particle.position.y = -30.0
