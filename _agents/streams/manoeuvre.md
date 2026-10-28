# Stream: manoeuvre (his first squad settles where he clicks: no 20 s jam in the start zone, no seat 29 m off, no crew lost on the way)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 43** (C43.1, C43.4, C43.5, CP43.0), your
> round-42 brief `streams/archive/round42/manoeuvre.md` (Status: Q5 OFF and R42.11's framing "clear the stalled head", Q6's deckwait
> and why it failed, Known issues, the drill recipes), and `game_design.md` *His playtest after round 42*. **You own:** movement's drive
> / unstick / side-step / avoidance / yield in `game/ai/movement.gd` (not the planner seam), `game/ai/traffic.gd`; GRANT (C43.5) the
> formation's spacing and seat: `game/tactics/tactics_formation.gd` (`pitch`, `hull_floor`, `turning_pitch`, `offsets_at`,
> `fit_to_corridor`) and `game/control/group_formation.gd`; `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`,
> `tests/test_traffic*.gd`, `tests/test_*formation*.gd`, `mk/manoeuvre.mk`. **Model:** Fable. **Machine:** builder0 light lane
> (J<=4); builder2 for a series over 24 fights. **Seeds:** 10401-10424 (bar S), 10425-10448 (guards), 10449-10472 (S5 bridge,
> BRIDGE_POOLED_SEEDS); his 56416 and dev blocks never a bar.

## The lead's direction (2026-10-27 ~20:00, verbatim)

"I was paying attention to the camera, but I didn't get far before seeing that my units all seemed incapable of moving to the west
side of the map. ... My first squad of tanks was never even able to settle for a simple target destination. I don't know if this is a
regression" ... "I want you to track that as something to investigate in the next round. I'm not sure if it's a bug per se, but it
warrants investigation and improvement."

Standing bar (memory, *units must look smart*): he must perceive his units as smart and under his control; contention first.

## Where things stand (main at launch: see HANDOFF)

