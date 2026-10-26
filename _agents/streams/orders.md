# Stream: orders (his many-squad order sets off as one: a shared direction, nobody nose-to-nose)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 41** (C41.1, C41.3,
> C41.4). Your round-40 brief: `streams/archive/round40/orders.md` (Status: G1 v6, G3 v9, the probe). **You own:** `game/control/**`,
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`; GRANT `game/ai/planner/**` for a group
> order's departure order and route spread only (C41.3). **Model:** Opus. **Machine:** builder0 light lane (J<=4); builder2 for a bar
> series. **Seeds:** O2 9101-9124 (C41.1).

## The lead's direction

His playtest of round-40 main (2026-10-26, verbatim in `game_design.md`): "when I'm controlling a large set of squads at once and
commanding all of them to go somewhere, a bunch of units block other units, but this is a symptom of all units generally not moving in
the same direction (i.e. a scout is pointed north and thus blocking a unit that's trying to go West) ... I suspect that we might get
better navigation with a little more coordinated movements".

Manoeuvre owns what a blocked crew does (wait, don't detour). You own the order itself: who leaves first, which way each squad turns,
which route each takes, so fewer crews start pointed across each other's lines.

## Where things stand (main at launch: see HANDOFF)

- T1 ON (`--deploy-arrive=settled`). G1 v6 and G3 v9 OFF with causes in your archived Status; G1 v7 parked (its dev read: a1602cca9,
  round40/orders-t1on).
- The orders probe (`tests/orders_probe.gd`) and probe_wedge (manoeuvre's, extends yours) measure squad-in times for a group click.

## Backlog (in order)

1. **O1 the group-order workload + start census.** Build (or extend the probe into) the case he played: select every squad (8+ on the
   bigger maps), one move order across the map, squads starting at mixed headings. Report per order: time until every squad is in,
   how many crews start with their nose > 90 deg off their first route leg, how many first-leg routes cross another squad's, crews'
   blocked-seconds. Give manoeuvre and the orchestrator its hash the minute it runs (manoeuvre's Q1 census reads on it).
2. **O2 a coordinated departure.** From O1's numbers pick the cheapest lever and say why before building: departure order (the squad
   whose path is clear goes first; those behind wait their turn rather than all starting at once), a shared heading (crews turn toward
   the group's direction of travel before setting off), route spread (adjacent squads take non-crossing routes / lanes). Build OFF,
   lab, then file **Bar O2** on 9101-9124 before any number: deciding = every-squad-in time on the group-order workload; guards = never-in,
   G1/G3 lines as round 40 used, fight lines. Name manoeuvre's Q2 switch state (C41.3).
3. **C41.4 getter for camera (on request):** if camera asks, expose a read-only "player is aiming" read (cursor over a pickable target,
   a drag in progress, an order pending) without changing pick behaviour.
4. **Stretch:** G1 v7 (archived Status) on the T1-ON main.

## How to verify

Pure tests (`tests/test_control*.gd`); the probe; `make quick-remote`; a full check of every hash you name. Smoke he can run:
`make skirmish ARENA=terminus SKIRMISH_FLAGS="<O2's flag>"`: select all, send them across, watch them set off.

## Don't touch

manoeuvre's movement/traffic, the planner outside C41.3's grant, camera's `game/camera/**`, settle's deploy functions, `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
