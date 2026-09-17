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

_Updated 2026-09-17 (evening)._

**Plan (backlog order):** X1 perf-scene + budget (CP1) ✅ → X2 instance uniforms ✅ → X3 lights ✅ → X4 vehicle read ✅
(first pass) → X5 LOD/instancing/thinning (in progress) → X6 faction art ✅ → arena's kit props (CP2 request) ✅ → stretch.

**Headline numbers** (`make perf-scene`, UHD 620, 61–65 vehicles, tier high; tables in `fx_tricks.md` → M1):

| | Round 5 start | Now |
|---|---|---|
| GPU 1280×720 / 1854×1011 | 18–19 / 29–31 ms | **8.5–9.6 / 12–13 ms** |
| Primitives | 0.97–1.1 M | **0.19–0.28 M** |
| Real lights | 17 | **5** |
| Renderer errors per run | 246 + 93 | **0** |
| Frame | 133 ms (pinned) | 133 ms at 60 vehicles, 40–60 ms at 25–30: **the sim tick (20–24 ms) is the wall** |

### X1: measured, budget published (CP1 announced 2026-09-17)
- `make perf-scene` (`game/theme/fx/bench/perf_scene.gd`, `perf_probe.gd`): a live 34-a-side CPU skirmish, layer
  toggles bracketed by `all` phases, CPU split into sim tick / process (game+UI, FX) / render submission. ~20 layers
  (`PERF_LAYERS=`), `--perf-shot-every-phase` for looking at what a layer changes. Budget: `fx_tricks.md` → M1.

### X2: the instance-uniform wall is gone
- **Cause:** Godot reserves 16 global-buffer slots per instance whose material declares any `instance uniform`; the
  UHD 620's cap is 4,096 slots = **256 instances**. **Fix:** shared materials per (texture set, team, paint, heat step)
  in `UnitSkin.dress()`, per (heat, flash) step in `ColorMeshBuilder.set_glow_state()`, one material per shield.
  Errors 246 + 93 → 0. Test scans every vehicle and faction part (mutation-checked).

### X3: fewer lights, grounded look
- No tier has dynamic shadows or MSAA; blob shadows under vehicles (one MultiMesh); at most 4 pooled lights (2 on low)
  and a `light_floor` so only explosions, shells, beams and muzzles take one. Underglow is a small dim hint.
- Look: stronger neutral moon key, less ambient, brighter corner floodlight pools, softer glow. Shots:
  `build/screenshots/look-before.png` vs `look-after.png`.

### X4: vehicles read as vehicles (first pass)
- Team neon on the model's light bars 0.6 → 0.35; the team now tints the rim on the silhouette. Shot: `look-x4.png`.
- Not done: a check with the lead at play distance (tank vs IFV, Wrecker vs Law). See questions.

### X5: detail levels and thinning (in progress)
- 3D render scale follows the window (0.85 at 1080p: −4.8 ms), glow wide levels only (−2.1 ms at 1080p), mesh LOD
  4 px (−0.6 ms, 374k → 237k prims), 6 sparks per spray (−1.4 ms), floor lit in its shader (−0.6 ms), an overdraw
  budget that thins decorative bursts in pile-ups. Remaining GPU: arena 2–3, glow 1.6–1.9, base ~3 ms.
- Culling: MultiMesh custom AABBs are world-sized for pooled effects (by design); vehicles and props cull normally.

### X6: faction art ships
- New "Linux Desktop" preset (faction art included; only Linux templates are installed) and `make export-desktop`:
  pack **23.2 MB → 43.5 MB**. `FactionArt.unit_slots()` gives gangs, Law and Syndicate units their own models in play
  (wrappers written by `tools/assets/build_faction_parts.py`, `make faction-parts`); missing turret/weapon models are
  empty parts. **Web and server** still exclude `game/theme/factions/*`: there the slots don't exist and a web player
  sees every faction in the Condemned's models (web pack unchanged).

### Arena's kit props (CP2 request)
- `prop.barricade`, `prop.floodlight` (with a painted light pool), `prop.sign` (arena-name neon, `kit_signs.png`),
  `prop.wreck` (husk fit to 3.2 × 2.0 × 6.4 m): one MultiMesh per kind (`arena_kit/kit/kit_yard.gd`).
- Fixed two floor artifacts the new maps exposed: the ad-screen spill flooded its 34 m quad (hard light boxes), and
  40 m floor tiles showed per-vertex fog as blue squares.

### Decisions
- perf-scene uses `--cinematic` (no planning pause, fog revealed: every vehicle drawn = worst case) with its own camera.
- The budget keeps ~10% headroom: a frame over 16.7 ms pays for two sim ticks next frame (the spiral).
- Render scale by window height rather than a fixed tier value: 720p keeps full resolution, big windows pay less.
- Pooled lights no longer light the floor (unlit floor); the effects' ground glows already paint that light.

### Requests to other streams (sent to the orchestrator)
- **combat + ai:** the simulation tick is the frame-rate blocker: 20–24 ms per tick at 60 vehicles on the lead's
  laptop; budget 5 ms. `make perf-scene` reports `tick_script_ms` and `ticks_per_frame`.
- **control:** HUD ≤ 130 draw calls (measured 210–340) and ≤ 1 ms of `_process`.
- **arena:** commit `tests/arena/arena_probe.gd.uid` (Godot generated it for your file).

### Questions for the lead
- **Team read (M3):** is a team-tinted rim plus small light bars enough to tell sides apart at play distance, or do you
  want per-team paint on the hull too? (`build/screenshots/look-x4.png`, `look-factions.png`)
- **Windows build:** only Linux export templates are installed; a Windows desktop preset needs `TEMPLATE_FILES` in the
  shared Makefile to include the Windows templates (~+100 MB in `.tools`). Want it this round?

### Known issues
- CPU numbers are measured on a laptop shared with five other agents (load ≈ 5): pessimistic.
- The 720p GPU line (6.5 ms) is not met yet (~9 ms); 1080p (10 ms) not met (~13 ms).

### What to playtest
- `make skirmish` (feel the look: lights, shadows, team rims), `make skirmish-factions FACTION=law ENEMY_FACTION=gangs`
  (faction models in play), `--arena=boulevard` / `--arena=boneyard` (kit props), `make perf-scene` (numbers).

### Merge notes
- `export_presets.cfg`: new preset.2 "Linux Desktop" (render owns the art filters).
- No other shared files touched. `mk/fx.mk` (perf-scene) and `mk/assets.mk` (faction-parts, export-desktop) are render's.
