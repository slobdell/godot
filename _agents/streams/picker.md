# Stream: picker (the Formation button becomes a picker he can see: every formation as its shape, one click, a preview on hover)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 18 direction* (item A and
> *His pick*), `_agents/legibility.md`, `_agents/workstreams.md` *Round 18*. You own `game/ui/**`, `game/control/**`,
> `tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_hud*.gd`, `tests/test_tactical_map.gd`,
> `tests/test_element_preview.gd`, `tests/test_touch.gd`. **Lent to finale:** a minimal fix in the DEFEAT / VICTORY
> banner's code (`game/ui/widgets/hud_skin.gd` and whatever draws it) if the end-of-match stall is a first-use cost
> there; it arrives through the orchestrator and is listed in finale's merge notes (C18.6).

## The lead's direction (2026-10-04, in chat, after playing round 17; verbatim)

> *"There's a quick UX request I think we should have - trying to change the formation by way of toggling through button
> clicks takes too long and it's not apparent what the next formation is. I think we should instead have a widget that
> does a mouseover effect that shows the possible formations, and I think we had a mouseover effect on top of each
> formation still that shows the sleek visualization of what the formation does."*

**Read plainly:** hovering the Formation button opens a small panel of every formation he can pick, each drawn as its
shape; one click picks it; hovering a formation in that panel shows what it does, in the same style as the task
previews. The current choice is marked. G keeps working for keyboard play.

## Where things stand (read at `c1cb2adb`, re-checked at `e9400ae1`; not played by the orchestrator)

- The play view's Formation button (key G) calls `RtsControls.cycle_formation()` (`game/control/rts_controls.gd:954`),
  which steps through `FORMATION_CYCLE = [AUTO, wedge, line, column, vee]` (`rts_controls.gd:73`): five states, up to
  four presses to reach one, and nothing shows which comes next. The button is wired in
  `game/ui/selection_panel.gd:440`; its glyph and label show only the current formation
  (`CommandIcons.formation_readout`, `game/ui/command_icons.gd:420`, called at `selection_panel.gd:283`).
- Echelon left, echelon right and coil are not in the cycle; they exist in the formation geometry and in the tactical
  map's picker (`PICKER_FORMATIONS`, `game/ui/tactical_map.gd:777`, cards built at `:844` from
  `CommandIcons.FORMATION_INFO`, `command_icons.gd:11`).
- The "sleek visualization" he remembers is real and lives in two places: the task buttons' animated top-down loop
  (`TaskPreview`, `game/ui/task_preview.gd`, round 7, built from the real planner) and the tactical map's formation
  cards (drawn from the real geometry, one plain-language line each). **The play view's Formation button has neither.**
- Tests that pin today's cycle and will need to follow the change: `tests/test_control_group_moves.gd:212–215`,
  `tests/test_control_panel.gd:99–102`, `tests/test_control_screen_task.gd:75,122`.
- The HUD redraws on change: lesson 242 (a redraw signature carries what it draws by identity or version, never by
  count). The HUD's per-unit cost on his laptop is a known line (`roadmap.md` *Round 18 candidates* 2, held): the
  picker must add nothing per frame while it is closed.

## Decided by the orchestrator (broad strokes are ours; record a reason if you overturn one)

- **AUTO is a card in the panel**, first, drawn as the shape the doctrine is forming now for the selection.
- **The echelons and coil join the play view's set**: the panel has room and the geometry exists. One list for both
  pickers (the tactical map's and the play view's), so a formation can never be in one and missing from the other.
- **G still cycles**, and the panel shows the cycle's next step while it is open. Direct keys per formation follow the
  tactical map's (Z X C V B N) only if they are free in the play view: check `control_hints.gd` and the bindings first.
- **Touch:** there is no hover on a phone. A tap on the button opens the panel, a tap on a card picks and closes, a
  long-press on a card shows the preview. The phone layout is a first-class target (`vision.md`).

## Backlog (in order)

- **P1. One formation list and one card.** The set, the order, the glyph, the one-line description and the shape come
  from one place for the play view, the tactical map and G. Tests first: every formation in the geometry has a card;
  the two pickers list the same set; the cycle is a subset in the same order.
