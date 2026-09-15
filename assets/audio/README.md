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
