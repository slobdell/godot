# Stream: brains (every crew across his bridge without the arrive maps paying; the yard's last crew in every time, Sumps included; the re-seat question with manoeuvre)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/doctrine.md`,
> `_agents/workstreams.md` **Round 32** (C32.3, C32.4, C32.5, C32.8) and *Round 31* (C31.6, R31.3), `_agents/roadmap.md`
> *Round 32 candidates*, and your round-31 brief `streams/archive/round31/brains.md` (B5c-v5's and B3b-2b's tables and
> traces; rows under `references/round31/brains/`). **You own:** `game/ai/**` EXCEPT traffic's, manoeuvre's, native's and the
> planner's carve-outs (round 31's list, restated in *Round 32*), `game/tactics/**`, `tests/ai_scenarios/**` (others add
> their own `scenario_<stream>*.gd`), `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
> `tests/test_nav*.gd`, `tests/test_form_up.gd`, `tests/test_wheeled_arrival.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`,
> `doctrines/doctrine_*.json`. **Granted to others in your files:** traffic's gate lines (C29.3); manoeuvre's two aim-lead
> lines and the turn-hull lift of `_order_move`'s decline (C31.8). **The C++ (C31.2):** `decide`, `build_situation`,
> TacticalQuery and `_approach_gate` run in C++; v5's mirror is on `pair/brains-v5`. **Model:** Opus.

## The lead's direction

Round 24: every squad across his bridge, both sides. Round 28: the gate's job is the yard's last crew in. No new words in
rounds 31–32; round 31's findings are the direction.

What he will notice: every crew of every squad gets across his bridge, and squads ordered elsewhere arrive as before;
at the yard crossing the last crew is in every time, a car told to face the way it came still turns round, and his scouts
still chase a spotter down.

## Where things stand (main at the round-32 docs commit; inherits `e66b41f1`'s green check: builder0 exited 0, 2657/0)

- **Shipped in round 31:** B6 (SBF takes his drawn facing; pooled 10.4 v 29.1°), B8 `realslow` (ON via CP-H), the pursuit
  test made robust (R31.3), your test split (six files into fifteen, `e66b41f1`; the new files have no shard times yet).
- **B3b-2b PARKED** (`lab/brains-r31-bridge` `5ed61f91`): the crossing seating gave 108/108 on his bridge (control
  106/108), but the arrive series fell 97 → 90 within 8 m (seeds 41–44, n 100, McNemar p 0.065). Attribution trace
  (builder0 light, `5ed61f91`, n 1 per cell and switch, the 9 losing cells): as is 0/9; `--mouth-held=off` alone 0/9;
  **`--reissue-heading=plan` alone 9/9**, each at the control's all_in8_s. Round 28's heading rule (narrowed at
  `254fd98f`) carries the cost.
- **B5c-v5 PARKED** (`pair/brains-v5` `e675a28a`): pursuit 24/24, yard every crew in 11/12 v 1/12, but **Sumps s17 t11
  +22.3 s**, a seat flip-flop that refired `near` 66 times. Yard s27 t8 (a car given up 27 m from its slot, facing away)
  is the case design.md §2.8's side gate names. Your B9 trace: the same `near` frees Terminus s33 t1 under T3b (all-in
  61.4 → 27.5 s), and T3b-c ships ON this round (traffic, first), so judge on a tree that carries it once it lands.
- **The planner's side gate** (CP-S, C32.4) is being built by the planner stream: `PlannerSeam.side_gate(slot, facing,
  unit_id) -> Vector3` (ZERO when neither side has room). Its hand-over is in `streams/archive/round31/planner.md`
  *Hand-over for round 32 (2)*.
- Your round-31 branch is `round31/brains` (kept, not merged).

## Backlog (in order)

1. **B3b-2c, his bridge's seating ALONE (C32.3):** the crossing seating + mouth guard with the heading rule OFF for this
   behaviour. Test first; C31.1's pair-tree check (native mirrors whatever runs in C++); a bar to the orchestrator before
   numbers: his bridge 108/108 (or ≥ control), the arrive series within 8 m not below base − 1.645 se, fresh seeds;
   bridge-pooled 18/18. Ships ON as a pair.
2. **B5c-v6, the arrival gate (C32.4):** choose between `near` keyed per seat index (or with hysteresis) and the planner's
   side gate once CP-S is on main; record the reason in one line. Bar before numbers: Sumps s17 t11 and yard s27 t8 as pass
   cases, pursuit as R31.3's count, yard and Terminus as v5's lines, judged on fresh seeds on a tree with T3b-c ON. Start
   from `pair/brains-v5`; native mirrors.
3. **The re-seat ruling with manoeuvre (C32.5):** when manoeuvre asks, answer in writing through the orchestrator: does an
   arrivals line count "completed at a re-seated slot" as arrived, and should facekeep change for gang hulls? Your
   re-seat owns the answer; give a reason and a test that pins it.
4. **Shard times:** `make test-times` on builder0 so your fifteen split files get rows (then the orchestrator commits
   `tests/shard_times.txt`, or you do in your branch with a merge note). Then any remaining brains file over ~60 s (C32.8):
   `test_combat_suppression_bite`, `test_tactics_cpu_hold`, `test_tactics_cpu_ambush`, `test_ai_scenarios`,
   `test_ai_player_orders` are all > 180 s if yours.
5. **Stretch:** the navmesh gap at (-25.7, 7.3) goes to traffic this round (C32.6); give them your reach-probe if they ask.

## How to verify

`make quick-remote` to iterate; the pair-tree `make remote T=check` with the switch ON before any series (C31.1), only for
hashes you name. `make gate-series`, `squad-arrive-series`, `bridge-series` (the 108), `bridge-pooled`, `screen-slots`,
`native-verify-scenarios`. Clips: his bridge, the yard's 180° arrival. Long remote runs under `systemd-run --user`. Every
number: commit, machine, workload, n, its row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; manoeuvre's drive body / unstick / H1 / k-turn executor / face path,
`manoeuvre*.gd`, `wall_contact.gd`, the two gunnery lead lines, the `_order_move` decline; the planner's
`game/ai/planner/**`; native's `native/**`; `game/control/**`, `game/tank/**`; `arenas/**` (traffic's grant this round);
`tests/baselines/**`; `tools/judge/**`. `origin` holds an old `stream/brains`: don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n and its row; bars to
the orchestrator before numbers; green hashes named)_

### NOW (2026-10-16 ~10:10 PDT): the order is B11's check + series, then B10b once C32.10's swap ships, then v6
- **R32.6 DONE (`03aa0c5d`):** test_tactics_body's run-order dependence was an overlapping spawn in its stage, separated
  by physics only in a process's first match (no script static: 12 caches cleared and native off changed nothing;
  `make body-twice` + `--body-trace`, builder0). The stage now sets spawns apart; the new test
  `test_the_stage_spawns_no_two_hulls_overlapping` fails without it. The line holds on today's main: off 41.0, on
  15.0–16.0 whatever ran before (≤ 20.5 needed); 4/4 alone (builder0). Trip-up 82 in orientation.md. Play side: the
  deploy is guarded (test_spawn_grid); gaps relayed (law/syndicate not in that test; respawns not checked).
  **Reopened and closed again (`c029cf70`):** the check on `03aa0c5d` read off 28.5 / on 15.0 (2699/1): the OFF arm
  drifted over successive matches in one process (41.0, 37.0, 28.5; twelve caches cleared: no change). Again the start
  position: a hull touching something at spawn is moved on the first frame differently match to match, and the stage
  snapped wherever physics left it. Now it snaps each hull's INTENDED spawn after start() with zero velocity: on 15.5 ×3
  identical, off 41.0/37.0/41.0, on after off 15.0 (builder0, body-twice). The residual off wobble starts at tick 56 by
  0.1 m (contact-level physics), time-boxed; the line holds in every order seen (on/off ≤ 0.42 v 0.5). law + syndicate
  added to test_spawn_grid's deploy check (granted, `90a38609`). Check on `c029cf70` RUNNING (13:08 PDT).
- **For v6 (traffic's relay, T4 parked, stream/traffic 82a56293 references/round32/traffic/t4_r32/):** in a crowded
  yard head-on spot the LAST hull in (usually Green_A_5) reverses and circles its slot for 15–20 s under ORCA reading
  real velocity. Main has no B5c gate rules (v4/v5 never shipped), so that is round 8's approach gate coming round: a
  case for v6's side gate and its judged yard cells.
- **B10b's premise checked by manoeuvre** (builder0, main + swap + the latch, `--ground-latch=on`, s19 t8 reproduced at
  89.27 s, native = GDScript): S_3 and S_4 never fire H1b's escape (1 hull fire all run, 0 failed asks, 0 swap asks);
  they three-point at full lock reading no_path/terrain/each other, and S_2 is never their blocked_by. So the swap
  cannot reach this case: S_2's seat in the passage is the element's knowledge (the seat choice), not a pressed pin.
- **B10 PARKED** (the orchestrator's ruling; latch OFF by default, `--ground-latch=on`); **B10b** = re-judged once with
  C32.10's swap ON, s19 t8 its case; v6 waits behind it.
- **B11 (C32.12 (2)):** built `e440bcd9`, bar filed (seeds 350–355); **check on `03aa0c5d` RUNNING** (09:58 PDT), then
  `brains-b11-series.sh` (hull-rest on v old + s66 × 3 a arm).

### C32.12 (1) ANSWERED, (2) = B11; B11 bar FILED before numbers (2026-10-16 ~09:40 PDT)
**(1) Why a faced move "completes" 11–15 m off: it doesn't complete; it is REPLACED.** `--order-trace` (gangs s66
faced_move, builder0 light, stream tree): Green_Guns_5's move never passes `_update_order_progress` (no ORDER_TRACE line
for it; its squadmates complete at 4.3–6.0 m, not repaired). Once its element ARRIVES (centre within ARRIVE_M), the
halt hands every crew a `hold` at its seat carrying his drawn facing, and a faced hold replaces a move at once
(Element._should_issue, round 10's rule for wheeled crews circling their slots), wherever the crew is. Repaired-arrival
is not involved (repair_to INF). The hold is the right standing order; what was wrong is (2).
**B11 (2):** `TankBrain._hold_return`: with a drawn facing on the order, back on only while that facing is within
Manoeuvre.FACING_KEEP_DEG (60°) of the nose, else drive on nose-first carrying the facing. `--hold-return=old` = the
control. GDScript only (`_act` is GDScript on every path). Tuning, n 1 each, free clock (the harness is not
deterministic: off read Guns_5 161.9° then 149.9°): s66 Guns_5 100.5° on v 149.9° off; crews > 90° off 4 v 6 of 20.
**B11 bar** (arms on v `--hold-return=old`, one tree, builder0, default path; `manoeuvre-hull-rest` drawn, all four
factions × FRESH seeds 350–355 (the orchestrator: 60–65 and 66–71 are taken) × the six faced tasks, n 144 runs an arm):
1. Crews ending > 90° from his drawn heading, pooled over all crews: on < off (deciding), one-sided Fisher p reported.
2. Pass case gangs s66 faced_move: Green_Guns_5 ≤ 90° in ≥ 2 of 3 on-repeats (off's 3 reported).
3. Not worse: no hull class's median error worse with permutation p < 0.05 (hull_rest_ab); runs never settled on ≤ off
   + 2; paired settled_after_s median not more than 2 s later.
4. The whole suite on the tree; sim-baseline moves (a CPU halt's hold carries its sector facing too) listed with reasons.
5. The worst on-arm run traced before medians.
Ships ON as one commit.

### B10 JUDGED: FAILS line 2 (one Sumps run 19.9 s later); every other line passes. Not shipped; the orchestrator rules (2026-10-16 08:35 PDT)
Check on `8e43cc5c` (builder0): exited 0, 2699/0, ALL JUDGED, sim-baseline 13 unmoved (latch ON), bridge-pooled 18/18.
Series on `8e43cc5c`, builder0, default path, on v `--ground-latch=off`; rows `references/round32/brains/b10-*-8e43cc5c.*`.

| line | on v off | result |
|---|---|---|
| (1) drift census, fresh seeds (Sumps 18 19 × 6 ticks, yard 29 30 × 6, Terminus 12–15 t11) | runs with a flipping crew **0 v 2**; drift moves 107 v 138 (Sumps 35 v 66, worst crew 1 v 15; yard and Terminus identical) | PASS |
| (2) arrivals: Sumps median ≤ off, no run > 5 s later; yard ≥ off | Sumps median **42.75 v 49.86 s**, but **s19 t8 89.3 v 69.4 s (+19.9)**; yard 5/12 v 5/12, crews 113 v 113, identical | **FAIL** |
| (3) arrive, fresh seeds 49–52, n 100 | 93 v 93, discordant 0/0, median 31.0 v 31.0 s | PASS |
| (4) sim-baseline | 13 unmoved | PASS |
| (5) suite | 2699/0 | PASS |
| (6) cost `t.poll.element`, Locks | 0.149 v 0.164 ms | PASS |
| (7) worst run traced first | below | done |

**The losing run, traced** (s19 t8, both arms, `--trace=on --drift-trace`, builder0, `8e43cc5c`; logs
`references/round32/brains/b10-trace/`): identical to 36.6 s. Off: Green_S_2's seat 3 then flips between (0.0, -50.8)
and (-1.9, -41.1) 11 times (the bug). On: the latch holds it at the near grounding (0.0, -50.8), and S_2 parks at
(-2.5, -51.9) from 42 s. S_3 and S_4 must reach the west seat (-9.8, -61.8) from the east; with S_2 parked there, each
reads `no_path`/blocked by the other for ~40 s (two make-room trades), all in at 89.3 s. In the off arm, S_2's flips
kept moving it out to (-1.9, -41.1), which happened to clear that passage. **So the latch does what it is meant to (no
flip), and the loss is a held seat standing in the squad's path, which the bug's dithering cleared by accident.** It is
one run of 12; the median is 7.1 s better.

### NOW (2026-10-16 04:45 PDT)
- **B3b-2c SHIPPED:** merged as main `33321516` (from `5f0ed865`). His bridge 108/108.
- **B10 (the grounding latch alone; the orchestrator's cut from v6):** stream `72e405f4`, main merged `fb303a7f`,
  tooling `ddd1cc56`; bar filed (below). **Check on `ddd1cc56` RUNNING** (04:28 PDT); then `make ground-series` + the
  arrive series (seeds 49–52) + cost in the light lane.
- **C32.10 (seat swap for manoeuvre's H1b), BUILT:** `lab/brains-r32-swap` `f2cc956d`, worktree `godot-brains-swap`
  (offset 9). `Elements.swap_seats(asker, parked) -> String`; tests 4/4 (laptop). Inert until H1b calls it.
- **B5c-v6:** `lab/brains-r32-gate` (worktree `godot-brains-gate`, offset 5) = v5 + main + side gate (+ the latch,
  which now ships as B10). Native mirrored the side gate (`pair/brains-v6-carry` 33db0ac1 + ba8d18d9). Judged on a
  latch-ON base after B10. Tuning run queued on builder0.
- **Worktrees of mine:** godot-brains (stream), godot-brains-gate, godot-brains-swap. Remove at round close.

### B10 bar (the grounding latch ALONE; the orchestrator's cut; FILED before any number; DECLARED; partial: none)
Candidate: stream/brains at the hash its check goes green on (main `33321516`+ merged: T3b-c ON, B3b-2c ON). Arms, one
tree, builder0, the DEFAULT path (native where it runs): **on** = default (latch); **off** = `--ground-latch=off`
(main's rules). Fresh seeds. GDScript only (Element.ground), so no native half.
1. **Drift census** (`make ground-series`: Sumps cell seeds 18 19 × ticks 1 3 6 8 11 16, n 12; yard crossing seeds 29 30
   × the same ticks, n 12; Terminus head-on seeds 12–15 t11, n 4): pooled runs with a flipping crew (> 10 drift moves)
   on ≤ off AND pooled drift moves on < off; plus the named main-side case Sumps s16 t8 (off: 22 flips, never in) with
   no flipping crew on.
2. **Arrivals not down, same series:** Sumps all-within-8 m median on ≤ off and no run > 5 s later (v5's line, judging.md
   *Sumps cell*); yard runs with every crew in on ≥ off and crews in on ≥ off every run; Terminus reported.
3. **Arrive series, FRESH seeds 49–52, n 100:** all_in8_s on ≥ off − 1 AND discordant against ≤ 1; paired median +2 %
   reported.
4. **sim-baseline:** the latch acts in CPU elements too, so maps may move: every moved map listed with its reason
   (a CPU seat whose grounding was pushed), adoption by the orchestrator; unmoved is also acceptable.
5. **The whole suite on the tree** (the check, latch ON), bridge-pooled 18/18.
6. Cost: `t.poll.element` on Locks ≤ 0.5 ms (the latch removes `standable_from` calls; reported).
7. The worst on-arm run of (1)–(3) traced before medians are read.
Ships ON as one commit.

### B3b-2c JUDGED: PASSES EVERY LINE; ships ON (2026-10-16 04:30 PDT). **Merge here: `5f0ed865`**
Its check (builder0): 2666 passed / 0 failed, 25 of 26; the one red was web-match-smoke's first sound (30.6 v 30 s at
load 22), and **web-smoke re-run ALONE exited 0** (R32.4). Series: builder0 light lane, tree `cbddb940` = `5f0ed865`'s
game code (+ a test file + docs), 02:24–04:26 PDT; on = default, control = `--route-seat=off --mouth-held=off` (main's
rules). Rows: `references/round32/brains/b3b2c-*-cbddb940.*`.

| line | on v control | result |
|---|---|---|
| (1) his bridge, the full 108 (locks green/rust × seeds 1–3 × ticks 1–18) | **108/108** v 107/108 (control fails green t5 s2, rim 1: round 28's cell) | PASS |
| (2) bridge-pooled (the check) | 18/18 | PASS |
| (3) arrive, FRESH seeds 45–48, n 100 an arm | all_in8_s **90 v 90**, discordant 0 for / 0 against; paired median 29.9 v 29.9 s (+0.0 %) | PASS |
| (4) counters | crossings_found > 0 in 108/108 on, 0/108 control; 0 in all 200 arrive runs; mouth_held_resends > 0 in 2 of 108 | PASS |
| (5) cost, `t.poll.element` on Locks (`ai-parts-match`) | 0.083 v 0.097 ms (identical call counts; box busy) | PASS (≤ 0.5) |
| (6) worst cells | on-arm 108: no failing cell; the most rim time is green s3 t11 (2.2 s, all 4 across, in 50.4 s), the slowest rust s2 t16 (55.0 s, rim 0.6 s); arrive: every cell's all_in8_s is identical in both arms (100/100), so there is no losing cell to trace | — |

As predicted in the bar, the arrive arms are byte-identical: the seating needs a deck, the mouth guard a deck's mouth,
and with round 28's narrowing OFF both arms share round 26's heading rule. sim-baseline 13 unmoved in the check.
**What he'll notice:** every crew of every squad gets across his bridge (round 28's last cell now crosses), and
squads ordered elsewhere arrive exactly as before. Native: none ported (GDScript only). The commits after `5f0ed865` on
the stream are test splits, shard times, a test and docs; they ride the next check (B10's).

### REPORT so far (2026-10-16 01:10 PDT)
- **B3b-2c** built (`5ca8269d`). Tuning, NOT evidence (builder0 light, `5ca8269d`, n 1 a cell, bridge-series on arm):
  round 28's two cells green t5 s2 (rim 0, 4/4, arrived 34.8 s) and rust t9 s2 (rim 0, 4/4, 41.6 s), B3b-2's traced
  cells green t18 s3 (rim 0, 41.3 s) and rust t8 s2 (rim 0, 28.8 s): the narrowing is not needed for them. Quick gate
  on `5ca8269d` (builder0): 296 passed, 0 failed, exited 0 (1739 s). Bar FILED and accepted by the orchestrator.
  **Pair-tree check on `5f0ed865` (builder0): `make check exited 2`, 2666 passed / 0 failed, 25 of 26 targets;** the one
  red is web-smoke's web-match-smoke "first sound 30.6 s after READY (bound 30 s)" at load 21.96 (WEB SMOKE itself
  PASSED); sim-baseline 13 unmoved, bridge-pooled 18/18, native 0 mismatches, ai-scenarios refused scenario_perf (usual).
  R32.4 (the orchestrator): the series may run on that red; web-smoke re-run ALONE must pass before the merge.
  **Series RUNNING** (light lane, from 02:24 PDT, `cbddb940` = `5f0ed865`'s game code; later commits test/docs only).
- **C32.5 answered** (via the orchestrator, 02:00 PDT): (a) yes, arrived = within 7 m of the slot the element holds for
  the crew at completion, re-seats reported and capped (base + 1.645 se); (b) facekeep unchanged for gang hulls; (c) the
  seating MATCH reads positions only, but an attack-move arriving with no drawn facing lays its halt along the members'
  averaged hull forward (ElementSituation.build → ElementPlan.build's default heading → `_halt`), read once at arrival,
  kept after, replaced by a drawn facing. Pinned: `tests/test_tactics_reseat_heading.gd` (`cbddb940`, 3/3 laptop).
- **Item 4, shard times + splits (C32.8):** `tests/shard_times.txt` rewritten from `5f0ed865`'s check (`89a33339`,
  builder0 busy: proportions only). Splits, test-only, bodies verbatim: `test_tactics_pursuit` 317 s → case + `_8`
  (8 m/s seeds) + `_18` (18 m/s seeds) + the rest, 10 tests before and after (`0eea7f32`; `pursuit_aa` preloads the
  case); `test_tactics_mixed_legs` 114 s → + `_terminus`, 4 tests (`386f8725`); `test_tactics_scenarios_4` 147 s →
  + `_6`; `test_ai_player_orders` 97 s → + `_contact` (`3484e358`). NOT split: `test_tactics_cpu_ambush` (183 s) and
  `test_tactics_cpu_hold` (131 s) are ONE test each (one stage run); `test_combat_suppression_bite` (292 s) is combat's
  file (not in brains' paths). The new files run in the next builder0 gate.
- **Traffic's request (C32.6), DONE `5f0ed865`:** `reach_probe` reads the arena it names (drains the previous lab's
  regions, waits for `TacticsLab.navigation_is_this_arenas`, `REACH_ARENA_NOT_READY` otherwise). Default arena (-25.7,
  7.3): start snaps 0.0 m, both waypoints reachable (builder0 light; rows
  `references/round32/brains/reach-probe-fixture.log`). Round 31's "8.2 m gap" was Terminus's mesh read by mistake.
- **Planner (CP-S):** signature agreed as proposed (`side_gate(slot, facing, unit_id, map, from)`), yard s27 t8 fixture
  sent: goal (-13.016, -47.469), facing (-1, 0.01), from (2.5, -46.1).
- **R32.2 noted:** manoeuvre's H1b settle-short writes `_repair_for`/`_repair_to`; tell manoeuvre if B5c-v6 changes how
  `Movement.repaired_arrival` is read.

### B3b-2c bar (C32.3; FILED to the orchestrator before any number; DECLARED; partial: none)
Candidate: stream/brains at the hash its pair-tree check goes green on (B3b-2b's seating + mouth guard, round 28's
heading narrowing OFF). Arms, one tree, builder0, GDScript and native as the default path runs them: **on** = default;
**control** = `--route-seat=off --mouth-held=off` (main's rules: no crossing seating, no mouth guard, round 26's heading
rule, which both arms share). Native: none ported (Element / ElementPlan / TacticsFormation are GDScript on every path;
native-verify in the check shows it).
1. **His bridge, the full 108** (`bridge-series`, locks green,3 + rust,3 × seeds 1–3 × ticks 1–18, `bridge_verdict`'s
   rule): on **108/108**, or ≥ the control's count (deterministic cells: any cell the control passes and on fails is a
   named regression, traced before anything else).
2. **bridge-pooled 18/18** on (in the check).
3. **Arrive series, FRESH seeds 45–48** (5 maps × 5 squads, n 100 an arm; judging.md *arrive series*): all_in8_s on ≥
   control − 1 AND McNemar discordant against ≤ 1 (C32.3's "not below base − 1.645 se" read as the count row's form);
   the paired median over cells complete in both no slower than +2 % (reported; the row says n > 1000 to decide).
4. Counters: crossings_found > 0 on every on-run of the 108, 0 on every control run; 0 on all arrive runs (no deck).
5. Cost: `t.poll.element` on Locks (`ai-parts-match`) ≤ 0.5 ms a tick, or NOT READABLE on a busy box.
6. The worst on-arm cell of (1) and of (3) traced before the medians are read.
Ships ON as one commit (no native half). Expected and stated in advance: the arrive arms may be byte-identical (the
seating needs a deck; the mouth guard needs a deck's mouth), which is the point of this cut.

### Plan (2026-10-16 00:40 PDT; start = main `6efdf42b`, inherits `e66b41f1`'s green check, no baseline check run)
1. **B3b-2c:** merged `lab/brains-r31-bridge` (`5ed61f91`) into stream (`0fae50a2`, one conflict in `tactics_flags.gd`,
   both sides kept), then `5ca8269d`: `Element.HEADING_REISSUE_TASK_ONLY` default **false** (round 26's rule = main's),
   `--reissue-heading=task` = round 31's candidate arm. Reason: the attribution trace put all 9 lost arrive cells on the
   narrowing; seating + mouth guard are inert on the arrive maps. Native: none ported (Element/ElementPlan/TacticsFormation
   are GDScript on every path). Tuning first on round 28's two cells + B3b-2's two traced cells (n 1, light lane), then
   the pair-tree check, then the bar, then the series (108 + arrive on fresh seeds 45–48).
2. **B5c-v6** once CP-S is on main (planner's signature agreed 00:45: `side_gate(slot, facing, unit_id, map, from)`; yard
   s27 t8 fixture sent).
3. **C32.5** when manoeuvre asks. 4. **`make test-times`** + splits. 5. Stretch: reach-probe to traffic on request.

