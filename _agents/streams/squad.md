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

_(the worker keeps this current; last updated 2026-09-28 ~02:30)_

**Summary: Q1–Q4 done.** Merge hash and its check are at the bottom (*Merge notes*).

### Done (every number: builder0 unless marked; commit named)

- **Q3, `dca1d6cc`.** The four ladder variants take `doctrine_standard.json`'s movement rows verbatim (wedge
  default). New test `test_a_ladder_variant_differs_from_the_standard_table_only_in_what_it_names`: a variant may
  differ from the live table only in name, summary, drills and traits. It was red on all four before the fix (row 10,
  the old `dense → column`) and is green after. Past ladder numbers stand: they were taken when the live table had
  the same row.
- **Q2, `470491be`.** `scenario_perf` times a reference workload (20 × `ControlFixture.reference_work`) 9× before the
  fight and every 30 ticks during it. If the median during the fight is more than 1.5× this machine's nominal
  (`tests/ai_scenarios/perf_nominal.json`), or the machine has no nominal, it prints
  `SCENARIO_NOT_JUDGED reason=… ref=…x` and skips only the budget assertion. The runner counts NOT JUDGED apart from
  passed (`scenarios not judged: N`). The gate compares passed + not judged with the baseline, prints *NOT JUDGED …
  not a pass*, and leaves a marker. `check`'s verdict has a fourth state:
  `>> check: 17 passed, 1 NOT JUDGED` + the row, never "all passed", exit 0. Tests first: 8 gate cases and 8 verdict
  cases were red before. `make ai-perf-nominal` records a machine; `ai-perf PERF_REFUSE=off` is the mutation arm.
  - End to end (check at dca1d6cc + this code, before any nominal existed): `1791 passed, 0 failed`,
    `>> check: 17 passed, 1 NOT JUDGED`, the row `scenario_perf … (reason=no_nominal machine=builder0)`,
    `>> remote: make check exited 0`.
  - At `070476be` with the nominal: `perf_reference 0.824 ms … nominal 0.819: 1.01x`, `scenarios not judged: 0`,
    `43 passed, 1 failed` (the baseline's), `18 targets, all passed`.
  - Nominals: builder0 **0.819 ms (PROVISIONAL**, taken during a check at `dca1d6cc`; re-record idle), flightdeck
    1.48 ms (idle, load 0.45). At builder0 load 16.6 / 24 Godot the reference read 1.457 ms (1.78×) while the budget
    read 19 256 µs/tick against 12 106 alone: the yardstick tracks the load that inflates the budget.
  - Loaded / alone / mutation proofs: see *Q2 proofs* below.
- **Q1, `070476be`** (+ frames `c9c8fdad`). **When:** never green on builder0. `git bisect run` (12 steps, each the
  commit's own `make tactics-drills FILTER=gang_pack`, in a separate clone `~/tank_squad/squad-bisect`) named
  `231994b5`. Its parent `9247ef48`, the commit that WROTE the assertions and the bisect's assumed-good end, was run
  directly and is red too. **Why:** that same commit switched encircle off in every shipped table (measured worse)
  and made bait require a contact that follows (`bait_chaser_mps`), while the drill stages two dug-in guns. So
  "rings them or baits them" could not pass by design. The ASSERTION was stale; the behaviour did not regress, and
  nothing in `game/` changed. **Now:** against guns the pack must not lure, must not circle, must fight
  (`react_to_contact`), and must come from ≥ 3 arcs. In `bait_chase` (chasers) the gangs must lure and the no-bait arm
  must not. "More sides than standard" was dropped (it read 4–8 arcs across commits on one seed; 9247ef48 itself found
  standard covers as many). **Mutation-checked** (builder0): bait without the follower rule → "does not lure" red;
  gangs without bait → "send a lure" red; gangs with encircle → "nor circle" + "fights them instead" red; unmutated
  `failures=0`. `make remote T=tactics-drills` at `070476be`: `TACTICS_DONE failures=0`, `exited 0`.
  **Frames:** `streams/references/round14/squad/q1_gang_pack_*.jpg`: the gangs vs guns (top-down and his pose),
  vs chasers (top-down and his pose: at 6 s one scout draws the hunters north while the pack pulls back), and
  standard vs guns at his pose; 3/6/10/16/26 s. `make remote T=tactics-shots STAGE=gang_pack` with
  `SHOT_ARGS="--pose=his --chasers --table=standard"` (call `tools/remote.sh` directly: `make remote` refuses the
  quotes).
- **Q4, `14f3091d`.** `tactics-drills` is in `CHECK_TARGETS`. Three builder0 runs of the full drills (code of
  `070476be`, load ~1.2): 14.77 s, 15.05 s, 15.90 s, all `failures=0`, md5 of every `TACTICS` line
  `3f9543682478` ×3. Laptop: 20.19 s and 20.29 s, `failures=0`, `46df3d0df1de` ×2 (a different fight, glibc; the
  assertions hold on both). No port, no `user://`, so no exclusion edge.

### Q2 proofs (builder0, `tools/remote.sh`, the wrapper's own lines)

- **In the wild, check at `5f67f91e`** (the checkpoint merge; load 3.4, other streams' checks running): budget
  18 006 µs/tick, `perf_reference 1.415 ms … nominal 0.819: 1.73x`, `SCENARIO_NOT_JUDGED reason=loaded ref=1.73x`,
  `>> check: 18 passed, 1 NOT JUDGED` + its row, `1793 passed, 0 failed`, `>> remote: make check exited 0`.
- A first "alone" attempt was not alone (19 Godot processes on the box): it refused at 1.66×, which is correct.
- The burner-loaded proof was stopped at the orchestrator's request (garage's check was running, and Q2 is not on
  main yet, so my load would have tripped its judging `scenario_perf`). It runs again on the orchestrator's go.
  Scripts: 14 busy loops on builder0 (15-minute cap, stopped by PID), then `ai-scenarios-check` and
  `ai-perf PERF_REFUSE=off`.
- **Merge condition (the orchestrator):** the named hash comes with an isolated `scenario_perf` JUDGED PASS on the same
  code, quoted beside it.

### Decisions

- **Q3: update, don't keep.** Each variant is an ablation; with the old row it differed from its control in two things.
- **Q2: the reference is sampled DURING the fight**, because the load that inflates the budget is the load during the
  30 s being measured. The yardstick is the control stream's (preloaded, not copied). No nominal is a refusal too.
- **Q2: NOT JUDGED does not fail `check`, and never reads as a pass.** A red check on a busy box is the false alarm this
  item removes. The gate's passed + not-judged arithmetic means a refusal stands in for exactly the scenario it names.
- **Q1: fix the assertion, not the behaviour**, and keep the drill staged as it was. The positive "it lures" check went
  where the design says a lure works (`bait_chase`), which is what keeps the drill able to fail (the orchestrator's
  condition).
- **Q4: into `check`**, not `check-all`: green, deterministic, 15 s.

### Questions for the lead (none blocking)

1. **Two of the gangs' 09-16 verdicts have flipped since** (one seed each, builder0, `dca1d6cc`; `doctrine.md`
   *Round 14 (squad Q1)*). With encircle switched on, the enemy is left at **0.002** (0.66 when it was switched off
   for being worse). With the shipped lure against chasers, the pack keeps 0.196 against 0.258 without it (0.58 vs
   0.43 when it was kept). Re-measuring over seeds, and then maybe shipping encircle or dropping bait, is a balance
   and design call (C12.6), so it is not acted on. Worth a round-15 item?

### Requests to other streams

None.

### Known issues

- builder0's nominal is provisional (recorded during a check, not idle). If it is too high, the gate refuses less
  than it should; re-record with `make remote T=ai-perf-nominal` in a quiet window and copy the line into
  `perf_nominal.json`.
- `scenario_perf`'s fight is not the same fight run alone as run in the full suite (LOS 148 100 vs 156 382 queries,
  26 vs 24 alive): the budget line is compared across different battles. Not investigated.
