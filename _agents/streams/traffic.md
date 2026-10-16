# Stream: traffic (his two yeses ship first: the Terminus crossing give-way and the set-up mortar truck; then the default arena's navmesh gap)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 31 close: his two answers*,
> `_agents/judging.md`, `_agents/workstreams.md` **Round 32** (C32.1, C32.6, C32.8; C31.1–C31.3 and R31.1–R31.10 stand),
> `_agents/roadmap.md` *Round 32 candidates*, and your round-31 brief `streams/archive/round31/traffic.md` (the T3b-c and
> T1c-b2 bars, verdicts and traces; the early-stop hook). **You own:** `game/ai/avoidance.gd`, `game/ai/steering.gd`,
> `game/ai/traffic*.gd`, in `game/ai/movement.gd` the give-way block (`right_of_way` through `_blocker`), `_avoid`,
> `_around_friends`, `_ask_behind`, `_hull_within`; `tests/test_traffic*.gd`, `tests/traffic/**`,
> `tests/ai_scenarios/scenario_traffic*.gd`, `tests/test_avoidance.gd`, `mk/traffic.mk`, `tools/series_cache.sh`,
> `tools/quick_tests.sh`, `mk/infra.mk`, `tests/run_tests.gd`'s shard plan. **Granted this round (C32.6 only):** `arenas/**`
> and `game/arena/**` for the navmesh gap. **The C++ (C31.2):** `right_of_way`, `_avoid`, `Avoidance.solve` and the hold have
> C++ twins; send native each settled diff before its commit. **Model:** Opus.

## The lead's direction

Round 28: **TAKE TURNS**: "fewer bumps; both squads arrive a little later." Round 31's close (2026-10-16): **"For the two
decisions you gave me, yes to both."**
1. **Terminus street crossings (T3b-c): YES.** His ~3 s price for the squad that gives way covers a Terminus street crossing
   as well as the yard (judged: Terminus +2.61 s, yard +3.38 s, bumps at Terminus 93 → 61; builder0, `f5dc4147`, seeds
   41–43, n 18).
2. **Set-up mortar truck (T1c-b2): YES.** It stays set up and firing, and squadmates go round it (packed up for a passer in
   6/18 fights → 0/18, rounds fired 434 v 437; builder0, `33cb2da5`, seeds 41–46, n 18).

What he will notice: at a Terminus street crossing the squad that gives way waits a couple of seconds and the two squads
stop shoving through each other; his mortar trucks keep shelling while a squadmate drives round them.

## Where things stand (main at the round-32 docs commit; it inherits `e66b41f1`'s green check: builder0 exited 0, 2657/0, ALL JUDGED)

- Your round-31 branch is `round31/traffic` (renamed, kept, NOT merged). The judged trees: **`traffic-t3bc-judged`
  `f5dc4147`** (= native `413252ea` + traffic `ab3351fb` + `Traffic.DEFAULT_OFF = []`) and **`traffic-t1cb2` `33cb2da5`**
  (round 30's `16780030` + measurement, the rule ON by default; native: NONE PORTED). `traffic-t4` is kept (T4 v1 merged OFF,
  `ghost` opt-in; not in CP-H).
- Main moved since the judging: CP-H (unstickback, kturnarc, realspeed, realslow ON), CP-P1 (the C++ planner for hulls ≥ 10 m
  ON) and the corrected baselines. That is why C32.1 asks for the check AND a judgement on whether the judged numbers moved.
