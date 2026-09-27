# Stream: camera (the camera asks the drawing, not the collider)

> **ARCHIVED — round 12 closed 2026-09-27.** This brief is kept as written, including the survey that was true when
> it was written and the parts the stream proved wrong. What shipped is in `HANDOFF.md` *ROUND 12*; the lead's words
> are in `game_design.md` *Round 12 direction* and his verdicts in *Round 12: the lead's verdicts as they land*; the
> round's lessons are `orchestration.md` 220–222. Do not work from this file.

> Read [`verification.md`](../verification.md) *A collider is not a silhouette* first; then
> [`orchestration.md`](../orchestration.md) lesson 214; [`game_design.md`](../game_design.md) *Round 9 addition*
> (*The camera inside a block*) and *Round 11 direction* (*The camera and the airship: push up, not away*);
> [`workstreams.md`](../workstreams.md) (round 12: ownership, C12.2, C12.3; round 11's C11.2). The archived
> `archive/round11/airship.md` is where the drawn-extent table came from. **You own** `game/camera/**`
> (`rts_camera.gd`, `block_cutaway.gd`, `camera_looks.gd`, `follow_camera.gd`, `cinematic_camera.gd`),
> `tests/test_control_camera_solids.gd` and the camera tests. **Read-only:** `AirshipFlight.DRAWN` in
> `game/theme/arena_kit/airship/airship_flight.gd` (C12.2).

## The lead's direction

The camera rules exist because of his words. Round 9 (2026-09-20): *"the camera often ends up inside a building and we
can't see what's going on inside the alleyways. We need to make it so the camera is forced outside the solid for these
cases."* Round 11 (2026-09-23), on the airship: push the camera **up** over a solid, not away. Round 12: these two
items were on the list he approved (2026-09-26).

## Where things stand (read from the code by the round-11 airship stream; not yet seen to fail in play)

`ArenaKit.PROPS` sizes, `Arena.active["obstacles"]` and the bodies under `Obstacles` are **collision** boxes. For three
kit types they are far smaller than what is drawn (measured off the meshes by `AirshipTruth.drawn_solids`):

| type | collider (x × h × z) | drawn | gap |
|---|---|---|---|
| floodlight | 2.4 × **3.0** × 2.4 | **16.05 m** tall, 4.2 m lamp head | a 13 m mast and head |
| ad_screen | 7.8 × **1.4** × 2.0 | **20.7 m** tall (7 × 14 m LED wall from 6 m up, beacon on top) | 19 m of panel |
| sign | none | 7.65 m, a 6.3 m board | all of it |
| block | 40 × 24 × 40 | the same | none |

Two camera systems ask the collider:

1. **`RtsCamera.roof_over` / `clear_pose` / `sight_blocked`** (`rts_camera.gd:578, :594, :723`) read
   `Arena.active["obstacles"]`. To them an ad screen is 1.4 m and a floodlight 3 m, so the camera can be parked inside a
   floodlight's lamp head (15–16 m up: his camera reaches that at a ~18° tilt; his default pose is 21°) or against an
   LED wall's housing, and `sight_blocked` never reports a view blocked by an LED wall. `clear_pose` is a static,
   headless function over data (round 11's C11.2) with tests; it must stay one. Round 9's measurement was 703 of 4328
   Terminus poses inside a solid before `clear_pose`, 0 after — against COLLIDERS.
2. **`BlockCutaway._gather`** (`block_cutaway.gd`) reads the obstacle bodies' own `CollisionShape3D`s and keeps solids
   at least `MIN_HEIGHT_M` (6 m) tall. An ad screen's collider is 1.4 m, so **a 20 m LED wall between his camera and
   the fight is never cut away**, nor is a floodlight's mast. Blocks are right because collider = drawn.

The drawn-extent table already exists and is tested: `AirshipFlight.DRAWN`, held against the kit's meshes by
`test_the_flights_table_of_drawn_props_covers_what_the_kit_draws` (airship's paths). **Read it; do not copy it**
(C12.2). **Never grow a collider** to fix any of this (C12.3): that moves gameplay and the sim baseline to solve a
picture. The orchestrator relayed "the floodlight is 3 m" to the lead from exactly the collider table (lesson 214).

## Backlog (in order)

**K1. An instrument first.** Extend the round-9 pose sweep (the 4328 Terminus poses at his pitch/FOV/distance grid;
find it in the camera tests or `camera_looks.gd`) to test each pose against the DRAWN solids as well as the colliders,
and print, per kit type: poses inside a drawn solid, poses whose sight line is blocked by a drawn solid, and the same
against colliders. That table, at `main`'s commit on builder0, is the "before". Run it on every shipping map
(`Arena.ROTATION`, six maps), not only the Terminus; the yard has floodlights and screens too.

**K2. `RtsCamera` asks the drawing.** `roof_over`, `clear_pose` and `sight_blocked` take the obstacle list grown to its
drawn extent for the visual question (a pure transform of `Arena.active["obstacles"]` using `AirshipFlight.DRAWN`,
built once per arena, still data-only, still headless — C11.2 holds). Keep the gameplay reads (anything that decides
where a HULL can be) on the collider. Re-run K1: inside-drawn should read 0; sight-blocked should fall and the
remaining count is the number for the cutaway. Then the frame pair at his pose: the camera at ~18° near a floodlight,
before (inside the lamp head) / after.

**K3. `BlockCutaway` cuts away what is drawn.** `_gather` measures height from the drawn extent, so the ad screen and
the floodlight mast qualify; the cutaway must hide the DRAWN mesh (the LED wall and its ad texture, the mast), not only
the collider's box, and a screen that is the airship's or the show's fixture must go back when the camera moves on.
Pair at his pose: an ad screen between the camera and a fight, before/after. Check with show's rule that a cue on that
screen does not fight the cutaway (the screen simply hides; the show keeps running).

**K4. Play it.** `make skirmish ARENA=terminus` and `ARENA=yard`, drive the camera along the perimeter and into the
blocks at his pose; the airship pass-over (round 11) must still lift the camera up and back. Frames in Status.

**K5 (stretch).** Whether `MIN_HEIGHT_M` (6 m) is the right bar once heights are true — a 7.65 m sign now qualifies;
does cutting away signs help or flicker? Decide on frames, state the reason.

## How to verify

- `make remote T=check` green on every named commit; the camera solids test suite extended (K1's table asserted:
  inside-drawn == 0 on every shipping map after K2).
- **Pre-registered UNMOVED:** sim baseline `01ab39b592cc9837` and the determinism hash; the camera is not the
  simulation. A move is a finding, not a record.
- Every frame pair at his pose (21°, FOV 35, 49 m) with commit and machine; `make remote T=airship-shot SEQUENCE=1`
  still shows the lift.

## Don't touch

`game/theme/**` (the airship's file is read-only; if `DRAWN` must move, C12.2 says how and arena reviews),
`game/arena/**` and `ArenaKit.PROPS` (arena's; C12.3), `game/control/**` beyond reading the camera's public API,
`game/ai/**`, `game/tactics/**`.

## Waiting on the lead

Nothing. The frame pairs go into Status for him; if K5 is a taste call, put the pair on a page with `db`.

## Status

_Updated 2026-09-26, camera worker (session in `~/projects/godot-camera`)._

**The lead's verdicts (2026-09-26 evening, his page's `db` `answers/camera`, read back and agreeing with his words as
relayed by the orchestrator):** *"1 · The camera in a floodlight's lamp head: Keep it · 2 · An ad screen between you and
the fight: Don't cut screens · 3 · What I left standing: floodlight masts and signs: Leave them standing"*. So **K2
stands; K3 is withdrawn**: `BlockCutaway.DRAWN_CUT` is now empty (the growth machinery stays, so restoring it is one
line), the tests assert no screen is cut and a screen in his sight line stays drawn, and `make camera-drawn` skips the
screen pair while the list is empty. Recorded in `game_design.md` *Round 12: the lead's verdicts*. The K3 text below
is the build he judged.

**MERGE HERE: `fe4f79fb`** (stream/camera with `main` at `4397be31` merged, the orchestrator's checkpoint): builder0,
`>> remote: make check exited 0`, 18 targets, **1744 passed, 0 failed**, sim-baseline `01ab39b592cc9837` **UNMOVED**,
determinism `b83a374ce2fcde37`. The one commit after it touches only this Status. Earlier: `806dd794` (the verdict,
unmerged) was also green on its clean re-run (1731 / 0). Its first run synced inside the 23:28 builder0 folder
incident and failed only `scenario_perf::test_the_brains_stay_inside_the_cpu_budget` (a wall-clock budget, builder0
loaded with several streams' runs); that run is void. The merge resolved one conflict in `game_design.md` (*Round 12:
the lead's verdicts as they land*): main's section kept, its camera paragraph replaced by the confirmed reading.

**Git-ignored record kept in this worktree** (`~/projects/godot-camera/build/camera-round12/`, 37 MB; builder0 frames
at `65071cc0`, the build he judged): `drawn_terminus/` and `drawn_yard/` (the pairs, each with `looks.json` and
`index.html`), `airship/` (`airship-shot SEQUENCE=1`), `alleys/` (`terminus-alleys`), `page_camera_drawn.html` (the
published page's source, frames embedded), `sweep_builder0_4a54bca2.log` (the test shard with the six-map
`MEASURE camera_drawn_solids` lines). All of it can be regenerated with the make targets named above.

**State: K1–K5 done; K3 reversed by his verdict.** Commits on `stream/camera`:
`fa094ed4` K1 (instrument) · `c645ad54` K2 (camera asks the drawing) · `4a54bca2` K3 (cutaway cuts ad screens) ·
`65071cc0` `make camera-drawn` (the pairs) · then docs. **`4a54bca2` checked green on builder0:** `>> remote: make check
exited 0`, 18 targets, **1730 passed, 0 failed**, sim-baseline `01ab39b592cc9837` **UNMOVED** (as pre-registered),
determinism `b83a374ce2fcde37`. The tip's check is below under *Merge*.

**The lead's page (with `db`): https://claude.ai/artifact/We5PxYjNqXZDqXmuoNurxp.** Three questions (lamp-head pair,
ad-screen pair, what is left uncut), answers saved at `db` doc `answers/camera` (`ArtifactData get`, collection
`answers`, doc `camera`). **Orchestrator: read it at the round's close** (lesson 220). Empty at publish (checked). The
page was built from `build/camera-drawn/{terminus,yard}` (builder0, `65071cc0`) by a throwaway script; to rebuild,
`make remote T="camera-drawn DRAWN_ARENA=terminus"` and `…=yard` give the same frames and an `index.html` of each.

**Plan (in order; smallest foundation first):**
1. K1: pure `RtsCamera.drawn_layout(data)` (reads `AirshipFlight.DRAWN`, C12.2) + `solid_at` / `sight_blockers`
   (per-solid versions of `roof_over` / `sight_blocked`, same maths) → the six-map sweep test
   `test_every_shipping_map_measured_against_what_is_drawn`, printing per kit type both arms (posed from colliders =
   the game today; posed from the drawing = K2). Behaviour unchanged.
2. K2: the live camera's visual questions default to `RtsCamera.seen()` (the drawn list, cached per arena); assert
   inside-drawn == 0 on every map; a test that `drawn_layout` covers `AirshipTruth.drawn_solids` (the meshes).
   Frame pair at ~18° near a floodlight.
3. K3: `BlockCutaway._gather` grows a body's box by `DRAWN` for its type; ad screens and floodlights qualify.
   Real-node test on the Terminus; frame pair with an ad screen between camera and fight.
4. K4: play on builder0 at his pose (terminus, yard), airship shot.
5. K5: signs and `MIN_HEIGHT_M`, decided on frames.

**Green baseline:** `46bac1a3` on builder0: `>> remote: make check exited 0`, 18 targets, 1726 passed, 0 failed,
sim-baseline `01ab39b592cc9837` (unmoved), determinism `b83a374ce2fcde37`.

### K1: the table (laptop, `4a54bca2`'s test, `test_every_shipping_map_measured_against_what_is_drawn`; 49 m, 8 yaws, 10 m grid)

Poses whose camera is INSIDE a drawn solid, posed as the game did before round 12 (from the colliders) → as it does now
(from the drawing). Inside a COLLIDER: 0 on every map, both arms (round 9 holds).

| map | poses | 21° before → after | 18° before → after |
|---|---|---|---|
| yard | 5608 | 0 → 0 | 6 (4 ad screen, 2 floodlight) → 0 |
| pit | 5736 | 4 (ad screen) → 0 | 6 (4 ad screen, 2 floodlight) → 0 |
| terminus | 4392 | 4 (ad screen) → 0 | 10 (8 ad screen, 2 floodlight) → 0 |
| crossing | 5256 | 4 (ad screen) → 0 | 10 (4 ad screen, 6 floodlight) → 0 |
| sumps | 5264 | 4 (ad screen) → 0 | 6 (4 ad screen, 2 floodlight) → 0 |
| locks | 5160 | 4 (ad screen) → 0 | 8 (4 ad screen, 4 floodlight) → 0 |

**Finding: at his DEFAULT pose (21°) the camera is never in a lamp head** (17.6 m up over a 16.05 m top); the lamp head
is an 18° problem (15.1 m up), as the brief said. The ad screen traps it at 21° too (4 poses a map).

Sight lines (camera → the aim point, 1.5 m up) blocked, 21°, posed from the drawing: against colliders → against the
drawing, and what stays blocked after the cutaway (K3), by drawn box and by the kit's own TRIANGLES:

| map | colliders | drawn | ad screen (drawn) | after cut, boxes | after cut, triangles: floodlight / sign |
|---|---|---|---|---|---|
| yard | 380 | 462 | 22 | 444 | 18 / 4 |
| pit | 138 | 250 | 40 | 160 | 34 / 4 |
| terminus | 829 | 952 | 64 | 98 | 36 / 4 |
| crossing | 656 | 754 | 42 | 146 | 4 / 2 |
| sumps | 555 | 691 | 44 | 216 | 40 / 4 |
| locks | 546 | 676 | 44 | 158 | 38 / 4 |

The rest of "after cut" is cover (containers, wrecks), which is never cut by design (round 9). After K3 **no ad screen
is in any sight line on any map** (asserted).

### K2–K4: the frames (builder0, `65071cc0`, his pose FOV 35 / 49 m, seed 3, looked at)

- **Lamp head** (`make camera-drawn`, 18°, camera over a floodlight): before, 15.1 m up and half the frame is the inside
  of the lamp head, on the Terminus and the yard; after, lifted to 18.0 m (21.6°) and the street reads. Real fault,
  real fix.
- **Ad screen** (21°, camera behind a screen): before, the screen's back and housing fill the middle of the frame;
  after, it is cut (`AdScreen_38` Terminus, `AdScreen_108` yard) and the cyan light it throws on the floor stays. The
  screens found stand by the wall, so the focus in these frames is an empty corner. The mechanism is shown; a screen
  in front of a real fight is the thing to watch for in play.
- **Left uncut**: a floodlight mast framed right beside it is a pole down the middle of the frame; "THE YARD" sign is a
  strip over the floor. Both read as set dressing, not as occlusion.
- **Airship** (`make remote T="airship-shot SEQUENCE=1"`, exited 0): `meet_+00_lifted` still has the camera 49 m up,
  over the hull, with the hull in frame. The lift is unchanged.
- **Round 9's alleys** (`make remote T=terminus-alleys`, exited 0, 12 frames): still produced; block behaviour unchanged
  (collider = drawn for blocks).
- **K4 honestly:** the frames come from the real skirmish (`--skirmish`, the rig, the cutaway), scripted and frozen.
  I did not drive a live `make skirmish` with a mouse; that is a laptop-window session and his eye is the check.

### K5: `MIN_HEIGHT_M` and signs, decided

**Keep `MIN_HEIGHT_M` at 6 m and do not cut signs.** With true heights, a sign (7.65 m) would qualify. But its board is
6.3 × 1.8 m at 6–7.8 m on a 0.28 m post, and against its triangles it is on 2–6 sight lines a map in ~5000 (its box
claimed 16–20). The frame shows a landmark, not a wall. Cutting it would pop a neon name board in and out as the camera
pans (flicker for nothing) and take its floor pool with it (shared MultiMesh). The bar only matters for kit types the
cutaway grows (`DRAWN_CUT`), so leaving signs out of that list settles it. His tap on question 3 can reverse it in one line.

**Decisions:**
- **K3 cuts ad screens, not floodlights or signs** (the brief named the floodlight mast; decided on the meshes): what
  stands above a floodlight's footing is a 0.64 m mast and a 4.2 × 1.3 m lamp head (`KitYard.floodlight_mesh`), and a
  sign is a 6.3 × 1.8 m board on a 0.28 m post. Their drawn BOXES claimed 50–94 and 16–20 blocked sight lines a map; their
  TRIANGLES block 4–40 and 2–6 of ~5000, and what does the blocking is a pole or a strip, which hides a sliver of a
  vehicle, not the vehicle. The lamp-head-in-the-camera case is K2's lift. They are also drawn in the kit yard's shared
  MultiMesh WITH their floor pools, so hiding one means removing instances (pool included) through `game/theme/`
  code that is not mine. Reversible: add the type to `BlockCutaway.DRAWN_CUT`.
- The cut hides the ad screen's STANDING geometry and keeps its light spill on the floor (a 34 × 22 m quad), so cutting
  a screen does not switch off the light in front of it.
- The drawn list is a SEPARATE list; `Arena.active` and every collider are untouched (C12.3). The functions keep
  taking the list as a parameter (C11.2); only the DEFAULT changes, to `RtsCamera.seen()` — every caller of these
  functions asks a visual question (grep: camera, show's `show_look`, the airship bench; nothing in gameplay).
- The cutaway finds a body's kit type from the name `Arena._build_obstacles` gives it (`AdScreen_12`):
  `BlockCutaway.kit_type_of`. It is name-coupled on purpose (no arena change), and the Terminus test fails if the naming
  moves.

**Questions for the lead:** none open (all three answered, above).

**Requests to other streams** (none blocking):
- *arena* (`game/arena/lane_readability.gd`): nothing needed. Since his verdict the cutaway cuts only what its
  collider-based rule already models.
- *show* (`game/theme/show/tools/show_look.gd`): its `clear_pose` / `sight_blocked` calls use the defaults, so they now
  ask the drawing too. The only effect is that a capture beside a floodlight or screen lifts like the game does.

**Known issues:** the six-map sweep adds ~40 s to the test shard it lands in (builder0) and ~100 s on the laptop. The
floodlight's DRAWN box (4.2 × 16 × 2.4) is conservative for the camera's inside test: the camera lifts over the whole
box, not just the lamp head. That is a lift of ≤ 3.6° at 18° only, and zero at his 21°.

**What to playtest:** `make skirmish ARENA=terminus`, then `ARENA=yard`. Tilt to ~18° (PageDown) and pan over a
floodlight: the camera should step up over the lamp, never into it. Ad screens stay drawn (his verdict). `make remote T="camera-drawn DRAWN_ARENA=terminus"` re-shoots the pairs.

**Merge notes (shared files):** `mk/command.mk` gains `camera-drawn` (additive); `_agents/verification.md` *A collider
is not a silhouette* updated to say both call sites now ask the drawing. Everything else is in `game/camera/**` and
`tests/test_control_camera_solids.gd`.

**Lesson candidate for `orchestration.md`:** *A drawn BOX is not the drawing either.* Growing the collider to the
drawn AABB fixed "inside" (a box is conservative, which is the safe side for a camera). For "in the way", the
floodlight's box claimed 50–94 blocked sight lines a map and its triangles 4–40, and the box would have cut a tower
for a pole. For a visual question, ask the box when being wrong costs a small lift. Ask the triangles when being wrong
removes something from the picture (`TriangleMesh.intersect_segment`, headless).
