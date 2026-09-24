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

_Updated 2026-09-24 ~04:00 by the arena worker. **Merge here: `abb5be04` is green** (builder0: `make check exited 0`,
1689 passed / 0 failed, 18 targets, sim-baseline `457b5e830708b439` unmoved). The commits after it are Status/doc only.
Baseline at the start: `a04d75c0` green on builder0 (1686/0)._

### Round 11 verdicts (the lead, 2026-09-24, relayed by the orchestrator): landed at `91dd8b5e`
1. **Crossing + Sumps KEPT**: in the kept list of `test_random_deals_only_the_maps_the_lead_kept`.
2. **The Locks: DEAL IT, recording approved.** "the Locks" is in `assets/announcer/lines.json`'s vocabulary (text only).
   **No audio generated.** The recording run below is the orchestrator's to start; the Locks is dealt in the SAME commit
   as its clips (see *The Locks' recording run*).
3. **The Pit DUG**: four corner pits ship in `pit.json`; the Pit he kept is the fixture `pit_dry` (one line to undo in
   `tools/make_arenas.py`); frames in `_agents/streams/references/arena/pit-dug-2026-09-24/`.
4. **Water: next round.** Written up in `arenas.md` *Water reads black* (diagnosis from the shader, maps, his pose,
   frames, suggestions); a pointer at the top of `roadmap.md`'s next-round section. Not started.
5. **The Locks' canal stays open** (orchestrator's ruling), recorded beside the layout in `terrain_maps.py`; ask him
   again after he has driven it.

### The Locks' recording run (lead-approved 2026-09-24; NOT run: waiting on the orchestrator)
- **Dry run** (laptop, `91dd8b5e`, nothing sent): `python3 tools/announcer/generate.py --dry-run --only-values locks`
  → **18 requests, 2,071 characters, ~2,071 credits** (Caller 4 / 285 chars, Veteran 1 / 67, PA 13 / 1,719), plus
  speech-to-text on ~2 minutes of audio. Round 10's Crossing + Sumps run was the same shape (36 requests, 4,196).
- **The real run** (needs `ELEVENLABS_API_KEY`; `generate.py` appends the ledger row to
  `assets/announcer/ledger.md` itself):
  `python3 tools/announcer/generate.py --lead-approved --only-values locks --note "r11: the Locks (arena A3), the 18 arena lines"`
  (`make announcer-generate APPROVED=1` has no `--only-values` pass-through, so call the script directly.)
- **The 18 lines** (each recorded with "the Locks" in place of `{arena}`): caller.intro.01, caller.intro.02,
  caller.intro.09, caller.intro.22, pa.welcome.01, pa.welcome.02, pa.welcome.05, pa.welcome.07, pa.welcome.08,
  pa.welcome.10, pa.welcome.11, pa.welcome.13, pa.welcome.14, pa.welcome.21, pa.welcome.23, pa.welcome.25,
  pa.sponsor.10, color.lore.11.
- **Then, in ONE commit with the clips and manifest:** in `tools/terrain_maps.py` `locks()` drop `fixture=True`;
  `make arenas`; add `"locks"` to `Arena.ROTATION` and to the kept list in
  `test_random_deals_only_the_maps_the_lead_kept`; `make announcer-check` must pass (`test_arena_names`); then
  `make remote T=check`. arena will do this commit the moment the clips exist, if asked.

### Summary
| item | state | commit |
|---|---|---|
| **A1** deal Crossing + Sumps; fail on any built-and-unpublished map | **done** | `3ba40e51` (green in `87d83217`) |
| **A2** venue floodlight towers | **done**: moved outside the wall; parity test covers the dressing | `a909a14d` (green in `87d83217`) |
| A1.4 play each map on the default path | **done**: `make terrain-drive` + frames | `87d83217`, `f30dbf0d` |
| **A3** a new map | **built, measured, on his page; waiting on a LEAD GATE** (recording its name) | `abb5be04` |
| **A4** (stretch) the Pit gets pits | **fixture proposal on his page** | `ece226b8` |

