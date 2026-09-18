# FX Tricks: spectacular lighting on a phone budget

> Written 2026-09-14 for the look & feel stream. The lead: *"part of the thing for the visual
> effects and lighting is that we need to figure out the 'tricks' to still render cool effects
> but do so in an efficient manner."*
>
> **Status of every claim below:** marked **[verified]** if it was checked against this repo or
> Godot 4.7.2 itself, and **[verify]** if it's standard real-time technique whose support or cost
> on *our* renderer still has to be proven in the FX lab (L0 in look_and_feel.md). Turn **[verify]**
> into measured facts; don't build on it blindly.

## M1: the frame budget every stream designs to (round 5, render X1, 2026-09-17)

> **This is contract M1 (CP1).** Owner: render. The target is the lead's: **60 fps with 30 a side on the lead's laptop**
> (this machine: Intel UHD 620, Mesa, Compatibility renderer). Measure with `make perf-scene` (below), on this laptop,
> before and after anything that adds per-frame work. Builder0's Iris Xe is ~2.3× faster on the GPU: don't budget
> from it.

### Two facts every stream should quote numbers against (measured 2026-09-17)

1. **The lead's laptop is ~2.75× slower than builder0** for an identical headless workload (`make sim-profile TIME=60`,
   58 vehicles: **18.42 ms a tick on the laptop, 6.68 ms on builder0**). A number measured on builder0 is not a number
   about the game he plays. In game on the laptop the same tick is ~32 ms, because the Compatibility renderer shares the
   main thread.
2. **Brains are 85% of a simulation tick** (`PROFILE_FLAGS=--no-brains`: 2.69 ms of 18.42) and think on a wall-clock
   schedule, so their cost per second does not change with the tick rate. Halving the tick rate could only ever save the
   other 15%: ~13% per second, which is what 30 Hz delivered.

### How it's measured: `make perf-scene`

A **live skirmish**, not a staged bench: `--skirmish --player=cpu --enemy=cpu --seed=3 --budget=6500 --cinematic`
(34 a side at the start), every brain, the HUD, the arena and the whole theme, with vsync off. `PerfScene`
(`game/theme/fx/bench/perf_scene.gd`) holds its own camera at the default play zoom (0.42) over the middle of every
living vehicle, waits 8 s, then alternates 2.5 s phases `all, no_<layer>, all, …` twice. A layer's cost is the mean of
the `all` phases either side minus the layer's phase (cancels the battle's drift). Per phase: frame avg/p95, **GPU ms**
(median), CPU render ms, **`tick_script_ms`** (every `_physics_process` in one tick: simulation + brains),
**`ticks_per_frame`**, `process_game_ui_ms` / `process_fx_ms` (probes around `FxWorld` in the process order), draw
calls, primitives, pooled lights, real lights. Output: `build/perf-scene.json`, `PERF_SCENE` lines, a screenshot, and
counts of the instance-uniform errors. Knobs: `PERF_RES=1920x1080`, `PERF_FLAGS=--fx-quality=low`, `PERF_LAYERS=`,
`PERF_CYCLES`, `PERF_NAME`. It opens a window for ~2 minutes.

### Before (2026-09-17, main at round 5 start, tier high)

Laptop shared with five other agents (load ≈ 5), so CPU numbers are pessimistic; GPU numbers are the GPU's.

| Vehicles alive | Frame avg | GPU (720p / 1080p) | Sim tick (script) | Ticks per frame | CPU render | Process: game+UI / FX | Draw calls | Primitives |
|---|---|---|---|---|---|---|---|---|
| 65 → 46 | **133 ms (7.5 fps, pinned)** | 18–19 / 29–31 ms | **17–23 ms** | 9 (the cap: the sim falls behind) | 2.1–2.5 | 2.3–3.5 / 1.3–1.5 | 810–930 | 0.97–1.02 M |
| 30 → 19 | 42–85 ms | 16–19 / 28–31 ms | 9–15 ms | 3–6 | 2.2–2.6 | 2.3–2.8 / 1.2–1.5 | 560–680 | 0.71–0.88 M |
| 12 → 10 | 21–34 ms | 15–17 ms | 4–7.5 ms | 2.3–2.8 | 1.8–2.3 | 2.9–3.1 / 1.4–1.8 | 450–500 | 0.65–0.69 M |

