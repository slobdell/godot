class_name MusicDirector
extends Node
## X6: the match's soundtrack. One bed per [MatchMood] state, crossfaded **on the beat**, with stingers over the top
## and everything ducking under the announcer.
##
## It reads `assets/music/manifest.json` (written by `make music-import`; the Suno brief is assets/music/PROMPTS.md)
## and nothing else — adding a track is a manifest row and a file, never code. It is presentation only: it listens to
## [MatchMood], never to the simulation.
##
##     var music := MusicDirector.new()
##     music.load_tracks("res://assets/music")
##     add_child(music)
##     music.follow(mood)          # or music.set_state("battle") by hand
##
## Launch flags (game/main.gd): `--music=on|off`, `--music-volume=DB`, `--music-dir=PATH`.
##
## Why beat-aligned: a crossfade that lands mid-bar sounds like a mistake even when both tracks are good. The
## director waits for the next bar line of the bed that is *playing*, up to [constant MAX_WAIT_S], then fades.

const BUS := "Music"
const ANNOUNCER_BUS := "Announcer"
const MANIFEST := "manifest.json"
const DEFAULT_DIR := "res://assets/music"
## Crossfade length. Long enough to be musical, short enough that a kill still feels sudden.
const FADE_S := 1.6
## A state change never waits longer than this for a bar line (a slow track's bar is ~2 s).
const MAX_WAIT_S := 2.5
## Stingers never pile up: one every this many seconds at most.
const STINGER_COOLDOWN_S := 4.0

signal track_changed(state: String, track_id: String)

var volume_db := 0.0:
	set(value):
		volume_db = value
		var index := AudioServer.get_bus_index(BUS)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, value)
## Replaceable for tests: path -> AudioStream (or null when there is no file).
var load_stream: Callable = func(path: String) -> AudioStream: return _load_any(path)

var tracks := {}
var stingers := {}
var dir := ""
var state := ""
var track_id := ""
## True while a crossfade is waiting for the next bar line.
var pending := ""

var _players: Array[AudioStreamPlayer] = []
var _stinger_player: AudioStreamPlayer
var _current := 0
var _fade: Tween
var _last_stinger_at := -100.0
var _clock := 0.0


## Adds a music director to the running game if `--music` asks for one, following the booth's mood. Returns it,
## or null. Mirrors AnnouncerBooth.attach, and is called from the same place in game/main.gd.
static func attach(main: Node, booth: AnnouncerBooth) -> MusicDirector:
	var flags: LaunchFlags = main.flags
	# --mute means silence, the soundtrack included (SfxSystem reads the same flag).
	if flags.text("music", "off") == "off" or flags.has("mute") or booth == null or booth.mood == null:
		return null
	var music := MusicDirector.new()
	music.name = "Music"
	music.volume_db = float(flags.text("music-volume", "0"))
	if not music.load_tracks(flags.text("music-dir", DEFAULT_DIR)):
		print("MUSIC no tracks in %s yet: silence" % flags.text("music-dir", DEFAULT_DIR))
		return null
	main.game_match.add_child(music)
	music.follow(booth.mood)
	print("MUSIC on: %d beds, %d stingers, following the match mood" % [music.tracks.size(), music.stingers.size()])
	return music


## Adds the Music bus and ducks it under the announcer, the way AnnouncerVoice ducks the world.
static func ensure_bus() -> int:
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
	var announcer := AudioServer.get_bus_index(ANNOUNCER_BUS)
	if announcer >= 0:
		var ducked := false
		for effect_index in AudioServer.get_bus_effect_count(index):
			var effect := AudioServer.get_bus_effect(index, effect_index) as AudioEffectCompressor
			ducked = ducked or (effect != null and effect.sidechain == ANNOUNCER_BUS)
		if not ducked:
			var compressor := AudioEffectCompressor.new()
			compressor.sidechain = ANNOUNCER_BUS
			# Music ducks harder than sound effects do: the booth has to be understood over it.
			compressor.threshold = -30.0
			compressor.ratio = 8.0
			compressor.attack_us = 8000.0
			compressor.release_ms = 500.0
			AudioServer.add_bus_effect(index, compressor)
	return index


## Reads the manifest. False (and silence) when there are no tracks yet, so the game runs without music.
func load_tracks(folder: String = DEFAULT_DIR) -> bool:
	dir = folder
	var path := folder.path_join(MANIFEST)
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("music: %s is not a manifest" % path)
		return false
	tracks = data.get("tracks", {})
	stingers = data.get("stingers", {})
	return not tracks.is_empty()


func _ready() -> void:
	ensure_bus()
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Bed%d" % index
		player.bus = BUS
		player.volume_db = -60.0
		add_child(player)
		_players.append(player)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.name = "Stinger"
	_stinger_player.bus = BUS
	add_child(_stinger_player)
	volume_db = volume_db


## Follows a mood signal: every state change picks a bed, and the result plays its stinger.
func follow(mood: MatchMood) -> void:
	mood.state_changed.connect(_on_mood_changed)
	set_state(mood.current()["state"])


