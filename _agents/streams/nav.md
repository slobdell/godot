# Stream: nav (reverse BEFORE the wall, and a goal that is not inside a building)

> Read [`game_design.md`](../game_design.md) *Round 11 direction* first, then [`navigation.md`](../navigation.md),
> [`algorithms.md`](../algorithms.md) and [`workstreams.md`](../workstreams.md). **You own** `game/ai/movement.gd`,
> `pathing.gd`, `steering.gd`, `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`, `game/tank/tank_motion.gd`,
> `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`, `_agents/algorithms.md`; **plus, for R2 only**, the goal-grounding
> path: `game/tactics/slot_ground.gd`, `Orders.ground_goal` in `game/control/orders.gd`, and the one call site
> `game/ai/squad.gd:272`. No control or squad stream runs this round; the orchestrator reviews those three at merge.

## The lead's direction (2026-09-23, night)

> *"In Terminus, if I tell a squad to go somewhere, a lot of vehicles still look dumb because they'll drive into a wall
> before trying to back up (i.e. it looks like our algorithm is trying to do a multi-point turn based on hitting an
> obstacle) - it would be more ideal if the units detected that their path would bump into a wall, and therefore they
> need to go in reverse first; a real-world driver would execute a 3 point turn as necessary. Also in terminus when I
> tell a squad to go to a point, it appears as though a unit's target position ends up inside of a building or
> something, because some of them still just look dumb getting stuck behind a wall. I suspect (and I could be wrong)
> that what I described is a 2 part problem."*

**He is right that it is two problems.** They have one owner (you) and different mechanisms, and neither is fixed by
the other. Do not let R1's work be judged on a goal that was never reachable, or R2's on a driver that cannot get
there — measure them apart, which is round 9's lesson and the reason this brief separates them.

## Where things stand (surveyed before this brief; verify each claim, do not trust it)

### R1: every reverse in the game today is reactive. There is no planned one.

Five things can put a hull in reverse, and **all five wait for something to go wrong** — which is precisely the
"multi-point turn based on hitting an obstacle" he described:

| where | trigger | what it does |
|---|---|---|
| `order["reverse"]` (`order_controller.gd:331`, `squad.gd:278`, `combat_motion.gd:98`) | tactical | keeps front armour to the threat; nothing to do with obstacles |
| `Steering._wheels` (`steering.gd:98-105`) | the **current steering point** is inside the current turning circle | full-lock reverse toward the point's side. **The only geometric trigger — and it knows nothing about walls**: no navmesh query, no check of what is behind |
| `Movement.unstick` (`movement.gd:2132-2170`) | 1.0 s at >0.5 throttle under 0.8 m/s | blind full-lock back-off |
| `Movement._pressing_escape` (`movement.gd:2221-2262`, default ON since round 10) | 1.0 s of **wall contact** with <0.75 m net motion | backs off 1.5 m. Its own header calls it a post-hoc recovery for hulls already pinned 30-130 s |
| yield-to-a-friend (`movement.gd:1145`) | no legal sidestep | straight back 6-10 m |

**The planner cannot see the problem at all.** `Pathing.find_path` (`pathing.gd:14`) is a holonomic navmesh A* at a
single 2.0 m bake radius; `_agents/algorithms.md:57` states it plainly: *"`min_turn_radius_m` exists in the data (K3)
and the planner ignores it."* `Movement._next_waypoint` (`movement.gd:1777-1936`) pushes the carrot further along to
*avoid* reaching the three-point-turn state, and when it cannot, `movement.gd:1920` says so in a comment: *"no
reachable-and-drivable point further on: take the carrot and the three-point turn."* The discovery happens one tick
at a time, at the bumper.

**The pieces to compose already exist**, which is why this is a light round and not a research project:
- `Steering._wheels`' circle test already answers *"can I reach this point going forward from this pose"*.
- `CombatMotion.dynamic_window` (`combat_motion.gd:948-985`) already forward-simulates the **real plant** over 0.25 s
  control periods and would price a K-turn as a scored candidate — but it is opt-in, lives only in `direct` hops, and
  contains **zero navmesh queries**, so it cannot see a wall.