Layer costs (GPU ms at 720p / 1080p; draw calls): **arena floor + props 7.1 / 11.8** (35 draws); **moon shadows 4.4 /
5.5** (155 draws, halves the primitives); effects 2.1 / 4.3; pooled lights (16) 1.7 / 2.8; glow 1.3 / 3.2; vehicles
1.1 / 2.1 (60–155 draws); underglow ~0.4; **HUD 0.5 / 0.9 GPU but 200–310 draw calls and ~1 ms CPU render**. 246
`Too many instances using shader instance variables` errors and 93 `instance_buffer_pos` errors per run.

**What this says:**
1. **The simulation tick is the wall.** At 60+ vehicles one tick's scripts take ~20 ms on this laptop. A 60 Hz sim that
   needs more than a frame per tick runs several ticks every frame (Godot caps it at 8), each frame gets longer, and
   the game pins at 133 ms. Nothing in rendering can fix that; rendering only decides how early the spiral starts.
2. **The spiral makes every cost non-linear.** Once a frame exceeds 16.7 ms, it pays for 2+ ticks. So the budget below
   keeps ~10% headroom: a frame that averages 16 ms but spikes to 20 ms still spirals.
3. **On the GPU the floor and the shadows are most of the frame**, not the lights or the vehicles.
4. **The HUD is a third of the draw calls.**

### After render X2–X5 (2026-09-17, same scene, tier high)

| Vehicles alive | GPU 720p / 1854×1011 | Primitives | Real lights | Draw calls (HUD) | Engine errors per run |
|---|---|---|---|---|---|
| 61 → 46 | **8.5–9.6 / 12–13 ms** (was 18–19 / 29–31) | **0.19–0.28 M** (was 0.97–1.1 M) | **5** (was 17) | 640–710 (HUD 210–220) | **0** (was 246 + 93) |

