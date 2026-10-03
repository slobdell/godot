# Stream: guns (sound he can feel: the guns, where the rounds land, and every event that is silent today)

> Read `_agents/orchestration.md` (the worker contract; lead gate 1 **as answered for this stream below**),
> `_agents/game_design.md` *Round 17 direction* (both of his messages, the measured state) and *Audio: cinematic, and
> alive*, `assets/audio/README.md` (how every shipped sound was made, round by round), `assets/audio/elevenlabs/ledger.md`
> and `sources.json`, `_agents/streams/archive/round4/audio.md` and `archive/round5/audio.md` (the mix, the buses,
> the takes), `_agents/workstreams.md` *Round 17*. You own `game/theme/audio/**`, `game/audio/**`, `assets/audio/**`,
> `tools/audio/**`, `tests/audio/**`, `tests/test_audio*.gd`, `tests/test_sfx*.gd`, `mk/audio.mk`, `project.godot [audio]`,
> and **one carve-out: the sound-selection lines of `game/theme/fx/weapon_fx.gd`** (the `FAMILIES` sound keys, `_sound`
> call sites, and whatever an impact needs to say what it struck — additive, listed in merge notes).

## The lead's direction (2026-10-03)

> *"the sound effects for all the gunfire and possibly explosions are lacking - when we're talking about tanks and
> fighting vehicles we want to assume that if a game player played this game in their living room with a great sound
> system, they'd really feel the action. I've heard AH-64 Apaches, Bradley fighting vehicles, and Abrams tanks all
> firing and in all cases it is awe-inspiring booms. I would expect our tanks to sound more like an Abrams tank round
> going off (those are of course unbearably loud, but we at least want to convey the raw power and kinetic energy from
> these weapons). I mention the Apache and the Bradley because I would expect our IVF's to sound more like this. And
> similarly, our scouts with their light machine gun fire should also have powerful machine gun sound effects. This is
> all heavy mechanized fighting vehicles and the sound effects should reflect that."*

> *"also, we have sound effects for guns firing, I don't know if we also should have sound effects for rounds landing
> (i.e. different sounds for a round hitting the ground or a building versus making a direct hit on a vehicle versus
> hitting the plasma shield versus destroying a vehicle). In general we want good sound effects, and I don't think we've
> invested effort into that. There miht also be other sound effects I'm not thinking of, but we have Elevenlabs credits
> to burn so we should use them"*

Read: he has stood next to these weapons; the standard is **his ears**, on **a great living-room system**, and the
words to design to are *awe-inspiring*, *raw power*, *kinetic energy*. Cinematic exaggeration is the standing pillar, so
the aim is the feeling of the real thing, not its decibels. Mapping: **tanks → an Abrams' 120 mm; the 25 mm / IFV family
→ a Bradley's Bushmaster and an Apache's 30 mm chain gun; scouts' machine guns → heavy, powerful, mechanical; explosions
too.** Then **where a round lands is audible as what it hit**, and **a full audit of what is silent**. **Spend is
authorised** (*"credits to burn so we should use them"*): for sound effects this round you generate on the ledger without
waiting for a tap — production quality, as many takes as a sound needs (memory: production quality over credits; he
limits scope, not spend). His ear still decides the result: the audition page (G4) is how.

## Where things stand (measured at `6adf94bb` on the laptop, from the files — a measurement, not a listening test)

- **Every weapon sound is mono**, 44.1 kHz, 16-bit: ElevenLabs masters (`assets/audio/elevenlabs/masters/*.mp3`, 75
  files, prompts in `sources.json`) layered with synthesised transients by `tools/audio/sfx_layer.py` into
  `assets/audio/layered/*.wav`, listed in the generated `sfx_layers.gd`. The whole sound-effect library cost about 2 000
  credits in rounds 5–6; the balance was ~110 900 on 2026-09-19 (read the current one).
- **The tank's shot has no crack.** `tank_boom` takes 1–2: 77–91 % of the energy below 200 Hz, **under 1 % above 2 kHz**,
  4.0 s, peak −1 dB, rms −15 to −16 dB. A real main gun is a pressure front (a broadband crack with a rise in
  milliseconds), then the body, then a long tail off the terrain. Ours is the body alone. `autocannon_shot`: 85 % below
  200 Hz, 3 % above 2 kHz, 1.0 s. `mg_round`: 0.48 s, almost nothing below 60 Hz. `explosion_big`: 5 s, 5–10 % below 60 Hz.
- **The mix sits the guns low** (`sfx_system.gd` `MIX`): `tank_boom` +1 dB, `autocannon_shot` −6, `mg_round` **−13**,
  `explosion_big` 0; the World bus is trimmed −6 dB under a −1 dB limiter (`WORLD_TRIM_DB`, `LIMIT_DB`); impacts duck the
  bed 5:1 and the gun loops 2:1; the announcer sidechains the whole World bus; 20 world voices, culled below −46 dB,
  stolen by loudness. Every world sound falls off with inverse distance (`UNIT_SIZE` 55, `MAX_DISTANCE` 600) and a
  distance low-pass (`DISTANCE_FILTER`) from a camera that is ~49 m up and never close.
- **Earlier rounds designed for small speakers**: round 3 put the heavy sounds' energy above 200 Hz *for phones*; rounds
  4–6 mixed on a laptop. Nothing has ever been designed for a subwoofer or checked on a full-range system, and nothing
  measures loudness in LUFS or the crest of a shot.
