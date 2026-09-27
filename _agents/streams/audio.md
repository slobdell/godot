# Stream: audio (the trade call and the opening track)

> Read [`game_design.md`](../game_design.md) *Round 12 direction* (his words on the booth and the music), *The arena
> announcer* (the humour direction and the 2026-09-15 ruling: satire subtle and believable, the caller authentic UFC
> hype, never punchlines), and [`workstreams.md`](../workstreams.md) (round 12: ownership, C12.7; round 10's R8 is the
> procedure). The archived `archive/round10/announcer.md` and `archive/round3/announcer.md` are the booth's history and
> tools; `assets/music/PROMPTS.md` is the music contract. **You own** `game/announcer/`, `assets/announcer/`,
> `tools/announcer/`, `tests/announcer/`, `mk/announcer.mk`; `game/audio/`, `assets/music/`, `assets/incoming/music/`
> (git-ignored Suno masters), `tools/audio/`, `mk/audio.mk`, `tests/test_audio_*.gd`. Runs in isolation: nothing you
> touch is the simulation, and two smokes prove it.

## The lead's direction (2026-09-26, parked until the formation work landed)

> *"I hear 'they are trading, they are trading in the middle of the floor' quite often — do we not have enough random
> phrases that accomplish the same filler? And do we have a wide selection of music tracks? I can't tell if it's playing
> the same music over and over on opening — if there are comparable moods across tracks (which there should be, I did a
> few variations), it would be good if we can randomize the selection."*

Round 10 (2026-09-20), on spend: *"let's burn through some ElevenLabs credits."* Memory notes: production quality over
credits; the lead limits scope (count), not spend.

## Where things stand (one grep by the orchestrator on 2026-09-26; verify before acting)

**The booth.** The line is `caller.kill.69` in `assets/announcer/lines.json` (1119 lines: caller 472, color 421,
pa 226), tagged `["kill", "trade"]`, intensity 3, recorded. It is not lull filler: it is a **kill call for a mutual
trade**. The `trade`-tagged pool is **five lines**: caller 69, 70 (*"Both sides lose one!"*), 71 (*"Blow for blow!"*);
color 20 (*"Even trades favor whoever has more left"*), 21 (*"That's a brawl"*). Three caller lines for a moment that
fires whenever two kills land close together on opposite sides — in a 30-a-side match that is often. The director
(`game/announcer/announcer_director.gd`, 507 lines) has per-kind cooldowns, "no line repeats in a match while another
fits", and lull banter with a back-off; `announcer_variance.gd` and `announcer_history.gd` are where repetition is
supposed to be prevented. Tools: `make announcer-pool-report POOL_SEEDS=5` (lines per (speaker, moment), the pool at
each pick, the deficit), `make announcer-variance MATCHES=50` (how much the booth repeats itself across matches),
`announcer-transcript`, `announcer-audit`, `announcer-generate` (`DRY_RUN=1` default; `APPROVED=1` spends),
`announcer-demo` (the Booth Monitor page), `announcer-check` (in `make check`). Every clip is speech-to-text verified;
every run goes on `assets/announcer/ledger.md`. ElevenLabs balance: check the ledger's last line (~123 k on 2026-09-18
before round 10's spend and round 11's Locks run).

**The music.** `assets/music/manifest.json` holds **9 tracks**: six beds with ONE track each — `garage`, `pre_match`,
`victory`, `defeat`, `lull`, `last_stand` — and three fight stem sets (`fight_hydraulic`, `fight_ritual`, `fight_rust`)
sharing `skirmish`/`battle` at intensity 0.6; plus 6 stingers. `MusicDirector.track_for(state)`
(`game/audio/music_director.gd:216`) picks the best track for a state and, among ties, `tied[posmod(rotation,
tied.size())]` with `rotation` drawn once per match from a randomised RNG in `attach()` (`:98`). **So rotation exists
only where a state has several tracks — the fights — and the opening (`pre_match`) has exactly one bed, which is what
he hears.** `assets/incoming/music/` holds **23 Suno mp3s** never imported (Anvil of Doom, Anvil Protocol, Apocalyptic
Machine Hymn, Factory Silence, Hydraulic Wasteland, Machine Combat, Mechanical Dread, Mechanical Momentum, Mechanical
Predator ×2, Neon Outrun, Neon Wasteland Blues, Post-Apocalyptic Convoy, Predatory Hunt, Ragnarok's Engine, Ritual of
Iron, Rusted Steel Sky, Rust & Hydraulic Pressure, Subterranean Anvil, Warzone Brass, Wasteland Blues ×3) — "the
variations" he mentions. Tools: `make music-import IN= STATE= BPM=` (beds) and the stems form (`music-stems` runs demucs
on builder0), `music-check` (loudness, true peak, loop points, seams against `PROMPTS.md`), `music-smoke` (a headless
match with music on: the beds change and the sim hash does not), `audio-launch-smoke`, `tests/test_audio_music_director.gd`.

