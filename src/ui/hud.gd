class_name Hud
extends CanvasLayer
## In-level HUD in the reference layout: logo top-left, wooden title sign with live stars top-centre,
## slate counters + Pause / Reset buttons top-right. Hints, level banner, pause and result popups.

var level: Level = null
var _root: Control
var _title: Label
var _title_box: VBoxContainer
var _chips: HBoxContainer
var _stars: Array[TextureRect] = []
var _shots: Label
var _shot_icon: TextureRect
var _destruction: Label
var _objective: Label
var _score: Label
var _hint: Label
var _popup: Control
var _last_stars: int = 0
var _wind_box: Control
var _wind_icon: TextureRect
var _wind_label: Label
var _boss_box: Control
var _boss_fill: ColorRect
var _boss_pips: Array[TextureRect] = []
var _boss_w: float = 420.0
var _mode_box: PanelContainer
var _mode_icon: TextureRect
var _mode_value: Label
var _mode_title: Label
var _mode_warn: bool = false
var _status_row: HBoxContainer
var _status: Dictionary = {}
var _chain_box: PanelContainer
var _chain_n: Label
var _chain_mult: Label
var _chain_shown: int = 0
var _ammo_row: HBoxContainer
var _ammo_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var logo: Control = UIKit.logo(30)
	logo.position = Vector2(16, 8)
	_root.add_child(logo)

	var top: VBoxContainer = VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 8
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: PanelContainer = UIKit.wood_sign()
	var sv: VBoxContainer = VBoxContainer.new()
	sv.add_theme_constant_override("separation", -2)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = UIKit.label("", 26, Color.WHITE, 8)
	sv.add_child(_title)
	var srow: HBoxContainer = HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in 3:
		var st: TextureRect = UIKit.tex_rect("star_empty", 30)
		srow.add_child(st)
		_stars.append(st)
	sv.add_child(srow)
	plate.add_child(sv)
	top.add_child(plate)
	_root.add_child(top)
	_title_box = top

	var tr: HBoxContainer = HBoxContainer.new()
	_chips = tr
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-14, 10)
	tr.add_theme_constant_override("separation", 8)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shots: Array = _counter("Shots", "hero_stone")
	_shot_icon = shots[1]
	_shots = shots[2]
	tr.add_child(shots[0])
	var destruction: Array = _counter("Destruction", "logo_castle")
	_destruction = destruction[2]
	tr.add_child(destruction[0])
	var objective: Array = _counter("Objective", "archer_idle")
	_objective = objective[2]
	tr.add_child(objective[0])
	tr.add_child(_labeled_button("icon_pause", "Pause", "orange", show_pause))
	tr.add_child(_labeled_button("icon_restart", "Reset", "orange", func() -> void: level.restart()))
	_root.add_child(tr)

	_score = UIKit.label("0", 30, Color("#ffe27a"), 8)
	_score.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_score.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_score.position = Vector2(-200, 96)
	_score.size = Vector2(186, 36)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_score)
	_build_chain()

	if level and level.data.has("wind"):
		_build_wind()
	if level and level.boss:
		_build_boss_bar()

	_ammo_row = HBoxContainer.new()
	_ammo_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_ammo_row.add_theme_constant_override("separation", 8)
	_ammo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.place(_ammo_row, Vector2(0, 1), Vector2(16, -112), Vector2(560, 96))
	_root.add_child(_ammo_row)

	_hint = UIKit.label("", 28, Color.WHITE, 9)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position.y = -46
	_hint.modulate.a = 0.0
	_root.add_child(_hint)


## [panel, icon, value label]
func _counter(title: String, icon: String) -> Array:
	var p: PanelContainer = UIKit.slate()
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic: TextureRect = UIKit.tex_rect(icon, 40)
	h.add_child(ic)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label(title, 17, Color.WHITE, 0, false))
	var val: Label = UIKit.label("0 / 0", 24, Color.WHITE, 5)
	v.add_child(val)
	h.add_child(v)
	p.add_child(h)
	return [p, ic, val]


func _labeled_button(icon: String, text: String, color: String, cb: Callable) -> Control:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	var b: Button = UIKit.icon_button(icon, color, 58)
	b.pressed.connect(cb)
	v.add_child(b)
	v.add_child(UIKit.label(text, 18, Color.WHITE, 6))
	return v


