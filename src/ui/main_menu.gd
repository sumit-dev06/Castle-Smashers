class_name MainMenu
extends Node2D
## Home screen (spec in docs/UI_DESIGN.md "Home"). A live valley scene behind: catapult, Vanguard,
## bobbing heroes and enemy archers. Every button opens a different place (no duplicates):
## top: rank card (→ Achievements), currency bar (+ → matching Shop tab), mail, settings;
## left: Campaign (world map), Challenges, Shop; right: Daily Rewards, Spin Wheel, Achievements;
## bottom: hero upgrade card (→ Upgrades), the gold PLAY plank (next level) and Skins.
## Red dots come from MetaFrame.has_news. The daily-reward screen opens once per day on the first visit.

var _camera: Camera2D
var _t: float = 0.0
var _heroes: Array[Sprite2D] = []
var root: Control
var bar: CurrencyBar


func _ready() -> void:
	_scene()
	var ui: CanvasLayer = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	_top_bar()
	_left_tiles()
	_right_column()
	_play_plank()
	_hero_card()
	_skins_tile()
	Sound.set_music("menu", "menu")
	Sound.set_surroundings(String(Background.realm_info(_realm()).get("key", "blossom")), true)
	_daily_popup()


# ------------------------------------------------------------------------------------ backdrop
func _scene() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * 0.8
	_camera.position = Vector2(0, -(Data.bf("camera", "menu_ground_screen_frac") - 0.5) * 720.0 / 0.8)
	add_child(_camera)
	var bg: Background = Background.new()
	bg.camera = _camera
	bg.realm = _realm()
	bg.blurred = false
	bg.ground_frac = Data.bf("camera", "menu_ground_screen_frac")
	add_child(bg)
	var g: Sprite2D = Art.sprite("ground_cliff")
	g.centered = false
	g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	g.region_enabled = true
	g.region_rect = Rect2(0, 0, 8000, g.texture.get_size().y)
	g.position = Vector2(-2000, -12)
	add_child(g)
	var cat: Catapult = Catapult.new()
	cat.position = Vector2(-360, 0)
	cat.scale = Vector2.ONE * 1.25
	add_child(cat)
	var kinds: Array[String] = ["stone", "fire", "bomb", "cyclone"]
	for i: int in kinds.size():
		var s: Sprite2D = Projectile.make_sprite(kinds[i])
		s.scale *= 1.2
		s.position = Vector2(335 + i * 80, -45)
		add_child(s)
		_heroes.append(s)
	for i: int in 3:
		var so: Soldier = Soldier.new()
		so.setup(Vector2(-560 - i * 80, 0))
		add_child(so)
	for i: int in 2:
		var ar: Sprite2D = Art.unit_sprite("archer_idle", 110)
		ar.position = Vector2(690 + i * 100, 0)
		ar.flip_h = true
		add_child(ar)


func _process(delta: float) -> void:
	_t += delta
	_camera.position.x = sin(_t * 0.15) * 60.0
	var bob: float = Data.bf("home", "hero_bob_px")
	for i: int in _heroes.size():
		_heroes[i].position.y = -45 - absf(sin(_t * 2.6 + i * 0.9)) * bob
		_heroes[i].rotation = sin(_t * 2.0 + i) * 0.08


# ------------------------------------------------------------------------------------ helpers
func _next_level() -> int:
	return clampi(int(Save.data["unlocked"]), 1, Data.level_count())


func _realm() -> int:
	return int(Data.level(_next_level()).get("realm", 1))


func _card(color: Color, border: Color = Color("#6a4424")) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", MetaFrame.card_box(color, border))
	return p


