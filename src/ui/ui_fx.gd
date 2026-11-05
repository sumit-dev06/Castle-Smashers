class_name UIFx
extends RefCounted
## Shared "juice" for menus and rewards: flying currency, count-ups, press squash, popups,
## ray bursts, confetti and stamps. Timings in data/balance.json -> ui_fx. See docs/UI_DESIGN.md.

static var _flying: Dictionary = {}


static func cfg(key: String) -> float:
	return Data.bf("ui_fx", key)


## Number of reward icons still in the air for a currency (CurrencyBar skips its own count-up).
static func flying(kind: String) -> int:
	return int(_flying.get(kind, 0))


## A new layer for one popup, just under the shared overlay (so reward icons fly above it).
## Free it when the popup closes. Never queue_free() overlay(): flying rewards live there.
static func popup_layer() -> CanvasLayer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 49
	layer.add_to_group("ui_popup")
	tree.root.add_child(layer)
	return layer


## Top overlay layer for effects that must draw above every screen.
static func overlay() -> CanvasLayer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var layer: CanvasLayer = tree.root.get_node_or_null("UIFxLayer")
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "UIFxLayer"
		layer.layer = 50
		tree.root.add_child(layer)
	return layer


## Burst `amount` of `kind` from `from` (canvas position) and fly the icons into the bar's pill.
## Adds the currency to the save, or with apply = false animates an amount the save already holds
## (claims save first so leaving the screen mid-flight never loses a reward).
static func fly_reward(from: Vector2, kind: String, amount: int, bar: CurrencyBar, apply: bool = true) -> void:
	if amount <= 0:
		return
	var n: int = clampi(amount, 1, int(cfg("fly_max_icons")))
	var start: int = Save.amount(kind) - (0 if apply else amount)
	_flying[kind] = flying(kind) + n
	if apply:
		Save.add(kind, amount)
	var layer: CanvasLayer = overlay()
	var px: float = cfg("fly_icon_px")
	var sound: String = "gem_tink" if kind == "gems" else "coin_tink"
	for i: int in n:
		var icon: TextureRect = UIKit.tex_rect(UIKit.CURRENCY_ICON[kind], px)
		icon.pivot_offset = icon.custom_minimum_size / 2.0
		icon.position = from - icon.pivot_offset
		icon.scale = Vector2.ZERO
		layer.add_child(icon)
		# Count down when the icon leaves the tree for any reason (landed or freed early), so the
		# wallet bar never waits forever for an icon that is gone.
		icon.tree_exited.connect(func() -> void: _flying[kind] = maxi(0, flying(kind) - 1), CONNECT_ONE_SHOT)
		var ang: float = TAU * float(i) / float(n) + randf() * 0.6
		var burst: Vector2 = from + Vector2.from_angle(ang) * cfg("fly_burst_px") * randf_range(0.5, 1.0) - icon.pivot_offset
		var target: Vector2 = (bar.pill_center(kind) if is_instance_valid(bar) else Vector2(1200, 40)) - icon.pivot_offset
		var value: int = start + int(round(float(amount) * float(i + 1) / float(n)))
		var tw: Tween = icon.create_tween()
		tw.tween_interval(float(i) * cfg("fly_stagger_s"))
		tw.tween_property(icon, "scale", Vector2.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(icon, "position", burst, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(icon, "rotation", randf_range(-0.6, 0.6), 0.22)
		tw.tween_property(icon, "position", target, cfg("fly_s")).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(icon, "scale", Vector2.ONE * 0.7, cfg("fly_s"))
		var k: int = i
		tw.tween_callback(func() -> void:
			icon.queue_free()
			# Every other coin tinks (a full burst stacked into one loud rattle).
			if k % 2 == 0 or k == n - 1:
				Sound.play(sound, 0.7, 1.0 + cfg("tink_pitch_step") * float(k))
			if k == n - 1:
				Sound.play("wallet_land", 0.7)
			if is_instance_valid(bar):
				bar.show_amount(kind, value if k < n - 1 else Save.amount(kind)))


## Scores and amounts roll up, never jump.
static func count_up(l: Label, from: int, to: int, seconds: float = -1.0, prefix: String = "") -> Tween:
	var tw: Tween = l.create_tween()
	var last: Array[int] = [from]
	tw.tween_method(func(v: float) -> void:
		l.text = prefix + CurrencyBar._fmt(int(v))
		# A soft tick while the number rolls (cooldown in balance audio.cooldown_ms keeps it light).
		if int(v) != last[0]:
			last[0] = int(v)
			Sound.play("count_tick", 0.35, 0.9 + 0.3 * clampf(inverse_lerp(float(from), float(to), v), 0.0, 1.0)), float(from), float(to),
		cfg("count_up_s") if seconds < 0.0 else seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return tw


## Squash on press, overshoot on release.
static func press_juice(b: BaseButton) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2.ONE * cfg("press_scale"), cfg("press_s")))
	b.button_up.connect(func() -> void:
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE * 1.06, cfg("press_s"))
		tw.tween_property(b, "scale", Vector2.ONE, cfg("press_s") * 1.5).set_trans(Tween.TRANS_BACK))


