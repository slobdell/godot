# Stream: arena (the Terminus streets are lanes; what a hull can touch has a collider; the spawn grid gives a hull room to turn)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*, *The arena*, *Round 9 addition*), [workstreams.md](../workstreams.md) (*Round 10: the eight
> streams*, contracts **R3**, **R4**, checkpoint **CP2**; *What reads `hull_size`*), [arenas.md](../arenas.md), and
> scale's round-9 brief [archive/round9/scale.md](archive/round9/scale.md) — its "ROUND-10 HANDOVER" is where the
> arena paths were left, and its spawn-grid item is yours.
>
> **You own** `arenas/`, `game/arena/` (including `arena_kit.gd`'s `PROPS`: the collider boxes), `tools/make_arenas.py`,
> `tools/arena_report.py` and siblings, `mk/arena.mk`, `_agents/arenas.md`, `tests/arena/`, `tests/test_arena*.gd`,
> and the carve-out from combat's C1: `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING` in `game/match/match.gd` (combat
> reviews at merge). `tools/roster_scale.py` and `mk/scale.mk` are yours to run, not to change.

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> I'm playong on the terminus map, and I want to gauge how smart units are by trying to navigate them through the
> city. But there streets are blocked with these shipping containers so there's almost no passageway. Some problems
> though - vehicles are going straight through and overlapping with some of the assets (like the lights).

And from the afternoon (game_design.md, 2026-09-20 afternoon): *"these containers in the middle of the road make it
hard to tell if the section is just impassible - I'll know that they units are doing what I want when I can navigate
them through the Terminus streets."*

The orchestrator's decision (game_design.md *Round 10 direction* §4): **streets are for driving.** Containers and
props stand on lots, against walls and at kerbs, parallel to the street, never across it; every lane keeps a
continuous drivable width; a prop a vehicle cannot drive through has a collider that covers what a hull can touch.

## Where things stand

- **`arenas/terminus.json` is GENERATED** by `tools/make_arenas.py:619-711` (the `terminus` list; `mirrored_props()`
  at `:171` supplies the north half; `PRESERVED_KEYS` keeps only `show` from a hand edit). Edit the generator, run
  `make arenas`, commit both.
- **Containers sit IN the lanes.** The lanes declared in the file: `the avenue` (x = 0, width 18), `west street` and
  `west street (far)` (x = ±70, width 18), `the ring road` ×2 (width 20). In the generator: `c20(0, 30)` and
  `c40(0, −34, stack=2)` are ON the avenue; `c40(±70, ∓8)` and `c20(±70, ±30)` are ON the west street; the form-up line
  `c20(−42, 80)`, `c20(0, 80)`, `c20(42, 80)` (and mirrors) runs ACROSS the front of each base. The comment at `:632`
  says they are there "so a 20 m street is a fight and not a corridor". His verdict is that they read as impassable.
- **The kit:** `ArenaKit.PROPS` (`game/arena/arena_kit.gd:16-32`) gives each prop its collider box and cover class;
  `Arena.load_layout` (`game/arena/arena.gd:642-656`) folds colliding props into obstacles, built as `StaticBody3D`
  under `Obstacles` (`:294-317`), which is in the `navigation_source` group, so they ARE in the bake.
  `Arena._obstacle_shapes()` (`:321-364`) tiles boxes over `SOLID_FOOTPRINT_M` 6.0 into 4 m slabs because the baker
  ignores large boxes silently (the measured table is in the comment).
- **The lamps** (`floodlight(14,14)`, `(−35,31)`, `(66,6)` + mirrors, `:660-683`): `PROPS["floodlight"]` is
  `{"size": [2.4, 3.0, 2.4]}`, "the concrete footing; the mast above it is too thin to matter". feel's mesh
  (`game/theme/arena_kit/kit/kit_yard.gd:205-219`) draws the footing, a lattice mast and a 4.2 m lamp head, and
  `KitProp` is visual-only ("the collision box is Arena's"). **Whatever he saw a vehicle pass through, the parity test
  (R3) is the instrument:** measure every prop's mesh AABB against its box and print the overhang.
