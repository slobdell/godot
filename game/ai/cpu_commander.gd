class_name CpuCommander
extends Node
## Stretch: a CPU commander for one team. It plays the tactical map the way a player would: every
## THINK_TICKS it looks at its team's intel and issues SquadCommands (the same data the map, the agent
## bridge, and the network send) to its gun squads. Scout and artillery squads are left to their
## brains (SPOT, BOMBARD), which already do their jobs.
##
## Policy (deterministic, thinks on Match.tick):
##   nothing known         -> MOVE in a wedge toward the objective (the center if contested, else a
##                            point ahead, advancing), BOUND once within BOUND_RANGE of old contacts
##   enemies in sight      -> compare strength (hull + shield of our living tanks vs the enemies we
##                            know about): ASSAULT when clearly stronger, BREAK CONTACT when clearly
##                            weaker, otherwise HOLD facing them and let them come
## A command is only re-issued when the verb changes or the destination moves by REISSUE_METERS,
## because every new order resets the brains' commitment.

const THINK_TICKS := 120
const ASSAULT_RATIO := 1.25
const WITHDRAW_RATIO := 0.7
const BOUND_RANGE := 110.0
const REISSUE_METERS := 15.0
## How far ahead of the squad a movement leg goes when there's nothing to go for.
const LEG := 50.0

var game_match: Match
var team := Match.Team.RUST
## Squad name -> the last command sent.
var last_commands := {}
var _offset := 0


func _ready() -> void:
	# Lower priority runs first, like other deciders: commands are in place before brains think.
	process_physics_priority = -20
	_offset = 37 + team * 11  # stagger from the other team's commander


func _physics_process(_delta: float) -> void:
	if game_match == null or (game_match.tick + _offset) % THINK_TICKS != 0:
		return
	think()


func think() -> void:
	var by_name := game_match.tanks_by_name()
	for squad in game_match.team_squads(team):
		if not _is_gun_squad(squad, by_name):
			continue
		var command := plan_for(squad, by_name)
		if command.is_empty() or not _worth_sending(squad.squad_name, command):
			continue
		if game_match.command_squad(team, command) == "":
			last_commands[squad.squad_name] = command


static func _is_gun_squad(squad: Squad, by_name: Dictionary) -> bool:
	for member in squad.alive_members(by_name):
		var tank := by_name[member] as Tank
		return Units.PROFILES.get(tank.unit_id, {}).get("class", "tank") == "tank"
	return false


## The command this squad should be under right now ({} = leave it).
func plan_for(squad: Squad, by_name: Dictionary) -> Dictionary:
	var alive := squad.alive_members(by_name)
	if alive.is_empty():
		return {}
	var lead := by_name[squad.commander] as Tank
	var frame := Match.team_frame(team)
	var home := Match.spawn_position(team, 0)
	var intel: Dictionary = game_match.intel[team]
	var names := intel.keys()
	names.sort()
	var visible_sum := Vector3.ZERO
	var visible_count := 0
	var enemy_strength := 0.0
	var freshest: Variant = null
	var freshest_tick := -1
	for contact_name in names:
		var contact: Dictionary = intel[contact_name]
		enemy_strength += float(contact["health"]) + float(contact.get("shield", 0))
		if contact["visible"]:
			visible_sum += contact["position"]
			visible_count += 1
		if int(contact["seen_tick"]) > freshest_tick:
			freshest_tick = int(contact["seen_tick"])
			freshest = contact["position"]
	var our_strength := 0.0
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and Units.PROFILES.get(tank.unit_id, {}).get("class", "tank") != "artillery":
			our_strength += tank.health + tank.shield

	if visible_count > 0:
		var threat := visible_sum / visible_count
		var facing := threat - lead.global_position
		if our_strength >= enemy_strength * ASSAULT_RATIO:
			return {"squad": squad.squad_name, "verb": "assault", "to": _clamp_xz(threat), "formation": "line"}
		if our_strength <= enemy_strength * WITHDRAW_RATIO:
			return {"squad": squad.squad_name, "verb": "break_contact", "to": _clamp_xz(home)}
		return {"squad": squad.squad_name, "verb": "hold", "to": _clamp_xz(lead.global_position),
				"facing": [facing.x, facing.z], "formation": "line"}

	var goal: Vector3
	if game_match.control_point and game_match.control_owner != team:
		goal = Match.CONTROL_CENTER
	elif freshest != null:
		goal = freshest
	else:
		goal = lead.global_position + (frame["forward"] as Vector3) * LEG
	var verb := "bound" if freshest != null and lead.global_position.distance_to(goal) <= BOUND_RANGE else "move"
	return {"squad": squad.squad_name, "verb": verb, "to": _clamp_xz(goal), "formation": "wedge"}


func _worth_sending(squad_name: String, command: Dictionary) -> bool:
	var last: Dictionary = last_commands.get(squad_name, {})
	if last.is_empty() or last["verb"] != command["verb"]:
		return true
	var a := Vector2(float(last["to"][0]), float(last["to"][1]))
	var b := Vector2(float(command["to"][0]), float(command["to"][1]))
	return a.distance_to(b) >= REISSUE_METERS


static func _clamp_xz(point: Vector3) -> Array:
	var limit := Squad.ARENA_LIMIT - 4.0
	return [clampf(point.x, -limit, limit), clampf(point.z, -limit, limit)]
