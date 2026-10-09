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
## Round 17 lever (l17c, BrainLevers.chord_samples = 1): the end alone (BrainLevers' note: the midpoint never refused).
const CHORD_END: Array[float] = [1.0]
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
## Round 12: ...or, for long hulls, their half-lengths plus this gap (`--nav-off=blockreach` restores the flat reach).
const BLOCKER_GAP_M := 2.0
## ...and "ahead" means within this cosine of the direction I'm trying to go (~60°).
const BLOCKER_AHEAD_COS := 0.5
## A route that ends further than this from the goal did not reach it: the goal is inside something or cut off.
const NO_PATH_MARGIN := 3.0
## ...and a unit within this of the end of such a route has gone as far as it can: `blocked`, `no_path`, at once.
const UNREACHABLE_AT_END := 4.0
## Round 11 (nav R2 item 3): **repair, don't just report.** Before that `blocked`/`no_path`, the goal is re-grounded ONCE
## with this hull's own envelope (SlotGround.for_unit) and driven to instead — if a route reaches the repaired point and
## it is within REPAIR_MAX_M of what was asked. A unit that quietly drives somewhere else is worse than one that says it
## is stuck, so a repair further than that, or one no route reaches, is refused and today's honest report stands. One
## try per goal (a goal that moves more than NEW_GOAL_JUMP is a new goal), so a genuinely impossible order cannot spin.
const REPAIR_MAX_M := 12.0
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
const OFF_NAMES: Array[String] = ["a1", "a4", "a6", "a7", "a11", "backup", "blockreach", "carrot", "chord", "circlefit", "clearance", "commit", "creepbound", "facegiveup", "grace", "guard", "guardnear", "holdband", "inflate",
		"leash", "minpace", "nosestop", "notready", "oriented", "press", "pushidle", "kturn", "kturnbrake", "kturnbrakeall", "kturnfill", "kturnlook", "kturnrollout", "kturnslide", "r5sidestep", "repair", "repath", "standoff", "unstick", "wheelhold", "yield", "yieldclear", "yieldfit", "yieldhold", "yieldshort"]


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


## Measurement only: route requests that found the navigation map not synced (each is retried the next tick).
static var route_not_ready := 0


static func route_arms() -> Dictionary:
	return {"corners_inflated": corners_inflated, "corners_kept": corners_kept, "press_escapes": press_escapes,
			"nose_stops": nose_stops, "oriented_pairs": Avoidance.oriented_pairs, "driver_ticks": driver_ticks.duplicate(),
			"yield_spots_refused": yield_spots_refused, "leash_clamps": leash_clamps, "leash_orders": leash_orders,
			"route_not_ready": route_not_ready,"a1_replans": a1_replans, "a1_cadence_due": a1_cadence_due, "a1_tube_skips": a1_tube_skips,
			"by_cause": a1_by_cause.duplicate(),
			"clearance_chords": clearance_chords, "clearance_refused": clearance_refused,
			"goal_repairs": goal_repairs, "goal_repairs_refused": goal_repairs_refused,
			"unstick_fires": unstick_fires, "circle_reverses": circle_reverses, "circle_reverse_ticks": circle_reverse_ticks,
			"kturns": kturns, "kturn_none": kturn_none, "kturn_aborted": kturn_aborted, "kturn_ticks": kturn_ticks,
			"kturn_multi": kturn_multi, "kturn_multi_legs": kturn_multi_legs, "kturn_looked": kturn_looked, "kturn_eased": kturn_eased,
			"yields_started": yields_started, "asks_refused": asks_refused, "yield_spots_unfit": yield_spots_unfit,
			"yield_swaps": yield_swaps, "yield_swaps_shorter": yield_swaps_shorter,
			"yield_spots_shortened": yield_spots_shortened, "yield_holds": yield_holds,
			"circle_kept": circle_kept, "circle_forward": circle_forward, "circle_none": circle_none}


static func reset_route_arms() -> void:
	circle_kept = 0
	circle_forward = 0
	circle_none = 0
	kturn_leg_log.clear()
	circle_log.clear()
	kturns = 0
	kturn_looked = 0
	kturn_eased = 0
	kturn_none = 0
	kturn_none_log.clear()
	kturn_fill_log.clear()
	yield_log_rows.clear()
	yield_unfit_log.clear()
	yield_spots_unfit = 0
	yields_started = 0
	asks_refused = 0
	yield_swaps = 0
	yield_swaps_shorter = 0
	yield_spots_shortened = 0
	yield_holds = 0
	kturn_aborted = 0
	kturn_multi = 0
	kturn_multi_legs = 0
	kturn_ticks = 0
	unstick_fires = 0
	circle_reverses = 0
	circle_reverse_ticks = 0
	goal_repairs = 0
	goal_repairs_refused = 0
	corners_inflated = 0
	corners_kept = 0
	press_escapes = 0
	nose_stops = 0
	driver_ticks = {}
	yield_spots_refused = 0
	leash_clamps = 0
	leash_orders = 0
	Avoidance.oriented_pairs = 0
	route_not_ready = 0
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
## Round 11 (R1's before-arm, measurement only): reverses by what started them. `unstick_fires` (the blind stall rule),
## `press_escapes` (below), `circle_reverses` / `circle_reverse_ticks` (Steering's in-circle back-up on a forward order).
static var unstick_fires := 0
static var circle_reverses := 0
static var circle_reverse_ticks := 0
var _circling := false
## Round 11 (R2 item 3): the goal a repair was tried for (INF = none yet), and what it was repaired to (INF = refused).
var _repair_for := Vector3.INF
var _repair_to := Vector3.INF
## Arm counters: repairs driven, and repairs refused (too far, or no route reaches them either).
static var goal_repairs := 0
static var goal_repairs_refused := 0
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
## Round 23 (brains B1, measurement only): whether the station PID drove this tick (tests/tactics/pace_stage.gd's trace).
var stationed_now := false
## Round 23 (brains B1): THE GIVE-WAY. A crew keeping station on the way (a `paced` transit move) that ORCA has been
## shaving for GIVE_WAY_AFTER_TICKS -- slowed and steered off its line by a squadmate it cannot pass -- eases off to
## GIVE_WAY_PACE for GIVE_WAY_TICKS, so it drops back a hull length and the diagonal round the squadmate opens. His
## case (the parade, seed 1, builder0): the rearmost crew sat 5 m behind-right of the centre crew for 12 s at exactly
## the anchor's speed, deflected every tick, 20 m from its seat; the centre crew, held to its station by the PID, had
## no reason to move, and neither had a speed margin over the other. Only for paced moves: the control arm is untouched.
const GIVE_WAY_AFTER_TICKS := SimClock.TICK_RATE * 3 / 4
const GIVE_WAY_TICKS := SimClock.TICK_RATE
const GIVE_WAY_PACE := 0.5
var _blocked_ticks := 0
var _give_way_left := 0
## Measurement: give-ways begun on this mover.
var give_ways := 0
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


# ---- Round 10 (item 1): the wall-contact instrument (game/ai/wall_contact.gd) -------------------------------------

## This mover's wall-contact reading, published in `state()` (measurement only; nothing decides on it).
var contact := WallContact.new()
## Did ORCA move this tick's steering point (set in `drive`, cleared when nothing drives)?
var _deflected := false


## The controller's last word on the tick: what it commanded and which layer produced it. The instrument judges the
## NEXT tick's slide against this, because the slide it reads is the motion this command produced.
func note_decision(cmd: TankCommand, order: Dictionary) -> void:
	var driver := String(order.get("type", "stop"))
	if phase == "yielding" and yield_to != "":
		driver = "yield"
	elif _unstick_left > 0.0:
		# Round 11 (R1's before-arm): the pressed-wall escape shares unstick's timer; split them, both are reactive.
		driver = "press" if _escape_gear != 0.0 else "unstick"
	elif _kturn_left_m > 0.0:
		driver = "kturn"
	elif driver == "move_to":
		driver = "direct" if bool(order.get("direct", false)) else "route"
	driver_ticks[driver] = int(driver_ticks.get(driver, 0)) + ctl._step
	var why := _reverse_why if driver == "route" else ""
	_reverse_why = ""
	var on_route := driver == "route" and _path_index < _path.size()
	contact.decided = {"driver": driver, "throttle": cmd.throttle, "turn": cmd.turn,
			"deflected": _deflected and (driver == "route" or driver == "direct"),
			"steer_to": steer_to if steer_to != Vector3.INF else null, "why": why,
			"leg": _kturn_left_m > 0.0}
	if not BrainSwitches.lazy_path:
		contact.decided["path"] = _path.slice(maxi(_path_index - 1, 0)) if on_route else PackedVector3Array()
	elif on_route:
		# Round 16 (switch lazy_path): the route and where it starts, not a copy of it every tick for every hull. Packed
		# arrays are copy-on-write values (trip-up 48), so this holds THIS tick's route even when a re-plan replaces
		# `_path` later; WallContact slices it on the rare tick a hull touches a wall.
		contact.decided["path_all"] = _path
		contact.decided["path_from"] = maxi(_path_index - 1, 0)


## Round 10 item 6 (the seam, measured first): unit-ticks by the layer that produced the motion — `route` (Movement's
## navmesh drive), `direct` (CombatMotion's short hops), `yield`, `unstick`, `face`, `drive`, `stop` — every controller
## tick, strided ticks counted by their stride. Measurement only.
static var driver_ticks := {}


## Read the hull's last slide (the controller calls this every physics tick, before its stride skip).
func observe_contact() -> void:
	contact.observe(self)


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


## Round 16 (brains A7): the two fields of state() a brain reads every tick on a move order, without building the other
## twenty (a path slice, the contact reading, legibility, the corridor). The same values state() would carry:
## `repaired_m > 0 and phase == "arrived"` (false when nothing drives the unit), and `corridor` (null likewise).
static func repaired_arrival(unit: Node) -> bool:
	var mover := of(unit)
	return mover != null and mover._repair_to != Vector3.INF and mover.phase == "arrived" \
			and _flat_distance(mover._repair_to, mover._repair_for) > 0.0


static func corridor_of(unit: Node) -> Variant:
	var mover := of(unit)
	return mover.corridor() if mover != null else null


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
		# KEYED TO THIS HULL'S OWN WORLD, not to the first region in the tree. Taking the first was safe only
		# because `arena.gd`'s `NavigationMirror` shares the same `NavigationMesh` — luck, not design, and it stops
		# being even that the moment two arenas can be alive at once, which is exactly the state that produced
		# combat's 284 edge errors. Matching `get_navigation_map()` against the hull's own map means a region
		# belonging to some other world can never answer for this hull.
		# Typed explicitly: `unit` is a `Node`, so a ternary on `unit.get_world_3d()` has no inferrable type and
		# GDScript refuses it at parse time — which is what broke the lint on the unverified merge of bffdea0f.
		var my_map := RID()
		var spatial := unit as Node3D
		if spatial != null:
			my_map = spatial.get_world_3d().navigation_map
		for node in unit.get_tree().get_root().find_children("*", "NavigationRegion3D", true, false):
			var region := node as NavigationRegion3D
			if region == null or region.navigation_mesh == null:
				continue
			if my_map.is_valid() and region.get_navigation_map() != my_map:
				continue
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


## The hull box every nav computation measures against — **one accessor, because three copies of a default is how
## the literal got to be three copies.** `avoidance.gd:54`, `movement.gd`'s chord slack and its `_chord_slack`
## twin all carried `[2.4, 1.6, 3.8]` inline: a **pre-CP2 size**, applied silently to any unit id the roster does
## not know, and **no shipped unit reaches it, which is exactly why nothing caught it** (scale's consumer sweep,
## 2026-09-21). After the resize that literal is smaller than 14 of 21 hulls and would model a 14 m semi as a 3.8 m
## car — the kind of value that looks like an answer and is a measurement of nothing.
##
## So: **loud, and live.** An unknown id is an error naming the id, not a shrug, and the fallback is
## `Units.DEFAULT`'s **current** box read from the roster rather than a number frozen in this file, so it cannot
## drift from the roster again the way the literal did.
static func hull_box(unit_id: String) -> Array:
	# `Units.PROFILES.has()` FIRST, and this is the sharper half of scale's finding. `Units.stat()` ends in
	# `PROFILES[unit_id].get(key, fallback)` — so its `fallback` covers a **missing KEY**, never a **missing UNIT**:
	# an unknown id raises *"Invalid access to property or key … on a base object of type 'Dictionary'"* before the
	# fallback is ever consulted. So `Units.stat(id, "hull_size", [2.4, 1.6, 3.8])` was not a stale guard against a
	# typo'd unit — **it was never a guard against one at all.** That literal only ever applied if a KNOWN unit
	# lacked `hull_size`, which no unit does. The case everyone assumed it covered was unreachable.
	if Units.PROFILES.has(unit_id):
		var size: Variant = Units.stat(unit_id, "hull_size", null)
		if size is Array and (size as Array).size() >= 3:
			return size
	push_error(("hull_size: no unit %s in the roster, so nav is measuring against %s's box. Every clearance, "
			+ "chord and avoidance radius for this hull is now wrong — a misspelled id or a unit added before its "
			+ "profile.") % [unit_id, Units.DEFAULT])
	var fallback: Variant = Units.stat(Units.DEFAULT, "hull_size", [2.4, 1.6, 3.8])
	return fallback if fallback is Array else [2.4, 1.6, 3.8]


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
			"repaired_m": _flat_distance(_repair_to, _repair_for) if _repair_to != Vector3.INF else 0.0,
			"facing_arc": arc_live, "legibility": legibility(), "corridor": corridor(),
			"clearance_shortfall_m": clearance_shortfall(ctl.tank, ctl.tank.unit_id) if ctl.tank != null else 0.0,
			"stalled_s": float(stalled_ticks) / float(SimClock.TICK_RATE), "replan": last_replan, "wedged": wedged,
			"wedge_moved_m": wedge_moved_m, "wedge_hull_m": wedge_hull_m,
			"wedge_ratio": wedge_moved_m / maxf(wedge_hull_m, 0.1)}.merged(contact.reading())


## A new order: drop the unstick routine, the old path, the fire detour and the stall bookkeeping, so the new order
## drives this very tick (K1 response guarantee).
func reset() -> void:
	_fire_detour = null
	_fire_detour_again = 0
	_fire_since = -1
	_unstick_left = 0.0
	_stuck_time = 0.0
	_press_time = 0.0
	_escape_gear = 0.0
	_nose_goal = Vector3.INF
	_repath_left = 0.0
	stalled_ticks = 0
	_progress_goal = Vector3.INF
	yield_to = ""  # a new order outranks giving way (K1 response guarantee)
	_order_ticks = 0
	_repair_for = Vector3.INF
	_repair_to = Vector3.INF
	_circle_away = 0.0
	if _kturn_left_m > 0.0:
		_kturn_end("reset")
	_kturn_left_m = 0.0
	_kturn_legs.clear()
	_kturn_check = 0
	if not _circle_rec.is_empty() and not _circle_rec.has("end"):
		_close_circle("reset")


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
	_deflected = false
	stalled_ticks = 0
	phase = "arrived"
	blocked_by = ""
	_goal = Vector3.INF
	_remaining = 0.0


