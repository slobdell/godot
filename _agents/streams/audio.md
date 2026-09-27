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
1. M1+M2 together (one change to one function): the director's draw per state, then the imports. **DONE, `75a9cce8`**.
2. M3 measure: follow the `trade` tag across matches, on real default-size matches (`announcer-real-report`). **Built,
   `965b8a55`; the builder0 run is in flight.**
3. M3(a) the director's widening, decided from that number; M3(b) new trade lines → audit → DRY_RUN → APPROVED=1.
4. M4 the other thin pools, batched, stop at half the balance.
5. M5 stretch: the opening's hand-off with ears (`audio-launch-smoke`), transcripts re-cut.

### Findings the brief did not have
- **The opening was never the pre_match bed.** `MatchMood` starts every match at `lull` and has no `pre_match` state;
  nothing in `game/` asked for `pre_match` (or `garage`). So what he heard every opening was the ONE `lull` bed
  (Subterranean Anvil). Fixed in the director (`music_state_for`: lull before the first shot = `pre_match`).
- **9 of the 23 Suno tracks were already imported** (`190dea27`, 2026-09-17), not 0; PROMPTS.md still called every
  track a placeholder. 14 were unused; all 23 are placed now.
- **A trade is a tag, not a moment:** the director merges kills queued within 4 s and tags the call `trade` when both
  sides lost units. A generic `kill` line is already eligible for it (a line is eligible when all ITS tags are on the
  moment), so M3(a)'s widening exists structurally; the thin part is the weight: each extra matched tag is ×8, so a
  trade call at intensity 3 lands on one of the 3 caller trade lines ~30 % of the time, on one of 4 flurry lines
  ~40 %, and on 33 generic kill lines ~30 %. Within a match a line never repeats, so a match with ≥3 trade calls
  uses all three trade lines. The number to fix is measured in step 2.

### Done
- **M1 + M2 (`75a9cce8`).** Director: `pre_match` for the opening; `candidates_for(state)`; one draw per set of equally
  fitting tracks per match (skirmish and battle share the fight set), from `match_seed` mixed with the set (states do
  not move in lockstep) and `MusicHistory` (least recently heard first: every opening before any repeat).
  `--music-seed=N`, `--music-history=PATH|off` (off when headless). Importer `--id` / `make music-import ID=`.
  **14 tracks imported** (11 beds, 3 fight stem sets via demucs on builder0): every state rotates between 3 and 6
  tracks (the garage/victory pool has 4, which counts for both states).
  Mapping and reasons: `assets/music/PROMPTS.md` *The mapping, and why*.
  - Tests first: on the committed manifest, 3 of the new director tests **FAIL** (`every_music_state_rotates…`,
    `the_opening_is_not_the_same…`, `a_match_draws_each_state…`); on the new manifest **24 passed, 0 failed** (laptop,
    `make test FILTER=music_director`, `75a9cce8`'s tree). Python: `test_music_stems.py` 7 OK (laptop).
  - `music-check` (laptop, `75a9cce8`): **0 problems over 23 tracks**; beds −16.1…−16.3 LUFS, true peak −4.4…−7.4 dB,
    seams ≤ 0.041 (limit 0.25); stems −16.1…−16.9 LUFS.

### Questions for the lead
1. **Web size.** `assets/music/` went from 13 MB to 29 MB and all of it ships in the web pack. Options: accept; drop the
   web build to one track per state and keep the rotation on desktop/Android; or the music-pack-after-start the design
   doc already plans. Nothing chosen; the most reversible is to leave it and decide at the next web release.
2. **By ear:** the placements are by measurement and title (nobody on the agent side can listen). The two weakest are
   `defeat_hunt` (Predatory Hunt) and `defeat_ragnarok` (Ragnarok's Engine). A wrong one is one `states` edit in
   `assets/music/manifest.json`.
3. **The garage has no music** (nothing plays the `garage` state; `game/garage/` is not audio's path). Want it?

### Requests to other streams
- None yet.

### What to playtest
- `make skirmish` twice from the title: the opening (before the first shot) should differ between the two
  (`MUSIC_TRACK state=pre_match track=…` in the log names it).
