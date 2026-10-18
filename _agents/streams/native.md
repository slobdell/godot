# Stream: native (every pair; N5's held ports once traffic's far-loop design settles)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (*N7*, *Stage 1*), `_agents/workstreams.md`
> **Round 33** (C33.2, C33.8; C31.1, C31.2, R31.1 and its addendum stand), and your round-32 brief
> `streams/archive/round32/native.md` (the pairs, the twin splits and their lesson, the swap pair's assessment, N5's hold).
> **You own:** `native/**` (outside the planner's `planner_*`, which you review), `game/ai/native/**`, `tests/native/**`,
> `tests/test_native*.gd`, `mk/native.mk`, `mk/pace.mk`, `brain_switches.gd` (others add one switch line: merge note),
> `cover_map.gd`, `incoming_fire.gd`'s seam, `think_quiet.gd`, the seams on main, `exec_fields.h`, the planner's build glue;
> plus the stage-1 grants (the seam at the top of `OrderController.compute_command`; `Movement`'s and `Gunnery`'s member
> STORAGE; `traffic.gd` for its port; `wall_contact.gd`'s observer). You review every planner C++ commit for fidelity before
> it is pushed. **Model:** Opus.

## The lead's direction

Round 26: core components in C++ (stage 1 ON 2026-10-12), even without a gain, with an equal answer; stage 2 deferred (his
call). Nothing he plays changes because of this stream alone; every behaviour he sees ships as a pair with its owner.

## Where things stand (main at the round-33 docs commit; inherits `0c124cf7`'s green check: builder0 exited 0, 2724/0)

- Round 32: every pair shipped (T3b-c, T1c-b2 "none ported", H1b), the four twin files split (CPU seconds roughly halved
  per file), two order-dependent twin reds fixed. The swap pair (`pair/swap-ship`) did not merge: the swap is parked.
- **N5's held ports** (`_negotiate`'s body / ask / `_begin_yield`, `_manoeuvre`) stay HELD until traffic's CP-X design is
  written (C33.2 (2)): it will likely change exactly those.
- `test_native_face_behind` compared 0 native executes in round 32 (vacuous): check whether a floor landed; if not, add one.
- Your round-32 branch is `round32/native` (merged).

## Backlog (in order; pairs pre-empt your own work, C31.2)

1. **The face_behind floor** (if missing): a native-execute floor so the twin cannot pass vacuously; test-only; name the hash.
2. **Pairs as they arrive:** manoeuvre's F0/CP-F (the face at rest touches the drive and the executor), brains' R1 (likely
   none ported: say so), B10b, B11b and B5c-v6 (the side-gate mirror on `pair/brains-v6-carry`), planner's CP-Q and
   face-behind budget (review its C++), traffic's CP-X. Each: mirror, twins at 0, the pair tree with the switch ON, plain
   check, named hash. Under `NATIVE=off`, `native-live-guard` fails by construction (R31.1 addendum).
3. **N5's held ports**, once CP-X's design is written in traffic's brief (the orchestrator tells you): each a pair with its
   own switch, proofs and price.
4. **Stretch:** the slowest remaining twin files (`tests/shard_times.txt`), split by frame where a floor is a branch
   (your round-32 lesson), measured as CPU seconds.

## How to verify

`make remote T=check` and `make remote T=check NATIVE=off` where a port changes; `make native test FILTER=...` for twins
(`tools/remote.sh --light native test 'FILTER=a|b'` when FILTER has `|`); `native-verify-scenarios`, `native-proof`;
determinism and the thirteen lines unmoved unless a pair moves them on purpose. A waiter greps `>> remote: make.* exited`.
Long remote runs under `systemd-run --user`. Every number: commit, machine, workload, n.

## Don't touch

Brains' think side (`tank_brain.gd` outside your seams, `game/tactics/**`, elements); manoeuvre's drive body and executor
logic (you mirror, they own); traffic's give-way logic; the planner's GDScript; `game/control/**`, `game/camera/**`,
`game/match/**`; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Round 33 (started 2026-10-17 from main `ae3dad71`, which inherits `0c124cf7`'s green check)

**Plan (in order):** (1) the face_behind floor: check whether one landed (read the file on main, then one builder0 light
run for the counts); add one only if missing. (2) Pairs as they arrive (C31.2: they pre-empt everything): manoeuvre's F0 /
CP-F, brains' R1 / B10b / B11b / B5c-v6 (the carry `pair/brains-v6-carry` `ba8d18d9` still needs `MoverState.world_reset()`
first in `test_native_gate`, round 32's open note: added when brains sends its tested diff, onto then-current main),
planner's CP-Q and face-behind budget (review its C++), traffic's CP-X. (3) N5's held ports after CP-X's design is written.
(4) Stretch: the slowest twin files by CPU seconds.
**1. The face_behind floor: ALREADY ON MAIN, no new code.** `test_native_face_behind` (`1ca9988f`, round 32) asserts
`native >= 100` on the tracked tank (the native face, compared both views) and, for the War Rig, `native == 0` BY DESIGN
(`simple_face` hands a wheeled face turn back) with `handed_back >= 400`. Round 32's "0 native" was the War Rig's case,
which is the hand-back proof, not a vacuous twin. Measured at `ae3dad71`, builder0 light lane, `make native test
FILTER=native_face_behind`, n 1: `exited 0`, 2 passed / 0 failed; tank 142 native executes, 2 handed back, 0 mismatches
(aligned 2.37 s); War Rig 0 native, 928 handed back writing nothing, 0 mismatches (GDScript legs 3, drift 1.5 m, aligned
15.43 s). The War Rig's case becomes a native-execute floor when the k-turn / `_manoeuvre` port lands (N5).
**R33.3 (PlannerSeam.live staleness, planner's main-bug fix), pre-assessed:** the C++ drive mirrors `live()` INLINE
(`drive_native.cpp:280` `seam_live()`: reads `_crews`, calls `live()` back only for a freed hull; gates the native unstick
~1449 and the `_planned_reverse` open ~2211; `manoeuvring()` is not ported). A release from `_crews` where the cutting
order lands needs no mirror (recommended to planner); a check inside `live()` needs one in `seam_live()`. Sent to the
orchestrator and planner; confirm with the twins on planner's commit. **Orchestrator (main `b80fb7a0`, R33.3 amended):**
planner releases the stale crew from `_crews` where the order is replaced, `live()` stays a lookup, no C++ change expected;
native confirms with the k-turn / execute twins on planner's pair tree when it names the hash.
**R33.3 pair: planner `fix/planner-live-stale` `03d1a50c` REVIEWED, APPROVED, NONE PORTED (answer (a)).** `tick_seen` is
written only in `take` / `hold`, which the C++ drive reaches only through GDScript callbacks (`_planned_reverse`,
drive_native.cpp ~2214), and `_release_stale` runs on `SceneTree.physics_frame`, between ticks, so both twin arms see the
same `_crews`. Twins on `03d1a50c` (worktree `../godot-native-pair`, branch `pair/r333-live-stale`), builder0 light,
`make native test FILTER=native_drive|native_execute|native_face_behind|planner_seam_stale`, n 1: `exited 0`, 10 passed /
0 failed, every twin 0 mismatches (drive 2160 a view, live and owned; k-turn 1440 drives / 5 plans, unstick 7200; execute
5880 + 6000 native; face_behind tank 142 native, rig 928 hand-backs; seam_stale released 2 ticks after `stop`). Sent to
planner and the orchestrator; planner's full check is the ship gate. **Planner's ship hash `1b5c69df`** (`03d1a50c` plus
its test disposing the match; seam code identical): planner reports builder0 `make check exited 0`, 2725 / 0,
sim-baseline unmoved. Nothing for native to re-run (the seam code the twins read is unchanged). Planner's CP-Q pair
(QUEUE_DEFAULT true) comes to native for C++ review after that merge. Merged as main `b122cf60` (orchestrator). Main moved
while N5.M's check ran on `145ada3a`; the orchestrator runs `tools/merge_check_needed.sh` on the verdict to rule whether
it inherits.
**CP-F pair `887ac6d2` (manoeuvre `pair/cpf-on`: main 227d0bb6 + R33.9 429ebc4b + manoeuvre e5c66718 + TURN_HULL_DEFAULT
true), twins GREEN, no C++ change.** The diff adds Manoeuvre.drawn_direction's station fallback and Orders._remember_station's
`drawn` field; the C++ reads neither (feed_native takes a station as a point only). builder0 light, worktree
`../godot-native-pair` detached at 887ac6d2, `make native test FILTER=native_drive|native_execute|native_face_behind
exited 0`, 9 / 0, n 1. Every twin had 0 mismatches:
- drive 2160 a view (live and owned); k-turn 1440 + 1440; unstick 7200;
- execute 5880 + 120 handed back, and 6000;
- face_behind: War Rig 928 handed back; tank 142 native / 2 handed back.
Sent to manoeuvre and the orchestrator.
**Stretch: the k-turn twin split, `26a35318` (test-only).** `_unstick_compare` compares a mover on frames where
`(frame + mover) % 2 == part`; test_native_drive_kturn = drive compare + part 0, test_native_drive_kturn_odd = part 1 (no
drive compare). Draws are made for every pair in their old order (rng also places the k-turns), so the fight is unchanged.
builder0 light, n 1: both halves 5 plans / 206 leg ticks (before: the same); unstick 3600 + 3600 (before 7200), 1:fired 164
+ 164 (328), 4:fired 44 + 46 (90); 0 mismatches; 3/0 with the owned file. CPU before (`6f88a2e5`, load ~3, serial):
kturn 166.4 CPU-s, kturn_owned 34.2. A first after-reading (load 12-18: kturn 218.6, odd 148.5) is contaminated, NOT
evidence; the interleaved ABAB was CANCELLED unrun (it queued 38 min for a heavy slot behind two full checks; it would
have held one ~40 min for a stretch number). **The split's CPU gain is unmeasured**; re-measure on a quiet builder0.
**3. N5's held ports.** R33.4 (orchestrator, main `404f1e37`): traffic's CP-X design is `parkedroom`, GDScript-only, and
changes `_begin_yield`'s body, so `_negotiate` / `ask` / `_begin_yield` stay HELD for its verdict; `_manoeuvre` released.
Manoeuvre confirmed CP-F does not touch `_manoeuvre`'s decision path.
**N5.M, `_manoeuvre`'s decision in C++: `04ee782e` + `.uid` `145ada3a`** (design first: `native.md` *N5.M*).
`BrainSwitches.native_manoeuvre` (default ON; off = the round-26 callback). Proof (builder0 light, lab `536f773c`, the
same code): new `test_native_manoeuvre` (five hulls on yard_open sent astern at rest and rolling, the decision twinned
on its tick, live and owned): 920 decisions native, 0 called back, 0 mismatches; route 613 / reverse 307; refusals
facing_nose 225, static 84, route_faster 66, friendly 6, enemy 2; `no_arrival` not reached. Drive twins 165 / 179
decisions native, 0 mismatches. Price (same run, load ~18, n 1): a decision tick's drive 1762 usec with the callback,
719 usec native, 1728 all GDScript.
**Verification on `145ada3a` (builder0, sequential, one heavy job):**
- First full check: killed by slot.sh after 5400 s (`make check exited 2`). Lint took 28 min on a busy box and test
  never finished: a timeout, not a red test.
- Second run: meant to be `check NATIVE=off`, but `make remote T=check NATIVE=off` does NOT forward NATIVE (the T must
  carry it: `T="check NATIVE=off"`), so it was a second native-ON full check. It read `make check exited 2`: 2727
  passed / 0 failed; sim-baseline all 13 unmoved; perf-judge and ai-scenarios NOT JUDGED (the box was busy); FAIL
  native-live-guard, "on but not taken under the tick profile: native_manoeuvre".
- The cause: the decision runs inside the C++ drive with no GDScript seam to call `took`. Fixed in `607fca1a`:
  `taken["manoeuvre"]` comes from the drive's own count while the guard counts, hooked in NativeExec's execute and
  NativeDrive.drive. builder0 light, `make native native-live-guard exited 0`: native_manoeuvre 227 decisions native,
  0 called back, in the profile's 20-a-side foundry match (N5.M runs in a real match).
- `native-proof` on `145ada3a`: `exited 0`, EQUAL `10c328a0f978ea49`.
**no_arrival reached: `1a1182bb`** (cherry-pick of lab `5a0d002e`, test-only). A sweep of Manoeuvre.simulate at
`145ada3a` found 4 War Rig goals and 6 Lancer goals among 1604 that reverse clear but don't arrive. The stage asks the
War Rig's four. builder0 light: 940 decisions native, 0 mismatches both views, `refused:no_arrival` 4, floor 1.
**N5.M GREEN and MERGED: main `199d1587` (= `c70be402`), R33.15 (main `27d34fe0`).** builder0, n 1 each, one heavy
job, run in sequence:
- `make check` on `025d5631`: `exited 0`, "26 targets, all passed, ALL JUDGED". Tests 2727 / 0; sim-baseline 13 maps
  unmoved; determinism `9d66d3a0c59a7936`; native-live-guard 23 taken, 2 held elsewhere.
- `check NATIVE=off` on `c70be402` (the brief-only diff from `025d5631`): `exited 2`. Tests 2727 / 0; sim-baseline
  unmoved. FAIL native-live-guard, by construction. FAIL perf-judge, judged on attempt 2: ratio 1.47x, ai 20050
  usec/tick, load 9.01. The orchestrator ruled that main's own budget for the all-GDScript AI, not N5.M's (the off path
  changes only under NativeBridge.counting).
- `native-proof` on `c70be402`: `exited 0`, EQUAL `10c328a0f978ea49`.
Round close, if builder0 is free: file one `NATIVE=off` perf-judge reading on main as a known item.
**R33.12 (main `402b3803`):** parkedroom is parked and stays DEFAULT_OFF, so the ask / `_begin_yield` port is
RELEASED. It is ported from main's body after R4's twins, with twins at 0.
**R4 pair GREEN: `pair/brains-v6-r4` `97c3b654`** (brains db72c8e9 + the mirror 560e09e8 + test_native_gate's floors as
filed on main `e4d1f749`). builder0 light, `make native test FILTER=native_gate|nav_gate_inside exited 0`, 8 / 0, n 1,
every twin 0 mismatches. Sent to brains (godot-brains-47) and the orchestrator. test_native_gate's FILE_TIME was 1006 s:
a frame-split candidate at round close.
**N5.Y built:** `4d2781e3` (C++) + `97ddf174` (test_native_yield + .uid). Design and proof in `native.md` *N5.Y*.
builder0 light, n 1, each run's exit line read:
- `make native test FILTER=native_yield exited 0`, 4 / 0, every case 0 mismatches.
- `make native native-live-guard test FILTER=native_drive|native_execute|native_face_behind|native_manoeuvre|native_gate|native_unstick|native_exec exited 0`,
  16 / 0, every twin 0 mismatches. The live guard: native_yield 14 taken; 24 switches in force, 2 held elsewhere.
**N5.Y MERGED: main `a47d43e3` (= `1053045e`).** builder0, n 1 each:
- Chain 1 on `6434969e`: builder0 dropped at 57 min (`exited 255`, no route to host). Re-run after the orchestrator's go.
- Chain 2 on `6434969e`:
  - `check exited 2`, 2738 / 1. The FAIL: `test_the_give_way_in_the_sumps` floor, `parked_refusals 47 >= 60`; every stage
    0 mismatches. perf-judge and ai-scenarios NOT JUDGED (box busy; unpinned).
  - `check NATIVE=off exited 2`, 2739 / 0, perf-judge PASS 1.07x judged; only FAIL native-live-guard (by construction).
  - sim-baseline unmoved both times. `native-proof exited 0`, EQUAL `10c328a0f978ea49`.
- Fix `1053045e`: `stream/native` fast-forwarded to `d7938a6e`, plus the parked floor 60 -> 20. The stage counts depend on
  test order; see native.md *N5.Y*. The orchestrator ruled no full chain: `make test exited 0`, 2741 / 0, and
  `perf-judge` JUDGED PASS 1.16x on attempt 1.
**R4 on main GREEN: `pair/brains-r4-main` `e382202e`** (main d99394f1 + v6 narrowed + inside_circle + the mirror, no B10b;
code-identical to `45d5f1ea`). builder0 light, `make native test FILTER=native_gate|nav_gate_inside exited 0`, 8 / 0, every
stage 0 mismatches, the same counts as `97c3b654`. Sent to brains and the orchestrator.
**C33.9 (manoeuvre's wheeled turn-in): NO C++ TWIN.** Wheeled faces hand back (execute_native `simple_face`, reason 3);
controller_tick runs the GDScript compute_command; N5.M and N5.Y never touch faces; no OrderController field is in
exec_fields.h; `--nav-off=turnin` empties nothing native (the drive steps aside on any `_off`).
**builder2 (GCP Zen 5) controller twin: 7 / 600 at d99394f1, TIMER GRANULARITY, not libm.** The only differing field is
`OrderController.profile_usec > 0`, on held ticks with profiling on: the GDScript held path sometimes finishes within 1 µs
there and charges 0. Fix, test-only, approved: `lab/native-controller-usec` `c7646f41` (main `a47d43e3` + the probe
brain spinning until get_ticks_usec advances). Run it on builder2 when the orchestrator frees the box, and on builder0
light.
**Trap (all streams):** `make remote T=check NATIVE=off` silently drops NATIVE. Make takes the trailing `NATIVE=off` as
its own variable, and the remote recipe passes only `$(T)`, so builder0 runs a plain native-ON `make check`. The
wrapper's line shows it: `>> remote: make check on …` with no `NATIVE=off`. Two forms that do forward it:
`make remote T="check NATIVE=off"` (T is word-split into the arguments) and `tools/remote.sh check NATIVE=off`
(`"$@"` reaches the remote make). Check the `>> remote: make … on` line names the variable.
**CP-F pair (manoeuvre `136c3828`), assessed: NO C++ CHANGE.** `_order_move`'s decline is not in C++; N5.M reads none of
`TURN_HULL_DEFAULT`, `_keep_slot` / `_keep_m` or facekeep, and the diff touches none of the mirrored functions; no new
Movement members (exec rows unaffected). `turret_carries_aim` is wheels + turret only, so every `drawn_face` order is a
wheeled face, handed back by execute_native (`simple_face` false on wheels); the twins assert those hand-backs write
nothing. (My first answer wrongly said tracked tanks could reach it; retracted within minutes, manoeuvre agreed.)
Read the twins on manoeuvre's pair hash when it names one.
**Decision:** no pre-emptive v6 carry work (it waits behind B10b, C33.4, and the base it lands on is not known yet).
