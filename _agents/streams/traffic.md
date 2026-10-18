# Stream: traffic (a crew pinned behind a parked crew of another squad gets by: the far ask loop in skirmish; then T4's circling hull)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 33**
> (C33.2, C33.7; C31.1–C31.3, R31.1–R31.10, R32.1–R32.7 stand), `_agents/roadmap.md` *Round 33 candidates*, your round-32
> brief `streams/archive/round32/traffic.md` (T4-ON's numbers, the TacticsLab dispose lesson), and manoeuvre's
> `streams/archive/round32/manoeuvre.md` (*Round 32 close*: the far rows, `blocker_kind`, *Round-33 lessons*; *C32.10 swap:
> PARKED*). **You own:** `game/ai/avoidance.gd`, `game/ai/steering.gd`, `game/ai/traffic*.gd`, in `game/ai/movement.gd` the
> give-way block (`right_of_way` through `_blocker`, including `_negotiate`, ask, `_begin_yield`), `_avoid`,
> `_around_friends`, `_ask_behind`, `_hull_within`; `tests/test_traffic*.gd`, `tests/traffic/**`,
> `tests/ai_scenarios/scenario_traffic*.gd`, `tests/test_avoidance.gd`, `mk/traffic.mk`, `tools/series_cache.sh`,
> `tools/quick_tests.sh`, `mk/infra.mk`, `tests/run_tests.gd`'s shard plan. **Granted (stretch only):** `arenas/**`,
> `game/arena/**` for the crate-roof navmesh islands. **The C++ (C31.2):** `right_of_way`, `_avoid`, `Avoidance.solve`, the
> hold have C++ twins, and N5 (`_negotiate` / ask / `_begin_yield`) is held for YOUR design: send native each settled diff.
> **Model:** Opus.

## The lead's direction

Round 28: **TAKE TURNS**: "fewer bumps; both squads arrive a little later." Round 31's close: yes to both crossing calls
(shipped in round 32). No new words at round 33's preparation (2026-10-17).

He was told at round 32's close, as a known issue he may see: **a crew stuck behind a parked crew of ANOTHER squad nudges
back and forth (ask, back up, drive in again) instead of getting by.** What he will notice when this ships: that crew gets
by, because the parked crew makes room or the stuck crew goes round, and nothing else he plays changes.

## Where things stand (main at the round-33 docs commit; inherits `0c124cf7`'s green check: builder0 exited 0, 2724/0)

- **On main and ON:** T3b-c (the crossing give-way, his yes), T1c-b2 (the set-up mortar truck stays set up, his yes),
  manoeuvre's H1b (a crew stuck behind a squadmate that never moves, NEAR its goal, stops short). H1b's failed-ask count
  and the `H1B_FAR` rows with `blocker_kind` (same_element / other_element / unseated / no_elements) are on main
  (`ManoeuvreCensus.print_new_far_rows()`, printed by fight_census and the MANOEUVRE_TURNS probes).
- **The far loop's only skirmish evidence** (manoeuvre, builder0, fights 400–423, n 24, `a13a9399`): 6 far rows; 5 are
  other_element + PARKED (4 × Green_Guns_4 behind Green_Eyes II_3, 54 m of route left, gap 6 m; 1 × Rust_Battery2_1 behind
  Rust_Battery_5, 19 m), 1 same-element under way. Round 32's Terminus-drive hunt (105 loops / 16 seeds) is NOT his case:
  that harness forms no elements.
- **C32.10's seat swap is parked** (0 swaps in skirmish): different elements share no seats. Round 32's dropped back-off
  needed 11–20 m of reverse and straight room met it 0/62 on Terminus.
- **T4 (the ghost) is OFF** (`0adc6deb` on `traffic-t4-on-r32`): mixed stuck −48 % but unproven at n 24; the yard
  head-on's last hull circles its slot 15–20 s with the ghost on.
- Your round-32 branch is `round32/traffic` (merged).

## Backlog (in order)

1. **X1 The census (C33.2 (1)), REPORTED, before any design.** Far rows by `blocker_kind`, blocker parked or moving, route
   left, gap, over a sample big enough to say how often he meets it: fights (fresh seeds), hull-rest drawn/clicked, and
   skirmish on Terminus and the Locks (`make skirmish ARENA=locks` is his bridge) with elements formed (CHECK the harness
   forms them first, manoeuvre's lesson 1). The table: far loops per match by kind; who is parked where (its own slot,
   a firing spot, a hold post). Commit the table under `references/round33/traffic/`; message the orchestrator the
   frequency. If the case is rarer than ~1 per match the orchestrator decides whether to build.
2. **X2 The design (C33.2 (2)), written in this brief before code**, agreed through the orchestrator: when H1b's count trips
   on a PARKED crew of another element, either (a) the parked crew yields (your `_begin_yield`, to a validated spot off
   the asker's corridor, then returns), or (b) the parked crew's element shifts its seat (brains' make-room; a seam
   signature agreed with brains before either side writes code). One reason recorded for the choice. Native is told the
   design the day it settles (it unblocks N5).
3. **X3 Build, pair tree, bar, series.** Behind a switch, default OFF; one real end-to-end case of the rule with elements
   formed before the series (lesson 2: a seam a stage test plays through an override is unexercised); the whole suite on
   the pair tree with the switch ON; the bar filed in `workstreams.md` *Bars (round 33)* before numbers: far loops down on
   the skirmish stages, arrivals not down, the parked crew's task not broken (a set-up mortar truck still never repacks:
   T1c-b2's line), no sim-baseline move unexplained. Ships ON as a pair.
4. **X4 T4-ON (C33.7):** trace one circle loop (the yard head-on's last hull with the ghost ON; tell brains what you find:
   it is also B5c-v6's case), then mixed stuck re-judged at n ≈ 48 on fresh seeds, bar first.
5. **Stretch:** the navmesh islands on 3 m crate roofs (the grant above): establish the bake input that makes them, re-bake
   only what needs it, sim-baseline moves go to the orchestrator with the reason.

## How to verify

`make quick-remote` to iterate; `make remote T=check` only for a hash you name (the pair tree, switch ON, before every
judged series). `traffic-census`, `traffic-series` (the early-stop hook), `manoeuvre-fights` / fight_census for far rows,
`traffic-native-verify`, `native-verify-scenarios`; a clip of one far-loop case before and after for him. Long remote runs
under `systemd-run --user`. Every number carries commit, machine, workload, n and its `judging.md` row. A test that builds a
`TacticsLab` must `dispose()` it in `teardown()` (trip-up 83).

## Don't touch

Manoeuvre's drive body / unstick / k-turn executor / H1 and H1b (you READ its count and rows; a hook you need there is
asked of manoeuvre); the planner's `game/ai/planner/**`; brains' elements, `game/tactics/**`, `tank_brain.gd`, `gunnery.gd`,
the seating; native's `native/**`; `game/control/**`, `game/tank/**`, `game/match/**`; `tests/baselines/**`;
`tools/judge/**`. Don't push.

## Waiting on the lead

Nothing. X1's frequency may become a question for him through the orchestrator, in player terms.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

## Overnight (round 33 extension, 2026-10-18 ~00:45 PDT)

The lead has gone to bed and wants builder2 kept busy. Take these items in order (`workstreams.md` *Round 33, overnight
extension*; the details are in `roadmap.md` *Round 34 candidates*). Merge main first. builder2 FIRST (`make gcp-remote`,
6 heavy slots). Every judged stage pinned at `--fixed-fps $(SIM_HZ)`. A bar is filed (sent to the orchestrator) before any
number, judged on FRESH seeds, and every number labelled with its machine. Keep this Status current: the lead reads it in
the morning.

1. **parkedroom v2:** the room rule only for a crew AT a post (not one paused between orders). The bar is fresh, on new
   fights (not 700–723), with L1 on hold-post far loops plus all parked far loops not up, and L6 (return) kept (R33.12).
2. **T4 ghost, third try:** the cohesion guard on `tests/tactics/body_probe.gd` children at --fixed-fps (brains'
   f8cf6476 shape), plus a REPLAY line (a same-process rematch replays exactly, ghost ON, or the reason it needn't:
   R33.17 and roadmap), then the Terminus re-judge.
3. **The fire-post loop** (random-705, 20 loops): diagnose who refuses whom and why, with brains (it borders the
   battery item). Report an owner proposal; build nothing.
