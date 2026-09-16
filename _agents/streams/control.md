# Stream: control (the vision-framed camera, command at scale)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 4 direction*: camera and vision, doctrine, army size), and [../workstreams.md](../workstreams.md) (L4 is
> yours; you consume doctrine's L1 and combat's L3). You own `game/control/`, `game/ui/` except `widgets/**` and
> `hud.tscn`, `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline}_mode.gd`, `mk/command.mk`, and
> `_agents/tactical_map.md`. Round 3's brief and report: [archive/round3/control.md](archive/round3/control.md).

## The lead's direction (2026-09-16)

> *"the game is still fairly unplayable because the camera doesn't really track the vehicles … we should optimize for
> the game being more zoomed in in general (i.e. closer to a Twisted Metal versus Starcraft if we put those 2 on a
> spectrum) … it really should automatically track the entire set of friendly units, and basically always zoom in as
> close as possible with the constraint can see the same horizon as what all units can collectively see (that in itself
> is actually a large and difficult problem, but you can do it). Basically zooming in and constraining the user's view
> is a legitimate limitation that the player would have to overcome by actually pointing in the correct direction (i.e.
> a bird's eye view is just an unearned god view; we want to actually make the users expend their sentries to be able to
> see, that sort of thing)."*
>
> On scattered forces, the lead agreed with: **frame the element you're commanding**, with off-screen markers and
> alerts for everyone else. On command at scale: *"we keep control groups plus automatic elements"*; a named hierarchy
> is out *"unless there's a sleek way we can figure that out from a UX perspective"*.

## Where things stand (round 3)

