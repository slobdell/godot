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

- Answered 2026-10-03 18:11 PDT on https://claude.ai/artifact/929eYAkRdDCMXArwc7Rja5: B everywhere (CP2). Open: the
  Terminus kerb boxes (parallel, as now, or turned).

## Status

_(the worker keeps this current; newest at the top of each list)_

### Report (newest state)
**He tapped the page (2026-10-03 18:11-18:12 PDT): B on all six dealt maps and both stack close frames; the Terminus
kerb question untapped (boxes against buildings stay parallel).** Built as **CP2 = `2c380daa`**:
`GROUND_SKEW_DEG` 4.0 (40 ft +-1.4..4.0 deg, 20 ft +-2.24..6.4), `STACK_OFFSET_M` 0.45. builder0 check:
`>> remote: make check exited 0`, **1940 passed, 0 failed**, 23 targets, ALL JUDGED, sim-baseline `05df1d55ba49cde1`
(unmoved), determinism `762a0576f944f5b7`. The page now shows B as what ships, A to compare:
**https://claude.ai/artifact/929eYAkRdDCMXArwc7Rja5** (version 3; db `taps` read 18:22 PDT by the orchestrator,
dumped to `references/round17/yard_y5_taps_db.json`). **The contact series at B** (`make container-contacts`, builder0, `2c380daa`, same factions / seeds 1-8 / maps as
CP1; the square arm reproduced CP1's square arm exactly, 32 of 32 runs byte-identical, so the merged code did not move
these fights). Per minute of fight, median; in brackets the seeds (of 8) where the turned layout was higher than square:

  | map | class | square | A (CP1) | B (CP2) |
  |---|---|---|---|---|
  | pit | plant x kturn | 25.9 | 24.7 (4) | 13.4 (2) |
  | pit | into containers | 7.7 | 8.5 (2) | 1.5 (2) |
  | pit | steer | 504.7 | 496.2 (4) | 404.6 (2) |
  | sumps | plant x kturn | 58.0 | 16.0 (0) | 49.6 (2) |
  | sumps | into containers | 8.8 | 2.5 (0) | 14.2 (3) |
  | sumps | steer | 449.3 | 406.4 (3) | **582.7 (7)** |
  | terminus | plant x kturn | 32.2 | 18.1 (2) | 27.3 (5) |
  | terminus | into containers | 0.0 | 0.0 (1) | 2.7 (3) |
  | terminus | steer | 368.7 | 298.0 (2) | 264.2 (0) |
  | yard | plant x kturn | 32.7 | 45.7 (4) | 26.2 (2) |
  | yard | into containers | 23.7 | 25.0 (3) | 22.8 (2) |
  | yard | steer | 383.9 | 323.7 (5) | 377.4 (3) |

  **Reading:** planned-k-turn plants do not rise at B beyond the seeds' spread (turned higher on at most 5 of 8, medians
  at or under square on every map); container plants 2-3 of 8. **The one signal: the Sumps' ordinary route scraping
  (cause=steer) is higher at B on 7 of 8 seeds (449 -> 583 a minute)** -- the routing class, not the planner the
  decision rule names; flagged for the orchestrator and round 18 rather than decided here. Fight lengths (median s):
  pit 146 / 115 / 156, sumps 174 / 176 / 154, terminus 151 / 153 / 167, yard 118 / 180 / 157 (square / A / B).

