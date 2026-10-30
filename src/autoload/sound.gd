extends Node
## Adaptive audio. Buses (created at startup): Master <- Music, Ambience, SFX, UI.
##   Sound.play(name, vol, pitch)     one-shot SFX: random variant, cooldowns, UI names go to the UI bus
##   Sound.set_music(song, state)     two synced stems per song (base + action), crossfaded between songs
##   Sound.music_state(state)         menu / map / aim / flight / destruction / result
##   Sound.excite(amount)             destruction energy: pushes the action stem up, then decays
##   Sound.stinger(name)              win / lose / boss_intro / siege_start / reward (ducks the music)
##   Sound.set_surroundings(realm, menu)  ambience bed, scattered details and SFX reverb for a realm
## Pause and slow motion muffle music and ambience with a low-pass. Numbers: data/balance.json -> audio.

const SFX_DIR: String = "res://assets/audio/sfx/%s_%d.wav"
const MUSIC_DIR: String = "res://assets/audio/music/%s.wav"
const AMB_DIR: String = "res://assets/audio/ambience/%s.wav"
const AMB_VARIANT: String = "res://assets/audio/ambience/amb_%s_%d.wav"
const MAX_VARIANTS: int = 6
const SILENT_DB: float = -60.0


## One song: base + action stems started together so they stay in sync.
class Deck:
	extends RefCounted
	var base: AudioStreamPlayer
	var action: AudioStreamPlayer
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
var _energy: float = 0.0
var _energy_hold: float = 0.0
var _duck_db: float = 0.0
var _cutoff: float = 20000.0
var _slow_real_s: float = 0.0
var _last_us: int = 0
var _filters: Array[AudioEffectLowPassFilter] = []
var _reverb: AudioEffectReverb
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _stretch: AudioStreamPlayer
var _stretch_on: bool = false
var _ratchet_power: float = 0.0


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
		d.base = _player("Music")
		d.action = _player("Music")
		_decks.append(d)
		_beds.append(_player("Ambience"))
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
	Events.block_destroyed.connect(func(_b: Node2D, _s: int) -> void: _hit("per_block"))
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
	var audio_cfg: Dictionary = Data.balance["audio"]
	var cooldowns: Dictionary = audio_cfg.get("cooldown_ms", {})
	var interval_ms: int = int(cooldowns.get(sound, Data.b("audio", "min_interval_ms")))
	var now: int = Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < interval_ms:
		return
	var list: Array = _variants(sound)
	if list.is_empty() or volume01 <= 0.01:
		return
	var gains: Dictionary = audio_cfg.get("sound_gain_db", {})
	var requested_db: float = linear_to_db(clampf(volume01, 0.0, 1.0)) + float(gains.get(sound, 0.0))
	var ui: bool = _ui_names.has(sound)
	var player: AudioStreamPlayer = _free_voice(_ui_pool if ui else _pool, requested_db)
	if player == null:
		return
	_last_ms[sound] = now
	var vary: float = Data.bf("audio", "pitch_variation") * (0.5 if ui else 1.0)
	player.stream = list[_rng.randi() % list.size()]
	player.volume_db = requested_db
	player.pitch_scale = maxf(0.2, pitch * _rng.randf_range(1.0 - vary, 1.0 + vary) * (1.0 if ui else _slow_pitch()))
	player.play()


func _free_voice(pool: Array[AudioStreamPlayer], requested_db: float) -> AudioStreamPlayer:
	for candidate: AudioStreamPlayer in pool:
		if not candidate.playing:
			return candidate
	var quiet: AudioStreamPlayer = pool[0]
	for candidate: AudioStreamPlayer in pool:
		if candidate.volume_db < quiet.volume_db:
			quiet = candidate
	# Preserve an existing loud impact instead of replacing it with a quiet incidental sound.
	if requested_db + 3.0 < quiet.volume_db:
		return null
	quiet.stop()
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
	return s


## Old API: maps a track name onto the adaptive player.
func play_music(track: String) -> void:
	set_music(track, state)


## Songs: menu, boss, or a realm key (blossom, desert, harbor, mines, sky).
func set_music(p_song: String, p_state: String = "") -> void:
	if not p_state.is_empty():
		music_state(p_state)
	if p_song == song and _decks[0].song == p_song and _decks[0].target > 0.0:
		return
	var base: AudioStream = _looped(MUSIC_DIR % (p_song + "_base"))
	if base == null:
		return
	song = p_song
	# The current deck fades out, the other one takes the new song.
	var old: Deck = _decks[0]
	var nxt: Deck = _decks[1]
	_decks = [nxt, old]
	old.target = 0.0
	nxt.song = p_song
	nxt.base.stream = base
	nxt.action.stream = _looped(MUSIC_DIR % (p_song + "_action"))
	nxt.gain = 0.0
	nxt.target = 1.0
	nxt.base.volume_db = SILENT_DB
	nxt.action.volume_db = SILENT_DB
	nxt.base.play()
	if nxt.action.stream:
		nxt.action.play()


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
		var p: AudioStreamPlayer = _free_voice(_amb_pool, 0.0)
		if p == null:
			continue
		var db: Array = d.get("db", [-12.0, -6.0])
		var pitch: Array = d.get("pitch", [0.95, 1.05])
		p.stream = list[_rng.randi() % list.size()]
		p.volume_db = _rng.randf_range(float(db[0]), float(db[1])) + _bed_db
		p.pitch_scale = _rng.randf_range(float(pitch[0]), float(pitch[1]))
		p.play()


# ------------------------------------------------------------------------------------------- mixer
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	_slow_real_s = _slow_real_s + dt if Engine.time_scale < 0.6 else 0.0
	_mix_music(dt)
	_mix_ambience(dt)
	_mix_filter(dt)
	_tick_details(dt)


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
	_duck_db = move_toward(_duck_db, 0.0, float((_cfg("duck", {}) as Dictionary).get("release_db_s", 10.0)) * dt)
	var fade_rate: float = 1.0 / maxf(0.05, float(_cfg("music_fade_s", 1.6)))
	for d: Deck in _decks:
		d.gain = move_toward(d.gain, d.target, fade_rate * dt)
		if d.gain <= 0.0 and d.target <= 0.0:
			if d.base.playing:
				d.base.stop()
				d.action.stop()
			continue
		var g: float = linear_to_db(maxf(d.gain, 0.0001))
		d.base.volume_db = maxf(SILENT_DB, g + float(sc.get("base", 0.0)) + _duck_db)
		d.action.volume_db = maxf(SILENT_DB, g + _action_db + _duck_db)


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