- **Impacts know the weapon, not the surface** (`weapon_fx.gd` `FAMILIES`, `SfxWeapons`): a shell or mortar round that
  misses plays `dirt_impact` whatever it struck (a container, a tower block, water, dirt); **a 25 mm burst or a
  machine-gun stream that misses plays nothing**; a vehicle hit plays `shell_hit_armor` / `bullet_hit_metal` (+ a
  ricochet chance), the weak spot `weak_spot_hit`, the shield `shield_hit` / `shield_down`, a kill `explosion_big`
  (`vehicle_death_*` masters exist). Find out what the impact event carries (collider, prop type, terrain, water) before
  designing the surface table.
- **Instruments**: `make remote T=audio-pass` (the whole mix of a 30-a-side match → `build/audio/pass.{wav,mp3,png,json}`,
  `PASS_FLAGS=--audio-solo=…`), `tools/audio/sfx_montage.py`, `pass_report.py`, `make audio-bench` (script cost; round 16's
  budget is audio ≤ 0.3 ms a frame), `make audio-check`, `make audio-pytest`, `make sfx-generate` (DRY_RUN by default;
  `APPROVED=1` spends; `ONLY=`), `make sfx-layer`.

## Backlog (in order)

- **G1. Separate the three suspects before spending, with one sheet.** `make weapon-sheet` (new): for every weapon and
  impact sound, per take — attack time, crest factor, integrated and peak loudness (LUFS / true peak), the spectrum in
  bands (< 40, 40–80, 80–200, 200–2 k, 2–6 k, > 6 k Hz), duration and tail, channels — **and the same again as it arrives
  at the master in a real fight** (solo the sound through its bus chain in `audio-pass` at his camera distance: what the
  distance model, the low-pass, the trim, the limiter and the ducks leave of it). The finding is which of **source**
  (no crack, no width, no tail), **mix** (level, limiter, ducking, distance) and **format** (mono, no sub layer) costs
  what, per sound, in dB. Put the table in Status and send it to the orchestrator. Do not skip this: twice before
  (rounds 4 and 5) "the sounds are bad" was the mix and the repetition, not the synthesis.
- **G2. The mix lets a gun be the loudest thing in the room.** From G1: a tank shot and a kill at the camera's
  distance arrive near full scale with their transient intact (the limiter must not eat the crack: look-ahead, attack,
  what it does to a shot's first 10 ms); the distance model fits an overhead tactical camera (the fight he watches is
  40–120 m from the listener: he should hear weight there, with distance told by tail and brightness more than by
  level); the machine guns audible as guns under cannon fire; the announcer stays intelligible (he loves the booth: the
  sidechain is retuned, not removed) and the music survives. Before/after `audio-pass` loudness curves in Status.
  Headroom, not clipping: measure true peak at the master across a 30-a-side fight.
- **G3. The three gun families, designed in layers for a full-range system that still reads on a laptop.** Per shot:
  **the crack** (broadband, a millisecond rise — this is what small speakers carry and what "kinetic" means), **the
  body** (the 60–200 Hz punch in the chest), **the sub** (30–60 Hz, felt on a subwoofer, silent on a laptop — it must
  not eat headroom there: check the laptop mix with it in), **the mechanical layer** (the breech, the chain gun's drive,
  links and brass, the action of a heavy machine gun), and **the tail** (the report rolling off the arena's walls and
  the terrain, stereo, seconds long for the tank). Generate new source material for each layer (prompts describe the
  physical event and the recording perspective — "120 mm smoothbore tank gun firing, recorded 50 m to the side, sharp
  supersonic crack then a deep concussive boom and a long rolling echo across open ground" — not "a big gun"; round 5
  learned that prompting the object returns the cliché), many takes, and pick by ear AND by the sheet. Stereo: establish
  first what Godot's `AudioStreamPlayer3D` does with a stereo stream (if it collapses width, the tail and the sub ride a
  non-positional player panned from the shot's bearing, the crack stays positional); `sfx_layer.py` and `SfxSystem`
  carry the layers. The 25 mm is a chain gun: a burst is separate heavy reports with the gun's own rhythm, never a
  buzz; the scouts' machine gun is a heavy gun (weight in each round, the action audible), held loops keeping round 6's
  seamlessness and takes. Explosions: the kill is the biggest event in the game — crack, fireball, debris, tail.
  **The other factions' weapons must not be left weaker than the guns beside them** (the Syndicate's railgun and energy
  family, the Law's sonic emitter, flamethrowers, missiles, mortars): after the three families, the sheet shows who is
  now the weakling; bring each up the same way.
- **G4. The audition page for his ear (early — as soon as the tank has two directions; then add to it).** One
  Artifact page (load `artifact-design` and `artifact-capabilities`; audio as page assets; the `db` capability for his
  taps; C15.2), per weapon family: **today's sound, and two or three new directions**, each playable dry AND in a
  15-second clip of a real fight's mix (from `audio-pass`), level-matched honestly (state the loudness of each), with
  a tap per direction and a note field. One line at the top says what to listen on (his big system first, then the
  laptop). Send the link to the orchestrator. Do not wait for his taps to continue: ship your own best pick as the
  default and make swapping a direction a one-line change.
