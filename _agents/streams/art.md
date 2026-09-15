# Stream: art (units, arena, lighting, crowds)

> Read [../art_direction.md](../art_direction.md) (the source of truth for the look), [../game_design.md](../game_design.md),
> [../workstreams.md](../workstreams.md) (especially **Lead gates**), and [../slot_contracts.md](../slot_contracts.md).
> Then the references: [references/fx_tricks.md](references/fx_tricks.md), [references/asset_prompts.md](references/asset_prompts.md),
> [references/asset_budget.md](references/asset_budget.md), [references/asset_services.md](references/asset_services.md), and
> `assets/README.md`. You own `game/theme/**`, `game/ui/widgets/**`, `game/ui/hud.tscn`, `game/combat/impact.gd`,
> `assets/**`, `tools/assets/`, `mk/assets.mk`, `mk/fx.mk`, `_agents/art_direction.md`, and those references.
> You and rules share `slot_contracts.md`.

## The lead's direction (2026-09-15)

> *"The agent developing assets totally discovered the exact vibe we want for the game with the ridiculous
> up-armored bus. What made Mad Max and Death Race so good was the over-the-top eccentric vehicles … On the look
> and feel front, we took a massive step forward with generating the single asset for a tank. Ideally we do the
> same for the whole map as well as other unit types. The game as it stands is also not well lit enough … We'll
> also eventually want to make the map look like a gladiator arena … where there's actually crowds cheering in the
> stands … we should now start generating more assets, with the caveat that the agent should have me review the
> imagery it's prepared for Meshy before it requests the full blown 3D model … We need the map itself to have
> texture."*

## Where things stand (round 1)

- **Vehicles:** the Meshy prison dozer is the default tank, wrapped by `game/theme/cyberpunk/dozer_part.gd` (team
  accents, underglow, shield). Scouts and artillery are scaled dozers.
- **Cyberpunk theme:** night arena, pooled FX with tier budgets, HUD widgets, synthesized sound. The web `.pck` is
  11.8 MB because the dozer ships its textures three times.
- **Problems found at integration:**
  - The accent strips read as blocky slabs.
  - The pipeline decimated the hull to 7.7k triangles, flattening its treads.
  - The barrel sits above gameplay's muzzle height.
  - The arena is too dark.
- **Meshy key:** it lives in the lead's `~/.bashrc` after the interactive guard, so agent shells don't see it (orientation
  trip-up 59). Load just that line, or ask the lead to move it.

## Lead gate: concept review before any 3D (mandatory)

For every new model: write the prompt from art_direction.md → generate concept images (cheap) → add them to a
**review sheet** (`make art-review` builds `build/review/index.html` with each image, its prompt, the target slot,
and the estimated 3D credits) → list the item under **Waiting on the lead** below → **stop that item** and continue
ungated work. Only images the lead approves (quote their words here) go to image-to-3D. Keep a spend ledger
(`assets/meshy_ledger.md`: date, task id, credits, result).

**Spending (the lead, 2026-09-15):** *"I don't really care about the Meshy spending cap, just don't be wasteful."* No
hard cap. Don't waste credits: batch and iterate on prompts at the cheap concept stage, never send an unapproved
or duplicate image to 3D, reuse previews, and prefer the cheapest mode that meets the slot contract.

## Backlog (ungated items first, gated items as reviews come back)

**X0. The review workflow:** `make art-review`, the ledger, and a short section in `assets/README.md`.

**X1. Vehicle readability** (no gate).
- Replace the boxy accent strips with thin trim or per-team tinting of the model's own neon.
- Drop the muzzle square.
- Add a subtle rim or fill light so textured bodies read at night.
- Raise the vehicle triangle budget to keep the generator's detail (~15k), re-run the dozer build, and verify the treads.
- Close-up and in-game screenshots before/after.
- The raw Meshy downloads are in `assets/incoming/meshy/` (git-ignored; preserved from round 1).

**X2. Lighting pass** (no gate): the arena readable at a glance on phone and desktop, without losing the neon
mood. Brighter key and fill plus floodlights, measured in the FX lab against the tier budgets.

**X3. Textured ground** (no gate): concrete or asphalt with hazard paint, oil stains, tire marks, and drains,
tileable without obvious repeats, on the chunked ground. CC0 texture sets (verify and record licenses) or Meshy
texture generation (gated if it spends credits).

