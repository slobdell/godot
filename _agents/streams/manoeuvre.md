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
