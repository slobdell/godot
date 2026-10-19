# Stream: traffic (a crew under fire doesn't step aside into a killing zone when the one behind can go round)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 35** (C35.1, C35.8;
> R34.9, R34.13, R34.15, R34.17, R34.20 in *Round 34*), and your round-34 brief `streams/archive/round34/traffic.md` (its Status is the
> close-out). Evidence: `references/round34/traffic/` (T5 census, x6/x6b series, parkedroom v4/v4b).
> **You own:** the give-way block (`_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`, `_negotiate`, ask, `_begin_yield`,
> `right_of_way`), `game/ai/traffic.gd`, `tests/traffic/**`, `tests/test_traffic*.gd`, `mk/traffic.mk`.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. His answer at round 34's close: **a firing mortar truck keeps
its spot** ("Keep the truck firing"; his round-31 T1c-b2 rule stands).

What he will notice: fewer crews dying while stepping aside for a squadmate in a lane under fire, without the crew behind
stalling there instead.

## Where things stand

- **Shipped in round 34:** O4 (routes are the squad's) and o4b (gates for squads that have the waypoint queued).
- **Parked, each judged twice or more:** parkedroom (v4/v4b: hold-post loops −74 %, the far-loop total is the firing batteries he
  keeps); T4 the ghost (the gain is spent by later rules); **T6/T6b under fire, no give-way** (R34.17, R34.20): refusing every ask
  under fire cut yielding deaths 53–69 % but moved the dying to stuck/blocked/parked one for one; dropping the mid-step abort (c)
  fixed the collision harm. `underfire` is DEFAULT_OFF on stream branches only (not on main); native's mirror `badfdb978` unmerged.
- **T5's census:** jammed-by-friendly deaths 5.6 %, 83 % giving way, 77 % under fire, median jam 1.5 s, lanes 74 %.

## Backlog (in order)

1. **T7 Refuse under fire only when the asker has another way (C35.8).** Design note first, to the orchestrator: how "another way"
   is read (parkedroom's room/route test, a navmesh detour bound, or the asker's own route options), what the asker does when it has
   none (the give-way proceeds as today), and the interactions (the battery rule, the gate, O4 routes). Then tests, then a bar before
   any number: deciding gain jam-under-fire deaths; guards stuck deaths, open deaths, far loops, kills, hit rate, contacts after a
   give-way, crossings (as T6b's); fresh fixed arenas, no twins. Base it on `round34/traffic` (T6b's code) on current main; native
   mirrors from `badfdb978` with the new gate.
2. **Stretch:** the measurement notes for judging.md (random-seed twins are now dropped by `seed_twins.py`; the fresh-folder import
   segfault is intermittent and a relaunch cures it).

## How to verify

Tests first; `make quick-remote`; one full check at a time on builder0; series pinned, fresh seeds, no random twins. Every number:
commit, machine, workload, n.

## Don't touch

Manoeuvre's drive and unstick, brains' and orders' paths, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
