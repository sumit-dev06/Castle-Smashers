class_name LoadoutScreen
extends CanvasLayer
## "Plan the Assault" (owner reference docs/reference/plan_assault_reference.png). Opens inside the
## level right after the fortress flyover, over the live scene, so the player picks heroes while
## looking at the enemy base. Layout: home button, title sign + parchment brief, a stats panel
## (shots, destruction, objective); one card per hero with -/+ steppers; the firing order and arcane
## power; bottom row with the fortress materials, siege weapon, Recommended and TO BATTLE.
## Rules (slots, power budget, per-hero caps) come from LoadoutRules.

signal confirmed(heroes: Array[String])

var level: Level
var level_id: int = 1
var _level_data: Dictionary = {}
var _selection: Array[String] = []
var _counts: Dictionary = {}
var _minus: Dictionary = {}
var _plus: Dictionary = {}
var _order: HBoxContainer
var _power: Label
var _message: Label
var _tip: Label
var _battle: Button
var _shots: Label
## Material id -> block count in this fortress, most common first (see fortress_materials).
var _materials: Array = []


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level_data = level.data if level else Data.level(level_id)
	_selection = LoadoutRules.saved_or_recommended(_level_data, level_id)
	_materials = fortress_materials(_level_data)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, Data.bf("loadout", "dim_alpha"))
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	_build_header(root)
	_build_stats(root)
	_build_order(root)
	_build_cards(root)
	_build_fortress(root)
	_build_weapon(root)
	_build_actions(root)
	_refresh()
	Sound.play("popup_open", 0.7)
	for i: int in root.get_child_count():
		var c: Control = root.get_child(i) as Control
		if c and c != dim:
			UIFx.pop_in(c, 0.02 * i)


static func _style(bg: Color, border: Color, radius: int = 18, width: int = 4) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.border_width_bottom = width + 3
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _build_header(root: Control) -> void:
	var home: Button = UIKit.icon_button("icon_home", "orange", 72)
	UIKit.place(home, Vector2.ZERO, Vector2(16, 14), Vector2(72, 72))
	home.pressed.connect(func() -> void:
		Sound.play("ui_back")
		Game.goto_map())
	UIFx.press_juice(home)
	root.add_child(home)
	var holder: CenterContainer = CenterContainer.new()
	UIKit.place(holder, Vector2(0.5, 0), Vector2(-300, 6), Vector2(600, 96))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sign: PanelContainer = UIKit.wood_sign()
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override("separation", -6)
	titles.add_child(UIKit.label("PLAN THE ASSAULT", 40, Color("#ffd23a"), 10))
	titles.add_child(UIKit.label("Level %d · %s" % [level_id, String(_level_data.get("name", ""))], 24, Color.WHITE, 7))
	sign.add_child(titles)
	holder.add_child(sign)
	root.add_child(holder)
	var brief: PanelContainer = PanelContainer.new()
	brief.add_theme_stylebox_override("panel", _style(Color("#f3dfb2"), Color("#8a5a2a"), 10, 3))
	brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl: Label = UIKit.label(String(_level_data.get("strategy", "Study the fortress, then choose your heroes.")), 19, UIKit.TEXT_DARK, 0, false)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(500, 0)
	brief.add_child(bl)
	var bc: CenterContainer = CenterContainer.new()
	UIKit.place(bc, Vector2(0.5, 0), Vector2(-280, 100), Vector2(560, 70))
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.add_child(brief)
	root.add_child(bc)


## Top right: what the player is up against (same numbers as the in-level HUD).
func _build_stats(root: Control) -> void:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color("#f3dfb2"), Color("#8a5a2a"), 16, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.place(p, Vector2(1, 0), Vector2(-470, 12), Vector2(456, 80))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var guards: int = level.archers.size() if level else (_level_data.get("archers", []) as Array).size()
	var rows: Array = [["hero_stone", "Shots", "%d / %d" % [LoadoutRules.slots(), LoadoutRules.slots()]],
			["logo_castle", "Destruction", "0%"], ["archer_idle", "Objective", "%d guards" % guards]]
	for r: Array in rows:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.add_child(UIKit.tex_rect(String(r[0]), 40))
		var v: VBoxContainer = VBoxContainer.new()
		v.add_theme_constant_override("separation", -6)
		v.add_child(UIKit.label(String(r[1]), 15, UIKit.TEXT_DARK, 0, false))
		var val: Label = UIKit.label(String(r[2]), 21, UIKit.TEXT_DARK, 0)
		v.add_child(val)
		if String(r[1]) == "Shots":
			_shots = val
		cell.add_child(v)
		h.add_child(cell)
	root.add_child(p)


