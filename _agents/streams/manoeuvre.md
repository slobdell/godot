# Stream: manoeuvre (a War Rig nose-on to a container backs out first, on the poses Bar B1 lost; then S v4 and holdway)

> Read `_agents/orchestration.md` (the worker contract; lesson 339), `_agents/judging.md`, `_agents/workstreams.md` **Round 45**
> (C45.1, C45.3-C45.6). Your last brief: `streams/archive/round44/manoeuvre.md` (Status: Bar B1's tables, the two losing patterns, the
> round-45 notes, the proof takes); R44.7, R44.19, R44.21, R44.24, R44.25 in `workstreams.md`. **You own:** movement's drive / unstick
> / side-step / avoidance / yield / backout (`game/ai/movement.gd` but the planner seam), `game/ai/traffic.gd`,
> `game/tactics/tactics_formation.gd`'s `pitch` / `hull_floor` / `offsets_at` / `fit_to_corridor` / seat bound / shape latch,
> `game/tactics/element_plan.gd`'s `grouped()` and converge, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`,
> `tests/test_traffic*.gd`, `tests/test_formation*.gd`, `mk/manoeuvre.mk`. **NOT** `game/tactics/element.gd` this round (engage's; ask
> through the orchestrator) nor `game/control/**` (orders). **Model:** Fable. **Machine:** builder0 light lane; builder2 for a bar
> series. **Seeds:** 11149-11196 (Bar B2), 11401-11448 (Bar S v4), 11449-11496 (reserve, A6 v4).

## The lead's direction (2026-10-28, verbatim; still open)

"The tanks start behind a shipping container. One of the tanks moved forward right away only to get stuck right away before
recognizing it needed to back up. In that case it should have been obvious to the tank that they should have backed up first to create
clearance."

His round-44 playtest (Gorge) did not repeat the container, but the bar is "units must look smart" (memory) and lesson 339 applies:
backout has failed one bar (B1) with every guard green. Ship it ON this round if B2 passes.

## Where things stand (main at launch: 972e4bb57, code a93271a66 GREEN builder0 3446/0, see HANDOFF)

- **Backout** (`--traffic-on=backout`, with parkedpass), OFF; C++ twin r3 EQUAL (R44.24). Bar B1 (R44.25, frozen 9111520bf,
  11101-11148): D1 his start PASS (Guns_2 reverses t4 v t44); D2 corpus FAIL 71 % v 80 % (21 base-stuck poses); every guard PASS.
  Losing poses: **13** (crossing, alone, +55 deg, nose 0.0 m: `looks 0`, the look never fires, arms identical) and the **crossing
  crawl 10 / 6** (+50 / +60 deg, a squadmate crawling ahead: the back-up lands, then a second k-turn, +1.7 to +5.3 s).
- **S v3** (seat bound + converge + kturngoal + parkaside, scoped to a squad's own order) FAILED its wedged guard (R44.7). **A6 v3
  holdway** FAILED its head-on guard (R44.19). All OFF.
- Evidence: `_agents/streams/references/round44/manoeuvre/`, `~/overnight-manoeuvre/r44/` on the laptop.

## Backlog (in order)

1. **M1 pose 13: why the look never fires.** `--turn-trace` on the dev pose: which gate (steering point within a hull's length,
   |speed| < circle speed, the window) refuses; fix on the dev pose only; tests first.
2. **M2 the crossing crawl (poses 10 / 6).** The back-up then a second k-turn: the departure vertex it backs out against is not the
   vertex the drive then wants. Back out against the vertex the drive will take (or re-read it after the back-up); dev poses only.
3. **M3 native twin** of M1 + M2 (message the orchestrator; native cuts it, C45.4), proved EQUAL + the default orders probe 60/60.
4. **M4 Bar B2**, filed BEFORE any number on 11149-11196: B1's shape (it was sound: floor met, guards green), D2's 80 % line
   unchanged; add orders' G2 places and engage's authority probe as guards (C45.3). Ships ON with `--traffic-on=backout` the default
   and `--traffic-off=backout` the escape the minute it passes; message the orchestrator the green hash.
5. **M5 S v4** on 11401-11448: S v3's wedged guard failure traced by removal first; file before numbers.
6. **M6 A6 v4 holdway** with a one-sided head-on guard (the round-44 note), reserve block.
7. **Stretch:** backout on grouped squads (after orders' G2 lands; C45.3); the two-squad press design note (archived Status).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>`); `make manoeuvre-start-trace`; `make replay-match RECORDING=...` on
his round-43 container recordings (`references/round43/playtest/2026-10-28T08-15-42-locks.jsonl`); the B1 judge; before/after shots
of each pose, looked at. Every number with its commit and machine.

## Don't touch

`game/control/**` (orders), `game/tactics/element.gd`, `drills.gd` and element_plan's engagement functions (engage), `native/**`, the
planner (trace lines only), `game/camera/**`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
