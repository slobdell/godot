# FX Tricks: spectacular lighting on a phone budget

> Written 2026-09-14 for the look & feel stream. The lead: *"part of the thing for the visual
> effects and lighting is that we need to figure out the 'tricks' to still render cool effects
> but do so in an efficient manner."*
>
> **Status of every claim below:** marked **[verified]** if it was checked against this repo or
> Godot 4.7.2 itself, and **[verify]** if it's standard real-time technique whose support or cost
> on *our* renderer still has to be proven in the FX lab (L0 in look_and_feel.md). Turn **[verify]**
> into measured facts; don't build on it blindly.

## The constraints we're designing inside

| Fact | Source |
|---|---|
| Renderer is **Compatibility** (OpenGL 3 / WebGL 2) on desktop, web, and mobile | `project.godot` **[verified]** |
| `rendering/limits/opengl/max_lights_per_object` = **8** by default | Godot 4.7.2 `--doctool` **[verified]** |
| `rendering/limits/opengl/max_renderable_lights` = **32** by default | Godot 4.7.2 `--doctool` **[verified]** |
| **The arena ground is ONE 320×320 `PlaneMesh`**, so at most 8 real lights can ever touch the entire floor at once, and lights anywhere on the map count against it | `game/theme/default/arena_dressing.tscn` **[verified]** |
| `Impact` (the hit fireball) allocates a new `SphereMesh` + `StandardMaterial3D` per hit, alpha-blended, freed afterwards: the "instantiate per event" pattern that causes hitches at scale | `game/combat/impact.gd`, `Match.show_impact` **[verified]** |
| `make web-smoke` renders with **SwiftShader** (software GL), so its frame times say nothing about real GPUs; it's only for "boots and looks right" | `tools/web_smoke/smoke.mjs` launch args **[verified]** |
| Visuals must never touch the simulation (`make sim-baseline`), and slots must load on a headless server | workstreams.md **[verified]** |

**What actually costs frames on phones and WebGL** (in rough order): draw calls and state
changes (each unique material/mesh), **overdraw** (layers of transparent/additive pixels covering
the screen), per-pixel light work, shader compiles at first use (a visible hitch), and GDScript
running per effect per frame. Triangle counts matter much less than those.

## The principles (the "tricks" behind all the tricks)

1. **Fake light; don't compute it.** In a dark scene, anything emissive + bloom *reads* as light.
   Reserve real lights for the few moments that must light other objects.
2. **Pool everything; allocate nothing in combat.** Preallocate tracers, flashes, beams, and lights
   at load; recycle them. No `new()`/`instantiate()`/`queue_free()` per shot.
3. **Batch.** Many copies of an effect = one `MultiMeshInstance3D` with one material, with
   per-instance color/data via `INSTANCE_CUSTOM`. Share materials; never give every object a
   unique `StandardMaterial3D` just to change a color. Use `instance uniform`s **[verified: work in Compatibility]** or MultiMesh custom data.
4. **Animate in shaders, not scripts.** Flicker, breathing neon, scrolling beams, heat shimmer,
   and fades driven by `TIME` or a start-time uniform cost nothing per frame in GDScript.
5. **Bake what doesn't move.** Light pools under lamps and neon glow on the floor can be painted
   into textures or vertex colors, or baked (LightmapGI: not tested), instead of lit live.
6. **Small on screen, few layers.** Additive sprites are cheap *per pixel* but overdraw stacks: prefer
   thin, bright, short-lived effects over big soft fullscreen ones.
7. **Pre-warm shaders.** Spawn every effect once off-camera during loading so the first shot doesn't hitch. This matters most on the web.
8. **Quality tiers from day one.** One `FxQuality` setting (low/med/high) scales light-pool size,
   splat counts, particle counts, glow, and 3D render scale. Phones start low and step up if frame time allows.

## The catalog: effect → trick

