# Stream: booth (the announcers repeat themselves: find the thin pools, deepen them through his veto)

> Read `_agents/orchestration.md` (the worker contract; lead gate 1), `_agents/streams/archive/round12/audio.md` (the
> director, the pool report, the trade pool), `_agents/streams/archive/round4/audio.md` (the voices, whole sentences),
> `assets/announcer/README.md`, `assets/announcer/ledger.md`, `_agents/workstreams.md` *Round 16*. You own
> `game/announcer/**`, `assets/announcer/**`, `tests/announcer/**`, `tests/test_announcer*.gd`, `mk/announcer.mk`,
> `tools/announcer/**`. Contracts C16.1 (nothing is cut), C12.7 (paid generation on the ledger, **text approved by the
> lead before ElevenLabs**), C15.2 (a decision page records when its `db` was last read). The memory on his taste
> stands: *satire subtle and believable, never punchlines; the caller is authentic UFC hype*; production quality over
> credits, he limits scope not spend.

## The lead's direction (2026-10-02)

> *"I had given feedback before about the announcers. The announcers absolutely make the game. But I believe we have
> different sets of possible statements based on actions in the game. I feel like there are cases where the set of
> things to choose from for an announcer to say must be minimal, because I keep hearing a lot of the same statements
> across gameplay"*

Read: the complaint is **repeats across matches** ("across gameplay"), for some moments and not others; his model is
right — the library is pooled per (speaker, moment) with context filters on top, and a frequent moment with a small
effective pool repeats. He plays `make skirmish` natively (the announcer's voice on by default), default armies, Law and
the Condemned lately (`build/recordings/2026-10-02T18-59-00-sumps.jsonl`).

## Where things stand

- **The director** (`game/announcer/announcer_director.gd`): per-kind cooldowns, no line repeats in a match while
  another is available, a history across matches (`announcer_history.gd`, `announcer_memory.gd`: least-recently-heard
  — CHECK that it persists across launches (`user://`), survives the title's tree reload, and is ON in his launch; if
  it only lives in one process, every launch starts with the same favourites and that alone is his complaint).
- **The instruments exist:** `make announcer-pool-report` (lines per (speaker, moment), the pool at each pick, N_c and
  the deficit; `POOL_SEEDS`), `make announcer-real-report` (the same over REAL default-size CPU matches recorded as K5
  timelines, builder0), `make announcer-variance MATCHES=50 WINDOW=5` (how much the booth repeats itself across
  matches), `make announcer-transcript FIXTURE= SEED=` (one match as called), `make announcer-audit` (the text
  library's symbols, slots, tags, duplicates, tone), `make announcer-demo` (the Booth Monitor page).
- **History of the number:** round 10 took the repeat of the most-said line 109 → 44 in 160 broadcasts; round 12
  deepened `trade` 3 → 20 lines and added 49 PA lines where she actually speaks (0.62 → 0.93 a match), then removed the
  ten he vetoed. 589 lines voiced in round 4; 518 lines on the pool at round 10; the booth's faction unit ids were
  unmatchable for 413 of 427 events until round 12 (so until then whole families of lines never fired — the pools he
  hears today are the post-fix pools; the report has not been re-read since).
- **Context filters are the suspect**, not the library size: a line keyed to a faction, a unit class, a speaker and a
  moment leaves an effective pool of a handful; a moment that fires every 10 s with a pool of 4 repeats within a
  match's first minute. The pool report prints the pool AT EACH PICK — that column, ranked by broadcasts per match, is
  the finding.
- **Ledger:** `assets/announcer/ledger.md` (ElevenLabs characters; 44 495 left at round 12's close — read the current
  line). Every paid request logged there. The two voices and the PA are established; no new voice.

## Backlog (in order)

- **B1. The thin pools, from HIS matches.** Replay his recordings through the booth (the recorder's K5 events, or
  `announcer-record-smoke`'s path on a default-size CPU match of the same factions, seed 92721 on the sumps, plus Law v
  Condemned and Gangs v Syndicate at two seeds each — `make remote T=announcer-real-report REAL_MATCHES=8`): for every
  (speaker, moment, filter context) the broadcasts per match, the effective pool at each pick, the repeat rate within a
  match and across 5 matches. Status gets the top 15 thin pools with their lines quoted, and the expected time to the
  first repeat for each. **This table decides B3's scope; send it to the orchestrator.**
- **B2. The free win first: memory across launches.** If the history does not persist (or persists but is not
  consulted at the first picks of a match), persist it (`user://announcer_history.json`, bounded, least-recently-heard
  first across sessions, forgotten after N matches so a line can come back); the garage/title tree reload keeps it;
  tests off the real `user://` (trip-up 54: a scratch path under `--garage-scratch`-style flags). `announcer-variance`
  before/after with `HISTORY=on` is the proof; the sim hash does not move (`announcer-record-smoke`).
- **B3. New lines for the thin pools**, in the voice: for each pool in B1's top list, enough lines that the expected
  first repeat is past 5 matches at his broadcast rate (compute N_c from the report, don't guess), written to the
  moment's slot contract (`announcer_library.gd`, `lines.json` schema), through `make announcer-audit` (tone, slots,
  duplicates), with the two speakers' characters kept (the caller: hype, specific, present-tense; the colour: dry,
  believable, never a punchline) — then **a review page with `db`** for the lead: one card per line, tap APPROVE /
  REJECT, the moment and today's pool shown beside it, the credit cost per line stated (lead gate 1: no generation
  before his taps). Record the time the `db` was last read in Status (C15.2). Message the orchestrator when the page is
  up.
