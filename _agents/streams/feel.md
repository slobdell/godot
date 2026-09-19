# Stream: feel (the arena is a place, and it is full of people)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*, *The arena*), [../workstreams.md](../workstreams.md) (you own **M1**, **M3**, **K4**, **K5**,
> **L5**, **C6**), [../art_direction.md](../art_direction.md), [../slot_contracts.md](../slot_contracts.md), and
> round 5's reports in [archive/round5/](archive/round5/) — `render.md` and `audio.md` are both yours now, and their
> saved baselines are in [references/](references/) (`fx_tricks.md`, `perf/`).
>
> **You own** `game/theme/**` (materials, shaders, effects, props, the crowd's MultiMesh **and its voice**),
> `game/audio/`, `game/announcer/`, `assets/{announcer,audio,music}/` and the art paths, `tools/{assets,announcer,
> audio}/`, `mk/{fx,assets,announcer,audio}.mk`, `export_presets.cfg` art filters,
> `_agents/{art_direction,slot_contracts}.md`.
>
> **Round 5's render and audio streams fold into you.** The frame-rate fight is won — the lead did not mention it once
> this round — so the remaining presentation job is whether the arena feels like a place worth fighting in.

## The lead's direction (2026-09-18, verbatim)

> *"On the look and feel side, I notice that the background / ambient crowd in the stands is non-existent."*

> *"the lower camera angles look good because we actually get to see the vehicles"* (control owns the camera; you own
> what it finds when it gets down there)

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

**Start here, because it changes the whole brief: the crowd already exists, and it shipped four days ago.**

- `game/theme/fx/crowd_system.gd` — one MultiMesh of billboard quads, one draw call, `PER_TIER = {LOW 900, MEDIUM
  1800, HIGH 4000}`, seats generated from the stands' rows (0.85 m spacing, 0.85 occupancy), reacting to
  `FxWorld.spectacle` (kills roar, hits ripple), with 6% of fans in team neon. Shader
  `game/theme/fx/shaders/crowd.gdshader`, atlas `game/theme/cyberpunk/crowd/crowd_atlas.png`.
- `game/theme/cyberpunk/arena_dressing.gd` — grandstand modules (`kit_stands`, ~23 m each, roof 15.7 m) tiled along
  the **north and south** walls, 5 seat rows per module, gates east and west, floodlight towers at ±112, ad screens,
  neon signs, container barricades. `HALF = 121`.
- `game/theme/audio/crowd_voice.gd` (round 5) — looping `crowd_murmur` plus `crowd_cheer` roars on the bed bus,
  `MURMUR_DB -30 → -14`, `ROAR_DB -9`, floor driven by `MatchMood` intensity. The WAVs exist.
- It landed 2026-09-14 (`74ab6fff`, *"the gladiator venue with a cheering crowd"*).

So **the code path is not the missing piece, and "build a crowd" is the wrong first move.** Something is stopping the
lead from seeing or hearing any of it, and finding out what is X1. The standing hypotheses, in order of suspicion:
the stands sit outside ±121 m and the camera's default vision framing never includes them; the fog (`density 0.0012`
plus height fog, flat near-black background, no skybox) eats them at that distance; the crowd tier is LOW on his
machine; the murmur is 30 dB down under gunfire; or trip-up 74 bit again (a QOA-compressed loop repeating its first
fifth). **Do not guess — instrument it, then look.**

The environment is `game/theme/cyberpunk/arena_environment.tscn`: no skybox texture, flat near-black background
(`#030307`), ambient from sky colour, ACES tonemap, glow, depth fog `0.0012`, height fog, one `Moon` directional light
(energy 1.7, shadow max 110 m).

## Backlog (in order)

**X1 — find out why the lead sees no crowd, before changing anything.** Take screenshots at the camera poses a player
actually gets (including the low angles control is moving toward), with the crowd soloed and the fog off, and *look at
them*. Report what you find as a diagnosis with an image: "the stands are behind 40 m of fog at the default frame" is
a finding; "added more crowd" is not. Same for the audio: record a real match with the `crowd` solo layer and listen
(lesson: round 5's music played once and went silent while every unit test passed — it was only caught by recording a
real match).

