class_name RepairHum
extends Node3D
## Round 37 (feedback F3, his approved "repair_loop"): a Resupply Tanker mending a friend sounds like a field workshop -
## an impact wrench, a torch, a pump - for as long as the mending beam shows. FeedbackFx says who is being mended this
## frame; the nearest few patients to the listener hold the looping voices, which follow them, and a patient that is
## whole again (or out of reach, or under fire) lets go, so the workshop stops with the beam.

const VOICES := 2
const SOUND := "repair_loop"

## FxWorld copies SfxSystem's --mute onto this.
var muted := false

var _voices: Array[AudioStreamPlayer3D] = []
## voice index -> patient key ("" = free)
var _assigned: PackedStringArray = []
var _loop: AudioStream
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "RepairHum"
	_rng.seed = 37
	SfxSystem.ensure_world_bus()
	var mix: Array = SfxSystem.MIX[SOUND]
	var filtering: Array = SfxSystem.DISTANCE_FILTER[SOUND]
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Repair%d" % i
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 30.0
		voice.max_distance = 300.0
		voice.volume_db = float(mix[0])
		voice.attenuation_filter_cutoff_hz = float(filtering[0])
		voice.attenuation_filter_db = float(filtering[1])
		voice.bus = SfxSystem.BED_BUS
		add_child(voice)
		_voices.append(voice)
		_assigned.append("")


## The repair loop from SfxSystem's takes (a layered take only: there is no synthesised one), looping.
func use_streams(streams: Dictionary, takes: Dictionary = {}) -> void:
	var source: Variant = (takes.get(SOUND, []) as Array).front() if not (takes.get(SOUND, []) as Array).is_empty() \
			else streams.get(SOUND)
	if source is AudioStreamWAV:
		var loop := (source as AudioStreamWAV).duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = SfxSystem.loop_frames(loop)
		_loop = loop
	for voice in _voices:
		voice.stream = _loop


## `patients`: patient key -> world position, this frame's (FeedbackFx.mending_points).
func update(listener: Vector3, patients: Dictionary) -> void:
	var near: Array = []
	for key: String in patients:
		near.append([listener.distance_squared_to(patients[key]), key])
	near.sort()
	var wanted := {}
	for k in mini(VOICES, near.size()):
		wanted[near[k][1]] = true
	for i in VOICES:
		if _assigned[i] != "" and not wanted.has(_assigned[i]):
			_assigned[i] = ""
			_voices[i].stop()
	for key: String in wanted:
		var index := _assigned.find(key)
		if index < 0:
			index = _assigned.find("")
			_assigned[index] = key
			if not muted and _loop != null and _voices[index].is_inside_tree():
				_voices[index].pitch_scale = 1.0 + _rng.randf_range(-0.03, 0.03)
				_voices[index].play(_rng.randf_range(0.0, 4.0))
		_voices[index].position = patients[key]


## Voices held by a patient being mended (tests).
func active_count() -> int:
	var count := 0
	for key in _assigned:
		count += 1 if key != "" else 0
	return count


func _exit_tree() -> void:
	for i in VOICES:
		_assigned[i] = ""
		_voices[i].stop()
