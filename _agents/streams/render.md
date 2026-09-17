# Stream: render (frame rate, and vehicles that look like vehicles)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*), [../workstreams.md](../workstreams.md) (**M1 is yours and is CP1**; M3 you share with control),
> [../art_direction.md](../art_direction.md) and [references/fx_tricks.md](references/fx_tricks.md) (the tricks and tier
> budgets from round 1). You own `game/theme/**`, the art paths under `assets/`, `tools/assets/`, `mk/{fx,assets}.mk`,
> the art filters in `export_presets.cfg`, `_agents/{art_direction,slot_contracts}.md` and `fx_tricks.md`.

## The lead's direction (2026-09-17)

> *"right now for this many vehicles the framerate drops substantially. We should fix this one way or another, and I
> suspect that might be possible without so many wild lighting effects (i.e. I bet we can make the game feel more
> realistic and get better frame rate at the same time) … the accent lights on all the vehicles make those lights the
> overwhelming thing seen by the game (i.e. I don't see tanks, I see blue lights)."* And: **faction art ships**.

Take the hypothesis seriously: fewer, better-motivated lights should buy performance *and* a more grounded look. Neon
is mood; the machine is the subject.

## Where things stand

- Round 3's effects work (pooled effects, tier budgets, `make fx-bench`, the FX lab) measured **6.9 ms a frame at
  25 v 25 on builder0's Iris Xe** — but that was effects on top of a smaller army, and the lead's laptop is an older
  UHD 620.
- **The renderer runs out of per-instance shader uniforms at ~30 a side** (found twice, by combat and control): hundreds
  of `Too many instances using shader instance variables … Maximum items supported by this hardware is: 4096`, then
  `instance_buffer_pos` failures. 4096 is the hardware cap, so a bigger buffer setting is not the fix — the vehicle
  materials need fewer per-instance uniforms (bake per-unit colour into vertex colours, or share a material per team).
  Users: `game/theme/cyberpunk/{unit_skin,weapon_cannon,dozer_part}.gd`, `game/theme/fx/shaders/{unit_body,vehicle_glow,shield}.gdshader`.
- **Faction art exists but doesn't ship** (47 MB, `game/theme/factions/`, excluded from both export presets): the three
  new rosters play as themselves and look like the Condemned through the C6 fallback.
- The arena kit (containers, ad screens, barricades, signs) exists but is barely placed — the arena stream places it;
  you make sure it renders cheaply.

## Backlog (in order)

**X1. Measure first, and publish the budget (M1; CP1).** `make perf-scene`: a scripted 30-a-side battle that reports
frame time (average, p95), draw calls, primitives, real lights alive, and where the time goes (CPU render, GPU), run on
this laptop's GPU class. Break the cost down by layer: vehicles, effects, lights, ground and props, HUD. Write the
budget into `fx_tricks.md` — what a frame may spend, how many real lights may exist at once, the triangle and draw-call
ceilings — and **announce CP1** so the other streams can design against it.

**X2. The per-instance uniform wall.** Get vehicle materials off per-instance uniforms (vertex colours, a material per
team, or instance custom data), so 60+ vehicles render without errors. The console must be clean at 30 a side.

**X3. Fewer lights, better look.** Cut real lights hard (they are the usual suspect on integrated GPUs): keep a small
pool for the moments that matter (a firing tank, an explosion), and replace the rest with emissive, light splats on the
ground, and baked or faked light from the arena's own fixtures. Aim for a grounded, filmic night: strong key from
floodlights and screens, less uniform neon wash. Compare before and after with screenshots **and** numbers.

**X4. Vehicles that read as vehicles (M3, with control).** Team accent becomes a hint: a smaller emissive area, a rim
or trim light, per-team paint that survives at distance. The lead must be able to tell a tank from an IFV at play
distance, and a Wrecker from a Law vehicle at a glance. Screenshots at the default zoom, 30 a side, next to today's.

**X5. Detail levels and instancing at scale.** Automatic levels of detail for vehicles and props, one draw per prop
kind (the containers already use MultiMesh), culling that works with the close camera, and effects that thin out with
distance and unit count. Re-measure against X1's budget.

**X6. Ship the faction art.** Include `game/theme/factions/*` in the desktop presets (the lead approved), keep the web
build lean and say in your Status what a web player sees instead. Report the desktop and web sizes before and after.

- **Stretch:** a "desktop high" tier that uses the better renderer when the platform allows; wrecks left burning
  (the husk prop exists); weather or smoke if the budget allows.

## How to verify

`make remote T=check` (the sim baseline must not change: rendering never touches the simulation), `make perf-scene`
before and after each item, `make fx-bench`, and screenshots at 30 a side **looked at** and compared. Report numbers
from this laptop's GPU class, not only builder0's.

## Don't touch

Arena layouts and where props go (arena), gameplay (combat), brains (ai), UI and camera (control), audio (audio).

## Status

_Updated 2026-09-17._

**Plan (backlog order, smallest foundation first):** X1 perf-scene + budget (CP1) → X2 instance uniforms off vehicles →
X3 lights → X4 vehicle read → X5 LOD/instancing → X6 faction art in desktop exports → stretch.

### X1: measured, budget published (CP1 announced 2026-09-17)
- `make perf-scene` (`game/theme/fx/bench/perf_scene.gd`, `perf_probe.gd`; test `tests/test_render_perf_scene.gd`): a
  live 34-a-side CPU skirmish on this laptop's UHD 620, layer toggles bracketed by `all` phases, CPU split into sim
  tick / process (game+UI, FX) / render submission. Numbers, reading and **the budget: `fx_tricks.md` → M1**.
- **Headline:** 133 ms frames at 60+ vehicles, pinned by Godot's 8-ticks-per-frame cap: the **simulation tick's scripts
  take ~20 ms at 60 vehicles** (9–15 ms at 20–30). GPU 18 ms at 720p, 30 ms at 1080p: floor+props 7/12, moon shadows
  4.4/5.5, effects 2/4, 16 pooled lights 1.7/2.8, glow 1.3/3.2, vehicles 1/2. HUD = 200–310 of 800–930 draw calls.
- **Budget:** frame ≤ 15 ms avg; sim tick ≤ 5 ms at 60 vehicles (combat + ai); GPU ≤ 6.5 ms at 720p / ≤ 10 ms at
  1080p; ≤ 350 draw calls (3D 220, HUD 130); ≤ 6 real lights, none per vehicle, no dynamic shadows on the default tier;
  no instance uniforms on anything that scales with units.
- Caveat: five other agents share this CPU (load ≈ 5), so CPU lines are pessimistic until re-measured quieter.

### X2: the instance-uniform wall is gone (2026-09-17)
- **Cause:** Godot reserves 16 global-buffer slots for every instance whose material declares any `instance uniform`
  (`MAX_INSTANCE_UNIFORM_INDICES`), whatever it uses; the UHD 620's cap is 4,096 slots, so **256 instances**. Hull,
  turret, weapon and shield per vehicle ran out at ~30 a side.
- **Fix:** no instance uniforms on vehicles. `UnitSkin.dress()` picks a shared material per (texture set, team, paint,
  heat step of 8); `ColorMeshBuilder.set_glow_state()` a shared glow material per (heat step, flash step); each
  `ShieldEffect` owns its material. Draw calls unchanged (Compatibility draws each instance anyway).
- **Measured** (`make perf-scene`, 720p, 63 vehicles): instance-uniform errors **246 → 0**, other engine errors
  **93 → 0**. Vehicles' GPU cost now reads 6.4 ms (was 1.1): the parts past the cap weren't drawing correctly before, so
  X4/X5 own that number now.
- Test: `test_no_vehicle_part_uses_instance_uniforms_whatever_it_is_doing` scans every slot and faction part after
  team, paint, heat, shield and firing calls (mutation-checked: an `instance uniform` put back in the shield shader
  fails it).

### Decisions
- perf-scene uses `--cinematic` (no planning pause, fog revealed: every vehicle drawn = the worst case) but its own
  camera, so runs frame the same fight.
- The budget keeps ~10% headroom because a frame over 16.7 ms pays for two sim ticks next frame (the spiral).

### Requests to other streams (sent to the orchestrator)
- **combat + ai:** the simulation tick is the frame-rate blocker: ~20 ms per tick at 60 vehicles on the lead's laptop;
  budget 5 ms. Check with `make perf-scene` (`tick_script_ms`, `ticks_per_frame`).
- **control:** HUD ≤ 130 draw calls (now 200–310) and ≤ 1 ms of `_process`.
- **arena:** props batched (≤ 2 draws per kind), no lights, no per-prop `_process`.

### Questions for the lead
- (none yet)

### Merge notes
- No shared files touched so far (`mk/fx.mk` is render's).
