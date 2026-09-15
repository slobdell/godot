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

- 2026-09-15: brief written for round 2.
- **2026-09-14 (command agent): backlog C1–C6 and all three stretch items are done, tested, and committed on
  `stream/command`; `make check`, `make web-smoke`, and `make garage-web-smoke` pass; sim baseline unchanged.**
  Nothing is waiting on a lead gate. Report below: Done, Decisions, Questions for the lead, What to
  playtest, Requests to other streams, Known issues, Next steps, Merge note.
- **Session closed (lead's call).** Final verification on the last commit: `make check` green (333 tests, all
  smokes, sim baseline `e5cf33921713b657`), `make web-smoke` and `make garage-web-smoke` green, and
  `make command-playtest-shots` ok. The branch has not merged `main` (no checkpoint was announced during the
  session). A fresh agent picking this up: read this Status, then run `make command-playtest-shots` and look at
  `build/command-playtest/*.png` to see the current UI.

### Plan (command agent, 2026-09-14 session)

1. **C1 one-tap grammar:** one press state machine for fingers AND the mouse's left button (tap / pan / hold-drag);
   radar tap = order, radar drag = look. Tests with real touch + mouse events.
2. **C2 squad bar:** `game/ui/squad_chip.gd` (chips drawn from live squad data); `squad_selected` signal;
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
- **C5 readability** (`tactical_map.gd`, `skirmish_mode.gd`): the start camera frames the army and the ground
  ahead at zoom ≥ 0.36 (was a fixed 0.62: a tank was ~17 px tall on a phone, now ≥ 24 px, tested); 3D
  nameplates only below zoom 0.12 (were on below 0.45 and covered the fight); close up: models + ground rings +
  a small hull/shield bar over the selected squad and over hurt enemies in sight; far out (zoom ≥ 0.5 or the
  overview): unit-type icons turned to each vehicle's heading (selected squad ringed, commander gold), enemies
  in sight as red type icons, remembered contacts as fading hollow triangles. `--zoom=0..1` for tuning/shots.
  Tests: `test_command_readability.gd`. Before/after: `build/before/skirmish_*.png` vs
  `build/screenshots/c5_*.png` (local, not committed).