func set_title(id: int, name_text: String) -> void:
	_title.text = name_text if id > Data.CHALLENGE_BASE else "Level %d – %s" % [id, name_text]
	_fit_title.call_deferred()


## Keeps the centred title plate clear of the logo and the right-hand chips: it slides left first,
## then the font shrinks if there is still no room (long names with a long objective text).
func _fit_title() -> void:
	if _title_box == null or _chips == null:
		return
	await get_tree().process_frame
	var gap: float = 12.0
	var logo_right: float = 230.0
	for i: int in 4:
		_title_box.offset_left = 0.0
		_title_box.offset_right = 0.0
		var w: float = _title_box.get_combined_minimum_size().x
		var view_w: float = _root.size.x
		var left: float = (view_w - w) / 2.0
		var limit: float = _chips.get_global_rect().position.x - _root.get_global_rect().position.x - gap
		if left + w > limit:
			left = maxf(logo_right, limit - w)
		if left + w <= limit or _title.get_theme_font_size("font_size") <= 18:
			_title_box.position.x = left
			_title_box.size.x = w
			return
		_title.add_theme_font_size_override("font_size", _title.get_theme_font_size("font_size") - 3)


## Mode objective chip at the top left (under the wind chip when there is one).
func set_mode(icon: String, title: String, value: String, warn: bool = false) -> void:
	if _mode_box == null:
		var parts: Array = _counter(title, icon)
		_mode_box = parts[0]
		_mode_icon = parts[1]
		_mode_value = parts[2]
		_mode_title = (_mode_value.get_parent() as VBoxContainer).get_child(0) as Label
		var y: float = 152.0 if _wind_box else 96.0
		UIKit.place(_mode_box, Vector2(0, 0), Vector2(16, y), Vector2(210, 56))
		_root.add_child(_mode_box)
		UIFx.pop_in(_mode_box, 0.3)
	if _mode_value.text != value and not _mode_value.text.is_empty() and not value.contains(":"):
		UIFx.pop(_mode_box, 1.15)
	_mode_value.text = value
	_mode_value.add_theme_color_override("font_color", Color("#ff7a6a") if warn else Color.WHITE)
	if warn and not _mode_warn:
		var tw: Tween = _mode_box.create_tween().set_loops(10)
		tw.tween_property(_mode_box, "modulate", Color(1.5, 0.8, 0.8), 0.25)
		tw.tween_property(_mode_box, "modulate", Color.WHITE, 0.25)
	_mode_warn = warn


func set_shots(left: int, total: int, kind: String) -> void:
	_shots.text = "%d / %d" % [left, total]
	_shot_icon.texture = Art.tex(String(Data.projectiles[kind]["texture"]))


## Ammo tray (bottom left): the heroes still to fire, in order. The first one is the hero in the
## bucket (or the next to hop in), drawn bigger with a gold frame and a NEXT tag.
func set_ammo(kinds: Array, index: int) -> void:
	var key: String = "%d:%s" % [index, ",".join(PackedStringArray(kinds.map(func(k: Variant) -> String: return String(k))))]
	if key == _ammo_key or _ammo_row == null:
		return
	var first_build: bool = _ammo_key.is_empty()
	_ammo_key = key
	for c: Node in _ammo_row.get_children():
		c.queue_free()
	for i: int in range(index, kinds.size()):
		var kind: String = String(kinds[i])
		var cfg: Dictionary = Data.projectiles[kind]
		var now: bool = i == index
		var side: float = 86.0 if now else 66.0
		var slot: PanelContainer = PanelContainer.new()
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.07, 0.04, 0.72)
		sb.border_color = Color("#ffd23a") if now else Color("#c8a060")
		sb.set_border_width_all(4 if now else 2)
		sb.set_corner_radius_all(int(side / 2))
		sb.set_content_margin_all(4)
		slot.add_theme_stylebox_override("panel", sb)
		slot.custom_minimum_size = Vector2(side, side)
		slot.size_flags_vertical = Control.SIZE_SHRINK_END
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: TextureRect = UIKit.tex_rect(String(cfg["texture"]), side - 12)
		slot.add_child(ic)
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", -6)
		col.alignment = BoxContainer.ALIGNMENT_END
		col.size_flags_vertical = Control.SIZE_SHRINK_END
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if now:
			col.add_child(UIKit.label("NEXT", 18, Color("#ffd23a"), 6))
		col.add_child(slot)
		_ammo_row.add_child(col)
		if now and not first_build:
			UIFx.pop_in(col)


