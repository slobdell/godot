# Stream: control (the desktop grammar that makes a facing real, the A6 readout, and the view against a resized roster)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 9 direction*, *ANSWERED: why he could not tell which way his units were facing*, *Controlling units*),
> [workstreams.md](../workstreams.md) (*Round 9: the seven streams*, contracts **S1**, **S4**, checkpoints **CP1–CP3**),
> [research_catalog.md](../research_catalog.md) row **A6**, and your round-8 brief in
> [archive/round8/control.md](archive/round8/control.md) — its Status is where you left off.
>
> **You own** `game/control/`, `game/ui/` (HUD, widgets, title, loading), `game/camera/`, `game/controllers/`,
> `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md`, and the control tests
> (`tests/test_control_*.gd`, `tests/test_rts_camera.gd`, `tests/test_camera_looks.gd`, `tests/test_command_camera.gd`).
> **Shared contracts you sign this round:** S4 (`_agents/legibility.md`, feel authors, you and nav sign) and the K1
> `facing` field, which you *issue* from now on rather than only read.

## The lead's direction (2026-09-19)

The round-9 items are the orchestrator's, from his round-8 playtest and the research review; his own words that bear on
this stream:

- Round 7: *"I couldn't tell what direction they were facing."* Round 8 answered the value being dropped and the brain
  ignoring it (game_design.md *ANSWERED*). What round 8 did **not** answer is that **his controls never send one**.
- Round 8: *"they still generally don't do what I command them."* Catalogue A6 reframes this as a motion problem
  (30–36% of attack-move time is spent driving somewhere other than the ordered destination — *correctly*) that needs a
  **readout** so a deliberate off-axis leg does not look like disobedience.
- Round 9, on sizing (game_design.md *Round 9 direction* §2): *"We need to do proportional, real-world relative sizing
  for all of our vehicles."* That is scale's build; **its consequence for you is the view**: everything you draw around
  a hull was calibrated against 3–5 m vehicles, at his 35° telephoto.

## Where things stand

- **The arrive-on-heading arc has no caller in the game he plays** (HANDOFF.md *Three claims on main that are weaker
  than their commit messages say*; found by you at round-8 close). A `facing` enters a move command in exactly one
  place, `game/ui/tactical_map.gd:262-270` — `order_drag(from, to)`: press = destination, a drag of at least
  `MIN_FACING_DRAG` (4.0 m, `tactical_map.gd:34`) = the facing. That map is behind `--touch-map`. His desktop controls
  are `RtsControls`, whose right button (`game/control/rts_controls.gd:353-360`) calls `right_click_order` on **press**
  (`:761-777`) and issues a bare `move`; `facing` is only ever *read* there (`selection_facing`, `:293-307`, for camera
  yaw and the pin). So nav's `_arrive_facing` never executes in play — its round-8 A/B read `gates aimed 0, refused 0`
  in **both** arms — and nobody can measure the arc until you give the desktop the touch map's grammar.
- **`Orders` already carries it end to end:** `orders.gd:154-155` copies `command["facing"]` into the base order,
  `:312-321` normalises it, `:373` reads it back. Nothing below you needs to change; this is a `RtsControls` job.
- **Left button already has a press/drag/release state machine** (`_press_at`, `_boxing`, `DRAG_THRESHOLD_PX` 6.0,
  `rts_controls.gd:30,363-368,371-396`). The right button has none: it acts on press and ignores release. The
  disambiguation you must keep: a **left** drag is a box-select; a **right** drag must never become one and must never
  be eaten by an armed-mode cancel (`disarm()` on right press, `:356`).
- **The order pin** (`_draw_order_marks`, `:1299-1330`) draws a stalk and the task symbol; **the facing chevrons**
  (`_draw_facing`, `:1360`, from `facing_marks()`, `:1338`) draw the *selection's* current facing, not the ordered
  one. A pin for a move with a facing has nothing that shows which way the unit will arrive.
- **Camera:** the lead's pose is `DEFAULT_PITCH_DEG` 21°, `FOV_DEG` 35 (`game/camera/rts_camera.gd:37,59`); the
  vision-framed lean parks the bottom of the frame at `VISION_FRAME_BOTTOM` 0.40 (`:147`), a constant that **mirrors**
  the command card's height in another of your files (round-8 Status, *Invariant 0*). `camera-looks`
  (`mk/command.mk:157-172`) photographs one frozen fight from a pitch × distance × FOV grid and every arena into
  `build/camera-looks/index.html` — it is the tool for item 3.
- **Radar** blips are a fixed 32 px texture scaled per mark (`game/ui/radar.gd:20,268,358-359`): nothing about a
  blip reads the hull it stands for.
- **`shell-playtest`** (`mk/command.mk:98-114`) walks title → skirmish → a minute of battle through real clicks and
  **fails on any console ERROR/WARNING** except two allow-listed lines. It is **not in `check`** (`mk/core.mk:85`), so
  `main` went green at `2fa58c01` with two `Texture with GL ID … leaked 5460 bytes` lines it would have caught
  (HANDOFF.md *Open questions*; routed to feel, since fixed once, and the class of failure is still invisible to the
  gate). Lesson 42 applies: **do not add a red suite to the gate** — record its expected state and fail on change.
