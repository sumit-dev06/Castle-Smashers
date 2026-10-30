class_name GameCamera
extends Camera2D
## Shows the whole battlefield (catapult to fortress) like a diorama, ground at a fixed screen
## height. Zooms out smoothly when a projectile flies above the top of the view. Screen shake.

var left: float = -440.0
var right: float = 2000.0
## Highest point of the fortress (world y, < 0). The resting view zooms out so it stays on screen.
var content_top: float = 0.0
## Screen pixels at the top kept free for the HUD (level sign, counters, boss bar).
var hud_top: float = 100.0
## While true a Cinematic drives position and zoom directly; only shake runs here.
var cine: bool = false
var tracked: Array = []
var _shake: float = 0.0
var _frac: float = 0.8
## Chain-reaction focus: the view eases toward `focus` while `_focus_goal` is 1.
var focus: Vector2 = Vector2.ZERO
var _focus_goal: float = 0.0
var _focus_w: float = 0.0


func _ready() -> void:
	_frac = Data.bf("camera", "ground_screen_frac")
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	_apply(base_zoom(), 1.0)


func _view() -> Vector2:
	return get_viewport_rect().size


## Resting zoom. The fortress top must land below the HUD band. A tall fortress first lowers the
## ground line (up to max_ground_screen_frac, keeping the ammo tray clear) and only then zooms out.
func base_zoom() -> float:
	var r: Vector2 = fit(_view(), left, right, content_top, hud_top)
	_frac = r.y
	return r.x


## [zoom, ground screen frac] for a view size, world span and fortress top (pure, used by tests).
static func fit(view: Vector2, l: float, r: float, top: float, hud: float) -> Vector2:
	var base_frac: float = Data.bf("camera", "ground_screen_frac")
	var max_frac: float = Data.bf("camera", "max_ground_screen_frac")
	var z: float = view.x / (r - l)
	var frac: float = base_frac
	if top < 0.0:
		var need: float = (hud - top * z) / view.y
		if need <= max_frac:
			frac = maxf(base_frac, need)
		else:
			frac = max_frac
			z = (max_frac * view.y - hud) / -top
	return Vector2(clampf(z, Data.bf("camera", "min_zoom"), Data.bf("camera", "max_zoom")), frac)


func target_zoom() -> float:
	var z: float = base_zoom()
	var top: float = 0.0
	for n: Variant in tracked:
		if is_instance_valid(n) and not (n as Projectile).done:
			top = minf(top, (n as Node2D).global_position.y)
	if top < 0.0:
		var need: float = -top + Data.bf("camera", "top_margin_px")
		z = minf(z, _frac * _view().y / need)
	return maxf(z, Data.bf("camera", "min_zoom"))


func add_shake(amount: float) -> void:
	_shake = minf(Data.bf("camera", "shake_max_px"), _shake + amount)


## World point -> screen point (for UI placed over the world).
func world_to_screen(p: Vector2) -> Vector2:
	return get_canvas_transform() * p


func set_focus(p: Vector2, goal: float) -> void:
	focus = p if goal > 0.0 else focus
	_focus_goal = goal


func _apply(z: float, t: float) -> void:
	z *= 1.0 + _focus_w * Data.bf("chain", "cam_zoom")
	var nz: float = lerpf(zoom.x, z, t)
	zoom = Vector2(nz, nz)
	position.x = lerpf((left + right) / 2.0, focus.x, _focus_w * Data.bf("chain", "cam_pull"))
	position.y = -(_frac - 0.5) * _view().y / nz


## Resting gameplay view: [position, zoom].
func default_view() -> Array:
	var z: float = base_zoom()
	return [Vector2((left + right) / 2.0, -(_frac - 0.5) * _view().y / z), z]


## Camera position that puts world point p at the screen centre for zoom z.
func center_on(p: Vector2, _z: float) -> Vector2:
	return p


func _process(delta: float) -> void:
	_focus_w = move_toward(_focus_w, _focus_goal, Data.bf("chain", "cam_ease") * delta)
	if not cine:
		_apply(target_zoom(), 1.0 - exp(-Data.bf("camera", "smooth") * delta))
	if _shake > 0.1:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake / zoom.x
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-Data.bf("camera", "shake_decay") * delta))
	else:
		offset = Vector2.ZERO
