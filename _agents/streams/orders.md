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

## How to verify

`make remote T=check`; your playtests headless on builder0 and windowed on the laptop for screenshots (C26.7: ask the
orchestrator). Look at every screenshot you produce.

## Don't touch

`game/tactics/**` (brains': how a task USES the facing), `game/ai/**`, `native/**`.

## Waiting on the lead

Nothing; he judges the gesture in play.

## Status

_Updated 2026-10-10 night (worker, `godot-orders`)._

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
  the horizon REFUSES ("released above the horizon: drag along the ground toward the way they should face") and stays
  armed. Follow and attack-move pressed on an enemy still fire on the press (their heading is their target's). The
  armed drag draws the right-drag's ring and arrow in the order's colour. Tests: `tests/test_control_armed_facing.gd`
  (23); the click tests pass on main's `rts_controls.gd` too (byte-identical command), the 12 drag tests fail there.
- **O3 legibility** (`6ce8a8ab`): the armed hint under the pointer, the command card tooltips (`TaskPalette`) and the
  first-time hints (`ControlHints`) say "drag to face". The order pin already draws a task's facing (task wins over the
  crews' orders, round 9) and a direct order's; tests assert it for a dragged screen and attack-move, and that a click's
  pin draws none. Found on the way: the HUD line for a task order said "3 units: ?" (`describe()` had no task verbs);
  it now says "3 units: screen facing E".

**Decisions (reversible):** (1) the above-horizon release refuses rather than using the last ground crossed (as the
right-drag does): an armed order is deliberate, so a guessed heading is worse than a retry; (2) Escape mid-drag disarms
too (not only the drag), matching what Escape did with an order armed; (3) the radar's armed click
(`armed_world_order`) stays a click: a facing drawn on a 200 px map is not a gesture worth teaching yet.

**Touch (phone):** the RTS controls see one finger as the emulated left mouse (no `DEVICE_ID_EMULATION` branch in
`rts_controls.gd`; two-finger gestures are only handled by the `--touch-map` tactical map). So a TAP is today's order
(decided on the finger's lift instead of its landing, same spot), and a one-finger press-drag IS the facing gesture.

**Files touched in `game/ui/**`:** `game/ui/control_hints.gd` (two hint strings).

