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

### Report (2026-10-16 ~14:00 PDT)

**H1b PASSES every line of its bar. Ship hash: `pair/h1b-on 273654e6`** (main 2fc43a47 + `e8e20ca9` + native's twin and
exec_fields rows `2d35b1ec` + H1B_DEFAULT true; builder0 plain check `>> remote: make check exited 0`, 2703 passed,
0 failed, sim-baseline all 13 maps unmoved). The five exec_fields rows ship WITH it. The series ran on
`stream/manoeuvre` with the arms as flags (base `--brains-off=native`, H1b `--nav-off=h1b --brains-off=native`), stage
labels `9c46002a` / `5736bb83` / `f5bf085f`: all carry H1b code `e8e20ca9`, plus only docs, the runner's PINNED/STUCK rows
and R32.7's reader fix. Builder0, GDScript path, every guard read once at completion.

| Line | Set | Reading | Verdict |
|---|---|---|---|
| (1) loops − far = 0, far ≤ base | fresh Terminus 300–312 | mixed 12−12, rigs 101−101; 12 ≤ 12, 101 ≤ 137 | PASS |
| (1) | 20 named Terminus hunt seeds | 0 on every seed; settles mixed 7, 13, 16 and rigs 9, 10, 16 | PASS |
| (1) | named fights 4 / 6 (+5) | s4 1→1 (far 1), s6 3→0 (1 settle), s5 0→0 | PASS |
| (2) hull-rest PINNED ≤ 10 m | 313–318, n 144 | 545 → 366 (−179, se 213.3) | PASS |
| (2) hull-rest STUCK (all hulls) | 313–318 | as filed 3766 → 4206 (+440, se 478.9, bound 4554); fixed reader 2598 → 3233 (+635, se 427.0, bound 3300) | PASS on both |
| (3) Terminus PINNED | 300–312 | rigs 59 → 47, mixed 0 v 0 | PASS |
| (3) Terminus STUCK | 300–312 | NOT READABLE (R32.7): as filed 257 → 380, offline 192 → 121 | — |
| (3) Terminus STUCK, R32.7 re-run | fresh 360–372, fixed reader | rigs 323 v 323, mixed 64 v 64 (diff 0, se 0) | PASS |
| (4) arrivals, paired | 300–312 | mixed 294 v 294; rigs 177 → 179 (mean +0.15, se 0.19) | PASS |
| (4) | 360–372 (reported) | mixed 289 → 290, rigs 164 → 165 | — |
| (5) fights | 320–343, 23 paired (333 timed out in both) | kills 914 v 914, deaths 918 v 918, hit rate 0.717 v 0.717 | PASS |
| (6) R31.5 terrain fallback | pair check | test_nav_wall_contact, test_control_queued_task, test_manoeuvre_escape green | PASS |
| (7) whole suite, switch ON | `273654e6` | exited 0, 2703/0 | PASS |

**Reported:** `far` (the swap's base): Terminus 300–312 mixed 12 / rigs 101; hunt 1–16 mixed 76 / rigs 70; fights 20.
H1b settles 3–4 crews a 13-seed set, 6–11 m short. Hull-rest stuck CREWS rose 76 → 100 with the fixed reader (UP beyond
2 se). In 3 of the 5 worst runs H1b never acted, so it reads as hull-rest's run-to-run variation (no `--fixed-fps`).
**What he will notice:** a vehicle sent to a slot a parked squadmate sits on (or right beside it) stops a few metres
short after two tries, instead of nudging back and forth every ~21 s. The far loops (most of today's: a crew pinned
behind a squadmate parked in the street) are next, as C32.10's seat swap.
**A reader subtlety found on 360–372 (flag, not changed):** in BOTH readers a long no-progress run that ENDS IN PROGRESS is
never counted (`best, run = r[3], 0`). The R32.7 fix counts a run the next goal interrupts, as on rigs 363 Green_S0_1
(68 s, counted in both arms). Whether "pressed 30 s, then got through" is stuck is a definition question for the next bar.

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
- **H1b's ON pair tree (native):** the first cut `pair/h1b-on 5d6d7414` failed LINT (`make check exited 2`): native's
  twin needs ExecuteTwinCase from stream/native's split, and only the one file had been copied. The re-cut is
  `pair/h1b-on fa2d9e31` (= 5d6d7414 + stream/native `981e336b`, tests and brief only), H1B_DEFAULT true; its plain check is
  running on builder0. The series waits for it (C31.1).
  **fa2d9e31's check** (builder0, plain): `>> remote: make check exited 2`, 2701 passed / 2 failed (23 targets passed,
  1 FAILED: test). **sim-baseline: all 13 maps UNMOVED** (determinism `9d66d3a0c59a7936`), so H1b ON moves no dealt map.
  Both reds are native's twin tests: (1) `test_native_exec_state` wants exec_fields rows for my five H1b members (added
  on the pair branch at `2d35b1ec`; **they must ship WITH H1b**, two-way checked); (2) `test_native_wall`'s per-crew split
  fell below its floor because H1b changed which crews meet walls (8 wall ticks in one half v 554, 0 mismatches), fixed
  on stream/native `e9fc7864`. Re-cut `pair/h1b-on 273654e6`; native's twins, then a full re-check, are running.
