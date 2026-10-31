# Stream: native (the game stays fast at the cost cap; every ON rule has its C++ twin; rematches replay exactly)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 351, 353, 354), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 48** (C48.1-C48.4) and **Round 47** (C47.1-C47.11; C47.6 is yours; R47.16, R47.18, R47.47), your last brief
> `streams/archive/round47/native.md` (FINAL REPORT and *Round 48's native list*). **You own:** as round 47 — `native/**`, `mk/native.mk`,
> `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`, `tools/slot.sh`,
> `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tools/builder_checks.sh`, `tests/ai_scenarios/guard_line.gd`,
> `mk/play.mk`'s skirmish recipe, `mk/gcp.mk`, `_agents/judging.md`, `tests/replay_orders.gd`, `tools/recording_arrivals.py`,
> `tools/playtest_report*`, `tests/replay/**`, `game/match/match_recorder.gd`'s `rules()` table (additive); GRANT the C++ seams in
> `game/control/**`, `game/ai/tank_brain.gd`'s native call site, and the native call site of `ElementPlan.build` / `ElementSituation.build`,
> each GDScript body kept as the fallback. **Model:** Opus. **Machine:** builder3 (builder0 is DOWN). **Seeds:** 13505-13552; twins run
> on the owner's.

## The lead's direction

Memory: native code is C++ (core components in C++ long-term, even without a gain); the laptop is the test bed (UHD 620; perf cuts ship
as hardware presets). At the 1000-credit cost cap he gets ~10-12 fps as gangs on the laptop (round 47).

## Where things stand (main df9aacc1a GREEN builder3 3630/0)

- C++ ON: place, esit, matchups; doors and the sight class's eye mask; the replay stamp carries every round-47 rule (lesson 354).
- Replays of his matches part at ~11 s (cause 2: an unrecorded live input; his recordings will carry `inp` rows from now on).
- The yield-cycle (sliver) test PENDING (R47.47): same-process Jolt carry-over moves a lab by cm.
- The laptop ratio ~3.0x builder3 (measured round 47).

## Backlog (in order)

1. **N1 twins as bars arrive** (C47.6): manoeuvre's give-way fix (Bar B), engage's retreat (Bar E11), orders' follow station (Bar F if the
   native drive reads it). Output-identical first; each with its replay stamp entry. Answer within the hour a stream asks.
2. **N2 contact_prototypes' rebuild in C++** (~0.7 ms a frame on his laptop at the cost cap). Judged on the laptop preset, lock-held read.
3. **N3 the same-process physics carry-over:** Jolt state left by earlier matches in one process (`make native-repeat ... REPEAT_JITTER=on
   YIELD_CYCLE=on` is the tool); matters for rematches and netplay; unblocks R47.47 with manoeuvre's M6.
4. **N4 the laptop fog readers' unexplained ~2 ms** (`references/round47/native/fogread-laptop`).
5. **N5 R47.18 the army layout's bake timing** (ARMY_LAYOUT_UNCHECKED: standable queries before the navmesh).
6. **N6 replay cause 2** once one of his recordings carries `inp` rows (the orchestrator relays the file when he plays).
7. **Stretch:** a laptop-preset fps read at the cost cap, gangs v syndicate on Crossing, before / after N2-N4 (the number he'll feel).

## How to verify

`make remote T=check` for a hash you will NAME (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote` to
iterate; VERIFY proofs in check for every twin; laptop reads lock-held only (`flock /tmp/tank-squad-laptop-godot.lock`), one at a time,
five sessions on a 7 GB laptop. Every number with commit, machine, workload, n.

## Don't touch

The GDScript bodies you twin (owners change them; you mirror), `arenas/**`, `game/camera/**`, `game/units/**`, `tests/baselines/**`
(the orchestrator adopts), `tools/spotter/**`.

## Waiting on the lead

Nothing at launch.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
