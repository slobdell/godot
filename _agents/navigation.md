# Navigation: how a unit gets where it is sent

> Owned by the **nav** stream (round 6). The contract is **N1** in [workstreams.md](workstreams.md); this file is the
> architecture behind it, written as it is built. The lead's question *"are we using A\*?"* — yes: Godot's
> `NavigationServer3D` runs A* over the navigation polygons baked from the arena's collision at startup
> (`Pathing.find_path`). What was missing in round 5 was everything about *other units*.

## Round 9: the desired-velocity layer, and what replaces what

> Written at the start of round 9 (2026-09-19) and kept current as each row lands. The backlog rows are A7, A11, A1
> and A4 in [research_catalog.md](research_catalog.md); the sequencing argument is in [workstreams.md](workstreams.md)
> *Round 9 goal*; the brief is [streams/nav.md](streams/nav.md).

**The Invariant 0c declaration, verbatim, because a round-9 row is only safe if it REPLACES something** (catalogue
Part 2: *replacing is safe, adding alongside is where two techniques fight*):

> nav owns the **desired-velocity layer** — `game/ai/movement.gd`, `game/ai/combat_motion.gd`, `game/ai/steering.gd`,
> `game/tank/tank_motion.gd`. It assumes **above** it that squad hands down goals and, since round 8, a `facing`. It
> assumes **below** it that the plant honours (throttle, turn) with a bounded yaw rate. **A7 replaces the additive
> blend; A11 replaces the 16-direction ring; A1 replaces the fixed repath / re-aim cadence; A4 replaces the straight
> approach inside the arrival arc. None of the four adds alongside.**

| Row | Replaces, by file and function | Restored by | Arm counter |
|---|---|---|---|
| **A7** null-space priority projection | the additive score in `CombatMotion.choose` (`WEIGHTS`, the `PENALTY_*` terms, `COMMIT_BONUS`) **and** the PID station override's precedence over avoidance in `Movement.drive` | `--nav-off=a7` | `a7_projected` |
| **A11** dynamic-window arcs | `CombatMotion.RING` and the `wheels` / `min_cos` chord test | `--nav-off=a11` | `dwa_candidates_reachable` |
| **A1** state-error tube | the `REPATH_SECONDS` / off-path / stalled cadence in `Movement._next_waypoint` (and, by request to squad, `TankBrain.MOTION_REPLAN_TICKS`) | `--nav-off=a1` | `a1_tube_skips` |
| **A4** clothoid primitives | the straight approach in `Movement._approach_gate` | `--nav-off=a4` | `a4_clothoids` |

**Two rules this layer holds itself to all round**, both bought with round-8 time:

1. **An arm counter, or it is not a comparison** (lesson 147). Round 8's facing A/B compared two arms in which the
   treatment never executed once, and the only thing that said so was a counter added for exactly that. Every row
   above ships its counter in its first commit, and `nav-fight` reports them all under `arms`.
2. **`--nav-off=<row>` restores the OLD mechanism, it does not disable the new one into nothing.** An arm that is
   "the new thing, switched off" is a third treatment, not a control.

**Determinism, for every row:** no wall clock inside a decision (`dt` is the tick), neighbours ordered by name, a
fixed iteration count, ties to the lower index. Fresnel integrals (A4) come from a fixed-size table with fixed-order
interpolation, never a series evaluated to a tolerance.

**Audited at the start of round 9, rather than assumed** (`movement.gd`, `combat_motion.gd`, `steering.gd`,
`tank_motion.gd`, `avoidance.gd`, `pid.gd`): the layer reads the wall clock in exactly **one** place,
`movement.gd:435`, and it is a profiling lap timer whose value reaches `OrderController._lap` and nothing else — no
decision consumes it. There is no RNG anywhere in the layer. So the round starts from a clean determinism position
and every new row has to keep it, rather than having to establish it first.

### The arrival gate's three-way counter (round 9, N0)

`gates_offered` / `gates_aimed` / `gates_refused`, with refusals split by reason (`off_mesh`, `on_approach`,
`reached`, `no_facing`, `bad_facing`). Round 8 could not tell *"never offered a facing"* from *"offered one and
refused the gate"*, and those are opposite findings: the first is an instrument failure, the second is a mechanism
finding. `nav-fight` reports the split, and the round's A/Bs all issue at least one order carrying a `facing` (a
squad hold, and a move with one) so the arrival path is a live arm **by construction** rather than by memory.

### A7's priority table (N1a, nav, 2026-09-19) — REVIEW WANTED from combat and feel before any A7 code

> **What this is.** Catalogue row **A7** replaces the additive score in `CombatMotion.choose` and the PID station
> override's precedence over avoidance in `Movement.drive`. *"Six multiply-adds"* understates it: `CombatMotion.WEIGHTS`
> is where round 7's approved behaviour lives — standoff and shoot-and-scoot, commitment, armour toward threats, the
> leash, the dodge, don't-walk-into-a-wall-of-bullets. **Every one of those either survives in this table as a named
> priority or quietly does not.** So the table is written, reviewed and argued before a line of A7 exists.
>
> **Reviewers:** combat (N5 engagement envelope, L2 suppression, A2's switching cost), feel (S4 legibility — the A6
> motion law must appear here as a named priority, not as a new additive term). Route: the orchestrator.

