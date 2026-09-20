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

## Round 7 (2026-09-18/19, after the quota lift) — the orchestrator's brief: A, B, C1–C3, plus K1 and the perimeter

| Item | State | Evidence |
|---|---|---|
| **A** yaw follows the selection's facing | done. Source: tasked element heading → order facing/heading → hull forward, averaged; mixed/none keeps yaw. 70°/s past a 12° deadband; manual yaw pauses it; **Y** toggles. Selected vehicles show a forward chevron (+ fire-arc edges for a fixed gun). Reads squad's now-honoured facing since `4cad7ef7` | `test_control_facing_camera` |
| **B** frame out to the selection's weapon range | done. The selection's reach (largest `min(effective range, sight)`, via Engagement) ahead along its facing is the view's **lean** (`order_pose`), not a point to fit — fitting it dropped the squad off screen with the enemy in view (caught in shell-playtest, mutation-checked). `;` `'` factor. Auto camera capped at 100 m (`auto_frame_max_m`) | same |
| **C1** vehicle renders as portraits | done. `UnitPortraits`: one real tank per type, dressed as in play, photographed offscreen, cached; role icons until ready/headless | builder0 shell-playtest frame |
| **C2** animated task help | done. Hovering a task plays its posture loop in the tooltip: move, face, fire (always / on contact), ADVANCES / HOLDS HERE. **Geometry is squad's real planner** (`ElementPlan.preview`, on main) — a coil for Hold, interlocking sectors for Support by Fire. Stand-in only for Stop | `test_control_panel` |
| **C3** two grammars told apart | done. Rows carry `then: click|now`; click buttons wear a pointer badge + inset border; tooltip says which | `test_control_panel` |
| K1 `follow` + `slot` | done (squad's ask). One unit, the leader's frame, a sliding goal (≤ 0.52 m/tick at 90°/s) | `test_control_follow_slot` |
| Perimeter cutaway | done against arena's `perimeter()`/`perimeter_edges()` (by name; square fallback) with positional spans | `test_rts_camera` hexagon test |
| Portrait + railing fixes | nameplate hidden, hull fills the cell; railing (7 m) counts for the cut | builder0 frame |
| Card help shows itself once | Screen's animated tooltip opens by itself in the first planning pause; any press dismisses it (`9c889025`) | `test_control_panel` |
| Radar draws the arena's outline | the perimeter polygon, else the active layout's bound (`4f7371ef`) | `test_radar` |
| **Order progress on screen** (orchestrator, from nav/squad churn: weaving must read as *en route*) | done (`53a2af87`). For the selection, each order — or the squad's task, not its leader's moves — keeps a **pin**: ground ring at the ordered point, a stalk to the task's own symbol (card/preview glyph) on a dark disc, and a plate reading `ATTACK-MOVE · 2/3 there · 37 m`. A squad task adds a lead line from its middle (direct orders already have each unit's dashed line). Looked at the lead's 21°/49 m/FOV 35 pose, 1280×720 (laptop): readable over the arena floor; the first draft (12 px text, 20 px glyph, no plate) was not. 0.17 ms/frame at 30 units under orders (laptop); the whole control frame 1.84–1.96 ms of 2.0 (laptop, ~2.75× faster on builder0). **Wants the lead's eye on a touchpad.** | `test_control_order_marks`, `test_control_scale` |

## Round 8 (2026-09-19, the lead: "it still sucks", "they still generally don't do what I command them")

| Item | State | Evidence |
|---|---|---|
| **Orphaned units** (selection side): *"orphaned units that don't get selected at all when I cycle through the numbers"* | done (`ee9a434c`). `from_squads` seeded groups 1–5 while faction armies field 6–10 squads: condemned 6, law 4, gangs 17 vehicles on no key (laptop, 5200). Now up to 9 keys, squads past 9 fold into their family (Guns4 → Guns), else the last. squad consolidates the player's army to ≤5 (`90bd2212`, its line in `_start_match`); this is the belt. The skirmish prints `CONTROL_GROUPS ... ungrouped=N ... engaged_of=wired` | `test_control_every_unit_on_a_key`; 0 ungrouped for all four factions |
| **An ignored order is visible** (*"they don't obey and instead they shoot at whatever they were already shooting at"*) | done (next commit). What each gun is really on (`OrderExecutor.engaged_target_of`: its controller, else its brain) is held against the player's intent (a unit's attack order, else its squad's attack TASK: number key + right-click, the lead's gesture). Attack pins count `ATTACK · 1/3 on target · 2 NOT COMPLYING` and turn red; after 2 s a unit carries a plated callout: `FIRING ON IFV`, `CAN'T SEE TARGET` or `NOT FIRING` (closing to range is compliance). Looked at at 21°/49 m/FOV 35, 1280×720 (laptop): readable after a plate; the text is small at that size (lead's eye). 0.117 ms/frame; control frame 20.7–21.4 of 26 references | `test_control_order_refused` (4, one through the real executor; mutation: without the task path the squad case shows nothing) |
| **Refused on the spot** | done (`9a91d14e`). Five refusals (task without a whole element, move task with nowhere to go, follow without a friendly) returned their reason to nobody; now `_refuse` emits `command_issued` and the HUD posts "Can't: …". **Overridden later: not built, on evidence** — no code path replaces a player-sourced order (`element.gd` skips units whose current order is the player's; nothing else issues to the player's units), and if one appeared, the gun-vs-intent callouts would show its effect | `test_control_order_refused` (5) |