## Execute a move_to: fill cmd's throttle and turn for this tick.
func drive(cmd: TankCommand, order: Dictionary, delta: float) -> void:
	# Round 24 (native N3c): the whole drive as one native call (native/src/drive_native.cpp) on this mover's own
	# members; the GDScript below is the reference. Every check drives each mover both ways from one snapshot
	# (tests/test_native_drive.gd): edit this function and the port fails there until it follows.
	if NativeDrive.usable(self):
		var native_lap := Time.get_ticks_usec() if OrderController.profile_detail else 0
		NativeDrive.drive(self, cmd, order, delta)
		OrderController._lap("m.native_drive", native_lap)  # measurement only
		return
	var tank := ctl.tank
	var goal := Vector3(order["x"], 0.0, order["z"])
	if order.has("leash"):
		leash_orders += ctl._step  # the denominator: ticks a leash reached the mover, arm on or off
		if leash_on():
			goal = within_leash(goal, order["leash"])
	if _repair_for != Vector3.INF:
		if _flat_distance(goal, _repair_for) > NEW_GOAL_JUMP:
			_repair_for = Vector3.INF  # a new goal: it gets its own one try
			_repair_to = Vector3.INF
		elif _repair_to != Vector3.INF:
			goal = _repair_to
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
	lap = OrderController._lap("path.gate", lap)
	# The gate is offset from the goal by at least APPROACH_MIN, so "a gate was aimed" and "the goal came back
	# unchanged" cannot be confused. This is the one place that knows, and it used to keep it nowhere.
	arc_live = aim != goal
	var routed := aim if direct else _next_waypoint(aim, delta)
	# Round 11: never a mid-route steering point under the hull, whichever branch of _next_waypoint chose it (arena's
	# Crossing deadlock was the chord fallback; nav-orders then found a route whose next vertex sat 0.07 m from the
	# hull - an IFV rocked in place on the plant's creep for 35 s at zero throttle, and the on/off throttle kept
	# resetting the stall rule). See _corner_beyond.
	if not direct and routed != aim and _flat_distance(routed, tank.global_position) < WAYPOINT_MIN_M:
		routed = _corner_beyond(tank.global_position, aim)
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
	_deflected = false
	if avoidance_on and not order.get("reverse", false) and ctl.tanks_root != null \
			and _flat_distance(tank.global_position, around_fire) > arrive:
		var avoided := _avoid(waypoint, speed_factor, delta)
		if avoided[0] != waypoint:
			arrive = 0.1  # steering at an avoiding point, not the goal: never "arrive" at it
			_deflected = true
		waypoint = avoided[0]
		pace = avoided[1]
	if order.get("paced", false):
		# Round 23 (B1): the give-way (see GIVE_WAY_AFTER_TICKS).
		if _give_way_left > 0:
			_give_way_left -= ctl._step
			pace = minf(pace, GIVE_WAY_PACE)
		elif _deflected and pace < 0.95:
			_blocked_ticks += ctl._step
			if _blocked_ticks >= GIVE_WAY_AFTER_TICKS:
				_blocked_ticks = 0
				_give_way_left = GIVE_WAY_TICKS
				give_ways += 1
				pace = minf(pace, GIVE_WAY_PACE)
		else:
			_blocked_ticks = 0
	else:
		_blocked_ticks = 0
		_give_way_left = 0
	# Round 16 (A2): "move.friends" was these two together; split so each has its own number.
	lap = OrderController._lap("move.avoid", lap)
	if not direct and waypoint != goal and not _off.has("guard"):
		waypoint = _guard_steer(tank.global_position, waypoint)
	lap = OrderController._lap("move.guard", lap)
	var drive_vector: Vector2
	var radius := wheel_radius()
	if radius > 0.0:
		# K3 wheels drive like cars: pure pursuit, three-point turns (Steering.drive_toward_wheels).
		# Direct calls rather than a Callable picked every tick (round-5 X1).
		if order.get("reverse", false):
			drive_vector = Steering.reverse_toward_wheels(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
		else:
			drive_vector = Steering.drive_toward_wheels(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
			# Round 11 (R1): a forward arc that would hit a wall is preceded by a planned reverse leg (see _planned_reverse).
			if not direct and kturn_on() and drive_vector != Vector2.ZERO and Pathing.enabled and Pathing.is_ready(tank):
				var leg := TankCommand.new()
				# Round 14 (N2): the circle rule's reverse is a swept, planned leg (see _circle_leg).
				if _kturn_left_m <= 0.0 and circle_fit_on() and (drive_vector.x < 0.0 or _circle_away != 0.0):
					drive_vector = _circle_gate(waypoint, radius, drive_vector)
				if _planned_reverse(leg, waypoint, delta):
					drive_vector = Vector2(leg.throttle, leg.turn)
			elif _kturn_left_m > 0.0:
				_kturn_end("cancelled")
				_kturn_left_m = 0.0
				_kturn_legs.clear()
	elif order.get("reverse", false):
		drive_vector = Steering.reverse_toward(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
	else:
		drive_vector = Steering.drive_toward(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
	lap = OrderController._lap("steer.drive", lap)
	cmd.throttle = drive_vector.x * speed_factor * pace
	cmd.turn = drive_vector.y
	if _kturn_left_m > 0.0:
		cmd.throttle = drive_vector.x  # a planned leg is driven as planned: pace or a slow order would drop it into the plant's creep
		_ease_ticks = 0
	elif _ease_ticks > 0:
		# Round 15 (V2): easing off before a wall the full-lock arc will meet (see _ease_for).
		_ease_ticks -= ctl._step
		if cmd.throttle > _ease_throttle:
			cmd.throttle = _ease_throttle
			kturn_eased += ctl._step
	# Round 11 (R1's before-arm): Steering's circle test backing a wheeled hull on a FORWARD order - the three-point
	# turn discovered one tick at a time. Episodes (a run of reversing ticks) and ticks; measurement only.
	var circling: bool = radius > 0.0 and not order.get("reverse", false) and drive_vector.x < 0.0 and _kturn_left_m <= 0.0
	if circling:
		circle_reverse_ticks += ctl._step
		if not _circling:
			circle_reverses += 1
	if reverse_log:
		_note_circle(circling, waypoint, goal, remaining, radius, drive_vector)
	_circling = circling
	_nose_at_end = _nose_stop(cmd, goal, direct)
	if _nose_at_end:
		drive_vector = Vector2.ZERO
	steer_to = waypoint
	pace_now = pace
	_note_wedge(tank.global_position, pace < 0.999)
	var stationed := false
	stationed_now = false
	if station_on and not direct and not order.get("reverse", false) and pace >= 0.99 and waypoint == goal \
			and remaining <= STATION_RANGE and _goal_velocity.length() >= STATION_MIN_SPEED:
		# Round 23 (brains B1): a crew its element paces on the way drives at that pace, whatever the PID would do.
		drive_vector = _keep_station(cmd, goal, delta, speed_factor if order.get("paced", false) else 1.0)
		stationed = true
		stationed_now = true
	elif _station != null:
		_station.reset()
	# Round 14 (nav N1), measurement only: which rule put a route-driven hull in reverse gear this tick.
	if _kturn_left_m <= 0.0 and cmd.throttle < 0.0:
		if order.get("reverse", false):
			_reverse_why = "order"
		elif stationed:
			_reverse_why = "station"
		elif circling:
			_reverse_why = "circle"
		else:
			_reverse_why = "other"
	lap = OrderController._lap("steer.station", lap)
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


## Round 10 (nav item 3c): **the nose stop — the end of the route is as near as a hull's NOSE can go.** The drive
## test's last pins on the CP2 map were hulls at the end of a route whose end lies on the navmesh's edge (a slot against
## a kerb, or an unreachable slot clamped to the mesh): the route steers the hull's CENTRE to that point, 2.0 m from the
## face, and a hull longer than 4 m puts its nose into the face before its centre gets there, then presses for the
## rest of the leg. When the hull is touching a wall at the end it is driving toward, with that end of the route
## within its own half-length plus `NOSE_STOP_REACH_M`, it stops: arrived when the goal is reachable, `blocked` /
## `no_path` as before when it is not. Static-footprint tier (the half-LENGTH ahead of the centre).
##
## OPT-IN for now (`--nav-off=nosestop` turns it ON). Arm counter: `nose_stops` (ticks it held a hull).
const NOSE_STOP_REACH_M := 1.5
static var nose_stops := 0
var _nose_at_end := false
## The goal the nose stop latched on (INF = not latched); a new order or a goal that jumps releases it.
var _nose_goal := Vector3.INF


func _nose_stop(cmd: TankCommand, goal: Vector3, direct: bool) -> bool:
	if not nose_stop_on():
		return false
	# LATCHED: once the nose has stopped on a wall for this goal, the hull stays put until the goal moves. Without the
	# latch it oscillated — stopped, came to rest (a parked hull reports no contact), drove on, touched, stopped —
	# and read 95 contact ticks in the test where the latched arm reads a handful.
	if _nose_goal != Vector3.INF and _flat_distance(goal, _nose_goal) <= NEW_GOAL_JUMP:
		cmd.throttle = 0.0
		cmd.turn = 0.0
		nose_stops += 1
		return true
	_nose_goal = Vector3.INF
	if not contact.touching or absf(cmd.throttle) < WallContact.THROTTLE_MIN:
		return false
	var tank := ctl.tank
	var here := tank.global_position
	var motion := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized() * signf(cmd.throttle)
	var r := Vector2(contact.point.x - here.x, contact.point.z - here.z)
	# The touching end is the one the hull is driving toward, and it is driving into the wall there.
	if motion.dot(r) <= 0.0 or motion.dot(Vector2(-contact.normal.x, -contact.normal.z)) <= WallContact.INTO_COS:
		return false
	var end := goal if direct or _path.is_empty() else _route_end(goal)
	var size: Array = hull_box(tank.unit_id)
	if _flat_distance(here, end) > float(size[2]) * 0.5 + NOSE_STOP_REACH_M:
		return false
	cmd.throttle = 0.0
	cmd.turn = 0.0
	nose_stops += 1
	_nose_goal = goal
	return true


## Round 10 item 6, the seam's smallest step: **`Movement`'s goal selection sees the formation leash.** Measured: on
## Terminus 47.6 % of fight ticks are Movement's route drive and 17.2 % CombatMotion's hops, and the leash (A7's
## level-0 region: "fight from your place in the formation") existed only inside `CombatMotion.choose` — so for the
## other ticks nothing bounded where a crew drove. A `move_to` may now carry `leash: [x, z, radius]`; with the arm on,
## a goal outside the circle is replaced by the circle's point nearest it (the projection A7 makes, applied to the
## goal instead of to a candidate direction). The leash itself is squad's to publish on its moves (a request in
## Status); until it does, the arm has nothing to act on and `leash_clamps` says so.
## OPT-IN (`--nav-off=leash` turns it ON). Arm counter: `leash_clamps`.
static var leash_clamps := 0
## The denominator (lesson 147): unit-ticks on which a move_to carrying a leash reached `drive`. Zero means the leash
## never arrived, which is not "every goal was inside its circle".
static var leash_orders := 0


static func leash_on() -> bool:
	return switched_off("leash")


static func within_leash(goal: Vector3, leash: Array) -> Vector3:
	var centre := Vector2(float(leash[0]), float(leash[1]))
	var radius := float(leash[2])
	var offset := Vector2(goal.x, goal.z) - centre
	if offset.length() <= radius:
		return goal
	leash_clamps += 1
	var edge := centre + offset.normalized() * radius
	return Vector3(edge.x, 0.0, edge.y)


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
	var size: Array = hull_box(ctl.tank.unit_id)
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
func _keep_station(cmd: TankCommand, goal: Vector3, delta: float, cap := 1.0) -> Vector2:
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
	# Round 23 (brains B1): paced (`cap` < 1: ahead of its seat in the shape), the crew holds that pace -- a creep, never
	# the PID's brake or reverse -- and lets the shape come up under it.
	cmd.throttle = cap if cap < 0.999 else clampf(wanted / maxf(tank.max_forward_speed, 0.1), -0.5, 1.0)
	return Vector2(cmd.throttle, cmd.turn)


## ON by default since round 11 (`--nav-off=repair` turns it off, like every other mechanism name here).
##
## It shipped opt-in for one night, for a good reason that is now gone: nav measured on `e62383ad` (builder0,
## `nav-orders`) that a player's scout goal was repaired 3.5 m, Movement arrived at the repaired point, and the ORDER
## never completed, because completion was judged against the order's own goal. A hull reading "arrived" under an
## order that never finishes is worse than an honest `no_path`. `TankBrain._update_order_progress` now honours
## `Movement.state(tank)["repaired_m"]` (`78b26067`, mutation-checked), so that failure mode cannot recur.
##
## **Flipped on the measurement, not on the argument** (the orchestrator, `9ed7fccf`, builder0, `nav-orders`, ONE run
## per arm, 30 ordered units, arms differing only in this switch):
##
##   terminus  off: completed 20, never_completed 10, goal_repairs 0,  t50 38.3 s
##   terminus  on:  completed 22, never_completed  8, goal_repairs 2,  t50 37.1 s, goal_repairs_refused 3,
##                  completed_far 1
##   yard      off: completed 30, never_completed  0, goal_repairs 0
##   yard      on:  completed 30, never_completed  0, goal_repairs 1   (every other counter identical)
##
## The Terminus is the honest place to judge this and the yard is not: on open ground a formation slot almost never
## lands inside a building, so the mechanism has nothing to do there and the yard arm is a null control — which is
## exactly what it reads as. On the Terminus **the two extra completions are the two repairs**: the counter and the
## outcome match unit for unit, which is a mechanism rather than a correlation.
##
## **The cost, stated because it is real:** `completed_far` went 0 -> 1, i.e. one unit finished more than 7 m from
## where the player pointed. That is the repair doing what it is for (the point he clicked was not standable), but a
## player cannot see the difference between "moved your goal 8 m" and "ignored you", so if that number grows this
## trade is worth re-opening. And this is ONE run per arm: 10 -> 8 is two units. The claim here is "the mechanism
## acts and nothing got worse", not a measured effect size.
static func repair_on() -> bool:
	return not switched_off("repair")


## Round 11 (R2 item 3): re-ground an unreachable goal once with this hull's envelope; true when the hull now drives to
## the repaired point (the next tick's drive() substitutes it and re-plans), false to report `no_path` as before.
func _repair(goal: Vector3) -> bool:
	if _repair_for != Vector3.INF or not repair_on():
		return false
	var tank := ctl.tank
	_repair_for = goal
	_repair_to = Vector3.INF
	var fixed := SlotGround.for_unit(tank, goal, tank.unit_id)
	var moved := _flat_distance(fixed, goal)
	if moved < 0.5 or moved > REPAIR_MAX_M:
		goal_repairs_refused += 1
		return false
	var route := Pathing.query(tank, tank.global_position, fixed)
	if not bool(route["ready"]) or not bool(route["reachable"]) or float(route["goal_gap_m"]) > NO_PATH_MARGIN:
		goal_repairs_refused += 1
		return false
	_repair_to = fixed
	_repath_left = 0.0
	goal_repairs += 1
	return true


## N1: what this tick amounts to. Arrived when steering has nothing left to do, blocked after BLOCKED_SECONDS without
## progress (with the cause), pathing while the navmesh isn't ready, else driving.
func _update_phase(goal: Vector3, drive_vector: Vector2, direct: bool) -> void:
	if drive_vector == Vector2.ZERO and (_flat_distance(ctl.tank.global_position, goal) <= _arrive + 0.5
			or _nose_at_end and _reachable):
		phase = "arrived"
		blocked_by = ""
		return
	if not _reachable and not direct and not _path.is_empty() \
			and _flat_distance(ctl.tank.global_position, _path[_path.size() - 1]) <= UNREACHABLE_AT_END:
		# As near as the navmesh goes. Round 11: first, once, a goal this hull can stand on near the one it was given;
		# only if there is none, say so now rather than after BLOCKED_SECONDS of grinding.
		if _repair(goal):
			return
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
	var there := _flat_distance(here, _yield_point) <= YIELD_REACHED \
			or (_yield_stop_m > 0.0 and _flat_distance(here, _yield_from) >= _yield_stop_m)
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
func ask(asker: String, from: Vector3, direction: Vector2, via := "asked") -> bool:
	if yield_to != "" or asker == _last_yielded_to:
		return false
	if _begin_yield(asker, from, direction, via):
		return true
	asks_refused += 1
	return false


func _end_yield() -> void:
	if not _yield_rec.is_empty() and not _yield_rec.has("ended_frame"):
		var here := ctl.tank.global_position
		_yield_rec["ended_frame"] = Engine.get_physics_frames()
		_yield_rec["reached"] = _flat_distance(here, _yield_point) <= YIELD_REACHED
		_yield_rec["end_gap_m"] = snappedf(_flat_distance(here, _yield_point), 0.1)
	_last_yielded_to = yield_to
	yield_to = ""
	_yield_point = Vector3.INF
	blocked_by = ""
	phase = "driving"
	stalled_ticks = 0
	_progress_goal = Vector3.INF
	_repath_left = 0.0


## Give way to `other`, travelling along `direction` from `from`: find the nearest validated spot off its line.
func _begin_yield(other: String, from: Vector3, direction: Vector2, via := "self") -> bool:
	var tank := ctl.tank
	var here := tank.global_position
	var along := direction.normalized() if direction.length_squared() > 0.0001 else \
			Vector2(here.x - from.x, here.z - from.z).normalized()
	if along == Vector2.ZERO:
		return false
	var across := Vector2(-along.y, along.x)
	_yield_unfit_last = false
	var short_best := Vector3.INF
	var short_target := Vector3.INF
	var short_label := ""
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
			if not _yield_fits(point):
				var short := _yield_shorten(point) if yield_short_on() else Vector3.INF
				if short != Vector3.INF and (short_best == Vector3.INF or _flat_distance(short, here) > _flat_distance(short_best, here)) \
						and (spot.y == 0.0 or _distance_to_ray(short, from, along) >= line_clear) \
						and _flat_distance(short, from) >= _flat_distance(here, from) and _free_spot(short, String(tank.name), other):
					short_best = short
					short_target = point
					short_label = "short:spot(%d,%d)" % [int(spot.x), int(spot.y * flip)]
				continue
			_start_yield(other, point, along, "spot(%d,%d)" % [int(spot.x), int(spot.y * flip)], via)
			return true
	if _off.has("backup"):
		if short_best != Vector3.INF:
			yield_spots_shortened += 1
			_start_yield(other, short_target, along, short_label, via)
			_yield_stop_m = _flat_distance(short_best, here)
			return true
		return false
	# Last resort (round 7, nav-fight: two cars nose to nose for 30 s with no legal spot): back straight up along my own
	# hull, as long as that isn't toward the unit being let past.
	var back := Vector2(tank.global_basis.z.x, tank.global_basis.z.z).normalized()
	for distance: float in YIELD_BACK_UP:
		var point := Vector3(here.x + back.x * distance, 0.0, here.z + back.y * distance)
		if _flat_distance(point, from) < _flat_distance(here, from):
			continue
		if not _free_spot(point, String(tank.name), other):
			continue
		if _yield_fits(point):
			_start_yield(other, point, along, "back(%d)" % int(distance), via)
			return true
		var short := _yield_shorten(point) if yield_short_on() else Vector3.INF
		if short != Vector3.INF and (short_best == Vector3.INF or _flat_distance(short, here) > _flat_distance(short_best, here)) \
				and _flat_distance(short, from) >= _flat_distance(here, from) and _free_spot(short, String(tank.name), other):
			short_best = short
			short_target = point
			short_label = "short:back(%d)" % int(distance)
	# R2: nothing fits whole, so give way as far as the hull DOES fit along the best of them (the displacement a
	# scraping give-way used to buy, without the scrape).
	if short_best != Vector3.INF:
		yield_spots_shortened += 1
		_start_yield(other, short_target, along, short_label, via)
		_yield_stop_m = _flat_distance(short_best, here)
		return true
	# Nothing fits even shortened, so give way IN PLACE — stop pushing and let the other through — rather than refuse
	# (a refusal leaves both hulls pushing: the refusing build's rigs lost 10 arrivals of 128). `--nav-off=yieldhold`.
	if _yield_unfit_last and yield_fit_on() and not switched_off("yieldhold"):
		yield_holds += 1
		_start_yield(other, here, along, "hold", via)
		return true
	return false


func _start_yield(other: String, point: Vector3, along: Vector2, spot := "", via := "") -> void:
	if yield_log:
		_yield_rec = _yield_diagnose(other, point, spot, via)
		yield_log_rows.append(_yield_rec)
	yield_to = other
	yield_spot = spot
	_yield_point = point
	_yield_from = ctl.tank.global_position
	_yield_stop_m = 0.0
	_yield_dir = along
	_yield_left = int(YIELD_MAX_SECONDS * SimClock.TICK_RATE)
	_yield_held = 0
	phase = "yielding"
	blocked_by = other
	yields_started += 1


## Round 13 (nav R1), measurement only (the drive test's `--yield-log`): every give-way begun — the spot it chose, the
## hull that took it, the room behind and ahead of it, and whether the straight run to the spot keeps the WHOLE outline
## clear (the sweep the planned reverse validates with) — and, filled in by WallContact while it drives there, the
## contact ticks by gear, what it hit and with which end. Never read by a decision.
static var yield_log := false
static var yield_log_rows: Array = []
var _yield_rec := {}


func _yield_diagnose(other: String, point: Vector3, spot: String, via: String) -> Dictionary:
	var tank := ctl.tank
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var to := Vector3(point.x - here.x, 0.0, point.z - here.z)
	var frame := _kturn_frame(tank)
	var other_tank := ctl.tanks_root.get_node_or_null(NodePath(other)) as Tank if ctl.tanks_root != null else null
	var row := {"unit": String(tank.name), "unit_id": tank.unit_id, "frame": Engine.get_physics_frames(), "via": via,
			"spot": spot, "asker": other, "asker_id": other_tank.unit_id if other_tank != null else "",
			"asker_length_m": snappedf(float(hull_box(other_tank.unit_id)[2]), 0.1) if other_tank != null else 0.0,
			"length_m": snappedf(float(frame[1]) * 2.0, 0.1), "width_m": snappedf(float(frame[0]) * 2.0, 0.1),
			"radius_m": snappedf(wheel_radius(), 0.1), "at": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)],
			"heading_deg": snappedf(rad_to_deg(atan2(forward.x, -forward.z)), 1.0),
			"ahead_m": snappedf(to.dot(forward), 0.1), "right_m": snappedf(to.dot(right), 0.1),
			"gear": "reverse" if _straight_behind(point) else "forward",
			"contacts": 0, "reverse_contacts": 0, "hit": {}, "ends": {}}
	if Pathing.enabled and Pathing.is_ready(tank):
		var map := tank.get_world_3d().navigation_map
		row["room_behind_m"] = _free_run(map, here - forward * float(frame[1]), -forward, float(frame[2]))
		row["room_ahead_m"] = _free_run(map, here + forward * float(frame[1]), forward, float(frame[2]))
		var start := _outline_offs(map, frame, here, forward)
		# The straight run to the spot with the heading held (what a reverse to a spot straight behind is), in
		# KTURN_BACK_STEP_M steps: "clear", or the first outline part that leaves the clear reach and how far in.
		var run := to.length()
		row["sweep"] = "clear"
		var travelled := KTURN_BACK_STEP_M
		while travelled < run + KTURN_BACK_STEP_M * 0.5:
			var at := here + to.normalized() * minf(travelled, run)
			var part := _outline_part(map, frame, at, forward, start)
			if part != "none":
				row["sweep"] = part
				row["sweep_at_m"] = snappedf(minf(travelled, run), 0.1)
				break
			travelled += KTURN_BACK_STEP_M
	return row


# ---- Round 13 (nav R2): a yield spot the hull fits, and the drive to it -----------------------------------------------
#
# Round 6's give-way validated a spot by its CENTRE: on the navmesh within YIELD_MESH_SLACK and clear of other hulls.
# For hulls of the day (<= 4 m) that was the hull. A 14 m War Rig's centre 6 m back (`back(6)`, round 7's last
# resort) is a point inside its own footprint, so it passed whatever was behind the tail; and a forward spot 7 m ahead
# of a 12 m-radius hull is one its nose corner reaches only through a block face. R1 (builder0, `5866e387`, 8 seeds):
# 44 % of the rigs' reverse-gear wall contacts were give-ways, and 89 % of those were to spots whose run the outline
# sweep refuses.
#
# **What this replaces: the yield-SPOT CHOICE only** (`_begin_yield`'s acceptance of a candidate), not the protocol:
# who asks whom, who gives way, the spot table's order, the hold and the release are round 6's. A candidate is
# accepted only if the drive right_of_way() will make to it — the same steering law (`Steering._wheels` or
# `drive_toward` / `reverse_toward`, the gear `_straight_behind` picks), stepped kinematically with the plant's yaw law —
# keeps the hull's WHOLE outline inside the clear reach at every step (`_outline_ok`: the planned reverse's own test,
# so an end already pressed against a face may not get deeper). **Sized, not refused:** when no candidate fits whole,
# the hull gives way as far along the best candidate's run as it DOES fit (at least YIELD_SHORT_MIN_M; `short:` in the
# log). Refusing outright was built first and measured worse (builder0, `26f4ac33`, 8 seeds: rigs' yield reverse
# contacts 661 -> 22 but arrivals 115 -> 105 and press/unstick 83 -> 313 — a rig that will not move keeps the jam, and
# the scrapes came back as kturn and press contacts); `--nav-off=yieldshort,yieldhold` is that build. When nothing
# fits even shortened, the hull **gives way in place** (`hold`: it stops pushing and holds, round 6's hold and release)
# — a refusal leaves both hulls pushing; `--nav-off=yieldhold` refuses instead, as round 6 always could: an asked hull
# refuses (the asker gives way itself), and a hull that had to give way asks the other (`yield_swaps`: the short car
# backs up for the truck).
# `--nav-off=yieldfit` restores round 6's choice. Arm counters: `yield_spots_unfit`, `yield_spots_shortened`,
# `yield_holds`, `yield_swaps`, `yield_swaps_shorter`. Measured: `_agents/streams/archive/round13/nav.md` Status.

static var yield_spots_unfit := 0
static var yield_swaps := 0
static var yield_swaps_shorter := 0
static var yield_spots_shortened := 0
static var yield_holds := 0
## A sized give-way: where it began, and how far from there it ends (0 = at its spot, round 6's rule).
var _yield_from := Vector3.ZERO
var _yield_stop_m := 0.0
## Measurement only (`--yield-log`): every candidate refused for fit, with how far its run stayed clear.
static var yield_unfit_log: Array = []
## Did the last spot search refuse at least one candidate for fit (so a swap is about room, not a refused asker)?
var _yield_unfit_last := false
## The run is stepped in this much travel (metres); a pivoting tracked hull in this much yaw (degrees).
const YIELD_FIT_STEP_M := 0.5
const YIELD_FIT_PIVOT_DEG := 15.0
## A run that has not arrived after this many steps (per metre of straight distance, plus a floor) never does cleanly.
const YIELD_FIT_STEPS_PER_M := 6
const YIELD_FIT_MIN_STEPS := 40


static func yield_fit_on() -> bool:
	return not switched_off("yieldfit")


## R2's sizing (`--nav-off=yieldshort`: refuse a spot that does not fit whole, R2's first build, measured worse).
static func yield_short_on() -> bool:
	return yield_fit_on() and not switched_off("yieldshort")


## Does the hull fit its drive to `point`? True when the arm is off or the navmesh is not ready (round 6's choice).
func _yield_fits(point: Vector3) -> bool:
	if not yield_fit_on():
		return true
	var tank := ctl.tank
	if not (Pathing.enabled and Pathing.is_ready(tank)):
		return true
	var poses: Array = []
	if _yield_run_ok(tank.get_world_3d().navigation_map, point, poses):
		return true
	if yield_log:
		yield_unfit_log.append({"unit": String(tank.name), "frame": Engine.get_physics_frames(),
				"clear_m": snappedf(_flat_distance(poses[-1], tank.global_position), 0.1) if not poses.is_empty() else 0.0,
				"steps": poses.size(), "behind": _straight_behind(point),
				"to_m": snappedf(_flat_distance(point, tank.global_position), 0.1)})
	yield_spots_unfit += 1
	_yield_unfit_last = true
	return false


## Step the drive right_of_way() makes to `point` and sweep the whole outline at every pose.
func _yield_run_ok(map: RID, point: Vector3, poses: Array = []) -> bool:
	var tank := ctl.tank
	var frame := _kturn_frame(tank)
	var at := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	var heading := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	var start := _outline_offs(map, frame, at, heading)
	var behind := _straight_behind(point)
	var radius := wheel_radius()
	var reach := YIELD_REACHED * 0.5
	var target := Vector3(point.x, 0.0, point.z)
	var steps := YIELD_FIT_MIN_STEPS + int(at.distance_to(target) * YIELD_FIT_STEPS_PER_M)
	var rolling := 0.0  # the signed speed the steering law sees (its backing hysteresis)
	for i in steps:
		if Vector2(target.x - at.x, target.z - at.z).length() <= reach:
			return true
		var drive := Vector2.ZERO
		if radius > 0.0:
			drive = Steering.reverse_toward_wheels(at, heading, target, reach, radius, rolling) if behind \
					else Steering.drive_toward_wheels(at, heading, target, reach, radius, rolling)
		else:
			drive = Steering.reverse_toward(at, heading, target, reach) if behind \
					else Steering.drive_toward(at, heading, target, reach)
		if drive == Vector2.ZERO:
			return true
		var gear := signf(drive.x)
		if gear == 0.0:
			# A tracked hull turning in place: the whole outline swings round its centre.
			heading = heading.rotated(Vector3.UP, -signf(drive.y) * deg_to_rad(YIELD_FIT_PIVOT_DEG))
		else:
			# The plant's yaw law (TankMotion): |ds| x turn / R in either gear; a tracked hull turns as it rolls.
			var yaw := YIELD_FIT_STEP_M * drive.y / radius if radius > 0.0 else drive.y * deg_to_rad(YIELD_FIT_PIVOT_DEG)
			heading = TankMotion.turn_heading(heading, yaw)
			at += heading * YIELD_FIT_STEP_M * gear
		rolling = gear
		if not _outline_ok(map, frame, at, heading, start):
			return false
		poses.append(at)
	return false


## R2's sizing: the run to `point` does not fit whole, so how far along it DOES the hull fit? The give-way keeps
## `point` as its steering target (so it drives exactly the run that was swept) and ends once the hull is as far from
## where it started as the last clear pose less YIELD_SHORT_MARGIN_M. Returns that pose (Vector3.INF when the clear
## part is shorter than YIELD_SHORT_MIN_M).
const YIELD_SHORT_MIN_M := 2.0
const YIELD_SHORT_MARGIN_M := 1.0


func _yield_shorten(point: Vector3) -> Vector3:
	var tank := ctl.tank
	if not (Pathing.enabled and Pathing.is_ready(tank)):
		return Vector3.INF
	var poses: Array = []
	_yield_run_ok(tank.get_world_3d().navigation_map, point, poses)
	if poses.is_empty():
		return Vector3.INF
	var here := tank.global_position
	var furthest := _flat_distance(poses[-1], here)
	for i in range(poses.size() - 1, -1, -1):
		var pose: Vector3 = poses[i]
		if _flat_distance(pose, here) <= furthest - YIELD_SHORT_MARGIN_M:
			return pose if _flat_distance(pose, here) >= YIELD_SHORT_MIN_M else Vector3.INF
	return Vector3.INF


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
		var on_mesh := Pathing.closest_point(tank.get_world_3d().navigation_map, point, "yield")
		if _flat_distance(on_mesh, point) > YIELD_MESH_SLACK:
			return false
		if yield_clear_on() and not _room_to_turn(tank.get_world_3d().navigation_map, point):
			yield_spots_refused += 1
			return false
	for row: Array in Avoidance.neighbours(me, point.x, point.z):
		if String(row[1]) != other and sqrt(float(row[0])) < YIELD_SPOT_CLEARANCE:
			return false
	return true


## Round 10 (nav, found by item 6's measurement): **a yield spot must leave the hull room to turn.** 10 % of yielding
## ticks in a Terminus fight touched a wall: `_free_spot` accepts a point within YIELD_MESH_SLACK of the navmesh, i.e.
## on the bake's erosion edge 2.0 m from a face, and a hull longer than 4 m that pulls in there and turns sweeps its
## end into the face. With the arm on, the spot must be ON the mesh and so must eight points around it at the hull's
## turning-envelope shortfall (half-diagonal + INFLATE_MARGIN − bake): clearance tier TURNING ENVELOPE (B5).
## OPT-IN (`--nav-off=yieldclear` turns it ON). Arm counter: `yield_spots_refused`.
static var yield_spots_refused := 0
const ROOM_PROBES: Array[Vector2] = [Vector2(1, 0), Vector2(0.70710678, 0.70710678), Vector2(0, 1),
		Vector2(-0.70710678, 0.70710678), Vector2(-1, 0), Vector2(-0.70710678, -0.70710678), Vector2(0, -1),
		Vector2(0.70710678, -0.70710678)]


static func yield_clear_on() -> bool:
	return switched_off("yieldclear")


func _room_to_turn(map: RID, point: Vector3) -> bool:
	if not _on_mesh(map, point):
		return false
	var size: Array = hull_box(ctl.tank.unit_id)
	var need := Vector2(float(size[0]), float(size[2])).length() / 2.0 + INFLATE_MARGIN - bake_radius(ctl.tank)
	if need <= 0.0:
		return true
	for probe: Vector2 in ROOM_PROBES:
		if not _on_mesh(map, point + Vector3(probe.x, 0.0, probe.y) * need):
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
	if _begin_yield(name, other.global_position, its_way):
		return
	# Round 13 (R2): I was the one to give way and no spot fits THIS hull (a 14 m rig in a 21 m street): I hold, and
	# the other gives way instead if it has room — the asymmetry a driver uses (the short car backs up for the truck).
	# Only when I had not already asked it (a refused ask means it had no room either).
	if i_give_way and yield_fit_on() and _yield_unfit_last and mover.ask(String(tank.name), here, my_way, "swap"):
		yield_swaps += 1
		if float(hull_box(other.unit_id)[2]) < float(hull_box(tank.unit_id)[2]):
			yield_swaps_shorter += 1


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
	var best_distance := INF
	var sized := not _off.has("blockreach")
	var my_half := float(hull_box(tank.unit_id)[2]) * 0.5 if sized else 0.0
	if ctl.tanks_root != null:
		for other in ctl.tanks_root.get_children():
			var hull := other as Tank
			if hull == null or hull == tank or not hull.is_alive():
				continue
			var offset := hull.global_position - here
			offset.y = 0.0
			var distance := offset.length()
			# Round 12: "within reach" is hull-sized for pairs the flat 8 m cannot hold. Two War Rigs nose to tail are
			# 14 m centre to centre, so a rig pressed against a parked friend's tail found nobody ahead, called it
			# terrain, never asked, and pushed at full throttle for 80 s (the drive test's rigs, far ring road).
			# Unchanged for every pair whose half-lengths sum to under BLOCKER_REACH - BLOCKER_GAP_M.
			var reach := BLOCKER_REACH
			if sized:
				reach = maxf(BLOCKER_REACH, my_half + float(hull_box(hull.unit_id)[2]) * 0.5 + BLOCKER_GAP_M)
			if distance >= reach or distance >= best_distance or distance < 0.01:
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
	var lap := Time.get_ticks_usec() if OrderController.profile_detail else 0
	Avoidance.refresh(ctl.tanks_root)
	lap = OrderController._lap("avoid.refresh", lap)
	var slow := clampf(_remaining / Steering.SLOW_RADIUS, 0.35, 1.0)
	var desired := tank.max_forward_speed * speed_factor * slow
	var preferred := to / distance * desired
	var chosen := Avoidance.solve(String(tank.name), Vector2(here.x, here.z),
			Vector2(tank.estimated_velocity.x, tank.estimated_velocity.z), preferred, tank.max_forward_speed,
			Avoidance.radius_of(tank.unit_id), delta, BrainLevers.orca_neighbours(tank.team, String(tank.name)))
	OrderController._lap("avoid.solve", lap)
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
		var on_mesh := Pathing.closest_point(tank.get_world_3d().navigation_map, probe, "avoid")
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
	var nearest := Pathing.closest_point(map, gate, "gate")
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
		if _flat_distance(Pathing.closest_point(map, shorter, "gate"), shorter) <= MESH_GATE_SLACK:
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
		if _flat_distance(Pathing.closest_point(map, gate, "gate"), gate) <= MESH_GATE_SLACK:
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
		_path = _inflate_corners(route["points"])
		_reachable = not bool(route["ready"]) or _path.size() < 2 \
				or (bool(route["reachable"]) and float(route["goal_gap_m"]) <= NO_PATH_MARGIN)
		_route_reading = route
		_path_index = 1 if _path.size() >= 2 else _path.size()
		if not bool(route["ready"]) and not _off.has("notready"):
			# Round 10 (combat's relay): a route asked on a frame where the navigation map is not synced (the first
			# frames of a match, or the frame after a scene reload drained the old regions) came back EMPTY, and the
			# cadence then drove the hull in a straight line for REPATH_SECONDS before asking again. Ask again next
			# tick instead: the map is usually ready one or two frames later.
			_repath_left = 0.0
			route_not_ready += 1
	if _path.size() < 2:
		_path_index = _path.size()
		return goal
	# Round 24 (native N3b): the route-following tail below as one native call (native/src/route_native.cpp), held to
	# this GDScript on every check (tests/test_native_route.gd).
	if NativeRoute.usable(self):
		return NativeRoute.tail(self, goal)
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
			return _corner_beyond(here, goal)
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


## Round 11 (arena's report, the Crossing, deterministic): the next corner, but never one the hull is standing ON. The
## segment search keeps the EARLIER segment when the hull sits exactly on the vertex two segments share, so
## `_path[_path_index]` can be a corner 0.4 m away - inside the 0.5 m arrive radius of a mid-route point. Steering then
## returns zero, the stall rule never sees a stall (it needs throttle), and the hull sat "driving" at speed 0 for 90 s.
## The first corner at least WAYPOINT_MIN_M away, or the route's end.
const WAYPOINT_MIN_M := 1.5


func _corner_beyond(here: Vector3, goal: Vector3) -> Vector3:
	for i in range(_path_index, _path.size()):
		if _flat_distance(_path[i], here) >= WAYPOINT_MIN_M:
			return Vector3(_path[i].x, 0.0, _path[i].z)
	return _route_end(goal)


## Round 10 (nav item 3b): **corner inflation — the route's corners get the hull's TURNING envelope, not the bake's.**
## The navmesh is eroded by the bake radius (2.0 m, the static-footprint tier of B5), and a string-pulled route bends
## exactly ON that erosion edge: every corner of it is 2.0 m from a block's face. A hull whose half-width fits that
## still hits the face while it TURNS there, because a turning hull sweeps its half-diagonal (the turning-envelope tier:
## IFV 4.0 m, the Condemned tank 4.5 m, the War Rig 7.2 m). The drive test measured it: the pinned contacts sat at a
## route gap of 2.1-2.7 m from the block they touched.
##
## So each interior corner is pushed OUTWARD along its bisector (away from the obstacle the route bends round, which
## lies along d_in − d_out's opposite) by `w/2 + (half-diagonal − w/2)·sin(turn/2) + INFLATE_MARGIN − bake`, capped at half the free ground found
## along that direction (so in a narrow street the corner is centred, never pushed against the far kerb), and kept only
## if the corner and both legs to it stay on the navmesh. Clearance tier: TURNING ENVELOPE (B5).
##
## OPT-IN for now (`--nav-off=inflate` turns it ON; see `press_on()`'s note). Arm counters:
## `corners_inflated` (moved) and `corners_kept` (asked, no room).
const INFLATE_MARGIN := 0.3
## Sampling step (metres) along a leg and along the outward probe.
const INFLATE_STEP := 0.5
static var corners_inflated := 0
static var corners_kept := 0


func _inflate_corners(path: PackedVector3Array) -> PackedVector3Array:
	if not inflate_on() or path.size() < 3 or not Pathing.enabled or not Pathing.is_ready(ctl.tank):
		return path
	var size: Array = hull_box(ctl.tank.unit_id)
	var half_width := float(size[0]) / 2.0
	var half_diagonal := Vector2(float(size[0]), float(size[2])).length() / 2.0
	var bake := bake_radius(ctl.tank)
	if half_diagonal + INFLATE_MARGIN <= bake:
		return path
	var map := ctl.tank.get_world_3d().navigation_map
	var out := path.duplicate()
	for i in range(1, path.size() - 1):
		var d_in := Vector2(path[i].x - out[i - 1].x, path[i].z - out[i - 1].z)
		var d_out := Vector2(path[i + 1].x - path[i].x, path[i + 1].z - path[i].z)
		if d_in.length_squared() < 0.01 or d_out.length_squared() < 0.01:
			continue
		d_in = d_in.normalized()
		d_out = d_out.normalized()
		if d_in.dot(d_out) > 0.996:
			continue  # under 5 degrees: not a corner
		# The clearance a turn of this angle needs: the half-width on a straight, growing to the half-diagonal on a
		# U-turn (sin of half the turn). A flat rate for every kink turned 6-degree jogs into metre-scale zigzags and
		# delayed an element's drive north (test_tactics_elements on c91d8039).
		var turn := acos(clampf(d_in.dot(d_out), -1.0, 1.0))
		var extra := half_width + (half_diagonal - half_width) * sin(turn / 2.0) + INFLATE_MARGIN - bake
		if extra < INFLATE_STEP:
			continue
		var outward := (d_in - d_out).normalized()
		# The free ground along `outward`, in fixed steps (deterministic, bounded): how far the mesh reaches.
		var free := 0.0
		var reach := extra * 2.0
		var t := INFLATE_STEP
		while t <= reach + 0.001:
			if not _on_mesh(map, path[i] + Vector3(outward.x, 0.0, outward.y) * t):
				break
			free = t
			t += INFLATE_STEP
		var shift := minf(extra, free * 0.5)
		if shift < INFLATE_STEP:
			corners_kept += 1
			continue
		var moved := path[i] + Vector3(outward.x, 0.0, outward.y) * shift
		if _leg_on_mesh(map, out[i - 1], moved) and _leg_on_mesh(map, moved, path[i + 1]):
			out[i] = moved
			corners_inflated += 1
		else:
			corners_kept += 1
	return out


static func _on_mesh(map: RID, point: Vector3) -> bool:
	var near := Pathing.closest_point(map, point, "on_mesh")
	return Vector2(near.x - point.x, near.z - point.z).length() <= 0.05


static func _leg_on_mesh(map: RID, from: Vector3, to: Vector3) -> bool:
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var steps := maxi(1, ceili(length / INFLATE_STEP))
	for k in range(1, steps):
		if not _on_mesh(map, from.lerp(to, float(k) / float(steps))):
			return false
	return true


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
	# Round 12 (nav, found tracing a back-and-fill's War Rig): the next corner, but never one the hull stands ON —
	# round 11's rule (_corner_beyond), which this fallback ran AFTER and so undid. A rig whose carrot chord left the
	# mesh was handed the route vertex 0.47 m from its centre for 2371 ticks: inside the 0.5 m arrive radius, zero
	# throttle, no stall, 79 m from its goal at the leg's end (laptop, rigs seed 3, the plaza leg). `--nav-off=guardnear`
	# restores the old pick (the attribution arm).
	var first := _path_index
	if not _off.has("guardnear"):
		while first < _path.size() - 1 and _flat_distance(_path[first], here) < WAYPOINT_MIN_M:
			first += 1
	if first < _path.size():
		var corner := Vector3(_path[first].x, 0.0, _path[first].z)
		if _chord_on_mesh(here, corner):
			return corner
	# (A "steer back onto the mesh" rescue was tried here and removed: in a narrow corridor a hull is legitimately in the
	# mesh's erosion margin, and the rescue fired 1106 times in one maze run, sending hulls sideways into each other.)
	guard_rescues += 1
	return waypoint


## Is the straight line from `from` to `to` on the navmesh (sampled at CHORD_SAMPLES points)? Only asked when there is
## a carrot to check, so it costs a couple of NavigationServer queries per moving unit per tick.
## Round 16 (A6): the last chord asked, its physics frame and its answer. The route-follower asks the chord to its carrot
## and the guard asks it again for the same two points in the same tick whenever nothing deflected the carrot; the
## navmesh does not change inside a frame and the slack is the hull's, so the same two points give the same answer.
var _chord_frame := -1
var _chord_from := Vector3.INF
var _chord_to := Vector3.INF
var _chord_answer := true


func _chord_on_mesh(from: Vector3, to: Vector3) -> bool:
	if not BrainSwitches.chord_memo:
		return _chord_compute(from, to)
	var frame := Engine.get_physics_frames()
	if frame == _chord_frame and from == _chord_from and to == _chord_to:
		if OrderController.profile_detail:
			OrderController.add_part("nav.chord_memo", 0)
		return _chord_answer
	_chord_answer = _chord_compute(from, to)
	_chord_frame = frame
	_chord_from = from
	_chord_to = to
	return _chord_answer


func _chord_compute(from: Vector3, to: Vector3) -> bool:
	var lap := Time.get_ticks_usec() if OrderController.profile_detail else 0
	if not Pathing.enabled or not Pathing.is_ready(ctl.tank):
		return true
	var map := ctl.tank.get_world_3d().navigation_map
	# Round 16 (A6): the slack once per chord, not once per sample (a pure function of the hull; the clearance arm's
	# counters now count chords rather than samples).
	var hoisted := BrainSwitches.chord_memo
	var slack := _chord_slack() if hoisted else 0.0
	var samples := CHORD_SAMPLES if BrainLevers.chord_samples(ctl.tank.team, String(ctl.tank.name)) >= 2 else CHORD_END
	if hoisted and BrainSwitches.native and BrainSwitches.native_move:
		# Round 23 (native N2b, C23.1): the sampling loop as one native call over the native navmesh index, the same
		# bits (native/src/nav_native.cpp chord_on_mesh); the loop below is the reference.
		# Every check holds this seam to the LIVE loop below (tests/test_native_movement_geometry.gd): edit one, edit both.
		var on_mesh: bool = NativeBridge.nav.chord_on_mesh(map, from, to, PackedFloat64Array(samples), slack)
		OrderController._lap("nav.chord", lap)
		return on_mesh
	for share: float in samples:
		var probe := Vector3(lerpf(from.x, to.x, share), 0.0, lerpf(from.z, to.z, share))
		if _flat_distance(Pathing.closest_point(map, probe, "chord"), probe) > (slack if hoisted else _chord_slack()):
			OrderController._lap("nav.chord", lap)
			if OrderController.profile_detail:
				# Round 17 (T3): which sample refused the chord (the midpoint is asked first; "end" = the midpoint passed).
				OrderController.add_part("nav.chord_fail_mid" if share < 1.0 else "nav.chord_fail_end", 0)
			return false
	OrderController._lap("nav.chord", lap)
	return true


## How far off the navmesh a point on my line may be and still be physically clear for MY hull: the bake erodes the
## mesh by the agent radius (2 m), so a point that far out is at an obstacle's face; my hull needs its half-width of
## that. A 0.3 m slack for every hull (the first version) called ordinary driving in the maze's 3 m corridors "off the
## mesh" and dropped head-on maze-60 from 60/60 to 27/60 (builder0, nav-where, round 7).
func _chord_slack() -> float:
	var size: Array = hull_box(ctl.tank.unit_id)
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
		if _escape_gear != 0.0:
			# Round 10 (item 3a): backing off a wall this hull was PRESSING, away from it and swinging the touching end
			# clear, until it has put PRESS_BACKOFF_M between itself and where it was pinned. See `_pressing_escape`.
			cmd.throttle = _escape_gear * PRESS_ESCAPE_THROTTLE
			cmd.turn = _escape_turn
			if _unstick_left <= 0.0 or _flat_distance(ctl.tank.global_position, _press_from) >= PRESS_BACKOFF_M:
				_escape_gear = 0.0
				_unstick_left = 0.0
			return
		if _unstick_pivot:
			cmd.throttle = 0.0  # no room behind: tracks swing the nose off whatever it is pressed against instead
		else:
			cmd.throttle = 1.0 if order.get("reverse", false) else -1.0  # back off the way you were NOT going
		cmd.turn = 1.0
		return
	# Routed moves only: a `direct` hop is CombatMotion's (it checked the straight line itself), and backing a hull out
	# of a duel mid-fight cost `scenario_motion`'s moving duel a shot (5 vs its bar of 6) on 2a2b77c1.
	if String(order.get("type", "")) == "move_to" and not bool(order.get("direct", false)) and _pressing_escape(cmd, delta):
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
				unstick_fires += 1
			else:
				# A car can't pivot: with a friend right behind it, ask that friend to make room, and back off next time.
				_ask_behind(Vector2(-ctl.tank.global_basis.z.x, -ctl.tank.global_basis.z.z) * backing)
	else:
		_stuck_time = 0.0


## Round 10 item 3's rows. **`press` is DEFAULT ON** (`--nav-off=press` restores the old stall rule alone): on the
## Terminus drive test with grounded right-click goals it took the War Rigs from 7 to 15 of 16 leg arrivals and their
## wall-contact ticks 10128 -> 2315, the mixed squad unchanged (builder0, seed 1, `c148b5d5`). `inflate` and
## `nosestop` stay OPT-IN (like `a7` and `holdband`, the switch turns them ON). Measured on the Terminus drive test they cut wall contacts by two thirds, but
## on `c91d8039` default-on they moved the sim baseline and reddened two element tests (inflation delays an element's
## drive north; see Status), so they wait for their own A/B before becoming the default. The not-ready route retry is
## default ON (`--nav-off=notready` restores the old wait) and is the one pre-registered baseline cause.
static func press_on() -> bool:
	return not switched_off("press")


static func inflate_on() -> bool:
	return switched_off("inflate")


static func nose_stop_on() -> bool:
	return switched_off("nosestop")


## Round 10 (nav item 3a): **the pressed-wall escape.** The Terminus drive test's longest contacts were hulls held
## against a block face or a lamp for 30-130 s at a LOW throttle (0.12-0.35: a wheeled hull's minimum creep, a slowing
## arrival, a tight turn) — below the 0.5 the stall rule above asks for, so nothing ever noticed. The wall-contact
## reading says exactly what the stall rule was guessing: this hull (on a ROUTED move — CombatMotion's `direct` hops
## are its own business) is touching a wall, it is being asked to move, and
## it is not getting anywhere (net displacement, not velocity). After PRESS_SECONDS of that it backs away from the wall (PRESS_BACKOFF_M, at most PRESS_ESCAPE_MAX_S), in the gear that
## moves the touching end off it, yawing so that end swings clear; then the route resumes (and re-plans: it was off it).
##
## DEFAULT ON since round 10's close (`--nav-off=press` switches it off; see `press_on()`).
## Arm counter: `press_escapes`. Deterministic: it reads only physics state already produced and the tick's command.
## A PIN, not a brush: 1.0 s of pressing without progress. Measured on builder0 (drive test rigs arrivals of 16 /
## scenario_motion's moving duel): 0.5 s -> 15 / 5 shots (bar 6, red); 1.0 s -> 14 / passes; 1.5 s -> 8 / passes.
## The drive test's pins last 30-130 s; a duelling tank's weave brushes a wall for well under a second.
const PRESS_SECONDS := 1.0
const PRESS_ESCAPE_THROTTLE := 0.6
## The escape ends once the hull is this far from where it was pinned, or after PRESS_ESCAPE_MAX_S (a wheeled hull
## from rest covers under a metre in the stall rule's 0.9 s: measured 0.78 m on the foundry wall).
const PRESS_BACKOFF_M := 1.5
const PRESS_ESCAPE_MAX_S := 2.0
## Less net movement than this over PRESS_SECONDS in wall contact is "pressed" (a hull sliding past a kerb at speed
## covers metres in that time).
const PRESS_PROGRESS_M := 0.75
static var press_escapes := 0
var _press_time := 0.0
var _press_from := Vector3.ZERO
var _escape_gear := 0.0
var _escape_turn := 0.0


func _pressing_escape(cmd: TankCommand, delta: float) -> bool:
	# Not while the crew is ENGAGED: in a fight the hull's motion is the combat layer's (a duel's weave brushes walls
	# on purpose), and the escape backing a duelling tank off cost scenario_motion's moving duel a shot (5 vs its bar
	# of 6) on 2a2b77c1 and on bc4873f3. The acceptance test it exists for — a squad driven through the streets — has
	# no engagement, so nothing it measured is lost.
	if not press_on() or ctl.gunnery.engaged_target != "":
		_press_time = 0.0
		return false
	var tank := ctl.tank
	var asked := absf(cmd.throttle) >= WallContact.THROTTLE_MIN or absf(cmd.turn) >= 0.05
	if not (contact.touching and asked):
		_press_time = 0.0
		return false
	# Progress is NET DISPLACEMENT over the window, not the hull's velocity: a hull scrubbing along a face keeps a
	# tangential velocity from the slide while going nowhere (the first version gated on `estimated_velocity` and
	# fired 0 times on the drive test's 2000-tick pins).
	if _press_time == 0.0:
		_press_from = tank.global_position
	_press_time += delta
	if _press_time < PRESS_SECONDS:
		return false
	var moved := _flat_distance(tank.global_position, _press_from)
	_press_time = 0.0
	if moved >= PRESS_PROGRESS_M:
		return false
	var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var away := Vector2(contact.normal.x, contact.normal.z)
	var r := Vector2(contact.point.x - tank.global_position.x, contact.point.z - tank.global_position.z)
	# The gear that moves the hull off the wall: along the normal when the hull faces into or away from it, otherwise
	# away from the END that is touching (a nose on the wall backs off, a tail on it drives on).
	var along := forward.dot(away)
	_escape_gear = signf(along) if absf(along) > 0.2 else (-1.0 if forward.dot(r) > 0.0 else 1.0)
	# The yaw that swings the touching point away from the wall (WallContact.swing_of: positive turn = clockwise).
	_escape_turn = 1.0 if WallContact.swing_of(tank.global_position, contact.point, 1.0).dot(away) > 0.0 else -1.0
	_unstick_left = PRESS_ESCAPE_MAX_S
	_press_from = tank.global_position
	_repath_left = 0.0
	press_escapes += 1
	cmd.throttle = _escape_gear * PRESS_ESCAPE_THROTTLE
	cmd.turn = _escape_turn
	return true


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
			mover.ask(String(tank.name), here, direction, "behind")
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


# ---- Round 11 (nav R1): the three-point turn a driver would do, decided before the bumper ------------------------
#
# The lead: *"a lot of vehicles still look dumb because they'll drive into a wall before trying to back up ... it would
# be more ideal if the units detected that their path would bump into a wall, and therefore they need to go in reverse
# first; a real-world driver would execute a 3 point turn as necessary."*
#
# Every reverse before this was REACTIVE: the stall rule (`unstick`, 1 s of no motion), the pressed-wall escape (1 s
# of wall contact) and Steering's circle test (the point inside the turning circle: no wall consulted). A wheeled hull
# nose-on to a wall whose route leaves BEHIND it, with the point outside its turning circle, drives a full-lock
# forward arc straight into the wall, and only then backs off 1.5 m and tries again: a multi-point turn discovered at
# the bumper, one contact at a time.
#
# This is the planned version, inside the driver (not the planner: Pathing stays holonomic by an earlier decision). At
# PLAN time, when a wheeled hull on a routed forward move must turn hard toward its steering point, the forward arc it
# is about to drive (full lock toward the point, the plant's own yaw law: heading turns |ds|·turn/R) is swept against
# the navmesh with the hull's whole outline (it yaws about its centre, so both ends swing). If the arc meets a wall
# within KTURN_HIT_WITHIN_M, a reverse leg is searched the same way — validated against what is behind and beside the
# hull, which no reverse before this did — for the shortest back-up after which the forward arc is clear. That leg is
# then driven as a deliberate leg with its own completion (distance backed, a REAR contact, or a timeout), never as a
# recovery. No clear forward arc within KTURN_BACK_MAX_M: no leg, and the
# reactive rules stand as before (counted: `kturn_none`).
#
# A point is clear when it is within `bake radius - KTURN_MARGIN_M` of the navmesh: the mesh stops the bake radius
# short of every collider, so such a point is at least the margin outside one. A point that already starts nearer a
# wall than that (a nose parked on a face) may not get any deeper. Measurement arm: `--nav-off=kturn`.

## Only when the steering point is this far off the nose (a gentle bend never needs a reverse).
const KTURN_MIN_ERROR_DEG := 45.0
## The forward arc counts as done (the hull points at the steering point) within this.
const KTURN_ALIGNED_DEG := 20.0
## Sweep steps (metres of travel) and how much of a full circle a forward sweep may take before giving up (a point
## inside the turning circle is never aimed at by a forward arc: Steering's own circle test handles that case).
const KTURN_STEP_M := 1.0
const KTURN_SWEEP_TURNS := 0.75
## A reverse leg is at most this long, searched in KTURN_BACK_STEP_M steps, and has this much added past the first
## clear pose so the forward arc starts with room rather than on the edge.
const KTURN_BACK_MAX_M := 8.0
const KTURN_BACK_STEP_M := 0.5
const KTURN_BACK_EXTRA_M := 0.5
## Clearance margin (metres) inside the bake radius; the reverse throttle (above the plant's creep, 0.5 × |turn|).
const KTURN_MARGIN_M := 0.4
const KTURN_THROTTLE := 0.7
## How often a hull not in a leg asks (ticks), and how long a leg may take per metre before it is abandoned.
const KTURN_CHECK_TICKS := 6
## After a leg is cut short, or no leg was found, wait this long before searching again (1 s).
const KTURN_RETRY_TICKS := SimClock.TICK_RATE
## Plan a reverse only for a wall the forward arc meets within this much travel (metres).
const KTURN_HIT_WITHIN_M := 5.0
const KTURN_SECONDS_PER_M := 1.5
## A leg's leading end is hitting a wall when its motion points into the wall's normal by more than this (cosine).
const KTURN_INTO_WALL_COS := 0.5
static var kturns := 0            # legs planned and driven
static var kturn_none := 0        # forward arc blocked, no clear reverse found: left to the reactive rules
static var kturn_aborted := 0     # a leg cut short by a rear contact or its timeout
static var kturn_ticks := 0       # unit-ticks spent on a planned reverse leg
var _kturn_left_m := 0.0
var _kturn_turn := 0.0
var _kturn_from := Vector3.ZERO
var _kturn_timeout := 0.0
var _kturn_check := 0
## Round 12 (N2): the gear of the leg being driven (-1 back, +1 forward) and the back-and-fill's legs still to drive.
var _kturn_gear := -1
var _kturn_legs: Array = []


static func kturn_on() -> bool:
	return not switched_off("kturn")


## Is a planned reverse leg being driven?
func in_kturn() -> bool:
	return _kturn_left_m > 0.0


## Round 17 lever (l17t, BrainLevers.far_exec_straight): is this hull on a plain straight leg -- not in a planned leg,
## touching nothing, not deflected by avoidance this tick, and pointed within STRAIGHT_LEG_DEG of its carrot? Only
## then may a far CPU unit run its controller every other tick (half-rate steering is where the scraping came from).
const STRAIGHT_LEG_DEG := 12.0
func straight_and_clear() -> bool:
	if in_kturn() or contact.touching or _deflected or steer_to == Vector3.INF:
		return false
	var tank := ctl.tank
	var to := Vector2(steer_to.x - tank.global_position.x, steer_to.z - tank.global_position.z)
	if to.length_squared() < 1.0:
		return false
	var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
	return absf(nose.angle_to(to)) <= deg_to_rad(STRAIGHT_LEG_DEG)


## Called by drive() for a wheeled hull on a routed forward move: fills `cmd` and returns true while a planned reverse
## leg is being driven (planning one first when the forward arc toward `waypoint` would hit a wall).
func _planned_reverse(cmd: TankCommand, waypoint: Vector3, delta: float) -> bool:
	var tank := ctl.tank
	if _kturn_left_m > 0.0:
		if not _kturn_rolling:
			# Round 14 (N2): the leg counts from where the hull STOPPED rolling the other way, not from where it was
			# commanded (the roll-out is not progress: the planner already planned from its end).
			if tank.speed() * _kturn_gear > KTURN_ROLLING_SPEED:
				_kturn_rolling = true
			_kturn_from = tank.global_position
		var backed := _flat_distance(tank.global_position, _kturn_from)
		# Round 14 (N3): the leg is done when what is left is within the stopping distance in its gear, so the next
		# leg's opposite throttle brakes the hull to rest AT the planned end rather than ~2 m past it (N1/N3: a rig's
		# forward leg at 5.7 m/s ended 0.25 m from the clear reach and the reverse leg began with the nose going in).
		var reached := backed + _kturn_stopping() >= _kturn_left_m
		_kturn_timeout -= delta
		# The LEADING end's hit ends the leg: the contact point behind the centre while backing (ahead of it on a
		# back-and-fill's forward leg). The other end still touching the wall the leg is moving away from is exactly
		# what the leg is for, and ending on it made every such leg abort on its first tick (the first laptop run:
		# 138 of 155 rig legs).
		var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
		var lead_hit := contact.touching and float(contact.decided.get("throttle", 0.0)) * _kturn_gear > 0.0 \
				and Vector2(contact.point.x - tank.global_position.x, contact.point.z - tank.global_position.z).dot(nose) * _kturn_gear > 0.0
		# Round 12: ...and only when that end is driving INTO the wall. A plan may start with an end already near a face
		# (a pressed start is allowed not to get deeper), and a leg that slides that end ALONG the face is the plan
		# working: aborting on it cut 9 of 20 rig plans on builder0, most within 0.1 m of the leg's start.
		if lead_hit and not _off.has("kturnslide"):
			lead_hit = Vector2(contact.normal.x, contact.normal.z).dot(nose * _kturn_gear) < -KTURN_INTO_WALL_COS
		if reached and not _kturn_legs.is_empty():
			_kturn_end("next")
			_kturn_start_leg(_kturn_legs.pop_front())  # the next leg of a back-and-fill, from where this one ended
		elif reached or _kturn_timeout <= 0.0 or lead_hit:
			_kturn_end("done" if reached else ("lead_hit" if lead_hit else "timeout"))
			_kturn_check = 0
			if not reached:
				kturn_aborted += 1
				_kturn_check = KTURN_RETRY_TICKS
				if kturn_log:
					kturn_fill_log.append({"unit": String(tank.name), "frame": Engine.get_physics_frames(), "aborted": true,
							"gear": _kturn_gear, "backed_m": snappedf(backed, 0.1), "left_m": snappedf(_kturn_left_m, 0.1),
							"lead_hit": lead_hit, "legs_left": _kturn_legs.size()})
			_kturn_left_m = 0.0
			_kturn_legs.clear()
			_repath_left = 0.0
			return false
		if reverse_log and _kturn_rec.has("_from"):
			# Round 14 (N1): how far the hull went the WRONG way (against the leg's gear) before the leg took hold.
			var from: Array = _kturn_rec["_from"]
			var along := (Vector2(tank.global_position.x - float(from[0]), tank.global_position.z - float(from[1]))
					.dot(Vector2(float(from[2]), float(from[3])))) * _kturn_gear
			_kturn_rec["wrong_way_m"] = snappedf(maxf(float(_kturn_rec["wrong_way_m"]), -along), 0.01)
		cmd.throttle = KTURN_THROTTLE * _kturn_gear
		cmd.turn = _kturn_turn
		kturn_ticks += ctl._step
		return true
	_kturn_check -= ctl._step
	if _kturn_check > 0:
		return false
	_kturn_check = BrainLevers.kturn_check_ticks(tank.team, String(tank.name))  # Round 17 lever (l17k): KTURN_CHECK_TICKS by default
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	var to := Vector3(waypoint.x - here.x, 0.0, waypoint.z - here.z)
	if to.length() < 0.5:
		return false
	var error := forward.signed_angle_to(to, Vector3.UP)
	if reverse_log:
		_note_look(waypoint, here, forward, error)
	if absf(error) < deg_to_rad(KTURN_MIN_ERROR_DEG):
		return false
	# Positive error = the point is to the LEFT, which is a negative turn (Steering's convention; the plant yaws the
	# hull the way of `turn` in EITHER gear, so the reverse leg keeps the same lock and keeps swinging toward it).
	var turn := -1.0 if error >= 0.0 else 1.0
	var map := tank.get_world_3d().navigation_map
	var frame := _kturn_frame(tank)
	# Only a wall the arc meets SOON: a hit further along is a corner the route bends round, which the carrot and the
	# steering's own easing take wider than full lock does; a reverse in the middle of a street corner is the wrong move.
	# Round 16 (brains, switch kturn_lazy): the start pose's outline is read only where a probe along the arc is already
	# beyond the clear reach (`_outline_ok`: off > max(reach, start + 0.05) is off > reach AND off > start + 0.05), which
	# in open ground is never; so its ten navmesh queries are made per point, on the probe that needs one, and all of
	# them once a plan is to be made from it. The same numbers, asked later or not at all.
	var lazy := BrainSwitches.kturn_lazy and BrainSwitches.kturn_cap
	var start := PackedFloat32Array() if lazy else _outline_offs(map, frame, here, forward)
	if lazy:
		_lazy_map = map
		_lazy_frame = frame
		_lazy_at = here
		_lazy_heading = forward
		_lazy_start.resize(KTURN_OUTLINE.size())
		_lazy_start.fill(-1.0)
	# Round 15 (V2): a moving hull looks a stopping distance further, and plans from where it will come to rest.
	var stop := _look_stop()
	# Round 16 (brains, switch `kturn_cap`): the sweep only has to look as far as the hit can matter. Below, a hit beyond
	# KTURN_HIT_WITHIN_M + stop does exactly what no hit at all does (no plan, no easing), and the arc used to be swept
	# on to its end (up to 3/4 of a full-lock circle, 10 navmesh queries a metre) to find a distance nothing reads: the
	# value is read again only by a leg's diagnosis, and a leg is planned only from a hit inside the cap. 58 of the 99
	# closest-point queries a tick at 50 units were this planner's (builder0, 26722b91).
	var cap := KTURN_HIT_WITHIN_M + stop if BrainSwitches.kturn_cap else INF
	_kturn_hit_m = _arc_hit(map, frame, here, forward, turn, waypoint, start, cap)
	if _kturn_hit_m > KTURN_HIT_WITHIN_M:
		if stop > 0.0 and _kturn_hit_m <= KTURN_HIT_WITHIN_M + stop:
			_ease_for(_kturn_hit_m)
		return false
	if lazy:
		for i in KTURN_OUTLINE.size():
			_lazy_start_at(i)
		start = _lazy_start.duplicate()
	var rolled := 0.0
	if stop > 0.0 and switched_off("kturnrollout"):
		var rest := _rollout(here, forward, turn, wheel_radius())
		rolled = _flat_distance(here, rest[0])
		here = rest[0]
		forward = rest[1]
		var there := _outline_offs(map, frame, here, forward)
		for i in start.size():
			start[i] = maxf(start[i], there[i])  # it will be there whatever is planned: no deeper than THAT
		kturn_looked += 1
	var at := here
	var heading := forward
	var backed := 0.0
	var radius := wheel_radius()
	var blocked_at := -1.0  # round 12 (N1), measurement only: where the reverse search met something, if it did
	while backed < KTURN_BACK_MAX_M:
		heading = TankMotion.turn_heading(heading, KTURN_BACK_STEP_M * turn / radius)
		at -= heading * KTURN_BACK_STEP_M
		backed += KTURN_BACK_STEP_M
		if not _outline_ok(map, frame, at, heading, start):
			blocked_at = backed
			break  # the hull would hit what is behind (or swing its nose into what is beside): no further back
		if _arc_hit(map, frame, at, heading, turn, waypoint, start) == INF:
			_kturn_turn = turn
			_kturn_plan_kind = "single"
			_kturn_start_offs = start
			_kturn_leg_no = 0
			if rolled > 0.0:
				_kturn_plan_pose = [here, forward]
			_kturn_start_leg(Vector2(-1.0, minf(backed + KTURN_BACK_EXTRA_M, KTURN_BACK_MAX_M)))
			kturns += 1
			cmd.throttle = -KTURN_THROTTLE
			cmd.turn = turn
			kturn_ticks += ctl._step
			return true
	# Round 12 (N2): no single back-up clears. The back-and-fill replaces THIS branch only (Invariant 0c): what it
	# cannot plan falls through to `kturn_none` and the reactive rules exactly as before.
	if fill_on():
		var plan := _best_fill(map, frame, here, forward, turn, waypoint, start)
		if not plan.is_empty():
			_kturn_turn = turn
			_kturn_legs = plan
			_kturn_plan_kind = "fill"
			_kturn_start_offs = start
			_kturn_leg_no = 0
			var first: Vector2 = _kturn_legs.pop_front()
			if rolled > 0.0:
				_kturn_plan_pose = [here, forward]
				if first.x > 0.0:
					first.y += rolled  # planned from the rest pose, counted from here: the roll is on the same lock
			_kturn_start_leg(first)
			kturn_multi += 1
			kturn_multi_legs += plan.size() + 1
			if kturn_log:
				kturn_fill_log.append({"unit": String(tank.name), "frame": Engine.get_physics_frames(),
						"at": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)], "to": [snappedf(waypoint.x, 0.1), snappedf(waypoint.z, 0.1)],
						"heading_deg": snappedf(rad_to_deg(atan2(forward.x, -forward.z)), 1.0),
						"plan": ([_kturn_gear * _kturn_left_m] + plan.map(func(leg: Vector2) -> float: return leg.x * leg.y)),
						"goal_m": snappedf(_flat_distance(here, _goal), 0.1) if _goal != Vector3.INF else -1.0})
			cmd.throttle = KTURN_THROTTLE * _kturn_gear
			cmd.turn = turn
			kturn_ticks += ctl._step
			return true
	kturn_none += 1
	if kturn_log:
		kturn_none_log.append(_kturn_diagnose(map, frame, here, forward, turn, waypoint, start, blocked_at))
	_kturn_check = KTURN_RETRY_TICKS  # nothing within reach: do not search again every few ticks
	return false


