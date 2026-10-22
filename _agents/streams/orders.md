# Stream: orders (his group click: the army goes where he clicked, stacked, whole)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1, C38.3) and
> in *Round 37*: R37.29, R37.38, R37.39 (his click, O7, the real-point read). Your round-37 brief and close notes:
> `streams/archive/round37/orders.md`. The design note: `references/round37/orders/group-click-column-note.md`; the lab:
> `tests/test_control_group_click.gd`; the switch on main: `--group-lay=column` (OFF). **You own:** `game/control/**`,
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`. Not the deploy/halt/seat functions (settle's,
> C38.3). **Model:** FABLE. **Machine:** builder0.

## The lead's direction (2026-10-21, verbatim in game_design.md *his playtest note on a group click*)

"By selecting all units and just clicking on an open space in the East side of the map, the target waypoints for each squad was all
over at far away places ... if there's not enough room for all target vehicles at the target waypoint ... it would make sense to just
have stacks of wedges (i.e. one squad immediately behind the other) ... the squad furthest away to land in the back and the closest squad
to land in the front ... I had a clear intent to navigate my army through a specific path I had in mind, but I immediatley lost control
of the army". And his standing bar: units must look smart and under his control; contention first.

What he will notice: select all, click anywhere on Terminus (or any street map): every squad lands in the space he clicked, stacked
along the approach, nearest in front, each squad with its own vehicles, nobody driving through another street.

## Where things stand

- O7 v1 (`--group-lay=column`, main, OFF) FAILED as filed (R37.38): plain clicks improved (crossing 5 outside 23 -> 2), route cells
  unchanged (squads leave the corridor on the route legs, not at the final click), yard_open changed (the scan's 100 m "open" test; its
  walls are nearer). At HIS real click it works (R37.39: outside 36/60 -> 0, metres outside 2,350 -> 323, re-dealt 24 -> 0).

## Backlog (in order)

1. **G1 O7 v2:** (a) open ground = the clear width fits today's body (not the scan limit), so yard_open stays identical; (b) route
   legs: lay each queued leg's arrival the same way, or keep squads in one column along the route; (c) whole squads (no re-deal).
   Lab first (his click; a route cell; yard_open identical), then a bar (O7's lines + "route metres outside the corridor"; yard_open
   rows identical; contacts; all-in). Paired top-down shots of his click, looked at, for him. A pass ships ON.
2. **G2 the shift-click route** case he described ("navigate my army through a specific path"): a queued route of 2-3 clicks keeps the
   army in one column through each street.
3. **Stretch:** the bridge-mouth lay (a plain click's places kept off the deck; R37.17's O3 trace).

## How to verify

Lab both paths; `make quick-remote`; one full check per named hash; `make native orders-probe` series on fresh seeds; his click as its
own cells (`--probe-click=x/z`); shots looked at. Smoke: `make skirmish ARENA=terminus`, select all, click the east apron.

## Don't touch

settle's deploy/halt/seat functions, doctrine's brains paths, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing (the shots go to him at the close).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
