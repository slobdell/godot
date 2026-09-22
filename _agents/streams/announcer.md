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

## Research addendum (brief 2, 2026-09-20 evening; row B11)

**Selection scoring (cheap, do it with item 5):** a recency-decay penalty per clip, Σ exp(−Δt/τ) over its firings
plus a lifetime count, replacing or joining the LRU + cooldown; the falsifier is the repeat-within-three-minutes rate
on the fixtures falling to zero for pools ≥ 12 (listeners notice a repeat inside about three minutes and not hours
apart).

**Authoring framework for the PA and the Veteran (item 2):** bureaucratic banality (a catastrophe as a maintenance
deviation), technical detachment (an accurate observation that downplays the crisis), understated inconvenience;
never for the caller, who is hype. Examples in the reply's §8; the audit rejects anything that reads as a joke.

**Stretch:** clause assembly (prefix × subject × action × clause with matched pitch and tempo) for the Veteran only;
the pipeline slices whole sentences by design and this would be a second recording mode, priced before it is tried.

## Research addendum 2 (brief 3, 2026-09-20 late; rows C9, C10)

**Pool size is a formula per moment (C9), not "≥ 12".** `N_c = ⌈λ·τ⌉ + ⌈λ·T_eff / −ln(1 − R)⌉`: λ the moment's
trigger rate per minute (measure it from the fixtures and a real match), τ the cooldown, T_eff the ROLE's memory
horizon, R the target repeat-perception rate (0.05). The roles differ by an order of magnitude: the caller's hype
lines fade in 90–180 s; the Veteran's analytical lines are recognised across 5–10 min; **the PA's one-wrong-detail
lines are remembered across sessions** (the isolation effect): one hearing, and a repeat is a jarring 100 % hit. Their
table, as a shape only: a moment firing twice a minute wants ~22 caller lines (with 3 takes each), ~58 Veteran, ~135
PA; at 0.5/min 9/21/42; rare 4/7/12. Item 1's pool report prints λ, N_c and the current count per (speaker, moment)
and the generation plan targets the deficit, biggest first. Cross-match memory (`AnnouncerHistory`) must give the PA's
lines a horizon of days, not one match.

**Takes (C10): the cheapest good use of the credits he authorised is the CALLER at 3 takes per line** (pitch peak
±3.5 semitones, rate ±18 %, different onset), an effective pool ×1.8–2.4; the Veteran gains little (×1.15) and gets
paraphrase instead; **the PA gets exactly ONE take per wrong detail** (a second take is a repeat, and emphasis on the
detail breaks the register). Check `voice_client.py` for the per-request voice settings (stability/style) that move
pitch and rate; STT-verify every take.

