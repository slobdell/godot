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

_(the worker keeps this current)_
