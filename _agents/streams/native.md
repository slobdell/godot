# Stream: native (big group clicks answer instantly; every rule that ships ON has its C++ twin; the judging table and the builders)

> Read `_agents/orchestration.md` (the worker contract; lessons 336, 341-343, 346), `_agents/judging.md`, `_agents/remote_builds.md`,
> `_agents/workstreams.md` **Round 46** (C46.1-C46.8; C46.4 is yours), your last brief `streams/archive/round45/native.md` (FINAL REPORT).
> **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`,
> `tools/loaded.sh`, `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tools/builder_checks.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe, `mk/gcp.mk`, `_agents/judging.md`, `tests/replay_orders.gd`,
> `tools/recording_arrivals.py`, `tools/playtest_report*`, `tests/replay/**`; GRANT the C++ seams in `game/control/**` (the fit's path
> queries, `gate_width`, untangle, `_assign`) and `game/ai/tank_brain.gd`'s native call site, each with the GDScript body kept as the
> fallback. **Model:** Opus. **Machine:** builder3; builder0 for perf-judge lines set there (quiet window). **Seeds:** the owner's.

## The lead's direction

Memory: native code is C++ (core components in C++ long-term); the laptop is the test bed (UHD 620). His asks this round are the
other streams'; native makes them fast and proves the C++ path gives the same game.

## Where things stand (main at launch: see HANDOFF; code 96f199c45 GREEN builder3 3470/0)

- gate_width / untangle / `_assign` in C++ on main (30-unit right click 10.4 -> 3.7 ms, builder0, not judged). The fit's ~60 path
  queries at his Gorge click cost 4.9 ms (orders' finding).
- builder3 is the default box (6 slots, ~10 min a full check, its perf nominal recorded); builder0 the reference for budgets set
  there; builder2 Spot, burst only.
- Replays: his matches replay 20/20 within 3 m; a native/GDScript disagreement fails loudly (exit 3).
- `tools/judge/lines_r45.py` + the judging table (`_agents/judging.md`) re-rendered at round 45's close.

## Backlog (in order)

1. **N1 the fit's path queries in C++** (orders' group lay; the seam agreed with orders through the orchestrator before code):
   output-identical first (the orders probe and the geometry table byte-identical native on v off), then `control-timing` judged.
   Coordinate so orders' V1 veto lands on the same seam (V1's test reuses the fit's path check).
2. **N2 twins as rules are filed (C46.4)**, in the order the bars arrive: engage's L2 (CLEAR_LANE scoring in native decide), orders'
   V1 / V4 if they touch a seam, manoeuvre's S v6 / A6 v5. EQUAL on the frozen bar tree, reported to the owner and the orchestrator
   the same hour. A twin is the bar's gate: it outranks N1 when a bar is waiting on it.
3. **N3 the camera planner's cost (C46.7):** if camera's per-frame budget on the laptop is over, offer a C++ ray batch for its
   occlusion term (camera owns the call; the seam through the orchestrator).
4. **N4 the judging lines:** `lines_r46.py` as verdicts land (V1, V2, L1, E6, S v6, A6 v5, C1); re-render the table at the close.
5. **N5 builders:** keep builder3 the default healthy (disk, cold-import watchdog, the full-check lock); `df -h` on the laptop each
   time you create a side worktree (lesson 341).
6. **Stretch:** the next GDScript hot spot by the sim profile on his Terminus recording (the round's biggest per-tick cost), proposed
   with a number before code.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make native-proof` / the probes byte-identical;
`make control-timing`, `make perf-judge` on the box the line was set on. Every number with its commit, machine, workload and n.

## Don't touch

Every other stream's GDScript bodies (your grants are seams only), `game/camera/**`, `game/ui/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Report (2026-10-30, start).** Started from main 7189e3ff3 (code = cb1014bed; the orchestrator's launch check runs it on builder3; no
baseline check of mine).

**Plan (order kept; reasons):**
1. **N1a the seam with orders, agreed through the orchestrator BEFORE code** (sent 2026-10-30). Fact: "the fit's ~60 path queries"
   are `gate_width_edge`'s per-step `Pathing.find_path`, already C++ since round 45 (NativeGateWidth); the cost is the engine's A*
   (~80 us a query, builder2), so a C++ port alone saves ~nothing. G2's `guard_failures` / `guard_across_gap` make no path query (pure
   terrain: over_water, leg_wet, beyond_neck). Proposed: (A) orders' `SelectionSquads.veto_failures(anchors, blocks, click, approach,
   ground, data) -> Array[int]`, twinned as one native call; any ground-path test goes through one `route_length(ground, from, to)`
   helper served from gate_width_native's proven pathing + path_length. (B) the speed-up that changes no output: a per-click memo of
   `find_path(click, p)` shared by every gate_width_edge scan and the veto in one click.
2. **N2 twins as bars are filed** (V1 first: it outranks N1's speed, the orchestrator 2026-10-30).
3. N1b the memo + `control-timing`; N3 camera's ray batch if asked; N4 lines_r46; N5 builders; stretch: Terminus sim profile.

**Questions for the lead:** none.
**Requests to other streams:** orders, the V1 seam above (through the orchestrator).
