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
## enemies() plus their positions as typed columns: [[tanks], x, y, z] per team (round-5 X1).
static var _enemy_columns: Array = [[], []]
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
## ...and the same living tanks as typed columns (round-5 X1: local avoidance reads them every tick for every mover).
static var _ally_x: Array = [PackedFloat32Array(), PackedFloat32Array()]
static var _ally_z: Array = [PackedFloat32Array(), PackedFloat32Array()]
static var _ally_names: Array = [PackedStringArray(), PackedStringArray()]
## [team] -> intel names sorted, per intel refresh.
static var _intel_names: Array = [[], []]
static var _intel_bucket := -1
## [team] -> {contact name: the shared half of a brain's contact entry}, per intel refresh (X2). Intel itself only
## changes on a refresh and every brain thinks once per refresh, so these dozen fields were being rebuilt 30 times
## over for identical data. Shared: brains duplicate before adding their own (offset-dependent) fields.
static var _contacts: Array = [{}, {}]
static var _contacts_bucket := -1
## Round-5 X1: the match's shells in flight this tick as typed columns, for counting incoming rounds without building
## Match.incoming_projectiles' dictionaries for every fighting unit every tick (391 usec per tick at 60 units).
## Built lazily on the first ask each tick (Match.tick), in scene order.
static var _flight_tick := -1
static var _flight_match := 0
static var _flight_x := PackedFloat32Array()
static var _flight_z := PackedFloat32Array()
static var _flight_dir_x := PackedFloat32Array()
static var _flight_dir_z := PackedFloat32Array()
static var _flight_vx := PackedFloat32Array()
static var _flight_vz := PackedFloat32Array()
static var _flight_reach := PackedFloat64Array()
static var _flight_shooter := PackedStringArray()


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
	# Packed arrays are values in GDScript (trip-up 48): each column is filled as a local, then stored.
	var ally_x_green := PackedFloat32Array()
	var ally_z_green := PackedFloat32Array()
	var ally_names_green := PackedStringArray()
	var ally_x_rust := PackedFloat32Array()
	var ally_z_rust := PackedFloat32Array()
	var ally_names_rust := PackedStringArray()
	for tank: Tank in _by_name.values():
		(_team_tanks[tank.team] as Array).append(tank)
		if tank.is_alive():
			(_allies[tank.team] as Array).append({"name": String(tank.name), "position": tank.global_position,
					"squad": game_match.squad_of(tank)})
			if tank.team == 0:
				ally_x_green.append(tank.global_position.x)
				ally_z_green.append(tank.global_position.z)
				ally_names_green.append(String(tank.name))
			else:
				ally_x_rust.append(tank.global_position.x)
				ally_z_rust.append(tank.global_position.z)
				ally_names_rust.append(String(tank.name))
	_ally_x = [ally_x_green, ally_x_rust]
	_ally_z = [ally_z_green, ally_z_rust]
	_ally_names = [ally_names_green, ally_names_rust]
	_enemies = [[], []]
	_rounds = []
	var shells := game_match.get_node_or_null("Shells")
	if shells != null:
		for node in shells.get_children():
			var shell := node as Shell
			if shell != null and shell.is_physics_processing():
				_rounds.append([shell.global_position, shell.direction * Shell.SPEED, shell.team, String(shell.name)])
	# Perception.enemies_of order (scene order), so nearest-first scans break exact ties the same way.
	var xs0 := PackedFloat32Array()
	var ys0 := PackedFloat32Array()
	var zs0 := PackedFloat32Array()
	var xs1 := PackedFloat32Array()
	var ys1 := PackedFloat32Array()
	var zs1 := PackedFloat32Array()
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.is_alive():
			(_enemies[1 - tank.team] as Array).append(tank)
			# Indexed by the team these are ENEMIES of (team 0's enemies are team 1's tanks).
			if tank.team == 1:
				xs0.append(tank.global_position.x)
				ys0.append(tank.global_position.y)
				zs0.append(tank.global_position.z)
			else:
				xs1.append(tank.global_position.x)
				ys1.append(tank.global_position.y)
				zs1.append(tank.global_position.z)
	_enemy_columns = [[_enemies[0], xs0, ys0, zs0], [_enemies[1], xs1, ys1, zs1]]


## Shells in flight this tick as typed columns (see _flight_*), built once per tick. Mirrors the shells
## Match.incoming_projectiles looks at: in flight, moving. Shared: never modify.
static func flight(game_match: Match) -> Dictionary:
	if _flight_match != game_match.get_instance_id() or _flight_tick != game_match.tick:
		_flight_match = game_match.get_instance_id()
		_flight_tick = game_match.tick
		_flight_x = PackedFloat32Array()
		_flight_z = PackedFloat32Array()
		_flight_dir_x = PackedFloat32Array()
		_flight_dir_z = PackedFloat32Array()
		_flight_vx = PackedFloat32Array()
		_flight_vz = PackedFloat32Array()
		_flight_reach = PackedFloat64Array()
		_flight_shooter = PackedStringArray()
		var shells := game_match.get_node_or_null("Shells")
		if shells != null:
			for node in shells.get_children():
				var shell := node as Shell
				if shell == null or not shell.in_flight() or shell.speed <= 0.0:
					continue
				var direction := Vector2(shell.direction.x, shell.direction.z).normalized()
				_flight_x.append(shell.global_position.x)
				_flight_z.append(shell.global_position.z)
				_flight_dir_x.append(direction.x)
				_flight_dir_z.append(direction.y)
				_flight_vx.append(shell.direction.x * shell.speed)
				_flight_vz.append(shell.direction.z * shell.speed)
				_flight_reach.append(shell.remaining_range())
				_flight_shooter.append(shell.shooter_name)
	return {"x": _flight_x, "z": _flight_z, "dir_x": _flight_dir_x, "dir_z": _flight_dir_z, "vx": _flight_vx,
			"vz": _flight_vz, "reach": _flight_reach, "shooter": _flight_shooter}


