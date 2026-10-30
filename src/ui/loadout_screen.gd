class_name LoadoutScreen
extends CanvasLayer
## Four ordered ammunition slots. Power budget and per-hero caps prevent all-specialist queues.

var level_id: int = 1
var _level_data: Dictionary = {}
var _selection: Array[String] = []
var _slots: Array[Button] = []
var _power: Label
var _message: Label
var _tip: Label
var _battle: Button
## Material id -> block count in this fortress, most common first (see _fortress_materials).
var _materials: Array = []


func _ready() -> void:
	layer = 5
	_level_data = Data.level(level_id)
	_selection = LoadoutRules.saved_or_recommended(_level_data, level_id)
	_materials = fortress_materials(_level_data)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_background(root)
	_build_header(root)
	_build_slots(root)
	_build_arsenal(root)
	_build_actions(root)
	_build_fortress(root)
	_build_weapon(root)
	_refresh()
	var realm_key: String = String(Background.realm_info(int(_level_data.get("realm", 1))).get("key", "blossom"))
	Sound.set_music(realm_key, "menu")
	Sound.set_surroundings(realm_key, true)


func _build_background(root: Control) -> void:
	var info: Dictionary = Background.realm_info(int(_level_data.get("realm", 1)))
	var bg: TextureRect = TextureRect.new()
	var bg_name: String = Background.bg_name(int(_level_data.get("realm", 1)), int(_level_data.get("bg_variant", 0)))
	bg.texture = Art.tex(bg_name) if not bg_name.is_empty() else null
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.06, 0.08, 0.12, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)


func _build_header(root: Control) -> void:
	var back: Button = UIKit.icon_button("icon_home", "orange", 68)
	UIKit.place(back, Vector2.ZERO, Vector2(18, 16), Vector2(68, 68))
	back.pressed.connect(Game.goto_map)
	root.add_child(back)
	var shop: Button = UIKit.icon_button("icon_workshop", "green", 68)
	UIKit.place(shop, Vector2.ZERO, Vector2(98, 16), Vector2(68, 68))
	shop.pressed.connect(Game.goto_workshop.bind(level_id))
	root.add_child(shop)
	var title_holder: CenterContainer = CenterContainer.new()
	UIKit.place(title_holder, Vector2(0.5, 0), Vector2(-370, 14), Vector2(740, 100))
	title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sign: PanelContainer = UIKit.wood_sign()
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override("separation", -5)
	titles.add_child(UIKit.label("PLAN THE ASSAULT", 34, Color("#ffd23a"), 9))
	titles.add_child(UIKit.label("Level %d · %s" % [level_id, String(_level_data.get("name", ""))], 25, Color.WHITE, 7))
	sign.add_child(titles)
	title_holder.add_child(sign)
	root.add_child(title_holder)
	var brief: Label = UIKit.label(String(_level_data.get("strategy", "Study the structure, then choose four heroes in firing order.")), 23, Color.WHITE, 6, false)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.place(brief, Vector2(0.5, 0), Vector2(-470, 112), Vector2(940, 52))
	root.add_child(brief)


func _build_slots(root: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	UIKit.place(row, Vector2(0.5, 0), Vector2(-500, 170), Vector2(1000, 150))
	root.add_child(row)
	for i: int in LoadoutRules.slots():
		var slot: Button = UIKit.button("", "dark", 22, Vector2(205, 136))
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_theme_constant_override("icon_max_width", 70)
		slot.pressed.connect(_remove_slot.bind(i))
		row.add_child(slot)
		_slots.append(slot)
	_power = UIKit.label("", 28, Color("#ffe27a"), 8)
	UIKit.place(_power, Vector2(0.5, 0), Vector2(-250, 316), Vector2(500, 42))
	root.add_child(_power)


func _build_arsenal(root: Control) -> void:
	var panel: PanelContainer = UIKit.slate()
	UIKit.place(panel, Vector2(0.5, 0), Vector2(-570, 365), Vector2(1140, 206))
	root.add_child(panel)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	outer.add_child(UIKit.label("WIZARD'S ARSENAL", 26, Color("#ffd23a"), 7))
	var cards: HBoxContainer = HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 12)
	for kind: String in _all_kinds():
		cards.add_child(_hero_card(kind))
	outer.add_child(cards)
	panel.add_child(outer)
	_tip = UIKit.label("", 21, Color.WHITE, 5, false)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.place(_tip, Vector2(0.5, 0), Vector2(-520, 574), Vector2(1040, 48))
	root.add_child(_tip)


