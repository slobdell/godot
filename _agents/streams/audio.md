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

_Updated 2026-09-16 by the audio worker._

**Done: X1 (variance), X5 (MatchMood), most of X6 (music pipeline). X2 is blocked on the lead (the API key).
In progress: X3 (booth live), then X4 (sound effects).**

### Waiting on the lead

1. **The ElevenLabs API key (blocks X2 entirely, and the ElevenLabs source for X4).** `ELEVENLABS_KEY_ID` in
   `~/.bashrc` holds a 64-hex-character value, which is a key **id**, not an API key. The API refuses it:
   *"API key ID used as API key - only valid API keys can be used. API keys start with 'sk_' and are shown when the
   key is created or rotated."* (verified against the live API with the pinned SDK; nothing was generated, no credits
   spent.) There is no `sk_` key in the environment or in the mavlink-hud reference project.
   **What to do:** elevenlabs.io → Settings → API Keys → create or rotate, copy the `sk_…` value shown once, and
   export it before the interactive guard in `~/.bashrc` (trip-up 59). Either name works now:
   `ELEVENLABS_API_KEY` is preferred, `ELEVENLABS_KEY_ID` still read. Also confirm the plan is a **paid** one: the
   free tier is non-commercial with attribution, and the run needs ~28.5k credits.
   The pipeline now refuses a key id up front with that message instead of sending a doomed request.
2. **The Suno tracks.** The pipeline, the per-state prompts and placeholder beds all ship now; see
   `assets/music/PROMPTS.md` and *What to playtest* below.

### Done

**X1 — variance before generation.** Measured first: `make announcer-variance` replays every fixture as 50
consecutive broadcasts through one recency memory and reports how often an opener comes back inside five matches.
The lead's complaint was real and large.

| | before | after | ceiling |
|---|---|---|---|
| the opening line repeats within five matches | **32.1%** | **6.9%** | 10% |
| the PA's welcome repeats within five matches | **49.2%** | **5.6%** | 10% |
| lines carried over from the previous match | 23.2% | 3.9% | 30% |
| a line said twice in one match | 0 | 0 | 0 |

Every fixture is under the ceiling individually (2–8% openers, 2–6% welcomes). Three causes, all fixed:
- **No memory past the final whistle.** `AnnouncerHistory` keeps the last eight matches' line ids in
  `user://announcer_history.json`; the director multiplies each line's pick weight by how recently it was heard. The
  penalty table is sized against the director's own 8×-per-matched-tag specificity weighting, so a recent line loses
  to a slightly less specific fresh one but not to a much less specific one.
- **Too few lines per opening slot.** Ten PA welcomes over a five-match window repeat about half the time whatever
  the weighting does. Library **429 → 490**: PA welcomes 10 → 30, the caller's intros 12 → 29, the Veteran's 6 → 14,
  plus six caller results, five PA sign-offs and five Veteran results (the hot-line report showed those carrying most
  of the match-to-match carryover; they are out of the top twenty now).
- **One tag-specific line winning outright.** `pa.welcome.10` was the only welcome tagged `control_point`, so it took
  roughly half of all intros on the default arena. There are now three, plus per-arena welcomes and intros.

The booth loads and saves the memory around a live match. `--announcer-history=PATH` points it elsewhere and `off`
disables it; a record-only booth never touches it, so automated runs never write the player's file (trip-up 54).
The review transcripts are regenerated and the text audit is clean at 490 lines.

**A real bug the new test found:** `JSON.parse_string` pushes an *engine error* on malformed text, which the test
runner counts as a failure and a player would have seen in their log. A corrupt history file is now read through a
`JSON` parser instance and simply treated as a booth with no past.

**X5 — the match mood signal (L5).** `game/audio/match_mood.gd`: `current() -> {intensity 0..1, state, reasons[]}`
over the same K5 event stream the announcer reads, with no clock of its own, so it is deterministic and runs over the
fixtures. Heat accumulates per event and decays with a seven-second half-life; states are `lull`, `skirmish`,
`battle`, `last_stand`, `victory`, `defeat` with hysteresis so one stray round can't flap the music.
**State is from one team's point of view** — the same match is a victory for one bench and a defeat for the other,
and a last stand is something that happens *to you* (a test covers both benches of the same match). `reasons` are
plain words the announcer or a log can quote ("green is down to one against four"). 12 tests, including every
fixture producing a plausible arc and the reading never leaving its contract.

**X6 — the dynamic music pipeline (placeholders now).**
- `game/audio/music_director.gd`: one bed per mood state, **crossfaded on a bar line** worked out from the manifest's
  tempo (a fade that lands mid-bar sounds like a mistake), stingers over the top with a cooldown, looping between the
  manifest's loop points rather than over the whole file, and a `Music` bus sidechain-ducked under `Announcer` (the
  same trick `AnnouncerVoice` uses for the world bus). Adding a track is a file and a manifest row, never code.
  10 tests.
