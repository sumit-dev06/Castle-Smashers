class_name UpgradesScreen
extends MetaFrame
## Upgrades / Workshop (owner reference docs/reference/upgrades_reference.png): left rail of siege
## weapons; the selected weapon large on a wooden platform with arrows, name and description;
## "Stats & Upgrades" rows (icon, name, segmented bar, Lv., green price button); bottom strips for
## the heroes (Workshop hero upgrades) and the Vanguard. Upgrading fills the bar segment by segment
## with sparks, flips the level in, and plays the anvil sound.

var weapon_id: String = ""
var back_to_level: int = 0
var _stats: VBoxContainer
var _hero_strip: HBoxContainer
var _big: TextureRect
var _cat: Catapult


func _title() -> String:
	return "Upgrades"


func _icon() -> String:
	return "icon_upgrades"


func _rail_items() -> Array:
	var out: Array = []
	for w: Variant in Progression.weapons():
		out.append([String(w), String(Progression.weapon_cfg(String(w))["name"]), "icon_weapon_" + String(w)])
	return out


func _bg_realm() -> int:
	return 4


func _back() -> void:
	if back_to_level > 0:
		Game.goto_loadout(back_to_level)
	else:
		Game.goto_menu()


func _ready() -> void:
	weapon_id = Progression.weapon()
	rail_key = weapon_id
	rail_bottom = -208.0
	super._ready()


func _rail_pressed(key: String) -> void:
	weapon_id = key
	rail_key = key
	_build_rail()
	_show_weapon()


func _build() -> void:
	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.add_theme_constant_override("separation", -4)
	name_box.name = "NameBox"
	UIKit.place(name_box, Vector2.ZERO, Vector2(284, 96), Vector2(470, 120))
	body.add_child(name_box)
	_big = TextureRect.new()
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UIKit.place(_big, Vector2.ZERO, Vector2(330, 210), Vector2(380, 300))
	body.add_child(_big)
	var plinth: Panel = Panel.new()
	plinth.add_theme_stylebox_override("panel", card_box(Color("#7a5232"), Color("#3a2212")))
	UIKit.place(plinth, Vector2.ZERO, Vector2(310, 490), Vector2(420, 34))
	plinth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(plinth)
	for side: int in [-1, 1]:
		var arrow: Button = UIKit.button("<" if side < 0 else ">", "orange", 40, Vector2(64, 74))
		UIKit.place(arrow, Vector2.ZERO, Vector2(276 if side < 0 else 704, 320), Vector2(64, 74))
		arrow.pressed.connect(_cycle.bind(side))
		UIFx.press_juice(arrow)
		body.add_child(arrow)
	var sp: PanelContainer = _dark_panel()
	UIKit.place(sp, Vector2(1, 0), Vector2(-540, 96), Vector2(524, 380))
	body.add_child(sp)
	var sv: VBoxContainer = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sp.add_child(sv)
	sv.add_child(UIKit.label("Stats & Upgrades", 30, Color("#fff2c8"), 8))
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 6)
	sv.add_child(_stats)
	UIFx.slide_in(sp, Vector2(1, 0), 0.05)
	var hp: PanelContainer = _dark_panel()
	UIKit.place(hp, Vector2(0, 1), Vector2(14, -196), Vector2(0, 184))
	hp.anchor_right = 1.0
	hp.offset_right = -14
	body.add_child(hp)
	var hv: VBoxContainer = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hp.add_child(hv)
	hv.add_child(UIKit.label("Heroes", 26, Color("#fff2c8"), 7))
	_hero_strip = HBoxContainer.new()
	_hero_strip.add_theme_constant_override("separation", 10)
	hv.add_child(_hero_strip)
	UIFx.slide_in(hp, Vector2(0, 1), 0.1)
	_show_weapon()


func _cycle(side: int) -> void:
	var list: Array = Progression.weapons()
	var i: int = (list.find(weapon_id) + side + list.size()) % list.size()
	Sound.play("whoosh", 0.5)
	_rail_pressed(String(list[i]))


