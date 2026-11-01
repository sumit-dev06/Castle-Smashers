class_name Cinematic
extends Node
## Animated story scenes played inside the real level, with the real fortress, mechanisms and boss.
## Characters walk, drop or pop in, talk in short comic bubbles, point and emote; the camera pans and
## zooms; new mechanics get a callout (ring, bouncing arrow, sign) and a ghost-shot demo; new heroes
## get a reveal card with their ability shown; bosses get a dramatic entrance.
## Beats (level JSON "cinematic"): {"t": "title"|"pan"|"enter"|"say"|"emote"|"focus"|"demo"|"hero"|
##   "boss"|"exit"|"wait"|"march", ...}. Tap = fast-forward the current beat, SKIP = end.

signal finished

const ACTORS: Dictionary = {
	"captain": {"art": "soldier_idle", "alt": "soldier_cheer", "h": 104.0, "name": "Captain Bram", "side": 0},
	"soldier": {"art": "soldier_cheer", "alt": "soldier_idle", "h": 94.0, "name": "Vanguard", "side": 0},
	"wizard": {"art": "wizard_idle", "alt": "wizard_idle", "h": 132.0, "name": "Master Orin", "side": 0},
	"enemy": {"art": "archer_idle", "alt": "archer_shoot", "h": 92.0, "name": "Redcap", "side": 1},
	"baron": {"art": "archer_shoot", "alt": "archer_idle", "h": 150.0, "name": "Iron Baron", "side": 1},
	"captive": {"art": "captive_idle", "alt": "captive_idle", "h": 92.0, "name": "Scout", "side": 1},
}

var level: Level
var beats: Array = []
## Quick in-level flyover (no letterbox, no skip button).
var quick: bool = false
var running: bool = false

var _cam: GameCamera
var _ui: CanvasLayer
var _root: Control
var _actors: Dictionary = {}
var _fast: bool = false
var _skip: bool = false
var _bars: Array[ColorRect] = []
var _temp: Array[Node] = []


func play() -> void:
	running = true
	_cam = level.camera
	_cam.cine = true
	_build_ui()
	for beat: Variant in beats:
		if _skip:
			break
		_fast = false
		await _run(beat as Dictionary)
	await _end()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 12
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)
	if quick:
		return
	var bar_h: float = Data.bf("story", "letterbox_px")
	for top_side: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color("#120d12")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		if top_side:
			bar.offset_top = -bar_h
			bar.offset_bottom = 0.0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = 0.0
			bar.offset_bottom = bar_h
		_root.add_child(bar)
		_bars.append(bar)
		var tw: Tween = bar.create_tween().set_parallel()
		tw.tween_property(bar, "offset_top", 0.0 if top_side else -bar_h, 0.4)
		tw.tween_property(bar, "offset_bottom", bar_h if top_side else 0.0, 0.4)
	var skip: Button = UIKit.button("SKIP", "dark", 24, Vector2(120, 56))
	UIKit.place(skip, Vector2(1, 0), Vector2(-140, 54), Vector2(120, 56))
	skip.pressed.connect(func() -> void:
		_skip = true
		_fast = true)
	_root.add_child(skip)


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_fast = true
		if quick:
			_skip = true
		get_viewport().set_input_as_handled()


## Waits `s` seconds (game time) unless the player taps.
func _sleep(s: float) -> void:
	var left: float = s
	while left > 0.0 and not _fast and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()


