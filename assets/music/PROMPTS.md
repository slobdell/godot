# The soundtrack: the lead's prompts, one per bed

Owner: the feel stream ([../../_agents/streams/archive/round10/feel.md](../../_agents/streams/archive/round10/feel.md)); round 5 it was audio ([../../_agents/streams/archive/round5/audio.md](../../_agents/streams/archive/round5/audio.md)). Design:
[../../_agents/game_design.md](../../_agents/game_design.md) *Audio: cinematic, and alive*.

> **The soundtrack is the lead's own Suno tracks** (all 23 of `assets/incoming/music/`, round 12; the first nine went
> in on 2026-09-17, `190dea27`). Only the six stingers are still placeholders. *The mapping, and why* (below) says which
> track plays where. The mix balance (music 9 dB under the battle) was set against the placeholders and has not
> been re-checked by ear against the real beds: `make remote T="audio-pass PASS_SECONDS=90"`, then listen.

The direction, in his words: *"a cyberpunk tank video game meant to exist in some futuristic world (Death Race meets
Mad Max meets Blade Runner) … heavy metal gaming music combined with synthwave combined with heavy grit."*

> **Rights:** Suno's commercial rights depend on the plan a track was generated under. Record the plan and the date
> with `RIGHTS="Suno <plan>, <date>"` on import; the manifest keeps it for Steam and Android.

## The plan in one table

| Bed (MatchMood state) | His prompt | BPM | His note | How it plays |
|---|---|---|---|---|
| `garage` | Victory Pit / Scrapyard Smuggler | 80 | *"good for mech equipping and stuff"* | a pool of takes (above) |
| `pre_match` | Hangar / Pre-Match Tank Customization | 95 | noir synthwave, tactical preparation | the opening, before the first shot; rotates |
| `lull` (quiet spells after contact) | Lockdown Protocol | 98 | *"good but slow"*, which suits a lull | rotates |
| **the fight** (`skirmish` and `battle`) | The Grinding Treadmill | 100 | **GOOD** | **stems that build** |
| **the fight**, second set | The Scrap Foundry | 105 | **GOOD** | stems that build |
| **the fight**, third set | High-Tech Grime & Dystopian Sludge | 110 | **GOOD** | stems that build |
| `last_stand` | Cyber Metal / Dark Techno, "lethal John Wick club combat" | 115 | relentless momentum | one track, a deliberate change |
| `victory` | Victory Pit / Scrapyard Smuggler | 80 | written for a results screen | the same track as `garage` |
| `defeat` | Acid Rain Wasteland | 85 | sludge / doom, rusted steel | one track, loops |
| stingers | his percussion palette (below) | — | anvils, brake drums, iron pipe | short one-shots |

**Why the fight is three stem sets instead of a skirmish bed and a battle bed.** The director doesn't swap tracks as
the fight grows; it brings layers of one track in and out on bar lines (round 5, X5), because swapping between two
different songs at the moment the fight gets serious sounds like a DJ changing records. So `skirmish` and `battle` are
one track split into stems. You marked three battle tracks **GOOD**; all three become fight sets, and the director
picks one per match, so matches don't all sound alike. `lull` and `last_stand` stay whole tracks: the crossfade into
the fight at first contact and into a last stand are moments where a change of song is the point.

**One unassigned prompt** of yours (*Instrumental Industrial Sludge Doom, 60 BPM, monolithic wall of sound…*, below):
too slow to sit under a fight. It would make a strong `defeat` alternative, or a pre-match build at a boss arena later.

## The mapping, and why (round 12)

His words (2026-09-26): *"do we have a wide selection of music tracks? I can't tell if it's playing the same music
over and over on opening — if there are comparable moods across tracks (which there should be, I did a few
variations), it would be good if we can randomize the selection."*

**What he heard was real.** The match opens in the mood's `lull` state, which had one bed (Subterranean Anvil), and
the `pre_match` bed was never asked for by anything. Now the director plays `pre_match` while the mood is `lull` and
nobody has fired (`MusicDirector.music_state_for`), `lull` only for a quiet spell after contact, and **every state
rotates between 2-5 tracks**. Each set of equally fitting tracks is drawn once per match from the music's own seed
(`--music-seed`) and `MusicHistory` (`user://music_history.json`): the director picks among the tracks heard *least
recently*, so every opening plays once before any plays twice. Skirmish and battle share one fight set per match (the
fight builds in layers; it never changes song).