- **No passability check exists at runtime.** `Arena.validate()` (`arena.gd:697-800`) checks keys, symmetry and spawn
  clearance. `tools/arena_report.py` has `corridor_widths()` (`:341`) and a deliberate WATCH line (`:214-221`): "a
  check that fails on an open question is an advocate rather than an instrument". For LANES the question is no longer
  open: he ruled. It becomes an assertion for lanes and stays a watch line for the open field.
- **The bake radius is 2.0 m** (`game/arena/arena.tscn:17`, mirrored by `NAV_AGENT_RADIUS`), nav reads it live. 14 of
  21 hulls have an avoidance radius above it, but nav corrected that number: it compares a turning envelope to a
  driving clearance. For a LANE the number that matters is the widest hull's WIDTH (the War Rig, 3.32 m) plus the
  bake on each side: R4 sets the bar at 2 × 3.32 m drivable (physical ≥ 10.64 m at a 2.0 m bake).
- **The spawn grid** (scale's round-9 item 5, yours now): on combat's settle-tick tree four crews overlap at spawn
  (across gaps −1.36, −0.02, −0.01, −0.77 m) and the off-slot crews of `test_five_squads_ordered_in_quick_succession`
  never departed because their first turn was refused in the press. The grid spaces by WIDTH where turning needs the
  HALF-DIAGONAL (tank 4.47 m, `gang_tank` 7.19 m against half-widths 1.20 and 1.66). One number, two sites, opposite
  errors (the disc sites in `match.gd` must NOT be "fixed" the same way; see *What reads `hull_size`*).
- **The arena page** (`make arena-page`, needs `make arena-report` and `make remote T=arena-shots`) is his review
  surface; `make terminus-alleys` shoots the alleys at his pose.

## Backlog (in order)

1. **R4: the Terminus lanes (CP2, merged alone, early).** Failing test first: for every declared lane, the narrowest
   drivable width along its length (physical minus 2 × the live bake radius) ≥ 6.64 m, computed from the layout's
   colliders the way `corridor_widths()` does. It fails today on the avenue and the west street. Then move the
   furniture: containers to the kerbs PARALLEL to the street (a 12 m container along a 20 m street's edge leaves 14 m
   physical), the form-up lines to the base's flanks or gone, the plaza clear, wrecks in lots. Add the east street
   (x ≈ 60..80) and the plaza crossings to `lanes` so the assertion covers what he drives. Keep 180° rotational symmetry
   (`mirrored_props()`) and the spawn clearance. Re-run `make arena-report`; the WATCH line becomes an assertion for
   lanes only. **Before/after at his pose** (`make remote T=terminus-alleys` and `arena-shots`), on the page, with each
   street named. Pre-register: the sim baseline does NOT move (the baseline match runs on the foundry); if it does,
   that is a finding to chase, not a record.
2. **R3: prop collision parity.** A test that instantiates each kit prop's mesh (feel's `kit_yard.gd` builders) and
   compares its AABB below 6.2 m (the tallest hull plus its yaw reach) against `PROPS[kind].size`; a failure names the
   prop and the overhang in metres. Fix by widening the box (the floodlight's head footprint; a container's doors if
   `doors="open"` draws them swung out) or by a request to feel to move the geometry above 6.2 m; the test decides.
   The bake reads the same boxes, so nav's obstacles follow.
3. **"Is this passable" as a read.** After item 1 the streets are open; make sure they READ open at his pose: no
   container end-on across a sightline down a street, kerb furniture visibly at the kerb. One frame per street on the
   page; feel's art review by message if you are unsure.
4. **The spawn grid gives a hull room to turn** (carve-out: `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING`). Failing
   test: on the settle-tick tree every spawned pair's turning envelopes are disjoint (the separating-axis test from
   squad's `test_match_spawns_and_results` extended with the half-diagonal). Derive the pitch from the roster's
   worst hull (the War Rig's 7.19 m half-diagonal) and print the derivation. **This moves the sim baseline** (spawn
   positions): pre-register the move, land it in its own commit, tell the orchestrator, who records it.
5. **The other arenas** get item 1's lane assertion where they declare lanes (yard, pit, boulevard): report, do not
   redesign; a failing lane on a map he has not complained about is a Status line, not a change.
6. **Stretch:** the `hull_size` consumer list's open sites (the three disc sites are combat's; the `army_layout`
   fallback is squad's; report status); scale's stretch item 6 (gangs-vs-law before-frames) is combat's series now.

