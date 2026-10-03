> **ARCHIVED (round 16, CLOSED 2026-10-03).** This brief ran as stream `booth` in round 16; every item is merged to `main`
> (`HANDOFF.md` *ROUND 16*). The Status below is the worker's final report. Kept for its numbers and decisions.

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

**Green:** `aa0a2174` (B7 + main CP1 merged): builder0 `make check exited 0`, 1873/0, baseline unmoved, determinism
`762a0576f944f5b7`. Before it, `a1985ba8` (B2, B5, B6, the instrument): builder0 `make check exited 0`, 1859/0, baseline `05df1d55ba49cde1`
unmoved, determinism `762a0576f944f5b7`, clean tree. **Start:** `8318b9db` green on builder0 (1856/0, sim baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`).

**Plan (in order):** B1 the evening instrument → the real table → the orchestrator · B2 (quit counts as heard; the curve
measured) · B6 (cheap, done early; it was one loop) · B3 the lines + the veto page (lead gate 1) · B5 fall-through ·
B4 after his taps · B7 stretch.

**Where it stands:** every backlog item DONE (B1–B7). B3's gate passed: he approved all 62.

**Finding before any run: his memory DOES persist.** `~/.local/share/godot/app_userdata/Tank Squad/announcer_history.json`
holds 31 matches (last written 2026-10-02 19:01), it is loaded every match and the title reload keeps it (it is a
file). So the repeats are not a missing memory: they are pools that a single match uses up, which no memory can fix.
From his own 31 matches (distinct lines per match from each pool, all 31 matches): caller kill `[flurry]` 2.39/match
from 10 lines, `[another]` 2.29 from 13, `[trade]` 2.32 from 20, `[streak]` 1.77 from 9, `interrupt` ("hold on")
1.32 from 6, Veteran `analysis [any]` 1.45 from 11, `[kill]` 1.42 from 15. **Caveat:** the main checkout's user dir is
his, so any orchestrator windowed run there (perf-play, skirmish shots) also writes this file unless it passes
`--announcer-history=off`.

### B1: the thin pools, from his matches (DONE)

**Workload:** `make remote T=announcer-real-report` with `REAL_PLAN` = his matchups (law v condemned seed 92721 on the
sumps, condemned v law 92722 sumps, law v condemned 11 and 12, gangs v syndicate 21 and 22, law v gangs 31, syndicate v
condemned 41; budget 5200; builder0, tree `89eb7765` (recording only: the events do not depend on the director); 28–54 kills a match, 59–223 s).
Then replayed locally (laptop) as **one evening of 40 matches with one memory** (`announcer_cli --evening`, matches in
turn, director seeds 1–40) through `tools/announcer/thin_pools.py`, with the director at `723ad8eb` (today's booth).
`again in 5` = the share of the pool's calls whose line was also said in the previous 4 matches; `his matches` = his
real `user://announcer_history.json` (31 matches), distinct lines a match from that pool. Overall: **7.09 of 34.1
calls a match (20.8 %) were a line heard in the last five matches.**

| # | pool (speaker act [line tags]) | lines | calls/match | again in 5 | repeats/match | first repeat of the evening | lines/rate (matches between hearings) | his matches: lines/match | target lines |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `caller call [kill,streak]` | 9 | 2.60 | 72 % | 1.88 | match 4, 5 min in | 3.5 | 1.77 | 17 |
| 2 | `caller call [flurry,kill]` | 10 | 2.52 | 58 % | 1.47 | match 4, 5 min in | 4.0 | 2.39 | 17 |
| 3 | `caller call [another,kill]` | 13 | 2.62 | 31 % | 0.82 | match 3, 4 min in | 5.0 | 2.29 | 18 |
| 4 | `caller interrupt [any]` | 6 | 1.35 | 52 % | 0.70 | match 5, 8 min in | 4.4 | 1.32 | 9 |
| 5 | `caller call [kill]` | 39 | 3.70 | 10 % | 0.35 | match 6, 10 min in | 10.5 | 5.84 | 24 |
| 6 | `caller call [kill,trade]` | 20 | 2.45 | 12 % | 0.30 | match 5, 7 min in | 8.2 | 2.32 | 17 |
| 7 | `caller stat [kill,streak]` | 2 | 0.42 | 59 % | 0.25 | match 5, 10 min in | 4.8 | 0.35 | 4 |
| 8 | `color analysis [any]` | 11 | 1.05 | 12 % | 0.12 | match 7, 12 min in | 10.5 | 1.45 | 8 |
| 9 | `caller call [kill,upset]` | 4 | 0.57 | 22 % | 0.12 | match 5, 7 min in | 7.0 | 0.19 | 4 |
| 10 | `caller call [kill,killer_tank]` | 2 | 0.40 | 31 % | 0.12 | match 4, 5 min in | 5.0 | 0.26 | 3 |
| 11 | `pa sponsor_read [faction_syndicate,kill]` | 3 | 0.47 | 21 % | 0.10 | match 6, 10 min in | 6.4 | 0.19 | 4 |
| 12 | `caller call [kill,victim_scout]` | 1 | 0.23 | 44 % | 0.10 | match 10, 18 min in | 4.3 | 0.13 | 3 |
| 13 | `caller call [comeback,kill]` | 6 | 0.75 | 10 % | 0.08 | match 11, 20 min in | 8.0 | 0.58 | 5 |
| 14 | `caller call [final_kill,kill]` | 4 | 0.57 | 13 % | 0.07 | match 6, 11 min in | 7.0 | 0.42 | 4 |
| 15 | `caller call [counter,kill]` | 2 | 0.30 | 25 % | 0.07 | match 10, 18 min in | 6.7 | 0.23 | 3 |

**1. `caller call [kill,streak]`** (9): *That's {streak} in a row for {faction}! They cannot miss!* / *{faction} are on a tear! That's {streak} straight!* / *Another one for {faction}! This is a clinic!* / *They cannot be stopped right now! Everything they touch goes down!* / *This is a run! This is a real run, folks!* / *Somebody has to answer this! They're taking everything!* / *Unanswered! Kill after kill, and nothing coming back!* / *{faction} are rolling! I don't know who stops this!* / *They are dominating this stretch! Absolutely dominating!*

**2. `caller call [flurry,kill]`** (10): *Vehicles are going down all over the floor! {kills} in a matter of seconds!* / *It is chaos down there! I can't even keep up!* / *{faction} are cleaning house! {kills} down, just like that!* / *Did everybody see that? {kills} vehicles gone in the blink of an eye!* / *Wrecks everywhere! I can't count them fast enough!* / *Everything is going off at once down there!* / *That was a storm! Vehicles falling all over the place!* / *Where do I even look? It's going off all over the floor!* / *Three, four at a time! This crowd doesn't know where to look!* / *In the space of a breath, the whole picture changes!*

**3. `caller call [another,kill]`** (13): *And another one! {faction} isn't done!* / *Two in a row! {faction} strike again!* / *Back to back! {faction} take out the {victim_unit} too!* / *They got another one! Oh my goodness!* / *And the {victim_unit} goes down right behind it!* / *They're not stopping! That's another one!* / *And they do it again! Right on top of the last one!* / *Oh, and another! They smell blood out there!* / *Same crew, same result! Another vehicle down!* / *It keeps happening! One more off the board!* / *Right behind it! Another one goes!* / *They are relentless! That's one more!* / *Here comes another! The pressure is suffocating!*

**4. `caller interrupt [any]`** (6): *Oh, wait, wait!* / *Hold on, hold on!* / *Whoa! Look at this!* / *Sorry to cut you off, but look!* / *Whoa, whoa, whoa!* / *Here it comes!*

**5. `caller call [kill]`** (39): *{faction} take out the {victim_unit}!* / *The {victim_unit} is done! {faction} get the kill!* / *That's it for the {victim_unit}! It is not moving!* / *Oh, the {other_faction_attr} {victim_unit} is finished!* / *Scratch one {victim_unit}! {faction} strike!* / *And the {victim_unit} goes up in flames!* / *That {victim_unit} is out of the fight!* / *{faction_s} {killer_unit} puts it away!* / *Put it away! {faction} put it away!* / *It's gone! That {victim_unit} is gone!* / *They pick off the {victim_unit}. Clean work.* / *Oh, they blew that {victim_unit} wide open!* / *{other_faction} are down to {count}!* / *The {victim_unit} is out, and {other_faction} are running short.* / *Down it goes! That one is finished!* / *Oh, they lit that one up!* / *That's a kill! No doubt about that one!* / *And that vehicle is not getting back up!* / *Oh, it's over for that crew! It's over!* / *That one's done. Clean shot, clean result.* / *Right on target, and that's another hull on the scrap pile!* / *Oh, they just folded that thing in half!* / *Stopped cold! That machine is going nowhere!* / *Good night! That one is going home on a truck!* / *There's the finish! They closed the deal!* / *And that's one fewer on the floor.* / *What a shot! What a shot! That is a kill!* / *It's burning! That one is burning, and it's out!* / *Ohh, they took that one apart piece by piece!* / *No answer for that one! None!* / *That's lights out for that crew!* / *They wear it down, and there it goes. Patience pays.* / *Dead stop! That thing is scrap!* / *Another hull goes dark!* / *They finished it! They absolutely finished it!* / *Smoke pouring out, and that one is done for the night!* / *And that's the end of that one.* / *Oh, you do not come back from that!* / *That one saw it coming and could not get out of the way!*

**6. `caller call [kill,trade]`** (20): *They're trading! They are trading in the middle of the floor!* / *Both sides lose one! Neither army is backing down!* / *Blow for blow! Everybody is swinging, and everybody is getting hit!* / *One goes down, then the other! This is a slugfest!* / *Oh, they're exchanging! Both sides just lost one!* / *Toe to toe! They are standing in the pocket and letting it fly!* / *Neither side will take a step back, and both of them pay for it!* / *Wrecks on both sides! This is an absolute war out there!* / *An even exchange! And the pace does not slow down one bit!* / *Both armies bleeding! Both armies still coming forward!* / *It's a firefight, folks! Everybody is getting tagged!* / *One for one! Nobody out there is willing to blink!* / *They are throwing everything they have at each other!* / *A big loss on one side, a big loss on the other! What a sequence!* / *Nobody wants to back up! Two wrecks in a matter of seconds!* / *Give and take! That's a war of attrition right there!* / *Hit for hit! Neither of them flinches!* / *Both sides answer at once! What an exchange!* / *They're swapping wrecks out there! Nobody is winning this one clean!* / *Back and forth, and both of them bleed for it!*


### B5 (DONE, `a1985ba8`): a specific line heard in the last 4 matches competes as a generic one

Two rules measured on that evening. **Excluding last match's lines: flat** (7.09 → 7.35 repeats a match; reverted:
these pools run dry inside one match, so ordering by last match cannot help). **Dropping the 8× specificity bonus for a
line heard in the last `RECENT_MATCHES` = 4 matches: 7.09 → 4.11** (seed offsets 1000/2000: 6.09 → 4.33, 6.66 → 4.90);
streak 72 → 56 %, flurry 58 → 49 %, another 31 → 12 %; moments answered by their own lines unchanged (streak 22/20 %,
trade 80/81 %). `announcer-variance` (fixtures, 50×, window 5, laptop): opener 2.0 → 0 %, welcome 3.8 → 0 %, carryover
0.25 → 0.18 %; **the cost: trade calls answered by a trade line 71 → 57 %** on the fixtures.