- `Clothoid` (`game/ai/clothoid.gd`) is built and used only for the arrival-facing gate (`movement.gd:1721`).
- Reeds-Shepp is parked on purpose (`algorithms.md:57`, `research_catalog.md:137-148`). **You do not need it** for
  what he asked for; if you conclude you do, say so with the measurement that shows it.

**The plant is why this reads so badly on wheels** (`tank_motion.gd:109-168`): wheeled hulls *cannot turn standing
still* (`yaw_rate = |speed| * turn / radius`), and below `WHEEL_CREEP_THROTTLE * |turn|` the plant substitutes a
**creep that alternates forward/reverse every half second** (`:91-93`, `:118-131`). That shuffle at a wall is the
thing on his screen. Most of the roster is `wheels` (radii 4.5-12 m); the Condemned tank is `tracks` (pivots in
place); the Syndicate is `hover`.

### R2: the goal IS grounded — for player right-clicks, once, and then never again

`Orders._resolve_group` (`game/control/orders.gd:291-365`) computes a formation slot, clamps it to the arena, and
then:

```gdscript
var ground := Orders.ground_goal(tanks[i], goal) if String(base.get("source", "")) == "player" else goal   # :358
```

`Orders.ground_goal` → `SlotGround.for_unit` → `standable_for` (`game/tactics/slot_ground.gd:45-67`) is
`NavigationServer3D.map_get_closest_point` plus an 8-direction clearance push at the hull's turning envelope. It
works. The leaks, each of which produces exactly his symptom:

1. **`source != "player"` is not grounded at all** (`orders.gd:358`), by a deliberate comment. Anything issuing a
   `move` without `source` gets raw formation geometry, which can be inside a block.
2. **Grounded once, never re-checked** (`orders.gd:363`). A queued leg or a re-resolve moves the anchor; nothing
   re-validates. `Movement.drive` never calls `map_get_closest_point` on its goal.
3. **`game/ai/squad.gd:272` uses the weaker `SlotGround.standable`** (mesh centre, 1.0 m tolerance) instead of
   `for_unit`/`standable_for` with the hull envelope. The navmesh edge is only `bake_radius` = 2.0 m from a wall, so
   a War Rig (3.32 × 14 m, envelope ~7.2 m) centred there **has its nose in the building**. This one line is the
   single most likely cause of what he saw, and `tank_brain.gd:718` already does it correctly for follow-stations.
4. **Slots are grounded independently with no de-collision**: two slots pushed out of the same block can land on the
   same point.
5. **In a street narrower than the envelope the pushes cancel** by design (`slot_ground.gd:36`), so a wing slot
   silently collapses toward the centreline — fine for a centre slot, wrong for a wing.

**And the game already KNOWS when a goal is unreachable and does nothing about it.** `Movement._next_waypoint:1852`
computes `_reachable` from `Pathing.query`'s `goal_gap_m`; `_update_phase:1030` sets `phase = "blocked"`,
`blocked_by = "no_path"`. Nothing repairs, re-grounds or reissues. Round 6 deliberately removed the "close enough
after a stall" fudge (`tank_brain.gd:164-168`) so a unit that cannot arrive says so and keeps trying — **the honest
reporting made this more visible, not less**, and that was the right call. The repair is the missing half.

## Backlog (in order)

### R2 first — it is smaller, it is more certainly a bug, and R1 cannot be measured under it

