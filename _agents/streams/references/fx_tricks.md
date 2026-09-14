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
   unique `StandardMaterial3D` just to change a color. Use `instance uniform`s **[verify]** or MultiMesh custom data.
4. **Animate in shaders, not scripts.** Flicker, breathing neon, scrolling beams, heat shimmer,
   and fades driven by `TIME` or a start-time uniform cost nothing per frame in GDScript.
5. **Bake what doesn't move.** Light pools under lamps and neon glow on the floor can be painted
   into textures or vertex colors, or baked **[verify LightmapGI in Compatibility]**, instead of lit live.
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
  data texture **[verify float textures in WebGL2 path]** or shader uniform arrays **[verify]**,
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
  (`GPUParticles3D` **[verify on WebGL2]** or `CPUParticles3D`) and a pooled light pulse.
- **Replace `Impact`'s per-hit allocation** with a pooled, shared-material flipbook.
- **Camera shake** on big hits is free and adds weight. It's visual-only; never slow the simulation for "hit-stop".

### Neon arena and glowing obstacles
- **Emissive textures** (neon strips, signage, hazard lights) on props, with glow. No lights needed.
- Flicker, buzz, and breathing in the shader via `TIME` (per-prop phase offset from world position, so there's no script).
- **Holograms / ads:** additive unshaded quads with scanline + noise shader.
- **Fake light pools:** painted gradient decals/quads on the ground under each neon source (static,
  so batch them or bake them into the ground texture). `Decal` node support in Compatibility **[verify]**; a plain additive quad always works.

### Blade Runner wet ground (reflections without SSR)
- SSR isn't available in Compatibility. Fake it: under each bright neon source, draw **vertical
  light streaks** on the ground (stretched, blurred, additive quads toward the camera), which is how
  wet asphalt reads. A dark, glossy-looking ground texture helps. `ReflectionProbe` **[verify cost]** only if cheap.

### Atmosphere
- **Depth fog + height fog** from `Environment` (cheap); no volumetric fog in Compatibility.
- **Fake volumetric beams** (floodlights, searchlights): additive cone meshes with soft edges (fresnel) and slow noise scroll.
- **Glow/bloom:** `Environment` glow **[verify levels/quality in 4.7.2 Compatibility]**, with a
  threshold so only HDR emissive (>1) blooms; lower quality on phones.
- One directional light (moon/floodlight) at most with shadows; **blob shadows** (a soft dark quad) under vehicles instead of dynamic shadows on phones.

### Heat, shields, damage state
- **Heat:** `instance uniform float heat` **[verify]** (or MultiMesh custom data) driving barrel/vent emission and a subtle heat-shimmer sprite, with no unique materials.
- **Shield:** a slightly larger hull "shell" mesh with a fresnel rim + hex/noise shader, invisible
  normally; on a hit, show it briefly with a ripple from the hit point (uniform). Show a "shield down" crackle and a recharge sweep.
- **Damage:** smoke flipbooks and sparking emissive flicker at low hull health.

### Whole-frame levers
- **3D render scale** (`scaling_3d_scale`) ~0.7 on phones while the UI stays crisp **[verify Compatibility support]**.
- MSAA 2× vs none as a quality-tier setting.
- Skip effects off screen (`VisibleOnScreenNotifier3D`) and use visibility ranges for far detail.

## How to prove it: the FX lab (L0)

1. **`make fx-bench`**: a deterministic worst-case scene that runs a fixed camera path for N
   seconds, e.g. 10v10 all firing, M tracers, K lasers, explosions, and the full neon prop set.
   It prints `FX_BENCH` lines: average / p95 / p99 frame time, draw calls and objects
   (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`), and per-trick
   toggles (so each trick's cost is its on/off delta). GPU timing via
   `RenderingServer.viewport_set_measure_render_time` **[verify in Compatibility]**. Otherwise, use frame time with vsync off.
2. **An on-screen perf overlay** (`--fx-bench` also shows fps / frame ms / draw calls in a corner) so a phone test needs no console.
3. **Where to measure:** native desktop (fast iteration), a **real browser with GPU** (not the SwiftShader smoke test), and **the lead's phone**:
   `make export-web && make serve-web WEB_HOST=0.0.0.0`, then open `http://<this machine's LAN IP>:8060/?fx-bench` on the phone. The phone test is a checkpoint to hand to the lead (a question at the end of a milestone, not a blocker mid-way).
4. **Record results here:** for each trick, whether it's supported (yes/no in 4.7.2 Compatibility),
   its cost in ms at the worst case (desktop, browser, and phone if measured), a screenshot, and a verdict
   (use / tier-gated / rejected). The **[verify]** tags above become facts.
5. **Set the budget from the data**, e.g. "phone low tier: ≤ 12 ms frame at the worst case, ≤ N draw calls, light pool = 4", and put it in look_and_feel.md so all later FX work designs to it.

## Results (fill in during L0)

| Trick | Supported (4.7.2 Compat) | Cost desktop / browser / phone | Verdict |
|---|---|---|---|
| _(none measured yet)_ | | | |
