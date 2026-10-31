extends RefCounted
## Firebase Cloud Messaging backend for the Notifications autoload (GodotX Firebase Core + Messaging,
## addons/godotx_firebase, native modules in android/firebase_core and android/firebase_messaging).
## Only created on Android. Push messages are sent from the Firebase console to topics
## (data/notifications.json "push.topics"); the game keeps no token and needs no server.
## Android shows pushes itself while the game is in the background. The Android 13 permission is
## asked by CastleNotify (after a few levels), never by this backend.

signal opened(title: String)

var _core: Object
var _msg: Object
var _ready: bool = false
var _subscribed: int = -1
var _topics: PackedStringArray = PackedStringArray()
var _opened_window_ms: int = 0
var _started_ms: int = 0


func available() -> bool:
	return Engine.has_singleton("GodotxFirebaseCore") and Engine.has_singleton("GodotxFirebaseMessaging")


func start(topics: Array, opened_window_ms: int) -> void:
	for t: Variant in topics:
		_topics.append(String(t))
	_opened_window_ms = opened_window_ms
	_core = Engine.get_singleton("GodotxFirebaseCore")
	_msg = Engine.get_singleton("GodotxFirebaseMessaging")
	_msg.connect("messaging_message_received", _on_message)
	_msg.connect("messaging_error", _on_error)
	_core.connect("core_initialized", _on_core)
	_started_ms = Time.get_ticks_msec()
	_core.call("initialize")


func is_ready() -> bool:
	return _ready


## Subscribes to (on) or leaves (off) every push topic. Idempotent; cheap to call on each resume.
func sync(on: bool) -> void:
	if not _ready or _subscribed == int(on):
		return
	_subscribed = int(on)
	for t: String in _topics:
		_msg.call("subscribe_to_topic" if on else "unsubscribe_from_topic", t)


## A message that arrives right after start or resume came from the player tapping a push.
func resumed() -> void:
	_started_ms = Time.get_ticks_msec()


func _on_core(success: bool) -> void:
	if not success:
		return
	# Without google-services.json the app has no Firebase project; messaging reports an error and
	# stays off.
	_ready = true
	_msg.call("initialize")


func _on_message(title: String, _body: String) -> void:
	if Time.get_ticks_msec() - _started_ms <= _opened_window_ms:
		opened.emit(title)


func _on_error(message: String) -> void:
	if message == "firebase_not_initialized":
		_ready = false
	push_warning("FCM: " + message)
