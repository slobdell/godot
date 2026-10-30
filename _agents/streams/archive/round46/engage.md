> **ARCHIVED (round 46 closed 2026-10-30).** Final state of this brief; results in `workstreams.md` *Bars/Rulings (round 46)*.

# Stream: engage (his IFV behind his own squads finds a lane and fires; when it can't, the feed says who is in the way)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 344, 345), `_agents/judging.md`, `_agents/workstreams.md` **Round 46**
> (C46.1-C46.8, R46.3, R46.4), your last brief `streams/archive/round45/engage.md` (Status: the lone-IFV trace, E2, E2b / E6, the garage
> map), R45.19, R45.24, R45.29 in `workstreams.md`. **You own:** `game/ai/gunnery.gd`, `game/ai/fire_lanes.gd`, `game/ai/tank_brain.gd`'s
> CLEAR_LANE option and its constants, `game/ai/native/native_decide.gd`'s constant table (additive), `game/tactics/drills.gd`,
> `game/tactics/element.gd`'s player-authority code, `game/tactics/element_plan.gd`'s engagement functions, `game/tactics/firing_position.gd`,
> `game/ai/order_controller.gd` (trace lines), GRANT `game/control/order_executor.gd`'s `stop` / `hold` / `move` / `attack_move` crew
> branches, GRANT `game/ui/hud_messages.gd` (one additive line kind, C46.5), `tests/tactics/test_engage*.gd`, `tests/engage/**`,
> `tests/test_authority*.gd`, `tests/test_gunnery*.gd`, `tests/test_fire_lanes*.gd`, `mk/engage.mk`, `game/garage/**`, `mk/garage.mk`.
> **Model:** Opus. **Machine:** builder3. **Seeds:** 11901-11948 (Bar L1), 11949-11996 (E6 / reserve). Dev 7001-7012 (never a bar).

## The lead's direction (2026-10-29 ~23:00, Terminus, verbatim)

"I was controlling an individual IVF and it seemed like it wasn't shooting at anything the whole time. I'm not sure if it finally got
shots off toward the end."

Memory: smart AI on both sides (friendly units as smart as Gears of War squadmates); units must look smart and under his control.

## Where things stand (main at launch: see HANDOFF; code 96f199c45 GREEN builder3 3470/0)

- **Your trace (round 45, builder3):** his crew Green_Hunters_1 fired 3 rounds from 104 s to 140 s with an engaged target 10-30 m away,
  clear sight, 3-5 enemies in range; then 30 rounds in 3 s at 140 s. Not E2 (identical with `--authority-off-at`), not ammo / heat /
  reload / sight. **Cause: his own vehicles in its line of fire:** `Gunnery._clear_to_fire` (FireLanes) holds a shot whose lane crosses a
  friendly; the blocker changed throughout (Guns_4 116 s, Guns_2 120-122 s, Hunters_2 124-128 s, Hunters_3 130 s, Wrenches_3 132-136 s,
  Guns_4 138 s), blocked up to 198 ticks running while the brain chose CLEAR_LANE. Command: `make engage-authority-trace
  AUTH_RECORDING=references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl AUTH_UNITS=Green_Hunters_1 AUTH_FROM=3090 AUTH_SECONDS=145`.
- CLEAR_LANE: `tank_brain.gd` (`CLEAR_LANE_EDGE` 1.15, the search radius const near :98), mirrored into native's decide via
  `native_decide.gd`'s constant table: **a behaviour change there needs native's twin (C46.4)**.
- E6 (the stop cap, `--turn-in-cap=on`, OFF): Bar E2b failed only on G5 (native runs a `stop` itself except a fixed gun on wheels).

## Backlog (in order)

1. **L1 why CLEAR_LANE finds no lane in a crowd, on his recording.** Per tick 3090-4200 for Green_Hunters_1: the candidate spots CLEAR_LANE
   scored, why each was rejected (blocked lane, out of range, no path, occupied, leash / his order), the one it chose and whether it
   moved. Is the blocker moving (a squadmate driving through the lane) or parked? Write the cause in Status before code; message the
   orchestrator.
