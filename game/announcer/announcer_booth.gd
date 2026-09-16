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
## Marker: ANNOUNCER_RECORDED path=... events=N problems=N

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
var adapter: MatchEventAdapter
var director: AnnouncerDirector
var voice: AnnouncerVoice
var recorded: Array = []
var _last_cue := {}


## Adds a booth to the running game if the launch flags ask for one. Returns it, or null.
static func attach(main: Node) -> AnnouncerBooth:
	var flags: LaunchFlags = main.flags
	if not flags.has("announcer") and not flags.has("announcer-record"):
		return null
	var booth := AnnouncerBooth.new()
	booth.name = "AnnouncerBooth"
	booth.game_match = main.game_match
	booth.hud = main.hud
	booth.mode = flags.text("announcer", "off" if flags.has("announcer-record") else "text")
	booth.record_path = flags.text("announcer-record")
	var seed_text := flags.text("announcer-seed")
	booth.setup(flags.text("arena", Arena.DEFAULT_LAYOUT), int(seed_text) if seed_text.is_valid_int() else -1,
			flags.text("announcer-clips", DEFAULT_CLIPS), float(flags.text("announcer-volume", "0")))
	main.game_match.add_child(booth)
	return booth


func setup(arena: String, seed_value: int = -1, clips_dir: String = DEFAULT_CLIPS, volume_db: float = 0.0) -> void:
	var library := AnnouncerLibrary.load_default()
	if seed_value < 0:
		# Presentation randomness: a fresh broadcast each match, from its own generator (never the simulation's).
		var fresh := RandomNumberGenerator.new()
		fresh.randomize()
		seed_value = fresh.randi() & 0x7fffffff
	adapter = MatchEventAdapter.new(game_match, arena)
	director = AnnouncerDirector.new(library, seed_value)
	if mode == "voice":
		voice = AnnouncerVoice.new()
		voice.name = "Voice"
		voice.volume_db = volume_db
		if voice.load_clips(ProjectSettings.globalize_path(clips_dir)) and library.load_manifest(ProjectSettings.globalize_path(clips_dir).path_join("manifest.json")):
			add_child(voice)
		else:
			print("ANNOUNCER no recorded clips in %s yet: subtitles only" % clips_dir)
			voice = null


func _ready() -> void:
	# After the match has stepped this tick, so events carry this tick's state.
	process_physics_priority = 100


func _physics_process(_delta: float) -> void:
	if adapter == null:
		return
	for event in adapter.poll():
		recorded.append(event)
		if mode != "off":
			director.push_event(event)
		if event["type"] == "match_end" and record_path != "":
			_write_record()
	if mode == "off":
		return
	if not _last_cue.is_empty() and _last_cue.get("cut", false) and voice != null and not _last_cue.get("_voice_cut", false):
		_last_cue["_voice_cut"] = true
		voice.cut()
	for cue in director.advance(adapter.seconds()):
		_say(cue)


## Keeps talking through the result and sign-off after the match stops ticking (skirmish results screen).
func _process(_delta: float) -> void:
	if adapter == null or mode == "off" or not director.memory.finished or director.is_done():
		return
	for cue in director.advance(director.now + get_process_delta_time()):
		_say(cue)


func _say(cue: Dictionary) -> void:
	_last_cue = cue
	if subtitles and hud != null:
		hud.post_message("%s: %s" % [SPEAKER_LABELS.get(cue["speaker"], "BOOTH"), cue["text"]], Hud.INFO)
	if voice != null:
		voice.play(cue)
	line_started.emit(cue)


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
