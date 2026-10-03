class_name AnnouncerBooth
extends Node
## The arena announcer in a live match: MatchEventAdapter (K5 events) -> AnnouncerDirector (what to say) ->
## subtitles through Hud.post_message and, when clips exist, AnnouncerVoice. Presentation only: it reads the match and
## never changes it, and its randomness is its own (`make announcer-record-smoke` checks the sim hash is unchanged).
##
## Launch flags (game/main.gd attaches the booth when either is present):
##   --announcer=text|voice|off   subtitles only, subtitles and voice (needs recorded clips), or nothing
##   --announcer-volume=DB        voice volume
##   --announcer-clips=DIR        folder with manifest.json (default res://assets/announcer/clips)
##   --announcer-seed=N           the director's seed (default: a new one each match)
##   --announcer-record=PATH      also write the match's K5 events to PATH (.jsonl) when it ends
##   --announcer-history=PATH|off  where the cross-match recency memory lives (default user://announcer_history.json)
## Marker: ANNOUNCER_RECORDED path=... events=N problems=N
##
## The booth also keeps the match's [MatchMood] (L5) up to date from the same events, because it already polls them
## and MatchMood costs nothing. That is what the music director follows, so `--music` alone attaches a silent booth.

## Every line as it starts: {t, end, speaker, text, moment, intensity 1-3, team, ...}. For the crowd (swell on
## intensity 3) and the ad screens (show the caller's line, the team that scored).
signal line_started(cue: Dictionary)

const DEFAULT_CLIPS := "res://assets/announcer/clips"
const SPEAKER_LABELS := {"caller": "CALLER", "color": "VETERAN", "pa": "PA"}

var game_match: Match
var hud: Hud
var mode := "text"
var subtitles := true
var record_path := ""
var history_path := AnnouncerHistory.PATH
## Which bench the mood is read from: the player's team.
var point_of_view := "green"
var adapter: MatchEventAdapter
var director: AnnouncerDirector
## What earlier matches already said, so the PA doesn't open the same way every night (brief X1). Saved when the
## broadcast ends. Tests and automated runs point it somewhere else with --announcer-history (trip-up 54: a test
## must never write the player's real user:// files).
var history: AnnouncerHistory
var history_saved := false
## L5: how the match feels, from the player's side. Read by the music director, and later the crowd and the screens.
var mood: MatchMood
var voice: AnnouncerVoice
## Round 17 (ship W2): where the clips come from. "" = a folder on disk (`--announcer-clips`, default DEFAULT_CLIPS; an
## exported desktop build looks beside its binary, EXPORT_CLIPS). "fetch" = over HTTP on first use from `voice_url`
## (VoiceFetch; `--web-voice=fetch`, the browser option on the lead's W2 page, OFF by default until he chooses).
var voice_source := ""
var voice_url := "voice/"
var fetcher: VoiceFetch
var recorded: Array = []
var _last_cue := {}
## Round 16 (B7): what the booth said, beside the match recording (<recording>.booth.txt), so "I keep hearing ..." is a
## grep over build/recordings. Opened at the first line when the match has a MatchRecorder (his skirmish); closed when
## the booth leaves.
var _said_file: FileAccess
var _said_checked := false


