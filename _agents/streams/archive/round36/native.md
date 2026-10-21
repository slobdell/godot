> **ARCHIVED (round 36 closed 2026-10-21).** The branch is `round36/native`; its unmerged references stay on that branch. Round 37's brief is `streams/native.md` where one exists.

# Stream: native (the scoreboard row for every main; every mirror; cleaner tests)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 36** (C36.1, CP36.1,
> C36.3, C36.5) and in *Round 35*: R35.47 (the bare-teleport note), R35.62 (the inert mirrors), R35.75 (X5: the scoreboard and the
> copy-back leak), R35.78 (W1b dropped). Then your round-35 brief `streams/archive/round35/native.md` (its Status is the close-out,
> with seven round-36 candidates).
> **You own:** `native/**`, `mk/native.mk`, `exec_fields.h`, the twins, planner's paths (`game/ai/planner/**`, `native/src/planner_*`,
> `tests/planner/**`, `tests/test_planner*.gd`, `mk/planner.mk`, `tools/judge/**`), the scoreboard (`mk/scoreboard.mk`,
> `tools/scoreboard/**`, `tests/scoreboard/**`, `references/scoreboard/**`), `tools/copyback_prune.sh` and its hook in
> `tools/remote.sh`, and the test-hygiene grant (C36.5): in ANY owner's test file, a bare `global_position =` spawn placement may be
> replaced by `Tank.place(...)` (or a fresh child) and nothing else, one commit per owner, a merge note naming the files.
> **Model:** Opus. **Machine:** builder2 for the scoreboard (C36.1); checks on whichever builder `tools/builder_checks.sh` shows free.

## The lead's direction

Nothing alone: every C++ change a twin of its GDScript, so the game stays fast on his laptop and the two paths agree. And his
round-35 concern, verbatim (2026-10-20): *"ensure that we're also generally making concrete progress"*: the scoreboard is the
answer he reads, one row per main, in player terms.

## Where things stand

- **On main from round 35:** N2 (FACE_KEEP_FAR gone, seed twins dropped, the judging table's rows), N3 (a source change always
  rebuilds), `tools/builder_checks.sh`, T7's pass lane in C++, W1b's and W1c's mirrors as inert code. The joint's T9 half lands at
  **CP36.1** (`pair/joint-ship`).
- **On `round35/native`, NOT on main:** the scoreboard (`mk/scoreboard.mk`, `tools/scoreboard/run.sh` / `score.py` / `table.py` /
  `mover_kind.py`, `tests/scoreboard/jam_census.gd`; 40 fights + 48 move orders + 36 group orders, seeds 2601+), the copy-back
  prune (`tools/copyback_prune.sh`, 1d8dd7648, its test), and R35.47's two Tank.place fixes (test_native_avoid_gather,
  test_native_record; committed at the close by the orchestrator, UNCHECKED). The first three rows (c29a8c7b6, a0ae0aafd,
  1c82d6d1e) were running on builder2 at the close; the orchestrator commits whatever rows finished to `round35/native`.

## Backlog (in order)

1. **N1 hand over round 35's tools (C36.5):** merge `round35/native` onto your fresh branch (read the diff first), finish any
   scoreboard row that didn't complete, `make native check` on one named hash, send it to the orchestrator. Tooling only: nothing
   he'd notice, so it merges on its check.
2. **N2 score every main the orchestrator names** (builder2, `tools/scoreboard/run.sh <commit>`), starting with main after CP36.1;
   commit the row and the re-rendered `references/scoreboard/README.md`. A number that moved by more than its noise: say so in
   player terms, with n.
3. **N3 mirrors, as asked:** W1b's inert mirror DELETED with manoeuvre's S3 (one pair); stallnet's `_stuck_from` (manoeuvre's S1,
   when its spec arrives: exec_fields row, twins both arms, 0 mismatches); orders' O1–O3 if any reaches C++.
