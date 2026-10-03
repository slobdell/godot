# Stream: render (the GPU's 20 ms at his window, and the theme's per-frame scripts — the picture unchanged)

> Read `_agents/orchestration.md` (the worker contract), `_agents/streams/references/fx_tricks.md` (M1: the budget, the
> round-5 cuts, the priced levers), `_agents/streams/references/perf/README.md`, `_agents/lighting.md`,
> `_agents/arenas.md` *Cost per frame*, `_agents/show_dials.md`, `_agents/verification.md`, `_agents/workstreams.md`
> *Round 16*. You own `game/theme/**` EXCEPT `game/theme/audio/**` and `game/theme/fx/bench/**` (play's), the
> `[rendering]` keys of `project.godot` (a carve-out: list every edit in merge notes), `tests/test_theme*.gd`,
> `tests/test_render*.gd`, `tests/test_fx*.gd`, `tests/test_show*.gd`, `mk/show.mk`, `mk/arena.mk`'s shot targets,
> `tools/look_parity.py` (new, yours). Contracts C16.1–C16.6. **The one rule of this round: the picture he sees does
> not change (C16.1, C16.6) — a lever that changes the look is PRICED on a page for him, OFF by default, never shipped
> on your own call.**

## The lead's direction (2026-10-02)

> *"the game is getting extremely choppy … before sacrificing any of the existing graphics or gameplay let's find (or
> profile our code) where we can just get better performance out of our application"*

He plays `make skirmish` natively on his laptop (Intel UHD 620, Mesa, Compatibility renderer), maximised to
1854×1011, `FrameTarget.LOCKED_30` (so `max_3d_lines=1080`: NO render-scale reduction at his window), glow kept by his
round-5 word. Choppy from the first second, default armies.

## Where things stand (measured today, 2026-10-02, at `1efa9940`, his laptop)

Two labelled baselines beside the older ones in `_agents/streams/references/perf/`:

| file | run | headline |
|---|---|---|
| `r16-before-720-cinematic.json` | 1280×720, `--cinematic --mute` (round 5's scene) | GPU **12.1 ms** flat at every vehicle count (was 8.5–9.6 after round 5's cuts, `fx_tricks.md` *After X2–X5*); holds locked 30 at 23 vehicles, 60 at 12 |
| `r16-before-1080-his-flags.json` | 1854×1011, `--announcer=voice --music=on --camera-readout=on`, unmuted | GPU **19–23 ms** at every count (budget ≤ 10 ms at 1080p); layer GPU costs: **arena 3.9, glow 3.3, effects 3.1, pool lights 1.5**, shadows 0.6, vehicles ≈ 0, HUD ≈ 0; so a **base of ~8–9 ms** no layer accounts for (clear, sky, skyline, venue/stands/crowd, water, ads, post, tonemap, composite) — `--perf-census` and your own layers split it; holds locked 30 at **10** vehicles, 60 at none |

Per frame on the CPU side of your paths: `process_fx_ms` 0.9–1.1 ms (budget ≤ 1.0; `fx_steps_ms` by system: motion
0.25–0.35, engines_gunfire 0.17–0.22, underglow 0.13–0.16, jolts 0.08–0.17), `cpu_render_ms` 1.5–2.0 (budget 1.5),
draw calls 280–440 (budget ≤ 350; HUD ~82 of them), primitives 380–500 k (budget ≤ 450 k).

The laptop was running one other agent's shell commands during both runs; GPU numbers are the GPU's (the layer method
alternates `all` and `no_<layer>` phases seconds apart, so a layer's cost cancels the battle's drift and the load).
**The GPU alone is 20 ms of a 33 ms locked-30 frame at his window, and the tick (sim's and brains') is 24 ms on the same
main thread: both have to come down for him to feel it; yours is the half that does not change a decision.**

Suspects from the survey (hypotheses; price each by removal within one run before touching it):

