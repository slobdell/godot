> **ARCHIVED: round 9 (2026-09-19 → 2026-09-20), stream `show`.** Every commit named here is merged to `main`; the round-10 list at the top of Status is the live part. Relative links below were written from `_agents/streams/`.

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

_2026-09-20, round 9 closing. Branch `stream/show`, `main` merged clean twice (CP1, then squad's baseline).
**Items 1-6 of the backlog are done; item 7 (stretch) is not started.**_

---

## ROUND 10, in order — start here

**The lead has seen it and his verdict is "it reads as nothing".** That is the premise of this list, not a problem
to be argued with. Everything below follows from it.

1. **Re-shoot the frames.** `make remote T='show-decisions show-frames'`. Round 9's last run (`c83117dc`) measured
   through a pair that was **not frozen**: `FxWorld` runs `PROCESS_MODE_ALWAYS` (`fx_world.gd:115`) and kept
   ticking through the pause between the two halves of every pair. `06f8ca0b` disables both `FxWorld` and `Show`
   across the pair and has never been shot. **Every luminance number in `lighting.md` §9 and `show_dials.md` is
   measured through that leak and does not count.** This run was queued and deliberately dropped to let the round
   converge — it is not a discovery, it is an owed measurement.
2. **The louder pair, for the lead.** Today's band width, **2×** and **3×**, one dial moved and nothing else, cost
   beside each, and the dial and file named in the caption: it is `"floor"`/`"ceiling"` on the `windows` and
   `shopfronts` channels in `arenas/terminus.json`. **Keep the mean fixed and widen the band** — that is dial 1 in
   `show_dials.md`, and raising the ceiling instead is the wrong knob:

   | | windows | shopfronts | swing |
   |---|---|---|---|
   | today | `[0.80, 1.10]` | `[0.82, 1.12]` | 32% / 31% |
   | **2×** | `[0.65, 1.25]` | `[0.67, 1.27]` | 63% / 62% |
   | **3×** | `[0.50, 1.40]` | `[0.52, 1.42]` | 95% / 93% |

   (3× on the windows is wider than the 65% this shipped at last night before the readability gate narrowed it, so
   expect the gate to have an opinion — that is the point of shooting it rather than arguing about it.) This is the
   answer to "it reads as nothing" and it should be the first thing he sees.
3. **His two quotes belong in `_agents/game_design.md`** (the orchestrator owns that file; §1956 is the round-9
   light-show section they extend):
   - the buildings still look like a **1990s game**;
   - he wants **basic primitives that drive individual lights on a building**, with light-show effects composed
     from those primitives — **and his eye is the judge** of the result.
     Read together these are not a lighting request, they are a *geometry* request with lighting on top: the
     channel engine already composes effects from primitives (§3, §4b of `lighting.md`) and it is doing it on
     buildings that do not have enough shape to carry them. The louder pair (#2) will not fix a 1990s silhouette.
4. **The three luminance reds, with a discriminator on a still pair.** An earlier strip showed `cue_fight −5.1%`,
   `cue_kill_0_25s −7.5%`, `t16_3 −7.5%` and they were deliberately not tuned, because a red measured through an
   unfrozen pair is not a red. **The last run reads the same three frames at −2.7%, −3.0% and −1.5%** — still the
   most negative on the Terminus, still in the same order, but now inside a 2.8% null. That halving is itself
   unexplained: it could be the dropped street pose, the swept heading, or the leak. After #1, either they are gone
   or they survive — and if they survive, the discriminator is a **still pair at one instant**, not a frame mean.
5. **Fix the two broken comparison arms** (`lighting.md` rule 13):
   - `STROBE_ALTERNATIVE_PERIOD_S = 6.0` in `show.gd:57` is compared against a **1.6 s** strobe in a **6 s** clip,
     so the "off" arm is under one cycle of a slow breath and reads a quarter darker, with a *larger* full-frame
     swing (12.4% vs 8.7%) than the strobe it replaces. Two readings of that constant and both need acting on:
     as a **look** it is deliberate (its comment: *"urgent, but not a fault light"*) and it is fine; as an **arm**
     it changes programme *and* period, so the clip pair cannot isolate the strobe. **Shoot both** — the arm at the
     cue's own 1.6 s, and keep the 6.0 s version as a third look if he wants it. (While in there: the call-site
     comment says `--show-no-strobe`, the flag is `--no-strobe`.)
   - **Parapet vs outline no longer discriminates** (0.00% to +0.35% against a 2.8% null; on the wide pose it used
     to read +7.3% to +13.5%). Nothing about the looks changed — the camera learned to sweep its heading toward the fight, and the
     band window at the new heading holds far less building. Either the window follows the buildings or the pair
     goes back to a fixed heading; the lead's eye decides the look either way.
6. **Re-shoot the five mood clips.** `build/show/clips/*.mp4` are from **05:47–05:56**, before the frame tools
   learned to wait for contact — five units a side, still on the spawn line. `make show-clips` was not in round
   9's last target list. **Do not send them to the lead** until they are re-shot.
7. **The blimp.** Never briefed, and it is the lead's art call before it is anyone's engineering. Listed here so it
   is not lost, not because it is ready to start.

---

## FOR THE LEAD, FIRST

> **The dials are on their own page: [`_agents/show_dials.md`](../show_dials.md)** — four dials in his terms, what
> each does to the picture, and the frame or clip to look at while deciding. This section is the summary; that page
> is the conversation.

**Look at the stills; the clips are stale.** `build/show/terminus_wide_cue_battle.png` against
`build/show/before/terminus_wide_cue_battle.png` — the same frozen moment with the show off and on, 39 vehicles in
shot, `c83117dc` on builder0 at 16:46. The five mood clips in `build/show/clips/` are from **05:5x**, before the
frame tools learned to wait for contact, and they show five units a side on the spawn line. Re-shooting them is
round 10 item 6.

**What it costs: a ceiling, not a figure — under about 0.8 ms.** Six `--no-show` pairs inside one run on an empty
builder0 read `+0.28 +0.49 +0.78 +0.06 −0.46 −0.77` ms against frames of 6.6 ms. **Two of six are negative**, and
the show cannot make the game faster, so that is the measurement moving under us. All six are inside ±0.8 ms, i.e.
under ~2.5% of the frame and probably a good deal less. **Zero added draw calls and zero added lights** — that part
is structural (the code may not create geometry or a light, and a test enforces it), not a measurement. That is the
answer to *"nice effects that bring the arena to life without costing much in terms of frame rate"*.

*(This section said "1.5%, +0.22 ms" this morning. That was a mean of measurements that disagree about their own
sign, which I had no business averaging.)*

**What you are looking at.** Every block's roofline carries a thin lit run in one of the venue's colours, picked
per building; the windows and shopfronts breathe, each window on its own clock; the perimeter rim breathes instead
of sitting at a flat purple; the signs, the floodlight pools and the tower beams are on their own channels. All of
it is driven by **15 uniform writes a frame** — the same 15 whether there are eight buildings or eighty.

**Three honest caveats, in order of how much they should bother you:**

1. **The buildings breathe; they do not look different.** Between feel's judgement (see below) and a readability
   gate, the default is conservative enough that a *still* barely changes. That is a deliberate position, not a
   limit of the machinery, and **you have the dial**. *(This is the caveat his verdict landed on, and round 10
   item 2 exists to answer it with pictures instead of prose.)*
2. **The dial is the band's WIDTH, not its ceiling.** The windows currently swing 32% (`[0.80, 1.10]` in
   `arenas/terminus.json`); they used to swing 65%. What reads as *alive* is contrast, not brightness — widening to
   `[0.70, 1.20]` gives most of the life back without making the city brighter. **"Turn it up" is the wrong dial**:
   raising the ceiling alone brightens the periphery and costs you the fight's readability, which is measured.