## The hull's footprint as [half width, half length, bake radius - margin] (cached per unit id by hull_box).
func _kturn_frame(tank: Tank) -> Array:
	var size: Array = hull_box(tank.unit_id)
	return [float(size[0]) * 0.5, float(size[2]) * 0.5, bake_radius(tank) - KTURN_MARGIN_M]


## Sweep the forward full-lock arc from (at, heading) until the hull points at `target`: how far it travels before the
## hull's outline is no longer clear (`start`: see _outline_ok) (INF = the whole arc is clear, or it never lines up:
## the point is inside the turning circle, which is Steering's own circle test's case, not this rule's).
## `cap`: stop sweeping once `travelled` reaches it and answer INF, as for a clear arc. Every step up to the first one at or
## past the cap is still taken, so any hit at a distance <= cap is found and reported exactly as before.
func _arc_hit(map: RID, frame: Array, at: Vector3, heading: Vector3, turn: float, target: Vector3, start: PackedFloat32Array,
		cap := INF) -> float:
	var radius := wheel_radius()
	if BrainSwitches.native and BrainSwitches.native_move and BrainSwitches.kturn_cap \
			and (not start.is_empty() or (_lazy_map == map and _lazy_frame == frame)):
		# Round 23 (native N2b, C23.1): the whole sweep as one native call (nav_native.cpp arc_hit), the same bits;
		# the loop below is the reference.
		# Every check holds this seam to the LIVE loop below (tests/test_native_movement_geometry.gd): edit one, edit both.
		return NativeBridge.nav.arc_hit(map, float(frame[0]), float(frame[1]), float(frame[2]), at, heading, turn, target,
				start, cap, radius, _lazy_at, _lazy_heading)
	var travelled := 0.0
	var limit := TAU * radius * KTURN_SWEEP_TURNS
	while travelled < limit and travelled < cap:
		var to := Vector3(target.x - at.x, 0.0, target.z - at.z)
		if absf(heading.signed_angle_to(to, Vector3.UP)) <= deg_to_rad(KTURN_ALIGNED_DEG):
			return INF
		heading = TankMotion.turn_heading(heading, KTURN_STEP_M * turn / radius)
		at += heading * KTURN_STEP_M
		travelled += KTURN_STEP_M
		if not _outline_ok(map, frame, at, heading, start):
			return travelled
	return INF


