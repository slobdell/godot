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

**REPORT (2026-10-30 ~03:50 PDT). GREEN: 9d1580b77 builder3 (3473 / 0, 28 targets ALL JUDGED, `exited 0`); merge here: 9d1580b77
(later commits are this Status only). On main already: a734c2296, 1843eb6df, 33edf6eaf, a06d450df.** In his terms:
- **Big group clicks are already instant:** his 30-unit right click on main is 2.03 ms (ratio 56 v the 104 budget, builder3). The veto
  adds ~0.1 ms (R46.13, no twin); orders cut his failing Gorge click from 45-66 ms to 10.5 ms in GDScript.
- **His IFV's lane fix runs in C++ too, bit for bit (L2 twin):** proved on engage's freeze efe4d8ba9 (7536 decisions / 0; his Gorge and
  Terminus replays byte-identical with v without the GDScript route).
- **His short move to a wheeled crew drives forward in C++ too (shortfwd twin):** proved on manoeuvre's freeze adeb71696 (2360 drives
  / 0; manoeuvre's corpus 14 / 14).
- **His games replay as he played them, to the end:** a recording now stamps the rules its build ran (`rules`), replay-match turns
  off a rule his build lacked (L2's `--lane-clear=off` for every older game), and the "drift" at Terminus' last second was his results
  screen: his match replays bit-exact to its final hash. Recordings also log every selection change (`sel`, for camera).
- **Builder reads can't silently time GDScript any more:** a fresh builder folder now builds the C++ library before any timing run
  (my first big-click read was the GDScript fallback, 6.86 ms).
**Backlog:** N1 DONE (seam agreed; the speed-up not needed at 2.03 ms; the memo (B) left as stretch, R46.13/orchestrator). N2 DONE so
far: L2, shortfwd twins EQUAL; V1 / A6 v5 / R46.19 need none (read, recorded). N3 CLOSED (camera sliced, 0.35 ms on the laptop). N4
OPEN: `lines_r46.py` scaffolded; lines land as the round's verdicts are ruled (none ruled yet); G2's D1 / D5b marked VOID in lines_r45.
N5 DONE (builder3 27 % disk; laptop ~360 MB freed into a tarball). Stretch DONE as a proposal (round 47: ElementPlan.build ~1.1 ms a
tick, then build_situation 1.51 ms; R46.16).
**What to playtest:** nothing new on screen from native. To re-read his games: `make replay-match RECORDING=references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl REPLAY_SECONDS=150 CREWS=all`
**Next:** re-prove any twin on a freeze that moves (engage's L1, manoeuvre's shortfwd); lines_r46 as verdicts land; re-render the table
at the close. **Merge notes:** pair/native-l2 (in engage's freeze) and pair/native-shortfwd (in manoeuvre's) carry stream/native
commits; traffic.gd's shortfwd gate line and tank_brain.gd's decide guard are removed only on those pairs.

**Report (2026-10-30, start).** Started from main 7189e3ff3 (code = cb1014bed; the orchestrator's launch check runs it on builder3; no
baseline check of mine).

**Stretch: where his Terminus tick goes (proposal, numbers before code).** `make replay-match RECORDING=<his Terminus>
REPLAY_SECONDS=149 CREWS=all REPLAY_FLAGS=--sim-profile` (tests/replay_orders.gd now honours `--sim-profile`; profiling only: the
replay stays 20/20 within 3 m), stream/native a06d450df+, builder3 light, native ON, 4500 ticks, n=1:
**tick 14.18 ms**; controllers 9.12 (brain/think 4.90: situation 1.51, t.poll 0.89, decide 0.64 already C++, act 0.64;
brain/execute 3.67); **elements 3.06 ms (one segment, no sub-sections)**; tanks 1.02 (drive 0.61); visfield 0.38; match 0.34.
Candidates: (a) `segment:elements` 3.06 ms: Element.update for the replanning elements, GDScript, nothing native; needs a sub-profile
first (element.gd is engage's / element_plan manoeuvre's: profile sections are additive lines in their paths, so asked through the
orchestrator); (b) `brain/situation` 1.51 ms (build_situation, GDScript; s.contacts 0.55 the largest part). Recommendation: (a)'s
sub-profile next, then port whichever single function is >= 1 ms with its GDScript kept as the fallback. JSON:
`references/round46/native/terminus-sim-profile-builder3/sim-profile.json`.

**shortfwd twin (manoeuvre M5, C46.4): EQUAL.** stream/native 7e3874bab: drive_native.cpp shortfwd_on / his_short_move natively, the
forward arc's test called back (_kturn_frame / _outline_offs / _arc_hit, his short move only); tests/test_native_drive_shortfwd.gd
2360 drives / 0 mismatches, 166 forward-arc ticks (laptop; a flipped turn sign reads 155 mismatches); every drive twin on builder3
light 14 / 0. pair/native-shortfwd 4ac0236bd = manoeuvre 8796e94f4 + it + traffic.gd's gate line for shortfwd dropped: manoeuvre's
corpus (SHORT_CORPUS=on SHORT_SEEDS=7001-7007, builder3 light) native v GDScript 14 / 14 SHORT_ROW rows byte-identical. **Bar shortfwd's freeze cec4e499f** = 4ac0236bd + 6 test/make lines (mk/manoeuvre.mk, tests/test_manoeuvre_short_move.gd; `git diff --stat`): the proof holds on it; its merge (it carries stream/native 7e3874bab) goes through the orchestrator. **Re-proved on the moved freeze adeb71696** (= cec4e499f + manoeuvre's 258ce00f0, holdway's cache as static scratch, which the C++ drive never reads): builder3 light test_native_drive* + movement + controller + exec_state 19 / 0; corpus native v GDScript 14 / 14 byte-identical. **R46.19 (engage's weave water guard): no twin** — ENGAGE's combat move (`_act`) is GDScript on both paths (the native controller calls `think` back; the brain's native call sites are decide, situation_core, matchups).
**R46.11 + the divergence end rule: GREEN a06d450df builder3** (3472 / 0, ALL JUDGED). **N3 closed:** camera sliced its planner to
one pose a frame (camera 1f3e6f111; laptop 0.35 ms mean, p99 0.9) and dropped the ray batch. **R46.13 stands:** orders cut his
failing Gorge click's veto from 45-66 ms to 10.5 ms in GDScript (f6bb52518; laptop, native ON).

