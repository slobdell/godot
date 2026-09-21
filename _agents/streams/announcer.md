# Stream: announcer (more lines on the same themes, generated this round)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*, *Lead gates*),
> [game_design.md](../game_design.md) (*Round 10 direction* §7, *The arena announcer* including the humour direction of
> 2026-09-15), [workstreams.md](../workstreams.md) (*Round 10: the eight streams*, contract **R8**), the round-3 brief
> [archive/round3/announcer.md](archive/round3/announcer.md) (the voices, the casting, the pipeline as built) and
> `assets/announcer/README.md` (the line format).
>
> **You own** `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `tests/announcer/`, `mk/announcer.mk`, and
> the `announcer-*` and `audio-launch-smoke` targets in `mk/audio.mk` (carved out of feel for the round). You run in
> total isolation: fixtures in `tests/announcer/fixtures`, the director headless, no Godot beyond `announcer-check`.
> **Money:** ElevenLabs only, key from `ELEVENLABS_KEY_ID` in the environment (never a file in the repo); every run in
> `assets/announcer/ledger.md`. No Meshy, no new accounts.

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> We can definitely expand the set of things announcers can say (try to generate more stuff on the same theme to
> create more selection - let's burn through some ElevenLabs credits).

The standing humour direction (2026-09-15, his words after hearing the first samples): *"the humor was far too overt
and just not funny. What makes satire funny is things blur the line between believable and non-believable; in the
humor with our professional reporter the listener should just get the sense that something's slightly off with what
she said. For the JR announcer, it would be easy enough to formulate a lot of stereotypical reactions to the sporting
event, and of course we can draw inspiration from the UFC announcers and how excited they are getting into it."*
The three voices: the caller (authentic fight-night hype, played straight; the comedy is that he is this excited about
armoured buses), the Veteran (dry, expert, understated), the Corporate Co-host / PA (a polished broadcaster; the
dystopia leaks through one slightly wrong detail with zero emphasis; **no jokes, no punchlines, no winks, no pun brand
names; if a line reads as a joke, cut it**). Dark and understated; mild language only; team names by colour.

**R8 (orchestrator, on his words): generation is authorised this round.** Lead gate 1's text approval is satisfied by
that direction plus `make announcer-audit` plus the review page; you generate in batches without waiting. The balance
was ~109 k credits at launch (`ledger.md`'s last row: 110 920 → 109 290). Target: the thin moments deepened to real
pools, roughly 400–600 new lines (~30–50 k credits at ~75 characters a line). **Stop at half the remaining balance
(~55 k) and ask the orchestrator** unless he says otherwise. A line he vetoes on the page is dropped or regenerated.

## Where things stand

- **601 lines in `assets/announcer/lines.json`** (schema, speakers, vocabulary, lines with `id, speaker, act, tags,
  sets, unless_flags, intensity, text`); the moment grammar in `beats.json` (moments: intro, army, tape, preview,
  contact, big_hit, kill, friendly_kill, hazard_kill, friendly_fire, close_call, control, squad_wiped, momentum, lull,
  result, outro, formation, drill; `tag_priority`, `tag_intensity`). Runtime selection: `announcer_director.gd` picks a
  moment, a beat (`_choose_beat`, weight `pow(4, len(when))`), then a line via `AnnouncerLibrary.candidates()` with
  `SPECIFIC_WEIGHT = 8.0 ^ specificity`, an intensity bonus and `AnnouncerHistory.weight()` for cross-match
  anti-repetition. **Selection variety is bounded by pool size per (speaker, moment, tags).**
- **The pools, by id prefix (2026-09-20, main `de31eeea`):** deep: `caller.kill` 76, `caller.intro` 29, `pa.welcome` 30,
  `color.banter` 25, `color.kill` 21, `caller.result` 18. **Thin (≤ 7):** `caller.control` 7, `caller.ff` 7, `caller.close`
  6, `caller.interrupt` 6, `caller.ownkill` 6, `caller.reaction` 6, `caller.stat` 6, `caller.faction` 5, `caller.waiting`
  5, `caller.hazard` 4, `caller.preview` 4, `caller.momentum` 3, `caller.squad` 3, `caller.formation` 3, `caller.tape` 3,
  `caller.drill` 2 (+2 ambush); `color.contact` 5, `color.hit` 3, `color.close` 3, `color.control` 3, `color.tape` 3,
  `color.waiting` 3, `color.momentum` 4, `color.ff` 6, `color.faction` 6, `color.ownkill` 6, the `color.technique.*` and
  `color.teach.*` singletons; `pa.control` 2, `pa.hazard` 2, `pa.odds` 2, `pa.syndicate` 3, `pa.faction` 4, `pa.ff` 4,
  `pa.signoff` 4. Recount with the script in Status before you start; the numbers above are the orchestrator's.
- **The pipeline:** `make announcer-generate` (dry-run by default: prints requests and credits; `APPROVED=1` calls
  ElevenLabs, model `eleven_multilingual_v2`, idempotent by clip id), `tools/announcer/{generate.py,voice_client.py,
  mixdown.py}` (masters → sliced, loudness-normalised, trimmed, speech-to-text verified, Ogg at a speech bitrate,
  `clips/manifest.json`), `audit_lines.py` (symbols, slots, tags, duplicates, rejected tone), `check_variance.py`,
  `recording_plan.py`, `announcer-transcripts` (the checked-in review transcripts per fixture and seed; the
  `transcripts-check` in `make check` fails when the director's output moves, so re-record them with the reason),
  `announcer-demo` (the Booth Monitor page; `announcer-demo-audio CLIPS=assets/announcer/clips` for the real voices).
- **Voices** are the round-3 designs (`caller`, `color`, `pa` voice ids in the client config); do not redesign them.
  Recording tricks that were verified in round 3 (whole sentences, slicing at word boundaries, request stitching,
  `loudnorm`, STT verification) are in the pipeline; read the round-3 Status before touching it.

## Backlog (in order)

1. **The recount and the plan.** A script (`tools/announcer/pool_report.py` or a flag on `audit_lines.py`) that prints
   lines per (speaker, moment, tag set) and the director's selection pool size per moment on the fixtures, so "thin"
   is a number the page shows; the target per pool written down (every caller and colour moment ≥ 12; every PA
   moment ≥ 8; the deep pools +25 %).
2. **Write the lines, on the same themes.** For each thin pool, new lines in the SAME voice and act as the existing
   ones (read the pool first; vary the reaction, not the character), slots (`{team}`, `{unit}`, `{faction}`, `{arena}`,
   `{count}`) used the way the pool uses them, `sets`/`unless_flags` for memory where the pool has them, intensity
   spread across 1–3. Run `announcer-audit` after every batch; anything the audit flags is cut, not argued. The PA's
   lines are the hardest and the most valuable: one wrong detail, flat delivery, no wink.
3. **The review page.** `announcer-demo` extended with a "new this round" tab: every new line with its id, speaker,
   moment, and (once generated) its clip; the transcripts re-cut with the new pool so he can read three matches.
   Sent to the orchestrator for him; his veto is a line id.
4. **Generate, in batches, as pools are written** (`APPROVED=1 make announcer-generate`, ~100–150 lines a batch),
   speech-to-text verify (a clip whose STT does not match its text is regenerated once, then cut), mixdown, manifest;
   the ledger row with balance before and after and a note naming the batch. Never a batch without the audit green;
   never past half the remaining balance without asking.
5. **Runtime checks:** `check_variance.py` across seeds with the new pool (the repetition rate falls; the per-moment
   repeat within a match reaches zero where the pool is ≥ 12); `announcer-transcripts` re-recorded with the reason;
   `audio-launch-smoke` on builder0 (a flagless launch has the voice); `announcer-record-smoke`.
6. **Stretch:** callbacks that use the new memory flags (the Veteran's "told you" lines) where a pool gained them;
   the `{arena}` lines for the Terminus (the newer arenas got theirs in round 4: check which arena names have clips);
   a second pass on the deep pools for lines that repeat a beat.

## How to verify

- `make announcer-check` (validate, pytest, audit, variance, transcripts-check, record-smoke) and the full
  `make check` green (`make remote T=check`), at the hash you name.
- `make announcer-transcript FIXTURE=comeback SEED=1` and read it as a listener; `make announcer-demo-audio
  CLIPS=assets/announcer/clips` and listen to ten clips per voice; STT mismatch rate in Status.
- `make skirmish` with the announcer on, one match, on the laptop: does the booth repeat itself?
- Every paid run: the ledger row; every count: the commit.

## Don't touch

`game/theme/**` (feel's), `game/audio/` and `assets/{audio,music}/` (feel's: the music and mix are not yours), the
simulation, `game/ui/` (control's: the subtitle path is `Hud.post_message`, consume it). `mk/audio.mk` beyond the
announcer targets.

## Waiting on the lead

His veto on the review page (never blocks: generation proceeds under R8); the "stop at half" line if the pools want
more than ~55 k credits.

## Status

_(the worker keeps this current; the ledger and the pool report are the numbers he reads)_