4. **N4 the test-hygiene sweep (R35.47):** the ~85 files that spawn and then set `global_position` (the list is in brains' E4 in
   `streams/archive/round35/brains.md`). Sort them: the ones whose floors could move with process history first (touching hulls),
   then the harmless snapshot reads. One commit per owner, each with a quick-remote of the files it touches.
5. **N5 the census gap lint:** a test that every counter named in a bar appears in its series' printed line (round 35 lost reads
   to a counter added to a rule but not to `ManoeuvreCensus.counters()`).
6. **Stretch:** E4b below the main loop (name the engine state the first iteration sets; a two-body repro).

## How to verify

`make quick-remote`; `make native check` for a named hash, one full check at a time a builder; tool tests on the laptop
(`make shell-tools-test`). Twins: both arms, 0 mismatches, every stage's floor reached.

## Don't touch

Gameplay GDScript outside planner's paths (mirrors follow the owner's spec), other owners' tests beyond the C36.5 grant,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Round 36, 2026-10-20 (worker).** `stream/native` already carried round 35's tools (no `round35/native` branch was cut), so
N1's hand-over is main merged into it (434640730, the brief taken from main) plus the two finished rows (5fabab534:
c29a8c7b6, a0ae0aafd; builder2). The 1c82d6d1e row was running at launch.

**Plan (in order):** N3's S3 pair first (it arrived at launch, small, and manoeuvre waits on it); then N1's check; N2 rows
as named; N4 sweep; N5 lint; stretch.

- **N1 done:** main 434640730, then e45bb6632 (88185ebb0) merged in; rows c29a8c7b6, a0ae0aafd, 1c82d6d1e committed (builder2,
  exit 0, 0 SCRIPT ERRORs, n=1 run per main) with the README rendered. c29a8c7b6 = a0ae0aafd exactly (no game/native source
  differs: determinism holds). 1c82d6d1e v a0ae0aafd: group orders never in 5/36 -> 0/36, moves never settled 13/48 -> 10/48,
  tanks lost per fight 40.4 -> 41.9 (noise not yet sized).