2. **L2 the lane move that works in a crowd, ON by default, `--lane-clear=off` the escape.** Candidates: score spots by the lane being
   clear of friends' *predicted* positions (their current route), not just this tick's; widen the search ring when the near ring is
   all blocked; a small lateral / forward step beats waiting; respect his order (E2: a crew he moved holds its post; the lane step
   stays within a few metres of it and returns). Optionally the blocking friend nudges aside when it is idle (manoeuvre's yield is
   theirs: ask through the orchestrator, don't edit movement). Symmetric (C46.6). Tests first: a staged crowd (his 116-140 s geometry)
   where today's crew holds > 10 s and the new one fires within ~3 s; a crew with no clear spot doesn't oscillate.
3. **L3 the feed line (C46.5):** when a crew in his selection holds a shot for a friend in the lane for > ~2 s, the feed says
   "<crew> holding fire: <friend> in the way" through `HudMessages` (its duplicate / rate rules apply). One line kind, no icon, no
   button; the escape is `--lane-clear=off` too. Screenshot it at desktop and phone aspect and look at it.
4. **L4 Bar L1**, filed BEFORE any number on 11901-11948, native's twin EQUAL first (C46.4), a staged crowd workload + full fights.
   Deciding: seconds a crew with an engaged target in range holds fire for a friend (his case's line), time to first shot after the
   lane blocks. Guards: friendly-fire hits (must not rise: the rule never fires through a friend), deaths of the stepping crew, his
   order held (E2's authority probe), the fight probe (kills / losses within base +/- 1.645 se), manoeuvre's one-squad arrival. Ships
   ON the minute it passes; name the green hash.
5. **L5 his acceptance read:** his Terminus replay on the shipped tree: Green_Hunters_1's shots 104-140 s before/after.
6. **E6 one try (R46.4):** the one-condition fix (fixed mount + wheels), a workload that stages it, Bar E6 on 11949-11996. If it fails,
   remove the code and say so.
7. **Stretch:** the garage (his ask list in `game_design.md`) — only if he adds one.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote`; `make engage-*` and
`make replay-match`; screenshots of the feed line looked at. Every number with its commit, machine, workload and n.

## Don't touch

`game/control/**` but your grant, movement / traffic (manoeuvre), `native/**` (native twins it), `game/camera/**`, `game/ui/**` but
`hud_messages.gd`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. If Bar L1 fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### FINAL REPORT (round 46, 2026-10-30 ~07:40 PDT) — read this first

**Shipped ON: his IFV behind his own squads steps to a clear lane and fires; when it can't, the feed says who is in the way.**
Bar L1c PASSED (R46.31) and merged at **1dd227534** (main 0471b8e14). `--lane-clear=off` turns all of it off. In his terms: a crew
(his or the CPU's) held by a squadmate in its line of fire steps aside and fires, ~5 s less held per blocked fight (L1c: 15.5 ->
10.7 s, -4.2 se); a burst never walks into a squadmate (friendly hits 9 -> 4, fewer than today); "Hunters 1 holding fire: Guns 4 in
the way" in the feed when it can't get a lane (crews in his selection, desktop controls); his hold / stop never moves it; at the post
his move left it, one step <= ~4 m (R46.7).

| Item | Outcome |
|---|---|
| L1 cause | DONE: three causes (post: no candidate + post refusal; attack: the order's +1.0 dilutes CLEAR_LANE's edge; spots tested weaker than the trigger) |
| L2 lane move | SHIPPED (in L1c) |
| L3 feed line | SHIPPED; looked at in his own replay (desktop); touch map has none (round 47) |
| L4 bars | L1 FAIL G1 (a burst walked into a squadmate), L1b FAIL D1 (moving-spread spots: no gain), **L1c PASS** (R46.31 on G4's exact tie) |
| L5 his read | DONE (below) |
| E6 | DROPPED (R46.22), code removed (6f9dba2c5 + 749a8cf22) |
| R46.19 dry_hop | SHIPPED in both arms: ENGAGE's direct hop never crosses water (his Locks bridge, the CPU side) |

**L5, his acceptance read** (his Terminus replay as played, `--lane-clear=off`, v the shipped rule switched on at 103 s where his lone
IFV starts, `--lane-clear-on-at=3090`; builder3, 63325f533's code = main + engage, native on, n = 1 replay): Green_Hunters_1's rounds
104-120 s: **10 v 0** (as played, 3 rounds 104-139 s; 16 -> 26 by 120 s v 16 -> 19). After ~125 s the two games differ (the rule
acts on every crew; no enemy is in its range in the ON game), so later seconds are not comparable. Logs `~/overnight-engage/r46/authority_l5*.log`.

**What to playtest:** `make garage` (any map) or a skirmish on Terminus: put an IFV behind your own parked squads with an enemy in
range; it should side-step and fire within a few seconds; select it when boxed in and read the feed. `--lane-clear=off` for today's game.

**Round 47 notes (no code this round):** (1) 12328 (Locks, gang_tank at his post): the MOVER'S YIELD (phase `yielding`, manoeuvre's)
drove a crew holding his post ~10 m toward the enemy to give way to a squadmate, then HOLD reversed it and the 6 m arrival radius
parked it 6 m short: his post is moved by traffic (both arms identical; manoeuvre + engage's post rule). (2) The touch map has no
`selection_state`, so no feed line on the phone layout. (3) A burst gun's later rounds were never re-checked before L1c (now under
`--lane-clear`); the trigger checks the first round only. (4) The authority probe's stop max 5.1 m under his stop is pre-existing
(both lane arms, 12301-12324).

**Machines / numbers:** every series builder0 light, every check builder3, native on; evidence `~/overnight-engage/r46/` (laptop).
**Merge notes:** granted shared edits this round: `game/tank/tank.gd` burst branch (R46.26), `tank_brain.gd` ENGAGE `dry_hop` (R46.19),
`hud_messages.gd` (C46.5); native's twin (pair/native-l2) merged into this branch.

### Report so far (2026-10-30 ~02:00, round 46) — superseded by the final report

| Item | State |
|---|---|
| L1 why CLEAR_LANE finds no lane | DONE (below): three causes, every blocker parked; R46.7 ruled on the post case |
| L2 the lane move, `--lane-clear` ON | code + tests DONE 9446e1903 (not yet a full check); native twin spec sent (decide guard until then, C46.4) |
| L3 the feed line | DONE: code + tests 320fbcd11 / aeb32f603; LOOKED AT in his own Terminus replay (laptop window, rule on at 103 s, 9446e1903-era tree): "Hunters 1 holding fire: Wrenches 3 in the way" in the left info feed, the crew selected through RtsControls (`~/overnight-engage/r46/shots/line-1920x1080-t36*.png`); as history it truncates like every older line ("Hunters 1 holding fi..."). Phone: the touch map has no `selection_state`, so no line there (R46.26: round 47); the laptop would not size the window to a phone aspect (`--resolution` ignored by the replay script's window) |
| L4 Bar L1 | **FAILED on G1** (fa9c6ff3a: friendly hits 1 -> 6, a burst walked into a squadmate; D1 / D2 PASS); not shipped (R46.24) |
| L4b Bar L1b | **FAILED on D1** (no gain: moving-spread spots rarely exist); G1 PASS (friendly hits 4 -> 1) |
| L4c Bar L1c | **PASSED** (R46.31); **ships ON at 1dd227534** |
| L5 his replay | dev read (below); the acceptance read waits for the shipped tree |
| E6 | **DROPPED (R46.22)**: the staged case shows no drift (dev 7001-7012, n 9: <= 3.2 m, capped arm identical); code removed after L1b's series |

**L2 (`game/ai/tank_brain.gd`, `--lane-clear=off` = round 45 exactly):** (1) under his attack / attack-move, CLEAR_LANE is
multiplied by its edge AFTER the order's base, so it beats the committed ENGAGE; (2) a crew holding his post after his MOVE (E2's
post, `lane_step`) serves the gun's held target and may step <= LANE_POST_STEP 4 m (R46.7), the parked-hold rule stands aside for that
step, HOLD drives it back once nothing is in sight; never under his hold or stop (the hold verb allows HOLD only); (3) `_lane_spot_v2`
tests spots with the trigger's own geometry (`Units.hull_distance_to_line`, `Match.shot_spread`, LINE_OF_FIRE_OVERSHOOT 15 m) plus
LANE_SPOT_MARGIN 0.3 m, friends now and 1 / 2 s ahead, rings 3 / 6 / 10 / 16 m; a wheeled hull takes drivable headings (fore / aft,
0 / +-25 / +-50 deg: the IFV is 7.5 m long with a 7 m circle and the mover stops a sideways step short); a spot the mover reads as
arrived short of is dropped and the next taken; a stale goal still clear is kept; nothing clear = stay and face (no blind sidestep).
**Staged crowd** (`tests/test_fire_lanes_crowd.gd`, builder3, 9446e1903, native on, n = 1 each): his case (IFV, enemy 19 m, a
squadmate parked 10 m out in the lane): OFF never fires in 12 s, ON first round 4.0 s, 0 friends hit; a wall of 3 parked: never v
4.7 s; boxed in by 8 (no lane): ON drives 24 m v OFF 30 m; his hold: 0.0 m; his post: <= 4 m.
**His Terminus replay, rule ON from tick 3090 (`--lane-clear=off --lane-clear-on-at=3090`, builder3, 320fbcd11's code, n = 1, a
DEV read):** Green_Hunters_1 fired 10 rounds 104-120 s v 3 rounds 104-139 s as he played it; at his post (118.6 s) no 4 m step was
clear (it held, no wander) until the lane cleared at 119.5 s, then 7 rounds; from ~125 s the two games differ (no enemy in range).
**L3 (`game/ui/hud_messages.gd`, C46.5):** "Hunters 1 holding fire: Guns 4 in the way" for a crew in his selection held > 2 s and
still being held, once per crew per 15 s (8 s read chatty on the dev probe: 4 lines in a 30 s hold), through HudMessages' duplicate / rate rules; none with `--lane-clear=off`. Tests
`tests/engage/test_engage_lane_line.gd` + the staged case (one line, naming the friend).

### Bar L1c (FILED 2026-10-30 ~06:05) and L1b

### Bar L1b (FILED 2026-10-30 ~05:40, before any number on 11949-11996)

- **Bar L1c VERDICT (2026-10-30 ~06:50 PDT): PASSES (R46.31 on G4's tie); ships ON at 1dd227534** (builder3 check 3486/0, only
  sim-baseline moved). builder0 light, native on, 12301-12348, 48 paired, 0 errors. D1 PASS (rule's case n 41: held 15.53 -> 10.65 s,
  -4.88, se 1.17); D2 PASS (31/41 sooner or identical, 11 strictly); G1 PASS (friendly hits 9 -> 4, kills 0 / 0); G2 2 -> 1; G3 hp
  0.62 -> 0.53; G4 max 10.1 m in BOTH arms on 12328 (an exact tie, no lane step: R46.31), every rule-caused post move <= 5.4 m,
  held_s post -2.52 (se 1.34); G5 PASS (E2's probe 24/24 seeds identical); G6 PASS (orders' default probe 48/48 rows identical); G7
  PASS (native EQUAL on 1dd227534). Evidence `~/overnight-engage/r46/barl1c/` (laptop).

- **Bar L1c HIS IFV FINDS A LANE; A BURST NEVER WALKS INTO A SQUADMATE (engage; filed 2026-10-30 ~06:05 PDT in streams/engage.md and here, BEFORE any number on 12301-12348; R46.28).**

  **The rule:** L1's lane move (CLEAR_LANE's edge after the order's base; the post step <= 4 m, R46.7; spots tested with the trigger's
  geometry at the STANDING spread, rings 3 / 6 / 10 / 16 m, a wheeled hull's headings) + L1b's burst re-check (`Tank._burst_into_friend`,
  R46.26: each later round of a burst checks the line; a friend in it ends the burst), all under `--lane-clear`. Both arms carry R46.19's
  `dry_hop`. **Workload, arms, machine, the rule's case:** Bar L1b's exactly, seeds **12301-12348**; the frozen tree named when frozen
  after its full check; builder0 light; native ON.

  **Deciding (the rule's case):** D1 `held_s` paired mean ON - OFF < 0 by at least 1.645 se (one-sided); D2 `first_shot_s` ON sooner
  or identical in >= 60 % of runs (strictly sooner reported).

  **Guards:** G1 friendly fire by the crew: hits ON <= OFF + max(1, 1.645 sqrt(OFF)); kills ON <= OFF. G2 crew deaths ON <= OFF +
  max(1, 1.645 sqrt(OFF)). G3 enemy hp left: paired mean ON - OFF <= +1.645 se. G4 post runs: every ON run's farthest from his post <= 5.5
  m; held_s ON - OFF <= +1.645 se. G5 E2's authority probe (seeds 12301-12324, AUTH_ARM=on) `--lane-clear=off` v default: Bar E1's D1
  (hold / stop moved <= 3.0 m), D2 (pushed rows 0), D3 (move ends) unchanged. G6 orders' default probe rows identical ON v OFF. G7
  native's `test_native_decide` equality on the frozen tree.

  **Reported:** held_s by mode; moved_m; shots; feed lines; bursts ended by a friend. A pass ships ON; a fail goes to him in player
  terms the same hour (the orchestrator may ship the feed line and the burst re-check alone: separable, `hud_messages.gd` + its test,
  `tank.gd`'s burst branch + `tests/test_fire_lanes_burst.gd`).

- **Bar L1b VERDICT (2026-10-30 ~05:50 PDT): FAILS as filed on D1** (c0affabe0's code, series tree dcabca4dc = + a brief-only docs
  commit, builder0 light, native on, 11949-11996, 48 paired, 0 errors). **D1 FAIL** (rule's case n 38: held 17.54 -> 18.28 s, +0.74,
  se 1.02); D2 PASS (31/38 sooner or identical, 8 strictly); G1 PASS (friendly hits 4 -> 1, kills 0 / 0); G2 1 / 1; G3 hp 0.72 ->
  0.74; G4 post max 5.3 m. G5 / G6 not run. Cause: spots kept clear by the MOVING spread rarely exist in a crowd (no step); the burst
  re-check is what removed L1's friendly fire. Proposed L1c: L1's spot test + L1b's burst re-check, fresh seeds (the orchestrator's
  ruling). Evidence `~/overnight-engage/r46/barl1b/` (laptop).

- **Bar L1b HIS IFV FINDS A LANE AND NEVER FIRES INTO A SQUADMATE (engage; filed 2026-10-30 ~05:40 PDT in streams/engage.md and here, BEFORE any number on 11949-11996; R46.24: a new filing, not an amendment of L1).**

  **What changed since L1:** (1) lane spots are kept clear by the MOVING spread (`TankBrain._lane_spread`); (2) under `--lane-clear`,
  each later round of a burst re-checks the line and a friend in it ends the burst (`Tank._burst_into_friend`, R46.26). Both arms
  carry R46.19's `dry_hop` (unswitched). **Workload, arms, machine:** Bar L1's exactly (`make engage-lane-bar`, `tests/engage/lane_probe.gd`,
  `lane_table.py --pair`), seeds **11949-11996**, OFF = `--lane-clear=off`, ON = default, one frozen tree (named when frozen, after its
  full check), builder0 light (or builder3 light), native ON. **The rule's case** = attack and cpu runs blocked in OFF.

  **Deciding (the rule's case):** D1 `held_s` paired mean ON - OFF < 0 by at least 1.645 se (one-sided); D2 `first_shot_s` ON sooner
  or identical in >= 60 % of runs (strictly sooner reported).

  **Guards (all 48 unless named):** G1 friendly fire by the crew: hits ON <= OFF + max(1, 1.645 sqrt(OFF)); kills ON <= OFF. G2 crew
  deaths ON <= OFF + max(1, 1.645 sqrt(OFF)). G3 enemy hp left: paired mean ON - OFF <= +1.645 se. G4 post runs: every ON run's farthest
  from his post <= 5.5 m; held_s ON - OFF <= +1.645 se. G5 his order to a crew (C46.3): E2's authority probe (`make engage-authority-probe`,
  seeds 11949-11972, AUTH_ARM=on) with `--lane-clear=off` v default: Bar E1's D1 (hold / stop moved <= 3.0 m), D2 (pushed rows 0), D3
  (move ends) unchanged. G6 orders' default probe (`make orders-probe`, default cells) rows identical ON v OFF. G7 C46.4: native's
  `test_native_decide` equality on the frozen tree (native re-proves).

  **Reported:** held_s by mode; moved_m; shots; feed lines; `Tank.burst_friend_stops`. A pass ships ON; a fail goes to him in player
  terms the same hour and the default turns OFF before any merge.

- **Bar L1 VERDICT (2026-10-30 ~04:50 PDT): FAILS as filed on G1** (frozen fa9c6ff3a, builder0 light, native on, 11901-11948, 48
  paired, 0 errors). D1 PASS (rule's case n 40: held 20.79 -> 16.94 s, -3.84, se 1.27); D2 PASS (35/40 sooner or identical, 12
  strictly); **G1 FAIL: friendly-fire hits 1 -> 6** (bar 2.6; kills 0 -> 0; 5 in seed 11922: a law_ifv's 4-round burst checked on its
  first round only, the hull pulled away mid-burst from a spot clear by the standing spread); G2 0 / 0; G3 hp 0.79 -> 0.72; G4 post max
  4.6 m. G5 / G6 not run. Not shipped (R46.24); L1b below. Evidence `~/overnight-engage/r46/barl1/` (laptop).

### Bar L1 (FILED 2026-10-30 ~02:20, before any number on 11901-11948; also in workstreams.md *Bars (round 46)*)

- **Bar L1 HIS IFV BEHIND HIS OWN SQUADS FINDS A LANE (engage; filed 2026-10-30 ~02:20 PDT in streams/engage.md and here, BEFORE any number on 11901-11948).**

  **Workload:** `make engage-lane-bar LANE_SEEDS="11901 ... 11948"` (`tests/engage/lane_probe.gd`, table `tests/engage/lane_table.py
  --pair`): per seed a drawn arena (gorge / locks / terminus / crossing), crew hull (4 IFVs, 2 tanks, 2 scouts), enemy gun (5 kinds,
  shoots back) 18-32 m off with a clear line, one squadmate in the lane (35-65 % of the way, within 1.5 m of the line) and one or two
  beside it (3-8 m off the line), on a third of the seeds the one in the lane driving ACROSS it; the friends hold their fire. Who
  commands the crew, by seed: his ATTACK on the gun, his MOVE done (E2's post), or the CPU's own brain (no player; C46.6). 30 s
  window. Arms OFF = `--lane-clear=off`, ON = default, paired by seed, one frozen tree (named when frozen), builder3, native ON.
  **The rule's case** = attack and cpu runs blocked in OFF (held for a friend at least once); post runs are R46.7's 4 m bound, where
  a step rarely clears a friend in the lane (dev: held ~29 s in both arms), so they are guards, not deciding.
  **Native (C46.4):** ships with decide's GDScript path for lane-blocked situations (`TankBrain.lane_case`) unless native's twin has
  landed EQUAL by the freeze (then the twin's tree is frozen instead and `test_native_decide` equality is a guard).

  **Deciding (the rule's case):**
  - D1 seconds held for a friend while the gun has a target (`held_s`): paired mean ON - OFF < 0 by at least 1.645 se (one-sided).
  - D2 first round after the first block (`first_shot_s`): ON sooner or identical in >= 60 % of runs (strictly sooner reported).

  **Guards (all 48 unless named):**
  - G1 friendly fire by the crew: hits ON <= OFF + max(1, 1.645 sqrt(OFF)); kills ON <= OFF.
  - G2 crew deaths ON <= OFF + max(1, 1.645 sqrt(OFF)).
  - G3 enemy hp left: paired mean ON - OFF <= +1.645 se (the crew does not hurt the gun less).
  - G4 post runs (R46.7): every ON run's farthest from his post <= 5.5 m (4 m + the hull's settle); held_s ON - OFF <= +1.645 se.
  - G5 his order to a crew (C46.3): E2's authority probe (`make engage-authority-probe`, seeds 11901-11924, AUTH_ARM=on) under
    `--lane-clear=off` v default: Bar E1's D1 (hold / stop moved <= 3.0 m), D2 (pushed rows 0) and D3 (move ends) unchanged.
  - G6 orders' default probe (`make orders-probe`, its default cells) rows identical ON v OFF where no lane is ever held (the rule
    acts only through CLEAR_LANE, which a move / stop / hold verb never allows).

  **Reported:** held_s by mode; moved_m; shots; feed lines (ON: post and attack runs; OFF: 0). A pass ships ON (it is ON by default
  already on stream/engage; a FAIL turns the default OFF before merging and goes to him in player terms the same hour).

### L1 DONE: why his IFV found no lane (his Terminus replay, builder3, 7189e3ff3 + trace rows, native on, n = 1 replay, 3090-4380)

Command: `make remote T="engage-authority-trace AUTH_RECORDING=references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl
AUTH_UNITS=Green_Hunters_1 AUTH_FROM=3090 AUTH_SECONDS=145 AUTH_EVERY=15 AUTH_TAG=l1base"` (log kept at `~/overnight-engage/r46/`).
New rows: `LANE_READ` (each `_lane_spot` search: 16 candidates, the reject reason of each, the pick) and, on AUTHORITY, the lane goal,
the move sent, moves refused by his post, and the blocker's speed / order / option. Shots 19 at 116.5 s, 19 at 139.1 s, then 31 in 3 s.
**Every blocker in the held windows was PARKED** (speed 0.0, phase `arrived`), except Guns_4 at 137.7 s (4 m/s, 45 m off). Three
separate causes, one per window:

| Window | What it did | Cause |
|---|---|---|
| 118.4-122.8 s (4.4 s), his move done, holding his post | `HOLD`, lane blocked by Guns_2 / Hunters_2 (parked) | the CLEAR_LANE gate needs a current fight target; a held crew's `HOLD` has none, so CLEAR_LANE is never a candidate (and its move would be refused by the post rule: `held_may_move` has no CLEAR_LANE) |
| 122.8-134.0 s (11.2 s), his attack on Eyes_3 | `ENGAGE`, lane blocked 28 -> 120 ticks by Hunters_2 / Hunters_3 / Wrenches_3 (all parked) | **scoring:** under his `attack` the order adds a +1.0 base to every candidate BEFORE the commitment bonus multiplies the current one, so ENGAGE = (1 + e) x 1.15 and CLEAR_LANE = 1 + e x 1.15 x 1.15: CLEAR_LANE wins only when e > 0.87. The exact trap the CLEAR_LANE_EDGE comment warns about, re-opened by the order's base |
| 134.0-139.1 s (5.1 s), CLEAR_LANE at last | picked spots 5.6 m and 6 m aside, arrived, still blocked by the SAME parked Wrenches_3 (10-11 m off), then Hunters_2 / Guns_4 | **the spot test is weaker than the trigger's:** `_lane_spot` checks a 2 m point disc with no spread (`FireLanes.in_line`), the gun's gate checks the real hull box plus spread (`Match.friendlies_in_line_of_fire`), so "ok" spots stay blocked; a re-pick only every 2 s; rings 6 / 10 m only |

At 139.1 s ENGAGE drove it 3 m forward, the lane cleared, 30 rounds in 3 s. **Not a moving squadmate**: parked friends between it and
the target, and a brain that would not (attack), could not (post) or did not correctly (spot test) step aside.

**L2 design from this (one switch `--lane-clear`, ON; `=off` restores today exactly):** (1) CLEAR_LANE keeps its edge after the order's
base (under attack / attack-move it is multiplied after the base is added); (2) a crew with no fight target (holding his post) serves
the gun's blocked target, and the post rule lets that step out to a few metres of the post (HOLD brings it back); (3) the spot test
uses the hull reach + the gun's spread + friends' positions 1-2 s ahead, a third ring at 16 m, and a re-pick 0.5 s after arriving
still blocked. (1) and (2) change decide's scoring: until native twins them (C46.4), decide runs the GDScript for exactly the
situations the rule can change (lane blocked >= LANE_BLOCKED_TICKS, switch ON); every other decide stays native.

### Plan (2026-10-30, round 46 start; fresh session on 7189e3ff3, launch check cb1014bed builder3)

1. L1: instrument `_lane_spot` (`TankBrain.LANE_READ`, trace only: the 16 candidates, each one's reject reason, the pick, fallback) and
   the authority trace (lane goal, the move sent, moves the post leash refused, the blocker's speed / order / option); read 3090-4200.
   Suspect to prove or kill first: `held_may_move` has no CLEAR_LANE, so a crew holding his post gets its lane move turned into a face.
2. L2 from L1's cause, tests first (staged crowd from his 116-140 s geometry), behind `--lane-clear` ON.
3. L3 the feed line; L4 Bar L1 filed before numbers; L5 his replay; E6 one try.

