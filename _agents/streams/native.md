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

**Report (2026-10-29, in progress).**

**Plan (order kept from the backlog; reasons):** N1 watchdog -> N2a gate_width C++ -> N2b untangle_whole C++ (GRANTED R45.3,
because gate_width alone cannot reach the budget, below) -> N3 twins as manoeuvre/orders/engage ship -> N4 lines_r45 + judging ->
N5 replay to 107 s -> stretch requeue.

**N1 the cold-import watchdog: BUILT, check running (9b6ffb0a6, builder0).** `tools/import_watchdog.sh` runs inside the slot
`tools/slot.sh` grants when `tools/remote.sh` exports `TANK_SQUAD_IMPORT_WATCH` (both builders; `REMOTE_IMPORT_WATCH=0` is the
escape; `IMPORT_WATCH_STALL` the limit). Progress = the last Godot progress line CHANGING: B1's hang printed the same
`[   0% ] reimport | Oswald-Latin.ttf` 14,369 times over 4 h (1/s), so "no output" would never have fired. Stall limit **600 s**:
in 20 builder logs of rounds 40-44 no honest progress line repeated more than 6 times (~6 s), and a whole cold import of the
project on builder0 took **15 s** (godot-native-light after .godot/ was cleared, 9b6ffb0a6), so 600 s is ~40x a whole cold
import and a double hang costs 20 min, not the slot's 4 h. On a stall: kill, `rm -rf .godot`, import once more; a second stall
ends the run with `>> remote: import hung on <file>` as the wrapper's LAST line and exit **75** (make alone said 2).
Proof: `tools/test_import_watchdog.sh` (in shell-tools-test) 21/0 on the laptop: fake hang twice (exit 75, the line, .godot/
cleared, command never runs, no orphan), hang-then-clean retry, silent hang, slow-but-moving left alone, TERM kills the import,
slot.sh seam on/off/nested. Staged on builder0 end to end (light folder, `IMPORT_WATCH_CMD=` a fake hang, stall 15 s): killed,
retried, `>> remote: import hung on staged-hang.ttf`, wrapper exit 75. A warm import costs ~3 s extra per run (laptop 9 s).

**N2 profile (laptop, native OFF, 0b62c4900 + temporary timers not committed; test_control_scale 30 units / 6 squads, mean of
10 orders):** order 29-31 ms (ratio ~234 v budget 104). `SelectionSquads.untangle_whole` **13.8 ms (44 %)** (the 720-permutation
search); `RtsControls.gate_width` **10.5-11.4 ms (36 %)**: 1 call, 100 steps, ~200 `Pathing.find_path` = 5.6 ms + Callables and
the near_deck sampling; setup to `ranks` 3.9 ms; the rest < 1.5 ms. gate_width at ~0 still leaves ~150: hence N2b (R45.3).

**N2a gate_width C++ (in progress):** `native/src/gate_width_native.cpp` (one navmesh query a step serves crosses_on and drive_on: the
same `find_path(ground, click, p)`; the deck test a loop over `SlotGround.deck_boxes()`; `Orders.clamp_to_arena` called back once a
step). Seam `RtsControls.gate_width_edge_on` (new, beside gate_width; the GDScript gate_width untouched as the fallback) at the
ONE call site the group click uses (rts_controls.gd column_lay's width_at, a one-line edit; told orders). Switch
`BrainSwitches.native_gate_width` (ON). Equality: `tests/test_native_gate_width.gd` (4 arenas x 90 clicks, each deciding branch counted).

### Requests to other streams
- **orders:** rts_controls.gd: one line in `_order_squads`' column_lay call (`RtsControls.gate_width` -> `gate_width_edge_on`,
  same Callables) and the new `gate_width_edge_on` above `POST_SPAN_M`. N2b: one guarded seam line at the top of
  `SelectionSquads.untangle_whole` (R45.3).

### Questions for the lead
- None.
