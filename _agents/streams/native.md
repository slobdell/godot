# Stream: native (every pair; the judging table complete; planner's paths this round)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 35** (C35.1, C35.9),
> your round-34 brief `streams/archive/round34/native.md` and planner's `streams/archive/round34/planner.md` (both close-outs).
> **You own:** `native/**`, `mk/native.mk`, `exec_fields.h`, the twins, and this round planner's paths: `game/ai/planner/**`,
> `native/src/planner_*`, `tests/planner/**`, `tests/test_planner*.gd`, `mk/planner.mk`, `tools/judge/**`.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Nothing alone: native keeps every C++ change a twin of its GDScript, so the game stays fast on his laptop and the two paths agree.

## Where things stand

- **Shipped in round 34:** C34.7 the dropped-peer shell RPC, C34.8 (a) PIN_FPS everywhere + the moves list, N4 NativeExpect.absent,
  N5 the yield floors, N6 web-smoke with no desktop.
- **Unmerged on purpose:** the underfire mirrors (`badfdb978`, T6b parked), parkedroom v4m, the T4 ghost twins. The c339 stop
  hand-back rides the M0 merge (C35.3). `round34/native` carries inert underfire C++ (e1bd2453b, 979c3fa5b, 15b1523da): don't merge
  that branch as a whole; take commits.

## Backlog (in order)

1. **N1 Pairs, as they come:** orders' deploy step ON (D1, check whether any C++ reads the halt seats; likely none), manoeuvre's
   wedged-death rule (W1, the drive), traffic's T7 (rebuild the underfire mirror with the new gate), CP-F 5 if it reaches C++.
2. **N2 Planner's leftovers (C35.9):** delete FACE_KEEP_FAR (R34.5); the judging table's owed rows (round 31 brains, round 32, the
   round 31–34 inventory lines; `python3 tools/judge/inventory.py` and `table.py`); make every series tool drop random-seed twins
   (`tools/judge/seed_twins.py`).
3. **Stretch:** the watch item from R34.16 (one 9.1 m both-planned face) if a face_pairs series runs.

## How to verify

`make quick-remote`; `make native check` for a named hash, one at a time on builder0; tools tests on the laptop.

## Don't touch

Gameplay GDScript outside planner's paths, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Round 35 (started 2026-10-19 from main `a0ae0aafd`, which inherits c29a8c7b6's green check; main 0f4d528d7 merged in)

**Plan (in order):** N2 first (nothing had arrived for N1 at launch), with N1 pairs pre-empting as they come; then the stretch.
1. N2 (a) FACE_KEEP_FAR deleted. (b) seed twins dropped by the series tools. (c) The judging table's owed rows. Then one full check.
2. N1 pairs: orders' D1 (statement), manoeuvre's W1/W2 (the face settle: mirror when its bar passes), traffic's T7 (the
   underfire mirror rebuilt with its pass-lane gate), CP-F 5 if it reaches C++.
3. Stretch: R34.16's watch item when a face_pairs series runs.

**REPORT (2026-10-19 evening; every number builder0 unless said; the light lane is `tools/remote.sh --light`).**

**On main (merged by the orchestrator):**
- **N2 (C35.9) planner's leftovers**, main c32606204. Green hash `2f7683d21`: builder0 `make check exited 0`, 2885/0, 27 ALL
  JUDGED, sim-baseline 13 unmoved.
  - FACE_KEEP_FAR deleted (`da93c3fea`).
  - seed_twins.filter_logs (`8f29bff5a`): a series folder's `random-<seed>.log` is dropped when the map it was dealt has its
    own `<map>-<seed>.log` there. far_table.py calls it.
  - The judging table's owed rows (`339465130`): rounds 31–34 in the inventory (`tools/judge/lines_r31_34.py`, 185 lines),
    round 31/32 pairs pooled, re-rendered (judging.md *Round 35 re-render*, `references/round35/native/sizing/`).
  - tools/judge's tests are in `planner-pytest`.
- **N3 (R35.15) a source change always rebuilds**, main fc1f4ac0e. Green hash `944ad8c9b`: builder0 `make check exited 0`,
  2885/0, 25 + 2 NOT JUDGED (load), sim-baseline unmoved.
  - What it fixed: a remote run had built native from the pre-merge tree. The merge then arrived by rsync with OLDER mtimes,
    and cmake rebuilt nothing.
  - The fix: `native/src_sync.sh` touches every source whose sha256 differs from the last successful build's sums. No
    record, or a removed file, touches all of them.
  - Reproduced on builder0: a header changed at a 2000 mtime → `src-sync: 1 changed ... touched`. Test:
    `tools/test_native_src_sync.sh` (10).
- **tools/builder_checks.sh** (`467f3073c`) and the slot-exclusive light-lane test fix (`44d06cbbe`), main eea6fb9fa (light
  `shell-tools-test exited 0`, 25 suites).
  - builder_checks counts builder0's full checks in every form: `--wait-below 2` launches behind them.
  - My first launcher's pgrep missed `make native check`, so a third check started on the box.
  - The light-lane slot-exclusive 13 fails were the suite inheriting TANK_SQUAD_LIGHT, not load. I first read them as load
    and corrected that with a reproduction.

