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