**X4. The unit roster in Meshy** (gated). Concepts for scout (rally truck or buggy, fixed hood gun), IFV (armored
bus or garbage truck with a 30 mm turret), artillery (crane carrier with a mortar battery), and Lancer (utility truck
with a laser emitter), all in the prison dozer's style: over-the-top, converted, photoreal. After approval: 3D,
the pipeline, and `unit.<id>.*` slots (from rules' R3). Share one texture set per unit (fixes the web download size).

**X5. The gladiator arena** (concepts gated, the rest not):
- stands, walls, gates, and floodlight towers around the perimeter, fitted to the arena layout (`arena.dressing`
  `setup(layout)`, C5)
- **crowds**: GPU-instanced impostor sprites or MultiMesh with shader-driven idle and cheer animation that reacts to
  match events (kills, close calls) through the announcer or HUD messages
- crowd audio

Everything stays inside the tier budgets.

**X6. Arena props from Meshy** (gated): barriers, containers, and scrap piles matching `prop.<type>` footprints.

- **Stretch:** an engine sound per unit type, wrecks that burn after a kill (needs a rules hook), and weather or
  smoke within budget.

## How to verify

`make check` with the sim baseline **unchanged**, `make vehicle-gallery`, `make fx-bench` (tier budgets hold),
`make skirmish-shots`, `make web-smoke`, and the web `.pck` size. Look at every screenshot; compare with the
concept art.

## Don't touch

Gameplay collision, stats, and layouts (rules), behavior (ai), UI logic and camera (command), army flow (army).

## Waiting on the lead

**Concept review #1 (2026-09-14, 17 images + 1 superseded, 162 credits):** tap Approve/Reject on the private review page
https://claude.ai/artifact/Hg4RfJSgmP1xeJvfokkJk1 (decisions save to its database; the agent reads them with `read_db`),
or `make art-review` → `build/review/index.html` in the art worktree (pictures in `assets/review/images/`). Pick at most one per unit or prop, or ask for another direction:
- **Scout** (fixed hood gun): `scout_a` desert trophy truck, `scout_b` caged dune buggy, `scout_c` police interceptor muscle car
- **IFV** (fast 30 mm turret): `ifv_a` school bus with slat armor, `ifv_b` garbage truck, `ifv_c` cash-in-transit truck
- **Artillery:** `artillery_a` crane carrier with a mortar battery, `artillery_b` cement mixer turned mortar drum
- **Lancer:** `lancer_a` utility bucket truck with a laser boom, `lancer_b` transformer flatbed with a coil cannon
- **Arena:** `arena_key_b` (mood picture for lighting/ground/dressing, never 3D), `stands_a` grandstand section,
  `gate_a` perimeter wall with gate, `tower_a` floodlight tower
- **Props:** `container_a` (prop.crate), `barrier_a` (prop.wall, tiled), `scrap_a` (a future scrap obstacle type)

Estimated 3D cost if one of each is approved: 10 × 15 = 150 credits (image-to-3D meshy-t2, textured).

**Decisions (the lead, 2026-09-14 21:44–21:54 UTC, on the review page: Approve/Reject taps, no comments):**
- **Approved → 3D:** `scout_b` caged dune buggy, `ifv_b` armored garbage truck, `artillery_a` crane carrier with a
  mortar battery, `lancer_b` transformer flatbed with a coil cannon, `stands_a`, `gate_a`, `tower_a`, `container_a`,
  `barrier_a`, `scrap_a`. `arena_key_b` approved as the mood target (no 3D).
- **Rejected:** `scout_a`, `scout_c`, `ifv_a`, `ifv_c`, `artillery_b`, `lancer_a`.
- Recorded in `assets/review/review.json` (`make art-review-status`). 3D requests sent right after (meshy-t2, textured).

## Status

_Updated 2026-09-14 (agent)._

**Plan** (order: unblock the lead's review first, since concepts are cheap and the 3D waits on them; then ungated work):
1. X0 review workflow + concept batch 1 → **done**
2. X1 vehicle readability (team tint of the model's own neon, no muzzle square, rim light, 15k hull budget, one texture set per unit)
3. X2 lighting pass (floodlights, brighter key/fill; fx-bench tier budgets)
4. X3 textured ground (CC0 concrete/asphalt + hazard paint, oil, tire marks, drains)
5. X5 ungated: stands/walls/towers fitted to `arena.dressing` `setup(layout)`, instanced crowds that cheer on events, crowd audio
6. X4/X5/X6 3D + pipeline + slots as approvals arrive
7. Stretch: engine sound per unit type, burning wrecks, weather/smoke

**Done**
- **X0** (commit eebd2e9): `make art-concept` / `art-review` / `art-review-status` / `art-decide`
  (`tools/assets/review.py`); `generate.py` logs every Meshy task to `assets/meshy_ledger.md` (credits + balance),
  refuses 3D without an approved `--review-item`, refuses a duplicate 3D request for the same concept, and gained
  `--keep-background` for scene art. 15 Python tests (the gate test is proven to fail without the gate).
- **Concept batch 1:** 18 images (162 credits; balance 838), published as a review page with per-concept approve/reject. See *Waiting on the lead*.

- **X1 vehicle readability:**
  - The added accent slabs and the square muzzle ring are gone. The model's own cyan and magenta light bars now
    glow in the team color (`game/theme/fx/shaders/unit_body.gdshader` + `UnitSkin`), while red and amber
    warning lights keep their color.
  - Paint and heat are per-instance uniforms on one shared material per unit. Heat applies to barrels only.
  - A cool rim term lifts the dark gunmetal off the night floor.
  - Hull budget 8k → 15k: the dozer hull is now 13,410 tris with no decimation, and the treads' road wheels are back.
  - One texture set per unit: `--textures-from=tank.hull` ships the turret and cannon untextured, and they wear the
    hull's materials (`generated_visual.gd` `material_source`). `game/theme/prison_dozer/generated`: 27 MB → 9.7 MB.
  - Vehicle gallery draw calls: 136 → 108.
  - Before and after screenshots: `build/screenshots/x1_before/`, `x1-gallery*.png`, `prison_dozer-unit-day.png`.
  - Not changed (rules' call): the barrel still sits ~0.65 m above gameplay's muzzle height until catalog v2's
    per-unit `muzzle_height` lands.

- **Review #1 → 3D:** the 10 approved concepts generated (meshy-t2 textured, 150 credits; balance 688).
- **X4 roster** (theme `roster`, `make assets-roster` = `tools/assets/build_roster.sh`):
  - **Units:** scout (caged dune buggy with a nose gun, no turret), IFV (garbage truck with a turret and 30 mm gun),
    artillery (crane carrier whose mortar rack is the turret), Lancer (transformer flatbed with a turntable and coil
    emitter).
  - **Slots:** filled per rules' C6 (`unit.<id>.hull/turret/weapon`) in the cyberpunk theme; the scout's turret and
    the artillery's weapon are deliberately empty (`units/no_part.tscn`).
  - **Contract checks:** all 10 parts pass `make assets-check`, and one texture set ships per unit.
  - **New pipeline tools:**
    - `--split=regions` (label islands by boxes), `--place-from` (keep the generated placement in turret space,
      with `--center`, `--shift-from` and `--stretch`), and unit contracts mirrored from catalog v2 in
      `AssetContracts.UNITS`.
    - `make assets-view` (raw-model turnaround and split preview) and `make assets-unit UNIT=<id> THEME=roster`.
    - Vehicle gallery `--gallery-units`.
  - Screenshots: `build/screenshots/roster-*-day.png`, `x4-roster-gallery.png`.
- **X2 lighting + X3 textured floor:**
  - **Floor** (`arena_ground.gdshaderinc`): CC0 cracked asphalt, a baked arena macro map (weathering, rectangular
    concrete slabs, oil), skid marks, worn hazard paint (a perimeter band and a center ring), drain grates, and
    painted floodlight pools (a light map baked from `FLOODLIGHTS`).
  - **Lighting:** a neutral white key (moon 0.65 → 1.15) and less blue ambient.
  - **Cost:** the tier-high floor is +1.9 ms, and the low/medium lite floor is +0.1 ms (full numbers in
    `references/fx_tricks.md`). The first version cost +6.6 ms and was rebuilt.
  - Screenshots: `x3-skirmish.png`, `x3-phone-low.png`, `x3-overview.png`.

- **X6 props:**
  - The approved container and barrier fill `prop.crate` and `prop.wall` in the cyberpunk theme
    (`make assets-arena-kit`).
  - `prop_generated.gd` adds a neon hazard frame on the floor around each cover footprint (amber for crates, violet
    for walls). Without it the textured props vanished in the 200 m tactical overview (trip-up 46).
  - Prop budgets are 4k (crate) and 8k (wall of 4 barriers).
  - Stretched props are refit to their collision box after decimation, which had shaved off tops (beacons, spikes).
  - The scrap pile is in `kit.scrap_heap`, waiting for a scrap obstacle type (rules' C5).
- **X5 gladiator venue:**
  - The arena dressing adds 18 Meshy grandstand modules along the long walls, gates in the short walls, and the
    generated floodlight tower at each corner (the fake beams are kept).
  - **The crowd** (`CrowdSystem`, `crowd.gdshader`, `tools/assets/build_crowd.py`): ~2,000 spectators in one
    MultiMesh draw. They idle-sway, and jump with arms up after a kill (strongest within 90 m of it) via the new
    `FxWorld.spectacle` signal, then settle in ~6 s. A few neon-shirted fans, and phone flashes when it's loud.
  - **Crowd audio:** a synthesized murmur loop whose volume follows the excitement, and a roar after kills
    (`make sfx`; the existing WAVs stayed byte-identical).
  - **Cost:** +0.3 ms at tier high, +0.14 ms at low.
  - Screenshots: `x5-stands.png` (mid-cheer), `x5-title.png`, `x5-overview.png`, `x6-skirmish.png`, `x6-overview.png`.
- **Web:**
  - `make web-smoke` passes.
  - Normal and ORM maps are capped at 512 on units (`--texture-caps`), because the `.pck` had grown to 22.4 MB with
    all five units at 1024. Re-measure after the next export.

**Decisions**
- The crowd is emissive-lit silhouettes (a procedural atlas), not meshes: at RTS distance a spectator is a few
  pixels, so motion and density carry it; one draw call. Clothes stay grimy and desaturated (6% neon fans):
  saturated shirts read as cartoon.
- Stands only on the long walls, and gates on the short ones: 18 modules keep the triangle count near 95k before
  LODs. The perimeter is mostly out of frame from the gameplay camera.
- Unit hull art may rise to 1.35× the collision height (`AssetContracts.UNIT_ART_HEIGHT`) so a garbage truck isn't
  shrunk to a toy by the 1.6 m box; gameplay collision is unchanged.
- Real barrels (scout, IFV) are stretched from their breech to the gameplay muzzle; the Lancer's coil emitter is not
  (it would look silly 4× longer), so its beam starts ~2.3 m ahead of the lens until rules can move the muzzle.
- The floor has no normal map (2 ms at tier high for relief the RTS camera barely shows) and no concrete texture
  (slabs are a baked tint over the asphalt): texture fetches are this GPU's bottleneck.
- Team identity on generated vehicles = the model's own neon tinted per team + the underglow (no added strips):
  at the skirmish camera the underglow and nameplates carry friend/foe; up close the tinted light bars do.
  ACES tonemapping bleached bright cyan to white, so team neon energy is moderate (0.6 × 4).
- Concept review images are committed as 1024 px JPEGs (`assets/review/images/`, ~150 KB each, `.gdignore`d) so
  the record survives a worktree removal; Meshy concept tasks expire ~3 days after creation, so a late approval
  sends the local image instead of the task id.
- Three directions each for the scout and IFV (the units the lead named), two for artillery and Lancer, one per
  arena piece and prop: choice where the silhouette matters most.
- `arena_key` (first try) was superseded: background removal erased the scene. Mood art now uses `KEEP_BG=1`.

**Questions for the lead**
- (none open; review #1 answered)

**Requests to other streams**
- **rules:** per-unit muzzle placement to match the art (C1 extension), e.g. `muzzle_forward` and a higher
  `muzzle_height` where hulls allow. Measured visible gun tips in turret space: IFV and scout reach −3.2 (stretched),
  the Lancer's emitter −0.93 (beam starts 2.3 m ahead of it), and the dozer's barrel sits ~0.65 m above 1.27 m.
  Raising muzzles needs taller hull boxes (trip-up 15), so it's your call.
- **rules (C5):** when arena layouts land, `arena.dressing.setup(layout)` will want `half_size` and obstacle
  positions for hazard borders and stands; the floor's perimeter band is hard-coded at 108 m for now.

**Shared-file edits (for the merge notes)**
- `Makefile`: `art-concept art-review art-review-status art-decide` added to `LIGHT_GOALS`.
