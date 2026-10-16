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

### REPORT so far (2026-10-16 01:10 PDT)
- **B3b-2c** built (`5ca8269d`). Tuning, NOT evidence (builder0 light, `5ca8269d`, n 1 a cell, bridge-series on arm):
  round 28's two cells green t5 s2 (rim 0, 4/4, arrived 34.8 s) and rust t9 s2 (rim 0, 4/4, 41.6 s), B3b-2's traced
  cells green t18 s3 (rim 0, 41.3 s) and rust t8 s2 (rim 0, 28.8 s): the narrowing is not needed for them. Quick gate
  on `5ca8269d` (builder0): 296 passed, 0 failed, exited 0 (1739 s). Bar FILED and accepted by the orchestrator.
  **Pair-tree check RUNNING on `5f0ed865`** (launched 01:09 PDT), then the series.
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

