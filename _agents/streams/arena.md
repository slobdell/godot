# Stream: arena (maps worth fighting over)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*, *The arena*, *The arena kit*), [../workstreams.md](../workstreams.md) (**M2 is yours and is
> CP2**), [../doctrine.md](../doctrine.md) (what formations and drills need from terrain) and
> [../verification.md](../verification.md) (the swap-bases fairness control). You own `game/arena/`, `arenas/`,
> `tools/make_arenas.py`, a new `mk/arena.mk`, and a new `_agents/arenas.md` (your design doc).

## The lead's direction (2026-09-17)

> *"the maps are just too simple. We probably need a dedicated agent to formulate maps. I'm also not seeing the assets
> I asked for earlier like the big dystopian TV screen in the match or the shipping containers as re-usable components
> in the arena. As far as I know there's only one map right now and it's boring and doesn't provide any meaningful way
> to do tactics."*

## Where things stand

- Three layouts exist as data (`arenas/foundry.json` — round 1's arena, `scrapyard.json`, `furnace.json` with fire
  pits), but the default is flat and sparse: a handful of crates and walls on a 240 m square.
- **The arena kit is built and almost unused:** `prop.container_20` / `container_40` (ISO sizes, stackable, one
  MultiMesh per kind, faction stencils), `prop.ad_screen` (a 7 × 14 m LED wall with channels and ad copy),
  barricades, gates, floodlight towers, neon signs, `prop.wreck`. Placing them costs nothing at generation time.
- Armies are now ~30 a side (44 for the gangs), so spawn zones and frontages sized for 10 vehicles no longer fit.
- Doctrine measures formations and drills against terrain: a wedge beats a column *because* of frontage and cover, and
  bounding overwatch needs somewhere to bound *to*. Flat ground makes all of it pointless.

## Backlog (in order)

**X1. Layout schema v2 (M2; CP2).** Extend `arenas/<name>.json` to carry the kit: `props` with `type`, position,
rotation and `stack` for containers; ad screens; barricades; signs; wrecks. Add per-arena **spawn zones sized for 30+ a
side**, and annotations the AI can read (lanes, cover clusters, open ground). Keep it point-symmetric and validated,
keep `--arena=<name>`, and keep the loader honest: unknown prop types fail loudly. Tell combat when it lands (they
build collision and navigation from it) and render (they dress it). **Announce CP2 as soon as it's green.**

**X2. What makes a map tactical.** Write `_agents/arenas.md` first: the vocabulary you'll build with (lanes,
chokepoints, cover clusters, sightline breaks, hard cover vs soft, flanking routes, high-traffic centre vs safe
flanks), what each does to the game we actually have (fire arcs, suppression, spotting ranges, turning circles), and
how you'll test that a map delivers it. Cite doctrine's measurements where they apply.

**X3. Four arenas with different characters,** built from the kit: for example a **container yard** (dense lanes,
short sightlines, ambushes), a **boulevard** (long fire lanes broken by screens and barricades, artillery matters), a
**pit** (a low centre overlooked from the edges, a control-point brawl), and a **scrapyard** (irregular cover, no
symmetry of shape but symmetric of value). Each ships with a one-line description of the fight it wants to produce.

**X4. Prove they work.** For each arena: the swap-bases fairness control (neither side wins by starting position), a
seeded match series, and measurements that the map does what X2 says — average engagement range, how much of a crossing
is exposed, how often flanking routes get used, how long a unit can stay hidden. Numbers in `_agents/arenas.md`.

**X5. Dressing and spectacle.** Place the ad screens where the camera sees them, containers stacked into real cover,
signs and floodlights on the stands, wrecks as permanent cover where it helps. Coordinate with render's frame budget
(M1): props are cheap per kind but not free per instance.

**X6. Arena selection.** `--arena=` everywhere, a random-but-fair default, and a short note in the Status on which
arena suits which faction matchup (the gangs' swarm wants lanes; the Syndicate's range wants the boulevard).

- **Stretch:** simple destructible cover (a container stack that collapses); a layout generator that proposes
  candidates for a human to approve, once X2 says what "good" means.

## How to verify

`make remote T=check`, the fairness control per arena, seeded series, and `make remote T=skirmish-shots --arena=<name>`
screenshots of each map **looked at**. A spectator's description of how a fight in each one differs.

## Don't touch

Vehicle art, props' materials and the frame budget (render), weapons and rules (combat), brains (ai), UI and camera
(control).

## Status

- 2026-09-17: brief written for round 5.
- 2026-09-17 (worker started): plan, in order, smallest foundation first:
  1. **X1 schema v2 (CP2)**: `ArenaKit` (game/arena/arena_kit.gd) as the gameplay truth of each kit prop; `props`,
     `spawn_zones`, `lanes`, `regions` in the layout; the loader normalizes colliding props into `obstacles` so every
     current consumer (CoverMap, radar, ElementSituation, navmesh) sees them with no change on their side. Tests first
     (`tests/test_arena_kit.gd`). *Decision:* v1 layouts stay valid and unchanged, so the sim baseline doesn't move.
  2. **X2 `_agents/arenas.md`**: the vocabulary grounded in measured mechanics (eye 1.3 m, muzzles 1.05-1.27 m,
     doctrine's 45 m terrain count, 85 m support range), rules of thumb, and the measures.
  3. **X3 four arenas** (yard, boulevard, pit, boneyard) authored in `tools/make_arenas.py`, iterated against
     `tools/arena_report.py` (static views, routes, exposure, plots). *Decision:* new names; foundry/scrapyard/furnace
     keep their names and content (the announcer and tests reference them).
  4. **X4 proof**: swap-bases fairness and seeded series per arena, dynamic measures into arenas.md.
  5. **X5 dressing** with render's M1 budget, **X6 selection** (random-but-fair default; the sim baseline pinned to
     foundry so a new default doesn't move the hash).
