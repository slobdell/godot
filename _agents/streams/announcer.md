# Stream: announcer (a round-3 candidate; not active yet)

> Drafted 2026-09-15 so a future agent can start from a one-line kickoff. Read
> [../game_design.md](../game_design.md) *The arena announcer* (the design: voices, the banter graph, recording tricks,
> the pipeline) first, then [../workstreams.md](../workstreams.md) for the autonomous and unattended rules.
> Proposed ownership: `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `mk/announcer.mk`, `tests/announcer/`,
> and this brief.

## The lead's direction (2026-09-15)

> *"We'd want the announcer to make it feel like a sporting event … we can formulate massive dumps of audio data and
> then just randomly select some fitting phrases … some giant decision graph where many edges link to many nodes, and
> traversals are chosen at random … one of the agents should be able to build out this pipeline - it can technically
> be built in isolation outside of the game because the API boundary would be so strict. We'll want to simulate a fake
> game with whatever fixture data might eventually exist, and then I'd want to be able to hear these announcers in
> action. I will prepare some voices in Elevenlabs now."*

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

**N1. The line library as text** (`assets/announcer/lines.json`): hundreds of tagged lines for two original voices
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

**N4. The audio pipeline** (`tools/announcer/`, `make announcer-generate`), modeled on the lead's
`~/projects/led-drone-microcontrollers/mavlink-hud/speech-to-text-elevenlabs` (ElevenLabs Python SDK, rules JSON →
MP3 masters, skip existing, print credits, ffmpeg → OGG):
- the key from the environment variable `ELEVENLABS_KEY_ID` (the lead's name for it); never write it to a file
- voices by the names the lead prepared in ElevenLabs (record the names and ids under *Voices* below)
- whole sentences sliced at word boundaries with character timestamps; previous/next text for intonation
- loudness normalization and silence trimming; a speech-to-text check of every clip
- mono Ogg Vorbis at a speech bitrate; a manifest with tags and durations; masters git-ignored
- a ledger (`assets/announcer/ledger.md`: date, clips, characters, credits)
- **Pilot first:** a small batch (~30 clips per voice, enough for one demo match) is fine before the transcript gate,
  so the lead can hear the voices. Bulk generation waits for approval.

**N5. Hear it in action** (`make announcer-demo FIXTURE=…`): renders a fixture's cues into a single mixed audio file
(`build/announcer/<fixture>.ogg`, with ffmpeg: clips placed at their cue times, ducking, an optional crowd bed) and a
transcript synced to it, then opens an HTML player page that highlights the current line and marks the match events on
a timeline. This is the lead's playtest for the announcer.

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
- **Arena PA and sponsor reads: "the Corporate Co-host"** (placeholder name Celeste Vance; voice not made yet). A polished
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

**Her comedy rule:** cheerful corporate euphemism over horror, delivered sincerely, never as a joke. In the banter
graph she carries `sponsor_read`, `answer_disagree` (correcting the caller's language), and `filler`.

**Example lines** (tone references for the line library; fictional brands only):
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

- The Veteran and Corporate Co-host voices (the caller `JR1` is ready, 2026-09-15; the co-host's Voice Design prompt is above).
- **Environment:** as of 2026-09-15, `ELEVENLABS_KEY_ID` (and `MESHY_API_KEY`) sit after the interactive guard in
  `~/.bashrc`, so agent shells can't see them (orientation trip-up 59). Move both above line 6 or into `~/.profile`.

## Status

- 2026-09-15: drafted as a round-3 candidate. Nothing started.
