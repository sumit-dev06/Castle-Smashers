class_name WorldMap
extends Node2D
## Interactive campaign map. The five realm paintings sit side by side; a dotted road links the level
## nodes. Drag to scroll (with inertia), tap an unlocked node to open its story and play.
## Locked nodes shake. The current level has a bouncing soldier marker. Each realm ends with a realm
## chest (tiers at balance realm_chests.stars) and shows its secret level once its scroll is found.

const NODE_SCALE: float = 0.8
const TAP_SLOP_PX: float = 14.0

var _camera: Camera2D
var _sound_realm: int = -1
var _nodes: Array[Dictionary] = []
var _segments: Array[Dictionary] = []
var _width: float = 0.0
var _view: Vector2 = Vector2.ZERO
var _drag: bool = false
var _moved: float = 0.0
var _press: Vector2 = Vector2.ZERO
var _vel: float = 0.0
var _last_x: float = 0.0
var _realm_label: Label
var _marker: Sprite2D
var _t: float = 0.0
var _marker_y: float = 0.0
## Chest / secret nodes: {pos, node, kind ("chest"|"secret"), realm}.
var _extras: Array[Dictionary] = []
var _bar: CurrencyBar


func _ready() -> void:
	_view = get_viewport_rect().size
	_camera = Camera2D.new()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camera)
	_build_segments()
	_build_nodes()
	_build_path()
	_build_extras()
	_build_ui()
	var cur: int = clampi(int(Save.data["unlocked"]), 1, Data.level_count())
	_scroll_to(_nodes[cur - 1]["pos"].x - _view.x * 0.45)
	_sound_realm = -1


func _build_segments() -> void:
	var x: float = 0.0
	var h: float = _view.y
	var realms: Array = Data.balance.get("realms", [])
	var per: int = maxi(1, int(ceil(float(Data.level_count()) / maxf(1.0, float(realms.size())))))
	# Each realm is wide enough for its nodes at node_spacing_px; paintings scale up to cover it.
	var min_w: float = per * Data.bf("map", "node_spacing_px") / Data.bf("map", "node_band")
	for r: Dictionary in realms:
		var bg_name: String = Background.bg_name(int(r["id"]))
		var w: float = maxf(h * 16.0 / 9.0, min_w)
		if not bg_name.is_empty():
			var s: Sprite2D = Sprite2D.new()
			s.texture = Art.tex(bg_name)
			s.centered = false
			var ts: Vector2 = s.texture.get_size()
			w = maxf(ts.x * h / ts.y, min_w)
			var sc: float = maxf(h / ts.y, w / ts.x)
			s.scale = Vector2(sc, sc)
			s.position = Vector2(x, h - ts.y * sc)
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, w / sc, ts.y)
			add_child(s)
		else:
			var c: ColorRect = ColorRect.new()
			c.color = Color(r.get("tint", "#88cc66"))
			c.position = Vector2(x, 0)
			c.size = Vector2(w, h)
			add_child(c)
		_segments.append({"x": x, "w": w, "name": String(r["name"]), "id": int(r["id"])})
		x += w
	_width = x
	# Soft mist over the seams so the paintings blend.
	for i: int in range(1, _segments.size()):
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 0.98, 0.94, 0.45), Color(1, 1, 1, 0)])
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.gradient = g
		gt.width = 64
		gt.height = 8
		var m: Sprite2D = Sprite2D.new()
		m.texture = gt
		m.centered = false
		m.scale = Vector2(420.0 / 64.0, h / 8.0)
		m.position = Vector2(float(_segments[i]["x"]) - 210.0, 0)
		add_child(m)


func _node_pos(id: int) -> Vector2:
	var per: int = maxi(1, int(ceil(float(Data.level_count()) / maxf(1.0, float(_segments.size())))))
	var seg: Dictionary = _segments[mini((id - 1) / per, _segments.size() - 1)]
	var k: int = (id - 1) % per
	var band: float = Data.bf("map", "node_band")
	var x: float = float(seg["x"]) + float(seg["w"]) * ((1.0 - band) * 0.5 + band * k / maxf(1.0, per - 1.0))
	var y: float = _view.y * (Data.bf("map", "node_y") + Data.bf("map", "node_wave") * sin(id * 1.9))
	return Vector2(x, y)


