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

_Updated 2026-09-22 11:20, worker session 1. Branch tip `10da860e` (laptop filtered runs only; full check pending)._

### Plan (in order, smallest foundation first)
1. ✅ Reproduce on the default path: `make repath-test` (new; headless, Terminus, condemned v law, seed 3, squad 1 = 8 Guns).
2. ✅ R2 on control's side: `_same_order` compares the CLICK for player orders; K1 `task` key (squad's ask).
3. ✅ R1: reasons on the greyed buttons, Form squad on the card, task keys refused at the key in the same words.
4. ✅ (code) banner notices + `N IN NO SQUAD` header. Frames still to take.
5. ✅ (code) 5a: a drawn facing lays the formation in the facing's frame (direct orders; the task path is squad's). 5b needs no change (camera keeps lifting; readout stays).
6. Stretch: the pin-head lean; the "column too long for this tilt" note.

### Item 1: what swallowed the click (measured)
`make repath-test` runs seven in-flight states through real input: a move, an attack-move (the yellow pin), support by fire,
an armed card command, a right-drag facing, a click 5 m from the last, and a squad that has arrived. After each it logs
per tick and per crew the order Orders says the crew is CARRYING OUT (lesson 183).
- **With this branch's R2 (`54fa6ff6`, builder0):** 6/7 pass. Every crew's order is new within 2 ticks of the issuing input
  frame, or it follows a leader whose order is new. **"arrived" fails:** crews that had finished their element move and
  gone idle got NO order after a new task (4 of 8 crews, still idle through tick +8). Mechanism: `element.gd:_should_issue`'s
  idle branch (a finished `move` in `_issued`, a desired `follow` with no `to`). That is squad's; it's fixed on stream/squad at `35f7b459`.
- Old-code A/B (pre-R2 Orders and controls, same harness): _running on builder0; the result goes here._
- Mechanism 3 (the armed press) is real by construction: the press cancels the armed order and issues nothing. It now
  says "Cancelled Attack-move: right-click again to move" in the warning banner, and the next press moves (tested).

### Done
- `Orders._same_order` (R2): a player order is a repeat only for the same click (≤ `PLAYER_REPEAT_M` 1 m, same facing,
  same units), never when it takes a unit off an element's order; an order under a new `task` is never a repeat.
  Mutation-checked: with the player rule disabled, 2 of the new tests fail.
- K1 gains optional `"task": int` (squad's ask; contract change for workstreams.md: K1 row).
- R1: `RtsControls.task_refusal()` ("these units are in different squads: press Form squad or Ctrl+1-9", "part of Alpha:
  press 1 for all of it, or Form squad", "these units are in no squad: …"), shown on the card's footer beside a FORM SQUAD
  button. It forms the lowest EMPTY group, the same rule as Ctrl+N; units stay in their old groups too. Task keys (E/R/B), the
  card's greyed buttons and the radar all refuse with those words. The tooltip says "Greyed out: …".
- Item 4: a `notice(text, warning)` signal on RtsControls, posted to the HUD banner by skirmish_mode ("Cancelled …",
  "Already doing that", "Squad 6 formed: press 6 to select it"); the group header reads "N UNITS (K IN NO SQUAD)".
- 5a: `_resolve_group` lays slots in the drawn facing's frame (the front rank leads toward the drawn heading); `heading` stays
  the travel. Mutation-checked.
- Tests: `test_control_repath` (7), `test_control_form_squad` (5), `test_control_facing_drag` (+1). Laptop, filtered:
  all pass.

### Decisions
- Form squad uses the lowest empty group 1-9 (squads hold 1-5, so it's 6 on the default path) and does not remove units
  from their old groups, because that is exactly what Ctrl+N does and the lead called regrouping good behaviour.
- Reason text says Ctrl+1-9 (not 1-5): 1-5 are the doctrine squads, and Ctrl+1-5 would overwrite one.
- Form squad lives in the card's footer strip (where an element's doctrine line goes; a selection that cannot take a
  task has no element, so the strip is free), not as an eighth card button, so the card's layout does not move.

### Requests to other streams
- squad: the "arrived" idle-crew case above (sent via the orchestrator; squad replied that it's fixed at `35f7b459`).

### Questions for the lead
- None blocking.

### What to playtest
`make skirmish ARENA=terminus`: press 1, right-click the plaza, and 3 s later right-click 40 m to the side. Box-drag
across two squads: the card says why the task buttons are grey; click FORM SQUAD and press R.

### Merge notes
- Shared file touched: `game/modes/skirmish_mode.gd` (mine) only. `mk/command.mk`: new `repath-test` target.
- K1 contract change: `UnitCommand.KEYS` gains `task`.
