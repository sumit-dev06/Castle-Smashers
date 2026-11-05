class_name Level
extends Node2D
## Builds a level from data/levels/level_NNN.json and runs it in real time:
## INTRO (soldiers march in) → PLAY (you fire whenever the catapult is loaded, archers shoot on their
## own timers) → WON (all archers down, soldiers charge) / LOST (soldiers down or out of heroes).

enum State { INTRO, PLAY, WON, LOST }

const HIT_SOUND: Dictionary = {"wood": "wood_hit", "stone": "stone_hit", "straw": "wood_hit", "crystal": "ice_hit", "iron": "metal_hit", "ice": "ice_hit", "bell": "bell"}
const BREAK_SOUND: Dictionary = {"wood": "wood_break", "stone": "stone_break", "straw": "straw_break", "crystal": "crystal_break", "iron": "metal_hit", "ice": "ice_break", "bell": "bell"}

var level_id: int = 1
var test_mode: bool = false
## Story mode: play the level's animated cinematic, then start the level (plan screen after it).
var cinematic_mode: bool = false
## Training range for this hero before level_id (no stars, no energy, coach hints).
var training: String = ""
var _coach_tapped: bool = false
var training_from_workshop: bool = false
var cine: Cinematic
## Tests can turn the archers on while keeping the rest of test mode.
var archers_in_test: bool = false
var arrows_fired: int = 0
var data: Dictionary = {}
var state: State = State.INTRO
var world: Node2D
var fx: Fx
var camera: GameCamera
var hud: Hud
var catapult: Catapult
var stage: Stage
var realm_info: Dictionary = {}
var blocks: Array[Block] = []
var mechanisms: Array[CastleMechanism] = []
var captives: Array[Captive] = []
var archers: Array[Archer] = []
var soldiers: Array[Soldier] = []
var heroes: Array = []
var hero_index: int = 0
var projectile: Projectile
var projectiles: Array[Projectile] = []
var score: int = 0
var stars: int = 0
var world_right: float = 2000.0
var blocks_destroyed: int = 0
var blocks_total: int = 0
var captives_rescued: int = 0
var lose_reason: String = ""

var _time: float = 0.0
var _state_t: float = 0.0
var _loaded: bool = false
var _reload_t: float = -1.0
var _waiting: Array[Sprite2D] = []
## A hero tapped while the next one was mid-hop: swapped in as soon as the hop lands.
var _pick_after_hop: int = -1
## The current touch picked a waiting hero, so its release must not trigger an ability.
var _press_picked: bool = false
var _dots: Array[Sprite2D] = []
var _aiming: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_ms: int = 0
var _pressed: bool = false
var _aim_vel: Vector2 = Vector2.ZERO
var _last_creak_power: float = 0.0
var _hinted: Dictionary = {}
var _autoshot_done: bool = false
var _slowmo: bool = false
var _gravity: float = 980.0
var _end_t: float = -1.0
var _out_t: float = 0.0
var _tutorial: Node2D
var _waiting_shadows: Array[Sprite2D] = []
var bolts: Array[Bolt] = []
var tethers: Array[Tether] = []
var gadgets: Array[Gadget] = []
## Level challenge facts (Feats): hero powers used and soldiers knocked out this attempt.
var abilities_used: int = 0
var soldiers_lost: int = 0
var background: Background
## Current horizontal wind acceleration on heroes in flight (px/s², + = toward the fortress).
var wind_now: float = 0.0
var boss: Archer
var rig: BossRig
var mode: ModeRules
var _play_t: float = 0.0
## Siege weapon + upgrades (Progression), neutral in test mode.
var _w_speed: float = 1.0
var _w_grav: float = 1.0
var _w_mass: float = 1.0
var _w_reload: float = 1.0
var _w_damage: float = 1.0
var _w_ability: float = 1.0
var _guards_total: int = 0
var _boss_phase: int = 0
var _fire_mult: float = 1.0
var _wind_t: float = 0.0
var chain: Chain = Chain.new()
var replay: Replay
var chain_bonus: int = 0
var archers_defeated: int = 0
var _chain_slowmo_t: float = -100.0
## The plan-the-assault overlay is open: the level waits in INTRO.
var _planning: bool = false
## Out of boulders with the fortress standing: the HUD offers +1 Rocky (ad) / Hellfire / give up.
var second_chance_open: bool = false
var rocky_ad_used: bool = false
var hellfire_running: bool = false


func _ready() -> void:
	data = Data.training(training) if not training.is_empty() else Data.level(level_id) if not is_challenge() else Data.challenge(level_id)
	if is_challenge() or not training.is_empty():
		heroes = (data.get("heroes", []) as Array).duplicate()
	else:
		heroes = LoadoutRules.recommended(data, level_id) if test_mode else LoadoutRules.saved_or_recommended(data, level_id)
	apply_weapon()
	mode = ModeRules.make(self)
	if mode and not mode.heroes_override().is_empty():
		heroes = mode.heroes_override()
	world_right = float(data.get("camera_right", 2000))
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	Events.soldier_knocked_out.connect(_on_soldier_ko)

	camera = GameCamera.new()
	camera.left = Data.bf("camera", "left")
	camera.right = world_right
	camera.content_top = float(data.get("camera_top", 0.0))
	camera.tracked = projectiles
	add_child(camera)
	realm_info = Background.realm_info(int(data.get("realm", 1)))
	var bg: Background = Background.new()
	background = bg
	bg.camera = camera
	bg.realm = int(data.get("realm", 1))
	bg.variant = int(data.get("bg_variant", 0))
	add_child(bg)
	world = Node2D.new()
	add_child(world)
	stage = Stage.new()
	stage.setup(data, realm_info, world_right)
	world.add_child(stage)
	catapult = Catapult.new()
	world.add_child(catapult)
	for md: Dictionary in data.get("mechanisms", []):
		spawn_mechanism(md)
	for rd: Dictionary in data.get("ramps", []):
		var ramp: Ramp = Ramp.new()
		ramp.setup(rd)
		world.add_child(ramp)
	for i: int in int(data.get("soldiers", 4)):
		var s: Soldier = Soldier.new()
		s.setup(Vector2(Data.bf("soldiers", "start_x") + i * Data.bf("soldiers", "spacing"), 0), not test_mode)
		world.add_child(s)
		soldiers.append(s)
	var data_blocks: Array[Block] = []
	for bd: Dictionary in data.get("blocks", []):
		var b: Block = Block.new()
		b.setup(String(bd["type"]), self, Vector2(float(bd["x"]), float(bd["y"])), float(bd.get("rot", 0.0)), bd)
		world.add_child(b)
		blocks.append(b)
		data_blocks.append(b)
	blocks_total = blocks.size()
	for bd2: Dictionary in data.get("bolts", []):
		var ia: int = int(bd2["a"])
		var ib: int = int(bd2["b"])
		if ia < data_blocks.size() and ib < data_blocks.size():
			var bolt: Bolt = Bolt.new()
			bolt.setup(self, data_blocks[ia], data_blocks[ib])
			world.add_child(bolt)
			bolts.append(bolt)
	for td: Dictionary in data.get("tethers", []):
		var ta: int = int(td["a"])
		var tb: int = int(td.get("b", -1))
		if ta < data_blocks.size() and tb < data_blocks.size():
			var tether: Tether = Tether.new()
			tether.setup(self, td, data_blocks[ta], data_blocks[tb] if tb >= 0 else null)
			if td.has("launch") and int(td["launch"]["payload"]) < data_blocks.size():
				tether.payload = data_blocks[int(td["launch"]["payload"])]
			world.add_child(tether)
			tethers.append(tether)
	var gi: int = 0
	for gd: Dictionary in data.get("gadgets", []):
		var gadget: Gadget = Gadget.new()
		world.add_child(gadget)
		gadget.setup(self, gd, gi, data_blocks)
		gadgets.append(gadget)
		gi += 1
	for gadget2: Gadget in gadgets:
		if gadget2.kind == "portal" and gadget2.cfg.has("pair") and int(gadget2.cfg["pair"]) < gadgets.size():
			gadget2.partner = gadgets[int(gadget2.cfg["pair"])]
	for ad: Dictionary in data.get("archers", []):
		spawn_archer(Vector2(float(ad["x"]), float(ad["y"])))
	var bu: Dictionary = data.get("boss_unit", {})
	if not bu.is_empty():
		boss = spawn_archer(Vector2(float(bu["x"]), float(bu["y"])))
		boss.make_boss(String(bu["name"]), float(bu.get("hp", Data.bf("boss", "hp"))))
	if BossRig.wanted(self):
		rig = BossRig.new()
		world.add_child(rig)
		rig.setup(self)
		rig.status_changed.connect(_on_rig_status)
	for cd: Dictionary in data.get("captives", []):
		var captive: Captive = Captive.new()
		captive.setup(self, cd)
		world.add_child(captive)
		captives.append(captive)
	for i: int in heroes.size():
		var sh: Sprite2D = Art.sprite("shadow", 0.9)
		_shadow_scale = sh.scale
		sh.modulate.a = 0.75
		world.add_child(sh)
		_waiting_shadows.append(sh)
		var w: Sprite2D = Projectile.make_sprite(String(heroes[i]))
		w.z_index = int(Data.b("catapult", "hero_wait_z"))
		sh.z_index = w.z_index - 1
		world.add_child(w)
		_waiting.append(w)
	_layout_waiting()
	fit_camera()
	fx = Fx.new()
	if not test_mode:
		fx.trail_color = Progression.trail_color()
	world.add_child(fx)
	replay = Replay.new()
	replay.level = self
	add_child(replay)
	for i: int in int(Data.b("catapult", "dots")):
		var d: Sprite2D = Art.sprite("dot", 1.0 - 0.5 * i / Data.bf("catapult", "dots"))
		d.visible = false
		d.z_index = 4
		world.add_child(d)
		_dots.append(d)
	if not test_mode:
		_build_foreground()
	hud = Hud.new()
	hud.level = self
	add_child(hud)
	if training.is_empty():
		hud.set_title(level_id, String(data.get("name", "")))
	else:
		hud.set_title_text(String(data.get("name", "")))
		hud.training_skip(leave_training)
		if not test_mode and not Game.args.has("autoshot"):
			hud.show_training_intro.call_deferred(training, _coach.bind("aim"))
	if mode:
		add_child(mode)
		mode.setup()
	_update_hud()
	if test_mode:
		_enter(State.PLAY)
		_load_now()
		return
	Sound.set_music("boss" if boss != null else Background.look(realm_info), "aim")
	Sound.set_surroundings(Background.look(realm_info))
	var march_s: float = Data.bf("soldiers", "march_s")
	for i: int in soldiers.size():
		var s2: Soldier = soldiers[i]
		s2.march_in(Vector2(Data.bf("soldiers", "march_from_x") - i * Data.bf("soldiers", "march_gap"), 0),
				march_s, 0.12 * (soldiers.size() - 1 - i))
	_enter(State.INTRO)
	if cinematic_mode:
		hud.visible = false
		_play_cinematic(data.get("cinematic", []), false)
		cine.finished.connect(func() -> void:
			Save.mark_seen("story:%d" % level_id)
			Game.skip_flyover = true
			Game.goto_level(level_id))
		return
	_planning = _wants_plan()
	var skip: bool = Game.skip_flyover
	Game.skip_flyover = false
	if skip:
		if _planning:
			get_tree().create_timer(Data.bf("loadout", "plan_delay_s")).timeout.connect(_open_plan)
		return
	hud.banner("Level %d" % level_id, String(data.get("name", "")))
	var fly: Array = _flyover_beats()
	if fly.size() <= 1:
		# Nothing new to point out: no camera tour, straight to planning (or to play).
		if _planning:
			get_tree().create_timer(Data.bf("loadout", "plan_delay_s")).timeout.connect(_open_plan)
		return
	_play_cinematic(fly, true)
	if _planning:
		cine.finished.connect(_open_plan)


