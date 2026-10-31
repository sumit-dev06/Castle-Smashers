class_name Art
extends RefCounted
## Texture loading. Prefers refined AI art (assets/art/ai/cut, made by tools/cutout.py) and falls back
## to the generated SVGs. SVGs import at 2x, so SVG sprites use SVG_SCALE for 1 SVG unit = 1 world px.
## Characters are placed with metadata (feet point, body circle) so AI and SVG art line up the same way.

const SVG_DIR: String = "res://assets/art/svg/%s.svg"
const AI_DIR: String = "res://assets/art/ai/cut/%s.png"
const AI_META: String = "res://assets/art/ai/cut/meta.json"
const SVG_SCALE: float = 0.5

## Character facts for the SVG fallbacks, in SVG units (tools/gen_art.py).
const SVG_META: Dictionary = {
	"hero_stone": {"body_c": [40, 44], "body_r": 30}, "hero_fire": {"body_c": [40, 60], "body_r": 29},
	"hero_bomb": {"body_c": [40, 59], "body_r": 29}, "hero_cyclone": {"body_c": [45, 45], "body_r": 30},
	"hero_quake": {"body_c": [44, 50], "body_r": 33},
	"soldier": {"feet_x": 42, "feet_y": 95, "unit_h": 92}, "archer": {"feet_x": 50, "feet_y": 95, "unit_h": 92},
	"wizard_idle": {"feet_x": 55, "feet_y": 136, "unit_h": 132}, "captive_idle": {"feet_x": 42, "feet_y": 95, "unit_h": 92},
}

## AI images with these prefixes keep the SVG's world size (see is_fit).
const FIT_PREFIXES: Array[String] = ["block_", "mechanism_", "boss_crown", "boss_shield"]
## AI UI/props keep the SVG's footprint but scale uniformly (no squash): icons, currency, props.
const UI_FIT_PREFIXES: Array[String] = ["icon_", "logo_", "gem", "blueprint", "cannonball", "engineer_", "chest_"]

static var _cache: Dictionary = {}
static var _svg_size: Dictionary = {}
static var _meta: Dictionary = {}
static var _meta_loaded: bool = false


static func _ai_meta() -> Dictionary:
	if not _meta_loaded:
		_meta_loaded = true
		if FileAccess.file_exists(AI_META):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AI_META))
			if parsed is Dictionary:
				_meta = parsed
	return _meta


static func has_ai(art_name: String) -> bool:
	return _ai_meta().has(art_name) and ResourceLoader.exists(AI_DIR % art_name)


## Resolves pose fallbacks: "hero_fire_hit" uses "hero_fire" if only the idle AI image exists.
static func resolve(art_name: String) -> String:
	if has_ai(art_name):
		return art_name
	if art_name.ends_with("_hit") and has_ai(art_name.trim_suffix("_hit")):
		return art_name.trim_suffix("_hit")
	if art_name.begins_with("block_"):
		var plain: String = stageless(art_name)
		if has_ai(plain):
			return plain
	return art_name


## "block_iron_beam_2" -> "block_iron_beam" (one AI image covers all damage stages).
static func stageless(art_name: String) -> String:
	var cut: int = art_name.rfind("_")
	if cut > 0 and art_name.substr(cut + 1).is_valid_int():
		return art_name.substr(0, cut)
	return art_name


## True when an AI image replaces this art but must keep the SVG's world size
## (blocks fill their collider, mechanisms their rig, the crown and shield their slot).
static func is_fit(art_name: String) -> bool:
	if not has_ai(resolve(art_name)):
		return false
	for p: String in FIT_PREFIXES:
		if art_name.begins_with(p):
			return true
	return false


