# Stream: brains (the yard's last crew in every time with the 180° arrival and a scout's chase intact; his bridge 108/108; support by fire lines up on his drawn facing; the re-seat reads the honest speed)

> Read `_agents/orchestration.md` (the worker contract; lessons 306–311 — **307 is yours twice**), `_agents/judging.md`,
> `_agents/doctrine.md`, `_agents/workstreams.md` **Round 31** (C31.1–C31.11, especially **C31.1**, **C31.4**, **C31.6**,
> **C31.8**), and round 30's brains report (`streams/archive/round30/brains.md`: B5c-v4 and its pursuit trace, B3b's
> per-switch cells, B6's three causes; rows and traces under `references/round30/brains/`). **You own:** `game/ai/**` EXCEPT
> traffic's, manoeuvre's, native's and the planner's carve-outs (C31 list), `game/tactics/**`, `tests/ai_scenarios/**`
> (others add their own `scenario_<stream>*.gd`), `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`,
> `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `tests/test_wheeled_arrival.gd`, `mk/ai.mk`,
> `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`. **Granted to others in your files:** traffic's gate lines
> (C29.3); manoeuvre's two aim-lead lines in `gunnery.gd` and the turn-hull lift of `_order_move`'s decline (C31.8).
> **The C++ (C31.2):** `decide`, `build_situation`, TacticalQuery and `_approach_gate` run in C++ (native's v4 mirror is
> `lab/native-b5c-v4` f508ce89). **Model:** Opus.

## The lead's direction

Round 24: every squad across his bridge, both sides. Round 28: the gate's job is the yard's last crew in. **Round 31: no
new words**; round 30's findings are the direction, and C31.1 (the pair-tree check BEFORE judging) is the rule your two
round-30 reds wrote.

What he will notice: at the yard crossing the last crew of his squad is in every time, a car ordered to face the way it came
still turns round, and his scouts still chase a spotter down (the three things v4 could not hold at once). His bridge drill
passes every cell. A support-by-fire line he draws faces where he drew it (wheeled turret hulls once manoeuvre's turn-hull
lands).

## Where things stand (main `cff4307e`)

- **B5c-v4 PARKED** (`lab/brains-r30-gate` f1a804eb; judged 19eca15a passed EVERY line: yard every crew in 12/12 v 1/12,
  Sumps 24.5 v 37.5 s, arrive 99 v 91/100, Terminus 10/10 with `near` firing on B_4). The pair check failed
  `test_tactics_pursuit` (five wheeled scouts, 8 m/s): the gate answered FIVE times, all at t = 0.1 s while the squad formed
  its opening vee — A_2 and A_4 `near` (7.6 m from their vee seats) — and the chase diverged downstream; no gate rule runs
  during the chase. Scoping "near not on an opening seat" fits the guard; "not on an arrived hull" moves judged rows. The
  planner's §2.8: a SIDE gate for 180°, never one behind the slot along the facing (v4 lays it behind: gates_turned fired
  10×/25×). **C31.6:** measure the pursuit test's own margin over seeds first.
- **B3b PARKED** (`lab/brains-r30-bridge` 4bc708d7): 107/108 v control 106/108 — route-aware seating + the mouth guard +
  the narrowed heading rule fix main's two cells (green t5 s2, rust t9 s2) and break green t18 s3 (one crew at the rim;
  the trace: route seating re-matches every plan). Per-switch cells in the report.
- **B6 TRACED, bar filed, not run** (`lab/brains-r30-sbf` 9aa0cd7c; `tests/tactics/sbf_probe.gd`, `make sbf-series`):
  three causes — (a) YOURS: with a drawn facing the SBF line still hands each crew its fanned sector (the plain move zeroes
  sectors when he draws); (b) the gate (B5c); (c) wheeled turret hulls decline a drawn facing (manoeuvre's turn-hull,
  C31.8; gang_ifv's 88.6° ceiling in both arms). Tuning of (a): gang_tank 20 → 11.2°, law_ifv 20 → 1.1°.
- **The Terminus seat trap** (traffic's T3b worst run s33/t1: B_4 circles its seat (35.6, 23.9) reading no_path/terrain
  36–61 s; B's destination (45, 30); needs `traffic-t3b`'s rule underneath to reproduce) — untraced.
- **The re-seat's "slow" test reads `estimated_velocity`** (manoeuvre's Sumps trace: a stranded 8×8 at 0.86 plant speed
  read as driving) — a CP-H consumer (C31.4, `--brains-off=realslow`).
- `judging.md` has rows for the yard/Sumps cells and the arrive series now (round 30's rows); B7's split is in.

## Backlog (in order)

**B5c-v5 — the arrival gate that keeps yard, the 180° arrival AND the chase (DECLARED; C31.6; last attempt named).**
(1) FIRST, the A/A: `test_tactics_pursuit`'s stage over 12 seeds, both arms OFF (and the 8 m/s + 18 m/s cases): its own
margin → a row in `judging.md` (send the orchestrator the numbers; it adds the row). (2) The design, picked from the trace:
`near` only on a re-seat / a new goal while ON A TASK (never the opening seat), and/or the 180° gate laid to the SIDE
(§2.8). (3) **The pair-tree check (C31.1) BEFORE any series:** native's mirror from `lab/native-b5c-v4`, the whole suite
with the rule ON — `test_tactics_pursuit` on every seed of the A/A as a pass line, `test_wheeled_arrival`,
`test_nav_arrival_heading`, `test_nav_gate_hold`, `test_nav_gate_v4`. (4) Bar from round 30's (yard crossing n = 12 the
deciding count line; Sumps; Terminus reported; arrive n = 100 McNemar; counters; bridge; screen-slots A_2; cost) citing
the table's rows; partial: none. Ships = default flip + native's mirror as a pair.

**B3b-2 — his bridge 108/108 (DECLARED; last attempt).** From 4bc708d7: keep what fixed main's two cells; trace green t18
s3 (the rim crew) and fix the one thing it shows (route seating re-matching every plan: match once per task point, or
only when the route crosses a deck?). Pair-tree check first. Bar: the FULL 108 = 108/108; bridge-pooled 18/18; arrive
fresh seeds n = 100 (within 8 m ≥ control − 1, McNemar discordant-against ≤ 1); counters; cost.

**B6 — the SBF sector hand-out (DECLARED; bar FILED in round 30, candidate 9aa0cd7c; last attempt).** Re-base on main;
pair-tree check first (the hand-out is GDScript: native states "none ported"); run the filed bar as written (`make
sbf-series SBF_SEEDS=7..18` × four wheeled classes + `tank` guard; drawn pooled median ≤ control − 10°, no class worse by
> 2 se, crews in ≥ control − 1, clicked rows byte-identical, counter, suite green) with gang_ifv's ceiling stated as
turn-hull's (C31.8). Ships ON.

**B8 — the re-seat reads `real_velocity` (CP-H consumer; `--brains-off=realslow`).** The "slow" test in the re-seat /
make-room clock reads the honest speed so a stranded hull at 0.86 plant speed is "stuck", not "driving". Unit test from
manoeuvre's Sumps trace. Pair-tree check; native ports (the element clock has a seam). Deliver behind the switch by CP-H;
manoeuvre runs the A/B.

**B9 — the Terminus seat trap (trace only unless a fix is cheap).** Cherry-pick `traffic-t3b`'s game files into a scratch
tree, `--traffic-on=turns`, Terminus crossing seed 33 tick 1: what does B_4 read at (35.6, 23.9) for 25 s? If it is a
seat on bad mesh → a DECLARED seating fix with its own bar; if it is the gate → B5c-v5's case.

**Stretch:** none. Adopt the early-stop hook (traffic's pattern) and `CACHE=on` in your series runners when they land.

## How to verify

The pair-tree `make check` with the switch ON before any series (C31.1); `make gate-series`, `squad-arrive-series`,
`bridge-series` (the 108), `bridge-pooled`, `screen-slots`, `sbf-series`, `native-verify-scenarios`; the named tests on the
default path. Clips: the 180° arrival + the yard crossing; his bridge. Every number: commit, machine, workload, n, its row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; manoeuvre's drive body / unstick / k-turn executor / face path,
`manoeuvre*.gd`, `wall_contact.gd`, the two gunnery lead lines, the `_order_move` decline (granted to manoeuvre); the
planner's `game/ai/planner/**`; native's `native/**`; `game/control/**`, `game/tank/**`; `tools/judge/**`.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current; bars to the orchestrator before numbers; the report at the top)_

### FINAL REPORT (round 31, 2026-10-15 ~12:30 PDT)

**Green hash:** stream/brains `303883c1`: `make check` on builder0 **exited 0, 2613/0**, sim-baseline unmoved,
bridge-pooled 18/18, native-verify 0 mismatches, ai-scenarios NOT JUDGED (the usual refusal). The commits after it are
Status/references only. Every
backlog item is done, judged, or parked by its bar. No lead gate is pending; no questions.

**Shipped**
- **B6, SBF facing:** with a facing drawn, the support-by-fire line takes it, not fanned sectors. **MERGED ON to main as
  201b792a** (lab `f22d7dcb`; GDScript only, native: none ported). Passes every line of round 30's filed bar (builder0,
  seeds 7–18, n = 12 runs an arm and class). Pooled drawn hull error at in, four wheeled classes: **10.4 v 29.1°**.

  | class | drawn median, on v control | crews in |
  |---|---|---|
  | gang_ifv | 26.0 v 49.9° | 48 v 48 |
  | gang_tank | 10.2 v 28.3° | 48 v 48 |
  | law_ifv | 1.1 v 28.9° | 48 v 48 |
  | law_tank | 24.0 v 29.9° (within 2 se) | 45 v 45 |
  | tank (guard) | 1.6 v 21.8° | 48 v 48 |

  Clicked rows 60/60 identical. Counter 60/60. Check 2613/0. Cost 0.178 v 0.171 ms. gang_ifv's remaining 26° is
  turn-hull's ceiling (C31.8: a wheeled hull not turned at rest, manoeuvre's), as is law_tank's 80–90° A_1/A_3 in
  both arms.
- **B8, realslow:** on main (aa205ea5), opt-in behind `--brains-off=realslow`. Waits for manoeuvre's CP-H A/B.
- **B8 toggle fix (for CP-H's ship):** `--brains-off=realslow` set it TRUE, so once the default flipped ON no arm
  could turn it off. Fixed in **c45c9792**: it flips against `REALSLOW_DEFAULT` (`BrainSwitches.realslow_named`), as
  unstickback/kturnarc/realspeed do. Check on builder0 at c45c9792: **exited 0, 2642/0**, sim-baseline unmoved,
  bridge-pooled 18/18. MERGED to main as 40eda0cf (INHERIT, no second check).
- **R31.9 split (stretch, test-only), GREEN:** `lab/brains-r31-split` **5a30b037** (split 293f9d62 + main 04620f67).
  The six slowest brains test files are now fifteen, with shared stages in base files that hold no tests. 33 tests before and after, bodies
  byte-identical. Slowest file 264 s -> 126 s (tactics_scenarios_4, builder0 light lane). Check on builder0 at 5a30b037:
  **exited 0, 2653/0**, sim-baseline unmoved, bridge-pooled 18/18, native-verify 0 mismatches. Handed to the orchestrator
  MERGED to main as e66b41f1 (the round's final main check covers it). Earlier runs: 293f9d62 killed by the 5400 s cap on a saturated box. 1a7c950f red on sim-baseline only
  (main's 71538a8d baselines were adopted on a stale native lib, corrected at 4973a482). f18eaea0 stopped (main's
  test_native_drive red, reverted at 04620f67). tests/shard_times.txt has no rows for the new files yet.
- **Cleanup done:** worktrees godot-brains-sbf and godot-brains-bridge removed, plus their builder0 folders (cwd-checked idle).
  Branches kept: lab/brains-r31-bridge, lab/brains-r31-split, pair/brains-v5, stream/brains. Round 32: `make test-times` to give
  the 9 new test files their shard times. **Stream done for round 31.**
- **R31.3:** test_tactics_pursuit made robust over seeds (a16585bf, 0415da23): on main (aa205ea5). A/A filed in
  judging.md.

**Parked, each with its table**
- **B5c-v5, the arrival gate:** FAILS line 3 (Sumps s17 t11 +22.3 s). Rows `b5c-v5-*`. Branch `pair/brains-v5`
  e675a28a kept.

  | line | on v off | result |
  |---|---|---|
  | pursuit | 24/24, 24/24 nudged | PASS |
  | yard, every crew in | 11/12 v 1/12 | PASS |
  | Sumps | median 24.8 v 24.9 s; s17 t11 58.3 v 36.0 s | FAIL |
  | Terminus (reported) | 3/4 v 2/4 | — |

- **B3b-2b, his bridge:** **the bridge is solved by the seating, not shipped this round**. FAILS line 3 (arrivals).
  Rows `b3b2b-*`. Branch `lab/brains-r31-bridge` 5ed61f91 kept.

  | line | candidate v control (main's rules) | result |
  |---|---|---|
  | his bridge, full 108 | **108/108** v 106/108 | PASS |
  | bridge-pooled | 18/18 | PASS |
  | arrive, all_in8_s, n = 100 | 90 v 97; 9 against, 2 for | FAIL |
  | counters | 108/108 bridge runs; 0 of 200 arrive runs | PASS |
  | cost | 0.116 v 0.194 ms | PASS |

- **B9, the Terminus seat trap:** traced, not a seating bug. It is the arrival gate circling (61.4 s; v4's `near`
  frees it at 19.4 s).

**Round-32 leads** (all in roadmap.md via the orchestrator)
1. **His bridge = the crossing seating + mouth guard WITHOUT the heading rule.** TRACE (not evidence):
   `--reissue-heading=plan` alone frees all 9 against cells at the control's exact times; the mouth guard alone frees
   none.
2. **The arrival gate:** key `near` per seat (or hysteresis), or the planner's §2.8 side gate (B5c-v5's Sumps limit
   cycle, yard s27 t8). The gate can also be pushed off by a new facing (B6 law_tank s17: `no_path` 21 m out).
3. **Navmesh:** the default arena's Alpha_3 spot (−25.7, 7.3) is 8.2 m off the navmesh (arena owner).

**Requests:** none open. **Known issues:**
- `tools/test_quiet_window.sh` "records once the window opens" flakes under load (remote-guard-test, seen once on
  344a772a). It is the orchestrator's to harden.
- perf-judge NOT JUDGED on a busy box in every check this round.

**Playtest notes (for him):** draw a facing on a support-by-fire order with wheeled squads. The line should now look
the way he drew (B6). His bridge is unchanged on main (106/108 cells).

**Worktrees:**
- Removed: godot-brains-b9, godot-brains-pair, and their builder0 folders.
- Left: godot-brains-bridge (parked lab) and godot-brains-sbf (merged). Both branches are pushed; remove at round
  close.

### Detail (the round as it went; REPORT so far) (2026-10-15 ~00:00 PDT)
- **B5c-v5 (1) the A/A — DONE** (`make pursuit-aa`, builder0, stream `3cb76e17` = main's game/, rule off, default path,
  48 runs; rows `references/round31/brains/pursuit-aa-3cb76e17.*`; filed in `judging.md`, ruled R31.3). **The test's
  stage was knife-edge on main:** 8 m/s as written 12/12, every start nudged 0.25 m 9/12 (the nudge alone flipped seeds
  3 — the test's own — 5, 9); 18 m/s 10/12 both, seeds 1 and 9 failing as written.
- **The 18 m/s failures traced** (builder0, seed 1): Green_A_1 shot to hp 0.01 at 5.0 s breaks away home (decide's
  RETREAT, the lead's rule); the per-crew closing/reversal lines lacked the let-go line's hurt excuse. Not a physics
  launch; real_velocity not involved.
- **R31.3 (a) `a16585bf`** the hurt excuse on those two lines; **(b) `0415da23`** the robust in-suite test (seeds 3–7,
  both visible chases, ≥ 3 of 5): green on builder0 (10/0, 5/5 at both speeds). **Merged to main as aa205ea5 (with B8).**
- **R31.3 (c) DONE** (stream `0415da23` = aa205ea5's code, rule off, builder0, 48 runs; rows
  `references/round31/brains/pursuit-aa-0415da23.*`, 9e6f17c3): as written **24/24**, nudged **22/24** (8 m/s seeds 3, 9
  let go; 18 m/s 12/12 both). v5's line (1) (main 3b7e7a6c): ON ≥ 21/24 as written AND ≥ 19/24 nudged, no new let-go
  at 18 m/s.
- **B5c-v5 JUDGED: FAILS its bar on line 3 (Sumps "no run > 5 s later") — the last attempt, partial none → PARKED**
  (proposed to the orchestrator). Candidate = v4's rule unchanged (pair tree `pair/brains-v5`: check on `17e7b08c`
  exited 0, 2629 / 0; series on `e675a28a` = + `tests/nav/arrive_pair.py`), builder0, GDScript drive both arms, fresh
  seeds; rows `references/round31/brains/b5c-v5-*`. (1) pursuit PASS 24/24 + 24/24 nudged (8 m/s reversal margin +47° on
  v +69° off). (2) yard PASS: every crew in 11/12 v 1/12, crews on ≥ off every run, median 21.0 s v never; endings latched
  3 / reset 3 / stuck 1 / cap 0; worst on-run s27 t8 = a 180° come-round carried A_5 27 m from its gate onto terrain
  (the planner's §2.8 side-gate case). (3) Sumps FAIL: median 24.8 v 24.9 s, arc 0.939 = 0.939, but s17 t11 58.3 v
  36.0 s (+22.3): S_3's slot drifts 67× on v 3× off between two seats ~10 m apart, `near` refires on every flip (a limit
  cycle between near-per-goal and the seating). (4) Terminus reported: all in 3/4 v 2/4. Stopped there (decided): arrive,
  bridge, screen-slots, cost never ran. Round 32: key `near` per seat (or hysteresis), or the side gate.
- **B8 DONE, on main** (`80eea6ec` + `922db8b6`, in aa205ea5): `realslow` opt-in (R31.1), GDScript only (the re-seat
  clock is GDScript on every path; `real_velocity` is filled by the native tank drive too). **Pre-series gate ACCEPTED**
  (scratch `44b32f12` = stream + default ON, `check NATIVE=off`, builder0, 3038 s): 2612 / 0, 25 of 26, sim-baseline 13
  unmoved, perf-judge PASS; `native-live-guard` red by construction under NATIVE=off (recorded in R31.1). Exit line
  missing (local `make remote` "Terminated" after the summary though launched setsid'd): accepted on the runner's
  summary as a PRE-series gate only. Waits for CP-H.
- **B6** re-based: `lab/brains-r31-sbf` = stream 0415da23 + round 30's three commits + `make sbf-bar` (`f22d7dcb`); its
  pair-tree check next. **Gate (C31.1) on f22d7dcb (builder0): `make check` exited 0, 2613/0, sim-baseline unmoved,
  native-verify 0 mismatches, bridge-pooled 18/18; perf-judge NOT JUDGED (box busy, 2.5–2.6x), ai-scenarios NOT JUDGED.**
  (A first try was stopped at the orchestrator's request: two heavy slots held by one stream.) The bar's run (`make
  sbf-bar`, seeds 7–18 × law_tank gang_ifv law_ifv gang_tank + tank) is running.
- **B6 JUDGED — PASSES EVERY LINE; ships ON (GDScript only; native: none ported)** (builder0, `lab/brains-r31-sbf`
  `f22d7dcb`, round 30's filed bar, one tree, on v `--sbf-told-sectors=on`, seeds 7–18): (1) pooled drawn hull error at
  in, four wheeled: **10.4 v 29.1°** (need ≤ 19.1); per class gang_ifv 26.0 v 49.9, gang_tank 10.2 v 28.3, law_ifv 1.1 v
  28.9, law_tank 24.0 v 29.9 (paired diff +4.8, se 7.2: within 2 se): none worse > 2 se: PASS. (2) crews in, drawn: 48 v
  48 for three classes, law_tank 45 v 45: PASS. (3) clicked rows 60/60 identical: PASS. (4) counter fired 60/60 drawn on,
  0 clicked, 0 control: PASS. (5) the gate on the tip: `make check` exited 0, 2613/0 (tactics scenarios incl. SBF /
  screen / ambush postures), sim-baseline unmoved, so nothing to explain in the thirteen. Additions: (a) the tracked
  `tank` guard 1.6 v 21.8° (better, not just within 2 se); (b) the CPU never draws a facing (`told` comes from his task
  only), so no CPU line; (c) cost `t.poll.element` 0.178 v 0.171 ms on Locks (`ai-parts-match`): ≤ 0.5 ms, PASS (inert
  for the CPU, so noise); (d) native: the change is 16 lines in `ElementPlan._plan_support_by_fire`, no native mirror of
  ElementPlan; native-verify-scenarios 0 mismatches: none ported. (e) law_tank read before the median: in most seeds
  A_1 and A_3 sit ~80–90° off in BOTH arms (cause (c), a wheeled hull not turned at rest: manoeuvre's M1b, outside B6).
  The worst run, s17 drawn on (2 of 4 in), traced: A_1, given the drawn facing (−0.87, −0.50) instead of its sector
  (−1, 0), reads `blocked no_path` from 16 s 21 m from its slot and never recovers; A_3 queues behind it. Control: A_1
  hits `no_path` at 20 s too but recovers, in at 24 s. This is the arrival gate, cause (b) (B5c, parked), reached by
  the new facing; the crew count is level overall (control loses its 3 in s8, s14, s15). Rows + traces:
  `references/round31/brains/b6-*`. For the orchestrator to merge `lab/brains-r31-sbf` f22d7dcb.
- **B3b-2** built: `lab/brains-r31-bridge` `344a772a` (route seating matched ONCE per task point, held `fixed` until the
  point changes or a re-seat; `--route-seat-once=off` = round 30's B3b; counter `crossings_held`); unit 5/0. Tuning on
  the three named cells running: green t5 s2 on = rim 0, 4/4 across, 35.8 s. Tuning (n = 1, builder0): green s2 t5 rim 0
  35.8 s (control 31.8), rust s2 t9 rim 0 38.0 s (control 49.3, deck jam 7.1 s), green s3 t18 rim 0 36.4 s (control rim
  1 FAIL). **Pre-series check on 344a772a (builder0): exited 2, 2619/0; bridge-pooled 17/18 (rust t8 s2: rim_crews 1)
  and remote-guard-test (quiet-window "records once the window opens", the known load flake, workstreams ~1148); every
  other gate green, sim-baseline unmoved, ai-scenarios NOT JUDGED (the usual refusal).** Traced rust t8 s2 (builder0):
  on, S_1 (first across) held the westmost far seat (49, 12) on the bank edge; leaving it for the next point (23 s) it
  reversed into the rim and stood blocked 4.1 s; control (re-matched) sent it to the near seat (79, 12), 0.5 s. Series
  NOT run (line 2 already failed). **B3b-2b** `5ed61f91`: the held seating is matched again once each time the count of
  crews past the exit changes (`Element.crews_across`; `--route-seat-across=off` = 344a772a; counter
  `crossings_rematched`); unit 7/0 (laptop). Tuning (n = 1, builder0, 5ed61f91): rust s2 t8 rim 0 29.5 s, green s2 t5
  rim 0 34.2 s, rust s2 t9 rim 0 43.8 s, green s3 t18 rim 0 40.5 s (S_1 2.1 s at the rim, under the 3 s line). The
  orchestrator accepted B3b-2b as the candidate under the same bar (a gate red fixed before any judged number, C31.1).
  **Gate on 5ed61f91 (builder0): `make check` exited 0, 2621/0, bridge-pooled 18/18 (= bar line 2), sim-baseline
  unmoved, native-verify 0 mismatches; perf-judge NOT JUDGED (box busy, ratios 1.57–2.30x), ai-scenarios NOT JUDGED.**
  **B3b-2b JUDGED — FAILED on line 3, NOT SHIPPED; the last attempt as filed: PARKED** (builder0, `5ed61f91`,
  2026-10-15 08:23–10:29 PDT): (1) his bridge, the FULL 108: **on 108/108**; control (main's rules) 106/108 (green t5 s2,
  rust t9 s2 rim_crews 1, round 28's two cells): PASS. (2) bridge-pooled 18/18 (the gate): PASS. (3) arrive, fresh seeds
  41–44, n = 100 an arm: all_in8_s **on 90 v control 97**, discordant 2 for v **9 against** (McNemar p 0.065; needs ≥ 96
  and ≤ 1 against): **FAIL**. Paired median over the 88 complete in both 28.1 v 28.9 s (−2.6 %, paired diff +0.0).
  Against: pit ifv/ifv/supp/tank s42, pit tank×4 s43, sumps tank×4 s44, yard ifv/ifv/supp/tank s41, yard
  scout/ifv/tank/tank s43, yard scout/scout/ifv/tank s42 + s43, yard tank×4 s41 + s44; for: sumps tank×4 s42, yard tank×4
  s42. (4) counters: crossings_found / held / rematched > 0 in 108/108 bridge runs on, 0 on control; 0 in all 200 arrive
  runs (no deck on those maps: the seating never fires there); mouth_held_resends > 0 in 2 of the 108. (5) cost:
  `t.poll.element` 0.116 v 0.194 ms on Locks (`ai-parts-match`, box busy, act 0.80 v 1.33: no gain claimed): PASS.
  **So the arrive loss is not the seating** (inert there): it is round 30's other two switches (mouth guard, heading
  rule) that ride in the candidate, never judged on the arrive line before (round 30's chain stopped at the 108). Rows:
  `references/round31/brains/b3b2b-*`. **Attribution, a TRACE not evidence** (the orchestrator's label: the 9 cells
  were picked because they lost; builder0 light lane, 5ed61f91, n = 1 a cell and switch): as is, 0 of 9 in within 8 m
  (reproduced: deterministic); `--mouth-held=off` alone 0 of 9; **`--reissue-heading=plan` alone 9 of 9, each at the
  control's exact all_in8_s** (35.57, 47.7, 39.93, 54.87, 47.37, 72.7, 108.3, 39.23, 105.83). A round-32 LEAD: round
  28's heading rule narrowed to the drawn facing (254fd98f) is what costs these arrivals; the seating and the mouth
  guard do not. The 2 "for" cells not re-run. Rows: `b3b2b-attr-trace-5ed61f91.jsonl`.
- **B9 DONE — the Terminus seat trap is the GATE (B5c-v5's case; no seating fix).** Reproduced on a scratch tree =
  stream + traffic-t3b's `traffic.gd` (a63dde6d) AND its `Traffic.shape` hook in `_avoid` (main lacks it; without it the
  rule never acts: my first two traces = T3b's base arm). terminus cross s33 t1 `--traffic-on=turns`, builder0 GDScript:
  B_4 in 61.4 s (= traffic's worst run). 40–61 s it steers between its seat (35.6, 23.9) and (35.3, 40.0) = its arrival
  gate 16.1 m north: reaches the gate, turns for the seat, loses "reached", is sent back (round 29's per-tick circling);
  reach-probe: the route to the seat is reachable and near-straight, rays at 0/±0.8/±1.6 m × 0.4/1.0 m hit no static
  body, no squadmate within 15 m. **With v4's gate on top** (scratch 36630581): B_4 in **19.4 s**, every crew in 27.5 s
  v 61.4 (`near` fires at 12.2 s, 8.4 m from its seat). Relayed for traffic's T3b question (n = 1). Traces + probe:
  `references/round31/brains/b9-*`. Side answer (manoeuvre's relay): `test_control_queued_task`'s Alpha_3 spot
  (-25.7, 7.3) stands 8.2 m off the navmesh (the start snaps to (-17.5, 7.3)): navmesh, not the re-seat (round-32
  candidate for the arena's owner).

### B5c-v5 bar (DRAFT; to the orchestrator once the pair-tree check is green; DECLARED; the LAST attempt; no partial)
Candidate: **v4's rule unchanged** (pair tree above). Arms: default (on) v `--nav-off=gategiveup` (off), one tree,
GDScript drive both arms (as round 30), FRESH seeds:
1. **Pursuit (R31.3):** `make pursuit-aa` on the pair tree, rule on: ≥ 21/24 as written AND ≥ 19/24 nudged; no new
   let-go at 18 m/s; the in-suite robust test green in the C31.1 check.
2. **Yard crossing** (`gate-series` yard, seeds 27 28 × ticks 1 3 6 8 11 16, n = 12; judging.md *yard crossing cell*,
   count-runs): runs with every crew in on ≥ off AND crews on ≥ off every run (deciding); last-crew median ≤ off − 5 s
   reported (A/A ±9 s).
3. **Sumps cell** (seeds 16 17 × 6 ticks, n = 12; judging.md *Sumps cell*, se 6.61 s): all-within-8 m median on ≤ off,
   no run > 5 s later; guns_on_arc ≥ off − 0.05.
4. **Terminus head-on** (seeds 8–11 t11): reported.
5. **Arrive series** (5 maps × 5 squads × seeds 37–40, n = 100; judging.md *arrive series*): within 8 m on ≥ off − 1 and
   McNemar discordant-against ≤ 1; paired median of complete cells no slower than +2 % (reported; the row says n > 1000).
6. Counters > 0 on every acting on-run, 0 every off-run; come-round endings counted (mostly-cap is a finding).
7. bridge-pooled 18/18 (on); `make screen-slots` seed 61 A_2 in.
8. Cost: `path.gate` ≤ 0.5 ms a tick at Sumps 25 a side, or NOT READABLE.
9. The worst on-arm run of (2) and (3) traced before the medians.
Ships = the default flip + native's mirror as one pair; native shows yard and Sumps equal on the ON path.

### Plan (2026-10-14 22:30 PDT; start = main `cff4307e`, covered by the launch check; R31.1 read at main `4233dc7b`)
1. **B5c-v5 (1) the A/A first** (C31.6): `make pursuit-aa` = the test's OWN `_pursue` (not a look-alike probe) over seeds
   1–12 × 8/18 m/s, two arms with the rule off: nudge 0 (the test as written) v every start moved 0.25 m. Why a nudge arm:
   the TacticsLab is deterministic per seed (an A/A of two identical arms is an equality check, not a margin), and v4 failed
   by changing two crews' OPENING moves; a do-nothing change to the opening is the honest null for "knife-edge". Rows →
   `references/round31/brains/`, numbers → the orchestrator for `judging.md`.
2. **B5c-v5 (2)–(4):** the design from the v4 trace + the A/A; tests on the default path; the pair-tree check (C31.1) with
   native's mirror from `lab/native-b5c-v4` BEFORE any series; the bar to the orchestrator before numbers.
3. **B8** (`realslow`, opt-in per R31.1) — small, GDScript-only on brains' side: build it while B5c-v5's pair waits on native.
4. **B6** the SBF sector hand-out (bar filed; re-base 9aa0cd7c on main; pair-tree check; `make sbf-series`).
5. **B3b-2** his bridge 108/108 (route seating laid once per task point).
6. **B9** the Terminus seat trap trace (scratch tree with `traffic-t3b`'s game files).
