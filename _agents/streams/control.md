# Stream: control (the squad UX earns every button; the camera comes down; loading shows itself)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*, *Controlling units*), [../workstreams.md](../workstreams.md) (you own **K1**, **L4**, **C7**
> and half of **N4**; you consume squad's **N2** and nav's **N1**), [../tactical_map.md](../tactical_map.md), and your
> round-5 report in [archive/round5/control.md](archive/round5/control.md).
>
> **You own** `game/control/`, `game/ui/` (HUD, widgets, title screen, the new loading screen), `game/camera/`,
> `game/controllers/`, `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md`.

## The lead's direction (2026-09-18, verbatim)

> *"For the controls on a squad level basis (the UX), we should definitely iron these out; I don't know what some of
> these buttons are (i.e. screen), and buttons like move and follow are already accessible via mouse click, so we
> shouldn't have buttons for them. I finally found the "support by fire button" (there's a standard military symbol
> for support by fire, we should ideally use these), and when I clicked it, the units definitely did not form up."*

> *"At the start of the game there's a big lag between pressing "Fight" and the game loading, so we should likely
> invest in some loading UX indicators and screens."*

> *"On the look and feel side, I think the bird's eye view is what's problematic on the camera. I think it should be
> more of a 3d perspective, possible just at an angle in general, and the lower camera angles look good because we
> actually get to see the vehicles. And remember, previous guidance from me is that we're trying to get somewhere in
> the middle between Starcraft 2 and Twisted Metal in terms of perspective (I know this is hard to figure out)."*

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

**The buttons.** `game/ui/selection_panel.gd:27-29` is the whole list, drawn as rectangles with a hotkey letter and a
*text* label — **there are no icons on the command card at all**:

| id | label drawn | key | mouse already does it? |
|---|---|---|---|
| `move` | "Move" | M | **yes** (right-click) |
| `stop` | "Stop" | S | no |
| `hold` | "Hold" | H | no |
| `screen` | "Screen" | E | no — and the lead couldn't tell what it was |
| `attack_move` | "Attack-move" | A | no |
| `follow` | "Follow" | F | **yes** (right-click a friendly) |
| `support_by_fire` | **"Base of fire"** | R | no |
| `formation` | "Formation: <current>" | G | no |

Note the label: **support-by-fire is on screen as "Base of fire"**, which is most of why he "finally found" it. The
touch map (`--touch-map`) already draws *real generated icons* through `CommandIcons.draw_drill()` /
`draw_formation()` — formation glyphs built from the actual `Formations.offsets` geometry — so the icon machinery
exists (`game/ui/{command_icons,icon_button,icon_raster}.gd`); the desktop card never got it. The only NATO-ish thing
in the game is a hostile diamond behind enemy icons (`tactical_map.gd:599`). No task graphics anywhere.

**The camera.** `game/camera/rts_camera.gd:179-185`:

```
distance = lerp(16, 260, level²)
pitch    = lerp(25°, 82°, level)
```

**Pitch is welded to zoom, and that is the lead's "bird's eye view".** `make skirmish` starts at zoom 0.36 → ~48 m out
at ~45°, which is not bad. But a player commanding 30 vehicles across a 242 m arena *zooms out*, and there is no way
to zoom out without tilting toward 82°: the two are the same slider. The L4 vision framing (`VISION_*` consts,
`_update_vision()` `:466-481`) moves along the same slider when it frames a commanded element. So he never chose a
bird's eye view — he chose to see his army, and the camera charged him a top-down for it. **Decoupling the two is the
fix; verify that diagnosis with screenshots at a few zoom levels before you act on it**, because the exact pose he was
looking at is an inference, not a measurement. (`toggle_overview()` at zoom 0.92 → 222 m, 77° is the deliberate
bird's eye, and on desktop it isn't even bound: Tab cycles control groups.)

