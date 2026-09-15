# Stream: control (StarCraft-style control, responsiveness, desktop first)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 3 direction*, pillars 5 and 7, *Controlling units*), and [../workstreams.md](../workstreams.md) (K1 is yours;
> CP1 is your first item). You own `game/control/` (new), `game/ui/` except `widgets/**` and `hud.tscn`,
> `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline}_mode.gd`, `mk/command.mk`, and
> `_agents/tactical_map.md`.

## The lead's direction (2026-09-15)

> *"we really need to re-imagine the UX (where I delegate that to Claude to figure out) because having to click
> between squads is quite burdensome; I would say we should draw inspiration from unit combat completely from
> starcraft (i.e. regroup units, click individual units, the units are actually responsive) … Trying to manage different
> formations is overwhelming … re-imagine this in the interest of making it fun (and perhaps that even means we target
> Steam as our primary platform so we can shift, right click, etc). But right now this is looking like a military nerd
> game instead of something that's fun to play … the units just don't feel controllable right now, they seem to get
> stuck in some particular state and then not respond to my clicks; units within the same squad ended up getting
> separated and didn't rejoin … the formations are definitely cool and useful, I know they serve practical purposes and
> a V formation of scouts from the gang coming at you would be scary; I just don't know how to incorporate it well."*
>
> Decided with the lead: **desktop first** and **StarCraft-style control**.

## Where things stand (round 2)

- `game/ui/tactical_map.gd`: a mobile tap grammar (tap a squad chip or unit, tap the ground or radar; hold-drag for
  facing), squad chips, a formation and drill picker with icons (`command_icons.gd`), 3D selection rings
  (`selection_markers.gd`), HUD messages (`hud_messages.gd`), and the RTS camera with order tracking
  (`game/camera/`). Orders are squad-level `SquadCommand`s applied by `Match.apply_squad_command` to
  `game/ai/squad.gd`, whose brains (`TankBrain extends OrderController`) decide how to execute them.
- **Problems the lead hit:** squad switching is burdensome; formations and drills overwhelm; units get stuck in a brain
  state and ignore clicks; squad members drift apart and never rejoin.
- The round-2 brief and its decisions: [archive/round2/command.md](archive/round2/command.md).

## Backlog (in order)

**X1. The Orders API (K1; checkpoint CP1).** `game/control/unit_command.gd` (the serializable command) and
`game/control/orders.gd` (per match: `issue`, `current`, `queue`, `order_changed`, `complete`), exactly as K1 in
workstreams.md, with validation and unit tests. Ask combat (Status request) for the one-line `Match.orders` field;
until then create `Orders` in skirmish mode. Include a minimal adapter so today's brains follow a `move` order (the ai
stream replaces it). **Announce CP1 in your Status as soon as it's green.**

**X2. Selection.** Click a unit; drag a box; shift-click to add or remove; double-click or ctrl-click selects all
visible units of that type; Escape clears. Enemy units can be selected to inspect (not command). Selection is
visible without covering models (reuse the ground rings). Tests drive real mouse events through `Viewport.push_input`.

**X3. Orders from the mouse and keyboard.** Right-click ground = move; right-click enemy = attack; A then click =
attack-move; S = stop; H = hold; F then click a friendly = follow/escort; shift queues any order (with visible
waypoints). Give every order an acknowledgement (marker, a short HUD blip; feel owns the sound). **Test the response
guarantee end to end:** a unit in any brain state starts moving toward a new order within 3 ticks.

**X4. Control groups and camera.** Ctrl+1–9 saves a group, 1–9 selects it, double-tap centers the camera, Tab cycles
groups. Squads from doctrines load as groups 1–5. Edge pan, middle-drag, wheel zoom, minimap (radar) left-click jumps
the camera and right-click orders. Remove the need for the squad bar; keep a compact group bar that shows each group's
unit icons and health.

**X5. Group movement, automatic formations, regrouping.** A group ordered somewhere moves as a group: it arrives
together (slow the fast units), arranges by role and situation (heavies in front, fragile units behind, a spread V for
fast units charging, a line when holding), and faces the direction of travel. **Units that get separated rejoin their
group** unless given their own order. One optional key cycles formations; formation offsets come from
`Formations.offsets` (ai owns the geometry). With ai: brains honor the formation slot as their movement goal.

