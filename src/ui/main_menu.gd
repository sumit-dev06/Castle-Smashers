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
	Sound.set_surroundings(Background.look(Background.realm_info(_realm())), true)
	if not "--no-popups" in OS.get_cmdline_user_args():
		Notifications.ask_on_home(self)
		PlayServices.on_home(self)
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
var _name_label: Label


static func player_name() -> String:
	var n: String = String(Save.data.get("player_name", ""))
	return n if not n.is_empty() else String(Data.balance["profile"]["default_name"])


## Rename: free once the player has reached level profile.free_rename_level, otherwise gems.
func _open_rename() -> void:
	Sound.play("ui_tap")
	var cfg: Dictionary = Data.balance["profile"]
	var free: bool = int(Save.data.get("unlocked", 1)) >= int(cfg["free_rename_level"])
	var cost: Dictionary = {} if free else {"gems": int(cfg["rename_gems"])}
	var layer: CanvasLayer = UIFx.overlay()
	layer.add_child(UIKit.dim())
	# Name panel at the top, our own keyboard on the lower screen: the system keyboard floats over
	# the middle in landscape and hid the field.
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	layer.add_child(col)
	var top: MarginContainer = MarginContainer.new()
	top.add_theme_constant_override("margin_top", 14)
	col.add_child(top)
	var center: CenterContainer = CenterContainer.new()
	top.add_child(center)
	var p: PanelContainer = UIKit.panel()
	p.custom_minimum_size = Vector2(760, 0)
	center.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(UIKit.tex_rect("icon_edit", 44))
	head.add_child(UIKit.label("Commander Name", 36, Color("#ffd23a"), 9))
	v.add_child(head)
	var field: LineEdit = LineEdit.new()
	field.text = player_name()
	field.max_length = int(cfg["name_max"])
	field.custom_minimum_size = Vector2(500, 64)
	field.add_theme_font_override("font", UIKit.body_font())
	field.add_theme_font_size_override("font_size", 30)
	field.virtual_keyboard_enabled = false
	field.custom_minimum_size = Vector2(700, 60)
	v.add_child(field)
	var note: Label = UIKit.body("Free: you have reached level %d." % int(cfg["free_rename_level"]) if free \
			else "Costs %d gems. Renaming is free from level %d." % [int(cfg["rename_gems"]), int(cfg["free_rename_level"])], 20)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 500
	v.add_child(note)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var cancel: Button = UIKit.button("CANCEL", "orange", 26, Vector2(180, 66))
	cancel.pressed.connect(func() -> void:
		Sound.play("ui_back")
		layer.queue_free())
	var save: Button = UIKit.button("SAVE" if free else "SAVE  %d" % int(cfg["rename_gems"]), "green", 26, Vector2(200, 66))
	if not free:
		save.icon = Art.tex("gem")
		save.expand_icon = true
		save.add_theme_constant_override("icon_max_width", 30)
	save.pressed.connect(func() -> void:
		var n: String = clean_name(field.text)
		if n.length() < int(cfg["name_min"]):
			note.text = "Use %d to %d letters or numbers." % [int(cfg["name_min"]), int(cfg["name_max"])]
			UIFx.shake(save)
			Sound.play("deny")
			return
		if n == player_name():
			layer.queue_free()
			return
		if not Save.spend(cost):
			note.text = "Not enough gems. Reach level %d to rename for free." % int(cfg["free_rename_level"])
			UIFx.shake(save)
			Sound.play("deny")
			return
		Save.data["player_name"] = n
		Save.write()
		_name_label.text = n
		Sound.play("upgrade")
		layer.queue_free())
	for b: Button in [cancel, save]:
		UIFx.press_juice(b)
		row.add_child(b)
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	col.add_child(_name_keyboard(field))
	p.pivot_offset = Vector2(380, 100)
	UIFx.pop_in(p)
	field.grab_focus.call_deferred()
	field.caret_column = field.text.length()


