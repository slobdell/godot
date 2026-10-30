# Stream: orders (his group click: the veto ships ON, nobody across the drop or sent back, every other click unchanged; then a tighter file)

> Read `_agents/orchestration.md` (the worker contract; **lessons 339, 345, 348**), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 46** (C46.1-C46.8, R46.1, R46.2), R45.31 and Bar G2 in *Bars (round 45)*, your last brief
> `streams/archive/round45/orders.md` (FINAL REPORT: what failed on the streets and why; the round-46 plan you wrote), and
> `game_design.md` *His answers at round 46's prep*. **You own:** `game/control/**` (incl. `selection_squads.gd`, `group_formation.gd`,
> `rts_controls.gd`) EXCEPT engage's grant in `order_executor.gd` (crew orders) and native's C++ seams (the GDScript bodies stay yours);
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`; GRANT `game/ai/planner/**` for a group
> order's departure order and route spread only. **Model:** Fable. **Machine:** builder3 (checks, series; never builder2 for a bar).
> **Seeds:** 11801-11848 (Bar V1), 11849-11896 (Bar V2 / reserve). Dev 7001-7006 (never a bar).

## The lead's direction

2026-10-29 (Gorge, verbatim): "I selected 3 squads and had them all go to a target waypoint that was south of the bridge. What
waypoint selection algorithm chose a far away waypoint that was north of the bridge for one of the squads. This was precisely the
behavior I had asked to fix."

2026-10-30, his picks (R46.1, R46.2): **the veto-only guard, ON** ("ONLY re-places a squad when it would land across a drop/water or
behind where it started — every other click, all streets included, stays exactly as today"), and **a tighter group file** ("Squads
pack closer (roughly half the length): the whole group is at your click sooner and fights together, at the cost of a bit more bumping
in tight spots").

He asked for the group click in rounds 37, 41, 43, 44 and 45 and **has never played a fix**. Lesson 348: the smallest ON change is a
veto, not a new layout.

## Where things stand (main at launch: see HANDOFF; code 96f199c45 GREEN builder3 3470/0)

- **His case:** Gorge seed 91711 recording `references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl`; one click at (-43.2, 53.2):
  today's `ranks` lay sends Hunters to (-76.0, 101.0) (48 m back, behind his start z 90) and Wrenches to (-10.4, 5.4) (across the drop).
- **G2** (the fitted file, ranks straight back from the click) is on branch `round45/orders` (2b95f6f27, default ON there), not on
  main. Its bar passed every line on his case (D1-D6, D5b 24/24) and failed the streets (places outside the corridor 7 -> 33, Terminus
  5-click all-in 11.7 -> 47.4 s): `references/round45/orders/bar-g2-builder3-03d1ddbc5/`. G2's `guard_failures` is exactly the veto's
  test; its re-deal is the seat source.
- **Spacing:** coil ranks are 33-50 m deep, so a 3-4 squad file is 66-150 m long. **The fit's ~60 path queries at his click cost 4.9 ms**
  (native's N1 this round moves them to C++; give native the seam early).
- Tools: `tests/control/orders_geometry_table.py` / `orders_geometry_judge.py`, `make orders-geometry`, `tests/control/orders_bar.sh`,
  `tests/orders_probe_group.gd`, `make replay-match`.

## Backlog (in order)

1. **V1 the veto-only guard, ON by default, `--group-veto=off` the escape (R46.1).** On today's default lay: for each squad's place,
   run G2's failure test (across a drop / water / neck from the click: ground path much longer than the line or the line crosses a
   pit; or > 10 m behind its own start along the approach). Only a failing place is re-dealt, to the nearest free seat on the click's
   side; **every passing place is byte-identical to today**, and a click with no failing place is byte-identical as a whole. Symmetric
   (C46.6). Tests first: his Gorge geometry (unit), a click beside a lock, a click on a bridge deck, a Terminus street click whose
   output must equal today's exactly.
2. **V2 Bar V1**, filed in `workstreams.md` *Bars (round 46)* BEFORE any number on 11801-11848, NARROW: deciding lines = his failure
   (places across a gap from the click: 0; places behind the start > 10 m: 0; D5b his exact Gorge click), on a corpus with Gorge (his
   click and clicks either side of each gap), Locks (his round-43 clicks), Crossing, Terminus. Guards: **part B's street lines as a
   byte-identity check** (every street click's places equal to base: by construction, so any difference is a bug), all-in / never-in
   on the cells the veto touched (<= base x 1.2 + 3 s), friendly contacts, engage's authority probe and manoeuvre's one-squad arrival
   (C46.3). Native's twin if it touches a C++ seam (C46.4). Ships ON the minute it passes; message the orchestrator the green hash.
3. **V3 his acceptance read:** the shipped tree on his Gorge replay and his two round-43 Locks clicks; top-down shots before/after,
   looked at; a table in Status.
4. **V4 the tighter file (R46.2), its own switch `--group-pack`, ON when its bar passes.** About half today's length: a 3-squad file
   <= ~50 m, 4 squads <= ~75 m (shorter rank depth between squads, not a new layout). Bar V2 on 11849-11896: deciding = file length
   and all-in time; guards = friendly contacts (<= base x 1.25 + 5: the "bit more bumping" he accepted is bounded), never-in, wedged
   seconds, the fight probe, the street lines. On top of V1.
5. **V5 the street lay (G2's file along the road)** behind `--group-guard=on`: rear ranks along the street corridor (the column's
   `_walk_back`), what part B wants. Dev reads only this round unless V1-V4 are done.
6. **Stretch:** more than two abreast on a wide yard (a feel question for him in player terms, one recommendation); the departure
   order (nearest leaves first).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote` to iterate; `make
replay-match RECORDING=...`; the geometry probe and judge; `make control-playtest`; top-down shots at his click, looked at. Every number
with its commit, machine, workload and n.

## Don't touch

`order_executor.gd`'s crew-order branches (engage's grant), `game/tactics/**` (engage / manoeuvre), movement / traffic (manoeuvre),
`native/**`, `game/camera/**`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch (both questions answered 2026-10-30). If Bar V1 fails, write in player terms what he would see ON v OFF and message
the orchestrator the same hour (C46.2): it goes to him the same day.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
