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

### Plan (command agent, 2026-09-14 session)

1. **C1 one-tap grammar:** one press state machine for fingers AND the mouse's left button (tap / pan / hold-drag);
   radar tap = order, radar drag = look. Tests with real touch + mouse events.
2. **C2 squad bar:** `game/ui/squad_bar.gd` (chips drawn from live squad data); `squad_selected` signal;
   `game/ui/selection_markers.gd` (3D ground rings, depth-tested, so they never cover models).
3. **C3 icons:** `game/ui/command_icons.gd` draws formation shapes from `Formations.offsets` and drill glyphs;
   a picker panel that fits 1200×540.
4. **C4 camera follows orders:** `RtsCamera.frame(points)` + an order-tracking mode that ends on arrival,
   manual pan, or reselection.
5. **C5 readability:** default zoom, smaller team-colored marks, far-zoom unit-type icons, nameplate declutter;
   before/after shots.
6. **C6 HUD messages:** order/loss/squad-destroyed/friendly-fire/control-point messages, rate-limited.
7. Stretch: single-unit selection, per-drill quick commands, accessibility.

### Done

- **C1 one-tap grammar** (`tactical_map.gd` press state machine, `radar.gd`): tap a unit or chip → tap the
  ground or the radar → it goes. Mouse = finger. Tests: `test_command_grammar.gd` (real `InputEventScreenTouch`
  through `Input.parse_input_event`, real mouse through `Viewport.push_input`: tap unit then ground, mouse
  drag pans / hold-drag faces, radar tap orders, a pinch never orders, right-click still a shortcut),
  `test_radar.gd` (tap orders, drag and long press look).
- **C2 squad bar + world marks** (`squad_chip.gd`, `selection_markers.gd`): `TacticalMap.squad_selected`.
  Tests: `test_command_squad_bar.gd` (chips, summary through losses, contact pip, five squads on a
  1200×540 phone with no overlap, rings follow selection and never show fogged enemies, depth-tested).
- **C3 icons + picker** (`command_icons.gd`, `icon_button.gd`): `test_command_icons.gd` (icons are the
  formation geometry under one uniform scale, shapes read right, every drill/formation explained, the picker
  fits a phone and sets the exact formation, the info line teaches the next order).
- **C4 camera follows orders** (`RtsCamera.frame`, `frame_pose`, `track`, `stop_tracking`, `tracking_ended`):
  `test_command_camera.gd` (framing math, off-screen order frames squad + destination after settling, one frame
  never exceeds the speed limit, visible orders leave the camera alone, manual pan/zoom and reselection end it,
  arrival ends it, Follow toggles and moves with the selection).

### Decisions (with reasons)

- **C1: the mouse's left button uses the finger grammar exactly** (tap = select/go, drag = pan the view,
  hold 0.35 s then drag = go + face). Round 1's "left-drag on the ground orders" is gone: two grammars for
  one button was the confusion the lead described, and drag-to-pan is what phones need. Right-drag stays as
  an optional desktop shortcut (never required).
- **C1: a press on a unit selects on release, not on press,** so a drag that starts on a vehicle pans instead
  of selecting by accident.
- **C1: radar tap = order the selected squad there; radar drag or a resting press = look** (the camera follows
  the finger). The lead asked for "click on a location in the radar" to send a squad, and ordering is the
  high-value action; scrubbing a minimap to look is the universal idiom, and a hesitant (resting) finger
  never sends anyone.
- **C2: the squad bar sits top center; Pause/Overview/Follow move to the top right** (they drop below the bar
  on screens too narrow for both). One pictogram per vehicle rather than "icon ×count": at ≤ 5 units per
  squad it reads as a count and shows losses (crossed out) in the same glyphs.
- **C2: "in contact" = hit in the last 3 s or an enemy in sight within a member's sight radius** (from intel),
  not brain intent strings, so the AI stream can rename options freely.
- **C2: selection marks are 3D ground rings** (depth-tested, just above the fog plane) instead of 2D circles
  painted over the models. Close up (zoom < 0.5) the map draws no 2D vehicle markers at all.
- **C2: a second tap on the selected chip centers the camera once** (frames the squad) instead of following;
  following is the Follow toggle (C4).
- **C3: drills stay one tap away in the order bar; formations open a picker** of cards (icon from
  `Formations.offsets`, name, two-word tagline) with the current formation's one-line description on top.
  Both echelons get their own card (the key B still flips). The info line above the bar teaches the next
  order ("next order: Bound in Wedge. Half the squad covers while…").
- **C4: track only when the squad or its destination is off screen** (outside the middle 85%). A tap on
  visible ground already shows the whole move, and moving the camera then would fight the player.
- **C4: tracking never zooms in closer than the player had it**, eases at 3/s, and is capped at 120 m/s
  (scaled down when close) and 0.35 zoom levels/s. Any manual camera input (pan, pinch, wheel, rotate, radar
  look) ends it at once. An explicit Follow outranks order tracking and moves on with the selection.
