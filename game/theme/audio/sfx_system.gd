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
}
const WORLD_VOICES := 20
const UI_VOICES := 4
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
var streams := {}
## Sounds started since load (tests and the bench).
var played := 0

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
		if stream != null:
			streams[key] = stream
	var flame := streams.get("flame_loop") as AudioStreamWAV
	if flame != null:
		flame.loop_mode = AudioStreamWAV.LOOP_FORWARD
		flame.loop_end = flame.data.size() / 2
	for i in WORLD_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Voice%d" % i
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 55.0
		voice.max_distance = 600.0
		voice.max_polyphony = 1
		add_child(voice)
		_world.append(voice)
	for i in UI_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "UiVoice%d" % i
		add_child(voice)
		_ui.append(voice)


## A world sound at `position`.
func play_at(sound: String, position: Vector3, volume_offset_db := 0.0) -> void:
	# Not in the tree yet (FxWorld is added deferred; the match announcer speaks at spawn): drop it.
	if muted or not streams.has(sound) or not is_inside_tree():
		return
	var voice := _take_world_voice()
	voice.stream = streams[sound]
	voice.position = position
	var mix: Array = MIX.get(sound, [0.0, 0.0])
	voice.volume_db = float(mix[0]) + volume_offset_db
	voice.pitch_scale = 1.0 + _rng.randf_range(-float(mix[1]), float(mix[1]))
	voice.play()
	played += 1


## A UI sound (not positional).
func play_ui(sound: String) -> void:
	if muted or not streams.has(sound) or not is_inside_tree():
		return
	var voice := _ui[_next_ui]
	_next_ui = (_next_ui + 1) % _ui.size()
	voice.stream = streams[sound]
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
