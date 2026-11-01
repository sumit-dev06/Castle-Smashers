class_name PromoPopup
extends Control
## "Featured" showcase on the home screen (docs/MONETIZATION.md "Feature showcase"): a big card,
## about two thirds of the screen, that cycles through what the game offers (Remove Ads, Hero
## Addons, skins, crates, Workshop upgrades, siege engines, Special Missions). One tap opens that
## screen; Later or the X closes it. When and how often: data/balance.json -> promo.

var _cards: Array[Dictionary] = []
var _i: int = 0
var _stage: Control
var _dots: HBoxContainer
var _auto: float = 0.0
var _drag_x: float = -1.0


static func cfg() -> Dictionary:
	return Data.balance.get("promo", {})


## Cards that make sense right now: owned things and locked screens are left out.
static func cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var unlocked: int = int(Save.data.get("unlocked", 1))
	for c: Variant in cfg().get("cards", []):
		var d: Dictionary = c
		if unlocked < int(d.get("min_level", 1)):
			continue
		match String(d.get("id", "")):
			"noads":
				if Ads.ads_removed():
					continue
			"addons":
				if HeroAddons.ids().all(func(a: String) -> bool: return HeroAddons.owns(a)):
					continue
		out.append(d)
	return out


## Home screen calls this on every visit. First visit of a session shows it after a short look at
## home; later visits show it every few visits, with a gap and a daily cap. Returns true if shown.
static func maybe_show(host: Node, first_visit: bool) -> bool:
	var c: Dictionary = cfg()
	if c.is_empty() or "--no-popups" in OS.get_cmdline_user_args():
		return false
	if int(Save.data.get("unlocked", 1)) < int(c.get("min_level", 3)) or Notifications.will_ask():
		return false
	var st: Dictionary = Save.data.get("promo", {}) if Save.data.get("promo", {}) is Dictionary else {}
	var now: int = int(Time.get_unix_time_from_system())
	var today: String = Save.today()
	var shown_today: int = int(st.get("count", 0)) if String(st.get("day", "")) == today else 0
	var visits: int = int(st.get("visits", 0)) + 1
	st["visits"] = visits
	Save.data["promo"] = st
	var due: bool = first_visit or visits % maxi(1, int(c.get("every_n_home_visits", 3))) == 0
	if not due or shown_today >= int(c.get("max_per_day", 4)) \
			or now - int(st.get("last", 0)) < int(c.get("min_gap_s", 180)) or cards().is_empty():
		return false
	st["day"] = today
	st["count"] = shown_today + 1
	st["last"] = now
	Save.write()
	Game.promo_seen = true
	host.get_tree().create_timer(float(c.get("delay_s", 1.2))).timeout.connect(func() -> void:
		if is_instance_valid(host) and host.is_inside_tree() and Game.current == host:
			open())
	return true


static func open() -> PromoPopup:
	for n: Node in UIFx.overlay().get_children():
		if n is PromoPopup and not n.is_queued_for_deletion():
			return n
	var p: PromoPopup = PromoPopup.new()
	UIFx.overlay().add_child(p)
	return p


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cards = cards()
	if _cards.is_empty():
		queue_free()
		return
	# Start where the last showcase left off, so every visit leads with a different feature.
	var st: Dictionary = Save.data.get("promo", {})
	_i = int(st.get("next", 0)) % _cards.size()
	st["next"] = _i + 1
	var shade: ColorRect = UIKit.dim()
	shade.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shade.size = size
	shade.color = Color(0.04, 0.03, 0.1, 0.62)
	add_child(shade)
	var view: Vector2 = get_viewport_rect().size
	var w: float = view.x * float(cfg().get("width_frac", 0.78))
	var h: float = view.y * float(cfg().get("height_frac", 0.82))
	var p: PanelContainer = UIKit.panel()
	p.position = (view - Vector2(w, h)) * 0.5
	p.size = Vector2(w, h)
	add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var tag: Label = UIKit.label(String(cfg().get("header", "DISCOVER MORE")), 24, Color("#b8733a"), 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(w - 56.0, h - 56.0 - 44.0 - 30.0)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	_stage.gui_input.connect(_on_swipe)
	v.add_child(_stage)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_dots)
	var x: Button = UIKit.icon_button("icon_close", "red", 64)
	x.position = Vector2(p.position.x + w - 46.0, p.position.y - 18.0)
	x.pressed.connect(_close)
	add_child(x)
	for dir: int in [-1, 1]:
		var arrow: Button = UIKit.button("‹" if dir < 0 else "›", "orange", 40, Vector2(60, 76))
		arrow.position = Vector2(p.position.x - 30.0 if dir < 0 else p.position.x + w - 30.0, p.position.y + h * 0.5 - 38.0)
		arrow.pressed.connect(func() -> void: _go(dir))
		add_child(arrow)
	UIFx.pop_in(p)
	Sound.play("popup_open")
	_show(0)


func _process(delta: float) -> void:
	_auto += delta
	if _auto >= float(cfg().get("auto_next_s", 5.0)) and _cards.size() > 1:
		_go(1)


func _go(dir: int) -> void:
	_i = posmod(_i + dir, _cards.size())
	_show(dir)


