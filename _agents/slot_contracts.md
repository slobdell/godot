# Visual slot contracts

> **Living contract** between the streams that place art (rules: units, arena) and the streams that make
> it (art). Moved here from the round-1 assets brief on 2026-09-15. Changing a row is a contract change
> ([workstreams.md](workstreams.md)). Data mirror for the asset pipeline: `assets/pipeline/asset_contracts.gd`.

How slots work: gameplay scenes hold `VisualSlot` nodes naming a slot id; `GameTheme` (game/theme/game_theme.gd)
maps slot ids to scenes per theme; themes fall back to `DEFAULT_SLOTS`. Visuals never add collision, and
`make sim-baseline` proves art never changes the simulation. Generated models go through the asset pipeline
(`assets/README.md`, `make assets-check`).

**Round 2 (2026-09-15):** units become fixed types (game_design.md), so vehicle slots move to per-unit ids
`unit.<unit_id>.hull`, `unit.<unit_id>.turret`, `unit.<unit_id>.weapon`. Each falls back to the `tank.*` and
`weapon.*` rows below until art exists. The rules stream adds the rows when it lands catalog v2.

**Known issues to fix in round 2:**
- The prison dozer's pipeline decimated the hull from 14k to 7.7k triangles (the 8k budget below), which
  flattened its treads in close-ups. Vehicles should keep the generator's detail (~15k): raise the hull budget.
- Tall hulls put the visible barrel ~0.65 m above gameplay's muzzle height (1.22 m). Catalog v2 carries a
  per-unit muzzle height so shells, tracers, and flashes start at the visible barrel.
- The cyberpunk wrapper's team accent strips (`game/theme/cyberpunk/dozer_part.gd`) read as blocky slabs under
  glow. Replace them with thin trim or per-team tinting of the model's own neon.

## The contracts (round 1 slots)

All: units are meters, **forward is −Z**, up is +Y, and origin as stated. Visuals must not add collision.

**Paint vs team (integration, 2026-09-15):** `set_team_color(Color)` is the TEAM color (friend or foe: accent lights in the cyberpunk theme); optional `set_paint(Color)` is the garage's full-body paint, called only when a loadout has one. Keep team accents in a separate emissive mask so paint never recolors them (look & feel's request).

