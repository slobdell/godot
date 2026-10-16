# Stream: manoeuvre (a vehicle pinned on a squadmate that never moves goes round or settles instead of looping; wheeled turret vehicles turn their hull to his facing AND settle)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 28 direction* (his call 2: turn
> the whole vehicle), `_agents/judging.md` (R31.8: no early stop on guard lines), `_agents/workstreams.md` **Round 32**
> (C32.2, C32.5, C32.8) and *Round 31* (C31.4, R31.1, R31.2, R31.5), `_agents/roadmap.md` *Round 32 candidates*, and your
> round-31 brief `streams/archive/round31/manoeuvre.md` (CP-H's bar and tables, the seed-31 trace, M1b(2)'s two attempts;
> tables under `references/round31/manoeuvre/`). **You own:** in `game/ai/movement.gd` the body of `drive()`, `_nose_stop`,
> `unstick`, `_pressing_escape`, H1 (`unstickback`), the k-turn / planned-reverse / circle block's EXECUTOR (`kturn_on`
> through `_look_stop`, `_kturn_start_leg`, `_planned_reverse`), NOT its plan source (the planner's seam, R31.2);
> `game/ai/manoeuvre*.gd`, `game/ai/clothoid.gd`, `game/ai/wall_contact.gd`; in `order_controller.gd` the face-at-rest path;
> `tests/test_manoeuvre*.gd`, `tests/test_kturn*.gd`, `tests/manoeuvre/**`, `tests/ai_scenarios/scenario_manoeuvre*.gd`,
> `mk/manoeuvre.mk`. **Granted:** the two aim-lead lines in `gunnery.gd`; `TankBrain._order_move`'s decline for wheeled
> turret hulls under `turnhull` (C31.8). **The C++ (C31.2):** the drive, unstick, the k-turn executor and gunnery's leads have
> C++ twins; send native each settled diff before its commit. **Keep counters off `Movement` statics** (round 31: one
> broke the twin; use `ManoeuvreCensus`). **Model:** Opus.

## The lead's direction

Round 28, call 2: turn the whole vehicle to his drawn facing (`game_design.md`). Round 31 shipped what he asked for a
wedged hull: it backs out instead of grinding. The known issue he was told about: **when the squadmate in the way never
moves, the pinned vehicle loops (ask, back 2–3 m, drive back in, about every 21 s) instead of going round.** He may see it.

What he will notice: a vehicle stuck behind a squadmate that won't budge drives round it or stops short and reports,
instead of nudging back and forth; a wheeled IFV or gang tank told to face a direction turns its hull there and then sits
still.

## Where things stand (main at the round-32 docs commit; inherits `e66b41f1`'s green check: builder0 exited 0, 2657/0)

- **CP-H is ON** (H1 `unstickback`, H2 `kturnarc`, H3 `realspeed` + brains' `realslow`): pinned crew-s at rest 3106 → 333,
  stuck 6578 → 3737. R31.5: hull pins get ask → straight reverse ≤ 3 m by the sweep → stand and report; pins with no hull
  take round 29's escape bit for bit.
- **The H1 loop (Terminus seed 31's last leg, shipped CP-H):** Green_S0_4 ends 9.1 m short touching Green_S0_2; asks 29,
  backs 29, all hull pins, refused 0. The friend's "pinned" ask never moves Green_S0_2. Clip:
  `~/projects/clips/round31/manoeuvre_rig_wedge_today_v_shipped_seed31_25c7421b.mp4`.
- **CP-P1 is ON:** hulls ≥ 10 m take the planner's legs (PlannerExecutor, R31.2); `last_refusal` and your handover
  counters `esc_after_refusal`, `refusal_then_free` (on ManoeuvreCensus) read live now.
- **M1b(2) PARKED** (attempt 2 `25ef8f7e`, the 'sector' lift): the hulls DO turn (wheeled turret at rest: move 46.5 → 2.5°,
  attack-move 45.0 → 3.8°; gang_ifv 37 → 62 % within 15°), but crews still moving at 75 s under attack-move +13 v a bound of
  11.2, and Terminus mixed arrivals 293 → 285, where the "misses" COMPLETED at slots the element re-seated 7–14 m off.
  facekeep refusals 11 997 in the new arm.
- Your round-31 branch is `round31/manoeuvre` (kept, not merged).

## Backlog (in order)

1. **H1b, the ask that never frees (C32.2).** Behind `--nav-off=h1b` (opt-in per R31.1 until judged). After N failed asks
   on the SAME blocker (pre-register N and what "failed" means: e.g. the blocker's real displacement < 0.5 m between asks),
   re-path round it (a temporary obstacle for that hull's route) or complete short and report; never re-drive into it.
   Test first: seed 31's last leg as a scenario that fails today. Bar to the orchestrator before numbers: seed 31 loops 0;
   CP-H's hull-rest pinned/stuck rows and nav-terminus-drive's PINNED/STUCK rows not worse (base + 1.645 se); Terminus
   arrivals (rigs and mixed apart) not down; fights within 1.645 se; R31.5's terrain fallback and `test_nav_wall_contact`
   unchanged; the whole suite on native's pair tree. Ships ON as a pair.
2. **M1b(3), turn the hull, settled (C32.5).** Before any number: agree with brains, in writing through the orchestrator,
   (a) whether an arrivals line counts "completed at a re-seated slot" as arrived (brains owns the re-seat), and (b)
   whether facekeep changes for gang hulls. The orchestrator records it as a ruling. Then solve the attack-move settle (the
   moving-at-75-s line) with attempt 2's turn kept; one bar, fresh seeds, one hull-rest arm per remote call.
3. **Test splits (C32.8):** after native's four, your files over ~60 s in `tests/shard_times.txt` (`make test-times` first).
4. **Stretch:** the C++ parity of anything you ship goes to native; a clip of seed 31 before/after H1b for him
   (`make manoeuvre-pin-clip`).

## How to verify

`make quick-remote` to iterate; `make remote T=check` on the pair tree with the switch ON before any series (C31.1), only
for hashes you name. `make manoeuvre-hull-rest` (one arm a call), `manoeuvre-fights`, `manoeuvre-census`,
`nav-terminus-drive` + `pinned_table.py`, `bridge-pooled`, `native-verify-scenarios`, `scenario_cp2`,
`test_tactics_mixed_legs`, `test_nav_wall_contact`. Long remote runs under `systemd-run --user`. Every number: commit,
machine, workload, n, its table row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; the planner's `game/ai/planner/**` and plan source; brains'
`_track_progress`, `_update_phase`, `_approach_gate`, the re-seat, elements, `game/tactics/**`, `tank_brain.gd` beyond the
granted decline, `gunnery.gd` beyond the two lead lines; native's `native/**`; `game/tank/**`; `game/control/**`;
`tests/baselines/**`; `tools/judge/**`. `origin` holds an old `stream/manoeuvre`: don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n and its row; bars to
the orchestrator before numbers; green hashes named)_

### Report (2026-10-16, in progress)

Working on item 1 (H1b). Nothing judged yet; no hash named green yet on this branch.

### H1b bar (DRAFT for the orchestrator, filed before any series number; seeds proposed, the orchestrator confirms)

- **Candidate:** `--nav-off=h1b` (H1B_DEFAULT false; naming it turns H1b ON) on ONE tree (the hash my pre-series full
  check names, with the switch flipped ON for C31.1's whole-suite check). **Base:** the same tree without the name.
  Both arms on the GDScript path (`--brains-off=native`; the CP-H runner's refusal rule), every run printing its flags.
- **Pre-registered:** N = `H1B_ASKS` = 2; "failed" = the escape fires again on the same friend for the same goal
  (within NEW_GOAL_JUMP) with that friend's flat position moved < `H1B_MOVED_M` 0.5 m (net) since the previous fire. A
  **loop** = a fire that records the second (or a later) failed ask and that H1b did not break (the third fire on
  an unmoved friend onward; base loops = fires − 2) (`ManoeuvreCensus.h1b_loops`, counted in BOTH
  arms). Settle short only with route left <= 12 m and a goal not sliding; farther loops are counted (`far`), not acted on.
- **Fresh seeds (proposed; unclaimed in workstreams.md as of main `3fdcc1ea`):** Terminus drive + census 300–312 (13),
  hull-rest 313–318 (4 factions × 6 tasks × 6 = 144 an arm, one arm per remote call), fights 320–343 (24).
- **Pass lines, every guard line run to completion and read once on its fixed 1.645 se line (R31.8):**
  (1) Terminus rigs seed 31 (the pass case, n = 1, deterministic): loops 0 in the H1b arm, Green_S0_4's last leg ends
  still (no ask/back after the settle); base's loop count quoted beside it.
  (2) hull-rest pinned crew-seconds and stuck crew-seconds (CP-H's row 67, ≤ 10 m hulls; rigs reported apart):
  ≤ base + 1.645 se paired, n 144.
  (3) nav-terminus-drive PINNED and STUCK rows (`pinned_table.py`), per squad, 13 seeds: ≤ base + 1.645 se.
  (4) Terminus arrivals, rigs and mixed apart (rows 73, 75): mean paired ≥ base − 1.645 se, 13 seeds, no early stop.
  (5) fights, 24 seeds (rows 69–71): kills, deaths, hit rate within 1.645 se.
  (6) R31.5's terrain fallback unchanged: `test_nav_wall_contact`, `test_control_queued_task` (traffic's C32.6 pin) and
  `test_manoeuvre_escape` green; `fires_wall` / `fallback` reported per arm (H1b's hook never sees a no-hull pin).
  (7) The whole suite green on native's pair tree with H1B_DEFAULT flipped ON (C31.1), before the series.
- **REPORTED:** settles, short_m per settle (what he would see: how far short a crew stops), failed asks, `far` (the
  re-path case's size: if it is not small, re-pathing round the friend is the next cut), loops in both arms, the escape's
  arms. Native: H1b's state (`_h1b_*`) and the repair write mirrored in the pair (R32.2).
- **Partial:** none; one cut. If a line misses: the worst run traced, H1b parked with the trace, no re-tuning on these
  seeds.

### Measurements (each with commit, machine, workload, n)

- H1b unit stage, builder0, working tree just before `373de208` (without the loop count), `test_manoeuvre_h1b`
  (deterministic, n = 1 an arm): War Rig sent to a slot a parked squadmate sits on (18 m behind, goal 3 m inside its
  hull). Base: 13 fires in 70 s (every ~5.3 s), ends `blocked`, 279 full-throttle ticks in the last 20 s. H1b: fires 3
  (2.1, 7.4, 12.6 s), settles at 13.7 s 11.0 m short, 0.00 m moved and 0 pressing ticks after. IFV 11 m behind a
  parked squadmate: 0 fires in both arms (avoidance holds it at `blocked`), so that case is a no-op guard.
- **Seed 31 does NOT loop on today's tree** (builder0, `7a9b17e4`, Terminus rigs seed 31, GDScript path, n = 1 an arm,
  `make manoeuvre-h1b-drive`): base and H1b byte-identical, 16/16 arrive, 1 hull fire, 1 ask, 0 backs, loops 0. Round
  31's loop (asks 29) was measured on `130a069b`, before CP-P1's planner legs; the rigs take planner legs now
  (`refusal_then_free` 9). Bar line (1) has no case on this seed: sent to the orchestrator with a proposal, and a hunt
  on diagnostic seeds 1–16 (rigs + mixed) is running.
- **The loop hunt (the orchestrator agreed both branches, 2026-10-16):** diagnostic seeds only (never 300–343). Base
  arm first, then the H1b arm only where base loops. Workloads: the Terminus drive seeds 1–16 rigs + mixed
  (`manoeuvre-h1b-drive`); fights seeds 1–8 (`manoeuvre-cph CPH_ARM=off CPH_STAGE=fights`, light lane); hull-rest
  seeds 1–4 (`CPH_STAGE=hull`, its squadmate-pin rows). Then the named seeds go to the orchestrator, who amends line
  (1) to "loops 0 in the H1b arm on every named hunt seed where base loops". If no seed loops anywhere, H1b ships
  as a guard only if every guard line passes.
- **Hunt, fights** (builder0 light lane, `48657f07`, showmatch 180 s, GDScript path, n = 1 a seed): with H1b off, loops
  on seed 4 (Terminus, 1 loop, 5 failed asks) and seed 6 (Sumps, 3 loops); seeds 1–3 and 5–8 have 0. With H1b on
  (seeds 4–6): seed 6 loops 3 → 0, 1 settle 7.7 m short; seed 4 loops 1 → 1, and it is a `far` (route left > 12 m or
  a sliding goal: the re-path case); seed 5 unchanged. Kills/deaths identical in each pair (49/49, 44/45, 46/46).
- **Hunt, Terminus drive** (builder0, `48657f07`, seeds 1–16 a squad, GDScript path, n = 1 a seed; `h1b_table.py`):
  base loops mixed 105 (12 of 16 seeds, ≤ 18 a run), rigs 114 (11 of 16, ≤ 27). H1b: settles 3 + 3, and each settled
  seed reads 0 loops (mixed 7, 13; rigs 9, 10, 16); but 76 + 70 loops are `far` and unchanged. Arrivals mixed 353 → 355,
  rigs 211 → 212 of 384 / 256. **So the settle reaches ~30 % of today's loops; the far loops are the problem.** Tracing
  them (`H1B_FAR` rows: route left, goal slide, gap, the blocker's phase) on seeds 3–6 at `9a00f57e`.
- **The far-loop trace** (LAPTOP, `08e6d44c`, H1b arm, Terminus seeds 3–6 rigs + mixed, n = 1 a seed,
  `tests/manoeuvre/h1b_far.py`). Loop counts agree with builder0's hunt on the same seeds (mixed 5: 13 v 13; rigs 3: 26
  v 27). Result: 62 far loops from 6 pairs. 50 have a PARKED blocker (arrived, its route left 0) and 12 (rigs) a blocker
  itself blocked by a third. MUTUAL (refused both ways): 0. Yielding at the fire: 0. The pinned hull has 22 / 29 / 37 m
  of route left (p10/50/90), 6–14 m centre to centre behind a SAME-SQUAD crew parked at its own slot. Asks refused 62/62,
  and _negotiate names the parked one in 50/62, but it has no validated yield spot. Traffic's back-off draft would need
  11 / 16 / 20 m of reverse, while the straight room back is ≤ 3 m (met 0/62). **Proposed to the orchestrator:** (A) a
  parked same-squad friend gives way FORWARD, or (B) SWAP SEATS (my lean). Either is not my code; my part is the
  detection hook. H1b's settle stands for the near-goal case, judged as filed with `far` reported.
- **quick-remote GREEN at `e8e20ca9`** (builder0, `>> remote: make quick … exited 0`, 59 passed 0 failed, 11 test files the
  diff selects + lint of 138 scripts + combat-smoke). `test_manoeuvre_h1b` 60.3 s, `test_manoeuvre_h1b_guard` 40.2 s.
- `test_manoeuvre_h1b` at `373de208` took 351 s on builder0; at `7a9b17e4` 162 s (40 s runs, base arms shared).
- **Environment finding, not H1b:** `make remote T='test FILTER=test_manoeuvre_'` in this worktree's FRESH builder0
  folder ran with no `native/bin` (plain `test` does not build it), so the C++ planner was absent and
  `test_manoeuvre_behind::test_the_war_rig_faces_behind_in_a_planned_turn` failed (drift 25.3 m, legs 2). It passed in
  `e66b41f1`'s check. Use `quick-remote` / `check` (they build native first) for any run that touches hulls ≥ 10 m.

### M1b(3): C32.5 RULED as R32.3 (2026-10-16, main workstreams.md)

- (a) "Arrived" = completed within ARRIVED_M of the crew's element seat AT COMPLETION (`Element.seats`, what
  settle_probe's `off_slot_m` reads), not a stale `to`. Every arm also reports arrivals against the original slot,
  `reseats` and `reseats_after_arrival`. Re-seats > base + 1.645 se is a FAIL line.
- (b) facekeep unchanged for gang hulls.
- (c) Brains' answer on heading: the re-seat reads it through the SHAPE. An attack-move with no drawn facing lays its
  halt along the element's heading, which is the members' averaged hull forward (`ElementSituation.build` ~70–76 →
  `ElementPlan.build` default heading :146 → `_halt` ~1669). That heading is read once, on the arrival plan; a drawn
  facing replaces it (~668–672). Also element_plan.gd ~678 (a plain move forming up within 2 m) and drills.gd ~387. So
  a wheeled hull turning BEFORE the element arrives moves every seat, and none after arrival. Pinned by brains'
  `tests/test_tactics_reseat_heading.gd` (stream/brains `cbddb940`).
- **Relayed from brains (2026-10-16):** seats DRIFT with no gate involved (v5's rows, Sumps s16 t8: goal_moves drift 22 in
  the off arm, never all in). Drift means the same anchor and seat index with the seat moved > 1 m, so the formation
  SHAPE is turning or re-laying on its anchor (the plan heading or the arrived flag flipping). Brains' `--drift-trace` is
  running on builder0. **Hold M1b(3)'s design until the orchestrator relays it**: one fix (the halt heading latched per
  arrival) may serve both streams, and if that fix lands in brains' code, M1b(3) shrinks to consuming it.
- **Brains' drift trace (relayed 2026-10-16) REFUTES the halt-heading idea for Sumps s17 t11:** across Green_S_3's 67
  drift lines the heading, arrived flag, formation, anchor and seat index stay CONSTANT; only the seat's POINT flips
  between (-0.2, -51.1) and (1.7, -40.9). Cause: `Element.ground` → `SlotGround.standable_from` picks the side a pushed
  (unstandable) slot lands on, memoised by the element CENTRE's 5 m cell, so jostling moves the centre across a cell
  edge and the seat jumps 10 m. Brains' fix (lab `20ec9c31`): latch each seat's grounding while its asked-for point
  holds within 0.5 m (`--ground-latch=off` = control). **For M1b(3): one `--drift-trace` run on the attack-move 75-s
  movers before any design** (are they chasing a jumping seat?); the flag is in brains' lab tree, so ask brains
  (godot-brains-38) when M1b(3) starts. H1b's far-loop trace comes first.
- **Working hypothesis to TRACE before designing (now doubtful, see above):** attempt 2's hulls turned mid-approach, swung the halt and re-seated
  the element (Terminus mixed misses), and perhaps kept the attack-move crews moving at 75 s. The bar is filed before
  numbers, after H1b.

### C32.10 (ruled 2026-10-16): SWAP SEATS for the far loop

The owner is BRAINS: the element's seats and the two Movement goals, behind one seam (shape `Element.swap_seats(a, b) -> bool`,
refused when a seat is pinned by a drawn facing or a task role). Player squads are elements too. **Mine:** the detection
hook (H1b's failed-ask count on a PARKED same-squad friend whose slot is nearer than mine) calling the seam, plus the
stage test. The signature is agreed with brains through the orchestrator. Its own bar comes after H1b. The 12
third-hull rig cases are reported, not designed for. **H1b is judged as filed (`far` reported) and ships if it passes.**

**The seam as recorded on main (brains' final version):** `Elements.of_match(m).swap_seats(asker, parked) -> String`
("" = taken, else the reason). It trades both crews' last-issued orders inside the call (the same tick) and sets
`_swap` so later plans keep it. Refusals: not_same_element, unseated, leader, kept, task_role, drill, role, deck,
budget, standing. A drawn facing is NOT a refusal. Brains codes it after B3b-2c's verdict.
**My hook is built on `lab/manoeuvre-swap` `367ab66c` (not run yet):** `--nav-off=h1bswap` OPT-IN. It sits inside H1b's ON
path at the second failed ask, asked only of a PARKED friend whose own goal is nearer me than my route left. Taken → the
escape holds in ESC_SWAP until my goal jumps (cap 0.5 s); refused → H1b as before. A stub ("no_seam") until the
method exists; `Movement.swap_seam_override` plays the seam in `tests/test_manoeuvre_h1b_swap.gd` (hook off / refused /
taken). Kept off `stream/manoeuvre` so H1b's checked tree stays H1b only.

**H1b bar line (1), amended on main before numbers:** on the named hunt seeds (Terminus mixed 4, 5, 6, 7, 9, 10, 11,
13, 14, 16; rigs 1, 2, 3, 4, 6, 9, 10, 14, 15, 16; fights 4, 6) AND on the fresh Terminus seeds 300–312: H1b-arm
loops − far = 0 and far ≤ base loops; far reported per seed on both sets.

### Plan (ordered)

1. **H1b** (C32.2): unit test first (`tests/test_manoeuvre_h1b.gd`: a rig / IFV sent to a slot a parked squadmate sits
   on; base loops, H1b settles), then seed 31's last leg as the pass case, then the bar to the orchestrator, then the
   series, then native's twin and a ship pair.
2. **M1b(3)** (C32.5): the written agreement with brains through the orchestrator first; then the attack-move settle.
3. **Test splits** (C32.8): `make test-times`, then my files over ~60 s.
4. Stretch: the seed-31 clip before/after H1b.

### Decisions (one line each, reversible)

- **H1b's "failed ask"**: the escape fires again on the SAME friend for the SAME goal (within NEW_GOAL_JUMP) and that
  friend's flat position moved < 0.5 m (net) since the previous fire. **N = 2** (H1b acts at the third fire): one retry
  covers a friend that was busy (yielding to another, holding at a mouth) for ~20 s; the loop it replaces ran 29 times.
- **H1b's settle uses the repair channel** (`_repair_for` / `_repair_to` = where the hull stands): the brain already
  completes an order on `Movement.repaired_arrival` (round 11), so no new completion path and no edit to brains' code.
  Only when the route left is <= `REPAIR_MAX_M` (12 m, the repair's own ceiling) and the goal is not sliding (a station
  riding its anchor would be stranded). Farther than that is the re-path case, counted (`h1b_far`) before it is built.
- **H1b never touches a terrain pin** (its hook runs only when a friend's hull pins it; R31.5's no-hull pins still take
  round 29's escape before it). `test_control_queued_task` (Green_Alpha_3 at (-25.7, 7.3), foundry; traffic's C32.6
  diagnosis b71fb9b0: an escape case, on the mesh) is kept as a pass line in H1b's bar.
- **R32.2 (the orchestrator's ruling, 2026-10-16):** H1b's hook may write `_repair_for` / `_repair_to`, with no edit to
  brains' functions or the fields' meaning. The native mirror of that write rides in H1b's pair, and every settled H1b
  diff goes to native before its commit (C31.2).
- **Native on H1b (2026-10-16): NO C++ mirror needed.** The native unstick reaches the escape only through the
  `_escape_begin` callback, so the early return behaves the same in both arms. What H1b reads and writes (`_goal`,
  `_remaining`, `_goal_velocity`, `_repair_for`, `_repair_to`) is synced around every callback, and `_h1b_*` stay GDScript.
  Native's two conditions: keep `native_stale |= STALE_ALL` in `_h1b_settle`, and tell native FIRST if `_h1b_gives_up`
  ever moves out of `_escape_begin`. Native adds `test_native_h1b` on `_parked(true, "gang_tank", 18.0, -3.0)`.
- **Native's pair proof is GREEN, with no C++ change** (scratch/h1b-on `f29e3c87` = stream/native `233cbde4` + `373de208` +
  H1B_DEFAULT true; builder0 light lane, `make native test FILTER=native_h1b` exited 0). `test_native_h1b` on the
  parked-squadmate stage twins the whole execute step, GDScript v native live v native owned: 1200 native executes,
  0 handed back, 3 fires, 2 failed asks, 1 settle, 0 mismatches. Native cuts the ON pair tree for C31.1 when I name a
  green hash.
- **Counters on `ManoeuvreCensus`** (`h1b_report()`), not Movement statics; `escape_arms()` unchanged (its off test
  compares the whole dict).

