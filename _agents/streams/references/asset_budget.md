# A5: web/mobile asset budget report

> Assets stream, 2026-09-14. Regenerate the numbers with `make assets-report` (per-asset tables from
> `assets/pipeline/budget_report.gd`, then a web export broken down by `tools/assets/pck_report.py`).
> Machine: no discrete GPU, so this covers **sizes and memory, not frame time**. Frame time comes
> from look & feel's `make fx-bench` and the lead's phone.

## Per-asset numbers (after the texture policy below)

Columns: **draw calls** = surfaces per instance (one per material). **RGBA8 KB** = GPU memory if textures upload
uncompressed (Lossless/Lossy imports). **VRAM KB** = GPU memory for VRAM-compressed or Basis imports (≈ 1 byte/px + mips).
**pack KB** = imported bytes the export ships.

### `default` (placeholder boxes, look & feel)

| slot | tris / budget | draw calls | textures | pack KB |
|---|---:|---:|---|---:|
| `tank.hull` | 36 / 8000 | 3 | — | 1 |
| `tank.turret` | 12 / 4000 | 1 | — | 1 |
| `weapon.cannon` | 768 / 2000 | 1 | — | 1 |
| `weapon.flamethrower` | 768 / 2000 | 1 | — | 1 |
| **`fx.shell`** | **3456 / 200** | 1 | — | 0 |
| `prop.crate` / `prop.wall` | 12 each | 1 | — | 0 |
| `arena.dressing` | 50 / 50000 | 5 | — | 1 |

**Finding:** the default `fx.shell` is a `CapsuleMesh` with default segments, **3,456 triangles, 17× its budget**.
Shells are the most numerous object in a firefight, so this goes to look & feel (L0 is replacing it with
MultiMesh tracers anyway). A `radial_segments = 6, rings = 1` capsule would be about 60 triangles.

### `kitbash` (CC0 Quaternius models, A3)

| slot | tris / budget | draw calls | textures | RGBA8 KB | VRAM KB | pack KB |
|---|---:|---:|---|---:|---:|---:|
| `tank.hull` | 5974 / 8000 | 4 | — | 0 | 0 | 115 |
| `tank.turret` | 392 / 4000 | 2 | — | 0 | 0 | 11 |
| `weapon.cannon` | 178 / 2000 | 1 | — | 0 | 0 | 6 |
| `prop.crate` | 920 / 2000 | 2 | — | 0 | 0 | 24 |
| `prop.wall` | 2656 / 3000 | 2 | — | 0 | 0 | 48 |
| `kit.light_pole` | 324 / 800 | 2 | — | 0 | 0 | 12 |
| `kit.billboard` | 516 / 1000 | 3 | 1000² | 5208 | 1302 | 247 |
| **total** | 10960 | 16 | | 5208 | 1302 | 463 |

### `neon_kit` (procedural, A4)

| slot | tris / budget | draw calls | textures | RGBA8 KB | VRAM KB | pack KB |
|---|---:|---:|---|---:|---:|---:|
| `prop.crate` | 324 / 2000 | 4 | 128², 128² | 171 | 43 | 14 |
| `prop.wall` | 268 / 3000 | 4 | 128², 256×96 | 213 | 53 | 15 |
| `kit.container` | 360 / 1500 | 4 | 128², 128² | 171 | 43 | 13 |
| `kit.barrier` | 56 / 800 | 3 | 128² | 85 | 21 | 7 |
| `kit.light_pole` | 192 / 800 | 5 | 128², 128² | 171 | 43 | 12 |
| `kit.billboard` | 62 / 1000 | 3 | 128², 256×96 | 213 | 53 | 12 |
| `kit.scrap_pile` | 360 / 1500 | 3 | 128², 128² | 171 | 43 | 18 |
| **total** | 1622 | 26 | | 1195 | 299 | 91 |

### What a match costs (today's arena: 11 crates, 8 walls, from `game/arena/arena.tscn`; 10 tanks)

| theme | prop tris | prop draw calls | tank tris (10×) | tank draw calls (10×) |
|---|---:|---:|---:|---:|
| default | 228 | 19 | 8,160 | 50 (+ shells) |
| kitbash | 31,368 | 38 | 65,440 | 70 |
| neon_kit props + kitbash tanks | 5,708 | 76 | 65,440 | 70 |

Guideline to verify with `fx-bench` and a phone, not a measurement: a mid-range phone on WebGL 2 holds 60 fps
at around **100–150k visible triangles and 150–250 draw calls** with cheap materials. Both themes fit, but
**draw calls, not triangles, are the first limit.** The neon kit is triangle-cheap and draw-call-heavy
(3–5 materials per prop), so the next pipeline step is a **palette atlas**: bake flat-colored, non-emissive materials
into one small palette texture per model, keeping only the named `paint*` / `neon*` materials separate. That
takes a prop to 2 draw calls. Identical props can also be drawn as a MultiMesh; the arena places them, so that's gameplay/look & feel's call.

## Mesh LOD on the Compatibility renderer (measured)

