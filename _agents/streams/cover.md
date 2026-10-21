# Stream: cover (hull-down behind real low cover)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 37** (C37.1, CP37.1,
> C37.3, C37.4) and `_agents/game_design.md` *OPEN QUESTIONS for him before round 37* (his answers to 3, 6, 9, 11). **You own:**
> `game/ai/cover_map.gd`, `game/ai/tactical_query.gd`, the partial-cover damage seam (one function in `game/combat/armor.gd` called
> from `Match.projectile_impact`; merge note to rules, who own the rest of combat), `arenas/*.json` (low cover only, C37.3),
> `tests/cover/**`, `tests/test_cover*.gd`, `mk/cover.mk`. C++ twins are native's (`cover_native`; you declare, native writes).
> **Model:** Opus. **Machine:** builder2 for series (shared queue: say in Status when you start/finish); light runs on either.

## The lead's direction (2026-10-21, verbatim in game_design.md)

He rejected a dig-in berm: **"the sandbag rings or dirt would just come out of nowhere."** His answer: **"the actual idea of using
real cover would add an important element of the game. If I'm understanding correctly here, idle units that are close to a piece of
cover might drive a very short distance to take advantage of the cover. While we might not have much waist-high cover on our maps
currently, it's certainly something we could add or try out."** On obstacles: **"let's defer on this one. The maps are already kind
of busy."** Wrecks stay passable (contention is his first movement priority).

What he will notice: a tank parked tight behind a low wall or rubble pile takes most frontal shots on the cover; from the side or
behind it is fully exposed; artillery from above ignores it; ordering a squad to the far side of a rubble line v the open street
beside it visibly changes the fight.

## Where things stand

- Cover today is all-or-nothing line of sight: `TacticalQuery.hull_hidden` (centre + HULL_MARGIN either side), `CoverMap.clear_line`,
  `find_cover`, `peek_from`. No partial cover in damage. `Armor.MULTIPLIER` front 0.5 / side 1.0 / rear 1.5 (+ engine-deck weak spot).
- Maps: `arenas/*.json` (13 dealt in sim-baseline). How much waist-high cover exists is UNKNOWN.

## Backlog (in order)

1. **K1 the count.** Per dealt map: the low cover a hull can sit behind with the turret showing (height band, length), where fights
   happen on it (fight census heat if available), and a screenshot page. Report to the orchestrator: which maps already have enough,
   which need RE-SHAPING of existing clutter (no net additions). Any map change is a before/after page for him first (C37.3).
2. **K2 the damage seam.** Switch `--cover-hulldown` (OFF): a shell arriving in the target's front arc whose line passes through low
   cover within a few metres of the hull strikes the cover (no damage) with a probability from the exposed fraction; side/rear arcs
   unaffected; ARC (artillery) unaffected. Lab test both paths (a tank behind a low wall: frontal hits fall by the stated fraction,
   flank hits unchanged). Declare the twin.
3. **K3 the seat API (C37.4).** `TacticalQuery.low_cover_seat(near, threat_dir, max_shift_m := 4.0) -> Variant`, deterministic,
   reachable (navmesh), with a unit test; tell orders when it is on main.
4. **K4 the bar (after CP37.1):** shape C37.2 (deciding the blob line; guards the turtle line, kills, match length, perf).
5. **K5 the map re-shape** he approves, per map, each with sim-baseline attribution (the orchestrator adopts).
6. **Stretch:** the CPU choosing low-cover seats when it defends (a brains-path grant; ask).

## How to verify

Lab tests both paths; `make quick-remote`; screenshots of every map you touch, looked at; series on builder2 on CP37.1's lines; every
number with commit, machine, workload, n. Smoke: `make skirmish ARENA=<a map with low cover>`, park a squad behind it, attack it
head-on, then from the flank.

## Don't touch

Rules' paths (the rest of combat, tank, match), orders' seat laying (you provide the query; they call it), `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

The map page (K1/K5) when you have it: the orchestrator relays.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
