# Stream: control (the shell has to work)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*, *Controlling units*), [../workstreams.md](../workstreams.md) (M3 you share with render; you own
> K1 and L4) and your round-4 report [archive/round4/control.md](archive/round4/control.md). You own `game/control/`,
> `game/ui/` (including `hud.tscn`, the widgets and the title screen), `game/camera/`, `game/controllers/`,
> `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md`.

## The lead's direction (2026-09-17)

> *"Right now the game is also unplayable with the camera, it ends up focusing on the enemy instead of our own friendly
> units. The startup screen seems stuck, I can't actually click any of the first buttons, and when I do manage to start
> the game there's a bunch of red error messages in the console log."*

Round 4 built the vision-framed camera, element focus and tasks, and every test passed. The lead still couldn't play
it. **Your first job is the gap between "the tests pass" and "a person can use it."**

## Where things stand

- The camera frames the *commanded element*; with nothing commanded, or when an element dissolves, it evidently ends up
  on the wrong thing. Reproduce it the way the lead hit it: `make skirmish`, don't give an order, watch what it frames.
- The title screen is `game/ui/` and `game/modes/title_mode.gd`. A headless `--title` run prints `TITLE_START offline`
  straight away, which suggests something starts or swallows input without a click.
- Console noise at 30 a side is largely the renderer's per-instance uniform limit (render's X2), but **triage all of
  it**: your job is a clean console for a player, and to hand anything that isn't yours to the stream that owns it.
- Announcer subtitles go through `Hud.post_message` and crowd the four-line log (audio's evidence:
  three of four visible lines were the announcer on desktop, and a kill message was buried on phone).

## Backlog (in order)

**X1. Play it, then fix what stops you.** Before writing code: run `make skirmish`, play a full match, and write down
in Status exactly where it stops being usable (with screenshots). Then fix, in whatever order the playthrough dictates:
- **The camera frames your force.** With no element commanded, frame the player's units; never centre on the enemy
  unless the player asked. An element dissolving hands focus back to your army, not to whatever was on screen.
- **The title screen accepts clicks** and starts what the button says; nothing starts a match on its own.
- **A clean console:** triage every error in a normal session, fix yours, and file the rest with evidence to the owning
  stream (render for shader and material errors, combat for simulation, audio for the booth).
Then play it again and say whether it's playable now.

**X2. Subtitles get their own line.** The booth speaks on its own band (a caption line or panel), so gameplay messages
(kills, losses, orders, control point) keep the message log. Readable at the default zoom and at 1280×720.

**X3. The lead's three dials** (from round 4, none blocking): how close the default frame sits, one alert line or
three, and whether the faction menu opens by default. Pick sensible defaults, make each one a flag or setting, and say
in Status what you chose and why.

**X4. Readability at 30 a side (M3, with render).** Selection marks, nameplates, health bars and order markers must
stay legible when 60 vehicles are on screen and render has toned the vehicle glows down. Their accent and your
selection colour must not be confusable. Screenshots at 30 a side, before and after.

**X5. Orders that survive a big army.** With 30+ units and several elements: selection, group switching and task
issuing stay inside the latency budget you measured in round 4 (box-select 1.38 ms, 30 orders 1.87 ms), and the element
bar stays readable. Add the optional `facing` to `UnitCommand` that doctrine asked for (their halt-formation hack goes
away).

