class_name AnnouncerVoice
extends Node
## Plays the booth's cues from recorded clips (tools/announcer/generate.py's manifest): each cue's parts in order,
## slot values from filler clips, one speaker at a time on the "Announcer" bus. A cut cue fades out fast.
##
## Ducking: the announcer bus is the sidechain of a compressor on the world-sound bus (WORLD_BUS), which SfxSystem
## routes every battle sound through. Either side may come up first, so both create the bus. MusicDirector ducks its
## own bus under this one the same way. Clips load from files at runtime, so voice packs can arrive after the game
## starts (web).

const BUS := "Announcer"
const WORLD_BUS := "World"
const CUT_FADE_S := 0.08
## The booth's level under --announcer-volume. X6's first full-match recording had the booth's lines 15-20 dB over the
## battle, clipping with the music underneath: it already ducks everything else, so it doesn't also need to be hot.
const TRIM_DB := -4.0

## Folder holding manifest.json and the clip folders.
var clips_dir := ""
var volume_db := 0.0:
	set(value):
		volume_db = value
		if AudioServer.get_bus_index(BUS) >= 0:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), value + TRIM_DB)
## Replaceable for tests: path -> AudioStream (or null).
var load_stream: Callable = func(path: String) -> AudioStream: return AudioStreamOggVorbis.load_from_file(path)

var manifest := {}
var _player: AudioStreamPlayer
var _queue: Array = []
var _stop_at := -1.0
var _clock := 0.0


static func ensure_bus() -> int:
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
	# Make the world bus if the sound effects haven't started yet: whichever of the two comes up first, the ducking
	# gets wired. (FxWorld is added deferred, so the booth's voice can easily be first.)
	var world := SfxSystem.ensure_world_bus()
	if world >= 0:
		var ducked := false
		for effect_index in AudioServer.get_bus_effect_count(world):
			var effect := AudioServer.get_bus_effect(world, effect_index) as AudioEffectCompressor
			ducked = ducked or (effect != null and effect.sidechain == BUS)
		if not ducked:
			var compressor := AudioEffectCompressor.new()
			compressor.sidechain = BUS
			compressor.threshold = -28.0
			compressor.ratio = 6.0
			compressor.attack_us = 5000.0
			compressor.release_ms = 350.0
			AudioServer.add_bus_effect(world, compressor)
	return index


## Loads the manifest; false (and silence) when there are no clips yet.
func load_clips(folder: String) -> bool:
	clips_dir = folder
	var path := folder.path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	manifest = data if typeof(data) == TYPE_DICTIONARY else {}
	return not manifest.is_empty()


func _ready() -> void:
	ensure_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)
	_player.finished.connect(_play_next)
	volume_db = volume_db


## The clip file for a cue: one whole sentence, recorded for exactly these slot values. Empty when this
## realization was never recorded, and then the cue is subtitles only.
##
## Until round 4 a cue was assembled from carrier segments and filler words at playback time. It sounded pasted,
## because a sentence's intonation spans the whole sentence (_agents/streams/archive/round4/audio.md, *Why stitching failed*).
func files_for(cue: Dictionary) -> PackedStringArray:
	var files := PackedStringArray()
	var line: Dictionary = manifest.get("lines", {}).get(cue["line_id"], {})
	if line.is_empty():
		return files
	var clip := String(line.get("variants", {}).get(String(cue.get("variant_key", "")), ""))
	var clips: Dictionary = manifest.get("clips", {})
	if clip == "" or not clips.has(clip):
		return files
	files.append(clips_dir.path_join(clips[clip]["file"]))
	return files


## Starts a cue now (the director never overlaps speakers, so a new cue replaces whatever is left).
func play(cue: Dictionary) -> bool:
	var files := files_for(cue)
	if files.is_empty() or _player == null:
		return false
	_queue = Array(files)
	_stop_at = -1.0
	_player.volume_db = 0.0
	_play_next()
	return true


## The director cut the current line: fade and stop.
func cut() -> void:
	_queue.clear()
	if _player != null and _player.playing:
		var tween := create_tween()
		tween.tween_property(_player, "volume_db", -40.0, CUT_FADE_S)
		tween.tween_callback(_player.stop)


func is_speaking() -> bool:
	return _player != null and (_player.playing or not _queue.is_empty())


func _play_next() -> void:
	if _queue.is_empty():
		return
	var stream := load_stream.call(String(_queue.pop_front())) as AudioStream
	if stream == null:
		_queue.clear()
		return
	_player.stream = stream
	_player.play()
