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

The decision page (P1) — for his morning. Nothing blocks the rest.

## Status

_(the worker keeps this current; last updated 2026-10-02 ~00:30)_

### Plan (smallest foundation first)

1. **P1 tooling:** `tests/tactics/gang_probe.gd` (one cell: arm × opponent × map × seed → `GANG_PROBE {json}`),
   `TacticsScenarios.table_for` composes `+drill` / `-no-drill` in memory, `make squad-doctrine-series` +
   `tools/tactics/doctrine_series.py` (paired by seed against the shipped arm, sign test, drill counters).
   *Decisions:* opponents are **guns** (round 14's encircle reading), **chasers** (its bait reading) and a
   **standard element** (tank + 2 IFV under `doctrine_standard.json`, told to attack: the brief's "the standard
   element"); maps are **yard** and **Terminus** (his maps, the pack at GREEN's spawn, the enemy 80 m toward the
   centre on standable ground) plus **lane** (the drills' own ground, round 14's staging) as the bridge to the one-seed
   numbers. Each seed jitters starts ±3 m / ±15° and seeds the fire dice (lesson: round 12's seeds without jitter were
   n = 1). The fight runs to a verdict or 90 s; survival is also read at 26 s (round 14's window). Seed 0 on the lane
   = round 14's drill exactly.
2. **P2** (cheap, independent): the winner rule's version printed beside every ELO, `--compare` refuses across rules
   (exit 3), `tactics-pytest` in `check`; then the reference ladder on main's code on builder0.
3. **P1 run + page** (the series on builder0, then the decision page with `db`).
4. **P3** `scenario_perf` alone vs in-suite. 5. **P4** the flanker's loop. 6. **P5** from P1's counters.