**CP2's hash table** (`make container-hashes`, builder0, light lane; launch `3713fdaa` / CP1 `1c497496` / CP2
`2c380daa` run twice, identical):

  | layout | launch | CP1 (A) | CP2 (B) |
  |---|---|---|---|
  | barriers | `7951f14ce67e6d97` | `7951f14ce67e6d97` | `7951f14ce67e6d97` |
  | boneyard | `a4d1cfa1bbc65876` | `a7e9c1655aaab9a8` | `bde979049537a4cf` |
  | boulevard | `d3787e44089ea982` | `9c2db8eb1f8d9a29` | `9b421c5d07b6abc5` |
  | crossing | `3193578b6db57b35` | `04b75f7e98563807` | `efc8449e97b18eb1` |
  | crossing_dry | `1c98306756025bcb` | `04456e6aadc906cb` | `136325064735f8f4` |
  | foundry | `05df1d55ba49cde1` | `05df1d55ba49cde1` | `05df1d55ba49cde1` |
  | furnace | `5b042d992bcbf421` | `5b042d992bcbf421` | `5b042d992bcbf421` |
  | locks | `cefaead4ed310afb` | `e7f8165a6d9c9532` | `db5512352146803e` |
  | locks_dry | `e1128772ed76c5ec` | `42ccd555207649cf` | `61674f7f5413423b` |
  | maze | `e49d9ca693d9e0fb` | `e49d9ca693d9e0fb` | `e49d9ca693d9e0fb` |
  | pit | `09b4f609497667eb` | `1047b3acd24f3f85` | `098f7d5cb3795e7f` |
  | pit_dry | `3766470b1aa45475` | `081eda0a24ec5db2` | `eaf578789f9be533` |
  | scrapyard | `19b7973fab33ad9f` | `19b7973fab33ad9f` | `19b7973fab33ad9f` |
  | sumps | `ea7669ae05b1c286` | `4073245c87d5a582` | `bf0bdb98568700db` |
  | sumps_dry | `cf2c0c34cd3276a7` | `256cadbccc71cd8d` | `f336b65717bf731e` |
  | terminus | `8b0309ee85e497dc` | `8b0309ee85e497dc` | `8b0309ee85e497dc` |
  | terminus_canal | `a154a8022abda501` | `a154a8022abda501` | `978a525ca4659e82` |
  | yard | `9c11a32a51781ca1` | `399b261dcf879e15` | `797dc49109a452d8` |

  Every dealt map changes again except the Terminus (its 40 s tank match never reaches the 4 boxes that turn; the
  10 against buildings are parallel by rule); the five layouts without turned containers are identical throughout.

**Guards at B** (all in `make check`): joint rays opened 0 on every layout (mutation opening 60 cm: a 4 deg turn
covers 30); lane / junction loss tolerance 20 cm (was 10 at A), every loss over 10 cm: sumps_dry west causeway 16 cm
(16.78 -> 16.62 m), pit / pit_dry west flank 15 cm (31.52 -> 31.37), crossing_dry west bridge 11 cm, the Pit
junction at (+-70, +-40) 14 cm (4.88 -> 4.74 m, already under its 8.37 m r_eff at launch; report-only map); stacks:
worst upper corner 45 cm off the collider, level-to-level step <= 56 cm, an upper end within STACK_END_M 10 cm of its
collider (it reached 12.4 cm on a 20 ft box before the clamp), wall-flush stacks 0.000 m into a building;
`test_nav_back_and_fill` passes. I looked at all 21 frames at B (`2c380daa`, builder0, airship hidden): rows jog
clearly, upper boxes read crane-placed, nothing new into a kerb, fence, quay edge or building.

