> **ARCHIVED (round 35 closed 2026-10-20).** The branch is `round35/traffic`; its unmerged references (`references/round35/` or `_agents/streams/references/round35/`) stay on that branch. Round 36's brief is `streams/traffic.md` where one exists.

# Stream: traffic (a crew under fire doesn't step aside into a killing zone when the one behind can go round)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 35** (C35.1, C35.8;
> R34.9, R34.13, R34.15, R34.17, R34.20 in *Round 34*), and your round-34 brief `streams/archive/round34/traffic.md` (its Status is the
> close-out). Evidence: `references/round34/traffic/` (T5 census, x6/x6b series, parkedroom v4/v4b).
> **You own:** the give-way block (`_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`, `_negotiate`, ask, `_begin_yield`,
> `right_of_way`), `game/ai/traffic.gd`, `tests/traffic/**`, `tests/test_traffic*.gd`, `mk/traffic.mk`.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. His answer at round 34's close: **a firing mortar truck keeps
its spot** ("Keep the truck firing"; his round-31 T1c-b2 rule stands).

What he will notice: fewer crews dying while stepping aside for a squadmate in a lane under fire, without the crew behind
stalling there instead.

## Where things stand

- **Shipped in round 34:** O4 (routes are the squad's) and o4b (gates for squads that have the waypoint queued).
- **Parked, each judged twice or more:** parkedroom (v4/v4b: hold-post loops −74 %, the far-loop total is the firing batteries he
  keeps); T4 the ghost (the gain is spent by later rules); **T6/T6b under fire, no give-way** (R34.17, R34.20): refusing every ask
  under fire cut yielding deaths 53–69 % but moved the dying to stuck/blocked/parked one for one; dropping the mid-step abort (c)
  fixed the collision harm. `underfire` is DEFAULT_OFF on stream branches only (not on main); native's mirror `badfdb978` unmerged.
- **T5's census:** jammed-by-friendly deaths 5.6 %, 83 % giving way, 77 % under fire, median jam 1.5 s, lanes 74 %.

## Backlog (in order)

1. **T7 Refuse under fire only when the asker has another way (C35.8).** Design note first, to the orchestrator: how "another way"
   is read (parkedroom's room/route test, a navmesh detour bound, or the asker's own route options), what the asker does when it has
   none (the give-way proceeds as today), and the interactions (the battery rule, the gate, O4 routes). Then tests, then a bar before
   any number: deciding gain jam-under-fire deaths; guards stuck deaths, open deaths, far loops, kills, hit rate, contacts after a
   give-way, crossings (as T6b's); fresh fixed arenas, no twins. Base it on `round34/traffic` (T6b's code) on current main; native
   mirrors from `badfdb978` with the new gate.
2. **T8 (R35.7, after T7's series; its own bar filed first):** a held crew that is being hit leaves the take-turns hold. From
   manoeuvre's W1 (builder0, native, main a0ae0aafd, Locks/Terminus × 3500–3511, 24 fights): 33 of 81 stuck:wedged deaths were HELD
   by the T1 street-mouth hold under fire, a median 5.4 s in; the 3 longest wedged episodes (18 s) are all holds. Not folded into T7.
3. **DONE (D):** `jam:held` is a REPORTED sub-cause (`9369a1039` jam_census `sub_cause`, `by_sub_cause`; jam_table prints it; T5's causes unchanged; dev fight terminus-1900 on builder0 emits it). Was: **(D) (R35.7, after T7's series reads):** jam_census adds `jam:held` as a REPORTED sub-cause (a death while held by the hold);
   T5's definition (T7's G) unchanged until then.
3b. **T9 (R35.12, after T7 and T8; bar drafted when reached, no code before):** a give-way that ends with the yielder still
   touching the asker or still across its route does not count as done (yieldfit). Manoeuvre's law-605 trace: a parked scout of
   another squad yielded 2.4 m, still touching and across the asker's route; the yield ended and nobody asked again for 65 s
   (manoeuvre's W1c makes the asker ask again; this half is ours).
4. **DONE (after T7's read):** jam_ab and jam_table call `seed_twins.filter_logs` before pooling (far_table already did,
   native's line); far_ab/far_kills are not on this branch (round 34's, unmerged). Was: **After T7's series, once native's N2 is on main (the orchestrator says when):** every traffic series reader that pools a folder
   that could hold random-arena fights (far_ab, far_kills, jam_ab, jam_table) calls `seed_twins.filter_logs` first (small commit).
4b. **X2 (Round 35 extension, 2026-10-20, workstreams *Round 35 extension*; the lead away for the day): T8** (a held crew under
   fire leaves the hold; bar filed, 1800–1827): cut its pair from main AFTER the joint W1c + T9 ship merges (T9 on main; the
   orchestrator says when), switch-OFF inertness, check + series on **builder2** (after orders' D5 check). No native mirror (the
   drive calls Traffic.hold_of). Prepared: `jam_ab --bar t8` and the census fields (`06144d171`), the driver
   `tests/traffic/t8_series.sh`.
5. **Stretch:** the measurement notes for judging.md (random-seed twins are now dropped by `seed_twins.py`; the fresh-folder import
   segfault is intermittent and a relaunch cures it).

## How to verify

Tests first; `make quick-remote`; one full check at a time on builder0; series pinned, fresh seeds, no random twins. Every number:
commit, machine, workload, n.

## Don't touch

Manoeuvre's drive and unstick, brains' and orders' paths, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

## ROUND 35 REPORT (traffic, Opus, 2026-10-20 ~02:30 PDT). Every number carries its commit, machine, workload, n.

**Done criterion (R35.60):** met as **"green except by construction"**. The stream tip `4fbbd4d3c` (builder0 `make native check
exited 2`) read 2916 passed, 1 failed, sim-baseline unmoved. The one red is `test_native_exec_state::test_the_table_is_the_scripts_members`:
T9's three Movement members have no rows in native's `exec_fields.h` here. Native's T9 mirror adds them in the joint pair (joint3-on
`872f82ae5`, 2931/0), which is how T9 reaches main. **stream/traffic is NOT a merge candidate on its own.** Tip now `60aafdbaa`+
(main `31e3d605c` merged; jam_ab tooling `5f2210a8c`, its test OK; docs).

**What shipped, in player terms.** **T7 (C35.8):** a crew under fire no longer steps aside into the open when the crew behind can
drive round it; the crew behind goes round. In a one-hull lane it still makes room as before. Merged to main `9e226c700` from the
green hand-over `3dbc206a0` (builder0 2903/0; sim-baseline moved cut/gorge/locks/terminus/yard, the judged pair's own, attributed by
its switch-OFF read). Judged on pair `e95179252` (builder0, native, fixed arenas × 1600–1627, n 140): jam-under-fire deaths 277 → 240
(2.1 se) and every guard passed. Stuck deaths 958 → 960 and far loops 108 → 108: the cost T6b paid is gone. Most of the gain is on the
Terminus; the Locks' one-hull lanes give none, by design. **Owed: perf-judge alone on a quiet builder0** (refused for load three
times; the orchestrator slots it).

