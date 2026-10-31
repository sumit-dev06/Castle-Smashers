extends Node
## Adaptive audio. Buses (created at startup): Master <- Music, Ambience, SFX, UI.
##   Sound.play(name, vol, pitch)     one-shot SFX: random variant, cooldowns, UI names go to the UI bus
##   Sound.play_at(name, pos, vol, pitch)  the same, placed in the world: panned and spread by
##                                    AudioStreamPlayer2D relative to the camera (impacts, breaks, units)
##   Sound.set_music(song, state)     three stems per song (base, action, climax) in one
##                                    AudioStreamSynchronized, sample-locked; crossfaded between songs
##   Sound.music_state(state)         menu / map / aim / flight / destruction / result
##   Sound.excite(amount)             destruction energy: pushes the action stem up, then decays
##   Sound.stinger(name)              win / lose / boss_intro / siege_start / reward (ducks the music)
##   Sound.set_surroundings(realm, menu)  ambience bed, scattered details and SFX reverb for a realm
## Pause and slow motion muffle music and ambience with a low-pass. Numbers: data/balance.json -> audio.

const SFX_DIR: String = "res://assets/audio/sfx/%s_%d.wav"
const MUSIC_DIR: String = "res://assets/audio/music/%s.ogg"
const AMB_DIR: String = "res://assets/audio/ambience/%s.ogg"
const STEMS: PackedStringArray = ["base", "action", "climax"]
const AMB_VARIANT: String = "res://assets/audio/ambience/amb_%s_%d.wav"
const MAX_VARIANTS: int = 6
const SILENT_DB: float = -60.0


## One song: its stems inside one AudioStreamSynchronized, so they start and loop on the same sample.
## Stem levels are the synchronized stream's per-stem volumes (read by the mixer every block).
class Deck:
	extends RefCounted
	var player: AudioStreamPlayer
	var sync: AudioStreamSynchronized
	var song: String = ""
	var gain: float = 0.0
	var target: float = 0.0


var song: String = ""
var state: String = "menu"
var realm: String = ""

var _streams: Dictionary = {}
var _last_ms: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _amb_pool: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _amb_2d: Array[AudioStreamPlayer2D] = []
var _decks: Array[Deck] = []
var _sting: AudioStreamPlayer
var _beds: Array[AudioStreamPlayer] = []
var _bed_gain: Array[float] = [0.0, 0.0]
var _bed_target: Array[float] = [0.0, 0.0]
var _bed_db: float = 0.0
var _amb_details: Array = []
var _amb_next: Array[float] = []
var _ui_names: Dictionary = {}
var _action_db: float = SILENT_DB
var _climax_db: float = SILENT_DB
var _energy: float = 0.0
var _energy_hold: float = 0.0
var _duck_db: float = 0.0
# Collapse layer: recent breaks [ms, pos, mass], the size already played for this fall, last break.
var _fall: Array = []
var _fall_tier: int = -1
var _fall_last_ms: int = 0
var _fall_count: int = 0
var _fall_pos: Vector2 = Vector2.ZERO
var _cutoff: float = 20000.0
var _slow_real_s: float = 0.0
var _last_us: int = 0
var _filters: Array[AudioEffectLowPassFilter] = []
var _reverb: AudioEffectReverb
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _stretch: AudioStreamPlayer
var _stretch_on: bool = false
var _ratchet_power: float = 0.0
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_buses()
	for i: int in int(Data.b("audio", "pool_size")):
		_pool.append(_player("SFX"))
	for i: int in int(_cfg("ui_pool_size", 4)):
		_ui_pool.append(_player("UI"))
	for i: int in int(_cfg("ambience_pool_size", 3)):
		_amb_pool.append(_player("Ambience"))
	for i: int in 2:
		var d: Deck = Deck.new()
		d.player = _player("Music")
		_decks.append(d)
		_beds.append(_player("Ambience"))
	for i: int in int(_cfg("pool_2d_size", 12)):
		_pool_2d.append(_player_2d("SFX"))
	for i: int in int(_cfg("ambience_pool_size", 3)):
		_amb_2d.append(_player_2d("Ambience"))
	_sting = _player("Music")
	_stretch = _player("SFX")
	var loop_path: String = "res://assets/audio/sfx/stretch_loop.wav"
	if ResourceLoader.exists(loop_path):
		_stretch.stream = _looped(loop_path)
	for n: Variant in _cfg("ui_sounds", []):
		_ui_names[String(n)] = true
	_last_us = Time.get_ticks_usec()
	apply_settings()
	# Game events drive the music state and the destruction energy (no gameplay code calls these).
	Events.projectile_launched.connect(func(_kind: String) -> void:
		if state == "aim" or state == "destruction":
			music_state("flight"))
	Events.big_impact.connect(func(_pos: Vector2, _impulse: float) -> void:
		_hit("per_impact")
		duck(float((_cfg("duck", {}) as Dictionary).get("impact_db", 0.0))))
	Events.block_destroyed.connect(func(b: Node2D, _s: int) -> void:
		_on_break(b)
		_hit("per_block")
		duck(float((_cfg("duck", {}) as Dictionary).get("block_db", 0.0))))
	Events.archer_defeated.connect(func(_a: Node2D, _s: int) -> void: _hit("per_block"))
	Events.explosion.connect(func(_pos: Vector2, _r: float) -> void: _boom())
	Events.quake.connect(func(_pos: Vector2, _r: float) -> void: _boom())
	Events.level_finished.connect(func(_id: int, _won: bool, _stars: int, _score: int) -> void: music_state("result"))
	_debug_record()


