# Stream: orders (squads arrive in their travel shape and deploy as one move, packed close; routes that don't jam)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 35** (C35.1, C35.2, C35.4, C35.5),
> `_agents/game_design.md` *Round 34, his playtest words during the round* and *Round 34 close* (his answers, verbatim), and the
> round-34 briefs `streams/archive/round34/orders.md` and `streams/archive/round34/brains.md` (B6, B8, B8b, O1–O4, R34.12: the
> whole history of this code, with every trace). Evidence: `references/round34/orders/` (planner's probe, the lead's pass and its
> screenshots), `_agents/streams/references/round34/brains/` (B6/B8 traces and tables).
> **You own:** `game/control/**` (except manoeuvre's additive fields in `game/control/screen_playtest.gd`), `tests/test_control*.gd`,
> `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`, and in `game/tactics/element_plan.gd` the deploy-step and
> halt-lay functions (`DEPLOY_STEP`, the deploy step's helpers, the halt seat lay for a plain AUTO move; merge note to brains).
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

His round-34 report, verbatim: *"If I select 3 squads and then tell them all to move to some point on the map, there's some
algorithm that automatically determines new points for each squad … one of them was all the way across the bridge, thus causing
one of my squads of scouts to go on a suicidal mission. How can we get behavior closer to starcraft…"* His corrections: squads may
nest (*"isn't there enough spacing where we could intersect two wedges basically?"*), and waypoints are the squad's (*"it's more
about the squad moving through that waypoint versus individual vehicles"*). His answer at round 34's close: **"Yes, use the deploy
step"**: a squad arrives in its travel shape and spreads into its halt shape as one deliberate move.

What he will notice this round: squads that arrive and deploy once, with no twitching afterwards; several squads sent to one point
packed close but never on top of each other; five squads on a Locks route that don't jam at a junction.

## Where things stand (main at the round-35 docs commit)

- **Shipped in round 34:** O1 the ground cap (no squad sent over a bridge it wasn't clicked across), O3 squads priced at their halt
  shape, O4 routes are the squad's (passed at about its width, gates), o4b, brains' two Locks fixes (stations and order goals stay
  on the anchor's bank), the rank fix + rank depth (the back rank comes up), ground_anchors (an anchor on a building stands beside
  it), the player-route stall fallback (12 s settled), gate order (first through a shared gate takes the farthest place). The
  lead's pass on main 62d90dc97: no crossing in 24 cells; five squads all go; routes finish except the Locks cells below.
- **The deploy step:** B8b is on main OFF. `round34/brains` `07c029732` is the WIP that flips it ON (tests updated, `test_on_by_default`),
  **no check run**. It reaches CPU elements too (ElementCommander gives plain moves), so sim-baseline WILL move.
- **The shuffle:** post-arrival seat moves 19–38 m worst with 3 squads, up to 87 m with 5 (main); with B8b, the twitch after the
  deploy is ~0 in 4 of 6 cells, the deploy move itself 16–30 m. Remaining causes known (B6/B8b traces): the halt re-seat after 2 s,
  travel seats re-grounded while the slowest crew arrives, the Locks strip between canal and building squeezing seats.
- **O2 packing (parked R34.12):** an AUTO pack before the deploy step was neither tighter nor fast enough (the heading isn't known at
  order time). With the deploy step, it is: the halt seats are laid on the order's approach heading. `wip/brains-o2` holds the
  attempt and the rotation-tolerant core.
- **Locks 5-squad route:** squads 3 and 5 jam for ~55 s at (5, 65); their drives cross though their anchors' lines don't
  (planner's trace, `references/round34/orders/gate-order-f1034b904/`).

## Backlog (in order)

1. **D1 Ship the deploy step ON (C35.2).** Start from `round34/brains` `07c029732` (cherry-pick or merge onto your branch). Laptop
   tests, then the full check on builder0 under systemd-run; attribute every moved sim-baseline map with `DEPLOY_STEP=off` on the same
   tree. A REPORTED fights census beside it (fresh fixed arenas, both sides, deaths/kills/stuck), since the CPU gets it too; bring a
   gross regression (> 2 se) to the orchestrator before shipping. Name the hash; the orchestrator adopts the baseline.
2. **D2 The probe on the shipped hash.** `make orders-probe` (planner's, now yours): 24 cells, main v `--deploy-step=off`, with the
   screenshots at arrival and +5 s. File as the "before" for D3.
3. **D3 Tight packing (C35.4).** On the deploy step: the order fixes each squad's approach heading; the halt seats are known at
   order time; pack by hull clearance (~9 m between crews of different squads), his 28 m between two columns, each squad on its own
   side of the approach, back ranks no farther back than their own squad, nothing on a building. The click's 3-tick response kept.
   Bar filed with the orchestrator before any number (the probe's cells + the squad-arrive / settle series, both arms).
4. **D4 What's left of the shuffle.** Trace the 5-squad cells' remaining post-deploy moves and the Locks strip; fix what the trace
   names (likely seats re-grounded during the wait, and the halt re-seat).
5. **D5 Crossing drives on the last leg (C35.5).** Deal the last leg by navmesh paths where they cross; a length guard; the Locks
   5-squad route as the test; probe before/after.
6. **Stretch:** the order markers show each squad's real halt place before he lets go of the button.

## How to verify

Tests first; `make quick-remote` while iterating; `make remote T=check` only for a hash you'll name (one at a time on builder0).
`make orders-probe` for anything he'll see, with screenshots looked at. Every number: commit, machine, map, n.

## Don't touch

`game/ai/**`, the rest of `game/tactics/**` (brains), `screen_playtest.gd`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing (his deploy-step yes is the go).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### D1 the deploy step ON: check record
- `orders-d1` `1a5e33c47` (= the flip + census + probe columns + main 0f4d528d7), builder0: `>> remote: make check exited 2`;
  test 2884 passed, 2 failed; **sim-baseline passed, 13 maps unmoved** (glibc-2.43): nothing to attribute (the CPU never
  reaches a plain move with the step on, as the census found). The 2 failures: test_tactics_scenarios_3/4 "every formation
  stands on the spot it was sent to (anchor 1.5-9.5 m off)": B8b laid the halt centred where the squad stood.
- Fix `orders-d1` `0603f3274`: within DEPLOY_ON_SPOT_M (12 m) of its spot the halt stands ON it; B8b's centred lay stays
  for a squad deployed on the 10 s cap far short. Laptop GDScript: those two files + test_tactics_deploy_step 9/0.
  builder0 full check: queued behind native's (C35.1: one check at a time).

### D4 A/B: FAILED its bar, minimax seating PARKED OFF (`bd22ac4c8`; `--deploy-minimax=on` opts in)
builder0, `make native orders-probe`, `68d4c06cd`, seeds 3621-3626, n 6, both arms `--gate-deal=off`; rows
`references/round35/orders/d4-ab-68d4c06cd/`. Counter: acted (25 / 36 click runs differ). Gain: summed median twitch 169.1 v
179.8 m (6 %, needed 20 %); Terminus 5 click 5.7 v 18.9 (better). Per-cell guard fails in 4 cells (Crossing 3 click 15.4 v
10.7, Crossing 5 route 29.4 v 21.4, Locks 5 click 21.4 v 13.9, Terminus 5 route 21.2 v 17.3); never-in up (Terminus 5 route
3 v 2, Locks 5 route 1 v 0). What stands from D4: the residual twitch is the deploy move itself, and halt seats reached
only round obstacles (round-36 design questions, below).

### D4 bar (minimax deploy seating), FILED BEFORE ANY BUILDER0 NUMBER (2026-10-19 11:35 PDT)
- **Probe:** `make native orders-probe ORDERS_PROBE_SEEDS="3621 3622 3623 3624 3625 3626" ORDERS_PROBE_ARMS="main:--gate-deal=off minimax_off:--gate-deal=off,--deploy-minimax=off"`
  (R35.26: both arms with the gate deal OFF, so D4 is judged on today's main behaviour whatever D5's fate); tree stream/orders
  `68d4c06cd` (code = `554131533`).
  on builder0 (native), 24 cells x 6 fresh seeds (never run anywhere; seeds move the click <= 12 m), medians a cell. Seed
  34 (tuned on, laptop) reported only. **Counter first:** the two arms' rows differ in >= 1 cell (the seating acted).
- **Gain (must pass):** summed over the 24 cells, the median `twitch worst m` at least 20 % lower on main; and the Terminus 5
  click cell's median twitch lower on main.
- **Guards (each cell):** median all in <= minimax_off x 1.2 + 3 s, no more never-in seeds; median `place worst m` <=
  minimax_off + 5 m; median `twitch worst m` <= minimax_off + 3 m (the orchestrator's addition: a sum can hide one cell
  getting worse, as the laptop's Locks 5 did); median end foreign min >= minimax_off - 3 m; deck / far no higher.

### D4 what's left of the shuffle: traced (laptop GDScript, seed 34, the 6 click cells, stream/orders `9370f5ddb`)
- Twitch after the place window (8 s from the deploy), worst crew: Crossing 3 25.2 m, Crossing 5 21.4, Locks 3 8.6, Locks 5
  13.6, Terminus 3 9.8, Terminus 5 31.3. Squads deploy all-in or on the 10 s cap about half and half.
- **Terminus 5, squad 4 (31.3 m), traced every second:** the last crew in (Delta_2, still driving to its travel seat on the
  east wing at t 6-8) was seated at the deploy (t 9) on the far end of its own herringbone, 45 m away; it drove past its
  squadmates in a street, sat blocked t 11-21 and stopped 18 m short behind Delta_1. So most of what reads as "twitch" is
  the DEPLOY MOVE overrunning the 8 s window: a wedge (wide ACROSS the approach) re-forms into a herringbone 55 m deep ALONG
  it, so the wing crews have up to ~27 m each to go, through squadmates, in lanes.
- **Tried and reverted:** seating nobody past a standing squadmate (the battery rule's PAST_COST with every squadmate):
  Terminus 5 unchanged (31.3 m), Locks 3 worse (23.1 v 8.6 m), Crossing 5 21.4 -> 27.3. Not kept.
- **Built, `93c1b35db`: minimax deploy seating** (`ElementPlan._deploy_keep`, `--deploy-minimax=off`): every assignment
  (<= 6 crews), the longest leg shortest, then the least total, pinned through `_group`'s `keep`. Laptop GDScript seed 34:
  Terminus 5 twitch 31.3 -> 14.0 m (place 25.0 -> 22.4), Locks 5 13.6 -> 15.5 (place 28.7 -> 26.0), 4 cells identical.
  `test_control_deploy_minimax` 3/0. Not judged yet (builder0, fresh seeds, a bar first).
- **Crossing 3, squad 1 (25.2 m), traced:** a different cause. At the deploy (t 13) Alpha_1's seat is 8.7 m off and Alpha_3's
  18.5 m, but both drive detours of 20-30 m (Alpha_1 to the west deck's end and back over 20 s; Alpha_3 30 m south and back):
  the halt laid ON the spot puts seats that are reached only round an obstacle. The halt lay would need driving distance
  (like `_dry_halt_anchor` steps inland from water); ElementPlan is pure (no navmesh) today. Ruled (orchestrator): the
  halt lay stays pure this round; **round-36 design question:** give the deploy's halt lay a reachability input (e.g. the
  controls pass, with the order, which grid cells near the spot are reached by a short drive), so seats behind a wall
  or across a bank step away as `_dry_halt_anchor` does for water.
- **What the trace points at (not built):** the deploy's shape change itself. Either the halt is laid so the travel seats
  map onto it without crossing (a herringbone's seats ordered as the wedge's, wings to the far ends by side, not by
  least total), or the halt in lanes is laid ACROSS the street as the travel shape is. Both are the halt-lay functions in
  my carve-out; the first is the smaller change and the next D4 step.

### D5 bar (C35.5), FILED BEFORE ANY BUILDER0 NUMBER; amended by the orchestrator (fresh seeds), as filed on main
- **Probe:** `make orders-probe ORDERS_PROBE_SEEDS="3611 3612 3613 3614 3615 3616" ORDERS_PROBE_ARMS="main: gate_off:--gate-deal=off"`
  on builder0 (native), the 24 cells x 6 FRESH seeds 3611-3616 (n 6 a cell; medians, the table's MEDIANS block; a seed moves the click, and the route's waypoints, <= 12 m to a dry standable point; 3601-3602 were seen on the laptop, so not judged; no laptop run on 3611-3616), the same tree (deploy
  step ON, pack OFF). Seed 34 (the cell the fix was tuned on, 43.3 -> 16.9 s on the laptop) is REPORTED only.
  **Counter first (R35.5):** `gates_laid` > 0 in the route cells on main; the legs (`ORDERS_PROBE_LEGS`) differ between arms.
- **Gain (must pass):** the Locks 5-squad route's median all in <= 0.7 x gate_off's median (a seed never in counts as inf);
  and over the 12 route cells the summed median all in lower on main.
- **Guards:** the click cells identical across arms on every seed (the table's EQUALITY line: the deal acts only on queued
  legs); every route cell median all in <= gate_off x 1.2 + 3 s, and no more never-in seeds than gate_off; deck / far no
  higher than gate_off in any cell; drive/plan median <= gate_off + 0.2 in each cell.

### D6 (R35.28): a shift-click never REPLACES a squad's route because its elements don't match the group. Bar FILED BEFORE CODE
Option (b): a shifted move queues on the elements its units now belong to (round 22's cross-squad re-deal stays: it is
what stopped his interleaved squads crossing). Bar (as the orchestrator filed it on main): Crossing 5 route s3614 (the
reproduction; reported) + fresh route seeds: every squad gets every leg (legs per squad = waypoints); round 22's Sumps seed
5988 scenario keeps 0 path crossings; test_control_queued_task and the route tests green; the click cells byte-identical; a
test that reproduces the replace. Fresh route seeds **3641-3646** (named on main); counter first: legs queued per squad
differ between arms in >= 1 route cell; the reproduce-the-replace test red with the switch off, green with it on (built:
`test_control_requeue`, both directions). Order: after D5's re-read and D4's A/B. Code: `862e60970`, OFF until then.

### D5 A/B 1 (builder0, `554131533`, seeds 3611-3616): gain PASSED, guards FAILED; one fix try (R35.26)
- **Read:** Locks 5 route median all in 19.9 v 33.4 s (gain line <= 23.4: pass); route medians summed 153.3 v 170.4 s; click
  cells 36/36 identical. **Failed guards:** Crossing 5 route 1 never-in seed (s3614) v 0; deck touches Crossing 3 route 6 v
  5 and Locks 3 route 4 v 2 (every extra one a crew nosing onto the NEAR end of a ramp, z 11.9 / ~31; far bank 0
  everywhere); Crossing 5 route drive/plan 2.17 v 1.94 (+0.23 v +0.2). Rows: `references/round35/orders/d5-ab-554131533/`.
- **Trace s3614 (reproduced on the laptop):** the gate's approach `prev - before` pointed BACKWARDS (-9.4, 4.2; the route
  runs -x -z) because waypoint 2's places had been laid ~40 m behind the click, near the squads' first legs; so the deal's
  front rank and never_behind ran the wrong way and sent squad 1 17 m back, and squad 4 (one of three squads whose route had
  collapsed to a single leg, both arms: a separate bug, below) ended 29 m short in the changed traffic.
- **Fix try (`45d34470a`):** with the deal on, the gate is passed from where the squads come from (`before`) toward the next
  click. s3614 laptop: squad 1's place now forward and to the side; all in 33 s. Locks 5 route s34 unchanged (17 s).
- **Separate bug seen (both arms, not touched; he would notice it):** in Crossing 5 route s3614 squads 3-5 got ONE leg each
  (their task REPLACED at each shift-click, never queued). Traced with the probe's `--probe-legs-each=on`: from the first
  click, `selection_squads()` returns squads 3-5 with MIXED units (squad 4 = Charlie_2, Charlie_3, Delta_4, Delta_5, Echo_4;
  squad 3 = Echo_1-3), i.e. `SelectionSquads.split` dealt them west to east as if from one oversized group, so no element is
  exactly theirs, `_queue_task_for` gets `held == null`, returns null, and the squad's task is replaced. **Cause (traced):**
  the split is clean at every click; the mixing is round 22's `SelectionSquads.untangle` (O1b) inside the FIRST click,
  which re-deals VEHICLES between squads whose drives would cross, so the elements formed then no longer match the control
  groups, and every later shift-click finds no element exactly the group. Fix options: untangle whole squads (deal squads
  to places, never vehicles across squads), or have a shifted move queue on the elements the units now belong to. A design
  choice (O1b's re-deal was his round-22 case): to the orchestrator.
- **Next:** the fresh re-read on 3631-3636 (filed on main, same bar) once D4's run frees this folder; fails again -> D5 parks.

### D5 crossing drives: built on stream/orders `77c284868` (no builder0 number yet)
- **Trace** (laptop GDScript, Locks 5 route, seed 34, `ORDERS_PROBE_LEGS` + `--probe-trace`): not the last leg. The IN-BETWEEN
  gate (O4's `gate_anchors`, waypoint 2) dealt squads left to right by where they stood AT HOME and stepped ranks by the
  HALT depth (herringbone, 55 m + gap): squad 3 (middle start, middle end) got the gate's far east (40, 60) and squads 2 / 4
  places 11-15 m BEHIND their own first leg. Squad 3 drove 208.6 m for a 69.9 m plan and crossed squad 5 at the junction.
- **Fix** (`RtsControls.GATE_DEAL`, `--gate-deal=off` = round 34): the gate is dealt by each squad's previous leg end, the
  nearest the gate take the front rank (left to right within it), ranks step by the travel shape's depth, and no gate place
  is behind the previous leg (R34.12b's never_behind). Plus `SelectionSquads.uncross_paths` (a leg's places swapped where
  the squads' navmesh paths cross, length guard 1.25x + 10 m, `--uncross=off`): a backstop, 0 swaps in this cell.
- **Laptop GDScript, Locks 5 route, seed 34, n 1:** all in 16.9 s v 43.3 s (`--gate-deal=off`), worst shuffle 32.6 v 53.8 m,
  twitch 3.1 v 12.5 m, drive/plan 1.26 v 3.06, deck 0 v 1. Tests: `test_control_gate_deal` 3/0, `test_control_uncross` 5/0.
- **Next:** the 24-cell probe on builder0 with arms main / `--gate-deal=off` (counter: gates_laid and the legs) after D1's
  merge and D2; bar below before reading it.

### D3 tight packing: PARKED, OFF by default (`--pack=on` / `PACK=on`), code on stream/orders `183eb4cd6`
**What was built** (`SelectionSquads.pack_halts`, `RtsControls._pack_halts`, the task's `halt_at` / `halt_shape` / `lay` per
R35.6, `ElementPlan._deploy_state` / `_deploy_shape` read them): with the deploy step on and 2+ AUTO squads on one plain
click, each squad's HALT seats are laid at order time and packed on a 2 m grid: every halt seat 9 m from another squad's,
no seat inside another squad's halt outline (a coil is a ring: by seat clearance alone a second coil stood inside it),
columns 28 m, nobody sent back past where it stands, seats within 4 m of standable ground (water refused), the click's
ground cap, halts may turn 90 deg across the approach (the Locks strip), started from the ranks and compacted (each squad,
dearest first, to its cheapest place that still fits), squads of one shape dealt to the places by least driving. 14 tests
(`tests/test_control_pack.gd`), laptop 14/0.
**Why parked (what it found):** the brief's premise ("with the deploy step the halt seats are known, so packing is exact")
holds for the HALT only. Squads ARRIVE in their travel shape (a wedge ~60 m wide for five) and deploy only when every crew
is in, so packed halts put two arriving wedges' slots 5.7 m apart (`test_control_two_squads`' "slots do not mix" fails) and
the 5-squad Locks cell jams (laptop GDScript probe: place move 40.7 m, twitch 27.3 m, drive/plan 2.25). Keeping the travel
shapes apart too (`PACK_TRAVEL_CLEAR_M` 7 m) makes the pack no tighter than the ranks (five coils: 70.7 m v 68.7 m to the
farthest crew; by halts alone 64.4 v 73.6). Round 34's O2 note said the same ("the travel seats before all-in still aren't").
And on the Locks the strict ground test stacks squads back along the approach (the decided rule for tight ground), so end
spread there grew (3 squads: 66.9 v 47.6 m), not shrank. No bar number was read on builder0 (laptop iteration only).
**What would unlock it (a design question, for the orchestrator / the lead):** packed squads must ARRIVE in something that
nests as tightly as their halts. Options, most reversible first: (a) a packed squad's last stretch in a narrower arrival
shape (file / column) that its halt opens out of; (b) deploy each squad as soon as ITS crews are in, the first-in front ones
first, so arrival overlap is transient (needs a stage); (c) accept B6-style shape-on-the-final-approach (failed its bar in
round 34 on a stale goal, B7 found the cause). Recommendation: (a).

### D3 bar (C35.4), FILED BEFORE ANY NUMBER (2026-10-19 ~09:20 PDT)
- **Probe:** `make orders-probe` on builder0 (native), seed 34, n 1 a cell (deterministic): Locks / Crossing / Terminus x 3 / 5
  squads x click / route = 24 cells, arms `main:` (pack on) v `pack_off:--pack=off`, the same tree, the deploy step ON in both.
- **Gain (must pass):** over the 6 CLICK cells, the median of each cell's `end far max m` (the farthest crew from the click at
  the window's end) at least 15 % below pack_off's; and in EVERY cell `end foreign min m` >= 7 m (the 9 m design, less
  grounding slop), on both arms reported.
- **Guards (each must hold in every cell):** all-in <= pack_off x 1.2 + 3 s, and no cell all-in on pack_off but not on main;
  far bank 0; `toward min m` >= 0 (nobody sent away from the click); `twitch worst m` <= pack_off + 5 m.
- **Response:** `test_control_scale` (the click's 3-tick response) passes in the check of the named hash.
- **Single squads:** the pack acts only on 2+ squads; `make squad-arrive-series ARRIVE_ARM_FLAG=pack ARRIVE_MAPS="terminus sumps"
  ARRIVE_SEEDS="1 2"` both arms must be byte-identical (an equality check, reported).
- Screenshots (`orders-probe-shots`, arrival and +5 s, desktop and phone) looked at for every 5-squad click cell.

### REPORT (in progress, 2026-10-19 ~12:50 PDT; every number names its commit and machine)
**D1, the deploy step ON (his item): MERGED, main `1a18dd278`** from `orders-d1` `581b8a396` (= round34/brains 07c029732's flip + the
on-spot lay + R35.17's body-test line + the census and probe tools, on main 0f4d528d7); builder0 GREEN: `make check exited 0`,
2886 passed, 0 failed, sim-baseline 13/13 unmoved. Its two earlier checks: `1a5e33c47` exited 2 (2884/2: the scenarios' "on the spot" lines, fixed by the on-spot lay),
`0603f3274` exited 2 (2885/1: test_tactics_body, resized under R35.17 after a builder0 trace). sim-baseline 13/13 unmoved
in both (the CPU never deploys: the census's 48 fights byte-identical on and off).
In his terms: a squad sent somewhere arrives in its travel shape, then steps once into its halt shape ON the spot it was
sent to; one squad halted in a herringbone across a street can slow a neighbour driving through (+6 s in brains' Locks body
stage).
**D5, the Locks 5-squad route jam:** cause traced (the in-between gate dealt by where squads stood at home); fix built on
stream/orders (`--gate-deal=off` = round 34). Laptop GDScript seed 34: all in 16.9 s v 43.3 s. Judged A/B on builder0
(fresh seeds 3611-3616) waits for D1's merge + D2.
**D4, the shuffle:** traced; minimax deploy seating FAILED its judged A/B (6 % v the 20 % line, 4 cells worse), parked OFF. The Crossing's detour seats and the herringbone-across-a-street are round-36 questions.
**D3, tight packing:** PARKED OFF (R35.11): the halts pack, the arrivals don't. D3b (a narrower arrival shape) after D5/D4.
**D2, done (reported):** `references/round35/orders/d2-main-1a18dd278/` (README in his terms, table, 48 shots). builder0 table
on main 977a270fa (seed 34, n 1): the twitch after settling falls on the Crossing and Locks 3 cells, rises on Locks 5 click and
Terminus 5 click (the step overruns 8 s there); Locks 5 route now finishes (45.6 s, round 34's never did); no river crossing.
Shots: the laptop (builder0 has no desktop; `orders-probe-shots` now fails on zero frames).

### D1 census bar (C35.2), FILED AFTER THE READING (said plainly)
The census ran (`e9066083a`, builder0) before the orchestrator asked for the bar, so this bar is written after its numbers.
It is moot in this instance: the two arms are byte-identical (below), so no line could read differently.
- **Probe:** `make deploy-census`: CPU v CPU (both sides ElementCommander), Locks / Terminus / Sumps x fresh seeds 3501-3516,
  factions rotated by seed, 1000 credits, 150 s, paired by (arena, seed), on v `--deploy-step=off`; n 48 pairs.
- **Gross (blocks shipping, to the orchestrator):** per side or pooled, deaths UP or kills DOWN by more than 2 se of the
  summed paired difference; stuck crew-seconds UP by more than 2 se. Alive and deploys are reported only.
- **Reading:** every line diff +0.0, se 0.0: arms byte-identical, 0 deploys on either side. The census's CPU gives
  screen / attack / support_by_fire / ambush tasks, never a plain move (`--trace=on`, laptop, Locks s3501, 40 s), so the deploy
  step never fires in a fight. **Not gross: D1 passes.** Rows: `references/round35/orders/d1-census-e9066083a/`.

### Working rule (R35.15)
After any merge of main that touches `native/src`, `touch native/src/*` before a remote run (builder0's rsync keeps the old
mtimes, so a stale native library can survive) and check sim-baseline reads main's current lines.

### Plan (2026-10-19, round 35)
1. **D1** the flip (`ee16b1b1e` = main a0ae0aafd + 07c029732's code; brains' brief left out) → quick-remote → full check on
   builder0 (one at a time: the orchestrator's C35.3 pair check is on the box at launch) → attribute moved sim-baseline maps
   with `make remote T="native sim-variants VARIANTS_EXTRA=--deploy-step=off VARIANTS_TAG=deployoff"` (off must read the
   recorded lines) → the REPORTED fights census (`make deploy-census`, new: CPU v CPU, Locks/Terminus/Sumps x fresh seeds
   3501–3516, factions rotated, on v off, deaths/kills/stuck/deploys by side, > 2 se = gross) → name the hash.
   *Decided:* own census probe (`tests/control/deploy_census.gd`) rather than manoeuvre's fight_census (random arenas deal
   twins, R34.15; it has no stuck count) or traffic's jam census (not on main).
2. **D2** `make orders-probe` arms `main:` v `deploy_off:--deploy-step=off` on the shipped hash + shots (arrival, +5 s).
3. **D3** tight packing (bar filed first). 4. **D4** shuffle trace. 5. **D5** crossing drives. 6. Stretch: halt markers.
