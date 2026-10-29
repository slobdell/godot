# Stream: orders (his group click: every squad lands at his click, on his side of the gap, nobody sent back; ON this round)

> Read `_agents/orchestration.md` (the worker contract; lesson 339), `_agents/judging.md`, `_agents/workstreams.md` **Round 45**
> (C45.1-C45.5). Your last brief: `streams/archive/round44/orders.md` (Status: G1 v10c, the five causes in his terms, the two round-45
> ideas, the runner fixes); R44.2, R44.9, R44.23 in `workstreams.md`; `game_design.md` *His answers on the group click* and *His
> playtest after round 44*. **You own:** `game/control/**` (incl. `selection_squads.gd`, `group_formation.gd`, `rts_controls.gd`) EXCEPT
> engage's grant in `order_executor.gd` (stop / hold / move / attack_move for a crew's own order) and native's `gate_width` C++ seam;
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`; GRANT `game/ai/planner/**` for a group order's
> departure order and route spread only. **Model:** Fable. **Machine:** builder0 light lane (J<=4); builder2 for a bar series.
> **Seeds:** 11201-11248 (bar), 11249-11296 (reserve).

## The lead's direction (2026-10-29, verbatim; the full note in `game_design.md` *His playtest after round 44*)

"I selected 3 squads and had them all go to a target waypoint that was south of the bridge. What waypoint selection algorithm chose a
far away waypoint that was north of the bridge for one of the squads. This was precisely the behavior I had asked to fix."

He asked for this in rounds 37, 41, 43 and 44 and **has never played a fix**: every fix failed a fresh-seed bar on cases he never
played, so his default game never changed (lesson 339). **This round something ships ON for it.** The bar is "units must look smart"
(memory): one army, one click, every squad lands near where he pointed.

## Where things stand (main at launch: 972e4bb57, code a93271a66 GREEN builder0 3446/0, see HANDOFF)

- **His case** (`references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl`, Gorge, seed 91711, laptop, native on; `make replay-match
  RECORDING=<that file>` PASS 20/20 for 30 s): at t 0 Hunters + Spears + Wrenches, one click at (-43.2, 53.2), just on his side of the
  west gap (R45.1). The order rows (`group: 3`, `click` recorded): Spears to the click, **Hunters to (-76.0, 101.0): 48 m BACK, behind
  his own start line z 90**, **Wrenches to (-10.4, 5.4): 65 m FORWARD across the drop**. Three spots on one line through the click,
  58 m apart, laid across his approach: the default `ranks` lay (R44.2: three abreast across the click).
- **G1 v10c** (fit first, two abreast, the rest stacked behind) is on main behind `--group-column=always`, OFF. Its bar failed (R44.23):
  (1) short clicks hold 2-3 squads and send the rest round a 90 m column; (2) on the Crossing's bending streets the column follows the
  road off his click line; (3) fit disagreements on along-20 cells. His exact Locks click lays as he asked. Your round-45 ideas (the
  archived Status): a short click is seats in place, no column; a column on bending streets keeps to the click line.
- Tools: `tests/control/orders_geometry_table.py` / `orders_geometry_judge.py`, `make orders-geometry`, `tests/control/orders_bar.sh`
  (runner fixes for error rows and `--probe-budget=3000` on main), the G1 v9 probe `tests/orders_probe_group.gd`.

## Backlog (in order)

1. **O1 his Gorge click, reproduced and cut down.** Replay his match to t 0 and print, per squad: start, the place each layer gives it
   (ranks lay, G1 v9's column-toward, fit_to_corridor, any edge/water push), the `to` it got. Confirm the default path is the `ranks`
   lay across the approach. Then answer the simplest question first: **does "every squad's place within N m of the click, on the
   click's side of any drop or water, never behind its own start along the approach, packed by fit" remove what he saw, with no other
   machinery?** Write the cause and the candidate in Status before code; message the orchestrator.
2. **O2 the guard (G2), ON by default, `--group-guard=off` the escape.** The smallest change that removes exactly what he saw, on
   today's default lay (not under `--group-column=always`): a place across a drop / water / impassable gap from the click (the
   ground path from click to place much longer than the straight line, or the straight line crosses a pit), or more than 10 m behind
   its squad's start along the approach, or farther than the packed depth from the click, is re-dealt to the nearest free packed seat
   on the click's side (fit first, nearest squad in front; a squad already within its seat's distance holds). Symmetric: the CPU's
   group orders take it (C45.5). Tests first (his Gorge geometry as a unit test; a click beside a lock; a click on a bridge deck).
3. **O3 Bar G2**, filed in `workstreams.md` *Bars (round 45)* BEFORE any number on 11201-11248, NARROW (C45.2): deciding lines =
   his failure (places across a gap from the click: 0; places behind the start > 10 m: 0; farthest place from the click <= the
   packed depth + slack you state), on a corpus that includes Gorge (his click and clicks either side of each gap), Locks (his round-43
   clicks), Crossing, Terminus, short (20 m) and far (80 m) reach. Guards (what it could break): all-in time per cell <= base x 1.2 + 3 s,
   never-in <= base, friendly contacts <= base x 1.1 + 5, G1 v9's street lines (places outside the corridor <= base + 2), the fight
   probe (his kills / losses within base +/- 1.645 se), engage's authority probe and manoeuvre's one-squad arrival (C45.3). Ships ON
   the minute it passes; message the orchestrator the green hash.
4. **O4 his acceptance read:** the shipped tree on his Gorge replay and his two round-43 Locks clicks; top-down shots of the places
   before/after, looked at; the table in Status.
5. **O5 G1 v10c continues behind its switch** (C45.2: it does not block G2): short clicks as seats in place; the column keeps to the
   click line on bending streets; then G1 v10d's bar on the reserve block, if time.
6. **Stretch:** more than two abreast on a wide yard (a feel question for him: write it in player terms with a recommendation); the
   departure order (nearest leaves first).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make replay-match RECORDING=...`; the
geometry probe and judge; `make control-playtest`; top-down shots at his click, looked at. Every number with its commit and machine.

## Don't touch

`order_executor.gd`'s crew-order branches (engage's grant), `game/tactics/**` (engage / manoeuvre), movement / traffic (manoeuvre),
`native/**`, `game/camera/**`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. If G2's bar fails, write in player terms what he would see with it ON v OFF and message the orchestrator the same
hour (C45.2): the call is his, not round 46's.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### NOW (2026-10-29, Fable, worktree `godot-orders`, branch `stream/orders`, started from main 8d59b2bdf = a93271a66's code)

- **Plan (in order):** O1 the cause on his replay (done, below) -> O2 the guard G2 ON (`--group-guard=off` the escape), his Gorge
  lab test first, then the Locks-beside-a-lock and bridge-deck cases -> quick-remote -> file Bar G2 here and message the
  orchestrator BEFORE any 11201 number -> `make remote T=check` on the frozen hash -> the series on builder2 -> O4 the
  acceptance read (his replay + his two round-43 Locks clicks, top-down shots) -> O5 G1 v10c behind its switch, if time.

- **O1 CAUSE (his Gorge click, reproduced to the decimetre).** `make remote T="replay-match RECORDING=references/round44/playtest/
  2026-10-29T09-35-51-gorge.jsonl REPLAY_SECONDS=5 CREWS=all REPLAY_FLAGS=--order-trace"` on builder0, main 8d59b2bdf (code a93271a66),
  replay PASS 20/20 within 3 m for 5 s. The order trace, per stage, every place identical to his recording's `to` rows:
  `ranks` Hunters (-76.0, 101.0) / Spears (-43.2, 53.2) / Wrenches (-10.4, 5.4); `column_lay` EMPTY (G1 v9 kept today's body:
  every place stands on clear ground, the far one on the valley floor across the drop); `never_behind`, `ground_cap`,
  `ground_anchors`, `untangle_whole` unchanged. So the default lay is `SelectionSquads.ranks` -> `row`: three squads fit one rank
  (3 <= MAX_ABREAST, 3 x 44 + 28 = 160 m <= 200 m), laid ABREAST 58 m apart across the approach, which here runs diagonally
  south-west from the army's middle (~(0, 93)) to his click (heading (-0.73, -0.68)), so "abreast" runs north-west / south-east:
  the Spears on the click, the Hunters 58 m north-west of it (level with the click along the approach, 8 m behind their own start
  in z: behind his start line), the Wrenches 58 m south-east of it, a leg that threads the west neck (x -48..-32, the pits either
  side at z 38-50) and ends 33 m past the drop toward the enemy. Why nothing caught it: never_behind reads only along the
  approach (the Hunters' place is level with the click there); the ground cap passes a place whose drive from the click is at
  most 1.5 x the straight line + 8 m and crosses no DECK (the neck is land: drive ~60 m v 58 m straight); the column only runs
  when a place stands off clear ground, and both outer places do stand on clear ground. The fit at his click, read as the layout
  reads it (`RtsControls.gate_width` across the approach): the north-west side open, the south-east side ends at the neck's far
  wall ~16 m out -> ONE squad abreast fits centred (`fit_abreast`), not three.
- **O1 ANSWER to the brief's question (the simplest thing):** yes. "Every place within one body of the click, on the click's side,
  nobody behind its start, packed by fit" removes what he saw with no column machinery: (1) lay the body at most as many abreast as
  the ground at the click fits (one here) -> the three stand in file along the approach, Spears on the click, Hunters and Wrenches
  in ranks behind on the open strip between the drop and his base, every place on his side; (2) a guard that reads each place for
  "across water / a pit / through a neck from the click, off the click line by more than the body's frontage, farther than its last
  rank, behind its own start" and, on any failure, re-lays the body on those seats. Built as G2 (O2 below).

- **Green so far:** `make quick-remote` on **2a622e5bd** (builder0): 336 passed / 0 failed over the 45 control / tactics files the
  diff touches, lint 97 scripts, the smoke; `>> remote: make quick exited 0`. Full check of 2a622e5bd launched on builder0
  (`~/orders-r45/check-2a622e5bd.log`). **Freeze candidate: dc1995fd0** = 2a622e5bd + main 47a15f434's checkpoint merge (the
  cold-import watchdog, tools/ only); it inherits 2a622e5bd's check by the orchestrator's N1 precedent (said to the orchestrator).
  His Gorge replay on the laptop with the guard ON (GDScript drive, 2a622e5bd, `~/orders-r45/o4/`): the lab's places on his real
  match (Hunters on his click, Spears 33 m behind, Wrenches 66 m behind, every place on his side). Earlier: 5225a024b quick-remote 327/9 (two_squads x 8,
  halt_price x 1: the fixture's off-mesh click and a drawn facing; both fixed in 2a622e5bd).
- **O2 G2 BUILT (this tree; ON by default, `--group-guard=off` / `GROUP_GUARD=off` the escape).** `SelectionSquads` *G2 (round
  45)*: (1) FIT FIRST: `ranks` takes a cap = `guard_fit` (fit_abreast at the click across the approach, at most two) read on the
  gate scan CUT at the first sample across a gap from the click (`guard_trim_sides`: the scan threads a neck, his Gorge click read
  58 m "clear" to the south-east over the valley floor; the column keeps the uncut scan, G1 v9 unchanged); `rank_sizes` /
  `rank_slots_for` factored so the seats can be asked for with spares in the body's own shape; (2) `guard_failures`: a place across a gap from the click
  (`guard_across_gap`: on water / a pit / a deck's mouth, a wet straight leg, or `beyond_neck`: the leg crosses the segment between
  two drops closer than GUARD_NECK_M 24 m and runs > 2 m past it; a place behind the click along the approach is never "across":
  the squads' own side), off the click line by more than the fitted frontage + 4 m, farther behind the click than the last rank +
  4 m, or > 10 m behind its own start along the approach; (3) `guard_relay`: the whole body re-laid on the fitted ranks' seats
  (3 spares): the front on the click, or (a click on a deck / in water / on a wall) on the first point back along the approach
  the ground takes (4 m steps, 40 m); each seat snapped to standable ground within 12 m (as ground_anchors does), refused on
  water / a deck's mouth / off the map / not `reached_from` the click by ground, skipped when across a gap from the click;
  NEAREST IN FRONT (`assign_by_distance`: ranks dealt by each squad's distance to the click, left to right within a rank; the
  fitted `ranks` lay is dealt the same way under the guard, not by the least total driving, which put the squad already at the
  tail's distance on the tail and drove the farthest through the middle); a squad the seat would send > COLUMN_AWAY_M farther
  than it stands holds; too few seats -> today's places (counted: `guard_unlaid`); a packed body (D3, `--pack=on`) is read, not
  re-laid. `RtsControls._order_squads`: one gate_width scan at the click (kept for the column: no second scan), the
  guard the last pass on the anchors before the squads are dealt (stage `group_guard` in the order trace); gated
  `squads.size() >= 2`, plain clicks only (a shifted leg lays as before). Measurements: `guard_relaid / held / unlaid /
  fit_capped`, `guard_last_fit / reach_m`, printed on the geometry probe's row with per-squad `across_gap`.
  Tests: `tests/test_control_his_gorge_click.gd` (his click reproduced with the guard off; with it on every place on his side,
  the Spears on the click; the neck read pure), `tests/test_control_guard_locks.gd` (a click beside the lock, a click on the
  swing bridge's deck: dry, off the deck, the click's side, one body). Judge `tests/control/orders_g2_judge.py`, runner
  `tests/control/orders_g2_bar.sh` (Gorge cells added; a fixed cell's folder now keyed by its click, `mk/command.mk`).

### Bar G2 THE GROUP GUARD (orders, round 45; filed here BEFORE any number on 11201-11248; dev reads on 7001-7006 only)

**What he would see:** he selects two or more squads and clicks once. Every squad lands at his click or in a short stack behind
it on HIS side of any drop, water or neck: nobody is sent across the gap toward the enemy, nobody is sent back behind where it
stands, nobody is strung 58 m off to one side. Where the ground at his click holds two squads side by side they stand side by
side; where it does not (a neck, a bank, a street) they stand in file along the way they came, nearest in front. On his Gorge
click (the lab, builder0, this tree): the Hunters (his nearest squad, 49 m off) ON the click, the Spears 33 m behind them, the
Wrenches 66 m behind, one file along his approach on the open strip between the drop and his base; today: Spears on the click,
Hunters 58 m north-west, Wrenches 58 m south-east through the neck.
- **Arms:** base `base:--group-guard=off` (today's lay) v `g2:` (the tree's default: the guard ON). Everything else as main.
- **Tree:** a frozen detached worktree at the commit named green here (`make remote T=check` on builder0, ALL JUDGED), or a docs-only
  descendant.
- **Part A, his geometry (DECIDING): `tests/control/orders_g2_bar.sh b2 g2: "11201 ... 11224" ...`** = `make orders-geometry` on
  builder2 (native on): gorge / locks / crossing / terminus / yard_open x his / along / across x reach 20 / 80, plus fixed clicks
  `locks:his:-62/50` (his round-43 target) and FIVE Gorge clicks: his own (`gorge:spawn:-43.2/53.2`, his rows at their spawn) and a
  click either side of each neck with his row side by side (`gorge:across:-40/58`, `-40/30`, `40/58`, `40/30`: near = his side,
  far = the valley through the neck). FRESH seeds 11201-11224, n 24 a cell. Judge `tests/control/orders_g2_judge.py`, over the
  ARM's runs, base reported beside, per cell (a fixed click its own cell) and per run:
  1. **D1 across_gap = 0 in every arm run** (the probe's per-squad flag as the guard reads it: a place on water / a pit / a deck's
     mouth, a wet straight leg from the click, or through a neck and out the far side; a place behind the click along the approach
     never counts): his Wrenches.
  2. **D2 backward = 0 in every arm run** (a place > 10 m behind its own start along the approach).
  3. **D3 every MOVED place within the fitted body's reach + 6 m of the click, every arm run** (reach = the farthest seat of the ranks
     the guard lays for that run, `guard.reach_m`; a moved place = one > 2 m from its squad's start): his Hunters, 58 m off.
  4. **D4 (R45.5) the fallback (`guard.unlaid`, too few seats: today's places stand) = 0 on every Gorge run**; reported per cell
     everywhere (how often his old scatter can still happen with the guard ON).
  5. **D5 held = 0 on every Gorge run** (a squad that keeps its spot did not land at his click); `held` reported per cell.
     Exact test: `held` = the squads whose place is within HOLD_M = 2 m of where they stood (the probe's row, as the geometry
     table reads it): the stay rule fired (the seat was > 10 m farther from the click than the squad stands, or > 2 m behind its
     start along the approach, so its place = its own centre). A squad that moves 4 m to a seat counts as moved, not held; a
     squad already within its rank's depth of its seat still MOVES to it (there is no "close enough" hold: a seat is a seat).
  6. **D6 (R45.6) on the Gorge `spawn` cell (his own click): no place more than 2 m behind its squad's start along the approach,
     every arm run.** Exact test: per run, max over squads of (start - click).approach - (place - click).approach <= 2.0 m
     (`backward_m` in the judge, from the probe's row `start` / `anchor` and the geometry row's `approach`). The guard itself
     holds a squad whose seat would be > 2 m behind its start along the approach (`GUARD_HOLD_BEHIND_M`; on the un-relaid lay
     never_behind already pulls such a place to the start's level, 0 m).
  Reported: spread, across, fit per cell, relaid per cell.
  **The lab's per-squad read of his click (builder0, 5225a024b, NATIVE=off; approach (-0.824, -0.566), 59 m from the army's
  middle to his click):**
  | squad | start | place (guard ON) | moved | direction | behind its start along the approach |
  |---|---|---|---|---|---|
  | Hunters | (-14.6, 92.6) | (-43.2, 53.2) = his click | 48.6 m | south-west, straight at his click | -45.9 m (ahead) |
  | Spears | (14.6, 92.6) | (-16.2, 71.7) | 37.2 m | west-south-west, onto the file 33 m behind the click | -37.2 m (ahead) |
  | Wrenches | (43.9, 93.6) | (10.8, 90.3) | 33.3 m | west along his start row, onto the file 66 m behind the click | -29.1 m (ahead) |
  Nobody turns round: the file runs straight back along the diagonal approach, so its tail seat is 29 m AHEAD of the Wrenches'
  start along the approach (it sits 3 m north of their start in z, 33 m west of it). Today: Spears on the click, Hunters 58 m
  north-west, Wrenches 58 m south-east through the neck.
- **Guards (what it could break), filed now:** part A per cell: all-in median <= base x 1.2 + 3 s, never-in <= base, held median <=
  base's unmoved + 1; friendly contacts pooled <= base x 1.1 + 5. **Part B, G1 v9's street lines:** `orders-probe` locks / crossing /
  terminus / yard_open x 3 / 5 squads x click / route + his terminus click, seeds 11225-11236, n 12 a cell, `orders_judge.py g1v8`
  unamended (places outside the corridor <= base + 2, sent away <= base + 2, re-dealt 0; yard_open REPORTED: the guard changes a
  three-abreast body there on purpose). **Part C, fights:** `--probe-fight=on --probe-budget=3000`, terminus / locks, 5 squads,
  click, seeds 11237-11248, n 12 a cell: his kills, his losses, the CPU's losses within base +/- 1.645 se. **C45.3:** a one-squad
  order never enters this code (`squads.size() >= 2`): engage's authority probe and manoeuvre's one-squad arrival are unchanged by
  construction (stated, not measured; the frozen tree carries whichever of their probes main holds at the freeze and they run in
  its full check). **C45.5:** the CPU never lays a group click (its elements are ordered one by one): no CPU case. **Perf:**
  no new scan on a group click (the guard's gate_width read is the one the column already made); `control-timing` on the
  frozen tree's builder0 check REPORTED (the 30-unit click already reads over budget on main, R43.41: native's item).
- **Known risks, said before the numbers:** (a) a 3+-squad click on open ground now stands 2 + 1 (or 2 + 2 + 1) instead of three
  abreast: all-in may lengthen where the third squad drives to the rank behind (the guard above decides); (b) a click past a neck
  (the far Gorge cells) stacks the ranks back THROUGH the neck, on the squads' own side: that is the column he asked for, but the
  never-in guard may bite if a rear rank stands in the neck's lane; (c) the stay rule can hold a squad on a short click (reach 20)
  when its seat is farther than its spot: D5 only decides it on Gorge; (d) a seat on a bending street is laid on the straight
  approach, not the road (part B decides).
- **Ships ON** the minute every line passes (`--group-guard=off` the escape); if a deciding line fails, what he would see with it
  ON v OFF goes to the orchestrator in player terms the same hour (C45.2).

- **Dev read 1 (builder2, 5225a024b, 7001-7006, base `--group-guard=off` v g2, `~/orders-r45/dev1/`, judge
  `orders_g2_judge.py`):** D1 PASS every cell (base 0 too: the probe's 4-squad army does not reproduce his 3-squad diagonal; the
  lab does); D6 PASS on his click (backward max 0.1 m v base -15.3); D2 FAIL (crossing along-20 4, locks along-20 3, terminus
  across-80 3), D3 FAIL (4 cells), **D4 FAIL: every Gorge click took the fallback** (4 squads in file at 50 m a rank = 150 m do not
  fit behind a click 45-60 m ahead of the row: the capped ranks laid in the air were slid onto the map; the relay found too few
  seats), D5 FAIL (gorge -40/58 and his click held 1), all-in FAIL on 9 cells, never-in FAIL on 5. Contacts 8429 -> 6176 PASS.
  **Cause and the rebuild (this tree):** the body under the guard is now LAID ON THE GROUND (`guard_lay`), rank by rank from his
  click: each rank as wide as the clear ground there (two at most; a rank behind reads its own 52 m scan), every seat dry / on
  the map / standable within 12 m / reached from the click, ranks only while the ground holds them and never behind the whole
  army; nearest in front; squads with no seat hold, as do those whose seat is farther than they stand (COLUMN_AWAY_M), behind
  their start (R45.6) or under a holding squad. Lab (laptop NATIVE=off, 7 files 61/0): his Gorge click unchanged (Hunters on the
  click, Spears 33 m, Wrenches 66 m behind); his tick-1512 Locks click: Hunters to the click, the other three HOLD (their seats
  would be farther than they stand: his answer 3, a short click); tick 1808: two abreast at the click + two behind.
  Dev read 2 on builder2 running on this tree.
- **Known issues:** (1) the shared repository had a corrupt packed object (the blob of
  assets/audio/layered/crowd_murmur_1.wav in pack-315912d8a6…): `git worktree add` for the frozen tree failed on it (~18:50);
  repaired reversibly with a hand-written loose copy of the same SHA from this worktree's intact file; the orchestrator is
  verifying the packs. (2) With `--pack=on` (D3, OFF) the guard reads the packed body but never re-lays it. (3) A shifted leg
  (shift-click route) lays as before: the guard is for his plain click only this round. (4) The frozen series tree is
  `../godot-orders-g2` (detached at dc1995fd0, local.mk copied, .tools symlinked); builder2's folder for it is fresh (the
  watchdog from main 47a15f434 covers its cold import).
- **Questions for the lead (feel, for after he plays it; not changed now, R45.6):** the gangs' squads halt in a coil (a ring
  36 m across), so a rank in file is 33-50 m deep and three squads stacked behind his click run 66-100 m back. When he sees the
  stack, does he want it tighter (the squads halting in their travel wedge, nested ~26 m a rank: manoeuvre's formation and the
  deploy step), or is a long file along his approach fine?
- **Requests to other streams:** none. Relays taken: engage's E1 (a one-crew order never enters the group path: `squads.size() >= 2`,
  as before and as G2 is gated); native's R45.3 seam at the top of `untangle_whole` (G2 does not touch that function's body;
  it changes only the anchors handed to it, as any lay does).