## The hull outline sampled as [along, across] in half-lengths / half-widths: corners, end middles, side quarters.
## ALL of it, both ends: the plant yaws a wheeled hull about its CENTRE, so the end that is not leading swings out as
## far as the one that is (the first build swept only the leading end, and its reverse legs scraped their noses:
## 169 contact ticks on one laptop rig run).
const KTURN_OUTLINE: Array[Vector2] = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, 0),
		Vector2(-1, 0), Vector2(0.5, 1), Vector2(0.5, -1), Vector2(-0.5, 1), Vector2(-0.5, -1)]


## kturn_lazy's start pose and its outline, filled point by point (-1 = not asked yet).
var _lazy_map := RID()
var _lazy_frame: Array = []
var _lazy_at := Vector3.ZERO
var _lazy_heading := Vector3.ZERO
var _lazy_start := PackedFloat32Array()


## Outline point `i` at the lazy start pose: exactly _outline_offs' arithmetic for that point.
func _lazy_start_at(i: int) -> float:
	if _lazy_start[i] < 0.0:
		var right := Vector3(-_lazy_heading.z, 0.0, _lazy_heading.x)
		var sample: Vector2 = KTURN_OUTLINE[i]
		var point := _lazy_at + _lazy_heading * (sample.x * float(_lazy_frame[1])) + right * (sample.y * float(_lazy_frame[0]))
		var closest := Pathing.closest_point(_lazy_map, point, "kturn")
		_lazy_start[i] = Vector2(closest.x - point.x, closest.z - point.z).length()
	return _lazy_start[i]