- **P2. The panel.** Opens on hover (mouse) or tap (touch) of the Formation button; every formation as its shape; the
  current one marked; one click picks and the next order uses it (assert through `orders.current(...)`, as
  `test_control_group_moves.gd` does). It closes on pick, on leaving the panel, on Escape, and on a click elsewhere,
  and it never swallows a world click it should not (a move order issued while the panel is open is a test).
  Hover intent: a short open delay and a forgiving path from button to panel, so crossing the button on the way to
  another control does not flash the panel and moving diagonally into it does not close it.
- **P3. The preview on each card.** Hovering a card plays the formation the way the task previews play a task: built
  from the real formation geometry and planner (`TacticsFormation`, the same source `TaskPreview` uses), for the
  number and kind of vehicles selected (four tanks draw four tanks; a mixed squad draws its real slots), with the
  plain-language line. One preview instance, reused; nothing built until first opened; nothing ticking while closed.
- **P4. Look at it like a player.** Screenshots at desktop and phone aspect of: closed, open, a card hovered, a pick
  made, AUTO's card for two different selections. Look at them. Then a scripted skirmish in which the picker is
  opened and a formation picked mid-fight, on his window size (1854×1011) and at the phone aspect.
- **P5. Its cost, on his path.** `hud_cost_probe.gd` / `make perf-play` before and after with the panel closed: no
  measurable change in the HUD's line (state commit, machine, load, sample). Open-panel cost reported, not gated.
- **Stretch.** (a) The tactical map's picker adopts the same card and preview. (b) A formation's card shows whether it
  FITS where the squad stands (a line of four needs about 36 m; `SlotGround.standable_for` knows) so a formation that
  will be squeezed is visible before he picks it: this is the join with the maps stream's work, ask the orchestrator
  before building it. (c) The task buttons and the formation picker as one palette style.

## How to verify

`make remote T=check` green on every commit you report (read the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe). The sim baseline is UNMOVED: a UI change that moves it is a finding. `make
skirmish` and use it. His eye is the check (C18.3): there is no page unless you have a real choice to put to him; if
you do, the page is rendered headless and its buttons counted before the link goes anywhere (lesson 252).

## Don't touch

`game/ai/**`, `game/tactics/**` (brains; read `TacticsFormation` freely, change nothing) · `arenas/**`, `game/arena/**`
(maps) · `game/theme/**` (finale owns `game/theme/fx/**`; the rest is nobody's) · `mk/core.mk`, `tests/baselines/**`
(ship) · balance values in `game/units/units.gd` (C12.6).

## Waiting on the lead

- Nothing. He plays it when it merges.

## Status

_Updated 2026-10-04 by the picker worker. Machines: "laptop" = his UHD 620 laptop (this checkout); "builder0" = `make remote`._

**State:** P1–P5 done, stretch (a) done, stretch (b) done on the orchestrator's yes (2026-10-04, godot-67, four
conditions, all met below), stretch (c) satisfied by construction (see Decisions). Green hash: _see Merge notes_.

### Plan (as worked)
P1 one list → P2 the panel → P3 the preview → P4 the playtest and frames → P5 the cost → (a) the tactical map's picker
→ (b) FITS / SQUEEZED here → (c) one palette.

### Done
- **P1** `game/ui/formation_catalog.gd` (`FormationCatalog`): `ORDER` = AUTO, wedge, line, column, vee, echelon L,
  echelon R, coil, plus the names, taglines, one-liners (`CommandIcons.FORMATION_INFO` is now an alias) and `CYCLE`
  (what G steps through). `TacticalMap.PICKER_FORMATIONS` = `FormationCatalog.shapes()`; `RtsControls.FORMATION_CYCLE`
  = `FormationCatalog.CYCLE`. Tests: every nameable shape has a card; the two pickers list the same set; the cycle is an
  ordered subset.
