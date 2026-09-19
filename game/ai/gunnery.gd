class_name Gunnery
extends RefCounted
## The firing half of a unit's standing orders: when a gun may speak (round 6, split out of OrderController by nav at
## combat's request). **Combat owns this file** (contract N5: the engagement envelope, game/combat/engagement.gd);
## nav owns the composer that calls it and the movement half beside it (game/ai/movement.gd).
##
## The seam, as combat specified it: one instance per OrderController (mirroring Movement); the composer calls
## `apply(cmd, seconds)` AFTER the movement half; it reads the controller for exactly four things — `tank`,
## `tanks_root`, `weapon_order`, and `move_order["type"]` (so a fixed-mount hull swings onto its target when halted) —
## and is handed SECONDS of game time, never a tick count (the acquisition timer is booked in seconds and must survive
## a tick-rate change; orchestration.md lesson 30). The weapon orders themselves are documented in OrderController.
##
## The public state below (engaged_target, watch_point, spotter, engagement_lay, ticks_since_fire, lane_blocked_ticks,
## lane_blocker, hold_for_friends) is also readable and writable on the controller, which forwards it here, so brains,
## the bridge and the HUD read it where they always did.

## Fire only when the turret is within this angle of the lead point.
const AIM_TOLERANCE_DEG := 2.5
## At or below this fraction of a full ammo load, only fire inside the weapon's preferred range.
const LOW_AMMO_FRACTION := 0.3
## A held turret heading aims at a point this far out along it.
const HELD_AIM_DISTANCE := 1000.0
## fire_at_will (and target fallbacks) look for the nearest shootable enemy this often, keeping a still
## shootable pick in between: the per-tick scan of every enemy was a top AI cost at 50 units.
const SCAN_EVERY_TICKS := SimClock.TICK_RATE / 10
## A blocked lane is re-checked only every this many ticks (a friend doesn't clear a lane in one tick).
const LANE_RECHECK_TICKS := maxi(1, (SimClock.TICK_RATE + 10) / 20)  # ~20 Hz, rounded to whole ticks

## The composer (an OrderController, or a TankBrain).
var ctl: OrderController

## Name of the tank currently being engaged ("" if none). For observation/debugging.
var engaged_target := ""
## World point the turret covers while nothing is engaged (null = hold the current heading).
var watch_point: Variant = null
## Indirect weapons (ARC) may shoot at any enemy this returns true for. Brains set it to "my TEAM
## sees it" (spotting); by default it's the tank's own line of sight.
## N5 (round 6): direct fire reads it too, as gate 1 of the engagement envelope.
var spotter: Callable
## N5 (round 6, CP4): this gun's lay on the contact it is engaging — the acquisition timer and the fire-discipline
## hysteresis (game/combat/engagement.gd); fed the target the weapon scan already picked, so it costs no extra raycast.
var engagement_lay := Engagement.Lay.new()
## Ticks since this unit last pulled the trigger. Brains time out fights with it.
var ticks_since_fire := 0
## A4 fire discipline: consecutive ticks the gun was ready and aimed but held because a friend was in the line
## of fire (or the splash), and which friend. Brains read it to move and clear the lane.
var lane_blocked_ticks := 0
var lane_blocker := ""
## Brain variants can turn the friendly-fire gate off (BrainVariants "hold_for_friends").
var hold_for_friends := true

## Flat world direction the turret holds when it has nothing to aim at (ZERO = not set yet).
var _held_aim := Vector3.ZERO
var _scan_pick: Tank = null
var _scan_left := 0
var _lane_hold_left := 0
## Seconds of game time the current apply() covers (one tick, or a whole controller stride).
var _seconds := 0.0

## The four things read from the composer, by name, so the rules below read as they always did.
var tank: Tank:
	get:
		return ctl.tank
var tanks_root: Node:
	get:
		return ctl.tanks_root
var weapon_order: Dictionary:
	get:
		return ctl.weapon_order
var move_order: Dictionary:
	get:
		return ctl.move_order
## Ticks the current run covers (counters that count ticks add it; see OrderController._step).
var _step: int:
	get:
		return ctl._step


func _init(controller: OrderController = null) -> void:
	ctl = controller


## Where the turret points before anything is decided this tick: along its held heading, far away so the tank's own
## movement doesn't swing the aim (parallax).
func held_aim_point() -> Vector3:
	if _held_aim == Vector3.ZERO:
		_held_aim = tank.turret_forward()
	return tank.global_position + _held_aim * HELD_AIM_DISTANCE


## The crew is dead: nothing engaged, and a respawned crew starts its lay from scratch (N5).
func dead() -> void:
	engaged_target = ""
	_held_aim = Vector3.ZERO
	engagement_lay.forget()


