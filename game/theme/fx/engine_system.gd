class_name EngineSystem
extends Node3D
## Engine sounds per unit type (art stretch): hull visuals register with their engine loop, and every frame the
## VOICES vehicles nearest the camera get a pooled AudioStreamPlayer3D whose pitch and volume follow how fast the
## visual moved (measured from its own position: nothing reads the simulation). A voice stays with its vehicle while
## it's still among the nearest, so loops don't restart. Lives in FxWorld; silent with --mute.

const VOICES := 4
const HEARING := 90.0  # meters from the camera
const IDLE_DB := -22.0
const REV_DB := -11.0
const TOP_SPEED := 14.0  # m/s that counts as full revs

var muted := false
var _sources: Dictionary = {}  # Node3D → {sound, last: Vector3, speed: float, voice: int}
var _voices: Array[AudioStreamPlayer3D] = []
var _owner_of: Array = []  # voice index → Node3D or null
var _streams: Dictionary = {}


func _init() -> void:
	name = "Engines"
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Engine%d" % i
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 18.0
		voice.max_distance = HEARING * 1.5
		add_child(voice)
		_voices.append(voice)
		_owner_of.append(null)


## A looping copy of an engine sound (from SfxSystem's streams).
func use_streams(streams: Dictionary) -> void:
	for key in streams:
		if String(key).begins_with("engine_"):
			var loop := (streams[key] as AudioStreamWAV).duplicate() as AudioStreamWAV
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_end = loop.data.size() / 2
			_streams[key] = loop


func add(source: Node3D, sound: String) -> void:
	if not _sources.has(source):
		_sources[source] = {"sound": sound, "last": source.global_position, "speed": 0.0}


func remove(source: Node3D) -> void:
	_sources.erase(source)
	for i in VOICES:
		if _owner_of[i] == source:
			_owner_of[i] = null
			_voices[i].stop()


func active_count() -> int:
	return _voices.filter(func(v: AudioStreamPlayer3D) -> bool: return v.playing).size()


func update(camera_position: Vector3, delta: float) -> void:
	var candidates := []
	for key in _sources.keys():
		if not is_instance_valid(key) or not (key as Node3D).is_inside_tree():
			_sources.erase(key)
			continue
		var source := key as Node3D
		var state: Dictionary = _sources[key]
		var position := source.global_position
		if delta > 0.0:
			state["speed"] = lerpf(float(state["speed"]), position.distance_to(state["last"]) / delta, 0.15)
		state["last"] = position
		var distance := position.distance_to(camera_position)
		if distance <= HEARING and source.is_visible_in_tree():
			candidates.append([distance, source])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var chosen := candidates.slice(0, VOICES).map(func(c: Array) -> Node3D: return c[1])
	for i in VOICES:  # free voices whose vehicle dropped out
		if _owner_of[i] != null and not chosen.has(_owner_of[i]):
			_owner_of[i] = null
			_voices[i].stop()
	for source in chosen:
		var index := _owner_of.find(source)
		if index < 0:
			index = _owner_of.find(null)
			if index < 0:
				continue
			_owner_of[index] = source
			var stream: AudioStream = _streams.get(_sources[source]["sound"])
			if stream == null or muted:
				continue
			_voices[index].stream = stream
			_voices[index].play(randf() * 0.9)
		var revs := clampf(float(_sources[source]["speed"]) / TOP_SPEED, 0.0, 1.0)
		var voice := _voices[index]
		voice.global_position = source.global_position
		voice.pitch_scale = lerpf(0.8, 1.7, revs)
		voice.volume_db = lerpf(IDLE_DB, REV_DB, revs)