## Idle CTA: slow breathing scale.
static func breathe(c: Control) -> void:
	var tw: Tween = c.create_tween().set_loops()
	tw.tween_callback(func() -> void: c.pivot_offset = c.size / 2.0)
	tw.tween_property(c, "scale", Vector2.ONE * cfg("breathe_scale"), cfg("breathe_s")).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, cfg("breathe_s")).set_trans(Tween.TRANS_SINE)


## A soft diagonal light sweep across a button every few seconds (the button clips it).
static func shine(c: Control, delay: float = 0.0) -> void:
	c.clip_contents = true
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 0.9, cfg("shine_alpha")), Color(1, 1, 1, 0)])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	var band: TextureRect = TextureRect.new()
	band.texture = gt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.rotation_degrees = 18.0
	c.add_child(band)
	var tw: Tween = band.create_tween().set_loops()
	tw.tween_callback(func() -> void:
		band.size = Vector2(c.size.y * 0.9, c.size.y * 2.2)
		band.position = Vector2(-band.size.x * 1.6, -c.size.y * 0.5))
	tw.tween_interval(delay + cfg("shine_gap_s"))
	tw.tween_method(func(k: float) -> void:
		band.position.x = lerpf(-band.size.x * 1.6, c.size.x + band.size.x * 0.6, k), 0.0, 1.0, cfg("shine_s")) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Attention cue for something ready to use: a quick small wiggle, then a long rest.
static func nudge(c: Control) -> void:
	var tw: Tween = c.create_tween().set_loops()
	tw.tween_callback(func() -> void: c.pivot_offset = c.size / 2.0)
	tw.tween_interval(cfg("nudge_gap_s"))
	for a: float in [5.0, -4.0, 3.0, -2.0, 0.0]:
		tw.tween_property(c, "rotation_degrees", a, 0.07).set_trans(Tween.TRANS_SINE)


## Popup entrance: scale from popup_from with a fade.
static func pop_in(c: Control, delay: float = 0.0) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * cfg("popup_from")
	var tw: Tween = c.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: c.pivot_offset = c.size / 2.0)
	tw.tween_property(c, "modulate:a", 1.0, cfg("popup_s") * 0.6)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, cfg("popup_s")).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Panel entrance from a side: dir (-1,0) = from the left, (1,0) = right, (0,1) = bottom.
static func slide_in(c: Control, dir: Vector2, delay: float = 0.0) -> void:
	var end: Vector2 = c.position
	c.position = end + dir * cfg("slide_px")
	c.modulate.a = 0.0
	var tw: Tween = c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "position", end, cfg("slide_s")).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate:a", 1.0, cfg("slide_s") * 0.5)


