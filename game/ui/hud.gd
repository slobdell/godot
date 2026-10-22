class_name Hud
extends CanvasLayer
## The always-on HUD: status line, scoreboard, center banner. Layout and styling live in
## hud.tscn (look-and-feel workstream); this script only fills in text.

## Severity for post_message (contract: see _agents/workstreams.md "HUD messages").
const INFO := 0
const WARNING := 1
const ERROR := 2

signal message_posted(text: String, severity: int)
## Control X2: a subtitle, shown on the caption line instead of the message log.
signal caption_posted(speaker: String, text: String)

## Speakers whose "SPEAKER: line" messages are subtitles, not gameplay messages (the booth's labels,
## AnnouncerBooth.SPEAKER_LABELS). Kept until the booth calls post_caption itself.
const CAPTION_SPEAKERS := ["CALLER", "VETERAN", "PA", "BOOTH"]

var game_match: Match
## The tank a local player drives, if any (shows HP/reload).
var local_tank: Tank

var _status := ""
var caption_line := CaptionLine.new()
## Round 19 (board, S2): the score bug, top centre, once the match decides by control or elimination (it replaces the
## "Green N units vs M units Rust" line). Null until then, and in `make run`'s respawn matches.
var score_bug: ScoreBug
var zone_rings: ZoneRings
## The team the local player commands (the bug draws it on the left in the friendly colour).
var team := Match.Team.GREEN
## Round 38 (feedback F1/F2): the end of a match he commands; null until `Match.finished`.
var end_card: EndCard
var _end_hooked: Match

@onready var status_label: Label = $Status
@onready var scoreboard: Label = $Scoreboard
@onready var banner: Label = $Banner


func _ready() -> void:
	add_child(caption_line)
	# Round 19 (board): the bug must be up while he plans (the match opens paused, and this node's _process pauses
	# with it), so a mount that runs regardless puts it up, then stops.
	var mount := _BugMount.new()
	mount.hud = self
	mount.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(mount)
	if EndShots.wanted():
		add_child(EndShots.new())


class _BugMount extends Node:
	var hud: Hud

	func _process(_delta: float) -> void:
		var bug := hud.score_bug != null or hud._maybe_add_score_bug()
		if hud._maybe_hook_end() and bug:
			set_process(false)


func set_status(text: String) -> void:
	_status = text


## Tell the player something happened. Gameplay calls this; how it looks (cyberpunk banners)
## is the look & feel stream's job. For now: the banner label, briefly, plus the signal.
## A booth line ("CALLER: ...") goes to the caption line instead (control X2), so kills and orders keep the log.
func post_message(text: String, severity: int = INFO) -> void:
	print("HUD_MESSAGE [%s] %s" % [["info", "warning", "error"][clampi(severity, 0, 2)], text])
	var colon := text.find(": ")
	if severity == INFO and colon > 0 and CAPTION_SPEAKERS.has(text.substr(0, colon)):
		_caption(text.substr(0, colon), text.substr(colon + 2))
		return
	message_posted.emit(text, severity)


## Control X2: a subtitle on its own line (speaker, then what they said), never in the message log.
func post_caption(speaker: String, text: String) -> void:
	print("HUD_MESSAGE [info] %s: %s" % [speaker, text])
	_caption(speaker, text)


func _caption(speaker: String, text: String) -> void:
	caption_line.show_line(speaker, text)
	caption_posted.emit(speaker, text)


func show_banner(text: String) -> void:
	banner.text = text
	banner.visible = end_card == null  # the end card says it (and why) itself


## Round 38 (feedback): listen for the end once the match is known. True once hooked.
func _maybe_hook_end() -> bool:
	if game_match == null:
		return false
	if _end_hooked != game_match:
		game_match.finished.connect(_on_match_finished)
		_end_hooked = game_match
	return true


## F1/F2: where he commands an army (the controls are on this layer and nobody is spectating), the end gets its card: it
## says who won and why, and stops a click from ordering a finished match.
func _on_match_finished(result: Dictionary) -> void:
	var controls := _commanding_controls()
	if controls == null or end_card != null:
		return
	var main := get_parent()
	var flags: LaunchFlags = main.get("flags") if main != null and main.get("flags") is LaunchFlags else LaunchFlags.new()
	if SkirmishMode.spectated(flags):
		return
	end_card = EndCard.new()
	end_card.setup(result, team, false, {Match.Team.GREEN: flags.text("player-faction"),
			Match.Team.RUST: flags.text("enemy-faction")}, flags.text("end-look"))
	end_card.yield_to = main.get_node_or_null("ArmyLoop") if main != null else null
	end_card.choices = end_card.yield_to == null  # the garage's results screen follows
	end_card.rig = main.get_node_or_null("RtsCamera") if main != null else null
	end_card.focus = EndCard.decided_at(game_match, result)
	end_card.hide_nodes.append(controls)
	end_card.chosen.connect(_on_end_chosen.bind(flags))
	banner.visible = false
	add_child(end_card)


func _commanding_controls() -> Control:
	for node_name in ["RtsControls", "TacticalMap"]:
		var node := get_node_or_null(node_name) as Control
		if node != null:
			return node
	return null


func _on_end_chosen(choice: String, flags: LaunchFlags) -> void:
	# The skirmish's own seed formula (make skirmish): a new fight each time.
	GameLauncher.start(get_tree(), MatchEnd.next_flags(flags, choice, int(Time.get_unix_time_from_system()) % 100000))


## True once the bug is up (a match that decides by control or elimination, with its armies on the field).
func _maybe_add_score_bug() -> bool:
	if score_bug != null:
		return true
	if game_match == null or not (game_match.elimination or game_match.control_point) or game_match.tanks.get_child_count() == 0:
		return false
	_add_score_bug()
	return true


func _add_score_bug() -> void:
	score_bug = ScoreBug.new()
	score_bug.process_mode = Node.PROCESS_MODE_ALWAYS  # its animations run while he plans
	score_bug.name = "ScoreBug"
	score_bug.team = team
	add_child(score_bug)
	score_bug.game_match = game_match
	# ...and the zones themselves on the floor, where he is looking (the HUD exists only where there is a screen).
	if game_match.control_point and zone_rings == null:
		zone_rings = ZoneRings.new()
		zone_rings.team = team
		game_match.add_child(zone_rings)
		zone_rings.game_match = game_match


func _process(_delta: float) -> void:
	var started := HudClock.begin()
	_process_timed(_delta)
	HudClock.end(&"hud.process", started)


func _process_timed(_delta: float) -> void:
	if game_match == null:
		return
	status_label.text = _status
	var line := "Green %d : %d Rust" % [game_match.score_green, game_match.score_rust]
	_maybe_add_score_bug()
	if score_bug != null:
		line = ""
	if local_tank != null and is_instance_valid(local_tank):
		var bars := int(round(local_tank.reload_fraction() * 10.0))
		# ASCII on purpose: the default font has no block glyphs (they render as empty boxes).
		line += "      HP %d  Shield %d      Reload [%s]" % [local_tank.sync_health, local_tank.sync_shield,
				"#".repeat(bars) + "-".repeat(10 - bars)]
		if local_tank.sync_ammo >= 0:
			line += "  Ammo %d" % local_tank.sync_ammo
		if not local_tank.is_alive():
			show_banner("Destroyed — respawning…")
		elif banner.text.begins_with("Destroyed"):
			banner.visible = false
	scoreboard.text = line