## Backlog (in order)

**M1. Prove what he hears, then fix the opening.** A test that `track_for("pre_match")` over 50 fresh `attach()`es
returns more than one track once the manifest has more than one — it will fail today with one bed, which is the point.
Then listen to the 23 incoming tracks (on builder0 or locally; `music-check` each) and assign: which are `pre_match`
moods (the opening: tension, not combat), which `lull`, `garage`, `victory`/`defeat`, `last_stand`, which are fight
material (stems via demucs if they carry the layers `PROMPTS.md` wants). Import so that **every state has at least two
tracks**, the three "Wasteland Blues" and two "Mechanical Predator" variations landing in ONE state each so the
rotation is between comparable moods (his words). Record the mapping and the reason per track in `PROMPTS.md`.
Loudness-match to `target_lufs`; the loop points seam-checked. `music-smoke` green: the sim hash does not move.

**M2. Rotation you can hear.** The per-match pick is one `rotation` for the whole match; check that a match's
`pre_match` → `lull` → fight → `victory` does not always land on the same COMBINATION (the same seed of `rotation`
indexing every tie the same way makes "track 2 of everything" a recognisable evening). Prefer a per-state draw seeded
from the match RNG, and a test that two matches with different seeds differ in at least one state's pick. Never the wall
clock (determinism.md); the music is outside the sim, but the director's draw must still be reproducible from the seed.

**M3. The trade call.** `make announcer-pool-report` and `announcer-variance` on today's library: how often the
`trade` moment fires per match, the pool at each pick, and the repeat rate across 50 matches — that is the number he
hears. Then two things, in this order: (a) widen the director's match for a mutual-trade kill so it can draw from the
whole `kill` pool at that intensity when the `trade` pool is spent (a trade IS a kill call), and check the same shape on
every other thin moment the report names; (b) write new `trade` lines for caller and color — enough that the report's
deficit for that moment goes to zero at the match rate you measured (state the count; likely 8–12 caller, 4–6 color),
in the standing humour direction, through `make announcer-audit`, then `announcer-generate DRY_RUN=1` for the price,
then `APPROVED=1` under C12.7 with the ledger row and the speech-to-text verification. The Booth Monitor (`make
announcer-demo-audio`) shows the new lines for his veto; send the URL/path to the orchestrator.

**M4. The other thin pools.** Whatever else the pool report names as a deficit at the match rate (round 10 deepened
many; some moments will still be two lines deep). Same procedure, batched; stop at half the remaining balance and ask
(C12.7).

**M5 (stretch).** The opening: does `pre_match` hand off to `lull`/fight on the FIGHT cue cleanly with the new beds
(`audio-launch-smoke`, and a real `make skirmish` with your ears); the transcripts re-cut (`announcer-transcripts`) and
`announcer-transcripts-check` green.

## How to verify