## One run of the gun: aim and (maybe) fire into `cmd`. `seconds` is the game time this run covers.
func apply(cmd: TankCommand, seconds: float) -> void:
	_seconds = seconds
	ticks_since_fire += _step
	_apply_weapon(cmd)
	if cmd.fire:
		ticks_since_fire = 0


## Seconds of GAME time this run covers: one tick, or the whole stride when this unit executes at a lower rate.
## Booked in seconds, never in ticks (orchestration.md lesson 30), and never from the wall clock (determinism.md).
func _seconds_step() -> float:
	return _seconds


func _apply_weapon(cmd: TankCommand) -> void:
	engaged_target = ""
	var lap := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var target: Tank = null
	if tank.weapon["kind"] == Weapons.Kind.ARC:
		_apply_indirect(cmd)
		return
	match weapon_order["type"]:
		"aim":
			_cover(Vector3(weapon_order["x"], 0.0, weapon_order["z"]), cmd)
			return
		"suppress":
			_apply_suppress(cmd)
			return
		"fire_at_will":
			if tanks_root != null:
				target = _scanned_shootable()
		"target":
			if tanks_root != null:
				var named := _named_tank(String(weapon_order["name"]))
				if named != null and named.is_alive() and named.team != tank.team and _shootable(named):
					target = named
				elif weapon_order.get("fallback", false):
					target = _scanned_shootable()
	lap = OrderController._lap("weapon.scan", lap)
	if target == null:
		# N5: nothing to lay on — the gunner's lay on the last contact bleeds off (it is not wiped, so a target that
		# ducks behind a crate for a moment is re-acquired from where he left it).
		engagement_lay.lose(_seconds_step())
		if watch_point != null:
			_cover((watch_point as Vector3), cmd)
		return

	engaged_target = target.name
	var weapon := tank.weapon
	var muzzle := tank.turret.global_position
	var aim := target.global_position
	if weapon["kind"] == Weapons.Kind.PROJECTILE:
		# K2 weapon profile v3: each weapon's own round speed (a 25 mm round flies far faster than a tank shell).
		var round_speed := float(weapon.get("projectile_speed_mps", 0.0))
		aim = Ballistics.lead_point(muzzle, target.global_position, target.estimated_velocity,
				round_speed if round_speed > 0.0 else Shell.SPEED)
	var brain := ctl as TankBrain
	if brain != null and brain.game_match != null:
		aim += Difficulty.aim_offset(float(Difficulty.for_team(tank.team)["aim_wander_m"]), brain.game_match.tick, tank.slot)
	_cover(aim, cmd)
	# Rules R2 (minimal hook; the ai stream owns the real behavior): a fixed-mount gun (the scout) only
	# points inside its fire arc, so a halted unit swings its hull onto the target.
	if tank.mount == "fixed" and move_order["type"] == "stop":
		cmd.turn = Steering.drive_toward(tank.global_position, -tank.global_basis.z, aim, 0.0).y
	var distance := muzzle.distance_to(aim)
	var in_range: bool = distance <= float(weapon["range"])
	# G7 ammo discipline: with few shells left, skip long-odds shots (spread makes them mostly miss).
	if tank.ammo_fraction() <= LOW_AMMO_FRACTION and distance > float(weapon["preferred_max"]):
		in_range = false
	var aimed: bool = Ballistics.aim_error(muzzle, tank.turret_forward(), aim) <= deg_to_rad(float(weapon["aim_tolerance_deg"]))
	lap = OrderController._lap("weapon.aim", lap)
	# N5 (round 6, CP4): gates 2 and 3 — the crew must have HELD this contact long enough, and the range must be one
	# where the round is worth firing, unless a commander named the target or this crew is already being shot at
	# (game/combat/engagement.gd). Hull to hull, not muzzle to lead point: the envelope is about where the two vehicles
	# stand, not where the gunner is aiming.
	var envelope := engagement_lay.engage(tank, target,
			tank.global_position.distance_to(target.global_position), _seconds_step(),
			bool(weapon_order.get("long_shot", false)))
	cmd.fire = _clear_to_fire(envelope and in_range and aimed and tank.ready_to_fire(), aim)
	OrderController._lap("weapon.lanes", lap)