### Light that follows a projectile (the lead's favorite)
- **Tracer:** a single stretched quad or thin capsule, unshaded, HDR emissive color (>1 so glow
  catches it), soft gradient in the shader. All tracers go in one MultiMesh.
- **Ground light splat:** an additive, unshaded quad lying on the ground under each tracer with a
  radial-gradient falloff in the tracer color. It moves with the projectile, so *the floor visibly
  lights up along the path* for almost no cost (one MultiMesh, tiny pixels). Fade the splat by the
  projectile's height. This is the core trick.
- **Real light only for the best candidates:** a **LightPool** of N `OmniLight3D`s (no shadows, short
  range, fast falloff) assigned each frame by priority (explosion > laser impact > muzzle flash >
  tracer nearest the camera), so walls and tanks catch *some* real light. N on phones ≈ 4–8. Measure.
- **Chunk the ground** (e.g. 40×40 m tiles) or the 8-lights-per-object cap makes the pool useless
  on the floor. This also helps culling.
- **Custom light field (advanced):** pack up to ~16–32 light positions/colors into a small float
  data texture (not tested) or shader uniform arrays (not tested),
  and add their falloff in the ground and prop shaders: one draw and one loop per pixel instead of
  engine light passes. Only if the splats + pool aren't enough.

### Lasers
- A camera-facing quad stretched between muzzle and hit point (billboarded around its axis):
  a white-hot core + colored falloff + scrolling noise in the shader, additive.
- Hit sprite + splat at the impact point, and a pooled light at the impact (or beam midpoint) for the brightest beams only.
- Fade-out via shader uniform rather than script.

### Muzzle flash, hits, explosions
- **Muzzle flash:** 2–3 crossed quads with random rotation, 2–3 frames long, plus a pooled light with a ~0.08 s decay.
- **Explosions:** **flipbook sprite sheets** (pre-rendered animated fireball/smoke frames on a
  billboard) look far richer than a runtime particle sim and cost one quad. Add a few sparks
  (`GPUParticles3D` **[verified natively; browser pending]** or `CPUParticles3D`) and a pooled light pulse.
- **Replace `Impact`'s per-hit allocation** with a pooled, shared-material flipbook.
- **Camera shake** on big hits is free and adds weight. It's visual-only; never slow the simulation for "hit-stop".

