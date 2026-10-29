# Stream: native (builder runs that never hang on a cold import; gate_width in C++; twins for what ships; the round's lines)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 45** (C45.1, C45.4). Your last brief:
> `streams/archive/round44/native.md` (Status: N1 report, N2 exact replay, the backout twin r3, lines_r44). **You own:** `native/**`,
> `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`,
> `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tools/builder_checks.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe, `mk/gcp.mk`, `_agents/judging.md`, `tests/replay_orders.gd`,
> `tools/recording_arrivals.py`, `tools/playtest_report*`, `tests/replay/**`; GRANT `game/control/rts_controls.gd`'s `gate_width` for
> the C++ seam only (the GDScript body stays as the fallback). **Model:** Opus. **Machine:** builder0 (quiet window for perf); builder2
> for rows. **Seeds:** 11501-11524.

## The lead's direction

"Core components in C++ long-term" (memory, 2026-10-12). He feels hitches on the laptop on purpose (memory: the laptop is the test bed).

## Where things stand (main at launch: 972e4bb57, code a93271a66 GREEN builder0 3446/0, see HANDOFF)

- **Cold import:** Bar B1 lost 4 h when builder2's fresh `godot-manoeuvre-b1-light` hung on its first import (Oswald-Latin.ttf at 0 %,
  18:21-22:23, killed at the 14400 s slot). Nothing noticed until the slot timed out.
- **gate_width:** a right click on 30 units / 6 squads reads 236 workloads v the control-timing budget 104 (builder0 quiet, orders
  57a20c9a4, 10.38 ms); 258 on aa9753028 (R43.41); `test_control_scale.gd` header R43.11: past MAX_SQUADS 5 the rest is one
  `RtsControls.gate_width` scan. JUDGED FAIL on that line since round 43.
- B1's lines are not yet in `tools/judge` (lines_r44 has G1 v10c, S v3, A6 v3).
- builder2 is Spot and was preempted twice on 10-28 evening (`make gcp-start` restarts it).

## Backlog (in order)

1. **N1 the cold-import watchdog.** `tools/remote.sh` (both builders): an import that shows no progress for N minutes (say 10; pick
   and record why) is killed, the `.godot/` import cache for that folder is cleared, and the import is retried once; the second
   failure ends the run with one clear line (`>> remote: import hung on <file>`), never a silent slot timeout. Test it with a fake
   hang. Merge alone when green.
2. **N2 gate_width in C++** (C45.4): output-identical first (the control probe and the G1 orders probe byte-identical, native on v
   off), then `control-timing` JUDGED on builder0 quiet: the 30-unit right click under budget. Merge alone when green.
3. **N3 twins for what ships:** manoeuvre's M1 + M2 backout changes (Bar B2's tree), and orders' G2 / engage's E2 if either touches
   the drive (C45.4); pairs proved EQUAL, merged with the ship.
4. **N4 lines_r45** (B1's lines, G2, E1, B2, S v4) and the judging table for the round's bars; the quiet perf read of main after each
   ship.
5. **N5 the replay to the end of his match:** `make replay-match` on the Gorge recording for the full 107 s (engage needs the scout's
   last 25 s): report where it diverges, and fix what you can.
6. **Stretch:** a builder2 preemption auto-requeue in `tools/remote.sh` (read the verdict line; re-run verbatim once).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make native` + `make native-info`; `make control-timing` quiet;
the watchdog on a staged hang. Every number with its commit and machine.

## Don't touch

`game/control/**` beyond the gate_width seam (orders), `game/tactics/**` (engage / manoeuvre), movement / traffic (manoeuvre),
`game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Report (2026-10-29 ~14:35 PDT).** **N1 DONE** (main 47a15f434 = 9b6ffb0a6). **N2 DONE** (main eec905e52 = dc182916f, GREEN
builder0 3448/0 ALL JUDGED); its judged `control-timing` read on builder0 quiet is WAITING for the window (engage's check holds the
last slot). **N3:** the B2 twin delivered (pair/native-backout-b2v2 04ce3abe9, EQUAL; merged into manoeuvre's freeze); B2b withdrawn
(R45.14, backout OFF this round). **N4:** B1's lines (lines_r44), B2's lines (lines_r45); G2 / E1 / S v4 / A6 v4 land with their
verdicts. **N5 DONE:** his Gorge match replays exactly to 107 s. **Stretch DONE:** the preemption re-queue. Also: engage's
native-fresh hole fixed; R45.3's untangle re-proof on orders' G2 candidate EQUAL; R45.16 (port G2's own cost) granted after G2's
final freeze.

**Plan (order kept from the backlog; reasons):** N1 watchdog -> N2a gate_width C++ -> N2b untangle_whole C++ (GRANTED R45.3,
because gate_width alone cannot reach the budget, below) -> N3 twins as manoeuvre/orders/engage ship -> N4 lines_r45 + judging ->
N5 replay to 107 s -> stretch requeue.

**N1 the cold-import watchdog: DONE. GREEN 9b6ffb0a6 builder0, `>> remote: make check exited 0`, 3446 passed / 0 failed, 28
targets ALL JUDGED; merged alone as main 47a15f434.** It ran for real on builder2 the same day (`import exited 0 in 20 s`). `tools/import_watchdog.sh` runs inside the slot
`tools/slot.sh` grants when `tools/remote.sh` exports `TANK_SQUAD_IMPORT_WATCH` (both builders; `REMOTE_IMPORT_WATCH=0` is the
escape; `IMPORT_WATCH_STALL` the limit). Progress = the last Godot progress line CHANGING: B1's hang printed the same
`[   0% ] reimport | Oswald-Latin.ttf` 14,369 times over 4 h (1/s), so "no output" would never have fired. Stall limit **600 s**:
in 20 builder logs of rounds 40-44 no honest progress line repeated more than 6 times (~6 s), and a whole cold import of the
project on builder0 took **15 s** (godot-native-light after .godot/ was cleared, 9b6ffb0a6), so 600 s is ~40x a whole cold
import and a double hang costs 20 min, not the slot's 4 h. On a stall: kill, `rm -rf .godot`, import once more; a second stall
ends the run with `>> remote: import hung on <file>` as the wrapper's LAST line and exit **75** (make alone said 2).
Proof: `tools/test_import_watchdog.sh` (in shell-tools-test) 21/0 on the laptop: fake hang twice (exit 75, the line, .godot/
cleared, command never runs, no orphan), hang-then-clean retry, silent hang, slow-but-moving left alone, TERM kills the import,
slot.sh seam on/off/nested. Staged on builder0 end to end (light folder, `IMPORT_WATCH_CMD=` a fake hang, stall 15 s): killed,
retried, `>> remote: import hung on staged-hang.ttf`, wrapper exit 75. A warm import costs ~3 s extra per run (laptop 9 s).

**N2 profile (laptop, native OFF, 0b62c4900 + temporary timers not committed; test_control_scale 30 units / 6 squads, mean of
10 orders):** order 29-31 ms (ratio ~234 v budget 104). `SelectionSquads.untangle_whole` **13.8 ms (44 %)** (the 720-permutation
search); `RtsControls.gate_width` **10.5-11.4 ms (36 %)**: 1 call, 100 steps, ~200 `Pathing.find_path` = 5.6 ms + Callables and
the near_deck sampling; setup to `ranks` 3.9 ms; the rest < 1.5 ms. gate_width at ~0 still leaves ~150: hence N2b (R45.3).

**N2 = N2a gate_width + N2b untangle_whole in C++ (69b95f56e; R45.3 granted N2b): EQUAL on builder2; full check running.**
- builder2 dev run (`native test`, the twins + the control tests): **48 passed / 0 failed, `exited 0`**.
  `test_native_gate_width`: 360 clicks (crossing, gorge, locks, terminus), **0 mismatches**, every deciding branch taken (deck 11,
  edge 508, detour 50, read past posts 80, click on a deck 20, full scan 151). `test_native_untangle`: 1200 knots (2-7 squads,
  leads/arc, misplaced, loose anchor, empty squad), **0 mismatches**, 1022 re-dealt. `test_untangle_whole_memo` (native v the
  round-43 reference) passes.
- **The orders probe on v off (C45.4), builder2, 69b95f56e, native on, dev seeds 7001-7004, 3 maps x 3/5 squads x click/route:
  today's default 192/192 rows byte-identical; `--group-column=always` 192/192** (evidence
  `references/round45/native/n2-orders-probe-builder2-69b95f56e/`).
- test_control_scale, 30 units / 6 squads: **ratio 89.2 (10.16 ms) v budget 104 on builder2** (not a judging machine). Laptop
  before, native off: ~234. The judged read is `make control-timing` on builder0 quiet, after the check.
- Names: `NativeGateWidth` / `BrainSwitches.native_gate_width` / `gate_width_native.cpp` ("gate" is already the drive's gate rule
  and its twin, tests/test_native_gate.gd: my first cut overwrote that test by name; restored before any commit).

**N2a gate_width C++ (design):** `native/src/gate_width_native.cpp` (one navmesh query a step serves crosses_on and drive_on: the
same `find_path(ground, click, p)`; the deck test a loop over `SlotGround.deck_boxes()`; `Orders.clamp_to_arena` called back once a
step). Seam `RtsControls.gate_width_edge_on` (new, beside gate_width; the GDScript gate_width untouched as the fallback) at the
ONE call site the group click uses (rts_controls.gd column_lay's width_at, a one-line edit; told orders). Switch
`BrainSwitches.native_gate_width` (ON). Equality: `tests/test_native_gate_width.gd` (4 arenas x 90 clicks, each deciding branch counted).

**N3 manoeuvre's M2 (b) stalled departure leg (R45.4): twin v2 on 57e02fed5.** Pair folder `godot-native-backout` (offset 8).
- v1 pair/native-backout-b2 (on 0af772a85): b2b129f9f the twin; native-proof with `--traffic-on=backout` **EQUAL** on builder2
  (4a04ea921011cd9a, on = off = ab). Its stage, `tests/test_native_drive_backout_stall.gd`, went through three cuts: a static box
  is a WallContact (lead_hit ends the leg first: 0 stalls, manoeuvre's 27f00d3f0 check 3446/1); a live parked rig is shoved, and
  against it real velocity flips sign every tick, so v1's velocity rule never counted past 1 tick (trace sent to manoeuvre, who
  then changed the rule); `process_mode` off alone takes the body out of the space (drove through). **Stage now: a FIXED parked
  rig, process off + `DISABLE_MODE_KEEP_ACTIVE`**: v1 stalled at t33, 1189 drives / 0 mismatches.
- **v2 pair/native-backout-b2v2 5ad8f5d39** (= 57e02fed5 + the twin, re-cut): `_backout_stall_from` (Vector3, INF) beside
  `_backout_stall_ticks`, window reopened on 1 m of progress (`BACKOUT_STALL_PROGRESS_M`), 30 ticks. Proving on builder2: the twins
  + manoeuvre's stage, then the default orders probe (5 squads, click, 7001-7004, base v bo).

**N5 (his Gorge match to the end): DONE, nothing diverges.** `make replay-match RECORDING=references/round44/playtest/
2026-10-29T09-35-51-gorge.jsonl REPLAY_SECONDS=107 CREWS=all`, builder2, 0e645dd5e, native ON: `DIVERGENCE crews=20 within=20
bar=3.0m seconds=107 first_over=- verdict=PASS`; Green_Hunters_5 0.0 m every second to 105 s, dead at 106 (his 105.3 s). The
native and GDScript replays (NATIVE=off, a fresh light folder) are **bit-identical**: 3042 crew-seconds of census, 489 / 489 rows
after the header, and both equal his recording (census grain 0.1 m, 1 Hz). Evidence `references/round45/native/n5-replay107-*`.

**Engage's report (a fresh folder ran GDScript in silence): FIXED, dc182916f.** `native-fresh` builds the library where none was
ever built (NATIVE != off + a toolchain; never under `make -n`; native-off folders stay off); builder2 fresh light folder: "no
library in this folder yet; building it" -> native ON, exited 0. `replay-match` exits 3 on REPLAY_NATIVE_MISMATCH unless NATIVE=off.

**Stretch (Spot preemption re-queue): DONE, dc182916f.** `tools/remote.sh`: ssh / rsync 255 while gcloud says the VM is not
RUNNING = preempted: start it, re-run verbatim ONCE, or (the builder's verdict line had arrived) copy build/ back only and exit with
that verdict; one line says why. `tools/test_remote_requeue.sh` 9/0 (fake ssh / rsync / gcloud).

**R45.3 re-proof on orders' G2 candidate (pair/native-g2 cfa4a0eb2 = a8adba232 + stream/native), builder2:** 68 / 0 tests;
orders probe native on v off **192/192 guard ON, 192/192 `--group-guard=off`** (guard on v off differ 192/192: the guard ran).
Orders' new `misplaced` is pure (captured arrays only), so asking it every (squad, anchor) before the search is equivalent.
**G2's two gate_width reads through gate_width_edge_on** (c7444d484): EQUAL (768 rows = the unswapped tree's), ~1 ms (20.53 ->
19.59 ms, builder2): sent to orders for its ship commit.

**G2's cost on the 30-unit click (R45.16 prep; timers uncommitted; 30 units / 6 squads, mean of 10):** builder2 native ON 20.5 ms
(reference 0.193 ms: builder2's e2 cores are SLOWER per core than the laptop's): setup + the fit read 9.5, guard_lay 6.6,
untangle_whole 0.8 (native), ground_cap 1.2, given 1.1. Laptop native OFF 17.1 ms (reference ~0.115): fit 7.6, guard_lay 2.6,
untangle 5.7. Next (after G2's final freeze): split the fit stage and guard_lay finer; port what dominates behind a switch.

### Requests to other streams
- **orders:** rts_controls.gd: one line in `_order_squads`' column_lay call (`RtsControls.gate_width` -> `gate_width_edge_on`,
  same Callables) and the new `gate_width_edge_on` above `POST_SPAN_M`. N2b: one guarded seam line at the top of
  `SelectionSquads.untangle_whole` (R45.3).

- **orchestrator / manoeuvre:** after G2 merges, I re-prove N2b EQUAL on orders' tree (R45.5).

### Questions for the lead
- None.