- **The swap stage's first two runs proved nothing** (lab `367ab66c`, `ab3b18a0`: 0 fires): a sign bug put the rig's
  goal BEHIND it. It was not "drives round on open ground" as first read. Fixed at lab `5c6d17ea`.
- **C32.10 swap stage GREEN on the laptop** (lab `98a29c57` = brains' seam f2cc956d + my hook; `test_manoeuvre_h1b_swap`
  3/3, deterministic n = 1; the seam played by the test). A rig 18 m behind a parked squadmate in a row of three
  (2.0 m gaps), goal 30 m beyond it. Hook off: 6 fires, 4 far loops. Refused: 4 asks all `test_refused`, fire times
  identical to hook off. Taken at 12.6 s: 3 fires, **0 loops**; B ends 4.3 m from A's seat, A 1.0 m from B's old goal.
  Stage lessons: the friend's mover must be bound, and on open ground the friend takes the yield ('yielding', not
  parked), so the stage makes it refuse as all 62 did in the trace.
- **hull-rest faced_move s66 Green_Guns_5 TRACED** (laptop, `fab0d82e`, gangs seed 66, GDScript path; 153–160° off in
  3 runs; squadmate rigs 0.4–13°; two temporary prints, not committed). Not a lost face step. (1) Its one behind
  decision (f 41) was `route` with the facing on the order (goal 29.7 m, past MAX_M). (2) The order completes inside the
  6 m settle radius at 8–11 m/s, and momentum carries it ~10 m past, to (−46, 96). (3) Option HOLD; tank_brain.gd ~2814
  "pushed off the spot" sends `{move_to, reverse: true, arrive 6.0, no facing}` (f 259). (4) It backs on tail first, and a
  wheeled turret hull's face is declined with turnhull off. Fixes: brains' HOLD return honours the facing (reverse only
  within FACING_KEEP_DEG of the nose); mine, the arrival overshoot, measured first in M1b(3).
  **CORRECTED the same day:** it is NOT a roll-past. On its wide arrival curve G5 never came within 11.5 m of the goal,
  yet its order had COMPLETED (option HOLD at f 259) while it was 11–15 m off; the HOLD return then backed it on. An
  arrival watch (lab `492cf7a1`, measurement only) found 0 of 7 driven arrivals rolling past settle + 1 m on that run.
  The trigger is an early completion (element arrival or the repaired path: brains'). For M1b(3), count "move orders
  completed with the hull > settle + 1 m off, by completion path" instead of overshoot.
  **Brains' answer (C32.12 (1), `--order-trace`, builder0 light):** G5's move never COMPLETES. When its ELEMENT arrives
  (centre within ARRIVE_M), the halt gives every crew a faced `hold` at its seat, and a faced hold replaces a move AT
  ONCE (`Element._should_issue`, round 10's rule), wherever the crew is. Squadmates completed at 4.3–6.0 m; none
  repaired. Brains' fix is B11 (HOLD's return drives nose-first, carrying the facing, when the facing is > 60° off the
  nose). **M1b(3)'s metric is therefore:** move orders ENDED (completed OR replaced by an element hold) with the hull
  > settle + 1 m off, by path.
- `test_manoeuvre_h1b` at `373de208` took 351 s on builder0; at `7a9b17e4` 162 s (40 s runs, base arms shared).
- **Environment finding, not H1b (later shown to be a real GDScript v native divergence, plan item 0b):**
  `make remote T='test FILTER=test_manoeuvre_'` in this worktree's FRESH builder0
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
- **Planner's CP-Q verdict (relayed 2026-10-16; stream/planner `722ba183`,
  `references/round32/planner/cpq-65cc43dd/VERDICT.txt`):** the shared queue FAILED on settle and facing (builder0,
  hull-rest gangs seeds 66–71, n 36 an arm: faced_move settle paired median +14.5 s, moving at 75 s faced_move +5 /
  faced_screen +3, SBF drawn at-rest error 106.8° v 74.3°). Planner's reading: today's FIFO starves ~20 % of face asks
  in a press, and served by the seam's face plans those crews settle WORSE. **So in M1b(3)'s drift-trace run, split the
  75-s movers by plan source (planner-served v today's face code)** beside brains' seat-drift reading.
  **CORRECTED (planner's traces, stream/planner `9ddcafee`):** neither CP-Q regression reproduces. Hull-rest's run-to-run
  variation dominates the tail (rigs paired median +0.3° / +0.4°). The split is still worth doing; expect little from it.
- **A likely bug in MY face path, to trace once H1b's series is running:** hull-rest faced_move s66 Green_Guns_5 (War Rig)
  ends ~144–156° off in BOTH arms. The planner's seam never acts for it. It drives its move_to, arrives nose south, and
  its order becomes `stop` with NO face step, so the faced move never turns to face at rest (order_controller's
  face-at-rest path). It may feed M1b(3)'s "moving / not settled" lines too.
- **Working hypothesis to TRACE before designing (now doubtful, see above):** attempt 2's hulls turned mid-approach, swung the halt and re-seated
  the element (Terminus mixed misses), and perhaps kept the attack-move crews moving at 75 s. The bar is filed before
  numbers, after H1b.

**The swap candidate is GREEN on quick-remote:** `lab/manoeuvre-swap2` `d21b5d56` (builder0, `>> remote: make quick …
exited 0`, 389 passed / 0 failed, QUICK_BASE=main, lint of 238 scripts + combat-smoke). Native is cutting the ON pair
tree (+ the `_h1b_swap_goal` row, H1B_SWAP_DEFAULT true). The series waits for its check (C31.1).

### C32.10 SWAP bar (FILED on main as written, 2026-10-16, before any number)

- **Candidate:** `lab/manoeuvre-swap2` (main `5cc02947` + brains' seam `f2cc956d` + my hook + the stage tests; native's one
  exec_fields row `_h1b_swap_goal` rides in the pair), the switch `h1bswap` OPT-IN (`--nav-off=h1bswap` turns it ON).
  **Base:** the same tree without it, i.e. main's behaviour, H1b ON. Arms by BEHAVIOUR (the runner derives the names
  from movement.gd's defaults): `h1b` v `swap`, both on the GDScript path. One tree, every run printing its flags.
- **Pre-registered:** the swap is asked only at H1b's second failed ask on a PARKED friend (`not is_under_way()`) whose
  goal is nearer this hull than its route left. A **far loop** = H1b's `far` count: a loop H1b could not settle (more
  than 12 m of route left, or a sliding goal).
- **Fresh seeds (unclaimed on main `71c061b4`):** Terminus drive 380–392 (13, rigs + mixed), hull-rest 393–398
  (n 144 an arm, one arm per call), fights 400–423 (24). Named cases: the far-loop trace's six pairs (Terminus hunt
  seeds rigs 3, 4, 6 and mixed 4, 5).
