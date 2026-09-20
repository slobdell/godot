# Stream: show (the arena as a light show — fixtures, channels, patches and cues over the venue's emissive art)

> Read `HANDOFF.md`, [orientation.md](../orientation.md), [game_design.md](../game_design.md) *Round 9 addition: the
> arena as a light show*, [workstreams.md](../workstreams.md) *Round 9: the seven streams* (your row, the ownership
> carve-outs, **contract S6**, the RAM note), [art_direction.md](../art_direction.md) (the vibe), and
> [`streams/references/fx_tricks.md`](references/fx_tricks.md) (contract M1: the frame budget). Then read
> **`/tmp/widget2.md`** — the breathing-conductors HUD spec the lead handed over as the reference for *how*: bake the
> expensive part once, animate only a scalar. Its §3, §5 and §8 are this stream's architecture.
>
> **You own:** `game/theme/show/` (new: fixtures, channels, patches, cues, the show director), `mk/show.mk` (new),
> `_agents/lighting.md` (new), and an additive `show` key per arena in `arenas/*.json` (scale reviews the schema).
> **Carve-outs from feel's `game/theme/**`, additive only, feel reviews the look at merge:** the emission paths of
> `CityBlock` (`game/theme/arena_kit/city/city_block.gd` + `game/theme/fx/shaders/city_block.gdshader`), the
> perimeter rim in `arena_dressing.gd` `_build_polygon_venue` (the neon on top of the wall), `NeonSigns`
> (`game/theme/arena_kit/ads/neon_signs.gd` + `neon_sign.gdshader`), the floodlight pools (`_glow_multimesh`,
> `splat.gdshader`), and `CyberMaterials.neon()` (`game/theme/fx/shaders/neon.gdshader`). A **hook** that a fixture
> exposes — never a restyle. **Every Godot process of yours runs on builder0** (`make remote T=…`): the laptop had
> ~2.2 GB free when you were added as the eighth stream.

## The lead's direction (2026-09-20)

Enqueued mid-round, his words verbatim ([game_design.md](../game_design.md) *Round 9 addition*):

> *"The point is not the widget itself, it's the concept of creating efficient graphics effects in an efficient manner
> (i.e. we can get away with nice effects that bring the arena to life without costing much in terms of frame rate).
> Basically the new Terminus map is AWESOME and really cool. But it also looks pretty retro for a game. We could easily
> bring these figures to life by making the lit edges breathe and glow. These were also set up as looking like city
> buildings, but since this is an arena theme, we can also fade in and out different lights on those buildings. But if
> we want to make this really cool, rather than just randomly having breathing lights, we should immerse ourselves in
> this whole arena sporting event, and ideally we could create lighting patterns that were consistent with an
> entertainment event (i.e. imagine light shows in Las Vegas). Similarly, the arena edges right now are just a dull neon
> purple. Those could easily have a breathing effect as well."*

