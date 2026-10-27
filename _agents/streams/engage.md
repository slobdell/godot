# Stream: engage (a crew under his attack order never stands behind a container NOT FIRING: it drives to a spot with a clear shot and fires)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 42** (C42.1, C42.2,
> C42.6), `_agents/game_design.md` *His playtest after round 41*. **You own:** in `game/tactics/element_plan.gd` the engagement
> functions (`_engage`, `_hold`'s in-range test, the orbit drill's in-range test ~3062, `ENGAGE_RANGE_FACTOR`, the crew-reach read
> ~662) and nothing of settle's (deploy-step, halt-lay, seat-deal); `game/tactics/element_situation.gd` (additive per-member fields);
> `game/tactics/drills.gd` `nearest_visible`; a new `game/tactics/firing_position.gd`; `game/control/order_executor.gd`'s `attack`
> branch (:126; orders has no stream this round: a GRANT, merge note); `game/ai/order_controller.gd` only if E1's trace lands there
> (merge note; native mirrors its seams); `tests/tactics/test_engage*.gd`, `tests/engage/**`, `mk/engage.mk` (new); GRANT (C42.6)
> `game/control/rts_controls.gd` `attack_shortfall` / `_moving_round` wording only. **Model:** Fable. **Machine:** builder0 light lane
> (J<=4); builder2 for a bar series over 24 fights (`make gcp-start`; Spot). **Seeds:** 9601-9624 (Bar E1 deciding), 9625-9648 (its
> fight guards). Dev 7001-7012 (never a bar).

## The lead's direction (2026-10-26, verbatim)

"I had 2 scouts attacking a Syndicate artillery piece. When I told them to attack, one vehicle was behind a milvan container. Even
though I explicitly told them to attack, one vehicle was just stuck behind the container (or waiting behind the container) with a banner
that just said "not firing" I think. If I tell my units to attack I expect them to navigate around obstacles and toward the enemy such
that they can and do attack"

**The rule he wants (the orchestrator's reading, approved):** a crew under his attack order that cannot hit its target moves to a spot
that can, round the obstacle and toward the enemy, and fires. "In range" means a clear shot, not a distance. His standing bar (memory,
*units must look smart*): he must perceive units as smart and under his control.

## Where things stand (main at launch: see HANDOFF)

- **His recording:** `_agents/streams/references/round42/engage/2026-10-26T14-15-45-locks.jsonl` (Locks, seed 49326, Gangs v
  Syndicate, round-41 main; copied out of `build/`, which a remote copy-back wipes). His `attack` orders on Rust_Battery_3 (tick 3048)
  and Rust_Battery_1 (tick 3293) went to Green_Spears2_3 + Green_Spears2_4 (Rat Rods). Spears2_4 killed all three Missile Rings.
  **Spears2_3 got zero kills: it sat "arrived" at (44.3, -74.4) from tick 3240 to his move at 4350 (37 s), 22-26 m from its targets,
  under an attack order the whole time**, HUD banner NOT FIRING. Readers of a recording: grep `recordings/` in `tests/` and `tools/`
  (`test_tactics_attack_obeyed.gd`, `tactics/pursuit_case.gd`, `tools/perf_trace_report.py`); `--record-dir` writes one.
- **The orchestrator's code read (a hypothesis, E1 confirms or corrects it):** `ElementPlan._engage` (element_plan.gd ~3250) orders
  `attack` to every member whose DISTANCE to the target is <= range x ENGAGE_RANGE_FACTOR (1.15), with no line-of-fire test; the same
  distance-only test sits in `_hold` (~3270) and the orbit drill (~3062) and the crew-reach read (~662). The executor's `attack` branch
  (order_executor.gd:126) stops the crew only when `close` (in reach AND `controller.engaged_target == target`), else drives toward the
  target's position; so why this crew STOOD STILL for 37 s is not yet explained by the plan alone: the recording has the answer (the
  mover's arrive, a `stop` from elsewhere, an `engaged_target` on something it could not see, or the squad plan re-issuing every tick).
- Sight today: `Perception.has_line_of_sight` is a physics ray (needs a scene); gunnery uses it (gunnery.gd:220); `ElementPlan` is pure
  on dictionaries (situation `contacts` carry `visible` per ELEMENT, not per crew: element_situation.gd:16); `game/ai/cover_map.gd` is
  built to decide without a scene; `fire_lanes.gd` exists. The HUD's `attack_shortfall` (rts_controls.gd:3372) says NOT FIRING when
  the crew is in distance-range, still, with the target visible to the team; `_moving_round` reads "carrying out" for a `move` /
  `attack_move` whose order names the target.
- The CPU's elements run the same `_engage`: whatever you ship makes the CPU smarter too (memory: *smart AI on both sides*; symmetric
  improvements ship without asking). `native/src/decide_native.cpp` twins the crew brain's decide, not ElementPlan (grep found no
  `_engage` twin); if E1's fix lands in `order_controller.gd`, ask native (via the orchestrator) whether that seam is mirrored.

## Backlog (in order)

1. **E1 replay his recording and name the mechanism (report first).** Rebuild the situation at ticks 3240-4350 (the recording, or
   `make skirmish ARENA=locks SEED=49326` and his two orders) and say, with ticks, who held Spears2_3 still: the plan's order each tick,
   the executor's `close` and `engaged_target`, the mover's state, the HUD's reason. Send the table to the orchestrator before building.
   Write the failing test first: a hand-built situation (a crew in distance-range, a box between it and the target) that today gets
   `attack` and must get a move for a shot.
