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
##   {"type": "target", "name": String, "fallback": bool (optional), "long_shot": bool (optional)}
##       engage one specific tank when visible; with fallback, shoot the nearest visible
##       enemy meanwhile (brains use this: team intel can pick a target this tank can't see)
##       long_shot (N5, round 6) lifts the engagement envelope's FIRE DISCIPLINE for this target: the crew may fire
##       out to the weapon's full range instead of holding for its effective band. It is deliberately NOT implied by
##       "target", because a brain in ENGAGE issues a target order every tick — if it were, no CPU unit would ever
##       hold its fire and the contract would do nothing. It is for a commander who has decided a long shot is worth
##       the round (a support-by-fire or attack-by-fire task). Sight and acquisition still apply: nobody may be
##       ordered to shoot at something nobody can see.
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
## Kept for readers of the old name: the route's look-ahead for a wall of bullets lives in Movement now.
const FIRE_LOOKAHEAD := Movement.FIRE_LOOKAHEAD
const MOVE_TYPES := ["stop", "move_to", "drive", "face"]
const WEAPON_TYPES := ["hold_fire", "aim", "fire_at_will", "target", "suppress"]
const REFLEX_TYPES := ["retreat_below_hp", "halt_on_contact"]
## Kept for readers of the old names: the firing constants live in Gunnery now.
const AIM_TOLERANCE_DEG := Gunnery.AIM_TOLERANCE_DEG
const LOW_AMMO_FRACTION := Gunnery.LOW_AMMO_FRACTION
const HELD_AIM_DISTANCE := Gunnery.HELD_AIM_DISTANCE
const SCAN_EVERY_TICKS := Gunnery.SCAN_EVERY_TICKS
const LANE_RECHECK_TICKS := Gunnery.LANE_RECHECK_TICKS
const MAX_REFLEXES := 4
const MAX_EVENTS := 8

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
var visible_enemy_names: PackedStringArray = []
var reflexes: Array = []
## Recent notable happenings (reflexes firing), newest last. For observers like the bridge.
var events: PackedStringArray = []

## The L2 source for this match, resolved once (asking "do you answer L2" per move per tick is not free).
var _fields: Object = null
var _fields_match := 0
var _reflex_armed: Array[bool] = []

var _drive_elapsed := 0.0

## Measurement (not decisions): shots held for friends, by every controller since the process started.
static var held_for_friends := 0
## Round-5 X1, controller stride (BrainVariants "brain_stride"): a brain runs its whole controller — thinking and
## executing — on every Nth physics tick, staggered by think_offset, and hands the tank its last command in between.
## `_step` is how many ticks the current run covers (counters that count ticks add it), `_last_run_tick` when it last
## ran, and `_last_command` what it handed over.
var _stride := 1
var _step := 1
var _last_run_tick := -1
var _last_command: TankCommand = null

## N1 (round 6): the path-following, avoidance and unsticking half of this controller (game/ai/movement.gd).
var movement: Movement
## Stuck detection (round-3 X1), kept here for the brains that read it: Movement.stalled_ticks.
var stalled_ticks: int:
	get:
		return movement.stalled_ticks
	set(value):
		movement.stalled_ticks = value


## The firing half: when a gun may speak (game/ai/gunnery.gd, combat's). Its public state is forwarded below so brains,
## the bridge and the HUD read it on the controller as before.
var gunnery: Gunnery
var engaged_target: String:
	get:
		return gunnery.engaged_target
	set(value):
		gunnery.engaged_target = value
var watch_point: Variant:
	get:
		return gunnery.watch_point
	set(value):
		gunnery.watch_point = value
var spotter: Callable:
	get:
		return gunnery.spotter
	set(value):
		gunnery.spotter = value
var engagement_lay: Engagement.Lay:
	get:
		return gunnery.engagement_lay
	set(value):
		gunnery.engagement_lay = value
var ticks_since_fire: int:
	get:
		return gunnery.ticks_since_fire
	set(value):
		gunnery.ticks_since_fire = value