3. **There is a second look you have not chosen between.** `build/show/outline/` has the same frames with **every
   vertical corner lit**, which is closer to your *"making the lit edges breathe and glow"*. feel argues against it
   in art-direction terms — the corner IS the silhouette, so lighting it draws an outline on everything, which
   `art_direction.md` names as a failure — and I agree with feel. **You decide; it is one word in the layout file.**

**Provenance.** Stills: `c83117dc`, builder0, 2026-09-20 16:46 — a real fight both arenas (Terminus 39 vehicles
wide / 12 close, yard 37 / 16), contact confirmed before the shutter, pitch 21° on every frame, `sight_blocked`
false throughout, zero shader errors on a real GL context. Clips: **05:5x, stale, do not use**. Decision pairs
(`build/show-decisions/`): same run.

**And the honest health warning on every luminance number in this brief:** they were measured through a pair that
was supposed to be two shots of one frozen instant and was not — `FxWorld` runs `PROCESS_MODE_ALWAYS` and ticked
through the pause. `06f8ca0b` fixes it and **has not been shot**. Round 10 item 1.

**Three questions:** Is it beautiful? Outline or parapet? Is the `last_stand` strobe — the one strobe in the venue
— too much? *(His answer to the first is already in: it reads as nothing. Round 10 item 2 is the reply.)*

