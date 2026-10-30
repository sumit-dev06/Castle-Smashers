class_name SettingsPopup
extends CanvasLayer
## Settings (docs/UI_DESIGN.md "Settings popup"): music + SFX toggles with volume sliders, haptics,
## reset tutorial, credits, privacy policy link and the version. Works while the tree is paused, so
## the pause menu opens it too.

signal closed

var _root: Control
var _panel: PanelContainer


static func open(parent: Node) -> SettingsPopup:
	var s: SettingsPopup = SettingsPopup.new()
	parent.add_child(s)
	return s


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = UIKit.dim()
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	_root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = UIKit.panel()
	_panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(_panel)
	_main()
	_panel.pivot_offset = Vector2(310, 260)
	UIFx.pop_in(_panel)
	Sound.play("popup_open")


func _clear() -> VBoxContainer:
	for n: Node in _panel.get_children():
		n.queue_free()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	return v


func _header(v: VBoxContainer, text: String) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_child(UIKit.tex_rect("icon_settings", 44))
	var t: Label = UIKit.label(text, 46, Color("#ffd23a"), 10)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var x: Button = UIKit.icon_button("icon_close", "red", 58)
	x.pressed.connect(close)
	h.add_child(x)
	v.add_child(h)


func _main() -> void:
	var v: VBoxContainer = _clear()
	_header(v, "Settings")
	_audio_row(v, "Music", "music", "music_volume", "icon_music")
	_audio_row(v, "Sound FX", "sfx", "sfx_volume", "icon_sound")
	_toggle_row(v, "Haptics", "haptics", "icon_check")
	var lang: HBoxContainer = _row(v, "Language", "icon_info")
	lang.add_child(UIKit.label("English", 26, Color("#ffe27a"), 6))
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var tut: Button = UIKit.button("Replay Tutorial", "blue", 22, Vector2(184, 58))
	tut.pressed.connect(func() -> void:
		Save.data["tutorial_done"] = false
		Save.write()
		UIFx.stamp(_root, tut.get_global_rect().get_center(), "DONE"))
	var cr: Button = UIKit.button("Credits", "orange", 22, Vector2(150, 58))
	cr.pressed.connect(_credits)
	var pv: Button = UIKit.button("Privacy", "dark", 22, Vector2(150, 58))
	pv.pressed.connect(func() -> void: OS.shell_open(String(Data.b("settings", "privacy_url"))))
	for b: Button in [tut, cr, pv]:
		UIFx.press_juice(b)
		h.add_child(b)
	var ver: Label = UIKit.label("Version " + String(ProjectSettings.get_setting("application/config/version", "")), 18, Color("#cdb48a"), 4, false)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ver)


func _row(v: VBoxContainer, text: String, icon: String) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var ic: TextureRect = UIKit.tex_rect(icon, 40)
	h.add_child(ic)
	var l: Label = UIKit.label(text, 28, Color.WHITE, 6)
	l.custom_minimum_size.x = 170
	h.add_child(l)
	v.add_child(h)
	return h


func _switch(on: bool) -> Button:
	var b: Button = UIKit.button("ON" if on else "OFF", "green" if on else "dark", 22, Vector2(96, 50))
	UIFx.press_juice(b)
	return b


func _toggle_row(v: VBoxContainer, text: String, key: String, icon: String) -> void:
	var h: HBoxContainer = _row(v, text, icon)
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var b: Button = _switch(bool(Save.data.get(key, true)))
	b.pressed.connect(func() -> void:
		Save.data[key] = not bool(Save.data.get(key, true))
		Save.write()
		Sound.apply_settings()
		if key == "haptics":
			Game.haptic()
		Sound.play("switch_click")
		_main())
	h.add_child(b)


func _audio_row(v: VBoxContainer, text: String, key: String, vol_key: String, icon: String) -> void:
	var h: HBoxContainer = _row(v, text, icon)
	var s: HSlider = HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = Data.bf("settings", "slider_step")
	s.value = float(Save.data.get(vol_key, 1.0))
	s.custom_minimum_size = Vector2(190, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.editable = bool(Save.data.get(key, true))
	s.value_changed.connect(func(x: float) -> void:
		Save.data[vol_key] = x
		Sound.apply_settings())
	s.drag_ended.connect(func(_c: bool) -> void:
		Save.write()
		Sound.play("switch_click"))
	h.add_child(s)
	var b: Button = _switch(bool(Save.data.get(key, true)))
	b.pressed.connect(func() -> void:
		Save.data[key] = not bool(Save.data.get(key, true))
		Save.write()
		Sound.apply_settings()
		Sound.play("switch_click")
		_main())
	h.add_child(b)


func _credits() -> void:
	var v: VBoxContainer = _clear()
	_header(v, "Credits")
	v.add_child(UIKit.label("CASTLE SMASHERS", 36, Color.WHITE, 8))
	for line: Variant in Data.b("settings", "credits"):
		var l: Label = UIKit.label(String(line), 20, Color("#ffe8c0"), 4, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 580
		v.add_child(l)
	var back: Button = UIKit.button("Back", "orange", 26, Vector2(180, 60))
	back.pressed.connect(_main)
	v.add_child(back)


func close() -> void:
	Sound.play("popup_close")
	closed.emit()
	queue_free()