func set_destruction(destroyed: int, total: int) -> void:
	_destruction.text = "%d%%" % int(round(100.0 * destroyed / maxf(1.0, float(total))))


func set_objective(guards_left: int, guards_total: int, rescued: int, captive_total: int) -> void:
	if captive_total > 0:
		var t: String = "%d/%d · %d guard%s" % [rescued, captive_total, guards_left, "" if guards_left == 1 else "s"]
		if t.length() != _objective.text.length():
			_fit_title.call_deferred()
		_objective.text = t
	else:
		_objective.text = "%d / %d" % [guards_left, guards_total]
	_objective.add_theme_color_override("font_color", Color("#8dff78") if guards_left == 0 and rescued >= captive_total else Color.WHITE)


func set_score(s: int, live_stars: int) -> void:
	_score.text = fmt(s)
	for i: int in 3:
		_stars[i].texture = Art.tex("star_full" if i < live_stars else "star_empty")
	if live_stars > _last_stars:
		var st: TextureRect = _stars[live_stars - 1]
		st.pivot_offset = st.custom_minimum_size / 2.0
		st.scale = Vector2.ONE * 1.8
		st.create_tween().tween_property(st, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sound.play("star", 0.7, 1.0 + 0.1 * live_stars)
	_last_stars = live_stars


## Big wooden sign that drops in at the start of a level.
func banner(title: String, sub: String) -> void:
	var c: CenterContainer = CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: PanelContainer = UIKit.wood_sign()
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label(title, 30, Color("#ffd23a"), 8))
	v.add_child(UIKit.label(sub, 52, Color.WHITE, 12))
	plate.add_child(v)
	c.add_child(plate)
	_root.add_child(c)
	c.modulate.a = 0.0
	c.position.y = -120
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "position:y", -40.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.3)
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)


func hint(text: String, seconds: float = 4.0) -> void:
	if text.is_empty():
		return
	_hint.text = text
	var tw: Tween = create_tween()
	tw.tween_property(_hint, "modulate:a", 1.0, 0.3)
	tw.tween_interval(seconds)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.5)


static func fmt(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _open_popup() -> VBoxContainer:
	close_popup()
	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(UIKit.dim())
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(center)
	var p: PanelContainer = UIKit.panel()
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	_root.add_child(_popup)
	p.pivot_offset = p.custom_minimum_size / 2.0
	p.scale = Vector2.ONE * 0.6
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v


func close_popup() -> void:
	if _popup:
		Sound.play("popup_close", 0.6)
		_popup.queue_free()
		_popup = null


## Pause: title, the level's goal, Resume, then Map / Restart / Settings and separate music and SFX
## toggles (docs/UI_DESIGN.md "Pause").
func show_pause() -> void:
	if level.is_finished():
		return
	get_tree().paused = true
	Sound.play("popup_open", 0.7)
	var v: VBoxContainer = _open_popup()
	v.add_child(UIKit.label("PAUSED", 60, Color("#ffd23a"), 12))
	var title: String = "Level %d · %s" % [level.level_id, String(level.data.get("name", ""))] if level.level_id <= Data.CHALLENGE_BASE else String(level.data.get("name", ""))
	v.add_child(UIKit.label(title, 28, UIKit.TEXT_DARK, 0))
	var goal: String = String(level.data.get("strategy", ""))
	if not goal.is_empty():
		var g: Label = UIKit.label(goal, 20, UIKit.TEXT_DARK, 0, false)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.custom_minimum_size.x = 500
		v.add_child(g)
	var resume: Button = UIKit.button("RESUME", "green", 40, Vector2(320, 86))
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		get_tree().paused = false
		close_popup())
	UIFx.press_juice(resume)
	v.add_child(resume)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var mp: Button = UIKit.icon_button("icon_levels", "blue", 80)
	mp.pressed.connect(func() -> void: Game.goto_back_from(level.level_id))
	var rs: Button = UIKit.icon_button("icon_restart", "orange", 80)
	rs.pressed.connect(func() -> void: level.restart())
	var st: Button = UIKit.icon_button("icon_settings", "dark", 80)
	st.pressed.connect(func() -> void: SettingsPopup.open(self).closed.connect(show_pause))
	var mu: Button = UIKit.icon_button("icon_music", "blue" if bool(Save.data["music"]) else "dark", 80)
	mu.pressed.connect(func() -> void: _toggle_audio("music"))
	var snd: Button = UIKit.icon_button("icon_sound", "blue" if bool(Save.data["sfx"]) else "dark", 80)
	snd.pressed.connect(func() -> void: _toggle_audio("sfx"))
	for b: Button in [mp, rs, st, mu, snd]:
		UIFx.press_juice(b)
		row.add_child(b)
	v.add_child(row)


