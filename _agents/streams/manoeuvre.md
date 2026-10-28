# Stream: manoeuvre (a War Rig nose-on to a container backs out first; his one-squad order lands at his click)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 44** (C44.1, CP44.0,
> C44.3, C44.4, C44.5). Your round-43 brief: `streams/archive/round43/manoeuvre.md` (Status: Bar S / S v2 tables, the read after the
> numbers, the R43.34 candidate and its proof takes 1-4); R43.31 / R43.34 / R43.42 in `workstreams.md`. **You own:** movement's drive /
> unstick / side-step / avoidance / yield (`game/ai/movement.gd` but the planner seam), `game/ai/traffic.gd`,
> `game/tactics/tactics_formation.gd`'s `pitch` / `hull_floor` / `offsets_at` / `fit_to_corridor` / seat bound / shape latch,
> `game/tactics/element_plan.gd`'s `grouped()` and converge, `game/tactics/element.gd` (as the candidate), `tests/manoeuvre/**`,
> `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`, `tests/test_formation*.gd`, `mk/manoeuvre.mk`. **NOT**
> `game/control/**` (orders'; the `group` key arrives through CP44.0). **Model:** Fable. **Machine:** builder0 light lane; builder2
> for a bar series. **Seeds:** 10901-10948 (bar), 10949-10996 (reserve).

## The lead's direction (2026-10-28, verbatim; the full note in `game_design.md` *His playtest after round 43*)

"I once again told squad 1 to go to the west side of the map. These were the gang tanks. The tanks start behind a shipping container.
One of the tanks moved forward right away only to get stuck right away before recognizing it needed to back up. In that case it should
have been obvious to the tank that they should have backed up first to create clearance. I played again to try to reproduce and I
didn't seem to have the same problem."

"Units must look smart" (memory): a tank that drives its nose into a box it could see is the opposite.

## Where things stand (main at launch: dbf0bf637, see HANDOFF)

- **His case** (`references/round43/playtest/2026-10-28T08-15-42-locks.jsonl`, Locks, seed 56416, Gangs, laptop, native ON): his first
  order (tick 0) sent the Guns west; Green_Guns_2 at (-42, 90) read `driving` for 4 s (ticks 0-120) moving under 2 m, then left;
  Guns_3 yielded 3 s to Hunters_1. Native's replay (`make replay-match`) reproduced his round-42 match bit-exact; run it on this one.
- **Built in round 43, all OFF (R43.42):** the seat bound (`--seat-bound=on`), the shape latch (`--shape-latch=on`), the first-tick
  k-turn for a station a hull's length off the crew (`--converge-on-crew=on`, R43.14), `--traffic-on=kturngoal` (native twin
  b2dea555a), `--traffic-on=parkaside` (twin 5b5a2c365). Bar S v2: D1 +13.8 se, D2 -2.4 se, never-arrived -37 %, but FAILED on
  Locks' per-arena give-way guard (+2.4 se; five crews converging on seats within 37 m give way to each other, +4.1 s a run) and G5
  (+3.8 s a run on his 5-squad order, parkaside's seats-beside on a group click).
- **The R43.34 candidate** `wip/manoeuvre-scope-g1` e883fc4eb (off 04ddbcabb, before main's merge of the ship and native's twins):
  `ElementPlan.grouped(task)` scopes the five rules to a squad on its own order; a grouped squad drives as today. Proof take 4: G1
  v9 probe 60 / 60 byte-identical, tests 581 / 0. The two `rts_controls.gd` lines and the KEYS entry land through orders (CP44.0).

## Backlog (in order)

1. **M1 rebase the scoping onto main.** Everything of `wip/manoeuvre-scope-g1` but `game/control/**` and `element_task.gd`'s KEYS
   (orders' CP44.0; until it merges, apply those three lines locally uncommitted to test, or wait; `git merge main` when the
   orchestrator says CP44.0 is in). Re-run proof take 4 on the rebased tree: the G1 probe byte-identical with all switches ON.
2. **M2 his container moment.** Replay 08-15 to tick 120: does Guns_2 nose in on main, and does `converge-on-crew` + `kturngoal`
   (scoped) back it out first? If not, trace why its first leg points into the box (the station a hull's length ahead? the seam's plan
   ignoring the container as a static obstacle?) and fix the k-turn so a crew whose first leg is blocked within a hull length starts
   in reverse. Show it as a before/after trace and a screenshot pair (look at them). Note he could not reproduce it on his second
   match: say what differed.
3. **M3 the Locks give-way (Bar S v2's failed guard).** Five crews of one squad converging on seats within 37 m yield to each other on
   the way in. Two shapes are on file in the archived Status; pick by removal on dev seeds, build behind a switch.
4. **M4 Bar S v3**, filed in *Bars (round 44)* BEFORE any number on 10901-10948: the scoped bound + converge + kturngoal + parkaside
   (+ M2's k-turn, + M3), deciding lines D1/D2 as v2, the Locks give-way line and G5 named as the risks, the G1 group probe as a guard
   (C44.3), fights (deaths, friendly contacts), native twins in the tree (C44.4). Ships ON with `=off` escapes when it passes.
5. **M5 his acceptance read:** the shipped tree on both his recordings' first orders (the 08-15 container, the 08-21 first order).
6. **Stretch:** the bridge drill crew's own cause (R43.38); the street hold on a bar decided on side jam_s (A6 v2's z -5.2, R43.21;
   `game/ai/traffic.gd` is yours; engage's archived Status has the candidate).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make manoeuvre-start-trace`; `make replay-match RECORDING=...`;
the Bar S judge (`tools/judge/`); screenshots of the container start before/after, looked at. Every number with its commit and machine.

## Don't touch

`game/control/**` (orders), `native/**` (ask native for twins), the planner (trace lines only), `game/camera/**`, `game/match/**`,
element_plan's engagement and settle functions, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch.

## Status

_(worker keeps this current)_
