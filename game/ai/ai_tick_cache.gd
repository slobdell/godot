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
const COS_30 := 0.8660254
## [team] -> {contact name: [names of that team's living tanks the contact faces]}, per intel refresh.
static var _facing_cache: Array = [{}, {}]
static var _facing_bucket := -1
static var _facing_bucket_match := 0
## Rounds in flight this tick, for dodging (IncomingFire): [[position, velocity, team, id]], scene order.
static var _rounds: Array = []
## Physics frame each tank last fired (by instance id): a muzzle flash is plain to see, so brains may use it to tell a
## loaded gun from a reloading one (X3 reload windows). Hooked to Tank.fired once per tank.
static var _fired := {}
static var _hooked := {}
## [team] -> [{"name", "position", "squad"}] for living tanks, by name (brains skip themselves).
static var _allies: Array = [[], []]
## [team] -> intel names sorted, per intel refresh.
static var _intel_names: Array = [[], []]
static var _intel_bucket := -1


static func _refresh(game_match: Match) -> void:
	if _match_id == game_match.get_instance_id() and _tick == game_match.tick:
		return
	if _match_id != game_match.get_instance_id():
		_fired = {}
		_hooked = {}
	_match_id = game_match.get_instance_id()
	_tick = game_match.tick
	_by_name = game_match.tanks_by_name()
	for tank: Tank in _by_name.values():
		var id := tank.get_instance_id()
		if not _hooked.has(id):
			_hooked[id] = true
			tank.fired.connect(AiTickCache._on_fired.bind(id))
	_team_tanks = [[], []]
	_allies = [[], []]
	for tank: Tank in _by_name.values():
		(_team_tanks[tank.team] as Array).append(tank)
		if tank.is_alive():
			(_allies[tank.team] as Array).append({"name": String(tank.name), "position": tank.global_position,
					"squad": game_match.squad_of(tank)})
	_enemies = [[], []]
	_rounds = []
	var shells := game_match.get_node_or_null("Shells")
	if shells != null:
		for node in shells.get_children():
			var shell := node as Shell
			if shell != null and shell.is_physics_processing():
				_rounds.append([shell.global_position, shell.direction * Shell.SPEED, shell.team, String(shell.name)])
	# Perception.enemies_of order (scene order), so nearest-first scans break exact ties the same way.
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.is_alive():
			(_enemies[1 - tank.team] as Array).append(tank)


## Living tanks of `team` as {"name", "position", "squad"}, by name, once per tick. Shared: never modify.
static func allies(game_match: Match, team: int) -> Array:
	_refresh(game_match)
	return _allies[team]


## `team`'s intel contact names, sorted, once per intel refresh (Match.INTEL_EVERY_TICKS). Shared: never modify.
static func intel_names(game_match: Match, team: int) -> Array:
	var bucket := game_match.tick / Match.INTEL_EVERY_TICKS
	if _intel_bucket != bucket or _match_id != game_match.get_instance_id():
		_refresh(game_match)
		_intel_bucket = bucket
		for side in 2:
			var names := (game_match.intel[side] as Dictionary).keys()
			names.sort()
			_intel_names[side] = names
	return _intel_names[team]


static func _on_fired(_muzzle: Vector3, _direction: Vector3, id: int) -> void:
	_fired[id] = Engine.get_physics_frames()


## Seconds until `tank`'s gun is loaded again, judged from its last shot and its weapon's reload (0 = loaded or never
## seen firing).
static func gun_ready_in(game_match: Match, tank: Tank) -> float:
	_refresh(game_match)
	var fired: Variant = _fired.get(tank.get_instance_id())
	if fired == null:
		return 0.0
	var reload := float(tank.weapon.get("reload", 0.0))
	return maxf(0.0, reload - float(Engine.get_physics_frames() - int(fired)) / 60.0)


## Shells in flight this tick: [[position, velocity, team, name]] (IncomingFire's source before K2).
static func rounds(game_match: Match) -> Array:
	_refresh(game_match)
	return _rounds


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
## Cached per contact for one intel refresh (Match.INTEL_EVERY_TICKS): the contact's data only changes then,
## and allies move under 1.5 m in that time. Plain dot products: this was the costliest part of a brain's
## situation at 50 units (contacts × allies).
static func faced_by(game_match: Match, team: int, contact_name: String, known: Dictionary) -> Array:
	var bucket := game_match.tick / Match.INTEL_EVERY_TICKS
	if _facing_bucket_match != game_match.get_instance_id() or _facing_bucket != bucket:
		_facing_bucket_match = game_match.get_instance_id()
		_facing_bucket = bucket
		_facing_cache = [{}, {}]
	var table: Dictionary = _facing_cache[team]
	if table.has(contact_name):
		return table[contact_name]
	var position: Vector3 = known["position"]
	var forward := Vector2(known["forward"].x, known["forward"].z)
	var faced: Array = []
	if forward.length_squared() > 1e-6:
		forward = forward.normalized()
		for ally: Tank in team_tanks(game_match, team):
			if not ally.is_alive():
				continue
			var dx := ally.global_position.x - position.x
			var dz := ally.global_position.z - position.z
			var distance_squared := dx * dx + dz * dz
			if distance_squared >= 6400.0 or distance_squared < 1e-6:
				continue
			if forward.x * dx + forward.y * dz >= COS_30 * sqrt(distance_squared):
				faced.append(String(ally.name))
	table[contact_name] = faced
	return faced