**X6. The selection panel and HUD.** A bottom panel for the selection: unit portraits (icons are fine) with health
and shield, the selection's current orders, and the command card (Move, Stop, Hold, Attack-move, Follow, Formation)
with hotkeys shown. Retire the drill picker and the formation picker from the default HUD (keep the code behind a
flag until the lead playtests). Info density like StarCraft, cyber styling from art widgets.

**X7. Playtest harness.** `make control-playtest-shots` (a scripted session: box select, attack-move across the
arena, a queued route, a control-group swap, a separated unit rejoining) with screenshots at 1920×1080 and 1280×720
and a log proving every order's response tick. Look at every screenshot.

**X8. Touch adaptation (stretch).** Tap selects, drag draws a box, a long press opens the command card, two-finger
pan and pinch. Only after X1–X7 are fun.

- **Stretch:** smart-casting-like quality of life (right-click an enemy with a mixed selection makes only units that
  can hit it attack; the rest follow); a "select idle units" key; hover tooltips with unit stats.

## How to verify

`make remote T=check`; your control tests with real mouse and keyboard events; the response guarantee test; the
playtest shots, **looked at**; a short screen description in Status of how selecting and ordering feels. Web still
boots (`make remote T=web-smoke`).

## Don't touch

Brain behavior (ai; request changes), weapons, movement physics, and `Match` (combat; request the `Match.orders`
field), effects and HUD styling (feel), models (assets).

## Status

