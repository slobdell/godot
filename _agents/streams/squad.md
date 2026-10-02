# Stream: squad, round 15 (the gang doctrine's flipped verdicts, measured; the ladder re-baselined; two loose ends)

> Read the archived round-14 brief `archive/round14/squad.md` **Status** (Q1's finding and *Questions for the lead* 1;
> *Known issues*: the ladder across the time-limit rule, `scenario_perf`'s different fight alone vs in-suite, the
> eastern flanker looping by a crate), [`doctrine.md`](../doctrine.md) *Round 14 (squad Q1)* and the gangs' table,
> `doctrines/doctrine_gangs.json`, and `tools/tactics_ladder.py`. **You own** what squad owned in round 14:
> `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,tank_brain,element_feed,directives}.gd`, `doctrines/`,
> `mk/tactics.mk`, `tools/tactics/**`, `tools/tactics_ladder.py`, `tests/test_tactics_*.gd`, `tests/tactics/`,
> `tests/ai_scenarios/`, `_agents/{doctrine,tank_brain,squad_ai_design}.md`.

## The lead's direction (2026-10-01)

> *"playin right now feels good, so we should go ahead and set up a bunch of workstreams I can kick off for the night."*

**Standing and binding: C12.6 — nobody tunes balance.** A doctrine table's verdict (encircle on, bait off) is a design
call that is his. This round MEASURES and puts the choice in front of him for the morning; it does not ship a table
change. S6 (`TankBrain.IDLE_FACE_NO_PIVOT`) is his toggle: do not touch.

## Where things stand (round 14's Status; verify on main)

- **The gangs' 09-16 verdicts, ONE seed each (builder0, `dca1d6cc`):** with encircle switched ON the enemy is left at
  **0.002** survival (0.66 when it was switched off for being worse); with the shipped lure against chasers the pack
  keeps **0.196** against 0.258 without it (0.58 vs 0.43 when bait was kept). Both verdicts the tables rest on have
  flipped on a tree that changed a lot since (hull sizes, S6, the wedge default, nav's rounds).
- **The ladder:** `tools/tactics_ladder.py` turns `winner` into ELO (draws included); garage's time-limit rule
  (`5f562dd0`: a time-out is judged on points destroyed, equal = draw) changed what a winner is for matches that hit
  `TIME=240`, so ladder numbers across that merge are not comparable. No ladder was run in round 14.
- `scenario_perf`'s fight is not the same fight alone as in the suite (LOS 148 100 vs 156 382 queries, 26 vs 24
  alive): the budget line is compared across different battles.
- The eastern flanker (`Green_A_4`) loops in tight circles by a crate from ~16 s to 26 s in the gang-pack frames
  (`references/round14/squad/q1_gang_pack_gangs_26s.jpg`): the brains' flank movement, not a drill.

## Backlog (in order)

**P1. The flipped verdicts, over seeds.** `make squad-doctrine-series` (write it on the round-12 paired-series tooling):
the gang pack vs the standard element and vs chasers, 8 seeds × both maps, four arms — shipped (encircle off, bait on),
encircle on, bait off, both flipped — same seeds. Report survival both sides, time to the verdict, and the drill
counters (`idle_faces`-style) so a win is attributed to a mechanism, not a coin. Then **a decision page for the lead**
(Artifact, the `db` capability, like round 12's fleet page): one card per arm with the numbers, the frame at his pose,
a one-line "approve = this row changes in `doctrine_gangs.json`", and the recommendation. The URL in Status with the
time the `db` was last read. **No table change ships this round.**

**P2. The ladder, re-baselined.** Run `make tactics-ladder` on main as it stands (builder0, the seeds the ladder uses),
record it as the new reference in the ladder's own results file with the commit and the winner rule it was taken
under, and make the ladder script PRINT the winner rule's version (a hash of `Match.result`'s time-limit branch, or a
constant bumped at `5f562dd0`) beside every ELO so two runs across a rule change refuse to compare. Test the refusal.

**P3. `scenario_perf` compares the same fight.** Find why alone vs in-suite differ (a seed read from the environment?
test order leaking state? the shard's unit count?) and pin the fight (same seed, same roster, same ticks) so the budget
is a measurement of one battle. Prove it: alone and in-suite LOS queries equal.

**P4. The flanker's loop by the crate.** Reproduce from the gang-pack stage (`tactics-shots STAGE=gang_pack`), log the
brain's option scores for `Green_A_4` 16–26 s, name the mechanism (a flank goal behind a crate it cannot reach? an
oscillation between two options?), fix it in the brain if it is a defect of the option, and measure the pack's drill
unchanged (the three mutation runs still red where they should be).

**P5 (stretch).** Whatever P1's series shows that is not a balance number (a drill that never fires, a counter that
reads zero) — fix the mechanism, not the table.

