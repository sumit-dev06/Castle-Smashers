class_name CloudPopup
extends CanvasLayer
## Shown on home when the Play Games cloud save and this phone have different progress
## (PlayServices.cloud_pending). The player picks one; closing it decides nothing and asks again
## next session. Nothing is uploaded until a choice is made.


static func open_if_pending(parent: Node) -> void:
	if PlayServices.cloud_pending.is_empty() or parent.has_node("CloudPopup"):
		return
	var p: CloudPopup = CloudPopup.new()
	p.name = "CloudPopup"
	parent.add_child(p)


func _ready() -> void:
	layer = 70
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UIKit.dim())
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel: PanelContainer = UIKit.panel()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UIKit.label("Cloud Save Found", 44, Color("#ffd23a"), 10))
	var t: Label = UIKit.body("Your Google Play cloud save has different progress from this phone. Which one do you want to keep?", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size.x = 580
	v.add_child(t)
	_choice(v, "This phone", PlayServices.cloud_summary(Save.data), "Keep this phone", "orange", func() -> void:
		PlayServices.cloud_keep_local())
	_choice(v, "Cloud save", PlayServices.cloud_summary(PlayServices.cloud_pending), "Load cloud save", "green", func() -> void:
		PlayServices.cloud_apply(PlayServices.cloud_pending))
	var later: Button = UIKit.button("Decide later", "dark", 20, Vector2(200, 50))
	later.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	later.pressed.connect(queue_free)
	v.add_child(later)
	UIFx.pop_in(panel)
	Sound.play("popup_open")


func _choice(v: VBoxContainer, title: String, summary: String, label: String, color: String, pick: Callable) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(title, 26, Color.WHITE, 6))
	var s: Label = UIKit.label(summary, 20, UIKit.TEXT_DARK, 0, false)
	col.add_child(s)
	h.add_child(col)
	var b: Button = UIKit.button(label, color, 20, Vector2(230, 56))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		Sound.play("ui_tap")
		queue_free()
		pick.call())
	UIFx.press_juice(b)
	h.add_child(b)
	v.add_child(h)
