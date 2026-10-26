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

**2026-10-26 ~15:50 PDT (Fable).** E1 DONE (the mechanism, below). E2 built, OFF behind `--attack-shot` (quick gate green on
builder0 at 7322318a3: 169 passed / 0 failed, 631 s). E3 DONE (the HUD's words, tests). E5 (cheap half) done. **Bar E1 FILED
below at b37e7f4a4 (the frozen tree), before any number on 9601-9648.** Running: the suite ON (C31.1) `make remote T="check
ATTACK_SHOT=on"` on b37e7f4a4, builder0. Next: the deciding series on builder0's light lane once the ON check is read; the fight
guards on builder2 (busy with balance's series at filing time: a request below); the OFF check of the merge candidate; the
player smoke shots.

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

**Switch:** `--attack-shot` (DEFAULT OFF at filing; a pass ships ON with `=off` = round 41). **Tree:** b37e7f4a4 frozen for every
arm (code = e81c93ae8; b37e7f4a4 adds the probe only). **What it could break (round 37's rule):** a crew that leaves its standoff
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
7. **The whole suite ON (C31.1):** `make remote T="check ATTACK_SHOT=on"` on b37e7f4a4 before the series: every test passes
   (the baseline rows excepted, 6).
8. **Cost:** cover-map lines per plan tick reported (dev 3.7 for 2-5 crews v 1 target; bound SHOT_CONTACTS 6 a member).
**A pass ships ON** (every deciding line and guard); the plan_lay seam stays in reserve (R42.2).

### Decisions

- A `move` (not `attack_move`) to the firing spot (above). The brain's own line read uses `clear_line` (0.5 m) rather than
  `clear_line_coarse` (2 m) so the brain and the plan agree at a corner (native: calling either is free; nothing twinned changed).
- SHOT_CONTACTS 6 nearest contacts in reach a member: bounded cost; a contact beyond the read is "no read, no refusal".
- The stage's hulls: five fixed mounts to one gun truck (his case is a fixed gun's hold; a turret circles and is seldom held).

### Requests to the orchestrator

- **builder2** for the fight guards (24 x 600 s fights x 2 arms, J8) when balance's series is done; until then they wait (the
  light lane would take ~3 h serial). Say when.
- At the ship: adopt the sim-baseline rows the ON check moves (listed in Status when read).

### Known issues

- SUPPRESS under an attack order can stand in band with no line (above; outside the GRANT; measured by the stuck line).
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
- `order_executor.gd` untouched (unreachable under EXECUTES_ORDERS).