# ------------------------------------------------------------------------------------ targets
func _target(name: String) -> Vector2:
	var st: Stage = level.stage
	if name == "catapult":
		return Vector2(60, -140)
	if name == "fortress":
		var x0: float = st.bases[0].position.x if not st.bases.is_empty() else 1000.0
		var x1: float = st.bases[-1].end.x if not st.bases.is_empty() else 1600.0
		return Vector2((x0 + x1) * 0.5, -260)
	if name == "gap":
		var gx1: float = st.bases[0].position.x if not st.bases.is_empty() else st.ledge_right + 400.0
		return Vector2((st.ledge_right + gx1) * 0.5, st.surface_y + st.tide_offset())
	if name == "boss" and is_instance_valid(level.boss):
		return level.boss.global_position + Vector2(0, -40)
	if name.begins_with("mech:"):
		var i: int = int(name.substr(5))
		if i < level.mechanisms.size():
			var m: CastleMechanism = level.mechanisms[i]
			var ropes: Array = m.ropes()
			if not ropes.is_empty():
				return ((ropes[0][0] as Vector2) + (ropes[0][1] as Vector2)) * 0.5
			if m.kind in ["lever", "windmill", "shield_ring", "rune_switch", "trapdoor", "flood"]:
				return m.hit_point()
			if m.kind == "geyser":
				return m.global_position + Vector2(0, -float(m.cfg["height"]) * 0.5)
			if m.body:
				return m.body.global_position
			return m.global_position
	if name.begins_with("gadget:"):
		var gi: int = int(name.substr(7))
		if gi < level.gadgets.size():
			return level.gadgets[gi].hit_point()
	if name.begins_with("captive:"):
		var c: int = int(name.substr(8))
		if c < level.captives.size():
			return level.captives[c].global_position + Vector2(0, -60)
	if name in ["core", "cannon"]:
		for b: Block in level.blocks:
			if b.mat_id == name:
				return b.global_position
	if name == "engineer" and level.rig and not level.rig.engineers.is_empty():
		return level.rig.engineers[0].global_position + Vector2(0, -40)
	if name == "weak":
		for b: Block in level.blocks:
			if b.is_weak_point():
				return b.global_position
	if name.begins_with("bolt:"):
		var k: int = int(name.substr(5))
		if k < level.bolts.size():
			return level.bolts[k].position_now()
	if name == "top":
		var top: Vector2 = _target("fortress")
		for a: Archer in level.archers:
			if a.global_position.y < top.y + 200.0:
				top = a.global_position
		return top + Vector2(0, -60)
	if name.contains(","):
		var p: PackedStringArray = name.split(",")
		return Vector2(float(p[0]), float(p[1]))
	return _target("fortress")