---

## The engineering

### Where it stands

| item | state |
|---|---|
| 1. `_agents/lighting.md` before code | **done**, reviewed by feel and control; their answers and reasons are in it |
| 2. The channel engine | **done** |
| 3. First fixtures (blocks, perimeter rim) | **done**, re-shaped after feel reviewed the frames |
| 4. Patches as data | **done** (`terminus`, `yard`, `make show-report`) |
| 5. Cues from the match | **done** (7 state cues + the kill ripple) |
| 6. Signage, pools, tower beams | **done** |
| 7. Stretch | **not started** |

### The design, in one paragraph

A channel packs into **one `vec4`** — `(floor, span, clock, sharpness)` — and **one function**,
`show_value(chan, phase) = chan.x + chan.y * pow(max(0.5 + 0.5*sin(chan.z + phase), 1e-4), chan.w)`, lives in
`game/theme/fx/shaders/show.gdshaderinc` and, identically, in `ShowChannel.level_at()`; a test asserts the two
bodies are the same line, so the headless tests keep describing what the player sees. **`phase` is per-instance and
never comes from the CPU**: a block's seed in `COLOR.g`, the rim's angle in world space, a sign's
`INSTANCE_CUSTOM.a`, a pool's `.y`, a tower's lamp angle. Everything else — programmes, patches, cues — is data.

### GREEN, and the hash to merge

**`e1823e68` is green.** builder0, `make remote T=check`, read from the wrapper's own line and the runner's
summary, never a shell exit code through a pipe:

- `>> remote: make check exited 0 (build/ copied back)`
- **`1420 passed, 0 failed`** (shard 0: 648, shard 1: 772)
- `lint: all 560 scripts parse (-P4, 8 known artefacts baselined)` — CP1's real lint
- **`sim-baseline passed: d4c049819a5833d3 (glibc-2.43)`** — squad's new baseline, **unmoved**

That last line discharges **S6's pre-registered claim**: *the show does not reach the simulation.* It was
pre-registered before a line was written and it held across a channel engine, five shaders, seven fixtures, a cue
book and a kill ripple.

**Superseded — see *The handover* below.** `e1823e68` is where round 9's code first went green; twenty-five
commits of capture tooling, two `show.gd`/`cues.gd` fixes and the docs landed above it, so the tip carries its own
check.

### NEXT STEP, in order

**The round-10 list at the top of this Status comes first** — it is what the lead's verdict and the last run
changed. What follows is the work that was already queued behind it and is still wanted; nothing here is urgent
next to item 2 up there.

