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

**Every default reproduces today's look exactly**, and that is asserted by a screenshot diff at the lead's pose, not
by reading the code.

---

## 5. Ownership: who writes what

Two writers to one perceived quantity look like flicker nobody can reproduce. Each row below has exactly one writer.

| quantity | owner | everyone else |
|---|---|---|
| **The arena-wide ground wash** | **the show director.** | `AdBroadcast.light_color()` stays the **screens' own local spill** and the director **reads** it as one input. The show never writes the spill; `AdBroadcast` never writes the wash. |
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