func _build_nodes() -> void:
	var unlocked: int = int(Save.data["unlocked"])
	for id: int in range(1, Data.level_count() + 1):
		var pos: Vector2 = _node_pos(id)
		var n: Node2D = Node2D.new()
		n.position = pos
		n.z_index = 2
		add_child(n)
		var open: bool = id <= unlocked
		var got: int = Save.stars(id)
		var art: String = "map_node_locked" if not open else ("map_node_done" if got > 0 else "map_node")
		var boss: bool = bool(Data.level(id).get("boss", false))
		var base: Sprite2D = Art.sprite(art, NODE_SCALE * (Data.bf("map", "boss_scale") if boss else 1.0))
		n.add_child(base)
		if boss:
			var flag: Sprite2D = Art.sprite("flag", 1.3)
			flag.position = Vector2(30, -78)
			n.add_child(flag)
			var tag: Label = UIKit.label("BOSS", 22, Color("#ffd23a"), 6)
			tag.size = Vector2(100, 30)
			tag.position = Vector2(-50, -96)
			n.add_child(tag)
		if open:
			var l: Label = UIKit.label(str(id), 40, Color.WHITE, 10)
			l.size = Vector2(100, 60)
			l.position = Vector2(-50, -36)
			n.add_child(l)
			for i: int in 3:
				var st: Sprite2D = Art.sprite("star_full" if i < got else "star_empty", 0.32)
				st.position = Vector2((i - 1) * 28, 52 - (6 if i == 1 else 0))
				n.add_child(st)
		else:
			var lock: Sprite2D = Art.sprite("icon_lock", 0.9)
			lock.position = Vector2(0, -4)
			n.add_child(lock)
		if id == unlocked:
			var ring: Sprite2D = Art.sprite("dot", 6.0)
			ring.modulate = Color(1, 0.95, 0.5, 0.5)
			ring.z_index = -1
			n.add_child(ring)
			var tw: Tween = ring.create_tween().set_loops()
			tw.tween_property(ring, "scale", ring.scale * 1.3, 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(ring, "scale", ring.scale, 0.7).set_trans(Tween.TRANS_SINE)
			_marker = Art.unit_sprite("soldier_idle", 90)
			_marker.position = pos + Vector2(-58, -6)
			_marker.z_index = 3
			_marker_y = _marker.position.y
			add_child(_marker)
		_nodes.append({"id": id, "pos": pos, "node": n, "open": open})


func _build_path() -> void:
	var curve: Curve2D = Curve2D.new()
	for i: int in _nodes.size():
		var p: Vector2 = _nodes[i]["pos"]
		var prev: Vector2 = _nodes[maxi(0, i - 1)]["pos"]
		var nxt: Vector2 = _nodes[mini(_nodes.size() - 1, i + 1)]["pos"]
		var tan: Vector2 = (nxt - prev) * 0.25
		curve.add_point(p, -tan, tan)
	var unlocked: int = int(Save.data["unlocked"])
	var pts: PackedVector2Array = curve.tessellate_even_length(5, 30.0)
	for i: int in pts.size():
		var done: bool = pts[i].x <= float(_nodes[mini(unlocked, _nodes.size()) - 1]["pos"].x)
		var d: Sprite2D = Art.sprite("dot", 0.8 if done else 0.6)
		d.position = pts[i]
		d.modulate = Color(1, 0.96, 0.8, 0.95) if done else Color(0.25, 0.2, 0.15, 0.55)
		d.z_index = 1
		add_child(d)


func _build_ui() -> void:
	var ui: CanvasLayer = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var home: Button = UIKit.icon_button("icon_home", "orange", 70)
	UIKit.place(home, Vector2(0, 0), Vector2(18, 16), Vector2(70, 70))
	home.pressed.connect(Game.goto_menu)
	root.add_child(home)
	var shortcuts: Array = [["icon_upgrades", "green", func() -> void: Game.goto_meta("upgrades"), "upgrades"],
		["icon_shop", "orange", func() -> void: Game.goto_meta("shop"), "shop"],
		["icon_achievements", "blue", func() -> void: Game.goto_meta("achievements"), "achievements"]]
	if Save.stars(int(Data.b("modes", "challenges_unlock_level"))) > 0:
		shortcuts.append(["icon_challenges", "blue", Game.goto_challenges, "challenges"])
	for i: int in shortcuts.size():
		var b: Button = UIKit.icon_button(String(shortcuts[i][0]), String(shortcuts[i][1]), 70)
		UIKit.place(b, Vector2(0, 0), Vector2(100 + i * 82, 16), Vector2(70, 70))
		b.pressed.connect(shortcuts[i][2])
		if MetaFrame.has_news(String(shortcuts[i][3])):
			b.add_child(MetaFrame._red_dot(Vector2(54, -4)))
		UIFx.press_juice(b)
		root.add_child(b)
	var plate: PanelContainer = UIKit.wood_sign()
	_realm_label = UIKit.label("", 34, Color.WHITE, 9)
	plate.add_child(_realm_label)
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.place(c, Vector2(0.5, 1), Vector2(-300, -100), Vector2(600, 80))
	c.add_child(plate)
	root.add_child(c)
	var right: HBoxContainer = HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.place(right, Vector2(1, 0), Vector2(-1000, 18), Vector2(980, 64))
	for pair: Array in [["icon_crown", Progression.rank_name()], ["star_full", "%d / %d" % [Save.total_stars(), Data.level_count() * 3]]]:
		var chip: PanelContainer = UIKit.slate()
		var h: HBoxContainer = HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UIKit.tex_rect(String(pair[0]), 38))
		h.add_child(UIKit.label(String(pair[1]), 28))
		chip.add_child(h)
		right.add_child(chip)
	_bar = CurrencyBar.new(["coins", "gems", "blueprints"], false)
	right.add_child(_bar)
	root.add_child(right)
	var hint: Label = UIKit.label("Drag to explore · Tap a level to play", 22, Color.WHITE, 7, false)
	UIKit.place(hint, Vector2(0.5, 1), Vector2(-300, -26), Vector2(600, 30))
	root.add_child(hint)