- **G5. Where the round lands.** The impact says what it struck: **dirt/ground, concrete/building, steel (a container,
  a wreck, a barrier), water, a vehicle's armour (by calibre: a 120 mm on armour is not a bullet on armour), the weak
  spot, the shield, the kill** — for shells, mortar rounds, 25 mm and machine-gun rounds (a stream stitching a wall is
  a sound; so are near misses over the listener: `shell_whine` exists, small-arms snaps do not). Test first: an impact
  on each surface asks for that surface's sound (a table test); rate limits so a 14-rounds-a-second stream is a texture
  and not 14 voices (`CLANK_EVERY`'s pattern); the voice budget and `audio-bench` hold. The surface comes from what the
  impact event already carries; if it carries nothing, the smallest additive read (the collider's group or the prop
  type) — **not a change to combat's event contract** (that is sim's: request it through the orchestrator if you need it).
- **G6. The audit: every event that is silent or borrowing.** Walk a match from the title to the results with the
  recorder's event list beside the sound table and list every event with no sound or the wrong one — candidates:
  secondary cook-off and the burning wreck after a kill, debris landing, a hull scraping a container, a tank crushing
  a barricade, the turret traversing, reloading (the breech, the autoloader), tracks and tyres per surface (`tread_loop`,
  `tire_loop` exist), braking and skids, water (fording, splashes, rounds into water), the swing bridges, shield
  recharge and hum, smoke, artillery bracing and the round's descent before it lands, the airship's engines and PA
  feedback, order acknowledgements per faction, capture and objective events, the planning pause, results. **Rank by how
  often he would hear it in his matches** (count events in his recordings: `build/recordings/`), put the ranked table
  in Status, fill it from the top, and say where you stopped. Each new sound: generated, layered, taken (variation
  pools as round 4), mixed on the sheet, on the page.
- **Stretch.** Arena acoustics as one system (a slap from the stands and the container walls keyed to the shot's
  position; an indoor/outdoor difference on the Terminus's streets); a 5.1 check (`AudioServer` speaker mode) so a
  surround system gets a real LFE; the web build's pack size after the new assets (report MB to the orchestrator: ship
  owns the web preset).

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe), `make audio-check`, `make audio-pytest`, `make audio-bench` (≤ 0.3 ms a frame,
builder0, stated load), `make remote T=audio-pass` before and after each of G2–G5 with the loudness numbers, and
`make audio-launch-smoke`. **Listen to what you ship as far as you can** (render clips; read the waveform and the
spectrogram) and say plainly in Status that you cannot hear: his ear is the only check that counts, the page is the
verification. The sim baseline is UNMOVED by everything here (sound reads the fight, never changes it): pre-register
it, and nothing audio-side may read or write simulation state. Every paid request on the ledger with its credits
before → after. Licence: only what we synthesise or generate — no downloaded recordings of real weapons.

## Don't touch

`game/announcer/**` and the announcer's clips (nobody this round; the sidechain's settings on your buses are yours) ·
the rest of `game/theme/fx/**` beyond the carve-out · `game/match/**`, `game/combat/**`, `game/tank/**` (sim) ·
`game/ai/**` (brains) · `arenas/**`, `game/arena/**` (yard) · `export_presets.cfg`, `mk/web.mk`, `mk/core.mk` (ship).

## Waiting on the lead

- His taps on the G4 page. **What does he listen on** when he plays (the laptop's speakers, headphones, the living-room
  system)? Asked by the orchestrator at launch; until answered, design for the big system and check the laptop.

## Status

_Last updated 2026-10-03 (guns worker). Machine for every number: the laptop unless it says builder0. **I cannot hear
anything: every judgement below is a measurement or a picture; his ear on the G4 page is the check.**_

### Plan (in order; one-line reasons)

1. **G1 the sheet** — the instruments first: the source sheet (files), the probe (each sound alone through the real
   chain, with the limiters / distance filter / trim taken out one at a time), the fight taps (what the limiter and
   ducks take in a real 30-a-side pass). Then the dB table, to the orchestrator.
2. **G3 started in parallel with G1's second half** — the source half of G1 already proved the tank's file and the
   ElevenLabs master under it have no crack (0 % above 2 kHz), so layered material was needed whatever the mix finding;
   generation is network-bound and did not compete with builder0.
3. **G2 the mix** — from the stage table: gain staging, limiter, distance model, gun levels, the booth's sidechain.
4. **G4 the page** as soon as the tank has its directions in a real-fight clip; then add each family.
5. **G3 the rest** — 25 mm (chain gun rhythm), heavy MG (loops), the kill; then whoever the sheet shows is the weakling.
6. **G5 impacts by surface**, **G6 the audit**, then stretch.

### Baseline

