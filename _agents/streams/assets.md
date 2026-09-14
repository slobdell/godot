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

Style for everything generated: **[../art_direction.md](../art_direction.md) is the source of truth** (the
"Death Race prison dozer" north star the lead picked on 2026-09-14): brutally converted real vehicles, riveted slab
armor, grilles, chains, hazard stripes, blackened gunmetal and grime, magenta/cyan neon behind grilles. Concept
art is **photoreal**, never stylized or cartoon. Neon comes through **emissive maps** (lighting is the headline
look), and emissive textures must survive normalization and import.

## First milestone

One generated tank hull (and turret) rendering in a test theme at the right size and orientation,
`make assets-check` enforcing the table above, and the determinism hash unchanged.

## Status

- 2026-09-13: brief and slot contracts written. Nothing started.
- 2026-09-14: overnight backlog added (no keys/GPU: research, pipeline, mock-tested providers, CC0 + procedural models). `fx.shell` slot landed.

### Overnight run 2026-09-14: morning report

**TL;DR.** The whole backlog (A0–A5) and the stretch items are done. There's a working pipeline from "a GLB from anywhere"
(AI service, CC0 pack, or code) to "a model in a visual slot that meets its contract", enforced by `make assets-check`
and 18 Godot + 9 Python tests. The Meshy/Tripo client is ready and waits only for a paid key. Two art sets: `kitbash` (CC0
Quaternius tank, containers, neon sign sheet) and `neon_kit` (procedural neon props in the look & feel palette),
both viewable in native and browser galleries and in the real game. Three findings for others: **`sim-baseline` flakes
under load (cause found: async navigation sync)**, **screenshots were being shipped inside the web .pck (+0.9 MB)**,
and **the default `fx.shell` is 17× its triangle budget**. `make check` and `make web-smoke` pass on the last commit.

**Done**
- **A0 service research**, [references/asset_services.md](references/asset_services.md). **Meshy** first: API on Pro (~$20/mo), `target_polycount`, paid-tier outputs owned by us, and the only service that returns an **emission map** (meshy-6 + `enable_pbr`). **Tripo** second, **Rodin** later for hero hulls. Luma Genie and CSM have shut down. Open models need 6–29 GB of VRAM, and none output emissive maps.
- **A1 normalize + check pipeline** (Godot code in `assets/pipeline/`, runtime wrapper `assets/runtime/generated_visual.gd`). `make assets-inspect / assets-normalize / assets-check / assets-slots`. Normalize: select meshes by name → remap forward/up to −Z/+Y → fit (contain/stretch/length) + slot anchor → bake skins and transforms, one surface per material → decimate to budget (sparing small detail surfaces) → compact + re-anchor → textures ≤ 1024 → strip material features Compatibility lacks → optional emissive-from-albedo / emission map / `--palette` / `--repeat` tiling → GLB + wrapper `.tscn` + `manifest.json` (source, license, options). The wrapper implements `set_team_color`, `set_heat`, `set_shield`, `set_firing`, `setup` by material-name globs. Tests: synthetic wrong-scale / sideways / dense / 4096² / collision models, emissive GLB round trip, team tint, palette, shield; each new test confirmed red on broken or old code.
- **A2 provider clients**, `tools/assets/generate.py`: Meshy text-to-3D (preview → refine with PBR) and image-to-3D, plus Tripo v3. Polygon target = 85% of the slot budget. Downloads GLB + maps + a JSON sidecar with the license note. Tested against `tools/assets/mock_provider.py` (progress, 401/402/429 retry, FAILED).
  **To turn it on:** buy Meshy Pro, `export MESHY_API_KEY=msy_…` in your shell profile, then `make assets-generate PROVIDER=meshy SLOT=tank.hull PROMPT="…"` → `make assets-inspect` → `make assets-normalize`. Prompts: [references/asset_prompts.md](references/asset_prompts.md).