- **P2** `game/ui/formation_picker.gd` (`FormationPicker`, a child of `SelectionPanel`). It opens after the mouse rests
  0.22 s on the Formation button, or on a click or tap. Every card shows its real shape; AUTO's card draws the shape
  the leader forms now ("Auto: Wedge"); NOW marks the formation in use and G marks the one G picks next. One click
  picks (`RtsControls.set_formation`) and closes. It closes on leaving (0.35 s grace, and the strip between the button
  and the panel counts as inside, so a diagonal path is forgiven), on Escape (consumed, so the selection stays), and
  on any click outside, which still reaches the world. A long press (0.45 s) on a card previews it without picking.
  While closed it is hidden and does no per-frame processing. The Formation button's click now opens the panel; G
  still cycles. Tests: hover delay (crossing doesn't open), pick → `orders.current(...).formation`, Escape, a right
  click while open still issues the move, a left click still selects, the diagonal path, overshoot and leave, long press.
- **P3** `game/ui/formation_preview.gd` (`FormationPreview`). The selected vehicles form up, drive, halt, turn to
  their sectors, and the sectors light up. The bottom line reads "N m wide · watches N°". Slots, seats and sectors come
  from `TacticsFormation.place` (the squads' own call) for the selected vehicles; with fewer than two selected, a squad
  of four tanks stands in. Layouts are cached per (shape, vehicles). There is one instance, built on first open, and
  it draws into a child stage, so only the animation redraws each frame; the cards redraw only when what they show changes.
- **P4** `game/control/picker_playtest.gd` (`PickerPlaytest`; `make picker-playtest` headless,
  `make remote T=picker-shots` windowed at 1854x1011 and 1200x540). It is a real skirmish driven by pushed input. It
  rests on the button, hovers Line (frames mid-drive and with sectors), shows AUTO for squad 1 and squad 2, presses
  Escape, picks Line with one click, then attack-moves into contact, opens the panel mid-fight, picks Wedge and checks
  the next order carries it. Headless on the laptop: 6/6 checks; contact 3.5 s after the attack-move.
  **Looked at** (`make remote T=picker-shots`, builder0, at `ec4fb58d`, then again at `d6df4928`): the panel was
  closed, then open, with a card hovered (driving, then the sectors lit), AUTO for squad 1 and squad 2, Line picked,
  and opened mid-fight. Both sizes are 8/8. **Fixed from looking:**
  - the control-group bar drew over the panel's bottom row of cards (and would have taken their clicks), so the panel
    now sits above it, and the playtest checks it is clear of the bar and on screen;
  - at the phone size the preview was squeezed by three lines of text, so the sentence now has its own strip under
    the cards;
  - the preview's vehicles were small, so they are bigger.
  What it shows: at the match start every card reads "fits here" (the squads stand in their open base). Mid-fight,
  Column, Echelon R and Coil read "squeezed here" in orange.
- **P5** the HUD's cost on his path (`make hud-profile`, headless, 1854x1011, ~30 a side (68 vehicles), 20 s per arm,
  laptop, three interleaved pairs, `cbda2c6a` (launch) vs `58a5ebc2`, load 2.6–7.1). Results are in the yardstick's
  units (refs) because the load moved:
  - HUD total, refs/frame: before 32.13 / 30.88 / 31.23 (mean 31.41), after 31.60 / 31.37 / 32.02 (mean 31.66).
    The +0.25 difference is inside the before arm's own spread (1.25), so **no measurable change**.
  - `selection_panel.process`, refs/frame: before 3.42 / 3.30 / 3.33, after 3.37 / 3.35 / 3.41. Same.
  - **The check that the closed panel costs nothing:** the picker's HudClock rows (`formation_picker.process/draw/preview/fit`)
    are absent from every closed run: zero calls per frame.
  - Open cost, reported and not gated (`--hud-profile-picker=open`, 8 s, laptop, load ~5, one run each): the whole
    panel redrawn every frame cost 5.7 refs/frame. After the split it costs `formation_picker.preview` 1.13 plus
    `.process` 0.29 refs/frame, and the cards don't redraw.
- **Stretch (a)** The tactical map's picker (touch grammar) plays the same `FormationPreview` above its cards: the card
  under the finger or mouse, otherwise the squad's own, with that card's line. It animates only while that picker is
  open, and it still fits a 1200x540 phone (test).
- **Stretch (b)** Each card's bottom line reads **"fits here" / "squeezed here"** (words; the orange only underlines
  the squeeze). The preview adds "Here: fits at its own spacing." or "Here: squeezed (a vehicle stands N m off its
  place)". `game/ui/formation_fit.gd` (`FormationFit`) is the one adapter. It asks the new read-only
  `Orders.preview_group`, which runs `Orders._resolve_group` itself: the order path a player's move uses
  (`GroupFormation.choose`, `SlotGround.for_unit`, `SlotGround.apart`). The question it answers is what a move to the
  squad's own centre in that formation would seat. A card reads SQUEEZED when a slot moves ≥ 1 m (the unit card's
  own "slot moved" threshold) or the group takes another shape.
  - Tests use hand-built navmeshes. On a 200 m plate every shape FITS; in a 14 m lane a line SQUEEZES and a column
    FITS. In both, every card is compared with the real order issued.
  - Mutation-checked: threshold 100 m fails the lane test, and so does `fits = true`.
  - The calls in game/tactics are pinned by arity and return shape (the test fails if brains changes them).
  - **Cost:** measured when the panel opens (and when the selection changes while it is open), one card per frame
    over its first eight frames, never while closed. Laptop, picker-playtest, load ~2.7, one open each: the worst
    frame was 1.6 ms at match start and 5.8 ms mid-fight. All eight in one frame had cost 5.6–13.4 ms.
  - Mid-fight the playtest read column "squeezed 4 m" and echelon R "squeezed 7 m", with the other shapes fitting.
