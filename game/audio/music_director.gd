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
##
## **Stems (round 5, X5).** A manifest track may be a set of stems instead of one file: `"stems": [{"file", "from"}
## or {"file", "states"}]`, all the same length and tempo, played sample-locked in one [AudioStreamSynchronized].
## A stem sounds while the match's intensity is at or above its `from` (or while the mood is in one of its
## `states`), so one track covering lull, skirmish, battle and last stand *builds* as the fight grows instead of
## stepping between beds: the drums come in at first contact, the bass when it turns into a battle. Layers change
## only on a bar line, fading over [constant STEM_FADE_S], and a layer leaves only once the intensity has fallen
## [constant STEM_HYSTERESIS] below where it came in, so a lull between two kills doesn't strip the arrangement.

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
## How long a stem takes to come in or drop out (it starts on a bar line).
const STEM_FADE_S := 1.2
## A stem stays in until the intensity is this far under its `from`.
const STEM_HYSTERESIS := 0.08
const SILENT_DB := -60.0
## The soundtrack's level under --music-volume. Until the stems looped (bc1ce8f) the fight music stopped after 8 s,
## so the whole mix was balanced against silence; the first full match with it playing measured -15.2 LUFS and a
## battle that was mostly music (-11 dB RMS). The battle leads; the music sits under it.
const TRIM_DB := -9.0

signal track_changed(state: String, track_id: String)

var volume_db := 0.0:
	set(value):
		volume_db = value
		var index := AudioServer.get_bus_index(BUS)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, value + TRIM_DB)
## Replaceable for tests: path -> AudioStream (or null when there is no file).
var load_stream: Callable = func(path: String) -> AudioStream: return _load_any(path)

var tracks := {}
var stingers := {}
var dir := ""
var state := ""
var track_id := ""
## True while a crossfade is waiting for the next bar line.
var pending := ""
## Stems of the playing track that are sounding (indices into its "stems"), and each stem's current level in dB.
var layers: Array[int] = []
var stem_db: Array[float] = []

var _players: Array[AudioStreamPlayer] = []
var _stinger_player: AudioStreamPlayer
var _current := 0
var _fade: Tween
var _last_stinger_at := -100.0
var _clock := 0.0
var _mood: MatchMood
var _stems: AudioStreamSynchronized
var _stem_fade: Tween
var _last_bar := -1
var _stems_started_usec := 0


## Adds a music director to the running game if `--music` asks for one, following the booth's mood. Returns it,
## or null. Mirrors AnnouncerBooth.attach, and is called from the same place in game/main.gd.
static func attach(main: Node, booth: AnnouncerBooth) -> MusicDirector:
	var flags: LaunchFlags = main.flags
	# --mute means silence, the soundtrack included (SfxSystem reads the same flag).
	if flags.text("music", "off") == "off" or flags.has("mute") or booth == null or booth.mood == null \
			or not AudioSolo.allows("music"):
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
	SfxSystem.ensure_master_limiter()
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
	_mood = mood
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
	if int(_clock / 5.0) != int((_clock - delta) / 5.0) and _players.size() > 0:
		print("MUSIC_STATE t=%.1f track=%s playing=%s pos=%.3f stems=%s" % [_clock, track_id, _playing(), position_s(),
				str(stem_db)])
	_hold_loop()
	if pending != "" and _ready_for_bar_line():
		_crossfade_now()
	elif pending == "" and _stems != null and _crossed_bar_line():
		update_layers(current_intensity(), state, true)


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


## The best track for a state: the one whose `states` list it in, a stem set first, then the highest intensity;
## "" when none fits.
func track_for(wanted: String) -> String:
	var best := ""
	var best_intensity := -1.0
	var ids: Array = tracks.keys()
	ids.sort()  # deterministic when two tracks tie
	for id in ids:
		var track: Dictionary = tracks[id]
		if not wanted in track.get("states", []):
			continue
		# A stem set outranks a single bed for the same state: it follows the fight instead of stepping.
		var intensity := float(track.get("intensity", 0.0)) + (10.0 if track.has("stems") else 0.0)
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


## Which stems of `track` should sound at this intensity and state. `current` is what is sounding now, for the
## hysteresis. A track without stems has none.
static func layers_for(track: Dictionary, intensity: float, mood_state: String, current: Array = []) -> Array[int]:
	var wanted: Array[int] = []
	var stems: Array = track.get("stems", [])
	for index in stems.size():
		var stem: Dictionary = stems[index]
		if stem.has("states"):
			if mood_state in stem["states"]:
				wanted.append(index)
			continue
		var from := float(stem.get("from", 0.0))
		if intensity >= from or (index in current and intensity >= from - STEM_HYSTERESIS):
			wanted.append(index)
	return wanted


## Brings stems in or out for this reading. True when the arrangement changed. The director calls it on bar lines
## with `one_step`, so it moves at most one layer per bar: at thirty a side, first contact takes the intensity from
## 0.4 to 0.9 in under a second (audio-pass on the Pit and the Boulevard), and applying that at once was a jump
## from pad to full band, not a build. Called directly without it, the whole change applies at once.
func update_layers(intensity: float, mood_state: String, one_step := false) -> bool:
	if _stems == null or not tracks.has(track_id):
		return false
	var wanted := layers_for(tracks[track_id], intensity, mood_state, layers)
	if wanted == layers:
		return false
	if one_step:
		wanted = _one_layer_toward(wanted)
	layers = wanted
	if _stem_fade != null and _stem_fade.is_valid():
		_stem_fade.kill()
	_stem_fade = create_tween().set_parallel(true)
	for index in stem_db.size():
		var target := 0.0 if index in layers else SILENT_DB
		_stem_fade.tween_method(_set_stem_db.bind(index), stem_db[index], target, STEM_FADE_S)
	print("MUSIC_LAYERS track=%s layers=%s intensity=%.2f state=%s t=%.1f pos=%.3f bar=%d" % [track_id, str(layers),
			intensity, mood_state, _clock, position_s(), _last_bar])
	return true


