# Sound effects (look & feel stream)

Every file here is **synthesized from scratch** by `game/theme/audio/make_sfx.gd` (`make sfx`): no
recorded samples, no downloads, deterministic (seeded). We dedicate them to the public domain under
**CC0 1.0** (https://creativecommons.org/publicdomain/zero/1.0/).

| File | Used for | How it's made |
|---|---|---|
| `cannon_shot.wav` | muzzle flash of every shell | pitch-dropping sine thump saturated with tanh (harmonics phones can play) + a lowpassed noise crack |
| `explosion_small.wav` / `explosion_big.wav` | hits / kills | noise through a closing lowpass + a 250–1500 Hz band + saturated sub rumble + crackle tail |
| `laser_pulse.wav` | each laser pulse | falling FM sine sweep (2.4 kHz → 300 Hz) |
| `shield_hit.wav` / `shield_down.wav` | shield takes a hit / breaks | inharmonic metallic partials + buzz / a descending sputtering saw |
| `flame_loop.wav` | flamethrower while firing (loops) | bandpassed noise with flutter, crossfaded seam |
| `ui_blip.wav` / `ui_alert.wav` / `ui_tick.wav` | info banner / warning banner / UI tick | square blip / two-tone alert / noise click |

Mobile check: phone speakers don't reproduce much below ~200 Hz, so the heavy sounds carry most of
their energy above it (cannon 57%, small explosion 78%, big explosion 50%, measured from the files).

**Art stream (round 2, X5):**

| File | Used for | How it's made |
|---|---|---|
| `crowd_murmur.wav` | the stands' crowd, looping under the match (volume follows the crowd's excitement) | noise through three slowly moving vowel-like bands (~520 Hz, 900 Hz, 1.4 kHz) with random swells + room rumble, rolled off above ~2 kHz, crossfaded seam |
| `crowd_cheer.wav` | the roar after a kill | wide noise band with a fast swell and slow decay, upward whistle sweeps, scattered claps |
| `engine_diesel.wav` / `engine_v8.wav` / `engine_electric.wav` | engine loops per unit type (tank, IFV, artillery / scout / Lancer), pitch and volume follow each vehicle's speed (EngineSystem, the 4 nearest the camera) | a four-cylinder firing-pulse train (uneven strength = lope) at 31 / 57 / 29 Hz through a resonant lowpass, hard-saturated so the harmonics carry on phone speakers, clatter noise; the Lancer adds a 120 Hz transformer hum with buzz; crossfaded seam |

**Feel stream (round 3, the new weapons):** each synthesizer reseeds from its sound's name, so adding one never changes
another. Share of energy above 200 Hz (what laptop and phone speakers play) measured from the files.

| File | Used for | How it's made | > 200 Hz |
|---|---|---|---|
| `tank_boom.wav` | every tank cannon shot (2.8 s) | a highpassed noise crack, a pitch-dropping saturated sine boom (144 → 34 Hz), a 150–400 Hz body, a low rumbling tail plus a 200–500 Hz rolling tail, slap echoes off the stands at 0.19 / 0.43 / 0.71 s | 49% |
| `shell_whine.wav` | a tank shell missing a vehicle by 1–7 m | an airy bandpassed whoosh swelling as it nears, a wavering whistle falling 1650 → 750 Hz (Doppler), cut off sharply | 98% |
| `shell_hit_armor.wav` | a tank shell striking a vehicle | five inharmonic plate partials (247–1577 Hz), a gritty crunch, a low thump, two echoes | 97% |
| `dirt_impact.wav` | a shell or mortar round landing in the dirt | a dull 55–135 Hz thud, a gritty spray, sparse clods pattering down | 57% |
| `autocannon_shot.wav` | each 25 mm round (bursts sound thump-thump-thump) | a punchy pitch-dropping thump (255 → 95 Hz) with a hard crack and one echo | 57% |
| `mg_round.wav` | each machine-gun round | a 0.11 s dry noise crack with a short mechanical knock | 95% |
| `mortar_launch.wav` | a mortar leaving its tube | a hollow resonant 230 Hz tube pop and a breathy push of gas | 98% |
| `mg_loop.wav` | a scout's machine gun held down (loops; GunfireLoops gives the 4 nearest gunners a voice) | exactly 11 dry cracks a second, each with its own weight and knock, over the rattle of the action (seamless) | 95% |
| `ricochet.wav` | a small round glancing off armor (at most one every 0.15 s) | a metallic tick and a zinging FM whine falling 3 kHz → 500 Hz | 100% |
| `bullet_hit_metal.wav` | a bullet or 25 mm round striking steel (at most one per target every 0.09 s) | three inharmonic partials around 900 Hz with a noise click | 100% |
| `weak_spot_hit.wav` | a weak-spot hit (any weapon; at most one per target and weapon every 0.15 s) | a heavy crunch and 90–180 Hz thump, then a bright two-note chime (E6, B6, each with a detuned partner) ringing out | 63% |
| `ui_ack_move.wav` / `ui_ack_attack.wav` / `ui_select.wav` | order acknowledgements (move, follow, hold, stop, waypoints / attack, attack-move) and selecting units | a squelch click with two rising tones (880, 1318 Hz) / a click, a hard descending saw buzz, and a 1760 Hz stab / a short 1.5–2 kHz rising blip | — |

## Audio stream (round 4, X4): takes, the bus mix, and distance

The lead's verdict on round 3's sound was *"it sounds like an atari game rather than a gritty action game"*. Three
things were wrong, none of them about any single sound's synthesis:

**1. Every shot was the same recording.** A scout's machine gun fires eleven rounds a second, and every one was
byte-identical; a pitch wobble of ±12% does not hide that. The most-repeated sounds now come in several **takes**
(`mg_round.wav`, `mg_round_2.wav`, …), each synthesised from its own seed, and `SfxSystem` draws one per shot:

| Sound | Takes | Why this many |
|---|---|---|
| `mg_round`, `bullet_hit_metal` | 4 | heard many times a second; 5–7 KB each, so takes are nearly free |
| `autocannon_shot`, `ricochet`, `shell_hit_armor`, `dirt_impact`, `explosion_small` | 3 | heard several times a minute |
| `weak_spot_hit`, `tank_boom`, `cannon_shot` | 2 | the signature sounds; `tank_boom` is 2.8 s and by far the largest file |

Loops (`mg_loop`, `flame_loop`, the engines, the crowd) keep a single take: they are held down, not re-triggered, and
feel's `EngineSystem` and `CrowdSystem` duplicate them to set loop points.

**2. Nothing mixed the battle.** Twenty voices summed straight into the master, so a firefight clipped. World sound
now goes through a **`World` bus**: trimmed 6 dB, with a limiter at −1 dB. That is also the bus the announcer ducks
(`AnnouncerVoice` sidechains a compressor onto it), so the booth is now audible over a battle without anything else
changing, and it is the bus feel asked for in round 3.

**3. Distance only made things quieter.** A cannon across the arena sounded like a small cannon nearby. Sounds now
carry a distance filter (`SfxSystem.DISTANCE_FILTER`): the big low sounds lose their top end with range (the tank's
boom falls to 1.4 kHz and −22 dB of filtering at maximum distance), while small metallic sounds that are only ever
heard close keep their brightness.

**Size:** 48 WAVs, 2.0 MB in git (the takes added 590 KB). Every one imports with `compress/mode=2` (Quite OK Audio),
so the exported pack carries roughly a quarter of that.

**Still to do** (blocked on the lead's ElevenLabs key): layering generated or CC0 source material under the
synthesised transients, which is what would take these from "clean and mixed" to "cinematic".