func _all_kinds() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in Data.projectiles.keys():
		var cfg: Variant = Data.projectiles[key]
		if cfg is Dictionary and (cfg as Dictionary).has("name"):
			out.append(String(key))
	out.sort_custom(func(a: String, b: String) -> bool:
		return int(Data.projectiles[a]["unlock_level"]) < int(Data.projectiles[b]["unlock_level"]))
	return out


func _hero_card(kind: String) -> Control:
	var cfg: Dictionary = Data.projectiles[kind]
	var unlocked: bool = int(cfg["unlock_level"]) <= level_id
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	var b: Button = UIKit.button("", "blue" if unlocked else "dark", 16, Vector2(184, 112))
	b.icon = Art.tex(String(cfg["texture"])) if unlocked else Art.tex("icon_lock")
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 72)
	b.disabled = not unlocked
	b.pressed.connect(_add_kind.bind(kind))
	v.add_child(b)
	if unlocked and is_strong(kind, _materials):
		var badge: PanelContainer = PanelContainer.new()
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("#2f9e44")
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = Color("#3a2212")
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		badge.add_theme_stylebox_override("panel", sb)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(UIKit.label("STRONG HERE", 14, Color.WHITE, 4))
		badge.position = Vector2(26, -12)
		b.add_child(badge)
	var title: String = String(cfg["name"]) if unlocked else "Level %d" % int(cfg["unlock_level"])
	v.add_child(UIKit.label(title, 21, Color(cfg["accent"]) if unlocked else Color("#c9ccd2"), 6))
	v.add_child(UIKit.label("Power %d · Max %d" % [int(cfg["power_cost"]), int(cfg["max_per_loadout"])], 16, Color.WHITE, 4, false))
	return v


## Blocks per material in a level, most common first: [[mat_id, count], ...].
static func fortress_materials(data: Dictionary) -> Array:
	var counts: Dictionary = {}
	for bd: Dictionary in data.get("blocks", []):
		var shape: Dictionary = Data.shapes.get(String(bd["type"]), {})
		if shape.is_empty():
			continue
		var m: String = String(shape["material"])
		counts[m] = int(counts.get(m, 0)) + 1
	var out: Array = []
	for m: String in counts:
		out.append([m, int(counts[m])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return out


## A hero is "strong here" when its block-weighted material multiplier beats loadout.strong_mult.
static func is_strong(kind: String, materials: Array) -> bool:
	var mults: Dictionary = Data.projectiles[kind].get("material_mult", {})
	var total: int = 0
	var sum: float = 0.0
	for e: Array in materials:
		total += int(e[1])
		sum += float(mults.get(String(e[0]), 1.0)) * int(e[1])
	return total > 0 and sum / total >= Data.bf("loadout", "strong_mult")


## Bottom-left strip: the fortress's materials with counts. Tapping one explains how it behaves.
func _build_fortress(root: Control) -> void:
	var panel: PanelContainer = UIKit.slate()
	UIKit.place(panel, Vector2(0, 1), Vector2(18, -96), Vector2(560, 82))
	root.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UIKit.label("FORTRESS", 20, Color("#ffd23a"), 6))
	panel.add_child(row)
	var shown: int = 0
	for e: Array in _materials:
		if shown >= int(Data.b("loadout", "fortress_max_chips")):
			break
		shown += 1
		var m: String = String(e[0])
		var chip: Button = Button.new()
		chip.flat = true
		chip.custom_minimum_size = Vector2(70, 60)
		chip.icon = Art.tex(_material_icon(m))
		chip.expand_icon = true
		chip.add_theme_constant_override("icon_max_width", 40)
		chip.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		chip.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.text = "x%d" % int(e[1])
		chip.add_theme_font_size_override("font_size", 16)
		chip.add_theme_color_override("font_color", Color.WHITE)
		chip.pressed.connect(func() -> void:
			var md: Dictionary = Data.materials[m]
			_tip.text = "%s · %s" % [String(md.get("label", m)), String(md.get("tip", ""))]
			Sound.play("ui_tap", 0.6))
		row.add_child(chip)


## Texture for a material chip: the undamaged look of its first square-ish shape.
func _material_icon(m: String) -> String:
	var best: String = ""
	var best_ratio: float = 99.0
	for shape_id: String in Data.shapes:
		var sh: Dictionary = Data.shapes[shape_id]
		if String(sh["material"]) != m or String(sh["collider"]) == "v":
			continue
		var r: float = maxf(float(sh["size"][0]), float(sh["size"][1])) / minf(float(sh["size"][0]), float(sh["size"][1]))
		if r < best_ratio:
			best_ratio = r
			best = shape_id
	return "block_%s_0" % best


## Siege weapon chip next to the fortress strip: tap to cycle the unlocked weapons.
func _build_weapon(root: Control) -> void:
	var b: Button = UIKit.button("", "dark", 18, Vector2(196, 82))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 64)
	UIKit.place(b, Vector2(0, 1), Vector2(590, -96), Vector2(196, 82))
	root.add_child(b)
	UIFx.press_juice(b)
	var show: Callable = func() -> void:
		var w: String = Progression.weapon()
		var c: Dictionary = Progression.weapon_cfg(w)
		b.icon = Art.tex("icon_weapon_" + w)
		b.text = String(c["name"]).to_upper()
	show.call()
	b.pressed.connect(func() -> void:
		var list: Array = Progression.weapons().filter(func(id: Variant) -> bool: return Progression.weapon_unlocked(String(id)))
		if list.size() <= 1:
			_tip.text = "Ballista unlocks after level %d, Trebuchet after level %d." % [
				int(Progression.weapon_cfg("ballista")["unlock_level"]) - 1, int(Progression.weapon_cfg("trebuchet")["unlock_level"]) - 1]
			return
		var i: int = list.find(Progression.weapon())
		Progression.set_weapon(String(list[(i + 1) % list.size()]))
		Sound.play("lever", 0.6)
		UIFx.pop(b, 1.1)
		show.call()
		_tip.text = "%s · %s" % [String(Progression.weapon_cfg()["name"]), String(Progression.weapon_cfg()["desc"])])


