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
- **Color commentator:** not chosen yet. Cast by character first (see game_design.md), with a timbre clearly
  different from JR1 on phone speakers.
- **Arena PA / sponsor voice:** not chosen yet.

## Waiting on the lead

- The color commentator and PA voices (the caller `JR1` is ready, 2026-09-15).
- **Environment:** as of 2026-09-15, `ELEVENLABS_KEY_ID` (and `MESHY_API_KEY`) sit after the interactive guard in
  `~/.bashrc`, so agent shells can't see them (orientation trip-up 59). Move both above line 6 or into `~/.profile`.

## Status

- 2026-09-15: drafted as a round-3 candidate. Nothing started.
