class_name Movement
extends RefCounted
## N1, the Movement API (round 6, CP1): the one seam between *where a unit is told to be* and *how it gets there*.
## Everything above it (squad's slots, control's orders, a brain's hops) says "be here"; everything below it (path
## planning, avoidance, right-of-way, unsticking, the control law) is nav's. Architecture: _agents/navigation.md.
##
## The static API is what other streams call:
##   Movement.request(unit, to, opts)   drive `unit` (a Tank) to `to`; opts may carry "arrive_radius", "facing", "pace"
##                                      (0.2..1 of top speed), "priority", "reverse", "direct"
##   Movement.state(unit) -> {"phase": "pathing" | "driving" | "yielding" | "blocked" | "arrived", "eta_s",
##                            "remaining_m", "path_points", "blocked_by", "goal", "stalled_s"}
##                           ({} for a unit nothing drives: a player's hull, a client's copy)
##   Movement.eta(unit, to) -> float   seconds to drive there along the navmesh route (the lead's "estimate the
##                                      position and time at which a unit would converge")
##   Movement.cancel(unit)              stop where it stands
##
## The guarantee nav owes every consumer: a unit given a destination ARRIVES or reports `blocked` with a reason in
## `blocked_by` (a unit's name, "terrain" or "no_path"). It never stands still silently.
##
## One Movement instance lives in each OrderController (the composer) and does the per-tick driving of a `move_to`:
## the route, the steps round fire and friends, the steering call, progress, and the unstick routine. It reads the
## controller for the order, the tank and the tick; it never decides where to go.

## X7: re-plan a route at least this often even when nothing changed (a safety net: the navmesh is static).
## **Round 9, A1 replaces this with a state-error tube** — `--nav-off=a1` restores it. See `_tube_for_plan`.
const REPATH_SECONDS := 4.0
## A1 (catalogue row A1, Tabuada 2007): the drift budget a plan is good for. Self-triggered control stores, at plan
## time, how far the state may drift before the plan stops being near-optimal — and for THIS plan, on THIS navmesh,
## that radius has an exact answer rather than a tuned one.
##
## **The navmesh is static and the route is optimal, so by Bellman's principle the route is still optimal from every
## point ON it.** Nothing about driving along a valid route degrades it. The only state errors that can invalidate it
## are leaving it, the goal moving, or being stuck — and all three are already EVENTS with their own tests
## (`OFF_PATH_REPATH`, the goal-moved check, `stalled`). **So the tube radius IS the off-path corridor**, and the
## fixed `REPATH_SECONDS` cadence on top of it was re-asking a question whose answer could not have changed.
##
## Two wrong versions were built and measured first, and both failed the same way — **a radius derived from the
## route's shape is a cadence wearing a radius**:
##   1. *distance to the second corner ahead, capped at 40 m*: a tank covers ~36 m in the 4 s cadence, so the cap
##      bound before the tube ever held. `a1_tube_skips` 0, re-plans 3 of 3.
##   2. *the same, uncapped*: navmesh routes are funnel-smoothed polylines with **19 points** over 100 m, so "two
##      corners ahead" is 28.7 m and the hull drifts past it in 3.2 s — it fired EARLIER than the cadence it was
##      replacing. `a1_tube_skips` 0 again. Measured, not reasoned: see the probe numbers in the brief.
const TUBE_RADIUS_IS := "the off-path corridor (OFF_PATH_REPATH)"
## ...and the same argument for the GOAL's own drift, which is where the re-plans actually are. A sliding goal is
## re-planned when it has moved this share of the remaining route, never less than this many metres.
const GOAL_TUBE_SHARE := 0.1
const GOAL_TUBE_MIN := 2.0
## ...and at once when the hull is this far off its route (flat metres).
const OFF_PATH_REPATH := 5.0
## X7: steer at a point this far along the route beyond the hull (metres); wheels at least this many turning radii.
const PATH_LOOKAHEAD := 5.0
const WHEELS_LOOKAHEAD_RADII := 1.2
## settle_radius(): a car settles within this share of its turning radius, at most this far (metres).
const WHEELS_SETTLE_RADII := 0.6
const WHEELS_SETTLE_MAX := 6.0
## ...but only once the hull points within ~60° of its route; until then it steers at the next corner (see there).
const CARROT_ALIGNED_COS := 0.5
## A car looks at most this many turning radii further along the route for a point it can drive forward onto.
const WHEELS_LOOKAHEAD_MAX_RADII := 4.0
## Round 7: the straight line to the carrot must stay on the navmesh; checked at these shares of its length, within
## this much slack (flat metres), and if it doesn't the carrot is pulled back to these shares of the lookahead.
const CHORD_SAMPLES: Array[float] = [0.5, 1.0]
const CHORD_SLACK := 0.3
## The navmesh bake's agent radius. **This constant is NO LONGER THE SOURCE — it is the cross-check.** The value
## that routing uses is READ from the live arena (`bake_radius()`); this one records what nav expects to find, and
## `bake_radius()` complains loudly if they ever disagree. A mirrored constant cannot drift silently if it is only
## ever compared, never consumed.
##
## **Why it cannot be per-hull-class, which is the question CP2 raised:** there is ONE navmesh with ONE bake radius.
## A per-class value here would claim clearance the mesh does not provide, which is worse than a stale one.
## `Avoidance.radius_of()` is the per-hull quantity and already derives from `Units` hull_size.
const NAV_AGENT_RADIUS := 2.0
const CHORD_MARGIN := 0.2
const CARROT_PULLBACK: Array[float] = [0.6, 0.3]
## Driving at >50% throttle but moving slower than this for STUCK_SECONDS = stuck.
const STUCK_SPEED := 0.8
const STUCK_SECONDS := 1.0
const UNSTICK_SECONDS := 0.9
## ...but only with this much room (beyond both hulls' radii) behind it: the unstick routine never rams a friend.
const UNSTICK_CLEARANCE := 2.0
## No progress (0.5 m closer along the route than its best) for this long and the unit reports `blocked` (N1).
const BLOCKED_SECONDS := 2.0
## A hull whose centre is within this of mine (flat metres), ahead of me, is what I'm blocked by.
const BLOCKER_REACH := 8.0
## ...and "ahead" means within this cosine of the direction I'm trying to go (~60°).
const BLOCKER_AHEAD_COS := 0.5
## A route that ends further than this from the goal did not reach it: the goal is inside something or cut off.
const NO_PATH_MARGIN := 3.0
## ...and a unit within this of the end of such a route has gone as far as it can: `blocked`, `no_path`, at once.
const UNREACHABLE_AT_END := 4.0
## eta(): the share of top speed a route is driven at on average (corners, the slow-down at the end).
const ETA_CRUISE_SHARE := 0.85

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

## THE REGIME NOTHING NOTICED (round 9). The maze defile found a hull that is **not stalled** (it inches forward, so
## `stalled_ticks` resets), **not blocked** (it makes a little progress), and **not held back enough to ask for right
## of way** (`asks_refused` and `yields_started` were both exactly **0** over a 70 s run) — and never arrives. Every
## safety net nav has was watching for a different symptom, so this gives the regime a name and a number.
##
## `wedged` = over WEDGED_WINDOW this mover's avoidance shaped its velocity on more than WEDGED_SHARE of its ticks
## **and** its net displacement is under its own hull length. Reported in `Movement.state()` as a FIELD, deliberately
## **not as a new `phase` value**: consumers branch on `phase` (the fight probe's buckets, control's readout, tests)
## and a new value there would silently change every one of those branches. A field is the reversible version.
const WEDGED_WINDOW := SimClock.TICK_RATE * 2
const WEDGED_SHARE := 0.5
## Measurement only: movers that ENTERED the wedged regime (transitions, not ticks).
static var wedged_units := 0


## X3: ORCA local avoidance on (the kill switch is for measuring the difference, `--no-avoidance`).
static var avoidance_on := not OS.get_cmdline_user_args().has("--no-avoidance")
## Measuring only: `--nav-off=grace,minpace,pushidle,carrot,yield,unstick,repath,chord,guard,backup,standoff,commit,holdband` switches single mechanisms off for an A/B
## (nav-where), and `r5sidestep` switches round 5's single-friend sidestep back ON (it overtakes a friend ahead in the lane).
## TWO TRAPS, both hit in round 6 (_agents/navigation.md "Measuring"): (1) a switch that silently does nothing makes
## your A/B a comparison of a thing with itself — the first `carrot` switch was broken exactly so; prove each switch
## changes SOMETHING before trusting an equal result. (2) Once a nav commit is merged, `main` is no longer the
## before-picture: bisect on named commits, not on "main vs my branch".
static var _off := _parse_off()


## Is mechanism `name` switched off (--nav-off=…)? Parses the command line on first use, so it is right whenever it is
## asked — including from another class's code before Movement's own statics have been touched.
static func switched_off(name: String) -> bool:
	if _off.is_empty() and not _off_parsed:
		_off = _parse_off()
	_off_parsed = true
	return _off.has(name)


static var _off_parsed := false


## Every mechanism name anything asks about. A name that is not here is a typo or a mechanism that no longer exists,
## and `switched_off()` would answer false for it forever: the A/B would run one treatment in both arms and come back a
## clean null (arena hit exactly that with `flow` on a tree that did not have it yet). So an unknown name is refused
## loudly instead. Add the name here in the same commit that adds the switch.
## Round 9: a row's switch selects between the NEW mechanism and the OLD one it replaces — never "the new thing,
## disabled into nothing", which is a third treatment rather than a control. `a7` is currently INVERTED (like
## `holdband` and `r5sidestep`, it turns its mechanism ON): A7 is built and measured but not the default, because it
## costs squad's slot-drift scenario. See `CombatMotion.a7_on()` for the numbers and the open contract question.
const OFF_NAMES: Array[String] = ["a1", "a4", "a6", "a7", "a11", "backup", "carrot", "chord", "clearance", "commit", "facegiveup", "grace", "guard", "holdband",
		"minpace", "pushidle", "r5sidestep", "repath", "standoff", "unstick", "yield"]


static func _parse_off() -> PackedStringArray:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nav-off="):
			var names := arg.trim_prefix("--nav-off=").split(",")
			for name: String in names:
				if not OFF_NAMES.has(name):
					push_error("--nav-off=%s: no such mechanism (have %s). A name nothing reads switches nothing off, and the A/B would look like a null." % [name, ", ".join(OFF_NAMES)])
			return names
	return PackedStringArray()
## Look this far along an avoiding velocity when steering by it (metres, at most the distance to the waypoint).
const AVOID_STEER_MIN := 3.0
const AVOID_STEER_MAX := 8.0
## An avoiding velocity must keep the hull on the navmesh this far ahead (flat metres off the mesh allowed).
const AVOID_MESH_PROBE := 3.0
const AVOID_MESH_SLACK := 0.75
## For this many ticks after a new order a hull steers along its route and avoidance only sets its throttle (_avoid: K1).
const AVOID_GRACE_TICKS := SimClock.TICK_RATE / 3
## Avoidance holding a unit below this share of its speed counts as held back (it asks a parked friend at once).
const AVOID_ASK_PACE := 0.5
## A goal that jumps further than this (flat metres) is a new destination for AVOID_GRACE_TICKS.
const NEW_GOAL_JUMP := 3.0
## ...and during those ticks a way on that is crowded but not reversed is still driven at this share of its speed at least.
const AVOID_MIN_PACE := 0.15

