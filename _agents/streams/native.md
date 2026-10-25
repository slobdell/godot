# Stream: native (the measuring tools under round 40: per-unit counts, same sim on every machine, fast)

> Read `_agents/orchestration.md` (the worker contract), `_agents/remote_builds.md`, `_agents/judging.md`, `_agents/workstreams.md`
> **Round 40** (C40.1, CP40.0). Your round-39 brief: `streams/archive/round39/native.md` (Status: the trig A/B, the copy-back fix, the
> full-check lock). **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`,
> `tools/perf_judge.sh`, `tools/loaded.sh`, `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe. Scratch trees `../godot-native-score` and `../godot-native-guard`
> are yours (their builder2 copies were cleared at launch; remote.sh re-syncs them). **Model:** Opus. **Machines:** builder2 for rows,
> builder0 only in a quiet window for perf.

## The lead's direction

Native code is C++ for core components (his call). He may buy a 16-core Ryzen tower (2026-10-24; memory *builder0 throughput*).

## Where things stand (main at launch: see HANDOFF)

N4 (CORE-MATH trig) ships: the laptop simulates the builders' fights. The trig A/B (main 6a1c77752, builder0 quiet, n 3 an arm): CORE-MATH
+169 us/tick (+2.2 %) v glibc 2.43's libm, 3/3 rounds. Full-check lock and copy-back fix merged. Main's perf: 7,691 us/tick (68d0410d3,
builder0).

## Backlog (in order)

1. **N1 per-unit counts in GUARD_RESULT (CP40.0, FIRST; balance waits on it).** For each side: per unit (id, type, faction, cost) kills,
   death (and the tick), damage dealt and taken. Additive fields; `guard.py` still reads old rows. Test: a fixture fight's tally sums to
   the row's kills. Name the green hash to the orchestrator the minute it's green; it merges alone.
2. **N2 a per-unit summary in `guard.py`** (`--by-unit`): per faction and unit type, kills/losses/damage per credit, paired arms.
3. **N3 the balance search's runner (for balance's B4):** run a candidate's stat overrides (a `--unit-overrides=<json>` flag read at army
   load, OFF by default; GRANT: the one read in `game/units/army.gd`, additive) across N seeds on builder2. Agree the json shape with
   balance via the orchestrator.
4. **N4 the trig's ~2 % (low priority):** a 5-round rerun of the A/B first; only if the sign holds at 5/5, try the FMA target clone or
   resolving to libm on glibc >= 2.41, with the twin and known-answer tests again.
5. **N5 (only if he buys the Ryzen):** measure it against builder2 on one full check and one guard chunk, add it to `remote.sh`.

## How to verify

Pure tests and twins; `make quick-remote`; a full check per named hash; perf only via `make remote-quiet T=perf-judge` on builder0.

## Don't touch

Brains (balance's), deploy (settle's), movement/traffic (manoeuvre's), `game/control/**` (orders'), `game/units/**` beyond N3's one read,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing (N5 waits on his purchase).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