- Round 8 left green at `1b3da573` (builder0, 1233 passed) with `39a61b86` (camera-looks wall frames) unchecked after
  it; both are on `main`. Owed from that Status: `VISION_FRAME_BOTTOM` read from the card rather than copied; the
  round-7 "not started" list (order-preview HUD, FOV tied to weapon range) stays parked unless an item below needs it.

## Backlog (in order)

Each item: the failing test first, then the build, then `make remote T=check`, then **frames you look at**.

1. **Desktop right-drag facing — the live arm, by construction.** Give the right button the left button's state
   machine: press records the ground point (destination); a drag past `DRAG_THRESHOLD_PX` on screen *and* past a world
   distance you choose (start from the touch map's 4.0 m, then judge it at 21°/35° where 6 px near the horizon is many
   metres) makes the release point the **facing** (`[dx, dz]` from destination toward release); a release inside the
   threshold is today's plain move. Shift queues as now. An armed mode still cancels on right *press* (`:356`) — decide
   whether a drag while armed does anything, and write it down in `_agents/tactical_map.md`'s grammar table either way.
   **Tests, written first, in `tests/test_control_orders.gd` or a new `test_control_facing_drag.gd`, through the real
   input pipeline** (`Viewport.push_input`, the way `test_control_selection.gd` does it; `tree.root.size =
   Vector2i(1280, 720)` first — orientation trip-up 31): (a) after a right press-drag-release on ground,
   `orders.current(unit)` has `"facing"` and it points from press toward release; (b) after a right click with no
   drag, `orders.current(unit)` has **no** `"facing"` key (the absence is the half that keeps every old test honest);
   (c) a right drag never changes the selection and never opens a box (`selection.units` unchanged, `_boxing` false);
   (d) at the lead's pose (pitch 21°, FOV 35, his default distance) a drag of a few px near the horizon and a drag of
   the same px near the bottom of the screen both resolve — or the near-horizon one is refused with a reason, never
   silently a plain move. Mutation-check (a): remove the facing assignment and (a) must fail.
   **The pin:** draw the ordered facing on the move pin (a short arrow from the ring, the same chevron language as
   `_draw_facing`) so he can see the heading he asked for before the unit gets there; `test_control_order_marks.gd`
   asserts the mark carries the facing. **Look at it** in `make remote T=control-playtest-shots` frames at 1920×1080
   and 1280×720 with a drag added to `control_playtest.gd`'s script.
   **The day it is green: message the orchestrator and nav with the hash.** nav's arrival-arc A/B needs this arm and
   must not be re-run against a plain `move` (HANDOFF.md: *do not re-measure zero twice*). Ask the orchestrator to
   merge it as a checkpoint if nav is waiting.
