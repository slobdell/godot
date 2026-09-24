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

_Worker: nav, round 11. Updated 2026-09-24 02:30. Every number names its commit and machine. **Merge point: see
"Green hash" at the end.**_

### Report in one screen

- **R2 (goal inside a building): fixed.** Every goal the player's right-click, the squad path (CPU commander, tactical
  map) and the follow station hand a crew is grounded with THAT hull's turning envelope; no two crews of one order or
  squad share a spot; pinches (a wreck beside a block face) search for a spot the hull fits. Test first
  (`tests/nav/test_nav_grounded_goals.gd`, failed on `a04d75c0`). R2 alone does not move the sim baseline.
- **R1 (drives into the wall before backing up): fixed for the case he described**, inside the driver: a wheeled hull
  whose forward arc would meet a wall within 5 m backs up FIRST, on a reverse leg checked against what is behind and
  beside it. Scenario test (IFV nose-on to a Terminus block): control touches the wall before any reverse; with the leg,
  reverse first, zero contacts, arrives. **Clip for him:** `assets/review/nav_r11/wall_side_by_side.mp4`.
- **Found on the way and fixed:** the path follower could steer at a route corner it was standing on and sit at zero
  throttle forever (arena's Crossing deadlock; then an IFV in `nav-orders`). And the goal repair made a unit read
  "arrived" under an order that never completes, so the repair is OPT-IN until completion honours it (request below).
- **Sim baseline moved, attributed, adopted:** `457b5e83 -> 814aed46` (the waypoint guard, then the planned reverse).

### Plan (the brief's order; R2 first because R1 cannot be measured under it)

| # | item | state |
|---|---|---|
| R2.1 | failing test on the issued goal | **done** — `tests/nav/test_nav_grounded_goals.gd`, failed on `a04d75c0` (laptop) |
| R2.2 | squad.gd:272 hull-aware; which sources; de-collide | **done** `5ad73612`; sources settled in `b96b122c` (below) |
| R2.3 | repair an unreachable goal once, else report | **built, OPT-IN** (`38c385d5`): see Requests |
| R2.4 | before/after on `nav-orders` and `nav-terminus-drive` | **done**, table below |
| R1.5 | instrument the reactive reverses before the fix | **done** `4f898560` (+ pre-registration `c043feac`) |
| R1.6 | the circle test at plan time + a mesh-checked reverse leg | **done** `77212e8c` -> `3040b660` -> `27bea0e2` (three measured corrections) |
| R1.7 | inside the driver, not the planner | **held**: Pathing untouched; not needed for his bar (numbers below). The War Rig's `kturn_none` is the one sign a longer search or a kinematic planner would help — see Next steps |
| R1.8 | the plant's creep at a wall | **measured, threshold NOT changed** (below) |
| R1.9 | before/after clip from his camera | **done** `617c6c09`, looked at |

### Measurements (builder0 unless stated)

**Workload:** `make nav-terminus-drive DRIVE_SEEDS="1 2 3 4 5 6 7 8"` — the mixed Condemned squad and the War Rig squad,
4 legs each, 8 seeds each (seed 1 canonical; seeds 2-8: 2 m spawn jitter + a random starting heading), 16 runs per arm.
Arms: **base** = `a04d75c0` with the same harness; **off** = `38c385d5` with `--nav-off=kturn` (R2 + the waypoint guard,
= R1's control); **on** = `38c385d5` default. Map list: `Arena.ROTATION` of `a04d75c0` (arena's crossing/sumps not merged here).

| squad | arm | arrived | leg time s | wall-contact ticks | press/unstick-driven contacts | reverse-gear contacts | cusps | creep reversals (at a wall) | kturns / none / aborted |
|---|---|---|---|---|---|---|---|---|---|
| mixed | base | 165/192 | 1796 | 2165 | 56 | — | 2281 | — | — |
| mixed | off | 170/192 | 1623 | 2806 | 88 | 671 | 2260 | 2602 (82) | — |
| mixed | **on** | **177/192** | 1441 | **996** | **1** | **206** | **1978** | 2157 (**33**) | 75 / 29 / 0 |
| rigs | base | 98/128 | 1420 | 15773 | 541 | — | 1866 | — | — |
| rigs | off | 99/128 | 1613 | 9678 | 393 | 2240 | 1585 | 2414 (248) | — |
| rigs | **on** | **104/128** | 1277 | **6917** | **227** | **946** | **1202** | 1735 (**113**) | 64 / 130 / 2 |

**R1's pre-registration, scored** (on vs off): (1) press/unstick-driven contacts DOWN — yes, 88 -> 1 and 393 -> 227;
(2) total contacts DOWN — yes, -64 % and -29 %; (3) reverse-gear contacts NOT UP — yes, down 69 % and 58 %; (4) cusps
down or flat — yes, -12 % and -24 %; (5) arrivals not down — yes, +7 and +5; **`kturn_none` small beside `kturns` —
NO for the War Rigs (130 vs 64)**: for a 14 m hull with a 12 m radius in 18-22 m streets the 8 m reverse search often
finds no single back-up that clears the forward arc. Unexpected: Steering's own in-circle back-ups for the mixed squad
went 647 -> 770 (the leg leaves some hulls with the point inside the circle); cusps still fell.

**R2 (base vs off):** mixed arrivals 165 -> 170, leg time 1796 -> 1623 s, but wall contacts 2165 -> 2806 (+30 %);
rigs arrivals 98 -> 99, contacts 15773 -> 9678, press/unstick contacts 541 -> 393. The off arm also carries the waypoint
guard, so this is R2 + guard, not R2 alone. `nav-orders` (yard, 5 squads, one run each): base 30/30, t50 29.9 / t90 39.5
/ t100 43.8 s; final (`38c385d5`) 30/30, t50 29.5 / t90 46.9 / t100 47.7 s — **the tail is slower by ~4 s on this run**;
laptop runs of the same pair gave 29/30 (base) and 30/30 (mine, t100 40.3 s), so one yard run is within its own noise.

**R1.8, the creep:** creep leg reversals AT A WALL fell 82 -> 33 (mixed) and 248 -> 113 (rigs) with the planned leg. I
did **not** raise `WHEEL_CREEP_THROTTLE`: the creep is also what turns a wheeled hull on a `face` order, and the
reversals away from walls barely moved (2602 -> 2157, 2414 -> 1735 total) — it is doing its other job. A threshold change
would need its own A/B on `nav-rotation` and the facing scenarios; recorded as a next step, not done at 3 a.m.

**The clip** (`make nav-wall-clip`, laptop render, `617c6c09`): off — first wall contact 0.73 s, 22 contact ticks, never
reverses (scrapes the face through its turn); on — reverses at the first tick, 0 contact ticks, one leg, same end point.

### Decisions (one line each)

- **Which sources are grounded (revised `b96b122c`):** `player` (Orders) and the squad path (`Squad.context_for`, which
  the CPU commander and the tactical map use); `element` grounds its own plan (`Element.ground`). **Sourceless Orders
  moves stay raw geometry on purpose:** every `issue()` caller was surveyed and none in production sends one (tests,
  scripts, the FX bench); grounding them reddened `scenario_orders`' 100 ms response test on `77212e8c` exactly as
  round 10 found, because that test compares the executed goal with the raw click.
- **The test's oracle is the layout's colliders** (`Arena.active["obstacles"]` + `ArenaKit.distance_to_footprint`), not
  the navmesh the fix grounds on, so it cannot agree with a wrong answer. Bar: every goal clears its hull's envelope
  (half diagonal) − 1.5 m; no two goals of one order closer than side by side (half widths summed).
- **The pinch case:** the first fixed run still left an IFV 2.4 m from a rotated wreck (envelope 4.0 m) — a 5 m gap
  between a wreck and a block face where the 8 clearance pushes cancel. `standable_for` now checks whether the hull
  FITS where the pushes settled and, if not, searches two rings (of the envelope) for the nearest point where it does;
  a street narrower than the envelope everywhere still gets the centred point (the only answer before).
- **Repair: OPT-IN (`38c385d5`).** On by default it made a scout read "arrived" 3.5 m from an order goal that then never
  completed (`nav-orders`, builder0 `e62383ad`, reproduced on the laptop). Bound when on: (a goal moving > `NEW_GOAL_JUMP` is a new goal); refused beyond 12 m
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
| `ca7c0df2` | exited 2, 1690 / 1 | the 100 ms test again (revert not yet in); sim-baseline MOVED -> `16bfe280760629ef`; ai-scenarios counts changed: the 100 ms test and `scenario_perf` (22.0 ms/tick, load) |
| `38c385d5` | exited 2, **1691 / 0**, ai-scenarios back to its baseline | the only red: sim-baseline MOVED -> `814aed46b1042e62` — attributed and adopted in `6602e1f9` |

- **`scenario_perf` is load, not nav:** laptop, alternating base (`a04d75c0`) and mine (`ca7c0df2`+): 22,013 / 21,937 µs
  per tick mine vs 22,221 / 22,111 base, identical fights (same LOS query counts). builder0 ran check2 at load 12.5 with
  22 other Godot processes.
- **`scenario_cover` peek (x3 4 hits vs x4 4 hits) is NOT a change:** it is the one expected failure already in
  `tests/baselines/ai_scenarios_count.txt` (43,1: "the reload-window arm shows no effect, 4 vs 4 ... squad re-measures in
  round 11"). It fails at `a04d75c0` on both machines.

### Requests to other streams / the orchestrator

- **tank_brain.gd (no owner this round; orchestrator):** order completion (`_update_order_progress`, the move /
  attack_move branch) should also complete when `Movement.state(tank)["repaired_m"] > 0` and its phase is `"arrived"`.
  Then `Movement.repair_on()` can default to ON (flip the switch semantics and the note above it). The orchestrator's
  session refused a direct message (2026-09-24 02:00), so this is its only copy.

### Questions for the lead

- None blocking. For his eye: `assets/review/nav_r11/wall_side_by_side.mp4` (left: today's reactive driver; right: the
  planned reverse), and a Terminus playtest (below).

### What to playtest (exact commands)

- `make skirmish` on the Terminus: select a mixed squad parked facing a block, right-click behind it — wheeled hulls
  should back up first, not nose into the face. Then right-click a point hard against a block: every crew should get a
  spot it fits (the card shows how far a goal moved).
- `make nav-wall-clip` (display) re-renders the clip; `make nav-terminus-drive DRIVE_SEEDS="1 2 3 4 5 6 7 8"` and
  `NAV_FLAGS=--nav-off=kturn` for the control; `make nav-orders`.

### Next steps (not done, in order)

1. When completion honours `repaired_m`, turn the repair on by default and re-run `nav-orders` + the drive test.
2. The War Rig's `kturn_none` (130 of 194 searches found no single clearing back-up): try a two-leg plan (reverse,
   forward, reverse) within the driver before reaching for a kinematic planner; if the rigs' arrivals do not move, that
   is the measurement that opens the planner question (brief R1.7).
3. The mixed squad's in-circle back-ups rose 647 -> 770: check whether the leg's end pose should aim the hull a little
   past the point so pure pursuit takes it forward.
4. `WHEEL_CREEP_THROTTLE`: an A/B on `nav-rotation` + the facing scenarios before any change (R1.8).
5. After arena merges: `make terrain-drive` (crossing, sumps, locks) as the deadlock regression.

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

### Green hash

**`c666f6ca` is green, merge here** (builder0, 2026-09-24 ~02:50): `>> remote: make check exited 0`, `check passed:
18 targets`, **1691 passed, 0 failed**, sim-baseline `814aed46b1042e62` (the adopted hash, `6602e1f9`), determinism
`bcc6e1609c14e12d`. Commits after it are documentation only (`_agents/`). The merge moves the sim baseline
`457b5e83 -> 814aed46` for the two named causes above; it merges on its own or with the orchestrator recording it.