**Done (every backlog item; the stream's final state):**
1. **Y1** done: `make container-census` (fails with `CENSUS_MAX_SQUARE`); BEFORE frames from the launch tree.
2. **Y2** done: upper levels crane-placed (`stack_levels`), off a building's wall where a stack stands flush, ends
   within 10 cm of the collider; door ends mixed (stretch).
3. **Y3 / CP1** done, merged (`1c497496`, merge `9314a2db`).
4. **Y4** done: nothing to request.
5. **Y5** done: the page; **his taps: B everywhere** -> **CP2** `2c380daa`, merged (`f8032806`; `main-checked`
   `90c289f2`, 1984 / 0). The Terminus kerb question he left untapped: boxes against buildings stay parallel.
6. Stretch: the census of the other square props (report only, below); door ends mixed.
**Branch:** `90c289f2` merged into `stream/yard` at `37c3b273`; the tip carries only Status, the page tool and the
contact probe / `contact-shot` after CP2.

### What to playtest (exact commands)
`make skirmish ARENA=yard` (and `pit`, `terminus`, `crossing`, `sumps`, `locks`): from your camera, look along a
container run (the yard's columns now step a few degrees box to box) and at a two- or three-high stack (the upper
boxes sit off by up to 45 cm, doors at either end); on the Terminus the boxes against buildings stay parallel to
their walls (your page left that unanswered -- say if you want them turned too). Drive a War Rig through the Sumps'
middle stacks: rigs grind against boxes there (as everywhere, square or turned; round 18).

### Merge notes
- Shared files: `game/arena/arena_kit.gd` gains the look key `wall` (additive). Nothing else outside yard's paths.
- In `make check` (via the test suite): `tests/test_arena_container_stack.gd` (6), `tests/test_arena_container_joints.gd`
  (4: joint rays square vs turned + mutation, lane/junction loss, kerb boxes keep their angle). Targets (none in
  check): `container-census`, `container-frames`, `container-hashes`, `container-contacts`, `contact-shot`; tools
  `container_census.py`, `container_skew.py`, `container_contacts.py`, `container_page.py` (+ `.html`); probes
  `tests/arena/container_frames.gd`, `tests/arena/contact_probe.gd`; frozen square layouts `tests/arena/before/square/`.
- **Changing the amounts:** `game/theme/arena_kit/containers/container_prop.gd` `GROUND_SKEW_DEG` (then `make arenas`;
  a fight change on every map with turned boxes, not the sim baseline: re-run `container-hashes` and
  `container-contacts`) and `STACK_OFFSET_M` (visual only).
- `arena-pytest` is outside `make check` and had rotted for seven rounds (fixed here); worth adding to `check-all`.

### The design, in one place
- **Amounts** (`game/theme/arena_kit/containers/container_prop.gd`, the two lines his page changes):
  `GROUND_SKEW_DEG = 4.0` (his tap, B; CP1 shipped 2.0) -- a 40 ft box on the ground turns +-1.40..4.00 deg (|turn|
  uniform over 35-100 % of it, sign seeded), a 20 ft box `GROUND_SKEW_20_SCALE` 1.6 x that (+-2.24..6.40 deg): both
  move a corner ~0.4 m (~14 px at his pose). `STACK_OFFSET_M = 0.45` (B; was 0.25) -- an upper level's corner sits at
  most 45 cm off the stack's collider (visual), its end within `STACK_END_M` 10 cm.
  Changing GROUND_SKEW_DEG needs `make arenas` and moves fights; STACK_OFFSET_M is visual only.
- **Rules** (`tools/container_skew.py`, run inside `write_v2` on the authored half before the mirror): joints stay
  closed (>= 3 cm overlap or what they had); gaps stay gaps; spawn clearance; deep overlaps turn together; **a box
  flush against a city block keeps the block's angle** (turned, a 40 ft kerb box sinks its far corner ~42 cm into
  the wall -- ~14 px, reads as embedded -- or swings into the street); one flush against a wreck or wall slides off
  to stay flush. `_square=True` on a prop holds it (unused now).
- **Fixtures kept square:** `maze`, `barriers`. Dry twins and `terminus_canal` turn exactly as their wet maps.

### Measurements (every one: commit, machine)
- **Launch tree green:** `make remote T=check` at `3713fdaa`, builder0 (loaded: ~20 other Godot processes):
  `>> remote: make check exited 0`, **1915 passed, 0 failed**, 21 targets all passed, sim-baseline `05df1d55ba49cde1`
  (unmoved), determinism `762a0576f944f5b7`.
- **Arena tests on the turned tree** (laptop, `e509105a` + the generator-test fix): `make test FILTER=arena`
  **134 passed, 0 failed** (lane width and corner validators, readability, spawn envelope, deploy zone, prop parity,
  symmetry, connectivity, the two new files); `arena-pytest` 41 tests OK after `e6cf19ff`.