- **Gain line (G):** on 380–392, far loops in the swap arm ≤ 50 % of the base arm's, rigs and mixed apart, read once
  at completion. The trace found 50 of 62 far loops were the parked-friend case; 50 % leaves room for refusals.
- **Guard lines, each run to completion and read once on its fixed 1.645 se line (R31.8):**
  (1) loops − far = 0 in both arms (no NEW near-goal loop); far ≤ base far, every named hunt seed;
  (2) hull-rest PINNED (≤ 10 m hulls) and STUCK ≤ base + 1.645 se, paired, n 144;
  (3) Terminus PINNED and STUCK, per squad, ≤ base + 1.645 se (paired sum, se of the seed-paired differences);
  (4) Terminus arrivals, rigs and mixed apart: paired mean ≥ base − 1.645 se;
  (5) fights 400–423: kills, deaths, hit rate within 1.645 se;
  (6) RE-SEATS (R32.3's fail line, element `reseats`, not counting swaps): ≤ base + 1.645 se; swaps reported apart;
  (7) the whole suite green on native's pair tree with H1B_SWAP_DEFAULT flipped ON (C31.1), before the series.
- **STUCK definition (the reader subtlety, stated before numbers):** `tests/manoeuvre/pinned_table.py` as at
  `f5bf085f`: a crew on a move_to with |throttle| > 0.3, in a run of ≥ 10 one-second state lines with no line 1 m closer
  to its goal than the run's best; a goal-distance jump > 3 m (a new goal) closes and restarts the run. **A run that ENDS
  IN PROGRESS is not counted** (both readers have always done this). So STUCK counts pressing that is never relieved
  within the run, not pressing that eventually gets through.
- **REPORTED:** swaps asked / taken / refused by brains' reason; far rows by blocker kind (PARKED / MOVING / MUTUAL);
  Sumps s19 t8 with the latch ON (R32 B10 amended: reported, NOT a pass case, since its crews never fire the escape).
- **Partial:** none. A miss parks the swap with the trace; no re-tuning on these seeds.

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

**A named case for the swap's bar (the orchestrator, from brains' B10 trace):** Sumps s19 t8 with brains' grounding
latch ON (`8e43cc5c`). S_2 parks at (-2.5, -51.9) in the passage S_3 and S_4 need to reach their west seat: ~40 s of
`no_path` / blocked-by-each-other, two make-room trades, +19.9 s. **To check first:** do those crews' stalls reach H1b at
all? H1b's count only runs on an escape FIRE (a throttle-held stall with a Tank in the slide); a crew reading `no_path`
may be standing, not pressing, and so never fire. If they don't fire, the swap's trigger needs a second door (a
`blocked_by` same-squad parked friend for N s) before this case can be one of its pass lines.