## Square tile: icon over a label, red dot when there is news. Whole tile is a button.
func _tile(key: String, text: String, icon: String, at: Vector2, size: Vector2, anchor: Vector2, gold: bool, cb: Callable) -> Button:
	var b: Button = UIKit.button("", "orange" if gold else "dark", 20, size)
	if not gold:
		b.add_theme_stylebox_override("normal", MetaFrame.card_box(Color("#4a2e18"), Color("#2a180c")))
		b.add_theme_stylebox_override("hover", MetaFrame.card_box(Color("#5a3820"), Color("#2a180c")))
		b.add_theme_stylebox_override("pressed", MetaFrame.card_box(Color("#3a2414"), Color("#2a180c")))
	UIKit.place(b, anchor, at, size)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic: TextureRect = UIKit.tex_rect(icon, size.y * 0.56)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l: Label = UIKit.label(text, 20 if size.x < 140 else 24, Color.WHITE, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if MetaFrame.has_news(key):
		b.add_child(MetaFrame._red_dot(Vector2(size.x - 18, -4)))
	b.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		cb.call())
	UIFx.press_juice(b)
	root.add_child(b)
	return b


func _bar(frac: float, w: float, h: float, color: Color) -> Control:
	var back: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#1e120a")
	sb.set_corner_radius_all(int(h / 2))
	back.add_theme_stylebox_override("panel", sb)
	back.custom_minimum_size = Vector2(w, h)
	var fill: Panel = Panel.new()
	var fs: StyleBoxFlat = StyleBoxFlat.new()
	fs.bg_color = color
	fs.set_corner_radius_all(int(h / 2))
	fill.add_theme_stylebox_override("panel", fs)
	fill.position = Vector2(2, 2)
	fill.size = Vector2(maxf((w - 4) * clampf(frac, 0.0, 1.0), h - 4), h - 4)
	fill.visible = frac > 0.0
	back.add_child(fill)
	return back


# ------------------------------------------------------------------------------------ top
func _top_bar() -> void:
	var prof: PanelContainer = _card(Color("#3a2414"))
	UIKit.place(prof, Vector2.ZERO, Vector2(14, 10), Vector2(390, 92))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	prof.add_child(h)
	var av: PanelContainer = _card(Color("#c88a3a"), Color("#2a180c"))
	av.custom_minimum_size = Vector2(72, 72)
	var face: TextureRect = UIKit.tex_rect("soldier_idle", 64)
	av.add_child(face)
	h.add_child(av)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(UIKit.tex_rect("icon_crown", 28))
	name_row.add_child(UIKit.label(Progression.rank_name(), 28, Color("#ffd23a"), 7))
	v.add_child(name_row)
	var th: Array = Data.balance["rank"]["stars"]
	var ri: int = Progression.rank_index()
	var stars: int = Save.total_stars()
	var goal: int = int(th[mini(ri + 1, th.size() - 1)])
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UIKit.tex_rect("star_full", 26))
	var pb: Control = _bar(Progression.rank_progress(), 200, 22, Color("#ffb52a"))
	var pl: Label = UIKit.label("%d / %d" % [stars, goal] if ri < th.size() - 1 else "%d  MAX" % stars, 16, Color.WHITE, 4)
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pb.add_child(pl)
	row.add_child(pb)
	v.add_child(row)
	prof.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			Game.goto_meta("achievements"))
	root.add_child(prof)
	UIFx.slide_in(prof, Vector2(-1, 0))
	bar = CurrencyBar.new()
	UIKit.place(bar, Vector2(1, 0), Vector2(-850, 18), Vector2(670, 56))
	bar.plus_pressed.connect(func(k: String) -> void: Game.goto_meta("shop", {"tab": ShopScreen.tab_for(k)}))
	root.add_child(bar)
	var mail: Button = UIKit.icon_button("icon_mail", "dark", 66)
	UIKit.place(mail, Vector2(1, 0), Vector2(-166, 12), Vector2(66, 66))
	mail.pressed.connect(_open_mail)
	if not bool(Save.data.get("mail_claimed", false)):
		mail.add_child(MetaFrame._red_dot(Vector2(50, -4)))
	UIFx.press_juice(mail)
	root.add_child(mail)
	var gear: Button = UIKit.icon_button("icon_settings", "dark", 66)
	UIKit.place(gear, Vector2(1, 0), Vector2(-86, 12), Vector2(66, 66))
	gear.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		SettingsPopup.open(self))
	UIFx.press_juice(gear)
	root.add_child(gear)