- `make remote T=check` green (it runs `announcer-check`, `audio-check`); `music-smoke` and `announcer-record-smoke`
  both report the sim hash UNMOVED (`01ab39b592cc9837`) — if either accuses your change of moving the simulation,
  check whether the three hashes agree before believing it (workstreams.md Invariant 2's note on those two targets).
- `announcer-pool-report` and `announcer-variance` before/after with the numbers in Status; `music-check` per track;
  the pre_match rotation test.
- Listen. A real `make skirmish`, twice, from the title: is the opening different the second time; does the booth
  call a trade two different ways.
- The ledgers: every ElevenLabs run with balance before/after; nothing generated whose text did not pass the audit.

## Don't touch

`game/theme/**` (feel's paths, resting), `game/ai/**`, `game/tactics/**`, `game/match/**` (the K5 event stream is
read, not changed: if a trade needs a new event field, request it in Status), `game/camera/**`.

## Waiting on the lead

His veto on the new lines (the Booth Monitor) and his ears on the opening. Neither blocks; generation is authorised
(C12.7).

## Status

_(the worker keeps this current)_ — updated 2026-09-26 late, by the audio worker.

### Plan (in order, smallest foundation first)
1. M1+M2: the director's draw per state, then the imports. **DONE** (`75a9cce8`).
2. M3 measure: follow the `trade` tag across matches on REAL default-size matches. **DONE** (`965b8a55`, `6cf67f0e`).
3. M3(b) new trade lines, voiced. **DONE** (`3f06d507`). M3(a) the widening: **exists already** (see Findings).
4. Found on the way: the booth sent faction unit ids. **FIXED** (`b5d8fafd`, `33d6133a`).
5. M4 the thin pools the real matches hammer, voiced. **DONE** (`da9edaec`).
6. M5 stretch: `audio-launch-smoke` on builder0 **PASSED**; the transcripts re-cut with each batch (**current** in the
   green check).

### Findings the brief did not have
- **The opening was never the pre_match bed.** `MatchMood` starts every match at `lull` and has no `pre_match` state;
  nothing in `game/` asked for `pre_match` (or `garage`). So what he heard every opening was the ONE `lull` bed
  (Subterranean Anvil). Fixed in the director (`music_state_for`: lull before the first shot = `pre_match`).
- **9 of the 23 Suno tracks were already imported** (`190dea27`, 2026-09-17), not 0; PROMPTS.md still called every
  track a placeholder. 14 were unused; all 23 are placed now.
- **A trade is a tag, not a moment**, so the round-10 pool report could not see it: the director merges kills queued
  within 4 s and tags the call `trade` when both sides lost units. M3(a)'s widening **already exists**: a generic
  `kill` line is eligible for a trade call (a line is eligible when all ITS tags are on the moment). What was thin
  was the pool and the weight (each extra matched tag is ×8, so the 3 trade lines took about half of all trade calls).
- **The fixtures understate the booth's load by half.** Real default-path matches (5200, faction armies, recorded
  with `make announcer-real-matches`, builder0) have 26-63 kills, most in 1-2 minutes; the caller's kill calls run at
  7.6/min against 3.6 in the fixtures, and the trade merge fires 4.1-4.3 times a match.
- **The booth sent faction unit ids (`gang_ifv`) in K5**, which neither validator nor the vocabulary knows. In every
  faction match (every default-path match) each line naming a unit (`{unit}`, `{victim_unit}`, `victim_tank`…) was
  ineligible, and every recording failed the contract (413 of 427 events). `MatchEventAdapter.booth_unit` sends the
  role now. Two faction roles have no words yet (`support`: the Resupply Tanker; `suppressor`: the Sonic Emitter);
  they are valid K5 types and simply aren't named.

### VERIFIED GREEN — merge here: `da9edaec`
builder0, 2026-09-26 late: `>> remote: make check exited 0`, 18 targets, **1733 passed, 0 failed**, `sim-baseline passed:
01ab39b592cc9837` (**UNMOVED**, as pre-registered), determinism passed, `announcer transcripts current`,
`music-smoke passed: 3 bed changes across 3 beds … hash 4ee36a82dcd9444f (matches the same match without the music)`
with `MUSIC_TRACK state=pre_match track=pre_match_hymn` → `battle fight_hydraulic` → `victory garage`,
`announcer-record-smoke passed: hash 4ee36a82dcd9444f (matches the same match without the booth)`.
Commits after it touch only `_agents/streams/audio.md`.

### Done (measurements; every number names its commit and machine)
- **M1 + M2 (`75a9cce8`).** Director: `pre_match` for the opening; `candidates_for(state)`; one draw per set of equally
  fitting tracks per match (skirmish and battle share the fight set), from `match_seed` mixed with the set (states do
  not move in lockstep) and `MusicHistory` (least recently heard first: every opening before any repeat).
  `--music-seed=N`, `--music-history=PATH|off` (off when headless). Importer `--id` / `make music-import ID=`.
  **14 tracks imported** (11 beds, 3 fight stem sets via demucs on builder0): every state rotates between 3 and 6
  tracks (pre_match 3, lull 4, fight 6, last_stand 3, defeat 3, garage/victory one pool of 4).
  Mapping and reasons: `assets/music/PROMPTS.md` *The mapping, and why*.
  - Tests first: on the committed manifest 3 of the new director tests **FAIL**; on the new one **24 passed, 0 failed**
    (laptop, `FILTER=music_director`). `music-check` (laptop): **0 problems over 23 tracks**; beds −16.1…−16.3 LUFS,
    true peak −4.4…−7.4 dB, seams ≤ 0.041 (limit 0.25).
  - builder0 `make check` at `965b8a55`: `music-smoke passed: 3 bed changes across 3 beds … (matches the same match
    without the music)`, `announcer-record-smoke passed … (matches the same match without the booth)`; 1732 passed,
    1 failed (my own new variance test, fixed in `6cf67f0e`).
