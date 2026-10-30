class_name ShopScreen
extends MetaFrame
## Shop (owner example docs/reference/shop_reference.png): category rail, a wide Starter Pack banner
## with a sale ribbon, pack cards, Remove Ads, and rows of gem / gold / resource packs, siege weapons
## and skins. Real-money items go through Store (prices from Google Play); in-game items through
## Save.spend. Every purchase plays the UIFx celebration and flies the contents into the bar.

const TABS: Array = [["offers", "Special Offers", "icon_crown"], ["gems", "Gems", "gem"], ["gold", "Gold", "coin"],
		["weapons", "Siege Weapons", "icon_weapon_trebuchet"], ["skins", "Skins", "icon_skins"],
		["noads", "Remove Ads", "icon_noads"], ["resources", "Resources", "blueprint"]]

var tab: String = "offers"
var _pane: ScrollContainer
var _pending: Control


## Shop tab for a wallet "+" button: coins → Gold, gems → Gems, blueprints → Resources.
static func tab_for(currency: String) -> String:
	return {"coins": "gold", "gems": "gems", "blueprints": "resources"}.get(currency, "offers")


func _title() -> String:
	return "Shop"


func _icon() -> String:
	return "icon_shop"


func _rail_items() -> Array:
	return TABS


func _bg_realm() -> int:
	return 2


func _ready() -> void:
	rail_key = tab
	super._ready()
	Store.granted.connect(_on_granted)
	Store.purchase_failed.connect(func(_id: String) -> void:
		if _pending:
			UIFx.shake(_pending)
		_pending = null)


func _rail_pressed(key: String) -> void:
	tab = key
	rail_key = key
	_build_rail()
	_show()


func _build() -> void:
	_pane = ScrollContainer.new()
	_pane.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.place(_pane, Vector2.ZERO, Vector2(282, 100), Vector2(0, 0))
	_pane.anchor_right = 1.0
	_pane.anchor_bottom = 1.0
	_pane.offset_right = -20
	_pane.offset_bottom = -16
	body.add_child(_pane)
	_show()


func _show() -> void:
	for c: Node in _pane.get_children():
		c.queue_free()
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	_pane.add_child(v)
	var shop: Dictionary = Data.balance["shop"]
	match tab:
		"offers":
			v.add_child(_starter_banner(shop["offers"][0]))
			var row: HBoxContainer = _row(v)
			row.add_child(_pack_card(shop["offers"][1], Color("#5a1e8a")))
			row.add_child(_pack_card(shop["offers"][2], Color("#1e4a8a")))
			row.add_child(_noads_card(shop["remove_ads"]))
		"gems":
			var r1: HBoxContainer = _row(v)
			for e: Dictionary in shop["gems"]:
				r1.add_child(_item_card(e, "gems"))
		"gold":
			var r2: HBoxContainer = _row(v)
			for e2: Dictionary in shop["gold"]:
				r2.add_child(_item_card(e2, "coins"))
		"resources":
			var r3: HBoxContainer = _row(v)
			for e3: Dictionary in shop["resources"]:
				r3.add_child(_item_card(e3, "blueprints"))
		"weapons":
			var r4: HBoxContainer = _row(v)
			for w: Variant in Progression.weapons():
				r4.add_child(_weapon_card(String(w)))
		"skins":
			var skins: Dictionary = Data.balance["cosmetics"]["skins"]
			var r5: HBoxContainer = _row(v)
			var n: int = 0
			for id: String in skins:
				if n == 4:
					r5 = _row(v)
				r5.add_child(_skin_card(id, skins[id]))
				n += 1
		"noads":
			var r6: HBoxContainer = _row(v)
			r6.add_child(_noads_card(shop["remove_ads"]))
	var k: int = 0
	for row2: Node in v.get_children():
		for card: Node in row2.get_children():
			if card is Control:
				UIFx.pop_in(card as Control, 0.04 * k)
				k += 1


func _row(v: VBoxContainer) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	return h


func _card(color: Color, w: float, h: float) -> Array:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(color, Color("#e8c070")))
	p.custom_minimum_size = Vector2(w, h)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return [p, v]