| Slot | Anchor / origin | Size guide (matches gameplay collision) | Optional methods | Budget |
|---|---|---|---|---|
| `tank.hull` | ground contact, center of the hull | 2.4 wide × 3.6 long × ≤ 1.6 tall (turret ring at y ≈ 1.22, z ≈ +0.2) | `set_team_color(Color)`, `set_shield(ratio 0..1)` (every frame, gameplay G6) | ≤ 8k tris |
| `tank.turret` | turret pivot (rotates about +Y) | ~1.4 × 1.7 × 0.55 | `set_team_color` | ≤ 4k tris |
| `weapon.cannon` | turret pivot; barrel along −Z | muzzle ~3.2 m ahead of the pivot (gameplay fires from there) | `set_team_color`, `setup(weapon)` | ≤ 2k tris |
| `weapon.flamethrower` | turret pivot; nozzle along −Z | short; show a flame effect ~20 m long | `set_team_color`, `setup(weapon)`, `set_firing(bool)` | ≤ 2k tris + FX |
| `prop.crate` | ground center | 4.5 × 3 × 4.5 | — | ≤ 2k tris |
| `prop.wall` | ground center | 18 long (X) × 3 tall × 1.5 thick | — | ≤ 3k tris |
| `weapon.laser` *(gameplay G7, placeholder landed on stream/gameplay)* | turret pivot; emitter along −Z | like the cannon; muzzle ~3.2 m ahead | `set_team_color`, `setup(weapon)`, `set_firing(bool)` (true on the tick a pulse fires), `set_heat(ratio 0..1)` (every frame) | ≤ 2k tris |
| `fx.shell` | projectile center, flying along −Z | ~0.3 × 0.3 × 1 | — (tracer + light; look & feel may pool) | ≤ 200 tris |
| `fx.laser_beam` *(gameplay G7, placeholder landed on stream/gameplay)* | created at the world origin, then `setup` places it | from the muzzle to the hit point (≤ 55 m) | `setup(from: Vector3, to: Vector3)` (world space, called once right after it enters the tree); Match frees it 0.2 s later | FX only |
| `fx.fog_of_war` *(gameplay G1, placeholder landed on stream/gameplay)* | world origin; `setup` places it | covers the arena floor (240 × 240 m) just above y = 0 | `setup({"texture": Texture2D, "origin": Vector2, "size": float})`: L8 texture, 1 px per 2 m cell, 0 never seen / ~90 seen before / 255 visible now; updated in place ~2×/s | one draw call |
| `weapon.machine_gun` *(gameplay directive set 2, placeholder = the cannon barrel)* | turret pivot; along −Z | slim; on the scout (a 2.0 × 1.4 × 3.0 hull, visuals scaled from the tank's) | `set_team_color`, `setup(weapon)`, `set_firing(bool)` | ≤ 1k tris |
| `weapon.mortar` *(gameplay directive set 2, placeholder = the cannon barrel)* | turret pivot; tube along −Z | on the artillery (a 2.6 × 1.6 × 4.0 hull, visuals scaled from the tank's) | `set_team_color`, `setup(weapon)` | ≤ 2k tris |
| (mortar rounds) | uses `fx.shell`, flown along an arc by `ArcRoundVisual` (game/combat/), pointing along its path | | | |
| `fx.tracer` *(gameplay directive set 2, placeholder)* | like `fx.laser_beam` | muzzle to hit point (≤ 45 m), 5 bursts per second | `setup(from: Vector3, to: Vector3)` | FX only |
| (all vehicle visuals) | | | `set_team_color(Color)` = the TEAM color (friend or foe), called once at spawn by `Tank.set_team_accent`; optional `set_paint(Color)` = cosmetic full-body paint, only when an army entry has `paint` | |
| `unit.<id>.hull` *(round 2, rules R3; ids: scout, tank, ifv, artillery, lancer, burner)* | like `tank.hull` | the unit's `hull_size` from `Units.PROFILES` (a slot filled by `unit.<id>.hull` is **not** rescaled; the `tank.hull` fallback is scaled from the tank's 2.4 × 1.6 × 3.6) | `set_team_color`, `set_paint`, `set_shield`; units that deploy (artillery, round 3 combat X5): `set_deployed(ratio 0..1)` every frame on the hull, turret, and weapon (0 = packed and driving, 1 = outriggers down and firing) | ≤ 15k tris |
| `unit.<id>.turret` *(round 2)* | turret pivot at the unit's `muzzle_height − 0.05` m; rotates about +Y. Fixed mounts (the scout) swing only ±`fire_arc_deg`/2: draw a hood gun, not a turret | | `set_team_color`, `set_paint` | ≤ 4k tris |
| `unit.<id>.weapon` *(round 2)* | turret pivot; along −Z; muzzle ~3.2 m ahead (times the turret scale) | falls back to `weapon.<the unit's weapon id>` | `set_team_color`, `setup(weapon)`, `set_firing`, `set_heat` | ≤ 2k tris |
| `prop.fire_pit` *(stretch hazard, rules; layout `furnace`)* | ground center | a burning pit `radius` m across (7–9 m in `furnace`), flush with the ground, no collision | `setup(hazard)` with `{type, position, radius, damage_per_second}` | ≤ 2k tris + FX |
| `unit.burner.*` *(stretch unit, rules)* | like the other `unit.<id>` rows | hull 2.4 × 1.6 × 3.8; the Burner fires `weapon.flamethrower` | | |
| `weapon.autocannon` *(round 2, the IFV's 30 mm)* | turret pivot; along −Z | twin short barrels read well; muzzle ~3.2 m ahead | `set_team_color`, `setup(weapon)` | ≤ 2k tris |
| `prop.container_20`, `prop.container_40` *(round 3, assets X1)* | ground center of the bottom container; long axis along X, doors at +X | 6.06 (40 ft: 12.19) × 2.59 tall × 2.44 per container; `stack` containers high | `setup(obstacle)`: `stack` (1..), `faction` (`mixed`/`condemned`/`law`/`syndicate`/`gangs`), `paint`, `stencil`, `rust` (0..1), `doors` (`closed`/`ajar`/`open`). Without `setup`, a visual the Arena scaled in height reads as that many stacked containers (never stretched) | ~314 tris per container; every container of a kind is one MultiMesh draw (ContainerYard) |
| `prop.ad_screen` *(round 3, assets X2)* | ground center; the screen faces -Z | 7 × 14 m panel from 6 m up (top ≈ 20.5 m) on two legs over a 7.4 × 1.4 × 1.4 m concrete plinth (the only part that should collide); throws light ~22 m in front | `setup(obstacle)`: `channel` (default `arena`; screens on one channel show the same ad) | ~5 draws per screen + one 2D feed per channel (AdBroadcast) |
| `unit.artillery.hull` `set_deployed(ratio)` *(round 3, assets X5; Tank calls it every frame since combat's CP2)* | | 0 = stowed (outrigger legs slid in under the chassis and lifted), 0.5 = beams out, 1 = jacks down (the approved concept's pose; also the visual's default before anything calls it) | every frame | rigid parts cut from the generated hull (OutriggerRig), no skeleton |
| `arena.environment` | world origin | sky/lighting/fog only | — | — |
| `arena.dressing` | world origin | ground 320×320 at y=0; perimeter walls at ±121 | optional `setup(layout)` (rules R6: the arena layout dictionary from `arenas/<name>.json`, so stands and crowds can fit it) | ≤ 50k tris |
| `prop.<type>` for layout obstacles *(rules R6)* | ground center; the body is rotated by `rotation_deg` | an obstacle with a `size` other than its type's default gets its visual scaled by size / default | — | per type |

## Runtime cuts: one approved mesh, more than one moving part (round 7 and round 9)

**A hull slot's model may be split at runtime into parts that move independently, and the slot contract above does
not change when it is.** The mesh is the approved one, untouched on disk and unmoved at rest; the cut is a box (or a
union of boxes) in the model's own space, applied once when the part is built, with the inside piece re-parented to a
pivot. Nothing is regenerated and no credits are spent, which is the whole point: a concept the lead approved stays
the concept he approved.

| Cut | Owner | What it is | Pivot's law |
|---|---|---|---|
| `FactionArt.GUN_CUTS` (round 7) | feel | a gun generated **into** the hull mesh, with only a nub as the turret part (`gangs/tank`, `law/artillery`) | follows the tank's turret yaw each frame; `rest_yaw_deg` turns a gun modelled pointing backwards |
| `FactionArt.TRAILER_CUTS` (round 9, contract **S2**) | feel | the War Rig's tanker trailer, cut at the fifth wheel | tractor-trailer off-tracking from the **drawn** motion each frame, clamped at a jackknife limit measured against the mesh |

Rules that apply to any cut added later, each of them earned:

1. **Measure the cut off the mesh, do not guess it** — `make assets-profile IN=… [AXIS= SLICES= BOX= CLIP=1
   RENDER=1]` prints a slice table and a ruled orthographic side view whose pixels are metres.
2. **A cut is not always a plane.** The War Rig's tanker overhangs the tractor's drive tandem, so `TRAILER_CUTS`
   carries a *list* of boxes (`FactionArt.split_mesh_boxes`); a triangle is inside if its centroid is in any of them.
3. **Nothing lost, nothing doubled, nothing moved at rest.** Assert that the pieces' triangles sum to the whole and
   their merged bounds equal the uncut bounds: at zero articulation the cut model **is** the original.
4. **Cuts compose, and the order is part of the contract.** The rig's gun is cut first and then rides the trailer —
   its pivot is re-parented under the trailer's and the trailer's yaw is taken back out of the gun's, so gunnery is
   unaffected. A cut whose piece sits on another cut's piece must say which is the parent.
5. **Per-frame motion reads the DRAWN pose**, `get_global_transform_interpolated()` and the frame's delta — never the
   physics tick (the sim is 30 Hz with physics interpolation on) — and **snaps on a teleport**, or the first frame
   after a respawn draws the part streaking from where the wreck was.
6. **It is still art**: no collider, no simulation state, `make sim-baseline` unchanged. The collider stays the one
   `hull_size` box, so a shell can pass through empty space inside a jackknife. That is the accepted cost.

Style for everything generated: **[art_direction.md](art_direction.md) is the source of truth** (the
"Death Race prison dozer" north star the lead picked on 2026-09-14): brutally converted real vehicles, riveted slab
armor, grilles, chains, hazard stripes, blackened gunmetal and grime, magenta/cyan neon behind grilles. Concept
art is **photoreal**, never stylized or cartoon. Neon comes through **emissive maps** (lighting is the headline
look), and emissive textures must survive normalization and import.