## X4 right-of-way. A unit that has made no progress for ASK_SECONDS asks the friend in its way to give way, at most
## once every ASK_EVERY seconds.
const ASK_SECONDS := 1.0
const ASK_EVERY_SECONDS := 1.0
## A remaining route this much shorter decides who gives way (metres); closer than that it's the unit name.
const PRIORITY_MARGIN := 0.5
## A unit gives way for at most this long, holds its spot at least YIELD_HOLD, and is at its spot within YIELD_REACHED.
const YIELD_MAX_SECONDS := 6.0
const YIELD_HOLD_SECONDS := 1.0
const YIELD_REACHED := 1.5
## ...and is done once the unit it gave way to is this far away (flat metres), or has passed it.
const YIELD_CLEAR := 9.0
## A spot to give way to must be this far (beyond both radii) from the asker's line of travel, and this far from every
## other hull (flat metres).
const YIELD_LINE_MARGIN := 0.75
const YIELD_SPOT_CLEARANCE := 3.5
## ...and on the navmesh within this (flat metres).
const YIELD_MESH_SLACK := 0.5
## Where to look for a spot, as [along the asker's travel, across it] (metres), nearest first. The across ones step
## off its line; the along ones (last resort, in a corridor with no room beside) lead the way out ahead of it.
## ...and when none of those is free, straight back along the hull this far (metres): the move a car always has.
const YIELD_BACK_UP: Array[float] = [6.0, 10.0]
const YIELD_SPOTS: Array[Vector2] = [Vector2(0, 5), Vector2(3, 6), Vector2(-3, 6), Vector2(0, 8), Vector2(5, 9),
		Vector2(0, 11), Vector2(10, 0), Vector2(16, 0), Vector2(24, 0)]

## A1's arm (round 9). `a1_cadence_due` is what `REPATH_SECONDS` alone WOULD have fired on this same run, so the
## falsifier — *intra-decision re-plan rate down 60%* — is read from one run rather than from two runs that were
## different drives. `a1_tube_skips` counts the ticks where the cadence was due and the tube said the plan was still
## good; it is 0 in the control arm by construction, which is what makes the two arms distinguishable (lesson 147).
static var a1_replans := 0
static var a1_cadence_due := 0
static var a1_tube_skips := 0
## ...split by what actually caused it: `cadence`, `goal_jumped` (a real new destination), `goal_slid` (a goal moving
## smoothly under a unit keeping station on it — a re-plan nav should probably not be doing at all), `off_path`,
## `stalled`. A1 measured that ~97% of re-plans are events rather than the cadence; this says WHICH events, which is
## the difference between a finding and a shrug.
static var a1_by_cause := {}


## A1 is OPT-IN (`--nav-off=a1` turns it ON), on the same footing as A7 and A11: round 9's new rows land behind their
## switch until their behaviour scenarios pass, and the switch is then the A/B arm rather than a leftover.
static func a1_on() -> bool:
	return switched_off("a1")


static func route_arms() -> Dictionary:
	return {"a1_replans": a1_replans, "a1_cadence_due": a1_cadence_due, "a1_tube_skips": a1_tube_skips,
			"by_cause": a1_by_cause.duplicate(),
			"clearance_chords": clearance_chords, "clearance_refused": clearance_refused}


static func reset_route_arms() -> void:
	clearance_chords = 0
	clearance_refused = 0
	a1_replans = 0
	a1_cadence_due = 0
	a1_tube_skips = 0
	a1_by_cause = {}


## Measurement only: give-ways begun, asks refused for lack of room, and units that gave way themselves.
static var yields_started := 0
## Measurement only: ticks the guard found neither the chosen point nor the next corner drivable (_guard_steer).
static var guard_rescues := 0
static var asks_refused := 0

## X6 (N6): station-keeping. A move_to whose goal is itself moving (a formation slot riding its anchor, a follow's
## station) and is within STATION_RANGE is regulated by a PID on the along-track gap, on top of the goal's own speed
## (feed-forward), instead of the drive-and-stop of a unit chasing a point. `--no-station-pid` is the measuring switch.
static var station_on := not OS.get_cmdline_user_args().has("--no-station-pid")
const STATION_RANGE := 14.0
## The goal counts as moving above this speed (m/s), estimated from how far it moved between changes.
const STATION_MIN_SPEED := 0.5
## ...and stops counting as moving when it has not changed for this long.
const STATION_STALE_SECONDS := 1.0
## ...or at once when it is re-issued unchanged after this long (a stopped slot; brains re-issue several times a second,
## and an anchor that only updates now and then must not read as stopping between updates).
const STATION_STOPPED_SECONDS := 0.35
## Steer at where the goal will be this far ahead (seconds), so the hull points along the formation's travel.
const STATION_LEAD_SECONDS := 0.6

const PHASES := ["pathing", "driving", "yielding", "blocked", "arrived"]

## Tank instance id -> the Movement driving it (the composer binds it every tick).
static var _registry := {}

## The composer this mover belongs to (an OrderController, or a TankBrain).
var ctl: OrderController

## Stuck detection (round-3 X1): consecutive ticks a move_to made no progress toward its goal (0 while arrived or not
## driving to a point). Brains time out options with it; N1 reports `blocked` from it.
var stalled_ticks := 0
var phase := "arrived"
var blocked_by := ""

var _path := PackedVector3Array()
var _path_index := 0
var _path_goal := Vector3.INF
var _repath_left := 0.0
var _stuck_time := 0.0
var _unstick_left := 0.0
var _unstick_pivot := false
var _progress_goal := Vector3.INF
var _progress_best := INF
var _goal := Vector3.INF
## Round 7: does the current route end at the goal? (False = the navmesh can only get this unit near it.)
var _reachable := true
## The last Pathing.query for this route (its gaps go into Movement.state for anyone who needs the numbers).
var _route_reading := {}
var _arrive := 0.0
var _remaining := 0.0
var _blocker_left := 0
## X4: the unit this one is giving way to ("" = none), where it's giving way to, and the bookkeeping (in ticks).
var yield_to := ""
var _yield_point := Vector3.INF
var _yield_dir := Vector2.ZERO
var _yield_left := 0
var _yield_held := 0
var _last_yielded_to := ""
var _ask_left := 0
## X6: the goal's estimated velocity (flat), when it last changed (in this mover's ticks), and the regulator.
var _goal_velocity := Vector2.ZERO
var _goal_seen := Vector3.INF
var _goal_changed_at := 0
## The order was (re)issued since the last tick: an unchanged goal re-issued means the goal has stopped.
var _reissued := false
var _ticks := 0
## Ticks since the current order (or interruption) began.
var _order_ticks := 0
## Where it steered this tick and at what share of its speed (N1 reading `steer_to`, `pace`: overlays, diagnosis).
var steer_to := Vector3.INF
var pace_now := 1.0
var _station: Pid = null
var _station_faction := "?"
## _wheel_radius() per unit type (the catalog doesn't change mid-match).
var _wheel_radius_unit := ""
var _wheel_radius_value := 0.0

## X3: the sidestep being driven right now (null = none) and the tick it gives up at.
var _fire_detour: Variant = null
var _fire_detour_until := 0
var _fire_detour_since := -1000
var _fire_detour_again := 0
## The tick this unit started going round the current wall of bullets (-1 = it isn't).
var _fire_since := -1
var _fire_checked_tick := -1000


func _init(controller: OrderController = null) -> void:
	ctl = controller


# ---- The N1 API (static: what other streams call) ------------------------------------------------------------------

## The Movement driving `unit`, or null (nothing drives it, or its controller is gone).
static func of(unit: Node) -> Movement:
	if unit == null or not is_instance_valid(unit):
		return null
	var mover: Movement = _registry.get(unit.get_instance_id())
	if mover == null or not is_instance_valid(mover.ctl) or mover.ctl.tank != unit:
		return null
	return mover


## Drive `unit` to `to`. Replaces its current move order (the weapon order is untouched).
static func request(unit: Node, to: Vector3, opts: Dictionary = {}) -> void:
	var mover := of(unit)
	if mover == null:
		push_warning("Movement.request: nothing drives %s" % [unit.name if unit != null else "null"])
		return
	var order := {"type": "move_to", "x": to.x, "z": to.z}
	if opts.has("arrive_radius"):
		order["arrive"] = float(opts["arrive_radius"])
	if opts.has("pace"):
		order["speed"] = float(opts["pace"])
	for key: String in ["reverse", "direct"]:
		if opts.has(key):
			order[key] = bool(opts[key])
	if opts.has("facing"):
		order["facing"] = opts["facing"]
	if opts.has("priority"):
		order["priority"] = int(opts["priority"])
	mover.ctl.set_orders(order, null)
	mover.ctl.interrupt()


## Stop where it stands.
static func cancel(unit: Node) -> void:
	var mover := of(unit)
	if mover != null:
		mover.ctl.set_orders({"type": "stop"}, null)


## What the unit's movement is doing now (see the header), or {} when nothing drives it.
static func state(unit: Node) -> Dictionary:
	var mover := of(unit)
	return mover.reading() if mover != null else {}


## Seconds for `unit` to drive to `to`: the navmesh route's length at a cruising share of its top speed, plus the time
## to swing its hull onto the route. Straight-line when the navmesh isn't ready. 0 when there already.
static func eta(unit: Node, to: Vector3) -> float:
	var tank := unit as Tank
	if tank == null or not is_instance_valid(tank) or tank.max_forward_speed <= 0.0:
		return 0.0
	var here := tank.global_position
	var length := _flat_distance(here, to)
	var first := to
	if length > 0.5 and Pathing.enabled and tank.is_inside_tree() and Pathing.is_ready(tank):
		var path := Pathing.find_path(tank, here, to)
		if path.size() >= 2:
			length = _flat_distance(here, path[0])
			for i in range(1, path.size()):
				length += _flat_distance(path[i - 1], path[i])
			first = path[1]
	if length <= 0.5:
		return 0.0
	var seconds := length / (tank.max_forward_speed * ETA_CRUISE_SHARE)
	var forward := -tank.global_basis.z
	var toward := Vector3(first.x - here.x, 0.0, first.z - here.z)
	if toward.length_squared() > 0.01 and tank.hull_turn_rate > 0.0:
		seconds += absf(Vector3(forward.x, 0.0, forward.z).normalized().signed_angle_to(toward, Vector3.UP)) / tank.hull_turn_rate
	return seconds


# ---- Per unit (the composer calls these) ----------------------------------------------------------------------------

## The N1 reading for this unit.
## S4 (contract, `_agents/workstreams.md`): **control signed A6 with exactly one condition on nav** — that
## `Movement.state(unit)` carry `{"active": bool, "why": StringName}` *"so the readout names which level took the
## nose rather than inferring it from geometry"*. control's C-2 readout has been **built and silent** waiting for
## this key while nav waited on control's signature, which control gave hours earlier. Shipping the key breaks that.
##
## **`why` is a CLOSED SET**, refused loudly if something publishes outside it — the same rule as `OFF_NAMES`, and
## for the same reason: a `why` the readout does not know renders as nothing, which is a silent readout that looks
## like a working one.
##   `band` `survival` `armour`   A7's levels, once A6-a/A6-b exist to lose to them. **Nothing publishes these yet.**
##   `arrival_arc`               the hull is on an ordered-facing approach gate. **S4 requires this case by name:**
##                               *"an arrival arc under an ordered facing is off-corridor by construction — those
##                               ticks are flagged by nav's emitter and counted as ordered, never charged to A6's
##                               fraction."* Without it A12 would bill obedience to A6.
##   `yielding`                  X4 right-of-way: the nose is where giving way put it, not where any law wants it.
##   `no_law`                    **no nav-owned motion law exists to run.** A6 is not built, so on the default blend
##                               this is the answer on most ticks. It is the ABSENCE of a cause, not a cause, and
##                               control renders it as nothing.
##   `override`                  **reserved, and nothing publishes it yet:** a nav-owned law RAN and something
##                               outranked it without naming itself. Split from `no_law` after control pointed out
##                               that nav had quietly changed this name's meaning between two messages -- it began
##                               as "something took the nose, unnamed" and became "nothing is shaping the nose",
##                               which are different claims and only the first is attribution. Rendering the second
##                               would have put "no law is running" on thirty units at once and called it an
##                               explanation: C-3's 30-messages failure wearing an explanation's clothes.
##
## `active` is **false until A6 exists**, deliberately. It means *"a nav-owned motion law is shaping the nose"*, and
## no such law is built: A6-a and A6-b are the next commit. A key that reported `active: true` for the route tangent
## would hand control a readout that lights up for behaviour nobody implemented.
## `_agents/legibility.md` §5 assigns the inactive flag AND its reason to nav — *"all five cases are things
## `Movement` already knows, so the flag and its reason come out of the same reading as the corridor"* — and warns
## why: *"An inactive law must never look like a broken law. Round 8 shipped a facing feature that could not fire at
## all on the lead's control scheme (lesson 149) and it read as 'the feature does nothing' rather than 'the feature
## is off.'"* So the set carries the structural reasons as well as the level that took the nose.
##
## **Two of §5's five cases are NOT here, and their absence is deliberate rather than an oversight:** `run_style`
## (the A/B control) and `reflex` (a dodge or a reverse owning the heading for a tick) are **`CombatMotion`'s
## knowledge, not the mover's**, and there is no channel from that layer to this one — the same seam as *THE LEASH
## IS NOT IN THE ROUTE PATH*. They land with A6-a/A6-b on the A7 arm, where the level and the decision are in one
## place. Until then this key never claims to know them, rather than guessing `override`.
const LEGIBILITY_WHY := [&"band", &"survival", &"armour", &"arrival_arc", &"yielding", &"override",
		&"no_law", &"no_order", &"blocked", &"no_path"]


