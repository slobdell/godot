# Stream: show (the light show on the building walls, judged by his eye)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*, *Round 9 addition: the arena as a light show*, and the two afternoon quotes at its end),
> [workstreams.md](../workstreams.md) (*Round 10: the eight streams*; round 9's contract **S6**),
> [lighting.md](../lighting.md), [show_dials.md](../show_dials.md), and your round-9 brief
> [archive/round9/show.md](archive/round9/show.md) — its "ROUND 10, in order" is folded in below.
>
> **You own** `game/theme/show/`, `mk/show.mk`, `_agents/lighting.md`, `_agents/show_dials.md`, the `show` key per
> arena, and the round-9 emission carve-outs from feel (`CityBlock`'s emission paths and `city_block.gdshader`, the
> perimeter rim, `NeonSigns`, the pools, `CyberMaterials.neon()`). **Extended 2026-09-20:** `CityBlock`'s window
> construction may gain per-instance custom data (a MultiMesh where it is a mesh today) — additive, the silhouette
> unchanged, feel reviews the look at merge. **Every Godot process runs on builder0** (the laptop is full).

## The lead's direction (2026-09-20; verbatim in game_design.md)

Evening: *"I asked for lightshows on the building walls but haven't gotten that yet."*

Afternoon (16:40): *"there is neither the blimp that I wanted to see or the lighting effects on the Terminus map (i.e.
making use of the windows). I did see the subtle glowing effect but that's it."*

Afternoon (16:55): *"previously I had given some long prompt about how I wanted to effectively see light shows. Those
3d buildings right now look like a 1990s game, and we could bring it to life by having some sleight-of-hand lighting
tricks (i.e. basic primitives to adjust individual lights on the building) and couple that with light show effects in
general."*

The orchestrator's reading: **what shipped is the engine with its dials where the gates allowed; what he asked for is
the SHOW.** The unit of the show is the individual window; effects are composed from windows; his eye is the judge,
against a 1990s-baseline frame, not a luminance bar. The bar and the gates were your discipline in round 9 and they
stay as instruments; they stop being the verdict.

## Where things stand

- **The engine** (`game/theme/show/{show.gd,channels.gd,cues.gd,cues.json}`): channels (`breathe, chase, strobe,
  sweep, cycle, hold`), cues bound to `MatchMood` and K5 events, fixtures via `Show.add_fixture(selector, driven)`
  (`show.gd:342`). The Terminus patch (`arenas/terminus.json` `show`) has seven channels, all `breathe`, binding
  `city_block/edge→edges` (parapet), `window→windows` `[0.80, 1.10]`, `shop→shopfronts`. The `city_block` fixture
  (`city_block.gd:82`) drives UNIFORMS (`show_edge/show_window/show_shop`, `show_spread`, `show_color`, `show_event`)
  in `city_block.gdshader:30-34`: **one number for the whole block's windows.** A cue can only breathe all of them
  together, which is why 32 % reads as nothing and why nothing can chase, ripple or sweep ACROSS a facade.
- **S6's hook rule** (feel, round 9): a value that differs between instances is per-instance custom data on a
  MultiMesh (how the crowd is driven); a whole-fixture value is a uniform. Per-window addressing is the first rule
  applied to windows: the window grid becomes a MultiMesh with custom data per window (or a per-window texel in a
  small texture the shader samples), the show writes a per-window value per frame on the CPU (a few hundred floats:
  `PackedFloat32Array` into a `MultiMesh` buffer, or one `ImageTexture.update`). Zero added lights; the draw-call
  count read from `make perf-scene`, before and after, its "Too many instances using shader instance variables"
  counter read as a number.
- **Your round-9 list, still true:** the frames were measured through an unfrozen pair (`FxWorld` at
  `PROCESS_MODE_ALWAYS`; `06f8ca0b` freezes both and has never been shot: every number in `lighting.md` §9 and
  `show_dials.md` is through the leak); the louder pair (2× and 3× band width, one dial) is the fastest thing he can
  see; the strobe arm compares 6.0 s against a 1.6 s strobe; parapet-vs-outline stopped discriminating because the
  camera sweeps toward the fight; the clips in `build/show/clips/` are the 05:5x set and must not go to him.
- **feel's art rulings stand** (the look: light inside things, venue palette, never red or cool white, the fight the
  brightest read) and **the gate's reading** (26 pairs inside the null: "not measurable", never "no effect"). The
  S6 falsifier held all round (the sim hash unmoved through everything); it holds this round too.
- **The blimp is feel's this round** (R7); its screens are fixtures you can patch once it exists.

## Backlog (in order)