- **Found and fixed (control's own file):** `Orders._same_order` dropped the player's same click in a different
  formation as a repeat: pick Line, click where the squad stands, and nothing happened. A new formation is now a new
  order (test). It applies to player-source orders only.

### Decisions (one line each)
- G cycles AUTO → wedge → line → column → vee (the everyday shapes); the echelons and coil are panel-only. Eight
  presses round would bring back his complaint. From a panel-only shape, G steps on round to AUTO.
- **No direct keys per formation in the play view:** C, V and B are taken (C, V camera; B ambush). The tactical map
  keeps Z X C V B N.
- The Formation button's click opens the panel instead of cycling, so a tap on a phone opens it. Cards pick on
  release, so a long press can preview without picking.
- The badge describes the ground under the squad when the panel opens ("here"), never the hovered ground: that would
  be per-frame work and would read as a promise about the destination (orchestrator condition 2).
- **(c) one palette:** the panel uses the command card's own vocabulary (the HUD_BACKGROUND box with a yellow
  outline as the task tooltips use, CARD fills, cyan glyph tints, yellow for "in use", the same font and sizes) and
  draws through DrawBatch like the card. Nothing more was needed.

### Questions for the lead (in his terms)
- None blocking. When he plays: does the panel open at the right moment when he rests on Formation (a fifth of a
  second), and is "squeezed here" on a card something he reads before he picks?

### Requests to picker (queued; each waits for finale's branch on main-checked, the orchestrator says when)
- **Loading screen:** hold it until `FxWorld.warmup.done` (`game/ui/game_launcher.gd`, `GameLauncher.start`), with a
  timeout so a missing FxWorld (headless, tests) never holds it. Test: the screen is still up on the frame
  `warmup.done` turns true.
- **DEFEAT / VICTORY:** move the word lower so the last explosion stays visible in the end-of-match slow motion.
  Frames before and after at 1854x1011 and 1200x540, looked at, and checked for overlap with the control-group bar at
  the phone aspect. Finale's two frames come through the orchestrator.

