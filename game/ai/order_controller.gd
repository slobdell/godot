class_name OrderController
extends Node
## Executes STANDING ORDERS for one tank by producing a TankCommand every tick.
##
## This is layer 2 ("Actions") of _agents/squad_ai_design.md. Something slower
## decides the orders; this node carries them out 60 times a second:
##   BotController (server bots)   a tiny built-in policy picks orders
##   AgentBridge   (a client)      Claude picks orders over HTTP (_agents/agent_bridge.md)
##
## Move orders (one at a time):
##   {"type": "stop"}
##   {"type": "move_to", "x": float, "z": float, "reverse": bool (optional), "speed": 0.2..1 (optional),
##    "arrive": 0.5..10 meters (optional, default ARRIVE_RADIUS)}
##       reverse = back up to the point, front armor kept toward where you came from
##       arrive = how close counts as there (brains use ~1 m for hide and peek spots)
##       direct = true: steer straight at the point, no navmesh path (brains' short, already-checked hops)
##   {"type": "drive", "throttle": float, "turn": float, "seconds": float}
##   {"type": "face", "x": float, "z": float}   turn in place to point the hull (front armor) at a spot
## Weapon orders (one at a time):
##   {"type": "hold_fire"}                      keep the turret where it is
##   {"type": "aim", "x": float, "z": float}    point the turret, don't fire
##   {"type": "fire_at_will"}                   engage the nearest visible enemy
##       optional "sector": [x, z] + "sector_cos": float — a sector of fire (X1, contract L1): enemies inside the
##       sector are engaged first, and one outside it only when the sector is empty (cover your arc, never idle)
##   {"type": "suppress", "x": float, "z": float}
##       L2 (X3): put fire ON A PIECE OF GROUND — a lane, a doorway, the cover an enemy is behind — whether or not
##       anything is standing there. This is what makes suppression a decision instead of a side effect: a machine gun
##       holding a crossing stops an advance without killing anyone. Fire discipline still applies (never through a
##       friendly), and the point must be inside the weapon's range.
##   {"type": "target", "name": String, "fallback": bool (optional)}
##       engage one specific tank when visible; with fallback, shoot the nearest visible
##       enemy meanwhile (brains use this: team intel can pick a target this tank can't see)
## Reflexes (up to MAX_REFLEXES, checked every tick BEFORE orders execute). Each
## fires once, then re-arms when its condition clears. They let a slow commander
## pre-decide "if X happens, do Y" (playtest #1), and they're the smallest version
## of doctrine *phases* (_agents/squad_ai_design.md, layer 4):
##   {"type": "retreat_below_hp", "hp": int, "x": float, "z": float, "reverse": bool (default true)}
##       health < hp → move_to (x, z), backing away with the front armor forward unless reverse=false
##   {"type": "halt_on_contact"}   an enemy comes into sight during a move_to → stop and fight
## Orders and reflexes persist through death and respawn.
##
## TURRET (G5): the turret is independent of the hull. With no target to engage it covers
## `watch_point` (a known threat; brains set it from team intel), or else holds its
## world-space heading, so turning or retreating never drags the gun off the fight.

const ARRIVE_RADIUS := 3.0
## Advance to the next path waypoint within this distance of the current one.
const WAYPOINT_RADIUS := 2.5
## Recompute the path this often even if the goal hasn't moved (other tanks move).
const REPATH_SECONDS := 1.0
## Fire only when the turret is within this angle of the lead point.
const AIM_TOLERANCE_DEG := 2.5
## Driving at >50% throttle but moving slower than this for STUCK_SECONDS = stuck.
const STUCK_SPEED := 0.8
const STUCK_SECONDS := 1.0
const UNSTICK_SECONDS := 0.9
const MOVE_TYPES := ["stop", "move_to", "drive", "face"]
const WEAPON_TYPES := ["hold_fire", "aim", "fire_at_will", "target", "suppress"]
const REFLEX_TYPES := ["retreat_below_hp", "halt_on_contact"]
const MAX_REFLEXES := 4
const MAX_EVENTS := 8
## At or below this fraction of a full ammo load, only fire inside the weapon's preferred range.
const LOW_AMMO_FRACTION := 0.3
## A held turret heading aims at a point this far out along it.
const HELD_AIM_DISTANCE := 1000.0
## fire_at_will (and target fallbacks) look for the nearest shootable enemy this often, keeping a still
## shootable pick in between: the per-tick scan of every enemy was a top AI cost at 50 units.
const SCAN_EVERY_TICKS := SimClock.TICK_RATE / 10

## Measurement only (scenarios): how many ticks a unit was steered off its route by a wall of bullets, and how often
## it looked and found no way round. Never read by decisions.
static var fire_detours := 0
static var fire_no_way_round := 0