- **Scoreboard v the Spot box (090580147):** builder2's 14:07 preemption killed e45bb6632's run (255, copy-back FAILED) and
  run.sh scored the stale local build/scoreboard (1c82d6d1e's files) as e45bb6632's row (deleted, never committed). Now
  `tools/scoreboard/verdict.sh` gates the row (exited 0 + copied back, verified, no NOT RUN, run.txt names the commit and
  closes with 40/48/36); each attempt clears the local copy, starts builder2 if it is down, retries a 255 (3). 12 known answers.
  e45bb6632 re-running on builder2 (systemd unit native-score-e45bb6632).
- **N3 S3 (W1b's mirror deleted), green alone:** `pair/native-s3` eefc379c5 = manoeuvre's d44c13377 + native half. builder0
  `make check exited 0`, 2950/0, 25 + 2 NOT JUDGED (load), sim-baseline 13/13 unmoved.
- **N3 S1 (stallnet mirror) stacked on S3, at manoeuvre's request:** `pair/native-s1s3-main` **20acbda5f** = S3 + manoeuvre's
  S1 (dbe6ed396/ab71634f4 cherry-picked) + mirror (779f31be5) + main a318a2cd3 (conflicts: OFF_NAMES; manoeuvre.gd's
  `_same_element` kept, W1b's block gone; native_drive.gd S1 + T9 keys) + main e45bb6632. Full check running on builder0; it
  also stands as main's check (the orchestrator did not relaunch one).

- **S1+S3 pair GREEN and MERGED:** builder0 `make check exited 0` on **20acbda5f**: 2961/0, 25 + 2 NOT JUDGED (perf-judge,
  ai-scenarios CPU budget: load 9.5-12.9), sim-baseline 13/13 unmoved; test_manoeuvre_stall_net 3/3 (native default arm =
  GDScript), test_native_h1b PASS. It stood as main e45bb6632's check. Main 5d6bb1de8 = it + manoeuvre's .uid; merged here
  (06069057d).
- **N2 e45bb6632 row** (9ccc92616): builder2, verdict ok. v 1c82d6d1e: tanks lost/fight 41.9 -> 40.9, twitch 12.6 -> 10.8 m,
  left behind 0.06 -> 0.12/order (n=1 a main, noise unsized: no claim).
- **Next for the scoreboard (orchestrator, R36):** a second seed block (2701+, same arenas and cells) on e45bb6632, per-seed sd
  from both blocks -> a "± noise" column (a move called past ~2 se). A same-seed repeat is byte-identical (c29a8c7b6 =
  a0ae0aafd), so it sizes nothing. builder2, after T8's judged series.
- **S2a (h1bside) + traffic's yieldgap (R36.4), one pair:** `pair/native-s2a-yg` **32ba4ca99** = 20acbda5f + manoeuvre
  ab22849a9 + S2a mirror 18bc084c9 + traffic lab/yieldgap 76aea1185 + yieldgap mirror c66058c41 + a test fix. Quick on
  8e6a52fc9: 134/1 (the red my twin reading a freed hull's name); test_native_yield on 32ba4ca99 13/0, nose-on long hulls ON
  1 twinned 0 mismatches not recorded, OFF 1 twinned 0 mismatches recorded. test_manoeuvre_h1b_side 3/3 (native default arm
  = GDScript, fires 5). **GREEN:** builder0 `make check exited 0` on **32ba4ca99**, 2967/0, 25 + 2 NOT JUDGED (load), sim-baseline
  13/13 unmoved. Manoeuvre names and merges it.
- **The ± noise column (fe58b0dbf):** score.py by_seed; table.py 2 se of a difference from references/scoreboard/noise.txt's
  rows (one main's seed blocks); SCORE_SEED_BASE / SCORE_TAG / SCORE_EXPECT for the second block. Provisional on e45bb6632's
  2601+ block alone: 1c82d6d1e -> e45bb6632 twitch 12.6 -> 10.8 m v ± 1.2 m (moved); every other line inside its noise; never in
  "no spread". The raw logs moved out of build/ (../godot-native-score-raw): a check's copy-back deletes build/'s non-.log
  files, which ate three raws' screen.json / run.txt (their committed rows stand). **Owed:** the 2701+ block on builder2 after
  T8's series, then noise.txt names both.
- **Lesson (C36.1):** a full check goes behind `tools/builder_checks.sh --wait-below 1`; I put 32ba4ca99's beside orders'.
- **N4 the test-hygiene sweep (C36.5), DONE:** every spawn placement (the hull acquired in the same function,
  no await / assert / order between, its first seat) is `Tank.place(at, yaw)` (the next-line yaw folded, its
  reset_physics_interpolation dropped). One commit an owner, each quick-remote green on builder0 (`exited 0`):
  native b87ea18ac + 86ca41584 (33/2 then 4/0: `native/gate_twin_case:97` keeps its bare seat, the foundry stage latched no
  gate under place(), 3 -> 0, 0 mismatches either way; drive twins moved and pass, replans 698 -> 798); manoeuvre 41a6c7cd6
  (23 files, 96/0; clearance chords 5 -> 2, three counters one tick each); orders 91b8a1926 (6 files, 53/0; group arrival
  322/330 -> 321/329 ticks); the combat family 393423053 (18 files, 116 seats, 162/0; skimmer 58.0 -> 57.4 m, screen_lost
  65.9 -> 65.3); the other unowned f5bea473e (21 files, 46 seats, 117/0; station_keeping pid gap 0.126 -> 0.129 m, worst 0.342
  -> 0.380, station_faction gaps +-0.03); brains' 7 test_ai seats d9b976128 (granted under C36.6 as R36.14; 7/0;
  ai_start_of_match_cpu_only green 99.9 -> 99.6 m; test_ai_perf_equivalence prints no numbers, its tick-by-tick equality
  passes). Merge notes sent (manoeuvre; orchestrator for orders and brains). Nothing in traffic's files is a spawn seat (all
  re-seats after lab.start). Left everywhere: re-seats after a tick, mid-test moves, non-hulls, chained spawn_tank(...)
  seats with no yaw handle, test_tank_place (the test of place), capture tools (rotation_capture, tactics_shots).
  Every commit was checked with a quick, not a full check: the branch's full check is owed before it merges.
- **Scoreboard: "killed while held at a street mouth"** (traffic's ask: T8 ships and the page had no line for it):
  496d6d70a, score.py reads JAM_CENSUS held_deaths, `--backfill-held` adds it to an old row only when its raw fights
  reproduce the row's every other fight number. Dry-run on copies: c29a8c7b6 71, a0ae0aafd 71, 1c82d6d1e 73, e45bb6632 66,
  3d46b2884 17 held deaths in 40 fights. Rows and README after the 2701+ block on 3d46b2884 (builder2, running).
- **N2 T8's main 3d46b2884, both seed blocks (0285bfe5f):** builder2, 2601+ and 2701+ (n = 8 + 8 seed units), both exit 0
  and verified. verdict.sh refused the 2701+ log only because make's variables sit before "exited" (regex fixed, 2 known
  answers added, test_verdict 14/0); that row was scored by hand from the same raw. noise.txt names both. v e45bb6632 per
  fight: held at a street mouth 1.65 -> 0.42 v +-0.40 (moved); jammed under fire 1.48 -> 1.20 v 0.76, stuck 6.03 -> 5.92 v
  2.33, lost 40.9 -> 40.4 v 9.8: every other line inside its noise. Held line back-filled onto every row.
- **N4's full check:** `native-check-9c7d47380` (builder0, behind --wait-below 1) synced **0285bfe5f**, running.
- **N5 the census gap lint, DONE (ca8145bd5):** tools/census_lint.py: each public int counter in Movement / Manoeuvre /
  Traffic / ManoeuvreCensus the game increments must reach a census / probe / stage script under tests/ (directly or by a
  static Dictionary report, followed transitively); fails on an unprinted counter, a stale or dangling ALLOWED entry, an
  allowed counter named in backticks in a bar. This repo: 115 counters, 110 printed, 5 allowed (manoeuvre's turn_in_*,
  test_manoeuvre_orbit only; manoeuvre told), 0 failures, 0.5 s laptop. Mutation: face_settles out of counters() fails it.
  tools/test_census_lint.sh 9/0 laptop (shell-tools-test runs it in check).
- **N4 MERGED** as main 3fc78e502 (R36.20): its full check on 0285bfe5f (builder0) was 2967/0, sim-baseline 53/0 unmoved,
  one red, relay-smoke (`tanks_seen=4/5`); relay-smoke alone on 0285bfe5f `exited 0`, 5/5 both (R36.12's rule: N4's diff
  touches no net path). Main merged back here (5141af274).
- **The net smokes' early-leave race, traced and fixed (0a4832c2f, granted R36.20):** the client counts the most tanks seen AT
  ONCE, and one that passed closed at once (host: client2 joined, client1 joined, client2 left, before client1's first
  snapshot). bot_client_check.gd: a passing client lingers --linger s (8) before leaving. `make relay-linger-smoke` (not in
  check) forces it: laptop, --linger=0 -> late client FAIL 4/5, 20 -> PASS 5/5; relay-/net-/combat-/relay-drop-smoke exit 0
  with the default (laptop, n=1). Rides with the next hand-over (with N5): owes a full check.
- **T10 mirrors (traffic; T10 judged on native):** `pair/native-t10b` **0ca19d829** = traffic's pair/t10-r36 c917ac33b + 4
  native commits: `seatyield` (begin_yield takes, of today's whole candidates, the one nearest the seat within SEAT_NEAR_M;
  strict <, by index; not firing = today), the asker-clear clock under `clearclock` (_yield_clear_seen exec field;
  yield_clear_n / ticks / never), `seat_near` (R36.19, exec field + seat_near_total, under clearclock either arm), all
  configured from SEAT_NEAR_M (native_drive.gd). Twins: test_native_yield's seat stage (5 fresh-process arms, 18 drives each,
  0 mismatches; ON 6 m move_to / face_slot seated 18 moved 15; 14 m and OFF never; seat_near 18 near in both arms, 0 at 14 m);
  clearclock on through every yield stage. **builder0 quick GREEN on 0ca19d829: 99/0, exited 0** (79ce37acc 26/0, cc5e11c72
  29/0 before). Found for traffic: H's `_count_seat_near()` marked no stale (the owned state would write it back): c917ac33b.
  Traffic takes the full check on builder2, then the T10 series.
- **stream/native full check on 024232755 (builder0): RED 2971/1, exited 2**, on one flake not from this diff:
  test_match_shell_dropped_peer's "the relay session has ended (expected 0, got 2)". Alone on builder0 (024232755,
  `make remote T="quick QUICK_FILTER=test_match_shell_dropped_peer:: QUICK_LINT=-"`): 5/5 exited 0. The race is in the test:
  `wait_physics_frames(2)` can mean 0-1 multiplayer polls under load (polls run per process frame; grace 0 needs > 0 ms).
  The fix (outside native's paths, proposed to the orchestrator 2026-10-21): wait for DISCONNECTED, bounded 30 physics frames.
  **Merged under R36.12 as main f2090ffa5 (R36.22).** The fix, granted: **e78f7cd9f** (main merged first, 35ac778f6) waits
  for CONNECTION_DISCONNECTED, bounded 30 physics frames, both asserts kept. builder0, on e78f7cd9f's tree: 2/2 green; mutant
  (grace_ms 300: the shell lands first) RED on "the shell was still in flight ... (expected 0, got 1)". Rides with the next
  hand-over (owes a full check).
- **R36.22 sweep: network tests' fixed frame-count waits on an event.** Files: tests/net/*, test_match_shell_dropped_peer,
  test_relay_peer, test_lobby, test_network_input, test_manoeuvre_stall_net (every test naming RelayPeer, multiplayer_peer,
  rpc or a connection status), plus mk/net.mk's recipes. **No other one found.** bot_client_check and lobby_check wait on
  deadlines (`Time.get_ticks_msec() < deadline`). test_relay_peer is synchronous (on_control). test_lobby's 1-3 frames
  are UI layout settling, with no network. Two side notes, neither a flake nor a false green:
  (a) `relay_host_up`, broker-load and lobby-smoke wait 5 s for BROKER_LISTENING and fall through silently, so a broker
  that never listens shows ~30 s later as "host never opened a room";
  (b) under `-eu -o pipefail` a combat-smoke client FAIL exits before the reap and the server-ERROR grep: red, but no
  diagnostics.
- **E4b (stretch) DONE: e9190b443, `make native-first-tick-sync`.** R35.57's naming was wrong: the state is NOT engine-side and
  NOT set by the first main-loop iteration. **It is the call context of the setup**, which decides whether a new body's
  placement reaches the physics server before the body's first tick.
  - **The real test** (scenarios_6 alone; laptop, GDScript, NATIVE=off, the 6839efe50 tree with local probes; n=1 each):

    | Setup runs from | Reads |
    |---|---|
    | the physics-frame signal (today's warm-up) | 3.0 |
    | the process-frame signal | 3.0 |
    | the idle-frame flush | 3.0 |
    | a call_deferred flushed inside a LATER physics frame (physics=3 process=2) | **4.8** |
    | no warm-up | 4.8 |

    The no-warm-up arm is not "before any iteration". Its setup runs at physics=1 process=0, inside the physics frame's
    deferred flush, because `_initialize -> _run.call_deferred()`.
  - **Ruled out**, each server switched off during the warm-up iteration, every arm still 3.0: PhysicsServer3D, PhysicsServer2D,
    NavigationServer3D and NavigationServer2D. Also ruled out: the lab's start frame (waited_frames=1, tick=1, physics_frames=3
    in both arms), autoloads (none), global RNG (none on AI paths), and frame-0 sentinels (all -1 / -1000000).
  - **The two-body repro** (laptop = builder0, Godot 4.7.2 Jolt):
    - Synced (the space holds the placement at tick 0, and the pair separates to -0.871/3.871): physics_flush, in_tick.
    - Stale (the space holds the add-time origin, and penetration recovery throws them over each other): physics_signal,
      process_signal, process_flush, main_ready.
    - Engine order is inferred from the measurements, not read in source. A placement reaches the server at the SceneTree's
      transform flush that follows the physics frame's deferred-call flush. A body built before that flush ticks synced; one
      built earlier in the frame, or in idle, ticks once against the stale transform.
  - **Real play:** `--skirmish` builds its squads in main._ready (main_ready is stale, the 3.0 class), so brains' warm-up stays
    the right fix, for the corrected reason. Respawns go through `place()` (_placed_settle skips their stale tick).
  - **Stale text:** R36.25 corrected R35.57 and HANDOFF; run_tests.gd's comment corrected by native under grant (cb9aef5aa,
    comment only). Originally proposed: run_tests.gd:115-121's comment ("engine-side state set by the
    first iteration (most likely the physics space's first step)"), and R35.57 / HANDOFF "real play's engine state".

- **R36.24 order flicker TRACED (ff1825b09; `references/round36/native/order_flip_trace.md`; no code).** builder0 light lane,
  native loaded, cb9aef5aa (main e778ca5c6, T10 OFF) plus print-only probes, locks/3/click s3664, n=3 runs, the same ticks
  each run.
  - **Writer:** GDScript `Element.update` -> `Element._issue` (element.gd:1932) -> `Orders.issue`, source "element". It is
    not the native execute.
  - **Cause:** the halt formation flips herringbone <-> coil (doctrine: lanes/dense -> herringbone, open -> coil), and the
    flip re-seats Bravo_2 17.6 m (key `reseat`).
  - **The condition:** `ElementSituation.terrain_at(center)` has no hysteresis. One cover feature sits at 45.0-45.5 m (=
    TERRAIN_RADIUS) from the crews' centroid, which Bravo_2's own creeping moves by 0.07 m. The terrain flips at the same
    ticks as the order writes (1159 / 1276 / 1288 / 1294).
  - **Round 37:** latch the halt shape per arrival, or read terrain at the anchor; size it by terrain-caused reseats.
  - The laptop does not reproduce it.
- **Close hand-over MERGED: 4a6b345d9 = main 48f4dc979.** builder0 `make native check exited 0`, 2972/0, sim-baseline
  unmoved. perf-judge was NOT JUDGED (the box was busy); the orchestrator ruled it moot, since the diff has no
  game/native/server code and main's perf-judge stands at 83eaddf66. The rerun was cancelled and its remote tree killed.
- **R36.28 yield re-pin: `pair/native-yield-repin` 6a92e7a74** (on main 5f2cd6187), to stack into S2a's hand-over pair.
  - **The change:** the Sumps stage ranks go from 7 x 16 m to 6 x 13 m (SUMPS_GAP / SUMPS_ACROSS).
  - **Why:** yieldgap stopped the re-yields that made every old back-up (laptop: spot:back 15 -> 0).
  - **builder0 quick, the whole test_native_yield file:** 13/0 `exited 0` in both arms, OFF (main) and ON (+ bf678480c's two
    flips). Sumps spot:back 21 / 21; 0 mismatches over 376 / 477 drives.
  - **Laptop sweep** (gap 6/7 x across 11-14): 6/13, 7/11, 7/12 and 7/13 pass both arms.
  - **Lesson:** side worktrees have no local.mk, so they share the default smoke ports. Two parallel remote quicks from them
    collided in combat-smoke (peer=0, tanks_seen=3/2), twice. Run them one at a time, or give each a local.mk.

**2026-10-20 (orchestrator, at launch).** Not started.