**The trade question (orchestrator, 2026-10-02):** on the real 40-match evening B5 costs the trade call nothing: trade
moments answered by a trade line **98/123 (80 %) → 109/134 (81 %)**. The fixtures' 71 → 57 % comes from the variance
tool replaying ONE fixture 50 times, so the same trades come back every match and every trade line is "recent". When a
trade call does fall through, the listener hears a single-kill call about the newest kill, true but one-sided: *"Back to
back! {faction} take out the {victim_unit} too!"*, *"Nobody saw that coming! The {killer_unit} wins that one!"*, *"They
put a hole in the Syndicate's pretty paint job!"*. It reads as a kill call, not as "both sides lost one". To hear it:
`make announcer-transcript FIXTURE=close_match SEED=1` shows calls without history; the evening rows
(`announcer_cli --evening ... --out`) carry `moment_tags` beside `line_tags` for every call.

### B3: 62 lines on his veto page (DONE: all 62 approved)

**Page: https://claude.ai/artifact/QYrMFqKyrMZM1hAvzzadNR** (db collection `verdicts`, doc id = line id with `.` → `_`,
fields `line_id, verdict (approve|reject), text, at`; `meta/booth.last_read` shows him when the booth last read it).
**db read: EMPTY at publish, 2026-10-03 03:46 UTC (20:46 local, 2026-10-02)** (C15.2). Re-read EMPTY 2026-10-03 04:16 UTC. **Read 2026-10-03 04:41 UTC: 62/62 `approve`, tapped 04:31:31–04:33:59 UTC, every text
matching the draft** (dump: `_agents/streams/references/round16/booth_veto_db/`); his words in chat, relayed by the
orchestrator: *"for whichever agent was waiting my approval on the web UI, I approved all the proposed announcements"*. Private to the owner until shared.
Drafts: `assets/announcer/drafts/r16_lines.json` (the game never loads it; `announcer_cli --extra-lines` measures it).
Generator: `tools/announcer/review_page.py` + `review_template.html` (checked in).
- caller streak +17 (9 → 26), flurry +12 (10 → 22), another +12 (13 → 25), interrupt +8 (6 → 14), the streak stat +3
  (2 → 5), final kill +3 (4 → 7), upset +3 (4 → 7); the PA's result +4 (12 → 16; wrong details toward the venue and its
  paperwork, the kinds he kept in round 12: paperwork, inspection, insurance, utilities). Audit: 0 errors.