## How far off the navmesh each outline point is at this pose (metres).
func _outline_offs(map: RID, frame: Array, at: Vector3, heading: Vector3) -> PackedFloat32Array:
	var right := Vector3(-heading.z, 0.0, heading.x)
	var offs := PackedFloat32Array()
	for sample: Vector2 in KTURN_OUTLINE:
		var point := at + heading * (sample.x * float(frame[1])) + right * (sample.y * float(frame[0]))
		var closest := Pathing.closest_point(map, point, "kturn")
		offs.append(Vector2(closest.x - point.x, closest.z - point.z).length())
	return offs


## Is the outline clear at this pose: every point within the clear reach of the mesh, or — for a point that was
## already closer to a wall than that where the plan started (a nose parked against a face) — no deeper than it was.
func _outline_ok(map: RID, frame: Array, at: Vector3, heading: Vector3, start: PackedFloat32Array) -> bool:
	if BrainSwitches.kturn_cap:
		if BrainSwitches.native and BrainSwitches.native_move \
				and (not start.is_empty() or (_lazy_map == map and _lazy_frame == frame)):
			# Round 23 (native N2b, C23.1): the ten points as one native call (nav_native.cpp outline_ok), the same bits
			# (the lazy start pose's points recomputed rather than memoised: the same numbers); the loop below is the reference.
			# Every check holds this seam to the LIVE loop below (tests/test_native_movement_geometry.gd): edit one, edit both.
			return NativeBridge.nav.outline_ok(map, float(frame[0]), float(frame[1]), float(frame[2]), at, heading, start,
					_lazy_at, _lazy_heading)
		# Round 16: the same test, sample by sample, stopping at the first point out (the answer is false either way;
		# the points after it were queried and never read).
		var right := Vector3(-heading.z, 0.0, heading.x)
		for i in KTURN_OUTLINE.size():
			var sample: Vector2 = KTURN_OUTLINE[i]
			var point := at + heading * (sample.x * float(frame[1])) + right * (sample.y * float(frame[0]))
			var closest := Pathing.closest_point(map, point, "kturn")
			var off: float = Vector2(closest.x - point.x, closest.z - point.z).length()
			if off > float(frame[2]):
				# start empty = the planned-reverse check's lazy start pose (kturn_lazy).
				var from_start: float = start[i] if not start.is_empty() else _lazy_start_at(i)
				if off > from_start + 0.05:
					return false
		return true
	var offs := _outline_offs(map, frame, at, heading)
	for i in offs.size():
		if offs[i] > maxf(float(frame[2]), start[i] + 0.05):
			return false
	return true


