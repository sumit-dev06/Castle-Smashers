extends Node
## Loads every JSON file in res://data once. All tunable numbers come from here.

var balance: Dictionary = {}
var materials: Dictionary = {}
var shapes: Dictionary = {}
var projectiles: Dictionary = {}
var _levels: Dictionary = {}
var _novelty: Dictionary = {}
## Challenge ids start above this (data/challenges/challenge_NNN.json).
const CHALLENGE_BASE: int = 100
var challenges: Dictionary = {}


func _ready() -> void:
	balance = load_json("res://data/balance.json")
	var mats: Dictionary = load_json("res://data/materials.json")
	materials = mats.get("materials", {})
	shapes = mats.get("shapes", {})
	projectiles = load_json("res://data/projectiles.json")
	challenges = load_json("res://data/challenges/index.json")


func load_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Data: cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Data: invalid JSON in %s" % path)
	return {}


func level_count() -> int:
	return int(balance.get("level_count", 1))


## What campaign level `id` shows for the first time ("hero:fire", "mech:crusher", "mat:iron",
## "shape:bell", "captive", "bolt", "engineer", "boss"). Empty = nothing new, so no story scene.
func novelty(id: int) -> PackedStringArray:
	if _novelty.is_empty():
		var seen: Dictionary = {}
		for n: int in range(1, level_count() + 1):
			var fresh: PackedStringArray = PackedStringArray()
			for k: String in _content_keys(level(n)):
				if not seen.has(k):
					seen[k] = true
					fresh.append(k)
			_novelty[n] = fresh
	return _novelty.get(id, PackedStringArray())


func _content_keys(d: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	var gadgets: Array = b("story", "novel_shapes")
	for h: Variant in d.get("heroes", []):
		keys.append("hero:" + String(h))
	for m: Variant in d.get("mechanisms", []):
		keys.append("mech:" + String(m.get("type", "")))
	for bl: Variant in d.get("blocks", []):
		var t: String = String(bl.get("type", ""))
		if shapes.has(t):
			keys.append("mat:" + String(shapes[t].get("material", "")))
		if t in gadgets:
			keys.append("shape:" + t)
	if not (d.get("captives", []) as Array).is_empty():
		keys.append("captive")
	if not (d.get("bolts", []) as Array).is_empty():
		keys.append("bolt")
	if not (d.get("engineers", []) as Array).is_empty():
		keys.append("engineer")
	if bool(d.get("boss", false)):
		keys.append("boss:%d" % int(d.get("id", 0)))
	return keys


func level(id: int) -> Dictionary:
	if not _levels.has(id):
		_levels[id] = load_json("res://data/levels/level_%03d.json" % id)
	return _levels[id]


func challenge(id: int) -> Dictionary:
	if not _levels.has(id):
		_levels[id] = load_json("res://data/challenges/challenge_%03d.json" % id)
	return _levels[id]


## Challenge cards in screen order: [{id, name, mode, realm, rule}].
func challenge_list() -> Array:
	return challenges.get("challenges", [])


## Index entry of a Special Mission ({} for campaign levels and Master Sieges).
func mission_info(id: int) -> Dictionary:
	for item: Dictionary in challenge_list():
		if int(item.get("id", 0)) == id:
			return item
	return {}


## Hard mechanic-puzzle cards, kept out of daily challenge rotation.
func special_list() -> Array:
	return challenges.get("specials", [])


func is_special(id: int) -> bool:
	for item: Dictionary in special_list():
		if int(item.get("id", 0)) == id:
			return true
	return false


## Shortcut: Data.b("camera", "smooth") -> balance.camera.smooth
func b(section: String, key: String) -> Variant:
	var s: Dictionary = balance.get(section, {})
	if not s.has(key):
		push_error("Data: missing balance %s.%s" % [section, key])
		return 0.0
	return s[key]


func bf(section: String, key: String) -> float:
	return float(b(section, key))


func vec(section: String, key: String) -> Vector2:
	var a: Array = b(section, key)
	return Vector2(float(a[0]), float(a[1]))
