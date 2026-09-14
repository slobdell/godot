class_name MatchAnnouncer
extends Node
## Turns what happens in a match into short messages for ONE team's player: order
## acknowledgements, first contact, losses, commander succession, the result. Skirmish mode
## forwards `announced` to Hud.post_message (the HUD messages contract in workstreams.md);
## how a message looks is the look & feel stream's job.

signal announced(text: String, severity: int)

## Don't repeat "contact" more often than this while enemies keep popping in and out of sight.
const CONTACT_COOLDOWN_TICKS := 60 * 20

var game_match: Match
var team := Match.Team.GREEN

var _had_contact := false
var _last_contact_tick := -CONTACT_COOLDOWN_TICKS


func _ready() -> void:
	game_match.tank_destroyed.connect(_on_tank_destroyed)
	game_match.finished.connect(_on_finished)
	for squad in game_match.team_squads(team):
		squad.commander_lost.connect(_on_commander_lost.bind(squad.squad_name))


func _physics_process(_delta: float) -> void:
	if game_match.tick % Match.INTEL_EVERY_TICKS != 0:
		return
	var in_sight := 0
	for contact in game_match.intel[team].values():
		if contact["visible"]:
			in_sight += 1
	if in_sight > 0 and not _had_contact and game_match.tick - _last_contact_tick >= CONTACT_COOLDOWN_TICKS:
		_last_contact_tick = game_match.tick
		_say("Contact: %d enem%s in sight" % [in_sight, "y" if in_sight == 1 else "ies"], Hud.WARNING)
	_had_contact = in_sight > 0


## Connect TacticalMap.command_issued here. `summary` is the map's human description.
func announce_command(summary: String, error: String) -> void:
	if error == "":
		_say(summary, Hud.INFO)
	else:
		_say("Can't: " + error, Hud.WARNING)


func _on_tank_destroyed(victim: Tank, _killer: String) -> void:
	if victim.team == team:
		var squad_name := game_match.squad_of(victim)
		_say("%s lost %s (%d tanks left)" % [squad_name if squad_name != "" else "We", short_name(String(victim.name)),
				game_match.alive_count(team)], Hud.WARNING)
	else:
		_say("Enemy tank destroyed (%d enemies left)" % game_match.alive_count(1 - team), Hud.INFO)


func _on_commander_lost(fallen: String, successor: String, squad_name: String) -> void:
	_say("%s: commander down, %s takes command" % [squad_name, short_name(successor)], Hud.WARNING)


func _on_finished(_result: Dictionary) -> void:
	var mine := game_match.alive_count(team)
	var theirs := game_match.alive_count(1 - team)
	if mine > 0 and theirs == 0:
		_say("VICTORY", Hud.INFO)
	elif mine == 0:
		_say("DEFEAT", Hud.ERROR)
	else:
		_say("Match over", Hud.INFO)


## "Green_Alpha_2" -> "Alpha 2" (players don't need the team prefix).
static func short_name(tank_name: String) -> String:
	var parts := tank_name.split("_")
	return " ".join(parts.slice(1)) if parts.size() >= 3 and Match.TEAM_NAMES.has(parts[0]) else tank_name


func _say(text: String, severity: int) -> void:
	announced.emit(text, severity)