**Done, not shipped by me:** **T9 (R35.12/R35.14)**, traced and coded: a give-way that ends with the asker not past and the crew
still in its way is not recorded, so the asker's next ask is honoured (cap 2 in 30 s). It is in the joint W1c+T9 series, which
manoeuvre runs; I sent the T9 × T7 interaction note. **Joint3 result (manoeuvre, stream/manoeuvre `2c212324d`, `references/round35/manoeuvre/joint3-series/`): FAILS as filed, on manoeuvre's own line (d) attack-move movers 16 → 17 v a line ≤ −21.8, which a base of 16 could not pass on these seeds. T9's guards all PASS (jam_ab `5f2210a8c` `--any-arms`): jam-under-fire 114 → 122 (limit 136.8), jam:yielding 124 → 125 (line 146.3), give-ways started +208 (band 492); ON arm yields_unfinished 573, retries capped 0 → 11. jam_ab's "G FAIL" is T6/T7's gain line, not in this bar. Re-file is the orchestrator's call; T9 needs nothing from me to re-run.** **(D)**: `jam:held`, reported. **Seed twins:** jam_ab and jam_table drop them.
**judging.md**: measurement notes. **Smoke** at his pose: `make traffic-t7-clip` (laptop with a display; desktop and phone sheets in
`references/round35/traffic/t7_clip/`).