## Firing order (tap a slot to remove that hero) and the arcane power budget.
func _build_order(root: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	UIKit.place(row, Vector2(0.5, 0), Vector2(-400, 172), Vector2(800, 52))
	row.add_child(UIKit.label("FIRING ORDER", 20, Color("#ffd23a"), 6))
	_order = HBoxContainer.new()
	_order.add_theme_constant_override("separation", 6)
	row.add_child(_order)
	_power = UIKit.label("", 22, Color("#ffe27a"), 7)
	_power.custom_minimum_size.x = 240
	row.add_child(_power)
	root.add_child(row)


func _build_cards(root: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	UIKit.place(row, Vector2(0.5, 0), Vector2(-600, 222), Vector2(1200, 340))
	for kind: String in _all_kinds():
		row.add_child(_hero_card(kind))
	root.add_child(row)
	var tip_pill: PanelContainer = UIKit.info_pill("icon_info", "Tap + to add a hero. They fire in the order you add them.", 20)
	_tip = (tip_pill.get_child(0) as HBoxContainer).get_child(1) as Label
	UIKit.place(tip_pill, Vector2(0.5, 0), Vector2(-330, 556), Vector2(660, 44))
	tip_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(tip_pill)


func _all_kinds() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in Data.projectiles.keys():
		var cfg: Variant = Data.projectiles[key]
		if cfg is Dictionary and (cfg as Dictionary).has("name"):
			out.append(String(key))
	out.sort_custom(func(a: String, b: String) -> bool:
		return int(Data.projectiles[a]["unlock_level"]) < int(Data.projectiles[b]["unlock_level"]))
	return out


func _available(kind: String) -> bool:
	return LoadoutRules.unlocked_kinds(level_id, _level_data).has(kind)


func _hero_card(kind: String) -> Control:
	var cfg: Dictionary = Data.projectiles[kind]
	var open: bool = _available(kind)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", -26)
	v.custom_minimum_size.x = 222
	var art: TextureButton = TextureButton.new()
	art.texture_normal = Art.tex(String(cfg["texture"]))
	art.ignore_texture_size = true
	art.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(222, 150)
	art.modulate = Color.WHITE if open else Color(0.25, 0.25, 0.3, 0.9)
	art.disabled = not open
	art.pressed.connect(_add_kind.bind(kind))
	v.add_child(art)
	var plaque: PanelContainer = PanelContainer.new()
	plaque.add_theme_stylebox_override("panel", _style(Color("#6a3f1e"), Color("#3a2212")))
	plaque.custom_minimum_size = Vector2(222, 0)
	var pv: VBoxContainer = VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	plaque.add_child(pv)
	pv.add_child(UIKit.label(String(cfg["name"]) if open else "Locked", 28, Color(cfg["accent"]) if open else Color("#c9ccd2"), 8))
	var tl: Label = UIKit.label(String(cfg.get("tagline", "")) if open else "Joins at level %d" % int(cfg["unlock_level"]), 16, Color("#ffe8c0"), 0, false)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(196, 42)
	pv.add_child(tl)
	pv.add_child(UIKit.label("Power %d · Max %d" % [int(cfg["power_cost"]), int(cfg["max_per_loadout"])], 17, Color.WHITE, 4, false))
	if open and is_strong(kind, _materials):
		var badge: Label = UIKit.label("STRONG HERE", 15, Color("#8dff78"), 5)
		pv.add_child(badge)
	var step: HBoxContainer = HBoxContainer.new()
	step.alignment = BoxContainer.ALIGNMENT_CENTER
	step.add_theme_constant_override("separation", 6)
	var minus: Button = _step_button("−")
	minus.pressed.connect(_remove_kind.bind(kind))
	var count: PanelContainer = PanelContainer.new()
	count.add_theme_stylebox_override("panel", _style(Color("#2a180c"), Color("#1a0e06"), 10, 2))
	count.custom_minimum_size = Vector2(70, 52)
	var cl: Label = UIKit.label("0", 30, Color.WHITE, 6)
	count.add_child(cl)
	var plus: Button = _step_button("+")
	plus.pressed.connect(_add_kind.bind(kind))
	for c: Control in [minus, count, plus]:
		step.add_child(c)
	pv.add_child(step)
	_counts[kind] = cl
	_minus[kind] = minus
	_plus[kind] = plus
	if not open:
		minus.disabled = true
		plus.disabled = true
	v.add_child(plaque)
	return v


func _step_button(text: String) -> Button:
	var b: Button = UIKit.button(text, "orange", 34, Vector2(56, 52))
	var off: StyleBoxFlat = UIKit._box(Color("#8a8f99"), Color("#5a5f69"), 24, 8)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_color_override("font_disabled_color", Color("#d8dce2"))
	UIFx.press_juice(b)
	return b


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
	UIKit.place(panel, Vector2(0, 1), Vector2(16, -100), Vector2(520, 86))
	root.add_child(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
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
		chip.custom_minimum_size = Vector2(64, 62)
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


## Siege weapon button: tap to cycle the unlocked weapons.
func _build_weapon(root: Control) -> void:
	var b: Button = UIKit.button("", "blue", 24, Vector2(220, 86))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 60)
	UIKit.place(b, Vector2(0, 1), Vector2(548, -100), Vector2(220, 86))
	root.add_child(b)
	UIFx.press_juice(b)
	var show: Callable = func() -> void:
		var w: String = Progression.weapon()
		b.icon = Art.tex("icon_weapon_" + w)
		b.text = String(Progression.weapon_cfg(w)["short_name"]).to_upper()
	show.call()
	b.pressed.connect(func() -> void:
		var list: Array = Progression.weapons().filter(func(id: Variant) -> bool: return Progression.weapon_unlocked(String(id)))
		if list.size() <= 1:
			_tip.text = "Master Orin reveals Ballista after Level %d and Trebuchet after Level %d. Forge them with coins in Upgrades." % [
				int(Progression.weapon_cfg("ballista")["unlock_level"]) - 1, int(Progression.weapon_cfg("trebuchet")["unlock_level"]) - 1]
			return
		var i: int = list.find(Progression.weapon())
		Progression.set_weapon(String(list[(i + 1) % list.size()]))
		if level:
			level.apply_weapon()
		Sound.play("lever", 0.6)
		UIFx.pop(b, 1.1)
		show.call()
		_tip.text = "%s · %s" % [String(Progression.weapon_cfg()["name"]), String(Progression.weapon_cfg()["desc"])])


func _build_actions(root: Control) -> void:
	_message = UIKit.label("", 19, Color("#ffb0a0"), 6, false)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.place(_message, Vector2(1, 1), Vector2(-520, -134), Vector2(500, 30))
	root.add_child(_message)
	var rec: Button = UIKit.button("RECOMMENDED", "orange", 21, Vector2(220, 80))
	for st: String in ["normal", "hover", "pressed"]:
		rec.add_theme_stylebox_override(st, _style(Color("#f6e2b8") if st != "pressed" else Color("#e6d0a0"), Color("#a8743a"), 20, 3))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		rec.add_theme_color_override(k, UIKit.TEXT_DARK)
	rec.add_theme_constant_override("outline_size", 0)
	rec.icon = Art.tex("star_full")
	rec.expand_icon = true
	rec.add_theme_constant_override("icon_max_width", 30)
	UIKit.place(rec, Vector2(1, 1), Vector2(-494, -96), Vector2(220, 80))
	rec.pressed.connect(_use_recommended)
	UIFx.press_juice(rec)
	root.add_child(rec)
	_battle = UIKit.button("TO BATTLE!", "green", 32, Vector2(258, 90))
	_battle.icon = Art.tex("icon_challenges")
	_battle.expand_icon = true
	_battle.add_theme_constant_override("icon_max_width", 46)
	UIKit.place(_battle, Vector2(1, 1), Vector2(-268, -102), Vector2(258, 90))
	_battle.pressed.connect(_start)
	UIFx.press_juice(_battle)
	root.add_child(_battle)


func _add_kind(kind: String) -> void:
	_tip.text = "%s · %s" % [String(Data.projectiles[kind]["ability"]), String(Data.projectiles[kind]["strategy"])]
	if not _available(kind):
		return
	if _selection.size() >= LoadoutRules.slots():
		_message.text = "All %d slots are full. Use − to free one." % LoadoutRules.slots()
		Sound.play("deny", 0.6)
		return
	if _selection.count(kind) >= int(Data.projectiles[kind]["max_per_loadout"]):
		_message.text = "The wizard can prepare only %d %s." % [int(Data.projectiles[kind]["max_per_loadout"]), String(Data.projectiles[kind]["name"])]
		Sound.play("deny", 0.6)
		return
	_selection.append(kind)
	Sound.play("pop", 0.7)
	_refresh()
	UIFx.pop(_counts[kind].get_parent() as Control, 1.2)


## − removes the last copy of that hero from the firing order.
func _remove_kind(kind: String) -> void:
	var i: int = _selection.rfind(kind)
	if i < 0:
		return
	_selection.remove_at(i)
	Sound.play("ui_tap", 0.7)
	_refresh()


func _use_recommended() -> void:
	_selection = LoadoutRules.recommended(_level_data, level_id)
	_tip.text = "The captain's balanced plan is ready. Change any count with − and +."
	Sound.play("upgrade", 0.6)
	_refresh()


func _refresh() -> void:
	for kind: String in _counts:
		var n: int = _selection.count(kind)
		(_counts[kind] as Label).text = str(n)
		if _available(kind):
			(_minus[kind] as Button).disabled = n == 0
			(_plus[kind] as Button).disabled = n >= int(Data.projectiles[kind]["max_per_loadout"]) or _selection.size() >= LoadoutRules.slots()
	for c: Node in _order.get_children():
		c.queue_free()
	for i: int in LoadoutRules.slots():
		var slot: Button = Button.new()
		slot.custom_minimum_size = Vector2(52, 52)
		slot.focus_mode = Control.FOCUS_NONE
		var sb: StyleBoxFlat = _style(Color(0.1, 0.07, 0.04, 0.75), Color("#ffd23a") if i == 0 else Color("#c8a060"), 24, 2)
		sb.set_content_margin_all(4)
		slot.add_theme_stylebox_override("normal", sb)
		slot.add_theme_stylebox_override("hover", sb)
		slot.add_theme_stylebox_override("pressed", sb)
		if i < _selection.size():
			slot.icon = Art.tex(String(Data.projectiles[_selection[i]]["texture"]))
			slot.expand_icon = true
			slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.pressed.connect(func() -> void:
				_selection.remove_at(i)
				Sound.play("ui_tap", 0.7)
				_refresh())
		else:
			slot.text = str(i + 1)
			slot.add_theme_color_override("font_color", Color("#c8a060"))
		_order.add_child(slot)
	var cost: int = LoadoutRules.cost(_selection)
	var budget: int = LoadoutRules.power_budget(_level_data, level_id)
	_power.text = "ARCANE POWER  %d / %d" % [cost, budget]
	_power.add_theme_color_override("font_color", Color("#ff8a7a") if cost > budget else Color("#ffe27a"))
	if _shots:
		_shots.text = "%d / %d" % [_selection.size(), LoadoutRules.slots()]
	var err: String = LoadoutRules.error(_selection, level_id, _level_data)
	_message.text = err
	_battle.disabled = not err.is_empty()


func _start() -> void:
	if not LoadoutRules.valid(_selection, level_id, _level_data):
		_refresh()
		UIFx.shake(_battle)
		return
	var all: Dictionary = Save.data.get("loadouts", {})
	all[str(level_id)] = _selection.duplicate()
	Save.data["loadouts"] = all
	Save.write()
	Sound.play("play_press")
	confirmed.emit(_selection.duplicate())
	queue_free()
