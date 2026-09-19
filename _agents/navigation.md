# Navigation: how a unit gets where it is sent

> Owned by the **nav** stream (round 6). The contract is **N1** in [workstreams.md](workstreams.md); this file is the
> architecture behind it, written as it is built. The lead's question *"are we using A\*?"* — yes: Godot's
> `NavigationServer3D` runs A* over the navigation polygons baked from the arena's collision at startup
> (`Pathing.find_path`). What was missing in round 5 was everything about *other units*.

## The layers

```
 squad / control / a brain's hop        "be here"          Movement.request(unit, to, opts)   (or a move_to order)
   └─ OrderController (the composer)    one per unit       orders, reflexes → a TankCommand every tick
        ├─ Movement (game/ai/movement.gd)   nav            route, avoidance, right-of-way, unstick, the N1 reading
        │    ├─ Pathing        A* over the navmesh (NavigationServer3D)
        │    ├─ Avoidance      ORCA over the 6 nearest hulls (game/ai/avoidance.gd)
        │    ├─ right-of-way   ask / give way, peer to peer (in movement.gd)
        │    ├─ Pid            station-keeping on a moving goal (game/ai/pid.gd, gains in control_gains.gd)
        │    └─ Steering       heading error → throttle, turn (tracks; wheels by pure pursuit)
        └─ Gunnery (game/ai/gunnery.gd)     combat         when a gun may speak (N5); apply(cmd, seconds) after Movement
   Tank._drive → TankMotion (the plant) → move_and_slide
```

## N1, the Movement API

| Call | Meaning |
|---|---|
| `Movement.request(unit, to, opts)` | Drive the Tank `unit` to `to`. `opts`: `arrive_radius`, `pace` (0.2..1), `facing`, `priority`, `reverse`, `direct`. Replaces the move order (a `move_to` on its controller); the weapon order is untouched. |
| `Movement.state(unit)` | `{"phase", "eta_s", "remaining_m", "path_points", "blocked_by", "goal", "stalled_s"}`, or `{}` for a hull nothing drives (the player's own tank in `make run`, a client's copy). |
| `Movement.eta(unit, to)` | Seconds to drive there: the navmesh route at `ETA_CRUISE_SHARE` (0.85) of top speed, plus the pivot onto the route at the hull's turn rate. Straight line while the navmesh isn't ready. |
| `Movement.cancel(unit)` | Stop where it stands. |
| `Movement.of(unit)` | The unit's mover (or null) — for code in nav's own paths. |

**Phases.** `arrived` — no move order, or steering has nothing left to do inside the arrive radius. `pathing` — a
route is wanted but the navmesh has not synced yet. `driving` — under way and making progress. `blocked` — no progress
(0.5 m closer along the route than its best) for `BLOCKED_SECONDS` (2 s); `blocked_by` names the cause: **the name of
the nearest hull ahead** within 8 m (friend or enemy), else `"no_path"` when the route ends more than 3 m short of the
goal, else `"terrain"`. `yielding` — giving way to a friend that asked (X4); `blocked_by` and `yield_to` name it.

**The guarantee:** a unit with a destination arrives or reports `blocked` with a reason. It never stands still
silently. Round 5's brains declared a stalled move *complete* from 12 m away (`TankBrain.ORDER_STALL_ARRIVE`); that was
deleted at `c8c7a79d`, measured with `make nav-orders` (a unit "completing" 8 m short in a maze corridor had been the
cause of the one unit that never arrived).

**Determinism.** Everything a decision reads is per tick: stall counts in ticks (`_step` under a controller stride),
`delta` = the fixed tick. The blocker scan walks `tanks_root` in scene order and keeps the nearest, strictly, so ties
go to the first in that order — which is the same on every run of one build. No wall clock.

## Where things live

