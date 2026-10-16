> **ARCHIVED at round 31's close (2026-10-15/16).** This is the brief as its worker left it on `stream/traffic` at `4a1efa9f`; the live round's briefs are in `_agents/streams/`.

# Stream: traffic (crossing squads: the yielder through ~3 s later, half the bumps — his call; a set-up mortar truck stays set up for a passing squadmate — his call; ORCA stops steering round a 12 m/s ghost; the early-stop hook)

> Read `_agents/orchestration.md` (the worker contract; lessons 306–311), `_agents/game_design.md` **Round 31: his two
> traffic calls**, `_agents/judging.md` (*The table*, *How to write a bar*, *Early stop*), `_agents/workstreams.md`
> **Round 31** (C31.1–C31.11, especially **C31.1**, **C31.3**, **C31.4**), and round 30's traffic report
> (`streams/archive/round30/traffic.md`: *REPORT*, T3b, T1c-b, T4). **You own:** `game/ai/avoidance.gd`, `game/ai/steering.gd`,
> `game/ai/traffic*.gd`, in `game/ai/movement.gd` the give-way block (`right_of_way` through `_blocker`), `_avoid`,
> `_around_friends`, `_ask_behind`, `_hull_within`; `tests/test_traffic*.gd`, `tests/traffic/**`,
> `tests/ai_scenarios/scenario_traffic*.gd`, `tests/test_avoidance.gd`, `mk/traffic.mk`, `tools/series_cache.sh`,
> `tools/quick_tests.sh`, `mk/infra.mk`, `tests/run_tests.gd`'s shard plan. **Granted (standing):** your gate lines at
> brains' and manoeuvre's clocks (C29.3). **The C++ (C31.2):** `right_of_way`, `_avoid`, `Avoidance.solve`, the hold have C++
> twins; send native each settled diff before its commit. **Model:** Opus.

## The lead's direction

