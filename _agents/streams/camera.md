# Stream: camera (a new selection pans at once; his squad stays near the middle of the screen)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 345, 352), `_agents/workstreams.md` **Round 47** (C47.1-C47.11;
> C47.10 is your laptop budget), your last brief `streams/archive/round46/camera.md` (FINAL REPORT: the planner, Bar C1, C1 v2),
> R46.20 / R46.23 / R46.37 in `workstreams.md`, and `game_design.md` *His playtest after round 46's ships* (item 4) and *His fifth note*.
> **You own:** `game/camera/**`, `game/theme/fx/camera_shake.gd`, `game/ui/camera_readout.gd`, `tests/test_camera*.gd`, `tests/camera/**`,
> `mk/camera.mk`; read-only feed lines in `game/modes/skirmish_mode.gd` (as C42.3). **Model:** Opus. **Machine:** builder3; the laptop
> only for the lock-held budget read. **Seeds:** 12801-12848 (Bar K), 12849-12896 (reserve). Dev 7001-7012 (never a bar).

## The lead's direction (2026-10-30, verbatim)

Crossing (~15:42): "Also on the camera work, when I change squads, the camera does pan to the target squad but there seems be a delay
between selecting a squad and the camera starting to move toward the other selected squad (I sent half my army west and half my army
east)"

Parade (~16:08): "ok also in my last game, the camera didn't seem to be tracking the squads I was using very well, the camera position
was far away with the squad I was controlling off in the distance at the edge of the peripheral, and the camera position didn't seem
to correct"

His standing rule (round 46): ONE planner of camera position at all times, no special cases. He asked for the planner ON (R46.37).

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0; planner ON, `--camera-planner=off` = round 45's camera)

- **The delay:** at each selection the `cam` row goes to mode `aim-hold` and stays put: Crossing sel Spears tick 838 -> cam (-73, 60)
  unchanged at 840 and 863, first moves at 870 (~1 s); sel Guns tick 663 -> `aim-hold` at 690.
- **Not tracking (Parade, `references/round46/playtest/2026-10-30T16-03-40-parade.jsonl`, 130 cam rows):** median gap look-point to his selection's centre
  **18 m**; **38 % of rows > 30 m**; median camera distance 69 m (up to 100). Worst: sel Bravo ~tick 2941, look (30, 78) v Bravo (51, -73)
  **152 m off**; 2 s later 147, 5 s 107, 8 s 111 m (mode alternating `planner` / `aim-hold`). Delta then 77-92 m off while he panned by
  hand (`manual`). Sumps milder (ticks 3036-3121, 71-78 m off for 3 s; 3541-3601, 21-24 m off at 99 m distance).
- Suspects: `aim-hold` freezing the look on every selection; a slow pan over long distances; the cost preferring a far framing over his
  squad; `manual` pan never handing back. C1 v2 (the rear ambush without losing the building win) is the round-46 leftover.

## Backlog (in order)

1. **K1 planner ON v `--camera-planner=off` on Parade, Crossing and Sumps (Status first, then message the orchestrator):** the same
   gap measures (median, % > 30 m, time to < 20 m after a selection) for both. If round 45's camera tracks better, say which term of the
   planner causes it, by removal.
2. **K2 a selection pans at once, ON:** no `aim-hold` delay on a selection change (the planner's own rule, not a special case); the
   pan to a far squad completes in a time he won't call slow (state the number; ~0.5-0.8 s for 150 m is a starting guess).
3. **K3 his selection stays framed:** the planner's cost keeps his selection's centre within a bound of the look point at a
   distance that shows it (a hard term, not a weight that loses to the fight); `manual` hands back to the planner when he selects.
4. **K4 Bar K**, filed BEFORE any number on 12801-12848 (scripted selection changes in full fights): deciding = % of time his selection
   is > 30 m off, seconds to frame a new selection; guards = Bar C1's lines (hits/deaths on screen, occlusion by buildings, the
   rear-ambush turn), the laptop's per-frame cost (C47.10). Ships ON; name the green hash.
5. **K5 his acceptance read:** the three recordings' gap measures on the shipped tree, before/after.
6. **K6 C1 v2** (the rear ambush) if K1-K5 are done.

## Don't touch

`game/control/**` (orders; selection is theirs, you read it), `game/ui/**` but `camera_readout.gd`, movement / engage / route code,
`native/**`, `arenas/**`, `tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