## How to verify

`make remote T=check` (the drills are in it now: `TACTICS_DONE failures=0`); the series with commit, machine, seeds;
the page's `db` read and its time noted; sim baseline `6313a38d7ecd99bb` **pre-registered UNMOVED** (no table or brain
default changes; P4 may move it if the brain changes — pre-register with the path, the CPU's gangs run flank movement
in the baseline match — and declare it).

## Don't touch

`game/ai/movement.gd` and nav's files; `game/control/**`; `game/garage/**`; `game/theme/**`; `game/match/**`;
`doctrines/*.json` beyond the series' TEMPORARY arms (never committed changed); `TankBrain.IDLE_FACE_NO_PIVOT`.

## Waiting on the lead

The decision page (P1) — for his morning. Nothing blocks the rest. **Answered 02:09 PDT: "As shipped" (see Status).**

## Status

_(the worker keeps this current; last updated 2026-10-02 ~04:30)_

**Summary: P1–P5 done; his P1 choice is in ("As shipped"). Green, merge here: `e05a44fc`** (see *Final
check*). The sim baseline is **UNMOVED** (`6313a38d7ecd99bb`) with every squad change in, so no CP.

**His page:** https://claude.ai/artifact/TjdypH5KxNgdmwQfSea176. One tap stores `decisions/choice` = `{arm, words, at}`
in the page's `db`. **`db` last read: 2026-10-02 03:28 PDT (10:28 UTC): he has tapped "As shipped"** (`{arm: "shipped", words: "", at: 2026-10-02T09:09:44Z}`, on version 1, which already recommended it). Version 2 (03:27 PDT) carries the final code's numbers; the recommendation is unchanged. **Nothing changes in `doctrine_gangs.json`.** (Earlier read: 01:50 PDT, empty.)
Recommendation on it: **keep the gangs' table as shipped**. No table change ships (C12.6).

### Final check

- **`make remote T=check` at `e05a44fc`** (builder0, load 17.5, 25 other Godot): `1822 passed, 0 failed`,
  `sim-baseline 6313a38d7ecd99bb (baseline unmoved)`, `>> check: 19 passed, 1 NOT JUDGED` (`scenario_perf`, loaded),
  `>> remote: make check exited 0`. Every commit after `e05a44fc` is docs (this brief).
- **`scenario_perf` alone at `e05a44fc`, JUDGED PASS** (`tools/remote.sh --quiet ai-perf`, an exclusive quiet window;
  the first plain try had refused at `1.86x` on a box at load 17): `ai_usec_per_tick 10022`,
  `perf_reference 0.778 ms … nominal 0.774 on builder0: 1.01x`, `PASS  scenario_perf::test_the_brains_stay_inside_the_cpu_budget`,
  `>> remote: make ai-perf exited 0`. LOS 148 100 queries / 26 alive: the same battle the suite now fights (P3).

### Done (every number: builder0 unless marked; commit named)

- **P1: the flipped verdicts, over seeds.** `make squad-doctrine-series` (`tests/tactics/gang_probe.gd` +
  `tools/tactics/doctrine_series.py`): the gang pack (IFV leader + 3 scouts) under four arms of its table (shipped =
  encircle off, bait on; encircle on; bait off; both), built in memory (`TacticsScenarios.table_for("gangs+encircle-no-bait")`;
  `doctrines/` never written, a test holds it). Three opponents (two dug-in guns, two chasing IFVs, a standard element of
  2 IFV + scout told to attack), on the yard and the Terminus (his maps; the pack at GREEN's spawn, the enemy 80 m on)
  and the drills' lane; seeds 1–8 jitter starts ±3 m / ±15° and seed the fire dice; 90 s or a verdict; paired by seed
  against shipped with a sign test; drill counters (starts, seconds, shots, damage dealt/taken while each drill ran).
  **Bridge:** seed 0 on the lane is round 14's drill to the digit (0.629 / 0.067 at 26 s).
  **Final, `efa49762` (P4 + P5 in), yard + Terminus, 16 paired fights per cell:**

  | Opponent | shipped (pack / enemy left, W–L–T) | encircle on | bait off | both flipped |
  |---|---|---|---|---|
  | dug-in guns | 0.646 / 0.000, 16–0–0 | 0.613 / 0.000, 16–0–0 | identical to shipped (no lure fires) | 0.613 / 0.000 |
  | chasers | 0.148 / 0.371, 5–8–3 | 0.012 / 0.608; enemy stronger 12 of 15, **p 0.035** | 0.041 / 0.487; 6 / 9, p 0.61 | 0.008 / 0.693; stronger 13 of 16, **p 0.021** |
  | standard element | 0.193 / 0.470, 4–9–3 | 0.057 / 0.553; 7 / 9, p 0.80 | 0.148 / 0.430; 8 / 8 | 0.059 / 0.529; 8 / 8 |

  Round 14's one-seed flips do not survive seeds: **encircle is still worse, and bait is a coin toss on his maps.**
  The pre-P4 series (`f712582d`) said the same with different numbers (best p 0.29 on his maps; the lane-only
  "bait off vs chasers" 7 / 1, p 0.07, does not carry to his maps). Raw rows and summaries:
  `references/round15/squad/p1_series_*.jsonl|json`.
- **P2: the ladder re-baselined (`e676c481`).** See `doctrine.md` *Round 15 (squad P2)*: rule hash printed beside
  every ELO, `--compare` refuses across rules (exit 3), `tactics-pytest` (13 tests) in `check`; reference
  `tools/tactics/ladder_reference.json` = main `85703220`, rule r14 `cc490e53eeb9`, 120 matches: brains 1032, faction
  1014, standard 954.
- **P3: `scenario_perf` fights one battle.** `RUN_FIRST` in the runner (`fe849ad5`); proof `make ai-perf-leak` at
  `cf574701`: one fight in all 12 runs (LOS 148 100 / 26 alive), `SCENARIO_ORDER=alpha` 2 fights (exit 2). Mechanism:
  alone the fight starts at match tick 0, after any earlier scenario at tick 1 (one tick of think-stagger phase). Two
  wrong models on the way (stale navmesh regions; "first arena") were falsified on builder0 and are written into the
  scenario's comment. **Consequence:** in the suite, `scenario_perf` now fights the battle it fights alone (148 100
  queries), not the one it fought in the suite before (156 382), so `ai-scenarios` numbers from before `fe849ad5` are a
  different battle.
