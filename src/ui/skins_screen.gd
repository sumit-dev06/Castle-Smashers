class_name SkinsScreen
extends MetaFrame
## Skins / Armory (owner reference docs/reference/skins_reference.png): rail (Catapult skins, Trails),
## the selected skin large on a stone plinth with arrows, a framed card with name, rarity pill,
## description, what it changes and EQUIP / price, and a strip of every item with its rarity pill
## (equipped one gold-framed with a tick). Cosmetic only: tints, trail colour, never stats.

const RARITY: Dictionary = {"common": Color("#7a7a80"), "rare": Color("#2a6ad8"), "epic": Color("#8a3ad8"), "legendary": Color("#d89a1a")}

var kind: String = "skins"
var _sel: String = ""
var _preview: TextureRect
var _info: VBoxContainer
var _strip: HBoxContainer
var _cat: Catapult


func _title() -> String:
	return "Skins"


func _icon() -> String:
	return "icon_skins"


func _rail_items() -> Array:
	return [["skins", "Catapult", "icon_weapon_catapult"], ["trails", "Trails", "icon_trail"]]


func _bg_realm() -> int:
	return 1


func _ready() -> void:
	rail_key = kind
	_sel = Progression.equipped(kind)
	rail_bottom = -196.0
	super._ready()


func _rail_pressed(key: String) -> void:
	kind = key
	rail_key = key
	_sel = Progression.equipped(kind)
	_build_rail()
	_refresh()


func _items() -> Dictionary:
	return Data.balance["cosmetics"][kind]


func _build() -> void:
	var plinth: Panel = Panel.new()
	plinth.add_theme_stylebox_override("panel", card_box(Color("#9a9288"), Color("#5a544c")))
	UIKit.place(plinth, Vector2.ZERO, Vector2(330, 470), Vector2(480, 46))
	plinth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(plinth)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UIKit.place(_preview, Vector2.ZERO, Vector2(350, 120), Vector2(440, 370))
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_preview)
	for side: int in [-1, 1]:
		var arrow: Button = UIKit.button("<" if side < 0 else ">", "orange", 40, Vector2(64, 74))
		UIKit.place(arrow, Vector2.ZERO, Vector2(282 if side < 0 else 820, 290), Vector2(64, 74))
		arrow.pressed.connect(_cycle.bind(side))
		UIFx.press_juice(arrow)
		body.add_child(arrow)
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_box(Color(0.18, 0.1, 0.05, 0.92), Color("#d8a040")))
	UIKit.place(card, Vector2(1, 0), Vector2(-430, 100), Vector2(410, 420))
	body.add_child(card)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 10)
	card.add_child(_info)
	UIFx.slide_in(card, Vector2(1, 0), 0.05)
	var sp: PanelContainer = _dark_panel()
	UIKit.place(sp, Vector2(0, 1), Vector2(14, -182), Vector2(0, 170))
	sp.anchor_right = 1.0
	sp.offset_right = -14
	body.add_child(sp)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sp.add_child(scroll)
	DragScroll.attach(scroll)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 10)
	scroll.add_child(_strip)
	UIFx.slide_in(sp, Vector2(0, 1), 0.1)
	_refresh()


func _cycle(side: int) -> void:
	var ids: Array = _items().keys()
	var i: int = (ids.find(_sel) + side + ids.size()) % ids.size()
	_sel = String(ids[i])
	Sound.play("whoosh", 0.5)
	_refresh()


func _tint(c: Dictionary) -> Color:
	return Progression._col(c["tint_base"]) if kind == "skins" else Progression._col(c["color"])