- The early-stop hook (`tests/traffic/seq_hook.py`) and `CACHE=auto` are on main.
- The navmesh gap (brains' reach probe, round 31): in the default arena at (-25.7, 7.3), where
  `test_control_queued_task`'s Green_Alpha_3 stops, the navmesh start snaps 8.2 m to (-17.5, 7.3), so pathing answers
  `no_path`. Today round 29's lock reverse frees the hull (R31.5 keeps it for terrain pins).

## Backlog (in order)

1. **T3b-c ships (CP-T, C32.1).** Carry `traffic-t3bc-judged` onto current main as one commit (with native: they re-carry
   `413252ea` on their branch; the pair tree is built in one place, agree which with native and tell the orchestrator).
   `make quick-remote` first, then **`make remote T=check` on the pair tree, switch ON by default** and name that hash.
   Expected red: sim-baseline ALONE with the moved maps listed; any other red is a finding. Then **does CP-H/CP-P1 move what
   was judged?** Re-run the T3b-c series ONCE on the new tree against round 31's filed bar (seeds 41–43 × six ticks, n 18,
   base `--traffic-off=turns`, `turns_verdict.py --allow yard_open/cross=3.0 --allow terminus/cross=3.0`: his ~3 s now
   covers both). If it passes, name the ship hash; the orchestrator merges the pair back to back and re-records the
   baselines. If a line fails, trace the worst run, write it up, and stop: it goes back to him.
2. **T1c-b2 ships (C32.1).** Carry `traffic-t1cb2` onto main (after T3b-c lands, so the pit baseline is re-recorded once).
   `traffic-native-verify` + `native-verify-scenarios` on the tree, native's "none ported" confirmed, `make remote T=check`
   with the rule ON, the census re-run ONCE on the new tree against round 31's bar (deciding line read as 0/18 repacks
   while firing; the guards as filed). Name the hash.
3. **The navmesh gap (C32.6).** First the diagnosis, with evidence: a screenshot of the default arena's baked navmesh
   around x −25…−18, z 7 with the obstacle footprints overlaid, and the bake inputs (agent radius, cell size, the
   geometry source). Is it a bake hole (standable ground left out) or an obstacle footprint the hull was pushed onto?
   A bake hole: fix the bake (only the default arena), a test that `NavigationServer3D.map_get_closest_point` at
   (-25.7, 7.3) is within 1 m, the full check, and the sim-baseline move with its reason to the orchestrator. A
   footprint: write it up for brains (route) and manoeuvre (escape) and stop.
4. **Test splits (C32.8):** after native's four, any traffic file over ~60 s in `tests/shard_times.txt` (round 31 found
   none; run `make test-times` on builder0 first, since brains' split files have no rows yet).