Round 28: **TAKE TURNS** — "fewer bumps; both squads arrive a little later." **Round 31, his two calls (2026-10-14, "let's
go with your recommendations for both"):**
1. **Crossing squads:** the yielding squad through a yard crossing ~3 s later (+2.80 s, se 0.22) for half the bumps
   (between-squad hard contacts 176 → 96) is ACCEPTED. Round 30's +10 % line was the orchestrator's number, not his.
2. **A set-up mortar truck** no longer packs up for a passing squadmate (repacks 11 → 0): ACCEPTED; the artillery-rounds
   line that failed was carried by one diverged run and its row was under-sized ~7×.

What he will notice: two of his squads crossing at an angle — the yielder gets through a few seconds later and they stop
shoving through each other. His mortar trucks keep shelling while a squadmate drives round them. (T4: an IFV that backs off
a pinned squadmate is no longer steered straight back into it — visible only with manoeuvre's escapes, CP-H.)

## Where things stand (main `cff4307e`; the last fully green check `48d5aa0d`, then only M1b's three files, checked on `3b3e590d`)

- **T3b** (`traffic-t3b` = cf124433: round 29's v2 + option (b), `CRAWL_REACH_M` 20 m, `--traffic-on=turns`): judged on
  seeds 31–33 — every line passed except the yard crossing clock +2.80 s (se 0.22) v +1.18. Between-squad fast pooled
  176 → 96; Terminus clock −1.17 s; all-in, crews, no wedge fine. Rows under `references/round30/traffic/`.
- **T1c-b** (`traffic-t1cb-judged` = 16780030: `Movement.ask()` refuses while the asked hull is on its fire post; `--traffic-
  off=setup`): census seeds 7–9 — runs with any repack while firing 4/9 → 0/9 (p 0.041), total 11 → 0; friendly-stuck,
  fast contacts, ApproachStage drawn, bridge, the four cases all passed; artillery shots 318 → 163 FAILED on Parade s9 alone
  (171 → 26, both sides' artillery fell, the enemy's refused nothing). `judging.md` now has the census row re-sized from
  that run (sd 34 a run v the old 4.4).
- **T4** (`lab/traffic-t4`: v1 05bb2c22 ORCA's neighbour table reads `Tank.real_velocity`; v2 b63a90c1 the solver's own
  velocity too): nav-terminus-drive seeds 21–23: v1 mixed stuck 198 → 86 crew-s, manoeuvre's oscillating IFV 74 → 12 and
  the loop gone, but rigs 72 → 164 (a War Rig pressed on a friend never fires its stall: manoeuvre's reading, CP-H). Noise:
  paired stuck sd ≈ 60 s a run (not in the table yet — your runs give it a row).
- I3's series cache PROVEN (adopt it: `CACHE=on` for base rows, C31.7); `make quick` 487 s; the crossing clock
  (`cross_clear_s`) is in the probe and the table (rows for both crossing cases).
- The Terminus seat trap at (35.6, 23.9), B's destination (45, 30), under `traffic-t3b`: brains' (relayed, not traced).

## Backlog (in order)

**T3b-c — the crossing re-judged with HIS line (DECLARED; ONE run on fresh seeds = the last).** Candidate = `traffic-t3b`
cf124433 re-based on main (no code change; say so). **First (C31.1): the whole suite with `--traffic-on=turns` ON on a
tree with native's `Traffic.shape` mirror** (native has the hook's diff from round 30; it ports it first) — green before any
series. Bar: round 30's filed T3b bar unchanged EXCEPT line 2 at the yard: the crossing clock's mean paired difference ≤
**base + 3.0 s** (his call; Terminus stays ≤ 0.10 × base median + 1.645 se); fresh seeds (not 1–3, 22–24, 31–33); every row
cites `judging.md`; early stop allowed (C31.3). Ships as a pair with native, the default flipped ON. A clip of his yard
crossing before/after for him.

**T1c-b2 — the set-up mortar truck re-judged with a sized artillery line (DECLARED; ONE run = the last).** Candidate =
`traffic-t1cb-judged` 16780030 re-based (no code change). **First (C31.1):** the whole suite with the rule ON on the pair
tree (no C++ twin: native states "none ported" + `native-verify-scenarios`). Bar: round 30's filed lines with (4) re-sized
from `judging.md`'s new census artillery row: artillery shots not down beyond 1.645 se at the n you run — the table says
what n decides a 10 % loss; if that n is beyond ~27 census runs, write the line as REPORTED and say so before numbers;
(1) stays the deciding line (runs with any repack while firing: arm 0/n, Fisher p ≤ 0.05 v base, base ≥ 4/9-equivalent).
Fresh census seeds (not 1–9). Ships ON.

**T4 — ORCA's ghost, as a CP-H consumer (DECLARED inside C31.4).** v1 (`05bb2c22`) re-based on main behind
`--traffic-off=ghost`; plus the solver's own velocity only if v2's rig numbers (72 → 77) were not luck — one tuning pair
decides which, written down. Unit test: a pinned hull's row in the neighbour table carries its real velocity. **Pair-tree
check first (C31.1)**; native ports `avoidance_gather` and the drive's solve read. Deliver on main behind the switch by
the time manoeuvre's consumers are in (the orchestrator calls CP-H); manoeuvre runs the combined A/B; your consumer's
alone-arm numbers are reported in your Status from manoeuvre's table.

**I4 — the early-stop hook (C31.3, C31.9; early, one commit).** `traffic-series` (and `traffic-census`) print
`tools/judge/sequential.py`'s `SERIES CONTINUE / PASS / FAIL` beside each row from the bar's `--lines` and the rule's
counter; the runner never stops by itself — the stream decides and records the row. Document the invocation in
`verification.md`; the pattern is what brains/manoeuvre copy. Adopt `CACHE=on` for base rows in the same commit (C31.7).

**Stretch:** the friendly half of the creep (a give-way that lets a creeping long hull through), only with the planner's
seam decided (CP-P1) and agreed through the orchestrator.

## How to verify

`make remote T=check` (builder0 only); the pair-tree check BEFORE any series (C31.1); `traffic-series` (with the hook),
`traffic-census`, `nav-terminus-drive` + manoeuvre's `pinned_table.py` for T4, `bridge-pooled`, `native-verify-scenarios`;
`traffic-clip` of his yard crossing. Every number carries commit, machine, workload, n and its `judging.md` row.

## Don't touch

Manoeuvre's drive body / unstick / k-turn executor; the planner's plan source and `game/ai/planner/**`; brains' `_track_
progress`, `_update_phase`, `_approach_gate`, elements, `game/tactics/**`, `tank_brain.gd`, `gunnery.gd`; native's `native/**`;
`game/control/**`, `game/tank/**`; `tools/judge/**` (the orchestrator's).

## Waiting on the lead

Nothing: both calls are made.

## Status

_(the worker keeps this current: every number names commit, machine, workload, n and its table row; bars go to the
orchestrator before numbers; the report at the top)_

_Updated 2026-10-15 ~06:15 PDT (traffic worker, round 31, Opus). Every number names commit, machine, workload, n._

### REPORT (traffic, round 31) — read this first

- **I4 the early-stop hook: DONE** (`e1aaabe1`, fix `33cb2da5`; on main via `traffic-t4` 357ca38b). `tests/traffic/seq_hook.py`
  prints `SEQ <case> k/N … -> SERIES CONTINUE | PASS | FAIL at run j` after every row of `traffic-series` /
  `traffic-census` (`SEQ_BASE`, `SEQ_LINES`, `SEQ_CENSUS_LINES`, `SEQ_COUNTER`), over the finished prefix in runner
  order (jobs now seed-major); `allow=X` carries a lead's allowance; `CACHE=auto` reuses BASE rows (C31.7).
  `make traffic-pytest` 4/0. Documented in `verification.md`. Used live on T3b-c and T1c-b2.
- **T3b-c the crossing: JUDGED, FAIL on one filed line — NOT shipped, his call owed.** Pair tree f5dc4147 (C31.1 gate
  green: 2624/0), builder0, GDScript, seeds 41–43 × 6, n 18: between-squad bumps 191 → 117 (−39 %); his yard line
  +3.38 s v +3.43 pass; **Terminus clock +2.61 s (se 0.55) v +2.07 FAIL**. Worst run traced: the yielder held 4–10 s
  (the rule as designed), no seat/gate circling. Clips for him in `~/projects/clips/round31/t3bc_*`. Question 1 below.
- **T1c-b2 the set-up mortar truck: deciding line NULL as filed (base 6/18 < the filed 8/18) — PARKED, his call owed.**
  Builder0, 33cb2da5, census s41–46, n 18: repacks while firing 6/18 → 0/18 runs (Fisher p 0.0095), artillery 434 →
  437, guards inside — all REPORTED. Pre-census gate dc8fcbf6: 2630/0, pit alone moved. Question 2 below.
- **T4 ORCA's ghost (CP-H consumer): v1 delivered OFF, ghostself OUT.** Tuning (builder0, dc8fcbf6, Terminus drive
  s24–29, n 12): v1 v v1+ghostself pinned 126 → 598 (UP beyond 2 se) → v1 alone. Merge branch `traffic-t4` =
  `357ca38b` (OPT-IN per R31.1). **PARKED for CP-H** (orchestrator, 07:15: the ghost-ON gate would land after the 09:00
  cutoff; CP-H runs without T4, native drops the ON gate). `0475758f` (= native + 357ca38b, T4 OFF): builder0 `make
  check exited 2`, 2639 passed / 0 failed, sim-baseline unmoved (13), RED on the engine-log gate alone — my
  `test_traffic_ghost` never disposed its TacticsLab (14 ObjectDB / 4 resources leaked). Fixed with native's fafe49ea
  lines: **traffic-t4 = `aaa7fa8e`**; the closing check = native's re-check on fafe49ea — **GREEN** (builder0, 10:55 PDT: `make check exited 0`, 2639/0, 26 targets, ALL JUDGED, sim-baseline unmoved on 13 maps, no leak lines). Next round: the ON gate (`pair/t4-on` 93c85531, `check
  NATIVE=off`) and T4 v1 as its own consumer A/B.
- **Stretch:** not started (waits on CP-P1). Seam reply sent: `Movement.manoeuvring()` rather than a wider `in_kturn()`.
- **Green check:** this stream's merge candidate is `traffic-t4` `aaa7fa8e`; its check is native's pair/t4 re-check on
  **fafe49ea = GREEN** (builder0 10:55 PDT, exited 0, 2639/0, ALL JUDGED, sim-baseline unmoved) — the stream's closing green check, **MERGED to main as `dc9792f9`** (T4 v1 + ghostself opt-in default OFF; I4 tooling + CACHE=auto for every stream). Stream complete apart from the lead's two answers (T3b-c Terminus line, T1c-b2 ship) (the first, 0475758f, was red on my test's leak alone). stream/traffic itself is a record branch (parked trees), not a merge candidate.
- **R31.9 stretch (test-time splits):** nothing of traffic's to split. test_nav_dynamic_window (157 s) tests CombatMotion's A11 lattice, which isn't traffic's code. Traffic's timed tests on main's tests/shard_times.txt are all < 60 s (test_traffic_hold_live 30.7 s, test_traffic_feed 12.9 s). Told the orchestrator.
- **Requests:** native — the two T4 pair checks. Orchestrator — the two questions to him; on yes, the follow-ups in
  *Kept branches*.
- **What to playtest:** nothing new in play from this stream (all parked or OFF). His clips: `~/projects/clips/round31/`.
- **Lessons for the doc:** (a) a bar's base-rate precondition must be sized from the pooled base rate, not one run's
  (8/18 from 4/9 voided a clean 0/18); (b) a crossing line written as "10 % of the median" on a 12 s clock is the
  same ~1 s guard that failed in round 30 — when the lead sets a price for one crossing, ask whether it covers the
  other before judging; (c) shell-spawned wrappers die at a cwd reset: `systemd-run --user`.


### The plan (ordered)

1. **I4 the early-stop hook** first (tooling, every stream copies it): `tests/traffic/seq_hook.py`, wired into
   `traffic-series` / `traffic-census`, `CACHE=auto` for base rows. Committed `e1aaabe1`; check on `ab3351fb` running.
2. **T3b-c**: candidate re-based (`e57f93d2`, cf124433's game/ + tests, NO code change); native's teardown finding taken
   (`ab3351fb`). Native's mirror `413252ea` (stream/native); pair tree = both + `DEFAULT_OFF = []`; `make remote T=check`
   on it BEFORE the series (C31.1). Then the judged series with the hook.
3. **T1c-b2**: re-base `traffic-t1cb-judged`, pair-tree check (no C++ twin: native states "none ported" +
   `native-verify-scenarios`), the bar below, the census. Re-based at `6d19a3d9` (no code change; the rule ON by default;
   the census hook's metrics `rwf_any`, `art_shots`). Bar FILED by the orchestrator (main f1863f9b6).
   Native: NONE PORTED (confirmed: ask() is reached only through GDScript callbacks). C31.1 gate = the whole suite green
   on a tree carrying 6d19a3d9 + `traffic-native-verify` + `native-verify-scenarios` on it.
4. **T4** behind `--traffic-off=ghost`, OPT-IN per the orchestrator's R31.1 (default OFF; naming it turns it ON).
   v1 re-based at `f9c765c76` (`Traffic.OPT_IN = ["ghost"]`: named in `--traffic-off=` or `--traffic-on=` → ON;
   `test_traffic_ghost` 4 tests). Diff sent to native for `avoidance_gather`. Next: the v1 v v1+v2 tuning pair
   (nav-terminus-drive seeds 21–23) decides whether the solver's own velocity rides along; R31.1's pre-series gate
   (`check NATIVE=off` with ghost flipped ON in a scratch tree).
   **R31.1 addendum (main 47be4134):** `ghost`/`ghostself` live in Traffic._off, and the native drive ignores them until
   native mirrors them, so the gate AND every T4 series (tuning and judged) run NATIVE=off / `--brains-off=native`.
5. Stretch only after CP-P1.

### Bar: T3b-c (pre-registered, sent to the orchestrator before any number; DECLARED; ONE run = the LAST attempt; no partial)

Candidate: round 30's `cf124433` game/ re-based on main = stream/traffic `ab3351fb` (no code change; the tests' teardown
restores the default), paired with native's `Traffic.shape` mirror, `Traffic.DEFAULT_OFF = []` (turns ON). Judged on the
PAIR tree once its `make check` is green (C31.1), builder0, both arms one commit, GDScript path (`--brains-off=native` is
not used: the pair is the default path; the series runs the default path), **fresh seeds {41, 42, 43} × ticks
{1,3,6,8,11,16}**, n = 18 a case, the four cases, 90 s. **Base `--traffic-off=turns`** (one flag, lesson 309), arm no
flag. Read by `tests/traffic/turns_verdict.py --allow yard_open/cross=3.0` (round 30's filed lines, `cf124433` + this one
change). Lines, rows of `judging.md` *The table* (`references/round30/sizing/table.csv`):
1. between-squad fast pooled over the two crossing cases down ≥ 25 % (row: traffic-series xfast, n 16 decides −25 %;
   pooled n 36); neither crossing case up beyond base + 1.645 se (+19.1 Terminus, +12.6 yard).
2. **the crossing clock**: yard crossing mean paired `cross_clear_s` ≤ **+3.0 s + 1.645 se (HIS line)**; Terminus crossing
   ≤ 0.10 × base median + 1.645 se (row: xclear sd 4.44 Terminus, 0.92 yard; se the run's own paired sd/√18, quoted).
3. crews every case ≥ base − 1.645 se (−4.07, −4.77, −6.81, −1.64). 4. no wedge (> 1 crew never in where the base had
   none); the worst run's trace read before the medians. 5. same-squad fast per crossing case ≤ base + 1.645 se (+43.7,
   +52.6). 6. head-on cases within 1.645 se on fast, between-squad fast, all-in (+194.4/+116.5/+9.62 Terminus,
   +8.38/+5.81/+3.82 yard). 7. all-in medians REPORTED with se. Also: bridge-pooled 18/18 (pair tree);
   `test_traffic_turns_live` fires, counters reported (`tr_cross_verdicts`, `tr_cross_slowed`, `tr_cross_reach_free`);
   CPU mirror on the Terminus crossing reported (no worse on 1/3/4).
**Early stop (C31.3)** — the hook's lines, table sd: `yard_open/cross=xfast:gain:0.25,xclear:guard:abs=1.0:allow=3.0,
arrived:guard:0.05 terminus/cross=xfast:gain:0.25,xclear:guard:0.10,arrived:guard:0.05
yard_open/head=xfast:guard:0.2,arrived:guard:0.05 terminus/head=xfast:guard:0.2,arrived:guard:0.05`,
`SEQ_COUNTER=tr_cross_verdicts`. Stop only on a row where every case reads SERIES PASS/FAIL; then `turns_verdict.py`
reads the rows that ran. Ships as a pair with native, the default ON. A clip of his yard crossing before/after.

### Bar: T1c-b2 (pre-registered before any number; DECLARED; ONE run = the LAST attempt; no partial)

Candidate: round 30's `16780030` game/ (+ `02dc1433`'s measurement additions) re-based = stream/traffic `6d19a3d9`, NO code
change, the rule ON by default (`--traffic-off=setup` = main). No C++ twin: native states "none ported" and
`native-verify-scenarios` + `traffic-native-verify` run on the tree (C31.1); the WHOLE suite green on it before the census.
Judged: builder0, both arms one commit, **fresh census seeds {41,…,46}** × the three census cases (Sumps 1000, Parade
2000, Foundry 2000), **n = 18**, 150 s; base `--traffic-off=setup` (one flag), arm no flag. Row: `judging.md` *The table*,
probe "traffic-census (3 arenas x seeds)".
1. **(deciding) the defect:** runs with any repack while firing: arm 0/18, one-sided Fisher p ≤ 0.05 v base, and base ≥
   8/18 (the 4/9-equivalent; below it the line is NULL, lesson 300 — say so, do not ship on it).
2. friendly-stuck s ≤ base + 1.645 se (row: sd 32.2 a run → +225 crew-s total at n 18).
3. fast friendly contacts ≤ base + 1.645 se (row: sd 6.84 a run → +47.7 total).
4. **artillery shots REPORTED, not judged** (said before numbers): row sd 34.1 a run, base 24.9 a run; a 10 % loss (2.5 a
   run) needs ~1150 runs at 80 %/5 % — far beyond ~27 — and at n = 18 the MDE is ~20 a run (~80 % of base). Reported:
   totals, mean paired with se, per-side per-battery counts, and the worst run traced (both sides' artillery).
5. brains' ApproachStage drawn artillery, fresh seeds {41,42,43} × six ticks, n = 18 both arms: give-way repacks down,
   from the side 18/18, first round ≤ clicked + 30 s, alive within 1.645 se.
6. bridge-pooled 18/18 with the rule on. 7. the four traffic-series cases (seeds 41–43): rows equal field for field
   (bar T1c-b's own counters), or within T3b-c's guards with no wedge.
**Early stop (C31.3):** `SEQ_CENSUS_LINES='rwf_any:rate:0.02:0.44 fstuck:guard:0.2 fast:guard:0.1'` (table sd; the rate
line's p0 = round 30's base 4/9); stop only on a row where all read SERIES PASS/FAIL; (1)'s Fisher reads the rows that ran.

### T3b-c JUDGED — FAIL on one filed line (the Terminus crossing clock); not shipped (last attempt, no partial)

Builder0, pair tree `f5dc4147` (native 413252ea + traffic ab3351fb, turns ON), GDScript path (`--brains-off=native` both
arms), seeds 41–43 × {1,3,6,8,11,16}, n = 18 a case, base `--traffic-off=turns`, full grid (no early stop). Verdict
`references/round31/traffic/t3bc_verdict_f5dc4147.txt` (`turns_verdict.py --allow yard_open/cross=3.0`):
- **Terminus crossing clock +2.61 s (se 0.55) v limit +2.07 (0.10 × 11.7 + 1.645 se): FAIL.** A steady shift, not a
  wedge: 16/18 later; worst s43/t1 +5.3 s (squad B, the yielder, 9.5 → 16.3 s); B's own crossing +4.22 s (se 0.64), A's
  −1.09. Round 30's seeds 31–33 read −1.17 s here.
- **Yard crossing clock (his line) +3.38 s (se 0.26) v +3.43: pass** (narrowly).
- Between-squad fast pooled 191 → 117 (−39 %) pass (Terminus 93 → 61, yard 98 → 56); crews 176→178, 167→168, 176→176,
  179→179; no wedge in the arm (base had two); same-squad 148→149, 145→148; head-on cases within 1.645 se; all-in median
  reported Terminus 39.5 → 32.9, yard 66.4 → 75.5.
- Hook (table sd): yard SERIES PASS at run 7, head-ons PASS (6, 18), Terminus SERIES FAIL at 18 (xclear, truncation).
- **Worst run's trace (s43/t1, both arms; `references/round31/traffic/t3bc_trace_s43t1/`): the yielder simply waits.**
  All five B crews held at the share (pace 0.30–0.40) from 4 s to ~8–10 s, the rear crew B_2 at 0.05 by 8 s (x −19 v
  base +11.7); all released by 10 s at pace 1.0. One extra event: B_5 overshoots north, k-turns at 12 s, blocked at
  14 s, arrives 18 s (base 12 s). No seat circling, no arrival-gate flip (brains' trap is absent here).
- If he says no, or T3b is ever re-judged: the honest pairing is T3b on top of brains' arrival gate v5 v v5 alone
  (brains: T3b + v4 frees round 30's s33/t1 seat trap, all-in 61.4 → 27.5 s). v5 PARKED this round (orchestrator), so
  any re-judge waits for round 32's gate fix.

### T1c-b2 — deciding line NULL as filed (base 6/18 < 8/18); PARKED, the rest REPORTED (orchestrator's ruling)

Builder0, `33cb2da5` (= dc8fcbf6 + an echo fix; the rule ON), GDScript path (`--brains-off=native`), census seeds 41–46 ×
Sumps 1000 / Parade 2000 / Foundry 2000, n = 18 paired, 0 missing; base `--traffic-off=setup`. Rows
`references/round31/traffic/t1cb2_judged_census_*_33cb2da5_seeds41-46.jsonl`.
- **(1) runs with a repack while firing: base 6/18 → arm 0/18** (one-sided Fisher p 0.0095); total 10 → 0. **The filed
  precondition (base ≥ 8/18) fails → the line is NULL as filed; not shipped on this run** (the bar is not re-read).
- REPORTED: artillery shots 434 → 437 (mean paired +0.17, se 0.39 a run: no diverged run this time); friendly-stuck
  746 → 787 crew-s (+2.28 a run, se 1.12; guard +225 total: inside); fast friendly contacts 1021 → 997 (guard +47.7:
  inside); give-way repacks 31 → 26; refusals on the post 0 → 45.
- Hook (table sd): `rwf_any` PASS, fstuck PASS, fast PASS → SERIES PASS at run 18 (the rate line's PASS is the arm's own
  0/18 v p0 0.44; the bar's precondition is a base count, outside the hook).
- Not run (orchestrator: cannot change a parked verdict; builder0 for CP-H/CP-P1): ApproachStage, the four cases,
  `traffic-native-verify`. The chain was stopped by its unit after the census arm (nothing left on builder0).
- For sizing: base rates now 4/9 (round 30, s7–9) and 6/18 (s41–46): pooled 10/27 ≈ 0.37 a run; a 4/9 line
  over-states it. Next bar: precondition from the pooled rate (≥ 5/18 for p ≤ 0.05 at arm 0/18), or n = 27.

### T4 for CP-H (cutoff 09:00 PDT 2026-10-15, the orchestrator's)

- **Merge branch `traffic-t4` = `357ca38b`** (one commit on main c6ffb37e; worktree `godot-traffic-t4`): T4 v1 (`ghost`) +
  `ghostself`, both OPT-IN via `Traffic.OPT_IN`; `test_traffic_ghost`; and ALL of I4's tooling (its merge path now that
  T3b's pair does not ship). No T1c-b, no T3b on it. Native builds pair/t4 on it (ghost ON for the gates).
- Tuning (builder0, `dc8fcbf6`, nav-terminus-drive seeds 24–29, GDScript path, n = 12 paired, `pinned_table.py`): base v
  v1: stuck 492 → 324 crew-s (se 153), pinned all 212 → 126 (se 110), rigs 81 → 71 (se 10), all within 2 se.
  Round 30's v1 rig regression (72 → 164) was on M4b's tree and does not appear on main.
  **DECIDED: v1 alone; ghostself OUT of CP-H.** v1 v v1+ghostself: pinned all 126 → 598 (+472, se 185, UP beyond 2 se),
  rigs 71 → 311 (se 168), stuck 324 → 799 (se 264); base v v2 pinned 212 → 598 UP. ghostself stays opt-in, tuning only,
  unmirrored. Tables and logs: `references/round31/traffic/t4_tuning_dc8fcbf6/`.

### Kept branches (round 31)

`traffic-t3bc-judged` = f5dc4147 (T3b-c's judged pair tree: native 413252ea + traffic ab3351fb, turns ON) — ships as is on
his yes to the Terminus line; `traffic-t1cb2` = 33cb2da5 (T1c-b2's judged tree, the rule ON) — on his yes: on then-current
main, traffic-native-verify + a check with the rule ON + the pit baseline re-recorded, then merge; `traffic-t4` = 357ca38b
(T4 merge-OFF + I4's tooling; native's pair/t4 0475758f, pair/t4-on 93c85531).

### Stretch (the friendly half of the creep)

Waits on the planner's seam (CP-P1) decided and agreed through the orchestrator (brief). Not started this round; my
reply on the seam (a `Movement.manoeuvring()` for a planner-held hull, read by the crossing row and `ask()`) is the
traffic side's part of it.

### His clips (T3b-c)

`~/projects/clips/round31/t3bc_*` (+ `t3bc_CAPTION.txt`): both crossings, seed 43 tick 1 (the worst Terminus run), pair
tree f5dc4147, before = rule off / after = rule on. Terminus A 11.0 / B 9.5 s → A 9.5 / B 16.3 s; yard A 8.3 / B 8.2 →
A 8.6 / B 10.6 s. Looked at: at 10 s the squads are interleaved in the junction before; after, A passes in a column and
B bunches up behind it, held.

### Gate results so far

- **T3b-c C31.1 gate PASSED** (native's pair tree `f5dc4147` = native 413252ea + traffic ab3351fb + `DEFAULT_OFF = []`;
  builder0 `make check exited 2` on sim-baseline alone, all 13 maps moved as a turns-ON tree must; 2624 passed / 0 failed;
  native-verify-scenarios 0; twin tests 0). Judged series running there: base arm 72 rows, 0 missing.
- **T1c-b2 pre-census gate** (`dc8fcbf6`, builder0, read from its build/ because the wrapper was reaped): test 2630 / 0;
  23 of 25 CHECK_TARGETS in done/; native-verify-scenarios 0 mismatches; sim-baseline red on **pit alone**
  (e03377eab0ab0389 → a8fe8e14bea01674, the declared rule; twelve maps unmoved). `traffic-native-verify` runs at the END
  of the judged chain; **the orchestrator's condition: red there = the census VOID.**
- `ab3351fb`'s own check never produced a verdict: Godot `--import` hung 70 min, wrapper reaped. The tooling rides
  the T3b pair instead (orchestrator).
- **Process (round 31):** wrappers launched from the shell are reaped at a shell-cwd reset, even with setsid/nohup.
  Long runs go under `systemd-run --user --unit=traffic-<what> --collect` (units: traffic-t3bc, traffic-after-check,
  traffic-t1cb2). Scratch worktrees: `godot-traffic-pair` (f5dc4147), `godot-traffic-t1cb` (33cb2da5).

### Questions for the lead

1. **(T3b-c, his call)** "At a Terminus street crossing, the squad that gives way now also gets through about 2.6 s later.
   It's the same rule and about the same price as the yard's ~3 s you accepted, and the two squads bump about a third
   less there (93 → 61 hard bumps)." **Recommendation: yes, let his ~3 s cover both crossings.** If he agrees, the rows
   already judged pass that line (+2.61 ≤ 3.0 + 1.645 × 0.55), and the pair ships as checked (f5dc4147).
2. **(T1c-b2, his call)** "A set-up mortar truck no longer packs up to let a passing squadmate by: on fresh seeds it
   happened in 6 of 18 fights before and 0 of 18 after, and the trucks fired just as much (434 v 437 rounds). It missed
   only because I'd written the bar to need the problem in at least 8 of 18 fights first." **Recommendation: ship it**
   (his round-31 call already wanted the behaviour; every guard held, and artillery fire did not fall).

### Requests to other streams

- native: `Traffic.shape` mirror (sent; `413252ea` in progress).
- planner / manoeuvre (via the orchestrator, 2026-10-14): do NOT widen `in_kturn()` for a planner-held hull. Instead add
  a `Movement.manoeuvring()` (in_kturn() or, with the planner ON, `PlannerSeam.live`), owned by the planner. Traffic
  reads it in the crossing row (traffic.gd:913) and in ask(): a held hull refuses, and the asker goes round. It is
  identical to today with the planner OFF. Manoeuvre decides its own two readers.

