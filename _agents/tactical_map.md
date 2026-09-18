# Controls: StarCraft-style, desktop first (v5, round 4)

> **The current controls are v5 below** (control stream, round 4, 2026-09-16): round 3's v4 grammar, plus a camera
> that frames what your force can see, elements that run doctrine when you give them tasks, and a HUD that survives
> 30 units a side. Everything after "History" (v1–v3: squad grammar, drills, the mobile tap map) is kept for
> reference; v3 still runs behind `--touch-map`. Design: [game_design.md](game_design.md) *Controlling units* and
> *Round 4 direction*; brief: [streams/archive/round4/control.md](streams/archive/round4/control.md).

## v6 (round 6, control): the card earns every button, the camera comes down

| Round 6 | What it means at the keyboard |
|---|---|
| **No Move or Follow buttons** | The lead: *"buttons like move and follow are already accessible via mouse click, so we shouldn't have buttons for them."* Right-click does both; **M** and **F** still work. |
| **Symbols, not words** | Every card button's primary read is its tactical task graphic (after APP-6 / MIL-STD-2525 / FM 1-02.2), with its doctrinal name under it and a one-sentence tooltip on hover. Support-by-fire is called **Support by Fire**, not "Base of fire". |
| **Loading shows itself** | FIGHT puts a loading screen on the tree root (`LoadingScreen`): the matchup, the arena and what it is for, a card teaching one command-card task by its symbol, and a bar naming the stage (scene, venue + navmesh, armies, first frame). The arena build and navmesh bake stay synchronous (trip-up 57); the screen names the stage and stays drawn through it. Every load prints `LOAD_TIMING total_ms=… scene=… arena=… armies=… first_frame=…`. |
| **Squad chips say what they're doing** | Each group chip over the panel reads IDLE (yellow: the one to find), MOVING, CONTACT or UNDER FIRE (ElementAwareness). |
| **Orders you can see landing** | nav's N1 `Movement.state`: a vehicle that is YIELDING or BLOCKED says so over its hull, and its card says "Blocked by Tank" or "Arrives in 4 s" (`MovementReadout`; silent until nav's CP1 is on `main`). |
| **Pitch is its own axis** | Zoom sets only the distance. **Page Up / Page Down** or **ctrl+wheel** tilt (8°-50°), **Home** resets it. Round 5 tilted from 25° to 82° as you zoomed out, so seeing your army cost you a top-down view. **O** is the deliberate top-down overview (77°) and back. **The default is the lead's pick, taken twice at the floor of what he was offered**: 25° of 25/35/45/60, then **12° · 50 m · FOV 60°** of 12/16/20/25. "Between StarCraft 2 and Twisted Metal" sits much nearer Twisted Metal than assumed; don't correct it upward for an easier tactical read. The floor is 8°, a little below his default, not at it: below 8° the frame is mostly horizon. |
| **A soft floor only far out** | Past 70 m a very low tilt is lifted, up to 40° at full zoom-out (`RtsCamera.tilt_at`): at 12° and ~150 m the arena was a strip between sky and cut-away stands, units specks. Up to 70 m, including his 50 m, the tilt is exactly his. Not round 5's weld: it engages only far out and stops well short of top-down. |
| **The wall cutaway** | At a low camera a squad near a wall (every spawn) is framed from a camera past the wall, among or behind the stands; the camera's near plane then sits just past the wall's top edge, so the stands and the wall between it and the arena aren't drawn (`RtsCamera.cutaway_near`). It cuts only when the stands would hide something: always when the camera is among the seats, and from beyond their back only when the sight line to a vehicle inside the wall passes through the stands' measured profile; otherwise the stands and crowd stay as foreground. Over the arena nothing changes. Chosen over raising the pitch near walls, which would bring back the top-down view exactly where every match starts. |
| **Why did it do that** | Hover the doctrine line on the card: the selected element's last six decisions with the match time ("0:47  line, react to contact — contact ahead"; `ElementLog`). |

## Task palette (N4)