2. **S4: sign `_agents/legibility.md`, then build the readout it specifies.** feel writes the page (the motion law:
   a turreted hull fighting off-axis keeps its nose within ~25° of the corridor tangent; a hull-fixed vehicle bounded
   forward-oblique), nav names where it executes; **you own what the player is shown**. Your half of the signature is a
   concrete spec: for a unit whose velocity currently opposes its corridor tangent, what tells him *"this is the plan"*
   (a leg marker, the pin's colour, a card line) versus *"this is a refusal"* (which already turns a pin red,
   `rts_controls.gd:1307`). Reuse `MovementReadout` and `ElementLog` (the "why did my element do that" line) before
   adding a widget. Until all three have signed, **write no A6 motion code and no readout code** — the bar in the
   catalogue (opposing-tangent time 30–36% → under 10% with no fall in exchange ratio) is measured by metrics' A12 after
   CP1, not by you. Test: the readout distinguishes a deliberate off-axis leg (nav's state says so) from an unreached
   goal, on a scripted scenario; no readout for a unit on its corridor.
3. **The camera inside a Terminus block — forced outside the solid** (added mid-round 2026-09-20, the lead, by the
   orchestrator; game_design.md *Round 9 addition*). His words: *"In the Terminus map it's highlighting another problem
   where the camera often ends up inside a building and we can't see what's going on inside the alleyways. We need to
   make it so the camera is forced outside the solid for these cases."* The blocks are the kit's `StaticBody3D` boxes.
   **Read his sentence as two faults, not one:** the camera *inside* a solid (he named the mechanism) and the alley
   *unseen* (he named the symptom) — and fixing only the first can make the second worse, which is the case the
   frames must show.
   **Mechanism, decided (change it only with frames):** (a) **push out, hard.** After the rig has its pose, query the
   camera point against the arena's static blocks; if it is inside one, shorten the boom along `focus → camera` to
   just outside the solid, keeping a standoff of at least the near plane so the near plane is not inside a wall
   either. The boom shortens; **the pitch and FOV he chose are not touched** — round 6's rule is that the camera
   overrides his tilt in exactly one place (the far-range floor) and that place is flagged to him, so this must not
   become a second one. (b) **Then, if the sight line `focus → camera` is still blocked, cut away the occluder** the
   way the perimeter wall already is, rather than lifting the pitch: lifting brings back the top-down view in the one
   place he is guaranteed to be looking. (c) **Expose what was cut** (`RtsCamera.cutaway_blocks()` or equivalent) —
   contract **S6** says a lighting cue must not fight the cutaway, so the new `show` stream reads this signal rather
   than guessing; tell show the exact shape the day it exists.
   **Test** (first): after a follow and after a pan across the Terminus, the camera is **never inside a block's box**,
   asserted against the layout's own boxes, sampled every frame of the move and not only at the ends. Plus: the push
   never puts the camera closer than `MIN_DISTANCE` without saying so, and a camera in the open is untouched
   (mutation-check: disable the push and the Terminus test must fail while the open-arena one still passes).
   **Frames you look at:** `make remote T=camera-looks CAMERA_LOOKS_ARENA=terminus` and
   `control-playtest-shots` at **his pose (21°, FOV 35, 49 m)** in the alleys — before, after, and **the case where
   pushing the camera out hides the alley**, with how it was handled written under it. Do not shoot these at 12°.

4. **After CP2 (the resized roster is on `main`): the view at his pose.** `git merge main`, then `make remote
   T=camera-looks` and `control-playtest-shots`, and look: selection rings and boxes on a hull two to three times
   longer; the command card's `VISION_FRAME_BOTTOM` lean (now derive it from the card's geometry — the round-8 Invariant
   0 item — instead of the 0.40 copy); radar blips against 8–14 m hulls (a blip should read the hull's length class,
   not one size); the cutaway against a taller hull near the wall; zoom limits (`MIN_DISTANCE` 16 m may now be inside
   a War Rig); the auto-frame and vision floor (`VISION_FLOOR_M` 45, `AUTO_FRAME_MAX_M` 100) with a squad that is
   physically wider. Fix what the frames show, one commit each, and put the strip in `build/camera-looks/` for the
   orchestrator with the commit and machine in its README. **Nothing here is published before CP2** — a frame of the
   old roster is a frame of a game he will not play again.
5. **`shell-playtest`'s console gate into `check`, behind a committed baseline.** It needs a display, so it runs
   under `remote` on builder0 (`tools/remote.sh` handles Xwayland; trip-up 65). The gate as written fails on *any*
   ERROR; lesson 42 says the honest first step is a committed expected state (`tests/baselines/shell_console.txt`, the
   allow-listed lines and their counts) and failure only on **change** — then tighten. This is what makes the next
   texture leak visible to the gate rather than to whoever happens to run a windowed playtest. Ask the orchestrator
   before touching `mk/core.mk`'s `check` line (shared; metrics is rewriting that recipe for T1 — coordinate so your
   target lands in their parallel form, not the serial one they are removing).
6. **Stretch:** after squad's A10 lands, re-check on the **default path** (`make skirmish`, not a test flag) that the
   `ungrouped=N` readout (`game/modes/skirmish_mode.gd:327`) reads 0 and that the ignored-order banner still fires for
   each refused-order class you wired in round 8. Lesson 149: a behaviour behind a flag has not shipped.

## How to verify

- `make remote T=check` — read the wrapper's `>> remote: make check exited <N>` and the runner's `N passed, M failed`,
  never a shell exit code through a pipe. Name the green hash when you report.
- `make control-playtest` (headless, every order's response tick — K1's 100 ms guarantee is asserted here; a facing
  drag must not add a tick); `make remote T=control-playtest-shots`, `T=camera-looks`, `T=shell-playtest`.
- Every screenshot you produce, you look at — desktop and phone aspect. Every number carries its commit and machine
  (laptop ≈ 2.75× slower than builder0).
- Windowed runs open on the lead's desktop (trip-up 32): prefer headless; say when a windowed run is coming.

## Don't touch

nav's motion (`game/ai/{movement,combat_motion,steering}.gd`, `game/tank/tank_motion.gd`) — you *issue* a facing, nav
*executes* it; squad's brains and `game/tactics/`; the roster values (`hull_size`, `muzzle_height` are **scale's** this
round, `game/units/units.gd` is combat's); feel's theme (`game/theme/**`) — the airship and the trailer are feel's;
`mk/core.mk`'s `check` recipe and `tools/slot.sh` (metrics', for T1) except by agreement in item 4.

## Waiting on the lead

Nothing at start. If item 1's threshold (how far a right-drag must travel before it means a facing) turns out to be a
feel question rather than a geometry one, put two frames on the orchestrator's decisions page rather than asking him
directly.

## Status

_Round 9, control stream. Branch `stream/control`, started from `main` at `9f864474` (2026-09-20)._

### Plan (order, with reasons)