1. **The frozen re-shoot and the louder pair, first, because he can see it tomorrow.** `make remote T='show-decisions
   show-frames'` on `06f8ca0b`'s freeze; then band width 2× (`[0.65, 1.25]`) and 3× (`[0.50, 1.40]`) on `windows` and
   `shopfronts`, the mean fixed, one dial, cost beside each, the file and key named in the caption; three frames at his
   pose, sent through the orchestrator. Ship 2× as the default if the gate does not refuse it; 3× is his to choose.
2. **Per-window primitives.** The window grid addressable per window: a MultiMesh (or texel) per window with a
   custom-data channel the shader multiplies into emission; the `city_block` fixture exposes `set_window(i, value)`
   and `window_count()`; a test asserts two windows on one block can differ by the channel's full range while draw
   calls are unchanged. Blocks keep their silhouette; feel reviews the look at merge. Report `perf-scene` before and
   after (draw calls, the instance-variable counter, frame time on a quiet box).
3. **Effects composed from windows.** New programmes that take a window's (row, column, facade) as input: a vertical
   chase up a tower, a horizontal sweep across a facade, a random-walk twinkle at a floor and ceiling (the Vegas
   fade), a kill ripple that crosses the facade nearest the kill, a floor-by-floor fill on a control-point capture,
   the `last_stand` strobe on one facade rather than all. Each is ten lines of JSON in the patch plus one programme;
   `lighting.md` §4b's recipe extended. Cues bind them by mood. **A pair per effect at his pose**, one variable, the
   frame-mean delta beside it; the readability gate reports, and if it objects, the number goes to him with the
   frame, not a quieter effect.
4. **The 1990s baseline frame.** One frame of the Terminus at his pose with the show OFF (the "before" he named) on
   the page beside the same frame with items 1–3 ON; two clips (30 fps; the strobe sampled correctly). That page is
   his verdict surface; nothing goes to him without the before.
5. **Signs and the rim as instruments in the same show:** the perimeter rim breathing with the plaza chase, the neon
   signs flickering (a sign's letters as windows), the pools following the kill ripple; the shopfront band per
   segment. Only after windows read.
6. **Your round-9 leftovers:** the strobe arm at the cue's own period; parapet-vs-outline on a fixed heading or with
   the window following the buildings; the three luminance reds on a still pair; re-shoot the five mood clips.
7. **Stretch:** the blimp's screens as fixtures once feel lands it (R7); a road or bridge patched with no new
   abstraction (the `lighting.md` promise).

## How to verify

- `make check` green (`make remote T=check`); `make remote T=perf-scene` before/after (draw calls unchanged, zero
  lights added, the counter); `make remote T='show-decisions show-frames'`; `make show-report ARENA=terminus`;
  `make remote T=show-clips`.
- The sim baseline: pre-registered UNMOVED on every commit (the S6 falsifier). A move is a finding.
- Every visual claim is a pair (your rule 12), at his pose, one dial, the file named; a frame he has not seen the
  before of is not evidence.

## Don't touch

`game/theme/**` outside the carve-outs (feel's: the blimp, the hulls, the props), `arenas/*.json` outside the `show`
key (arena's; the generator preserves `show`), `game/control/**` (the cutaway is control's; the FIGHT cue lifts
blocks and a test holds that), the simulation.

## Waiting on the lead

His eye on item 1's three frames (the band width he prefers) and on item 4's page. Neither blocks: 2× ships as the
default on the gate's say, and items 2–3 proceed regardless.

## Research addendum (brief 2, 2026-09-20 evening; row B10)

**Item 2 changes mechanism.** Per-window addressing is a packed 32-bit per-instance attribute (zone id, spatial phase,
palette index, wave mode) that the SHADER evaluates from one global time uniform: chases, pulses and strobes per
window at zero CPU per frame and zero added draw calls; the CPU writes per-window values only for event ripples (a
kill crossing a facade). That is the media-facade practice and it is cheaper than the buffer-per-frame plan. Two
dials from the same source: camera-facing attenuation (a facade facing the camera dims, so a broadside wall never
dominates the frame) and the readability gate as a 3 : 1 luminance ratio of the fight over the venue. The
falsifier for item 2 is unchanged: two windows on one block differ by the channel's full range while `perf-scene`'s
draw calls and instance-variable counter do not move.

## Research addendum 2 (brief 3, 2026-09-20 late; row C11)

**One fixture rule from the legibility instrument:** a light behind every street corner so the entrance silhouettes
from his camera, and no facade wash that lowers the contrast of a street's ground-contact line (the edge the eye uses
to read passability). arena's render test prints the contact-line contrast per lane; keep it from falling when a cue
runs. After the per-window work.

## Status

_(the worker keeps this current)_