func _toggle_audio(key: String) -> void:
	Save.data[key] = not bool(Save.data[key])
	Save.write()
	Sound.apply_settings()
	Sound.play("switch_click")
	show_pause()


func show_result(won: bool, stars: int, score: int, earned: Dictionary, has_next: bool, reason: String = "", info: Dictionary = {}) -> void:
	var v: VBoxContainer = _open_popup()
	v.add_child(UIKit.label("FORTRESS SMASHED!" if won else "LEVEL FAILED!", 52, Color("#ffd23a") if won else Color("#ff8a7a"), 12))
	if not won and not reason.is_empty():
		v.add_child(UIKit.label(reason, 28, UIKit.TEXT_DARK, 0, false))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = 120
	v.add_child(row)
	var star_nodes: Array[TextureRect] = []
	for i: int in 3:
		var holder: Control = Control.new()
		holder.custom_minimum_size = Vector2(110, 110 if i != 1 else 120)
		holder.add_child(UIKit.tex_rect("star_empty", 100 if i != 1 else 118))
		var f: TextureRect = UIKit.tex_rect("star_full", 100 if i != 1 else 118)
		f.pivot_offset = f.custom_minimum_size / 2.0
		f.scale = Vector2.ZERO
		holder.add_child(f)
		row.add_child(holder)
		star_nodes.append(f)
	var score_l: Label = UIKit.label("Score  0", 38, UIKit.TEXT_DARK, 0)
	v.add_child(score_l)
	if won and not info.is_empty():
		v.add_child(_breakdown(info))
	# Wallet top right: shows the totals from before this win, then the earned currency flies in.
	var wallet_box: PanelContainer = PanelContainer.new()
	wallet_box.add_theme_stylebox_override("panel", MetaFrame.card_box(Color("#2a180c"), Color("#c8a060")))
	UIKit.place(wallet_box, Vector2(1, 0), Vector2(-500, 8), Vector2(486, 72))
	var wallet: CurrencyBar = CurrencyBar.new(["coins", "gems", "blueprints"], false)
	wallet_box.add_child(wallet)
	_popup.add_child(wallet_box)
	var cr: HBoxContainer = HBoxContainer.new()
	if not earned.is_empty():
		cr.alignment = BoxContainer.ALIGNMENT_CENTER
		cr.add_theme_constant_override("separation", 10)
		for k: String in ["coins", "gems", "blueprints"]:
			if int(earned.get(k, 0)) > 0:
				wallet.show_amount(k, Save.amount(k) - int(earned[k]), false)
				cr.add_child(UIKit.tex_rect(UIKit.CURRENCY_ICON[k], 40))
				cr.add_child(UIKit.label("+%d" % int(earned[k]), 34, UIKit.CURRENCY_COLOR[k], 0))
		v.add_child(cr)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	var mp: Button = UIKit.icon_button("icon_levels", "blue", 84)
	mp.pressed.connect(func() -> void:
		Ads.maybe_show_interstitial(level.level_id)
		Game.goto_back_from(level.level_id))
	var rs: Button = UIKit.icon_button("icon_restart", "orange", 84)
	rs.pressed.connect(func() -> void:
		Ads.maybe_show_interstitial(level.level_id)
		level.restart())
	btns.add_child(mp)
	btns.add_child(rs)
	if bool(info.get("replay", false)):
		var rp: Button = UIKit.icon_button("icon_replay", "blue", 84)
		rp.pressed.connect(start_replay)
		btns.add_child(rp)
	if won and has_next:
		var nx: Button = UIKit.button("NEXT", "green", 40, Vector2(200, 84))
		nx.pressed.connect(func() -> void:
			Ads.maybe_show_interstitial(level.level_id)
			Game.goto_level_entry(level.level_id + 1))
		btns.add_child(nx)
	v.add_child(btns)
	_celebrate_result(won, stars, score, earned, info, star_nodes, score_l, cr, wallet)


