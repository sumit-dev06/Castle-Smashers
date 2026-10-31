class_name EnergyUI
extends RefCounted
## Energy pill for the wallet bars, the "army is exhausted" popup and the paid level entry.
## Rules live in Energy (src/game/energy.gd); numbers in balance.json energy.


## Spends the bars for campaign level `id` and calls `go`, or opens the exhausted popup (which can
## top up the bars once with a rewarded ad and then calls `go`).
static func enter(id: int, go: Callable) -> void:
	if Energy.spend(id):
		go.call()
		return
	exhausted(id, go)


## Wallet pill: shield icon, "3/5" and the time to the next bar. Tap for the details.
static func pill() -> PanelContainer:
	var p: PanelContainer = UIKit.chip()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(UIKit.tex_rect("icon_energy", 42))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count: Label = UIKit.label("", 26, Color("#fff2c8"), 8)
	var timer: Label = UIKit.label("", 15, Color("#ffd98a"), 5)
	v.add_child(count)
	v.add_child(timer)
	h.add_child(v)
	p.add_child(h)
	var refresh: Callable = func() -> void:
		count.text = "%d/%d" % [Energy.bars(), Energy.max_bars()]
		var left: float = Energy.next_in_s()
		timer.text = "FULL" if left <= 0.0 else "+1 in " + Energy.fmt_time(left)
	refresh.call()
	var t: Timer = Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(refresh)
	p.add_child(t)
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			Sound.play("ui_tap")
			exhausted(0, Callable()))
	p.tooltip_text = "Army energy"
	return p


## The popup. id > 0: the player tried to start that level without enough bars. id == 0: info only.
static func exhausted(id: int, go: Callable) -> void:
	var cfg: Dictionary = Energy.cfg()
	var need: int = Energy.cost(id) if id > 0 else 0
	var short: bool = id > 0 and Energy.bars() < need
	var layer: CanvasLayer = UIFx.overlay()
	layer.add_child(UIKit.dim())
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var p: PanelContainer = UIKit.panel()
	p.custom_minimum_size = Vector2(640, 0)
	center.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var title: Label = UIKit.label(String(cfg["exhausted_title"] if short else cfg["info_title"]), 44, Color("#ffd23a"), 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_tired_army(short))
	v.add_child(_bar_row(need))
	var body: Label = UIKit.body("", 23)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 580
	v.add_child(body)
	var refresh: Callable = func() -> void:
		var lines: PackedStringArray = PackedStringArray()
		if short:
			lines.append(String(cfg["needs_text"]) % [need, "" if need == 1 else "s"])
			lines.append(String(cfg["ready_text"]) % Energy.fmt_time(Energy.ready_in_s(need)))
		elif Energy.bars() >= Energy.max_bars():
			lines.append(String(cfg["full_text"]))
		else:
			lines.append(String(cfg["next_text"]) % Energy.fmt_time(Energy.next_in_s()))
			lines.append(String(cfg["how_text"]))
		body.text = "\n".join(lines)
	refresh.call()
	var t: Timer = Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(refresh)
	layer.add_child(t)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	if short and Energy.ad_allowed():
		var ad: Button = UIKit.button("  " + Hud.ad_label(String(cfg["ad_text"])), "green", 26, Vector2(360, 72))
		if not Ads.ads_removed():
			ad.icon = Art.tex("icon_video")
			ad.expand_icon = true
			ad.add_theme_constant_override("icon_max_width", 40)
		var on_reward: Callable = func(rid: String) -> void:
			if rid != "energy_refill" or not is_instance_valid(layer):
				return
			Analytics.event("rewarded_ad_watched", {"placement": "energy_refill", "reward_amount": need, "level_id": id})
			Energy.ad_refill_and_spend(id)
			layer.queue_free()
			go.call()
		Ads.rewarded_earned.connect(on_reward)
		ad.tree_exiting.connect(func() -> void: Ads.rewarded_earned.disconnect(on_reward))
		ad.pressed.connect(func() -> void:
			if not Ads.rewarded_ready():
				body.text = String(cfg["no_ad_text"])
				return
			Ads.show_rewarded("energy_refill"))
		UIFx.press_juice(ad)
		row.add_child(ad)
	elif short:
		var wait: Label = UIKit.body(String(cfg["ad_locked_text"]), 20, Color("#8a5a2a"))
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wait.custom_minimum_size.x = 560
		v.add_child(wait)
		v.move_child(wait, row.get_index())
	var ok: Button = UIKit.button("OK", "orange", 28, Vector2(160, 72))
	ok.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		layer.queue_free())
	UIFx.press_juice(ok)
	row.add_child(ok)
	p.pivot_offset = Vector2(320, 260)
	UIFx.pop_in(p)
	if short:
		Sound.play("lose", 0.35)
		# The title sags in like a tired sigh, then keeps a slow breathing wobble.
		title.pivot_offset = Vector2(300, 26)
		var tw: Tween = title.create_tween()
		tw.tween_property(title, "rotation", -0.05, 0.5).from(0.08).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			var loop: Tween = title.create_tween().set_loops()
			loop.tween_property(title, "scale", Vector2(1.03, 0.97), 0.9).set_trans(Tween.TRANS_SINE)
			loop.tween_property(title, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE))


