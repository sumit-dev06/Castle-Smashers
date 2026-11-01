class_name UIKit
extends RefCounted
## Builds the chunky, beveled UI look in code (docs/ART_DIRECTION.md → UI).

const COLORS: Dictionary = {
	"green": [Color("#6fdc45"), Color("#2f9a28")],
	"orange": [Color("#ffb53a"), Color("#d4630c")],
	"blue": [Color("#4fa8ff"), Color("#2462c4")],
	"red": [Color("#ff6a5a"), Color("#b8302a")],
	"dark": [Color(0.12, 0.1, 0.2, 0.55), Color(0.05, 0.04, 0.1, 0.6)],
}
const TEXT_DARK: Color = Color("#3a1f0c")
const CURRENCY_ICON: Dictionary = {"coins": "coin", "gems": "gem"}
const CURRENCY_COLOR: Dictionary = {"coins": Color("#c4780a"), "gems": Color("#9a3ad8")}

static var _title: Font
static var _body: Font


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/lilita-one-latin.woff2")
	return _title


static func body_font() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/fredoka-latin.woff2")
	return _body


static func _box(top: Color, bottom: Color, radius: int, bevel: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = top
	sb.border_color = bottom
	sb.border_width_bottom = bevel
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6 + bevel
	sb.anti_aliasing_size = 1.2
	return sb


static func button(text: String, color: String = "green", font_size: int = 34, min_size: Vector2 = Vector2(200, 78)) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	var c: Array = COLORS[color]
	var n: StyleBoxFlat = _box(c[0], c[1], 24, 8)
	var h: StyleBoxFlat = _box((c[0] as Color).lightened(0.12), c[1], 24, 8)
	var p: StyleBoxFlat = _box((c[0] as Color).darkened(0.08), c[1], 24, 3)
	p.content_margin_top = 11
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", font_size)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_outline_color", (c[1] as Color).darkened(0.35))
	b.add_theme_constant_override("outline_size", 8)
	b.pressed.connect(func() -> void: Sound.play("ui_tap"))
	return b


static func icon_button(icon: String, color: String = "orange", side: int = 76) -> Button:
	var b: Button = button("", color, 10, Vector2(side, side))
	b.icon = Art.tex(icon)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(side * 0.5))
	for st: String in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st) as StyleBoxFlat
		sb.set_corner_radius_all(side / 2)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
	return b


## Smallest text size in design px (1280x720). Phones show the design at about 1.5x; below this,
## text turned soft and hard to read on a 6-inch screen.
const MIN_FONT: int = 18


static func label(text: String, size: int = 32, color: Color = Color.WHITE, outline: int = 10, title: bool = true) -> Label:
	size = maxi(size, MIN_FONT)
	outline = mini(outline, maxi(2, size / 3)) if outline > 0 else 0  # thick outlines on small text smear it
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font() if title else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", TEXT_DARK)
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		l.add_theme_constant_override("shadow_offset_y", 4)
		l.add_theme_constant_override("shadow_offset_x", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Body copy for cream panels: dark brown on cream, no outline or shadow (outlined light text on a
## light panel blurs). Wraps; set custom_minimum_size.x for the width.
static func body(text: String, size: int = 22, color: Color = TEXT_DARK) -> Label:
	var l: Label = label(text, size, color, 0, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Dark rounded pill with an icon and a short line: footers and notes over a backdrop
## (instead of bare text floating on the art).
static func info_pill(icon: String, text: String, size: int = 22) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.03, 0.78)
	sb.border_color = Color("#d8a040")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 16
	sb.content_margin_right = 20
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not icon.is_empty():
		h.add_child(tex_rect(icon, size * 1.5))
	h.add_child(label(text, size, Color("#ffe27a"), 6))
	p.add_child(h)
	return p


## Cream panel with a wooden frame.
static func panel() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#fff4dc")
	sb.border_color = Color("#b8733a")
	sb.set_border_width_all(10)
	sb.border_width_bottom = 18
	sb.set_corner_radius_all(36)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 8)
	sb.set_content_margin_all(28)
	sb.anti_aliasing_size = 1.2
	p.add_theme_stylebox_override("panel", sb)
	return p


## Dark translucent pill for HUD counters.
static func chip() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.2, 0.45)
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 16
	sb.content_margin_right = 20
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func dim() -> ColorRect:
	var c: ColorRect = ColorRect.new()
	c.color = Color(0.05, 0.05, 0.15, 0.55)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func tex_rect(art: String, h: float) -> TextureRect:
	var t: TextureRect = TextureRect.new()
	t.texture = Art.tex(art)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sz: Vector2 = t.texture.get_size() if t.texture else Vector2.ONE
	t.custom_minimum_size = Vector2(h * sz.x / sz.y, h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func _nine(art: String, margin: int, pad: Vector4) -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = Art.tex(art)
	var m: int = margin * 2
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb


## Wooden plank sign (reference: level title sign).
static func wood_sign() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _nine("ui_sign", 22, Vector4(30, 8, 30, 14)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Dark slate panel with a brown edge (reference: Shots / Destruction panels).
static func slate() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _nine("ui_chip", 18, Vector4(14, 6, 18, 8)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Dark rounded speech bubble for tutorials.
static func dark_bubble() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.2, 0.88)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## "Stone Storm" wordmark with the castle emblem (reference: top-left logo).
static func logo(size: int = 40) -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tex_rect("logo_mark" if Art.has_ai("logo_mark") else "logo_castle", size * 1.7))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", -int(size * 0.45))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a: Label = label("Stone", size, Color("#ffcf3a"), int(size * 0.28))
	var b: Label = label("Storm", size, Color("#fff4dc"), int(size * 0.28))
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(a)
	v.add_child(b)
	h.add_child(v)
	return h


## Anchors `c` to a point of its parent (anchor 0..1 per axis) with an explicit pixel rect.
static func place(c: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y
