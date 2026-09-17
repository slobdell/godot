# The soundtrack: one prompt per state

Owner: the audio stream ([../../_agents/streams/audio.md](../../_agents/streams/audio.md)). Design:
[../../_agents/game_design.md](../../_agents/game_design.md) *Audio: cinematic, and alive*.

The lead writes these tracks in Suno himself. **This file is the brief**: what to generate, in what style, and what
the file has to look like when it comes back so the music director can use it. The style below extends the prompts
the lead already liked (`/tmp/music_prompt.md`: *"heavy metal gaming music combined with synthwave combined with
heavy grit"*, Death Race meets Mad Max meets Blade Runner) to every state the match can be in.

> **Rights:** Suno's commercial rights depend on the plan the track was generated under. Before any of these ship in
> the paid Android build or on Steam, the lead confirms the plan allows commercial use, and we record the plan and the
> generation date in `manifest.json` (`rights` and `generated`). Placeholder loops in the repo today are ours.

## How the director uses them

One track per state. `MusicDirector` picks the track for `MatchMood.current().state` (L5), crossfades **on the beat**
using the tempo and loop points in `manifest.json`, plays a stinger over the top on kills and at the end, and ducks
everything under the announcer. So each track must:

1. **Loop seamlessly.** The director loops between `loop_start_s` and `loop_end_s`, not the whole file. Generate a bit
   more than you need at each end and put the loop points inside the steady part.
2. **Hold one tempo.** The crossfade lands on a bar line computed from `bpm` and `beats_per_bar`; a track that
   accelerates will drift out of the grid. Ask Suno for a steady tempo and no rallentando.
3. **Leave the middle clear.** The caller, the Veteran and the PA live in roughly 200 Hz – 4 kHz. Tracks that park a
   lead synth there get chewed up by the ducking compressor. Prefer low-end weight and high-end air over busy mids.
4. **Not resolve.** These are beds, not songs: no big ending, no long silence, no signature hook that gets old in the
   fortieth match.
5. **Be instrumental.** Toggle Suno's **Instrumental** switch on. Vocals compete with the booth.

## The states

Each entry is: when it plays → the **Style of Music** box → the meta tags → what to avoid.

### 1. `garage` — the army builder, between matches

Not a match. The player is reading unit cards and spending credits; this plays for minutes at a time.

**Style of Music**
> Instrumental Blade Runner noir synthwave, mid-tempo ninety-five BPM, brooding analog pads, gritty muted bass groove,
> sparse industrial guitar pulses, oily metallic ambience, tactical preparation, dark dystopian, minimal melody,
> steady driving rhythm, game loop soundtrack

**Meta tags**
> [Instrumental]
> [Slow steady industrial beat]
> [Low warm synth pads, gritty bassline]
> [Sparse muted electric guitar accents]

**Avoid:** anything that builds. This one has to survive twenty minutes of menu.

### 2. `pre_match` — the arena, before the first shot

The crews are on the floor, the PA is welcoming ninety-four thousand people, nothing has happened yet. Tension with
no payoff.

**Style of Music**
> Instrumental darksynth, one hundred BPM, slow rising arpeggiated bass, distant stadium crowd ambience, low brass
> swells, tense held drones, sparse tom hits, Carpenter Brut style, ominous anticipation, no drop, minimal melody

**Meta tags**
> [Instrumental]
> [Intro: distant crowd, low drone]
> [Slow rising arpeggio, sparse toms]
> [No drop, sustained tension]

**Avoid:** the drop. If it pays off, the first kill has nothing left to do.

### 3. `lull` — contact has not started, or the floor has gone quiet

The maneuver bed. Vehicles are repositioning; the player is scouting. Movement without violence.

**Style of Music**
> Instrumental industrial synthwave, one hundred five BPM, steady eighth-note bass pulse, muted palm-muted guitar
> chugs low in the mix, mechanical percussion, hydraulic clanks, cold analog pads, patrolling and searching, restrained,
> minimal melody, game loop soundtrack

**Meta tags**
> [Instrumental]
> [Steady driving pulse, restrained]
> [Muted low guitar chugs, mechanical percussion]
> [No lead melody]

**Avoid:** drums that sound like a fight. This is the floor the battle track has to feel bigger than.

### 4. `skirmish` — shots exchanged, nobody down

Half the band. It has to sit clearly between `lull` and `battle`, because the director crossfades between all three.

**Style of Music**
> Instrumental cyber metal, one hundred twenty BPM, low-tuned syncopated guitar riff, driving industrial drums,
> dirty Moog bassline, analog distortion, Mick Gordon style, gritty and urgent, steady driving rhythm, minimal melody,
> game loop soundtrack

**Meta tags**
> [Instrumental]
> [Main riff: syncopated low guitars, driving drums]
> [Dirty analog bass]
> [Steady, no breakdown]

**Avoid:** the full wall of sound. Leave headroom above this.

### 5. `battle` — sustained fighting, units dying

The one the lead's second prompt already described: the heavy armor track.

**Style of Music**
> Instrumental cyber metal, sludge industrial, heavy low-tuned chug riffs, dirty Moog basslines, hydraulic and
> mechanical SFX, crushing mid-tempo one hundred ten BPM, Mad Max post-apocalyptic atmosphere, gritty, distorted,
> ominous Blade Runner brass, relentless groove, eight-string guitars, game loop soundtrack

**Meta tags**
> [Instrumental]
> [Intro: low droning sub-bass, heavy mechanical clangs]
> [Buildup: rising industrial synths, slow tribal metal drums]
> [Main Riff: heavy syncopated djent guitars with dirty analog fuzz]
> [Outro: decaying distortion and warning sirens]

**Avoid:** a busy lead in the vocal range; the booth is loudest here.

### 6. `last_stand` — your force is down to its last third and losing

Not louder than `battle` — *desperate*. Heroic and doomed at once. This is the track a player remembers.

**Style of Music**
> Instrumental darksynth metal, one hundred twenty eight BPM, driving relentless kick, soaring distorted lead synth
> over crushing guitars, tragic minor-key brass, air-raid siren pads, last stand, heroic and doomed, Carpenter Brut
> style, huge and desperate, steady driving rhythm

**Meta tags**
> [Instrumental]
> [Relentless driving kick and bass]
> [Soaring tragic lead synth over heavy guitars]
> [Rising siren pads]
> [No resolution]

**Avoid:** resolving. The player might still lose.

### 7. `victory` — the match is over and you won

Plays over the results screen, so it may resolve. Still loops (the player reads their credits).

**Style of Music**
> Instrumental triumphant darksynth, one hundred twenty BPM, major-key distorted lead synth, heavy victorious guitars,
> stadium crowd roar, big gated drums, industrial fanfare, celebratory but gritty and dirty, retro arcade victory,
> game loop soundtrack

**Meta tags**
> [Instrumental]
> [Fanfare: distorted brass and lead synth]
> [Big gated drums, crowd roar]
> [Settles into a steady victorious loop]

**Avoid:** clean and polished. This is a prison arena, not a sports network.

### 8. `defeat` — the match is over and you lost (or drew)

**Style of Music**
> Instrumental dark ambient industrial, seventy BPM, slow decaying distorted guitar drone, hollow sub-bass, distant
> crowd, broken machinery, cold empty reverb, mournful minor pads, sparse, Blade Runner noir, resigned

**Meta tags**
> [Instrumental]
> [Slow decaying distortion]
> [Hollow sub-bass, distant crowd]
> [Sparse mournful pads]

**Avoid:** punishing the player. Sad, not sarcastic.

## Stingers (short, one-shot, over the top of the bed)

Two to four seconds each, generated the same way, mono or stereo, **no tail that outlasts the moment**. The director
plays them without changing the bed.

| Id | When | Style of Music |
|---|---|---|
| `sting.first_blood` | the first kill of the match | Instrumental, two seconds, single crushing industrial guitar stab with a sub-bass drop and a short metallic ring |
| `sting.kill` | a kill during `battle` (rate-limited) | Instrumental, one and a half seconds, short distorted percussive hit, dirty analog, no tail |
| `sting.comeback` | the losing side takes the lead back | Instrumental, three seconds, rising distorted synth swell into a bright major stab, hopeful and gritty |
| `sting.last_unit` | your force is down to one vehicle | Instrumental, three seconds, descending air-raid siren with a low tragic brass hit |
| `sting.victory` | the match ends in a win | Instrumental, four seconds, triumphant industrial brass fanfare with gated drums and a crowd roar |
| `sting.defeat` | the match ends in a loss | Instrumental, four seconds, collapsing distorted drone into silence, hollow and final |

## What a finished file has to look like

Put the files in `assets/music/` and add a row to `assets/music/manifest.json`. The director reads nothing else.

| Field | What | Why |
|---|---|---|
| `file` | the file name, **Ogg Vorbis**, stereo, 44.1 kHz, about 96–128 kbps | the web build downloads it; MP3 and WAV are not used |
| `bpm` | the tempo Suno was asked for, measured from the file | the crossfade lands on a bar line |
| `beats_per_bar` | usually 4 | same |
| `loop_start_s`, `loop_end_s` | the seamless section, in seconds | the director loops this, not the whole file |
| `intensity` | 0.0–1.0, what this bed is worth | picks between two tracks for one state, and orders the beds |
| `states` | which `MatchMood` states it may play under | one track can serve `lull` and `skirmish` |
| `peak_db`, `lufs` | measured, not guessed (`make music-check` prints them) | every bed sits at the same loudness so a crossfade doesn't jump |
| `rights` | the Suno plan the track was generated under, and the date | commercial use on Steam and Android |

Loudness target: **−16 LUFS integrated, true peak below −1.5 dBTP.** `make music-check` measures every track, fails on
anything more than 2 LU off the target or over the peak ceiling, and prints the loop seam's discontinuity so a bad
loop point is caught before it is heard.

**Converting what Suno gives you** (it returns MP3 or WAV):

    make music-import IN=~/Downloads/battle.mp3 STATE=battle BPM=110
    # decodes, trims, finds the nearest bar lines for the loop, encodes Ogg, measures loudness,
    # and writes the manifest row for you to check.