func _pan_to(p: Vector2, z: float, s: float) -> void:
	var tw: Tween = _cam.create_tween().set_parallel()
	tw.tween_property(_cam, "position", p, s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_cam, "zoom", Vector2.ONE * z, s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _sleep(s)


func _default_zoom() -> float:
	return float(_cam.default_view()[1])


# ------------------------------------------------------------------------------------ beats
func _run(b: Dictionary) -> void:
	match String(b.get("t", "")):
		"title":
			await _beat_title()
		"pan":
			var z: float = float(b.get("zoom", 0.0))
			if z <= 0.0:
				z = _default_zoom()
			await _pan_to(_target(String(b.get("to", "fortress"))), z, float(b.get("s", Data.bf("cinematic", "pan_s"))))
		"enter":
			await _beat_enter(String(b["who"]), String(b.get("at", "catapult")), String(b.get("style", "walk")))
		"say":
			await _beat_say(String(b["who"]), String(b["text"]))
		"emote":
			await _beat_emote(String(b["who"]), String(b.get("e", "jump")))
		"focus":
			await _beat_focus(String(b["target"]), String(b.get("label", "")))
		"demo":
			await _beat_demo(String(b["target"]), String(b.get("hero", "stone")))
		"hero":
			await _beat_hero(String(b["kind"]))
		"boss":
			await _beat_boss()
		"exit":
			_beat_exit(String(b["who"]))
			await _sleep(0.4)
		"wait":
			await _sleep(float(b.get("s", 0.5)))
		"march":
			for s: Soldier in level.soldiers:
				s.cheer(1.5)
			Sound.play("star", 0.5, 0.9)
			await _sleep(0.8)


func _beat_title() -> void:
	var info: Dictionary = level.realm_info
	var c: CenterContainer = CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sign: PanelContainer = UIKit.wood_sign()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_child(UIKit.label(String(info.get("name", "")).to_upper(), 26, Color("#ffd23a"), 8))
	v.add_child(UIKit.label("%d · %s" % [level.level_id, String(level.data.get("name", ""))], 50, Color.WHITE, 12))
	sign.add_child(v)
	c.add_child(sign)
	_root.add_child(c)
	c.position.y = -500
	Sound.play("whoosh", 0.6)
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "position:y", -120.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fort: Vector2 = _target("fortress")
	_cam.position = fort + Vector2(-200, -60)
	_cam.zoom = Vector2.ONE * _default_zoom() * 1.2
	await _pan_to(fort, _default_zoom() * 1.1, 1.8)
	var out: Tween = c.create_tween()
	out.tween_property(c, "modulate:a", 0.0, 0.35)
	out.tween_callback(c.queue_free)


func _actor_pos(at: String) -> Vector2:
	match at:
		"catapult":
			return Vector2(-150, 0)
		"ledge":
			return Vector2(level.stage.ledge_right - 110.0, 0)
		"fortress":
			var b0: Rect2 = level.stage.bases[0]
			return Vector2(b0.position.x + 50.0, b0.position.y)
	return _target(at)


func _beat_enter(who: String, at: String, style: String) -> void:
	var a: Dictionary = ACTORS.get(who, ACTORS["captain"])
	if at == "boss" and is_instance_valid(level.boss):
		# The villain speaking from the boss spot IS the boss: no second crowned figure on top of it.
		var boss: Archer = level.boss
		var bs: Sprite2D = boss.get("_sprite") as Sprite2D
		var info: Dictionary = a.duplicate()
		info["h"] = maxf(60.0, boss.global_position.y - boss.visual_top() - 30.0)
		_actors[who] = {"node": boss, "sprite": bs, "base": bs.scale, "info": info, "borrowed": true}
		level.fx.puff(boss.global_position + Vector2(0, -40), 8, Color(0.6, 0.5, 0.7, 0.9), 1.1)
		Sound.play("pop", 0.7, 0.8)
		_squash(bs, Vector2(1.2, 0.85))
		await _sleep(0.5)
		return
	var node: Node2D = Node2D.new()
	node.z_index = 6
	level.world.add_child(node)
	var spr: Sprite2D = Art.unit_sprite(String(a["art"]), float(a["h"]))
	if int(a["side"]) == 1 and String(a["art"]).begins_with("archer"):
		spr.flip_h = false
	if who == "baron":
		spr.modulate = Color(0.85, 0.75, 1.0)
		var crown: Sprite2D = Art.sprite("boss_crown", 1.0)
		crown.position = Vector2(-4, -float(a["h"]) - 4)
		node.add_child(crown)
	var sh: Sprite2D = Art.sprite("shadow", 1.1)
	node.add_child(sh)
	node.add_child(spr)
	_actors[who] = {"node": node, "sprite": spr, "base": spr.scale, "info": a}
	var target: Vector2 = _actor_pos(at)
	match style:
		"drop":
			node.position = target + Vector2(0, -700)
			var tw: Tween = node.create_tween()
			tw.tween_property(node, "position", target, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				level.fx.puff(target, 5, Color(1, 0.95, 0.85, 0.9), 0.8)
				level.camera.add_shake(6.0)
				Sound.play("slam", 0.5, 1.2)
				_squash(spr, Vector2(1.3, 0.7)))
			await _sleep(0.75)
		"smoke":
			node.position = target
			spr.scale = Vector2.ZERO
			level.fx.puff(target + Vector2(0, -50), 8, Color(0.6, 0.5, 0.7, 0.9), 1.1)
			Sound.play("pop", 0.7, 0.8)
			spr.create_tween().tween_property(spr, "scale", _actors[who]["base"], 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await _sleep(0.5)
		_:
			var from_x: float = target.x + (-520.0 if int(a["side"]) == 0 else 520.0)
			node.position = Vector2(from_x, target.y)
			var walk: Tween = node.create_tween()
			walk.tween_method(func(k: float) -> void:
				node.position = Vector2(lerpf(from_x, target.x, k), target.y - absf(sin(k * 18.0)) * 10.0),
				0.0, 1.0, 0.9)
			await _sleep(0.95)
			node.position = target


func _squash(spr: Sprite2D, amount: Vector2) -> void:
	var base: Vector2 = spr.scale
	var tw: Tween = spr.create_tween()
	tw.tween_property(spr, "scale", base * amount, 0.08)
	tw.tween_property(spr, "scale", base, 0.3).set_trans(Tween.TRANS_ELASTIC)


func _beat_say(who: String, text: String) -> void:
	if not _actors.has(who):
		await _beat_enter(who, "catapult" if int(ACTORS.get(who, ACTORS["captain"])["side"]) == 0 else "fortress", "smoke")
	var act: Dictionary = _actors[who]
	var node: Node2D = act["node"]
	var spr: Sprite2D = act["sprite"]
	var h: float = float(act["info"]["h"])
	await _pan_to(node.position + Vector2(0, -h * 0.9), _default_zoom() * Data.bf("cinematic", "focus_zoom"), 0.5)
	var holder: Node2D = Node2D.new()
	holder.position = node.position + Vector2(0, -h - 40)
	holder.z_index = 30
	level.world.add_child(holder)
	var bubble: PanelContainer = UIKit.dark_bubble()
	var l: Label = UIKit.label(text, 26, Color.WHITE, 0, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(420.0, 40.0 + text.length() * 13.0), 0)
	bubble.add_child(l)
	holder.add_child(bubble)
	bubble.position = Vector2(-l.custom_minimum_size.x * 0.5 - 18.0, -70.0)
	holder.scale = Vector2.ZERO
	holder.create_tween().tween_property(holder, "scale", Vector2.ONE / _cam.zoom.x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var voice: String = "talk_enemy" if int(act["info"]["side"]) != 0 else ("talk_high" if who == "captive" or who == "wizard" else "talk_hero")
	Sound.play(voice, 0.75)
	if who == "baron" or who == "enemy":
		Sound.play("enemy_laugh", 0.4)
	var talk: Tween = spr.create_tween().set_loops(6)
	var base: Vector2 = act["base"]
	talk.tween_property(spr, "scale", Vector2(base.x * 1.05, base.y * 0.95), 0.12)
	talk.tween_property(spr, "scale", base, 0.12)
	await _sleep(maxf(Data.bf("cinematic", "say_min_s"), text.length() * Data.bf("cinematic", "say_per_char_s")))
	var out: Tween = holder.create_tween()
	out.tween_property(holder, "scale", Vector2.ZERO, 0.15)
	out.tween_callback(holder.queue_free)


func _beat_emote(who: String, e: String) -> void:
	if not _actors.has(who):
		return
	var act: Dictionary = _actors[who]
	var node: Node2D = act["node"]
	var spr: Sprite2D = act["sprite"]
	if bool(act.get("borrowed", false)):
		# A real unit (the boss): only a sprite wobble and a laugh, never moving its physics body or
		# swapping its art.
		var wob: Tween = spr.create_tween()
		for i: int in 6:
			wob.tween_property(spr, "rotation", 0.1 if i % 2 == 0 else -0.1, 0.07)
		wob.tween_property(spr, "rotation", 0.0, 0.08)
		Sound.play("enemy_laugh", 0.5)
		await _sleep(0.5)
		return
	match e:
		"jump", "cheer":
			Art.set_unit_tex(spr, String(act["info"]["alt"]), float(act["info"]["h"]))
			var y0: float = node.position.y
			var tw: Tween = node.create_tween()
			for i: int in 2:
				tw.tween_property(node, "position:y", y0 - 60.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(node, "position:y", y0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			Sound.play("star", 0.4, 1.2)
		"laugh", "shake":
			var tw2: Tween = spr.create_tween()
			for i: int in 6:
				tw2.tween_property(spr, "rotation", 0.14 if i % 2 == 0 else -0.14, 0.07)
			tw2.tween_property(spr, "rotation", 0.0, 0.08)
			Sound.play("enemy_laugh", 0.5)
		"point":
			var tw3: Tween = spr.create_tween()
			tw3.tween_property(spr, "rotation", 0.25 if int(act["info"]["side"]) == 0 else -0.25, 0.2)
			tw3.tween_interval(0.5)
			tw3.tween_property(spr, "rotation", 0.0, 0.2)
		"scared":
			spr.modulate = Color(0.8, 0.85, 1.2)
			var tw4: Tween = node.create_tween()
			for i: int in 8:
				tw4.tween_property(node, "position:x", node.position.x + (6.0 if i % 2 == 0 else -6.0), 0.04)
		"wave":
			for k: int in 6:
				var sp: Sprite2D = Art.sprite("sparkle", randf_range(0.4, 0.8))
				sp.position = node.position + Vector2(randf_range(-40, 60), -float(act["info"]["h"]) + randf_range(-30, 30))
				sp.z_index = 8
				level.world.add_child(sp)
				var st: Tween = sp.create_tween()
				st.tween_property(sp, "position:y", sp.position.y - 60.0, 0.6)
				st.parallel().tween_property(sp, "modulate:a", 0.0, 0.6)
				st.tween_callback(sp.queue_free)
			Sound.play("rescue", 0.5, 1.3)
	await _sleep(0.8)


func _callout(p: Vector2, label: String) -> Node2D:
	var c: Node2D = Node2D.new()
	c.position = p
	c.z_index = 25
	level.world.add_child(c)
	var k: float = 1.0 / maxf(0.3, _cam.zoom.x)
	var ring: Sprite2D = Art.sprite("callout_ring", 1.6 * k)
	c.add_child(ring)
	var pulse: Tween = ring.create_tween().set_loops()
	pulse.tween_property(ring, "scale", ring.scale * 1.25, 0.4).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ring, "scale", ring.scale, 0.4).set_trans(Tween.TRANS_SINE)
	var arrow: Sprite2D = Art.sprite("callout_arrow", 1.0 * k)
	arrow.position = Vector2(0, -110 * k)
	c.add_child(arrow)
	var bob: Tween = arrow.create_tween().set_loops()
	bob.tween_property(arrow, "position:y", -140 * k, 0.3).set_trans(Tween.TRANS_SINE)
	bob.tween_property(arrow, "position:y", -110 * k, 0.3).set_trans(Tween.TRANS_SINE)
	if not label.is_empty():
		var sign: PanelContainer = UIKit.wood_sign()
		sign.add_child(UIKit.label(label, 30, Color.WHITE, 8))
		var holder: Node2D = Node2D.new()
		holder.scale = Vector2.ONE * k
		holder.position = Vector2(0, -260 * k)
		holder.add_child(sign)
		c.add_child(holder)
		sign.position = Vector2(-label.length() * 9.5 - 30.0, 0)
		# High targets (boss towers) would put the sign under the HUD bars: show it below the ring.
		if (c.get_global_transform_with_canvas() * holder.position).y < Data.bf("cinematic", "callout_top_safe"):
			holder.position = Vector2(0, 120 * k)
	_temp.append(c)
	return c


func _beat_focus(target: String, label: String) -> void:
	var p: Vector2 = _target(target)
	await _pan_to(p + Vector2(0, -80), _default_zoom() * Data.bf("cinematic", "focus_zoom"), 0.7)
	var c: Node2D = _callout(p, label)
	Sound.play("pop", 0.6, 1.4)
	await _sleep(Data.bf("cinematic", "callout_s"))
	if is_instance_valid(c):
		c.queue_free()


## A ghost hero flies the arc from the catapult to the target, then the target flashes.
func _beat_demo(target: String, hero: String) -> void:
	var p: Vector2 = _target(target)
	var from: Vector2 = level.catapult.launch_point(hero)
	var mid: Vector2 = (from + p) * 0.5
	await _pan_to(mid + Vector2(0, -120), _default_zoom() * 0.95, 0.6)
	var ghost: Sprite2D = Projectile.make_sprite(hero)
	ghost.modulate = Color(1, 1, 1, 0.75)
	ghost.z_index = 9
	level.world.add_child(ghost)
	var peak: float = minf(from.y, p.y) - 260.0
	var dots: Array[Sprite2D] = []
	Sound.play("launch", 0.5)
	var dur: float = Data.bf("cinematic", "demo_s")
	var tw: Tween = ghost.create_tween()
	tw.tween_method(func(k: float) -> void:
		var x: float = lerpf(from.x, p.x, k)
		var y: float = lerpf(from.y, p.y, k) + (peak - (from.y + p.y) * 0.5) * 4.0 * k * (1.0 - k)
		ghost.position = Vector2(x, y)
		ghost.rotation = k * 8.0
		if dots.size() < int(k * 16.0):
			var d: Sprite2D = Art.sprite("dot", 0.8)
			d.position = ghost.position
			d.z_index = 8
			level.world.add_child(d)
			dots.append(d), 0.0, 1.0, dur)
	await _sleep(dur + 0.05)
	level.fx.flash(p, 90.0)
	level.fx.sparks(p, 8)
	Sound.play("rope_snap" if target.begins_with("mech:") else "stone_hit", 0.7)
	_callout(p, "")
	await _sleep(0.7)
	ghost.queue_free()
	for d2: Sprite2D in dots:
		d2.queue_free()


func _beat_hero(kind: String) -> void:
	var cfg: Dictionary = Data.projectiles[kind]
	if not _actors.has("wizard"):
		await _beat_enter("wizard", "catapult", "smoke")
	var wz: Node2D = _actors["wizard"]["node"]
	await _pan_to(wz.position + Vector2(120, -120), _default_zoom() * 1.35, 0.5)
	await _beat_emote("wizard", "wave")
	var hero: Sprite2D = Projectile.make_sprite(kind)
	var base: Vector2 = hero.scale
	hero.position = wz.position + Vector2(40, -150)
	hero.scale = Vector2.ZERO
	hero.z_index = 9
	level.world.add_child(hero)
	var land: Vector2 = wz.position + Vector2(170, -float(cfg["radius"]) * 1.8)
	var tw: Tween = hero.create_tween()
	tw.tween_property(hero, "scale", base * 1.8, 0.35).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(hero, "position", land + Vector2(0, -120), 0.35)
	tw.tween_property(hero, "position", land, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sound.play("pop", 0.8)
	await _sleep(0.7)
	# Ability preview on the hero itself.
	match kind:
		"fire":
			for i: int in 10:
				level.fx.flame_puff(land + Vector2.from_angle(randf() * TAU) * randf() * 70.0)
			Sound.play("fire", 0.7)
		"bomb":
			level.fx.flash(land, 120.0)
			level.fx.sparks(land, 12)
			level.camera.add_shake(10.0)
			Sound.play("explosion", 0.6)
		"cyclone":
			var spin: Tween = hero.create_tween()
			spin.tween_property(hero, "rotation", TAU * 3.0, 0.9)
			for i: int in 8:
				level.fx.puff(land + Vector2.from_angle(i * 0.8) * 60.0, 1, Color(0.85, 1.0, 0.98, 0.7), 0.6)
			Sound.play("wind", 0.6)
		"quake":
			level.fx.shockwave(land.x, 220.0, 0.0)
			level.camera.add_shake(14.0)
			Sound.play("quake", 0.7)
		_:
			level.fx.puff(land + Vector2(0, 40), 6, Color(1, 1, 1, 0.9), 0.8)
			Sound.play("slam", 0.6)
	# Name card on screen.
	var card: PanelContainer = UIKit.panel()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_child(UIKit.label("NEW HERO", 24, Color("#c4501a"), 0))
	v.add_child(UIKit.label(String(cfg["name"]).to_upper(), 54, Color("#ffd23a"), 10))
	var ab: Label = UIKit.label(String(cfg["ability"]).split(":")[0].to_upper() + "!", 30, UIKit.TEXT_DARK, 0)
	v.add_child(ab)
	v.add_child(UIKit.label("Tap while flying", 20, UIKit.TEXT_DARK, 0, false))
	card.add_child(v)
	UIKit.place(card, Vector2(1, 0.5), Vector2(-470, -150), Vector2(420, 260))
	card.pivot_offset = Vector2(210, 130)
	card.scale = Vector2.ZERO
	_root.add_child(card)
	card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("star", 0.7, 1.1)
	await _sleep(Data.bf("cinematic", "hero_card_s"))
	var out: Tween = card.create_tween()
	out.tween_property(card, "scale", Vector2.ZERO, 0.2)
	out.tween_callback(card.queue_free)
	var hop: Tween = hero.create_tween()
	hop.tween_property(hero, "position", level.catapult.bucket_global(), 0.4).set_trans(Tween.TRANS_QUAD)
	hop.parallel().tween_property(hero, "scale", base, 0.4)
	hop.tween_callback(hero.queue_free)
	await _sleep(0.3)


func _beat_boss() -> void:
	if not is_instance_valid(level.boss):
		return
	var p: Vector2 = level.boss.global_position
	await _pan_to(p + Vector2(0, 40), _default_zoom() * 1.5, 0.9)
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 0.2, 0.1, 0.45)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(flash)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.8)
	level.camera.add_shake(22.0)
	Sound.play("boss_roar", 1.0)
	Sound.stinger("boss_intro")
	Game.haptic(120)
	var tw: Tween = level.boss.create_tween()
	tw.tween_property(level.boss, "scale", Vector2(1.2, 0.85), 0.1)
	tw.tween_property(level.boss, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
	var plate: PanelContainer = UIKit.wood_sign()
	var v: VBoxContainer = VBoxContainer.new()
	v.add_child(UIKit.label("BOSS", 26, Color("#ff7a6a"), 8))
	v.add_child(UIKit.label(level.boss.boss_name.to_upper(), 46, Color.WHITE, 12))
	var phases: int = level.data.get("boss_unit", {}).get("phases", []).size()
	v.add_child(UIKit.label("%d PHASES" % phases, 22, Color("#ffd23a"), 6))
	plate.add_child(v)
	# The camera centres on the boss, so the name card sits in the lower band of the screen,
	# clear of the boss, its shield bubble and anyone standing next to it.
	var c: CenterContainer = CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	c.offset_top = -Data.bf("cinematic", "boss_card_band_px")
	c.offset_bottom = -24.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(plate)
	_root.add_child(c)
	plate.pivot_offset = plate.get_combined_minimum_size() * 0.5
	plate.scale = Vector2.ONE * 3.0
	plate.create_tween().tween_property(plate, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _sleep(1.9)
	var out: Tween = c.create_tween()
	out.tween_property(c, "modulate:a", 0.0, 0.3)
	out.tween_callback(c.queue_free)
	flash.queue_free()


func _beat_exit(who: String) -> void:
	if not _actors.has(who):
		return
	var node: Node2D = _actors[who]["node"]
	var borrowed: bool = bool(_actors[who].get("borrowed", false))
	_actors.erase(who)
	if borrowed:
		return
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, 0.35)
	tw.tween_callback(node.queue_free)


func _end() -> void:
	for n: Node in _temp:
		if is_instance_valid(n):
			n.queue_free()
	for who: String in _actors.keys():
		_beat_exit(who)
	var view: Array = _cam.default_view()
	_fast = false
	await _pan_to(view[0], float(view[1]), 0.6 if not _skip else 0.25)
	for bar: ColorRect in _bars:
		bar.create_tween().tween_property(bar, "modulate:a", 0.0, 0.3)
	_cam.cine = false
	running = false
	finished.emit()
	if _ui:
		_ui.queue_free()
