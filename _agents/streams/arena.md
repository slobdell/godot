# Stream: arena (the maps he has never been dealt, and the 21 m spotlight he drives through)

> Read [`game_design.md`](../game_design.md) *Round 11 direction* first, then [`arenas.md`](../arenas.md) and
> [`workstreams.md`](../workstreams.md). **You own** `arenas/`, `game/arena/`, `tools/make_arenas.py`,
> `tools/terrain_maps.py`, `tools/arena_report.py`, `mk/arena.mk`, `tests/arena/`, `tests/test_arena*.gd`,
> `_agents/arenas.md`; **plus two carve-outs from the theme layer** (below): the venue floodlight tower in
> `game/theme/cyberpunk/arena_dressing.gd`, and `tests/test_arena_prop_parity.gd`.

## The lead's direction (2026-09-23, night)

> *"we still barely have any maps, I haven't seen any bridges or pits that I've asked for, there have been no new
> maps."*

> *"Also, I notice that units can still drive right through the spotlight assets in Terminus; solid objects should not
> intersect."*

## Where things stand (surveyed before this brief was written — check each claim, do not trust it)

### The maps exist. The rotation table is the whole bug.

`Arena.ROTATION := ["yard", "pit", "terminus"]` (`game/arena/arena.gd:63`) is the **only** list the faction picker
offers (`GameLauncher.arena_choices()`, `game/ui/game_launcher.gd:75`) and the only thing `--arena=random` can deal
(`Arena.resolve_name`, `arena.gd:618`). `arenas/` holds fifteen layouts.

**Round 10's `terrain` stream built exactly what he is asking for and it has never been reachable from the game:**

| layout | terrain | what it is |
|---|---|---|
| `crossing.json` | 3 water + 2 bridge | the river map, objective pair "the west landing", half_size 140, hexagon |
| `sumps.json` | 4 **pit** + 2 bridge | the pit map, objective pair "the far causeway" |
| `terminus_canal.json` | 2 water + 6 bridge | **a fixture**: the canal proposal cut through the Terminus |

**This is the third time this exact failure has cost him a round**, and the test that was written to stop it is the
one you will edit: `tests/test_arena_kit.gd:205 test_random_deals_only_the_maps_the_lead_kept` exists because his
CUT verdict on the boulevard and the boneyard *"sat in a document for a full round while `--arena=random` kept
dealing him boulevard and boneyard"*. It asserts the cut maps are absent and the kept ones present — and it never
asked whether the maps built since are there at all. **A decision that lives only in prose is a decision the game
does not have; so is a map.**