### Requests to other streams
- None. (Brains: `SlotGround.standable_for/for_unit/apart` and `TacticsFormation.fit_to_corridor` are pinned by
  `test_the_seating_calls_the_badge_rests_on_have_not_changed_shape`. If you change one, that test names it, and the
  badge's adapter `game/ui/formation_fit.gd` is the one place to follow it.)

### Parade (CP2's candidate 1), after merging main-checked `23941d90`
`make remote T="picker-shots PICKER_ARENA=parade PICKER_SPOTS=centre:0,0,0+ladder:-80,18,90"` (a squad of four set down
with the tree paused; frames `spot_centre.png`, `spot_ladder.png` at both sizes; looked at):
- **Open centre (0, 0), facing the enemy:** all eight cards "fits here" (Auto: Wedge, Wedge, Line, Column, Vee, Echelon L,
  Echelon R, Coil).
- **West ladder (-80, 18), between the rungs at z = 30 and 6, facing along them:** Column "fits here"; Auto: Wedge and
  Wedge squeezed 3 m, Line, Echelon L and R squeezed 5 m, Vee and Coil squeezed 7 m.
- The radar draws parade's hexagon and the ladder rungs. The "Bravo 2" box over the radar's corner is squad Bravo's
  edge-marker chip, not a candidate drawn wrong. **Fixed (the orchestrator: mine):** a chip pinned low on the right edge
  landed on the radar because the bottom strip kept clear (22 % of the screen) is shorter than the radar. A chip whose
  box and arrow would touch the radar now moves up the edge to sit just above it
  (`EdgeMarkers._clear_of_radar`). Test `test_no_edge_marker_lands_on_the_radar` sweeps an element over a 9x9 grid of
  the arena and checks every chip against the radar's rect; it fails with the fix removed (3 chips on the radar).

### The heap abort (orchestrator's URGENT, 2026-10-04 evening)
`test_previewing_a_formation_issues_nothing` passed and then aborted the process at exit on the laptop (glibc 2.39, exit
134, "corrupted size vs. prev_size in fastbins"). **It was the test's two lambdas on the RefCounted Orders' signals, not
`Orders.preview_group`.** Each arm was run alone with the same ground helper:

| Arm | Result |
|---|---|
| lambdas + `preview_group` | 134, 2 of 2 |
| lambdas only | 134, 2 of 2 |
| `preview_group` only | exit 0, 2 of 2 |
| neither | exit 0, 2 of 2 |
| lambdas disconnected before return | exit 0, 3 of 3 |
| methods instead of lambdas | exit 0, 3 of 3 |

- **The fix (`43603182`):** methods connected and disconnected in the test. The whole file under `MALLOC_CHECK_=3
  MALLOC_PERTURB_=165` gives 17/0, exit 0, 2 of 2; `picker-playtest` under the same env exits 0.
- **Valgrind on the defect** (release binary, no symbols): the first complaint is an invalid read of size 4 in
  `pthread_mutex_lock`, 872 bytes inside a 1,696-byte block freed earlier on the same shutdown path. 32 errors from 25
  contexts.
- The paragraph on this Godot hazard is in `godot_for_programmers.md`.
- `repath_playtest.gd`'s lambdas on Orders became methods.
- `picker-playtest`, `picker-shots` and `shell-playtest` now fail on the engine's exit code (ship's pattern). Each was
  proved red by a stub that prints DONE and exits 3.

### Parade v3 (maps' 9475c06d, layout file only, on picker 40cd31b8; builder0 frames at both sizes, looked at)
- **Bay (-80, 0), facing east out of the west bay:** all eight cards "fits here"; the line of four stands between the
  bay's two container walls.
- **Centre (0, 0):** all eight "fits here".
- The "Bravo 2" chip sits just above the radar now (9a88b504 working in the real game).
- The heap-abort fix on builder0 (glibc 2.43): `MALLOC_CHECK_=3 make test FILTER=` the method gives 1/0, make exit 0;
  the whole file gives 17/0, make exit 0.

### Finale's two requests and the Watch.on conversion (done)

**The loading screen holds for the shader warm-up** (`5e3224bc`, `d65913bf`, `b22bb956`):
- `GameLauncher.hold_for_warmup` waits between the first frame and `done()` on a last stage, "Warming up the lights",
  capped at 120 frames.
