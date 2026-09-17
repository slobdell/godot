class_name SfxSystem
extends Node3D
## Pooled sound effects: a fixed set of AudioStreamPlayer3D voices (world sounds) and a few
## AudioStreamPlayer voices (UI). Playing a sound grabs a free voice or steals the oldest; nothing is
## allocated in combat. Attenuation is tuned for our cameras (46 m follow cam, 200 m tactical view),
## so battle sounds stay audible from the top-down map. Lives in FxWorld (never on headless peers).
## `--mute` silences it.

const SOUNDS := {
	"cannon_shot": "res://assets/audio/cannon_shot.wav",
	"explosion_small": "res://assets/audio/explosion_small.wav",
	"explosion_big": "res://assets/audio/explosion_big.wav",
	"laser_pulse": "res://assets/audio/laser_pulse.wav",
	"shield_hit": "res://assets/audio/shield_hit.wav",
	"shield_down": "res://assets/audio/shield_down.wav",
	"flame_loop": "res://assets/audio/flame_loop.wav",
	"ui_blip": "res://assets/audio/ui_blip.wav",
	"ui_alert": "res://assets/audio/ui_alert.wav",
	"ui_tick": "res://assets/audio/ui_tick.wav",
	"crowd_murmur": "res://assets/audio/crowd_murmur.wav",
	"crowd_cheer": "res://assets/audio/crowd_cheer.wav",
	"engine_diesel": "res://assets/audio/engine_diesel.wav",
	"engine_v8": "res://assets/audio/engine_v8.wav",
	"engine_electric": "res://assets/audio/engine_electric.wav",
	# Feel (round 3): the new weapons (make_sfx.gd).
	"tank_boom": "res://assets/audio/tank_boom.wav",
	"shell_whine": "res://assets/audio/shell_whine.wav",
	"shell_hit_armor": "res://assets/audio/shell_hit_armor.wav",
	"dirt_impact": "res://assets/audio/dirt_impact.wav",
	"autocannon_shot": "res://assets/audio/autocannon_shot.wav",
	"mg_round": "res://assets/audio/mg_round.wav",
	"mortar_launch": "res://assets/audio/mortar_launch.wav",
	"mg_loop": "res://assets/audio/mg_loop.wav",
	"ricochet": "res://assets/audio/ricochet.wav",
	"bullet_hit_metal": "res://assets/audio/bullet_hit_metal.wav",
	"weak_spot_hit": "res://assets/audio/weak_spot_hit.wav",
	"ui_ack_move": "res://assets/audio/ui_ack_move.wav",
	"ui_ack_attack": "res://assets/audio/ui_ack_attack.wav",
	"ui_select": "res://assets/audio/ui_select.wav",
	# Audio (round 5, X4): running gear under the engines (tools/audio/make_world_loops.py).
	"tread_loop": "res://assets/audio/tread_loop.wav",
	"tire_loop": "res://assets/audio/tire_loop.wav",
}
## Extra takes per sound (game/theme/audio/make_sfx.gd VARIANTS): "mg_round" also loads mg_round_2..4. A sound
## plays a take at random, so a burst is never the same crack eleven times (X4).
const TAKES := {
	"mg_round": 4, "bullet_hit_metal": 4, "autocannon_shot": 3, "ricochet": 3, "shell_hit_armor": 3,
	"dirt_impact": 3, "explosion_small": 3, "weak_spot_hit": 2, "tank_boom": 2, "cannon_shot": 2,
}
const WORLD_VOICES := 20
const UI_VOICES := 4
## World sounds go through their own bus so the whole battle can be mixed, limited, and ducked under the announcer
## in one place (AnnouncerVoice sidechains a compressor onto this bus when the booth is on).
const WORLD_BUS := "World"
## Headroom: twenty voices summing in a firefight clip the master and turn to mush. The limiter catches the peaks
## that survive per-sound gain staging; the trim leaves room for it to work.
const WORLD_TRIM_DB := -6.0
const LIMIT_DB := -1.0
## Distance filtering: a blast heard across the arena is dull, not just quiet. Per sound, the cutoff (Hz) at
## max_distance and how much of the sound is filtered; the engine interpolates with distance. Sounds not listed keep
## their full brightness, which is right for the small metallic ones that are only ever heard close.
const DISTANCE_FILTER := {
	"tank_boom": [1400.0, -22.0], "cannon_shot": [1500.0, -20.0], "explosion_big": [1100.0, -24.0],
	"explosion_small": [1600.0, -20.0], "mortar_launch": [2200.0, -14.0], "autocannon_shot": [2400.0, -14.0],
	"mg_round": [3000.0, -12.0], "mg_loop": [3000.0, -12.0], "shell_hit_armor": [2600.0, -12.0],
	"dirt_impact": [1800.0, -16.0], "weak_spot_hit": [3000.0, -10.0], "flame_loop": [2600.0, -12.0],
	"engine_diesel": [1800.0, -16.0], "engine_v8": [1800.0, -16.0], "engine_electric": [2600.0, -12.0],
}
## Per sound: base volume (dB) and random pitch spread, so repeated shots don't sound identical.
const MIX := {
	"cannon_shot": [-4.0, 0.08], "explosion_small": [-3.0, 0.1], "explosion_big": [0.0, 0.06],
	"laser_pulse": [-8.0, 0.12], "shield_hit": [-7.0, 0.1], "shield_down": [-4.0, 0.03],
	"ui_blip": [-14.0, 0.0], "ui_alert": [-10.0, 0.0], "ui_tick": [-20.0, 0.15],
	"tank_boom": [1.0, 0.05], "shell_whine": [-5.0, 0.08], "shell_hit_armor": [-1.0, 0.07], "dirt_impact": [-3.0, 0.1],
	"autocannon_shot": [-6.0, 0.06], "mg_round": [-13.0, 0.12], "mortar_launch": [-5.0, 0.05],
	"ricochet": [-9.0, 0.15], "bullet_hit_metal": [-12.0, 0.12], "weak_spot_hit": [-2.0, 0.03],
	"ui_ack_move": [-13.0, 0.03], "ui_ack_attack": [-12.0, 0.03], "ui_select": [-18.0, 0.05],
}