`make remote T=check` at the launch tree `3713fdaa` (builder0): **exited 0, 21 targets all passed, 1915 passed /
0 failed**, sim-baseline `05df1d55ba49cde1` (unmoved). Pre-registered: every guns commit leaves it UNMOVED (sound reads
the fight; the only additions to the game path are presentation: SfxSystem, the recorder's taps behind a flag).

### G1 — findings so far (laptop, `8d592ee3`'s tree; probe = one take per sound, centred, Dummy driver)

**Source (the shipped files; `build/audio/weapon_sheet.md`):** every take is **mono**. `tank_boom` (3 takes):
attack 12.6 ms, crest 7.3 dB, **0 % of its energy above 2 kHz**, 39 % below 80 Hz, tail 3.3 s. The ElevenLabs master
under it is the same (0 % above 2 kHz, crack −21.8 dB) although its prompt asked for "a sharp supersonic crack": **the
source has no crack, not just the layering**. ElevenLabs masters are 2-channel files but effectively mono (width
0.00–0.35; the round-17 batch 0.00–0.02 even for "wide, spacious" tails), and `sfx_layer.py` folds them to mono.

**What reaches the master, one sound alone (dB at the camera's focus, 49 m / across the arena, 120 m):**

| | tank_boom | autocannon_shot | mg_round | explosion_big (the kill) |
|---|---|---|---|---|
| file M max LUFS | −11.2 | −18.7 | −18.1 | −14.6 |
| at master, 49 m | −13.0 LUFS, **TP −6.7** | −27.9 | −38.2 | −17.4 (**4.4 dB under a shot**) |
| at master, 120 m | −21.8 | −36.9 | −47.6 | −26.4 |
| crack lost, 49 / 120 m | −2.6 / **−25.6** | **−13.4** / −18.2 | −10.8 / −9.9 | (the file has none) |
| crest lost to the limiter, 49 m | −1.2 dB (30 m: −2.1) | 0 | 0 | 0 |

Stage by stage (each a difference of two recordings of the same sound, `make weapon-sheet`):
- **Trim and limiter (mix):** the World bus's `AudioEffectLimiter` adds **+3 dB make-up** (ceiling − threshold) to
  everything, so the −6 dB trim is really −3; and with threshold −4 / ceiling −1 before the trim, **no sound in the game
  can peak above about −6.5 dBTP at the master** — measured for the tank, the railgun, the MG loops and the shell on
  armour alike, at 30 m and 49 m. ~5.5 dB of the master's headroom is never used by any gun, and the tank shot, a held
  machine gun and a railgun all hit the same ceiling.
- **The distance filter (mix):** Godot scales the filter by the voice's *own* level (its MIX volume × distance gain),
  so quiet-mixed sounds are filtered even close: the 25 mm loses 11.5 dB above 2 kHz at the focus, `mg_round` 10 dB.
  The loud ones lose it with range: the tank's crack −16.5 dB at 80 m and −25.6 at 120 m (1.4 kHz shelf, −22 dB).
- **Level (mix):** inverse distance from UNIT_SIZE 55 plus Godot's linear fade to MAX_DISTANCE 600: −8.7 dB at 120 m.
  The fight he watches spans 40–120 m: a 9 dB swing in level across it.
- **Format:** every arrival has width 0.00 (mono in, mono out).
- **Stereo in Godot (measured, for G3):** `AudioStreamPlayer3D` keeps a stereo file's full width (L/R correlation 0.00
  at 0°, 45°, 90°) and pans it by balance (±3–6 dB): a stereo take can stay positional.
- The machine gun the scouts fire is `mg_loop` through `GunfireLoops` (+2 dB, Godot's default −24 dB / 5 kHz distance
  filter), not `mg_round`; both are on the sheet.

**In a real fight** (`audio-pass --audio-taps`, builder0, the LAUNCH mix and sound — `--sfx-direction=tank_boom:0`,
`443648dd`'s instruments on `3713fdaa`'s mix; Gangs v Law, Foundry, seed 3, 150 s, 30 a side; each tap pair is a bus
before and after its effects, 10 ms windows where the bus is above −45 dBFS):

| stage | median gain | at the loudest 1 % | worst | time > 3 dB down |
|---|---|---|---|---|
| World: limiter (+3 make-up) then the booth's duck | **−16.8 dB** | −18.7 | −34.7 | 33 % |
| Bed: the impacts' duck (engines, small hits) | **−14.5 dB** | −21.4 | −41.8 | 44 % |
| Gunfire: the impacts' duck (the MG loops) | −7.4 dB | −7.2 | −18.3 | 25 % |

The booth speaks **70 % of the match** (110 of 150 s); while it does the battle reaching the master sits a median
**26.5 dB under the voice** (10th percentile 14.4 dB), at ~−40 dBFS; with the booth silent the battle is ~−26 dBFS
(first pass, same setup). The master: −18.0 LUFS integrated, true peak −4.0 dBTP, 0 clipped samples. The World
bus's input peaked at +1.2 dBFS (0.01 % of windows over full scale).

**G1's answer — what costs the guns their power, in dB (at the camera's focus unless stated):**

| suspect | where | cost |
|---|---|---|
| **mix: the booth's duck** | World, −28 dB / 6:1 | **~16 dB off every gun for 70 % of the match** — the largest single cost |
| **mix: the impacts' duck** | Bed, −26 dB / 5:1 | 14.5 dB median off engines and small hits, 21 at the loudest |
| **mix: limiter + trim** | World | every loud sound clamped to −6.5 dBTP at the master; tank crest −1.2 dB (−2.1 at 30 m); 5.5 dB of headroom unused |
| **mix: distance filter** | per voice | tank crack −16.5 dB at 80 m, −25.6 at 120 m; the 25 mm −11.5 dB above 2 kHz at 49 m (filter scaled by its low mix level) |
| **mix: level** | MIX, distance | 25 mm −9.8 dB, MG round −20 dB vs file; −8.7 dB across 40–120 m; **the kill 4.4 dB under a tank shot** |
| **source** | the files | tank: 0 % above 2 kHz, crack absent in the file AND the ElevenLabs master; MG loop take 1 has a 0.4 s dropout |
| **format** | all | mono everywhere (width 0.00); ElevenLabs returns mono even for "wide" prompts; no deliberate sub layer |

