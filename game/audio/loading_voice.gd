class_name LoadingVoice
extends Node
## Feel X5 (round 6): the sound under control's loading screen. FIGHT to playable is ~1.4 s now (control's measurement
## after the spawn fix), so this is a beat, not a bed: the stands' murmur fades up the moment FIGHT is pressed, and when
## the match draws its first frame the crowd roars as the lights come up and the murmur hands over to the match's own
## CrowdVoice. It lives on the tree root, like the screen, so it survives the scene switch.
##
## Control's LoadingScreen calls `LoadingVoice.start(tree)` when it shows and `LoadingVoice.finish()` when the match is
## up. Silent with --mute or another --audio-solo layer.

const MURMUR_DB := -18.0
const ROAR_DB := -8.0
const FADE_IN_S := 0.4
const FADE_OUT_S := 1.6
const SILENT_DB := -60.0
const MURMUR := "res://assets/audio/crowd_murmur.wav"
const ROAR := "res://assets/audio/crowd_cheer.wav"

static var current: LoadingVoice

var murmur := AudioStreamPlayer.new()
var roar := AudioStreamPlayer.new()
## "in", "hold", "out" (then it frees itself).
var phase := "in"
var _time := 0.0


## Start the murmur under a loading screen (replaces one already playing). Returns null when sound is off.
static func start(tree: SceneTree) -> LoadingVoice:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null
	var flags := LaunchFlags.from_environment()
	if flags.has("mute") or not AudioSolo.allows("crowd") or DisplayServer.get_name() == "headless":
		return null
	var voice := LoadingVoice.new()
	tree.root.add_child(voice)
	current = voice
	return voice


## The match is up: a roar as the lights come on, and the murmur fades out under the match's own crowd.
static func finish() -> void:
	if current != null and is_instance_valid(current):
		current.lights_up()


func _init() -> void:
	name = "LoadingVoice"
	process_mode = Node.PROCESS_MODE_ALWAYS
	SfxSystem.ensure_world_bus()
	for player: AudioStreamPlayer in [murmur, roar]:
		player.bus = SfxSystem.CROWD_BUS
		add_child(player)
	var source := load(MURMUR) as AudioStreamWAV
	if source != null:
		var loop := source.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = SfxSystem.loop_frames(loop)
		murmur.stream = loop
	roar.stream = load(ROAR) as AudioStream
	murmur.volume_db = SILENT_DB


func _ready() -> void:
	if murmur.stream != null:
		murmur.play()


func lights_up() -> void:
	if phase == "out":
		return
	phase = "out"
	_time = 0.0
	if roar.stream != null:
		roar.volume_db = ROAR_DB
		roar.play()


func _process(delta: float) -> void:
	_time += delta
	match phase:
		"in":
			murmur.volume_db = lerpf(SILENT_DB, MURMUR_DB, clampf(_time / FADE_IN_S, 0.0, 1.0))
			if _time >= FADE_IN_S:
				phase = "hold"
		"out":
			murmur.volume_db = lerpf(MURMUR_DB, SILENT_DB, clampf(_time / FADE_OUT_S, 0.0, 1.0))
			if _time >= FADE_OUT_S and not roar.playing:
				if current == self:
					current = null
				queue_free()