- **The venue:** round 6 measured stands/gates/screens ~2.5 ms + crowd 1.05 ms GPU at the low camera
  (`perf/feel-r6-venue-1080.json`); the stands are lit PBR with normal maps at 5.4 k triangles a module, backdrop at
  60–250 m (`fx_tricks.md` *The GPU cuts that are left*: "unlit stands, est. most of the ~2.5 ms", priced, not built —
  **but an unlit material that is pixel-equal at his pose is not a cut; one that reads flatter is, and goes on the page**).
- **The stadium screens render a SubViewport scene** (`game/theme/arena_kit/ads/live_feed.gd:159-193`, `FEED_HZ`) and
  the ad broadcast renders its viewport (`ad_broadcast.gd:117-125`, half-rate only on LOW). What do they cost at his
  window, and is anything rendered that the screen then shows at 30 px?
- **Overdraw and fragment cost:** the floor's shader (`arena_ground*.gdshader`, `wet_ground`), water (round 12: ~1 ms,
  0 draws — re-measure at his window), heat haze, fog of war's visual, glow's levels (3 and 5 only: confirm that is
  what runs), the night sky + skyline (0.45 ms in round 6), the city blocks' per-window texel shader
  (`city_block.gdshader`) at the cutaway's exposed faces.
- **Per-frame CPU in the theme:** `Show.apply()` writes `bindings × fixtures` `set_shader_parameter` per frame
  (`show.gd:535-650`, `writes_last_frame` is already counted: how many, and how many carry an unchanged value?);
  `_listen_for_captures` reads `_mood.get("_control_changes")` per frame; `BlockCutaway` loops every solid and every
  part toggling `visible` every frame (`game/camera/block_cutaway.gd:86-116` is hud's — request a dirty flag from hud,
  or expose a cheaper query from your side); `SyndicateAdAirship.advance_to` can step `MAX_CATCHUP` ticks in one
  `_process`; `FxWorld`'s 14 systems each `update()` per frame (`fx_world.gd:179-212`) — which ones have nothing alive?
