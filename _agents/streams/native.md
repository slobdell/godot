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

**L2 twin RE-PROVED on engage's frozen efe4d8ba9: EQUAL** (builder3 light): efe4d8ba9's `test_native_decide|fire_lanes_crowd|
engage_lane_line` 13 / 0 (decide 7536 / 0, 78 lane-only CLEAR_LANE); his replays with v without engage's routing guard byte-identical
(Gorge 426/426, Terminus 2071/2071). **R46.11 (replays turn off rules his build lacked): 882c62d7c** — the match row's `rules`
stamp (`lane_clear`), tests/replay/rules.py in replay-match (and so playtest-report): on efe4d8ba9 + it, his Gorge replays 20/20 to
107 s again (was 11/20 from 50 s with L2 ON) and Terminus reads main's 17/20 at 151 s. Laptop: recorder tests 6/0, rules 3/0.
Evidence `references/round46/native/l2-reproof-r4611-builder3-efe4d8ba9/`. **33edf6eaf GREEN builder3** (3472 / 0, ALL JUDGED).

**L2 twin (engage, C46.4): EQUAL.** C++ on stream/native ee607ade6 (decide_native.cpp reads TankBrain.LANE_CLEAR live, as
ENGAGE_WATER; absent on main = unchanged: test_native_decide 7536 / 0). pair/native-l2 165bea71f = engage 9446e1903 + it, engage's
GDScript-routing guard removed + test_native_decide's lane mutations: 7536 decisions / 0 mismatches, 78 lane-only CLEAR_LANE (laptop;
a broken attack edge reads 29 mismatches); builder3 light engage's set + the twin 78 / 0; his Gorge 426/426 and Terminus 2071/2071
replay rows byte-identical engage v pair (`references/round46/native/l2-twin-proof-builder3-165bea71f/`). Engage merges the pair onto
894f561dd and freezes; native re-proves on the frozen hash.

**R46.6 the sel row: GREEN 1843eb6df builder3** (3472 / 0, 28 targets ALL JUDGED, `exited 0`): his Gorge 490/490 and Terminus
2141/2141 replay rows byte-identical with v without it (`references/round46/native/sel-row-proof-builder3-274177400/`); format sent
to camera. **a734c2296 GREEN builder3** (3470 / 0, ALL JUDGED): merged alone as main 200b7b920.

**Today's big click (the orchestrator's ask): main 7189e3ff3 (code cb1014bed), builder3 quiet (load 1.9), `make native-fresh
control-timing`, test_control_scale 30 units / 6 squads, mean of 10: order 2.03 ms, ratio 56.3 v budget 104; click-to-order 2.13
ms, 59.3; per-frame 0.62 ms, 17.7 v 26. 5/0 + 8/0.** (builder3 is not the box the budget was set on: builder0's round-45 read was
3.68 ms / 89.8 on eec905e52, not judged.) So today's default click is already well under budget; N1's speed matters only for what
V1 / V4 add on top. **Found and fixed on the way (tools/remote.sh, 47d0ff61c+):** a fresh light folder has no C++ library and
control-timing does not build one, so my first two reads timed the GDScript fallbacks in silence (6.86 ms, ratio 180.6, "2 failed").
A remote run now runs `native-fresh` first (not for check / native* / NATIVE=off; `REMOTE_NATIVE_FRESH=0` skips;
`tools/remote_native_first.sh`, its test 12/0). Proven on builder3: native/bin removed, control-timing built it and read 2.02 ms / 56.0.

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