### Neon arena and glowing obstacles
- **Emissive textures** (neon strips, signage, hazard lights) on props, with glow. No lights needed.
- Flicker, buzz, and breathing in the shader via `TIME` (per-prop phase offset from world position, so there's no script).
- **Holograms / ads:** additive unshaded quads with scanline + noise shader.
- **Fake light pools:** painted gradient decals/quads on the ground under each neon source (static,
  so batch them or bake them into the ground texture). `Decal` nodes **[verified: render nothing in Compatibility]**; use additive quads (MultiMesh).

### Blade Runner wet ground (reflections without SSR)
- SSR isn't available in Compatibility. Fake it: under each bright neon source, draw **vertical
  light streaks** on the ground (stretched, blurred, additive quads toward the camera), which is how
  wet asphalt reads. A dark, glossy-looking ground texture helps. `ReflectionProbe` **[verified: no useful reflection in Compatibility]**.

### Atmosphere
- **Depth fog + height fog** from `Environment` (cheap); no volumetric fog in Compatibility.
- **Fake volumetric beams** (floodlights, searchlights): additive cone meshes with soft edges (fresnel) and slow noise scroll.
- **Glow/bloom:** `Environment` glow **[verified: works, +1.1 ms at 720p]**, with a
  threshold so only HDR emissive (>1) blooms; lower quality on phones.
- One directional light (moon/floodlight) at most with shadows; **blob shadows** (a soft dark quad) under vehicles instead of dynamic shadows on phones.

### Heat, shields, damage state
- **Heat:** `instance uniform float heat` **[verified: works]** (or MultiMesh custom data) driving barrel/vent emission and a subtle heat-shimmer sprite, with no unique materials.
- **Shield:** a slightly larger hull "shell" mesh with a fresnel rim + hex/noise shader, invisible
  normally; on a hit, show it briefly with a ripple from the hit point (uniform). Show a "shield down" crackle and a recharge sweep.
- **Damage:** smoke flipbooks and sparking emissive flicker at low hull health.

### Whole-frame levers
- **3D render scale** (`scaling_3d_scale`) ~0.7 on phones while the UI stays crisp **[verified: 0.7 saves 4.3 ms]**.
- MSAA 2× vs none as a quality-tier setting.
- Skip effects off screen (`VisibleOnScreenNotifier3D`) and use visibility ranges for far detail.

## How to prove it: the FX lab (L0)

1. **`make fx-bench`**: a deterministic worst-case scene that runs a fixed camera path for N
   seconds, e.g. 10v10 all firing, M tracers, K lasers, explosions, and the full neon prop set.
   It prints `FX_BENCH` lines: average / p95 / p99 frame time, draw calls and objects
   (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`), and per-trick
   toggles (so each trick's cost is its on/off delta). GPU timing via
   `RenderingServer.viewport_set_measure_render_time` **[verified: works; use medians]**. Otherwise, use frame time with vsync off.
2. **An on-screen perf overlay** (`--fx-bench` also shows fps / frame ms / draw calls in a corner) so a phone test needs no console.
3. **Where to measure:** native desktop (fast iteration), a **real browser with GPU** (not the SwiftShader smoke test), and **the lead's phone**:
   `make export-web && make serve-web WEB_HOST=0.0.0.0`, then open `http://<this machine's LAN IP>:8060/?fx-bench` on the phone. The phone test is a checkpoint to hand to the lead (a question at the end of a milestone, not a blocker mid-way).
4. **Record results here:** for each trick, whether it's supported (yes/no in 4.7.2 Compatibility),
   its cost in ms at the worst case (desktop, browser, and phone if measured), a screenshot, and a verdict
   (use / tier-gated / rejected). The **[verify]** tags above become facts.
5. **Set the budget from the data**, e.g. "phone low tier: ≤ 12 ms frame at the worst case, ≤ N draw calls, light pool = 4", and put it in look_and_feel.md so all later FX work designs to it.

## Results (L0, measured 2026-09-14)

**How:** `make fx-bench` (18 configs at L0, 21 since L6, × 6 s each, same seeded timeline: 10 v 10 tanks firing every
0.7 s, ~23 tracers in flight, explosions on every hit, orbiting camera at gameplay heights, the
cyberpunk arena). Native desktop, **Intel UHD 620 (Mesa, laptop iGPU, no discrete GPU)**,
1280×720, vsync off, while four other agents shared the CPU. Raw numbers: `build/fx-bench.json`;
screenshots: `build/screenshots/fx/fx_<config>.png`. A trick's cost = its config minus `all`
(tier-high budgets: 16 pooled lights, glow, MSAA 2×, moon shadows, chunked ground, merged props).
Support checks for features the bench doesn't use: `game/theme/fx/bench/fx_probe.gd` → `probe.png`.
Frame times on this GPU are GPU-bound (median GPU time ≈ frame time − 0.7 ms), so a GPU delta is the
honest cost. **Browser (real GPU) and phone: pending the lead's phone run** (`?fx-bench`).

| Config | Frame avg / p95 ms | GPU ms (median) | CPU render ms | Draw calls |
|---|---|---|---|---|
| `arena_only` (no firing) | 13.70 / 14.97 | 13.03 | 1.68 | 381 |
| **`all`** (tier high) | **15.11 / 16.67** | **14.39** | **1.98** | **384** |
| `lights_0` / `lights_4` / `lights_8` / `lights_32` | 14.17 / 14.74 / 14.87 / 16.30 | 13.49 / 14.01 / 14.14 / 15.41 | ~2.0 | 384 |
| `no_splats` | 15.39 | 14.62 | 2.10 | 383 |
| `no_glow` | 14.08 | 13.29 | 2.03 | 384 |
| `single_ground` (one 320 m plane, 16 lights) | 16.95 | 15.99 | 1.87 | 361 |
| `msaa_off` | 13.82 | 13.14 | 2.23 | 384 |
| `scale_0.7` (3D render scale) | 10.80 | 10.10 | 2.28 | 384 |
| `no_shadows` (moon DirectionalLight shadow off) | 10.20 | 9.53 | 1.36 | **191** |
| `no_muzzle_flash` | 15.77 | 14.92 | 2.18 | 384 |
| `unmerged_props` (every box its own mesh) | 16.19 | 15.50 | **3.55** | **564** |
| `naive` (per-shell mesh + material + OmniLight3D; per-hit sphere + material) | 17.42 / p99 19.4, max 33.5 | 16.23 | 2.82 | 447, 275k prims |
| `tier_low` / `tier_medium` / `tier_high` | **5.47** / 7.97 / 16.00 | 4.8 / 7.29 / 15.24 | 1.71 / 1.54 / 2.44 | 190 / 190 / 384 |

| Trick | Supported (4.7.2 Compat) | Cost desktop (UHD 620) / browser / phone | Verdict |
|---|---|---|---|
| **LightPool** (N pooled OmniLight3D, priority + distance) | yes | 16 lights **+0.9 ms** GPU over 0; 4 → +0.5; 8 → +0.65; 32 → +1.9. Draw calls don't change (light passes aren't counted as draws). Pool of 20 requests → only N nodes ever exist. / pending / pending | **use**; tiers: low 4, medium 8, high 16 |
| **MultiMesh tracers** (one draw for all shells, axis-billboard shader) | yes | tracers + splats + bursts together ≈ `all` − `arena_only` = **+1.4 ms** for ~23 tracers, 16 lights, explosions; 3 draws total / pending / pending | **use** |
| **Ground light splats** (additive MultiMesh under each tracer) | yes | **≈0** (within noise: `no_splats` was 0.2 ms *slower*) / pending / pending | **use** on every tier; this is the core "light along the path" trick |
| **Flipbook explosions in a pooled ring-buffer MultiMesh** (shader-animated from a start time in `INSTANCE_CUSTOM`) | yes: float custom data survives, animation is smooth | part of the +1.4 ms above; zero allocation per hit (was SphereMesh + material per hit) / pending / pending | **use**; replaced `Impact` |
| Naive per-shell light + mesh (the "before") | yes, but | **+1.8 ms GPU, +0.8 ms CPU, 275k primitives, p99 19.4 ms, max 33.5 ms hitches** (allocation + first-use compiles) / pending / pending | **rejected** |
| **Chunked ground** (8×8 tiles of 40 m) | yes | a single plane costs **+1.6 ms GPU** with 16 lights (+1.9 with 8): lights re-draw the whole plane; tiles cost +23 draw calls / pending / pending | **use** |
| **Merged static props** (`StaticBatcher`: one surface per material) | yes | **−180 draw calls, −1.6 ms CPU render**, −0.9 ms GPU / pending / pending | **use** for all static art (the Compatibility renderer does no 3D batching) |
| **Environment glow** (HDR threshold 0.9, additive) | yes: blooms emissive > 1 (tracers, neon, emission on StandardMaterial3D) | **+1.1 ms** / pending / pending | **use**; candidate to drop first on a slow phone |
| Moon **DirectionalLight3D shadows** | yes | **+4.9 ms GPU, doubles draw calls (191 → 384)** / pending / pending | **tier-gated: high only**; the arena reads fine without them (neon is the lighting) |
| **3D render scale** (`scaling_3d_scale`) | yes (bilinear) | 0.7 → **−4.3 ms**; UI stays crisp / pending / pending | **use** on phones (low tier 0.75) |
| MSAA 2× | yes | **+1.3 ms** / pending / pending | tier-gated: high only |
| Muzzle flash (burst star + ground glow + pooled light flash) | yes | within noise (≤ 0.7 ms, `no_muzzle_flash` measured *slower*) / pending / pending | **use** |
| Emissive neon shader with per-object flicker from `NODE_POSITION_WORLD` | yes | in `arena_only`; shared material, no script / pending / pending | **use** |
| Fake volumetric beam cones (additive fresnel) | yes | in `arena_only`, 4 beams / pending / pending | **use**; watch overdraw when the camera is inside a cone |
| Hologram ad shader (additive, scanlines, procedural text blocks) | yes | in `arena_only`, 4 ads / pending / pending | **use** |
| **Shader pre-warm** (every effect + every pooled light drawn invisibly for 3 frames at load) | yes | native first-shot worst frame 28–31 ms without vs 20–27 ms with, but Mesa's on-disk shader cache hides most compiles natively; the web has no such cache / pending / pending | **use** (3 frames at load, free) |
| `instance uniform` (per-instance shader params without unique materials) | **yes** (probe: three cubes, one material, three `heat` values render three colors) | not measured (no per-object cost expected) | **use** for `set_heat` / `set_shield` |
| `Decal` node | **no**: renders nothing in Compatibility (probe) | — | **rejected**; use additive quads / MultiMesh glow pools |
| `GPUParticles3D` | yes natively (probe); browser pending | — | allowed for sparks; CPUParticles3D also works and is the safe web fallback |
| `ReflectionProbe` | no useful result (probe: metal sphere shows no probe reflection) | — | **rejected**; fake wet reflections with low roughness + pooled lights + streaks |
| `viewport_set_measure_render_time` | yes (GPU/CPU ms reported; an occasional garbage sample, so the bench uses medians) | — | used by the bench |
| Float data textures / uniform-array light field; LightmapGI | not tested | — | not needed yet: splats + pool are enough |

### Re-measured after L3–L6 (vehicles, underglow, lasers, shields, streaks in the scene)

Same bench, now with the procedural cyberpunk tanks (2 draws per part), team underglow taking
spare pooled lights, 4 laser tanks pulsing every 0.35 s through `fx.laser_beam` (as `Match.show_beam`
does), shield hits/recharge on every hit, and wet-floor streaks. `build/fx-bench-l6.json`.

| Config | Frame avg ms | GPU ms | CPU render ms | Draw calls |
|---|---|---|---|---|
| `all` (tier high, moon shadows **4 PSSM splits**) | 17.55 | 16.02 | 2.75 | 466 |
| `all` (tier high, moon shadows **orthogonal, 110 m**: shipped) | **14.23** | 13.40 | 2.40 | **401** |
| `no_shadows` | 11.98 | 11.06 | 1.72 | 240 |
| `no_lasers` / `no_shields` | within noise of `all` (±0.7 ms) | | | −4 / −15 |
| `unmerged_props` | 17.60 | 17.18 | **4.52** | **647** |
| `tier_low` / `tier_medium` / `tier_high` | **5.91** / 8.57 / 14.13 | 4.94 / 7.76 / 13.23 | 1.88 / 1.72 / 2.44 | 240 / 240 / 401 |

- **Directional shadow splits are the hidden draw-call multiplier:** PSSM 4 splits re-draws casters per split; orthogonal mode saved 3.3 ms and 65 draws with no visible loss from the gameplay cameras.
- **Pre-warm (extended to shields, flames, beams, vehicle glow):** without it the first laser pulse hitched **56 ms**; with it the worst frame after load was 16.7 ms (`FX_BENCH_HITCH` lines log any frame over 50 ms).
- Lasers and shields cost nothing measurable: beams are one MultiMesh, shields draw only during events.

### Frame budgets per quality tier (set from these numbers)

Worst case = the bench firefight. Native UHD 620 numbers are the reference; a mid-range phone GPU is
roughly this class or slower, so phones start **low**.

| Tier | Default for | Frame budget (worst case) | Draw calls | Pooled lights | Glow | Render scale | MSAA | Shadows | Measured here (L6) |
|---|---|---|---|---|---|---|---|---|---|
| **low** | web, mobile | **≤ 12 ms** (leaves 4 ms of a 16.7 ms frame for game logic) | ≤ 250 | 4 | on (first to cut) | 0.75 | off | off | 5.9 ms, 240 draws |
| **medium** | — | ≤ 12 ms | ≤ 250 | 8 | on | 1.0 | off | off | 8.6 ms, 240 draws |
| **high** | desktop | ≤ 16 ms | ≤ 450 | 16 | on | 1.0 | 2× | moon, orthogonal, 110 m | 14.1 ms, 401 draws |

Tier selection (L6, `FxQuality`): `--fx-quality` flag > the player's saved choice (HUD "FX" button,
`user://fx_quality.cfg`) > platform default. On web/mobile without an explicit choice, `FxAutoQuality`
steps down one tier when 4 s average frame time exceeds 24 ms (10 s cooldown; never up, since
browsers cap frames at the display rate).

