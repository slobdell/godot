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

**ROUND 34: OPEN ITEMS (traffic's own words, written at round 33's close).** Ranked by what I'd take next.
1. **The parked blocker, the far loop's biggest source: parkedroom (v4), if the lead still wants it.** What works: the room
   rule really clears hold-post loops (v2 39 -> 1, v3 59 -> 18 loops behind a hold-post blocker; all far loops 411 -> 201).
   What blocked it: two guards. (a) The return: v3 got 89.96 % home against a 90 % line. 19 of the 45 misses were still owed the
   way back at the read because the asker was still driving, so a 30 s read is early for a long hull through a neck.
   (b) The fights guard: kills fell 3.9 % on random maps. The one fight traced (random-859) shows a rout that didn't happen
   (`ov_parkedroom_v3_l3_trace.md`), not hits that stopped killing. Next: a census of who dies stuck or jammed across the
   48 random fights (`far_census --far-kills=on` exists), and the lead's call on whether "fewer one-sided routs" is
   wanted, BEFORE a v4 bar. Needs: a fresh bar, fresh fights, and a pair on CURRENT main with native's hand-back
   (`ae8d6e858` Drive::ask hand-back, `f16f49867` exec_fields, `a7999c5c4` execute hand-back, `5e5465af8` its twin;
   today they sit on an older main). v3's code is on this branch, DEFAULT_OFF.
2. **T4 (the ghost) is parked on G2** (4 of 12 seeds where body-cohesion alone_s rises > 3 s; `ov_t4_bar.md`). It's blocked
   on the ghost changing which body route the Sirens' crews take in a third of seeds, plus native's coverage floors
   starving under the ghost (R33.29: native's ghost-aware twins, `b2b97188d`, not merged). It needs a per-seed trace of
   the four losing seeds (7, 8, 9, 14) before any fourth try.
3. **Same-process rematch replay (UNOWNED, match/physics):** a rematch in one process branches at tick 1 on hull
   height, with the ghost on or off. A fresh process replays exactly. Every A/B here uses fresh processes, so nothing
   of traffic's waits on it, but anything that rematches in-process (a lobby rematch?) will not replay.
4. **Fire-post loops that remain are engaged batteries** (item 4 shipped: idle ones 20 -> 0). The engaged ones are the
   lead's T1c-b2 yes. Whether a battery firing at a target should still give way to its own column is a design
   question for the lead, not a bug.
Tooling ready for round 34: `far_ab.py --v2/--v3`, `item4_lines.py`, `v2_lines.py`, `far_census --far-kills=on`,
`make traffic-t4-guard` / `traffic-t4-drive`. Raw logs of every judged run tonight: see the close-out note below.

**ROUND 33 CLOSE-OUT (2026-10-18):** item 4 SHIPPED (main `8684a97bb`). parkedroom v2 and v3 PARKED (R33.37). T4
PARKED (R33.30). No v4 this round. The raw per-fight logs behind tonight's verdicts are bundled outside the repo (2.8 MB:
the session scratchpad's `r33_traffic_overnight_runs.tar.gz`: v2n, v3, item4, item4b, k859, traces, checks). The
committed `ov_*` files carry every number and the series' summary output.

**OVERNIGHT (2026-10-18), branch `stream/traffic-overnight` (= `6be563e3` + main `e46f1720`, `dc208a19`):**
- **STANDING BY (R33.37).** parkedroom **v2 and v3 are PARKED** as filed (no re-read of L6). parkedroom stays
  DEFAULT_OFF. **No v4 this round:** a v4 needs a fresh bar AND a pair on current main with native's hand-back
  commits (`5e5465af8` line; `ae8d6e858`, `f16f49867`, `a7999c5c4`, ...). The pairs judged so far sit on an older main.
  - **L3's kill drop, traced** (dev read, builder0, `ef7f7901f`, random-859 both arms, n 1;
    `ov_parkedroom_v3_l3_trace.md`): room give-ways from 13 s branch the fight. The base's rout of Rust's artillery
    park (14 lost, caught driving or stuck) never happens in the arm (3 lost). Rust's losses went 44 -> 20 and
    Green's 11 -> 15. Fewer kills because one side lost less, not because hits stopped killing.
  - Item 4 shipped (main `8684a97bb`; main `d7d57f4cf` green 2797 / 0 on builder2 per the orchestrator).
