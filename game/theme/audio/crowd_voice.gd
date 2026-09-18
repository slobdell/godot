class_name CrowdVoice
extends Node
## The crowd's sound (audio's since round 5, X4; the crowd you see is render's CrowdSystem). A murmur loops under
## the whole match and a roar goes up for a kill, as before, but the murmur now follows **the match** as well as the
## last explosion: it sits on a floor set by MatchMood's intensity, so a crowd watching a long firefight stays loud
## between kills instead of dropping to a library hush, and a result gets its own roar. Not positional: the stands
## surround the camera. Silent with --mute and on headless peers (no FxWorld).

## Feel X3 (round 6): +8 dB on round 5. At -30 the murmur measured 20-25 dB under the mix, and the lead called the crowd
## non-existent; but that pass ran in slow motion (references/audio). At real pace, +13 put the crowd soloed a median 4 dB
## under the whole mix (builder0, 2ab241e1 tree, yard, 90 s): the loudest bed in the game. This aims for 8-10 dB under.
const MURMUR_DB := Vector2(-22.0, -11.0)  # calm → on its feet
const ROAR_DB := -6.0
const RESULT_ROAR_DB := -3.0
const CALM := 0.12
## How fast the crowd settles after a kill (excitement per second), and how much of the match's intensity it holds.
const SETTLE := 0.35
const MOOD_HOLD := 0.6
## A roar is not restarted before this much of the last one has played.
const ROAR_GAP_S := 1.2
const BOOTH_GROUP := "announcer_booth"

var excitement := CALM
var murmur := AudioStreamPlayer.new()
var roar := AudioStreamPlayer.new()
## Replaceable for tests: the mood to follow (else the running booth's, found lazily).
var mood: MatchMood
var _rng := RandomNumberGenerator.new()
var _last_state := ""
## `--crowd-meter` (feel X3): once a second, print what the crowd and the whole world bus actually measure in this match.
var _meter := false
var _meter_clock := 0.0
var _meter_sums := Vector3.ZERO


func _init() -> void:
	name = "CrowdVoice"
	_rng.seed = 23
	murmur.name = "Murmur"
	roar.name = "Roar"
	SfxSystem.ensure_world_bus()
	murmur.bus = SfxSystem.CROWD_BUS
	roar.bus = SfxSystem.CROWD_BUS
	add_child(murmur)
	add_child(roar)


func _ready() -> void:
	var fx := FxWorld.get_instance()
	if fx == null:
		return
	_meter = LaunchFlags.from_environment().has("crowd-meter")
	fx.spectacle.connect(react)
	if not fx.sfx.muted and AudioSolo.allows("crowd"):
		use_streams(fx.sfx.streams)


func use_streams(streams: Dictionary) -> void:
	var source := streams.get("crowd_murmur") as AudioStreamWAV
	if source != null:
		var loop := source.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = SfxSystem.loop_frames(loop)
		murmur.stream = loop
		murmur.volume_db = MURMUR_DB.x
		if murmur.is_inside_tree():
			murmur.play()
	roar.stream = streams.get("crowd_cheer")


## A hit or a kill (FxWorld.spectacle): kills roar, anything lifts the murmur.
func react(_position: Vector3, weight: float) -> void:
	if weight >= 0.9:
		_roar(ROAR_DB)
	excitement = clampf(maxf(excitement, CALM + weight * 0.75), 0.0, 1.0)


## The level the murmur is heading for right now: the last big moment, or the match's own intensity, whichever is
## higher.
func target_excitement() -> float:
	var floor_level := CALM
	var reading := _mood()
	if reading != null:
		floor_level = CALM + reading.intensity() * MOOD_HOLD
	return maxf(excitement, floor_level)


func _process(delta: float) -> void:
	var reading := _mood()
	var floor_level := CALM + (reading.intensity() * MOOD_HOLD if reading != null else 0.0)
	excitement = move_toward(excitement, floor_level, SETTLE * delta) if excitement > floor_level else floor_level
	if reading != null and reading.state != _last_state:
		_last_state = reading.state
		if _last_state in ["victory", "defeat"]:
			_roar(RESULT_ROAR_DB)  # the stands react to the result, whoever it's for
	if murmur.playing:
		murmur.volume_db = lerpf(MURMUR_DB.x, MURMUR_DB.y, clampf((excitement - CALM) / (1.0 - CALM), 0.0, 1.0))
	if _meter:
		_measure(delta, reading)


## Mean peak level (dB) of the Crowd bus after its dip and of World after the booth's duck, over each second. The
## crowd's reading adds World's trim so the two are on the same scale (a bus meter reads before the next bus's volume),
## and `sim_s` is the match clock: a loaded machine can stall the game under a wall-clock recording.
func _measure(delta: float, reading: MatchMood) -> void:
	var crowd := AudioServer.get_bus_index(SfxSystem.CROWD_BUS)
	var world := AudioServer.get_bus_index(SfxSystem.WORLD_BUS)
	if crowd < 0 or world < 0:
		return
	_meter_sums += Vector3(maxf(AudioServer.get_bus_peak_volume_left_db(crowd, 0) + AudioServer.get_bus_volume_db(world), -80.0),
			maxf(AudioServer.get_bus_peak_volume_left_db(world, 0), -80.0), 1.0)
	_meter_clock += delta
	if _meter_clock < 1.0:
		return
	print("CROWD_METER " + JSON.stringify({"sim_s": snappedf(float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second, 0.1), "crowd_db": snappedf(_meter_sums.x / _meter_sums.z, 0.1),
			"world_db": snappedf(_meter_sums.y / _meter_sums.z, 0.1), "excitement": snappedf(excitement, 0.01),
			"state": reading.state if reading != null else ""}))
	_meter_clock = 0.0
	_meter_sums = Vector3.ZERO


func _roar(volume_db: float) -> void:
	if roar.stream == null or not roar.is_inside_tree():
		return
	if roar.playing and roar.get_playback_position() < ROAR_GAP_S:
		return
	roar.volume_db = volume_db
	roar.pitch_scale = _rng.randf_range(0.92, 1.08)
	roar.play()


func _mood() -> MatchMood:
	if mood == null and is_inside_tree():
		var booth := get_tree().get_first_node_in_group(BOOTH_GROUP) as AnnouncerBooth
		if booth != null:
			mood = booth.mood
	return mood
