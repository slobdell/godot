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
3. **After CP2 (the resized roster is on `main`): the view at his pose.** `git merge main`, then `make remote
   T=camera-looks` and `control-playtest-shots`, and look: selection rings and boxes on a hull two to three times
   longer; the command card's `VISION_FRAME_BOTTOM` lean (now derive it from the card's geometry — the round-8 Invariant
   0 item — instead of the 0.40 copy); radar blips against 8–14 m hulls (a blip should read the hull's length class,
   not one size); the cutaway against a taller hull near the wall; zoom limits (`MIN_DISTANCE` 16 m may now be inside
   a War Rig); the auto-frame and vision floor (`VISION_FLOOR_M` 45, `AUTO_FRAME_MAX_M` 100) with a squad that is
   physically wider. Fix what the frames show, one commit each, and put the strip in `build/camera-looks/` for the
   orchestrator with the commit and machine in its README. **Nothing here is published before CP2** — a frame of the
   old roster is a frame of a game he will not play again.
4. **`shell-playtest`'s console gate into `check`, behind a committed baseline.** It needs a display, so it runs
   under `remote` on builder0 (`tools/remote.sh` handles Xwayland; trip-up 65). The gate as written fails on *any*
   ERROR; lesson 42 says the honest first step is a committed expected state (`tests/baselines/shell_console.txt`, the
   allow-listed lines and their counts) and failure only on **change** — then tighten. This is what makes the next
   texture leak visible to the gate rather than to whoever happens to run a windowed playtest. Ask the orchestrator
   before touching `mk/core.mk`'s `check` line (shared; metrics is rewriting that recipe for T1 — coordinate so your
   target lands in their parallel form, not the serial one they are removing).
5. **Stretch:** after squad's A10 lands, re-check on the **default path** (`make skirmish`, not a test flag) that the
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

_Not started. Round 9, control stream; `main` at `f49aa08a` when this brief was written (2026-09-19)._
