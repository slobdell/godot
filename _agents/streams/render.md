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

**Closed for round 5, merged at `265dbcfc`.** `make remote T=check` green on both merge points: **404152fe** (main merge
with the 30 Hz simulation, contains the blob-shadow fix) 987 passed, 0 failed; **265dbcfc** (the feed's late-frame skip,
the hitch log, the round-6 write-up) 988 passed, 0 failed.

**Reopened and closed again, 2026-09-17: the MultiMesh interpolation warnings** (orchestrator's request, commit
`8168e158`). The 30 Hz tick turned physics interpolation on, so the renderer interpolates MultiMesh transforms between
ticks and every `_process` write logged `[Physics interpolation] MultiMesh interpolation is being triggered from
outside physics process`. None of these meshes should be interpolated — their transforms already come from
`FxWorld.visual_transform()`, i.e. from where things are drawn, so the renderer would interpolate an interpolation and
smear every effect a frame behind.

There are **two switches and both matter**, which is worth knowing in any stream that owns a MultiMesh:
- the **node's** `physics_interpolation_mode`: a MultiMeshInstance3D pushes its own state to the server whenever that
  state changes, *entering the tree included*, which silently undoes a server flag set in `_init`. Measured: with the
  server call alone the node still reports `is_physics_interpolated_and_enabled() == true`, and a burst spawn still
  warned in a playtest.
- the **server's** flag on the multimesh, which is reset by any `instance_count` change, because that rebuilds the
  buffers.

`game/theme/fx/fx_multimesh.gd` holds both (`never_interpolated()` per mesh node, `resize()` for every count change)
rather than 21 one-liners the next resize would undo, and `tests/test_render_multimesh_interpolation.gd` fails if
anyone sets `instance_count` directly or adds a mesh node without the switch (mutation-checked). A 6 s playtest:
**0 interpolation warnings, 0 warnings or errors of any kind** (was 1, from a burst spawn), screenshot still has its
bursts, tracers, blob shadows and arena kit. `game/ui/selection_markers.gd` is control's and fixed on their side.

**Open for round 6, in order of what the lead is waiting on:**
1. His own clean `perf-scene` run: nobody has measured his laptop in the state he plays in (ours: ~29 vehicles quiet,
   12–15 under load, locked 30 at 1080p).
2. The catch-up-steps comparison above, if he wants it measured (render has the instrument, combat owns the setting).
3. The GPU lines are still unmet on paper (9–10 ms at 720p against 6.5; 15 at 1080p against 10), which only matters once
   the tick stops being the wall. The cuts left, priced: render scale 0.75 −2.8 ms, glow off −1.7 (he kept glow),
   venue off −1.35.

**Plan (backlog order):** X1 perf-scene + budget (CP1) ✅ → X2 instance uniforms ✅ → X3 lights ✅ → X4 vehicle read ✅
(first pass; team-read question for the lead) → X5 LOD/instancing/thinning ✅ → X6 faction art ✅ → arena's kit props
(CP2 request) ✅ → stretch: wrecks left burning ✅; "desktop high" renderer and weather not started (see below).

**Headline numbers** (`make perf-scene`, UHD 620, 61–65 vehicles, tier high; tables in `fx_tricks.md` → M1):