## Sprite scale at world_scale 1 (texture px -> world px), per axis.
static func base_scale(art_name: String) -> Vector2:
	if is_fit(art_name) or _is_ui_fit(art_name):
		var svg: String = SVG_DIR % art_name
		if not _svg_size.has(art_name):
			_svg_size[art_name] = (load(svg) as Texture2D).get_size() * SVG_SCALE if ResourceLoader.exists(svg) else tex(art_name).get_size()
		var k: Vector2 = (_svg_size[art_name] as Vector2) / tex(art_name).get_size()
		return Vector2.ONE * minf(k.x, k.y) if _is_ui_fit(art_name) else k
	return Vector2.ONE * (1.0 if has_ai(resolve(art_name)) else SVG_SCALE)


static func _is_ui_fit(art_name: String) -> bool:
	if not has_ai(art_name):
		return false
	for p: String in UI_FIT_PREFIXES:
		if art_name.begins_with(p):
			return true
	return false


static func exists(art_name: String) -> bool:
	var key: String = resolve(art_name)
	return has_ai(key) or ResourceLoader.exists(SVG_DIR % key)


static func tex(art_name: String) -> Texture2D:
	var key: String = resolve(art_name)
	if not _cache.has(key):
		var path: String = AI_DIR % key if has_ai(key) else SVG_DIR % key
		if not ResourceLoader.exists(path):
			push_error("Art: missing %s" % path)
			return null
		_cache[key] = load(path)
	return _cache[key]


## Sprite of SVG art drawn at world_scale (1.0 = SVG size in world pixels).
static func sprite(art_name: String, world_scale: float = 1.0) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex(art_name)
	s.scale = world_scale * base_scale(art_name)
	return s


## Size in world pixels at world_scale 1 (SVG units, or AI pixels).
static func svg_size(art_name: String) -> Vector2:
	var t: Texture2D = tex(art_name)
	if t == null:
		return Vector2.ONE
	return t.get_size() * base_scale(art_name)


## Walkable top line of a stage_* piece, in world px at world_scale 1 (pixels from the image top).
## SVG placeholders put it at STAGE_SVG_TOP; AI art gets `top_y` from tools/cutout.py.
const STAGE_SVG_TOP: float = 24.0


static func stage_top(art_name: String) -> float:
	var key: String = resolve(art_name)
	if has_ai(key):
		var m: Dictionary = _ai_meta()[key]
		return float(m.get("walk_y", m.get("top_y", 0.0)))
	return STAGE_SVG_TOP


## Metadata in texture pixels.
static func meta(art_name: String) -> Dictionary:
	var key: String = resolve(art_name)
	if has_ai(key):
		return _ai_meta()[key]
	var base: String = key.trim_suffix("_hit")
	for fam: String in ["soldier", "archer"]:
		if base.begins_with(fam):
			base = fam
	var m: Dictionary = SVG_META.get(base, {})
	var out: Dictionary = {}
	for k: String in m:
		var v: Variant = m[k]
		out[k] = [float(v[0]) * 2.0, float(v[1]) * 2.0] if v is Array else float(v) * 2.0
	return out


## Hero sprite whose round body has the given world radius, body centred on the node.
static func hero_sprite(art_name: String, radius: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	set_hero_tex(s, art_name, radius)
	return s


static func set_hero_tex(s: Sprite2D, art_name: String, radius: float) -> void:
	s.texture = tex(art_name)
	var m: Dictionary = meta(art_name)
	var c: Vector2 = Vector2(float(m["body_c"][0]), float(m["body_c"][1]))
	s.scale = Vector2.ONE * radius / float(m["body_r"])
	s.offset = s.texture.get_size() / 2.0 - c


## Soldier / archer sprite: feet at the node origin, standing pose is `height` world px tall.
## All poses of a family share one pixel scale (cutout.py), so a KO pose stays the right size.
static func unit_sprite(art_name: String, height: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	set_unit_tex(s, art_name, height)
	return s


static func set_unit_tex(s: Sprite2D, art_name: String, height: float) -> void:
	s.texture = tex(art_name)
	var m: Dictionary = meta(art_name)
	s.scale = Vector2.ONE * height / float(m["unit_h"])
	s.offset = s.texture.get_size() / 2.0 - Vector2(float(m["feet_x"]), float(m["feet_y"]))