- **B4. After his taps:** `make announcer-generate APPROVED=1 ONLY=<approved ids>` on the ledger, the clips imported
  (`assets/announcer/clips`, the `include_filter`), `announcer-transcripts` regenerated and checked in, `announcer-demo`
  rebuilt, `announcer-variance` and the pool report re-read: the before/after per pool in Status. Vetoed lines are
  removed from `lines.json` the same hour (round 12's rule).
- **B5. The director's pick, widened where it is narrow by accident:** a filter that leaves a pool under N_c when a
  sibling pool (the other speaker, the unfiltered moment) has lines that fit — fall through rather than repeat; a line
  said in the last match is ranked below one never heard. Each rule measured by `announcer-variance`; the transcripts
  check says what changed.
- **B6. The booth's per-frame cost:** `match_event_adapter.gd:44` uses `get_nodes_in_group` — once, cached; the booth
  and voice ≤ 0.1 ms a frame (`make audio-bench` is play's: ask for the row, or time it in your own test).
- **B7 (stretch).** A "what did she just say" line in the recording (the K5 timeline with the picked line id) so his
  next *"I keep hearing…"* is a grep.

## How to verify

- `make remote T=check` green (announcer-check is in it: validate, pytest, audit, variance, transcripts, record-smoke);
  the sim baseline unmoved (the booth reads the match, never writes it).
- `make remote T="announcer-real-report REAL_MATCHES=8"` before and after; `make announcer-variance MATCHES=50
  WINDOW=5 HISTORY=on` before and after; the Booth Monitor page looked at for the new lines in context.
- Listen: `make skirmish` once from the title for a 3-minute match with the new clips, from his seat; `make
  remote T="audio-pass PASS_SECONDS=150"` for the mix.
- The review page's `db` read and recorded; the ledger line after generation; `assets/announcer/clips` in the web
  export's `include_filter` (`make web-smoke` boots).

## Don't touch

Everything outside your paths: `game/audio/**`, `game/theme/audio/**`, `game/modes/**`, `game/ui/**` (play, hud),
`game/match/**` (sim: the K5 event emission is read-only for you; a missing event is a request), `game/ai/**`,
`game/theme/**`, `project.godot`, `export_presets.cfg` (an `include_filter` line is a merge note to the orchestrator),
`mk/core.mk`, `game/main.gd`.

## Waiting on the lead

- **B3's review page** (lead gate 1): the texts, one tap per line, before any ElevenLabs request. Up early; B2 and B5
  continue while it waits.

## Status

_Updated 2026-10-02 evening (the worker, live)._

**Start:** `8318b9db` green on builder0 (1856/0, sim baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`).

**Plan (in order):** B1 the evening instrument → the real table → the orchestrator · B2 (quit counts as heard; the curve
measured) · B6 (cheap, done early; it was one loop) · B3 the lines + the veto page (lead gate 1) · B5 fall-through ·
B4 after his taps · B7 stretch.

**Finding before any run: his memory DOES persist.** `~/.local/share/godot/app_userdata/Tank Squad/announcer_history.json`
holds 31 matches (last written 2026-10-02 19:01), it is loaded every match and the title reload keeps it (it is a
file). So the repeats are not a missing memory: they are pools that a single match uses up, which no memory can fix.
From his own 31 matches (distinct lines per match from each pool, all 31 matches): caller kill `[flurry]` 2.39/match
from 10 lines, `[another]` 2.29 from 13, `[trade]` 2.32 from 20, `[streak]` 1.77 from 9, `interrupt` ("hold on")
1.32 from 6, Veteran `analysis [any]` 1.45 from 11, `[kill]` 1.42 from 15. **Caveat:** the main checkout's user dir is
his, so any orchestrator windowed run there (perf-play, skirmish shots) also writes this file unless it passes
`--announcer-history=off`.

