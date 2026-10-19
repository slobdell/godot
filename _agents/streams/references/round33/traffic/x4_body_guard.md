# Round 33 traffic X4: R33.14's body-stage guard on T4, verdict FAIL as filed (lines 2, 3), every fail at seed 2

Tree `pair/ghost-on-r33` `95f85afc` (game code = `bbb4d2db`: ghost ON by default; OFF arm `--traffic-off=ghost`), builder0
light lane, 2026-10-17 ~16:40 PDT, `make traffic-body-guard` (tests/traffic/body_guard.gd: the front file's tests as the
runner runs them, then BodyStage.run seed s body OFF then body ON on one case, 60 s, `--fixed-fps 60`). n 9 a side for
the filed cells (seeds 1-3 x fronts none / test_det_core / test_rts_camera). The run also did seeds 4-6, because brains'
`mk/tactics.mk` already defines `BODY_SEEDS ?= 1 2 3 4 5 6` and it shadowed mine. Those cells are REPORTED only
(`x4_body_guard_s1-6_reported.txt`), and the variables are renamed `BGUARD_*`.

Filed table: `x4_body_guard_s1-3.txt`. Raw rows: `x4_body_guard_rows.txt`.
- (1) median body-ON alone_s, ghost OFF 15.0 v ON 15.0 (line 18.0): PASS.
- (2) every ghost-ON cell body-ON < 0.5 x body-OFF: FAIL. 6 of 9 pass. The 3 fails are seed 2 at every front
  (15.5 / 16.0, 15.5 / 16.0, 14.5 / 15.0).
- (3) the Sirens choose "body" in every ghost-ON cell: FAIL. Same three cells, seed 2.

## Seed 2 traced
- **The choice is the same in both arms, and right**: Sirens own route 103.0 m with 24.6 m alone, body route 123.6 m
  with 22.4 m alone, so "own" (the split doesn't leave them alone). The choice is made from the spawns' geometry before
  anything drives. The ghost can't change it, so line (3) fails at seed 2 on ANY tree, ghost OFF included (ghost-OFF
  seed-2 cells: "own" at all three fronts).
- **Line (2) fails at seed 2 because the ghost-OFF baseline is a non-arrival**: ghost OFF body-OFF alone 56.5 s, with the
  army never all in (arrived -1). Ghost ON, the same squads arrive (19.0 s) and the Sirens are alone 15.5 s, so body ON
  has nothing to halve. With the front test_rts_camera the ghost-OFF arm fails the same line (12.0 / 12.0).
- The earlier suite-order signal (body-ON alone 18.5 s with the ghost ON behind test_rts_camera) did NOT reproduce in
  this probe: seed 1, test_rts_camera, ghost ON 13.5 v OFF 12.5. One difference from the runner: the probe runs at
  `--fixed-fps 60`, while `make test` doesn't.

Reading: as filed, the guard fails and T4 parks. Every failing cell fails the same way (or worse) with the ghost OFF,
and the cause is the stage's seed 2 (its geometry, plus base's stuck arrival), not the ghost. Whether that's a bar
defect is the orchestrator's call.

## R33.16 (the orchestrator, main a5a59313): the relative form; verdict FAIL on (2'), T4 PARKS

Read from the same rows, seeds 1-3 (4-6 reported only). (2') every cell: body-ON alone_s ghost ON <= ghost OFF + 3.0 s.
(3') the Sirens' choice is the same ghost ON and OFF in every cell.

| front | seed | body-ON alone ghost OFF | ghost ON | line OFF+3.0 | (2') | Sirens OFF / ON | (3') |
|---|---|---|---|---|---|---|---|
| none | 1 | 15.0 | 15.0 | 18.0 | pass | body / body | pass |
| none | 2 | 15.0 | 16.0 | 18.0 | pass | own / own | pass |
| none | 3 | 17.0 | 12.5 | 20.0 | pass | body / body | pass |
| test_det_core | 1 | 15.0 | 15.0 | 18.0 | pass | body / body | pass |
| test_det_core | 2 | 15.0 | 16.0 | 18.0 | pass | own / own | pass |
| test_det_core | 3 | 17.0 | 12.5 | 20.0 | pass | body / body | pass |
| test_rts_camera | 1 | 12.5 | 13.5 | 15.5 | pass | body / body | pass |
| test_rts_camera | 2 | 12.0 | 15.0 | 15.0 | pass | own / own | pass |
| test_rts_camera | 3 | 7.0 | 12.5 | 10.0 | FAIL | body / body | pass |
(2') FAIL | (3') PASS

**(2') fails in ONE cell, test_rts_camera seed 3**: ghost OFF 7.0 v ON 12.5 (line 10.0, +5.5 s). test_rts_camera seed 2
sits exactly on its line (12.0 v 15.0). (3') passes in all 9 cells. Both forms: filed (2)/(3) FAIL at seed 2 (a bar
defect, R33.16); relative (2') FAIL at rts_camera s3, (3') PASS.

**The failing cell traced (from its rows):** ghost ON, the army is in at 19.1 s (Hunters2 10.2 s), and the Sirens are
alone 12.5 s, the same 12.5 s ghost ON shows at seed 3 behind every front. Ghost OFF, Hunters2 is late (13.0 s), the army
is in at 23.1 s, and alone falls to 7.0 s; with no front, the same ghost-OFF cell reads 17.0 s. So the front moves the
CONTROL arm here (17.0 -> 7.0), and the ghost-ON arm is steady and 4 s sooner. That is the stage's known order
sensitivity (body_stage.gd:31: "alone_s 12.0 run first and 24.5 run after"). The relative line still fails as filed, so
T4 parks (R33.16).

**fixed-fps note:** at --fixed-fps 60 (the probe), seed 1 behind test_rts_camera reads ghost ON 13.5 v OFF 12.5. In the
suite (make test, no --fixed-fps) the same order read ghost ON 18.5, and ghost OFF 12.0 (stream/traffic, light lane).

**Close-out note (brains via the orchestrator, after R33.17):** most of the suite's order swing on this stage is wall-clock
pacing. `make test` runs without `--fixed-fps`: up to 9 s swing unpinned v <= 2 s at `--fixed-fps 60` (laptop, ghost OFF),
which fits this probe's 13.5 v 12.5 against the suite's 18.5. The remaining ghost-ON carry in one process is the physics
server's real_velocity (`x4_rematch_statics.md`). Round 34's T4 guard: tests/tactics/body_probe.gd as child processes at
`--fixed-fps 60`, one arm a process (brains' f8cf6476 shape), plus a replay line.
