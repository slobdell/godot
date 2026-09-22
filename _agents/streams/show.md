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

**2026-09-22, round 10 worker started at `2ee65f94` (the launch commit; its tree is the orchestrator's verified-green
`de31eeea` code).** builder0 had nine checks queued at start (every stream launching at once), so the baseline check
was cancelled in favour of one check on the first changed tree: the launch tree's green is the orchestrator's, read
from the wrapper's line on `de31eeea` (1559/0).

### Plan (smallest foundation first; decisions in one line each)

1. **Dial 1 as a strip** — `Show.set_band(k)` scales the `window`/`shop` channels' span around the mean (idempotent
   against the patch; floor never under 0.1), `--show-band=K`, and `make show-bands` shoots off/1×/2×/3× at ONE
   frozen moment in ONE process (idle + battle), so the three arms differ in the band and nothing else. *Decided:*
   one process beats three runs (lighting.md §8b "two runs are not the same run").
2. **Per-window primitives** — `ShowWindowGrid`: one RGBA8 texel per window (32 × 1024, 128 KB), the shader finds its
   own texel from block index (COLOR.b), facade (world normal), storey (y / 3.6) and bay (along / bay). *Decided:
   texel, not MultiMesh* — the windows are drawn procedurally in the fragment shader, there is no mesh per window to
   instance; a texel needs no vertex data, no instance uniform, no draw call. *Decided:* the bay width moves from a
   GPU `sin()` hash to a CPU-chosen 8-bit code in COLOR.a, so CPU and GPU agree on where every window is (float32
   and float64 disagree about `fract(sin(x) * 43758)`); the bay widths of the eight blocks change (still 3–4.5 m,
   silhouette unchanged, feel reviews). `CityBlock.set_window(i, v)` / `window_count()`.
3. **Effects composed from windows** — a `pixel` parameter (any pane, lit by the art or dark, carries a venue-palette
   light) evaluated per window IN THE SHADER from one channel plus a spatial `wave` (per storey, per metre, scatter,
   rate jitter): idle = Vegas twinkle; skirmish = sweep across facades; battle = vertical chase up every tower;
   last_stand = strobe on the one facade facing the losing base; victory = sweep in the winner's colour; kill =
   ripple crossing the windows; capture = CPU floor-by-floor fill of the nearest block. *Decided (research B10):*
   shader-evaluated programmes, CPU writes only for events.
