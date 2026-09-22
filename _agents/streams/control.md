# Stream: control (the right-click that must always answer, and element orders for any selection)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*, *Controlling units*), [workstreams.md](../workstreams.md) (*Round 10: the eight streams*,
> contracts **R1**, **R2**, checkpoint **CP1**), and your round-9 brief in
> [archive/round9/control.md](archive/round9/control.md) — its Status is where you left off.
>
> **You own** `game/control/`, `game/ui/` (HUD, widgets, title, loading), `game/camera/`, `game/controllers/`,
> `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md`, and the control tests
> (`tests/test_control_*.gd`, `tests/test_rts_camera.gd`, `tests/test_camera_looks.gd`, `tests/test_command_camera.gd`).
> **Contracts:** R1 (narrowed to UX, yours alone) and R2 (you own the input half, squad the task half).

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> I'm also trying to move units, and they weren't responding (I can see improvement for sure in formation generation
> and stuff). But I had a selection and the yellow X's on the map were in the center, that's where they were driving
> to, and I was trying to right click to move them in a different direction and they didnt respond

> When I select a set of units that doesn't necessarily belong to a squad, the buttons to do support by fire or
> whatever the case is is disabled - any way we can make that usable for new, random selections?

> Reviewing an iteration of gaming, it's hard to give feedback because there are some general playability blockers.

The orchestrator's reading: **these two are the round's first two items in the whole project.** He cannot judge
anything about unit intelligence until a right-click is obeyed at once and any selection can carry an element order.
Everything else you did in round 9 (the chevron, the hull-shaped ring, the camera lift) is on the tree and he saw it
("improvement for sure in formation generation and stuff"). This round is not about drawing; it is about the order
reaching the crew.

## Where things stand

**The unanswered right-click.** What he described: a selection with a squad task in flight (the yellow pins at the
map centre are order pins from `order_marks()`, `rts_controls.gd:1335-1389`, one per squad task; `order_marks():1352-1353`
relabels a squad `move` with drills as `attack_move`, whose colour is `GameTheme.ui["commander"]` `#FFD500` and whose
glyph is the ringed crosshair, so "yellow X's" is a squad move task), then a right-click elsewhere that changed nothing.
Three places a fresh move can be swallowed, found by reading the code, in the order the orchestrator would suspect:

1. **`Orders._same_order()` (`game/control/orders.gd:342-362`)** drops an order whose destination is within
   `SAME_ORDER_M = ARRIVE_RADIUS = 3.0 m` of the one in flight, same verb, same target. It compares the **per-unit
   `goal`** (the formation slot from `_resolve_group`, `:276-336`), not the click, so a click metres from the last one
   on a moving squad can compare equal per unit. A drawn facing defeats it, but only when `source == "player"` (`:352`).
