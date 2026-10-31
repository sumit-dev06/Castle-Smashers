class_name UpgradesScreen
extends MetaFrame
## Master Orin's Workshop: campaign milestones reveal engines and heroes. Engines then require a
## substantial coin forge cost and have three specific upgrades with real gameplay effects. Hero
## power is fixed; their cards state the campaign level where Orin introduces them.

var weapon_id: String = ""
var back_to_level: int = 0
var focus_hero: String = ""
var _name_box: VBoxContainer
var _stats: VBoxContainer
var _hero_strip: HBoxContainer
var _cat: Catapult
var _vanguard_preview: Node2D
var _wizard_line: Label
## Centre x of the engine column between the rail and the stats panel.
var _cx: float = 530.0


func _title() -> String:
	return "Master Orin's Workshop"


func _icon() -> String:
	return "icon_workshop"


func _rail_items() -> Array:
	var out: Array = []
	for wid: Variant in Progression.weapons():
		var id: String = String(wid)
		out.append([id, String(Progression.weapon_cfg(id)["short_name"]), "icon_weapon_" + id])
	out.append(["vanguard", "Vanguard", "icon_units"])
	return out


func _bg_realm() -> int:
	return 4


func _back() -> void:
	if back_to_level > 0:
		Game.goto_loadout(back_to_level)
	else:
		Game.goto_menu()


func _ready() -> void:
	weapon_id = String(Game.args.get("weapon-preview", Progression.weapon())) if OS.is_debug_build() else Progression.weapon()
	if not Progression.weapons().has(weapon_id) and weapon_id != "vanguard":
		weapon_id = Progression.weapon()
	rail_key = weapon_id
	rail_bottom = -196.0
	super._ready()


func _rail_pressed(key: String) -> void:
	weapon_id = key
	rail_key = key
	_build_rail()
	_show_selection()


func _build() -> void:
	_name_box = VBoxContainer.new()
	_name_box.add_theme_constant_override("separation", -2)
	# Engine column is centred between the rail (278) and the stats panel (548 from the right).
	_cx = (278.0 + get_viewport().get_visible_rect().size.x - 548.0) * 0.5
	UIKit.place(_name_box, Vector2.ZERO, Vector2(_cx - 150.0, 96), Vector2(300, 125))
	body.add_child(_name_box)
	var plinth: Panel = Panel.new()
	plinth.add_theme_stylebox_override("panel", card_box(Color("#775238"), Color("#3a2212")))
	UIKit.place(plinth, Vector2.ZERO, Vector2(_cx - 151.0, 487), Vector2(302, 34))
	plinth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(plinth)
	for side: int in [-1, 1]:
		var arrow: Button = UIKit.button("<" if side < 0 else ">", "orange", 40, Vector2(64, 74))
		UIKit.place(arrow, Vector2.ZERO, Vector2(maxf(282.0, _cx - 254.0) if side < 0 else minf(_cx + 190.0, get_viewport().get_visible_rect().size.x - 548.0 - 70.0), 320), Vector2(64, 74))
		arrow.pressed.connect(_cycle.bind(side))
		UIFx.press_juice(arrow)
		body.add_child(arrow)
	var stats_panel: PanelContainer = _dark_panel()
	UIKit.place(stats_panel, Vector2(1, 0), Vector2(-548, 96), Vector2(532, 424))
	body.add_child(stats_panel)
	var sv: VBoxContainer = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 7)
	stats_panel.add_child(sv)
	sv.add_child(UIKit.label("Forge & Upgrades", 30, Color("#fff2c8"), 8))
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 7)
	sv.add_child(_stats)
	UIFx.slide_in(stats_panel, Vector2(1, 0), 0.05)
	_build_wizard_panel()
	_show_selection()


func _build_wizard_panel() -> void:
	var p: PanelContainer = _dark_panel()
	UIKit.place(p, Vector2(0, 1), Vector2(278, -188), Vector2(0, 176))
	p.anchor_right = 1.0
	p.offset_right = -14
	body.add_child(p)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var narrow: bool = get_viewport().get_visible_rect().size.x < 1500.0
	var wizard: TextureRect = UIKit.tex_rect("wizard_idle", 96 if narrow else 126)
	h.add_child(wizard)
	var speech: VBoxContainer = VBoxContainer.new()
	speech.custom_minimum_size.x = 190 if narrow else 250
	speech.add_theme_constant_override("separation", 2)
	speech.add_child(UIKit.label(String(Data.balance["wizard_workshop"]["name"]), 25, Color("#ffd23a"), 7))
	_wizard_line = UIKit.label(String(Data.balance["wizard_workshop"]["intro"]), 17, Color.WHITE, 4, false)
	_wizard_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wizard_line.custom_minimum_size = Vector2(speech.custom_minimum_size.x, 82)
	speech.add_child(_wizard_line)
	h.add_child(speech)
	var divider: VSeparator = VSeparator.new()
	h.add_child(divider)
	_hero_strip = HBoxContainer.new()
	_hero_strip.add_theme_constant_override("separation", 7)
	h.add_child(_hero_strip)
	_fill_heroes()
	UIFx.slide_in(p, Vector2(0, 1), 0.1)


