class_name CampaignEnd
extends Node2D
## "What's next?" screen after the last campaign level (docs/UI_DESIGN.md "Campaign end").
## The road of conquered realms ends at a misty, locked ninth realm that Master Orin is still
## forging: new levels are coming. Texts and timings in data/balance.json -> campaign_end.

var _camera: Camera2D
var _t: float = 0.0
var _fog: Array[TextureRect] = []
var _mystery: Control


func cfg() -> Dictionary:
	return Data.balance.get("campaign_end", {})


func _ready() -> void:
	Save.mark_seen("campaign_end")
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * 0.8
	_camera.position = Vector2(0, -(Data.bf("camera", "menu_ground_screen_frac") - 0.5) * 720.0 / 0.8)
	add_child(_camera)
	var bg: Background = Background.new()
	bg.camera = _camera
	bg.realm = int(Data.level(Data.level_count()).get("realm", 1))
	bg.blurred = true
	bg.ground_frac = Data.bf("camera", "menu_ground_screen_frac")
	add_child(bg)
	var ui: CanvasLayer = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var shade: ColorRect = UIKit.dim()
	shade.color = Color(0.05, 0.03, 0.1, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	_build(root)
	Sound.set_music("menu", "menu")
	Sound.stinger("win")
	UIFx.confetti.call_deferred(get_viewport().get_visible_rect().size * Vector2(0.5, 0.25))


func _build(root: Control) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var p: PanelContainer = UIKit.panel()
	var w: float = minf(view.x * 0.8, 1180.0)
	var h: float = view.y * 0.86
	p.position = Vector2((view.x - w) * 0.5, (view.y - h) * 0.5)
	p.size = Vector2(w, h)
	root.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var title: Label = UIKit.label(String(cfg().get("title", "ALL REALMS CONQUERED!")), 50, Color("#ffcf3a"), 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var stars: int = Save.total_stars()
	var sub: Label = UIKit.body(String(cfg().get("subtitle", "")).format({
		"levels": Data.level_count(), "stars": stars, "max": Data.level_count() * 3}), 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_road())
	# Master Orin's promise, in a speech bubble next to him.
	var talk: HBoxContainer = HBoxContainer.new()
	talk.alignment = BoxContainer.ALIGNMENT_CENTER
	talk.add_theme_constant_override("separation", 14)
	talk.add_child(UIKit.tex_rect("wizard_idle", 112))
	var bubble: PanelContainer = UIKit.dark_bubble()
	var say: Label = UIKit.body(String(cfg().get("orin_says", "")), 22, Color.WHITE)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.custom_minimum_size = Vector2(minf(w - 260.0, 720.0), 0)
	bubble.add_child(say)
	talk.add_child(bubble)
	v.add_child(talk)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	var goals: Array = [
		["Collect every ★", "orange", func() -> void: Game.goto_map()],
		["Special Missions", "blue", func() -> void: Game.goto_challenges()],
		["Home", "green", func() -> void: Game.goto_menu()],
	]
	for g: Array in goals:
		var b: Button = UIKit.button(String(g[0]), String(g[1]), 24, Vector2(230, 66))
		var go: Callable = g[2]
		b.pressed.connect(func() -> void:
			Sound.play("ui_tap")
			go.call())
		UIFx.press_juice(b)
		btns.add_child(b)
	v.add_child(btns)
	UIFx.pop_in(p)


## Eight conquered realm medallions in a row, then the misty locked ninth "being forged".
func _road() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	var realms: Array = Data.balance.get("realms", [])
	for i: int in realms.size():
		var r: Dictionary = realms[i]
		var cell: VBoxContainer = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var node: Control = Control.new()
		node.custom_minimum_size = Vector2(76, 76)
		var disc: TextureRect = UIKit.tex_rect("map_node_done", 72)
		node.add_child(disc)
		var tick: TextureRect = UIKit.tex_rect("icon_check", 34)
		tick.position = Vector2(20, 18)
		node.add_child(tick)
		cell.add_child(node)
		var name_l: Label = UIKit.label(String(r.get("name", "")), 12, Color("#5a3416"), 0, false)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.custom_minimum_size = Vector2(86, 0)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		cell.add_child(name_l)
		row.add_child(cell)
		# Each medallion lands in turn, like the road being walked again.
		node.pivot_offset = Vector2(36, 36)
		node.scale = Vector2.ZERO
		node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.3).set_delay(0.35 + i * 0.09) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		row.add_child(_dots())
	var cell9: VBoxContainer = VBoxContainer.new()
	_mystery = Control.new()
	_mystery.custom_minimum_size = Vector2(110, 96)
	var locked: TextureRect = UIKit.tex_rect("map_node_locked", 92)
	locked.modulate = Color(0.55, 0.5, 0.75)
	locked.position = Vector2(9, 2)
	_mystery.add_child(locked)
	var q: Label = UIKit.label("?", 54, Color("#ffcf3a"), 10)
	q.position = Vector2(38, 4)
	_mystery.add_child(q)
	var hammer: TextureRect = UIKit.tex_rect("icon_hammer", 40)
	hammer.position = Vector2(70, 52)
	hammer.pivot_offset = Vector2(8, 32)
	_mystery.add_child(hammer)
	# Orin's hammer keeps tapping: the realm is being built right now.
	var tap: Tween = hammer.create_tween().set_loops()
	tap.tween_property(hammer, "rotation_degrees", -28.0, 0.35).set_trans(Tween.TRANS_SINE)
	tap.tween_property(hammer, "rotation_degrees", 6.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tap.tween_interval(0.5)
	for k: int in 3:
		var fog: TextureRect = UIKit.tex_rect("cloud_%d" % (k % 2), 46)
		fog.modulate = Color(0.85, 0.85, 1.0, 0.75)
		fog.position = Vector2(-10 + k * 36, 56 + (k % 2) * 10)
		_mystery.add_child(fog)
		_fog.append(fog)
	cell9.add_child(_mystery)
	var soon: Label = UIKit.label(String(cfg().get("next_label", "Coming soon")), 16, Color("#7a3fb0"), 0)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell9.add_child(soon)
	row.add_child(cell9)
	return row


func _dots() -> Label:
	var d: Label = UIKit.label("··", 20, Color("#b8733a"), 0)
	d.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	d.custom_minimum_size = Vector2(0, 60)
	d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return d


func _process(delta: float) -> void:
	_t += delta
	_camera.position.x = sin(_t * 0.12) * 50.0
	for k: int in _fog.size():
		_fog[k].position.x = -10 + k * 36 + sin(_t * 0.8 + k * 1.7) * 8.0
	if _mystery:
		_mystery.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(_t * 2.0))