1. **Item 1, desktop right-drag facing** — the only item with no dependency, and the prerequisite for nav's
   arrival-arc A/B (which currently measures zero in both arms). Tests first, then the state machine, then the pin.
   **Done; green hash below.**
2. **Item 2, S4** — the signature first (it is a gate on three streams), then the parts of the readout that do not
   need nav's new field. **Signed by all three 2026-09-20.** C-1 (the corridor drawn, current leg at full weight) is
   built; C-2's attribution waits on nav's `legibility.why` key, and no verdict before CP1.
3. **Item 3, the camera inside a Terminus block** — a new lead item from play, which outranks a scheduled re-check.
   Independent of CP2 (blocks do not resize), so it can be built before it; the frames go out after CP2 if it has
   landed, else with the roster named in the README.
4. **Item 5, `shell-playtest`'s console gate behind a committed baseline** — independent of both checkpoints; the ask
   went to metrics early and is answered (`check-display` as its own bundle, not in `CHECK_TARGETS`).
5. **Item 4, the view after CP2** — blocked until scale's roster merges. Nothing published before it.
6. **Item 6 (stretch)** — after squad's A10.

### Decisions

- **The facing-drag threshold is in PIXELS (18 px), not metres.** This is the one real decision in item 1 and the
  brief left it open. The touch map uses 4.0 m because a top-down map has one scale; the play camera does not. At the
  lead's pose (21°, FOV 35, 49 m) an 18 px drag spans **~0.3 m near the bottom of the frame and ~40 m near the top** —
  a hundredfold. A threshold in metres makes the same hand movement a facing near the horizon and a *silent plain
  move* near the bottom, which is the one outcome the brief says the gesture must never have. The gesture is made by
  a hand on a screen, so the threshold is the hand's; the metres only have to be non-degenerate
  (`FACING_DRAG_MIN_M` 0.05), and the **direction is exact at either end of the screen** (it is the projection of an
  exact screen ray onto the ground plane). `test_control_facing_drag.gd::test_the_same_hand_gesture_means_the_same_
  thing_anywhere_on_his_screen` pins it at his pose. 18 px = 3× the left button's jitter guard: a wrong facing costs
  a manoeuvre, a wrong box costs nothing.
- **An enemy under the right press is attacked on the PRESS, drag or no drag.** An attack takes its heading from its
  target, so there is nothing for a drag to say — and deferring would add release latency to the commonest urgent
  order (K1). Only a press on **ground** starts a facing drag.
- **A drag while an order is armed does nothing; the cancelling press is spent.** The brief asked for this to be
  decided and written down either way (`_agents/tactical_map.md` v7). The player's hand is mid-cancel, not
  mid-order, and an order he did not mean is worse than a gesture he has to repeat.
- **A release with no ground under it falls back to the last ground the drag crossed** (dragging up past the horizon),
  rather than refusing. The heading the player drew is still the one that got there, and a refusal would also lose the
  move he asked for. The facing is computed from **unclamped** ground points (`ground_under`), because clamping a
  direction's far end to a wall bends the heading — or, drawn outward next to a wall, collapses it onto the
  destination and loses it. Destinations still go through `screen_to_world`, which clamps as it always did.
- **A differing `facing` makes it a different order — for the player's orders only** (`Orders._same_order`, shared
  file, in merge notes). Right-clicking a spot and then right-dragging *the same spot* to correct the heading was
  being dropped as a repeat: the one case where the new gesture would look ignored. Element leaders re-issue from a
  heading that drifts as the element turns, so machine re-issues keep today's dedup exactly and round 8's
  idle-command numbers cannot move.
- **The formation heading stays the travel direction, not the ordered facing** (`Orders._resolve_group`). An
  emplacement gesture arguably wants the *line* laid out across the kill zone, but that changes the geometry of every
  facing-carrying order including squad's, and item 1's job is to make the arm live, not to re-shape formations.
  Recorded as a question, below.

### Progress

