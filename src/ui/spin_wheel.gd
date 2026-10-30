class_name SpinWheel
extends MetaFrame
## Spin wheel (owner reference docs/reference/spin_wheel_reference.png, matched closely): a big
## wooden wheel with iron brackets and 10 gold / violet / blue slices, a gold star hub, a red-gem
## pointer on top; "Possible rewards" parchment on the right; a green SPIN / WATCH AD button with
## "N spins left today". First spin each day is free. Odds and rewards: balance.json -> spin.

const SLICE_COLORS: Dictionary = {"gold": [Color("#ffcf3a"), Color("#d8901a")],
		"violet": [Color("#a64ae0"), Color("#6a1ea8")], "blue": [Color("#3a8ae8"), Color("#1a4aa8")]}

var _wheel: Node2D
var _pointer: TextureRect
var _spin_btn: Button
var _left: Label
var _spinning: bool = false
var _last_tick: int = -1


static func slices() -> Array:
	return Data.balance["spin"]["slices"]


static func free_spin_ready() -> bool:
	return String(Save.data.get("spin_free", "")) != Save.today()


static func ads_used() -> int:
	var d: Dictionary = Save.data.get("spin_ads", {})
	return int(d.get(Save.today(), 0))


static func spins_left() -> int:
	return (1 if free_spin_ready() else 0) + maxi(0, int(Data.b("spin", "ads_per_day")) - ads_used())


## Weighted pick; `roll` in 0..1 (tests pass a fixed roll).
static func pick(roll: float) -> int:
	var total: float = 0.0
	for s: Dictionary in slices():
		total += float(s["weight"])
	var acc: float = 0.0
	for i: int in slices().size():
		acc += float(slices()[i]["weight"]) / total
		if roll <= acc:
			return i
	return slices().size() - 1


## Spends a spin (free first, then an ad) and returns the slice index; -1 when none left.
static func use_spin(ad: bool, roll: float) -> int:
	if ad:
		if ads_used() >= int(Data.b("spin", "ads_per_day")):
			return -1
		Save.data["spin_ads"] = {Save.today(): ads_used() + 1}
	else:
		if not free_spin_ready():
			return -1
		Save.data["spin_free"] = Save.today()
	var i: int = pick(roll)
	var r: Dictionary = slices()[i]["reward"]
	for k: String in Save.WALLET:
		if r.has(k):
			Save.add(k, int(r[k]), false, false)
	Save.write()
	return i


func _title() -> String:
	return "Spin Wheel"


func _icon() -> String:
	return "icon_spin"


func _rail_items() -> Array:
	return RAIL_REWARDS


func _bg_realm() -> int:
	return 3


func _ready() -> void:
	rail_key = "spin"
	super._ready()
	Ads.rewarded_earned.connect(_on_ad)