- `GameLauncher.warmup_holds(warmup)` holds only while finale's warm-up is warming a played match. A menu's backdrop
  match is never warmed (finale's `cdef3fae`), so it never holds.
- Tests (`tests/test_hud_launcher_warmup.gd`): the screen is still up on the frame the warm-up lets go; a stuck warm-up
  releases at the cap; with no FxWorld it releases at once; a backdrop never holds; a played match holds until done.
- `LOAD_TIMING` marks `warmup_held_<frames>_<done|idle|none>`. builder0, shell-playtest x2, through the real launcher:
  - the menu launch holds 0 frames with the warm-up idle;
  - the FIGHT launch holds 3 frames and lets go with the warm-up **done** (warmup = 156 and 2977 ms; builder0's
    hidden window draws about 1 fps).
  So there is no race with the warm-up's throttled played-match check.

**DEFEAT / VICTORY below the kill** (`39475d19`):
- The box is centred at 66 % of the screen height and capped to end 24 px (1080p) above the alert strip
  (`EdgeMarkers.ALERT_Y`).
- Test at 1854x1011 and 1200x540.
- Frames: `make remote T="end-trace END_TRACE_SHOTS=1 ..."`, Sumps seed 1, before (`hud_skin.gd` from `5e3224bc`) and
  after, both sizes, looked at. Before, the word sits on the burning wreck; after, the explosion is fully visible above
  the word and the word is clear of "Alpha wiped out [Q]".

**`test_control_orders`:** its four lambdas on Orders' signals go through ship's `Watch.on` (`d65913bf`); the file
exits 0, 2 of 2.

**Not mine, routed:** the +188 orphan nodes per setup in `test_control_orders`, `test_control_group_moves` and
`test_every_unit_selectable` are unnamed `@MeshInstance3D` strays (`--leak-report`), created by the arena + match +
units setup, not by control code. One test releases 1153 of them when a unit dies. The likely shape is lesson 75 (a
field-initializer `MeshInstance3D` added only conditionally: `cyber_vehicle.gd:18`, `city_block.gd:52`), in
`game/theme` (nobody's); not proven. Reported to the orchestrator.

**Green:** `39475d19` (hold + banner; merged as `1a9564d2`) and `d65913bf` (backdrop test + Watch.on): builder0 exit 0,
ALL JUDGED, 2038/0 and 2042/0, baselines unmoved.

### Known issues
- The badge is about where the squad stands and ignores where the next order goes; its wording says "here".
- AUTO's card read "Auto: Wedge" for both squads in seed 3 (both elements' leaders were in a wedge). That is true for
  those squads, and AUTO follows the leader's pick when it changes.
- Pending from the orchestrator: after CP2, merge main and take one frame of the panel on the candidate's open centre,
  where a line should read "fits here".

### What to playtest
`make skirmish`. Select a squad and rest the mouse on **Formation** (bottom right of the card). Hover each card to
watch it, click one, then right-click. Tap on a phone: `make skirmish` with touch, or the tactical map `--touch-map`.
Frames: `make remote T=picker-shots` → `build/picker-shots/1854x1011/` and `1200x540/`.

### Merge notes
- `mk/command.mk`: new `picker-playtest`, `picker-shots` (additive).
- `game/control/orders.gd`:
  - **`Orders.preview_group(names, formation, to)`** is a new READ-ONLY entry point. It returns the per-unit orders a
    player's move would seat, and `test_previewing_a_formation_issues_nothing` pins that calling it records no order,
    emits no `issued`/`order_changed`, and moves or turns no unit.
  - `_same_order`'s player branch now compares the formation.
- **Fights across the `_same_order` change: SAME.** The scripted Sumps skirmish (`--skirmish --scripted --enemy=cpu
  --arena=sumps --seed=3 --hash-every=150 --hash-until=900`, headless, `--fixed-fps 60`, laptop) was run twice on
  each side, at `58a5ebc2` and at `ec4fb58d`. All four runs gave identical SIM_HASH at every 150 ticks to 900
  (tick 900 `e7b4a7ede7c1b52d`).
- Sim baseline **UNMOVED** on every check (`05df1d55ba49cde1`, builder0).
- **Green hashes:**
  - `58a5ebc2` (P1–P5 + stretch a): builder0, `make check exited 0`, 23 targets ALL JUDGED, 2013 passed / 0 failed,
    0 engine errors. Merged to main as `0d6e506b` by the orchestrator.
  - **`d6df4928` (stretch b + the frame fixes): this commit is green, merge here.** builder0, `make check exited 0`,
    23 targets ALL JUDGED, 2019 passed / 0 failed, 0 engine errors, baseline `05df1d55ba49cde1` unmoved, determinism
    `762a0576f944f5b7`. Commits after it change only this Status.
