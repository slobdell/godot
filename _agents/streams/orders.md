# Stream: orders (his all-squads click: every squad the same way, a column of wedges at his click)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 44** (C44.1-C44.5,
> CP44.0). Your last brief: `streams/archive/round41/orders.md` (G1 v9's bar and Status); R41.15 and *Bars (round 41)* Bar G1 v9 in
> `workstreams.md`; *Round 37: his playtest note on a group click* in `game_design.md`. **You own:** `game/control/**` (incl.
> `selection_squads.gd`, `group_formation.gd`, `rts_controls.gd`), `tests/test_control*.gd`, `tests/control/**`,
> `tests/orders_probe*.gd`, `mk/command.mk`; GRANT (C44.2) a `click` / `group` key on the `order` row of
> `game/match/match_recorder.gd`; GRANT (CP44.0) the `"group"` entry in `ElementTask.KEYS`; GRANT `game/ai/planner/**` for a group
> order's departure order and route spread only. **Model:** Fable. **Machine:** builder0 light lane (J<=4); builder2 for a bar series.
> **Seeds:** 10801-10848 (bar), 10849-10896 (reserve).

## The lead's direction (2026-10-28, verbatim; the full note in `game_design.md` *His playtest after round 43*)

"I selected all of my squad and told all of them to move to the west side of the map. I had reported this issue long ago: the
waypoints selected for the respective squads were all over the place, leading to all squads moving in all different directions. We had
already talked about this at lenth in the path where I was trying to ask for the squads to pack it in or something (i.e. one squad behind
another or something so that they can all share roughly the same destination)"

Round 37, what he asked for: "stacks of wedges, one squad immediately behind the other", "the squad furthest away to land in the back
and the closest squad to land in the front". **This is the round's lead item and it has come back after a bar passed (G1 v9, R41.15):
the bar measured something other than his case. Find out what, on his recording, before anything else.** The bar for this stream is
"units must look smart" (memory): he must see one army going one way.

## Where things stand (main at launch: dbf0bf637, see HANDOFF)

- **His case** (`references/round43/playtest/2026-10-28T08-21-31-locks.jsonl`, Locks, seed 56416, Gangs v Condemned, laptop, native ON,
  cap 4): at tick 1512 (50 s) all four squads stood along the north edge side by side: Hunters (-15, 92), Spears (14, 91), Wrenches
  (44, 93), Guns_4 alone (-8, 78). One click west became Guns_4 (-50, 15), Hunters (-46, 70), Spears (8, 58), Wrenches (-25, 117): four
  destinations ~100 m apart north to south, the Wrenches sent back to the north edge, the Spears barely west of where they stood. Again
  at tick 1808: (-60, 20) / (-66, 58) / (-1, 66) / (-72, 110). **The recording has each squad's `to` but not his click point.**
- G1 v9 ON (`--group-g1`, `--group-column-toward=stay`: the column stands; a squad it would send > 10 m away keeps the spot it stands
  on). Code: `selection_squads.gd`, `group_formation.gd`, `rts_controls.gd` `_order_squads`; tests `test_control_column_toward.gd`;
  probe `tests/orders_probe_group.gd` (locks / crossing / terminus x 5 squads x click). The G1 v9 probe's squads start clumped;
  his started side by side in a line 60 m wide, perpendicular to the click. That geometry may never have been in the corpus.
- Unchecked suspicions (yours to confirm or kill, by removal): the column's axis taken from the army's spread rather than the click
  direction; `fit_to_corridor` / the corridor re-lay spreading the column across Locks' streets; `column-toward=stay` keeping squads
  on their own spots because the column's seats are > 10 m from them (four squads, all "far"); a per-squad anchor picked per
  street (planner route spread).
- `make replay-match` / `tests/replay_orders.gd` re-issue his recorded orders (native's; faithful on his round-42 match, R43.9). Run
  it on the 08-21 recording to reproduce tick 1512 headless.

## Backlog (in order)

1. **O0 CP44.0 the `group` marker (first commit, output-identical).** Land e883fc4eb's two lines in `rts_controls.gd` and the KEYS
   entry (`git diff $(git merge-base wip/manoeuvre-scope-g1 main) wip/manoeuvre-scope-g1 -- game/control game/tactics/element_task.gd`)
   with a test that the key reaches the element's task and survives a re-lay; G1 v9 probe byte-identical v main. Message the
   orchestrator the green hash; it merges alone.
2. **O1 record the click (C44.2), merged alone.** `order` row: `click:[x,z]` (the ground point under his cursor before any layout) and
   `group:<n>`. Recorder test; old recordings still read. Green hash to the orchestrator the minute it passes, so his next playtest
   carries it.
3. **O2 his case reproduced and explained.** Replay 08-21 to tick 1512 (and 1808); infer his click point from the four `to`s and the
   layout code, or bracket it. Then a table: per squad, its start, the seat G1 v9 computed, the `to` it got, which step moved it there.
   Remove candidates one at a time until the scatter goes (C43.3's rule: cause before rule). Write the cause up in your Status before
   building anything; message the orchestrator.
4. **O3 the corpus grows his geometry.** Add starts the probe never had: squads side by side in a line perpendicular to the click,
   squads strung along the click direction, one squad detached (his Guns_4), on Locks / Crossing / Terminus and his own seed. Read
   main's G1 v9 on them: how often is a squad sent backwards, how far apart are the destinations, does the closest land in front.
5. **O4 the fix, behind a switch, then Bar G1 v10.** Every squad's destination within one column at his click, ordered by distance
   (closest in front), no squad's goal behind its start along the click direction, the column through the corridor his click is in.
   File the bar in `workstreams.md` *Bars (round 44)* BEFORE any number on 10801-10848: deciding lines on his geometry (spread of
   destinations, squads sent backward, time to the last squad in), guards: G1 v9's own probe lines, manoeuvre's one-squad arrival
   (C44.3), fights (deaths, friendly contacts), the corridor. Symmetric: the CPU's group orders take it (C44.5). Ships ON when it passes.
6. **O5 his case, the acceptance read:** the fixed build on his 08-21 replay at ticks 1512 and 1808; screenshots from above
   (`make control-playtest-shots` style, or a replay frame) of the four squads' seats before/after. Look at them.
7. **Stretch:** the feel question G1 v9 left open (a click right beside his army: squads already in that street hold, only the near ones
   move); the departure order (closest leaves first) if O2 shows crews crossing at the start.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make control-playtest`,
`make two-squads-playtest`; the G1 probe (`tests/orders_probe_group.gd`) via `mk/command.mk`; `make replay-match RECORDING=...`;
screenshots of the column from above, at his click, looked at. Every number with its commit and machine.

## Don't touch

Movement / traffic / the formation's spacing, seat bound, latch, converge (manoeuvre); the planner beyond the grant; `native/**`;
`game/camera/**`; `game/match/**` beyond C44.2; `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. If O2 shows two reasonable readings of "pack it in", write both in player terms (what he would see) with one
recommendation in your Status; keep building the recommended one.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### NOW (2026-10-28, Fable, worktree `godot-orders`, branch `stream/orders`, started from main 711f3e94f = dbf0bf637's code)

- **VERDICT (R44.23): Bar G1 v10c FAILS (part A FAIL, part B FAIL, part C NO DATA). `--group-column=always` stays OFF; nothing
  ships ON.** Series on builder2, BAR_DONE 15:09 laptop clock, frozen tree 805eae5e1 (game code e2d1b499f, probe adc0362f7), arms
  `main` v `--group-column=always`, seeds 10801-10824 (geometry, 1200 runs) / 10825-10836 (streets 384 + his 48) / 10837-10848
  (fights, 48 error rows). Judge read on the laptop over the recorded rows with the judge as frozen; the reading, the tables and
  the runner's log tail: `_agents/streams/references/round44/orders/bar-g1v10c-builder2-805eae5e1/` (verdict_ab.txt). Part A:
  11 of 25 cells pass; deciding 2 (nobody sent back) and 4 (nearest squad in front) PASS every cell; deciding 1, 3, 6 and the
  all-in / never-in guard FAIL; pooled friend contacts 21550 -> 12105 PASS. Part B: places outside the corridor on click cells
  8 -> 26 (bar <= 2), metres driven outside after being in 356 -> 3489 (bar <= 178), all on the Crossing; Locks and Terminus
  unchanged; guards twitch / all-in / end-foreign fail on Terminus and Locks 5-squad cells. Part C never ran: the 5-squad army
  costs 2970 against the probe's 2500 fight budget, both arms wrote 48 error rows, the runner counted them as runs and the judge
  crashed on them (my runner defect; the fight part was never dev-run). Not re-run (R44.23: A and B decide). Fixed on the branch
  for round 45 (this commit): the runner counts error rows and stops the part on the first, the fight arms carry
  `--probe-budget=3000`, the judge's row loader refuses any file with an error row (tested on the series' fight file: REFUSED;
  dev read 9's folder still judges).
- **The five causes, in his terms (what he would see with the switch on):**
  1. **A short click holds half his army.** Click 20 m ahead of squads standing side by side (or with one squad detached) and
     two or three squads sit still (the column counts them as already in it) while the rest drive round to the back of a 90 m
     column: all-move 0-4 % on Crossing across-20 / his-20 and Locks along-20 / his-20; the movers take twice as long to all
     arrive (Terminus across-20 7.2 s -> 14.6 s, Crossing his-20 3.2 -> 8.1 s; builder2, 805eae5e1, n 24).
  2. **On the Crossing a far click lays the column along the wrong street.** His detached-squad start, click 80 m away: the road
     back from the click bends away from where he pointed, the farthest squad lands 67 m across and 75 m aside (bar 52 m), two
     squads hold (all-move 25 %). The same bend is part B's whole failure: 10 of 10 new places outside the street corridor
     on Crossing 3-click (main 0), 16 on 5-click (main 8), and 1728 / 1760 m driven out of the street to reach them (main 83 / 274).
     He would see his squads leave the street he is on to park on the next one over.
  3. **The width he gets is not the width the ground fits.** On along-20 cells (Locks, Terminus, Yard, Yard his-20) some runs lay
     two abreast where that run's clear-ground read fits one (across 35-58 m with fit 1); every SLIDE flag is the same run. He
     would see a two-wide column on a one-wide road in roughly a run in six.
  4. **A squad that never arrives.** Locks across-20 0 -> 2 runs, Terminus across-80 0 -> 3, Yard across-80 0 -> 1 with some squad
     still short of the click at the end; the base's own never-ins vanish elsewhere (Crossing across-20 23 -> 0, Locks his-20
     20 -> 0). He would see one squad of four stuck behind the column at the lock's bank.
  5. **His exact Locks click passes in everything but the judge's 2 m.** The column lays, spread 89 -> 79 m, nearest squad in
     front 0 % -> 100 %, no holds, no one sent back; lines 1 and 3 fail on the tolerance edge (across 2.x m, aside 2.x m against
     fit-one's 0 + 2 m). This cell is the fix doing what he asked, failed by the width of a hull. Honest reading: the shape is
     right on his click and wrong on the clicks around it.
- **Round 45 ideas (ideas, not code; the orchestrator asked for my best on two):**
  1. **Short clicks: seats in place, no column.** When the click is within the column's own length of the army (reach <= about
     the squads' count x 20 m), do not lay a column at all: deal the squads the places nearest the click that they already stand
     nearest to (a stable assignment by distance, every squad moves <= its own slot's distance), so nobody holds and nobody
     drives to the back. A column only makes sense when there is a drive in front of it; a 20 m click is a shuffle, and he reads
     a shuffle as "they moved up", a column as "half of them ignored me". The hold rule (line 6c) then has nothing to hold.
     Test: the across-20 / his-20 cells' all-move goes to 100 % and all-in <= base; today's dev probes read it in a dev read.
  2. **A column on bending streets keeps to the click line.** Read the road only as far back from the click as it stays within
     the street he clicked in (stop the walk at the first bend over ~30 degrees or at the first junction), then lay the rest of
     the column along the straight line back toward the army's centroid, each rank's place pulled onto the nearest standable
     ground (the blocked callable already does this for water and decks). The Crossing's failure is the walk following the road
     round the corner; a column that stops at the corner and continues straight stays in his street and in the corridor. Where
     the straight line leaves standable ground (a wall), the column shortens: squads with no room hold in place per idea 1's
     rule, not behind the corner. Test: part B's Crossing click cells back to main's places-outside; part A's Crossing his-80
     aside <= 52.
  Both are symmetric (C44.5) and live in `SelectionSquads` under the same switch.
- **Plan (in order):** O0 + O1 as ONE commit (both are additive keys at the same two call sites, one check certifies both,
  both merge the same minute; CP44.0's `group` and C44.2's `click`) -> quick-remote -> the G1 v9 probe byte-identical v main
  (locks / crossing / terminus x 7001-7004, 5 squads, click: manoeuvre's R43.34 proof shape, 60 rows) -> `make remote T=check`
  -> green hash to the orchestrator -> O2 (replay 08-21 to tick 1512 / 1808, the per-squad table, remove candidates one at
  a time; cause written here BEFORE any fix) -> O3 (the corpus grows his geometry) -> O4 (the fix behind a switch, Bar G1 v10
  filed before any number on 10801-10848) -> O5 (his case, the acceptance read, shots looked at) -> stretch.
- **O0 + O1 built (this commit):** `order_selection` stamps `click` (the cursor's ground point before any layout) on every order
  of a click; `_order_squads` stamps `group` = the squads of an order to two or more; `_copy_pack` carries `group` onto the
  element's task (e883fc4eb's two lines); `ElementTask.KEYS` + `group`; `UnitCommand.KEYS` + `click`, `group` (the direct,
  no-element path validates commands key by key and would have refused them: a hole in e883fc4eb that the probe, which runs
  with elements, never crossed); the recorder's `order` row copies `click` and `group` when present (additive).
  Test `tests/test_control_order_click_row.gd` (4 tests: row + task on a two-squad click; a one-squad click has `click` and no
  `group`; `group` survives the re-lays of a three-click route on both the running and the queued legs; an old-style command
  writes a row without the keys, and the validator takes them). Laptop NATIVE=off, this tree: the new file + recorder /
  requeue / queued_task / commands / orders / order_refused / preempt / element_task / pack neighbours **71 / 0**.
- **O0 + O1 VERIFIED:** `make quick-remote` builder0, 716e6304e, native on: **425 / 0** (quick passed in 516 s). **CP44.0 output
  proof: the G1 v9 probe (locks / crossing / terminus x 7001-7004, 5 squads, click; manoeuvre's R43.34 shape) 716e6304e v main
  711f3e94f, builder0 light, native off: 60 / 60 rows byte-identical** (`references/round44/orders/o0-probe-identical-builder0-716e6304e/`).
  Full check: launched on the tip (below), the hash named when it is green.
- **O2 CAUSE (found 2026-10-28 ~09:50 PDT, laptop clock; his tick-1512 click reproduced to the metre, tick 1808 to ~5 m):**
  - **Where he clicked:** the lab (`tests/test_control_his_locks_click.gd`: his sixteen living vehicles where the census had them,
    on the real Locks navmesh, through `order_selection`) searched the west half for the click whose four places match the
    recording: **tick 1512 = (-35, 97)**, score 4.5 m summed over four squads; **tick 1808 = (-61, 59)**, 21.8 m (the squads were
    under way). So his first click was **44 m west of his army's middle, 20 m past his Hunters**, on the open north yard: not the
    far west side he describes (the camera stood 100 m back at a 21 deg pitch, target (8, 86); a cursor near the horizon lands on
    near ground). With O1 merged the click itself is recorded, so the next playtest settles that.
  - **What the layout did with it (the per-stage table, `RtsControls.order_trace`):**
    `ranks` (today's body, round 21): four blocks, the widest a 5-crew wedge 44 m wide, **`rank_sizes` = [3, 1]** (3 x 44 + 2 x 14 =
    160 <= MAX_FRONTAGE_M 200): THREE squads abreast ACROSS the approach, 58 m apart, the fourth one rank (56 m) behind. The approach
    was west, so "across" was north-south: a 160 m north-south front for a 44 m move. Raw slots z = 154 / 97 / 40 plus the rear at
    (14, 87); the north edge is 20 m from the click, so `fit_inside` slid the WHOLE body 32 m south: Wrenches (-23.7, 117) at the
    north edge, Hunters (-35, 65) 32 m south of his click, Guns_4 (-46, 8) 89 m south, Spears (14, 55) 56 m EAST of the click (7 m
    from where they stood). `column_lay` returned nothing: the corridor at the click reads [20, 90] m (the yard is open 110 m across)
    and every place is within it or reached by ground, so `on_clear_ground` KEPT today's body (`bodies_kept` +1, `columns_laid` +0).
    `never_behind` pulled the Spears 7 m west; `ground_anchors` moved Guns_4 and the Hunters 7-11 m onto standable ground. Result =
    his recording. Tick 1808: the same ([3, 1], corridor [58, 52], body kept; Wrenches 58 m north, Guns_4 51 m south, Spears 50 m
    east).
  - **Why Bar G1 v9 passed and this still happens:** the column (G1) runs only where the ground at the click is narrower than the
    body; its bar's deciding cells were street clicks (locks / crossing / terminus streets), and its yard_open cell was a GUARD that
    the open yard stays as today. His click was on the open yard, where today's body is kept BY DESIGN (his round-37 note allowed
    "spread out" in an open field), and today's body is round 21's ranks: up to three abreast across the approach. None of the four
    suspicions in the brief (column axis, corridor re-lay, column-toward=stay, planner route spread) is it: the column never ran.
  - **In player terms:** "Your four squads stood in a row along the north edge and you clicked about 45 m west of them, on the open
    yard. On open ground the game lines the army up ACROSS the way you clicked, up to three squads side by side 58 m apart, with
    the fourth behind. Clicking west, 'across' is north-south, so it drew a 160 m north-south line; the map edge was 20 m north of
    your click, so the whole line slid 32 m south: the Wrenches went to the north edge, the Hunters 30 m south of your click, the
    lone Guns tank 90 m south, and the Spears, in the back rank, barely moved. The column of wedges from round 41 only runs in
    streets, never on a yard."
  - **Two readings of "pack it in" on open ground (both in player terms; I build A):**
    **A (recommended, the brief's O4):** the column always: the front squad (or two side by side when the ground is wide) lands ON
    your click, the rest stack behind it along the way you came, nearest in front, farthest at the back; no squad is sent back past
    where it stands. On your click: Hunters and the Guns tank at the click side by side, Spears and Wrenches one rank behind (the
    Spears about where they stood). Everything heads one way. **B:** your click is where the army's MIDDLE goes: front squads a rank
    past the click, rear squads a rank short of it, so every squad moves about the same distance. Easier to read on a short click
    (nobody stands still), but the front overshoots the spot you clicked, and round 37 chose "the column stands at the click".
- **O3 BUILT (faa56b5c3): `make orders-geometry`** (`tests/orders_probe_geometry.gd` extends the orders probe; his 4-squad army
  `tests/control/orders_probe_his_4.json`, Gangs: 5 IFVs / 4 scouts + a tank / 3 support + 2 IFVs / ONE tank): `--probe-starts=
  his|along|across|spawn` re-stands the squads just before the click (a row along the approach 30 m apart as his stood; across it;
  his row with the lone tank 20 m off it just ahead of the front squad), `--probe-reach=M` puts the click M m past the nearest
  squad (his: 20; 80 = a real move); `tests/control/orders_geometry_table.py` reads per run from `start` / `anchor` / the click:
  spread, across-spread, aside_max (the farthest place off the click line: the map-edge push), backward squads (a place behind
  its start along the approach by > 10 m = COLUMN_AWAY_M), front_ok (the nearest squad gets the nearest place), all-in. Main's
  read: builder2, native on, locks / crossing / terminus x his / along / across x reach 20 / 80 x 7001-7006 (108 runs): below.
- **O4 BUILT OFF (add0c2dcb): G1 v10, `--group-column=always`.** The column is laid on open ground too (the clear-ground keep of
  today's body is skipped on a plain click; gates and G2 legs as before), at most TWO abreast (COLUMN_ABREAST), SINGLE FILE when
  the squads already stand in file across the approach (every centre within half a slot of the click line: his row), and the
  G1 v9 stay rule reads ALONG the approach (a place more than 10 m behind where the squad stands keeps it on its spot; a lone
  vehicle 15 m off the line still falls in). Lab (laptop, his tick-1512 click): the Hunters (nearest) land on the click (-35, 95),
  the Spears / Wrenches / Guns_4 hold (already in the column behind it, 0 m back), places within 16 m of the click line, no
  north-south front (today 100 m). `test_v10_lays_his_click_as_one_column`. What he would see on THAT click: one squad moves 20 m
  west onto his spot, the other three stand where they are, in file behind it; on a far click every squad drives, nearest in
  front. **Symmetric (C44.5):** the CPU gives no group clicks (its planner tasks elements one by one; SelectionSquads is the
  player's layout only), so there is no CPU twin, as for G1 v9.
- **O5 (the acceptance READ in numbers; shots still to take):** his tick-1512 click on native's exact replay (N2 `--click=1512:-35,97`,
  a scratch tree = 7b9e7d1a4 + stream/native 9f4eb4f59; laptop, GDScript drive: the layout is the read, not the drive), before /
  after `--group-column=always`: **before** = his recording to within 2 m (Guns_4 (-51.5, 15.3), Hunters (-45.9, 69.5), Spears
  (6.8, 56.5), Wrenches (-23.7, 117.2)); **after** = Hunters (-35.4, 95.1) ON his click, Guns_4 / Spears / Wrenches hold where
  they stand, in file behind it; every order row carries `click` [-35, 97] and `group` 4. Evidence
  `references/round44/orders/o5-replay-laptop/`. Top-down shots need a display (a short windowed run; said here before it runs).
- **Main's dev read of his geometry (O3; builder2, native on, faa56b5c3, 7001-7006, n 6 a cell; `references/round44/orders/
  o3-geometry-dev-builder2/main.txt`):** 13 of 18 cells lay the squads 108-125 m ACROSS the approach (today's three-abreast
  ranks: every `across` cell, every locks cell but along-20, every terminus cell); only crossing's along / his cells stand in a
  column already (its streets; across 4-34 m). The nearest squad lands in front in 17-100 % of runs by cell; nobody is sent
  back > 10 m (0.0-0.5 squads a run); aside max 16-80 m; crossing across-20 never gets every squad in (6 / 6). The v10 arm's
  read on the same cells follows.
- **Dev reads 3 and 4 (builder2, native on, 7001-7006, n 6; `references/round44/orders/o3-geometry-dev-builder2/`) and the code
  they drove (all under the switch):** read 3 (bb70c0152 + the deal / cap / water / shift / hold fixes): contacts 5893 -> 2033,
  10 of 18 cells pass every line; read 4 (+ the final stay rule): 8 cells pass under R44.6's line 6. What read 4 showed and what
  changed since: (a) the room rule read AHEAD of the rearmost start never fitted a near click, so 2-3 squads held where R44.6
  counts them only within the column's length -> the last rank may stand up to 10 m behind the rearmost start (taken, not held;
  on his click every squad falls in a few metres); (b) a rank laid into a Terminus city block was pushed 12 m aside after the lay
  (59 m off the line) -> unstandable ground is `blocked` at the lay, like water; (c) on Crossing a reach-80 click lands at the
  river bank beyond a bridge, and the water read (a 22 m disc) kept every rank "wet" along a road 25 m from the bank, so ranks
  walked 135 m back and three squads held -> water is read at half the footprint (the leader's seat and the inner ring; the
  outer seats are the deploy's), a wet rank follows the road, a lone vehicle's footprint is a hull (4 m); traced on crossing
  along-80 s7002: Guns to the click, Hunters / Spears / Wrenches 4-15 m ahead of their starts in file. Dev read 5 carries these.
- **Dev read 5 (builder2, native on, fee735f2a arm v main, 7001-7006, n 6):** 14 of 18 cells pass every line of v10b as frozen by
  R44.6; lines 1, 3, 4 pass everywhere; contacts 5893 -> 2408. Still failing: crossing his-80 (one squad held in 3 of 6 runs,
  6(a)), locks his-20 (three held, three "backward": the squads behind his click on the narrow bank), terminus across-20 (two
  held; 6(c)). **Superseded by R44.9 before any fresh number:** his answers (`game_design.md` *His answers on the group click*)
  make the rule FIT FIRST; the code and the bar are re-shaped below (v10c) and dev read 6 reads them.
- **O4 v10c (R44.9, FIT FIRST; this commit):** on his plain click a rank holds as many squads abreast as fit CENTRED on the column's
  line with NO slide (`fit_abreast`: k x widest + (k - 1) x GAP_M within twice the narrower clear side; at most COLUMN_ABREAST = 2),
  the rest fold into ranks behind, nearest in front; no rank slides to one side any more (RANK_SHIFT_HALF is G1 v9's), and the
  "single file when the squads stand in file" rule is gone (the ground decides, his answer 2). His Locks click: the yard reads
  [20, 90] m, so one abreast: the Hunters ON his click (-35, 97), the three behind fall in a few metres (Guns_4 14 m north onto the
  line, Spears 9 m, Wrenches 14 m). His target, "the open area in the west side": Locks' west quay reads [42, 50] m at (-62, 50)
  and [46, 48] at (-60, 50): two wedges abreast (102 m) do not fit centred there, so his army would arrive in single file along
  the quay. **Corpus (O3):** `yard_open` added to the maps (an abreast-fits cell: the open yard holds two abreast), and a FIXED
  cell `locks:his:-62/50` (his row along the north edge, a far click INTO the west quay). The geometry line now carries the clear
  ground at the click and the widest squad, for the judge.
- **Windowed run on the lead's desktop (said before it runs, ~12:50 PDT laptop clock):** six short probe runs with `--probe-shots`
  (R44.18's three dev cells x main / v10c), top-down frames at arrival and 5 s after; a stray click during them would be an order
  in a probe match, nothing more.
- **R44.18's three shots (laptop, e2d1b499f, top-down frames 5 s after the last arrival, main v v10c; looked at, with the rows;
  `references/round44/orders/o4-shots-dev8-laptop/`):**
  - **His yard click** (locks, his row along the north edge, click (-35, 97); the probe's row put two squads PAST the click, which
    his real case did not): v10c = the nearest squad lands ON the click, the two east of it hold in file behind it, and the lone
    tank standing 20 m past the click is moved 18 m north onto the far side's line: one file along the edge plus one tank
    aside, no scatter (main: four places 60-90 m apart, one squad sent 30 m south-west). His exact geometry (the lab, no squad
    past the click): one clean file, the Hunters on the spot.
  - **A bending street** (crossing along-20 s7001): v10c = one column along the road, the lone tank on the click and the three
    squads one behind another round the bend (places (-68, 72), (-40, 85), (-5, 85) on the road back); main sent one squad 30 m up
    a side street and left two where they stood. Visibly one column.
  - **The Crossing far cell** (crossing his-80 s7001, the click 80 m on, just across the west bridge): v10c = the lone tank
    crosses to the click, the three squads stand one behind another along the road to the bridge on the near bank (a file, the
    bridge between its head and its body); main spread them 120 m apart with one squad across the bridge and one holding.
  **The yard frame's markers (the orchestrator's question):** white = his click (-35, 97), drawn at the frame's centre-left; the
  frame looks down with the north edge (z 90-117, his spawn row and the barrier) at the BOTTOM, west to the left. Posts (the
  probe's squad order): red = squad 1, the lone tank; yellow = squad 2; green = squad 3; blue = squad 4, the detached 5-crew
  squad. v10c: blue is under the white dot (squad 4, 27 m from the click, took it); yellow (-15, 95) and green (14, 92) hold in
  file east of it; red at the bottom-left = the lone tank's own far-side place (-55, 117): it stood (-55, 99), 20 m PAST the
  click (the probe's row ran through the click), and G1 v6's two-sided lay gives a squad past the click a place on the far side's
  line, which the edge clamp and the standable step put 18 m north of where it stood, on the edge. Not a held squad, not a squad
  the column skipped: the one squad the probe put beyond the click, moved 18 m sideways. His real click had no squad past it.
  No frame shows a scatter the numbers missed.
- **Dev read 8 (the freeze read; builder2, native on, e2d1b499f, both arms, 25 cells, 7001-7006; `references/round44/orders/
  o3-geometry-dev-builder2/dev8.txt`):** 15 of 25 cells pass every line; lines 2, 4, 6 hold everywhere but the two water's-edge
  cells (locks his-20, crossing his-80) and locks along-20; the all-in guard fails on terminus across-20 and yard_open across-80
  (stacked squads arrive later than spread ones; the guard decides as filed, R44.13). Three cells failed lines 1 / 3 on a PROBE
  defect: the clear ground and the road were read along the approach computed before the squads were re-stood, a few degrees
  off the layout's, and a physics frame earlier (50 m clear read where the layout read 52: fit one v two; roads 2.3 m apart v a
  2 m slack). Fixed in the probe alone (adc0362f7: the geometry line is read on the order's tick with the layout's own approach;
  smoke: the probe's clear = the lay's sides). The check queued for f12e61c38 was stopped before it started (remote side first,
  by cwd, then the wrapper) and relaunched on the tip. **FROZEN TREE: 805eae5e1 (docs + the probe over e2d1b499f's game code).
  GREEN on builder2 (13:14 laptop clock): `>> remote: make check exited 0`, 27 targets, 3428 passed / 0 failed; NOT JUDGED as
  builder2 always gives: perf-judge (not a judging machine) and scenario_perf (loaded, ref 2.88x) -> a builder0 read before any
  merge. Bar G1 v10c's series started 13:15 on builder2 (`tests/control/orders_g1v10_bar.sh b2 v10:--group-column=always
  10801-10824 / 10825-10836 / 10837-10848`, jobs 10); the verdict lands here with BAR_DONE.**
- **Watch item (the orchestrator, after main 7975d1455's check):** control-timing's NOT JUDGED line "a right click on 30 units" read
  878 workloads (88.7 ms) on main v 272 on native's tree an hour earlier (both loaded); "ordering 30 units" 557 v 264. Possible
  causes in my paths: load (likely: `--order-trace` is a static read of the command line and `_trace_stage` returns on its first
  line when off; the `click` / `group` keys are one `duplicate()` and two writes an order), to be read on a quiet builder0 with
  `make control-timing` on main AFTER BAR_DONE (no change to the frozen tree before it); the two lines with commit and load go here.
  **Read (main 57a20c9a4, builder0 QUIET, load 0.02 / 0.01 / 0.00 at 15:14 laptop clock, `make remote T=control-timing` from a
  scratch tree at main, --fixed-fps 30; JUDGED 3 passed, 2 failed):** "ordering 30 units takes 226.3 reference workloads (budget
  104; 9.96 ms)"; "a right click on 30 units takes 236.0 reference workloads (budget 104; 10.38 ms)". Load explains 878 -> 236
  and 557 -> 226; both still 2.2x the budget. Next, same machine and flags in the next quiet window (chained after the builder0
  check): the round-44 base 711f3e94f, to tell round 44's merges (O0+O1's keys, native N2) from what was there before.
- **Decisions:** `click` goes on the one-squad row too (its `to` is the click, but one key the tools can rely on beats a
  rule); `group` only on orders to two or more squads (C44.3: his one-squad order stays manoeuvre's); loose units' row
  carries `click`, not `group`.
- **Questions for the lead (no block; A is being built):** (1) reading A or B above; (2) did you mean the far west side? The
  recording puts your click 45 m from your army (see O2); the next playtest's recording will carry the click itself.
- **Requests to other streams:** native: `tests/replay_orders.gd` / `ReplaySetup.merge_clicks` may merge a click's rows by
  `click` + `tick` (today by `to`, which differs per squad, so his group click replays as four orders; it still works).



### Bars (filed here before any judged number; the orchestrator records them on main)
- **Bar G1 v10 THE COLUMN ON OPEN GROUND (orders, round 44; filed 2026-10-28 ~10:05 PDT (laptop clock) BEFORE any number on 10801-10848; code
  add0c2dcb, OFF; dev read on 7001-7006 only).** What he would see: he selects every squad and clicks once. The squad nearest
  his click drives to it; the others fall in behind it along the way they came, one behind another (two side by side at most
  where the ground is wide), nearest in front and farthest at the back; nobody is sent back past where it stands; the places
  are never strung across the way he clicked, and the map's edge never pushes a squad off the column. On his Locks click:
  the Hunters on the spot, the other three hold in file behind. On a far click: one army, one way.
  - **Arm:** `v10:--group-column=always` (everything else as main: G1 v9 ON). Base `main:`.
  - **Tree:** a frozen detached worktree at the commit whose full check is named green here (add0c2dcb or a descendant of it
    with docs only; main's switches as launched).
  - **Part A, his geometry (DECIDING):** `make orders-geometry` on builder2 (native on; the series lock, re-queue on preemption):
    locks / crossing / terminus x starts his / along / across x reach 20 / 80 x arm, **FRESH seeds 10801-10824**, n 24 a cell
    (18 cells, 432 runs an arm). Judge `tests/control/orders_geometry_table.py` per cell (medians over seeds) and per run:
    1. **across_m** (the places' spread across the approach): every cell's median <= 60 m (two abreast = a 44 m slot + the 14 m
       gap; main's smoke: 115-126 m), and no run > 80 m;
    2. **backward** (a place more than 10 m behind its squad's start along the approach): 0 squads in every arm run (main reported);
    3. **aside_max_m** (the farthest place off the click line, the orchestrator's line on the map-edge push): every run <= 52 m
       (a two-abreast place is 29 m off the line and RANK_SHIFT_HALF may slide a rank half a slot, 22 m; nothing else may move
       it); main reported;
    4. **front_ok** (the squad nearest the click at the start gets the place nearest the click, within 10 m): >= 90 % of runs in
       every cell;
    5. **spread_m** reported (end to end; his recording ~100 m for a 44 m move).
  - **Guards (filed now):** part A: each cell's all-in median <= base x 1.2 + 3 s and never-in no more than base; friendly
    contacts (the run row's `friend_contacts`) <= base x 1.1 + 5 pooled. **Part B, G1 v9's own lines:** `tests/control/orders_bar.sh
    b2 g1v8 v10:--group-column=always "10825 ... 10836" <out> 8` (the 12 street cells + his terminus click, n 12 a cell, judge
    `orders_judge.py g1v8` unamended): every R36.6 probe guard per cell, places outside the corridor <= base + 2, sent away > 10 m
    <= base + 2, re-dealt 0; yard_open is NOT a guard this time (v10 changes the open yard on purpose: its rows are REPORTED,
    the deciding lines above judge them through part A). **Part C, fights:** the probe's fight (`--probe-fight=on`, terminus /
    locks, 5 squads, click) on 10837-10848, n 12 a cell: his kills, his losses, the CPU's losses within base +/- 1.645 se.
    **C44.3:** a one-squad order never enters this code (squads.size() >= 2), so manoeuvre's one-squad arrival is unchanged by
    construction; stated, not measured. Fresh-seed series are never amended after their numbers are seen.
  - **Known risk:** a click right among the squads (every squad within COLUMN_NEAR_M = 30 m along the approach) still keeps
    today's body (unchanged by v10; not his case, said here before the numbers); a clump of five squads on open ground with a
    near click may squeeze into two ranks abreast (two abreast x two deep + one) rather than spread as the yard allowed.
  - **Plus:** his tick-1512 click on native's exact replay (O5), before / after, top-down shots looked at. A pass ships ON
    (`--group-column=always` the default, `--group-column=off` the escape).
- **Bar G1 v10b (RE-FILED 2026-10-28 ~11:00 PDT, laptop clock, after two DEV reads on 7001-7006 and BEFORE any number on
  10801-10848; code: the commit below).** The same bar with two lines re-shaped and the code's dev-read fixes; the dev reads are
  in the Status above (`references/round44/orders/o3-geometry-dev-builder2/`). Why: the `across` row standing 30 m from the
  map's edge with the click 20 m ahead has no room for ranks behind, so two squads go to the click and two HOLD where they stand
  90 m apart; v10 as first filed measured the across-spread and the off-line distance over every destination, holders included,
  so that cell could never pass while "nobody sent back past where it stands" holds. A squad that holds its spot is not a
  destination he reads as scattered.
  - **Deciding 1 (re-shaped):** across_m over the squads the click MOVES (a place > 2 m from where the squad stands): every
    cell's median <= 60 m, no run > 80 m. **Deciding 3 (re-shaped):** aside_max_m over moved squads, every run <= 52 m.
    Deciding 2 and 4, the guards, parts B and C, seeds, n and the tree rule: unchanged. **Deciding 6 (the orchestrator's, R44.5,
    added before any fresh number: holding a squad cannot buy the pass; R44.6 shaped it):** (a) in every reach-80 cell `held` = 0
    in >= 90 % of the arm's runs (on a far click every squad moves); (b) in every reach-80 cell the arm's held squads (median a run)
    <= base's squads that moved less than 2 m + 1; (c) in every reach-20 cell, per run, held <= the squads whose start lies within
    the arm's own laid column's length behind the click (the farthest moved place), no slack. `held` is also reported per cell.
    **The bar is FROZEN after dev read 4 (R44.6): no more amendments.** (Re-opened once by R44.9, his answers: v10c below.)
- **Bar G1 v10c (RE-FILED on R44.9, 2026-10-28 ~11:45 PDT laptop clock, BEFORE any number on 10801-10848; code: the commit of this
  text).** His answers: side by side where the open ground fits them, otherwise stacked behind, nearest in front; a short click holds
  the squads already in place. What he would see: he selects every squad and clicks. Where the ground at his click holds two squads
  side by side centred on the spot, two land there side by side and the rest stack behind; where it holds one, they land one behind
  another; nobody slides off the spot toward the open side, nobody is sent back past where it stands, the nearest squad is in front.
  - **Deciding 1 (re-shaped):** every arm run's across-spread over MOVED squads <= the front the clear ground at the click fits
    centred with no slide, + 2 m: (fit_abreast - 1) x (widest + 14), fit_abreast = the most squads (<= 2) whose frontage fits twice
    the narrower clear side (the probe's `clear` at the click, the group scan, 100 m a side).
  - **Deciding 3 (re-shaped):** every arm run's farthest MOVED place off the click line <= 52 m AND <= half the fitted front + 2 m
    (no edge or wall slide).
  - **Deciding 2, 4, 6 (R44.6's shape), the guards (all-in, never-in, contacts; parts B and C), seeds, n, the tree rule:** unchanged.
  - **Corpus (part A):** locks / crossing / terminus / yard_open x his / along / across x reach 20 / 80 (24 cells) + the fixed cell
    locks his (-62, 50) (his far click into the west quay): 25 cells x n 24 on 10801-10824, both arms.
  - **Note for the orchestrator:** the abreast cap stays 2, so line 3's 52 m holds by construction (a two-abreast place is 29 m
    off the line); with three abreast allowed, line 3 would have to read half the fitted front (58 m). **R44.11: the cap stays 2.**
  - **R44.13 (dev read 6's finding, accepted before any fresh number): "off the line" in lines 1 and 3 is the signed distance
    from the ROAD back from his click** (the navmesh drive from the click to the army's START centroid, the squads as they stand
    at the click; identical in both arms; recorded once a run by the probe, never moved by a layout), the straight click line
    when no road was recorded; across = right-most minus left-most offset over moved squads. Thresholds unchanged. The straight-
    line across / aside are REPORTED beside every cell. Code accepted with it: every rank capped by the fit at his click, the
    stay rule a metre inside 10 m, the probe's reach click pulled onto dry ground. The all-in guard decides as filed. **After
    dev read 7: freeze, check, name the hash, run 10801. No further amendments.**

  - **Code since the filing (all under the switch; G1 v9 unchanged, its tests pass):** the near-click keep is skipped on the plain
    click; places are dealt by distance along the approach (no drive-time re-deal, no whole-squad untangle: it read collinear
    drives as crossings and swapped ranks end to end); the stay rule is re-read after the lay; ranks keep off water and decks
    (`wet_or_deck`, stepped back along the line; the deck clear runs even for a click on the lock's bank); the straight-line
    ground cap does not apply to a column's places (they lie along the road back from the click); the ranks behind keep the
    front rank's slide where their frontage fits (no zigzag); squads with no room behind hold their spot instead of merging into
    a three-wide rank.
  - **Dev read 2 (builder2, native on, bb70c0152 arm v main 711f3e94f tree, 7001-7006, n 6; before the last four fixes):** along /
    his cells 113-125 -> 2-16 m across; contacts 5893 -> 4921; the failures that led to the fixes above: across-20 cells kept a
    3-wide rank (116 m), the rearmost squad dealt the front (locks along-80, 17 %), 1-2 never-in on the lock's bank and mouth.