## Three soldiers slumped over their spears, swaying, with "z" bubbles drifting up.
static func _tired_army(tired: bool) -> Control:
	var box: Control = Control.new()
	box.custom_minimum_size = Vector2(560, 150)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in 3:
		var s: TextureRect = UIKit.tex_rect("soldier_idle" if tired else "soldier_cheer", 120)
		s.position = Vector2(150 + i * 100, 20 + (i % 2) * 6)
		s.size = Vector2(110, 120)
		s.pivot_offset = Vector2(55, 120)
		s.modulate = Color(0.82, 0.82, 0.9) if tired else Color.WHITE
		box.add_child(s)
		var tw: Tween = s.create_tween().set_loops()
		var lean: float = 0.16 if tired else 0.05
		tw.tween_property(s, "rotation", lean, 1.3 + i * 0.2).set_trans(Tween.TRANS_SINE).set_delay(i * 0.25)
		tw.tween_property(s, "rotation", lean * 0.4, 1.3 + i * 0.2).set_trans(Tween.TRANS_SINE)
		if tired:
			var z: Label = UIKit.label("z", 26 + i * 4, Color("#cfe6ff"), 6)
			z.position = Vector2(225 + i * 100, 20)
			box.add_child(z)
			var zt: Tween = z.create_tween().set_loops()
			zt.tween_property(z, "position", Vector2(250 + i * 100, -18), 1.6).from(Vector2(222 + i * 100, 26)).set_delay(i * 0.5)
			zt.parallel().tween_property(z, "modulate:a", 0.0, 1.6).from(1.0)
	return box


## One shield per bar: lit ones are rested, grey ones are still resting; the ones the level needs
## are marked by a gold underline.
static func _bar_row(need: int) -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var have: int = Energy.bars()
	for i: int in Energy.max_bars():
		var c: VBoxContainer = VBoxContainer.new()
		c.add_theme_constant_override("separation", 2)
		var icon: TextureRect = UIKit.tex_rect("icon_energy" if i < have else "icon_energy_empty", 56)
		c.add_child(icon)
		var mark: ColorRect = ColorRect.new()
		mark.custom_minimum_size = Vector2(44, 5)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mark.color = Color("#ffc93a") if i < need else Color(0, 0, 0, 0)
		c.add_child(mark)
		h.add_child(c)
		if i >= have and i < need:
			icon.pivot_offset = Vector2(28, 28)
			var tw: Tween = icon.create_tween().set_loops()
			tw.tween_property(icon, "scale", Vector2.ONE * 1.12, 0.45).set_trans(Tween.TRANS_SINE)
			tw.tween_property(icon, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	return h
