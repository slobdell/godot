> **ARCHIVED: round 10 (2026-09-22 → 23), stream `terrain`.** Every commit named here is merged to `main` (the closing check on `80e3ce90` was green; the last merges after it are listed in `HANDOFF.md`); the round-11 list at the top of Status is the live part. Relative links below were written from `_agents/streams/`.

# Stream: terrain (the maps with water, pits and bridges that never materialised)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction* §"Maps", *The arena* §13 water or pits, *MEASURED: every shipping arena scores `spread 0.00`*,
> *The principle behind all of it: terrain makes risk, objectives make reason*), [arenas.md](../arenas.md) (all of it:
> the vocabulary, the mirror bake, X2/X4, *What I'd build next*, the Terminus trap), [workstreams.md](../workstreams.md)
> (*Round 10: the nine streams*, contracts **R4**, **R9**; round 6's N3 and N7), and
> `game/arena/arena_terrain.gd`'s header (the round-7 mechanism, measured by `make water-probe`).
>
> **You own** new arena layouts (`arenas/<new>.json` and their functions in `tools/make_arenas.py`, ADDITIVE: arena
> owns the file and reviews your diff at merge), `game/arena/arena_terrain.gd`, `tests/arena/water_probe.gd`, a new
> `game/theme/arena_kit/terrain/` for the water/pit/bridge art (feel reviews the look at merge; the `arena.terrain`
> slot is yours to fill), the `water-probe`/`terrain-*` targets in `mk/arena.mk` (additive), and a *Terrain maps*
> section of `_agents/arenas.md`. **Every Godot process runs on builder0** (the laptop is full); write and test
> layouts headless, look at frames from `make remote T=arena-shots`.

## The lead's direction

2026-09-20, evening, verbatim: *"another possible workstream - what about map generation? I had asked about adding
bridges / pits / water elements to create different mapping types, but this never materialized."*

The original ask (game_design.md *The arena* §13): *"We need water or pits - these would be elements that units could
not cross but they could still fire over. Useful for setting up kill zones. i.e. we could have a map that required
crossing some bridges to get to the other side."* And the rule he added on 2026-09-18: *"clearly crossing a bridge is
risky, so you don't want a simple map with 2 sides connecting two bridges. There generally has to be some compelling
reason to cross the bridge to take some advantageous ground."*

## Where things stand (why it never materialised)

- **The mechanism exists and no map uses it.** `ArenaTerrain` (round 7) carves `water` and `pit` rectangles out of
  the navmesh floor, restores a `bridge` deck, puts a 0.9 m rim (a hull stops, a shell and an eye do not) cut where a
  bridge crosses, and a pan underneath. `make water-probe` measured all three claims (impassable, fire-transparent,
  a shoved hull does not fall in). `arenas/*.json` accept a `terrain` list. **Every shipping arena has `terrain: []`.**
- **The art slot is empty.** `Arena._build_terrain()` looks for `GameTheme.slots["arena.terrain"]` and builds nothing
  visible when it is absent, by design ("water with no art is worse than errors"). Nobody has drawn water, a pit or a
  bridge deck. Without art the lead cannot see the feature, which is the literal reason he says it never materialised.
- **A bridge needs a reason to cross, and that gate is now open.** arena measured `spread 0.00` on every map with one
  central objective (nothing to cross for), then authored mirrored objective pairs on yard (0.35) and pit (0.26):
  `objectives: [{name, position, radius}]` in the layout, mirrored pairs enforced by `Arena.validate()`. Each side
  gets one objective it holds cheaply and one it must contest. That is the reward half of his rule; you build the
  risk half.
- **Constraints you inherit:** the navmesh is baked as one half plus its 180° rotation, so every footprint, deck and
  objective is authored on one half and mirrored (`mirrored_props()`, `mirrored()`); footprints are axis-aligned
  rectangles (no diagonal river without a clipper); `MIN_DECK_M` 7.0 gives 3 m of drivable deck at a 2.0 m bake, which
  is single file, and **R4 now says a lane keeps 6.64 m drivable**, so a bridge the War Rig uses is ≥ 10.64 m wide
  physical, and its approaches are corners certified with the rig's turning radius (C5). Large boxes must be tiled
  (`SOLID_FOOTPRINT_M`, the Terminus trap). Spawn clearance and point symmetry are validated at authoring time.
- **The acceptance test is written already:** a bridge is doing its job when the arena report's decision `spread`
  is non-zero AND a match series shows unit-time actually spent on the expensive route (combat's route-time
  falsifier, `make arena-series`); a look alone is decoration. And his eye on the arena page.
- **The default is his Terminus playtest**; a new map is reachable with `make skirmish ARENA=<name>`. The arena menu
  with previews ("Players pick") is control's, later; your maps ship with a title, a note and a thumbnail from
  `arena-report` so the menu has something to show.

## Backlog (in order)

1. **The water/pit/bridge art (the reason he could not see it).** Fill the `arena.terrain` slot: a water surface
   (a flat emissive-tinted plane with the venue's neon reflected, animated by one scalar; no lights, one draw call),
   a pit (dark pan, a lit rim, hazard stripes), a bridge deck (kit steel, the container palette, guard rails BELOW
   the 1.3 m eye line so the rim rule holds). Frames at his pose from `make remote T=arena-shots` before any map
   ships; feel's art review by message. Pre-registered: the sim baseline does not move (visual only).
2. **The first river map ("the Crossing"): two bridges, two reasons.** A river across the centre line (axis-aligned;
   a dog-leg is two rectangles), two bridges off-centre and mirrored, a mirrored objective pair so that each side's
   contested objective sits across the river from its cheap one (his "advantageous ground"), the streets/approaches
   as lanes under R4 (the bridge deck ≥ 10.64 m physical for the rig, corners certified). Author in
   `tools/make_arenas.py`, `make arenas`, `make arena-report`: `spread` > 0 with the number, fairness by the swap-bases
   control (`make arena-series` on builder0), the X2 ambush reach printed. Then a match series: unit-time on the
   bridge route vs the null (no water) on the SAME seeds (C6); the bridge is real when the expensive route is used
   and the flanking rate moves.
3. **The second map ("the Pits"): kill zones without a river.** Pits as islands the routes must thread, sightlines
   across them, objectives placed so the short route crosses a covered pit-side and the safe route is long. Same
   measurements. This is his "kill zones" sentence.
4. **The Terminus with water?** Only if 2 and 3 read well: a canal along one street (the ring road is the candidate,
   with two bridges) would give his acceptance map a crossing. Arena owns the Terminus; propose it with frames, do
   not edit it.
5. **The map page for him:** each new map's whole-arena shot, his-pose shot, the report's numbers (`spread`,
   `centre_sees_share`, reach, fairness), the title and note, on the arena page; sent through the orchestrator.
6. **Stretch:** a diagonal river (needs the clipper: price it first); hazards (`hazards: [{type, position, radius,
   damage_per_second}]`, fire pits that hurt what stands in them; Match applies the damage, so it works headless);
   elevation is NOT in scope (arenas.md item 6: a round of its own).

## How to verify

- `make check` green (`make remote T=check`); `make arenas` reproduces every JSON from the generator; `make water-probe`
  and `make water-probe BRIDGE=1` still pass with your art in the slot; `make arena-report`, `make remote T=arena-shots
  ARENAS=<new>`, `make remote T="arena-series ARENAS=<new> SEEDS=8"`, `make arena-page`.
- `make skirmish ARENA=<new>`: drive a squad over a bridge and around a pit; a shell fired across water lands.
- Every number: commit, machine, seeds; series paired by seed; every frame at his pose with a before (the same map
  with `terrain: []`) beside it.

## Don't touch

`arenas/terminus.json`, `yard.json`, `pit.json` and the existing layouts' functions in `make_arenas.py` (arena's:
propose, do not edit), `game/arena/arena.gd` and `arena_kit.gd` (arena's: request the hook you need), `game/theme/**`
outside `arena_kit/terrain/` (feel's), `game/ai/**`, `game/tactics/**`, `game/control/**` (the arena menu is
control's, later), `game/match/**`.

## Waiting on the lead

His eye on item 1's frames and item 5's page. Neither blocks; the numbers decide whether a bridge is real, his eye
decides whether it is beautiful.

## Status

_Worker: terrain, started 2026-09-22 on `2ee65f94` (= `main` at launch). Every Godot process runs on builder0._

### Plan (ordered; smallest foundation first, each with its test first)

1. **Mechanism fixes the art depends on** (`arena_terrain.gd`, mine): (a) the rim is cut only by a deck that actually
   crosses THAT edge (today any deck overlapping the edge's axis cuts it, so a second river gets a gap where no
   bridge is); (b) **bridge rails**: a deck has no side rails, so a shoved hull can leave the deck into the pan; rails
   0.9 m (below the 1.3 m eye line) along each deck side over the water; (c) rims and rails become navigation
   sources, so the navmesh stops an agent radius short of them (R3's rule: what a hull cannot drive through has a
   collider AND sits in the bake); (d) `MIN_DECK_M` becomes R4's number (2 × widest hull + 2 × agent radius +
   2 × rail), guarded by a test that reads `Units` so a wider bus fails it loudly. `Arena._build_terrain()` becomes a
   one-line delegate to `ArenaTerrain.build()` (arena's file; the hook, listed in merge notes).
2. **The report sees water** (`tools/arena_report.py`, arena's, additive hook): today it ignores `terrain`, so
   `spread` and routes on a river map would be measured as if the river were floor. Water/pit cells become
   undrivable (sight untouched), drawn on the plot. Test in `tools/test_arena_report.py`-style file of mine.
3. **The art** (`game/theme/arena_kit/terrain/`, the `arena.terrain` slot): water (one draw: an emissive plane with
   fake depth by interior mapping and the venue's neon reflected, one animated scalar, no lights), pit (dark pan,
   parallax depth, lit rim), kerbs with hazard stripes (one draw, from the SAME `rim_slabs` as the colliders), bridge
   deck in the container palette with rails below eye line (one draw each). Frames at his pose with a before
   (`terrain: []`) beside each, from a shots tool of mine run on builder0.
4. **The Crossing** (river, two bridges, mirrored objective pair across the river) + its dry twin fixture
   (`crossing_dry`, `terrain: []`, the null arm) → `make arenas`, `arena-report` (`spread`, centre_sees, reach),
   swap-bases fairness, paired series vs the dry twin on the same seeds.
5. **The Pits** (shipped as `sumps`, "The Sumps", beside the kept `pit`) + `sumps_dry`, same measurements.
6. Terminus canal proposal (frames only, arena's map), the map page, stretch (diagonal river price, hazards).

**Decisions (one line each):**
- The brief's "Pits" ships as **`sumps`, "The Sumps"** (a pump house and its sumps): `ARENA=pits` beside the lead's
  kept `pit`, and a booth saying both, is a mix-up waiting to happen. The orchestrator agreed (2026-09-22).
- `ArenaTerrain.min_deck_m()` is READ from `ArenaLanes.bar()` + two rails (arena's ask, Invariant 0), not a literal.
- The null arm for every paired series is a committed FIXTURE twin (`<map>_dry.json`, `fixture: true`, identical but
  `terrain: []`): the series and the before-frames need it loadable by name, and a fixture never reaches a menu.
- Tooling that needs Godot lives in `game/theme/arena_kit/terrain/tools/` (mine), not `tests/arena/` (arena's).

### REPORT (2026-09-22, evening)

**Done for the round. Everything is on main:** `ef29355f` → `4ffb4c1a` (the mechanism, the art, the Crossing, the
Sumps), `2504b1ee` → `4cf545ac` (the uid files), `8b0a879a` → main (both paired series, fairness, feel's look notes,
the Terminus canal proposal). **The check on `8b0a879a`** (builder0, REMOTE_SLOTS=5): 1651 passed / 2 failed,
sim-baseline `11c479c3bec77082` unmoved, determinism `cd43435b56b09acf`, 16/18 targets; the two reds (squad's
drive-to-slots, combat's parked-friend) and the scenario count 40,4 are main's own at `f29c5b7c`, confirmed by the
orchestrator's main check. **Pre-registered UNMOVED held at every check: terrain never moved the sim baseline.**

| Item | State |
|---|---|
| 1. Art in `arena.terrain` | done; **feel ACCEPTED** the look; its two notes (water read as a starfield, pit floor had no depth cue) addressed |
| 2. The Crossing | done: spread 0.55 (dry 0.30), centre 0.29, R4 lanes pass, fair (−0.019 ± 0.067), series: bridges used 31/32 seeds (p < 0.0001) |
| 3. The Pits → **the Sumps** | done: centre 0.34, spread 0.35 (= dry), lanes pass, fair (−0.025 ± 0.035), series: causeways/catwalk used 29/32 seeds (p < 0.0001) |
| 4. Terminus canal | a FIXTURE proposal (`terminus_canal`), frames only; **recommendation: do not** -- it costs the ring-road and plaza-crossing lanes, moves the objective pair, and pushes spread 0.33 → 0.83 (a formality). Orchestrator accepted the recommendation; his call |
| 5. His page | `build/terrain-page/index.html`, frames in `build/terrain-shots/` (paths below) |
| 6. Stretch | diagonal river PRICED (below, ~1.5 days, baker risk first); hazards already work (Furnace; `Match._apply_hazards`), nothing to build |

**What the numbers say, in one paragraph:** terrain decides WHERE the fight crosses (unit-time on the bridges ×8 on the
Crossing, ×1.8 on the Sumps' causeways, both p < 0.0001 over 32 paired seeds), and on the Crossing it is also what
creates the decision (spread 0.55 against its dry twin's 0.30; the contested route 148 → 185 m). It does NOT change
how much time the brains-only CPUs spend at the far objective (both maps: flat, p 0.38 and 0.22) -- that is not
claimed; whether a player's squads take the far objective more is his game to judge.

**Questions for the lead** (none block): (1) the Sumps' centre sees 0.34 -- between the Pit you kept (0.30) and the
Boneyard you cut (0.40); a kill-zone map is open across its pits on purpose; keep it that open? (2) the Terminus canal:
the frames are on the page beside the Terminus; it costs two lanes and moves the objectives -- still want it?
(3) the diagonal river is ~1.5 days: worth it after you have driven the straight one?

**What to playtest:** `make skirmish ARENA=crossing` and `make skirmish ARENA=sumps` (both load by name; neither is in
the random rotation -- that is `Arena.ROTATION`, arena's, one line when you say so). Drive a squad over a bridge and
along a bank (the rails and rims should stop a shove without touching the tracks), fire across the water.

**Requests to other streams (all answered):** arena: the report hook, the objective-reachability test, `ArenaLanes`
reading rims and rails (arena did it, `fb3a1ec7`); announcer: names and clips for `crossing`/`sumps` (landed
`3934f234`); control: the radar and tactical map draw the centre ring on maps whose objectives are a pair (relayed).

**`make water-probe`, rebuilt on the shipping `ArenaTerrain.build()` path, art in the slot (builder0, tip `8b0a879a`
+ docs):** no bridge: the channel is off the mesh (10.1 m), the crossing is unreachable, an eye-level ray crosses, a
hull driven straight at it is stopped by the rim (z 59.1) and never falls; `BRIDGE=1`: reachable at detour 1.00, the
hull crosses, and a hull ordered sideways off the deck ends at x 1.6 m, still on it (rails present), lowest y 0.0.

**Known issues:** the deck is a flat plate at y ≈ 0.07 over a floor at 0 (no ramp; nothing collides with it, so no
hull bumps).

**Round 11, in the order I would brief it:**
1. **His eye on the page first** (`build/terrain-page/index.html`): if the Crossing and the Sumps read as maps he wants,
   one line in `Arena.ROTATION` (arena's) puts them in `make skirmish`'s random draw.
2. **The far objective.** Both series say terrain moves WHERE the crossing happens and not WHETHER the CPUs go for the
   contested objective. If he wants the far objective contested, that is the squad deciders' valuation of an
   objective behind a crossing (squad/combat), measured on these two maps with the same paired series.
3. **A second river map** built to the Crossing's finding (the river IS the decision: spread 0.55 vs 0.30), and the
   diagonal river only after the half-day baker check priced below.
4. `ArenaLanes` calls `rail_slabs` by name (arena, `fb3a1ec7`): now that terrain is on main, arena's lane test sees
   the rails too -- confirm it once.

### The paired series (R9's second acceptance; `make terrain-series`, builder0)

**The Crossing vs `crossing_dry`, 32 paired seeds (1–32), Condemned vs Condemned, budget 5200, 180 s, sim code at
`56691a5b`.** Positive control held on every run (`terrain_entries` > 0 wet, 0 dry, or the pair is refused).

| measure (median) | crossing | crossing_dry | seeds wet > dry | wet < dry | sign test p |
|---|---|---|---|---|---|
| unit-time on the crossings (the bridges' chokepoint regions) | **0.0186** | 0.0024 | **31** | 1 | **< 0.0001** |
| time at the CONTESTED objective / time at either | 0.58 | 0.63 | 13 | 19 | 0.38 |
| hits | 591 | 507 | 23 | 9 | 0.02 |

Winner changed between the arms on 6 of 32 seeds.
- **The expensive route IS used:** unit-time on the bridges goes up 8× with the river, on 31 of 32 seeds. That is R9's
  "unit-time on the expensive route", met.
- **The flanking rate does NOT move:** time at the contested objective is flat (13 vs 19, p 0.38). The river funnels
  the fight onto the bridges (more hits, 23 vs 9) but does not change how much of it happens at the far objective.
  Read: the brains-only CPUs cross where they must and fight there; whether a player's squads would take the far
  objective more is the lead's game, not this series'. Not claimed.

**The Sumps vs `sumps_dry`, the same 32 paired seeds and settings, sim code at `56691a5b` (the tree synced at 15:33,
before any later commit), builder0.** Positive control held on every run.

| measure (median) | sumps | sumps_dry | seeds wet > dry | wet < dry | sign test p |
|---|---|---|---|---|---|
| unit-time on the crossings (catwalk and causeway chokepoints) | **0.0253** | 0.0140 | **29** | 3 | **< 0.0001** |
| time at the CONTESTED objective / time at either | 0.47 | 0.64 | 12 | 20 | 0.22 |
| hits | 482 | 503 | 15 | 17 | 0.86 |

Winner changed between the arms on 2 of 32 seeds.
- **The sumps put the fight on the causeways and the catwalk** (29 of 32 seeds) without changing how much fighting
  there is (hits flat), which is what a kill-zone map should do.
- **The contested-objective rate does not move** here either (12 vs 20, p 0.22; its median falls, not significantly).
  Same reading as the Crossing: the terrain decides WHERE the crossing happens, not WHETHER the CPUs go for the far
  objective. Not claimed.

**Fairness (the swap-bases control, `make arena-series ARENAS=crossing,sumps SEEDS=8`, builder0, code `e1fb2a30`):**
the Crossing's paired south advantage **−0.019 ± 0.067** (8 pairs, 2 winner flips), the Sumps' **−0.025 ± 0.035**
(8 pairs, 1 flip): both inside one standard error of zero, so neither base is favoured that 8 seeds can see. (Median
hit range 28 m and 26 m; the Crossing's flank share 0.73 against the Sumps' 0.28 -- the Crossing's bridges are out on
the flanks by design.)

### For his page (paths in `~/projects/godot-terrain`; the orchestrator copies them)

- **Frames at his pose** (21°, FOV 35, 49 m), each beside the same frame of its dry twin: `build/terrain-shots/`
  (`crossing-{bridge,neck,landing,far_bridge,overview}.png`, `sumps-{catwalk,causeway,lip,far,overview}.png`, the
  `_dry` twins, and `terminus_canal-*` beside `terminus-*` for the canal proposal once shot).
- **The page:** `build/terrain-page/index.html` (`make terrain-page`: frames in pairs, the report's numbers, the
  paired series when it exists). Built on builder0 with the shots.
- **Merged:** `ef29355f` → main `4ffb4c1a` (check on `ef29355f`: 1611/0, sim-baseline `1ea332e7bc268d2a` unmoved,
  17/18; the one red was main's scenario count, since re-recorded at `4ff45e50`).
- **feel's look review: ACCEPTED** (2026-09-22), two non-blocking notes (water read as a starfield; the pit floor had
  no depth cue), both addressed in `water.gdshader` (merged with `8b0a879a`); the frames on the page are the addressed look.

### Stretch: the diagonal river, priced (not built)

**~1.5 agent-days, one real risk.** Everything today is axis-aligned rectangles because the floor is cut by exact
rectangle decomposition. A diagonal (or any polygon) river needs:
1. **The floor and rims as polygons** — Godot already ships the clipper: `Geometry2D.clip_polygons` /
   `offset_polygon` (Clipper2) for arena-minus-water-plus-decks and for the rim ring, then
   `Geometry2D.decompose_polygon_in_convex` into `ConvexPolygonShape3D` prisms. ~4 h with tests. No new dependency.
2. **Rails** along deck edges that border water: deck ∩ offset(water), same primitives. ~2 h.
3. **The shader's union trace** against arbitrary edges instead of boxes (a ray against ≤ 32 segments per kind; the
   hop logic already exists). ~2 h.
4. **The Python mirror** (report routing): rasterise polygons per cell (point-in-polygon), no clipper needed; the
   golden parity test moves from boxes to polygons. ~3 h.
5. `Arena.validate` symmetry for polygons (vertex-set mirror). ~1 h.
**The risk is the baker, not the maths:** the Terminus trap (a box ≥ 8 m on both axes contributes nothing to the
bake) was never characterised for large CONVEX PRISMS as floor pieces. The floor today is huge boxes and bakes fine,
so the trap is likely obstacle-only, but it must be measured first with the water probe on a diagonal channel
(half a day), before anything else is built. Recommendation: build it only if the lead likes the straight river.

### Waiting on the lead

His eye on the page (item 1's frames and item 5's page), and the three questions above. Nothing is blocked.

### Merge notes (shared or other streams' files this branch touches)

- `game/arena/arena.gd` (arena's): `_build_terrain()` is a one-line delegate to `ArenaTerrain.build()`; the body
  moved to `arena_terrain.gd` unchanged except rims/rails are navigation sources and rails are new.
- `tests/test_arena_kit.gd` (arena's): the connectivity test asserts every OBJECTIVE is reachable (the centre only
  when a layout lists none) -- the Crossing's centre is a river and the Pits' a building.
- `tools/arena_report.py` (arena's): +`import arena_terrain`, one `carve()` call in `analyze()`, terrain on the plot.
- `tools/make_arenas.py` (arena's): `write_v2(..., terrain=())` + `terrain_maps.check_terrain`, and the call to
  `tools/terrain_maps.author()` at the end.
- `game/theme/game_theme.gd` (feel's): one `DEFAULT_SLOTS` line, `arena.terrain`.
- `mk/arena.mk`: additive `terrain-*` targets.
- New fixture layouts `crossing_dry`, `sumps_dry`: every all-layouts test now includes them (fixtures).