- **Materials and draws:** `Impact` allocates a `SphereMesh` + `StandardMaterial3D` per hit (`game/combat/impact.gd`;
  the sim side is sim's, the mesh is yours via a request or an adapter in `game/theme/fx`); 280–440 draw calls at
  ~30 vehicles — the census says whose.
- **Engine settings** are all runtime (`FxQuality`, `FrameTarget`, `arena_environment.gd`): MSAA off, moon shadows off,
  blob shadows one MultiMesh, glow on 3 and 5, LOD 4 px. Confirm each is what actually runs in HIS launch (an arm
  assertion, lesson of round 9: read the state the renderer consults, not the setting that was issued).

Instruments: `make perf-scene` with `PERF_LAYERS=` (your own layers: add `no_venue`, `no_water`, `no_ads`, `no_sky`,
`no_show`, `no_cutaway`, `no_haze` where missing — the harness file `perf_scene.gd` is play's: send the layer list as a
request on day one, or add layers through `FxWorld`'s own switch table in your files and ask play to expose them),
`--perf-census`, `--perf-shot-every-phase`, `make fx-bench`, `make show-perf-layer`, `make crowd-look`; play's
`make perf-play` (CP1) is the run at his window with his flags. Needs a display: the laptop (say when a window is
coming) or builder0's display (`make remote T=…`, GPU numbers NOT his: Iris Xe is ~2.3× faster; builder0 is for
draw-call and primitive counts and for parity shots, the laptop for GPU ms).

## Backlog (in order)

Every item: price by removal in one run FIRST, change, parity shots, `make remote T=check`, the number again; commit
with both numbers, commit, machine, window, sample.

- **R1. `make look-parity`: the picture, proven unchanged.** `tools/look_parity.py` compares two shot sets
  (`make remote T=skirmish-shots` desktop + phone at a fixed seed and delay, `arena-shots` for every arena, the garage
  tour's frames, the lineup sheet) pixel-wise with a stated tolerance (a per-pixel threshold and a changed-pixel share,
  e.g. ≤ 0.5 % of pixels over 8/255) and writes a diff image per pair; the first run is before/before (the noise floor
  from the fight's own variation at a fixed seed — if it is not ~0, pin what varies: `--tune=match.no_damage=1`, a
  scripted camera). Every later item ships with its parity line. **This is C16.6's instrument and the first thing you
  merge.**
- **R2. The base 8–9 ms, split.** Layers for everything no layer covers today (venue, crowd, water, sky+skyline, ads
  and live feed, show, haze, fog visual, cutaway) in one run at his window; a table in Status: GPU ms, draw calls,
  primitives per layer at 30 vehicles. Then the order of the rest of this backlog follows the table, not this list.
- **R3. Work that renders nothing he can see:** the live feed and ad viewports' rate and resolution against the pixels
  the screens cover at his pose (a 1024² viewport shown at 30 px is waste, not a look); FX systems updating with
  nothing alive; `Show` writes of unchanged values; the airship's catch-up stepping; any mesh drawn fully behind the
  cutaway. Pixel-equal by construction: R1 proves it.
- **R4. Fragment cost on the big surfaces:** the floor, water, stands — shader passes doing per-pixel work whose result
  is constant across the surface (move to vertex or to a uniform); normal maps on backdrop geometry that reads
  identical at his pose (R1 decides: if the diff is inside the tolerance it ships; if it reads flatter, it is a
  priced lever on the page, OFF).
- **R5. Draw calls and primitives:** the census at 30 vehicles; `StaticBatcher`/MultiMesh for anything that is still
  one draw per instance; the LOD threshold's actual effect at his window; vehicles' material count per hull.
- **R6. Glow and the pooled lights (3.3 + 1.5 ms):** what the glow pass costs at his window per level, and whether a
  level is doing work that the next level overwrites; the pooled lights' `light_floor` only where a light is lit. Glow
  stays ON (his round-5 word).
- **R7. `cpu_render_ms` 1.5–2.0 → ≤ 1.5:** what the draw submission spends on (materials switched per draw, the
  HUD's ~82 draws are hud's: file a request with the census).
- **R8. The page for him (only if R2–R6 leave the GPU over 10 ms at his window): the priced levers** — a render scale
  of 0.75–0.85 at 1080p (round 5 priced −2.8 ms), unlit stands if they read flatter, glow levels, the venue at a lower
  LOD when the camera is low — each with its GPU ms, a before/after pair at his pose, and the exact flag; a decision
  page with `db`, recorded in Status with the time its `db` was last read (C15.2). **Nothing on it ships before his tap.**

## How to verify

- `make remote T=check` green on your last commit (the sim baseline cannot move from your paths: if the wrapper's line
  says it did, stop and tell the orchestrator); `make look-parity` on every item, the diff images looked at.
- `make perf-scene` on the laptop at his window (`PERF_RES=1854x1011` or let the window maximise) with his flags,
  before and after each item; the layer method within one run for every cost you claim; play's `make perf-play`
  after CP1. Say when a window is coming (the lead's desktop).
- Draw calls, primitives, objects from `--perf-census` before/after; `make fx-bench` for any FX trick you touch;
  `make show-perf-layer` if the show is touched; `make crowd-look` if the crowd is.
- The shots and sheets you produce are looked at by you and listed in Status for the orchestrator.

## Don't touch

`game/ai/**`, `game/tactics/**` (brains), `game/match/**`, `game/tank/**`, `game/combat/**`, `game/arena/**`,
`game/units/**` (sim; `impact.gd`'s mesh via request or an adapter in your paths), `game/ui/**`, `game/control/**`,
`game/camera/**` (hud; `block_cutaway.gd` via request), `game/theme/audio/**`, `game/theme/fx/bench/**`,
`game/modes/**`, `game/audio/**`, `mk/fx.mk`'s perf targets, `mk/play.mk` (play), `mk/core.mk`, `game/main.gd`,
the `[physics]` keys of `project.godot` (sim).

## Waiting on the lead

Nothing at launch. R8's page, if it is needed, is a lead gate for the levers on it only.

## Status

_Live, 2026-10-02 evening (render-a2 session)._ Started from a green check: **`8318b9db`, builder0, 1856 passed / 0
failed, sim baseline `05df1d55ba49cde1` unmoved.**

### Plan (order; one-line reasons)

1. **R1 `make look-parity`** — the instrument everything else ships with. Decision: shots are taken by a harness in
   render's paths (`game/theme/fx/look_parity_shot.gd`, hooked from `FxWorld`) under `--fixed-fps 30`, frozen at exact
   match ticks (tree paused from inside the physics step + `Engine.time_scale = 0`), five poses per tick (the live
   camera with HUD, his pose over the centre, over the south base, a low look at the north venue, the overview). Why:
   `skirmish-shots` is timer-based, so two runs of the same code are different fights; a fixed-fps frozen frame is
   the only way the before/before floor can be ~0. Sets are per-machine (builder0's GPU rounds differently).
2. **R2 `make render-split`** — render's own within-run layer alternation over a new switch table
   (`RenderLayers`, 22 layers) because `perf_scene.gd` is play's; request to play to call the same table (below).
   GPU ms on the laptop at his window, counts on builder0. The table decides R3–R7's order.
3. R3 → R7 in the order R2's table gives; R8 only if the GPU is still > 10 ms at his window.

### R1 — the instrument (built; floor proven)

- **`make look-parity-ab`** is the one to ship with: ONE process, ONE frozen frame, every frame shot as the tree has it
  and again with `RenderLayers.BEFORE` layers swapped in (the shaders/settings as they were before each change), then
  diffed by `tools/look_parity.py` (a pixel changes above 8/255; a pair passes at ≤ 0.5 % of its pixels; diff images in
  `build/look-parity/diff/`). Nothing else can differ: not the fight, not the machine, not the GPU's clocks. Every render
  change adds its "before" layer (`ground_r15`, `fogvis_r15`, `haze_world_box`, `sky_r15`, `yards_r15`, `instanced_r15`).
- **`make look-parity-floor`** (two runs of the same tree): **PASS, 40 pairs, worst 0.020 %** (builder0, `a8f0eafb`),
  sumps + terminus × his window 1854×1011 + phone 1200×540 × live/his/base/venue/overview × calm/staged-effects.
- **A finding that shaped it:** the windowed skirmish is NOT repeatable across runs past first contact, even at
  `--fixed-fps 30` (same tree, builder0: 0.015 % at tick 150; 3–75 % at ticks 450/900 — different fights, "Bravo wiped
  out +4" vs "+5"). So parity freezes once before contact (tick 150) and **stages** the battle's effects on that frozen
  frame (fireballs, kills with fires → heat haze, lasers, pooled lights; `LookParityShot.stage`), letting only the FX
  clock run 20 fixed frames. Not render's to fix; flagged for the orchestrator (sim/play: the windowed fight diverges).
  The divergent tree was `ba7b3d3d` (= `d0d1b50f` + render's harness), **before sim's S1** (`dcd25cc5` is not an
  ancestor), so the threaded field is not the cause. No recordings (`--scripted` runs do not record). Reproduce:
  `make remote T="look-parity-floor LP_TICKS=150,450,900"` → `LOOK_PARITY_PAIR … live_t0450 FAIL` (the frames from the
  first run were overwritten by the next floor run).
- `make look-parity-shots LP_LABEL=x` + `make look-parity LP_BEFORE= LP_AFTER=` remain for cross-commit sets.
- builder0 renders a hidden vsync'd window at ~1 fps (795 frames in 800 s); the harness turns vsync off for itself.

### R1 — the parity verdict on the R3/R4 batch (builder0, staged frames, 40 pairs)

- **Per change on the tip** (`make look-parity-bisect`, each "before" layer alone vs the tree): **all six PASS on all 40
  pairs** — floor 0.017 %, fog sheet 0.020 %, haze box 0.093 %, sky 0.344 %, yard cells 0.022 %, instancer cells 0.022 %.
- **The real before** (the nine changed files checked out at `d0d1b50f`, everything else the tip, shot by the same
  harness — the orchestrator's tightening: a stack of reverts is a tree nobody shipped) **vs the tip: 33/40 PASS, 7 FAIL**,
  every fail a staged-effects frame, the fireballs paler in the tip (worst Terminus centre 2.40 %, the SAME numbers the
  stacked reference gave, so that reference was faithful).
- **Forward bisect** (`make look-parity-bisect-forward`: round 15 plus ONE change): ground and fog sheet PASS; haze box,
  sky priority, yard cells and instancer cells EACH flip the same fireballs (2.17 %, sky 0.85 %) — two of them purely
  opaque changes that cannot touch a fireball's pixels.
- **Cause, read from the code:** round 15's heat haze and the fireballs (`BurstSystem`) both carry the same world-sized
  `custom_aabb`, so both sort at exactly (0, 20, 0): **an exact depth tie**, settled by an unstable sort, i.e. by the
  render list's contents. Any change to the scene's objects — any stream's — can flip it. Drawn after the fireballs the
  haze composites a copy of them back over themselves (more saturated); drawn before, it doesn't. Round 15's order was
  never a defined picture. **The tip pins it: haze first among transparents (priority MAX)** — one of the two pictures
  round 15 could show. The 7 failing pairs are that tie, decided; nothing else differs. Flagged for the orchestrator as a
  C16.1 call (the other order is a one-line change: priority MIN).
- **Then the probe** (`make look-parity-probe LP_BEFORE=real_before`): NO single explicit order reproduces round 15's
  frames — haze MIN 5 fails, haze MAX 7, bursts max/min 8/7, decals max/min 7/7, fog sheet max/min 7/17. Round 15's
  changed pixels are REDDER (mean R 184 vs 154, G/B equal): an additive contribution, not the haze. SIX transparent FX
  systems share the world-sized box (bursts, decals, beams, tracers, order marks, haze) and tie at (0, 20, 0); round 15's
  picture there is one roll of an unstable sort. Time-boxed (~90 min). Shipped: haze FIRST (fire drawn over it), pinned by
  `test_fx_fires::test_the_haze_is_drawn_before_the_fire_it_bends`; the code site names the other order. The 5–7 staged
  pairs (1–2.4 %) vs round 15 are that tie; everything else is within the floor.
- **DECIDED (the orchestrator, under C16.1, 2026-10-03): an undefined order is a defect, not a look — pin all six, once.**
  `FxWorld.TRANSPARENT_ORDER`, back to front: ground decals (4), order marks (3), heat haze (2), beams and tracers (1),
  everything else (0), the fire last (bursts −1): nothing is ever drawn over a fireball. Read back by
  `test_fx_fires::test_the_transparent_effects_have_one_defined_order`. **The staged-frame pairs that differ from round
  15 are round 15's undefined tie, now defined** (numbers vs the real before: below, from the run at the green hash).
  For his playtest: the only visible effect is that explosions are never dimmed or re-tinted by the haze or marks.
- The sky change's 0.3 % on the venue pose is not the sky: the diff sits on the HUD's wall-clock timestamp and an ad
  screen's content (real-time driven).
- Parity tools now: `look-parity-floor`, `look-parity-ab` (stacked "before" layers), `look-parity-bisect` (each alone vs
  the tip), `look-parity-bisect-forward` (each alone on round 15), `look-parity-shots` + `look-parity` (any two sets).

### R2 — the split (instrument built; the table)

`make render-split` alternates `all` with each `RenderLayers` layer on ONE frozen frame (fixed-fps, tick 150, the
staged effects above), GPU ms as the phase median. A live-fight split was useless for before/after: the same layers read
glow 2.5 vs 4.0 ms and the fog sheet 0.4 vs 1.9 ms in two runs (the camera moves). **Laptop (his UHD 620), his window
1854×1011, load ~5–6 from other agents, `724c51e2`-era tree, frozen staged frame (tick 450 live-camera frame for this
table), 3 cycles; GPU all = 18.0 ms:**

| layer | GPU ms | draws | prims | note |
|---|---|---|---|---|
| no_glow | 3.50 | 0 | 0 | his round-5 word: stays |
| no_venue | 2.85 | 4 | 25.9 k | stands 2.35 + crowd 0.56 (+ screens, signs) |
| no_pool_lights | 1.91 (1.5 staged) | 0 | 0 | **1.42 of it = extra passes over STATIC geometry** (Compatibility re-draws a whole object per light touching its box) |
| no_ground | 1.13 | 1 | 6.5 k | one plane, ~6 fetches/pixel |
| no_effects | 1.06 | 9 | 2.4 k | |
| no_env_fog | 0.95 | 0 | 0 | per-fragment fog in every material |
| no_haze | 0.69 | 1 | — | the screen copy |
| no_fogvis | 0.44 | 1 | — | (0.4–1.9 live before R3) |
| no_hud | 0.37 | 123 | 4.6 k | 2 823 objects; **hud's** |
| no_show | 0.31 | 0 | 0 | |
| no_sky | 0.29 | 3 | 1.3 k | |
| no_screens / no_airship / no_live_feed / no_vehicles / no_crowd-only | ≤ 0.2 each | | | vehicles 14 draws, 0.08 ms |
| no_water / no_blocks / no_perimeter / no_shadows / no_ads | ≈ 0 (noise ±0.3) | | | |

Order this gave the rest of the backlog: the light passes (R3/R5), the fog sheet and haze (R3), the sky's draw order
(R3), the floor's ALU (R4); glow/venue/fog are the look → R8's page.

### R3–R4 — done so far (each A/B within one frozen run, laptop, his window, load 5–6; parity: `look-parity-ab`)

| change | GPU (A/B vs round 15) | draws | parity |
|---|---|---|---|
| fog-of-war sheet leaves at v ≥ 0.95 (exactly the alpha-0 case) | **−0.47 ms** (two runs: 0.39, 0.47) | 0 | calm frames PASS (builder0 `a8f0eafb`) |
| floor: band normals per vertex (flat), paint math only where paint is, one flood_map fetch | −0.11 / −0.28 ms | 0 | PASS |
| sky dome, skyline, city ground drawn last (render priority max) | −0.16 / −0.33 ms | 0 | pending (`sky_r15`) |
| heat haze box = its quads (no screen copy when off screen) | 0 on a frame with haze in view; the copy (0.6–0.9 ms) when out of view | 0 | **FAILED twice, then fixed** (fireballs dimmer on 6–8/40 staged frames, 0.5–3.9 %): the tight box moved the haze in the transparent sort, so it drew after nearby fireballs and painted the pre-transparent screen copy over them. First fix used priority MIN, which is LAST ("higher priority renders earlier", Godot docs) and failed the same way; now MAX = first, round 15's accidental order stated. Re-check pending |
| yard props per 96 m cell (LightCells): containers, barricades, floodlights, sign posts, wrecks | −0.17 / −0.24 ms (yards' light passes 0.71 → 0.21) | +11 | pending (`yards_r15`) |
| StaticInstancer per 96 m cell (stands, towers, gates) | **−0.65 ms** | +7 | pending (`instanced_r15`); prims moved +37 k — LOD per cell? parity decides |

Measured and NOT done: stands' normal map / ORM textures (−0.07 / −0.13 ms: null, the stands keep them); the haze's
mipmapped screen texture (−0.01: null, reverted); the floor drawn last (0.10 ms, coplanar-decal risk: not worth it); a
write cache in `Show.apply()` (its counts are a designed, tested cost model (`writes_for`) and most channels are functions
of time that change every frame: little to save, real test churn).

### R8 — the levers page (LEAD GATE, waiting on his taps)

**https://claude.ai/artifact/PMFmmgGgQJ5QdfS5jh9pDG** (`db` `decisions/<lever>` = {decision: on|off|try, words, at};
**read EMPTY 2026-10-03 ~00:30 UTC** by render right after publishing). Built by `tools/render_lever_page.py` from
`make lever-shots` (builder0, `936fdb26`, the Sumps' frozen staged frame, his window: live / his / venue poses, now
against the lever). Every lever is OFF in the game; to play one: `make skirmish SKIRMISH_FLAGS=--render-levers=<name>`.
Prices: laptop, his window, frozen staged frame within one run (`make render-split`), GPU all = 16.0 ms:

| lever | GPU saved | pixels changed (live pose) |
|---|---|---|
| `scale_075` (3D at 75 % of the lines) | 3.48 ms | 30–36 % |
| `scale_085` | 1.48 ms | (same family, softer) |
| `no_env_fog` | 1.05 ms | up to 48 % |
| `lights_2` (2 pooled lights, not 4) | 0.62 ms | **0.01 % on this frame** — the frame barely shows it; it shows in bigger fights |
| `no_haze` | 0.46 ms | ≤ 1.7 % |
| `crowd_medium` | 0.31 ms | ≤ 2.5 % (venue) |
| `unlit_stands` | 0.23 ms | ≤ 12 % (base / venue) |
| glow level 5 off | −0.22 (nothing) | dropped |
| glow off | 2.91 ms | NOT offered: his round-5 word keeps glow |

The 10 ms budget needs about 6 ms of these on top of the pixel-equal work; the page keeps a running total of what he
turns on.

### Check

- **`de655837`: `make check` on builder0 — 1889 passed / 0 failed, sim baseline `05df1d55ba49cde1` unmoved**, determinism
  `762a0576f944f5b7` (the `make -k` run's exit 2 was the look-parity-ab step, not the check).

### Requests to other streams

- **play** (sent to the orchestrator 2026-10-02): a default arm in `perf_scene.gd`'s `_apply` that hands unknown
  phases to `RenderLayers.apply(get_tree(), phase)` / `RenderLayers.restore(undo)`, so `PERF_LAYERS=no_water,…` works
  in perf-scene and perf-play. **Done by play, on main at CP1 (`7100e3fe`).**
- **hud** (sent to the orchestrator 2026-10-02): the HUD is 123 draw calls, 2 823 canvas objects, 0.79 ms of draw
  submission and 0.37 ms GPU at his window (frozen `no_hud`): worth batching per-element CanvasItems.
- **sim/play** (FYI, sent): the windowed skirmish diverges between runs after contact (R1 above).

### What to playtest (the lead)

- `make skirmish` as usual: it should look as before (that is the point); the GPU work is ~2 ms lighter at his window.
  The one deliberate change: the transparent effects have a defined order, so an explosion is never dimmed or re-tinted
  by heat shimmer or an order mark (round 15 left that to chance).
- The levers, one at a time, only if he wants to see a page item in motion:
  `make skirmish SKIRMISH_FLAGS=--render-levers=scale_085` (or `lights_2`, `scale_075`, `no_env_fog`, `no_haze`,
  `crowd_medium`, `unlit_stands`; comma-join to combine).

### Merge notes (shared files)

- `tests/test_arena_prop_parity.gd` (arena's/sim's test): `_instances()` reads a yard draw's kind from its `kind` meta
  (yard draws are per cell since R3) — one line.
- `tests/test_assets_containers.gd`, `tests/test_render_arena_kit_props.gd`: the yards' contract is now one MultiMesh per
  kind per 96 m cell (`LightCells`), every instance drawn once.
- `game/theme/fx/fx_quality.gd`: `value()` routes through `RenderLevers.adjust` (all levers off by default).
- `game/theme/fx/shaders/reference/*`: frozen round-15 shader copies for the A/B layers (not used in play; small).
- New: `tools/look_parity.py`, `tools/render_lever_page.py`, `game/theme/arena_kit/light_cells.gd`,
  `game/theme/fx/{look_parity_shot,render_layers,render_split,render_levers}.gd`, `mk/show.mk` targets
  (`look-parity-*`, `render-split`, `lever-shots`). No `project.godot` edit. `game/main.gd` untouched.

### Next steps

- R5/R7 remaining: the crowd's light passes (one MultiMesh around the arena; split per side keeping the tier's
  visible set — ~0.1–0.2 ms), the city blocks' (0.17) and terrain's (0.15) light passes; `no_hud` re-read after hud's
  batch lands (they will say).
- The six FX systems' shared world box is a latent order lottery for every transparent effect (not only the haze); a
  defined order for all of them is a deliberate change of look and would go on a page.
- Read the levers page's `db` again before the close.

### Windows on his desktop

- 2026-10-02 ~21:15: `make render-split` (R2, his window 1854×1011, ~4 min of a skirmish window) on the laptop.