- **Measured with B5 (40-match evening, laptop, three seed sets): repeats 7.09 → 1.12 / 0.95 / 1.00 a match (3 % of
  calls)**; streak 7 %, flurry 2 %, another 4 %, interrupt 4 %.
- Cost if all approved: **74 recordings, 5,374 characters (~5,374 credits) + speech-to-text**; ledger had 44,495.

### B2: memory across launches (DONE, `723ad8eb`)

It already persisted (above). The one hole: **a match quit before its result was never remembered** (`_exit_tree`
saved only finished broadcasts), so after quitting to the title the next match could open with what he had just heard.
Now any match that said something is remembered (`test_a_match_quit_midway_still_counts_as_heard`, scratch path). The
text-mode booth test no longer reads the real `user://` memory. The curve was measured, not changed: B5's rule is the
lever (above). The sim hash is untouched (`announcer-record-smoke` in every check).

### B6: the booth's per-frame cost (DONE, `723ad8eb`)

`match_event_adapter.gd:44`'s `get_nodes_in_group` runs once, at setup, never per frame. The real per-tick cost was
`_watch_health` walking 52 Dictionary records every tick. It now skips unchanged hulls through packed arrays.
**0.112 → 0.055 ms a tick mean** (laptop, load ~8, 26 v 26, 600 ticks, `tests/announcer/test_announcer_cost.gd`, which
prints `BOOTH_COST` and the split: poll 77 → ~38 µs, mood ~9, director ~20). **K5 events byte-identical** on a 60 s
law v condemned headless match (149 events, 93 damage, 1 close call; old vs new adapter). The voice's own cost is
play's `audio-bench` row (not measured here).

