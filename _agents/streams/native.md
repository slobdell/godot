# Stream: native (a playtest report he can paste; twins for what ships; the replay of his group click)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 44** (C44.1, C44.2, C44.4), your round-43
> brief `streams/archive/round43/native.md` (Status: CP43.0, the replay, lines_r43). **You own:** `native/**`, `mk/native.mk` (incl.
> `playtest-report`), `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`,
> `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tests/ai_scenarios/guard_line.gd`,
> `mk/play.mk`'s skirmish recipe, `_agents/judging.md`, `tests/replay_orders.gd`, `tools/recording_arrivals.py`, the playtest-report
> tools, `tests/replay/**`. **Model:** Opus. **Machine:** builder0 (quiet window for perf); builder2 for rows. **Seeds:** 11001-11024.

## The lead's direction (2026-10-28)

He ran `make playtest-report` on his recording and found its output too long to paste. "Core components in C++ long-term" (memory).

## Where things stand (main at launch: dbf0bf637, see HANDOFF)

- `make playtest-report RECORDING=<file> [HTML=out.html]` (`mk/native.mk` ~line 493): arrivals per order, the camera at each hit /
  death, a 30 s replay's divergence. It prints everything to the terminal.
- The replay is faithful (his round-42 match bit-exact, R43.9). Orders adds `click` / `group` keys to the `order` row (C44.2).
- Round-43 watch items: control per frame 27.60 v 26.0 (a watch line); `gate_width` in C++.

## Backlog (in order)

1. **N1 the one-screen report.** `make playtest-report` writes the full report to a file (`build/playtest-report/<recording>.txt`, plus
   the HTML) and prints at most ~40 lines: the match (arena, seed, factions, length), per order one line (tick, squads, verb, worst
   arrival / never-arrived), the camera-misses count, replay divergence one line, and the path of the full file. Test it on both his
   round-43 recordings; paste the printed summary into your Status so the orchestrator can see it fits. Merge alone when green.
2. **N2 replay his group click.** `make replay-match` on `references/round43/playtest/2026-10-28T08-21-31-locks.jsonl` to tick 1512 /
   1808: confirm it reproduces his four destinations; hand orders the command and the divergence (message the orchestrator). Make the
   replay read the `click` key when present (C44.2).
3. **N3 twins for what ships:** whatever manoeuvre (Bar S v3's rules beyond kturngoal / parkaside, M2's k-turn) and orders (G1 v10's
   layout, if it touches the drive) need before they ship ON (C44.4); pairs proved output-identical, merged with the ship.
4. **N4 lines_r44 and the judged table** for the round's bars; the quiet perf read of main at launch and after each ship.
5. **Stretch:** `gate_width` in C++; the control-per-frame line re-read quiet.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make native` + `make native-info`; the report on both
his recordings, read by eye. Every number with its commit and machine.

## Don't touch

`game/control/**` (orders), movement / traffic / formation (manoeuvre), `game/match/**` (the `click` key is orders'), `tests/baselines/**`.

## Waiting on the lead

Nothing.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Plan (in order):** N1 the one-screen report -> N2 replay his group click -> N3 twins (manoeuvre's `--traffic-on=backout`,
requested 2026-10-28 by the orchestrator; orders' if any) -> N4 lines_r44 + quiet perf reads -> stretch (gate_width in C++,
control-per-frame quiet read).

**N1 DONE, check running.** `make playtest-report` prints <= 40 lines and writes the full report to
`build/playtest-report/<recording>.txt` + `.html`: 8a1c384fe. tools/test_playtest_report.sh 27/0 (laptop). Each click is one
line (the order rows of one tick and verb grouped; squads as squad:crews; his `click` when C44.2 records it; how far apart the
spots are; arrived n/N; the worst best-distance; AWAY >= 30 m). "camera: off screen" projects each hit/death's victim through the
recorded `cam` row (RtsCamera.pose_at, fov 35 assumed (the row has no lens), 16:9). The replay line names why it parted (native
differs / roster mismatches / seed not recorded). His 08-15 recording: 18 lines; 08-21 (laptop, 8a1c384fe + N2, native ON,
52 s wall):
```
PLAYTEST 2026-10-28T08-21-31-locks.jsonl
match: locks, seed -1 (his --seed=56416.), 63 s, gangs v condemned (20 v 20 units), squad cap 4, laptop, native on
fight: 71 hits, 5 deaths (his 4, CPU 1)
his clicks (5; time, verb, squad:crews, spots, arrived in the window to the next order, worst best-distance):
     0.0 s  move         Guns:5  to (-86, 53)  arrived 4/5  worst Guns_5 56 m never  AWAY Guns_3 44 m
    25.0 s  attack       Guns:4  -> Lances_1
    39.6 s  stop         Guns:1
    50.4 s  move         Guns:1 Hunters:5 Spears:5 Wrenches:5  4 spots 105 m apart  arrived 8/16  worst Wrenches_3 72 m never
    60.3 s  move         Guns:1 Hunters:5 Spears:5 Wrenches:5  4 spots 91 m apart  arrived 4/16  worst Wrenches_3 84 m never
camera: 16 of 76 hits/deaths off screen (16 on his units, 1 deaths); estimate: fov 35, 16:9
replay: PASS, his match: 20 of 20 crews within 3.0m for 30 s
full report: build/playtest-report/2026-10-28T08-21-31-locks.txt (page build/playtest-report/2026-10-28T08-21-31-locks.html)
```
(the replay line as it reads with N2; before N2 it read `FAIL ... first over Green_Guns_1@7 (1 roster mismatches, seed not recorded)`.)
Full check of **fff546ef6** (N1 + the SEED fix): running on builder0, log `~/native-r44/check-fff546ef6.log`.

**FINDING: his round-43 seed was lost to a full stop.** Both playtests ran `SEED=56416.` (HANDOFF's sentence end): --seed did not
parse, so the armies rolled from the clock (unix % 100000), the recorder wrote seed -1, and Match's fire RNG (process `--seed`, else 0)
started from 0. `make skirmish` keeps SEED's digits only (fff546ef6; tools/test_skirmish_flags.sh 6/0, laptop).

**N2: his round-43 matches replay EXACTLY** (0d4b08cd8, laptop, native ON, through make): the replay passes his seed TEXT and his
render preset (the laptop's roll caps armies at 20; desktop's does not: test pins it) and gives the skirmish the army seed found
from his roster near the recorder's start second (REPLAY_SEED_RECOVERED). 08-21: seed 891, 20/20 crews 0.0 m for all 63 s; 08-15:
seed 542, 20/20 for 60 s. Round 42's recording: exact for 49 s with `--engage-water=off` (A7 ON since his match parts it at 15 s:
behaviour change, expected). test_replay_setup 13/0 (laptop).
**His group click (tick 1512):** reproduces his four spots (the rows replay as recorded). His click point is not in the recording;
`--click=1512:X,Z` replays the four rows as ONE group click at (X,Z). Six clicks tried (his four spots, their centroid,
(-12.6, 104.2)): every one scatters the squads 60-110 m from his exact state (worst 37-110 m from his spots; none his exact
layout). z = 117.24 recurs as a hard edge and his Wrenches landed at (-25.49, 117.24): the squad "sent back to the north edge" looks
like a slot past the map clamped to the edge. Handed to orders via the orchestrator (the command + this).
C44.2: rows sharing a `click` merge into one order AT the click (a one-squad row keeps its recorded point).

**Questions for the lead:** none. **Requests:** orchestrator: send SEED= without a trailing full stop (done by fff546ef6 anyway).