#### How the levels work, and the one honest caveat

The textbook statement (Antonelli, Arrichiello & Chiaverini 2008) synthesises a velocity as
`v = Σ_i (Π_{j<i} N_j) v_i`, each lower task projected into the null space `N_j = I − J_j⁺J_j` of the higher ones.
**Our velocity set is discrete** — a 16-direction ring today, A11's reachable (speed, yaw-rate) lattice after N2 — so
the projection is exercised as a **tolerance-banded lexicographic filter over candidates**, which is the same algebra
applied to a finite set:

    survivors := feasible candidates
    for each level i, highest priority first:
        if the level has no active task: continue          # it leaves the whole set free
        c_i := cost of each survivor at level i
        survivors := { c in survivors : c_i(c) <= min(c_i) + TOLERANCE[i] }
    choose argmin of the last level's cost; ties by lower index

`TOLERANCE[i]` **is** the null space of level *i*: 0 makes the level dictatorial, ∞ makes it a pure preference. Fixed
level count, fixed candidate count, no convergence loop, ties by lower index — deterministic by construction.

**The caveat, stated plainly so nobody is surprised at merge: A7 does not remove tuning, it restructures it.** Eight
weights that traded off incommensurable quantities (metres of range against radians of turn) become five tolerances,
each with units inside one level. That is a better-shaped problem, not a smaller one, and the honest claim for the
round is *"opposing goals can no longer cancel to zero"*, never *"nothing is tuned any more"*.

#### The levels

| # | Level | What it is | Null space it leaves |
|---|---|---|---|
| **0** | **FEASIBILITY** (a mask, not a level) | reachable by the plant this tick; inside the arena; not crossing or ending in an obstacle | everything else. If the mask is empty the boxed-in fallback runs, exactly as today |
| **1** | **SURVIVAL** | a round that would hit me; a route through a beaten zone | free whenever no candidate is safe — a unit boxed in by fire still goes somewhere |
| **2** | **WEAPON** | the standoff band (radial), the ram guard, keeping the target in sight | **the whole tangential component** — which is why circling survives untouched |
| **3** | **ARC / ARMOUR** | front toward threats; the angle style's side-on guard; **A6's motion law goes here, named** | the sign of the arc (either shoulder), and all speed |
| **4** | **FORMATION** | the leash on the element slot; crowding; `Movement`'s PID station | everything inside the slot's cell |
| **5** | **PREFERENCE** | tangent, side, flank, continuity, turn cost, reverse cost, commitment | — (argmin here decides) |

**Level 5 keeps the additive weighted sum, deliberately.** A7 forbids summing *across* priority levels, not within
one. Continuity, the turn cost and commitment go on working exactly as round 7 measured them; what changes is that
they can no longer outvote a dodge or a standoff band.

#### Every term in the code today, and what it becomes

