# Stream: brains (respawns never overlap a standing hull; a pushed-off rig returns to its post facing his way; seats stop jumping without blocking a squadmate; the yard's last crew in)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/doctrine.md`,
> `_agents/workstreams.md` **Round 33** (C33.3, C33.4, C33.5; R32.3, R32.6 stand), `_agents/roadmap.md` *Round 33
> candidates*, `_agents/orientation.md` trip-ups 82–83, and your round-32 brief `streams/archive/round32/brains.md` (B10's
> and B11's tables and readings; *Not reached*: B5c-v6). **You own:** `game/ai/**` EXCEPT traffic's, manoeuvre's,
> native's and the planner's carve-outs (`workstreams.md` *Round 33* ownership), `game/tactics/**`, `tests/ai_scenarios/**`
> (others add their own `scenario_<stream>*.gd`), `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`,
> `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `tests/test_wheeled_arrival.gd`, `mk/ai.mk`,
> `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`. **Granted this round (C33.5):** the respawn spot in
> `game/match/match.gd` (`tank.respawn(_jittered(spawn_position(...)))` ~2128 and one helper beside it; merge note).
> **The C++ (C31.2):** `decide`, `build_situation`, TacticalQuery and `_approach_gate` run in C++; v6's side-gate mirror is
> on `pair/brains-v6-carry`. **Model:** Opus.

## The lead's direction

Round 24: every squad across his bridge (shipped, 108/108). Round 28: the gate's job is the yard's last crew in. Round 28,
call 2: turn the whole vehicle to his drawn facing. No new words at round 33's preparation.

What he will notice: a vehicle respawning never appears inside another one; a War Rig shoved off the spot he told it to
hold drives back and faces his way; a crew's spot stops jumping about while its squad jostles, without it parking in a
squadmate's path; at the yard the last crew gets in.

## Where things stand (main at the round-33 docs commit; inherits `0c124cf7`'s green check: builder0 exited 0, 2724/0)

- **Shipped in round 32:** B3b-2c (his bridge 108/108), R32.6's fix (the test stage's overlapping spawns, trip-up 82).
- **Respawns can overlap (your round-32 finding):** `match.gd` ~2128 respawns at `_jittered(spawn_position(...))` with no
  check against hulls standing near the slot; physics recovers from an overlap differently in a process's first match and
  later ones (trip-up 82), so a session's later matches can play differently.
- **B11 PARKED** (`--hold-return=faced`, OFF; `c029cf70`/`ffba7f77`): turreted wheeled faced_move 48.4 → 17.3°, but
  wheels/fixed worse (7.5 v 3.0°, p 0.000) and s66 Green_Guns_5 still > 100° (needs the face at rest: manoeuvre's CP-F).
- **B10 PARKED** (`--ground-latch=on`, OFF): flips 22 → 0 on Sumps s16 t8, but Sumps s19 t8 +19.9 s (the held seat stood
  in two squadmates' passage).
- **B5c-v6 not reached:** `lab/brains-r32-gate` `b8a34c4f` (v5 + side gate + the latch; tuning n 1: Sumps s17 t11 35.8 v
  34.8 s, yard s27 t8 10/10 v 9/10); native's mirror on `pair/brains-v6-carry` (33db0ac1 + ba8d18d9).
- Your round-32 branch is `round32/brains` (merged).

## Backlog (in order)

1. **R1 Respawns clear of standing hulls (C33.5):** the respawn takes the nearest clear spot to its slot (the hull's
   footprint v every standing hull's), deterministic for both peers; a test that fails without it (a big hull respawning
   beside a parked one), mutation-checked; a check; name the hash. A sim-baseline move goes to the orchestrator with the
   reason. Ships alone.
2. **R2 B10b (C33.4):** the latch held only while the latched point is out of a squadmate's route corridor (or one
   re-ground with hysteresis); one reason for the form chosen. Bar first: Sumps s16 t8 flips (pass case), Sumps s19 t8 time
   (the case B10 failed), the arrive series within 8 m not below base − 1.645 se, fresh seeds. Ships ON if it passes.
3. **R3 B11b (C33.3), once manoeuvre's CP-F merges:** HOLD's return honours the post's facing for `mount == "turret"`
   wheeled hulls only; judged on a base with CP-F ON; pass case s66 Green_Guns_5 ≤ 90° in ≥ 2 of 3; no class worse at
   p < 0.05; never-settled within its line. If CP-F has not merged when you reach this, do R4 first.
4. **R4 B5c-v6:** v5's gate + planner's side gate for yard s27 t8, on a base with B10b ON if it shipped (else main); the bar
   as round 32 wrote it (Sumps s17 t11 and yard s27 t8 the pass cases, pursuit as R31.3's count); traffic may send you T4's
   circling-hull trace (the same yard head-on): read it before the series.
5. **R5 If traffic's CP-X design chooses an element make-room (C33.2 (2)(b)):** the seam, signature agreed through the
   orchestrator before either side writes code; this pre-empts R4.
6. **Stretch:** T1c-b2's price (round 32): in 6 of 18 fights a mortar truck waited ~20 s behind ANOTHER set-up mortar truck
   of its battery and two set up 10–19 m short. A battery's firing spots chosen so one truck's spot is not behind another's
   set-up truck. Trace first; bar before numbers.

## How to verify

`make quick-remote` to iterate; the pair-tree `make remote T=check` with the switch ON before any series, only for hashes
you name. `make squad-arrive-series`, `bridge-series` (the 108), `bridge-pooled`, `screen-slots`, the
hull-rest drawn series (B11's), `native-verify-scenarios`. Long remote runs under `systemd-run --user`. Every number:
commit, machine, workload, n, its row. A test that builds a `TacticsLab` must `dispose()` it (trip-up 83).

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; manoeuvre's drive body / unstick / H1 / H1b / k-turn executor / face
path, `manoeuvre*.gd`, `wall_contact.gd`, the two gunnery lead lines, the `_order_move` decline; the planner's
`game/ai/planner/**`; native's `native/**`; `game/control/**`, `game/tank/**`; `game/match/**` beyond the respawn grant;
`arenas/**`; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### OVERNIGHT REPORT (2026-10-18, for the lead's morning read; every number builder2 unless said)
1. **Battery item:** the three switches together FAILED the census (first shot 9.0 v 3.3 s, never-past askers 2 v 1).
   **R33.27: switch (a) alone PASSED and is MERGED** (main `32e74084` = `1ea8ce40`): set-up battery crews keep their seats;
   census 53–58 n 18: far set-ups 39/86 v 118/193, art shots 377 v 240, no stuck batteries, first shot 3.0 v 2.5 s.
   (c) deploy-at-place PARKED, (b) arrivedgate DROPPED.
2. **Scout fights back: FAILED, PARKED (R33.31).** At SPOT 0.15 (re-filed: at 0.7 the rule fired and SPOT still won),
   ENGAGE was chosen on 90 % of firing ticks and shots rose x1.62, but the damage median rose 190 v 186 and 3 close-orbit
   cells v the faster, longer-ranged syn_scout were > 20 % worse. A duel-only retry is a round 34 item (seeds 73–79),
   waiting on your stand-or-hang-back answer.
3. **War Rig 4-of-5: PASS, MERGED (main `c583e0a8` = `befd86c2`)** (lab/brains-warrig-main). Cause traced: a squad sent to the arena
   edge had its seats clamped onto the edge, so its centre never came within 12 m. Fix: on the final approach (60 m) the
   spot moves inland at most 15 m, and an element still folded on the edge arrives at its laid seats. Seeds 8–14: every
   element in, 10/10 v 5/10; largest inset 15 m; squad-arrive 100 v 100. **What you'd see:** a squad sent to the very
   edge stops up to 15 m inland of your click and reads arrived.
4. **Respawn rejoin: PASS, MERGED (main `6703d74d` = `d5c98eb7`)** (lab/brains-rejoin-main, on main per R33.32). A crew back from a
   respawn rejoins its squad's element: 1-crew elements 2 v 1595 in 16 respawn fights; kills/deaths within noise.
Rows: `references/round33/brains/` battery_series_ee18403b9, battery_a_1ea8ce40, scout_series_0565d1a8,
rejoin_d5c98eb7, warrig_befd86c2 (all _builder2.txt). Main's check with both merges is the orchestrator's (builder2).
**Round 34 notes:** the War Rig trace does not log the inset's engage distance (reported-only in (1b)); add it.
The duel-only scout (advantage >= 1, reach judged over the next 1–2 s, seeds 73–79) waits on the lead's answer.
B10b stays parked (R33.22), with --ground-latch on stream/brains. B11b waits on CP-F (R33.23).
Process notes: rejoin's first stage (showmatch) could not act (elimination: nothing respawns) and its second tree
carried parked B10b; both caught before a merge, re-run on fresh seeds. builder2 fresh folders race `npm ci` in
broker-test/relay-smoke; seed node_modules AND touch its .package-lock.json.

### NOW (2026-10-17; order by ruling: R1 → R33.9 → R33.6 → B10b's series)
- **R1 MERGED** (`2fd9f420` → main `07b8e99a`, on `429ebc4b`'s green check per R33.10).
- **R33.9: the bar PASSES on (a), (b) and (c)**; the verdict with tables went to the orchestrator 2026-10-17. Merge `429ebc4b` on its
  own check (builder0, 2731/0, sim-baseline 13 maps unmoved). The measurement commits and readers stay in the lab.
- **R33.9 MERGED** (main `9396e795`). **R33.6 rebased onto main `e420b524`: `71f80a70`, then `fc195815`** (+ the respawn test, orchestrator b800a6aa: 3/0 laptop, its trigger mutation fails 2) (lab/brains-r336; 70ffe28e's
  measurement dropped). Laptop, `71f80a70`: test_tactics_squad_split 2/0, and the element/commander/respawn/arrive tests
  33/0, 0 engine errors. Its builder0 check is HELD until the orchestrator reports main's check exit line (no doubling up).
  **Its check on `fc195815` (builder0): `make check exited 2`**: 25 passed, 1 FAILED (web-smoke), 0 NOT RUN. Tests
  2735/0, sim-baseline 13 unmoved, determinism `9d66d3a0c59a7936`. The FAIL is web-match-smoke's "first sound 31.5 s after
  READY (bound 30 s)" at load 30.8 (page 2 fps); R33.6 touches no web or audio code. **web-smoke re-run alone GREEN**
  (builder0, `make web-smoke exited 0`, first sound 11.7 s at load 12.6). By the orchestrator's ruling that completes the
  check: **`fc195815` is GREEN**, for merge with `f8cf6476` cherry-picked after it.
- **R33.6 MERGED** (main `863cb199`); f8cf6476 cherry-picked as `279600af`.
- **B10b: check GREEN, series FAILS line 2 (2026-10-17).** Check on stream/brains `99e867ee` (main `9e8e4b2f` + B10b
  ON), builder0: `>> remote: make check exited 0`, 26 targets ALL JUDGED, 2740/0, sim-baseline 13 unmoved, BRIDGE_POOLED
  18/18 (two earlier tries lost to builder0's link drops, exit 255, no verdict). Series, builder0, `99e867ee`, n 1 a case:
  **line 1 PASS** (s16 t8 on 0 flipping crews; off flipping, 22 drift moves, never all in); **line 2 FAIL** (s19 t8
  all-within-8 m on **100.8 s** v off 69.4 s, bar off + 5; b10 89.3 s). Stopped there (a failed line decides).
  **Line 8 trace** (builder0 light, settle_probe --trace=on; the laptop's GDScript drive reads 35.3 v 35.3, so native path
  only): Green_S_1 circles inside its approach gate's turning circle t=78–98 (goal (11.0,-57.4), gate (-2.6,-55.4)), S_4
  likewise t=30–79: R33.8's loop. The latch holds the seat, so the gate holds; off's drifting seat frees it by accident.
  **With R4 under it** (pair/brains-v6-r4 `97c3b654`, light lane, n 1, TUNING): s19 on 38.8 v off 42.4 s, s16 36.2 v 36.5,
  0 flipping either arm: **TUNING, not evidence.** **Ruling R33.18:** B10b's FAIL stands; R4 first, on main; if R4 ships,
  B10b is re-judged on main + R4 (bar unchanged, a fresh check, the same named cases, the census not yet run).
- **R4's pair on MAIN: `pair/brains-r4-main` `e382202e`** (main `d99394f1` + v6 narrowed + inside_circle + native's mirror,
  without B10b; the net of `97c3b654` v `7300e5cd`, docs excluded; worktree godot-brains-v6). Laptop: gate/wheeled/
  planner-seam/nav/ground-latch tests 145/0. Next: native's light `test_native_gate|nav_gate_inside` at 0 mismatches,
  then the full check (C31.1), then R4's series on that hash.
  **Pair now `45d5f1ea`** (accepted: an arms-plumbing commit before any number): `gate-series` knobs GATE_DRIVE (default
  `--brains-off=native`) and GATE_OFF (default `--nav-off=gategiveup`), a `yardhead` cell (yard_open head-on s42 t3), and
  `gates_inside` / `circle_reverses` in the probes. R4's arms: `GATE_DRIVE=` (native path) and
  `GATE_OFF=--nav-off=gateside,gateinside`. Twins on e382202e or 45d5f1ea both count.
  **Twins GREEN** (native, e382202e, builder0 light lane, n 1): `>> remote: make native test FILTER=native_gate|nav_gate_inside
  exited 0`, 8 passed 0 failed, 0 mismatches in all four stages, NATIVE_EXEC 19999 native / 0 handed back.
  **Check GREEN on `45d5f1ea`** (builder0, full check, n 1): `>> remote: make check exited 0`, 2759 passed 0 failed,
  26 targets ALL JUDGED, sim-baseline 13 unmoved, BRIDGE_POOLED 18/18, determinism 9d66d3a0c59a7936.
  **R4 VERDICT: PASS, ships ON** as one pair with native's mirror: `pair/brains-r4-main` **`45d5f1ea`** (check green
  above), arms `GATE_DRIVE=` (native path) v `GATE_OFF=--nav-off=gateside,gateinside`, builder0, 2026-10-17. Rows:
  `references/round33/brains/r4_series_45d5f1ea_builder0.txt`. In filed order:
  (1) yard s27 t8 10/10 both, last 22.1 v 22.1 PASS; Sumps s17 t11 58.3 v 58.3 (≤ OFF+2) PASS (R4 did not fire: inside 0
  both); yardhead s42 t3 Green_A_5 17.1 v 17.1 (≤ OFF+5), circle reverses 0 v 2 (≤ 20) PASS, ghost OFF; ghost ON NOT run
  (traffic's ghost is opt-in, off on the base tree). The side gate never fired on yard s27 t8 (inside fired 3).
  (2) pursuit-aa 24/24 both arms as written and nudged, no let-go at 18 m/s, identical rows PASS.
  (3) yard cell n 12: every crew in 12/12 v 12/12, never fewer crews ON PASS; last-crew median 20.1 v 23.9 (reported).
  (4) Sumps cell n 12: median 24.0 v 24.0, no run > 5 s later, guns_on_arc 0.950 v 0.950 PASS.
  (5) Terminus s8–11 t11 n 4: median 47.5 v 47.5 (s10 71.7 v 70.0).
  (6) arrive n 100 seeds 61–64: all-within-8 m 97 v 97, floor 97.0, 0 discordant PASS (every-crew-on-slot 87 v 86).
  (7) the faced-finish tests are in the green check (native on); gates_side/gates_inside 0 on every OFF run; ON: inside
  > 0 on 33/36 runs, side > 0 on 4 (yard s30 t6/t8/t11/t16). (8) check green on 45d5f1ea, sim-baseline 13 unmoved.
  (9) traced AFTER the reader printed the medians (it prints both at once; said so). Worst ON v OFF, yard s30 t1 20.5 v
  19.1: rerun on the GDScript drive (twins 0 mismatches) reproduced every number. Green_B_1's gate dropped by
  inside_circle at t≈10–12, so it drove onto its slot, in 14.3 s (OFF: blocked on terrain, last in at 19.1). The late
  crew Green_B_5 was NOT acted on (gate_dropped_for inf both arms). At t=12–14 it met Green_B_4 (yielding to it),
  turned about 43° left onto terrain, was blocked t=14–18, and got in at 20.5 (OFF 14.6): a knock-on through SquadB's
  traffic. Worst Sumps ON, s22 t3, 71.9 v 74.4: Green_S_4 last in both arms, ON 2.5 s earlier. `--gate-trace` prints
  nothing in the crossing probe: its orders carry no facing (`movement.gd:973`).
  **Merged: main `54abf20a`** (= 45d5f1ea, over N5.Y's drive_native.cpp). Lesson for next round: the reader prints the
  worst runs before the medians.
- **B10b re-judged on main + R4 (R33.18), bar unchanged.** stream/brains rebased onto main `54abf20a` (clean; the old tip
  tagged `brains-pre-r4-rebase`). B10b's code diff from main is element.gd, tactics_flags.gd, mk/tactics.mk,
  ground_census.py and test_tactics_ground_latch.gd. Laptop: ground_latch, nav_gate, wheeled_arrival and squad_split
  35/0. **The pair is this commit.** Its full check, then its series, run on **builder2** (orchestrator: every step and
  both arms there, every number labelled builder2). Series script `b10b-series-b2.sh`: the named Sumps s16/s19 t8,
  the census (seeds never read: the census at 99e867ee was stopped before any number), arrive 53–56 on v off, then cost
  on v off, run one after another.
  **builder2 check on f91b61c7: `>> remote: make check exited 2`**, 2770 passed 3 failed, sim-baseline unmoved. The
  failures are native EXERCISE floors, every twin at 0 mismatches: test_native_gate latch ("a crew came round its gate
  (0)"), test_native_yield sumps (negotiations 96 >= 115, parked_refusals 0 >= 20, asks_refused 0 >= 1) and sumps_owned
  (115 >= 120). **Not B10b:** on builder2, `native test FILTER=native_gate|native_yield` (n 1 each) gave main `54abf20a`
  9/1 and the pair 9/1, the same sumps floor lines. The other two passed in both filtered runs, so they look order- or
  wall-clock-dependent. **R33.20:** those three reds are main's own known coverage-floor defect (native is moving those
  stages into fresh processes), so this check is enough to START the series; the MERGE waits for a fully green check
  with native's fix. The builder0 check was stopped and its remote processes killed by cwd (0 left, --status IDLE).
  **B10b RE-JUDGE VERDICT (builder2, pair f91b61c7, tree c2ba1756 = Status-only on top; 2026-10-18): FAIL AS WRITTEN on
  line 3's strict clause; every other line passes.** Rows: `references/round33/brains/b10b_rejudge_f91b61c7_builder2.txt`.
  Worst runs read first (line 8): no ON run is later than OFF anywhere. The named cases are the only runs where ON
  differs from OFF.
  (1) s16 t8: flipping crews 0 on, PASS. **But OFF no longer flips either (0 flipping, 2 drift moves): with R4 on main,
  main's flip case (22 flips, never in) is gone.** all_in8 36.23 on v 36.50 off.
  (2) s19 t8: 38.77 on v 42.37 off (≤ OFF+5) PASS.
  (3) census n 28 (Sumps 12, yard 12, Terminus 4), seeds unread before: flipping runs 0 v 0 (≤) PASS; **pooled drift
  moves 112 v 112, so "on < off" FAILS** (Sumps 40/40, Terminus 31/31, yard 41/41); Sumps all_in8 median 24.57 v 24.57,
  no run later PASS; yard crews in 119 v 119, equal every run PASS. **ON and OFF are identical in every field in all 28
  census runs: the latch never acted on fresh seeds.** b10 (corridor off) did act once: Sumps s21 t16 43.67 v 37.87.
  (4) arrive 53–56 n 100: 98 v 98, floor 98.0, 0 discordant PASS (every crew on slot 85 v 84).
  (5) sim-baseline 13 unmoved PASS. (6) check: BRIDGE_POOLED 18/18; red only on R33.20's known floors (merge waits).
  (7) t.poll.element on Locks 0.039 v 0.039 ms (builder2; ≤ 0.5) PASS.
  **R33.22: PARKED** (orchestrator, agreed). `--ground-latch` stays on stream/brains for manoeuvre's R33.21 re-seat trace.
  Reading: on main + R4, B10b does no harm and acts only on the two named cases. The drift it was built for is no
  longer on main's fresh seeds. The orchestrator rules (ship as harmless, or park it until a case needs it, e.g.
  R33.21's re-seats, where manoeuvre traces the latch as an arm).
- **B11b: BLOCKED, no CP-F hash this round** (R33.21: CP-F parked; crews still moving at the judge on ambush/move/screen;
  on ambush 39 of 55 movers drive 8–28 m after facing, which is re-seats, B10b's territory).

- **R2 B10b** (`2ce42aaa` on stream/brains): its bar is filed; its series runs on a tree with R33.9 + R33.6.

### R33.9 (the orchestrator's ruling; manoeuvre's F1 trace): the element's arrival latched per task
- **Bug on main:** `element_plan.gd:290` and `:686` read `arrived = centre within ARRIVE_M` afresh every plan; the arrived
  layout (halt on the spot, his heading) and the travelling one (the other way) pulled the centre across 12 m and back,
  every seat jumping ~20 m a flip (gangs hull-rest faced_attack_move s40: Battery 67 flips, 286 re-seats, base arm).
- **Fix** (`429ebc4b` on `lab/brains-r339` = R1 + it; worktree `godot-brains-r339`): `ElementPlan._arrived_at`: once
  arrived on a task, arrived until the centre is ARRIVE_M + ARRIVE_LEAVE_M (6 m) out; `Element.assign` clears it per task.
  6 m: half the arrive radius, above a five-crew swarm's centre swing on a re-seat, far below a real departure.
  `--arrive-latch=off` = main. GDScript only (ElementPlan has no C++ twin; native told). Measurement: `70ffe28e`
  (`Element.arrive_flips`, `--arrive-trace`). Test `test_tactics_arrive_latch` (3/0 laptop; its control-arm test shows
  main's rule reads 14 m as not arrived).
- **Bar (filed before numbers, in workstreams *Bars (round 33)*):** (a) s40 Battery arrive-flips 0 on, re-seats on < off;
  (b) arrivals not down: the hull-rest faced_attack_move cell's settled crews on ≥ off, squad-arrive 57–60 (n 100)
  all-within-8 m on ≥ off − 1.645 se; (c) the check, sim-baseline moves listed. Its check RUNNING (builder0); if green it
  also carries R1 (R33.10).
- **Bar (a) READS** (builder0, `97ec141f`, hull-rest base_drawn faced_attack_move GDScript, --arrive-trace, seeds 40–45 × 4
  factions, n 24 a side; `tests/tactics/arrive_latch_table.py`, `5fc5a5fe`): gangs s40 Battery flips **0 v 39**, re-seats
  **6 v 302**, seat jumps ≥ 8 m 68 v 464. Pooled: flips 5 v 123 (Battery 4 v 70, all at gangs s43), re-seats 266 v 1135,
  jumps 1367 v 2541. Condemned, law and syndicate show 0 flips in both arms; the bug is a gangs (five-crew swarm) matter.
- **Bar (b), hull-rest half:** settled runs 12 v 12 of 24 (paired settled_after_s median +1.0 s, n 9); squads arrived 68
  v 71 of 81; crews still moving at the end 30 v 39. gangs s45 (on) stalled at t=17.6 s in the series (no SCREEN_DONE, no
  error; most likely the 300 s timeout, not traced) and was re-run alone on the light lane: it finished (settled -1, 3/5).
- **Bar (b) squad-arrive half READS** (builder0, `97ec141f`, seeds 57–60, n 100 a side, 0 missing; `arrive_latch_pair.py`,
  `133c6695`): all-within-8 m **93 v 93** (floor 88.8), every crew on its slot 71 v 70, re-seats after arrival 22 v 23.
  One table cell differs (law_scout:law_ifv:law_tank:law_tank on cut: 4/4 on v 3/4, 1 hollow, off).
- **(c):** the check on `429ebc4b` GREEN (builder0, `make check exited 0`, 2731/0), sim-baseline 13 maps unmoved. **PASS.**

### R33.14 / R33.17 (test_tactics_body order dependence; DONE)
- **`f8cf6476`** (stream/brains, the test file alone): each arm of `test_his_three_squads_keep_together` runs
  `tests/tactics/body_probe.gd` in its own child process under `--fixed-fps`. The line is unchanged. Laptop: traffic's
  ghost tree `bbb4d2db` 42.0 v 15.5 alone and after test_rts_camera; stream/brains 44.0 v 15.5. With the treatment child at
  body=off the line FAILS (44.0 v 44.0). Lands with R33.6 (cherry-picked onto main after fc195815 merges).
- **Cause (laptop, stream/brains, in-process seeds 1 and 3):** mostly TIMING. `make test` runs without --fixed-fps, so the
  physics steps per loop follow the wall clock: after test_rts_camera s1 read 44.5 v 7.0 (alone 35.0 v 16.0). Under
  --fixed-fps 60 the swing falls to at most 2 s (37.0 v 15.0). The residual is earlier matches' leftovers (the physics
  server and/or traffic's statics `_forget` keeps: `destinations`, `_teams`, `last_share`); those two are not separated.
  The start is not the cause (with the navmesh awaited before the spawn, the frames matched and the reads still differed).
  body_stage.gd can't be made timing-proof from GDScript; the child-process form is the cure.

### Battery stretch (lab/brains-r33-battery, worktree godot-brains-battery, offset 7; on main 54abf20a, without B10b)
- **BUILT on the laptop, test first (2026-10-18).** The trace commits were rebased onto main 54abf20a (old tip tagged
  `battery-pre-main-rebase`). Switches, each with its own off arm:
  (a) `9f02fb88` seat rule, `--battery-seat=off`. ElementPlan._group: a BATTERY's set-up crews (ElementSituation's new
  "deployed" = deploy_ratio >= 1) with a seat in this shape at this size keep it (`keep`), and their place is where
  they stand. TacticsFormation.seat `set_up_at`: a mover's seat whose straight line passes within PAST_M 6 m of a
  set-up truck costs PAST_COST 1e7 (< _PINNED, so the only open seat is still given). test_tactics_battery_seat 6/0.
  (c) `d915b8fd` deploy at its place, **`--battery-deploy=off`** (the bar's `deployatplace`; its own flag so it is
  judged alone). TankBrain MOVE: element-ordered artillery > DEPLOY_PLACE_M 8 m from its goal holds fire and sets
  Tank.deploy_held, so standing still (yielding, blocked) does not lower the legs; a fire command still digs in.
  test_tactics_battery_deploy 4/0.
  (b) `7efbdaac` GDScript half, `--nav-off=arrivedgate`. Movement._approach_gate, after v4's near block: a turreted hull
  (mount turret: every battery; never fixed-gun) standing (< 1 m/s) within its arrive radius of a goal it has already
  seen latches the gate ("arrived", gates_arrived). test_nav_gate_arrived 6/0; test_nav_gate_inside now runs with
  arrivedgate off (its IFV stands 4.25 m from its goal at rest, so both rules latch onto the goal); gate v4/inside +
  wheeled_arrival 29/0 laptop. **Native's mirror requested** (C26.2). Each switch's mutation fails its test.
  **Native's mirror DONE** (`pair/native-arrivedgate` 8200e230 + test_native_gate_arrived, floors 6805367b).
- **After the laptop freeze (2026-10-18 ~10:50):** the side worktrees were removed (branches kept); godot-brains-battery
  recreated on lab/brains-r33-battery, fast-forwarded to native's pair and merged with main 579c6fc4. No orphans on either
  builder. The pre-freeze builder2 gate run on 7efbdaac was lost; d915b8fd (a + c) had read 549/0 on builder2
  (`test FILTER=tactics_|formation|artillery|battery|combat_deploy|native_`).
- **Candidate `e8530098`** = the three switches + native's mirror + main 579c6fc4 + MEASUREMENT ONLY: BATTERY_FIRE_ORDER /
  BATTERY_FIRST_SHOT (fire order = the battery element's task becomes attack/support_by_fire; first shot by any crew),
  BATTERY_SETUP gated by ElementPlan.is_battery, `make battery-census` (traffic's census_probe, pinned --fixed-fps 30,
  --battery-trace, logs kept) and `tests/tactics/battery_table.py` (worst ON runs printed before the totals).
  **Arms and readings filed before any number** (the orchestrator filed them under the battery bar on main). (1) Named
  Parade s43 / Foundry s45: on, off, a/b/c alone. (2) Census Sumps/Parade/Foundry x fresh 47–52, n 18, ON v OFF.
  (b)'s squad-arrive on fresh seeds 65–68, n 100. **Orchestrator's rule:** if (2) fails as a whole, a SUBSET needs its own
  census on fresh 53–58, filed first; a subset is never picked from (2)'s numbers. Laptop smoke (Parade s43, 40 s, n 1,
  TUNING): the pipeline reads both arms; ON set-ups > 8 m 0/5 v 9/9, but shots 9 v 18 in 40 s, so the shots and
  first-shot lines are the risk. Full check RUNNING on builder2 (`brains-battery-check2`); then `battery-series.sh`.
- **Battery check GREEN on `ee18403b`** (= e8530098 + main's 4-slot remote.sh; builder2, full check): 2791 passed 0 failed,
  sim-baseline 13 unmoved, BRIDGE_POOLED 18/18. broker-test and relay-smoke failed on an infra race (a fresh folder's two
  targets run `npm ci` at once and corrupt node_modules/ws, plus the npm I killed mid-install). Re-run alone after reseeding
  node_modules from godot-brains' folder: `>> remote: make broker-test relay-smoke exited 0`, broker 31/31, relay PASS x2.
  Accepted by the orchestrator (the web-smoke precedent); the race is filed for native. **Series RUNNING on builder2**
  (`battery-series.sh`: named Parade s43 / Foundry s45 x 5 arms, census 47–52, arrive 65–68).
- **BATTERY VERDICT (builder2, ee18403b9, 2026-10-18): FAIL AS A WHOLE; nothing ships.** (1) named PASS (never-past
  battery askers 0 on Parade s43 and Foundry s45 ON); (2) census n 18 FAILS two clauses: never-past battery askers 2 v 1,
  first-shot median 9.0 v 3.3 s (limit 8.3; 19/28 orders answered v 28/31). Its other clauses pass: set-ups > 8 m 7/99 v
  186/344, art shots 441 v 446, repack while firing 0, friendly-stuck 637 v limit 931. (b) arrive 65–68 n 100: 97 v 97
  PASS. (3) check green. Worst ON run traced (census Parade s49): the first shots wait for (c)'s hold-fire-to-place
  (Green 20.1 v 7.1 s, Rust 40.2 v 3.1 s). Named switch-alone: (b) alone identical to OFF in both cases; (c) alone the
  only arm with never-past askers (Foundry 2); (a) alone fired most (109, 90). Recommended to the orchestrator, if a
  subset is filed: (a) or (a)+(b) on fresh 53–58, (c) parked. Rows: `references/round33/brains/battery_series_ee18403b9_builder2.txt`.
- **R33.27: battery (a) ALONE PASSED and is MERGED** (main `32e74084` = lab/brains-battery-a `1ea8ce40`; builder2;
  check 2777/0, sim-baseline unmoved, broker/relay re-run alone). Census 53–58 n 18: never-past battery askers 0 v 0,
  set-ups > 8 m 39/86 v 118/193, art shots 377 v 240, repack while firing 0, friendly-stuck 525 v limit 687, first shot
  3.0 v 2.5 s (limit 7.5). Named ON: no never-past askers (Parade shots 109 v 20; Foundry 90 v 44). (c) PARKED (its cost
  is its design); (b) DROPPED (no measured effect; native's mirror stays on pair/native-arrivedgate).
  Rows: `battery-a-1ea8ce40*` in the scratchpad (to file with the round's references).
- **Overnight item 2 (scout), groundwork:** C33.9 has NOT shipped (main has its bar and notes only), so item 2 is judged
  on main without it, and says so. SPOT is scored in TankBrain.decide, which runs in C++ (decide_native.cpp), so the
  change needs native's mirror. No attacker is recorded on a hit (Tank.take_hit), so "fire from a contact inside the
  scout's effective range" needs a proxy: hit within N ticks and a visible enemy inside both ranges. Asked manoeuvre for
  the stage behind "seed 4: shots 5–20 v 112–128" before filing the bar.
- **Item 2 (scout) BUILT** on lab/brains-scout (worktree godot-brains-scout, on manoeuvre's lab/c339-turnin ea043755:
  the orbit stage lives only there; main's behaviour is its turn-in-OFF arm). Bar filed (+ orchestrator: team enemy-seen
  MEASURED and judged; the 20 % per-cell line on cells with OFF hits >= 10; (a) on POOLED total shots).
  `2bd1fc11` scout_fights_back (hit within 2 s; visible, threatens_me, inside its own effective range; duel advantage
  >= 1 (a ratio) or not slower); `9aa792a8` scout-census enemy_seen_s per side. **Tuning (builder0, seeds 50–52) showed
  the arms IDENTICAL:** the rule fired but SPOT at 0.7 (0.80 with the commitment bonus) still beat ENGAGE's 0.27–0.43.
  **Re-filed: SPOT = 0.15 under the rule** (`57d8342c`), checked first wherever a contact is in sight. Option table
  (laptop, seed 50, 48 cells, a debug print not committed): ENGAGE chosen on 1925 of 2130 rule-firing ticks (90 %).
  Native's decide mirror requested at 57d8342c (needed for the fights guard; the orbit stage forces GDScript).
- **Item 3 (War Rig 4-of-5) TRACED** (lab/brains-warrig on stream/manoeuvre: `--element-trace`, `make warrig-trace`,
  pinned headless; builder0, seed 8, n 1). R33.6's split makes 3 elements (5/4/4). The 5-crew element's seat centroid is
  0.0 m off its anchor, and it arrives by t ≈ 30. One 4-crew element's anchor (6, 116) sits ON the arena's north edge;
  clamp_to_arena pulls its two outer seats onto the edge, SlotGround moves them 6 m in, and the centroid sits 17–20 m off,
  so it never passes the 12 m centre rule. Seat triples rule out stale seat sizes. **Candidate filed:** inset an element's
  anchor from the arena edge by its shape's half-extent (`--anchor-inset=off`); the "4 of 5" rule is dropped.
- **Item 3, cap + fold (filed):** inset capped at 15 m (INSET_CAP_M); a shape still past the edge arrives at its LAID
  seats' centroid; the transit route ends at the same inset point (lab/brains-warrig `d39c6e58`). Builder0 dev, seed 8
  (tuning): all three elements arrive ON (t 23/18/31 s; OFF: only the 5-crew one); the edge element's inset is exactly
  15 m. test_tactics_tasks' halt test moved inland (-100 is the pure world's default bound); its station test reads
  geometry with the inset off. Laptop tactics_tasks + anchor_inset 29/0.
- **Item 2 (scout) series RUNNING** on builder2 (lab/brains-scout = native's pair/native-scout `0565d1a8`, mirror GREEN:
  7536 decisions, 0 mismatches). Its check: 2782/0, but sim-baseline moved 6 maps (yard, terminus, gorge, archipelago,
  cut, yard_open). The orchestrator ruled the series may start (an expected move from a default-ON change). Attribution
  `make sim-baseline SCOUT_FIGHT=off` is queued on builder0: all 13 unmoved makes the moves the rule's; any move with
  it off is the turn-in branch underneath.
- **Item 4 (respawn rejoin) BUILT** on lab/brains-rejoin `13e1187d` (Element.join, Elements.join/has_room,
  ElementCommander._rejoin; `--rejoin=off` = R33.6; `--rejoin-trace`). Laptop test_tactics_squad_split 5/0; the join
  mutation fails 1. Bar filed (fights 560–575, n 16). Check GREEN (lab 97a02410, builder2: 2775/0, sim-baseline
  unmoved). **The filed stage was a NULL:** manoeuvre-fights 560–575 read identical arms and 0 BRAINS_REFORM lines.
  Skirmish/showmatch fights are elimination (skirmish_mode.gd:423), so nothing respawns there. **Re-filed (main):**
  `make rejoin-fights` (lab `6345125b`): the match runner without --elimination, 25 a side, pinned, --score-limit=0,
  180 s, fresh 580–583 x sumps/yard/terminus/foundry, n 16. A laptop smoke run acts: 52 joins, 2 one-crew forms.
  **Series RUNNING** on builder2.
- Traffic's random-705 fire-post loop: my view sent (traffic narrows T1c-b2's on_fire_post to set up AND a fire mission;
  a brains no-dig-in rule would cost every battery its deploy on first contact). Report only.
- Battery stretch (lab/brains-r33-battery, worktree godot-brains-battery, offset 7): trace c104f45e, 87181cf3 (laptop, Parade s43, n 1).
  Chain: arrived 4.9 m off pointing away -> arrival gate re-aimed 20.0 m back -> yields to Battery_1 -> coil seat swap across set-up trucks -> refused by set-up Battery_3, never moves.
  BATTERY_SETUP: 18 of 31 Green set-ups > 8 m from the place assigned at deploy start.
  Bar filed (main 405963b2, amended ffafc957 + later): three switches each judged alone in the named cases (Parade s43, Foundry s45), together deciding:
  (a) seat rule `--battery-seat=off` (a set-up crew keeps its seat); (b) `--nav-off=arrivedgate` (an arrived hull latches its gate; batteries/artillery/turreted only, never fixed-gun wheeled; native mirror; 3 gate tests on native; squad-arrive fresh n 100 >= OFF - 1.645 se);
  (c) deploy only at its place (third switch; added line: median fire order -> first shot ON <= OFF + 5 s).
  "Within 8 m" measured against the place ASSIGNED when the crew began to deploy (BATTERY_SETUP, both arms). Order: after B10b and R4.
- Scout C33.9 answered (round 34 candidate): ENGAGE when shooter matches and SPOT post is leash-clamped.
- Removed merged worktrees godot-brains-r1/-r339/-r336 (branches kept).

### R4 B5c-v6 (lab `lab/brains-r33-v6`, worktree `godot-brains-v6`, offset 5; `db72c8e9`, laptop only so far)
- **Rebuilt** on stream/brains (R33.6 `fc195815`, B10b `d3502faa`) + round 32's `b8a34c4f` (OFF_NAMES unioned) + native's
  `ba8d18d9`. The old build `77a3d55b` is tagged `v6-old-77a3d55b` in that worktree.
- **Finding (laptop, GDScript):** v6 as carried fails `test_nav_gate_v4`'s and `test_wheeled_arrival`'s 180-degree car. It
  takes the side gate, reaches it still pointing away, latches, and parks at dot -0.60 (a 40 s probe: it never turns).
  Handed back to v5's gate there instead, it stalled beside the slot at dot 0.41. **Decision:** the side gate only where
  v4's come-round has no turning circle beside the (nominal) rear gate. Reason: in open ground the come-round parks the
  facing. Yard s27 t8 is the case that tests it.
- **R33.8 built:** `inside_circle`. A gate strictly inside either turning circle of the hull is latched and the hull
  drives onto the goal (not while v4's come-round is running), at the rear and at the side gate. `--nav-off=gateinside`;
  test `test_nav_gate_inside`. Laptop: the gate, wheeled, planner-seam and inside tests 39/0 (`test_native_gate` skips
  with no native library).
- **R4 bar (FILED 2026-10-17, before any number; the orchestrator files it in *Bars (round 33)*).** *Preamble:* round 32's
  v6 as carried (`b8a34c4f`) fails `test_nav_gate_v4` and `test_wheeled_arrival` (the 180-degree car parks at dot -0.60),
  so the candidate is the NARROWED v6: the side gate only where v4's come-round has no turning circle beside the rear
  gate, plus `inside_circle` (R33.8). Candidate = `db72c8e9` + native's mirror (pair branch, test_native_gate 0
  mismatches), on the B10b base if B10b ships (else main). Arms: ON v `--nav-off=gateside,gateinside` (v5's gate, as main
  ships), one tree, native path, fresh seeds where a cell is named by seeds below.
  (1) **Named pass cases, DECIDING.** **Yard s27 t8:** every crew in, ON, and last crew in ON ≤ OFF. **Sumps s17 t11:**
  all-within-8 m ON ≤ OFF + 2 s (round 32's tuning read 35.8 v 34.8, n 1). **Yard head-on s42 t3 Green_A_5 (R33.8):**
  settles ON ≤ OFF + 5 s with circle reverses ≤ 20, ghost OFF, and ghost ON too if traffic's ghost is on the base tree
  (else said so).
  (2) **Pursuit** (R31.3's count): `make pursuit-aa`, 24 cells, ON ≥ OFF − 3 as written AND nudged, no new let-go at 18 m/s.
  (3) **Yard crossing cell** (seeds 29 30 × ticks 1 3 6 8 11 16, n 12), DECIDING: runs with every crew in ON ≥ OFF, and
  crews in ON ≥ OFF in every run. Last-crew median REPORTED.
  (4) **Sumps cell** (seeds 22 23 × the same 6 ticks, n 12): all-within-8 m median ON ≤ OFF, no run more than 5 s later;
  guns_on_arc ≥ OFF − 0.05.
  (5) Terminus head-on (seeds 8–11, t11) REPORTED.
  (6) **Arrive series** (5 maps × 5 squads × seeds 61–64, n 100): all-within-8 m ON ≥ OFF − 1.645 se.
  (7) **The faced finish:** test_nav_gate_v4, test_wheeled_arrival and test_nav_gate_inside green on the native path.
  Counters gates_side and gates_inside > 0 on the acting ON runs and 0 on every OFF run.
  (8) The check green on the candidate, sim-baseline moves listed with the reason.
  (9) The worst ON run of (3) and (4) traced before the medians are read.
  Ships ON as one pair with native's mirror if (1)–(4) and (6)–(8) pass.
- **Native's mirror READY:** `pair/brains-v6-r4` `97c3b654` (= `db72c8e9` + the C++ mirror of inside_turning_circle, the inside_circle latches and the side gate's turn_room condition). builder0 light: `make native test FILTER=native_gate|nav_gate_inside exited 0`, 8/0, every twin 0 mismatches, n 1. test_native_gate's floors are as filed (main `e4d1f749`). From here a gate edit in `_approach_gate` needs native's mirror to follow (C26.2). R4's series runs on this pair once B10b's verdict sets the base.
  `test_native_gate` fails without it. The bar is filed before any number; the series runs on the B10b base.

### Round 34 candidate (manoeuvre's War Rig case; filed by the orchestrator, main `eca993cf`)
- Laptop, manoeuvre `86447a3e`, foundry s8, gangs faced_right, squads 1+2, n 1. The War Rigs never read arrived: the slots
  centre 23 m off the element's anchor (28.2,116.0), and seat 4 (Guns_4) sits 70 m off it, (42.6,47.6). Arrival measures
  the centre against that anchor, so it can never pass. Not a straggler (my first reading, withdrawn), and the R33.9 latch
  doesn't change it. One field decides it: `plan["slots_asked"]` for Guns_4. Asked near the anchor = grounding moved it
  (SlotGround.standable_from, War Rig clearance); asked out there = the swarm geometry or the anchor.
- Manoeuvre read slots_asked (laptop, `86447a3e`, n 1): the anchor is orders' share point (28.2,116.0), and the shape is
  ONE FILE of 5 along the heading at z=116 (12.8 m pitch). Three seats were grounded 6 m south (recorded). Two kept x but
  went 28–68 m south with NO slots_asked entry. Probable chain (code read, not run): the transit squeeze (one lane) files
  the seats → the tail seats fall in a carving footprint → `Arena.clamp_into` (via ElementPlan.clamp_to_arena, before
  grounding) steps them out by the nearest side INSIDE the arena, keeping x → the centre never gets within 12 m. Confirm
  by printing the raw seat before the clamp. Foundry is a CUT map.

### R33.5 / R33.6 (the orchestrator's rulings; traced and built)
- **Cause (traced from the code):** in a showmatch both sides are CPU, but `SkirmishMode.fielded(doctrine, is_player=true)`
  folds the Green side like a player's army (`SquadConsolidation.for_player` merges families, splits only past 8): squads
  of 6–8. `skirmish_mode.gd:415` forms each squad with `Elements.form`, which refuses them (C19.1, an ERROR each), and the
  commander re-formed only when the team had NO element (`element_commander.gd:180`), so those crews fought unseated all
  match, and once the team's elements died every think re-refused them (~470 ERRORs a fight, traffic's X1 census).
  His own skirmish opponent (Rust) is not folded: he never saw it except in showmatches.
- **The decision (R33.6, his standing rule: symmetric AI improvements ship):** split, by his own side's arithmetic
  (`SelectionSquads.deal`, called, not copied: ceil(n / 5) pieces, as even as they come, west to east). One reason: the
  formations, slots and drills are built for ≤ 5 (MAX_MEMBERS); a larger element would be new, untested geometry.
- **Built:** `Elements.form_squad` (new; `form` unchanged, manoeuvre's stages keep it); `ElementCommander.form_elements`
  uses it and re-forms whenever a living crew of its squads has no element; `skirmish_mode.gd:415` calls `form_squad`
  (the granted line). Test `test_tactics_squad_split` (6 → 3+3, 8 → 4+4, names "Guns", "Guns II", every crew seated, no
  ERROR); the commander test fails with the old form/re-form (laptop, 2/0 with, 1/1 without).
- **Showmatch fights 500–507, 120 s, builder0, default path:** R1 `2fd9f420` (without it): C19.1 refusals in 8/8 fights,
  224 in all (s503 71, s507 144; every ERROR line a refusal), FIGHT_CENSUS rows 7/8. With it (`64fed1ad`): 0 refusals, 0
  ERRORs, 8/8 fights, rows 8/8. Rebased onto R33.9: `5df2404e` (its check follows R33.9's, one heavy job at a time).
- **Branch layering now:** `2fd9f420` R1 → `429ebc4b`/`70ffe28e` R33.9 → `5df2404e` R33.6 → stream/brains (B10b
  `2ce42aaa` + Status). R4's lab `lab/brains-r33-v6` (worktree `godot-brains-v6`, offset 5) = stream/brains + round 32's
  v6 lab `b8a34c4f` (OFF_NAMES unioned) + native's mirror `pair/brains-v6-carry` `ba8d18d9`: `77a3d55b`, built, unchecked.

### Plan (in order; R3 waits on CP-F, so R4 goes before it if CP-F has not merged)
1. R1 respawn clear (ships alone). 2. R2 B10b (bar → check on the pair tree with it ON → series). 3. R4 B5c-v6 on a
   B10b-ON base if CP-F has not merged, else R3 first. 4. R3 B11b on CP-F. 5. R5 only if CP-X picks an element
   make-room. 6. Stretch: the battery firing spots.

### Decisions
- **R1 reuses the deploy's search** (`ArmyLayout._clear_spot`: rings outward from the slot, STAND_CLEAR_M between boxes
  on their own axes, clear of layout obstacles, standable) rather than a second clear-spot finder. The slot is kept
  EXACTLY when its box is already clear (so a respawn with nobody near is unchanged, bit for bit); the living hulls of
  both teams count, the dead do not; read sorted by name (deterministic on both peers).
- **B10b's form: the corridor, not a hysteresis re-ground.** One reason: it never holds a seat in the squad's path, and
  where no squadmate's route passes the held point it is exactly B10 (keeping its 22 → 0 flips). A corridor = a crew
  still driving (Movement phase not `arrived`): its position then the rest of its navmesh route (`Movement._path`, kept
  in GDScript on both drive paths), half width = both hulls' half widths + 1.0 m (ArmyLayout.STAND_CLEAR_M). The
  straight chord to the seat is NOT enough: in B10's losing run (s19 t8, 54 s) S_3's chord to its west seat passes
  ~14 m from S_2's held seat while its route goes round through it. Own element only (other elements are C33.2's).

### B10b bar (C33.4; FILED 2026-10-17 before any number; the orchestrator files it in *Bars (round 33)*)
Candidate: stream/brains at the hash its check goes green on. Arms, one tree, builder0, the DEFAULT path (native where
it runs; Element.ground is GDScript on every path, so no native half): **on** = default (latch + corridor);
**off** = `--ground-latch=off` (main's rules); **b10** = `--ground-corridor=off`, reported only.
1. **Pass case Sumps s16 t8** (main's flip case: 22 flips, never in): no flipping crew (> 10 drift moves) on.
2. **Pass case Sumps s19 t8** (the case B10 failed, +19.9 s): on's all-within-8 m time ≤ off's + 5 s.
3. **Drift census, FRESH seeds** (`make ground-series`: Sumps 20 21 × ticks 1 3 6 8 11 16, n 12; yard 31 32 × the
   same, n 12; Terminus head-on 16–19 t11, n 4): pooled runs with a flipping crew on ≤ off AND pooled drift moves on <
   off; Sumps all-within-8 m median on ≤ off and no run > 5 s later; yard crews in on ≥ off every run.
4. **Arrive series, FRESH seeds 53–56, n 100 an arm:** all-within-8 m count on ≥ off − 1.645 se (se of the paired
   difference of the per-run 0/1 outcomes, × n); discordant pairs and the paired median reported.
5. **sim-baseline:** moved maps listed with reasons (a CPU element's held seat re-grounded off a route), adoption by the
   orchestrator; unmoved also acceptable.
6. **The whole suite on the tree** (the check, on), bridge-pooled 18/18.
7. Cost: `t.poll.element` on Locks ≤ 0.5 ms (B10: 0.149 v 0.164).
8. The worst on-arm run of 1–4 traced before medians are read.
Ships ON as one commit if every line passes.

## Overnight (round 33 extension, 2026-10-18 ~00:45 PDT)

The lead has gone to bed and wants builder2 kept busy. Take these items in order (`workstreams.md` *Round 33, overnight
extension*; the details are in `roadmap.md` *Round 34 candidates*). Merge main first. builder2 FIRST (`make gcp-remote`,
6 heavy slots). Every judged stage pinned at `--fixed-fps $(SIM_HZ)`. A bar is filed (sent to the orchestrator) before any
number, judged on FRESH seeds, and every number labelled with its machine. Keep this Status current: the lead reads it in
the morning.

1. **The battery item:** three switches judged alone, its filed bar (native mirrors arrivedgate).
2. **A scout under fire fights back when it can't get away:** your design (roadmap). Bar first. It pairs with
   manoeuvre's C33.9, so judge it on a tree that has C33.9 if C33.9 has shipped, else say which.
3. **An element that never arrives because one crew still drives** (foundry s8, the War Rig 4-of-5 case): trace, then
   a candidate ("arrived when 4 of 5 are in their slots and the rest are stalled").
4. **A respawned crew rejoins its squad's living element when it has room** (R33.6's side effect, improved).