### B7: what the booth said, greppable (DONE, `66e4fc46`)

When the match has a `MatchRecorder` (his skirmish), every line goes to `<recording>.booth.txt` beside it:
`0:27.6  CALLER   caller.kill.68            Did everybody see that? Three vehicles gone in the blink of an eye!`.
His next *"I keep hearing …"* is `grep -l "trading" build/recordings/*.booth.txt`. Smoke: a headless spectated
skirmish (law v condemned, seed 92721, the Sumps, `--cinematic --player=cpu`, laptop) wrote 39 lines from the PA's
welcome on. Reads only the recorder's `path` (sim's node).

### B4: voiced, imported, measured (DONE)

`make announcer-generate APPROVED=1 ONLY=<the 62 ids> MAX_CHARACTERS=6000` (2026-10-03 ~04:45 UTC, laptop): **74 requests,
5,374 characters, speech-to-text flagged 0, alignment errors 0**; balance read **43,777 → 39,731** (the ledger row; the
previous row closed at 44,495, so 718 went between rounds 12 and 16, not here; the 39,731 read may still settle). The
62 lines moved from the drafts into `lines.json` (only additions, verified); the drafts file deleted (nothing rejected).
Takes checked by pace: 2.4–5.4 words a second against the caller's existing 1.9–5.3 (median 3.4, 42 clips); none
regenerated. Review transcripts regenerated (16 files, `announcer-transcripts-check` current). Booth Monitor rebuilt
against the real pack (`announcer-demo-audio CLIPS=assets/announcer/clips`: no line the director wants is missing a clip).