func _show_weapon() -> void:
	var c: Dictionary = Progression.weapon_cfg(weapon_id)
	var nb: VBoxContainer = body.get_node("NameBox")
	for n: Node in nb.get_children():
		n.queue_free()
	nb.add_child(UIKit.label(String(c["name"]), 52, Color.WHITE, 12))
	var unlocked: bool = Progression.weapon_unlocked(weapon_id)
	var equipped: bool = Progression.weapon() == weapon_id
	nb.add_child(UIKit.label("EQUIPPED" if equipped else ("Tap to equip" if unlocked else "Unlocks after level %d" % (int(c["unlock_level"]) - 1)),
			22, Color("#7ae05a") if equipped else Color("#ffe27a"), 6))
	var d: Label = UIKit.label(String(c["desc"]), 21, Color.WHITE, 6, false)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nb.add_child(d)
	for n2: Node in nb.get_children():
		(n2 as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# The catapult is shown with the game's own art; ballista / trebuchet use their weapon icon.
	if weapon_id == "catapult":
		_big.texture = null
		if _cat == null:
			_cat = preview_catapult(Vector2(560, 488), 1.0)
		_cat.get_parent().visible = true
	else:
		if _cat:
			_cat.get_parent().visible = false
		_big.texture = Art.tex("icon_weapon_" + weapon_id)
	var wt: Dictionary = Progression.weapon_cfg(weapon_id)
	_big.modulate = Progression._col(wt["tint_base"]) if unlocked else Color(0.35, 0.35, 0.4)
	_big.pivot_offset = _big.size * 0.5
	_big.scale = Vector2.ONE * 0.6
	_big.create_tween().tween_property(_big, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _big.gui_input.is_connected(_on_big_input):
		_big.mouse_filter = Control.MOUSE_FILTER_STOP
		_big.gui_input.connect(_on_big_input)
	_fill_stats()
	_fill_heroes()


func _on_big_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and Progression.weapon_unlocked(weapon_id):
		Progression.set_weapon(weapon_id)
		Sound.play("lever", 0.8)
		UIFx.pop(_big, 1.15)
		_show_weapon()


func _fill_stats() -> void:
	for n: Node in _stats.get_children():
		n.queue_free()
	var rows: Array = [["weapon", "power", "status_cannon"], ["weapon", "reload", "icon_restart"],
			["vanguard", "armor", "icon_units"], ["vanguard", "shields", "status_armor"]]
	for r: Array in rows:
		_stats.add_child(_stat_row(String(r[0]), String(r[1]), String(r[2])))


func _stat_row(group: String, track: String, icon: String) -> Control:
	var c: Dictionary = Progression.up_cfg(group, track)
	var lv: int = Progression.up_level(group, track)
	var mx: int = int(c["max"])
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#3a2414"), Color("#6a4424")))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(UIKit.tex_rect(icon, 48))
	var mid: VBoxContainer = VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	mid.custom_minimum_size.x = 190
	var t: Label = UIKit.label(String(c["title"]), 21, Color.WHITE, 5)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(t)
	var segs: HBoxContainer = HBoxContainer.new()
	segs.add_theme_constant_override("separation", 3)
	for i: int in mx:
		var s: ColorRect = ColorRect.new()
		s.custom_minimum_size = Vector2(176.0 / mx - 3.0, 14)
		s.color = Color("#ffb52a") if i < lv else Color(0.12, 0.08, 0.05)
		segs.add_child(s)
	mid.add_child(segs)
	h.add_child(mid)
	var lvl: Label = UIKit.label("Lv. %d" % lv, 20, Color.WHITE, 5)
	lvl.custom_minimum_size.x = 56
	h.add_child(lvl)
	var cost: Dictionary = Progression.up_cost(group, track)
	var b: Button
	if cost.is_empty():
		b = UIKit.button("MAX", "dark", 22, Vector2(150, 54))
		b.disabled = true
	else:
		var label: String = " " + CurrencyBar._fmt(int(cost.get("coins", 0)))
		if cost.has("blueprints"):
			label += " +%d" % int(cost["blueprints"])
		b = UIKit.button(label, "green", 20, Vector2(150, 54))
		b.icon = Art.tex("coin")
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 26)
		b.pressed.connect(func() -> void:
			if Progression.buy_up(group, track):
				_upgraded(segs, lv, lvl)
				get_tree().create_timer(0.7).timeout.connect(_fill_stats)
			else:
				UIFx.shake(b)
				Sound.play("deny")
				for k: String in cost:
					if Save.amount(k) < int(cost[k]):
						bar.deny(k))
		UIFx.press_juice(b)
	h.add_child(b)
	return p


## Upgrade juice: the new bar segment fills with sparks, the level flips in, anvil + shake.
func _upgraded(segs: HBoxContainer, old_lv: int, lvl: Label) -> void:
	var seg: ColorRect = segs.get_child(old_lv) as ColorRect
	var tw: Tween = seg.create_tween()
	tw.tween_property(seg, "color", Color(2, 1.6, 0.8), 0.12)
	tw.tween_property(seg, "color", Color("#ffb52a"), 0.25)
	Sound.play("anvil")
	UIFx.rays(UIFx.overlay(), seg.get_global_rect().get_center(), 160.0, 0.4)
	lvl.text = "Lv. %d" % (old_lv + 1)
	lvl.pivot_offset = lvl.size * 0.5
	lvl.scale = Vector2(1, 0)
	lvl.create_tween().tween_property(lvl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	UIFx.shake(root, 6.0)
	UIFx.confetti(seg.get_global_rect().get_center(), 18)


func _fill_heroes() -> void:
	for n: Node in _hero_strip.get_children():
		n.queue_free()
	for kind: String in ["stone", "fire", "bomb", "cyclone", "quake"]:
		_hero_strip.add_child(_hero_card(kind))


func _hero_card(kind: String) -> Control:
	var cfg: Dictionary = Data.projectiles[kind]
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#3a2414"), Color("#6a4424")))
	p.custom_minimum_size = Vector2(210, 130)
	var h: HBoxContainer = HBoxContainer.new()
	p.add_child(h)
	h.add_child(UIKit.tex_rect(String(cfg["texture"]), 70))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(UIKit.label(String(cfg["name"]), 20, Color.WHITE, 5))
	var lv: int = Workshop.level_of(kind)
	v.add_child(UIKit.label("Lv. %d / %d" % [lv, Workshop.max_level()], 17, Color("#ffe27a"), 4))
	var locked: bool = int(cfg["unlock_level"]) > 1 and not Save.is_unlocked(int(cfg["unlock_level"]))
	var cost: int = Workshop.next_cost(kind)
	var b: Button
	if locked:
		b = UIKit.button("Lv. %d" % int(cfg["unlock_level"]), "dark", 18, Vector2(110, 46))
		b.disabled = true
	elif cost < 0:
		b = UIKit.button("MAX", "dark", 18, Vector2(110, 46))
		b.disabled = true
	else:
		b = UIKit.button(" " + CurrencyBar._fmt(cost), "green", 18, Vector2(110, 46))
		b.icon = Art.tex("coin")
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 22)
		b.pressed.connect(func() -> void:
			if Workshop.buy(kind):
				Sound.play("anvil")
				UIFx.celebrate(p, "LEVEL UP!")
				_fill_heroes.call_deferred()
			else:
				UIFx.shake(b)
				bar.deny("coins"))
		UIFx.press_juice(b)
	v.add_child(b)
	return p
