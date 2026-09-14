# Stream: Assets (AI-generated 3D models into the game)

> Read [../workstreams.md](../workstreams.md) and [look_and_feel.md](look_and_feel.md).
> You own `assets/`, `tools/assets/`, `mk/assets.mk` (new), and `game/theme/<theme>/generated/`.
> Coordinate art direction (prompts, style) with look & feel; they own which scene fills a slot.

## Goal

A repeatable path from "prompt an AI 3D generator" to "a model sitting correctly in a visual slot,
fast enough for phones and the web".

## Services to evaluate (verify current offerings, pricing, API access, and license terms first)

Text- and image-to-3D generators such as Meshy, Tripo, Rodin (Hyper3D), and Luma, plus open models
(e.g. Stable Fast 3D, TRELLIS) that can run locally. Criteria: glTF/GLB export, API automation,
texture quality, polygon control/remeshing, **commercial-use license for generated output**, cost.
API keys live in environment variables, never in the repo.

## Pipeline to build

```
prompt / reference image ─▶ service ─▶ assets/incoming/<name>.glb   (raw; not committed if large)
   ─▶ tools/assets/normalize   scale to the slot's size, forward = −Z, origin at the slot's anchor,
                               decimate to the triangle budget, textures ≤ 1024², materials the
                               Compatibility renderer supports
   ─▶ tools/assets/check       budgets + orientation + bounds report (make assets-check)
   ─▶ game/theme/<theme>/generated/<slot>.glb + a wrapper .tscn implementing the slot's methods
   ─▶ GameTheme slot points at the wrapper (look & feel's call)
```

Godot imports glTF natively; commit `.import` files. Prefer git LFS (or committing only
optimized GLBs) for binaries.

## Slot contracts

All: units are meters, **forward is −Z**, up is +Y, and origin as stated. Visuals must not add collision.

| Slot | Anchor / origin | Size guide (matches gameplay collision) | Optional methods | Budget |
|---|---|---|---|---|
| `tank.hull` | ground contact, center of the hull | 2.4 wide × 3.6 long × ≤ 1.6 tall (turret ring at y ≈ 1.22, z ≈ +0.2) | `set_team_color(Color)` | ≤ 8k tris |
| `tank.turret` | turret pivot (rotates about +Y) | ~1.4 × 1.7 × 0.55 | `set_team_color` | ≤ 4k tris |
| `weapon.cannon` | turret pivot; barrel along −Z | muzzle ~3.2 m ahead of the pivot (gameplay fires from there) | `set_team_color`, `setup(weapon)` | ≤ 2k tris |
| `weapon.flamethrower` | turret pivot; nozzle along −Z | short; show a flame effect ~20 m long | `set_team_color`, `setup(weapon)`, `set_firing(bool)` | ≤ 2k tris + FX |
| `prop.crate` | ground center | 4.5 × 3 × 4.5 | — | ≤ 2k tris |
| `prop.wall` | ground center | 18 long (X) × 3 tall × 1.5 thick | — | ≤ 3k tris |
| `weapon.laser` *(planned, gameplay G7)* | turret pivot; emitter along −Z | like the cannon | `set_team_color`, `setup(weapon)`, `set_firing(bool)`, `set_heat(ratio)` | ≤ 2k tris |
| `fx.shell` | projectile center, flying along −Z | ~0.3 × 0.3 × 1 | — (tracer + light; look & feel may pool) | ≤ 200 tris |
| `fx.laser_beam` *(planned, gameplay G7)* | muzzle | stretched to the hit point | `setup(from: Vector3, to: Vector3)` | FX only |
| `arena.environment` | world origin | sky/lighting/fog only | — | — |
| `arena.dressing` | world origin | ground 320×320 at y=0; perimeter walls at ±121 | — | ≤ 50k tris |

Style for everything generated: the cyberpunk gladiator arena (look_and_feel.md). Dark, weathered
scrap and metal **with emissive maps** for neon strips, lights, and signage, since lighting is the
game's headline look. Emissive textures must survive normalization and import.

## First milestone

One generated tank hull (and turret) rendering in a test theme at the right size and orientation,
`make assets-check` enforcing the table above, and the determinism hash unchanged.

## Status

- 2026-09-13: brief and slot contracts written. Nothing started.
- 2026-09-14: overnight backlog added (no keys/GPU: research, pipeline, mock-tested providers, CC0 + procedural models). `fx.shell` slot landed.

### Overnight run 2026-09-14: morning report (kept current as work lands)

