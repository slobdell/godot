# Stream: yard (containers that look placed by people: every map, every stack, the truth turning with the picture)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 17 direction* (his words, the
> measured state) and *The arena kit*, `_agents/arenas.md`, `_agents/workstreams.md` *Round 17* (C17.1: **you are the
> round's one baseline mover, once, as CP1**), `_agents/determinism.md`. You own `tools/make_arenas.py`,
> `tools/terrain_maps.py`, `arenas/**`, `game/arena/**`, `game/theme/arena_kit/containers/**`,
> `game/theme/arena_kit/prop_container_*.tscn`, `tests/arena/**`, `tests/test_arena*.gd`, `mk/arena.mk`, the arena report
> tools, and `tests/baselines/**` **for CP1 only**.

## The lead's direction (2026-10-03)

> *"For all of the containers that we have on our maps, in all cases they are completely aligned and completely
> orthogonal, and it looks completely synthetic as a result. Containers stacked on top of each other are done so
> perfectly. For all cases of containers on maps, I think we should rotate them just slightly so that it doesn't look
> synthetic."*

Read: **all cases** — every map he can play and every stack, ground level and upper levels both. **Just slightly** — a
row still reads as a row, a wall is still a wall; he is asking for the hand of a crane driver, not the Boneyard's
wreckage. This is subjective: **his eye is the only check that counts**, so the deliverable that closes the stream is a
page of before/after frames at his pose that he looks at, not a number.

## Where things stand (counted at `6adf94bb`, from `arenas/*.json`)

- **668 containers in 15 layout files (dry twins counted): 448 at exactly 0°, 172 at exactly 90° — 93 % square to the
  grid.** Per file: barriers 114 (all 0°), maze 152 (148 at 0°), yard 98, pit / pit_dry 38 (28 square), sumps /
  sumps_dry 32, boneyard 28 (none square: the one map that already looks right), boulevard 26, crossing / crossing_dry
  24, locks / locks_dry 18, terminus 14, terminus_canal 12. 492 are stacks of two or more.
- **Layouts are generated**: `tools/make_arenas.py` (`make arenas`) authors one half and `mirrored_props` writes its 180°
  mirror, so anything authored in the half is fair by construction. `prop()` / `c20()` / `c40()` take `rot`; `run()`
  lays a straight wall of containers end to end with no rotation at all. Never edit `arenas/*.json` by hand.
- **A layout `rotation_deg` turns the collider with the picture** (`game/arena/arena.gd` ~275 obstacles, ~375 props), and
  the rotated footprint is already consulted by the cover tables (`cover_tables.gd`), the lanes
  (`arena_lanes.gd`, `ArenaKit.distance_to_footprint`), lane readability, spawn clearance, the overlap check
  (`arena.gd` ~975), `tactics/element_situation.gd`, `tactics/army_layout.gd`, the airship's truth, the lane paint
  (`lane_marks.gd`) and the terrain visual. So rotation is a supported input everywhere; what has never been tested is
  *hundreds* of slightly-off boxes at once.
- **The stack already jitters, invisibly.** `containers/container_prop.gd` `_register`: levels above the ground get
  ±0.6° and ±4 cm; level 0 gets nothing. At his pose (21° pitch, FOV 35, 49 m: about 3 cm a pixel at 1080p — recompute
  it yourself) ±4 cm is one pixel and 0.6° moves a 40-footer's corner 6 cm, two pixels. To read from his camera an offset
  wants roughly 20–30 cm at a corner: about 2–3° on a 40 ft box, 3–5° on a 20 ft one. Those are starting points, not
  the answer; the frames decide.
- The collider of a stack is **one box** scaled in height (gameplay's); the visual is per level through
  `ContainerYard`'s MultiMesh (one draw per kind per cell — keep that; `make arena-kit-measure` prints the draws).

## Backlog (in order)

- **Y1. The before, at his pose, and a census that can fail.** `make container-census` (new; your `mk/arena.mk`): per
  layout, containers, the share within 0.5° of square, the distribution of yaw, stacks and levels — the 93 % above
  reproduced. `make remote T=arena-shots` and `T=terrain-shots` on the launch tree, kept as the BEFORE set (copy them
  out of `build/` at once: the next run overwrites it). Look at them and write in Status which maps read most
  synthetic and why (long `run()` walls? identical stacks? rows parallel to the screen edge?).
- **Y2. The stack: upper levels visibly placed by a crane.** In `container_prop.gd`: per-level yaw and offset large
  enough to read at his pose, seeded as now (position + level, so a map is the same picture every launch and in every
  screenshot test), each level's footprint staying on the one below (no level overhangs so far it would fall; corner
  castings roughly over corner castings) and inside what the single collider box makes believable (a shell that meets
  the box where no steel is drawn, or passes through drawn steel, is a defect he will see — state the worst case in cm).
  Tests first: the transforms are deterministic; the largest overhang; the draw count unchanged
  (`arena-kit-measure`). Visual only: **pre-register the sim baseline UNMOVED for Y2 and prove it.**
- **Y3. The ground level turns for real (CP1, the round's one baseline move).** Decide and record first: the
  orchestrator's lean is that the truth turns with the picture (a layout `rotation_deg`, a few seeded degrees per
  container, authored in the half so the mirror keeps the map fair), because a visual-only yaw on the ground puts a
  40-footer's drawn corner ~0.3 m from its collider and tanks hug these corners. If you find the truth-turning route
  breaks something a round cannot fix, the visual-only route with a stated worst-case mismatch is the fallback — say
  which and why. Then, in `make_arenas.py`: a seeded skew in `prop()`/`c20()`/`c40()` and in `run()`, written into the
  JSON (the JSON stays the single truth; no runtime randomness in the sim). **The traps, each a test before the change:**
  - **A wall must stay a wall.** Two neighbours in a `run()` turned different ways open a wedge at their ends; a 6 cm
    wedge is invisible to him and wide open to `has_line_of_sight`'s physics ray and to a shell. For every run that was
    solid before: no sight ray and no shell passes between its containers after (sample rays across every joint, both
    directions; mutation-check the test by opening one joint). Close joints by construction (pivot and spacing so ends
    overlap rather than gap) and make the overlap check accept that.
  - **No new way through and none lost**: `make arena-test` (schema, collision, symmetric navigation, connectivity),
    `make arena-report` corridor widths and the lane validators (no lane narrower than before by more than a stated
    tolerance), spawn clearance, `make remote T=nav-maze` (arrivals, crawling, stuck — the Maze is 152 containers of
    wall), `make remote T=terrain-drive` for the bridge maps.
  - **Fairness holds**: the point symmetry test, then `make remote T=arena-series` on the maps he plays (swap-bases).
  - **Fixtures are not maps.** If a layout exists as a test instrument with calibrated expectations (`barriers`, the
    Maze's nav probes, `tests/arena/before/**`), find out what depends on it before turning it; his words are about the
    maps he plays (list which layouts the skirmish and garage offer). A fixture may stay square with one line saying so.
  - **The sim baseline moves, on purpose, once**: pre-register which arena the baseline match runs on and whether it
    holds containers; `make remote T=sim-baseline-record` twice, the two lines identical, copied over `tests/baselines/`
    in the same commit as the layouts, the commit message saying why. `make determinism` holds. This commit alone is
    **CP1**: message the orchestrator with the green hash; it is merged alone and the other streams are told.
- **Y4. Everything drawn from the layout still agrees with it.** The tactical map's container footprints
  (`game/ui/tactical_map.gd` — not yours: if it draws square boxes for turned containers, request it through the
  orchestrator with a frame), the lane paint stopping short of turned boxes, the camera's block cutaway
  (`game/camera/block_cutaway.gd`, read-only), the cover the brains take (a unit "behind" a turned corner is behind it:
  `make remote T=ai-scenarios-check` counts unchanged or explained, `make tactics-drills`).
- **Y5. The page for his eye.** Before/after pairs of every map he plays at his pose, plus two close frames of stacks,
  on one Artifact page with a tap per map (looks right / too much / too little — the `db` capability; load the
  `artifact-design` and `artifact-capabilities` skills; C15.2: record when its `db` was last read). The amounts are two
  numbers in one place (ground degrees, stack offset) so his "too much" is a one-line change. Send the link to the
  orchestrator. **Look at every frame yourself first**: a container floating over a kerb, sunk in a ramp, or poking
  through a wall, a fence or a screen is yours to find, not his.
- **Stretch.** The same census for the other square props (crates, barricades, floodlight towers, wrecks, signs): report
  the share that is square and a frame, do not change them — his item is containers, the rest is his call. Doors: real
  rows mix door-end directions; if the look table always faces doors one way, vary it (visual only).

## How to verify

`make remote T=check` green on every commit you report (read the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe). Arena: `make arena-test`, `arena-pytest`, `arena-report`, `container-census`. Frames:
`make remote T=arena-shots`, `T=terrain-shots`, `T=arena-kit-gallery` — **open them and look**. Baseline: UNMOVED through
Y1–Y2, moved exactly once at Y3, never after. Every number with its commit, machine, workload and sample.

## Don't touch

`game/ai/**`, `game/tactics/**` (brains) · `game/match/**`, `game/tank/**`, `game/combat/**`, `game/units/**` (sim) ·
`game/theme/audio/**`, `game/audio/**`, `assets/audio/**` (guns) · `export_presets.cfg`, `mk/web.mk`, `mk/core.mk` (ship) ·
the rest of `game/theme/**`, `game/ui/**`, `game/camera/**`, `game/garage/**` (nobody this round: request through the
orchestrator). No paid generation: this stream spends nothing.

## Waiting on the lead

- His taps on the Y5 page (the amounts). Until then the amounts are your judgment from the frames.

## Status

_(the worker keeps this current; newest at the top of each list)_

### Plan (in order) and state
1. **Y1 census + BEFORE frames** — `make container-census` built (it reproduces the brief's count, below). BEFORE
   frames: taken on the launch tree `3713fdaa` itself (detached checkout), because `make remote` syncs the working
   tree when it starts. _In progress._
2. **Y2 stack offset** (visual, `container_prop.gd`) — built and tested locally; check pending.
3. **Y3 ground turned in the truth** (`tools/container_skew.py` inside `write_v2`) — built, joints tested in physics
   locally; check, arena-test, nav-maze, terrain-drive, arena-series pending. CP1.
4. **Y4** — tactical map: nothing to request (it is the 3D scene through an orthographic camera, so turned
   containers draw turned). Lane paint, cutaway and cover: after Y3's check.
5. **Y5 page**, then stretch.

### Findings
- **The sim baseline cannot be moved by the layouts:** `sim-baseline` and `determinism` both run on `foundry`
  (`Arena.DEFAULT_LAYOUT`; neither passes `--arena`), and `foundry.json` holds **0 containers**. Pre-registered: CP1
  leaves sim-baseline `05df1d55ba49cde1` and determinism UNMOVED. The orchestrator has been told (2026-10-03).
- **Census at `3713fdaa` (static, the JSON):** 668 containers in 15 files, **620 (92.8 %) within 0.5° of square**;
  dealt maps: yard 98/98, crossing 24/24, sumps 32/32, locks 18/18, terminus 14/14, pit 28/38; 492 are stacks.
- **Faults in containers that were already there** (seen in the joint census, `3713fdaa`; frames to confirm):
  yard's `c40(-100, 36)` and `c20(100, 50)` lie across the x = ±98 run (two containers through each other, 2.1–2.3 m
  deep); the crossing's `c20(-42, 80)` is fully inside a city block's footprint edge (2.44 m); the sumps' `c20(70, 44)`
  is 1.03 m inside a block; the Pit's gate pillars are two 20 ft boxes at 3.03 m spacing (half-overlapping:
  `make_arenas.py` subtracts 3.03 where 6.06 was probably meant, so the gate is 18 m, not the 12 m its comment
  says). Geometry the series were measured on, so not changed silently; listed here for the page.
- **Decision (Y3, truth vs visual):** the truth turns with the picture, as the orchestrator leaned. Reason: the
  turning code already had every consumer of `rotation_deg` reading the rotated footprint, and the joint rules can
  be enforced at authoring time; visual-only would leave a 40-footer's corner ~0.2 m from its collider where tanks
  hug walls.
- **Decision:** `maze` and `barriers` stay square (fixtures calibrated on gap widths: the Maze's 3 m tight gate, the
  stall's known gaps). Dry twins and `terminus_canal` turn exactly as their wet maps (the turn is seeded by kind and
  position), so a wet/dry series still compares terrain alone.

### Questions for the lead
- (none yet; the amounts are on the page when it is up)

### Requests to other streams
- (none)

### Known issues
- (see Findings: the pre-existing overlaps)
