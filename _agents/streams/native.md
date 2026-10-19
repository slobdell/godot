# Stream: native (every pair; a shell never RPCs a dropped player; every judged stage pinned)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (*N7*, *Stage 1*), `_agents/workstreams.md`
> **Round 34** (C34.2, C34.4, C34.5, C34.7, C34.8 (a); C31.1, C31.2 stand; R33.25 in *Round 33*), `_agents/remote_builds.md`
> (the native traps), and your round-33 brief `streams/archive/round33/native.md` (its close-out Status).
> **You own:** `native/**` (outside the planner's `planner_*`, which you review), `game/ai/native/**`, `tests/native/**`,
> `tests/test_native*.gd`, `mk/native.mk`, `mk/pace.mk`, `brain_switches.gd` (others add one switch line: merge note),
> `cover_map.gd`, `incoming_fire.gd`'s seam, `think_quiet.gd`, the seams on main, `exec_fields.h`, the planner's build glue,
> the stage-1 grants, and round 33's test-infra grants (mk/core.mk's `test`/`check`, mk/web.mk's web-smoke judge,
> tools/test_slot_light.sh, tools/remote.sh). **Granted (round 34):** C34.7's guard on `_shell_hit`'s RPC in
> `game/match/match.gd` and the shell's teardown, with a test. C34.8 (a)'s `--fixed-fps $(SIM_HZ)` token in nav.mk,
> pace.mk, planner.mk, command.mk and tactics.mk's direct run_tests.gd callers, and in each unpinned JUDGED stage target.
> One token each, with a merge note. **Model:** Opus.

## The lead's direction

Round 26: core components in C++ (stage 1 ON 2026-10-12), even without a gain, with an equal answer; stage 2 deferred
(his call). Nothing he plays changes because of this stream alone; every behaviour he sees ships as a pair with its owner.
He is building toward relay-only network play, so a network log that is clean under load matters.

## Where things stand (main at the round-34 docs commit)

- **Round 33 shipped from native:** N5.M (`_manoeuvre` in C++), N5.Y (the give-way negotiation in C++), the fresh-process
  twin stages (the order-dependent floors are fixed for good), the controller twin's timer fix on Zen 5, and the test infra
  (the suite at `--fixed-fps`, `make test` refusing without a library, load-aware NOT JUDGED, npm once under a lock,
  test_native_gate split). C33.9's stop hand-back (`pair/native-c339` `2f9ad0fb9`) waits for manoeuvre's turn-in, which did not ship
  (R33.39; C34.10). It covers any narrowing.
- **Waiting pairs (C31.2: they pre-empt everything):**
  - traffic's parkedroom v4 needs your hand-back REBASED onto current main (`pair/native-parkedroom` `5e5465af8`:
    `ae8d6e858`, `f16f49867`, `a7999c5c4`, `bcb0af2ba`, `6596e871c`).
  - brains' scout try 2: the `decide` mirror (`pair/native-scout` `0565d1a89`, green for try 1; rework for the duel-only rule).
  - manoeuvre's CP-F attempt 4: its mirrors.
  - traffic's T4 only if it returns (`pair/native-ghost-on` `b2b97188d`).
