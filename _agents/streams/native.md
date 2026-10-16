# Stream: native (every pair, T3b-c first; the four slow twin files split; N5's held ports)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (*N7*, *Stage 1*), `_agents/workstreams.md`
> **Round 32** (C32.1, C32.8; C31.1, C31.2, R31.1 and its addendum stand), and your round-31 brief
> `streams/archive/round31/native.md` (*Round 31* report: the T3b mirror `413252ea`, T1c-b2 "none ported", the CP-H and
> CP-P1 pairs, *Carried to round 32*; the twin lessons). **You own:** `native/**`, `game/ai/native/**`, `tests/native/**`,
> `tests/test_native*.gd`, `mk/native.mk`, `mk/pace.mk`, `brain_switches.gd` (others add one switch line: merge note),
> `cover_map.gd`, `incoming_fire.gd`'s seam, `think_quiet.gd`, the seams on main, `exec_fields.h`, the planner's build glue;
> plus the stage-1 grants (the seam at the top of `OrderController.compute_command`; `Movement`'s and `Gunnery`'s member
> STORAGE; `traffic.gd` for its port; `wall_contact.gd`'s observer). You review every planner C++ commit for fidelity before
> it is pushed. **Model:** Opus.

## The lead's direction

Round 26: core components in C++ (stage 1 ON 2026-10-12), even without a gain, with an equal answer. Nothing he plays
changes because of this stream alone; every behaviour he sees ships as a pair with its owner.

## Where things stand (main at the round-32 docs commit; inherits `e66b41f1`'s green check: builder0 exited 0, 2657/0)

- Round 31 shipped every pair it was sent: T3b and T4 (OFF), CP-H (`76b7ee46`), CP-P1 (`166f7f1e`). The T3b-c mirror
  `413252ea` (`NativeTraffic.avoid_shape` → `Traffic.shape` as a GDScript callback; inert unless Traffic has `shape`) was
  judged on `f5dc4147` with 0 mismatches in its four twins, and **his yes ships it this round**.
- Your round-31 branch is `round31/native` (kept, not merged).
- **Shard times (builder0, `tests/shard_times.txt`):** `test_native_traffic_hold` 316 s, `test_native_execute` 308 s,
  `test_native_drive` 241 s, `test_native_wall` 185 s: four of the six slowest files in the suite. A check is ~55 min of
  test time (R31.9).

## Backlog (in order; pairs pre-empt your own work, C31.2)

1. **The T3b-c pair (C32.1, CP-T):** re-carry `413252ea` onto current main (CP-H and CP-P1 landed since), twins at 0
   mismatches (`make native test FILTER=native_traffic`), and build the pair tree with traffic's carried T3b-c (agree with
   traffic where it is built; tell the orchestrator). Plain `make remote T=check` on it, switch ON by default; name the hash.
2. **T1c-b2:** confirm "none ported" still holds on current main (`ask()` only through GDScript callbacks) and run
   `native-verify-scenarios` + `traffic-native-verify` on traffic's tree.
3. **The four twin splits (C32.8, R31.9 (3)):** `test_native_traffic_hold`, `test_native_execute`, `test_native_drive`,
   `test_native_wall`, in round 31's `TrafficTwin` pattern (a shared harness, one case or case group per file). Measure
   each on builder0 first; the same assertions divided; test count and the slowest file's seconds before and after; check
   green; name the hash. Test-only, so the orchestrator can merge it on its own.
4. **Pairs as they arrive:** manoeuvre's H1b, brains' B3b-2c and B5c-v6, the planner's side gate and SLICE preset (if any
   of them touch C++ or the drive), in that rough order. Each: mirror, twins at 0, the pair tree with the switch ON,
   plain check, named hash. Under `NATIVE=off`, `native-live-guard` fails by construction (R31.1 addendum).
5. **N5's held ports** (carried, unblocked by CP-P1): `_negotiate`'s body / ask / `_begin_yield`, `_manoeuvre`; each a
   pair with its own switch, proofs and price. Only when no pair waits.

## How to verify

`make remote T=check` and `make remote T=check NATIVE=off` where a port changes; `make native test FILTER=...` for twins
(plain `make test` builds no library; call `tools/remote.sh --light native test 'FILTER=a|b'` when FILTER has `|`);
`native-verify-scenarios`, `native-proof`; determinism and the thirteen lines unmoved unless a pair moves them on purpose.
A waiter greps `>> remote: make.* exited`. Long remote runs under `systemd-run --user`. Every number: commit, machine,
workload, n.

## Don't touch

