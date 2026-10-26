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

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
