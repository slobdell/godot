> **ARCHIVED (round 35 closed 2026-10-20).** The branch is `round35/brains`; its unmerged references (`references/round35/` or `_agents/streams/references/round35/`) stay on that branch. Round 36's brief is `streams/brains.md` where one exists.

# Stream: brains (squads on a route don't hang at each leg; the CPU's squad decisions)

> Read `_agents/orchestration.md` (the worker contract), `_agents/doctrine.md`, `_agents/workstreams.md` **Round 35** (C35.1, C35.7;
> R34.18, R34.19 in *Round 34*), and your round-34 brief `streams/archive/round34/brains.md` (its Status is the close-out).
> Evidence: `_agents/streams/references/round34/brains/`, manoeuvre's `references/round34/manoeuvre/cpf4-series/`.
> **You own:** `game/ai/**` EXCEPT traffic's, manoeuvre's, native's carve-outs, `game/tactics/**` EXCEPT orders' deploy-step and
> halt-lay functions in `element_plan.gd`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`,
> `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`.
> **The C++:** `decide`, `build_situation`, TacticalQuery and `_approach_gate` run in C++; every change there ships with native's mirror.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. His round-34 answers: the scout turn-in ships, the deploy
step is ON (orders owns it this round), a firing mortar truck keeps its spot.

What he will notice: squads on an attack-move or a route that move on to the next leg when they've arrived, instead of hanging
~30 s while one crew finishes turning to its arc.

## Where things stand

- **Shipped in round 34:** B1 scout try 2 (stand when it can win), B2's arrive-leg adapter (live with M2), B3, the Locks fixes, rank
  depth, ground_anchors, the stall fallback, gate order (with orders' code now owned by orders).
- **Parked:** B6 (early halt lay; superseded by the deploy step), B9 lane spread (R34.19: the mechanism works, the outcome doesn't
  follow), O2 (now orders' D3).
- **The sector-face step (R34.18):** attack-move elements step to the next leg ~30 s later when their arrived crews sit on a `face
  from sector` (tank_brain.gd ~2960's sector watch) instead of a stop; law/faced_attack_move-614 stepped at t 60 v t 32; 7 of 26
  pairs ≥ 10 s later.

## Backlog (in order)

1. **E1 The element step doesn't wait on a sector face (C35.7, your side).** Trace the hold in faced_attack_move-614 (which rule keeps
   `arrived` false or the step from firing), then agree the seam with manoeuvre through the orchestrator before code (their side: a
   face that gives up after N refused plans). Tests first; then CP-F 5's bar (manoeuvre files it).
2. **E2 B11b** (HOLD's return honours the post's facing for turret-mounted wheeled hulls) only if CP-F 5 ships.
3. **E3 The CPU commander and lanes, a second look (stretch).** B9's census showed stacking correlates with losing; the A/B showed
   spreading doesn't help. If you see a cause the census missed (the piecemeal arrival in locks-1404), write it up; no code without
   a bar.
5. **X4 (round-35 extension, 2026-10-20; workstreams.md *Round 35 extension*).** (a) The released straggler's catch-up (E1 (d):
   +3 crews still driving at 75 s): trace why a released crew is slow to rejoin, design a fix, file the bar before numbers.
   (b) After the joint W1c + T9 merges (the orchestrator says when), re-read Bar E1's left-behind crews on main (9 of 17 were still
   wedged): did the joint free them? Report only. Laptop and light lane first; series slots through the orchestrator (builder0
   after manoeuvre's probe A/B).
4. **Merge fallout:** the deploy step ON (orders' D1) reaches CPU elements; answer orders' questions about element internals.

## How to verify

Tests first; `make quick-remote`; one full check at a time on builder0; series pinned, fresh seeds, no random twins. Every number:
commit, machine, workload, n.

## Don't touch

Orders' paths (game/control, the deploy/halt functions), traffic's, manoeuvre's and native's paths, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### X4 (round-35 extension, 2026-10-20)

**X4a TRACED: the premise does not hold; no fix, no bar (none would move).** Read of Bar E1's series (`83b3b90b4`, builder0, native,
faced_attack_move + faced_move x 701-716 x 4 factions, n 64 a task an arm; laptop read, `tests/tactics/mover_kind.py`, filed
`references/round35/brains/x4a_mover_kind_83b3b90b4_builder0.txt`).
- **The released crews:** of the 6 releasing runs, 5 readable (law-701's hold ran to the judge). 3 rejoined: law-716 Guns_1 5.2 m off
  by t 24 (released t 22), condemned-701 Guns_7 3.9 m by t 74 (released t 56), condemned-710 Burners_2 32.8 -> 11.4 -> 3.4 m by t 44
  (released t 21). 2 never moved after the release: law-705 Eyes_3 (62.7 m off at the same spot (-2.8, 99.5) from t 17 to the
  judge; cmd throttle 0.13, real 0.00) and law-711 Guns_7 (51.6 m off at (9.1, 95.8) from t 48): wedged, the same crews in both arms.
  A slow catch-up is not in the data.
- **The +3 movers at 75 s (E1 (d)) are wedged hulls rocking, none a released crew:** the attack-move movers by their last 10 s:
  base closing 3 / jitter 4 / wander 3, new 3 / 7 / 3. The extra 3 are `jitter` (net <= 0.1 m in 10 s, real_mps 0.25-0.57 from
  rocking): law-705 Eyes_5 (a squadmate of the released crew, sent on to the next leg and wedged 14.5 m short at (30.6, 90.9);
  in base it waited at the gate, still), law-716 Guns_7 + Guns_8 (element id 3, which did NOT release: two tanks nose to tail in
  one choke at (7-10, 97-101); the run diverges from base at ~t 20 and in base Guns_7 got through). Counted by net motion (closing +
  wander), E1 (d) reads 6 v 6 on attack-move and 4 v 4 on faced_move.
- **Why no catch-up fix:** a released crew is the element's laggard, so `FormUp.paces` already gives it 1.0 (the candidate,
  `crew_paces` toward its slot, would change nothing), and the ones that do not rejoin are not driving. What is left is W1's (the
  wedged hull), with one observation for manoeuvre: law-716 Guns_7 pushes at cmd 0.83 for 50 s, plant v 9.98, real 0.32, and
  `_stuck_time` never reaches STUCK_SECONDS. ~~Because the stall test reads `estimated_velocity`~~ WRONG, corrected by manoeuvre's
  X1(d) trace (stream/manoeuvre `f89b7679b`, builder0 native, `references/round35/manoeuvre/x1d-trace/README.md`): the 7.3 m
  law_tank is wedged between friendly Hunters_2/6, so `_honest_blocker` holds and the test reads REAL velocity; the contact pops
  ~once a second (one tick at 8.5-9.9 m/s, net <= 0.1 m in 10 s), which zeroes the clock at 0.73-0.99 s for ~50 s. My 9.98 was
  MANOEUVRE_STATE's `moved` (estimated) column. Fix (reset on net motion) is manoeuvre's, round 36.
- **Measurement lesson for future bars:** a mover guard should count net motion (`mover_kind.py`'s closing + wander), not
  `real_mps` alone: a wedged hull rocking reads >= 0.3 m/s.

**X4a ACCEPTED, no fix (R35.67)**; the stuck test went to manoeuvre as X1(d); the net-motion mover rule was offered to native for the X5 scoreboard ("crews still moving"); native TAKES it (tools/scoreboard/, from f1e3e6a9b).

**X4b:** waiting on the joint W1c + T9 merge (the orchestrator says when).

### Report (round 35 FINAL, 2026-10-20)

**Brief complete.** Shipped to main: **E1** the straggler release (bbe418b80, R35.42), the per-tick release counter, **E4** lab hulls
placed with Tank.place (5f05c997c, R35.51), **E4b** the runner warm-up (25f8bc52f + bfe25438b; cause named by native, R35.57: the
engine's first main-loop iteration, so the warm-up matches real play). Written up, no code: **E3** (no lever, R35.46). Judged and
PARKED: **E2 B11b** (R35.63; FAILS (a)/(d)/(f): with M5 in the medians are ~4 deg in both arms; stays on stream/brains `4b6b3c589`
behind `--hold-return=turret`, NOT merged, no check by the orchestrator's call). **D1 fallout** done (test_tactics_body native 24.0
v 17.8 s, inside R35.17's line).
**Green:** main carries all brains code that ships; the last green check of a brains tree is `05ba49192` (builder2, 2953/0; E2 ON),
and `4a6394932` (builder2, 2911/0) before it. The tip `4b6b3c589` is parked code with main's behaviour by default, unchecked by design.
**Questions for the lead:** none. **Requests:** see round-36 candidates (wedged crews, test teleports, the copy-back leak).

### E2 B11b (unblocked by M5, R35.61; 2026-10-20)

**Code (`--hold-return`, GDScript only, no native twin):** `TankBrain.hold_return_faces(unit_id)`: HOLD's return carries his drawn
facing for `Units` locomotion "wheels" + mount "turret" only (law_tank, gang_tank/the War Rig, ifv, gang_ifv, artillery, lancer,
burner, suppressor...); `--hold-return=old` = no faced return (control), `--hold-return=faced` = every class (round 32's B11).
`test_ai_hold_return` 2/0 (laptop). Judged on a tree WITH M5 (main ed121d24f), so the series waits for the merge.

**Bar E2 (filed 2026-10-20 before any number; C33.3's lines).** One commit containing M5, builder2 (R35.61's lane), native, both
arms the same tree (base `--hold-return=old`). Workload: `manoeuvre-hull-rest` drawn, all six faced tasks, FRESH seeds 801-816 x
gangs/law/syndicate/condemned (384 runs an arm); fights: `manoeuvre-fights` fresh seeds 820-843 (24 an arm). Readers:
`tests/manoeuvre/hull_rest_ab.py` (per class x task medians, permutation p), `tests/tactics/hold_return_table.py`.
- (a) DECIDING: wheels/turret hull error at the judge on faced_move AND faced_right: new median < base, permutation p < 0.05 each.
- (b) The pass case: gangs faced_move seed 66 Green_Guns_5 (hull-one, drawn, native) <= 90 deg from his heading (was 104-126 deg
  under B11 without a face at rest); reported both arms.
- (c) GUARD: no hull class worse at p < 0.05 on any task (wheels/fixed, tracks, hover must read identical or within noise: the
  rule does not reach them by construction).
- (d) GUARD: never settled in 75 s and movers at the judge (real_mps >= 0.3), new - base <= 2 se on each task.
- (e) GUARD: squads arrived, base - new <= 2 se.
- (f) GUARD: fights kills and deaths each side within 2 se (paired).
- (g) `make check` green on the hash; moved sim-baseline maps attributed with `--hold-return=old`.

**E2 JUDGED (2026-10-20): FAILS (a), (d), (f) -> PARKED, OFF** (`--hold-return=turret` opts in). Series on `05ba49192` (E2 + main
c474fd455 with M5), builder2, native, base `--hold-return=old`; `references/round35/brains/e2_bar_series_05ba49192_builder2.txt`.
(0) faced returns 2341 v 0 PASS; **(a) wheels/turret medians ~4 deg in BOTH arms** (faced_move 4.2 v 4.1, p 0.949; faced_right
4.5 v 4.5, p 0.957) FAIL: M5 already ends these hulls facing his way, and the faced return trims only the tail (p90 85.3 -> 62.6,
90.8 -> 64.5 deg; >= 100 deg 6 -> 5 %, 9 -> 5 %); (b) s66 Green_Guns_5 6.8 deg BOTH arms (M5's, not B11b's); (c) no class differs
at p < 0.05 PASS; **(d) movers at the judge faced_move 30 v 12 (+18, 2.8 se), faced_right 22 v 9 (+13, 2.0 se) FAIL** (the hulls
that drive back onto their spot are still turning at 75 s); settled and arrived within se; **(f) fights kills 934 v 972 and deaths
944 v 982 (-38 each, se 18.0) FAIL** (fewer of both: hit rate equal). Per R33.34 a further attempt needs a new design (e.g. a faced
return only past the tail angle), not a re-tune. Note: the copy-back again carried older series' runs (6xx/7xx; old fights) into
the series folder; read from filtered copies.

### Round-36 candidates (brains' view, 2026-10-20)

1. **The wedged crew itself** (manoeuvre W1 / traffic): E1 stops the squad waiting, but 9 of the 17 crews left > 25 m behind in
   Bar E1's new arm were still wedged at the judge (law-605 Eyes_4, law-607 Guns_6, gangs-602 Hunters_3 traced). He still sees a
   crew sitting idle behind its squad.
2. **A released straggler's catch-up** (brains): Bar E1 (d) read +3 crews still driving at 75 s (law-705, law-716): the crew sent
   on to its next slot takes its time. Candidate: a released crew gets the element's catch-up pace (`crew_paces`) toward its slot,
   judged on movers-at-75 s and left-behind, guards as Bar E1.
3. ~~The runner teardown's field~~ NAMED by native: the engine's first main-loop iteration, not the teardown; the warm-up matches
   real play and can stay (optional: pin which engine state, e.g. the physics space's first step, if anyone needs it).
4. **85 test files teleport by a bare `global_position =`** (list in E4 above): each owner moves to `Tank.place` (most are
   harmless singles; the ones spawning touching hulls carry the same stale-body shove).
5. **An arrived squad's herringbone across another squad's street** (orders, R35.17's resize of test_tactics_body to off + 8.1 s):
   a jam he would see; native 24.0 v 17.8 s on c7c7d347a.
6. **E2 B11b** PARKED with M5 in (medians already ~4 deg); only a tail-only design is left, and it costs movers and fights.
8. **Tooling: stale `build/` rows leak into series folders** (R35.63; FIXED by native on stream/native `1d8dd7648`, not merged yet: `tools/copyback_prune.sh` moves orphaned run.logs to `build/.stale-<ts>/`, nothing deleted): a series copied from `build/manoeuvre/hull-rest/<arm>`
   and `build/manoeuvre/fights` carried older series' runs (E1's 6xx/7xx, old fight seeds) because the copy-back mirrors the remote
   `build/`, which keeps every earlier run's folders; three of my reads had to be filtered by seed. Fix candidates: the recipes write
   under a per-run dir (commit + seeds), or `manoeuvre-hull-rest` / `manoeuvre-fights` clear their whole output dir, not only the arm.
7. Hygiene, low: `Element._body_memo` is keyed by `Engine.get_physics_frames()` (process-wide), not by match; ruled out as
   E4b's cause, but a match-scoped key is the right shape.

### Report (2026-10-19 evening)

**E1 PASSES its bar (R35.42); merges when the partial gate is green.** Merge hash: `83b3b90b4` (E1 code `67a5a9db0` + main
`fc1f4ac0e`'s N3 tooling), gate = the timed-out re-check's 16 finished targets (test 2890/0, sim-baseline 13/13 unmoved at main's
lines, determinism 8c3c1232b711a760) + the partial `lint` + the 10 unfinished targets (R35.22; RUNNING on builder0 behind
`builder_checks.sh --wait-below 1`, log `~/overnight-brains/e1_rest_83b3b90b4.log`).
- **What he will notice:** a squad on an attack-move whose one crew is wedged takes the next leg after ~8 s instead of hanging
  up to a minute or more; the wedged crew catches up if it can (if it can't, that is manoeuvre's W1 / traffic's, not this).
- **Bar E1 series** (`83b3b90b4`, builder0, native, base `--straggler=off` on the same tree; seeds 701-716 x 4 factions, n 64
  attack-move pairs; fights 720-743, n 24; `references/round35/brains/e1_bar_series_83b3b90b4_builder0.txt`):
  (0) releases 6 v 0 (inferred: a wait >= 8 s ending with the crew < 2 m nearer over its last 8 s; 0 false positives on the
  c23acdbe2 census); (a) long-hold s 89 v 358 (0.25x; paired -269, se 116.4, 2.3 se) PASS, a TAIL effect: all of it in the 6
  releasing runs (law-705 -73, law-716 -68, condemned-701 -44, law-711 -40, law-701 -25, condemned-710 -19), the other 58
  identical; (b) faced_move VACUOUS (a plain move plans in `_plan_form_up`, never `_advance`); (c) left > 25 m 17 v 20 (se 2.2),
  wedged among them 9 v 10; (d) movers at 75 s 13 v 10 (+3, limit 4.4: released crews still driving), settled 35 v 34;
  (e) squads arrived 194 v 190; (f) fights kills 970 v 970, deaths 984 v 984, hit rate 0.718 both (3 CPU releases in 24 fights).
  (g) sim-baseline: no map moves either way (`--straggler=off` sim-variants on `83b3b90b4` = the baseline 13/13).
- **Decisions:** the hold R34.18 blamed on the sector face is `_advance`'s cohesion gate waiting on a laggard (face 0-0.5 % of
  wait seconds; wedged crews 44-61 %); the seam with manoeuvre is decoupled (R35.3), face_settled() stays out. STRAGGLER_S 8 s /
  STRAGGLER_GAIN_M 2 m sized on the census (no re-tune after the series).
- **Infra found:** the stale native library via an mtime race (R35.15 -> native's N3); a partial check needs `lint` in
  CHECK_TARGETS (every target is ordered after it); a hull-rest copy-back carries an earlier series' arm folders (read by seed).
- **E3 (stretch) written up, NO code (no lever found).** A cause the B9 census missed, traced in locks-1404 (laptop, lane spread
  green, 24 v 4): at t 24.5 Green takes the far quay, `Posture.decide` flips to HOLD ('ahead on points') and the commander re-posts
  ALL four elements to the quay, the two central ones in contact driving ~60 m across the enemy's front (Hunters gone by t 40).
  Census (`74526bca1`, laptop, GDScript, lane_census showmatch locks/terminus/crossing x 1400-1409, n 30;
  `references/round35/brains/e3_posture_flip_census_74526bca1_laptop.txt`, `tests/tactics/posture_flip_table.py`): 56 flips to
  hold (35 'ahead on points', 21 'zone threatened'); engaged elements RE-POSTED > 40 m lost 15 / 30 / 25 % of their crews in the
  next 30 s (crossing / locks / terminus) v engaged elements KEPT 19 / 40 / 33 %. These are SELECTED groups: no sign the re-post
  is worse, nothing more (a cost is attributed only by removing it, R35.46), so locks-1404 is one fight's shape, not a pattern; like B9 (R34.19) the stacked/piecemeal look follows
  the fight, it does not cause it. A bar draft is not proposed: the census gives no sign it would pass. If anyone wants the A/B
  anyway: "engaged elements keep their task through a flip to hold for N s" v main, deciding on fight E (R34.19's scale),
  guards deaths/kills/contact spread; `POSTURE_ENABLED` is the existing switch.
- **E4 (R35.46, trace only) NAMED: a test harness that teleports a hull with a bare `global_position =` leaves its physics
  body at its spawn SLOT until the first step, and how that transient overlap resolves depends on process history.** Probe
  (`references/round35/brains/e4_probe_test.gd.txt`; laptop, GDScript, `3014d6cb9`'s tree): the four-tank Sumps stage
  (`mixed_legs_case`, seed 1) played twice in one process: first 50.0 s, reseats 1; second 55.9 s, reseats 0 (manoeuvre's
  "alone v after another test", R35.39). They diverge at step 0: in the SECOND match only, the outer tanks M_1/M_4 are pushed
  0.31 m inward (x +-12.0 -> +-11.686) before anything moves. Before `lab.start` every body still sits at its
  `Match.spawn_position` slot (server x 0 / -15 / 15 / -30 v nodes -12 / -4 / 4 / 12) in BOTH matches; M_2's stale body at -15
  overlaps M_1 (and M_3's M_4); the first match syncs without a push, a later one resolves the overlap as penetration. What
  inside Jolt carries between matches is not named (body ids / contact cache / broadphase are candidates); it does not need
  to be: the stale overlap is ours. `TacticsLab.unit`/`.gun` write `global_position` directly; the game's own `Tank.place`
  (writes the node, flushes the server, resets interpolation, `sync_position`; army_layout learned this in round 14) does not
  leave the stale body. **With `Tank.place` in the probe: both matches 50.0 s, reseats 1, poses AND `Match.state_hash` identical
  at all 1800 steps.** (`PhysicsServer3D.body_set_state` alone did not take; a remove/re-add equalled the poses only.)
  **WRITTEN (R35.47 approved; bar on main + any line moving to other than its first-match value is traced): `78f60777a`**,
  `test_tactics_lab_place` red before (first difference at step 0), green after; laptop GDScript: mixed_legs + body 8/0, four tanks
  50.0 s reseats 1 run AFTER other tests (the first-match value). Builder0 check pending (after the batch main). **Proposed fix:** `TacticsLab.unit` and `.gun` and `BodyStage`'s spawn (`body_stage.gd:152`)
  call `tank.place(position, yaw)`. `AiScenario.brain_tank` already does. **Bar draft:** builder0 native, (1) the suite green;
  (2) order-independence: `test_tactics_mixed_legs` alone v after `test_planner_h1b_guard` / `test_nav_blocker_reach` in one
  process reads the SAME arrival and reseats (today 50.6 s v 31.9 m short on joint-on); (3) every test line the change moves is
  listed with its old and new value (expected: lines that today read their 'later match' value move to the 'first match'
  value; none of them is a game change). 85 other test files spawn then assign `global_position` (fx, combat, nav, native
  ...): not mine, for their owners: test_units_roster.gd test_combat_deploy.gd test_nav_tube.gd test_fx_orders.gd test_control_point.gd test_visibility.gd test_nav_route_retry.gd test_combat_mechanics.gd test_command_readability.gd test_native_incoming.gd test_weapons_and_intel.gd test_match_score.gd test_native_combat.gd test_nav_gate_inside.gd test_tank_yaw_fit.gd test_hud_score_bug.gd test_native_perception.gd test_native_shell.gd test_movement.gd test_order_completion_repair.gd test_assets_outriggers.gd test_arena_layouts.gd test_native_threat.gd test_nav_gate_v4.gd test_nav_gate_hold.gd test_native_scan.gd test_combat_weapons.gd test_native_movement_geometry.gd test_responsiveness.gd test_manoeuvre_escape.gd test_fx_light_rounds.gd test_artillery.gd test_navigation.gd test_station_keeping.gd test_nav_arrival_heading.gd test_native_tick_profile.gd test_nav_wall_contact.gd test_ai_player_orders_contact.gd test_radar.gd test_ammo_heat.gd test_fx_tank_shell.gd test_units_law_apc_tracked.gd test_shields.gd test_combat_locomotion.gd test_ai_player_holds.gd test_combat_cover.gd test_command_squad_bar.gd test_wheeled_arrival.gd test_ai_perf_equivalence.gd test_reflexes.gd test_combat_events.gd test_combat_weak_spots.gd test_turrets.gd test_friendly_fire.gd test_planner_trace_wedged.gd test_tank_place.gd test_ai_cover_map.gd test_native_avoid_gather.gd test_native_record.gd test_nav_face_recovery.gd test_ai_idle_fallback.gd test_control_response.gd test_combat_envelope.gd test_nav_clearance.gd test_combat.gd test_match_visfield_parity.gd native/gate_twin_case.gd test_native_route.gd native/drive_twin_case.gd scale/visfield_bench.gd arena/slope_probe.gd nav/test_nav_back_and_fill.gd nav/test_nav_yield_log.gd nav/rotation_capture.gd nav/test_nav_blocker_reach.gd nav/test_nav_guard_corner.gd nav/test_nav_yield_fit.gd nav/test_nav_kturn_brake.gd nav/test_nav_reverse_log.gd nav/test_nav_queue_census.gd nav/test_nav_creep_bound.gd nav/test_nav_planned_reverse.gd nav/test_nav_circle_fit.gd nav/test_nav_kturn_look.gd arena/water_probe.gd.
- **E4 MERGED (main 5f05c997c, R35.51)** at `85fa139cf`: check `exited 0`, 2909/0, sim-baseline 13/13 unmoved; order-independence
  (builder0 native, TEST_SHARDS=1): mixed_legs four tanks 50.03 s / reseats 1 alone AND after h1b_guard + blocker_reach (main's
  suite read 56.63 s / 0). Bar (3) table `references/round35/brains/e4_moved_lines_85fa139cf.txt`: 34 moved keys, 33 read the same
  in the tip suite as each file alone (planner_queue differs only in a process-wide tick stamp; task_posture is a reader artifact).
- **E4b (the one outlier, a SECOND carry-over; trace, time-boxed, not named to the field):** test_tactics_scenarios_6
  attack_move_decisions reads switches_per_unit_min 3.2 alone v 4.8 after ANY earlier test in the process (builder0 native;
  laptop GDScript 4.8 alone v 3.0 after). Bisect (light lane): the first file of the shard already moves it; a test that only
  waits 1, 97 or 1000 physics frames moves it the same (so not frame phase); the stage played twice inside ONE test is identical
  (GDScript and native), and the navmesh path / map iteration it starts from are identical. Per-tick dump (laptop,
  `references/round35/brains/e4b_first_divergence_laptop.txt`, probe `e4b_dump_probe.gd.txt`): identical through step 28; at step
  29 Rust_B_2 begins YIELDING to Rust_B_1 (its column leader) only when a test ran before. So the yield path reads some state that
  differs between a process's first test and every later one, and settles after the first test's teardown (the runner's
  `drain_navigation` or a lazily initialised static are the leading candidates; Element._body_memo keyed by match was tried and
  ruled out). **Proposed fix (not written; bar first):** `tests/run_tests.gd` warms up before the first test (one physics frame +
  the same teardown every test gets), so every test sees the 'later' state: the 1-frame test above IS that warm-up and gives the
  suite value. Bar: scenarios_6 alone == in the suite; the full suite green with every moved line listed (expected: lines that
  ran first in a shard move to their suite value). **WRITTEN (R35.54; the correct fix per R35.57, not interim): `0daea3d90`** (laptop
  GDScript: scenarios_6 alone 3.0 = after 3.0; was 4.8 v 3.0). **CORRECTED by native's trace (2026-10-20, laptop, main
  5f05c997c):** it is NOT the teardown and NOT drain_navigation (an earlier test that steps no frame keeps the alone value, with or
  without the drain), NOT a script static (all 815 `static var`s identical), NOT frame phase (1-4 and 97 frames all give the
  'later' value), NOT the nav map's first sync. ONE main-loop iteration before a test's setup flips it: engine-side state set by
  the first iteration (most likely the physics space's first step). Real play starts every match long after launch, so it matches
  the 'later' value: **the warm-up makes the tests match real play** (my earlier 'real play matches the first test' was wrong;
  the stage-twice-in-one-test reading never separated the teardown from the frame). One frame is the whole fix; the teardown in
  the warm-up is incidental.
- **D1 fallout DONE:** test_tactics_body on `c7c7d347a` (main f31b5430e = D1 + E1 + T7 merged; builder0 light lane, native ON):
  PASS, body off arrived 17.8 s, on 24.0 s (+6.2, inside R35.17's +8.1; D1 alone read 23.8). E1 merged on main (bbe418b80, R35.42).
- **E2:** waits on CP-F 5 (manoeuvre's W2 ships on its own bar). (Old note:) re-read
  `test_tactics_body`'s arrival after merging main (the deploy step + the release; orders' resize to off + 8.1 s, R35.17).
- **Requests to other streams:** native: hash-stamp native/src in build.sh (done, N3). manoeuvre: the wedged crews
  (law-605 Eyes_4, law-607 Guns_6, gangs-602 Hunters_3; law/faced_attack_move-614 G4 on lab/cpf4).
- **Questions for the lead:** none.
- **Playtest:** `make skirmish ARENA=foundry`, attack-move (A) a squad across the map; a squad whose crew snags moves on.
  The old behaviour: `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish --arena=foundry --straggler=off`.
- **Next:** a real per-tick release counter in ELEMENT_TRACE (cheap; the orchestrator asked) after the merge; then E3.

**Start (2026-10-19 08:40 PDT):** worktree `godot-brains` on `stream/brains` at `a0ae0aafd`; launch baseline is main's inherited
green (HANDOFF), no baseline check run.

**Plan (in order):**
1. E1 trace: reproduce law/faced_attack_move-614 on `lab/cpf4` `e76f6dab6` (the tree R34.18 traced) and on today's main, with a
   measurement-only leg-gate trace (`ElementPlan._advance`: `reached`, `_cohesive`, which crew fails it by how much), then the
   26-pair attack-move set on builder0 to see whether the hold still exists on main. Reason: the seam with manoeuvre must name
   the rule that actually holds, not the one the README guessed.
2. E1 seam note to the orchestrator; tests first; code only after the seam is agreed.
3. E2 only if CP-F 5 ships. 4. E3 write-up (no code without a bar). 5. Merge fallout from orders' D1.

**E1 trace (R35.3, agreed: the seam is decoupled).** law/faced_attack_move-614 on `lab/cpf4` `e76f6dab6`, laptop, GDScript, both
arms, leg-gate trace `c23acdbe2`: the leg is held by `ElementPlan._advance`'s `_cohesive`, never by a face. `reached` is true at
every hold; `_cohesive` fails on one crew over its allowance (20 m x 1.0 / 12 m/s = 1.33 s, ~16 m); each step fires the moment
the laggard gets inside. The crew on `face from sector` stood 3-4 m from its slot (closed up). Base arm: element 3 waits t 37 to
past 75 on Green_Guns_4 WEDGED at (18, 87.5) (plant 9.25 m/s, real 1.17, 30 m off, re-seat budget spent). The 128-run census
(builder0, seeds 601-616 x 4 factions x CP-F on/off, n 64 an arm, `leg_wait_table.py`; filed
`references/round35/brains/e1_leg_wait_census_c23acdbe2_builder0.txt`): wait seconds CP-F on 428 (closing 228, wedged 189, face 2,
stop 9), off 516 (closing 252, wedged 255, face 0, parked 1, stop 8); long holds 7 / 191 s v 11 / 329 s, nearly all waiting on a
WEDGED crew (a move held, < 0.5 m/s real, 20-50 m off its slot). Face is 0-0.5 %: face_settled() stays out (orchestrator,
recorded). The wedged crews themselves (law-605 Eyes_4, law-607 Guns_6, gangs-602 Hunters_3) went to manoeuvre's W1.

**E1 design: the straggler release.** `_advance`'s gate stops waiting for a crew that has not come STRAGGLER_GAIN_M (2 m) closer
to its slot in STRAGGLER_S (8 s) while the element stands at its anchor: closed-up is judged over the others, the element steps,
and the straggler is sent to its slot on the next leg (it catches up; a wedged crew gets a new goal, which is also its best
chance to come unstuck). Both sides (symmetric AI). `--straggler=off` is main's gate (the base arm and the attribution).

**Bar E1 (filed 2026-10-19 before any number).** One commit, builder0, native, both arms the same tree (base `--straggler=off`).
Workload: hull-rest drawn, `faced_attack_move` + `faced_move`, FRESH seeds 701-716 x gangs/law/syndicate/condemned (128 runs an
arm), `--element-trace=all --turn-states`; fights: `manoeuvre-fights`' census on fresh seeds 720-743 (24 an arm). Paired by seed;
se of the paired sum.
- (0) FIRST (R35.5's rule): straggler releases > 0 in the new arm (LEG_GATE `released`), else the A/B is vacuous.
- (a) DECIDING: long-hold seconds (leg waits >= 10 s, `leg_wait_table.py`) summed over attack-move runs: new <= 0.6 x base AND the
  paired difference < 0 by > 2 se.
- (b) the same on faced_move: not worse by > 2 se (report the size).
- (c) GUARD, left behind: crews > 25 m off their slot in their element's last trace row before the judge, new - base <= max(2, 2 se)
  on each task; reported split by whether the left crew is wedged at that row (R35.3: a wedged crew left behind is the same crew
  in both arms, manoeuvre's/traffic's to fix, not caused by the release).
- (d) GUARD, late movers at 75 s: crews with real_mps >= 0.3 at the judge, new - base <= 2 se on each task; settled-in-75 s counts
  the same.
- (e) GUARD, squads arrived (judge rows): base - new <= 2 se.
- (f) GUARD, fights: kills and deaths each side within 2 se (paired).
- (g) `make check` green on the hash; sim-baseline maps that move are attributed with `--straggler=off` on the same tree.

**E1 progress.** Code `ec1f5cc75` (+ `67a5a9db0`: the switch read at load). `test_tactics_straggler` 5/0 (laptop, GDScript).
quick-remote of `7b85b470a` (builder0, QUICK_BASE a0ae0aafd, 107 tests): 105/2. The two reds are main's new scout turn-in tests
(`test_manoeuvre_orbit::…at_stop…`, `test_native_execute_turn_in::…`), single-scout stages with no element. Read as the folder's
STALE native library (quick builds none; the last native build there was my census at `c23acdbe2`, before the turn-in's C++
landed): "210 mismatches".
Full check of `67a5a9db0` (builder0): `make check exited 2`, 2888/2, 23/26 targets passed; the same two turn-in reds, plus sim-baseline
MOVED terminus/parade/gorge/docks. **VOID: a stale native library.** My census (`c23acdbe2`) synced the pre-merge tree at ~09:00,
waited for a slot and built native at 09:23 from pre-merge C++; the main merge (09:22:13 locally, native/src +19/-5) reached builder0
with mtime 09:22 (rsync keeps it), older than the objects, so cmake rebuilt nothing. Proof (builder0, `native test FILTER=
test_native_execute_turn_in|test_manoeuvre_orbit`): clean `0f4d528d7` 8/0; my tree after `touch native/src/*` 8/0, the same
numbers (c339_stop on 0, 147 turned in). Parade and docks had gone back to their pre-turn-in lines. A fresh check is asked for
(slot after orders' D1, traffic's T7 and manoeuvre's M5); the lesson goes to native via the orchestrator (stamp native/src's
hash, not mtimes).