Rules for all later FX work: new effects join an existing MultiMesh or pool (no per-event nodes with
meshes/materials/lights), static art goes through `StaticBatcher`, and any new per-frame cost gets a
bench config so its delta is measured.

### Round 2 (art X2/X3, 2026-09-14): the textured floor and the lighting pass

Same bench, while four other worktree agents loaded the machine, so **compare configs within one run only** (absolute
numbers drift by several ms between runs). New configs: `ground_wet` (round 1's procedural wet asphalt), `ground_flat`
(a plain material), `ground_lite` (the low/medium floor on tier high), `tier_low_ground_wet`.

| Floor shader (tier high unless noted) | Δ frame vs `ground_wet` (same run) | Verdict |
|---|---:|---|
| First textured floor: 2 asphalt + concrete + normal + 2 detail + drain + per-pixel hash noise + an 8-lamp loop (12 fetches) | **+6.6 ms** (low tier +3.7) | rejected |
| … hash noise replaced by noise texture channels, lamp loop by a baked 64² light map | no better (+7 ms): fetches, not math, are the cost | — |
| … pooled lights excluded from the floor (cull mask) | within noise: extra light passes weren't the cost either | not kept |
| … minus anisotropic filtering / minus the normal map / minus 4 fetches | −1.0 / −2.0 / −3.2 ms | the cost is texture fetches |
| **Shipped, tier high:** asphalt ×2 (anti-tiling), baked `arena_macro` (weathering, slabs, oil), skid-mark detail, light map, drain fetched only inside drain cells; no normal map | **+1.9 ms** | use (desktop) |
| **Shipped, low/medium (`arena_ground_lite`):** asphalt, macro, light map (3 fetches) | **+0.1 ms** at tier low (6.44 vs 6.33); medium 9.13 | use (web/phones) |

- On this GPU (Intel UHD 620, Compatibility), **per-pixel texture fetches on a full-screen surface dominate**; branch
  away fetches that only matter in small areas (`textureLod` inside `if`), bake static variation into one arena-wide map.
- Painted floodlight pools (a 64² light map baked from the dressing's lamp list, added as emission) light the floor
  for one fetch; the moon (key light) went 0.65 → 1.15 energy and neutral white, ambient less saturated (no measurable cost).
- **The gladiator venue (X5)**, `no_venue` configs: 18 Meshy grandstand modules, 2 gates, 4 generated floodlight towers,
  ~2,000 instanced spectators in **one MultiMesh draw** (alpha scissor, shader-animated idle/cheer, per-tier counts
  900/1,800/4,000): **+0.3 ms at tier high, +0.14 ms at low, +2 draw calls** from the bench's orbit camera.
- Tier budgets hold: low 6.4 ms / 189 draws, medium 9.1 ms / 189 draws; high +1.9 ms over round 1's floor (borderline
  against 16 ms on a loaded machine; switch high to the lite floor if a desktop GPU struggles).