- **R33.25:** relay-smoke under a full check's load logs ×6 "Trying to call an RPC via a multiplayer peer which is not
  connected" from match.gd:2094 `_shell_hit` ← shell.gd `_fly`. It passes alone. It's the known red that doesn't block
  (R33.20's family).

## Backlog (in order)

1. **N1 Pairs, as they arrive.** Each: review the diff, mirror or hand back, twins at 0 mismatches, and the owner's pair
   check names the hash.
2. **N2 relay-smoke's shell RPC (C34.7).** A test that drops the peer while a shell is in flight and fails without the
   fix. Then guard the RPC on a connected peer, or stop shells at teardown. relay-smoke and net-smoke green in a full check
   on a loaded box (builder2 with other jobs running).
3. **N3 Pin every judged stage (C34.8 (a)).** Audit `mk/*.mk` for unpinned `$(GODOT) --headless` calls that a JUDGED target
   runs (renders, smokes and network targets keep the wall clock where that's the point; say which and why). Pin them and
   the five direct run_tests.gd callers. Make a moves list like the suite's bar (twice pinned, twice free, one commit).
   Every mover gets a reason, and nothing is loosened.
4. **N4 The library refusal, the rest of the way:** `make test` refuses; audit native-verify-suite, the shard targets and
   the FILTER paths that could still pass the twins vacuously ("native: absent").
5. **N5 Move the yield Sumps stage off the pits** (your round-33 note).
6. **Stretch:** a native turn-in, only if perf-judge shows the C33.9 hand-back costs; twin splits only if shard balance
   needs them.

## How to verify

`make native check` (never `make remote T=test` for twins: it now refuses without a library). `native-proof`,
`native-verify-scenarios`, the twin files. Long remote runs under `systemd-run --user`. Every number: commit, machine,
NATIVE line, n.

## Don't touch

Gameplay behaviour in any stream's GDScript (mirror it, don't change it); `game/ai/planner/**` (review only);
`tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Round 34 (started 2026-10-18 from main `918ede503`, which inherits `d7d57f4cf`'s green check)

**REPORT (top).** **MERGED: main `02a912163`** (= `12ac7b172`: C34.7 + C34.8 (a) + N4; INHERIT, no main check). builder2 `make native check exited 0`:
2798 / 0, 27 targets ALL JUDGED, sim-baseline 13 unmoved, perf-judge PASS 1.34x. The load at the start was 28.8 on 32
CPUs with 55 other godot processes (pin-moves and three twin runs at once). relay-smoke and net-smoke both passed under
that load, n 1. Pairs: scout try 2 GREEN `85f34ca63` (merged into stream/brains `0b8fbd3f6`); parkedroom v4 `6231e7222`
twins running. Still running: the moves list (pin-moves), N5's centre probe.

**Plan (in order; pairs pre-empt, C31.2):** (0) the waiting pairs: parkedroom's hand-back rebased onto main for traffic's
v4; brains' scout try 2 mirror as it arrives. (1) N2 C34.7: the dropped-peer test first, then the guard. (2) N3 C34.8 (a):
the audit, one token a recipe, the moves list as a make target (pinned ×2, free ×2, one commit). (3) N4 the library
refusal audit. (4) N5 the yield Sumps stage off the pits. (5) A full `make native check` on a loaded box for N2 + N3.
**Decisions:** the pin is one token `$(PIN_FPS)` (defined in mk/native.mk, `?= --fixed-fps $(SIM_HZ)`), so the free arm
is `PIN_FPS=` with no second recipe; the guard shows the impact locally when the peer is not connected (what call_local
would have done) rather than stopping shells at teardown: the host's match goes on after its room closes, and its own
screen should still see the hit.

**Pairs:**
- **C34.2 parkedroom hand-back, rebased: `pair/native-parkedroom-r34`** = main `918ede503` + `ae8d6e858`, `6596e871c`,
  `f16f49867`, `bcb0af2ba`, `a7999c5c4`, `5e5465af8` cherry-picked, no conflicts. It reads traffic's parkedroom members, so
  it is for traffic's v4 pair tree; twins run on traffic's v4 hash.
- **C34.5 scout try 2 mirror: `pair/native-scout2` `93d878924`** on brains' `86c8d7f68`. `scout_fights_back` in C++: the
  can't-outrun clause and its `Units.stat` calls are gone; an advantage < 1 skips; the reach forecast samples now and each
  second to `SCOUT_FIGHT_REACH_S` on `godot::Vector3` (real_t, as GDScript). test_native_decide's forced scout case now
  also moves the contacts (0-16 m/s) and the scout (0-12 m/s) and counts the cases the forecast cut. builder2, `make
  native test FILTER=native_decide` at `2135c0af5` (n 1): `exited 0`, 7536 decisions, 0 mismatches; 480 forced scout
  cases, 27 fight back, 6 cut by the forecast (floors at half: 13 and 3, `93d878924`).

- **C34.5, brains' second change (834562ab1: the champion runs without matchups, so decide computes the duel for a
  scout under fire): `pair/native-scout3` `85f34ca63`** = brains `834562ab1` + the two commits above + `scout_under_fire`
  in C++ and the lazy `matchups_for` in decide's SPOT branch. test_native_decide's count follows the same rule. builder2,
  n 1: native_decide 7536 decisions, 0 mismatches; 480 forced scout cases, 52 fight back, 17 cut by the forecast.
  **GREEN, sent to brains: `85f34ca63`.** builder2, n 1, `make native test FILTER=native_decide|scout_fights_back|
  native_gate|native_drive|native_execute|native_matchups` exited 0, 24 / 0, every twin 0 mismatches (drive 2160,
  k-turns 1440, unstick 3600 + 3600, execute 5880 native / 120 handed back). Brains merges it and runs its ship check.
- **C34.2 v4: `pair/native-parkedroom-v4` `6231e7222`** = traffic `1b2fd26f1` + the r34 hand-back (merged) + one commit:
  Drive::ask's hand-back asks `Movement.at_post_of(tanks_root, name)` (traffic's one definition of AT a post: still for
  ROOM_STILL_S, or on a HOLD order inside its hold line) instead of inlining `Traffic.still_s`. The phase test stays as
  at_post's own first clause. No new floor stage: the C++ asks the GDScript's at_post itself, so the decision is equal by
  construction, and traffic's neck test covers the hold-line clause.
  **GREEN, sent to traffic: `6231e7222`.** builder2, n 1, `make native test FILTER=native_yield|native_drive|
  native_execute|native_h1b|traffic_neck|native_gate` exited 0, 33 / 0, every twin 0 mismatches; the parkedroom Sumps
  stage: 173 negotiations, ask_handed_back 1 (floor 1).
- **N4, the refusal the rest of the way: `12ac7b172`.** Every twin's "native: absent" early return (57 sites, 42 files)
  goes through `NativeExpect.absent(self)` (tests/native/native_expect.gd). That FAILS the twin when make exported
  `TANK_NATIVE_EXPECTED=1` (NATIVE on and a C++ toolchain, mk/native.mk). It covers what `_native-ready` can't see: a
  FILTER that matches a twin without saying "native" (`FILTER=decide` ran test_native_decide vacuously), shards,
  native-verify-suite / -scenarios, and every other recipe's run_tests.gd call. Laptop, no library: the runner with
  `TANK_NATIVE_EXPECTED=1` and `--filter=decide|native_shell` reads 32 / 3, the three twins FAIL with the message; without
  it, they skip as before. A first try (an engine error at NativeBridge's static init) was dropped: it fires before any
  test, so the runner does not count it. Not converted: tests/test_manoeuvre_wedge.gd (manoeuvre's, one site; relayed).

**N2 C34.7, the shell RPC after the drop: BUILT, `cd0fc9ed0` (+ `.uid`).** `test_match_shell_dropped_peer`: a seated
relay host (grace 0) fires a shell at a tank 15 m away, the socket drops with the shell in flight, the session ends on the
next poll, the shell lands. Red without the guard (laptop, NATIVE=off): exactly R33.25's engine error, "Trying to call an
RPC via a multiplayer peer which is not connected" (scene_rpc_interface.cpp:478); every other assertion held. Green with
`_show_shell_impact` (rpc when connected, else the local call): laptop 7 runs, alone and with relay_peer + fx_tank_shell.
One early combined run read 20/1 with its detail lost; 7 since are green. Watching for it in the full check.

**N5, the yield Sumps stage off the pits: DONE, `17876e4b6` (test-only).** The off-floor hulls were NOT the pits alone.
A laptop sweep of the stage's spawn layout over 961 Sumps centres (4 m grid, NATIVE=off) found hulls pushed off the floor
almost everywhere: only 231 centres spawn clean. The old (-16, -6) put 7 hulls off the floor, where its ranks overlapped
the pump house and the west pit's rim. On flat yard_open the same layout spawns clean. Six clean candidates near a pit
were run as the real stage on builder2 (scratch `2c4f5d2e1`). (-40, 40) keeps every hull on the floor through the whole
stage and reaches every path. Its ranks are 6 m from the pit, which still makes give-way spots unfit (45). builder2, n 1,
`make native test FILTER=native_yield` at `17876e4b6`: exited 0, 6 / 0. Both Sumps stages read the same: 546 drives
compared, 0 mismatches, 44 negotiations (spot 34, unfit 45, back 5, hold 1, parked refusals 3, asks refused 1). The
counts equal the probe's, which shows the fresh-process stage is deterministic. Floors are at half, each path at least 1,
and a guard asserts no hull leaves the floor. The old stage reached more paths (107 negotiations); the floors only ask
that each path is reached. Traffic's parkedroom stage (on its pair tree) still uses (-16, -6); it moves when N5 merges.

**N3 C34.8 (a), the pinning audit: BUILT, `d8ce74b91`.** Pinned (one `$(PIN_FPS)` token each): command.mk
five-squads-series, interleaved-probe, control-timing ×2, facing-probe, hull-rest-probe, flank-probe; nav.mk gate-test;
pace.mk pace-p0-tests, pace-leak-tests ×2; planner.mk planner-twin, planner-trace-hull-rest; tactics.mk converge-probe,
scenario-times; traffic.mk traffic-far-hull. Free on purpose, each with its reason, in mk/native.mk's audit comment
(the clock is the parameter; real sockets; CPU benches; UI playtests; no physics step decides anything).