1. **The ground fixture** (*Decided overnight* #8), with its own paired measurement.
2. **The rest of item 7**: the airship's screen on an ad channel, a fixture that is neither building nor wall, a
   `show` view in `arena-kit-gallery`.
3. **feel's roof question**, which feel is holding as a round-close item: with the chamfers dark the parapet is the
   only edge left, and control's camera lift puts roofs on screen far more often. feel wants a frame from the
   lifted camera before any geometry, and surface treatment (tar, grime, a vent grid — texture in the existing
   shader) before a MultiMesh. **Do not wait on it**: the parapet at 0.55 under the windows' 0.80 stays correct
   with a bare cap and stays correct if the cap later gets grime.

### Decided overnight (the lead asleep; most reversible option taken, reason recorded)

1. **The `Show` mounts itself** under the scene tree root (`FxWorld`'s pattern) and follows `Arena.active`, so it
   needs no edit to any file feel owns.
2. **The show never grows a second `MatchMood`** — lazy booth lookup by `CrowdVoice.BOOTH_GROUP`, cached, copes
   with null (feel's condition). With no booth the show runs its idle and the kill ripple still fires; the state
   cues are live in the game the lead plays, because a windowed launch attaches the booth by default.
3. **The show director owns the arena-wide wash and reads `AdBroadcast.light_color()` as an input, never writes
   it.** One writer per perceived quantity.
4. **The victory sweep is the only team-coloured cue**, and takes the *winner's* colour rather than a hex.
5. **The kill ripple is kills only** (`weight >= 1.0`).
6. **`export_presets.cfg` gains `game/theme/show/*.json`** so the cue book ships in the web and server exports.
7. **The parapet, not the outline** — feel's call, adopted; the outline survives as a named variant.
8. **The ground fixture was designed and deliberately NOT shipped.** It is the best remaining one — the hazard band
   and centre ring *are* the "road stripe or kerb line" the lead named — but the ground plane is the largest
   fragment area in the game, its include is shared by three shader variants, and builder0 went off the network
   before a paired measurement could be run. **Shipping the one fixture that cannot be measured, on the night the
   measuring machine died, is the exact mistake rule 3 exists to prevent.**

### Measurements

| claim | evidence |
|---|---|
| **Frame cost** | `no_show` layer, six pairs **within one run** on an empty builder0: `+0.28 +0.49 +0.78 +0.06 −0.46 −0.77` ms against frames of 6.6 ms. **Two of six are negative and the show cannot make the game faster**, so this is a bound, not a figure: **under ~0.8 ms, and not resolvable** |
| **Real lights added** | **0** — median 4 vs 4, identical ranges |
| **Draw calls added** | none detectable; and structurally a test forbids `MeshInstance3D`, `MultiMesh` and `Light3D` anywhere under `game/theme/show/` |
| **Instance-uniform errors** | **0** in every run |
| **Shaders compile** | `shader errors 0` on every strip, on a real GL context — headless compiles no shaders, so this is the only proof |
| **Per-frame cost** | **15 writes idle, 16 during a kill, 25 during the victory sweep** on the Terminus: 7 patch entries over 13 driven materials. **O(driven materials), never O(instances)** |
| **Readability** | **36 of 36 frames pass**, most positive, against a measured null of 0.5% median / 1.3% p95 |
| **Lint** | `all 560 scripts parse (-P4, 8 known artefacts baselined)`, remote at `e1823e68` |
| **Tests** | `--filter=show` 79 passed 0 failed; 43 methods, every one confirmed present in the output (trip-up 73) |

### What this found, and none of it was visible by eye

1. **⚠ `FxWorld.spectacle` is NOT a kill signal — it fires on every hit.** `fx_world.gd:319` emits 0.15 for a near
   miss; `weapon_fx.gd:278` 0.3 for a plain hit and `:378` 0.5 for a weak spot. Only a kill is 1.0. Four subsystems
   already ride that bus and feel's airship puts a 64 m screen on the same ad channel. **Anything new wired to it
   must read `weight`.**
2. **A "pairwise incommensurate" period bank is much harder to write than it looks.** The first attempt was 4:3 to
   within 1%; the second, written to fix the first, was 5:4 to within two parts in a thousand — and passed a check
   that tested `p/q` for `p, q ≤ 4`. Periods are a global bank; **phases are per arena**, because the spread bar
   tightens as an arena patches fewer channels.
3. **A "never do X" guard must scan code, not prose.** The test asserting the show never reads the wall clock
   failed on `show.gd`'s own comment saying *"never `Time.get_ticks_*`"*.
4. **A cue's first frame was a real tear.** The clock offset came from the live channel, which does not exist on
   the frame a cue starts — 0.4 rad of jump at t = 40 s, at exactly the moment a cue begins.
5. **The FIGHT cue could never fire.** The Show mounts with a *deferred* `add_child`, so the venue is built before
   `_ready()` runs, and the cue book was loaded in `_ready()`.
6. **⚠ TWO RUNS ARE NOT THE SAME RUN, three times in one night** (`lighting.md` §8b): a perf before/after an hour
   apart (machine load tripled *every* layer, including ones the show does not touch); the paired runs in one slot
   (**the show-ON arm came out 43% faster** — impossible, therefore noise); and the luminance pair across two
   processes (the frames ride a live skirmish, so the vehicles are elsewhere; the same frames swung 5 points
   between runs of one commit). **The fix is identical in all three: get A and B from one run.**
7. **A gate that fails the branch point is not a gate.** The readability rule shipped first as an absolute and
   failed **22 of 30 frames with no show in them at all**.
8. **⚠ `arenas/*.json` are GENERATED** (`tools/make_arenas.py` builds a fresh dict and overwrites), so a hand-edited
   key is silently deleted on the next `make arenas` — and a dropped lighting patch produces a *static arena*,
   which looks exactly like a working one. Guarded by a test asserting the patched set is exactly
   `["terminus", "yard"]`.
9. **A latent bug in `city_block.gd`**, found while proving the off arm was off: `neon_color()` only honoured
   colours beginning with `#`, so all eight of the Terminus's named block colours were ignored and the map wore the
   signage palette — including the two colours feel had just ruled out for the parapet. **Fixed by feel at
   `637ad4de`.**
10. **I reported one fix as shipped when it was not.** A `str.replace` moving the kill ripple onto the idle
    silently did not match, with no assertion on it, and I said so in a commit message and to the orchestrator. Two
    strips were shot before it was caught. **An edit that claims to change behaviour must fail loudly when it
    changes nothing.**

### The strip changed the design, which is why it went out the night it existed

feel's review of the first frames changed what ships, and the change is *smaller* than what it replaced:

- **The edge emission was an outline, and a dimmer outline is still an outline.** `show_edge` is added on the
  bevel/chamfer branch and **that branch is the silhouette**. The default is now the **roof parapet only**; the
  breathing that carries a block is `show_window` and `show_shop`, which is light *inside* things.
- **Cool white and red are barred.** Cool white is not in the venue palette and reads as architectural LED; **red
  is a signal in this game**, so spending it on trim spends a colour that means something is wrong.
- **The hierarchy is a gate.** `make show-frames` fails if the show makes the fight harder to read than the same
  frozen frame with the show off.

### The readability gate forced one look decision

35 of 36 frames passed; the one failure was repeatable and diagnosable — `terminus/wide/t0_0` at **−7.3%** against
a **0.5% median / 1.3% p95** null. `t0_0` is the idle at `t = 0`, where each channel's clock equals its phase, and
the windows' phase of 1.48 rad puts the sine at 0.998: **that frame is the brightest the buildings ever get.** The
gate found the worst case, which is what it is for. The windows went `[0.70, 1.35]` → `[0.80, 1.10]`.

**This is a look decision a gate forced**, and the lead's section above says so and names the dial.

**And it is the decision round 10 should revisit first.** The last run (`c83117dc`) measures 26 pairs between
**−3.0% and +3.3%** against a null whose *worst* pair is **2.8%** — the whole result is inside the error bar, so
this gate is not currently able to justify a narrowing it once forced. Re-shoot through a genuinely frozen pair
(round 10 item 1), then let the 2×/3× set (item 2) answer the band question with pictures.

### Proved on request: the `--no-show` arm really is off

The orchestrator saw lit coloured lines on the blocks in the show-off arm and asked whether the "additive hook,
never a restyle" promise had broken. It had not: those are feel's **`NEON_BAND`**, a second surface on every
`CityBlock` at shopfront height since round 7. **The proof is the pair's own numbers**, with both failure
predictions stated in advance: if the identity leaked the band would be *equal* between arms; if the parapet were
lit only in the on arm it would be consistently *higher*. It is neither — **median −0.39%, range −3.7% to +2.4%,
scattered both ways**, against a 1.3% null.

### Provenance of the frames and clips

| what | commit | when | fight? |
|---|---|---|---|
| `build/show/*.png`, `build/show/outline/` | `c83117dc` | 16:46 | **yes** — Terminus 39 wide / 12 close, yard 37 / 16, contact confirmed |
| `build/show-decisions/` (parapet·outline, strobe on·off) | `c83117dc` | 16:24–16:43 | **yes** — 39 vehicles |
| `build/show/clips/*.mp4` (five moods) | earlier | **05:47–05:56** | **NO — five a side on the spawn line. Do not send these.** |
| `build/show/terminus_street_*.png` | earlier | 14:46 | stale: the street pose was dropped at `cd00e613` |

`make show-clips` was not in the last run's target list, which is why the clips are the old set; `show-frames`
and `show-decisions` write to different directories since `c83117dc`, so a re-run of one no longer wipes the other.

**Every luminance number from this run passed through a pair that was not frozen** — `FxWorld` is
`PROCESS_MODE_ALWAYS` and ticked through the pause between halves. `06f8ca0b` fixes it; nothing has been shot
since. Round 10 item 1.

### Requests to other streams

- **feel** — answered all four hooks, landed the `CyberMaterials.neon()` fixture tag, and made the calls that
  shaped this: the parapet over the outline, the barred colours, kills-only, pools on a uniform, the airship's
  navigation lights left steady, and the settle-window warning on the perf phase. **Still to review at merge:** the
  five fixture shaders and that the level-1.0 look is unchanged.
- **scale** — the `show` key's schema, and (ruled) the generator preserves an allowlist of hand-authored keys while
  `Arena.validate()` rejects unknown top-level ones.
- **control** — **nothing reserved.** Its block cutaway is per-block *visibility*
  (`BlockCutaway.cut_blocks()`), never a uniform. Two constraints taken: roofs are on screen far more often, and
  `cutaway_near()` can clip the near wall away at every spawn, so the rim must not be the fixture that carries
  match start — the FIGHT cue lifts the blocks, beams and signs too, and a test holds that.

### What to playtest

```
make skirmish --arena=terminus                  # the show is live by default
make remote T=show-frames                       # the strip + the readability gate
make remote T=show-clips                        # the cues, as motion
make remote T=show-perf-layer                   # the cost, measured within one run
make show-report ARENA=terminus                 # every knob the patch resolved to
```

### Merge notes (shared-file edits)

- `export_presets.cfg`: `game/theme/show/*.json` appended to all three `include_filter`s.
- `mk/show.mk` is new and needs no `Makefile` edit (`include mk/*.mk` already).
- `game/theme/fx/bench/perf_scene.gd` (feel's shared M1 harness): **one additive match arm**, `no_show`, and
  deliberately **not** in the default `LAYERS` list — a test asserts it stays off, because adding a phase would
  lengthen every other stream's runs and change their `PERF_SCENE_LAYERS` shape.
- `arenas/terminus.json`, `arenas/yard.json`: an additive top-level `show` key only.
- Additive `show_*` uniforms in five of feel's shaders and a registration call in four of its scripts, all inside
  the granted carve-outs, all defaulting to today's look, all asserted by tests that parse the uniform
  declarations rather than trusting the author.
