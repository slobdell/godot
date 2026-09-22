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

**Session 1, 2026-09-22 (feel worker). Every number is builder0 unless it says laptop.**

### In his terms (read this first)

- **The bus is bigger, and it is DRAWN bigger.** 2.40 x 2.40 x 8.62 → **2.90 x 4.76 x 9.70 m** (a 45 ft prison coach):
  1.29x the garbage truck's length and 1.29x its height, as he asked. Half of "too small" was a bug: the bus was
  drawn 1.60 m wide and 7.36 m long inside its own collider (fixed). **Merged as CP3 at `f49b5f15` → main `69c681ac`**;
  the sim baseline moved as pre-registered, `1ea332e7bc268d2a → aac14c6704fbac39`, three causes bisected.
- **The turrets sit where the guns are.** The bus's and the fire engine's turrets were buried inside the hull; they
  are on the roof. The gang gun truck's real machine gun (in its bed) now traverses, and the stray "barrel" sticks
  on the gun truck and the catapult are gone. The War Rig's rounds leave from under its gun.
- **The blimp he asked for is in his frame.** A lit ad blimp drifting down the Terminus avenue at 12 m; at his pose
  it is on screen and unoccluded in **13.4 %** of 12,960 samples (every focus x 4 yaws x its lap), and it is in his
  **opening camera**, 881 px wide (`references/round10/feel/blimp_opening_d9b70dc4.jpg`). The airship stays over the city.
- **Hulls get a faint rim in their faction's colour** (amber, magenta, police blue, ivory) so they read between the
  lamp pools. The pair is his eye's call (`references/round10/feel/rim_v2_final.jpg`; `--no-faction-rim` switches it off).
- **Waiting on his tap:** six concepts, three for the bus's own mesh and three for the fire engine
  (`make art-review-page TITLE="The Condemned bus and fire engine (R6)" GROUPS=R6 OUT=build/review_page_r6`).
  Meshy balance 34 (54 credits spent tonight, ledgered): enough for both vehicles' 3D after his taps, nothing more.

### Merge notes

- **CP3 merged** at `f49b5f15` (main `69c681ac`); **the rest merged** at `a822a48f` (main `28d60a4a`). They were
  (all visual, pre-registered UNMOVED):
  `d9b70dc4` (blimp re-routed down the avenue), `7f1707a3` + `e27e0b85` (blimp-look frame fixes), `010456f5` +
  `839cf3f4` (the faction rim), `a822a48f` (burner concepts), the MatchMood accessor, Status/docs. **Green hash for
  them: see the last line of this Status** (the check on the merged tip).
- Shared or other streams' files edited, each with the owner's ruling: `game/match/match.gd` (the two
  `SPAWN_JITTER_MAX_*`, combat's; orchestrator-approved), `game/tank/tank.gd` (the mount write, `TURRET_STANDARD`,
  `shared_hull_size`; combat reviews), `game/units/units.gd` (the tank/burner values and four `turret_mount`s; the
  carve-out, plus gang_ifv/gang_tank mounts under the same key), tests in combat's and squad's files in DERIVED form
  (`test_combat_mechanics`, `test_tactics_elements`, `scenario_fire_discipline`, `scenario_squad`,
  `scenario_elements`) with REASON lines where the claim is a behaviour, `game/audio/match_mood.gd` (mine).
- Temporary worktrees `~/projects/godot-feelneutral` and `~/projects/godot-feelbisect` (detached, mine, for the
  bisect) and their builder0 folders are REMOVED.

### Known issues / reds with a reason