## Measurement only (make ai-perf): microseconds spent in think + compute_command while `profiling` is on.
## Never read by decisions.
static var profiling := false
static var profile_usec := 0
## ...and `profile_detail` (--profile-parts) adds the finer laps inside moving and shooting. They cost about 190 usec
## per tick at 60 units in clock calls alone, so they are off by default: the headline ai_usec_per_tick must measure
## the AI, not the measuring.
static var profile_detail := false
## Measurement only: controller ticks that steered from scratch vs held last tick's steering (execution LOD).
static var executed_full := 0
static var executed_held := 0

@export var tank: Tank
## Where to look for other tanks (Match/Tanks).
var tanks_root: Node

var move_order := {"type": "stop"}
var weapon_order := {"type": "hold_fire"}
## Name of the tank currently being engaged ("" if none). For observation/debugging.
var engaged_target := ""
var visible_enemy_names: PackedStringArray = []
var reflexes: Array = []
## World point the turret covers while nothing is engaged (null = hold the current heading).
var watch_point: Variant = null
## Indirect weapons (ARC) may shoot at any enemy this returns true for. Brains set it to "my TEAM
## sees it" (spotting); by default it's the tank's own line of sight.
var spotter: Callable
## Recent notable happenings (reflexes firing), newest last. For observers like the bridge.
var events: PackedStringArray = []

## X3: the sidestep being driven right now (null = none) and the tick it gives up at.
var _fire_detour: Variant = null
var _fire_detour_until := 0
var _fire_detour_since := -1000
var _fire_detour_again := 0
## The tick this unit started going round the current wall of bullets (-1 = it isn't).
var _fire_since := -1
## The L2 source for this match, resolved once (asking "do you answer L2" per move per tick is not free).
var _fields: Object = null
var _fields_match := 0
var _reflex_armed: Array[bool] = []
## Flat world direction the turret holds when it has nothing to aim at (ZERO = not set yet).
var _held_aim := Vector3.ZERO

var _drive_elapsed := 0.0
var _path := PackedVector3Array()
var _path_index := 0
var _path_goal := Vector3.INF
var _repath_left := 0.0
var _stuck_time := 0.0
var _unstick_left := 0.0
var _scan_pick: Tank = null
var _scan_left := 0
## Stuck detection (round-3 X1): consecutive ticks a move_to made no progress toward its goal (0 while arrived or not
## driving to a point), and ticks since this unit last pulled the trigger. Brains time out options with them.
var stalled_ticks := 0
## _wheel_radius() per unit type (the catalog doesn't change mid-match).
var _wheel_radius_unit := ""
var _wheel_radius_value := 0.0
var ticks_since_fire := 0
var _progress_goal := Vector3.INF
var _progress_best := INF

