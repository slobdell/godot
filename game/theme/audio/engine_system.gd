class_name EngineSystem
extends Node3D
## Engine sounds (art stretch; audio's since round 5, X4): hull visuals register with their engine loop, and every
## frame the VOICES vehicles nearest the camera get a pooled engine voice plus a running-gear voice (tracks clattering
## or tyres rolling). Everything is measured from the visual's own position: nothing reads the simulation. A voice
## stays with its vehicle while it's still among the nearest, so loops don't restart. Lives in FxWorld; silent with
## --mute.
##
## An engine is heard by **speed and load**: speed sets the revs (pitch), load (how hard it is accelerating) makes it
## work (louder, a touch higher), so a tank pulling away from a standstill roars before it is fast. The running gear
## follows speed alone, pitched so the track links clank faster the faster it goes, and is silent at rest.
##
## Cost (make audio-bench): nearest vehicles are picked by insertion into a VOICES-long list, not by sorting every
## vehicle with a lambda each frame, which was most of the audio frame at 60 vehicles.

const VOICES := 4
const HEARING := 90.0  # meters from the camera
const IDLE_DB := -22.0
const REV_DB := -11.0
## Extra level, and pitch, for an engine pulling at full load.
const LOAD_DB := 5.0
const LOAD_PITCH := 0.12
const TOP_SPEED := 14.0  # m/s that counts as full revs
const FULL_LOAD_ACCEL := 5.0  # m/s² that counts as working flat out
## Running gear per engine: the diesel hulls run on tracks, the rest on tyres.
const RUNNING_GEAR := {"engine_diesel": "tread_loop", "engine_v8": "tire_loop", "engine_electric": "tire_loop"}
const GEAR_DB := Vector2(-34.0, -13.0)  # crawling → full speed
const GEAR_PITCH := Vector2(0.55, 1.5)
const SILENT_DB := -80.0

## FxWorld copies SfxSystem's --mute onto this; --audio-solo for another layer keeps it silent regardless.
var muted := false:
	set(value):
		muted = value or not AudioSolo.allows("engines")
var _sources: Dictionary = {}  # Node3D → {sound, last: Vector3, speed: float, load: float}
var _voices: Array[AudioStreamPlayer3D] = []
var _gear: Array[AudioStreamPlayer3D] = []
var _owner_of: Array = []  # voice index → Node3D or null
var _streams: Dictionary = {}


func _init() -> void:
	name = "Engines"
	for i in VOICES:
		_voices.append(_voice("Engine%d" % i, 18.0))
		_gear.append(_voice("Gear%d" % i, 14.0))
		_owner_of.append(null)


func _voice(voice_name: String, unit_size: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = voice_name
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.unit_size = unit_size
	voice.max_distance = HEARING * 1.5
	voice.bus = SfxSystem.WORLD_BUS
	add_child(voice)
	return voice


## Looping copies of the engine and running-gear sounds (from SfxSystem's streams).
func use_streams(streams: Dictionary) -> void:
	for key in streams:
		var id := String(key)
		if id.begins_with("engine_") or id in RUNNING_GEAR.values():
			var loop := (streams[key] as AudioStreamWAV).duplicate() as AudioStreamWAV
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_end = SfxSystem.loop_frames(loop)
			_streams[id] = loop


func add(source: Node3D, sound: String) -> void:
	if not _sources.has(source):
		_sources[source] = {"sound": sound, "last": source.global_position, "speed": 0.0, "load": 0.0}


func remove(source: Node3D) -> void:
	_sources.erase(source)
	for i in VOICES:
		if _owner_of[i] == source:
			_release(i)


func active_count() -> int:
	var count := 0
	for voice in _voices:
		count += 1 if voice.playing else 0
	return count


## How hard a registered vehicle's engine is working right now, 0..1 (tests and tuning).
func load_of(source: Node3D) -> float:
	return float(_sources.get(source, {}).get("load", 0.0))


func update(camera_position: Vector3, delta: float) -> void:
	# The VOICES nearest audible vehicles, kept sorted by insertion (distance², source).
	var near_d: Array[float] = []
	var near: Array[Node3D] = []
	var hearing_sq := HEARING * HEARING
	for key in _sources.keys():
		if not is_instance_valid(key) or not (key as Node3D).is_inside_tree():
			_sources.erase(key)
			continue
		var source := key as Node3D
		var state: Dictionary = _sources[key]
		var position := source.global_position
		if delta > 0.0:
			var speed := float(state["speed"])
			var measured := position.distance_to(state["last"]) / delta
			var next_speed := lerpf(speed, measured, 0.15)
			var accel := (next_speed - speed) / delta
			state["speed"] = next_speed
			state["load"] = lerpf(float(state["load"]), clampf(accel / FULL_LOAD_ACCEL, 0.0, 1.0), 0.1)
		state["last"] = position
		var distance_sq := position.distance_squared_to(camera_position)
		if distance_sq > hearing_sq or (near.size() == VOICES and distance_sq >= near_d[VOICES - 1]):
			continue
		if not source.is_visible_in_tree():  # a tree walk: only for vehicles that would otherwise get a voice
			continue
		var at := near.size()
		while at > 0 and near_d[at - 1] > distance_sq:
			at -= 1
		near_d.insert(at, distance_sq)
		near.insert(at, source)
		if near.size() > VOICES:
			near_d.resize(VOICES)
			near.resize(VOICES)
	for i in VOICES:  # free voices whose vehicle dropped out
		if _owner_of[i] != null and not near.has(_owner_of[i]):
			_release(i)
	for source in near:
		var index := _owner_of.find(source)
		if index < 0:
			index = _owner_of.find(null)
			if index < 0:
				continue
			_owner_of[index] = source
			var sound := String(_sources[source]["sound"])
			var stream: AudioStream = _streams.get(sound)
			if stream == null or muted:
				continue
			var offset := randf() * 0.9
			_voices[index].stream = stream
			_voices[index].play(offset)
			var gear: AudioStream = _streams.get(RUNNING_GEAR.get(sound, ""))
			if gear != null:
				_gear[index].stream = gear
				_gear[index].volume_db = SILENT_DB
				_gear[index].play(offset)
		var state: Dictionary = _sources[source]
		var revs := clampf(float(state["speed"]) / TOP_SPEED, 0.0, 1.0)
		var working := float(state["load"])
		var voice := _voices[index]
		voice.global_position = source.global_position
		voice.pitch_scale = lerpf(0.8, 1.7, revs) + LOAD_PITCH * working
		voice.volume_db = lerpf(IDLE_DB, REV_DB, revs) + LOAD_DB * working
		var gear_voice := _gear[index]
		if gear_voice.playing:
			gear_voice.global_position = voice.global_position
			gear_voice.pitch_scale = lerpf(GEAR_PITCH.x, GEAR_PITCH.y, revs)
			# At a crawl the gear fades out entirely rather than clanking slowly forever at a standstill.
			gear_voice.volume_db = lerpf(GEAR_DB.x, GEAR_DB.y, revs) if revs > 0.03 else SILENT_DB


func _release(index: int) -> void:
	_owner_of[index] = null
	_voices[index].stop()
	_gear[index].stop()
