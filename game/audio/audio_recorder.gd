class_name AudioRecorder
extends Node
## X6 (round 5): records what the player hears (the Master bus: guns, engines, crowd, booth and music together) to a
## WAV, so a whole match's mix can be measured and listened to away from the game. `make audio-pass`.
##
## Launch flags (game/main.gd): `--audio-record=<abs path.wav>` and `--audio-record-seconds=N` (default 120), after
## which it saves and quits. Presentation only: it reads the mix, never the match.

const DEFAULT_SECONDS := 120.0

var path := ""
var seconds := DEFAULT_SECONDS
var _effect: AudioEffectRecord
var _started_ms := 0
var _saved := false


static func attach(main: Node) -> AudioRecorder:
	var flags: LaunchFlags = main.flags
	if not flags.has("audio-record"):
		return null
	var recorder := AudioRecorder.new()
	recorder.name = "AudioRecorder"
	recorder.path = flags.text("audio-record")
	recorder.seconds = float(flags.text("audio-record-seconds", str(DEFAULT_SECONDS)))
	recorder.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(recorder)
	return recorder


func _ready() -> void:
	_effect = AudioEffectRecord.new()
	_effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _effect)
	_effect.set_recording_active(true)
	_started_ms = Time.get_ticks_msec()
	print("AUDIO_RECORD started: %.0f s to %s (driver %s)" % [seconds, path, AudioServer.get_driver_name()])


## Wall-clock seconds, because that is what the recording holds (a slow frame still records its whole duration).
func _process(_delta: float) -> void:
	if not _saved and (Time.get_ticks_msec() - _started_ms) / 1000.0 >= seconds:
		save_and_quit()


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
	return error
