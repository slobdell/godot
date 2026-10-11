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

_Not started._