**How the tracks were sorted.** Nobody on the agent side can listen. `tools/audio/survey_tracks.py` measured tempo,
loudness, tone and the steady window, and a second pass measured percussive density, the share above 4 kHz and the
intro-versus-body level. The four blues takes stand apart on every measure (dark, sparse top end, very dynamic). The
metal tracks are close together on all of them, so they were placed by tempo, tone and title. **His ears decide:**
a track in the wrong state is one line in `manifest.json` (its `states`), no re-import.

| State | Tracks (manifest id ← Suno file) | Why |
|---|---|---|
| `pre_match` (the opening, before the first shot) | `pre_match` ← Anvil of Doom; `pre_match_outrun` ← Neon Outrun; `pre_match_hymn` ← Apocalyptic Machine Hymn | tension, not combat. Anvil of Doom is dark (2.4 % above 4 kHz) with a quiet intro; Neon Outrun is the most synth-led of the set (45 % under 250 Hz, the lowest), nearest his *"noir synthwave, tactical preparation"* prompt; the Hymn is one of the three least percussive metal tracks |
| `lull` (a quiet spell after contact) | `lull` ← Subterranean Anvil; `lull_predator` ← Mechanical Predator; `lull_predator_b` ← Mechanical Predator (1); `lull_factory` ← Factory Silence | stalking, not attacking. **His two Mechanical Predator takes are in one state**, so the rotation is between comparable moods; Factory Silence has the narrowest loudness range of the 23 (6.3 dB), which suits a bed that must not surge |
| `skirmish` + `battle` (stem sets that build) | `fight_hydraulic` ← Hydraulic Wasteland; `fight_ritual` ← Ritual of Iron; `fight_rust` ← Rust & Hydraulic Pressure; **new:** `fight_machine` ← Machine Combat; `fight_momentum` ← Mechanical Momentum; `fight_convoy` ← Post-Apocalyptic Convoy | the most percussive of the metal tracks (onset peakiness 2.1-2.3 against 1.8-2.0), each split with demucs on builder0 and layered other → bass (0.35) → drums (0.6) like the first three |
| `last_stand` | `last_stand` ← Anvil Protocol; `last_stand_rusted` ← Rusted Steel Sky; `last_stand_brass` ← Warzone Brass | a deliberate change of song. Rusted Steel Sky is the fastest of the 23 (178 BPM); Warzone Brass is the brightest (6.7 % above 4 kHz), with brass over the chug |
| `defeat` | `defeat` ← Mechanical Dread; `defeat_ragnarok` ← Ragnarok's Engine; `defeat_hunt` ← Predatory Hunt | Mechanical Dread is the darkest metal track (2.3 % above 4 kHz); Predatory Hunt is the least percussive of all 23 (1.79); Ragnarok's Engine by its title. **The weakest placements: listen to these two first** |
| `garage` + `victory` (one pool) | `garage` ← Wasteland Blues (2); `victory` ← Wasteland Blues (1); `blues_wasteland` ← Wasteland Blues; `blues_neon` ← Neon Wasteland Blues | **his three Wasteland Blues takes and the neon variation, all in one pool.** They are his *Victory Pit / Scrapyard Smuggler* prompt, which this file already gave to both states. Nothing in the game asks for `garage` yet (the garage screen has no music director), so today they play on the victory |

Every bed is -16.1 to -16.3 LUFS, true peak -4.4 to -7.4 dB, loop seam ≤ 0.041 (limit 0.25), about 60 s of loop at
112 kbps (~0.8 MB); a stem set is ~2.6 MB. `assets/music/` went from 13 MB to ~30 MB, **and all of it ships in the web
pack** (question for the lead in `_agents/streams/archive/round12/audio.md`).

## Step by step

### Whole tracks (garage, pre_match, lull, last_stand, victory, defeat)
1. In Suno: paste **Style of Music** into the style box and the meta tags into the lyrics box; toggle **Instrumental**
   on. Generate until one feels right. Download the MP3.