What bought it (GPU ms measured as layer deltas in the same fight; each item's commit has its run):

| Change | Saved |
|---|---|
| X2: no instance uniforms on vehicles (shared materials per team/paint/heat step; own material per shield) | the 246 + 93 errors; vehicles now draw correctly |
| X3: moon shadows off on every tier, blob shadows under vehicles (one MultiMesh) | 4.4–5.5 ms, ~155 draws, half the primitives |
| X3: MSAA off | 2.5 ms |
| X3: 4 pooled lights (2 on low) for explosions, shells, beams and muzzles only (`light_floor`); no vehicle lights | 17 → 5 real lights; ~1 ms, and the floor stops paying light passes (arena layer 7 → 2.5 ms) |
| X5: 3D render scale follows the window (≤ ~918 lines, ≥ 0.7; `FxQuality.render_scale_for`) | 4.8 ms at 1920×1080 |
| X5: glow on its wide levels only (3 and 5) | 2.1 ms at 1080p |
| X5: spark/debris loop 14 → 6 per spray | 1.4 ms |
| X5: mesh LOD threshold 1 → 4 px | ~0.6 ms, primitives 374k → 237k |
| X5: floor lit in its own shader (flat, no dynamic shadows) | 0.6 ms |
| Floor tiles subdivided (per-vertex fog), additive spill/signs `fog_disabled` | no cost; removed square artifacts |

**Where the GPU still goes** (720p / 1080p): arena (floor, walls, venue, props) 1.9 / 2.8, glow 1.6 / 1.9, pooled
lights 0.3–1.8 (noisy), effects 0.2 / 1.5, vehicles 0.4, HUD 0.2–0.35, and a base of ~3 ms (clear, post, tonemap, UI
composite). **The frame is still 50–133 ms because the simulation tick is 20–24 ms at 60 vehicles**: that line of
the budget is combat's and ai's, and nothing in rendering moves it.

### The budget (UHD 620, 60 vehicles in a fight, default desktop tier)

| Line | Budget | Before | Owner |
|---|---|---|---|
| **Whole frame** | **≤ 15 ms average, p95 ≤ 16.7 ms** (60 fps with headroom; `ticks_per_frame` ≈ 1.0) | 133 ms | everyone |
| **Simulation tick** (all `_physics_process`: Match, combat, brains, elements, orders, visibility) | **≤ 5 ms** at 60 vehicles (`tick_script_ms`); brains inside that keep ai's 4 ms | 17–23 ms | combat + ai (control's order execution inside it) |
| **GPU** | **≤ 6.5 ms at 1280×720, ≤ 10 ms at 1920×1080** | 18 / 30 ms | render (arena props must stay inside render's numbers: see below) |
| CPU render (draw submission) | ≤ 1.5 ms | 2.1–2.6 ms | render + control |
| **Draw calls** | **≤ 350 total: 3D ≤ 220, HUD/UI ≤ 130** | 810–930 (HUD 200–310) | render (3D), control (HUD) |
| Primitives drawn (all passes) | ≤ 450 k | 0.7–1.0 M | render |
| `_process` scripts: game + UI | ≤ 1.5 ms | 2.3–3.5 ms | control (UI), audio (booth, music, crowd), combat/ai (anything in `_process`) |
| `_process` scripts: effects (`FxWorld`) | ≤ 1.0 ms | 1.2–1.8 ms | render |
| **Real lights alive at once** | **≤ 6: the moon (no shadow) + ≤ 4 pooled omni lights** for the moments that matter (explosions, a tank shell, a kill); **no per-vehicle lights**; no omni shadows ever | 17 (moon with shadow + 16 pooled, most of them on vehicles as underglow) | render |
| Dynamic shadows | **off on the default desktop tier** (fake with blob shadows); high tier only when the GPU line holds with them | moon shadows on | render |
| Instance uniforms (`instance uniform` in a shader) | **none on anything that scales with unit count** (each instance reserves 16 of the 4,096 buffer slots: 256 instances total) | vehicles, weapons and shields used them | render |

**Rules for every stream:**
- **Arena (props):** static props go through `StaticBatcher`/MultiMesh (one draw per prop kind and material, not per
  prop); a new prop kind costs ≤ 2 draws; **no real lights and no per-prop `_process`**; props cast no dynamic shadows
  on the default tier. Tell render when a layout adds a kind.
- **Control (HUD):** the HUD and tactical overlays together ≤ 130 draw calls and ≤ 1 ms of `_process` at 60 vehicles:
  panels that don't change don't redraw; per-unit widgets (cards, markers, rings) are pooled or batched, not one node
  tree per unit per frame. 3D selection marks count against render's 3D line, so keep them one MultiMesh.
- **Combat and ai (simulation):** the whole tick ≤ 5 ms at 60 vehicles on this laptop, checked with `make perf-scene`
  (`tick_script_ms`) as well as `make ai-perf`; nothing per tick that scales with units² without a spatial index or a
  staggered schedule.
- **Audio:** booth, music director and crowd scripts ≤ 0.3 ms per frame together; players are pooled.
- **Everyone:** a feature that adds per-frame work runs `make perf-scene` before and after and puts both numbers in its
  commit or Status. Over budget = not done.

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
| A MultiMesh written from `_process` warns on every write once physics interpolation is on (30 Hz), and switching it off takes **two** calls: `physics_interpolation_mode = OFF` on the MultiMeshInstance3D (the node re-pushes its state to the server when it enters the tree, undoing a server flag set in `_init`) **and** the server flag re-asserted after every `instance_count` change (a resize rebuilds the buffers and clears it). Use `FxMultiMesh` | `game/theme/fx/fx_multimesh.gd` **[verified: 0 warnings in a playtest, was 1]** |

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

> **Superseded for the full game by M1 above (round 5):** these were effects-only budgets on a staged bench.

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

## Round 3 (feel X7, 2026-09-15): 50 vehicles with round 3's weapons

**How:** `make remote T="fx-bench FX_CONFIGS=r3_all,r3_no_weapons,r3_no_motion,r3_tier_medium,r3_tier_low,all,tier_low
FX_SECONDS=8"` on **builder0 (Intel Iris Xe, Mesa 26, 1280×720, vsync off)**, a faster GPU than round 1–2's reference
UHD 620 (round 2's `all` was 14.2 ms there, 6.24 ms here: about 2.3× faster), so compare configs within this run and
scale by ~2.3 for the laptop. `Round3Firefight`: 25 v 25 (per side 5 tanks firing shells every 5 s, 8 IFVs in 4-round
bursts, 8 scouts streaming 16 rounds a burst, 2 artillery, 2 Lancers), 30% misses, 12% weak spots, kills that burn,
every vehicle moving (scouts circle and drift), an order marker every 1.5 s. Effects go through `WeaponFx` exactly as
K2 events would. Raw numbers: `build/fx-bench.json`; screenshots: `build/screenshots/fx/fx_r3_*.png`.

| Config | Frame avg / p95 ms | GPU ms (median) | CPU render ms | Draw calls | Tracers in flight |
|---|---|---|---|---|---|
| `r3_all` (tier high) | **6.88 / 7.14** | 5.85 | 1.07 | **273** | 52 |
| `r3_no_weapons` (vehicles moving, no fire) | 6.27 / 6.67 | 5.36 | 0.92 | 268 | 0 |
| `r3_no_motion` (fire, no dust/marks/lurch) | 6.82 / 7.14 | 5.82 | 1.02 | 272 | 51 |
| `r3_tier_medium` | 4.59 / 5.18 (one 17.8 ms frame) | 2.74 | 0.88 | 140 | 50 |
| `r3_tier_low` | **4.35 / 5.00** | 2.18 | 0.80 | **140** | 51 |
| `all` (round 2's 20-tank bench, same run) | 6.24 / 6.67 | 5.21 | 1.03 | 238 | 19 |
| `tier_low` (round 2's bench) | 2.96 / 3.33 | 1.72 | 0.99 | 148 | 19 |

- **Round 3's weapon effects cost +0.6 ms** at tier high for 50 vehicles fighting (`r3_all` − `r3_no_weapons`): shell
  blasts, bursts, streams, crits, kills, burning wrecks, order markers. **Motion effects cost ~0.06 ms** (dust in its own
  pool, drift marks one MultiMesh). New draw calls: +5 (weapon pools, decals, dust, skids, order markers, trail).
- **Budgets hold:** high 6.9 ms / 273 draws (≈ 16 ms on a UHD 620, at the edge of its 16 ms budget: the 50 vehicles'
  886k primitives are the big cost, not effects); low 4.4 ms / 140 draws (≈ 10 ms on a UHD 620, under 12 ms).
- **Rules that kept it cheap:** everything is an instance in an existing MultiMesh (virtual hitscan rounds share the
  tracer buffer); machine guns are held sound loops for the 4 nearest gunners, not a sound per round; small-round
  sparks are rate-limited per target (0.07 s) and ricochet sounds globally (0.15 s); dust and marks only for the
  vehicles nearest the camera (6/12/20 by tier); scorches, dust, and marks have their own pools so a firefight never
  recycles them.
- **Heat haze** (stretch, `HeatHaze`: ≤ 8 camera-facing quads over the nearest fires reading the screen texture, tier
  high only): `r3_all` vs `r3_no_haze`, two passes each: 7.12 / 7.08 ms vs 6.96 / 7.13 ms, the same 273 draws: **within
  noise** on the Iris Xe. Not measured on web or phones (it's off on low and medium).