func _show(dir: int) -> void:
	_auto = 0.0
	var old: Array[Node] = _stage.get_children()
	var card: Control = _card(_cards[_i])
	_stage.add_child(card)
	var wdt: float = _stage.custom_minimum_size.x
	if dir != 0:
		card.position.x = wdt * dir
		var tw: Tween = card.create_tween().set_parallel(true)
		tw.tween_property(card, "position:x", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for o: Node in old:
			tw.tween_property(o, "position:x", -wdt * dir, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func() -> void:
			for o: Node in old:
				o.queue_free())
	else:
		for o: Node in old:
			o.queue_free()
	for d: Node in _dots.get_children():
		d.queue_free()
	for k: int in _cards.size():
		var dot: Panel = Panel.new()
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("#ffb52e") if k == _i else Color("#d8c39c")
		sb.set_corner_radius_all(8)
		dot.add_theme_stylebox_override("panel", sb)
		dot.custom_minimum_size = Vector2(28 if k == _i else 14, 14)
		_dots.add_child(dot)
	Analytics.event("promo_shown", {"card": String(_cards[_i].get("id", ""))})


## One feature: big art with a light burst on the left, title, selling points and the button.
func _card(d: Dictionary) -> Control:
	var c: Control = Control.new()
	c.size = _stage.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: HBoxContainer = HBoxContainer.new()
	h.size = c.size
	h.add_theme_constant_override("separation", 24)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	var art_box: Control = Control.new()
	art_box.custom_minimum_size = Vector2(340, 300)
	art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(art_box)
	var glow: Panel = Panel.new()
	var gsb: StyleBoxFlat = StyleBoxFlat.new()
	gsb.bg_color = Color(d.get("color", "#ffcf3a"))
	gsb.set_corner_radius_all(150)
	glow.add_theme_stylebox_override("panel", gsb)
	glow.size = Vector2(290, 290)
	glow.position = Vector2(25, 5)
	glow.modulate.a = float(d.get("glow_alpha", 0.45))
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_box.add_child(glow)
	var arts: Array = d.get("art", [])
	art_box.custom_minimum_size = Vector2(340, c.size.y)
	glow.position = Vector2(25, c.size.y * 0.5 - 145.0)
	# Main item big in the glow; up to two extras smaller at its upper and lower right.
	var spots: Array[Vector2] = [Vector2(170, c.size.y * 0.5), Vector2(285, c.size.y * 0.5 + 95.0), Vector2(280, c.size.y * 0.5 - 100.0)]
	for k: int in mini(arts.size(), 3):
		var a: TextureRect = UIKit.tex_rect(String(arts[k]), 210.0 if k == 0 else 92.0)
		var cap: float = 260.0 if k == 0 else 120.0
		if a.custom_minimum_size.x > cap:
			a.custom_minimum_size = a.custom_minimum_size * (cap / a.custom_minimum_size.x)
		a.size = a.custom_minimum_size
		a.position = spots[k] - a.size * 0.5
		a.pivot_offset = a.size * 0.5
		art_box.add_child(a)
		a.scale = Vector2.ONE * 0.6
		a.create_tween().tween_property(a, "scale", Vector2.ONE, 0.45).set_delay(k * 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	if d.has("badge"):
		var badge: PanelContainer = PanelContainer.new()
		var bsb: StyleBoxFlat = StyleBoxFlat.new()
		bsb.bg_color = Color("#e8432e")
		bsb.set_corner_radius_all(12)
		bsb.content_margin_left = 14
		bsb.content_margin_right = 14
		badge.add_theme_stylebox_override("panel", bsb)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		badge.add_child(UIKit.label(String(d["badge"]), 18, Color.WHITE, 4))
		v.add_child(badge)
	var title: Label = UIKit.label(String(d.get("title", "")), 44, Color("#4a2408"), 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(title)
	for line: Variant in d.get("points", []):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UIKit.tex_rect("icon_check", 30))
		var t: Label = UIKit.body(String(line), 23)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		v.add_child(row)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	var go: Button = UIKit.button(String(d.get("cta", "SHOW ME")), "green", 30, Vector2(240, 76))
	go.pressed.connect(func() -> void: _open_target(d))
	UIFx.press_juice(go)
	btns.add_child(go)
	var later: Button = UIKit.button("Later", "blue", 24, Vector2(150, 64))
	later.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	later.pressed.connect(_close)
	btns.add_child(later)
	v.add_child(btns)
	return c


func _open_target(d: Dictionary) -> void:
	Sound.play("ui_tap")
	Analytics.event("promo_tap", {"card": String(d.get("id", ""))})
	var target: String = String(d.get("target", "shop"))
	var tab: String = String(d.get("tab", ""))
	queue_free()
	match target:
		"challenges":
			Game.goto_challenges()
		"map":
			Game.goto_map()
		_:
			Game.goto_meta(target, {"tab": tab} if not tab.is_empty() else {})


func _close() -> void:
	Sound.play("ui_tap")
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _on_swipe(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		var pressed: bool = e.pressed
		var x: float = (e as InputEventScreenTouch).position.x if e is InputEventScreenTouch else (e as InputEventMouseButton).position.x
		if pressed:
			_drag_x = x
		elif _drag_x >= 0.0:
			var dx: float = x - _drag_x
			_drag_x = -1.0
			if absf(dx) > 60.0:
				_go(-1 if dx > 0.0 else 1)
