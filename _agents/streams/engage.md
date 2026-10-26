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

**2026-10-26 evening (Fable, builder0 light lane / laptop).** E1 DONE (the mechanism below, replayed and named); E2 in progress.

### Plan (in order)

1. E1 replay + failing test (done; the report below).
2. E2 `--attack-shot`: (a) the situation builder's per-member `shot` read (pure, from the situation's cover map); (b) `_engage`
   gives `attack` only with a shot, else a firing position (`firing_position.gd`, pure) as a move naming the target; (c) the
   crew brain's ENGAGE hold needs the crew's OWN line (the real executor: see E1; a GRANT request, below); (d) the orbit drill
   and `_hold` get the same truth if cheap.
3. E3 the HUD words (C42.6).
4. E4 Bar E1 filed, then run on 9601-9648.
5. E5 stretch.

### E1: who held Green_Spears2_3 still (report)

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
1. `ElementPlan._engage` (element_plan.gd:3250) hands it `attack` by distance alone (26 m <= 34.5 m); the drills' `attack_move`
   before that named the target too. Neither tests a line of fire (the orchestrator's hypothesis, confirmed). But that is not
   what stops the hull:
2. **`OrderExecutor` is dead code.** `TankBrain.EXECUTES_ORDERS` is true (tank_brain.gd:15), so the executor steps aside in its
   `_ready` (order_executor.gd:37) and the `attack` branch at :126 never runs. The crew's own brain executes his order.
3. `TankBrain._obey` (tank_brain.gd:1833): the ordered target is "fresh" through the TEAM's intel (Spears2_4 sees it), so the
   only candidate kept is ENGAGE on it; under the drills' `attack_move` the target counts as "met on the way" (`in_reach`:
   team-visible and within range + 10 m), so ENGAGE outscores MOVE and the crew never drives to the assault slot either.
4. `TankBrain._act` ENGAGE (tank_brain.gd:2573): `contact["visible"]` is the team's read, not this crew's eyes; visible and
   within range + 15 m means `_combat_move`, whose gunlay planner (`CombatMotion.plan_lay`, combat_motion.gd:1236) scores a
   gear-0 "hold" on aim and turning room only, with NO sight test from the hull, so it answers hold: "holding at standoff"
   (tank_brain.gd:3283) and the move order is `stop`.
5. `Gunnery._shootable` (gunnery.gd:220) needs the physics ray; it is blocked by the 20-ft container at (42, -80) (the cover
   map agrees, `clear_line` false), so `engaged_target` stays "" and the fixed mount never even turns.
6. Movement under `stop` reports `arrived` (the census's phase).
7. The HUD (rts_controls.gd:3372): gun on nothing, verb `attack` (not "moving round"), the team sees the target, 26 < 30 m,
   standing still: NOT FIRING. Under the drills' `attack_move` the same crew read as carrying the order out ("" for 15 s).

**So "in range" is wrong twice:** the squad plan sends `attack` by distance, and the crew brain HOLDS by distance (the team's
sight, the gunlay's aim), while the gun needs a line the hull does not have. The fix has to land in both: the plan's `attack`
needs a shot (C42.2, mine) and the brain's ENGAGE hold needs the crew's OWN line (the real "executor's attack branch").
Both are symmetric: the CPU's crews run the same brain and the same plan.

**Requests to the orchestrator:** (1) GRANT for `game/ai/tank_brain.gd` `_act` ENGAGE (:2573-2592) only: one guarded branch
behind `--attack-shot`, "a crew whose own line to its target is blocked (cover map, coarse) does not hold at standoff: it closes
on the target" (the brain already holds `cover_map`; `clear_line_coarse` is memoized). Nobody owns tank_brain.gd this round;
`_act` is not twinned natively (NativeDecide twins `decide` only; the ENGAGE branch is GDScript). Alternative seam if preferred:
`CombatMotion.plan_lay`'s gear-0 hold requires `map.clear_line_coarse(here, target)` (combat_motion.gd:1340; shared by every
fixed gun). (2) Note for the brief: order_executor.gd's attack branch is unreachable; I will not edit it.