Ranked: the mix first (the duck alone outweighs everything), then the source (no crack can be mixed in), then the
format (width and a sub add feel, not level). Rounds 4 and 5 were right to suspect the mix.

### G2 — after (first measurement; builder0, finished 13:16 PDT)

Same match as the before-pass (Gangs v Law, Foundry, seed 3, 150 s, taps). Tree: the one synced when the before-pass
ended = `fe66533b` (G2's limiter, booth duck, distance and levels; NOT yet the Bed/Gunfire retune of `5b2caa2d`).

| | before (launch mix) | after (`fe66533b`) |
|---|---|---|
| integrated loudness at the master | −18.0 LUFS | **−17.4 LUFS** (the game did not get quieter: +0.6) |
| true peak | −4.0 dBTP | −2.5 dBTP (0 clipped samples) |
| World stage, median gain | −16.8 dB | **−5.6 dB** |
| booth over the battle while it speaks, median / 10th pct | 26.5 / 14.4 dB | **10.4 / 2.1 dB** |
| music under the battle while the booth speaks | −3.7 dB | −16.5 dB |
| Bed duck, median | −14.5 dB | −18.0 dB (louder impacts on the old 5:1; retuned at `5b2caa2d`) |
| Gunfire duck, median | −7.4 dB | −10.4 dB (same; retuned) |

Read: the guns get ~11 dB back; the booth's worst 10 % is now within 2 dB of the battle, which risks the caller's
intelligibility; and the music sits much lower under the battle. Both belong to the booth item on the page (his call);
`mix-ab` and the duck arms of `audition-clips` measure each setting on his match.

### G2 — before and after on ONE tree (`make mix-ab`, builder0, finished 14:10 PDT, written 14:11 PDT)

Tree `6b9cb5c0` (synced ~13:40 PDT): the layout fix and every G2/G3 change, booth duck still the LIGHT setting (−20 dB,
2.5:1; MID became the default at `4f3d117c`, 13:41). Launch arm = `--mix=launch --sfx-direction=all:0` in the same
build. 150 s each, taps, N=1 per arm per match.

| | his match (Sumps, Law v Condemned, seed 92721) launch → now | Foundry (Gangs v Law, seed 3) launch → now |
|---|---|---|
| integrated loudness | −17.5 → **−16.6 LUFS** | −18.2 → **−17.0 LUFS** |
| true peak (0 clipped samples in all four) | −3.1 → −1.6 dBTP | −4.3 → −2.4 dBTP |
| World stage, median gain | −15.8 → −4.6 dB | −15.3 → −5.8 dB |
| Bed duck, median | −18.5 → −6.4 dB | −15.1 → −9.9 dB |
| booth speaking | 102 → 89 s of 150 | 101 → 108 s of 150 |
| booth over the battle, median / busiest tenth | 22.0 / 8.3 → 10.6 / 1.8 dB | 21.9 / 10.4 → 11.2 / 2.5 dB |
| music under the battle while the booth speaks | −7.1 → −14.4 dB | −6.9 → −16.4 dB |

**One fight or two (sim's kill-cam finding, checked 14:14 PDT):** on his match the elimination is decided at t ≈ 131 s
(the last kill, then the defeat bed at 131.3 s in BOTH arms), so the 150 s arms carry ~18 s of post-decision tail,
where windowed runs differ (kill-cam time scale). Re-measured over the first 125 s only: launch −17.5 LUFS / −3.1 dBTP,
now −16.4 / −1.6 (the whole-150 s figures above: −17.5 and −16.6): the comparison holds within 0.2 dB. Every 75 s
audition arm ends mid-fight (score 4 : 14, no defeat bed), so the page's 15 s and 20 s cuts are one fight. The kill
cam's slow motion as a sound event (everything should pitch down) goes on the audit list, not chased this round.

Read: the game is ~1 dB louder overall and the guns ~10 dB louder relative to the booth's duck; at the LIGHT duck the
caller is within 2 dB of the battle in its busiest tenth (as the audition's light arm showed), which is why MID is now
the default (audition, 75 s of his match: 14.7 / 2.9 dB). The music sits 7–9 dB further under the battle than before:
its own level is unchanged (−45 → −42 dBFS on his match), the battle is louder. If he wants the music up, that is the
Music bus's level (one constant), his call from the page's whole-game clips.

### G4 — the audition page (C15.2)

**https://claude.ai/artifact/WmGWF4RBCVycueMmUMac9i** (private to the owner; the orchestrator gives him the link).
- v1 published 2026-10-03 before 12:55 PDT (dry only); **v2** before 12:56 PDT (`date` at the next step): Dry clips loudness-matched by default (each gun's list
  turned DOWN to its quietest, never up; a switch turns it off; numbers printed as measured), width reported for the
  TAIL (after 0.15 s) in words (wide ≥ 0.3 / slightly wide ≥ 0.1 / nearly mono / mono), the other factions' weapons
  added, MP3 192 kbps stated (the 30–40 Hz sub survives it: −0.27 dB in every band 20–200 Hz, the encoder's level,
  measured on tank, kill and 25 mm against the WAV of the same preview).
- **v3** published 13:41 PDT: the fight clips (15 s of his match, the same moment in every arm) and the booth item
  (20 s where the caller speaks). Whole game on his match: before round 17 −16.8 LUFS, now −15.2 (louder by 1.6 dB).
  Booth over the battle, median / busiest tenth: launch 21.7 / 8.8 dB, mid 14.7 / 2.9, light 9.6 / 1.5; the caller
  speaks ~76 % of the match. **Default changed to mid** (`BOOTH_DUCK`): the guns gain 6.4 dB, the caller keeps his lead.
- Was pending on builder0: "In the fight" clips (his match: Sumps, Law v Condemned, seed 92721, budget 4600) and the booth
  item (launch −28/6:1, mid −24/4:1, new −20/2.5:1, the same 20 s where the caller speaks over the loudest fight).
- **db paths:** `picks/<family>` {pick, note, at} for tank, 25mm, mg, kill, railgun, twinmg, mortar, missiles, pulse,
  flame, booth; `verdicts/<sound>` {verdict keep|redo, at} for each new single sound.
- **db reads** (times from `date`): 2026-10-03, right after v1, before 12:55 PDT: empty; 13:41 PDT (after v3): empty. (An earlier note said ~13:21: my clock
  estimate, not `date`; corrected.)
- Built by `tools/audio/audition_page.py` (+ `audition_page.html`); defaults marked on the page = `SfxSystem.DIRECTION`.

### G3 — what is designed (laptop, measured from the files)

| sound | default | crack dB | tail width | notes |
|---|---|---|---|---|
| tank_boom | a | −6.9 (today −11, 0 % > 2 kHz) | 0.38 (today 0) | N-wave crack, generated report, 38 Hz sub, breech, paired tail, room, slaps |
| autocannon_shot | a | −4.8 (today −7) | 0.56 | separate reports at the 0.12 s rhythm (looked at: four distinct onsets; b and c smear) |
| mg_loop | a | −14.3 | 0.24 | a crack and a thump on every detected round, 6–12 rounds/s; today's take 1 has a 0.4 s dropout |
| explosion_big | a | −13.9 | 0.32 | blast front, fireball, 30 Hz sub, stereo debris, stadium rumble |
| railgun, mortar, missiles, pulse, twin MG, flamethrower | a | — | 0.12–1.0 | the other factions brought up beside the new guns |

### G5 — impacts by surface (done)

A miss reads what it struck from `Arena.active` (turned footprints via `ArenaKit.distance_to_footprint`, water, the
perimeter): ground / concrete / steel / water × heavy / medium / light, a vehicle hit as armour by calibre; 25 mm and MG
misses (silent before) thinned per spot (`SfxSurfaces.RateLimit`: MG ≤ 1 per 0.2 s per 3 m spot). Energy weapons keep
their own impact sound on misses. Table tests + end-to-end WeaponFx tests (`tests/audio/test_audio_impacts.gd`).

### G6 — the audit (two 30-a-side headless matches, Foundry, 180 s each, `fe66533b`, laptop)

| rank | event | per minute (Gangs v Law / Condemned v Syndicate) | before | now |
|---|---|---|---|---|
| 1 | hard braking (≥ 4 m/s drop in 0.5 s; an upper bound) | 830 / 635 | silent | `track_skid` / `tyre_skid` from EngineSystem, the 4 voiced hulls, 1.6 s cooldown each |
| 2 | hard turn at speed | 268 / 251 | silent | `track_squeal` / `tyre_skid`, same rules |
| 3 | mortar rounds coming down | — / 106 | silent | `shell_incoming`, timed from ArcRoundVisual to end as it lands |
| 4 | kills → burning wrecks and cook-off pops | 76 / 43 kills | silent | FireVoices: the 2 nearest fires loop and burn down, every pop heard |
| 5 | a shield coming back up | 23 / 39 | silent | `shield_up`, once per return from zero (shield_effect.gd line lent, C17.6) |
| — | rounds landing (misses) | 49 / 304 with an impact event | dirt or nothing | G5 |
| 6+ | turret traverse, airship engines and PA, water fording, order acks per faction, capture, planning, results | continuous / arena-specific | silent / generic | **stopped here**: next if time allows |

**On HIS match** (the Sumps, Law v Condemned, seed 92721, budget 4600, 180 s headless, `88793282`, laptop; per minute):
hard braking ≤ 499 · hard turns at speed 73 · mortar rounds landing 38 (each heard coming down) · kills 29 (each a
burning wreck) · shields back up 34 · misses with an impact event 66 (35 of them 25 mm, 11 MG: silent before G5) ·
shots: MG 731, 25 mm 223, beam 99, shell 63. Still to do: a clip of each new event on the page.

### Pack size (for ship; native unaffected)

Round-17 takes, imported (what an export packs), at `e967f25e`: **18.2 MB** = defaults 13.6 (one-shots 6.2 as QOA,
loops 7.4 as PCM) + alternates 4.6 (`*~b_*`, `*~c_*`, kept only for the page). Two levers: (1) exclude the alternates
from the web preset once his picks are in: −4.6 MB (I confirm: no game code loads a non-default direction without
`--sfx-direction`); (2) import the loops as QOA instead of PCM (QOA measured at 0.203 of PCM on these takes): −5.9 MB.
Lever 2 applies to native too (Godot's import settings are per file, not per platform) and QOA is lossy: **declined
by the orchestrator** (the native sound on his system is the point; the 100 MB per-file cap is ship's to solve with a
second pack file). The plan: exclude the alternates from the web after his picks.

### Cost (`make audio-bench`, 60 vehicles, 1200 frames)

Laptop, `4cf27ea8`, light load (informational; the builder0 number, pinned `taskset -c 0-3` per ship, follows):
booth+mood 0.052 ms, music 0.026 ms (budget 0.3 ms for booth, music and crowd: met), engines 0.189 ms (with the G6
skid detection), gunfire 0.073, one-shots 0.045; total 0.385 ms.

### Incident and lesson (written 2026-10-03 13:44 PDT)

Stopping my own waiting script with `pgrep -f "[c]hain3.sh" | kill` at ~13:43 PDT also killed **yard's** `chain3.sh`
(PID 388081; five streams name their scratch scripts `chain1..3.sh`) and my own shell (trip-up 19). Yard's remote check
survived under systemd; the rest of yard's chain did not launch (the orchestrator told yard what to restart). Lesson
for the list: stop a script only by the PID it recorded itself (`echo $$ > x.pid`), never by a name pattern, and name
scratch scripts with the stream (`guns-chain3.sh`). My later scripts do both.

### Known issues

- `test_audio_music_director` leaks 131 ObjectDB instances at exit (a warning; present at the launch tree `3713fdaa`).
- `game/theme/fx/weapon_fx.gd`, `shield_effect.gd` and `tests/test_fx_weapon_events.gd` are touched (merge notes).

### Queued after G4 (from the orchestrator, 2026-10-03)

- **The orchestrator's five points on G1** (to answer with the A/B below): re-take the stage table on HIS match (Sumps,
  Law 24 v Condemned 27, seed 92721) and one more, say which numbers moved, and give the booth's share as k s of N;
  the booth duck is his to choose (a dedicated page item: the same 20 s of a heavy fight with the caller speaking, old
  duck / middle / new, a tap each; default my pick, one constant); integrated loudness, true peak, booth and music vs
  battle before/after on the same match (if the game got quieter, say so); the TURNED container footprint (done:
  `ArenaKit.distance_to_footprint`, table test with a 30° container); every ledger line before → after, and say if a
  batch would take the balance under 20 000 (36 195 after batch 2). Plan: `--mix=launch` recreates the pre-round-17
  mix in the same build so before/after run on one tree and one match; `--booth-duck=launch|mid|new` for the page.
- **FIXED at `96c37137` (13:38 PDT): the browser's silence.** Cause, found with a scratch web export and ship's
  observer (laptop, headless Chrome/SwiftShader): in Sample playback ONE runtime `AudioServer.set_bus_send()` silences
  every sample playback after it, Master included (probes: Master untouched audible; `add_bus` alone, a rename, an
  effect on Master harmless; `set_bus_send` → silence). SfxSystem, the booth and the music director all set sends at
  startup. Fix: every bus declared with its send in `res://default_bus_layout.tres` (Godot loads it by default; no
  project.godot change); SfxSystem only dresses buses, at most once (`tests/audio/test_audio_bus_layout.gd`). Measured,
  ship's scenario (Gangs v Law, Yard, seed 7, keys 1@8 2@12 1@16 Space@25, 45 s), interleaved N=2 per arm on one tree:
  no layout → silent all 45 s (peak −200 dB, 93–173 sample starts); layout → loud from ~11 s after READY, 100 % of
  audio blocks loud, peak −14 dB. Native unchanged: the weapon probe (tank, MG round, kill at 30–120 m, every arm)
  equal within 0.01 dB with and without the layout. Still true and separate: bus effects do not run in Sample mode, so
  the web mix has no limiter, ducks or sidechain (a web-only Stream setting is the lever; its stutter not yet priced).
  **What now sounds in the browser, by class** (`8d18de13`, laptop, headless Chrome on the REAL GPU, 8–9 fps, ship's
  scenario with Space@10, 60 s, one run per `?audio-solo=` layer, measured 13:54 PDT): guns first loud 41.9 s (combat),
  51 % of blocks loud, peak −3.8 dB · impacts 44.8 s, 45 %, −4.1 dB · engines 14.2 s, 100 %, −5.8 dB · crowd 13.9 s,
  100 %, −4.5 dB · music 13.8 s, 97 %, −7.8 dB. So the fix is not the pre-match bed alone. Caveat: the solo is not
  airtight on the web: "ui" is loud from 13.9 s and "booth" from 43 s although the web export carries no booth clips,
  so something outside AudioSolo leaks into those two runs (not chased). Dependency: the booth's sidechain matters on
  the web only once ship's voice option puts clips in the browser, and in Sample mode it would not run anyway.
  **The lever priced: Stream playback on the web** (measured 14:00 PDT; `8d18de13` + a scratch export with
  `[audio] general/default_playback_type.web=0`, project.godot itself unchanged; laptop, headless Chrome on the real GPU,
  ship's scenario, Space@10, 60 s, Sample vs Stream interleaved N=2): first sound Sample 13.0 / 14.3 s, Stream 14.7 /
  15.2 s after load; after it, **every 128-sample block (2.7 ms) at the destination was above −60 dBFS in both modes**,
  i.e. not one dropout in ~45 s of fight per run, at 7–8 fps. What Stream buys: Godot's own mixer on the web, so the
  limiter, the ducks and (once the web has clips) the booth's sidechain exist there, and the web and native mixes are
  one mix. Not priced: very low frame rates (SwiftShader ~2 fps), phones, longer matches. Recommendation: the web-only
  setting `general/default_playback_type.web=0`, ONE line in `project.godot [audio]` (guns'), default unchanged until he
  (or ship's page) decides (C17.4: it changes what a web player hears).
- **The browser is silent for the opening of every match (ship, tree 9a575a26, laptop export, headless Chrome, N=1):**
  with Godot's web default `audio/general/default_playback_type.web` = Sample (project.godot has no `[audio]`), WebAudio's
  output is exact zeros until 43.3 s (the music's pre_match → fight change); a scratch export with Stream (`=0`) is
  heard from 13.7 s. Ship's reading, unproven: Sample mode hands streams to the browser and skips Godot's mixer, so the
  buses, the limiter, the ducks, the distance filter and the booth's sidechain would not exist in the browser. To do
  after G4: reproduce with ship's observer (`OBSERVE_GPU=1 node tools/web_smoke/observe.mjs …`, on ship's branch); find
  WHAT is silent in Sample mode and why from Godot's source/docs; price Stream mode's stutter at the browser's real
  frame rates; recommend a web-only `[audio]` setting behind the switch, default unchanged until he decides (C17.4).
  **What Godot's own docs say (read 2026-10-03, docs 4.4, "Exporting for the Web → Audio playback" and "Audio
  streams"):** in Sample mode "AudioEffects are not supported", "Reverberation and doppler effects are not
  supported", "Procedural audio generation is not supported", "Positional audio may not always work correctly
  depending on the node's properties"; Stream mode "leads to increased latency (especially when thread support is
  disabled), but it allows the full suite of Godot's audio features to work". So ship's reading holds for the mix: in
  the browser today there is NO World limiter, no impacts' duck, no booth sidechain, no Master limiter and no recorder
  tap: every G2 setting is native-only. Hypothesis for the opening silence, to test with the observer: the music's
  pre-match bed is a multi-stem stream (Synchronized / generator-like) that Sample mode cannot play, and something in
  the sound-effect path also needs Stream; not yet proven. **Revised after reading the code (2026-10-03 13:12 PDT):**
  the pre-match beds are single imported Oggs; every `fight_*` bed is stems in an `AudioStreamSynchronized`, and the
  first sound ship heard is exactly the switch to `fight_momentum` (stems). The director is already
  PROCESS_MODE_ALWAYS (round 16), and its players inherit it, so the paused tree should not pause them. Two hypotheses,
  each with a decisive test for the observer: (H1) a stream that cannot be a WebAudio sample (Synchronized) falls back
  to Godot's own mixer and is heard, while a SAMPLE started during the planning pause is not - test: play a short
  imported WAV (a UI blip) during the pause in Sample mode; (H2) a sample started while the browser's AudioContext is
  still suspended (no user gesture yet / before resume) is never scheduled, and only playbacks started after the
  resume sound - test: log `AudioContext.state` over time and the start time of each playback. Stream mode's 11-18 s
  is then the context's resume or the match's load, to be read from the same log.

### Spend (ElevenLabs, `assets/audio/elevenlabs/ledger.md`)

- 2026-10-03 batch 2 (G5 impacts): 41 requests, 36 700 → 36 195 (505). Batch 3 (G6): 21, 36 190 → 35 670 (520).
  Batch 4 (other factions): 13, 35 670 → 35 394 (276). Total this round 2 363 credits; balance 35 394.
- 2026-10-03 batch 1 (G3 layers: tank report/far/tail/breech/muzzle crack, 25 mm round/bursts/mechanism, heavy MG
  burst/round/mechanism, the kill's blast/debris/tail): 49 requests, 157 s, **38 274 → 37 212 (1 062 credits)**.

### Questions for the lead

- What do you listen on (laptop speakers, headphones, the living-room system)? Until answered: designed for the big
  system, checked for the laptop.

### Merge notes

- `game/main.gd` untouched. `game/theme/fx/weapon_fx.gd` (carve-out): FAMILIES burst/stream sound keys, `_miss_sound`
  at the two miss call sites, the surface read on a miss and a fizzle, `_surface` / `_impact_rate` fields.
- `project.godot [audio]` (guns): ONE line, `general/default_playback_type.web=0` (`632df039`; his tap on ship's page,
  `choices/mix` = stream). Web-only; native's playback type untouched (test).
- `default_bus_layout.tres` (NEW, project root, guns): declares World, Impacts, Bed, Gunfire, Crowd, Announcer, Music.
  `game/announcer/announcer_voice.gd` and `music_director.gd` are unchanged: their create-if-missing branches no
  longer run.
- `game/theme/fx/shield_effect.gd`: ONE additive `shield_up` call in `set_shield` (lent by the orchestrator, C17.6).
- `tests/announcer/test_announcer_booth.gd`: `test_the_voice_plays_a_cues_clips_and_ducks_the_world` made its own
  second "World" bus and removed buses by name; with the declared layout it now uses the declared buses and removes
  only what it made (the behaviour it guards, the booth's duck, is guns'). Found by the check of `d542d79f`.
- `tests/test_fx_weapon_events.gd`: the sound check asks a live SfxSystem (sounds that exist only as designed takes).
- Commits are split where possible: G2 mix (`5b2caa2d`, `a2ed55ef`; `443648dd` mixes G2 with G3's 25 mm/kill/MG),
  G3 samples (`8d592ee3`, `e967f25e`), G5 (`fe66533b`, `366e75e7`), G6 (`ff5bc0b3`, `7018e11c`, `50da3b08`).