- `test_tactics_elements::…drive_to_their_slots` RED on purpose (squad's REASON: the leader pinned to its column's
  head crosses its own row first while co-arrival pacing holds the rest; squad's fix follows the pitch).
- `scenario_fire_discipline` parked-friend RED on purpose (combat's REASON; knife-edge: on the laptop the plain arm
  passes and `hull_disc=0` fails, on builder0 the plain arm fails).
- `scenario_elements` formation-slot RED on builder0 (squad's REASON; tipped by the mounts, CP3 (c)).
- `scenario_elements` base-of-fire: passed on the pre-merge CP3 tree, failed after merging main -- named to squad.
- `vehicle_gallery.gd` mirrors the old turret placement and scaling (a gallery, not the game); not widened into CP3.
- The Law and Syndicate weapon parts are the same generated 3 cm "barrel" sticks (law_ifv's sits 1.07 m off-centre);
  he named only the Condemned and the gangs, so they are untouched. A question for him below.

### Questions for the lead

1. The Law and Syndicate vehicles show the same thin generated "barrel" sticks the gangs had; hide them too (the
   guns baked into those hulls would then not traverse), or leave them?
2. The rim: keep it (faint, per faction), stronger, or off?
3. Bus and fire-engine concepts: one per vehicle, or none (then the stretched dozer stays).

### What to playtest

- `make skirmish ARENA=terminus` -- the bus beside the garbage truck; the turrets on the roofs; the blimp coming down
  the avenue from your end at the start (it laps in ~4 minutes); the faint hull rims between the lamp pools.
- The rim off, for the comparison (`make skirmish` passes no extra flags):
  `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish --arena=terminus --no-faction-rim`

### Next steps (in order)

1. The check on the merged tip → name the hash for the post-CP3 commits.
2. After his taps: image-to-3D for the chosen bus (and burner), fitted to their boxes (S1's `box_at_length` then
   derives their proportions from the mesh, and `test_only_the_two_known_units_have_no_art_of_their_own` changes).
3. B10 / C11 kit items (warm lane lights and kerbs, corner fixtures, scale anchors, low-obstacle markings) when arena
   sends the lane and corner list -- none received yet.
4. Stretch, waiting on a quiet builder0 the orchestrator calls: the hinge's frame cost,
   `REMOTE_SLOTS=6 make remote T="perf-trailer-ab PERF_CYCLES=6"` (refuses its own number under load, by design).
   The single-variable lamp pair: not started (no one has asked for the lamp claim on stricter footing).

### Decisions (one line each)

- **The bus's reference is a 45 ft motor coach (MCI D4505), 13.72 m x K = 9.70 m** -- the coach the US Marshals and
  the Bureau of Prisons run as prison buses, so S1's reference x K rule keeps holding; his eye picked the proportions.
- **`turret_mount`'s frame is the Tank node's own: +z is the REAR.** The contract said "z forward"; its quoted default
  (+0.2, `tank.tscn`) has always been 0.2 m AFT (trip-up 2).
- **The Turret node is simulation, so R5 splits the mount** (agreed with the orchestrator and combat): x/z move the
  pivot (rounds leave from under the drawn gun); y stays at `muzzle_height − 0.05` (the ceiling rule) and only the
  turret/weapon ART rises. `turret_mount[1]` is the height of the art's ORIGIN (each part carries an authored offset).
- **The blimp flies the avenue** (the first route, the ring roads, was 0.0 % seen: walled by 24 m blocks from the
  bases). Four flank screens yawed 35 deg fore/aft so the view down the avenue sees one.
- **The burner's box is unchanged** (2.40 x 2.40 x 6.89): he did not ask, and its concept page is his to tap.

### CP3, as built (the record)

| commit | what | baseline pre-registration |
|---|---|---|
| `11ccc0a8` | R5 write: `turret_mount` on all three axes (`Tank.turret_pose`), `make turret-probe` | UNMOVED (proven: `5cfde60e` = `1ea332e7bc268d2a`) |
| `9dcc42d3` | tank/burner DRAWN at their box; the turret's scale kept by name | UNMOVED (same proof) |
| `5cfde60e` | the ad blimp + `make blimp-look` | UNMOVED (same proof) |
| `7001bdc8` | **(b)** spawn jitter 1.5/0.6 → 1.30/0.15, the rule beside it | MOVES; alone: 29/0 on the failing files, 41,3 |
| `055fb10f` | **(a)** the bus 2.90 x 4.76 x 9.70 | MOVES; causes all three unit reds; 40,4 |
| `a138b5f1` | **(c)** the mount values; `GUN_CUTS["gangs/ifv"]`; stray sticks hidden | MOVES; tips formation-slot; 39,5 |
| `835b4f26`, `f49b5f15` | **(d)** the literals derived (combat's, squad's forms) and the REASONs | — |
| `f49b5f15` check | `exited 2`, 1624/2 (both REASON'd), `aac14c6704fbac39`, 40,4 against the pre-44,0 count | merged `69c681ac` |

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

- combat (answered): R5 design accepted; its condition, a per-profile muzzle test, is
  `test_no_mount_pushes_the_muzzle_further_out_of_its_own_box` (in `a138b5f1`): with its mount, a unit's muzzle is
  inside its own box or no further past its nose than today's pose puts it (small hulls' muzzles always were).
- squad: read `scenario_elements::test_the_base_of_fire_keeps_firing_while_the_others_move` (passes on the pre-merge
  CP3 tree, fails after merging main with squad's fix) and the formation-slot drift (REASON'd).
- arena: the B10 / C11 lane and corner lists, when ready (feel does the kerb paint, the corner fixture, the scale
  anchors and the low-obstacle markings).


### The last check (the green hash for everything after CP3)

**MERGED: `a822a48f` → main `28d60a4a` (2026-09-22).** The engine-deck scenario is routed to squad as a CP3 consequence
of its ORBIT controller; scenario_perf under five slots is load. **What is left for feel:** the hinge bench in the
quiet window the orchestrator calls at the round's end; the bus/burner image-to-3D after his taps (his morning);
B10/C11 kit work when arena sends the lane/corner list (asked 2026-09-22). Later commits (`e27e0b85` tool fix, Status)
merge with the next docs hash. **Was: merge here, `a822a48f`.** Check on it (builder0, merged with main `69c681ac`, `REMOTE_SLOTS=5`): `>> remote: make
check exited 2`; **1645 passed, 2 failed** -- the two REASON'd tests above; sim-baseline `aac14c6704fbac39` (CP3's
recorded move; these commits add none); determinism `2bf54e1e4c829e06`; ai-scenarios **39,5 against 44,0**: the three
REASON'd or named scenarios above, plus `scenario_cp2` engine-deck (fixed on main by squad's ORBIT fix, broken again
by the 9.7 m bus: named to squad) and `scenario_perf` CPU budget (load: five slots on builder0). Everything else green.
Commits after `a822a48f`: `e27e0b85` (blimp-look frame fix), the Status.
