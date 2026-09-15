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
