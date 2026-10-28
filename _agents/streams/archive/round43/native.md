> **ARCHIVED (round 43 closed 2026-10-28).** Final state of this brief; round 43's results are in `workstreams.md` *Bars (round 43)* and *Rulings (round 43)*.

# Stream: native (the quiet reads; his match replayed faithfully (CP43.0); twins for what ships; the judged lines)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 43** (C43.1, C43.2, C43.4, CP43.0), your
> round-42 brief `streams/archive/round42/native.md` (Status: N4 never run, lines_r42, the guard tool's paired means). **You own:**
> `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`,
> `tools/loaded.sh`, `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe, `_agents/judging.md`; NEW this round `tests/replay_orders.gd`,
> `tools/recording_arrivals.py`, `tests/replay/**`; GRANT (C43.2) keys on the `match` / `order` rows of `game/match/match_recorder.gd`.
> **Model:** Opus. **Machine:** builder0 (quiet window first); builder2 for rows.

## The lead's direction

Nothing he sees directly: "core components in C++ long-term" (memory). This round his playtest could not be re-run: "I don't know if
this is a regression" can only be answered by a replay of his match that reproduces it.

## Where things stand (main at launch: see HANDOFF)

- **builder0 is idle at launch** (20:32 PDT: load 0.00) and the other three streams spend their first half hour reading. N4 (the
  quiet-box read) has never had a window in round 42.
- **The replay probe** `tests/replay_orders.gd` (the orchestrator's, now yours) re-issues his recorded orders into a headless skirmish
  (`--fixed-fps 30`, same seed / arena / factions / cap) and writes a new recording. On his `references/round42/playtest/` recording
  it diverges inside 2 s: his Guns squad jams at the start (War Rig 3 yields 20 s to his Hunters), the replay's drives off. Candidates,
  none tested: his laptop ran 26-31 fps (frame-rate-dependent movement or a physics/frame tick mismatch); an order landing on a
  different tick or frame phase than recorded; the interactive input path (selection, a drag, group-click layout from the screen's
  rays) issuing something different from the recorded row; state the recording doesn't hold (the army's spawn deal, RNG draws by
  anything frame-driven: camera, audio, LOD, the announcer).
- `tools/recording_arrivals.py` reads a recording's arrivals (the orchestrator's; yours now).
- Two control-timing OVER BUDGET lines noted by camera on a loaded box: a right click on 30 units 2699.8 v 104 workloads; control per
  frame 28.25 v 26.0. Re-read quiet before anyone acts on them.

## Backlog (in order)

1. **N1 the quiet reads (now, while builder0 is idle; time-box 60 min, then yield to the others).** `make remote-quiet`: perf-judge on
   main b12b17ac7 (the round's reference), N4 lint-fast before/after wall time, the two control-timing lines re-read. Report each with
   commit, machine, load. If someone's check starts, stop and record what you got.
2. **N2 CP43.0 the replay reproduces his match.** First measure the divergence (per crew per census tick: replay v his match). Then find
   the cause by removing candidates one at a time (run the replay at his frame rate: e.g. `--fixed-fps 28` or the recorded frame times;
   issue orders on the recorded tick and phase; drive the real input path). Fix in your paths; add to the recording (C43.2: additive keys
   only) whatever it must hold for the next playtest to replay. Bar (filed before the numbers): every crew of his first two orders
   within 3 m of his census for the first 20 s, on this recording and on round 41's (`references/round42/engage/`). If an interactive
   match cannot be replayed bit-faithfully, write why and what would make it so. Name the green hash: the orchestrator merges it alone
   and tells engage and manoeuvre the same minute.
3. **N3 twins as asked:** manoeuvre's S2 / S3 rules, engage's A3 if it lands in a mirrored seam (C43.4). Pair branches as before.
4. **N4 lines_r43** as bars are filed (from workstreams.md *Bars (round 43)* and the streams' tables; nothing re-measured).
5. **Stretch:** a `make replay RECORDING=<file>` target (headless, prints the divergence table) so every future playtest can be re-run.

## How to verify

`make quick-remote`; `make remote T=check` for a hash you name; native-proof on builder0 for any twin. The replay: its divergence table
on both recordings, before and after.

## Don't touch

`game/ai/movement.gd`, `traffic.gd` (manoeuvre), `game/tactics/**` (engage), `game/camera/**` (camera), `game/match/**` but your
C43.2 keys, `tests/baselines/**`. If the divergence's cause is in someone else's code, write it up and message the orchestrator. Don't
push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**FINAL REPORT (native, round 43, 2026-10-28 ~13:30). Every backlog item and stretch done; nothing waiting on the lead.**
- **Done:** N1 the quiet reads (N4 lint-fast's quiet read never got a quiet window: not done), N2 / CP43.0 (his round-42 match replays
  exactly), N2a (the G1 v9 hitch bisected), N2b (R43.11 untangle memo), N3 three twins (A7 landed via engage; kturngoal b2dea555a and
  parkaside 5b5a2c365 ride manoeuvre's close as OFF code), N4 lines_r43 (49 lines, every round-43 bar), N5 `make playtest-report`,
  stretch `make replay-match`, remote.sh's builder-side log, close step 5b (round 43's inventory + table, judging.md section).
- **N6 (GRANT tests/run_tests.gd):** the runner FAILS a test file that defines a hook TestCase never calls (before_each,
  after_each, before_all, after_all, setup, set_up, tear_down, ...: run_tests.gd UNCALLED_HOOKS), naming it with "TestCase calls
  only teardown()". 6cd8e65e4; test_runner_hooks 2/0 with tests/support/uncalled_hooks_fixture.gd; a demo copy under a test_
  name FAILS as `<file>` (laptop). Cause: manoeuvre's latch tests armed in before_each, so they passed for the wrong reason.
- **Merges:** 24744f2df = main c707aff67; 3bc207d16 = main b72f4f13c. **GREEN, to merge at the close: 6cd8e65e4** (main b72f4f13c
  merged in, lines_r43's 49 lines, step 5b, N6): builder0 `>> remote: make check exited 0`, 3393 passed / 0 failed, 28 targets ALL
  JUDGED, perf-judge PASS 1.00x (7398 us/tick). The tip above it is this Status only (docs).
- **Findings:** the kturngoal pair's native-proof had compared GDScript with GDScript (gate lifted in b2dea555a, re-proved C++ v
  GDScript); the replay's re-run lost --headless/--fixed-fps/--path (6fa677a85); the lock test's atomic-claim race read a late start as
  two winners (37a9253c1; the lock itself is atomic); S v2 failed on the round's closest line (-0.40 se, judging.md round 43).
- **Later (not this round):** RtsControls.gate_width's scan in C++ (R43.11); a quiet builder0 window for N4's lint-fast before/after.
- **Questions for the lead:** none.

**REPORT (native, round 43, session 1, 2026-10-28 ~02:20; superseded by the final report above).**
- **N5 `make playtest-report RECORDING=<file> [HTML=<out.html>]`: 952d06a78** (on main e90421990). One report of his playtest: (a) the
  match and every order's arrivals (tools/recording_arrivals.py), (b) the camera at each hit and death (the `cam` rows, C43.2; a
  recording from before round 43 says it has none), (c) the replay's divergence over 30 s, all crews, with its verdict line.
  tools/test_playtest_report.sh 12/0. **Full check, first run: exited 2, not ours:** builder0's kernel OOM killer took all six test
  shards (pids 3056076-81, 140-385 MB RSS each, builder clock 01:46:46-01:48:24, then other Godots to 01:51) while the box was shared,
  and full-check-lock's atomic-claim race read 19/20 under that load. Every other target passed (perf-judge PASS 1.00x,
  playtest_report 12/0, lint 1259 parse, scenarios 54/0). **GREEN, to merge: 24744f2df** (N5 + the lock-test fix 37a9253c1 +
  Status): builder0 `>> remote: make check exited 0`, 3380 passed / 0 failed, 28 targets ALL JUDGED, sim-baseline unmoved,
  perf-judge PASS 1.00x (7441 us/tick), full-check-lock 22/0.
- **N3 third twin, parkaside (manoeuvre Bar S v2):** `pair/native-parkaside` f57dbb144 off manoeuvre's 04ddbcabb. The C++ drive
  called `_manoeuvre` back only on decision ticks, so a twin was needed: _park_aside's memo and cheap exits natively, the decision
  called back only when a still friend's disc holds the goal (exact: a superset of what _park_aside can find); ON keeps the C++
  drive (traffic.gd's gate lifted for it). **Final: 5b5a2c365** (the look reads the disc first: radius by hull id and a position,
  team and speed only for a hull whose disc holds the goal; Traffic's parsed `_off` read directly). builder2: native-proof EQUAL
  with `--traffic-on=parkaside` (86725536d09d2335), 129 passed / 0 failed (test_native_drive*, test_manoeuvre_parkaside now on
  the C++ drive, test_traffic*), test_native_drive_parkaside 2790 drives / 11 seats moved / 0 mismatches. **Cost** (his round-42
  match, 49 s, builder2 load ~1-3, the pair + main, ~22,000 drives at ~27 a tick, profiled): OFF 1.71 us a drive (~46 us a tick:
  the switch read); ON 16.70 us a drive (~0.45 ms a tick), of which 5.19 is the `_park_aside` callbacks (the first cut read 27.19).
  Without the pair, ON runs the whole GDScript drive. Merges at ship with Bar S v2.
- **FINDING (kturngoal):** its pair a907a541e twinned the C++ drive but left `kturngoal` in traffic.gd's GDScript-drive gate, so
  with kturngoal ON every match crew ran the GDScript drive and its native-proof EQUAL compared GDScript with GDScript (the twin
  tests were real: they call NativeDrive.drive directly). **b2dea555a** lifts it; builder2 native-proof EQUAL with
  `--traffic-on=kturngoal` (5cbf9970e14eb29c, now C++ v GDScript), 129 passed / 0 failed, 6 goal-moved ends. Lesson: a twin
  that a gate keeps out of the match is not proved by the match; lift the gate in the pair and say so.
- **Replay fix 6fa677a85:** Godot keeps `--headless`, `--fixed-fps 30` and `--path` out of OS.get_cmdline_args(), so the
  replay's re-run had none: it opened a window on the laptop and could not start on a builder (found running replay-match on
  builder2). ReplaySetup.reexec_args puts them back; test_replay_setup 8/0; his round-42 replay still PASS 10/10 for 20 s (laptop).
  **GREEN, to merge: 3bc207d16** (builder0 `>> remote: make check exited 0`, 3381 passed / 0 failed, 28 ALL JUDGED, perf-judge PASS 1.00x).
  Builder disk: the pair worktrees are removed after their proofs (lesson 337); the branches are kept.
- **Merged:** 95331c3cd = main 84f914f78 (R43.1); 2fd2e5d4e rode camera's d489eaa2b (main b31d3ddea); **CP43.0 409f70d66 GREEN**
  (builder0 `>> remote: make check exited 0`, 3352 passed / 0 failed, 28 targets ALL JUDGED, sim-baseline 53/0 unmoved, perf-judge
  PASS 1.00x) = main c57fc616b.
- **(merged in b840544de = main 5cb6b9802):** N2b memo 6afe991bb, REPLAY_SECONDS 82bbe3da8, the budget note 2383d9f94, the trace's
  command columns, lines_r43 c9f6aadde, the trig fix 45d5b28ce.
- **CP43.0, final:** his round-42 match replays EXACTLY: 49 s, both teams, 0.0 m for every unit at every census, the 18 deaths on the
  same ticks, Guns_1's turnaround AWAY 82 m as his. Round 41's on its own commit 21b20bdce: 5/5 crews 0.0 m for 20 s (bar PASS); on
  today's code it parts at 16 s (behaviour changed since round 41, real).
- **THE TRIG TRAP (the cause of both "open" items, now closed):** a Godot started by hand on the laptop (glibc 2.39) runs the system
  atan2f & co., 1 ulp off CORE-MATH; the native library carries CORE-MATH and make LD_PRELOADs the shim into every Godot it starts
  (native.md *Machine-independent trig*). His match ran through make; my lab replays did not, so (a) the "twin gap" (GDScript v native,
  a Syndicate crew's turn 1 ulp apart at tick 1, seen at tick 22) and (b) the "parting at ~28 s" were both the harness. With the shim:
  native ON v `--brains-off=native` bit-identical (0 of 12,420 trace lines: 36 units x 345 ticks, poses + drive commands), and the
  whole match exact. **No twin gap exists.** The replay now probes its own atan2f and re-runs itself with the shim
  (`REPLAY_TRIG_SHIM`), or says `REPLAY_TRIG_MISMATCH`. Builders (glibc 2.43) were never affected. Engage, manoeuvre told (CC
  orchestrator): any laptop Godot started by hand must go through make or carry the shim.
- **Later (not this round, R43.11):** RtsControls.gate_width's scan in C++ (the ~7 ms left of a 5-6 squad group click).
- **Merged since:** b840544de GREEN (builder0 `make check exited 0`, 3354/0, 28 ALL JUDGED, perf-judge 1.00x) = main 5cb6b9802.
- **GREEN, to merge: 1b6535335** (builder0 `>> remote: make check exited 0`, 3354 passed / 0 failed, 28 ALL JUDGED, perf-judge 1.00x;
  its own builder log ends `>> builder: make check exited 0`), remote.sh's builder-side log (tools/remote_log.sh: each remote run's output and its
  `>> builder: make <args> exited N` line in `~/tank_squad/remote-logs/<folder>-<target>-<stamp>.log`, the newest 300 kept; a dead
  laptop wrapper no longer loses a finished verdict; test_remote_log.sh 11/0; seen live on builder0). A lost session still stops its
  full check (full_check_lock.sh, round 39, unchanged); the log then ends with the lock's own line.
- **N3 twins (pairs; each stream told directly):**
  - **kturngoal (manoeuvre S3):** `pair/native-kturngoal` a907a541e off fed356a8b. builder2 `exited 0`, 12/0, native-proof EQUAL with
    `--traffic-on=kturngoal` (5cbf9970e14eb29c x3); the drive twin with the goal jumping ahead mid-leg: 1440 drives, 0 mismatches, 6
    goal-moved ends. **Superseded by b2dea555a** (the gate lift; see FINDING above). Rides manoeuvre's close as OFF code.
  - **A7 (engage `--engage-water`):** `pair/native-a7` 457effa1a off de626d7e1. decide_native's `obey` skips a contact across water;
    the water test natively (ElTerrain.leg_wet, synced once an _obey), the brain's seam through the GDScript. Laptop: seam case
    2400 / 0 (509 changed), Locks' canal 2400 / 0 (74 changed), decide twin 7536 / 0. **Cost** (his match, ENGAGE_WATER on, laptop):
    a per-contact callback was ~1.4 ms a tick (11,292 calls x ~185 us); native ~32 us a tick (upper bound). builder2 `exited 0`,
    15/0, native-proof EQUAL with `--engage-water=on` (4a04ea921011cd9a x3). **Landed** with A7 ON (R43.39, main aa9753028).
- **Done:** N1 (but N4 lint-fast quiet read: no quiet window), N2 / CP43.0, N2a, N2b, stretch `make replay-match`, N3 as asked (two
  pairs), N5. **N4:** lines_r43.py b40bd054b, 27 lines: Bar A (R43.18) 7, A6 (R43.20) 4, A6 v2 (R43.21) 5, A7 lines 1-9 (R43.23) 4, K5
  (R43.27) 7. Still to add as verdicts land: S, S5, K5 v2, A7 lines 10-11.
- **Questions for the lead:** none. **Note for the orchestrator:** while stopping my superseded tip check I killed two local
  `make remote T=check` process pairs by pattern (4146475/7 mine; 4154223/4 were **camera's** builder2 check wrapper, 26/27 done, ~1 hour
  lost). Since then I kill only a PID I recorded at launch and whose cwd I checked (worker contract section 7).

**N2a the 30-unit order hitch: G1 v9 ON (merge 09564e582, round 41).** builder2 (loads 2.4-3.6), GDScript path at every commit,
test_control_scale "ordering 30 units": 8952c3d64 10.90 ms / ratio 96.4; 63fec0c19 10.91 / 96.6; d8cb5c685 11.05 / 97.8; 04513fc92
10.81 / 95.7; a1af3ba9e (09564e582's parent) 10.90 / 95.6; **09564e582 313.19 / 2747.2**; 21b20bdce 312.57 / 2741.9; main 84f914f78
312.17 / 2714.5. Laptop, today's code: ON 248.94 / 2735.6 v `--group-g1=off` 8.26 / 96.1. Of G1's seven switches only
`--group-lay=off` removes it (9.40 ms). **In player terms (corrected):** the test's army is 6 squads, past any side's cap; at his
laptop's 4 squads the click cost ~8 ms more, at the desktop's 5 ~40 ms: a frame or two, never the 0.25 s I first wrote.

**N2b (R43.11, GRANT: G1 pack cost path; done, GDScript only).** Profile (laptop, temporary lap timers): `untangle_whole` 247.5 of
260 ms (a 6-squad column: 720 permutations x 15 pairs x 25 segment tests); `column_lay` 8.0 (one gate_width); ground_cap 0.41.
6afe991bb: crossings memoised per (squad, place, squad, place), drives precomputed and summed in the same order, permutations built
once per n, a permutation that cannot win stops counting once past the best. **Identity:** tests/test_untangle_whole_memo.gd (the
function as it stood, verbatim, v the new one on 1,500 seeded knots: same places, return and counters on every one).
Laptop: 30 units / 6 squads 249.2 ms 2738.8 -> 20.19 ms 232.1; 25 / 5 squads 13.39 ms 155.7; **20 / 4 squads (his laptop) 6.50 ms
78.3, in budget**. The budget number is unchanged; its comment says it is judged at the caps (R43.11).
**Merge notes (GRANT lines):** game/control/selection_squads.gd `untangle_whole`'s permutation loop, `_permutations` /
`_build_permutations` / `_perms_memo`; tests/test_control_scale.gd comment only.

**N2 CP43.0: why the probe diverged, each cause removed and measured** (laptop flightdeck, `tests/replay/divergence.py`: per crew per
census second, replay v his census; bar 3 m, first two orders' crews, 20 s):
1. `--squad-cap`: headless = the desktop's 5 squads / 45 units v his laptop's 4 / 20 (the CPU's counter-lineup then deals another
   army). Fixed: cap and factions from the header (C43.2 keys) or the old roster.
2. `--no-control` in the probe removed skirmish's control-point objectives (the CPU aimed at its fallback `spawn * 0.75`). Removed.
3. **THE BIG ONE: wrong arena.** `Arena._ready` (and every `--<switch>`) reads `LaunchFlags.from_environment()` (the process command
   line), not `Main.next_flags`, so `--arena=locks` never arrived: every replay ran on **foundry** (same spawn spots). Fixed in the
   replay (no arena.gd change): it re-runs itself once with the match's switches on its own command line (`REPLAY_REEXEC`).
4. His planning-pause orders now land in the pause, before the CPU's first plan.
   -> his round-42 match 0.0 m to 10 s in a hand-started laptop run (the parting after it was the trig trap, item 8).
5. **The native library + make's trig** (the build he played, through make): **every unit 0.0 m for 20 s: bar PASS (10/10 crews)**;
   with the trig shim the whole 49 s match is exact (item 8); the GDScript path is the same match bit for bit.
6. **Round 41's recording (`references/round42/engage/`, seed 49326): an UNRECORDED INPUT.** A formation pick (G / Shift+G / the
   panel, `RtsControls.set_formation`) re-tasks the selected squads without `command_issued`, so the recording never held it: he put
   Hunters, Spears and Spears2 in **column** in the planning pause. The replay now infers those picks from the task rows
   (`_give_formation`'s exact task shape) and issues each before the first order naming its squad (element creation order matters).
   -> on today's code 0.0 m for 12 s; **on its own commit 21b20bdce (+ its library, scratch worktree): 0.0 m for 20 s, bar PASS
   (5/5 crews)**. On today's code it parts at 13 s: behaviour changed since round 41 (that is a real difference, not the replay's).
   The recorder now writes a pick as an `order` row with verb `formation` (C43.2, additive), so the next playtest holds it.
7. One click over several squads is written as one row per squad (same tick, verb, target); replayed as separate one-squad orders it
   is a different order (his tick-806 attack on Rust_Hunters_4: the parting at ~28 s). The replay merges them back (`merge_clicks`).
8. **The trig shim** (see the REPORT): a laptop Godot started by hand runs glibc 2.39's atan2f, 1 ulp off the CORE-MATH make
   preloads and the native library carries. With it: 49 s, both teams, 0.0 m, all 18 deaths on the same ticks; the replay shims
   itself now (`REPLAY_TRIG_SHIM`).
- **What a replay needs (and now has):** the native state he ran (`native` key; `REPLAY_NATIVE_MISMATCH` warns), the cap, factions,
  switches (`flags`), unrounded spawn, the pause, formation picks. **Not yet held:** a garage army saved under his `user://`
  (the match keeps no doctrine; `REPLAY_ROSTER_MISMATCH` says so instead of diverging silently).

**Requests / notes for others:** engage + manoeuvre: replay with `make native` built; never trust a pre-fix replay (foundry).
Shared-code findings (not mine): (a) `Arena._ready` reads the process command line, not Main.next_flags (a garage FIGHT's flags
reach the arena only via the picker's next.values): fine in play, a trap for every harness; (b) `set_formation` emits no
`command_issued` (worked around in the recorder via `formation_changed`).

**Questions for the lead:** none.
