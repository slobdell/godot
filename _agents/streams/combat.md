# Stream: combat (the rigs yaw through walls: the plant predicate, then the constraint back on; ORBIT reads hull length)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*), [workstreams.md](../workstreams.md) (*Round 10: the eight streams*, contracts **R5**, **R6**,
> checkpoints **CP3**, **CP4**; *What reads `hull_size`*), [balance.md](../balance.md), and your round-9 brief
> [archive/round9/combat.md](archive/round9/combat.md) — its "ROUND 10 STARTS HERE" list (the predicate, the ordering,
> diagonal spacing, the artillery scenario, gangs-vs-law, ORBIT) is the backlog below, in its order.
>
> **You own** `game/units/`, `game/combat/`, `game/match/`, `game/tank/` except `tank_motion.gd`,
> `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`,
> `_agents/balance.md`. **Carve-outs this round (you review at merge):** arena holds `SLOT_X`, `SPAWN_ROWS`,
> `SPAWN_ROW_SPACING` in `match.gd`; feel holds `turret_mount` (R5: a new optional key per profile and the three-axis
> write in `Tank._apply_hull_size`) and the `hull_size`/`muzzle_height` VALUES of `tank` and `burner` (R6).

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> You alreayd mentioned that the truck rigs had yaw problems. Units are still driving into walls.

Round 8's words behind it: the semi "yawing in place" through scenery. The plant resolves a hull's position against
collision and not its rotation; the round-9 constraint (`Tank._fitting_forward`, `yaw_fit_enabled`) fixes 74 % of the
illegal yaw in a corridor (44.0° → 11.6°, footprint 12.1 → 6.1 m at the corrected two-arm table) and, on, freezes four
of five squads at spawn. It shipped OFF. **This round it comes back on or the reason it cannot is a mechanism, not a
correlation.**

## Where things stand

- **The refusal ranking killed the diagonal-spacing story** (your table, laptop, `DRIVE_TRACE` on the five off-slot
  crews of `test_five_squads_ordered_in_quick_succession`): `Green_Charlie_3` at 3.19 m across refused 1135
  CONTINUOUS ticks; `Green_Charlie_1` at 0.06 m refused 1260; `Green_Alpha_4` seated after 128 at a tight 0.26 m, and
  what sets it apart is that Alpha was ordered FIRST. The across gap predicts nothing; the counter never resets, so
  this is a freeze, not a stall. `Green_Echo_1` produced zero traced ticks (a gap in the data, not a row). Repro:
  `TUNE=match.yaw_fit=1 DRIVE_TRACE=<crew> make test FILTER=ai_player_orders`.