**X2 — make the crowd read from the player's camera.** Whatever X1 finds: the stands and their people must be visible
and alive from the angles the lead plays at. Likely work — bringing the stands closer or raking them higher, fog and
tone-mapping that doesn't swallow them, a crowd density that survives the LOW tier, brighter/larger figures at
distance, movement that reads at 50–200 m (a shimmer of motion beats individually animated people). Hold the budget:
**a locked 30 fps at 1080p with 30 a side** (M1), and the crowd is one draw call today — keep it that way.

**X3 — make the crowd react, audibly.** The murmur bed under everything, swelling with `MatchMood`, a real roar on a
kill or a last stand, and a drop into tension during a lull. It exists; make it audible under gunfire without fighting
the announcer. ElevenLabs credits are available for better crowd beds under the standing gate: **approve the text,
pilot cheaply, listen, then batch** (lesson 19 — the announcer shipped a version that passed every automated check and
was obviously wrong to the first human who heard it).

**X4 — the arena as a place.** With the camera coming down to 25–50°, the eye now lands on the horizon, not the floor:
the stands, the gates, the towers, the screens, the sky. Check what that reveals — the flat near-black background may
need a real skyline or a skybox now, props may need silhouettes that read from low down, and the ad screens (live
match content during the fight, ads between — the lead's ruling) should be legible from a playing angle. Work with
control: their `make camera-looks` page is the same screenshots you need.

**X5 — the loading screen's voice.** control builds the loading mechanism and its progress; you give it something
worth looking at — faction art, the matchup, the arena, and an announcer sting or crowd bed under it. Coordinate; do
not build the screen yourself.

**X6 — keep the frame.** You inherit M1. Anything added this round is measured with `make perf-scene` / `make
audio-bench`, and the numbers carry their commit and machine. `make perf-scene` runs with `--mute`, so its frame
numbers contain no audio at all (trip-up 76).

**X7 (stretch) — the Syndicate's weapons still sound cartoonish** (the lead, round 5, specific to the energy/laser
family and not the pipeline — he called the same batch "awesome" on the Condemned). "Laser" is the most cliché prompt
in sound design and reaches straight for the 1950s ray-gun: prompt for the physical event instead — a capacitor bank
discharging, an arc flash, a transformer failing — and avoid pitch sweeps entirely.

**X8 (stretch) — impacts and payoff cues.** Once combat's shorter engagement ranges land, flanking pays off in rear
and side hits: a weak-spot hit should *sound and look* like a reward. combat provides the event; you make it land.

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `make perf-scene`, `make fx-bench`, `make audio-bench`, `make vehicle-gallery`, `make announcer-demo`,
  `make web-smoke` (the web build must still boot and stay lean).
- **Look at the screenshots and listen to the recordings.** For anything subjective a human is the only check that
  counts (lesson 19) — put cheap samples in front of the lead through the orchestrator before any expensive run.
- You **must not** move the sim baseline (invariant 2). Art and sound never change the simulation.
- Remote screenshots can silently repeat one frame on builder0 (trip-up 65): if captures look identical, check the log
  for `Invalid MIT-MAGIC-COOKIE`.

## Don't touch

`game/ai/**` (nav's and squad's), `game/control/` `game/ui/` `game/camera/` (control's — including the loading screen
itself), `game/units/` `game/combat/` `game/match/` (combat's), `arenas/` `game/arena/` (arena's — you dress what they
place, you do not place).

## Waiting on the lead

