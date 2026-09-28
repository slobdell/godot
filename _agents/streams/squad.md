# Stream: squad, round 14 (two red instruments: the gang-pack drills and the CPU budget under load)

> Read the archived round-13 brief `archive/round13/squad.md` **Status** (*Known issues*: the two gang-pack drill
> assertions; the ladder variants' stale row), [`verification.md`](../verification.md) (rule 3: a control that cannot
> judge REFUSES, never passes; the `scenario_perf` note), and `HANDOFF.md` *ROUND 12 … Housekeeping* (three streams saw
> `scenario_perf` trip under builder0 load; each isolated re-run was green; round 13's audio saw it again). **You own**
> what squad owned in round 13: `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,tank_brain,element_feed,
> directives}.gd`, `doctrines/`, `mk/tactics.mk`, `tools/tactics/**`, `tests/test_tactics_*.gd`, `tests/tactics/`,
> `tests/ai_scenarios/`, `_agents/{doctrine,tank_brain,squad_ai_design}.md`; **carve-out:** the `scenario_perf` /
> `ai-scenarios-check` targets in `mk/ai.mk` and whatever reads the box's load (`tools/slot.sh` is shared: additive only,
> listed in merge notes).

## The lead's direction

No new words. S6 is decided ON (2026-09-27 evening; `game_design.md` *Round 13: S6 decided*) and its toggle is
documented at the code site: **do not change it.** Standing: C12.6 — nobody tunes balance.

## Where things stand (verify on main)

- `make tactics-drills` (NOT in `make check`) fails two gang-pack assertions on main — *"the pack rings them or baits
  them"* and *"from more sides than a standard element would: 4"* — already at `8f96a43c` (builder0), identical with S6
  off and on. Nobody has looked at WHEN they started failing.
- `scenario_perf` (the AI cost-per-tick budget, `ai-scenarios-check`) trips when builder0 runs two checks at once
  (audio's round-13 first check: 22 ms/tick); every isolated re-run is green. `verification.md` rule 3 says a control
  that cannot judge must REFUSE and be counted "not judged, never a pass". Today it judges and fails.
- `tests/tactics/variants/doctrine_standard_*.json` (ladder experiment copies) still carry the old `dense → column`
  plain-move row that round 13 removed from the live tables.

## Backlog (in order)

**Q1. The gang-pack drills: when, and why.** Bisect on builder0 (`git bisect run` with `make tactics-drills` filtered
to the two assertions) to the commit that turned them red; read what changed; then decide whether the DRILL regressed
(fix the behaviour) or the ASSERTION is stale against a legitimate change (fix the assertion, and say which change made
it legitimate). Either way: the drill's frames at his pose before/after, and `tactics-drills` green. If it is a
behaviour regression that a balance number would fix, that is C12.6's: write it up for the lead instead.

**Q2. `scenario_perf` refuses when the box is loaded.** The scenario reads a reference workload (the same idea as
`verification.md`'s "2.1× nominal, machine too loaded"): before judging, it times a fixed reference loop; if the
reference is > 1.5× its recorded nominal on that machine, it prints `SCENARIO_NOT_JUDGED reason=loaded ref=<x>×` and the
gate counts it as NOT JUDGED (the summary must show it, never a pass — rule 3's silent-skip trap). Record the nominal
per machine in the repo (`tests/ai_scenarios/perf_nominal.json`: builder0, the laptop). Prove it both ways: under
`stress` (or a second check running) it refuses; alone it judges and passes. Mutation-check: with the threshold
disabled it fails under load as before.

**Q3. The ladder variants' stale row.** Update `tests/tactics/variants/doctrine_standard_*.json` to the wedge default or
document in their header why they keep the old row (they are experiment copies; if the ladder's numbers depend on the
old row, keep it and say so). The doctrine coverage test decides what it covers.

**Q4 (stretch).** `make tactics-drills` into `make check`? Only if it is green, deterministic on builder0 across three
runs, and under 60 s; otherwise a `check-all` row with the reason.

## How to verify

`make remote T=check` green on every named commit; `make remote T=tactics-drills` green; `ai-scenarios-check` both
loaded and alone with the wrapper's own lines quoted; sim baseline `6313a38d7ecd99bb` pre-registered UNMOVED (Q1 may
move it if the DRILL changes: pre-register with the path — the CPU's tasks run drills in the baseline match — and
declare it; lesson 223).

## Don't touch

`game/ai/movement.gd` and nav's other files; `game/control/**`; `game/garage/**`; `game/theme/**`;
`TankBrain.IDLE_FACE_NO_PIVOT` (his toggle).

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current)_