func _on_mood_changed(reading: Dictionary) -> void:
	set_state(String(reading["state"]))
	match String(reading["state"]):
		"victory":
			play_stinger("sting.victory")
		"defeat":
			play_stinger("sting.defeat")
		"last_stand":
			play_stinger("sting.last_unit")


func _process(delta: float) -> void:
	_clock += delta
	_hold_loop()
	if pending != "" and _ready_for_bar_line():
		_crossfade_now()


## Asks for a state. The bed changes at the next bar line; asking for the state that is already playing does nothing.
func set_state(next: String) -> void:
	if next == state and pending == "":
		return
	state = next
	var wanted := track_for(next)
	if wanted == "" or wanted == track_id:
		pending = ""
		return
	pending = wanted
	if not is_inside_tree() or not _playing():
		_crossfade_now()  # nothing is playing: start straight away


## The best track for a state: the one whose `states` list it in, highest intensity first; "" when none fits.
func track_for(wanted: String) -> String:
	var best := ""
	var best_intensity := -1.0
	var ids: Array = tracks.keys()
	ids.sort()  # deterministic when two tracks tie
	for id in ids:
		var track: Dictionary = tracks[id]
		if not wanted in track.get("states", []):
			continue
		var intensity := float(track.get("intensity", 0.0))
		if intensity > best_intensity:
			best = id
			best_intensity = intensity
	return best


## A one-shot over the bed (a kill, a comeback, the result). Rate-limited so a flurry gets one hit, not five.
func play_stinger(id: String) -> bool:
	if not stingers.has(id) or _stinger_player == null:
		return false
	if _clock - _last_stinger_at < STINGER_COOLDOWN_S:
		return false
	var stream := load_stream.call(dir.path_join(stingers[id]["file"])) as AudioStream
	if stream == null:
		return false
	_last_stinger_at = _clock
	_stinger_player.stream = stream
	_stinger_player.play()
	return true


func current_track() -> String:
	return track_id


func is_playing() -> bool:
	return _playing()


## Where the playing bed is, in seconds (tests and the bar-line maths).
func position_s() -> float:
	var player := _players[_current] if not _players.is_empty() else null
	return player.get_playback_position() if player != null and player.playing else 0.0


## True when the playing bed is within a fade of a bar line — or when we have waited long enough.
func _ready_for_bar_line() -> bool:
	if not _playing() or track_id == "":
		return true
	var track: Dictionary = tracks.get(track_id, {})
	var bar_s := seconds_per_bar(track)
	if bar_s <= 0.0:
		return true
	var into_bar := fmod(position_s(), bar_s)
	return bar_s - into_bar <= minf(FADE_S * 0.5, MAX_WAIT_S)


## How long one bar of a track lasts; 0 when the manifest doesn't say.
static func seconds_per_bar(track: Dictionary) -> float:
	var bpm := float(track.get("bpm", 0.0))
	var beats := float(track.get("beats_per_bar", 4.0))
	return 0.0 if bpm <= 0.0 or beats <= 0.0 else beats * 60.0 / bpm


func _playing() -> bool:
	return not _players.is_empty() and _players[_current].playing


func _crossfade_now() -> void:
	var next_id := pending
	if next_id == "":
		return
	if _players.is_empty():
		# _ready hasn't run yet (the node was added to a tree that isn't in the scene yet): keep the request and
		# let _process pick it up, rather than silently dropping the first bed of the match.
		return
	pending = ""
	var stream := load_stream.call(dir.path_join(tracks[next_id]["file"])) as AudioStream
	if stream == null:
		# Not push_warning: a music pack that hasn't downloaded yet is an ordinary state on the web, and the test
		# runner counts any engine message as a failure (orientation trip-up 16).
		print("MUSIC no file for %s yet: silence" % next_id)
		return
	var outgoing := _players[_current]
	_current = 1 - _current
	var incoming := _players[_current]
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play(float(tracks[next_id].get("loop_start_s", 0.0)))
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming, "volume_db", 0.0, FADE_S)
	if outgoing.playing:
		_fade.tween_property(outgoing, "volume_db", -60.0, FADE_S)
		_fade.chain().tween_callback(outgoing.stop)
	track_id = next_id
	# Marker for make music-smoke: the soundtrack is the one thing here that a headless run can prove.
	print("MUSIC_TRACK state=%s track=%s t=%.1f" % [state, track_id, _clock])
	track_changed.emit(state, track_id)


## Beds loop between loop_start_s and loop_end_s, not over the whole file (PROMPTS.md): seek back at the seam.
func _hold_loop() -> void:
	if not _playing() or track_id == "":
		return
	var track: Dictionary = tracks.get(track_id, {})
	var loop_end := float(track.get("loop_end_s", 0.0))
	if loop_end <= 0.0:
		return
	if position_s() >= loop_end:
		_players[_current].seek(float(track.get("loop_start_s", 0.0)))


## A track from res:// (inside the .pck in an export, so it must go through ResourceLoader) or from a file on disk
## (a music pack downloaded after the game starts, which is how the web build will get the big beds).
static func _load_any(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return ResourceLoader.load(path) as AudioStream if ResourceLoader.exists(path) else null
	return AudioStreamOggVorbis.load_from_file(path) if path.ends_with(".ogg") else null
