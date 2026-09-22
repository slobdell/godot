# Stream: squad (a transient element from any selection, and a player's order that pre-empts everything)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*, *Controlling units*), [workstreams.md](../workstreams.md) (*Round 10: the eight streams*,
> contracts **R1**, **R2**, checkpoint **CP1**; *What reads `hull_size`*), [squad_ai_design.md](../squad_ai_design.md),
> and your round-9 brief in [archive/round9/squad.md](archive/round9/squad.md) — its "ROUND 10 STARTS HERE" list is
> folded into the backlog below.
>
> **You own** `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,cpu_commander,tank_brain,directives,
> utility_curves,brain_variants,element_feed,matchups,difficulty,tactical_query,cover_map,fire_lanes,perception,
> suppression_feed,incoming_fire,ai_tick_cache,ai_explain_overlay}.gd`, `doctrines/`, `game/agent/`,
> `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`, `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,
> unit_ai,doctrine}.md`. **Invariant 0c governs the brief:** every item names what it REPLACES, by file and function.

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> When I select a set of units that doesn't necessarily belong to a squad, the buttons to do support by fire or
> whatever the case is is disabled - any way we can make that usable for new, random selections?

> I'm also trying to move units, and they weren't responding (I can see improvement for sure in formation generation
> and stuff). But I had a selection and the yellow X's on the map were in the center, that's where they were driving
> to, and I was trying to right click to move them in a different direction and they didnt respond

> I want to gauge how smart units are by trying to navigate them through the city.

The orchestrator's reading: he noticed the formations (that is your round 9 landing). What blocks him now is that the
element layer only exists for numbered squads, and that a task in flight can outlive his next order. **Your first live item
is the task half of the round's first blocker (R2)**; control owns the input side.

## Where things stand