- **v3 JUDGED (2026-10-18): FAIL on L3 and L6; parkedroom stays DEFAULT_OFF.** Pair `pair/parkedroom-on-v3`
  `6d0e00652`, builder2, native, fresh 820-867 x 3, n 144. L1a 59 -> 18, L1b 224 -> 63, L2 411 -> 201, L4 identical,
  L5 0 / 9: all PASS. **L3 FAIL:** kills 2072 -> 1992 and deaths 2090 -> 2008 (random n 48), with shots -0.6 % and an
  equal hit rate (not traced yet; read random-859 first). **L6 FAIL:** 403 / 448 = 89.96 % (line 90 %). Write-up:
  `ov_parkedroom_v2_bar.md` "v3 result". A hand-over would also need a pair on current main (`d7d57f4cf`) with native's
  hand-back commits.
- **R33.36 (the orchestrator's amendments, filed before numbers).**
  - **Item 4 RE-JUDGE PASS** (`23251f069`, fresh 796-819 x 3, n 72): idle fire-post loops 20 -> **0**; all fire-post
    loops 68 -> 11; guards pass; lines 1, 3, 4, 6 stand. **Hand-over: `pair/firemission-on-n` `23251f069`** (main
    `68a91f9d6` + item 4 ON + native's mirror + test fix; C31.1 2782 / 0 builder2). `ov_item4_bar.md` re-judge result.
  - **Item 4 MERGED** by the orchestrator: main `8684a97bb` (the `23251f069` hand-over).
  - **v3 BUILT** (`e675054b7` + `0f25b15b0`, DEFAULT_OFF): a hold-order crew owes its way back to its hold point
    (`_room_home`), and the way back ends once the crew is within HOLD_TOLERANCE - 0.5 m of the goal (`_room_home_inside`;
    the first v3 trace dithered 2-3 m off for 13 s, still giving way). No new Movement member (native agreed v3 needs no
    C++). +1 neck test, laptop GDScript traffic|movement|nav_yield 74 / 0. Pair `pair/parkedroom-on-v3` `6d0e00652`.
    C31.1 (builder2, `make native check`): **2784 / 0**; sim-baseline MOVED on terminus, sumps, parade, docks (the ON
    arm). Pre-series trace PASS (s703: the way back ends 2.4 m off the hold goal at 23.5 s; `ov_parkedroom_v2n_trace.md`).
    **The series is RUNNING on builder2** (fresh 820-867 x 3, `far_ab --v3`, then L4 / L5; `v3_series.sh` in the
    session scratchpad). The L3
    reading (hit rate one-sided, kills and deaths two-sided) is agreed with the orchestrator.
- **RESULTS (2026-10-18, builder2, native, fresh fights): BOTH FAIL AS FILED; both stay DEFAULT_OFF.**
  - **v2** (`e7b202760`, 724-771 x 3, n 144): L1a hold-post loops 39 -> **1** PASS, L1b PASS, L2 PASS; **L3 FAIL** (hit
    rate 0.714 -> 0.731, out on the good side); **L6 FAIL** (63 % of 395 within 3 m; line 90 %). Traced: 99 of the 147
    misses sit inside their hold line around the ORDER GOAL (the parked spot was 3.1 m off it); only 48 (12 %) are off
    station by both readings. A v3 would return to the hold point (orchestrator's call). `ov_parkedroom_v2_bar.md` Result.
  - **item 4** (`23251f069`, 772-795 x 3, n 72): line 1 NOT ARISEN (705 has 0 in both arms); **line 2 FAIL** (fire-post
    loops 34 -> 29, se 14.4); lines 3-6 PASS. Traced: every remaining arm fire-post loop is ENGAGED (kept by design);
    idle fire-post loops 10 -> **0**. `ov_item4_bar.md` Result.
- **(1) parkedroom v2: native's hand-back is GREEN** (native: `pair/native-parkedroom` `5e5465af8` on my `5259fb463`;
  Drive::ask hands an AT-post ask to Movement.ask, and a crew owed a way back is executed by the GDScript. builder2
  88/0, perf 1.00x per native). New pair `pair/parkedroom-on-v2n` = `5e5465af8` (worktree in the session scratchpad).
  Its C31.1 (builder2, `make native check`): tests **2783 / 0**, perf-judge 1.00x, lint clean; sim-baseline MOVED on
  terminus, sumps and parade (the ON arm's own change; the baselines are not mine). Every known red of `5259fb463` is
  green. Tooling on the pair `e7b202760` (game code = `5e5465af8`). Pre-series trace PASS
  (`ov_parkedroom_v2n_trace.md`, terminus s703, builder0, n 1: room, way back, a second room, back within 2.3 m). Dev
  census, old fights 700-705 terminus (builder0, n 6, never judged): 2-38 rooms a fight, ways back 1-26. **The filed
  series is RUNNING on builder2** (fresh 724-771 x terminus,locks,random, both arms, `native traffic-far-census`). L4/L5
  run after it (`tests/traffic/v2_lines.py`, `6fba31762`).
- **(4) item 4 + native's mirror:** `pair/firemission-on-n` `23251f069` = native's `5b6aa0fd2` (on my main-based
  `0d3f45b25`) + my test fix `328778c94` (the set-up-battery test needed a fire mission once firemission is ON). Its
  C31.1 (builder2, `make native check`) **exited 0: 2782 / 0**, sim-baseline unmoved, perf-judge 1.15x PASS (load 30) =
  bar line 6. Lines 1-5 RUNNING on builder2 (`item4_series.sh` in the session scratchpad; reader
  `tests/traffic/item4_lines.py`, `6847a0559`).
- **The laptop froze ~01:40** (kernel-side spin, swap full); the lead restarted it. Work resumed; no run was lost
  that mattered (the merge was redone).
- **(3) Fire-post loop DIAGNOSED (report only):** `references/round33/traffic/ov_firepost_r705.md` (`8a4c88f1`;
  random-705 reproduced exactly on builder2, n 1). An artillery truck's move reads arrived 5.1 m short. It then digs
  in after 0.25 s still (tank.gd), with NO target, and T1c-b2's `on_fire_post()` reads "dug in + fire_at_will + arrived"
  as a firing battery, so it refuses every passer for 66 s. The askers, also batteries, dig in on every stall. Owner
  proposal: traffic narrows T1c-b2 to a battery with a fire mission, OR brains adds "no dig-in without a fire mission".
  Brains' deployatplace switch alone leaves it (the blocker is 5.9 m from its slot, inside 8 m). Asked brains which.
- **(2) T4's replay line: a CORRECTION to R33.17** (`33154cc3`, `references/round33/traffic/ov_replay.md`, laptop
  GDScript, fixed-fps 60, n 6 seeds): a same-process rematch does NOT replay with the ghost OFF either (2 of 6 seeds
  branch; ghost ON 4 of 6). It enters at tick 1 as hull height (the physics server's settle). A fresh World3D does not
  fix it; a fresh process replays exactly. The orchestrator accepted: (r1) a FRESH process replays exactly ghost ON,
  judged; (r2) the same-process branch rate reported against ghost OFF. The same-process rematch is a new UNOWNED item
  (match/physics). Pair tree for T4: `pair/ghost-on-r34` `a74515f85` (main `062eb3759` + ghost ON; NOT to merge).
- **KNOWN RED on this branch until native's commit:** `test_native_exec_state::test_the_table_is_the_scripts_members`
  (native builds only): v2 added 7 Movement members native's exec_fields.h doesn't list. The C31.1 for the record on
  the v2 ON pair (`5259fb463`, builder2): 2776 / 6 (that test, test_native_h1b's settle twin, 4 test_traffic_neck ON
  tests: the native-ask bypass), sim-baseline docks moved (`ov_parkedroom_v2_c311.txt`). Native has the specifics.
- **(4) item 4's GDScript side built** (`8a5dd0a38`, DEFAULT_OFF `firemission`; bar FILED, `ov_item4_bar.md`): pair on
  current main once native's on_fire_post mirror lands.
- **(1) parkedroom v2 WAITING ON NATIVE (R33.33):** native's N5.Y moved Movement.ask into C++ with no parkedroom, so
  on the shipping path v2 barely acts (fresh-native dev census: 1.5 room give-ways a fight). Native builds a hand-back
  (Drive::ask passes a parkedroom ask to GDScript) on this tree; then a new pair, its own C31.1, and the series as
  filed. `ov_parkedroom_v2_design.md` last section.
- **(1) parkedroom v2 BAR FILED** (`ov_parkedroom_v2_bar.md`, amended: L6 needs n ≥ 50). Dev reads on old fights got
  L6 on unchanged orders 50 → 78 % (gate + way back; the way back is checked at Traffic.refresh too, `20b1cc113`), but
  those reads ran a STALE native library (builder0) or none (builder2): a probe target without `native` uses whatever
  the folder last built. Judged runs are `native <target>` from here. C31.1 on `pair/parkedroom-on-v2` `5259fb463` is
  running on builder2. s403 crossing no longer has X3's episode on today's tree (the tank holds and never asks), so the
  end-to-end trace is being picked from a fresh-native dev census.
- **(4) ASSIGNED (the orchestrator): T1c-b2 narrowed** to a battery set up AND with a fire mission. Bar first, judged on
  a tree with brains' battery item: "repack while firing 0", plus random-705's 20 loops → 0 and fresh fights. Queued
  after v2 and T4.
- **(2) T4 third try PARKED on G2** (`6e23e692d`, `references/round33/traffic/ov_t4_bar.md` Result; builder2, native,
  fresh processes, Locks, seeds 7–18, n 12): G1 median 14.0 v 15.5 PASS, G2 4 of 12 seeds > +3 s FAIL, G3 7/12 v 7/12
  PASS, r1 fresh-process replay 36/36 PASS, r2 same-process digest differs 12/12 in both arms (reported). Line 7 was red
  first: four native coverage floors starve under the ghost (R33.29: native makes its twin stages ghost-aware). T not run.
- **(2) T4 tooling ready:** `make traffic-t4-guard` (body_probe children ghost OFF v ON × body × seeds × 2 reps, plus
  rematch_probe digests; `tests/traffic/t4_guard.py`), on the pair tree `pair/ghost-on-r34` `00457710c`. Seed-1 smoke on
  builder2 ran end to end (not a judged number). Bar drafted; it is filed after v2's.
- **(1) parkedroom v2 BUILT (DEFAULT_OFF), bar not yet filed:** the gate (still ≥ 2 s by Traffic's table clock) plus a
  way back to the post driven by movement, which survives the CPU's re-sent orders. `references/round33/traffic/
  ov_parkedroom_v2_design.md`. Dev read on the old fights (builder0): rooms 2632 → 798 (12 a fight median, v1 42); the
  first build's way back rarely started (34 in 798: `reset()` dropped the post), fixed and re-reading.
- **(1) parkedroom v2, design read on the OLD X3 fights** (700–723, ON, builder2, exploration, never judged):
  2632 room give-ways. **No "at a post" gate rescues L6 as written.** The best group (HOLD, still ≥ 10 s, at its slot)
  returns within 3 m 36 % of the time, because the brain brings a crew back only for a hold ORDER beyond
  max(3 m, settle + 1) (tank_brain.gd:2854), and in CPU fights the order itself often moves. A second read is
  running, with the order at the 30 s read, so L6 can be judged on crews whose order did not change. The bar goes
  to the orchestrator after it.

**CLOSE-OUT (round 33, 2026-10-17 evening): every backlog item done, parked or reported. What reached main (the
orchestrator's merges): `islands-on-main` `0bf0a721` (main `f18e021f`) and `far-census-on-main` `c54a932d` (the merge after
it); main's next check covers both. `stream/traffic` itself does NOT merge (parkedroom's base).** Final check on
`stream/traffic` `97d8c56f`: NOT RUN, stopped while still queued for a builder0 slot (the orchestrator: it checks a tree
that won't merge). Last green check here: `traffic-islands` `b71b8097` (below).
- **X1** census DONE (above). **X2** parkedroom built, DEFAULT_OFF. **X3** series verdict FAIL (L1, L6) → PARKED (R33.12).
  **X4** T4 (ghost ON) PARKED (R33.17): line 7 red order-dependent, then R33.16's relative body guard FAILS in one cell;
  a round-34 candidate once brains' body stage stops swinging with the files run before it (their pacing note: wall-clock
  pacing, up to 9 s unpinned; round 34's guard = body_probe.gd child processes at --fixed-fps 60, one arm a process, plus
  a replay line; `references/round33/traffic/x4_body_guard.md`).
- **Statics audit** (`ef6589f0`, `references/round33/traffic/x4_rematch_statics.md`, laptop GDScript path, --fixed-fps 60,
  game code `bbb4d2db`, n 1 a cell): no traffic static carries one match into the next; ghost OFF a same-process rematch
  replays exactly (35.0 → 35.0), ghost ON it does not (37.0 → 28.5) under every clear incl. brains' caches and the
  registry: the carry is the physics server's `real_velocity`. Filed by the orchestrator for round 34 (main `42040bc9`).
- **Stretch: crate-roof islands GREEN** on `traffic-islands` `b71b8097` (base `aff64e2b`): builder0 `>> remote: make check
  exited 0`, 2732 passed / 0 failed (5 shards), sim-baseline **13/13 unmoved**, foundry included (`f72b1712479b2570`): no hashed
  route uses the dropped roof islands, so the bake change is behaviour-neutral for the baselines; determinism
  `9d66d3a0c59a7936` (`references/round33/traffic/stretch_islands_check.txt`). Carried to main as `islands-on-main`
  `0bf0a721` = main `e8383ce6` + the three commits, mk/traffic.mk = main's + the traffic-islands block only (7 files,
  +216); laptop on `0bf0a721`: test_traffic_islands 1/0.
- **X1 census on main (measurement only, for round 34):** `far-census-on-main` `c54a932d` = main `e8383ce6` +
  far_census.gd + far_table.py + navgap_plot's trace overlay + `make traffic-far-census / -hull / -one / -navgap`. On main,
  far_census has no FAR_ROOM rows or parkedroom counters (main's Movement has no `parked_rooms` / `room_log`). Laptop
  smoke on `c54a932d` (GDScript path, terminus s500, 20 s, n 1): FAR_CENSUS printed, no script errors; it runs, nothing
  more is claimed. far_ab.py (parkedroom's L1–L6 judge) and body_guard stay on this branch only.
- **Kept on `stream/traffic` only:** `tests/traffic/rematch_probe.gd` as 42040bc9's repro (ghost ON same-process rematch).
- **Merge notes:** do **NOT** merge `stream/traffic`, `traffic-islands`, `pair/parkedroom-on` or `pair/ghost-on-r33`
  (parkedroom's base / the parked defaults). Everything mergeable is already on main (above).
- **Not run:** the hull-rest census (`make traffic-far-hull`; now on main for round 34), box load; the Terminus re-judge
  (T4 parked); the final check on `97d8c56f` (above).
- **Known issues:** brains' `test_tactics_body::test_his_three_squads_keep_together` is order-dependent under ghost ON only
  (ghost OFF, as shipped, it is green); `Movement._registry` leaks instance ids across matches (harmless, movement's).

**T4 PARKED (R33.16, ~17:00 PDT):** R33.14's judged body-stage guard (`make traffic-body-guard`, builder0 light,
`pair/ghost-on-r33` `95f85afc` = game code `bbb4d2db`, seeds 1–3 × fronts none/test_det_core/test_rts_camera, n 9 a side;
`references/round33/traffic/x4_body_guard.md`): as filed, (1) median 15.0 v 15.0 PASS, (2)/(3) FAIL at seed 2 only (the
control arm fails the same cells: a bar defect, R33.16); the relative re-read (2') ghost ON ≤ OFF + 3.0 s FAILS in one
cell, test_rts_camera s3 (OFF 7.0 v ON 12.5; the front moved the CONTROL from 17.0, the ghost-ON arm reads 12.5 at every
front and arrives 4 s sooner), (3') PASS. T4 parks with that trace; the Terminus re-judge is NOT run. For a next round: the
stage swings with the files run before it (body_stage.gd:31), so a T4 guard on it needs a stage that doesn't
(brains' R33.14 hardening), or many more fronts.

**T4 now (~16:00 PDT):** pair tree `pair/ghost-on-r33` `bbb4d2db` (= `b4b78825` + ghost out of OPT_IN, round 32's
`93c85531` recipe). **Line 7 NOT green:** builder0 `>> remote: make check exited 2`: test 2730 / 1, 22 targets passed,
sim-baseline 13/13 MOVED (expected, ghost ON), perf-judge NOT JUDGED (box busy). The red:
`test_tactics_body::test_his_three_squads_keep_together` (brains'), ORDER-DEPENDENT: alone it passes 3/3; with
`test_rts_camera` (or shard-3 files 48–70 or 71–93) in front it fails (body-OFF alone 38.0/28.5 s, ON 18.5/17.5 s v the line
ON < OFF·0.5). Builder0 light, body-ON alone_s ghost OFF v ON by front: none 15.0/15.0, det_core 15.0/15.0, rts_camera
12.0/18.5, 48–70 12.0/18.5, 71–93 15.0/17.5 (n 1 a cell): the ghost costs the body-route squads +2.5–6.5 s alone in 3 of 5
orders; REPORTED beside the re-judge. **R33.14 (main `d0a60e2b`), ruling (a):** run the Terminus re-judge on `bbb4d2db`;
T4 does NOT merge until line 7 is green on a named hash, with brains' hardening commit of that test carried onto the pair
tree. Order on the lane: the islands full check (running, `traffic-islands` `b71b8097`), then the re-judge (script
`scratchpad/t4/run.sh`: drive 801–848 mixed+rigs base `--traffic-off=ghost`, `pinned_table.py`; fights random 900–923;
series 41–43 × 6 ticks).

**R33.12 (the orchestrator, main `402b3803`): parkedroom PARKED**; no v2 ahead of T4 and the islands. A v2 gates on a crew
AT a post and files a fresh bar first (new fights, not 700–723; L1 on hold-post far loops + all parked far loops not up;
L6 kept). random-705's fire-post loop is a separate problem, reported to close. Lead-page answer sent: yes, mildly: ~42
extra pull-aside moves a fight (crews only paused between orders), could read as milling; fights unchanged (L3).

**X3 SERIES VERDICT: FAIL (L1, L6) — parkedroom ships nothing; stays DEFAULT_OFF; `pair/parkedroom-on` is NOT to merge**
(builder0, stream/traffic `d90fbdb7`, fights 700–723 × Terminus/Locks/random, 180 s, n 72 paired;
`references/round33/traffic/x3_series_verdict.md`): L1 parked far loops OFF 22 → ON 25 (se 20.3) FAIL; L2 36 → 44 PASS;
L3 (random 24) kills 1031/1013, deaths 1041/1026, hit rate 0.704/0.694 PASS; L6 back within 3 m 212 of 2175 (10 %) FAIL;
R give-ways a fight median/worst OFF 158/330, ON 176/285 (room 42/111). L4/L5 not run (stopped after the fail, R33.10).
The targeted mechanism did go (hold-post "just gave way" loops 11 → 0); what is left is T1c-b2 fire-post loops (23, 20 in
one fight, random-705), outside the rule by design. L6 shows a real defect: "parked" = not under way, so crews paused
between orders are asked, make room and are sent on by their element (median 19.1 m from the "post" at 30 s). A next try
(not built; bar changes, the orchestrator's): gate on a crew AT a post, judge L1 on hold-post loops at a larger n.

**X1 DONE (REPORTED, 2026-10-17 ~08:30 PDT):** `references/round33/traffic/x1_census.md` (+ table, raw rows, the s403
picture). builder0, tree `dc6723ed` (= main `ae3dad71` + the probe, measurement only), showmatch fights 500–523 on
Terminus, the Locks and random, 180 s, n 69 read (3 timed out on a box at load ~30):
- far loops 37 (0.54 a match; 9 of 69 matches have any), Terminus 0.67, the Locks 0.77, random 0.05;
- **the brief's case, a PARKED crew of ANOTHER element: 3 episodes / 9 loops in 69 fights (~1 in 23 matches)**, well
  under the ~1-a-match line, so the orchestrator decides whether to build;
- behind ANY parked crew (any element or none): ~10 episodes / 30 loops (~1 in 7 matches); the parked crew's answer:
  "just gave way to this asker" 20, set up and firing (T1c-b2, his yes) 10;
- the mechanism (traced, s403 crossing): no spot in `_begin_yield`'s fixed set fits a parked crew in a neck, so it gives
  way IN PLACE (`yieldhold`, moves nothing) and then refuses that asker for good (`asker == _last_yielded_to`).
- Side finding for brains: CPU squads of more than 5 hulls are refused an element (C19.1) at the start and every think
  tick once the team's elements are gone (`element_commander.gd:180`): unseated crews and up to ~470 ERROR lines a fight.
- Tools: `make traffic-far-census` (FAR_AT, FAR_RANGE), `traffic-far-one` (FAR_TRACE, a dry-run spot search on parked
  blockers), `traffic-far-hull` (hull-rest's workload; NOT YET RUN: builder0 too loaded for its 144 serial runs),
  `traffic-navgap` (the plot runs locally: builder0 has no matplotlib).

**X3 pair check GREEN (C31.1): `pair/parkedroom-on` `6ea486ef`** (parkedroom ON), builder0 `>> remote: make check exited 2`:
test 2731 passed / 0 failed, 25 targets passed, native-verify-scenarios 0 mismatches; sim-baseline alone red, 11 of 13 maps
MOVED (pit, locks unmoved), reason: the rule ON. **Series STARTED 11:48 PDT** on stream/traffic `d90fbdb7` (game code =
`aff64e2b`, default OFF, arm `--traffic-on=parkedroom`); script and outputs in the session scratchpad `series/`.

**Stretch (crate-roof islands), built on its own branch `traffic-islands` `b71b8097`, NOT merged, full check GREEN
(close-out above: exited 0, 2732/0, 13/13 unmoved):** the
probe (`make traffic-islands`, builder0 light, all 13 arenas at region_min_size 2 / 4 / 8): the islands are the default
arena's only (foundry: five, 1.0–2.5 m² at 3.5 m); every other arena's components are identical at all three values (the
next-smallest island anywhere is a 72 m² ground pocket on crossing). Bake input: `region_min_size = 8.0` (64 cells, 16 m²) in
`arena.tscn`'s NavigationMesh; `test_traffic_islands` 1/0 (fails without it: default 2.0). Sim-baseline: foundry's maps may
move (reason: the bake drops five unreachable roof islands); the orchestrator adopts. Its full check runs after the
parkedroom series (R33.10).

**X3 now (~13:00 PDT):** the room search was tightened after the orchestrator's lane question (`ad347548`: with no
route the asker's corridor is its asked direction; the run to a spot never comes closer to the asker and never re-enters
its corridor). Pair tree `pair/parkedroom-on` `ea550faf` (= `cf17abd6` + that fix + the three granted OFF pins): builder0
light, traffic_neck 7/0 (incl. the lane case ON: spot 8.3 m off the lane, min gap 7.1 m, 0 contacts), test_movement 9/0,
nav_yield_fit 4/0; its FULL check is running. The series follows on that code (stream/traffic, base default OFF, arm
`--traffic-on=parkedroom`). **Merge note (R33.4 grant):** `test_movement::test_asked_to_give_way_it_steps_off_the_line_and_resumes`
and `tests/nav/test_nav_yield_fit.gd`'s two in-place / refusing tests pin parkedroom OFF (a setup line and a restore line
at the end; those files have no teardown).

**X3 pair check (C31.1), `pair/parkedroom-on` `cf17abd6` (parkedroom ON by default):** builder0 `>> remote: make check
exited 2`: test 2724 passed / 3 failed; sim-baseline red (expected with the rule ON); every other target green; native
traffic twins 0 mismatches. The 3 reds are the rule acting by design on tests of the OLD parked-crew semantics
(`test_movement::test_asked_to_give_way_it_steps_off_the_line_and_resumes`; `test_nav_yield_fit::test_a_rig_accepts_only_a_spot_it_fits_and_gives_way_without_the_wall`
and `::test_the_refusing_build_declines_when_nothing_fits`: ON, the rig takes `room(6,-22)`, run_ok, 0 contacts). Proposed to
the orchestrator: those tests pin parkedroom OFF (they judge the fixed set), with ON counterparts in test_traffic_neck.

**End-to-end fight case ON (the orchestrator's pre-series condition: MET):** s403 crossing, elements formed: the scout
reaches its room spot under its element, the tank is through the neck at 24 s and at its goal at 29 s (OFF: pinned 23–52 s,
4 far loops), the scout back on its post by ~33 s (`references/round33/traffic/x3_e2e_s403_*`). 51 room give-ways in
that 90 s fight, both sides: hence R (the give-way count).

**X4 trace DONE (R33.8):** `references/round33/traffic/x4_t4_circle.md`: the yard head-on s42/t3 circle is
`_approach_gate`'s (brains' v6, a named pass case), not the ghost's code.

**X2 AGREED (R33.4, the orchestrator, main `404f1e37`): BUILD `parkedroom`, kind-agnostic, option (a)** ("the deciding
finding is the mechanism, not the frequency"). The bar must carry, filed before numbers: (1) T1c-b2 as shipped (a set-up
mortar truck ordered to fire never repacks for a passer: 0); (2) the parked crew's return (back at its slot/post within a
filed time); plus far loops down on fresh skirmish fights, arrivals not down, one real end-to-end neck case with elements
formed before the series. Native: no mirror; N5 waits for the verdict. The element-refusal side finding went to brains (R33.5).

**Bar addition (the orchestrator, REPORTED, not judged): R: give-way count** — in L1's fights, give-ways started per
fight (all kinds) OFF v ON, and ON's room give-ways, each as the median and the worst fight (`far_ab.py`'s R line); if it
ships, a 30–60 s clip of the busiest fight's neck ON for him (does it look like milling?).

**X4's T4-ON bar (C33.7, filed 2026-10-17 before any number; R33.8: the circle is brains' v6 case):** tree = the
parkedroom series tree with the ghost as an arm (`--traffic-on=ghost`; base none), native path (the path that ships), FRESH
Terminus drive seeds 801–848 (n 48 a squad, paired; `nav-terminus-drive DRIVE_SQUADS="mixed rigs"`), read as round 32's
T4 (same reader). k = 1.645, se = the pair's own paired se of the sum.
1. **Deciding:** mixed friend-stuck crew-s: arm < base AND (base − arm) − k·se > 0 (round 32 at n 24: −294, se 211; at
   n 48 the same effect is ~1.4 se more than the line).
2. Rigs stuck: arm ≤ base + k·se. 3. Pinned (mixed, rigs): arm ≤ base + k·se. 4. Arrivals (mixed, rigs): arm ≥ base − k·se.
5. **REPORTED, not judged, until brains' v6 lands (R33.8):** the yard head-on's settle (all-in median, last arrival) and
   between-squad fast contacts, traffic-series seeds 41–43 × six ticks, n 18.
6. **(the orchestrator's, on main)** a skirmish guard: showmatch fights on the random arena, FRESH seeds 900–923, n 24,
   the manoeuvre-fights command line: kills, deaths, hit rate and far loops each within base ± 1.645 se (the pair's own),
   run entirely before brains' R33.6 merges or on a tree that has it in both arms, never across it.
7. **(the orchestrator's)** C31.1: the whole suite on a pair tree with the ghost ON, green before the series.
No partial rule: a fail on (1) parks T4 again with the reading. R33.10: one heavy builder0 job per stream at a time.

**X2 (the design as drafted):** option (a), traffic's own give-way, kind-agnostic: `parkedroom` (DEFAULT_OFF). A
PARKED crew asked to make room (1) never gives way in place (it buys the asker nothing), (2) is never refused for "I just
gave way to you" (that rule is for two movers trading the lane), and (3) when the fixed spot set has nothing, searches
wider (radii 6–20 m × 16 bearings, nearest first) for a spot off the asker's ROUTE (its remaining path, ≤ 40 m, not the
straight line to me) that it can drive straight to (the same `_free_spot` + `_yield_fits` sweep as every give-way), waits
there up to 20 s until the asker is past (the give-way's own `passed` rule along the asker's route), and its brain takes it
back to its post. **Reason for (a) over (b) the element make-room:** the mechanism is the give-way's (a refusal and an
in-place yield), not the seat; it covers every parked crew (other element, same element, unseated: 30 loops, not 9);
the crew returns to the seat its element chose, so no seam with brains and nothing in `game/tactics/**`. The set-up
battery (T1c-b2) keeps refusing (his yes). Native: `ask` / `_begin_yield` run in GDScript on both paths (called back from
`_negotiate` / `_escape_begin`); `right_of_way` (twinned) is unchanged; so N5 needs no new port for this rule beyond what
it holds. Stage: `tests/test_traffic_neck.gd` (the s403 neck, both crews in their own elements): OFF reproduces (the tank
never through in 40 s, far loops 3); ON being made to pass.

**Plan (2026-10-17):** X1 census probe (`tests/traffic/far_census.gd`: manoeuvre's H1B_FAR rows read-only, plus the
blocker's state the tick each row is written: set up, order verb, option, element task, distance to its slot/goal, why
it refused) + `make traffic-far-census` (FAR_AT arenas × FAR_RANGE seeds, showmatch fights, both CPU sides run elements)
+ `tests/traffic/far_table.py` → validate on round 32's fights 403–409 → census on Terminus, the Locks and random, fresh
seeds, plus hull-rest → the table under `references/round33/traffic/` → frequency to the orchestrator → X2 → X3 → X4.
Reason for the probe instead of a hook in manoeuvre's census: the row is already written there; reading it the same tick
from a SceneTree probe needs no change in a path traffic does not own.

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