**Elements sub-profile (R46.14 probe, branch probe/native-elements 9145cc82a, NOT merged; builder3 light, his Terminus 149 s,
native ON, n=1, this run's tick 12.24 ms):** elements segment 2.67 ms = Element.update 2.62 (2.32 calls a tick): **ElementPlan.build
1.06 (0.46 ms a call)**, ElementSituation.build 0.55, ground (apply_swap / ground / ground_stations) 0.32, post (_take .. _issue) 0.32,
pre-plan (corridor, transit, crossing, stall) 0.25. **Proposal (round 47, owners' code, so not this round):** ElementPlan.build is
the round's single biggest GDScript function on his match (~1.1 ms a tick here; the laptop reads ~2.75x builder0); next is the
brain's build_situation (1.51 ms, contacts 0.55). Either port needs its owner (manoeuvre / engage) to agree and a twin proof like
decide's. JSON beside the first profile.

**His Terminus replay is bit-exact to the end of his match (3888ff416).** The "17/20 at 151 s" was post-match: his match ended at
tick 4471 (149.0 s, elimination); the census rows after it are his results screen v a headless replay running on. Through 149 s
every crew 0.0 m, and the replay's end row equals his (tick 4471, state_hash 4682461502ba5500). divergence.py now judges to his
`end` row and prints `END his= replay= state_hash=same|differs` (a differing end fails): Terminus 20/20 PASS, Gorge 20/20.

**R46.13 no veto_failures twin:** the veto costs ~0.1 ms (orders f77e16230, builder3 light, test_control_scale 30 units / 6 squads,
mean of 10, n 2 a side: 2.31 / 2.32 v 2.22 / 2.23 ms, ratio ~61 v ~58 of 104). **A6 v5 (C46.4) confirmed:** the street hold has no
C++ copy; the native drive calls back NativeTraffic.avoid_hold (Traffic.refresh / hold_of in GDScript) and only reads `_live`;
holdway (manoeuvre 97403a089) touches nothing the C++ reads.

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

**Questions for the lead:** none. (Laptop housekeeping: rounds 36-40's raw native folders `~/projects/godot-native-guard-raw`,
`-score-raw` and five `.out` files, whose judged results are in `references/`, are packed in `~/projects/godot-native-old-raw-r36-r40.tar.gz`
(21 MB, verified, 5307 files; ~360 MB freed). Delete the tarball whenever you like.)
**Requests to other streams:** orders, the V1 seam above (through the orchestrator).
