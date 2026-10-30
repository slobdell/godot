# Stream: camera (ONE planner decides where the camera is at all times: his selection, where it is going and its fight on screen; no building in the way)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 344, 345, 348), `_agents/workstreams.md` **Round 46** (C46.1-C46.8),
> `_agents/judging.md`, your last briefs `streams/archive/round43/camera.md` (the `cam` row, K5's corner look and why it failed) and
> `streams/archive/round42/camera.md` (the danger camera, Bar K4 v2, the clip recipe), and the camera history in
> `game/camera/rts_camera.gd`'s header (his pose: pitch 21, 49 m, FOV 35, settled from play; do NOT change the default pose or lens
> without asking him). **You own:** `game/camera/**`, `game/theme/fx/camera_shake.gd`, `game/ui/camera_readout.gd`, `tests/test_camera*.gd`,
> `tests/camera/**`, `mk/camera.mk`; GRANT read-only feed lines in `game/modes/skirmish_mode.gd` for what the planner reads (selection,
> its orders' paths, contacts). **Model:** Opus (Fable quota low, 2026-10-30). **Machine:** builder3 (checks, series); the laptop for the per-frame budget and clips
> (one Godot run under `flock /tmp/tank-squad-laptop-godot.lock`). **Seeds:** 12201-12248 (Bar C1), 12249-12296 (reserve). Dev
> 7001-7012 (never a bar).

## The lead's direction (2026-10-29 ~23:00, Terminus, verbatim; the full note in `game_design.md` *His playtest after round 45's ships*)

"Then with our camera, it's clearly better, but I had cases in the last match where the camera no longer had any of our selected
squads in view, and when I selected a new squad, the camera didn't pan to it until there was some combat action. Also still, there
seems to be this problem in Terminus where I clearly wish the camera was oriented down a corridor, but it was not and had a building
blocking the view. This was most apparent when I was having a squad move through a corridor, but the camera was still at an angle
with a building blocking it. To review the camera logic, we generally don't want special cases and we ideally want an abstract
algorithm that's planning camera position at all times"

**His design rule is the brief: ONE abstract planner of camera position at all times, no special cases.** The danger look (round 42),
the corner look (round 43, OFF), auto-frame, follow and the block cutaway are today separate rules that take turns; the planner
replaces their *decisions* with one cost over candidate poses. Memory: he rejects UI buttons and "cheating" visuals (no seeing
through buildings to reveal what his crews can't see); he plays on a weak laptop on purpose (C46.7).

## Where things stand (main at launch: see HANDOFF; code 96f199c45 GREEN builder3 3470/0)

- **His recording:** `references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl` (seed 39851, 151 s, laptop, native on; `make
  playtest-report` replay PASS 20/20 for 30 s). It carries `cam` rows (yaw, want, pitch, distance, ground point, mode, TURN) once a
  second and at each automatic turn: `python3 tests/camera/camera_recording.py <file> --from S --to S`. Orchestrator's read: **371 of
  1696 hits/deaths off screen (358 on his units).** Find in it: (a) the seconds no selected squad was on screen, (b) each selection
  change and how long until the new squad was on screen, (c) his corridor drives on Terminus and the building between the camera
  and his squad.
- **Today's camera:** `rts_camera.gd` (2086 lines) + `camera_looks.gd` / `camera_look.gd` (the look rules), `danger_feed.gd` (round 42's
  danger look, ON, `--camera-danger=off`), `camera_corner.gd` (K5, OFF), `block_cutaway.gd`, `follow_camera.gd`. Tools: `camera_trace.gd`
  (`--camera-trace`), `camera_playtest.gd` (`--camera-scenario`, autoplay, clips), `tests/camera/camera_report.py`, `bar_k5.py`,
  `corner_nocheat.py` (the no-cheat check).
- **What failed before and why (don't repeat it):** K5's corner swing turned toward the next building on tight streets, swung back
  after each corner and turned during fights (R43.27-R43.30); the danger look's ambush clearance raised building-clearance jerks
  (1.88/min v 0.07) and seconds inside a building (R42 watch items). Each was a rule added beside the others. A single cost with a
  stability term is what removes the "swing back" class of failure.

## Backlog (in order)

1. **C1 the census on his recording, before code.** From his `cam` rows and the replay (`make replay-match RECORDING=<file>`, which
   rebuilds the scene: you can ray-cast from the recorded camera pose), print per second: is any selected crew on screen (frustum),
   is it occluded by a building (rays camera -> crew), the squad's path direction v the camera's look, contacts on screen. Tabulate
   his three complaints with timestamps. Write the table and your cost terms in Status before code; message the orchestrator.
2. **C2 the planner, behind `--camera-planner=on` (OFF until the bar).** Each frame (or at a fixed rate with smoothing) score a small
   set of candidate poses (yaw steps + ground point + zoom within today's caps; pitch and FOV stay his) by ONE cost:
   - his selection on screen (each selected crew inside the inset frame; heavy),
   - its path ahead on screen (the next N m of its current orders' route),
   - the action on screen (hits on / shots by his units, danger contacts within range of his selection),
   - line of sight: rays from the pose to his selected crews and to the path ahead, penalised by buildings in the way (this is what
     makes "look down the corridor" emerge, not a corridor rule),
   - stability: change of yaw / position from the current pose (no swinging back), and his manual input wins until he lets go,
   - a NEW selection jumps the selection term's weight so the view pans to it at once (no "waits for combat").
   One function, its weights in one table, no per-situation branches. The old look rules stay as the OFF path (`=off` escape).
   Unit tests first: a pose with a building between camera and squad scores worse than the same pose turned down the street; a new
   selection off screen wins within N frames; equal-cost candidates don't flip-flop.
3. **C3 the budget (C46.7).** Measure the planner's ms/frame on the laptop (UHD 620, laptop preset, Terminus, 5 squads), under the lock.
   State the budget in the bar (target <= 0.5 ms/frame laptop; rays batched, candidates few). Anything over goes to a preset knob
   (fewer candidates / lower rate), never a different look on better GPUs.
4. **C4 Bar C1**, filed in `workstreams.md` *Bars (round 46)* BEFORE any number on 12201-12248, base = today's camera, arm =
   `--camera-planner=on`, scripted autoplay on Terminus, Locks, Crossing, Gorge (selection changes, corridor drives, ambushes).
   Deciding lines (what he saw): seconds with no selected crew on screen; seconds a selected crew is occluded by a building while
   moving; time from a new selection to it on screen (<= ~1 s); hits on his units off screen. Guards (what it could break): snaps
   and jerks per minute (K4's G1), seconds inside a building, attack clicks on the aimed unit (K4's watch line), the ambush / retreat
   lines of Bar K4 v2, the frame budget. Ships ON the minute it passes; name the green hash to the orchestrator.
5. **C5 his acceptance read:** the shipped tree on his Terminus replay: his three moments before/after (stills you looked at, the
   census table); clips on the laptop (left today / right planner) of a corridor drive and a selection change, in Status for him.
6. **Stretch:** retire the old look rules' code once the planner has shipped ON for a playtest (not this round's merge); the
   off-screen hit edge marker is NOT this round (C46.5: no new UI).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote` to iterate; `make
camera-*` targets (`make help`); `--camera-trace`, `camera_report.py`, the census on his recording; screenshots and clips at desktop
and phone aspect, looked at. Every number with its commit, machine, workload and n.

## Don't touch

`game/control/**` (orders), `game/tactics/**` and `game/ai/**` (engage / manoeuvre), `native/**`, `game/ui/**` but `camera_readout.gd`,
`game/match/**` (the recorder: ask native via the orchestrator if a `cam` field must be added), `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. If the bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour
(C46.2). Any change to the default pitch, distance or lens is his call: propose it with a clip, don't ship it.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Report (2026-10-30, top = newest).** C1 DONE (adb5c1b13). C2 the planner BUILT behind `--camera-planner=on` (OFF):
`game/camera/camera_planner.gd` + the rig's `_update_planner`; tests `tests/test_camera_planner.gd` (10, laptop 56/0 camera tests
at 53de53ea4). Dev reads only on 7001-7006 (never a bar). In progress: tuning on dev seeds, then C3 (laptop budget) and Bar C1.

### Plan (ordered; smallest foundation first)
1. C1 census tool + table (below) — DONE. 2. C2 `CameraPlanner` (pure cost + candidate set, tests first), wired behind
`--camera-planner=on`. 3. C3 laptop budget. 4. C4 Bar C1 filed, then the series on builder3. 5. C5 his acceptance read.

### C1: the census on his Terminus recording (laptop, tests/camera/census.gd at the C1 commit; recording seed 39851, 151 s, n = 144 seconds with a selection)

**Method.** `make camera-census RECORDING=references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl`. Each `cam` row's
SHOWN pose (yaw, pitch, distance, ground point; his 35 deg lens, 16:9) is rebuilt with `RtsCamera.pose_at` on Terminus; at the
nearest `census` row it projects his crews and rays camera -> hull middle AND hull top against the DRAWN layout
(`RtsCamera.seen`, solids >= 3 m). **His selection = his last order's units** (the recording has no selection rows; every order
goes to what is selected), so a selection changed WITHOUT an order is invisible to it (said, not hidden). "On screen" = inside
the frame and above the command card (0.44 of the half-height below centre).

| His complaint | What the census finds (seconds, of 144 with a selection) | When |
|---|---|---|
| (a) no selected squad in view | **none on screen: 2 s** (0 s, 132 s); **under half on screen: 26 s**; some selected crew off: 63 s | 74-90 s (Guns, strung 110 m from z -3 to -112: the auto frame's 100 m cap shows 1-2 of 5 while the danger look turns S); 100-103 s (4 crews, 1 on, while he had zoomed in by hand to 36 m); 10-13 s |
| (b) new selection did not pan until combat | every ORDERED new selection was on screen at the next cam row (<= 1 s; n = 22) — he orders what he sees, so the proxy cannot see it. **The code shows the cause:** `take_vision()` starts the frame at once, but the glide's **aim hold** (`aiming_now`: his hand moved within 1.5 s and stopped, or the cursor on a unit, or an order armed) coasts the automatic move to a STOP; a selection made by clicking leaves his hand on the mouse, so the pan waits until his hand rests >= 1.5 s, or until a hit swings the danger yaw | aim-hold is the mode on 33 of 209 cam rows |
| (c) a building blocks his squad driving a corridor | **moving 116 s; a building hides >= half of his shown selection 18 s; the view looks > 45 deg off his drive 64 s (55 %)**; both together 13 s | **70-74 s: Wrenches driving N up the x -70 street, the danger look swung the view to SE (yaw -127, 136 deg off the drive): 3-5 of 5 hidden by the blocks.** 10-13 s (2 of 2 hidden, 34-50 deg off); 63-65 s; 104-115 s (his lone scout hidden 7 s) |
| hits on his units off screen | **328 of 1214 (27 %)** | 93-103 s (his group's fight at the x -55 street, 14/37, 26/40, 39/39 off: he had zoomed in by hand), 108-117 s (his scout selected, the army fighting elsewhere) |

**What it says about today's camera:** the danger look turns the yaw toward the enemy (one direction sum), the frame fits his
crews at that yaw, and nothing asks whether a building is between the boom and the crews or whether the view runs along the
street they drive. Three rules (frame, yaw, aim hold) each decide one part of the pose and none sees the others' result.

### C2: the planner's cost (ONE function, weights in one table; written before code)

Every PLAN_S (0.2 s) the planner scores candidate poses and hands the winner to the glide (the springs, the solid clearance and
the manual hand-back stay: they are motion, not decisions). A candidate = a yaw from a fixed set (the current wanted yaw +
12 headings every 30 deg); its ground point and distance come from framing his selection (+ the lean toward its path ahead)
at that yaw under today's caps (16-100 m; pitch and FOV his). Cost, lower wins:

| Term | What | Weight |
|---|---|---|
| selection | fraction of his selected crews outside the inset frame | W_SEL 10 (x3 for NEW_S 2 s after a new selection) |
| path | fraction of his selection's path-ahead points (route, next 40 m, every 10 m) off screen | W_PATH 2 |
| action | contacts that fired at / hit his selection (fading 3 s) + known enemies within 120 m, weighted as the danger feed weighs them, off screen | W_ACTION 3 |
| sight | rays from the candidate's camera to his selected crews (hull top) blocked by a drawn solid; and to the path points | W_SIGHT 4 (crews), 2 (path) |
| stability | the yaw turn from the current wanted yaw (0..1 over 180 deg) | W_TURN 1.5 |
| distance | the zoom-out beyond his 49 m (0..1 to the 100 m cap) | W_DIST 0.5 |

A challenger replaces the current pose only if it is better by SWITCH_MARGIN (0.25): equal costs never flip-flop, and a
small gain never swings the view back (K5's failure). His hand (wheel, keys, drag, rotate) wins for the hand-back time as
today. A NEW selection off screen bypasses the aim hold (he cannot be aiming at what is not on his screen) and triples the
selection term, so the view pans at once. "Look down the corridor" is not a rule: a boom along the street has clear rays.
