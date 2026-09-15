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

- 2026-09-15: brief written for round 3. Nothing started.