var lane_blocked_ticks: int:
	get:
		return gunnery.lane_blocked_ticks
	set(value):
		gunnery.lane_blocked_ticks = value
var lane_blocker: String:
	get:
		return gunnery.lane_blocker
	set(value):
		gunnery.lane_blocker = value
var hold_for_friends: bool:
	get:
		return gunnery.hold_for_friends
	set(value):
		gunnery.hold_for_friends = value


func _init() -> void:
	movement = Movement.new(self)
	gunnery = Gunnery.new(self)


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
		movement.new_order()
	if new_weapon != null:
		weapon_order = new_weapon
	return ""


func compute_command(delta: float) -> TankCommand:
	movement.bind()
	if not tank.is_alive():
		gunnery.dead()  # N5: nothing engaged, and a respawned crew starts its lay from scratch
		movement.idle()
		return TankCommand.new(0.0, 0.0, tank.global_position + tank.turret_forward() * HELD_AIM_DISTANCE)
	var cmd := TankCommand.new(0.0, 0.0, gunnery.held_aim_point())
	var clock := Time.get_ticks_usec() if profile_detail else 0
	_sense()
	_apply_reflexes()
	clock = _lap("c.reflexes", clock)
	clock = Time.get_ticks_usec() if profiling else 0
	_apply_move(cmd, delta)
	movement.unstick(cmd, move_order, delta)
	if profiling:
		TankBrain.profile_parts["move"] = int(TankBrain.profile_parts.get("move", 0)) + Time.get_ticks_usec() - clock
		clock = Time.get_ticks_usec()
	gunnery.apply(cmd, _seconds_step())  # after the movement half, in seconds (combat's seam)
	if profiling:
		TankBrain.profile_parts["weapon"] = int(TankBrain.profile_parts.get("weapon", 0)) + Time.get_ticks_usec() - clock
	return cmd


## A new order from the player: drop the unstick routine, the old path, and stall bookkeeping, so the new order
## drives this very tick (K1 response guarantee).
func interrupt() -> void:
	movement.reset()


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
				movement.new_order()
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
	# X4: a unit giving way to a friend does that first, whatever its own order is; the order resumes afterwards.
	if movement.right_of_way(cmd, delta):
		return
	if move_order["type"] != "move_to":
		movement.idle()
	match move_order["type"]:
		"move_to":
			movement.drive(cmd, move_order, delta)
		"face":
			var spot := Vector3(move_order["x"], 0.0, move_order["z"])
			var turn_only := Steering.drive_toward(tank.global_position, -tank.global_basis.z, spot, 0.0)
			cmd.turn = turn_only.y if absf(turn_only.y) > 0.08 else 0.0
			if movement.wheel_radius() > 0.0 and cmd.turn != 0.0 and absf(turn_only.y) >= 1.0:
				# Wheels can't turn standing still: creep round (combat's wheels roll along the arc on a pure turn command).
				cmd.throttle = Steering.WHEELS_MIN_THROTTLE
		"drive":
			_drive_elapsed += delta
			if _drive_elapsed <= float(move_order["seconds"]):
				cmd.throttle = move_order["throttle"]
				cmd.turn = move_order["turn"]
			else:
				move_order = {"type": "stop"}


## The object that answers contract L2 for this match, resolved once.
func _suppression_fields(game_match: Object) -> Object:
	var id := game_match.get_instance_id()
	if _fields_match != id:
		_fields_match = id
		_fields = SuppressionFeed.source(game_match)
	return _fields


## The minimum turning radius when this unit rolls on wheels, else 0 (Movement.wheel_radius; brains read it).
func _wheel_radius() -> float:
	return movement.wheel_radius()


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Seconds of GAME time this run covers: one tick, or the whole stride when this unit executes at a lower rate.
## Booked in seconds, never in ticks (orchestration.md lesson 30), and never from the wall clock (determinism.md).
func _seconds_step() -> float:
	return float(_step) / float(SimClock.TICK_RATE)


## The nearest shootable enemy (Gunnery's scan; brains ask it directly).
func _nearest_shootable() -> Tank:
	return gunnery._nearest_shootable()


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