# ------------------------------------------------------------------------------------ plan the assault
## Campaign levels let the player choose heroes after seeing the fortress. Challenges, boss rush,
## modes with fixed heroes and debug autoshots keep their heroes.
func _wants_plan() -> bool:
	if test_mode or is_challenge() or not training.is_empty() or not Game.rush.is_empty():
		return false
	if mode and not mode.heroes_override().is_empty():
		return false
	return not (Game.args.has("autoshot") or Game.args.has("force-win") or Game.args.has("no-plan"))


func _open_plan() -> void:
	if not is_inside_tree() or is_finished():
		return
	hud.visible = false
	var plan: LoadoutScreen = LoadoutScreen.new()
	plan.level = self
	plan.level_id = level_id
	plan.confirmed.connect(func(kinds: Array[String]) -> void:
		set_heroes(kinds)
		hud.visible = true
		_planning = false)
	add_child(plan)


## Siege weapon multipliers (Progression); neutral in test mode. Called again when the plan screen
## switches weapons.
func apply_weapon() -> void:
	if test_mode:
		return
	_w_speed = Progression.speed_mult()
	_w_grav = Progression.gravity_scale()
	_w_mass = Progression.mass_mult()
	_w_reload = Progression.reload_mult()
	_w_damage = Progression.damage_mult()
	_w_ability = Progression.ability_mult()
	if catapult:
		catapult.set_appearance(Progression.weapon(), Progression.equipped("skins"))


## Ammo tray tap: hero `i` (still waiting) goes into the bucket next; the one that was loaded takes
## its place in the queue. Ignored mid-hop, while aiming, or for heroes already fired.
func choose_hero(i: int) -> bool:
	if is_finished() or _aiming or i < hero_index or i >= heroes.size():
		return false
	if i == hero_index:
		return true
	if _waiting[hero_index].has_meta("hopping"):
		_pick_after_hop = i
		return true
	var a: String = heroes[hero_index]
	heroes[hero_index] = heroes[i]
	heroes[i] = a
	var w: Sprite2D = _waiting[hero_index]
	_waiting[hero_index] = _waiting[i]
	_waiting[i] = w
	var sh: Sprite2D = _waiting_shadows[hero_index]
	_waiting_shadows[hero_index] = _waiting_shadows[i]
	_waiting_shadows[i] = sh
	for k: int in [hero_index, i]:
		_waiting[k].scale = _hero_scale(heroes[k])
	if _loaded:
		catapult.load_hero(heroes[hero_index])
		Sound.play("pop", 0.6)
	_layout_waiting()
	_update_hud()
	return true


## Frames the whole fortress: the highest block, unit (boss crown and shield), gantry or mechanism
## must sit below the HUD band, and the furthest piece inside the right edge. Uses the live bodies,
## so it can't drift from the level data. Returns [content_top, right].
func fit_camera() -> Array:
	var top: float = minf(0.0, float(data.get("camera_top", 0.0)))
	var right: float = world_right
	for b: Block in blocks:
		var r: float = b.size.length() * 0.5
		top = minf(top, b.global_position.y - r)
		right = maxf(right, b.global_position.x + r + 60.0)
	for a: Archer in archers:
		top = minf(top, a.visual_top())
		right = maxf(right, a.global_position.x + 90.0)
	for t: Tether in tethers:
		if t.cfg.has("frame"):
			top = minf(top, float(t.cfg["frame"]["top"]) - 30.0)
		top = minf(top, t.hook_point().y - 30.0)
	top -= Data.bf("camera", "content_margin_px")
	camera.content_top = top
	camera.right = right
	world_right = right
	camera.hud_top = Data.bf("camera", "boss_hud_top_px" if boss != null else "hud_top_px")
	if Game.args.has("debug-fit"):
		var bz: float = camera.base_zoom()
		print("FIT level %d top %.0f right %.0f zoom %.3f frac %.3f view %s hud %.0f" % [level_id, top, right, bz, camera._frac, camera.get_viewport_rect().size, camera.hud_top])
	return [top, right]


## Replaces the ammo queue before the first shot (plan screen).
func set_heroes(kinds: Array[String]) -> void:
	for w: Sprite2D in _waiting:
		w.queue_free()
	for sh: Sprite2D in _waiting_shadows:
		sh.queue_free()
	_waiting.clear()
	_waiting_shadows.clear()
	heroes = []
	hero_index = 0
	add_heroes(kinds)


# ------------------------------------------------------------------------------------ cinematics
func _play_cinematic(beats: Array, quick: bool) -> void:
	cine = Cinematic.new()
	cine.level = self
	cine.beats = beats
	cine.quick = quick
	add_child(cine)
	cine.play()


## Every level opens on its fortress: the camera starts there, points out what is new or dangerous
## (level JSON "callouts": [{"target", "label"}]), then sweeps back to the catapult.
## Only what the player has not met before is pointed out (Save.seen); a level with nothing new
## returns just the opening pan, which the caller skips.
func _flyover_beats() -> Array:
	var beats: Array = [{"t": "pan", "to": "fortress", "zoom": 0.0, "s": 0.9}]
	var fresh: bool = not Save.seen("level:%d" % level_id)
	for c: Variant in data.get("callouts", []):
		var key: String = "callout:" + String(c["label"])
		if fresh and not Save.seen(key):
			beats.append({"t": "focus", "target": String(c["target"]), "label": String(c["label"])})
			Save.mark_seen(key, false)
	if is_instance_valid(boss) and not Save.seen("boss:%d" % level_id):
		beats.append({"t": "focus", "target": "boss", "label": boss.boss_name.to_upper()})
		Save.mark_seen("boss:%d" % level_id, false)
	Save.mark_seen("level:%d" % level_id)
	return beats


# ------------------------------------------------------------------------------------ building
## Close-up framing in the screen corners, like the reference art. Screen space, above the world.
## Uses the realm's AI corner images (fg_<realm>_left/right) when they exist, else tinted SVG leaves.
func _build_foreground() -> void:
	var layer_fg: CanvasLayer = CanvasLayer.new()
	layer_fg.layer = 1
	add_child(layer_fg)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_fg.add_child(root)
	var key: String = Background.art_key(realm_info, "fg_%s_right")
	if Art.has_ai("fg_%s_left" % key) or Art.has_ai("fg_%s_right" % key):
		for side: int in 2:
			# The left corner sits over the waiting heroes: keep it low so they stay in view.
			# A realm with a bulky right corner (Storm Crags' tree) sets a lower fg_height_frac.
			var frac: float = Data.bf("stage", "fg_ai_left_height_frac") if side == 0 \
					else float(realm_info.get("fg_height_frac", Data.bf("stage", "fg_ai_height_frac")))
			var h: float = get_viewport_rect().size.y * frac
			var art_name: String = "fg_%s_%s" % [key, "left" if side == 0 else "right"]
			var mirror: bool = false
			if not Art.has_ai(art_name):
				# A realm with only one corner piece mirrors it into the other corner.
				art_name = "fg_%s_%s" % [key, "right" if side == 0 else "left"]
				mirror = true
				if not Art.has_ai(art_name):
					continue
			var tr: TextureRect = TextureRect.new()
			tr.texture = Art.tex(art_name)
			tr.flip_h = mirror
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			var tsz: Vector2 = Art.svg_size(art_name)
			var sz2: Vector2 = Vector2(h * tsz.x / tsz.y, h)
			tr.anchor_left = float(side)
			tr.anchor_right = float(side)
			tr.anchor_top = 1.0
			tr.anchor_bottom = 1.0
			tr.offset_left = -sz2.x if side == 1 else 0.0
			tr.offset_right = 0.0 if side == 1 else sz2.x
			tr.offset_top = -sz2.y
			tr.offset_bottom = 0.0
			root.add_child(tr)
		return
	var fg_tint: Color = Color(String(realm_info.get("stage_tint", "#ffffff")))
	# [art, anchor (0/1 per axis), scale, flip, offset from that corner]
	var items: Array = [
		["fg_leaves", Vector2(0, 0), 0.92, false, Vector2(-8, -24)],
		["fg_leaves", Vector2(1, 0), 0.78, true, Vector2(28, -30)],
		["fg_fence", Vector2(0, 1), 0.7, false, Vector2(-40, 40)],
		["fg_bush", Vector2(1, 1), 0.7, false, Vector2(60, 50)],
	]
	for it: Array in items:
		var t: TextureRect = TextureRect.new()
		t.texture = Art.tex(String(it[0]))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.flip_h = bool(it[3])
		t.modulate = fg_tint
		var sz: Vector2 = Art.svg_size(String(it[0])) * float(it[2])
		var anchor: Vector2 = it[1]
		var off: Vector2 = Vector2(it[4]) + Vector2(-sz.x if anchor.x > 0.5 else 0.0, -sz.y if anchor.y > 0.5 else 0.0)
		t.anchor_left = anchor.x
		t.anchor_right = anchor.x
		t.anchor_top = anchor.y
		t.anchor_bottom = anchor.y
		t.offset_left = off.x
		t.offset_top = off.y
		t.offset_right = off.x + sz.x
		t.offset_bottom = off.y + sz.y
		root.add_child(t)


## Sprite scale of a hero as Projectile.make_sprite() builds it (cached per kind).
var _hero_scales: Dictionary = {}
var _shadow_scale: Vector2 = Vector2.ONE


func _hero_scale(kind: String) -> Vector2:
	if not _hero_scales.has(kind):
		var s: Sprite2D = Projectile.make_sprite(kind)
		_hero_scales[kind] = s.scale
		s.free()
	return _hero_scales[kind]


## Waiting heroes are drawn hero_wait_scale larger (looks only: physics and abilities unchanged).
func _layout_waiting() -> void:
	var xs: Array = Data.b("catapult", "hero_wait_x")
	var slot: int = 0
	for i: int in _waiting.size():
		var w: Sprite2D = _waiting[i]
		if i >= heroes.size() or i < hero_index or (i == hero_index and _loaded):
			w.visible = false
			continue
		w.visible = true
		var big: float = Data.bf("catapult", "hero_wait_scale")
		var r: float = float(Data.projectiles[heroes[i]]["radius"]) * big
		w.position = Vector2(float(xs[mini(slot, xs.size() - 1)]), -r + Data.bf("catapult", "hero_sink_px"))
		w.scale = _hero_scale(heroes[i]) * big
		w.set_meta("base_y", w.position.y)
		w.set_meta("base_scale", w.scale)
		_waiting_shadows[i].scale = _shadow_scale * big
		slot += 1


func _process(_delta: float) -> void:
	if OS.is_debug_build() and Game.args.has("no-hud") and hud.visible:
		hud.visible = false  # clean captures for the website / store
	_tick_coach()
	var t: float = Time.get_ticks_msec() * 0.001
	# Waiting heroes sit on the ground and breathe (squash), so they never look like they float.
	for i: int in _waiting.size():
		var w: Sprite2D = _waiting[i]
		var sh: Sprite2D = _waiting_shadows[i]
		sh.visible = w.visible and not w.has_meta("hopping")
		if w.visible and w.has_meta("base_y") and not w.has_meta("hopping"):
			var k: float = sin(t * 3.0 + i * 1.3) * 0.05
			var bs: Vector2 = w.get_meta("base_scale")
			var r: float = float(Data.projectiles[heroes[i]]["radius"]) * Data.bf("catapult", "hero_wait_scale")
			w.scale = Vector2(bs.x * (1.0 + k), bs.y * (1.0 - k))
			w.position.y = float(w.get_meta("base_y")) + r * k
			sh.position = Vector2(w.position.x, float(w.get_meta("base_y")) + r - 3.0)


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0


