# Stream: native (the scoreboard row for every main; every mirror; cleaner tests)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 36** (C36.1, CP36.1,
> C36.3, C36.5) and in *Round 35*: R35.47 (the bare-teleport note), R35.62 (the inert mirrors), R35.75 (X5: the scoreboard and the
> copy-back leak), R35.78 (W1b dropped). Then your round-35 brief `streams/archive/round35/native.md` (its Status is the close-out,
> with seven round-36 candidates).
> **You own:** `native/**`, `mk/native.mk`, `exec_fields.h`, the twins, planner's paths (`game/ai/planner/**`, `native/src/planner_*`,
> `tests/planner/**`, `tests/test_planner*.gd`, `mk/planner.mk`, `tools/judge/**`), the scoreboard (`mk/scoreboard.mk`,
> `tools/scoreboard/**`, `tests/scoreboard/**`, `references/scoreboard/**`), `tools/copyback_prune.sh` and its hook in
> `tools/remote.sh`, and the test-hygiene grant (C36.5): in ANY owner's test file, a bare `global_position =` spawn placement may be
> replaced by `Tank.place(...)` (or a fresh child) and nothing else, one commit per owner, a merge note naming the files.
> **Model:** Opus. **Machine:** builder2 for the scoreboard (C36.1); checks on whichever builder `tools/builder_checks.sh` shows free.

## The lead's direction

Nothing alone: every C++ change a twin of its GDScript, so the game stays fast on his laptop and the two paths agree. And his
round-35 concern, verbatim (2026-10-20): *"ensure that we're also generally making concrete progress"*: the scoreboard is the
answer he reads, one row per main, in player terms.

## Where things stand

- **On main from round 35:** N2 (FACE_KEEP_FAR gone, seed twins dropped, the judging table's rows), N3 (a source change always
  rebuilds), `tools/builder_checks.sh`, T7's pass lane in C++, W1b's and W1c's mirrors as inert code. The joint's T9 half lands at
  **CP36.1** (`pair/joint-ship`).
- **On `round35/native`, NOT on main:** the scoreboard (`mk/scoreboard.mk`, `tools/scoreboard/run.sh` / `score.py` / `table.py` /
  `mover_kind.py`, `tests/scoreboard/jam_census.gd`; 40 fights + 48 move orders + 36 group orders, seeds 2601+), the copy-back
  prune (`tools/copyback_prune.sh`, 1d8dd7648, its test), and R35.47's two Tank.place fixes (test_native_avoid_gather,
  test_native_record; committed at the close by the orchestrator, UNCHECKED). The first three rows (c29a8c7b6, a0ae0aafd,
  1c82d6d1e) were running on builder2 at the close; the orchestrator commits whatever rows finished to `round35/native`.

## Backlog (in order)

1. **N1 hand over round 35's tools (C36.5):** merge `round35/native` onto your fresh branch (read the diff first), finish any
   scoreboard row that didn't complete, `make native check` on one named hash, send it to the orchestrator. Tooling only: nothing
   he'd notice, so it merges on its check.
2. **N2 score every main the orchestrator names** (builder2, `tools/scoreboard/run.sh <commit>`), starting with main after CP36.1;
   commit the row and the re-rendered `references/scoreboard/README.md`. A number that moved by more than its noise: say so in
   player terms, with n.
3. **N3 mirrors, as asked:** W1b's inert mirror DELETED with manoeuvre's S3 (one pair); stallnet's `_stuck_from` (manoeuvre's S1,
   when its spec arrives: exec_fields row, twins both arms, 0 mismatches); orders' O1–O3 if any reaches C++.
4. **N4 the test-hygiene sweep (R35.47):** the ~85 files that spawn and then set `global_position` (the list is in brains' E4 in
   `streams/archive/round35/brains.md`). Sort them: the ones whose floors could move with process history first (touching hulls),
   then the harmless snapshot reads. One commit per owner, each with a quick-remote of the files it touches.
5. **N5 the census gap lint:** a test that every counter named in a bar appears in its series' printed line (round 35 lost reads
   to a counter added to a rule but not to `ManoeuvreCensus.counters()`).
6. **Stretch:** E4b below the main loop (name the engine state the first iteration sets; a two-body repro).

## How to verify

`make quick-remote`; `make native check` for a named hash, one full check at a time a builder; tool tests on the laptop
(`make shell-tools-test`). Twins: both arms, 0 mismatches, every stage's floor reached.

## Don't touch

Gameplay GDScript outside planner's paths (mirrors follow the owner's spec), other owners' tests beyond the C36.5 grant,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Round 36, 2026-10-20 (worker).** `stream/native` already carried round 35's tools (no `round35/native` branch was cut), so
N1's hand-over is main merged into it (434640730, the brief taken from main) plus the two finished rows (5fabab534:
c29a8c7b6, a0ae0aafd; builder2). The 1c82d6d1e row was running at launch.

**Plan (in order):** N3's S3 pair first (it arrived at launch, small, and manoeuvre waits on it); then N1's check; N2 rows
as named; N4 sweep; N5 lint; stretch.

- **S3 (W1b's mirror deleted):** `pair/native-s3` = `lab/manoeuvre-s3` d44c13377 + native half eefc379c5. Check pending.

**2026-10-20 (orchestrator, at launch).** Not started.
