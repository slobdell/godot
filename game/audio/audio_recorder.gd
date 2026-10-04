class_name AudioRecorder
extends Node
## X6 (round 5): records what the player hears (the Master bus: guns, engines, crowd, booth and music together) to a
## WAV, so a whole match's mix can be measured and listened to away from the game. `make audio-pass`.
##
## Launch flags (game/main.gd): `--audio-record=<abs path.wav>` and `--audio-record-seconds=N` (default 120), after
## which it saves and quits. Presentation only: it reads the mix, never the match.
##
## Round 17 (G1): `--audio-taps` also records the buses either side of what can take level away in a fight - the
## World bus before its limiter and after its last effect (the limiter, then the booth's duck), Bed and Gunfire
## before and after the impacts' duck - next to the main recording as <name>.<tap>.wav. tools/audio/pass_taps.py
## turns each pair into the gain the stage took, moment by moment. The buses are made by whoever comes up first
## (SfxSystem, the booth), so the taps go in TAP_AFTER_S into the run, and the World bus's chain is printed then.

const DEFAULT_SECONDS := 120.0
const TAP_AFTER_S := 3.0
## tools/audio/pass_taps.py adds this back.
const TAP_HEADROOM_DB := 12.0
## tap -> [bus, where: "first" (before every effect) or "last" (after every effect, before the bus's volume)].
const TAPS := {"world_in": ["World", "first"], "world_out": ["World", "last"], "bed_in": ["Bed", "first"],
		"bed_out": ["Bed", "last"], "guns_in": ["Gunfire", "first"], "guns_out": ["Gunfire", "last"],
		"booth": ["Announcer", "last"], "music": ["Music", "last"], "crowd": ["Crowd", "last"],
		"master_in": ["Master", "first"]}

var path := ""
var seconds := DEFAULT_SECONDS
var _effect: AudioEffectRecord
var _started_ms := 0
var _saved := false
var _tapping := false
var _taps_live := false
## tap -> its AudioEffectRecord, once placed.
var _taps := {}


## Round 17 (guns): `--no-bus-layout` drops res://default_bus_layout.tres before anything builds a bus, so the game
## builds its buses at runtime as it did before round 17: the control arm of `make layout-ab`, which proves the layout
## changes nothing native. Called from main.gd BEFORE the mode starts: FxWorld (made while the mode starts) builds the
## world buses first in the windowed game, and a reset after it would rebuild them in another order (round 17: the first
## control arm did exactly that and was not the old game).
static func prepare_buses(flags: LaunchFlags) -> void:
	# Round 17: the control arm drops the layout at whichever comes first - SfxSystem's first bus-building call
	# (windowed: FxWorld is made by children whose _ready runs before main's) or here, before the booth attaches
	# (headless: no FxWorld, the booth builds the first bus). One guard, so it happens once, before any bus exists.
	SfxSystem._drop_layout_if_asked()
	print("AUDIO_BUSES layout=%s buses=%d" % ["none" if flags.has("no-bus-layout") else "declared", AudioServer.bus_count])


static func attach(main: Node) -> AudioRecorder:
	var flags: LaunchFlags = main.flags
	if not flags.has("audio-record"):
		return null
	var recorder := AudioRecorder.new()
	recorder.name = "AudioRecorder"
	recorder.path = flags.text("audio-record")
	recorder.seconds = float(flags.text("audio-record-seconds", str(DEFAULT_SECONDS)))
	recorder._tapping = flags.has("audio-taps")
	recorder.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(recorder)
	return recorder


func _ready() -> void:
	# Master's own tap goes on NOW, before the main recorder: adding an effect to a bus later re-instantiates every
	# effect on it, and the main recording came back empty when the Master tap was added at TAP_AFTER_S (round 17).
	if _tapping:
		_place_tap("master_in")
	_effect = AudioEffectRecord.new()
	_effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _effect)
	_effect.set_recording_active(true)
	_started_ms = Time.get_ticks_msec()
	print("AUDIO_RECORD started: %.0f s to %s (driver %s) ticks_ms=%d" % [seconds, path, AudioServer.get_driver_name(), _started_ms])