# --- Round 12 (nav N1/N2): the back-and-fill, and the instrument that asked for it ------------------------------------
#
# The round-11 planned reverse searches ONE back-up (same lock, up to KTURN_BACK_MAX_M) after which the forward arc is
# clear. For the War Rig (14 m, 12 m radius) in an 18-22 m street it found none 130 times against 64 legs (builder0,
# `38c385d5`, 8 seeds). N1 logs, for every such refusal, what the search saw; `_plan_fill` is the manoeuvre a driver does
# when one back-up is not enough: legs alternating gear, every leg on the SAME lock (the plant yaws the hull the way of
# `turn` in either gear — TankMotion.step's wheels branch — so every leg keeps swinging the nose toward the point), each
# leg driven as far as the hull's outline stays clear of the navmesh edge less KTURN_FILL_MARGIN_M, and the manoeuvre
# done at the first reverse pose from which the forward arc is clear. Validated with the WHOLE outline at every step
# (both ends swing: `_outline_ok`), so the end leading a leg is always checked.

## Measurement only (the drive test's `--kturn-log`): every `kturn_none` appends what the search saw.
static var kturn_log := false
static var kturn_multi := 0        # back-and-fills planned (the single back-up found none; this did)
static var kturn_multi_legs := 0   # ...and their legs, summed
static var kturn_none_log: Array = []
static var kturn_fill_log: Array = []   # ...and every back-and-fill planned (measurement only)
## A back-and-fill leg is at most this long, is backed off this far from the first pose that is not clear, and a leg
## shorter than KTURN_FILL_LEG_MIN_M after that is no progress (the plan fails rather than dither).
const KTURN_FILL_LEG_MAX_M := 10.0
const KTURN_FILL_MARGIN_M := 0.25
const KTURN_FILL_LEG_MIN_M := 0.5
## The most legs a plan may have (the last is always a reverse; the forward arc after it is the ordinary driver's).
## N1 (laptop, 8 seeds, the rigs' 132 refusals): a plan of at most 3 legs existed for 29, at most 5 for 39, at most 8
## for 57, at most 16 for 77. Five: a five-point turn is still a driver's manoeuvre; eight half-metre shuffles are not.
const KTURN_FILL_LEGS := 5


static func fill_on() -> bool:
	return kturn_on() and not switched_off("kturnfill")


## Start driving one leg, Vector2(gear, metres), from where the hull is now.
func _kturn_start_leg(leg: Vector2) -> void:
	_kturn_gear = int(leg.x)
	_kturn_left_m = leg.y
	_kturn_from = ctl.tank.global_position
	_kturn_timeout = leg.y * KTURN_SECONDS_PER_M + 1.0
	# Round 14 (N3): rolling the other way at the start (the last leg's momentum): the distance counts from where the
	# hull starts moving in this leg's gear, and the timeout allows the braking.
	_kturn_rolling = not kturn_brake_on() or ctl.tank.speed() * leg.x > -KTURN_ROLLING_SPEED
	if not _kturn_rolling:
		_kturn_timeout += absf(ctl.tank.speed()) / _braking()
	_kturn_leg_no += 1
	if reverse_log:
		_kturn_rec = _kturn_leg_diagnose(leg)
		kturn_leg_log.append(_kturn_rec)
	_kturn_plan_pose = []


## The back-and-fill to drive: reverse-first or forward-first, fewer legs first, then less travel (reverse-first on a
## tie: it keeps the nose off the wall the forward arc was about to meet).
func _best_fill(map: RID, frame: Array, here: Vector3, forward: Vector3, turn: float, target: Vector3,
		start: PackedFloat32Array) -> Array:
	var best: Array = []
	for first in [-1, 1]:
		var plan := _plan_fill(map, frame, here, forward, turn, target, start, first, KTURN_FILL_LEGS)
		if plan.is_empty():
			continue
		if best.is_empty() or plan.size() < best.size() or (plan.size() == best.size() and _fill_metres(plan) < _fill_metres(best)):
			best = plan
	return best


static func _fill_metres(plan: Array) -> float:
	var metres := 0.0
	for leg: Vector2 in plan:
		metres += leg.y
	return metres


## One step of `metres` along the plant's yaw law in `gear` (+1 forward, -1 reverse) on lock `turn`.
static func _fill_step(at: Vector3, heading: Vector3, gear: int, turn: float, radius: float, metres: float) -> Array:
	heading = TankMotion.turn_heading(heading, metres * turn / radius)
	return [at + heading * (metres * gear), heading]


## The back-and-fill from (here, forward): legs as Vector2(gear, metres), in order, the first in `first_gear`; empty if
## no plan of at most `max_legs` legs clears the forward arc toward `target`. Deterministic: fixed steps, fixed order.
func _plan_fill(map: RID, frame: Array, here: Vector3, forward: Vector3, turn: float, target: Vector3,
		start: PackedFloat32Array, first_gear: int, max_legs: int, margin := KTURN_FILL_MARGIN_M,
		leg_min := KTURN_FILL_LEG_MIN_M) -> Array:
	var radius := wheel_radius()
	var at := here
	var heading := forward
	var legs: Array = []
	var gear := first_gear
	for leg in max_legs:
		var travelled := 0.0
		var poses: Array = []  # the pose after each step, so the leg can be backed off without re-simulating
		var cleared := false
		while travelled < KTURN_FILL_LEG_MAX_M:
			var next := _fill_step(at if poses.is_empty() else poses[-1][0], heading if poses.is_empty() else poses[-1][1],
					gear, turn, radius, KTURN_BACK_STEP_M)
			if not _outline_ok(map, frame, next[0], next[1], start):
				break
			poses.append(next)
			travelled += KTURN_BACK_STEP_M
			if gear < 0 and _arc_hit(map, frame, next[0], next[1], turn, target, start) == INF:
				cleared = true
				break
		if cleared:
			# As the single leg does: a little past the first clear pose, if that is clear too.
			var extra := _fill_step(poses[-1][0], poses[-1][1], gear, turn, radius, KTURN_BACK_EXTRA_M)
			if _outline_ok(map, frame, extra[0], extra[1], start):
				travelled += KTURN_BACK_EXTRA_M
			legs.append(Vector2(gear, travelled))
			return legs
		var usable := travelled - margin
		if usable < leg_min:
			return []
		var steps := int(floor(usable / KTURN_BACK_STEP_M))
		usable = steps * KTURN_BACK_STEP_M
		at = poses[steps - 1][0]
		heading = poses[steps - 1][1]
		legs.append(Vector2(gear, usable))
		gear = -gear
	return []


## N1: what the search saw at one `kturn_none` (measurement only; reads the navmesh and the other hulls, changes nothing).
func _kturn_diagnose(map: RID, frame: Array, here: Vector3, forward: Vector3, turn: float, target: Vector3,
		start: PackedFloat32Array, blocked_at: float) -> Dictionary:
	var tank := ctl.tank
	var radius := wheel_radius()
	var reach := float(frame[2])
	var pressed := 0
	for off: float in start:
		if off > reach:
			pressed += 1
	var out := {"unit": String(tank.name), "id": tank.unit_id, "frame": Engine.get_physics_frames(),
			"at": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)], "to": [snappedf(target.x, 0.1), snappedf(target.z, 0.1)],
			"error_deg": snappedf(rad_to_deg(forward.signed_angle_to(target - here, Vector3.UP)), 1.0),
			"hit_m": _arc_hit(map, frame, here, forward, turn, target, start), "reach_m": snappedf(reach, 0.01),
			"pressed_points": pressed, "start_max_off_m": snappedf(Array(start).max(), 0.01),
			"blocked_at_m": blocked_at, "goal_m": snappedf(_flat_distance(here, _goal), 0.1) if _goal != Vector3.INF else -1.0,
			"point_is_goal": _goal != Vector3.INF and _flat_distance(target, _goal) < 0.5}
	# Which part of the outline stopped the single back-up.
	if blocked_at > 0.0:
		var pose := [here, forward]
		for i in int(round(blocked_at / KTURN_BACK_STEP_M)):
			pose = _fill_step(pose[0], pose[1], -1, turn, radius, KTURN_BACK_STEP_M)
		out["blocked_by"] = _outline_part(map, frame, pose[0], pose[1], start)
	# A longer single back-up (no 8 m cap): does one exist at all?
	out["longer_m"] = _single_backup(map, frame, here, forward, turn, turn, target, start, 30.0)
	# A straight back-up (no lock) before the same forward arc.
	out["straight_m"] = _single_backup(map, frame, here, forward, 0.0, turn, target, start, KTURN_BACK_MAX_M)
	# The back-and-fill, both first gears, up to five legs (the planner's own cap is KTURN_FILL_LEGS).
	for first in [-1, 1]:
		var plan := _plan_fill(map, frame, here, forward, turn, target, start, first, 5)
		out["fill_%s" % ("rev" if first < 0 else "fwd")] = plan.map(func(leg: Vector2) -> float: return snappedf(leg.x * leg.y, 0.1))
	# How many legs a tight many-point turn would take (0.25 m margin, 0.5 m legs, up to 16 legs): is there ANY?
	for first in [-1, 1]:
		var many := _plan_fill(map, frame, here, forward, turn, target, start, first, 16, 0.25, 0.5)
		out["many_%s" % ("rev" if first < 0 else "fwd")] = [many.size(), snappedf(many.reduce(
				func(sum: float, leg: Vector2) -> float: return sum + leg.y, 0.0), 0.1)]
	# The street: free run of the hull's CENTRE on the mesh along four axes relative to the heading.
	var spans := []
	for deg in [0.0, 45.0, 90.0, 135.0]:
		var axis := forward.rotated(Vector3.UP, deg_to_rad(deg))
		spans.append(snappedf(_free_run(map, here, axis, reach) + _free_run(map, here, -axis, reach), 0.1))
	out["spans_m"] = spans  # [along heading, 45, across, 135]; physical width ~ span + 2 × bake radius
	out["bake_radius_m"] = snappedf(bake_radius(tank), 0.01)
	# Friends: the nearest other hull, and whether one sits in the box the back-up sweeps (behind, within a leg).
	var nearest := INF
	var behind := false
	var half_w := float(frame[0])
	var half_l := float(frame[1])
	if ctl.tanks_root != null:
		for other in ctl.tanks_root.get_children():
			if other == tank or not (other is Tank):
				continue
			var rel := (other as Tank).global_position - here
			rel.y = 0.0
			nearest = minf(nearest, rel.length())
			var along := rel.dot(forward)
			var across := absf(rel.dot(Vector3(-forward.z, 0.0, forward.x)))
			if along < 0.0 and along > -(half_l * 2.0 + KTURN_BACK_MAX_M) and across < half_w + 3.0:
				behind = true
	out["friend_nearest_m"] = snappedf(nearest, 0.1) if nearest < INF else -1.0
	out["friend_behind"] = behind
	return out


## The shortest back-up on lock `back_turn` (up to `limit` m) after which the forward arc on `turn` is clear, or -1
## (-2 - metres when the outline was blocked first, so the log says how far it got).
func _single_backup(map: RID, frame: Array, here: Vector3, forward: Vector3, back_turn: float, turn: float,
		target: Vector3, start: PackedFloat32Array, limit: float) -> float:
	var radius := wheel_radius()
	var pose := [here, forward]
	var backed := 0.0
	while backed < limit:
		pose = _fill_step(pose[0], pose[1], -1, back_turn, radius, KTURN_BACK_STEP_M)
		backed += KTURN_BACK_STEP_M
		if not _outline_ok(map, frame, pose[0], pose[1], start):
			return -2.0 - backed
		if _arc_hit(map, frame, pose[0], pose[1], turn, target, start) == INF:
			return backed
	return -1.0