2. **E2 the rule, OFF behind `--attack-shot` (ON when its bar passes; `=off` = round 41).** "In range" = distance AND a clear line of fire
   from the crew's gun to the target. A crew in distance-range without a shot gets a **firing position**: the nearest reachable spot
   within its range with a clear line, on the enemy's side of the obstacle (toward the enemy, never away unless nothing nearer exists),
   not on a friend's spot, as `attack_move` toward it with the target named (so the HUD reads "carrying out"). Hysteresis so it doesn't
   dither between two spots; a crew whose target has no such spot within a bounded search keeps closing straight (today). Line-of-fire
   reads reach pure code through the situation builder (element_situation.gd: an additive per-member field, built once a plan tick) so
   the planner stays testable without a scene; name the per-tick cost (rays per member per plan tick) and keep it bounded. The executor's
   own `attack` branch gets the same truth (a crew is `close` only when it can actually hit), traced from E1. Fixed-mount hulls face.
3. **E3 the HUD words (C42.6, GRANT).** While a crew drives for a shot the banner reads nothing (or MOVING FOR A SHOT); NOT FIRING is
   kept only for a crew that stands with a clear shot and doesn't fire (a bug, not a state). Test the strings.
4. **E4 Bar E1, filed before any number on 9601-9648.** Workload: a probe of his case (`tests/engage/`): on locks / terminus / crossing,
   2-5 crews ordered to attack a target 20-40 m away behind a container or building, crews starting on both sides of the cover; CPU
   fights for the guards (the CPU runs the same plan). Deciding (paired by seed, pooled): crew-seconds under an attack order in
   distance-range with no shot and not moving (ON <= 0.25 x OFF AND paired mean < 0 by >= 2 se); seconds from the order to the crew's
   first hit (ON < OFF by >= 2 se). Guards (filed first): deaths of crews moving for a shot <= OFF + 1.645 se (exposure); never-reached
   firing spots reported; fight lines G1-G4 (the wedge trace / `guard_line.gd`, 9625-9648, CPU v CPU, both sides) within OFF +/- 1.645
   se; a dither count (spot changes per crew per order) reported with a cap; sim-baseline moves adopted with the reason; the whole
   suite ON (C31.1) before the series. A pass ships ON.
5. **E5 stretch:** CAN'T SEE TARGET under an attack order gets the same move (a spot from which the team can see it); the orbit drill's
   and `_hold`'s distance tests get the same truth if E1 shows them in his case.

## How to verify

