# Stream: manoeuvre (the last odd-looking side steps and stuck crews)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 37** (C37.1, C37.7)
> and in *Round 36*: R36.27, R36.28, R36.31, R36.32. Then your round-36 brief `streams/archive/round36/manoeuvre.md` (its Status is
> the close-out). **You own:** in `movement.gd` the `drive()` body, `_nose_stop`, `unstick`, `_pressing_escape`, the
> k-turn/planned-reverse executor and the side-step rule (h1bside); traffic's give-way block (`right_of_way` .. `_blocker`, `_avoid`,
> `_around_friends`, `_ask_behind`, `_hull_within`) and `game/ai/traffic.gd` (traffic has no stream this round); `tests/manoeuvre/**`,
> `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`, `mk/manoeuvre.mk`, `mk/traffic.mk`.
> **Model:** Opus. **Machine:** builder0 (C37.1); light runs on either builder.

## The lead's direction

**"the feel of the game needs to have the user perceive that the units are smart and under their control"** and **"the general
priority is to mitigate vehicle contention with one another"** (game_design.md, round 36). A behaviour with a good internal reason
that LOOKS dumb counts against the game.

What he will notice: a crew blocked by a long friend seen at an angle stops trying the same side step every few seconds; fewer crews
left wedged behind their squad.

## Where things stand

- **S2a ON** (main eee5b0afa, R36.32): far loops 91 -> 35, left behind 77 -> 65 / 768 runs (builder2). **T8 ON** (R36.12).
- **Eyes_3 (R36.31):** `_side_clear` tests only the POINT against hull centres, never the DRIVE to it against the friend's oriented
  box; a long hull at an angle blocks the drive and the crew picks nearly the same point every ~3 s (9 picks, net 1.0 m). 17
  crew-friend pairs reached the side rule in 48 fights; 15 fired once, 1 twice, Eyes_3 9 times.
- **WEDGE_TRACE** on main has no `unstick_fires` total (R36.32; the judge rebuilt it from rows).
- **S1 stallnet** failed its series (R36.27: an unstick storm, kills up); parked OFF on `round36/manoeuvre`.

## Backlog (in order)

1. **M1 Eyes_3's stand rule** (fix (ii)): a side step that ends still blocked by the same unmoved friend makes the next far fire a
   stand. Deciding lab case: a long friend at 30–45 deg (both paths). Bar in *Bars (round 37)* before numbers; native twins the change.
   Symmetric: a pass ships ON.
2. **M2 the `unstick_fires` total** in main's WEDGE_TRACE, so `s1_judge.py` reads it (census lint N5: it must print).
3. **M3 S1 v2:** a design note to the orchestrator on what a fresh stall net would do differently from R36.27's (no code before a
   ruling).
4. **M4 once rules' R3 (suppression slows) is ON:** re-read wedge and left-behind lines on main; report any rise.
5. **Stretch:** the post-deploy twitch that is neither depth nor seating (orders' engagement / stopped short / traffic split), trace only.

## How to verify

Lab cases first; `make quick-remote`; one full check per named hash; series on fresh seeds; every number with commit, machine,
workload, n. Smoke: `make skirmish ARENA=locks`, two squads through one street.

## Don't touch

Orders', rules', cover's, feedback's paths; brains' paths; `native/**`; `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