# ------------------------------------------------------------------------------------ side columns
func _left_tiles() -> void:
	var chal_lv: int = int(Data.b("modes", "challenges_unlock_level"))
	var cam: Button = _tile("campaign", "Campaign", "icon_flag", Vector2(14, 112), Vector2(150, 124), Vector2.ZERO, true, Game.goto_map)
	UIFx.slide_in(cam, Vector2(-1, 0), 0.05)
	var open_chal: Callable = func() -> void:
		if Save.stars(chal_lv) > 0:
			Game.goto_challenges()
		else:
			_toast("Clear Level %d to unlock Challenges" % chal_lv)
	var ch: Button = _tile("challenges", "Challenges", "icon_challenges", Vector2(14, 246), Vector2(150, 112), Vector2.ZERO, false, open_chal)
	var sh: Button = _tile("shop", "Shop", "icon_shop", Vector2(14, 368), Vector2(150, 112), Vector2.ZERO, false, func() -> void: Game.goto_meta("shop"))
	for i: int in 2:
		UIFx.slide_in([ch, sh][i], Vector2(-1, 0), 0.1 + i * 0.05)


func _right_column() -> void:
	var items: Array = [["daily", "Daily Rewards", "icon_daily"], ["spin", "Spin Wheel", "icon_spin"], ["achievements", "Achievements", "icon_achievements"]]
	for i: int in items.size():
		var key: String = items[i][0]
		var t: Button = _tile(key, items[i][1], items[i][2], Vector2(-174, 112 + i * 122), Vector2(160, 112), Vector2(1, 0), false, func() -> void: Game.goto_meta(key))
		UIFx.slide_in(t, Vector2(1, 0), 0.08 + i * 0.05)


# ------------------------------------------------------------------------------------ play + hero
func _play_plank() -> void:
	var lv: int = _next_level()
	var b: Button = UIKit.button("", "orange", 20, Vector2(430, 124))
	UIKit.place(b, Vector2(0.5, 1), Vector2(-215, -250), Vector2(430, 124))
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(UIKit.tex_rect("icon_challenges", 52))
	h.add_child(UIKit.label("PLAY", 68, Color("#4a2408"), 0))
	h.add_child(UIKit.tex_rect("icon_challenges", 52))
	v.add_child(h)
	var sub: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#5a3010")
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sub.add_theme_stylebox_override("panel", sb)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_child(UIKit.label("Level %d · %s" % [lv, String(Background.realm_info(_realm()).get("name", ""))], 22, Color.WHITE, 4))
	v.add_child(sub)
	b.pivot_offset = Vector2(215, 62)
	b.pressed.connect(func() -> void:
		Sound.play("play_press")
		Game.goto_level_entry(lv))
	UIFx.press_juice(b)
	root.add_child(b)
	UIFx.pop_in(b, 0.15)
	var tw: Tween = b.create_tween().set_loops()
	tw.tween_interval(0.5)
	tw.tween_property(b, "scale", Vector2.ONE * 1.05, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


## The hero that is cheapest to level up next (affordable first), else the configured default.
func _featured_hero() -> String:
	var best: String = String(Data.b("home", "hero_card_kind"))
	var best_cost: int = 1 << 30
	for kind: String in ["stone", "fire", "bomb", "cyclone", "quake"]:
		var cfg: Dictionary = Data.projectiles[kind]
		if int(cfg["unlock_level"]) > 1 and not Save.is_unlocked(int(cfg["unlock_level"])):
			continue
		var c: int = Workshop.next_cost(kind)
		if c >= 0 and c < best_cost:
			best_cost = c
			best = kind
	return best


func _hero_card() -> void:
	var kind: String = _featured_hero()
	var cfg: Dictionary = Data.projectiles[kind]
	var p: PanelContainer = _card(Color("#3a2414"))
	UIKit.place(p, Vector2(0, 1), Vector2(14, -118), Vector2(380, 104))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(UIKit.tex_rect(String(cfg["texture"]), 80))
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(UIKit.label(String(cfg["name"]), 26, Color.WHITE, 6))
	var lv: int = Workshop.level_of(kind)
	v.add_child(UIKit.label("Lv. %d / %d" % [lv, Workshop.max_level()], 18, Color("#ffe27a"), 4))
	v.add_child(_bar(float(lv) / float(maxi(Workshop.max_level(), 1)), 150, 16, Color("#ffb52a")))
	var up: Button = UIKit.button("UPGRADE", "green", 20, Vector2(110, 76))
	up.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	up.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		Game.goto_meta("upgrades", {"focus_hero": kind}))
	var cost: int = Workshop.next_cost(kind)
	if cost >= 0 and Save.coins() >= cost:
		up.add_child(MetaFrame._red_dot(Vector2(94, -4)))
		UIFx.breathe(up)
	UIFx.press_juice(up)
	h.add_child(up)
	root.add_child(p)
	UIFx.slide_in(p, Vector2(-1, 0), 0.2)