## A4 fire discipline: consecutive ticks the gun was ready and aimed but held because a friend was in the line
## of fire (or the splash), and which friend. Brains read it to move and clear the lane.
var lane_blocked_ticks := 0
var lane_blocker := ""
## Brain variants can turn the friendly-fire gate off (BrainVariants "hold_for_friends").
var hold_for_friends := true
## Measurement (not decisions): shots held for friends, by every controller since the process started.
static var held_for_friends := 0
## A blocked lane is re-checked only every this many ticks (a friend doesn't clear a lane in one tick).
const LANE_RECHECK_TICKS := maxi(1, (SimClock.TICK_RATE + 10) / 20)  # ~20 Hz, rounded to whole ticks
## Local avoidance of friends in the way (see _around_friends), meters.
## X3 (L2): how far ahead a route is checked for a wall of bullets (meters). Far enough to see one coming: checking
## only the next navmesh waypoint is a few metres, by which time the unit is already in it.
const FIRE_LOOKAHEAD := 34.0
## ...and how far to one side the route can step (meters). All of them are scored; the least-swept wins.
const FIRE_DETOUR_STEPS: Array[float] = [12.0, 24.0, 36.0]
## A sidestep has to be this much safer than carrying straight on before it is worth taking, so a unit doesn't weave
## over a rounding error.
const FIRE_DETOUR_MARGIN := 0.75
## A sidestep is DRIVEN, not re-decided every tick: re-deciding just wobbles along the edge of the fire (measured: 4 m
## off the straight line, and longer in the beaten zone than going straight). It is held until it is reached, or the
## route on is clear, or this many ticks pass.
const FIRE_DETOUR_TICKS := SimClock.TICK_RATE * 2
const FIRE_DETOUR_REACHED := 5.0
## Reaching a step is not "I tried and it didn't work" — it is the step working, so the unit looks again and steps
## again if the way on is still swept. What bounds the whole business is this: once a unit has been going round for
## this long without the fire lifting, it has spent enough and pushes on. Orders win in the end.
const FIRE_AVOID_MAX := SimClock.TICK_RATE * 5
## ...and then the unit pushes on for this long before it looks for a way round again. It only has to be long enough
## to stop the search running on every check tick: FIRE_AVOID_MAX below is what actually guarantees a unit arrives.
## It used to be 240, which swallowed four seconds of a seven-second crossing and made the whole behaviour measure as
## nothing (28 ticks in the beaten zone against a control's 33, where a working version manages 14).
const FIRE_DETOUR_COOLDOWN := SimClock.TICK_RATE
## Going round is ENTERED on `is_beaten_zone` (a hard threshold) but KEPT while the route still carries this share of
## that much fire on average. Without the hysteresis a unit abandons its detour the moment the field dips under the
## threshold between two bursts — and a beaten zone pulses, because the field has a ~1 s half-life and guns fire in
## bursts. That cost the whole behaviour once combat's suppression rework made the field denser and burstier: one
## attempt, three ticks, then the cooldown below and a walk straight through the fire.
const FIRE_KEEP_SHARE := 0.4
## The route is re-checked against the field this often (ticks, staggered per unit) rather than every tick. A detour
## already being driven is re-checked every tick regardless. This is not only a cost knob — it sets how many chances a
## unit gets to notice a wall of bullets while there is still room to go round, and it was measured, in the swept-lane
## scenario (ticks spent in the beaten zone against a control's 33) and with `make ai-perf UNITS=60`:
##     every tick   21 ticks in the fire, 4740 usec        every 3   10 ticks, 4231 usec        every 6   28 ticks
## Three is both the best behaviour and cheaper than one. Six was chosen as a pure cost cut during X2 and quietly cost
## most of the avoidance — a reminder to measure what an optimisation does to behaviour, not just to the clock.
const FIRE_CHECK_TICKS := maxi(1, (SimClock.TICK_RATE + 10) / 20)  # ~20 Hz, rounded to whole ticks
## A step round the fire is kept this long even if the fire seems to lift. A beaten zone PULSES — rounds arrive in
## bursts and the field decays between them — so a momentary reading below the threshold is not the fire ending. Round
## 5, found at 30 Hz: without this the unit dropped its step every other check and picked the other side next time,
## thrashing on the spot inside the lane instead of crossing it (19 ticks in the beaten zone against a control's 16).
const FIRE_LEG_MIN_TICKS := maxi(1, SimClock.TICK_RATE / 4)
const AVOID_LOOKAHEAD := 10.0
const AVOID_WIDTH := 3.2
const AVOID_CLEARANCE := 5.0
## Wheels move on to the next path waypoint within this share of their turning radius (at least WAYPOINT_RADIUS).
const WHEELS_WAYPOINT_RADII := 0.8
var _lane_hold_left := 0
## Round-5 X1, controller stride (BrainVariants "brain_stride"): a brain runs its whole controller — thinking and
## executing — on every Nth physics tick, staggered by think_offset, and hands the tank its last command in between.
## `_step` is how many ticks the current run covers (counters that count ticks add it), `_last_run_tick` when it last
## ran, `_last_command` what it handed over, and `_fire_checked_tick` when the fire-avoidance check last looked.
var _stride := 1
var _step := 1
var _last_run_tick := -1
var _last_command: TankCommand = null
var _fire_checked_tick := -1000


func _ready() -> void:
	# Lower priority runs first: the command is ready before the tank consumes it.
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	if tank == null or not is_instance_valid(tank):
		return
	var started := Time.get_ticks_usec() if profiling else 0
	var brain := self as TankBrain
	if _stride > 1 and brain != null and brain.game_match != null:
		var tick := brain.game_match.tick
		if _last_command != null and _last_run_tick >= 0 and not brain.wants_to_run() \
				and (tick + brain.think_offset) % _stride != 0:
			# Controller stride (round-5 X1): not this unit's tick. The tank keeps its last command — throttle, turn, aim
			# and trigger — for one more tick; anything that must not wait (a new order, the element leader's call) runs
			# it at once instead (TankBrain.wants_to_run).
			tank.command = _last_command
			if profiling:
				executed_held += 1
				profile_usec += Time.get_ticks_usec() - started
			return
		_step = clampi(tick - _last_run_tick, 1, _stride) if _last_run_tick >= 0 else 1
		_last_run_tick = tick
		delta *= _step
	if profiling:
		executed_full += 1
	think(delta)
	tank.command = compute_command(delta)
	_last_command = tank.command
	if profiling:
		profile_usec += Time.get_ticks_usec() - started