func _build_actions(root: Control) -> void:
	_message = UIKit.label("", 20, Color("#ffb0a0"), 5, false)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.place(_message, Vector2(1, 0), Vector2(-300, 22), Vector2(280, 90))
	root.add_child(_message)
	var recommended: Button = UIKit.button("RECOMMENDED", "orange", 23, Vector2(230, 68))
	UIKit.place(recommended, Vector2(1, 1), Vector2(-500, -84), Vector2(230, 68))
	recommended.pressed.connect(_use_recommended)
	root.add_child(recommended)
	_battle = UIKit.button("TO BATTLE!", "green", 31, Vector2(240, 76))
	UIKit.place(_battle, Vector2(1, 1), Vector2(-254, -88), Vector2(240, 76))
	_battle.pressed.connect(_start)
	root.add_child(_battle)


func _add_kind(kind: String) -> void:
	_tip.text = "%s · %s" % [String(Data.projectiles[kind]["ability"]), String(Data.projectiles[kind]["strategy"])]
	if _selection.size() >= LoadoutRules.slots():
		_message.text = "Tap an ordered slot to remove it first."
		return
	var candidate: Array[String] = _selection.duplicate()
	candidate.append(kind)
	var count: int = candidate.count(kind)
	if count > int(Data.projectiles[kind]["max_per_loadout"]):
		_message.text = "The wizard can prepare only %d %s." % [int(Data.projectiles[kind]["max_per_loadout"]), String(Data.projectiles[kind]["name"])]
		Sound.play("stone_hit", 0.4)
		return
	_selection.append(kind)
	Sound.play("pop", 0.7)
	_refresh()


func _remove_slot(index: int) -> void:
	if index >= _selection.size():
		return
	_selection.remove_at(index)
	Sound.play("ui_tap", 0.7)
	_refresh()


func _use_recommended() -> void:
	_selection = LoadoutRules.recommended(_level_data, level_id)
	_tip.text = "The captain's balanced recommendation is ready. Tap a slot to change its firing order."
	_refresh()


func _refresh() -> void:
	for i: int in _slots.size():
		var b: Button = _slots[i]
		if i < _selection.size():
			var kind: String = _selection[i]
			var cfg: Dictionary = Data.projectiles[kind]
			b.text = "%d  %s\nPower %d" % [i + 1, String(cfg["name"]), int(cfg["power_cost"])]
			b.icon = Art.tex(String(cfg["texture"]))
		else:
			b.text = "%d  EMPTY\nTap an hero below" % (i + 1)
			b.icon = null
	var cost: int = LoadoutRules.cost(_selection)
	var budget: int = LoadoutRules.power_budget(_level_data, level_id)
	_power.text = "ARCANE POWER  %d / %d" % [cost, budget]
	_power.add_theme_color_override("font_color", Color("#ff8a7a") if cost > budget else Color("#ffe27a"))
	var err: String = LoadoutRules.error(_selection, level_id, _level_data)
	_message.text = err
	_battle.disabled = not err.is_empty()


func _start() -> void:
	if not LoadoutRules.valid(_selection, level_id, _level_data):
		_refresh()
		return
	var all: Dictionary = Save.data.get("loadouts", {})
	all[str(level_id)] = _selection.duplicate()
	Save.data["loadouts"] = all
	Save.write()
	Game.goto_level(level_id)
