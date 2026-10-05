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
## Launch flags (game/main.gd): `--music=on|off`, `--music-volume=DB`, `--music-dir=PATH`, `--music-seed=N` (which
## tracks this match draws; default a new draw each match), `--music-history=PATH|off` (the cross-match memory; off
## by default in a headless run, which nobody hears).
##
## **Round 12: the opening, and a soundtrack that rotates.** The mood starts every match at `lull`, so the pre-match
## bed was never asked for and every match opened on the one lull bed. The director's own states are the mood's plus
## `pre_match` (the quiet before anybody has fired: [method music_state_for]). Every state has several tracks; each
## set of equally fitting tracks is drawn once per match from the match's seed and the [MusicHistory] (the least
## recently heard first), so the opening, the lull and the result each rotate on their own rather than one index
## picking "track 2 of everything".
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
## The states the director plays: the mood's, the opening before them, and the garage outside a match.
## **Round 13: the garage.** GarageMode holds the director on `garage` ([method hold]) while the army builder is up, so
## the match mood underneath it (the booth keeps one from launch) cannot pull the bed; FIGHT [method release]s it back
## to the mood, which before anybody has fired is `pre_match`: the garage's blues crossfade into the match's opening on
## a bar line, in the same process (FIGHT does not reload the scene, so this is one director with one set of draws).
const STATES := ["pre_match", "lull", "skirmish", "battle", "last_stand", "victory", "defeat", "garage"]
## The soundtrack's level under --music-volume. Until the stems looped (bc1ce8f) the fight music stopped after 8 s,
## so the whole mix was balanced against silence; the first full match with it playing measured -15.2 LUFS and a
## battle that was mostly music (-11 dB RMS). The battle leads; the music sits under it.
const TRIM_DB := -9.0
## Round 17 (guns): the new mix brought the guns ~10 dB up against the music (mix-ab on his match: the music 7-9 dB
## further under the battle than before, its own level unchanged). In a match the music is lifted this much - about half
## the gap back, the worker's pick on the audition page until the lead taps (the master limiter's price: none
## measurable, Master's input peaks −2.3…−3.4 dBFS in all three arms). The garage and the title keep their level.
const IN_MATCH_LIFT_DB := 4.0
## Off under the title: its backdrop fight is a match state, but the title is where the lead first hears the music and
## he called the intro "really cool"; the lift begins when a match adopts the carried director.
var lift_allowed := true
## Round 16 (P4, the lead: *"the intro music is really cool but then it just stops when we start the initial game and
## it goes to a loading screen"*). A menu that launches the match reloads the scene (GameLauncher.start), which used to
## free the director with it: the loader played in silence and the match started its opening from nothing. Now the
## menu [method carry]s the director onto the root first -- an AudioStreamPlayer keeps playing across a reparent
## (measured in 4.7: the position kept advancing) -- and the next match's [method attach] adopts it instead of making a
## second one. It keeps its draws, so the opening the menu was playing IS the match's opening and simply carries on;
## a different state crossfades on its bar line as always. Waiting on the root it is named this.
const CARRIED := "CarriedMusic"
## While carried, a `MUSIC_CARRY` line this often (the launch smoke reads them: playing through the loader).
const CARRY_LOG_S := 0.5

signal track_changed(state: String, track_id: String)

var volume_db := 0.0:
	set(value):
		volume_db = value
		_apply_bus_volume()
## Replaceable for tests: path -> AudioStream (or null when there is no file).
var load_stream: Callable
## Round 16 (P8): streams this director has loaded, held so a bed that comes back is not loaded again; and the files
## asked of the loader thread ahead of time ([method prefetch_draws]).
var _held := {}
var _requested := {}
## `--music-prefetch=off`: the old synchronous loads, for the before/after in one build.
var prefetch := true