## L2 (X3): fire at a piece of ground. No target, no lead, no line-of-sight-to-an-enemy check — just the gun on the
## spot and rounds going down it while it is in range and the lane is clear of friendlies. A fixed mount swings the
## hull onto it like it would onto a target.
func _apply_suppress(cmd: TankCommand) -> void:
	var aim := Vector3(weapon_order["x"], 0.0, weapon_order["z"])
	aim.y = tank.turret.global_position.y
	_cover(aim, cmd)
	if tank.mount == "fixed" and move_order["type"] == "stop":
		cmd.turn = Steering.drive_toward(tank.global_position, -tank.global_basis.z, aim, 0.0).y
	var muzzle := tank.turret.global_position
	var in_range: bool = muzzle.distance_to(aim) <= float(tank.weapon["range"])
	# Suppressing is worth rounds, not the last of them: a unit low on ammo saves them for something it can kill.
	if tank.ammo_fraction() >= 0.0 and tank.ammo_fraction() <= LOW_AMMO_FRACTION:
		in_range = false
	var aimed: bool = Ballistics.aim_error(muzzle, tank.turret_forward(), aim) <= deg_to_rad(float(tank.weapon["aim_tolerance_deg"]))
	cmd.fire = _clear_to_fire(in_range and aimed and tank.ready_to_fire(), aim)


## Direct fire needs a clear line of sight from this tank AND the target being seen: by the team when a
## spotter is set (brains: a scout's sight lets a tank use its full gun range), else by this tank.
func _shootable(enemy: Tank) -> bool:
	if tank.global_position.distance_to(enemy.global_position) > float(tank.weapon["range"]):
		return false
	# N5 (round 6, CP4): gate 1 of the engagement envelope. Round 5 found this `seen` test computed here and thrown
	# away, so "shootable" had only ever meant "in range with a clear line" — a gun reaching past the eyes that aim it,
	# which is the mechanism behind the lead's "units see each other and then everyone just starts firing". It is back,
	# deliberately, and it goes BEFORE the raycast: a dictionary lookup that rejects a contact saves the ray.
	if not Engagement.is_seen(tank, enemy, spotter):
		return false
	# X2 measured, and rejected: answering this with the memoized 2D cover map instead of a physics ray made picking a
	# target *slower* at 60 units (650 usec per tick against 573). The two agree (139 of 139 lines, test_ai_cover_map),
	# but with a memo this big a hit costs about as much as the ray it saves.
	return Perception.has_line_of_sight(tank, enemy)


## _nearest_shootable(), re-scanned every SCAN_EVERY_TICKS while the last pick is still shootable (a nearer enemy
## may have appeared), and every tick while there's nothing to shoot (a delay there leaves loaded guns idle).
func _scanned_shootable() -> Tank:
	_scan_left -= _step
	var pick_alive := _scan_pick != null and is_instance_valid(_scan_pick) and _scan_pick.is_alive()
	# X2, order execution at a lower rate for units that aren't firing: a gun that is still reloading cannot shoot
	# anything, so neither re-picking a target nor re-testing the sight line to the current one buys anything this
	# tick. The turret keeps tracking the pick meanwhile. The moment the gun IS loaded the line is tested again
	# below, so a shot is never taken at something this tank cannot see. At 60 tanks on 5 s cannons this was the
	# single biggest cost of executing orders: a physics ray per unit per tick, plus a full scan every 6.
	if pick_alive and not tank.ready_to_fire():
		if _scan_left <= 0:
			_scan_left = SCAN_EVERY_TICKS
		return _scan_pick
	if _scan_left > 0 and pick_alive and _shootable(_scan_pick):
		return _scan_pick
	_scan_left = SCAN_EVERY_TICKS
	_scan_pick = _nearest_shootable()
	return _scan_pick


## The nearest shootable enemy, preferring the current weapon order's sector of fire (X1) when it has one: a unit in
## a formation covers its own arc, so the element sees all round instead of every gun swinging onto one target.
func _nearest_shootable() -> Tank:
	var best: Tank = null
	var best_distance := INF
	var in_sector: Tank = null
	var in_sector_distance := INF
	var sector := Vector3.ZERO
	var sector_cos := -1.0
	var facing: Variant = weapon_order.get("sector")
	if facing != null:
		var point: Variant = OrderFeed.point(facing)
		if point != null and (point as Vector3).length_squared() > 0.0001:
			sector = (point as Vector3).normalized()
			sector_cos = float(weapon_order.get("sector_cos", 0.5))
	var brain := ctl as TankBrain
	var columns: Array = AiTickCache.enemy_columns(brain.game_match, tank.team) \
			if brain != null and brain.game_match != null and brain.game_match.tanks == tanks_root else []
	var enemies: Array = columns[0] if not columns.is_empty() else _enemies()
	var here := tank.global_position
	var reach := float(tank.weapon["range"])
	for index in enemies.size():
		var enemy: Tank = enemies[index]
		# Round-5 X1: positions from the tick's typed columns (the same values), and nothing out of range is looked at
		# further (_shootable's own first test, answered without touching the node).
		var there := Vector3((columns[1] as PackedFloat32Array)[index], (columns[2] as PackedFloat32Array)[index],
				(columns[3] as PackedFloat32Array)[index]) if not columns.is_empty() else enemy.global_position
		var distance := here.distance_to(there)
		if distance >= best_distance and (sector == Vector3.ZERO or distance >= in_sector_distance):
			continue
		if distance > reach or not _shootable(enemy):
			continue
		if distance < best_distance:
			best = enemy
			best_distance = distance
		if sector != Vector3.ZERO and distance < in_sector_distance:
			var toward := there - here
			toward.y = 0.0
			if toward.length_squared() > 0.01 and toward.normalized().dot(sector) >= sector_cos:
				in_sector = enemy
				in_sector_distance = distance
	return in_sector if in_sector != null else best


