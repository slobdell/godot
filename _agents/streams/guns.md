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

### FINAL REPORT (round 17, written 2026-10-03 20:1x PDT)

**State:** every backlog item is done, or waiting on his ear on the page. Merged to main: `0423fe45` (as `5a6fdf79`)
and the tip `de0d67ac` (green at `f5c127c4`). After that: `2ec25c9a`, the 5.1 check (a speaker-mode print and the
`--audio-device` flag): **GREEN** (builder0, clean tree, `>> remote: make check exited 0`, 1982 passed, 0 failed,
finished 20:57 PDT). **Merge here: `2ec25c9a`**; after it, Status only.
Every number below carries its commit and machine in the sections further down.

**Done, with the measurement that shows it:**
- **G1 the sheet:** source, mix and format on one sheet (`make weapon-sheet`). It found why the guns were small: the tank
  file had no crack (0 % above 2 kHz), the MG sat at −13, and the booth's duck took ~16 dB off every gun for most of a match.
- **G2 the mix:** the MID booth duck (−24 dB 4:1), a limiter with no make-up, the distance filter kept off the crack, the
  gun levels, a declared bus layout (World first, the old game's own order). His match, launch → now (MID, pinned
  seed, pre-CP2, builder0 `28425a48`): the same overall loudness (−17.5 LUFS both); World's median gain −9.5 → −7.0
  dB; the bed no longer ducked by impacts (−12.1 → −0.4); the master limiter more than 1 dB under 20.7 % → 3.1 % of the
  time; the caller 17.6 dB over the battle (median). The layout is an equality natively (layout-ab N=4, every figure
  EQUAL, `c2b25411`) and is what makes the browser audible.
- **G3 gun families in layers:** tank, 25 mm, heavy MG and the kill with directions A/B/C (synth crack and sub +
  generated body, mechanism and a decorrelated stereo tail; tail width 0.24–0.56). The other factions' railgun, mortar,
  missiles, pulse cannon, twin MG and flamer brought up. The game ships direction A of each until he picks.
- **G4 the page:** https://claude.ai/artifact/WmGWF4RBCVycueMmUMac9i, v6. Families, singles, the booth and music
  items, fight clips with ONE commentary per item (asserted), dry loudness matching, and the three-seed spread beside
  the booth figures. db: `picks/` (0 so far) and `verdicts/` (17).
- **G5 impacts by surface:** 11 impacts by surface × calibre (`SfxSurfaces`, rotated footprints), rate-limited. He
  kept all 11.
- **G6 the audit:** skids, hard turns, incoming mortar rounds, burning wrecks + cook-offs, shield up. He kept the
  wheeled skid and the fire; he sent back incoming, shield, track skid and track squeal → second tries (two new
  directions each, batch 5, 236 credits) on the page.