| Attack pin wording (squad's, adopted by the orchestrator) | done (`648563f8`): `ATTACK · 2/4 on target · 1 moving round · 1 NOT COMPLYING` — "moving round" = the member's order names the target and its gun is on nothing else | `test_control_order_refused` (6, 5/5 runs) |
| Drift heuristic for move/attack-move tasks | **declined by the orchestrator, on evidence**: under attack-move units spend 30–36% of their time off their order by design (arena's measurement), so a "not obeying" light would fire a third of the time and teach him to ignore the HUD. A predicate needs a measurement of normal first | — |

| Scale playtest regression (squad, after its consolidation) | done (`3c1c224e`): with nothing selected the vision camera framed the whole army (can't fit 100 m at 35°) → now group 1; and the lean toward the reach parked the selected squad UNDER the command card (symmetric 0.78 bound vs the card at 0.44 of the half-height) → `VISION_FRAME_BOTTOM` 0.40. Playtest with squad's 90bd2212: ok=true, group 1 at y 586–653 vs card ~778 | `test_rts_camera::test_a_long_lean_keeps_the_squad_above_the_command_card` (fails on the old camera: 0.49) |

**Hexagon, first look (main `0ae1b223`, `make camera-looks` on yard, laptop):** radar outline is the hexagon; far and
diagonal walls keep their stands and crowd; no void and no foreground occlusion in the default, overview and 90 m
frames. **Behind the walls, diagonals included: looked at, clean** — `make camera-looks` now adds a "behind wall k" frame per edge
of half the perimeter (180° symmetric) at the lead's 21°/49 m/FOV 35, focus 20 m inside the edge, camera out beyond
it; on the yard hexagon all three (two diagonals) cut the wall and stands and keep the floor to the bottom of the frame.

**ROUND 8 CLOSED. Merged into main as part of `1b3da573`** (verified: `git merge-base --is-ancestor 1b3da573 main`).
**MERGE HERE NEXT: `3c488882` — #29 GREEN (builder0): `make check exited 0`, 1261 passed / 0 failed, `sim-baseline
passed: 0cb238bf366e141f`, every target through `audio-check passed`.** It covers (beyond `1b3da573`): `39a61b86` (camera-looks "behind wall" frames), `8326e1eb` +
`3c488882` (`facing` on a move = arrive on this heading, nav/squad's contract, documented at the key and in
`orders.gd`), `17c1235e` (merge of main `22eda2f3`: nav's wheeled arrival, squad's facing half). Status commits after `3c488882`
(`f4f0e2bc`, `27619e69`, this one) landed after #29's sync and are docs only.
Local after that merge (laptop): control 183/0, camera 52/0, command 77/0, test_r 98/0.

**Next round — A6 (research_catalog.md, control + feel, contract first with nav and combat):** the lead's "they don't
obey" is a motion-LEGIBILITY problem, not only a readout one — under attack-move units spend 30–36% of their time
driving somewhere other than where he sent them, correctly, because they are fighting. feel owns the motion, control
owns the readout; the bar is joint (opposing-tangent time under 10% with no fall in exchange ratio). The nearest thing
already built is `facing` on a move: the hull's orientation carrying the order's intent.

**Round 9, control's, found at round-8 close: THE ARRIVE-FACING ARC HAS NO CALLER IN THE LEAD'S GAME.** `facing` on a
move is issued in exactly one place — `game/ui/tactical_map.gd:269`, the **touch map's** right-drag (press =
destination, drag = facing). That map is behind `--touch-map`; the lead plays `RtsControls`, which only ever READS
`facing` (rts_controls.gd:307). Squad sets it for holds and stations. So nav's `_arrive_facing` cannot fire in play,
which is why its A/B read `gates aimed 0, refused 0` in both arms. **Fix (control's): the desktop right-click gains the
touch map's grammar — press = destination, drag = the heading to arrive on** — with a test asserting
`orders.current(unit)["facing"]` after a drag so the next A/B has a live arm by construction, and a look at the lead's
pose (a facing drag must not read as a box-select; the pin should show the heading it will arrive on).

**Round 9, Invariant 0 (the orchestrator's): `RtsCamera.VISION_FRAME_BOTTOM` should READ the command card's geometry,
not mirror it.** The derivation it mirrors, at 1920×1080: the card (`SelectionPanel.HEIGHT` 200) plus the group chips
put the HUD's top edge at y 778, i.e. (778 − 540) / 540 = **0.44** of the half-height below centre; the constant is
**0.40**, the extra leaving room for the hulls themselves above the card. So a camera bound is a copy of a UI height in
another file — if feel or control changes the card, the lean silently goes back to hiding squads behind it. Both files
are control's, so this is ours to fix: have the camera ask for the HUD's reserved bottom fraction.

**Housekeeping (2026-09-19):** a backgrounded Godot from Sep 18 10:12 was still running 34 h later against this
worktree, plus ten waiter loops from checks #6/#17. All killed. **A hung headless Godot holds its checkout's `.godot`
import cache**; two Godots in ONE checkout produce phantom "tracked file does not exist" and cascading false
`Nonexistent function` errors (seen in the main checkout with two concurrent `make lint` loops, not this worktree).

**Round 8 detail: `1b3da573` — #27 GREEN (builder0): `make check exited 0`, 1233 passed / 0 failed, `sim-baseline
passed: 668b7d490607439b`, every target through `audio-check passed`** (main `0ae1b223` merged; contains every round-8
item above). After it, unchecked: `39a61b86` (camera-looks wall frames) and docs. **Round 8 is done for control.**
Before it, `3c1c224e` (waited for main's new sim line). #26 on `4ebe47a7`: 1228/0 tests,
then `sim-baseline FAILED` (expected `53d4e0ac`, got `668b7d49`) — **main's line is stale, not this branch:** the same
command on the laptop gives one hash (`34507d95`, glibc 2.39) for main `28eb403f`, this branch, and this branch with the
pre-M4 `orders.gd`; and clean main `28eb403f` on builder0 gives `668b7d49` too (control's scratch run). The orchestrator
records the line. Before it, **`4ebe47a7`** (main 28eb403f merged) — #26 running. #25 on `9dc17901` was not a verdict: feel's
`test_a_new_state_waits_for_a_bar_line` failed on builder0 (audio-driver timing; reported to feel), so make stopped at
`test`. **Round 8 is otherwise done for control.**

**Previous: `9cb4a86d` — #24 GREEN (builder0): `make check exited 0`, 1213 passed / 0 failed, `sim-baseline passed:
253ecfdeed84bc4d`, every target through `audio-check passed`** (M4 clamps + the timing policy on top of merged `c7f9cd4e`).
**MERGED: `baf04ead` as main `fa859dce`; `c7f9cd4e` as `b500a2db`.** Next candidate: `86a8744c` (main `fa859dce` merged in at `7105478c`; the rest
of the ratio timing tests; the cutaway reads feel's `StandsProfile` by path when the build has it, hand measurement as
fallback; the kit's front is 9.64 m from 4.2 m out, not the measured 7 m at 2.3 m, so one test case moved 30° → 40°).
#21 on it: RED on `test_radar`'s outline test only (1191/1, builder0), the static-leak main fixed at `5cc17ee6`;
smokes never ran. **Candidate now `c7f9cd4e`** (main through `5cc17ee6` merged at `af9e4f1e`, plus the same leak guarded
in `test_rts_camera`, positive-controlled). **MERGE HERE: `c7f9cd4e` — #22 GREEN (builder0): `make check exited 0`,
1193 passed / 0 failed, `sim-baseline passed: 253ecfdeed84bc4d`, every target through `audio-check passed`.** **Open:** look at the cutaway at the lead's pose once `StandsProfile` is on main (it cuts the front of the stands
slightly more often near the wall) — **looked at, fine:** at 21° (49 m and 100 m) both profiles cut, vehicles by the
wall are clear and the far stands keep their crowd; the profile only decides at steep far poses. **M4 done:**
`Orders.clamp_to_arena` (shape inset by a 4 m hull clearance = exactly ±116 on the square, then `Arena.clamp_into`)
replaces the four square clamps; when arena's `f295ff30` (exact `margin` in `ArenaShape.clamp_into`, fixing the corner
bug control reported) is on main, pass the margin through instead of scaling the bound here. **Round 8 timing policy: done** — `make check` measures
control's timing, `make control-timing` judges it (run on an idle builder0).
Was: **MERGE HERE: `baf04ead` — #20 GREEN (builder0): `make check exited 0`, 1162 passed / 0 failed, `sim-baseline passed:
e38fd65b6b6ead3f`, every target through `audio-check passed`** (main `b70608d6` merged in). After it, unchecked:
`35c72304` (order/click/bars as ratios) and docs. **Decided before the result (orchestrator, lesson 106):** `baf04ead`
predates main's `d8f26176` (garage/army-loop timeouts 60/120 → 600 s), so a *timeout* in `garage-smoke` or
`army-loop-smoke` in #20 is not a finding about this branch; merge anyway and re-run on main.
**After #20 merges (agreed with the orchestrator):** merge `main` first (nav's `c7da4dd8` moved the sim baseline;
feel's `551cb2a4`), then resolve combat's `36e116c8` in `game/ui/radar.gd` if it has merged: take combat's inline
`Arena.perimeter()` block in `_draw()`, keep `test_the_radar_outline_is_the_arenas_own_shape` pointed at it, delete
`outline_points()`; read `visibility.origin` (combat's per-instance field origin) wherever control reads the field.
`git merge-tree` showed `radar.gd` as the only conflict. Then re-check. #19 on `9c889025` was RED on `test_control_scale` (2.33 ms frame vs 2.0, builder0:
load from concurrent checks — idle builder0 is ~0.65 ms) and was killed, since make stops at the failing target. Fix in
`baf04ead`: the frame budget is a **ratio to a reference workload** timed interleaved with it (5.5–7.2 on the laptop at
loads 3–8, budget 8.0, mutation-checked), click latency is the fastest of three, and the panel sorts once a frame.
Superseded: `a1d92ad6` (#17: 1157/0 tests, sim-baseline failed on main's then-unrecorded hash). Not done: nothing from the brief; open: the
preview's start row crosses on the way (cosmetic), feel's stands profile as data (control still measures kit_stands).

**STATE AT PAUSE (2026-09-18, quota stop; resuming ~4 days later): everything is committed.** Last commit with code:
`017fda42` (the lead's camera: 21°, FOV 35, 49 m, auto-framing on; the `-` `=` hints; squad-1 first frame; tests
pin their lens). **Its `make remote T=check` (#14) came back GREEN: 1085 passed, 0 failed (builder0). Merge here: `017fda42`.**
It passed locally (camera 42, control 145, command 50, radar 7, touch 9, all 0 failed; laptop) and `make remote
T=shell-playtest` exited 0 on it (builder0). **Last verified green: `2dbd985d`** (1082/0) and `ff28563d` (1084/0);
`42d42fd2` and `eb2d7b74` were never fully checked (superseded). Nothing is mid-way: no feature started after
`017fda42`. Not started (round 7, needs a brief): order-preview HUD, two grammars on one card, yaw follows facing, FOV
from weapon range. Camera shape coupling (square perimeter) and the telephoto pull-out: tactical_map.md "Open items".

**SETTLED (2026-09-18, night): the lead found the camera in play** with the live controls — `CAMERA_POSE pitch=21
distance_m=49 fov=35 yaw=-0 zoom=0.365 auto_frame=on`. Now the default: 21°, FOV 35° (telephoto), 49 m, auto-framing
on, first frame on squad 1. **The lens, not the pitch, was the problem** (tactical_map.md "Why a telephoto"): my FOV
page argued "wider shows more" — the wrong way, sound and irrelevant. FOV range now 20°–90° (his pick was the floor
again). `-` `=` added to the readout (he is on a touchpad). Tests that are about screen geometry pin round 5's lens
(55°) as they pin its pitch. Start vehicle: 64.1 px at 1080p, 39.0 px at 1200×540 (laptop, headless projection).

**THEN (2026-09-18, later): still unplayable at 45°** — *"it's unplayable because of the field of view right now"*.
Stop choosing the number: **the lead finds the camera himself.** In `make skirmish`: a live **camera readout** (top
left: pitch, distance, FOV, yaw, auto-frame), **[ ]** field of view (35°–90°), PgUp/PgDn tilt (8°–70°), wheel
distance, `,` `.` yaw, **V** auto-framing off (so the vision camera stops taking the view back), **P** prints the pose
and copies it to the clipboard (`CAMERA_POSE pitch=… distance_m=… fov=… yaw=…`) — the default becomes whatever he
sends. Provisional start nearer the readable end: 50°, FOV 60, auto-framing no closer than 45 m (at 45° it closed to
~29 m in play). FOV frames for him to confirm the lens: https://claude.ai/artifact/Akfsk6xq1L4pQDCFyTNvva (50/55/60; at
the same pose 60 shows more of the fight). Command card 160 → 200 px tall ("the buttons are too small to make out").
Round 7 (not started, needs a brief): yaw follows the selection's facing; FOV tied to the selection's weapon range.

**REVERSED (2026-09-18, late): the lead played 12° and rejected it** — *"I was totally wrong about the camera, the
game is unplayable now with low field of view."* Default pitch back to **45°** (round 5's start pose); FOV 60 kept (my
judgement from scripted sessions: "low" reads as the pitch, and 60 shows more ground than 55, not less — one constant if
he disagrees); pitch/zoom decoupling, the 8°–50° range, the cutaway and the far floor all stay. Phone bar back at 24 px
(30.3 px measured). The reason is next to `DEFAULT_PITCH_DEG`: **a playability number, chosen from play, not a frame.**
Everything below about 12° is history.

**Report (2026-09-18, night).** **Green, merge here: `2dbd985d`** (`make remote T=check` 1082 passed, 0 failed,
builder0) — main `0f559857` merged in, X4 re-landed, Ambush, X5 on nav's real Movement. Merged to `main` earlier:
`758a45a8`, `aa7f3499` + `9ef6bbee`. (This Status edit is docs-only, on top of it.)
- **Done:** X1 (no Move/Follow buttons), X2 (the N4 palette with tactical task graphics; Support by Fire and Screen
  earned from squad's evidence), X3 (pitch its own axis; **the lead picked 12° · 50 m · FOV 60** on two camera pages,
  played and fixed: wall cutaway, far-range tilt floor), X4 (loading screen; FIGHT → playable 7.6 s → 1.4 s with
  feel's fix), X6 chips, X7 "why did my element do that".
- **Landed after main merged nav, feel and squad:** the plain move keeps the squad a squad (0 idle commands in the
  lead's sequence), Ambush on the card (B), X5 on nav's real Movement API.
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
| X5 orders you see landing | **live** with nav's N1 (on main `f03a795c`): real provider reports `driving`, ETA 4.9 s, 58.9 m, the route's points (`test_the_real_movement_api_reaches_the_card`) | `test_control_movement_readout` |
| X7 (stretch) "why did my element do that" | done: `ElementLog` keeps each element's last 6 decisions with match time; hover the card's doctrine line | `test_control_element_log` |
| X6 a plain move keeps the squad a squad | **RE-LANDED** after squad's fix (`4d734b1e`, on main `0f559857`), admitted by the A/B that held it: the lead's five-squad sequence on the merged tree (laptop, seed 3, one run each) — X4 on: **0 idle commands**, 1.0 changes/s, 14 arrived and stayed, 1 never arrived, 5.9 m mean from slot (element units 6.7 m from their current slots); direct: 0, 0.8/s, 12, 1, 5.6 m. Both runs showed 6–7 `no_goal_recorded`: the instrument's click spots were screen fractions set at a 45° camera, and at 12° squad 2's spot was sky (no order). Fixed (walk the click down to ground); re-run with X4 on: all 21 ordered, 18 arrived and stayed, 3 still travelling, **0 idle commands**, 1.2 changes/s. A direct order to part of a squad still releases only those units | `test_control_commands::test_a_direct_order_to_part_of_an_element_releases_only_those_units` |
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

- ~~**GL textures leak at exit after merging main**~~ feel's (the night sky's radiance maps), fixed on main and merged.
  Also fixed by feel: the "void below the near wall" was never missing geometry — the cutaway clips every real surface
  in that band and the sky dome's below-horizon colour showed through; the dome now draws the city's ground.
- (history) **GL textures leak at exit after merging main** (two "Texture with GL ID … leaked 5460 bytes" lines in
  `make shell-playtest`, which fails its clean-console gate). Absent in every pre-merge run; nothing control added
  creates a texture of that size; the merge brought feel's sky and skyline shaders. Reported to the orchestrator.

- **The floor ends at the stands** (feel's): a camera outside the venue (far framing, the free camera after a defeat)
  sees black void below the stands; the far-range tilt floor keeps it to the bottom strip in normal play.
- **X4 (a plain move keeps the squad a squad) is held** until squad's `4d734b1e` is on `main` and the five-squad A/B
  comes back at 0 idle commands (see the X6 rows).
- ~~`shell-playtest`'s `faction_row_under_mouse` failed once in seven windowed runs (blamed on the desktop's mouse)~~
  **Not a flake, and mine** (`31a4aa11`): on builder0 the faction checks failed every run, and the control under the
  mouse was the loading screen — a full-rect, click-stopping layer on the root, still fading when the playtest clicked.
  One consistent failure plus one intermittent one of the same check was one cause. The screen now lets clicks through
  the moment the load is done (tested, mutation-checked) and the playtest waits for it to go. After merging feel's leak
  fix, `make remote T=shell-playtest` exits 0 on builder0 for the first time: 18/18 checks, clean console.
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