var muted := false
## key -> the first take, as an AudioStreamWAV. Feel's engine and crowd systems read this directly, so it stays
## exactly what it always was.
var streams := {}
## key -> every take of that sound, first one included. play_at picks from here.
var takes := {}
## Sounds started since load (tests and the bench).
var played := 0
## key -> how many synthesised takes loaded (make_sfx.gd), whether or not layered ones replaced them.
var synth_takes := {}
## Sounds playing ElevenLabs-layered takes (SfxLayers, round 5 X1) rather than the synthesised ones.
var layered := {}

var _world: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _next_world := 0
var _next_ui := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Sfx"
	_rng.seed = 7
	muted = LaunchFlags.from_environment().has("mute")
	for key in SOUNDS:
		var stream := load(SOUNDS[key]) as AudioStream
		if stream == null:
			continue
		streams[key] = stream
		var pool: Array[AudioStream] = [stream]
		for take in range(2, int(TAKES.get(key, 1)) + 1):
			var extra := load(String(SOUNDS[key]).replace(".wav", "_%d.wav" % take)) as AudioStream
			if extra != null:
				pool.append(extra)
		takes[key] = pool
		synth_takes[key] = pool.size()
	if not LaunchFlags.from_environment().has("sfx-synth"):
		_use_layered_takes()
	var flame := streams.get("flame_loop") as AudioStreamWAV
	if flame != null:
		flame.loop_mode = AudioStreamWAV.LOOP_FORWARD
		flame.loop_end = loop_frames(flame)
	ensure_world_bus()
	for i in WORLD_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice%d" % i
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 55.0
		voice.max_distance = 600.0
		voice.max_polyphony = 1
		voice.bus = WORLD_BUS
		add_child(voice)
		_world.append(voice)
	for i in UI_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "UiVoice%d" % i
		add_child(voice)
		_ui.append(voice)