func _build() -> void:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.place(holder, Vector2(0.5, 0.5), Vector2(-140, -10), Vector2(10, 10))
	body.add_child(holder)
	_wheel = _make_wheel(250.0)
	holder.add_child(_wheel)
	_pointer = UIKit.tex_rect("wheel_pointer", 70)
	_pointer.pivot_offset = Vector2(_pointer.custom_minimum_size.x * 0.5, 8)
	_pointer.position = Vector2(-_pointer.custom_minimum_size.x * 0.5 + 5, -282)
	holder.add_child(_pointer)
	_wheel.scale = Vector2.ONE * 0.2
	_wheel.create_tween().tween_property(_wheel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_build_rewards_panel()
	_spin_btn = UIKit.button("", "green", 34, Vector2(380, 92))
	UIKit.place(_spin_btn, Vector2(0.5, 1), Vector2(-325, -138), Vector2(380, 92))
	_spin_btn.pressed.connect(_on_spin)
	UIFx.press_juice(_spin_btn)
	body.add_child(_spin_btn)
	_left = UIKit.label("", 22, Color.WHITE, 7, false)
	UIKit.place(_left, Vector2(0.5, 1), Vector2(-325, -42), Vector2(380, 30))
	body.add_child(_left)
	_refresh()


## The wheel is a Node2D drawn in code so it can spin smoothly: rim, brackets, slices, icons, hub.
func _make_wheel(r: float) -> Node2D:
	var w: Node2D = Node2D.new()
	var n: int = slices().size()
	var rim: Polygon2D = _disc(r + 26.0, Color("#3a2212"))
	w.add_child(rim)
	w.add_child(_disc(r + 20.0, Color("#a8642e")))
	w.add_child(_disc(r + 8.0, Color("#6e3e1c")))
	for i: int in n:
		var a0: float = TAU * float(i) / float(n) - PI * 0.5 - PI / float(n)
		var a1: float = a0 + TAU / float(n)
		var cols: Array = SLICE_COLORS[String(slices()[i]["color"])]
		var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
		var cpts: PackedColorArray = PackedColorArray([(cols[0] as Color).lightened(0.2)])
		for k: int in 13:
			var a: float = lerpf(a0, a1, float(k) / 12.0)
			pts.append(Vector2.from_angle(a) * r)
			cpts.append(cols[1])
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = pts
		poly.vertex_colors = cpts
		w.add_child(poly)
		var edge: Line2D = Line2D.new()
		edge.points = PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a0) * r])
		edge.width = 5.0
		edge.default_color = Color("#3a2212")
		w.add_child(edge)
		var mid: float = (a0 + a1) * 0.5
		var reward: Dictionary = slices()[i]["reward"]
		var kind: String = "coins"
		for k2: String in ["gems", "coins"]:
			if reward.has(k2):
				kind = k2
				break
		var icon: Sprite2D = Art.sprite(UIKit.CURRENCY_ICON[kind], 1.15 if not bool(slices()[i].get("jackpot", false)) else 1.45)
		icon.position = Vector2.from_angle(mid) * r * 0.66
		icon.rotation = mid + PI * 0.5
		w.add_child(icon)
		var lab: Label = UIKit.label(CurrencyBar._fmt(int(reward[kind])), 24, Color.WHITE, 7)
		lab.size = Vector2(110, 32)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.pivot_offset = lab.size * 0.5
		lab.position = Vector2.from_angle(mid) * r * 0.42 - lab.size * 0.5
		lab.rotation = mid + PI * 0.5
		w.add_child(lab)
	# Iron brackets around the rim (the pointer ticks against these).
	for i2: int in n:
		var a2: float = TAU * float(i2) / float(n) - PI * 0.5 - PI / float(n)
		var br: Polygon2D = _rect_poly(Vector2(18, 30), Color("#7d8792"))
		br.position = Vector2.from_angle(a2) * (r + 12.0)
		br.rotation = a2 + PI * 0.5
		w.add_child(br)
		var rivet: Polygon2D = _disc(5.0, Color("#eef2f5"))
		rivet.position = br.position
		w.add_child(rivet)
	var hub: Sprite2D = Art.sprite("star_full", 1.5)
	w.add_child(_disc(52.0, Color("#3a2212")))
	w.add_child(_disc(46.0, Color("#c88a2a")))
	w.add_child(hub)
	return w


static func _disc(r: float, c: Color) -> Polygon2D:
	var p: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 64:
		pts.append(Vector2.from_angle(TAU * float(k) / 64.0) * r)
	p.polygon = pts
	p.color = c
	return p


static func _rect_poly(sz: Vector2, c: Color) -> Polygon2D:
	var p: Polygon2D = Polygon2D.new()
	p.polygon = PackedVector2Array([-sz * 0.5, Vector2(sz.x, -sz.y) * 0.5, sz * 0.5, Vector2(-sz.x, sz.y) * 0.5])
	p.color = c
	return p


func _build_rewards_panel() -> void:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_box(Color("#f4e2b8"), Color("#8a5a2a")))
	UIKit.place(p, Vector2(1, 0.5), Vector2(-420, -230), Vector2(390, 420))
	body.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UIKit.label("Possible Rewards", 30, UIKit.TEXT_DARK, 0))
	var g: GridContainer = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	var ranges: Dictionary = {}
	for s: Dictionary in slices():
		for k: String in s["reward"]:
			var a: Array = ranges.get(k, [1 << 30, 0])
			ranges[k] = [mini(int(a[0]), int(s["reward"][k])), maxi(int(a[1]), int(s["reward"][k]))]
	var labels: Dictionary = {"coins": "Gold", "gems": "Gems"}
	for k3: String in Save.WALLET:
		if not ranges.has(k3):
			continue
		var cell: PanelContainer = PanelContainer.new()
		cell.add_theme_stylebox_override("panel", card_box(Color("#5a3418"), Color("#c8a060")))
		var cv: VBoxContainer = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		cv.add_child(UIKit.tex_rect(UIKit.CURRENCY_ICON[k3], 54))
		cv.add_child(UIKit.label(String(labels[k3]), 20, Color.WHITE, 5))
		cv.add_child(UIKit.label("%s - %s" % [CurrencyBar._fmt(int(ranges[k3][0])), CurrencyBar._fmt(int(ranges[k3][1]))], 18, Color("#ffe27a"), 5))
		cell.add_child(cv)
		cell.custom_minimum_size = Vector2(170, 120)
		g.add_child(cell)
	var jack: PanelContainer = PanelContainer.new()
	jack.add_theme_stylebox_override("panel", card_box(Color("#6a1ea8"), Color("#ffd23a")))
	var jv: VBoxContainer = VBoxContainer.new()
	jv.add_child(UIKit.tex_rect("icon_crown", 54))
	jv.add_child(UIKit.label("Jackpot", 20, Color.WHITE, 5))
	jv.add_child(UIKit.label("Rare: 3 gems", 18, Color("#ffe27a"), 5))
	jack.add_child(jv)
	jack.custom_minimum_size = Vector2(170, 120)
	g.add_child(jack)
	UIFx.slide_in(p, Vector2(1, 0), 0.1)