- **M3 + M4, the booth.** 67 new lines (`added: r12`), all through `make announcer-audit` (0 errors), all voiced,
  speech-to-text flagged 0 of 70 recordings. Caller trade calls 3 → 20, Veteran trade analyses 2 → 8, another 5 → 13,
  streak 5 → 11, comeback 2 → 6, flurry 4 → 10, caller post-contact lull +8, Veteran lull +12.
  **ElevenLabs:** batch 1 19 requests / 1,171 chars, 56,183 → 54,982 settled; batch 2 51 / 3,055, 54,982 → 51,999.
  Both on `assets/announcer/ledger.md`. Balance 51,999; the C12.7 stop line would be ~26k.
  **The number he hears** (laptop, the CLI's `--variance --tag=trade`, 8 recorded real matches × 20 consecutive
  broadcasts, history on; same recordings for every column):

  | | before round 12 | + trade lines (`3f06d507`) | + M4 (`da9edaec`) |
  |---|---|---|---|
  | trade calls per match | 4.14 | 4.18 | 4.29 |
  | answered by a trade line | 49 % | 79 % | 75 % |
  | a trade call's line also a trade call in the previous 4 matches | **48 %** | 37 % | **23 %** |
  | carryover (a match's lines also said the match before) | 13 % | 8 % | **2 %** |
  | the booth's most-said line, uses in 160 broadcasts | 109 ("Blow for blow!"; "They're trading!…" 107) | 82 | **44** |

  The recordings' `match_end` summaries were remapped by role after the fact (the second fix landed after they were
  recorded); every other event is as recorded. Copies: kept in the worker's scratchpad, regenerate with
  `make remote T="announcer-real-report REAL_MATCHES=8"`.
- **M5 (`2c1be0cc`, code = `da9edaec`, builder0): `audio-launch-smoke passed`** — the player's own path (title →
  SKIRMISH → faction menu → FIGHT, no audio flags), two launches in the run: `MUSIC on: 23 beds, 6 stingers` both
  times, and the two openings were **different tracks** (`pre_match_outrun`, then `pre_match`), with the first shot
  handing over to `fight_hydraulic` at 10.6 s. The caption frame (`build/audio-launch/4_caption.png`) shows the
  caller naming the faction. **An earlier run of this target at 23:32 is VOID**: builder0's folders were emptied by
  another stream's rsync at 23:28 (orchestrator lesson 221); its log read `Cannot open file 'res://game/main.tscn'`.
  The green `make check` above finished at 23:17, before the incident.
- **Not done: a real `make skirmish` with ears.** Nobody on the agent side can listen; that check is his.
- **The veto page (with `db`, for his taps): https://claude.ai/artifact/6kWUqopgyKkiv6Ahf669A5** — all 67 r12 lines
  with their clips, grouped by pool, Keep / Veto per line; taps land in its `verdicts` collection (doc id = the line
  id with `.` → `_`, fields `line_id`, `verdict`, `text`, `at`). **Read that `db` at the round's close** (lesson
  220). Private to the owner until shared. Rebuild: `tools`-free, the generator is in the audio worker's scratchpad;
  the local equivalent is the Booth Monitor below.
- **The Booth Monitor** (local) for his veto: `make announcer-demo-audio CLIPS=assets/announcer/clips`, then open
  `build/announcer/demo/index.html#new` — the New tab lists every r12 line with its clip.

### M6 — more of the PA (2026-09-27, after the lead's veto pass)

**His words** (the orchestrator relayed them; he said the same here): *"ok I finished approving the announcers, those
are great - with all the new voice overs for the 2 male announcers it makes me feel like there's more good content
that can be created for the female announcer"*, and in this session: *"I just approved all announcer audio, those were
awesome and hilarious. This makes me feel like more good audio content can be created for the female announcer"*.
He KEPT all 67 lines on the first veto page (dump: `_agents/streams/references/round12/audio_veto_db/`).