- **Joints in physics** (`test_arena_container_joints.gd`, laptop): 196 rays per joint (2 heights x 7 x 7 x both
  ways), square vs turned, **opened 0 on every layout**: yard 36 joints, boulevard 10, pit/pit_dry 12, terminus 10,
  terminus_canal 8, sumps/sumps_dry 4, crossing/crossing_dry 2. Rays that got through the square layout and are
  now blocked (grazing rays beside a box slid flush to a block): terminus 28, terminus_canal 28, crossing 4.
  Mutation: a yard joint opened 30 cm lets rays through.
- **Static report, square vs turned** (`tools/arena_report.py`, laptop, `e509105a` vs `3713fdaa` layouts): narrowest
  corridor unchanged on every map except pit/pit_dry 19.0 -> 18.5 m and terminus/terminus_canal 18.0 -> 17.5 (the
  report's 0.5 m grid); all 21 hulls fit everywhere; longest sightline unchanged on every map; mean view moves by at
  most 0.4 m. Terminus avenue lane (GDScript `ArenaLanes`): 17.56 -> **17.17 m** physical (bar 12.14).

- **CP1's first check** (`e6cf19ff`, builder0): `>> remote: make check exited 2`, 1920 passed, **1 failed**
  (`test_nav_back_and_fill::test_driving_it_turns_the_rig_toward_its_goal_without_touching_a_wall`), sim-baseline
  `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`. **Attribution** (laptop, that test, 25 s drive):
  bisected one Terminus container pair at a time on the square layout -- only the avenue's kerb boxes flip it. With
  the first kerb rule (slide flush) the 20 ft box at (+-8.78, +-72) took 14 cm of the avenue (17.56 -> 17.17 m;
  the lane validator's 12.14 m bar can't see that); with a pivot-into-the-building rule (street face unchanged)
  the 40 ft box at (+-8.78, +-60) still flips it while the navmesh edge beside it is 2.04 m (square) vs 2.06-2.44 m
  (turned) from the face. Witness: the planned back-and-fill plants into `Container40_10` (cause=plant,
  driver=kturn, 9 ticks) where the square run has 0. Brains' reading (relayed by the orchestrator): `_outline_ok`
  samples a 14 m hull's sides 3.5 m apart, so a TURNED box presents a corner between two samples; fix ~20 lines,
  brains recommends round 18. **What I changed:** boxes flush against blocks keep the block's angle (above), and
  the guards below. Whether the outline gap matters elsewhere is the contact series (running).
- **Lane guards** (`tests/test_arena_container_joints.gd`, in `make check`): what the lane validators see is each
  declared lane's narrowest corridor width against a 12.14 m bar and each junction's clearance against r_eff -- not
  a turning pocket for a 14 m hull, not a 14 cm loss in a 17.56 m street. So turning has its own rule: no lane loses
  more than 10 cm of its narrowest width (measured worst: 8 cm, dry twins only; every wet map 0) and nothing that
  passed fails; no junction loses more than 10 cm unless it keeps 25 % spare over r_eff (boneyard and the crossing
  lose 12-14 cm at junctions with 4.7-8.6 m spare); every box flush against a block keeps its angle and place.
- **Other props, square share** (stretch, census at `e509105a`, all layouts, not changed -- his item is containers):
  barricades 118 of 132 (89 %), floodlights / signs / ad screens 122 of 124 (98 %), wrecks 0 of 86 (already varied).
  Barricades across the dealt maps (wrecks, floodlights, screens, signs, blocks together): 55-80 % square per map.
- **CP1 = `1c497496`.** `make remote T=check`, builder0: `>> remote: make check exited 0`, **1923 passed, 0
  failed**, 21 targets, sim-baseline `05df1d55ba49cde1` (baseline unmoved), determinism `762a0576f944f5b7`.
- **CP1's own evidence: the baseline match on every layout** (`make container-hashes`: SIM_HASH_READ's doctrines,
  seed 3, 40 s = 1200 ticks; builder0; before = `3713fdaa` from the launch-tree worktree, after = `1c497496` run
  twice, identical). foundry's line equals the sim baseline, so the target runs the baseline's own match.

  | layout | `3713fdaa` | `1c497496` run 1 | run 2 | |
  |---|---|---|---|---|
  | barriers | `7951f14ce67e6d97` | `7951f14ce67e6d97` | `7951f14ce67e6d97` | same |
  | boneyard | `a4d1cfa1bbc65876` | `a7e9c1655aaab9a8` | `a7e9c1655aaab9a8` | **changed** |
  | boulevard | `d3787e44089ea982` | `9c2db8eb1f8d9a29` | `9c2db8eb1f8d9a29` | **changed** |
  | crossing | `3193578b6db57b35` | `04b75f7e98563807` | `04b75f7e98563807` | **changed** |
  | crossing_dry | `1c98306756025bcb` | `04456e6aadc906cb` | `04456e6aadc906cb` | **changed** |
  | foundry | `05df1d55ba49cde1` | `05df1d55ba49cde1` | `05df1d55ba49cde1` | same |
  | furnace | `5b042d992bcbf421` | `5b042d992bcbf421` | `5b042d992bcbf421` | same |
  | locks | `cefaead4ed310afb` | `e7f8165a6d9c9532` | `e7f8165a6d9c9532` | **changed** |
  | locks_dry | `e1128772ed76c5ec` | `42ccd555207649cf` | `42ccd555207649cf` | **changed** |
  | maze | `e49d9ca693d9e0fb` | `e49d9ca693d9e0fb` | `e49d9ca693d9e0fb` | same |
  | pit | `09b4f609497667eb` | `1047b3acd24f3f85` | `1047b3acd24f3f85` | **changed** |
  | pit_dry | `3766470b1aa45475` | `081eda0a24ec5db2` | `081eda0a24ec5db2` | **changed** |
  | scrapyard | `19b7973fab33ad9f` | `19b7973fab33ad9f` | `19b7973fab33ad9f` | same |
  | sumps | `ea7669ae05b1c286` | `4073245c87d5a582` | `4073245c87d5a582` | **changed** |
  | sumps_dry | `cf2c0c34cd3276a7` | `256cadbccc71cd8d` | `256cadbccc71cd8d` | **changed** |
  | terminus | `8b0309ee85e497dc` | `8b0309ee85e497dc` | `8b0309ee85e497dc` | same |
  | terminus_canal | `a154a8022abda501` | `a154a8022abda501` | `a154a8022abda501` | same |
  | yard | `9c11a32a51781ca1` | `399b261dcf879e15` | `399b261dcf879e15` | **changed** |

  Every layout without a turned container (foundry, furnace, scrapyard, maze, barriers) is identical. Every dealt
  map changes **except the Terminus and its canal twin**: 10 of their 14 boxes stay parallel to buildings by rule,
  and the 40 s tank match never reaches the 4 that turn. The longer matches below do: all 8 Terminus seeds differ
  between square and turned (fight length or contact counts).
