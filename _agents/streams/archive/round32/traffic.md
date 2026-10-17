> **ARCHIVED at round 32's close (2026-10-16).** This is the brief as its worker left it on `stream/traffic` at `0fc259bc`; the live round's briefs are in `_agents/streams/`.

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

**🏁 CLOSING REPORT (round 32).** Every backlog item is done.
- **Done:**
  1. **CP-T T3b-c (the crossing give-way) SHIPPED ON.** `b5882c9c` → main `86917d5a`; baselines adopted `0e49fb3e`.
     Re-judge PASS: Terminus clock +2.61 s v +3.90, yard +3.38 v +3.43, between-squad bumps −39 %.
  2. **T1c-b2 (the set-up mortar truck stays set up) SHIPPED ON.** `c9fa64a4` → main `36a531b4`, builder0 check exited 0,
     2708/0. Census PASS: repack while firing 5/18 → 0/18 (p 0.023), guards pass. The six askers that never got past are
     traced. The worst waited ~19 s and set up 19 m short.
  3. **C32.6, the navmesh gap: diagnosed, closed.** A probe artifact (a stale map in the reach probe), not a bake hole.
     Pinned by `test_traffic_navgap`.
  4. **C32.8, test splits: none needed.** No traffic file is near 60 s.
  5. **Stretch T4 (the ghost ON): judged, NOT SHIPPED** (below). Branch `traffic-t4-on-r32` `0adc6deb` kept, not
     merged.
- **Decisions:**
  - Re-judges ran on the GDScript path when the judged run did (T3b-c, T1c-b2), and T4 on the native path, the path that ships.
  - turns_verdict's pooled −25 % line is not read for T4, because it is T3b-c's gain line.
- **Questions for the lead:** none.
- **Requests to other streams:**
  - brains: the reach probe should build labs through ArenaFixture. Done, `5f0ed865`.
  - manoeuvre: Alpha_3 at (-25.7, 7.3) is an escape case.
  - manoeuvre: `test_manoeuvre_behind`'s war-rig planned turn is red on the GDScript path (NATIVE=off), identical with
    the ghost off.
  - planner and native fixed two order-dependent twin reds this round (`8904c9c4`, `45b52d04`).
- **Known issues:**
  - The navmesh islands on 3 m crate roofs (reported, not fixed).
  - T4's yard head-on slot loop.
