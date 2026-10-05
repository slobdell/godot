# Stream: ship (a baseline that sees every map he plays, so a change to a map or a brain cannot pass unseen; and the check's last allowed leaks)

> Read `_agents/orchestration.md` (the worker contract; lessons 243–253 are mostly yours by subject),
> `_agents/determinism.md`, `_agents/remote_builds.md`, `_agents/verification.md`,
> `_agents/streams/archive/round17/ship.md` (your predecessor: the check as it stands) and
> `_agents/streams/archive/round17/yard.md` (*the sim baseline cannot be moved by the layouts*),
> `_agents/workstreams.md` *Round 18*. You own `mk/core.mk` (the check's composition, the baseline targets),
> `tests/baselines/**` (brains adopts the `sim_state_hash.txt` line at its CP1; every other line and file is yours),
> `tools/slot.sh`, `tools/remote.sh`, `tools/round_status.sh`, `tools/engine_log_gate.py`, `tests/run_tests.gd`,
> `tests/support/**`, the `ai-perf*` / `perf-judge` / `scenario_perf` targets of `mk/ai.mk`, `_agents/verification.md`,
> `_agents/remote_builds.md`, `_agents/determinism.md`. **Not this round: the browser build** (below).

## The lead's direction (2026-10-04, in chat; verbatim)

> *"Don't worry too much about the browser version right now, I don't want to sacrifice anything on our game to
> accomodate browser play"*

So no browser work this round: `export_presets.cfg`, `mk/web.mk` and the web smokes stay as they are, `web-smoke`
stays in `check` unchanged, and the three browser candidates (frame rate, a host that fails to open a room, the wasm
trap) are held. **If any stream's change turns a web target red, the native game does not bend:** report it to the
orchestrator with the line; do not ask the stream to cut the feature.

No words of his on the baseline. It is here because his map item cannot be checked without it: the maps stream is
about to add layouts and brains is about to change a decision in every unit, and today's baseline would see neither on
any map he actually plays.

## Where things stand

- **The baseline covers one map nobody is dealt** (yard's finding, round 17): `sim-baseline` and `determinism` run
  `SIM_HASH_READ` (`mk/core.mk:604`) with no `--arena`, so on `foundry` (`Arena.DEFAULT_LAYOUT`), which holds zero
  containers. Round 17's CP1 turned every container on every dealt map and the baseline, correctly, did not move.
  The comment above `SIM_HASH_READ` records the earlier half of the same lesson (it once fielded only tanks).
- **The instrument exists as a one-off:** `make container-hashes` (`mk/arena.mk:234`, the maps stream's file) runs the
  baseline's own match on every layout and prints a hash each; foundry's line equals the baseline. Round 17's table,
  builder0, `1c497496`, each run twice and identical, is in `streams/archive/round17/yard.md`.
- **The adopter handles one line per glibc:** `make sim-baseline-adopt` reads twice on builder0, refuses a
  disagreement, merges the line and prints the commit message (`mk/core.mk:630–660`); the file is
  `tests/baselines/sim_state_hash.txt` (`glibc-2.43 05df1d55ba49cde1`).
- **The check today:** 23 targets, about 20 minutes on builder0 (`488c06bf`, 2026-10-04 10:14–10:34 PDT, exited 0,
  2002 passed 0 failed, ALL JUDGED). `sim-baseline` is 4 s of it.
- **The test shards leak at exit** (your predecessor's gate, `f5b2226c`, builder0): shards 0, 1 and 3 print, after
  their `0 failed` line, up to 414 ObjectDB instances, 14 CanvasItem RIDs, 10 resources still in use, and RID
  allocations (DummyTexture 41, ShapedText 121, Font 3). Allowed for `test` only by two lines in
  `tests/baselines/engine_log_allowed.txt`. No smoke and no player path prints a leak line.
- **`tools/round_status.sh` does not print the disk** (lesson 249: two workers' scratch filled 119 GB in eight hours).
  The laptop is at 83 GB used, 30 GB free (2026-10-04 14:33 PDT).

## Backlog (in order)

- **S1. A baseline line per dealt map.** Design it, then price it in check seconds before building the expensive
  form. Decide and record: which layouts (recommended: every name in `Arena.ROTATION` plus `foundry`, read from the
  game so a newly dealt map cannot be forgotten: a rotation map with no line FAILS, it does not skip); which match
  (recommended: the baseline's own doctrines, seed and 40 s, as `container-hashes` does, so foundry's line stays the
  number everyone knows); one file with a `<glibc> <layout> <hash>` line each, or one file per layout; run
  concurrently inside the target (six 4 s matches should not cost 24 s). The failure message names the MAP that
  moved and what to run. `determinism` gets the same reach if its minutes allow (twice per map), or one dealt map
  beside foundry, chosen for what it exercises (water, bridges, containers); say which and why.
- **S2. The adopter, for many lines.** `make sim-baseline-adopt` adopts every line that moved, each read twice on
  builder0, refusing any disagreement, and prints one commit message that lists map, before and after. Drive every
  branch once with a stub before it merges (lesson 250): nothing moved; one map moved; all moved; two reads
  disagree; a rotation map has no line; an unknown glibc.
- **S3 = CP0. Land it early.** Record the launch tree's lines (builder0, twice), prove the target red on a
  deliberately stale line and on a one-box nudge of one dealt layout made in a scratch copy (the round-17 class), and
  give the orchestrator the green hash. **It merges before brains' CP1** if you are first; if brains is first, the
  orchestrator re-records your lines on the merged tree (C18.1). Tell the orchestrator the seconds it added.
- **S4. Candidates stay out, visibly.** The maps stream adds a CANDIDATE class of layouts (playable by name, never
  dealt). They carry no baseline line while candidates; the day one is dealt (`ROTATION`, his word) S1's rule makes
  the missing line a failure with the adopt command in its message. A smoke that every candidate at least loads and
  runs 10 s of a headless match without an engine error line belongs in `check-all`, not `check`: price it.
- **S5. The test shards exit clean.** Run one shard with `--verbose` to name the leaked objects; free what the tests
  leave (the fix is in the test or its fixture: for another stream's test file, the minimal fix is yours this round,
  listed in merge notes); delete the two allow-list lines; the gate now fails `test` on a leak.
- **S6. `make round-status` prints the disk**: `df -h /` and `du -sh /tmp/claude-1000/*` beside the worktrees, with
  the 3 GB floor called out (lesson 249).
- **Stretch.** (a) The baseline match fields every locomotion × mount combination but only one faction pair and one
  seed: what a second line (another seed, his usual factions) would cost and what it would have caught in rounds
  15–17 (read the merge tables; count the changes that did not move the baseline and should have). (b) The check's
  wall time by target on today's tree, and the one or two cheapest cuts. (c) A known-red list in `verification.md`
  that is generated, not remembered (`web-host-smoke`, the wasm trap), so "red outside check" is one command.

## How to verify

`make remote T=check` green on every commit you report: the wrapper's `>> remote: make check exited <N>` line, `N
passed, M failed`, the count of targets and ALL JUDGED, and a count of `ERROR|WARNING|parsing error` lines against the
previous check's (lesson 251). Never a pipe. **Your changes move no hash: foundry's line stays `05df1d55ba49cde1`
until brains' CP1 says otherwise.** Every recipe branch driven once by a stub (lesson 250). Announce to the
orchestrator before your first `mk/core.mk` change merges: every stream's check changes under it.

## Don't touch

`export_presets.cfg`, `mk/web.mk`, `game/web/**`, `tools/web_smoke/**` (held; his words) · `mk/arena.mk`, `arenas/**`,
`game/arena/**` (maps; `container-hashes` is theirs: call it or copy its command, and tell them which) ·
`game/ai/**`, `game/tactics/**` (brains) · `game/ui/**`, `game/control/**` (picker) · `game/theme/fx/**` (finale).

## Waiting on the lead

- Nothing.

## Status

_Updated 2026-10-04 14:57 PDT (from `date`). Worker: godot-ship._

**Plan (in order):** S1 per-map lines (tool + stub tests, then record on builder0) → S2 adopter (same tool) → S3 = CP0
(record twice, prove red on a stale line and on a one-box nudge in a scratch copy, price it, hand the green hash) →
S6 disk on round-status (done early: it is local and small) → S4 candidates-smoke (built; priced at CP0) → S5 shards
exit clean (diagnosis needs builder0) → stretch (a), (b), (c).

**Decisions (one line each):**
- **One file, three columns** `<glibc> <map> <hash>` (`tests/baselines/sim_state_hash.txt`), provenance comment per
  line: one reader, one adopter, one place to look; a pre-round-18 two-column line is REFUSED by name, never read as
  foundry.
- **Which maps:** `Arena.DEFAULT_LAYOUT` + every name in `Arena.ROTATION`, read from the game by
  `tests/support/dealt_layouts.gd` (constants off the script, no class cache needed). A dealt map with no line FAILS
  with `make sim-baseline-adopt` in the message; a machine with no lines at all SKIPS as before (the laptop).
- **Which match:** the baseline's own (sim_baseline doctrines, seed 3, 40 s, elimination) + `--arena=<map>`; foundry's
  line is expected to stay `05df1d55ba49cde1` (`--arena=foundry` = the default).
- **Concurrently:** every map at once in Python threads (`SIM_BASELINE_JOBS` caps it); fixed tick, so load cannot
  move a hash.
- **Arm assertions (lesson 247):** an "arena: … using foundry" fallback fails that map; two maps sharing one hash fail.
  `MATCH_RESULT` does not name its arena (`game/modes/**` is nobody's), so these two stand in for it.
- **Adopter:** every map read twice on builder0 concurrently; ANY disagreement refuses the whole adoption; merges
  moved and missing lines, DROPS lines of maps no longer dealt, keeps other machines' lines and unmoved lines'
  provenance, prints one commit message listing each map before → after and the unmoved ones. Replaces
  `tools/baseline_merge.py` and its test (deleted).
- **Candidates:** `candidates-smoke` (check-all) reads `Arena.CANDIDATES` — **maps: please name the constant exactly
  that** (an Array of names) or tell me the name.

**Done so far (laptop unless said):**
- `b11d57f2` S1/S2 tool + targets; `tools/test_sim_baseline.sh` 46/0 stub-driven (every branch in S2's list).
- `7cd6f28a` S6: `== disk ==` in round-status (free GB vs the 3 GB floor, `df -h /`, scratch dirs largest first);
  `tools/test_round_status.sh` 44/0.
- `7897c031` S4 `candidates-smoke` (51/0 with its stubs); S5's diagnostic: the runner lists tests that leave orphan
  nodes, `--leak-report`, `make test-leaks`. First finding (laptop, `test_hud_widgets` alone):
  `test_the_look_button_is_there_only_with_render_levers` leaves 5 orphan nodes (HudSkin's five member-initialised
  `.new()` controls, freed without ever entering the tree) and the exit prints 5 CanvasItem RIDs, 24 ObjectDB
  instances, ShapedText 6, Font 1 — the round-17 leak class, in miniature.

- **Launch tree green** (`cbda2c6a`, builder0, 14:44 queued → 15:32 PDT): exited 0, 23 targets all passed ALL JUDGED,
  2002/0, sim-baseline `05df1d55ba49cde1` unmoved, determinism `762a0576f944f5b7`; 39 `ERROR|WARNING|parsing error`
  lines in the wrapper's output (the reference count). Before-seconds from the target stamps (2 at once, load 6–9):
  determinism 16 s, sim-baseline 8 s.
- **S3 lines recorded** (`3ee39518`; builder0, glibc 2.43, `make sim-baseline-adopt`, each map read twice at `1586d40e`,
  agreeing, 15:32 PDT): foundry `05df1d55ba49cde1` (unmoved: `--arena=foundry` = the default), yard `797dc49109a452d8`,
  pit `098f7d5cb3795e7f`, terminus `8b0309ee85e497dc`, crossing `efc8449e97b18eb1`, sumps `bf0bdb98568700db`, locks
  `db5512352146803e` — seven different hashes.
- **S3 proved red** (builder0, 15:42–15:46 PDT): (1) yard's middle container pair (container_20 at ±(17, −3)) moved
  0.5 m and turned 3°, uncommitted, reverted right after the sync → `yard MOVED: expected 797dc491…, got b4b363f5…`,
  the six others unmoved, exit 2, message names `make sim-baseline-adopt` and `container-hashes CH_LAYOUTS=<map>`;
  (2) a stale pit line (a scratch file via `SIM_BASELINE_FILE`) → `pit MOVED`, exit 2. The next run after the revert
  read yard unmoved again.
- **Determinism carve-out** granted by the orchestrator (godot-67, 2026-10-04, before 15:10 PDT): `84c403c6` — crossing beside foundry, 7/0 stubs.
- **Stretch (c)** `1586d40e`: `tests/baselines/known_red.txt` (web-host-smoke), `make known-red`, check-all's KNOWN RED tag.
- **CP0 GREEN: `3ee39518`** (builder0, 15:47 → ~16:16 PDT, load 9.8–12, test x4, 2 at once): exited 0, 23 targets all
  passed ALL JUDGED, 2002/0, 1694 s; hashes line: all seven maps unmoved, determinism foundry `762a0576f944f5b7`,
  crossing `0459b39aa81dd51e`. 33 `ERROR|WARNING|parsing error` lines vs 39 on the launch tree: the difference is
  only the test shards' exit-leak lines (4 shards leaking fewer than 5), no new line. **Seconds added** (target
  stamps; same box, heavier load): sim-baseline 8 → 17 s, determinism 16 → 14 s; both run beside `test` (~25 min), so
  the check's wall time does not move. **Merge here: `3ee39518`** (everything after it is docs/Status).
- **Docs** `69dbce5c`: determinism.md *Per-map baseline*, verification.md, remote_builds.md.

**S5: the test shards exit clean** (`712f851f`). `make test-leaks` (builder0, `9ef6620e`, 16:48–17:07 PDT, 5 shards,
`--verbose --leak-report`) named every exit leak; shards 1 and 4 had none:
| Shard | At exit | Source (named by the runner's ORPHAN list / Godot's stray-node and resource lines) | Fix |
|---|---|---|---|
| 0 | 131 ObjectDB, 5 resources (music_director, music_history, match_mood, the test's script, test_case.gd) | `test_audio_music_director`'s `_director()`: a MusicDirector node most tests never add or free; its loader lambda holds the test | the helper hands it to the test's teardown (`_owned_nodes`) |
| 2 | 297 ObjectDB, 14 CanvasItem, 121 ShapedText, 46 DummyTexture, 3 Font, 5 resources (cyber_banner, cyber_frame, caption_line, two fonts) | `test_control_faction_pick::test_the_arena_choice_reaches_the_restarted_match` (+14 orphans): the main scene instantiated and freed outside the tree; the HUD widgets' member controls (`var x := Button.new()`, parented only in `_ready()`) were orphaned | `LeakFree.free_with_members` (`tests/support/leak_free.gd`, walks the subtree and members' members) |
| 3 | 6 ObjectDB, 3 resources (orders.gd, the test's script, test_case.gd) | `test_tactics_reissue`: watcher lambdas capture `orders` and are connected to `orders.order_changed` — a reference cycle | disconnect this file's lambdas (`is_custom()`) when each test ends |
| (laptop) | 24 ObjectDB, 5 CanvasItem, ShapedText 6, Font 1 | `test_hud_widgets::test_the_look_button…`: HudSkin's five member controls | `LeakFree.free_with_members` |
Every fixed file exits with no leak line on the laptop (`test_hud_widgets` + `test_control_faction_pick` 27/0;
`test_audio_music_director` 32/0; `test_tactics_reissue` 2/0). The two allow-list lines are deleted: **a leak at a
shard's exit now fails `test`** (the gate's own suite already drives that branch: `tools/test_engine_log_gate.sh`
`run test "… were leaked …"`). Note for readers of the runner's new ORPHAN list: per-test orphan counts include nodes
freed later (shard 1 listed +2820 for `test_every_unit_selectable` and still exited clean); the exit lines are the gate.
**Not yet scanned:** picker's `tests/test_control_formation_picker.gd` (merged to main after this scan; the
orchestrator's heads-up) — re-run `make remote T=test-leaks` after merging main.

**Findings after the merge of main (2026-10-04 evening; laptop unless said):**
- **Picker's `test_control_formation_picker::test_previewing_a_formation_issues_nothing` aborted the process at exit**
  ("corrupted size vs. prev_size in fastbins", exit 134, glibc 2.39), alone, every run, with main's runner too. Picker
  found the cause by removal: lambdas still connected to Orders' signals when the test's coroutine frame dies; fixed in
  their test. **And `make test` could not see it:** each shard's exit status went to `test-shards/N.status` and was never
  read. Fixed (`50fb0ed1`): a shard that dies after its summary line fails `test`, named, with its last lines
  (`tools/test_test_shards.sh` 5/0). builder0's main check at `d9372259` happened to exit that shard 0 (glibc 2.43).
- **The exit-code audit** (orchestrator's ask; a research pass over every check/check-all target): 13 places where a
  Godot exit was lost. Ship's own fixed: `perf_judge.sh` (PASS then 134 read as PASS; `3c3fd291`, `tools/test_perf_judge.sh`
  5/0), `sim_baseline.py` (a hash from a run that exited non-zero is refused; `f6ff6d2c`). Items 1–8 LENT to ship by the
  orchestrator (C18.6) and fixed in `db95aed3`: garage-smoke, army-loop-smoke, tactics-drills, ai-scenarios-check (exit 1
  expected: its gate is on counts), music-smoke's garage run, desktop-smoke, windowed-elimination-pair, and the
  background servers of net-/combat-/relay-smokes (reaped; 143 = our SIGTERM is the one expected code). Proved red by
  stubs (`tools/test_lent_exit_codes.sh` 8/0, `tools/test_reap.sh` 5/0); net-, combat- and relay-smoke pass for real on
  the laptop with each server reaped at 143. Not fixed, by the orchestrator's scope: the web smokes (C18.7), perf-play-measure
  (a measure), lint (minor), and picker's own three in `mk/command.mk`. **If a target goes red on main once it can see
  the exit code, that is a finding for the path's owner, not a gate to soften.**
- **`Watch.on(signal, callable)`** (`tests/support/watch.gd`, `91ee5112`): a test watcher the runner disconnects after each
  test's teardown — the right thing to reach for instead of `sig.connect(func …)`. Scan of `tests/`: 72 `.connect(func`
  sites; the risky ones connect to a RefCounted emitter that outlives the test — `Orders` (test_control_orders ×4,
  test_tactics_reissue ×2 fixed, test_control_formation_picker ×2 fixed by picker), `MatchMood` (test_audio_match_mood ×2),
  `RelayPeer` (test_relay_peer ×6); the rest are on nodes the test frees. None of those prints an exit line today
  (S5's scan); a runner or lint refusal of the pattern would fail 72 sites, so it is offered, not built.
- **Brains' x18m moved three of seven lines** (foundry, yard, pit; terminus, crossing, sumps, locks unmoved: the 40 s
  match there takes no peek decision). `make sim-variants` + `tools/sim_variants.py compare` (`9970ca25`) price the
  candidate lines against that case (below, when run). The adopter's message now takes `WHY=` and `WHY_UNMOVED=`
  (`f6ff6d2c`) so "three moved, four unmoved, and why" is printed by the tool.

**Stretch (a): what a second line would cost and would have caught** (rounds 15–17 read from HANDOFF's merge tables and
the archived briefs; the reading is a research pass, each claim with its file:line in this session's notes, "inferred"
where nobody ran the match). The foundry baseline missed **six merged fight changes**:
| Rnd | Change | Per-map line? | Faction/seed line? |
|---|---|---|---|
| 15 | nav V1 `03f8336c` brake for ≥10 m hulls (War Rigs) | possible (inferred) | yes with the Gangs' rigs (inferred) |
| 15 | squad P4 far-ambush turn-in | no (baseline doctrines run no drill) | yes with the CPU's gangs table (inferred) |
| 15 | squad P5 bait runner returns | no | yes with gangs (inferred) |
| 16 | sim S9 `law_ifv` wheels → tracks | no (`law_ifv` is not in the baseline doctrines) | yes with a Law line (inferred) |
| 17 | yard CP1 `9314a2db` containers turned | **yes, stated** (yard's table: 5 of 6 dealt maps moved; terminus did not) | longer/other seed covers terminus |
| 17 | yard CP2 `f8032806` strength B | **yes, stated** (terminus again identical at 40 s) | same |
Neither line would have caught the skirmish-only fire RNG (`0010bcb4`) or the windowed kill-cam / Sumps fork (windowed
only, after the decision). **Counts: per-map 2 stated + 1 inferred (now shipped); a line with his usual factions (Gangs v
Law, CPU tables on) 3 inferred, 4 with nav V1.** Price: one more 40 s match per map, concurrent, ≈ the 9 s the per-map
lines added to `sim-baseline`'s own time (builder0, `3ee39518`), off the critical path. **Recommendation:** a second
line per dealt map with the factions he plays (`--green-faction=gangs --rust-faction=law`, the CPU's directives on,
seed 3, 40 s), adopted by the same tool; and for the terminus blind spot, 60 s instead of 40 on that line. Not built:
it moves the instrument the round's contracts count on (C18.1), so it waits for the orchestrator's word after CP1.

**Stretch (b): the check's wall time by target** (`3ee39518`, builder0, 15:52–16:21 PDT, load 9.8–12, test x4): the
critical path IS perf-judge 30 s → lint 324 s (gates every target) → test 1370 s = 1724 s of the 1694 s total; every
other target runs beside `test` (ai-scenarios-check 317, announcer-check 131, remote-guard-test 123, audio-check 98,
web-smoke 83, the rest ≤ 30 s). **The two cheapest cuts:** (1) start `test` while lint runs and discard its verdict
if lint fails (lint is red perhaps once a round; the rationale — "a parse error makes every target fail confusingly"
— is kept by reporting test NOT RUN on a red lint): saves ~5 min, ~19 %; (2) test's shard count (4 here: `slot.sh
--jobs 500` reads free memory on a box with 25 other Godots) — a fifth shard was ~1574 s total on the launch tree vs
1694 s, which is noise-level at these loads; not worth chasing before (1). Neither built: (1) changes what "lint gates"
means for every stream; offered to the orchestrator.

**Questions for the lead:** none.

**Requests to other streams:** maps — the candidate list as `Arena.CANDIDATES` (above). Orchestrator — `determinism`
lives in `mk/match.mk` (nobody's this round): may I add one dealt map (crossing) beside foundry there? (Asked at CP0.)

**Known issues:** none yet.

**Merge notes (shared files, minimal fixes outside ship's paths):**
- `mk/match.mk` — the `determinism` recipe only (orchestrator's carve-out, C18.6 addition): crossing beside foundry.
- `tests/test_hud_widgets.gd`, `tests/test_control_faction_pick.gd` (picker's) — one line each: `LeakFree.free_with_members(…)`
  instead of `.free()`.
- `tests/test_tactics_reissue.gd` (brains': `tests/test_tactics*.gd`) — `_release(orders)` at the end of both tests, and
  the helper. (The S5 commit message says "no owner"; it is brains'.)
- `tests/audio/test_audio_music_director.gd` (no owner this round) — `_director()` appends its node to `_owned_nodes`.
- `tools/baseline_merge.py` and `tools/test_baseline_merge.sh` deleted (superseded by `tools/sim_baseline.py`).
- `tests/baselines/sim_state_hash.txt` is three-column now; a two-column line is refused (brains' CP1 adopts with the
  new `make sim-baseline-adopt` after merging main).

**What to try (exact commands):** `make round-status` (the `== disk ==` block); `make sim-baseline-layouts`;
`make remote T=sim-baseline`; `make known-red` after a `make remote T=check-all`; `make remote T=test-leaks`.
Nothing here changes what the lead sees or plays.

**Next steps:** merge main when the orchestrator says (after CP0's check on main); then `make remote T=test-leaks` for
picker's new formation-picker test, and a check-all once (drives check-all's new verdicts file and KNOWN RED tag on
the real web-host-smoke, and prices `candidates-smoke` once parade is on main). Stretch (a)'s second line and (b)'s
"test beside lint" cut wait on the orchestrator's word.

**Housekeeping:** round 17 ship's old session scratch (`/tmp/claude-1000/-home-slobdell-projects-godot-ship/fe69721c…`,
140 MB) left in place (not this session's; 28 GB free at 17:13 PDT).