Brains' think side (`tank_brain.gd` outside your seams, `game/tactics/**`, elements); manoeuvre's drive body and executor
logic (you mirror, they own); traffic's give-way logic; the planner's GDScript; `game/control/**`, `game/camera/**`;
`tests/baselines/**`; `tools/judge/**`. `origin` holds an old `stream/native`: don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Round 32 (started 2026-10-16 ~00:40 PDT from main `6efdf42b`; covered by `e66b41f1`'s inherited green check)

**Report (kept current).**
- **1. T3b-c pair (CP-T, R32.1):** my mirror `413252ea` is already an ancestor of main (round 31; inert until Traffic has
  `shape`), so native re-carries nothing. Traffic's carried T3b-c is `b5882c9c` (main `6efdf42b` + `ac15ac0b` + teardowns
  `67aa9c76` + `DEFAULT_OFF := []`), and that commit IS the pair tree: branch `pair/t3bc-r32`, worktree
  `../godot-native-pair`. **Ship check read on `b5882c9c`:** builder0 `>> remote: make check exited 2`, tests 2671 passed /
  0 failed, engine 0 errors, `25 passed, 1 FAILED, 0 NOT RUN`: sim-baseline alone, all 13 maps moved (expected ON,
  C32.1). Twins: test_native_traffic_turns 5147 drives (655 shaped) / `_owned` 4758 (643 shaped), 0 mismatches; hold 7856,
  0. Named to the orchestrator (recorded) and traffic, whose one re-judge on that tree gates the merge.
- **2. T1c-b2:** NONE PORTED still holds on main `2572cbec`: the rule (`on_fire_post` and the refusal) is inside
  `Movement.ask()`, reached from the native drive only through the GDScript `_negotiate` / `_ask_behind` callbacks.
  Re-confirmed on traffic's tree `traffic-t1cb2-r32` `4849bfdc` (its game/ diff v `b5882c9c` is only `on_fire_post`, the
  refusal in `ask()` and three Movement statics written in that callback); traffic runs `traffic-native-verify` +
  `native-verify-scenarios` on it.
- **4. H1b (manoeuvre `373de208`): NONE PORTED.** The native unstick reaches `_escape_begin` only as a callback followed by
  `return`, as the GDScript does; H1b's reads (`_goal`, `_remaining`, `_goal_velocity`) and writes (`_repair_for`,
  `_repair_to`) are exec_fields rows synced round callbacks and honoured by the native drive; `_h1b_*` are GDScript-only
  members the twins capture. Proof: `test_native_h1b` (`233cbde4`), manoeuvre's parked-squadmate stage with the pinned
  hull's execute step twinned (GDScript / native live / native owned); skips without H1b; on an ON tree it needs a settle
  compared natively. **Green on the scratch ON tree** `scratch/h1b-on` `f29e3c87` (`233cbde4` + manoeuvre `373de208` +
  H1B_DEFAULT true; builder0 light, exited 0): 1200 native executes, 3 escape fires, 2 failed asks, 1 settle (compared in
  both views), phase arrived, 0 mismatches. The pair tree waits for manoeuvre's green hash.
- **5. B5c-v6 (brains):** v5's mirror (`4b335e67`, v4 rule; v5's gate GDScript equals v4's) carried onto main:
  `pair/brains-v6-carry` `09c85f67` (`../godot-native-v6`) = lab `6c3e6c71` + main `b418225c` + a harness fix:
  `test_native_gate` predates CP-P1 and lacked the planner seam's world capture (read `_kturn_check` 6 v 1). builder0
  light: gate 4/4 at 0 mismatches (Sumps 6000 + 174/186 forced; Foundry 6000 + 513/515 forced), turns and drive twins 0.
  No `near` cooldown row (dropped by brains: a GDScript grounding latch instead). Waiting for brains' tested diff.