**Plan (backlog order):** A0 research → A1 normalize/check pipeline → A2 Meshy client vs mock → A3 CC0 kitbash theme → A4 procedural kit → A5 budget report → stretch (prompt library, LODs, son's guide).

**Done**
- **A0** [references/asset_services.md](references/asset_services.md): Meshy recommended first (API on Pro ~$20/mo, `target_polycount`, smart-topology 100–15k faces, paid-tier outputs owned by us; only service with an emission map: meshy-6 + `enable_pbr`), Tripo second, Rodin for later hero hulls. Luma Genie and CSM are gone. Open models all need ≥ 6–29 GB VRAM and none output emissive.
- **A1** pipeline (Godot-side code in `assets/pipeline/`, runtime wrapper in `assets/runtime/`): `make assets-inspect IN=… [SLOT=…]`, `make assets-normalize IN=… SLOT=… THEME=… ARGS=…`, `make assets-check`, `make assets-slots`. Normalize = select meshes by name glob → rotate source forward/up to −Z/+Y → contain/stretch/length fit + slot anchor → bake transforms, merge per material (1 draw call per material) → meshoptimizer LOD decimation to budget → textures ≤ 1024 → strip Compatibility-unsupported material features → optional emissive-from-albedo → GLB + wrapper `.tscn` + `manifest.json` (source, license, options). 12 tests in `tests/test_assets_pipeline.gd` (synthetic wrong-scale / sideways / dense / 4096² / collision models; emissive GLB round trip; per-instance team tint). Verified two tests go red when orientation and decimation are broken.

- **A2** `tools/assets/generate.py` (stdlib Python): Meshy text-to-3D preview → refine (`ai_model: meshy-6`, `enable_pbr` so the emission map comes back) and image-to-3D; Tripo v3 text-to-model. `target_polycount` = 85% of the slot budget, read from `asset_contracts.gd`. Downloads GLB + texture maps + a JSON sidecar (task, prompt, license note) into `assets/incoming/`. Tested against `tools/assets/mock_provider.py` (status progression, 401/402/429 retry/FAILED paths): 9 tests via `make assets-test`. `--emission-map=<png>[:glob]` on normalize wires a delivered emission map in.
  **How the lead turns it on:** buy Meshy Pro (~$20/mo, API access), `export MESHY_API_KEY=msy_…` in your shell profile, then `make assets-generate PROVIDER=meshy SLOT=tank.hull PROMPT="…"` → `make assets-inspect IN=assets/incoming/<name>.glb SLOT=tank.hull` → `make assets-normalize …`. Without a key the command prints these steps and exits 3.
- **A3** `kitbash` test theme from CC0 packs (licenses quoted in `assets/CREDITS.md`, sources in `game/theme/kitbash/generated/manifest.json`, re-fetch with `make assets-kitbash`): Quaternius tank → `tank.hull` 5974 tris / `tank.turret` 392 / `weapon.cannon` 178 (muzzle at z = −3.20); Quaternius Container Small → `prop.crate` 920; 4 × Shipping Container → `prop.wall` 2656 (decimated from 5344); candidates `kit.light_pole` (Street Light, emissive lamp) and `kit.billboard` (Cyberpunk Signs, emissive). Tools to look at them: `make assets-gallery THEME=kitbash` (models beside default art, contract ghost boxes, muzzle marker) and `make assets-preview THEME=kitbash FLAGS=--skirmish` (the real game with the theme's slots swapped in via `assets/pipeline/theme_preview.tscn`, no shared edits). Screenshots reviewed: `build/screenshots/assets-gallery-kitbash-1600x900.png`, `assets-preview-kitbash-1600x900.png` (skirmish map), `assets-preview-kitbash-2400x1080.png` (demo; window clamped to 1854×1011 by the display).

- **A4** procedural cyberpunk kit, `make assets-procedural` → theme `neon_kit` (`assets/pipeline/procedural_kit.gd`, seeded, headless, same normalize → GLB → wrapper → manifest path; all project-owned): `prop.crate` neon cargo stack (324 tris, same 4.5 × 3 × 4.5 footprint), `prop.wall` concrete blast barrier with alternating team-neon/pink light bars and holo-ad panels (268 tris, 18 × 3 × 1.5), and candidates `kit.container` 360, `kit.barrier` (jersey, underglow) 56, `kit.light_pole` (hooded lamp, neon strip) 192, `kit.billboard` (procedural neon ad texture) 62, `kit.scrap_pile` 360. Palette from look_and_feel.md (cyan #00F3FF, pink #FF0099, purple #D900FF) plus amber hazard lights. Grime textures 128², sign 256×96. **Handover to look & feel:** `make assets-gallery THEME=neon_kit NIGHT=1` shows them lit by their own neon (`build/screenshots/assets-gallery-neon_kit-night-1920x864.png`, day version beside it). To try them in the arena: `make assets-preview THEME=neon_kit FLAGS=--skirmish`. Materials named `neon_team*` take the team color via `set_team_color`; props aren't painted today, so they show the cyan default unless the arena calls it.

**Decisions**
- Pipeline GDScript lives in `assets/pipeline/`, not `tools/assets/`: `tools/` has a `.gdignore`, so Godot never registers `class_name` scripts there. `tools/assets/` keeps non-Godot tooling (Python provider clients, mock server).
- Slot contracts are data (`assets/pipeline/asset_contracts.gd`). Where the brief's table was loose I picked what matches today's placeholder art, so swapping art never moves gameplay: turret **bottom at y = −0.275** relative to its pivot (sits on the default hull deck at 0.945 m); cannon/laser barrel from z = −0.7 to the muzzle at **z = −3.2**, axis at y = 0.05; props **stretch** to their exact collision box (warning past 2× distortion); vehicles scale uniformly (**contain**); turret max 1.8 × 0.9 × 2.1.
- Wrapper methods work by **material name** globs (`tint_materials`, `team_emissive_materials`, `heat_materials`), so any model joins team colors / neon / heat by naming materials; per-instance material copies.
- Raw downloads go in `assets/incoming/` (git- and Godot-ignored).
- Limitation: bounds can't tell forward from backward; the orientation unit test + screenshots cover the sign.
- Skinned meshes (rigged pack tanks) are baked to their rest pose on load; tread animations are dropped (slots don't animate skeletons).
- Walls are **tiled** from segments (`--repeat=4x1x1`) rather than stretched. The first try (Quaternius Barrier Large ×10) read as a see-through fence, which would mislead players about cover; solid-looking shipping containers replaced it.
- Decimation takes meshoptimizer LOD levels (each about half the previous), so decimated models land at 50–100% of budget. `SurfaceTool.generate_lod` hits exact targets but is deprecated and its warning fails the error-capturing test runner.
- `assets-generate` and `assets-mock` are added to `LIGHT_GOALS` in the root Makefile (shared, one line) so waiting on a remote service doesn't hold a heavy-run slot.

**Questions for the lead**
- (none yet)

**Requests to other streams**
- (none yet)

**Known issues**
- (none yet)

**What to playtest**
- `make assets-slots`, `make test FILTER=assets`

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. **Constraints tonight:** no API keys or accounts for any 3D service, no discrete GPU (so no local generation models), ~9 GB disk shared by five agents (**≤ 500 MB of downloads**). The pipeline and everything around it can still be built and proven.

1. **A0 service research** (`_agents/streams/references/asset_services.md`): Meshy, Tripo, Rodin/Hyper3D, Luma, CSM, and others you find, plus open models (TRELLIS, Stable Fast 3D, Hunyuan3D) for later GPU use. Cover current pricing, API availability, output formats, polygon/texture control, **license terms for commercial use of outputs**, and quality notes. Cite sources with dates. End with a recommendation.
2. **A1 normalize + check pipeline** (headless Godot tooling in `tools/assets/`): load a GLB (`GLTFDocument`), report bounds/tris/materials/texture sizes, and scale/orient/recentre to the slot contract. Keep **emissive** maps intact. Write `game/theme/<theme>/generated/<slot>.glb` + a wrapper `.tscn` implementing the slot's optional methods (e.g. `set_team_color` by tinting a named material). `make assets-check` enforces the contract table. Tests use synthetic GLBs produced by `GLTFDocument` export from procedural meshes (wrong scale, wrong forward axis, too many tris…).
3. **A2 provider clients, ready for keys:** `make assets-generate PROVIDER=<name> PROMPT=… SLOT=…` reading the key from an environment variable. Implement the recommended provider's API flow, tested against a local mock HTTP server (no network, no key). Document how the lead turns it on.
4. **A3 real models without accounts:** pick CC0 packs (e.g. Kenney, Quaternius, Poly Haven; verify each license on its page and record it in `assets/CREDITS.md`) with vehicle and industrial/sci-fi props. Run a handful through the pipeline into a `kitbash` test theme (tank hull/turret, 2–3 props) and take screenshots in-game. `make sim-baseline` unchanged.
5. **A4 procedural cyberpunk kit** (fallback and filler art): a headless Godot script that builds shipping containers, concrete barriers, light poles, billboards, and scrap piles from primitives with emissive neon strips → GLB via the same pipeline, as candidates for look & feel (who decides what fills slots). Hand them over through the Status notes.
6. **A5 web/mobile budget report:** per-asset triangle and texture-memory numbers, `.pck` size impact of the kitbash theme, and texture compression import settings for web/mobile (a `project.godot` change is a shared edit; propose it in your notes).
- **Stretch:** a cyberpunk **prompt library + style guide** for when keys exist (hero tank, scout, artillery, props), LOD generation, and a pipeline doc for the lead's son (how to bring a model into the game).