1. **Crowd bed audio text**, if X3 needs new ElevenLabs material: approve the text, then a cheap pilot before any
   batch. Route it through the orchestrator the day it is ready.
   **Drafted (feel, 2026-09-18), not sent yet.** Order agreed with the orchestrator: the mix fix lands first and the
   lead listens to it; only if the procedural murmur (filtered noise) still sounds like hiss rather than people does
   this go to him. Proposed sources (ElevenLabs sound effects, `eleven_text_to_sound_v2`, ~10 credits a second):

   | id | sound | s × takes | prompt |
   |---|---|---|---|
   | `crowd_bed` | `crowd_murmur` (loop) | 20 × 2 | *A packed open-air stadium crowd of thousands at night, heard from the middle of the arena floor: a dense steady murmur of many overlapping voices, no words intelligible, scattered distant shouts and whistles, a few claps, a big hard concrete bowl. Constant level, no swells, no music, no announcer.* |
   | `crowd_tense` | new lull bed (loop) | 15 × 1 | *A huge stadium crowd holding its breath: a low restless anxious hum of thousands of people, shuffling feet on metal bleachers, a few nervous calls far away. Quiet and constant, no cheering, no music.* |
   | `crowd_roar` | `crowd_cheer` | 5 × 3 | *A packed stadium crowd erupting at a huge hit: thousands of voices rising into a roar within a second, yells and cheers, feet stamping on metal bleachers, then slowly falling back. Real voices only: no whistle sweeps, no music, no horns.* |
   | `crowd_ooh` | new near-miss reaction | 3 × 2 | *A big stadium crowd reacting to a near miss: a collective rising "oooh" from thousands of people that breaks into scattered groans and laughter. Real voices, no music.* |
   | `crowd_stomp` | new last-stand bed (loop) | 6 × 1 | *Thousands of fans stamping on metal bleachers and clapping in a steady rhythm that slowly builds, with a low chanting roar under it and no words. Constant tempo, no music.* |

   Pilot (listen first): `crowd_bed` 1 take + `crowd_roar` 1 take ≈ 25 s ≈ 250 credits. Full set ≈ 90 s ≈ 900
   credits.
2. **No new Meshy models** (88 credits left). Placing and re-dressing existing art is free and expected.

## Status

### Resumed after the quota stop — current state (read this, then the handover below for detail)

- **Green: `42a6bc5f`** (builder0 `make check`: 1138 passed, 0 failed) — unit scale, MG tracers (shell tracer
  rebalanced to 0.7 so it stays over twice any bullet: the first check at 82f99c6e failed `test_fx_tank_shell` on that),
  MG sound, announcer trail-off. Sent to the orchestrator.
- `f7878bdd` (unchecked, small): music-smoke and announcer-record-smoke compare against a same-match control run
  instead of the shared baseline (combat's report: they failed and blamed the music/booth whenever the baseline moved).
- **Announcer, awaiting the lead's ear:** 10 clips in `build/announcer-cuts/` (booth-only and full mix, one pair per
  interruption, 150 s real-pace match on builder0 with the fix). Waveforms: no silence after any cut, largest 100 ms
  drop at a cut 4–9 dB (was a near-total drop in 0.08 s). Not reported fixed until he has listened.
- **combat's `test_it_follows_a_mood_signal` full-suite failure does not reproduce on this tree** (passes in the green
  full check; the 13-file prefix passes 82/0 on the laptop). Replied with a file-list bisect recipe.