## In-game keyboard for the name field: digits, QWERTY, shift (one letter), backspace, space.
func _name_keyboard(field: LineEdit) -> Control:
	var pad: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.06, 0.94)
	sb.border_color = Color("#3a2212")
	sb.border_width_top = 3
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	pad.add_theme_stylebox_override("panel", sb)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	pad.add_child(rows)
	var letters: Array[Button] = []
	var shift: Array[bool] = [field.text.is_empty()]
	var relabel: Callable = func() -> void:
		for b: Button in letters:
			b.text = b.text.to_upper() if shift[0] else b.text.to_lower()
	var type: Callable = func(t: String) -> void:
		if field.text.length() >= field.max_length:
			return
		field.insert_text_at_caret(t)
		Sound.play("ui_tap", 0.4)
	for line: String in ["1234567890", "qwertyuiop", "asdfghjkl", "^zxcvbnm<", " "]:
		var r: HBoxContainer = HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", 6)
		rows.add_child(r)
		for ch: String in line:
			var b: Button
			if ch == "^":
				b = UIKit.button("SHIFT", "blue", 20, Vector2(140, 56))
				b.pressed.connect(func() -> void:
					shift[0] = not shift[0]
					relabel.call())
			elif ch == "<":
				b = UIKit.button("DEL", "orange", 20, Vector2(140, 56))
				b.pressed.connect(func() -> void:
					var at: int = field.caret_column
					if at > 0:
						field.text = field.text.substr(0, at - 1) + field.text.substr(at)
						field.caret_column = at - 1
					Sound.play("ui_tap", 0.4))
			elif ch == " ":
				b = UIKit.button("SPACE", "dark", 20, Vector2(520, 52))
				b.pressed.connect(func() -> void: type.call(" "))
			else:
				b = UIKit.button(ch.to_upper() if shift[0] and ch >= "a" else ch, "dark", 26, Vector2(96, 56))
				var letter: bool = ch >= "a" and ch <= "z"
				if letter:
					letters.append(b)
				b.pressed.connect(func() -> void:
					type.call(b.text)
					if letter and shift[0]:
						shift[0] = false
						relabel.call())
			b.focus_mode = Control.FOCUS_NONE
			r.add_child(b)
	return pad


## Letters, digits and single spaces only, trimmed.
static func clean_name(raw: String) -> String:
	var out: String = ""
	for ch: String in raw.strip_edges():
		var c: int = ch.unicode_at(0)
		var ok: bool = (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c > 191 and c < 0x2000)
		if ok or (ch == " " and not out.ends_with(" ")):
			out += ch
	return out.strip_edges()


## Unread-letter badge on the mail button; removed the moment the letter is claimed.
var _mail_dot: Control


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
	_name_label = UIKit.label(player_name(), 26, Color("#ffd23a"), 7)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)
	var edit: Button = UIKit.icon_button("icon_edit", "orange", 40)
	edit.custom_minimum_size = Vector2(40, 40)
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.pressed.connect(_open_rename)
	name_row.add_child(edit)
	# The whole name line is the rename target (a 40 px pencil alone is hard to hit on a phone).
	name_row.mouse_filter = Control.MOUSE_FILTER_STOP
	name_row.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
				and not (e as InputEventMouseButton).pressed:
			name_row.accept_event()
			_open_rename())
	v.add_child(name_row)
	var th: Array = Data.balance["rank"]["stars"]
	var ri: int = Progression.rank_index()
	var stars: int = Save.total_stars()
	var goal: int = int(th[mini(ri + 1, th.size() - 1)])
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UIKit.tex_rect("star_full", 26))
	var pb: Control = _bar(Progression.rank_progress(), 170, 22, Color("#ffb52a"))
	var pl: Label = UIKit.label("%d / %d" % [stars, goal] if ri < th.size() - 1 else "%d  MAX" % stars, 16, Color.WHITE, 4)
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pb.add_child(pl)
	row.add_child(pb)
	row.add_child(UIKit.label(Progression.rank_name(), 16, Color("#f4e2b8"), 4))
	v.add_child(row)
	prof.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			Game.goto_meta("achievements"))
	root.add_child(prof)
	UIFx.slide_in(prof, Vector2(-1, 0))
	bar = CurrencyBar.new()
	bar.add_energy()
	UIKit.place(bar, Vector2(1, 0), Vector2(-850, 18), Vector2(670, 56))
	bar.plus_pressed.connect(func(k: String) -> void: Game.goto_meta("shop", {"tab": ShopScreen.tab_for(k)}))
	root.add_child(bar)
	var mail: Button = UIKit.icon_button("icon_mail", "dark", 66)
	UIKit.place(mail, Vector2(1, 0), Vector2(-166, 12), Vector2(66, 66))
	mail.pressed.connect(_open_mail)
	if not bool(Save.data.get("mail_claimed", false)):
		_mail_dot = MetaFrame._red_dot(Vector2(50, -4))
		mail.add_child(_mail_dot)
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
			_toast("Clear Level %d to unlock Special Missions" % chal_lv)
	var ch: Button = _tile("challenges", "Special Missions", "icon_challenges", Vector2(14, 246), Vector2(150, 112), Vector2.ZERO, false, open_chal)
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
	var sword_l: TextureRect = UIKit.tex_rect("icon_challenges", 52)
	var play_l: Label = UIKit.label("PLAY", 68, Color("#4a2408"), 0)
	var sword_r: TextureRect = UIKit.tex_rect("icon_challenges", 52)
	h.add_child(sword_l)
	h.add_child(play_l)
	h.add_child(sword_r)
	v.add_child(h)
	_clash(sword_l, play_l, sword_r)
	var sub: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#5a3010")
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sub.add_theme_stylebox_override("panel", sb)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var done: bool = Game.campaign_done()
	var sub_text: String = "All %d cleared · What's next?" % Data.level_count() if done \
		else "Level %d · %s" % [lv, String(Background.realm_info(_realm()).get("name", ""))]
	sub.add_child(UIKit.label(sub_text, 22, Color.WHITE, 4))
	v.add_child(sub)
	b.pivot_offset = Vector2(215, 62)
	b.pressed.connect(func() -> void:
		Sound.play("play_press")
		if done:
			Game.goto_campaign_end()
		else:
			Game.goto_level_entry(lv))
	UIFx.press_juice(b)
	root.add_child(b)
	# Entrance pop and press feedback only: no idle loop, so the button reads as solid, not busy.
	UIFx.pop_in(b, 0.15)


