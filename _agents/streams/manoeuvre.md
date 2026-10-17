# Stream: manoeuvre (a wheeled turret vehicle given a facing turns its hull there at rest and sits still: CP-F)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 28 direction* (his call 2: turn
> the whole vehicle), `_agents/judging.md`, `_agents/workstreams.md` **Round 33** (C33.3; R32.3 stands), `_agents/roadmap.md`
> *Round 33 candidates*, your round-32 brief `streams/archive/round32/manoeuvre.md` (*Round 32 close*, *Round-33 lessons*,
> M1b(3)'s carry), brains' `streams/archive/round32/brains.md` (*B11 JUDGED*: its table and reading) and planner's
> `streams/archive/round32/planner.md` (the hull-rest trace: s66 "a `stop` with no face step after the move").
> **You own:** in `game/ai/movement.gd` the body of `drive()`, `_nose_stop`, `unstick`, `_pressing_escape`, H1 / H1b, the
> k-turn / planned-reverse / circle EXECUTOR (`kturn_on` through `_look_stop`, `_kturn_start_leg`, `_planned_reverse`), not
> its plan source; `game/ai/manoeuvre*.gd`, `game/ai/clothoid.gd`, `game/ai/wall_contact.gd`; in `order_controller.gd` the
> face-at-rest path; `tests/test_manoeuvre*.gd`, `tests/test_kturn*.gd`, `tests/manoeuvre/**`,
> `tests/ai_scenarios/scenario_manoeuvre*.gd`, `mk/manoeuvre.mk`. **Granted:** the two aim-lead lines in `gunnery.gd`;
> `TankBrain._order_move`'s decline for wheeled turret hulls under `turnhull` (C31.8). **The C++ (C31.2):** the drive,
> unstick, the executor and the leads have twins; send native each settled diff. Counters go in `ManoeuvreCensus`, never
> `Movement` statics. **Model:** Opus.

## The lead's direction

Round 28, call 2: **turn the whole vehicle to his drawn facing.** No new words at round 33's preparation.

He was told at round 32's close, as a known issue: **a War Rig on a faced move can end ~150° backwards.** What he will
notice when CP-F ships: a War Rig, gang tank or IFV he tells to face a direction ends with its hull pointing there and then
sits still; with brains' B11b on top, one pushed off its post goes back and faces his way again.

## Where things stand (main at the round-33 docs commit; inherits `0c124cf7`'s green check: builder0 exited 0, 2724/0)

- **H1b is ON** (round 32): near-goal settle-short. The far loops are traffic's this round (C33.2); your `H1B_FAR` rows and
  `blocker_kind` are their census tool, so answer traffic's questions about them.
- **The face at rest is the missing piece.** B11 (brains, OFF, `--hold-return=faced`) halved the turreted rigs' error
  (faced_move 48.4 → 17.3°) but the named case s66 Green_Guns_5 still ended > 100°: the return completes inside the 6 m
  settle radius still turned, and nothing faces a wheeled turret hull at rest. Fixed-gun wheeled hulls got worse with B11
  (B11b will touch turret hulls only).
- **A likely main bug (planner's trace, round 32):** hull-rest faced_move s66, both queue arms end ~150° off and the seam
  never acted: a `stop` with no face step after the move.
- R32.3 stands: arrived = the held seat at completion (ARRIVED_M 7 m), re-seats a guarded FAIL line; facekeep unchanged
  for gang hulls; the heading reaches the seating through the arrival halt's shape.
- Your round-32 branch is `round32/manoeuvre` (merged); `lab/manoeuvre-swap2`, `pair/swap-ship` are records only.

## Backlog (in order)

1. **F0 The missing face step (trace first).** Reproduce s66 faced_move on main (hull-rest, drawn, the War Rig); find why
   the order ends in a `stop` with no face step. If it is a bug, fix it alone on its own commit with a test that fails
   without it; a check; name the hash (it may ship before F1).
2. **F1 CP-F, turn the hull at rest (M1b(3), C33.3):** a wheeled turret hull that completes a faced order turns its hull to
   the facing at rest (the planner's face plan where the room needs legs: agree with planner, C33.6 (c), who owns a faced
   finish), then settles. The attack-move settle (crews still moving at 75 s) is the line attempt 2 failed: solve it, don't
   re-prove the turn. Bar first (`judging.md` noise): faced error by class down, never-settled not up, settle time within
   its line, re-seats guarded (R32.3). Whole suite on the pair tree with the switch ON; ships ON as a pair. **Tell brains
   the hash the day it merges: B11b judges on it.**
3. **F2 Help B11b:** brains' turret-only HOLD return judges on CP-F; answer its questions on the face step.
4. **Stretch:** a short clip of a War Rig told to face behind, before and after, for him.

## How to verify

`make quick-remote` to iterate; `make remote T=check` on the pair tree with the switch ON before any series, only for
hashes you name. `make manoeuvre-hull-rest` (one arm a call), `manoeuvre-fights`, `manoeuvre-census`,
`test_manoeuvre_face_behind`, `scenario_cp2`, `native-verify-scenarios`. Build squad-facing fixes on stages that form
elements (lesson 1). Long remote runs under `systemd-run --user`. Every number: commit, machine, workload, n, its row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; the planner's `game/ai/planner/**` and plan source; brains'
`_track_progress`, `_update_phase`, `_approach_gate`, HOLD's return, the re-seat, elements, `game/tactics/**`,
`tank_brain.gd` beyond the granted decline; native's `native/**`; `game/tank/**`, `game/control/**`, `game/match/**`;
`tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Report (2026-10-17, in progress)

| Item | State |
|---|---|
| F0 the missing face step | **DONE: not a main bug** (no fix commit). A real main bug found on the way, in planner's file: stale `PlannerSeam.live()` (sent to planner + orchestrator) |
| F1 CP-F | IN PROGRESS: tracing attack-move's moving-at-75-s (attempt 2's failed line) |
| F2 help B11b | waiting on CP-F |
| Stretch clip | not started |

### F0: s66 faced_move traced on main (2026-10-17)

builder0, main `ae3dad71` (round-33 docs commit), `manoeuvre-hull-one` gangs seed 66 faced_move, n 1 a run, temporary prints
(not committed). **Native path, turnhull OFF (today's game):** Green_Guns_5 ends **109.1°** off, still (squadmates 0.2–172°).
Its move becomes `stop` at f≈360 with 12 m left and stays `stop`: the element's faced hold replaces its move (brains',
round 10's rule), and every face the brain sends it after that (`from` order / sector, and contact when the quiet enemy is
seen) is declined to `stop` by round 8's turret-carries-aim rule (`TankBrain._order_move` ~3487), because turnhull is OFF.
No face reaches the mover, so the seam never acts. **That is the design CP-F changes, not a lost step.** GDScript path the
same (104.9°).

**With turnhull ON** (`--nav-off=turnhull --brains-off=native`, 4 runs; hull-rest is not repeatable run to run): 176 hull
turns, but G5 still ends 44–126° off. Traced: (1) the seam plans G5's face (4–5 legs) and the legs start, then a face
`from: "contact"` (the quiet enemy seen at ~74 m) is declined to `stop` (turnhull lifts only order/sector), so the hull
STOPS MID-PLAN; when the contact drops it gets a new face and a new plan; (2) **stale seam crew (main bug, planner's
file):** once the order leaves face/kturn, `take`/`hold` are never called again, so the Crew is never released and
`PlannerSeam.live()` (no staleness check) reads true to the match end (G5 f≈500 → 2300+). While it does,
`Movement.unstick` returns early for that hull (movement.gd ~3080), `manoeuvring()` reads true, and the census is blind.
Proposed to planner: `live()` false past STALE_TICKS since `tick_seen`, with a test. **Planner's fix:** branch `fix/planner-live-stale` `03d1a50c`
(stale crews released once a tick before any controller runs; `tests/test_planner_seam_stale.gd`), check running; the
orchestrator ruled it R33.3 and will name the hash when it merges. No guard in `unstick` (agreed).

**Agreed with planner (C33.6 (c), 2026-10-17):** manoeuvre owns WHEN a faced finish turns the hull and the residual;
planner owns HOW only while `PlannerSeam.take()` holds the hull (rigs ≥ 10 m). CP-F's at-rest face goes through
`face_turn`, so the seam may take it.

### Plan (ordered)

1. F0 trace (done above).
2. F1: on tuning seeds (not judged ones), trace turnhull's attack-move crews still moving at 75 s; first suspect: the
   contact decline cutting a hull turn mid-plan and the sector face restarting it (churn). Fix under the one switch, test
   first; then the bar to the orchestrator before numbers; C31.1 suite with TURN_HULL_DEFAULT true on the pair tree; the
   judged series on fresh seeds; ship ON as a pair; tell brains the hash.
3. F2: answer B11b.
4. Stretch: the War Rig face-behind clip.

### Decisions

- F0 gets no fix commit: the decline is round 8's deliberate rule, and the brief's "if it is a bug" is answered no.

