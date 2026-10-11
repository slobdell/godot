# Stream: orders (facing for every armed order: press at the spot, drag toward the facing, release)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* (his words,
> reading (5)), `_agents/legibility.md`, `_agents/ui_kit.md`, `_agents/workstreams.md` *Round 26* (C26.3 is yours). You own
> `game/control/**`, the order hints in `game/ui/**` (help/hint text about order input only; list what you touch in
> Status), `tests/test_control*.gd`, the control playtests and their targets in `mk/command.mk`.

## The lead's direction (2026-10-10)

> *"I was trying to get tanks oriented in a screen at a particular angle, and therefore I was trying to click on one
> target then shift+screen at another point such that the first point would determine the direction of the screen, but
> this didn't work. it short-circuit directly to screen and so the vehicles moved into a line abreast angle I didn't
> want. This is probably the case for all our specialized cases (attack, ambush, screen, etc)."*

Reading (5), decided for him (reversible): today an armed order fires on the left PRESS (`rts_controls.gd`
`_left_button` → `armed_click_order`), so it can take no direction, and shift means "queue", so his shift-click queued
a second order instead of aiming the first. Only a right-drag move takes a facing (round 9). **An armed order gets the
same gesture as the move: press at the spot, drag toward the way they should face, release.** A plain click (no drag past
the round-9 threshold) keeps today's automatic facing. Shift still queues (shift + drag queues a faced order).

## Where things stand (VERIFY at main)

- Right-drag move with facing: `rts_controls.gd` (round 9 threshold constants near line 37, `_draw_facing_drag`,
  `right_click_order(at, queue, facing)` putting `extra["facing"]`, which reaches `task["facing"]`, `ElementTask.facing`).
- Armed orders: `arm()` / `armed_click_order()` for `attack_move` (a click on an enemy = attack that target: no facing
  there), `follow` (no facing), `move`, `screen`, `support_by_fire`, `ambush` (`TaskPalette.element_only()`).
- Tests to copy: `test_control_facing_drag.gd`, `test_control_screen_task.gd`, `test_control_facing_camera.gd`;
  playtests `screen_playtest.gd`, `control_playtest.gd`.
- Whether each armed TASK honours `task["facing"]` is brains' B0 (C26.3, CP0). Until CP0 merges, test against your own
  stub.

## Backlog (in order)

**O1 — the gesture.** For `screen`, `support_by_fire`, `ambush`, `attack_move` (on ground) and armed `move`: the order is
decided on RELEASE; press sets the spot; a drag past the round-9 threshold draws the facing arrow (same look as the
right-drag) and puts `facing` on the order; a click without drag is exactly today's order (no `facing` key, C26.3).
Tests first: unit tests per order kind (click = byte-identical order dictionary to main; drag = `facing` normalised
toward the release), shift + drag queues, Escape / right press during the drag cancels, a drag that ends above the
horizon refuses with a notice. Touch (phone aspect): keep a tap working as today; a press-drag on touch is the same
gesture if the touch path routes through `_left_button` — say in Status what it does.

**O2 — end to end after CP0.** `git merge main` when told CP0 landed; a scripted playtest (copy `screen_playtest.gd`):
his case — select two squads, arm Screen, press at a point, drag toward a second point, release — and assert the line's
heading on the ground within 15° of the drawn facing, for each armed task; screenshots at his pose (desktop and phone
aspect), looked at. Report any task that ignores the facing to brains through the orchestrator.

