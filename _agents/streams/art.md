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

**Decisions**
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
- (none yet)

**Shared-file edits (for the merge notes)**
- `Makefile`: `art-concept art-review art-review-status art-decide` added to `LIGHT_GOALS`.
