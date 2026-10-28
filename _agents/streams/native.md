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

_(worker keeps this current)_
