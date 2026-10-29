# Stream: native (builder runs that never hang on a cold import; gate_width in C++; twins for what ships; the round's lines)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 45** (C45.1, C45.4). Your last brief:
> `streams/archive/round44/native.md` (Status: N1 report, N2 exact replay, the backout twin r3, lines_r44). **You own:** `native/**`,
> `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`,
> `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tools/builder_checks.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe, `mk/gcp.mk`, `_agents/judging.md`, `tests/replay_orders.gd`,
> `tools/recording_arrivals.py`, `tools/playtest_report*`, `tests/replay/**`; GRANT `game/control/rts_controls.gd`'s `gate_width` for
> the C++ seam only (the GDScript body stays as the fallback). **Model:** Opus. **Machine:** builder0 (quiet window for perf); builder2
> for rows. **Seeds:** 11501-11524.

## The lead's direction

"Core components in C++ long-term" (memory, 2026-10-12). He feels hitches on the laptop on purpose (memory: the laptop is the test bed).

## Where things stand (main at launch: 972e4bb57, code a93271a66 GREEN builder0 3446/0, see HANDOFF)

- **Cold import:** Bar B1 lost 4 h when builder2's fresh `godot-manoeuvre-b1-light` hung on its first import (Oswald-Latin.ttf at 0 %,
  18:21-22:23, killed at the 14400 s slot). Nothing noticed until the slot timed out.
- **gate_width:** a right click on 30 units / 6 squads reads 236 workloads v the control-timing budget 104 (builder0 quiet, orders
  57a20c9a4, 10.38 ms); 258 on aa9753028 (R43.41); `test_control_scale.gd` header R43.11: past MAX_SQUADS 5 the rest is one
  `RtsControls.gate_width` scan. JUDGED FAIL on that line since round 43.
- B1's lines are not yet in `tools/judge` (lines_r44 has G1 v10c, S v3, A6 v3).
- builder2 is Spot and was preempted twice on 10-28 evening (`make gcp-start` restarts it).

## Backlog (in order)

1. **N1 the cold-import watchdog.** `tools/remote.sh` (both builders): an import that shows no progress for N minutes (say 10; pick
   and record why) is killed, the `.godot/` import cache for that folder is cleared, and the import is retried once; the second
   failure ends the run with one clear line (`>> remote: import hung on <file>`), never a silent slot timeout. Test it with a fake
   hang. Merge alone when green.
2. **N2 gate_width in C++** (C45.4): output-identical first (the control probe and the G1 orders probe byte-identical, native on v
   off), then `control-timing` JUDGED on builder0 quiet: the 30-unit right click under budget. Merge alone when green.
3. **N3 twins for what ships:** manoeuvre's M1 + M2 backout changes (Bar B2's tree), and orders' G2 / engage's E2 if either touches
   the drive (C45.4); pairs proved EQUAL, merged with the ship.
4. **N4 lines_r45** (B1's lines, G2, E1, B2, S v4) and the judging table for the round's bars; the quiet perf read of main after each
   ship.
5. **N5 the replay to the end of his match:** `make replay-match` on the Gorge recording for the full 107 s (engage needs the scout's
   last 25 s): report where it diverges, and fix what you can.
6. **Stretch:** a builder2 preemption auto-requeue in `tools/remote.sh` (read the verdict line; re-run verbatim once).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make native` + `make native-info`; `make control-timing` quiet;
the watchdog on a staged hang. Every number with its commit and machine.

## Don't touch

`game/control/**` beyond the gate_width seam (orders), `game/tactics/**` (engage / manoeuvre), movement / traffic (manoeuvre),
`game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
