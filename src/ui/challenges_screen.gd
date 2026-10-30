class_name ChallengesScreen
extends CanvasLayer
## Challenges: a card per challenge level (mode icon, name, rule, stars, best score), the daily
## challenge first and gold-trimmed with a countdown, and the Boss Rush card after level 50.
## Opens after level modes.challenges_unlock_level. See docs/UI_DESIGN.md "Challenges screen".

var _countdown: Label
var _cards: Array[Control] = []


func _ready() -> void:
	layer = 5
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var bg: TextureRect = TextureRect.new()
	var bg_name: String = Background.bg_name(3, 1)
	bg.texture = Art.tex(bg_name) if not bg_name.is_empty() else null
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.14, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var back: Button = UIKit.icon_button("icon_home", "orange", 68)
	UIKit.place(back, Vector2.ZERO, Vector2(18, 16), Vector2(68, 68))
	back.pressed.connect(Game.goto_menu)
	UIFx.press_juice(back)
	root.add_child(back)
	var sign: PanelContainer = UIKit.wood_sign()
	var sh: HBoxContainer = HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	sh.add_child(UIKit.tex_rect("icon_mode_siege", 44))
	sh.add_child(UIKit.label("CHALLENGES", 38, Color("#ffd23a"), 9))
	sign.add_child(sh)
	UIKit.place(sign, Vector2(0, 0), Vector2(100, 14), Vector2(360, 80))
	root.add_child(sign)
	var bar: CurrencyBar = CurrencyBar.new(["coins", "gems", "blueprints"], false)
	UIKit.place(bar, Vector2(1, 0), Vector2(-680, 22), Vector2(660, 56))
	root.add_child(bar)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.place(scroll, Vector2(0, 0.5), Vector2(24, -230), Vector2(0, 470))
	scroll.anchor_right = 1.0
	scroll.offset_right = -24
	root.add_child(scroll)
	DragScroll.attach(scroll)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	scroll.add_child(row)
	var daily: int = Save.daily_challenge_id()
	var list: Array = Data.challenge_list().duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) == daily and int(b["id"]) != daily)
	for c: Dictionary in list:
		var card: Control = _card(c, int(c["id"]) == daily)
		row.add_child(card)
		_cards.append(card)
	row.add_child(_rush_card())
	var special_open: bool = Save.special_pack_unlocked() or (OS.is_debug_build() and Game.args.has("preview-special"))
	if special_open:
		for special: Dictionary in Data.special_list():
			var special_card: Control = _card(special, false, true)
			row.add_child(special_card)
			_cards.append(special_card)
	else:
		var gate_card: Control = _special_gate_card()
		row.add_child(gate_card)
		_cards.append(gate_card)
	for i: int in _cards.size():
		UIFx.pop_in(_cards[i], 0.05 * i)
	if OS.is_debug_build() and Game.args.has("preview-special"):
		get_tree().create_timer(0.15).timeout.connect(func() -> void:
			scroll.scroll_horizontal = int(scroll.get_h_scroll_bar().max_value))
	var hint: Control = UIKit.info_pill("coin", "Daily challenge: +%d coins once a day" % int(Data.b("modes", "daily_coins")))
	UIKit.place(hint, Vector2(0.5, 1), Vector2(-260, -58), Vector2(520, 48))
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(hint)
	Sound.set_music("menu", "menu")
	Sound.set_surroundings(Sound.realm if not Sound.realm.is_empty() else "blossom", true)


