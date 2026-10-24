# Stream: native (the rules-ON pairing base; the same sim on every machine; the tools every stream leans on)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/remote_builds.md`, `_agents/workstreams.md`
> **Round 39** (C39.0, C39.1, C39.6) and *Rulings (round 38)*: R38.25, R38.50, R38.52, R38.55. Your round-38 brief:
> `streams/archive/round38/native.md`. **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`,
> `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`, `tools/slot.sh`, `tests/ai_scenarios/guard_line.gd`; GRANT (C39.6):
> `mk/play.mk`'s skirmish recipe. **Model:** Opus. **Machine:** builder2 (rows), builder0 for perf only.

## The lead's direction

C++ for core components long-term ("Native code is C++"); the builders are for throughput. He asked (2026-10-23) whether a faster
physics engine would speed development; the answer was "physics is a small share, Jolt already" with an offer to measure it.

## Where things stand

- **Round 38's row (R38.52):** 686150ed2, rules OFF: blob 47 %, turtle 41 %, inside noise of round 37. Per-fight rows
  `references/scoreboard/guards/686150ed2.fights.jsonl`.
- **R1-R3 ON by default (R38.55)**, so that base no longer describes main.
- **Machine trig (R38.25):** the laptop (glibc 2.39) and builders (2.43) differ in float trig (atan2f etc.); native == GDScript per
  machine. Pairs across machines are forbidden until this is fixed.
- **Loaded gates are per physical core** (builder2 24, builder0 15). Orders' check failed test_slot_light's setup at 1.49 per core
  (R38.18 cleared on a solo re-run).

## Backlog (in order)

1. **N1 the rules-ON base (CP39.0, FIRST).** CP37.1's guard lines (320 paired fights, same seeds) on main as launched, rules ON; file
   `references/scoreboard/guards/<main>.fights.jsonl` and a scoreboard row v 686150ed2 per faction. Tell the orchestrator the minute it
   lands (doctrine waits on it).
2. **N2 `make skirmish SKIRMISH_FLAGS="..."` (C39.6).** Passthrough only; default unchanged; a test that the flags reach the game.
3. **N3 the begin_yield twin** for manoeuvre's chain-aware give-way (when manoeuvre names the function).
4. **N4 machine-independent trig.** Make the sim's trig the same on glibc 2.39 and 2.43 (own implementations or a pinned libm in
   native and the GDScript path), sim-baseline equal on the laptop and both builders. A design note first (cost, perf).
5. **N5 the quiet-window line ~1.0 per core** (SLOT_LOADED_PER_CORE / QW_LOADED_PER_CORE): it waits for quiet, costs no judging power.
6. **Stretch:** the physics-share measurement (what share of a tick and of a check is physics on builder0), for his question.

## How to verify

`make native check` on builder2 per named hash; perf-judge on a quiet builder0; shell-tools-test for tool changes; sim-baseline on
every machine for N4.

## Don't touch

Game code outside `native/**` (twins mirror their GDScript owners' code, which stays the owners'), `tests/baselines/**` (the orchestrator
adopts). Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Report (round 39 worker, 2026-10-24 ~00:30 PDT): every backlog item and the stretch done

**HAND-OVER (green): stream/native 8f018edf7** (builder2 3137/0, 13 sim-baseline maps unmoved; Status-only commits after
it). **N3's pair: pair/native-givewaychain bb8043686** (builder2 3143/0), merged by the orchestrator beside manoeuvre's
branch. **Left:** the scoreboard row's fights/moves/orders part for 8952c3d64 (run.sh, at a doctrine chunk pause; nothing
waits on it); perf-judge of the native trig change on a quiet builder0 (main's own check).
**After the hand-over (2026-10-24, the orchestrator's asks):**
- **Merged main 259926070** (0a34b4ceb). main 76f42a9c3 judged +8.8 % on builder0: 8,366 us/tick v 8952c3d64's 7,687.
- **The trig cost A/B is built, its run DEFERRED to the orchestrator's go** (the round's close, when builder0 empties, ~20:00
  PDT). `make remote-quiet T=trig-perf-ab`: libtank_native built cr v `NATIVE_TRIG=libm` (the only N4 change on glibc
  >= 2.41), perf-judge per arm, 3 rounds alternating.
  - Then, if cr ~ libm: `tools/judge/perf_ab_commits.sh 8952c3d64 <final main>` (remote-quiet per run). If 8952c3d64 still
    reads ~7,7xx, walk batch 1's merges (a77395a49, 3b2bce5eb, e7bb2adcb, 25baad035, ffec9488f, ba6a54c1b) for the first step.
  - The first launch (831ad5471) was stopped on a busy box: 6 of 6 attempts REFUSED (2.53-2.59x), nothing judged.
  - Prior (not a result): a laptop micro-bench puts CORE-MATH at 8-16 ns a call; its fma through libm's PLT costs ~0.5 ns.
  - Single readings, builder0 (the orchestrator's): 8952c3d64 7,687 (R38.55); 76f42a9c3 8,366 (idle 74 %, load 4.25);
    2518811d0 7,899 (idle 51 %, load 5.34). Both mains have N4, so the +679 looks like single-reading spread. Not a verdict:
    the A/B decides, and its summary now prints each arm's range as a % of its mean (a single reading's noise).
- **GREEN: 0bb755a4f** (builder0, `make check exited 0`, 3169 passed / 0 failed, 25 of 26 targets passed, the 26th
  NOT JUDGED; 13 sim-baseline maps unmoved, determinism 258cc8b1c957a796). Perf-judge was NOT JUDGED (busy box, 3 refusals at
  1.78-2.06x), and so was scenario_perf, which only perf-judge judges here. 1f4fdac27 after it is docs only.
- **The full-check lock (tools/** for it is the orchestrator's grant):** tools/full_check_lock.sh, a flock on the builder,
  taken by remote.sh around every full check; builder_checks.sh counts the holder.
  - 0bb755a4f (feedback's finding: 3f1f35432's claim was the wrapper's alone): make inherits the claim; HUP/INT/TERM or a
    dead ssh session (watched, also while queued) stops the check's group. Live on builder0: killing the local ssh stopped
    the held command within 1 s and freed the lock.
  - test_full_check_lock 18/0; shell-tools-test 34 suites (laptop).
  - **GREEN 7d1078f0d (tools only; the orchestrator's gate: quick-remote + shell-tools-test):** feedback's report against
    0bb755a4f, reproduced live on builder2. A stopped wrapper left its queued AND its running check alive, for two reasons:
    the watchdog died by SIGPIPE writing to the dead session's stderr, and a waiter in a foreground flock could not run its
    trap. Fixed: SIGPIPE ignored, and flock waits in the background. Live after: both gone within 5 s, the lock free.
    quick-remote builder0 `exited 0` (no tests touched). shell-tools-test builder0 light lane `exited 0`, 34 suites,
    full-check-lock 22/0 (at 342da8b23, docs only on top). The 0bb755a4f script fails 3 of the new cases.
- **relay-smoke's stale host log (feedback's red at a2b560896), mk/net.mk (the orchestrator's grant):** logs are removed
  before their process starts; waits read the process's own /proc/<pid>/fd/1. test_net_own_line 3/0. In 0bb755a4f's
  check: host opened K735J, both clients NET_CHECK PASS.
- **The 8952c3d64 run.sh row:** builder2 when doctrine frees it (~14:30 PDT, doctrine says). If it would still run when
  CP39.1 lands (~16:30), it waits until after orders' Bar G3 v6.
**Orchestrator (R39.3):** it merges 8f018edf7 then bb8043686, then runs one main check; the trig perf line rides main's
own check on a quiet builder0. From now on only one stream runs Godot on the laptop at a time: wrap any laptop Godot run
in `flock /tmp/tank-squad-laptop-godot.lock <cmd>`; everything else on the builders.
**To playtest (the lead):** nothing changes on screen. `make skirmish SKIRMISH_FLAGS="--rules-off=sight,spread,pin_slow"`
plays the old rules; `make trig-info` says which trig this machine runs.

**Plan (order):** N1 first (doctrine waits) and running in the background → N2 → N3 (named by manoeuvre at ~21:45) → N4 →
N5 → stretch. Decided: N1 runs on main **8952c3d64**, the launch main (main 906557c06 differs from it in docs only).

- **N1 (CP39.0) RUNNING:** `tools/scoreboard/guard.sh 8952c3d64` on builder2.
  - Relaunched clean 21:13:55 PDT (systemd unit native-guard-8952c3d64c) after the orchestrator's builder2 cleanup voided
    the first run. That run was killed, and its remote folder and local raw dir deleted; nothing from it is kept.
  - On landing: `references/scoreboard/guards/8952c3d64.fights.jsonl` + json + the scoreboard row v 686150ed2, then
    message doctrine and the orchestrator at once.
- **N2 DONE (3c01cec03):** `make skirmish SKIRMISH_FLAGS="..."`, mk/play.mk's skirmish recipe only.
  - The flags go last, so LaunchFlags (last value wins) also lets them override the recipe's own. The default command is
    unchanged.
  - Test: tools/test_skirmish_flags.sh (in shell-tools-test). A fake Godot records the recipe's argv: 4/0.
  - Laptop smoke: `make skirmish SKIRMISH_FLAGS="--rules-off=sight,spread,pin_slow --screenshot=..."`. TANK_SQUAD_READY
    listed rules-off, and the screenshot flag saved the faction menu on The Locks (looked at).
- **N4 DONE (a577e3776), full check running on builder2:** machine-independent float trig. Design and proof:
  `_agents/native.md` "Machine-independent trig".
  - Vendored CORE-MATH (MIT, unedited, pinned 0ce0cbc1) for atan2f/acosf/asinf/atanf/tanf.
  - Native defines them hidden. The engine gets them through LD_PRELOAD from mk/native.mk, on glibc < 2.41 only.
  - **builder0 (2.43): CORE-MATH == libm on all 2^32 inputs** of the 4 one-argument functions and on 4e8 atan2f pairs,
    so nothing on the builders moves.
  - Laptop (2.39) v CORE-MATH: atan2f differs on 19 % of pairs, tanf on 83 M of 2^32 inputs.
  - Cross-machine digests: sinf/cosf/sincosf/expf/logf/powf were already identical.
  - **Laptop `make sim-baseline` (13 dealt maps) against the builders' glibc-2.43 lines:** 13/13 unmoved with the shim;
    control `TRIG=system` FAILED with 10/13 moved.
  - Cost: no function slower (ns/call, indicative, both boxes loaded).
  - Tests: test_native_trig.gd (engine atan2f known answer: 2/0 under make; FAILS under TRIG=system, as designed) and
    tools/test_trig.sh (6/0).
  - **R38.25's "never pair a laptop read with a builder read" can be lifted for runs through make** (orchestrator's call).
- **N3 DONE, GREEN: `pair/native-givewaychain` bb8043686** (on manoeuvre's 14a10e719).
  - Full check, builder2: `make check exited 0`, 3143 passed / 0 failed, 26 targets, 13 sim-baseline maps unmoved.
  - Quick, builder0: 104/0. Chain stages ON / ON owned / OFF: 105 drives each, 0 mismatches.
  - bb8043686 = 37735bf4b + the fix for manoeuvre's jam_census.gd:408 lint error (`var started: bool`), which failed the
    first quick. manoeuvre has the same line as d7259b161, so the merge is clean.
  - drive_native.cpp chain_in_play / chain_far mirror Movement._chain_reach / _chain_far, at the same two places in
    begin_yield.
  - Config: CHAIN_M (the ready flag) and CHAIN_SLACK_M.
  - traffic.gd's `_chain_native` is removed and test_traffic_chain's last case updated (manoeuvre's files, on the pair
    branch only).
  - Twin: test_native_yield chain stages ON, ON owned, OFF. 105 forced poses each, 0 mismatches, 0 called back (laptop).
  - Mutants caught: no slack, 4 mismatches; no under-way exemption, 18.
- **N5 DONE (78c5fff87):** SLOT_LOADED_PER_CORE / QW_LOADED_PER_CORE default 1.0 (was 1.5). test_loaded 11/0,
  slot-light 6/0, quiet-window 28/0 (laptop).

- **N1 DONE (407a156cb), messaged doctrine and the orchestrator (R39.2):** main 8952c3d64, builder2, 21:13-21:56 PDT,
  320 of 320 fights, 0 lost, 0 SCRIPT ERRORs. Base `references/scoreboard/guards/8952c3d64.fights.jsonl` (+ .json).
  - Blob wins 41 % (± 10 %), kr 0.78. Turtle wins 38 % (± 12 %), kr 0.82.
  - Paired v 686150ed2 (rules OFF): blob -5.6 points (se 2.9; 16 fights flipped to a loss, 7 to a win; McNemar p 0.047),
    kr 0.85 -> 0.78. Turtle -3.7 (se 3.8), inside its noise.
  - Not yet run: the fights/moves/orders part of the row (run.sh, ~1.5 h of builder2). Nothing waits on it. It goes at
    a doctrine chunk-boundary pause.
- **a577e3776 GREEN (builder2):** `make check exited 0`, 3137 passed / 0 failed, 26 targets, all 13 sim-baseline maps
  unmoved (N4 moves no builder sim).
  - The ai-scenarios gate held with one note: scout_suppress::test_target_crossing is pending but now passes.
  - That's the rules-ON effect, not N4: doctrine's tree (no N4) has already promoted it and passes it on builder0.
- **Stretch DONE (e8e7a8d46): the physics engine's share of a tick** (his question).
  - Run: builder0 light lane, `make physics-share`, 3 CPU v CPU fights (condemned mirror, 5200 budget, 120 s), 9,930
    ticks. The box was loaded, but the share is a ratio within each run.
  - **The engine (Godot's frame outside the scripts, mostly Jolt's step) is 4.2 % of a tick.**
  - **`tank/drive` (motion model + move_and_slide) is 4.1 %. So physics is at most 8.3 %.**
  - An infinitely fast physics engine would make a sim at most ~9 % faster. The scripts (brains, orders) are the other
    ~92 %. Check time is mostly sims, so the same bound holds for a check.
  - Laptop (indicative, one 20 s fight): 6.7 % + 6.0 %.

**Merge notes (shared files):** mk/play.mk (C39.6 GRANT); tests/test_native_trig.gd and tools/test_trig.sh,
tools/test_skirmish_flags.sh (new); `game/ai/native/native_drive.gd` (the native seam; not in round 39's owned list, it was
native's in every earlier round) on the pair branch only.

**Lessons (round 39):**
- A live test of anything that runs over ssh must keep the SAME stdio as the real path. 0bb755a4f's builder0 test sent stderr to
  a file and passed; with stderr on the ssh pipe, as remote.sh has it, the watchdog died by SIGPIPE (7d1078f0d).
- Kill only by recorded pid, even in scratch: one `pkill -u $USER -f` on builder2 matched nothing else, but it is against
  the contract.

**Questions for the lead:** none.