4. The 1990s-baseline page (show OFF beside items 1–3 ON, two clips at 30 fps).
5. Signs / rim / pools / shopfront segments in the same show.
6. Round-9 leftovers (strobe arm at the cue's period, parapet-vs-outline instrument, the three reds, mood clips).
7. Stretch: blimp screens (after feel's R7), a road/bridge patch.

**MERGE HERE: `f19804ed` is GREEN** — `make remote T="check show-frames show-effect-clips"`, builder0: runner
`1572 passed, 0 failed`, `>> check: 18 targets, all passed`, `>> remote: ... exited 0`, sim-baseline
`1ea332e7bc268d2a` unmoved, determinism `559a415887806e43`. Commits after it are docs only.

**What to playtest:** `make skirmish ARENA=terminus` (watch the buildings when the fight starts, at a kill, when the
centre point changes hands, and at a last stand). **His page:** `build/show-page/index.html` (12 show-off/show-on
pairs at his pose, the band strip, six 30 fps clips in `build/show-clips/`); rebuild with
`python3 tools/show_page.py build` after `make remote T="show-frames show-bands show-effect-clips"`. **Looked at**
(the clips, 1 s apart): battle pulses whole storey rows block by block; last_stand strobes ONLY the far facade while
the near block stays dark (the focus works); capture fills amber from the street up.

### THE ROUND'S SHOW VERDICT (for the lead's morning page)

**The band dial is not the lever; the pixel layer is.** Dial 1 at 1×/2×/3× on one frozen frame at his pose is near
indistinguishable to the eye (the art lights few windows there; `build/show-bands/`), so round 9's "turn it up" would
never have answered "it reads as nothing". What reads is every window addressable and lit by the show: the Terminus
wide frames move the fight/venue luminance ratio **−5.8 % to −26.7 %** with the show on (idle −6 to −11 %, battle
−16 %, kill ripple −12 to −27 %, capture −22 %; yard within ±2.7 %; null p95 1.4 %), where round 9 sat inside the
null. **Reported, not blocking** (the brief: the number goes to him with the frame, not a quieter effect). If he
finds the venue competing with the fight, the dials below are where to turn it down.

**One line per effect: what it is, the dial, the file** (all data; `make show-report ARENA=terminus` prints them):

| effect | dial | file |
|---|---|---|
| idle twinkle (Vegas fade, window by window) | `channels.pixels` `ceiling` 0.9, `sharpness` 6, `period` 10.5, `wave.scatter/jitter` | `arenas/terminus.json` `show` |
| skirmish sweep across the facades | `states.skirmish.set.pixels` `period` 6.0, `wave.along` −0.25 | `game/theme/show/cues.json` |
| battle chase up every tower | `states.battle.set.pixels` `period` 3.2, `wave.row` −0.75 | `game/theme/show/cues.json` |
| last-stand strobe on ONE facade (facing the losing base) | `states.last_stand.set.pixels` `period` 1.6 | `game/theme/show/cues.json` |
| victory sweep in the winner's colour | `states.victory.set.pixels` `color_mix` 0.8, `wave.along` −0.2 | `game/theme/show/cues.json` |
| kill ripple across the windows (and the pools) | `events.kill` `gain` 1.5, `speed` 62 | `game/theme/show/cues.json` |
| capture fill, floor by floor | `FILL_STEP_S` 0.18, `FILL_HOLD_S` 1.4, `FILL_FADE_S` 1.2 | `game/theme/show/window_effects.gd` |
| how bright any show-lit window is | `show_pixel_energy` 1.3 | `game/theme/fx/shaders/city_block.gdshader` |
| the art's own lit windows' swing (dial 1) | `channels.windows`/`shopfronts` `floor`/`ceiling` (2× = `[0.65, 1.25]`) | `arenas/terminus.json` `show` |

**Owed: the quiet perf re-measure.** Before `2ee65f94` / after `fba345d7`, builder0 1080p terminus seed 3, taken
while other streams' checks ran: per-phase GPU 7.99–17.06 ms (before) and 11.06–14.99 ms (after) inside each run, so
the no_show layer's +0.42 / −1.29 ms is noise. Draw calls 257 / 258 (first phase; 230–263 with the camera),
instance-uniform errors 0 / 0, real lights 1 / 1. Re-run `make show-perf-layer` on a quiet builder0.

### Done (with measurements; every number builder0)

- **Items 1–3 at `9f68b95e` — GREEN: `make remote T=check` 1572 passed 0 failed, 18/18, sim-baseline
  `1ea332e7bc268d2a` UNMOVED (S6 held), determinism `559a415887806e43`.** `fba345d7` on top: values only (2× band,
  pixel energy 1.8 → 1.3), its check pending.
- **Per-window primitives work and read.** The frames at his pose (`build/show/`, one frozen frame shot show-off then
  show-on in one process) show individual windows lit: idle magenta twinkle window by window, battle rows lit up the
  towers, the capture fill amber from the street up, the kill ripple across the windows. **The instrument now SEES the
  show:** Terminus wide ring/band ratio −5.8 % to −26.7 % with the show on (round 9: inside a 2.8 % null); yard within
  ±2.7 %; the null this run p95 1.4 %. The luma gate *reports* this (it would have refused 9 of 29 frames): per the
  brief the numbers go to him beside the frames, not a quieter effect.
- **The band dial (item 1) is not the lever.** `make show-bands`: 1×/2×/3× on the same frozen frame are near
  indistinguishable to the eye (the art lights few windows at his pose), all −4.8 % to −6.1 % idle, −15 % to −18 %
  battle (that spread is the pixel layer, present in all three arms). 2× ships as the default (the brief's rule); 3×
  stays his. The louder thing he can see is the pixel layer.
- **Cost.** Structural: zero draw calls, lights, nodes, instance uniforms added (`tests/test_show_windows.gd`).
  `perf-scene` 1080p terminus seed 3, `--perf-layers=no_show`, before `2ee65f94` / after `fba345d7`: draw calls
  257 / 258 on the first phase (both runs wander 230–263 with the camera), instance-uniform errors 0 / 0, real
  lights 1 / 1. **GPU cost not measurable on this builder0:** both runs were taken while other streams' checks ran,
  and per-phase GPU swung 8–17 ms inside EACH run (the no_show layer read +0.42 ms before, −1.29 ms after: noise, not
  a speed-up). A quiet-box re-measure is owed.

- **Round-9 leftovers, fixed at `b5f95d14` — GREEN** (builder0: `1572 passed, 0 failed`, `18 targets, all passed`,
  `>> remote: make check show-decisions exited 0`, sim-baseline unmoved). (a) The no-strobe arm keeps the strobe's own
  1.6 s period (one variable): band swing **23.5 % strobe vs 13.7 % breathe**, full frame 8.8 % vs 5.3 %, 38 vehicles
  in both 30 fps clips — the pair now discriminates (round 9's arm changed the tempo too). (b) Parapet vs outline on
  a FIXED heading (`--show-look-fixed-heading`, both at 21°): outline band luma **+3.2 % to +7.9 %** over parapet
  (wide idle 0.1605 → 0.1732, battle 0.1776 → 0.1832), against a ~1.4 % null — discriminates again (round 9, swept:
  0.00–0.35 %). Frames and clips: `build/show-decisions/` (`strobe_on.mp4`, `strobe_off.mp4`, `*_outline.png`).
  Still open from item 6: the three luminance reds (moot: the round-9 frames they came from are superseded by the
  pixel layer, whose numbers are above), the mood clips re-shot as `build/show-clips/` (done, 30 fps).

### Requests to other streams

- **feel (owner of `game/audio/match_mood.gd`):** a public read of how many `control_changed` events the mood has
  counted (e.g. `func control_changes() -> int`). The capture fill polls `MatchMood._control_changes` through `get()`
  today, because S6 lets the show hear the match only through MatchMood and K5 events; a rename degrades to "no fill",
  never to an error. Not blocking.