- **Web:** silence fixed (the declared layout), the script duck (MID's 12.7 dB, cannot stack, tested), −4 dB trim,
  `sample-duck` his choice. Pack +1.85 MB of alternates (main pack ~90 of 100 MB); unpicked ones leave after his picks.
- **Stretch:** pack size reported. The 5.1 check is done and found an engine problem (below). Arena acoustics as a
  runtime system is NOT done: the arena slaps are baked into each take (gun_layers.py `slaps`), not keyed to the shot's
  position; it is on the round-18 list.
- **Spend:** 2 599 credits this round, balance 35 158 (ledger).

**Decisions I made (his ear overrides any of them):** the booth duck MID (his tap pending on the page); music +4 dB in
a match, the title excluded; direction A as the shipped default of every family; World-first bus order; the −4 dB web
trim (the orchestrator's call); no QOA for loops (declined).

**What he should listen to, in this order:** (1) the page's *whole game* before/now; (2) the tank, 25 mm, MG and kill
families: pick A/B/C/today; (3) the booth item: launch / MID / light; (4) the music item: +0 / +4 / +8; (5) the
*Second tries*. On the living-room system: **set the PC's output to stereo (or 2.1)**, not 5.1. In 5.1, Godot sends every
3D sound full-range into the LFE at a constant level, so the sub would boom (5.1 check below).

**Waiting on him:** family picks, second-try picks, and the booth and music picks. Then I take the unpicked alternates
out of the web preset and set the picked directions as the defaults. (The post-CP2 MID mix-ab is done: `80b2773b`,
under G2, the same effect on a talkier fight.)

**Round 18** (ranked list below, his match): turret traverse (474 starts/min, silent), hits doing no damage (46,
the wrong sound), collisions (44 + 26), pinned (39), rocket-truck deploys (13/10), the bridge deck (6), friendly
fire and non-primary captures (the booth's), repair and resupply; plus arena acoustics as a system, and the 5.1 LFE fix
(engine-side) if he plays in 5.1.

**Open questions for the lead:** what he listens on (laptop / headphones / the living-room system); if the living
room, whether it runs 5.1 from the PC.

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

### Checks (builder0, read from the wrapper's own line)

- `d542d79f`: **RED** - exited 2, 1948 passed / 1 failed (`test_announcer_booth`'s duck test vs the declared layout;
  fixed at `f62e735e`).
- `934f0ebc` (finished 16:26 PDT): **green** - exited 0, 21 targets all passed, **1956 passed / 0 failed**, sim-baseline
  `05df1d55ba49cde1` UNMOVED. Predates the tap-placement fix (`3d611afd`) and the −4 dB web trim (`55279c13`).
- `934f0ebc` audio-launch-smoke (finished 16:45 PDT): **green** - exited 0; music through the loader, garage → FIGHT, a
  flagless launch with the booth and the music.
- The tip's full check is queued after the music arms and the final `layout-ab`; its synced HEAD is the green hash.
- **Interim range (the orchestrator's decision):** `934f0ebc` merges to main tonight so he can play the new guns, impacts
  and mix with `make skirmish`. Main then has the **−3 dB** web trim; still owed in the next range: the tap-placement
  fix (`3d611afd`), the −4 dB trim (`55279c13`), the layout equality's booth / sidechain / music / crowd columns, the
  ground-truth bus order, the page's music item, and whatever his taps change.
- **`0423fe45` GREEN** (builder0, clean tree, `>> remote: make check exited 0`, finished ~18:5x PDT): 1982 unit tests
  passed, 0 failed; sim baseline unmoved; ai-scenarios refused `scenario_perf` under load (2.72×) and perf-judge judged
  it, so that verdict stands. **Merge here: `0423fe45`** (sent to the orchestrator). It carries everything owed above
  plus the MID self-consistency test, the no-stacking duck test and the SCRIPT_DUCK setting/depth print. After it,
  unchecked until the next check: `ddd42868` (the second tries, +1.85 MB) and docs/page commits.
- **`f5c127c4` GREEN** (builder0, clean tree, `>> remote: make check exited 0`, copy-back verified 523 files, finished
  ~19:4x PDT): 1982 unit tests passed, 0 failed. It carries the second tries (`ddd42868`, +1.85 MB of alternates). **Merge
  here: `f5c127c4`.** After it: Status only (`0517d59a`, the round-18 list).

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

### G2 — the MID mix-ab for the close (pre-CP2; builder0, light lane, `28425a48`, finished 18:3x PDT)

`make mix-ab`, his match (Sumps, Law v Condemned, seed 92721, budget 4600), booth seed 7 in both arms (27 lines each),
launch mix vs now (MID booth duck, +4 dB music, the declared layout, World first). Taken BEFORE yard's CP2 (the
stronger container turn): a record of this fight, not comparable with anything taken after CP2 merges.

| figure | launch | now (MID) |
|---|---|---|
| integrated / true peak | −17.5 LUFS / −2.2 dBTP | −17.5 LUFS / −1.3 dBTP |
| World gain, median / loudest 1 % | −9.5 / −18.2 dB | −7.0 / −17.8 dB |
| Bed (impacts' duck) gain, median | −12.1 dB | −0.4 dB |
| Master limiter, time > 1 dB under | 20.7 % | 3.1 % |
| booth over battle, median / busiest tenth | 22.2 / 8.4 dB | 17.6 / 6.9 dB |
| battle level while the booth speaks (median) | −30.3 dBFS | −30.0 dBFS |

Read: at the same loudness the guns keep 2.5 dB more of World and almost all of the bed (the impacts no longer duck
the battle's own body), the master limiter has almost nothing to do, and the caller still sits 17.6 dB over the battle.
(Music under the battle is from the pre-volume Music tap: compare arms only, as noted under G4.)

**After CP2** (yard's containers at strength B; `main-checked` 90c289f2 merged as `80b2773b`; builder0, light lane,
finished 21:20 PDT; the WAVs were deleted on the laptop and builder0 as soon as the report was written). Same match, same flags,
booth seed 7 in both arms. A different fight from the pre-CP2 pair: the caller spoke 119 / 102 s of 150, against 82 / 81.
The two arms spoke 37 and 33 lines (the pre-CP2 pair spoke 27 and 27), so the pinned seed did not give identical commentary
here, and the booth rows carry that difference.

| figure | launch | now (MID) | pre-CP2: launch → now |
|---|---|---|---|
| integrated / true peak | −17.3 LUFS / −2.8 dBTP | **−16.6 LUFS** / −1.5 dBTP | −17.5 → −17.5 / −2.2 → −1.3 |
| World gain, median / loudest 1 % | −17.2 / −16.2 dB | **−11.2 / −6.0 dB** | −9.5 → −7.0 / −18.2 → −17.8 |
| Bed (impacts' duck) gain, median | −21.2 dB | **−11.2 dB** | −12.1 → −0.4 |
| Master limiter, time > 1 dB / > 3 dB under | 4.1 % / 0.1 % | **11.3 % / 1.2 %** | 20.7 → 3.1 % / 4.3 → 0.1 % |
| booth over battle, median / busiest tenth | 21.1 / 7.3 dB | **16.9 / 5.0 dB** | 22.2 → 17.6 / 8.4 → 6.9 |
| battle level while the booth speaks (median) | −36.2 dBFS | −30.6 dBFS | −30.3 → −30.0 |

**What moved.** The direction of every change holds: World keeps 6 dB more (−17.2 → −11.2), the impacts duck the bed
10 dB less, and the caller stays about 17 dB over the battle, as he did before CP2 (17.6). What differs is this fight:
it has more commentary over it, so the launch mix ducked it harder (World −17.2 against −9.5 before). Against that
deeper launch baseline, now plays 0.7 dB louder overall (before CP2: equal). The master limiter now works more than
the launch arm on this fight: 11.3 % of the time more than 1 dB under, but only 1.2 % more than 3 dB, so it shaves
peaks and does not pump. Earlier it was 3.1 %. Read: the mix's effect is the same on both fights; the
absolute loudness depends on how much the booth talks, as it did at launch. Nothing to change. It's for his ear on the page.

**Which loudness is right: "about 1 dB louder" (14:10) or "the same, −17.5 / −17.5" (this run)?** This run is right
for the build as it ships now. The 14:10 pair (`6b9cb5c0`) measured a different mix and a different fight:
- **the booth duck was LIGHT** (−20 dB 2.5:1). MID became the default at `4f3d117c`, after that tree synced. MID takes
  more off World whenever the caller speaks, which is 55 % of the window: World's median gain went from −4.6 to −7.0 dB,
  and the caller's lead from 10.6 to 17.6 dB. That is most of the 0.9 dB of integrated loudness.
- **a different fight:** yard's CP1 (turned containers, `9314a2db`) and sim's kill-cam tick fix (`d7860e7f`) merged
  in between, so the Sumps fight differs (C17.2), and its commentary was unseeded. This run pins booth seed 7 in both
  arms. The launch arm reads −17.5 LUFS in both pairs, so the launch build is stable across the change. The
  difference is all in the "now" arm.
- the music lift (+4 dB, `73e594d9`) came in between too. It pushes the other way (music louder), and is smaller.
- The control arm's wrong bus order affected layout-ab only, never mix-ab (mix-ab has no `--no-bus-layout` arm).
These causes were not each measured on their own: the attribution above comes from the World and booth columns.
**What to tell him:** on his match the game as it ships plays at the same overall loudness as at launch (−17.5 LUFS).
Inside that, the battle is fuller (the bed is no longer ducked by the impacts) and the master limiter barely works.
While the caller speaks the battle drops under him by MID's depth, then comes back. The guns are not louder overall;
they are louder against everything that used to sit on them.

### Ground truth: the order the game builds its buses in (written 17:32 PDT)

`make bus-order` (a probe autoload injected into a `git archive` copy; windowed on builder0; his match; every
`bus_layout_changed` logged, then the final order with each compressor):
- **launch tree `3713fdaa` (the old game): World first** - created at frame 0 in the order World, Impacts, Bed,
  Gunfire, Crowd, Announcer, then Music; World carries `Limiter, Compressor(Announcer −28 dB 6:1)`.
- **the page's tree `1619596d`** (its clips, synced 13:16): **World first**, the same order (World: `HardLimiter,
  Compressor(Announcer −20 dB 2.5:1)` - that tree's default; the page's arms forced their duck by flag).
- So the shipped layout (World first) IS the old game's order, and `bc47545a` was right. What was wrong: layout-ab's
  control arm - `--no-bus-layout` reset the buses in main.gd's `_ready`, after FxWorld (made by child nodes, whose
  `_ready` runs first) had built World, so the booth rebuilt the list Announcer-first. Fixed at `0ece2408`: the layout
  is dropped before ANY bus is built. The 20-21 dB "runtime" figures came from that unfaithful arm.
- The battle's own level into World is the same on the page's tree and today's (−14.1…−15.1 dB while the caller
  speaks): the page's MID 14.9 dB vs today's World-first 12.1-12.7 is not content and not order; it is two sessions'
  runs of one seed. `booth-match` now runs the page's tree LIVE beside the tip (`db7b67d7`), interleaved, light lane.
- **The booth is not seeded by the match** (written 17:46 PDT): with history off, two runs of one match seed spoke different
  lines (layout-ab's two declared runs: 19 vs 21 lines, different calls); `--announcer-seed=N` pins them. booth-match,
  layout-ab, mix-ab and the audition clips now pin it.
- **booth-match result** (light lane, `dd07223d`, seeds 7/8/9): FAILED as a test, but the comparison is invalid -
  since main's CP1 merge (turned containers) the page's tree and the tip are different fights on the Sumps (C17.2),
  and the two arms spoke different lines on every seed even with the same booth seed. Per seed (page vs tip, median /
  busiest tenth): 12.4/4.9 vs 13.8/0.4; 15.7/1.9 vs 13.2/5.2; 12.8/4.9 vs 13.9/1.2. Mean difference 0.0 dB (median),
  −1.7 (busiest tenth); spread across booth seeds on the page's tree 3.3 / 3.0 dB. Read: the shipped MID reproduces
  the page's MID on average. The page is re-recorded on the tip (seed 9: the caller speaks 88 % of the window; seeds 7
  and 8: 48 %, 78 %), so from v5 its booth item IS the shipped build at each setting.
- **All five trees, World first** (chain10, builder0, finished ~18:0x PDT): launch `3713fdaa`, page `1619596d`, the
  interim `934f0ebc`, the tip with `--no-bus-layout` and the tip as shipped all print `1:World 2:Impacts 3:Bed
  4:Gunfire 5:Crowd 6:Announcer 7:Music`. The tip's control arm now builds the same order as its declared layout,
  so layout-ab compares the layout itself, not a different order.

### The layout's native equality: settled (builder0, light lane, `c2b25411`, finished 18:4x PDT)

`make layout-ab LAYOUT_RUNS=4`: one tree, the faithful control (`--no-bus-layout` dropped before any bus is built),
booth seed 7 in every run (asserted: the same 18 lines in all eight). Difference between arms vs spread within an arm:
LUFS 0.01 / 0.63, TP 0.14 / 0.64, booth 0.02 / 0.80, music 0.10 / 2.93, crowd 0.05 / 0.95, World gain 0.03 / 2.90,
booth over battle 0.02 / 1.60 - **EQUAL on every figure**. (The N=2 run at `0423fe45` had booth-over-battle 0.90 vs
0.80 and TP 0.61 vs 0.42: two runs per arm was too few to call; the orchestrator ruled it non-gating.) The declared
`default_bus_layout.tres` changes nothing a native player hears; it exists for the browser, where it is what makes
Sample playback audible.

### Booth over the battle: every figure, reconciled (written 15:12 PDT)

| figure (median / busiest tenth, dB) | tree | bus order | booth duck | window | read |
|---|---|---|---|---|---|
| page: launch 21.7 / 8.8, mid 14.7 / 2.9, light 9.6 / 1.5 | `a6e2806d` (synced 13:16) | runtime-built, windowed = **World first** | per arm (`--booth-duck`) | whole 75 s recording | the shipped order; MID's basis |
| after-pass 10.4 / 2.1 (Foundry) | `fe66533b` | runtime-built windowed = World first | light | whole 150 s | consistent with light |
| mix-ab: launch 22.0 / 8.3 → now 10.6 / 1.8 (his match) | `6b9cb5c0` (13:39) | declared World first (= right) | launch arm's / light | whole 150 s incl. ~18 s post-decision | consistent with the page's launch and light |
| layout-ab declared 15.5 | `8d793ac4` (14:11) | declared World first | MID | whole 90 s | agrees with the page's MID (14.7) |
| layout-ab "runtime" 20.1 | `8d793ac4` | **Announcer first** (control reset after mode.start: NOT the old game) | MID | whole 90 s | the invalid arm; led to `47a8a43f`, undone at `bc47545a` |

**SUPERSEDED (written 17:00 PDT):** the final `layout-ab` (synced `0b9ba0ee`, taps working, reset before
`mode.start()`, windowed, N=2) printed the runtime order as **Announcer first** - so the windowed game does build the
booth's bus before FxWorld's, and `bc47545a`'s reasoning was wrong. Equal between arms: LUFS, TP, booth, music, crowd.
DIFFERS: World stage −12.6 (declared, World first) vs −17.4 (runtime), booth over battle 15.6 vs 21.0. Unresolved
contradiction: the page's clips (no layout, runtime buses, 13:16) read MID 14.7 - the World-first figure. The
launch-tree bus-order print (`make bus-order` on a `git archive` of `3713fdaa`) decides which order the old game used;
until then **the layout's native equality is NOT established** and main (World-first since the interim) may duck the
battle ~5 dB less under the caller than the old game did.

**Headless vs windowed before the layout:** headless runs have no FxWorld and built the booth's bus first; windowed
built World first. Tests, `audio-bench` and the weapon probe ran headless: the tests assert effects by bus NAME and
never by order (checked: no expectation depends on order); the bench's cost does not depend on order; the probe has
no booth. With the layout both paths build the same order.

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
- **v4** published 16:54 PDT: the music item (the same 20 s of his match's loudest fight, music at +0 / +4 / +8 dB,
  `c513b16c`, builder0): the music sits 14.0 / 9.7 / 5.6 dB under the battle while the caller speaks (before round 17
  about 7); the master limiter does not engage in any (its input peaks −2.3…−3.4 dBFS, ceiling −1; Master tap aligned
  to the recording by envelope, 3.0 s). **Default +4 dB in a match** (`73e594d9`, `MusicDirector.IN_MATCH_LIFT_DB`;
  the garage keeps its level; the TITLE keeps its intro level - `4168c17a`, the lift starts when a match adopts the
  director). The Music tap is before
  the bus volume: every earlier "music under the battle" figure carries the same constant offset, so comparisons
  between them hold and the page's numbers add the arm's lift back.
- Was pending on builder0: "In the fight" clips (his match: Sumps, Law v Condemned, seed 92721, budget 4600) and the booth
  item (launch −28/6:1, mid −24/4:1, new −20/2.5:1, the same 20 s where the caller speaks over the loudest fight).
- **v5** published 18:13 PDT: every fight clip re-recorded with ONE booth seed (9) per item, asserted (`same commentary
  across <item>: True` for tank, 25mm, mg, kill, duck, music; builder0, `882daeb0` for the booth/music/whole-game arms,
  `0ba6b21c` for the per-gun arms - the commits between differ only in tests and docs). Booth, median / busiest tenth:
  launch 24.8 / 11.1, **mid 16.7 / 6.8**, light 10.1 / 3.0. Music under the battle: +0 → 13.1, **+4 → 8.3**, +8 → 4.5.
  Beside the booth figures: booth-match's three-seed table for the shipped MID over another 20 s (29.9–49.9 s) of the
  same fight: seed 7 13.8 / 0.4, seed 8 13.2 / 5.2, seed 9 13.9 / 1.2 - the median moves 0.7 dB with the commentary,
  the busiest tenth 4.8 dB, so the busiest-tenth figures are loose.
- **His verdicts** (found 18:14 PDT, written 14:21–14:22 PDT - earlier reads looked at `picks` only): **keep** all 11
  impacts, `tyre_skid`, `wreck_fire_loop`; **redo** `shell_incoming`, `shield_up`, `track_skid`, `track_squeal` (no
  notes). No picks yet.
- **v6** published 18:20 PDT (`ddd42868`): *Second tries*: the four he sent back, each the first try beside two new
  directions (batch 5): skid b = a stop on dirt (engine dropping, tracks clanking to a halt, gravel), c = the drivetrain
  (sprocket squeak, slack links, one hull clunk); squeal b = a pivot in mud (engine strain, tracks tearing the ground),
  c = the classic road-wheel squeal; incoming b = a big shell tearing the air, freight-train roar, no whistle, c = a
  mortar's short fluttering whoosh; shield b = a heavy generator spinning up (thrum, relays, settling hum), c = a soft
  whoomp and a glassy shimmer. Picks go to `picks/skid|squeal|incoming|shield`. The game still plays the first tries
  (direction a) until he picks.
- **db paths:** `picks/<family>` {pick, note, at} for tank, 25mm, mg, kill, railgun, twinmg, mortar, missiles, pulse,
  flame, booth, music, and (v6, the second tries) skid, squeal, incoming, shield; `verdicts/<sound>` {verdict
  keep|redo, at} for each new single sound. The page writes only these two collections.
- **Every db read lists EVERY collection the page writes** (`picks/` and `verdicts/`; any new one is added here
  first) and Status records the time and the count per collection (lesson 220: 17 verdicts sat four hours because the
  reads looked at `picks/` only). 18:14 PDT (me): `picks/` 0, `verdicts/` 17 (13 keep, 4 redo). 18:22 PDT (the
  orchestrator): the same; dumped to `references/round17/guns_g4_verdicts_db.json`. 19:48 PDT (me): `picks/` 0, `verdicts/` 17 (unchanged).
- **db reads** (times from `date`): 2026-10-03, right after v1, before 12:55 PDT: empty; 13:41 PDT (after v3): empty; 16:54 PDT (after v4): empty. (An earlier note said ~13:21: my clock
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

### Round-18 list: what is left of the audit, ranked by events a minute on HIS match

Probe (an autoload in a `git archive` copy of `3d7891ab`, laptop, headless, `--cinematic`, no audio recorded) on the
Sumps, Law v Condemned, seed 92721, budget 4600. The match ends by control at 143.4 s, so 146.4 s were counted. Two runs
gave identical counts. The rates are map-wide (46 units, ~27 alive on average), not what the camera hears. Already
voiced this round and not re-counted: skids, hard turns, incoming mortar rounds, burning wrecks, shield up, misses by
surface.

| # | event | /min | threshold | today | what it should be |
|---|---|---|---|---|---|
| 1 | turret traverse | 474 starts; ~35 % of alive time | yaw vs hull > 20°/s after ≥ 0.3 s below | silent | servo whine + ring-gear grind, pitch on yaw rate, nearby units only (a loop, not one-shots) |
| 2 | hits doing < 5 damage | 46 (9.4 exactly 0, all 25 mm) | `projectile_impact` on a unit, shield+hull damage < 5 | generic: the same clank as a damaging hit (`weapon_fx.gd:540`); the ricochet is a random 30 %/20 % roll, not tied to no damage (`:529-538`) | a no-damage hit is the zing and a thin tink, never the clank |
| 3 | tank-to-tank collisions | 44 (80 of 171 in the first 30 s) | new contact ≥ 3 m/s closing, pair once a second | silent | steel thud + track scrape, scaled by closing speed |
| 4 | suppression: pinned | 39 | `Tank.is_pinned()` false→true | silent | near-miss cracks and a crew "heads down", local |
| 5 | tank into a wall or prop | 26 | as #3, collider not a Tank | silent | dull boom + scrape by `SfxSurfaces` surface |
| 6 | rocket trucks deploy / pack | 13 / 10 | `deploy_ratio` leaves 0 / 1 | silent | outrigger hydraulics and jack clunks |
| 7 | onto the bridge / catwalk | 6.2 (pit 0.8) | entering a terrain rect | silent | hollow steel-deck rumble under the engine |
| 8 | friendly fire | 2.0 | `Match.friendly_fire` | generic hit | a radio "check fire" bark (the booth's call) |
| 9 | a non-primary objective changes hands | 1.2 (of 1.6) | `objective_changed` | silent (the primary is announced: `match/announcer.gd:114`) | a capture sting for every objective |
| 10 | repair | 1.6 | hull rises, > 3 s since the last | silent | wrench and welder crackle |
| 11 | resupply / ammo empty | 0.8 / 0.4 | ammo rises / hits 0 | silent | crate clank / a dry click |
| — | water, orders, kill cam | 0 / 0 / 0 | no water on the Sumps; CPU sides issue no orders; it ends by control | — | other maps / player matches only |

Context: 358 shots a minute, 11 kills, 27 impacts on nothing. The ricochet plays about 45 times a minute (an estimate
from the code; headless has no sound system), which is often enough to check it does not mask the armour clanks.
Not measured: what plays and how loud at the camera (needs a windowed run, skipped under the disk rule). The collision
counts depend on the thresholds (raw contact starts: 407 a minute).

### Stretch: the 5.1 check (laptop, Godot 4.7.2, written 20:0x PDT)

Method: a 6-channel PipeWire null sink (FL FR C LFE RL RR), the game pointed at it with the new `--audio-device=<sink>`
(the system default untouched; the sink unloaded after), the sink's monitor recorded with `parec`. The game prints
`AUDIO_SPEAKERS mode=... ` at start and `AUDIO_SPEAKERS settled mode=...` a second in (the driver reopens asynchronously).
- **Godot opens real 5.1** (`speaker_mode = SURROUND_51`) when the output has six channels.
- **The booth and the music stay on the fronts** (2D players, stereo mix target). In his match, FL and FR correlate
  0.93 with each other and ~0.3 with C/LFE.
- **Every 3D sound also goes, full range, into the LFE at a constant level whatever its direction.** One 1 kHz tone
  from an AudioStreamPlayer3D at eight bearings: the mains pan as they should (front → C and FL/FR; behind → RL/RR;
  the opposite side drops to silence), but LFE sits at −11.2 dBFS at every bearing, louder than any single main
  (−12.7 at best). In 60 s of his match: LFE −16.3 dBFS RMS against the fronts' −20.2; below 120 Hz the LFE is −20.1
  against the fronts' −29.1.
- **What it does on a receiver:** a 5.1 receiver low-passes LFE (~80–120 Hz) and plays it 10 dB hot (the standard).
  So the battle's low end reaches the sub about 9 dB (measured) + 10 dB (the LFE gain) above the mains' own lows.
  That's boom, not punch, and it is not the mix he would hear in stereo.
- **Not fixable in our paths:** the copy is made inside the engine's 3D panner. A bus effect runs per channel pair,
  so it can't filter the LFE alone, and GDScript can't write an AudioEffect. Options: (a) **his living room: set the
  PC's output to stereo (or 2.1)** and let the receiver's bass management feed the sub from the mains (what the mix
  was designed and measured for); (b) an engine-side fix (a GDExtension effect on the centre/LFE pair, or an engine
  patch), priced for round 18, not ours to ship; (c) leave it (stereo players, laptops and the web are unaffected).
  **Recommendation: (a) now, written into how he should listen; (b) on the round-18 list if he ever plays in 5.1.**

### Pack size (for ship; native unaffected)

Round-17 takes, imported (what an export packs), at `e967f25e`: **18.2 MB** = defaults 13.6 (one-shots 6.2 as QOA,
loops 7.4 as PCM) + alternates 4.6 (`*~b_*`, `*~c_*`, kept only for the page). Two levers: (1) exclude the alternates
from the web preset once his picks are in: −4.6 MB (I confirm: no game code loads a non-default direction without
`--sfx-direction`); (2) import the loops as QOA instead of PCM (QOA measured at 0.203 of PCM on these takes): −5.9 MB.
Lever 2 applies to native too (Godot's import settings are per file, not per platform) and QOA is lossy: **declined
by the orchestrator** (the native sound on his system is the point; the 100 MB per-file cap is ship's to solve with a
second pack file). The plan: exclude the alternates from the web after his picks.

**Standing constraint (orchestrator, 17:5x PDT):** the merged browser main pack is 88 MB, 12 MB under GitHub Pages'
100 MB per file. Every sound added counts against it. **The next range (since the interim `f93f3cb4`) adds 1.85 MB**:
the 28 second-try takes (batch 5, `ddd42868`), measured as the imported files an export packs (QOA, 1 849 876 bytes);
nothing else under `assets/` changed. They are alternates: once he picks, the unpicked ones leave the web preset. The audition clips (v5 included) are page assets: they live in the
scratchpad and the artifact, never in `assets/`. After his picks the alternates leave the web preset (−4.6 MB).

**Script duck in the browser (he chose `sample-duck`, 16:59:33 PDT):** the duck chases ONE target (rest − depth) and
never subtracts from its current level, so back-to-back lines cannot stack. `test_back_to_back_lines_never_stack`
(4717e8e4): four 1 s lines 0.5 s apart dip ≤ depth + 0.05 dB. Ship's joint run measured one dip of 18.2 dB, which is
either the battle falling in that window or a launch-duck run (launch depth = 18.2), never a stacked MID.

### Cost (`make audio-bench`, 60 vehicles, 1200 frames)

Laptop, `4cf27ea8`, light load (informational; the builder0 number, pinned `taskset -c 0-3` per ship, follows):
booth+mood 0.052 ms, music 0.026 ms (budget 0.3 ms for booth, music and crowd: met), engines 0.189 ms (with the G6
skid detection), gunfire 0.073, one-shots 0.045; total 0.385 ms.

### Disk rule (the laptop hit 100 % at 18:49 PDT; written 18:5x PDT)

I held ~18 GB of it: the scratchpad (13 GB: raw WAV taps and main recordings of finished runs, seven scratch web
exports, old page builds) and `build/` (6.3 GB: `build/light/build` 3.6 G, `build/audio` 2.5 G). Removed at a job
boundary: every WAV whose numbers are already in a report or in Status, every scratch web export, the old page
builds, the light lane's copy-back WAVs. Kept: reports (json/txt/tables), `clips.json`, the page's mp3s, the ledger.
`df -h /`: 60 MB free before → 18 GB free after.
**For the rest of the round:** a recording run deletes its WAV taps as soon as its report is written. Scratch exports
and `git archive` copies are removed after the measurement. `build/light/build` is emptied after each light job's
results are copied out. Before any run that writes more than ~200 MB: `df -h /`, and never start under 3 GB free.

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
  **WITHDRAWN (wrong): "Stream: no dropouts at 7–8 fps" (14:00 PDT).** The "stream" arm was served by a leftover Sample
  server (its run shows 869 buffer-source starts, i.e. Sample). The lead tapped `choices/mix = stream` on that number;
  the tap is VOID (C17.4) and the setting is reverted (`4448e2c7`). **Re-priced (written 14:55 PDT, mode asserted per run
  from the page: 0 buffer-source starts = Stream):** laptop, headless Chrome on the real GPU, ~9 fps, ship's scenario,
  interleaved N=2: Stream at `output_latency.web` 50 ms (Godot's default) 0.35–0.41 of 2.7 ms blocks loud (broken
  audio); 150 ms 0.80–0.82; 300 ms 0.96–0.97; Sample (with the layout fix) 1.00. Still to price with ship: loud
  fraction against frame rate (where does Stream stop dropping out?), in a real window, and what Sample costs once
  the web has a booth (no sidechain: the caller is not lifted over the battle; is a static Announcer offset the cheap
  substitute?). Lesson (round 9's): an arm that is never asserted to BE its arm carries no information.
  **Frame-rate sweep (written 15:03 PDT, mode asserted, laptop, real GPU, fps varied by viewport and army budget, N=1 per
  cell):** Stream at 50 ms: 0.98–0.99 loud at 58–60 fps, 0.43–0.47 at 11–18 fps; Stream at 300 ms: 0.98–0.99 at 21–60
  fps, 0.96 at ~9 fps. A 30-a-side browser fight runs 8–11 fps on the laptop (headless), so the honest choice for the
  web is Sample (no bus effects) or Stream with +300 ms on every sound (output_latency.web=300).
- **150 ms buffer:** the runs meant for 20–30 fps landed at 11 fps (laptop busier): Stream at 150 ms, 11 fps,
  0.88–0.89 loud (N=4). 20–30 fps at 150 ms is NOT measured.
- **The cheap substitute for the web's missing sidechain, priced from the MID clip's taps (no new run):** MID's duck
  takes a median **12.7 dB** off the battle while the caller speaks (launch 18.2, light 6.8; World's gain during
  speech against during silence). In Sample mode the caller would therefore sit ~12.7 dB lower against the battle than
  natively (median ~2 dB over it at MID's numbers). A static offset cannot fix it: the booth already peaks at
  −0.9 dBFS on its own bus and Sample mode has no limiter, so the Announcer cannot go up; lowering World statically
  costs the guns 12.7 dB in the browser at all times. The substitute worth building: a SCRIPT duck, web-only -
  SfxSystem lowers the World bus's volume by 12.7 dB (≈50 ms down, ≈300 ms up) while a booth line plays; no audio
  effect, no headroom spent, runtime bus volume already works on the web (the music director sets one). Not built:
  it matters once ship's voice D puts clips in the browser.
- **The web's script duck: BUILT** (`1b5856ea`, on the orchestrator's decision): where bus effects do not run (web,
  Sample) SfxSystem lowers the World bus's VOLUME by the chosen booth duck's measured depth (`BOOTH_DUCKS[..].script_db`:
  launch 18.2, MID 12.7, light 6.8 dB) while any AudioStreamPlayer under an AnnouncerVoice plays; ~50 ms down,
  ~300 ms up; off natively (test). **Proven on the web** (written 15:26 PDT, scratch probe project with the declared
  layout, Sample asserted: 46 buffer-source starts; laptop, headless Chrome, real GPU): a runtime World-volume change
  is heard - a loop on World at −8.5 dB went to −20.4 for a −12 dB setting and back to −8.5, kept playing throughout,
  and a later one-shot on World played normally. At his army size the browser runs 3–5 fps (ship): the dip lands in
  the frame the line starts (≤ 250 ms, one 12.7 dB step, masked by the caller's onset), the release returns in 3–4
  steps (≈7, 3, 1.4, 0.6 dB) over ~1 s: GDScript has no audio-side ramp for a bus volume, so this is the floor.
- **Sample mode has no limiter: does the browser clip?** Four full 30-a-side browser fights (laptop, real GPU, layout +
  G2 mix, Sample asserted): destination peaks −1.6, −0.3, −1.3, −1.8 dBFS; 0 of 423 half-second records at full
  scale (exact sample peaks). Not clipping, but 0.3 dB of margin at worst. **Built on the orchestrator's call: a
  web-only MASTER trim** (`53143c52`, `WEB_MASTER_TRIM_DB` −3, gated with the script duck by `web_sample_mix()`; native
  Master untouched, tested; −4 dB since `55279c13`): every relation in the mix stays native, the sum gets headroom. Proven (written 15:37 PDT,
  Sample asserted): a runtime Master-volume change is heard (probe: −8.5 → −20.5 dB for −12, loop unbroken); five
  browser fights on `53143c52`+: median RMS −29.0…−29.7 dB (was −25.1…−26.4: the trim, ~3.5 dB), peaks −6.0 to
  −11.1 dBFS, 0 records at full scale. The peaks fell 5–10 dB, more than the trim: something that peaked near full
  scale in the earlier build no longer does; not identified. The script duck never engaged in these runs (no booth
  clips on the web yet): its first real exercise is ship's joint run once voice D lands.
  **The peak drop explained (written 16:03 PDT):** the trees: `web_solo` = `8d18de13`, `web_trim` = `53143c52`/`9e3eed4f`;
  between them, for web sound, only the trim is net (Stream added then reverted before the trim export; the order went
  Announcer-first and back to the same World-first; the duck never engaged). Per class (45 s, `?audio-solo=`): the
  guns layer started 0 sounds in BOTH builds (at 3–5 fps the fight never reached gunfire in 45 s); impacts started 84
  on the old build (8 fps) and 22 on the new (6 fps). So a 45 s window holds as much fight as the laptop's frame rate
  allows: the old runs' near-full-scale peaks were big impact moments the slower trim runs mostly did not reach - an
  unequal-arms artefact, not a missing sound. **With comparable fights** (100 s, 8 fps, 2 412–2 872 sounds started
  each, interleaved N=2): no trim peaks **+0.1 and 0.0 dBFS - the browser clips** in a full fight; with −3 dB, −3.2 and
  −2.2 dBFS, median RMS 3.2 dB lower. **The trim is now −4 dB** (`55279c13`, the orchestrator's call): two comparable
  fights (written 16:08 PDT, Sample asserted, 8 fps, 2 701 and 2 073 sounds started) peaked at −4.0 and −3.5 dBFS,
  median RMS −22.1 / −22.3. Rule from here: a web arm is defined by sounds started or the tick reached, never by
  seconds.
- **Two runs failed and why:** the music arms and the MID `mix-ab` (exited 2, no main recording): the Master tap,
  added at 3 s, re-instantiated Master's effects and emptied the main recorder. Fixed at `3fef989b` (the Master tap
  goes on before the main recorder); both re-queued.
- **Ship's constant-match sweep** (relayed): at his army size the browser runs 3.4–4.9 fps; sound share at 1×: Sample
  1.00, Stream 50 ms 0.06–0.07, 150 ms 0.24–0.38, 300 ms 0.50–0.74. Sample is the browser's mode.
- **Which tree each recording ran on** (from each run's log creation time vs commit times): page v3's fight clips,
  booth item and whole-game clips synced 13:16:07, before any layout file existed: buses built at runtime, Announcer
  first = the order the shipped layout declares (`47a8a43f`): valid. `mix-ab` synced 13:39:05 on `6b9cb5c0`, the
  WRONG-order layout in both arms: its absolute booth figures are biased low (~5 dB less duck); the MID `mix-ab`
  re-take runs on the corrected tree.
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
  Batch 4 (other factions): 13, 35 670 → 35 394 (276). Batch 5 (second tries at his four redos): 28, 35 394 → 35 158
  (236). Total this round 2 599 credits; balance 35 158.
- 2026-10-03 batch 1 (G3 layers: tank report/far/tail/breech/muzzle crack, 25 mm round/bursts/mechanism, heavy MG
  burst/round/mechanism, the kill's blast/debris/tail): 49 requests, 157 s, **38 274 → 37 212 (1 062 credits)**.

### Questions for the lead

- What do you listen on (laptop speakers, headphones, the living-room system)? Until answered: designed for the big
  system, checked for the laptop.
- If the living-room system: does the PC feed it 5.1? If so, set the PC to stereo/2.1 for now (the 5.1 check).

### Merge notes

- `game/main.gd`: ONE additive line, `AudioRecorder.prepare_buses(flags)` before the mode builds FxWorld (the
  `--no-bus-layout` control arm); already on main. `game/theme/fx/weapon_fx.gd` (carve-out): FAMILIES burst/stream sound keys, `_miss_sound`
  at the two miss call sites, the surface read on a miss and a fizzle, `_surface` / `_impact_rate` fields.
- `project.godot`: no change against main. The `[audio]` Stream line (`632df039`) was reverted (`4448e2c7`) when he
  re-chose `sample-duck`; web stays Sample with the script duck and the −4 dB trim.
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