| Item | State | Evidence |
|---|---|---|
| 1. Desktop right-drag facing | **built, green on the control suite (187 passed) and on the full local `make test`**; `make remote T=check` next | `tests/test_control_facing_drag.gd` (7, through `Viewport.push_input`), `test_control_order_marks::test_a_dragged_order_puts_its_heading_on_the_pin` |
| 1. the pin | done: a move pin drawn from a facing drag grows a ground arrow in the order's colour (`_draw_ordered_facing`), and the HUD line names it in compass ("3 units: move facing NE") | `order_marks()[i]["facing"]`, `describe()` |
| 1. the live preview | done: while the right button is down, a ring on the destination and, past the threshold, an arrow following the pointer — a player cannot learn a gesture he cannot see | `_draw_facing_drag` |
| 1. frames | **not yet** — `make remote T=control-playtest-shots` with a drag added to `control_playtest.gd` | — |
| 2. S4 signature | **signed by all three 2026-09-20**; feel took C-1–C-4 into §6 verbatim and the arrival-arc warning into §7 as a pre-registered exclusion | `git show 4ec341d2:_agents/legibility.md` |
| 2. C-1 the corridor drawn | done: the **current leg** at full weight, the rest faint; `{}` when nav has no path, and an inactive law draws nothing | `MovementReadout.corridor` / `corridor_tangent`, `test_control_movement_readout` |
| 2. C-2/C-3 the attribution | **built against nav's contract shape, silent until nav publishes it** — which is the correct output, not a stub. Vocabulary degrades to one word because nav has stated `why` can only be `override` while A7 is off | `MovementReadout.legibility_line`, `RtsControls.legibility_notes`, `ElementLog.note` |
| 3a. camera forced outside a Terminus block | **built, green locally, mutation-checked**; frames owed | `tests/test_control_camera_solids.gd`, `RtsCamera.clear_pose` / `roof_over` |
| 3b. the building in the sight line is not drawn | **built**; the pre-registered bar is sight line blocked **518 → under 50** | `BlockCutaway`, `RtsCamera.segment_hits_box`, `test_cutting_the_building_in_the_way_clears_the_alley` |
| 4. the view after CP2 | blocked on CP2 | — |
| 5. `shell-playtest` into `check` | **built**: `tools/shell_console.py` (a committed baseline that fails on CHANGE, in either direction), `make check-display`, `make shell-console-baseline`, `make shell-console-pytest` (5 tests, green). **baseline recorded and committed, and it is EMPTY** — a real run produced 18/18 checks and **zero** console lines, so the gate is now stricter than the allow-list it replaces | `tests/baselines/shell_console.txt`, `tools/test_shell_console.py`, `mk/command.mk` |
| (unasked) `test_control_facing_camera` wall-clock flake | **fixed**: the test owns its clock | 6/6 on three consecutive loaded runs |

**What the mutation check says:** deleting the `facing` assignment in `right_click_order` fails 4 of the 7 new tests
(the brief asks only that (a) fail).

### S4: control's signature on `_agents/legibility.md` (2026-09-20)

Read at `4ec341d2` on `stream/feel`. **control signs §6 as the readout, subject to C-2.** Sent to feel and the
orchestrator; the page is feel's file, so this copy is the record on this branch.

- **Correction to §6.1.** "the lead's 12° and 35° poses" is not his pose. He played 12° and rejected it: *"I was
  totally wrong about the camera, the game is unplayable now with low field of view."* His pose is **pitch 21°,
  FOV 35°, 49 m, auto-frame on**. Frames will be shot there and across the tilt range he can reach (8°–70°).
- **C-1, the corridor drawn.** Most of it exists: `_draw_waypoints` already draws `movement.route(unit)` (N1
  `path_points`, one publisher, never recomputed) faint under the order line. Two changes, no new widget: draw it for
  the selected **element**, and draw the **current leg** at full weight with the rest faint.
- **C-2, attribution — the blocking ask on nav.** §5's `active` boolean cannot say *which* level took the nose, and
  control will not infer the cause from geometry: a guessed attribution is confidently wrong on exactly the ticks the
  player is watching. Asked for one key in `Movement.state(unit)`:
  `"legibility": {"active": bool, "why": StringName}`, `why` in a closed set
  `"" | no_order | no_path | blocked | reflex | style_run | band | survival | armour`. The last three are the level
  1/2/3 overrides; control maps them onto words already on screen (*holding range*, *taking fire*, *front toward the
  threat*) through `ElementLog` and adds no vocabulary. **Without `why`, §6.2 does not get built.**
- **C-3, "this is the plan" vs "this is a refusal" never share a channel.** A refusal already owns one: the pin turns
  red and its label says NOT COMPLYING. So a deliberate off-corridor leg is *the corridor still drawn, the pin still
  the order's colour, and one `ElementLog` line naming the cause* — it never touches the pin's colour, never adds a
  hull callout, and never posts a HUD message (30 units off-corridor at once is 30 messages). The hull callout band
  (`MovementReadout`: YIELDING / BLOCKED / STUCK) stays reserved for *nav cannot proceed*; A6 is a unit that **is**
  proceeding.
- **C-4.** No button, no stance, no toggle. Nothing new on the command card.
- **A warning raised with it, new from this round:** **an arrival arc is off-corridor by construction** at the end of
  every dragged move — that is the unit obeying an explicit order. Now that facings are orderable on the desktop,
  A12 will charge A6's falsifier for exactly the obedience item 1 just shipped, unless the arc's ticks are excluded
  from the off-corridor fraction or counted as ordered. Relayed to feel and the orchestrator for nav and metrics.

### Decided overnight (2026-09-20, the lead asleep; most reversible decent option, recorded rather than waited on)

