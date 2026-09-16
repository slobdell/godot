# Stream: audio (sound effects, the announcer for real, dynamic music)

> **Archived 2026-09-16:** round 4 is merged into `main`. This brief and its Status are the record of what the stream did;
> the current round is in [../../../workstreams.md](../../../workstreams.md).

> Read [../orchestration.md](../../../orchestration.md) (the worker contract), [../game_design.md](../../../game_design.md)
> (*Round 4 direction*: audio; *The arena announcer* including the **humor direction**), and
> [../workstreams.md](../../../workstreams.md) (**L5 is yours**; lead gate 1 is now approved). You own `game/announcer/`,
> `game/audio/` (new), `assets/announcer/`, `assets/audio/`, `assets/music/` (new), `game/theme/audio/`,
> `tools/announcer/`, `tools/audio/` (new), `mk/announcer.mk`, `mk/audio.mk` (new), `tests/announcer/`.
> Round 3: [archive/round3/announcer.md](../round3/announcer.md) and [archive/round3/feel.md](../round3/feel.md)
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

## The lead's direction (2026-09-16, after hearing the real voices)

> *"basically it's no good. Our madlibs / adlibs style of swapping words into sentences just clearly doesn't work
> … we either need to generalize the things that can be said or we need to create multiple versions of a given
> script … but that can quickly blow up so we might want to generally rethink our strategy for announcing teams.
> Furthermore, the conversations are overwhelmingly dominated by the Caller, we don't have much banter from the
> Veteran."*

And the creative opening he gave with it:

