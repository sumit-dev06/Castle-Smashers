class_name ShopScreen
extends MetaFrame
## Shop: Crates (Hellfire, Coin, Gem), Remove Ads, Gold (gems -> coins), Skins, Siege Engines.
## Real-money items go through Store; prices are the localized strings from Google Play and a
## button stays disabled until Play has priced it. Crate contents are fixed (no random rewards).
## Every state is spelled out on the button or the status line: Connecting, Processing, Pending,
## Owned, Unavailable. In-game items (gold, skins) go through Save.spend.

const TABS: Array = [["crates", "Crates", "chest_open"], ["noads", "Remove Ads", "icon_noads"], ["gold", "Gold", "coin"],
		["skins", "Skins", "icon_skins"], ["addons", "Hero Addons", "addon_crown"], ["weapons", "Siege Engines", "icon_weapon_trebuchet"]]
const CRATE_COLORS: Dictionary = {"hellfire_crate": Color("#7a1a0a"), "coin_crate": Color("#6a4a0a"), "gem_crate": Color("#4a1a7a")}

var tab: String = "crates"
var _pane: ScrollContainer
var _status: Label
var _cards: Dictionary = {}


## Shop tab for a wallet "+" button.
static func tab_for(currency: String) -> String:
	return {"coins": "crates", "gems": "crates"}.get(currency, "crates")


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
	Store.status_changed.connect(func(_s: int) -> void: _show())
	Store.products_changed.connect(_show)
	Store.entitlements_changed.connect(_show)
	Store.granted.connect(_on_granted)
	Store.purchase_pending.connect(func(_id: String) -> void:
		_say(String(Data.balance["shop"]["pending_note"]), Color("#ffe27a"))
		_show())
	Store.purchase_cancelled.connect(func(_id: String) -> void:
		_say("Purchase cancelled. You were not charged.", Color.WHITE)
		_show())
	Store.purchase_failed.connect(func(_id: String, msg: String) -> void:
		_say(msg, Color("#ff9a8a"))
		_show())
	Store.restore_finished.connect(func(ok: bool) -> void:
		_say("Purchases restored." if ok else "Could not reach Google Play. Try again later.", Color("#9aff8a") if ok else Color("#ff9a8a"))
		_show())


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
	_pane.offset_bottom = -64
	body.add_child(_pane)
	DragScroll.attach(_pane)
	_status = UIKit.label("", 20, Color.WHITE, 6, false)
	UIKit.place(_status, Vector2(0, 1), Vector2(282, -58), Vector2(0, 44))
	_status.anchor_right = 1.0
	_status.offset_right = -20
	body.add_child(_status)
	_show()


func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _store_line() -> String:
	match Store.status:
		Store.Status.CONNECTING, Store.Status.OFF:
			return "Connecting to Google Play…"
		Store.Status.UNAVAILABLE:
			return "Google Play purchases are not available on this device."
	return ""


func _show() -> void:
	if _pane == null:
		return
	for c: Node in _pane.get_children():
		c.queue_free()
	_cards.clear()
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	_pane.add_child(v)
	if Store.status != Store.Status.READY:
		_say(_store_line(), Color("#ffe27a"))
	elif _status.text == "Connecting to Google Play…":
		_say("", Color.WHITE)
	var shop: Dictionary = Data.balance["shop"]
	match tab:
		"crates":
			var row: HBoxContainer = _row(v)
			for id: String in ["hellfire_crate", "coin_crate", "gem_crate"]:
				row.add_child(_crate_card(id))
			v.add_child(_footer())
		"noads":
			var r2: HBoxContainer = _row(v)
			r2.add_child(_noads_card())
			v.add_child(_footer())
		"gold":
			var r3: HBoxContainer = _row(v)
			for e: Dictionary in shop["gold"]:
				r3.add_child(_gold_card(e))
		"skins":
			var skins: Dictionary = Data.balance["cosmetics"]["skins"]
			var r5: HBoxContainer = _row(v)
			var n: int = 0
			for sid: String in skins:
				if n == 4:
					r5 = _row(v)
				r5.add_child(_skin_card(sid, skins[sid]))
				n += 1
		"addons":
			var note: Label = UIKit.label("Dress up Rocky: one hat and one pair of glasses at a time. Looks only.", 20, Color("#f4e2b8"), 5, false)
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(note)
			var r6: HBoxContainer = _row(v)
			var n6: int = 0
			for aid: String in HeroAddons.ids():
				if n6 == 4:
					r6 = _row(v)
				r6.add_child(_addon_card(aid, HeroAddons.catalog()[aid]))
				n6 += 1
			v.add_child(_footer())
		"weapons":
			var r4: HBoxContainer = _row(v)
			for w: Variant in Progression.weapons():
				r4.add_child(_weapon_card(String(w)))


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