Pure tests on hand-built situations (`tests/tactics/test_engage*.gd`); the probe; the replay of his recording's situation; `make
quick-remote` per step; a full check of every hash you name. Smoke like a player: `make skirmish ARENA=locks SEED=49326` (his seed),
select two Rat Rods, attack a Missile Ring behind a container: the far crew drives round and fires; the banner never sits on NOT
FIRING. Screenshots at desktop and phone aspect; look at them.

## Don't touch

Settle's functions in `element_plan.gd` (deploy-step, halt-lay, seat-deal), `game/ai/movement.gd` / `traffic.gd` (manoeuvre),
`game/camera/**`, `game/units/**` numbers (balance), `native/**`, `tests/baselines/**` (the orchestrator adopts). Don't push.

## Waiting on the lead

Nothing.

## Status

**2026-10-26 ~19:10 PDT (Fable). BAR E1 PASSED (R42.13); `--attack-shot` is ON BY DEFAULT at f9b675a56** (`=off` / env
ATTACK_SHOT=off = round 41). E1 DONE (the mechanism, below); E2 built and shipped; E3 DONE (the HUD's words); E4 = Bar E1
(below: deciding lines z -3.6 and -3.9, the guards within their bands, G3 ruled on the paired mean, R42.13); E5 (cheap half)
done; R42.10 (the flank side) shipped with the rule. **MERGE CANDIDATE: 76f43fb6d** (the flip f9b675a56 + the 9 adopted
baselines): its DEFAULT check (now ON) on builder0 is GREEN: `>> remote: make check exited 0`, `3303 passed, 0 failed`,
`sim-baseline: 53 passed, 0 failed`, perf-judge `JUDGED, PASS on attempt 1 of 3` (9522 usec per reference ms v 25840); the
synced tree verified = 76f43fb6d by md5 of the files later commits touch (done 20:16 PDT after 1167 s behind camera's lock).
**Now: v2** (the SUPPRESS stand's own-line guard, R42.12) built OFF at eb4024fe3, labbed on 7001-7012, Bar E2 filed and recorded
(R42.14, below); in flight: its suite-ON check (`check ATTACK_SHOT_SUPPRESS=on`) then its series on 9649-9672 (builder0's light
lane, `engage-bar2`, one chained script `scratchpad/engage-e2.sh`); then the guard window asked for once. The flag-ON checks: 4658fa514 green by the filing's terms (`3303 passed,
0 failed`, `27 passed, 1 FAILED` = sim-baseline's 9 maps; perf-judge PASS, 9510 usec per reference ms); 57e2e7eb5 (16:40)
exit 2 with far_ambush red -> R42.10.

**Launching (a trip-up for the next agent):** `make remote T=...` rejects `' " ( ) ; & | \` $` in T, so a quoted seed list
cannot go through it; call `tools/remote.sh [--light] <target> 'VAR=a b c' VAR2=x` directly (and `REMOTE_HOST=slobdell@builder2`
in the environment for builder2: `make gcp-remote` is the same `make remote`). The light lane's results land in
`build/light/build/` (copy them out before the next copy-back).

**Player smoke (laptop, 57e2e7eb5, `tests/engage/engage_shots.gd`, his pose, desktop 1920x1080 and phone 1200x540, frames at
0/1/3/8/20 s in `build/engage/shots/`, copied to the scratchpad):** OFF: the Rat Rod sits nose-on behind the blue container all
20 s, gun on nothing, 26.1 m out. ON: at 1 s it is at 19.1 m with its gun on the ring and the ray clear; at 3 s it stands past
the container's end at 17.8 m, "holding at standoff", and the ring's damage reads 47 by 3 s and 1555 by 20 s (OFF: 632, all
from the squadmate). Looked at: desktop_off_08s, desktop_on_08s, phone_on_03s. (A lab, so no HUD banner in the frame: the banner
words are pinned by test_engage_hud_words.)

### Done (every number: commit, machine, workload, n)

- **E1 (3848c229e).** `tests/engage/replay_probe.gd` rebuilds his crew (laptop, Locks seed 49326, the census's places, 40 s, n 1,
  deterministic): OFF = still 39.8 of 40 s, moved 0.3 m, ends 26.1 m out, no hit of its own; **ON (7322318a3) = drives round in
  1.5 s, fires from 17.8 m from tick 31 (0.8 s after the order), the target's damage 1459 -> 3209.** Mechanism: *E1 report* below.
- **E2 (7322318a3, OFF).** (a) `ElementSituation.shots_into`: each member's `shot` {contact: bool} for the SHOT_CONTACTS (6) nearest
  contacts within range x 1.15 + 15 m, from the cover map's `clear_line` (pure, memoized at 0.5 m), once a plan tick. Cost: the
  probe reads **3.7 lines per plan tick** for a 2-5 crew squad v one target (12 seeds, laptop). (b) `ElementPlan._engage`: `attack`
  only in reach AND with a shot; in reach without one -> `FiringPosition.find` -> a `move` to the spot naming the target (its slot,
  so it carries back for hysteresis); no spot in the bounded search -> keep closing (`attack_move` toward, target named).
  (c) `game/tactics/firing_position.gd` (pure): 4 rings x 24 directions round the target at 0.9/0.75/0.6/0.45 of the crew's
  effective range (inside the band the brain holds at), inside the arena, standable (STAND_CLEARANCE), a clear line, not within
  5 m of a friend or a dealt spot, within 45 m of the crew; cost = drive + 12 m if the straight line crosses a feature + 20 m if
  farther from the target than the crew stands; the previous spot kept within 8 m of the best. (d) **R42.2 GRANT, `TankBrain._act`
  ENGAGE:** `own_line` from the cover map (`clear_line`, the plan's read, so the two agree at the same quantum); blocked -> the
  not-visible branch (`_move_to(contact.position)`, "no line of fire: going round"). OFF: byte-identical to main.
  **Decision (why a `move`, not the brief's `attack_move`):** under an attack-move the brain fights a target the TEAM sees from
  where it stands (E1's ticks 6-470: ENGAGE outscored MOVE for 15 s), so the spot would never be driven to; a named move lays the
  gun on the target and reads "carrying out" on the HUD just the same.
- **E3 (e81c93ae8, C42.6 GRANT in `rts_controls.gd`):** `attack_shortfall`: after the visible check, a crew with no line of fire
  (the cover map; `line_of_fire` Callable for tests) reads "" while driving (going for a shot) and **NO LINE OF FIRE** standing;
  **NOT FIRING** only with a clear shot. `_moving_round` unchanged. `tests/engage/test_engage_hud_words.gd` pins the strings.
  (Merge note: one new var `line_of_fire` and one helper beside `engaged_of`; the two lines of wording.)
- **E5 (e81c93ae8, cheap half):** `_hold`'s attack, the orbit drill's in-range and the flank line's crew-reach read take the same
  `has_shot` truth under the flag (a covering crew without a line holds its spot; a ring crew keeps going round).
- **R42.10 (4658fa514, GRANT, gated under ATTACK_SHOT): the maneuver half flanks on the side with room.** The suite-ON check
  at 57e2e7eb5 turned far_ambush red. Traced (`tests/engage/far_ambush_trace.gd`, laptop, identical numbers to builder0): under
  ON, A_3 (no line to Gun_2 for ~20 ticks of react to contact) got a firing-spot move 3 m west of where OFF's `attack` took it;
  `_plan_fire_and_maneuver` picks the flank side by the sign of (maneuver centre - focus) . right, the maneuver half straddles
  the line of contact there (margin ~3 m), the sign went west, and the lane (x -98) is 17 m from the arena edge: the flank
  point was clamped onto the wall, "swing" 17.0 m (OFF happens to pick east: 73.3 m). The fight was also won 8 s sooner ON
  (both guns dead at tick 447 v 697). A knife-edge pick that was there before; a flank into a wall is wrong in either arm.
  Fix: `ElementPlan.flank_side` (pure): the sign's side unless the arena clamps its flank point further than the other
  side's (one side into a wall -> the other; both -> the one moved less). OFF unchanged (option b: no OFF baseline moves before
  the flip). `tests/tactics/test_engage_flank_side.gd` (4: OFF pinned wall-and-all, the stage ON goes > 20 m east to an
  unclamped flank, both clamped -> the less moved, the function pure). Laptop, all drills ON: failures 0.
- **Tests:** `tests/tactics/test_engage_shot.gd` (6: the read, today's `attack` pinned as the control, the spot's properties, the
  spot kept, no spot -> closing, find pure and bounded), `tests/engage/test_engage_hud_words.gd` (2). `mk/engage.mk`: engage-replay,
  engage-probe, engage-bar, engage-parse.
- **Dev read (laptop, b37e7f4a4, `tests/engage/attack_shot_probe.gd`, 7001-7012, 60 s, n 12 paired, NOT a bar number):** stuck
  crew-seconds OFF 314.9 -> ON 29.9 (paired mean -23.8 a run, se 10.0, z -2.4); first hit 9.0 -> 3.8 s (mean -5.2, se 2.0);
  crews that never hit 14 -> 6 of 42; deaths 7 = 7, none while moving for a shot; firing-spot dither 0; spots never reached 0; line
  flips 0.9 -> 1.2 a crew (reported). Sizing from it: stuck's paired sd ~36 a run v a 23 s effect -> n 15 decides it (80 % / 5 %);
  first hit sd ~7 v 5 s -> n 13; **24 seeds decide both.**

### E1: who held Green_Spears2_3 still (report, 3848c229e)

**Rebuilt** with `tests/engage/replay_probe.gd` (Locks, seed 49326 spawns, the census's places: his crew at (44.3, -74.4) with
17 hp, Spears2_4 at (46.4, -95.1), the Missile Ring at (24.3, -91.7) held alive, the squad given his attack task; laptop,
18982e8df + the probe, 40 s, one run, deterministic). **Result: still 39.8 of 40 s, moved 0.3 m, ended 26.1 m from the
target, zero hits of its own** (the ring's 1459 damage came from Spears2_4). The same picture as his 37 s.

| ticks (probe) | the element issued | the brain chose / why | brain move | mover | gun on | own ray | cover map | team sees | HUD |
|---|---|---|---|---|---|---|---|---|---|
| 2-3 | `move` to its echelon slot (32.2, -87.8) | MOVE, "ordered" | move_to slot | driving | - | blocked | blocked | no, then yes | CAN'T SEE, then NOT FIRING |
| 6-470 | `attack_move` naming the target (near_ambush, then assault_through: slot 50 m off at (-5.9, -108.8)) | ENGAGE on it, "holding at standoff" | **stop** | **arrived** | "" | blocked | blocked | yes | "" (reads as moving round) |
| 471-1200 | `attack` (react_to_contact, then none: `_engage` by distance, 26.1 <= 30 x 1.15) | ENGAGE on it, "holding at standoff" | **stop** | **arrived** | "" | blocked | blocked | yes | **NOT FIRING** |

**The chain, in code:**
1. `ElementPlan._engage` (element_plan.gd ~3250) hands it `attack` by distance alone (26 m <= 34.5 m); the drills' `attack_move`
   before that named the target too. Neither tests a line of fire (the orchestrator's hypothesis, confirmed). But that is not
   what stops the hull:
2. **`OrderExecutor` is dead code.** `TankBrain.EXECUTES_ORDERS` is true (tank_brain.gd:15), so the executor steps aside in its
   `_ready` (order_executor.gd:37) and the `attack` branch at :126 never runs (left untouched, R42.2). The crew's own brain
   executes his order.
3. `TankBrain._obey` (tank_brain.gd ~1833): the ordered target is "fresh" through the TEAM's intel (Spears2_4 sees it), so the
   only candidate kept is ENGAGE on it; under the drills' `attack_move` the target counts as "met on the way" (`in_reach`:
   team-visible and within range + 10 m), so ENGAGE outscores MOVE and the crew never drives to the assault slot either.
4. `TankBrain._act` ENGAGE (tank_brain.gd ~2573): `contact["visible"]` is the team's read, not this crew's eyes; visible and
   within range + 15 m means `_combat_move`, whose gunlay planner (`CombatMotion.plan_lay`, combat_motion.gd ~1236) scores a
   gear-0 "hold" on aim and turning room only, with NO sight test from the hull, so it answers hold: "holding at standoff"
   (tank_brain.gd ~3283) and the move order is `stop`.
5. `Gunnery._shootable` (gunnery.gd:220) needs the physics ray; it is blocked by the 20-ft container at (42, -80) (the cover
   map agrees, `clear_line` false), so `engaged_target` stays "" and the fixed mount never even turns.
6. Movement under `stop` reports `arrived` (the census's phase).
7. The HUD (rts_controls.gd `attack_shortfall`): gun on nothing, verb `attack` (not "moving round"), the team sees the target,
   26 < 30 m, standing still: NOT FIRING. Under the drills' `attack_move` the same crew read as carrying the order out for 15 s.

**So "in range" was wrong twice:** the squad plan sends `attack` by distance, and the crew brain HOLDS by distance (the team's
sight, the gunlay's aim), while the gun needs a line the hull does not have. E2 lands in both (symmetric: the CPU's crews run
the same brain and plan). **Seen in the dev read, not fixed (outside the GRANT):** under an attack order a crew may pick SUPPRESS
and stand in band with no line (7001 ON, 7.8 s: "suppressing Rust_T_1" into the container); the stuck line counts it. If Bar E1
reads it as material, the seam is `_act` SUPPRESS's stand (same guard) or `CombatMotion.plan_lay`'s hold (in reserve, R42.2).

### Bar E1 (FILED b37e7f4a4, 2026-10-26 ~15:50 PDT, before any number on 9601-9648)

**READ, the deciding series (builder0 LIGHT lane, native off, commit 5e9518da0 = 4658fa514's code, `engage-bar` 9601-9624,
n 24 paired, 60 s windows, J4, 18:24-18:26 PDT; the table `tests/engage/attack_shot_table.py --pair`):**

| line | OFF | ON | paired mean | se | z | reading |
|---|---|---|---|---|---|---|
| 1 stuck crew-s (sum) | 598.4 | 28.8 | -23.7 | 6.6 | -3.6 | DECIDING: 0.048 x OFF, < 0 by 3.6 se -> **PASS** |
| 2 first hit s (mean a run) | 13.5 | 4.0 | -9.4 | 2.4 | -3.9 | DECIDING: by 3.9 se -> **PASS** |
| 3 deaths while moving for a shot | 1 | 0 | -0.04 | 0.04 | -1.0 | GUARD -> **PASS**; all deaths 39 -> 31 (mean -0.33, se 0.30) |
| 4 spots never reached | 0 | 2 | | | | reported (9607, 9609: one crew each); dither 0.00 both arms (cap 2.0: within); line flips 1.20 -> 1.25 a crew |
| 8 cost: lines a plan tick | 0.00 | 3.35 | | 0.25 | | <= crews + 1 (mean crews 3.8 -> 4.8) -> **PASS**; perf-judge PASS (above) |
| 9 SUPPRESS share of ON's stuck | 15.0 of 598.4 (3 %) | 23.3 of 28.8 (**81 %**) | | | | REPORTED (R42.6): most of what is left is the brain's SUPPRESS stand -> a real result; v2 on R42.2's terms |
| also | never hit 32 -> 14 of 91 crews; target dead by 36.6 -> 26.9 s (mean -9.6, se 4.3); hits 3195 -> 3301 | | | | | |

Lines 6 and 7 read above (the 9 maps; the suite ON green at 4658fa514).

**Line 5 READ, the fight guards (builder2, native on, commit b08d54df3 = 4658fa514's code, `native guard-run` kinds none, green
side, locks, 9625-9648, 600 s, J8, n 24 paired, 18:33-19:00 PDT; `tools/scoreboard/guard.py --pair`):**

| guard | OFF | ON | paired diff | se | band 1.645 se | reading |
|---|---|---|---|---|---|---|
| G1 green kills a fight | 18.96 | 19.79 | +0.83 | 1.24 | 2.03 | **PASS** |
| G2 green losses a fight | 18.62 | 18.54 | -0.08 | 0.99 | 1.63 | **PASS** |
| G3 fight length | arm medians 181.0 / 193.4 | | +12.4 (medians) / **+4.8 (paired mean)** | 7.05 | 11.6 | medians: outside by 0.8 s (z 1.76); paired mean (judging.md's form for this line, "read as a mean"): z 0.69, median of diffs 0.0, 9 longer / 9 shorter / 6 identical, end reasons 15 control / 9 elimination both arms -> **ruling asked (R42.12 thread)** |
| G4 green kill ratio | 1.02 | 1.07 | +0.05 | 1.47 | | **PASS** |
| G5 no SCRIPT ERROR / missing result | 24 of 24 | 24 of 24 | | | | **PASS** |

**RULED (R42.13): G3 passes on the paired mean (judging.md line 114's form for this line); the tool's median-v-mean's-se
reading is recorded beside it as the tool's mismatch, not the bar's. Bar E1 PASSES; shipped ON at f9b675a56.**

Per faction (reported): condemned losses 21.0 -> 17.7 (se 1.5), gangs kills 6.6 -> 8.8 (se 1.8), syndicate median +20 s
(se 17). The largest length diff is 9625 (+95.6 s: elimination at 120 s OFF -> the control clock at 216 s ON; kills 27 -> 26,
losses 3 -> 8); without it the mean is +0.9 s (se 6.1). Why the medians step: half the fights end on the control clock in a
cluster at 193-195 s, and the median jumps between that cluster and the eliminations below it. Per-seed table:
`scratchpad/guards/pair.txt` + the two `guards-<arm>/none/locks-<seed>-green.log` sets (copied out of build/).
What is left of stuck under ON is 9609 (13.7 s) and 9619 (10.5 s), both gang_ifv squads v a target that kills the whole
squad (tdead 60 = never died, deaths 4 of 4): crews in SUPPRESS in band with no line while dying. The never-reached spots:
9607 and 9609, one crew each (below). Four seeds (9601 9605 9607 9614, all crossing) carry STAGE-OFF (the stage's grounding
moved a hull off its drawn spot); paired, same stage both arms.

**Switch:** `--attack-shot` (DEFAULT OFF at filing; a pass ships ON with `=off` = round 41). **Tree:** 4658fa514 frozen for every
arm (was 57e2e7eb5 = e81c93ae8 + the read gated behind the flag + the probe, the table and the shot tool; moved to 4658fa514 on
R42.10's flank side pick after the suite-ON check at 57e2e7eb5 turned far_ambush red, before any number on 9601-9648 was read;
the lines below are unchanged). OFF asks the cover
map for nothing (probe 7001: 0 lines OFF, 210 ON). **What it could break (round 37's rule):** a crew that leaves its standoff
to close may die in the open (the exposure guard); a crew whose spot is unreachable, or whose line flickers at a corner, may
oscillate (the dither count, the line flips, spots never reached); a CPU fight where crews now close instead of holding may
change its kills, losses and length (the fight lines); the sim-baseline rows move (expected: adopted with the reason).

**Deciding (paired by seed, pooled; `tests/engage/attack_shot_probe.gd` via `make engage-bar`, 9601-9624, n 24, 60 s windows,
builder0 light lane, the arenas locks / terminus / crossing by seed, 2-5 crews (fixed guns 5 of 6 draws, his case), the target
behind a container or block 18-42 m away, one crew with a clear line from the start):**
1. **Stuck crew-seconds** (under the attack order, in distance-range, no line by the cover map, not moving; sum a run):
   ON <= 0.25 x OFF AND the paired mean < 0 by >= 2 se. (Sized: dev sd ~36 a run, effect ~23 -> n 15; at n 24 the se of the
   mean is ~7.)
2. **Seconds from the order to each crew's first hit** (never = the window, 60 s; mean a run): ON < OFF by >= 2 se.
**Guards (filed first):**
3. **Exposure:** crews that die while moving for a shot (moving, no line, under the order; sum over the series): ON <= OFF +
   max(1.645 se, 2 crews) (the floor because the dev read has 0 in both arms: a 0 se is no guard). All deaths: ON <= OFF +
   1.645 se, reported either way.
4. **Spots never reached:** reported with their count; **dither:** firing-spot changes a crew an order (mean a run) reported,
   cap 2.0; **line flips** a crew reported.
5. **Fight lines G1-G4** (`make guard-run GUARD_KINDS=none GUARD_SIDES=green GUARD_AT=locks GUARD_SEEDS=9625..9648`, 600 s,
   CPU v CPU both sides, 24 fights an arm, `tools/scoreboard/guard.py --pair`; builder2 when free, else builder0 light):
   G1 green kills a fight, G2 green losses a fight, G3 the match length (median), G4 green's kill ratio: each ON within OFF
   +/- 1.645 paired se. **G5:** no fight ends in a SCRIPT ERROR or a missing GUARD_RESULT.
6. **Sim-baseline:** rows that move under ON listed with the reason (the rule acted); adopted at the ship by the orchestrator.
7. **The whole suite ON (C31.1):** `make remote T="check ATTACK_SHOT=on"` on the frozen tree before the series: every test
   passes (the baseline rows excepted, 6). At 57e2e7eb5: 3297/0 unit tests, far_ambush red -> R42.10; rerun on 4658fa514.
8. **Cost (the ray budget, named before the series):** cover-map lines a plan tick in the ON arm, mean over the series, <= crews
   + 1 (one line a member a target; the probe has one target; dev 3.7 at a mean 3.6 crews); by construction never more than
   SHOT_CONTACTS (6) x members an element a plan tick, memoized at 0.5 m; and the ON check's perf-judge reads PASS on its own
   line. OFF: 0 lines.
9. **SUPPRESS share (pre-registered, R42.6):** the share of ON's stuck crew-seconds spent in the brain's SUPPRESS is a reported
   column (`stuck_suppress`); if it is most of what is left, that is a real result and the SUPPRESS stand in `_act` gets the
   same own-line guard as a v2 on R42.2's terms (plan_lay the second reserve).
**A pass ships ON** (every deciding line and guard); the plan_lay seam stays in reserve (R42.2).

### Decisions

- A `move` (not `attack_move`) to the firing spot (above). The brain's own line read uses `clear_line` (0.5 m) rather than
  `clear_line_coarse` (2 m) so the brain and the plan agree at a corner (native: calling either is free; nothing twinned changed).
- SHOT_CONTACTS 6 nearest contacts in reach a member: bounded cost; a contact beyond the read is "no read, no refusal".
- The stage's hulls: five fixed mounts to one gun truck (his case is a fixed gun's hold; a turret circles and is seldom held).

### The order from here (R42.12, the orchestrator)

1. The fight guards G1-G5 on builder2 on its "go" (balance pausing at a leg boundary): `scratchpad/engage-guards.sh` = OFF then
   ON, `native guard-run GUARD_DIR=build/guards-<arm> GUARD_KINDS=none GUARD_SIDES=green GUARD_AT=locks GUARD_SEEDS=9625..9648
   GUARD_JOBS=8 GUARD_SECONDS=600 GUARD_ARGS=[--attack-shot=on]`, read with `tools/scoreboard/guard.py --pair`.
2. The reading of Bar E1 (lines 1-4, 6-9 above: PASS / reported; line 5 from the guards).
3. A pass: the default flip ON (`--attack-shot=off` / `ATTACK_SHOT=off` the escape), then the OFF (= default) check of the
   merge candidate (`make remote T=check`); name both hashes (the flag-ON check's 4658fa514 and the merge candidate's).
   **DONE: the flag-ON check 4658fa514 (green by the filing's terms), the merge candidate 76f43fb6d (default check green, exit 0,
   3303/0, sim-baseline 53/0, perf-judge PASS; builder0, 20:16 PDT).**
4. **v2 (granted on R42.2's terms, built OFF, AFTER the flip, not in this bar):** the same own-line guard on the SUPPRESS stand
   in `_act` (81 % of ON's remaining stuck seconds, above); labbed on dev seeds 7001-7012; its own bar on fresh 9649-9672,
   filed before any number.

### v2: the SUPPRESS stand's own line (R42.12; built OFF at eb4024fe3, after the merge candidate 76f43fb6d)

`TankBrain.SUPPRESS_LINE` (`--attack-shot-suppress=on`, env ATTACK_SHOT_SUPPRESS=on): the in-band SUPPRESS stand (a face, or
a stop when already facing) becomes a move toward the target when the cover map says the crew's own line is blocked, as
ENGAGE's hold does under --attack-shot (`_own_line_to`, shared; ENGAGE's read unchanged; `line_of_fire` Callable seam for
tests). OFF: the stand as before. Test: `tests/tactics/test_engage_suppress_line.gd` (2: both arms, both lines, the act step
on a built situation). The probe takes `--hull= --target=` and `ENGAGE_TAG` names its folder.

**Dev lab (laptop, eb4024fe3, `engage-probe` 7001-7012, `--hull=gang_ifv --target=ifv`, --attack-shot ON both arms, 60 s,
n 12 paired, NOT a bar number):** stuck_suppress 6.5 -> 0.0 s (one seed carried all of it: 7008, locks, gang_ifv v ifv, 3 crews, Green_E_2: stuck 7.2 s of which 6.5 in SUPPRESS, first hit 15.2 s OFF), stuck
8.4 -> 1.6, first hit 2.91 -> 2.73 s, deaths 20 = 20, none moving, dither 0, hits 3047 -> 3093, target dead by 26.1 = 26.1,
lines a plan tick 3.47 -> 3.50. The stand is RARE (1 of 12 dev seeds; 2 of 24 in Bar E1's series) and mechanistic (the sim
is deterministic: where it happens, ON removes it), so a 2-se line on the paired mean cannot decide it at n 24 (k seeds of n
with the effect give z ~ sqrt(k)): v2's bar is filed with a dominance line (below), and an "exercised" floor.

### Bar E2 (v2; FILED 10262d932 / code eb4024fe3, 2026-10-26 ~19:50 PDT, before any number on 9649-9672)

**Switch:** `--attack-shot-suppress` (OFF at filing; a pass ships ON with `=off`). **Arms:** OFF = today's default (--attack-shot
ON, the merge candidate 76f43fb6d's rule); ON = + `--attack-shot-suppress=on`. **Tree:** eb4024fe3's code frozen for both arms
(abe954fc8 / 10262d932 are mk + Status). **What it could break:** a crew that leaves a suppressing stand to go round may die
in the open; a crew whose line flickers may dither; the squad loses the pin's effect while it moves (first hit, deaths).
**Workload:** `engage-probe` on 9649-9672, the natural draw (hull/target by seed, as E1), 60 s windows, builder0's light
lane J4, n 24 paired, `attack_shot_table.py --pair --deciding=suppress`.

**Deciding:**
1. **SUPPRESS stuck crew-seconds** (`stuck_suppress`, sum a series): ON <= 0.25 x OFF, AND no seed worse (ON <= OFF + 0.5 s
   on every seed). The effect is sparse and mechanistic (the sim is deterministic per flags: where the stand happens, ON removes
   it), so a 2-se line on the paired mean cannot decide it at n 24 (k seeds of n carrying it give z ~ sqrt(k); E1's series:
   2 of 24, the dev lab 1 of 12): a dominance line instead, with an **exercised floor: at least 3 seeds with OFF >= 2 s**;
   fewer -> NOT EXERCISED: extend with 9673-9696 (the two sets pooled as one n 48 series, same lines); still fewer than 3
   -> INCONCLUSIVE, no ship, written up.
**Guards (filed first; paired se as E1):**
2. **All stuck crew-seconds:** ON <= OFF + 1.645 se (v1's win holds).
3. **Exposure:** deaths while moving for a shot ON <= OFF + max(1.645 se, 2 crews); all deaths ON <= OFF + 1.645 se.
4. **First hit** (mean a run): ON <= OFF + 1.645 se (not worse); **never hit** reported.
5. **Dither** cap 2.0 a crew an order; **spots never reached** and **line flips** reported.
6. **Cost:** lines a plan tick ON <= OFF + 0.5 (the stand's read is the memoized map, the same quantum); the ON check's
   perf-judge PASS on its own line.
7. **Suite ON (C31.1):** `make remote T="check ATTACK_SHOT_SUPPRESS=on"` on the frozen tree before the series: every test passes
   (sim-baseline rows excepted, listed with the reason; adopted at the ship).
8. **Fight guards G1-G5** as E1 (24 x 600 s, locks, kinds none, green side, builder2 on the orchestrator's word), **seeds
   9697-9720 (R42.14); the extension set for line 1 is 9673-9696.** The hand-over to balance costs it a leg: ask for the
   guard window once, when the series is read.
**A pass ships ON** (line 1 decided, 2-8 within). **Recorded on main as R42.14** (the dominance form accepted). The table:
`attack_shot_table.py --pair OFF ON --deciding=suppress` (7a8f7fb2e).

**READ, line 7 (the suite ON; builder0, dcf83c66a = eb4024fe3's code, native on, 20:18-21:50 PDT, the box at load 4-12 with
"12 other godot" and main's batch check queued):** `>> remote: make check ATTACK_SHOT_SUPPRESS=on exited 2`, `3304 passed,
1 failed`, `24 passed, 2 FAILED, 0 NOT RUN, 2 NOT JUDGED`. The two FAILED: **sim-baseline** (expected: 6 maps move under the
stand's line: foundry, pit, sumps, gorge, archipelago, cut; yard, terminus, crossing, locks, parade, docks, yard_open unmoved;
adopted at the ship) and **test** = one wall-clock test, `test_announcer_cost::test_the_booth_costs_well_under_a_tenth_of_a_millisecond_a_tick`
(booth tick 0.3403 ms mean v its 0.3 ms line; the test times the booth alone with `Time.get_ticks_usec` and nothing in
the booth reads the flag: `SUPPRESS_LINE` is read on one line of `TankBrain._act`'s SUPPRESS branch and nowhere else). The
NOT JUDGED: **perf-judge** (`refused 3 times (ratios 1.45x 1.45x 1.38x 1.38x 1.25x 1.25x) in 86s: the box was truly busy`)
and ai-scenarios-check's scenario_perf (always: perf-judge judges it). **To close line 7 and line 6's perf-judge:** rerun
`make remote T="test FILTER=announcer_cost ATTACK_SHOT_SUPPRESS=on"` and `make remote T="perf-judge ATTACK_SHOT_SUPPRESS=on"`
on a quiet builder0 (after the series and main's batch check); the 3303 other tests at the flag stand as read.
**main:** the orchestrator merged 76f43fb6d alone as **9405f4dfb** (--attack-shot ON on main; v2 not in it).

**READ, lines 1-6 on 9649-9672 (builder0 light lane, native off, dcf83c66a = eb4024fe3's code, n 24 paired, 60 s, 21:49-21:52
PDT; `scratchpad/series2/pair_table.txt`):** the two arms are BYTE-IDENTICAL on every seed. **Line 1 NOT EXERCISED:** stuck_suppress
0.0 = 0.0 (0 of 24 seeds with OFF >= 2 s; the floor is 3). The rest, reported: stuck 4.6 = 4.6 crew-s, first hit 9.48 = 9.48 s,
never hit 18 = 18, deaths 30 = 30 (none moving), never reached 0, dither 0, line flips 1.26 = 1.26, hits 2655 = 2655, target
dead 30.53 = 30.53 s, lines a plan tick 2.96 = 2.96. The draw: gang_scout 10, law_scout 9, gang_ifv 3, scout 2, on terminus /
crossing / locks; no seed put a crew on a blocked SUPPRESS stand (E1's series had 2 of 24 with the stand, its ON arm). The ON arm's
recipe verified by `make -n` (`--attack-shot=on --attack-shot-suppress=on` on the probe's command line; the probe's json does not
record the second flag). **The extension 9673-9696 is running** (started 21:53 PDT, same lane, the pooled n 48 table in
`scratchpad/series2pool/`): fewer than 3 exercised seeds in the 48 -> INCONCLUSIVE, no ship, written up. **The guards are held**
(builder2 to balance's B7) until the pooled table exercises the line: 48 fights for a bar that cannot ship would be waste.
**R42.19 (the orchestrator):** extend to n 48 as filed, no guards before the line is exercised; fewer than 3 in the 48 -> E2 written
up INCONCLUSIVE with the evidence and a proposal for how a later bar would force the case, and the round is done.

**For the record, how a later bar would force the case (a staged probe with a SUPPRESS-prone draw):** the stand needs three
things at once that the natural draw rarely gives together: a gun that cannot kill its target quickly (E1's two seeds and the
dev lab's one were all gang_ifv squads v an ifv; `--hull=gang_ifv --target=ifv` is already a probe flag), a crew in the
SUPPRESS band [10, 28] m of the target, and a feature on that crew's own line while a squadmate's line is clear (so the
element holds the attack and the brain's choice is SUPPRESS, not a move). The probe stages crews at STAGE_MIN..STAGE_MAX m
and draws the feature between: a `--stage=suppress` mode would place one crew of three INSIDE the band behind the feature
(its line blocked by the map, checked with CoverMap.clear_line at placement, re-drawn until true) and the other two in the
clear at 20-28 m, hull gang_ifv v ifv, on locks / crossing (the maps the stand showed on). Then every seed exercises line 1
by construction and the bar's deciding line can be the paired mean on stuck_suppress at n 24 (z, not dominance), with the
natural-draw series kept as the "does it cost anything where it never fires" guard (lines 2-6 at identity, as read here).
The mechanism itself is pinned today by `tests/tactics/test_engage_suppress_line.gd` (both arms, both lines, the act step).

### Requests to the orchestrator

- **builder2** for the fight guards (24 x 600 s fights x 2 arms, J8) when balance's series is done; until then they wait (the
  light lane would take ~3 h serial). Say when.
- At the ship: adopt the sim-baseline rows the ON check moves (listed in Status when read).

### Known issues

- SUPPRESS under an attack order can stand in band with no line (above; outside the GRANT; measured by the stuck line).
- The flank side pick is a knife-edge when the maneuver half straddles the line of contact (far_ambush's stage: ~3 m); R42.10
  keeps it off walls under the flag but does not latch it. OFF today can still flank into a wall (test_engage_flank_side pins
  that as the control). Worth a latch in a later round if a drill flips side mid-swing.
- A target the team sees but the cover map calls blocked while the physics ray is clear (a feature lower than eye height is not
  in the map's lines; hull-down cover): the plan sends a spot the gun did not need. Not seen in 12 dev seeds.

### What to playtest

`make skirmish ARENA=locks SEED=49326 SKIRMISH_FLAGS="--attack-shot=on"`: select two Rat Rods, attack a Missile Ring behind a
container; the far crew drives round and fires; the banner never sits on NOT FIRING (NO LINE OF FIRE at most, briefly). The
OFF arm is the same without the flag.

### Merge notes (shared-file edits)

- `game/ai/tank_brain.gd` `_act` ENGAGE: the R42.2 GRANT branch only (own_line; `cover_map` is a fresh `CoverMap.of(tank)`).
- `game/control/rts_controls.gd`: `line_of_fire` var + `_has_line_of_fire` + the two wording lines in `attack_shortfall`.
- `game/tactics/element_situation.gd`: additive `preferred_min` and `shot` member fields; `shots_into` static.
- `game/tactics/element_plan.gd` `_plan_fire_and_maneuver`: two lines under `if ATTACK_SHOT` + the pure `flank_side` (R42.10).
- `order_executor.gd` untouched (unreachable under EXECUTES_ORDERS).
