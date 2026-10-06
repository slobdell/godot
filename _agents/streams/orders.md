# Stream: orders (a formation belongs to the squad he gave it to; two squads ordered together stay two squads and arrive side by side)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 19 direction* (items 1 and 2),
> `_agents/tactical_map.md`, `_agents/legibility.md`, `_agents/workstreams.md` *Round 19*. You own `game/control/**`,
> `game/ui/formation_picker.gd`, `game/ui/selection_panel.gd`, `game/ui/command_icons.gd`, `game/ui/tactical_map.gd`,
> `game/ui/radar.gd`, `game/ui/task_preview.gd`, `game/ui/control_hints.gd`, `game/theme/fx/order_feedback.gd` (the
> order markers), `tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_tactical_map.gd`,
> `tests/test_element_preview.gd`, `tests/test_touch.gd`, `mk/command.mk`. **Lent by brains (C19.1):** the member
> cap in `Elements.form` (`game/tactics/elements.gd:80`), one guard line, nothing else in `game/tactics/**`.

## The lead's direction (2026-10-05, in chat, after two games on the twelve-map rotation; verbatim)

> *"1. It seems that I can't assign different formations to different squads. It looks like if I apply a formation to
> one squad, when I select another squad, that same formation was applied. 2. I just tried a simple movement where I
> selected 2 squads and right clicked a point on the map - the resultant indicator dots for all the units was all over
> the map, and a bunch of vehicles just basically ran off to the middle of the map.."*

**Read plainly:** a formation is a property of the squad he gave it to, not of the mouse. Two squads ordered together
stay two squads, each in its own formation, both arriving at the point he clicked, side by side; the dots show where
each vehicle will stand; nothing drives through the middle of the map on the way.

## Where things stand (read at `93ec68b4` by the orchestrator; not played, not reproduced)

**Item 1 is one variable.** The chosen formation is `RtsControls.formation` (`game/control/rts_controls.gd:128`),
one field for the whole controller: G writes it (`cycle_formation`, `:955`), the picker writes it (`set_formation`,
`:960`; `game/ui/formation_picker.gd:144-148` calls only that, then closes). Nothing is sent to any squad on a pick:
the NEXT order carries it, to whichever squad gets that order (`:652-653` task path, `:950-951` direct path), and
keeps carrying it to every squad until he picks again. A selection change never touches it. The Formation button and
the picker's marked card show the variable (`selection_panel.gd:293` → `CommandIcons.formation_readout`,
`command_icons.gd:411-418`): only under AUTO does the readout look at the selected element's real shape (`:419-420`).
The squads already hold their own: `Element.formation` (`game/tactics/element.gd:45`, set from the plan at `:699`)
and the task's `formation` key (`:477`; `Element.assign` replaces the whole task, `:195-200`). The tactical map's
older path does it per squad: `apply_formation` issues `{"squad": selected_squad, "formation": …}` at once
(`game/ui/tactical_map.gd:262-268`) and shows `squad.formation` per squad (`:216`). Tests that pin today's
behaviour and must follow the change: `tests/test_control_formation_picker.gd:103,344`,
`tests/test_control_group_moves.gd:210-217`, `tests/test_control_tasks.gd:145-152`,
`tests/test_control_panel.gd:101-103`, `tests/test_control_screen_task.gd:75-139`; `picker_playtest.gd`'s
`one_click_picks_line` (67) and `mid_fight_pick_reaches_the_order` (97) read only `controls.formation`.

**Item 2 has two paths, and which he hit depends on how he selected** (`rts_controls.gd:620`, `_is_task` is true
when `selected_element() != null or selected_group() > 0`; control groups are dealt one per squad,
`control_groups.gd:94-103`):
- *Two squads selected together* (1 then shift+2, or a box): the DIRECT path, `:936-952`: every unit is removed from
  its element, both squads are disbanded, and one `UnitCommand` covers all ~10 units: `Orders.issue` →
  `_resolve_group` (`game/control/orders.gd:298`): anchor at the click, `TacticsFormation.auto` = "rows" above five
  (`tactics_formation.gd:620`), rows of five at a pitch floored by the largest hull's diagonal, seated by toughness
  tier before distance (`seat`, `:685`; `TIER_COST` 1e5), then `SlotGround.for_unit` and `apart` (bounded: 2 and 3
  rings). Goals stay within about 60 m of the click; crews cross the whole group to reach their seats; and both
  squads and their formations are thrown away to do it.
