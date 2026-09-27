# Stream: camera (the camera asks the drawing, not the collider)

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

_(the worker keeps this current)_