**X2 (round 35 extension, moved up from round 36): T8, a held crew that is being hit leaves the take-turns hold** (R35.7; coded `1a1bd58bf`,
`--traffic-on=holdfire`, DEFAULT_OFF; `Traffic.hold_of` releases a held crew hit within `Movement.UNDER_FIRE_S`, `released_fire`;
tests/test_traffic_holdfire.gd 2/2 + hold twins 15/0, builder0 quick). **No native mirror needed:** the native drive calls back into
`Traffic.hold_of`.
- **Bar (filed on main, workstreams Bars round 35; `references/round35/traffic/t8_design.md`):** FRESH fixed arenas {terminus,
  locks, crossing, gorge, parade} × **1800–1827, locks 1801–1828** (R35.69: locks-1800 swapped for locks-1828), n 140, native, one machine start to end, pinned, 180 s. Counter first:
  `released_fire` > 0 in the arm. **G:** held deaths (dead while `Traffic.holding` the tick before, or within 3 s of a hold ending;
  jam_census `held_3s` / `held_deaths`) arm < base and (base − arm) − k·se > 0. **Guards:** stuck deaths, jam deaths (T5), open
  deaths ±, far loops, kills/hit rate, all friendly contacts, crossing arrivals 44–46 × 6, `tr_holds` ≥ half of base, and **all
  deaths per team** ≤ base + k·se.
