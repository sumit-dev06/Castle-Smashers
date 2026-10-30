class_name Stage
extends Node2D
## Level terrain like the reference art: the catapult ledge on the left, one or more fortress bases on
## the right, and the gap between them (water, sea, lava or clouds). Anything that falls below the
## kill line under the gap surface is gone: blocks break (scored), archers are defeated.
## Level JSON: "stage": {"ledge_right": 470, "bases": [{"x0": 760, "x1": 1300, "top": 0}], "gap": "water"}

var level_data: Dictionary = {}
var realm: Dictionary = {}
var gap: Dictionary = {}
var gap_kind: String = "water"
var surface_y: float = 150.0
var kill_y: float = 220.0
var ledge_right: float = 470.0
## Fortress bases as world rects (x, top y, width, depth).
var bases: Array[Rect2] = []
var world_right: float = 2000.0

var _waves: Array[Sprite2D] = []
var _wave_speed: PackedFloat32Array = PackedFloat32Array()
var _wave_y: PackedFloat32Array = PackedFloat32Array()
var _t: float = 0.0
var _base_surface: float = 150.0
var _tide_amp: float = 0.0
var _tide_period: float = 9.0
var _gap_root: Node2D


func setup(p_level_data: Dictionary, p_realm: Dictionary, p_world_right: float) -> void:
	level_data = p_level_data
	realm = p_realm
	world_right = p_world_right
	var sd: Dictionary = level_data.get("stage", {})
	gap_kind = String(sd.get("gap", realm.get("gap", "water")))
	var gaps: Dictionary = Data.balance["gaps"]
	if not gaps.has(gap_kind):
		push_error("Stage: unknown gap kind %s" % gap_kind)
		gap_kind = "water"
	gap = gaps[gap_kind]
	surface_y = float(sd.get("surface_y", gap["surface_y"]))
	_base_surface = surface_y
	var tide: Dictionary = level_data.get("tide", {})
	if not tide.is_empty():
		_tide_amp = float(tide.get("amp_px", Data.bf("tide", "default_amp_px")))
		_tide_period = float(tide.get("period_s", Data.bf("tide", "default_period_s")))
	kill_y = surface_y + Data.bf("stage", "kill_below_surface_px")
	ledge_right = float(sd.get("ledge_right", Data.bf("stage", "ledge_right")))
	var raw_bases: Array = sd.get("bases", [])
	if sd.is_empty():
		# No stage block (old data, menus): one continuous base so nothing floats.
		raw_bases = [{"x0": ledge_right, "x1": world_right + 1200.0, "top": 0.0}]
	for bd: Dictionary in raw_bases:
		var top: float = float(bd.get("top", 0.0))
		var x0: float = float(bd["x0"])
		var x1: float = float(bd["x1"])
		bases.append(Rect2(x0, top, x1 - x0, kill_y + 400.0 - top))


func _ready() -> void:
	var tint: Color = Color(String(realm.get("stage_tint", "#ffffff")))
	var key: String = String(realm.get("key", "blossom"))
	var ledge_left: float = Data.bf("stage", "ledge_visual_left")
	_add_collider(Rect2(-8000.0, 0.0, 8000.0 + ledge_right, kill_y + 400.0))
	_add_piece("stage_ledge_" + key, ledge_left, ledge_right, 0.0, tint)
	var raw_bases: Array = level_data.get("stage", {}).get("bases", [])
	for i: int in bases.size():
		var r: Rect2 = bases[i]
		_add_collider(r)
		var art: String = ""
		if i < raw_bases.size():
			art = String((raw_bases[i] as Dictionary).get("art", ""))
		if art.is_empty():
			art = "wide" if r.size.x >= Data.bf("stage", "wide_base_min_px") else "small"
		var over: float = r.size.x * (Data.bf("stage", "visual_overhang") - 1.0) * 0.5
		_add_piece("stage_base_%s_%s" % [key, art], r.position.x - over, r.end.x + over, r.position.y, tint)
	_build_gap()