- In the gang-pack frames the eastern flanker (Green_A_4) loops in tight circles by a crate from ~16 s to 26 s
  (`q1_gang_pack_gangs_26s.jpg`). That's the brains' flank movement, not a drill; noted, not investigated.
- **Garage's time-limit rule (main `5f562dd0`) changes what `make tactics-ladder` scores.** An elimination match that
  ends on time is now won on points destroyed (equal = draw). `tools/tactics_ladder.py` turns `winner` into ELO
  (draws included), so ladder numbers before and after that merge are not comparable for matches that hit
  `TIME=240`. `squad-coherence` records `winner` but reports nothing from it. The drills don't read a winner. No ladder
  was run this round.
- `gang_pack_swarm_only` (`gangs-no-encircle`) is identical to `gang_pack_gangs`, since encircle is already off. It is
  kept because it costs ~1 s.

### What to playtest

Nothing player-facing changed. To see the drills: `make remote T=tactics-drills`; to see the pack:
`tools/remote.sh tactics-shots STAGE=gang_pack "SHOT_ARGS=--pose=his --chasers"` → `build/tactics-shots/`.

### Merge notes (shared-file edits, all additive)

- `mk/core.mk`: `tactics-drills` appended to `CHECK_TARGETS` (Q4), with a comment.
- `tools/check_verdict.sh` + `tools/test_check_verdict.sh`: the NOT JUDGED state.
- `tools/metrics/ai_scenarios_gate.sh` + `test_ai_scenarios_gate.py`: NOT JUDGED arithmetic and marker.
- `mk/metrics.mk`: one env var (`AI_SCENARIOS_NOT_JUDGED_MARKER`) on the gate's call.
- Uses (read-only) `tests/support/control_fixture.gd`'s `reference_work`.
- Sim baseline: pre-registered UNMOVED (no `game/` file changed); read `6313a38d7ecd99bb` unmoved at `dca1d6cc` and
  `070476be`.
- Merged `main` at the checkpoint (`5f67f91e`, clean).
