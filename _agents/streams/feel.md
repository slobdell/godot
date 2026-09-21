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

## Status

_(the worker keeps this current)_
