# Stream: airship (it flies through the buildings, and the camera flies through it)

> Read [`game_design.md`](../game_design.md) *Round 11 direction* and *THE AIRSHIP, PASS 2* in
> [`HANDOFF.md`](../../HANDOFF.md) (the airship's whole design, its measurements and its two wrong turns), then
> [`workstreams.md`](../workstreams.md). **You own** `game/theme/arena_kit/airship/**`, `game/camera/**`
> (`rts_camera.gd`, `block_cutaway.gd`), `tests/test_theme_ad_airship.gd`, `tests/test_control_camera_solids.gd`,
> `game/theme/fx/bench/airship_shot.gd` and the airship targets in `mk/fx.mk`; **plus one carve-out**:
> `_build_airship` (`game/theme/cyberpunk/arena_dressing.gd:140-155`) — arena owns `_build_tower` in the same file.

## The lead's direction (2026-09-23, night)

> *"I also notice that the camera can end up inside the airship - similar to what we did with buildings, it would be
> ideal if the camera and airship intersected, we push the camera up above the airship (that way there's more
> likelihood of seeing the cool airship for an in-game effect)."*

> *"It also looks like the airship itself ends up intersecting with the buildings in Terminus as it flies around."*

**Note what the first one is asking for.** It is not "stop the camera clipping the hull" — it is *"use the collision
as an excuse to show the airship off"*. The round-9 rule pushes the camera **outside** a solid; this one has a
direction: **up and over**, so the hull comes into frame.

## Where things stand (surveyed before this brief; verify every number, do not trust it)

### The camera's solid rule is pure math over the layout, and the airship is not in it

`RtsCamera.clear_pose` (`game/camera/rts_camera.gd:586-607`) is the round-9 rule, and its own header carries his
older quote and the design decision: **"So: lift first, and shorten only when even `MAX_PITCH_DEG` cannot clear the
roof"** (`:524`). It loops `SOLID_PASSES` (6) over `roof_over(...)`, lifting pitch to put the boom `SOLID_CLEAR_M`
(2.0 m) above the roof, and only shortens the boom when the lift is capped.

**It casts nothing.** No ray, no collision layer, no mask: `roof_over` (`:536-549`) reads
`Arena.active["obstacles"]` and uses `ArenaKit.distance_to_footprint` on a **rotated rectangle** — so it works
headless, which is why it is testable. The airship is a `Node3D` under `ArenaDressing.structures` with **no entry in
`obstacles`, no collider, and a moving transform**: it is structurally invisible to the one mechanism he is pointing
at.

And the camera provably *is* inside it — the airship's own header says so
(`syndicate_ad_airship.gd:70-76`): his camera sits at **17.56 m** (49 m boom, 21° pitch) and the hull spans **belly
6.20 m to deck 22.76 m**, half-beam 11.10 m, half-length 28.5 m. The camera height is inside the hull's height range
by design — that is the same geometry that killed the belly screen in pass 2.

### The airship flies through the Terminus for three separate, measurable reasons

`SyndicateAdAirship.blockers()` (`:181-194`) reads **real prop positions** from the layout but substitutes a
**hard-coded circle** from `TALL_PROPS` (`:105`) for the extent, dropping `rotation_deg` and `stack` and never
consulting the real `ArenaKit` box:

1. **The circle does not contain the block.** `ArenaKit.PROPS["block"]` is **40 × 40 m** — half-width 20 m on axis,
   but **28.28 m to a corner**. `TALL_PROPS["block"]` says `radius 21.0`. The circle is **7.28 m short at every
   corner.** A point 32.2 m from a block centre *on the diagonal* scores `clearance = 32.2 − 21 − 11.1 = +0.1 m` →
   "clear", while the real corner is 3.9 m away and the hull's half-beam is **~7 m inside the building**. The
   existing start-position test passes with the hull in the block.
2. **The climb is triggered far too late to be flown.** Arithmetic from the constants, all of which you should
   re-derive rather than believe: cruise centre `ALTITUDE` 18.20 m; required centre over a 24 m block **39.00 m**;
   climb needed **20.80 m**; at `CLIMB_MPS` 2.4 that is **8.67 s**. The trigger radius is `radius + BEAM*0.5` =
   32.10 m from the centre, the block face is at 20 m, so the lead-in is **12.10 m**, crossed at `CRUISE_MPS` 7.5 in
   **1.61 s**, in which it climbs **3.87 m of the 20.80 it needs**. It arrives at a 24 m roof with its belly at
   ~10 m and **flies through 14 m of building**. Worse, the hull's **nose is 28.5 m ahead of `pilot.position`**, and
   `required_altitude` is evaluated at the current centre point only (`:353`) — the nose is already ~16 m inside the
   footprint before the rule fires. **There is no look-ahead anywhere.**
3. **`contain` runs after `avoid` and erases it exactly where the outer blocks are.** The ordering at `:349-351` is
   deliberate ("Containment LAST, so neither the orbit nor an avoidance push can send it through the wall"), but on
   the Terminus `play_radius` = 118.90 and `CONTAIN_FROM` 0.72 means containment bites from **85.6 m** — and the
   Terminus has blocks at **(±100, 0)** spanning x 80…120, entirely inside that band. `contain` lerps the goal toward
   the origin and hard-clamps at `radius * 0.9` = 107 m, **deleting the outward avoidance push at precisely those two
   blocks**.

**A fourth thing, which is a gift rather than a bug.** `TALL_PROPS["floodlight"]` is `[4.5, 24.0]` while the real kit
floodlight box is `[2.4, 3.0, 2.4]` — **a 3 m concrete footing entered in the table as 24 m tall**, and the Terminus
has four of them at (±14, ±14), near the centre of the orbit. So the airship climbs to 39 m to clear a knee-high
post. That is most of why HANDOFF reports it at its low cruise height only **52 % of the time on the Terminus** (vs
96 % on the yard). Fixing the table makes it fly lower and be seen more — which is the same thing he is asking for
in his camera sentence.

### Why the tests did not catch any of it

`tests/test_theme_ad_airship.gd` has 18 tests and they are good, but:
- `test_it_climbs_over_what_it_cannot_fly_around` (`:306`) is a **pure static lookup at the block's own centre** — it
  never flies.
- `test_it_never_leaves_the_arena` (`:327`) is the only test that flies with `avoid` + `contain`, and it asserts only
  `position.length() < half_size` — **distance from the origin, never distance to a blocker**.

So both of his complaints are outside the test envelope by construction. That is the gap to close first.

**One more trap, worth knowing before you shoot frames:** `game/theme/fx/bench/airship_shot.gd:83,101` poses the
camera with `RtsCamera.pose_at`, **not `clear_pose`** — so airship frames do not exercise the building-lift rule at
all today, and a new airship-lift rule will not appear in your shots unless you wire it in.

## Backlog (in order)

**S1. The failing test that flies.** Before changing anything: fly the pilot on the Terminus for 240 s and assert the
**swept hull box** (centre ± half-length along heading, ± half-beam) clears every real prop footprint it overlaps,
with the belly against the real roof height. Use the camera's own primitives — `Arena.obstacle_size` and
`ArenaKit.distance_to_footprint` on the rotated rectangle — not a new circle. It must fail on today's tree, and its
failure should print where and by how much, because that number is your before-arm.

**S2. Real footprints, real heights.** Replace the `TALL_PROPS` circle table in `blockers()` with the layout's actual
boxes (rotation included), and take the heights from the kit rather than from the table. Expect the floodlight's
24 m → 3 m correction to change how the airship flies everywhere; **measure `seen_fraction` and the time-at-cruise
per map before and after and report both**, because "it flies lower on the Terminus" is the part he will notice.

**S3. Look ahead by the time it takes to climb.** `required_altitude` must be evaluated against where the hull
**will be**, not where its centre is: sample the swept hull along the next `climb_time` of travel (≈8.7 s ≈ 65 m at
cruise) and start the climb early enough to arrive above the roof. Then check the converse — it must come back down
promptly, or it spends the match at 39 m where he cannot see it. State the rule you chose in the header the way the
rest of that file does.

**S4. Fix the ordering that erases avoidance.** `contain` deleting the avoidance push at the (±100, 0) blocks needs a
composition that satisfies both: the hull stays inside the wall **and** outside the buildings. Decide it, write the
reason, and prove it with a test that flies past those two blocks specifically. If no goal satisfies both — the band
is genuinely pinched — the honest answer is to move the orbit, and say so with the number.

**S5. The camera lifts over the airship (his first sentence).** `clear_pose` is a `static` pure function taking
`data: Dictionary` and is called from six places (`show_look.gd:458`, `lane_readability.gd:47`, `camera_looks.gd:198`
and five spots in `tests/test_control_camera_solids.gd`) — so a **dynamic** occluder needs a parameter or a small
registry; pick the one that keeps the function pure and testable headless, because that purity is why this rule has
tests at all. Give `SyndicateAdAirship` a `hull_box()`-style predicate (centre, heading, length, beam, belly, deck)
in the same style as `roof_over`, and let the existing **lift-then-shorten** loop do the rest with `SOLID_CLEAR_M`.
Two things to get right:
- **Lift, don't shorten.** He wants the camera *above* the airship precisely so the hull is in frame. If the lift
  caps out, prefer letting the airship pass rather than yanking the boom in — a jerked camera in a fight is worse
  than a moment of hull. Decide, and write the reason down.
- **It moves.** A static solid can be re-evaluated every frame with no consequence; a hull crossing the frame can
  make the camera pump. Damp it, test that it does not oscillate, and look at a clip before you call it done.

**S6. Shoot it and look at it.** Wire `airship_shot.gd` to `clear_pose` so the frames show the real rule, then take
the Terminus sequence: the airship approaching a block (S1-S4) and the camera meeting the hull (S5). **Put the frames
where the orchestrator can send them to him** — this whole stream is a "does it look cool" item and his eye is the
only check that counts.

## Non-goals

**Do not give the airship a collider.** `test_the_airship_carries_no_collision_of_any_kind` (`:35`) is deliberate and
so is the pre-registered sim baseline; on `WORLD_MASK` a 57 m body at 6-23 m would block sight lines and shell
traces. Everything above is solvable with the same pure-math pattern the camera already uses. If you conclude
otherwise, stop and write the argument in Status rather than trying it.

## How to verify

- `make remote T=check` — the wrapper's own `>> remote: make check exited <N>` line and the runner's
  `N passed, M failed`. **Never through a pipe.** Confirm the sim baseline `457b5e830708b439` has **not** moved.
- `make airship-shot` (needs a display: `make remote T=airship-shot`), `SyndicateAdAirship.seen_fraction`,
  `make skirmish ARENA=terminus` and watch it fly for a few minutes with your own eyes.
- Every number carries its commit and its machine.

## Don't touch

`game/ai/**` (nav's), `arenas/` and `game/arena/**` (arena's — note arena is adding `crossing` and `sumps` to
`Arena.ROTATION` early this round, and `flies_on`/`route_for` walk every shipping map, so `git merge main` when the
orchestrator announces it and re-run your map walk), vehicle art and `game/units/units.gd` (fleet's),
`_build_tower` in `arena_dressing.gd` (arena's).

## Waiting on the lead

Nothing blocks you. S6's frames go to him for the morning.

## Status

_(the worker keeps this current: plan, what's done with measurements, decisions and their reasons, questions for the
lead, requests to other streams, known issues, what to playtest, next steps, merge notes, and the commit hash whose
own check went green)_