**His review page: https://claude.ai/artifact/DUa5fN72G9YDTjLYRFkuj6** (private to his account; version 3 built from
`abb5be04`). It covers the rotation now, the Locks, the Crossing and Sumps with squads crossing, the dug-Pit
before/after, the Terminus tower before/after at his pose, and five questions.

### Done, with measurements
- **A1.** `Arena.ROTATION` = yard, pit, terminus, **crossing, sumps**. `Arena.CUT` holds his cut list in code.
  `test_every_built_map_is_dealt_cut_or_a_fixture`: every layout in `arenas/` must be exactly one of fixture / CUT /
  ROTATION. **Verified failing** on the old rotation (it named crossing and sumps) and passing on the new one.
  `test_every_dealt_map_has_a_title_and_a_note_that_names_its_terrain`: the existing notes already qualify. Other
  consumers of the list (lesson 43), re-run green: `test_arena_cover_tables`, `test_control_faction_pick`,
  `test_arena_maze`, `announcer-check` (crossing and sumps were already recorded in round 10). `make nav-fight-maps`
  reads ROTATION from the code (nav's file, untouched).
- **Bridges and pits as built:** a bridge is restored ground at y = 0 between two carved holes, drawn as a 0.07 m deck
  with 0.9 m rails, and nothing drives under it. A pit is a hole with no navmesh and a 0.9 m kerb; you cannot fall in.
- **A2.** `test_the_venue_dressing_is_solid_or_outside_the_wall` builds the shipping dressing per non-fixture layout
  and fails on any floor-standing drawn mesh inside `ArenaShape.contains(shape, half_size)` that isn't inside a
  `navigation_source` box. On the old tree it named **exactly the towers** (6 per hexagon, 4 per square) and nothing
  else, which also closes A2.4's sweep. **Decision: move the towers outside the wall** rather than make them solid in
  place. The fight loses no floor, the navmesh and lanes don't move (no lane narrowed), and the in-play floodlight
  stays the solid kit prop. Each tower sits on its corner's line, past the wall's outer corner by the model's bounds
  half-diagonal (≈5.8 m) + 1 m. Looked at: before/after at his pose on the Terminus's east corner, and the overview
  (six towers between the stand banks, nothing clipping).
- **terrain-drive** (`make terrain-drive`, new): a player squad ordered over each terrain map's crossings via
  `Orders` (source: player), with arrivals, contacts by cause, ticks inside a hole, `--trace`/`--trace-full` dumps,
  and `DRIVE_TERRAIN_SHOTS=1` frames at his pose. Results (seed 1): **Sumps** mixed + rigs pass both legs;
  **dug Pit** passes; **Locks** passes on the laptop, builder0 rendered 6/6 + 5/6 (an IFV 6.4 m short, `blocked_by`
  a parked squadmate); **Crossing** fails on nav's follower deadlock (below). **Zero ticks in any hole, every map,
  every run.** War Rigs report `arrived` 8–15 m off their slots (their arrival reads wider than the probe's 7 m bar).
- **A3: the Locks** (`tools/terrain_maps.py` `locks`), my own design rather than promoting `terminus_canal`, which is
  his acceptance map redesigned (ring road and objective pair gone). A canal wall to wall, the lock in the middle
  (16 m) and a swing bridge on each flank (14 m), four lock houses round the lock, 13.8 m quay roads, the objective
  pair on the far quays. **arena-report** (pure Python): spread **0.453** (dry twin 0.344), routes 174.9 / 110.5 m,
  centre sees **0.45** (flagged for his eye: open water; the Sumps ships at 0.34). R4: every lane ok, every corner
  clears the rig. **Paired series** (builder0, `abb5be04`, 32 seeds, condemned mirror, 180 s, `make terrain-series
  TERRAIN_MAP=locks`): crossing share 0.0182 vs dry 0.0062, higher on 31/32 (sign test p ≈ 0); contested-objective
  share 0.535 vs 0.643, lower on 27/32 (p = 0.0001); hits +42.5 median (22/10, p = 0.05); 3 winner flips. **Both routes
  are used:** crossing time is lock 63%, swing bridges 18% + 19%; the lock appears in 32/32 matches and a swing bridge
  in 31/32. terrain-drive caught three layout faults the static report cannot see, all fixed: an objective on a lock
  house's corner, quay stacks in the quay roads' mouths (1697 rig contact ticks), and a 5.8 m slot against the rim.
- **A3 is waiting on a LEAD GATE.** The Locks went into the rotation at `231c838d`; `f30dbf0d`'s check went red on
  `announcer-check` only, because `test_arena_names` requires every dealt map's name recorded for the 18 `{arena}`
  lines, and new spoken text is paid generation behind his approval. So it's a fixture (`abb5be04`). **On his
  yes:** `make announcer-generate` for "the Locks" (18 clips), drop `fixture=True` in `locks()`, `make arenas`, and add
  `"locks"` to `Arena.ROTATION` and to the pending list in `test_random_deals_only_the_maps_the_lead_kept`.
- **A4: the Pit, dug** (`pit_dug`, fixture): four 14 m pits at the ring's corners outside the diagonal walls, with
  not one container moved (inside the ring every pit that fits leaves a 2–5 m slot against the walls). Spread 0.658
  (Pit 0.67), centre 0.32 (0.31): the fight is unchanged and the pits become visible. **On his yes:** move the terrain
  onto `pit` in `make_arenas.py` and drop the fixture (the Pit is already recorded, so no gate).

### Known issues
- **Crossing: nav's follower deadlock** (artillery parked on a waypoint at a bridge exit, `stalled_s` 0, nothing
  fires). Reported to nav directly (the orchestrator session refused four SendMessages); **nav fixed it on
  `stream/nav` `e62383ad`** (the chord fallback returned the corner under the hull). builder0's rendered run showed two
  more units `driving` 140 m short on the Crossing's far bank; this looks like the same bug but is unconfirmed. Re-run
  `make terrain-drive` after nav merges.
- **Water renders near-black** at his pose (round 10's `water.gdshader`, `water_deep` ≈ 0.01, theme layer, not
  arena's). It's a question on his page; I haven't changed it.
- The rendered and headless runs of the same seed differ (Locks leg 2: 6/6 laptop headless vs 5/6 builder0 rendered).
  Treat one seed as one sample, not a regression test.

### What to playtest
- `make skirmish ARENA=crossing`, `ARENA=sumps` (or Random: they're in the deal now); `ARENA=locks` and
  `ARENA=pit_dug` load by name even as fixtures. Order a squad over a bridge and watch the exits.
- Look at a Terminus corner: the 21 m towers are outside the wall now; the 3 m floodlight footing is the solid one.

### Requests to other streams
- **nav:** the Crossing repro above (sent directly, fixed at `e62383ad`); after merge, `make terrain-drive` is a cheap
  regression for it.
- **airship / fleet (C11.1):** the rotation now includes crossing and sumps; re-walk your map lists after the merge.

### Merge notes (shared files)
- `game/theme/cyberpunk/arena_dressing.gd`: only `TOWER_INSET` → `TOWER_CLEARANCE`, the two tower placement calls,
  and new `_tower_base` / `_tower_radius` beside `_build_tower`. `_build_airship` untouched.
- `tests/test_arena_prop_parity.gd`: one new test appended.
- Everything else is in arena's paths: `game/arena/arena.gd`, `tests/test_arena_kit.gd`, `tests/arena/terrain_drive.gd`,
  `tools/terrain_maps.py`, `mk/arena.mk`, `arenas/{locks,locks_dry,pit_dug}.json`, `_agents/arenas.md`.

### Questions for the lead
- Crossing and Sumps (and Terminus) are in the rotation without your verdict; each comes out in one line if you say no.
- **The Locks: deal it?** A yes also approves recording "the Locks" for the 18 announcer lines that name the arena.
- The Locks' centre sees 45% of the field (open water by design): the kill zone you want, or more cover on the quays?
- The Pit, dug (four pits at the ring's corners): make it the Pit, or leave the Pit as you kept it?
- Water renders as a dark channel: should it look wetter? (theme layer)
