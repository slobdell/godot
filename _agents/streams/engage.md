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

**2026-10-27 ~21:40 PDT (Fable). A1 DONE: the turnaround is reproduced bit-exact on native's faithful replay and its cause is
shown by removal. Cause: Traffic's STREET HOLD (round 29 T1, `game/ai/traffic.gd` `_begin_wait`, manoeuvre's path): when two
friendly squads meet head-on in a street, the waiting squad's EVERY moving crew is dealt a spot behind the street's mouth, however
far from the mouth it stands; his lead War Rig, 80 m from the mouth, was sent to its spot (-29.7, 100.0) at full pace and drove
there for 18 s. Ownership asked of the orchestrator (C43.3); nothing built yet. A2 answered (below: no queue). Code: 2d43b1e88
(main 84f914f78 merged at a51c8d5af).**

### A1: the turnaround on his seed (laptop, native library ON, `make engage-replay-trace ENGAGE_TAG=on`, 2d43b1e88, his recording, 50 s, n 1, deterministic)

The replay (native's CP43.0, `tests/replay_orders.gd`) puts Green_Guns_1 **0.0 m off his census at every second for 48 s**
(`tests/replay/divergence.py --crews=Green_Guns_1,Green_Guns_3`: both crews 0.0, PASS) and `tools/recording_arrivals.py` reads the
replay's own recording exactly as his: `Guns_1:best61m/no-arr/AWAY82m`. The trace (`--crew-trace=Green_Guns_1`, a new
measurement-only TankBrain line: the K1 order, the choice and why, the move asked, the mover's goal / steering point / path / driver,
the planner's last refusal, the street hold) and `--element-trace=Guns`, ticks 445-1400:

| ticks | the crew holds (K1) | the element (task, slot for Guns_1) | the brain chose | the mover drove at | what happened |
|---|---|---|---|---|---|
| 445-550 | `attack_move` to its vee seat (-85, 18.5) then react-to-contact's (-95, 38) / (-102, 36), paced 0.35-1.0 | task move+drills to (-100, -15); anchor (-89.5, 8.8); crossing = the west bridge (-88, 12)->(-98, -11) | MOVE | the seat, then **from tick 478 the hold spot (-29.7, 100.0)** (`steer`), driver `route` | Traffic verdict at 478: squad e:5 (Guns) WAITS for e:6 (his Hunters, moving west at z 50-65 across the Guns' way); spots dealt to Guns_3, Guns_4 AND Guns_1 |
| 556-694 | `attack_move` (react to contact: 15 m toward the contact / the seat across the bridge) | task move+drills; drill react_to_contact; swarm/vee flapping | **ENGAGE Rust_Hunters_3 / _4 across the canal, 58-61 m** ("going for its side, weaving" / "no line of fire: going round") | direct REVERSE hops to (-69, 64) and (-71, 61); a direct forward hop to (-112, 81); routed moves to the contact's spot (-112, -12) | the hops swing the 14 m hull from yaw 110 deg to -178 deg (nose north) at 9 m/s; no shot (the gun's range 50, effective 36) |
| 700-1005 | `attack_move` to the seat (-80.6, 20.6), then (-77.0, 24.4): on the NORTH bank, 45 m south-east of the crew, steady | task move+drills, then his attack on Rust_Hunters_4 (tick 807: the task is `attack` from t 27.0); slot (-77, 24.4) stands t 27-35 | MOVE ("attack-move") | **steering point (-29.7, 100.0) for 15 s** (driver `route`, throttle 0.75-0.99, no k-turn, no unstick, no planner refusal, no fire detour) | **the drive away: (-103, 55) -> (-24, 98), 90 m north-east at 8-12 m/s, 47 -> 90 m off its own seat** |
| 1023-1060 | same | same | MOVE | the seat (-77, 24.4): the hold released at ~1023 (18.2 s after the verdict; HOLD_CAP_S is 20) | the hull starts its turn back (yaw -117 -> -67) |
| 1063-1108 | react-to-contact `attack_move` naming Rust_Hunters_4, (-24, 87) / (-11, 85) / (-11, 75) | task attack; drill react_to_contact | MOVE | those points | 10 s more at the north edge |
| 1124-1320 | `attack_move` to the seat (-60, 41) | task attack; slot (-60, 41) | MOVE | the planner seam LIVE (a lattice plan pending), the circle rule reversing at 2.8 m/s, phase `blocked terrain` 1248-1320 | **the container stall: 6.5 s against the container_20 at (-20, 80), the 14 m hull turning round in the gap by the arena edge** (its own line, manoeuvre's: k-turn / circle-fit) |
| 1336-1449 | `attack_move` to (-96.5, -30.8) then `attack` Rust_Hunters_4 | task attack, pursuing | MOVE, then ENGAGE / PURSUE | the far quay, routed | drives south-west at 12 m/s, as his did from tick 1380 |

**Killed by REMOVAL (C43.3): the street hold.** `make engage-replay-trace ENGAGE_TAG=nohold ENGAGE_FLAGS=--traffic-off=hold`
(same tree, native ON, the match identical to his for 17 s and then only this crew's drive differs): **Guns_1 best 29.8 m, ARRIVED
on the far quay at tick 810 (12 s after his order), drive-away seconds 1 v 19, farthest north-east (-91.6, 55.3) v (-8.6, 95.4).**
(It then died at ~28 s in the five Hunters' line, alone: the crew obeyed; the squad was already dead or held.) The hold's own
read, from Traffic's tables in the trace: `{"group": "e:5", "passer": "e:6", "since": frame 511 (tick 478), "spot": [-29.7, 100.0],
"spots": [Guns_3, Guns_4, Guns_1]}`; the mover's steering point equals the spot from tick 478 until 1023 whenever the driver is
`route`. In code: `Traffic._begin_wait` deals a spot to every moving crew of the waiting squad; a crew behind the centre line gets
`_spot_behind(centre, ...)` (HOLD_BACK_M 8-43 m behind the MOUTH, HOLD_SIDE_M to the right), whatever its own distance to the mouth;
`hold_of` returns pace `approach` = 1.0 beyond HOLD_SLOW_M (16 m), so a far crew drives to the mouth at full speed for up to HOLD_CAP_S
(20 s) or until the passer is past. His War Rig stood 80 m from the mouth.

**The other hypotheses, each killed:** (a) a route via the lock: the navmesh (`tests/engage/path_probe.gd`, `make engage-paths`)
routes every leg from (-105, 46) to the far quay / a far-bank seat over the west bridge (63-67 m); the lock is 108 m to (-14, 84)
alone; and the crew's K1 goal was never across the canal to the east (the trace: its seats were (-85, 18), (-80, 21), (-77, 24),
(-60, 41), (-96, -31)). (b) the element re-aimed it: the element trace shows the slot standing at (-80.6, 20.6) -> (-77.0, 24.4)
through t 25-35 while the hull drove 90 m the other way; the task changed once (his attack, 807). (c) attack-shot's firing spot:
no `move`-to-spot order on this crew in 50 s (every K1 order was `attack_move` / `attack`); the `--attack-shot=off` arm
(ENGAGE_TAG=asoff) is a different match from 14 s (the rule changes the fight before the hold) and has no drive away either, so it
neither shows nor rules out, and the trace does the ruling out. (d) an unstick / k-turn chain after START_BLOCKED: `kturn_m` 0,
`unstick` false, `refusal` [] and the planner not live for the whole drive 700-1005; the planner goes live only at the container
stall (1124+). (e) the order latency (A2): below. **The combat hops (556-694, ENGAGE on a target across the canal) are real and
turned the hull north, but they are not the drive: with the hold off the same hops happen and the crew still arrives in 12 s.**
They remain a known issue (below).

**Why a rebuild from the census could not show it** (`tests/engage/turnaround_probe.gd`, `make engage-rebuild ENGAGE_FROM=420|540|600|630|660`,
laptop, 0e7664821): a task assigned fresh forms the elements fresh, so Traffic's verdict (made at 478 between two squads moving
through each other) never recurs, and every rebuild went for the bridge (from 660: on the deck by 790, 16 m from his click at 30 s).
The rebuild probe stays as a tool (any census tick, both sides' task rows replayed, the crew traced).

### A2: his attack at tick 806 "reached the crew at 1380": no queue

The order reached the ELEMENT the next tick (task row 807: `attack Rust_Hunters_4`; the element trace: task `attack` from t 27.0).
What the census' `order` column shows is the crew's K1 verb, which the element chooses: out of reach of the target (131 m, across the
canal) `ElementPlan._engage` and react_to_contact issue `attack_move` legs toward it (naming the target from 1063), and the K1 verb
becomes `attack` only when the element's pursuit (`_plan_pursuit`) or in-reach `attack` takes over (1372 in the replay, 1380 in his
census). Nothing held the order; the HUD's "carrying out" reads the named attack-move the same way (round 42's `_moving_round`).

### Known issues found (not built on)

- **ENGAGE across water (mine, R43.5 GRANT if the orchestrator confirms):** under attack-move the crew brain engages a team-seen
  contact across the canal when within range + 15 m: `_own_line_to` (the cover map) ignores water, and `_combat_move` answers direct
  hops (one of them reverse, 36 m) that swing a 14 m hull round and away. No shot results (effective range 36 m). Measured on his seed
  only (556-694); it did not cause the drive, but it costs 5 s and a 180 deg turn. A rule: no ENGAGE hop toward a contact the hull
  cannot reach without a crossing (SlotGround.leg_wet on the hop), or "water between: firing across" (the existing hold) applied to
  the choice, not only the hop. Symmetric for the CPU.
- **The container stall (manoeuvre's):** 1124-1320, the rig turning round beside the container_20 at (-20, 80) with the planner live
  and the circle rule reversing; 6.5 s `blocked terrain`. Same family as round 42's rust s2 t15.
- The vee/swarm flap on this element (t 17-23 and 36) re-seated the crew each time (the orchestrator's note); not the drive either.

### Requests to the orchestrator

- **Ruling (C43.3): the cause is in `game/ai/traffic.gd` (`_begin_wait`, `_spot_behind`), manoeuvre's path.** Proposed rule, symmetric
  (the CPU's squads take the same holds), behind a switch (`--traffic-on/off`): a crew of the waiting squad farther from the street's
  mouth than the spot grid reaches (HOLD_BACK_M's last row, 43 m, plus its hull) is not sent to the mouth: it is released from the hold
  (ORCA keeps it clear as always), or holds where it is (`spot = here`, the existing "nowhere to pull aside" branch) if its route runs
  through the street. A test: a two-squad head-on meeting with one crew of the waiting squad 80 m back; today it is dealt a spot at
  the mouth and drives there; with the rule it keeps its route. If granted to me I build it (A3) and file Bar A; if manoeuvre's, the
  trace and the replay recipe above are theirs (`make engage-replay-trace ENGAGE_TAG=<x> ENGAGE_FLAGS=...`, `--crew-trace=<name>`).

### Tools (all engage's)

- `tests/engage/turnaround_probe.gd` (`make engage-rebuild`): a census-places rebuild of a recorded match from any tick, both sides'
  task rows replayed at their ticks, one ENGAGE_TA row per change / sample for one crew, ENGAGE_TA_SUMMARY (drive-away, nearest, the
  farthest north-east, the bridge tick, the planner's report).
- `tests/engage/path_probe.gd` (`make engage-paths ENGAGE_LEGS="x,z>x,z;..."`): the navmesh's route and crossing per leg.
- `TankBrain.CREW_TRACE` (`--crew-trace=<name|all>`, default off, no behaviour): CREW_TRACE per think change / 15 ticks.
- `make engage-replay-trace ENGAGE_TAG=<arm> ENGAGE_FLAGS=<switches>`: native's replay of his match with the traces on, its recording
  under `build/engage/rec/<arm>/` for `tools/recording_arrivals.py` and `tests/replay/divergence.py`; `make engage-his` unpacks the gz.
- Merge note: `game/ai/tank_brain.gd` gains `CREW_TRACE` (static), `_crew_trace()` and one call after `_act` (3 hunks, trace only).