func damage_enabled() -> bool:
	return _time > Data.bf("physics", "damage_grace_s")


func is_finished() -> bool:
	return state == State.WON or state == State.LOST


func is_loaded() -> bool:
	return _loaded


# ------------------------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	_time += delta
	_state_t += delta
	_prune_projectiles()
	var cb: int = chain.tick(_time)
	if cb >= 0:
		_pay_chain(cb)
	match state:
		State.INTRO:
			if _state_t > Data.bf("soldiers", "march_s") + 0.5 and not cinematic_mode and not _planning and (cine == null or not cine.running):
				_enter(State.PLAY)
				_reload_t = 0.0
				_log_level_start()
				if boss == null:
					Sound.stinger("siege_start")
				var feat: Dictionary = Feats.shown_for_level(level_id) if training.is_empty() and not is_challenge() else {}
				if not feat.is_empty() and not Game.args.has("autoshot"):
					hud.hint("CHALLENGE: %s" % Feats.goal_text(feat), 3.5, "icon_achievements")
				if not bool(Save.data.get("tutorial_done", false)):
					_show_tutorial()
		State.PLAY:
			if second_chance_open or hellfire_running:
				return
			_play_t += delta
			if mode:
				mode.tick(delta)
			_tick_wind(delta)
			_check_ropes()
			_tick_reload(delta)
			if not test_mode or archers_in_test:
				_tick_archers(delta)
			_check_end(delta)
		State.WON, State.LOST:
			pass


func _prune_projectiles() -> void:
	for i: int in range(projectiles.size() - 1, -1, -1):
		var p: Projectile = projectiles[i]
		if not is_instance_valid(p) or p.done:
			projectiles.remove_at(i)
		elif p.age > Data.bf("physics", "projectile_max_s"):
			p.finish()


func _tick_reload(delta: float) -> void:
	if _loaded or _reload_t < 0.0 or hero_index >= heroes.size():
		return
	_reload_t -= delta
	if _reload_t <= 0.0:
		_reload_t = -1.0
		_hop_next_hero()


## The next waiting hero jumps into the bucket.
func _hop_next_hero() -> void:
	var w: Sprite2D = _waiting[hero_index]
	var target: Vector2 = catapult.bucket_global(String(heroes[hero_index])) - catapult.global_position
	var hop: float = Data.bf("catapult", "hop_s")
	w.set_meta("hopping", true)
	var start: Vector2 = w.position
	var from_scale: Vector2 = w.scale
	var to_scale: Vector2 = _hero_scale(String(heroes[hero_index]))
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void:
		w.scale = from_scale.lerp(to_scale, k)
		w.position = start.lerp(target, k) + Vector2(0, -sin(k * PI) * 110.0)
		w.rotation = k * TAU * 0.5, 0.0, 1.0, hop)
	tw.tween_callback(func() -> void:
		w.remove_meta("hopping")
		w.rotation = 0.0
		_load_now())


func _load_now() -> void:
	if hero_index >= heroes.size():
		return
	var kind: String = String(heroes[hero_index])
	catapult.load_hero(kind)
	_loaded = true
	_layout_waiting()
	_update_hud()
	Sound.play("pop", 0.6)
	if _pick_after_hop > hero_index:
		var pick: int = _pick_after_hop
		_pick_after_hop = -1
		choose_hero(pick)
		kind = String(heroes[hero_index])
	_pick_after_hop = -1
	_coach("aim")
	if not test_mode and (Sound.state == "destruction" or Sound.state == "flight"):
		Sound.music_state("aim")
	if not test_mode and not _hinted.has(kind) and kind != "stone" and not Save.seen("hint:" + kind):
		hud.hint("%s: %s" % [String(Data.projectiles[kind]["name"]), String(Data.projectiles[kind]["ability"])], 3.5,
				String(Data.projectiles[kind]["texture"]))
		Save.mark_seen("hint:" + kind)
	_hinted[kind] = true
	# Debug capture: --force-win=seconds ends the level as a win (results screen screenshots).
	if OS.is_debug_build() and Game.args.has("hellfire") and not hellfire_running and not _autoshot_done:
		_autoshot_done = true  # debug capture: --hellfire=seconds runs a strike without spending one
		get_tree().create_timer(float(Game.args["hellfire"])).timeout.connect(_hellfire_strike)
	if OS.is_debug_build() and Game.args.has("second-chance") and not _autoshot_done:
		_autoshot_done = true
		get_tree().create_timer(float(Game.args["second-chance"])).timeout.connect(func() -> void:
			hero_index = heroes.size()
			_out_of_heroes())
	if OS.is_debug_build() and Game.args.has("force-win") and not _autoshot_done and not Game.args.has("autoshot"):
		_autoshot_done = true
		get_tree().create_timer(float(Game.args["force-win"])).timeout.connect(func() -> void:
			if not is_finished():
				score = maxi(score, int((data.get("star_scores", [0, 0, 0]) as Array)[2]))
				force_finish(true))
	if Game.args.has("autoshot") and not _autoshot_done:
		_autoshot_done = true
		# "angle,power,ability_delay" or several shots "a,p,d;a,p,d;..." (debug captures and trailers).
		_autoshots(String(Game.args["autoshot"]).split(";"), 0)


## Fires shot `i` of a debug autoshot list once the catapult is loaded, then the next one.
func _autoshots(shots: PackedStringArray, i: int) -> void:
	if i >= shots.size() or is_finished() or not is_inside_tree():
		return
	# --autoshot-rapid: fire as soon as the catapult reloads (a quick player), not when the last shot stops.
	var rapid: bool = Game.args.has("autoshot-rapid")
	if not _loaded or (not rapid and is_instance_valid(projectile) and not projectile.is_queued_for_deletion() and i > 0 and projectile.linear_velocity.length() > 40.0):
		get_tree().create_timer(0.25).timeout.connect(_autoshots.bind(shots, i))
		return
	var parts: PackedStringArray = shots[i].split(",")
	var ang: float = deg_to_rad(float(parts[0]))
	var power: float = float(parts[1]) if parts.size() > 1 else 1.0
	var vel: Vector2 = Vector2(cos(ang), -sin(ang)) * power * Data.bf("catapult", "max_speed")
	get_tree().create_timer(0.4 if i == 0 or rapid else 0.9).timeout.connect(func() -> void:
		fire_hero(vel)
		var fired: Projectile = projectile
		if parts.size() > 2:
			get_tree().create_timer(float(parts[2])).timeout.connect(func() -> void:
				if is_instance_valid(fired) and fired.use_ability():
					coach_ability_used())
		_autoshots(shots, i + 1))


func _tick_archers(delta: float) -> void:
	if rig:
		rig.tick(delta)
	if _living_soldiers().is_empty():
		return
	var draw: float = Data.bf("archers", "draw_time_s")
	var busy: float = Data.bf("archers", "busy_speed")
	for a: Archer in archers:
		if not is_instance_valid(a) or a.dead or a.is_engineer:
			continue
		if a.speed() > busy or absf(a.rotation) > 0.6:
			a.relax()
			a.cooldown = maxf(a.cooldown, draw + 0.3)
			continue
		a.cooldown -= delta
		if a.cooldown <= draw and not a.drawing:
			a.draw_bow()
		if a.cooldown <= 0.0:
			_shoot(a)
			a.cooldown = randf_range(Data.bf("archers", "fire_min_s"), Data.bf("archers", "fire_max_s")) * _fire_mult


func _living_soldiers() -> Array[Soldier]:
	var out: Array[Soldier] = []
	for s: Soldier in soldiers:
		if not s.knocked_out:
			out.append(s)
	return out


func spawn_archer(pos: Vector2) -> Archer:
	var a: Archer = Archer.new()
	a.setup(self, pos)
	a.cooldown = randf_range(Data.bf("archers", "first_min_s"), Data.bf("archers", "first_max_s"))
	world.add_child(a)
	archers.append(a)
	return a


func _shoot(a: Archer) -> void:
	_shoot_one(a)
	if a.is_boss and _boss_phase >= 2:
		for i: int in int(Data.b("boss", "volley")) - 1:
			get_tree().create_timer(0.18 * (i + 1), false).timeout.connect(func() -> void:
				if is_instance_valid(a) and not a.dead:
					_shoot_one(a))


func _shoot_one(a: Archer) -> void:
	a.relax()
	var living: Array[Soldier] = _living_soldiers()
	if living.is_empty():
		return
	var target: Soldier = living[randi() % living.size()]
	var spread: float = Data.bf("archers", "aim_spread_px")
	var to: Vector2 = target.body_center() + Vector2(randf_range(-spread, spread), 0)
	var from: Vector2 = a.bow_point()
	var t: float = Data.bf("archers", "flight_time_base_s") + Data.bf("archers", "flight_time_per_px") * absf(to.x - from.x)
	var arrow: Arrow = Arrow.new()
	world.add_child(arrow)
	arrow.setup(from, to, t, soldiers, stage)
	arrows_fired += 1
	Sound.play_at("arrow_shoot", from, 0.8)


func _check_end(delta: float) -> void:
	if is_finished():
		return
	if mode and mode.check_end(delta):
		return
	if archers.is_empty() and captives_rescued >= captives.size() and not (mode and mode.blocks_win()):
		if _end_t < 0.0:
			_end_t = 0.0
		_end_t += delta
		if _end_t > Data.bf("physics", "win_delay_s"):
			_finish(true)
		return
	if _living_soldiers().is_empty():
		lose_reason = "Your soldiers were defeated!"
		_end_t = maxf(_end_t, 0.0) + delta
		if _end_t > Data.bf("physics", "lose_delay_s"):
			_finish(false)
		return
	if hero_index >= heroes.size() and projectiles.is_empty():
		_out_t += delta
		if (_out_t > Data.bf("physics", "settle_min_s") and _all_still()) or _out_t > Data.bf("physics", "settle_max_s"):
			lose_reason = "Out of heroes!"
			_out_of_heroes()
	else:
		_out_t = 0.0


func _all_still() -> bool:
	var lim: float = Data.bf("physics", "settle_speed")
	for b: Block in blocks:
		if is_instance_valid(b) and not b.held and ((not b.sleeping and b.speed() > lim) or b.is_burning()):
			return false
	for a: Archer in archers:
		if is_instance_valid(a) and not a.sleeping and a.speed() > lim:
			return false
	return true


func fire_hero(vel: Vector2) -> void:
	if state != State.PLAY or not _loaded:
		return
	var kind: String = String(heroes[hero_index])
	hero_index += 1
	_loaded = false
	projectile = Projectile.new()
	projectile.setup(kind, self, _w_damage, _w_ability)
	projectile.position = catapult.launch_point(kind)
	projectile.gravity_scale *= _w_grav
	projectile.mass *= _w_mass
	world.add_child(projectile)
	projectile.launch(projectile.position, vel * _w_speed)
	projectiles.append(projectile)
	catapult.fire()
	_hide_dots()
	_reload_t = Data.bf("catapult", "reload_s") * _w_reload
	_update_hud()
	_hide_tutorial()
	_coach_shot_start()
	if not test_mode:
		Analytics.set_crash_key("phase", "physics")
		Analytics.set_crash_key("projectile", kind)
		Analytics.breadcrumb("shot:%s:%s" % [kind, Progression.weapon()])
	if not test_mode and not bool(Save.data.get("tutorial_done", false)):
		Save.data["tutorial_done"] = true
		Save.write()
		Analytics.event("tutorial_complete", {"level_id": level_id})
	Sound.play_at("launch", catapult.global_position)
	Game.haptic()
	Events.projectile_launched.emit(kind)