## Price button for a Play product, with its state spelled out.
func _iap_button(id: String) -> Button:
	var text: String = Store.price_text(id)
	var enabled: bool = false
	if Store.status != Store.Status.READY:
		text = "Unavailable" if Store.status == Store.Status.UNAVAILABLE else "Connecting…"
	elif not PurchaseProcessor.is_consumable(id) and Store.owns(id):
		text = "OWNED"
	elif Store.busy_product == id:
		text = "Processing…"
	elif text.is_empty():
		text = "Loading…"
	else:
		enabled = Store.busy_product.is_empty()
	var b: Button = UIKit.button(text, "orange" if enabled else "dark", 26, Vector2(220, 64))
	b.disabled = not enabled
	b.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		if Store.buy(id):
			_say("Opening Google Play…", Color.WHITE)
			_show())
	UIFx.press_juice(b)
	return b


func _crate_card(id: String) -> Control:
	var c: Dictionary = Store.product(id)
	# Three cards share the pane; on 16:9 and tablets (1280 wide) they shrink to fit.
	var card_w: float = minf(330.0, floorf((get_viewport().get_visible_rect().size.x - 302.0 - 40.0) / 3.0))
	var parts: Array = _card(CRATE_COLORS.get(id, Color("#3a2414")), card_w, 430)
	var v: VBoxContainer = parts[1]
	if id == "hellfire_crate":
		var tag: Label = UIKit.label("PURCHASE ONLY", 18, Color("#ffd23a"), 6)
		v.add_child(tag)
	v.add_child(UIKit.label(String(c["name"]), 32, Color("#ffd23a"), 8))
	v.add_child(UIKit.tex_rect(String(c["icon"]), 150 if id == "hellfire_crate" else 110))
	var gives: Dictionary = c["gives"]
	var what: String = ""
	for k: String in gives:
		what = "%s %s" % [CurrencyBar._fmt(int(gives[k])), {"coins": "Coins", "gems": "Gems", "hellfire": "Hellfire Strikes"}.get(k, k)]
	v.add_child(UIKit.label(what, 26, Color.WHITE, 7))
	var d: Label = UIKit.label(String(c["desc"]), 17, Color("#f4e2b8"), 4, false)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = card_w - 40.0
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	if id == "hellfire_crate":
		v.add_child(UIKit.label("You have: %d" % Save.amount("hellfire"), 20, Color("#ffb070"), 5))
	v.add_child(_iap_button(id))
	_cards[id] = parts[0]
	return parts[0]


func _noads_card() -> Control:
	var c: Dictionary = Store.product("remove_ads")
	var parts: Array = _card(Color("#5a2a14"), 460, 400)
	var v: VBoxContainer = parts[1]
	v.add_child(UIKit.label("Remove Ads", 36, Color("#ffd23a"), 8))
	v.add_child(UIKit.tex_rect("icon_noads", 90))
	for perk: Variant in c["perks"]:
		var h: HBoxContainer = HBoxContainer.new()
		h.add_child(UIKit.tex_rect("icon_check", 24))
		h.add_child(UIKit.label(String(perk), 20, Color.WHITE, 5, false))
		v.add_child(h)
	v.add_child(UIKit.label("One-time purchase", 18, Color("#f4e2b8"), 4, false))
	v.add_child(_iap_button("remove_ads"))
	_cards["remove_ads"] = parts[0]
	return parts[0]


func _footer() -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var restore: Button = UIKit.button("Restore Purchases", "blue", 22, Vector2(260, 58))
	restore.disabled = Store.status != Store.Status.READY
	restore.pressed.connect(func() -> void:
		_say("Checking your purchases with Google Play…", Color.WHITE)
		Store.restore())
	UIFx.press_juice(restore)
	h.add_child(restore)
	var note: Label = UIKit.label("Every crate has fixed contents: you always get exactly what is shown.\nPrices are set by Google Play in your local currency.",
			16, Color("#f4e2b8"), 4, false)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 700
	h.add_child(note)
	return h


func _gem_button(cost: Dictionary) -> Button:
	var k: String = "gems" if cost.has("gems") else "coins"
	var b: Button = UIKit.button(" " + CurrencyBar._fmt(int(cost[k])), "green", 26, Vector2(180, 60))
	b.icon = Art.tex(UIKit.CURRENCY_ICON[k])
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 30)
	UIFx.press_juice(b)
	return b