- **P4: the flanker's loop** (`4ef9c04e`, `e3fcd04c`, `da298860`). Mechanism: far ambush's turn-in toggled on an 18 m
  radius (see the pre-registration below). Fix: the bearing test. Builder0, the drill's own fight (`cf574701`):
  distance arm = round 14 exactly (0.629, guns dead 27.3 s, the order flipping every 1.5–3 s); fixed: Green_A_4 holds
  at (−73, −27) from 10 s and fights, pack 0.748, guns dead 21.3 s. Drills `failures=0`; **the three mutation runs red
  on builder0** (`make tactics-drills MUTATE=bait_any|gangs_no_bait|gangs_encircle`, exit 2 each, `cf574701`).
- **P5: the lure's missing return leg** (`d9d39e83`; pre-registration below). Paired against the series before it
  (`series2` → `series3`, shipped arm, same seeds): against chasers on his maps the pack keeps more in 7 of 8 decided
  seeds (0.09 → 0.15, p 0.07), the enemy a coin (7 / 6); against a standard element a coin (7 / 8); guns unchanged.
  The runner now turns for home at ~2.5 s (builder0 trace, lane seed 1). Kept as a mechanism fix; its worth is
  inside his bait question.
- **Baseline:** `make sim-hash-arm` at `cf574701`: fixes on `6313a38d7ecd99bb` ×2; `--flank-turn-in=distance`
  `6313a38d7ecd99bb` ×2; `--bait-return=off` `6313a38d7ecd99bb` ×2 (`efa49762`). P4's pre-registered MOVE was **falsified**: the baseline match
  never has a maneuver half in the changed state.

### Decisions

- **Opponents and maps for P1:** guns and chasers are round 14's two readings; "the standard element" got its own
  opponent (2 IFV + scout: a tank in it decided the matchup, 0.22 of the pack whatever the arm). His maps carry the
  verdict; the lane is the bridge to round 14.
- **The page shows the final code's numbers** (P4 and P5 in), since those are what ship if he taps.
- **P3 pinned by order, not by reset:** the history below the scenarios is the world's; a fresh process is the only
  state alone and suite can share.
- **P5 counts as a defect of the drill, not a balance change:** the drill's own comment and the lead's words describe a
  return leg that the code never had. No table number moved.

### Questions for the lead (none blocking)

1. ~~His page~~: **answered on the page, "As shipped"** (02:09 PDT). Nothing to do.
2. **The lure now leads the chasers back to the pack.** It helps the pack survive chasers a little (7 of 8 seeds) and
   is a coin toss otherwise. Worth watching in a match: `make skirmish` with the gangs against Condemned IFVs.

### Requests to other streams

None.

### Known issues

- **The gangs-vs-guns drill covers exactly 3 arcs**, the assertion's floor (`arcs_covered >= 3`), since P4 (the flank
  half now holds its flank instead of circling through more arcs). Green, but one arc from red; the assertion is about
  the design ("from more than one side"), so ≥ 2 would also be honest. Not changed.
