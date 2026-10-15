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

### REPORT so far (2026-10-14 ~23:00 PDT)
- **B5c-v5 (1) the A/A — DONE** (`make pursuit-aa`, builder0, stream `3cb76e17` = main's game/, rule off, default path,
  48 runs; rows `references/round31/brains/pursuit-aa-3cb76e17.{jsonl,txt}`; filed by the orchestrator in `judging.md`,
  ruled R31.3). **The test's stage is knife-edge on main:** 8 m/s as written 12/12, every start nudged 0.25 m 9/12 — the
  nudge alone flipped seeds 3 (the test's own), 5, 9; 18 m/s 10/12 both arms, seeds 1 and 9 fail as written.
- **The 18 m/s failures traced** (builder0, seed 1): Green_A_1 shot to hp 0.01 at 5.0 s breaks away home (decide's
  RETREAT, the lead's rule) and failed the per-crew closing/reversal lines, which lacked the let-go line's hurt excuse.
  Not a physics launch; real_velocity not involved.
- **R31.3 (a) `a16585bf`** the hurt excuse on those two lines; **(b) `0415da23`** the robust test (seeds {3,4,5,6,7},
  both visible chases, ≥ 3 of 5). (b) GREEN on builder0 (`make test FILTER=test_tactics_pursuit`, 10 passed / 0 failed:
  5/5 seeds at 8 and at 18 m/s, rule off). (a) alone queued (scratch tree at a16585bf); then (c) the A/A re-run: its
  counts replace 22/19 in v5's pursuit line (ON ≥ OFF − 3 on both start sets).
- **B6** re-based: `lab/brains-r31-sbf` = stream 0415da23 + round 30's three commits + `make sbf-bar` (both arms + the
  filed bar's lines, `tests/tactics/sbf_bar.py`) = `f22d7dcb`; its pair-tree check queues after the current ones.
- **B3b-2** built: `lab/brains-r31-bridge` = stream + `lab/brains-r30-bridge` + the crossing seating matched ONCE per
  task point (held `fixed` until the point changes or a re-seat; `--route-seat-once=off` = round 30's B3b; counter
  `crossings_held`) = `344a772a`; unit 5/0. Tuning on the three named cells (green t5 s2, rust t9 s2, green t18 s3) ×
  {on, once-off} queued; then its bar.
- **B9** queued: scratch tree = stream + traffic-t3b's `traffic.gd` (`a63dde6d`), `reseat-trace` Terminus crossing s33
  t1 `--traffic-on=turns` (GDScript path: turns has no C++ twin).
- **B5c-v5 design decision:** v4's rule UNCHANGED is the first candidate — the A/A removed its parking premise (lesson
  306); `near` is scoped (never the opening seat) only if v4 fails the count line. Pair tree `pair/brains-v5` = stream +
  `lab/brains-r30-gate` + native's `f508ce89` (merged clean; `17e7b08c`): C31.1's `make check` running before any series.
- **B8 `80eea6ec`** (+ `922db8b6` the test restores the switch): `realslow` opt-in, GDScript only. Note for native/the orchestrator: the
  re-seat clock (`Element._watch_progress`) is GDScript on every path and `real_velocity` is filled by the native tank
  drive too, so the switch acts on the native path as well; series run NATIVE=off anyway (R31.1 addendum). Pre-series
  gate (scratch tree flipped ON, `check NATIVE=off`): first launch died in builder0's fresh-folder import (segfault in
  `--import`, before any test); re-launched.

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