## Debug builds: --record-audio=seconds[,path] writes the Master mix to a WAV (default
## build/shots/audio.wav) so the real in-game mix can be measured without listening.
func _debug_record() -> void:
	if not OS.is_debug_build():
		return
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--record-audio="):
			continue
		var parts: PackedStringArray = arg.trim_prefix("--record-audio=").split(",")
		var path: String = parts[1] if parts.size() > 1 else "res://build/shots/audio.wav"
		var rec: AudioEffectRecord = AudioEffectRecord.new()
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), rec)
		rec.set_recording_active(true)
		get_tree().create_timer(float(parts[0]), true, false, true).timeout.connect(func() -> void:
			rec.set_recording_active(false)
			var wav: AudioStreamWAV = rec.get_recording()
			if wav:
				wav.save_to_wav(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
				print("Sound: recorded %.1fs to %s" % [wav.get_length(), path]))


func _hit(key: String) -> void:
	if state == "flight" or state == "aim" or state == "destruction":
		excite(float((_cfg("energy", {}) as Dictionary).get(key, 0.1)))
		if state == "flight":
			music_state("destruction")


func _boom() -> void:
	_hit("per_explosion")
	duck(float((_cfg("duck", {}) as Dictionary).get("explosion_db", -5.0)))


func _cfg(key: String, fallback: Variant) -> Variant:
	return (Data.balance["audio"] as Dictionary).get(key, fallback)


func _player(bus_name: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p


## A world voice. Godot pans it by its position on screen and attenuates it with distance from the
## camera. The autoload is a plain Node, so the player's position is its world position.
func _player_2d(bus_name: String) -> AudioStreamPlayer2D:
	var p: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	var pos_cfg: Dictionary = _cfg("positional", {})
	p.bus = bus_name
	p.max_distance = float(pos_cfg.get("max_distance", 6000.0))
	p.attenuation = float(pos_cfg.get("attenuation", 0.6))
	p.panning_strength = float(pos_cfg.get("panning_strength", 1.0))
	add_child(p)
	return p


func _build_buses() -> void:
	for bus_name: String in ["Music", "Ambience", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var master: int = AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		# Glue compressor + ceiling on the full mix: many synthetic hits at once stay smooth.
		var comp: AudioEffectCompressor = AudioEffectCompressor.new()
		comp.threshold = float(_cfg("master_threshold_db", -14.0))
		comp.ratio = float(_cfg("master_ratio", 3.0))
		comp.attack_us = 8000.0
		comp.release_ms = 180.0
		AudioServer.add_bus_effect(master, comp)
		if ClassDB.class_exists("AudioEffectHardLimiter"):
			var lim: AudioEffect = ClassDB.instantiate("AudioEffectHardLimiter") as AudioEffect
			lim.set("ceiling_db", Data.bf("audio", "limiter_ceiling_db"))
			# Make-up into the limiter: phones play games quietly, so the mix is mastered toward the
			# mobile target (about -18 LUFS) while the limiter keeps the peaks under the ceiling.
			lim.set("pre_gain_db", float(_cfg("limiter_pre_gain_db", 0.0)))
			lim.set("release", float(_cfg("limiter_release_s", 0.1)))
			AudioServer.add_bus_effect(master, lim)
	var sfx: int = AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		_reverb = AudioEffectReverb.new()
		_reverb.wet = 0.0
		AudioServer.add_bus_effect(sfx, _reverb)
	else:
		_reverb = AudioServer.get_bus_effect(sfx, 0) as AudioEffectReverb
	for bus_name: String in ["Music", "Ambience"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if AudioServer.get_bus_effect_count(idx) == 0:
			var f: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
			f.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(idx, f)
		_filters.append(AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter)


func apply_settings() -> void:
	var music_volume: float = clampf(float(Save.data.get("music_volume", 1.0)), 0.0, 1.0)
	var sfx_volume: float = clampf(float(Save.data.get("sfx_volume", 1.0)), 0.0, 1.0)
	var music_off: bool = not bool(Save.data.get("music", true)) or music_volume <= 0.001
	var sfx_off: bool = not bool(Save.data.get("sfx", true)) or sfx_volume <= 0.001
	var m_db: float = linear_to_db(maxf(music_volume, 0.001))
	var s_db: float = linear_to_db(maxf(sfx_volume, 0.001))
	_bus("Music", Data.bf("audio", "music_db") + m_db, music_off)
	_bus("SFX", Data.bf("audio", "sfx_db") + s_db, sfx_off)
	_bus("UI", float(_cfg("ui_db", -2.0)) + s_db, sfx_off)
	# The world's ambience follows the sound-effects setting: music off still leaves the surroundings.
	_bus("Ambience", float(_cfg("ambience_db", -4.0)) + s_db, sfx_off)


func _bus(bus_name: String, db: float, mute: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, mute)


# ------------------------------------------------------------------------------------------- SFX
func _variants(sound: String) -> Array:
	if not _streams.has(sound):
		var list: Array = []
		for i: int in MAX_VARIANTS:
			var path: String = SFX_DIR % [sound, i]
			if not ResourceLoader.exists(path):
				break
			list.append(load(path))
		if list.is_empty():
			push_warning("Sound: no files for '%s'" % sound)
		_streams[sound] = list
	return _streams[sound]


## volume01 in 0..1, scaled to dB. Repeated sounds use data-driven cooldowns.
func play(sound: String, volume01: float = 1.0, pitch: float = 1.0) -> void:
	_start(sound, volume01, pitch, Vector2.ZERO, false)


## A world sound at a world position: panned across the stereo field by where it is on screen and
## a little quieter far from the camera. Without a 2D camera (menus) it plays like play().
func play_at(sound: String, pos: Vector2, volume01: float = 1.0, pitch: float = 1.0) -> void:
	var positional: bool = _pool_2d.size() > 0 and not _ui_names.has(sound) \
			and is_inside_tree() and get_viewport().get_camera_2d() != null
	_start(sound, volume01, pitch, pos, positional)


func _start(sound: String, volume01: float, pitch: float, pos: Vector2, positional: bool) -> void:
	var audio_cfg: Dictionary = Data.balance["audio"]
	var cooldowns: Dictionary = audio_cfg.get("cooldown_ms", {})
	var interval_ms: int = int(cooldowns.get(sound, Data.b("audio", "min_interval_ms")))
	var now: int = Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < interval_ms:
		return
	var list: Array = _variants(sound)
	if list.is_empty() or volume01 <= 0.01:
		return
	var cap: int = int((audio_cfg.get("max_voices", {}) as Dictionary).get(sound, 0))
	if cap > 0 and _voices_playing(sound) >= cap:
		return
	var gains: Dictionary = audio_cfg.get("sound_gain_db", {})
	var requested_db: float = linear_to_db(clampf(volume01, 0.0, 1.0)) + float(gains.get(sound, 0.0))
	var ui: bool = _ui_names.has(sound)
	if not ui:
		requested_db += float(_cfg("level_sfx_db", 0.0))
	if positional:
		# Godot's 2D pan law halves each side at the centre; make_up keeps the level of play().
		requested_db += float((_cfg("positional", {}) as Dictionary).get("make_up_db", 0.0))
	var player: Node = _free_voice(_pool_2d if positional else _ui_pool if ui else _pool, requested_db)
	if player == null:
		return
	_last_ms[sound] = now
	var vary: float = Data.bf("audio", "pitch_variation") * (0.5 if ui else 1.0)
	if positional:
		(player as AudioStreamPlayer2D).global_position = pos
	player.set_meta("snd", sound)
	player.set("stream", list[_rng.randi() % list.size()])
	player.set("volume_db", requested_db)
	player.set("pitch_scale", maxf(0.2, pitch * _rng.randf_range(1.0 - vary, 1.0 + vary) * (1.0 if ui else _slow_pitch())))
	player.call("play")


## Voices of one sound still playing (per-material cap: twenty planks breaking at once read as one
## wall of noise; three voices plus the collapse layer read as a building falling).
func _voices_playing(sound: String) -> int:
	var n: int = 0
	for pool: Array in [_pool_2d, _pool]:
		for v: Node in pool:
			if bool(v.get("playing")) and String(v.get_meta("snd", "")) == sound:
				n += 1
	return n


## Collapse layer (data: audio.collapse). Breaks close together in time are one fall: as the count
## or mass inside the window passes each tier, the matching collapse sound plays once at the
## centre of the breaks; when the breaks stop, a rubble tail settles.
func _on_break(b: Node2D) -> void:
	var c: Dictionary = _cfg("collapse", {})
	if c.is_empty() or not is_instance_valid(b):
		return
	var now: int = Time.get_ticks_msec()
	var mass: float = float(b.get("mass")) if b.get("mass") != null else 1.0
	_fall.append([now, b.global_position, mass])
	var window: int = int(c.get("window_ms", 700))
	while not _fall.is_empty() and now - int(_fall[0][0]) > window:
		_fall.pop_front()
	var sum_m: float = 0.0
	var centre: Vector2 = Vector2.ZERO
	for e: Array in _fall:
		sum_m += float(e[2])
		centre += e[1] as Vector2
	centre /= float(_fall.size())
	_fall_pos = centre
	_fall_last_ms = now
	_fall_count += 1
	var tiers: Array = c.get("tiers", [])
	var tier: int = -1
	for i: int in tiers.size():
		var t: Dictionary = tiers[i]
		if _fall.size() >= int(t.get("count", 99)) or sum_m >= float(t.get("mass", 1e9)):
			tier = i
	if tier > _fall_tier:
		_fall_tier = tier
		play_at(String(tiers[tier]["sound"]), centre, float(tiers[tier].get("volume", 1.0)))
		if OS.is_debug_build() and "--log-audio" in OS.get_cmdline_user_args():
			print("Sound: collapse tier %d (%d breaks, mass %.1f)" % [tier, _fall.size(), sum_m])
		duck(float(c.get("duck_db", -6.0)))


func _settle_fall() -> void:
	if _fall_tier < 0 or Time.get_ticks_msec() - _fall_last_ms < int((_cfg("collapse", {}) as Dictionary).get("settle_ms", 900)):
		return
	var c: Dictionary = _cfg("collapse", {})
	play_at(String(c.get("settle_sound", "rubble_settle")), _fall_pos, clampf(0.4 + 0.05 * _fall_count, 0.4, 1.0))
	_fall_tier = -1
	_fall_count = 0
	_fall.clear()


## A free voice from the pool, else the quietest one (never a loud impact for a quiet sound).
## Works for AudioStreamPlayer and AudioStreamPlayer2D pools.
func _free_voice(pool: Array, requested_db: float) -> Node:
	for candidate: Node in pool:
		if not bool(candidate.get("playing")):
			return candidate
	var quiet: Node = pool[0]
	for candidate: Node in pool:
		if float(candidate.get("volume_db")) < float(quiet.get("volume_db")):
			quiet = candidate
	# Preserve an existing loud impact instead of replacing it with a quiet incidental sound.
	if requested_db + 3.0 < float(quiet.get("volume_db")):
		return null
	quiet.call("stop")
	return quiet


## Long slow motion (chain cinematics) drops world sounds in pitch; short hit-stops do not.
func _slow_pitch() -> float:
	if _slow_real_s < float(_cfg("slowmo_pitch_after_s", 0.15)):
		return 1.0
	return lerpf(1.0, Engine.time_scale, float(_cfg("slowmo_pitch_follow", 0.45)))


## Catapult rope under tension while aiming: a looping creak whose volume and pitch follow the pull,
## plus a ratchet click every `catapult.ratchet_step` of extra pull. power 0..1.
func stretch(power: float) -> void:
	if _stretch.stream == null:
		return
	var p: float = clampf(power, 0.0, 1.0)
	_stretch.volume_db = lerpf(Data.bf("catapult", "stretch_db_min"), Data.bf("catapult", "stretch_db_max"), p)
	_stretch.pitch_scale = lerpf(Data.bf("catapult", "stretch_pitch_min"), Data.bf("catapult", "stretch_pitch_max"), p)
	if not _stretch_on:
		_stretch_on = true
		_ratchet_power = 0.0
		_stretch.play()
	var step: float = Data.bf("catapult", "ratchet_step")
	if p >= _ratchet_power + step:
		_ratchet_power = floorf(p / step) * step
		play("ratchet", 0.6 + 0.4 * p, 0.9 + 0.3 * p)
	elif p < _ratchet_power - step:
		_ratchet_power = floorf(p / step) * step


func stretch_stop() -> void:
	_stretch_on = false
	_ratchet_power = 0.0
	_stretch.stop()


## Volume for an impact of a given impulse.
func impact_volume(impulse: float) -> float:
	return clampf(impulse / Data.bf("audio", "impact_ref_impulse"), 0.15, 1.0)


# ------------------------------------------------------------------------------------------- music
func _looped(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	var w: AudioStreamWAV = s as AudioStreamWAV
	if w and w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	var o: AudioStreamOggVorbis = s as AudioStreamOggVorbis
	if o and not o.loop:
		# Vorbis keeps the exact sample count, so looping the whole file is seamless.
		o.loop = true
		o.loop_offset = 0.0
	return s


## The song's stems as one synchronized stream (base first). Missing stems are skipped.
func _song_stream(p_song: String) -> AudioStreamSynchronized:
	var streams: Array[AudioStream] = []
	for stem: String in STEMS:
		var st: AudioStream = _looped(MUSIC_DIR % (p_song + "_" + stem))
		if st == null and stem == "base":
			return null
		if st:
			streams.append(st)
	var sync: AudioStreamSynchronized = AudioStreamSynchronized.new()
	sync.stream_count = streams.size()
	for i: int in streams.size():
		sync.set_sync_stream(i, streams[i])
		sync.set_sync_stream_volume(i, SILENT_DB)
	return sync


## Old API: maps a track name onto the adaptive player.
func play_music(track: String) -> void:
	set_music(track, state)


## Songs: menu, boss, or a realm key (blossom, desert, harbor, mines, sky).
func set_music(p_song: String, p_state: String = "") -> void:
	if not p_state.is_empty():
		music_state(p_state)
	if p_song == song and _decks[0].song == p_song and _decks[0].target > 0.0:
		return
	var sync: AudioStreamSynchronized = _streams.get("song:" + p_song) as AudioStreamSynchronized
	if sync == null:
		sync = _song_stream(p_song)
		if sync == null:
			return
		_streams["song:" + p_song] = sync
	song = p_song
	# The current deck fades out, the other one takes the new song.
	var old: Deck = _decks[0]
	var nxt: Deck = _decks[1]
	_decks = [nxt, old]
	old.target = 0.0
	if nxt.sync == sync:
		# Coming back to the song the other deck is still fading out of: give it its own copy so the
		# per-stem volumes of the two decks don't fight.
		sync = sync.duplicate() as AudioStreamSynchronized
	nxt.song = p_song
	nxt.sync = sync
	nxt.player.stream = sync
	nxt.gain = 0.0
	nxt.target = 1.0
	nxt.player.volume_db = SILENT_DB
	nxt.player.play()


func music_state(p_state: String) -> void:
	state = p_state


func excite(amount: float) -> void:
	_energy = clampf(_energy + amount, 0.0, 1.0)
	_energy_hold = float((_cfg("energy", {}) as Dictionary).get("hold_s", 2.5))


func duck(db: float) -> void:
	_duck_db = minf(_duck_db, db)


func stinger(name: String) -> void:
	var path: String = MUSIC_DIR % ("sting_" + name)
	if not ResourceLoader.exists(path):
		return
	_sting.stream = load(path)
	_sting.volume_db = float((_cfg("stinger_db", {}) as Dictionary).get(name, 0.0))
	_sting.play()
	duck(float((_cfg("duck", {}) as Dictionary).get("stinger_db", -12.0)))


# ------------------------------------------------------------------------------------------- surroundings
## realm: a realm key or "" for none. menu=true plays the bed quieter and skips sparse details.
func set_surroundings(p_realm: String, menu: bool = false) -> void:
	var all: Dictionary = _cfg("ambience", {})
	var cfg: Dictionary = all.get(p_realm, {})
	_bed_db = float(cfg.get("db", 0.0)) + (float(_cfg("menu_ambience_db", -5.0)) if menu else 0.0)
	_amb_details = cfg.get("details", []) if not menu else (cfg.get("details", []) as Array).slice(0, 1)
	_amb_next.clear()
	for d: Dictionary in _amb_details:
		var gap: Array = d.get("gap", [6.0, 12.0])
		_amb_next.append(_rng.randf_range(0.2, 1.0) * float(gap[0]))
	_set_reverb(p_realm if not menu else "menu")
	if p_realm == realm:
		return
	realm = p_realm
	var bed: AudioStream = _looped(AMB_DIR % String(cfg.get("bed", "")))
	_bed_target[0] = 0.0
	_beds.reverse()
	_bed_gain.reverse()
	_bed_target = [0.0, 0.0]
	if bed:
		_beds[0].stream = bed
		_beds[0].volume_db = SILENT_DB
		_beds[0].play()
		_bed_gain[0] = 0.0
		_bed_target[0] = 1.0


func _set_reverb(key: String) -> void:
	if _reverb == null:
		return
	var all: Dictionary = _cfg("realm_reverb", {})
	var r: Dictionary = all.get(key, all.get("menu", {}))
	_reverb.room_size = float(r.get("room", 0.3))
	_reverb.damping = float(r.get("damp", 0.5))
	_reverb.wet = float(r.get("wet", 0.05))
	_reverb.dry = 1.0
	_reverb.predelay_msec = float(r.get("predelay_ms", 20.0))
	_reverb.hipass = float(r.get("hipass", 0.2))


func _amb_variants(name: String) -> Array:
	var key: String = "amb:" + name
	if not _streams.has(key):
		var list: Array = []
		for i: int in MAX_VARIANTS:
			var path: String = AMB_VARIANT % [name, i]
			if not ResourceLoader.exists(path):
				break
			list.append(load(path))
		_streams[key] = list
	return _streams[key]


func _tick_details(dt: float) -> void:
	for i: int in _amb_details.size():
		_amb_next[i] -= dt
		if _amb_next[i] > 0.0:
			continue
		var d: Dictionary = _amb_details[i]
		var gap: Array = d.get("gap", [6.0, 12.0])
		_amb_next[i] = _rng.randf_range(float(gap[0]), float(gap[1]))
		var list: Array = _amb_variants(String(d["name"]))
		if list.is_empty():
			continue
		# In a level or on the map, each detail comes from a random point across (and a little
		# beyond) the screen: birds to the left, a gull to the right, never the same spot twice.
		var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
		var p: Node = _free_voice(_amb_2d if cam and _amb_2d.size() > 0 else _amb_pool, 0.0)
		if p == null:
			continue
		var db: Array = d.get("db", [-12.0, -6.0])
		var pitch: Array = d.get("pitch", [0.95, 1.05])
		var level_db: float = _rng.randf_range(float(db[0]), float(db[1])) + _bed_db
		if p is AudioStreamPlayer2D:
			var half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / cam.zoom
			var spread: float = float((_cfg("positional", {}) as Dictionary).get("ambience_spread", 1.1))
			(p as AudioStreamPlayer2D).global_position = cam.get_screen_center_position() + Vector2(
					_rng.randf_range(-spread, spread) * half.x, _rng.randf_range(-0.8, 0.2) * half.y)
			level_db += float((_cfg("positional", {}) as Dictionary).get("make_up_db", 0.0))
		p.set("stream", list[_rng.randi() % list.size()])
		p.set("volume_db", level_db)
		p.set("pitch_scale", _rng.randf_range(float(pitch[0]), float(pitch[1])))
		p.call("play")


# ------------------------------------------------------------------------------------------- mixer
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	_slow_real_s = _slow_real_s + dt if Engine.time_scale < 0.6 else 0.0
	_settle_fall()
	if get_tree().paused != _was_paused:
		_was_paused = get_tree().paused
		_hold_world_audio(_was_paused)
	_mix_music(dt)
	_mix_ambience(dt)
	_mix_filter(dt)
	_tick_details(dt)


## Pause holds the music, ambience and world sounds where they are; resume carries on from there.
## UI clicks (their own pool) keep working in the pause menu.
func _hold_world_audio(hold: bool) -> void:
	var players: Array[Node] = []
	for d: Deck in _decks:
		players.append(d.player)
	players.append_array(_beds)
	players.append_array(_pool_2d)
	players.append_array(_amb_2d)
	players.append_array(_amb_pool)
	players.append_array(_pool)
	for p: AudioStreamPlayer in [_sting, _stretch]:
		if p:
			players.append(p)
	for p: Node in players:
		if is_instance_valid(p):
			p.set("stream_paused", hold)


func is_holding() -> bool:
	return _was_paused


func _state_cfg() -> Dictionary:
	var states: Dictionary = _cfg("music_states", {})
	return states.get(state, {"base": 0.0, "action": SILENT_DB})


func _mix_music(dt: float) -> void:
	var sc: Dictionary = _state_cfg()
	var e: Dictionary = _cfg("energy", {})
	_energy_hold -= dt
	if _energy_hold <= 0.0:
		_energy = maxf(0.0, _energy - float(e.get("decay_per_s", 0.25)) * dt)
	var floor_db: float = float(sc.get("action", SILENT_DB))
	var target: float = floor_db
	if bool(sc.get("reacts", false)):
		target = lerpf(floor_db, float(e.get("max_db", 0.0)), _energy)
	var rate: float = float(_cfg("stem_attack_db_s", 30.0)) if target > _action_db else float(_cfg("stem_release_db_s", 8.0))
	_action_db = move_toward(_action_db, target, rate * dt)
	# Climax: choir, low brass and taiko join only at the peak of a destruction chain.
	var c_on: float = float(e.get("climax_on", 0.6))
	var c_target: float = SILENT_DB
	if bool(sc.get("reacts", false)) and state == "destruction" and _energy >= c_on:
		c_target = lerpf(float(e.get("climax_floor_db", -12.0)), float(e.get("climax_max_db", -2.0)),
				clampf((_energy - c_on) / maxf(0.01, 1.0 - c_on), 0.0, 1.0))
	var c_rate: float = float(e.get("climax_attack_db_s", 24.0)) if c_target > _climax_db else float(e.get("climax_release_db_s", 6.0))
	if c_target > _climax_db and _climax_db < float(e.get("climax_floor_db", -12.0)):
		c_rate *= 4.0  # from silence to the floor in about half a second, then a musical swell
	_climax_db = move_toward(_climax_db, c_target, c_rate * dt)
	_duck_db = move_toward(_duck_db, 0.0, float((_cfg("duck", {}) as Dictionary).get("release_db_s", 10.0)) * dt)
	var fade_rate: float = 1.0 / maxf(0.05, float(_cfg("music_fade_s", 1.6)))
	var stem_db: Array[float] = [float(sc.get("base", 0.0)), _action_db, _climax_db]
	for d: Deck in _decks:
		d.gain = move_toward(d.gain, d.target, fade_rate * dt)
		if d.gain <= 0.0 and d.target <= 0.0:
			if d.player.playing:
				d.player.stop()
			continue
		d.player.volume_db = maxf(SILENT_DB, linear_to_db(maxf(d.gain, 0.0001)) + _duck_db)
		if d.sync:
			for i: int in d.sync.stream_count:
				d.sync.set_sync_stream_volume(i, maxf(SILENT_DB, stem_db[mini(i, 2)]))


func _mix_ambience(dt: float) -> void:
	var rate: float = 1.0 / maxf(0.05, float(_cfg("ambience_fade_s", 2.0)))
	var action_duck: float = float(_cfg("ambience_action_duck_db", -4.0)) * _energy
	for i: int in 2:
		_bed_gain[i] = move_toward(_bed_gain[i], _bed_target[i], rate * dt)
		if _bed_gain[i] <= 0.0 and _bed_target[i] <= 0.0:
			if _beds[i].playing:
				_beds[i].stop()
			continue
		_beds[i].volume_db = maxf(SILENT_DB, linear_to_db(maxf(_bed_gain[i], 0.0001)) + _bed_db + action_duck)


func _mix_filter(dt: float) -> void:
	var f: Dictionary = _cfg("filter", {})
	var target: float = float(f.get("normal_hz", 20000.0))
	if get_tree().paused:
		target = float(f.get("pause_hz", 700.0))
	elif _slow_real_s > float(_cfg("slowmo_pitch_after_s", 0.15)):
		target = float(f.get("slowmo_hz", 1400.0))
	# Glide in log-frequency so the sweep sounds even.
	var k: float = clampf(float(f.get("glide", 6.0)) * dt, 0.0, 1.0)
	_cutoff = exp(lerpf(log(_cutoff), log(target), k))
	for flt: AudioEffectLowPassFilter in _filters:
		flt.cutoff_hz = _cutoff
