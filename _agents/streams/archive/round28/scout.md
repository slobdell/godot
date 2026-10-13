> **ARCHIVED (round 28 closed 2026-10-13; native continues).** Kept as the stream left it; current state is in `HANDOFF.md`.
# Stream: scout (fixed guns that keep shooting while suppressing; every scout passes its duel bars)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 27 direction*,
> `_agents/workstreams.md` *Round 28*, and round 27's scout report (`streams/archive/round27/scout.md`: CP-S, the census,
> S4's write-up). **You own:** `game/ai/combat_motion.gd`; in `game/ai/tank_brain.gd` the fight-motion hunk
> (`_combat_move`, `_hold_motion_plan`, the ORBIT controller and its constants, the SUPPRESS motion for a fixed gun —
> agree the exact hunk with brains through the orchestrator before editing); `tests/test_ai_combat_motion.gd`,
> `tests/test_scout*.gd`, `tests/scout/**`, `tests/ai_scenarios/scenario_scout*.gd`, `mk/scout.mk`. `decide` is C++: a
> change to it goes to native as a diff first (C28.2).

## The lead's direction (2026-10-11, watching `make showmatch`)

> the scouts absolutely suck at attacking targets … they drive super close to their target, leaving no room for them to
> turn and maintain their target, and they don't seem to drive backwards when they have that option

Round 27 shipped the lay planner (CP-S): gun on target in reach +16 pts, contacts down; kills/damage unchanged within noise.
What he will notice next: scouts that also keep their gun on target while suppressing, and fewer scouts dying for nothing.

## Where things stand (main `ecc0d6e0`, green)

- CP-S: `CombatMotion.plan_lay`, a 2.1 s rollout over the fixed gun's plant (`--scout-off=gunlay`); only ENGAGE uses it.
- Census (seeds 13–36): 45 % of a scout's fight time is outside the planner: ENGAGE out of reach/sight 24 %, **SUPPRESS
  20 %**, FLANK 9 %, CLEAR_LANE 4 %. Flat kills/damage most likely sit there.
- S4 (the short-halt gate) not shipped (`scout-s4-halt`): gang_scout's spear gun lost standing shots on crossing targets.
  law_scout passes 4/5 duel bars, gang_scout 3/5.

## Backlog (in order)

**S1 — a fixed gun under SUPPRESS lays itself.** The planner (or its idea) for SUPPRESS: hull on the suppressed point,
turning room kept. Bar before numbers: on fresh census seeds, fixed-gun gun-on-point share during SUPPRESS up ≥ 10 pts
outside 2 se; all-fight on target not down; contacts not up; outcomes (kills, damage, deaths) reported. DECLARED.

**S2 — outcomes.** Why kills/damage stayed flat: per-seed, where scouts die and what they were doing (option × motion at
death). If a rule follows, its own declared change.

**S3 — law_scout and gang_scout duel bars** (stretch): the halt gate on turning room only (round 27's untested
candidate), judged on fresh seeds.

## How to verify

`make remote T=check`; `make scout-census` (fresh seeds after any tuning), `scenario_scout_cross` per unit; a before/after
showmatch clip of a suppressing scout for him.

## Don't touch

Brains' tactics/elements and the rest of `tank_brain.gd`; manoeuvre's and traffic's movement blocks; `native/**`.

## Waiting on the lead

Nothing.

## Status

_Round 28 scout worker, started 2026-10-12 afternoon from `c6e32d03`. **FINAL REPORT 2026-10-13: stopped at the
orchestrator's word (S3 done; S1's retry cancelled with M2).**_

### Report (the short version)
- **Merge here: `de45a69f` is green** (builder0, `make check exited 0`, **2521 passed, 0 failed**, 25 targets ALL
  JUDGED incl. native-verify-scenarios; all thirteen sim lines unmoved; determinism `2875411ff4ec6be7`). Commits after
  it are this Status only. **S3 (DECLARED) ships** in it.
- **What he will notice (S3):** a gang scout (the spear-gun car) that ends up nose-to-side against a tank no longer
  stops dead there for its reload — it backs off and keeps the gun on the tank (his round-27 case: it touched the tank
  in 9 of 18 runs, now 0). Everywhere it can still turn, it keeps its standing shots exactly as before.
- **S1 did NOT ship** (scouts laying their hull on the point they suppress): the scenario passed, the blind census did
  not (+6.3 pts se 5.2; kills 77 → 57). Parked on `scout-s1-suppresslay` for round 29 with manoeuvre's creep-as-legs
  idea (the remaining time is wheeled hulls coming round in legs).
- **S2 (for brains):** fixed guns mostly die under ordered MOVEs (23–30 %) and RETREAT (14–17 %), not in the fight
  motion (SUPPRESS 3–7 %). No scout rule follows.
- Cost (C28.4): `make scout-cost` at `de45a69f`, builder0, Sumps ~20–25 a side, n = 9: plan_lay **0.032 ms a tick mean,
  0.101 max**; S3's gate is one distance check per short-halt test.