## Results juice (docs/UI_DESIGN.md "Juice"): stars slam in one by one with a dust puff and a rising
## note, the score rolls up, NEW BEST stamps on, then the earned currency flies into the wallet.
func _celebrate_result(won: bool, stars: int, score: int, earned: Dictionary, info: Dictionary,
		star_nodes: Array[TextureRect], score_l: Label, cr: HBoxContainer, wallet: CurrencyBar) -> void:
	var step: float = Data.bf("ui_fx", "star_slam_s")
	var tw: Tween = create_tween()
	tw.tween_interval(0.35)
	for i: int in stars:
		var f: TextureRect = star_nodes[i]
		tw.tween_callback(func() -> void:
			f.rotation = deg_to_rad(-25.0)
			f.scale = Vector2.ONE * 2.4
			f.modulate.a = 0.0
			Sound.play("star", 1.0, 1.0 + i * 0.12))
		tw.tween_property(f, "scale", Vector2.ONE, step).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(f, "rotation", 0.0, step)
		tw.parallel().tween_property(f, "modulate:a", 1.0, step * 0.4)
		tw.tween_callback(func() -> void:
			var c: Vector2 = f.get_global_rect().get_center()
			UIFx.rays(_popup, c - _popup.get_global_rect().position, 220.0, 0.6).modulate.a = 0.55
			_dust(c)
			Sound.play("slam", 0.45, 1.2 + i * 0.1)
			Game.haptic())
	tw.tween_callback(func() -> void: UIFx.count_up(score_l, 0, score, -1.0, "Score  "))
	tw.tween_interval(Data.bf("ui_fx", "count_up_s"))
	if bool(info.get("new_best", false)):
		tw.tween_callback(func() -> void:
			UIFx.stamp(_popup, score_l.get_global_rect().get_center() + Vector2(220, -10), "NEW BEST!", Color("#ffd23a")))
		tw.tween_interval(0.3)
	if won:
		tw.tween_callback(func() -> void:
			var from: Vector2 = cr.get_global_rect().get_center() if cr.is_inside_tree() else get_viewport().get_visible_rect().get_center()
			for k: String in ["coins", "gems", "blueprints"]:
				if int(earned.get(k, 0)) > 0:
					UIFx.fly_reward(from, k, int(earned[k]), wallet, false)
			if stars == 3:
				UIFx.confetti(get_viewport().get_visible_rect().get_center()))


