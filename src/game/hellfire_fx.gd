class_name HellfireFX
extends Node
## The paid Hellfire strike as a short cinematic (all timings in balance.hellfire):
## 1. the HUD hides, black bars slide in, the sky turns blood red with a deep rumble and embers rise;
## 2. "HELLFIRE!" slams onto the screen;
## 3. one giant meteor opens (slow motion), then a barrage sweeps across the fort, one meteor per
##    block, each with a flame tail, glow, embers, shockwave and a scorch mark;
## 4. a white flash, every guard falls, the bars and tint clear, and the level is won.
## Level._hellfire_strike creates it; `done` fires when the level may finish.

signal done

var level: Level
var _cfg: Dictionary
var _layer: CanvasLayer
var _tint: ColorRect
var _flash: ColorRect
var _bars: Array[ColorRect] = []
var _embers: CPUParticles2D


func start(p_level: Level) -> void:
	level = p_level
	_cfg = Data.balance["hellfire"]
	_build_overlay()
	if level.hud:
		level.hud.visible = false
	Sound.play("hellfire_rumble", 0.9)
	level.camera.add_shake(float(_cfg["shake"]) * 0.4)
	var intro: float = float(_cfg["intro_s"])
	var tw: Tween = create_tween()
	tw.tween_property(_tint, "color:a", float(_cfg["tint_alpha"]), intro).set_trans(Tween.TRANS_SINE)
	_slide_bars(true)
	_after(intro * 0.3, _title)
	_after(intro, _barrage)


func _after(s: float, fn: Callable) -> void:
	get_tree().create_timer(s, false).timeout.connect(fn)


# ------------------------------------------------------------------------------------ overlay
func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 1  # over the world, under the HUD
	add_child(_layer)
	_tint = ColorRect.new()
	_tint.color = Color(String(_cfg["tint_color"]))
	_tint.color.a = 0.0
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tint)
	var bar_h: float = float(_cfg["bar_px"])
	for i: int in 2:
		var b: ColorRect = ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.anchor_right = 1.0
		if i == 1:
			b.anchor_top = 1.0
			b.anchor_bottom = 1.0
		# Hidden just off screen; _slide_bars moves both edges by bar_h.
		b.offset_top = -bar_h if i == 0 else 0.0
		b.offset_bottom = 0.0 if i == 0 else bar_h
		_bars.append(b)
		_layer.add_child(b)
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.95, 0.85, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)
	# Embers drifting up over the whole screen while the sky burns.
	_embers = _ember_emitter(80, 2.4, false)
	_embers.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, get_viewport().get_visible_rect().size.y + 20)
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(get_viewport().get_visible_rect().size.x * 0.6, 10)
	_embers.direction = Vector2(0.2, -1)
	_embers.initial_velocity_min = 60.0
	_embers.initial_velocity_max = 160.0
	_embers.gravity = Vector2(0, -20)
	_layer.add_child(_embers)
	_embers.emitting = true


## Letterbox bars in (show) or out.
func _slide_bars(show: bool) -> void:
	var h: float = float(_cfg["bar_px"])
	var tw: Tween = create_tween().set_parallel(true)
	for i: int in 2:
		var d: float = (h if i == 0 else -h) * (1.0 if show else -1.0)
		tw.tween_property(_bars[i], "offset_top", _bars[i].offset_top + d, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_bars[i], "offset_bottom", _bars[i].offset_bottom + d, 0.4).set_trans(Tween.TRANS_SINE)


func _ember_emitter(amount: int, life: float, one_shot: bool) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.texture = Art.tex("fx_glow")
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	ramp.set_color(1, Color(0.9, 0.15, 0.02, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.55, 0.12, 0.9))
	p.color_ramp = ramp
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	return p


func _title() -> void:
	Sound.play("boss_roar", 0.6, 0.7)
	var l: Label = UIKit.label(String(_cfg["title"]), 120, Color("#ffe066"), 18)
	l.add_theme_color_override("font_outline_color", Color("#4a0800"))
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.3, 0.0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 40)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_top = float(_cfg["bar_px"]) + 20.0
	l.offset_left = -500.0
	l.offset_right = 500.0
	l.offset_bottom = l.offset_top + 160.0
	l.pivot_offset = Vector2(500, 80)
	l.scale = Vector2.ONE * 1.8
	l.modulate.a = 0.0
	_layer.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.12)
	tw.tween_callback(func() -> void: level.camera.add_shake(8.0))
	tw.tween_interval(float(_cfg["title_hold_s"]))
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------------------------ meteors
func _barrage() -> void:
	var targets: Array[Block] = []
	for b: Block in level.blocks:
		if is_instance_valid(b) and not b.dead:
			targets.append(b)
	# Sweep across the fort from the front, with a little shuffle so it doesn't look mechanical.
	# Jitter is fixed per block before sorting: a random comparator breaks the sort.
	var key: Dictionary = {}
	for b: Block in targets:
		key[b] = b.global_position.x + randf_range(-60, 60)
	targets.sort_custom(func(a: Block, b: Block) -> bool: return float(key[a]) < float(key[b]))
	var fall: float = float(_cfg["fall_s"])
	var spread: float = float(_cfg["spread_s"])
	var first_gap: float = float(_cfg["first_gap_s"])
	if not targets.is_empty():
		# The opener: one giant meteor on the front of the fort, in slow motion.
		_meteor(targets[0], float(_cfg["opener_scale"]), fall * 1.4, true)
	for i: int in range(1, targets.size()):
		var delay: float = first_gap + spread * float(i - 1) / maxf(1.0, float(targets.size() - 1))
		var big: float = randf_range(0.8, 1.15) * float(_cfg["meteor_scale"])
		_after(delay, _meteor.bind(targets[i], big, fall, i % int(_cfg["incoming_every"]) == 0))
	var end_s: float = fall * 1.4 + first_gap + spread + fall
	_after(end_s, _finale)


