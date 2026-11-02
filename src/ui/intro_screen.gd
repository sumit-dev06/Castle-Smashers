extends Control
## Studio intro (INTERCORE STUDIO / PRESENTS). The video and sound are captured unchanged from
## art_source/intro/intercore_studio_cinematic_intro.html by tools/capture_intro.py.
## Played by Game.boot on the first launch after an install only (not after updates, not on
## ordinary launches). The marker is its own file, outside Android's backup rules, so a reinstall
## that restores the save still plays it. Tap to skip only on debug replays (--intro).

const VIDEO: String = "res://assets/intro/intro.ogv"
const AUDIO: String = "res://assets/intro/intro.wav"

signal finished

var skippable: bool = false
var _video: VideoStreamPlayer
var _done: bool = false


static func available() -> bool:
	return ResourceLoader.exists(VIDEO) and ResourceLoader.exists(AUDIO)


const SEEN: String = "user://intro_seen"


## True on the first launch after this install.
static func due() -> bool:
	return available() and not FileAccess.file_exists(SEEN)


static func mark_seen() -> void:
	var f: FileAccess = FileAccess.open(SEEN, FileAccess.WRITE)
	if f:
		f.store_string(_version())
	Save.data["intro_version"] = _version()
	Save.write()


static func _version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: ColorRect = ColorRect.new()
	bg.color = Color.BLACK  # html, body { background-color: #000000 }
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_video = VideoStreamPlayer.new()
	_video.stream = load(VIDEO)
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_video)
	_fit()
	get_viewport().size_changed.connect(_fit)
	_video.finished.connect(_finish)
	# The sound keeps playing after the picture ends (its reverb tail), so it lives on Game.
	var music: AudioStreamPlayer = AudioStreamPlayer.new()
	music.stream = load(AUDIO)
	music.bus = "Master"
	Game.add_child(music)
	music.finished.connect(music.queue_free)
	_video.play()
	music.play()


## Letterboxed, never stretched: the 1600x720 frame keeps its proportions on any screen.
func _fit() -> void:
	var view: Vector2 = get_viewport_rect().size
	# The parent is a plain Node, so anchors cannot size this control: do it explicitly.
	position = Vector2.ZERO
	size = view
	var src: Vector2 = Vector2(1600, 720)
	var k: float = minf(view.x / src.x, view.y / src.y)
	_video.size = src * k
	_video.position = (view - _video.size) * 0.5


func _gui_input(e: InputEvent) -> void:
	if not ((e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed()):
		return
	if _title_open:
		_leave_title()
	elif skippable and not _done:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	mark_seen()
	if not ResourceLoader.exists(TITLE):
		finished.emit()
		return
	_video.stop()
	_video.visible = false
	_show_title()


## Title card after the studio intro: fades in from black, slow push-in, tap (or wait) to continue.
const TITLE: String = "res://assets/intro/title.jpg"
const TITLE_HOLD_S: float = 6.0
var _title_open: bool = false


func _show_title() -> void:
	var view: Vector2 = get_viewport_rect().size
	var tex: Texture2D = load(TITLE)
	var art: TextureRect = TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cover the screen but keep the logo (top of the art) whole: wide screens crop the bottom,
	# narrow screens crop the sides evenly.
	var k: float = maxf(view.x / tex.get_width(), view.y / tex.get_height())
	art.size = tex.get_size() * k
	art.position = Vector2((view.x - art.size.x) * 0.5, 0.0)
	art.pivot_offset = Vector2(art.size.x * 0.5, art.size.y * 0.3)
	art.modulate.a = 0.0
	add_child(art)
	var tap: Label = UIKit.label("TAP TO PLAY", 34, Color.WHITE, 9)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.size = Vector2(400, 56)
	tap.position = Vector2(view.x * 0.5 - 200.0, view.y - 96.0)
	tap.modulate.a = 0.0
	add_child(tap)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(art, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(art, "scale", Vector2.ONE * 1.04, TITLE_HOLD_S + 1.0).from(Vector2.ONE).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_title_open = true
		var pulse: Tween = create_tween().set_loops()
		pulse.tween_property(tap, "modulate:a", 1.0, 0.6)
		pulse.tween_property(tap, "modulate:a", 0.45, 0.6))
	Sound.play("screen_whoosh", 0.4)
	get_tree().create_timer(TITLE_HOLD_S).timeout.connect(_leave_title)


var _left_title: bool = false


func _leave_title() -> void:
	if _left_title or not is_inside_tree():
		return
	_left_title = true
	finished.emit()