func _scroll_to(x: float) -> void:
	_camera.position.x = clampf(x, 0.0, maxf(0.0, _width - _view.x))


func _process(delta: float) -> void:
	_t += delta
	if not _drag and absf(_vel) > 5.0:
		_scroll_to(_camera.position.x - _vel * delta)
		_vel = lerpf(_vel, 0.0, 1.0 - exp(-4.0 * delta))
	var mid: float = _camera.position.x + _view.x / 2.0
	for s: Dictionary in _segments:
		if mid >= float(s["x"]) and mid < float(s["x"]) + float(s["w"]):
			_realm_label.text = String(s["name"])
			# The map plays the music and surroundings of the realm in view, crossfading as you scroll.
			if int(s["id"]) != _sound_realm and not _drag:
				_sound_realm = int(s["id"])
				var key: String = String(Background.realm_info(_sound_realm).get("key", "blossom"))
				Sound.set_music(key, "map")
				Sound.set_surroundings(key, true)
	if _marker:
		_marker.position.y = _marker_y - absf(sin(_t * 4.0)) * 18.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e: InputEventScreenTouch = event
		if e.index != 0:
			return
		if e.pressed:
			_drag = true
			_moved = 0.0
			_press = e.position
			_last_x = e.position.x
			_vel = 0.0
		else:
			_drag = false
			if _moved < TAP_SLOP_PX:
				_tap(e.position + _camera.position)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index != 0 or not _drag:
			return
		var dx: float = d.position.x - _last_x
		_last_x = d.position.x
		_moved += absf(dx)
		_scroll_to(_camera.position.x - dx)
		_vel = d.velocity.x


func _tap(world_pos: Vector2) -> void:
	for e: Dictionary in _extras:
		if (e["pos"] as Vector2).distance_to(world_pos) < Data.bf("map", "extra_tap_px"):
			_tap_extra(e)
			return
	for n: Dictionary in _nodes:
		if (n["pos"] as Vector2).distance_to(world_pos) < 56.0:
			var node: Node2D = n["node"]
			if bool(n["open"]):
				Sound.play("map_select")
				var tw: Tween = node.create_tween()
				tw.tween_property(node, "scale", Vector2.ONE * 1.2, 0.1)
				tw.tween_callback(Game.goto_level_entry.bind(int(n["id"])))
			else:
				Sound.play("locked")
				var tw2: Tween = node.create_tween()
				for k: int in 3:
					tw2.tween_property(node, "position:x", float(n["pos"].x) + 8.0, 0.04)
					tw2.tween_property(node, "position:x", float(n["pos"].x) - 8.0, 0.04)
				tw2.tween_property(node, "position:x", float(n["pos"].x), 0.04)
			return


