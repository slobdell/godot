class_name MatchAnnouncer
extends Node
## Turns what happens in a match into short messages for ONE team's player: order
## acknowledgements, first contact, losses, commander succession, the result. Skirmish mode
## forwards `announced` to Hud.post_message (the HUD messages contract in workstreams.md);
## how a message looks is the look & feel stream's job.

signal announced(text: String, severity: int)

## Don't repeat "contact" more often than this while enemies keep popping in and out of sight.
const CONTACT_COOLDOWN_TICKS := SimClock.TICK_RATE * 20
## R4: say "friendly fire" at most this often per shooter (flames hurt every tick).
const FRIENDLY_FIRE_COOLDOWN_TICKS := SimClock.TICK_RATE * 10

var game_match: Match
var team := Match.Team.GREEN

var _had_contact := false
## Squads currently reported as "shields down" (re-armed once most shields are back).
var _shields_down := {}
## Tank names already reported as out of ammo (cleared when they have shells again).
var _dry := {}
var _last_contact_tick := -CONTACT_COOLDOWN_TICKS
## Shooter name -> tick of its last friendly-fire message.
var _friendly_fire_ticks := {}


func _ready() -> void:
	game_match.tank_destroyed.connect(_on_tank_destroyed)
	game_match.friendly_fire.connect(_on_friendly_fire)
	game_match.finished.connect(_on_finished)
	game_match.control_changed.connect(_on_control_changed)
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
	_check_shields()
	for tank in game_match.sorted_team_tanks(team):
		var tank_name := String(tank.name)
		if tank.is_alive() and tank.sync_ammo == 0:
			if not _dry.has(tank_name):
				_dry[tank_name] = true
				_say("%s is out of ammo" % short_name(tank_name), Hud.WARNING)
		else:
			_dry.erase(tank_name)


## G6: "Alpha: shields down" when at least half a squad's living tanks have no shield; said again
## only after the squad's shields have mostly recharged.
func _check_shields() -> void:
	var by_name := game_match.tanks_by_name()
	for squad in game_match.team_squads(team):
		var alive := squad.alive_members(by_name)
		if alive.is_empty():
			continue
		var down := 0
		var charged := 0
		for member in alive:
			var tank := by_name[member] as Tank
			if tank.max_shield <= 0.0:
				continue
			down += 1 if tank.sync_shield <= 0 else 0
			charged += 1 if tank.sync_shield >= tank.max_shield * 0.5 else 0
		if not _shields_down.has(squad.squad_name) and down * 2 >= alive.size() and down > 0:
			_shields_down[squad.squad_name] = true
			_say("%s: shields down" % squad.squad_name, Hud.WARNING)
		elif _shields_down.has(squad.squad_name) and charged == alive.size():
			_shields_down.erase(squad.squad_name)


## Connect TacticalMap.command_issued here. `summary` is the map's human description.
func announce_command(summary: String, error: String) -> void:
	if error == "":
		_say(summary, Hud.INFO)
	else:
		_say("Can't: " + error, Hud.WARNING)


func _on_tank_destroyed(victim: Tank, killer: String) -> void:
	if victim.team == team:
		var squad_name := game_match.squad_of(victim)
		var by_us := killer.begins_with(Match.TEAM_NAMES[team] + "_")
		_say("%s lost %s%s (%d tanks left)" % [squad_name if squad_name != "" else "We", short_name(String(victim.name)),
				" to friendly fire from %s" % short_name(killer) if by_us else "", game_match.alive_count(team)], Hud.WARNING)
	else:
		_say("Enemy tank destroyed (%d enemies left)" % game_match.alive_count(1 - team), Hud.INFO)


## R4: our own fire hit one of ours (the kill itself is reported by _on_tank_destroyed).
func _on_friendly_fire(victim: Tank, shooter: String, _hull: int, killed: bool) -> void:
	if victim.team != team or killed:
		return
	if game_match.tick - int(_friendly_fire_ticks.get(shooter, -FRIENDLY_FIRE_COOLDOWN_TICKS)) < FRIENDLY_FIRE_COOLDOWN_TICKS:
		return
	_friendly_fire_ticks[shooter] = game_match.tick
	_say("Friendly fire: %s hit %s" % [short_name(shooter), short_name(String(victim.name))], Hud.WARNING)


func _on_commander_lost(fallen: String, successor: String, squad_name: String) -> void:
	_say("%s: commander down, %s takes command" % [squad_name, short_name(successor)], Hud.WARNING)


func _on_control_changed(owner: int) -> void:
	if owner == team:
		_say("We hold the center", Hud.INFO)
	elif owner >= 0:
		_say("The enemy took the center", Hud.WARNING)
	else:
		_say("The center is neutral", Hud.INFO)


func _on_finished(_result: Dictionary) -> void:
	var mine := game_match.alive_count(team)
	var theirs := game_match.alive_count(1 - team)
	if game_match.control_point and maxi(game_match.control_score[0], game_match.control_score[1]) >= Match.CONTROL_POINTS_TO_WIN:
		mine = 1 if game_match.control_score[team] >= Match.CONTROL_POINTS_TO_WIN else 0
		theirs = 1 - mine
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