_Updated 2026-09-15 by the control worker. **Round report: every backlog item is done except X8 (deferred by the
round's no-new-touch-work constraint). `make remote T=check` is green (470 tests, every smoke) on a39c135, the merge of main's
tools/remote.sh fix; every remote screenshot was re-taken after that merge, and each was checked to be a distinct frame and looked at.**_

### Plan (in order) and progress

| Item | State |
|---|---|
| X1 Orders API (K1, CP1): `UnitCommand`, `Orders`, `GroupFormation`, temporary `OrderExecutor` | **done** (2114693): 17 tests; response measured at 1 tick from fighting, driving, holding, hurt |
| X2 Selection: click, box, shift, ctrl/double-click by type, Escape, inspect enemies, rings | **done** (2114693): 7 tests through `Viewport.push_input` |
| X3 Orders from mouse and keyboard: right-click move/attack/follow, A/F/M + click, S, H, shift queue + waypoints, acks | **done** (2114693): 7 tests; click-to-tracks 1 tick |
| X4 Control groups and camera: ctrl/shift/1–9, double tap centers, Tab, doctrine squads = groups 1–5, radar look/order, group bar | **done** (2114693): 7 tests |
| X5 Group movement, automatic formations, regrouping | **done** (0620b4c): 8 tests; a scout and a tank arrive 25 ticks apart (the scout tops out at 10.7 of 14 m/s); a laggard 40 m behind arrives 21 ticks after its leader |
| X6 Selection panel and command card; retire drill/formation pickers (kept behind `--touch-map`) | **done** (0620b4c): 6 tests; panel clear of the radar at 1920×1080 and 1280×720 |
| X7 `make control-playtest` / `make control-playtest-shots` | **done**: headless and windowed 1920×1080 and 1280×720 all ok on builder0; 7 orders logged per run, worst response 1 tick; frames looked at (the first windowed runs exposed harness timing: units still sliding into their spawn wedge during the box drag, and a 150 s timeout; fixed) |
| X8 Touch adaptation (stretch) | **deferred:** workstreams.md forbids new touch-only work this round; the round-2 touch map still runs behind `--touch-map` |
| Stretch: smart attack, select idle (F1), hover tooltips | **done** (b0da368): 4 tests; `make remote T=check` green (470 tests); `make remote T=garage-web-smoke` passes with the new controls in the browser |

### CP1 (K1 Orders API): READY, commit 2114693

**CP1 is green** (`make remote T=check` on builder0: 452 tests, every smoke). Merge `stream/control` at 2114693 (or
later) to `main`. What consumers get: `game/control/unit_command.gd`, `game/control/orders.gd` (K1 exactly, plus
`issue(command, team)`, `queue_changed`, `goal_position`, `Orders.goal_of`, `Orders.reached`, `Orders.of/attach`), and
the temporary `OrderExecutor`. That commit also switches skirmish to the new desktop controls (round 2's map behind
`--touch-map`). Later commits on the branch (X5–X7, stretch) are green too; merging the branch head brings
`Orders.pace_factor` and `Orders.station`, which ai X1 wants.

### Decisions

- **Brains keep their autonomy until ai X1; ordered units obey a temporary executor.** `OrderExecutor`
  (`game/control/order_executor.gd`) pauses an ordered unit's `TankBrain` and drives it with a plain
  `OrderController` (pathing, unsticking, fire at will). When its queue runs out the unit keeps its station (its
  slot in its group: returns if pushed, faces the group's heading or the nearest visible enemy, shoots). Why: the lead's first complaint is units
  ignoring clicks; obedient beats clever-but-deaf until brains execute orders. It steps aside by itself once
  `TankBrain` declares `const EXECUTES_ORDERS := true`. Units never ordered keep their brains and doctrine squads.
- **`Orders` is a RefCounted per match**, reachable with `Orders.of(match)`: `Match.orders` once combat adds it,
  else a meta set by `Orders.attach` (skirmish mode does that today). `issue(command, team = -1)` adds an optional
  team check. Extra signal `queue_changed(unit)` for waypoint markers. Destinations outside the arena are clamped,
  not rejected (a click on the edge still orders).
- **Per-unit order data** carries the group (`units`), `slot` ([right, back] m), `goal`, `heading`, and `pace_mps`,
  so brains don't need control's code to honor formations. `Orders.goal_of(order, match)` resolves follow slots live.
- **Automatic formations (X5):** a wedge for 2–5 units with the heaviest at the point (tank, then IFV/Burner, scout,
  Lancer, artillery last), rows of up to 5 abreast beyond that, a line when holding, and a 1.4× wider wedge when only
  fast units (≥ 12 m/s) attack-move. Slots are 10 m apart, centered on the click, facing the direction of travel;
  units keep their left-right order so paths don't cross. Named formations (G) use `Formations.offsets` (≤ 5 units).
  Why a wedge over a line for moving groups: it keeps the heavy in front and reads as a formation from the camera.
- **Arriving together = equal arrival times, not a speed cap:** each unit drives at `remaining / slowest member's time
  to arrive` (floor 35%). A cap at the slowest unit's top speed would also slow the laggard it waits for.
- **Stations are slots, not stop positions:** a unit returns to where its group put it, which is what "rejoin the
  group" means in a StarCraft model where the player decides who goes together.
- **New desktop controls are a new node, not a rewrite of `TacticalMap`**: `RtsControls` (`game/control/`) is the
  default in skirmish; round 2's tap grammar stays behind `--touch-map` (and the camera playtest) so its tests keep
  passing until the lead has played the new controls. The node keeps the name `TacticalMap` so feel's HUD skin
  lays out around it.
- **Keys:** A attack-move, F follow, M move (armed orders, cancelled by right-click or Escape; shift keeps them armed),
  S stop, H hold, G formation, C center on selection, Tab next group, F1 idle units, Space pause. Right-click on a
  friend outside the selection follows it (StarCraft). Arrows, edges, middle-drag, wheel, `,` `.` stay the camera.
  Round 2's F (camera follow) and Tab (overview) are gone from the desktop controls; wheel out for the overview.
- **Smart attack threshold 25% through side armor:** scouts (13% vs a tank) escort instead of plinking; IFVs (34%)
  still join, matching "the IFV chips tanks". Combat's K2 weapons may move these numbers; the rule reads live data.
- **X8 deferred, not attempted:** the round's product constraint ("no new touch-only work this round") outranks the
  brief's stretch item.

### How selecting and ordering feels (from the screenshots and the scripted playtest)

The skirmish opens paused with group 1 (Alpha) selected: bright cyan rings under its three vehicles, faint rings
under the rest, a bottom panel with one big portrait per unit (hull and shield bars) and a six-button command card
with yellow hotkeys, a small group bar above it (`1` lit, `2`), and the radar at the bottom right. Dragging a box
lights the units inside; a right-click drops a shrinking ring on the ground and every selected hull turns toward it
on the next tick; dashed lines run from each unit through its current and shift-queued stops (gold for
attack-moves). A group ordered forward spreads into a wedge with the tanks at the point and arrives together (the
scout visibly holds back). Pressing `2` swaps to the other group; `2` again swings the camera over it. A unit
shoved away from its group drives back to its slot within a few seconds. What still feels thin: once ordered, units
fight like simple turrets (no cover, no flanking) until ai X1 lets brains execute orders; waypoint lines are faint on
the dark floor; the panel's single-unit card is text-heavy.

### Questions for the lead

- **Playtest the new controls** (`make skirmish`): do right-click orders, groups, and automatic formations feel
  StarCraft-like? Can the round-2 touch map (`--touch-map`), with its drill and formation pickers, be deleted?
- **Tab:** the brief asks for Tab to cycle groups (done). StarCraft uses Tab for sub-groups inside a selection;
  worth switching once there are more unit types per group?
- **Planning pause at start:** kept (Space starts). StarCraft has none; drop it for a faster start?

### Requests to other streams

- **orchestrator (K1 additions, all additive, for workstreams.md):** `Orders.issue(command, team = -1)`;
  `Orders.queue_changed(unit)`; `Orders.goal_position(unit)` / `Orders.goal_of(order, match)`; `Orders.reached(order,
  position)`; `Orders.pace_factor(unit)` (arrive together); `Orders.station(unit)` (`{position, heading, units, id}`,
  where an idle unit regroups); `Orders.of(match)` / `Orders.attach(match, orders)`. Per-unit order fields beyond K1:
  `id`, `units`, `started_tick`, `slot`, `goal`, `heading`, `pace_mps`; `formation` holds the resolved name. `UnitCommand`
  rejects unknown keys. `stop` is never queued; `to` is clamped into the arena.

- **combat:** add `var orders: Orders` to `Match` (K1). `Orders.attach` already sets it when the field exists; no
  other change needed.
- **ai:** when brains execute K1 orders, add `const EXECUTES_ORDERS := true` to `TankBrain`; `OrderExecutor` then does
  nothing, and control deletes it. Per-unit order fields are listed in `game/control/orders.gd`'s header.

### Known issues

- **Ordered units lose their brains' cleverness** (cover, retreat, flanking) until ai X1: the executor drives them
  with a plain `OrderController`. Never-ordered units keep their brains.
- **Idle stations don't follow a moving group.** A unit whose orders ran out returns to its last slot, not to where
  the rest of its old group went later; give the group a new order together to regroup it somewhere else.
- **Attack-move splits a group:** each unit halts to fight what it meets (StarCraft does the same); the rest carry
  on to the destination.
- **Pathing around the ordered spot:** slots are not checked against obstacles; a slot inside a crate relies on the
  navmesh's closest point (as round 2's formations did).
- **X8 touch adaptation is deferred** by the round's "no new touch-only work" constraint; touch still works through
  `--touch-map`.

### What to playtest (exact commands)

- `make skirmish` (desktop controls; try: drag a box, right-click the ground, shift+right-click a route, A + click,
  ctrl+3 then 3 3, G then right-click, F1, hover an enemy, right-click an enemy with tanks and a scout selected).
- Round 2's map for comparison: `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish
  --touch-map` (`mk/play.mk` isn't control's, so no make variable was added).
- `make control-playtest` (headless, prints each check) and `make remote T=control-playtest-shots` (frames in
  `build/control-playtest/1920x1080/` and `1280x720/`).

### Next steps

- ai X1: brains execute `Orders.current()`, honor `slot`/`goal`/`pace_factor`, regroup to `Orders.station()`, then
  add `EXECUTES_ORDERS`; control deletes `OrderExecutor` and re-checks the response guarantee test against brains.
- Feel: skin the order markers and waypoint lines (they're plain 2D draws in `RtsControls._draw_*`), order sounds.
- Obstacle-aware slots; station following for split groups; sub-group Tab once the roster grows.

### Merge notes (shared or other streams' files)

- `game/garage/army_loop.gd` (paused army stream): the unpause lookup no longer casts to `TacticalMap` (the node may be
  `RtsControls`); minimal compatibility fix.
- `game/garage/garage_settings.gd` (paused army stream): the second in-match tip described round 2's tap grammar; it
  now describes box select, number keys, and right-click (seen in the browser smoke screenshot). Text only.
- `tools/remote.sh` (shared): none left. Control found the stale Xwayland auth file independently; main's fix
  (7dc7bdc, from feel) was merged in and its version kept.
- `_agents/orientation.md` (common tasks: the skirmish row, a control playtest row) and `_agents/verification.md`
  (a control playtest paragraph): small additive edits.
- `mk/command.mk` (control's now): `control-playtest`, `control-playtest-shots` added; command-playtest targets kept.