func _meteor(b: Block, size_k: float, fall: float, loud: bool) -> void:
	if not is_instance_valid(b) or b.dead:
		return
	var to: Vector2 = b.global_position
	var from: Vector2 = to + Vector2(float(_cfg["from_dx"]), -float(_cfg["from_dy"])) * randf_range(0.9, 1.1)
	var dir: Vector2 = (to - from).normalized()
	var m: Node2D = Node2D.new()
	m.z_index = 12
	m.global_position = from
	level.world.add_child(m)
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow: Sprite2D = Art.sprite("fx_glow", 3.4 * size_k)
	glow.modulate = Color(1.0, 0.5, 0.12, 1.0)
	glow.material = add
	m.add_child(glow)
	var tail: Sprite2D = Art.sprite("fx_hellfire_tail", 1.1 * size_k)
	tail.material = add
	# Tail trails behind: its tip points back along the path.
	tail.rotation = dir.angle() - PI / 2.0  # bright end at the rock, tip trailing back
	tail.position = -dir * Art.svg_size("fx_hellfire_tail").y * 1.1 * size_k * 0.42
	m.add_child(tail)
	var rock: Sprite2D = Art.sprite("fx_hellfire_meteor", 0.9 * size_k)
	rock.modulate = Color(1.35, 1.1, 0.95)  # molten, reads hot against the red sky
	m.add_child(rock)
	var trail: CPUParticles2D = _ember_emitter(36, 0.7, false)
	trail.local_coords = false
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 22.0 * size_k
	trail.initial_velocity_max = 40.0
	trail.gravity = Vector2(0, -40)
	trail.scale_amount_min = 0.1 * size_k
	trail.scale_amount_max = 0.3 * size_k
	m.add_child(trail)
	trail.emitting = true
	if loud:
		Sound.play_at("hellfire_incoming", to, 0.7)
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "global_position", to, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rock, "rotation", randf_range(4.0, 7.0), fall)
	tw.tween_callback(_impact.bind(m, b, to, size_k))


## `target` is untyped: the block may be freed (smashed by physics) while the meteor falls.
func _impact(m: Node2D, target: Object, to: Vector2, size_k: float) -> void:
	m.queue_free()
	var b: Block = target as Block if is_instance_valid(target) else null
	var fx: Fx = level.fx
	var bottom: float = to.y + (b.size.y * 0.5 if b != null else 0.0)
	fx.flash(to, 90.0 * size_k)
	fx.shockwave(to.x, 150.0 * size_k, bottom)
	fx.debris(to, "clay", 6, 460.0)
	for k: int in 6:
		fx.flame_puff(to + Vector2(randf_range(-40, 40), randf_range(-30, 20)) * size_k)
	var burst: CPUParticles2D = _ember_emitter(40, 0.9, true)
	burst.global_position = to
	burst.spread = 180.0
	burst.direction = Vector2.UP
	burst.initial_velocity_min = 180.0
	burst.initial_velocity_max = 520.0 * size_k
	burst.gravity = Vector2(0, 600)
	burst.z_index = 13
	level.world.add_child(burst)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	# A flare of light and a scorch mark that cools down.
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var light: Sprite2D = Art.sprite("fx_glow", 2.0 * size_k)
	light.material = add
	light.modulate = Color(1.0, 0.7, 0.3, 0.9)
	light.global_position = to
	light.z_index = 13
	level.world.add_child(light)
	var lt: Tween = light.create_tween()
	lt.tween_property(light, "scale", light.scale * 2.4, 0.35).set_ease(Tween.EASE_OUT)
	lt.parallel().tween_property(light, "modulate:a", 0.0, 0.35)
	lt.tween_callback(light.queue_free)
	var scorch: Sprite2D = Art.sprite("fx_scorch", 0.9 * size_k)
	scorch.global_position = Vector2(to.x, bottom - 4.0)
	scorch.z_index = 2
	level.world.add_child(scorch)
	var st: Tween = scorch.create_tween()
	st.tween_interval(float(_cfg["scorch_s"]))
	st.tween_property(scorch, "modulate:a", 0.0, 1.0)
	st.tween_callback(scorch.queue_free)
	level.camera.add_shake(5.0 * size_k)
	Sound.play_at("explosion", to, 0.6, randf_range(0.85, 1.1))
	if b != null and not b.dead:
		b.destroy(true)
	if size_k >= float(_cfg["opener_scale"]) - 0.01:
		level.slow_mo(float(_cfg["opener_slowmo"]), float(_cfg["opener_slowmo_s"]))


# ------------------------------------------------------------------------------------ ending
func _finale() -> void:
	for a: Archer in level.archers.duplicate():
		if is_instance_valid(a) and not a.dead:
			a.shield_left = 0.0
			a.defeat()
	for b: Block in level.blocks.duplicate():
		if is_instance_valid(b) and not b.dead:
			b.destroy(true)
	level.camera.add_shake(float(_cfg["shake"]))
	Sound.play("explosion", 0.8, 0.7)
	var tw: Tween = create_tween()
	tw.tween_property(_flash, "color:a", 0.85, 0.08)
	tw.tween_property(_flash, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(_tint, "color:a", 0.0, 1.2)
	_embers.emitting = false
	_after(0.6, _slide_bars.bind(false))
	_after(float(_cfg["settle_s"]), func() -> void:
		if level.hud:
			level.hud.visible = true
		done.emit()
		queue_free())
