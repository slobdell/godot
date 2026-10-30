# Stream: manoeuvre (his squad settles where he clicks; squads at a street mouth wait for the right one; a short move inside the turning circle)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 344, 345), `_agents/judging.md`, `_agents/workstreams.md` **Round 46**
> (C46.1-C46.8), your last brief `streams/archive/round45/manoeuvre.md` (ROUND 45 FINAL REPORT: S v4 / S v5, holdway A6 v4, shortfwd,
> backout's 75 %), R45.17, R45.20, R45.26, R45.28 in `workstreams.md`, and
> `references/round45/manoeuvre/barss5-builder0-fc639d7e0/README.md` (S v6's starting point). **You own:** movement's drive / unstick /
> side-step / avoidance / yield / backout (`game/ai/movement.gd` but the planner seam), `game/ai/traffic.gd`,
> `game/tactics/tactics_formation.gd`'s `pitch` / `hull_floor` / `offsets_at` / `fit_to_corridor` / seat bound / shape latch,
> `game/tactics/element_plan.gd`'s `grouped()` and converge, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`,
> `tests/test_traffic*.gd`, `tests/test_formation*.gd`, `mk/manoeuvre.mk`. NOT `element.gd` (engage's), NOT `game/control/**` (orders').
> **Model:** Opus. **Machine:** builder3 (builder0 a second light lane). **Seeds:** 12001-12048 (S v6), 12049-12096 (A6 v5),
> 12097-12144 (backout / shortfwd / reserve). Dev 7001-7012 (never a bar).

## The lead's direction

His standing asks this stream serves: his squad settles where he clicks (round 43: "units must look smart"); a War Rig backs out of
the box (shipped ON round 45). Round 46 brings no new words for this stream; it finishes the round-45 starting points so they can
reach his default game. Memory: units must look smart and under his control; contention first.

## Where things stand (main at launch: see HANDOFF; code 96f199c45 GREEN builder3 3470/0)

- **Shipped ON:** backout (R45.26; `--traffic-off=backout`). Missed 9 of 12 base-stuck poses' "sooner" only on exact ties (pose 10: a
  squadmate 1.7 m beside the rig, the back-up refused). Terminus pays ~3 s of k-turning a run (reported).
- **Seat bound S v5 FAILED (R45.28):** the settle is real (seated within the bound by 15 s 220 -> 329, +8.4 se) but Crossing's Battery
  squad yields to ITSELF (+9.85 s a run, cell 11751) and Locks wedged +3.37 s. Cause: the open seat + rear-crew term deal two-row
  layouts seats whose paths cross. S v6: the rear-crew term keeps S v4's lateral order.
- **Holdway A6 v4 FAILED (R45.20)** on guard 4 by -0.16 se (the judging table's closest line): the "ordered way" was the crew's next
  station (sideways at an order's first ticks). Fix: the squad's route tangent (as backout's look uses) + a tie rule (the squad whose
  lead is nearer the street's inside waits). One real bug fixed on main (fc639d7e0).
- **Shortfwd** (his short move inside a wheeled crew's turning circle drives forward, not back): parked, code on the branch.
- Every switch of this stream's new code is DEFAULT_OFF on main.

## Backlog (in order)

1. **M1 S v6 dev read on Crossing's Battery layout (11751's geometry, dev seeds):** the rear-crew term keeps the squad's lateral order;
   show no self-yield on Crossing and Locks wedged within noise BEFORE filing. Status first, then message the orchestrator.
2. **M2 Bar S v6** on 12001-12048 (filed before numbers; S v5's guards unchanged + Crossing yield+blocked and k-turn as named risks).
   Native twin EQUAL first (C46.4). Ships ON when it passes.
3. **M3 holdway A6 v5:** ordered way = the squad's route tangent at the crew, the tie rule; Bar A6 v5 on 12049-12096 (A6 v4's lines
   unchanged). Native twin. Ships ON when it passes.
4. **M4 backout pose 10:** the refused back-up beside a squadmate (a shorter first leg or a lateral look); and the Terminus k-turn
   seconds read by removal. Its bar on 12097-12120 only if the change is real.
5. **M5 shortfwd:** a bar on 12121-12144 using his Gorge recording's geometry (`references/round44/playtest/...gorge.jsonl`, the lone
   scout's 1-11 m moves) as the staged workload.
6. **Relay seat for engage's L2:** if engage asks (through the orchestrator) that an idle crew blocking a firing lane steps aside, it
   is yours to build in the yield code; it outranks M4-M5.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote`; `make manoeuvre-*`;
the B1 corpus and the default orders probe (60/60 byte-identical v main for any OFF code); top-down shots looked at. Every number with
its commit, machine, workload and n.

## Don't touch

`game/tactics/element.gd` (engage's), `game/control/**` (orders'), `game/ai/gunnery.gd` / `fire_lanes.gd` / `tank_brain.gd` (engage's),
`native/**`, `game/camera/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. A bar that fails twice on the same fix: write in player terms what he would see and message the orchestrator
(lesson 339).

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