## The pair control's readout reads. Kept to the closed set above, and refused loudly otherwise.
func legibility() -> Dictionary:
	var why := &"no_law"
	if phase == "blocked":
		why = &"blocked"                      # §5: no fallback and no guessed corridor
	elif phase == "yielding":
		why = &"yielding"
	elif phase == "arrived" or _goal == Vector3.INF:
		why = &"no_order"                     # §5: holding, or the task is complete
	elif corridor() == null:
		why = &"no_path"                      # §5: no path yet -- the straight-line fallback
	elif arc_live:
		why = &"arrival_arc"
	# A6 is not built, so nothing nav owns is shaping the nose: `active` stays false and says so.
	var out := {"active": false, "why": why}
	if not LEGIBILITY_WHY.has(why):
		push_error("legibility why=%s is outside the closed set %s: control's readout renders an unknown reason as "
				% [why, LEGIBILITY_WHY] + "nothing, which is a silent readout that looks like a working one.")
	return out


## CP2's second structural consequence, measured: **the navmesh is baked for a hull smaller than most of the
## roster.** `arena.tscn` bakes at `agent_radius = 2.0`, and after the resize **14 of 21 units need more than that**
## — `gang_tank` 4.58 m (2.3x the bake), median 2.50 m, smallest `gang_scout` 1.36 m. So a corridor the mesh
## certifies as clear for a 2.0 m agent is **not** clear for two thirds of the units that will be routed down it.
##
## The bake radius stays 2.0 this round (ruled: raising it to 4.58 would close every alley the two thirds that fit
## can legitimately use, and per-class meshes are a round-10 cost). What nav does instead is **consult the
## shortfall**: publish how much the mesh under-promises for this hull, so routing can refuse or widen rather than
## discovering it by wedging.
##
## Cached once: the bake radius is a property of `arena.tscn`, not of a layout, so every arena in the project shares
## it. `game/arena/` is arena's stream, so nav finds the node rather than asking arena for a hook.
static var _bake_radius := -1.0


static func bake_radius(unit: Node) -> float:
	if _bake_radius >= 0.0:
		return _bake_radius
	var found := -1.0
	if unit != null and unit.is_inside_tree():
		# Taking the FIRST region is safe and was checked rather than assumed: `arena.gd` adds a second region,
		# `NavigationMirror`, but assigns it the SAME `NavigationMesh` resource (`mirror.navigation_mesh = nav_mesh`)
		# rotated by PI — so `agent_radius` is identical whichever one the search meets. If arena ever gives the
		# mirror a mesh of its own, this must pick `$Navigation` by name instead.
		for node in unit.get_tree().get_root().find_children("*", "NavigationRegion3D", true, false):
			var region := node as NavigationRegion3D
			if region != null and region.navigation_mesh != null:
				found = region.navigation_mesh.agent_radius
				break
	if found < 0.0:
		# No arena in the tree (a unit test that never built one). Fall back to the documented expectation rather
		# than to a guess, and say so — a silent fallback here is a mirrored constant wearing a function's clothes.
		return NAV_AGENT_RADIUS
	if absf(found - NAV_AGENT_RADIUS) > 0.001:
		push_error(("the navmesh bakes at agent_radius %.2f but movement.gd expects %.2f. Routing uses the BAKED "
				+ "value; update NAV_AGENT_RADIUS so the cross-check means something again.") % [
				found, NAV_AGENT_RADIUS])
	_bake_radius = found
	return _bake_radius


## How much MORE clearance this hull needs than the navmesh guarantees, in metres. Positive means the mesh
## under-promises: a route it certifies may be too tight. Zero or negative means the hull fits anything the mesh
## calls clear. Post-CP2 this is positive for 14 of 21 units.
static func clearance_shortfall(unit: Node, unit_id: String) -> float:
	return Avoidance.radius_of(unit_id) - bake_radius(unit)


## OPT-IN like every round-9 row: `--nav-off=clearance` turns the routing half ON. The READ and the published
## shortfall are unconditional — they change no behaviour — and only the refusal is switched.
static func clearance_on() -> bool:
	return switched_off("clearance")


## Arm counters (lesson 147): chords where the rule was consulted, and chords it refused for an oversized hull.
## Equal counts mean every hull asked was oversized; zero `clearance_chords` means the rule never ran at all, which
## is the failure this round found six times and must not be confused with "it changed nothing".
static var clearance_chords := 0
static var clearance_refused := 0


## S4 (`_agents/legibility.md` §2): the ordered corridor's TANGENT, which nav promised to publish at N5 *"on the
## principle that one publisher should mean one INTERPRETATION, not one array that three streams each project onto
## slightly differently"*. The law, control's readout and the falsifier all read this rather than each deriving a
## tangent from `path_points`.
##
## It is the **current leg's** direction, flattened and normalised — from the previous waypoint to the next, which
## is the segment the unit's projection lies on. On the first leg there is no previous waypoint, so the leg starts
## where the hull is. **`null` when there is no leg at all**, never a zero vector and never a guess: §5 makes "no
## path yet" an inactive case with a name, and a `Vector3.ZERO` tangent would be an unreadable corridor that looks
## like a readable one.
##
## **READING IT: use `has("corridor")`, never `get("corridor", null)`.** The default-argument form cannot tell *"nav
## answered null"* from *"this build has no such key"*, so a consumer written that way falls through to its own
## fallback on **exactly the ticks where nav said there is no leg** — reinstating the second publisher on the only
## ticks where the two could disagree. control hit this within minutes of adopting the key and reported it
## (2026-09-20); it is the same absent-versus-empty distinction that makes a right-drag leave `facing` *absent*
## rather than empty. Sending `null` only works if the reader uses `has`.
func corridor() -> Variant:
	# Gated on the SAME condition `reading()` uses to empty `path_points`, not on a similar-looking one. `idle()`
	# does not clear `_path`, so a corridor keyed only on the path index would publish a tangent for a leg whose
	# `path_points` is already empty -- this key disagreeing with the array it is the interpretation OF, which is
	# the exact failure §2 asks nav to prevent by publishing it at all.
	if phase == "arrived" or _path_index >= _path.size() or ctl.tank == null:
		return null
	var to: Vector3 = _path[_path_index]
	var from: Vector3 = _path[_path_index - 1] if _path_index >= 1 else ctl.tank.global_position
	var leg := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if leg.length_squared() < 0.0001:
		return null
	return leg.normalized()


## S3 (metrics' contract, `tools/metrics/FORMAT.md`): is the arrival ARC live on THIS tick — is the hull being
## steered at an approach gate so it can come onto the ordered heading? metrics' emitter reads this as an OPTIONAL
## key and writes `null` until nav publishes it, deliberately never `false`, *"because a column that quietly says
## 'no arc' on every tick is exactly how a falsifier ends up charging A6 for obedience while looking like it had the
## data"*. Until this commit it WAS null, and `make metrics` printed `arc_live=0.0s` in both arms of nav's own A4
## A/B — a zero that reads like a measurement and was an unpublished field.
##
## Set every tick the mover steps (`drive`) and cleared by `idle()`, so it can never go stale: a hull that stopped
## driving is not on an arc, and a stale `true` would be counted as arc seconds it never spent.
var arc_live := false


func reading() -> Dictionary:
	var eta_s := -1.0
	var points := PackedVector3Array()
	if phase != "arrived" and ctl.tank != null:
		eta_s = _remaining / (maxf(ctl.tank.max_forward_speed, 0.1) * ETA_CRUISE_SHARE)
		if _path_index < _path.size():
			points = _path.slice(_path_index)
	return {"phase": phase, "eta_s": eta_s, "remaining_m": _remaining if phase != "arrived" else 0.0,
			"path_points": points, "blocked_by": blocked_by if phase == "blocked" or phase == "yielding" else "",
			"yield_to": yield_to, "reachable": _reachable, "route_end_gap_m": float(_route_reading.get("end_gap_m", 0.0)),
			"goal_gap_m": float(_route_reading.get("goal_gap_m", 0.0)), "steer_to": steer_to if steer_to != Vector3.INF else null, "pace": pace_now,
			"goal": _goal if _goal != Vector3.INF else null,
			"facing_arc": arc_live, "legibility": legibility(), "corridor": corridor(),
			"clearance_shortfall_m": clearance_shortfall(ctl.tank, ctl.tank.unit_id) if ctl.tank != null else 0.0,
			"stalled_s": float(stalled_ticks) / float(SimClock.TICK_RATE), "replan": last_replan, "wedged": wedged,
			"wedge_moved_m": wedge_moved_m, "wedge_hull_m": wedge_hull_m,
			"wedge_ratio": wedge_moved_m / maxf(wedge_hull_m, 0.1)}


## A new order: drop the unstick routine, the old path, the fire detour and the stall bookkeeping, so the new order
## drives this very tick (K1 response guarantee).
func reset() -> void:
	_fire_detour = null
	_fire_detour_again = 0
	_fire_since = -1
	_unstick_left = 0.0
	_stuck_time = 0.0
	_repath_left = 0.0
	stalled_ticks = 0
	_progress_goal = Vector3.INF
	yield_to = ""  # a new order outranks giving way (K1 response guarantee)
	_order_ticks = 0


## How close a hull of `unit_id` can settle on a point: 0 for tracks and hover (they pivot), and for wheels
## WHEELS_SETTLE_RADII of the minimum turning radius, at most WHEELS_SETTLE_MAX. The one place this is decided: an order
## that asks for tighter is widened to it, and a decider asking "is it there?" should ask this (TankBrain's
## _order_arrive states the same numbers today).
static func settle_radius(unit_id: String) -> float:
	if String(Units.stat(unit_id, "locomotion", "tracks")) != "wheels":
		return 0.0
	var radius := maxf(float(Units.stat(unit_id, "min_turn_radius_m", 0.0)), 0.5)
	return minf(radius * WHEELS_SETTLE_RADII, WHEELS_SETTLE_MAX)


## Is this unit driving somewhere (anything but arrived)? Avoidance gives a still unit no share of the avoiding.
func is_under_way() -> bool:
	return phase != "arrived"


## Make this mover the one Movement.state(tank) reads (the composer calls it every tick: a dictionary lookup).
func bind() -> void:
	var id := ctl.tank.get_instance_id()
	if _registry.get(id) != self:
		_registry[id] = self


## Forget the route (a new move order): the next drive() repaths at once.
func new_order() -> void:
	_repath_left = 0.0
	_reissued = true


## The move order isn't a move_to (stop, face, drive, or a dead hull): nothing to report but "arrived".
func idle() -> void:
	yield_to = ""
	arc_live = false
	stalled_ticks = 0
	phase = "arrived"
	blocked_by = ""
	_goal = Vector3.INF
	_remaining = 0.0