func _add_collider(r: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = int(Data.b("layers", "world"))
	body.collision_mask = 0
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = 1.0
	body.physics_material_override = pm
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = r.size
	col.shape = shape
	col.position = r.get_center()
	body.add_child(col)
	add_child(body)


## Terrain sprite scaled to span x0..x1 with its flat top on `top`. If the art is too shallow to reach
## under the gap surface it is stretched vertically (capped), so pieces never float above water.
func _add_piece(art: String, x0: float, x1: float, top: float, tint: Color) -> void:
	var s: Sprite2D = Art.sprite(art)
	var size: Vector2 = Art.svg_size(art)
	var k: float = (x1 - x0) / size.x
	var top_off: float = Art.stage_top(art)
	var sy: float = k
	if gap_kind != "clouds":
		var need: float = surface_y + _tide_amp - top + Data.bf("stage", "min_depth_below_surface_px")
		var depth: float = (size.y - top_off) * k
		if depth < need:
			sy = k * minf(need / maxf(depth, 1.0), Data.bf("stage", "max_stretch_y"))
	s.centered = false
	s.scale = Vector2(s.scale.x * k, s.scale.y * sy)
	s.position = Vector2(x0, top - top_off * sy)
	s.modulate = tint
	s.z_index = -1
	add_child(s)


func _build_gap() -> void:
	_gap_root = Node2D.new()
	add_child(_gap_root)
	var left: float = -8000.0
	var right: float = world_right + 8000.0
	var deep: float = Data.bf("stage", "front_depth_px")
	var body: Polygon2D = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(left, surface_y), Vector2(right, surface_y),
			Vector2(right, surface_y + deep), Vector2(left, surface_y + deep)])
	var top_c: Color = Color(String(gap["top"]))
	var bot_c: Color = Color(String(gap["bottom"]))
	body.vertex_colors = PackedColorArray([top_c, top_c, bot_c, bot_c])
	body.z_index = -3
	_gap_root.add_child(body)
	var wave_art: String = "gap_cloud" if gap_kind == "clouds" else "gap_wave"
	var wave_c: Color = Color(String(gap["wave"]))
	_add_wave(wave_art, wave_c, -3, surface_y, 1.0, 1.0)
	var front_alpha: float = float(gap["front_alpha"])
	if front_alpha > 0.0:
		var front: Polygon2D = Polygon2D.new()
		var fy: float = surface_y + Data.bf("stage", "front_offset_px")
		front.polygon = PackedVector2Array([Vector2(left, fy), Vector2(right, fy), Vector2(right, fy + deep), Vector2(left, fy + deep)])
		var fc: Color = Color(String(gap["front"]))
		var fc_top: Color = Color(fc, front_alpha)
		var fc_bot: Color = Color(bot_c, minf(1.0, front_alpha + 0.3))
		front.vertex_colors = PackedColorArray([fc_top, fc_top, fc_bot, fc_bot])
		front.z_index = 2
		_gap_root.add_child(front)
		_add_wave(wave_art, Color(wave_c, 0.8), 2, fy, -0.7, 0.8)


func _add_wave(art: String, color: Color, z: int, y: float, speed_k: float, scale_k: float) -> void:
	var s: Sprite2D = Art.sprite(art, scale_k)
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	var ts: Vector2 = s.texture.get_size()
	var span: float = world_right + 16000.0
	s.region_rect = Rect2(0, 0, span / s.scale.x, ts.y)
	var h: float = ts.y * s.scale.y
	var wy: float = y - h * 0.45
	s.position = Vector2(-8000.0, wy)
	s.modulate = color
	s.z_index = z
	_gap_root.add_child(s)
	_waves.append(s)
	_wave_speed.append(Data.bf("stage", "wave_speed") * speed_k / s.scale.x)
	_wave_y.append(wy)


## Vertical tide offset of the gap surface now (0 without a tide).
func tide_offset() -> float:
	if _tide_amp <= 0.0:
		return 0.0
	return sin(_t * TAU / _tide_period) * _tide_amp


func _physics_process(_delta: float) -> void:
	var off: float = tide_offset()
	surface_y = _base_surface + off
	kill_y = surface_y + Data.bf("stage", "kill_below_surface_px")
	if _gap_root:
		_gap_root.position.y = off


func _process(delta: float) -> void:
	_t += delta
	var bob: float = Data.bf("stage", "wave_bob_px")
	var hz: float = Data.bf("stage", "wave_bob_hz")
	for i: int in _waves.size():
		var w: Sprite2D = _waves[i]
		w.region_rect.position.x = fposmod(_t * _wave_speed[i], w.texture.get_size().x)
		w.position.y = _wave_y[i] + sin(_t * TAU * hz + i * 1.7) * bob


## True when x is over solid ground (ledge or a base top), used by arrows and soldiers.
func ground_at(x: float) -> bool:
	if x <= ledge_right:
		return true
	for r: Rect2 in bases:
		if x >= r.position.x and x <= r.end.x:
			return true
	return false


## Ground top y at x: 0 on the ledge, the base top on a base, the gap surface over the gap.
func top_at(x: float) -> float:
	if x <= ledge_right:
		return 0.0
	for r: Rect2 in bases:
		if x >= r.position.x and x <= r.end.x:
			return r.position.y
	return surface_y


func splash_color() -> Color:
	return Color(String(gap["splash"]))


func splash_sound() -> String:
	return String(gap["sound"])
