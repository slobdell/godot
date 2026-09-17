class_name GunfireLoops
extends Node3D
## Machine-gun fire as held loops, not one sound per round (feel X3): a scout streaming 11 rounds a second would steal
## every pooled voice, and a dozen scouts would be noise. Each weapon_fired from a stream marks its gunner as firing;
## once per frame the gunners still firing (a round within HOLD_SECONDS) nearest the listener get the few looping voices,
## which follow their muzzles. A gunner who stops lets go of its voice, so the brrrt ends with the trigger.

const VOICES := 4
## A gunner counts as still firing this long after its last round (longer than the gap between rounds).
const HOLD_SECONDS := 0.16
const SOUND := "mg_loop"
const VOLUME_DB := -9.0

## FxWorld copies SfxSystem's --mute onto this; --audio-solo for another layer keeps it silent regardless.
var muted := false:
	set(value):
		muted = value or not AudioSolo.allows("guns")

## gunner key -> {"position": Vector3, "last": float}
var _gunners := {}
var _voices: Array[AudioStreamPlayer3D] = []
## voice index -> gunner key ("" = free)
var _assigned: PackedStringArray = []
var _rng := RandomNumberGenerator.new()
## sound key -> a looping copy of it.
var _loops := {}


func _init() -> void:
	name = "GunfireLoops"
	_rng.seed = 11
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "Gunfire%d" % i
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 45.0
		voice.max_distance = 500.0
		voice.volume_db = VOLUME_DB
		voice.bus = SfxSystem.BED_BUS
		add_child(voice)
		_voices.append(voice)
		_assigned.append("")


## Looping copies of every stream weapon's sound (SfxWeapons), so a voice can play whichever its gunner fires.
func use_streams(streams: Dictionary) -> void:
	for key in [SOUND] + SfxWeapons.named_sounds():
		var source := streams.get(key) as AudioStreamWAV
		if source == null:
			continue
		var loop := source.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = SfxSystem.loop_frames(loop)
		_loops[key] = loop
	for voice in _voices:
		voice.stream = _loops.get(SOUND)


## A round left `key`'s gun at `position`. `sound` is the loop it streams (SfxWeapons: a plasma repeater is not a
## machine gun); "" keeps the default.
func trigger(key: String, position: Vector3, now: float, sound := "") -> void:
	_gunners[key] = {"position": position, "last": now, "sound": sound if sound != "" else SOUND}


## Muzzle positions of every gunner still firing (for the flickering muzzle light).
func firing_positions(now: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for key in _gunners:
		if now - float(_gunners[key]["last"]) <= HOLD_SECONDS:
			result.append(_gunners[key]["position"])
	return result


## Voices currently held by a firing gunner.
func active_count() -> int:
	var count := 0
	for key in _assigned:
		count += 1 if key != "" else 0
	return count


func update(listener: Vector3, now: float) -> void:
	var firing: Array = []
	for key in _gunners.keys():
		var gunner: Dictionary = _gunners[key]
		if now - float(gunner["last"]) > HOLD_SECONDS:
			_gunners.erase(key)
			continue
		firing.append([listener.distance_squared_to(gunner["position"]), key])
	firing.sort()
	var wanted := {}
	for k in mini(VOICES, firing.size()):
		wanted[firing[k][1]] = true
	# Keep voices on gunners that still deserve one (no restart stutter), release the rest, then hand out free voices.
	for i in VOICES:
		if _assigned[i] != "" and not wanted.has(_assigned[i]):
			_assigned[i] = ""
			_voices[i].stop()
	for key in wanted:
		var index := _assigned.find(key)
		if index < 0:
			index = _assigned.find("")
			_assigned[index] = key
			var loop: AudioStream = _loops.get(String(_gunners[key].get("sound", SOUND)))
			if loop != null:
				_voices[index].stream = loop
			if not muted and _voices[index].stream != null and _voices[index].is_inside_tree():
				_voices[index].pitch_scale = 1.0 + _rng.randf_range(-0.06, 0.06)
				_voices[index].play(_rng.randf_range(0.0, 0.9))
		_voices[index].position = _gunners[key]["position"]


func _exit_tree() -> void:
	stop_all()


func stop_all() -> void:
	for i in VOICES:
		_assigned[i] = ""
		_voices[i].stop()
	_gunners.clear()