- **Long hulls' planned k-turns vs turned boxes** (brains' question; `make container-contacts`, builder0,
  `1c497496`: War Rigs (14 m) and Condemned tanks (9.7 m), Gangs v Condemned at 5200, elimination, 180 s cap, seeds
  1-8 per map, the frozen square layout vs today's on the same code; counted every tick from `Movement.state()` up
  to the decision (the headless runner quits there)). Per minute of fight, median, square -> turned, and on how
  many of the 8 seeds turned was higher:

  | map | plant x kturn | of which into a container | steer (old scraping) | fight length s |
  |---|---|---|---|---|
  | pit | 25.9 -> 24.7 (4 of 8) | 7.7 -> 8.5 (2 of 8) | 504.7 -> 496.2 (4 of 8) | 146 -> 115 |
  | sumps | 58.0 -> 16.0 (0 of 8) | 8.8 -> 2.5 (0 of 8) | 449.3 -> 406.4 (3 of 8) | 174 -> 176 |
  | terminus | 32.2 -> 18.1 (2 of 8) | 0.0 -> 0.0 (1 of 8) | 368.7 -> 298.0 (2 of 8) | 151 -> 153 |
  | yard | 32.7 -> 45.7 (4 of 8) | 23.7 -> 25.0 (3 of 8) | 383.9 -> 323.7 (5 of 8) | 118 -> 180 |

  Worst single match, plant x kturn: pit 244 -> 269, sumps 513 -> 342, terminus 455 -> 705, yard 716 -> 450.
  **Reading:** no map's planned-leg plant contacts rise beyond the seeds' spread (no map has turned higher on more
  than 4 of 8 seeds; into containers 0-3 of 8). The same seed is a different fight on the two layouts (yard's median
  length 118 vs 180 s), so this is two populations of 8, not paired replays. Raw lines: `build/container-contacts.jsonl`.

