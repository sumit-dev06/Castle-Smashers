class_name MetaFrame
extends CanvasLayer
## Shared frame for every meta screen (docs/UI_DESIGN.md "Meta screens"): painted background, square
## wooden back button, plank title sign with the screen icon, the currency bar top right and an
## optional left rail of tabs (selected tab gold). Subclasses fill `body` in _build().

const RAIL_REWARDS: Array = [["spin", "Spin Wheel", "icon_spin"], ["daily", "Daily Rewards", "icon_daily"],
		["shop", "Shop", "icon_shop"], ["challenges", "Challenges", "icon_challenges"], ["achievements", "Achievements", "icon_achievements"]]

var root: Control
var body: Control
var bar: CurrencyBar
var rail_key: String = ""
var _rail: VBoxContainer
var _rail_panel: PanelContainer
## Rail bottom offset (screens with a bottom strip end the rail above it).
var rail_bottom: float = -110.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_background()
	var back: Button = UIKit.icon_button("icon_home", "orange", 68)
	UIKit.place(back, Vector2.ZERO, Vector2(18, 14), Vector2(68, 68))
	back.pressed.connect(func() -> void:
		Sound.play("ui_back")
		_back())
	UIFx.press_juice(back)
	root.add_child(back)
	var sign: PanelContainer = UIKit.wood_sign()
	var sh: HBoxContainer = HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	sh.add_child(UIKit.tex_rect(_icon(), 46))
	sh.add_child(UIKit.label(_title(), 38, Color("#fff2c8"), 9))
	sign.add_child(sh)
	UIKit.place(sign, Vector2.ZERO, Vector2(98, 10), Vector2(420, 80))
	root.add_child(sign)
	UIFx.slide_in(sign, Vector2(-1, 0))
	bar = CurrencyBar.new()
	UIKit.place(bar, Vector2(1, 0), Vector2(-700, 18), Vector2(684, 56))
	bar.plus_pressed.connect(func(k: String) -> void:
		if self is ShopScreen:
			_rail_pressed(ShopScreen.tab_for(k))
		else:
			Game.goto_meta("shop", {"tab": ShopScreen.tab_for(k)}))
	root.add_child(bar)
	body = Control.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)
	if not _rail_items().is_empty():
		_build_rail()
	_build()
	Sound.play("popup_open", 0.6)
	Sound.set_music("menu", "menu")
	Sound.set_surroundings(Sound.realm if not Sound.realm.is_empty() else "blossom", true)


# ---- overridables
func _title() -> String:
	return ""


func _icon() -> String:
	return "icon_castle"


func _rail_items() -> Array:
	return []


func _build() -> void:
	pass


func _back() -> void:
	Game.goto_menu()


func _bg_realm() -> int:
	return 1


# ---- helpers
func _background() -> void:
	var bg: TextureRect = TextureRect.new()
	var bg_name: String = Background.bg_name(_bg_realm(), 0)
	bg.texture = Art.tex(bg_name) if not bg_name.is_empty() else null
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var warm: ColorRect = ColorRect.new()
	warm.color = Color(0.2, 0.09, 0.03, 0.5)
	warm.set_anchors_preset(Control.PRESET_FULL_RECT)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(warm)


func _build_rail() -> void:
	if _rail_panel:
		_rail_panel.queue_free()
	var panel: PanelContainer = _dark_panel()
	_rail_panel = panel
	UIKit.place(panel, Vector2.ZERO, Vector2(14, 100), Vector2(250, 0))
	panel.anchor_bottom = 1.0
	panel.offset_bottom = rail_bottom
	root.add_child(panel)
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 6)
	panel.add_child(_rail)
	for it: Array in _rail_items():
		var key: String = String(it[0])
		var sel: bool = key == rail_key
		var b: Button = UIKit.button("", "orange" if sel else "dark", 22, Vector2(226, 64))
		var h: HBoxContainer = HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 10)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 12
		h.add_child(UIKit.tex_rect(String(it[2]), 44))
		var l: Label = UIKit.label(String(it[1]), 22, Color.WHITE, 6)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		b.add_child(h)
		if MetaFrame.has_news(key) and not sel:
			b.add_child(_red_dot(Vector2(206, 4)))
		b.pressed.connect(func() -> void:
			if key != rail_key:
				Sound.play("tab")
				_rail_pressed(key))
		UIFx.press_juice(b)
		_rail.add_child(b)
	UIFx.slide_in(panel, Vector2(-1, 0), 0.05)


func _rail_pressed(key: String) -> void:
	Game.goto_meta(key)


## A real siege engine (the gameplay rig) for previews, standing with its wheels at `ground`.
func preview_catapult(ground: Vector2, scale_k: float, weapon_id: String = "", skin_id: String = "") -> Catapult:
	var holder: Node2D = Node2D.new()
	holder.position = ground
	add_child(holder)
	var c: Catapult = Catapult.new()
	c.weapon_id = Progression.weapon() if weapon_id.is_empty() else weapon_id
	c.skin_id = Progression.equipped("skins") if skin_id.is_empty() else skin_id
	holder.add_child(c)
	holder.scale = Vector2.ZERO
	holder.create_tween().tween_property(holder, "scale", Vector2.ONE * scale_k, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return c


## Dark wooden board behind rails and lists.
static func _dark_panel() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.11, 0.05, 0.88)
	sb.border_color = Color("#7a4a22")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	return p


## A card tile (dark green/purple/gold) used by reward grids.
static func card_box(color: Color, border: Color = Color("#c8a060")) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func _red_dot(at: Vector2) -> Control:
	var d: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#ff3a2a")
	sb.border_color = Color.WHITE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	d.add_theme_stylebox_override("panel", sb)
	d.position = at
	d.size = Vector2(18, 18)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.pivot_offset = Vector2(9, 9)
	var tw: Tween = d.create_tween().set_loops()
	tw.tween_property(d, "scale", Vector2.ONE * 1.3, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(d, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	return d


## Something to collect on that screen (red dot on its tab / tile).
static func has_news(key: String) -> bool:
	match key:
		"daily":
			return DailyRewards.can_claim()
		"spin":
			return SpinWheel.free_spin_ready()
		"achievements":
			return Progression.ready_count() > 0
		"challenges", "events":
			return not Save.daily_paid_today() and Save.stars(int(Data.b("modes", "challenges_unlock_level"))) > 0
	return false


## A reward line: icon + amount for each kind in `reward`.
static func reward_row(reward: Dictionary, size: int = 30) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k: String in Save.WALLET:
		if int(reward.get(k, 0)) > 0:
			h.add_child(UIKit.tex_rect(UIKit.CURRENCY_ICON[k], size))
			h.add_child(UIKit.label(CurrencyBar._fmt(int(reward[k])), int(size * 0.8), Color.WHITE, 6))
	if reward.has("skin"):
		h.add_child(UIKit.tex_rect("icon_skins", size))
	return h


## Fly every currency in `reward` from `from` into the bar. The save already holds it (claims
## save silently first), so this only animates.
func pay(reward: Dictionary, from: Vector2) -> void:
	for k: String in Save.WALLET:
		if int(reward.get(k, 0)) > 0:
			UIFx.fly_reward(from, k, int(reward[k]), bar, false)
