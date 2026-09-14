class_name Hud
extends CanvasLayer
## The always-on HUD: status line, scoreboard, center banner. Layout and styling live in
## hud.tscn (look-and-feel workstream); this script only fills in text.

var game_match: Match
## The tank a local player drives, if any (shows HP/reload).
var local_tank: Tank

var _status := ""

@onready var status_label: Label = $Status
@onready var scoreboard: Label = $Scoreboard
@onready var banner: Label = $Banner


func set_status(text: String) -> void:
	_status = text


func show_banner(text: String) -> void:
	banner.text = text
	banner.visible = true


func _process(_delta: float) -> void:
	if game_match == null:
		return
	status_label.text = "%s   |   tanks: %d" % [_status, game_match.tanks.get_child_count()]
	var line := "Green %d : %d Rust" % [game_match.score_green, game_match.score_rust]
	if game_match.elimination:
		line = "Green %d tanks  vs  %d tanks Rust" % [game_match.alive_count(Match.Team.GREEN),
				game_match.alive_count(Match.Team.RUST)]
	if local_tank != null and is_instance_valid(local_tank):
		var bars := int(round(local_tank.reload_fraction() * 10.0))
		# ASCII on purpose: the default font has no block glyphs (they render as empty boxes).
		line += "      HP %d      Reload [%s]" % [local_tank.sync_health, "#".repeat(bars) + "-".repeat(10 - bars)]
		if not local_tank.is_alive():
			show_banner("Destroyed — respawning…")
		elif banner.text.begins_with("Destroyed"):
			banner.visible = false
	scoreboard.text = line