## Living tanks of `team` as {"name", "position", "squad"}, by name, once per tick. Shared: never modify.
static func allies(game_match: Match, team: int) -> Array:
	_refresh(game_match)
	return _allies[team]


## OrderFeed.source / ElementFeed.source, resolved once per tick for all brains instead of once per brain per tick
## (round-5 X1: a property probe and a meta lookup each, 60 times a tick).
static var _sources_tick := -1
static var _sources_match := 0
static var _order_source: Object = null
static var _element_source: Object = null


static func _resolve_sources(game_match: Match) -> void:
	if _sources_match == game_match.get_instance_id() and _sources_tick == game_match.tick:
		return
	_sources_match = game_match.get_instance_id()
	_sources_tick = game_match.tick
	_order_source = OrderFeed.source(game_match)
	_element_source = ElementFeed.source(game_match)


static func order_source(game_match: Match) -> Object:
	_resolve_sources(game_match)
	return _order_source


static func element_source(game_match: Match) -> Object:
	_resolve_sources(game_match)
	return _element_source


## allies() as typed columns [x, z, names] in the same order. Shared: never modify.
static func ally_columns(game_match: Match, team: int) -> Array:
	_refresh(game_match)
	return [_ally_x[team], _ally_z[team], _ally_names[team]]


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


## `team`'s intel as the shared half of a brain contact entry, once per intel refresh: everything that doesn't depend
## on which of our tanks is looking. A brain duplicates its entry and fills in `age` and the five fields that need its
## own position. `reload_windows` is a per-team brain feature, so `gun_ready_in` belongs here too.
## Shared: duplicate before modifying.
static func contact_prototypes(game_match: Match, team: int) -> Dictionary:
	var bucket := game_match.tick / Match.INTEL_EVERY_TICKS
	if _contacts_bucket != bucket or _match_id != game_match.get_instance_id():
		_refresh(game_match)
		_contacts_bucket = bucket
		for side in 2:
			var reload_windows: bool = BrainVariants.for_team(side).get("reload_windows", false)
			var table := {}
			var intel: Dictionary = game_match.intel[side]
			for contact_name: String in intel_names(game_match, side):
				var known: Dictionary = intel[contact_name]
				var weapon_id := String(known["weapon"])
				table[contact_name] = {
					"name": contact_name,
					"position": known["position"],
					"velocity": known["velocity"],
					"forward": known["forward"],
					"health": known["health"],
					"shield": known.get("shield", 0),
					"weapon": weapon_id,
					"unit": known.get("unit", ""),
					"turret_forward": known["turret_forward"],
					"visible": known["visible"],
					"seen_tick": int(known["seen_tick"]),
					# X3 reload windows: seconds until its gun is loaded again (0 when loaded, unknown, or fast).
					"gun_ready_in": _gun_ready_in(game_match, contact_name) if reload_windows else 0.0,
					# Saves a Weapons.PROFILES lookup per brain per contact ("can it reach me").
					"weapon_range": float(Weapons.profile(weapon_id)["range"]),
					# L2 (X3): how hard a crew has its head down. Plainly visible behaviour, so it is read live for a
					# contact we can actually see and left at 0 for one we are only remembering. (Combat's intel
					# doesn't carry it; ai asked for it there — see the stream's requests.)
					"suppression": _suppression_of(game_match, contact_name) if bool(known["visible"]) else 0.0,
					# Filled in per brain (they need the looker's position): age, exposed_face, facing_ally,
					# aiming_at_me, watching_me, threatens_me.
					"age": 0,
				}
			_contacts[side] = table
	return _contacts[team]


static func _suppression_of(game_match: Match, contact_name: String) -> float:
	var enemy := tanks_by_name(game_match).get(contact_name) as Tank
	return 0.0 if enemy == null else SuppressionFeed.of(enemy)


static func _gun_ready_in(game_match: Match, contact_name: String) -> float:
	var enemy := tanks_by_name(game_match).get(contact_name) as Tank
	if enemy == null or float(enemy.weapon.get("reload", 0.0)) < TankBrain.SLOW_GUN_RELOAD:
		return 0.0
	return gun_ready_in(game_match, enemy)


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


## enemies() with positions as typed columns: [tanks, x, y, z]. Shared: never modify.
static func enemy_columns(game_match: Match, team: int) -> Array:
	_refresh(game_match)
	return _enemy_columns[team]


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