- *One control group that holds exactly both squads* (Ctrl+N over both, or an earlier task that formed them into
  one): the TASK path, `assign_task` (`:626`) → `Elements.form(selection.units, …)` (`:634`) → ONE element of ~10
  vehicles (`game/tactics/elements.gd:80` has no size cap; `Formations.MAX_MEMBERS = 5` is not enforced there).
  `ElementPlan.build` (`element_plan.gd:69`) keeps the chosen shape and never passes `auto`, so a 10-vehicle wedge
  stays a wedge at the 14 m "open" spacing (`doctrine_table.gd:86`): about 126 m across and 70 m deep around the
  click, on an arena 240 m wide. The transit starts from the CENTROID of all members (`Element._advance_transit`,
  `element.gd:434`, for moves of 25 m or more; stations laid around it, `element_plan.gd:291`), so two squads on
  opposite flanks first drive to the middle of the map. **This matches both of his symptoms.**
- The dots: `RtsControls.waypoints()` (`:1277`, drawn at `:1873`) puts one marker at each unit's `order["goal"]`;
  the radar one per distinct goal (`radar.gd:155-161`); `OrderFeedback` one per command at `to`
  (`order_feedback.gd:145`). "All over the map" means the per-unit goals really were.
- Also: `ElementPlan.clamp_to_arena` (`element_plan.gd:1298`) is the old square ±116 clamp, not the arena-shape
  clamp `Orders.clamp_to_arena` uses; `Element.remove` (`element.gd:580`) does not emit `element_changed`, so a
  brain can hold a stale station for one poll. Both are brains' (report what you see; do not fix them).
- Nothing tests two whole squads ordered together: `test_control_group_moves.gd` uses 8 bare units;
  `tests/tactics/partial_probe.gd --case=mixed` is two partial squads; `control-playtest` box-selects group 1 only.

## Decided by the orchestrator (broad strokes are ours; record a reason if you overturn one)

- **A formation is stored on the squad** (the element's task / `Element.formation` is the truth; AUTO is a value
  too). The controller keeps no formation of its own. A pick applies to the selected squad AT ONCE (as the tactical
  map does), re-forming it where it stands if it is idle, or re-planning its current task if it has one (the
  round-18 rule "the same click in a new formation is a new order" stands, `orders.gd:439`).
- **Selecting a squad shows that squad's formation** on the button, in the picker's marked card and in the preview.
  G cycles the selected squad's. A mixed selection of several squads shows "—" (or the common value if they agree)
  and a pick applies to each of them.
- **Several squads ordered together stay several squads.** Both selection shapes (two groups together; one group
  holding two squads) issue one order per squad: the same destination, each squad in its own formation, laid side by
  side across the line of approach (the squads' order left-to-right kept, so they do not cross), each squad's
  transit from ITS OWN position, never from the joint centroid. No element is ever formed with more members than
  `Formations.MAX_MEMBERS` (the lent guard line in `Elements.form` refuses it loudly: a test). Units with no
  squad in the selection keep today's direct-path behaviour among themselves.
- **The dots tell the truth before the vehicles move:** one marker per vehicle at its real goal, and a marker per
  squad at the squad's anchor, so he can see "squad 1 here, squad 2 beside it" at the click.
- **Touch and the tactical map** follow the same rule (one list of formations, one meaning of a pick).

## Backlog (in order)

- **O1. Reproduce both of his cases headless, with numbers.** A scripted skirmish (`control_playtest.gd` style, or a
  new `tests/test_control_two_squads.gd`): task squads 1 and 2 separately on opposite flanks of a base, select both
  (shift), right-click a point 60 m away; then the same with Ctrl+3 over both. For every unit, dump
  `orders.current(u)["goal"]` and its distance to the click, and the first 5 s of each vehicle's path (does it head
  for the centroid?). Record the two tables in Status with the commit and machine. These become the tests that fail
  first.
- **O2. The formation lives on the squad.** Remove `RtsControls.formation` as a controller state; a pick (picker, G,
  tactical map) becomes a per-squad order applied at once; orders fill their `formation` from the squad being
  ordered; the readout, the picker's marked card and the preview read the selected squad. Tests first: pick Line
  for squad 1, select squad 2 → the button says squad 2's formation and squad 2's next order carries IT; pick for
  squad 2 → squad 1 keeps Line on its next order; G on squad 2 does not touch squad 1; AUTO is per squad too. Update
  the tests listed above and `picker_playtest.gd` (assert through `orders.current(...)` and the element's state,
  never through a controller field).