## Puff of dust when a star lands (screen-space).
func _dust(at: Vector2) -> void:
	for j: int in 8:
		var d: TextureRect = UIKit.tex_rect("puff", 34)
		d.modulate = Color(1, 0.95, 0.8, 0.85)
		d.pivot_offset = d.custom_minimum_size / 2.0
		d.position = at - d.pivot_offset - _popup.get_global_rect().position
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_popup.add_child(d)
		var dir: Vector2 = Vector2.from_angle(TAU * j / 8.0 + randf() * 0.4)
		var t: Tween = d.create_tween()
		t.tween_property(d, "position", d.position + dir * randf_range(50, 80), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.parallel().tween_property(d, "scale", Vector2.ONE * 1.6, 0.45)
		t.parallel().tween_property(d, "modulate:a", 0.0, 0.45)
		t.tween_callback(d.queue_free)


## REPLAY on the result panel: hide the panel and the HUD, play the best chain, then show them again.
func start_replay() -> void:
	if _popup == null:
		return
	_root.visible = false
	if level.play_best_replay():
		level.replay.finished.connect(func() -> void: _root.visible = true, CONNECT_ONE_SHOT)
	else:
		_root.visible = true


## Score lines on the result panel: [label, value] rows, chain rows highlighted.
func _breakdown(info: Dictionary) -> Control:
	var g: GridContainer = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	g.add_theme_constant_override("v_separation", -2)
	var rows: Array = (info.get("mode_rows", []) as Array).duplicate()
	rows.append_array([
		["Blocks smashed", str(int(info.get("blocks", 0)))],
		["Guards defeated", str(int(info.get("archers", 0)))],
		["Heroes saved", "+" + fmt(int(info.get("unused_pts", 0)))],
		["Best chain", "%d  (x%.2f)" % [int(info.get("best_chain", 0)), float(info.get("best_mult", 1.0))]],
		["Chain bonus", "+" + fmt(int(info.get("chain_bonus", 0)))],
	])
	for r: Array in rows:
		var hot: bool = String(r[0]).begins_with("Chain") or String(r[0]).begins_with("Best")
		var c: Color = Color("#b4500a") if hot else UIKit.TEXT_DARK
		var a: Label = UIKit.label(String(r[0]), 24, c, 0, false)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var b: Label = UIKit.label(String(r[1]), 24, c, 0)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(a)
		g.add_child(b)
	var cc: CenterContainer = CenterContainer.new()
	cc.add_child(g)
	return cc


# ------------------------------------------------------------------------------------ chain counter
func _build_chain() -> void:
	_chain_box = UIKit.slate()
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(UIKit.tex_rect("icon_chain", 40))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", -8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain_n = UIKit.label("CHAIN 0", 24, Color("#ffd23a"), 5)
	_chain_mult = UIKit.label("x1.0", 20, Color.WHITE, 4)
	v.add_child(_chain_n)
	v.add_child(_chain_mult)
	h.add_child(v)
	_chain_box.add_child(h)
	UIKit.place(_chain_box, Vector2(1, 0), Vector2(-214, 136), Vector2(200, 64))
	_chain_box.pivot_offset = Vector2(100, 32)
	_chain_box.visible = false
	_root.add_child(_chain_box)


## Chain counter: shown from `chain.show_at` links; grows and warms up with the chain.
func set_chain(n: int, mult: float) -> void:
	if _chain_box == null:
		return
	if n < int(Data.b("chain", "show_at")):
		if _chain_box.visible and n == 0:
			var tw: Tween = _chain_box.create_tween()
			tw.tween_property(_chain_box, "modulate:a", 0.0, 0.35)
			tw.tween_callback(func() -> void:
				_chain_box.visible = false
				_chain_box.modulate.a = 1.0)
		_chain_shown = n
		return
	_chain_box.visible = true
	_chain_box.modulate.a = 1.0
	_chain_n.text = "CHAIN %d" % n
	_chain_mult.text = "x%.2f" % mult
	var heat: float = clampf(float(n) / 20.0, 0.0, 1.0)
	_chain_n.add_theme_color_override("font_color", Color("#ffd23a").lerp(Color("#ff5a2a"), heat))
	if n > _chain_shown:
		_chain_box.scale = Vector2.ONE * (1.25 + 0.15 * heat)
		_chain_box.create_tween().tween_property(_chain_box, "scale", Vector2.ONE * (1.0 + 0.12 * heat), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chain_shown = n


## Milestone: the chip flashes white and shakes (the words float in the world, see Level).
func chain_callout(_text: String) -> void:
	if _chain_box == null:
		return
	_chain_box.modulate = Color(2.0, 2.0, 2.0)
	var tw: Tween = _chain_box.create_tween()
	tw.tween_property(_chain_box, "modulate", Color.WHITE, 0.4)
	tw.parallel().tween_property(_chain_box, "rotation", 0.08, 0.06)
	tw.tween_property(_chain_box, "rotation", -0.06, 0.08)
	tw.tween_property(_chain_box, "rotation", 0.0, 0.08)


# ------------------------------------------------------------------------------------ wind + boss
func _build_wind() -> void:
	var p: PanelContainer = UIKit.slate()
	var h: HBoxContainer = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wind_icon = UIKit.tex_rect("icon_wind", 34)
	_wind_icon.pivot_offset = Vector2(20, 17)
	h.add_child(_wind_icon)
	_wind_label = UIKit.label("CALM", 20, Color.WHITE, 5)
	h.add_child(_wind_label)
	p.add_child(h)
	UIKit.place(p, Vector2(0, 0), Vector2(16, 96), Vector2(150, 50))
	_root.add_child(p)
	_wind_box = p


## frac in -1..1 (sign = direction, + toward the fortress).
func set_wind(frac: float) -> void:
	if _wind_box == null:
		return
	var strong: bool = absf(frac) > 0.15
	_wind_icon.flip_h = frac < 0.0
	_wind_icon.scale = Vector2.ONE * (0.7 + 0.5 * absf(frac))
	_wind_icon.modulate = Color(1, 1, 1, 0.4 + 0.6 * absf(frac))
	_wind_label.text = ("GUST " + ("→" if frac > 0.0 else "←")) if strong else "CALM"
	_wind_label.add_theme_color_override("font_color", Color("#9fe6ff") if strong else Color.WHITE)


func _build_boss_bar() -> void:
	_boss_w = Data.bf("boss", "bar_width")
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UIKit.tex_rect("boss_crown", 30))
	row.add_child(UIKit.label(level.boss.boss_name, 24, Color("#ffd23a"), 7))
	for i: int in level.data.get("boss_unit", {}).get("phases", []).size():
		var pip: TextureRect = UIKit.tex_rect("star_full", 22)
		row.add_child(pip)
		_boss_pips.append(pip)
	box.add_child(row)
	var back: ColorRect = ColorRect.new()
	back.color = Color(0.1, 0.05, 0.05, 0.8)
	back.custom_minimum_size = Vector2(_boss_w, 18)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color("#e0302a")
	_boss_fill.size = Vector2(_boss_w - 4, 14)
	_boss_fill.position = Vector2(2, 2)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_boss_fill)
	box.add_child(back)
	if level.rig and not level.rig.status().is_empty():
		_status_row = HBoxContainer.new()
		_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_status_row.add_theme_constant_override("separation", 14)
		box.add_child(_status_row)
		set_boss_status(level.rig.status())
	UIKit.place(box, Vector2(0.5, 0), Vector2(-_boss_w * 0.5, 96), Vector2(_boss_w, 60))
	_root.add_child(box)
	_boss_box = box