## The match's own dice for which of several equally fitting tracks it plays (attach() draws one per match, or
## --music-seed; 0 in tests). Never the simulation's generator.
var match_seed := 0
## The cross-match memory of what was heard (null: none, every draw is the dice alone).
var history: MusicHistory
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
## This match's pick for each set of equally fitting tracks, keyed by the set: skirmish and battle share one fight set,
## so they share one pick.
var _picks := {}
## A state the director keeps playing whatever the mood says ("" = follow the mood): the garage.
var held := ""
var _carry_log_at := 0.0


## Adds a music director to the running game if `--music` asks for one, following the booth's mood. Returns it,
## or null. Mirrors AnnouncerBooth.attach, and is called from the same place in game/main.gd.
static func attach(main: Node, booth: AnnouncerBooth) -> MusicDirector:
	var flags: LaunchFlags = main.flags
	# --mute means silence, the soundtrack included (SfxSystem reads the same flag).
	if AudioDefaults.value(flags, "music") == "off" or flags.has("mute") or booth == null or booth.mood == null \
			or not AudioSolo.allows("music"):
		MusicDirector.drop_carried(main.get_tree())
		return null
	# Round 16 (P4): the menu that launched this match carried its director through the loader. Adopt it.
	var garage_hold := (main.get("mode") as GarageMode).music_state() if main.get("mode") is GarageMode else ""
	if MusicDirector.carried(main.get_tree()) != null:
		return MusicDirector.adopt_carried(main, booth.mood, garage_hold)
	var music := MusicDirector.new()
	music.name = "Music"
	# Presentation randomness from its own generator, never the simulation's.
	var seed_text := flags.text("music-seed")
	if seed_text.is_valid_int():
		music.match_seed = int(seed_text)
	else:
		var dice := RandomNumberGenerator.new()
		dice.randomize()
		music.match_seed = dice.randi() & 0x7fffffff
	var history_path := flags.text("music-history",
			"off" if DisplayServer.get_name() == "headless" else MusicHistory.PATH)
	if history_path != "off":
		music.history = MusicHistory.load_from(history_path)
	music.lift_allowed = not (main.get("mode") is TitleMode)
	music.volume_db = float(flags.text("music-volume", "0"))
	music.prefetch = flags.text("music-prefetch", "on") != "off"
	if not music.load_tracks(flags.text("music-dir", DEFAULT_DIR)):
		print("MUSIC no tracks in %s yet: silence" % flags.text("music-dir", DEFAULT_DIR))
		return null
	# Round 16 (P4): music is presentation, and the skirmish opens in the planning pause (the tree paused). Under the
	# paused Match its players were stream-paused, so the opening was silent until Space -- the launch smoke saw a carried
	# bed report playing=false the moment it was adopted. It plays on through any pause.
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	main.game_match.add_child(music)
	music.held = garage_hold
	music.follow(booth.mood)
	print("MUSIC on: %d beds, %d stingers, following the match mood (seed %d, memory %s)%s" % [music.tracks.size(),
			music.stingers.size(), music.match_seed, history_path, " held on %s" % music.held if music.held != "" else ""])
	return music


## The running game's director (attach() puts it on the match), or null when the launch has no music.
static func find(main: Node) -> MusicDirector:
	var game_match: Node = main.get("game_match")
	return game_match.get_node_or_null("Music") as MusicDirector if game_match != null else null


## Round 16 (P4): before a menu reloads the scene for a match, move the running director onto the root so the music
## plays through the loader. Returns it, or null when `main` has none. It stops following the old mood (the booth goes
## with the old scene) and keeps playing what it was playing, paused by nothing (the loader may pause the tree).
static func carry(main: Node) -> MusicDirector:
	var music := MusicDirector.find(main) if main != null else null
	if music == null:
		return null
	music.unfollow()
	music.reparent(main.get_tree().root)
	music.name = CARRIED
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	music._carry_log_at = 0.0
	print("MUSIC_CARRY carried track=%s playing=%s state=%s t=%.1f" % [music.track_id, music.is_playing(), music.state,
			music._clock])
	return music


