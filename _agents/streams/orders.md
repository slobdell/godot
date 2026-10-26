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

### NOW (2026-10-26)
- **Plan:** O1 census probe (done, 8b828ec59) -> census on builder0 dev seeds 7001-7006 (crew v formed headings) -> hash to
  manoeuvre + orchestrator -> O2: pick the lever from the numbers, build OFF, lab, file Bar O2 on 9101-9124 before any number
  -> C41.4 getter if camera asks -> stretch G1 v7.
- **Decisions:**
  - "8+ squads" in the brief: the game fields at most `Units.MAX_SQUADS` = 5 squads a side (garage and skirmish), so his
    biggest group order is five FULL squads (25 crews, `tests/control/orders_probe_group_5.json`, mixed tanks/IFVs/scouts).
  - Mixed headings: every crew a seeded random heading just before the click (`--probe-headings=crew`), as squads stand
    after a fight; `formed` (untouched) is the control.
  - "Across the map": the click is the point opposite his army through the arena's middle, halfway to the far edge
    (`--probe-target=across`), so every squad drives 110-150 m through streets; the base probe's deck click is short.
  - Blocked-seconds are split by Movement's own phase: `blocked` (by a friend), `yielding` (stepping aside), `slow` (any
    other under-way tick < 1 m/s, its own turn on the spot included).
- **O1 first look (laptop, 8b828ec59-equivalent tree, terminus s7001, crew headings, n 1):** all in 75.4 s; squads 1 and 5
  (the flanks) 75 / 63 s, the middle three 23-39 s; squad 1 drove 224 m for a 150 m route; 12 of 25 crews nose > 90 deg
  off their first leg; first-leg crossings 0; crew-seconds under way: yielding 80, slow 60, blocked 10.