## Subclasses decide orders here (called every tick before orders execute).
func think(_delta: float) -> void:
	pass


## Replace one or both orders. Returns "" on success or a human-readable error.
## Validates everything: orders may come from an external process.
func set_orders(new_move: Variant, new_weapon: Variant, new_reflexes: Variant = null) -> String:
	if new_move != null:
		var error := _validate(new_move, MOVE_TYPES)
		if error != "":
			return "move: " + error
	if new_weapon != null:
		var error := _validate(new_weapon, WEAPON_TYPES)
		if error != "":
			return "weapon: " + error
	if new_reflexes != null:
		if typeof(new_reflexes) != TYPE_ARRAY or new_reflexes.size() > MAX_REFLEXES:
			return "reflexes: must be a list of at most %d reflexes" % MAX_REFLEXES
		for reflex in new_reflexes:
			var error := _validate(reflex, REFLEX_TYPES)
			if error != "":
				return "reflexes: " + error
	if new_reflexes != null:
		reflexes = new_reflexes.duplicate(true)
		_reflex_armed.clear()
		for reflex in reflexes:
			_reflex_armed.append(true)
	if new_move != null:
		move_order = new_move
		_drive_elapsed = 0.0
		_repath_left = 0.0
	if new_weapon != null:
		weapon_order = new_weapon
	return ""


func compute_command(delta: float) -> TankCommand:
	if not tank.is_alive():
		engaged_target = ""
		_held_aim = Vector3.ZERO
		return TankCommand.new(0.0, 0.0, tank.global_position + tank.turret_forward() * HELD_AIM_DISTANCE)
	if _held_aim == Vector3.ZERO:
		_held_aim = tank.turret_forward()
	# Far away, so the tank's own movement doesn't swing the aim (parallax).
	var cmd := TankCommand.new(0.0, 0.0, tank.global_position + _held_aim * HELD_AIM_DISTANCE)
	ticks_since_fire += _step
	var clock := Time.get_ticks_usec() if profile_detail else 0
	_sense()
	_apply_reflexes()
	clock = _lap("c.reflexes", clock)
	clock = Time.get_ticks_usec() if profiling else 0
	_apply_move(cmd, delta)
	_apply_unstick(cmd, delta)
	if profiling:
		TankBrain.profile_parts["move"] = int(TankBrain.profile_parts.get("move", 0)) + Time.get_ticks_usec() - clock
		clock = Time.get_ticks_usec()
	_apply_weapon(cmd)
	if profiling:
		TankBrain.profile_parts["weapon"] = int(TankBrain.profile_parts.get("weapon", 0)) + Time.get_ticks_usec() - clock
	if cmd.fire:
		ticks_since_fire = 0
	return cmd


## A new order from the player: drop the unstick routine, the old path, and stall bookkeeping, so the new order
## drives this very tick (K1 response guarantee).
func interrupt() -> void:
	_fire_detour = null
	_fire_detour_again = 0
	_fire_since = -1
	_unstick_left = 0.0
	_stuck_time = 0.0
	_repath_left = 0.0
	stalled_ticks = 0
	_progress_goal = Vector3.INF


## Measurement only (make ai-perf): add the microseconds since `since` to a profile part, and return the clock now.
static func _lap(part: String, since: int) -> int:
	if not profile_detail:
		return 0
	var now := Time.get_ticks_usec()
	TankBrain.profile_parts[part] = int(TankBrain.profile_parts.get(part, 0)) + now - since
	return now


func _sense() -> void:
	visible_enemy_names = PackedStringArray()
	# Only halt_on_contact reads what this tank sees; skipping the sight rays otherwise was the biggest
	# single AI cost at 50 units (_agents/unit_ai.md "Results").
	if tanks_root == null or reflexes.is_empty():
		return
	var halts := false
	for reflex: Dictionary in reflexes:
		halts = halts or reflex["type"] == "halt_on_contact"
	if not halts:
		return
	for enemy in Perception.enemies_of(tank, tanks_root):
		# G1: a tank sees within its sight radius, and only with a clear line of sight.
		if tank.global_position.distance_to(enemy.global_position) <= tank.sight_radius \
				and Perception.has_line_of_sight(tank, enemy):
			visible_enemy_names.append(enemy.name)