- **Arena shape settled: hexagon, flat side to each base** (arena's reasoning; the stands tile it: 6 modules of
  23.07 m on a 139.7 m side). Owed when the stands are reshaped: **the stands' height profile as data beside the kit**
  (control's cutaway reads it; stop them measuring `kit_stands`), and a **gate placement** (below).
- Round 7 (next): a **cityscape arena kit** — the X4 skyline made playable: parameterised blocks, collision and visual
  from one recipe; solid buildings in `navigation_source` on layer 1, low walls barricade-style, everything above eye
  height scenery only; chamfered edges as the finish, decided together with arena's perimeter; budget per StaticBatcher.

### HANDOVER — read this first (2026-09-18, ~21:05, weekly quota about to stop this session for ~4 days)

**Tree:** `stream/feel` is clean at `82f99c6e` (plus this Status commit). **Last green: `b00b8ff9`** (builder0 check,
1130 passed). A full `make remote T=check` on `82f99c6e` was **started ~21:03 on builder0 (`~/tank_squad/godot-feel`)
and its result was not read before the stop**: re-run `make remote T=check` first thing; do not assume green.
Commits since `b00b8ff9`, all tested locally (their test files pass), none check-verified:

1. **`2586c7a6` unit scale from `hull_size` — done.** Cause: `tank.gd:238` (combat's) does not scale a unit's hull when
   it has its own art, so every new-faction model showed at Meshy's 3–4 m (gang_tank drew 3.6 m of 5.6 m, smaller than a
   scout, while its collision box was full size). Fix in `dozer_part._fit_to_hull()`: every part takes one uniform scale
   = hull_size length / the hull model's natural length (`FactionArt.hull_length`), turret/weapon parts undo the turret
   node's scale and rise with the roof. Test `tests/test_theme_unit_scale.gd` (mutation-checked: fails without).
   **Findings for combat (data, not edited):** several models' proportions disagree with `hull_size` width — gang_tank
   (the semi) model is 1:4 wide:long, hull_size 3.0×5.6, so its hit box is wider than it looks after scaling; law_suppressor
   model 1.2×2.4 vs hull 2.6×4.4. Measured table: `build/bench/scale_bench.gd` output (natural model size vs hull_size,
   laptop headless) — rerun it with `.tools/godot-*/Godot* --headless --path . --script res://build/bench/scale_bench.gd`
   (build/ is ignored: copy the script out of build/ if it is gone; it is ~30 lines). Muzzle heights (`muzzle_height`,
   combat's) were set for the unscaled models: shots may now leave from inside a taller hull — look, and ask combat.
2. **`d2076221` machine-gun tracers — done, looked at.** A scout's 10/s at HITSCAN_SPEED 180 m/s left one thin dash on
   screen. `TracerSystem.STYLES.stream` now has its own speed 90 m/s, tail 8 m, width 0.32, intensity 2.4 (burst raised
   too, stays fatter). `fx-shots SHOWCASE=scout_stream` on builder0: 3 tracers in the air gun→target. Test
   `tests/test_fx_mg_tracers.gd`.
3. **`0999d755` + `53b3a84a` machine-gun sound — done, measured, NOT heard by a human.** New ElevenLabs loops (physical-
   event prompts): mg_stream 4 takes × 4 s, twin_mg_stream 3 takes (twin_mg had borrowed the single gun's loop),
   plasma_stream re-rolled 3 takes (see below). Spend: 111,816 → 111,416 (410 credits, in the ledger). Gunners get a
   random take each (`GunfireLoops.use_streams(streams, takes)`; SfxSystem exposed only take 1 for loops). Gun loops
   left the Bed bus (5:1 duck by every impact) for a `Gunfire` bus (2:1 dip). **Measured at real pace** (builder0, yard,
   gangs v law, 90 s, `--crowd-meter` now prints `gunfire_db`/`gunfire_world_db` averaged only while a gun sounds):
   before the level change MGs sat a median **15 dB under the mix while firing**; after `VOLUME_DB` −6 → **+2** (at
   `53b3a84a`) a median **4.7 dB under**. Listening sample for the lead: `build/crowd-listen/machine_guns_full_mix.mp3`
   (made at `0999d755`, i.e. BEFORE the +8 dB — regenerate with `make remote T="audio-pass PASS_SECONDS=90 ARENA=yard"`
   and copy build/audio/pass.mp3). Also found and fixed: GunfireLoops voices were created before their bus existed and
   fell back to Master (now `SfxSystem.ensure_world_bus()` first).
   **Pipeline guard (`tools/audio/sfx_layer.py`):** loops are now onset/tail-trimmed and never ship a hole: the longest
   unbroken stretch (no dip > 0.25 s) loops, refused under 1.2 s. It caught the Syndicate's round-5 `plasma_loop_1.wav`:
   **750 ms of silence every 2.2 s** (a stuttering gun, plausibly part of "cartoonish"); refused → re-generated.
   Python tests in `tools/audio/test_sfx_pipeline.py` (`make audio-pytest`, 18 pass).
4. **`82f99c6e` announcer overlap — diagnosed and fixed, NOT heard by a human.** The lead: "The announcers cut each
   others' audio off" / "the other announcer only stops speaking after they've been interrupted".
   **Trace** (builder0, real pace, `audio-pass PASS_SECONDS=150 ARENA=yard`, voiced booth, 31 lines; trace lines
   `ANNOUNCER_CLIPPED` / `ANNOUNCER_CUT` from `announcer_voice.gd`): **no overruns at all** (the director's durations
   come from real clip lengths via `AnnouncerLibrary.line_seconds`), **every clip was a deliberate director interruption**
   (`AnnouncerDirector._interrupt`, priority ≥ INTERRUPT_MIN, sets the incumbent's end to max(now, t+0.4); the booth then
   calls `voice.cut()`, which faded it out in 0.08 s — mid-word). Lost audio: PA `pa.correct.01` 7.66 s, caller
   `caller.hit.04` 1.40 s, colour `color.banter.24` 2.83 s (then clipped again by `caller.kill.60`).
   **Fix:** `AnnouncerVoice` has two players; an interrupted voice ducks 5 dB and fades over `TRAIL_S` 0.8 s on its own
   player while the interrupting line starts on the other (brief natural overlap, then only the challenger). The director
   is unchanged (its stale-drop already exists: `stale_at`). Test `tests/audio/test_audio_announcer_overlap.gd`.
   **Not verified by ear.** Next step: record a real match (`audio-pass`), listen at every `ANNOUNCER_CUT` line's
   timestamp; if interruptions are too frequent, the director's `INTERRUPT_MIN` / `INTERRUPT_LINE_CHANCE` are the knobs.
5. **Gang IFV "drives backwards" — NOT started beyond reading.** The lead: "the gang's IFV drives backwards".
   Established by reading code: the simulation never reads the model (armour faces, muzzle, turret come from the Tank
   body, forward −Z), so **this is art only, not a balance bug** — but muzzle flashes will appear at the model's rear.
   Vehicle galleries were rendered for all three factions to audit orientation (builder0, `vehicle-gallery
   FACTION=<f>`, outputs `build/screenshots/vehicle-gallery-<faction>.png` in `~/tank_squad_feel_look/godot-feel` on
   builder0) but **not yet looked at**. Next step: look at them; for any reversed model add a per-part yaw correction
   (e.g. an exported `model_yaw_deg` on `dozer_part.gd`, set 180 in `game/theme/factions/gangs/parts/ifv_*.tscn`),
   check the turret/weapon parts of the same unit too, and audit every faction, not just the one he noticed.
6. **Not started (queued by the orchestrator):** the crowd beds (text drafted below; the lead's standing approval now
   covers ElevenLabs sound effects — "generate generously, pilot, listen, ship"); chamfered arena edges (cheap, mine);
   the arena *shape* change is a round-7 contract change — do not start it.

**Open findings for others:** camera at the lead's settled pose (21°, 49 m, FOV 35) shows **0 far-stand seats facing
the enemy** (telephoto's top edge is 3.5° below the horizon; the stands' top rows are ~1.5° below at 220 m): the crowd
appears only near walls or when the camera turns — geometry of his camera, not fixable by crowd work. builder0's
shell-playtest reports `ok=false` in every variant from control's faction-click checks (not mine).


_Last updated 2026-09-18 by the feel worker._

### Plan (backlog order; one line of reason where I chose)
1. **X1** diagnose: build an instrument that measures the crowd's own pixels, not a second camera page (control owns
   that); record a real match with the crowd soloed. — **done, below.**
2. **X3 mix half before X2 art** — the audio fix is a gain/bus change, cheap and reversible; the source-material
   question (ElevenLabs text) waits until the mix is proven right (orchestrator's order, agreed).
3. **X2** legibility across the whole 22–50° band, not one pose — the lead has not picked a camera yet.
4. X4 horizon/sky once control's camera lands; X5 with control's loading screen; X6 perf re-baselined **after**
   control's camera merge and combat's CP4 (both move perf-scene's numbers); X7/X8 stretch.

**Headline (builder0, crowd-look, tree `cf6b079a`+, control's camera merged): the game's own default frame now has
3,011 spectators in view — at round 5's default it was 0 of 2,040.** 12° frame with control's real cutaway:
`build/crowd-look-report/x4_12deg_real_cutaway.png`.

### X1 — why the lead saw no crowd (done)
Instrument: `make crowd-look` (`game/theme/fx/bench/crowd_look.gd`, `b80f3161`): a real skirmish, the player's own
frame plus today's zoom slider and control's 22–50° pitch × distance grid, each shot with/without the crowd and fog
(tree paused), reporting seats in view, median figure height in px, and the crowd's changed pixels (noise-masked).
Image for the lead: `build/crowd-look-report/x1_diagnosis.png` (sent to the orchestrator).

**Two separate causes** (builder0, 1920×1080, HIGH tier, Foundry scripted skirmish seed 3, tree at `b80f3161`):
1. **Framing.** The default skirmish pose (zoom 0.45, 52°, 56 m up) has **0 of 2,040** spectators in view. Facing the
   enemy on today's slider nothing appears until zoom 0.70 (65°), where figures are 7 px tall. The home stands sit
   behind the camera. control's pitch decoupling fixes most of this half.
2. **Legibility.** Where the stands are in frame, the crowd *is* there — ~800 figures, 22 px tall, at 35°/60 m facing
   home — but rendered as near-black figures the same value as the stands' metal, 5 sparse rows per module, so it reads
   as structure. Facing the enemy at 22°/90 m it is ~1,400 figures only 7 px tall: they can only read as a mass.
   Fog is not a meaningful cause (crowd pixels barely change with fog off at these distances).

**Audio** (builder0, `b80f3161`, `make audio-pass PASS_SECONDS=90 ARENA=yard`, gangs v law, 30 a side; same match
with `--audio-solo=crowd`): the crowd alone measured **−46.5 dBFS until contact, 20–25 dB under the full mix**, and
−32 to −36 dBFS after contact (still 10–16 dB under) — *before* the 5:1 impact ducking on the Bed bus it also rode. The
murmur is procedural filtered noise (`crowd_murmur.wav`, 4 s). Inaudible regardless of source: **the mix is the
first cause**, fixed and measured before any source-material request.

### Merge notes
No shared files touched. Mine only: `game/theme/**`, `game/audio/loading_voice.gd`, `mk/fx.mk` (`crowd-look`),
`mk/audio.mk` (`PASS_GODOT_FLAGS ?= --disable-vsync`), `perf_scene.gd` layers (`no_sky`, `no_crowd`), tests, docs
(`references/audio/README.md`, `references/perf/`, `fx_tricks.md`).

### What to playtest
`make skirmish` at the default camera: the stands on all four sides should read as a packed, colourful, moving
crowd; the horizon should be a lit city under a smoggy sky; the crowd should murmur under the fight, cheer a
weak-spot hit and roar a kill. Listen: `build/crowd-listen/*.mp3`. Look: `make remote T=crowd-look`.

### Next steps (for whoever picks this up)
- The lead's listen decides the crowd source material (text drafted, pilot ~250 credits).
- If the GPU line starts to matter (the frame is CPU-bound today): the unlit-stands material (priced in fx_tricks).
- When combat's `face` lands on impact events: weight rear hits up so the room cheers a flank.
- Control's two `LoadingVoice` calls.

### Questions for the lead
1. **The crowd recordings** (with him via the orchestrator): is the crowd audible, and does it sound like people or
   hiss? Hiss → the ElevenLabs pilot drafted under *Waiting on the lead* (~250 credits); people → nothing to spend.
2. **Round 5's Syndicate pilot** (X7): do the three energy weapons sound right, and record the other four (~120)?

### Green commits (merge here)
- **`3040ccd9`** — `make remote T=check` on builder0: **1081 passed, 0 failed, `make check exited 0`**; shell-playtest on
  builder0: 0 leak lines, 0 ERROR lines. The sky leak fix and the ground under the near wall.
- **`dae54f8f`** — `make remote T=check` on builder0: **1066 passed, 0 failed, `make check exited 0`**. Everything since
  `e817194a`: X3 real-pace levels, vsync-off audio-pass, X4 sky/skyline/side stands/screens, X5 LoadingVoice, X6
  baseline, X8 cheer, crowd-look on control's camera. Commits after it are Status/docs only.
- `e817194a` — `make remote T=check` on builder0: **1014 passed, 0 failed, `make check exited 0`**. Holds X1, X2,
  X3 (provisional levels) and the spawn-cost fix. Sent to the orchestrator.

### Spawn cost — control's FIGHT-lag profile (done, `90b3cfb9`)
Not per-instance work in `dozer_part` (< 1 ms a part, measured). Every new-faction vehicle's hull VisualSlot first
fills the default `tank.hull` (the Condemned dozer), then swaps in its own art; the dozer is freed, nothing references
its glb, the engine unloads it, and the next vehicle re-reads it from disk (a node trace showed a 70–90 ms gap before
`HullVisual/TankHullDozer` on every law_tank). Fix: `GameTheme.scene()` holds every slot scene it loads.
Laptop, headless, `build/bench/tank_bench.gd` (not committed: build/ is ignored), tree at `b80f3161`, steady state
(instances 2–4): law_tank 106–128 → 0.9 ms, gang_tank 104–125 → 0.8, syn_ifv 104–114 → 1.1, Condemned tank 2 → 0.7.
Request to combat (not urgent): set a new-faction unit's hull slot before its VisualSlot readies, so the dozer is never
built and thrown away (~0.5 ms a vehicle now).

### X2 — the crowd reads (first pass done, `e447c6e5`)
Palette across the whole value range (was all darks), skin-toned heads and hands (atlas G mask), `lamp` 1.8,
9 rows per module at 0.75 m (2,040 → 4,287 seats), tiers LOW/MEDIUM/HIGH 1800/3600/6000, still one draw call.
Frames (builder0, crowd-look, working tree on `b80f3161`): the home stands at 35°/60 m read as a packed, speckled
crowd; the far stands at 22°/90 m (7 px figures) read as a bright mass instead of empty metal. Tuned across the band,
not for one pose: the lead picked 25°/50 m/FOV 60 and control may go to 12°; crowd-look now shoots FOV-60 poses at
15–50°. Perf: not yet measured — X6 re-baselines after control's camera merge (perf-scene inherits its pose).

### X3 — audible crowd (mix done; source material waits on the lead's listen)
Crowd bus → World, dipped 2:1 by impacts (Bed ducks 5:1). `--crowd-meter` prints crowd and World levels each second
with the match clock. **Measured at real pace** (builder0 with vsync off, tree `1badf779`, yard, gangs v law, 90 s,
full mix and crowd-solo of the same seed compared in 5 s windows): at +13 dB over round 5 the crowd sat ~4 dB under
the whole mix (too loud: the loudest bed); at **+8 dB (murmur −22…−11, roars −6/−3) it sits a median 7.5 dB under
(min 5.6)**, with impacts dipping it 2:1 on top in play. Mix −17.5 LUFS, true peak −3.6 dBFS, 0 clipped.
Recordings for the lead: `build/crowd-listen/{full_mix,crowd_only}_real_pace.mp3` (the orchestrator has put them in
front of him). **I can't hear:** whether the procedural murmur sounds like people is his call; the ElevenLabs text
is drafted below under *Waiting on the lead* and is not to be sent until he has listened.

**builder0 recorded every `audio-pass` in slow motion until `3d38ab26`** (~1/10 speed: 8.2 s of match per 90 s; muted
just as slow, so not the audio; `--disable-vsync` → 25.6 s per 30 s). Vsync is now off by default for audio-pass.
Written up in `references/audio/README.md` (round 5's loudness/peak numbers stand; anything about battle density does
not).

### X4 — the arena as a place (sky, skyline, side stands: done; ad screens not yet checked)
- `night_sky.gdshader`: static smog glow on the horizon, clouds lit from below; no TIME, so never re-rendered; nothing
  samples it for light.
- `CitySkyline`: one unshaded ring at 640 m, two layers of towers, lit windows that fade to their average under ~2 px
  (no shimmer), neon signs, aviation lamps. One draw call.
- **Side grandstands** (`50328778`): at the lead's 12° the horizon runs the full frame width and the short walls had
  no stands, so the venue looked one-sided. Three modules per quarter beyond the ad screens; 6,005 seats; one draw.
- Judged at the lead's pose (12°/50 m/FOV 60) and 25°: `build/crowd-look-report/x4_12deg_50m_fov60.png`. Sent to the
  orchestrator. (I flagged a grandstand fascia filling the bottom third at 12°: it was my approximation of control's
  cutaway, not the game — control's real rule cuts it. crowd-look now calls `RtsCamera.pose_at`/`cutaway_near`
  itself; lesson 53.)
- Not yet: the ad screens' legibility from the playing angle.

### After the merge: the sky's texture leak and the void under the near wall (fixed, `3040ccd9`)
- **Leak (mine).** control's `make shell-playtest` (not in `check`) ended with `Texture with GL ID … leaked 5460 bytes`
  ×2 after my X4 merged. 5,460 bytes = one 32×32 RGBA mip chain: the Environment `Sky`'s radiance maps. Confirmed on
  builder0 by toggling only the sky (leak with it, none without). Fix: no `Sky` resource at all; the night sky is an
  unshaded dome mesh (`NightSky`). Verified: no leak lines with the fix. (builder0's shell-playtest also reports
  `ok=false` from control's faction-click checks in every variant, with or without my changes.)
- **Void (mine).** control's cutaway near plane clips every real surface between a camera past the wall and the
  wall, so no mesh can fill that band: it showed the dome's below-horizon colour, which ACES crushed to pure (0,0,0).
  Proved with a red debug colour. The dome now draws the city's ground where each ray meets y = 0 (a floodlit
  concourse, streets, sodium lamps), shared through `city_ground.gdshaderinc` with a new `CityGround` plane out to the
  skyline for cameras that see past the stands.

### "The audio is defaulted to off" (the lead's playtest; fixed, `b00b8ff9`)
The music director and the booth read a missing `--music`/`--announcer` as OFF, and only `make skirmish`/`audio-pass`
passed them: the title's SKIRMISH, the garage's FIGHT and a bare launch came up with no booth (so no match mood for
the crowd), no announcer and no music. `AudioDefaults`: a windowed launch sounds unless told otherwise; headless,
`--mute` and the title's backdrop fight stay silent. `make audio-launch-smoke` (needs a display) drives title →
SKIRMISH → faction menu → FIGHT with no audio flags: fails on the old code, passes on the fix (builder0).
**Unexplained:** silence through `make skirmish` itself does not reproduce (its flags survive FIGHT). Asked how he
launched.

### X5 — the loading screen's voice (done on my side, `1badf779`)
`LoadingVoice`: murmur fades up at FIGHT, a roar as the lights come up, hands over to the match's crowd. **Request to
control** (relayed by the orchestrator): `LoadingVoice.start(tree)` in `LoadingScreen.show_for`,
`LoadingVoice.finish()` when the match is up. FIGHT → playable is ~1.4 s now, so this is a beat, not a bed.

### X7 (stretch) — the Syndicate's weapons: waiting on the lead since round 5
Round 5 already did the work this item describes (`archive/round5/audio.md`, *Reopened 2026-09-17*): the cause was the
mapping (every Syndicate weapon borrowed another faction's sound), fixed with `SfxWeapons`; the energy family re-prompted
as physical events with no pitch sweeps; a 3-weapon pilot (106 credits) on
<https://claude.ai/artifact/RY6mYLNmNsrwPJoJmBUPSn>. **The lead has not answered** whether they sound right and whether to
record the remaining four (pulse cannon, guided missiles, energy hit, sonic emitter; ~120 credits). Carried under
*Questions for the lead*; nothing to spend until he does.

### X8 (stretch) — payoff cues (done on my side)
The weak-spot flare and sting shipped in round 5 (`WeaponFx._weak_spot`: gold flare, sparks, a jet of fire on a shell,
`weak_spot_hit`). Round 6 adds the room: a spectacle of weight ≥ 0.45 (a weak spot is 0.5, a plain hit 0.3) gets a
smaller cheer from the stands (−14 dB, pitched up), and a cheer never cuts a louder roar short. When combat's `face`
(front/side/rear) lands on events, a rear hit can be weighted up the same way.

### X6 — keep the frame (measured at the new camera)
Laptop (the lead's UHD 620), `cf6b079a` (control's low camera merged), 1854×1011, HIGH, 30 a side CPU v CPU, 2 cycles,
laptop shared with other agents: **GPU 18.45 ms; venue 3.54 ms GPU (crowd 1.05, stands/gates/screens ~2.5); sky +
skyline 0.45 ms.** Round 5 measured the venue at 1.35 ms from the old high camera: this is the cost of an arena the
player can now see, not a regression. The frame average (50 ms) tracks vehicle count (100 ms at 67, 25 ms at 23):
**CPU-bound**, so the GPU line (18.5 of a 33 ms locked-30 frame) has headroom. Saved as
`references/perf/feel-r6-venue-1080.json`; priced cuts (unlit stands, venue off, sky off) in `fx_tricks.md`.