2. Find a steady stretch: at least 30 seconds, ideally a minute or more, after the intro has finished and before the
   outro starts. Note its start and end as `m:ss`. The meta tags ask Suno for an intro and an outro, and neither loops,
   so don't use them.
3. Import it:

       make music-import IN=~/Downloads/lockdown.mp3 STATE=lull BPM=98 FROM=0:24 TO=2:08 RIGHTS="Suno Pro, 2026-09-18"

   It trims to your section, puts the loop points on whole bars inside it, normalises to -16 LUFS, encodes Ogg and
   writes the manifest row. **A second take for a state** needs its own row: add `ID=lull_foundry` (the file becomes
   `bed_lull_foundry.ogg`); it takes the intensity the state's other beds have, so the director rotates between them. For `victory`, import the Victory Pit track a second time with `STATE=victory`.
4. `make music-check`: it measures loudness and peak and prints the **loop seam**. Over the limit, the loop clicks
   every time it repeats: move `FROM`/`TO` by a bar or two and import again.

### The fight (three stem sets)
Suno gives a stereo mix, not stems. **Split it locally with demucs** (a music source separator), which runs on builder0
because it needs PyTorch (about 2 GB installed; the laptop's disk is at 97%). **Don't `pip install demucs` locally:**
`make music-stems` sends the track to builder0, where the venv already lives (`~/tank_squad/.tools/demucs-venv`, made
on first use if missing), and brings the stems back. It's tested on this repo's own mix: its drums stem follows the
real drums and its bass the bass. The alternative, generating a quiet and a loud take from the same prompt, fails
because two Suno generations are never the same arrangement at the same bar, so they can't be layered.

1. Generate the track in Suno as above and download the MP3.
2. Split it (about a minute per 2-minute track):

       make music-stems IN=~/Downloads/grinding_treadmill.mp3 OUT=build/audio/stems/treadmill

   You get `drums.wav`, `bass.wav`, `other.wav` (guitars, synths, pads) and `vocals.wav` (near-empty for an
   instrumental; anything vocal-like Suno added lands here, and it isn't used).
3. Import the stems as a fight set, quietest layer first:

       make music-import IN=build/audio/stems/treadmill STATE=fight_treadmill BPM=100 \
           LAYERS="other=0 bass=0.4 drums=0.6" FROM=0:20 TO=2:00 RIGHTS="Suno Pro, 2026-09-18"

   `other=0` plays from first contact, the bass comes in as the skirmish heats up, and the drums arrive with the
   battle. The numbers are MatchMood intensity (0 to 1) and can be tuned in `manifest.json` afterwards without
   re-importing. The first real fight set retires the placeholder for those states automatically.
4. Repeat with `STATE=fight_foundry BPM=105` and `STATE=fight_grime BPM=110`.
5. `make music-check` checks the stems line up, the full arrangement's loudness and peak, and that `other` on its
   own is still music rather than silence.

### Stingers
Two to four seconds, one-shot. Use your percussion palette as the Style of Music, one line each, and import them the
way the placeholders are listed in `manifest.json` (`sting.first_blood`, `sting.kill`, `sting.comeback`,
`sting.last_unit`, `sting.victory`, `sting.defeat`).

---

## The lead's prompts (verbatim)

### Tips for Best Results in Suno

1. **Keywords to mix & match:** Words like `Mick Gordon style`, `Carpenter Brut style`, `Darksynth`, `Industrial Metal`, `8-string guitars`, `analog distortion`, and `gritty` tell Suno exactly how much dirt and crunch to apply.
2. **Instrumental Switch:** Toggle Suno's **Instrumental** switch to "On" unless you specifically want robotic/vocoded callouts or aggressive death-growl battle chants.
3. **Looping / Background Suitability:** Suno often likes to add vocal-like synth leads; if it gets too melodically busy to loop behind gameplay, add tags like `minimal melody`, `steady driving rhythm`, or `game loop soundtrack` to keep the focus on the rhythm and atmosphere.

### `garage` and `victory`: Victory Pit / Scrapyard Smuggler (Dark Bluesy Cyber-Garage) (good for mech equipping and stuff)

*Best for: Results screen, black market dealer screens, or tuning specialized heavy artillery.*

**Style of Music:**
Instrumental Dark Cyberpunk Blues, Heavy Industrial Downtempo, 80 BPM, gritty slide guitar over deep analog synth bass, Mad Max desert wasteland, greasy mechanical atmosphere, slow dragging drum beat, smoky Blade Runner noir, low-frequency rumble

**Custom Meta Tags (Lyrics Box):**

    [Instrumental]
    [Intro: Resonant acoustic metal clank, deep pulsing synth]
    [Main: Slow dragged drum groove, dirty distorted slide guitar]
    [Atmosphere: Warm vintage synth chords, distant radio static]
    [Outro: Slow fadeout over low bass hum]

### `pre_match`: Hangar / Pre-Match Tank Customization / Garage

*Best for: The garage menu, mounting railguns, upgrading treads, and selecting armor plating before dropping into the arena.*

**Style of Music:**
Mid-tempo 95 BPM, atmospheric Cyberpunk, Blade Runner noir synthwave, heavy distorted bass groove, muted industrial guitar pulses, oily metallic grit, dark dystopian ambient, brooding, tactical preparation

**Optional Meta Tags:**

    [Instrumental]
    [Slow steady industrial beat]
    [Low warm synth pads, gritty bassline]
    [Sparse muted electric guitar accents]

### `lull`: Lockdown Protocol (Tension-Building Mid-Match Shift) (good but slow)

*Best for: Mid-round hazard phases (collapsing arena walls, toxic gas release, supply drops).*

**Style of Music:**
Instrumental Dark Electro-Industrial, slow burn 98 BPM, heavy syncopated guitar stabs, ominous Blade Runner brass synth, distorted sub-bass rumble, tactical dread, mechanical grit, brooding cinematic tension, dystopian sci-fi tank warfare

**Custom Meta Tags (Lyrics Box):**

    [Instrumental]
    [Intro: Pulsing warning synth, low sub-bass sweep]
    [Rhythm Enter: Punchy industrial kick and low, rhythmic guitar hits]
    [Mid Section: Ominous low synth horn, tense metallic hats]
    [Climax: Heavy distorted wall of sound, pulsing darksynth]
    [Outro: Abrupt mechanical cut]

### The fight, set 1: The Grinding Treadmill (Sustained Mid-Tempo Battle Groove) (GOOD)

*Best for: Protracted slugfests where heavy tanks are trading cannon fire at medium range; focuses on hypnotic, crushing rhythm over frantic speed.*

**Style of Music:**
Instrumental Mid-tempo Industrial Groove Metal, heavy 100 BPM, slow mechanical swing, brutal down-tuned 8-string chugs, fat overdriven Moog bass, hydraulic piston soundscapes, dark cinematic synth pads, oily grit, apocalyptic demolition arena, dystopian combat soundtrack

**Custom Meta Tags (Lyrics Box):**

    [Instrumental]
    [Intro: Low droning sub-bass and heavy hydraulic clanks]
    [Main Groove: Crushing syncopated guitar chug, fat industrial snare]
    [Layered: Gritty analog synth lead, dirty saw wave]
    [Heavy Breakdown: Pure bass fuzz and slow drum stomp]
    [Outro: Engine idle and dying distortion]

### The fight, set 2: The Scrap Foundry (Percussive & Mechanical Metal) (GOOD)

*Best for: An arena set inside an active smelting facility or automated weapons plant. Heavy emphasis on metallic impacts and relentless thumping rhythm.*

**Style of Music:**
Instrumental Industrial Cyber Metal, EBM crossover, 105 BPM, heavy syncopated rhythm, metallic anvil hits, distorted 303 acid bassline layered with low tuned metal guitars, dark mechanical chug, raw machine energy, Nine Inch Nails grit meets heavy arena combat

**Custom Meta Tags (Lyrics Box):**

    [Instrumental]
    [Intro: Factory rhythmic clatter, distorted bass sequence]
    [Groove: Heavy drum kick and low guitar chug locking into sync]
    [Section: Acid synth squeal weaving through industrial noise]
    [Bridge: Distorted sub drops and heavy metal clangs]
    [Outro: Fading machine hum]

### The fight, set 3: High-Tech Grime & Dystopian Sludge (Heavy Armor / Boss Fight) (GOOD)

*Best for: Encounters with massive, slow-moving super-tanks, irradiated wasteland arenas, and grinding metal treadplates.*

**Style of Music:**
Instrumental Cyber metal, Sludge Industrial, heavy low-tuned chug riffs, dirty Moog basslines, hydraulic and mechanical SFX, crushing mid-tempo 110 BPM, Mad Max post-apocalyptic atmosphere, gritty, distorted, ominous Blade Runner brass, relentless groove

**Optional Meta Tags:**

    [Instrumental]
    [Intro: Low droning sub-bass, heavy mechanical clangs]
    [Buildup: Rising industrial synths, slow tribal metal drums]
    [Main Riff: Heavy syncopated djent guitars with dirty analog fuzz]
    [Outro: Decaying distortion and warning sirens]

### `last_stand`: Cyber Metal / Dark Techno

**Style of Music:**
Instrumental Cyber Metal, Sludge Industrial meets Dark Techno, 115 BPM, lethal John Wick club combat vibe, driving four-on-the-floor kick, tight staccato 8-string chugs, distorted overdriven Moog bassline, metallic anvil strikes, slick cinematic noir strings, gritty tactical electronic groove, relentless momentum

### `defeat`: Acid Rain Wasteland (Sludge / Doom Cyberpunk)

*Best for: Outdoor, rain-slicked industrial scrapyards or toxic mud arenas where moving feels sluggish and dangerous.*

**Style of Music:**
Instrumental Cyberpunk Doom Metal, Sludge Metal combined with Darksynth, 85 BPM, crushing monolithic guitar riffs, gritty analog fuzz, eerie retro synth textures, Blade Runner rain ambience, heavy thunderous drums, dark dystopian oppression, rusted steel atmosphere

**Custom Meta Tags (Lyrics Box):**

    [Instrumental]
    [Intro: Dark atmospheric rain soundscape, mournful synth swell]
    [Drop: Massive monolithic fuzz-distorted riff, heavy slow beat]
    [Verse: Sparse low synth bassline, metallic percussion clangs]
    [Build: Screaming feedback and low war horn synth]
    [Outro: Heavy decaying guitar drone]

### Unassigned (a `defeat` alternative, or a boss-arena build later)

Instrumental Industrial Sludge Doom, 60 BPM, monolithic wall of sound, crushing down-tuned 8-string guitars, rhythmic anvil strikes, mechanical hydraulic hiss, subterranean sub-bass drone, apocalyptic brass synth, slow devastating groove, cinematic dark metal, unrelenting scale

### Stingers: the percussion palette

`anvil strikes on downbeat` · `heavy industrial steel clanks` · `distorted brake drum percussion` · `metallic bell impacts` · `harsh iron pipe hits` · `Mick Gordon killer instinct style industrial hits`

---

## What a finished file has to look like

Put the files in `assets/music/` and add a row to `assets/music/manifest.json`. The director reads nothing else.

| Field | What | Why |
|---|---|---|
| `file` | the file name, **Ogg Vorbis**, stereo, 44.1 kHz, about 96–128 kbps | the web build downloads it; MP3 and WAV are not used |
| `bpm` | the tempo Suno was asked for, measured from the file | the crossfade lands on a bar line |
| `beats_per_bar` | usually 4 | same |
| `loop_start_s`, `loop_end_s` | the seamless section, in seconds | the director loops this, not the whole file |
| `intensity` | 0.0–1.0, what this bed is worth | picks between two tracks for one state, and orders the beds |
| `stems` | instead of `file`: `[{"file", "from": 0.0–1.0}` or `{"file", "states": [...]}]`, quietest first | a track that builds with the fight (above) |
| `states` | which `MatchMood` states it may play under | one track can serve `lull` and `skirmish` |
| `peak_db`, `lufs` | measured, not guessed (`make music-check` prints them) | every bed sits at the same loudness so a crossfade doesn't jump |
| `rights` | the Suno plan the track was generated under, and the date | commercial use on Steam and Android |

Loudness target: **−16 LUFS integrated, true peak below −1.5 dBTP.** `make music-check` measures every track, fails on
anything more than 2 LU off the target or over the peak ceiling, and prints the loop seam's discontinuity so a bad
loop point is caught before it is heard.

**Converting what Suno gives you** is the step-by-step above (`make music-import`, `make music-stems`,
`make music-check`).