func _finish(won: bool) -> void:
	if is_finished():
		return
	_enter(State.WON if won else State.LOST)
	var cb: int = chain.finish()
	if cb >= 0:
		_pay_chain(cb)
	_hide_dots()
	catapult.set_pull(0.0)
	var unused_pts: int = 0
	if won and not (mode and mode.kind == "time_attack"):
		unused_pts = (heroes.size() - hero_index) * int(Data.b("score", "unused_hero"))
		score += unused_pts
		for s: Soldier in soldiers:
			s.charge(stage.ledge_right - Data.bf("stage", "soldier_stop_px"))
	_update_hud()
	count_match()
	if not training.is_empty():
		Save.mark_seen("training:" + training)
		get_tree().create_timer(float(Data.balance["result_delay_s"]), true, false, true).timeout.connect(func() -> void:
			Engine.time_scale = 1.0
			Sound.stinger("win" if won else "lose")
			hud.show_training_done(won, training))
		return
	stars = (mode.stars(stars_for(score)) if mode else stars_for(score)) if won else 0
	var earned: Dictionary = {}
	if not test_mode:
		Progression.best("chain_best", chain.best)
		if won:
			Progression.bump("wins")
			if training.is_empty() and not is_challenge() and not (mode and mode.kind == "boss_rush") \
						and not Game.args.has("autoshot"):
				var got: Array = Feats.on_win(level_id, {"shots": hero_index, "abilities": abilities_used,
						"soldiers_lost": soldiers_lost, "chain": chain.best, "time": _play_t})
				for f: Dictionary in got:
					hud.hint("CHALLENGE DONE: %s! Claim it in Achievements." % Feats.goal_text(f), 4.0, "icon_achievements")
	if mode and mode.kind == "boss_rush" and not test_mode:
		if won and Game.rush_advance(self):
			return
		if won:
			stars = Game.rush_stars()
			earned = Save.record_rush(Game.rush_total_time())
		Game.rush.clear()
	var old_best: int = Save.challenge_best(level_id) if level_id > Data.CHALLENGE_BASE else int(Save.data["best"].get(str(level_id), 0))
	if not test_mode and not (mode and mode.kind == "boss_rush"):
		earned = Save.record_result(level_id, won, stars, score, boss != null)
	if not test_mode:
		var common: Dictionary = {"level_id": level_id, "attempt": _attempt(), "duration_s": int(_play_t),
				"weapon": Progression.weapon(), "shots_used": hero_index}
		if won:
			common.merge({"stars": stars, "score": score, "used_hellfire": hellfire_running or Analytics.last("hellfire_used").get("level_id", -1) == level_id})
			Analytics.event("level_complete", common)
		else:
			common["reason"] = lose_reason
			Analytics.event("level_failed", common)
	Events.level_finished.emit(level_id, won, stars, score)
	if won and not test_mode:
		Notifications.maybe_ask_permission(level_id)
	if test_mode:
		return
	var t: SceneTreeTimer = get_tree().create_timer(float(Data.balance["result_delay_s"]), true, false, true)
	t.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		Sound.stinger("win" if won else "lose")
		hud.show_result(won, stars, score, earned, level_id < Data.level_count() and not (mode and mode.kind == "boss_rush"), lose_reason, {
			"mode_rows": mode.result_rows() if mode else [],
			"blocks": blocks_destroyed, "archers": archers_defeated, "unused_pts": unused_pts,
			"best_chain": chain.best, "best_mult": chain.multiplier(chain.best), "chain_bonus": chain_bonus,
			"replay": replay.frame > 0, "new_best": won and old_best > 0 and score > old_best}))


func stars_for(s: int) -> int:
	var n: int = 1
	var th: Array = data.get("star_scores", [0, 0, 0])
	for i: int in th.size():
		if s >= int(th[i]):
			n = maxi(n, i + 1)
	return n


func live_stars() -> int:
	var n: int = 0
	var th: Array = data.get("star_scores", [0, 0, 0])
	for i: int in th.size():
		if score >= int(th[i]):
			n = i + 1
	return n


## Ads: this attempt counts as one match once it ends, or when it is left after the first shot.
## Training and test runs never count.
var _match_counted: bool = false


## Leaving the app (home button, a call, the notification shade) mid-level opens the pause menu, so the
## physics, archers and the clock never run on unseen and the player comes back to "PAUSED".
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED and what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	if test_mode or hud == null or is_finished() or get_tree().paused or hellfire_running:
		return
	if not Engine.get_write_movie_path().is_empty() or Game.args.has("autoshot") or Game.args.has("screenshot"):
		return  # video recordings and automatic debug shots run in an unfocused window
	if Ads.showing():
		return  # a full-screen ad also takes focus; the ad flow handles that
	if second_chance_open or not Store.busy_product.is_empty():
		return  # out of boulders (nothing moves) or Google Play's purchase sheet: keep that popup
	hud.show_pause()


## Pause menu Map / Restart before the level ended: where players give up.
func track_quit(how: String) -> void:
	if test_mode or is_finished() or not training.is_empty():
		return
	Analytics.event("level_quit", {"level_id": level_id, "attempt": _attempt(), "duration_s": int(_play_t),
			"shots_used": hero_index, "how": how})


func count_match() -> void:
	if _match_counted or test_mode or not training.is_empty():
		return
	if not is_finished() and hero_index == 0 and projectiles.is_empty():
		return  # left before firing: not a match
	_match_counted = true
	Ads.match_played()


func restart() -> void:
	if not training.is_empty():
		Game.goto_training(training, level_id, training_from_workshop)
		return
	if mode and mode.kind == "boss_rush":
		Game.start_rush()
		return
	EnergyUI.enter(level_id, func() -> void:
		Game.skip_flyover = true
		Game.goto_level(level_id))


func _stat(name: String, n: int = 1) -> void:
	if not test_mode:
		Progression.bump(name, n)


## A hidden map scroll was in this crate: reveals the realm's secret level on the map.
func _found_scroll(at: Vector2) -> void:
	var realm: int = int(data.get("realm", 1))
	fx.float_text(at + Vector2(0, -90), "SECRET MAP!", Color("#9af6ff"), 42)
	fx.sparks(at, 20)
	fx.flash(at, 120.0)
	Sound.play("reveal", 0.9)
	on_mode_bonus(int(Data.b("secrets", "scroll_score")), at)
	if hud:
		hud.boss_callout("A SECRET PATH IS REVEALED!")
	if not test_mode:
		Progression.find_secret(realm)


func is_challenge() -> bool:
	return level_id > Data.CHALLENGE_BASE


func play_time() -> float:
	return _play_t


func force_finish(won: bool) -> void:
	_finish(won)


## Attempt number for this level (1 = first try), counted when play starts.
func _attempt() -> int:
	return int((Save.data.get("attempts", {}) as Dictionary).get(str(level_id), 1))


func _log_level_start() -> void:
	if test_mode:
		return
	if not (Save.data.get("attempts", null) is Dictionary):
		Save.data["attempts"] = {}
	Save.data["attempts"][str(level_id)] = int(Save.data["attempts"].get(str(level_id), 0)) + 1
	Analytics.set_crash_key("level", str(level_id))
	Analytics.set_crash_key("scene", "level")
	Analytics.set_crash_key("phase", "aiming")
	Analytics.set_crash_key("weapon", Progression.weapon())
	Analytics.event("level_start", {"level_id": level_id, "attempt": _attempt(), "weapon": Progression.weapon(),
			"heroes": ",".join(PackedStringArray(heroes)), "mode": String(data.get("mode", "siege"))})
	if not test_mode and training.is_empty() and not bool(Save.data.get("tutorial_done", false)) and not bool(Save.data.get("tutorial_begun", false)):
		Save.data["tutorial_begun"] = true
		Save.write()
		Analytics.event("tutorial_begin", {"level_id": level_id})


# ------------------------------------------------------------------------------------ second chance
## Modes where a second chance makes no sense (clock or shared pool) fail straight away.
func _out_of_heroes() -> void:
	if test_mode or second_chance_open or not Game.rush.is_empty() or (mode and mode.kind in ["time_attack", "one_shot"]):
		_finish(false)
		return
	second_chance_open = true
	_out_t = 0.0
	if hud:
		hud.show_second_chance(not rocky_ad_used)


## Rewarded ad watched: one extra Rocky, once per attempt. Afterwards only Hellfire or a replay.
func second_chance_rocky() -> void:
	if not second_chance_open or rocky_ad_used:
		return
	rocky_ad_used = true
	second_chance_open = false
	_out_t = 0.0
	add_heroes(["stone"])


func decline_second_chance() -> void:
	second_chance_open = false
	_finish(false)


## Paid Hellfire: spends one strike and destroys the whole fortress. false if none owned.
func use_hellfire() -> bool:
	if hellfire_running or is_finished() or Save.amount("hellfire") <= 0:
		return false
	Save.add("hellfire", -1)
	get_tree().paused = false  # never run the strike under a pause left over from leaving the app
	Analytics.event("hellfire_used", {"level_id": level_id, "left": Save.amount("hellfire")})
	second_chance_open = false
	_hellfire_strike()
	return true


func _hellfire_strike() -> void:
	hellfire_running = true
	var fxn: HellfireFX = HellfireFX.new()
	add_child(fxn)
	fxn.done.connect(func() -> void:
		hellfire_running = false
		if not is_finished():
			_finish(true))
	fxn.start(self)


## Mode goals (chests, sunk engines) score and count as chain links.
func on_mode_bonus(pts: int, at: Vector2) -> void:
	score += pts
	_chain_link(at, pts, "mode")
	_update_hud()


## Append heroes to the queue (time attack refills, survival waves).
func add_heroes(kinds: Array) -> void:
	for k: Variant in kinds:
		heroes.append(String(k))
		var sh: Sprite2D = Art.sprite("shadow", 0.9)
		sh.modulate.a = 0.75
		world.add_child(sh)
		_waiting_shadows.append(sh)
		var w: Sprite2D = Projectile.make_sprite(String(k))
		w.z_index = int(Data.b("catapult", "hero_wait_z"))
		sh.z_index = w.z_index - 1
		world.add_child(w)
		_waiting.append(w)
	_layout_waiting()
	if not _loaded and _reload_t < 0.0 and state == State.PLAY:
		_reload_t = 0.05
	_update_hud()


func _update_hud() -> void:
	if hud == null:
		return
	hud.set_shots(heroes.size() - hero_index, heroes.size(), String(heroes[mini(hero_index, heroes.size() - 1)]))
	hud.set_ammo(heroes, hero_index)
	hud.set_destruction(blocks_total - blocks.size(), blocks_total)
	# Total = everyone who ever stood in the fortress (boss, engineers and reinforcements included).
	_guards_total = maxi(_guards_total, archers.size() + archers_defeated)
	hud.set_objective(archers.size(), _guards_total, captives_rescued, captives.size())
	hud.set_score(score, live_stars())


# ------------------------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if test_mode or is_finished():
		return
	if event is InputEventScreenTouch:
		var e: InputEventScreenTouch = event
		if e.index != 0:
			return
		if e.pressed:
			_press(e.position)
		else:
			_release(e.position)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == 0:
			_drag(d.position)


## Index of the waiting hero (on the ledge next to the catapult) under a screen position, or -1.
func waiting_hero_at(screen_pos: Vector2) -> int:
	var world_pos: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * screen_pos
	var best: int = -1
	var best_d: float = INF
	for i: int in range(hero_index, mini(_waiting.size(), heroes.size())):
		var w: Sprite2D = _waiting[i]
		if not w.visible or w.has_meta("hopping"):
			continue
		var r: float = float(Data.projectiles[heroes[i]]["radius"]) * Data.bf("catapult", "hero_wait_scale") + Data.bf("catapult", "hero_tap_pad_px")
		var d: float = w.global_position.distance_to(world_pos)
		if d < r and d < best_d:
			best = i
			best_d = d
	return best


