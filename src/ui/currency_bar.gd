class_name CurrencyBar
extends HBoxContainer
## Top-right wallet pills (coins, gems, blueprints) with a green "+" each. Counts roll up and the
## pill pops when the amount changes. UIFx.fly_reward() targets pill_center(kind).

signal plus_pressed(kind: String)

var _labels: Dictionary = {}
var _pills: Dictionary = {}
var _shown: Dictionary = {}
var _tweens: Dictionary = {}


func _init(kinds: Array = ["coins", "gems", "blueprints"], with_plus: bool = true) -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k: String in kinds:
		var pill: PanelContainer = UIKit.chip()
		pill.mouse_filter = Control.MOUSE_FILTER_PASS
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UIKit.tex_rect(UIKit.CURRENCY_ICON[k], 40))
		var l: Label = UIKit.label(_fmt(Save.amount(k)), 28, Color("#fff2c8"), 8)
		l.custom_minimum_size.x = 74 if k == "coins" else 48
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
		if with_plus:
			var plus: Button = UIKit.button("+", "green", 26, Vector2(40, 40))
			plus.pressed.connect(func() -> void: plus_pressed.emit(k))
			h.add_child(plus)
		pill.add_child(h)
		add_child(pill)
		_labels[k] = l
		_pills[k] = pill
		_shown[k] = Save.amount(k)
	Events.currency_changed.connect(_on_changed)


func pill_center(kind: String) -> Vector2:
	var p: Control = _pills.get(kind, self)
	return p.get_global_rect().get_center() - Vector2(p.size.x * 0.25, 0)


## Show `value` now (used by fly-in rewards that tick the counter coin by coin).
func show_amount(kind: String, value: int, pop: bool = true) -> void:
	if not _labels.has(kind):
		return
	_shown[kind] = value
	(_labels[kind] as Label).text = _fmt(value)
	if pop:
		bump(kind)


func bump(kind: String) -> void:
	var p: Control = _pills.get(kind)
	if p == null:
		return
	p.pivot_offset = p.size / 2.0
	if _tweens.has(kind) and (_tweens[kind] as Tween).is_valid():
		(_tweens[kind] as Tween).kill()
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE * Data.bf("ui_fx", "pill_pop"), 0.06)
	tw.tween_property(p, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens[kind] = tw


## Shake the pill red (not enough of this currency).
func deny(kind: String) -> void:
	var p: Control = _pills.get(kind)
	if p == null:
		return
	var l: Label = _labels[kind]
	l.modulate = Color(1, 0.4, 0.35)
	var x: float = p.position.x
	var tw: Tween = p.create_tween()
	for i: int in 4:
		tw.tween_property(p, "position:x", x + (8.0 if i % 2 == 0 else -8.0), 0.04)
	tw.tween_property(p, "position:x", x, 0.04)
	tw.tween_callback(func() -> void: l.modulate = Color.WHITE)


func _on_changed(kind: String, total: int) -> void:
	if not _labels.has(kind) or UIFx.flying(kind) > 0:
		return
	var from: int = int(_shown[kind])
	_shown[kind] = total
	var l: Label = _labels[kind]
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void: l.text = _fmt(int(v)), float(from), float(total),
		Data.bf("ui_fx", "count_up_s")).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	bump(kind)


static func _fmt(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