## Execute a move_to: fill cmd's throttle and turn for this tick.
func drive(cmd: TankCommand, order: Dictionary, delta: float) -> void:
	var tank := ctl.tank
	var goal := Vector3(order["x"], 0.0, order["z"])
	if _goal == Vector3.INF or _flat_distance(goal, _goal) > NEW_GOAL_JUMP:
		_order_ticks = 0  # a new destination, not a slot sliding along (brains re-issue their move every think)
	_goal = goal
	_track_goal(goal)
	_order_ticks += ctl._step
	# `direct`: the brain already checked the straight line (CombatMotion's short hops), so skip the navmesh path.
	var direct: bool = order.get("direct", false)
	var lap := Time.get_ticks_usec() if OrderController.profile_detail else 0
	# Round 8: a wheeled hull that was told which way to face arrives ALREADY facing it, by driving the last stretch
	# along that heading, instead of arriving and then creeping round for ~6 s (measured: an IFV 45 degrees off).
	var aim := _approach_gate(goal, order)
	# The gate is offset from the goal by at least APPROACH_MIN, so "a gate was aimed" and "the goal came back
	# unchanged" cannot be confused. This is the one place that knows, and it used to keep it nowhere.
	arc_live = aim != goal
	var routed := aim if direct else _next_waypoint(aim, delta)
	lap = OrderController._lap("move.path", lap)
	var around_fire := _around_fire(routed, goal, order)
	lap = OrderController._lap("move.fire", lap)
	var waypoint := around_fire
	if _off.has("r5sidestep"):
		waypoint = _around_friends(around_fire)
	var speed_factor := clampf(float(order.get("speed", 1.0)), 0.2, 1.0)
	# A car can't settle on a point much closer than a share of its turning circle without circling it (round 7: IFVs
	# told to re-seat within 1.5 m hunted back and forth round their spot for 10 s and never turned to their facing).
	_arrive = maxf(clampf(float(order.get("arrive", OrderController.ARRIVE_RADIUS)), 0.5, 10.0),
			settle_radius(tank.unit_id) if wheel_radius() > 0.0 else 0.0)
	var arrive := _arrive if around_fire == goal else 0.5
	var remaining := _flat_distance(tank.global_position, goal) if direct else _remaining_path_distance(goal)
	_remaining = remaining
	lap = OrderController._lap("move.remaining", lap)
	var pace := 1.0
	if avoidance_on and not order.get("reverse", false) and ctl.tanks_root != null \
			and _flat_distance(tank.global_position, around_fire) > arrive:
		var avoided := _avoid(waypoint, speed_factor, delta)
		if avoided[0] != waypoint:
			arrive = 0.1  # steering at an avoiding point, not the goal: never "arrive" at it
		waypoint = avoided[0]
		pace = avoided[1]
	if not direct and waypoint != goal and not _off.has("guard"):
		waypoint = _guard_steer(tank.global_position, waypoint)
	lap = OrderController._lap("move.friends", lap)
	var drive_vector: Vector2
	var radius := wheel_radius()
	if radius > 0.0:
		# K3 wheels drive like cars: pure pursuit, three-point turns (Steering.drive_toward_wheels).
		# Direct calls rather than a Callable picked every tick (round-5 X1).
		if order.get("reverse", false):
			drive_vector = Steering.reverse_toward_wheels(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
		else:
			drive_vector = Steering.drive_toward_wheels(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
	elif order.get("reverse", false):
		drive_vector = Steering.reverse_toward(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
	else:
		drive_vector = Steering.drive_toward(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
	cmd.throttle = drive_vector.x * speed_factor * pace
	cmd.turn = drive_vector.y
	steer_to = waypoint
	pace_now = pace
	_note_wedge(tank.global_position, pace < 0.999)
	if station_on and not direct and not order.get("reverse", false) and pace >= 0.99 and waypoint == goal \
			and remaining <= STATION_RANGE and _goal_velocity.length() >= STATION_MIN_SPEED:
		drive_vector = _keep_station(cmd, goal, delta)
	elif _station != null:
		_station.reset()
	_track_progress(goal, drive_vector, remaining)
	_update_phase(goal, drive_vector, direct)
	# Asking: after ASK_SECONDS without progress, whoever is in the way; and AT ONCE when avoidance is holding this
	# unit back behind a friend that is going nowhere (StarCraft's "idle units get pushed aside": a parked unit should
	# not cost a moving one a second of standing still before it asks).
	var held_back := pace < AVOID_ASK_PACE and _order_ticks >= AVOID_GRACE_TICKS and not _off.has("pushidle")
	if stalled_ticks >= int(ASK_SECONDS * SimClock.TICK_RATE) or held_back:
		_ask_left -= ctl._step
		if _ask_left <= 0:
			_ask_left = int(ASK_EVERY_SECONDS * SimClock.TICK_RATE)
			_negotiate(goal, direct, stalled_ticks < int(ASK_SECONDS * SimClock.TICK_RATE))
	else:
		_ask_left = 0
	OrderController._lap("move.steer", lap)


## Feed the wedged window one tick: was avoidance shaping this hull, and where is it now.
func _note_wedge(here: Vector3, deflected: bool) -> void:
	_deflect_window.append(deflected)
	_wedge_trail.append(here)
	if _deflect_window.size() > WEDGED_WINDOW:
		_deflect_window.remove_at(0)
		_wedge_trail.remove_at(0)
	if _deflect_window.size() < WEDGED_WINDOW:
		wedged = false
		return
	var hits := 0
	for flag: bool in _deflect_window:
		hits += 1 if flag else 0
	var moved := _flat_distance(_wedge_trail[0], _wedge_trail[_wedge_trail.size() - 1])
	var size: Variant = Units.stat(ctl.tank.unit_id, "hull_size", [2.4, 1.6, 3.8])
	var was := wedged
	wedge_moved_m = moved
	wedge_hull_m = float(size[2])
	wedged = float(hits) / float(WEDGED_WINDOW) > WEDGED_SHARE and moved < float(size[2])
	if wedged and not was:
		wedged_units += 1


## X6: how fast the goal is moving, from how far it moved between changes (brains re-issue a slot a few times a
## second, so per-tick deltas are mostly zero with a jump in between). A goal that jumps further than a slot could
## travel is a new order, not motion.
func _track_goal(goal: Vector3) -> void:
	_ticks += ctl._step
	var reissued := _reissued
	_reissued = false
	if _goal_seen == Vector3.INF:
		_goal_seen = goal
		_goal_changed_at = _ticks
		_goal_velocity = Vector2.ZERO
		return
	var moved := Vector2(goal.x - _goal_seen.x, goal.z - _goal_seen.z)
	var seconds := float(_ticks - _goal_changed_at) / float(SimClock.TICK_RATE)
	if moved.length_squared() > 0.0001:
		var velocity := moved / maxf(seconds, 1.0 / float(SimClock.TICK_RATE))
		_goal_velocity = Vector2.ZERO if velocity.length() > 2.0 * ctl.tank.max_forward_speed else velocity
		_goal_seen = goal
		_goal_changed_at = _ticks
	elif seconds > STATION_STALE_SECONDS or (reissued and seconds > STATION_STOPPED_SECONDS):
		# Re-issued where it already was: the slot has stopped. Feed-forward must stop with it at once, or a crew runs
		# ~3 m past a halting formation on a stale speed (measured, X8: 3.2 m for every gain set before this).
		_goal_velocity = Vector2.ZERO


## X6: keep station on a moving goal. Throttle = (the goal's speed along my heading + PID on the along-track gap) /
## top speed; the derivative acts on the gap's own rate (my speed relative to the goal's), so a slot that jumps
## doesn't kick. Steers at where the goal is heading. Returns the drive vector it used.
func _keep_station(cmd: TankCommand, goal: Vector3, delta: float) -> Vector2:
	var tank := ctl.tank
	var faction := String(Units.stat(tank.unit_id, "faction", ""))
	if _station == null or faction != _station_faction:
		_station = Pid.new(ControlGains.for_loop("station", faction))
		_station_faction = faction
	var here := tank.global_position
	var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var gap := Vector2(goal.x - here.x, goal.z - here.z)
	var along := gap.dot(forward)
	var feed_forward := _goal_velocity.dot(forward)
	var my_speed := tank.speed()
	var correction := _station.step_with_rate(along, my_speed - feed_forward, delta)
	var wanted := feed_forward + correction
	var ahead := Vector3(goal.x + _goal_velocity.x * STATION_LEAD_SECONDS, 0.0,
			goal.z + _goal_velocity.y * STATION_LEAD_SECONDS)
	var drive_vector := Steering.drive_toward(here, -tank.global_basis.z, ahead, 0.3)
	cmd.turn = drive_vector.y
	cmd.throttle = clampf(wanted / maxf(tank.max_forward_speed, 0.1), -0.5, 1.0)
	return Vector2(cmd.throttle, cmd.turn)


## N1: what this tick amounts to. Arrived when steering has nothing left to do, blocked after BLOCKED_SECONDS without
## progress (with the cause), pathing while the navmesh isn't ready, else driving.
func _update_phase(goal: Vector3, drive_vector: Vector2, direct: bool) -> void:
	if drive_vector == Vector2.ZERO and _flat_distance(ctl.tank.global_position, goal) <= _arrive + 0.5:
		phase = "arrived"
		blocked_by = ""
		return
	if not _reachable and not direct and not _path.is_empty() \
			and _flat_distance(ctl.tank.global_position, _path[_path.size() - 1]) <= UNREACHABLE_AT_END:
		# As near as the navmesh goes: say so now rather than after BLOCKED_SECONDS of grinding.
		phase = "blocked"
		blocked_by = "no_path"
		return
	if stalled_ticks >= int(BLOCKED_SECONDS * SimClock.TICK_RATE):
		# The cause is re-read twice a second, not every tick (it walks the neighbours).
		_blocker_left -= ctl._step
		if phase != "blocked" or _blocker_left <= 0:
			_blocker_left = SimClock.TICK_RATE / 2
			blocked_by = _blocker(goal, direct)
		phase = "blocked"
		return
	blocked_by = ""
	if not direct and Pathing.enabled and _path.is_empty() and not Pathing.is_ready(ctl.tank):
		phase = "pathing"
	else:
		phase = "driving"


# ---- X4: right-of-way (the lead's peer-to-peer "move out of the way") ---------------------------------------------

## The composer calls this first every tick: true when this unit is giving way, and `cmd` has been filled for it.
func right_of_way(cmd: TankCommand, delta: float) -> bool:
	if yield_to == "":
		return false
	var tank := ctl.tank
	var here := tank.global_position
	_yield_left -= ctl._step
	var asker := ctl.tanks_root.get_node_or_null(NodePath(yield_to)) as Tank if ctl.tanks_root != null else null
	var there := _flat_distance(here, _yield_point) <= YIELD_REACHED
	if there:
		_yield_held += ctl._step
	var passed := asker == null or not asker.is_alive() or _flat_distance(here, asker.global_position) > YIELD_CLEAR \
			or Vector2(asker.global_position.x - here.x, asker.global_position.z - here.z).dot(_yield_dir) > 0.0
	var asker_mover := Movement.of(asker) if asker != null else null
	if asker_mover != null and not asker_mover.is_under_way():
		passed = true
	if _yield_left <= 0 or (passed and (there or _yield_held >= int(YIELD_HOLD_SECONDS * SimClock.TICK_RATE))):
		_end_yield()
		return false
	phase = "yielding"
	blocked_by = yield_to
	if not there:
		var drive_vector := Steering.drive_toward(here, -tank.global_basis.z, _yield_point, YIELD_REACHED * 0.5)
		if wheel_radius() > 0.0:
			if _straight_behind(_yield_point):
				drive_vector = Steering.reverse_toward_wheels(here, -tank.global_basis.z, _yield_point, YIELD_REACHED * 0.5,
						wheel_radius(), tank.speed())
			else:
				drive_vector = Steering.drive_toward_wheels(here, -tank.global_basis.z, _yield_point, YIELD_REACHED * 0.5,
						wheel_radius(), tank.speed())
		elif _straight_behind(_yield_point):
			drive_vector = Steering.reverse_toward(here, -tank.global_basis.z, _yield_point, YIELD_REACHED * 0.5)
		cmd.throttle = drive_vector.x * 0.7
		cmd.turn = drive_vector.y
	return true


## Another unit asks this one to give way: `asker` wants to go along `direction` from `from`. True when this unit
## found a validated spot and is giving way; false when it can't (it is already giving way, it just gave way to the
## same asker, or there is no room) — and then the asker gives way itself.
func ask(asker: String, from: Vector3, direction: Vector2) -> bool:
	if yield_to != "" or asker == _last_yielded_to:
		return false
	if _begin_yield(asker, from, direction):
		return true
	asks_refused += 1
	return false


func _end_yield() -> void:
	_last_yielded_to = yield_to
	yield_to = ""
	_yield_point = Vector3.INF
	blocked_by = ""
	phase = "driving"
	stalled_ticks = 0
	_progress_goal = Vector3.INF
	_repath_left = 0.0


## Give way to `other`, travelling along `direction` from `from`: find the nearest validated spot off its line.
func _begin_yield(other: String, from: Vector3, direction: Vector2) -> bool:
	var tank := ctl.tank
	var here := tank.global_position
	var along := direction.normalized() if direction.length_squared() > 0.0001 else \
			Vector2(here.x - from.x, here.z - from.z).normalized()
	if along == Vector2.ZERO:
		return false
	var across := Vector2(-along.y, along.x)
	# Step off to the side of its line I'm already on (ties: its left), so I never cut across its bow.
	var side := 1.0 if across.dot(Vector2(here.x - from.x, here.z - from.z)) >= 0.0 else -1.0
	var other_tank := ctl.tanks_root.get_node_or_null(NodePath(other)) as Tank if ctl.tanks_root != null else null
	var other_radius := Avoidance.radius_of(other_tank.unit_id) if other_tank != null else 1.8
	var line_clear := Avoidance.radius_of(tank.unit_id) + other_radius + YIELD_LINE_MARGIN
	Avoidance.refresh(ctl.tanks_root)
	for spot: Vector2 in YIELD_SPOTS:
		for flip: float in ([side, -side] if spot.y != 0.0 else [side]):
			var offset := along * spot.x + across * (spot.y * flip)
			var point := Vector3(here.x + offset.x, 0.0, here.z + offset.y)
			if spot.y != 0.0 and _distance_to_ray(point, from, along) < line_clear:
				continue
			# Never give way TOWARD the unit being let past (backing into it is how two units end up nose to tail).
			if _flat_distance(point, from) < _flat_distance(here, from):
				continue
			# Wheels can't pivot: a spot inside the turning circle is a three-point turn. A car takes a spot it can
			# drive forward onto, or one straight behind it (reversing in a straight line is what a car CAN do).
			if wheel_radius() > 0.0 and not _ahead_of_wheels(point) and not _straight_behind(point):
				continue
			if not _free_spot(point, String(tank.name), other):
				continue
			_start_yield(other, point, along)
			return true
	if _off.has("backup"):
		return false
	# Last resort (round 7, nav-fight: two cars nose to nose for 30 s with no legal spot): back straight up along my own
	# hull, as long as that isn't toward the unit being let past.
	var back := Vector2(tank.global_basis.z.x, tank.global_basis.z.z).normalized()
	for distance: float in YIELD_BACK_UP:
		var point := Vector3(here.x + back.x * distance, 0.0, here.z + back.y * distance)
		if _flat_distance(point, from) < _flat_distance(here, from):
			continue
		if _free_spot(point, String(tank.name), other):
			_start_yield(other, point, along)
			return true
	return false


func _start_yield(other: String, point: Vector3, along: Vector2) -> void:
	yield_to = other
	_yield_point = point
	_yield_dir = along
	_yield_left = int(YIELD_MAX_SECONDS * SimClock.TICK_RATE)
	_yield_held = 0
	phase = "yielding"
	blocked_by = other
	yields_started += 1


## Is `point` straight behind this hull (within ~25 degrees of its tail)? A car reaches that by reversing.
func _straight_behind(point: Vector3) -> bool:
	var tank := ctl.tank
	var to := Vector2(point.x - tank.global_position.x, point.z - tank.global_position.z)
	var back := Vector2(tank.global_basis.z.x, tank.global_basis.z.z)
	return to.length_squared() > 0.01 and back.normalized().dot(to.normalized()) >= 0.9


## A wheeled hull can drive forward onto `point` (it is outside both turning circles and not behind it).
func _ahead_of_wheels(point: Vector3) -> bool:
	var tank := ctl.tank
	var here := tank.global_position
	var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var to := Vector2(point.x - here.x, point.z - here.z)
	if to.dot(forward) <= 0.0:
		return false
	var left := Vector2(forward.y, -forward.x)
	var radius := wheel_radius()
	for side: float in [1.0, -1.0]:
		if (to - left * side * radius).length() < radius:
			return false
	return true


## A spot on the navmesh, with no hull but `me` and `other` within YIELD_SPOT_CLEARANCE.
func _free_spot(point: Vector3, me: String, other: String) -> bool:
	var tank := ctl.tank
	if Pathing.enabled and Pathing.is_ready(tank):
		var on_mesh := NavigationServer3D.map_get_closest_point(tank.get_world_3d().navigation_map, point)
		if _flat_distance(on_mesh, point) > YIELD_MESH_SLACK:
			return false
	for row: Array in Avoidance.neighbours(me, point.x, point.z):
		if String(row[1]) != other and sqrt(float(row[0])) < YIELD_SPOT_CLEARANCE:
			return false
	return true


## Flat distance from `point` to the ray from `origin` along `direction` (unit), behind the origin = to the origin.
static func _distance_to_ray(point: Vector3, origin: Vector3, direction: Vector2) -> float:
	var offset := Vector2(point.x - origin.x, point.z - origin.z)
	var t := maxf(offset.dot(direction), 0.0)
	return (offset - direction * t).length()


## Stalled: the friend in my way is asked to give way, or I give way to it. Who gives way is decided by a rule both
## units compute the same way — a unit going nowhere always gives way to one going somewhere; between two movers, the
## one with less of its route left gives way (it has less to lose), and the unit name breaks a tie — so the two never
## both wait and never both go.
func _negotiate(goal: Vector3, direct: bool, still_only := false) -> void:
	if _off.has("yield"):
		return
	var tank := ctl.tank
	var name := _hull_ahead(goal, direct)
	if name == "":
		return
	var other := ctl.tanks_root.get_node_or_null(NodePath(name)) as Tank
	if other == null or other.team != tank.team:
		return  # an enemy can't be asked
	var mover := Movement.of(other)
	if mover == null or mover.yield_to != "":
		return  # the player's own hull, or it is already giving way to someone
	if still_only and mover.is_under_way():
		return  # held back by a mover: avoidance is sharing that out; only a stall makes it a negotiation
	var here := tank.global_position
	var my_way := _travel_direction(goal, direct)
	var i_give_way := false
	if mover.is_under_way():
		var difference := _remaining - mover._remaining
		i_give_way = difference < -PRIORITY_MARGIN or (absf(difference) <= PRIORITY_MARGIN and String(tank.name) < name)
	if mover._last_yielded_to == String(tank.name):
		i_give_way = true  # it gave way to me last time: my turn
	if not i_give_way and mover.ask(String(tank.name), here, my_way):
		return
	if _last_yielded_to == name:
		return  # never twice in a row to the same unit: unstick and avoidance carry on
	var its_way := mover._travel_direction(mover._goal, false) if mover.is_under_way() else Vector2.ZERO
	if its_way == Vector2.ZERO:
		its_way = Vector2(here.x - other.global_position.x, here.z - other.global_position.z)
	_begin_yield(name, other.global_position, its_way)


## The flat direction this unit is trying to go: toward its next waypoint (or the goal).
func _travel_direction(goal: Vector3, direct: bool) -> Vector2:
	var here := ctl.tank.global_position
	var toward := _path[_path_index] if _path_index < _path.size() and not direct else goal
	if toward == Vector3.INF:
		return Vector2.ZERO
	var flat := Vector2(toward.x - here.x, toward.z - here.z)
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector2.ZERO


## The nearest hull ahead within BLOCKER_REACH, or "".
func _hull_ahead(goal: Vector3, direct: bool) -> String:
	var name := _blocker(goal, direct)
	return "" if name in ["no_path", "terrain"] else name


## What this unit is up against: the nearest hull ahead of it within BLOCKER_REACH (friend or enemy), else "no_path"
## when its route doesn't reach the goal, else "terrain".
func _blocker(goal: Vector3, direct: bool) -> String:
	var tank := ctl.tank
	var here := tank.global_position
	var toward := (_path[_path_index] if _path_index < _path.size() and not direct else goal) - here
	toward.y = 0.0
	if toward.length_squared() < 0.01:
		toward = -tank.global_basis.z
	toward = toward.normalized()
	var best := ""
	var best_distance := BLOCKER_REACH
	if ctl.tanks_root != null:
		for other in ctl.tanks_root.get_children():
			var hull := other as Tank
			if hull == null or hull == tank or not hull.is_alive():
				continue
			var offset := hull.global_position - here
			offset.y = 0.0
			var distance := offset.length()
			if distance >= best_distance or distance < 0.01:
				continue
			if offset.dot(toward) / distance < BLOCKER_AHEAD_COS:
				continue
			best = String(hull.name)
			best_distance = distance
	if best != "":
		return best
	if not direct and not _path.is_empty() and _flat_distance(_path[_path.size() - 1], goal) > NO_PATH_MARGIN:
		return "no_path"
	return "terrain"


## X3 (L2): a route through a wall of bullets is stepped around. The lead: *"vehicles make decisions to avoid walking
## into a wall of bullets that will kill them."* Navmesh paths know nothing about fire, and this is where every move
## passes — an order, an element's bound, a drill — so it is the one place that covers all of them. Sides are tried
## nearest first; if every way through is swept it goes anyway, because standing still in the open is worse.
func _around_fire(waypoint: Vector3, goal: Vector3, order: Dictionary) -> Vector3:
	var brain := ctl as TankBrain
	var tank := ctl.tank
	if brain == null or brain.game_match == null \
			or not bool(BrainVariants.for_team(tank.team).get("avoid_beaten", true)):
		return waypoint
	# A move that IS the escape (running to cover, breaking contact) is driven as given: re-routing it round the fire
	# is how a hurt tank ends up never reaching the cover it was running to.
	if bool(order.get("to_safety", false)):
		return waypoint
	var fields := brain._suppression_fields(brain.game_match)
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
	var stride := ctl._stride
	if _fire_detour == null:
		# Under execution LOD the check can't wait for an exact multiple of FIRE_CHECK_TICKS (it may be an off tick):
		# it runs on the first executed tick at least FIRE_CHECK_TICKS - 1 after the last one instead.
		if stride == 1 and (tick + brain.think_offset) % FIRE_CHECK_TICKS != 0:
			return waypoint
		# Under a controller stride the check can't wait for an exact multiple (that tick may not run): it looks on the
		# first run at least FIRE_CHECK_TICKS after the last look.
		if stride > 1 and tick - _fire_checked_tick < FIRE_CHECK_TICKS:
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
			OrderController.fire_detours += ctl._step
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
		OrderController.fire_detours += ctl._step
		return best
	# Looked and found nothing: every way round is swept too. Push on rather than looking again every few ticks.
	OrderController.fire_no_way_round += 1
	_fire_since = -1
	_fire_detour_again = tick + FIRE_DETOUR_COOLDOWN
	return waypoint


## X3: ORCA. [the point to steer at, the share of the drive's speed to keep]. The preferred velocity is the route's
## (toward `waypoint` at this order's speed, easing off for the end of the route); Avoidance returns the nearest
## velocity that keeps clear of every neighbour, sharing the avoiding with movers. A velocity that would take the hull
## off the navmesh is refused (static geometry wins): the unit keeps its route and slows to the avoiding speed instead.
func _avoid(waypoint: Vector3, speed_factor: float, delta: float) -> Array:
	var tank := ctl.tank
	var here := tank.global_position
	var to := Vector2(waypoint.x - here.x, waypoint.z - here.z)
	var distance := to.length()
	if distance < 0.5:
		return [waypoint, 1.0]
	Avoidance.refresh(ctl.tanks_root)
	var slow := clampf(_remaining / Steering.SLOW_RADIUS, 0.35, 1.0)
	var desired := tank.max_forward_speed * speed_factor * slow
	var preferred := to / distance * desired
	var chosen := Avoidance.solve(String(tank.name), Vector2(here.x, here.z),
			Vector2(tank.estimated_velocity.x, tank.estimated_velocity.z), preferred, tank.max_forward_speed,
			Avoidance.radius_of(tank.unit_id), delta)
	if chosen.distance_squared_to(preferred) < 0.04:
		return [waypoint, 1.0]
	var speed := chosen.length()
	var keep := clampf(speed / maxf(desired, 0.1), 0.0, 1.0)
	# K1's response guarantee (100 ms = 3 ticks) outranks avoidance: an order takes effect at once and avoidance only
	# SHAPES the movement. So for a moment after a new order the hull steers along its route (avoidance can't turn it
	# away from where it was told to go before it has visibly gone), and it never sits at zero throttle while the way on
	# is merely crowded rather than reversed — it creeps (soft nudging is fine: vehicles are vehicles), and right-of-way
	# sorts out who goes first.
	var starting := _order_ticks < AVOID_GRACE_TICKS
	# The creep is only for the start of an order (that is what K1 measures). Kept on afterwards it measured as
	# pushing into crowds: head-on maze-60's last arrival 182 s with it, 163 s without (builder0, 639071f2+).
	if starting and chosen.dot(preferred) > 0.0 and not _off.has("minpace"):
		keep = maxf(keep, AVOID_MIN_PACE)
	if (starting and not _off.has("grace")) or speed < 0.3:
		return [waypoint, keep]
	var direction := chosen / speed
	var probe := Vector3(here.x + direction.x * AVOID_MESH_PROBE, 0.0, here.z + direction.y * AVOID_MESH_PROBE)
	if Pathing.enabled and Pathing.is_ready(tank):
		var on_mesh := NavigationServer3D.map_get_closest_point(tank.get_world_3d().navigation_map, probe)
		# ROUND 9, BUILT AND REVERTED AS A MEASURED NULL (round 8's precedent: a null comes out with its switch).
		# The theory: in a corridor nearly every avoiding velocity leaves the mesh, so this fallback becomes a
		# permanent slow — and the fix was to walk the velocity back toward the route until the probe accepts.
		# **It fires TWICE in a 70 s defile run** (2 refusals against 2249 solved ticks), the rescue changed
		# **nothing** (identical arrivals, identical 40.57 s dispersion, artillery still never arriving), so it went.
		#
		# The mistake behind the theory is the part worth keeping: `Avoidance.deflected` at 58% counts ORCA
		# **shaping** the velocity, which is its job. It does **not** count this refusal. Two quantities, one name.
		if _flat_distance(on_mesh, probe) > AVOID_MESH_SLACK:
			return [waypoint, keep]
	# Wheels steer by curvature: a point inside the turning circle is a three-point turn (backing up), so an avoiding
	# point is never nearer than the route's own carrot for them.
	var reach := wheel_radius() * WHEELS_LOOKAHEAD_RADII
	var look := clampf(distance, maxf(AVOID_STEER_MIN, reach), maxf(AVOID_STEER_MAX, reach))
	var point := Vector3(here.x + direction.x * look, 0.0, here.z + direction.y * look)
	if wheel_radius() > 0.0 and not _ahead_of_wheels(point):
		return [waypoint, keep]  # a car can't swerve onto a point inside its turning circle: keep the route, slow down
	return [point, keep]


## Measuring only (`--nav-off=r5sidestep` turns it ON): round 5's local avoidance, kept to attribute differences.
## Local avoidance: a friend parked in the way within AVOID_LOOKAHEAD meters (within AVOID_WIDTH of the line to the
## waypoint) is passed beside, AVOID_CLEARANCE meters off its center on the side the line already leans to. Navmesh paths
## ignore units, move_and_slide stops a hull against another, and wheels can't pivot round one (a wheeled IFV looped its
## unstick routine against a parked tank for 8 s). Brains only (they share the per-tick tank table).
func _around_friends(waypoint: Vector3) -> Vector3:
	const AVOID_LOOKAHEAD := 10.0
	const AVOID_WIDTH := 3.2
	const AVOID_CLEARANCE := 5.0
	var brain := ctl as TankBrain
	if brain == null or brain.game_match == null:
		return waypoint
	var tank := ctl.tank
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
func wheel_radius() -> float:
	var tank := ctl.tank
	if _wheel_radius_unit != tank.unit_id:
		_wheel_radius_unit = tank.unit_id
		_wheel_radius_value = 0.0
		if String(Units.stat(tank.unit_id, "locomotion", "tracks")) == "wheels":
			_wheel_radius_value = maxf(float(Units.stat(tank.unit_id, "min_turn_radius_m", 0.0)), 0.5)
	return _wheel_radius_value


## Counts ticks without getting at least 0.5 m closer (along the path) to the current move goal. `remaining` is the
## distance the caller already worked out for steering — computing it again here walked the whole path a second time
## every tick for every moving unit (X2).
func _track_progress(goal: Vector3, drive_vector: Vector2, remaining: float) -> void:
	if _flat_distance(goal, _progress_goal) > 2.0 or drive_vector == Vector2.ZERO:
		_progress_goal = goal
		_progress_best = remaining
		stalled_ticks = 0
	elif remaining < _progress_best - 0.5:
		_progress_best = remaining
		stalled_ticks = 0
	else:
		stalled_ticks += ctl._step


## The point this move should ROUTE to: the goal itself, or, for a wheeled hull with a `facing` in its order, a gate one
## approach-length short of the goal along that heading. Driving to the gate first turns the last leg into a straight run
## onto the ordered heading — the only way a car can arrive pointing a given way, since it cannot pivot once it is there
## (the contract is in _agents/workstreams.md; squad populates `facing`). Arrival is still judged on the goal: this only
## changes what the route aims at on the way. The gate is abandoned when it is off the navmesh, when the hull is already
## on the approach, or once the hull has reached it.
## 2.5 turning radii: pure pursuit needs about two radii of straight to settle onto a line, plus the gate tolerance.
## Measured at 1.5 radii an IFV still arrived 63 degrees off (dot 0.45) and at 3.5 it did not reach the goal at all.
const APPROACH_RADII := 2.5
const APPROACH_MIN := 4.0
const APPROACH_MAX := 20.0
const APPROACH_ALIGNED_COS := 0.85


## Measuring only, and counted per PLAN TICK, not per order: how many wheeled plans were OFFERED a facing at all, how
## many of those AIMED at a gate, and how many were REFUSED it (with the reason). An arrival arc that never fires looks
## exactly like one that does nothing from outside, and round 8's facing A/B could not tell those apart: it read
## `gates aimed 0, gates refused 0` in both arms, which turned out to mean *no order in a CPU fight carries a facing* —
## an instrument failure, not a finding about the arc. `offered` is the number that distinguishes them, and
## `offered == aimed + refused` always holds (a test asserts it).
static var gates_offered := 0
static var gates_aimed := 0
static var gates_refused := 0
## ...and why each refusal happened: "bad_facing", "reached", "on_approach", "off_mesh". squad predicted that an
## element's 6.5 m assembly spacing refuses most slot gates against a ~17 m approach; that prediction is falsifiable
## only because the reason is recorded.
static var gate_refusals := {}


## The counter, as one reading (nav-fight reports this; the tests diff it).
static func gate_report() -> Dictionary:
	return {"offered": gates_offered, "aimed": gates_aimed, "refused": gates_refused,
			"refusals": gate_refusals.duplicate(), "off_mesh_fit": gate_off_mesh_fit.duplicate(),
			"a4": a4_report()}


## Tests only: zero the gate counters so one case's numbers are its own.
static func reset_gates() -> void:
	gates_offered = 0
	gates_aimed = 0
	gates_refused = 0
	gate_refusals = {}
	gate_off_mesh_fit = {}
	a4_curved_gates = 0
	a4_rescued_blocked = 0
	a4_refused_curvature = 0


## Count a refusal and keep the goal: the route aims at the goal itself, as it did before round 8.
static func _gate_refused(reason: String, goal: Vector3) -> Vector3:
	gates_refused += 1
	gate_refusals[reason] = int(gate_refusals.get(reason, 0)) + 1
	return goal


func _approach_gate(goal: Vector3, order: Dictionary) -> Vector3:
	var radius := wheel_radius()
	if radius <= 0.0 or not order.has("facing"):
		return goal  # not offered: a tracked or hover hull pivots, and an order with no facing asks for nothing
	gates_offered += 1
	var facing: Variant = order["facing"]
	if not (facing is Array) or (facing as Array).size() < 2:
		return _gate_refused("bad_facing", goal)
	var direction := Vector2(float(facing[0]), float(facing[1]))
	if direction.length_squared() < 0.0001:
		return _gate_refused("bad_facing", goal)
	direction = direction.normalized()
	var length := clampf(radius * APPROACH_RADII, APPROACH_MIN, APPROACH_MAX)
	var gate := Vector3(goal.x - direction.x * length, 0.0, goal.z - direction.y * length)
	var tank := ctl.tank
	var here := tank.global_position
	if _flat_distance(here, gate) <= _arrive_gate():
		# At the gate: the straight run onto the heading IS the rest of the move.
		return _gate_refused("reached", goal)
	var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var to_goal := Vector2(goal.x - here.x, goal.z - here.z)
	if to_goal.length() <= length and forward.dot(direction) >= APPROACH_ALIGNED_COS:
		# Already on the approach, pointing the right way: don't drive backwards to a gate behind me.
		return _gate_refused("on_approach", goal)
	var map: RID = tank.get_world_3d().navigation_map
	var nearest := NavigationServer3D.map_get_closest_point(map, gate)
	if _flat_distance(nearest, gate) > MESH_GATE_SLACK:
		# The straight approach would start inside a wall. Classify the failure first — a shorter run-in and a curve
		# fix DIFFERENT failures and must never be credited to each other — then, with A4 on, try curving.
		var kind := _off_mesh_kind(goal, direction, length, map)
		_note_off_mesh(kind)
		if a4_on():
			var curved := _curved_gate(goal, direction, length, radius, map)
			if curved != Vector3.INF:
				a4_curved_gates += 1
				if kind == "":
					a4_rescued_blocked += 1  # no straight run-in reached this one at ANY length
				gates_aimed += 1
				return curved
		return _gate_refused("off_mesh", goal)
	gates_aimed += 1
	return gate


## DIAGNOSTIC ONLY, no behaviour (round 9, N4 groundwork). `off_mesh` is **70% of all gate refusals** (901 of 1222 on
## yard, seed 3, 45 s), which makes it the single biggest thing standing between the arrival arc and the fights it is
## meant to run in. Before A4 is designed around it, the question is which KIND of failure it is:
##
##   - a gate that would fit if the approach were simply SHORTER — the goal is near geometry but there is open ground
##     closer in, and a cheap fix (a shorter run-in) recovers it, at the cost of arrival heading accuracy
##     (`APPROACH_RADII` 2.5 was measured: at 1.5 radii an IFV still arrived 63 degrees off);
##   - or a gate with NO straight run-in at any length, because the approach corridor itself is blocked — which no
##     straight gate can fix at any length, and which is exactly the case a curved (clothoid) approach exists for.
##
## So each off-mesh gate is probed at shrinking fractions of its nominal length and the LONGEST that would have landed
## on the navmesh is bucketed. `none` is A4's case; anything else is a shorter-run-in's case. Recorded per refusal so
## the two are counted, not estimated.
const OFF_MESH_PROBES: Array[float] = [0.75, 0.5, 0.25]
static var gate_off_mesh_fit := {}


## Which kind of off-mesh failure this is: the longest straight run-in that WOULD have fitted, or "" for none at all.
static func _off_mesh_kind(goal: Vector3, direction: Vector2, length: float, map: RID) -> String:
	for share: float in OFF_MESH_PROBES:
		var shorter := Vector3(goal.x - direction.x * length * share, 0.0, goal.z - direction.y * length * share)
		if _flat_distance(NavigationServer3D.map_get_closest_point(map, shorter), shorter) <= MESH_GATE_SLACK:
			return "fits_at_%d" % int(share * 100.0)
	return ""


static func _note_off_mesh(kind: String) -> void:
	var key := kind if kind != "" else "none"
	gate_off_mesh_fit[key] = int(gate_off_mesh_fit.get(key, 0)) + 1


## A4 (catalogue row A4): a CURVED approach. The straight gate is pinned to the goal's heading axis, which is why
## **361 of 835 off-mesh gates fit at no length at all** — the corridor behind the goal is blocked and no straight
## line reaches them. A clothoid leaves that axis while still arriving on the ordered heading, so it can enter from
## ground the straight run-in cannot occupy.
##
## A fixed fan, straightest first, ties to the lower index: deterministic, no search. Each entry is how much heading
## the approach curves through; 0 is exactly today's straight gate, so the fan is a superset of current behaviour.
const A4_FAN: Array[float] = [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0]
## Measurement, and the orchestrator's pre-registered positive control: `a4_rescued_blocked` counts ONLY gates that
## no straight run-in could reach at any length. The aggregate would let the 474 that a shorter run-in recovers leak
## into the clothoid's number and take credit for territory it did not win.
static var a4_curved_gates := 0
static var a4_rescued_blocked := 0
static var a4_refused_curvature := 0


static func a4_on() -> bool:
	return switched_off("a4")


static func a4_report() -> Dictionary:
	return {"a4_curved_gates": a4_curved_gates, "a4_rescued_blocked": a4_rescued_blocked,
			"a4_refused_curvature": a4_refused_curvature}


## A gate the hull can actually drive to and arrive on `direction` from, curving rather than running in straight.
## Returns `Vector3.INF` when no candidate in the fan lands on the navmesh.
static func _curved_gate(goal: Vector3, direction: Vector2, length: float, radius: float, map: RID) -> Vector3:
	# The approach frame: `direction` is the heading to arrive on, so the gate lies BACK along it, and `across` is to
	# its left. A clothoid that curves through `angle` ends up `offset.y` off the axis at `offset.x` back from here.
	var left := Vector2(-direction.y, direction.x)
	for degrees: float in A4_FAN:
		var angle := deg_to_rad(degrees)
		var sharpness := Clothoid.sharpness_for(angle, length)
		# A curve tighter than the hull's turning circle is not a candidate — it is the ring's mistake in a new shape.
		if radius > 0.0 and Clothoid.peak_curvature(sharpness, length) > 1.0 / radius:
			a4_refused_curvature += 1
			continue
		var offset := Clothoid.offset(sharpness, length)
		var gate := Vector3(goal.x - direction.x * offset.x + left.x * offset.y, 0.0,
				goal.z - direction.y * offset.x + left.y * offset.y)
		if _flat_distance(NavigationServer3D.map_get_closest_point(map, gate), gate) <= MESH_GATE_SLACK:
			return gate
	return Vector3.INF


## How close counts as "at the gate" (metres): a car's settle radius, never less than this.
const MESH_GATE_SLACK := 1.5
const GATE_REACHED := 2.5


func _arrive_gate() -> float:
	return maxf(GATE_REACHED, settle_radius(ctl.tank.unit_id))


## X7: the point to steer at now — a "carrot" PATH_LOOKAHEAD metres along the route beyond the hull's own place on it
## (pure pursuit along the polyline), or `goal` itself on the last stretch or with no path (navigation not baked yet).
## Steering at raw navmesh corners made a hull drive to each corner, pivot, and drive on; chasing a point that slides
## along the route rounds the corners instead, inside the 2 m the navmesh is eroded by. Wheels look further (a turning
## radius), which is what lets a car take a corner it can actually make. The route is re-planned only when something
## changed — the goal moved, the hull is off it, it made no progress — or every REPATH_SECONDS as a safety net: the
## navmesh is static, so re-planning a route every second (round 5) bought nothing but cost.
## The wedged window: whether avoidance shaped this mover on each of the last WEDGED_WINDOW ticks, and where it was.
var _deflect_window: Array[bool] = []
var _wedge_trail: Array[Vector3] = []
var wedged := false
## ...and the CONTINUOUS quantities behind the flag, published because the flag alone cannot be compared across a
## roster change. scale caught this: `wedged`'s bar is **the mover's own hull length**, so it is size-dependent in its
## DEFINITION rather than in its data — after CP2 an 8.62 m tank must fail to travel 8.62 m where at 3.60 m it only
## had to fail 3.60 m, and the same physical behaviour scores differently. A drop in `wedged` counts across CP2 is
## therefore not necessarily an improvement, and neither is a rise. Publishing the metres travelled, the hull length
## and their ratio lets a consumer normalise it however it needs instead of trusting the boolean.
var wedge_moved_m := 0.0
var wedge_hull_m := 0.0


## A1: why this mover re-planned THIS tick, or "" — published so a harness that can see the K1 order (which nav
## cannot: the mover is handed a `move_to`, not the order that produced it) can attribute the cause to an owner.
## squad's point: a sliding goal can come from an element's flow OR from the player's own follow, and those are two
## different owners. Splitting it here rather than arguing about it is the cheap way to find out.
var last_replan := &""


func _next_waypoint(goal: Vector3, delta: float) -> Vector3:
	var tank := ctl.tank
	var here := tank.global_position
	_repath_left -= delta
	var off_path := _path.size() >= 2 and _off_path(here) > OFF_PATH_REPATH
	var stalled := stalled_ticks > 0 and stalled_ticks % int(BLOCKED_SECONDS * SimClock.TICK_RATE) == 0
	# A1: the fixed cadence becomes a STATE-ERROR TUBE. The clock still ticks, but only so the arm counters can say
	# what the cadence WOULD have done on this very run — the alternative is comparing two runs and hoping they were
	# the same fight. Everything else here is an EVENT and is never gated by the tube: a goal that moved, a hull off
	# its route, a stall. Contact arrival reaches this as a moved goal, which is why latency is preserved by
	# construction rather than by a constant, and why the latency test was written before the mechanism.
	last_replan = &""
	var cadence_due := _repath_left <= 0.0
	if cadence_due:
		a1_cadence_due += 1
		# Re-arm the clock whether or not this becomes a re-plan, so `a1_cadence_due` counts what the CADENCE would
		# have fired on this run. Without this the clock sits below zero while the tube holds and the counter ticks
		# once per tick — 120 "cadence firings" in 8 seconds, which is the instrument lying in the treatment's favour.
		_repath_left = 1.0 if _off.has("repath") else REPATH_SECONDS
	var drifted := cadence_due
	if a1_on():
		# Inside the tube = still on the route it was planned on. `off_path` below is that test, and it is an event,
		# so the tube's only job here is to stop the CLOCK forcing a re-plan that cannot change the answer.
		#
		# **`cadence_due and …`, NOT `…` alone. The tube may only ever hold a plan LONGER than the cadence would,
		# never shorter** — it is allowed to skip a re-plan and never to add one. The first version read
		# `drifted = _path.size() < 2` on its own, so a hull with no route yet re-planned on ticks where the cadence
		# was not due and the blend would not have: **A1 could re-plan MORE than the thing it replaces.** That is the
		# regression a flag hides, and it is exactly the guarantee squad wrote into the brain half's tests before
		# nav thought to write it into this one. Monotone by construction now, and asserted.
		drifted = cadence_due and _path.size() < 2
		if cadence_due and not drifted:
			a1_tube_skips += 1
	# Split by CAUSE, because "an event re-planned it" is not actionable and the four causes have four different
	# owners. squad raised the one that matters: a member on a K1 `follow` has a goal that slides with its leader
	# EVERY TICK by design, so a flat "the goal moved 1 m" test re-plans a whole route several times a second for a
	# unit that is doing exactly what it was told. nav already knows the difference — `_track_goal` estimates
	# `_goal_velocity` for station-keeping (X6) and `drive()` uses NEW_GOAL_JUMP to tell "a new destination" from "a
	# slot sliding along" — and `_next_waypoint` was the one place that did not ask.
	var goal_shift := _flat_distance(goal, _path_goal)
	# A goal that is SLIDING (a follower keeping station on its leader, a slot riding its anchor) gets a tolerance
	# that scales with how far there is left to go, instead of a flat metre. Measured: **47% of all re-plans in a
	# fight were this** — nav re-planning an entire route because a goal it is already regulating moved 1 m. A 1 m
	# shift on an 80 m route changes nothing about the route; on a 5 m route it changes everything, which is why the
	# tolerance is a SHARE and not a bigger constant. This is A1's own argument applied to the other state variable,
	# and it is behind A1's switch because it is A1's mechanism.
	#
	# Latency is untouched: a re-order makes the goal JUMP, `_track_goal` refuses a jump as motion (it rejects
	# anything above twice top speed), so `_goal_velocity` falls below STATION_MIN_SPEED and the flat 1 m rule
	# applies — which is what the latency test asserts.
	var sliding := _goal_velocity.length() >= STATION_MIN_SPEED
	var tolerance := 1.0
	if sliding and a1_on():
		tolerance = maxf(GOAL_TUBE_MIN, GOAL_TUBE_SHARE * _remaining)
	var goal_moved := goal_shift > tolerance
	var event := goal_moved or off_path or stalled
	if drifted or event:
		a1_replans += 1
		if goal_moved:
			var key := "goal_slid" if sliding else "goal_jumped"
			a1_by_cause[key] = int(a1_by_cause.get(key, 0)) + 1
			last_replan = StringName(key)
		elif off_path:
			a1_by_cause["off_path"] = int(a1_by_cause.get("off_path", 0)) + 1
			last_replan = &"off_path"
		elif stalled:
			a1_by_cause["stalled"] = int(a1_by_cause.get("stalled", 0)) + 1
			last_replan = &"stalled"
		else:
			a1_by_cause["cadence"] = int(a1_by_cause.get("cadence", 0)) + 1
			last_replan = &"cadence"
		_repath_left = 1.0 if _off.has("repath") else REPATH_SECONDS
		_path_goal = goal
		# Round 7: reachability is "the route ENDS at the goal", never "a route came back" (lesson 76). NavigationServer
		# answers an unreachable goal with a route to the nearest reachable point, which reads as success; Pathing.query
		# says which it is. For a MOVE the question is also whether the unit can get within its arrive radius of the goal:
		# a goal inside cover is on its island but NO_PATH_MARGIN+ off the mesh, so it is "no_path" for driving purposes.
		var route := Pathing.query(tank, here, goal)
		_path = route["points"]
		_reachable = not bool(route["ready"]) or _path.size() < 2 \
				or (bool(route["reachable"]) and float(route["goal_gap_m"]) <= NO_PATH_MARGIN)
		_route_reading = route
		_path_index = 1 if _path.size() >= 2 else _path.size()
	if _path.size() < 2:
		_path_index = _path.size()
		return goal
	# Where am I along the route: the nearest point on the next few segments (never backwards).
	var best := INF
	var best_segment := _path_index - 1
	var best_point := Vector2(here.x, here.z)
	for segment in range(maxi(_path_index - 1, 0), mini(_path_index + 2, _path.size() - 1)):
		var point := _closest_on_segment(here, _path[segment], _path[segment + 1])
		var distance := Vector2(here.x, here.z).distance_squared_to(point)
		if distance < best:
			best = distance
			best_segment = segment
			best_point = point
	_path_index = best_segment + 1
	var look := maxf(PATH_LOOKAHEAD, wheel_radius() * WHEELS_LOOKAHEAD_RADII)
	# Facing well away from the route (turning round onto it): steer at a FIXED point — the next corner at least a
	# lookahead away — until lined up. A carrot slides along with the hull, so while it turns round it would keep
	# chasing a point beside itself.
	var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
	var toward := Vector2(_path[_path_index].x - here.x, _path[_path_index].z - here.z)
	if _off.has("carrot"):
		return _corner_waypoint(goal)
	if toward.length_squared() > 0.01 and forward.normalized().dot(toward.normalized()) < CARROT_ALIGNED_COS:
		for i in range(_path_index, _path.size()):
			if _flat_distance(_path[i], here) >= look and (wheel_radius() <= 0.0 or _ahead_of_wheels(_path[i])):
				return Vector3(_path[i].x, 0.0, _path[i].z)
		return _route_end(goal)
	# Walk the lookahead along the route from there. A car's point must be one it can drive forward onto (outside
	# both turning circles): a point inside one is a three-point turn, so look further along the route until it isn't.
	var point := _along_route(best_point, look)
	# Round 7 (nav-fight): a carrot round a corner can put the straight line to it THROUGH the obstacle the route bends
	# round (the route is on the navmesh; the chord across its bend is not). A tank pressed its nose into a barricade's
	# end for 35 s steering at a carrot on the far side. Pull the carrot back toward the corner until the chord is on the
	# navmesh; the corner itself always is.
	if point != Vector3.INF and not _off.has("chord") and not _chord_on_mesh(here, point):
		point = Vector3.INF
		for share: float in CARROT_PULLBACK:
			var nearer := _along_route(best_point, look * share)
			if nearer != Vector3.INF and _chord_on_mesh(here, nearer):
				point = nearer
				break
		if point == Vector3.INF:
			return Vector3(_path[_path_index].x, 0.0, _path[_path_index].z)
		return point
	if wheel_radius() > 0.0:
		# ...but never to a point whose chord leaves the navmesh (the round-7 pinned car steered 20 m through a wall).
		var carrot := point
		var further := look
		while point != Vector3.INF and not _ahead_of_wheels(point) and further < look + WHEELS_LOOKAHEAD_MAX_RADII * wheel_radius():
			further += wheel_radius()
			point = _along_route(best_point, further)
		if point != Vector3.INF and point != carrot and not _off.has("chord") and not _chord_on_mesh(here, point):
			point = carrot  # no reachable-and-drivable point further on: take the carrot and the three-point turn
	return point if point != Vector3.INF else _route_end(goal)


## Where the route runs out: the goal itself, or — when the goal is unreachable — the last point the route reaches
## (steering on toward the goal from there only presses the hull into whatever cuts it off).
func _route_end(goal: Vector3) -> Vector3:
	if _reachable or _path.is_empty():
		return goal
	var end := _path[_path.size() - 1]
	return Vector3(end.x, 0.0, end.z)


## The point `distance` metres along the route from `from` (on segment _path_index - 1), or INF past its end.
func _along_route(from: Vector2, distance: float) -> Vector3:
	var left := distance
	var at := from
	for i in range(_path_index, _path.size()):
		var corner := Vector2(_path[i].x, _path[i].z)
		var leg := at.distance_to(corner)
		if leg >= left:
			var carrot := at + (corner - at) * (left / leg)
			return Vector3(carrot.x, 0.0, carrot.y)
		left -= leg
		at = corner
	return Vector3.INF

## Measuring only (`--nav-off=carrot`): round 5's path following, exactly — steer at the next raw corner, moving on
## within 2.5 m of it (cars: 0.8 turning radii).
func _corner_waypoint(goal: Vector3) -> Vector3:
	var here := ctl.tank.global_position
	var reach := maxf(2.5, wheel_radius() * 0.8)
	while _path_index < _path.size() and _flat_distance(here, _path[_path_index]) < reach:
		_path_index += 1
	if _path_index >= _path.size():
		return goal
	return Vector3(_path[_path_index].x, 0.0, _path[_path_index].z)


## Round 7 (nav-fight): the LAST word on where to steer. Every source of a steering point — the route carrot, a car's
## look-ahead, a fixed corner, an avoiding velocity — can pick one whose straight line clips an obstacle's end, and a
## hull steering at it presses into that end forever (four such units in one 52-unit fight, pinned 20-35 s each). If
## the line leaves the navmesh (allowing for my hull's width), steer at the next route corner; if even that line does,
## keep the chosen point (and count it: guard_rescues).
func _guard_steer(here: Vector3, waypoint: Vector3) -> Vector3:
	if _chord_on_mesh(here, waypoint):
		return waypoint
	if _path_index < _path.size():
		var corner := Vector3(_path[_path_index].x, 0.0, _path[_path_index].z)
		if _chord_on_mesh(here, corner):
			return corner
	# (A "steer back onto the mesh" rescue was tried here and removed: in a narrow corridor a hull is legitimately in the
	# mesh's erosion margin, and the rescue fired 1106 times in one maze run, sending hulls sideways into each other.)
	guard_rescues += 1
	return waypoint


## Is the straight line from `from` to `to` on the navmesh (sampled at CHORD_SAMPLES points)? Only asked when there is
## a carrot to check, so it costs a couple of NavigationServer queries per moving unit per tick.
func _chord_on_mesh(from: Vector3, to: Vector3) -> bool:
	if not Pathing.enabled or not Pathing.is_ready(ctl.tank):
		return true
	var map := ctl.tank.get_world_3d().navigation_map
	for share: float in CHORD_SAMPLES:
		var probe := Vector3(lerpf(from.x, to.x, share), 0.0, lerpf(from.z, to.z, share))
		if _flat_distance(NavigationServer3D.map_get_closest_point(map, probe), probe) > _chord_slack():
			return false
	return true


## How far off the navmesh a point on my line may be and still be physically clear for MY hull: the bake erodes the
## mesh by the agent radius (2 m), so a point that far out is at an obstacle's face; my hull needs its half-width of
## that. A 0.3 m slack for every hull (the first version) called ordinary driving in the maze's 3 m corridors "off the
## mesh" and dropped head-on maze-60 from 60/60 to 27/60 (builder0, nav-where, round 7).
func _chord_slack() -> float:
	var size: Variant = Units.stat(ctl.tank.unit_id, "hull_size", [2.4, 1.6, 3.8])
	# The BAKED radius, read from the arena, not the constant. Same number today; the difference is that the day
	# arena re-bakes, this follows and the constant complains instead of both being quietly wrong.
	var slack := maxf(CHORD_SLACK, bake_radius(ctl.tank) - float(size[0]) / 2.0 - CHORD_MARGIN)
	if not clearance_on():
		return slack
	# THE ROUTING HALF of the CP2 clearance row, OPT-IN (`--nav-off=clearance` turns it ON).
	#
	# This slack is derived from HALF-WIDTH alone, but a hull's real envelope through a corner is `(w + l) / 4`
	# (`Avoidance.radius_of`) — which is why a 14 m semi 3.3 m wide is allowed to hug a mesh edge on a certificate
	# that only ever covered its width. Post-CP2 that gap is positive for 14 of 21 units.
	#
	# So an oversized hull does not take mesh-hugging shortcuts: it follows the route the bake actually certified.
	# The slack may go NEGATIVE, and that is the intended refusal rather than an underflow — every probe is then
	# further from the mesh than allowed, `_chord_on_mesh` answers false, and no carrot is cut.
	clearance_chords += 1
	var shortfall := clearance_shortfall(ctl.tank, ctl.tank.unit_id)
	if shortfall <= 0.0:
		return slack
	clearance_refused += 1
	return slack - shortfall


## Flat distance from `here` to the route near where the hull is on it.
func _off_path(here: Vector3) -> float:
	var best := INF
	for segment in range(maxi(_path_index - 1, 0), mini(_path_index + 2, _path.size() - 1)):
		best = minf(best, Vector2(here.x, here.z).distance_to(_closest_on_segment(here, _path[segment], _path[segment + 1])))
	return best


static func _closest_on_segment(here: Vector3, a: Vector3, b: Vector3) -> Vector2:
	var start := Vector2(a.x, a.z)
	var span := Vector2(b.x - a.x, b.z - a.z)
	var length_sq := span.length_squared()
	if length_sq < 0.0001:
		return start
	var t := clampf((Vector2(here.x, here.z) - start).dot(span) / length_sq, 0.0, 1.0)
	return start + span * t


func _remaining_path_distance(goal: Vector3) -> float:
	var tank := ctl.tank
	if _path_index >= _path.size():
		return _flat_distance(tank.global_position, goal)
	var total := _flat_distance(tank.global_position, _path[_path_index])
	for i in range(_path_index, _path.size() - 1):
		total += _flat_distance(_path[i], _path[i + 1])
	return total


## Blind unsticking: driving hard but not moving for STUCK_SECONDS → back off for UNSTICK_SECONDS.
func unstick(cmd: TankCommand, order: Dictionary, delta: float) -> void:
	if _unstick_left > 0.0:
		_unstick_left -= delta
		if _unstick_pivot:
			cmd.throttle = 0.0  # no room behind: tracks swing the nose off whatever it is pressed against instead
		else:
			cmd.throttle = 1.0 if order.get("reverse", false) else -1.0  # back off the way you were NOT going
		cmd.turn = 1.0
		return
	if absf(cmd.throttle) > 0.5 and ctl.tank.estimated_velocity.length() < STUCK_SPEED:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			_stuck_time = 0.0
			# Not blind any more: backing off is only done when there is room to back into. A friend right behind
			# (a column, a crowd) would just be rammed, and then two units are stuck instead of one — right-of-way
			# sorts that case out instead.
			var backing := 1.0 if order.get("reverse", false) else -1.0
			_unstick_pivot = not _off.has("unstick") and _hull_within(Vector2(-ctl.tank.global_basis.z.x, -ctl.tank.global_basis.z.z) * backing,
					UNSTICK_CLEARANCE)
			if not _unstick_pivot or wheel_radius() <= 0.0:
				_unstick_left = UNSTICK_SECONDS
			else:
				# A car can't pivot: with a friend right behind it, ask that friend to make room, and back off next time.
				_ask_behind(Vector2(-ctl.tank.global_basis.z.x, -ctl.tank.global_basis.z.z) * backing)
	else:
		_stuck_time = 0.0


## Ask the friend nearest behind (along `direction`) to give way, so this car has room to back off.
func _ask_behind(direction: Vector2) -> void:
	var tank := ctl.tank
	var here := tank.global_position
	Avoidance.refresh(ctl.tanks_root)
	for row: Array in Avoidance.neighbours(String(tank.name), here.x, here.z):
		var i: int = row[2]
		var offset := Vector2(Avoidance._xs[i] - here.x, Avoidance._zs[i] - here.z)
		if offset.length_squared() < 0.01 or offset.normalized().dot(direction) < 0.7:
			continue
		var other := ctl.tanks_root.get_node_or_null(NodePath(String(row[1]))) as Tank
		var mover := Movement.of(other) if other != null and other.team == tank.team else null
		if mover != null:
			mover.ask(String(tank.name), here, direction)
		return


## Is there a hull within `reach` metres (beyond both radii) along `direction` (flat, unit) — within ±45° of it?
func _hull_within(direction: Vector2, reach: float) -> bool:
	if ctl.tanks_root == null:
		return false
	var tank := ctl.tank
	var here := tank.global_position
	Avoidance.refresh(ctl.tanks_root)
	var mine := Avoidance.radius_of(tank.unit_id)
	for row: Array in Avoidance.neighbours(String(tank.name), here.x, here.z):
		var i: int = row[2]
		var offset := Vector2(Avoidance._xs[i] - here.x, Avoidance._zs[i] - here.z)
		var distance := offset.length()
		if distance < 0.01 or distance > mine + Avoidance._radii[i] + reach:
			continue
		if offset.dot(direction) / distance >= 0.7:
			return true
	return false


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
