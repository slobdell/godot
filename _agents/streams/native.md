# Stream: native (a playtest report he can paste; twins for what ships; the replay of his group click)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 44** (C44.1, C44.2, C44.4), your round-43
> brief `streams/archive/round43/native.md` (Status: CP43.0, the replay, lines_r43). **You own:** `native/**`, `mk/native.mk` (incl.
> `playtest-report`), `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`,
> `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tests/ai_scenarios/guard_line.gd`,
> `mk/play.mk`'s skirmish recipe, `_agents/judging.md`, `tests/replay_orders.gd`, `tools/recording_arrivals.py`, the playtest-report
> tools, `tests/replay/**`. **Model:** Opus. **Machine:** builder0 (quiet window for perf); builder2 for rows. **Seeds:** 11001-11024.

## The lead's direction (2026-10-28)

He ran `make playtest-report` on his recording and found its output too long to paste. "Core components in C++ long-term" (memory).

## Where things stand (main at launch: dbf0bf637, see HANDOFF)

- `make playtest-report RECORDING=<file> [HTML=out.html]` (`mk/native.mk` ~line 493): arrivals per order, the camera at each hit /
  death, a 30 s replay's divergence. It prints everything to the terminal.
- The replay is faithful (his round-42 match bit-exact, R43.9). Orders adds `click` / `group` keys to the `order` row (C44.2).
- Round-43 watch items: control per frame 27.60 v 26.0 (a watch line); `gate_width` in C++.

## Backlog (in order)

1. **N1 the one-screen report.** `make playtest-report` writes the full report to a file (`build/playtest-report/<recording>.txt`, plus
   the HTML) and prints at most ~40 lines: the match (arena, seed, factions, length), per order one line (tick, squads, verb, worst
   arrival / never-arrived), the camera-misses count, replay divergence one line, and the path of the full file. Test it on both his
   round-43 recordings; paste the printed summary into your Status so the orchestrator can see it fits. Merge alone when green.
2. **N2 replay his group click.** `make replay-match` on `references/round43/playtest/2026-10-28T08-21-31-locks.jsonl` to tick 1512 /
   1808: confirm it reproduces his four destinations; hand orders the command and the divergence (message the orchestrator). Make the
   replay read the `click` key when present (C44.2).
3. **N3 twins for what ships:** whatever manoeuvre (Bar S v3's rules beyond kturngoal / parkaside, M2's k-turn) and orders (G1 v10's
   layout, if it touches the drive) need before they ship ON (C44.4); pairs proved output-identical, merged with the ship.