The command card's vocabulary. The code is `game/control/task_palette.gd` (`TaskPalette.ROWS`); the symbols are
`CommandIcons.draw_task`; `tests/test_control_panel.gd` fails if a row here goes missing. **A verb the mouse already
expresses gets no button** (move, follow, attack). **A task gets a button only once squad has demonstrated its
behaviour** (the *On the card* column); the others have their symbol drawn and waiting.

| Verb | Symbol (tactical task graphic) | Key | Tooltip (what the player reads) | The behaviour the player is entitled to see | On the card |
|---|---|---|---|---|---|
| `stop` | a stop square | S | Drop every order and stand still. They still shoot back. | Every selected unit's order and queue cleared; a squad's leader stands down | yes |
| `hold` | a line held from behind | H | Stay on this ground and fight from it. Nobody chases. | Units stop and fight from where they are; nobody leaves to chase | yes |
| `attack_move` | an arrow ending in crosshairs | A | Click a spot: go there, fighting anything met on the way. | The group moves to the spot, engaging what it meets; a whole squad does it as a move task with react-to-contact | yes |
| `screen` | the security line, arrows outward, broken by **S** | E | Click a spot: spread into a line across it, watch, and fight only what comes to you. | A line across the point, facing out, observing; fights only what comes to it (squad X5 proves it) | yes (earned: squad `df736a8e`) |
| `support_by_fire` | a base line with two arrows converging on the target, feet at its ends | R | Click a target area: take firing positions facing it, suppress it, and don't advance. | Firing positions in a line at a standoff, interlocking sectors, facing the point, suppressing, not advancing (squad X5: *"the units definitely did not form up"*) | yes (earned: squad `df736a8e`) |
| `ambush` | a curved line with three arrows into the kill zone | B (planned) | Click a kill zone: hide in a line facing it and hold fire until the enemy is in it, or they are found. | A line at 0.6 × effective range facing the kill zone; crews hold fire until an enemy is in it, one is on top of them, or they're hit (squad `a8048028`) | not yet: waits on squad's check and CP3 |
| `attack_by_fire` | one arrow from a short base line with feet | - | Click a target: destroy it with fire from a distance, without closing. | Destroys the target from a standoff without closing | no: not a verb yet |
| `guard` | the security line broken by **G** | - | Click a flank: protect the army there, fighting to stop anything getting through. | Holds a flank and fights to stop penetration | no: not a verb yet |
| `cover` | the security line broken by **C** | - | Click a spot ahead: operate out in front of the army, buying it time and space. | Operates forward of the army, independently | no: not a verb yet |
| `fix` | a zig-zag arrow and **F** | - | Click an enemy: pin it where it is so the rest of the army can hit it. | Suppresses an enemy so it cannot move | no: not a verb yet |
| `block` | a T across the route and **B** | - | Click a route: deny the enemy passage along it. | Holds a route closed | no: not a verb yet |
| `formation` | the formation's real shape | G | Choose the shape the next orders move in. Auto lets each squad pick. | The next orders move in that shape (an explicit one overrides doctrine) | yes |
| `move`, `follow`, `attack` | - | M, F, - | - | right-click the ground, a friend, an enemy | never: the mouse's |

## v5: what changed from v4

| Round 4 | What it means at the keyboard |
|---|---|
| **The camera is framed by vision (L4)** | It keeps the element you are commanding framed as close as it can, and you cannot scroll out past what your whole force can see. Tab shows your force's horizon, not the arena. Manual pan/zoom always wins and hands back after 2.5 s; free panning stays over ground the team can see. `--no-vision-camera` opts out. |
| **The rest of your force is on the screen edge** | Chips for every element you aren't watching (name, survivors, strength, state); click one to go there. One alert prompt above the group chips, **Q** jumps to it. |
| **The radar is the map** | Facing ticks on friendly blips, element numbers, the selected element ringed, last-known contacts fading. Click looks, right-click orders. |
| **Tasks, not geometry (L1)** | With a whole element selected, orders become tasks its leader carries out - it picks the formation, the movement technique and the drills. **E** screens a flank, **R** sets a base of fire. The card reads back what it chose. An ad-hoc handful of units still gets direct orders, and any direct order dissolves the element. |
| **Scale** | Portraits group by type above ten units, with one strength number. **ctrl+A** takes the whole army, **F2** goes to the next idle element. |
| **Readability** | A hull bar over vehicles that are hurt or selected, sized from the hull on screen. |
| **Factions** | `--player-faction=` / `--enemy-faction=`, or a menu on an interactive `make skirmish`. Army size falls out of the faction's costs. |
| **Spectating** | `--cinematic`: the camera finds the fighting, holds a shot, and cuts. |

