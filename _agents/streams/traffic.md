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