**X6. The first two minutes.** A new player opens the game and gets: a title screen that works, a match that starts,
controls they can discover (a short on-screen hint set that doesn't nag), and a camera that never loses their army.
Write what a first-time player sees, in order, in Status.

- **Stretch:** the cinematic camera as a spectate mode from the title screen; a replay of the last match.

## How to verify

`make remote T=check`; your control tests with real input events; **a played match**, with screenshots you looked at
and a written verdict on playability; a clean console log attached to Status (`build/skirmish-console.log` or similar).

## Don't touch

Vehicle art and effects (render), arena layouts (arena), weapons and rules (combat), brains (ai), the booth's content
(audio: you own where its subtitles appear, not what it says).

## Status

_Round 5, control stream. **Every backlog item (X1–X6) is done; stretch: spectate done, replay not started.** Updated 2026-09-17._

### Plan (backlog in order)

1. **X1** play it through real input (`make shell-playtest`: title → SKIRMISH → faction menu → planning → two minutes
   of battle), fix what stops a player, triage the console.
2. **X2** booth subtitles on a caption line of their own (`Hud.post_caption`), the message log for gameplay.
3. **X3** the three dials as flags with defaults.
4. **X4** readability at 30 a side with render's toned-down glows; HUD ≤ 130 draw calls and ≤ 1 ms `_process` (CP1).
5. **X5** orders at scale re-measured; optional `facing` in `UnitCommand`.
6. **X6** the first two minutes, written down in order.

### X1. Play it, then fix what stops you. Done.

**How it was played.** No input injector exists on builder0, so `ShellPlaytest` (`game/ui/shell_playtest.gd`,
`make shell-playtest`, needs a display) plays through `Viewport.push_input`: it moves the mouse over each button and
records what Godot says is under it, clicks, and samples the camera through two minutes of battle. Frames were looked at.

**Where it stopped being usable, and what changed:**

| What the lead hit | What it was | Fix |
|---|---|---|
| "The startup screen seems stuck, I can't click the first buttons" | `make skirmish` opens the faction menu. Clicks *did* reach it (the playtest shows the row under the mouse and the picks change), but nothing on it was a button that started anything: the only way on was Enter, written as a line of text ("ENTER fight"). Clicking a row changes a highlight and nothing else, which reads as stuck. | A real **FIGHT** button (min 160×44 px; confirms on release), hint text that says click / right-click. |
| (the title screen, `make title`) | Its buttons did work, but on desktop they **quit and relaunched the executable**, dropping every launch flag. From a terminal that is a window closing and another opening seconds later. | Switches to the game scene in-process with `Main.next_flags`; carries `--ui-touch`, `--announcer`, `--music` and the playtest flag. |
| "It ends up focusing on the enemy instead of our own friendly units" | The vision frame included every enemy the commanded element could see. Once the armies met, 26 contacts outweighed 5 of yours: the frame's centre moved to the enemy, the zoom cap stopped it widening, and your element slid off the bottom. Unit test on the old code: **centre 44 m from your element, 17 m from the enemy**. | Contacts are framed together with their mirror image about the element: they widen the view, never move its centre. A wiped last group falls back to the whole army. After: the element stays **1–15 m from screen centre** at every sample through 120 s of battle, all its vehicles on screen. |
| "A bunch of red error messages" | In a full session the **only** errors are render's: `Too many instances using shader instance variables … 4096` (217) and `instance_buffer_pos.has(p_instance)` (94) with 45 vs 26 vehicles. Nothing from control, combat or audio. | Render owns it (their X2); nothing to file beyond what CP1 already tracks. |

The brief's clue (a headless `--title` printing `TITLE_START offline` at once) did not reproduce: locally the title sat
for 40 s without printing it.

**Playable now?** Up to the edge of render's and combat's work, yes: a click on SKIRMISH opens the faction menu, clicks
pick both sides, FIGHT starts the match, the planning pause says what to do, Space starts it, and the camera stays
on your element through contact with the enemy visible beyond it. What still stops a real session is not control's:
the frame rate (combat/ai's simulation tick per CP1) and the renderer's uniform errors.

### X2. Subtitles get their own line. Done.

- `Hud.post_caption(speaker, text)` shows one caption at a time on a **caption line** (`CaptionLine`,
  `game/ui/widgets/caption_line.gd`): top centre, 56% of the screen wide, the speaker in their colour (CALLER yellow,
  VETERAN cyan, PA pink), white text on a dark strip, at most two lines, held for reading time (2.5 s + 55 ms a
  character, up to 7 s) and faded. A new line replaces the last at once.
- Until the booth calls `post_caption` itself, `Hud.post_message` recognises its `"CALLER: …"` format and routes it
  there. The `HUD_MESSAGE [info] CALLER: …` console line is unchanged, so `announcer-shots` still finds it.
- **Why the top:** the bottom fifth belongs to the command card, group chips and alert prompt; the message banners
  run down the sides. The caption strip ends at 12% of the height at 1080p and never crosses a message column
  (tested at 1920×1080 and 1280×720; text ≥ 18 px).
- Played: in the shell playtest's two minutes, **4 booth lines on the caption line, 0 in the log, 12 gameplay
  messages in the log**; frame `build/shell-playtest/4_caption.png` looked at (VETERAN's two-line caption over the
  battle, readable, clear of the status block and the log).

### X3. The lead's three dials. Done.

| Dial | Flag | Default | Why |
|---|---|---|---|
| How close the default frame sits | `--camera-frame=close\|default\|wide` (`RtsCamera.vision_inset` 0.9 / 0.78 / 0.6) | `default` (round 4's frame) | With contacts now framed symmetrically the view already widens when a fight starts (zoom 0.31 on the march, ~0.8 in contact in the playtest). Closer would lose the enemy the moment it matters. |
| One alert line or three | `--alert-lines=1..3` | 1 | The message log already narrates; the prompt is the one thing to act on (Q). Three lines stack upward and dim. |
| Faction menu by default | `--pick-faction` / `--no-pick-faction` | on | It was the "stuck" screen only because it couldn't be clicked through; with FIGHT it is one click, and it is where the army size is explained. |

To try them: `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --skirmish --camera-frame=close --alert-lines=3`.

### X4. Readability at 30 a side (M3, with render). Done.

**The HUD's draw calls: 369 → 84** at 1920×1080 with 68 vehicles (CP1 budget ≤ 130). `make hud-cost` measures each
widget during a tactical pause (hidden vs shown, the picture holding still) and writes `build/hud-cost.json`; render
can hold the line with it.

| Widget | Before | After | What changed |
|---|---|---|---|
| Group bar | 120 | 8 | unit icons drawn once into textures (`IconRaster`, `CommandIcons.unit_texture`), and a `DrawBatch` that draws every fill, then outline, icon, text |
| Selection panel | 71 | 33 | the same |
| Radar | ~104 | 20 | blips are cached disc / diamond / ring textures drawn kind by kind; prop footprints are batched primitives |
| HUD skin (status + banner frames) | 52 | 5 | `CyberFrame` draws each glow layer's brackets as one multiline, not four polylines |
| Selection rings (3D) | 61 meshes | 3 draws | one MultiMesh per ring kind |
| Everything else (messages, captions, hints, edge markers, status, score) | | ~18 | |
| **Whole HUD** | **369** | **84** | |

HUD `_process` with 30 selected of 60: **0.865 ms** (`test_control_scale`), inside CP1's 1 ms.

**Legibility on render's darker scene** (frames `build/control-playtest/scale/*.png` and the shell playtest, looked at,
after render's merge): the selected element's thick bright rings read at a glance against idle friendlies' thin
ones and against render's cyan team rim, which is a faint tint on the hull, not a ring on the ground; hull bars sit
over the selected and the hurt only; order markers and the dashed attack-move line stay visible over the asphalt.
**Enemies' dashed rings were too faint to find in a crowd** at 0.45 alpha: raised to 0.7. Friend and foe still
differ by shape (solid vs dashed rings, circles vs diamonds on the radar), not only colour.

**Console:** a whole played session (title → menu → 2 minutes of battle, 64 vehicles) and the 30-a-side scale session
now log **zero** `ERROR`, `SCRIPT ERROR` or `WARNING` lines, after render removed the instance uniforms.
`make shell-playtest` now **fails on any red line**, so it stays that way.

### X5. Orders that survive a big army. Done.

**Latency at 30 a side** (`tests/test_control_scale.gd`, builder0, 2026-09-17, main with render/combat/arena merged):
box-select the army **0.53 ms**, click → 30 orders **1.15 ms**, `order_selection` for 30 **1.83 ms** (round 4: 1.38 /
1.87 / 1.65 on the laptop), control's per-frame work with 30 selected of 60 **0.865 ms** (awareness 0.32, horizon
zoom 0.64 amortised, panel summary 0.29, vision state 0.13, edge markers 0.01) against CP1's 1 ms. The element bar is
read in the X4 frames below.

**`facing` in `UnitCommand`** (doctrine's request from round 4): `move`, `attack_move` and `hold` take an optional
`facing: [x, z]` (zero or NaN rejected; other verbs rejected). The group still travels and forms up toward `to`; every
unit's order carries the normalised `facing`, and once the order completes its station's `heading` is the facing. The
round-4 executor honours it on hold. Nothing issues it yet, so the sim baseline is untouched. On main in K1
(orchestrator, 0f838c8). **Turning a brain to it is ai's** (requested via the orchestrator, with the halt hack in
`element_plan.gd` to remove).

### X6. The first two minutes. Done.

**What a first-time player sees, in order** (played with `make shell-playtest`, frames looked at):

1. **The title** (`make title`): TANK SQUAD types itself in over the night arena, four buttons. The mouse is over the
   button it looks like it's over; SKIRMISH switches to the game in the same window (no restart).
2. **The faction menu:** four factions with what each fields at the budget (Road Gangs 44 vehicles … Syndicate 17),
   click for yours, right-click for theirs; an **ARENA** row (Random by default, or The Container Yard, The Boulevard,
   The Pit, The Boneyard, each with its one-line note: the fight it is built for); a yellow **FIGHT** button.
3. **Planning:** the army on its start line, the first element selected and ringed, "PLANNING: select … Space starts"
   across the top, and in the bottom-left corner three hints: `1-5 pick an element`, `RIGHT-CLICK move there / attack
   it`, `SPACE pause to plan`. The radar shows the whole arena with the fog.
4. **Space:** the match runs, the SPACE hint retires and `A + CLICK attack-move` moves up. The camera follows the
   element it frames at zoom ~0.31 on the march.
5. **Contact (~45 s):** the view widens to take in the enemy while staying centred on your element (~0.8); the caption
   line carries the booth; kills and losses go to the message column on the right; one alert (`Hunters under fire
   (+4) [Q]`) sits above the group chips.
6. **Losing an element:** the camera goes back to your army, not to what killed it.

Hints never take input, show at most three, and each goes for good once used (`user://control_hints.cfg`;
`--hints=off`, `--hints=fresh`).

**The arena picker** (arena asked, via the orchestrator): `Arena` builds from the command line only, so a match
restarted with `Main.next_flags` silently kept the old layout. `GameLauncher` (`game/ui/game_launcher.gd`) instances
`main.tscn` with the arena's `layout_name` set, resolves `--arena=random` by `--seed`, and both the title and the
faction menu start matches through it. The shell playtest checks the arena you clicked is the one built.

### Stretch

- **Spectate from the title.** SPECTATE starts a CPU-vs-CPU skirmish under round 4's self-directing cinematic camera
  on a random arena (`skirmish cinematic player=cpu enemy=cpu no-pick-faction arena=random`). A title entry can carry
  several flags now.
- **A replay of the last match:** not started. It needs the simulation to be replayable from recorded orders on the
  current Jolt physics, which is combat's determinism work first.

### The CPU's commander (orchestrator's request, then withdrawn)

`SkirmishMode.cpu_runs_elements(flags)`: `--element-cpu` / `--no-element-cpu`, default `ELEMENT_CPU_DEFAULT`. When on,
each CPU squad becomes an element under `ElementCommander` (both sides under `--cinematic`), sharing the one
`Elements` with the player's lazily formed elements. **It stays off:** ai's faction ladder in skirmish's real setup
(faction armies at 5200, control point on) has brains-only beating doctrine 32–16; the earlier 52–28 was small mirrors
without the control point. Cost when on (ai, Jolt, laptop): elements +1.7 ms a tick flat after ai's stagger, about +15%
of the tick. Flip the constant when ai reports a variant that wins at scale.

### Decisions (with reasons)

- **Contacts frame symmetrically about the element** rather than being dropped: the lead wants to see the fight
  coming, and the element must stay the centre. Mirroring keeps both.
- **Captions at the top centre**, not the bottom: the bottom fifth is the command card, chips and alert; the sides are
  the message columns.
- **The faction menu stays on by default** and gained the arena: it was "stuck" only because nothing on it was clickable.
- **Menus start matches in-process through `GameLauncher`**, never by relaunching the executable (lost flags, a
  closing window) or by `reload_current_scene` (the arena ignored the new flags).
- **HUD icons are rasterised once in GDScript** (`IconRaster`) rather than baked in a SubViewport: synchronous,
  headless-safe, testable, and the vector `draw_unit` stays the single source of the shapes.
- **The shell playtest fails on any console error or warning.** The lead's "red error messages" are a player-facing
  bug, so the check is the player's console, not a filtered one.

### Questions for the lead

1. **Is the view in a fight wide enough?** On the march the camera sits close (zoom ~0.31); when the enemy is in sight
   it widens to keep them in frame (~0.8). `--camera-frame=close|default|wide` changes how tightly the element fills the
   screen if either feels wrong.
2. **Arena choice:** the menu offers Random (default) plus each named arena with its note. If you'd rather the game
   always rolls it, the row can go; if you want the choice, it's there.

### Requests to other streams

- **ai:** turn brains to `order["facing"]` on arrival and to the station heading when idle (K1 facing, on main); then
  `element_plan.gd`'s halt can issue facing instead of driving crews along their sectors. Relayed by the orchestrator.
- **ai:** tell control when a doctrine variant beats brains at skirmish scale; the default flips in one line.
- **audio:** the booth calls the player's side "the Condemned" when the player picked the Road Gangs (seen in the shell
  playtest, gangs vs law). And `Hud.post_caption(speaker, text)` is there to call instead of the `"CALLER: …"` format
  whenever convenient. Relayed by the orchestrator.
- **arena:** when `--arena=random` lands in `Arena` itself (stream/arena 3b1377c), control switches `GameLauncher` to pass
  "random" through with `--seed` and reads `Arena.active["name"]` back (the orchestrator's ruling: Arena owns the roll).
  Until then `GameLauncher.resolve_arena` rolls from `--seed` and hands Arena a real name, so nothing logs an error.

### Known issues

- `GameLauncher` resolves `random` itself until arena's resolver is on main (above): two implementations for a while.
- Hints are desktop only (keys and right-click), like the rest of the round-4 grammar.
- `make hud-cost` measures during a pause, so messages and captions (0–4 draws each when showing) aren't in the 84.

### What to playtest (exact commands)

```bash
make title                          # SKIRMISH → faction + arena menu → FIGHT → planning (Space) → battle; or SPECTATE
make skirmish                       # straight to the faction + arena menu
make skirmish-factions FACTION=gangs ENEMY_FACTION=law ARENA=pit
make remote T=shell-playtest        # the whole first two minutes through real input; fails on any console error
make remote T=hud-cost              # the HUD's draw calls, per widget
make remote T=control-scale-shots   # 30 a side, frames in build/control-playtest/scale/
```
Try `--camera-frame=close|wide`, `--alert-lines=3`, `--hints=off`, `--element-cpu` on the Godot command line.

### Next steps

1. Switch `GameLauncher` to arena's resolver when it merges (above).
2. Flip `ELEMENT_CPU_DEFAULT` when ai's variant wins at scale.
3. Touch: the desktop grammar, hints and menus have no touch path yet.
4. A replay of the last match, once the simulation replays from recorded orders.

### Merge notes (shared files)

- **No shared files edited.** `project.godot`, `game/main.gd`, `Makefile`, `mk/core.mk` untouched. Everything is in
  control's paths: `game/control/`, `game/ui/` (including `widgets/` and `widgets/title/`), `game/camera/`,
  `game/modes/skirmish_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md`, control's tests.
- **K1:** `UnitCommand` gains optional `facing` (already documented on main, 0f838c8).
- **Hud:** new `post_caption(speaker, text)` and signal `caption_posted`; `post_message` routes the booth's
  `"SPEAKER: …"` lines to it and still prints `HUD_MESSAGE`.
- **Title screen:** starts modes in-process through `GameLauncher`; a menu entry may carry several flags.
- **New flags** (skirmish): `--camera-frame`, `--alert-lines`, `--hints=off|fresh`, `--no-element-cpu`,
  `--hud-cost=PATH`, `--shell-playtest=DIR`. **New make targets:** `shell-playtest`, `hud-cost`; `skirmish-factions`
  takes `ARENA=`.
- The sim baseline is untouched (nothing here runs in `--match`).