func set_boss(frac: float, phase: int) -> void:
	if _boss_box == null:
		return
	_boss_fill.create_tween().tween_property(_boss_fill, "size:x", (_boss_w - 4) * frac, 0.25)
	for i: int in _boss_pips.size():
		_boss_pips[i].modulate = Color(0.3, 0.3, 0.3, 0.7) if i < phase else Color.WHITE


## Boss defences: kind -> [left, total]. A chip per kind (icon + count), greyed and struck when 0.
func set_boss_status(st: Dictionary) -> void:
	if _status_row == null:
		return
	for k: String in st:
		var left: int = int(st[k][0])
		var chip: Dictionary = _status.get(k, {})
		if chip.is_empty():
			var p: PanelContainer = UIKit.chip()
			var h: HBoxContainer = HBoxContainer.new()
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icon: TextureRect = UIKit.tex_rect("status_" + k, 30)
			h.add_child(icon)
			var l: Label = UIKit.label("", 20, Color.WHITE, 5)
			h.add_child(l)
			p.add_child(h)
			_status_row.add_child(p)
			chip = {"panel": p, "icon": icon, "label": l, "left": -1}
			_status[k] = chip
		var lab: Label = chip["label"]
		lab.text = "%d/%d" % [left, int(st[k][1])] if left > 0 else "✓"
		var pan: PanelContainer = chip["panel"]
		pan.modulate = Color.WHITE if left > 0 else Color(0.6, 1.0, 0.6, 0.75)
		if int(chip["left"]) >= 0 and left != int(chip["left"]):
			UIFx.pop(pan, 1.35)
		chip["left"] = left


func boss_callout(text: String) -> void:
	if text.is_empty():
		return
	banner("BOSS", text)