**Loading.** Nothing is threaded — no `Thread`, no `WorkerThreadPool`, no `ResourceLoader.load_threaded_*` anywhere in
`game/`. FIGHT (`faction_picker.gd` → `GameLauncher.start`, `game/ui/game_launcher.gd:17-33`) does a synchronous
`load("res://game/main.tscn")`, then `Arena._ready()` builds obstacles, decor, hazards, the whole cyberpunk venue
(stands, crowd, gates, towers, screens, flood and wear maps) **and bakes the navmesh synchronously** — usually the
biggest single stall — then `SkirmishMode._start_match()` instantiates up to ~44 vehicles a side in one frame, then
the controls, radar, panels and markers. There is **no loading screen, no progress bar, no spinner**; the only text is
`hud.set_status("Pick a faction, then FIGHT")`. The one progress UI in the repo is Godot's stock web shell, which only
covers the wasm download.

## Backlog (in order)

**X1 — cut the buttons the mouse already does.** `move` and `follow` come off the command card (the lead, explicitly).
Keep their hotkeys if they cost nothing. The card is for what the mouse *cannot* express.

**X2 — the task palette and its military symbology (N4).** Build the table in `_agents/tactical_map.md`, one row per
task: verb · **APP-6 / MIL-STD-2525 tactical task graphic** · hotkey · one line of player-facing text · the behaviour
the player is entitled to see. Then draw the symbols on the card, the way the touch map already draws its icons —
extend `CommandIcons` rather than importing images, so they stay crisp and themeable. The graphics you need:
- **support by fire** — the two-pronged arrow with the base line;
- **screen** — the line with the semicircle/S;
- **attack by fire**, **guard**, **cover**, **fix**, **block** if squad can demonstrate them.
Name each button by its doctrinal name (**"Support by Fire", not "Base of fire"**), with the symbol as the primary
read and the words underneath, plus a hover/hold tooltip that says in one sentence what the units will do. The lead
could not name `screen`; the symbol plus one sentence is the fix. **A verb only gets a row when squad can demonstrate
its behaviour** — agree the final list with squad, and say in your Status which rows squad has earned.

**X3 — the camera comes down (the lead gate).** Decouple pitch from zoom. The recommendation to try first: a much
lower pitch range (roughly **22°–50°** instead of 25°–82°), pitch as its *own* axis the player can adjust, and a
default that sits low enough to see vehicles in profile. Then **put it in front of the lead rather than guessing**:
`make camera-looks` — the same moment of the same fight, captured at a grid of pitch × distance × FOV, as a page of
screenshots he can pick from. "Between StarCraft 2 and Twisted Metal" is not a number; a picture he points at is.
Send the orchestrator the page the day it exists (lesson 12). Keep the tactical read honest: he must still be able to
command, and `toggle_overview()` stays as the deliberate top-down for reading the map (and bind it on desktop).

**X4 — loading that shows itself.** A real loading screen between FIGHT and the match:
- **Stage it.** Split the work into named stages (arena layout → venue → navmesh bake → armies → units → controls)
  with a progress signal, and yield a frame between stages so the screen can actually draw. `ResourceLoader`'s
  threaded load for the scene, and `bake_navigation_mesh(true)` for the navmesh, are the two obvious wins — coordinate
  the bake with arena and nav, since navigation determinism is pinned synchronous in `project.godot:53` for a reason
  (trip-up 57: async iterations made the same seed simulate differently). **Do not change that setting to make a
  progress bar look nicer.**
- **Give it the game's voice**, not a grey bar: faction art, the matchup, the arena name, a doctrine card or a fact,
  and let feel put an announcer sting or crowd bed under it. Coordinate with feel for the art slots.
- Measure it: report FIGHT→playable wall-clock before and after, on this laptop, at 30 a side.

**X5 — orders you can see landing.** The lead's round-5 note was that units feel unresponsive; nav now reports
`Movement.state(unit)` with `blocked_by` and an ETA (N1). Surface it: a unit that is *yielding* or *blocked* should say
so on the HUD rather than looking idle, order markers should show the formation slots squad computes (N2), and the
100 ms K1 response guarantee stays asserted in milliseconds. A unit that acknowledges instantly feels responsive even
when it takes a second to move.