**O3 — legibility.** The hint/help text names the drag ("drag to face"); the order marker shows the facing it was given
(the move's arrow) so he can check it after the fact. Screenshots looked at.

**O4 — stretch:** a facing for a QUEUED armed order shown on its marker in the queue; and a facing on attack (enemy
click): not without a design reason — write the question in Status instead.

**O5 — `make showmatch` (added 2026-10-11, the lead's words: *"is there a way that you can create a 'make demo' or
something like that ... just pit 2 computer players against each other so I can easily record the game to share with
people"*; PRIORITY after the `_same_order` fix).** Built on `make cinematic`: a clean feed (no HUD, hints, order chrome
or planning pause; announcer and music on; `HUD=1` keeps the score bug); random BOTH factions (never a mirror) and arena
from a printed seed (DEMO_SEED), pinned by FACTION= / ENEMY_FACTION= / ARENA= / SEED=; the army follows the machine's
preset (C25.6) unless SIZE=; `MOVIE=path` records with Godot's Movie Maker at 1080p, fixed fps, audio included; the
match ends cleanly (the end banner ~5 s, then quit when recording). Named `showmatch` because `make demo` is play.mk's.

## How to verify

`make remote T=check`; your playtests headless on builder0 and windowed on the laptop for screenshots (C26.7: ask the
orchestrator). Look at every screenshot you produce.

## Don't touch

`game/tactics/**` (brains': how a task USES the facing), `game/ai/**`, `native/**`.

## Waiting on the lead

Nothing; he judges the gesture in play.

## Status

_Updated 2026-10-11 evening (worker, `godot-orders`): final report for round 26 below._

**Plan (in order):** O1 the gesture (tests first) → O3 legibility (the hint text and the marker; small, and the
marker already reads a task's facing) → the O2 probe built now on today's code (it shows which tasks ignore a drawn
facing BEFORE CP0, so B0's effect can be measured) → O2 proper after CP0 (`git merge main` when told) → O4 the stretch.

### Done

- **O1 the gesture** (`6ce8a8ab`): `rts_controls.gd` `_armed_press` / `_armed_release` / `armed_gesture()`. Screen,
  support by fire, ambush, attack-move on the ground and armed move are decided on the left RELEASE. Press = the spot;
  a drag past `FACING_DRAG_PX` (18 px, the right-drag's threshold) puts `facing` = the normalised ground direction
  from the spot toward the release on the order (`extra["facing"]` → `task["facing"]` through the existing
  `assign_task` / `_task_squad` copy, C26.3); a click is main's order (no `facing` key). Shift-drag queues a faced
  order and stays armed; Escape or a right press mid-drag cancels (and disarms, as both did before); a release above
  the horizon used to REFUSE; since the ruling below it faces the last ground crossed, as the right-drag does. Follow and attack-move pressed on an enemy still fire on the press (their heading is their target's). The
  armed drag draws the right-drag's ring and arrow in the order's colour. Tests: `tests/test_control_armed_facing.gd`
  (23); the click tests pass on main's `rts_controls.gd` too (byte-identical command), the 12 drag tests fail there.
- **O3 legibility** (`6ce8a8ab`): the armed hint under the pointer, the command card tooltips (`TaskPalette`) and the
  first-time hints (`ControlHints`) say "drag to face". The order pin already draws a task's facing (task wins over the
  crews' orders, round 9) and a direct order's; tests assert it for a dragged screen and attack-move, and that a click's
  pin draws none. Found on the way: the HUD line for a task order said "3 units: ?" (`describe()` had no task verbs);
  it now says "3 units: screen facing E".

- **O4 stretch (a)** (`f21f9933`): a QUEUED faced order (a shift-dragged move or attack-move) shows its heading as
  the pin's chevrons at the middle of its crews' queued stops, one per order (`queued_facings()`; a squad's task never
  queues, tasks replace). Test in `test_control_armed_facing`.
- **Check:** `1805fdde` (O1+O3+O4 + the probe's first form): **builder0 `make check exited 0`, 2401 passed / 0 failed**
  (main's 2377 + 24 of mine), thirteen sim hashes unmoved, determinism 762a0576f944f5b7; 2 NOT JUDGED were the CPU
  timing judges refusing on a busy box (`perf-judge` 2.55-2.68x, `scenario_perf` unpinned), nothing of mine.
- **O2 probe, built before CP0** (`make facing-probe`, `make facing-shots`; `ScreenPlaytest` `faced_*` scenarios
  through `--screen-only`, so `game/modes/**` is untouched): squads 1 and 2 selected, the task key, the REAL left
  press-drag-release 60 deg off the travel, one fresh match per task; judged when both squads' elements say arrived
  (75 s at most) + 15 s: mean hull heading, the line's normal (line tasks), crews whose own order carries the heading.
  **Before CP0** (`86895573`, builder0, foundry seed 3, n = 1 per task, 14 + 7 gang crews; the gesture's own error 0.0
  deg on every task, i.e. `task["facing"]` = the drawn heading):

  | task | arrived | crews told (sq1, sq2) | hull error deg | line error deg |
  |---|---|---|---|---|
  | screen | 13 s | 1/14, 0/7 | 79, 105 | 46, 18 |
  | support by fire | not in 75 s | 2/14, 0/7 | 154, 112 | 76, 49 |
  | ambush | not in 75 s | 1/14, 0/7 | 78, 142 | 75, 48 |
  | attack-move | sq1 only | 2/14, 0/7 | 81, 27 | - |
  | plain move | 27 s | 12/14, 7/7 | 69, 140 | - |

  Every task ignores the facing today (expected: B0 is brains'), and a plain two-squad move gives every crew the heading
  yet its hulls are still 69/140 deg off 15 s after arrival. Sent to the orchestrator for brains (2026-10-11).
  Probe history, so the numbers are read right: the first form read its screen points a frame stale (gave a heading up
  to 30 deg off the drawn one) and ran all five tasks in one match (later tasks ran into contact); both fixed.

- **Found in the first windowed frames, fixed** (`ed6d6b29`): (1) the drag arrow (armed AND right-drag) was drawn from
  the pressed PIXEL, and the vision camera reframes the selection during a drag, so the arrow floated ~90 px off its
  ring; it now starts at the spot as the camera sees it now (the facing itself was always right: it is computed on the
  ground). (2) The longer "drag to face" hint ran off a 1200x540 screen over the radar; `mode_hint_at` flips it left
  of the pointer near the edge and keeps it on screen.
- **O4 stretch (b), a facing on attack (an enemy clicked): not built, a question.** An attack's heading is its target's
  (the hull or turret follows the enemy), so a drawn facing would be either ignored or fighting the gun. The one design
  reason I can see: *attack from a side* (drag = the approach direction, e.g. to hit a tank's flank). That is a
  different order (an approach vector, not an arrival facing) and would need brains' attack task to read it.

### Questions for the lead (decided overnight by the orchestrator, 2026-10-11; both reversible after he plays)

1. Attack with a direction (press on an enemy + drag = come at it from that side): **not this round**, he did not ask
   for it. Round 27 candidate: an approach vector on brains' attack task, drawn as press-on-enemy + drag.
2. A drag released above the horizon: **the right-drag's rule**, the last ground the drag crossed is the heading, no
   refusal (one gesture, one rule). Built in the commit after `ba3e3480`.

- **CP0 merged** (`6e480393` = `7f792de9` into this branch): builder0 `make check exited 0`, **2417 passed / 0 failed, ALL
  JUDGED**, thirteen unmoved, determinism 762a0576f944f5b7.
- **O2 after CP0** (the probe, `make remote LIGHT=1 T=facing-probe`; quiet arm = the enemy holds at its base,
  `--enemy=player_default --no-element-cpu`, no enemy within any crew's sight radius in any run, judged; contact arm =
  the seeded CPU, reported only). Judged per ELEMENT (a gang control group holds two or three elements), when every hull
  has been still 3 s or at 75 s. Quiet arm, `19f6a418`, builder0, foundry, seeds 3/5/8, 15 elements per task:

  | task | lines within 15 deg | line err median/worst | gun err median/worst | hull err median/worst |
  |---|---|---|---|---|
  | screen | 12/15 | 7.1/18.4 | 0.0/30.0 | 45.1/169.2 |
  | support by fire | 11/15 | 8.9/46.3 | 0.0/30.0 | 92.0/176.6 |
  | ambush | 12/15 | 4.4/20.1 | 30.0/30.0 | 99.8/175.1 |
  | attack-move | - | - | 0.0/155.9 | 38.4/162.9 |
  | move (armed M) | - | - | 0.0/30.0 | 34.8/113.2 |
  | move (right-drag, round 9) | - | - | 0.0/30.0 | 54.3/131.8 |

  **Read:** the line lies across the drawn facing and the guns point it (30 deg = brains' interlocking sectors); the
  HULLS do not, on every order including round 9's plain right-drag. order_controller (~482): a wheeled turreted hull
  keeps its arrival heading by design and its turret takes the facing; the orchestrator asked manoeuvre (face-at-rest,
  C26.9) to split hull numbers by hull class. Ambush's guns at a flat 30 deg are odd (for brains). Few runs settle in
  75 s (crews still nudging); the before-CP0 table above is the "before".
- **O2 after CP2** (main 2aadc60c merged = `5acc4c42`; M1b turn-at-rest + reverses for short moves behind). Quiet arm,
  builder0, foundry, seeds 3/5/8, 15 elements per task, same probe as above:

  | task | lines within 15 deg | line err median/worst | gun err median/worst | hull err median/worst (CP0 -> CP2 median) |
  |---|---|---|---|---|
  | screen | 12/15 | 4.7/18.8 | 0.0/30.0 | 38.9/107.2 (45.1 -> 38.9) |
  | support by fire | 11/15 | 4.4/61.3 | 0.0/30.0 | 27.2/160.9 (92.0 -> 27.2) |
  | ambush | 11/15 | 6.3/30.6 | 30.0/30.0 | 45.5/167.4 (99.8 -> 45.5) |
  | attack-move | - | - | 0.0/164.2 | 29.2/103.8 (38.4 -> 29.2) |
  | move (armed M) | - | - | 0.0/30.0 | 36.0/153.1 (34.8 -> 36.0) |
  | move (right-drag) | - | - | 0.0/30.0 | 59.0/157.5 (54.3 -> 59.0) |

  **Read:** the hulls of the line tasks now mostly turn to the drawn facing (support by fire and ambush medians halved
  or better); plain moves did not change. Each task still has a tail of hulls 100-167 deg off, and no run is still
  for 3 s inside 75 s (`runs settled` 0/3 everywhere), so these are 75 s readings. Support by fire and ambush report
  0/15 operational `arrived` while their lines are already within 15 deg: that flag is the element's, worth a look
  by brains. Hull numbers stay manoeuvre's (C26.9).
- **Found by main's check** (`test_control_order_marks` failed on main d28bf8c5, 1/2392; builder0 diagnostics). Since
  B0 the leader's first issue copies a task's facing onto its crews' orders, and a task re-given WITHOUT a heading
  leaves the crews on the old one. Two halves:
  1. **Orders' half, fixed** (`518d7775`, approved by the orchestrator): `Orders._same_order` dropped an element order
     that only lost its heading as a repeat. Now facing present vs absent is a new order (drift still ignored; no heading
     on either side = the old rule, so the thirteen lines did not move). Unit test in `test_control_armed_facing`.
  2. **His re-order was already fine; the stale path is off the player's team.** My first repro used the control
     fixture, which sets no "player_team" meta, so `Element.preempting()` is false and the element re-issues only on
     its own cadence; there `Element._should_issue` (no heading compare) kept the old heading 360+ frames (builder0 at
     `ba541b96`). On his team the task's first update re-issues every crew under the new task id and the heading sheds
     in ~5 frames (brains measured, builder0 lab 8fd6209a). So `tests/ai_scenarios/scenario_orders_facing.gd` now
     sets `player_team = GREEN` and is REQUIRED (orchestrator's ruling); the off-team path is brains' 3214dddf
     (`_should_issue` treats a heading given / taken away / turned >20 deg as a new intention), tested in their
     `test_tactics_reorder_heading`.
  The pin test no longer depends on this: it judges the pin on the task alone, with both assigns in the same frame
  (`1e58cc7c`, reason C26.6 in the test).
- **Settled frames** (`facing-shots`, `--enemy=player_default --no-element-cpu --no-vision-camera`, 1854x1011 and
  1200x540): `_1_drag` (ring + arrow in the order's colour on the spot), `_2_moving` (the pin with its chevrons),
  `_3_settled` (the camera back on the spot; the line across the arrow, guns along it). Looked at on builder0's output
  at `19f6a418`+: the arrow sits on its ring, the hint stays on screen at both sizes. Since `681f0d22` windowed runs
  move the OS pointer with their events (the hint and hover tooltip follow the real pointer, so they had shown where
  the window's pointer was left, over the command card at 1200x540); rerun on builder0: the hint sits at the arrow tip.

### Report (2026-10-11, final for round 26)

**State:** every backlog item is done (O1-O5, O4 (b) written up and decided); merged on main as `aca71957` (green
`702269f7`, builder0 2449/0, ALL JUDGED, thirteen unmoved). One thing left: after brains' heading fix (3214dddf)
reaches main, `git merge main` and rerun the quiet probe (the after-CP2 table above is its baseline).

**What he'll notice when he plays:**
- Any armed order (Screen E, Support by fire R, Ambush B, Attack-move A, Move M): press on the ground where they
  should go and DRAG toward the way they should face, then let go. A ring and an arrow in the order's colour follow the
  drag; the order's pin then carries chevrons pointing that way. A plain click is exactly the order it always was. The
  hints and the command card's tooltips say "drag to face".
- Shift-drag queues a faced move or attack-move (its heading shows on the queued pin); Escape or a right click during
  the drag cancels it. Dragging up past the horizon uses the last ground the drag crossed, like the right-drag.
- On a phone, a tap is still the order; a one-finger press-drag is the facing gesture.
- The squad's LINE lies across the arrow and its guns point along it (11-12 of 15 runs within 15 deg); after CP2 most
  hulls turn to it too, plain moves less so (the hull numbers are manoeuvre's).
- `make showmatch`: two computer players fight, filmed by the self-directing camera, with no HUD, the announcer and
  music on, and "WINNER: <FACTION>" at the end. Each run prints `DEMO_SEED N`; `make showmatch SEED=N` replays it.

**Commands (exactly):**
- `make skirmish` then select a squad (1-4 or a click), press E / R / B / A / M, and press-drag-release on the ground.
- `make showmatch` to watch; `make showmatch HUD=1` keeps the score bug; `make showmatch SEED=3666` replays a match;
  `FACTION=law ENEMY_FACTION=gangs ARENA=docks SIZE=3` pin the rest.
- `make showmatch MOVIE=build/showmatch.mp4` records it: 1080p, 30 fps, sound, an mp4 ready to share (via ffmpeg; without
  ffmpeg it keeps the .avi and says so). It renders slower than real time (builder0: an 88 s match took 344 s, about 4x;
  his laptop will be slower) but the file plays smoothly; it quits by itself 5 s after the end banner.
- Numbers and frames: `make remote LIGHT=1 T=facing-probe`, `make remote LIGHT=1 T=facing-shots`.

**Round 27 candidates:**
1. Attack with a direction: press on an enemy + drag = come at it from that side (an approach vector on brains' attack
   task). Decided not this round (he did not ask).
2. The cinematic camera's last shot can tilt so the bottom third is the purple floor under the arena (seen in the
   HUD=1 movie's end frame, seed 43496 docks): game/camera's framing, untouched here.
3. Ambush's guns sit at a flat 30 deg off the drawn facing in every run (brains).
4. Hulls at rest against the drawn facing, by hull class (manoeuvre, C26.9); the tail of 100-167 deg hulls on every task.
5. The laptop preset's army fold gives the CPU squads of 6-7, which elements refuse (C19.1), so they fight leaderless
   (perf has it; my guard keeps the controls safe either way).

**Known issues:** few probe runs are still for 3 s inside 75 s, so its numbers are 75 s readings; the contact arm is
reported, not judged; Movie Maker renders at about 4x real time on builder0.

**Merge notes (all merged in `aca71957`):** new `tools/facing_probe_table.py` (approved), `game/ui/clean_feed.gd`,
`tests/ai_scenarios/scenario_orders_facing.gd` (REQUIRED, `.uid` committed), `tests/test_control_showmatch.gd`,
`tests/test_control_oversize_squad.gd`; `game/control/orders.gd` `_same_order`; `game/ui/control_hints.gd` (two strings);
`game/modes/skirmish_mode.gd` (demo flags, the spectated end banner, the clean feed: granted); `project.godot` (two
`.movie` lines: granted); `tests/baselines/ai_scenarios_count.txt` 45 -> 46 (approved); perf's 845dc7af as e736248a.

### Checks (builder0, `make remote T=check`)

- `1805fdde` green 2401/0; `6e480393` (CP0 merged) green 2417/0, ALL JUDGED.
- `ba541b96` (main ec9b8672 merged) 2426/1: the stale-heading integration test (moved, see above).
- `1e58cc7c` 2425/1: `test_audio_script_duck::test_a_real_booth_line_is_seen` (audio's; nothing of mine near it).
- `5acc4c42` (main 2aadc60c, CP2, merged) 2431/5 + ai-scenarios count 45 -> 46: the five were main's latent
  RenderLevers leak (`test_hud_widgets` cycles LOOK to laptop, `test_native_army_cap` ran next in the same shard once my
  files moved the shard boundaries); perf's 845dc7af (cherry-picked `e736248a`) fixes it; the count is my required
  scenario (re-recorded `1226372a`, approved). Thirteen unmoved, determinism 762a0576f944f5b7 on every one.
- **Final: `ba3e3480` green: builder0 `make check exited 0`, 2449 passed / 0 failed, 24 targets ALL JUDGED, thirteen
  unmoved, determinism 762a0576f944f5b7.** It holds `_same_order` + the required scenario + the count (`1226372a`),
  perf's leak fix (`e736248a`), O5 (`bc117050`, `5a9b86a1`) and the null-element guard (`ba3e3480`). Merged as 28578083.
- `702269f7` green: 2449/0, ALL JUDGED, thirteen unmoved, determinism 762a0576f944f5b7 (the above-horizon ruling,
  `c967c055`). Merged as `aca71957`.

- **Null-element guard** (`ba3e3480`, perf's finding, builder0 a5ab7518): where `Elements.form` refuses (over five,
  C19.1) and returns null, `assign_task` / `_task_squad` send a unit verb straight to the crews and refuse a squad-only
  task with "that group is too big for one squad (N; a squad is at most 5): split it"; the formation re-form refuses the
  same way. A player's SELECTION never gets there (`SelectionSquads.split` deals a group of six into 3 + 3, pinned).
  Tests: `test_control_oversize_squad` (5).

**Decisions (reversible):** (1) the above-horizon release uses the last ground crossed, as the right-drag does (it
refused until the orchestrator's ruling above); (2) Escape mid-drag disarms
too (not only the drag), matching what Escape did with an order armed; (3) the radar's armed click
(`armed_world_order`) stays a click: a facing drawn on a 200 px map is not a gesture worth teaching yet.

**Touch (phone):** the RTS controls see one finger as the emulated left mouse (no `DEVICE_ID_EMULATION` branch in
`rts_controls.gd`; two-finger gestures are only handled by the `--touch-map` tactical map). So a TAP is today's order
(decided on the finger's lift instead of its landing, same spot), and a one-finger press-drag IS the facing gesture.

**Files touched in `game/ui/**`:** `game/ui/control_hints.gd` (two hint strings).