**Lesson (twins):** every twin whose drive can reach `_planned_reverse` must snapshot `MoverState.world_capture()` (the
planner seam), or a crew the live arm hands the seam is inherited by the native arm. And a twin for code that is not on
main yet must name the new members by string (`get`/`call`), or the file fails lint on main. A pair tree takes stream/native's TESTS
whole (merge the named hash), never one file: `test_native_h1b` extends `ExecuteTwinCase`, and the first H1b pair cut
(`5d6d7414`) lost a check to lint on that.
- **H1b pair tree:** `pair/h1b-on` `fa2d9e31` (main `2fc43a47` + manoeuvre `e8e20ca9` + stream/native `981e336b` +
  H1B_DEFAULT true; worktree `../godot-native-h1b`). Its check (builder0): `make check exited 2`, 2701 passed / 2
  failed, sim-baseline ALL 13 maps UNMOVED (H1b ON moves no map; determinism 9d66d3a0c59a7936). Both reds native-side:
  (a) test_native_exec_state wanted exec_fields rows for H1b's five members (`_h1b_blocker`, `_goal`, `_at`, `_failed`,
  `_last_answer`): pair commit `2d35b1ec`; the table is two-way checked, so those rows SHIP WITH H1b, never main first.
  (b) test_native_wall's crew split: with H1b ON one half met 8 wall ticks (the other 554) and failed the branch floor
  at 0 mismatches. Fixed `e9fc7864`: split by staggered frame (`(frame + index) % parts`), so each half sees every crew.
  Off main as `fix/wall-split` `cb408505` (builder0 light: 2/0, halves 241 / 318 wall ticks) for the orchestrator to
  merge ahead of H1b (the crew split is on main already). Re-cut `pair/h1b-on` `273654e6` (+ `2d35b1ec` + `e9fc7864`):
  builder0 light `native_wall|native_exec_state|native_h1b` 7/0 (table 156/156; wall halves 319 / 242; h1b 1200
  executes, 1 settle, 0 mismatches). **GREEN: `pair/h1b-on` `273654e6`**, builder0 plain check `make check exited 0`,
  2703 passed / 0 failed, all 13 maps unmoved. Named to manoeuvre and the orchestrator for the series.
  Coming (manoeuvre's labs, not in this pair): `lab/manoeuvre-swap` adds `_h1b_swap_goal` and ESC_SWAP (escape stage 4:
  the native unstick must hand back or mirror it, plus a row); `lab/manoeuvre-m1b3`'s `_arr_*` are census-only.