- **Pair plan (X2):** cut `pair/holdfire-x2` from main AFTER the joint W1c + T9 ship merges (the orchestrator's word) + `1a1bd58bf`
  (traffic.gd and the test; tests/test_traffic_holdfire.gd.uid `41f637d8e`) + the series tooling main lacks (tests/traffic/
  jam_census.gd, jam_ab.py, test_jam_ab.py, jam_table.py, t8_series.sh: (D)'s `held_deaths` is not on main) + an ON flip
  removing `holdfire` from `DEFAULT_OFF`. Base arm `--traffic-off=holdfire`. All on **builder2**, one driver from the pair's
  worktree under systemd-run: `tests/traffic/t8_series.sh` = wait for builder2's checks to clear (orders' D5 first) →
  `make native check` (stops if red beyond sim-baseline) → switch-OFF `sim-variants --traffic-off=holdfire` → the series
  (`native traffic-jam-census` per arena per arm, 4 jobs; crossings 44–46 × 6) → `jam_ab --bar t8`, v2_lines, jam_table per
  arm, into `~/overnight-traffic/r35/t8series/`. Resumable step by step (a Spot stop restarts the box via `make gcp-start`).
  Perf-judge alone before a ship.
- **Reader:** `jam_ab.py BASE ARM --bar t8` (`06144d171`, test_jam_ab 7/0; T7's series re-reads unchanged): released_fire
  counter first; G `held`; guards 1 stuck, 2 jam, 3 open ±, 4 far loops, 5 kills ± / hit rate, 6 all contacts, 8 tr_holds ≥ half
  base, 9 all deaths of each team; line 7 by v2_lines. JAM_CENSUS now carries `holdfire_on` and `Traffic.report()`.
- **Seed slip (flagged to the orchestrator):** the census smoke for that commit ran ONE filed fight, locks-1800 (laptop, 60 s, OFF v
  ON; it printed T8's lines for that fight). **Ruled (c), R35.69:** locks-1800 swapped for locks-1828 (n 140, every judged fight
  unseen); in the driver (`LOCKS_RANGE=1801-1828`) and the bar above.

**Questions for the lead.** None.
**Requests to other streams.** None open (native's T7 and T9 mirrors are done).
**Known issues.** The stream tip's one by-construction red (above). The laptop's memory guard reaped two of my idle waiters
overnight; systemd units were unaffected.
**What to playtest.** `make skirmish ARENA=terminus`: in a street fight, watch a crew that's being shot hold its spot while a squadmate
behind it swings out and round; in a one-hull lane it still pulls aside. `make traffic-t7-clip` shows the case at his camera, ON v OFF.
**Merge notes.** T7 merged via `3dbc206a0` (touches `movement.gd`, `traffic.gd`, native's `drive_native.*`, `exec_fields.h`,
`tank_native.cpp`, `native_drive.gd`, tests). Branches NOT to merge: `stream/traffic` (by-construction red), `pair/underfire-t7`
(merged via the hand-over), `lab/t9-trace`, `lab/t9-trace-w1c` (measurement prints).

**2026-10-19 (traffic, Opus).** No numbers yet.

**Plan (ordered).** T7.0 design note (DONE, `321e752f1`, sent to the orchestrator) → T7.1 base: T6/T6b + jam tooling cherry-picked
onto main without parkedroom (DONE) → T7.2 tests + code (DONE: test_traffic_underfire 13/13, builder0 quick at `95cc04a04`; the 17-file movement/native-twin/traffic quick
88/89 before the one staging fix) → T7.3 native's mirror spec (DONE, `t7_native_spec.md`, with native since ~10:00 PDT; waiting on
their twins hash) → T7.4 pair +
`make native check` + switch-off inertness → T7.5 the judged series (below) → stretch: judging.md measurement notes (DONE `a2d8d6256`). Then T8 (coded, bar filed, 1800–1827), (D), seed_twins readers.

**T7's bar, FILED before any number (also in workstreams *Bars (round 35)*).** Pair = current main + T7 (`--traffic-on=underfire`,
DEFAULT_OFF) + native's mirror + the ON flip; base arm `--traffic-off=underfire`; switch-OFF sim-baseline inertness beside the C31.1
full check. Native, builder0 start to end, pinned, 180 s showmatch, FRESH fixed arenas `{terminus, locks, sumps, gorge, parade} ×
1600–1627` (n 140, no random arena, no twins). k = 1.645, paired se (`tests/traffic/jam_ab.py`).
- **G (deciding gain):** jam-under-fire deaths (T5's definition) arm < base AND (base − arm) − k·se > 0.
- **Guards (T6b's):** (1) open deaths ± k·se; (2) stuck deaths ≤ base + k·se; (3) far loops ≤ base + k·se; (4) kills ± k·se, hit rate
  ≥ base − k·se; (5) contacts in the 3 s after a hit-ended give-way ≤ base + k·se; (6) crossing arrivals 44–46 × 6 ≥ base − k·se a case;
  **(7, new) all friendly hull contacts a fight ≤ base + k·se** (a pass must not buy bumps).
- **Reported:** contacts with a crew passing, standoffs with durations, all/jam deaths, deaths by cause, `underfire_refusals/gives/
  holds`, `passes/passes_done/passes_timeout`. A fail is traced (worst fight first); no re-read of a line.

**Decisions.** "Another way" = a pass lane beside the refuser swept for the asker's hull (design note: parkedroom's room test answers
the refuser's question, a navmesh detour cannot see hulls, a lane change is brains' and B9 showed it is not the lever). The refused
asker steers by the lane (ORCA alone follows a slow mover: T6b's doubled far loops). (b) is gated by the same test, roles swapped.

**STREAM TIP CHECK (the done criterion): `4fbbd4d3c` (main 5f05c997c + T8 + T9, both DEFAULT_OFF), builder0, `make native check
exited 2`: 2916 passed, 1 failed; 24/27; sim-baseline PASSES (unmoved); NOT JUDGED for load: perf-judge, scenario_perf.** The one
red is `test_native_exec_state::test_the_table_is_the_scripts_members`: "add to native/src/exec_fields.h ... _unfinished_to,
_unfinished_count, _unfinished_since" = T9's three Movement members, which native's T9 mirror adds to exec_fields in the joint
pair (`pair/native-w1c-t9-main`). `native/**` is not mine, so the stream alone is red by construction on that one twin (as round
34's stream/traffic was); T9 reaches main only through the joint pair, which carries both halves. `references/round35/traffic/
tip_check_4fbbd4d3c.txt`. Since then: `5f2210a8c` (jam_ab tooling, its test OK) and main `31e3d605c` merged (`60aafdbaa`).

**T7 SHIPPED (R35.44): MERGED to main `9e226c700`** from the green hand-over `3dbc206a0`; the orchestrator adopts the five moved
maps on the merged tree and runs one batch main check (don't merge main until it says green). perf-judge alone is still owed in
the first quiet window. T8's pair: cut from the batch-green main when its series turn nears (queue W1b → D6 → M5 → joint W1c+T9 → T8).

**T7 JUDGED: PASSES AS FILED (2026-10-19 20:18 PDT; `0670dbeed`, `references/round35/traffic/t7_design.md` RESULT).** Pair
`e95179252`, builder0, native, fixed arenas × 1600–1627, n 140, none missing. Counters: refusals 427, passes 311 (192 abreast,
44 timed out), gives 1327. **G jam-under-fire deaths 277 → 240 (−13 %, 2.1 se) PASS**; guards: open 4780 → 4746, stuck 958 → 960,
far loops 108 → 108, kills 6037 → 5979, hit rate 0.732 → 0.731, post-hit contacts 416 → 407, all friendly contacts +0.2 %,
crossings 180/180 every case: all PASS. All deaths 6082 → 6019 (reported). Most of the gain on the Terminus; the Locks' one-hull
lanes give none (by design). **Owed before a ship:** perf-judge alone on a quiet builder0; a hand-over re-cut on current main with
one fresh check (and native's mirror re-based with it). **HAND-OVER GREEN: `handover/t7-on-main` `3dbc206a0` (merge here).** builder0 `make native check exited 2`: 2903 passed, 0
failed; 24/27; the only red is sim-baseline, MOVED cut, gorge, locks, terminus, yard, the same five maps at the same hashes as the
judged pair's (attributed by its switch-OFF read); NOT JUDGED for load: perf-judge (refused at 1.53–2.23×), scenario_perf (unpinned).
perf-judge alone owed in the first quiet window. `references/round35/traffic/t7_handover_3dbc206a0.txt`. Was: `handover/t7-on-main` `3dbc206a0` =
main `8be787afe` + the judged pair `e95179252` (22 files: T7, native's T7 mirror and twins, census tooling; T7 ON); worktree
`~/projects/godot-traffic-t7ho`; its `make native check` waits for the orchestrator's slot (behind `builder_checks.sh --wait-below 1`).

**T7 SERIES RUNNING (R35.18, started 12:58 PDT 2026-10-19):** `traffic-t7-series` (systemd, laptop) from the pair worktree,
`e95179252`, builder0, native, pinned, 180 s, {terminus, locks, sumps, gorge, parade} × 1600–1627 both arms, JAM_JOBS 3, one remote
call per arena per arm, then traffic-series 44–46 × 6 both arms; results `~/overnight-traffic/r35/t7series/` (driver.log,
base/, arm/, jam_ab.txt, v2_lines.txt). Machine rule (R35.36): ONE judged series and ONE full check on builder0 at a time; the series queue after T7 is W1b → M5 →
the joint W1c+T9 → T8; full checks launch behind `tools/builder_checks.sh --wait-below 1`; perf-judge alone for T7 is slotted by
the orchestrator. Progress at 18:24 PDT: terminus, locks, sumps, gorge done in both arms (28/28 each, none missing), parade and
the crossing series left. Read order as filed: counters (underfire_refusals, passes > 0 in the arm), then G, then
the 7 guards.

**T7 pair GREEN for the series (C31.1): `pair/underfire-t7` `e95179252`**, builder0, `make native check` exited 2: 2902 passed,
0 failed; 24 of 27 targets pass; the one red is sim-baseline, 5 maps MOVED with the switch ON (8 unmoved); the switch-OFF
`sim-variants --traffic-off=underfire` on the same commit reads all 13 of main's lines unmoved, so the moves are the ON arm's own.
NOT JUDGED for load: perf-judge (refused ×3 at 1.87–2.01×) and scenario_perf (unpinned). `references/round35/traffic/
t7_c311_e95179252.txt`, `t7_inert_ufoff_e95179252.tsv`. perf-judge alone on a quiet builder0 is owed before any ship.

**T9 (R35.12/R35.14, APPROVED; joint bar with manoeuvre's W1c, manoeuvre cuts the pair and runs the series).** Trace
(`lab/t9-trace-w1c` `e2bea96f2`, builder0 light, GDScript, W1c ON, law faced_attack_move 605, n 1): a parked crew's give-way
ended on the 6 s clock with the pinned asker never past and still beside it; `_last_yielded_to` then refused that asker's every
later ask (`references/round35/traffic/t9_trace_design.md`). Coded `--traffic-on=yieldfit2` (DEFAULT_OFF): an unfinished
give-way is not recorded; cap 2 in 30 s (`2af7d3528` + staging fix); test_traffic_yieldfit2 4/4 on builder0 quick. Mirror spec
`t9_native_spec.md` sent (via the orchestrator). **Native's T9 mirror is in the joint pair `pair/native-w1c-t9` `6177ee87a`** (my
`f432645dd` + their T7 mirror + T9 mirror; builder0 light: test_native_yield 12/0, native twins 111/0, every twin 0 mismatches;
forced clock-ended give-ways twinned, 8 unrecorded + 6 capped a stage). Manoeuvre cuts the W1c+T9 pair; merging waits for T7's
verdict (R35.19).

**T7 pair cut (2026-10-19 ~10:40 PDT): `pair/underfire-t7` `e95179252`** = native's `pair/native-t7` `21e5d69e4` (my `95cc04a04` +
their T6b mirror + the T7 mirror + twins: test_native_yield 10/0, a pass stage 813 drives twinned at 0 mismatches, builder0 light)
+ v2_lines.py + jam_census's reported held fields + the ON flip. Main since its base: docs only. Worktree
`~/projects/godot-traffic-t7pair`. Its `make native check` (switch ON) + switch-OFF inertness wait for the orchestrator's slot
(after brains' E1, ≤ 2 checks on the box), gated by `traffic-t7pair-gate` (systemd); logs `~/overnight-traffic/r35/t7pair_*`.
Series driver: scratchpad `t7_series.sh` (one remote call per arena per arm, then traffic-series 44–46 × 6 both arms).

**T7 smoke at his pose (`make traffic-t7-clip`, laptop with a display, stream `1ed5b668e`+clip, GDScript):** a crew on open ground
hit every tick and a squadmate sent through it. ON: refused once, one pass, ended abreast; the hit crew moved 0.0 m and the
squadmate swings out round it. OFF: the hit crew is shoved 8.9 m along the lane ahead of the squadmate. Desktop and phone sheets in
`references/round35/traffic/t7_clip/` (looked at: readable at both aspects; on phone the pass leaves the frame quickly).

**T7 dev read (REPORT, dev seeds, NOT a judged number):** `95cc04a04` tree, builder0, GDScript (`--brains-off=native`), T7 ON,
Terminus/Locks × 1700–1701, n 4, 180 s. Under-fire asks: 27 given way as today (no lane) v 10 refused with a lane; (b) holds 3;
passes 5 started, 2 ended abreast, 2 timed out (6 s), 1 still running at the end; 12 friendly contacts while passing (of 3865
friendly contacts). The lane test is selective (about 1 in 4 under-fire asks), which is the point. Note: 1700–1701 were then
taken out of T8's block (moved to 1800–1827). Raw: `build/t7dev/`.

**T8 coded behind `--traffic-on=holdfire` (DEFAULT_OFF; `Traffic.hold_of` releases a held crew hit within 5 s, `released_fire`);
test `tests/test_traffic_holdfire.gd` (2); its pair waits for T7's read.**

**Questions for the lead.** None.
**Requests to other streams.** native: the T7 mirror (spec to follow with the first green commit).