func _press(pos: Vector2) -> void:
	_press_picked = false
	# Tapping a hero waiting on the ledge loads it next (same as tapping it in the tray).
	if state == State.PLAY and not _aiming:
		var pick: int = waiting_hero_at(pos)
		if pick >= 0:
			if choose_hero(pick):
				_press_picked = true
				Sound.play("ui_tap")
				Game.haptic(20)
				get_viewport().set_input_as_handled()
				return
	_pressed = true
	_press_pos = pos
	_press_ms = Time.get_ticks_msec()
	_aiming = false
	_aim_vel = Vector2.ZERO
	_last_creak_power = 0.0


func _drag(pos: Vector2) -> void:
	if not _pressed or state != State.PLAY:
		return
	if not _aiming:
		var zone: bool = _press_pos.x < get_viewport_rect().size.x * Data.bf("catapult", "aim_zone_screen_frac")
		if _loaded and zone and pos.distance_to(_press_pos) > Data.bf("catapult", "min_pull_px") * 0.5:
			_aiming = true
			Sound.play("aim_grab", 0.7)
	if _aiming:
		_update_aim(pos)


func _release(pos: Vector2) -> void:
	if _press_picked:
		_press_picked = false
		return
	if not _pressed:
		return
	_pressed = false
	if _aiming:
		_aiming = false
		Sound.stretch_stop()
		if _aim_vel != Vector2.ZERO and state == State.PLAY:
			fire_hero(_aim_vel)
		else:
			catapult.set_pull(0.0)
			_hide_dots()
		return
	var quick: bool = Time.get_ticks_msec() - _press_ms < int(Data.bf("catapult", "tap_max_s") * 1000.0)
	if quick and pos.distance_to(_press_pos) < Data.bf("catapult", "min_pull_px"):
		_tap_ability()


## Tap: newest hero in flight that still has its ability uses it.
func _tap_ability() -> void:
	for i: int in range(projectiles.size() - 1, -1, -1):
		var p: Projectile = projectiles[i]
		if is_instance_valid(p) and p.use_ability():
			Sound.play("ability", 0.6)
			coach_ability_used()
			return


func _update_aim(pos: Vector2) -> void:
	var pull: Vector2 = _press_pos - pos
	var length: float = pull.length()
	if length < Data.bf("catapult", "min_pull_px"):
		_aim_vel = Vector2.ZERO
		catapult.set_pull(0.0)
		Sound.stretch_stop()
		_hide_dots()
		return
	var power: float = clampf(length / Data.bf("catapult", "max_pull_px"), 0.0, 1.0)
	var lo: float = deg_to_rad(Data.bf("catapult", "min_launch_angle_deg"))
	var hi: float = deg_to_rad(Data.bf("catapult", "max_launch_angle_deg"))
	var a: float = pull.angle()
	if pull.x < 0.0:
		a = lo if pull.y < 0.0 else hi
	a = clampf(a, lo, hi)
	_aim_vel = Vector2.from_angle(a) * power * Data.bf("catapult", "max_speed")
	catapult.set_pull(power)
	Sound.stretch(power)
	_show_dots(catapult.launch_point(String(heroes[hero_index])), _aim_vel)


func _show_dots(start: Vector2, v: Vector2) -> void:
	var step: float = Data.bf("catapult", "dot_step_s")
	for i: int in _dots.size():
		var t: float = (i + 1) * step
		var p: Vector2 = start + v * _w_speed * t + Vector2(0, 0.5 * _gravity * _w_grav * t * t)
		_dots[i].position = p
		_dots[i].visible = p.y < 0.0


func _hide_dots() -> void:
	for d: Sprite2D in _dots:
		d.visible = false


# ------------------------------------------------------------------------------------ training coach
## Step hints on the training range: "aim" when a hero is loaded, "tap" in flight, "done" after the
## ability fired. Texts: balance.json training.coach.<hero>.
func _coach(step: String) -> void:
	if training.is_empty():
		return
	var cfg: Dictionary = Data.balance["training"]
	var texts: Dictionary = (cfg["coach"] as Dictionary).get(training, {})
	var text: String = String(texts.get(step, ""))
	if step == "aim" and _coach_shots > 0:
		text = String(texts["again"]) if _coach_shot_tapped else String(cfg["missed"])
	elif step == "fly":
		text = String(cfg["fly"]) % String(Data.projectiles[training]["name"])
	if not text.is_empty():
		hud.hint(text, float(Data.balance["training"]["hint_s"]), String(Data.projectiles[training]["texture"]) if step != "done" else "icon_check")


## End of practice: back to the Workshop, or on to the level this range came before.
func leave_training() -> void:
	Save.mark_seen("training:" + training)
	if training_from_workshop:
		Game.goto_workshop()
	else:
		Game.goto_level_entry(level_id)


func coach_ability_used() -> void:
	if training.is_empty():
		return
	_coach_shot_tapped = true
	_coach_prompt_end()
	if not _coach_tapped:
		_coach_tapped = true
		_coach("done")


var _coach_shots: int = 0
var _coach_shot_tapped: bool = false
var _coach_prompted: bool = false
var _coach_prompt_ms: int = -1
var _coach_front_x: float = 0.0


## A shot on the training range: remember where the fort starts so the TAP NOW prompt can show
## when the hero gets there (front + tap_dx).
func _coach_shot_start() -> void:
	if training.is_empty():
		return
	_coach_shots += 1
	_coach_shot_tapped = false
	_coach_prompted = false
	_coach_front_x = INF
	for b: Block in blocks:
		if is_instance_valid(b) and not b.dead:
			_coach_front_x = minf(_coach_front_x, b.global_position.x - b.size.x * 0.5)
	_coach("fly")


## Per frame on the training range: slow time and show TAP NOW at the right moment; end it once the
## ability fires, the hero lands (Boomer can still be tapped after landing) or prompt_hold_s pass.
func _tick_coach() -> void:
	if training.is_empty() or test_mode or not is_instance_valid(projectile):
		if _coach_prompt_ms >= 0 and not is_instance_valid(projectile):
			_coach_prompt_end()
		return
	var p: Projectile = projectile
	var cfg: Dictionary = Data.balance["training"]
	if _coach_prompt_ms >= 0:
		var gone: bool = p.done or p.ability_used or (p.impacted and p.kind != "bomb")
		if gone or Time.get_ticks_msec() - _coach_prompt_ms > int(float(cfg["prompt_hold_s"]) * 1000.0):
			_coach_prompt_end()
		return
	if _coach_prompted or p.done or p.ability_used or (p.impacted and p.kind != "bomb"):
		return
	var dx: float = float(((cfg["coach"] as Dictionary)[training] as Dictionary)["tap_dx"])
	var there: bool = p.global_position.x >= _coach_front_x + dx
	var short: bool = p.linear_velocity.y > 0.0 and p.global_position.y > -120.0
	if there or short or p.impacted:
		_coach_prompted = true
		_coach_prompt_ms = Time.get_ticks_msec()
		_slowmo = true
		Engine.time_scale = float(cfg["slowmo_scale"])
		Sound.play("slowmo", 0.8)
		hud.coach_prompt(String(((cfg["coach"] as Dictionary)[training] as Dictionary)["tap"]))


func _coach_prompt_end() -> void:
	if _coach_prompt_ms < 0:
		return
	_coach_prompt_ms = -1
	_slowmo = false
	Engine.time_scale = 1.0
	Sound.play("slowmo_out", 0.7)
	hud.coach_prompt_hide()


# ------------------------------------------------------------------------------------ tutorial
func _show_tutorial() -> void:
	_tutorial = Node2D.new()
	_tutorial.z_index = 20
	_tutorial.position = Vector2(-60, -250)
	world.add_child(_tutorial)
	var bubble: PanelContainer = UIKit.dark_bubble()
	var l: Label = UIKit.label("Drag & Release\nto Fire!", 30, Color.WHITE, 0)
	bubble.add_child(l)
	bubble.position = Vector2(-150, -130)
	_tutorial.add_child(bubble)
	var arrow: Sprite2D = Art.sprite("tutorial_arrow", 1.1)
	arrow.position = Vector2(150, 40)
	arrow.rotation = -0.1
	_tutorial.add_child(arrow)
	var hand: Sprite2D = Art.sprite("hand", 1.1)
	hand.position = Vector2(60, 170)
	_tutorial.add_child(hand)
	var tw: Tween = hand.create_tween().set_loops()
	tw.tween_property(hand, "position", Vector2(-60, 230), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.25)
	tw.tween_property(hand, "position", Vector2(60, 170), 0.3)


func _hide_tutorial() -> void:
	if _tutorial and is_instance_valid(_tutorial):
		_tutorial.queue_free()
		_tutorial = null
		if not test_mode:
			Save.data["tutorial_done"] = true
			Save.write()


# ------------------------------------------------------------------------------------ callbacks
func on_impact(b: Block, impulse: float, from_projectile: bool) -> void:
	var snd: String = String(b.mat["sound"])
	Sound.play_at(String(HIT_SOUND.get(snd, "wood_hit")), b.global_position, Sound.impact_volume(impulse))
	var hs: float = Data.bf("fx", "hitstop_impulse")
	if impulse > hs * 0.25:
		camera.add_shake(impulse * Data.bf("fx", "shake_per_impulse"))
		fx.puff(b.global_position, 2, Color(0.95, 0.9, 0.8, 0.7), 0.7)
	if from_projectile and impulse > hs:
		_hitstop()
		Game.haptic()
		Events.big_impact.emit(b.global_position, impulse)


func on_projectile_impact(p: Projectile) -> void:
	camera.add_shake(6.0)
	fx.puff(p.global_position, 4, Color(1, 1, 1, 0.8), 0.7)


func on_block_destroyed(b: Block, scored: bool) -> void:
	blocks.erase(b)
	var pos: Vector2 = b.global_position
	var m: Dictionary = b.mat
	fx.debris(pos, String(m["debris"]), int(Data.b("fx", "debris_per_block")), 520.0)
	fx.puff(pos, 4, Color(0.95, 0.9, 0.8, 0.8), 1.0)
	Sound.play_at(String(BREAK_SOUND.get(String(m["sound"]), "wood_break")), pos, 0.9)
	if b.is_weak_point():
		Sound.play_at("weak_point", pos, 0.9)
	if scored:
		blocks_destroyed += 1
		_stat("blocks")
		if b.mat_id == "ice":
			_stat("ice")
		if bool(b.get_meta("scroll", false)):
			_found_scroll(pos)
		var pts: int = int(m["score"])
		score += pts
		fx.float_text(pos, str(pts), Color.WHITE, 28)
		Events.block_destroyed.emit(b, pts)
		_chain_link(pos, pts, "barrel" if bool(m["explodes"]) else "block")
	replay.event("break", pos, maxf(b.size.x, b.size.y), String(m["debris"]))
	if not b.trigger_id.is_empty():
		activate_trigger(b.trigger_id)
	if rig:
		rig.on_block_destroyed(b)
	if mode:
		mode.on_block_destroyed(b)
	_update_hud()
	_wake_near(pos, maxf(b.size.x, b.size.y) + Data.bf("physics", "wake_margin_px"))
	if bool(m["explodes"]):
		var e: Dictionary = m["explosion"]
		# Thrown kegs and cart loads are packed tighter than a barrel in a cellar (Block meta).
		var bm: float = float(b.get_meta("blast_mult", 1.0))
		explode.call_deferred(pos, float(e["radius"]) * sqrt(bm), float(e["impulse"]) * bm, float(e["damage"]) * bm)
	if m.has("shatter"):
		shatter.call_deferred(pos, m["shatter"])
	for bolt: Bolt in bolts.duplicate():
		if bolt.has_block(b):
			bolt.snap()