func _price_button(e: Dictionary) -> Button:
	var b: Button
	if e.has("cost"):
		var cost: Dictionary = e["cost"]
		var k: String = "gems" if cost.has("gems") else "coins"
		b = UIKit.button(" " + CurrencyBar._fmt(int(cost[k])), "green", 26, Vector2(180, 60))
		b.icon = Art.tex(UIKit.CURRENCY_ICON[k])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 30)
	else:
		b = UIKit.button(String(e.get("price_label", "BUY")), "orange", 28, Vector2(180, 60))
	UIFx.press_juice(b)
	return b


func _starter_banner(e: Dictionary) -> Control:
	var parts: Array = _card(Color("#2e5a1e"), 980, 200)
	var p: PanelContainer = parts[0]
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	(parts[1] as VBoxContainer).add_child(h)
	h.add_child(UIKit.tex_rect("chest_open", 150))
	var mid: VBoxContainer = VBoxContainer.new()
	mid.add_child(UIKit.label(String(e["name"]).to_upper(), 44, Color("#ffd23a"), 10))
	mid.add_child(reward_row(e["gives"], 40))
	mid.add_child(UIKit.label("+ Desert Gold skin · No ads", 22, Color.WHITE, 6, false))
	h.add_child(mid)
	var right: VBoxContainer = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var ribbon: Label = UIKit.label(String(e.get("sale", "")), 30, Color.WHITE, 8)
	ribbon.add_theme_color_override("font_outline_color", Color("#a0141a"))
	right.add_child(ribbon)
	var owned: bool = Store.owns(String(e["iap"]))
	var b: Button = _price_button(e)
	if owned:
		b.text = "OWNED"
		b.disabled = true
	b.pressed.connect(_buy_iap.bind(String(e["iap"]), p))
	right.add_child(b)
	h.add_child(right)
	var tw: Tween = ribbon.create_tween().set_loops()
	tw.tween_property(ribbon, "scale", Vector2.ONE * 1.12, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ribbon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	return p


func _pack_card(e: Dictionary, color: Color) -> Control:
	var parts: Array = _card(color, 310, 300)
	var v: VBoxContainer = parts[1]
	v.add_child(UIKit.label(String(e["name"]), 32, Color("#ffd23a"), 8))
	v.add_child(UIKit.tex_rect("chest_closed", 96))
	v.add_child(reward_row(e["gives"], 30))
	var b: Button = _price_button(e)
	b.pressed.connect(_buy_iap.bind(String(e["iap"]), parts[0]))
	v.add_child(b)
	return parts[0]


func _noads_card(e: Dictionary) -> Control:
	var parts: Array = _card(Color("#5a2a14"), 310, 300)
	var v: VBoxContainer = parts[1]
	v.add_child(UIKit.label("Remove Ads", 32, Color("#ffd23a"), 8))
	v.add_child(UIKit.tex_rect("icon_noads", 70))
	for perk: Variant in e["perks"]:
		var h: HBoxContainer = HBoxContainer.new()
		h.add_child(UIKit.tex_rect("icon_check", 22))
		h.add_child(UIKit.label(String(perk), 18, Color.WHITE, 5, false))
		v.add_child(h)
	var b: Button = _price_button(e)
	if bool(Save.data.get("no_ads", false)):
		b.text = "OWNED"
		b.disabled = true
	b.pressed.connect(_buy_iap.bind(String(e["iap"]), parts[0]))
	v.add_child(b)
	return parts[0]


func _item_card(e: Dictionary, kind: String) -> Control:
	var parts: Array = _card(Color("#3a2414"), 300, 290)
	var v: VBoxContainer = parts[1]
	if e.has("extra"):
		var tag: Label = UIKit.label(String(e["extra"]), 22, Color("#7ae05a"), 7)
		v.add_child(tag)
	v.add_child(UIKit.tex_rect(UIKit.CURRENCY_ICON[kind], 96))
	v.add_child(UIKit.label(CurrencyBar._fmt(int(e["gives"][kind])), 34, Color.WHITE, 8))
	var b: Button = _price_button(e)
	if e.has("cost"):
		b.pressed.connect(_buy_ingame.bind(e, parts[0], b))
	else:
		b.pressed.connect(_buy_iap.bind(String(e["id"]), parts[0]))
	v.add_child(b)
	return parts[0]


func _weapon_card(id: String) -> Control:
	var c: Dictionary = Progression.weapon_cfg(id)
	var parts: Array = _card(Color("#3a2414"), 300, 300)
	var v: VBoxContainer = parts[1]
	v.add_child(UIKit.label(String(c["name"]), 30, Color("#ffd23a"), 8))
	v.add_child(UIKit.tex_rect("icon_weapon_" + id, 100))
	var d: Label = UIKit.label(String(c["desc"]), 18, Color.WHITE, 5, false)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 260
	v.add_child(d)
	var unlocked: bool = Progression.weapon_unlocked(id)
	var b: Button = UIKit.button("UPGRADE" if unlocked else "Level %d" % (int(c["unlock_level"]) - 1), "green" if unlocked else "dark", 24, Vector2(180, 56))
	b.disabled = not unlocked
	b.pressed.connect(func() -> void: Game.goto_meta("upgrades"))
	v.add_child(b)
	return parts[0]


func _skin_card(id: String, c: Dictionary) -> Control:
	var rar: String = String(c["rarity"])
	var col: Color = {"common": Color("#4a4a4a"), "rare": Color("#1e4a8a"), "epic": Color("#5a1e8a"), "legendary": Color("#8a5a10")}[rar]
	var parts: Array = _card(col, 230, 270)
	var v: VBoxContainer = parts[1]
	var icon: TextureRect = UIKit.tex_rect("icon_weapon_catapult", 80)
	icon.modulate = Progression._col(c["tint_base"])
	v.add_child(icon)
	v.add_child(UIKit.label(String(c["name"]), 24, Color.WHITE, 7))
	v.add_child(UIKit.label(rar.capitalize(), 18, Color("#ffe27a"), 5))
	var owned: bool = Progression.owns("skins", id)
	var b: Button
	if owned:
		b = UIKit.button("OWNED", "dark", 22, Vector2(170, 54))
		b.disabled = true
	elif (c["price"] as Dictionary).is_empty():
		b = UIKit.button("Chest" if String(c.get("source", "")).begins_with("realm") else "Achievement", "dark", 20, Vector2(170, 54))
		b.disabled = true
	else:
		b = _price_button({"cost": c["price"]})
		b.pressed.connect(func() -> void:
			if Progression.buy_cosmetic("skins", id):
				_celebrate_card(parts[0], {})
				Progression.equip("skins", id)
				b.text = "OWNED"
				b.disabled = true
			else:
				_deny(b, c["price"]))
	v.add_child(b)
	return parts[0]


func _buy_ingame(e: Dictionary, card: Control, b: Button) -> void:
	var cost: Dictionary = e["cost"]
	if not Save.can_afford(cost):
		_deny(b, cost)
		return
	for k: String in cost:
		Save.add(k, -int(cost[k]), false)
	for k2: String in e["gives"]:
		Save.add(k2, int(e["gives"][k2]), false, false)
	Save.write()
	_celebrate_card(card, e["gives"])


func _buy_iap(product_id: String, card: Control) -> void:
	_pending = card
	Sound.play("ui_tap")
	Store.buy(product_id)


func _on_granted(_product_id: String, gives: Dictionary) -> void:
	if _pending:
		_celebrate_card(_pending, gives)
	_pending = null
	_show.call_deferred()


func _celebrate_card(card: Control, gives: Dictionary) -> void:
	UIFx.celebrate(card)
	var from: Vector2 = card.get_global_rect().get_center()
	var tw: Tween = create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(pay.bind(gives, from))


func _deny(b: Control, cost: Dictionary) -> void:
	UIFx.shake(b)
	Sound.play("deny")
	for k: String in cost:
		if Save.amount(k) < int(cost[k]):
			bar.deny(k)