# ------------------------------------------------------------------------------------ chests + secrets
func _build_extras() -> void:
	for seg: Dictionary in _segments:
		var realm: int = int(seg["id"])
		var cp: Vector2 = Vector2(float(seg["x"]) + float(seg["w"]) * Data.bf("map", "chest_x"), _view.y * Data.bf("map", "chest_y"))
		var cn: Node2D = Node2D.new()
		cn.position = cp
		cn.z_index = 3
		add_child(cn)
		var e: Dictionary = {"pos": cp, "node": cn, "kind": "chest", "realm": realm}
		_extras.append(e)
		_draw_chest(e)
		var sl: int = Progression.secret_level(realm)
		if sl > 0 and Progression.secret_found(realm):
			var sp: Vector2 = Vector2(float(seg["x"]) + float(seg["w"]) * Data.bf("map", "secret_x"), _view.y * Data.bf("map", "secret_y"))
			var sn: Node2D = Node2D.new()
			sn.position = sp
			sn.z_index = 3
			add_child(sn)
			var glow: Sprite2D = Art.sprite("fx_rays", 0.9)
			glow.modulate = Color(0.75, 0.6, 1.0, 0.7)
			sn.add_child(glow)
			var gt: Tween = glow.create_tween().set_loops()
			gt.tween_property(glow, "rotation", TAU, 8.0).as_relative()
			sn.add_child(Art.sprite("icon_secret", 1.1))
			var st: int = Save.challenge_stars(sl)
			var l: Label = UIKit.label("SECRET" if st == 0 else "★ %d" % st, 22, Color("#e8d4ff"), 6)
			l.size = Vector2(140, 30)
			l.position = Vector2(-70, 34)
			sn.add_child(l)
			_extras.append({"pos": sp, "node": sn, "kind": "secret", "realm": realm, "level": sl})


## Next unclaimed tier of a realm chest (3 = all claimed).
func _chest_tier(realm: int) -> int:
	for t: int in 3:
		if Progression.chest_state(realm, t) != "claimed":
			return t
	return 3


func _draw_chest(e: Dictionary) -> void:
	var n: Node2D = e["node"]
	for c: Node in n.get_children():
		c.queue_free()
	var realm: int = int(e["realm"])
	var tier: int = _chest_tier(realm)
	var need: Array = Data.balance["realm_chests"]["stars"]
	var ready: bool = tier < 3 and Progression.chest_state(realm, tier) == "ready"
	if ready:
		var glow: Sprite2D = Art.sprite("fx_rays", 1.0)
		glow.modulate = Color(1, 0.9, 0.4, 0.8)
		n.add_child(glow)
		var gt: Tween = glow.create_tween().set_loops()
		gt.tween_property(glow, "rotation", TAU, 6.0).as_relative()
	var chest: Sprite2D = Art.sprite("chest_open" if tier >= 3 else "chest_closed", 1.0)
	n.add_child(chest)
	if ready:
		var bt: Tween = chest.create_tween().set_loops()
		bt.tween_property(chest, "rotation", 0.12, 0.12)
		bt.tween_property(chest, "rotation", -0.12, 0.12)
		bt.tween_property(chest, "rotation", 0.0, 0.12)
		bt.tween_interval(1.0)
	var text: String = "DONE" if tier >= 3 else ("OPEN!" if ready else "%d / %d" % [Progression.realm_stars(realm), int(need[tier])])
	var l: Label = UIKit.label(text, 22, Color("#ffd23a") if ready else Color.WHITE, 6)
	l.size = Vector2(140, 30)
	l.position = Vector2(-70, 36)
	n.add_child(l)
	if tier < 3:
		var pips: Label = UIKit.label("Chest %d/3" % (tier + 1), 16, Color("#ffe8c0"), 5, false)
		pips.size = Vector2(140, 24)
		pips.position = Vector2(-70, -66)
		n.add_child(pips)


func _tap_extra(e: Dictionary) -> void:
	var n: Node2D = e["node"]
	if String(e["kind"]) == "secret":
		Sound.play("reveal")
		Game.goto_level(int(e["level"]))
		return
	var realm: int = int(e["realm"])
	var tier: int = _chest_tier(realm)
	if tier >= 3 or Progression.chest_state(realm, tier) != "ready":
		Sound.play("locked")
		var tw: Tween = n.create_tween()
		tw.tween_property(n, "rotation", 0.15, 0.05)
		tw.tween_property(n, "rotation", -0.15, 0.08)
		tw.tween_property(n, "rotation", 0.0, 0.05)
		return
	# Claim saves silently first (Progression._pay), then the reward flies into the wallet.
	var reward: Dictionary = Progression.claim_chest(realm, tier)
	Sound.play("chest_open")
	Game.haptic()
	var screen: Vector2 = (e["pos"] as Vector2) - _camera.position
	UIFx.rays(UIFx.overlay(), screen, 360.0, 1.0)
	UIFx.confetti(screen)
	for k: String in ["coins", "gems", "blueprints"]:
		if int(reward.get(k, 0)) > 0:
			UIFx.fly_reward(screen, k, int(reward[k]), _bar, false)
	if reward.has("skin"):
		UIFx.stamp(UIFx.overlay(), screen + Vector2(0, -120), "NEW SKIN!", Color("#ffd23a"))
	_draw_chest(e)