- **Face-behind twin (orchestrator's question, `NATIVE=off` red on test_manoeuvre_behind's War Rig planned turn):**
  `test_native_face_behind` (`1ca9988f`). A wheeled hull's face turn (`Movement.face_turn`, M1b's planned legs) is
  handed back BY DESIGN (execute_native.cpp `simple_face`: a face order natively only on a tracked hull's plain facing),
  so the War Rig case asserts the hand-back (0 native, 928 handed back that wrote nothing; GDScript-played legs 3, drift
  1.5 m) and a tracked tank on the same stage the native face (142 native executes, 0 mismatches, the whole 2.4 s turn).
  builder0 light, `89c68660`. The divergence was the PLANNER's no-library session (planner fixed it, c74f5943); a
  C++-v-GDScript session case was declined: two plays in one test process are not clean (my scratch never freed the
  first Rig, so later plays were pinned; sent to planner with that caveat). Porting `face_turn` belongs with the held
  k-turn / `_manoeuvre` port (item 6).
- **Order-dependent twin red (traffic's check on c9fa64a4, test_native_execute_odd 2 mismatches at frame 0):** a crew
  test_native_drive_owned leaves held in PlannerSeam (hull freed since) is skipped by `capture()` but counted in
  `report()`'s `live`, so the live arm read 1 and the restored native arm 0 until the first `_sweep`. Fix `f686f155`:
  `MoverState.world_reset()` (the seam's `reset`) first in every twin case that captures the seam. Reproduced
  (builder0 light, `native_drive_owned|native_execute_odd` serial): main 99afc1f8 1/1, f686f155 2/0. Off main as
  `fix/seam-reset` `45b52d04` (3/0 with h1b). **Lesson:** a twin case owns its world: empty every static table it
  captures at its start, or it inherits the shard's history.
- **stream/native green: `17ab77b9`** (main 99afc1f8 merged + face twin + seam reset): builder0 `make check exited 0`,
  2703 passed / 0 failed, 24 passed, all maps unmoved. (`1ca9988f`'s check had 2702/1: the face twin's War Rig case at
  tick 0, the same seam carry-over, before `f686f155` gave it `world_reset`.) Later commits are this brief only.
- **Still open:** B5c-v6 is on HOLD this round (C32.11: behind B10b, behind C32.10's swap, behind H1b's series); when it
  returns, the v6 carry's `test_native_gate` needs `MoverState.world_reset()` at its start like every other
  seam-capturing twin. **C32.10 swap pair, pre-assessed on `lab/manoeuvre-swap` `98a29c57`: NONE PORTED.** The native
  drive calls `_escape_step` back for any `_esc_stage` != 0 (drive_native.cpp ~1452), so ESC_SWAP (4) runs as
  GDScript; `_h1b_swap` runs inside `_escape_begin` (a callback, like H1b). The pair needs ONE exec_fields row,
  `F(Vector3, VECTOR3, _h1b_swap_goal)` after `_h1b_last_answer` (declaration order), shipped with the swap;
  `swap_seam_override` is a static Callable (MoverState's statics carry it; not an exec row). Then the plain check.
  N5's held ports (item 6) stay held until the swap ships (it is their moving target).
**Lesson (splits):** split a twin by crew only where the floor is a sample size; a branch floor (walls, hulls) must split
by frame, or a behaviour change elsewhere starves one half.
- **3. Twin splits (C32.8):** `d98f4400` (test-only). BEFORE, measured first (builder0 light lane, `6efdf42b`, one
  serial `make native test FILTER=…`, n 1, while a heavy check ran beside it): test_native_execute 472 s,
  test_native_drive 330 s, test_native_traffic_hold 253 s (+ `_owned` 193 s, round 31's split), test_native_wall 193 s;
  every one 0 mismatches (execute 11880 native executes; drive 2160 drives a view, k-turns 1440; hold 7244 / owned 7304
  drives; wall 12000 observes). The FAIR before is a full sharded check's per-file times: `b5882c9c`'s (builder0, load
  ~12, plan rr): drive 457 s, execute 455, traffic_hold 334, wall 315, hold_owned 234, and, now T3b-c is ON on main,
  traffic_turns_owned 215 and traffic_turns 159 (split too at `08b452ee`, TrafficTurnsCase). A serial light-lane run of all
  the split files was killed at the 90-min slot cap (load 10), so it is not evidence. The first full check on `233cbde4`
  failed LINT on my own `test_native_h1b` (it named H1b's statics, so it did not parse without H1b; fixed `981e336b`).
  AFTER, full check on `981e336b` (builder0): `make check exited 2`, 2663 passed / 1 failed, the one being
  test_control_vision_camera's teleport case (not a native file; re-run alone below). Its per-file times are NOT evidence
  either way: under contention (load 12-16) a file's wall time moved ±40 % between checks. **Measured instead as CPU
  seconds** (user+sys, one Godot process per file, `/usr/bin/time`, builder0 light slot, serial, n 1; the base folder =
  `6efdf42b`, the split = `981e336b`; scratchpad script `cpu_times.sh`): test_native_execute 614 → 262 + 289 (the slower
  half 47 %); test_native_wall 138 → 91 + 95 (69 %: the uncompared fight is a larger share); test_native_drive 493 →
  106 + 98 (owned) + 178 (kturn) + 23 (kturn owned) (36 %); test_native_traffic_hold 384 → 87 + 88; `_owned` 346 → 168 +
  161 (49 %). The suite's slowest native file falls from 614 CPU-s (execute) to 289 (execute_odd). Every split file 0
  mismatches. The turns twins (split at `08b452ee`) skip on this tree (no T3b-c until stream/native takes main).
  test_control_vision_camera re-run alone on the same build: 18/18 (a load flake at load 12+). **Green hash for the
  splits: `981e336b`** (its check: 2663/1, the one red that flake; later commits are this brief only).
- **Planner review:** `df45fac3` (CP-S `PlannerNative::clearances`) APPROVED, one note (the GDScript arm prepares the
  caller's world; the native arm doesn't).
  `0b9e96bc` (`refused_at_begin`, header only) APPROVED: consistent with `step()` (those three codes never start the fine
  retry). Per-crew `PlannerNative` instances for the shared queue: agreed (no C++ change; free an instance with its crew).

- **6. N5's held ports: HELD this round (decision, reason).** `_negotiate`'s body / `ask` / `_begin_yield` are being
  changed in round 32 by traffic and manoeuvre (C32.10's mutual pin: traffic's designation + manoeuvre's reverse; H1b
  in the escape beside them), and the brief puts pairs first. Porting them now means porting a moving target twice. They
  start once C32.10 ships; the k-turn planner's body and `_manoeuvre` follow manoeuvre's M1b(3).

**Plan (in order):** (1) the T3b-c pair check, named hash; (2) T1c-b2's verify runs on traffic's tree; (3) the four twin
splits, test-only, their own hash; (4) pairs as they arrive (H1b, B3b-2c, B5c-v6, the planner's side gate and SLICE: CP-S
needs no mirror, being C++ already reviewed); (5) N5's held ports only when no pair waits.
**Split design (one reason each):** drive has five cases, so each case goes to its own file over a shared base
(`DriveTwinCase`, bodies byte-identical). Execute, wall and the traffic hold are ONE case over one fight, so each file plays
the whole fight and compares half the crews (even / `_odd`): every frame's union is still every crew, and the branch floors
(the hold firing, wall / hull ticks) see the whole fight, which a frame-window split would not guarantee. Only the sample
floor is divided. A live v owned split would keep most of the cost: the GDScript capture of every mover dominates both
arms.
