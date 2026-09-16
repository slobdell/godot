# Stream: announcer (script engine and transcripts; the audio pipeline without API calls)

> **Active in round 3** (2026-09-15). Read [../orchestration.md](../orchestration.md) (the worker contract),
> [../game_design.md](../game_design.md) *The arena announcer* (voices, the banter graph, **humor direction**, recording
> tricks, the pipeline), and [../workstreams.md](../workstreams.md) (K5 is this brief's event contract; lead gate 2).
> Proposed ownership: `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `mk/announcer.mk`, `tests/announcer/`,
> and this brief.

## The lead's direction (2026-09-15)

> *"We'd want the announcer to make it feel like a sporting event … we can formulate massive dumps of audio data and
> then just randomly select some fitting phrases … some giant decision graph where many edges link to many nodes, and
> traversals are chosen at random … one of the agents should be able to build out this pipeline - it can technically
> be built in isolation outside of the game because the API boundary would be so strict. We'll want to simulate a fake
> game with whatever fixture data might eventually exist, and then I'd want to be able to hear these announcers in
> action. I will prepare some voices in Elevenlabs now."*

**Round 3 scope, from the lead:** *"setting up the audio ingestion pipeline for our announcers, but I actually think I'd
> prefer not to run the ingestion yet because I'll want to review what the generated text is for our potential
> conversations - with the earlier samples you gave me to play to Elevenlabs, the humor was far too overt and just not
> funny … we should be able to get the full program to formulate a synthesized announcers script based on fixture
> gameplay data that we sent (where the recorded data we pass doesn't necessarily need to exist yet)."*
>
> So: **no ElevenLabs API calls this round, not even a pilot.** Build and test the pipeline with a mock client and a
> dry run; deliver transcripts for the lead to read.

## Why this stream can run in isolation

The announcer only **listens to match events** and plays audio. It never reads or changes the simulation. So the whole
stream builds against a strict event contract and fixture data, with no dependency on the other streams' progress:

```
match events (JSON lines)  ─▶  Director (banter graph, memory, queue)  ─▶  playback cues  ─▶  audio + subtitles
   ▲ fixtures now,                pure GDScript, runs headless                 ▲ a mixdown file now,
   ▲ Match signals later                                                       ▲ the game's audio bus later
```

## The event contract (proposed C9; agree it with rules before wiring into Match)

One JSON object per line, ordered by tick:
`{"tick": int, "t": seconds, "type": string, ...fields}`.

| `type` | Fields | Source in the game later |
|---|---|---|
| `match_start` | `arena`, `teams: [{team, faction, units: [{id, unit}]}]`, `budget` | `Match` setup |
| `first_contact` | `team`, `unit`, `target_unit` | first shot fired |
| `damage` | `shooter`, `victim`, `unit`, `victim_unit`, `hull`, `shield`, `critical` | combat (rate-limited in the adapter) |
| `unit_destroyed` | `victim`, `victim_unit`, `victim_team`, `killer`, `killer_unit`, `killer_team`, `friendly` | `Match.tank_destroyed` |
| `friendly_fire` | `shooter`, `victim`, `hull`, `killed` | `Match.friendly_fire` |
| `close_call` | `unit`, `team`, `hull_left` | survives with little hull |
| `control_changed` | `owner` | `Match.control_changed` |
| `squad_wiped` | `team`, `squad` | squads |
| `momentum` | `team`, `army_health_ratio` (every few seconds) | derived |
| `match_end` | `winner`, `reason`, `duration_seconds`, per-team `units_left`, `kills_by_unit` | `Match.finished` (C3) |

Units are referred to by type (`scout`, `tank`, …) and team color, never player names. Keep the contract small;
the director derives streaks, comebacks, and callbacks itself.

## Backlog (in order)

**N0. The event contract and fixtures.**
- Write the contract as `tests/announcer/fixtures/README.md` plus a validator.
- **A fake-match generator** (seeded, `tools/announcer/fake_match.py` or GDScript) that produces plausible timelines:
  a close match, a blowout, a comeback, a friendly-fire disaster, a scout-heavy army against tanks, a control point
  swing. Check in a handful of generated fixtures.
- When the game can do it, add an adapter that records real events from the headless match runner (coordinate with rules).

**N1. The line library as text** (`assets/announcer/lines.json`), **written to the humor direction** (believable,
slightly off; authentic fight-night hype; no punchlines, no pun brand names; the rejected example lines below show what
to avoid): hundreds of tagged lines for two original voices
(caller and color) plus the arena PA, following game_design.md's tags (speaker, dialog act, event, intensity,
position and intonation, slots). A text audit tool like mavlink-hud's `audit_tts.py` (odd symbols, overlong lines,
missing tags, duplicates).

**N2. The director** (`game/announcer/`, pure GDScript, unit tested headless): beat templates, tag matching, slot
filling, match memory (momentum, streaks, callbacks, the match arc), priority queue with interrupts and cooldowns,
anti-repetition, and a seeded random generator of its own (never the simulation's). Output: timed cues
`{t, speaker, clip_id, text}`.

**N3. The transcript simulator** (`make announcer-transcript FIXTURE=…`, no credits): runs a fixture through the
director and writes a readable transcript with timestamps. **Lead gate:** the lead reads sample transcripts and
approves tone and coherence **before bulk audio generation** (list them under *Waiting on the lead*).

**N4. The audio pipeline, built but not run against the API** (`tools/announcer/`, `make announcer-generate`), modeled on the lead's
`~/projects/led-drone-microcontrollers/mavlink-hud/speech-to-text-elevenlabs` (ElevenLabs Python SDK, rules JSON →
MP3 masters, skip existing, print credits, ffmpeg → OGG):
- the key from the environment variable `ELEVENLABS_KEY_ID` (the lead's name for it); never write it to a file
- voices by the names the lead prepared in ElevenLabs (record the names and ids under *Voices* below)
- whole sentences sliced at word boundaries with character timestamps; previous/next text for intonation
- loudness normalization and silence trimming; a speech-to-text check of every clip
- mono Ogg Vorbis at a speech bitrate; a manifest with tags and durations; masters git-ignored
- a ledger (`assets/announcer/ledger.md`: date, clips, characters, credits)
- **No API calls this round.** Test everything against a mock ElevenLabs client (canned MP3s or silence with fake
  timestamps) so slicing, normalization, the speech-to-text check (mocked), encoding, and the manifest are proven.
  `make announcer-generate DRY_RUN=1` prints what would be sent: clip count, characters per voice, estimated credits.
  Real generation waits for the lead's approval of the text (lead gate 2).

**N5. Read it in action** (`make announcer-demo FIXTURE=…`): an HTML page with the match's event timeline and the
banter scrolling in sync (speaker, line, why the director chose it), so the lead can "watch" a match as text. Several
fixtures, several seeds each, so the lead sees the variety. The same page plays the mixed audio later, once clips exist
(ffmpeg mixdown built and tested with the mock clips).

**N6. In-game integration** (after round-2 integration, coordinating with command and art): an adapter from `Match`
signals to the event contract, playback on an announcer audio bus with ducking, subtitles through `Hud.post_message`,
cues to the crowd and the screens, web packs that load after start, and a volume or off setting.

- **Stretch:** sponsor reads and PA lines for the ad screens; faction introductions; a "tale of the tape" pre-match
  segment built from `match_start`.

## How to verify

Unit tests for tag matching, slot filling, cooldowns, interrupts, and determinism of the director for a given seed;
the text and audio audits; transcripts and a demo mixdown for every fixture, **listened to** (spot-check several clips
with speech-to-text output and durations, and describe what you hear in Status). `make check` stays green.

## Don't touch

The simulation and Match (rules; propose the event adapter), the HUD and crowd visuals (art), the in-match UI (command).
The announcer never affects gameplay.

## Voices

- **Caller (play-by-play): `JR1`** in the lead's ElevenLabs account (2026-09-15). The lead describes it as a parody of a
  famous podcaster. Keep the *character* original: no real name, catchphrases, or references in lines, and before
  shipping, the lead confirms the voice doesn't imitate a real person (ElevenLabs' policy; sound-alike voices in
  commercial products carry legal risk even as parody). Resolve the voice id by name, as mavlink-hud does.
- **Color commentator: "the Veteran"** (recommended 2026-09-15, voice not made yet). A former arena champion, an ex-convict
  who won his freedom: the expert with scars. Deep, slow, gravelly, dry humor; roasts bad tactics; "I survived that
  arena" callbacks. The classic pairing of a hype caller and an expert. **Casting notes:** if he's voiced as a Black man,
  he is the authority, never a hype-man foil for the caller; describe the voice by timbre and personality (e.g. "deep,
  gravelly baritone, slow deliberate delivery, dry humor, older, a former fighter"), never by race or dialect, and write
  his lines in his own voice, not exaggerated dialect.
- **Arena PA and sponsor reads: "the Corporate Co-host"** (placeholder name Celeste Vance): **`corporate2`** in the lead's ElevenLabs account (2026-09-15). A polished
  host the Syndicate assigned to the broadcast. A woman, for the most distinct timbre of the three voices. The
  third alternative considered: a stiff, monotone Law liaison (deadpan, booed by the crowd).

### The Corporate Co-host: Voice Design prompt and examples

**Voice description** (ElevenLabs Voice Design):

> A polished, warm-but-hollow corporate broadcast host, a woman in her mid-30s with a neutral American accent. Bright,
> crisp, perfectly enunciated delivery with a permanent smile you can hear. Medium pace, confident and upbeat, the
> tone of a luxury brand commercial or a morning show host. Underneath the cheer is something cold and rehearsed:
> every sentence sounds approved by legal. Clean studio-quality recording, close microphone, no background noise.

**Preview text:**

> Good evening, and welcome to tonight's match, brought to you by Syndicate Life Insurance. Because you won't make it.
> I'm Celeste Vance, and what a crowd we have tonight! Remember, folks: every casualty you see this evening is fully
> covered under our Platinum Afterlife plan. Now let's go down to the arena floor!

**Her comedy rule (revised by the lead, 2026-09-15):** she's a believable professional; something is *slightly off*,
never a joke. See game_design.md *Humor direction*. **The example lines below are the wrong tone** (the lead heard them
in ElevenLabs: *"far too overt and just not funny"*); they stay only as a record of what to avoid. A better direction,
for calibration: "Conditions on the floor are excellent tonight. Humidity is low, and the medical team has been told
not to intervene." (Ordinary broadcast cadence; one detail is wrong; no emphasis.) In the banter
graph she carries `sponsor_read`, `answer_disagree` (correcting the caller's language), and `filler`.

**Example lines (REJECTED tone, too overt; kept as what to avoid):**
- Match intro: "Tonight's Condemned have been given a generous opportunity to earn their freedom. Terms and conditions
  apply. Void where survived."
- Over carnage: "That dozer has just been reduced to scrap! And speaking of reductions, AquaCorp is lowering water
  rations by only eight percent this quarter. Hydration is a privilege!"
- Friendly fire: "Rust's artillery has just delivered a surprise team-building exercise. Syndicate HR reminds all
  combatants: accidents are a learning opportunity."
- Answering the caller: Caller: "Oh, he's dead! That scout is gone!" / Co-host: "*Retired*. We say retired. His organs
  are already trading on Organ Futures. Up four points!"
- The Law booed: "I'm hearing some enthusiastic feedback from the stands for our friends at the Law. The Syndicate
  values all public input. Your seat number has been recorded."
- Victory: "And Green takes the match! A thrilling demonstration of our Series Nine railgun, available now to qualified
  governments. Pre-orders ship before the next uprising."

## Waiting on the lead

- The Veteran's voice (ready: the caller `JR1` and the Corporate Co-host `corporate2`, 2026-09-15).
- **Environment:** `ELEVENLABS_KEY_ID` and `MESHY_API_KEY` are exported before the interactive guard in `~/.bashrc`
  (fixed 2026-09-15), so agent shells see them. No ElevenLabs calls this round regardless.

## Status

_Updated 2026-09-15 by the announcer worker._

**Report (2026-09-15): N0–N6 and all three stretch items are done; N3's approval and N4's real generation wait on
the lead (lead gate 2). No ElevenLabs request was made. `make check` passes on builder0.**

### Plan (in order; smallest foundation first; all done)

1. **N0** contract README + two validators (Python, GDScript) that agree on shared broken cases; seeded fake-match
   generator with six scenario shapes; fixtures checked in; `make announcer-check` in `make check`.
2. **N2 skeleton before N1 bulk:** the library schema and loader, tag matching, slot filling, and a first ~60 lines, so
   the director is testable; then **N1** grows the library to hundreds of lines plus the text audit.
3. **N2** the director: moments derived from events, beat templates, memory, priority queue with interrupts,
   cooldowns, anti-repetition, own seeded RNG; cues `{t, speaker, clip_id, text, reason}`.
4. **N3** `make announcer-transcript FIXTURE=…` → readable transcripts for every fixture (lead gate).
5. **N5** the HTML demo page (timeline + banter in sync, several seeds per fixture).
6. **N4** the audio pipeline against a mock ElevenLabs client (slicing, loudnorm, trim, STT check, Ogg, manifest,
   ledger, `DRY_RUN=1` credit estimate), then the mixdown for the demo page.
7. **N6** in-game adapter (Match signals → K5), playback bus with ducking, subtitles; stays within announcer paths.
8. Stretch: sponsor reads for the ad screens, faction introductions, tale of the tape.

### Waiting on the lead: read the booth (lead gate 2)

**The text is ready for review; no audio has been generated.** Two ways to read it:
- **The Arena Booth Monitor** (private page): https://claude.ai/artifact/FCkbZb1uyg4fjcBfEpRttw. Pick a match and a
  director seed, press Play (4× by default), and the floor's events and the booth's lines scroll in sync; "Why" shows
  what the director noticed; seed 1 of each match plays mock audio (tone bursts where words go) to show timing. Rebuild
  locally: `make announcer-demo` (text) or `make announcer-demo-audio` (with the mock mixdowns).
- **Plain transcripts** in `assets/announcer/transcripts/` (8 fixtures × seeds 1–2), and `make announcer-transcript
  FIXTURE=comeback SEED=3` for more. The full library: `assets/announcer/lines.json` (429 lines).

Questions for the lead with the review:
1. **Tone:** is the PA (Celeste Vance) subtle enough? Lines to judge her by: `pa.welcome.03` ("the medical team has been
   asked not to intervene"), `pa.notice.04` ("will be considered a participant"), `pa.result.02` ("The surviving crews
   will be processed shortly"). Is the caller's hype authentic, not jokey? Is the Veteran's dark past (`color.lore.*`)
   the right amount?
2. **Cost:** `make announcer-generate` (dry run) estimates **28,524 characters ≈ 28,500 credits** on
   eleven_multilingual_v2 for all 701 clips (caller 12.5k, Veteran 9.3k, PA 6.7k; 19.3k for the two voices that exist
   today), plus ~32 minutes of speech-to-text.
   Flash v2.5 would halve it; quality first per your standing direction, so v2 is the default.
3. **Factions** (stretch): each faction has introductions, and the Law is booed; the Syndicate's kills get a product
   read ("The Syndicate congratulates its engineering team on another successful field test."). Read
   `gangs_vs_law_seed*.txt` and `syndicate_showcase_seed*.txt`. Right direction?
4. **The Veteran's voice** still needs making in ElevenLabs (casting notes under *Voices*); his lines are skipped until a
   voice with the name set in `lines.json` → `speakers.color.voice` exists.
5. After approval: `pip install -r tools/announcer/requirements.txt`, then `make announcer-generate APPROVED=1` (it
   resolves voices by name, skips what's recorded, prints credits, logs `assets/announcer/ledger.md`). Suggest a pilot
   first: `make announcer-generate APPROVED=1 ONLY=caller.kill.13,caller.kill.52,pa.welcome.03` (~250 characters) to
   hear stitching before the bulk run.

### Decisions

- **Fixture ids vs types got distinct field names** (`unit_id`/`shooter`/`victim` hold instance ids; `unit`/`*_unit` hold
  types) so no field means two things; `friendly_fire` gained unit types and team; `momentum` carries both teams.
  Recorded in `tests/announcer/fixtures/README.md` (K5).
- **Generator in Python** (`tools/announcer/fake_match.py`): an abstract duel model, not the game's sim, so fixtures
  don't churn with combat's round-3 rebalance. Each scenario has a predicate; the generator walks seeds upward to the
  first match that fits, so `--seed 1` always writes the same file (a test enforces fixtures == generator output).
- **Python tests live beside the tools** (`tools/announcer/test_*.py`, the assets stream's precedent), GDScript tests
  in `tests/announcer/`.
- **Tags, not edges:** a line fits a moment when all its tags are on the moment; each extra matched tag multiplies its
  chance by 8, and a beat can `require` its key tag (a first-blood beat always says "first blood"). Format:
  `assets/announcer/README.md`.
- **Friendly and hazard kills are their own moment kinds**, so a generic "{team} takes out the {victim_unit}!" can
  never be said about a team killing itself.
- **The booth doesn't talk over live action:** follow-ups by the Veteran and the PA are skipped within 1.5 s of a shot;
  a kill cuts off a follow-up (soft priority) but not another call; kills that pile up merge into one "flurry" or
  "trade" call; the result clears everything but the final kill. These came from reading transcripts: the first
  version narrated stale kills 4 s late and cut the Veteran off after one word three times a match.
- **What the audience heard, not what happened:** the director sets `said_<kind>_<team>`, so "again!" only follows a
  first friendly-fire call the audience actually heard; an upset is called once per matchup; a close call is dropped if
  that unit has died since.
- **Stitching:** whole sentences with character timestamps, sliced at word boundaries; slots are separate filler clips
  recorded in carrier sentences per intonation (mid, final, rising); punctuation after a slot stays with the slot
  (the mock's speech-to-text check caught a sliver of the filler word in the next segment); loudness is normalized on
  the whole master, then sliced (normalizing 0.2 s fillers alone made them 10 dB hotter than sentences).
- **Voice settings** default to stability 0.45 / similarity 0.8 / style 0.35 (commentary needs more life than the
  reference's alert voice at stability 1.0); tune after the pilot.
- **Timing uses recorded durations when they exist** (`--manifest`): with the mock, estimated per-word timing made
  lines overlap the next cue in 6 of 22 cues; with manifest durations, 0 overlaps.

### Done

- **N0 (2026-09-15):** contract, validators (`tools/announcer/events.py`, `game/announcer/announcer_events.gd`), shared
  broken cases (`tests/announcer/contract_cases.json`, 18 cases both reject), generator, six fixtures (54–141 s
  matches, 36–83 events each; one hazard kill, 3+ friendly-fire hits, a control-point win), `make announcer-fixtures`,
  `announcer-validate`, `announcer-pytest`, `announcer-check`.
- **N1:** `assets/announcer/lines.json`, 393 lines / 4,303 words (caller 224, Veteran 125, PA 44) across 17 moment
  kinds, plus `beats.json` (the grammar). `tools/announcer/audit_lines.py` (`make announcer-audit`): structure,
  unknown acts/slots, "a {unit}" articles, digits and symbols, duplicates, dangling flags, unanswered questions, beats
  without lines; warnings for the rejected tone's phrases and borrowed catchphrases. Clean (2 near-duplicate warnings).
- **N2:** `AnnouncerLibrary`, `AnnouncerMemory`, `AnnouncerDirector` (pure GDScript, headless): 12 unit tests (tag
  matching, slots, flags, memory tags, cooldowns, interrupts and staleness, kill merging, answers on topic, recorded
  durations, determinism and the global RNG untouched) + every fixture × 3 seeds reads as a broadcast (intro first,
  result and sign-off last, no repeats, no overlaps, no unfilled slots). Mutation-checked: without merging or
  interrupts, their tests fail.
- **N3:** `make announcer-transcript`, `make announcer-transcripts` (12 review transcripts, checked in);
  `announcer-check` fails when they're stale. 18–31 lines per match, 1–4 cut lines each.
- **N5:** the Arena Booth Monitor (`make announcer-demo`, published above): 18 matches, 354 KB, plays mixdowns in sync.
- **N4:** `tools/announcer/{recording_plan,voice_client,generate,mixdown}.py`; 12 pipeline tests against the mock
  (plan rebuilds every line, fillers cover every slot value, dry run sends nothing, key only from the environment,
  masters idempotent, mono Vorbis, fillers within 3 dB of sentences, mishearing and bad slices flagged, missing voices
  skipped, ledger only for paid runs, mixdown places fillers and cuts). SDK calls checked against elevenlabs 2.24.0
  installed in a scratch venv (no key, no requests). **Measured on the mock mixdowns** (no voices exist to listen to):
  in comeback and control swing, every line's sound starts at its cue except back-to-back lines, silence begins within
  0.35 s of every line's end (26/26), 0 overlaps; clip levels −13.2 to −14.9 dB mean. Real listening waits for the pilot.
- **N6:** `MatchEventAdapter` (Match signals, `Tank.fired`, and health reads → K5; listens only), `AnnouncerBooth`
  (adapter → director → `Hud.post_message` subtitles and `line_started`), `AnnouncerVoice` (manifest clips on an
  `Announcer` bus; cut lines fade; a `World` bus gets a sidechain compressor keyed on the announcer when it exists;
  clips load from files so voice packs can arrive after start). Flags `--announcer=text|voice|off`,
  `--announcer-volume`, `--announcer-clips`, `--announcer-seed`, `--announcer-record=PATH`. 3 tests (a live Match
  becomes a valid K5 timeline with kills, a teamkill, a hazard, first contact, a squad wipe, and the end; the booth
  calls a live match; the voice picks filler clips, refuses half-recorded lines, ducks the world bus).
  **`make announcer-record-smoke`** (in `announcer-check`): the sim-baseline match with the recorder attached keeps its
  hash (builder0 `c9cfbb1a221f5c94`, laptop `772dfb5198e15909`), records 28 valid events, and gets a transcript.
  **Played like a player:** a scripted skirmish with `--announcer=text` (screenshot `build/screenshots/announcer_desktop.png`,
  laptop window, 30 s): the caller, PA, and Veteran lines appear in the HUD message log with the typewriter effect,
  readable at 1920×1080; they push gameplay messages out of the four-line log (request to control and feel below).
- **Stretch (all three):** faction introductions (caller, PA, Veteran for the Condemned, road gangs, the Law, the
  Syndicate; the Law is booed; Syndicate kills get a product read), a tale-of-the-tape moment, and ad-screen PA lines
  (the Law's report-your-neighbor, AquaCorp's water schedule, betting odds). Library 429 lines / 4,797 words. Fixtures
  `gangs_vs_law` and `syndicate_showcase`; 16 review transcripts.
- **Quiet stand-offs:** the builder0 skirmish run showed the Veteran telling stories back to back through a long lull;
  banter now backs off (each lull in a row waits longer, up to 4×): 9–10 beats in five quiet minutes instead of 16–19.

### Requests to other streams

- **control** (skirmish mode): turn the booth on for players: `--announcer=text` by default in skirmish (or an
  options toggle: text / voice / off, and a volume), wiring `AnnouncerBooth.attach` already runs from `game/main.gd`.
  Subtitles arrive through `Hud.post_message` as `CALLER: …`; if they crowd gameplay messages, a separate subtitle line
  in the HUD would be better (feel owns `hud.tscn`).
- **feel** (audio): route world sound effects through an audio bus named `World`; the announcer then ducks it
  automatically (a sidechain compressor keyed on the `Announcer` bus). Crowd: connect `AnnouncerBooth.line_started`
  and swell on `intensity == 3`.
- **assets** (ad screens): `line_started` carries the caller's text and the team for the screens' live ticker.
- **combat** (K2): when `Match.projectile_impact` lands, the adapter should take `shooter`, `weak_spot`, and `face` from
  it instead of inferring damage from hull changes (a small change in `game/announcer/match_event_adapter.gd`, mine).
- **orchestrator**: record K5 as final in workstreams.md (the field names changed from the first draft; see Decisions),
  and export `assets/announcer/*.json` (+ clips later) in `export_presets.cfg` `include_filter` when the booth ships
  in the web build (not done: shared file, and nothing plays it by default yet).

### Known issues

- ~~`army-loop-smoke` flaked twice on builder0~~ ("Invalid polygon data, triangulation failed"): **fixed on main**
  (8dbe23e: far-zoom command icons off screen failed triangulation on precision), merged here.
- ~~A command_icons test from that fix failed on 4.7.2~~ (collinear polygons still triangulate): fixed on main as
  13685ce (a zero-area guard), merged here. **Full `make check` passes on builder0 after the merge: 433 tests,
  every smoke, announcer-check.**
- Mock durations are longer than the per-word estimate; real ElevenLabs pacing will differ again, which is why the
  director reads the manifest.
- ~~Rendering on builder0 hangs~~ **fixed on main** (7dc7bdc, a stale Xwayland auth file; merged here): after the merge,
  `make remote T=announcer-shots` rendered `build/screenshots/announcer_{desktop,phone}.png` on builder0. At phone
  aspect (1200×540) the newest subtitle wraps in full and older ones truncate with an ellipsis; readable.
- Inferred damage credits the victim's nearest enemy until K2's `projectile_impact` exists (occasionally the wrong
  shooter type in a big-hit call).
- Director seeds in live matches are random per match (presentation only); `--announcer-seed` pins one.

### What to playtest

- `make announcer-transcript FIXTURE=gangs_vs_law SEED=3` (any fixture, any seed) and the Booth Monitor link above.
- `make skirmish` with subtitles: `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish --announcer=text`.
- `make announcer-generate` (dry run; nothing is sent). After text approval: the pilot command under *Waiting on the lead*.

### Next steps (after the lead's review)

1. Apply tone notes to `lines.json` (the audit and the transcript check keep it honest), then the pilot generation.
2. Listen to the pilot: stitching at slot boundaries, filler intonation, loudness; tune `VOICE_SETTINGS` and carriers.
3. Bulk generation; commit `assets/announcer/clips/` (mono Vorbis, ~40 kbps: ~701 clips × ~2 s ≈ 7 MB) with the manifest;
   `--announcer=voice` then plays in skirmish; web packs load the clips after start.
4. Swap inferred damage for K2 `projectile_impact` once combat merges.

### Merge notes (shared files)

- `mk/core.mk`: `announcer-check` appended to `check`'s prerequisites (it includes `announcer-record-smoke`, ~15 s).
- `game/main.gd`: `AnnouncerBooth.attach(self)` after `mode.start()` (returns at once unless an `--announcer*` flag is
  given), plus one header line documenting the flags.