- **The tune plumbing is fixed** (`_ensure_env_tuning`, point-of-use readers, the two-arm load-order test at
  `d6daa3b3`: every knob's test asserts the PREDICATE moved, lesson 195). The world-only mask arm (`match.yaw_world`)
  measured a frozen hull (offered 30, applied 30, refused 30, swept 0.0°) and moved a corridor with no vehicles in
  it: two APIs, not one mask (lesson 201's shape). If the mask question is asked again it is `test_move` in both arms
  with only the collider set swapped, "the corridor must not move" as the arm proof.
- **The settle tick landed** (`Tank.place()`, one declared baseline move); `SPAWN_LIFT_M` 0.0; the disc sites behind
  `match.hull_disc` (disc default until the series); the suppression assertion; the engine-deck columns.
- **Two scenarios are yours:** `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` is red on main because the
  scout's ORBIT radius is tuned to a hull length that no longer exists (scale's arm: tank 8.62 → 3.60 m took deck hits
  0 → 22 of 43); `scenario_cp2::test_artillery_stays_dug_in_on_a_moving_target` was passing on a neighbour's leaked
  navigation state and fails in 0.6 s once drained (metrics' four-run table in
  [archive/round9/metrics.md](archive/round9/metrics.md)). The count baseline is `41,3,3,0`; the orchestrator
  re-records with your REASON.
- **nav is building a wall-contact instrument** (its item 1) and a Terminus drive test (its item 2). A hull ROTATING
  through a wall in that test is your row; a hull DRIVEN into one is nav's. Expect its log; ask for a getter if the
  plant does not expose its collision report and add it (yours).
- **feel writes into your files under two carve-outs** (R5 `turret_mount`, R6 the bus box). Review at merge for the
  mechanism (the write is three axes, default preserves today's pose; the box change is CP3 and moves the baseline).

## Backlog (in order)

1. **The predicate.** Why does `_fitting_forward` accept none of three candidate yaws (1.0/0.6/0.3 of the wanted
   step) for over a thousand consecutive ticks on a hull that is clear on every axis anyone measured? Instrument
   what each candidate's `_penetration` returns against WHICH collider, per tick, on `Charlie_3`, and on the seating
   `Alpha_4` for contrast. Hypotheses to rank before you look, with their signatures: (a) the "current" penetration
   is already non-zero against a squadmate and every candidate compares worse by a hair (dominance, your own
   correction); (b) `test_move` answers a boolean and two touching hulls saturate it; (c) the candidate transforms are
   built from a stale basis (the settle tick's `state_for`); (d) the yaw wanted is toward the goal but the refusal
   compares against the world layer where a kerb container sits. The answer is a mechanism with the tick it happens
   on. Constraint OFF throughout.
2. **The ordering.** five_squads with the squads ordered in the other four orders: does the seating squad follow the
   order or the geometry? One table.
3. **The fix the predicate implies**, as an arm with both claims measured on the same pair: the slots (five_squads, 0
   of 30 off) AND the corridor (44.0° → 11.6°, 12.1 → 6.1 m, the residual ≤ 1.8 m, giveups) AND nav's wedged rig
   (offered/applied/refused, never a freeze). Diagonal-derived spacing is a CANDIDATE with the table beside it (squad
   is deriving the pitch from the turning envelope this round and arena the spawn grid: after both land, re-run
   five_squads with the constraint on before concluding anything about the predicate). **CP4:** the constraint's
   default flips ON only when all three pass on one build; it moves the baseline; merged alone.
4. **ORBIT radius reads hull length.** The scout's orbit against a target reads `hull_size[2]` (or the box's reach
   along the bearing via `hull_reach_along`), the engine-deck scenario goes green on the resized tank, the REASON is
   written for the count re-record.
5. **The artillery scenario, honestly.** Reproduce with the drain; why does the artillery leave its dug-in position
   on a moving target once the map is clean? Fix the behaviour or re-specify with the reason.
6. **The gangs-vs-law series with `match.hull_disc` as the arm** (stretch; the lead's convergence call deferred it):
   feel's matrix as the before (pit 20 %, yard 50 %), per cell, never pooled, the null pre-registered as evidence
   AGAINST the disc being the cause; the box becomes default only on a result no worse on every cell.
7. **Stretch:** `Units.stat()`'s `has()` guard (C1); A2's verdict once metrics' cusp split is read; the duel's
   hide/peek regression named.

## How to verify

- `make check` green (`make remote T=check`); `make ai-scenarios` with the count beside the hash;
  `make test FILTER=ai_player_orders`, `FILTER=tank_yaw_fit`, `FILTER=nav_face_recovery` (nav's, run it: the wedged
  rig is your falsifier too).
- `make skirmish ARENA=terminus` with War Rigs: do they turn at a corner without the trailer passing through the
  block? Frames at his pose.
- Every number: commit, machine, sample size, the arm proven applied; every baseline move pre-registered with one
  cause and merged alone.

## Don't touch

`game/ai/**`, `game/tank/tank_motion.gd` (nav's: send the log and a failing test), `game/tactics/**` (squad's),
`arenas/`, `game/arena/` and the three spawn constants (arena's), `game/theme/**`, the `turret_mount` values and the
`tank`/`burner` boxes (feel's this round; review, do not set).

## Waiting on the lead

Nothing blocks. Balance is deferred by him; the series (item 6) reports, it does not tune.

## Research addendum (brief 2, 2026-09-20 evening; rows B2, B3, B9 in `research_catalog.md` *Round 10 addendum*)

**The freeze has a candidate mechanism, and it reorders item 1.** The reply names the sequence: formed-up hulls settle
INSIDE each other's collision margins (a non-zero penetration baseline), every candidate yaw compares worse against
the SQUADMATE contact, both hulls refuse, and the deepest contact masks the wall term. Your ranking measured LATERAL
gaps only; nose-to-tail contact was never measured, which is consistent with a 3.19 m-across crew refusing as long as
a 0.06 m one. So item 1's instrument is: per candidate per tick, the identity and depth of the deepest contact
collider, on the refusing crews AND the seating one. Confirmed if the refusers' deepest contact is a squadmate and
Alpha_4's is not. Then the fix family, in this order: (i) a capsule-string / multi-circle hull for the yaw test (its
distance field is monotone in yaw: no OBB discontinuity, no masking); (ii) a turning-envelope reservation before a
rotation, yield by priority (unit id) if denied; (iii) elongated wheeled hulls do not rotate in place at all (yaw
coupled to forward speed), which is what the creep already tries to be. CP4's three bars are unchanged and gain a
fourth: zero runs of more than 3 consecutive refused ticks anywhere in five_squads.

**The series gains two arms (B9):** physical collider (rescaled vs legacy mesh) × AI perception (disc vs box): arm B
(true mesh, box) decides whether perception caused 9/20 → 0/20; arm C (legacy mesh, scaled disc) whether perception
alone suffices. Per cell, never pooled. The aspect-exposure formula (broadside 4.2× head-on for the rig) is the other
candidate: a hull that cannot keep its nose on the threat; `hull_reach_along` already computes the chord.

**Stretch (B3):** the trailer as a second HINGED collider placed analytically from feel's hitch kinematics (no joint
solver; RK2 on the articulation angle; a jackknife lock in reverse), so a shell through a fold misses. Moves the
baseline once; not before the lead asks.

## Research addendum 2 (brief 3, 2026-09-20 late; rows C2, C6, C7, C8)

**The series' design changes (C6).** The one `match.hull_disc` knob flips three sites at once and can only say
"the disc" or "not the disc". Intervene on ONE site at a time with the disc kept in the others: the friendly-fire
line-of-fire site (`match.gd:1383`), the incoming-projectile site (`match.gd:1450`), squad's `incoming_fire.gd:101`
(squad's file; ask for the knob), and the aim point. Then Shapley effects over the subsets if the sites interact.
**Run every arm on the SAME seed list** (common random numbers) and report discordant pairs (McNemar), never pooled
rates: ~32 paired seeds per cell detect a 25-point shift, ~64 size a component; stop a dominated arm early with a
sequential test. Ten unpaired matches per cell (round 9's design) is retired.

**Counterfactual forking (C7) is the instrument that avoids the butterfly:** replay a seed to a checkpoint every
~5 s, fork under each configuration for 1 tick (which predicate flipped: friendly-fire blocked, threat, mode) and for
5 s (net damage from the identical state). Our determinism makes it a match-runner flag (`--fork-at=T` plus a tune).
The pre-registered arm the reply proposes: rescaled bodies, disc kept for spacing, box for line-of-fire AND threat;
its prediction is that this recovers most of the lost win rate. Record the prediction, then run it.

**Two traps to check before believing any cell (C8):** (a) the aim point: after the rescale (and R5's turret mount),
does every weapon aim at the target's hull centre at height, or at its origin? A test. (b) hard thresholds in the
selectors near the disc radius flip modes on a 1 % change; list them beside A2's verdict.

**"Who yields" for the yaw reservation (C2):** the deterministic key nav adopts (emergency brake, clearance slack,
stopping distance, distance to goal, unit id) is the tie-break for B2's turning-envelope reservation too; do not
invent a second one.

## Status

_(the worker keeps this current)_

**Started 2026-09-22 (worker session, `stream/combat` at `2ee65f94`).** Start-of-round check on `2ee65f94` (builder0):
`>> remote: make check exited 0`, 1559 passed, 0 failed, sim-baseline `1ea332e7bc268d2a` unmoved, determinism
`559a415887806e43`.

### ✅ MERGED to main at `4a96829d` (from `6e3cd021`; the orchestrator re-records the scenario count 44,0 on main)

builder0, the check on this exact hash: `>> remote: make check exited 2`, **1604 passed, 0 failed**, sim-baseline
`1ea332e7bc268d2a` **unmoved**, determinism `559a415887806e43`, 17 of 18 targets passed. The one red is
`ai-scenarios-check`, by design: **44 passed, 0 failed, 3 pending** against the file's 41,3, which the orchestrator
re-records on `main` (my record reverted on request). Earlier green points: `d0445bbf` exit 0 (1564/0), start of round
`2ee65f94` exit 0 (1559/0).

### Latest check: `0fe728d6` (main at `f29c5b7c` merged in, + the CP3-review mount fix), builder0

`>> remote: make check exited 2`, **1652 passed, 2 failed**, sim-baseline `11c479c3bec77082` **unmoved**, determinism
`cd43435b56b09acf`. Identical to `main`'s own check at `f29c5b7c` (1651/2, the same two REASON'd reds: squad's
drive-to-slots and combat's parked-friend; the same scenario reds 40,4) plus my one new passing test. So this branch
adds no red. The parked-friend row is being re-read on squad's `c0040ae4` (placement through `Tank.place()`).

### For the lead, in one paragraph

**Why the yaw fix froze your squads, and the fix.** Round 9's rule that stops a hull rotating through a wall also
treated a squadmate as a wall. A long vehicle parked in a row, told to turn round in place, nudged its corner into
its neighbour a few millimetres at a time until the next nudge was over the limit, and then held that exact pose
forever. Every refused turn we traced was against a squadmate; not one was against a building. A building doesn't
move, but a squadmate gets pushed aside, so the rule now only counts buildings. Same build, both measured:

| | squads that formed up (of 5) | units off their slot (of 30) | longest freeze | rig in the wall corridor (turn / footprint) |
|---|---|---|---|---|
| constraint off (what you play today) | 5 | 0 | none | 44.0° / 12.1 m, through the walls |
| constraint on, squadmates count as walls (round 9) | 1 | 12 | 1268 ticks (42 s) | 11.6° / 6.1 m |
| **constraint on, only buildings count (the fix)** | **5** | **0** | **1 tick** | **11.6° / 6.1 m** |

It switches on (CP4) after the bus box (CP3) and squad's new slot pitch, measured again on that tree, so you get it
together with the formation work. Two scenarios were decided by something else: the scout's orbit around the bigger
tank was too slow to beat its turret at any radius (measured here; squad has since rebuilt the orbit, and the scout
now lands 27 of 29 hits on the engine deck), and the artillery was right all along (its scenario tested which frame
the map loaded on; fixed).

### Plan (the brief's order; one-line reasons where the brief left a choice)

1. **Predicate instrument**: `YAW_TRACE` lines per candidate per tick on a `DRIVE_TRACE` crew: the predicate's depth,
   the verdict, and every contact of the same zero-motion query by name, kind (tank/world) and depth. Run on the
   refusing crews (Charlie_3, Charlie_1, Bravo_6) and the seating Alpha_4, constraint ON by tune. Rank (a)–(d) by the
   trace, not before.
2. **Ordering table**: five_squads in the other four orders (a test-local permutation knob, measured, not asserted).
3. **The fix the predicate implies**, measured on slots + corridor + nav's wedged rig on one build; CP4 only if all
   bars (plus B2's "no run > 3 refused ticks") pass. **Sequenced by the orchestrator (2026-09-22):** CP3 (bus box +
   jitter + mount x/z) → squad's pitch → the five_squads re-run with the constraint on, on that tree.
4. ORBIT reads hull length (engine-deck scenario).
5. The artillery scenario, with the drain.
6. Stretch: gangs-vs-law per-site series (C6 paired seeds), `Units.stat()` guard, A2 verdict, duel hide/peek.

### 1. The predicate: ANSWERED, a mechanism with its tick (laptop, `2ee65f94` + the `YAW_TRACE` instrument)

**Repro:** `TUNE=match.yaw_fit=1 DRIVE_TRACE=Green_Charlie_3,Green_Alpha_4,Green_Charlie_1,Green_Bravo_6 make test
FILTER=ai_player_orders` (the constraint selected by tune for the instrument; the default stays OFF). It reproduced
round 9 to the decimal: Alpha 2.9, Bravo 89.5, Charlie 87.6, Delta 86.5, Echo 91.1, 12 of 30 off.

| crew | refused candidates | against | longest refused run | command while refused (ticks) |
|---|---|---|---|---|
| Charlie_3 | 3516 | Charlie_2 only | 1134 | throttle 0, turn −1: 1209 |
| Charlie_1 | 3782 | Charlie_2 (3779), Bravo_6 (3) | 1259 | throttle 0, turn −1: 1290 |
| Bravo_6 | 3742 | Charlie_1 (3741), Bravo_5 (1) | 1112 | throttle 0, turn −1: 1279 |
| **Alpha_4 (seats)** | 476 | Alpha_3, Alpha_5 | **128** | turn +1: 188; **throttle 0.5: 140**; turn −1: 56 |

**Every refused candidate of every traced crew, the seating one included, was refused against a SQUADMATE. The world
never appeared once** (the `Ground` rows are depth 0.0000 and never refuse).

**The mechanism: a ratchet into a fixed point.** `tank` is the tracked dozer, 8.62 × 2.40 m, half-diagonal 4.48 m, in a
6 m row. A pivot in place there needs 8.96 m, and one end of a pivoting hull swings toward each neighbour. Its goal is
behind it, so the driver commands a pure pivot (throttle 0, turn −1). Each accepted small candidate deepens its corner
into the neighbour by up to the slack (5 mm). `move_and_slide` with zero velocity leaves the pair touching. The hull
stops at the one posture where even the smallest candidate costs just over the slack. Charlie_3 from **tick 1880**:
here 0.0000, candidates 1.0 / 0.6 / 0.3 = 0.0177 / 0.0104 / 0.0050 m against Green_Charlie_2, **byte-identical every
tick for 1134 ticks**. Nothing translates the hull, so the state never changes. Alpha_4 escapes because its command is
not a pure pivot (140 ticks of throttle 0.5), and throttle moves it off the contact.

**The four hypotheses, ranked on the trace:**
- **(a) Dominance against a squadmate: CONFIRMED in its corrected form.** The current penetration is ~0 (not
  non-zero), and every candidate is worse against the squadmate by the ratchet's margin.
- **(b) Boolean saturation: REFUTED.** The depths are continuous and ordered by fraction (0.0177 > 0.0104 > 0.0050).
- **(c) Stale basis: REFUTED.** The candidate yaws are exact fractions of a constant 2.66° step off the live heading.
- **(d) A kerb container on the world layer: REFUTED.** Zero world refusals.
- **Research B2's prediction** that the refusers' deepest contact is a squadmate and Alpha_4's is not: half right.
  Alpha_4's is also a squadmate; what separates it is the command (throttle), not the contact.

**What the mechanism implies for item 3:** a wall does not yield and a squadmate does (the slide depenetrates the
pair). Refusing a yaw because a VEHICLE is in the way is the defect. The arm is `match.yaw_world`, rebuilt as a true
mask arm: the same `test_move`, with the body's mask narrowed to the world layer for the call. Round 9's `collide_shape`
version is retired; its numbers are not carried forward. Tests in `test_tank_yaw_fit.gd`: a positive control (vehicles
in the mask → the pivot freezes, run > 3) and the treatment (world mask → run ≤ 3 and > 90° turned), plus the wall case
under the world mask.

### 2. The ordering: ONE TABLE, and the answer is "neither alone" (laptop, `2ee65f94` + instrument)

`FIVE_SQUADS_ORDER=<letters> TUNE=match.yaw_fit=1 make test FILTER=five_squads`, n=1 per order (worst gap to its
own slot, m; bold = frozen, beyond the 36 m leash):

| order | Alpha | Bravo | Charlie | Delta | Echo | off of 30 |
|---|---|---|---|---|---|---|
| ABCDE | 2.9 | 5.4 | **88.0** | 4.3 | **89.7** | 8 |
| EDCBA | **89.7** | **87.2** | **88.1** | 9.0 | **90.0** | 14 |
| CABDE | **89.9** | 3.5 | 3.0 | 6.5 | **89.7** | 7 |
| BCDEA | 3.5 | 5.5 | 8.7 | 3.5 | **89.7** | 5 |
| DEABC | 2.9 | **89.5** | **87.6** | **86.5** | **91.1** | 12 |

- **The order does not decide.** The first-ordered squad seated in 3 of 5 (Echo and Delta, ordered first, froze).
- **The geometry does not decide alone either.** Echo, at the +x end of the row, froze in all five orders. Every other
  squad both seated and froze depending on the order.
- **⚠ THE HARNESS IS NOT DETERMINISTIC ENOUGH FOR THIS TABLE, so no row above is evidence about order.** The same
  order and code (ABCDE, vehicles in the mask) ran **12 off** in the arm batch and in item 1's run, and **8 off** in this
  batch. DEABC reproduced the 12-off row to the decimal. `make test` runs Godot WITHOUT `--fixed-fps` (`mk/core.mk:244`),
  so physics steps interleave with idle frames by wall clock, and a loaded laptop (nine agents) changes the simulation.
  Run-to-run noise on identical input (4 frozen squads vs 2) is as large as any difference between orders.
- **What survives:** Echo froze in every row; the first-ordered squad did not reliably seat (3 of 5). "Alpha seats
  because it was ordered first" (round 9's n=1) is **not supported**. The freeze is the predicate plus the pivot command
  (item 1), and item 3 removes the vehicle term instead of tuning an order, so the order question closes with it.
- **Harness note for whoever owns `mk/core.mk` (metrics/orchestrator):** a filtered `make test` is not a repeatable
  measurement of a many-unit test on a loaded machine. Every number here was cross-checked by re-running.

### 3. The fix the predicate implies: the WORLD-ONLY mask, measured (laptop, working tree on `2ee65f94`)

Same build, arms selected by tune and proven applied (`TUNE applied from the environment: …` and the MEASURE line's
`yaw_fit true, world mask true`):

| arm | five_squads off of 30 (worst per squad, m) | longest refused run | nav's wedged rig: yaw / footprint / residual / giveups | nav suite |
|---|---|---|---|---|
| constraint OFF (today's default) | **0** (3.8, 4.3, 10.1, 4.2, 4.3) | 0 | 44.0° / 12.1 m (nav's unconstrained figures) | 8/0 |
| ON, vehicles in the mask (round 9's) | **12** (2.9, 89.5, 87.6, 86.5, 91.1) | **1268** | 11.6° / 6.1 m / 1.27 m / 1 | 8/0 |
| **ON, world mask (the fix)** | **0** (2.9, 5.0, 9.2, 6.2, 3.8); a second run: 0 (4.1, 4.3, 5.4, 5.0, 5.6) | **1** | **11.6° / 6.1 m / 1.27 m / 1** | **8/0** |

- **The arm proof:** the corridor holds no vehicles, and it is byte-identical between the two mask arms (4.99 m of path,
  11.6°, net drift 2.26 m, residual 1.27 m). The arm changed only the collider set.
- **All four CP4 bars pass on one build with the world mask:** slots 0 of 30; corridor 11.6° / 6.1 m, residual
  1.27 ≤ 1.8 m, giveups 1; the wedged rig not frozen; no refused run over 3 ticks (longest 1).
- **Tests** (`FILTER=tank_yaw_fit`: 5 tests, the three new ones included; builder0 check below). The positive control: two squadmates 0.8 m
  either side, vehicles in the mask → the pivot freezes (longest run 82 ticks, 12.6° in 3 s). The treatment: the world
  mask → 128.9°, run 0. The wall case under the world mask: unchanged (36.3°, the rig not inside the crate).
- **The cost, stated:** under the world mask a pivoting hull overlaps its squadmates (the slide separates them), which is
  exactly today's default behaviour with the constraint off. It is not new clipping. Hulls not clipping while they dress
  is squad's slot pitch (this round).
- **CP4 is prepared, not flipped.** The orchestrator's sequence is CP3 (bus box + jitter + mount) → squad's pitch →
  five_squads re-run with the constraint on, on that tree. The flip is two defaults (`yaw_fit_enabled`,
  `yaw_fit_world` → true) in one commit, merged alone, baseline recorded twice.

### 4. ORBIT vs the resized tank: the radius is NOT the mechanism. SUPERSEDED by squad's orbit controller

**Update 2026-09-22 (orchestrator relay):** squad gave ORBIT an orbit controller that holds its radius, keeps the
circled target fresh for 4 s, and starts deck runs inside the 25° cone. The engine-deck scenario passes at 27 deck hits
of 29 (laptop, squad `2ac026af`). That is the behaviour fix the finding below asked squad for. The analysis stays as
the record of why the radius was not the lever. The count is recorded once on `main` by the orchestrator (my
`d0445bbf` record is reverted in `87bc107f`).

Laptop, `2434f50d` + temporary probes in `tank_brain.gd`/`gunnery.gd` (never committed; carve-out granted for the
ORBIT_RADIUS/BREAK lines, unused because the arm did not work). `make ai-scenarios FILTER=engine_deck`, one run per arm:

| arm | x4mw deck / hits / shots | where the scout sits astern | gun error while astern |
|---|---|---|---|
| today (radius 11, break 5, from the centre) | 0 / 13 / 14 | 5.5–7.5 m from the centre (1–3 m off the stern) | 30–90° |
| radius, break, burst range surface-relative (+ half-length − 1.8 = +2.5 m) | 0 / 16 / 16 | ~10 m | 60–120° |
| + the eligibility gate surface-relative (ORBIT ineligible: 47.5 < 50°/s) | 0 / 0 / 0 (the scout declines the fight, like x3m) | n/a | n/a |

**The mechanism (probe, today's arm):** the tank's turret was within 60° of the scout on **236 of 236** ORBIT thinks
(245 of 245 under the radius arm). The orbit never outruns the turret, so the scout bursts only in the cannon's reload
window. Its real orbit is a median **9.1 m/s at 6.6 m from the centre, 33.7°/s about the target** (p90 101°/s). The
brain's eligibility gate assumes 14 m/s ÷ 11 m = 73°/s against the turret's 50°/s. Every fire gate but `aimed` is true
astern (envelope, range, ready); the fixed gun is 30–120° off because the scout is circling, not facing. Its hits come
from 30 m at a 43° bearing and from 3–6 m at ~109° (side-rear): the round-9 DECK_PROBE reading, now explained.

**Why the 3.60 m tank worked (scale's arm, 22 deck hits of 43):** with the stern 1.8 m out, a scout circling ~6–7 m
from the centre is ~4–5 m clear of the hull and can swing onto the stern inside its 5 m turning radius. The 8.62 m
hull's stern is 4.31 m out, so the same circle is 1–3 m off it, and a larger circle is too slow angularly to beat 50°/s.

**REASON as written before squad's fix (kept for the record):** `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` stayed
red on the resized tank. The ORBIT tactic is geometrically marginal against an 8.62 m hull with a 50°/s turret: the
scout's measured orbit rate (33.7°/s) is below the turret's at every radius that clears the hull, and a
surface-relative radius does not change the result (0 deck in both arms). Not a radius constant.

**Request to squad (owner of `tank_brain.gd`), not urgent:** the orbit's steering (a lead point 75° ahead on an 11 m
circle, re-aimed each think, with arrival slowdowns) produces 9.1 m/s and 33.7°/s where the gate assumes 14 m/s and
73°/s. An eligibility gate that reads the MEASURED angular rate, or a true constant-radius pursuit curve, is the
behaviour fix. The option to pick when ORBIT is ineligible (today the scout declines the fight) is a design call.

### 5. The artillery scenario: the artillery is right; the scenario measured nav's tick-1 route (re-specified)

Laptop, `2434f50d` + temporary probes (never committed). `make ai-scenarios` uses `--fixed-fps`, so every row repeats.

| run order | target's first route (its tick 2) | where the target parks | spotter sees it | battery | result |
|---|---|---|---|---|---|
| alone (first in the process) | ready, 7 points | (−32, −41) | yes | BOMBARD to the end, 5 rounds | PASS |
| after any scenario (e.g. `artillery_digs_in`) | **ready=false, 0 points, `regions=[]`** | (−33, −40) | **no, from t≈300** | SHADOW from t≈300, drives off to (−62, 30), 1 round | FAIL |

**Mechanism:** a scripted unit's first route request happens on the scenario's first physics frame. After a previous
scenario, that is the one frame where the drained map has no regions and the new arena's are not yet synced (they are
the next frame). `Movement` keeps the empty "not ready" route and replans only on its 4 s cadence, so the target
drives straight and parks out of the spotter's line of sight. The battery then correctly packs up to re-acquire. It
did nothing wrong in either run. Round 9's "passing on leaked navigation state" had the direction backwards for
today's tree: the FIRST scenario of a process is the one that gets a route on tick 2.

**Re-specified:** the target's goal is (−45, −40), in the spotter's sight on both routes (the claim is "stays dug in on
a moving, spotted target", not "the target parks here"). Laptop: PASS in all three orders (alone, after `digs_in`, the
whole file), 5 rounds each, packed up 0–1 times. The count moves 41,3 → 42,2 (REASON recorded in the baseline).

**Request to nav (via the orchestrator):** `Movement` should retry a route that came back `ready=false` on the next
tick rather than after `REPATH_SECONDS`. The same frame exists in real play (a match's first tick after a scene
reload), and a unit ordered on it drives straight for 4 s.

### 6. The gangs-vs-law series, site by site: PRE-REGISTERED (written before any run)

**Instrument (committed before the run):** `match.hull_disc_<site>` knobs (`lof` = Match's friendly-fire
line-of-fire test, `incoming` = Match's projectile-threat test; `squad_incoming` reserved for squad's `IncomingFire`,
which stays on the whole knob until squad passes the site name). A test proves each knob moves its own site only.
`MATCH_RESULT.controls.tuning` carries the tuning the match READ, and `faction_matrix.py` refuses a run whose matches
did not carry the requested `--tune`. `faction_matrix.py` writes a per-game `games` list; `tools/paired_arms.py` /
`make paired-arms` pairs two arms by (faction, other, seed, colour) and prints pairs, both rates, the discordant
counts b and c, and an exact McNemar p. It never reports a pooled rate alone.

**Design:** `make remote T="disc-site-series ARENA=pit"`, then `ARENA=yard`. gangs vs law, 32 seeds × both colours =
64 games per arm per map, the same seed list in every arm. The control is today's default (the disc at every site).
Treatments: `lof` (the box at the line-of-fire site only), `incoming` (the box at the threat site only), `both`
(research C7's arm: the box for line of fire AND threat, the disc kept for spacing). Per map, per cell, never pooled.
Before on record: feel's matrix, gangs 20 % on pit and 50 % on yard (unpaired, different build: context only).

**Results so far:**

| tree (machine) | map | arm vs control | pairs | gangs: treatment / control | b | c | McNemar p |
|---|---|---|---|---|---|---|---|
| `e7d3ced6`, pre-CP3 8.62 m bus (builder0) | pit | `lof` | 64 | 28% / 20% | 8 | 3 | 0.227 |
| `6e2d9421` **DIRTY** (untracked terrain `.uid`s at launch; `paired_arms` REFUSED it; not quotable) | pit | `lof` | 64 | 22% / 16% | 6 | 2 | 0.289 |
| `6e2d9421` **DIRTY** (the clone: my log files written inside it; not quotable) | pit | `incoming` | 64 | 20% / 16% | 6 | 3 | 0.508 |

**Determinism, measured:** the control at `6e2d9421` run from two builder0 folders (this worktree's and the clone's)
produced the same 64 games, winner for winner, and the `lof` arm reproduced to the same rates. The dirty flags came
from untracked files (terrain's `.uid`s; then my own logs inside the clone), not code. The rule still holds: these
rows may be acted on, not quoted. The clean re-run (logs outside the clone, FRESH control) is running.

The rest of that run was killed by slot.sh's 90-minute limit (one arm ≈ 41 min at 2 jobs). The series restarts on the
post-CP3 tree (the 9.70 m bus, where the parked-friend question lives), one arm per invocation, at 3 jobs.

**The series tree is FROZEN at `6e2d9421`** (post-CP3 bus, before nav's route retry and squad's pair). Every arm must
share the control's commit (`paired_arms` refuses otherwise, even for a docs-only commit), and this branch keeps
merging `main`. So the `lof` arm runs from this worktree's builder0 folder, and the `incoming` and `both` arms run
from a clean clone at the same commit in the scratchpad (`godot-combat-series`, its own builder0 folder, a fresh
control at the same commit; the two controls should be byte-identical games, which doubles as a determinism check).

**Predictions, stated now:**
- C7's prediction for `both`: it recovers most of the rig's lost win rate (the round-8 loss was 9/20 → 0/20).
  Operationally: on each map, b > c for gangs with p < 0.05.
- **The null** (b ≈ c on both maps for every arm) is evidence AGAINST the disc being the cause of 9/20 → 0/20, and gets
  written up as such.
- Positive control: an arm's `controls.tuning` must show its knob in every match (enforced by the tool). A
  McNemar null with the knob proven applied is "no effect detected at n=64", not "not measured".

### Answers given to other streams

- **feel CP3 jitter (2026-09-22):** no objection. five_squads seeds jitter 0.0; `test_tank_place`/`test_spawn_isolation`
  positions move (pre-registered as moved, not regressed). The bus box raises the default hull's half-diagonal at
  five_squads' 6 m pitch, so CP4 is measured after CP3.
- **feel R5 mount (2026-09-22):** no objection to x/z pivot moves with y kept. **C8(a) aim point:** `gunnery.gd:149`
  aims at `target.global_position` (the box centre on the ground), and every aim test is planar
  (`Ballistics.aim_error` zeroes y; shells fly flat), so the aim is the hull centre in plan: not a trap today. Test to
  add: the collider centre equals the origin in x/z for every profile.

### Requests to other streams

- ~~**squad** (`tank_brain.gd`): the ORBIT eligibility gate vs the measured orbit rate (item 4).~~ Done by squad
  (`2ac026af`: an orbit controller, 27 deck hits of 29).
- **squad** (`incoming_fire.gd:137`): pass `"squad_incoming"` as the site to `Units.hull_reach_of` /
  `hull_distance_of` (a one-word change) so the series can switch that site alone. Until then it follows
  `match.hull_disc`.
- **nav** (`movement.gd`): retry a route that came back `ready=false` on the next tick, not after `REPATH_SECONDS`
  (item 5: a unit ordered on the frame the map has no regions drives straight for 4 s).
- **nav**: after CP2, the War Rigs' `plant` wall contacts (8893 of 24463 unit-ticks pre-CP2) re-measured with
  `TUNE=match.yaw_fit=1,match.yaw_world=1`, and the hull-hull count beside it (the accepted trade).
- **metrics/orchestrator** (`mk/core.mk`): `make test` without `--fixed-fps` is not repeatable for many-unit tests on a
  loaded machine (item 2). The orchestrator has taken this.

### Merge notes (shared or other-owned files touched)

- `tests/test_ai_player_orders.gd`: the `FIVE_SQUADS_ORDER` knob (default unchanged) and a refusal MEASURE line.
- `tests/ai_scenarios/scenario_cp2.gd`: the artillery target's goal (−30 → −45, −40), with the reason in its comment.
- `tests/baselines/ai_scenarios_count.txt`: recorded (`d0445bbf`, 42,2 on builder0) and then reverted (`87bc107f`)
  on the orchestrator's instruction: it records the count once on `main` after control → squad → combat. My branch's
  check is therefore red on `ai-scenarios-check` alone, by design, with the REASON in item 5.
- `game/modes/match_runner_mode.gd` (mine): `controls.tuning` in `MATCH_RESULT`; no simulation effect.
- The `game/ai` probes used for items 4 and 5 were never committed.

### What to playtest

Nothing on the default path changes on this branch (the constraint stays OFF until CP4). To see the fix now:
`TUNE=match.yaw_fit=1,match.yaw_world=1 make skirmish ARENA=terminus` and order squads of War Rigs and dozers
around the blocks; compare with `TUNE=match.yaw_fit=1` (round 9's rule), where squads parked in a row can freeze.

### CP3 review (`git diff 4ff45e50 69c681ac -- game/match game/units game/tank`): APPROVED, one defect fixed here

- **`match.gd` jitter:** approved. Derived from the rule `pitch − 2·jitter − hull ≥ HULL_CLEAR_M` for
  `Units.DEFAULT`, asserted by `tests/test_spawn_grid.gd`. The values are X 1.30, **Z 0.15** (the relay said 0.3;
  the code's derivation, (12.0 − 9.70 − 2.0)/2, is the one that counts).
- **`units.gd` bus box and mounts:** approved as carve-out values (the lead's eye, R6; the mounts measured on
  builder0). The bus is now 2.90 × 4.76 × 9.70 m.
- **`tank.gd` turret pose and scale:** approved. The turret's scale is pinned to `TURRET_STANDARD`, so the art
  measurement fix does not move a muzzle, and `turret_pose` keeps y at the muzzle's height.
- **The muzzle-inside-own-hull condition landed as a test:**
  `test_tank_turret_mount.gd::test_no_mount_pushes_the_muzzle_further_out_of_its_own_box` (no mounted unit's muzzle
  sits further past its nose than today's default pose puts it, and none behind its tail). Verified here: 5/5 pass.
- **Defect, fixed on this branch:** `_apply_turret_mount` read the RAW profile, so `TUNE=tank.muzzle_height=…` moved
  `Tank.muzzle_height` but not the pivot rounds leave from (pivot 1.09 m against an expected 1.45 m). The tank now
  passes its own tuned value. Test: `test_combat_hull_geometry::test_a_tuned_muzzle_height_reaches_the_mounted_pivot`
  (red before, green after). No tune means identical values: baseline pre-registered unmoved.

### Where five_squads' hulls start (for CP4's re-run)

Arena's finding: doctrine armies re-lay at tick 0 and never stand on the spawn grid, so its checkerboard fill (turning
envelopes disjoint for the first 28 bare spawns) does not reach five_squads. **Neither does squad's pitch, at spawn:**
`test_ai_player_orders._setup` places the 30 hulls by hand at `x = −90 + 6·i, z = 95`, a 6 m row. The bus's turning
envelope needs 10.42 m (arena's figure), so every hull starts inside its neighbours' envelopes. That start is exactly
the regime item 1 traced: the freeze happened at the spawn row. Squad's pitch governs the arrival slots only. So the
CP4 re-run measures the world-mask fix against a start that is deliberately worst-case, which is the right test of it,
and "hulls clip while pivoting out of a 6 m row" is expected there under the world mask (the accepted trade), not a
regression.

**Decision rule for CP4's re-run, written before it (2026-09-22, with the orchestrator):** the run happens on squad's
merge hash (arrival slots + seating) with CP3's bus; arena's grid is not a prerequisite. Under the world mask a
squadmate cannot refuse a yaw, so the hand-placed 6 m row cannot reproduce item 1's freeze. If five_squads still leaves
units off their slots with the constraint on, I trace it with `YAW_TRACE` first. If the refusals name a squadmate, the
mask arm is not applied (an arm failure, not a result). If they name the world, it's a new mechanism (write it up).
If there are no refusals, it's not the constraint at all. Only if the trace shows the row's geometry itself (hulls
overlapping at placement) does the test's row pitch become the literal to derive from the turning envelope, with a
REASON. The constraint does not stay off because of a hand-placed literal.

### Owed after CP3 (taken 2026-09-22)

- `scenario_fire_discipline::test_a_tank_blocked_by_a_parked_friend_moves_to_clear_the_lane` fails on feel's CP3 tree
  (1 shot, not ≥ 2) with the bigger bus as the parked friend. It is a behaviour claim on the `lof` disc site, not a
  literal. Run it with the plain tree against `match.hull_disc_lof=0`: box passes / disc fails = the disc's
  over-reach (series evidence, and a candidate to flip that site); both fail = the lane search vs a longer friend
  (squad's CLEAR_LANE). The literal `test_autocannon_rounds_fall_short_past_its_range` is feel's derived fix in CP3
  (approved: measure the gap from the target's hull reach).
- **Feel's arm on the CP3 tree (`a138b5f1` + derivations, LAPTOP):** plain PASSES (first shot tick 114, 2 shots, moved
  3.9 m); `match.hull_disc=0` FAILS (first shot 232, 1 shot, roamed 32.1 m). On builder0 the plain run FAILS (first shot
  231, 1 shot). So the box, not the disc, is the arm that roams, and the plain verdict flips by machine. The first
  shot straddles the 6 s bar (180 ticks) by a wide bimodal margin (~114 vs ~231), which reads as two behaviours
  (clear lane found at once vs a re-position), selected by something small: a knife-edge on the 9.7 m bus, not "the
  disc refuses". My hypothesis is not supported by this pair (n=1 per arm, two machines). The discriminator is the
  paired-seed series with `match.hull_disc_lof` on builder0 after CP3, plus a seed sweep of this scenario (the
  first-shot tick per seed per arm), before any reading.

### Next steps

1. When CP3 and squad's pitch are on `main` (the orchestrator messages the hash): merge `main`, re-run five_squads,
   nav's corridor, the wedged rig and the refused-run bar on builder0 with the world mask, then the CP4 commit
   (`yaw_fit_enabled` and `yaw_fit_world` → true), merged alone, baseline recorded twice.
2. After CP2 + nav's drive test: the rigs on Terminus under the world mask (nav's instrument), and frames at his pose.
3. The series: `make remote T="disc-site-series ARENA=pit"`, then `ARENA=yard`; read against the pre-registration.
   The third site (`squad_incoming`, squad's `a8789bea`, arm-proven by `tests/test_ai_incoming_site.gd`) joins as a
   fourth treatment arm (`squad=match.hull_disc_squad_incoming=0`) only after squad's pitch + seating merge reaches
   this branch. Before that the knob would be accepted and never read (round 9's lesson).
4. Stretch: A2's verdict once metrics' cusp split is read; the duel's hide/peek regression.