- **C6 HUD** (`hud_messages.gd`, wired in `skirmish_mode.gd`): one filtered feed to `Hud.post_message`: losses
  merged per squad with unit types ("Alpha lost 2 vehicles (Tank, Tank), 1 left"), "Bravo destroyed" (error),
  friendly-fire kills called out, enemy kills merged, order acks at most every 3 s (rejections always),
  duplicates within 4 s dropped, ≤ 3 info messages per 3 s, control point "N points from winning" warnings.
  A center meter under the squad bar (our points from the left, theirs from the right, who holds it). The
  debug event log (coordinates) is gone from the play view; the scoreboard says "units", not "tanks".
  Tests: `test_command_messages.gd` (including one that runs the real announcer's wording through the filter).
- **Playtest script** (`game/ui/command_playtest.gd`, `mk/command.mk`): `make command-playtest` (headless) and
  `make command-playtest-shots` (phone-sized window, frames in `build/command-playtest/*.png`) tap each squad's
  chip, tap a far radar spot, and log the camera (`camera.jsonl`). Latest: Alpha and Bravo both tracked, squad
  on screen within 0.4 s, max view speed 32–72 m/s over 0.25 s windows (limit 120), zoom capped at 0.48.
  **It found two real bugs,** fixed: (1) when tracking let go, the camera lurched to tracking's last goal zoom
  (now it stays where the view is); (2) framing a squad plus a destination 170 m away zoomed out to 0.97,
  exactly the zoom-out-then-in chore the lead described (now order tracking caps the zoom, keeps the squad
  framed, and leans the view toward the destination).

- **Stretch: single-unit selection** (`tactical_map.gd` `focus_unit`, unit card): tapping a unit of the
  selected squad opens its card (name, type, hull/shield/ammo/heat, what it's doing in player words) with
  **Lead squad** and Close; its ground ring turns white. Orders still go to the whole squad (SquadCommand has
  no per-unit verb; see requests). Tests: `test_command_squad_bar.gd`, updated map/touch tests.
- **Stretch: quick commands from the squad bar:** long-press a chip → Hold / Break / Assault / Follow for that
  squad under its chip, without changing the selection; closes after one command or 5 s. Test in
  `test_command_squad_bar.gd`.
- **Stretch: accessibility:** friend and foe differ by shape as well as color (enemy ground rings dashed; far
  icons on a hostile diamond vs a round friendly backing; radar enemies as diamonds), and `--ui-scale=0.75..2`
  scales every tap target and its text (1.25 still fits a 1200×540 phone, tested). Tests:
  `test_command_readability.gd`.

### Questions for the lead

1. **Commander election moved behind a button.** Round 1 elected a commander when you tapped a unit of the
   selected squad; with tap-to-go that swapped leaders by accident whenever you tapped near your own vehicles.
   Now that tap opens a unit card with **Lead squad**. Keep it, or go back? (Reversible: one branch in
   `TacticalMap.click`.)
2. **Radar tap = order** (the look is a drag or a long press). If you'd rather a radar tap only look, it's a
   one-line swap in `Radar.tap`.
3. **Order tracking caps at zoom 0.48** and leans toward far destinations instead of zooming out to show both.
   Playtest a cross-arena radar order and say if you'd like it to show more of the map.
4. A **settings screen** for `--ui-scale` (and a colorblind palette from art) needs a home: the title or army
   flow (army stream)? Today it's a launch flag only.

### What to playtest

- `make skirmish`: tap a squad chip, tap the ground; tap the radar; hold then drag for facing; drag to pan.
- Tap a far spot on the radar: the camera should follow the squad without you zooming. Pan to take over.
- Tap a unit of the selected squad: its card; **Lead squad**. Long-press a chip: quick commands.
- Formation button → the picker; read the descriptions. `make skirmish CONTROL=1` for the center meter.
- Zoom all the way out: unit-type icons; enemies on diamonds. `--ui-scale=1.25` via
  `godot --path . -- --skirmish --ui-scale=1.25`.
- `make command-playtest-shots` saves a camera walk-through to `build/command-playtest/`.

### Requests to other streams

- **rules:** tag `MatchAnnouncer.announced` with a kind (e.g. `announced(text, severity, kind)`) so
  `HudMessages` can filter by kind instead of by text pattern; and a `Match` signal for friendly-fire *hits*
  (`friendly_hit(shooter, victim, damage)`) once friendly fire lands, so the HUD can warn before a kill
  (`HudMessages` already reports friendly-fire kills from `tank_destroyed`).
- **rules (C1 catalog v2):** `CommandIcons.role_of` reads `role`; until then it maps v1 `class` (and laser
  tanks → lancer). Icons exist for scout, tank, ifv, artillery, lancer; a new role falls back to a generic hull.
- **art:** (1) the team glow blob under each vehicle is wider than the new selection ring, so at play
  distance the ring reads as a halo on a blob; a smaller or dimmer glow would let the ring and the model read.
  (2) The ring, icon, and meter colors come from `GameTheme.ui` (`friendly`, `enemy`, `commander`); restyle
  freely. (3) `SquadChip`/`IconButton` draw over the theme's Button style; a dedicated chip style (less
  transparent, so crates behind don't show through) is welcome.
- **ai:** per-unit orders are the natural next step for single-unit selection: a SquadCommand `unit` field
  (or a detach verb) the squad applies to one member. The unit card is ready to host those buttons. This is a C7
  contract change, so it's only a proposal.
- **art:** a colorblind-safe palette option in `GameTheme.ui` (the shapes already carry friend/foe).
- **ai:** squad verbs are unchanged; the map only reads `Squad.arrived`, `verb`, `destination`, `roster`,
  `commander`, `formation`, `alive_members`.

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
- **C4: order tracking caps its zoom at 0.48** (still the model view) instead of always fitting squad +
  destination: for a far goal it keeps the squad framed and leans the view toward the goal, and the
  destination comes into view as the squad closes in. Fitting both zoomed a cross-arena order out to 0.97.
- **C4: tracking never zooms in closer than the player had it**, eases at 3/s, and is capped at 120 m/s
  (scaled down when close) and 0.35 zoom levels/s. Any manual camera input (pan, pinch, wheel, rotate, radar
  look) ends it at once. An explicit Follow outranks order tracking and moves on with the selection.
- **C5: nameplates are effectively off in skirmish** (only when zoomed right in). The squad bar has health,
  the rings say whose and which squad, and floating bars cover hurt vehicles; names like "Alpha 2 300 +150"
  were the biggest clutter in round 1's shots.
- **C5: the icon/model switch is at zoom 0.5** (~77 m out), where a vehicle model falls under ~20 px on a phone.
- **C6: the command stream filters messages in `game/ui/hud_messages.gd` instead of editing the announcer**
  (rules owns `game/match/announcer.gd`). It drops the announcer's loss/kill lines by pattern and posts richer
  ones; a test pins the announcer's wording so a format change can't silently double messages.

### Known issues

- **Browser screenshot timing:** `make garage-web-smoke`'s `web-garage-fight.png` shows the frame before the
  skirmish camera applies (SwiftShader renders ~1 frame in the 3 s wait; a 2 s timer never fired). The logged
  start pose (`SKIRMISH_CAMERA focus=(0, 78) zoom=0.47`) is correct and the same flow natively frames the army.
- **Pending drill is still global,** not per squad (round 1 gap): Bound on Alpha then selecting Bravo keeps
  Bound as the next order. The info line always says what the next tap does.
- **The center meter** is thin and small on phones; art may want to style it.
- **`tests/run_tests.gd` skips a test file that fails to parse** (prints `0 passed, 0 failed` for a filtered
  run). `make lint` catches it first in `make check`, but a filtered `make test` alone can look green. Shared
  file: flagged here rather than changed.
- Chip state text shrinks to 8 px for a long squad name on the narrowest phones.

### Next steps

- Per-unit orders on the unit card once ai agrees to a `unit` field in SquadCommand (C7).
- Per-squad pending drill; a "last order" recall on the chip.
- After checkpoint 1 (catalog v2): check the icons against the new roles and the scout's fixed gun (a
  firing-arc wedge on the unit card would teach fixed mounts).
- A settings home for UI scale and a colorblind palette (army or art).

### Merge note (for the orchestrator)

- **What changed:** tap-only commanding (finger = mouse), radar tap orders, squad bar, 3D selection rings,
  formation/drill icons and picker, order-following camera (`RtsCamera.frame/track/order_pose`,
  `tracking_ended`), readable start zoom and far icons, filtered HUD messages, unit card, chip quick
  commands, shape-coded friend/foe, `--ui-scale`, `--zoom`, `--command-playtest`.
- **New files:** `game/ui/{command_icons,icon_button,squad_chip,selection_markers,hud_messages,command_playtest}.gd`,
  `mk/command.mk`, `tests/test_command_{grammar,squad_bar,icons,camera,readability,messages}.gd`.
- **Edits outside `game/ui`, `game/camera`, `game/modes/skirmish_mode.gd`:** `_agents/orientation.md`
  (common-tasks row), `_agents/verification.md` (command playtest paragraph). No shared code files touched;
  `mk/command.mk` is picked up by the root Makefile's `include mk/*.mk`.
- **Contract C7:** `TacticalMap.squad_selected(squad_key)` and `RtsCamera.frame(points)` added as specified;
  `RtsCamera.follow(target)` and `focus_on(point)` still exist. `Hud.post_message` usage unchanged.
- **Proposed doc edits (orchestrator-owned):** HANDOFF "Play it" can say "tap a squad, tap the ground or the
  radar"; roadmap: mark round-2 command outcomes done.
- **New console marker:** `SKIRMISH_CAMERA focus=(x, z) zoom=z vehicles=n` (skirmish start pose), plus
  `COMMAND_PLAYTEST {json}` / `COMMAND_PLAYTEST_DONE ok=…` from `--command-playtest`. `game/main.gd`'s marker
  list is a shared file, so they're listed here and in `tactical_map.md` instead.
- **Playtest:** see "What to playtest" above.