4. **N4 lines_r44 and the judged table** for the round's bars; the quiet perf read of main at launch and after each ship.
5. **Stretch:** `gate_width` in C++; the control-per-frame line re-read quiet.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make native` + `make native-info`; the report on both
his recordings, read by eye. Every number with its commit and machine.

## Don't touch

`game/control/**` (orders), movement / traffic / formation (manoeuvre), `game/match/**` (the `click` key is orders'), `tests/baselines/**`.

## Waiting on the lead

Nothing.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**FINAL REPORT (native, round 44, 2026-10-28 ~17:20 PDT).** Every backlog item done or handed over; nothing waits on the lead.
- **N1 DONE, on main:** the one-screen `make playtest-report` (<= 40 lines printed, the full report to `build/playtest-report/
  <recording>.txt` + `.html`) + `make skirmish` keeps SEED's digits = **fff546ef6**, builder0 `>> remote: make check exited 0`, 3420 / 0,
  28 targets ALL JUDGED, perf-judge JUDGED PASS attempt 1 of 3 = main c3a6e6a38.
- **N2 DONE, on main:** his round-43 matches replay exactly (army seed recovered from his roster: 891 / 542; his seed text and laptop
  preset passed; `--click=TICK:X,Z`; C44.2 click rows merge at the click) = **7e9c199ae**, builder0 `exited 0`, 3425 / 0, 28 ALL
  JUDGED, sim-baseline unmoved = main 7975d1455. His group click: R44.2 / R44.4 (the six trial clicks, the z = 117.24 edge).
- **N3 twins (manoeuvre's; each proved on builder2, hashes sent to manoeuvre + orchestrator):**
  - backout v1 `pair/native-backout` edbb120a5 (on e0a746667): superseded when 67998860d changed the rule.
  - backout v2 + parkedpass `pair/native-m2m3-r2` 39b063c7c (on 6c45ef6f0): EQUAL, 232 / 0; merged into stream/manoeuvre; its
    station-PID gate was the OLD rule (R44.8 addendum: the orders probe 37/60 on the C++ drive). parkedpass parked (S v3 failed).
  - **backout r3 `pair/native-backout-r3` 30e37f336** (on manoeuvre df31afba8 = cf6eabc22 + c9ea1a6b4): station PID off
    `_backout_leg` only, the long-hull pre-filter, traffic.gd's gate lifted. builder2: native-proof EQUAL with
    `--traffic-on=backout,parkedpass` (4a04ea921011cd9a), **233 passed / 0 failed, `exited 0`**; laptop staged twin 1191 drives / 0
    mismatches (C++ t4 / t93 = the GDScript stage's); parkedpass twin 420 / 0. Default orders probe 60/60 (base v bo, C++ drive): see
    the line below. Bar B1 freezes on it (manoeuvre).
  - Twin lessons: a GDScript look with side effects (a memo, a route read) is decided by the GDScript: the C++ pre-filters on the
    side-effect-free terms only; a per-look scratch the GDScript writes (`_departure_hulls`, member or static) must be written by the
    cheap path too (29 mismatches without it); mutants caught for both rules.
- **N4:** `tools/judge/lines_r44.py` 8e3bff0a1, 24 lines (G1 v10c 10, S v3 10, A6 v3 4), quoted from R44.7 / R44.19 / R44.23 and
  their judge files; judge tests 86/86 (laptop). B1 has no line until it reads. No round-44 pair's rows are on main as probe rows
  (no table change). Quiet perf reads: main's checks carried perf-judge PASS each time; no separate quiet read was run (builder0 was
  never quiet while the bars ran).
- **Stretch:** the control-per-frame quiet read was done by orders (main 887059084: the watch item closed); `gate_width` in C++ is
  round 45 (HANDOFF 6211aa124; orders' code this round).
- **Questions for the lead:** none. **Known issues:** a replay of a recording made before A7 (his round-42) parts at 15 s on today's
  main (`--engage-water=off` makes it exact): behaviour changed, expected. Builder folders `godot-native-backout*` on builder2 can go.

**Plan (in order):** N1 the one-screen report -> N2 replay his group click -> N3 twins (manoeuvre's `--traffic-on=backout`,
requested 2026-10-28 by the orchestrator; orders' if any) -> N4 lines_r44 + quiet perf reads -> stretch (gate_width in C++,
control-per-frame quiet read).

**N1 DONE, check running.** `make playtest-report` prints <= 40 lines and writes the full report to
`build/playtest-report/<recording>.txt` + `.html`: 8a1c384fe. tools/test_playtest_report.sh 27/0 (laptop). Each click is one
line (the order rows of one tick and verb grouped; squads as squad:crews; his `click` when C44.2 records it; how far apart the
spots are; arrived n/N; the worst best-distance; AWAY >= 30 m). "camera: off screen" projects each hit/death's victim through the
recorded `cam` row (RtsCamera.pose_at, fov 35 assumed (the row has no lens), 16:9). The replay line names why it parted (native
differs / roster mismatches / seed not recorded). His 08-15 recording: 18 lines; 08-21 (laptop, 8a1c384fe + N2, native ON,
52 s wall):
```
PLAYTEST 2026-10-28T08-21-31-locks.jsonl
match: locks, seed -1 (his --seed=56416.), 63 s, gangs v condemned (20 v 20 units), squad cap 4, laptop, native on
fight: 71 hits, 5 deaths (his 4, CPU 1)
his clicks (5; time, verb, squad:crews, spots, arrived in the window to the next order, worst best-distance):
     0.0 s  move         Guns:5  to (-86, 53)  arrived 4/5  worst Guns_5 56 m never  AWAY Guns_3 44 m
    25.0 s  attack       Guns:4  -> Lances_1
    39.6 s  stop         Guns:1
    50.4 s  move         Guns:1 Hunters:5 Spears:5 Wrenches:5  4 spots 105 m apart  arrived 8/16  worst Wrenches_3 72 m never
    60.3 s  move         Guns:1 Hunters:5 Spears:5 Wrenches:5  4 spots 91 m apart  arrived 4/16  worst Wrenches_3 84 m never
camera: 16 of 76 hits/deaths off screen (16 on his units, 1 deaths); estimate: fov 35, 16:9
replay: PASS, his match: 20 of 20 crews within 3.0m for 30 s
full report: build/playtest-report/2026-10-28T08-21-31-locks.txt (page build/playtest-report/2026-10-28T08-21-31-locks.html)
```
(the replay line as it reads with N2; before N2 it read `FAIL ... first over Green_Guns_1@7 (1 roster mismatches, seed not recorded)`.)
Full check of **fff546ef6** (N1 + the SEED fix): running on builder0, log `~/native-r44/check-fff546ef6.log`.

**FINDING: his round-43 seed was lost to a full stop.** Both playtests ran `SEED=56416.` (HANDOFF's sentence end): --seed did not
parse, so the armies rolled from the clock (unix % 100000), the recorder wrote seed -1, and Match's fire RNG (process `--seed`, else 0)
started from 0. `make skirmish` keeps SEED's digits only (fff546ef6; tools/test_skirmish_flags.sh 6/0, laptop).

**N2: his round-43 matches replay EXACTLY** (0d4b08cd8, laptop, native ON, through make): the replay passes his seed TEXT and his
render preset (the laptop's roll caps armies at 20; desktop's does not: test pins it) and gives the skirmish the army seed found
from his roster near the recorder's start second (REPLAY_SEED_RECOVERED). 08-21: seed 891, 20/20 crews 0.0 m for all 63 s; 08-15:
seed 542, 20/20 for 60 s. Round 42's recording: exact for 49 s with `--engage-water=off` (A7 ON since his match parts it at 15 s:
behaviour change, expected). test_replay_setup 13/0 (laptop).
**His group click (tick 1512):** reproduces his four spots (the rows replay as recorded). His click point is not in the recording;
`--click=1512:X,Z` replays the four rows as ONE group click at (X,Z). Six clicks tried (his four spots, their centroid,
(-12.6, 104.2)): every one scatters the squads 60-110 m from his exact state (worst 37-110 m from his spots; none his exact
layout). z = 117.24 recurs as a hard edge and his Wrenches landed at (-25.49, 117.24): the squad "sent back to the north edge" looks
like a slot past the map clamped to the edge. Handed to orders via the orchestrator (the command + this).
C44.2: rows sharing a `click` merge into one order AT the click (a one-squad row keeps its recorded point).

**N1 MERGED:** fff546ef6 GREEN builder0 (`>> remote: make check exited 0`, 3420 passed / 0 failed, 28 targets ALL JUDGED, perf-judge
JUDGED PASS attempt 1 of 3) = main c3a6e6a38. N2's check: main merged in (7e9c199ae), full check running on builder0.

**N3 twins (manoeuvre's M2 backout + M3 parkedpass, C44.4).** First cut pair/native-backout edbb120a5 (off e0a746667: builder2
native-proof EQUAL with --traffic-on=backout, 209/0) went STALE when manoeuvre's 67998860d rewrote the look (nose-on, 40 deg, the
hull-stopped back-up): 100 mismatches on their merged tree. **Re-cut: pair/native-m2m3-r2 39b063c7c on manoeuvre 6c45ef6f0:**
- backout: C++ backout_due pre-filters the side-effect-free terms and calls back Movement._backout_due (its look reads the route
  and memo); the cheap look defers on the pre-departure terms and writes the static scratch `_departure_hulls = []` as every
  GDScript look past 0.5 m does; `_backout_leg` bookkeeping; the station PID kept off a planned leg; kturngoal's end skipped while
  `_backout_leg`. Members _backout_goal/_tick/_point/_from/_leg as LATE rows in exec_fields.h.
- parkedpass: C++ ask(): under way natively, `_parked_for_pass` called back (read only), pass_lane natively, the refusal + offer.
- traffic.gd: neither switch forces the GDScript drive / yield any more.
- Laptop, 39b063c7c: test_native_drive_backout (his 08-15 start, every crew both ways every frame, 8 s) 1191 drives / 0 mismatches,
  the C++ fight backs at t11 and clears the box at t102; test_native_drive_parkedpass (manoeuvre's yard_open stage, C++ yield) 420 /
  0, 6 refusals, the rig never moves; + exec_state + manoeuvre's two tests 11/0. Mutants caught: no `_departure_hulls` reset 29
  mismatches; no native refusal 1 mismatch (rig moves 9 m); first cut's no cheap-look deferral 6 mismatches.
- builder2 proof (native-proof + test files, both switches ON): running, log `~/native-r44/m2m3-proof-39b063c7c.log`.

**Stretch:** gate_width in C++: DEFERRED. It is orders' `game/control/rts_controls.gd`, which orders is rewriting this round (G1).
Control-per-frame quiet re-read: waiting for a quiet builder0 (load 13 at 10:43).

**Questions for the lead:** none. **Requests:** orchestrator: send SEED= without a trailing full stop (done by fff546ef6 anyway).