func _apply_reflexes() -> void:
	for i in reflexes.size():
		var reflex: Dictionary = reflexes[i]
		var triggered := false
		match reflex["type"]:
			"retreat_below_hp":
				triggered = tank.sync_health < int(reflex["hp"])
			"halt_on_contact":
				triggered = move_order["type"] == "move_to" and not visible_enemy_names.is_empty()
		if not triggered:
			_reflex_armed[i] = true  # condition cleared: ready to fire again next time
			continue
		if not _reflex_armed[i]:
			continue
		_reflex_armed[i] = false
		match reflex["type"]:
			"retreat_below_hp":
				var reverse: bool = reflex.get("reverse", true)
				move_order = {"type": "move_to", "x": reflex["x"], "z": reflex["z"], "reverse": reverse}
				_repath_left = 0.0
				_log_event("retreat_below_hp: HP %d < %d, %s to (%.0f, %.0f)" % [tank.sync_health,
						int(reflex["hp"]), "backing away" if reverse else "turning to run", reflex["x"], reflex["z"]])
			"halt_on_contact":
				move_order = {"type": "stop"}
				_log_event("halt_on_contact: %s in sight, stopping" % ", ".join(visible_enemy_names))


func _log_event(text: String) -> void:
	events.append("t=%.1fs %s" % [Time.get_ticks_msec() / 1000.0, text])
	if events.size() > MAX_EVENTS:
		events = events.slice(events.size() - MAX_EVENTS)


# ---- Movement ------------------------------------------------------------------------