## Pop a control (stars, counters, unlocked badges).
static func pop(c: Control, peak: float = 1.25) -> void:
	c.pivot_offset = c.size / 2.0
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * peak, 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func shake(c: Control, px: float = 10.0) -> void:
	var x: float = c.position.x
	var tw: Tween = c.create_tween()
	for i: int in 5:
		tw.tween_property(c, "position:x", x + (px if i % 2 == 0 else -px) * (1.0 - i * 0.18), 0.04)
	tw.tween_property(c, "position:x", x, 0.04)


## Spinning light rays centred on `center` (canvas coords). Returns the node; free_after <= 0 keeps it.
static func rays(parent: Node, center: Vector2, size: float, free_after: float = 1.4) -> TextureRect:
	var r: TextureRect = UIKit.tex_rect("fx_rays", size)
	r.pivot_offset = r.custom_minimum_size / 2.0
	r.position = center - r.pivot_offset
	r.material = CanvasItemMaterial.new()
	(r.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.scale = Vector2.ZERO
	parent.add_child(r)
	var tw: Tween = r.create_tween()
	tw.tween_property(r, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin: Tween = r.create_tween().set_loops()
	spin.tween_property(r, "rotation", TAU, TAU / deg_to_rad(cfg("rays_spin_dps"))).as_relative()
	if free_after > 0.0:
		tw.tween_interval(free_after)
		tw.tween_property(r, "modulate:a", 0.0, 0.4)
		tw.tween_callback(r.queue_free)
	return r


## Paper confetti falling from `center`.
static func confetti(center: Vector2, count: int = -1) -> void:
	var layer: CanvasLayer = overlay()
	var colors: Array[Color] = [Color("#ffd23a"), Color("#ff5a4a"), Color("#4ac0ff"), Color("#7ae05a"), Color("#c46aff"), Color.WHITE]
	var n: int = int(cfg("confetti")) if count < 0 else count
	for i: int in n:
		var p: ColorRect = ColorRect.new()
		p.size = Vector2(randf_range(8, 14), randf_range(12, 20))
		p.pivot_offset = p.size / 2.0
		p.color = colors[i % colors.size()]
		p.position = center
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(p)
		var up: Vector2 = center + Vector2(randf_range(-320, 320), randf_range(-260, -60))
		var down: Vector2 = up + Vector2(randf_range(-80, 80), randf_range(380, 620))
		var d: float = cfg("confetti_s") * randf_range(0.7, 1.2)
		var tw: Tween = p.create_tween()
		tw.tween_property(p, "position", up, d * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(p, "position", down, d * 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(p, "modulate:a", 0.0, d * 0.7).set_delay(d * 0.15)
		tw.tween_callback(p.queue_free)
		var spin: Tween = p.create_tween()
		spin.tween_property(p, "rotation", randf_range(-12, 12), d)


## Big rubber stamp text ("PURCHASED!", "CLAIMED!") slamming onto `parent` at `center`.
static func stamp(parent: Node, center: Vector2, text: String, color: Color = Color("#7ae05a")) -> Label:
	var l: Label = UIKit.label(text, 64, color, 14)
	l.size = Vector2(640, 90)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = l.size / 2.0
	l.position = center - l.pivot_offset
	l.rotation = deg_to_rad(-8)
	l.scale = Vector2.ONE * 2.6
	l.modulate.a = 0.0
	parent.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, cfg("stamp_s")).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 1.0, cfg("stamp_s") * 0.4)
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	Sound.play("slam", 0.5)
	return l


## Full purchase celebration on a card: flash, rays, confetti, stamp, purchase sound.
static func celebrate(card: Control, text: String = "PURCHASED!") -> void:
	var c: Vector2 = card.get_global_rect().get_center()
	var layer: CanvasLayer = overlay()
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.position = card.get_global_rect().position
	flash.size = card.get_global_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var tw: Tween = flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)
	rays(layer, c, card.get_global_rect().size.y * 1.8)
	confetti(c)
	stamp(layer, c, text)
	pop(card, 1.12)
	Sound.play("purchase")
