class_name AchievementsScreen
extends MetaFrame
## Achievements: a scrolling list of plank rows (icon, name, description, progress bar, reward and
## CLAIM). Ready rows glow and sort first; claiming flies the reward into the bar.

var _list: VBoxContainer


func _title() -> String:
	return "Achievements"


func _icon() -> String:
	return "icon_achievements"


func _rail_items() -> Array:
	return RAIL_REWARDS


func _bg_realm() -> int:
	return 5


func _ready() -> void:
	rail_key = "achievements"
	super._ready()


func _build() -> void:
	var rank: PanelContainer = PanelContainer.new()
	rank.add_theme_stylebox_override("panel", card_box(Color("#2a3a6a"), Color("#ffd23a")))
	UIKit.place(rank, Vector2.ZERO, Vector2(282, 100), Vector2(0, 70))
	rank.anchor_right = 1.0
	rank.offset_right = -20
	body.add_child(rank)
	var rh: HBoxContainer = HBoxContainer.new()
	rh.add_theme_constant_override("separation", 14)
	rank.add_child(rh)
	rh.add_child(UIKit.tex_rect("icon_crown", 48))
	rh.add_child(UIKit.label("Kingdom rank: " + Progression.rank_name(), 28, Color.WHITE, 7))
	var pb: ProgressBar = _bar(Progression.rank_progress(), 320)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(pb)
	var done: int = 0
	for a: Dictionary in Progression.achievements():
		if Progression.ach_state(a) == "claimed":
			done += 1
	rh.add_child(UIKit.label("%d / %d done" % [done, Progression.achievements().size()], 24, Color("#ffe27a"), 6))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.place(scroll, Vector2.ZERO, Vector2(282, 182), Vector2(0, 0))
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_right = -20
	scroll.offset_bottom = -16
	body.add_child(scroll)
	DragScroll.attach(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_fill()


func _fill() -> void:
	for n: Node in _list.get_children():
		n.queue_free()
	var order: Dictionary = {"ready": 0, "locked": 1, "claimed": 2}
	var items: Array = Progression.achievements().duplicate()
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(order[Progression.ach_state(a)]) < int(order[Progression.ach_state(b)]))
	var i: int = 0
	var feats: Array = Feats.listed()
	if not feats.is_empty():
		var left_s: int = int(float(Feats.cfg().get("rotate_hours", 24)) * 3600.0)
		left_s = left_s - int(Time.get_unix_time_from_system()) % maxi(1, left_s)
		var head: Label = UIKit.label("LEVEL CHALLENGES  ·  new set in %dh %02dm" % [left_s / 3600, (left_s % 3600) / 60], 24, Color("#ffe27a"), 6)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(head)
		for f: Dictionary in feats:
			var fr: Control = _feat_row(f)
			_list.add_child(fr)
			UIFx.pop_in(fr, 0.03 * i)
			i += 1
		var head2: Label = UIKit.label("ACHIEVEMENTS", 24, Color("#ffe27a"), 6)
		head2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(head2)
	for a: Dictionary in items:
		var row: Control = _row(a)
		_list.add_child(row)
		UIFx.pop_in(row, 0.03 * i)
		i += 1


static func _bar(frac: float, w: float) -> ProgressBar:
	var pb: ProgressBar = ProgressBar.new()
	pb.custom_minimum_size = Vector2(w, 20)
	pb.max_value = 1.0
	pb.value = frac
	pb.show_percentage = false
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.06, 0.03)
	bg.set_corner_radius_all(8)
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = Color("#ffb52a")
	fg.set_corner_radius_all(8)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb


const FEAT_ICONS: Dictionary = {"max_shots": "icon_mode_oneshot", "no_ability": "icon_lock", "all_soldiers": "soldier_idle",
		"chain": "icon_challenges", "fast": "icon_mode_time"}


func _feat_row(f: Dictionary) -> Control:
	var st: String = Feats.state(f)
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#24345e"), Color("#ffd23a") if st == "done" else Color("#5a78c0")))
	p.custom_minimum_size.y = 90
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var icon: String = String(FEAT_ICONS.get(String(f["kind"]), "icon_achievements"))
	h.add_child(UIKit.tex_rect(icon if Art.exists(icon) else "icon_achievements", 60))
	var mid: VBoxContainer = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t: Label = UIKit.label("%s  ·  Level %d" % [String(f.get("name", "Challenge")), int(f["level"])], 26, Color.WHITE, 6)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(t)
	var d: Label = UIKit.label(Feats.describe(f), 18, Color("#dbe6ff"), 0, false)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(d)
	h.add_child(mid)
	h.add_child(reward_row(f["reward"], 30))
	var b: Button
	if st == "done":
		b = UIKit.button("CLAIM", "green", 26, Vector2(150, 62))
		UIFx.nudge(b)
		b.pressed.connect(func() -> void:
			var r: Dictionary = Feats.claim(String(f["id"]))
			if r.is_empty():
				return
			UIFx.celebrate(p, "CLAIMED!")
			var from: Vector2 = p.get_global_rect().get_center()
			var tw: Tween = create_tween()
			tw.tween_interval(0.3)
			tw.tween_callback(pay.bind(r, from))
			tw.tween_interval(0.9)
			tw.tween_callback(_fill))
	else:
		b = UIKit.button("GO", "orange", 26, Vector2(150, 62))
		b.pressed.connect(func() -> void:
			Sound.play("ui_tap")
			Game.goto_level_entry(int(f["level"])))
	UIFx.press_juice(b)
	h.add_child(b)
	return p


func _row(a: Dictionary) -> Control:
	var st: String = Progression.ach_state(a)
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#4a2e18") if st != "claimed" else Color("#2e2418"),
			Color("#ffd23a") if st == "ready" else Color("#7a5a30")))
	p.custom_minimum_size.y = 96
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(UIKit.tex_rect("icon_achievements" if st != "locked" else "star_empty", 64))
	var mid: VBoxContainer = VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t: Label = UIKit.label(String(a["name"]), 26, Color.WHITE, 6)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(t)
	var d: Label = UIKit.label(String(a["desc"]), 18, Color("#f4e2b8"), 0, false)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(d)
	var prog: int = Progression.ach_progress(a)
	var bh: HBoxContainer = HBoxContainer.new()
	bh.add_child(_bar(float(prog) / float(int(a["goal"])), 300))
	bh.add_child(UIKit.label("%s / %s" % [CurrencyBar._fmt(prog), CurrencyBar._fmt(int(a["goal"]))], 18, Color.WHITE, 4))
	mid.add_child(bh)
	h.add_child(mid)
	h.add_child(reward_row(a["reward"], 30))
	var b: Button
	match st:
		"ready":
			b = UIKit.button("CLAIM", "green", 26, Vector2(150, 62))
			UIFx.breathe(b)
			b.pressed.connect(func() -> void:
				var r: Dictionary = Progression.claim_achievement(String(a["id"]))
				if r.is_empty():
					return
				UIFx.celebrate(p, "CLAIMED!")
				var from: Vector2 = p.get_global_rect().get_center()
				var tw: Tween = create_tween()
				tw.tween_interval(0.3)
				tw.tween_callback(pay.bind(r, from))
				tw.tween_interval(0.9)
				tw.tween_callback(_fill))
		"claimed":
			b = UIKit.button("DONE", "dark", 22, Vector2(150, 62))
			b.disabled = true
		_:
			b = UIKit.button("LOCKED", "dark", 20, Vector2(150, 62))
			b.disabled = true
	UIFx.press_juice(b)
	h.add_child(b)
	return p
