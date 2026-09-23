# The arena as a light show: fixtures, channels, patches and cues

> Owner: the **show** stream (`game/theme/show/`, contract **S6**). Reviewers: **feel** (it owns the materials these
> hooks grow in), **scale** (the arena JSON schema), **control** (the block cutaway must not fight a cue).
> Written 2026-09-20 on `stream/show` at `e3501ef9`, **before any code**, because the whole point of the round is that
> a road stripe or a bridge next round is a *patch*, not a new abstraction.

The lead, verbatim ([game_design.md](game_design.md) *Round 9 addition*):

> *"we should immerse ourselves in this whole arena sporting event, and ideally we could create lighting patterns that
> were consistent with an entertainment event (i.e. imagine light shows in Las Vegas)."*
> *"I would give the guidance to make it beautiful, with the idea that we can easily create desirable lighting effects
> at low compute cost using whatever programming tricks we can."*

**The bar is "make it beautiful" and the check is the frame time.** A human judges the first; `make perf-scene` on
builder0 judges the second, and the numbers it judges on are listed in *How this is measured*.

---

## 1. The four nouns

Stage lighting already has this vocabulary, and it happens to map exactly onto what the Compatibility renderer does
cheaply. Use these words; do not invent synonyms.

### Fixture
**Anything emissive that can be driven.** A city block's lit edges, its window grid, the perimeter neon rim, a
floodlight pool, a sign, a tower beam; later a road stripe, a bridge, a rafter truss.

A fixture is **not a light**. It is an emissive surface *on a mesh or MultiMesh that is already being drawn*, reached
through a material uniform or a per-instance custom-data slot. **Adding a fixture adds zero draw calls and zero real
lights.** If a design wants an `OmniLight3D` or a `SpotLight3D`, the design is wrong for this renderer — find the
emissive form.

A fixture is **whatever exposes the hook** (§4). That is the entire definition, and it is why the abstraction
generalises: nothing in `game/theme/show/` knows what a city block is.

### Channel
**A named signal computed once per frame on the CPU and pushed as one write.** `breathe`, `chase`, `strobe`, `sweep`,
`cycle`, `hold`. A show has **tens of channels, never one per fixture** — eight city blocks breathe on eight clocks
from *one* channel, because the per-instance desync lives in data the mesh already carries (§3).

### Patch
**Which fixtures listen to which channels, in data, per arena** (`arenas/<name>.json`, key `show`). The Terminus, the
yard and a future bridge are patched without code. **A missing `show` key means today's static look** — asserted for
every shipped layout, with the list derived from `arenas/` and never hard-coded (lesson 3).

### Cue
**A programme of channel overrides bound to match state**, with an attack and a release. Selected from
`MatchMood.current().state` (`lull`, `skirmish`, `battle`, `last_stand`, `victory`, `defeat`) and fired by K5 events.

**This is what makes it an entertainment event rather than random breathing.** Idle is the slow breathe; the cues are
the show.

---

## 2. The hard rules

These are not craft. A change that breaks one of them is wrong even if it looks good.

1. **Bake the expensive part once, animate only a scalar** (widget spec §5, §8). Never a blur in the frame loop. A
   glow halo is baked geometry or a baked sprite; the breathing lives in the modulation value. Bake at **full**
   opacity and modulate at draw — baking dimmed and modulating again double-attenuates and the breathe range
   collapses (widget spec §8).
2. **Per-instance variation is per-instance data; whole-fixture values are a uniform** (feel's rule). If a value
   differs between instances it rides `use_custom_data` on the MultiMesh, or a value the mesh already carries
   (`CityBlock`'s `block_seed` in `COLOR.g`, the rim's world position). If it is one number for the whole fixture it
   is a material uniform. **The show never adds a MultiMesh or a light to get variation a channel could carry.**
3. **Zero added draw calls, zero added real lights.** Measured, not asserted: `make perf-scene` before and after on
   the same tree and seed, on builder0.
4. **The instance-uniform ceiling is a first-class number.** `make perf-scene` counts *"Too many instances using
   shader instance variables"* errors and `instance_buffer_pos`. The venue hit that ceiling before the FX rework (246
   per run). **A fixture that pushes a shader over it fails M1 even at the same GPU ms.** Read both counters on every
   before/after.