## Which part of the outline is not clear at this pose: nose, rear, side_fore, side_aft (the first failing sample).
func _outline_part(map: RID, frame: Array, at: Vector3, heading: Vector3, start: PackedFloat32Array) -> String:
	var offs := _outline_offs(map, frame, at, heading)
	for i in offs.size():
		if offs[i] > maxf(float(frame[2]), start[i] + 0.05):
			var sample: Vector2 = KTURN_OUTLINE[i]
			if sample.y == 0.0:
				return "nose" if sample.x > 0.0 else "rear"
			if absf(sample.x) == 1.0:
				return "nose_corner" if sample.x > 0.0 else "rear_corner"
			return "side_fore" if sample.x > 0.0 else "side_aft"
	return "none"


## How far a point can go from `at` along `axis` before it is more than `reach` off the mesh (0.5 m steps, 40 m cap).
static func _free_run(map: RID, at: Vector3, axis: Vector3, reach: float) -> float:
	var run := 0.0
	while run < 40.0:
		var point := at + axis * (run + 0.5)
		var closest := Pathing.closest_point(map, point, "kturn_run")
		if Vector2(closest.x - point.x, closest.z - point.z).length() > reach:
			break
		run += 0.5
	return run


# ---- Round 14 (nav N1): the instrument for the other 53 % -----------------------------------------------------------
#
# After round 13 the rigs' reverse-gear wall contacts are `route` 820 and `kturn` 713 (builder0, 16 seeds). Neither is
# right-of-way. `route` reverses have more than one source (Steering's circle rule on a forward order, the station PID,
# a reverse order); `kturn` legs are planned with the outline sweep yet end in walls. The drive test's `--reverse-log`
# logs, per episode, what the rule saw and what the hull then did, the way `--yield-log` logs a give-way:
#
# - **Circle episodes** (`circle_log`, `NAV_CIRCLE`): a run of ticks in which Steering's circle rule backs a wheeled hull
#   on a forward route order at full lock. What it saw (the point in hull coordinates, whether it is the route's end,
#   the distance left), the reverse it commits to (how far until the rule lets go, stepped with the rule itself and the
#   plant's yaw law) against how far the whole outline stays clear (`_outline_ok`, the planned reverse's test), the
#   forward arcs' clear run on either lock, and — filled in as it drives — the metres driven, how it ended, and the
#   contacts by gear, end and collider.
# - **K-turn legs** (`kturn_leg_log`, `NAV_KTURN_LEG`): every planned leg (single back-up or back-and-fill leg). The
#   plan (gear, metres, the pose the planner predicts at its end and the clearance margin it predicts along it) against
#   the drive (metres driven, how it ended: done / next / lead_hit / timeout / cancelled / reset; the pose it ended at
#   and its error against the planner's pose at the SAME distance; the clearance margin there), and the contacts.
#
# WallContact also splits every route-driven reverse-gear contact by `why` (`by_reverse_why`: circle / station / order /
# other), always on. Measurement only: nothing here is read by a decision.

## Round 15 (V1), measurement only: `--leg-print` turns the leg log on in ANY harness (the AI scenarios, a match) and
## prints each k-turn leg's row as it closes (`NAV_KTURN_LEG`), with the hull and the brain's option it was driven under.
static var leg_print := OS.get_cmdline_user_args().has("--leg-print")
static var reverse_log := leg_print
static var kturn_leg_log: Array = []
static var circle_log: Array = []
## Which rule put a route-driven hull in reverse this tick ("" = not reversing); read once by note_decision.
var _reverse_why := ""
var _kturn_rec := {}
var _kturn_plan_kind := ""
var _kturn_leg_no := 0
var _kturn_start_offs := PackedFloat32Array()
var _circle_rec := {}
var _circle_last := Vector3.INF


## The smallest clearance left at this pose (metres, negative = the outline is past what `_outline_ok` accepts).
func _outline_margin(map: RID, frame: Array, at: Vector3, heading: Vector3, start: PackedFloat32Array) -> float:
	var offs := _outline_offs(map, frame, at, heading)
	var least := INF
	for i in offs.size():
		var allowed := maxf(float(frame[2]), (start[i] + 0.05) if i < start.size() else 0.0)
		least = minf(least, allowed - offs[i])
	return least


static func _flat_xz(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.z, 0.01)]


static func _heading_deg(forward: Vector3) -> float:
	return rad_to_deg(atan2(forward.x, -forward.z))


func _kturn_leg_diagnose(leg: Vector2) -> Dictionary:
	var tank := ctl.tank
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	if not _kturn_plan_pose.is_empty():  # planned from the roll-out pose, not from here (round 14 N2)
		here = _kturn_plan_pose[0]
		forward = _kturn_plan_pose[1]
	var row := {"unit": String(tank.name), "unit_id": tank.unit_id, "frame": Engine.get_physics_frames(),
			"kind": _kturn_plan_kind, "leg_no": _kturn_leg_no, "legs_left": _kturn_legs.size(), "gear": int(leg.x),
			"planned_m": snappedf(leg.y, 0.01), "turn": _kturn_turn, "at": _flat_xz(here),
			"heading_deg": snappedf(_heading_deg(forward), 0.1), "contacts": 0, "reverse_contacts": 0, "hit": {}, "ends": {},
			"moving": {}, "v0": snappedf(tank.speed(), 0.01), "wrong_way_m": 0.0, "_from": [here.x, here.z, forward.x, forward.z],
			"hull_len": snappedf(float(hull_box(tank.unit_id)[2]), 0.01), "remaining_m": snappedf(_remaining, 0.1),
			"braking": snappedf(_braking(), 0.1), "looks": _kturn_looks.duplicate()}
	# Round 15 (V1): the plan's purpose as the brain saw it (a scenario's orbit vs a street march), for the key.
	var choice: Variant = ctl.get("choice")
	row["option"] = String((choice as Dictionary).get("option", "")) if choice is Dictionary else ""
	if Pathing.enabled and Pathing.is_ready(tank):
		var map := tank.get_world_3d().navigation_map
		var frame := _kturn_frame(tank)
		var pose := [here, forward]
		var least := INF
		var travelled := 0.0
		while travelled < leg.y - 0.001:
			var step := minf(KTURN_BACK_STEP_M, leg.y - travelled)
			pose = _fill_step(pose[0], pose[1], int(leg.x), _kturn_turn, wheel_radius(), step)
			travelled += step
			least = minf(least, _outline_margin(map, frame, pose[0], pose[1], _kturn_start_offs))
		row["pred_end"] = _flat_xz(pose[0])
		row["pred_heading_deg"] = snappedf(_heading_deg(pose[1]), 0.1)
		row["pred_margin_m"] = snappedf(least, 0.01) if least < INF else null
		row["start_margin_m"] = snappedf(_outline_margin(map, frame, here, forward, _kturn_start_offs), 0.01)
		# Round 14 (N3): planned in time? The forward arc's hit distance when planned, the forward roll-out before the
		# leg can take hold (v^2 / 2b on the leg's lock), and the least clearance along that roll-out.
		var speed := tank.speed() * float(-leg.x)  # rolling AGAINST the leg's gear
		row["hit_m"] = snappedf(_kturn_hit_m, 0.01) if _kturn_hit_m < INF else -1.0
		if speed > KTURN_ROLLING_SPEED:
			var braking := maxf(float(Units.stat(tank.unit_id, "braking_mps2", 8.0)), 0.1)
			var stop := speed * speed / (2.0 * braking)
			row["stop_m"] = snappedf(stop, 0.01)
			var rolled := [here, forward]
			var least_roll := INF
			var gone := 0.0
			while gone < stop - 0.001:
				var step := minf(KTURN_BACK_STEP_M, stop - gone)
				rolled = _fill_step(rolled[0], rolled[1], int(-leg.x), _kturn_turn, wheel_radius(), step)
				gone += step
				least_roll = minf(least_roll, _outline_margin(map, frame, rolled[0], rolled[1], _kturn_start_offs))
			row["roll_margin_m"] = snappedf(least_roll, 0.01)
		else:
			row["stop_m"] = 0.0
	return row


func _kturn_end(reason: String) -> void:
	_kturn_looks.clear()  # round 15 (V2): the next plan's looks start after this leg
	if _kturn_rec.is_empty() or _kturn_rec.has("end"):
		return
	var tank := ctl.tank
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	var driven := _flat_distance(here, _kturn_from)
	_kturn_rec["end"] = reason
	_kturn_rec["driven_m"] = snappedf(driven, 0.01)
	_kturn_rec["ticks"] = Engine.get_physics_frames() - int(_kturn_rec["frame"])
	_kturn_rec["end_at"] = _flat_xz(here)
	_kturn_rec["end_heading_deg"] = snappedf(_heading_deg(forward), 0.1)
	var from: Array = _kturn_rec["_from"]
	if Pathing.enabled and Pathing.is_ready(tank):
		# The planner's pose after the metres actually driven (the steering-law drift is the difference).
		var pose := [Vector3(float(from[0]), 0.0, float(from[1])), Vector3(float(from[2]), 0.0, float(from[3]))]
		var travelled := 0.0
		while travelled < driven - 0.001:
			var step := minf(KTURN_BACK_STEP_M, driven - travelled)
			pose = _fill_step(pose[0], pose[1], int(_kturn_rec["gear"]), float(_kturn_rec["turn"]), wheel_radius(), step)
			travelled += step
		_kturn_rec["drift_m"] = snappedf(_flat_distance(pose[0], here), 0.01)
		_kturn_rec["drift_deg"] = snappedf(rad_to_deg((pose[1] as Vector3).signed_angle_to(forward, Vector3.UP)), 0.1)
		var map := tank.get_world_3d().navigation_map
		_kturn_rec["end_margin_m"] = snappedf(_outline_margin(map, _kturn_frame(tank), here, forward, _kturn_start_offs), 0.01)
		_kturn_rec["end_part"] = _outline_part(map, _kturn_frame(tank), here, forward, _kturn_start_offs)
	_kturn_rec.erase("_from")
	if leg_print:
		print("NAV_KTURN_LEG %s" % JSON.stringify(_kturn_rec))


## Called by drive() every tick it reaches the steering (reverse_log only): opens a circle episode when the rule starts
## backing the hull, closes it when it lets go.
func _note_circle(circling: bool, waypoint: Vector3, goal: Vector3, remaining: float, radius: float, drive_vector: Vector2) -> void:
	var here := ctl.tank.global_position
	var open := not _circle_rec.is_empty() and not _circle_rec.has("end")
	if circling and not _circling:
		if open:
			_close_circle("restart")
		_circle_rec = _circle_diagnose(waypoint, goal, remaining, radius, drive_vector.y)
		circle_log.append(_circle_rec)
		_circle_last = here
	elif circling and open:
		_circle_rec["driven_m"] = float(_circle_rec["driven_m"]) + _flat_distance(here, _circle_last)
		_circle_last = here
	elif not circling and _circling and open:
		_close_circle("kturn" if _kturn_left_m > 0.0 else ("forward" if drive_vector.x > 0.0 else "stopped"))


func _close_circle(reason: String) -> void:
	_circle_rec["end"] = reason
	_circle_rec["ticks"] = Engine.get_physics_frames() - int(_circle_rec["frame"])
	_circle_rec["driven_m"] = snappedf(float(_circle_rec["driven_m"]), 0.01)
	# Kept (closed) until the next episode: WallContact judges a slide against the PREVIOUS tick's decision, so the
	# episode's last contact arrives the tick after it ends.


func _circle_diagnose(waypoint: Vector3, goal: Vector3, remaining: float, radius: float, turn: float) -> Dictionary:
	var tank := ctl.tank
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var to := Vector3(waypoint.x - here.x, 0.0, waypoint.z - here.z)
	var row := {"unit": String(tank.name), "unit_id": tank.unit_id, "frame": Engine.get_physics_frames(),
			"at": _flat_xz(here), "heading_deg": snappedf(_heading_deg(forward), 0.1), "radius_m": snappedf(radius, 0.1),
			"ahead_m": snappedf(to.dot(forward), 0.1), "right_m": snappedf(to.dot(right), 0.1),
			"point_is_goal": _flat_distance(waypoint, goal) < 0.5, "remaining_m": snappedf(remaining, 0.1),
			"arrive_m": snappedf(_arrive, 0.1), "turn": turn, "phase": phase, "v0": snappedf(tank.speed(), 0.01),
			"driven_m": 0.0, "contacts": 0, "reverse_contacts": 0, "hit": {}, "ends": {}, "moving": {}}
	if not (Pathing.enabled and Pathing.is_ready(tank)):
		return row
	var map := tank.get_world_3d().navigation_map
	var frame := _kturn_frame(tank)
	var start := _outline_offs(map, frame, here, forward)
	row["start_margin_m"] = snappedf(_outline_margin(map, frame, here, forward, start), 0.01)
	# The reverse the rule commits to: backing at this lock until the rule itself would drive forward (its hysteresis:
	# the point RADIUS + margin outside the circle), capped at CIRCLE_SWEEP_MAX_M; and how far of it the outline clears.
	var pose := [here, forward]
	var travelled := 0.0
	var needed := -1.0
	var clear := -1.0
	while travelled < CIRCLE_SWEEP_MAX_M:
		pose = _fill_step(pose[0], pose[1], -1, turn, radius, KTURN_BACK_STEP_M)
		travelled += KTURN_BACK_STEP_M
		if clear < 0.0 and not _outline_ok(map, frame, pose[0], pose[1], start):
			clear = travelled - KTURN_BACK_STEP_M
			row["blocked_by"] = _outline_part(map, frame, pose[0], pose[1], start)
		var rule := Steering.drive_toward_wheels(pose[0], pose[1], waypoint, 0.1, radius, -1.0)
		if rule.x > 0.0:
			needed = travelled
			break
	row["needed_m"] = needed
	row["clear_m"] = clear if clear >= 0.0 else travelled
	row["fits"] = clear < 0.0 and needed >= 0.0
	# The forward alternatives: how far a full-lock forward arc stays clear on the same lock and on the other.
	for lock in [turn, -turn]:
		pose = [here, forward]
		travelled = 0.0
		while travelled < CIRCLE_SWEEP_MAX_M:
			var next := _fill_step(pose[0], pose[1], 1, lock, radius, KTURN_BACK_STEP_M)
			if not _outline_ok(map, frame, next[0], next[1], start):
				break
			pose = next
			travelled += KTURN_BACK_STEP_M
		row["fwd_same_m" if lock == turn else "fwd_other_m"] = travelled
	row["room_behind_m"] = _free_run(map, here - forward * float(frame[1]), -forward, float(frame[2]))
	return row


## The circle episode's reverse is swept at most this far (metres).
const CIRCLE_SWEEP_MAX_M := 20.0


# ---- Round 14 (nav N2): the circle rule consults the wall ------------------------------------------------------------
#
# Steering's circle rule (a point inside the wheeled hull's turning circle on its side -> reverse at full lock until the
# point is WHEELS_CIRCLE_MARGIN outside it) reversed without asking what is behind: N1 (builder0, `8554f3b8`, 8 seeds)
# put ALL of the rigs' `route/reverse` contacts on it (429), ~189 of them the rule backing the rear into a face.
#
# Now every tick the rule backs a hull on a routed forward move, the reverse it is about to drive — CIRCLE_GATE_M plus
# the hull's own reverse stopping distance, at the rule's lock, stepped with the plant's yaw law — is swept with the
# hull's DENSE outline (`_dense_outline`: sides and ends sampled at most 1 m apart; the 10-point outline misses a block
# corner between the side samples of a 14 m hull). Clear: the rule's reverse stands (the rule, tick by tick, is the
# "shorter fit": it backs while the next stretch is clear). Not clear: a forward arc on the OTHER lock (turning away takes
# the point out of the circle) if that is clear; else the rule as before (`circle_none`).
#
# Build 1 (`0df01263`, falsified on the design seeds, builder0): the rule's reverse as a COMMITTED planned leg from the
# roll-out pose. Rigs' reverse-gear contacts 892 -> 2136 and leg time +60 %: a committed leg overrides the rule's own
# tick-by-tick let-go, and its 10-point sweep passed legs that scraped their sides along Block_1 (one rig looped there
# for ~700 contact ticks). Arm counters (unit-ticks): `circle_kept`, `circle_forward`, `circle_none`.
#
# **Not shipped: OPT-IN** (`--nav-off=circlefit` turns it ON). Build 2 (this code, `d8fba199`, builder0, design seeds
# 1-8, rigs): `route/reverse` contacts 431 -> 410 (target: below 215), all contacts 3951 -> 5708, arrivals 110 -> 104
# of 128, leg time +22 %. Half the rule's reverse contacts are the forward ROLL-OUT (N1), which no gate on the reverse
# touches; where the reverse does not fit, the forward arc scrapes instead (`route/forward` 2646 -> 4025). What is left
# is the planner's case (algorithms.md: the kinematic planner). Kept for that work: the dense outline and the gate.

static var circle_kept := 0
## The lock of the forward arc a blocked circle reverse turned into (0 = none): held until the point is out of the circle.
var _circle_away := 0.0
var _circle_away_ticks := 0


## Is the hull touching a wall with its front half (the end a forward arc leads with)?
func _nose_touching(here: Vector3, forward: Vector3) -> bool:
	return contact.touching and Vector2(contact.point.x - here.x, contact.point.z - here.z).dot(Vector2(forward.x, forward.z)) > 0.0