- `assets/music/PROMPTS.md`: the brief for the lead — one Suno **Style of Music** prompt and meta tags per state
  (garage, pre-match, lull, skirmish, battle, last stand, victory, defeat) in the style he already liked, six
  stingers, the five rules a bed has to follow to be loopable and duckable, and exactly what the manifest row needs.
- **Placeholder beds ship now** (`make music-placeholders`, 537 KB): synthesised here, CC0, deliberately plain, but
  at real tempos with real loop points, normalised to −16 LUFS and limited under −1.5 dBTP so swapping in a real
  track doesn't change the mix. `make music-check` enforces the whole contract (loudness, true peak, loop points
  inside the file, and the **loop seam's discontinuity**, which is what makes a bad loop click on every repeat) and
  is in `make check` through the new `audio-check`.
- `make music-import IN=… STATE=… BPM=…` turns one Suno download into a bed: trims silence, puts the loop points on
  **bar lines**, normalises and limits, encodes Ogg, and writes the manifest row without clobbering tuning the lead
  has already done. It nags if the Suno plan wasn't recorded, because commercial rights depend on it.

**The mixdown flake (not in my backlog; the orchestrator asked for it early).** `test_mixdown_places_parts_fillers_and_cuts`
was failing other streams' checks with 5.197 s instead of 7.0 s. It is **not load**: `apad` after `amix` simply does
not pad on ffmpeg 6.1.1, so the mix ended with its last clip. `render()` now mixes against a generated `anullsrc`
input as long as the match (`amix duration=longest`), which is version- and load-independent, and verifies its own
output length and raises with both numbers rather than shipping a short mix that would desync the demo page. The test
no longer proves the schedule by measuring audio. Mutation check: putting `apad` back reproduces 5.197 s exactly.
Committed as 5ccf56f and reported to the orchestrator for merging to `main`.

### Decisions

- **Measure before fixing.** The first thing X1 shipped was the audit, not a fix; the "before" numbers are what
  makes the brief's "~10%" target checkable, and they are now a gate in `make check`.
- **Recency weighting rather than a ban list.** A hard "never repeat within N matches" rule breaks down where a slot
  has one eligible line (a control-point welcome on a control-point arena). Weighting degrades gracefully: with one
  candidate it still plays.
- **Eight matches of memory.** Long enough that a session's worth of matches doesn't repeat, short enough that the
  file stays tiny and a line the player liked comes back.
- **MatchMood takes a point of view.** L5's `victory`/`defeat` states are meaningless without one, and the music for
  a last stand should only play for the side making it.
- **Placeholder music is synthesised here, not sourced.** No licence question, no download, regenerable, and
  obviously placeholder — but it carries real tempo, loop and loudness metadata, so the director is exercised
  end to end and swapping in a Suno track is a file plus a row.
- **A tolerance, not a target, for loudness.** Placeholders land within 1.5 LU of −16 LUFS; `music-check` allows 2 LU,
  because Suno's output won't be exact either and re-normalising a finished track twice does it no favours.

### Known issues

- `caller.hit.07/08/14` (the weak-spot calls) are the most-said lines at ~1.5% each: that moment's pool is narrow.
  It is inside every ceiling and no line repeats inside a match, so it is a top-up for later, not a defect.
- The placeholder beds are exactly that. They are correct, not good.
- `make remote T=check` has not yet run green on this branch: builder0 has been saturated by the other four streams
  all session. The baseline run I started at the beginning finally completed and failed on the pre-existing mixdown
  flake, which is the bug I then fixed.

### What to playtest

- `make announcer-variance` — the numbers above, and `HOT=20` for the most-said lines.
- `make announcer-transcript FIXTURE=close_match SEED=1` (any fixture, any seed): the PA's new openings.
- `make music-check` — every bed's loudness, peak, loop points and seam.
- `make music-placeholders` — regenerate the beds; then `make music-import IN=<a Suno file> STATE=battle BPM=110`.

### Next steps

1. **X3**: the booth and the music in a live skirmish — flags, an options entry, and screenshots at both aspects.
2. **X4**: the sound effects. ElevenLabs' sound-effects generation is blocked with X2, so the plan is layered
   synthesis (transient, body, tail, reflections), variation pools so nothing repeats, distance filtering, and a real
   bus mix with headroom — all licence-clean and regenerable, with the ElevenLabs source added when the key lands.

### Merge notes (shared files)

- `mk/core.mk`: `audio-check` appended to `check`'s prerequisites (music contract checks, a few seconds).
- `mk/audio.mk`: new, mine.
- `_agents/orientation.md`: trip-up 67 added (GNU make defines `WINDOW = 2` itself).