func on_archer_defeated(a: Archer) -> void:
	archers.erase(a)
	_stat("archers")
	if a.is_boss:
		_stat("bosses")
	if rig:
		rig.on_archer_defeated(a)
	archers_defeated += 1
	var pts: int = int(Data.b("boss", "score")) if a.is_boss else int(Data.b("boss_rig", "engineer_score")) if a.is_engineer else int(Data.b("score", "archer"))
	if a.is_boss and hud:
		hud.set_boss(0.0, _boss_phase)
		camera.add_shake(Data.bf("boss", "phase_shake"))
		Sound.play_at("boss_roar", a.global_position, 0.9, 1.3)
	score += pts
	_update_hud()
	fx.float_text(a.global_position + Vector2(0, -40), Hud.fmt(pts), Color("#ffe27a"), 40)
	fx.puff(a.global_position, 6, Color(1, 1, 1, 0.9), 0.9)
	Sound.play_at("enemy_ko", a.global_position)
	Events.archer_defeated.emit(a, pts)
	_chain_link(a.global_position, pts, "boss" if a.is_boss else "archer")
	replay.event("ko", a.global_position, 60.0)
	for s: Soldier in soldiers:
		s.cheer()
	if archers.is_empty() and not test_mode:
		_slow_motion()


func _on_soldier_ko(_s: Node2D) -> void:
	soldiers_lost += 1
	score = maxi(0, score + int(Data.b("score", "soldier_ko")))
	_update_hud()


func spawn_mechanism(md: Dictionary) -> CastleMechanism:
	var mechanism: CastleMechanism = CastleMechanism.new()
	mechanism.setup(self, md)
	world.add_child(mechanism)
	mechanisms.append(mechanism)
	return mechanism


func wake_near(pos: Vector2, r: float) -> void:
	_wake_near(pos, r)


## Levers, windmill hubs and revealed switches react to blasts, fire, quakes and beams.
func hit_mechanisms_near(pos: Vector2, radius: float) -> void:
	for m: CastleMechanism in mechanisms:
		if is_instance_valid(m):
			m.on_blast(pos, radius)


## Blasts and fire bursts light fuses.
func _heat_gadgets(pos: Vector2, radius: float) -> void:
	for g: Gadget in gadgets:
		if is_instance_valid(g):
			g.on_heat(pos, radius)


func _wake_near(pos: Vector2, r: float) -> void:
	for b: Block in blocks:
		if is_instance_valid(b) and b.global_position.distance_to(pos) < r + maxf(b.size.x, b.size.y) * 0.5:
			b.sleeping = false
	for a: Archer in archers:
		if is_instance_valid(a) and a.global_position.distance_to(pos) < r + 60.0:
			a.sleeping = false


func activate_trigger(trigger: String) -> void:
	if trigger.is_empty():
		return
	for mechanism: CastleMechanism in mechanisms:
		if is_instance_valid(mechanism) and mechanism.trigger_id == trigger:
			mechanism.activate()
	for captive: Captive in captives:
		if is_instance_valid(captive) and captive.rescue_id == trigger:
			captive.rescue()
	for gadget: Gadget in gadgets:
		if is_instance_valid(gadget):
			gadget.on_trigger(trigger)


## A gadget did something worth a callout (portal used, plate pressed, crystal broken...).
func on_gadget(gadget: Gadget, text: String, pts: int = -1) -> void:
	if is_finished():
		return
	if pts < 0:
		pts = int(Data.b("gadgets", "gadget_score"))
	score += pts
	camera.add_shake(Data.bf("mechanics", "activation_shake"))
	fx.float_text(gadget.hit_point() + Vector2(0, -50), text, Color("#9fe8ff"), 26)
	Events.mechanism_activated.emit(gadget)
	_stat("gadgets")
	_chain_link(gadget.hit_point(), pts, "mechanism")
	_update_hud()


func on_mechanism_activated(mechanism: CastleMechanism, pts: int = -1) -> void:
	if Game.args.has("debug-mech"):
		print("MECH %s at %d ms" % [mechanism.kind, Time.get_ticks_msec()])
	if pts < 0:
		pts = int(Data.b("mechanics", "trigger_score"))
	score += pts
	camera.add_shake(Data.bf("mechanics", "activation_shake"))
	fx.float_text(mechanism.hit_point(), mechanism.callout_text(), Color("#ffe27a"), 26)
	Events.mechanism_activated.emit(mechanism)
	_stat("mechanisms")
	if rig:
		_on_rig_status()
	_chain_link(mechanism.hit_point(), pts, "mechanism")
	_update_hud()


func on_captive_rescued(captive: Captive) -> void:
	captives_rescued += 1
	_stat("rescues")
	score += int(Data.b("mechanics", "rescue_score"))
	fx.float_text(captive.global_position + Vector2(0, -90), "RESCUED!", Color("#8dff78"), 34)
	Events.captive_rescued.emit(captive)
	for soldier: Soldier in soldiers:
		soldier.cheer(2.2)
	_update_hud()


# ------------------------------------------------------------------------------------ gap
## Bodies below this world y have fallen into the gap and are removed.
func kill_line() -> float:
	return stage.kill_y if stage else Data.bf("physics", "out_of_bounds_y")


func surface_line() -> float:
	return stage.surface_y if stage else Data.bf("physics", "out_of_bounds_y")


## A body crossed the gap surface: water splash (or lava flare / cloud puff).
func splash(pos: Vector2, size: float) -> void:
	var p: Vector2 = Vector2(pos.x, stage.surface_y)
	var c: Color = stage.splash_color()
	var n: int = int(Data.b("stage", "splash_puffs"))
	fx.puff(p, n, Color(c, 0.9), clampf(size / 60.0, 0.6, 1.6))
	fx.puff(p + Vector2(0, -30), maxi(2, n / 2), Color(c, 0.7), clampf(size / 90.0, 0.5, 1.2))
	if stage.gap_kind == "lava":
		fx.flame_puff(p)
		fx.sparks(p, 5)
	Sound.play_at(stage.splash_sound(), p, clampf(size / 80.0, 0.45, 1.0))
	replay.event("splash", pos, size)


# ------------------------------------------------------------------------------------ effects on the world
## True when solid ground or a rock wall (world layer: stage, ramps) stands between two points, so a
## blast or fire burst cannot reach behind it (walled pits, hills). Endpoints are lifted a little so
## things standing on the ground are not hidden by the ground itself.
func _behind_cover(from: Vector2, to: Vector2) -> bool:
	var lift: Vector2 = Vector2(0.0, -Data.bf("physics", "cover_lift_px"))
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from + lift, to + lift, int(Data.b("layers", "world")))
	return not world.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func explode(pos: Vector2, radius: float, impulse: float, damage: float) -> void:
	fx.flash(pos, radius)
	replay.event("explode", pos, radius)
	fx.sparks(pos, 14)
	cut_ropes_near(pos, radius * Data.bf("ropes", "explosion_cut_mult"))
	_snap_bolts_near(pos, radius * Data.bf("bolts", "explosion_break_mult"))
	hit_mechanisms_near.call_deferred(pos, radius * 0.6)
	_heat_gadgets(pos, radius * 0.6)
	Sound.play_at("explosion", pos)
	camera.add_shake(Data.bf("camera", "shake_max_px"))
	Game.haptic(60)
	Events.explosion.emit(pos, radius)
	for b: Block in blocks.duplicate():
		if not is_instance_valid(b) or b.dead:
			continue
		var d: float = maxf(0.0, b.global_position.distance_to(pos) - minf(b.size.x, b.size.y) * 0.5)
		if d < radius:
			if b.absorb("blast") or _behind_cover(pos, b.global_position):
				continue
			var f: float = 1.0 - d / radius
			var dir: Vector2 = ((b.global_position - pos).normalized() + Vector2(0, -0.35)).normalized()
			b.push(dir * impulse * f)
			b.take_damage(damage * f)
	var ffr: float = radius * Data.bf("friendly_fire", "blast_radius_mult")
	hurt_soldiers(pos, ffr * 0.5, int(Data.b("friendly_fire", "blast_hits_inner")))
	hurt_soldiers(pos, ffr, int(Data.b("friendly_fire", "blast_hits_outer")))
	for a: Archer in archers.duplicate():
		if not is_instance_valid(a) or a.dead:
			continue
		var d2: float = a.global_position.distance_to(pos)
		if d2 < radius and not _behind_cover(pos, a.global_position):
			var f2: float = 1.0 - d2 / radius
			a.push(((a.global_position - pos).normalized() + Vector2(0, -0.5)).normalized() * impulse * 0.4 * f2)
			a.take_damage(damage * f2)


func fire_burst(pos: Vector2, radius: float, damage: float) -> void:
	Sound.play_at("fire", pos)
	camera.add_shake(10.0)
	for i: int in 14:
		fx.flame_puff(pos + Vector2.from_angle(randf() * TAU) * randf() * radius * 0.6)
	fx.flash(pos, radius * 0.6)
	cut_ropes_near(pos, Data.bf("ropes", "fire_cut_radius_px"))
	hit_mechanisms_near.call_deferred(pos, radius * 0.5)
	_heat_gadgets(pos, radius * 0.5)
	var burn: float = Data.bf("fire", "burn_s")
	for b: Block in blocks.duplicate():
		if not is_instance_valid(b) or b.dead:
			continue
		var d: float = maxf(0.0, b.global_position.distance_to(pos) - minf(b.size.x, b.size.y) * 0.5)
		if d < radius:
			if b.absorb("fire") or _behind_cover(pos, b.global_position):
				continue
			b.sleeping = false
			b.ignite(burn)
			b.take_damage(damage * (1.0 - d / radius) * float(Data.projectiles["fire"]["material_mult"].get(b.mat_id, 1.0)))
	for a: Archer in archers.duplicate():
		if is_instance_valid(a) and a.global_position.distance_to(pos) < radius and not _behind_cover(pos, a.global_position):
			a.ignite(burn)
			a.take_damage(damage * 0.5)
	hurt_soldiers(pos, radius, int(Data.b("friendly_fire", "fire_hits")))


## Friendly fire: our soldiers within `radius` of `pos` take `hits` unblockable hits each. Explosions
## and flames that go off on our ledge, or a hero that drops back onto it, hurt the Vanguard.
## Each soldier is hit once per call (inner/outer rings call twice).
func hurt_soldiers(pos: Vector2, radius: float, hits: int) -> int:
	var n: int = 0
	for s: Soldier in soldiers:
		if not is_instance_valid(s) or s.knocked_out:
			continue
		if s.body_center().distance_to(pos) < radius:
			for k: int in hits:
				s.hit(true)
			n += 1
	if n > 0 and not test_mode:
		hud.hint("Careful! Your own shot hit the Vanguard.", 2.0, "soldier_idle")
	return n


func spread_fire(src: Block) -> void:
	var t: float = Data.bf("fire", "spread_burn_s")
	for b: Block in blocks:
		if b == src or not is_instance_valid(b) or b.is_burning():
			continue
		var reach: float = (maxf(src.size.x, src.size.y) + maxf(b.size.x, b.size.y)) * 0.5 + 10.0
		if b.global_position.distance_to(src.global_position) < reach:
			b.ignite(t)