Godot's glTF importer generates LODs for every generated model (`meshes/generate_lods=true` in the `.import`), and
**the Compatibility renderer uses them.** Primitives drawn for one kitbash tank hull (5,974 tris), 1280×720, by camera
distance and the viewport's `mesh_lod_threshold` (`make`-less probe: `res://assets/pipeline/lod_probe.tscn`):

| distance → | 4 m | 15 m | 30 m | 60 m | 120 m | 240 m |
|---|---:|---:|---:|---:|---:|---:|
| threshold 1.0 (default) | 5,974 | 5,974 | 5,974 | 5,974 | 4,102 | 3,862 |
| threshold 4.0 | 5,974 | 5,974 | 4,102 | 3,862 | 3,230 | 3,230 |
| threshold 16.0 | 5,974 | 3,862 | 3,230 | 3,230 | 3,230 | 3,230 |

At RTS distances (30–60 m) the default threshold draws full detail. **`mesh_lod_threshold` is a free quality-tier knob**
for look & feel's L6 (`FxQuality`): about 4 on low/phones cuts tank triangles by roughly 35% at play distance, with no
new art. LODs never reduce draw calls. Hand-made LODs aren't needed while the importer's are this good.

## The web `.pck`: what it holds

`build/web/index.pck`, measured with `tools/assets/pck_report.py` (exact, from the pack directory):

| state | pck on disk | notes |
|---|---:|---|
| as found (all streams' `build/screenshots/*.png` get imported) | **1,944 KB** | ~880 KB of it was my gallery screenshots, which Godot imports and exports because `build/` has no `.gdignore` |
| with `build/.gdignore` | **1,062 KB** | `game/theme/kitbash` 551 KB (53%), `game/theme/neon_kit` 237 KB (23%), `game/` code 110 KB, `.godot/` 73 KB, `assets/` scripts 58 KB |
| + texture policy (below) | ≈ 900 KB (estimate from pack KB: kitbash 463, neon_kit 91) | |
| without the unused test themes | ≈ 350 KB | nothing loads `kitbash`/`neon_kit` at runtime yet; `export_filter="all_resources"` ships them anyway |

The kitbash tank hull GLB is 657 KB on disk but **115 KB imported**, because Godot compresses vertex attributes on import.
Commit optimized GLBs and check the imported size, not the GLB size.

## Texture compression: measured (Godot 4.7.2, Compatibility)

A 1024² noisy map (the shape of a Meshy texture after downscaling), the kitbash 1000² sign atlas, and a 128²
grime map, each imported in every mode (`.godot/imported` file size = what the pack ships):

| mode (`compress/mode`) | 1024² noise | 1000² sign | 128² grime | GPU memory at 1024² | works on |
|---|---:|---:|---:|---:|---|
| 0 Lossless (PNG/WebP lossless) | 2,035 KB | 315 KB | 20 KB | 5.5 MB (RGBA8) | everything |
| 1 Lossy (WebP) | 428 KB | 110 KB | 2.7 KB | 5.5 MB (RGBA8) | everything |
| 2 VRAM Compressed | 683 KB **per format** | 652 KB per format | 10.7 KB per format | 0.7–1.4 MB | only GPUs with that format (S3TC desktop, ETC2/ASTC mobile); export needs both formats for web+phones = 2× size |
| 4 Basis Universal | 1,249 KB | 233 KB | 19 KB | 0.7–1.4 MB (transcoded at load) | one file for all; transcode costs CPU at load |

**Policy (implemented in the pipeline, enforced by `make assets-check`):**
- **≤ 256 px → Lossy.** Pack size is tiny, and uncompressed GPU memory is still under 100 KB per map.
- **> 256 px → Basis Universal.** One file serves desktop browsers (S3TC) and phones (ETC2/ASTC) at a quarter of
  the GPU memory, with no second format in the export. *Pending verification on a real phone browser* (SwiftShader
  can't prove this): check that a Basis texture renders and loads in reasonable time.
- The pipeline caps textures at 1024 and sets `detect_3d/compress_to=0`, so an editor session can't silently switch modes.

`make assets-textures THEME=…` applies the policy (the normalize and procedural targets run it automatically).

## Proposed shared edits (for the morning integration; not made overnight)

1. **`mk/core.mk`, `import` target:** `mkdir -p build && touch build/.gdignore`. Every stream's screenshots currently
   bloat the web pack (measured: 880 KB from one stream's gallery shots). My `assets-*` screenshot targets already
   do this, but only for the checkout they run in.
2. **`export_presets.cfg`, both presets:** add `assets/pipeline/*, game/theme/kitbash/*` to `exclude_filter` until a
   theme uses them (≈ 520 KB of web download). Keep `assets/runtime/*`, which generated wrappers need. Look & feel decides whether
   `neon_kit` pieces graduate into `game/theme/cyberpunk`; exclude `game/theme/neon_kit/*` too if they don't.
3. **`project.godot`:** `rendering/textures/vram_compression/import_etc2_astc=true` once Android export starts (lets
   VRAM-compressed UI or effect textures carry a mobile format). The web preset's
   `vram_texture_compression/for_mobile` stays off as long as model textures use Basis.
4. **`game/theme/default/fx_shell.tscn`** (look & feel): cut the capsule's segments (3,456 → ~60 tris).