## Wall-clock seconds, because that is what the recording holds (a slow frame still records its whole duration).
func _process(_delta: float) -> void:
	var elapsed := (Time.get_ticks_msec() - _started_ms) / 1000.0
	if _tapping and not _taps_live and elapsed >= TAP_AFTER_S:
		_taps_live = true  # not `_taps.is_empty()`: Master's tap is placed in _ready (round 17)
		_place_taps()
	if not _saved and elapsed >= seconds:
		save_and_quit()


## One tap: a recorder between an Amplify pair (down TAP_HEADROOM_DB, then back up) at the start or end of its bus.
func _place_tap(tap: String) -> void:
	var bus := AudioServer.get_bus_index(String(TAPS[tap][0]))
	if bus < 0:
		print("AUDIO_TAP missing bus=%s" % TAPS[tap][0])
		return
	var effect := AudioEffectRecord.new()
	effect.format = AudioStreamWAV.FORMAT_16_BITS
	var down := AudioEffectAmplify.new()
	down.volume_db = -TAP_HEADROOM_DB
	var up := AudioEffectAmplify.new()
	up.volume_db = TAP_HEADROOM_DB
	if String(TAPS[tap][1]) == "first":
		for stage: AudioEffect in [up, effect, down]:
			AudioServer.add_bus_effect(bus, stage, 0)
	else:
		for stage: AudioEffect in [down, effect, up]:
			AudioServer.add_bus_effect(bus, stage, -1)
	_taps[tap] = effect


func _place_taps() -> void:
	for tap in TAPS:
		if not _taps.has(tap):
			_place_tap(tap)
	# Only now: adding an effect to a bus re-instantiates the ones already on it, and a recorder started before its
	# bus's last addition records into an instance the bus has dropped (round 17: the "before" taps came back empty).
	for tap in _taps:
		(_taps[tap] as AudioEffectRecord).set_recording_active(true)
	var chain := PackedStringArray()
	var world := AudioServer.get_bus_index("World")
	for i in AudioServer.get_bus_effect_count(world):
		var effect := AudioServer.get_bus_effect(world, i)
		var detail := ""
		if effect is AudioEffectAmplify:
			detail = "(%+.0f)" % (effect as AudioEffectAmplify).volume_db
		elif effect is AudioEffectCompressor:
			var c := effect as AudioEffectCompressor
			detail = "(%s %.0f dB %.1f:1)" % [c.sidechain, c.threshold, c.ratio]
		chain.append(effect.get_class() + detail)
	var order := PackedStringArray()
	for i in AudioServer.bus_count:
		order.append("%s>%s" % [AudioServer.get_bus_name(i), AudioServer.get_bus_send(i)])
	print("AUDIO_TAPS placed=%d at_s=%.1f world_chain=%s buses=%s" % [_taps.size(), (Time.get_ticks_msec() - _started_ms) / 1000.0,
			",".join(chain), " ".join(order)])


## Whatever was recorded is saved if the game ends first (a match that finishes, a timeout's SIGTERM is not caught,
## but a normal quit is).
func _exit_tree() -> void:
	if not _saved:
		_save()


func save_and_quit() -> void:
	get_tree().quit(0 if _save() == OK else 1)


func _save() -> int:
	_saved = true
	_effect.set_recording_active(false)
	var recording := _effect.get_recording()
	var error := recording.save_to_wav(path) if recording != null else ERR_UNAVAILABLE
	print("AUDIO_RECORDED path=%s seconds=%.1f error=%d" % [path, recording.get_length() if recording != null else 0.0, error])
	for tap in _taps:
		var effect: AudioEffectRecord = _taps[tap]
		effect.set_recording_active(false)
		var take := effect.get_recording()
		var tap_path := path.get_basename() + ".%s.wav" % tap
		var tap_error := take.save_to_wav(tap_path) if take != null else ERR_UNAVAILABLE
		print("AUDIO_TAP_RECORDED tap=%s path=%s seconds=%.1f error=%d" % [tap, tap_path,
				take.get_length() if take != null else 0.0, tap_error])
	return error