| | Round 5 start | Now |
|---|---|---|
| GPU 1280×720 / 1854×1011 | 18–19 / 29–31 ms | **8.5–10 / 12–14 ms** |
| Primitives | 0.97–1.1 M | **0.19–0.39 M** (rises with wrecks) |
| Draw calls (HUD inside) | 810–930 (200–310) | **430–700** (HUD 200–245; 3D ≈ 230–460) |
| Effects `_process` | 1.3–1.8 ms | **~1.05 ms** (0.18 of it audio's engines/gunfire) |
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

### X5: detail levels, instancing, thinning
- **GPU:** 3D render scale follows the window (0.85 at 1080p: −4.8 ms), glow wide levels only (−2.1 ms at 1080p), mesh
  LOD threshold 4 px (−0.6 ms, 374k → 237k prims), 6 sparks per spray (−1.4 ms), floor lit in its own shader (−0.6 ms),
  an overdraw budget that thins decorative bursts in pile-ups.
- **Draw calls:** the venue's repeated models (20 stands, 4 towers, 2 gates) are one MultiMesh per mesh
  (`StaticInstancer`), the unlit floor is one plane instead of 64 tiles: arena 45 → 5 draws. Generated parts' empty
  accent meshes are hidden (180 fewer culled objects).
- **CPU:** `MotionFx` ranks vehicles every 0.2 s and only fully watches the 20 nearest; recoil jolts skip vehicles past
  75 m from the camera. perf-scene times every FxWorld step (`fx_steps_ms`) and has a census (`--perf-census`).
- Remaining GPU at 720p: arena ~2–3 ms (floor 2.3), glow 1.6–1.9, effects 1.3–2.7, base ~3 ms. Remaining draws: HUD
  200–245 (control), vehicles 3 per vehicle, control's selection markers (61 MeshInstance3Ds at 60 units).

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

### Stretch
- **Wrecks left burning:** `WreckField` leaves a charred husk where each vehicle died (one MultiMesh, an ~800-triangle
  LOD, 48/24/12 per tier, cleared by a new match); the fire sites already burn on them.
- **"Desktop high" with a better renderer:** not started. On the lead's UHD 620 Forward+/Mobile would cost more, not
  less, and web must stay Compatibility; worth it only for a Steam build on real GPUs.
- **Weather or smoke:** not started: the GPU line isn't met yet.

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

### The lead's answers (2026-09-17, via the orchestrator)
- **Glow: keep it** (the frame is sim-bound; switching it off buys nothing today).
- **Team read: "Rim tint is enough."** No hull paint; `team_paint` stays a perf-scene layer for reference only.
- **Windows build: skipped this round.** Don't install the templates.
- **Arena screens: "Live during, ads between."** Live match content on the screens during the fight (shared 15 Hz feed
  camera, ring-buffer replay after kills), the approved ad copy (`assets/announcer/drafts/ad_copy.md`) between
  matches. Prove the cost with a `live_feed` perf-scene layer first; the measured number decides replay quality.
- **30 Hz simulation starts this round** (combat owns the refactor): take a "60 Hz, pre-interpolation" perf-scene
  baseline first, and flag anything that reads a body's transform in `_process`.

### Known issues
- CPU numbers are measured on a laptop shared with five other agents (load ≈ 5): pessimistic.
- The GPU lines aren't met: ~9–10 ms at 720p (budget 6.5), ~13–14 ms at 1080p-class windows (budget 10). Glow off
  would bring 720p to ~8; the rest is the floor and the base cost. Even so, the frame is bound by the sim tick.
- `make fx-bench` still runs (its `all` config: 185 draws, was 401).

### What to playtest
- `make skirmish` (the look: lights, blob shadows, team rims, wrecks after kills),
  `make skirmish-factions FACTION=law ENEMY_FACTION=gangs` (faction models in play), `--arena=boulevard` and
  `--arena=boneyard` (kit props: barricades, towers, signs, wrecks), `make perf-scene` (the numbers; opens a window
  for ~2 minutes), `make export-desktop` (43.5 MB desktop pack).

### After main's Jolt physics (re-measured 2026-09-17, main 8d975fa)
- `make perf-scene`, 720p: sim tick **21.5 ms at 66 vehicles** (still 9 ticks per frame), 14 ms at 43, 10 ms at 20;
  GPU **9.5–10.7 ms**; draws 460–700; 0 engine errors. The frame first holds 60 fps at **~8–10 vehicles**
  (12–14 ms, ticks_per_frame ≈ 1). 1080p-class: GPU 13–15 ms (this run's layer deltas are spoiled by one 28 ms sample).
- The four kit arenas (yard, boulevard, pit, boneyard) at gameplay zoom read well at the new light levels
  (`build/screenshots/arenas-grid.png`). Only nit: an ad screen seen from behind is a flat black slab.

### Tracers moved into the gap (orchestrator's review of the arenas grid, 2026-09-17)
- With the accent lights fixed, saturated, heavily-blooming tracers became the loudest thing on screen. Now: hdr boost
  3.0 → 1.5, warm incandescent with a 45% team tint, width/tail/floor splat roughly halved per style. Before/after:
  `build/screenshots/comets-before-after.png` (left before, right after).
- Ad screens seen from behind: lighter housing, ribs, amber service lights (no longer a black slab).
- **Team read evidence for the lead:** perf-scene layer `team_paint` coats hulls in a dulled team color;
  `build/screenshots/team-read-crop.png` (left today's rim tint, right painted). Not the default: the lead's call.
- **The floor** (the orchestrator: vehicles were dark shapes on a dark flat surface): the baked light map is in color
  now (cool tower light, warm sodium pools thrown by each layout's own floodlight props), an overhead rig lights the
  middle of the field where fights happen, and the unlit floor's moonlight is ~30% stronger, so hulls read as
  silhouettes on lit mid-grey ground. Same fetch count: no frame cost. `build/screenshots/floor2-grid.png` (left
  before, right after, yard and boulevard).
- **Baked wear** from each layout: tyre tracks and a faint polish along lanes, oil and grime under wrecks and stacks,
  scuffed spawn zones, in the flood map's alpha (256 texels, still one fetch, zero per frame). Kept light so lanes
  don't darken the ground under vehicles. `build/screenshots/wear-grid.png`.

### Live screens: "Live during, ads between" (built 2026-09-17)
- `LiveFeed` (`game/theme/arena_kit/ads/live_feed.gd`): a broadcast camera renders at 15 Hz into a ring of
  SubViewports sharing the arena's world (high 30 × 256×512, medium 16 × 192×384; low/web keeps the ads). The newest
  slot is live on every AdBroadcast channel while a match is fought (the ad layout stops redrawing); after the match,
  ads. A kill within 45 m of the shot replays the ring at half speed, at most every 9 s; no readback, no rewind.
- The shot (reworked after the orchestrator's review, which found two of three frames empty): `best_shot` scores every
  vehicle's 30 m neighbourhood for vehicles, both teams present, and fresh kills/hits, and frames its centroid; far
  switches are cuts (≤ 1 per 3 s); a frame is recorded only with 3+ vehicles in shot, screens hold the last good frame
  and fall back to ads after 2 s without one; the portrait camera keeps its width. 18 sampled frames on yard and
  boulevard all show vehicles: `build/screenshots/shot-feeds.png`.
- **Between matches:** the lead's twelve approved ads (`ad_copy.md`, as written) plus the live score card; each brand
  has a procedural motif (`tools/assets/build_ads.py`); headlines break at 13 characters. `build/screenshots/ads-grid.png`.
- **Live score card names factions, never colours** ("CONDEMNED  2 / LAW  0"; HOME / AWAY when unreadable or the
  same faction); a test fails if GREEN or RUST reaches a screen.
- **A test that passed while asserting nothing:** a screen test showed an ad by a stale id; `index_of` returned -1 and
  `show_ad` clamped it to the first ad, so the assertion passed against the wrong ad. `show_ad` now raises an engine
  error on an unknown index (mutation-checked: the stale id fails the test). Siblings checked: every other
  `index_of` in the tests names a real ad.
- **Cost, measured:** at 13 vehicles (frame not sim-bound), `no_live_feed` × 4 cycles: frame time within noise
  (−0.3 ms; +0.02 ms after the framing rework). Caveat: perf-scene's GPU timer and draw monitors only see the main viewport, so the feed's own GPU time
  isn't isolated; the frame-time delta is the honest number. At 60 vehicles: 2 replays in 16 s, still live.
- Estimated VRAM on high: 30 × (256×512 color + depth) ≈ 30–45 MB.

### What 30 Hz can and can't fix: projections from the 60 Hz baseline (to be replaced by the measurement)

**Model.** The simulation runs as many ticks as the frame took, so a frame is `R / (1 − tick / tick_period)`, where
`tick` is one tick's script time and `R` everything else a frame does (render submission, GPU wait, `_process`),
calibrated from the uncapped baseline phases: **R ≈ 10.1 ms at 720p, ≈ 12.5 ms at 1080p** (it predicts 15.0 ms at
13 vehicles, measured 15.7). 60 fps needs `tick ≤ tick_period × (1 − R / 16.7)`; 30 fps needs `tick ≤ tick_period ×
(1 − R / 33.3)`. Assumes one 30 Hz tick costs what a 60 Hz tick does (the brains and Match don't do less per tick).

Baseline tick by vehicles (720p run): 13 → 5.5 ms, 23 → 10.8, 27–39 → 14.2, 44 → 16.1, 54 → 22.4, 65 → 34.8.

| Target | Tick must be ≤ at 60 Hz | at 30 Hz | Holds to (30 Hz, projected) | 30 a side (60 vehicles, tick ≈ 22–35 ms) |
|---|---|---|---|---|
| 60 fps, 720p (R 10.1) | 6.6 ms | **13.2 ms** | **~25 vehicles** (was 13) | no: the tick must fall another 40–60% |
| 60 fps, 1080p (R 12.5) | 4.2 ms | **8.4 ms** | **~12 vehicles** (was never) | no |
| 60 fps, 1080p with every GPU cut below (R ≈ 8.5) | 8.2 ms | 16.4 ms | ~40 vehicles | no |
| **locked 30 fps, 1080p (R 12.5)** | 20.8 ms | **41.6 ms** | **~60 vehicles: 30 a side** | **yes** |
| locked 30 fps, 720p (R 10.1) | 23.2 ms | 46.4 ms | 60+ | yes |

**The 1080p GPU floor** (measured, `floor-1080-options`, 60+ vehicles, window 1854×1011): GPU 14.8 ms. Cuts available:
3D render scale 0.75 (−2.8 ms; softer image), glow off (−1.7 ms; the lead chose to keep it), venue off (−1.35 ms;
stands, crowd, screens), the lite floor (+1.6 ms: worse, it's lit; the unlit floor is already the cheap one). All of
them together leave ~9 ms of GPU, still most of a 16.7 ms frame.

**What that means, for the lead:** 30 Hz roughly doubles how many vehicles hold 60 fps at 720p (13 → ~25) but doesn't
reach 30 a side there, and at 1080p 60 fps stays out of reach this round whatever the tick does, unless the look gives
up glow, resolution and the venue *and* the tick falls further. **A locked, stable 30 fps at 1080p with 30 a side is
reachable with 30 Hz alone** and may be the better game than an unstable 60: that's a design decision, not an
engineering failure.

### Measured on 30 Hz (main 84376839, 2026-09-17): the tick rate bought much less than projected

`make perf-scene`, UHD 620, same scene as every other run. Files: `_agents/streams/references/perf/hz30-*.json`.

| | 60 Hz baseline | 30 Hz now |
|---|---|---|
| 60 fps holds at (720p / 1080p) | 13 / never | **14 / 8 vehicles** |
| Locked 30 at 1080p, **p95**, quiet laptop | never | **~18 (mine) to ~29 (combat's)** |
| Locked 30 at 1080p, p99 (rare hitches counted) | never | **8–14** |
| Locked 30 at 720p | never | 18 |
| GPU | 10 / 14 ms | 9 / 15 ms (unchanged) |

**The agreed picture (with combat, 2026-09-17).** A locked 30 fps at 1080p holds **~29 vehicles on a quiet laptop and
12–15 while five agents share the CPU**; my quiet run gives ~18 by p95. Two measurement notes that explain the spread
and should travel with the number:
- **Machine load moves it more than anything we build.** Same tool, same build: 12–15 under load, 18–29 quiet.
- **p95 versus p99.** Combat quote p95; I quote p99 because the lead's target is a *locked* rate. At 18 vehicles my p95
  is 33.5 ms (locked by that measure) while the p99 catches occasional 40–100 ms frames. **Neither of us has measured
  his machine in the state he plays in**; his own clean `perf-scene` run is the tiebreak.
- **The hitches, chased down:** perf-scene now logs each frame far over the target with what ran in it
  (`PERF_SCENE_HITCH`). Every one was a frame in which the **simulation ran 2–3 ticks at once** (catching up, 23–44 ms
  of script), and in two of three a **feed slot rendered in that same already-late frame**. The sim half is combat's;
  render's half is fixed: LiveFeed now skips a feed frame whose last frame ran more than 1.3× the frame target, so it
  never adds a scene render to a frame that is already behind. Same scene, capped 30 at 1080p: **3 hitches → 0**.

**Combat's correction to my decomposition, which I accept:** the `segment:controllers` band is `OrderController`
executing every tick *as well as* `TankBrain` thinking on a wall clock. The executing half halves with the tick rate,
the thinking half does not — so the ceiling is not my ~13% but their measured **27%** (513 → 377 ms of script per
simulated second, same seed, same 60 simulated seconds, same laptop). Their earlier 47% is withdrawn.

**Reconciled with combat (2026-09-17).** Two separate factors, and their headless number and mine are consistent:
- **Machine:** combat's own `make sim-profile TIME=60` run on the lead's laptop gives **tick 18.42 ms at 58 vehicles**
  against **6.68 ms on builder0**: the laptop is **~2.75× slower** for the identical headless workload. In game on the
  laptop it is ~32 ms: rendering shares the main thread in Compatibility, plus other agents' load. Same thing measured
  in three places; only the last is what the lead gets.
- **Why 30 Hz can only save ~13%:** the same profile with `PROFILE_FLAGS=--no-brains` gives **tick 2.69 ms**, so brains
  are **85% of a tick** (15.69 ms of 18.42). Brains think at a fixed 10/s wall clock, so their cost *per second* does
  not change with tick rate; only the non-brain 2.7 ms per tick halves (~81 ms/s of ~630). That is the ~13-18% measured,
  and combat's `ready_to_fire` fix (~14% more shells) accounts for the rest.
- The doctrine default was **withdrawn**, so it is not part of this (an earlier note here said otherwise).
**The arithmetic that settles the strategy:** the tick is 18.42 ms at 58 vehicles on the laptop. With `--no-brains` it is
2.69 ms. **Brains are 85% of a tick.** They think on a wall-clock schedule, so their cost per second is *independent of
tick rate*; only the non-brain 2.7 ms halves. That is ~81 ms/s out of ~630: **30 Hz could never have saved more than
~13%.** The tick change was sound engineering aimed at the wrong 15% of the problem, and the decomposition above is what
shows it.

**No reactivity regression, and a small surprise** (checked in the code, not inferred): think intervals are tick-rate
relative (`TankBrain.THINK_EVERY_TICKS = SimClock.TICK_RATE / 10`, the champion's `think_ticks = TICK_RATE * 3 / 20`).
At 60 Hz that was every 9 ticks = 6.67 thinks/s; at 30 Hz integer division gives every 4 ticks = **7.5 thinks/s, ~12%
MORE often**. So brains did not become less reactive — they became slightly more so, and that extra thinking is part of
why the per-second saving came out below even the 13% ceiling.

**The lever is brain cost per second, not tick rate: 30 Hz has already given what it can.**

**Against the lead's target** (locked 30 at 1080p with 30 a side): not met. It needs a tick of ~21 ms at 60 vehicles
(frame = R / (1 − tick/33.3), R ≈ 12.5 ms at 1080p); measured is 32–42 ms. The tick has to come down ~40–50%, and
that is the whole gap: GPU, draw calls and effects are all inside budget.

**Measurement fix in the same commit:** perf-scene's "uncapped" runs were silently capped at 30 fps, because FxWorld
applies the frame target in its own `_ready`, which runs after this node's (children first). It now clears the cap every
frame while measuring uncapped, and `holds_*_at_vehicles` allows 1 ms over the target (a 30 fps cap measures 33.4 ms).

### The lead's decision: a locked 30 fps at 1080p with 30 a side, plus a 720p 60 fps option
- `FrameTarget` (`game/theme/fx/frame_target.gd`): **LOCKED_30** (default: `Engine.max_fps` 30, 3D native up to 1080
  lines) or **PERFORMANCE_60** (60 fps, ~720 lines of 3D, UI full resolution). `--frame-target=30|60`, or the player's
  saved choice via `FrameTarget.apply(target, "player", true)` (control's menu: requested); the web gets no cap.
- perf-scene: `p99_ms` and `max_ms` per phase; **`holds_30fps_at_vehicles`** judged on the 99th percentile (a locked rate
  that drops isn't locked) next to `holds_60fps_at_vehicles`; `--perf-capped` measures with the cap and vsync on.
- **Before 30 Hz, capped at 30, 1080p:** it never holds (36–64 vehicles: p99 94–144 ms, the 60 Hz spiral).
  `_agents/streams/references/perf/locked30-capped-60hz-1080.json`. The 60-vehicle line is the one to clear.

### Ready for 30 Hz with physics interpolation (combat's refactor)
- 60 Hz baseline: `_agents/streams/references/perf/baseline-60hz-preinterp{,-1080}.json` (main 328b67b). **The lead's
  number, before 30 Hz: 60 fps held at 13 vehicles at 720p, and never at 1080p** (median frame at 10 vehicles 18.8 ms).
  perf-scene now reports it as `holds_60fps_at_vehicles` (median frame per vehicle count, every smaller count under
  16.7 ms).
- `FxWorld.visual_transform()` for everything that follows a body per frame; `WeaponFx.drawn_offset()` keeps muzzle
  effects on the drawn barrel. Combat confirmed: shells interpolated, `reset_physics_interpolation()` on spawns,
  `shooter` stays in `weapon_fired`. Re-take perf-scene on their flip commit.

### Round 6, for the lead: catch-up steps, or a clock that falls behind?

`max_physics_steps_per_frame` is **3** (combat's round-5 choice, down from Godot's default 8, which is the spiral). It
decides what a slow machine does when a frame runs long, and the two outcomes are genuinely different games rather than
better and worse:
- **3 steps (today):** after a slow frame the simulation catches up in the next one. That catch-up frame carries 2–3
  ticks, 23–44 ms of script — every hitch in `PERF_SCENE_HITCH` was one of these. The clock stays true; the picture
  stutters.
- **1 step:** the frame stays smooth and the *simulation clock* falls behind instead, so under load the game plays in
  slight slow motion. Nothing stutters; everything is a little slower than real time.

For a locked 30 on the lead's laptop, smooth-but-slightly-slow may be the better experience, and it is his call, not
ours. Combat owns the setting; render has the instrument (`make perf-scene --perf-capped`, hitch log, p99 and worst
frame) and can measure both in an hour. **Not changed now:** it would move behaviour under a build he has just measured.

### Next steps
1. The lead's answers on glow and team read (M3); then per-team hull paint if the rim isn't enough.
2. Re-measure `make perf-scene` when combat and ai land sim-tick work: once ticks_per_frame is ~1, the GPU line starts
   to matter and the next cuts are the floor (a cheaper unlit variant), glow, and the effects' base.
3. A Windows desktop preset once the templates are installed (shared Makefile edit).
4. Control: HUD draw calls and one MultiMesh for selection markers (M1/M3).

### Merge notes
- `export_presets.cfg`: new preset.2 "Linux Desktop" (render owns the art filters).
- No other shared files touched. `mk/fx.mk` (perf-scene) and `mk/assets.mk` (faction-parts, export-desktop) are render's.
