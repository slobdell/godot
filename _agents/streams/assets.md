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

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. **Constraints tonight:** no API keys or accounts for any 3D service, no discrete GPU (so no local generation models), ~9 GB disk shared by five agents (**≤ 500 MB of downloads**). The pipeline and everything around it can still be built and proven.

1. **A0 service research** (`_agents/streams/references/asset_services.md`): Meshy, Tripo, Rodin/Hyper3D, Luma, CSM, and others you find, plus open models (TRELLIS, Stable Fast 3D, Hunyuan3D) for later GPU use. Cover current pricing, API availability, output formats, polygon/texture control, **license terms for commercial use of outputs**, and quality notes. Cite sources with dates. End with a recommendation.
2. **A1 normalize + check pipeline** (headless Godot tooling in `tools/assets/`): load a GLB (`GLTFDocument`), report bounds/tris/materials/texture sizes, and scale/orient/recentre to the slot contract. Keep **emissive** maps intact. Write `game/theme/<theme>/generated/<slot>.glb` + a wrapper `.tscn` implementing the slot's optional methods (e.g. `set_team_color` by tinting a named material). `make assets-check` enforces the contract table. Tests use synthetic GLBs produced by `GLTFDocument` export from procedural meshes (wrong scale, wrong forward axis, too many tris…).
3. **A2 provider clients, ready for keys:** `make assets-generate PROVIDER=<name> PROMPT=… SLOT=…` reading the key from an environment variable. Implement the recommended provider's API flow, tested against a local mock HTTP server (no network, no key). Document how the lead turns it on.
4. **A3 real models without accounts:** pick CC0 packs (e.g. Kenney, Quaternius, Poly Haven; verify each license on its page and record it in `assets/CREDITS.md`) with vehicle and industrial/sci-fi props. Run a handful through the pipeline into a `kitbash` test theme (tank hull/turret, 2–3 props) and take screenshots in-game. `make sim-baseline` unchanged.
5. **A4 procedural cyberpunk kit** (fallback and filler art): a headless Godot script that builds shipping containers, concrete barriers, light poles, billboards, and scrap piles from primitives with emissive neon strips → GLB via the same pipeline, as candidates for look & feel (who decides what fills slots). Hand them over through the Status notes.
6. **A5 web/mobile budget report:** per-asset triangle and texture-memory numbers, `.pck` size impact of the kitbash theme, and texture compression import settings for web/mobile (a `project.godot` change is a shared edit; propose it in your notes).
- **Stretch:** a cyberpunk **prompt library + style guide** for when keys exist (hero tank, scout, artillery, props), LOD generation, and a pipeline doc for the lead's son (how to bring a model into the game).