1. **A failing test first** (`tests/nav/` or `tests/test_control_grounded_goals.gd`'s sibling): on the Terminus, a
   squad of mixed hulls including a War Rig ordered to a point beside a city block — **assert every issued goal is on
   the navmesh with that hull's own clearance**, not the mesh centre. It must fail today. Derive the hull sizes from
   the catalogue (lesson 3), and put the assertion on the *issued order*, not on where the unit ends up.
2. Fix `squad.gd:272` to use the hull-aware call; make `Orders.ground_goal` reachable for the non-player sources that
   should have it (decide which, and record why any source keeps raw geometry); and de-collide slots after grounding
   so two units never receive the same point.
3. **Repair, don't just report:** when `Movement` finds `_reachable == false` within `UNREACHABLE_AT_END` of the
   route's end, re-ground the goal once with the hull's envelope and continue; if it is still unreachable, keep
   today's honest `blocked`/`no_path`. Bound it (one repair per order, or a cooldown) so a genuinely impossible order
   does not spin. **A unit that quietly drives somewhere else is worse than one that says it is stuck** — the repair
   must land the hull where he pointed, or report.
4. Measure it on the bar that exists: `make nav-orders` (`completed_far`, `never_completed`, t50/t90/t100) and
   `make nav-terminus-drive` before and after, same commit, same machine, same seeds, sample size stated.

### R1 — the three-point turn a driver would do, decided before the bumper

5. **Name the observable first, and instrument it before you change anything.** `WallContact`
   (`game/ai/wall_contact.gd:19-24`) already classifies every contact tick by cause (`bake`/`route`/`avoid`/`steer`/
   `plant`) and by driver (`route`/`direct`/`yield`/`unstick`/`face`/`drive`). The number he is complaining about is
   **contact ticks whose driver is `unstick`/`press`, i.e. reverses that happened only because something already went
   wrong** — publish that number on today's tree, on the Terminus, with its sample size, before writing a line of the
   fix. That is the before-arm and it is the only way anyone can tell whether R1 worked.
   Second observable, from `make metrics`: **cusp density** (`_agents/metrics.md:68`; a K-turn is 2 cusps). A good fix
   does not remove cusps — it **moves them earlier and makes them fewer per manoeuvre**. Pre-register which direction
   you expect each number to move (lesson 210) and accept being wrong.
6. **The fix, in one sentence: run the circle test against the route's first leg at PLAN time, and emit an explicit
   reverse leg when it fails.** The place is `_next_waypoint` around `movement.gd:1852-1870`, where the route is
   already in hand. When the carrot is not forward-drivable from this pose, choose a reverse segment **validated
   against the navmesh behind the hull** — which no existing reverse does (`unstick:2147`, `_pressing_escape:2253`
   and `steering.gd:105` all back up blind, and backing blind into a second wall is the failure this is supposed to
   stop). Then drive it as a deliberate leg with its own completion, not as a recovery.
7. **Keep it inside the driver, not the planner, unless you prove otherwise.** Making `Pathing` kinematic (turn-radius
   aware, reverse-admitting) is a much larger change and is parked by an earlier decision. If your measurement says
   the leg-level fix cannot reach his bar without it, write that up with the number and stop there — that is a design
   decision for the next round, not a thing to start at 3 a.m.
8. **The plant's creep is part of what he sees.** Once R1's leg exists, check whether the half-second forward/reverse
   alternation (`tank_motion.gd:118-131`) still fires as often at a wall, and whether a deliberate reverse leg lets
   you raise `WHEEL_CREEP_THROTTLE`'s threshold. Measure; do not tune by eye.
9. **Watch it like a player.** `make nav-rotation ROT_CASES=car` renders how hulls rotate from his camera, and
   `make nav-terminus-drive` is the bar. Record a before and after clip of one car-like hull ordered up a Terminus
   side street from a bad heading, and look at them both. He will judge this one with his eyes, not with cusp density.

## How to verify

- `make remote T=check` on builder0 — read the wrapper's own `>> remote: make check exited <N>` line and the runner's
  `N passed, M failed`, **never through a pipe**.
- Bars: `make nav-terminus-drive` (arrivals per leg + wall contacts by cause), `make nav-orders`, `make nav-fight`
  (`blocked_no_path`, `oscillating_share`, gear flips), `make metrics` (cusp density, oscillation, SPARC),
  `make squad-settle ARENA=terminus`, `make repath-test`.
- **Every number carries its commit, its machine (the laptop is ~2.75× slower than builder0), its workload and its
  sample size.** Paired seeds where you can; a control that cancels the cause you suspect beats more repetitions.

## Don't touch

`arenas/`, `game/arena/**` (arena's — and note arena is publishing `crossing` and `sumps` into `Arena.ROTATION` early
this round: `git merge main` when the orchestrator announces it, and say which map list your numbers were taken on),
`game/units/units.gd` and vehicle meshes (fleet's — hull sizes may move under you; state the commit for every number),
`game/camera/**` and `game/theme/arena_kit/airship/**` (airship's).

## Waiting on the lead

Nothing blocks you. Put the before/after clips from R1.9 where the orchestrator can send them to him.

## Status

_Worker: nav, round 11. Updated 2026-09-24 (small hours). Every number names its commit and machine._

### Plan (the brief's order; R2 first because R1 cannot be measured under it)

| # | item | state |
|---|---|---|
| R2.1 | failing test on the issued goal | **done** — `tests/nav/test_nav_grounded_goals.gd`, failed on `a04d75c0` (laptop) |
| R2.2 | squad.gd:272 hull-aware; ground non-player sources; de-collide | **done** in `5ad73612` |
| R2.3 | repair an unreachable goal once, else report | **done** in `5ad73612` (`Movement._repair`, `--nav-off=repair`) |
| R2.4 | before/after on `nav-orders` and `nav-terminus-drive` | running (builder0) |
| R1.5 | instrument the reactive reverses before the fix | built (counters below); before-arm = the same tree with `--nav-off=kturn` (paired) plus `a04d75c0` |
| R1.6 | circle test at plan time + a reverse leg validated against the mesh | built (`Movement._planned_reverse`); scenario test passes (laptop) |
| R1.7 | inside the driver, not the planner | holding to it; Pathing untouched |
| R1.8 | the plant's creep at a wall | after R1.6's numbers |
| R1.9 | before/after clip from his camera | after R1.6's numbers |

### Decisions (one line each)

- **Which sources are grounded:** every `Orders` source except `element`. An element's plan is already grounded with the
  hull's envelope (`Element.ground`) and issues one crew per order, so grounding twice buys nothing. Scripts, the agent
  bridge and sourceless moves were raw geometry only to keep two round-10 test numbers; a goal inside a block is wrong
  whoever asked for it.
- **The test's oracle is the layout's colliders** (`Arena.active["obstacles"]` + `ArenaKit.distance_to_footprint`), not
  the navmesh the fix grounds on, so it cannot agree with a wrong answer. Bar: every goal clears its hull's envelope
  (half diagonal) − 1.5 m; no two goals of one order closer than side by side (half widths summed).
- **The pinch case:** the first fixed run still left an IFV 2.4 m from a rotated wreck (envelope 4.0 m) — a 5 m gap
  between a wreck and a block face where the 8 clearance pushes cancel. `standable_for` now checks whether the hull
  FITS where the pushes settled and, if not, searches two rings (of the envelope) for the nearest point where it does;
  a street narrower than the envelope everywhere still gets the centred point (the only answer before).
- **Repair bound:** one try per goal (a goal moving > `NEW_GOAL_JUMP` is a new goal); refused beyond 12 m
  (`REPAIR_MAX_M`) or when no route reaches the repaired point, and then `blocked`/`no_path` exactly as before. The
  readout carries `repaired_m`. The lesson-76 test now aims at a Terminus block CENTRE (20 m deep), since a small
  prop's inside is now correctly repaired.
- **R1 lives in the driver.** A wheeled hull on a routed forward move with its steering point > 45° off the nose sweeps
  the full-lock forward arc (the plant's own yaw law) against the navmesh with its leading end; if it would hit, it
  searches back along the reverse arc (same lock, so the hull keeps swinging toward the point) with its TRAILING end —
  the first reverse in the game validated against what is behind — for the shortest back-up after which the forward
  arc is clear, and drives it as a leg with its own completion (distance, rear contact, or timeout). None found:
  counted (`kturn_none`) and the reactive rules stand.

### R1 pre-registration (written 2026-09-24 before any drive-test result for either arm)

Workload: `make nav-terminus-drive DRIVE_SEEDS="1 2 3"` (mixed + rigs squads, 4 legs each, seed 1 canonical, seeds
2-3 with 2 m jitter and random starting headings), builder0, arms `--nav-off=kturn` (control) vs default (planned
reverse) on the SAME commit. Expected, per arm total over 6 runs:
1. **contact ticks whose driver is `press`/`unstick` DOWN** (the number he is complaining about);
2. **total wall-contact ticks DOWN**, and `steer`-caused contacts down most;
3. **reverse-gear contact ticks NOT UP** (the leg is validated against what is behind; if this rises, the validation is
   wrong);
4. **cusps DOWN or flat** — reverses happen earlier and once, instead of bump-back-bump; if cusps rise sharply with
   contacts flat, the planner is reversing for nothing;
5. **arrivals not down**; `kturn_none` small beside `kturns` (else the search is too short).
Accepting being wrong on any of them; each is reported as measured.

### Checks so far (builder0, read from the wrapper's own line)

| commit | verdict | notes |
|---|---|---|
| `a04d75c0` (start) | `make check exited 0`, 1686 passed / 0 failed | sim-baseline `457b5e830708b439` unmoved |
| `77212e8c` | exited 2, 1689 / 2 | wheeled-arrival car test (the FIRST planner build; passes after `3040b660`), the 100 ms order test (sourceless grounding; reverted in `b96b122c`); sim-baseline MOVED -> `0146969cfee27c76` |
| `ca7c0df2` | exited 2, 1690 / 1 | the 100 ms test again (revert not yet in); sim-baseline MOVED -> `16bfe280760629ef`; ai-scenarios counts changed: the 100 ms test, `scenario_cover` peek (see below), `scenario_perf` (22.0 ms/tick) |

- **`scenario_perf` is load, not nav:** laptop, alternating base (`a04d75c0`) and mine (`ca7c0df2`+): 22,013 / 21,937 µs
  per tick mine vs 22,221 / 22,111 base, identical fights (same LOS query counts). builder0 ran check2 at load 12.5 with
  22 other Godot processes.
- **`scenario_cover` peek (x3 4 hits vs x4 4 hits):** fails identically on the LAPTOP at `a04d75c0` too; passed on
  builder0 at `a04d75c0`. Being attributed on builder0 by commit (base vs `5ad73612`).

### Known issues / notes for merge

- **arena's Crossing deadlock (fixed, `e62383ad`):** the follower steered at a route corner it was standing on (chord
  fallback + a segment-search tie), 0 throttle, no stall. Verified on arena's repro (their `09dd33c7` + the patch,
  laptop). After arena's branch merges, `make terrain-drive` (crossing, sumps, locks; mixed and rigs) is the
  regression check for it (arena, 2026-09-24). arena's Locks report did not reproduce on the final layout.

- `game/ai/squad.gd` (the one call site) and `game/control/orders.gd` (the `ground_goal` call site and `_resolve_group`'s
  grounding loop) are carve-out edits for the orchestrator to review. The obsolete `_slot_ground`/`_has_for_unit`
  compatibility shim in `Orders.ground_goal` was removed (for_unit landed in round 10).
- Order COMPLETION is judged against the order's own goal (`tank_brain.gd`, `order_executor.gd`, not mine), so a
  Movement repair of an ORDER goal would not complete the order. After R2 every order goal is already hull-grounded,
  so the repair in practice reaches brain-made goals (cover and fire spots) and island cases; its counters say how often.