**What is NOT a gap:** the boulevard, boneyard, foundry, furnace and scrapyard are **CUT by the lead**
(`game_design.md:756`, the arena verdict read back from the review page's store). They stay out. `maze` and
`barriers` are instruments. Nothing here re-opens his verdict.

**What IS a real gap in the same sentence:** `arenas/pit.json` has no `terrain` key at all. "The Pit" is a ring of
stacked containers with four gates — a name, not a pit. He has asked for pits twice. `sumps.json` is where the pits
actually are.

**Know what a bridge and a pit ARE here before you show him one** (`game/arena/arena_terrain.gd:39-43`): the world
is flat. A **bridge is a restored strip of ground at y = 0** between two carved holes, drawn at `DECK_TOP = 0.07` m
with 0.9 m rails — a causeway, not an elevated span, and nothing drives underneath. A **pit is a hole with no
navmesh and a 0.9 m kerb** (`RIM_HEIGHT`, under `Perception.EYE_HEIGHT` 1.3 m, so hulls stop and shells cross) — you
cannot fall in. That is honest and it is what ships; say so in your Status in one line so nobody promises him a
viaduct.

### The spotlight he drives through is the *venue tower*, not the kit prop

There are two different floodlight things on the Terminus and only one is solid:

- **The layout prop is solid and correct.** `ArenaKit.PROPS["floodlight"] = {"size": [2.4, 3.0, 2.4], ...}`
  (`game/arena/arena_kit.gd:33`) — a 3 m concrete footing; `Arena.normalize()` appends it to `obstacles` and
  `_build_obstacles()` gives it a `StaticBody3D` in the `navigation_source` group.
- **The venue tower is a 21.1 m Meshy model with no collision at all, and it stands on the playfield.**
  `game/theme/cyberpunk/arena_dressing.gd:11` says *"Visual only, no collision"*; `_build_tower` (`:568`)
  instantiates `kit_floodlight_tower.tscn` (roof 21.138 m per the kit manifest) straight into `structures`.
  `_build_polygon_venue` (`:278`) puts one at **every polygon corner pulled 9 m inward** (`HALF 121`,
  `TOWER_INSET 112`). On the Terminus (hexagon, half_size 140) that is **(±131, 0), (±65.5, ±113.45)** — roughly
  7.8 m *inside* the wall faces, on drivable baked navmesh. The two on the x axis stand **3 m from the real
  floodlight props at (±128, 0)**: a 21 m tower you drive through, beside a 2.4 m footing you don't. That is exactly
  what he saw.
- **Why round 10's parity fix missed it:** `tests/test_arena_prop_parity.gd:124` iterates `ArenaKit.PROPS` only, and
  `:144` iterates layout props with `collides: false`. Neither test can see `ArenaDressing` at all. The rule it was
  written for is in `game_design.md:2190`: *"Every prop a vehicle cannot drive through has a collider AND sits in the
  navmesh bake; a prop without a collider is a decoration and lives where no vehicle drives."* The towers are the
  only dressing piece inside the play area, and they break both halves of it.

## Backlog (in order)

### A1. Deal him the maps that already exist (this is the round's first deliverable, and it is small)

1. **Test first**, in `tests/test_arena_kit.gd` beside `test_random_deals_only_the_maps_the_lead_kept`: every
   **shipping, non-fixture** layout whose terrain the lead asked for is in `ROTATION`. Write the assertion so that a
   *future* map built and not published fails here — the generalisation of the bug, not the instance. Rewrite that
   test's header comment to record that it failed to catch a second instance and how the new assertion closes it.
2. Add `crossing` and `sumps` to `Arena.ROTATION` with the one-line reason per map in the comment above it, the way
   the existing comment does for `terminus`.
3. **Every map in the rotation needs a `title` and a `note`** — the picker draws both (`faction_picker.gd:214-223`)
   and the note is what tells him what the fight is *about*. Check all five; write the missing ones so the note names
   the terrain ("a river with two crossings", "pits between the causeways").
4. **Play each one on the default path and look at it.** `make skirmish ARENA=crossing`, then `sumps`: a squad
   ordered across a bridge, a screenshot of the water, a screenshot of a pit with hulls stopped at the kerb. Lesson
   23: the flag nobody passes has not shipped — and here the whole item *is* the default path. Check each new map
   against the harnesses that already walk every layout (`test_arena_kit.gd:158` connectivity, `test_arena_lanes`,
   `test_spawn_grid`, `test_arena_terrain`) and against `make arena-report` for `spread`.
5. `make nav-fight-maps` warns on a stray/missing map against `Arena.ROTATION` (`mk/nav.mk:145`) — expect it to have
   something to say and fix what it says. **Message the orchestrator the moment A1 is green**: nav's Terminus work
   and fleet's gallery both care that the rotation moved, and the drive test's map list is nav's.

### A2. Solid means solid: the venue towers (his second sentence)

1. **A failing test first**, in `tests/test_arena_prop_parity.gd`, extending it to the `arena.dressing` layer: build
   the dressing for each shipping layout and assert that **anything inside the drivable area with a footprint has a
   collider and is in the `navigation_source` group** — derive "inside the drivable area" from the layout
   (`Arena.shape`/`half_size`), never from a hard-coded coordinate (lesson 3). It must fail on today's tree.
2. Fix it. The tower is 21 m of steel standing on the floor: **give it a collider sized to its base and put it in the
   bake**, so the navmesh routes around it and hulls stop at it, exactly like the kit floodlight. Take the box from
   the model's own bounds, not from a guess (`_bounds(model)` is already read at `arena_dressing.gd:580`), and match
   the kit's rule that the mast above the cover height is "too thin to be cover" — the *base* is the solid, not the
   lamp bank. A moved navmesh is a real change: re-run the connectivity and lane tests, and say in your Status
   whether any lane narrowed.
3. **Then ask the second question, which is the better one:** should a 21 m tower be inside the wall at all? It is
   placed 9 m inside the polygon corner because that was written for a square venue at `half_size` 120; on a hexagon
   at 140 the corner is a different place. Decide between "solid where it stands" and "move it outside the wall and
   let the kit floodlight be the in-play one", record the one-line reason, and prefer the one that costs the fight
   less floor space. Either answer satisfies his rule; say which you picked and why.
4. Sweep for the rest of it: the survey found **no `StaticBody3D`/`CollisionShape3D` anywhere under `game/theme/`**.
   Stands, gates, wall ad screens and neon signs are all non-solid, and all of those are *outside* the wall — so they
   are decorations living where no vehicle drives, which is legal. Confirm that per layout with the new test rather
   than by eye, and list anything else it catches.

### A3. A new map, because "there have been no new maps" is also literally true

After A1 and A2 are green. `terminus_canal.json` already exists as the **canal proposal** (2 water, 6 bridge, cut
through the city) and is a fixture. Promote it or build one new terrain map of your own design, your call, judged by:
`make arena-report` `spread` > 0 (an objective pair worth crossing for — his own rule that a bridge needs something
on the far side), the connectivity test, the lane widths for the rig, and a paired match series showing the expensive
route is actually used. **Put the frames on the arena review page and message the orchestrator the link** — his eye
is the only check that counts for a map, and he is asleep, so it goes on the page and he sees it in the morning.

### A4 (stretch). The Pit deserves its name

`pit.json` is KEPT by his verdict, so do not redesign it. But the terrain mechanism could put real pits inside that
container ring without moving a single container. Cheap, and it answers "I haven't seen any pits" twice over. Only
after A3, and only with the before/after on the review page.

## How to verify

- `make remote T=check` on builder0, read from the wrapper's own `>> remote: make check exited <N>` line and the
  runner's `N passed, M failed`. **Never through a pipe.**
- `make arena-report` then `make remote T=arena-shots` then `make arena-page` (his review page);
  `make remote T=terrain-shots` then `make terrain-page` for the water/bridge maps beside their dry twins;
  `make terrain-series TERRAIN_MAP=crossing` for "is the expensive route used" on paired seeds;
  `make skirmish ARENA=<map>` for the default path; `make water-probe` for the mechanism itself;
  `make nav-fight-maps` for the rotation warning.
- **Look at your screenshots.** A bridge you have not seen a tank cross is not a bridge that works.

## Don't touch

`game/ai/**` (nav's: the driver and the planner), `game/units/units.gd` and the vehicle meshes (fleet's),
`game/theme/arena_kit/airship/**` and `game/camera/**` (airship's). In `game/theme/cyberpunk/arena_dressing.gd` you
own `_build_tower` and the venue placement calls only — **`_build_airship` (`:140-155`) is airship's**; keep your
diff to your functions and say so in your merge notes.

## Waiting on the lead

Nothing blocks you. A3's frames and A4's before/after go on the arena page for his morning.

## Status

_(the worker keeps this current: plan, what's done with measurements, decisions and their reasons, questions for the
lead, requests to other streams, known issues, what to playtest, next steps, merge notes, and the commit hash whose
own check went green)_
