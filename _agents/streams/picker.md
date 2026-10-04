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

_Not started. The worker keeps this section current: plan, done (with measurements), decisions, questions for the
lead, requests to other streams, known issues, what to playtest (exact commands), merge notes, and the green hash._
