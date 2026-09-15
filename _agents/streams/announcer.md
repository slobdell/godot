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
- **Environment:** as of 2026-09-15, `ELEVENLABS_KEY_ID` (and `MESHY_API_KEY`) sit after the interactive guard in
  `~/.bashrc`, so agent shells can't see them (orientation trip-up 59). Move both above line 6 or into `~/.profile`.

## Status

- 2026-09-15: activated for round 3 (no API calls; transcripts for the lead's review). Nothing started.
