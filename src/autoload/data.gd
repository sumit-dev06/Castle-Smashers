extends Node
## Loads every JSON file in res://data once. All tunable numbers come from here.

var balance: Dictionary = {}
var materials: Dictionary = {}
var shapes: Dictionary = {}
var projectiles: Dictionary = {}
var _levels: Dictionary = {}
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
