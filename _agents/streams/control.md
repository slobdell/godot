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

> ## HAND-OVER TIP: `c0d56029`. THE CASCADE IS GONE; NOTHING FAILING IS CONTROL'S.
>
> `make remote T=check` at **`c0d56029`** (main merged at `a6268137`), builder0, 1134s:
> ```
> >> remote: make check exited 2 (build/ copied back)
> 1540 passed, 1 failed
> >> check: 16 passed, 2 FAILED, 0 NOT RUN  [test x5, lint -P6, 2 at once, builder0]
> >> check: failed: test ai-scenarios-check
> ```
> `sim-baseline 1e90f69e5d6fcc46` (baseline unmoved), `determinism 253adefeec657df1`.
>
> **Both failures are main's known pair, not control's:** `test_match_spawns_and_results::…spawns_clear_of_itself`
> (squad's true positive that combat's `Tank.place()` clears) and `ai-scenarios-check` →
> `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck`. **Zero control, command, camera or touch tests fail
> anywhere in the check.** The four teardown sites moved under nav's seal are **31 PASS, 0 FAIL** between them and
> appear in no leak report — which was the case I named in advance as the one that would make them the suspect.
>
> **The 32-failure cascade of `78aa496d` is gone:** `grep -c "navigation region"` = **0** and
> `grep -c "physics bodies in the world"` = **0** across the whole check. nav's sealed `_teardown()` did it alone,
> with combat's leaking override still in the tree.
>
> **Reading the prediction against what it said.** I predicted *all 32 gone and 0 failed*. The first half held
> exactly. **The second half was wrong, and wrong in the shape this round keeps producing:** I formed it about
> control's own tests and then stated it as a total, which quietly swallowed main's two known reds. A true claim
> about one thing, stated as a claim about everything — the sixth entry in that column and the first where the
> claim was mine about my own work. Writing a prediction down before reading the result is what made it visible;
> it would otherwise have been a sentence that sounded right.
>
> The second leaker I found (`test_combat_no_damage`, a `Match` per `_tank()` and an override that never reaches
> the base) was real and verified on main, and **changed nothing for this tree** — the seal does not depend on an
> override behaving. Worth keeping as the reason the seal was the right shape of fix and combat's one-liner is
> belt-and-braces.
>
> **Round 9 items 1-5 delivered.** The facing frames are with the lead; the pin-head crowding is his call.
> **Item 6 (stretch) is the only thing left** — the `ungrouped=N` readout and the refused-order banner re-checked
> on the default `make skirmish` path — and it waits on squad's A10.