# ------------------------------------------------------------------------------------ bottom
## Catapult skins and flight trails (trails are a tab inside the Skins screen).
func _skins_tile() -> void:
	var t: Button = _tile("skins", "Skins", "icon_skins", Vector2(-174, -126), Vector2(160, 112), Vector2(1, 1), false, func() -> void: Game.goto_meta("skins"))
	UIFx.slide_in(t, Vector2(1, 0), 0.2)


# ------------------------------------------------------------------------------------ popups
func _toast(text: String) -> void:
	Sound.play("locked")
	Sound.play("toast", 0.7)
	var l: Label = UIKit.label(text, 30, Color.WHITE, 10)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position.y = 110
	root.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## Welcome letter with a one-time gift (balance home.welcome_mail).
func _open_mail() -> void:
	Sound.play("ui_tap")
	var layer: CanvasLayer = UIFx.overlay()
	var dim: ColorRect = UIKit.dim()
	layer.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var p: PanelContainer = UIKit.panel()
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var cfg: Dictionary = Data.b("home", "welcome_mail")
	var claimed: bool = bool(Save.data.get("mail_claimed", false))
	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(UIKit.tex_rect("icon_mail", 48))
	head.add_child(UIKit.label(String(cfg["title"]) if not claimed else "Mailbox", 38, Color("#ffd23a"), 9))
	v.add_child(head)
	var body: Label = UIKit.body(String(cfg["body"]) if not claimed else "No new letters. Check back after the next update!", 23)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 520
	v.add_child(body)
	var reward: Dictionary = cfg["reward"]
	if not claimed:
		v.add_child(MetaFrame.reward_row(reward, 40))
	var b: Button = UIKit.button("CLAIM" if not claimed else "CLOSE", "green" if not claimed else "orange", 30, Vector2(240, 70))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		if not bool(Save.data.get("mail_claimed", false)):
			Save.data["mail_claimed"] = true
			for kk: String in ["coins", "gems", "blueprints"]:
				if int(reward.get(kk, 0)) > 0:
					Save.add(kk, int(reward[kk]), false, false)
			Save.write()
			Sound.play("chest_open")
			var from: Vector2 = b.get_global_rect().get_center()
			for kk: String in ["coins", "gems", "blueprints"]:
				if int(reward.get(kk, 0)) > 0:
					UIFx.fly_reward(from, kk, int(reward[kk]), bar, false)
			UIFx.confetti(from)
		layer.queue_free())
	UIFx.press_juice(b)
	v.add_child(b)
	p.pivot_offset = Vector2(280, 150)
	UIFx.pop_in(p)


## First visit of the day with an unclaimed daily reward: open Daily Rewards.
func _daily_popup() -> void:
	if "--no-popups" in OS.get_cmdline_user_args() or not DailyRewards.can_claim():
		return
	if String(Save.data.get("daily_popup", "")) == Save.today():
		return
	Save.data["daily_popup"] = Save.today()
	Save.write()
	get_tree().create_timer(Data.bf("home", "popup_delay_s")).timeout.connect(func() -> void:
		if is_inside_tree():
			Game.goto_meta("daily"))