5. **Stretch: T4 (ORCA's ghost) as its own consumer A/B** on the CP-H tree: `pair/t4-on` `93c85531`, the ON gate `check
   NATIVE=off`, then a bar to the orchestrator before numbers.

## How to verify

`make quick-remote` to iterate; `make remote T=check` only for a hash you name (C31.1's pair-tree check before every judged
series). `traffic-series` (with the hook), `traffic-census`, `traffic-native-verify`, `native-verify-scenarios`,
`bridge-pooled`; `traffic-clip` of the Terminus crossing for him. Long remote runs under `systemd-run --user` (a shell
wrapper is reaped). Every number carries commit, machine, workload, n and its `judging.md` row.

## Don't touch

Manoeuvre's drive body / unstick / k-turn executor / H1; the planner's `game/ai/planner/**` and plan source; brains'
`_track_progress`, `_update_phase`, `_approach_gate`, elements, `game/tactics/**`, `tank_brain.gd`, `gunnery.gd`; native's
`native/**`; `game/control/**`, `game/tank/**`; `tests/baselines/**` (the orchestrator adopts); `tools/judge/**`.
`origin` still holds an old `stream/traffic`: don't push.

## Waiting on the lead

Nothing: both answers are in. A failed re-judge goes back to him through the orchestrator.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n and its row; bars to
the orchestrator before numbers; green hashes named)_

**2026-10-16 (traffic worker, round 32).**

**Plan (in order):** (1) CP-T T3b-c: carry the judged tree onto main, quick-remote, native builds/checks the pair tree
(R32.1: native's mirror `413252ea` is already on main, inert until Traffic has `shape`), then ONE re-judge on it; (2) T1c-b2
carried after T3b-c lands; (3) navmesh gap diagnosis; (4) test splits if any traffic file > ~60 s; (5) stretch T4.

**CP-T, T3b-c carried:** `b5882c9c` on stream/traffic = main `6efdf42b` + `e57f93d2` (as `ac15ac0b`) + `ab3351fb` (as
`67aa9c76`) + `DEFAULT_OFF := []` (turns ON). The one conflict of substance, `Movement._avoid`: main's T4 `ghostself`
read (OPT-IN, off) and T3b-c's `Traffic.shape` combined, shape first, the 0.04 early return against `route_preferred`
(the native drive's order, `drive_native.cpp` 556–603). `traffic.gd`: `OPT_IN` and `DEFAULT_OFF` both kept and parsed.
Re-judge configuration (decided): as round 31's judged run, `--brains-off=native` both arms (GDScript path), base
`--traffic-off=turns`, seeds 41–43 × {1,3,6,8,11,16}, n 18, `turns_verdict.py --allow yard_open/cross=3.0 --allow
terminus/cross=3.0`. Reason: the question is whether CP-H/CP-P1 moved what was judged, so the arms match the judged run.

**C32.6, the navmesh gap: DIAGNOSED, no bake fix. It is a probe artifact, not a bake hole or a footprint** (`b71fb9b0`,
laptop, headless Godot 4.7.2; geometry facts, so they don't depend on the machine).
- **The default arena's own bake covers the spot.** On `foundry`, the default layout, `map_get_closest_point(-25.7, 7.3)`
  is 0.00 m away. The spot sits 0.45 m north of Crate_7's carved edge (a 4.5 m crate at (-24, 12) plus the 2 m agent
  radius). Routes from it reach both of the test's shift-waypoints.
- **The 8.2 m was Terminus's navmesh.** On `terminus`, the same spot snaps 8.2 m to (-17.5, 7.3), because a city block
  stands there. The round-31 reach probe (`tests/tactics/reach_probe.gd`) runs its labs in one process, and its later
  labs ask before the map holds the new arena's regions. `Pathing.is_ready` answers true from the previous map: this is
  `ArenaFixture`'s documented round-6 trap. I reproduced it: in a copy run default arena first, then Terminus, the
  Terminus lab read 0.0 m, which is the default arena's answer.
- **Bake inputs:** cell 0.5 m, cell height 0.25, agent radius 2.0 m, height 1.75, climb 0.25, slope 45°, collision
  shapes (layer 1) in the group `navigation_source`. The south half is baked (filter AABB z ≥ −2.5, border 2.5) plus a
  180° mirror region.
- **Evidence:** `references/round32/traffic/navgap_default_arena.png` (the fresh bake, footprints and their 2 m carve) and
  `navgap_terminus_same_spot.png`. Probe: `tests/traffic/navgap_probe.gd` (`--arena=`, `--after=<layout>` replays the
  stale-map case) and `navgap_plot.py`. Pinned by `tests/test_traffic_navgap.gd` (2/0 on the laptop): within 1 m on the
  default arena, and the 8.2 m reading on Terminus.
- **Side finding, not fixed (reported):** the bake leaves a small navmesh island on top of each 3 m crate. The 1.75 m
  agent height lets the top count as standable, and the 0.25 m climb keeps it disconnected. A goal point inside a crate
  could snap to that roof and become unreachable. It is harmless today, and fixing it would move every arena's bake (so
  the sim baselines), so I'm only reporting it.
- **Requests:** to **brains**: the reach probe should build its labs through `ArenaFixture` (or wait for its own
  regions), or its later cases read the previous arena. To **manoeuvre**: Alpha_3's round-31 "held by the ground, no
  contact" at (-25.7, 7.3) is on the mesh, right at Crate_7's carve, so it is your escape's case, not the navmesh's.
  R31.5's fallback already frees it on main.