static var circle_forward := 0
static var circle_none := 0
const CIRCLE_GATE_M := 1.0
const CIRCLE_FWD_GATE_M := 2.0
const CIRCLE_THROTTLE := 0.6
## The dense outline's largest gap between samples (metres).
const DENSE_OUTLINE_STEP_M := 1.0


## Round 15 (V1): N3 KEYED BY HULL CLASS. Round 14's N3 (a planned leg ends within its stopping distance, and counts from
## where the hull moves in its gear) made the rigs tidier and quicker but broke `scenario_cp2`'s orbiting scout, whose
## planned back-ups are brake taps (the roll counts as the leg's distance). The leg log (`--leg-print`, Status V1) says
## which key separates them: the HULL. The rig's legs are 14 m hulls whose roll is 6 % of the hull; the scout's taps are
## 3 m hulls rolling 31 % of theirs — "stopping distance as a share" picks the scout, not the rig, so the key is length.
## ON by default for hulls at least KTURN_BRAKE_HULL_M long; `--nav-off=kturnbrake` restores round 14 (off for all);
## `--nav-off=kturnbrakeall` is round 14's opt-in arm (on for every wheeled hull), for measurement.
## The cut: the War Rig only (14 m; every other wheeled hull is <= 8.2 m). Pre-registered first at 5.5 m (the buses and
## trucks too); on the acceptance seeds 17-24 that build met the rigs' contacts bar (-30 %) but the mixed squad's
## contacts rose 1430 -> 1815 (two seeds of eight; none on planned legs), a failed clause, so the mid hulls keep round
## 14's legs and the rig alone stops where its leg was planned (Status V1). `kturnbrakeall` keeps the wider arm.
const KTURN_BRAKE_HULL_M := 10.0


static func kturn_brake_all() -> bool:
	return kturn_on() and switched_off("kturnbrakeall") and not switched_off("kturnbrake")


## Does this hull's planned leg stop where it was planned (N3), or count its roll (round 13's tap)?
func kturn_brake_on() -> bool:
	if not kturn_on() or switched_off("kturnbrake"):
		return false
	return kturn_brake_all() or float(hull_box(ctl.tank.unit_id)[2]) >= KTURN_BRAKE_HULL_M


func _braking() -> float:
	return maxf(float(Units.stat(ctl.tank.unit_id, "braking_mps2", 8.0)), 0.1)


## The distance the hull needs to stop from its speed in the current leg's gear (0 when N3 is off for this hull).
func _kturn_stopping() -> float:
	if not kturn_brake_on():
		return 0.0
	var speed := ctl.tank.speed() * float(_kturn_gear)
	return speed * speed / (2.0 * _braking()) if speed > 0.0 else 0.0


## OPT-IN (`--nav-off=circlefit` turns it ON, like `a7`): falsified on the design seeds in three builds (Status N2).
static func circle_fit_on() -> bool:
	return kturn_on() and switched_off("circlefit")


## The hull outline sampled at most DENSE_OUTLINE_STEP_M apart, as [along, across] in half-lengths / half-widths.
static func _dense_outline(frame: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var along_n := maxi(2, int(ceil(float(frame[1]) * 2.0 / DENSE_OUTLINE_STEP_M)))
	var across_n := maxi(1, int(ceil(float(frame[0]) * 2.0 / DENSE_OUTLINE_STEP_M)))
	for i in along_n + 1:
		var a := -1.0 + 2.0 * float(i) / float(along_n)
		out.append(Vector2(a, 1.0))
		out.append(Vector2(a, -1.0))
	for j in range(1, across_n):
		var c := -1.0 + 2.0 * float(j) / float(across_n)
		out.append(Vector2(1.0, c))
		out.append(Vector2(-1.0, c))
	return out


func _offs_with(map: RID, frame: Array, at: Vector3, heading: Vector3, samples: Array[Vector2]) -> PackedFloat32Array:
	var right := Vector3(-heading.z, 0.0, heading.x)
	var offs := PackedFloat32Array()
	for sample: Vector2 in samples:
		var point := at + heading * (sample.x * float(frame[1])) + right * (sample.y * float(frame[0]))
		var closest := Pathing.closest_point(map, point, "circle")
		offs.append(Vector2(closest.x - point.x, closest.z - point.z).length())
	return offs


## Does `gear` on `lock` for `metres` from (at, heading) keep the dense outline clear (the `_outline_ok` rule)?
func _dense_run_ok(map: RID, frame: Array, samples: Array[Vector2], start: PackedFloat32Array, at: Vector3,
		heading: Vector3, gear: int, lock: float, metres: float) -> bool:
	var pose := [at, heading]
	var travelled := 0.0
	var radius := wheel_radius()
	while travelled < metres - 0.001:
		var step := minf(KTURN_BACK_STEP_M, metres - travelled)
		pose = _fill_step(pose[0], pose[1], gear, lock, radius, step)
		travelled += step
		var offs := _offs_with(map, frame, pose[0], pose[1], samples)
		for i in offs.size():
			if offs[i] > maxf(float(frame[2]), start[i] + 0.05):
				return false
	return true


## The circle rule wants to back the hull (`rule`, its drive vector): keep it, turn it into a forward arc on the other
## lock, or (nothing clear) keep it anyway.
func _circle_gate(point: Vector3, radius: float, rule: Vector2) -> Vector2:
	var tank := ctl.tank
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	var map := tank.get_world_3d().navigation_map
	var frame := _kturn_frame(tank)
	var samples := _dense_outline(frame)
	var start := _offs_with(map, frame, here, forward, samples)
	var nose_touching := _nose_touching(here, forward)
	if _circle_away != 0.0:
		# Turning away (latched): keep the forward arc until the point is the rule's own margin outside the circle (the
		# rule, asked with its backing hysteresis, would stop reversing), while it stays clear and makes progress (a
		# pressed nose may "stay no deeper" forever: the first build of this latch pinned a rig on a floodlight 51 s);
		# then the rule again.
		_circle_away_ticks += ctl._step
		var still_in := Steering.drive_toward_wheels(here, forward, point, 0.1, radius, -1.0).x < 0.0
		var stuck := nose_touching or (_circle_away_ticks > SimClock.TICK_RATE and tank.speed() < STUCK_SPEED)
		if still_in and not stuck and _dense_run_ok(map, frame, samples, start, here, forward, 1, _circle_away, CIRCLE_FWD_GATE_M):
			circle_forward += ctl._step
			return Vector2(CIRCLE_THROTTLE, _circle_away)
		_circle_away = 0.0
		if rule.x >= 0.0:
			return rule
	var braking := maxf(float(Units.stat(tank.unit_id, "braking_mps2", 8.0)), 0.1)
	var reverse_max := float(Units.stat(tank.unit_id, "max_reverse_speed", 4.0))
	var gate := CIRCLE_GATE_M + reverse_max * reverse_max / (2.0 * braking)
	if _dense_run_ok(map, frame, samples, start, here, forward, -1, rule.y, gate):
		circle_kept += ctl._step
		return rule
	if not nose_touching and _dense_run_ok(map, frame, samples, start, here, forward, 1, -rule.y, CIRCLE_FWD_GATE_M):
		circle_forward += ctl._step
		_circle_away = -rule.y
		_circle_away_ticks = 0
		return Vector2(CIRCLE_THROTTLE, -rule.y)
	circle_none += ctl._step
	return rule


## Where the hull comes to rest if it brakes now on lock `turn`: [position, heading] (forward motion only).
func _rollout(here: Vector3, forward: Vector3, turn: float, radius: float) -> Array:
	var tank := ctl.tank
	var speed := tank.speed()
	var pose := [here, forward]
	if speed <= KTURN_ROLLING_SPEED:
		return pose
	var braking := maxf(float(Units.stat(tank.unit_id, "braking_mps2", 8.0)), 0.1)
	var distance := speed * speed / (2.0 * braking)
	var travelled := 0.0
	while travelled < distance - 0.001:
		var step := minf(KTURN_BACK_STEP_M, distance - travelled)
		pose = _fill_step(pose[0], pose[1], 1, turn, radius, step)
		travelled += step
	return pose


## Round 15 (V2), measurement only (`reverse_log`): the planner's last looks before a leg — at every check of a moving
## wheeled hull whose steering point is at least KTURN_ALIGNED_DEG off, the error, the full-lock arc's hit and the
## stopping distance — so the leg log says what an EARLIER trigger would have seen (N5: first legs planned with the hit
## 1.0 m away and a 3.45 m stop).
const KTURN_LOOKS_KEPT := 6
var _kturn_looks: Array = []


func _note_look(waypoint: Vector3, here: Vector3, forward: Vector3, error: float) -> void:
	var tank := ctl.tank
	var hit := -1.0
	if absf(error) >= deg_to_rad(KTURN_ALIGNED_DEG):
		var map := tank.get_world_3d().navigation_map
		var frame := _kturn_frame(tank)
		var arc := _arc_hit(map, frame, here, forward, -1.0 if error >= 0.0 else 1.0, waypoint, _outline_offs(map, frame, here, forward))
		hit = snappedf(arc, 0.1) if arc < INF else -1.0
	var speed := tank.speed()
	_kturn_looks.append({"f": Engine.get_physics_frames(), "err": snappedf(rad_to_deg(absf(error)), 1.0), "hit": hit,
			"v": snappedf(speed, 0.1), "stop": snappedf(speed * speed / (2.0 * _braking()) if speed > 0.0 else 0.0, 0.01)})
	if _kturn_looks.size() > KTURN_LOOKS_KEPT:
		_kturn_looks.pop_front()


## Round 15 (V2, N5): THE PLANNER LOOKS EARLIER FROM A MOVING HULL. The looks before the rigs' late first legs (builder0,
## `f70afa98`, seeds 1-8, V1 on: 16 of 72 first legs, 87 contacts) show a rig already >= 45 deg off its point with the
## arc's hit 9 -> 4 m away while it ACCELERATED to 8 m/s (stop 4.3 m): the 5 m trigger fired inside the stopping
## distance. A keyed hull (`kturn_brake_on`: its legs really stop) moving forward therefore
##   1. EASES OFF when the full-lock arc's hit is within KTURN_HIT_WITHIN_M plus its stop: the throttle is capped so the
##      stop stays KTURN_EASE_CLEAR_M inside the hit (never into the plant's creep band), until the next look; and
##   2. when the 5 m trigger does fire while it rolls, plans the reverse from the ROLL-OUT (`_rollout`: where it comes to
##      rest braking on the lock), not from the pose at the tick.
## A first build REVERSED at the wider trigger instead (hit <= 5 m + stop): on a Terminus probe the rig then backed up at
## a 7 m hit the carrot would have steered wide of (the control turned clean, no contact; the build touched and never
## arrived) — the 5 m bound exists for that, so the earlier look slows the hull and does not plan earlier.
## The brief's "when the roll-out's arc is clear, no reverse" is null by construction: the roll-out runs along the same
## full-lock arc, so what is left of it hits at `hit - stop`.
## Both parts are OPT-IN: `--nav-off=kturnlook` turns part 1 on, `--nav-off=kturnlook,kturnrollout` both (Status V2:
## part 2 made the rigs worse on the design seeds, contacts 4900 -> 6917).
## Counters: `kturn_looked` (plans made from a roll-out), `kturn_eased` (unit-ticks
## the throttle was capped).
const KTURN_EASE_CLEAR_M := 2.5
static var kturn_eased := 0
var _ease_ticks := 0
var _ease_throttle := 1.0


func _ease_for(hit: float) -> void:
	var tank := ctl.tank
	var safe := sqrt(2.0 * _braking() * maxf(hit - KTURN_EASE_CLEAR_M, 0.0))
	var top := maxf(float(Units.stat(tank.unit_id, "max_forward_speed", 10.0)), 0.1)
	_ease_throttle = maxf(safe / top, TankMotion.WHEEL_CREEP_THROTTLE + 0.05)
	_ease_ticks = KTURN_CHECK_TICKS


static var kturn_looked := 0


## OPT-IN (`--nav-off=kturnlook` turns it ON, like `a7`): on the design seeds it removed the late legs it was built for
## and left the rest (the corner jumps, Status V2), with the squad's numbers noise-dominated and press+unstick up 2.6x.
static func kturn_look_off() -> bool:
	return not switched_off("kturnlook")


func _look_stop() -> float:
	if kturn_look_off() or not kturn_brake_on():
		return 0.0
	var speed := ctl.tank.speed()
	return speed * speed / (2.0 * _braking()) if speed > KTURN_ROLLING_SPEED else 0.0


## A leg's motion has begun in its gear once the hull rolls that way faster than this (m/s).
const KTURN_ROLLING_SPEED := 0.3
var _kturn_rolling := true
## The pose a leg was planned from when it is not where the hull is (the roll-out), for the leg log only.
var _kturn_plan_pose: Array = []
## Round 14 (N3), measurement: the forward arc's hit distance when the planner last looked (metres).
var _kturn_hit_m := INF


# ---- Round 14 (nav N4): does a hull that HOLDS block the street behind it? ----------------------------------------
#
# Round 13's give-way gives way IN PLACE when no spot fits (`hold`). The fight net's `blocked_*` share rose on 7 of 12
# runs (one seed) and the question it asks is whether a holding hull leaves the hulls behind it queued. The census
# (measurement only; nothing decides on it): each tick, every hull giving way is a YIELDER, labelled by its spot kind
# (`hold`, `short`, `spot`, `back`); every other hull whose `blocked_by` chain (up to CENSUS_HOPS links through other
# blocked hulls) ends at a yielder is QUEUED behind it. The probes add up queued unit-ticks by the yielder's kind, the
# longest queue, and each yielder's episode (how long it yielded, the most hulls queued behind it at once).

## The spot the current give-way took (round 6's table name, `back(m)`, `short:…`, or `hold`); "" when not yielding.
var yield_spot := ""
const CENSUS_HOPS := 4


static func spot_kind(spot: String) -> String:
	if spot == "hold":
		return "hold"
	if spot.begins_with("short"):
		return "short"
	if spot.begins_with("back"):
		return "back"
	return "spot" if spot != "" else "?"


## {"yielders": {name: kind}, "queued": {name: yielder name}} over the tanks under `root` (alive, with a mover).
static func queue_census(root: Node) -> Dictionary:
	var phase_of := {}
	var by_of := {}
	var yielders := {}
	for tank in root.get_children():
		if not (tank is Tank) or not (tank as Tank).is_alive():
			continue
		var mover := of(tank)
		if mover == null:
			continue
		var name := String(tank.name)
		phase_of[name] = mover.phase
		by_of[name] = mover.blocked_by
		if mover.phase == "yielding" and mover.yield_to != "":
			yielders[name] = spot_kind(mover.yield_spot)
	var queued := {}
	for name: String in phase_of:
		if yielders.has(name) or phase_of[name] != "blocked":
			continue
		var by := String(by_of[name])
		for hop in CENSUS_HOPS:
			if by == "" or by == name or not phase_of.has(by):
				break
			if yielders.has(by):
				queued[name] = by
				break
			if phase_of[by] != "blocked":
				break
			by = String(by_of[by])
	return {"yielders": yielders, "queued": queued}


## Accumulates the census tick by tick (the probes own one each).
class QueueTally:
	var queued_ticks := {}      # yielder kind -> unit-ticks queued behind one
	var yield_ticks := {}       # yielder kind -> unit-ticks yielding
	var longest := 0
	var episodes := {}          # yielder name -> {kind, ticks, most_queued, queued_ticks}
	var closed: Array = []

	func add(census: Dictionary) -> void:
		var yielders: Dictionary = census["yielders"]
		var queued: Dictionary = census["queued"]
		var behind := {}
		for name: String in queued:
			var root := String(queued[name])
			behind[root] = int(behind.get(root, 0)) + 1
			var kind := String(yielders[root])
			queued_ticks[kind] = int(queued_ticks.get(kind, 0)) + 1
		for name: String in yielders:
			var kind := String(yielders[name])
			yield_ticks[kind] = int(yield_ticks.get(kind, 0)) + 1
			var ep: Dictionary = episodes.get(name, {"unit": name, "kind": kind, "ticks": 0, "most_queued": 0, "queued_ticks": 0})
			ep["ticks"] = int(ep["ticks"]) + 1
			ep["most_queued"] = maxi(int(ep["most_queued"]), int(behind.get(name, 0)))
			ep["queued_ticks"] = int(ep["queued_ticks"]) + int(behind.get(name, 0))
			episodes[name] = ep
			longest = maxi(longest, int(behind.get(name, 0)))
		for name: String in episodes.keys():
			if not yielders.has(name):
				closed.append(episodes[name])
				episodes.erase(name)

	func report() -> Dictionary:
		var all: Array = closed + episodes.values()
		var by_kind := {}
		for ep: Dictionary in all:
			var row: Dictionary = by_kind.get(ep["kind"], {"episodes": 0, "ticks": 0, "with_queue": 0, "queued_ticks": 0})
			row["episodes"] = int(row["episodes"]) + 1
			row["ticks"] = int(row["ticks"]) + int(ep["ticks"])
			row["queued_ticks"] = int(row["queued_ticks"]) + int(ep["queued_ticks"])
			if int(ep["most_queued"]) > 0:
				row["with_queue"] = int(row["with_queue"]) + 1
			by_kind[ep["kind"]] = row
		return {"queued_unit_ticks": queued_ticks, "yield_unit_ticks": yield_ticks, "longest_queue": longest,
				"episodes_by_kind": by_kind}