- **A3 `kitbash` theme** from CC0 packs (licenses quoted in `assets/CREDITS.md`). Rebuild from its recipe with `make assets-kitbash` (`tools/assets/build_kitbash.sh`, deterministic):
  - Quaternius tank → `tank.hull` 5,974 tris / `tank.turret` 392 / `weapon.cannon` 178 (muzzle exactly at gameplay's z = −3.2)
  - Container Small → `prop.crate` 920
  - 4 × Shipping Container → `prop.wall` 2,656
  - candidates: `kit.light_pole`, `kit.billboard` (13 glowing neon signs, a ready-made sign sheet for look & feel)
  - Seen in `make assets-gallery THEME=kitbash` and in the real game with `make assets-preview THEME=kitbash FLAGS=--skirmish`.
- **A4 procedural `neon_kit`**, `make assets-procedural` (seeded, project-owned):
  - neon cargo-stack `prop.crate` (324 tris)
  - blast-barrier `prop.wall` with light bars and holo-ad panels (268 tris)
  - candidates: container, jersey barrier, light pole, billboard, scrap pile (56–360 tris each)
  - Palette: cyan/pink/purple from look_and_feel.md, plus amber hazard lights. `neon_team*` materials take team color.
- **A5 budget report**, [references/asset_budget.md](references/asset_budget.md) (`make assets-report`):
  - per-asset tris, draw calls, texture memory, and packed bytes
  - exact web `.pck` breakdown (`tools/assets/pck_report.py`)
  - texture compression modes measured
  - **Texture policy** in the pipeline: ≤ 256 px lossy, larger → Basis Universal, enforced by `assets-check`
  - `--palette` cut kitbash match draw calls: props 38 → 19, tanks 70 → 50
  - LODs: the Compatibility renderer uses the importer's LODs, and `mesh_lod_threshold` ≈ 4 cuts ~35% of tank tris at play distance, a free quality-tier knob
- **Stretch:** prompt library + style guide; [`assets/README.md`](../../assets/README.md) (how to bring a model into the game, written for the lead's son); LOD measurements; browser proof with `make assets-web-gallery` (Basis texture + emissive + glow render in headless Chrome/WebGL 2).

**Screenshots reviewed** (`build/screenshots/`): `assets-gallery-kitbash-1920x864.png`, `assets-gallery-kitbash-kit.b-1920x864.png` (neon signs), `assets-gallery-neon_kit-1920x864.png` and `-night-`, `assets-preview-kitbash-1600x900.png` (skirmish), `assets-preview-kitbash-1920x864.png` (demo, ~20:9), `assets-web-gallery-kitbash-kit.b.png` and `assets-web-gallery-neon_kit-night.png` (browser), `web.png`.

**Decisions** (each reversible)
- Pipeline GDScript lives in `assets/pipeline/`, not `tools/assets/`: `tools/` has a `.gdignore`, so `class_name` scripts there never register. `tools/assets/` holds the non-Godot tooling.
- Slot contracts are data (`asset_contracts.gd`), matched to today's placeholder art so swapping art never moves gameplay:
  - turret bottom at pivot −0.275 (the default hull deck)
  - barrel from z = −0.7 to the muzzle at z = −3.2, at y = 0.05
  - props **stretch** to their exact collision box; vehicles scale uniformly
- The wrapper finds materials by **name** (per-instance copies), so any model joins team color / neon / heat / shield by naming its materials.
- Skinned meshes are baked to rest pose; pack tread animations are dropped.
- Walls are **tiled** from segments, not stretched. A see-through fence wall was rejected because it misleads players about cover.
- Decimation lowers the largest surface first and never touches surfaces ≤ 64 tris / 10% unless it must: whole-model LOD steps erased the neon signs. Unused vertices are compacted and the anchor is re-applied afterwards.
- Unchanged GLBs aren't rewritten; otherwise Godot wouldn't re-import them and their extracted textures would vanish.
- `--palette` merges only flat, untextured, non-emissive, non-tint materials; the vertex-color flags glTF drops are restored by the wrapper.
- Raw downloads go in `assets/incoming/` (git- and Godot-ignored). Screenshot targets write `build/.gdignore`.

**Questions for the lead**
1. Buy Meshy Pro (~$20/mo) now to start generating, or stay on CC0 + procedural art until look & feel settles the style?
2. Basis textures on your phone: they render in desktop Chrome; phone load time is unmeasured. To check, remove the `rm -rf "$out"` cleanup in `tools/assets/web_gallery.sh`, run `make assets-web-gallery THEME=kitbash ONLY=kit.b`, then `python3 tools/serve_web.py build/web-gallery 8090 0.0.0.0` and open it on the phone.

**Requests to other streams**
- **Gameplay / netcode: `make sim-baseline` is flaky, and I found why.**
  - It failed 2 of ~12 runs overnight, each time with a different hash (`40503279562bab7e`, `72906422db671e8b`), while other worktrees loaded the machine.
  - Godot 4.7 syncs navigation maps on a worker thread (`navigation/world/map_use_async_iterations=true` by default), so `Pathing.is_ready` turns true at physics **frame 5 idle but 3–4 under load** (measured), and brains steer straight until then.
  - With `navigation/world/map_use_async_iterations=false` + `region_use_async_iterations=false` (tried via a local override.cfg, since reverted), it's **frame 2 in 10/10 runs, idle or loaded**.
  - The fix is a `project.godot` edit + a baseline hash update, which is gameplay's call. `make determinism` can't catch it (both of its runs see the same load), and lockstep netcode would inherit it.
- **Look & feel:**
  - The default `fx_shell.tscn` capsule is 3,456 tris against a 200 budget.
  - Candidate art: `make assets-gallery THEME=neon_kit NIGHT=1` and the kitbash sign sheet (`ONLY=kit.b`). Point slots at `game/theme/<theme>/generated/*.tscn`, or copy pieces into `cyberpunk/`.
  - `mesh_lod_threshold` is a quality-tier knob for L6.
- **Gameplay (proposal for directive set 2):** per-class vehicle slots (`scout.hull`, `artillery.hull`, …) sized from each class's collision; the pipeline needs one contract row each, and 3 more Quaternius tank variants are ready.
- **Integrator (shared files, not edited overnight):**
  1. `mk/core.mk` `import`: `mkdir -p build && touch build/.gdignore` (screenshots ship inside the web .pck today, ~0.9 MB measured)
  2. `export_presets.cfg` `exclude_filter` += `assets/pipeline/*, game/theme/kitbash/*` until a theme uses them (≈ 520 KB of web download)
  3. later, `project.godot` `import_etc2_astc=true` for Android

**Merge notes**
- **Shared-file edits:** the root `Makefile` `LIGHT_GOALS` gets `assets-generate assets-mock` (one line, so remote waits don't hold a heavy-run slot).
- **New files outside owned paths:** `tests/test_assets_pipeline.gd` (+ `.uid`), plus `_agents/streams/references/asset_{services,budget,prompts}.md`.
- **Everything else** is in owned paths: `assets/`, `tools/assets/`, `mk/assets.mk`, `game/theme/{kitbash,neon_kit}/generated/`.
- **No gameplay code was touched.** `sim-baseline` is unchanged (`e69acc63a64f319a`). The branch isn't rebased on `main` (overnight rule).
- **Web pack cost:** the two test themes add ~550 KB to it until excluded (integrator item 2).
- **Proposed orientation trip-ups** (not added overnight, to avoid five streams conflicting on that list):
  1. `tools/` has a `.gdignore`, so `class_name` scripts there are invisible to Godot; Godot code goes under `game/` or `assets/`.
  2. Anything under `build/` without a `.gdignore` gets imported and **exported into the .pck** (screenshots added ~0.9 MB).
  3. Navigation maps sync asynchronously by default, so anything waiting on `Pathing.is_ready` is load-dependent (the sim-baseline flake).
  4. Release web templates refuse a scene path on the command line; export a copy with a different `run/main_scene` instead (`tools/assets/web_gallery.sh`).

**Known issues**
- The orphan-file check can't flag a stale texture that shares a live model's name prefix (the next normalize removes it).
- Kitbash billboard decimation is aggressive after the palette merge (282 tris for budget 1000); the signs are intact.
- Windowed shots are clamped to the display (1854×1011); use `SCREEN=1920x864` for 20:9.
- Browser galleries are darker than native (SwiftShader lighting); judge brightness natively.

**Next steps** (assets stream)
1. With a key: generate a hero hull/turret/cannon from `asset_prompts.md`, normalize, and log results in its Results table.
2. Per-class slots once gameplay adds unit classes; normalize the other Quaternius tank variants.
3. After look & feel picks pieces: trim unused test themes from the export.
4. Only if `fx-bench` shows draw calls hurting: share one grime texture across the neon kit's materials so they can merge.

**What to playtest**
- `make assets-gallery THEME=kitbash` · `make assets-gallery THEME=neon_kit NIGHT=1` · `make assets-web-gallery THEME=kitbash ONLY=kit.b`
- `make assets-preview THEME=kitbash FLAGS=--skirmish` (screenshot). To play it: `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . res://assets/pipeline/theme_preview.tscn -- --theme=kitbash --skirmish`
- `make assets-test` · `make assets-check` · `make assets-report` · `make assets-kitbash` (rebuild; git should stay clean)

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. **Constraints tonight:** no API keys or accounts for any 3D service, no discrete GPU (so no local generation models), ~9 GB disk shared by five agents (**≤ 500 MB of downloads**). The pipeline and everything around it can still be built and proven.

1. **A0 service research** (`_agents/streams/references/asset_services.md`): Meshy, Tripo, Rodin/Hyper3D, Luma, CSM, and others you find, plus open models (TRELLIS, Stable Fast 3D, Hunyuan3D) for later GPU use. Cover current pricing, API availability, output formats, polygon/texture control, **license terms for commercial use of outputs**, and quality notes. Cite sources with dates. End with a recommendation.
2. **A1 normalize + check pipeline** (headless Godot tooling in `tools/assets/`): load a GLB (`GLTFDocument`), report bounds/tris/materials/texture sizes, and scale/orient/recentre to the slot contract. Keep **emissive** maps intact. Write `game/theme/<theme>/generated/<slot>.glb` + a wrapper `.tscn` implementing the slot's optional methods (e.g. `set_team_color` by tinting a named material). `make assets-check` enforces the contract table. Tests use synthetic GLBs produced by `GLTFDocument` export from procedural meshes (wrong scale, wrong forward axis, too many tris…).
3. **A2 provider clients, ready for keys:** `make assets-generate PROVIDER=<name> PROMPT=… SLOT=…` reading the key from an environment variable. Implement the recommended provider's API flow, tested against a local mock HTTP server (no network, no key). Document how the lead turns it on.
4. **A3 real models without accounts:** pick CC0 packs (e.g. Kenney, Quaternius, Poly Haven; verify each license on its page and record it in `assets/CREDITS.md`) with vehicle and industrial/sci-fi props. Run a handful through the pipeline into a `kitbash` test theme (tank hull/turret, 2–3 props) and take screenshots in-game. `make sim-baseline` unchanged.
5. **A4 procedural cyberpunk kit** (fallback and filler art): a headless Godot script that builds shipping containers, concrete barriers, light poles, billboards, and scrap piles from primitives with emissive neon strips → GLB via the same pipeline, as candidates for look & feel (who decides what fills slots). Hand them over through the Status notes.
6. **A5 web/mobile budget report:** per-asset triangle and texture-memory numbers, `.pck` size impact of the kitbash theme, and texture compression import settings for web/mobile (a `project.godot` change is a shared edit; propose it in your notes).
- **Stretch:** a cyberpunk **prompt library + style guide** for when keys exist (hero tank, scout, artillery, props), LOD generation, and a pipeline doc for the lead's son (how to bring a model into the game).