## Adds a booth to the running game if the launch flags ask for one. Returns it, or null.
static func attach(main: Node) -> AnnouncerBooth:
	var flags: LaunchFlags = main.flags
	# --music attaches a silent booth too: the music follows the mood the booth keeps.
	# Feel (round 6): a launch that doesn't say gets the booth on a game with a window (AudioDefaults).
	var announcer := AudioDefaults.value(flags, "announcer")
	if announcer == "off" and not flags.has("announcer-record") and AudioDefaults.value(flags, "music") == "off":
		return null
	var booth := AnnouncerBooth.new()
	booth.name = "AnnouncerBooth"
	booth.add_to_group(CrowdVoice.BOOTH_GROUP)  # the crowd follows the same mood the booth keeps
	booth.game_match = main.game_match
	booth.hud = main.hud
	# Headless with only --music (music-smoke) keeps its old text booth; a windowed game defaults to the voice.
	booth.mode = flags.text("announcer", "off" if flags.has("announcer-record") else (announcer if announcer != "off" else "text"))
	booth.record_path = flags.text("announcer-record")
	var seed_text := flags.text("announcer-seed")
	booth.history_path = flags.text("announcer-history", AnnouncerHistory.PATH)
	booth.voice_source = flags.text("web-voice", "")
	booth.voice_url = flags.text("voice-url", booth.voice_url)
	booth.setup(arena_key(flags.text("arena", Arena.DEFAULT_LAYOUT)), int(seed_text) if seed_text.is_valid_int() else -1,
			flags.text("announcer-clips", DEFAULT_CLIPS), float(flags.text("announcer-volume", "0")))
	main.game_match.add_child(booth)
	print("ANNOUNCER_BOOTH mode=%s" % booth.mode)  # make audio-launch-smoke reads this
	return booth


## The map the booth names: the arena actually built (Arena.active), because `--arena=random` (the skirmish default)
## names no map. "" when nothing is built and the flag doesn't name one, which just keeps {arena} lines quiet.
static func arena_key(flag_value: String) -> String:
	var built := str(Arena.active.get("name", ""))
	if built != "":
		return built
	return "" if flag_value == "random" else flag_value


func setup(arena: String, seed_value: int = -1, clips_dir: String = DEFAULT_CLIPS, volume_db: float = 0.0) -> void:
	var library := AnnouncerLibrary.load_default()
	if seed_value < 0:
		# Presentation randomness: a fresh broadcast each match, from its own generator (never the simulation's).
		var fresh := RandomNumberGenerator.new()
		fresh.randomize()
		seed_value = fresh.randi() & 0x7fffffff
	adapter = MatchEventAdapter.new(game_match, arena)
	director = AnnouncerDirector.new(library, seed_value)
	mood = MatchMood.new(point_of_view)
	# A booth that only records events (--announcer-record) says nothing, so it neither reads nor writes the memory.
	if history_path != "off" and mode != "off":
		history = AnnouncerHistory.load_from(history_path)
		director.history = history
	if mode == "voice" and AudioSolo.allows("booth"):
		voice = AnnouncerVoice.new()
		voice.name = "Voice"
		voice.volume_db = volume_db
		if voice_source == "fetch":
			_fetch_voice(library)
			return
		var folder := clips_folder(clips_dir)
		if voice.load_clips(folder) and library.load_manifest(folder.path_join("manifest.json")):
			add_child(voice)
			# Round 17 (ship W3/W5): the smokes read this to know the booth CAN speak (a voice with no clips is silent).
			print("ANNOUNCER voice: %d clips from %s" % [voice.manifest.get("clips", {}).size(), folder])
		else:
			print("ANNOUNCER no recorded clips in %s yet: subtitles only" % clips_dir)
			voice = null


## Round 17 (ship W5): the clips folder on disk. The clips are `.gdignore`d (no pack carries them: they are read with
## load_from_file), so an EXPORTED build finds them in EXPORT_CLIPS beside its binary (`make export-desktop` copies them
## there); the editor and the tests read the project folder, as before.
const EXPORT_CLIPS := "voice"
static func clips_folder(clips_dir: String) -> String:
	if clips_dir == DEFAULT_CLIPS and not OS.has_feature("editor") and not OS.has_feature("web"):
		var beside := OS.get_executable_path().get_base_dir().path_join(EXPORT_CLIPS)
		if FileAccess.file_exists(beside.path_join("manifest.json")):
			return beside
	return ProjectSettings.globalize_path(clips_dir)