> *"Note that for the buildings I'm obviously talking about the Terminus case, but in theory these blocks should be
> highly re-usable, so the point is that we'd want abstract modules for creating light effects. You're better than me at
> identifying what those abstractions are exactly, but if our whole theme is a sporting / entertainment arena then we
> could probably account for all sorts of abstractions for creating lighting effects (i.e. stadiums also have spotlights
> and signage all along the rafters, we might be able to later add lighting effects to things like roads or bridges,
> etc. I would give the guidance to make it beautiful, with the idea that we can easily create desirable lighting
> effects at low compute cost using whatever programming tricks we can."*

The third passage in that section — the camera ending up inside a Terminus block — is **control's**, not yours; it is
quoted there and in control's brief. Your one contract with it: a cue must not fight control's block cutaway (S6).

**The bar is his: "make it beautiful."** He judges the look from frames at his pose; the frame time is the check.

### The abstractions (the orchestrator's answer; your `_agents/lighting.md` is the reference version)

Stage lighting already has the vocabulary, and it maps onto what the Compatibility renderer does cheaply:

- **Fixture.** Anything emissive that can be driven: a block's lit edges and window grid, the perimeter rim, a
  floodlight pool, a sign, a tower beam; later a road stripe or a bridge. A fixture is **not a light** — it is an
  emissive surface on an existing mesh or MultiMesh instance, driven through a material uniform or per-instance custom
  data. Adding a fixture adds **zero draw calls and zero real lights**.
- **Channel.** A named scalar or colour signal computed **once per frame on the CPU** and pushed as one uniform or one
  instance-data write: `breathe(period, phase)`, `chase`, `strobe`, `sweep(direction, speed)`, `cycle`. A show has
  tens of channels, never one per fixture. Periods 10–25 s, pairwise incommensurate, phases scattered (widget spec §3).
- **Patch.** Which fixtures listen to which channels, **in data** per arena, so the Terminus, the yard and a future
  bridge are patched without code.
- **Cue.** A programme of channel settings bound to **match state** (L5 `MatchMood`: `lull`, `skirmish`, `battle`,
  `last_stand`, `victory`, `defeat`) and K5 events. **This is what makes it an entertainment event rather than random
  breathing.** Idle is the slow breathe; the cues are the show.
- **The efficiency rule (widget spec §5, §8):** bake the expensive part once, animate only a scalar. Never a blur per
  frame; glow halos are baked sprites or emissive geometry; the breathing lives in the modulation value. Bake at full
  opacity, modulate at draw; keep a ceiling below full so the show never competes with the HUD's alerts or team accents;
  the *core* of a fixture never goes fully dark (a rim that vanishes reads as broken, not idle).
- **Visual only.** The show reads the match and never writes it; frame time, never the tick; **pre-registered: the sim
  hash does not move.**

## Where things stand (`main` at `a1c2ab24`, 2026-09-20; every number carries its commit and machine)

**The venue's emissive art is already built the cheap way — nothing here needs a new draw call.** What is missing is
that nothing *drives* it: every emissive surface either sits at a constant or runs its own private `TIME` wobble.

| Surface | Where | How it is lit today | The hook you add |
|---|---|---|---|
| **The Terminus blocks** (8 `block` props on `arenas/terminus.json`, e.g. `{"type": "block", "position": [40, 0], "tiers": 3, "neon": "cyan", "seed": 11}`) | `CityBlock.build()` `city_block.gd:98–` — one `ArrayMesh`, **two surfaces, two draws whatever the size** (`:9–10`); surface 0 the facade, surface 1 the neon band over the shopfronts (`NEON_BAND` `:23`). `COLOR.r` tags the part, `COLOR.g` the block's seed (`city_block.gdshader:6–7`) | Facade windows: `EMISSION = city_windows(...) * pane` (`city_block.gdshader:65`), a static pattern from `city_windows.gdshaderinc` at `window_level = 1.4` (`:16`). Shopfronts: a warm constant `0.35` (`:71`). Chamfers and bevels: an `edge` **albedo**, not an emission (`:74–80`) — **the "lit edges" he sees are the pale chamfer catching the moon, so "make the edges breathe" means giving them an emissive term they do not yet have** | `facade_material()` is **one static `ShaderMaterial` shared by every block** (`city_block.gd:56–60`), so a uniform on it drives all 8 at once and a per-block phase must come from `block_seed`, already in the vertex colour. Add uniforms `show_edge` (colour × energy), `show_window` (a level multiplier), `show_seed_spread`; write them once per frame from the channel engine |
| **The perimeter rim** ("a dull neon purple") | `arena_dressing.gd:200–204`: a `top_quad` and a thin box per edge, `CyberMaterials.neon(PURPLE, 0.9, 0.03)` and `neon(PURPLE, 4.0, 0.05)`; `StaticBatcher.merge(segment)` (`:205`) | `neon.gdshader`: `flicker` and a `breathe = 0.15` at `breathe_speed = 0.6` from `TIME` with a phase from world position (`neon.gdshader:2–13`) — a fixed 0.6 rad/s wobble on every neon prop in the game | `CyberMaterials.neon()` **caches one material per (colour, energy, flicker)** (`cyber_materials.gd:35–45`), so the rim's two materials are shared by every edge of the hexagon: two uniform writes drive the whole ring. Add a `show_level` uniform (default 1.0 = today) and a `show_color` override; the six edges get per-edge phase from position exactly as the flicker already does |
| **Neon signs** | `NeonSigns.build()` `neon_signs.gd:18–47`: **one MultiMesh for every sign**, `use_colors` + `use_custom_data` (`:28–29`); `INSTANCE_CUSTOM.r` = atlas row, `.g` = flicker seed (`neon_sign.gdshader:2–3`) | buzz + a random stutter from `TIME` (`neon_sign.gdshader:24–29`), `energy = 3.6` uniform | `.b` and `.a` of `INSTANCE_CUSTOM` are free: a channel index and a per-sign phase. `set_instance_custom_data` per sign at patch time; a small `channels` uniform array (or a 1×N texture) read by index per frame. Headless renderers drop instance data (`:44–45`): tests read `placements` from the meta as the crowd test does |
| **Floodlight pools, tower beam pools** | `_build_perimeter` `arena_dressing.gd:465–518` and `_build_tower` `:521–576`: `_glow_multimesh` (`:579`, "static additive glow quads, reuses the projectile splat shader") | `splat.gdshader`, `pool_colors` baked into instance colour (`:510`) | Instance colour is the intensity: one `set_instance_color` per pool per frame is 20-odd writes, or a `show_level` uniform on the splat material |
| **The kit's `floodlight` and `sign` props** (2 + 2 on the Terminus) | `KitYard.custom_data()` `kit_yard.gd:80–84`: `INSTANCE_CUSTOM` carries the sign's row + flicker seed, a pool's intensity | as above | same as the signs |
| **Ad screens** (4 on the Terminus) | `AdBroadcast` `ad_broadcast.gd:3–8`: every screen on a channel shares one material; **each ad's average colour already becomes the light the screens throw on the ground** (`_light`, `light_color()` `:223`, `ad_spill.gdshader` `color`/`energy` uniforms) | live | **This is a fixture that already exists** — the spill colour is a channel with one publisher. Read it, do not duplicate it; a cue may ask the channel to `post_live` (K5 already does on kills) |
| **The ground** | `arena_ground.gdshaderinc`'s hazard band, `flood_map` (`arena_dressing.gd:285–294`, `:448`) | a baked light map | Stretch: a `show_level` on the band |

**What already reacts to the match, and the pattern to copy for cues:** `FxWorld.spectacle(position, weight)`
(`fx_world.gd:13–14`, emitted from `explosion()` `:319`: 1.0 a kill, 0.15 a hit) → `CrowdSystem.react()` lifts
`excitement` and writes `event_position` / `excitement` shader parameters once per `_process`
(`tests/test_fx_crowd.gd:24–37` is the headless test shape: call `react`, call `_process(dt)`, read the parameter).
`MatchMood` (`game/audio/match_mood.gd`) is L5: `current() -> {intensity 0..1, state, reasons}` (`:120–122`), states
`lull/skirmish/battle/last_stand/victory/defeat` (`:22`), `state_changed(mood)` signal (`:19`), a heat with a 7 s
half-life (`:25–35`). It is **instantiated by the announcer booth** (`announcer_booth.gd:91`, `MatchMood.new(pov)`) and
the music director *follows* it (`music_director.gd:13`, `follow(mood)`); `crowd_voice.gd` also reads one. **Find who
owns the mood in a plain `make skirmish` with no `--music`** before you build on it — if no booth is attached, the show
may need to be the thing that instantiates and advances one from the K5 stream (it is deterministic over events, has
no clock, and never reads the simulation: `match_mood.gd:6–9`).

**Frame time, not the tick.** `FxWorld._process(delta)` keeps `now += delta` (`fx_world.gd:154–155`) and every FX
system updates from it; shaders use `TIME`. The show does the same: a `Show` node in `_process`, its clock frame time.
Nothing in `game/match/`, `game/tank/` or `game/ai/` may read it. The `Show` node lives under the theme's FxWorld or
the dressing, whichever exists in every mode that draws the arena (`--skirmish`, `--match` with a display, galleries).

**The budget, M1** ([fx_tricks.md](references/fx_tricks.md)): the lead's target is a **locked 30 fps at 1080p with 30
a side**, judged on `p99_ms` in a `--perf-capped` run; capacity in an uncapped run. Measure with `make perf-scene`
(`mk/fx.mk:64`): a live 34-a-side skirmish, per-layer costs, draw calls, primitives, pooled and real lights, output
`build/perf-scene.json` + `PERF_SCENE` lines. Labelled baselines and their provenance are in
`streams/references/perf/README.md` — the latest venue row is `feel-r6-venue-1080.json` at `cf6b079a` (laptop, GPU
18.45 ms, venue 3.54). **Take your own BEFORE on builder0 at your branch point before the first fixture lands**, and
say the machine on every row: builder0's Iris Xe is ~2.3× the laptop's GPU and 2.75× its CPU; a builder0 number is not
a number about the game he plays, but a builder0 *delta* between two runs on the same tree is honest.

**Renderer facts you design around** (orientation.md trip-ups 43–45): dark glossy floors under a black sky render
black blotches (roughness ≥ 0.5, `reflected_light_source = disabled`); a directional light's PSSM shadows redraw every
caster per split (orthogonal, 110 m); **the Compatibility renderer does not batch 3D draws** — a prop of 23 boxes is 23
draws, which is why every surface above is one mesh or one MultiMesh, and why your fixtures ride existing draws rather
than adding quads. `MultiMesh.use_custom_data` works on Compatibility (`arena_dressing.gd:591`, `neon_signs.gd:29`,
`underglow_system.gd:41`, `container_yard.gd:117` all use it).

**Four rules from feel, the materials' owner (2026-09-20), and they are hard rules, not craft:**
1. **If a value differs between instances it is per-instance custom data on the MultiMesh** (`use_custom_data`,
   already how the crowd is driven; zero draw calls, zero lights): window grids, block edges out of phase. **If it is
   one number for the whole fixture it is a material uniform**, and `CyberMaterials.neon()` is the place: the
   perimeter rim, a spotlight pool, the arena-wide wash. **show never adds a MultiMesh or a light to get variation a
   custom-data channel could carry.** (For the blocks, which are one mesh each and not a MultiMesh, the per-block
   phase is `block_seed` in the vertex colour — the same idea, already in the data.)
2. **`AdBroadcast`'s ad channel already drives the ground wash from the screen's average colour** (`light_color()`,
   the spill), so an arena-wide light cue is a **second writer to the same perceived quantity**; two writers look like
   flicker nobody can reproduce. **Decide the owner in `_agents/lighting.md` before code.** Recommended: the show
   director owns the wash and reads the ad colour as one input.
3. **`make perf-scene` counts "Too many instances using shader instance variables" errors as a first-class number**
   (fx_tricks.md: 246 per run before the FX rework) because the venue hit that ceiling before. Read that counter and
   the `instance_buffer_pos` count on every before/after, not only the frame time; a fixture that pushes a shader over
   the instance-uniform ceiling fails M1 even at the same GPU ms.
4. **Message feel (`godot-feel-e4`) before designing any hook**; feel gives the same rules in the materials' own terms
   and knows which uniforms and instance slots are already spoken for.

**The arena JSON:** `Arena.validate()` (`arena.gd:650–`) checks the keys it knows and **does not reject unknown
top-level keys**, so an additive `show` key loads today; your job is to validate *your* key's shape and to return a
readable error for a bad patch (a missing `show` key = today's static look, asserted for every shipped layout). scale
owns `arenas/` this round and reviews the schema; write the key, message scale, do not touch the loader beyond the
call into your validator.

**The look, from art direction** ([art_direction.md](../art_direction.md)): *Death Race is the spine, Mad Max the
build method, Blade Runner the light.* **Neon lives behind or inside things, never outlines on everything, never a
cartoon glow** (`:42`, `:56`). **Venue lighting must not read as a team** — the signs' palette is warm and violet, never
the team cyan or magenta (`neon_signs.gd:4–5`); a victory sweep in the winner's colour is the one deliberate exception
and it is a *cue*, not a fixture default. The Syndicate is the immaculate ivory tower and owns the sky (the airship);
the gangs are the crowd favourite. "Lit well enough to read the fight on a phone; the neon is mood, not the only
light" (`:72–73`).

## Backlog (in order)

Tests first where a thing is testable headless (channel maths, patches, cue selection, draw-call counts); frames looked
at for everything visible; every number with commit and machine.

0. **Hard rules for every item below** (feel's, above): per-instance variation is custom data, whole-fixture values
   are a uniform, never a new MultiMesh or a light for variation a channel could carry; **one owner for the ground
   wash**, decided in `lighting.md` before code; the instance-uniform error counters are read on every before/after;
   **message feel before designing a hook.**

1. **`_agents/lighting.md` — the vocabulary, written BEFORE code.** One page: fixture / channel / patch / cue, the
   efficiency rules (widget spec §3, §5, §8 restated for a 3D venue), **the custom-data-vs-uniform rule**, the hook a
   fixture exposes, **who owns the ground wash** (the show director, reading `AdBroadcast.light_color()` as one input,
   unless feel argues otherwise), the JSON shape of a patch and a cue, and the list of fixtures that exist today (the
   table above) with the ones you will drive this round marked. Send it to the orchestrator and to feel; feel reads
   it because its materials grow the hooks. **A fixture is
   whatever exposes the hook** — write it so a road stripe or a bridge next round is a patch, not a new abstraction.

2. **The channel engine** (`game/theme/show/show.gd`, `channels.gd`): a `Show` node computing N channels per frame
   from frame time, each channel a small closed-form programme (`breathe`, `chase`, `strobe`, `sweep`, `cycle`, and
   `hold`), each with period, phase, floor and ceiling. Headless tests: (a) channel values are a pure function of time
   (same `t`, same value; no per-frame state beyond `t`); (b) the periods a patch declares are pairwise incommensurate
   within a tolerance and their phases are spread — the widget spec's rule, so a bank of fixtures never pulses in sync
   or visibly loops; (c) the per-frame cost is `O(channels)`, independent of fixture count — assert the number of
   uniform/instance writes per frame equals the number of *channels bound*, not fixtures; (d) floor > 0 for any
   channel driving a core surface (the rim never goes fully dark). No `Time.get_ticks_*` inside a decision; the show
   is visual only and this test is what keeps it that way: assert nothing under `game/theme/show/` references `Match`
   state except through `MatchMood.current()` and K5 events.

3. **The first fixtures: the Terminus blocks and the perimeter rim.** (a) `city_block.gdshader` gains an emissive
   edge term on the chamfers/bevels (today a pale albedo, `:74–80`) and a level multiplier on the windows and
   shopfronts, all driven by uniforms on the one shared `facade_material()`, with per-block phase from `block_seed`
   so eight blocks breathe on eight clocks from **one** material write. Keep the facade's look at channel level 1.0
   identical to today (a screenshot diff at his pose is the test). (b) `neon.gdshader` gains `show_level` and
   `show_color`; the rim's two cached materials (`arena_dressing.gd:200–204`) breathe instead of holding a flat purple,
   per-edge phase from position as the flicker already does. **Measure before and after** with
   `make remote T=perf-scene` on builder0 (same tree, same seed): draw calls, primitives, **real lights** and pooled
   lights must not rise; **the "Too many instances using shader instance variables" and `instance_buffer_pos` error
   counts must not rise**; GPU ms delta reported. **Frames at the lead's pose** — 21° pitch, FOV 35, 49 m (NOT 12°,
   the camera he rejected) — on `terminus` and `yard`, before and after, in `build/show/`; send the strip to the
   orchestrator **now, not at the end of the round**: the lead judges the look and a wrong direction costs a day per
   day it is not seen.

4. **Patches as data.** A `show` key per arena (`arenas/<name>.json`): channels (name, programme, period, phase,
   floor, ceiling) and patches (fixture selector → channel). Validated by your validator with readable errors; a
   missing key = today's static look, asserted for every shipped layout (lesson 3: derive the list from `arenas/`,
   never hard-code it). Terminus and yard patched; `make show-report ARENA=<name>` prints the resolved patch (every
   knob it resolved to, lesson 44). Message scale with the schema.

5. **Cues from the match** (`cues.gd`): a cue is a data programme — a set of channel overrides with an attack and a
   release — selected from `MatchMood.current().state` and fired by K5 events (`FxWorld.spectacle` for kills/hits is
   the existing bus; `MatchMood.state_changed` for states). The set for this round, each a frame or short capture:
   **FIGHT** — house lights down, the rim and towers up (the moment the loading screen drops); **lull** — the slow
   breathe; **battle** — faster, brighter, a chase along the rim; **a kill** — a ripple outward across the nearest
   blocks from the kill position (the crowd's `event_position` pattern); **last stand** — a strobe/pulse concentrated at
   the losing base's edges; **victory** — a sweep around the rim to the winner's colour (the one team-coloured cue),
   **defeat** — the house going cold. Attack/release so cues never pop; a cue never drives a channel outside its
   floor/ceiling. Headless test: given a scripted mood/event sequence, the selected cue and channel values at each step.
   **Contract with control (S6):** if control fades or cuts a block for the camera, your cue must not fight it — ask
   control what signal it exposes and read it; do not both write the same uniform.

6. **Signage and rafter/tower beams as baked-glow fixtures.** Tower beams (`_build_tower`) and the signs get a
   channel; a "rafter" strip of sign-like fixtures along the stands' top rail is a patch over `NeonSigns`, not new
   geometry. Where a halo is wanted (a beam's bloom, a sign's glow), it is a **baked sprite or emissive quad in the
   existing MultiMesh**, modulated per instance — never a per-frame blur, never a `Light3D`.

7. **Stretch.** (a) The Syndicate airship's screen as a fixture on an ad channel (feel builds the airship; you patch
   it). (b) One fixture that is not a building or a wall — a road stripe or the plaza's kerb line on the Terminus —
   to prove the abstraction generalises without new code. (c) A `show` view in `make arena-kit-gallery` so the lead
   can see a cue on demand.

## How to verify

- **Every Godot process on builder0.** `make remote T=perf-scene` (before/after, same tree, same seed; report draw
  calls, primitives, real lights, GPU ms with the commit and "builder0"); `make remote T=check` before any readiness
  claim (read the wrapper's `>> remote: make check exited <N>` and the runner's `N passed, M failed`, never a shell
  exit code through a pipe; one `make remote` per worktree at a time).
- **`sim-baseline` green on the current `main` hash** on your branch: the pre-registered proof that the show never
  reached the simulation. If it moves, that is information about something else — say so, do not re-record.
- **Frames** in `build/show/`: his pose (21°/FOV 35/49 m) on `terminus` and `yard`, before and after each visible
  item, plus one frame per cue; `make remote T=camera-looks` (control's tool, `mk/command.mk:163`) and
  `make arena-kit-gallery VIEWS=venue SHAPE=hexagon` (`mk/assets.mk:170`) are the existing frame tools. Look at them.
- **A human is the only check for "beautiful"** (lesson 19): put the first strip in front of the orchestrator the day
  it exists; the lead's reaction is the acceptance test, and it is cheaper to redirect after one fixture than after
  seven.
- Headless tests under `tests/test_show_*.gd` (`extends TestCase`, the crowd test's shape); `make show-report`.

## Don't touch

- The simulation: `game/match/`, `game/tank/`, `game/ai/`, `game/units/`, `game/tactics/`. Nothing here reads the
  show; the show reads only `MatchMood` and K5 events.
- feel's paths beyond the additive hooks listed above; the look of any surface at channel level 1.0 stays what feel
  shipped. No new Meshy, no new textures the show does not bake itself.
- The roster numbers and `arenas/` beyond your `show` key (scale's); control's camera, HUD and cutaway; metrics' tool;
  the shared files (`project.godot`, `Makefile`, `mk/core.mk`) except a one-line `include mk/show.mk`, listed in merge
  notes.
- Real lights. If a design wants an `OmniLight3D`, the design is wrong for this renderer; find the emissive form.

## Waiting on the lead

- **The look.** Nothing blocks on it; the first before/after strip goes to him via the orchestrator as soon as item 3
  renders, and his reaction steers items 5–6.

## Requests to other streams

- **feel:** **message feel first, before designing any hook** — feel owns the materials and knows which uniforms and
  instance slots are spoken for. Then review at merge (the edge emission on `city_block.gdshader`,
  `show_level`/`show_color` on `neon.gdshader`, the free `INSTANCE_CUSTOM` slots on the signs); confirm the level-1.0
  look is unchanged; agree the ground-wash owner. Tell show
  the airship's screen material when it exists.
- **scale:** review the `show` key's schema and its validator call; confirm `Arena.validate` stays yours.
- **control:** the block cutaway's signal, so a cue never fights it.

## Status

_Updated 2026-09-20 (overnight). Branch point `e3501ef9`. **Items 1-6 are built and green locally; the lead gate
(the frame strip) is the only thing outstanding, and it is waiting on builder0.**_

### Where it stands

| item | state | commit |
|---|---|---|
| 0. Hard rules | done, and they are written down rather than remembered | `415f9e09` |
| 1. `_agents/lighting.md` before code | **done**, reviewed by feel and control, their answers folded in with reasons | `415f9e09` |
| 2. The channel engine | **done** | `a3e86c01` |
| 3. First fixtures (Terminus blocks, perimeter rim) | **code done**; before/after perf and the frame strip pending builder0 | `a3e86c01` |
| 4. Patches as data | **done** (`terminus`, `yard`; `make show-report`) | `a3e86c01` |
| 5. Cues from the match | **done** (7 state cues + the kill ripple) | `a3e86c01` |
| 6. Signage, pools, tower beams | **done** | `b3bc7896` |
| 7. Stretch | not started (airship screen, a non-building fixture, a gallery view) | — |

**Local, laptop, at `b3bc7896`: 72 passed, 0 failed** on `--filter=show`; arena 79/0, fx 111/0, theme 39/0, crowd
16/0; **all touched scripts parse-checked locally** (metrics' lesson 157 — a remote-green commit is not
parse-checked, so nothing here is called green off a remote run alone).

**`make show-report`, laptop, `b3bc7896`:** terminus **7 uniform writes per frame from 7 patch entries**, yard **4
from 4**. That is the architecture's whole claim, and it is O(patch entries), never O(instances): eight blocks, six
rim edges, every sign in the venue and every floodlight pool each cost **one** write, because the per-instance
desync is a phase the mesh already carries.

### The design, in one paragraph

A channel packs into **one `vec4`** — `(floor, span, clock, sharpness)` — and **one function**,
`show_value(chan, phase) = chan.x + chan.y * pow(max(0.5 + 0.5*sin(chan.z + phase), 1e-4), chan.w)`, lives in
`game/theme/fx/shaders/show.gdshaderinc` and, identically, in `ShowChannel.level_at()`. A test asserts the two
bodies are the same line after normalising language differences, so the headless tests keep describing what the
player sees. `phase` is the per-instance offset and never comes from the CPU: a block's seed in `COLOR.g`, the rim's
angle in world space, a sign's `INSTANCE_CUSTOM.a`, a pool's `.y`, a tower's lamp angle. Everything else — programmes,
patches, cues — is data.

### Decided overnight (the lead asleep; most reversible option taken, reason recorded)

1. **The `Show` mounts itself** under the scene tree root (`FxWorld`'s own pattern) and follows `Arena.active`,
   rather than being added by `FxWorld` or `ArenaDressing`. *Reason:* it needs no edit to any file feel owns, and
   `Arena.active` already carries the arena's `show` key because `normalize()` deep-duplicates.
2. **The show never grows a second `MatchMood`** — lazy booth lookup by `CrowdVoice.BOOTH_GROUP`, cached, copes with
   null (feel's condition, `CrowdVoice._mood()`'s pattern). With no booth (headless, `--mute`, `make perf-scene`) the
   show runs its idle and the kill ripple still fires. **The state cues are live in the game the lead plays**,
   because a windowed launch attaches the booth by default; `make perf-scene PERF_FLAGS="--music=on"` attaches a
   silent one so the cue path can be measured without unmuting.
3. **The show director owns the arena-wide wash and reads `AdBroadcast.light_color()` as an input, never writes it.**
   Agreed with feel in those words. One writer per perceived quantity.
4. **The victory sweep is the only team-coloured cue**, and it takes the *winner's* colour rather than a hex in the
   book. A test asserts no other cue carries a colour at all.
5. **The kill ripple is kills only** (`weight >= 1.0`). See *What this found*, below.
6. **Rim ceiling 1.25, floor 0.60.** He called the rim "dull", so it peaks *brighter* than today rather than
   breathing down from it. Reversible in one number per arena; it is the first thing to change if the strip reads hot.
7. **`export_presets.cfg` gains `game/theme/show/*.json`** to its three `include_filter`s, so the cue book ships in
   the web and server exports (trip-up 30). Listed in merge notes — it is a shared file.
8. **The ground fixture was designed and deliberately NOT shipped.** It is the best remaining one — the hazard band
   and the centre ring *are* the "road stripe or kerb line" the lead named, they already exist, and the hook is four
   uniforms and one line. But the ground plane is **the largest fragment area in the game**, its include is shared by
   three shader variants across three quality tiers, and builder0 went off the network before a paired measurement
   could be run. **Shipping the one fixture that cannot be measured, on the night the measuring machine died, is the
   exact mistake rule 3 exists to prevent.** It is the first thing to build when builder0 is back, and it should land
   with its own paired `perf-scene` rather than bundled with anything.

### What this found, and none of it was visible by eye

1. **⚠ `FxWorld.spectacle` is NOT a kill signal — it fires on every hit.** `fx_world.gd:319` emits `0.15` for a near
   miss; `weapon_fx.gd:278` emits `0.3` for a plain hit and `:378` `0.5` for a weak spot. Only a kill is `1.0`.
   Raised by feel, **verified here in the source rather than relayed**. Four subsystems already ride that one bus
   (`CrowdVoice`, `CrowdSystem`, `AdBroadcast`'s glitch, `LiveFeed`) and feel's new airship puts a 64 m screen 74 m
   up on the same ad channel — so a kill is now four venue-scale events on one trigger. Each is correctly owned by
   one writer, and that is not the same as a venue that does not flash on every trade. **Anything new wired to
   `spectacle` must read `weight`.**
2. **A "pairwise incommensurate" period bank is much harder to write than it looks.** The first attempt was 4:3 to
   within 1%; the second, written to fix the first, was 5:4 to within two parts in a thousand. Both were caught by
   the validator, and the second only because the ratio check tests `p/q` for `p, q <= 5` — **at `<= 4` it sailed
   through**. Phases have the same trap with a twist: the spread bar is half of even spacing, so it *tightens* as an
   arena patches fewer channels, and a seven-channel phase set failed the yard's four. **Periods are a global bank;
   phases are per arena.**
3. **A "never do X" guard must scan code, not prose.** The test asserting the show never reads the wall clock failed
   on `show.gd`'s own comment saying *"never `Time.get_ticks_*`"*. It strips comments and string literals now.
4. **A cue's first frame was a real tear, not a rounding one.** The clock offset was taken from the live channel,
   which does not exist on the frame a cue starts — so the rim's period moving 24.0 -> 23.x recomputed the clock
   instead of retuning it: **0.4 rad of jump at t = 40 s, at exactly the moment a cue begins.** It retunes from the
   patch's channel now, and the test measures the worst single-frame step across a 24 s breathe becoming a 1.6 s
   strobe.
5. **feel's `block_seed` "does not exist" was a glob that could not have found it.** Its grep was
   `game/theme/arena_kit/city/city_block.gd*`; the shader that reads `COLOR.g` is
   `game/theme/fx/shaders/city_block.gdshader`, and the GDScript side calls the value `seed01`. Checked against
   feel's own commit rather than argued. feel confirmed.

### Blocked / pending

**Everything outstanding is behind one thing: builder0 went off the network at ~02:47** (`ssh: No route to host`,
100% packet loss, confirmed over three attempts). It is every stream's build machine; the orchestrator has told all
eight to hold remote runs.

1. **THE LEAD GATE — the frame strip. Shot once, found to be wrong, and being re-shot.** The first run produced
   **30 frames, terminus and yard, at his pose, `shader errors 0`** — and reading their own reported channel values
   showed the three "idle breathe" frames were taken with the **FIGHT cue still running** (it holds 5 s from arena
   load; the warmup is 3), each one printing `"mood":"fight"`. The lead would have judged the ambience by looking at
   the loudest cue in the book. Fixed at `685df1f2`; the re-run is ~6 minutes whenever the machine is back.
   *The first strip was also only half copied back — `rsync` died mid-transfer with the machine and the wrapper
   correctly said `local build/ is STALE`. 15 of 30 frames had arrived. The partial set was deleted rather than
   kept, because a half-strip is exactly the artefact that gets read as a whole one.*
2. **The paired perf control.** `make show-perf-pair` runs `perf-scene` with `--no-show` and then without it, back to
   back **in one slot** — same binary, same import cache, same machine, minutes apart. Written and committed;
   never run.
3. **A full `make remote T=check`.** Running **locally** instead while builder0 is down (started 02:48 at
   `685df1f2`); it is the gating artefact and the laptop can produce it, slower.
4. **The ground fixture** — designed, deliberately not built. See *Decided overnight* #8.

### Measurements

**BEFORE, builder0 (Mesa Intel Iris Xe RPL-U), branch point `e3501ef9`, terminus, 1920×1080, seed 3:**
`all_avg 15.56 ms`, `all_gpu 6.27 ms`, `all_p95 27.45 ms`, holds 30 fps at **53 vehicles**, arena layer
**1.42 ms GPU**, **instance-uniform errors 0**, other engine errors 0.

**AFTER, builder0, `e5c8678f`, same arena, resolution and seed:** `all_avg 26.69 ms`, `all_gpu 8.25 ms`,
`all_p95 43.36 ms`, holds 30 fps at 33 vehicles, arena layer 4.07 ms GPU, **instance-uniform errors 0**, other
engine errors 0.

**⚠ DO NOT READ A DELTA FROM THOSE TWO ROWS. The machine was not the same machine.** builder0 went from 4
concurrent heavy runs to 8+ between them. The tell is that **every layer cost roughly tripled, including layers the
show does not touch**: `no_hud` 0.43 → 2.14 ms GPU (×5), `no_pool_lights` 0.39 → 3.47 (×9), `no_underglow`
0.55 → 1.41 (×2.6). A lighting change that made the HUD five times more expensive would be a remarkable lighting
change.

**What IS honest, because it is a count rather than a time** (median over the 17 all-phase samples in each run):

| | BEFORE `e3501ef9` | AFTER `e5c8678f` | reading |
|---|---|---|---|
| **real lights** | **4** (1–5) | **4** (1–5) | **identical: zero added real lights** |
| **instance-uniform errors** | **0** | **0** | the shader-instance ceiling did not move |
| **other engine errors** | **0** | **0** | **the five fixture shaders compile on a real GL context** |
| draw calls | 260 (197–324) | 273 (218–322) | +13 on heavily overlapping ranges — fight variance, not geometry |
| GPU ms | 6.1 | 6.5 | +0.4 ms **while the CPU side went +62% under load: an upper bound, not a measurement** |

The GPU row is the informative one. The show is a GPU-side change; GPU median moved **6%** while `avg_ms` median
moved **62%**. On a machine that much busier, +0.4 ms GPU is a ceiling on the cost rather than the cost.

**Frames, builder0, `cb167f69`, 1920×1080, terminus and yard:** 30 rendered, **`shader errors 0` on both arenas.**
That is the claim headless could never make — headless Godot uses a dummy renderer and compiles no shaders, so until
this run every "the defaults reproduce today's look" statement rested on parse checks and on a test that reads the
uniform *declarations*. The `#include`, the `pow` clamp and five sets of `show_*` uniforms are real.

**Local, laptop, `685df1f2`:** 74 passed, 0 failed on `--filter=show` — **43 test methods, every one confirmed
present in the run output rather than assumed** (trip-up 73). arena 79/0, fx 111/0, theme 39/0, crowd 16/0. All
touched files parse-checked clean, none of them in metrics' baselined set of 8 known lines.

### Requests to other streams

- **feel** — answered all four hooks, landed the `CyberMaterials.neon()` fixture tag itself
  (`stream/feel` `02e30ac0`, **not yet covered by a green check**, taken at the next announced checkpoint rather
  than cherry-picked), and made three calls this stream adopted: pools take a uniform not instance colour; the
  airship's navigation lights stay steady (*"the Syndicate is the faction that does not flicker"*); the ripple is
  kills only. **Still to review at merge:** the edge emission on `city_block.gdshader`, `show_level`/`show_color`
  on `neon.gdshader`, `splat.gdshader`, `beam_cone.gdshader` and `neon_sign.gdshader`, and that the level-1.0 look
  is unchanged.
- **scale** — **not yet messaged; owed.** The `show` key's schema is additive and loads today because
  `Arena.validate()` does not reject unknown top-level keys, and `make show-report` fails on a patch the validator
  refuses. What is still wanted is the **one-line call into the show's validator from `Arena.validate()`**, so a bad
  patch is a load-time error rather than a static arena. That is scale's file.
- **control** — answered: **nothing reserved.** Its camera-inside-a-block fix moves the camera
  (`RtsCamera.clear_pose()` lifts over the roof; 703 of 4328 poses inside a building before, 0 after), so it writes
  no uniform, no alpha, no visibility on a block and there is no faded-while-mid-cue case. Two consequences taken as
  constraints: roofs are on screen far more often (the parapet is now a fixture, and it is free), and
  `cutaway_near()` can clip the near wall away entirely at every spawn, so **the rim must not be the fixture that
  carries match start** — the FIGHT cue lifts the blocks, beams and signs too, and a test holds that.

### Questions for the lead

1. **Is it beautiful?** The only question that matters, and the frame strip is how it gets asked. Items 5-6's
   direction (how hard the cues push) should be steered by his answer rather than by another round of guessing.
2. **The rim peaks brighter than today** (ceiling 1.25). Right call for "dull", or does the venue now compete with
   the fight? One number per arena either way.
3. **Strobe on `last_stand`** is the one place in the venue a strobe is allowed. Worth keeping, or too much?

### What to playtest

```
make skirmish --arena=terminus          # the show is live by default: a windowed launch attaches the booth
make remote T="show-frames"             # the strip: build/show/*.png, idle + one frame per cue
make show-report ARENA=terminus         # every knob the patch resolved to
make remote T="perf-scene PERF_NAME=show-after-terminus PERF_RES=1920x1080 PERF_FLAGS=--arena=terminus"
```

### Merge notes (shared-file edits)

- `export_presets.cfg`: `game/theme/show/*.json` appended to all three `include_filter`s (the cue book must ship).
- `mk/show.mk` is new and needs no `Makefile` edit — the root `Makefile` already does `include mk/*.mk`.
- `arenas/terminus.json` and `arenas/yard.json` gain **only** an additive top-level `show` key (scale owns `arenas/`).
- Additive `show_*` uniforms in five of feel's shaders and a registration call in four of its scripts
  (`city_block.gd`, `arena_dressing.gd`, `neon_signs.gd`, `kit_yard.gd`), all inside the granted carve-outs, all
  defaulting to today's look, all asserted by tests that parse the uniform declarations rather than trusting the
  author.
- **Take feel's `02e30ac0` first if both land in the same merge**, then `rim_material()` and `beam_material()` pass
  their `fixture` tags; until then the cache isolation is held by a test instead of by the key.