- **O3. Several squads, one click, side by side.** Per-squad orders from both selection shapes; squads laid beside
  each other across the approach without crossing; each transits from its own position; the lent guard in
  `Elements.form`. Tests: every goal within one squad-width of the click; no vehicle's first 5 s heads away from
  the click by more than its spacing; both squads still exist afterwards with their formations; `partial_probe.gd
  --case=mixed` still passes (partial squads are a different case: keep it).
- **O4. The dots.** One marker per vehicle at its goal and one per squad at its anchor, on the ground and on the
  radar; `OrderFeedback` shows the squads' anchors, not one dot. Look at it (frames at desktop and phone aspect,
  `make control-playtest-shots` on builder0).
- **O5. Play it like him.** `make skirmish ARENA=parade`: two squads, Line for one, Wedge for the other, select
  both, right-click the far bay; then the same on the Sumps in a street. Frames and a short paragraph of what you
  saw, in Status. Then a mixed selection that includes a squadless unit.
- **O6. The cost on his path.** `make hud-digest` / `hud_cost_probe.gd` before and after: the HUD's per-frame work
  unchanged with the picker closed (state commit, machine, load, N). Nothing new per frame while idle.
- **Stretch.** (a) A selection of several squads shows each squad's formation card in the picker (one row per
  squad) so he can set two at once. (b) Direct keys per formation if free (`control_hints.gd`). (c) The two brains
  items you found (the square clamp; `Element.remove` without a signal) written up as requests with your numbers.

## How to verify

`make remote T=check` green on every commit you report (read the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe; lessons 255 and 257). **The thirteen baseline lines and determinism are
UNMOVED** (your paths run only under a player; a move is a finding: stop and message the orchestrator). `make
control-playtest`, `make picker-playtest`, `make skirmish` and use it; frames at desktop and phone aspect, looked at.
His eye is the check for the feel (C18.3); your tables are the check for the geometry.

## Don't touch

`game/ai/**`, `game/tactics/**` except the one lent guard line (brains; read `TacticsFormation`, `Element`,
`ElementPlan` freely) · `game/garage/**`, `game/progression/**`, `game/units/**`, `game/ui/widgets/cyber_*.gd`
(garage) · `game/match/**`, `game/ui/hud.gd`, `hud.tscn`, `game/ui/widgets/hud_skin.gd`, `game/ui/hud_messages.gd`,
`game/announcer/**`, `game/theme/arena_kit/**` (board) · `arenas/**`, `game/arena/**` (nobody this round; a layout
defect is a request) · `mk/core.mk`, `tests/baselines/**` (nobody).

## Waiting on the lead

- Nothing. He plays it when it merges.

## Status

