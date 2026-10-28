# Stream: engage (a crew under his attack-move keeps going for the enemy; the 20 s drive back to his own edge, found and fixed)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 43** (C43.1, C43.3, CP43.0), your round-42
> brief `streams/archive/round42/engage.md` (Status: E1's replay probe, the trace rows, the launching trip-up with quoted seed lists,
> Known issues), and `game_design.md` *His playtest after round 42*. **You own:** `game/tactics/element_plan.gd`'s engagement functions
> (`_engage`, `_hold`'s and the orbit drill's in-range tests, `ENGAGE_RANGE_FACTOR`, the crew-reach read; NOT settle's deploy-step,
> halt-lay, seat-deal), `game/tactics/element_situation.gd` (additive), `game/tactics/drills.gd`, `game/tactics/firing_position.gd`,
> `game/control/order_executor.gd`'s `attack` / `attack_move` branches, `game/ai/order_controller.gd` (trace lines; behaviour only on
> the orchestrator's ruling), trace-only lines (flag-gated, default off) anywhere on the crew's order path including
> `game/ai/planner/planner_seam.gd` (merge note), `tests/tactics/test_engage*.gd`, `tests/engage/**`, `mk/engage.mk`.
> **Model:** Fable. **Machine:** builder0 light lane (J<=4); builder2 for a series over 24 fights. **Seeds:** 10301-10324 (bar),
> 10325-10348 (fight guards); his 56416 and dev 7001-7012 never a bar.

## The lead's direction (2026-10-27 ~20:00, verbatim)

"I was paying attention to the camera, but I didn't get far before seeing that my units all seemed incapable of moving to the west
side of the map. ... My first squad of tanks was never even able to settle for a simple target destination. I don't know if this is a
regression"

On the orchestrator's read of the recording: "I want you to track that as something to investigate in the next round. I'm not sure if
it's a bug per se, but it warrants investigation and improvement."

(The arrival half of "never able to settle" is manoeuvre's this round; yours is the War Rig that drove away under attack-move.)

## Where things stand (main at launch: see HANDOFF)

- **His recording:** `_agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz` (Locks, seed 56416, Gangs v
  Syndicate, round-42 main b12b17ac7 + docs, laptop 26-31 fps, 49 s). Census rows every 1 s (`MatchRecorder.CENSUS_S`), order rows
  with refusals, task rows. Read it with `python3 tools/recording_arrivals.py <file>`.
- **The anomaly (orchestrator's read):** under his attack-move to the far quay (-100, -15), the lead War Rig reached the west bank at
  (-105, 46), 46 m short of the west swing bridge, then turned and drove 100 m back to the north-east edge over 20 s (ticks 660-1320),
  fired nothing, met nothing (every enemy was south of the canal), ended `blocked terrain` at (-9, 95). His attack order on it at
  tick 806 showed on the crew only at tick 1380 (19 s). The planner seam refused every ask that match (18 asks, all k-turns:
  START_BLOCKED 8, GOAL_BLOCKED 1, NO_PATH 1, 0 plans).
- **Hypotheses to kill first (cheapest first, none shown):** (a) the route to the far quay was re-planned via another crossing (the
  west swing bridge's state, its "far" twin `arenas/locks.json` "west swing bridge (far)", or a lane cost) and the north-east drive is
  the path to the lock; (b) the element's leader / task moved (a squad task row re-aimed the crew); (c) `--attack-shot`'s firing-spot
  search picked a spot behind (its spot is "toward the enemy", but on a team-seen contact far south?); (d) an unstick / k-turn chain
  after START_BLOCKED drove it off; (e) the order latency (806 -> 1380) is the order queue or the executor holding a stale order.
- **The replay probe** (`tests/replay_orders.gd`, the orchestrator's; native owns it this round) re-issues his orders headless with the
  same seed / army / cap but diverges inside 2 s (his Guns jam at the start, the replay's drive off) and did not reproduce the
  turnaround with attack-shot on or off. Native's CP43.0 is making it faithful; don't wait for it.
- Shipped from round 42 that touch this crew: `--attack-shot` ON (firing positions), `--camera-danger` ON (camera only), the counter-
  lineup (the enemy's deal). Round 42's Known issues: SUPPRESS can stand in band with no line; the flank side pick is a knife-edge.

## Backlog (in order)

1. **A1 the turnaround, traced on his seed (report first, C43.3).** Rebuild his War Rig's situation without the replay: from the
   census at tick ~630 (positions, hp, orders of every unit), place the armies on Locks 56416 (your E1 probe's census-places method),
   issue his attack-move to (-100, -15) and his tick-806 attack, and trace per tick: the order the crew holds, the element task, the
   brain's choice, the route (its waypoints and which crossing), the planner asks and refusals, the mover's phase, the attack-shot spot.
   Reproduce the drive north-east or show it doesn't reproduce from that state. Then kill hypotheses (a)-(e) one by one, each by
   REMOVING the suspect (a switch off, a route pinned), never by a ratio. Send the trace table and your cause to the orchestrator
   before building anything.
2. **A2 the order latency.** Why his attack order at tick 806 reached the crew at tick 1380: trace the command from `RtsControls`
   through `order_controller` / `order_executor` to the element. If it is a queue that holds while a plan runs, say so with the ticks.
3. **A3 the fix, OFF behind a switch (ON when its bar passes; `=off` = round 42).** Whichever cause A1 shows, in your paths; if it is in
   the mover or the planner, the orchestrator rules (C43.3). Symmetric for the CPU. A test on the traced case first (it fails on today's
   main, passes with the fix).
4. **A4 Bar A, filed before any number on 10301-10324.** Workload: an attack-move across a canal on Locks (and one other arena with a
   crossing: crossing or docks), mixed squads, the CPU enemy dug in beyond; 24 seeds, BASE off v ARM on, one commit. Deciding (name it
   before the numbers, e.g.): crew-seconds driving AWAY from the order's point (distance to it rising for > 5 s with no contact) ARM <
   BASE by >= 2 se. Guards (filed first, unamended): Bar E1's lines at their round-42 levels (stuck crew-seconds, first hit, deaths),
   fight length, perf (us/tick within 1.05x), no SCRIPT ERROR; fight guards 10325-10348 on builder2 if over 24 fights.
5. **A5 after CP43.0:** read his turnaround on the faithful replay, ON and OFF; the clip for him if the fix ships (laptop, one Godot
   run under the lock; film outside `build/`).
6. **Stretch:** E2, the SUPPRESS stand on a STAGED draw (your round-42 proposal in the archived Status: a workload that exercises it,
   since 1 of 48 seeds did); the flank side latch.

## How to verify

`tests/tactics/test_engage*.gd`, `tests/engage/**`; `make quick-remote` (QUICK_BASE=your last green); `make remote T=check` only for a
hash you name. Smoke like a player: `make skirmish ARENA=locks SEED=56416`, his Gangs v Syndicate, attack-move a War Rig squad to the
far quay past the west swing bridge; does it keep going? Look at your screenshots.

## Don't touch

Settle's functions in `element_plan.gd`, `game/ai/movement.gd` and `game/ai/traffic.gd` (manoeuvre), `game/camera/**` (camera),
`native/**`, `tests/replay_orders.gd` (native), `game/match/**`, `game/ui/**`, `arenas/**`, `tests/baselines/**`. Don't push main.

## Waiting on the lead

Nothing. The clip, when A5 has one.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