func _gold_card(e: Dictionary) -> Control:
	var parts: Array = _card(Color("#3a2414"), 300, 290)
	var v: VBoxContainer = parts[1]
	if e.has("extra"):
		v.add_child(UIKit.label(String(e["extra"]), 22, Color("#7ae05a"), 7))
	v.add_child(UIKit.tex_rect("coin", 96))
	v.add_child(UIKit.label(CurrencyBar._fmt(int(e["gives"]["coins"])), 34, Color.WHITE, 8))
	var b: Button = _gem_button(e["cost"])
	b.pressed.connect(func() -> void:
		if Save.spend(e["cost"]):
			Save.add("coins", int(e["gives"]["coins"]), true, false)
			_celebrate_card(parts[0], e["gives"])
		else:
			_deny(b, e["cost"]))
	v.add_child(b)
	return parts[0]


func _weapon_card(id: String) -> Control:
	var c: Dictionary = Progression.weapon_cfg(id)
	var parts: Array = _card(Color("#3a2414"), 300, 300)
	var v: VBoxContainer = parts[1]
	v.add_child(UIKit.label(String(c["short_name"]), 30, Color("#ffd23a"), 8))
	v.add_child(UIKit.tex_rect("icon_weapon_" + id, 100))
	var d: Label = UIKit.label(String(c["role"]), 18, Color.WHITE, 5, false)
	v.add_child(d)
	var b: Button = UIKit.button("OPEN WORKSHOP", "green", 22, Vector2(220, 56))
	b.pressed.connect(func() -> void: Game.goto_meta("upgrades"))
	v.add_child(b)
	return parts[0]


func _skin_card(id: String, c: Dictionary) -> Control:
	var rar: String = String(c["rarity"])
	var col: Color = {"common": Color("#4a4a4a"), "rare": Color("#1e4a8a"), "epic": Color("#5a1e8a"), "legendary": Color("#8a5a10")}[rar]
	var parts: Array = _card(col, 230, 280)
	var v: VBoxContainer = parts[1]
	var art: String = "skin_%s_base" % id
	v.add_child(UIKit.tex_rect(art if ResourceLoader.exists("res://assets/art/svg/%s.svg" % art) else "icon_weapon_catapult", 84))
	v.add_child(UIKit.label(String(c["name"]), 22, Color.WHITE, 7))
	v.add_child(UIKit.label(rar.capitalize(), 18, Color("#ffe27a"), 5))
	var b: Button
	if Progression.owns("skins", id):
		b = UIKit.button("OWNED", "dark", 22, Vector2(170, 54))
		b.disabled = true
	elif (c["price"] as Dictionary).is_empty():
		b = UIKit.button("Chest reward" if String(c.get("source", "")).begins_with("realm") else "Achievement", "dark", 18, Vector2(170, 54))
		b.disabled = true
	else:
		b = _gem_button(c["price"])
		b.pressed.connect(func() -> void:
			if Progression.buy_cosmetic("skins", id):
				_celebrate_card(parts[0], {})
				Progression.equip("skins", id)
				_show.call_deferred()
			else:
				_deny(b, c["price"]))
	v.add_child(b)
	return parts[0]


## Rocky addon: Rocky wearing it, then the Play price until owned, then WEAR / TAKE OFF.
func _addon_card(id: String, c: Dictionary) -> Control:
	var parts: Array = _card(Color("#3a2414"), 240, 360)
	var v: VBoxContainer = parts[1]
	var pv: Control = HeroAddons.preview("stone", [id], 140)
	pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pv)
	v.add_child(UIKit.label(String(c["name"]), 24, Color("#ffd23a"), 7))
	var d: Label = UIKit.label(String(c["desc"]), 16, Color("#f4e2b8"), 4, false)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 200
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var product: String = String(c["product"])
	if not HeroAddons.owns(id):
		v.add_child(_iap_button(product))
		_cards[product] = parts[0]
	else:
		var on: bool = HeroAddons.is_on(id)
		var b: Button = UIKit.button("TAKE OFF" if on else "WEAR", "orange" if on else "green", 24, Vector2(190, 60))
		b.pressed.connect(func() -> void:
			Sound.play("upgrade")
			HeroAddons.toggle(id)
			_show.call_deferred())
		UIFx.press_juice(b)
		v.add_child(b)
	return parts[0]


func _on_granted(product_id: String, gives: Dictionary) -> void:
	var name: String = String(Store.product(product_id).get("name", "Purchase"))
	if product_id.begins_with("addon_") and not HeroAddons.is_on(product_id.trim_prefix("addon_")):
		HeroAddons.toggle(product_id.trim_prefix("addon_"))
	_say("%s delivered. Thank you!" % name, Color("#9aff8a"))
	var card: Control = _cards.get(product_id)
	if card and is_instance_valid(card):
		var shown: Dictionary = {}
		for k: String in gives:
			if Save.WALLET.has(k):
				shown[k] = gives[k]
		_celebrate_card(card, shown)
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