- **Item 3's mechanism: LIFT the camera over the roof, do not pull the boom in.** Both were available and the numbers
  decided it. At his pose the camera is 17.6 m up and 45.7 m back; the Terminus is 40 × 24 × 40 m blocks with 20 m
  streets. Shortening the boom until it exits collapses **49 m → ~11 m** — below `MIN_DISTANCE`, near-first-person,
  and the far side of the street still walls the alley: *it answers his sentence and not his problem*. Lifting over
  the roof is **21° → 32°**, keeps 41.5 m of horizontal reach, and looks **down into** the alley, which is the thing
  he said he could not see; it is also inside the tilt range he can reach by hand (8°–70°). The boom shortens only
  when even `MAX_PITCH_DEG` cannot clear a roof (a solid taller than the boom is long).
  **Measured** (`tests/test_control_camera_solids.gd`, laptop, `9bb6d143` + tree): every open ground point on the
  Terminus × 8 yaws at his pose = 4328 poses; **703 had the camera inside a building, 0 after, worst lift 11.0°,
  nothing pulled in.** The yard is provably untouched. Mutation-checked: disable the lift and the Terminus test fails
  while the open-arena one still passes. **Reversible:** one constant loop-bound; the pull-in path is already written
  and tested, so swapping the preference is a few lines if the frames say otherwise.