## A tank by name: the brains' shared per-tick table (no NodePath parsing every tick), else a node lookup.
func _named_tank(tank_name: String) -> Tank:
	var brain := ctl as TankBrain
	if brain != null and brain.game_match != null and brain.game_match.tanks == tanks_root:
		return AiTickCache.tanks_by_name(brain.game_match).get(tank_name) as Tank
	return tanks_root.get_node_or_null(NodePath(tank_name)) as Tank


## Living enemies in scene order: shared per tick for brains (AiTickCache), scanned otherwise.
func _enemies() -> Array:
	var brain := ctl as TankBrain
	if brain != null and brain.game_match != null and brain.game_match.tanks == tanks_root:
		return AiTickCache.enemies(brain.game_match, tank.team)
	return Perception.enemies_of(tank, tanks_root)


## ARC weapons: lob at a spotted enemy inside the [min_range, range] window, leading it by the flight time.
func _apply_indirect(cmd: TankCommand) -> void:
	if tanks_root == null or weapon_order["type"] in ["hold_fire", "aim"]:
		if weapon_order["type"] == "aim":
			_cover(Vector3(weapon_order["x"], 0.0, weapon_order["z"]), cmd)
		elif watch_point != null:
			_cover(watch_point as Vector3, cmd)
		return
	var weapon := tank.weapon
	var sees: Callable = spotter if spotter.is_valid() else func(other: Tank) -> bool: return Perception.has_line_of_sight(tank, other)
	var in_window := func(other: Tank) -> bool:
		var d := tank.global_position.distance_to(other.global_position)
		return d >= float(weapon["min_range"]) and d <= float(weapon["range"])
	var target: Tank = null
	if weapon_order["type"] == "target":
		var named := _named_tank(String(weapon_order["name"]))
		if named != null and named.is_alive() and named.team != tank.team and sees.call(named) and in_window.call(named):
			target = named
	if target == null and (weapon_order["type"] == "fire_at_will" or weapon_order.get("fallback", false)):
		var best_distance := INF
		for enemy: Tank in _enemies():
			var d := tank.global_position.distance_to(enemy.global_position)
			if d < best_distance and in_window.call(enemy) and sees.call(enemy):
				best_distance = d
				target = enemy
	if target == null:
		engaged_target = ""
		if watch_point != null:
			_cover(watch_point as Vector3, cmd)
		return
	engaged_target = target.name
	var flight := tank.global_position.distance_to(target.global_position) / float(weapon["flight_speed"])
	var aim := target.global_position + target.estimated_velocity * flight
	_cover(aim, cmd)
	var aimed: bool = Ballistics.aim_error(tank.turret.global_position, tank.turret_forward(), aim) <= deg_to_rad(float(weapon["aim_tolerance_deg"]))
	cmd.fire = _clear_to_fire(aimed and tank.ready_to_fire(), aim)


## A4: the last gate before the trigger. A shot that would pass through (or splash) a friend is held, and
## counted in lane_blocked_ticks. Only checked when the gun would otherwise fire, so it costs one check per
## reload, not per tick.
func _clear_to_fire(would_fire: bool, aim: Vector3) -> bool:
	if not would_fire:
		return false
	if not hold_for_friends:
		return true
	if _lane_hold_left > 0:
		_lane_hold_left -= _step
		lane_blocked_ticks += _step
		OrderController.held_for_friends += 1
		return false
	var blockers := FireLanes.for_shot(tanks_root, tank, aim)
	if blockers.is_empty():
		lane_blocked_ticks = 0
		lane_blocker = ""
		return true
	lane_blocked_ticks += _step
	lane_blocker = String(blockers[0])
	OrderController.held_for_friends += 1
	_lane_hold_left = LANE_RECHECK_TICKS - 1
	return false


## Point the turret at a world spot, and remember that heading for when the spot is gone.
func _cover(point: Vector3, cmd: TankCommand) -> void:
	cmd.aim_point = point
	var flat := Vector3(point.x - tank.global_position.x, 0.0, point.z - tank.global_position.z)
	if flat.length_squared() > 0.25:
		_held_aim = flat.normalized()