- **Elements exist only for numbered groups.** `RtsControls.assign_task` (`game/control/rts_controls.gd:519-528`,
  control's) forms an element from a numbered control group; an unnumbered box-drag selection has no path to one, so
  the task buttons grey out (`selected_element()` demands exactly one element and all its members). R1 asks you for
  ONE call: form an element from any list of friendly units with a task, base and manoeuvre split by role and position,
  its split published in `Element.state()`, dissolved when any member gets a non-element order. Nothing about the
  element machinery itself needs to change; what changes is who is allowed to create one.
- **A task in flight can swallow a fresh move.** `Element.assign()` (`game/tactics/element.gd:145-163`) resets leg,
  route and drill; crews' orders are re-derived by the leader, and the re-issue suppression at `element.gd:562-583`
  (`_same_place(..., REISSUE_M)`, the `"hold"` handling) can keep crews on the old geometry after a new task. R2:
  after a fresh player task every crew's order changes within 2 ticks. control reproduces on the default path and
  sends you the per-crew log; do not wait for it to start, the mechanism is readable in your file.
- **Hold-on-arrival** (`d29115ae`, round 9): a dragged heading reaches every crew as a standing `hold`. A hold is a
  standing order and must yield to the next player order instantly (R2); check that it does.
- **40 s from a right-drag to a settled squad on a 20 m move** (round 9, orchestrator's item found on the way): 22.3 s
  for the element to declare arrival, ~20 s more for the crews to stop; A9's co-arrival pacing waits on the slowest
  member (`game/tactics/form_up.gd:55-64`). He will feel that before he sees any heading.
- **Your round-9 list**, folded in below: slot pitch from the turning envelope (item 1, DECIDED for you: hulls do not
  clip while dressing; the pitch gives a hull room to rotate, `half_diagonal − half_width` beside it, tank +1.27 m,
  War Rig +3.53 m; the roominess is the price and he sees it on the field); `_is_clear` ignores each placed vehicle's
  forward (item 3); Delta's margin at 62 % of budget (item 4); the base-of-fire scenario
  (`scenario_elements::test_the_base_of_fire_keeps_firing_while_the_others_move`) was passing on a neighbour's leaked
  navigation state and fails in 1.4 s once drained (metrics' four-run table in
  [archive/round9/metrics.md](archive/round9/metrics.md) "The one finding to carry into round 10"): a behaviour
  finding, yours. `test_tactics_deform`'s `super.teardown()` (item 5) is done under nav's seal.
- **Stood-down rows** (A10's `fixed` guarantee at `c0f22597`, A8 off the switch or off the branch, the tube's
  five-seed gate, A9's cost against the 4 s drill allowance) are stretch; the round's bar is his playtest, not a row.

## Backlog (in order)

1. **WITHDRAWN (the lead, 2026-09-20 night): no transient-element API.** He found that regrouping a mixed
   selection (Ctrl+1–5) already makes it a squad with formation and element orders, calls that good behaviour, and
   wants only the UX to say so; control owns that. Nothing to build here; keep `Element.state()` publishing the
   base/manoeuvre split for control's readout, and take the fitness split (research row B8) only if a numbered group's
   element formation lacks one today.
2. **R2 on your side.** A fresh task on an element re-derives every crew's order on the next tick; the re-issue
   suppression yields to a task with a new id; a standing hold yields to any player order. The integration test is
   control's (item 1 of its brief) and it runs on the default path; your unit test asserts the ORDER on each crew two
   ticks after `assign()`. Mutation-check both.
3. **The settle time.** Measure the 20 m move end to end (order → arrival declared → crews stopped) on the default
   arena and Terminus, then cut it: arrival declared when the leader's slot is reached, not the slowest member's;
   co-arrival pacing bounded (A9 keeps its shape; a bound is a number with a reason). Bar: a 20 m move settles in
   under 10 s on flat ground; print the three times on every run.
4. **Slot pitch from the turning envelope** (your round-9 item 1, decided). `TacticsFormation.HULL_CLEAR_M` stays a
   name that says which motion it licenses (nav's lesson 197): the lateral pitch is `max(width + HULL_CLEAR_M,
   2 × (half_diagonal − half_width) + width)` or the form you can defend, with a test that a formed squad can be
   ordered to a new heading and no pair's turning envelopes intersect. Pre-register the baseline: a pitch change
   moves the sim baseline (CPU armies use it); merge alone, tell the orchestrator.
5. **The base-of-fire scenario, honestly.** Reproduce with the drain (`make ai-scenarios` on a sealed tree); the
   base stops firing while the others move because of what? Fix the behaviour or re-specify the scenario with the
   reason; the count baseline is re-recorded by the orchestrator with your REASON.
6. **`_is_clear` compares rotated boxes as aligned** (item 3) and **Delta's margin** (item 4): the first is a test
   with an arena whose spawn zones are not opposed; the second is a measurement that says what Delta's worst crew is
   doing at 22 m, then the fix or the number written down.
7. **Stretch, in your round-9 order:** A10's `fixed` guarantee (`c0f22597`); A8 off the switch or off the branch;
   the tube's five-seed gate; the duel bar to a rate; A9's cost against the 4 s allowance.

## How to verify

- `make check` green (`make remote T=check`), `make ai-scenarios` with the count beside the hash.
- `make skirmish ARENA=terminus`: box-select units from two squads, give support-by-fire, watch the split; give a
  move mid-task, watch every crew turn within a tick. `make squad-defile` for the maze. Frames at his pose for anything
  visual.
- Every number: commit, machine, sample size; every arm proven applied (round 9's rule).

## Don't touch

`game/control/`, `game/ui/` (control's: send the API and a failing test), `game/ai/{movement,combat_motion,pathing,
steering,avoidance,pid,control_gains,order_controller,order_feed}.gd`, `game/tank/tank_motion.gd` (nav's),
`game/tank/`, `game/units/`, `game/combat/`, `game/match/` (combat's; the spawn grid constants are arena's this round),
`arenas/`, `game/arena/` (arena's), `game/theme/**`.

## Waiting on the lead

Nothing blocks. The pitch decision (item 4) was made for him; he overrules on the field.

## Research addendum (brief 2, 2026-09-20 evening; rows B1, B2, B7, B8, B14)

**R1 gets its default split (B8):** fitness S = (range × DPS) / (speed × agility), agility 1.0 tracked/hover, 0.5
wheeled, 0.2 articulated; sort descending, ties by unit id; the top ⌈n/2⌉ are the base element; then match the
assignments to positions projected on the normal of the target vector so deployment paths do not cross. Falsifier:
zero crossing deployment paths on five random selections.

**Item 3 (the settle time) is re-specified (B7): arrival is three phases.** Transit under pacing → OPERATIONAL
ARRIVAL the instant the formation centroid enters the destination zone and every hull is braking: the player's order
is COMPLETED here, pacing lifts, weapons free → INDEPENDENT DRESSING per crew: tracked and hover hulls neutral-steer
to the facing; wheeled hulls stop on their slot and keep their approach heading, accepting a residual (the turret
covers the sector). Our bar: a 20 m move on flat ground reports COMPLETED in ≤ 8 s with no rise in collisions. This
replaces the round-9 ruling that a held wheeled hull manoeuvres to its facing, EXCEPT for hull-fixed wheeled units
whose weapon arc the residual exceeds (nav's row). Composition rule (B14): during dressing, tracked hulls hold
turning-room priority and wheeled hulls never claim it.

**Item 4 (pitch) is confirmed as an invariant (B2):** lateral slot pitch ≥ the turning envelope's diameter unless
the element is deliberately single file.

**Acknowledgement within one second (B7):** on any player order a crew shows visible intent within 1 s on the default
path (turret slews toward the destination, the nose begins to turn) before the hull moves; control draws the pin at
the next tick. Cheap; it buys tolerance for everything slower.

**The funnel (B1) is what you publish for nav's seam item:** the element's corridor as a chain of convex polytopes
plus the leash, in `Element.state()`, so the mover can project onto it. Build the publisher when nav asks; the shape
is in the catalog row.

## Research addendum 2 (brief 3, 2026-09-20 late; rows C1, C2, C6)

**The funnel you publish (B1) has a construction (C1):** it is the string-pulled corridor's polygons shrunk by the
member's effective clearance and intersected around each portal; nav owns the construction, you publish the
element's corridor and leash so nav can build it per member. **`incoming_fire.gd:101` is one arm of combat's series
(C6):** give it its own knob so the disc can be swapped at that one site with the others held; the series pairs
arms by seed. **"Who yields" during dressing (C2):** the deterministic key nav adopts; tracked hulls hold turning
room (B14) and the key breaks the rest.

## Status

_(the worker keeps this current; newest first within each part)_

**Plan (2026-09-22, in order; one-line reasons):**
1. ~~Transient-element API~~: withdrawn by the lead (R1 is control's UX item). Nothing to build; `Element.state()` keeps its split.
2. **R2, squad's half**: FIRST, because the lead can't judge anything until a right-click is obeyed.
3. **Settle time**: measure end to end (`make squad-settle`), then B7's three-phase arrival. Second because it's what he sees next.
4. **Pitch from the turning envelope**: built now, merged ALONE after CP3 (the orchestrator's sequencing, 2026-09-22: CP3
   merges → I `git merge main` → the pitch lands with the baseline move pre-registered → combat re-runs five_squads).
5. Base-of-fire scenario; 6. `_is_clear` + Delta's margin; 6b. **ORBIT's eligibility gate (new, from combat,
   2026-09-22):** the engine-deck scenario (`scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck`) is red because
   ORBIT cannot out-circle a 50°/s turret around an 8.62 m hull: the scout's real orbit is a median 9.1 m/s at 6.6 m
   from the centre = 33.7°/s, while the gate assumes 14 m/s ÷ 11 m = 73°/s (combat's probe: the tank's turret within
   60° of the scout on 236 of 236 ORBIT thinks; a surface-relative radius moved deck hits 0 → 0). The fix is mine, in
   `tank_brain.gd`: the gate reads the orbit's REAL angular rate (measured, not v/r from constants), and/or the
   orbit's steering achieves the rate the gate assumes. The scenario's bar is the falsifier. After R2, settle, pitch.
   6c. **Slot drift on the bigger bus (from CP3, 2026-09-22):** `scenario_elements::test_a_unit_fighting_from_a_formation_
   slot_stays_in_it` on feel's box commit `055fb10f`: drift 15.2 m against its own leash + 2 m = 16.0 (laptop, PASS
   by 0.8), over on builder0. The bar is already derived (the leash is the doctrine's 14 m spacing, not the hull), so
   it is behaviour: a 9.7 m hull fighting from its slot carries its centre further. After the pitch + seating pair.
   **Correction (feel's bisect, builder0):** it PASSES on the box-only tree `055fb10f` (ai-scenarios 40,4) and fails
   only at `a138b5f1` with the R5 mounts, where the Condemned bus's turret pivot moved 0.2 m aft (z 0.2 → 0.4). The
   knife-edge (15.2 vs 16.0) was tipped by the MOUNT, not the box. Discriminating pair: `a138b5f1` vs `055fb10f` on
   the same seeds; the mechanism to look for is a pivot further from the hull centre changing where the hull stands
   to fire.
   (Its sibling, the overwatch scenario, was a start-geometry literal: fixed in CP3 by feel with a 4 m east start
   and a setup assertion that the stay-put control is exposed; box tree 0% vs 73%.)
   7. stretch.

**Item 4, the orchestrator's refinement (2026-09-22):** `2 × half_diagonal` (tank 8.95 m, rig ~14.4 m) is the bound
for neighbours rotating in OPPOSITE directions; a dressing formation turns its hulls the same way at about the same
rate, and one hull turning beside a still neighbour needs `half_diagonal + half_width` (tank 5.7 m, rig 8.85 m). 14 m
between rigs abreast is a look he notices before the rotation room. So: the test MEASURES the turning envelopes
per tick while a formed squad is ordered to a new heading (not the static bound), the landed pitch is the smallest
that passes with zero intersections, both candidates' numbers go in Status (the conservative bound is the fallback if
the measured one clips), doctrine spacing still wins where larger, and a frame pair goes to him: a five-rig line at the
chosen pitch beside today's, at his pose (21°, FOV 35, 49 m).

**Machine note:** every number below says its commit and machine. The laptop is ~2.75× slower than builder0.

### Done

- **On main `08319e59` (builder0, the record):** `MEASURE element_support_by_fire lane clear at 1.5 s, first shot
  0.9 s after it, 9 shots in the 22.5 s after, through a friend 0` PASS; `MEASURE ai_cp2_scout_engine_deck x4mw
  {deck 27, hits 29, shots 29}; x3m (no weak spots) {0, 0, 0}` PASS. `make repath-test`: 6/7; `arrived` STALE only
  for crews destroyed before the click (six of eight dead there; the two living changed at +0 ticks). Count
  re-recorded on main at `4ff45e50`: 44,0,3,0.
- **MERGED to main at `08319e59`:** `e4d5e3f3` (stream/squad with main `52254fd2` = control's R2 merged in), builder0: `make check
  exited 2`, **1587 passed / 0 failed**, sim-baseline `1ea332e7bc268d2a` UNMOVED, determinism `559a415887806e43`,
  red ONLY on ai-scenarios-check: **43 passed, 1 failed** (was 41,3; the one red is combat's
  `artillery_stays_dug_in`). REASONs: base-of-fire re-specified (`35f7b459`), ORBIT controller (`2ac026af`). Commits
  after it are docs only. `make repath-test` (laptop) on it: 6 of 7 pass; `arrived` reads STALE only for two crews
  destroyed before the click (control's dead-crew exclusion `563c9155` not yet on main).

- **Baseline (start of round):** `2ee65f94`, builder0: `make check exited 0`, 1559 passed / 0 failed, sim-baseline
  `1ea332e7bc268d2a` unmoved, determinism `559a415887806e43`, ai-scenarios 41,3.
- **Item 2, R2 (squad's half)** — `2d5945ac`, `35f7b459`. REPLACES: `Elements._physics_process`'s cycle gate for a
  player task (it now runs on the next tick), and for that first update `Element._issue`'s three skips (player-source
  guard, `_should_issue`) and `_adopt` (`_retake` takes detached crews back). Only on the player's team (CPU elements
  keep their cycle). Also `_should_issue`'s idle branch gives an idle crew the `follow` its flow asks for (control's
  repath-test "arrived" finding; any team). `task_seq` rides on orders as `task` once control's key exists (it does
  on stream/control `54fa6ff6`). Measured on the unfixed code (laptop): 3 of 4 crews still on pre-task `follow`s 2
  ticks after `assign()` at every phase of the cycle. `test_tactics_preempt` 7/7 (laptop); mutation-checked: no cycle
  bypass fails 2, no forced re-issue fails 3, no retake fails 1, no idle-follow branch fails 1.
- **Item 3, settle time, step 1** — `96915bfc`. `make squad-settle` (three times per run: `ordered_s`, `arrived_s` =
  COMPLETED per B7, `stopped_s`; `TRACE=on` per second) and `make squad-settle-series` (paired seeds, both arms).
  Before (laptop, seed 1, tank/tank/ifv/ifv abreast, 20 m plain move; arrived / stopped): default fwd 4.0/8.2, default
  SIDE 14.8/19.8, Terminus fwd 4.4/20.5, Terminus side 18.0/25.0. Cause of the slow side moves (trace): the leader was
  pinned to the column's head, 46.8 m from where it stood, and stalled 5 s driving through its own squad; the armour
  tiers sent a tank through two ifvs; collinear moves tied and the solver picked crossing paths. REPLACES the plain
  move's seating in `ElementPlan._plan_form_up` (→ `_group(..., pin_leader=false, policy="travel")`) and adds the
  `travel` policy to `TacticsFormation.seat` (least SQUARED driving, no tiers). After, one seed (laptop): default side
  6.7/13.5, Terminus side 10.7/13.1; longest leg 47.9 → 23.9 m. The paired series on builder0 decides it (pending).
  The Terminus forward tail (20 s) is one wheeled ifv `blocked/terrain` 5 m from a slot against geometry: nav's.
  Tried and reverted: lifting co-arrival pacing at arrival (Terminus fwd 20.5 → 32.7 s, one seed).
- **Item 3, settle time, step 2** — `6d6d6264`: `_flow` runs only when the leader leads from the front (else every crew
  goes straight to its final slot); the probe's seed jitters the start (±1.5 m, ±10°: the first series had six
  identical seeds, n = 1). **Paired series, builder0, `a3582c82`-tree + `6d6d6264`, 8 jittered seeds per cell,
  20 m plain move, tank/tank/ifv/ifv (median arrived / stopped, s; shipped vs round 9's pinned leader; discordant
  stopped pairs shipped-faster/round-9-faster/tie):**

  | arena | dir | arrived | stopped | pairs |
  |---|---|---|---|---|
  | default | forward | 1.9 / 3.8 | **4.2** / 9.2 | 7/0/1 |
  | default | side | 2.7 / 11.7 | **4.9** / 14.8 | 8/0/0 |
  | default | back | 8.4 / 8.4 | 15.8 / 15.3 | 4/3/1 |
  | terminus | forward | 2.6 / 3.8 | **5.8** / 7.1 | 6/1/1 |
  | terminus | side | 2.8 / 12.5 | **9.3** / 17.2 | 8/0/0 |
  | terminus | back | 8.9 / 7.3 | 16.2 / 13.5 | 4/4/0 |

  Overall 37 / 8 / 3. **B7's COMPLETED ≤ 8 s: met forward and side (max 2.8 s); back 8.4–8.9 s. The < 10 s settle bar:
  met forward and side on both arenas; NOT met for back** (a wash between arms): a 20 m move BACK from the spawn lays
  a 40 m column whose rear slots press on the arena edge (`blocked/terrain` in the trace), and one wheeled crew
  creeps 0.5–1.8 m/s for ~15 s after its order completes. Known issue, next in item 3 if time: the plain move's
  formation is the doctrine's COLUMN, 40 m long for four hulls, for a 20 m reposition.
- **Item 5, base-of-fire scenario** — `35f7b459`. Re-specified with the reason: the base crews were hand-issued
  `attack` (close with and destroy: they reversed, one charged 32 m, no shot for 6.3 s after a lane cleared); the
  element issues a base crew a HOLD on its spot, and the scenario now does. The early-shots bar measured nav moving
  the assault out of the lanes it starts in; the clock now starts at the first clear lane. Laptop: clear 1.5 s,
  first shot +0.9 s, 9 shots, 0 through a friend. **REASON for the count: expect ai-scenarios 41,3 → 42,2.**
- **Checks:** `96915bfc` builder0 exit 2: 1565/1, the red `test_an_element_flows_in_formation_on_the_way` (travel
  seating improved snapping's transit gap more than the flow's; re-specified in `64a9e1e1` against round 9's seating:
  flow 8.0 m vs round 9's 10.0, dresses 3.2 vs snapping's 6.4). `64a9e1e1` builder0 exit 2: **1569 passed / 0
  failed, sim-baseline `1ea332e7bc268d2a` UNMOVED, determinism `559a415887806e43`**, red ONLY on ai-scenarios-check
  at 42,2 (pre-registered, the base-of-fire REASON below). The orchestrator's ruling: red only on the count with the
  REASON written is mergeable; the count is re-recorded once on main, not on this branch.
- **R2, control's "near" state** — `d358febc`: a player task 5 m from the old one moves the leader's order within 2
  ticks (mutation: without the forced re-issue the goal moves 0.0 m, control's laptop finding exactly).
- **Item 6b, ORBIT** — `2ac026af` (combat's finding: the orbit radius was not the mechanism). REPLACES the ORBIT
  steer point in `TankBrain` (a point ON the 11 m circle 75° ahead → an orbit controller: tangent turned by the
  radius error, gain 2, clamped 45°, 13 m look-ahead), adds `ORBIT_MEMORY_TICKS` (the circled target stays fresh 4 s,
  three sites, the COVER_FIRE pattern), and deck runs start inside Armor's 25° cone (`COS_DECK`) and break outside
  45°. Engine-deck scenario (laptop): 0 deck hits of 13 → **27 of 29**. **REASON for the count: expect 43,1 at the
  tip.** May move the sim baseline (CPU scouts orbit turrets): the tip's check says.
- **Item 4, instrument** — `d1253eb1`. `TacticsFormation.LATERAL_FLOOR` (default "width" = round 9: nothing moves) and
  `tests/test_tactics_pitch.gd`. Measured (laptop, tank 2.40 × 8.62, four abreast turning in place): width 4.40 m
  −0.23 same (2 of 4 jammed) / −0.48 opposite; half_diagonal + half_width 5.67 m −0.73 / −0.36; 6.5–8.5 m clips at
  every step (−0.27 at 8.5); **2 × half_diagonal 8.95 m +0.01 / 0.00**. Two parallel hulls turning together each
  project w|cos θ| + l|sin θ| on the line between them, peaking at the diagonal: a dressing formation needs the
  diagonal. Lands at CP3 as `max(width + HULL_CLEAR_M, diagonal)` (tank 8.95, rig ~14.4; doctrine spacing wins where
  larger). The only tighter option is a STAGGERED dressing (crews turning one after another): a behaviour for the
  lead's eye, not built.
  **RULING (orchestrator, 2026-09-22):** lateral floor = `max(width + HULL_CLEAR_M, diagonal + DRESS_MARGIN_M)`,
  `DRESS_MARGIN_M` = 0.30 m, a named constant (1 cm at 8.95 is inside the plant's slack and the spawn jitter; 0.3 m is
  invisible to his eye and outside both). Tank 9.25 m, rig ≈ 14.7 m. Lands after CP3: alone, baseline pre-registered
  MOVED with one cause, the five-row pitch table in the commit message, the five-rig frame pair for him. Staggered
  dressing is the next arm only if he says the rigs look too spread.
- **Item 6a, `_is_clear`** — `80905740`. REPLACES the aligned projection in `ArmyLayout._is_clear` with the
  separating-axis rule on each placed hull's own forward. Test with a 90° neighbour (old: 3.6 m clear, true 0.5 m).

### Requests to other streams

- **control (R2), sent via the orchestrator 2026-09-22:** `Orders._same_order` drops an ELEMENT re-issue whose only
  change is the facing (non-player sources skip the facing compare; slots < `SAME_ORDER_M` apart). It also drops an unchanged
  `follow`, so a squad re-dragged on the same spot can keep its leader's old arrival heading until arrival. Ask: add
  `"task"` to `UnitCommand.KEYS` and have `_same_order` return false when `current.task != order.task`. squad's side
  already sends `command["task"] = element.task_seq` for the player's elements as soon as the key exists (runtime
  adapter `Element._ORDERS_TAKE_TASK`), and `test_tactics_preempt` asserts the leader's facing from that day.

- **combat (C6), owed by squad AFTER combat merges:** pass `"squad_incoming"` as the site argument at
  `game/ai/incoming_fire.gd:137/139` (combat's `match.hull_disc_{lof,incoming,squad_incoming}`). The helper has no
  site argument on main at `52254fd2`, so the one line waits for combat's merge; then `git merge main` and add it.

### Questions for the lead

_(none yet)_

### Known issues

_(none yet)_