## v4→v5: the grammar

| Do | Mouse and keys |
|---|---|
| **Select** | left-click a unit · drag a box · shift-click or shift-box adds (shift-click a selected unit drops it) · double-click or ctrl-click: every unit of that type on screen · Escape clears · click an enemy to inspect it (panel card, never commanded) |
| **Order** | right-click the ground = **move** · right-click an enemy = **attack** · right-click a friend = **follow** · **A** then click = attack-move (click an enemy = attack) · **F** then click a friend = follow · **M** then click = move · **S** stop · **H** hold position · **shift** queues any order and keeps A/F/M armed for the next click · right-click or Escape cancels an armed order |
| **Tasks** (round 4) | with a **whole element** selected (a control group, or a doctrine squad) the orders above become L1 **tasks** its leader carries out: right-click ground or **M** = move, right-click an enemy or **A** = attack (A also maps to a move task: an element on the move already reacts to contact), **H** = hold, **E** then click = screen that flank, **R** then click = support by fire. **S** takes the wheel back. The command card reads back the formation, technique and drill the leader chose. |
| **Formation** | automatic (see below) · **G** cycles wedge, line, column, vee, back to auto for the next orders. An explicit formation is an override: that order goes out as geometry instead of a task. |
| **Groups** | **ctrl+1–9** saves the selection · **shift+1–9** adds to a group · **1–9** selects (a quick second tap centers the camera) · **Tab** next group · doctrine squads start as groups 1–5 · the group bar (bottom center) shows each group; click a chip to select it |
| **Camera** | screen edges, arrows, middle-drag pan · wheel zoom · `,` `.` rotate · **Page Up/Down** or ctrl+wheel tilt, **Home** resets it, **O** overview (round 6) · **C** centers on the selection · radar: left-click or drag looks, right-click moves the selection there, A then a radar click attack-moves there |
| **Panel** | portraits (hull and shield) for a group: click selects one, shift-click drops it, ctrl-click keeps its type · a card for one unit or an inspected enemy · the command card (round 6: the task palette above - Stop S, Hold H, Attack-move A, Screen E, Support by Fire R, Formation G; symbols with names under them, a tooltip on hover) |
| **Awareness** (round 4) | elements you aren't watching sit on the screen edge: click a chip to select that element and go to it · **Q** jumps to the newest alert ("Bravo under fire", "Alpha contact north"), rate-limited to one per element per kind |
| **Scale** (round 4) | **ctrl+A** selects the whole army · **F2** goes to the next element with nothing to do · above ten selected units the panel's portraits group by type with a count and one strength number |
| **Quality of life** | right-click an enemy with a mixed selection: only units whose guns hurt it (≥ 25% through its side armor) attack, the rest escort the nearest attacker (a whole element gets an attack task instead, and its leader works that out) · **F1** selects idle units · rest the mouse on any unit for its stats (hull, shield, weapon, range, speed, strong and weak against) |
| **Time** | Space pauses (orders still land); skirmish starts in a planning pause |

**Feedback:** a thin hull bar over our vehicles that are hurt or selected (fading towards the enemy color as the
hull gets serious, with a shield sliver above it), bright rings under selected units (an inspected enemy's ring is bright red), a ground ring that shrinks
onto every ordered spot (team color = move, red = attack, gold = attack-move), dashed waypoint lines from each selected
unit through its current and queued stops, a crosshair cursor and a hint while an order is armed, and a HUD line per
order ("3 units: attack-move"). Sounds are feel's.

## v4: how orders work (K1)

```
mouse/keys ─▶ RtsControls ─▶ UnitCommand {units, verb, to?, target?, queue, formation?, source?, facing?}
                                  │ Orders.issue(command, team)       (game/control/orders.gd, one per match)
                                  ▼
             per-unit order: group, slot, goal, heading, pace ──▶ order_changed(unit)
                                  │
                   brains execute it (ai X1)  ·  until then OrderExecutor (game/control/order_executor.gd)
```

- **The response guarantee:** a unit steers toward a new order within **100 ms** of the input (`Orders.RESPONSE_MS`; round 5
  restated it in wall-clock time ahead of the 30 Hz tick, where it is exactly 3 ticks), whatever it was doing. Measured: 1 tick
  from fighting, driving elsewhere, holding, and hurt (`tests/test_control_response.gd`, `make control-playtest`).
- **Automatic formations** (`GroupFormation`): heavies in front, fragile and artillery behind; a wedge for up to five
  units, rows beyond; a line when holding; a group of only fast units (≥ 12 m/s) attack-moving spreads into a wide
  wedge. Slots are centered on the click and face the direction of travel; units keep their left-right order so
  paths don't cross. Named formations come from `Formations.offsets` (ai's geometry).