## The match's intensity (the mood signal's), or the playing track's own when nothing is being followed.
func current_intensity() -> float:
	return current_intensity_for(tracks.get(track_id, {}))


## The current layers with one change toward `wanted`: the first missing layer added, else the last extra removed.
func _one_layer_toward(wanted: Array[int]) -> Array[int]:
	var next: Array[int] = layers.duplicate()
	for index in wanted:
		if not index in next:
			next.append(index)
			next.sort()
			return next
	for i in range(next.size() - 1, -1, -1):
		if not next[i] in wanted:
			next.remove_at(i)
			return next
	return next


func _set_stem_db(db: float, index: int) -> void:
	stem_db[index] = db
	if _stems != null and index < _stems.stream_count:
		_stems.set_sync_stream_volume(index, db)


## True once per bar, on the first frame after a bar line of the playing track.
func _crossed_bar_line() -> bool:
	var bar_s := seconds_per_bar(tracks.get(track_id, {}))
	if bar_s <= 0.0 or (_stems == null and not _playing()):
		return true
	var bar := int(position_s() / bar_s)
	# Forward only: the playback position is reported per mix chunk and can sit either side of a bar line on
	# consecutive frames, which counted one bar line twice (two layer changes 0.1 s apart on the Boulevard). A jump
	# back of more than one bar is the loop wrapping, which is a real bar line.
	if not is_new_bar(bar, _last_bar):
		return false
	_last_bar = bar
	return true


## Whether reaching `bar` is a bar line after `last_bar` (forward, or the loop wrapping back by more than one bar).
static func is_new_bar(bar: int, last_bar: int) -> bool:
	return bar != last_bar and bar != last_bar - 1


func current_track() -> String:
	return track_id


func is_playing() -> bool:
	return _playing()


## Where the playing bed is, in seconds (tests and the bar-line maths).
## A stem track is timed by its own clock: AudioStreamSynchronized reports no playback position (always 0.0, seen in
## audio-pass as every MUSIC_LAYERS line at pos=0.000), which silently skipped every bar-line wait and the loop seek.
func position_s() -> float:
	if _stems != null and _stems_started_usec > 0:
		var track: Dictionary = tracks.get(track_id, {})
		var start := float(track.get("loop_start_s", 0.0))
		var span := float(track.get("loop_end_s", 0.0)) - start
		var elapsed := (Time.get_ticks_usec() - _stems_started_usec) / 1000000.0
		return start + (fmod(elapsed, span) if span > 0.0 else elapsed)
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
	var stream := _stream_for(next_id)
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
	_last_bar = -1
	_stems = stream as AudioStreamSynchronized if tracks[next_id].has("stems") else null
	_stems_started_usec = Time.get_ticks_usec() if _stems != null else 0
	if _stems != null:
		# The bar it starts in has already begun: the first change waits for the next bar line, not the first frame.
		_last_bar = int(position_s() / maxf(seconds_per_bar(tracks[next_id]), 0.001))
	if _stems == null:
		layers = []
		stem_db = []
	# Marker for make music-smoke: the soundtrack is the one thing here that a headless run can prove.
	print("MUSIC_TRACK state=%s track=%s t=%.1f" % [state, track_id, _clock])
	track_changed.emit(state, track_id)


## One file, or a track's stems locked together with the layers for the current reading already set, so a track
## that starts mid-battle starts with its drums in rather than fading them up. Null when any file is missing.
func _stream_for(id: String) -> AudioStream:
	var track: Dictionary = tracks[id]
	if not track.has("stems"):
		return load_stream.call(dir.path_join(track["file"])) as AudioStream
	var stems: Array = track["stems"]
	var synced := AudioStreamSynchronized.new()
	synced.stream_count = stems.size()
	var starting := layers_for(track, current_intensity_for(track), state)
	stem_db = []
	for index in stems.size():
		var part := load_stream.call(dir.path_join(stems[index]["file"])) as AudioStream
		if part == null:
			stem_db = []
			return null
		part = _looping(part, float(track.get("loop_start_s", 0.0)))
		synced.set_sync_stream(index, part)
		var db := 0.0 if index in starting else SILENT_DB
		synced.set_sync_stream_volume(index, db)
		stem_db.append(db)
	layers = starting
	return synced


## The mood's intensity when following one, else the track's own manifest intensity (every stem in by default).
## A looping copy of one stem: every stem loops by itself from the track's loop start, so they stay locked together
## without the director seeking (it cannot: see position_s).
static func _looping(part: AudioStream, loop_start_s: float) -> AudioStream:
	var copy := part.duplicate() as AudioStream
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
		(copy as AudioStreamOggVorbis).loop_offset = loop_start_s
	elif copy is AudioStreamWAV:
		var wav := copy as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = int(loop_start_s * wav.mix_rate)
		wav.loop_end = SfxSystem.loop_frames(wav)
	return copy


func current_intensity_for(track: Dictionary) -> float:
	return _mood.intensity() if _mood != null else float(track.get("intensity", 1.0))


## Beds loop between loop_start_s and loop_end_s, not over the whole file (PROMPTS.md): seek back at the seam.
func _hold_loop() -> void:
	if not _playing() or track_id == "" or _stems != null:
		return  # stems loop by themselves (_stream_for), and a synchronized stream can't report where it is
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
