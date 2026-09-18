# Stream: arena (terrain that makes ambush and flanking possible, and the maze nav is measured against)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*, *The arena*), [../workstreams.md](../workstreams.md) (you own **N3** and **M2/C5**),
> [../arenas.md](../arenas.md), and your round-5 report in [archive/round5/arena.md](archive/round5/arena.md) —
> including the 240-match series saved in [references/arena_series_round5.json](references/arena_series_round5.json).
>
> **You own** `game/arena/`, `arenas/`, `tools/make_arenas.py`, `mk/arena.mk`, `_agents/arenas.md`.

## The lead's direction (2026-09-18, verbatim)

> *"The maps are still pretty basic, right now the game is just this big open brawl with dumb units. We want to be able
> to set up ambushes, do flanking maneuvers."*

> *"We might even want a map that's a quasi maze just for test purposes to ensure units can get through it."*

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

- Seven layouts exist: `boneyard, boulevard, foundry, furnace, pit, scrapyard, yard`. Schema and kit are documented at
  `game/arena/arena.gd:1-30`: `obstacles`, `props`, `spawns`, `spawn_zones`, `lanes`, `regions`, `hazards`.
- `Arena._build_obstacles()` (`arena.gd:100-124`) makes a `StaticBody3D` + `BoxShape3D` per obstacle;
  `OBSTACLE_SIZES` (`arena.gd:35`): crate 4.5×3×4.5, wall 18×3×1.5. The navmesh is baked at startup from the southern
  half plus a 180° mirror (`arena.gd:84-97`), because an asymmetric bake gave the south base a 64% win rate
  (trip-up 21). `validate()` enforces point symmetry.
- **Your own round-5 measurement is the reason this brief is short on "more maps" and long on "shape":** flanking
  routes took 4–5% of unit-time on dense layouts against 14% on foundry, and three streams independently landed on
  the same explanation — **a single central control point overrides every tactical choice**, so terrain has nothing to
  decide. combat separately measured median hit range at 39–43 m on *every* map. More props will not fix that.
- Wrecks are on physics layer 4 **on purpose**, so they never block driving and the startup-only navmesh never goes
  stale. nav may want to change that (its X9); it is a conversation, not a unilateral change.

## Backlog (in order)

**X1 — the maze, on day one (N3, CP2).** `arenas/maze.json`: the quasi-maze the lead asked for by name. It is a
**test fixture, not a shipping map** — say so in the file and in `arenas.md`. Requirements:
- built from the existing kit (containers, walls, barricades), point-symmetric like every arena so `validate()`
  passes;
- a start zone big enough for 30+ vehicles and a far objective, with a route that is genuinely non-trivial: at least
  one gap only ~1.5 vehicle-widths wide, at least one dead end, at least two alternative routes of different length;
- reachable — verify the navmesh actually connects start to objective before handing it over (a maze whose navmesh is
  disconnected will read as a nav bug for a day).
Then `make nav-maze` (the target lives in `mk/arena.mk`; nav reads its output): send N units across and report
arrivals, time to 50/90/100%, unit-seconds under 0.5 m/s, stuck events, and any unit that ends up off the navmesh.
**Message the orchestrator the moment it is on the branch** — nav's acceptance test is blocked on it, and this is a
day-one job, not a week-one job.

**X2 — approaches that are not covered from everywhere.** The lead wants ambush and flank to be *possible*, which is a
property of sightlines, not of prop count. For each shipping arena, build and measure:
- **covered approach routes** — a path from a spawn toward the objective along which a unit is exposed to less than
  some fraction of the defending positions;
- **sightline breaks** deep enough that an element can cross without being seen from the centre;
- **overwatch positions** that dominate a lane but can themselves be flanked.
Publish the numbers per arena (extend the existing `make arena-report`): exposure along the best three routes, the fraction of
the map visible from the centre, and the longest sightline. A map where the centre sees everything cannot host an
ambush, and that is measurable before anyone plays it.

**X3 — objectives that pull play off the centre line.** Your own finding, and the orchestrator's pick for the highest-
leverage change this round: the single central control point funnels the whole fight. Try, and measure:
- two or three objectives away from the centre line, or
- an objective that moves or rotates during the match, or
- per-arena objective placement that suits the terrain rather than the map's midpoint.
Measure it as a **control that cancels the suspected cause** (lesson 22): the same arenas with the objective moved,
paired and mirrored — not more seeds of the same thing. The claim to test is "flanking-route unit-time goes up and
median hit range goes down when the objective is off-centre."

**X4 — terrain features, not just props.** Everything in the kit today is a box on a flat floor. What makes an ambush
work is ground that hides an approach: sunken lanes, raised platforms with limited ramps, a long wall with two gaps,
a building footprint you can go around either side of. Check what the navmesh and the vehicles can actually handle
(slopes need `agent_height`/`cell_height` care — trip-up 23) and add what survives. Coordinate with feel on how new
terrain types dress.

**X5 — the arenas the lead will actually play.** He has still never said which arena is fun ("Not played yet", his
round-5 sign-off). `--arena=random` is the default and he picks in control's ARENA row. Make sure every shipping
arena is worth landing on, and cut or fix any that measures as a brawl.

**X6 (stretch) — destructible cover.** Approved by the lead in the round-5 sign-off and deliberately not landed then
(two cross-stream changes at once make failures unattributable). The design is settled: **a stack collapses to a lower
stack, never changing drivable space.** Only start it once X1–X3 are done and nav's avoidance has landed, and
coordinate with nav — anything that changes what blocks driving touches the navmesh.

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `make arena-test` and `make arena-report` (both exist) on every layout you touch; `Arena.validate()` is the point-symmetry gate.
- **The swap-bases fairness control after any arena, spawn or navigation change** (invariant 4,
  [../verification.md](../verification.md)). A symmetric map does not give a symmetric navmesh (trip-up 21).
- Judge arena art and shape from `--skirmish` screenshots, not only the follow camera — the overview is orthographic
  at ~3 px per metre and art thinner than 0.5 m vanishes (trip-up 46).
- Match series for tactical claims — and **run the configuration players actually get** (lesson 23): faction armies,
  30 a side, default flags. Never publish a number measured across combat's CP4 range change.
- You **must not** move the sim baseline (invariant 2). If a layout change moves it, that is a finding: say so.

## Don't touch

`game/ai/**` (nav's and squad's), `game/control/` `game/ui/` `game/camera/` (control's), `game/units/` `game/combat/`
`game/match/` (combat's), `game/theme/**` (feel's — including how your props are *dressed*; you place, feel dresses).

## Waiting on the lead

1. **Which arena is fun** — still unanswered from round 5. If you can put a page of arena screenshots plus their
   measured shape in front of him, do it, and tell the orchestrator.

## Status

_The worker keeps this current._