## How to verify

- `make check` green (`make remote T=check`); `make arenas` reproduces the JSON byte for byte from the generator;
  `make arena-report`, `make remote T=arena-shots`, `make arena-page`; `make remote T=terminus-alleys`.
- `make skirmish ARENA=terminus`: drive a squad from the spawn to the far plaza through each street. Nav's drive
  test (nav's brief, item 1) is the mechanical version and runs on your map after CP2.
- Every number: commit, machine; every frame: his pose, before/after, the street named.

## Don't touch

`game/theme/**` (feel's meshes: request, do not edit), `game/ai/**`, `game/tank/**` (nav's and combat's),
`game/units/units.gd` values (feel's carve-out this round for `tank`/`burner`; the rest combat's), `game/tactics/**`.
`game/match/match.gd` beyond the three constants.

## Waiting on the lead

Nothing blocks. Chokepoints off the lanes are yours to author or drop; list them in `arenas.md`.

## Research addendum (brief 2, 2026-09-20 evening; rows B4, B5, B10)

**R4 gains corners (B4).** Road-design practice certifies a street for a design vehicle by its swept path at every
turn, not by its straight width. Item 1's lane test also checks each lane corner and each street-to-street junction
against the War Rig's turning template (its outer cab-overhang arc and inner trailer-axle arc at the rig's minimum
turning radius, a swept polygon per turn angle, computed offline from `Units`), and fails on any corner the template
does not clear. Print each corner's fillet radius beside the rig's. The Terminus grid's 90° junctions at 20 m streets
are the cases; the report names each.

**"Reads passable" gets a language (B10):** certified lanes read warm (street-level light, painted kerbs, unbroken
pavement); chokepoints read cold (blue perimeter light, warning stencils, containers and barriers ≥ 1.2 m tall);
passable clutter is under 0.3 m. And a light behind every corner so the entrance silhouettes from his camera. Item 3
uses this table; the fixtures are feel's and show's (send them the list of corners and lanes); the kerb paint is a
kit material question for feel.

**Vocabulary (B5):** the spawn-grid derivation (item 4) is a TURNING ENVELOPE use; the collider boxes (R3) are STATIC
FOOTPRINT; name them in the code.

## Research addendum 2 (brief 3, 2026-09-20 late; rows C5, C11, C12)

**The corner check is a closed form (C5).** A car-like hull turning through exterior angle Δψ needs an effective
clearance radius `r_eff = r_a + R_min·(sec(Δψ/2) − 1)` beyond its footprint (`R_min` from `Units`'
`min_turn_radius_m` for the War Rig). Item 1's lane test prints, for every junction and lane corner, Δψ, the rig's
`r_eff`, and the corner's inscribed clearance, and fails where the clearance is short. That replaces "the rig's
turning template" with one formula; the swept-polygon template can come later.

**"Reads passable" has an instrument now (C11), and three numbers explain his read.** At his pose (21°): a gap
ACROSS the screen is foreshortened by sin 21° ≈ 0.36, so the ring road (cross-screen at his default heading) shows
the same clearance 2.8× narrower than the avenue (in depth); a foreground object of height h hides 2.6 h of ground
behind it, so a 1.5 m barricade hides 3.9 m of the street's contact line; the telephoto flattens depth, so the eye
needs scale anchors (lane markings, paving, kerb stones) between the vehicle and the throat. Low obstacles (0.4–0.9 m:
barricades, kerbs) project 3–6 px tall and camouflage; overhead geometry reads as blockage. **Item 3 becomes a
render test** using control's camera tooling (`terminus-alleys` / `camera-looks`): per lane, project the narrowest
throat to screen at his pose, read the Z-buffer for the occluded fraction of its ground-contact line, and print the
visible throat width minus the rig's projected width. The page shows each frame with the throat drawn and the two
numbers; the ring road's beside the avenue's. Design rules that follow: kerb furniture never in front of a throat's
contact line from his camera; low barricades lit top-vs-side or replaced by tall ones; paving or lane marks as scale
anchors along every lane (feel's kit); a light behind every corner (show's).

**C12 (a calibrated per-frame score) waits** until his reads disagree with the instrument's ranking.

## Status

_(the worker keeps this current)_