func _apply_move(cmd: TankCommand, delta: float) -> void:
	if move_order["type"] != "move_to":
		stalled_ticks = 0
	match move_order["type"]:
		"move_to":
			var goal := Vector3(move_order["x"], 0.0, move_order["z"])
			# `direct`: the brain already checked the straight line (CombatMotion's short hops), so skip the navmesh path.
			var direct: bool = move_order.get("direct", false)
			var lap := Time.get_ticks_usec() if profile_detail else 0
			var routed := goal if direct else _next_waypoint(goal, delta)
			lap = _lap("move.path", lap)
			var around_fire := _around_fire(routed, goal)
			lap = _lap("move.fire", lap)
			var waypoint := _around_friends(around_fire)
			lap = _lap("move.friends", lap)
			var arrive := clampf(float(move_order.get("arrive", ARRIVE_RADIUS)), 0.5, 10.0) if waypoint == goal else 0.5
			var remaining := _flat_distance(tank.global_position, goal) if direct else _remaining_path_distance(goal)
			lap = _lap("move.remaining", lap)
			var drive: Vector2
			var radius := _wheel_radius()
			if radius > 0.0:
				# K3 wheels drive like cars: pure pursuit, three-point turns (Steering.drive_toward_wheels).
				# Direct calls rather than a Callable picked every tick (round-5 X1).
				if move_order.get("reverse", false):
					drive = Steering.reverse_toward_wheels(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
				else:
					drive = Steering.drive_toward_wheels(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
			elif move_order.get("reverse", false):
				drive = Steering.reverse_toward(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
			else:
				drive = Steering.drive_toward(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
			cmd.throttle = drive.x * clampf(float(move_order.get("speed", 1.0)), 0.2, 1.0)
			cmd.turn = drive.y
			_track_progress(goal, drive, remaining)
			_lap("move.steer", lap)
		"face":
			var spot := Vector3(move_order["x"], 0.0, move_order["z"])
			var turn_only := Steering.drive_toward(tank.global_position, -tank.global_basis.z, spot, 0.0)
			cmd.turn = turn_only.y if absf(turn_only.y) > 0.08 else 0.0
			if _wheel_radius() > 0.0 and cmd.turn != 0.0 and absf(turn_only.y) >= 1.0:
				# Wheels can't turn standing still: creep round (combat's wheels roll along the arc on a pure turn command).
				cmd.throttle = Steering.WHEELS_MIN_THROTTLE
		"drive":
			_drive_elapsed += delta
			if _drive_elapsed <= float(move_order["seconds"]):
				cmd.throttle = move_order["throttle"]
				cmd.turn = move_order["turn"]
			else:
				move_order = {"type": "stop"}


## X3 (L2): a route through a wall of bullets is stepped around. The lead: *"vehicles make decisions to avoid walking
## into a wall of bullets that will kill them."* Navmesh paths know nothing about fire, and this is where every move
## passes — an order, an element's bound, a drill — so it is the one place that covers all of them. Sides are tried
## nearest first; if every way through is swept it goes anyway, because standing still in the open is worse.
func _around_fire(waypoint: Vector3, goal: Vector3) -> Vector3:
	var brain := self as TankBrain
	if brain == null or brain.game_match == null \
			or not bool(BrainVariants.for_team(tank.team).get("avoid_beaten", true)):
		return waypoint
	# A move that IS the escape (running to cover, breaking contact) is driven as given: re-routing it round the fire
	# is how a hurt tank ends up never reaching the cover it was running to.
	if bool(move_order.get("to_safety", false)):
		return waypoint
	var fields := _suppression_fields(brain.game_match)
	if fields == null:
		return waypoint
	var here := tank.global_position
	var to := Vector3(waypoint.x - here.x, 0.0, waypoint.z - here.z)
	var distance := to.length()
	if distance < 1.0:
		return waypoint
	var direction := to / distance
	var reach := minf(FIRE_LOOKAHEAD, maxf(_flat_distance(here, goal), 1.0))
	var tick := brain.game_match.tick
	if _fire_detour == null:
		# Under execution LOD the check can't wait for an exact multiple of FIRE_CHECK_TICKS (it may be an off tick):
		# it runs on the first executed tick at least FIRE_CHECK_TICKS - 1 after the last one instead.
		if _stride == 1 and (tick + brain.think_offset) % FIRE_CHECK_TICKS != 0:
			return waypoint
		# Under a controller stride the check can't wait for an exact multiple (that tick may not run): it looks on the
		# first run at least FIRE_CHECK_TICKS after the last look.
		if _stride > 1 and tick - _fire_checked_tick < FIRE_CHECK_TICKS:
			return waypoint
		_fire_checked_tick = tick
	var ahead := here + direction * reach
	var ahead_beaten := SuppressionFeed.beaten(fields, tank.team, here, ahead)
	# Already going round. Reaching the step, or spending long enough on it, counts as having tried: push on for a
	# while afterwards so a wall across the whole frontage can't stop a unit forever (orders win in the end). The fire
	# simply lifting is different — carry straight on, with no cooldown, because nothing was spent.
	var still_swept := SuppressionFeed.along(fields, tank.team, here, ahead) >= Match.BEATEN_ZONE_DENSITY * FIRE_KEEP_SHARE
	if _fire_detour != null:
		var leg: Vector3 = _fire_detour
		if not still_swept and tick - _fire_detour_since >= FIRE_LEG_MIN_TICKS:
			_fire_detour = null  # the fire lifted: carry on, nothing spent
			_fire_since = -1
		elif _fire_since >= 0 and tick - _fire_since >= FIRE_AVOID_MAX:
			_fire_detour = null  # long enough: push on
			_fire_since = -1
			_fire_detour_again = tick + FIRE_DETOUR_COOLDOWN
		elif tick >= _fire_detour_until or _flat_distance(here, leg) <= FIRE_DETOUR_REACHED:
			_fire_detour = null  # that step is done; look again below and take another if it is still needed
		else:
			fire_detours += _step
			return leg
	if not still_swept:
		_fire_since = -1
	if not ahead_beaten or tick < _fire_detour_again:
		return waypoint
	var across := Vector3(-direction.z, 0.0, direction.x)
	var limit := Match.DRIVABLE_LIMIT - 4.0
	# The way round is a step SIDEWAYS first, not a shallower line to the same place: a lane swept across your front is
	# crossed by leaving it, then going on. Every step is SCORED rather than tested for being perfectly clear — a
	# beaten zone pulses and its edges are soft, so "is this clear" is the wrong question and "which of these is least
	# swept" is the right one (Match.threat_along exists for exactly this). A route is as dangerous as its worst leg.
	var straight := SuppressionFeed.along(fields, tank.team, here, ahead)
	var best: Variant = null
	var best_threat := straight * FIRE_DETOUR_MARGIN
	for step: float in FIRE_DETOUR_STEPS:
		for side: float in [1.0, -1.0]:
			var beside := here + across * (side * step)
			beside.x = clampf(beside.x, -limit, limit)
			beside.z = clampf(beside.z, -limit, limit)
			var threat := maxf(SuppressionFeed.along(fields, tank.team, here, beside),
					SuppressionFeed.along(fields, tank.team, beside, beside + direction * reach))
			if threat < best_threat:
				best_threat = threat
				best = beside
	if best != null:
		_fire_detour = best
		_fire_detour_until = tick + FIRE_DETOUR_TICKS
		_fire_detour_since = tick
		if _fire_since < 0:
			_fire_since = tick
		fire_detours += _step
		return best
	# Looked and found nothing: every way round is swept too. Push on rather than looking again every few ticks.
	fire_no_way_round += 1
	_fire_since = -1
	_fire_detour_again = tick + FIRE_DETOUR_COOLDOWN
	return waypoint


## The object that answers contract L2 for this match, resolved once.
func _suppression_fields(game_match: Object) -> Object:
	var id := game_match.get_instance_id()
	if _fields_match != id:
		_fields_match = id
		_fields = SuppressionFeed.source(game_match)
	return _fields


## Local avoidance: a friend parked in the way within AVOID_LOOKAHEAD meters (within AVOID_WIDTH of the line to the
## waypoint) is passed beside, AVOID_CLEARANCE meters off its center on the side the line already leans to. Navmesh paths
## ignore units, move_and_slide stops a hull against another, and wheels can't pivot round one (a wheeled IFV looped its
## unstick routine against a parked tank for 8 s). Brains only (they share the per-tick tank table).
func _around_friends(waypoint: Vector3) -> Vector3:
	var brain := self as TankBrain
	if brain == null or brain.game_match == null:
		return waypoint
	var here_x := tank.global_position.x
	var here_z := tank.global_position.z
	var to_x := waypoint.x - here_x
	var to_z := waypoint.z - here_z
	var distance := sqrt(to_x * to_x + to_z * to_z)
	if distance < 1.0:
		return waypoint
	var dir_x := to_x / distance
	var dir_z := to_z / distance
	var nearest := minf(distance + AVOID_WIDTH, AVOID_LOOKAHEAD)
	var detour := waypoint
	# X2: the tick's shared living-ally table (positions already extracted; every controller runs before any tank
	# moves, so these are this tick's positions), and a squared-distance reject before any of the lane math. At 60
	# units this loop was the single biggest cost of executing orders.
	var my_name := String(tank.name)
	var reach_squared := nearest * nearest + AVOID_WIDTH * AVOID_WIDTH
	# Round-5 X1: typed columns instead of a dictionary per ally (same tanks, same order, same float values).
	var columns := AiTickCache.ally_columns(brain.game_match, tank.team)
	var xs: PackedFloat32Array = columns[0]
	var zs: PackedFloat32Array = columns[1]
	var names: PackedStringArray = columns[2]
	for i in xs.size():
		var position := Vector3(xs[i], 0.0, zs[i])
		var dx := position.x - here_x
		var dz := position.z - here_z
		if dx * dx + dz * dz >= reach_squared or names[i] == my_name:
			continue
		var along := dx * dir_x + dz * dir_z
		if along <= 0.0 or along >= nearest:
			continue
		var lateral := dx * dir_z - dz * dir_x
		if absf(lateral) >= AVOID_WIDTH:
			continue
		nearest = along
		# Pass on the side away from it (ties: its right).
		var clearance := AVOID_CLEARANCE if lateral >= 0.0 else -AVOID_CLEARANCE
		detour = Vector3(position.x - dir_z * clearance, 0.0, position.z + dir_x * clearance)
	return detour


## The minimum turning radius when this unit rolls on wheels (K3 `locomotion` "wheels", `min_turn_radius_m`), else 0.
func _wheel_radius() -> float:
	if _wheel_radius_unit != tank.unit_id:
		_wheel_radius_unit = tank.unit_id
		_wheel_radius_value = 0.0
		if String(Units.stat(tank.unit_id, "locomotion", "tracks")) == "wheels":
			_wheel_radius_value = maxf(float(Units.stat(tank.unit_id, "min_turn_radius_m", 0.0)), 0.5)
	return _wheel_radius_value


## Counts ticks without getting at least 0.5 m closer (along the path) to the current move goal. `remaining` is the
## distance the caller already worked out for steering — computing it again here walked the whole path a second time
## every tick for every moving unit (X2).
func _track_progress(goal: Vector3, drive: Vector2, remaining: float) -> void:
	if _flat_distance(goal, _progress_goal) > 2.0 or drive == Vector2.ZERO:
		_progress_goal = goal
		_progress_best = remaining
		stalled_ticks = 0
	elif remaining < _progress_best - 0.5:
		_progress_best = remaining
		stalled_ticks = 0
	else:
		stalled_ticks += _step


## The point to steer at now: the next navmesh waypoint toward `goal`, or `goal`
## itself when there's no path (navigation not baked yet, or already close).
func _next_waypoint(goal: Vector3, delta: float) -> Vector3:
	_repath_left -= delta
	if _repath_left <= 0.0 or _flat_distance(goal, _path_goal) > 1.0:
		_repath_left = REPATH_SECONDS
		_path_goal = goal
		_path = Pathing.find_path(tank, tank.global_position, goal)
		_path_index = 0
	# Wheels can't thread a waypoint the way tracks pivot onto one: they move on to the next one a turning radius out.
	var reach := maxf(WAYPOINT_RADIUS, _wheel_radius() * WHEELS_WAYPOINT_RADII)
	while _path_index < _path.size() \
			and _flat_distance(tank.global_position, _path[_path_index]) < reach:
		_path_index += 1
	if _path_index >= _path.size():
		return goal
	var waypoint := _path[_path_index]
	return Vector3(waypoint.x, 0.0, waypoint.z)


func _remaining_path_distance(goal: Vector3) -> float:
	if _path_index >= _path.size():
		return _flat_distance(tank.global_position, goal)
	var total := _flat_distance(tank.global_position, _path[_path_index])
	for i in range(_path_index, _path.size() - 1):
		total += _flat_distance(_path[i], _path[i + 1])
	return total


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _apply_unstick(cmd: TankCommand, delta: float) -> void:
	if _unstick_left > 0.0:
		_unstick_left -= delta
		cmd.throttle = 1.0 if move_order.get("reverse", false) else -1.0  # back off the way you were NOT going
		cmd.turn = 1.0
		return
	if absf(cmd.throttle) > 0.5 and tank.estimated_velocity.length() < STUCK_SPEED:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			_stuck_time = 0.0
			_unstick_left = UNSTICK_SECONDS
	else:
		_stuck_time = 0.0


# ---- Weapon --------------------------------------------------------------------------

func _apply_weapon(cmd: TankCommand) -> void:
	engaged_target = ""
	var lap := Time.get_ticks_usec() if profile_detail else 0
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
	lap = _lap("weapon.scan", lap)
	if target == null:
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
	var brain := self as TankBrain
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
	lap = _lap("weapon.aim", lap)
	cmd.fire = _clear_to_fire(in_range and aimed and tank.ready_to_fire(), aim)
	_lap("weapon.lanes", lap)


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
	# Round-5 X1 found: a `seen` test (team spotting, else own sight radius) was computed here and never used, so this
	# has only ever meant "in range with a clear line". The unused call is gone (it cost a dictionary walk per enemy per
	# scan); whether a gun should hold fire on something nobody sees is a behaviour question for the ladder
	# (_agents/streams/archive/round5/ai.md, known issues).
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
	var brain := self as TankBrain
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
	var brain := self as TankBrain
	if brain != null and brain.game_match != null and brain.game_match.tanks == tanks_root:
		return AiTickCache.tanks_by_name(brain.game_match).get(tank_name) as Tank
	return tanks_root.get_node_or_null(NodePath(tank_name)) as Tank


## Living enemies in scene order: shared per tick for brains (AiTickCache), scanned otherwise.
func _enemies() -> Array:
	var brain := self as TankBrain
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
		held_for_friends += 1
		return false
	var blockers := FireLanes.for_shot(tanks_root, tank, aim)
	if blockers.is_empty():
		lane_blocked_ticks = 0
		lane_blocker = ""
		return true
	lane_blocked_ticks += _step
	lane_blocker = String(blockers[0])
	held_for_friends += 1
	_lane_hold_left = LANE_RECHECK_TICKS - 1
	return false


## Point the turret at a world spot, and remember that heading for when the spot is gone.
func _cover(point: Vector3, cmd: TankCommand) -> void:
	cmd.aim_point = point
	var flat := Vector3(point.x - tank.global_position.x, 0.0, point.z - tank.global_position.z)
	if flat.length_squared() > 0.25:
		_held_aim = flat.normalized()


static func _validate(order: Variant, allowed_types: Array) -> String:
	if typeof(order) != TYPE_DICTIONARY:
		return "order must be an object"
	var type: Variant = order.get("type")
	if not allowed_types.has(type):
		return "type must be one of %s" % [allowed_types]
	var numeric := {"move_to": ["x", "z"], "face": ["x", "z"], "aim": ["x", "z"], "suppress": ["x", "z"],
			"drive": ["throttle", "turn", "seconds"],
			"retreat_below_hp": ["hp", "x", "z"]}
	for key in numeric.get(type, []):
		var value: Variant = order.get(key)
		if not (typeof(value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(value)):
			return "'%s' needs a finite number '%s'" % [type, key]
	if type == "target" and typeof(order.get("name")) != TYPE_STRING:
		return "'target' needs a string 'name'"
	if order.has("reverse") and typeof(order["reverse"]) != TYPE_BOOL:
		return "'reverse' must be true or false"
	if order.has("direct") and typeof(order["direct"]) != TYPE_BOOL:
		return "'direct' must be true or false"
	if order.has("to_safety") and typeof(order["to_safety"]) != TYPE_BOOL:
		return "'to_safety' must be true or false"
	if order.has("fallback") and typeof(order["fallback"]) != TYPE_BOOL:
		return "'fallback' must be true or false"
	if order.has("speed") and not (typeof(order["speed"]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(order["speed"]))):
		return "'speed' must be a number"
	if order.has("arrive") and not (typeof(order["arrive"]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(order["arrive"]))):
		return "'arrive' must be a number"
	return ""