- **Lesson (for orientation's trip-ups): a test that builds a `TacticsLab` must `dispose()` it in `teardown()`.**
  Otherwise the shard leaks ObjectDB instances at exit, and the engine-log gate turns the whole check red with no failing test
  named.
  - This happened twice: `test_traffic_ghost` in round 31 (14 ObjectDB) and `test_traffic_setup` in round 32 (20 ObjectDB / 4
    resources). I misread the second as another test's at first.
  - To find the owner: run the suspect file alone and look for the "leaked at exit" line.
- **Playtest:**
  - T3b-c: `make traffic-clip` (his crossing cases at his pose, per arm, needs a display).
  - T1c-b2: `make traffic-census-one CENSUS_ONE="parade gangs law 2000 opponent 43"` (the worst asker's run; TRAFFIC_ASKER
    lines in the log). Or in a match: set up a mortar truck, order it to fire, and drive a squadmate past it.
- **Next steps:** T4 comes back only with one circle loop traced and mixed stuck re-judged at n ≈ 48 (roadmap round 33).
- **🎯 Final check GREEN: stream/traffic `82a56293`** (main `bacfd7b5` merged), builder0 `make check exited 0`, 2708
  passed / 0 failed, 26 targets all passed, ALL JUDGED, sim-baseline all 13 unmoved. The commit after it is this report (docs only).
- Worktrees `../godot-traffic-judge` and `../godot-traffic-t1cb2` are removed. Branches `traffic-t1cb2-r32` (merged) and
  `traffic-t4-on-r32` (not shipped) are kept locally and not pushed.

**🎯 CP-T T3b-c: RE-JUDGED, VERDICT PASS. Ship hash `b5882c9c`** (the pair tree; native's mirror `413252ea` is already on
main). Builder0, `b5882c9c`, GDScript path (`--brains-off=native` on both arms, as round 31's judged run), seeds 41–43 ×
ticks {1,3,6,8,11,16}, n 18 a case, 90 s, base `--traffic-off=turns`, the full grid of 144 rows (0 cache hits, 0 missing),
`turns_verdict.py --allow yard_open/cross=3.0 --allow terminus/cross=3.0` (round 31's bar; his ~3 s now covers both
crossings). Files: `references/round32/traffic/t3bc_r32_{verdict,hook}_b5882c9c.txt`, `*_base/arm_b5882c9c.jsonl.gz`.
- **Terminus crossing clock: +2.61 s (se 0.55) v his +3.0 + 1.645 se = +3.90: pass.** 16/18 later. The yielding squad B
  is +4.22 s (se 0.64) and A is −1.09 s.
- **Yard crossing clock: +3.38 s (se 0.26) v +3.43: pass** (narrowly, as in round 31). 18/18 later.
- Between-squad fast contacts pooled over the two crossings: 191 → 117 (−39 %), pass (Terminus 93 → 61, yard 98 → 56).
  Crews: 176 → 179, 169 → 167, 173 → 175, 179 → 179, all pass. No wedge. Same-squad contacts 144 → 139 and 150 → 149.
  Head-on cases are within 1.645 se. All-in medians reported: Terminus 39.5 → 34.7, yard 33.3 → 33.8.
- Hook (table sd): yard crossing SERIES PASS at run 7, head-ons PASS (at 6 and 18), Terminus crossing PASS at 18.
- **Did CP-H/CP-P1 move what was judged? No.** Every judged line reads as round 31's `f5dc4147` did, apart from crews
  176→179 v 176→178. These fights are short-hull squads crossing, where CP-P1 (≥ 10 m hulls) and CP-H's pinned-hull
  consumers barely act. Worst runs (the same as round 31's): Terminus s43/t1 +5.3 s, yard s42/t8 +6.0 s. Their traces
  are below.
- **Worst runs traced** (builder0 light, `b5882c9c`, both arms; `references/round32/traffic/t3bc_traces/`, read with
  `tests/traffic/squad_pace_table.py`). The traces reproduce the series rows exactly: Terminus 11.0 → 16.3 s, yard 8.1 → 14.1 s.
  - **Terminus s43/t1 (+5.3 s): the yielder simply waits, as in round 31.** All of squad B is held at the 0.40 floor from
    3–4 s to about 8 s, and released at full pace by 9–10 s. Then one extra event: B_5 k-turns at 12–14 s, is blocked by
    terrain for 2 s, and arrives at 17.6 s (base 11.0). Squad A is untouched (9.5 v 11.0 s). Arrivals: B_3 15.2 v 44.9 s
    (the base's B_3 yielded to B_4 and was blocked), B_4 31.1 v 24.1.
  - **Yard s42/t8 (+6.0 s):** squad B is held at the share 2–6 s, and its rear crew B_4 until about 9 s. Then a give-way
    inside the squad (B_2 yields to B_4, 9–11 s) holds B_4's arrival to 15.5 s (base 8.1) and B_2's to 18.6 s (10.9). B_1
    never arrives in either arm (the same k-turn and path block in base and arm), so it is not a wedge. Nothing is stuck.
- **MERGED (orchestrator): `b5882c9c` → main `86917d5a`**; the 13 baselines are being re-adopted. T1c-b2's check on
  `d1c375b3` was stopped (its base was stale; builder0 processes killed by cwd), and it is re-carried onto the
  post-adoption main so that its check reads only the pit moving.

**T1c-b2 on the post-adoption main: `traffic-t1cb2-r32` `cf81aedc`** = stream/traffic `fa088c38` (main `0e49fb3e` merged)
+ the rule + the `traffic-native-verify` fix.
- `traffic-native-verify` on `cf81aedc`: builder0 exited 0, 0 mismatches.
- **`make remote T=check` on `cf81aedc`:** builder0 `make check exited 2`, 2690 passed / 1 failed. **sim-baseline: all 13
  maps unmoved, the pit included** (the baseline runs never set a truck up beside a passer, so there is nothing to
  re-record). The one red is `test_native_traffic_turns_owned::test_the_crossing_on_the_owned_state` (twin 5147 drives,
  0 mismatches). It failed on 2 script errors, "'tank' … previously freed" at `planner_executor.gd:70` ← `planner_seam.gd`
  `Crew.copy` ← `capture` ← `tests/native/mover_state.gd:124`, and the exit-leak gate (20 ObjectDB) was red too. **Correction:** that leak was MINE (below), not the planner test's.
  **Diagnosis: latent on main, order-dependent, not the rule.** `PlannerSeam._crews` keeps a crew whose hull an earlier
  test's match freed, and `capture()` copies it. Adding `tests/test_traffic_setup.gd` shifted the rr shard plan.
  On the laptop the file passes alone and with `test_native_route|tick_profile` before it, on both `86590075` and
  `cf81aedc` (1/0 and 5/0). The fix is planner/native's (skip crews whose tank is not `is_instance_valid` in `capture`).
  Orchestrator: planner lands the fix alone on main first; then main merges into this branch and the check re-runs.
- **Census: VERDICT PASS against round 31's bar** (builder0, `cf81aedc`, GDScript `--brains-off=native` both arms, base
  `--traffic-off=setup`, seeds 41–46 × Sumps@1000 / Parade@2000 / Foundry@2000, n 18, 150 s, 0 missing;
  `references/round32/traffic/t1cb2_r32_census_{base,arm}_{cf81aedc.jsonl.gz,table_cf81aedc.txt}`).
  - **Deciding line: runs with a repack while firing 5/18 → 0/18** (one-sided Fisher p 0.023). Events 7 → 0. Repacks
    while giving way 50 → 42.
  - Friendly-stuck 789 → 696 crew-s (−93; limit +225): pass. Fast friendly contacts 934 → 946 (+12; limit +47.7): pass.
  - Reported: artillery shots 451 → 456. Under way 23155 → 22894 crew-s. Refusals on the post 0 → 59 (Green 52, Rust 7,
    so the rule is symmetric).
  - **The asker's side (orchestrator's addition a):** of the refused askers, 10 went round (Green 7, Rust 3) and
    6 never got past within 20 s (Green, all in the four runs where the base repacked: Foundry s45/s46 1 each, Parade
    s42/s43 2 each). Nothing was pending at the end. This is his yes as specified: the truck stays set up, so a squadmate
    behind it waits or goes round instead of moving it. Friendly-stuck time went down, not up.
  - **The six, traced** (builder0, `8ce39559` = `cf81aedc` + a measurement-only TRAFFIC_ASKER line; the four runs re-run
    reproduce the census, Foundry 15 refusals / 2 never-past, Parade 35 / 4;
    `references/round32/traffic/t1cb2_r32_askers_8ce39559.jsonl`). Each asker was watched from its refusal to the end:
    - got past late: Foundry s46 Battery_5 sat 26 s within 20 m of the set-up Battery_2 and got past 32 s after
      the refusal; Parade s43 Battery_2 sat 20 s behind Battery_1 and got past at 25 s.
    - settled short of its spot: Parade s43 Battery_3 sat 19 s behind Battery_4, then stopped 36 s on, 19 m short of
      its spot; Foundry s45 Battery_2 sat 20 s behind Battery_1 and stopped 26 s on, 10 m short.
    - ended by the fight: Parade s42 Battery_3 (12 s sat) and Hunters_1 (3.5 s sat; it had been re-ordered 78 m away)
      were freed when the set-up hull died.
    - **Worst, in player terms:** Parade s43, a mortar truck heading for its firing spot waited about 19 s behind a set-up
      squadmate, never got by, and set up 19 m short of where it was sent.
  - The red above stands until planner's fix is on main. Then main merges into `traffic-t1cb2-r32` and the check re-runs.
    That green hash is the ship hash.

**T4 stretch (the ORCA ghost ON): bar FILED** (workstreams *Bars (round 32)*, `8597a5fa`).
- Tree: `traffic-t4-on-r32` `0adc6deb` = main `2dce8a8c` + ghost out of OPT_IN (worktree `../godot-traffic-judge`).
- Arms: native path, base `--traffic-off=ghost`.
- Workload: nav-terminus-drive mixed + rigs, seeds 41–64 (n 24 a squad, paired), `pinned_table.py`, plus the four series
  cases (41–43 × 6 ticks).
- Conditions: it queues behind H1b, B10 and CP-Q on builder0, one remote run at a time. If H1b ships first, main merges
  into the T4 tree before the series.
- The ON gate `check NATIVE=off` is running.
- Manoeuvre's rig stall-clock answer (via the orchestrator): it is on main. `_honest_blocker` (movement.gd ~3198) reads
  `real_velocity` for a > 10 m hull pressed on a friend with no wall touched, on a routed move_to with unstickback ON.
  So round 31's rig 72 → 164 predates it, and line 2 tests it fresh.
- Script: `$S/t4_series.sh` (scratchpad).

- **After planner's fix (main `7a5cb5e5`, merged at `b99857bb`):** builder0 `make check exited 2`, tests 2708 / 0, all 13
  sim-baseline maps unmoved. The one red was the exit-leak gate: 20 ObjectDB / 4 resources. **The cause was my
  `tests/test_traffic_setup.gd`**: its teardown never disposed its TacticsLab (round 31's `test_traffic_ghost` bug). On the
  laptop the old file alone prints exactly those two lines at exit and the fixed one prints neither (5/0). Fixed at
  **`c9fa64a4`**.
- **🎯 T1c-b2 SHIP HASH `c9fa64a4`:** builder0 `make check exited 0`, 2708 passed / 0 failed, 24 targets passed. Two NOT
  JUDGED: perf-judge (box busy, ratios 1.67–2.21×) and scenario_perf (unpinned). sim-baseline: all 13 unmoved. Its first
  check on the same hash went red on native's `test_native_execute_odd`, which was order-dependent:
  `test_native_drive_owned` left a crew held in the planner seam. Native's test-only fix is on main at `45b52d04`.

**T4 stretch JUDGED: NOT SHIPPED** (builder0, `0adc6deb` = main `2dce8a8c` + the ghost ON, native path, base
`--traffic-off=ghost`; `references/round32/traffic/t4_r32/`).
- **ON gate (`check NATIVE=off`): no red from T4.** 2699 / 1. sim-baseline all 13 moved (expected), native-live-guard is
  structural under NATIVE=off, and `test_manoeuvre_behind::…war_rig_faces_behind_in_a_planned_turn` (drift 25.3 m) is
  identical with `--traffic-off=ghost` on the laptop (GDScript), so it is main's GDScript path (manoeuvre's).
- **Terminus drive, seeds 41–64, n 24 a squad paired, 48/48 runs:**
  - (1) **Deciding line FAILED:** mixed stuck 607 → 313 crew-s (−294, −48 %), se 211, needs beyond −347. The
    direction is right but not proven at n 24.
  - (2) Rigs stuck 627 → 459 (−168, se 185): pass. Manoeuvre's `_honest_blocker` is on main, so round 31's rig harm is
    gone.
  - (3) Pinned: mixed 316 → 17 crew-s (se 153), crews 5 → 1; rigs 0 → 0: pass.
  - (4) Arrivals: mixed 543 → 541 (limit −12.3), rigs 332 → 331 (−14.5): pass.
- **(5) Series (41–43 × 6 ticks, n 18 a case, 144 rows):** the crossings, Terminus head-on and every no-wedge/crews line
  pass. Terminus cross clock +0.31 s, yard +0.44 s. Same-squad fast contacts 139 → 116 and 149 → 120.
  **Yard head-on FAILED two guards:** between-squad fast 53 → 59 (limit +5.8) and all-in median 33.8 → 38.0 (+3.82).
  (`turns_verdict`'s pooled −25 % line is T3b-c's gain line, not T4's; not read.)
  - Traced from the rows: one pair (s43/t6, +27 s) is an extra arrival (A_5 never arrived in base). Over crews in both
    arms the last arrival is +3.6 s (se 2.3), carried by four pairs at +15–22 s (s41/t11, s42/t3, s41/t6, s42/t11).
  - In each of those, the late hull (Green_A_5 three times) reverses and circles round its slot: circle reverses
    20 → 47, 8 → 138, 15 → 112. There are more k-turns and one unstick fire, and friend-stuck is ≈ 0.
  - **Reading:** with the ghost on, the last hull into a packed head-on slot loops (reverse / circle) instead of
    settling. It is a slot-approach cost, not a wedge.
- **Next, if it is taken up:** trace one of those four (circle_reverse with the ghost's neighbour velocities) and
  re-judge mixed stuck at n ≈ 48 (−48 % at se 211/√2 ≈ 150 would decide).

**C32.8, test splits: none needed.** Builder0's shard times: no traffic-owned file is near 60 s.
`test_traffic_hold_live` 30.9 s, `test_traffic_turns_live` 31.0 s, `test_traffic_feed` 13.2 s. The slow files are native's
twins.

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
- **quick-remote on `b5882c9c`: GREEN** (builder0, 68 passed / 0 failed, `>> remote: make quick … exited 0`; it included
  test_native_traffic_turns(+_owned) and test_native_avoid_gather). Native's plain ON check on `pair/t3bc-r32` =
  `b5882c9c` is running (native names the hash). The re-judge chain is ready: base `--brains-off=native
  --traffic-off=turns`, arm `--brains-off=native`, both `TRAFFIC_WHICH=both`, with the hook lines (Terminus's xclear now
  `abs=1.0:allow=3.0`, his ~3 s), then `turns_verdict.py`. It runs on stream/traffic, whose game/ equals `b5882c9c`.
- **T1c-b2 carried:** `traffic-t1cb2-r32` `4849bfdc` = stream/traffic + `6d19a3d9` (one conflict, the end of
  `mk/traffic.mk`; `Movement.ask()`'s fire-post refusal applied clean). quick-remote GREEN (builder0, 42/0, exited 0).
  Native confirms none ported. `native-verify-scenarios` on `4849bfdc`: builder0 exited 0, 52 passed, 0 verify mismatches.
  **`traffic-native-verify` was broken since round 31:** the `;` in `TRAFFIC_VERIFY_CENSUS` reached the recipe's `for`
  list as a command separator (a bash syntax error at `parade`), which is why round 31 never ran it. Fixed at
  `d1c375b3`; re-run there: builder0 exited 0, 0 mismatches (census Sumps s7 and Parade s8, approach s13 and s14). Caveat: those census runs read `setup_refusals` 0, so the refusal itself is covered by native's structural reading (ask() is GDScript on both arms), not by these runs. The chain (worktree `../godot-traffic-t1cb2`) then runs the full check with the rule ON and
  the census on round 31's seeds 41–46 × Sumps 1000 / Parade 2000 / Foundry 2000, n 18, 150 s, `--brains-off=native`,
  base `--traffic-off=setup`. As the brief says, the deciding line is read as arm 0/18 repacks while firing (the base's
  ≥ 8/18 precondition is not re-applied), with the guards as filed.
- **CP-T gate PASSED (native):** `b5882c9c`, builder0 `make check exited 2`, 2671 passed / 0 failed, 25 targets passed
  and 1 FAILED = sim-baseline alone (all 13 maps moved), turns twins 0 mismatches. **The re-judge is running** from
  worktree `../godot-traffic-judge` at exactly `b5882c9c` (unit `traffic-rejudge-t3bc`, 01:56 PDT).

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