func _cycle(side: int) -> void:
	var list: Array = Progression.weapons().duplicate()
	list.append("vanguard")
	var i: int = (list.find(weapon_id) + side + list.size()) % list.size()
	Sound.play("whoosh", 0.5)
	_rail_pressed(String(list[i]))


func _show_selection() -> void:
	for n: Node in _name_box.get_children():
		n.queue_free()
	for n: Node in _stats.get_children():
		n.queue_free()
	if weapon_id == "vanguard":
		_show_vanguard()
	else:
		_show_weapon()
	_fill_heroes()


func _show_weapon() -> void:
	var cfg: Dictionary = Progression.weapon_cfg(weapon_id)
	_name_box.add_child(UIKit.label(String(cfg["name"]), 45, Color.WHITE, 11))
	_name_box.add_child(UIKit.label(String(cfg["role"]).to_upper(), 20, Color("#ffd23a"), 6))
	var desc: Label = UIKit.label(String(cfg["desc"]), 18, Color.WHITE, 5, false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 300
	_name_box.add_child(desc)
	if _vanguard_preview:
		_vanguard_preview.visible = false
	if _cat == null:
		_cat = preview_catapult(Vector2(_cx, 492), 0.88, weapon_id)
	else:
		_cat.get_parent().visible = true
		_cat.set_appearance(weapon_id, Progression.equipped("skins"))
	_cat.get_parent().modulate = Color.WHITE if Progression.weapon_level_met(weapon_id) else Color(0.2, 0.2, 0.24)
	_cat.get_parent().scale = Vector2.ONE * 0.88
	var level_met: bool = Progression.weapon_level_met(weapon_id)
	var owned: bool = Progression.weapon_owned(weapon_id)
	if not level_met:
		_wizard_line.text = String(Data.balance["wizard_workshop"]["locked_line"]) % (int(cfg["unlock_level"]) - 1)
		_stats.add_child(_notice("LOCKED", "Complete Level %d to reveal this engine." % (int(cfg["unlock_level"]) - 1), "icon_lock"))
		return
	if not owned:
		_wizard_line.text = String(Data.balance["wizard_workshop"]["available_line"])
		_stats.add_child(_unlock_card(cfg))
		return
	_wizard_line.text = String(Data.balance["wizard_workshop"]["owned_line"])
	var equipped: bool = Progression.weapon() == weapon_id
	var equip: Button = UIKit.button("EQUIPPED" if equipped else "EQUIP ENGINE", "dark" if equipped else "blue", 24, Vector2(0, 58))
	equip.disabled = equipped
	equip.pressed.connect(func() -> void:
		Progression.set_weapon(weapon_id)
		Sound.play("lever", 0.9)
		UIFx.celebrate(_cat.get_parent(), "EQUIPPED!")
		_show_selection())
	UIFx.press_juice(equip)
	_stats.add_child(equip)
	for track: String in Progression.weapon_tracks(weapon_id):
		_stats.add_child(_weapon_upgrade_row(track))


func _show_vanguard() -> void:
	_name_box.add_child(UIKit.label("Vanguard Foundry", 45, Color.WHITE, 11))
	_name_box.add_child(UIKit.label("ARMOR FOR YOUR SOLDIERS", 20, Color("#ffd23a"), 6))
	_name_box.add_child(UIKit.label("Armor your soldiers keep for every battle. Paid with coins.", 20, Color.WHITE, 5, false))
	if _cat:
		_cat.get_parent().visible = false
	if _vanguard_preview == null:
		_vanguard_preview = Node2D.new()
		_vanguard_preview.position = Vector2(_cx, 482)
		body.add_child(_vanguard_preview)
		for i: int in 3:
			var soldier: Sprite2D = Art.unit_sprite("soldier_idle", 120)
			soldier.position = Vector2((i - 1) * 82, 0)
			_vanguard_preview.add_child(soldier)
	_vanguard_preview.visible = true
	_wizard_line.text = "Steel for the Vanguard is never wasted. Armor keeps your crew in the fight."
	for track: String in Data.balance["upgrades"]["vanguard"]:
		_stats.add_child(_vanguard_row(track))


func _unlock_card(cfg: Dictionary) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#55320f"), Color("#ffd23a")))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UIKit.label("ENGINE BLUEPRINT MASTERED", 25, Color("#ffd23a"), 7))
	v.add_child(UIKit.label("Forge it once and it is yours for good.", 20, Color.WHITE, 4, false))
	var cost: Dictionary = Progression.weapon_unlock_cost(weapon_id)
	var buy: Button = _coin_button("FORGE  " + CurrencyBar._fmt(int(cost["coins"])), int(cost["coins"]))
	buy.pressed.connect(func() -> void:
		if Progression.buy_weapon(weapon_id):
			Sound.play("anvil")
			UIFx.celebrate(p, "ENGINE FORGED!")
			_show_selection.call_deferred()
		else:
			_deny_coins(buy))
	v.add_child(buy)
	return p


func _weapon_upgrade_row(track: String) -> Control:
	var cfg: Dictionary = Progression.weapon_tracks(weapon_id)[track]
	var level: int = Progression.weapon_up_level(weapon_id, track)
	var cost: Dictionary = Progression.weapon_up_cost(weapon_id, track)
	return _upgrade_row(String(cfg["title"]), String(cfg["desc"]), String(cfg["icon"]), level, int(cfg["max"]), cost,
			func() -> bool: return Progression.buy_weapon_up(weapon_id, track))


func _vanguard_row(track: String) -> Control:
	var cfg: Dictionary = Progression.up_cfg("vanguard", track)
	var level: int = Progression.up_level("vanguard", track)
	var cost: Dictionary = Progression.up_cost("vanguard", track)
	return _upgrade_row(String(cfg["title"]), String(cfg["desc"]), "icon_units" if track == "armor" else "status_armor",
			level, int(cfg["max"]), cost, func() -> bool: return Progression.buy_up("vanguard", track))


func _upgrade_row(title: String, desc: String, icon: String, level: int, maximum: int, cost: Dictionary, buy_call: Callable) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#392313"), Color("#79502c")))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	p.add_child(h)
	h.add_child(UIKit.tex_rect(icon, 43))
	var mid: VBoxContainer = VBoxContainer.new()
	mid.custom_minimum_size.x = 245
	mid.add_theme_constant_override("separation", 0)
	var title_label: Label = UIKit.label(title, 20, Color.WHITE, 5)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(title_label)
	var desc_label: Label = UIKit.label(desc, 15, Color("#ead9bc"), 0, false)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(desc_label)
	var segments: HBoxContainer = HBoxContainer.new()
	segments.add_theme_constant_override("separation", 3)
	for i: int in maximum:
		var segment: ColorRect = ColorRect.new()
		segment.custom_minimum_size = Vector2(202.0 / maximum - 3.0, 11)
		segment.color = Color("#ffb52a") if i < level else Color("#170e08")
		segments.add_child(segment)
	mid.add_child(segments)
	h.add_child(mid)
	var button: Button
	if cost.is_empty():
		button = UIKit.button("MAX", "dark", 20, Vector2(140, 52))
		button.disabled = true
	else:
		button = _coin_button(CurrencyBar._fmt(int(cost["coins"])), int(cost["coins"]))
		button.pressed.connect(func() -> void:
			if buy_call.call():
				Sound.play("anvil")
				UIFx.celebrate(p, "POWER UP!")
				_show_selection.call_deferred()
			else:
				_deny_coins(button))
	h.add_child(button)
	return p


func _coin_button(text: String, cost: int) -> Button:
	var button: Button = UIKit.button(" " + text, "green", 20, Vector2(140, 52))
	button.icon = Art.tex("coin")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 25)
	button.tooltip_text = "%s coins" % CurrencyBar._fmt(cost)
	UIFx.press_juice(button)
	return button