func _card(c: Dictionary, daily: bool, special: bool = false) -> Control:
	var id: int = int(c["id"])
	var p: PanelContainer = UIKit.panel()
	p.custom_minimum_size = Vector2(250, 440)
	if daily:
		p.modulate = Color(1.12, 1.05, 0.85)
	elif special:
		p.modulate = Color(1.08, 0.96, 1.14)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if daily:
		v.add_child(UIKit.label("DAILY", 26, Color("#c46a0a"), 0))
		_countdown = UIKit.label("", 18, UIKit.TEXT_DARK, 0, false)
		v.add_child(_countdown)
	elif special:
		v.add_child(UIKit.label("MASTER SIEGE %d / %d" % [int(c.get("order", 1)), Data.special_list().size()], 21, Color("#7b3fb2"), 0))
	var icon: TextureRect = UIKit.tex_rect(String(ModeRules.ICONS.get(String(c["mode"]), "icon_mode_siege")), 92)
	v.add_child(icon)
	v.add_child(UIKit.label(String(c["name"]), 28, UIKit.TEXT_DARK, 0))
	v.add_child(UIKit.label(ModeRules.display_name(String(c["mode"])), 20, Color("#7a3a10"), 0, false))
	var rule: Label = UIKit.label(String(c["rule"]), 17, UIKit.TEXT_DARK, 0, false)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size = Vector2(220, 70)
	v.add_child(rule)
	var stars: HBoxContainer = HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	for i: int in 3:
		stars.add_child(UIKit.tex_rect("star_full" if i < Save.challenge_stars(id) else "star_empty", 32))
	v.add_child(stars)
	var best: int = Save.challenge_best(id)
	v.add_child(UIKit.label("Best " + Hud.fmt(best) if best > 0 else "Not played", 18, UIKit.TEXT_DARK, 0, false))
	var heroes: HBoxContainer = HBoxContainer.new()
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	for h: Variant in c.get("heroes", []):
		heroes.add_child(UIKit.tex_rect(String(Data.projectiles[String(h)]["texture"]), 30))
	v.add_child(heroes)
	var play: Button = UIKit.button("PLAY", "green", 30, Vector2(180, 64))
	play.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		Game.goto_level(id))
	UIFx.press_juice(play)
	if daily:
		UIFx.breathe(play)
	v.add_child(play)
	return p




func _special_gate_card() -> Control:
	var gate: int = int(Data.b("special_pack", "star_gate"))
	var p: PanelContainer = UIKit.panel()
	p.custom_minimum_size = Vector2(280, 440)
	p.modulate = Color(0.78, 0.74, 0.86)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UIKit.label("MASTER SIEGES", 29, Color("#7b3fb2"), 0))
	v.add_child(UIKit.tex_rect("icon_lock", 92))
	v.add_child(UIKit.label("10 HARD LEVELS", 23, UIKit.TEXT_DARK, 0))
	var rule: Label = UIKit.label("Mechanics are the only way through. Master every contraption.", 18, UIKit.TEXT_DARK, 0, false)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size = Vector2(240, 74)
	v.add_child(rule)
	v.add_child(UIKit.label("%d / %d CAMPAIGN STARS" % [Save.total_stars(), gate], 22, Color("#7a3a10"), 0))
	var progress: ProgressBar = ProgressBar.new()
	progress.custom_minimum_size = Vector2(220, 24)
	progress.max_value = gate
	progress.value = mini(Save.total_stars(), gate)
	progress.show_percentage = false
	v.add_child(progress)
	v.add_child(UIKit.label("Earn %d more stars" % maxi(0, gate - Save.total_stars()), 18, UIKit.TEXT_DARK, 0, false))
	return p
func _rush_card() -> Control:
	var p: PanelContainer = UIKit.panel()
	p.custom_minimum_size = Vector2(250, 440)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var unlocked: bool = Save.is_unlocked(int(Data.b("modes", "rush_unlock_level"))) and Save.stars(int(Data.b("modes", "rush_unlock_level"))) > 0
	v.add_child(UIKit.tex_rect("icon_mode_rush", 100))
	v.add_child(UIKit.label("Boss Rush", 30, UIKit.TEXT_DARK, 0))
	var rule: Label = UIKit.label("All five bosses back to back. Shared heroes, soldier HP carries over.", 17, UIKit.TEXT_DARK, 0, false)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size = Vector2(220, 80)
	v.add_child(rule)
	var best: float = float(Save.data.get("rush_best", 0.0))
	v.add_child(UIKit.label("Best %.1f s" % best if best > 0.0 else "No run yet", 18, UIKit.TEXT_DARK, 0, false))
	if unlocked:
		var play: Button = UIKit.button("START", "orange", 30, Vector2(180, 64))
		play.pressed.connect(Game.start_rush)
		UIFx.press_juice(play)
		v.add_child(play)
	else:
		v.add_child(UIKit.tex_rect("icon_lock", 44))
		v.add_child(UIKit.label("Beat level %d" % int(Data.b("modes", "rush_unlock_level")), 20, Color("#7a3a10"), 0, false))
		p.modulate = Color(0.75, 0.75, 0.8)
	_cards.append(p)
	return p


func _process(_d: float) -> void:
	if _countdown == null:
		return
	var now: Dictionary = Time.get_time_dict_from_system()
	var left: int = 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
	_countdown.text = ("Paid today" if Save.daily_paid_today() else "New in") + " %02d:%02d:%02d" % [left / 3600, (left / 60) % 60, left % 60]