## Quaky's shockwave. Low pieces (within shockwave_height of the ground) take the full hit; everything
## higher in range is shaken loose with a weaker jolt (upper_damage_mult), so the whole structure
## rocks. `power` scales it (an undived landing is weaker).
func quake(pos: Vector2, quake_cfg: Dictionary, power: float = 1.0) -> void:
	var radius: float = float(quake_cfg["shockwave_radius"]) * lerpf(0.7, 1.0, power)
	var height: float = float(quake_cfg["shockwave_height"])
	var damage: float = float(quake_cfg["shockwave_damage"]) * power
	var impulse: float = float(quake_cfg["shockwave_impulse"]) * power
	var upper: float = float(quake_cfg.get("upper_damage_mult", 0.45))
	var ground_y: float = stage.top_at(pos.x) if stage else 0.0
	if ground_y > 0.0:
		ground_y = 0.0
	fx.shockwave(pos.x, radius, ground_y)
	_snap_bolts_near(Vector2(pos.x, ground_y), radius * Data.bf("bolts", "quake_break_radius_mult"))
	hit_mechanisms_near.call_deferred(Vector2(pos.x, ground_y), radius * 0.4)
	camera.add_shake(Data.bf("camera", "shake_max_px"))
	Sound.play_at("quake", pos, 0.95)
	Game.haptic(70)
	for b: Block in blocks.duplicate():
		if not is_instance_valid(b) or b.dead:
			continue
		var dx: float = absf(b.global_position.x - pos.x)
		if dx > radius or b.held:
			continue
		if b.absorb("quake"):
			continue
		var low: bool = b.global_position.y >= ground_y - height
		var strength: float = (1.0 - dx / radius) * (1.0 if low else upper)
		var weak_mult: float = float(quake_cfg["weak_point_mult"]) if b.is_weak_point() else 1.0
		var mat_mult: float = float((quake_cfg.get("material_mult", {}) as Dictionary).get(b.mat_id, 1.0))
		var side: float = signf(b.global_position.x - pos.x) if dx > 1.0 else (1.0 if randf() < 0.5 else -1.0)
		b.push(Vector2(side * impulse * (0.2 if low else 0.3), -impulse * (1.0 if low else 0.3)) * strength)
		b.take_damage(damage * strength * weak_mult * mat_mult)
	for a: Archer in archers.duplicate():
		if is_instance_valid(a) and not a.dead and absf(a.global_position.x - pos.x) < radius:
			var strength_a: float = 1.0 - absf(a.global_position.x - pos.x) / radius
			a.push(Vector2(signf(a.global_position.x - pos.x) * impulse * 0.15, -impulse * 0.35) * strength_a)
			a.take_damage(float(quake_cfg.get("archer_damage", 18.0)) * strength_a * power)
	Events.quake.emit(Vector2(pos.x, ground_y), radius)


func whirl(center: Vector2, cfg: Dictionary, _delta: float, release: bool) -> void:
	var r: float = float(cfg["whirl_radius"])
	var ref: float = float(cfg["ref_mass"])
	var bodies: Array[RigidBody2D] = []
	for b: Block in blocks:
		if is_instance_valid(b) and not b.dead:
			bodies.append(b)
	for a: Archer in archers:
		if is_instance_valid(a) and not a.dead:
			bodies.append(a)
	for body: RigidBody2D in bodies:
		var to: Vector2 = center - body.global_position
		var d: float = to.length()
		if d > r or d < 1.0:
			continue
		body.sleeping = false
		var m: float = minf(body.mass, ref)
		if release:
			var dir: Vector2 = Vector2(1.0, -0.6).normalized()
			if body is Block:
				(body as Block).push(dir * float(cfg["fling_impulse"]) * minf(1.0, body.mass / ref))
			else:
				(body as Archer).push(dir * float(cfg["fling_impulse"]) * minf(1.0, body.mass / ref))
			continue
		var n: Vector2 = to / d
		var force: Vector2 = n * float(cfg["pull_accel"]) + n.orthogonal() * float(cfg["swirl_accel"]) \
				+ Vector2(0, -float(cfg["lift_accel"]))
		body.apply_central_force(force * m)


# ------------------------------------------------------------------------------------ phase C hooks
## Adds a block at runtime (rope loads, boss reinforcements).
func spawn_block(shape: String, pos: Vector2, decor: Dictionary = {}) -> Block:
	var b: Block = Block.new()
	b.setup(shape, self, pos, 0.0, decor)
	world.add_child(b)
	blocks.append(b)
	blocks_total += 1
	return b


func on_block_damaged(b: Block) -> void:
	for bolt: Bolt in bolts.duplicate():
		if not bolt.broken and bolt.has_block(b) and bolt.overloaded():
			bolt.snap()


func on_bolt_snapped(bolt: Bolt) -> void:
	bolts.erase(bolt)
	fx.sparks(bolt.position_now(), 6)
	Sound.play_at("metal_hit", bolt.position_now(), 0.7, 1.3)
	_chain_link(bolt.position_now(), 0, "bolt")


## Crystal blocks burst into shards that hurt their neighbours.
func shatter(pos: Vector2, cfg: Dictionary) -> void:
	var radius: float = float(cfg["radius"])
	fx.debris(pos, String(cfg.get("debris", "crystal")), 8, 640.0)
	fx.flash(pos, radius * 0.5)
	for b: Block in blocks.duplicate():
		if not is_instance_valid(b) or b.dead:
			continue
		var d: float = b.global_position.distance_to(pos)
		if d < radius:
			var f: float = 1.0 - d / radius
			b.push((b.global_position - pos).normalized() * float(cfg["impulse"]) * f)
			b.take_damage(float(cfg["damage"]) * f)
	for a: Archer in archers.duplicate():
		if is_instance_valid(a) and a.global_position.distance_to(pos) < radius:
			a.take_damage(float(cfg["damage"]) * 0.6)


## Fire on iron: it glows red-hot and takes extra damage for a while.
func on_block_heated(b: Block) -> void:
	fx.float_text(b.global_position + Vector2(0, -30), "RED HOT!", Color("#ff8a3a"), 26)
	fx.sparks(b.global_position, 6)


func on_block_bent(b: Block) -> void:
	_stat("iron_bent")
	var pts: int = int(b.mat["bend"]["score"])
	score += pts
	Sound.play_at("metal_bend", b.global_position, 0.9)
	fx.sparks(b.global_position, 10)
	fx.float_text(b.global_position + Vector2(0, -30), "BENT!", Color("#d8e0ea"), 28)
	camera.add_shake(8.0)
	_chain_link(b.global_position, pts, "bend")
	_update_hud()


## A charged rune crystal fires a beam along its arrow: it damages and pushes every block it
## crosses, burns wood, heats iron, melts ice, defeats guards, cuts ropes, snaps bolts and
## charges other rune crystals (so beams can be bounced around a fortress).
func rune_beam(src: Block) -> void:
	if not is_instance_valid(src) or src.dead:
		return
	var cfg: Dictionary = src.mat["rune"]
	var dir: Vector2 = src.beam_dir()
	var a: Vector2 = src.global_position + dir * minf(src.size.x, src.size.y) * 0.5
	var e: Vector2 = a + dir * float(cfg["length"])
	var half_w: float = float(cfg["width"]) * 0.5
	var mults: Dictionary = cfg["material_mult"]
	fx.beam(a, e, float(cfg["width"]))
	replay.event("beam", a, float(cfg["width"]), e)
	Sound.play_at("rune_beam", a, 0.95)
	camera.add_shake(12.0)
	Game.haptic(40)
	var step: float = float(cfg["width"])
	var n: int = int(float(cfg["length"]) / step)
	for i: int in n + 1:
		var p: Vector2 = a + dir * step * i
		cut_ropes_near(p, half_w)
		_snap_bolts_near(p, half_w)
		hit_mechanisms_near.call_deferred(p, half_w)
	for b: Block in blocks.duplicate():
		if b == src or not is_instance_valid(b) or b.dead:
			continue
		var on: Vector2 = Geometry2D.get_closest_point_to_segment(b.global_position, a, e)
		if on.distance_to(b.global_position) > half_w + minf(b.size.x, b.size.y) * 0.5:
			continue
		if b.absorb("beam"):
			continue
		b.push(dir * float(cfg["impulse"]))
		b.take_damage(float(cfg["damage"]) * float(mults.get(b.mat_id, 1.0)))
		b.ignite(float(cfg["burn_s"]))
	for ar: Archer in archers.duplicate():
		if not is_instance_valid(ar) or ar.dead:
			continue
		var on2: Vector2 = Geometry2D.get_closest_point_to_segment(ar.global_position, a, e)
		if on2.distance_to(ar.global_position) < half_w + 26.0:
			ar.push(dir * float(cfg["impulse"]) * 0.3)
			ar.take_damage(float(cfg["archer_damage"]))
	var pts: int = int(cfg["score"])
	score += pts
	_stat("beams")
	_chain_link(a, pts, "beam")
	_update_hud()


func on_rope_cut(m: CastleMechanism) -> void:
	var pts: int = int(Data.b("ropes", "snap_score"))
	score += pts
	fx.float_text(m.global_position + Vector2(0, 40), "SNAP!", Color("#ffe27a"), 30)
	_chain_link(m.global_position, pts, "rope")
	_update_hud()


## A contraption rope (Tether) was cut: points, SNAP! and a chain link.
func on_tether_cut(t: Tether) -> void:
	on_contraption(t.hook_point().lerp(t.attach_point(), 0.5), "SNAP!", int(Data.b("tethers", "snap_score")))


## Score, callout and a chain link for a contraption firing (rope snap, seesaw launch).
func on_contraption(at: Vector2, text: String, pts: int) -> void:
	score += pts
	fx.float_text(at, text, Color("#ffe27a"), 30)
	_chain_link(at, pts, "rope")
	_stat("mechanisms")
	_update_hud()


## Rope segments near a point are cut (heroes passing, fire, explosions).
func cut_ropes_near(pos: Vector2, radius: float) -> void:
	for t: Tether in tethers:
		var seg: Array = t.rope_segment()
		if not seg.is_empty() and Geometry2D.get_closest_point_to_segment(pos, seg[0], seg[1]).distance_to(pos) < radius:
			t.release(true)
	for m: CastleMechanism in mechanisms:
		if not is_instance_valid(m):
			continue
		for seg: Array in m.ropes():
			if Geometry2D.get_closest_point_to_segment(pos, seg[0], seg[1]).distance_to(pos) < radius:
				m.cut_rope(int(seg[2]))


func _check_ropes() -> void:
	var r: float = Data.bf("ropes", "cut_radius_px")
	for p: Projectile in projectiles:
		if is_instance_valid(p) and not p.done:
			cut_ropes_near(p.global_position, r + p.radius())


## A crusher stone sweeps this world rect: anything inside is crushed.
func crush(r: Rect2) -> void:
	for b: Block in blocks.duplicate():
		if not is_instance_valid(b) or b.dead or b.held:
			continue
		if r.grow(-minf(b.size.x, b.size.y) * 0.25).has_point(b.global_position):
			if b.mat_id in ["iron", "boulder", "rune"]:
				b.take_damage(Data.bf("crusher", "slam_damage"))
			else:
				b.destroy(true)
	for a: Archer in archers.duplicate():
		if is_instance_valid(a) and not a.dead and r.has_point(a.global_position):
			a.take_damage(Data.bf("crusher", "slam_damage"))
	for p: Projectile in projectiles:
		if is_instance_valid(p) and not p.done and r.has_point(p.global_position):
			on_projectile_impact(p)
			p.finish()


## A heavy beam landing along a-b (drawbridge): guards and blocks within reach take damage and
## are driven down and outward.
func slam_segment(a: Vector2, b: Vector2, reach: float, damage: float, impulse: float) -> void:
	for bl: Block in blocks.duplicate():
		if not is_instance_valid(bl) or bl.dead or bl.held:
			continue
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(bl.global_position, a, b)
		if c.distance_to(bl.global_position) - minf(bl.size.x, bl.size.y) * 0.5 < reach:
			bl.sleeping = false
			bl.push(((bl.global_position - c).normalized() + Vector2(0, 0.6)).normalized() * impulse)
			bl.take_damage(damage)
	for ar: Archer in archers.duplicate():
		if not is_instance_valid(ar) or ar.dead:
			continue
		var c2: Vector2 = Geometry2D.get_closest_point_to_segment(ar.global_position, a, b)
		if c2.distance_to(ar.global_position) < reach + 40.0:
			ar.take_damage(damage)