## The director a menu carried and no match has adopted yet, or null.
static func carried(tree: SceneTree) -> MusicDirector:
	return tree.root.get_node_or_null(CARRIED) as MusicDirector if tree != null else null


## The new match takes the carried director: under its `game_match` where [method find] looks, following its mood (or
## held on `hold_state`, the garage). The draws it already made stand, so the same opening simply continues.
static func adopt_carried(main: Node, mood: MatchMood, hold_state := "") -> MusicDirector:
	var music := MusicDirector.carried(main.get_tree())
	var game_match: Node = main.get("game_match")
	if music == null or game_match == null:
		return null
	music.reparent(game_match)
	music.name = "Music"
	music.process_mode = Node.PROCESS_MODE_ALWAYS  # see attach: the planning pause must not silence it
	music.lift_allowed = not (main.get("mode") is TitleMode)
	music._apply_bus_volume()
	music.held = hold_state
	if mood != null:
		music.follow(mood)
	elif hold_state != "":
		music.set_state(hold_state)
	print("MUSIC_CARRY adopted track=%s playing=%s state=%s t=%.1f" % [music.track_id, music.is_playing(), music.state,
			music._clock])
	return music


## A launch with no music (or a quit) lets a carried director go. True when there was one.
static func drop_carried(tree: SceneTree) -> bool:
	var music := MusicDirector.carried(tree)
	if music == null:
		return false
	print("MUSIC_CARRY dropped track=%s" % music.track_id)
	music.queue_free()
	return true


## Stop following the mood (it is going away with its scene).
func unfollow() -> void:
	if _mood != null and _mood.state_changed.is_connected(_on_mood_changed):
		_mood.state_changed.disconnect(_on_mood_changed)
	_mood = null


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


func _init() -> void:
	load_stream = _default_load


## Round 16 (P8): a bed change used to load its files on the main thread -- 5-8 ms for one file, 16-20 ms for a stem set
## (laptop) -- in the frame the crossfade started: one dropped frame per track change at a locked 30. The match's
## draws are fixed when it starts (one track per set of states, ~9 MB of Ogg in all), so every file it can play, and
## every stinger, is asked of the loader thread then; the bed change takes the stream that is already there. When a
## request has not landed yet, taking it waits as the old synchronous load did, never longer, so no bar line moves.
## Off on the web (no threads: the synchronous path) and under a test's own `load_stream`.
func prefetch_draws() -> Array:
	var wanted: Array = []
	if not prefetch or not MusicDirector.threaded_loads() or not uses_default_loader():
		return wanted
	for wanted_state: String in STATES:
		var id := track_for(wanted_state)
		if id == "":
			continue
		var track: Dictionary = tracks[id]
		for part: Dictionary in track.get("stems", [{"file": track.get("file", "")}]):
			wanted.append(dir.path_join(String(part["file"])))
	for id: String in stingers:
		wanted.append(dir.path_join(String(stingers[id]["file"])))
	for path: String in wanted:
		if path.begins_with("res://") and not _requested.has(path) and not _held.has(path) and ResourceLoader.exists(path):
			if ResourceLoader.load_threaded_request(path) == OK:
				_requested[path] = true
	return wanted


## Whether this platform loads on a thread (not the web build, which keeps the synchronous path).
static func threaded_loads() -> bool:
	return OS.has_feature("threads") and not OS.has_feature("web")


## Whether `load_stream` is the game's own loader (a test swaps in its own).
func uses_default_loader() -> bool:
	return load_stream == Callable(self, "_default_load")


func _default_load(path: String) -> AudioStream:
	if _held.has(path):
		return _held[path]
	var stream: AudioStream = null
	if _requested.has(path):
		_requested.erase(path)
		stream = ResourceLoader.load_threaded_get(path) as AudioStream
	if stream == null:
		stream = _load_any(path)
	if stream != null:
		_held[path] = stream
	return stream


