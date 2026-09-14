class_name AiTickCache
extends RefCounted
## Per-physics-tick shared lookups for brains (_agents/unit_ai.md §8). Every brain thinks before any tank
## moves in a tick (controllers run at process_physics_priority -10), so the tank list, positions, and team
## intel are the same for all of them: computing them once per tick instead of once per brain changes no
## decision. Keyed by match instance and Match.tick.

static var _match_id := 0
static var _tick := -1
static var _by_name := {}
static var _team_tanks: Array = [[], []]
static var _enemies: Array = [[], []]
## [team] -> {contact name: [names of that team's living tanks the contact faces]}
static var _facing: Array = [{}, {}]


static func _refresh(game_match: Match) -> void:
	if _match_id == game_match.get_instance_id() and _tick == game_match.tick:
		return
	_match_id = game_match.get_instance_id()
	_tick = game_match.tick
	_by_name = game_match.tanks_by_name()
	_team_tanks = [[], []]
	for tank: Tank in _by_name.values():
		(_team_tanks[tank.team] as Array).append(tank)
	_enemies = [[], []]
	# Perception.enemies_of order (scene order), so nearest-first scans break exact ties the same way.
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.is_alive():
			(_enemies[1 - tank.team] as Array).append(tank)
	_facing = [{}, {}]


## Match.tanks_by_name(), once per tick.
static func tanks_by_name(game_match: Match) -> Dictionary:
	_refresh(game_match)
	return _by_name


## Match.sorted_team_tanks(team), once per tick (living and dead, sorted by name).
static func team_tanks(game_match: Match, team: int) -> Array:
	_refresh(game_match)
	return _team_tanks[team]


## Living tanks not on `team`, in scene order (Perception.enemies_of without the self check).
static func enemies(game_match: Match, team: int) -> Array:
	_refresh(game_match)
	return _enemies[team]


## Match.squad_context(tank) with the tick's shared name table.
static func squad_context(game_match: Match, tank: Tank) -> Dictionary:
	var squad := game_match.squad_for(tank)
	if squad == null:
		return {}
	return squad.context_for(String(tank.name), tanks_by_name(game_match))


## Names of `team`'s living tanks within 80 m that `known` (an intel contact) points its hull at (±30°).
## TankBrain._faces_any over all allies, computed once per contact per tick.
static func faced_by(game_match: Match, team: int, contact_name: String, known: Dictionary) -> Array:
	_refresh(game_match)
	var table: Dictionary = _facing[team]
	if table.has(contact_name):
		return table[contact_name]
	var position: Vector3 = known["position"]
	var forward: Vector3 = known["forward"]
	var faced: Array = []
	for ally: Tank in _team_tanks[team]:
		if not ally.is_alive():
			continue
		var offset := ally.global_position - position
		if offset.length() < 80.0 and Ballistics.aim_error(position, forward, ally.global_position) <= deg_to_rad(30.0):
			faced.append(String(ally.name))
	table[contact_name] = faced
	return faced