- **The honest second number, and it is not a cure.** His sentence has two halves — the camera *inside* a solid, and
  the alley *unseen* — and the lift answers the first completely (703 → 0) but the second only partly. Measured over
  the same 703 poses (`test_control_camera_solids`, laptop): the sight line from the camera to the ground it is
  aimed at was blocked by a building in **700 of 703 before and 518 after — a 26% reduction, not a fix.** The
  remaining 518 are cameras that are correctly outside every solid and still looking at the side of one. **So the
  occlusion half is probably still owed**, and the frames decide it: if the alley reads at his pose in
  `build/terminus-alleys/index.html`, the lift is enough; if it does not, the next step is the per-block cutaway,
  which the orchestrator has already ruled the shape of (per-block visibility/alpha, never an emission or show
  channel, named in merge notes and on `_agents/lighting.md`'s reserved list) and which `RtsCamera.sight_blocked`
  is already the primitive for. **Do not claim the item is finished on the 703 → 0 number alone.**
- **The cutaway is VISIBILITY, not a fade, and that is a constraint-driven choice rather than a preference.** S6's
  seam gives control alpha and visibility and gives `show` emission and channels. A per-block *alpha* would have to
  be an `instance uniform` on `city_block.gdshader` — **show's file**, and one static ShaderMaterial shared by all
  eight blocks — so taking it meant either editing their shader or blocking overnight on them adding one. Hiding the
  block body's `VisualSlot` needs no uniform, cannot collide with anything show writes, and is one boolean to revert.
  **control reserves nothing on the block material**, and a cut block keeps its cue underneath: it is not drawn while
  it is in the way and is drawn again mid-cue when it is not. `BlockCutaway.cut_blocks()` is the signal show reads.
  If the frames say a hard cut reads badly, the next step is to *ask* show for the instance uniform, not to write one.
- **Cover is never cut** (`MIN_HEIGHT_M` 6 m). A container between the camera and the fight is *information* — it is
  why a unit stopped where it did — and the lead's complaint was buildings. This is also why the falsifier's bar is
  "under 50" and not zero: what is left is cover, deliberately still drawn.
- **It reports what it did** (`RtsCamera.lifted_deg`). This is the **second** place the camera overrides his tilt,
  after the far-range floor, and round 6's rule is that such a place is flagged to him, not hidden.
- **Nothing is written on a city block.** No uniform, no instance parameter, no visibility, no alpha — the camera
  moves instead. Told to show (`godot-show-b0`) and to the orchestrator; control's row on `_agents/lighting.md`'s
  reserved list reads *nothing reserved*. If the alley frames later force an occlusion cutaway, it arrives as a named
  uniform plus a message, per the orchestrator's ruling.
- **A wall-clock budget in a behaviour test is a measurement of the machine.** nav measured
  `test_control_facing_camera::test_the_camera_turns_to_face_where_the_selection_faces` failing ~1 run in 3 on a
  loaded laptop **at the branch point**, costing two bisection experiments on a regression that did not exist. It
  spun on `await tree.process_frame` until 3000 ms of wall clock had passed. Fixed by taking the rig off the tree's
  process loop and stepping it at a fixed delta (`_step`): the same 2 s of simulated time on any machine at any load.
  6/6 on three consecutive runs with seven streams live. **The rule, worth a round lesson before CP3 makes a loaded
  machine normal: if the thing under test advances on `delta`, the test owns the clock.**

### Verification notes, and one method that was WRONG

- **Windowed local runs were authorised** (orchestrator, 2026-09-20 ~03:15, builder0 off the network, the lead
  asleep): `terminus-alleys` and the `shell_console` baseline may run on the laptop's own display (`DISPLAY=:0`)
  instead of `make remote`. Trip-up 32 says say when a windowed run is coming — **neither had started when the pause
  came.** One run each when work resumes, then leave the display alone.
- **`git checkout <sha> -- .` does NOT reproduce that commit's lint.** I put the tree at `e27f0681` to lint exactly
  that commit, reasoning that files added in *later* commits would only add extra checks. **They add FALSE ones:**
  `block_cutaway.gd` and `test_control_camera_solids.gd` were still on disk and call statics (`segment_hits_box`,
  `roof_over`, `clear_pose`) that `rts_camera.gd` does not have *at that commit*, so each reports a parse error that
  is a property of the method and not of the code. Either subtract those files by name or move them aside for the
  run. Same shape as a control that is not actually the control.

### Where this ended (2026-09-20 ~04:20). Every backlog item is done or blocked on another stream.

| Item | State |
|---|---|
| 1. desktop right-drag facing | **merged to `main` as CP2c** (`e27f0681`), `lint local: 531 files, 5 known baselined, 0 others` |
| 2. S4 signature + C-1 corridor + C-2/C-3 attribution | **done.** C-2's words stay silent until nav ships `legibility: {active, why}` — that is the correct output, not a stub |
| 3. camera inside a block, and the block in the sight line | **done and approved on the lead's behalf**, frames looked at by control and the orchestrator |
| 4. the view after CP2 | **blocked: CP2 (scale's roster) is not on `main` yet.** The moment it is: `git merge main`, then `camera-looks` + `control-playtest-shots` and the list in the backlog item |
| 5. `shell-playtest` console gate | **done**: baseline recorded from a clean run, `make check-display` green |
| 6. stretch (`ungrouped=N` on the default path) | not started; waits on squad's A10 |

**The last hash:** `ffd09b0e` (`main` merged in, CP1's metrics and its working lint included). Its
`make remote T=check` is the one to quote; **`449b0344` came back 1279/1** and that failure is fixed in `9d4fd9ea`.

**What tonight cost, and what it bought, in one line each — these are the five that were worth the time:**

1. **A pure falsifier said 518 → 0 while the feature cut nothing at all in a real match.** `BlockCutaway`'s root was
   wired before the arena built its bodies. Only the frames showed it. *The gap between "the algorithm is right" and
   "the feature works" is not closed by any amount of geometry testing.*
2. **A before/after where both halves were "after".** The cutaway ran during the "as asked" frame too, so the pair
   was nearly identical and showed no fault. *A comparison has to be built so the control arm can fail.*
3. **`git checkout <sha> -- .` does not reproduce that commit's lint.** Later files stay on disk and error against
   the older sources they now mismatch.
4. **`Arena._ready` takes its layout from `layout_name`/`--arena`, never `Arena.active`.** A test that sets `active`
   builds the DEFAULT arena, runs green on the wrong map, and blames the thing under test.
5. **A wall-clock budget in a behaviour test measures the machine** (lesson 158; three of mine removed).

**The pattern under all five:** each was a measurement that answered a slightly different question than the one
asked, and each looked like a pass. Two were caught by pictures, one by builder0, two by another stream.

### PAUSED 2026-09-20 ~03:20 (superseded by the section above; kept for the record)

**Everything is committed and the working tree is clean at `bd69de5f`.** There is no half-applied state to
reconstruct: items 1, 2 (C-1/C-2/C-3), 3 (both halves) and 5 are written, tested and committed, and `e27f0681` is
already merged to `main` as CP2c.

**Three things are owed, all machine-bound, none of them thinking:**

1. **`lint local` on `e27f0681` — STARTED, KILLED, NO RESULT.** It had reached roughly 40 of 533 files when the
   pause came and was stopped cleanly with its Godot children. **No number from it may be quoted.** Redo it with the
   method fixed (above).
2. **`make terminus-alleys`** — the deliverable that decides whether item 3 *reads*, as opposed to whether its
   numbers are right. Then **look at `build/terminus-alleys/index.html`**, and send show (`godot-show-b0`) a copy:
   they asked, and the same frames judge whether the block edges read at street level.
3. ~~`make shell-playtest`, then `make shell-console-baseline`~~ **DONE** (windowed, local, 04:0x): the console is
   clean — 18/18 checks and **zero** ERROR/WARNING/SCRIPT ERROR lines, so the baseline is empty on purpose and
   `make check-display` reports `unchanged (0 classes, 0 lines)`. **Finding worth acting on later:** the two
   patterns `mk/command.mk` still excludes by hand (`ObjectDB instances were leaked at exit`, `MultiMesh
   interpolation is being triggered`) **did not occur either**, so that allow-list is currently dead weight; leave
   it in case another machine or driver still produces them, and delete it if a few more runs stay clean.

**Then:** `make remote T=check REMOTE_SLOTS=6` on `bd69de5f` — only after the orchestrator says builder0 is up, and
after checking the box for an orphaned `slot.sh` of this stream's.

**(Retracted, and worth keeping as the mistake rather than deleting.)** This Status briefly warned that a foreign
`make check` was running *in this worktree*. **It was not.** The orchestrator checked by **cwd** and found pid
4145492's `slot.sh` child running in `godot-combat` (02:48:27) and a second in `godot-show` (02:48:52) — both
legitimate merge-gate runs started before the pause. My error: I walked the parent chain up from a Godot
`--check-only` process **without checking its cwd**, after earlier cwd sweeps had returned hits that were my own
`pgrep` command line matching its own pattern. **A process list filtered by NAME is not filtered by WORKTREE**, and
on this laptop seven checkouts run the same binary. Check `/proc/<pid>/cwd`, and write the pattern so it cannot
match the sweep itself. The `.lint.lock` contention I saw was the **shared laptop heavy-run slot**, not this
checkout's lock — so "a lint here will hang" was also wrong; it queues, as designed.

### Questions for the lead

- **Should a dragged facing also orient the formation?** Today "move here facing north" lays the squad out along its
  *travel* direction and each unit arrives on the ordered heading. The alternative is to lay the line out *across*
  the drawn heading, which is what an ambush emplacement wants. It is a few lines in `Orders._resolve_group`, and it
  changes the shape of every facing-carrying order (squad's included), so it is not being done blind. Frames rather
  than a question if it comes up.

### Merge notes (shared files, and files another stream owns)

- **`game/control/orders.gd`** (control's own, but every stream's orders run through it): `_same_order` now treats a
  differing `facing` as a different order **for `source == "player"` only**. Machine re-issues keep today's dedup
  exactly, so round 8's idle-command numbers cannot move. Reviewed by whoever merges CP2c.
- **`mk/command.mk`** (control's): new `terminus-alleys`, `check-display`, `shell-console-baseline`,
  `shell-console-pytest`. **`shell-playtest` itself is unchanged** — the console compare lives in `check-display`,
  because `shell-playtest` is the instrument every stream reaches for by hand and a missing or stale baseline must
  never be why someone's playtest goes red. It also lets the baseline be regenerated from a plain
  `make remote T=shell-playtest` without the gate refusing the run that is producing it.
- **`tools/shell_console.py`, `tools/test_shell_console.py`** (new, control's).
- **`mk/core.mk` is NOT edited.** `shell-console-pytest` needs no display and belongs in `check` beside
  `match-pytest`; the `check` line is shared and metrics is rewriting it for T1, so it is **requested, not taken**.
  Until it lands there it runs as a prerequisite of `check-display`. `check-display` is deliberately outside
  `CHECK_TARGETS` (metrics' shape): a display-only target inside `check` either fails every local run or no-ops
  without a display, and a target that passes for the wrong reason is what lesson 42 is about.
- **`tests/test_control_group_moves.gd` is deliberately untouched**: the CP2 re-time is scale's, in `23767e5a`, per
  the orchestrator's ruling. I had made the change and backed it out so the branches do not conflict.
- **Nothing is written on a city block** — no uniform, no instance parameter, no visibility, no alpha. control's row
  on `_agents/lighting.md`'s reserved list reads *nothing reserved*.

### Next steps (in order, for whoever picks this up)

1. **Send the orchestrator `e27f0681` with both lines** — the wrapper's `>> remote: make check exited <N>` and the
   runner's `N passed, M failed` — plus `lint local: N files, 8 known baselined lines` (lesson 157: `make remote`
   never parse-checked anything, because `lint` lists files with `git ls-files` and `.git` is not synced). The
   test target came back **1269 passed, 0 failed** on builder0; the exit line was still in the copy-back queue.
2. **`REMOTE_SLOTS=6` on every remote run** until this branch merges `main` — `tools/remote.sh` hard-coded 3 slots
   while builder0 sat at load 0.4, and `main` now defaults to 6. Do not `git merge main` for it: CP2 has not been
   announced, and the brief says merge only at announced checkpoints.
3. **`make remote T=terminus-alleys REMOTE_SLOTS=6`** — item 3's frames, and the thing the orchestrator asked to see
   tonight. Then LOOK at `build/terminus-alleys/index.html`: each pair is the same spot and yaw at his pose, left as
   asked, right as the camera now places itself, labelled `INSIDE A BUILDING` / `alley behind a wall`. **show
   (`godot-show-b0`) asked for a copy whatever the verdict** — the same frames judge whether the block edges read at
   street level, and it saves them a builder0 slot.
4. **`make remote T=shell-playtest REMOTE_SLOTS=6`**, then `make shell-console-baseline`, then commit
   `tests/baselines/shell_console.txt` saying what each line is. Until that file exists `check-display` refuses.
5. **A second `make remote T=check`** on the branch tip: everything after `e27f0681` is unverified by a check of its
   own.

### Requests to other streams

- **nav:** the `"legibility": {"active", "why"}` key in `Movement.state(unit)` (C-2 above) — §6.2 is blocked on it.
  And: mark the arrival arc's ticks so A12 can exclude them (see the warning above).
- **metrics:** split the last `arrive_radius` of a final leg out of the off-corridor statistic, or count it as
  ordered. An obeyed facing must not read as illegible motion.