func _refresh() -> void:
	var c: Dictionary = _items()[_sel]
	if kind == "skins":
		_preview.texture = null
		if _cat == null:
			_cat = preview_catapult(Vector2(610, 456), 1.1)
		_cat.get_parent().visible = true
		_cat.set_appearance(Progression.weapon(), _sel)
	else:
		if _cat:
			_cat.get_parent().visible = false
		_preview.texture = Art.tex("icon_trail")
		_preview.modulate = _tint(c)
	_preview.pivot_offset = _preview.size * 0.5
	_preview.scale = Vector2.ONE * 0.7
	_preview.create_tween().tween_property(_preview, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for n: Node in _info.get_children():
		n.queue_free()
	_info.add_child(UIKit.label(String(c["name"]) + (" Catapult" if kind == "skins" else " Trail"), 34, Color("#ffd23a"), 9))
	var rar: String = String(c.get("rarity", "common"))
	_info.add_child(_pill(rar.capitalize(), RARITY.get(rar, RARITY["common"])))
	var perks: Array = (c.get("features", ["Distinct silhouette"]) as Array).duplicate() if kind == "skins" else ["Coloured flight trail"]
	if kind == "skins":
		perks.push_front(String(c.get("silhouette", "Custom siege rig")))
	if c.has("trail"):
		perks.append("%s flight trail" % String(Data.balance["cosmetics"]["trails"][String(c["trail"])]["name"]))
	perks.append("Looks only, never stronger")
	for p: String in perks:
		var h: HBoxContainer = HBoxContainer.new()
		h.add_child(UIKit.tex_rect("icon_check", 26))
		h.add_child(UIKit.label(p, 20, Color.WHITE, 5, false))
		_info.add_child(h)
	var owned: bool = Progression.owns(kind, _sel)
	var equipped: bool = Progression.equipped(kind) == _sel
	var b: Button
	if equipped:
		b = UIKit.button("Equipped", "dark", 34, Vector2(320, 84))
		UIKit.locked(b, "Already equipped.")
	elif owned:
		b = UIKit.button("Equip", "green", 40, Vector2(320, 84))
		b.pressed.connect(func() -> void:
			Progression.equip(kind, _sel)
			Sound.play("upgrade")
			UIFx.celebrate(_preview, "EQUIPPED!")
			_refresh())
		UIFx.breathe(b)
	elif (c["price"] as Dictionary).is_empty():
		var src: String = String(c.get("source", ""))
		b = UIKit.button("From a realm chest" if src.begins_with("realm") else "Achievement reward", "dark", 22, Vector2(320, 84))
		UIKit.locked(b, "Found in a realm chest on the map." if src.begins_with("realm") else "Unlocked by an achievement.")
	else:
		var price: Dictionary = c["price"]
		var k: String = "gems" if price.has("gems") else "coins"
		b = UIKit.button(" " + CurrencyBar._fmt(int(price[k])), "orange", 36, Vector2(320, 84))
		b.icon = Art.tex(UIKit.CURRENCY_ICON[k])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 40)
		b.pressed.connect(func() -> void:
			if Progression.buy_cosmetic(kind, _sel):
				Progression.equip(kind, _sel)
				UIFx.celebrate(_preview)
				_refresh()
			else:
				UIFx.shake(b)
				bar.deny(k))
	UIFx.press_juice(b)
	_info.add_child(b)
	for n2: Node in _strip.get_children():
		n2.queue_free()
	for id: String in _items():
		_strip.add_child(_tile(id, _items()[id]))


func _pill(text: String, col: Color) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(col, col.lightened(0.3)))
	p.add_child(UIKit.label(text, 20, Color.WHITE, 5))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p


func _tile(id: String, c: Dictionary) -> Control:
	var sel: bool = id == _sel
	var equipped: bool = Progression.equipped(kind) == id
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(150, 148)
	b.focus_mode = Control.FOCUS_NONE
	var box: StyleBoxFlat = card_box(Color("#3a2414"), Color("#ffd23a") if sel else Color("#6a4424"))
	if sel:
		box.set_border_width_all(6)
	for st: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, box)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var art_name: String = "icon_trail"
	if kind == "skins":
		var candidate: String = "skin_%s_base" % id
		art_name = candidate if ResourceLoader.exists("res://assets/art/svg/%s.svg" % candidate) else "icon_weapon_catapult"
	var icon: TextureRect = UIKit.tex_rect(art_name, 64)
	icon.modulate = _tint(c) if kind != "skins" or art_name == "icon_weapon_catapult" else Color.WHITE
	if not Progression.owns(kind, id):
		icon.modulate = icon.modulate.darkened(0.45)
	v.add_child(icon)
	v.add_child(UIKit.label(String(c["name"]), 20, Color.WHITE, 5))
	var rar: String = String(c.get("rarity", "common"))
	v.add_child(_pill(rar.capitalize(), RARITY.get(rar, RARITY["common"])))
	if equipped:
		var tick: TextureRect = UIKit.tex_rect("icon_check", 34)
		tick.position = Vector2(4, 2)
		b.add_child(tick)
	b.pressed.connect(func() -> void:
		_sel = id
		Sound.play("ui_tap")
		_refresh())
	return b