**Pairs (C31.2), each with its twins green; merges are the owners' bars' and the orchestrator's:**
- **T7 (traffic, underfire pass lane): `pair/native-t7` `21e5d69e4`** = traffic 95cc04a04 + my T6b mirror (e1bd2453b /
  979c3fa5b / 15b1523da, re-cut) + the T7 mirror. test_native_yield 10/0, 0 mismatches.
  - A new pass stage reaches: refusals 3, passes 2, done 2, holds 2. The rank stage forces passes (live / timeout / done).
  - `_pass_lane` (and its sweep) is a GDScript call from C++ (R35.8). Port it only if T7 ships.
- **W1b (manoeuvre, wheeled pace-0 halt): `pair/native-w1b` `f4f6bf1d2`.** native twins 107/0 halt OFF (423 asks a hold stage,
  floor >= 100). On lab 1d2f0cac9, halt ON: 107/0, 1094 halts a stage, 0 mismatches. Merges on W1b's bar (the orchestrator).
- **W1c + T9 (one joint pair, R35.14): `pair/native-w1c-t9`** = lab/w1c-t9 878200ede + traffic f432645dd + pair/native-t7 +
  pair/native-w1b + T9's mirror (end_yield's gate, yield_unfinished, 3 exec rows) + W1c's (stall_throttle, against_friend
  in unstick).
  - Twins at `2446d46f9`: 111/0, 0 mismatches.
  - W1c ON (lab): every twin 0 mismatches, but Sumps reaches no parked refusal and no plain refused ask. So floors moved
    (C34.6): the Sumps pair is floored only with W1c off, and the parked refusal on the under-fire stages (4 both arms).
  - A forced plain-refusal stage (5 Sumps poses from a sweep of ask; the orchestrator's request): **green hash
    `6177ee87a`**, test_native_yield 12/0 on it and on lab `c8db0a442` (W1c ON): asks_refused 5/5 live and owned,
    0 mismatches.
  - **R35.39 (manoeuvre's scope predicate):** against_friend skips a squadmate of the crew's own element
    (Manoeuvre._same_element called). **Current pair hash `7372e6118`:** 14/0 on test_native_drive, traffic_hold and
    manoeuvre's stall_intent, W1c ON and OFF, 0 mismatches. With W1c ON the hold stage's intent ticks go 8 → 0 (own
    squadmates); the drive fight's 49 stay.
  - **R35.19:** this pair merges only after T7's verdict (if T7 parks, it is re-cut without T6b/T7 and re-twinned).
- **Joint W1c+T9 re-cut on main (R35.53): `pair/native-joint3` `7a1435cdd`.**
  - The base is manoeuvre's lab/joint3 813f6e1ff: main 5f05c997c + stream/manoeuvre + T9 cherry-picked, W1b's mirror out.
  - Twins, builder0 light: both arms green, 35/0 + 14/0, 0 mismatches.
  - With yieldfit2 ON, the under-fire stage's give-ways rise (66 v 39), natively beside T7's pass lane at 0 mismatches.
  - It supersedes pair/native-w1c-t9 / -main for the joint series; manoeuvre cuts joint3 from it.
- **R35.62: W1b's and W1c's mirrors on main as inert code: stream/native `44b2e04b5`** (main ed121d24f merged in).
  - W1b's mirror is from pair/native-w1b. W1c's (stall_throttle, against_friend / same_element, R35.39's element skip) is
    from pair/native-joint3, byte-identical to it. T9's half (yield_unfinished, the `_unfinished_*` exec rows, T9's floors) is
    left out.
  - STALL_INTENT_DEFAULT and WHEEL_HALT_DEFAULT stay false.
  - Twins, builder0 light, ON arm lab/native-inert-on 567466f85 (both true) and OFF arm 44b2e04b5:
    - yield + exec_state + pass_lane: 18/0 both arms;
    - drive + traffic_hold + stall_intent + wheel_halt: 15/0 both arms;
    - 0 mismatches. ON: stall ticks 49, wheel halts 1044 of 1044 asks. OFF: 0, and 0 of 423.
  - **Full check green: `44b2e04b5` on builder2**, `make native check exited 0`, 2953 passed / 0 failed, sim-baseline 13
    unmoved, 25 passed + 2 NOT JUDGED (perf-judge and scenario_perf, the box loaded 2.0x / 3.7x), 1827 s.
  - joint3's merge later is T9's half plus the flips.
- **D1 (orders' deploy step):** no native change (statement to the orchestrator).
- **CP-F 5 / M5 (the orchestrator's question): W2's face settle and turnhull run on the native path, as GDScript, not
  bypassed** (lab/cpf5 63336d690).
  - A wheeled hull's `face` order hands its execute step back (execute_native.cpp ~363–378).
  - face_turn's only caller is that branch.
  - turnhull's lift is in TankBrain._order_move (no C++ port; only `decide` is native).
  - Native cell on builder0 light (new_drawn, seed 460, gangs + law, 12 runs, a scratch counters() line): face_settles 27,
    face_settle_fails 93, hull_turns 17535; execute_counts face hand-backs 205912, other_order 0.
  - Found: face_settles / face_settle_fails were not in ManoeuvreCensus.counters(). Manoeuvre adds them (orchestrator).

**E4b traced (R35.54; laptop, GDScript, main 5f05c997c, trace only):** test_tactics_scenarios_6's first-in-process v later
difference is not a script field and not the runner's teardown.
- **Ruled out:**
  - Script statics: all 815 `static var`s are identical first v after.
  - The teardown and drain_navigation: a 0-frame earlier test keeps the alone value 4.8.
  - Frame phase: waits of 1 / 2 / 3 / 4 / 97 frames all give 3.0.
  - The nav map's first sync: `map_force_update` alone gives 4.8.
- **What flips it:** one main-loop iteration before the setup. It is engine-side state set by the first iteration (likely the
  physics space's first step, or the before-the-main-loop setup context).
- **Real play** starts long after launch, so it matches the later tests. Brains' one-frame warm-up in run_tests.gd is the right fix.

**Round-36 note (R35.47: tests that spawn a tank, then set `global_position` by hand; native's 13 of brains' 85; read only, no
code):** a bare `global_position =` leaves the physics body at its Match spawn slot until a step, and how a stale overlap resolves
depends on process history (the first match in a process syncs without a push, a later one pushes). The native twins compare the
GDScript and C++ paths on ONE snapshot, so an overlap can move the sample but never the equality verdict; the risk is a FLOOR or
coverage count that moves with what ran before.
- **Can overlap, and a floor reads the stepped stage (fix in round 36: `Tank.place`, or a fresh child):**
  - `test_native_avoid_gather`: random ±30 m poses, stepped every tick; floors on compared / still / real-velocity rows.
  - `test_native_record`: 6 m spacing beside the spawn slots, 20 frames stepped; floors on routes and neighbours.
- **Can overlap, but already order-proof** (every stage in its own child process, FreshStage, round 33):
  - `native/drive_twin_case.gd` (test_native_drive*, the k-turn stage's mid-stage teleport then one frame).
  - `native/gate_twin_case.gd` (test_native_gate*, 7 x 8 m grid at x -30 beside the slots; its floors moved with shard order
    before the fresh-process fix).
  - Converting them to `place` is still cleaner, low priority.
- **Harmless** (a snapshot read, with no floor that depends on contact physics after the teleport, or none of the bodies within
  a hull of another's slot):
  - test_native_incoming, test_native_combat, test_native_threat, test_native_scan, test_native_route.
  - test_native_tick_profile (counts ticks only), test_native_movement_geometry (navmesh queries).
  - test_native_perception (rays may read stale bodies, the same in both arms).
  - test_native_shell (waits a frame "so the bodies are where the rays look").
- Native's round-35 stages (test_native_yield's pass and refusal stages, test_native_pass_lane) already use `Tank.place`.

**Round-36 candidates (native):**
1. **Mirrors waiting on their owners' bars:**
   - W2's face settle, if it ever reaches C++: today it is GDScript on the native path by design (face hand-back).
   - W1b: `pair/native-w1b` `f4f6bf1d2`, rebased on the merge base when W1b returns.
   - The joint W1c+T9: `pair/native-joint3` `7a1435cdd`.
2. **The R35.47 note's two fixes:** test_native_avoid_gather and test_native_record to `Tank.place` (or a fresh child);
   the drive / gate twin harnesses to `place` as cleanup.
3. **E4b below the main loop (optional, R35.57):** name the engine state the first iteration sets (physics space's first
   step v the setup context): a minimal two-body repro, with or without one stepped frame.
4. **The census gap pattern:** a counter added to a rule but not to ManoeuvreCensus.counters() / a series reader. Propose a
   lint-style test that every `static var` counter named in a bar appears in the series' printed line.
5. **R34.16's watch item** (one 9.1 m both-planned face) when a face_pairs series next runs.
6. **The traffic series readers' seed_twins call** (requested; traffic queued it after T7's series).

**Requests to other streams:** traffic, relayed after T7's series: any series reader that pools a folder containing random-arena
fights calls `seed_twins.filter_logs(files)` first.

**Merge notes:** `tests/traffic/far_table.py` (traffic's: one import + one call, merged with N2).

- **T7's `_pass_lane` in C++ (R35.8's follow-up; T7 shipped, R35.44): stream/native `f75273624`.** pass_lane,
  pass_wheels_ok, pass_clear and pass_swept run natively, line by line (they were a GDScript call while T7 was judged).
  - New twin test_native_pass_lane: 576 poses (yard_open + Sumps, 4 hull kinds), 0 mismatches, 259 lanes / 317 none.
  - test_native_yield's pass stage reads as before; 12/0 on builder0 light.
  - Merges on a full check (asked the orchestrator for the go, R35.36).

**Next:** the pass-lane port's full check (on the orchestrator's go); W2's mirror when its bar passes.

**Questions for the lead:** none. **Known issues:** none.