> ## THE BRANCH WAS RED BEFORE ROUND 9'S WORK STARTED, AND ONLY A FULL CHECK FOUND IT
>
> `make remote T=check` at `78aa496d`: wrapper `>> remote: make check exited 2`, runner **1501 passed, 33 failed**.
> **Not green, not handed over as green.** The 33 split into 32 + 1.
>
> **The 32 are one cascade.** All carry the same message — `left 4 navigation region(s) on the map after 120
> frames` — from the leaked-region guard in `tests/test_case.gd`, which says in its own text that it charges
> whichever test runs *next*. Whole files go red together (all of `test_theme_trailer`, `test_units_catalog`,
> `test_wheeled_arrival`, plus `test_combat_sim_cost`, `test_combat_suppression_bite`,
> `test_match_spawns_and_results`). The orchestrator found the author: combat's `test_tank_yaw_fit` had a
> `teardown()` override that never called super and leaked a foundry arena (44 bodies, 4 regions); it has been on
> main since `53cc42e3` and has been charged to feel, scale, control and combat in turn. **Nothing here is owed on
> those 32** — two arms are in flight, nav's sealed `_teardown()` (`49ed1fb3`) and combat's `await
> super.teardown()` (`26754ef1`).
>
> **The 1 was control's, and older than the round.** `test_control_order_marks`' pin test failed in isolation too.
> `ac4df0d7` asserted the pin draws what the CREWS were told and never what the task holds; `2cca6bea` reversed
> that rule in `rts_controls.gd` and **did not run the file that asserted the old one**. `2cca6bea` was this
> session's starting tip, so the branch carried a red test through all of round 9's drawing work. (Control's
> branch only — `2cca6bea` is not on main, and main's copy of that test passes.) Rewritten at `19d87f5c` **to the
> contract, not bent to the code**: the task's heading is drawn because since squad's `4cff69b6` it is the order
> deferred, and the unanimity rule is kept, still asserted on the path it still governs — orders given directly to
> units, where there is no task to read. `make test FILTER=control_order_marks`: **5 passed, 0 failed**.
>
> **The rule this cost, and it is the round's theme again: when a commit reverses a rule, run the file that
> asserted the old one.** Every filtered run I leaned on all round was green and none of them touched that file.
> A filtered run is a claim about the files it named and nothing else.
>
> **Prediction, written before the merge check is read.** On the post-merge tip: all 32 gone, control's pin test
> green, 0 failed. Watching two things rather than assuming them — (a) if only combat's arm is on main, the leak
> is fixed at its source but any *other* override that skips super is still live, so expect a smaller cascade
> rather than none; (b) **the four teardown edits below are themselves overrides that stop calling super.** Under
> nav's seal that is correct, but it is the same shape that caused this, so if the cascade reappears near
> `test_command_readability`, `test_touch`, `test_command_camera` or `test_control_panel`, those edits are the
> first suspect and not nav's seal.
>
> **Sequence agreed with the orchestrator, to spend one check and not two:** wait for word that both arms are on
> main → `git merge main` → the four teardown edits under the seal → one check on that tip, which is the one that
> merges.


> ## CP2c, THIRD FRAME: THE ORDERED HEADING NOW READS. WHAT THE FIRST TWO ATTEMPTS BOTH GOT WRONG.
>
> **The frames** (`78aa496d`, builder0, shot 14:48): `build/control-playtest/{1920x1080,1280x720}/9_facing_drag_ordered.png`
> and `..._drawing.png`. Two nested chevrons run out of the destination ring along the heading. They read at both
> sizes. **One thing left for your eye:** the chevrons cross the pin's head disc and, at 720p, the left edge of the
> `MOVE · 0/3 there · 24 m` plate. Crowded, not hidden. If you want it cleaner the fix is to lean the pin's head
> away from the heading it carries so the two stop stacking — say the word and it is a small change.
>
> **Why this took three goes, because the reason generalises.** The heading was first a line with an arrowhead. It
> vanished into the pin's own stalk. I replaced it with chevrons — and they vanished the same way. The frame says
> why: **arms fixed at ±2.6 m span 96 px at 21°, while the nose stands off only 15 px.** A 96:15 "V" is a
> horizontal tick, and it lies along screen-vertical, which is exactly where the stalk is whenever the heading
> points away from the camera. The stalk was also drawn *after* it, painting over what nose there was.
>
> So the shape is now specified **on the screen** and the ground that produces it is **solved for, per pin, per
> pose**: the nose must stand off the arms by half their span. At 21°/49 m that buys **4.62 m** of ground pointing
> away against **2.20 m** across — the shape is the constant and the ground pays for it. This is invariant 0
> applied to a drawing: derive the metres from the pose, never mirror a number that happened to read once. A dark
> backing stroke carries it over the stalk it must still cross.
>
> **What no test caught, twice.** Both failed attempts passed every assertion that asked *"does a facing reach the
> pin"* — which was all of them. `test_the_pin_chevron_reads_as_an_arrow_and_not_a_tick` now asserts the
> **property** (nose stand-off ≥ half the span, at the lead's pose, for a heading pointing away, toward and
> across) rather than the pixels. That is the fifth entry this round in the same column: *a measurement that is
> true but reads as a stronger claim than it makes*. "The facing is on the pin" was true all along and never meant
> "the player can see it".
>
> **Also:** the frames only settled this because I cropped and magnified them (`convert -crop … -resize 200%`)
> instead of judging a 1920-wide screenshot at thumbnail size. Twice this round I reported "I cannot tell" on a
> frame that a crop would have answered. Do that first.
>
> `make test FILTER=control_facing_drag` on builder0 at `78aa496d`: **8 passed, 0 failed**.
> Still blocked: the teardown edits wait on nav's sealing merge — `free_owned()` does not exist in this worktree
> yet, so `tests/test_case.gd:194` is still `teardown()` and the four call sites stay as they are.


> ## WHAT THE RESIZE CHANGED FOR YOU, AND THE ONE THING STILL TO DECIDE
>
> Making the vehicles their real relative sizes was worth it, and it broke four things that were quietly sized for
> a 3.6 m hull. Three are fixed. **Two of the four were wrong at your own camera**, not at some extreme.
>
> | What you will see | Look at |
> |---|---|
> | **The marker under a vehicle is now shaped like the vehicle** — a capsule along the hull instead of a circle round its longest side. A tank's circle had grown to 12.9 m across, wide enough to park two tanks abreast in, and a squad's markers overlapped into a blob you could not read a unit out of. The marker now also shows which way a vehicle points. | `build/ring-before-after/before_circles.png` vs `after_shaped.png` |
> | **A vehicle parked against the arena wall is no longer sliced in half** when you tilt the camera down. The wall cut-away was placed at the wall's top edge (3 m) — fine when the tallest vehicle was 1.6 m, wrong now that the Sonic Emitter is 6.18 m. At 50° it was cutting 1.57 m off the top of it. | it is geometry, not a frame: `-1.57 m → +0.20 m` worst across your whole tilt range |
> | **The camera stops cutting squads off at the edge of the screen.** It framed where vehicles *stood*, never how big they are, so a column of War Rigs ran off the screen **at your own 21° camera** while the camera believed it had them all. | `-16.3 px → +12.4 px` at your pose |
> | **A radar blip is sized to the vehicle it stands for** — rat rod smallest, rig biggest — instead of every vehicle being the same dot. | `build/control-playtest/1920x1080/8_whole_army.png` (bottom right) |
>
> **Still yours to decide** (below): whether the marker should be a tighter circle, the shaped capsule now shipped,
> or left alone — and note the whole-squad facing drag is half-built, described under it.
>
> **One thing we have NOT fixed, so you know before you find it:** at the very lowest camera tilt (8°, the floor of
> the range), a column of vehicles longer than about 70 m still runs off the screen. That is not the resize — it is
> the camera's fitting maths going wrong when the ground is nearly edge-on, and it was true before. Measured and
> recorded rather than quietly rounded off.

> ## TWO CALLS FOR YOU, WITH THE PICTURES. Neither is broken; both are choices the resize forced.
>
> ### 1. The ring under your vehicles is now wider than the vehicle is long. Which do you want?
>
> **Look at** `build/camera-looks/arenas/yard/default.jpg` (one tank, one ring) and
> `build/control-playtest/1920x1080/8_whole_army.png` (three rings at once).
>
> Your tanks got longer — the Condemned tank went from about the length of a car to **8.6 m, the length of a bus** —
> but they did not get wider. The selection ring is drawn from whichever is bigger, so it grew with the length and
> is now **a circle you could park two tanks abreast inside**. On one vehicle it looks loose. On a squad the rings
> overlap into a cloverleaf and you cannot tell which ring belongs to which vehicle, which is the thing rings exist
> to tell you.
>
> - **(a) Tighter circle.** One number. The ring shrinks to just contain the hull (about a third smaller). Cheapest,
>   and on a squad in close formation they will still touch.
> - **(b) A ring shaped like the vehicle** — an oval or a rounded rectangle lying along the hull. This is the honest
>   answer now that your roster runs from a 2.9 m rat rod to a 14 m rig, and it is the only option that stops a
>   squad's rings overlapping. It is real work on the marker, not a constant.
> - **(c) Leave it.** Loose rings, and you live with the cloverleaf when a squad is packed.
>
> **My recommendation: (b).** You said the resize made the game *"much cooler and awesome"*; the rings are the one
> piece of UI that got worse in exchange, and (a) only halves the problem.
>
> ### 2. When you drag a heading for a whole squad, the squad does not turn to it yet.
>
> Right-drag now means *"go there, and be facing that way when you arrive"*. It works when you have picked
> vehicles individually. **When you have a whole squad selected — your commonest order — the heading currently
> stops at the squad leader and does not reach the vehicles.** The pin shows the heading you drew, so the screen is
> telling you it took; the vehicles have not been told.
>
> **This is half-built, not broken, and the missing half is one line in squad's code** (the element passes the
> task's facing down to its members). Nothing for you to decide unless you would rather it waited for the whole
> thing before you play with it. Flagged because the pin promises something the vehicles do not yet do, and a
> promise the game does not keep is worse than a feature that is obviously absent.

> ## ITEM 4, PART DONE: THE HUD ON THE RESIZED ROSTER. TWO FINDINGS, ONE IS YOURS TO RULE ON.
>
> **THE FRAMES (item 4 is now shot; `camera-looks` landed at 08:59, `exited 0`, copy-back verified):**
>
> ```
> build/camera-looks/index.html                       the page: 28 grid frames + all ten arenas at his pose
> build/camera-looks/arenas/yard/default.jpg          his pose, resized roster, one ring on one tank
> build/control-playtest/1920x1080/8_whole_army.png   the cloverleaf: three rings at once
> build/control-playtest/1920x1080/*.png              12 frames (and 1280x720 beside it)
> ```
>
> `control-playtest-shots` was shot **locally at 08:28 while builder0 was down**; `camera-looks` ran on **builder0
> at 08:59** once it returned. Both are on the **resized** roster (`914dc7d3`). The earlier `camera-looks` attempt
> `exited 255` (ssh) with a failed copy-back and produced nothing here — this one exited 0, and its `index.html`
> timestamp was checked before anything was read out of it.
>
> **FINDING 1 — the selection rings have become a cloverleaf, and this is your call.** A ring's radius is
> `max(hull.x, hull.z) * 0.75`. The Condemned tank went **3.60 m → 8.62 m long** but is still **2.40 m wide**, so
> its ring went from **5.4 m across to 12.9 m** — for a vehicle you could park two abreast inside it. In
> `8_whole_army.png` three neighbouring units' rings visibly intersect and you cannot tell which ring belongs to
> which vehicle; `arenas/yard/default.jpg` shows the same thing on a SINGLE unit, where the ring is about **twice
> the hull's own length**. **It is not a bug, it is a constant that was right for a 3.6 m hull**, and the fix is a design
> choice rather than a number: (a) bound the hull's own circumscribing circle instead of its longest axis
> (`hypot(x,z)/2`, which gives 4.47 m for the tank against today's 6.47) — cheapest, still overlaps at formation
> spacing; (b) an **oriented** marker (an ellipse or a rounded box along the hull) that bounds a long narrow
> vehicle tightly — the honest answer for a roster spanning 2.93–14.0 m, and a real change to the marker mesh;
> (c) leave it. **I did not change it blind:** at 08:45 with one display I could not have re-shot and LOOKED at a
> new constant before you read this, and a ring I have not seen is exactly what this stream has spent the night
> refusing to hand over.
>
> **FINDING 2 — a facing drag on a WHOLE SQUAD lost its heading, and that is mine, not CP2's.** The playtest I
> added for item 1 ran for the first time here and failed: `drag_px 127`, a good ground direction, and
> `facing: []` on the order. A whole-element move goes down the **task** path, and `RtsControls.assign_task` copied
> only `to` and `target` into the task — so the lead's commonest order, a squad with a drawn heading, silently
> became a plain move. **Control's half is fixed** (the task now carries `facing`); **the last mile is squad's** —
> the element layer has a facing channel (`element.gd:493`) but nothing reads `task["facing"]` yet, so the per-unit
> orders will not carry it until squad wires it. The playtest now reports **which half** failed
> (`facing_drag_reaches_the_task`). My unit tests missed it because they all order single units or pairs that are
> not elements, and those take the direct path.
>
> **Still owed:** `REMOTE_SLOTS=6 make remote T=camera-looks` the moment builder0 answers, and the rest of the
> checklist under *Still owed* below (radar blips across a 2.93–14.0 m spread, the cutaway against the 6.18 m
> Sonic Emitter, `MIN_DISTANCE` 16 m against the 14 m War Rig, the card lean derived rather than copied).

> ## ⚠ (superseded by the section above) ITEM 4 IS NOT DONE, AND THERE ARE NO NEW FRAMES.
>
> **CP2 is merged and on this branch** (`914dc7d3`, the roster really is resized: tank hull **8.62 m**, Sonic
> Emitter **6.18 m** tall, Rat Rod **2.93 m**). The post-CP2 camera sweep **started and did not finish**:
> `make remote T=camera-looks` came back **`exited 255`**, which is **ssh, not the suite**
> (`_agents/remote_builds.md`), and **`build/ copied back: FAILED`**. builder0 has been unreachable since ~08:27
> (`No route to host`). It had finished foundry and furnace on the box before the link dropped; **none of it reached
> this laptop**, so `build/camera-looks/` here holds **an older run's frames and must not be read as CP2's**.
>
> **There are therefore NO frames of the resized roster.** The rule in this brief has not relaxed: *a frame of the
> old roster is a frame of a game he will not play again*, and that applies to stale frames sitting in `build/` just
> as much as to freshly shot ones.
>
> **The one command that finishes it, the moment builder0 answers:**
>
> ```bash
> cd ~/projects/godot-control && git merge main      # already done: 914dc7d3
> REMOTE_SLOTS=6 make remote T=camera-looks
> REMOTE_SLOTS=6 make remote T=control-playtest-shots
> ```
>
> Then read the frames against the checklist under *Still owed*, below, and put the paths here.
>
> **The frames that ARE real and worth looking at are the Terminus alleys**, shot locally at 04:02 on the
> **pre-CP2** roster: `build/terminus-alleys/index.html`. They answer the camera-inside-a-building item, which does
> not depend on hull size; they are not a substitute for the sweep.

> **Round 9, control. Finished 2026-09-20 ~05:00.** Branch `stream/control`; **`ffd09b0e` is the checked hash**
> (builder0, **16 of 16 check targets**, verdict read from the box's own markers — metrics' kill took my wrapper
> line, `mk/core.mk:250` clears the marker directory at the start and `:274` writes a marker only on success, so
> 16 fresh markers is a sound green). `e27f0681` went to `main` earlier as **CP2c**.

### What you can now do that you could not

| Your words | What shipped |
|---|---|
| *"I couldn't tell what direction they were facing"* — and round 8 found your controls never **sent** a facing | **Right-DRAG the ground: "go there, and be facing that way when you get there."** Press picks the spot exactly as before; drag past 18 px and the drag's direction becomes the order's heading. Until now **nothing in the game you play had ever sent one**, so nav's arrive-on-heading arc had no caller and its A/B measured zero in both arms |
| *"the camera often ends up inside a building… we can't see what's going on inside the alleyways"* | **703 of 4328 camera poses on the Terminus were inside a building. Now 0** — it lifts over the roof (21° → 32°) instead of yanking in, keeping 41.5 m of view. And **the building between the camera and what you are looking at is not drawn**: sight line blocked **518 → 0** |
| *"they still generally don't do what I command them"* | The groundwork, not the fix: the **ordered corridor** is drawn with its current leg at full weight, and when a unit leaves it deliberately the cause goes in *"why did my element do that"* — never on the order pin, which stays the refusal channel. **The words are silent until nav ships its cause field**, deliberately: a guessed reason is confidently wrong exactly when you are watching |
| (unasked) the console you see when you play | `make shell-playtest` now has a **committed baseline that fails on change**. A real run came back **18/18 checks and zero error lines**, so the baseline is empty and the gate is stricter than the allow-list it replaced |

### Done, with measurements

- **Right-drag facing** — `tests/test_control_facing_drag.gd`, 7 tests through the real input pipeline. Mutation
  check: deleting the facing assignment fails 4 of 7. The pin grows a ground arrow for the ordered heading and the
  HUD says *"3 units: move facing NE"*. A live preview follows the pointer while the button is down.
- **Camera out of solids** — 4328 poses (every open ground point × 8 yaws) at your pose: **703 inside a building →
  0**, worst lift **11.0°**, nothing pulled in, the yard provably untouched. Mutation-checked.
- **The building in the sight line** — over those same 703: **700 blocked before, 518 after the lift, 0 after the
  cutaway**. Every one of the 518 was a building, so the "cover" headroom in the bar went unused.
- **Frames, looked at** (`build/terminus-alleys/index.html`, local): the *before* frame is your complaint exactly —
  the bottom 70% of the screen is the flat dark inside of a wall. The *after* is a legible street with a whole squad
  and their selection rings, facades and neon intact at the sides, no half-cut geometry. The open-ground control
  frame cuts nothing and lifts 0.0°, which is the check that the fix does the specific thing and not a general one.
- **S4 legibility** — signed by feel, nav and control. The corridor's current leg is drawn; an inactive law draws
  nothing rather than a guessed corridor.
- **Console gate** — `tools/shell_console.py`, 5 green tests, `make check-display`.
- **Three wall-clock test budgets removed** (lesson 158) — they were measuring the machine, not the code.

### The five measurements that were lying, and what caught each

**This is the part worth a successor's time. Every one looked like a pass.**

1. **A falsifier read 518 → 0 while the feature cut nothing at all in a real match.** `BlockCutaway`'s root was wired
   before the arena had built its bodies, so it returned early forever. **Caught by looking at the frames.** No
   amount of geometry testing closes the gap between *the algorithm is right* and *the feature works*.
2. **A before/after where both halves were "after"** — the cutaway ran during the control frame too, so the pair was
   nearly identical and showed no fault. **Caught by looking at the frames.** A comparison must be built so the
   control arm *can* fail.
3. **`git checkout <sha> -- .` does not reproduce that commit's lint** — files added in later commits stay on disk
   and error against the older sources they now mismatch. **Caught by reading the errors instead of counting them.**
4. **`Arena._ready` takes its layout from `layout_name`/`--arena`, never `Arena.active`** — a test that sets `active`
   silently builds the DEFAULT arena, runs green on the wrong map, and blames the thing under test. **Caught by a
   number that was too small** (19 bodies, then 48).
5. **A wall-clock budget in a behaviour test measures the machine.** **Caught by nav**, who ran the branch point
   three times instead of once; a single control run had already convinced them my branch was at fault.

Two more from the same family: **a dedup that held only under one frame ordering** (caught by builder0, not by the
laptop), and **a process list filtered by name is not filtered by worktree** — `pgrep -f` even matches your own
command line, which turns *"is it still running?"* into yes whatever the truth is. I diagnosed a foreign `make check`
in my own worktree from it; metrics killed three streams' wrappers from the same root cause.

### What to playtest (exact commands)

- `make skirmish` → FIGHT. **Right-DRAG on the ground** with units selected: a ring appears on the destination and an
  arrow follows your pointer; release and the pin grows an arrow for the heading, with *"N units: move facing NE"* on
  the HUD. A plain right-click is unchanged. Right-press on an **enemy** still attacks instantly, drag or no drag.
  **Shift** queues. An armed order (A/F/M/E/R/B) still cancels on right-press, and that press is spent.
- `make skirmish --arena=terminus` — drive a squad into the streets. The camera should never end up inside a
  building, and a building between you and your units should simply not be drawn. `--block-cutaway=off` draws the
  city whole for comparison.
- **Look at** `build/terminus-alleys/index.html` (six pairs, your pose, left as asked / right as fixed).
- `make remote T=control-playtest-shots` and `T=camera-looks` for the HUD and the camera grid;
  `make remote T=check-display` for the console gate.

### Owed: four teardowns that have silently skipped the navigation drain (waiting on nav)

combat's grep, confirmed here. Four control test files override `teardown()` and call the base:

```
tests/test_command_readability.gd:141   super.teardown()
tests/test_touch.gd:177                 super.teardown()
tests/test_command_camera.gd:194        super.teardown()
tests/test_control_panel.gd:143         teardown()      <- mid-test, not an override
```

**Because the override is declared `-> void`, the runner's `await` returns immediately, the navigation drain
detaches, and these viewport-resizing tests have skipped it since it existed.** nav has sealed the drain into a
`_teardown()` the runner awaits, with the overridable hook synchronous (`c3df6d4a`, riding nav's next check). **The
three overrides and the mid-test call need DIFFERENT fixes:**

- `test_command_readability:141`, `test_touch:177`, `test_command_camera:194` — **just drop `super.teardown()`**.
  Their own viewport restore keeps its place, because the hook runs *before* the freeing.
- `test_control_panel:143` — **`free_owned()`, with NO `await`.** It is public now and the supported way to clear
  the world part-way through a test. **It is synchronous by design** — nothing inside it yields, so no caller can
  leave it half-run by forgetting to wait — and `await`ing it would raise Godot's `REDUNDANT_AWAIT` and fail lint.
  A bare `teardown()` there would run only the synchronous hook and **free nothing**.

Nothing to do until nav's merges.

**It is the same class as the rest of this round, in a new costume:** `await` on a `-> void` function is a
statement that looks like it waits and does not. A lint over zero files, a `get()` that turns *absent* into *null*,
a baseline describing an older world, a before-frame shot with the fix running — **every one of them true, and read
as a stronger claim than it made.** That is the thing to be suspicious of in this codebase, more than any
particular bug.

### If you change the selection marker, check the SHADER PARAMETERS, not the mesh

Round 9 turned the marker from an annulus mesh scaled uniformly into **one unit quad per kind with a
signed-distance capsule in the fragment shader** (`selection_markers.gd`), and **two guarantees moved with it**.
Both had tests that went on passing for the wrong reason, or failed for a reason that was not a regression:

- **depth testing** was `StandardMaterial3D.no_depth_test`; it is now the absence of `depth_test_disabled` in the
  shader's `render_mode`. (*A vehicle must cover its own marker.*)
- **friend and foe differ by SHAPE, not only colour** — an accessibility property — was a dashed *mesh* with fewer
  vertices; it is now the material's `dashes` parameter. A vertex count now compares **6 against 6** and cannot see
  it at all.

**Neither property changed. Both assertions had to move.** If you touch the marker again, the question to ask of
every ring test is *where does this guarantee live now* — and the answer is a shader parameter or a `render_mode`,
not a mesh or a material flag. The second of the two was caught by `make remote T=check`, not locally: it lives in
`test_command_readability.gd`, which is not one of the files you would think to run after editing the markers.

### One pose is not a range

I reported the wall-cutaway checklist entry as **"answered: clear"** from a single check at the lead's pose (21°),
where a 6.18 m hull parked against the wall clears the near plane by **+0.22 m**. Swept across the tilt range he
can actually reach, it is **−1.57 m at 50°** — the top 1.57 m of that vehicle cut away. The fix brings the worst
case across 8–70° to **+0.20 m**.

**The analysis was not wrong, it was narrow**, and it read as a clean answer — which is what made it dangerous.
Anything checked at one pose, one seed, one arena or one hull is checked at one point of a range the player moves
through freely, and a checklist entry is not answered until the range is.

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

### Questions for you

- **Should a dragged facing also orient the formation?** Today *"move here facing north"* lays the squad out along
  its **travel** direction and each unit arrives on the ordered heading. The alternative lays the line **across** the
  drawn heading, which is what an ambush emplacement wants. It is a few lines, and it changes the shape of every
  facing-carrying order including squad's, so it is not being done blind.
- **The camera lifting itself over a roof is the second place it overrides your tilt** (after the far-range floor).
  It reports how far it lifted. Keep it, or would you rather it pulled in and stayed at your angle? The frames show
  why I chose the lift: pulling in collapses the 49 m boom to about 11 m.

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

### Still owed

- **ITEM 4 IS OWED, AND HERE IS EXACTLY HOW TO RUN IT.** It needs scale's resized roster on `main` and nothing
  else. It does not depend on anyone remembering anything:

  ```bash
  cd ~/projects/godot-control
  git merge main                      # the LOCAL branch; origin/main is behind, nothing is pushed
  REMOTE_SLOTS=6 make remote T=camera-looks CAMERA_LOOKS_ARENA=yard
  REMOTE_SLOTS=6 make remote T=control-playtest-shots
  REMOTE_SLOTS=6 make remote T=terminus-alleys        # the alley pairs again, on the new hulls
  # then LOOK at: build/camera-looks/index.html, build/control-playtest/1920x1080/*.png,
  #               build/terminus-alleys/index.html
  ```

  **Read each frame against this list** (all of it sized for a 3–5 m hull and now facing 2.93–14.0 m):
  selection rings and boxes on a hull two to three times longer · the command card's lean
  (`VISION_FRAME_BOTTOM` 0.40, **to be derived from the card's geometry rather than copied** — the round-8 Invariant 0
  debt) · radar blips, which are a fixed 32 px texture and should read a hull's length class · the wall cutaway
  against the **6.18 m Sonic Emitter**, the tallest hull · `MIN_DISTANCE` 16 m against the **14 m War Rig**, which
  may now be inside it · the auto-frame and `VISION_FLOOR_M` 45 / `AUTO_FRAME_MAX_M` 100 against a physically wider
  squad. Fix what the frames show, one commit each, and put the strip in `build/camera-looks/` with the commit and
  machine in its README.

  **The rule does not relax if the deadline moves: nothing here is published before CP2.** A frame of the old roster
  is a frame of a game he will not play again, so if CP2 misses the night, the honest state for his morning is
  *"item 4 not done, and here is the command"* — not a set of frames shot on the roster being replaced.

- **(superseded, kept for the shape) Item 4, the post-CP2 camera sweep: NOT DONE.** It needs scale's
  resized roster on `main`. When it lands: `git merge main`, then `make remote T=camera-looks` and
  `T=control-playtest-shots` at your pose, and check selection rings, the command card's lean
  (`VISION_FRAME_BOTTOM`, to be derived from the card rather than copied), radar blips against 8–14 m hulls, the
  wall cutaway against a taller hull, `MIN_DISTANCE` 16 m against a War Rig, and the auto-frame with a wider squad.
  **Nothing here is published before CP2** — a frame of the old roster is a frame of a game you will not play again.
- **Item 6 (stretch)** — stood down to next round with squad's A10.
- **C-2 is UNBLOCKED and built to nav's real set** (`Movement.LEGIBILITY_WHY`, `stream/nav` at `3f8cb7b1`); the
  words arrive when nav's commit reaches `main`. Two of nav's reasons render as **nothing**, both deliberately:
  - **`override` is silent.** nav's wording shifted between the two messages — from *"the honest single word"* when
    nothing bound the nose, to ***"nothing nav owns is shaping the nose"***. The second is the **absence** of a
    cause, and by nav's own table it is **most ticks on the default blend**; a line on every off-corridor unit every
    tick is the 30-messages failure C-3 exists to prevent, dressed as an explanation. It gets words the day A6
    exists and `override` can only mean *a law ran and something outranked it*.
  - **`yielding` is silent** because `MovementReadout.CALLOUTS` already floats **YIELDING** over that hull. C-3: one
    fact, one channel.
  - **`arrival_arc` → *"arriving on the heading you drew"*** is the one live reason a player sees today, and it
    exists because of item 1. `band`/`survival`/`armour` are wired with their shipped words and light up when nav
    can publish them — a test asserts **every word in the vocabulary names a reason nav can actually publish**, so a
    word for a reason that can never arrive cannot sit here looking like a feature.
  - An unknown `why` renders as nothing, never a guess and never a raw key. nav's `push_error` catches drift on
    their side, this catches it on mine.
- **The A4 finding, and why the readout changed for an arm that is switched off.** nav measured a hull on the A4
  arm holding `arrival_arc` for **45 s, ending 9.8 m short and 147° off** the ordered heading (the straight arm is
  home in 4.3 s from the same start). *"Arriving on the heading you drew"* is the one live reason this readout
  renders, so on that arm it would tell the player to **wait for a unit that is not coming** while the band beside
  it correctly said STUCK — two opposite things on screen, with the encouraging one wrong. **The callout band now
  outranks the explanation**: if the band has anything to say about a hull, the legibility line says nothing. A
  general rule, not an A4 special case; it covers STUCK, BLOCKED and YIELDING at once. Fixed while A4 is off
  because the flaw is in the readout's wording, not in the arm — lesson 149's converse: a behaviour behind a flag
  can still mislead the day the flag goes on.
- **nav's hashes, so C-2 lights up when they reach `main`:** `3f8cb7b1` (the key), `16444beb` (the corridor tangent
  and the `no_law`/`override` split), `e2fbd1aa` (A6 behind `--nav-off=a6`), `1a616345` (the arm in `NAV_FIGHT_ARM`).
  **Expect A6 inactive on every unit after that merge and do not call it a wiring fault** — nav measured A6 reached
  1087 times and able to act **0** times (`a6_asked 1087, a6_no_corridor 1087, a6_nose_narrowed 0`), because
  `CombatMotion.choose()` has no unit handle until squad passes `request["corridor"]`. `band`/`survival`/`armour`
  start arriving with squad's merge, with no change needed here.
- **A "blocked on X" line is a claim with a date on it.** My Status said *blocked on nav's key* for hours while the
  readout sat built; nav's said *A6 blocked on S4* while the signature had been given. Neither of us re-read the
  contract and the orchestrator spotted it. Both sides were done and both were waiting.

### Requests to other streams

- **nav:** the `"legibility": {"active", "why"}` key in `Movement.state(unit)` (C-2 above) — §6.2 is blocked on it.
  And: mark the arrival arc's ticks so A12 can exclude them (see the warning above).
- **metrics:** split the last `arrive_radius` of a final leg out of the off-corridor statistic, or count it as
  ordered. An obeyed facing must not read as illegible motion.