> *"in sporting events the veteran often educates users about good technique in a sport, or technical reasons why
> someone has the upper hand or a disadvantage. We can make the veteran provide some technical analysis, but we can
> add some humor into it by the veteran completely trailing off after incomplete thoughts, never fully making his
> point (think the humor in The Big Lebowski), or the veteran can just say some factual, straight faced statements
> that would otherwise be appalling ("when you're driving in that formation, your point man better be sure that
> he's focused and ready for whatever comes next, because there's about a 90% chance that his life is about to
> end")."*
>
> *"there's opportunities for interjection from the PA where she offers polite factual corrections to the
> announcers saying things out of bounds in our dystopian state. For example, caller might say something like 'Wow
> the Gang really stuck it to the Law in that one!' to which the PA might interject 'That's right Joseph … That
> same maneuver performed outside of the arena would have resulted in an immediate Article 57-8C for the suspect
> and all of his blood relatives'"*

**Canon:** the caller is **Joseph** (the lead: *"the caller should be referred to as Joseph since it's a parody of
Joe Rogan"*). The other two may now address him by name. Keep the character original: no real name, catchphrases or
references (the standing rule in game_design.md *Voices*).

## Why stitching failed, and what replaces it (decided 2026-09-16)

**Diagnosis.** A sentence's intonation spans the whole sentence. Cutting a word out of one recording and dropping it
into another gives it the wrong pitch, stress and length for its new home — the defect is *prosody*, not level or
slicing, so no amount of tuning the cuts would have fixed it. The pilot's checks could not catch this: every clip
transcribed correctly and sat at the right loudness. **It was audible to the first person who listened, and I never
listened.** That is the lesson, not the credits.

**Replacement: record whole sentences, one per realization.** No slicing, no fillers, no joins. The library stays
templated for authoring and for the director; the *recording plan* expands each template into the full sentences it
can become, and a cue plays exactly one clip.

**What that costs, measured over the current library** (227 of 490 lines carry slots; the other 263 are already
whole sentences, already recorded, and still good):

| | recordings | credits |
|---|---|---|
| naive full expansion | 3,560 | ~227,000 |
| **cap of 12 combinations a line** | **816** | **~51,000** |
| cap of 6 | 504 | ~32,000 |

The naive number is not a reason to abandon the idea — it is 13 lines out of 227 doing 65% of the damage. One line
(`caller.tape.03`, *"it's {count} for {team} and {other_count} for {other_team}"*) needs 676 recordings by itself.

**Writing rules that follow** (they are also just better writing):
1. **One variable thing per sentence.** Never two units, never a count beside a team. Every line in the expensive
   tail breaks this.
2. **No exact numbers in speech.** `{count}` is 13 values, and at thirty units a side an exact count is wrong as
   often as it is right. "Half their force", "a handful left", "most of them" instead.
3. `{team}` (2 values, in 136 lines), `{arena}` (3, fixed per match) and a *single* `{unit}` (6) are all cheap and
   stay. Recording both team variants whole is what actually fixes *"Green fields the Condemned tonight"*.

**What survives the change:** the 263 slotless clips, and every master (223 MB, rescued to the main checkout), so
re-cutting costs nothing. What is thrown away: 423 segment clips and 91 fillers — the stitching machinery.

## The rebuild (2026-09-16, after the lead heard the stitched build)

**What was wrong and what replaced it** is above under *Why stitching failed*. What the rebuild actually changed:

| | before | after |
|---|---|---|
| a cue plays | carrier segments + filler words, joined | **one recording of one whole sentence** |
| a side is called | "Green", "Rust" | **its faction**: the Condemned, the Wreckers, the Law, the Syndicate |
| the Veteran's share of the words | 20% | **31%** (the caller 57% → 49%) |
| library | 490 lines | 550 |
| recordings | 777 | 2,225 (~137k credits, of which 116.5k new) |

**The gang faction is "the Wreckers"** — from the lead's own shortlist in game_design.md (*the Wreckers / Scrapborn /
Chrome Cult*). It matches the shape of the other three: a definite-article collective noun naming what the group is,
and it doubles as salvage-crew slang that fits their tow-wrecker roster. One vocabulary entry, trivially changed.

**Three forms of a faction name, because English needs them.** The plain name carries its own article ("the Law"),
`{faction_attr}` is the attributive form for after one ("the Law tank"), `{faction_s}` the possessive. The audit
enforces both traps this exposed, so they cannot come back:
- an article before a plain faction name ("The last **the Condemned** vehicle") — 3 lines;
- a **singular verb** after one ("the Wreckers **cracks** it") — 85 lines. A faction is a crew and takes a plural
  verb, the way sports commentary treats every team name; it is the only rule that works for all four names at once.

**Counts are quantized, not dropped** (the lead's idea): "over {count_over} vehicles" is true at any army size and
costs six recordings instead of one per possible number. `AnnouncerMemory` stores the bucket — the largest multiple
of five strictly below the real count — so nothing downstream knows about rounding, and below five the slot is
unset, which makes those lines ineligible and the booth says something else.

**Why the Veteran was quiet, which was not what it looked like.** He had 147 lines to the caller's 260, but that was
not the cause: the director skipped every non-caller follow-up for 1.5 seconds after *any* shot, so in a sustained
firefight he was mute exactly when he had most to explain. That window is now 0.5 s, analysis *of* the moment being
called is exempt entirely, and he opens beats of his own. The 60 new lines give him the three registers the lead
asked for — real technique a player can use, thoughts that trail off and never land, and flat statements of
appalling fact — and give the PA polite legal corrections addressed to **Joseph**, who is now the caller's name.

**Cost discipline.** `MAX_COMBINATIONS` (24) refuses a line that names more than one variable thing instead of
quietly ordering 676 recordings of it; 16 lines were rewritten to obey it. Opponents are always different factions,
which removes three quarters of the combinations of every line naming both sides.

**A second pilot went to the lead before the full run** (41 recordings, 1,875 credits): the same kill call for all
four factions back to back, so any remaining seam would be obvious, plus both new characters.
<https://claude.ai/artifact/VnKAEDc9y4TZMHYnHSuiiU>. He approved the full run from it.

## A recorded line outlives the number that justified it (2026-09-16)

The constraint that makes this stream different from every other one: **nothing the booth says can be edited.** A
clip can only be re-recorded, for credits, and re-shipped. So a line asserting something about how the game works
is a promise the build has to keep, and the cost of being wrong is paid months later.

Doctrine raised it (they marked up which of their measurements are safe to quote, `_agents/doctrine.md`), and it
generalises to every stream that measures anything. Geometry and armour facing are safe — a column watches the
whole circle, a line 0.42 of it, bunched vehicles shoot later because only the front can bear. Survival numbers
resting on a half-built mechanic are not: "bounding overwatch gets you killed" is true of a build with no
deliberate suppression, and combat is landing exactly that.

Two lines were cut for this before recording. Cutting them afterwards would have meant a clip that contradicts the
game. The rule is in `assets/announcer/README.md` so it survives this round: **when in doubt, describe rather than
evaluate.**

**Standing request to other streams:** if you measure something and it surprises you, send it — the Veteran is the
only one in the booth who gets to be precise, and a number a player can act on is better material than anything I
would invent. Say whether it is stable or resting on something you are still building.

## X2 delivered: the booth has a voice (2026-09-16)

| | |
|---|---|
| library | **589 lines** (caller 267, Veteran 225, PA 97) |
| recorded | **2,372 whole sentences**, ~14 MB of Ogg |
| spend this session | **171,050 credits**; 125,297 left of 300,000 |
| main run | 2,225 clips, 110,091 characters, 112,717 credits |
| incremental (element and drill material) | 171 clips, 12,593 characters |
| listen | <https://claude.ai/artifact/7tZzJRW8BhMcX7dnWfSzUc> — eight full matches |

**What the 36 speech-to-text flags were worth.** All 36 were the caller; none the Veteran or the PA, which fits — he
delivers short phrases at speed. Most were the recogniser's problem, not the audio's ("Ohh, that rocked" heard as
"Pull that rock"). **One was a real finding, and only because every combination was recorded rather than sampled:**
all eight variants of `caller.ff.05` came back misheard *identically* — "{faction_s} own {victim_unit}" elided to
"the condemned **zone** artillery", "the wrecker **zone** burner", "the law **zone** IFV". A possessive immediately
followed by "own" runs together at his pace. One flag is noise; eight failing the same way is a cause. Rewritten to
"their own {victim_unit}": correct, and a quarter of the recordings, because the team was obvious from context —
which is usually the sign the original had a redundant variable in it.

**The starvation pattern, three times in one round.** The tactical commentary was silent in every transcript. The
obvious reading was that I had not written enough of it. The director's own decision log said otherwise: **6 of 8
element moments expired while queued behind kill calls**, against a `stale_s` of 4–6 seconds; one more was dropped
from a full queue. They were never outranked — they timed out. Formation now waits 20 s and a drill 10 s, because
that kind of colour is what a booth says in the gap *after* the action. Two of eight element decisions now get
called in a busy match, which is the right rate.

That is the same shape as the Veteran's airtime problem (a heat rule silencing him) and as two bugs doctrine hit
independently. Written up for `orchestration.md`: **a behaviour that looks under-written is usually being starved by
a rule above it — before adding content, log what selected it each tick.**

## Housekeeping found two things worth knowing (2026-09-16)

Both came from actually measuring at the end rather than trusting earlier numbers.

**The clips folder's `.gdignore` was gone.** Wiping `assets/announcer/clips` to re-cut the pilot deleted the marker
with it, so Godot imported all 2,396 clips and **2,396 `.import` files were committed**. Deleting them is the
cleanup; the fix is that `generate.py` now writes the marker itself and clears stale `.import` files after every
run, so a wipe cannot lose it again.

**The masters were 1.1 GB, not the 340 MB I had reported.** Only 176 MB were masters; ~950 MB were `.norm.wav` and
`.level.txt` caches the pipeline writes beside each one — about six times the size of what they cache, on a laptop
at 98% disk. The pipeline now drops them at the end of a run. With 340 stale master sets from deleted lines also
pruned: **1.1 GB → 176 MB**, and the laptop went from 2.4 GB free to 3.3 GB.

**For whoever closes the round:** `assets/announcer/masters/` is **176 MB** and must be rescued before this worktree
is removed — it is worth 171k credits, because everything in `clips/` can be re-cut from it for nothing. The 223 MB
rescued to `main` earlier is **superseded, not additive**: those masters were recorded against line texts the
rebuild changed.

## Status

_Updated 2026-09-16 by the audio worker._

**Done: X1 (variance), X3 (the booth and the music in live matches), X4 (the sound mix), X5 (MatchMood), X6 (the
music pipeline). X2 is blocked on the lead: the environment has an ElevenLabs key *id*, not an API key.**

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

**X3 — the booth and the music in live matches.** The booth already listened to real `Match` signals through
`MatchEventAdapter` (round 3, K5). What round 4 adds:
- The booth keeps the match's **`MatchMood`** up to date from the same events it already polls, so there is one
  adapter and one mood for everything that reacts to the match. `--music` on its own attaches a *silent* booth, so
  the music works without the announcer.
- `MusicDirector.attach()` from `game/main.gd`, beside the booth, on `--music=on` (`--music-volume=DB`,
  `--music-dir=PATH`). It follows the booth's mood: the bed changes at the next bar line, the result plays its
  stinger.
- **The ducking chain is now real.** `AnnouncerVoice` sidechains a compressor onto a `World` bus that nothing
  previously created; `SfxSystem` now creates it and routes every world voice through it, and `MusicDirector` adds
  its own `Music` bus ducked under `Announcer` as well. So speech ducks both the battle and the music, and that is
  wired rather than described.
- `assets/announcer/*.json` and `assets/music/*.json` are added to `include_filter` in `export_presets.cfg`, or the
  web and server builds ship without the line library and the music manifest (trip-up 30).

**X4 — the sound effects.** The lead's *"atari"* verdict was about three things, none of them any single sound's
synthesis, and all three are fixed:
- **Every shot was the same recording.** A scout's machine gun fires eleven rounds a second and every one was
  byte-identical; ±12% pitch jitter does not hide that. The most-repeated sounds now come in several **takes**
  (4 for `mg_round` and `bullet_hit_metal`, 3 for `autocannon_shot`, `ricochet`, `shell_hit_armor`, `dirt_impact`,
  `explosion_small`, 2 for `weak_spot_hit`, `tank_boom`, `cannon_shot`), each synthesised from its own seed, and
  `SfxSystem` draws one per shot. Loops keep a single take, because feel's engine and crowd systems duplicate them
  to set loop points — a contract a test now guards, since those files are feel's and not mine to adapt.
- **Nothing mixed the battle.** Twenty voices summed straight into the master, so a firefight clipped and turned to
  mush. World sound now goes through the `World` bus, trimmed 6 dB with a limiter at −1 dB.
- **Distance only made things quieter.** Sounds now carry a distance filter, so a cannon across the arena is dull
  as well as quiet (the tank's boom falls to 1.4 kHz and −22 dB at maximum range) while small metallic sounds that
  are only ever heard close keep their brightness.

**Size:** 48 WAVs, 2.0 MB in git (the takes added 590 KB); every one imports as Quite OK Audio, so the exported pack
carries roughly a quarter of that. `assets/music` is another 537 KB of placeholder Ogg.

**What X4 did not get** (it needs X2's key): ElevenLabs' sound-effects generation, and CC0 source material layered
under the synthesised transients. That is the step from "clean, varied and properly mixed" to genuinely cinematic,
and it is the first thing to do when the key lands.

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
- `music-smoke` only sees **two** bed changes in its forty-second match (lull at 0 s, battle at 12.7 s), because
  that match never goes quiet again or reaches a last stand. It proves the chain end to end; it does not exercise
  every state. The unit tests cover the rest.
- The `MUSIC_TRACK` marker also prints during the music director's unit tests, which is a little noisy in the test
  log. Harmless (the smoke greps its own log), but worth tidying if anyone minds.

### Verified

**`make remote T=check` exited 0 on builder0 against the final tree (459331b), and again against 128c33b before
the housekeeping commits. Do not treat an older green run as evidence about a newer tree — two commits landed
between them.** Against the rebuilt booth (128c33b): 696 Godot tests, 0 failed;
`announcer-variance`, `announcer-record-smoke` and `music-smoke` all green with the sim hash unchanged at
`d7967d8b36d4417b`; `audio-check passed`.** The three failures that first run found were all tests describing the
*previous* contract rather than defects — a dead shooter being illegal, a `close_call` the regenerated fixtures no
longer all produce, and a flat twelve-line floor that was really asserting how long the fixtures happened to be.
When a contract changes, the tests that break are the old contract's documentation and want rewriting to state the
new rule, not bending until they pass.

**Earlier run (pre-rebuild), for the record:** `make remote T=check` exited 0 against `bc49a34` (the last commit; working tree clean, so the run
matches the commit exactly):
- **691 Godot tests, 0 failed** — 656 on `main` plus the 35 this stream added (7 announcer history, 12 MatchMood,
  10 music director, 6 sound mix).
- `announcer-variance passed` — the X1 ceilings are now a gate, not a claim.
- `announcer-record-smoke passed`, sim hash `d7967d8b36d4417b`, **matching the glibc-2.43 baseline**: the booth, the
  mood signal and the music read the match and never change it, which is the invariant audio must not break.
- `music-smoke passed: 2 bed changes across 2 beds` — a real headless match drove the soundtrack from the `lull`
  bed to the `battle` bed at 12.7 s, and the simulation hash did not move.
- `audio-check passed` — every bed's loudness, true peak, loop points and seam.
- The Python side: 43 tests (contract, generator, text audit, the pipeline against the mock client).

**Played like a player** (`make remote T=announcer-shots`, a scripted skirmish with subtitles on builder0's desktop;
frames in `build/screenshots/announcer_{desktop,phone}.png`, both looked at):
- The broadcast reads as a broadcast. Seed 2 opened on one of the new caller lines ("Listen to this crowd! They have
  been waiting for this one all season!"), the PA gave the control-point welcome, the Veteran came in after first
  contact ("Now everybody knows where everybody is. This is where it gets honest."), and the caller called the
  first kill, the matchup and the score. No repeats, nothing stale, nothing pasted-sounding.
- **Desktop (1920×1080):** the newest line renders in full with the typewriter cursor, older ones truncate with an
  ellipsis. Readable over the arena floor.
- **Phone aspect (1200×540):** the same, smaller; the newest line still wraps in full.
- **The one real problem, and it is not mine to fix:** the booth crowds gameplay out of the four-line message log.
  In the desktop frame three of the four visible lines are the caller; in the phone frame "Destroyed an enemy Tank
  (4 left)" is sandwiched between two of his. Round 3 asked control and feel for a separate subtitle line in the
  HUD; the screenshots are now evidence that it matters. Restated under *Requests to other streams*.

### What to playtest

- **The whole thing, as a player:**
  `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish --announcer=text --music=on`
  The booth's subtitles come through the HUD message log, the soundtrack follows the fight, and the battle is on a
  limited bus with distance filtering. `--announcer=voice` does nothing until X2's clips exist.
- `make announcer-variance` — the numbers above, and `HOT=20` for the most-said lines.
- `make announcer-transcript FIXTURE=close_match SEED=1` (any fixture, any seed): the PA's new openings. Run it
  twice with different seeds to hear the variance the lead asked for.
- `make music-check` — every bed's loudness, peak, loop points and seam. `make music-smoke` — the beds changing
  during a real match.
- `make music-placeholders` — regenerate the beds; then `make music-import IN=<a Suno file> STATE=battle BPM=110`.
- `make sfx` — regenerate every sound effect and its takes.

### Next steps

1. **When the `sk_` key lands:** the pilot (~250 characters), listen to it, tune `VOICE_SETTINGS` and the carrier
   sentences, then the full run (~28.5k credits), then `--announcer=voice` plays in skirmish. After that, ElevenLabs
   sound-effects generation layered under X4's transients.
2. **An options entry** for announcer and music volume. The flags exist; the settings UI is control's file, so it
   is a request to them rather than something I should edit (below).
3. **The stretch items, and why none of them are done.** I stopped at the end of the backlog rather than starting
   these, because the branch was green and ready to merge and reopening it would move the target. Honest status of
   each, so the next round can pick them up:
   - **Stems (layers that build with intensity).** *Unblocked* — the pipeline could be built against the
     placeholder beds today, and it is the one stretch item with no dependency. This is the one I would do first,
     and the only one I deliberately left rather than could not start. It needs the manifest to carry a layer list
     per bed and the director to cross-fade layers instead of whole tracks, which is a real change to
     `MusicDirector`, not an addition.
   - **An arena PA reading ad copy between rounds.** *Blocked on the lead* — the ad art and copy are lead gate 3 in
     HANDOFF and the placeholders shipped without copy. The PA's sponsor-read lines exist (`pa.sponsor.*`); what is
     missing is the copy to read and the screens to read it for.
   - **Per-faction announcer flavour.** *Mostly already there* and the remaining value is small: round 3 shipped
     faction introductions for all four factions and the director already tags moments `faction_<id>` and
     `other_faction_<id>`, so faction-specific lines are selected today. What does not exist is a per-faction
     *voice treatment* (the Syndicate's broadcast sounding different from the gangs'), which is an audio-processing
     job that wants X2's real clips first.

### Requests to other streams

- **control / feel** (the HUD message log): **subtitles need their own line.** The booth posts through
  `Hud.post_message`, so its lines compete with gameplay messages for the same four slots, and in a busy match the
  caller wins. `build/screenshots/announcer_{desktop,phone}.png` show it: three of four lines are his on the
  desktop, and a kill message is buried between two of his on the phone. A dedicated subtitle line (or a second,
  shorter log for the booth) fixes it; `hud.tscn` is feel's and the skirmish HUD layout is control's, so it is
  yours either way. Round 3 raised this; the frames now make the case.
- **control** (skirmish and the options screen): `--announcer=text|voice|off` and `--music=on|off` plus their volume
  flags are wired and default to off. A settings entry for each (announcer: text / voice / off with a volume; music:
  a volume) belongs in your options UI. Round 3 also asked for `--announcer=text` by default in skirmish; still
  worth doing.
- **feel**: the `World` audio bus you asked for in round 3 now exists and every world voice is on it, so the
  announcer's ducking works. `AnnouncerBooth.line_started` still carries the caller's text, team and intensity for
  the crowd swell. Nothing for you to change unless you want to route more sounds there.

### Merge notes (shared files)

- `mk/core.mk`: `audio-check` appended to `check`'s prerequisites (music contract checks, a few seconds).
- `mk/audio.mk`: new, mine.
- `mk/announcer.mk`: `announcer-variance` added to `announcer-check` (~90 s). **The orchestrator removed this line on
  `main`** because my mixdown commit carried the target without its CLI support and broke everyone's check. The CLI
  support is here (46bf0c0), so take my version of this file on merge and it comes back working.
- `game/main.gd`: the announcer's attach line now also attaches the music director, plus one header line for the
  `--music` flags.
- `export_presets.cfg`: `assets/announcer/*.json` and `assets/music/*.json` added to both presets' `include_filter`.
- `_agents/orientation.md`: trip-ups 67–70 added (make's own `WINDOW`; killing `make remote` leaves the remote build
  running; `.gitignore` slashes versus symlinks; `git add -A`).
- `.gitignore`: `.tools` added without a trailing slash, so the worktree toolchain symlink can never be committed
  again. One line; take it or the ai stream's equivalent, whichever merges first.
- **Before merging this branch:** `git ls-files .tools` must be empty (it is, as of e578923).

### Mistakes worth recording

Both have the same cause, and it is worth naming once: **`git add -A <paths>` commits things I had not looked at**,
and in both cases the file was visible in `git status` output I had decided was noise.

1. **A half-finished make target broke `main` for five streams.** Commit 5ccf56f staged `mk/announcer.mk` with
   `announcer-variance` already in `announcer-check`, while the CLI implementing it was still uncommitted. The
   orchestrator had to remove the line. *A make target that is part of `check` and the code it calls belong in the
   same commit.*
2. **A committed `.tools` symlink destroyed the laptop's Godot toolchain.** Commit 93e2f40 committed `.tools`, which
   in a worktree is a symlink to the main checkout's shared toolchain. `.gitignore` said `.tools/`, and a pattern
   ending in a slash never matches a symlink, so it was never ignored — `?? .tools` sat in every `git status` I ran
   for hours and I filtered it out each time. Merging the branch checked the symlink out over the real 300 MB
   directory, leaving it pointing at itself; every worktree on the laptop then failed with "Too many levels of
   symbolic links". The ai stream diagnosed it. Fixed here (e578923): untracked, and `.gitignore` now lists the
   slashless form too so no stream can repeat it. Repair for the main checkout is `make bootstrap`; builder0 keeps
   its own `.tools` and the green check there is unaffected.

Orientation trip-ups 69 and 70 record both.
