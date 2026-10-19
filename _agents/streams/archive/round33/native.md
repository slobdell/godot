# Stream: native (every pair; N5's held ports once traffic's far-loop design settles)

> **ARCHIVED (round 33 closed 2026-10-18).** Branch `round33/native`. The current brief is `_agents/streams/native.md` (round 34).

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
  `perf-judge` JUDGED PASS 1.16x on attempt 1. **CORRECTION:** that `make test` ran with the library ABSENT (86 `native:
  absent`), so it proved nothing about the floor (native.md hazard 10). N5.Y's evidence is the 6434969e check (native ON)
  and every builder2 main check since (HANDOFF corrected).
**R4 on main GREEN: `pair/brains-r4-main` `e382202e`** (main d99394f1 + v6 narrowed + inside_circle + the mirror, no B10b;
code-identical to `45d5f1ea`). builder0 light, `make native test FILTER=native_gate|nav_gate_inside exited 0`, 8 / 0, every
stage 0 mismatches, the same counts as `97c3b654`. Sent to brains and the orchestrator.
**C33.9 (manoeuvre's wheeled turn-in): NO C++ TWIN.** Wheeled faces hand back (execute_native `simple_face`, reason 3);
controller_tick runs the GDScript compute_command; N5.M and N5.Y never touch faces; no OrderController field is in
exec_fields.h; `--nav-off=turnin` empties nothing native (the drive steps aside on any `_off`).
**builder2 (GCP Zen 5) controller twin: 7 / 600 at d99394f1, TIMER GRANULARITY, not libm.** The only differing field is
`OrderController.profile_usec > 0`, on held ticks with profiling on: the GDScript held path sometimes finishes within 1 µs
there and charges 0. Fix, test-only: `lab/native-controller-usec` `c7646f41` (main `a47d43e3` + the probe brain spinning
until get_ticks_usec advances). n 1 on each, both `make native test FILTER=native_controller exited 0`, 1 / 0, 0 of 600
mismatches: builder2 (`make gcp-remote`) and builder0 light. **MERGED: main `ac06a393`.** The rule is native.md
hazard 8.
**Round 33 close (native).** Merged this round: N5.M (`199d1587`), N5.Y (`a47d43e3`), the controller-twin fix
(`ac06a393`). Paired and green: R4 (`e382202e`) and CP-F (no C++). Reviewed, none ported: R33.3, planner `1b5c69df`.
Answered, no twin: C33.9. Not reached this round (they come as pairs): brains' B10b (failed on its base; re-judged on
main + R4), B11b, R1; planner's CP-Q C++ review; traffic's CP-X (parkedroom is GDScript-only). Nothing barred is left.
Docs-only commits on stream/native after the merges: `beb3e868` (native.md N5.Y order-dependence), `159248db` and this
one (Status, hazard 8).
**Round 34 candidates (native):**
- Split `test_native_gate` by frame, where a floor is a branch. It is on main now, and its 4 stages run as fresh children
  (90–104 s each on builder2, 393 s for the file), so the split matters less than it did. Measure CPU seconds before and after; the next slowest are `test_native_execute` (221 s) and `test_native_drive_kturn`
  (204 s), both under the suite's largest file (`test_tactics_pursuit`, 312 s), so split them only if shard balance
  needs it.
- One `NATIVE=off` perf-judge reading on main, filed as a known item (1.47x at `c70be402`, builder0; 1.07x at
  `6434969e` under a lighter load). Use builder2 or builder0, whichever is free.
- Move the Sumps stage centre of `test_native_yield` off the pits, then re-verify its paths. Its slots sit on pit
  edges, so hulls print TANK_OFF_FLOOR at spawn. That is the stage's own placement, not a game path; both arms drive
  from one snapshot, so the twin is unaffected.
