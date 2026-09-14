# Stream: command (how the player commands, camera, readability)

> Read [../game_design.md](../game_design.md) ("Commanding"), [../workstreams.md](../workstreams.md), and
> [../tactical_map.md](../tactical_map.md). You own `game/ui/` (except `widgets/**` and `hud.tscn`),
> `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline}_mode.gd`, and `_agents/tactical_map.md`.

## The lead's direction (2026-09-15)

> *"By putting the vehicles into squads, the UX will be such that the player commands a squad at a time and can
> easily toggle between squads through the UI … All of these formation options are great but since I don't know
> what the difference between all of them is (our users won't be military experts) there should be icons depicting
> what each formation corresponds to … since our game is planned for mobile first, we need to figure out how the map
> can generally work with single clicks (i.e. not right click). I should be able to click on a squad then click on a
> place on the map and they go there (and I also should be able to click on a location in the radar) … we also in
> general need better camera tracking. If I tell a unit to go somewhere offscreen the camera should follow them
> rather than me having to zoom out and then zoom in on where they're going."*

## Where things stand (round 1)

- **Tactical map:** tap a tank to select (tap again for commander), tap the ground to go, hold-drag to set facing,
  drag to pan, pinch/twist for the camera, buttons for drills, formations, pause, overview, follow. Mouse still uses
  right-drag for orders.
- **Radar:** tap aims the camera, drag orders.
- **RTS camera:** perspective, zoom 16–260 m, follow on F.
- **Known problems:**
  - At the default zoom, units are tiny and selection rings and glow cover the new models.
  - Formations are names only.
  - The camera doesn't follow orders.

## Backlog (in order)

**C1. One-tap grammar everywhere.** Tap a squad (squad bar chip or any of its units) → tap the ground **or the
radar** → it moves. Mouse left-click behaves exactly like a tap; no action needs right-click. Keep hold-and-drag for
facing as an advanced gesture. Decide how radar taps split between "move here" (with a squad selected) and "look
here", and record why. Tests drive real `InputEventScreenTouch`/`ScreenDrag` and mouse events.

**C2. Squad bar.**
- Up to 5 chips: squad name, unit-type icons with counts, a compact health/shield summary, and the current order state.
- Tap selects; a second tap centers the camera on the squad.
- The selected squad is unmistakable in the world (ground ring or outline), without covering the models.

**C3. Formation and drill icons.** Draw each formation icon from the real geometry (`Formations.offsets`, C7) so
it can never drift from behavior, with a plain-language label ("Wedge: arrowhead, strong all-round"). Give drills
(move, bound, hold, assault, break contact) icons plus one-line descriptions. They live in a picker that fits a phone.

**C4. The camera follows orders.** After an order to somewhere off screen, the camera smoothly frames the squad (and
its destination) and tracks it until arrival, a manual pan, or another selection. Keep a "follow selected" toggle.
No motion sickness: ease, clamp speed, never fight the player's fingers. Tests check the pose after an off-screen
order. Add `RtsCamera.frame(points)` (C7).

**C5. Readability at play distance.**
- Pick a default zoom where the vehicles read as vehicles.
- Tame the markers: smaller rings, team-colored ground marks, no glow blobs over models.
- Show unit-type icons when zoomed far out and models when close, and declutter nameplates.
- Coordinate styling with art (they own the look; you own what is shown when).
- Screenshots at desktop and phone aspect, compared before/after.

**C6. The in-match HUD for the new rules:** squads ≤ 5, unit types, friendly-fire events, and the control point.
Post the right `Hud.post_message`s (orders, losses, squad destroyed) without spamming.

- **Stretch:**
  - selecting a single unit inside a squad
  - quick commands per drill from the squad bar
  - an accessibility pass (colorblind-safe team marks, text size), in coordination with art

## How to verify

`make check`, the command tests, `make skirmish-shots` (desktop + phone aspect) and **look at them**, plus
a playtest script that selects each squad, orders one off screen, and records camera frames.

## Don't touch

Unit rules and stats (rules), brain behavior (ai; but squad verbs are shared, so coordinate), art and HUD styling
(art), the army builder and results flow (army).

## Status

- 2026-09-15: brief written for round 2. Nothing started.