func _deny_coins(control: Control) -> void:
	UIFx.shake(control)
	Sound.play("deny")
	bar.deny("coins")


func _notice(title: String, text: String, icon: String) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#30261f"), Color("#72665c")))
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(UIKit.tex_rect(icon, 72))
	v.add_child(UIKit.label(title, 30, Color("#ffe27a"), 7))
	var label: Label = UIKit.label(text, 19, Color.WHITE, 4, false)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(label)
	return p


func _fill_heroes() -> void:
	if _hero_strip == null:
		return
	for n: Node in _hero_strip.get_children():
		n.queue_free()
	for kind: Variant in Workshop.hero_order():
		_hero_strip.add_child(_hero_card(String(kind)))


func _hero_card(kind: String) -> Control:
	var cfg: Dictionary = Data.projectiles[kind]
	var introduced: bool = Workshop.introduced(kind)
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#3b2819"), Color("#ffd23a") if kind == focus_hero else Color("#6a4424")))
	p.custom_minimum_size = Vector2(124, 132)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var portrait: TextureRect = UIKit.tex_rect(String(cfg["texture"]), 56)
	portrait.modulate = Color.WHITE if introduced else Color(0.25, 0.25, 0.28)
	v.add_child(portrait)
	v.add_child(UIKit.label(String(cfg["name"]), 17, Color.WHITE, 4))
	if introduced:
		v.add_child(UIKit.label("Introduced · L%d" % Workshop.intro_level(kind), 13, Color("#8df078"), 3, false))
	else:
		v.add_child(UIKit.label("Unlocks at Level %d" % Workshop.intro_level(kind), 13, Color("#ffd070"), 3, false))
		var lock: TextureRect = UIKit.tex_rect("icon_lock", 22)
		v.add_child(lock)
	# Tap an unlocked hero to replay its training range (how to use the ability).
	if introduced and Data.has_training(kind):
		v.add_child(UIKit.label("Tap to practise", 18, Color("#9fd8ff"), 3, false))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
					and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				Sound.play("ui_tap")
				Game.goto_training(kind, int(Data.training(kind).get("before_level", 1)), true))
	return p