- The pairs above, as they arrive.
**test_native_yield floors, round 33 late:** builder2's 16-shard order put the Sumps' parked refusals at 6 (main
4d6f321d: 2 floors red, 0 mismatches). Fix `7b82b2e9`: each path floored at 1 (reached at all) and 100 drives compared.
`make native test FILTER=native_yield exited 0`, 6 / 0, on builder2 and builder0 light, n 1 each, with every counter
identical across the two CPUs. **MERGED: main `de6d3266`.** The in-order proof is main's next builder2 check. If a thin
path reads 0 there (asks_refused 2–3, holds 4–7), the next step is a fresh process per stage (brains' `f8cf6476` shape).
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
**Fresh-process twin stages (round 33 late; main `7851690c` = `bbb9821f`).** Main de6d3266 went red on builder2: floors
at >= 1 (native_gate's foundry latch turned 0; Sumps parked and asks 0), every twin 0 mismatches. The shard order decided
which paths a stage reached. Fix, test-only, on `fix/native-fresh-stages`:
- `e534a028`: `tests/native/fresh_stage.gd` + its child (+ `.uid`s). The pattern is native.md hazard 9, applied to 17
  stages.
- `43562eab`: the child finds the stage on the instance. The laptop negative proof caught this.
- `bbb9821f`: the yield floors at half the fresh counts; MIN_COMPARED 185.
Results:
- Filtered on 43562eab, `FILTER=native_yield|native_gate|native_drive|native_manoeuvre`: builder0 light and builder2 both
  `exited 0`, 18 / 0. Every counter is identical across the two CPUs, and each owned arm equals its live arm.
- Full order on bbb9821f, builder2: `make test exited 0`, 2771 / 0, native ON. Slowest shard 921 s (was 932 s); the 8
  files 770 -> 711 s.
- builder0 `make remote T="native test"` on bbb9821f: `exited 0`, 2771 / 0, native ON. Slowest of 6 shards 1899 s. The earlier
  `T=test` run (2208 s) had no library, so there is no fair builder0 before. FILE_TIME: native_gate 535 s (1006 s
  in-process on the R4 pair), native_yield 118 s.
- The negative proof (laptop, scratch, not committed): a child's failed assert, engine error or kill (137) each turns
  the parent red with the child's message; a passing child stays PASS.

## Overnight (round 33 extension, 2026-10-18 ~00:45 PDT)

The lead has gone to bed and wants builder2 kept busy. Take these items in order (`workstreams.md` *Round 33, overnight
extension*; the details are in `roadmap.md` *Round 34 candidates*). Merge main first. builder2 FIRST (`make gcp-remote`,
6 heavy slots). Every judged stage pinned at `--fixed-fps $(SIM_HZ)`. A bar is filed (sent to the orchestrator) before any
number, judged on FRESH seeds, and every number labelled with its machine. Keep this Status current: the lead reads it in
the morning.

Granted for these items only: mk/core.mk's `test` and `check` recipes, mk/web.mk's web-smoke judge,
tools/test_slot_light.sh, tools/remote.sh (merge notes for each).
1. **The suite at a fixed physics rate:** `--fixed-fps $(SIM_HZ)` for run_tests.gd. A full check on builder2 and on
   builder0, plus a list of every test whose numbers or verdict move, and why. sim-baseline must stay unmoved.
2. **A remote `make test` with no native library** refuses (NOT JUDGED for the twin files), or builds the library first.
3. **web-smoke's first-sound bound and test_slot_light** read NOT JUDGED under measured load instead of FAIL, as
   perf-judge does.
4. **Split test_native_gate by frame** (FILE_TIME 535 s on builder0).
5. **One NATIVE=off perf-judge reading on main** (builder2 and builder0, labelled).
Pairs pre-empt all of it (brains' arrivedgate mirror first).

### Overnight status (2026-10-18; the laptop froze ~01:45, work resumed 10:50)
**Pair: brains' arrivedgate mirror GREEN, `pair/native-arrivedgate` `6805367b`.** The C++ mirror of `_approach_gate`'s
arrived latch (`8200e230`), line for line. A new twin, `test_native_gate_arrived`, poses hulls at the goal from brains'
test shape: 144 poses a stage, each driven both ways from one snapshot, in its own process. On builder2 (n 1) it reached
the latch for artillery 40 / 144 (live and owned) and IFV 32, and never for the scout (fixed gun). The twin set +
nav_gate* + wheeled_arrival: `exited 0`, 63 / 0, 0 mismatches. In brains' battery candidate `e8530098`. Switches (a)
and (c) are GDScript only (no twin missed).
**Next pair queued: brains' scout_fights_back (`lab/brains-scout` `57d8342c`)**, after brains' battery series. It needs
`since_hit` in the C++ situation's self fields and the new first SPOT branch (0.15) in decide_native.
**1. The suite at --fixed-fps: BUILT, judging.** `e80ad0a8`: run_tests.gd gets `--fixed-fps $(SIM_HZ)` (`TEST_FPS`;
`TEST_FPS=` is the old free suite). builder2 (n 2 each, at load ~70, so the free arm is distorted): pinned 968 / 880 s
wall v free 1318 / 947 s; pinned 2768 / 3 twice, free 2771 / 0 twice. The 3 pinned fails each read the wrong clock, and
each was fixed test-only under a grant (`06d4998d`, `8aa67196`):
- `test_fx_kill_cam` asserted the runner never pins. Now the reader agrees with the runner's own flag.
- `test_control_dials` waited 40 frames. Now it waits until the camera settles on physics frames (game time).
- `test_ship_voice_fetch`'s fake fetch delay was game time against a wall-clock lateness. Now it is wall time.
All three pass pinned and free (builder0 light). The judged moves list is the builder0 set (fixed ×2, free ×2 at
`8aa67196`, load sampled); the comparison script splits each log into per-test blocks.
**2. A remote `make test` with no library REFUSES: DONE, `f3fe436d` + `6b66f161`.** It refuses (exit 3) when NATIVE is
not off, a toolchain is present and `native/bin` is missing, for the whole suite or a FILTER naming "native". Other
filters run as before. Laptop: FILTER '' and 'native_yield' refuse, 'nav_gate' runs, NATIVE=off runs.
test_filter_gate / test_test_shards skip `_native-ready` (granted): 17 / 0 and 5 / 0 with no library.
**3. Load-flaky targets read NOT JUDGED: DONE, `0a11a815` + `f5683f5f`.** web-smoke's first-sound bound,
test_slot_light's quiet-window case and test_quiet_window's live cases are NOT JUDGED only when they are the sole miss
and the 1-minute load is >= 1.5 per CPU. On a quiet box they FAIL as before. Check reads it from
`build/check/notjudged/{web-smoke,remote-guard-test}`. Stub-proven both ways on the laptop; shell-tools-test passes.
**4. test_native_gate split: DONE, `79b8a5b7`.** By case, not by frame: each stage already runs in its own process, so two
files of two stages halve a shard's share without replaying the fight. The harness is `tests/native/gate_twin_case.gd`;
the files are `test_native_gate` (Sumps) and `test_native_gate_foundry`. builder2: 4 / 0, 0 mismatches, counts as before,
219 s + 244 s (was 393 s). Merge note: arrivedgate's `gates_arrived` line moves into the harness.
**5. NATIVE=off perf-judge on main `729c2306`:** builder2 `exited 0`, JUDGED PASS 1.03x on attempt 1 (load 33 on 32 CPUs,
75 % idle), n 1. builder0 follows when the moves set frees its slot.
**6 (optional, granted). The broker's npm install takes a lock: DONE, `e0759118`.** In a fresh folder, three installs
started at once installed exactly once (two read "installed by a concurrent run"), and the broker tests passed 31 / 0.
**Overnight results, afternoon 2026-10-18 (stream/native `5caf639d` holds items 1-4 and 6):**
- **Bar (1), full check on both machines at `5caf639d`:**
  - builder0 `make check exited 0`: 26 targets passed, ALL JUDGED; tests 2771 / 0 at fps 30 (test wall 1271 s, 5 shards);
    sim-baseline 13 unmoved; perf-judge PASS 1.49x.
  - builder2 `make check exited 2`: tests 2771 / 0 (test wall 518 s, 16 shards); sim-baseline 13 unmoved; perf-judge
    PASS 1.36x. The one FAIL is net-smoke (a client saw 1 / 2 tanks, at load 46 with 79 other godot), so combat-smoke
    was NOT RUN. Re-run alone on builder2 at the same commit: `make net-smoke combat-smoke exited 0`, both clients 2 / 2.
    Load, not this change: net-smoke runs Godot directly, through no recipe this work touched.
- **Bar (2), the moves list** (the judged set: builder0, `8aa67196`, `native test` ×2 pinned, ×2 free, every run 2771 / 0;
  builder0's 1-min load sampled 149 times, median 12.4 on 12 CPUs):
  - Verdict differences pinned v free: 0, once the three tests below read the right clock.
  - Stable movers: 4. test_audio_music_director's `cost=` (a wall-clock ms measure, 0.05 v 0.06). test_control_awareness
    and test_control_cinematic: camera and marker geometry paced by frames. All pass both ways.
  - Run-to-run noise is not reduced by pinning: builder0 157 tests pinned v 129 free; builder2 68 v 114. It is almost
    all printed timings and live-match outcomes, and it moves no verdict.
- **Bar (3), the three pinned fails, fixed test-only under grants:** test_fx_kill_cam, test_control_dials and
  test_ship_voice_fetch (above).
- **Bar (4), throughput, pinned v free:**
  - builder2: test wall 968 / 880 s v 1318 / 947 s (load ~70).
  - builder0: 2975 / 1867 s v 2924 / 2548 s (shards vary 4-5 with load).
  - Pinned is the same or faster on both. In builder2's check the pinned suite took 518 s.
- **Item 5, NATIVE=off perf-judge on main:**
  - builder2, main `729c2306`: JUDGED PASS 1.03x (load 33 on 32 CPUs).
  - builder0, main `4dd04cbe`: JUDGED PASS 1.01x (load 9.2 on 12 CPUs). n 1 each.
- **Pairs:**
  - Brains' scout decide mirror is GREEN, `pair/native-scout` `0565d1a8`: 7536 decisions, 0 mismatches; the fight-back
    branch reached in 108 of 480 forced cases (floor 54). test_native_decide runs in its own process.
  - The arrivedgate mirror is DROPPED (R33.27: (b) had no measured effect). `pair/native-arrivedgate` `6805367b` stays
    unmerged, so the gate split's merge note about it no longer applies.
  - The ghost-aware stages are WITHDRAWN (R33.30: T4 parked). `fix/native-ghost-stages` `4b6433b4` and
    `pair/native-ghost-on` `b2b97188` stay unmerged and were never judged. The design, for when T4 returns:
    `Traffic.set_off("ghost", true)` in each gate / yield stage (`--traffic-off=ghost` means opposite things on main and
    on T4's pair), plus a ghost-ON stage each for the latch and the Sumps.
**Traffic pairs, afternoon 2026-10-18:**
- **R33.33, parkedroom v2: GREEN, `pair/native-parkedroom` `5e5465af`** (on traffic's `5259fb463`; traffic paired it as
  `pair/parkedroom-on-v2n`). Three parts:
  - `Drive::ask` hands every ask of a crew AT its post to the live `Movement.ask`: parkedroom on, not under way,
    `Traffic.still_s` >= `ROOM_STILL_S`, after the same `Traffic.refresh`. There is no fire-post carve-out: it would make
    the arms count differently, and handing every parked ask back is equal by construction (the orchestrator accepted).
  - `exec_fields.h` carries the seven `_room_*` members.
  - A crew with `_room_post` set is executed by the GDScript (hand-back reason 2): traffic's `right_of_way` owns the way
    back.
  builder2, n 1: twins + native_h1b + traffic tests, 88 / 0, 0 mismatches. The parkedroom-ON Sumps stage reaches the
  hand-back (1) and traffic's room path (1). perf-judge PASS 1.00x. The live guard's fight had 14 negotiations and 0
  hand-backs.
- **Item 4, firemission: GREEN on the twins, `pair/native-firemission` `5b6aa0fd`** (on traffic's `0d3f45b25`).
  `Drive::on_fire_post` needs a fire mission (a target or suppress order, or an engaged target) unless
  `--traffic-off=firemission`. The yield twin's set-up case cycles the fire order and the switch. builder2: every twin 0
  mismatches. The one red was traffic's own GDScript test (a fire_at_will battery); traffic fixed it (`328778c9`) and
  paired the two as `pair/firemission-on-n` `23251f06`.
**C33.9 ship (manoeuvre's turn-in), round 33 close, 2026-10-18 evening: `pair/native-c339` `2f9ad0fb`** on manoeuvre's
`pair/c339-ship` `4a7cbc6e` (= main `eb532bf5` + the turn-in `608c3357` + TURN_IN_DEFAULT true).
- The turn-in's face path needed nothing: a wheeled hull's `face` was already handed back (reason 3).
- Its stop hook (`OrderController._stop_turn_in`, after the gun on a `stop` of a fixed gun on wheels) is not mirrored.
  The native execute now hands that stop back: reason 4, counted as `turn_in_stop`. The switch is
  `Manoeuvre.TURN_IN_DEFAULT`, read at configure (the native drive runs only with `Movement._off` empty). A tree
  without it: no change.
- New twin `test_native_execute_turn_in` (its own process): manoeuvre's stop stage, a gang_scout circled at 15 m.
  builder2, n 1:
  - Red on `4a7cbc6e` with no native change: 198 mismatches (the live stop turns in at throttle 0.62, native kept 0).
  - Green at `8b0d91c5`: 0 mismatches, 506 hand-backs (both views), 99 live stop turn-ins. Floors at half (253 / 49).
  - The twins, h1b and manoeuvre_orbit: `exited 0`, 22 / 0. The Sumps execute twin hands back 114 (was 110), 0
    mismatches.
- Full `make native check` on builder2: see the orchestrator's message / HANDOFF for the result.

### Round 33 close-out (2026-10-18)
**Unmerged native work** (stream/native carries docs only beyond main):
- `pair/native-scout` `0565d1a8`: brains' scout_fights_back mirror. GREEN. **Carry**: merge when brains ships the
  scout fight-back.
- `pair/native-parkedroom` `5e5465af`: traffic's parkedroom ask / execute hand-back, the `_room_*` exec fields, the
  parkedroom-ON yield stage. GREEN. **Carry**: merge with traffic's parkedroom (v3, parked by R33.37, changes only
  where the way back goes; no native change needed).
- `pair/native-c339` `2f9ad0fb`: the turn-in stop hand-back above. **Ships with C33.9.**
- `pair/native-arrivedgate` `6805367b`: brains' arrivedgate latch mirror plus test_native_gate_arrived. **Dead** (R33.27:
  (b) had no measured effect). Keep only as reference if the latch returns.
- `fix/native-ghost-stages` `4b6433b4`, `pair/native-ghost-on` `b2b97188`: the ghost-aware gate / yield stages.
  **Dead until T4 returns** (R33.30). The design is in the overnight Status above.
- `pair/native-firemission` `5b6aa0fd`: merged (in main via traffic's pair).
- Older labs (`lab/native-b5c`, `-b5c-v4`, `-kturnarc`, `-m4b-escapes`, `-n5m`, `-n5m-noarr`, `proof/native-t1`,
  `round31/native`, `scratch/native-el-dev`, `scratch/native-ellaps`, `local/native-laps-*`): superseded by what merged
  in rounds 29-33, or measurement scaffolding. **Dead**: delete when convenient.

**Round 34, what native would take next** (in order):
1. **The judged-stage pinning audit.** `make test` runs at `--fixed-fps $(SIM_HZ)`, but the other run_tests callers
   (nav, pace, planner, command, tactics .mk) still run free. Pin each judged stage, or name why it must run free, and
   measure the moves the way item 1 did (pinned ×2, free ×2, load sampled).
2. **The library refusal, the rest of the way.** `make test` refuses with no library (`_native-ready`, done). Audit
   the other targets that can pass the twins vacuously: `native-verify-suite`, the shard targets, and any target that
   runs a `native_*` file by FILTER through another recipe.
3. **The yield Sumps stage off the pits**, so its counts stop depending on the pit geometry.
4. **The turn-in natively**, only if perf-judge shows the hand-back costs (the scouts are few; today it is GDScript
   on a stop with wheels and a fixed gun).
5. **Pairs as they come**: brains' scout and traffic's parkedroom (carried above).
6. Twin splits only if shard balance needs them.