func _refresh() -> void:
	var free: bool = free_spin_ready()
	var left: int = spins_left()
	# One free spin a day; every extra spin is a rewarded video (granted without the video with Remove Ads).
	_spin_btn.text = "FREE SPIN" if free else ("  SPIN AGAIN" if Ads.ads_removed() else "  WATCH AD: SPIN")
	_spin_btn.icon = null if free or Ads.ads_removed() else Art.tex("icon_video")
	_spin_btn.expand_icon = true
	_spin_btn.add_theme_constant_override("icon_max_width", 48)
	_spin_btn.disabled = left <= 0 or _spinning
	var ad_left: int = left - (1 if free else 0)
	if free:
		_left.text = "1 free spin today, then %d more with a video" % ad_left
	elif left > 0:
		_left.text = "Free spin used. %d video spin%s left today" % [ad_left, "" if ad_left == 1 else "s"]
	else:
		_left.text = "All spins used. A new free spin comes tomorrow!"
	if left > 0 and not _spinning:
		UIFx.breathe(_spin_btn)


func _on_spin() -> void:
	if _spinning:
		return
	if free_spin_ready():
		_run(use_spin(false, randf()))
	elif not Ads.rewarded_ready():
		_left.text = "No video available right now. Try again soon."
	else:
		Ads.show_rewarded("spin")


func _on_ad(reward_id: String) -> void:
	if reward_id == "spin" and not _spinning:
		Analytics.event("rewarded_ad_watched", {"placement": "spin", "reward_amount": 1})
		_run(use_spin(true, randf()))


func _run(i: int) -> void:
	if i < 0:
		_refresh()
		return
	_spinning = true
	_refresh()
	var n: int = slices().size()
	var target: float = -TAU * float(i) / float(n)
	var start: float = fposmod(_wheel.rotation, TAU)
	var end: float = start + TAU * float(Data.b("spin", "turns")) + fposmod(target - start, TAU) + randf_range(-0.35, 0.35) * TAU / float(n)
	_wheel.rotation = start
	Sound.play("whoosh", 0.7)
	var tw: Tween = create_tween()
	tw.tween_method(_spin_step, start, end, Data.bf("spin", "spin_s")).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _land(i))


func _spin_step(a: float) -> void:
	_wheel.rotation = a
	var n: int = slices().size()
	var tick: int = int(floor((a + PI / float(n)) / (TAU / float(n))))
	if tick != _last_tick:
		_last_tick = tick
		Sound.play("wheel_tick", 0.6)
		_pointer.rotation = -0.35
		_pointer.create_tween().tween_property(_pointer, "rotation", 0.0, 0.09)


func _land(i: int) -> void:
	_spinning = false
	var reward: Dictionary = slices()[i]["reward"]
	var center: Vector2 = _wheel.get_global_transform_with_canvas().origin + Vector2(0, -150)
	UIFx.rays(UIFx.overlay(), center, 380.0, 1.4)
	UIFx.confetti(center, 60 if bool(slices()[i].get("jackpot", false)) else 36)
	Sound.play("purchase")
	var pop: HBoxContainer = reward_row(reward, 64)
	pop.position = center - Vector2(120, 40)
	pop.size = Vector2(240, 80)
	UIFx.overlay().add_child(pop)
	UIFx.pop_in(pop)
	var tw: Tween = pop.create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		pay(reward, center)
		pop.queue_free())
	_refresh()