| Term (`combat_motion.gd`) | Today | Becomes | The lead-approved behaviour it encodes |
|---|---|---|---|
| `WEIGHTS[*]["range"]` (1.0 / 1.0 / 1.2 / 0.0) + `_band()` | additive | **Level 2**, as a constraint on the **radial** component only | Round 7 standoff / shoot-and-scoot: closest approach 3.0 → 27.7 m, shots 29 → 211. The project's largest measured behaviour win — it is a priority, not a preference |
| `standoff_holds()` → `{"hold": true, "index": -1}` | an early return **before** the ring is scored | **Level 2's zero-radial solution, scored as a candidate like any other** | Round 7's "stop and shoot". **This is the round-8 cancellation failure being fixed**: a hold returns index −1 today and therefore never consults commitment, so we shipped and measured a term that was never in that code path |
| `MIN_GAP`, `PENALTY_RAM` (1.2) | penalty | **Level 2** (the band's inner wall) | "Scouts are just running directly into their targets" |
| `SIGHT_CHECKS` (6), `clear_line_coarse` | a post-hoc rescan of the best 6 | **Level 2's null-space preference** — it orders everything that ties on the band, not only the top 6 | "Circling out of view loses the fight" (the Lancer after CP2). Strictly better than today by construction |
| `PENALTY_HIT` (3.0), `would_be_hit` | penalty | **Level 1** | X3 the dodge. **Now strictly dominant**; today 3.0 is large but finite and can in principle be outvoted |
| `beaten` (L2) + `beaten_fallback` | last-resort filter | **Level 1**, with the same "free when nothing is safe" release | "Don't walk into a wall of bullets" — and the release keeps "a unit boxed in by fire has to go somewhere" |
| `WEIGHTS[*]["armor"]`, `threats`, `MULTI_THREAT_ARMOR`, `BUSY_ARMOR` | additive 0.15–1.0 | **Level 3** for hull-fixed and heavy hulls; **null-space task (level 5)** for turreted hulls, whose gun does not need the hull | X3 "keep your front toward threats", and the busy-target flank |
| `PENALTY_SIDE_ON` (1.5), `ANGLE_MASK_COS` | penalty, angle style only | **deleted as a constant**; it is level 3's expression for the `angle` style | Heavy hulls rocking along one angled heading instead of turning side-on |
| `PENALTY_LEASH` (1.5), `LEASH_FALLOFF` | penalty | **Level 4** | X1 "fight from your place in the formation" |
| `PENALTY_CROWD` (0.6), `FRIEND_SPACING` | penalty | **Level 4** | Mutual support without piling up |
| `WEIGHTS[*]["tangent"]` | additive | **Level 5**, inside level 2's null space | Round 3's circling — the lead's "no intent of trying to circle your opponent" |
| `WEIGHTS[*]["side"]`, `flank`, `BUSY_FLANK` | additive | **Level 5** | X3 the busy-target flank |
| `WEIGHTS[*]["continuity"]`, `["turn"]`, `turn_seconds()` | additive | **Level 5** | "A pivot is time standing still, the easiest shot there is" |
| `WEIGHTS[*]["reverse"]` | additive; **negative means never reverse** (`run`) | **Level 5**, priced — never a veto | P3: forbidding a switch more than doubled switch-and-switch-back. A reversal is priced, and A4 prices its cusp |
| `COMMIT_BONUS` (0.35) | additive | **Level 5, UNCHANGED by A7** | Round 7 commitment. **See the composition hazard below — this term is also combat's A2 this round** |
| `RING`, `wheels`/`min_cos` | the candidate set | **untouched by A7; A11 replaces them at N2** | — |
| `HOLD_SLACK_M` / `--nav-off=holdband` | opt-in hysteresis | **unchanged**, still opt-in | Its A/B missed its bar in round 8; it is not smuggled in under A7 |
| `fixed_style == "run"` | round 3's attack runs | **keeps the old additive blend, untouched** | It exists to be an A/B control (`--nav-off=standoff`). A control that is also rewritten is not a control |

| Term (`movement.gd`) | Today | Becomes |
|---|---|---|
| `_avoid` (ORCA) vs `_keep_station` (PID) | the station PID runs **last** and overwrites the avoiding velocity (`movement.gd:483`) | **the priority inversion A7 exists to fix**: avoidance is Level 1, station is Level 4, and the station's correction is clamped into the avoidance-feasible set instead of applied on top of it |
| `_around_fire` | pipeline stage | Level 1 |
| `_next_waypoint` / `_approach_gate` | pipeline stage | Level 2 (the goal task); A4 replaces the gate's straight approach at N4 |
| `_guard_steer`, the chord test | pipeline stage | Level 0 (feasibility) |

#### By style, since a style stops being a weight vector

| Style | Level order | Level 5 weights |
|---|---|---|
| `strafe` (turret) | 1 · 2 · 4 · 5, **armour demoted into 5** | tangent high — the turret aims independently of the hull |
| `angle` (heavy tracked) | 1 · 2 · **3** · 4 · 5, armour promoted above formation | wider radial tolerance at level 2, so it rocks along one angled heading |
| `standoff` (fixed gun) | 1 · 2 (with the hold as a candidate) · **3** · 4 · 5 | armour at level 3 because the hull *is* the gun mount |
| `run` (A/B control) | — | the round-3 additive blend, unchanged |

#### ⚠ Composition hazard, for the orchestrator: A7 and A2 both touch `COMMIT_BONUS` this round

This is catalogue Part 2 happening in real time, in two streams, on one constant. **A7 relocates the commitment term
into level 5 without changing its value; combat's A2 replaces the flat bonus with a state-dependent switching cost.**
Those compose only if A2 lands as *the level-5 commitment term's new expression*. If A2 lands as an additional
penalty somewhere else in the same scorer, we get the exact failure Part 2 predicts: two correct techniques, neither
working. **nav's proposal: A2's switching cost IS level 5's commitment term, and nav adopts combat's expression
verbatim rather than keeping a constant beside it.** Sequencing: A7 lands first and leaves the term in one named
place, so A2 has one line to replace.

#### What nav is asking each reviewer for

- **combat:** does the level order above preserve N5's engagement envelope and L2's suppression behaviour? Two
  specific predictions nav wants challenged: (1) making the dodge **strictly dominant** (level 1, not a −3.0 penalty)
  will break units off under fire more decisively than today; (2) demoting armour to level 5 for turreted hulls is
  right because the turret aims independently — but the scout's engine-deck behaviour (41/23) is exactly the kind of
  thing that dies quietly to a change like that, so **run your two scenarios on nav's A7 commit rather than a copy**.
- **feel:** A6's motion law (S4) is written into **level 3** above. Is a heading constraint at level 3 — above
  formation, below the weapon band — where the legibility contract wants it? If the law should outrank the standoff
  band, say so now: that is a one-line change here and a re-argument after the code exists.

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