5. **The core of a fixture never goes fully dark.** `floor > 0` for any channel driving a core surface. A rim that
   vanishes reads as broken, not idle — the widget spec learned this the same way ("the circuit disconnected visually
   every cycle and looked broken rather than idle").
6. **Keep a ceiling below full blast.** The show must not compete with the HUD's alerts or the team accents. The
   widget spec's glow ceiling is `180/255`; ours is per channel and stated in the patch.
7. **Venue lighting must not read as a team** ([art_direction.md](art_direction.md)). Warm and violet, never the team
   cyan or magenta. **The victory sweep in the winner's colour is the one deliberate exception, and it is a cue, not a
   fixture default.**
8. **Neon lives behind or inside things** — never outlines on everything, never a cartoon glow (art_direction.md
   `:42`, `:56`).
9. **Visual only.** The show reads the match and never writes it. It runs on **frame time**, never the tick. Nothing
   in `game/match/`, `game/tank/`, `game/ai/`, `game/units/` or `game/tactics/` may read it.
   **Pre-registered: the sim hash does not move.** If `sim-baseline` moves when the show lands, that is information
   about something else — say so, do not re-record.
10. **Periods 10–25 s, pairwise incommensurate, phases scattered** (widget spec §3). Faster reads as alarm-blinking;
    slower reads as static; commensurate periods make the ensemble visibly loop, and synchronised parallel fixtures
    look like a loading indicator rather than like current. **The validator enforces all three, and it had to: the
    first period bank written for this round was 4:3 to within 1% and the second was 5:4 to within two parts in a
    thousand. Neither was visible by eye in a table.** The ratio check tests `p/q` for `p, q ≤ 5`, not `≤ 4` — at 4
    the second bank sailed through.
    **Periods are a global bank; phases are per arena.** Incommensurability does not depend on how many channels an
    arena uses, so one period table serves every layout. The phase bar *does*: it is half of even spacing, so it
    tightens as an arena patches fewer channels. Phases come from the golden angle taken over **that arena's**
    channel count — a seven-channel set failed the yard's four.
11. **A cue may run a channel faster than a patch may declare one.** Rule 10 governs the *idle*, not a stab of
    strobe: a `last_stand` at a 1.6 s period is the point. The floor is 0.8 s, under which it reads as a fault.
12. **Every visual claim about the show is a PAIR, shot on one frozen frame with `driving` toggled — so the check
    can only ever blame the show for what the show actually changed.** This is not a measurement convenience, it
    is what makes the check *fair*, and it has already earned it twice: the Terminus's brightest feature is feel's
    neon band at shop-window height, which is present in **both** halves and therefore cancels. An **absolute**
    check charges that band to the light show, and the response to it is to dim windows to compensate for a strip
    the show does not own — which is exactly what the first version of the readability gate asked for when it
    failed 22 of 30 frames with no show in them at all. **If you find yourself tuning one of these dials to fix
    something that is in the show-off half too, the check is wrong, not the dial.**
13. **An arm that changes two things at once is not an arm — and the second thing is usually the camera.** Round 9
    ended with three comparisons and *all three* turned out to move something besides the treatment. The
    `--no-strobe` arm swaps programme **and** period (a 1.6 s strobe for a 6.0 s breathe), so its clip is not "the
    venue without a strobe", it is a different rhythm. The parapet/outline pair stopped discriminating the week the
    camera learned to sweep its heading, because the band window at the new heading holds far less building. And
    the "frozen" pair was not frozen, because `FxWorld` runs `PROCESS_MODE_ALWAYS`. **Before believing a delta,
    write down every input that differs between the halves and check that the list has one entry.**

---

## 3. The one formula

Everything in the show is this, on the CPU and in the shaders, and it is deliberately the *same line* in both places
so the headless test that checks the CPU also documents the GPU.

A channel is packed into **one `vec4`** per frame:

| lane | meaning |
|---|---|
| `.x` | **floor** — the level the fixture never falls below |
| `.y` | **span** — `ceiling - floor` (a `hold` channel has span 0) |
| `.z` | **clock** — `TAU * t / period + phase`, in radians, advanced by the CPU from frame time |
| `.w` | **sharpness** — `1` breathe, `~8` a travelling pulse (chase/sweep), `~40` strobe |

```glsl
// game/theme/fx/shaders/show.gdshaderinc — the only waveform in the game's lighting.
float show_level(vec4 chan, float phase) {
	float x = 0.5 + 0.5 * sin(chan.z + phase);
	return chan.x + chan.y * pow(x, chan.w);
}
```

`phase` is the **per-instance** offset, and it comes from data the mesh already carries:

| fixture | its `phase` | why it is free |
|---|---|---|
| city blocks | `block_seed * TAU * spread` | already in `COLOR.g` (`city_block.gd:104`) |
| the perimeter rim | the angle around the ring, `atan(pos.x, pos.z) * spread` | `NODE_POSITION_WORLD`, as the existing flicker already does — and an *angle* rather than the flicker's hash, so a sweep travels **around** the hexagon in order instead of scattering |
| neon signs | `INSTANCE_CUSTOM.a * TAU * spread` | `.b` and `.a` are unused today (`.r` = atlas row, `.g` = flicker seed) |
| floodlight / tower pools | `INSTANCE_CUSTOM.g * TAU * spread` | the pools' custom data is `(1,0,0,0)` today |

**`phase = 0` is the bank-wide value, and it is exactly what the CPU's `Channel.level(t)` returns.** That is the
contract between the two implementations, and the test asserts it.

**Why this keeps the cost O(patch entries):** the CPU evaluates one `vec4` per channel and performs **one write per
patch entry** — a uniform write, or one element of a small uniform array. Eight blocks, six rim edges and forty signs
cost the same as one of each. Patch entries are **tens**; instances are **hundreds**. The test asserts writes per
frame equals bound patch entries, and it is the test that keeps this true when someone later adds a fixture.

### The programmes

| programme | sharpness | span | what it reads as |
|---|---|---|---|
| `hold` | — | 0 | a constant at `floor`. The off switch, and the default for anything unpatched |
| `breathe` | 1 | > 0 | the idle. Slow swell and fade, periods 10–25 s |
| `chase` | 8 | > 0 | a narrow pulse. With per-instance `phase` ordered along the bank it *travels* |
| `sweep` | 3 | > 0 | a wide wave running around the ring; a chase with soft shoulders |
| `strobe` | 40 | > 0 | a short bright stab per period. Reserved for `last_stand`; never the idle |
| `cycle` | 1 | > 0 | `breathe` plus a colour walk on `show_color` / `show_color_mix` |

Colour is **not** per-instance: a cue writes `show_color` and `show_color_mix` as two more uniforms on the same
fixture. Per-instance colour would need a second custom-data lane and buys nothing the phase does not.

---

## 4. The hook a fixture exposes

A fixture is whatever accepts this. There is no base class and no interface to implement — the show writes shader
parameters, and a fixture is a thing that has some.

```
Fixture registration (once, at build time, from the arena's patch):
    show.bind(selector, parameter, channel_name)

    selector   a StringName naming a fixture in the venue: &"rim", &"city_block", &"signs", &"pools"
    parameter  which of that fixture's uniforms this channel drives: &"level", &"edge", &"window", &"shop", &"color"
    channel    the channel's name in the arena's `show.channels`

Per frame (Show._process), for each bound entry:
    material.set_shader_parameter(uniform_for(parameter), channel.packed(t))
```

**Naming convention, and it is load-bearing:** every uniform the show writes is prefixed **`show_`**. Grep for
`show_` and you have the complete list of what the light show touches. Anything without the prefix belongs to feel or
to control, and the show never writes it.

| parameter | uniform | type | default (= today's look) |
|---|---|---|---|
| `level` | `show_level` | `vec4` | `(1, 0, 0, 1)` — floor 1, span 0: a constant 1.0 |
| `edge` | `show_edge` | `vec4` | `(0, 0, 0, 1)` — floor 0: no emissive edge, today's pale albedo alone |
| `window` | `show_window` | `vec4` | `(1, 0, 0, 1)` |
| `shop` | `show_shop` | `vec4` | `(1, 0, 0, 1)` |
| `color` | `show_color` + `show_color_mix` | `vec3`, `float` | unused, `0.0` |
| `spread` | `show_spread` | `float` | `0.0` — every instance in phase; the patch raises it |
| `pixel` (round 10) | `show_pixel` (+ `show_pixel_wave`, `show_pixel_focus`, `show_window_map`) | `vec4` ×3, `sampler2D` | `(0, 0, 0, 1)`, zero wave, `(−1, −1, 0, 0)`, black — see §4c |

**Every default reproduces today's look exactly**, and that is asserted by a screenshot diff at the lead's pose, not
by reading the code.

---

## 4b. Recipes: how to actually add one

The lead asked for the abstractions by name, and §1–§4 are the abstractions. This section is the other half — **what
you type.** Each recipe is the whole change; if you find yourself writing more than this, the thing you are adding
probably is not a cue or a fixture.

### Add a cue — ten lines, all of them data

A cue is channel overrides bound to a mood state. It goes in `game/theme/show/cues.json`; **no code changes, no new
file, and it applies to every arena that declares a channel by that name.** To make the venue surge when the match
tips into `battle`:

```json
"battle": {
  "attack": 1.2,
  "release": 2.5,
  "set": {
    "rim":     {"programme": "chase",  "period": 5.5, "floor": 0.70, "ceiling": 1.25},
    "edges":   {"programme": "sweep",  "period": 7.0, "floor": 0.30, "ceiling": 1.00},
    "windows": {"period": 11.0}
  }
}
```

That is it. Things worth knowing before you write one:

- **The key must be a `MatchMood` state** (`lull`, `skirmish`, `battle`, `last_stand`, `victory`, `defeat`) or the
  pseudo-state `fight`. A typo is a **load error naming the states you could have meant**, not a cue that never
  fires — which is the failure this validator exists to prevent.
- **Anything you do not mention is left alone.** `{"period": 11.0}` changes the tempo and nothing else.
- **You cannot escape the arena's floor and ceiling.** `ShowCues.blend()` clamps every override into the band the
  patch declared, so no cue can take a core fixture dark or to full blast. Ask for `"ceiling": 9.0` and you get the
  patch's ceiling.
- **`attack` and `release` are seconds**, and they are why cues do not pop. A period change *retunes* the clock
  rather than recomputing it, so a 24 s breathe becoming a 1.6 s strobe changes rate without tearing.
- **A cue may run faster than a patch may** (down to 0.8 s): rule 10 governs the idle, not a stab of strobe.
- **`"color": "winner"`** is the one team-coloured thing in the venue and resolves at runtime. A hex here would be a
  venue colour and must obey §8b's bars: **no cool white, no red.**

**An event cue** is the same shape under `"events"`, and its `min_weight` is load-bearing: `FxWorld.spectacle` fires
on every *hit*, so `1.0` means kills only. See §8b.

### Add a fixture — three steps, and step 1 is usually the only real work

A fixture is any emissive surface already being drawn. **Adding one must not add a draw call, a mesh or a light** —
if it does, it is not a fixture.

**1. Give the shader the hook.** Include the one waveform and declare the uniforms with **identity defaults**, so
the surface renders exactly as it does today until something patches it:

```glsl
#include "res://game/theme/fx/shaders/show.gdshaderinc"
uniform vec4  show_level      = vec4(1.0, 0.0, 0.0, 1.0);   // SHOW_IDENTITY: a constant 1.0
uniform float show_spread     = 0.0;                        // per-instance phase scale
uniform vec3  show_color      : source_color = vec3(1.0);
uniform float show_color_mix  = 0.0;

// ...then multiply what the surface already emits:
ALBEDO = mix(color, show_color, show_color_mix) * ... * show_value(show_level, phase);
```

**`phase` must come from data the mesh already carries** — a per-instance `INSTANCE_CUSTOM` lane, a vertex colour,
or world position. Never a uniform per instance, and never a new MultiMesh to get variation (§2 rule 2). If you are
*adding* a term rather than modulating one (as the blocks' parapet does), its identity is `SHOW_OFF`, not
`SHOW_IDENTITY`, and it adds to `EMISSION` rather than multiplying.

**2. Register the driven object — once per material, never once per instance:**

```gdscript
var show := Show.get_instance()   # null on a headless peer, and that is fine
if show != null:
    show.add_fixture(&"my_fixture", material)
```

**3. Patch it** in `arenas/<name>.json`, which is the only place a fixture is switched on:

```json
{"fixture": "my_fixture", "parameter": "level", "channel": "rim", "spread": 1.0}
```

Then `make show-report ARENA=<name>` prints what it resolved to, and `make show-frames` shoots it and **fails if it
makes the fight harder to read**.

### Add a new *parameter* (rarely)

`level`, `edge`, `window` and `shop` cover a modulator and an additive term. A genuinely new one is a row in
`Show.UNIFORMS`, a uniform named `show_<parameter>`, and a decision about its identity — and if it drives a surface
that is lit **today**, add it to `Show.CORE_PARAMETERS` so the validator refuses a patch that would let it go dark.

### What to do when it does not show up

| symptom | first thing to check |
|---|---|
| nothing moves | is the fixture in the arena's `patch`? `make show-report ARENA=<name>` lists every binding |
| nothing moves, and the report looks right | did anything call `add_fixture`? Headless returns a null `Show` by design |
| it moves but every instance together | `spread` is 0, or the shader is not using its per-instance `phase` |
| the cue never fires | the state name — a typo is a load error, so read the error rather than the frame |
| it looks wrong and you cannot say why | `make show-frames` prints every channel's live value beside each frame (lesson 44) |

---

## 4c. Every window addressable (round 10): the pixel layer, the window grid, the effects

The lead: *"basic primitives to adjust individual lights on the building, and couple that with light show effects."*
Round 9 drove each block's windows with ONE number (`show_window`), which can breathe a facade and can never chase,
sweep or ripple ACROSS one. Round 10 makes the unit of the show the individual window.

**Why a texel and not a MultiMesh.** The windows are not geometry: `city_block.gdshader` draws them procedurally from
a bay grid in world metres. There is nothing to instance, so the brief's other option is the right one — **one texel
per window in a small texture the shader samples.** The fragment finds its own texel from what it already has:

| what | where it comes from |
|---|---|
| block | `COLOR.b` = the block's index in the show's grid, k/255 (claimed at `CityBlock.setup`) |
| facade | the world normal: 0 = +x, 1 = −x, 2 = +z, 3 = −z (`ShowWindowGrid.facade_of`, the same tie rule) |
| storey | `floor(world.y / 3.6)`, modulo 16 |
| bay column | `floor(along / bay)`, modulo 32; `along` is world z on an x-facing wall, world x on a z-facing one |
| bay width | `COLOR.a` = an 8-bit code chosen on the CPU: `bay = 3.0 + 1.5 * code` |

The bay width used to be `3 + 1.5 * city_hash(seed)` computed on the GPU. `fract(sin(x) * 43758)` is not reproducible
between float32 and float64, so the CPU could never know where a window was; the CPU now chooses the code (the
block's layout seed, drawn after every value the look already used) and the GPU reads it. **The eight Terminus blocks'
bay widths changed** (still 3–4.5 m; the silhouette did not).

Texture: `ShowWindowGrid.image`, RGBA8, 32 × 1024 (16 blocks × 4 facades × 16 storeys), 128 KB; `r` = the window's
level, `g` = palette override (0 = the block's colour, 1/2/3 = magenta/cyan/amber). All-zero is the identity. It is
uploaded **only on a frame where a window was written** (`flush()`), never per window.

**The pixel layer** (`show_pixel`, parameter `pixel`, identity `SHOW_OFF`): every pane — lit by the art or dark —
can carry a show light in the venue palette, ADDED on top of the art's windows (which keep breathing on
`show_window`). A pane's level is the larger of

1. **a programme evaluated per window in the shader** from the channel and its **wave** (`show_pixel_wave`, written
   only when it changes): `phase = block * 2.4 * spread + row * wave.row + along * wave.along + TAU * hash *
   wave.scatter`, and the window's clock runs at `1 + wave.jitter * (hash2 − 0.5)` of the channel's; and
2. **the window's texel**, written by the CPU only for events;

plus the kill ripple (`show_event`), which now crosses the windows as well as the parapet. `show_pixel_focus` =
(block, facade, map_live, 0) limits the programme to one block/facade (−1 = all) and tells the shader whether the
map holds anything; with the channel off, no event and `map_live` 0 the whole layer is one skipped branch.

**The effects, and what each is in data** (`cues.json`, channel `pixels`; the Terminus patch declares it):

| effect | mood | programme | wave |
|---|---|---|---|
| **Vegas twinkle** (random-walk at a floor and ceiling) | idle (the patch) | `breathe`, sharpness 6, 10.5 s, `[0, 0.9]` | `scatter 1, jitter 0.6` |
| **sweep across every facade** | `skirmish` | `sweep`, 6.0 s | `along −0.25` (25 m band, ~4 m/s) |
| **vertical chase up every tower** | `battle` | `chase`, 3.2 s | `row −0.75` (~2.6 storeys/s), each block on its own beat |
| **strobe on ONE facade** | `last_stand` | `strobe`, 1.6 s | none; `Show` focuses the facade facing the losing base |
| **sweep in the winner's colour** | `victory` | `sweep`, 4.0 s, `color: winner` | `along −0.2` |
| house lights down | `fight`, `defeat` | `hold` 0 | — |
| **kill ripple across the facade nearest the kill** | event | the existing `kill` event, now on the windows | — |
| **floor-by-floor fill** | an objective changes hands | CPU: `ShowWindowEffects.start_fill`, one storey per 0.18 s, hold 1.4 s, fade 1.2 s, amber | — |

A negative per-storey wave travels UP (the peak sits where `clock + phase = π/2`, so as the clock grows the peak moves
to lower phase = higher storey); a negative per-metre wave travels toward +along.

**The primitives, for a new effect:** `CityBlock.window_count()`, `CityBlock.set_window(i, value, palette)`;
`ShowWindowGrid.windows` (each with its world `centre`, `row`, `column`, `facade`, `block`), `set_window(index, …)`,
`flush()`; `ShowWindowEffects.nearest_block(grid, xz)`, `facing_facade(grid, xz)`; `Show.focus_pixels(block,
facade)`, `Show.fire_capture(position)`. **Recipe:** a new SHADER effect is a cue entry with a `wave` (ten lines of
JSON, no code); a new EVENT effect is one function in `window_effects.gd` that writes texels, and one line in
`Show.apply`.

**Cost, structurally:** zero draw calls, zero lights, zero instance uniforms, zero nodes (`tests/test_show_windows.gd`
asserts all four). Per frame: one extra uniform write only when the wave or focus changes; one texture upload only on
a frame an event wrote a window.

---

## 5. Ownership: who writes what

Two writers to one perceived quantity look like flicker nobody can reproduce. Each row below has exactly one writer.

| quantity | owner | everyone else |
|---|---|---|
| **The arena-wide ground wash** | **the show director.** | `AdBroadcast.light_color()` stays the **screens' own local spill** and the director **reads** it as one input. The show never writes the spill; `AdBroadcast` never writes the wash. |
| **The floor's READABILITY — how well lit the fight is** | **scale's lamps, in `terminus.json`** | **the show modulates what is already lit; the `pools` channel is not the floor's baseline.** Ruled by the orchestrator, 2026-09-20, after feel found that the Terminus's shop-height bands out-compete the fight by *placement* rather than palette. The `pools` channel is the nearest knob and it is the wrong one: if the show lights the floor, the show's dials start gating whether the fight is legible, and a look decision becomes a play decision. |
| Emission and channel values on any `show_*` uniform | **the show** | control never writes a `show_*` uniform |
| A block's **alpha / visibility** (the camera-inside-a-block cutaway) | **control** | **the show never writes alpha, visibility, or the cutaway's own uniform.** Ruled by the orchestrator, 2026-09-20 |
| The **look at channel level 1.0** — every material's base colours, roughness, energies | **feel** | the show is additive only: a hook a material exposes, never a restyle |
| The ad channel's content and its screens' material | `AdBroadcast` | a cue may *ask* it to `post_live`, as K5 already does on kills |
| **The Syndicate airship's navigation lights** | **nobody — they stay steady** | feel's look judgement, 2026-09-20, adopted: *"the Syndicate is the faction that does not flicker"*. A strobing airship would undo the one piece of art direction the lead named by hand (the ivory tower, pristine, no rust). **If a Syndicate cue ever exists it goes on the screens, never on the beacons.** |

**If a faded block is also mid-cue, the cue continues underneath the fade. No special case.** (Orchestrator, S6.)

### The airship makes the ad channel the venue's biggest light (feel, 2026-09-20)
`SyndicateAirship` (`stream/feel` `567a8007`) puts **two screens on the `arena` `AdBroadcast` channel, sharing the
channel's material**, on a 64 m object orbiting 74 m over the arena. The ownership rule does not change —
`AdBroadcast` owns the ad channel, the show reads `light_color()` and never writes it — but the **consequence** does:

- **A `post_live` on a kill is now a venue-scale lighting event.** Neither stream designed it as one. It is probably
  good; it is certainly not small, and the next person to touch either side should know before they find it in a
  frame.
- **It is a MOVING fixture, so its phase cannot come from world position.** The rim's per-edge phase is
  `atan(pos.x, pos.z)` — the angle around the venue — which is exactly the kind of phase that would slide underneath
  a moving object, giving a sweep that chases the airship around its own orbit. Its pose is a pure function of
  `Match.tick` (one lap in 70 s), so **if it is ever patched, the phase comes off the orbit parameter.**

### Reserved by control
**Nothing on the block material, and that is still true after control changed its mechanism.** Updated 2026-09-20
(second message): control now *does* cut city blocks, and it does it by setting **`visible = false` on the block
body's `VisualSlot` node** (`game/camera/block_cutaway.gd`, `BlockCutaway`) — not the mesh, not a material, not an
instance parameter. `show_edge`, `show_window` and `show_shop` are untouched.

It chose visibility over a per-block alpha **because of the shared-material constraint in §3**: a per-block fade
would have to be an `instance uniform` on `city_block.gdshader`, which is the show's file, so taking it would have
meant editing another stream's shader overnight. A node boolean needs neither.

Three consequences for the show, all from control's own message:

1. **A cut block is not drawn at all, so its cue is invisible, not interrupted.** The channels keep running and
   nothing of control's writes or resets them; when the block is drawn again it comes back **mid-cue**, at whatever
   value the channel is at. That is exactly the orchestrator's ruling ("the cue continues underneath"), and it needs
   no special case here.
2. **`BlockCutaway.cut_blocks() -> Array[String]`** (node names, on the node named `BlockCutaway` under `Main`,
   recomputed per frame) is the S6 signal, and it is polled rather than pushed.
3. **Only solids ≥ 6 m are ever cut** — never cover, because a container between the camera and the fight is
   information. So floodlight footings, signs and barricades are never affected; only the city blocks.

**`--block-cutaway=off` draws the city whole, and `make show-frames` passes it**, or a frame shot to judge how the
block edges read may not contain the nearest block.

The original mechanism, kept because its measurement is the reason the second one exists: control's first fix was to
lift the camera over the roof rather than shorten the boom —
`RtsCamera.clear_pose()`, 21° → 32° to clear a 24 m roof on a 49 m arm, **703 of 4328 poses inside a building before,
0 after**. It fixed the camera being *inside* a solid and not the alley being *unseen*: of those 703, the sight line
to the ground was still blocked by a building in **518** after the lift (down from 700, a 26% reduction) — 518
cameras correctly outside every building, looking at the side of one. Hence the cutaway, with a pre-registered bar of
**518 → under 50**.

Two consequences for the show, both from control's own message:

1. **Roofs are now on screen far more often on the Terminus**, and a block's top face is the least-dressed surface on
   that map. That is a *look* judgement for the show: a parapet edge run is the obvious fixture, and it costs nothing
   extra because the roof cap is already part of surface 0 (`part >= 0.75`). Taken up in §8.
2. **`RtsCamera.cutaway_near()` moves the camera's near plane** so the wall and stands between camera and arena are
   not drawn. It writes nothing on a fixture, but **a rim fixture on the near wall can be clipped away entirely** when
   the camera is outside the perimeter — which is every spawn, at the lead's low pitch. So **the rim's breathing must
   not be the thing that carries match start**; the FIGHT cue lifts the towers and the blocks too.

If control's alley frames later show an occlusion cutaway is needed after all, it arrives as a **named uniform and a
message**, never as a surprise in a merge, and it lands in this table. Assume no cutaway until then.

### The `CyberMaterials.neon()` fixture tag, and why it exists
`CyberMaterials.neon()` caches one material per `(color, energy, flicker)` (`cyber_materials.gd:35-45`), so any two
props that ask for the same triple get **the same object**. Writing a `show_` uniform on a shared cached material
would drive unrelated props across the whole game, silently.

**This is insurance, not a fix for a live bug.** feel checked the callers (2026-09-20) and today nothing collides: the
rim's `(PURPLE, 4.0, 0.05)` is distinct from `prop_wall`'s `(PURPLE, 3.5, 0.05)` and from `city_block.gd:119`'s
`(<block colour>, 3.0, 0.05)`. The one that *can* collide is `arena_dressing.gd:492-500`, where the key is built from
a **per-arena `neon_color`** — so a future arena whose neon happens to match a prop's would fuse them.

**feel landed the fix itself** (`stream/feel` `02e30ac0`), since the signature is feel's:
`CyberMaterials.neon(color, energy, flicker, fixture := &"")`, keyed `neon/<html>/<e>/<f>/<fixture>`. Callers that
pass nothing share exactly what they shared before; the rim asks with `fixture = &"rim"`, so all six edges still share
**one** material — batching and the zero-draw-call rule intact — and nothing else can ever ride it.
**A test asserts the rim's material is not the same object as a wall prop's, and that driving the rim leaves the wall
prop's parameters untouched**, so the sharing can never come back by accident.

---

## 6. The data

### A patch, in `arenas/<name>.json` (additive top-level key `show`)

```json
"show": {
  "channels": {
    "rim":     {"programme": "breathe", "period": 17.3, "phase": 0.5, "floor": 0.55, "ceiling": 1.00, "spread": 1.0},
    "edges":   {"programme": "breathe", "period": 21.7, "phase": 2.1, "floor": 0.20, "ceiling": 1.00, "spread": 1.0},
    "windows": {"programme": "breathe", "period": 13.1, "phase": 4.8, "floor": 0.85, "ceiling": 1.25, "spread": 0.6}
  },
  "patch": [
    {"fixture": "rim",        "parameter": "level",  "channel": "rim"},
    {"fixture": "city_block", "parameter": "edge",   "channel": "edges"},
    {"fixture": "city_block", "parameter": "window", "channel": "windows"}
  ]
}
```

Validated by the show's own validator, called from `Arena.validate()` (scale owns the loader; the show owns the
validator and its errors). Every error names the arena, the key and what was expected. A bad patch is a **readable
failure**, never a silent static arena.

`Arena.validate()` does not reject unknown top-level keys, so this loads today and an arena without it is unchanged.

### A cue, in `game/theme/show/cues.json` (one book, every arena)

A cue is channel overrides plus an attack and a release, keyed by mood state, with event cues beside them.

```json
"states": {
  "lull":       {"attack": 2.0, "release": 3.0, "set": {"rim": {"period": 17.3, "ceiling": 0.85}}},
  "battle":     {"attack": 0.6, "release": 2.0, "set": {"rim": {"programme": "chase", "period": 6.0, "ceiling": 1.0}}},
  "last_stand": {"attack": 0.3, "release": 2.5, "set": {"rim": {"programme": "strobe", "period": 1.6}}},
  "victory":    {"attack": 0.5, "release": 4.0, "set": {"rim": {"programme": "sweep", "color": "team"}}}
},
"events": {
  "kill": {"attack": 0.15, "release": 1.2, "ripple": {"fixture": "city_block", "parameter": "edge", "speed": 70.0}}
}
```

**A cue never drives a channel outside its floor/ceiling** — the patch's floor and ceiling are the clamp, and the cue
moves within it. That is what stops a cue from blowing past rule 5 or rule 6.

**Attack and release are why cues never pop.** A cue change ramps the packed `vec4` over `attack` seconds and back
over `release`; the clock lane (`.z`) is never jumped, only its rate changed, so a programme swap does not tear.

### The cue set for round 9

| cue | trigger | what it is |
|---|---|---|
| **FIGHT** | the loading screen drops | house lights down, the rim and the towers up |
| **lull** | `MatchMood` `lull` | the slow breathe. This is the idle, and it is most of a match |
| **battle** | `MatchMood` `battle` | faster, brighter, a chase around the rim |
| **a kill** | `FxWorld.spectacle(position, 1.0)` | a ripple outward across the nearest blocks from the kill position — the crowd's `event_position` pattern, which already exists and works |
| **last stand** | `MatchMood` `last_stand` | a strobe concentrated at the losing base's edges |
| **victory** | `MatchMood` `victory` | a sweep around the rim to the winner's colour. **The one team-coloured cue** |
| **defeat** | `MatchMood` `defeat` | the house going cold |

---

## 7. Where the mood comes from

**Measured, not assumed** (`announcer_booth.gd:49-70`, `audio_defaults.gd`):

- A **windowed** launch with no flags — *the game the lead plays* — attaches a booth by default, and the booth owns a
  `MatchMood` (`announcer_booth.gd:91`). **The show reads that one.** One mood per match, one owner.
- A **headless** or `--mute` launch (`make perf-scene`, the test runner, servers) attaches **no booth**, so there is
  **no mood in the tree**.

**The show never grows a second mood.** It looks the booth up lazily by `CrowdVoice.BOOTH_GROUP`, caches it and
copes with null — the pattern `CrowdVoice._mood()` already uses (`crowd_voice.gd:154`). feel's reason, and it is the
ground-wash rule again in a place where it would be much harder to see: two moods advancing independently from the
same event stream will disagree, and nobody will be able to reproduce it.

**With no booth the show runs its idle** — the patch's breathe — **and the event cues still fire**, because the kill
ripple rides `FxWorld.spectacle`, which exists in every mode that draws the arena. So what a muted run loses is the
*state* cues (battle, last stand, victory, defeat), not the show.

**This is not a behaviour behind a flag the default path never passes** (the trap HANDOFF names three times): the
default windowed launch the lead plays attaches the booth, so the state cues are live in the game he plays. To
measure them, `make perf-scene PERF_FLAGS="--music=on"` attaches a silent booth under `--mute`, so the cue path runs
in a perf capture without unmuting the game.

`MatchMood` is deterministic over events and has no clock of its own (`match_mood.gd:6-9`), so the show cannot reach
the simulation through it.

---

## 8. The fixtures that exist today

Everything below is **already drawn**. None of it needs a new draw call; what is missing is that nothing *drives* it.

| fixture | selector | where | driven this round |
|---|---|---|---|
| **City block edges** (chamfers, bevels) | `city_block` / `edge` | `city_block.gdshader:74-80` — today a pale **albedo**, so "make the edges breathe" means giving them an emissive term they do not have | **yes** |
| **City block windows** | `city_block` / `window` | `city_block.gdshader:65`, `city_windows.gdshaderinc` at `window_level = 1.4` | **yes** |
| **City block shopfronts** | `city_block` / `shop` | `city_block.gdshader:71`, a warm constant `0.35` | **yes** |
| **The perimeter rim** ("a dull neon purple") | `rim` / `level` | `arena_dressing.gd:200-204` (polygon venue), `:492-500` (rectangle); `neon.gdshader`'s fixed `breathe = 0.15` at `breathe_speed = 0.6` | **yes** |
| **Neon signs** | `signs` / `level` | `neon_signs.gd:18-47`, one MultiMesh for every sign. `INSTANCE_CUSTOM.b`/`.a` are written as zero and never read — **confirmed free and unclaimed by feel**. **`COLOR` is NOT free**: `v_color = COLOR.rgb` is the sign's neon colour, so a per-sign colour cue rides custom data too. **The brief's "rafter strip along the stands' top rail" IS this bank** — the signs already crown the grandstands, so it is a patch and not new geometry | **yes** |
| **Floodlight and tower pools** | `pools` / `level` | `_glow_multimesh` `arena_dressing.gd:579`, its own fresh `ShaderMaterial` (**not** cached — safe). **A uniform, not instance colour** (feel): instance colour already carries the per-pool tint, and rewriting a buffer every frame to say one number is the wrong trade at zero draw calls. Phase rides `INSTANCE_CUSTOM.y`; a projectile splat leaves it at 0, which is every splat in phase, i.e. exactly today | **yes** |
| **Block roofs and parapets** | `city_block` / `edge` | the roof cap and bevel are already surface 0 at `part >= 0.75`, so the edge channel reaches them for free -- no new geometry, no new uniform. **Newly worth dressing:** control's camera lift puts roofs on screen far more often | **yes, for free** |
| **Tower beams** | `beams` / `level` | `_build_tower` `arena_dressing.gd:521-576`. `CyberMaterials.beam()` caches on (colour, energy) exactly as `neon()` does on its triple, and `beam_material()` is its only caller in the game — a test fails if a second one appears. Phase is the lamp's angle round the venue, so four corner towers rise in sequence | **yes** |
| **The kit's signs and pools** | `signs` / `pools` | `kit_yard.gd` builds its own MultiMesh per kind on the same two shaders, so the kit's props and the dressing's breathe as **one venue** rather than two | **yes** |
| **Ad screens and their spill** | — | `ad_broadcast.gd`, `ad_spill.gdshader` | **read, never written** (§5) |
| **The ground hazard band and the centre ring** | `ground` / `level` | `arena_ground.gdshaderinc:81-95`. **This is the "road stripe or kerb line" the lead named, and it already exists** — the band inside the walls and the ring around the centre are the arena's floor markings. The hook is one emissive term on `painted`, phase from `atan(p.y, p.x)` so a sweep travels round the band | **stretch, deliberately NOT shipped tonight — see below** |
| **The Syndicate airship's screen** | `airship` | feel builds it | stretch, when it exists |
| **A road stripe / the plaza kerb** | `road` | does not exist yet | stretch — **the proof that the abstraction generalises: a patch, not new code** |

---

### The one fixture that was designed and deliberately not shipped

**The ground.** It is the best remaining fixture — it is the non-building, non-wall case that proves the abstraction
generalises, it needs no new geometry, and the surfaces are already there. The hook is four uniforms and one line:

```glsl
EMISSION += mix(hazard_yellow, show_color, show_color_mix) * painted * show_value(show_level, atan(p.y, p.x) * show_spread);
```
with `show_level` defaulting to `(0, 0, 0, 1)` — off, because the paint has no emission today.

**It was not shipped, and the reason is the reason, not the clock.** The ground plane is **the largest fragment area
in the game**, the include is shared by *three* shader variants (`arena_ground`, `_lite`, `_unlit`) across three
quality tiers, and it is feel's core surface. It is therefore the single place where adding a per-fragment term
without a before/after measurement is most likely to cost frame time — and builder0 went off the network before the
paired control could be run. **Shipping the one fixture that cannot be measured, on the night the measuring machine
died, would be the exact mistake this document's rule 3 exists to prevent.**

It is the first thing to build when builder0 is back, and it should land with its own paired `perf-scene`, not
bundled with anything else.

## 8b. The first strip, and what it changed (2026-09-20)

The first frames went to the orchestrator and to feel the night they existed, which is the whole reason the
following is a design note rather than a post-mortem. **Everything below was found by looking at frames, not by
reading code.**

**The edge emission was an outline, and the fix was not a dimmer one.** `show_edge` is added to `EMISSION` on the
bevel/chamfer branch of `city_block.gdshader`, and **that branch is the silhouette** — so with the chamfers lit the
term can only ever draw an outline, which is `art_direction.md` :56's named failure, *"Neon as outlines on
everything, or a cartoon glow"*. Lowering its energy makes the anti-pattern quieter; it does not make it a different
thing (feel). The street frame is what proved it: at the lead's wide pose the edges read as an aggressive styling
choice, and at street level the same strip is a thick glowing bar across a flat wall with no housing and no seam.

**So the default is the roof parapet only** (`show_chamfer_gain = 0`): a horizontal line along a roofline reads as a
building; a line tracing every corner reads as a wireframe. The breathing that carries the block is
`show_window` and `show_shop` — **light inside things, which is the rule** (:42) and the reference the art direction
actually names (*"lit like a Blade Runner night"*, :31). The full outline is kept as the **`outline` style** so the
lead can compare against his own words (*"making the lit edges breathe and glow"*); it ships to nobody.

**Two colours are barred from the venue's fixtures, and the second reason is the better one:**

- **Cool white is not in the palette.** It reads as architectural LED, which makes the city look *new* rather than
  salvaged — and in the first strip it was the brightest thing on screen.
- **Red is a signal in this game, not trim.** Warning lights and beacons are red (`CyberMaterials.RED` on the ad
  screen's beacon and the crate's alarm). Spending it on building edges spends a colour that means *something is
  wrong*.

### The brightness hierarchy is a gate, and it is play rather than taste

`art_direction.md` :72: the arena must be **"lit well enough to read the fight"**. The first strip inverted that —
the brightest pixels in the frame were the building edges and the darkest were the arena floor and the vehicles.

**The fight out-reads the periphery, and `make show-frames` enforces it.** Every frame samples the mean luminance of
a **ring** window (the middle of the frame, where the fight is) against a **band** window (the top, where the blocks
and stands are); `tools/show_luma_gate.py` fails the target if the band wins in any **default-style** frame. The
`outline` variant is exempt — it exists to be compared, not to ship — and a failure in the **BEFORE** arm
(`--no-show`, no patch, every fixture at its identity) is reported as *information about the venue* rather than as
the show's bug, because that arm contains no show at all.

The ordering the hierarchy asks for, top to bottom: **the fight → the window grid → the parapet.** In data that is
the `edges` channel's ceiling sitting under the `windows` channel's floor, which a test asserts for every shipped
patch.

### A strip cannot show a cue

A chase, a sweep and a strobe are **motion**. A still of a chase is a still of a bank of lights; a still of a strobe
caught at its trough reads as *"dimmer"*, which is the opposite of the impression it gives. The first strip
understated `last_stand` exactly that way. **Cues are shot as clips** (`make show-clips`: 60 frames 0.1 s apart,
ffmpeg to a 6 s 10 fps mp4, 720p because motion is the subject); the strip shows the **fixtures**.

### Two runs are not the same run — and it bit three different measurements in one night

Every measurement this stream tried to make by **comparing two runs** was wrong, and each one was wrong for a
different reason that looked like a result:

| measurement | what "two runs" cost it |
|---|---|
| `perf-scene` before vs after, an hour apart | builder0 went from 4 concurrent heavy runs to 8+. **Every** layer cost roughly tripled, including layers the show does not touch (`no_hud` ×5). Delta unusable. |
| `show-perf-pair`, both arms back to back in one slot | Contention swings *within* a slot. **The show-ON arm came out 43% faster than the show-OFF arm** — impossible as an effect, so a measurement of the noise. |
| the luminance gate, a `--no-show` process against a normal one | These frames ride a **live skirmish**, so the vehicles are somewhere else in the other process. The same frames swung by **up to 5 percentage points** between two runs of one commit, and the "failure" it produced had the *outline* variant scoring better than the parapet — backwards, and the tell that it was noise. |

**The fix is the same in all three: get A and B from ONE run.**

- **Timing:** `make perf-scene` alternates `all` and a layer phase *seconds apart* and takes the mean of the `all`
  phases either side. The show is the `no_show` layer (`Show.driving`), off the default `LAYERS` list so no other
  stream's runs lengthen. feel adopted the same shape for the War Rig's hinge the same night, replacing a
  back-to-back A/B that would have produced a number.
- **Frames:** `ShowLook` toggles `driving` on the **paused** scene and captures twice, milliseconds apart — same
  vehicles, same effects, same everything but the show.

**And when the timing is unmeasurable anyway, counts are not.** Real lights, draw calls, `instance_buffer_pos`, the
instance-uniform error count, and whether the shaders compiled at all survive a bad machine completely. On the
contaminated pair, real lights were identical and both error counts were zero — which is most of rule 3, proven, on
a run whose milliseconds were worthless.

### Within one run is necessary and not sufficient — and more samples do not fix a moving machine

The `no_show` layer is the right instrument and it still failed on 2026-09-20 morning, which is worth writing down
because the obvious next move is the wrong one.

Re-measuring on the CP2 roster with builder0 at **load 21 on 12 cores, 67 Godot processes resident**:

| attempt | reported `no_show` GPU cost |
|---|---|
| `PERF_CYCLES=2` (3 `all` phases, 2 `no_show`) | **+1.50 ms** |
| `PERF_CYCLES=6` (7 `all`, 6 `no_show`) | **−0.65 ms** |

**They straddle zero**, and each phase's own GPU spread was **~5 ms** against an effect that should be under 1.5.

**Raising the cycle count did not help, and could not have.** More samples fix *sampling* noise — the error from
having looked too few times at a **stable** quantity. On a box at load 21 the GPU's throughput is itself moving
between one phase and the next, so more samples describe the drift more confidently and converge on nothing.

**So the rule has a second half.** "Get A and B from one run" bounds *when* the two halves are measured; it does
not bound *how quiet the machine is while they are*. Within-run is what stops a 43%-faster-when-slower result; it
is not what turns a sub-millisecond effect into a number. **For an effect near the noise floor you need both: one
run, and a quiet machine.** Ask the orchestrator for the window — it is six minutes of Godot, and the alternative
is a figure that straddles zero and a paragraph that has to be written twice.

**Report the load average beside the number, always.** A layer cost with no load beside it cannot be checked by the
next reader, and on a shared builder that is most of what decides whether it means anything.

### Read the counters in the same JSON before blaming the treatment

`all_gpu` went **7.69 ms → 19.87 ms** between last night and the morning after CP2 merged, and the obvious reading —
*"the resized roster costs 2.6× the GPU"* — was wrong, and refutable from data already in the same output:

| run | vehicles | **primitives** | **draw calls** | GPU ms | avg ms |
|---|---|---|---|---|---|
| `96e10e82` (before CP2) | 68 | **191,206** | **291** | **6.43** | 23.44 |
| `d8a107b5` (after CP2) | 68 | **145,093** | **259** | **20.05** | 99.68 |

**The scene got 24% smaller in primitives and 11% smaller in draw calls, and took 3× the GPU time.** A GPU drawing
less through fewer calls cannot take three times longer unless it is sharing the card — so this is a contended
machine, not a heavier scene, and the counters say so from *inside* the run without needing the load average.

**The general habit:** when a timing number moves, **check the counters beside it before believing the story that
fits.** `primitives`, `draw_calls`, `objects` and `real_lights` are in every `PERF_SCENE` row, they cost nothing to
read, and they are immune to the load that moved the timing. Here they inverted the conclusion in thirty seconds.

**⚠ AND THEN I MADE THE MIRROR-IMAGE MISTAKE WITH THE SAME COUNTER, which is why this section has a second half.**
Having used `primitives` to refute a timing story — correctly — I went on to make a *quantitative* claim from it:
*"CP2 buys 68 vehicles at 145k primitives where it bought 68 at 191k."* **That was wrong.** A quiet-box run on the
same post-CP2 tree reads **180,780 primitives with 63 vehicles** — within ~5% of the pre-CP2 191k, and *more*
primitives with *fewer* vehicles.

| run | vehicles | primitives | draw calls | GPU |
|---|---|---|---|---|
| pre-CP2, quiet-ish | 68 | 191,206 | 291 | **6.43** |
| post-CP2, **load 21** | 68 | 145,093 | 259 | **20.05** |
| post-CP2, **load 0.9** | 63 | **180,780** | 258 | **6.40** |

**The timing conclusion held** — 6.40 against 6.43 confirms the 19.87 was load and nothing else. **The counter-based
claim did not.**

**So the rule has a second half: a counter being immune to LOAD does not make it immune to SAMPLING.** `primitives`
moves with the state of the battle — how many units are alive, how many effects are live, what the camera can see
— and a single run samples one moment of that. Use the counters to **refute a story whose direction is impossible**
(less geometry cannot take three times longer); do **not** read a percentage off them from one run and hand it to
another stream.

### A gate that fails the branch point is not a gate

The luminance rule shipped first as an **absolute**: fail if the block band out-reads the fight ring. Run against a
BEFORE arm it failed **22 of 30 frames with no show in them at all**. At the lead's 21° pose over dark asphalt the
top of the frame is simply brighter than the middle, and it was before any of this existed.

**So the bar is relative: the show must not make the ratio meaningfully worse than the same frozen frame with the
show off.**

**⚠ AND THE FIRST ANSWER THAT BAR GAVE WAS WRONG, BECAUSE THE RING WINDOW HAD NO FIGHT IN IT.** It read
*"−2.6% to +7.4%, mostly positive — the show makes the fight marginally easier to read"*, which was a true
measurement of bare asphalt: the frame tools never passed `--budget`, so every run fielded **five units a side**
instead of ~30, and a 3-second warmup left those five on their spawn line 86 m from the camera.

**Re-run against a real army — 34 a side, 11–23 vehicles in every frame — the effect is essentially ZERO:** 35 of
36 frames inside the bar, scattered both ways, median near zero. The ratios themselves moved from ~0.80 to ~0.93
on `terminus/wide` once real vehicles were in the ring, which is the clearest evidence that the old numbers were
measuring the wrong subject.

**So `vehicles_in_frame` is printed with every capture and `tools/show_frame_gate.py` refuses a set containing an
empty frame — and it runs BEFORE the luminance gate**, because a ring window with nothing in it makes the
luminance gate meaningless rather than merely wrong.

Three cautions that outlive this round:

- **Check the frame contains its subject before trusting the number.** A measurement of the wrong thing is not
  noisy, it is confident and wrong, and it looks exactly like a result.

- **Say which statistic you are gating.** feel's observation was *"the brightest pixels in the image are the
  building edges"* — a **maximum**. The gate measures a **mean** over two windows. Both are reported per frame now;
  a passing mean does not answer a claim about maxima.
- **Check the control against itself before trusting a failure.** The first failing run had the *outline* variant
  scoring better than the parapet. More lit silhouette cannot help the fight out-read the periphery, so the
  measurement was wrong before the result was interesting.

### A frame-mean cannot tell you whether a strobe reads

Four attempts went into making a number answer *"does the `last_stand` strobe read?"*, and the fourth is the one
that should have been obvious:

1. **Band-window swing:** 2.9% with the strobe on, 2.9% off. The band is the top of the frame; the rim, beams and
   signs that strobe are largely outside it. *Wrong window.*
2. **Whole-frame swing at 10 fps:** 1.9% vs 1.6%. **The clip was aliasing.** At sharpness 40 over 1.6 s the stab is
   above half its span for **8.4% of the cycle — 0.134 s** — so at 10 fps ~1.3 frames land inside each stab and
   almost never at its peak. *The clip was sampling the gaps between flashes.*
3. **Whole-frame swing at 30 fps** (what the player sees, since the game targets 30): **2.4% vs 1.9%.** Real, but
   barely above the still-pair null, and **there is no null for this statistic** to compare it against.
4. **The reason it will never be much better:** the swing is a **frame mean**, and the strobing fixtures occupy a
   small fraction of a frame centred on the fight. A strobe's visibility is *local contrast on the thing that
   strobes*, not the average brightness of the picture.

**So the clip is the measurement and the number is the sanity check, not the other way round.** That is what clips
were shot for; it took four tries to stop arguing with the medium. Report the swing with its frame rate beside it,
and let a human watch.

### Shoot an event cue where it has headroom

The first strip took the kill ripple under the `battle` cue, where the edge channel sits at **0.96 of a 1.00
ceiling** — there was nothing left to ripple into, and the frame was indistinguishable from the battle frame. The
ripple is now shot **against the idle, at three wavefront ages**. The general rule: *an additive effect is invisible
on a channel that is already near its ceiling, so measure it against the quiet state, not the loud one.*

## 9. How this is measured

| claim | the check |
|---|---|
| zero added draw calls, zero added lights | `make remote T=perf-scene` before and after, same tree, same seed, **builder0**: draw calls, primitives, real lights, pooled lights |
| within the frame budget | `p99_ms` in a `--perf-capped` run against the lead's **locked 30 fps at 1080p with 30 a side**; capacity uncapped (M1, `fx_tricks.md`) |
| no shader-instance ceiling regression | the *"Too many instances using shader instance variables"* count and `instance_buffer_pos` on the same before/after |
| the sim never moved | `make sim-baseline` green on the current `main` hash — **pre-registered** |
| level 1.0 is today's look | a screenshot diff at the lead's pose on `terminus` and `yard` |
| it is beautiful | **a human. There is no other check** (lesson 19). Frames go to the orchestrator the day they exist, not at the end of the round |

**Every number carries its commit and its machine.** builder0's Iris Xe is ~2.3× the laptop's GPU and ~2.75× its CPU,
so a builder0 number is not a number about the game the lead plays.

**⚠ And "the same machine" means the same machine AT THE SAME LOAD.** A before/after an hour apart on a shared
builder is not a paired measurement: on 2026-09-20 the two runs straddled builder0 going from 4 concurrent heavy
runs to 8+, and **every layer cost roughly tripled, including layers the show does not touch** — `no_hud` ×5,
`no_pool_lights` ×9. The delta was unusable and reported as such rather than as a regression.

**The control that works on a loaded machine is `--no-show`** (`make show-perf-pair`): `Show.get_instance()` returns
null, no fixture registers, every material keeps its shader defaults — and those defaults *are* the identity — so
the venue renders exactly as it did before the show existed, on the **same binary, the same import cache and the
same machine, minutes apart in one slot**. Contention drifts slowly relative to a pair, so the paired delta survives
what an absolute number does not. This is orchestration.md lesson 22 in a new place: **a control that cancels the
cause, not more seeds.**

**What survives a bad machine, and what to lean on when the timing does not:** counts. Real lights, draw calls,
`instance_buffer_pos`, the *"Too many instances using shader instance variables"* count, and whether the shaders
compiled at all. On the contaminated pair above, *real lights was identical and both error counts were zero* —
which is most of rule 3, proven, on a run whose milliseconds were worthless.

The lead's pose, for every frame: **21° pitch, FOV 35, 49 m.** Not 12° — that is the camera he played and rejected.

---

### The last run of round 9, and what it is worth (`c83117dc`, builder0, 2026-09-20 16:21–16:58)

**This is the run every number below the round-9 line comes from, and it is weaker than it looks.** Read this
before quoting any of it.

**What the run did right.** 26 frames, two arenas, every one of them a real fight: Terminus 39 vehicles in the wide
pose and 12 in the close, yard 37 and 16, contact confirmed before the first shutter (`closest_gap_m` 59.6 and 59.3
against a 60 m bar, after 115.8 s and 70.8 s of waiting). Pitch 21.0 on every frame, no lift, `sight_blocked` false
throughout. 15 uniform writes a frame at idle, 16 while a kill ripple runs, 25 on the victory sweep. Shader errors:
zero, on a real GL context.

**What the run cannot tell you: whether the show changes the picture.**

| | |
|---|---|
| on vs off, 26 frozen pairs | between **−3.0%** and **+3.3%** |
| the same frame shot twice, nothing changed | median 0.2%, p95 1.1%, **worst 2.8%** |

**The whole spread of the result sits inside the null's own worst case.** The gate passes — no frame is more than
3.0% worse with the show on — but passing a bar that the noise alone can nearly clear is not evidence that the show
is harmless, it is evidence that this instrument cannot see the show at this band width. Say "not measurable",
never "no effect".

**And the pair was not frozen.** `FxWorld` runs `PROCESS_MODE_ALWAYS` (`fx_world.gd:115`), so it kept ticking
through the pause between the two halves of every pair in this run. `06f8ca0b` disables both `FxWorld` and `Show`
across the pair and sets `SETTLE_FRAMES`, and **it has not been shot**. Every luminance number above is measured
through that leak. Re-shooting is the first action of round 10.

**Two comparisons in this run are broken, in the way rule 13 describes:**

- **Parapet vs outline no longer discriminates.** 0.00% to +0.35% across six pairs, against a 2.8% null. An
  earlier run of the same pair read +7.3% to +13.5%; what changed in between is not the lighting, it is that the
  camera learned to sweep its heading toward the fight, and the band window at the new heading holds far less
  building. **The two PNGs are still the right thing to put in front of the lead — the number beside them is not.**
- **The strobe arm changes the rhythm too.** `STROBE_ALTERNATIVE_PERIOD_S = 6.0` against a 1.6 s strobe, and the
  clip is 6.0 s long, so the "off" arm shows under one cycle of a slow breath. That is why its floor is 25% darker
  (0.0822 vs 0.1101) and its full-frame swing is *larger* (12.4% vs 8.7%), which is the opposite of what a strobe
  should do. **As a look the constant is defensible** — its comment says *"urgent, but not a fault light"*, and
  that is a real alternative. **As an arm it is not**, because it moves two variables, and the call site describes
  it as "a fast breathe" while 6.0 s is not fast. Shoot the arm at the cue's own 1.6 s and keep 6.0 s as a third
  look. Left unchanged here only because changing it means re-shooting the clips, which round 10 does anyway.
  **Fixed in round 10:** `soften_strobes()` now keeps each strobe's own period (a 1.6 s breathe against the 1.6 s
  strobe: sharpness is the only variable); `STROBE_ALTERNATIVE_PERIOD_S` is gone, and `soften_strobes(6.0)` still
  gives the slow look as a third arm if anyone wants it.

**The five mood clips in `build/show/clips/` are from 05:47–05:56, not from this run.** `make show-clips` was not
in the run's target list, so they are the ones shot before the frame tools learned to wait for contact — five units
a side, three seconds in, the squads still on the spawn line. **Do not send them to the lead as the show.** The
stills in `build/show/` (16:46) are the real fight; the clips are not.