**Native on the swap (lab `98a29c57`): NONE PORTED.** The native drive calls `_escape_step` back for any `_esc_stage != 0`,
so ESC_SWAP runs as GDScript, and `_h1b_swap` runs inside `_escape_begin` (a callback). The pair needs ONE exec_fields row
from native, `F(Vector3, VECTOR3, _h1b_swap_goal)` placed after `_h1b_last_answer`, and it ships with the swap.
`swap_seam_override` is a static, so it needs no row. Native cuts the pair tree on the candidate hash.

**H1b bar line (1), amended on main before numbers:** on the named hunt seeds (Terminus mixed 4, 5, 6, 7, 9, 10, 11,
13, 14, 16; rigs 1, 2, 3, 4, 6, 9, 10, 14, 15, 16; fights 4, 6) AND on the fresh Terminus seeds 300–312: H1b-arm
loops − far = 0 and far ≤ base loops; far reported per seed on both sets.

### Plan (ordered)

0b. **MOVED TO PLANNER by the orchestrator (2026-10-16)**: planner owns the GDScript planner twin, and it comes back
   to me only if the trace lands in my executor (with the leg). Native added `test_native_face_behind`.
   (Was: inserted 2026-10-16, low priority) **The War Rig's planned turn diverges GDScript
   v native:** `test_manoeuvre_behind::test_the_war_rig_faces_behind_in_a_planned_turn` FAILS with no native library
   (drift 25.3 m, legs 2, aligned 9.67 s: traffic's `check NATIVE=off` at 0adc6deb, the laptop, and MY fresh-builder0
   run at 373de208 with the identical numbers) and passes native ON. A GDScript planner exists
   (`game/ai/planner/planner.gd`), so this is the GDScript twin or my executor, not a native-only test. GDScript is
   every twin's reference. Native and planner are told.
0. ~~Trace hull-rest faced_move s66 Green_Guns_5~~ **DONE** (see Measurements): brains' HOLD return reverses onto the
   post without the facing, after an arrival overshoot. Sent to the orchestrator; the overshoot measurement is mine,
   in M1b(3).

1. **H1b** (C32.2): unit test first (`tests/test_manoeuvre_h1b.gd`: a rig / IFV sent to a slot a parked squadmate sits
   on; base loops, H1b settles), then seed 31's last leg as the pass case, then the bar to the orchestrator, then the
   series, then native's twin and a ship pair.
2. **M1b(3)** (C32.5): the written agreement with brains through the orchestrator first; then the attack-move settle.
3. **Test splits** (C32.8): **DONE for my files.** `test_manoeuvre_h1b` 162 s → 60 s + `_guard` 40 s (`08e6d44c`);
   `test_manoeuvre_behind` 69 s → 4 + 2 tests in `test_manoeuvre_behind` + `test_manoeuvre_face_behind` (`566564aa`, bodies
   byte-identical, laptop 18.6 s + 54.3 s). Still to do: re-record `tests/shard_times.txt` (`make test-times` after the next
   full sharded check).
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

