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