func _notification(what: int) -> void:
	# Requests nobody took (a stinger never played): collect them so the loader lets go of them.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		MusicDirector.quiet_for_quit(get_tree())  # the window is closing: the engine quits at the end of this frame
	if what == NOTIFICATION_PREDELETE:
		for path: String in _requested:
			ResourceLoader.load_threaded_get(path)
		_requested.clear()


## Round 18 (finale; lent, C18.6): a quit mid-match left "2 resources still in use at exit" (AudioStreamPlaybackOggVorbis
## and its OggPacketSequencePlayback, the music's) in 18 of 46 exported headless runs on builder0, 0 of 14 with the music
## off. `stop()` only MARKS a playback; the audio thread deletes it at its next mix, and the engine's resource check at
## exit can come first. So before a quit tears the tree down: every playing player stops, and the main thread waits two
## audio buffers (bounded) while the audio thread mixes and lets go. SYNCHRONOUS on purpose: no frame passes, so no tick
## runs and no SIM_HASH line is added. Nothing playing: returns at once. Whether he ever hit it (his laptop mixes through
## PulseAudio every ~10 ms) is not measured. Returns the milliseconds it waited.
const QUIT_WAIT_CAP_MS := 250


static func quiet_for_quit(tree: SceneTree) -> int:
	if tree == null or tree.root == null:
		return 0
	var stopped := 0
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for node in tree.root.find_children("*", kind, true, false):
			if bool(node.get("playing")):
				node.call("stop")
				stopped += 1
	if stopped == 0:
		return 0
	var wait := MusicDirector.quit_wait_ms(AudioServer.get_output_latency(), AudioServer.get_mix_rate())
	OS.delay_msec(wait)
	return wait


## Two audio buffers (the driver's latency, or a 1024-frame buffer at the mix rate when it reports none -- the Dummy
## driver does), plus a margin, never over QUIT_WAIT_CAP_MS. Pure.
static func quit_wait_ms(latency_s: float, mix_rate: float) -> int:
	var buffer_s := latency_s if latency_s > 0.0 else 1024.0 / maxf(mix_rate, 8000.0)
	return clampi(ceili(buffer_s * 2.0 * 1000.0) + 5, 5, QUIT_WAIT_CAP_MS)


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
	set_state(held if held != "" else mood_music_state())
	# After the first bed: it starts at once as it always did, not queued behind every other file on the loader.
	prefetch_draws()


## Plays `hold_state` and keeps it whatever the mood does, until [method release] (the garage).
func hold(hold_state: String) -> void:
	held = hold_state
	set_state(held)


## Back to following the mood: the state it is in now, which straight after the garage is the opening.
func release() -> void:
	held = ""
	set_state(mood_music_state())


## What the mood asks for right now (the opening when there is no mood yet).
func mood_music_state() -> String:
	if _mood == null:
		return "pre_match"
	return music_state_for(String(_mood.current()["state"]), _mood.started_contact)


## The director's state for a mood reading: the mood's own, except that the quiet before anybody has fired is the
## opening (`pre_match`), not a lull.
static func music_state_for(mood_state: String, started_contact: bool) -> String:
	return "pre_match" if mood_state == "lull" and not started_contact else mood_state


func _on_mood_changed(reading: Dictionary) -> void:
	if held != "":
		return
	set_state(music_state_for(String(reading["state"]), _mood != null and _mood.started_contact))
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
	if name == CARRIED and _clock >= _carry_log_at:
		_carry_log_at = _clock + CARRY_LOG_S
		print("MUSIC_CARRY waiting track=%s playing=%s pos=%.2f t=%.1f" % [track_id, _playing(), position_s(), _clock])
	_hold_loop()
	if pending != "" and _ready_for_bar_line():
		_crossfade_now()
	elif pending == "" and _stems != null and _crossed_bar_line():
		update_layers(current_intensity(), state, true)