## Round 5 (X1): sounds with ElevenLabs source material layered under their transients (tools/audio/sfx_layer.py)
## play those takes instead. A loop's layered take is a WAV, so it also replaces `streams[key]`, which the engine,
## crowd, flame and gunfire code duplicate and set loop points on; a one-shot's is Ogg and only changes the pool.
## `--sfx-synth` keeps the synthesised set, for A/B listening.
func _use_layered_takes() -> void:
	for key in SfxLayers.TAKES:
		if not streams.has(key):
			continue
		var pool: Array[AudioStream] = []
		for path in SfxLayers.TAKES[key]:
			var stream := load(String(path)) as AudioStream
			if stream != null:
				pool.append(stream)
		if pool.is_empty():
			continue
		takes[key] = pool
		layered[key] = pool.size()
		if pool[0] is AudioStreamWAV:
			streams[key] = pool[0]


## A WAV's length in frames, whatever its import compression. `data.size() / 2` is only right for 16-bit PCM: on a
## QOA import it is a fifth of the sound, which is how every loop came to repeat its first 0.2 s (round 5).
static func loop_frames(stream: AudioStreamWAV) -> int:
	return int(round(stream.get_length() * stream.mix_rate))


## Adds the World bus (and its limiter) if it isn't there. Static so anything that wants to route to it can.
static func ensure_world_bus() -> int:
	var index := AudioServer.get_bus_index(WORLD_BUS)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, WORLD_BUS)
	AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_volume_db(index, WORLD_TRIM_DB)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = LIMIT_DB
	limiter.threshold_db = -4.0
	limiter.soft_clip_db = 2.0
	AudioServer.add_bus_effect(index, limiter)
	return index


## A world sound at `position`, in one of its takes.
func play_at(sound: String, position: Vector3, volume_offset_db := 0.0) -> void:
	# Not in the tree yet (FxWorld is added deferred; the match announcer speaks at spawn): drop it.
	if muted or not streams.has(sound) or not is_inside_tree():
		return
	var voice := _take_world_voice()
	voice.stream = _a_take(sound)
	voice.position = position
	var mix: Array = MIX.get(sound, [0.0, 0.0])
	voice.volume_db = float(mix[0]) + volume_offset_db
	voice.pitch_scale = 1.0 + _rng.randf_range(-float(mix[1]), float(mix[1]))
	var filtering: Array = DISTANCE_FILTER.get(sound, [])
	voice.attenuation_filter_cutoff_hz = float(filtering[0]) if not filtering.is_empty() else 20500.0
	voice.attenuation_filter_db = float(filtering[1]) if not filtering.is_empty() else 0.0
	voice.play()
	played += 1


## One take of a sound, chosen from its pool. Presentation randomness: its own generator, never the simulation's.
func _a_take(sound: String) -> AudioStream:
	var pool: Array = takes.get(sound, [])
	if pool.size() < 2:
		return streams[sound]
	return pool[_rng.randi_range(0, pool.size() - 1)]


## A UI sound (not positional).
func play_ui(sound: String) -> void:
	if muted or not streams.has(sound) or not is_inside_tree():
		return
	var voice := _ui[_next_ui]
	_next_ui = (_next_ui + 1) % _ui.size()
	voice.stream = _a_take(sound)
	var mix: Array = MIX.get(sound, [0.0, 0.0])
	voice.volume_db = float(mix[0])
	voice.pitch_scale = 1.0 + _rng.randf_range(-float(mix[1]), float(mix[1]))
	voice.play()
	played += 1


## Silence every voice (before quitting: a playback still running at exit leaks its stream, e.g. the tank boom's tail).
func stop_all() -> void:
	for voice in _world:
		voice.stop()
	for voice in _ui:
		voice.stop()


func _exit_tree() -> void:
	stop_all()


func voice_count() -> int:
	return _world.size() + _ui.size()


## A free voice, or the one started longest ago.
func _take_world_voice() -> AudioStreamPlayer3D:
	for i in _world.size():
		var index := (_next_world + i) % _world.size()
		if not _world[index].playing:
			_next_world = (index + 1) % _world.size()
			return _world[index]
	var stolen := _world[_next_world]
	_next_world = (_next_world + 1) % _world.size()
	return stolen
