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

_(the worker keeps this current: plan, done with measurements, decisions, questions for the lead, requests to other
streams, known issues, what to playtest, next steps, merge notes — and `this commit is green, merge here: <sha>`)_