Selection (click, box, shift, double-click by type), right-click orders, attack-move, shift-queued waypoints, follow,
stop, hold, ctrl+1–9 groups, group moves with automatic formation slots and regrouping, the selection panel and command
card, order markers and acks (feel's), `RtsCamera` with framing and order tracking, the control point on by default.
Orders go through `Orders` (K1). Playtest: `make control-playtest-shots`.

## Backlog (in order)

**X1. The vision-framed camera (L4).** The camera fits what the commanded element can currently see: its units' sight
radii, its spotted contacts, and its destination, then zooms as close as that region allows (a `max_zoom_in` the player
can't exceed by scrolling). Smooth, no lurching as units turn; manual pan and zoom always win and hand back after a
pause. Write the fitting as pure math with tests (region → camera pose), then wire it. Include a "look" mode that can
peek beyond the region **only** where the team already has vision.

**X2. Element focus and awareness.** Switching elements (control groups, Tab, or clicking a unit) moves the camera to
that element. Everyone else gets **off-screen markers** on the screen edge (element, health, contact state) and
**alerts** you can jump to ("Bravo under fire", "contact north"), rate-limited. The radar keeps the whole arena; it is
now the main way to read the map, so make it excellent: contacts, last-known enemies, element positions and facings,
click to look, right-click to order.

**X3. Tasks, not geometry (with doctrine's L1).** The command card issues **tasks** (move, attack, screen, support by
fire, hold) to an element, not formations. Show the element's current formation, movement technique and drill with a
one-line reason ("bounding overwatch: contact ahead"). Let the player override the formation, but never require it.
Build against L1's contract with a stub until CP1 lands.

**X4. Command at 30+ units a side.** Selection, groups, the selection panel and the HUD stay readable and fast with
30–60 units: grouped portraits with counts, per-element health, no per-unit spam. Measure input-to-order latency and
frame cost with 60 units selected. Keep a "select all combat units" and "next idle element" key.

**X5. Faction pick in skirmish (with combat's L3).** `make skirmish` takes a faction per side (flag and a simple menu);
army size follows the faction's roster and budget, not a fixed count.

**X6. Readability at close zoom.** With the camera close, nameplates, selection rings, health and order markers must
stay legible without hiding the models; far-out icons matter less now. Re-tune with screenshots at 1920×1080 and
1280×720, and at the new default zoom.

- **Stretch:** a "cinematic" camera mode that follows the fighting on its own for spectating and trailers; smart-cast
  quality of life (a mixed selection right-clicking an enemy sends only units that can hurt it).

## How to verify

`make remote T=check`; your control tests with real mouse and keyboard events; a playtest script that drives a match
with 30 a side, switching elements, with screenshots **looked at**; a short written description of what the player can
and can't see at the new default zoom, and what it costs to see more.

## Don't touch

Doctrine data and element leaders (doctrine), weapons, suppression and rosters (combat), brains (ai), audio (audio).

## Status

_Round 4, control stream. **All six backlog items and the stretch are done.** Updated 2026-09-16._

### Plan (backlog in order)

1. **X1 vision-framed camera (L4).** `VisionRegion` (pure math: sight discs, contains/clamp/bounds) →
   `RtsCamera.frame_vision` + a continuous `Track.VISION` mode reusing the existing speed-limited tracking →
   the zoom-out cap (`vision_zoom`) the wheel and Tab both obey → manual override with a timed hand-back →
   "look" panning clamped to the team's vision.
2. **X2 element focus and awareness.** Off-screen edge markers + a rate-limited alert feed you can jump to; the
   radar becomes the map (contacts, last-known, element facings, click to look, right-click to order).
3. **X3 tasks not geometry.** Command card issues tasks; shows the element's formation/technique/drill and a
   one-line reason, read through an `ElementView` adapter that stubs L1 until CP1 lands.
4. **X4 command at 30+ a side.** Grouped portraits with counts, per-element health, latency and frame-cost
   measurements at 60 selected, "select all combat units" and "next idle element".
5. **X5 faction pick in skirmish** (needs combat's L3; stub `Units.roster` behind an adapter until CP2).
6. **X6 readability at close zoom.** Re-tune rings, nameplates, bars, markers at the new default zoom, 1920×1080
   and 1280×720 screenshots.

### Decisions (with reasons)

- **The brief's `max_zoom_in` is implemented as a zoom-out cap** (`RtsCamera.vision_zoom`). In this codebase
  `zoom` runs 0 = close to 1 = high, and the rule the lead asked for ("a bird's eye view is just an unearned god
  view") is a limit on how far *out* you may go, not how far in. Zooming in closer than the auto frame stays free:
  it costs you awareness, which is the player's call.
- **Two zooms from one region.** The auto frame fits the commanded element's units, its spotted contacts and its
  destination ("as close as possible"); the cap fits the same units' *sight discs* ("the same horizon as what all
  units can collectively see"). Both are `frame_pose` on different point sets, so the math is shared and testable.

### Done

**X1. The vision-framed camera (L4).** Done, `make remote T=check` green (668 tests), playtest green at
1920×1080 and 1280×720 with all nine checks, frames looked at.

- `VisionRegion` (`game/control/vision_region.gd`): the ground a set of units can see, as the union of their
  sight discs. `contains`, `clamp_point`, `bounds`, `center` - pure math, no engine state.
- `RtsCamera.vision` (a `Callable` returning `{frame, destination, region}`) drives a new `Track.VISION` mode
  that keeps the commanded element framed through the existing speed-limited tracking, so it never whips.
  `RtsControls.vision_state` / `commanded_units` supply it: the selection, else the group last recalled, else
  the whole force; plus the contacts that element can see and where it is headed.
- **The zoom-out cap.** `seen_fraction` samples a 5×5 grid of screen points onto the ground and asks the region
  how many it can see; `horizon_zoom` binary-searches the furthest zoom keeping 70% of the screen over seen
  ground, floored at 0.35. The wheel, keyboard zoom, framing and Tab all obey it.
- Manual pan/zoom/rotate always win, hold the camera for `handback_seconds` (2.5), then it returns; recalling a
  group takes it back at once. Free panning is clamped to ground the team can see (the "look" mode).
- **Tab** now shows everything the force can see instead of the whole arena.
- `--no-vision-camera` opts out (galleries, comparisons); `CONTROL_FLAGS=` passes it to both playtest targets.

**Measurements.** Zoom-out caps: lone 40 m-sight unit **0.35**, two 80 m units **0.58**, the five-unit test force
**0.62**, a force spread across the arena with 90 m sight **0.81** (1.0 = the old arena overview, 0.92). Auto
frame for a four-unit element in the skirmish: **zoom 0.33**, camera 35 m up, ~95 m of ground front to back.

**What the player can and can't see at the new default zoom.** Commanding one element, the screen is about
95 m deep: the element fills the middle, its own vehicles read as models (hull, turret and paint are legible,
not icons), and the fog boundary is usually just inside the screen edges. You cannot see the other half of the
arena, your other elements, or anything your force has not spotted. To see more you either switch element
(instant, free - the camera goes there), scroll out to the cap (which buys maybe 40% more ground and only as
much as your force already sees), or spend a scout: pushing a 110 m-sight unit forward is what actually moves
the cap up, because the cap is derived from the force's own sight. That is the intended cost.

**Known issues / notes.**
- The cap is recomputed every 6 frames; at 60 units its cost still needs measuring (X4).
- `separated_unit_rejoins` in the playtest is skipped when every survivor is in contact. The playtest uses
  wall-clock timers, so which units survive varies run to run; the check now says so instead of failing.
- `relay-smoke` and the announcer's `test_mixdown_places_parts_fillers_and_cuts` both failed once under
  builder0 load and passed in isolation. Neither is in control's paths; both reported to the orchestrator.

**X2. Element focus and awareness.** Done, `make remote T=check` green (675 tests), playtest green at both
sizes, frames looked at.

- `ElementAwareness` (`game/control/element_awareness.gd`): one entry per control group - name, survivors,
  strength, middle, and state (idle / moving / contact / under_fire / lost, worst wins). Bad state changes raise
  an alert with a place attached, rate-limited per element and kind (8 s). A wiped element lingers 10 s so
  "Bravo wiped out" has something to point at.
- `EdgeMarkers` (`game/ui/edge_markers.gd`): every element you aren't watching gets a chip on the screen edge
  (arrow, name, survivors, strength bar, colour by state); clicking one selects it and takes the camera. The
  chips stay clear of the command card (the bottom 22% is the HUD's).
- One centred alert prompt above the group chips: the newest unseen alert plus a count, `[Q]` to jump. **Q**
  selects that element and moves the camera. Contact bearings are measured element → enemy, not from the base.
- Clicking or boxing a selection takes the camera to it, so switching elements always moves the view.
- `ControlGroups` keeps a label per group from the doctrine squad's name ("Bravo", not "Group 2").
- The radar is now the map: facing ticks on friendly blips, element numbers at each element's middle, the
  selected element ringed, last-known contacts still fading, click to look, right-click to order.

**X3. Tasks, not geometry (L1).** Done, `make remote T=check` green (787 tests after merging CP1+CP2),
playtest green with all ten checks.

- Skirmish installs `Elements`. **A player element is formed by the first task given to a control group and
  dissolved by any direct order.** An element with no task still runs its SOP, so pre-forming one per squad had
  untasked leaders fighting the player for the wheel: it broke K1's response guarantee and ate a shift-queued
  route before doctrine's per-unit detach could see it. Forming on demand keeps round 3's direct control intact.
- A whole element selected → right-click, A, H and the command card issue L1 tasks; an ad-hoc handful of units
  still gets direct K1 orders. Attack-move maps to a `move` task (an element on the move already runs
  react-to-contact). **E** screens a flank, **R** sets a base of fire; both greyed out without an element.
- The command card reads back `element.describe()` under the header ("Alpha: wedge, traveling"), and is now 4×2.
- **G** still overrides the formation, and an override drops that order back to explicit geometry.
- **K1 gains an optional `source`** (`"player" | "element" | ""`, default `""`, additive). Control tags its own
  orders; the playtest was otherwise timing doctrine's formation-slot orders against the player-response
  guarantee. Relayed to the orchestrator for `workstreams.md`.
- `--no-elements` keeps squads hand-driven; `--element-cpu` runs the CPU on `ElementCommander` (off by default).

**X4. Command at 30+ units a side.** Done, `make remote T=check` green (792 tests), measured, and looked at
at 28 vs 29.

- The selection panel groups portraits by **type** above ten units, each with a count, plus one strength number
  in the header ("28 UNITS  IDLE  99%" over ×15 Tanks, ×7 IFVs, ×6 Lancers). Clicking a grouped portrait selects
  that type; below ten units every unit still gets its own.
- **ctrl+A** selects the whole army; **F2** goes to the next element with nothing to do.
- **Measured at 30 a side** (60 units on the field, 30 selected), headless on this laptop:
  box-select the army **1.38 ms**, right-click → 30 orders **1.87 ms** (all on the click's own frame),
  `order_selection` **1.65 ms**, and control's per-frame work **1.685 ms** (vision_state 0.355, awareness 0.595,
  panel summary 0.511, edge markers 0.017, horizon_zoom 1.244 amortised over 6 frames).
  `tests/test_control_scale.gd` holds these to a 2 ms frame budget and an 8 ms order budget.
- Two hot spots were found and fixed: the panel's sort comparator did a node lookup per comparison (1.53 → 0.51
  ms) and `ElementAwareness` scanned the tank list once per member (1.07 → 0.60 ms).
- `make control-scale-shots` runs the session with ~30 a side. Deliberately not pass/fail: with a faction-sized
  army nobody is commanding, the player's force loses and steps needing a live group 1 report false.

**X5. Faction pick in skirmish (L3).** Done, playtested headless (44 gangs vs 17 syndicate), menu looked at.

- `--player-faction=` / `--enemy-faction=` turn a side into a faction army. Either raises the default budget to
  `Units.BASELINE_BUDGET`, so **size falls out of the roster**: Road Gangs **44**, Condemned **27**, Law **24**,
  Syndicate **17** - the lead's ordering, asserted in the test. `--budget` still wins. (The match runner spells
  these `--green-faction` / `--rust-faction`; here they follow `--player` / `--enemy`.)
- `FactionPicker` (`game/ui/faction_picker.gd`): shows what each faction actually fields at the match budget -
  count, points per vehicle, composition. 1-4 yours, shift+1-4 theirs, click / right-click, Enter fights.
  Picking restarts the skirmish with the flags, so the armies come from the same code path as the command line.
- The menu opens on an interactive run that named no faction, and **never** in a headless, scripted, playtest,
  touch-map or smoke run. `--pick-faction` forces it, `--no-pick-faction` suppresses it.
- `make skirmish-factions FACTION=gangs ENEMY_FACTION=syndicate`, `make faction-menu-shot`.

**X6. Readability at close zoom.** Done, looked at at 1920×1080 and 1280×720 and at 25 vs 27.

- A thin **hull bar** over our vehicles that are hurt or selected, and nothing else (a bar over every healthy
  vehicle at 30 a side is noise). Above the hull, sized from the hull's own width on screen (14-62 px), fading
  towards the enemy colour as it gets serious, with a shield sliver. Measured 62 px close, 16 px far;
  **0.131 ms** a frame for 30 bars. This is where "which of mine is nearly dead" lives now that X4 grouped the
  panel's portraits.
- The doctrine line ran off the bottom of the panel at 1280×720; the panel now reserves a footer strip for it.

### Stretch. Done.

- **A cinematic camera** (`game/camera/cinematic_camera.gd`, `--cinematic`): it works in **shots**, not drift - a
  camera that chases the best point every frame is a nervous mess. Each shot frames one cluster and is held for
  6 s; something clearly better interrupts after 2.5 s; a long move is a **cut**, not a glide over dead ground.
  Scenes score both sides in one place highest, then vehicles just hit, then how many are in frame. It replaces
  the vision framing and ignores the L4 cap: nobody is earning this view. `make cinematic`, `make cinematic-shots`.
- **Smart-cast for a mixed selection** already shipped in round 3 (`RtsControls.smart_attack`); X3 keeps it for
  ad-hoc selections, while a whole element gets an attack task and its leader works out who shoots.

### Decisions (with reasons)

- **`max_zoom_in` is a zoom-out cap** (`RtsCamera.vision_zoom`): `zoom` runs 0 = close to 1 = high here, and the
  rule the lead asked for is a limit on going *out*. Zooming in past the auto frame stays free - it costs
  awareness, which is the player's call.
- **The cap measures seen ground, not a bounding box.** Bounding-boxing the sight discs said a five-unit force
  could see a 250 m box and earned zoom 0.94, which is no cap at all. `seen_fraction` samples the screen onto the
  ground and asks the region; the cap is the furthest zoom keeping 70% of the screen over seen ground.
- **Elements are formed by the first task and dissolved by any direct order.** `Element.update` commands its
  members even with no task, so pre-forming one per squad had untasked leaders fighting the player for the wheel.
- **Attack-move maps to a `move` task** for an element: an element on the move already runs react-to-contact.
- **Faction flags follow `--player` / `--enemy`**, not the match runner's `--green` / `--rust`, so one skirmish
  command reads consistently. The menu never opens in a headless, scripted, playtest or smoke run.

### Questions for the lead

1. **How close is right?** The default frame is ~95 m of ground with the camera 35 m up. That is the Twisted
   Metal end of the spectrum you asked for, and you cannot scroll out past your force's horizon. If it is still
   too far or now too close, `VISION_FRAME_INSET` and `VISION_SEEN_FRACTION` in `game/camera/rts_camera.gd` are
   the two dials, and `--no-vision-camera` gives you round 3's free camera to compare against.
2. **Is one alert prompt enough,** or do you want the last three on screen? It started as three lines and landed
   on the HUD's message column, so it is one line plus a count now.
3. **The faction menu opens on `make skirmish`** when you name no faction. If that gets in the way,
   `--no-pick-faction` skips it and I will make that the default.

### Requests to other streams

- **art / theme (no stream this round) - blocks the scale goal.** At ~30 a side the renderer runs out of
  per-instance shader uniform slots: *"Too many instances using shader instance variables … Maximum items
  supported by this hardware is: 4096"*, 339 errors in one `make control-scale-shots` run. Raising `buffer_size`
  cannot help - 4096 is the hardware maximum - so the vehicle materials need fewer per-instance uniforms
  (`game/theme/cyberpunk/{unit_skin,weapon_cannon,dozer_part}.gd`,
  `game/theme/fx/shaders/{unit_body,vehicle_glow,shield}.gdshader`). Reported; the orchestrator has it in HANDOFF
  and combat hit it independently.
- **doctrine:** `Element.update` commands its members even when `task == {}`. Control forms elements lazily to
  work around it; anyone else adopting L1 will hit the same edge. (Relayed - now noted in workstreams.md.)
- **doctrine (their request (a)):** an optional `facing` in `UnitCommand`, to remove the halt-formation hack where
  each vehicle drives a few metres along its sector to end up pointing the right way. It is control's file and it
  is **not done** - a clean next-round item.
- **ai:** the CPU still runs its squad AI in skirmish; `--element-cpu` wires `ElementCommander` in for
  experiments. Which commander the CPU runs is ai's call.

### Known issues

- None outstanding. The last check is **fully green: 843 passed, 0 failed, exit 0**, on main as of `06875d5`
  (ai's avoidance fix and the new sim baseline `d4bd86eee0f96c54`), including `sim-baseline`, `determinism` and
  every smoke test. Earlier checks on this branch reported `test_ai_scenarios::test_a_unit_ordered_across_a_
  swept_lane_keeps_out_of_the_fire`; that was ai's, and their fix is merged.
- The faction menu is the only new screen and it has no gamepad or touch path. Desktop first (pillar 5).
- `separated_unit_rejoins` in the playtest reports "skipped" when every survivor is in contact or the pushed unit
  is destroyed on the way home. The playtest uses wall-clock timers, so which units survive varies run to run.

### What to playtest (exact commands)

```bash
make skirmish                       # the faction menu, then the vision camera, elements and tasks
make skirmish-factions FACTION=gangs ENEMY_FACTION=syndicate   # 44 vs 17
make cinematic                      # watch a CPU-vs-CPU match direct itself
make remote T=control-playtest-shots   # frames at 1920x1080 and 1280x720
make remote T=control-scale-shots      # ~30 a side
make remote T=cinematic-shots          # trailer frames
```

In a match: **1-5** picks an element and the camera goes to it; **right-click** gives it a task and the command
card tells you what its leader chose; **E** screens a flank, **R** sets a base of fire; **Q** jumps to whoever is
in trouble; **ctrl+A** takes everything; **F2** finds whoever is idle; **Tab** shows your force's horizon; **G**
overrides the formation if you disagree with the leader.

### Next steps

1. `facing` in `UnitCommand` (doctrine's request (a)).
2. The renderer's per-instance uniform limit, once `game/theme/**` has an owner - it is what stops 30 a side from
   *looking* right.
3. Touch: the whole round-4 grammar is desktop-only. `--touch-map` still runs round 2's tap grammar unchanged.
4. The lead's answers to the three questions above are dials, not rewrites.

### Merge notes (shared files)

- `game/modes/skirmish_mode.gd` (control's): new flags `--player-faction`, `--enemy-faction`, `--pick-faction`,
  `--no-pick-faction`, `--no-vision-camera`, `--no-elements`, `--element-cpu`, `--cinematic`; installs `Elements`
  and wires the vision camera.
- `mk/command.mk` (control's): `CONTROL_FLAGS`, `control-scale-shots`, `cinematic`, `cinematic-shots`,
  `faction-menu-shot`, `skirmish-factions`; the windowed playtest's timeout is 420 s.
- **K1 additive change:** `UnitCommand` and each stored order gain an optional `"source"`
  (`"player" | "element" | ""`, default `""`). Doctrine's `Element._issue` needs no change. Documented in
  workstreams.md by the orchestrator.
- No shared-file edits outside my paths: `project.godot`, `game/main.gd`, `Makefile`, `mk/core.mk` and
  `game/theme/**` are untouched.
- The **sim baseline is untouched** (control must not change it): nothing here runs in `--match`. Verified, not
  assumed - the final check reached `sim-baseline passed: d4bd86eee0f96c54 (glibc-2.43)`. (An earlier draft of
  this report claimed that from a check that had stopped at a failing test before reaching the step.)