## Round 17 (ship W2, option c): the manifest over HTTP, then the voice joins; clips follow on first use.
func _fetch_voice(library: AnnouncerLibrary) -> void:
	fetcher = VoiceFetch.new()
	fetcher.name = "VoiceFetch"
	fetcher.base_url = voice_url
	add_child(fetcher)
	var joining := voice
	fetcher.manifest_ready.connect(func(ok: bool) -> void:
		if ok and voice == joining and joining.load_clips(fetcher.cache_dir) \
				and library.load_manifest(fetcher.cache_dir.path_join("manifest.json")):
			joining.fetch = fetcher
			add_child(joining)
			print("ANNOUNCER voice joined: clips fetched on first use from %s" % voice_url)
		else:
			print("ANNOUNCER voice fetch failed (%s): subtitles only" % voice_url)
			voice = null)
	print("ANNOUNCER fetching the voice manifest from %s: subtitles until it lands" % voice_url)
	fetcher.start()


func _ready() -> void:
	# After the match has stepped this tick, so events carry this tick's state.
	process_physics_priority = 100


func _physics_process(_delta: float) -> void:
	if adapter == null:
		return
	for event in adapter.poll():
		recorded.append(event)
		mood.push_event(event)
		if mode != "off":
			director.push_event(event)
		if event["type"] == "match_end" and record_path != "":
			_write_record()
	mood.advance(adapter.seconds())
	if mode == "off":
		return
	if not _last_cue.is_empty() and _last_cue.get("cut", false) and voice != null and not _last_cue.get("_voice_cut", false):
		_last_cue["_voice_cut"] = true
		voice.cut()
	for cue in director.advance(adapter.seconds()):
		_say(cue)


## Keeps talking through the result and sign-off after the match stops ticking (skirmish results screen).
func _process(_delta: float) -> void:
	if adapter == null or mode == "off" or not director.memory.finished:
		return
	if director.is_done():
		_remember_tonight()
		return
	for cue in director.advance(director.now + get_process_delta_time()):
		_say(cue)


## Writes what the booth said tonight, once, so the next match opens differently.
func _remember_tonight() -> void:
	if history_saved or history == null:
		return
	history_saved = true
	history.remember(director.used_line_ids())
	history.save()


func _exit_tree() -> void:
	if _said_file != null:
		_said_file.close()
		_said_file = null
	# A match the player quits out of still counts as heard, finished or not (round 16, B2: until then a match quit
	# before its result was forgotten, so the next one could open with the lines he had just heard).
	if director != null and not director.used_line_ids().is_empty():
		_remember_tonight()


func _say(cue: Dictionary) -> void:
	_last_cue = cue
	_write_said(cue)
	if subtitles and hud != null:
		hud.post_message("%s: %s" % [SPEAKER_LABELS.get(cue["speaker"], "BOOTH"), cue["text"]], Hud.INFO)
	if voice != null:
		voice.play(cue)
	line_started.emit(cue)


## One line per cue: match clock, speaker, line id, the words. Read-only on the recorder (sim's): its `path` only.
func _write_said(cue: Dictionary) -> void:
	if not _said_checked:
		_said_checked = true
		var recorder := game_match.get_node_or_null("MatchRecorder") if game_match != null else null
		var recording: String = str(recorder.get("path")) if recorder != null and recorder.get("path") != null else ""
		if recording != "":
			var path := ProjectSettings.globalize_path(recording.trim_suffix(".jsonl") + ".booth.txt")
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			_said_file = FileAccess.open(path, FileAccess.WRITE)
	if _said_file == null:
		return
	var t := float(cue["t"])
	_said_file.store_line("%d:%04.1f  %-7s  %-24s  %s" % [int(t) / 60, fmod(t, 60.0),
			SPEAKER_LABELS.get(cue["speaker"], "BOOTH"), cue["line_id"], cue["text"]])
	_said_file.flush()


func _write_record() -> void:
	var path := ProjectSettings.globalize_path(record_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("announcer: cannot write %s" % path)
		return
	for event in recorded:
		file.store_line(JSON.stringify(event))
	file.close()
	var problems := AnnouncerEvents.validate_timeline(recorded)
	print("ANNOUNCER_RECORDED path=%s events=%d problems=%d%s" % [path, recorded.size(), problems.size(),
			(" first: " + problems[0]) if not problems.is_empty() else ""])