2. **The task path.** `order_selection` (`rts_controls.gd:772-796`) routes a whole-squad move to `assign_task` when
   `_is_task()` holds (`:513-515`). `Element.assign()` (`game/tactics/element.gd:145-163`, squad's) resets the leg,
   route and drill, but crews' orders are re-derived by the leader and `element.gd:562-583`'s re-issue suppression
   (`_same_place(..., REISSUE_M)`, the `"hold"` handling) can keep crews on the old geometry. That half is squad's
   under R2; you measure it and hand squad the numbers.
3. **`_right_button_down` (`rts_controls.gd:811-813`):** if any order is armed (`mode != ""`), the right press is spent
   cancelling it and **no move is issued**. If he had a command armed from the card, his right-click cancelled it and
   nothing said so.

You do not know which he hit. **Reproduce first, on the default path** (`make skirmish ARENA=terminus`, a squad given a
task to the centre, then right-clicks 20–60 m off its line every few seconds), with a per-tick log of what reached
each crew (`OrderController`'s current order per unit, the element's task, `Orders`' dedup decision). Lesson 183: a
readout that reports what was INTENDED contradicts the game exactly when it matters; log what was ISSUED.

**Element buttons for an ad-hoc selection.** One boolean: `SelectionPanel` builds the card at
`game/ui/selection_panel.gd:209-218` with `"enabled": commandable and (is_element or not ELEMENT_ONLY.has(command[0]))`,
`is_element := controls.can_task()`, `ELEMENT_ONLY := TaskPalette.element_only()` (`:39`) = every `kind: "task"` row in
`game/control/task_palette.gd:21-73` (screen, support_by_fire, ambush, and the unearned attack_by_fire/guard/cover/
fix/block). `RtsControls.can_task()` (`rts_controls.gd:491-492`) is `selected_element() != null or selected_group() > 0`;
`selected_element()` (`:495-507`) demands exactly one element and ALL its members. The same refusal is on the keyboard
and radar paths (`press_command` `:357-360`; `armed_world_order` `:889-891` → `_refuse("select a whole element to give
it a task")`), and the tooltip says "Select a whole squad (1-5) first." `assign_task` (`:519-528`) forms an element from
a NUMBERED group but not from an unnumbered selection. **R1 gives you the call that forms one from any list.**

**Your round-9 leftovers, still yours:** item 6 (the `ungrouped=N` readout and the refused-order banner on the default
path); the two questions you asked him (does a dragged facing orient the formation across the heading; does the camera
keep lifting over roofs) are DECIDED below so you are not waiting.

## Backlog (in order)

1. **Reproduce the unanswered right-click on the default path and name the mechanism.** A scripted skirmish on
   Terminus: select a squad, give it a move to the plaza, wait 3 s, right-click 40 m off the line, repeat with a task
   (support_by_fire) in flight, with a card command armed, with a drag-facing. Log per tick per crew: the order id,
   verb, goal, source; `Orders._same_order`'s verdict; the element's task. **The test that fails first:** every crew's
   order changes within 2 ticks of the click (R2). Write it against the mechanism you find; if the mechanism is
   squad's (the element re-issue suppression), send squad the log and the failing test, stub the fix on your side
   only if it is one line in your file, and keep going.
2. **R2 on your side.** `_same_order` never drops a `player` order (compare the CLICK, and even then only an exact
   repeat within 1 m and the same facing); an armed mode cancelled by a right press is announced by the banner and the
   NEXT press issues; `order_selection` on a selection with a task in flight replaces the task (via `Element.assign`
   or by dissolving the element, whichever squad's R1 says) rather than being deduplicated against it. The
   regression test from item 1 goes green here. Mutation-check it (it must fail with the old `_same_order`).
3. **Squad orders for a mixed selection (R1, narrowed by the lead on 2026-09-20 night; his words in
   `game_design.md` *Squad orders for a mixed selection*).** He found that regrouping (Ctrl+1–5) already turns a
   mixed selection into a squad that carries formation and element orders, calls it good behaviour, and asks only
   that the UX say so. So: no transient element, no squad API. The greyed task buttons carry a one-line reason he
   reads without a tooltip ("these units are in different squads: press Form squad or Ctrl+1–5"); the card gains a
   one-click **Form squad** action that assigns the next free group number to the selection and enables the buttons
   in the same frame (the existing `assign_task` path from a numbered group); the keyboard/radar refusal says the
   same words. Test: a box-drag across two squads, Form squad, support_by_fire enabled and issued within one frame.
4. **The banner and the `ungrouped=N` readout on the default path** (your round-9 item 6): every refused or
   deduplicated order shows why in the banner for 2 s ("cancelled the armed order; click again to move"), and the HUD
   shows how many selected units are in no squad. A player who is not told why nothing happened concludes the game is
   broken, which is what he concluded.
5. **Decisions on your two round-9 questions, recorded (orchestrator, 2026-09-20):** (a) a dragged facing orients the
   FORMATION across the drawn heading (an emplacement faces its threat; the travel-direction layout is what the
   formation does while moving, and it dresses to the heading on arrival). Land it with a frame pair at his pose.
   (b) The camera keeps LIFTING over roofs (pulling in collapses his boom to 11 m); the lift readout stays.
6. **Stretch:** the pin-head crowding (lean the head away from the chevron); the 8° column-off-screen limit gets a
   "column too long for this tilt" note in the readout rather than a fix.

## How to verify

- `make check` green on your last commit (`make remote T=check`; read the wrapper's own line and the runner's line).
- `make skirmish ARENA=terminus`: the round's acceptance is his hands on the mouse. Your scripted stand-in is item 1's
  test plus `make control-playtest-shots` (frames at 1920×1080 and phone aspect) and `make shell-playtest`.
- Every frame you send him: his pose (21°, FOV 35, 49 m), before/after, one variable moved, the dial named.
- Every number: commit, machine, sample size.

## Don't touch

`game/tactics/**`, `game/ai/**` (squad's and nav's: send them logs and failing tests, not edits), `game/tank/**`,
`game/units/**`, `game/match/**` (combat's), `arenas/`, `game/arena/` (arena's), `game/theme/**` (feel's and show's),
`game/announcer/**` (announcer's). `mk/core.mk` and `Makefile`: additive only, listed in merge notes.

## Waiting on the lead

Nothing blocks. His verdict on the round is the playtest.

## Research addendum (brief 2, 2026-09-20 evening; rows B7, B4)

**Acknowledgement is its own requirement (B7):** within one tick of any order the pin is drawn and the banner (if
the order was refused, deduplicated or spent on a cancel) says so; within one second a crew shows visible intent
(squad's half: the turret slews toward the destination, the nose begins to turn). Item 4's banner and item 1's
regression test both assert the acknowledgement tick. The player tolerates slow execution he can see acknowledged;
he cannot tolerate silence.

**The order COMPLETES at operational arrival (B7):** squad now reports a move complete when the formation's centroid
is in the zone and every hull is braking, before dressing. The pin's state and the "MOVE · 0/3 there" plate read that
phase, and a "dressing" state follows it so the player sees why hulls are still nudging.

**Later (B4):** an affordance overlay of certified lanes for the selected vehicle class (arena's corner certification
is the data). Not this round unless cheap.

## Research addendum 2 (brief 3, 2026-09-20 late; row C11)

**arena's lane-readability render test uses your camera tooling** (`terminus-alleys`, `camera-looks`, his pose): it
projects a lane's narrowest throat to screen and reads the Z-buffer for the occluded fraction of its ground-contact
line. Expose what it needs (a headless frame at his pose with the G-buffer's depth and a world-to-screen for a
segment) as a small API or make target; nothing else changes on your side. The three numbers behind his "is it
blocked?" read (cross-screen foreshortening at sin 21°, foreground occlusion of 2.6× an object's height, the
telephoto's missing scale cues) are also why the camera's default heading matters: a street read along the depth
axis is 2.8× more legible than one read across.

## Status

_Updated 2026-09-22 ~13:30, worker session 1._

> **THIS COMMIT IS GREEN, MERGE HERE: `f8e8c592`.** `make remote T=check`, builder0, from the wrapper: `>> remote: make
> check exited 0`; runner `1575 passed, 0 failed`; ai-scenarios 41,3 unchanged; sim-baseline `1ea332e7bc268d2a`
> (unmoved); determinism `559a415887806e43`. The orchestrator has the hash (SendMessage). Later commits on the branch are
> harness, frames and docs only, and each names its own check below.

### Plan (in order) and where each stands
1. ✅ Reproduce on the default path: `make repath-test` (new).
2. ✅ R2, control's half: player orders compare the CLICK; K1 `task` key (squad's ask).
3. ✅ R1: reasons on the greyed buttons, FORM SQUAD on the card, task keys refused at the key in the same words.
4. ✅ Banner notices + `N UNITS (K IN NO SQUAD)`.
5. ✅ 5a: a drawn facing lays the formation in the facing's frame (direct orders; the task path is squad's to honour).
   5b needs no code: the camera keeps lifting and the readout stays.
6. ✅ Stretch: the pin head leans away from an up-screen heading; the camera readout says COLUMN TOO LONG FOR THIS TILT.
7. ✅ Extra (terrain's report, relayed): the radar and tactical map draw the objectives the match scores, not the centre.

### Item 1: what swallowed the click (measured, `make repath-test`: Terminus, condemned v law, seed 3, squad 1 = 8 Guns)
Seven in-flight states through real input: a move, an attack-move (the yellow pin), support by fire, an armed card
command, a right-drag facing, a click 5 m from the destination, and an arrived squad. Then a right-click 40 m off the
line. For each crew, per tick, it logs what Orders says the crew CARRIES OUT (lesson 183), plus whether the crew visibly
moved or turned within 1 s. **Three mechanisms, two owners:**
- **Control, the armed press** (mechanism 3 in the brief). A right press with a card command armed is spent cancelling
  it and issues nothing, silently. Now: "Cancelled Attack-move: right-click again to move" in the warning banner, and
  the next press moves. Tested.
- **Control, the 3 m player dedup** (mechanism 1). A hand-picked (non-squad) group given a second click a couple of
  metres off had it dropped: slots within 3 m compared equal. Now only the same click again (≤1 m, same facing, same
  units) is a repeat. Mutation-checked: with the old rule, 2 of `test_control_repath`'s tests fail.
- **Squad, the element's re-issue** (mechanism 2). "arrived": crews that had finished their element move and gone idle
  got NO order from a new task (4 of 8 on builder0 at `54fa6ff6`; 4 of 7 living on the laptop at `649d7e44`).
  "near": a whole-squad click 5 m from the current task changed NO crew's order (the leader's desired goal moved
  < REISSUE_M = 8 m). Both were sent to squad with the logs. Squad fixed both on stream/squad (`35f7b459` for arrived,
  `2d5945ac` for near, each with its own mutation-checked test).
- **What already worked on the old code:** en-route whole-squad move, attack-move and support-by-fire tasks. Every crew
  was re-ordered within 2-3 ticks, or followed a leader that was (the laptop run on the `2ee65f94` controls, read again
  with the corrected verdict). Visible intent at 1 s: 8/8 in those states (laptop, `649d7e44`).
- A/B on builder0 against the pre-R2 controls: started, then stopped to free builder0 for the merge check. The laptop
  A/B above stands in for it.

### Done (all in `f8e8c592`)
- `Orders._same_order` (R2): a player order is a repeat only for the same click and never when it takes a unit off an
  element's order; an order under a new `task` is never a repeat, whatever its source. `Orders.last_dropped` and the
  `deduplicated` signal are the instrument.
- K1 contract: `UnitCommand.KEYS` gains optional `"task": int` (the element's task sequence; squad's adapter sends it).
- R1: `RtsControls.task_refusal()` (e.g. "these units are in different squads: press Form squad or Ctrl+1-9", "part
  of Alpha: press 1 for all of it, or Form squad", "these units are in no squad: …"), shown in the card's footer
  beside FORM SQUAD. `form_squad()` takes the lowest EMPTY group, the same rule as Ctrl+N. E/R/B refuse at the key; the
  greyed buttons and the radar refuse in the same words; the tooltip says "Greyed out: …".
- `RtsControls.notice(text, warning)` → the HUD banner (skirmish_mode). Messages: "Cancelled …", "Already doing that",
  "Squad 6 formed: press 6 to select it".
- 5a: `_resolve_group` lays slots in the drawn facing's frame (mutation-checked).
- `Radar.objective_rings(match)` = `Match.objectives`, drawn by the radar and the tactical map; the score warning says
  "the objectives" on pair layouts. Test on every `arenas/*.json`.
- `RtsCamera.cuts_off` + `frame_short` → CameraReadout's COLUMN TOO LONG line; `RtsControls.pin_head` leans the pin.
- New/extended tests: `test_control_repath` (7), `test_control_form_squad` (5), `test_control_objective_rings` (2),
  `test_control_facing_drag` (+1), `test_control_order_marks` (+1), `test_rts_camera` (+1).

### After `f8e8c592` (merged at `52254fd2`): on the branch, check on `363c2952` queued
- `repath-test`: element membership and the selection in the log; a destroyed crew is "dead", not STALE (squad's
  run on main with both branches: 6/7 living-crew passes, and "arrived" failed only on two destroyed crews).
  Visible intent at 1 s is reported (8/8 in the en-route states).
- **The Form-squad reason was cut off at 1920×1080** ("These units are in different squads: press", from the first
  frame, `build/control-playtest/1920x1080/7a_mixed_selection.png` at `f874047e`). The card now uses a short form that
  reads into the button ("In different squads: Ctrl+1-9 or [FORM SQUAD]"); a test asserts every variant fits at 720p.
- **COLUMN TOO LONG showed with all three units in view** (the first frame, `9_facing_drag_ordered.png`): the vision
  frame also carries contacts and their mirrors. It now judges only our own vehicles (`vision_state()["own"]`) and
  clears whenever the vision frame is not driving the camera.
- B7: a squad task's pin reads `MOVE · ARRIVED · dressing n/m` after squad's operational arrival (`Element.arrived`)
  and drops its lead line.
- The control playtest gained three checked steps with frames: `7a/7b` (the mixed selection, then Form squad), `7c`
  (the armed-cancel banner), and `10a/10b` (plain click vs right-drag east, same three hand-picked units, same spot: the
  5a pair).

### Decisions
- Form squad = lowest empty group 1-9 (6 on the default path). Units stay in their old groups too, exactly as Ctrl+N
  leaves them, because the lead called regrouping good behaviour.
- The reason says Ctrl+1-9, not 1-5: 1-5 hold the doctrine squads and Ctrl+1-5 would overwrite one.
- FORM SQUAD lives in the card's footer (the doctrine line's strip, which is free when there is no element) so the
  button grid does not move.
- `repath-test` is not in `make check`: until squad's branch is on main, "near" and "arrived" fail by design (squad's
  acceptance).
- ai-scenarios `scenario_perf` is a CPU-time budget. It read 25525 usec/tick on a loaded builder0 at `6c6b9a7c` (40,4),
  and 41,3 again on the next run. Not re-recorded; reported.

### Requests to other streams
- squad: "arrived" and "near" (above). Answered: fixed on stream/squad; squad runs `make repath-test ONLY=near` and
  `ONLY=arrived` after both branches are on main.
- orchestrator: record the K1 `task` key in workstreams.md (squad said it would).

### Questions for the lead
- None blocking.

### What to playtest
`make skirmish ARENA=terminus`. Press 1, right-click the plaza, and 3 s later right-click 40 m to the side (the whole
squad turns only once squad's branch is merged too). Press A then right-click: the banner says the press was spent
cancelling. Box-drag across two squads: the card says why the task buttons are grey; click FORM SQUAD, then R.
Right-drag a hand-picked group: its front faces the way you drew.

### Merge notes
- Shared files touched: none outside control's paths. `game/modes/skirmish_mode.gd` (control's): the `notice` hookup
  and `--repath-test`. `mk/command.mk`: `repath-test`.
- K1 contract change: `UnitCommand.KEYS` gains `task`.