**Authoring gates for the PA, in `audit_lines.py` (C10):** exactly one anomalous span of 1–6 tokens; mid-sentence,
followed by ≥ 4 mundane tokens (clause-final is a punchline's position and is rejected); the carrier in flat
informational register (no exclamations, no affect words); no two lines with the same CATEGORY of wrong detail
(keep a small category list in the JSON). **Diversity audits without listeners:** Distinct-n / self-BLEU over each
pool (surface templates), and the compression ratio of a simulated 12-minute transcript (rises with real variety);
both cheap in Python now; an embedding-based effective-line count (the Vendi score) later if a model is at hand.

**Confirmed by the reply:** whole-sentence recording is right (spliced sub-sentence audio breaks the pitch
declination and reads as robotic); clause assembly stays a stretch; the "narrow context funnel" (a specific tag
conjunction with 3 lines firing 4× a match) is the failure the pool report exists to catch.

## Status

_(the worker keeps this current; the ledger and the pool report are the numbers he reads)_

**Updated 2026-09-22 (worker, round 10). Every backlog item is done; the round's report is below.** Baseline:
`make remote T=check` on `2ee65f94` (builder0): `>> remote: make check exited 0`, 1559 passed, 0 failed.
**Green commit for the merge: see "Merge notes" (the final check's hash).**

### Done

1. **The recount and the plan** (`bf9fdb43`). `make announcer-pool-report` replays every fixture for seeds 1-5 (40
   broadcasts, 51.9 match minutes) and prints per (speaker, moment): library lines and how many are `new` this round,
   λ/min, the director's pool **at the pick** (the director records `pool`, `fresh` and `effective` = exp entropy of
   the pick's weights on every cue), starved picks, C9's `N_c`, the target, the deficit and Distinct-2; then the narrow
   funnels (a tag set firing often from few lines). Knobs, decided and written in the script: R = 0.05; horizons caller
   2 min / Veteran 7.5 / PA 30; floors 12/12/8; deep pools (>= 18) +25 % measured against the pool **as the round found
   it**; caps 40/40/**16 for the PA**. A moment the fixtures never reach gets only its floor. The deficit is against the
   smaller of the library count and the mean pool at the pick, because `caller.army` has 16 lines and offers 2.
   **Deficit: 514 -> 147** (the table below; both measured under the final rules).
2. **The lines** (`96333be1`, `69057d84`, `dc95c555`). **518 new lines** (`"added": "r10"`): caller 205, Veteran 196
   (183 + 13 stretch), PA 117, mostly slot-free, since a `{faction}` line is 4 recordings and a `{unit}` line 6.
   `caller.preview` was skipped on purpose (0 firings in 64 broadcasts) and `tape` got 5.
   **The PA's C10 gates are in `audit_lines.py`**: a new PA line names its one wrong detail (`oddity: {span,
   category}`), 1-6 words, at least 4 ordinary words after it (clause-final is a punchline's position), no `!`, no
   affect word, and no two lines of the same kind of wrong detail in one moment's pool (33 categories in
   `lines.json`). Audit: **1119 lines, 0 errors** (the 1 warning predates the round).
3. **The review page** (`96333be1`). `make announcer-demo` -> `build/announcer/demo/index.html#new`: every new line by
   moment, **518 of 518 with a Play button**, a veto tick per line collecting ids to send back, an optional marker for
   the PA's wrong detail, and a `new` badge on the match rows. Looked at, desktop 1400x1100 and phone 420x900.
4. **Generation** (`69057d84`, `dc95c555`). Five runs, every one a ledger row:
   | batch | requests | characters | credits |
   |---|---|---|---|
   | pilot (`pa.hit.01`) | 1 | 138 | 108,348 -> 108,348 (unsettled) |
   | 1: the PA | 116 | 15,253 | 108,348 -> 93,575 |
   | 2: the Veteran | 183 | 13,248 | 92,572 -> 80,143 |
   | 3: the caller + the stretch pairs | 236 | 11,755 | 78,952 -> 67,002 |
   | 3b + reword: 5 speech-to-text re-records | 5 | 205 | 67,002 -> 66,710 |
   | 4: the plural-faction fix, 14 older lines | 80 | 4,009 | 66,710 -> 63,894 |
   **Balance 63,894, well above the ~54,000 stop line, so nothing needed asking.** Speech-to-text: **0 mismatches
   left**; 4 of 523 new clips were flagged, 3 passed the one re-record the brief allows, and the fourth was the
   recogniser splitting "downrange", so `caller.contact.15` is now "First rounds are away!". `generate.py` gained
   `--max-characters` (a batch cannot overshoot its stop line; tested with the mock) and `--note`.
5. **Runtime checks.** Variance (laptop, `dc95c555`, 50 matches per fixture, window 5, history on): **0 in-match
   repeats, openers 2.0 %, PA welcomes 3.8 %, carryover 0.4 %** (ceilings 0/10/10/30). Review transcripts re-recorded
   three times as the library moved (the reason each time is in the commit). **C9's cross-match memory** (`5bb8d2a3`):
   `AnnouncerHistory` keeps 40 matches, and PA lines fade on their own curve, never weaker than everybody's in the
   recent matches. Measured old -> new over 400 broadcasts: **window 20 openers 30 % -> 19 %, PA welcomes 40 % -> 33 %**;
   window 5 gives up 0 -> 2 % and 1 -> 4 %. `audio-launch-smoke` on builder0: see Merge notes.
6. **Stretch.** *Callbacks*: four predictions fire at **first contact** (the moment that reaches the air in every
   match; `preview` fired 0 times in 64 broadcasts) and set `predicted_{friendly_fire,flank,scouts,artillery}`; nine
   callbacks in kill, momentum, friendly_kill and result need them. A director test proves the pairing in both
   directions, including that a flag set *after* the moment is hindsight, not a prediction. *The `{arena}` lines*:
   nothing to do - all eight arenas, **Terminus included**, already have clips for all 18 `{arena}` lines. *A second
   pass on the deep pools*: reading the transcripts as a listener found two grammar bugs recorded three rounds ago
   ("The Wreckers **draws** first blood", "hit **its** own scout"); the audit's verb list and its-check now catch both,
   and the 14 lines they flagged are fixed and re-recorded.

### The pool table, before and after (laptop, 40 fixture broadcasts, 51.9 match minutes, `dc95c555`)

Both columns are measured the same way, under the final rules (PA cap 16; the +25 % for deep pools anchored to the
pool as the round FOUND it, not as it grows): the round-start library scores **514**, the round's library **147**.
*(The 568 quoted earlier in the round was the same library under the first cap setting, before the PA's cap came down
to 16 and the growth target stopped receding; 514 → 147 is the honest pair.)* `lines` is what the moment can reach in
the library; `pool at the pick` is what the director actually had to choose from, which is the number that bounds
variety; `N_c` is C9's formula at that λ, and `target` is it capped, or the floor, whichever is larger.

| speaker | moment | λ/min | lines | pool at the pick | N_c | target | deficit |
|---|---|---|---|---|---|---|---|
| caller | drill | 0.79 | 4 → 33 | 2.5 → 25.7 | 32 | 32 | 28 → 6 |
| color | lull | 0.21 | 58 → 85 | 13.4 → 16.3 | 33 | 33 | 27 → 17 |
| caller | kill | 3.57 | 92 → 117 | 14.8 → 30.5 | 140 | 40 | 25 → 9 |
| color | big hit | 0.41 | 18 → 41 | 16.5 → 36.8 | 61 | 40 | 23 → 3 |
| color | momentum | 0.39 | 19 → 44 | 17.0 → 36.0 | 58 | 40 | 23 → 4 |
| caller | result | 0.89 | 34 → 56 | 11.0 → 24.6 | 35 | 35 | 22 → 10 |
| color | army | 0.19 | 26 → 49 | 17.9 → 27.2 | 29 | 29 | 22 → 2 |
| color | drill | 0.73 | 21 → 41 | 19.8 → 31.8 | 109 | 40 | 20 → 8 |
| color | contact | 0.62 | 20 → 44 | 19.7 → 40.2 | 91 | 40 | 20 → 0 |
| caller | big hit | 0.71 | 29 → 48 | 8.9 → 25.7 | 29 | 29 | 19 → 3 |
| color | result | 0.71 | 28 → 48 | 21.9 → 34.1 | 105 | 40 | 18 → 6 |
| color | kill | 0.69 | 41 → 61 | 22.9 → 34.3 | 102 | 40 | 17 → 6 |
| pa | drill | 0.04 | 1 → 15 | 1.0 → 15.0 | 24 | 16 | 15 → 1 |
| pa | big hit | 0.02 | 1 → 16 | 1.0 → 16.0 | 13 | 13 | 15 → 0 |
| caller | contact | 0.62 | 12 → 27 | 7.7 → 18.6 | 25 | 25 | 14 → 6 |
| pa | control | 0.08 | 3 → 16 | 2.5 → 13.2 | 46 | 16 | 14 → 3 |
| pa | kill | 0.17 | 6 → 18 | 3.0 → 9.3 | 102 | 16 | 13 → 7 |
| pa | friendly fire | 0.02 | 2 → 12 | 1.0 → 11.0 | 13 | 13 | 12 → 2 |
| pa | formation | 0.02 | 1 → 12 | 1.0 → 12.0 | 13 | 13 | 12 → 1 |
| pa | momentum | 0.00 | 1 → 11 | 1.0 → 0.0 | 0 | 8 | 12 → 0 |
| caller | army | 0.15 | 16 → 28 | 2.0 → 4.5 | 7 | 12 | 10 → 8 |
| caller | momentum | 0.02 | 3 → 13 | 2.0 → 9.0 | 2 | 12 | 10 → 3 |
| caller | squad wiped | 0.00 | 3 → 12 | 0.0 → 0.0 | 0 | 12 | 9 → 0 |
| caller | control | 0.23 | 7 → 16 | 3.2 → 7.4 | 10 | 12 | 9 → 5 |
| caller | formation | 0.04 | 3 → 13 | 3.0 → 9.5 | 3 | 12 | 9 → 2 |
| caller | tape | 0.00 | 3 → 8 | 0.0 → 0.0 | 0 | 12 | 9 → 4 |
| pa | outro | 1.21 | 15 → 24 | 7.4 → 10.6 | 711 | 16 | 9 → 5 |
| caller | hazard kill | 0.08 | 4 → 12 | 4.7 → 10.5 | 4 | 12 | 8 → 2 |
| caller | friendly kill | 0.08 | 6 → 14 | 4.3 → 12.0 | 4 | 12 | 8 → 0 |
| color | friendly fire | 0.04 | 7 → 15 | 4.0 → 12.5 | 7 | 12 | 8 → 0 |
| caller | preview | 0.00 | 4 → 4 | 0.0 → 0.0 | 0 | 12 | 8 → 8 |
| caller | close call | 0.19 | 6 → 13 | 5.0 → 12.0 | 9 | 12 | 7 → 0 |
| caller | friendly fire | 0.17 | 7 → 14 | 4.6 → 10.9 | 8 | 12 | 7 → 1 |
| caller | intro | 0.62 | 29 → 35 | 23.8 → 29.8 | 25 | 32 | 6 → 2 |
| color | close call | 0.15 | 16 → 21 | 16.0 → 21.0 | 24 | 24 | 5 → 3 |
| pa | hazard kill | 0.00 | 3 → 8 | 0.0 → 0.0 | 0 | 8 | 5 → 0 |
| pa | friendly kill | 0.00 | 4 → 8 | 0.0 → 0.0 | 0 | 8 | 4 → 0 |
| caller | lull | 0.23 | 41 → 45 | 7.8 → 9.7 | 11 | 12 | 4 → 2 |
| pa | army | 0.00 | 4 → 8 | 0.0 → 0.0 | 0 | 8 | 4 → 0 |
| pa | lull | 0.14 | 27 → 31 | 13.0 → 15.0 | 80 | 16 | 3 → 1 |
| color | squad wiped | 0.00 | 11 → 11 | 0.0 → 0.0 | 0 | 12 | 1 → 1 |
| pa | intro | 0.91 | 38 → 44 | 21.8 → 27.1 | 530 | 16 | 0 → 0 |
| color | formation | 0.06 | 29 → 29 | 0.0 → 23.0 | 10 | 29 | 0 → 6 |
| color | tape | 0.00 | 14 → 14 | 0.0 → 0.0 | 0 | 12 | 0 → 0 |
| color | preview | 0.00 | 26 → 26 | 0.0 → 0.0 | 0 | 12 | 0 → 0 |
| color | hazard kill | 0.00 | 12 → 12 | 0.0 → 0.0 | 0 | 12 | 0 → 0 |
| color | control | 0.04 | 14 → 14 | 14.0 → 14.0 | 6 | 12 | 0 → 0 |
| color | intro | 0.00 | 25 → 25 | 0.0 → 0.0 | 0 | 12 | 0 → 0 |
| color | friendly kill | 0.00 | 18 → 19 | 0.0 → 0.0 | 0 | 12 | 0 → 0 |
| **total** | | | **601 → 1119** | | | | **514 → 147** |

**The ledger, this round: 621 requests, 44,608 characters, 41,346 credits spent (108,348 → 63,894).** Five runs, each
its own row in `assets/announcer/ledger.md`: the pilot, the PA (15,253), the Veteran (13,248), the caller with the
stretch pairs (11,755), five speech-to-text re-records (205), and the plural-faction fix (4,009).

### Numbers, each with its commit and machine
- Pool deficit 514 -> 147; library 601 -> 1119 lines (laptop, `dc95c555`, 40 broadcasts).
- Credits 108,348 -> 63,894 (41,346 spent this round, ~4,000 of it the grammar fix and the re-records).
- The pack: 3,051 -> 2,866 clips, 76 MB -> 72 MB (216 orphaned recordings pruned, 24 of them left by an earlier round).
- `make check` on builder0: green on `96333be1` (1559 passed, 0 failed, `exited 0`); the final one in Merge notes.

### Decisions
- **PA cap 16 this round** (the formula wants hundreds for a 30-minute horizon): her lines are the hardest to write
  well, and a mass-produced wrong detail becomes the joke the lead told us to cut. Reversible in `pool_report.py`.
- **"No two lines with the same category" is per moment pool**, not global: 117 PA lines cannot carry 117 kinds of wrong.
- **Takes (C10: the caller at 3 takes a line) are NOT done.** They need the booth to choose between recordings of one
  variant (a runtime change in `AnnouncerVoice` and the manifest) and roughly double the caller's bill. First next step.
- Eight of the 14 grammar fixes **dropped the `{faction}` slot** rather than keep 24 recordings each: same meaning in
  context, a quarter of the cost.

### What to playtest (exact commands)
- `make announcer-demo` then open `build/announcer/demo/index.html#new` (the tab has audio for all 518 lines).
- `make announcer-transcript FIXTURE=gangs_vs_law SEED=2` and read it as a listener.
- `make skirmish` with the announcer on, one match: does the booth repeat itself?

### Next steps (in order)
1. **Takes for the caller** (C10): one variant, several recordings, chosen at random with the recency penalty.
2. The remaining deficit, 147 lines, biggest first: `color lull` 17, `caller kill` 9, `pa kill` 7.
3. The PA's pools past 16 once someone has read a session's worth of her lines and still likes them.

### Questions for the lead
- None blocking. **His veto is a line id** from the New tab's list.

### Requests to other streams
- None.

### Merge notes
- Shared files touched: none outside the stream's own paths (`assets/announcer/`, `tools/announcer/`,
  `tests/announcer/`, `game/announcer/`, `mk/announcer.mk`, this brief).
- **The masters for this round's 523 recordings are in `~/projects/godot-announcer/assets/announcer/masters`
  (git-ignored, ~60 MB).** The main checkout's masters folder does not have them. **Rescue it before this worktree is
  removed** (orchestration lesson 6; `_agents/backups.md` names the masters as an input worth keeping).