| File | What |
|---|---|
| `game/ai/movement.gd` | N1, and the per-unit mover: `_next_waypoint` (repath every 1 s or when the goal moves 1 m), `_around_fire` (step round a beaten zone), `_avoid` (ORCA), right-of-way (`_negotiate`, `ask`, `right_of_way`), `_keep_station` (PID), `unstick` (blind reverse), progress and phase. |
| `game/ai/avoidance.gd` | ORCA (RVO2's linear programs, ported), the per-tick neighbour table (grid-hashed, one per tick for the whole match), hull radii. |
| `game/ai/pid.gd`, `game/ai/control_gains.gd` | N6: the regulator and its gains as data (per-faction overrides are X8). |
| `game/ai/order_controller.gd` | The composer: orders, reflexes, the controller stride; one `Movement` and one `Gunnery` per controller. Forwards `stalled_ticks`, `_wheel_radius()`, `FIRE_LOOKAHEAD` (Movement) and `engaged_target`, `watch_point`, `spotter`, `engagement_lay`, `ticks_since_fire`, `lane_blocked_ticks`, `lane_blocker`, `hold_for_friends`, `_nearest_shootable()` (Gunnery) for the brains, bridge, HUD and tests that read them there. |
| `game/ai/gunnery.gd` | **combat's**: the firing rules, split out of the controller at CP4. Reads the controller for `tank`, `tanks_root`, `weapon_order`, `move_order`; handed seconds, not ticks. combat's three wiring tests in `test_combat_envelope.gd` go red if its call is cut (checked at the split). |
| `game/ai/pathing.gd` | `find_path`, `is_ready`. |
| `game/ai/steering.gd` | The P controller for tracks and pure pursuit for wheels. |

## X7: path quality

The hull steers at a **carrot** 5 m (cars: 1.2 turning radii, further if needed, see *Wheels*) along the route beyond
its own projection on it — pure pursuit along the polyline — instead of at raw navmesh corners, so corners are rounded
inside the navmesh's 2 m erosion rather than driven to, pivoted on, and left. While facing more than 60° off the route
it steers at a fixed corner instead (a carrot that slides with the hull never gets turned onto). The route is
re-planned when the goal moves > 1 m, the hull is > 5 m off it, it has stalled for 2 s, or every 4 s as a safety net —
not every second as in round 5: the navmesh is static, so a route only goes stale when the hull or the goal moves.

## X8: factions by their gains

`ControlGains.FACTIONS` overrides the default station-keeping gains per faction (the Condemned are the default): the
Syndicate crisp (kp 1.5, kd 0.9), the gangs loose (kp 0.45, kd 0.05), the Law damped (kp 0.7, kd 1.2). The mover
builds its regulator from the unit's faction. A goal re-issued unchanged after 0.35 s means the slot stopped, and
feed-forward stops with it (before that fix every crew overshot a halting slot by ~3.2 m).

## Measuring

`make nav-suite` runs arena's probe over arenas × sizes × traffic in parallel; `make nav-where` is one run that also
names every unit that didn't arrive, where it is and what its Movement says; `make nav-orders` is the lead's own test
WITH BRAINS (5 player squads ordered across one another through control's Orders), recording when each order
completes and how far from its goal the unit really was. `--nav-off=…` switches single mechanisms off for an A/B
(grace, minpace, pushidle, carrot, yield, unstick, repath; `r5sidestep` turns round 5's sidestep back on).

### The measuring switches, and what each one proves

**An unknown name is refused** (`Movement.OFF_NAMES`, round 8): a switch nothing reads switches nothing off, and the
A/B then comes back a clean null with a correct-looking arm header. arena hit that with `flow` on a tree that did not
have it. Add the name to `OFF_NAMES` in the commit that adds the switch.

`--nav-off=a,b` on any run (`make nav-where NAV_FLAGS=--nav-off=…`; in a test, set `Movement._off`,
`Movement.avoidance_on`, `Movement.station_on` directly and restore them). Each isolates one decision:

| switch | turns off | what an A/B with it answers |
|---|---|---|

| `--no-avoidance` | ORCA (X3) | how much arrival and flow come from avoidance at all |
| `--no-station-pid` | PID station-keeping (X6) | P-law chase vs regulated slot (0.35 vs 4.58 m, `test_station_keeping`) |
| `grace` | the 10-tick K1 start window | whether K1's 3-tick response depends on it (it does: control's response test) |
| `minpace` | the 15% creep floor in that window | tail cost of creeping (on outside the window: head-on maze t100 182 → 163 s) |
| `pushidle` | asking a parked friend at once | whether pushing idle units helps (180 vs 182 s: marginal) |
| `yield` | right-of-way (X4) entirely | how much of a jam resolves by negotiation |
| `unstick` | the "room behind" check (old blind reverse) | whether ramming friends in columns matters |
| `repath` | X7's re-plan policy (back to every 1 s) | cost/benefit of re-planning |
| `carrot` | X7's pure-pursuit carrot (round 5's exact corner-following) | path smoothing's effect |
| `standoff` / `commit` | round 7's standoff style / CombatMotion commitment | fixed-gun behaviour; re-aim churn (read live from `NAV_FIGHT_ARM`) |
| `holdband` | **turns ON** round 8's standoff-hold hysteresis (HOLD_SLACK_M, hit-only break; off by default: its A/B missed) | whether hold ↔ move flips are the wheeled "yaw in place" |
| `r5sidestep` | **turns ON** round 5's single-friend sidestep | the one thing X3 REMOVED; it alone restored squad's near-ambush timing (555 → 531 ticks) |

**Two traps, both hit this round — read before trusting an A/B:**
1. **A switch that silently does nothing gives you "no difference" for free.** The first `carrot` switch returned the
   wrong point (0/60 arrived — broken), and an equal result from a switch you haven't seen change *anything* proves
   nothing. Check each switch moves some number before reading an equal result as "not this mechanism".
2. **The moment a nav commit is merged, `main` stops being your control.** I told the orchestrator a failure "happens
   on main too, so it isn't nav" — main already contained my merge. Bisect on named commits (`00c99bf4` before nav,
   `7cce78af` nav's merge), never on "main vs my branch". And the cause turned out to be something *removed*, which no
   switch of added mechanisms can find — hence `r5sidestep`.

`make nav-maze` (arena's, `tests/arena/maze_probe.gd`) is the acceptance instrument: it only watches positions, so it
keeps meaning the same thing whatever nav rewrites. Note it drives plain `OrderController`s, not brains — round 5's
`_around_friends` never ran in it.

## X3: avoidance (ORCA)

Each tick a moving unit wants a velocity: toward its next waypoint at its order's speed, easing off near the end.
`Avoidance.solve` returns the velocity closest to that which keeps clear of its 6 nearest hulls (within 14 m, ordered
by distance then name) for a 2 s horizon, assuming each mover does half the avoiding and a parked unit none. That
velocity is steered at (a point 3–8 m along it) with the throttle scaled by its speed. An avoiding velocity that would
put the hull off the navmesh 3 m ahead is refused: the unit keeps its route and slows instead. Enemies are in the
neighbour set too. Hull radius = mean of half-width and half-length + 0.25 m. Two hulls on one spot part by name.

**K1 comes first.** The player's response guarantee is 100 ms = 3 ticks with nothing spare, and avoidance must not
spend it: for `AVOID_GRACE_TICKS` (10) after a new destination the hull steers along its route and avoidance only sets
its throttle, and a way on that is crowded but not reversed is still driven at `AVOID_MIN_PACE` (15%) at least, so
a new order always visibly starts. (Found by control's response test at 4 ticks; the orchestrator ruled 3 is a hard
constraint, not a target.) A goal that jumps > 3 m counts as a new destination; a slot sliding along does not.

**Wheels.** A car's steering point — route carrot or avoiding point — must be one it can drive *forward* onto,
outside both turning circles; a point inside one is a three-point turn. The carrot walks further along the route (up
to 4 turning radii) until it is; an avoiding point that isn't is dropped for the route. (Found by control's click test:
an IFV with a 1.2-radius carrot three-point-turned for a second on a 40° bend.)

Tanks are not holonomic, so ORCA's "take this velocity now" is only approximately achievable; in practice the hulls
turn fast enough (80°/s) that it resolves. **Do not** read the chosen velocity as a physics guarantee — hulls still
collide through `move_and_slide`, and that is intended (vehicles are vehicles).

## X4: right-of-way

A unit that has made no progress for 1 s names the hull ahead of it (within 8 m, ±60°). If it is a friend with a mover:
a unit going nowhere always gives way to one going somewhere; between two movers the one with the shorter remaining
route gives way; the name breaks a tie; and a unit that gave way to me last time is owed the favour back. The one that
gives way searches `YIELD_SPOTS` (to the side of the asker's line it is already on first, then the far side, then
leading the way out ahead) for a point on the navmesh, clear of the asker's line by both radii + 0.75 m, and 3.5 m from
every other hull. It drives there, holds at least 1 s, and resumes its own order once the asker is past or 9 m away
(at most 6 s). A player's new order cancels giving way at once. It never gives way twice in a row to the same unit.
A mover that avoidance is holding below half speed behind a *parked* friend asks it at once, without waiting for a
stall (StarCraft's "idle units get pushed aside"). A yield spot never lies closer to the asker than the yielder
already is (backing into the unit you are letting past is how two units end up nose to tail), and a car's spot must
be forward-reachable. The unstick routine no longer reverses blind: it backs off only with 2 m of room behind it.
The asking is a direct call on the other unit's mover (`ask(asker, from, direction)` → accepted or not); refused asks
make the asker give way itself.

## X6: station-keeping (N6)

A `move_to` whose goal is moving (estimated from how far it moved between re-issues; > 0.5 m/s; stale after 1 s)
and is within 14 m, on the last leg, is regulated: throttle = (goal speed along my heading + PID on the along-track
gap) / top speed, steering at where the goal will be in 0.6 s. The PID's derivative acts on the gap's own rate (my
speed relative to the goal's), so a slot that jumps doesn't kick. `--no-station-pid` and `--no-avoidance` are the
measuring switches (read once from the command line).

## Measurements

| When | Machine | What | Result |
|---|---|---|---|
| `30e3250d` (= round-5 behaviour) | builder0 | `make nav-suite`, hold-fire, 180 s | arrived: maze-30 15/30, maze-60 35/60, maze-60 head-on **0/60**, yard-60 34/60, yard-60 head-on 33/60, foundry-60 40/60 (`references/nav/nav_suite_30e3250d_baseline.json`). Five seeds were identical: the probe has no randomness. |
| `e291a35a` (X3+X4+X6) | builder0 | same | **60/60 everywhere, 30/30 on maze-30**; t90 maze-60 129 s, head-on 145 s, yard 47 s, foundry 38 s |
| `e291a35a` | builder0 | `test_station_keeping` | a slot at 5 m/s: mean gap 0.35 m (PID) vs 4.58 m (P law) |

| `30e3250d` vs `1923059c` | builder0 | `make ai-perf` (60 brains fighting, `--profile-parts`) | `move` part 1119 → **1688 usec per tick** (+0.57 ms: ORCA, right-of-way, carrot); AI band per living unit 150.4 → 165.9 usec. Different battles (21 vs 19 alive at the end), so the per-part number is the comparable one. |
| `1923059c` | builder0 | `make nav-suite` | 60/60 on maze-60 (t90 120 s), maze-60 head-on (144 s), yard-60 (55 s), yard-60 head-on (42 s), foundry-60 (40 s); maze-30 30/30 (74 s) |

The probe spawns 60 units on 52 spawn points, so 8 pairs start on top of each other; at `30e3250d` those pairs never
moved at all. That is part of the baseline's failure, and a real case (respawns can overlap too).