- `relay-smoke` failed once at the launch commit under seven sessions starting at once (`room_not_found`); green inside
  `c5536785`'s check and alone.
- The ladder reference predates P4/P5: re-run `make tactics-ladder LADDER_COMPARE=tools/tactics/ladder_reference.json`
  on the merged tree before reading a drill change into it (it will compare: same rule, same workload).
- `scenario_perf` is NOT JUDGED on a loaded builder0 (1.94× in `c5536785`'s check, 1.86× alone at load 17); the
  quiet-window pass is in *Final check*.

### What to playtest

- The gangs' pack flanking (no more circles): `tools/remote.sh tactics-shots STAGE=gang_pack "SHOT_ARGS=--pose=his"`
  → `build/tactics-shots/`; one unit's mind tick by tick: `make remote T="gang-trace"`.
- The lure: `make skirmish` as the Condemned against the gangs (their CPU runs bait against anything that chases).
- His page (above).

### Next steps

- His tap was "As shipped": no table change. The orchestrator reads the `db` again at close (C15.2).
- Re-run the ladder on the merged tree (P4/P5 move doctrine's numbers; same rule, so it compares).

### Merge notes (shared-file edits, all additive)

- `mk/core.mk`: `tactics-pytest` appended to `CHECK_TARGETS` (+ comment).
- `mk/ai.mk` (squad's `scenario_perf` carve-out): `ai-perf-leak` + `PERF_LEAK_BEFORE`.
- `tests/ai_scenarios/run_scenarios.gd`: `a|b` filters, `RUN_FIRST` ordering, `--scenario-order=alpha`, the
  `scenario_index` meta.
- Everything else is squad's own paths (`game/tactics/**`, `tests/tactics/**`, `tools/tactics/**`,
  `tools/tactics_ladder.py`, `mk/tactics.mk`, `_agents/doctrine.md`, this brief, `references/round15/squad/`).
- Evidence in `_agents/streams/references/round15/squad/` (1.3 MB: both series, page notes and frames, traces, leak rows).

### P5 pre-registration (written 2026-10-02 ~02:15, before any series or baseline read of it)

- **Found in P1's counters (post-P4 series):** in every shipped cell bait ran ~4–7 s, dealt 5–43 and took 49–123.
  Trace (laptop, lane seed 1, chasers): the pack drove 55 m AWAY to a hiding place while the runner fought alone; the
  drill ended when the chasers closed (~4.5 s) and the pack needed ~5 s to drive back. `ElementPlan._plan_bait` never
  orders the runner back: the "leads them back over the pack" half of the drill (the lead's own idea, 2026-09-16) did
  not exist.
- **Change:** the hiding place is fixed when the drill starts; the runner turns for it (a named move, gun on them) once
  it reaches the lure point or the live contact is inside 1.25 × `bait_min_m`. No table number changes; the end
  conditions are unchanged. `--bait-return=off` is the mutation arm.
- **Sim baseline: predicted UNMOVED by P5** if no element runs `bait` in the baseline match (only the gangs' table
  enables it); MOVED only if a gangs element is in it. Read with `sim-hash-arm SIM_ARGS=--bait-return=off` beside
  P4's arms.
- **The decision page's bait numbers change with it,** so the series is re-run on the final code and the page
  republished from it (same URL).

### P4 pre-registration (written 2026-10-02 ~01:15, BEFORE the change ran anywhere)

- **Mechanism (laptop trace, seed 0 lane, `make gang-trace`; builder0 trace to confirm):** `ElementPlan._plan_far_ambush`
  tells the maneuver half "turn in and roll them up" (`attack_move` on the focus) only while its centre is within
  `FLANK_ARRIVE` (18 m) of the flank point; turning in carries it out of that radius, so the next update orders it back
  to the flank (`move`). Green_A_4's order flips every ~1.5 s between the flank point (east) and the gun (west), and its
  yaw rotates through 360° every ~3 s: the tight circles of the round-14 frames.
- **Change:** the maneuver half has turned the flank once its bearing from the focus is at least FLANK_TURN_IN_DEG off
  the line of contact (driving straight at the target keeps that bearing, so the decision cannot flip back); the
  distance test stays as an OR. `--flank-turn-in=distance` restores the old test (the mutation arm).
- **Sim baseline `6313a38d7ecd99bb`: predicted MOVED**, path: the baseline match's CPU elements run `far_ambush`
  (the brief: the CPU's gangs run flank movement in the baseline match) and any maneuver half that is wide of the
  focus but more than 18 m from the flank point now turns in where it used to keep driving to the point. If it reads
  UNMOVED, the baseline match never had a maneuver half in that state, and I say so.
- **Kept:** the three gang-pack mutation runs still red where they should be; `tactics-drills` failures=0.