## The Music bus: the player's volume, the trim, and IN_MATCH_LIFT_DB while a match plays (any state but the garage's).
func _apply_bus_volume() -> void:
	var index := AudioServer.get_bus_index(BUS)
	if index >= 0:
		var lift := IN_MATCH_LIFT_DB if lift_allowed and state != "" and state != "garage" else 0.0
		AudioServer.set_bus_volume_db(index, volume_db + TRIM_DB + lift)


## Asks for a state. The bed changes at the next bar line; asking for the state that is already playing does nothing.
func set_state(next: String) -> void:
	if next == state and pending == "":
		return
	state = next
	_apply_bus_volume()
	var wanted := track_for(next)
	if wanted == "" or wanted == track_id:
		pending = ""
		return
	pending = wanted
	# Nothing started yet: start straight away. Asked of the director, not the audio server: a bed started this frame
	# may not be reported as playing until the mixing thread gets to it, and on a busy machine that cut the next bed
	# in early (control's check, round 8). A bed that really stopped is replaced on the next frame (_crossed_bar_line).
	if not is_inside_tree() or track_id == "":
		_crossfade_now()


## The best track for a state: this match's pick among [method candidates_for]; "" when none fits.
func track_for(wanted: String) -> String:
	var tied := candidates_for(wanted)
	if tied.size() <= 1:
		return "" if tied.is_empty() else String(tied[0])
	var key := ",".join(tied)
	if not _picks.has(key):
		_picks[key] = pick_among(tied, match_seed, history)
	return _picks[key]


## Every track that fits a state equally well, sorted: the ones whose `states` list it, a stem set first, then the
## highest intensity.
func candidates_for(wanted: String) -> Array:
	var tied: Array = []
	var best_intensity := -1.0
	var ids: Array = tracks.keys()
	ids.sort()  # deterministic order for the draw
	for id in ids:
		var track: Dictionary = tracks[id]
		if not wanted in track.get("states", []):
			continue
		# A stem set outranks a single bed for the same state: it follows the fight instead of stepping.
		var intensity := float(track.get("intensity", 0.0)) + (10.0 if track.has("stems") else 0.0)
		if intensity > best_intensity + 0.0001:
			tied = [id]
			best_intensity = intensity
		elif is_equal_approx(intensity, best_intensity):
			tied.append(id)
	return tied


## Which of `tied` a match plays: among those heard least recently (all of them, with no memory), the one this
## match's seed lands on. The seed is mixed with the set itself, so each state draws for itself.
static func pick_among(tied: Array, seed_value: int, memory: MusicHistory = null) -> String:
	var freshest: Array = []
	var oldest := 0x7fffffffffffffff
	for id in tied:
		var heard_at := memory.last_heard(id) if memory != null else -1
		if heard_at < oldest:
			freshest = [id]
			oldest = heard_at
		elif heard_at == oldest:
			freshest.append(id)
	return freshest[posmod(hash("%d|%s" % [seed_value, ",".join(tied)]), freshest.size())]


## A new match: draw every state again (the seed or the memory has changed).
func forget_picks() -> void:
	_picks.clear()
	prefetch_draws()


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
	var cost_from := Time.get_ticks_usec()
	# Where in its bar the outgoing bed is as this crossfade starts (0..1; -1 with nothing playing): the bar-line rule's
	# own witness in the log, so a change that moved it would show (P8's check).
	var out_bar_s := seconds_per_bar(tracks.get(track_id, {}))
	var bar_phase := fmod(position_s(), out_bar_s) / out_bar_s if out_bar_s > 0.0 and _playing() else -1.0
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
	if history != null:
		history.heard(track_id)
		history.save()
	# Marker for make music-smoke: the soundtrack is the one thing here that a headless run can prove.
	# `cost`: this bed change's main-thread ms (loading and starting it), round 16's P8 measure.
	print("MUSIC_TRACK state=%s track=%s t=%.1f cost=%.2f bar_phase=%.2f" % [state, track_id, _clock,
			(Time.get_ticks_usec() - cost_from) / 1000.0, bar_phase])
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