- **Arriving together:** each unit paces itself so its group arrives at once (`Orders.pace_factor`: the slowest
  member's time to arrive sets everyone's speed, never below 35%; a laggard drives flat out).
- **Regrouping:** when a unit's orders run out it keeps a **station** (`Orders.station`: its slot in its group,
  facing the group's heading, or the order's `facing` when it gave one). Pushed or drawn away, it drives back; a unit
  given its own order gets its own station.
- **Facing (round 5, for doctrine's halts):** `move`, `attack_move` and `hold` take an optional `facing: [x, z]`. The
  group still travels and forms its slots toward `to`; the facing is where each unit looks once there (`order.facing`,
  normalised, and the station's `heading`). Turning to it is the brain's job (ai).
- **Stop** clears the queue and halts; **hold** stays on the spot but turns and shoots; **attack-move** halts to
  fight what it meets, then carries on; **follow** keeps a slot behind the target; **attack** closes to 80% of the
  weapon's range and completes when the target dies.
- **Temporary executor:** until brains execute orders (ai X1), an ordered unit's brain is paused and a plain
  `OrderController` drives it (pathing, unsticking, fire at will). Never-ordered units keep their brains. The executor
  steps aside when `TankBrain` declares `const EXECUTES_ORDERS := true`.

## v4: files, tests, playtest

| Piece | File |
|---|---|
| Command data and validation | `game/control/unit_command.gd` |
| Orders per match (K1) | `game/control/orders.gd` (`Orders.of(match)`) |
| Automatic formation slots, pacing | `game/control/group_formation.gd` |
| Temporary order executor | `game/control/order_executor.gd` |
| Selection, control groups | `game/control/selection.gd`, `game/control/control_groups.gd` |
| Mouse and keyboard | `game/control/rts_controls.gd` (node named `TacticalMap` in skirmish, for the HUD skin) |
| Panel, group bar, rings, radar | `game/ui/selection_panel.gd`, `game/ui/group_bar.gd`, `game/ui/selection_markers.gd`, `game/ui/radar.gd` |
| Vision region and the camera (L4) | `game/control/vision_region.gd`, `game/camera/rts_camera.gd` (`vision`, `horizon_zoom`, `Track.VISION`) |
| Element state and alerts (X2) | `game/control/element_awareness.gd`, `game/ui/edge_markers.gd` |
| Faction pick (L3) | `game/ui/faction_picker.gd` |
| Self-directing camera | `game/camera/cinematic_camera.gd` |
| Scripted playtest | `game/control/control_playtest.gd` |

- Tests: `tests/test_control_{orders,response,selection,commands,groups,group_moves,panel,stretch}.gd` and round 4's
  `tests/test_control_{vision_camera,awareness,tasks,scale,faction_pick,readability,cinematic}.gd` (real mouse and key
  events through `Viewport.push_input`; shared setup in `tests/support/control_fixture.gd`, which also builds a
  30-a-side match with `build_scale`).
- `make control-playtest` (headless): box select, attack-move across the arena, a queued route, a group swap, a
  pushed unit rejoining; every order's response tick in `build/control-playtest/headless/orders.jsonl`.
- `make control-playtest-shots` (a display; `make remote T=control-playtest-shots` uses builder0's): the same session
  at 1920×1080 and 1280×720, frames in `build/control-playtest/<size>/`.
- `make control-scale-shots` (a display): the same session with ~30 a side. Deliberately not pass/fail - with a
  faction-sized army nobody is commanding, the player's force loses. `make cinematic-shots` for the spectator camera,
  `make faction-menu-shot` for the faction menu.
- Launch flags (skirmish): the center control point is on by default (`--no-control` turns it off; combat X7 measured
  a 92 s median match with it), `--touch-map` (round 2's tap grammar), `--control-playtest=DIR`, `--scripted` (the
  desktop script: group 1 attack-moves, group 2 moves with a queued leg). Round 4 adds `--no-vision-camera`,
  `--no-elements`, `--element-cpu`, `--player-faction=` / `--enemy-faction=`, `--pick-faction` / `--no-pick-faction`,
  and `--cinematic`.
- **Measured at 30 a side** (60 units, 30 selected): box-select 1.38 ms, right-click → 30 orders 1.87 ms, control's
  per-frame work 1.685 ms. `tests/test_control_scale.gd` holds these to a budget.

## History: v1–v3 (the squad grammar and the mobile tap map)

> **Status: v1 implemented (2026-09-13); v2 (2026-09-15, stream/gameplay): RTS 3D camera, radar, fog of
> war, touch-first controls. See "v2" at the end.** Play it: `make skirmish` (desktop) or `make serve-web` → `http://localhost:8060/?skirmish` (browser, no server). Builds on
> [tank_brain.md](tank_brain.md) (autonomous brains + directives) and answers its
> "Squad command UI" open question.

## The lead's brief

> "I want the tactical map. The challenge here is really a UX standpoint, where I want
> to essentially give the player a lot of hidden control and power without an
> overwhelming set of inputs. There's also a simple concept where a tank is elected as
> a commander, and from there it would be easy to control the squad to take an action
> relative to the command (i.e. … Army-standard tank formations and battle drills); if
> we elected a tank the commander then things like V formations could be formed up
> relative to the commander."

## UX principle: three kinds of input, everything else is implied

| Input | Gesture (mouse / keys; touch later) | Answers |
|---|---|---|
| **Who** | Click a tank (selects its squad) or press `1`–`4`. Click a tank in the already-selected squad to **make it commander** | Which squad, and who leads it |
| **Where / which way** | **Right-drag** on the map: press = destination, drag direction = facing on arrival (a short drag faces the direction of travel). A ghost of the formation follows the cursor | The spot and the orientation |
| **How** | One **drill** chip (`Q` Move · `W` Bound · `E` Hold · `R` Assault · `T` Break contact) and one **formation** chip (`Z` Column · `X` Wedge · `C` Vee · `V` Line · `B` Echelon · `N` Coil) | The battle drill and the shape |

A complete order is at most **one click + one drag + one chip**. The "hidden power" is
everything that gesture expands into, none of which the player touches:

```
Right-drag with "Bound" + "Wedge" selected
  → SquadCommand {squad, verb: bound, to, facing, formation: wedge}   (structured data, validated)
    → Squad: elects/keeps a commander, splits the squad into two elements, runs the bound cycle
      → per-tank DIRECTIVE MODIFIERS + formation SLOT targets
        → autonomous TankBrains still score options (a hurt tank still retreats, a tank
          in contact still fights) inside the drill's weights
          → orders → TankCommand
```

The same `SquadCommand` data can come from the map, a CPU commander, the agent
bridge (Claude commanding squads), or later an LLM or a network client.

## The commander

- Every squad has one **commander**. Formations are laid out **relative to the commander's position and heading**, so moving the commander moves the formation.
- **Election:** the player clicks a tank in the selected squad. By default, the first tank in the squad's roster leads.
- **Succession:** when the commander is destroyed, the next surviving tank in the roster takes command immediately, and an event appears ("Alpha: commander down, Green_Alpha_2 takes command"). The formation re-forms around the new leader. **Decapitation becomes a tactic**: a disrupted squad loses cohesion for a moment.
- The commander paces the squad: it slows down while followers are far out of their slots.

## Formations (after US Army tank platoon doctrine)

Roughly following the formations taught for tank platoons (ATP 3-20.15), adapted
to 2–5 tanks per squad. Offsets are in the commander's frame (right, back), in
units of `spacing` (default 12 m):

| Formation | Shape | Use it for | Trade-off |
|---|---|---|---|
| **Column** | single file behind the leader | moving fast through a lane between obstacles | only the leader can shoot forward; flanks exposed |
| **Wedge** (Λ) | leader at the point, others staggered back left and right | movement to contact; the default | good all-round firepower and control |
| **Vee** (V) | leader at the base, the others forward on both flanks | pushing into a known threat with firepower forward | leader protected; the flanks take contact first |
| **Line** | abreast of the leader | maximum firepower forward; assaults | weak flanks, hard to control, no depth |
| **Echelon** (right or left) | a diagonal behind the leader to one side | protecting one flank (e.g. along a wall) | the other flank is blind |
| **Coil** | a ring facing outward around the destination | halting; all-round security | no movement |

## Drills (after battle drills and movement techniques)

| Drill | What the squad does | Contact behavior |
|---|---|---|
| **Move** (traveling) | all tanks move together in formation toward the destination | return fire while moving; formation is kept unless a tank is hurt |
| **Bound** (bounding overwatch) | two elements leapfrog: one halts and covers (overwatch) while the other moves up ~25 m, then they swap | the overwatch element engages anything in sight; the bounding element keeps moving |
| **Hold** | halt in formation at the destination, facing the drag direction | engage from position; leashed to slots |
| **Assault** | drive at the destination; formation loosens into individual fights | aggression up; brains hunt |
| **Break contact** | withdraw toward the destination (default: own base), backing away with the front armor toward the threat | fire while withdrawing |

## Fog of war on the map

The map shows your tanks exactly, but enemies only as your team's **intel**:
visible contacts solid, remembered ones fading with age. The shared vision that
makes scouting matter to the brains is also what the player sees.

## Architecture

| Piece | File | Notes |
|---|---|---|
| Formation geometry (pure) | `game/ai/formations.gd` | slot offsets, heading rotation, world slots; unit tested |
| Squad runtime + commands | `game/ai/squad.gd` | roster, commander, succession, drill state (bound cycle), `SquadCommand` validation |
| Brain integration | `game/ai/tank_brain.gd` | new option `KEEP_SLOT`; drill → directive modifiers; the commander's pacing |
| Map UI | `game/ui/tactical_map.gd` | overlay `Control` drawn over a top-down camera; emits SquadCommands |
| Skirmish mode | `--skirmish` / `?skirmish` / `make skirmish` | single player commands Green squads vs a CPU doctrine; works in the browser with no server |

## Verification plan

- Unit: formation shapes and rotation; election and succession; command validation; the bound cycle.
- Integration (real physics): a wedge ordered 60 m forward arrives with tanks near their slots; hold halts and faces; break contact withdraws in reverse.
- UI logic without rendering: synthetic mouse and key events into `TacticalMap` produce the expected SquadCommands.
- Visual: screenshots of the skirmish map (selection, ghost formation, fog-of-war contacts).

## v1 as built (2026-09-13)

- **Skirmish mode** (`--skirmish`, `?skirmish`, `make skirmish ENEMY=individuals|anvil_hammer|flame_rush`): you command Green's squads from `doctrines/player_default.json` (Alpha: 3 cannons in a wedge; Bravo: 2 in a line, both holding) against a CPU doctrine. First to 10 kills; VICTORY/DEFEAT banner.
- **Map drawing:** friendly tanks as circles with hull ticks; the commander marked by a gold diamond; the selected squad ringed, with each tank's brain intent under it; destination line, ghost slots, arrival-facing arrow; a live gold ghost formation while right-dragging; enemies only from team intel (solid = in sight, hollow and fading = remembered). 3D enemy tanks outside your team's sight are hidden, and 3D nameplates are hidden on the map.
- **Panels:** the drill and formation bar (clickable, lit when active, keyboard shortcuts on the labels); a squad readout (`*` = commander, health per tank); a hint line; an event log (orders, bounds, "commander down, X takes command").
- **Tab** switches to a 3D view behind the selected squad's commander and back.

### Verified

- 10 squad tests: formation geometry, validation, election/succession, move-in-wedge arrival, hold facing, break contact in reverse, bounding overwatch leapfrogging 54 m.
- 5 map tests driving `_gui_input` / `_unhandled_key_input` with synthetic events: screen↔world mapping, squad keys, formation keys (incl. echelon flip), a right-drag producing destination + facing + pending drill, click-twice election, E = hold here.
- Screenshots of a scripted skirmish (bound + echelon orders, a live drag preview, commander succession in the log) and of the browser build at `?skirmish`.

### Known gaps / next

- **Multiplayer squad command:** today skirmish is single-player; a networked client would send SquadCommands to the server (same data, validated there).
- **Claude as the opposing commander:** give the agent bridge a `/squad` endpoint; the enemy becomes a thinking commander instead of a static doctrine.
- **Touch/phone:** tap = select, long-press-drag = where, bottom chips = how (the input model already maps 1:1).
- Formation slots don't yet avoid obstacles (a wedge along a wall clamps to the arena edge; slots inside crates rely on navmesh closest-point).
- Pending drill is global, not per squad.

## Iteration 2 (2026-09-13): the lead's first skirmish

> "the game is a little bit unplayable at the moment. First off, tanks should not re-spawn,
> this should be a squad vs squad match. Second, it should not be easy for our tanks to die…
> I haven't been able to successfully use the commander and formations feature (maybe because
> the tanks die too quickly)"

**Diagnosis with measurements** (5v5 CPU matches, first-kill and first-shot timing):

| Change | First shot | First kill | Why |
|---|---|---|---|
| Before (small map, 100 HP, 110 m guns, respawns) | **0 s** | 14 s | Bases were 84 m apart with a clear sightline: both teams fired from spawn. There was no maneuver phase at all, so formations had no time to matter |
| 400 HP, 70 m cannon, 75 m sensors | 1 s | 29 s | Tougher, but still immediate contact: both sides close 84 m in a second |
| **Arena doubled** (240 m, bases 180 m apart) + the above | **7–8 s** | **~32 s** | A real approach phase; a fight takes ~25 s to claim a tank |

**What changed:**
- **Squad vs squad elimination** in skirmish (`Match.elimination`): no respawns; the last team standing wins (VICTORY/DEFEAT). Time-limited elimination matches are decided by tanks alive, then total health. The runner has `--elimination`; the network server and `make run` keep respawns.
- **Tougher tanks and slower killing:** 400 HP (was 100), cannon reload 2.5 s (was 2.0), cannon range 70 m (was 110), sensor 75 m (was 90), and **shot spread** 0.8° σ that grows ×2.5 at full speed, so halting to shoot (Hold, overwatch) is rewarded. The spread RNG is seeded, so matches stay deterministic.
- **Arena doubled** to 240×240 m with 4.5 m crates, 18 m walls, and three extra mirrored cover pairs; all size constants now live in `Match` (`ARENA_HALF_SIZE`, `DRIVABLE_LIMIT`, `BASE_Z`).
- **Tactical pause:** skirmish starts in a PLANNING pause; **Space** pauses and resumes anytime. Orders work while paused; the map processes with `PROCESS_MODE_ALWAYS`.
- **Hurt tanks stop yo-yoing:** a tank below its retreat threshold no longer advances blindly (without repairs, it bounced between base and enemy forever and matches stalemated).
- **Input discoverability:** **left-drag on open ground** also orders (right-drag still works; a left press on a tank selects; a plain left click on the ground does nothing). A **toast** confirms every order ("Alpha: Bound in Wedge") or explains a rejection.

**Were clicks broken?** A new test drives the map through Godot's real input pipeline
(`Viewport.push_input`). It first "failed", but only because **headless Godot's root
viewport is 64×64**, so the pushed clicks landed off-map. In a real window the same click
reaches the map. With a 1280×720 test viewport, keys, clicks, commander election, drags,
and pausing all pass end to end. Conclusion: the lead's trouble was the pace and
discoverability, not dropped input.


## v2 (2026-09-15): 3D camera, radar, fog, touch

| Input | Mouse / keys | Touch |
|---|---|---|
| Who | click a tank (again: commander), 1–3, squad chips | tap a tank (again: commander), squad chips |
| Where | left- or right-drag on the ground (press = spot, drag = facing), radar drag | tap ground (go), hold 0.35 s then drag (go + face), radar drag |
| How | Q–T drills, Z–N formations, or the buttons | buttons (drills; Formation opens the formation row) |
| Camera | arrows / screen edge / middle-drag pan, wheel zoom, `,` `.` rotate, F follow, Tab overview, radar tap | drag pan, pinch zoom, twist rotate, radar tap, Follow / Overview buttons (tap the selected squad's chip to follow) |
| Time | Space | Pause / Resume button |

- The camera is `RtsCamera` (a controller for the main camera); the map works in perspective because every
  interaction is a ground raycast. Without a rig (tests) the old flat top-down view remains.
- Fog of war: `VisibilityField` (team vision grid) drawn in 3D by the `fx.fog_of_war` slot and on the radar;
  enemies are drawn only from intel. Nameplates never show brain intents in skirmish.
- The radar (`Radar`) is an input too: tap = look there, drag = order.


## v3 (round 2, command stream): one-tap grammar, squad bar, icons, camera that follows orders

| Input | Finger **and** left mouse button (identical) | Desktop extras |
|---|---|---|
| Who | tap a squad chip, or any unit of the squad (again on a unit of the selected squad: commander) | 1–5 |
| Where | tap the ground **or the radar**; hold 0.35 s then drag = go + face | right-drag = go + face |
| How | drill buttons (icons); Formation opens the picker (cards drawn from `Formations.offsets`) | Q–T, Z–N |
| Camera | drag = pan; pinch = zoom; twist = rotate; radar drag or long press = look; second tap on the selected chip = center on the squad; Follow = toggle "follow selected" | wheel, middle-drag, arrows, `,` `.`, F, Tab |
| Time | Pause / Resume | Space |

- **Radar:** a tap orders the selected squad there (the lead's request); a drag or a resting press looks.
- **Squad bar** (`game/ui/squad_chip.gd`): name, order state (Moving / Holding / Arrived / Destroyed…), one
  pictogram per vehicle (lost ones crossed out), hull and shield bars, a red pip when in contact.
- **World marks** (`game/ui/selection_markers.gd`): 3D ground rings, depth-tested: the selected squad bright
  (commander gold), other friendlies faint, enemies in sight faint red. Close up the map draws no 2D markers.
- **Icons** (`game/ui/command_icons.gd`): unit roles, drills, and formations as CanvasItem drawings; formation
  icons come from the real geometry (a test checks the uniform scaling), with plain-language names, taglines,
  and one-line descriptions. The info line above the order bar says what the next tap will do.
- **Camera follows orders** (`RtsCamera.frame/track/order_pose`, C7): after an order whose squad or destination
  is off screen, the camera frames the squad and its destination (or, when that would need more than zoom 0.48,
  the squad with the view leaning toward the destination) and tracks them, gently and speed-limited, until the
  squad arrives, the player touches the camera (pan, zoom, rotate, radar look), or another squad is selected. It
  never zooms in closer than the player had it. **Follow** is a toggle that tracks the selected squad and moves
  on with the selection.
- Signals: `TacticalMap.command_issued(command, error)`, `TacticalMap.squad_selected(squad_key)`,
  `RtsCamera.tracking_ended(reason)`.
- **Messages** (`game/ui/hud_messages.gd`): merged losses with unit types, squad destroyed, friendly-fire kills,
  rate-limited order acks, control-point warnings; a center score meter under the squad bar.
- **Readability:** the start camera frames the army (zoom ≥ 0.36); nameplates only when zoomed right in; close
  up = models, rings, and small health bars; zoom ≥ 0.5 = unit-type icons.
- Tests: `tests/test_command_*.gd` (grammar through real touch/mouse events, squad bar, icons, camera,
  readability, messages). Playtest: `make command-playtest` / `make command-playtest-shots`.
- Launch flags (skirmish): `--zoom=0..1` (start height), `--ui-scale=0.75..2`, `--command-playtest=DIR`.
  Console markers: `SKIRMISH_CAMERA`, `COMMAND_PLAYTEST`, `COMMAND_PLAYTEST_DONE`.