_Worker, 2026-10-05 late evening. Started from `567e1997` (the launch commit; baseline `make remote T=check` queued
behind the other three streams' checks on builder0)._

**Plan (smallest foundation first; O1's probe is committed alone so its "before" numbers are the unchanged code's):**
1. O1 probe: `TwoSquadsPlaytest` (`--two-squads`, `make two-squads-playtest` / `two-squads-shots`, `TWO_ARENA=`): squads
   1 and 2 to opposite flanks, then both ordered 60 m ahead, (a) selected together, (b) as one group (Ctrl+N, N); per
   vehicle: goal, end slot, first 5 s (`away_5s`: farther from the click; `to_middle_5s`: run toward the middle past
   its own line), end. Run on the base code first → the "before" tables.
2. `SelectionSquads` (new, `game/control/selection_squads.gd`): a selection → its squads (an element wholly selected;
   else the SMALLEST control group wholly selected, so groups 1 and 2 come back out of a Ctrl+3 over both; a whole
   group over five is dealt into squads of ≤ 5 west to east) + loose units; `row()` lays blocks abreast.
3. O2: `RtsControls.formation` is a read-only view of the selected squads (`selected_formation()`; assigning it =
   `set_formation`); a pick applies at once per squad (`_give_formation`); `ControlGroups` remembers each group's
   pick between elements; MIXED reads "—".
4. O3: `_order_squads`: one task per squad, anchors from `row()`; queued routes per squad on the direct path;
   loose units direct beside them; the lent guard in `Elements.form`.
5. O4: `arrival_slot()` / `shown_route()` (dots at the real end slot during a formation transit), the radar's
   destinations from it, `OrderFeedback` marks each squad task's anchor (`command["task"]`).
6. O5 play, O6 cost, stretch.

**Finding before any code (read at `567e1997`):** Shift+N does not select a second squad: it ADDS the selection to
group N (`rts_controls.gd` `_unhandled_key_input`, StarCraft's meaning). So "1, then Shift+2" quietly makes group 2
hold BOTH squads, and the next press of 2 selects ten vehicles as one group → the task path → one element of ten:
the scatter and the run to the middle. The group bar's chips only recall. Kept as is (StarCraft players expect it);
O3 makes that group order as two squads anyway.

**O1 DONE: both of his cases reproduced headless, with numbers** (`make two-squads-playtest`, the unchanged code:
`31154440` + the probe's own fixes `c5bf5481`, `9f507e0e`; builder0; seed 3, foundry; squads 1 and 2 = tank, tank, IFV,
IFV, scout each (`tests/support/two_squads_army.json`) against one scout, no centre ring; squads on flanks ±55 m,
the click 60 m ahead and 35 m toward squad 2, at (35, 34.7); one run per case).

| case | elements after | farthest end slot from the click | worst run toward the middle past its own line, first 5 s | worst off its straight line, first 5 s |
|---|---|---|---|---|
| **selected together** (box / shift-clicks; direct path) | **0** (both squads dissolved; rows of five) | 22.2 m | 6.6 m | 9.9 m |
| **one group over both** (Ctrl+3, 3; task path) | **1 element of 10** (wedge) | **52.3 m** | **37.6 m** (Alpha_1) | 14.1 m |

Per vehicle, one group over both (start → end slot, distance from click; Alpha are squad 1 on the west flank):
Alpha_1 (-32.7, 91.2) → (37.8, 12.6) 22.2 m, ran 37.6 m to the middle · Alpha_2 (-67.7, 75.8) → (11.4, 27.3) 24.8 m ·
Alpha_3 (-63.5, 90.2) → (-17.2, 37.4) 52.3 m, 13.8 m off line · Alpha_4 (-45.9, 98.0) → (23.7, 21.7) 17.2 m ·
Alpha_5 (-59.6, 105.2) → (-2.9, 32.3) 38.0 m · Bravo_1 (33.7, 85.8) → (56.4, 27.1) 22.7 m, 23.4 m to the middle ·
Bravo_2 (64.8, 92.7) → (58.6, 42.1) · Bravo_3 (72.9, 79.3) → (54.2, 12.1) · Bravo_4 (46.3, 95.5) → (62.6, 59.7), 20.7 m
to the middle · Bravo_5 (56.8, 106.0) → (63.1, 72.1) 46.8 m. The two squads' crews interleave across one 10-wide
wedge (squad 1's lead crew ends 38 m EAST, beyond squad 2's), its back rank 47 m behind the click, and the transit
starts at the joint centroid: that is "dots all over the map" and "ran off to the middle". Selected together the
goals stay within 22 m but both squads and their formations are thrown away. (First run of the probe used skirmish's
3 + 2 army in a fight and a click that never landed: both fixed, and the probe now checks the order moved them.)

**O2 + O3 DONE; CP2 READY: this commit is green, merge here: `38d99b44`** (builder0, `>> remote: make check exited 0`,
23 targets ALL JUDGED, 2074 passed 0 failed; all thirteen sim-baseline lines unmoved; determinism `762a0576f944f5b7`).
- O2: `RtsControls.formation` is a read-only view of the selected squads (`selected_formation()`; assigning it =
  `set_formation`). A pick (panel, G, `formation =`) applies AT ONCE to each selected squad (`_give_formation`): a
  tasked squad re-plans its task in the new shape; an idle one re-forms where it stands facing its way (a move task
  to its own centre); a squad still driving a hand-drawn route keeps it and its group remembers the shape.
  `ControlGroups.formation(n)` remembers each group's pick between elements (forgotten when the group is saved over
  different units). Several squads in different formations read MIXED ("—" over a ring with a dash). Part of a squad
  (or units in none) cannot take a formation: the refusal says how to select the squad. Tests:
  `tests/test_control_squad_formation.gd` (7). Updated: picker/panel/group-moves tests save their squad on a number
  key (a formation is a squad's); `picker_playtest` asserts through the element's task and checks squad 1 keeps its
  own (`squad_1_keeps_its_own`).
- O3: `SelectionSquads.split` (groups ≤ 5 smallest first, then elements, then oversized groups dealt west to east;
  the rest loose) and `row()` (abreast across the approach or the drawn heading, left-to-right order kept, AUTO squads
  reserve a line's frontage + 14 m gap). `RtsControls._order_squads`: one task per squad (queued routes: one direct
  order per squad, each in its own formation), loose units a direct group order in their own place in the row; enemy
  right-click with several squads = one attack task per squad; several whole squads can take Screen etc. (`can_task`).
  The lent guard: `Elements.form` refuses > MAX_MEMBERS with push_error and returns null, before anyone leaves an
  element. Tests: `tests/test_control_two_squads.gd` (10 + O4's 1).
- **After (the probe on `38d99b44`, builder0, same setup as O1):** both cases → **2 elements of 5**, each squad in its
  own wedge; farthest end slot 56 m from the click (the row spans ~140 m: two line-frontages + gap, centred on it);
  worst run toward the middle **6.9 m** (was 37.6); worst heading away 11.2 m (≤ 14 m spacing, the brief's rule);
  no crew's first station is on the other side of the click. Off-line (reported, not judged): 12.1 / 20.5 m, against
  12.7 m for ONE squad alone on the same click (the reference case): a crew finding its seat inside its own squad's
  travelling wedge, brains' transit seating, the same with or without a second squad.
- Also seen: `make picker-playtest` and `make control-playtest` pass on this code (builder0).

**O4 DONE (green: `b03c0767`, main merged; builder0, `make check exited 0`, 2127 passed 0 failed, ALL JUDGED, thirteen
lines unmoved, determinism `762a0576f944f5b7`):**
- Per vehicle: `RtsControls.arrival_slot(unit)`: where it will STAND (an element in transit lays its own formation,
  pitch and seats on the task's destination at the arrival heading; otherwise the element's slot, else the order's
  goal). The ground's dashed line + dot per selected vehicle (`shown_route`) and the radar's crosses use it, so the
  dots are at the click side by side, not at the stations moving with each squad.
- Per squad: one ground pin per squad in the selection (`order_marks` / `_task_mark`). **Found in the frames:** with
  two squads selected it drew one pin PER VEHICLE ("MOVE · 0/1 there", ten of them) because it only had a squad pin
  for a single selected element; every crew's leader-issued order has its own id. That was literally "dots all
  over the map". Radar: a square per selected squad at its anchor (`selected_squad_anchors`, both mark paths).
- `OrderFeedback` marks each squad task's anchor (`command["task"]` on command_issued); before, a task click got no
  3D marker or sound at all (its crews' orders are the leader's, which it rightly ignores).
- Frames looked at (`make two-squads-shots`, builder0, foundry, at `b7176662`): 1854x1011 ordered: one pin per squad
  ("MOVE · 0/5 there · 43 m"); settled: the two wedges side by side either side of the crate, each under its own
  "MOVE · there" pin; 1200x540 grouped at 5 s: two pins (86 m / 13 m), a dashed line from each vehicle to its own slot,
  the radar's two squares with five crosses each. The windowed run is real time (three cases × 25 s settles): it
  needs the 720 s timeout now in the target.
- Tests: `test_control_two_squads.gd` (pins per squad, radar squares and crosses, ground dots at the arrival slots).

**Board's requests DONE (`006a3add`, `b03c0767`):** (a) the radar draws each ring's capture fill as an arc in the
taker's colour inside the owner's ring, reading `Match.score_snapshot()["objectives"]` via `score_changed` (C19.4;
`Radar.capture_fill`, test in `test_control_radar_marks`); (b) `TacticalMap._draw_control_meter` removed (board's
ScoreBug on both paths, `b8725381`).

**Requests from other streams (via the orchestrator, 2026-10-05 late):**
- (done, above) board (a): the radar draws each objective ring's capture fill as an arc (abs(progress), capturer's colour) beside
  the owner colour (`radar.gd` ~519-523). Read `Radar.objective_rings`' progress now; switch to
  `Match.score_snapshot()["objectives"]` on `score_changed` once board's S1 is on `main`. After O2/O3.
- (done, above) board (b): remove `tactical_map.gd` `_draw_control_meter` (touch path) ONLY when the orchestrator says board's
  ScoreBug is on `main` on both paths. Not before.