- Not done: the brief's before/after showmatch clip of a suppressing scout (S1 did not ship; nothing to show). S3's
  evidence is the scenario (`make scout-cross SCOUT_UNIT=gang_scout`). No screenshots made this round.

### What to playtest (exact commands)
- `make scout-cross SCOUT_UNIT=gang_scout` (his case, pooled; `NAV_FLAGS=--scout-off=halt` for main's).
- `make showmatch SEED=130` (Yard Open, Gangs v Law: gang scout contacts 6 → 3 in the census).
- `make scout-cross SCOUT_FILTER=scenario_scout_suppress` (S1's spec: behind and crossing PENDING on main).

### Merge notes (shared-file edits)
- `game/ai/tank_brain.gd`: inside `_combat_move`'s short-halt block only (`halt_ok`, my hunk). `decide` untouched (no
  native port); no Movement member written (no `native_stale` door).
- `game/ai/combat_motion.gd`: `halt_gated`, `halt_allowed` (mine). New: `tests/ai_scenarios/scenario_scout_suppress.gd`
  (+ `.uid`), census tooling in `tests/scout/`. Baseline `ai_scenarios_count.txt` 51,0,3,0 → 53,0,5,0 (`046b4481`,
  builder0, declared). Kept branches: `scout-s1-suppresslay` (S1 + spread weighting), `scout-s4-halt` (round 27).

### Questions for the lead
None.

### Requests to other streams
- **brains** (via the orchestrator, sent): fixed-gun deaths under ordered MOVE / RETREAT (S2 table below); round 27's
  PURSUE first-think drive-in (2 m arrive) is still where the S1 scenario's first case touched (`right90`, traced).

### Plan (ordered)
1. **S1** (CP-S1, DECLARED): census measures SUPPRESS gun-on-point (Gunnery's suppress gate) and SUPPRESS time by move
   order; `scenario_scout_suppress` (a pinned tank right90 / behind / close 8 m / crossing — a pinned crew is what makes
   a scout SUPPRESS, found by probe); the change: `_act`'s SUPPRESS arm gets one first branch for a fixed gun on the lay
   planner (`_lays_suppressing`) → `_combat_move(s, contact, spot)` with the point as a stationary target, no short
   halt; `--scout-off=suppresslay` the A/B. Hunk granted by the orchestrator (2026-10-12). Bar pre-registered (below).
   Decided: reuse `_combat_move`/`plan_lay` rather than a second planner — one rollout, one set of tests; the bounding
   crew keeps brains' bound-slot move (the element's pace outranks a lay).
2. **S2** outcomes: per seed where fixed guns die and what they were doing (option × motion at death).
3. **S3** stretch: the halt gate on turning room only, fresh seeds.

### CP-S1 bar (pre-registered with the orchestrator 2026-10-12, before any census number)
PRIMARY blind: census fresh seeds 61–84, new v `--scout-off=suppresslay`, gun-on-point share during SUPPRESS paired
per seed (≥ 1 s SUPPRESS both arms): ≥ +10 pts outside 2 se ships; +5..+10 outside 2 se ships with a note only if the
scenario passes all four; else no ship. < 12 paired seeds → extend 85+. GUARDS: all-fight on target not down beyond
2 se; fight-option contacts not up beyond 2 se; **SUPPRESS's share of fight time not down beyond 2 se** (the
orchestrator's addition, accepted; absolute SUPPRESS seconds per arm reported); outcomes reported. SCENARIO pooled n = 18 a case: on point ≥ 50 %,
median first-on ≤ 3.0 s, 0 contacts, all four; off arm fails ≥ 1. And check green, native-verify-scenarios green,
thirteen lines declared, determinism, cost ≤ 0.5 ms (`make scout-cost`).

### S1: the scenario (builder0, tree on `c6e32d03` + S1, pooled n = 18 a case; seen before the census, disclosed)
| case | on point off → new | median first-on s | contacts | bars off / new |
|---|---|---|---|---|
| left90 (20 m off the left side) | 0.83 → 0.83 | 2.1 → 1.2 | 0 / 0 | pass / pass |
| behind (20 m astern) | 0.71 → 0.80 | **3.5 → 2.5** | 0 / 0 | FAIL / pass |
| close (8 m dead ahead) | 1.00 → 1.00 | 0.0 → 0.0 | 0 / 0 | pass / pass |
| crossing (20 m ahead, W→E) | **0.48 → 0.61** | 1.1 → 0.7 | 0 / 0 | FAIL / pass |
Two scenario fixes made on one-run probes, before either pooled arm was judged (disclosed): the first `right90` case
(20 m east) had no sight line at the start, so brains' PURSUE ("ordered, closing in", 2 m arrive) drove the scout to
6 m before SUPPRESS began — all 33/36 contacts were that approach, both arms; mirrored to `left90`. The setup floor
(SUPPRESS ≥ 50 % of the run) read 5.6 s on the crossing (the tank leaves reach); now 30 % — a setup check, not a bar.

### S1: the trace (census seeds 1–12, traced, NOT judged; builder0)
- v1 (`ee9d7583`): on point during SUPPRESS +7.1 pts se 6.2; SUPPRESS 484 → 300 s; 43 % of SUPPRESS reversing.
  Traced seed 5: with the gun on a still point, the reverse that brought it on and the brake TIED on every step and
  commitment kept the reverse (2 s at 5.8 m/s, range 28 → 35 m, moving spread). Fix (`c138e589`): under SUPPRESS a
  step on the point is weighted by Match.shot_spread's moving factor, 1 / (1 + 1.5 × |v| / top). ENGAGE unchanged.
- v2 (`c138e589`): on point **+5.86 pts se 5.78** (pooled 43.7 % → 56.2 %); SUPPRESS 484 → 338 s; share of fight
  −7.4 pts se 4.3; all-fight on target +0.7 se 2.9; fight contacts −2.8 a seed se 2.4; kills 9 → 7, damage +35 a
  seed se 36, deaths 190 → 176. SUPPRESS by motion (new): stop/hold 40 % (88 % on point), reverse/lay 38 % (41 %),
  forward lay 20 % (26 %): the moving time is wheeled hulls coming round 40–110° in legs.
- Known and left (brains'): a fixed gun of a squad on `hold` keeps the face chain (`_moves_while_fighting` false); the
  suppress point re-lays every 1.5 s onto a moving target's lead, so a wheeled hull re-turns each time.

### S2: where fixed guns die (census seeds 1–12, builder0; last ticked option/motion; both arms of the trace)
off n = 189 / new n = 175: **under an ordered MOVE 23 % / 30 %**, RETREAT 14 % / 17 %, SPOT 14 % / 9 %, ENGAGE
(hold+lay+ring) 24 % / 26 %, SUPPRESS 7 % / 3 %, TAKE_COVER 5 % / 3 %. Killers: IFVs and tanks ~55 %, lancers ~11 %,
artillery 6–12 %. Reading: the fight motion is not where most scouts die — a quarter to a third die while driving an
ordered move (round 27's census put most enemy contacts there too) and ~15 % while retreating. Those are brains'
(orders/retreat), not a scout rule: filed as a request. No S2 rule of mine follows from this.

### S1 blind result: DOES NOT SHIP (census seeds 61–84, builder0, game/ = `c138e589`, new v `--scout-off=suppresslay`)
PRIMARY gun on point during SUPPRESS **+6.32 pts, se 5.17** (n = 13 paired, 2 se 10.3: inside). Guards held:
all-fight on target −0.92 se 1.64; fight contacts +0.38 a seed se 2.22; SUPPRESS share of fight +0.46 se 2.33;
SUPPRESS 958 → 935 s (on point 40.7 → 45.5 % pooled). Outcomes: **kills 77 → 57 (−1.0 a seed, se 0.5)**, damage
−110 a seed se 108, deaths 331 → 317 (most of the kill drop in two diverged matches: 62 Gorge 21 → 13, 80 Archipelago
18 → 12). Kept on branch **`scout-s1-suppresslay`**; `game/` reverted on `stream/scout`. The orchestrator allows ONE
last attempt after manoeuvre's M2 (creep lift: a paced 120° turn 14 gear changes / 7.8 s → 0 / 2.8 s) merges: the
branch on main + M2, fresh seeds 85–108, the same bar, kills promoted to a guard.

### S3 bar (pre-registered with the orchestrator, accepted before any number)
Change: a fixed gun on the lay planner short-halts only OUTSIDE its turning room (`CombatMotion.halt_allowed`, no bearing
condition); `--scout-off=halt` = main. PRIMARY: `scenario_scout_cross` gang_scout his case pooled n = 18, contact runs
≤ 4 of 18 with the off arm on the same commit ≥ 7. GUARDS: the gang cases CP-S passed still pass; scout 5/5 and
law_scout 4/5 unchanged. BLIND census 109–132: gang fight contacts, ENGAGE in-reach on target, fixed-gun kills,
all-fight on target — none worse beyond 2 se; ≥ 12 seeds with gang scouts. Partial: 5–6 of 18 ships with a note.

### S3 result: PASSES (builder0, `de45a69f`)
- PRIMARY (n = 18, gang_scout his case): **contact runs 9 of 18 (off) → 0 of 18**; his case now passes all its bars
  (on target 0.64 → 0.63, re-acquire 0.6 → 1.5 s (bar 2.0), backs west 4.9 m). The four crosses byte-identical between
  arms (cross5 L→R still fails 2.1 s, as at CP-S): gang_scout 3/5 → 4/5. law_scout 4/5 and scout 5/5 identical to
  round 27's numbers.
- BLIND (seeds 109–132, n = 24, 13 fielding gang scouts): gang fight contacts −0.31 a seed se 0.24; ENGAGE in-reach on
  target −0.49 pts se 1.71; all-fight −0.02 se 0.58; fight contacts −0.25 se 0.17; kills 33 → 28 (−0.2 a seed, se 0.2,
  inside 2 se — noted); damage −33 a seed se 32; deaths 310 → 309. The gate rarely fires in a real fight.
