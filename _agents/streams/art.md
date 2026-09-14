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

- (nothing yet)

## Status

- 2026-09-15: brief written for round 2. Nothing started.
