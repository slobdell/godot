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
    added before any fresh number: holding a squad cannot buy the pass):** in every reach-80 cell `held` = 0 in >= 90 % of the
    arm's runs (on a far click every squad moves); in every cell the arm's held squads (median a run) <= base's squads that moved
    less than 2 m + 1. `held` is also reported per cell.
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
