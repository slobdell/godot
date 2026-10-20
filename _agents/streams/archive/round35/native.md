> **ARCHIVED (round 35 closed 2026-10-20).** The branch is `round35/native`; its unmerged references (`references/round35/` or `_agents/streams/references/round35/`) stay on that branch. Round 36's brief is `streams/native.md` where one exists.

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
4. **Round 35 extension X5 (2026-10-20, the lead away for the day; workstreams.md):**
   - (d) Mirrors as asked, first: the joint W1c + T9 hand-over's twins (manoeuvre's pair/joint-ship d56685115).
   - (a) **The round scoreboard** (his concern: "ensure that we're also generally making concrete progress"). A fixed workload
     (fights on fixed arenas x fixed seeds, plus the orders probe's click / route cells) runs on builder2 against each main the
     orchestrator names. It prints the player-facing numbers into one table across mains: deaths by cause incl. stuck / jam,
     crews left behind, never-settled, all-in times, far bank, twitch. Rendered to `references/scoreboard/`, readable in player
     terms. First rows: round 34's close c29a8c7b6, round 35's launch a0ae0aafd, and today's main.
   - (b) The copy-back leak (stale `build/` rows from earlier runs reaching a series folder): fix it in tools/remote.sh
     (granted), with a test.
   - (c) R35.47's two Tank.place fixes: test_native_avoid_gather and test_native_record.

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

**FINAL REPORT, round 35 (2026-10-20). Every number is builder0 unless it says otherwise. The light lane is
`tools/remote.sh --light`. The perf-judge alone on a quiet builder0 is owed for the whole round's main; it goes in the
orchestrator's close.**

**Shipped (on main, merged by the orchestrator):**
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
  - `native/src_sync.sh` touches every source whose sha256 differs from the last successful build's sums. No record, or a
    removed file, touches all of them.
  - It fixes an rsync of a merge carrying OLDER mtimes, after which cmake rebuilt nothing. Test:
    `tools/test_native_src_sync.sh` (10).
- **tools/builder_checks.sh** (`467f3073c`) and the slot-exclusive light-lane test fix (`44d06cbbe`), main eea6fb9fa (light
  `shell-tools-test exited 0`, 25 suites).
  - builder_checks.sh counts builder0's full checks in every form. `--wait-below 2` launches behind them (R35.36).
  - The 13 slot-exclusive fails were the suite inheriting TANK_SQUAD_LIGHT, not load.
- **T7's `_pass_lane` in C++** (R35.8's follow-up, after T7 shipped at R35.44), main 214e444ef. Green hash `8f7c8a1f5`:
  builder2 `make native check exited 0`, 2910/0, sim-baseline 13 unmoved.
  - pass_lane, pass_wheels_ok, pass_clear and pass_swept run natively, line by line.
  - New twin test_native_pass_lane: 576 poses (yard_open + Sumps, 4 hull kinds), 0 mismatches, 259 lanes / 317 none.
- **W1b's and W1c's mirrors as inert code (R35.62)**, main 9336ea5f8. Green hash `44b2e04b5`: builder2 `make native check
  exited 0`, 2953/0, sim-baseline 13 unmoved, 25 + 2 NOT JUDGED (perf-judge 2.0x, scenario_perf 3.7x: load), 1827 s.
  - W1c's code is byte-identical to pair/native-joint3. T9's half is out. STALL_INTENT_DEFAULT and WHEEL_HALT_DEFAULT stay
    false.
  - Twins, builder0 light, ON arm lab/native-inert-on 567466f85 and OFF arm 44b2e04b5: 18/0 + 15/0 in both arms, 0
    mismatches. ON: stall ticks 49, wheel halts 1044 of 1044 asks. OFF: 0, and 0 of 423.

**Mirrors (C31.2 pairs, each with its twins green):**
- **T7 (traffic, under-fire pass lane): `pair/native-t7` `21e5d69e4`.** Merged with T7, then natively ported (above).
  - test_native_yield 10/0, 0 mismatches.
  - A dedicated pass stage reaches refusals 3, passes 2, done 2, holds 2.
- **W1b (manoeuvre, wheeled pace-0 halt): `pair/native-w1b` `f4f6bf1d2`.** On main inert (above). Twins 107/0 both arms.
  - The halt switch on lab 1d2f0cac9 gave 1094 halts a stage, 0 mismatches.
- **Joint W1c+T9 (R35.14 / R35.53): `pair/native-joint3` `7a1435cdd`.** Base: manoeuvre's lab/joint3 813f6e1ff. Both arms
  green, 35/0 + 14/0, 0 mismatches.
  - W1c's half is already on main (inert). The joint merge is T9's half plus the flips. T9's half is yield_unfinished, the
    `_unfinished_*` exec rows before pass_offer, and T9's UNDERFIRE_FLOORS keys. Manoeuvre was told the commits.
  - It also carries R35.39's element skip (against_friend skips the crew's own element via Manoeuvre._same_element).
  - It also carries the forced plain-refusal stage (5 Sumps poses, asks_refused 5/5 live and owned).
  - The superseded joint pairs: pair/native-w1c-t9 `7372e6118` / -main `e2fe62c9a`.
- **D1 (orders' deploy step):** no native change.

**Traces:**
- **CP-F 5 / M5: W2's face settle and turnhull run on the native path, as GDScript, not bypassed** (lab/cpf5 63336d690).
  - A wheeled hull's `face` order hands its execute step back (execute_native.cpp ~363–378). face_turn's only caller is that
    branch.
  - turnhull's lift is in TankBrain._order_move, which has no C++ port.
  - Native cell on builder0 light (new_drawn, seed 460, gangs + law, 12 runs): face_settles 27, face_settle_fails 93,
    hull_turns 17535; face hand-backs 205912, other_order 0.
  - face_settles / face_settle_fails were missing from ManoeuvreCensus.counters(). Manoeuvre adds them.

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
1. **The joint W1c+T9's remaining half** (`pair/native-joint3` `7a1435cdd`): T9's mirror plus the flips, on the joint
   verdict.
2. **W2's face settle in C++**, if it ever leaves the face hand-back (today it is GDScript on the native path by design).
3. **The R35.47 note's two fixes:** test_native_avoid_gather and test_native_record move to `Tank.place` (or a fresh child).
   The drive / gate twin harnesses move to `place` as cleanup.
4. **E4b below the main loop (optional, R35.57):** name the engine state the first iteration sets (the physics space's first
   step, or the setup context). A minimal two-body repro, with or without one stepped frame.
5. **The census gap pattern:** a counter added to a rule but not to ManoeuvreCensus.counters() or a series reader. Propose a
   lint-style test: every `static var` counter named in a bar appears in the series' printed line.
6. **R34.16's watch item** (one 9.1 m both-planned face) when a face_pairs series next runs. The stretch was not reached this
   round: no face_pairs series ran.
7. **The traffic series readers' seed_twins call** (requested; traffic queued it after T7's series).

**Requests to other streams:** traffic: any series reader that pools a folder containing random-arena fights calls
`seed_twins.filter_logs(files)` first.

**Merge notes:** `tests/traffic/far_table.py` (traffic's: one import + one call, merged with N2).

**Next:** stand by. Round 35's backlog is complete. N1's remaining pair (T9's half of joint3) waits on the joint verdict.

**Questions for the lead:** none. **Known issues:** none.