**Measured first** (8 recorded real 5200 matches, laptop): she said ~2.7 lines a match, 1.5 of them the sign-off;
kill notices 0.5, welcome 0.4, lull 0.25; during play 0.62 a match. Her army / control / drill / formation /
momentum pools (70 lines) never fire at that density. With her cross-session memory (C9: one hearing is remembered
all evening), the sign-off and the kill notices are what an evening of matches exhausts.

**Built (`8dcc59ad`):** 49 lines in her register, each naming its one wrong detail as data (`oddity {span, category}`;
audit 0 errors), each a category its pool had not used: 21 kill notices (18 → 39), 13 sign-off notices + 3 results
(outro 24 → 40), 12 lull notices / sponsor reads (31 → 43). 58 recordings, 7,875 characters, speech-to-text flagged 0,
ElevenLabs 51,851 → 44,495 settled (ledger row; the earlier batch settled 148 lower than logged, noted there).
`beats.json`: kill *Joseph is corrected* 2 → 4, lull *sponsor read* and *arena notice* 2 → 3. Her lines during play
**0.62 → 0.93 a match**, airtime 16 % → 18 %; the caller unchanged (827 lines), the Veteran 28 % → 26 % (40 broadcasts,
laptop). Review transcripts re-cut; `test_announcer` 41 passed, 0 failed; announcer pytest OK (laptop).

**VERIFIED GREEN — merge here: `159f8645`** (M6 + main at `bcd9dd4f`; builder0, 2026-09-27): `>> remote: make check
exited 0`, 18 targets, **1766 passed, 0 failed**, `sim-baseline passed: 6313a38d7ecd99bb` (main's value after nav's
CP2; audio moves nothing), `announcer transcripts current`, `music-smoke` and `announcer-record-smoke` both `(matches
the same match without …)`. The run at `8dcc59ad` read `sim-baseline FAILED … got 6313a38d7ecd99bb`: that tree had
main at `c8e80f5b`, before main recorded nav's move in `d6094cef`; merging main fixed it, no audio change.

**Her veto page (same shape as the first; `verdicts`, doc id = line id with `.` → `_`):
https://claude.ai/artifact/Kkj5VrQPuw8HNDLJUsPtjk** — 49 lines grouped by where she says them; a result line plays
the Law's take. Empty at publish. **Read its `db` at the round's close.**

### Questions for the lead
1. **Web size.** `assets/music/` went from 13 MB to 29 MB and all of it ships in the web pack. Options: accept; drop the
   web build to one track per state and keep the rotation on desktop/Android; or the music-pack-after-start the design
   doc already plans. Nothing chosen; the most reversible is to leave it and decide at the next web release.
2. **By ear:** the placements are by measurement and title (nobody on the agent side can listen). The two weakest are
   `defeat_hunt` (Predatory Hunt) and `defeat_ragnarok` (Ragnarok's Engine). A wrong one is one `states` edit in
   `assets/music/manifest.json`.
3. **The garage has no music** (nothing plays the `garage` state; `game/garage/` is not audio's path). Want it?

### Requests to other streams
- None. (Nothing outside audio's paths was edited.)

### Merge notes (for the orchestrator)
- **Rescue the ElevenLabs masters before this worktree is removed:** `assets/announcer/masters/` is git-ignored and
  holds the 70 new masters (lesson from round 10: the Terminus masters were lost that way). Copy them into the main
  checkout's `assets/announcer/masters/` (additive; no file there has these names).
- **The Suno masters** stay where they were (`~/projects/godot/assets/incoming/music/`); nothing new to rescue there.
  The demucs stems are in this worktree's `build/audio/stems/` (regenerable).
- K5 (`tests/announcer/fixtures/README.md`): the `unit` fields now carry the unit's ROLE; `support` and `suppressor`
  are valid types. Additive for every consumer (MatchMood reads counts only).
- `assets/music/` is 29 MB (was 13 MB) and all of it is in the web pack; question 1 below.

### What to playtest
- `make skirmish` twice from the title: the opening (before the first shot) should be a different track the second
  time (`MUSIC_TRACK state=pre_match track=…` in the log names it; `user://music_history.json` remembers).
- In a big fight, listen for the trade calls: "Toe to toe! They are standing in the pocket and letting it fly!",
  "Oh, they're exchanging! Both sides just lost one!" and 18 more.
- The Booth Monitor's New tab (above) is the veto list: any line he vetoes comes out of `lines.json` and its clip.