**X6 — the selection grammar for squads.** The lead thinks in squads; make selecting one, keeping it, and ordering it
frictionless: control groups that survive an order (coordinate with squad's X4 — a plain move to a whole element must
no longer dissolve it), a clear read of which element is selected and what it is doing, and idle-element cues.

**X7 (stretch) — the three round-4 dials** (frame distance, one alert line or three, faction menu open by default) and
the "why did my element do that" view, if the camera and loading work lands early.

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `make command-playtest`, `make command-playtest-shots`, `make control-playtest`,
  `make remote T=control-playtest-shots` — and **look at the frames**.
- `make camera-looks` (yours to build) for the lead gate.
- **Play it** (`make skirmish`) and do what the lead did: press every button on the card and ask whether you could
  name it without reading the code.
- Windowed playtests open on the lead's desktop and a stray click becomes a real order (trip-up 32): prefer headless.
- You **must not** move the sim baseline (invariant 2). If order execution changes a doctrine match, say so and
  coordinate.

## Don't touch

`game/tactics/**` and the deciding half of `game/ai/` (squad's), nav's movement files, `game/units/` `game/combat/`
`game/match/` (combat's), `arenas/` `game/arena/` (arena's), `game/theme/**` (feel's).

## Waiting on the lead

1. ~~**The camera look**~~ — **answered 2026-09-18** on the camera page (https://claude.ai/artifact/6LEzbnaQc1T6oyVo2jmxaL,
   its database doc `picks/lead`, version 5, 15:53 UTC): **"pitch 25° · 50 m · FOV 60°"**, the lowest angle offered, no
   note. Applied: `RtsCamera.DEFAULT_PITCH_DEG = 25`, `FOV_DEG = 60`, `SkirmishMode.START_ZOOM = 0.373` (50 m). The
   player's tilt range stays 22°–50°.
2. **Which arena is fun** — the same page has a Fun box per arena (all seven, three frames each). Unticked so far.
3. ~~**Lower than 25°?**~~ **Answered 18:01 UTC: "pitch 12° · 50 m · FOV 60°"** (the follow-up page,
   https://claude.ai/artifact/GcEpxjxyaUcjCjrmdrH2q7, db `picks/lead`) — the floor again. Applied: default 12°, player
   range 8°–50°. Treat it as direction, not an experiment (game_design.md).

## Status

_Round 6, control stream. Started 2026-09-18 from `a975e262`._

**Report (2026-09-18, evening).** Green and sent to merge: **`aa7f3499`** (`make remote T=check` 1051 passed, 0 failed,
builder0); `9ef6bbee` on top is docs and a comment only. Merged to `main` earlier: `758a45a8`.
- **Done:** X1 (no Move/Follow buttons), X2 (the N4 palette with tactical task graphics; Support by Fire and Screen
  earned from squad's evidence), X3 (pitch its own axis; **the lead picked 12° · 50 m · FOV 60** on two camera pages,
  played and fixed: wall cutaway, far-range tilt floor), X4 (loading screen; FIGHT → playable 7.6 s → 1.4 s with
  feel's fix), X6 chips, X7 "why did my element do that".
- **Waiting on other streams:** X4-of-squad / X6 plain move keeps the squad a squad (held until squad's `4d734b1e` is on
  `main`; acceptance = `make squad-orders-test` at 0 idle commands); Ambush (`earned` flips when squad says green);
  X5 lights up when nav's N1 is on `main` (built against the shipped contract; check by play then).
- **Debt recorded:** touch needs its own framing (phone bar 24 → 22 px provisionally).

### Plan (order, with reasons)

1. **X1** cut Move and Follow off the card — smallest, and the lead named it. **Done** (keys M/F kept).
2. **X3** camera, pulled ahead of X2: it is the round's main lead gate, and the brief says to get the page in front of
   him early. Pitch decoupled from zoom first, then `make camera-looks` (the page) — the page's "round 5" row is also
   the check of the diagnosis the brief asked for before acting on it.
3. **X2** task palette + symbology: the table (`TaskPalette`), the graphics, the card. Screen and Support by Fire stay
   on the card pending squad's X5 proof; the other five doctrinal tasks have symbols drawn and wait off the card.
4. **X4** loading screen: staged load behind a screen on the root, timings printed, then measure before/after.
5. **X5** orders you can see landing — waits on nav's CP1 (`Movement.state`), not on `main` yet.
6. **X6** squad selection grammar — coordinates with squad's X4 (a plain move keeps the element).
7. **X7** stretch dials.

### Progress (2026-09-18)

| Item | State | Evidence |
|---|---|---|
| X1 no Move/Follow buttons | done | `test_control_panel` (card has neither; M and F still arm) |
| X3 pitch decoupled | done; **the lead's pick applied: 12° · 50 m · FOV 60** (his second pick, again the floor offered); wall cutaway; far-range soft floor | `test_rts_camera::test_tilt_is_its_own_axis`, `test_zoom_sets_the_distance_and_never_the_tilt`, `test_a_camera_past_the_wall_cuts_away_the_stands_between` |
| X3 camera pages | answered: https://claude.ai/artifact/6LEzbnaQc1T6oyVo2jmxaL; follow-up below 25°: https://claude.ai/artifact/GcEpxjxyaUcjCjrmdrH2q7 | `make camera-looks`; laptop render, 1920×1080, frames in the scratchpad (not committed: 26 MB of JPEG) |
| X2 palette + symbols | done; Screen / Support by Fire held off the card until squad's X5 | `TaskPalette`, `CommandIcons.draw_task`, table in `tactical_map.md` "Task palette (N4)", `test_control_panel` |
| X4 loading screen | done; FIGHT → playable 7.6 s → 1.4 s with feel's fix (below) | `LoadingScreen`, `GameLauncher.start` staged, `test_loading_screen`, shell-playtest `loading_screen_shows` + frame `2b_loading` |
| X5 orders you see landing | built against N1 with a fake provider; **lights up when nav's CP1 is on `main`** (wire `MovementReadout.from_movement` to the real call shape then) | `test_control_movement_readout` |
| X7 (stretch) "why did my element do that" | done: `ElementLog` keeps each element's last 6 decisions with match time; hover the card's doctrine line | `test_control_element_log` |
| X6 a plain move keeps the squad a squad | **HELD** (landed in `8d9c59af`, reverted before merge: see the next row). What stays: a direct order to part of a squad releases only those units, and re-selecting the group re-forms it | `test_control_commands::test_a_direct_order_to_part_of_an_element_releases_only_those_units` |
| X6 plain move, **played — why it is held** | Held by the orchestrator, 2026-09-18, until squad explains the re-issuing; do NOT re-add `"move"` to `ELEMENT_TASKS` without this A/B coming back at 0 idle commands on five squads (the lead's sequence, not a single-squad lab). Question to squad: in the lead's sequence (`make squad-orders-test`, 5 squads from the spawn) elements re-issue in the idle window. Laptop, seed 3, one run each, same tree: X4 on → 31 idle commands (all element moves), 7.0 changes/s, 3/21 never_arrived, slot error mean 14.5 / worst 28 m; X4 off → 0, 1.0/s, 0 never_arrived, 14.1 / 20 m. Station-keeping by design or thrash? If thrash, X4 is a one-line revert (`"move"` out of `ELEMENT_TASKS`). **Second reading** (new `element_slot_m`: distance from the slot the element holds *now*; X4 on, one more run): element units are on their current slots (mean 5.8 m over 17, worst 30) but the slots drift 15–22 m from where the first orders put them, with 38 idle commands (8.5/s) — the formation keeps its shape but leaves the clicked spot. Sent to squad | `build/squad-orders/run.log`, `squad_orders.json` `element_slot_m` |
| CP3 adapter review | `group_formation.gd` as squad's shim over `TacticsFormation`: pacing identical (`PACE_NEAR` 8, `PACE_FLOOR` 0.35, same formula), seating through `place(..., {"policy": "front"})`; all control formation tests pass on the merge | — |
| X6 squad chips | chips say IDLE / MOVING / CONTACT / UNDER FIRE; lit by living members in any order. Plain move keeping the element: agreed with squad, waits on their green | `test_control_groups::test_group_chips_say_what_each_squad_is_doing` |

**The diagnosis the brief asked to verify, verified** (the page's first row): round 5's start pose (zoom 0.36 → 45°)
was fine; zoom 0.75 → 68° is a top-down view where 30 vehicles are dots. The complaint was the weld, not the start.

**HUD cost after the card rework:** 90 canvas draw calls for the whole HUD (budget 130; round 5 measured 84–86).
Laptop, 1854×1011 window, 68 vehicles, `make hud-cost`, `32fd2abc` + tree, one run.

### X4: FIGHT → playable, measured

Laptop (shared with five streams: pessimistic), `make shell-playtest` (gangs vs law, Boulevard, ~30 a side), one run per
row. "Before" is `a975e262` with the same clock patched into a throwaway worktree (start of `GameLauncher.start` → two
frames after `Main` is ready); "after" is the loading screen's own `LOAD_TIMING`.

| | total | scene | arena build + navmesh | armies | first frame |
|---|---|---|---|---|---|
| before (`a975e262`) | 7,563 ms | – | – | – | – |
| after (`32fd2abc` + tree), run A | 5,828 ms | 67 | 678 | 4,749 | 334 |
| after, run B | 7,802 ms | 66 | 884 | 6,369 | 483 |
| **after feel's fix** (`8d9c59af` tree: main's `e817194a`), run 1 | **1,398 ms** | 67 | 679 | 387 | 265 |
| after feel's fix, run 2 | **1,406 ms** | 67 | 690 | 415 | 234 |

**FIGHT → playable: 7.6 s → 1.4 s** (laptop, the rows above). `make spawn-cost` on the same tree: 0.8 ms per vehicle
after the first of each type (was ~63), 180–215 ms for the first of each type per army. What is left is the arena
build + navmesh bake (~0.7 s, arena's and nav's; synchronous for determinism) and the first frame. At 1.4 s the
loading screen is a beat, not a wait, and its stage weights no longer matter; it stays, because the web build and
slower machines will sit on it longer.

**Where the time goes:** marks inside `_start_match` put 6.35 s of run B between `mode_start` and `armies_built`, i.e.
`Match.load_doctrine` spawning vehicles. `make spawn-cost` (headless, laptop, 68 vehicles) measured ~65 ms per vehicle
with the cyberpunk art against 1.1 ms with `--theme=default`, ~63 ms for every instance after the first of its type.
**I attributed that to per-instance art work, and that was wrong** (feel, `90b3cfb9` on `stream/feel`): each
new-faction hull slot first instances the default Condemned dozer and swaps it out, the dozer's `.glb` then had no
reference, the engine unloaded it, and the next vehicle re-read it from disk. A cache evicted *between* instances looks
exactly like per-instance cost in a per-call profile; the Condemned vehicles at 2 ms each (their live dozers kept the
model loaded) were the control group in my own data. Fix: `GameTheme.scene()` keeps a reference (law_tank 106–128 ms
→ 0.9 ms, laptop, headless). Rows A and B are stale for that reason; the rows after them are on top of the fix.
**The old instrument was blind to it:** shell-playtest's `load_ms` started its clock after the FIGHT click's own
awaits returned, by which time the whole stall had happened, so it read 0 ms before this round.

### Decisions

- **Default pitch 12° (was 25°, both the lead's), FOV 60°, start 50 m out; player floor 8°** (room below his default;
  below 8° the frame is mostly horizon, so don't widen it on the theory that lower is always what he wants).
- **Played at 12°, three things changed** (all found in `make shell-playtest` frames, all in `rts_camera.gd`, tested):
  (1) the cutaway must clear the 3 m wall's top edge too, or it hides every vehicle parked against it; (2) cut only when
  the stands would hide something (always when the camera is among the seats; from beyond their back only when the
  sight line to a vehicle inside the wall runs through their measured profile), otherwise a far camera showed a black
  void below the wall; (3) **a soft tilt floor past 70 m** (to 40° at full zoom-out), because a 12° camera framing a
  whole army at ~150 m showed the arena as a strip between sky and void. Up to 70 m the tilt is exactly his. This is
  the one place the camera overrides his tilt: flag it to him, don't hide it.
- (superseded) **Default pitch 25°, FOV 60°, start 50 m out — the lead's first pick.** Player range 22°–50°, Page Up/Down or ctrl+wheel
  to tilt, Home resets, **O** = the overview (77°, the one deliberate top-down).
- **The wall cutaway, not a pitch floor near walls** (do not "simplify" this away). Played at the lead's 25°, a squad
  near the wall (every army's spawn) is framed from a camera that sits past the wall inside the grandstand: in
  `make shell-playtest` at 50 s the stand railing hid our own vehicles and the crowd filled the bottom third. Raising the
  pitch near walls would have brought the top-down view back exactly where every match begins, the one moment the lead
  is guaranteed to be looking. Instead `RtsCamera.cutaway_near()` puts the camera's near plane just short of where its
  line of sight crosses the wall at the floor, so the stands between the camera and the arena are not drawn. A camera
  over the arena keeps `NEAR_DEFAULT`, so the cost is bounded. Side effect for feel: the stands *behind* the player's
  base (and their crowd) are cut away whenever the camera is past that wall; the far stands stay in view at 25°.
- **Sky is not unseen ground.** The L4 zoom-out cap sampled the screen and counted rays that miss the ground as ground
  the force can't see; at 25° a fifth of the screen is sky, so the cap would have punished the view the lead chose.
  Sky samples now leave the count.
- **Tests that are about screen geometry pin their pose** (`control_fixture.gd`, `test_command_camera.gd`: pitch 42°,
  round 5's tilt at their zoom 0.3) rather than inheriting the default look: at 25° / FOV 60° most of the arena is on
  screen at once, which turned "is it off screen?" tests into tests of the default.
- **Task symbols are drawn, not imported** (`CommandIcons.draw_task`, rasterised once by `IconRaster` into 96 px
  textures): crisp, themeable, and one batched rect per button on the HUD's draw-call budget.
- **Letters as strokes** (S, G, C, F, B) so the rasteriser needs no font.
- **The loading screen lives on the tree root**, so it survives the scene switch; the arena's venue build and
  navmesh bake stay synchronous (trip-up 57) — the screen names the stage and stays drawn through the stall.

### What to playtest (exact commands)

- `make skirmish` → pick factions and an arena → FIGHT: the loading screen names the matchup, the arena and one task
  by its symbol (~1.4 s on the laptop). In play: the camera starts at his 12° · 50 m; **Page Up/Down** or
  **ctrl+wheel** tilts (8°–50°), **Home** resets, **O** is the top-down map view. Zoom far out: past 70 m the tilt
  lifts (to 40° by 160 m). Near the spawn wall the stands between camera and arena are cut away.
- The command card: Stop, Hold, Attack-move, **Screen**, **Support by Fire** (symbols, names under them, hover for the
  one-sentence tooltip; Screen and Support by Fire need a whole squad), Formation. No Move or Follow buttons (right-click).
- The group chips over the card: IDLE (yellow) / MOVING / CONTACT / UNDER FIRE per squad.
- Hover the yellow doctrine line on the card with a squad selected: its last six decisions with the match time.
- Once nav's N1 is on `main`: YIELDING / BLOCKED / STUCK over vehicles, "Blocked by Tank" / "Stuck for 4 s" / "Arrives
  in 4 s" on a unit's card, and a faint line for the route a selected unit means to take.
- Instruments: `make camera-looks` (the page; `--camera-looks-pitches=…` for a follow-up grid), `make spawn-cost`,
  `make shell-playtest` (prints `LOAD_TIMING`), `make squad-orders-test` (now with `element_slot_m`), `make hud-cost`.

### Known issues

- **The floor ends at the stands** (feel's): a camera outside the venue (far framing, the free camera after a defeat)
  sees black void below the stands; the far-range tilt floor keeps it to the bottom strip in normal play.
- **X4 (a plain move keeps the squad a squad) is held** until squad's `4d734b1e` is on `main` and the five-squad A/B
  comes back at 0 idle commands (see the X6 rows).
- `shell-playtest`'s `faction_row_under_mouse` failed once in seven windowed runs on the shared laptop desktop (a real
  mouse can move the hover; trip-up 32); it passed on the immediate re-run.
- **Touch needs its own framing — a debt, not a resolution.** At the lead's 12° / FOV 60° a start-view vehicle is
  23.7 px on a 1200×540 phone, 40.0 px at 1920×1080 (headless projection, one fixture, laptop). He chose that camera for
  desktop; the phone inherits it. The phone bar moved 24 → 22 px provisionally (desktop got its own, 36 px); when touch
  gets its pass, give it a closer start or its own pitch rather than moving the bar again. Reported to the lead.
- **Constants fitted at the old camera (25-45° / FOV 55), checked after the 12° / FOV 60 change.** Zoom- or
  distance-based, unaffected: `ICON_ZOOM`, `TRACK_MAX_ZOOM`, `FOLLOW_ZOOM`, `OVERVIEW_ZOOM`, the cinematic `MIN_ZOOM`.
  Pixel/projection-based, fine: edge-marker sizes, pick radii, hull bars (sized from the projected hull).
  Pitch-dependent: **`VISION_FRAME_LIFT`** moves the focus a fixed ground distance, and at 12° the foreshortened ground
  turns that into ~0.3x the intended up-screen nudge (it should scale by ~1/sin(pitch)); in played 12° frames the
  element still sits clear of the card, so it is recorded, not changed late. `VISION_SEEN_FRACTION` (the zoom-out cap)
  is pitch-sensitive too; sky is now excluded from it. The phone readability bar was the third (above).
- The loading screen's stage bar is weighted equally; at 1.4 s it barely shows, so it was left as is.
- The camera pages' frames (26 MB of JPEG) live in the artifacts, not the repo; `make camera-looks` regenerates them.

### Merge notes (shared files)

None edited: `project.godot`, `game/main.gd`, `Makefile`, `mk/core.mk` and `tests/run_tests.gd` are untouched.
Outside control's paths: `tests/test_ai_player_holds.gd` (one line, seconds instead of frames, agreed with the
orchestrator). `perf_scene.gd` (feel's) reads `RtsCamera.pose_for` / `FOV_DEG`, so perf-scene's camera is now the lead's
12° / FOV 60 with the far-range floor.

### Questions for the lead

- **The far-range tilt floor** (the one place the camera overrides his 12°): at army-wide zoom it lifts to ~30–40°,
  because at 12° from that far the fight is a sliver. Keep it, or would he rather stay at 12° and zoom less?
- **Which arena is fun** (still unticked on the first camera page).

### Requests to other streams

- **squad:** tell control when Screen and Support by Fire are demonstrable (X5) — one boolean each in
  `game/control/task_palette.gd`. X4 (a plain move keeps the element): the two `rts_controls.gd` lines are agreed and wait
  for squad's green commit.
- **feel:** `perf_scene.gd` calls `RtsCamera.pose_for(focus, 0, zoom)`, which now looks down at 38° instead of the
  zoom-welded pitch: perf-scene's camera moves when this merges (lower, sees more of the far arena). The camera page's
  frames are an instrument for the crowd diagnosis: the low poses are the first that put the stands in frame.
- **nav:** X5 needs `Movement.state(unit)` (N1) on `main`.
