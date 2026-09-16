# Stream: audio (sound effects, the announcer for real, dynamic music)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 4 direction*: audio; *The arena announcer* including the **humor direction**), and
> [../workstreams.md](../workstreams.md) (**L5 is yours**; lead gate 1 is now approved). You own `game/announcer/`,
> `game/audio/` (new), `assets/announcer/`, `assets/audio/`, `assets/music/` (new), `game/theme/audio/`,
> `tools/announcer/`, `tools/audio/` (new), `mk/announcer.mk`, `mk/audio.mk` (new), `tests/announcer/`.
> Round 3: [archive/round3/announcer.md](archive/round3/announcer.md) and [archive/round3/feel.md](archive/round3/feel.md)
> (feel built the effect *triggers*; you own how they sound).

## The lead's direction (2026-09-16)

> *"we also have all of our voices prepared so we should be able to run the whole pipeline; the sample announcer
> scripts look good, but some of them were fairly repetitive (i.e. same opening announcement from the syndicate
> announcer lady across multiple cases, I assume we need to generate more variance for whatever decision tree that was
> created), but otherwise we can have an agent go ahead and run the full ElevenLabs pipeline to generate the output ogg
> files, and we need to get the announcer scripts ready to plug in to the real game. The sound effects for the game also
> currently completely suck, and now that we have the ElevenLabs pipeline we should definitely figure out how to create
> immersive sound effects better - right now the sound effects make it sound like an atari game rather than a gritty
> action game."*
>
> Tone: **cinematic exaggeration**, not documentary realism (the lead's pick). Music: *"the best case is a living,
> breathing music selection with the game"*; the lead writes the tracks in Suno later and has style prompts in
> `/tmp/music_prompt.md`. **Build the pipeline and the per-state prompts now, with placeholders.**

## Where things stand (round 3)

- **Announcer:** 429 tagged lines, the banter director (moments, beats, memory, cooldowns), transcripts, the booth
  page, the in-game adapter, and the whole ElevenLabs pipeline built against a **mock** client (slicing by character
  timestamps, loudness, speech-to-text check, Ogg encode, manifest, ledger, `DRY_RUN=1`). Voices: `JR1` (caller),
  `corporate2` (PA), `veteran` (colour). Dry run: ~28,524 characters for 701 clips.
- **Sound effects:** synthesized from noise and pulses in code (`assets/audio/*.wav`), triggered by feel's `WeaponFx`,
  `MotionFx` and HUD. The lead's verdict: Atari.
- **Music:** none.

## Backlog (in order)

**X1. Variance before generation.** The lead saw the PA repeat her opening across matches. Fix the cause, not the
symptom: more openers and variants per moment, recency memory that persists **across matches** (`user://`), slot
variety, and an audit that reports the repeat rate over 50 simulated matches per fixture. Target: no line repeats
within a match, and an opener repeat rate under ~10% across five consecutive matches. Regenerate transcripts and say in
Status what changed.

**X2. The real announcer run (lead gate 1, approved).** Pilot first (~250 characters: a few caller, PA and Veteran
lines), listen, check stitching and levels, then the full run. Log every request and its credits in
`assets/announcer/ledger.md`, keep masters out of git, ship compressed Ogg plus the manifest, and re-check every clip
with speech-to-text. Report the real spend against the ~28.5k estimate.

**X3. The booth in live matches.** Wire the adapter to real `Match` events (K5), an announcer audio bus that ducks
music and effects, subtitles through the HUD, and a volume or off setting. Verify in a real skirmish, not only fixtures.

**X4. Sound effects that sound like a film.** Replace the synthesized placeholders with layered, cinematic sound:
- Weapons: transient crack, body, and a long tail; tank cannon, 25 mm burst, machine-gun stream, laser, mortar, flame.
- Impacts: armor spark, shield, weak spot, kill explosion and cook-off, wreck fire.
- Vehicles: engines by speed and load, treads and tires, braking and drift.
- World: crowd swell tied to the match mood, arena PA, ad screens.
Source them with ElevenLabs' sound-effects generation and CC0 libraries (record licenses), then process: variation
pools so nothing repeats, distance filtering and rolloff, a real mix with headroom and a limiter. Keep the file size
sane and report it. **Feel owns when effects fire; you own how they sound.**

**X5. The match mood signal (L5).** `MatchMood` derived from the event stream: intensity 0–1 plus a state (lull,
skirmish, battle, last stand, victory, defeat) and the reasons behind it. It drives the announcer's energy, the music,
and later the crowd and screens. Tests over the fixtures.

**X6. The dynamic music pipeline (placeholders now).** `game/audio/`: a music director that picks a track per state,
crossfades **on the beat** (each track carries tempo, loop points and intensity tier in a manifest), plays stingers on
kills, comebacks and match end, and ducks under the announcer. Ship with placeholder loops so it's testable end to end,
and write `assets/music/PROMPTS.md`: one Suno prompt per state, in the style the lead already likes
(`/tmp/music_prompt.md`), plus the format and metadata each file needs. Note that Suno's commercial rights depend on
the lead's plan.

- **Stretch:** stems (split a track locally) so layers can build with intensity; an arena PA that reads ad copy between
  rounds; per-faction announcer flavour.

## How to verify

`make remote T=check`; the announcer's Python tests; the repeat-rate audit; **listen** to the pilot and to a full
match's mixdown (say what you hear in Status, and give the lead exact commands); a real skirmish recording with
announcer, effects and music together; file sizes and the mix's headroom.

## Don't touch

When effects fire and the visual effects themselves (feel's code from round 3: `game/theme/fx/**`), gameplay (combat,
doctrine, ai), the camera and HUD layout (control). You may add an audio bus and a settings entry (shared files:
minimal, listed in merge notes).

## Status

- 2026-09-16: brief written for round 4. Nothing started.
