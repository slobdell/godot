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

- **N1 done:** main 434640730, then e45bb6632 (88185ebb0) merged in; rows c29a8c7b6, a0ae0aafd, 1c82d6d1e committed (builder2,
  exit 0, 0 SCRIPT ERRORs, n=1 run per main) with the README rendered. c29a8c7b6 = a0ae0aafd exactly (no game/native source
  differs: determinism holds). 1c82d6d1e v a0ae0aafd: group orders never in 5/36 -> 0/36, moves never settled 13/48 -> 10/48,
  tanks lost per fight 40.4 -> 41.9 (noise not yet sized).
- **Scoreboard v the Spot box (090580147):** builder2's 14:07 preemption killed e45bb6632's run (255, copy-back FAILED) and
  run.sh scored the stale local build/scoreboard (1c82d6d1e's files) as e45bb6632's row (deleted, never committed). Now
  `tools/scoreboard/verdict.sh` gates the row (exited 0 + copied back, verified, no NOT RUN, run.txt names the commit and
  closes with 40/48/36); each attempt clears the local copy, starts builder2 if it is down, retries a 255 (3). 12 known answers.
  e45bb6632 re-running on builder2 (systemd unit native-score-e45bb6632).
- **N3 S3 (W1b's mirror deleted), green alone:** `pair/native-s3` eefc379c5 = manoeuvre's d44c13377 + native half. builder0
  `make check exited 0`, 2950/0, 25 + 2 NOT JUDGED (load), sim-baseline 13/13 unmoved.
- **N3 S1 (stallnet mirror) stacked on S3, at manoeuvre's request:** `pair/native-s1s3-main` **20acbda5f** = S3 + manoeuvre's
  S1 (dbe6ed396/ab71634f4 cherry-picked) + mirror (779f31be5) + main a318a2cd3 (conflicts: OFF_NAMES; manoeuvre.gd's
  `_same_element` kept, W1b's block gone; native_drive.gd S1 + T9 keys) + main e45bb6632. Full check running on builder0; it
  also stands as main's check (the orchestrator did not relaunch one).

- **S1+S3 pair GREEN and MERGED:** builder0 `make check exited 0` on **20acbda5f**: 2961/0, 25 + 2 NOT JUDGED (perf-judge,
  ai-scenarios CPU budget: load 9.5-12.9), sim-baseline 13/13 unmoved; test_manoeuvre_stall_net 3/3 (native default arm =
  GDScript), test_native_h1b PASS. It stood as main e45bb6632's check. Main 5d6bb1de8 = it + manoeuvre's .uid; merged here
  (06069057d).
- **N2 e45bb6632 row** (9ccc92616): builder2, verdict ok. v 1c82d6d1e: tanks lost/fight 41.9 -> 40.9, twitch 12.6 -> 10.8 m,
  left behind 0.06 -> 0.12/order (n=1 a main, noise unsized: no claim).
- **Next for the scoreboard (orchestrator, R36):** a second seed block (2701+, same arenas and cells) on e45bb6632, per-seed sd
  from both blocks -> a "± noise" column (a move called past ~2 se). A same-seed repeat is byte-identical (c29a8c7b6 =
  a0ae0aafd), so it sizes nothing. builder2, after T8's judged series.
- **S2a (h1bside) + traffic's yieldgap (R36.4), one pair:** `pair/native-s2a-yg` **32ba4ca99** = 20acbda5f + manoeuvre
  ab22849a9 + S2a mirror 18bc084c9 + traffic lab/yieldgap 76aea1185 + yieldgap mirror c66058c41 + a test fix. Quick on
  8e6a52fc9: 134/1 (the red my twin reading a freed hull's name); test_native_yield on 32ba4ca99 13/0, nose-on long hulls ON
  1 twinned 0 mismatches not recorded, OFF 1 twinned 0 mismatches recorded. test_manoeuvre_h1b_side 3/3 (native default arm
  = GDScript, fires 5). Full check running on builder0.

**2026-10-20 (orchestrator, at launch).** Not started.
