class_name DragScroll
extends Node
## Finger-drag scrolling for a ScrollContainer full of buttons and cards. Godot only scrolls a
## ScrollContainer when the drag reaches it, and the cards and buttons inside take the touch first,
## so on a phone the list never moved. This node reads the raw input instead: a press inside the
## container that moves past `ui.drag_scroll_px` scrolls it (with a short fling), cancels the button
## under the finger and swallows the release, so a drag never counts as a tap.
## Usage: DragScroll.attach(scroll)  (axis follows the container's enabled scroll mode).

var scroll: ScrollContainer
var _down: bool = false
var _dragging: bool = false
var _start: Vector2 = Vector2.ZERO
var _origin: float = 0.0
var _last: Vector2 = Vector2.ZERO
var _vel: float = 0.0
var _faking: bool = false


static func attach(sc: ScrollContainer) -> DragScroll:
	var d: DragScroll = DragScroll.new()
	d.scroll = sc
	sc.add_child(d)
	return d


func _horizontal() -> bool:
	return scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
			and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED


func _axis(v: Vector2) -> float:
	return v.x if _horizontal() else v.y


func _value() -> float:
	return float(scroll.scroll_horizontal if _horizontal() else scroll.scroll_vertical)


func _set_value(v: float) -> void:
	if _horizontal():
		scroll.scroll_horizontal = int(v)
	else:
		scroll.scroll_vertical = int(v)


func _input(event: InputEvent) -> void:
	if _faking or not is_instance_valid(scroll) or not scroll.is_visible_in_tree():
		return
	var pos: Vector2
	var pressed: bool
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion:
		_motion((event as InputEventMouseMotion).position)
		return
	else:
		return
	if pressed:
		if scroll.get_global_rect().has_point(pos):
			_down = true
			_dragging = false
			_start = pos
			_last = pos
			_origin = _value()
			_vel = 0.0
	elif _down:
		_down = false
		if _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()


func _motion(pos: Vector2) -> void:
	if not _down:
		return
	if not _dragging and absf(_axis(pos - _start)) > Data.bf("ui", "drag_scroll_px"):
		_dragging = true
		_cancel_press()
	if _dragging:
		_vel = _axis(_last - pos) / maxf(get_process_delta_time(), 0.001)
		_last = pos
		_set_value(_origin - _axis(pos - _start))


## Releases the button under the finger far off-screen, so it un-presses without firing.
func _cancel_press() -> void:
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(-10000, -10000)
	up.global_position = up.position
	_faking = true
	get_viewport().push_input(up)
	_faking = false


func _process(delta: float) -> void:
	if _down or absf(_vel) < 20.0:
		return
	_set_value(_value() + _vel * delta)
	_vel = lerpf(_vel, 0.0, 1.0 - exp(-Data.bf("ui", "drag_scroll_friction") * delta))
