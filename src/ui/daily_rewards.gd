class_name DailyRewards
extends MetaFrame
## Daily login calendar (owner reference docs/reference/daily_rewards_reference.png): "Login Daily"
## ribbon, 7 day cards (claimed = green tick, today glows and bobs, day 7 a big gold Epic Chest card),
## CLAIM REWARD, and a reward preview strip. Rewards: balance.json -> daily. Missing a day keeps the
## streak (only one claim per calendar day).

var _cards: Array[PanelContainer] = []
var _claim: Button
var _note: Label


static func days() -> Array:
	return Data.balance["daily"]["days"]


## Next day index to claim (0..6), wrapping after day 7.
static func next_day() -> int:
	return int(Save.data.get("daily_streak", 0)) % days().size()


static func can_claim() -> bool:
	return String(Save.data.get("daily_last", "")) != Save.today()


## Claims today's reward (currencies added to the save). Returns it, or {} if already claimed.
static func claim() -> Dictionary:
	if not can_claim():
		return {}
	var r: Dictionary = (days()[next_day()] as Dictionary).duplicate()
	Save.data["daily_streak"] = int(Save.data.get("daily_streak", 0)) + 1
	Save.data["daily_last"] = Save.today()
	for k: String in Save.WALLET:
		if r.has(k):
			Save.add(k, int(r[k]), false, false)
	Save.write()
	return r


func _title() -> String:
	return "Daily Rewards"


func _icon() -> String:
	return "icon_daily"


func _rail_items() -> Array:
	return RAIL_REWARDS


func _bg_realm() -> int:
	return 2


func _ready() -> void:
	rail_key = "daily"
	super._ready()


func _build() -> void:
	var ribbon: PanelContainer = PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", card_box(Color("#b8261e"), Color("#ffc93a")))
	var rv: VBoxContainer = VBoxContainer.new()
	rv.add_theme_constant_override("separation", -6)
	rv.add_child(UIKit.label("Login Daily", 54, Color("#ffd23a"), 12))
	rv.add_child(UIKit.label("Get amazing rewards every day!", 24, Color.WHITE, 7))
	ribbon.add_child(rv)
	UIKit.place(ribbon, Vector2(0.5, 0), Vector2(-200, 100), Vector2(560, 120))
	body.add_child(ribbon)
	UIFx.pop_in(ribbon, 0.05)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	UIKit.place(row, Vector2(0.5, 0), Vector2(-390, 236), Vector2(1160, 270))
	body.add_child(row)
	var nd: int = next_day()
	var today_open: bool = can_claim()
	# After claiming day 7 the cycle wraps to 0: show the finished week until tomorrow.
	var claimed_n: int = days().size() if (nd == 0 and not today_open and int(Save.data.get("daily_streak", 0)) > 0) else nd
	for i: int in days().size():
		var c: PanelContainer = _day_card(i, i == nd and today_open, i < claimed_n)
		row.add_child(c)
		_cards.append(c)
		UIFx.pop_in(c, 0.12 + 0.05 * i)
	_claim = UIKit.button("Claim Reward", "green", 38, Vector2(380, 86))
	UIKit.place(_claim, Vector2(0.5, 0), Vector2(-60, 520), Vector2(380, 86))
	_claim.pressed.connect(_on_claim)
	UIFx.press_juice(_claim)
	body.add_child(_claim)
	_note = UIKit.label("", 22, Color.WHITE, 6, false)
	UIKit.place(_note, Vector2(0.5, 0), Vector2(-160, 600), Vector2(580, 30))
	body.add_child(_note)
	var prev: PanelContainer = _dark_panel()
	UIKit.place(prev, Vector2(0.5, 1), Vector2(-330, -86), Vector2(900, 76))
	body.add_child(prev)
	var ph: HBoxContainer = HBoxContainer.new()
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	ph.add_theme_constant_override("separation", 26)
	prev.add_child(ph)
	ph.add_child(UIKit.label("Reward Preview", 22, Color("#ffe27a"), 6))
	for it: Array in [["coin", "Gold 200 - 1,500"], ["gem", "5 Gems on day 7"], ["chest_closed", "Weekly Chest"]]:
		var h: HBoxContainer = HBoxContainer.new()
		h.add_child(UIKit.tex_rect(String(it[0]), 36))
		h.add_child(UIKit.label(String(it[1]), 18, Color.WHITE, 5, false))
		ph.add_child(h)
	_refresh()


func _day_card(i: int, today: bool, claimed: bool) -> PanelContainer:
	var last: bool = i == days().size() - 1
	var p: PanelContainer = PanelContainer.new()
	var col: Color = Color("#e8a81a") if last else Color("#2e4a22")
	p.add_theme_stylebox_override("panel", card_box(col, Color("#ffe27a") if last or today else Color("#7a5a30")))
	p.custom_minimum_size = Vector2(250 if last else 132, 250 if last else 220)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(UIKit.label("Day %d" % (i + 1), 26 if last else 22, Color.WHITE, 7))
	var r: Dictionary = days()[i]
	if last:
		v.add_child(UIKit.tex_rect("chest_closed", 110))
		v.add_child(UIKit.label("Epic Chest", 26, Color.WHITE, 7))
	else:
		var kind: String = "coins"
		for k: String in ["gems", "coins"]:
			if r.has(k):
				kind = k
				break
		v.add_child(UIKit.tex_rect(UIKit.CURRENCY_ICON[kind], 64))
		var extra: String = " +" if r.size() > 1 else ""
		v.add_child(UIKit.label(CurrencyBar._fmt(int(r[kind])) + extra, 26, Color.WHITE, 7))
	if claimed:
		v.add_child(UIKit.tex_rect("icon_check", 46))
		p.modulate = Color(0.85, 0.9, 0.85)
	elif today:
		# Containers own position, so today's card breathes (scale) and glows instead of bobbing.
		UIFx.breathe(p)
		var tw: Tween = p.create_tween().set_loops()
		tw.tween_property(p, "self_modulate", Color(1.35, 1.3, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p, "self_modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	return p


func _refresh() -> void:
	var ok: bool = can_claim()
	UIKit.locked(_claim, "" if ok else "Today's reward is claimed. Come back tomorrow for the next one!")
	_claim.text = "Claim Reward" if ok else "Claimed"
	if ok:
		UIFx.breathe(_claim)
		_note.text = ""
	else:
		var now: Dictionary = Time.get_time_dict_from_system()
		var left: int = 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		_note.text = "Next reward in %dh %02dm" % [left / 3600, (left / 60) % 60]


func _on_claim() -> void:
	var i: int = next_day()
	var card: PanelContainer = _cards[i]
	var r: Dictionary = claim()
	if r.is_empty():
		return
	var from: Vector2 = card.get_global_rect().get_center()
	if bool(r.get("chest", false)):
		Sound.play("chest_open")
		UIFx.rays(UIFx.overlay(), from, 360.0, 1.6)
	UIFx.celebrate(card, "CLAIMED!")
	var tw: Tween = create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		pay(r, from)
		var check: TextureRect = UIKit.tex_rect("icon_check", 46)
		(card.get_child(0) as VBoxContainer).add_child(check)
		UIFx.pop(check, 1.6))
	_refresh()
