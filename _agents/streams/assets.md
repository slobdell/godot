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
| (all tank visuals) | | | optional `set_team_accent(Color)`: the team's friend-or-foe accent, called once at spawn; a loadout's `paint` goes to `set_team_color` instead of the team color | |
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
and 22 Godot + 12 Python tests. **Update (with the lead): the Meshy key is in, and the first production unit exists**: the
"Death Race prison dozer" (theme `prison_dozer`, see the update below), which is also the style north star. Two art sets: `kitbash` (CC0
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

**Update 2026-09-14 (with the lead, Meshy key): first production unit, the prison dozer**
- The lead picked the **Death Race prison dozer** concept as the style north star (documented in [../art_direction.md](../art_direction.md)).
- **Production flow proven end to end** (110 credits total, including rejected and compared variants): photoreal concept (nano-banana-pro) → turnaround → image-to-3D Smart Topology → `--split=tank` → hull/turret/cannon slots → theme `prison_dozer` (`make assets-prison-dozer`, recipe `tools/assets/build_prison_dozer.sh`). Hull 7.7k tris, turret 488, cannon 434; 1024 Basis textures with Meshy's emission map (energy ×4).
- **New pipeline pieces**, each with a regression test confirmed red on the old behavior:
  - `assets/pipeline/asset_splitter.gd`: islands → hull_/turret_/cannon_ by geometry. Turret growth stays inside its footprint and off the deck, so roof rivets aren't turret.
  - Per-part decimation, then merge by material (hull 13.7k → 7.7k, not a whole-model halving to 6.8k).
  - `--deck-from` raises turret and cannon onto a tall hull's roof.
  - `--attach-to` keeps the gun where the generator attached it, stretched along its axis to the gameplay muzzle.
  - `--emission-energy`, `--tint-strength`, `make assets-unit` (close-up turnaround).
  - The client gained concept / turnaround / multi-image / smart-topology / data-URI support.
- **Reviewed:** `build/screenshots/prison_dozer-unit-{day,night}.png` (close-up), `assets-gallery-prison_dozer-*.png`, `prison_dozer-ingame-demo.png` (the real game), and `assets-web-gallery-prison_dozer-tank.png` (browser).
- **Decisions:**
  - The tall-narrow bus body stays in proportion: the hull is height-limited to 1.6 m, so it's 1.6 m wide vs the 2.4 m collision box. `MIN_FILL` was relaxed to 0.8 for that reason.
  - Team tint is 20% so the grime survives (players paint the whole vehicle in the garage; friend or foe is accent lights).
  - The baked neon keeps the concept's cyan/magenta/red mix.
- **Request to gameplay:** units with tall hulls put the visible turret and barrel ~0.65 m above the fixed turret pivot and shell spawn height (1.22 m). A per-unit turret height in the unit catalog would let muzzle flashes and tracers start at the visible barrel.
- **Next:** see *Next steps* below: shared textures per unit first (the dozer ships its maps three times), then friend/foe accent lights, then scout and artillery.

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
1. ~~Buy Meshy Pro?~~ Answered: the lead signed up, and the key lives in `~/.bashrc`. **Rotate it**: it was pasted in chat once.
2. **Git LFS for generated art?** The `prison_dozer` theme commits ~27 MB of GLB/PNG (three copies of the same textures, see
   Known issues). Fine for one unit, not for a roster. Recommend LFS for `game/theme/*/generated/*.{glb,png}` before the second unit.
3. Basis textures on your phone: they render in desktop Chrome; phone load time is unmeasured. To check, remove the `rm -rf "$out"` cleanup in `tools/assets/web_gallery.sh`, run `make assets-web-gallery THEME=kitbash ONLY=kit.b`, then `python3 tools/serve_web.py build/web-gallery 8090 0.0.0.0` and open it on the phone.

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
- **Web pack cost:** the two test themes add ~550 KB to it until excluded (integrator item 2); `prison_dozer` adds **~10.7 MB** until its textures are shared (Known issues).
- **Shared docs edited with the lead (2026-09-14, art direction):** new `_agents/art_direction.md` + `_agents/art/north_star_prison_dozer.jpg` (`.gdignore`'d); one-paragraph links added to `HANDOFF.md`, `_agents/vision.md`, `_agents/workstreams.md` (product constraint 2), `_agents/streams/look_and_feel.md`, and `_agents/streams/garage.md`. Expect small merge conflicts with those streams' own brief edits: keep both.
- **Proposed orientation trip-ups** (not added overnight, to avoid five streams conflicting on that list):
  1. `tools/` has a `.gdignore`, so `class_name` scripts there are invisible to Godot; Godot code goes under `game/` or `assets/`.
  2. Anything under `build/` without a `.gdignore` gets imported and **exported into the .pck** (screenshots added ~0.9 MB).
  3. Navigation maps sync asynchronously by default, so anything waiting on `Pathing.is_ready` is load-dependent (the sim-baseline flake).
  4. Release web templates refuse a scene path on the command line; export a copy with a different `run/main_scene` instead (`tools/assets/web_gallery.sh`).
  5. Agent shells are non-interactive, and Ubuntu's `~/.bashrc` returns early for those, so an `export MESHY_API_KEY=…` at the end of it is invisible to `make assets-generate` run by an agent. Put keys before the interactive guard or in `~/.profile`, or source just that line (what this session did).

**Known issues**
- **`prison_dozer` ships its textures three times.** Hull, turret, and cannon are separate GLBs, and each embeds the same 1024² base/normal/ORM/emission set, so the web pack grows ~10.7 MB (3.5 MB per slot after Basis) and git holds ~27 MB. Fix: extract one shared texture set per unit and point all three slot materials at it (next step 1).
- Tall generated hulls put the visible turret and barrel ~0.65 m above gameplay's shell spawn (request to gameplay above).
- The orphan-file check can't flag a stale texture that shares a live model's name prefix (the next normalize removes it).
- Kitbash billboard decimation is aggressive after the palette merge (282 tris for budget 1000); the signs are intact.
- Windowed shots are clamped to the display (1854×1011); use `SCREEN=1920x864` for 20:9.
- Browser galleries are darker than native (SwiftShader lighting); judge brightness natively.

**Next steps** (assets stream)
1. **Share one texture set per generated unit** across its slots (cuts the dozer's pack cost from ~10.7 MB to ~3.6 MB and its git weight by two thirds), and decide on git LFS with the lead.
2. **Friend/foe accent lights** on generated units (a team-colored emission layer on the neon bars), coordinated with look & feel.
3. **Scout and artillery** as converted vehicles (art_direction.md) through the same flow; per-class slots once gameplay adds unit classes.
4. After look & feel picks pieces: trim unused test themes (`kitbash`, `neon_kit`) from the export.
5. Only if `fx-bench` shows draw calls hurting: share one grime texture across the neon kit's materials so they can merge.

**What to playtest**
- `make assets-gallery THEME=kitbash` · `make assets-gallery THEME=neon_kit NIGHT=1` · `make assets-web-gallery THEME=kitbash ONLY=kit.b`
- `make assets-preview THEME=kitbash FLAGS=--skirmish` (screenshot). To play it: `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . res://assets/pipeline/theme_preview.tscn -- --theme=kitbash --skirmish`
- `make assets-test` · `make assets-check` · `make assets-report` · `make assets-kitbash` (rebuild; git should stay clean)
- **The prison dozer:** `make assets-unit THEME=prison_dozer` (close-up, day + night) · `make assets-gallery THEME=prison_dozer ONLY=tank` · `make assets-web-gallery THEME=prison_dozer ONLY=tank`. To drive it: `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . res://assets/pipeline/theme_preview.tscn -- --theme=prison_dozer`. Rebuild: `make assets-prison-dozer`.

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. **Constraints tonight:** no API keys or accounts for any 3D service, no discrete GPU (so no local generation models), ~9 GB disk shared by five agents (**≤ 500 MB of downloads**). The pipeline and everything around it can still be built and proven.

1. **A0 service research** (`_agents/streams/references/asset_services.md`): Meshy, Tripo, Rodin/Hyper3D, Luma, CSM, and others you find, plus open models (TRELLIS, Stable Fast 3D, Hunyuan3D) for later GPU use. Cover current pricing, API availability, output formats, polygon/texture control, **license terms for commercial use of outputs**, and quality notes. Cite sources with dates. End with a recommendation.
2. **A1 normalize + check pipeline** (headless Godot tooling in `tools/assets/`): load a GLB (`GLTFDocument`), report bounds/tris/materials/texture sizes, and scale/orient/recentre to the slot contract. Keep **emissive** maps intact. Write `game/theme/<theme>/generated/<slot>.glb` + a wrapper `.tscn` implementing the slot's optional methods (e.g. `set_team_color` by tinting a named material). `make assets-check` enforces the contract table. Tests use synthetic GLBs produced by `GLTFDocument` export from procedural meshes (wrong scale, wrong forward axis, too many tris…).
3. **A2 provider clients, ready for keys:** `make assets-generate PROVIDER=<name> PROMPT=… SLOT=…` reading the key from an environment variable. Implement the recommended provider's API flow, tested against a local mock HTTP server (no network, no key). Document how the lead turns it on.
4. **A3 real models without accounts:** pick CC0 packs (e.g. Kenney, Quaternius, Poly Haven; verify each license on its page and record it in `assets/CREDITS.md`) with vehicle and industrial/sci-fi props. Run a handful through the pipeline into a `kitbash` test theme (tank hull/turret, 2–3 props) and take screenshots in-game. `make sim-baseline` unchanged.
5. **A4 procedural cyberpunk kit** (fallback and filler art): a headless Godot script that builds shipping containers, concrete barriers, light poles, billboards, and scrap piles from primitives with emissive neon strips → GLB via the same pipeline, as candidates for look & feel (who decides what fills slots). Hand them over through the Status notes.
6. **A5 web/mobile budget report:** per-asset triangle and texture-memory numbers, `.pck` size impact of the kitbash theme, and texture compression import settings for web/mobile (a `project.godot` change is a shared edit; propose it in your notes).
- **Stretch:** a cyberpunk **prompt library + style guide** for when keys exist (hero tank, scout, artillery, props), LOD generation, and a pipeline doc for the lead's son (how to bring a model into the game).