## PLAY idle cue: every few seconds both crossed swords swing toward the word and strike
## (a fast swing, a tiny punch on PLAY at the hit, a springy return), then rest. Timing: balance home.
func _clash(left: Control, word: Control, right: Control) -> void:
	var gap: float = Data.bf("home", "play_clash_gap_s")
	var tw: Tween = create_tween().set_loops()
	tw.tween_callback(func() -> void:
		left.pivot_offset = left.size * Vector2(0.5, 0.85)
		right.pivot_offset = right.size * Vector2(0.5, 0.85)
		word.pivot_offset = word.size * 0.5)
	tw.tween_interval(gap)
	tw.tween_property(left, "rotation_degrees", -16.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(right, "rotation_degrees", 16.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(left, "rotation_degrees", 14.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(right, "rotation_degrees", -14.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(word, "scale", Vector2.ONE * 1.07, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(left, "rotation_degrees", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(right, "rotation_degrees", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(word, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## True when Master Orin can forge or improve something with the current coin balance.
func _workshop_ready() -> bool:
	for wid: Variant in Progression.weapons():
		var id: String = String(wid)
		var unlock_cost: Dictionary = Progression.weapon_unlock_cost(id)
		if not unlock_cost.is_empty() and Save.can_afford(unlock_cost):
			return true
		if Progression.weapon_owned(id):
			for track: String in Progression.weapon_tracks(id):
				var cost: Dictionary = Progression.weapon_up_cost(id, track)
				if not cost.is_empty() and Save.can_afford(cost):
					return true
	for track: String in Data.balance["upgrades"]["vanguard"]:
		var vanguard_cost: Dictionary = Progression.up_cost("vanguard", track)
		if not vanguard_cost.is_empty() and Save.can_afford(vanguard_cost):
			return true
	return false


func _hero_card() -> void:
	var p: PanelContainer = _card(Color("#3a2414"))
	UIKit.place(p, Vector2(0, 1), Vector2(14, -118), Vector2(380, 104))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var orin: TextureRect = UIKit.tex_rect("wizard_idle", 82)
	h.add_child(orin)
	# One greeting nod from his feet once the card has slid in, then he stands still.
	var nod: Tween = orin.create_tween()
	nod.tween_interval(UIFx.cfg("orin_nod_delay_s"))
	nod.tween_callback(func() -> void: orin.pivot_offset = Vector2(orin.size.x * 0.5, orin.size.y))
	nod.tween_property(orin, "rotation_degrees", UIFx.cfg("orin_nod_deg"), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	nod.tween_property(orin, "rotation_degrees", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	v.add_child(UIKit.label("Master Orin", 26, Color.WHITE, 6))
	var current: String = Progression.weapon()
	v.add_child(UIKit.label("%s · Forge Lv. %d / 12" % [String(Progression.weapon_cfg(current)["short_name"]), Progression.weapon_total_level(current)], 16, Color("#ffe27a"), 4, false))
	v.add_child(UIKit.label("New heroes join as you win levels", 18, Color("#d9c8aa"), 3, false))
	var open: Button = UIKit.button("WORKSHOP", "green", 18, Vector2(118, 76))
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		Game.goto_meta("upgrades"))
	if _workshop_ready():
		# The red dot is the only cue; the button no longer wiggles.
		open.add_child(MetaFrame._red_dot(Vector2(102, -4)))
	UIFx.press_juice(open)
	h.add_child(open)
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
			if is_instance_valid(_mail_dot):
				_mail_dot.queue_free()
			for kk: String in Save.WALLET:
				if int(reward.get(kk, 0)) > 0:
					Save.add(kk, int(reward[kk]), false, false)
			Save.write()
			Sound.play("chest_open")
			var from: Vector2 = b.get_global_rect().get_center()
			for kk: String in Save.WALLET:
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
	var first: bool = not Game.promo_seen
	if "--no-popups" in OS.get_cmdline_user_args():
		return
	if not DailyRewards.can_claim() or String(Save.data.get("daily_popup", "")) == Save.today():
		# No daily reward waiting: the feature showcase gets this visit (never both at once).
		PromoPopup.maybe_show(self, first)
		return
	Save.data["daily_popup"] = Save.today()
	Save.write()
	# Let the player look at the home screen first; skip it if they already went somewhere.
	get_tree().create_timer(Data.bf("home", "popup_delay_s")).timeout.connect(func() -> void:
		if is_inside_tree() and Game.current == self:
			Game.goto_meta("daily"))