- **Visual commit** `86f0c0d4` (wall-flush stacks, door ends): builder0 `make check exited 0`, 1925 passed, 0 failed,
  sim-baseline `05df1d55ba49cde1` unmoved. **Merge of `ddf710b2`** at `8623d0b4`: `make check exited 0`, 1940 passed,
  0 failed, 23 targets all passed, ALL JUDGED, baseline and determinism unmoved.
- **The frames** (`make container-frames`, builder0, 1920x1080): AFTER at `86f0c0d4`/`51beac50` (spots fixed after
  looking: the Crossing's centre sightline ran through a block, the Locks' east-quay camera sat behind the stands,
  the Pit's close camera stood against the wall); B from the same tree with the two constants at 4.0 / 0.45,
  reverted; BEFORE from `3713fdaa` except four new spots rebuilt from the frozen square layouts with the stack offset
  at 0 (labelled on the page).

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
- **What depends on the two square fixtures** (grep, `e509105a`): the Maze — `tests/test_arena_maze.gd` (gap widths,
  the 3 m tight gate, the dead end, the two serpentines' lengths), `tests/arena/maze_probe.gd` / `make nav-maze`,
  `tests/tactics/defile_probe.gd`, `tools/test_arena_report.py`; the Barrier Line — the stall probes' known pieces and
  gaps (its note), `tests/test_arena_kit.gd` (dealt/cut/fixture), and both appear in the airship's report and test
  (`airship_report.gd`, `test_theme_ad_airship.gd`). **Neither is ever dealt to a player:** the skirmish launcher
  (`game/ui/game_launcher.gd`) offers `Arena.ROTATION` only (yard, pit, terminus, crossing, sumps, locks), and random
  deals from the same list.
- **Y4:** the tactical map is the 3D scene from an orthographic camera (turned boxes draw turned); the lane paint
  (`lane_marks.gd` `footprints_of`) and the block cutaway (`block_cutaway.gd`, the body's live rotation) both read the
  rotated footprint. Nothing to request.
- **Decision:** `maze` and `barriers` stay square (fixtures calibrated on gap widths: the Maze's 3 m tight gate, the
  stall's known gaps). Dry twins and `terminus_canal` turn exactly as their wet maps (the turn is seeded by kind and
  position), so a wet/dry series still compares terrain alone.

### The Sumps' route scraping at B, attributed (the orchestrator's CP2 question)
`make container-contacts CC_MAPS=sumps CC_JOBS=1` on the light lane at `4b780be5` (CP2's layouts; the per-match
totals equal CP2's run exactly), with the probe now counting long hulls' steer contacts per collider. Over the 8
seeds: square 9,915 steer ticks (517 a minute), B 11,463 (601). **The rise is mostly not on containers:**
containers 2,131 -> 2,281 (+150); terrain rims +311, perimeter +336, wrecks +397, floodlights +219, blocks +66, rails
+69. The fights take different routes on the turned map, and the hulls scrape what those routes pass.
The three containers with the largest rise (B vs square, ticks over 8 seeds; their mirrors carry the authored names):
- `Container20_24` at (-38, -16), turned 4.49 deg: 96 -> 339 (mirror of `c20(38, 16, 90, 3)` beside the causeway)
- `Container40_22` at (-8, -30), turned 3.76 deg: 226 -> 330
- `Container20_8` at (-41, -8), turned 2.51 deg: 89 -> 183 (mirror of `c20(41, 8, 0, 2)`)
and the largest falls: `Container20_15` -186, `Container20_3` -158, `Container40_20` -79.
**The one-line option, if he wants it:** hold `c20(38, 16, 90, 3)` and `c20(41, 8, 0, 2)` square (`_square=True` in
`tools/terrain_maps.py`; their mirrors follow) -- it would take back at most the +337 ticks those two drew, about a
fifth of the rise. I would not: the rise is the routes, not the boxes.
**Visible? Yes, as contact, not as a defect:** `make contact-shot SHOT_COLLIDER=Container20_24,Container40_22,Container20_8
SHOT_SEED=6` (builder0, light lane, `4b780be5`+, windowed replay, so not the headless match tick for tick) froze the
first long-hull scrape of one of those boxes: a War Rig with its nose pressed against the end of the three-high
`Container40_22` at (-5.4, -37.8) -- `references/round17/yard_sumps_scrape_close.jpg` (22 m). Physics stops the hull;
nothing passes through the box. At his pose (49 m) the frame from the same instant puts the camera inside the pump
house (the game's block cutaway would hide it; the tool does not), so only the close frame is filed.

### For round 18 (from CP1's numbers; the orchestrator's decision: the k-turn outline fix is round 18)
- **Rigs in streets, the standing state, measured for the first time** (table above, both layouts): a long hull
  (War Rig, Condemned tank) PLANTS into something 16-58 times a minute during planned k-turn legs and SCRAPES
  (cause=steer) 300-500 times a minute, on the square yard as much as on the turned one. The turn did not create this;
  it is what a 14 m hull does in our streets today. Brains' outline-sampling gap (`_outline_ok`: side samples 3.5 m
  apart on a 14 m hull) is the first suspect for the plant share.
- **The Yard is the one map where turned reads higher** (plant x kturn 32.7 -> 45.7 a minute, turned higher on 4 of
  8 seeds). Not significant at N = 8; when the outline fix is tested, run the yard at 16 seeds both ways.
- Regression test for the fix: the Terminus avenue kerb boxes TURNED (bring back the two-pair bisect in this
  Status: either kerb rule flipped `test_nav_back_and_fill` from 0 to 9 planned-leg contact ticks).

### Questions for the lead
- Answered on the page: B everywhere (built as CP2). Still open on it: the Terminus kerb boxes -- parallel to their
  buildings (as now) or turned too?
- Not his item but on the page: the yard's two boxes lying across a column, the Pit's half-overlapping gate pillars
  (18 m gates, the comment says 12), two crossing/sumps boxes partly inside buildings -- fix or leave?

### Requests to other streams
- (none)

### Known issues
- The pre-existing overlaps above (unchanged).
- Rigs scrape and plant into walls in streets on both layouts (round 18, above); not caused by the turn.
- `arena-pytest` is not in `make check` and had rotted for seven rounds (fixed here); worth adding to `check-all`.

### Next steps
- None open in this stream. Round 18 (above): the k-turn outline sampling with the turned Terminus kerb boxes as its
  regression, the Sumps' rigs and containers as nav's first question (the attribution above is its starting point),
  the yard at 16 seeds; his call on the pre-existing oddities and on turning the Terminus kerb boxes.
