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

@onready var status_label: Label = $Status
@onready var scoreboard: Label = $Scoreboard
@onready var banner: Label = $Banner


func _ready() -> void:
	add_child(caption_line)


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
	banner.visible = true


func _process(_delta: float) -> void:
	if game_match == null:
		return
	status_label.text = _status
	var line := "Green %d : %d Rust" % [game_match.score_green, game_match.score_rust]
	if game_match.elimination:
		line = "Green %d units  vs  %d units Rust" % [game_match.alive_count(Match.Team.GREEN),
				game_match.alive_count(Match.Team.RUST)]
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