- **His recording:** `_agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz` (Locks 56416, Gangs v Syndicate,
  laptop, 49 s); `python3 tools/recording_arrivals.py <file>`. His first squad (Guns: three War Rigs, a Gun Truck, a Tanker) ordered to
  (-69, 51) at tick 0: three of five arrived in 6-9 s; **the wedge seats the lead War Rig 29 m west of the click** (formation spacing
  for 14 m hulls; the same spread is in his round-41 recording); **War Rig 3 spent 20 s yielding to his Hunters in the deploy zone**
  (the same start-zone jam is in the round-41 recording, `references/round42/engage/2026-10-26T14-15-45-locks.jsonl`); **the Tanker
  routed east round the warehouses and never arrived in 14 s.** (The lead War Rig's later drive back north-east under attack-move is
  engage's A1; tell the orchestrator if your trace lands on it.)
- R42.11: the never-in squads are columns behind a STALLED HEAD (at the Crossing's street mouths); the next rule must clear the head
  (why it stands: the deploy / seat / mouth it waits on), not only ease the follower. R42.15: deckwait's fresh-seed bridge had nothing
  to fix OFF; the next shape fires only on the carried-past case.
- The headless replay (`tests/replay_orders.gd`, native's this round) diverges from his match in 2 s: his Guns jam at the start, the
  replay's drive off. That divergence IS your jam: until CP43.0 makes the replay faithful, rebuild the start from his census (tick 0-60).
- ON for `deckwait` / `nopush` / `wait` / `holdlane` forces `native_drive` off until twinned (Known issues, round 42).

## Backlog (in order)

1. **S1 the arrival census of his first order (report first).** From his census (ticks 0-60), rebuild Locks 56416's start with his
   whole army and his first order; trace per crew per tick: seat, distance to seat, the mover's phase, who it yields to and why (the
   yield / ask / wait chain), the route (which way round the warehouses and why the Tanker's goes east). Name, with ticks: why War Rig 3
   yields 20 s to the Hunters (who is the stalled head and what it waits on), why the wedge seat is 29 m from the click (the pitch
   numbers), why the Tanker never arrives. Do the same on the round-41 recording's start. Send the table to the orchestrator first.
2. **S2 the seat (C43.5).** His click is where the squad goes: the formation centred on the click, its farthest seat within a bound you
   name from the hulls (e.g. <= 1.5 hull lengths + the hull floor for a five-crew wedge), spacing by real hull extents (C38's floors
   kept), the G1 v9 group column unchanged for a group of squads (test). OFF behind a switch; a test on his click first.
3. **S3 the start-zone jam.** The rule S1's cause asks for (clear the head: e.g. a crew already at its seat or parked in the deploy zone
   steps aside for a crew whose route runs through it; a yield that times out with nobody moving re-plans), speed-only where it can be
   (C43.4), OFF behind `--traffic-on=<name>`, a test on his start first.
4. **S4 Bar S, filed before any number on 10401-10424.** Workload: his first order shape (a five-crew mixed squad to a point on its own
   bank, the rest of the army deployed beside it, then a second squad's order through the same zone) on Locks + two arenas with a cramped
   deploy (terminus, crossing), 24 seeds, BASE off v ARM on, one commit. Deciding (name before numbers, e.g.): crews seated within the
   bound by 15 s ARM > BASE by >= 2 se, AND start-zone yield-seconds ARM < BASE by >= 2 se. Guards (filed first, unamended): his 5-squad
   order's jam / contact lines at round 42's levels, Bar G1 v9's corridor lines, fight length, perf (us/tick within 1.05x), no SCRIPT
   ERROR; 10425-10448. Native twins before ON, or the bar says native_drive is forced off for it (C43.4).
5. **S5 the bridge crew (balance's gate, R42.15 / R42.23).** The drill crew rust s2 t15 that Bar B2s v2's bridge depends on: the
   carried-past case only (your round-42 next-round shape), on fresh 10449-10472. If it passes, balance's stat change can be re-read next
   round.
6. **Stretch:** the `_wait` timer artefact fix with a test; `q3_judge.py`'s counters line under `--arm=deckwait` (one-line fix).

## How to verify

`tests/test_traffic*.gd`, `tests/test_manoeuvre*.gd`, `tests/manoeuvre/**`; `make quick-remote`; `make remote T=check` only for a hash
you name. Smoke like a player on the laptop: `make skirmish ARENA=locks SEED=56416`, Gangs: send his Guns squad to (-69, 51) and his
Hunters next to it; do all five crews sit near the click within seconds, does anyone wait 20 s? Screenshots at desktop and phone aspect.

## Don't touch

`game/tactics/element_plan.gd`, `drills.gd`, `firing_position.gd` (engage), `game/ai/planner/**`, `game/ai/order_controller.gd`,
`game/camera/**`, `native/**`, `tests/replay_orders.gd` (native), `game/match/**`, `arenas/**`, `tests/baselines/**`. Don't push main.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Session start 2026-10-27 ~20:40 PDT (Fable). Starting commit 2f1620a77 = main at launch (code b12b17ac7 GREEN builder0, 3343/0; no
baseline check re-run, per the contract). CP43.0 taken at f6b930a3d (main 84f914f78 merged). Orchestrator session: `godot-b8`.**

### S1 REPORT: the arrival census of his first order (2026-10-27 ~22:30 PDT; laptop, 847e569cf, the rebuild of his Locks 56416 start)

**How it was read.** `tests/manoeuvre/start_trace.gd` (`make manoeuvre-start-trace`) restarts his match (seed 56416, Locks, Gangs v
Syndicate, `--squad-cap=4`: his laptop's four squads of five; the arena and seed on the REAL command line, R43.1), issues his orders
at their ticks (the tick-0 one inside the planning pause) and prints every traced crew's mover and seat per tick. **Fidelity (START_GAP,
laptop, GDScript drive): all ten Guns / Hunters crews within 0.1 m of his census for the first 10 s, within 2 m to 13 s, the same phases
at the same seconds (Guns_3 yielding to Hunters_1 at 7-8 s, to Hunters_4 at 13-14 s as in his census).** Before R43.1 the replay ran on
the default map with 46 units; that, not the mover, was "his Guns jam, the replay's drive off". Logs: `~/overnight-manoeuvre/r43/s1/`
(traceC = the rebuild; traceE = `--anchor-inset=off`; trace41 = the round-41 recording on today's code, which diverges at 3-4 s there).

**The three answers, with the mechanism (every seat below is the element's issued order `to`, read off START_SEAT / START_ROW):**

1. **Why the lead War Rig seats 29 m from his click, and two crews 60-70 m from it: the squad's travel shape is the Gangs doctrine's
   SWARM, laid round a point 15 m off his click.** `doctrines/doctrine_gangs.json` "movement": every row but `threat: likely` (a VEE)
   is a swarm ("hunting, in no particular order" is its default row), and `TacticsFormation.offset("swarm")` lays rank 1 at
   +-SWARM_SPREAD (1.9) x pitch across the heading and rank 2 at twice that, staggered +-0.8 / 1.6 pitch along. The Guns' pitch is
   (14.7, 16.0): the War Rig's 14.0 x 3.32 m hull floors both axes (across = the dressing diagonal 14.39 + 0.3; along = 14 + 2), so
   the swarm is **112 m wide**: slots at (0, -25.6), (-27.9, 0), (+27.9, +25.6), (-55.8, -12.8), (+55.8, +12.8) m; farthest seat 58 m.
   Then `ElementPlan.inset_anchor` (overnight item 3, `--anchor-inset=off`) moves the destination inland until the shape's 58 m reach
   disc fits the arena's clamp polygon: his click (-69.1, 50.7) became the anchor **(-56.1, 43.2)** (traceE with the inset off: the
   anchor is exactly his click). Seats as issued at tick 1 (click (-69.1, 50.7)): **Guns_1 War Rig #3 (-97.4, 50.4) = 28.3 m W** (his
   "29 m"), Guns_2 War Rig #0 (-68.8, 21.0) = 29.7 m S, **Guns_3 War Rig #4 (-1.3, 26.7) = 72 m E**, Guns_4 Gun Truck #1 (-80.4, 57.1)
   = 13 m W, **Guns_5 Tanker #2 (-6.2, 51.6) = 63 m E**. The VEE the squad flips to (below) at the hull-floored pitch has its rear
   corners at 2 x 13.2 across + 12.8 along = **29.3 m** from the click (Guns_1's vee seat (-98.4, 52.7)): with a 14 m hull a five-crew
   wedge / vee cannot be tighter than that without the hulls clipping as they turn (C38's floors), so 29 m is the War Rig's physics;
   the 60-70 m seats and the 15 m anchor shift are the swarm's.
2. **Why War Rig 3 yields 20 s to the Hunters: its seat was 72 m EAST, through the Hunters' deploy row, and the squad's shape flipped
   swarm / vee / swarm / vee / swarm (t251, 278, 350, 437) as the planner's threat reading changed, moving its seat 50-95 m each
   time; it never left a 5 m circle at (-32, 74) in 16 s.** Trace: t30-90 drives SE at 7 m/s toward (-1.3, 26.7) through the Hunters
   (Hunters_1-5 parked at x -21..-8, z 89-95, then ordered west at t56); t105-180 ORCA-deflected by Hunters_1 driving west across its
   nose, speed 1.7 -> -1.0 -> 0.6 m/s, stall 1.6 s; **t184 Hunters_1 (pinned behind it, seat (-69.8, 60.8) west) asks it via "pinned";
   its answer is a HOLD (no spot fits a 14 m hull: room_ahead 0, room_behind 40 on START_YIELD), so it stands across Hunters_1's lane
   for the full 6 s (YIELD_MAX_SECONDS, t184-250) while Hunters_1 stands at (-31.7, 79.1) t142-300 pushing at it**; t251 seat ->
   vee #0 (-59.6, 67.4) WEST; t278 -> swarm #2 (1.9, 51.6) EAST (drives east at 10-11 m/s t300-330); t350 -> vee #0 (-56.5, 66.5)
   WEST (pace 0.35); t368-405 yields to Hunters_4 (pinned, short:back(10), reverses 2 m); t407 seat (-60.3, 39.5), t437 (-45.9, 69.5),
   t446 his attack-move (-83.6, -18.4); wedged from t420. **The stalled head is War Rig 3 itself, across the Hunters' lane; what it
   waits on is a seat that moves 50 m every few seconds and a give-way that can only hold.** Hunters_4 (seat (-27.2, 14.5): 67 m S of
   its click; then (-45.8, 19.1)) k-turns at (-20, 64) t204-268, wedged from t300, stands at (-22, 68) t330-480 behind War Rig 3 (his
   census: `blocked Guns_3`). Hunters_1 arrives only at t415 (12 s after its second click).
3. **Why the Tanker never arrives: its seat was 63 m EAST of his click (swarm #2), and stayed east.** It drives east along z 83-85
   (the warehouses' north side) at 5-9 m/s t120-250 toward (-6.2, 51.6); t251 seat -> vee #4 (-53.4, 26.5) west (82 m of route);
   t278 -> swarm #4 (-1.3, 26.7) east again; t330-350 at (-6, 55) 11 m/s; t350 seat -> (-53.3, 40.9) west: k-turn at (-6, 51)
   t350-390. It was never routed "round the warehouses" to the click: every seat it had but two was on the far side of them. Killed
   t404 (his recording's `dead` row: Rust_Guns_2).

Guns_2 (seat 30 m S of the click, toward the canal) k-turned in place 3.6 s (t20-127, reversing north 3.5 m: his census's "crept
north"), arrived t251 and was the first loss (t348, Rust_Guns_3). Guns_1 and Guns_4 drove straight to their west seats (8.2 s / 5.5 s).

| crew (his first order, Locks 56416, click (-69.1, 50.7)) | first seat | from click | seat moves (max) | arrived | nearest to click | yielding s | k-turn s |
|---|---|---|---|---|---|---|---|
| Guns_1 War Rig | swarm #3 (-97.4, 50.4) | 28.3 m W | 3 (50 m) | 8.2 s | 15.4 m | 0 | 0 |
| Guns_2 War Rig | swarm #0 (-68.8, 21.0) | 29.7 m S | 2 (29 m) | 8.4 s | 10.1 m | 0 | 3.6 |
| Guns_3 War Rig | swarm #4 (-1.3, 26.7) | 71.9 m E | 6 (96 m) | never | 41.3 m | 3.5 (+ 1.2 hold) | 0 |
| Guns_4 Gun Truck | swarm #1 (-80.4, 57.1) | 13.0 m W | 3 (36 m) | 5.5 s | 7.6 m | 1.1 | 0 |
| Guns_5 Tanker | swarm #2 (-6.2, 51.6) | 62.9 m E | 3 (54 m) | never | 48.6 m | 0 | 1.8 |
| Hunters (t56 click (-60.7, 72.5); t141 (-86.1, 55.6)) | swarm: _1 15 m, _2 61 m E, _3 43 m N, _4 67 m S, _5 20 m | | 4-9 each | _5 11 s, _1 12 s, _3 arrived; _2 / _4 never | | | _4 2.1 |

(laptop, 847e569cf on main 2f1620a77, GDScript drive, one run each: the rebuild is deterministic, and his census agrees with it.)

**Round 41's recording (Locks 49326; his four squads ordered at tick 0, the Guns with a queued SCREEN):** on today's code the rebuild
diverges at 3-4 s (native: it was played on 21b20bdce; native replays it on that tree), so only the tick-1 seats are a read: EVERY
squad's first move is a swarm, Hunters_2's seat (-52.0, 37.3) is 65 m S of a click on the north edge (-58.4, 102.2), Hunters_3's
(-63.8, 117.2) 15 m N of it, Spears_4's (-25.9, 20.0) 75 m S of (-44.8, 95.4), Spears2_4 / _5 east: four swarms 100 m wide laid
over each other across the deploy zone is the round-41 start jam (his census: Hunters_2 yielding Hunters_3 2-5 s, Hunters_3 yielding
Guns_3, Guns_2 blocked by Hunters_1 at 4 s).

**What this says for the backlog (my reading, the orchestrator rules on the owners):**
- **S2 (C43.5, mine):** a bound on the farthest seat in `TacticsFormation.place` caps the swarm (58 -> ~37 m for War Rigs, ~18 m
  for Gun Trucks) and with it `inset_anchor`'s shift (a 37 m reach disc at his click clamps nothing: the anchor stays on the click).
  The wedge / vee of five War Rigs stays at 29 m: the hull floor. Building it OFF behind `--seat-bound=on`, test first.
- **Not mine, ruling asked (R43.x):** (a) the travel shape of a PLAYER's move order flapping between the doctrine's swarm and vee on
  the threat reading (`ElementPlan` + `doctrine_gangs.json`'s movement rows): every flip re-seats the squad 50 m; a latch (keep the
  shape a move started with until it arrives or he re-orders) would end the E/W/E/W of Guns_3 and the Tanker. (b) Whether a swarm is
  the right travel shape under his move at all (the doctrine's "they spread wider than anyone"): the bound keeps its raggedness at a
  reach he can read as "at my click".
- **S3:** the jam's head is a crew sent through another squad's deploy row to a seat 70 m past the click, holding in place when asked
  (no spot fits a 14 m hull). After S2 the start is re-read on the same recording; what remains names the rule.