## Blast without fire or flash (heavy landings): knocks blocks and guards away from pos.
func shockwave(pos: Vector2, radius: float, impulse: float, damage: float, source: Node = null) -> void:
	fx.puff(pos, 8, Color(0.92, 0.88, 0.8, 0.9), 1.2)
	for bl: Block in blocks.duplicate():
		if not is_instance_valid(bl) or bl.dead or bl.held or bl == source:
			continue
		var d: float = maxf(0.0, bl.global_position.distance_to(pos) - minf(bl.size.x, bl.size.y) * 0.5)
		if d < radius:
			var f: float = 1.0 - d / radius
			bl.sleeping = false
			bl.push(((bl.global_position - pos).normalized() + Vector2(0, -0.25)).normalized() * impulse * f)
			bl.take_damage(damage * f)
	for ar: Archer in archers.duplicate():
		if not is_instance_valid(ar) or ar.dead:
			continue
		var d2: float = ar.global_position.distance_to(pos)
		if d2 < radius:
			var f2: float = 1.0 - d2 / radius
			ar.push(((ar.global_position - pos).normalized() + Vector2(0, -0.5)).normalized() * impulse * 0.4 * f2)
			ar.take_damage(damage * f2)


func geyser_push(m: CastleMechanism, delta: float) -> void:
	var r: Rect2 = m.geyser_rect()
	var lift: float = Data.bf("geyser", "lift_accel")
	var lava: bool = stage != null and stage.gap_kind == "lava"
	for p: Projectile in projectiles:
		if is_instance_valid(p) and not p.done and not p.freeze and r.has_point(p.global_position):
			p.linear_velocity.y = maxf(p.linear_velocity.y - lift * delta, -lift * 0.6)
	for b: Block in blocks:
		if is_instance_valid(b) and not b.held and r.has_point(b.global_position):
			b.sleeping = false
			b.apply_central_force(Vector2(0, -Data.bf("geyser", "block_lift_accel") * b.mass))
			if lava:
				b.ignite(1.0)
	for a: Archer in archers:
		if is_instance_valid(a) and r.has_point(a.global_position):
			a.sleeping = false
			a.apply_central_force(Vector2(0, -Data.bf("geyser", "block_lift_accel") * a.mass))
			if lava:
				a.take_damage(Data.bf("geyser", "lava_damage_dps") * delta)




# ------------------------------------------------------------------------------------ boss
## Every power core is broken: the boss shield drops and the boss is stunned for a moment.
func on_core_down(at: Vector2) -> void:
	_stat("cores")
	var pts: int = int(Data.b("boss_rig", "core_down_score"))
	score += pts
	_chain_link(at, pts, "core")
	camera.add_shake(Data.bf("boss", "phase_shake"))
	fx.flash(at, 220.0)
	fx.shockwave(at.x, 400.0, at.y)
	Sound.play_at("explosion", at, 1.0, 0.8)
	Sound.play_at("boss_roar", at, 0.9, 0.85)
	Game.haptic(80)
	if is_instance_valid(boss):
		boss.lock_shield(false)
		boss.cooldown += Data.bf("boss_rig", "stun_s")
		fx.float_text(boss.global_position + Vector2(0, -150), "SHIELD DOWN!", Color("#9af6ff"), 38)
		if hud:
			hud.boss_callout("CORE DESTROYED!")
	if not test_mode:
		Engine.time_scale = 0.35
		get_tree().create_timer(Data.bf("boss_rig", "core_down_slowmo_s"), true, false, true).timeout.connect(func() -> void:
			if state == State.PLAY:
				Engine.time_scale = 1.0)
	_update_hud()


func _on_rig_status() -> void:
	if hud and rig:
		hud.set_boss_status(rig.status())


## Boss phases from level JSON "boss_unit.phases": [{"at": hp fraction, "do": ["reinforce", "shield",
## "enrage", "charge"]}]. Each phase fires once when the boss HP falls below "at".
func on_boss_damaged(b: Archer) -> void:
	var frac: float = clampf(b.hp / maxf(1.0, b.max_hp), 0.0, 1.0)
	var phases: Array = data.get("boss_unit", {}).get("phases", [])
	while _boss_phase < phases.size() and frac <= float(phases[_boss_phase]["at"]):
		var ph: Dictionary = phases[_boss_phase]
		_boss_phase += 1
		_run_boss_phase(b, ph.get("do", []))
	if hud:
		hud.set_boss(frac, _boss_phase)


func _run_boss_phase(b: Archer, actions: Array) -> void:
	camera.add_shake(Data.bf("boss", "phase_shake"))
	Sound.play("boss_roar", 0.9)
	Game.haptic(80)
	var words: PackedStringArray = PackedStringArray()
	for act: Variant in actions:
		match String(act):
			"reinforce":
				words.append("REINFORCEMENTS!")
				for p: Variant in data.get("boss_unit", {}).get("reinforce", []):
					var pos: Vector2 = Vector2(float(p[0]), float(p[1]) - Data.bf("boss", "reinforce_drop_px"))
					var a: Archer = spawn_archer(pos)
					a.sleeping = false
					fx.puff(pos, 5, Color(1, 0.9, 0.9, 0.9), 0.8)
			"shield":
				words.append("SHIELD!")
				b.raise_shield(Data.bf("boss", "shield_s"))
			"enrage":
				words.append("ENRAGED!")
				_fire_mult = Data.bf("boss", "enrage_fire_mult")
				for a2: Archer in archers:
					a2.cooldown = minf(a2.cooldown, 1.5)
			"charge":
				words.append("FULL SPEED!")
				for m: CastleMechanism in mechanisms:
					m.speed_mult = Data.bf("boss", "charge_speed_mult")
	if hud:
		hud.boss_callout(" ".join(words))
	fx.float_text(b.global_position + Vector2(0, -150), " ".join(words), Color("#ff7a6a"), 34)
	_update_hud()


func _snap_bolts_near(pos: Vector2, radius: float) -> void:
	for bolt: Bolt in bolts.duplicate():
		if not bolt.broken and bolt.position_now().distance_to(pos) < radius:
			bolt.snap()


## Level JSON "wind": {"strength": px/s², "period_s", "gust_s", "dir": 1|-1, "alternate": bool}.
## Gusts ramp in and out; heroes in flight drift with them (the aim dots do not show it).
func wind_strength_at(t: float) -> float:
	var w: Dictionary = data.get("wind", {})
	if w.is_empty():
		return 0.0
	var period: float = float(w.get("period_s", 7.0))
	var gust: float = float(w.get("gust_s", 3.0))
	var n: int = int(floor(t / period))
	var u: float = fposmod(t, period)
	var env: float = sin(PI * clampf(u / gust, 0.0, 1.0)) if u < gust else 0.0
	var dir: float = float(w.get("dir", 1))
	if bool(w.get("alternate", false)) and n % 2 == 1:
		dir = -dir
	return float(w["strength"]) * env * dir


func _tick_wind(delta: float) -> void:
	if not data.has("wind"):
		return
	_wind_t += delta
	wind_now = wind_strength_at(_wind_t)
	if background:
		background.wind = wind_now
	for p: Projectile in projectiles:
		if is_instance_valid(p) and not p.done and not p.freeze:
			p.apply_central_force(Vector2(wind_now * p.mass, 0))
	if hud:
		hud.set_wind(wind_now / maxf(1.0, float(data["wind"]["strength"])))


func _hitstop() -> void:
	if _slowmo or test_mode:
		return
	Engine.time_scale = Data.bf("fx", "hitstop_scale")
	get_tree().create_timer(Data.bf("fx", "hitstop_s"), true, false, true).timeout.connect(func() -> void:
		if not _slowmo:
			Engine.time_scale = 1.0)


func _slow_motion() -> void:
	slow_mo(Data.bf("fx", "slowmo_scale"), Data.bf("fx", "slowmo_s"))


## Real-time slow motion (ignored in tests).
func slow_mo(scale: float, real_s: float) -> void:
	if test_mode:
		return
	_slowmo = true
	Engine.time_scale = scale
	Sound.play("slowmo", 0.8)
	get_tree().create_timer(real_s, true, false, true).timeout.connect(func() -> void:
		_slowmo = false
		Engine.time_scale = 1.0
		Sound.play("slowmo_out", 0.7))


# ------------------------------------------------------------------------------------ chain reactions
func _chain_link(pos: Vector2, pts: int, kind: String) -> void:
	if is_finished() or hellfire_running:  # the Hellfire cinematic keeps the screen clean
		return
	var milestone: String = chain.link(_time, pos, pts)
	var n: int = chain.count
	if n >= 2:
		Sound.play("combo", 0.55, pow(2.0, minf(float(n - 2), 12.0) / 12.0))
		Sound.excite(float((Data.balance["audio"]["energy"] as Dictionary).get("per_chain", 0.1)))
	if hud:
		hud.set_chain(n, chain.multiplier())
	if not milestone.is_empty():
		fx.float_text(chain.center + Vector2(0, -120), milestone, Color("#ffd23a"), 44)
		Sound.play("star", 0.8, 1.0 + 0.04 * n)
		if hud:
			hud.chain_callout(milestone)
	if n >= int(Data.b("chain", "cam_at")):
		camera.set_focus(chain.center, 1.0)
	var slow: bool = n == int(Data.b("chain", "slowmo_at")) or (kind == "barrel" and n >= int(Data.b("chain", "barrel_slowmo_links")))
	if slow and _time - _chain_slowmo_t > Data.bf("chain", "slowmo_cooldown_s"):
		_chain_slowmo_t = _time
		slow_mo(Data.bf("chain", "slowmo_scale"), Data.bf("chain", "slowmo_s"))


func _pay_chain(bonus: int) -> void:
	camera.set_focus(chain.center, 0.0)
	if hud:
		hud.set_chain(0, 1.0)
	if bonus <= 0:
		return
	chain_bonus += bonus
	score += bonus
	fx.float_text(chain.center + Vector2(0, -60), "CHAIN BONUS +" + Hud.fmt(bonus), Color("#7dffb0"), 36)
	_update_hud()


## Plays the best chain again (result screen). Returns false if there is no footage.
func play_best_replay() -> bool:
	var t0: float = chain.best_start_t - Data.bf("replay", "pre_s")
	var t1: float = maxf(chain.best_end_t + Data.bf("replay", "post_s"), t0 + Data.bf("replay", "min_s"))
	if chain.best == 0:
		t1 = _time
		t0 = t1 - Data.bf("replay", "min_s") * 2.0
	return replay.play(t0, t1, chain.best_center)


func _exit_tree() -> void:
	if OS.is_debug_build() and Game.args.has("autoshot") and not test_mode:
		# Debug: lets tools/record_trailer.py pick shots that look good on video.
		print("AUTOSHOT_RESULT score=%d blocks=%d/%d guards=%d won=%s shots=%d powers=%d lost=%d chain=%d time=%.1f" % [score,
			blocks_total - blocks.size(), blocks_total, archers.size(), str(is_finished() and archers.is_empty()),
			hero_index, abilities_used, soldiers_lost, chain.best, _play_t])
		for a: Node in archers:
			if is_instance_valid(a):
				print("AUTOSHOT_LEFT %s at %s" % [a.get_class() if a.get_script() == null else a.get_script().resource_path.get_file(), str((a as Node2D).global_position.round())])
	Engine.time_scale = 1.0
	Sound.stretch_stop()