**Before / after, the 40-match real evening (laptop, three seed sets):** repeats within five matches **7.09 → 1.12 /
0.95 / 1.00 a match (20.8 % → 3 % of calls)**; per pool (offset 0): streak 72 → 7 %, flurry 58 → 2 %, another 31 → 4 %,
interrupt 52 → 4 %, generic kill 10 → 2 %. `announcer-variance` (fixtures, 50×, window 5): opener 2.0 → 0 %, welcome
3.8 → 0 %, carryover 0.25 → 0.09 %, in-match repeats 0.

**The ledger gap (orchestrator's ask):** the account's TTS history (read 2026-10-03 04:56 UTC) shows **no requests
between round 12's batches (2026-09-27) and tonight's**, so the 718 credits between the round-12 close (44,495) and
tonight's start read (43,777) were not speech. The likeliest cause is round 12's speech-to-text settling after its
closing read: tonight's batch did the same, 39,731 at the end of the run → **38,274 settled** (5,503 in all: 5,374 TTS
+ ~129 speech-to-text, which bills by audio duration). Recorded as **unknown, most likely late-settling speech-to-text,
between rounds 12 and 16**.

**The browser build has no announcer voice** (code reading, not a run): the Web preset excludes
`assets/announcer/clips/*` (and the folder has a `.gdignore`), so `AnnouncerVoice.load_clips` finds no `manifest.json`
and the booth falls back to subtitles only (`ANNOUNCER no recorded clips … subtitles only`). A round-17 question.

### Questions for the lead

- None open. To hear it: `make skirmish`, two or three matches; `build/recordings/*.booth.txt` shows what was said.

### Requests to other streams

- **play / the orchestrator:** windowed automated runs in the main checkout write his `user://announcer_history.json`
  unless they pass `--announcer-history=off` (relayed; play's harness carries it from its tip).

### Known issues

- `b5b80a8e`'s check read 1872/1: `test_a_specific_line_heard_lately_competes_as_a_generic_one` asserted a fixed 3 % that
  B4's 17 new streak lines outgrew (4 %; the rule works). The assertion is now relative to the unheard share. Lesson:
  re-run the announcer tests after a LIBRARY change, not only after code. `scenario_perf` NOT JUDGED in the same run
  (loaded, 2.06×), the known load refusal.

- `make announcer-variance` replays ONE fixture 50 times; its trade "answered" share drops with B5 (71 → 57 %) for
  that reason only. The real evening (`announcer-thin-pools` over real matches) is the instrument for this question.
- The remote copy-back mirrors `build/` with `--delete`: scripts kept under `build/` vanish after a remote run (only
  `*.log` is protected). Keep launch scripts in the scratchpad.

### What to playtest

- `make skirmish` (any faction), 3 minutes, then `ls build/recordings/*.booth.txt`: what the booth said, line by line.
  Two or three matches in a row: the streak, pile-up and "another one" calls should vary more (B5) before any new
  lines.
- After B4: the new lines in his ears (`make skirmish`), and `make announcer-demo-audio CLIPS=assets/announcer/clips`.

### Next steps

- His ears on the new lines (`make skirmish`); a veto after listening removes the line and its clip the same hour.
- The streak stat (5 lines, 22 % in five matches) is the thinnest pool left; the Veteran's `analysis [any]` (11) next.

### Merge notes

- Paths: `game/announcer/**`, `tests/announcer/**`, `tools/announcer/**`, `mk/announcer.mk`,
  `assets/announcer/**` (62 lines, 74 clips, manifest, ledger, transcripts), `_agents/streams/references/round16/booth_veto_db/`.
  No shared files touched. **Web export:** nothing to add. The Web preset's `exclude_filter` (export_presets.cfg line 10)
  already excludes `assets/announcer/clips/*` (the clips folder has a `.gdignore`), so the new clips follow the old ones.
  The Linux Desktop preset (line 48) does not exclude them. The masters (`assets/announcer/masters/`, git-ignored)
  for these 74 takes are in THIS worktree only: rsync them into the main checkout's masters before removing it.
- New targets: `announcer-thin-pools` (EVENING_DIR, EVENING_MATCHES, HISTORY_FILE, EXTRA_LINES); `announcer-real-matches`
  takes `REAL_PLAN=green:rust:seed[:arena] ...`.
- `main` (CP1 `7100e3fe`, HANDOFF `1bec31fb`) merged into the branch at `56d7acbf`, clean.

