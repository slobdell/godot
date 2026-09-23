# Stream: feel (the blimp in his frame, the turret mounts, the bus that reads bigger than the garbage truck)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*, *The Syndicate airship*, *Round 9 direction* §2), [workstreams.md](../workstreams.md)
> (*Round 10: the eight streams*, contracts **R5**, **R6**, **R7**, checkpoint **CP3**; round 9's **S1**, **S2**),
> [art_direction.md](../art_direction.md), [slot_contracts.md](../slot_contracts.md), and your round-9 brief
> [archive/round9/feel.md](archive/round9/feel.md) — its "ROUND 10, carried forward" (rim light, the hinge cost, the
> single-variable lamp pair) is the tail of the backlog below.
>
> **You own** `game/theme/**` except show's carve-outs (unchanged from round 9) and the announcer paths (announcer's
> this round: `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `mk/announcer.mk`); `game/audio/`,
> `assets/{audio,music}/`, `tools/{assets,audio}/`, `mk/{fx,assets}.mk`, `export_presets.cfg` art filters,
> `_agents/{art_direction,slot_contracts,legibility}.md`. **Carve-outs granted 2026-09-20 (combat reviews at merge):**
> (a) an optional `turret_mount: [x, y, z]` per `Units.PROFILES` entry and the three-axis write in
> `Tank._apply_hull_size` (`game/tank/tank.gd`); (b) the `hull_size`/`muzzle_height` VALUES of `tank` and `burner` in
> `game/units/units.gd`.

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> we're missing the blimp I wanted.

> The turret placement on our vehicles is wrong (at least with the condemned and the gangs).

> I can see that the condemned bus is too small still. It should be longer than the garbage truck and heightened
> proportionally.

> vehicles are going straight through and overlapping with some of the assets (like the lights).

Standing: *"production quality over credits"* (the lead limits the asset count, not the spend); new assets go on the
concept review page, 2–3 directions per slot, before any 3D (memory: *Concept choices review page*).

## Where things stand

- **The blimp.** The round-9 airship (`game/theme/arena_kit/airship/syndicate_airship.gd`, primitives, no collision,
  `ORBIT_RADIUS` 560 m, `ORBIT_ALTITUDE` 56 m, built by `arena_dressing.gd:117-127`, absent on the LOW tier) is
  invisible where he plays: at 21° pitch / FOV 35 the frame's top edge is 3.5° BELOW the horizon, so the sky is
  never on screen; your 768-sample sweep (`make airship-look`) found it in 12.5 % of frames at 8–12° tilt and 0 % at
  17° and above. Your round-9 question (leave it over the city, or make it a title element) is ANSWERED by his
  sentence: he wants to see a blimp while he plays. R7: a blimp that shows at his pose flies LOW, among the Terminus
  blocks (24 m tall) over the far half of the frame, ~10–14 m up (the camera sits ~17.5 m up at his boom; anything
  higher than the camera minus the 3.5° drop over the distance is out of frame), slow, lit, with its own screens
  (an ad blimp drifting down the avenue), no collider, the sim baseline pre-registered unmoved. The 560 m airship
  stays as the city's.
- **Turret placement.** `tank.tscn:22` puts `Turret` at `(0, 1.22, +0.2)`; `Tank._apply_hull_size()`
  (`game/tank/tank.gd:243-258`) writes only `position.y = muzzle_height − 0.05` and a uniform scale; **x and z are
  never touched**, so every hull from 2.9 m to 14 m carries its turret 0.2 m ahead of its origin. A bus, a garbage
  truck, a hot rod and a semi have their turrets in the same place. `Units.PROFILES` has `mount`, `muzzle_height`,
  `hull_size` and no mount offset. Where a faction hull bakes its gun into the mesh, `FactionArt.GUN_CUTS`
  (`faction_art.gd:127-137`) cuts and yaws it about an authored pivot (`gangs/tank`, `law/artillery`). R5 adds
  `turret_mount: [x, y, z]` per profile, derived from each mesh's ring (the `driving_bounds()` pattern in
  `dozer_part.gd:300`), applied on all three axes; default preserves today's pose so nothing moves until measured.
- **The bus.** `tank` (the Condemned prison-bus dozer) is `[2.40, 2.40, 8.62]` from a Type D school bus (12.19 m) × K;
  the garbage truck is the Condemned `ifv`, `[2.86, 3.70, 7.54]` (Type C bus reference; the armored-garbage-truck
  art). The bus is longer on paper by 1.08 m and 1.30 m SHORTER, on a shared dozer hull stretched to length (no
  mesh of its own, so `box_at_length` cannot derive it; scale's derivation to `[1.83, 2.23, 8.62]` looked worse and was
  reverted on the picture). R6: his eye rules for `tank` and `burner`: the bus reads LONGER than the garbage truck
  and TALLER in proportion. Start at length ≥ 1.25 × 7.54 = 9.4 m, height ≥ 3.70 × (9.4/7.54) ≈ 4.6 m, width from a
  coach's proportions (~2.9 m), then LOOK (`make roster-lineup` at his pose) and adjust until it reads; record the
  reference you settle on beside the box. **A `hull_size` change moves the sim baseline** (spawn grid, collider,
  clearance): CP3, merged alone, the orchestrator records. The bus's own mesh is the real fix: a concept page with
  2–3 directions (the armoured school-bus dozer at its new proportions) for his tap, then Meshy. The burner (fire
  engine) gets the same page if the count allows; he limits the count.
- **"Through the lights."** The floodlight's collider is its 2.4 × 3.0 × 2.4 footing (`ArenaKit.PROPS`, arena's);
  the mast and the 4.2 m head are visual only (`kit_yard.gd:205-219`, `KitProp` is visual-only by design). arena
  writes the parity test (R3) and may ask you to move geometry above 6.2 m or accept a wider box; answer the day it
  asks.
- **Carried from round 9:** the per-faction rim light on hulls (dark hulls between lamp pools are invisible without
  their rings; pair discipline, the readability gate); the hinge's frame cost (three refusals; combat's tune fix is
  on main, the bench will refuse again if the knob does not take); the single-variable lamp pair.

## Backlog (in order)

1. **R6: the bus box (CP3).** Failing test first: `tank`'s box exceeds `ifv`'s in length and height by the recorded
   ratio; the lineup at his pose (`make roster-lineup`, builder0) with the before beside it. Pick the numbers by
   looking, not by the table; record the reference. Pre-register the baseline move; land the values in one commit
   with the derivation; tell the orchestrator the hash whose check is green (red only on sim-baseline). Then the
   concept page: 2–3 bus directions for his tap (`make art-concept`), no 3D before his tap.
2. **R5: the turret mounts.** `turret_mount` per profile, the three-axis write, a mutation-checked test (a unit with a
   mount 3 m aft draws its turret 3 m aft; a unit without one draws where it does today), the default preserving
   today's pose. Then measure the Condemned and gang hulls' rings from their meshes (the ring's centre in the hull
   frame at the profile's length) and write the values; a frame per unit at his pose, before/after. `slot_contracts.md`
   updated. Pre-registered: the sim baseline does not move (visual; if it does, the muzzle path reads the turret
   position and that is a finding for combat).
3. **R7: the blimp.** Build the low ad-blimp (primitives; its screens ride `AdBroadcast` like the airship's), fly it
   along the Terminus avenue's far half at 10–14 m at a walking pace, lit (navigation lights steady, the screens the
   ad colour), no collider; prove it with the airship-look sweep at HIS pose: the fraction of a match it is in frame,
   the frame beside the number. If every candidate path is out of frame, the frames go to him with the choice.
   Pre-registered: the sim baseline does not move.
4. **The per-faction rim light** (round 9's recommendation): a faint hull rim per faction so hulls read between the
   lamp pools without their rings; a pair at his pose with the show off and on; the readability gate.
5. **The parity requests from arena** (R3), as they arrive.
6. **Stretch:** the hinge's frame cost with the freeze that takes; the single-variable lamp pair; the burner's
   concept page.

## How to verify

- `make check` green (`make remote T=check`); `make roster-scale` (the table), `make roster-lineup` (his frame),
  `make airship-look`, `make crowd-look ARENA=terminus`, `make assets-preview`.
- `make skirmish ARENA=terminus` and look at the bus, the turrets, the blimp at his pose.
- Every frame a pair, one variable, his pose; every number its commit and machine; every paid request in the ledger
  (`assets/meshy_ledger.md`) and behind his tap on the concept page.

## Don't touch

`game/theme/show/**` and show's carve-outs, `game/announcer/**`, `assets/announcer/**`, `tools/announcer/**`
(announcer's this round), `game/ai/**`, `game/tactics/**`, `game/control/**`, `arenas/`, `game/arena/` (arena's:
answer its requests), `game/units/units.gd` beyond the `tank`/`burner` values and the `turret_mount` key,
`game/tank/tank.gd` beyond the mount write.

## Waiting on the lead

The bus concept page (his tap before any 3D); the burner's, if the count allows. Nothing else blocks: the bus's box
lands from your eye, and he overrules on the lineup.

## Research addendum (brief 2, 2026-09-20 evening; rows B10, B3)

**Affordance language for the streets (B10), with arena:** certified lanes read warm (street light at ~3000 K,
painted kerbs, unbroken pavement); chokepoints read cold (blue perimeter light, warning stencils, barriers ≥ 1.2 m);
and a light behind every corner so a street's entrance silhouettes from his camera. arena sends the list of lanes and
corners; the kerb paint and the corner fixture are kit work of yours; pair discipline as always. This sits after the
bus, the turrets and the blimp.

**The trailer's second collider (B3)** has a shape now (a hinged OBB placed analytically from the hitch kinematics you
already drive visually); it is combat's stretch item, not yours; expect a request for the kinematics as a shared
function.

## Research addendum 2 (brief 3, 2026-09-20 late; row C11)

**Two kit items from the legibility instrument, after the bus, the turrets and the blimp:** scale anchors along every
lane (lane markings, paving slabs or kerb stones at a known pitch: at his telephoto pose the eye has no depth cue
between the vehicle and a throat 80 m away), and low obstacles (barricades, kerbs, 0.4–0.9 m) lit top-versus-side or
given a marking, because at 21° they project 3–6 px tall and camouflage against the road. A 1.5 m object hides 3.9 m
of ground behind it from his camera, so kerb furniture never stands in front of a throat's contact line. arena sends
the list; pair discipline.

## Status

_(the worker keeps this current)_

**2026-09-22, session 1 (feel worker). Baseline: `main` at `2ee65f94`, check on builder0 launched 09:58.**

### Plan (in order, with the reason where the brief left a choice)

1. **R5 write first, then R6's box** — the mount write is baseline-NEUTRAL (no unit carries a mount), so it can go
   green on its own and the three baseline-moving commits stack on it.
2. **R6, CP3, as THREE commits** (the orchestrator's condition, so a bisect can attribute the move):
   (a) the bus box — pre-registered: MOVES the sim baseline; (b) the spawn-jitter shrink in `match.gd` (combat's
   constants, edited here with the orchestrator's approval; combat reviews at merge) — pre-registered: MOVES;
   (c) the turret-mount VALUES — pre-registered: MOVES (x/z move the pivot, which is sim). The write alone (R5,
   step 1) is pre-registered UNMOVED and proven so on its own check.
3. **R7, the blimp** — a low ad blimp on a street circuit round the Terminus's central blocks; pre-registered UNMOVED.
4. The rim light; the arena parity requests as they come; stretch.

### Done so far (commits on `stream/feel`; every number: builder0 unless it says laptop)

| commit | what | baseline pre-registration |
|---|---|---|
| `11ccc0a8` | R5 write: `turret_mount` read on all three axes (`Tank.turret_pose`), `make turret-probe` | UNMOVED (no unit carries a mount) |
| `9dcc42d3` | R6: tank/burner DRAWN at their box (`shared_hull_size` fell back in silence); turret scale kept by name | UNMOVED |
| `5cfde60e` | R7: the ad blimp + `make blimp-look` | UNMOVED |
| `7001bdc8` | **CP3 (b)** spawn jitter 1.5/0.6 → 1.30/0.15, the rule beside it (combat's constants, approved) | **MOVES** |
| `055fb10f` | **CP3 (a)** the bus 2.40 x 2.40 x 8.62 → **2.90 x 4.76 x 9.70** (45 ft MCI coach x K; 1.29x the ifv on both axes) | **MOVES** |
| `8a9b71a2` | R6 concept page: `bus_r10_a/b/c`, 27 credits (Meshy 88 → 61), **waiting on his tap** | — |
| `a138b5f1` | **CP3 (c)** R5 values: tank, burner (roof), gang_ifv (GUN_CUT of the bed MG), gang_tank (pivot under the cut gun); stray gang_artillery stick hidden | **MOVES** |

**Frames kept in the repo, `_agents/streams/references/round10/feel/`** (JPEG; the full PNGs regenerate with the
targets named below): `bus_sheet.jpg` (the bus at his pose: before | the draw fix alone | the chosen 2.90 x 4.76 x 9.70
| 3.10 wide | 4.20 tall), `turret_pairs.jpg` (side-on, before | after: bus, burner, gang_ifv, gang_tank,
gang_artillery, ifv), `blimp_opening_d9b70dc4.jpg` (the blimp in his opening camera), `rim_v1_too_strong.jpg` (the
rim pair's first pass: show off/on x rim off/on; the rim was toned down after it). **How they were made:** the bus at his pose, before /
the draw fix alone / the chosen box / 3.10 wide / 4.20 tall: `lineup_bus.png`, `lineup_bus_1..3.png`
(`make remote T=roster-lineup`, `LINEUP_FLAGS=--size-look-bus=W,H,L/W,H,L`). The turrets side-on before/after:
`make remote T=facing-audit` → `build/facing/<unit>.png`. What they show: the before-bus reads SMALLER and far lower
than the 7.5 m garbage truck with no visible turret; at 2.90 x 4.76 x 9.70 it reads longer and taller, with its
cannon on the roof; the gun truck's stray rod is gone and its bed MG traverses; the catapult's 5 m stick is gone.

### R7, the blimp: the number and the frame

`make blimp-look` (builder0, his pose 21 deg / FOV 35 / 49 m, the Terminus, 135 foci on a 20 m grid x 4 yaws x 24
points of its lap = 12,960 samples; SEEN = in the viewport AND a clear physics ray past the blocks' colliders):

| route | seen, all | seen, the skirmish's start yaw | seen, the middle band | median width |
|---|---|---|---|---|
| ring roads + west streets (`5cfde60e`) | **0.0 %** (37.5 % "on screen" by bounding box only) | 0.0 % | 0.0 % | — |
| **the avenue loop** (`d9b70dc4`, x = +-4, turning at z = +-86) | **13.4 %** | **14.8 %** | 10.6 % | **427 px** |

In the OPENING view (the camera he starts with) it is seen, 881 px wide: `build/blimp-look/blimp_opening.png` --
the lit envelope over the avenue top-right, its screen showing the arena channel's ad, the resized buses below.
The first route was wrong for a reason worth keeping: from the bases the ring roads are walled by 24 m block rows
his 17.5 m camera cannot see over; the avenue is the one corridor along his view. "Sometimes visible" is ~1 sample
in 7 wherever he looks, and every time he starts a match.

### Decisions (one line each)

- **The bus's reference is a 45 ft motor coach (MCI D4505), 13.72 m x K = 9.70 m.** The US Marshals and the Bureau
  of Prisons run MCI coaches as prison buses, so this is the real vehicle and S1's rule keeps holding
  (`test_every_hull_is_its_reference_length_times_k`); his eye picked the proportions, recorded beside the box.
- **`turret_mount`'s frame is the Tank node's own: +z is the REAR.** The contract text said "z forward"; the default it
  quotes (+0.2, `tank.tscn`) has always been 0.2 m AFT of centre in Godot's frame (trip-up 2). Written down so nobody
  flips a sign reading the contract.
- **The Turret node is simulation, so R5 splits the mount** (agreed with the orchestrator and combat, 2026-09-22): x/z
  move the pivot (rounds leave from under the drawn gun), y stays at `muzzle_height − 0.05` (the ceiling rule) and only
  the turret/weapon ART rises to the ring.
- **The blimp flies the ring roads and west streets, not the avenue:** along the avenue its flank screens would be
  edge-on to a camera looking up the map; on the ring roads they face the bases.
- **`vehicle_gallery.gd` still mirrors the old turret placement** (its own scaling differs too); left as it is, noted
  here, not widened into this diff.

### Findings

- **The bus was not drawn at its box (the second half of "too small").** `Tank.shared_hull_size()` measured the
  cyberpunk `tank.hull` (a `dozer_part` wrapper that builds its model in `_ready`) out of the tree, found no meshes and
  returned the (2.4, 1.6, 3.6) fallback in silence, so the 2.40 x 2.40 x 8.62 bus drew **1.60 wide and 7.36 long**
  (`make turret-probe`, laptop, `11ccc0a8`); the burner the same way. `test_units_scale`'s shared-art test multiplied
  the slot's scale by that same wrong measurement, so it passed against itself. Fixed by measuring the wrapper's
  `model_scene`; the TURRET's scale (sim: the muzzle is 3.2 m x it ahead of the pivot) keeps the (2.4, 1.6, 3.6) it
  was always scaled against, by name (`Tank.TURRET_STANDARD`), so the fix is pre-registered UNMOVED. Its own commit.
- **Every turret part's art already sits at an authored height above its pivot** (probe: the garbage truck's turret
  base is at 3.37 m on its 3.70 m roof with the pivot at 1.09). So `turret_mount[1]` is the height of the turret ART's
  origin, and each value's derivation records the probe's numbers (ring height − the art's authored base offset).
- **arena's R3 floodlight finding, for the record:** the floodlight's geometry fits its collider (the head is at
  15 m); what he saw a vehicle drive through was most likely the neon SIGN (no collider, a post and a 6.3 m board)
  standing in the spawn zones on yard, pit and Terminus; arena moved it and asserts it. The other candidate is the
  War Rig's trailer art folding outside its rigid 14 m collider (S2's accepted cost; combat's B3 stretch).

### Answered for arena (R3, 2026-09-22)

- Ad screen housing (down to 5.71 m, 7.80 x 1.92): **keep arena's widened 7.8 x 2.0 box**; no art change.
- Wreck husk (drawn 3.2 x 3.3 in a 3.2 x 6.4 box): **arena shrinks the box to the art**; no regeneration.

### Reviews owed to others

- **show's per-window layer (merged to main at `2ecda325`; post-merge review, 2026-09-22): ACCEPTED, no requests.**
  Idle look at level 1.0: `before_yard_wide_t16_3` vs `yard_wide_t16_3` differ by a mean of **0.38 / 255** in
  luminance (show's own page frames, builder0) -- unchanged. Terminus capture cue: the windows fill magenta and amber
  across the facade, the hulls and floor are untouched, and the bay widths (now from a CPU code in COLOR.a) read as
  natural storey bays; the silhouette is unchanged. `MatchMood.control_changes()` added for show (`game/audio/`).

- **terrain's `arena.terrain` slot (merged to main at `4ffb4c1a`; post-merge review, 2026-09-22): ACCEPTED**, two
  non-blocking look notes sent to terrain. On its own frames (`~/projects/godot-terrain/build/terrain-shots`,
  dry/wet pairs): the bridge deck with hazard-striped rails over a cyan-edged river and the hazard-ringed pit read at
  play distance and sit in the art direction's stripe motif. Notes: (1) the water surface reads as a starfield /
  nebula rather than oily night water -- darker, low-frequency ripple, a specular streak from the lamps; (2) the pit
  floor is flat black with no depth cue -- a gradient darkening toward the centre or lit rim walls.

### Requests to other streams

- combat (via the orchestrator, answered): R5 design accepted; combat asks for a per-profile test that the muzzle
  stays inside the unit's own box once mounts move the pivot — **to be written with the mount values (commit c).**

