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

_Worker: airship. Last updated 2026-09-24 (morning). **DONE: all six backlog items complete. THIS COMMIT IS GREEN, MERGE HERE:
`1a79f392`** (builder0: `make check exited 0`, `check passed: 18 targets`, **1697 passed, 0 failed**, sim-baseline
`457b5e830708b439` unmoved, determinism `bcc6e1609c14e12d`). Lead gate: his eye on the frames and the clip. `c58aaf16` (S1–S5 first version) is green on builder0: `make check exited 0`,
1695 passed / 0 failed, sim-baseline `457b5e830708b439` unmoved._

### Plan (in order, smallest foundation first)
1. S1 the flying test (red on the old tree, with its number) → 2. S2+S3 one flight object (`AirshipFlight`): real rotated
boxes grown to what is DRAWN, the hull as the parts that can hit something, a climb planned by flying a ghost ahead →
3. `make airship-report` (inside / cruise / seen per map, before and after) → 4. S4 the ordering, decided and tested
at the (±100, 0) blocks → 5. S5 `clear_pose` takes moving occluders; the live camera lifts over the hull, damped →
6. S6 `airship-shot` posed through `clear_pose`, with a Terminus sequence → 7. check on builder0, frames, Status.

### Done so far (numbers: laptop, working tree on `a04d75c0`; builder0 check pending)
- **S1.** `test_it_flies_the_terminus_for_four_minutes_without_entering_a_building` flies the node for 240 s (the fight
  in the middle, then pushed to each side). **Before-arm on the old tree: the hull was inside something 37.5 % of the
  flight; worst 17.8 m of the (40, 0) block above its belly, at t = 0.1 s — the START POSITION was inside the block's
  corner.** Its ground truth is `AirshipTruth`, which shares no geometry with the flight: the layout's boxes grown to
  the kit's own meshes, and the hull's own mesh rasterised to a 1 m underside heightmap. Mutation-checked: a late
  climb (`CLIMB_LEAD` 5.0) fails it with 10.5 m of block.
- **S2 + S3.** `AirshipFlight` (new) is the whole flight: pilot, height, solids, orbit. The node, the tests,
  `seen_fraction` and the report all step the same object, so what is measured is what is drawn.
  - **Solids** are the layout's own rotated boxes (obstacles incl. stacks, plus non-colliding props), grown to what is
    drawn (`DRAWN`): floodlight **16.05 m** (its mast and lamp head, 4.2 m wide), sign **7.65 m**, ad screen **20.7 m**
    (beacon). The brief's "3 m floodlight" was the collision footing: the mast would have gone through the hull. A
    test measures the kit meshes to hold the table honest.
  - **The hull is two parts, not a 57 × 22 m box**, measured off `arena_airship` in 20 slices: a **14.4 m keel** down
    to the belly, and **wings to the full 22.2 m beam whose underside is 2.95 m below the centre** (8 m above the
    belly). A test rasterises the mesh's underside and fails if any drawn cell hangs below the model.
  - **The climb rule (S3):** fly a ghost pilot ahead; for every roof `r` its footprint will cross at `t` s, hold at least
    `r − 0.8 × CLIMB_MPS × t` now (the latest the climb can start, a fifth held in reserve). The converse falls out:
    once the footprint is off the last roof and nothing is ahead, it sinks straight back (test: it starts down within
    1.5 s of leaving a roof, every crossing, and spends most of a one-block flight at cruise).
  - **Tuning, each measured with `make airship-report`:** `ROOF_CLEARANCE` 3 → **1 m** (at 3 m the maze's 152
    two-high container stacks held it 2 m over cruise all match); `CLIMB_MPS` 2.4 → **3.2** (better on all six tall
    maps, still 0 % inside); **the orbit bends toward open ground**, re-choosing its radius from 1.0–1.6 × 62 m by the
    climb the next stretch would cost (never smaller: a 40 m orbit made it loop on the spot on the Sumps); avoidance
    ignores what it is already high enough to clear (steering off a roof it is flying over swung the carrot behind it).
- **S4, decided: containment wins sideways, height wins over buildings.** The (±100, 0) blocks run to within 1 m of the
  play radius, so no goal satisfies both in that band; the wall has a crowd behind it and only steering keeps the hull
  off it, whereas a building is cleared by the climb whatever the steering does. Containment stays last and absolute;
  the hull goes over the outer blocks. Test: `test_by_the_wall_it_stays_inside_and_goes_over_the_outer_blocks`.
- **S5.** `RtsCamera.clear_pose(..., occluders := [], grow := 0.0)`: moving solids are a PARAMETER (C11.2 holds: pure,
  headless, the six existing callers untouched and provably unchanged over the Terminus grid). The live camera gathers
  boxes from the `camera_occluders` group (`SyndicateAdAirship.camera_occluder()`: the hull's footprint from belly to
  the top of its FINS, 10.9 m above centre, not the deck screen), grows them `HULL_LEAD_M` 6 m so it moves before the
  hull arrives, and then — **decided from the frames, after two wrong versions:**
  1. *Tilt about the focus* (the building rule) carried the camera in toward the fight and left the hull behind it:
     the fight from 43 m up and no airship.
  2. *Straight up* still left it behind the lens: when they meet, the hull's centre is as often behind the camera as in
     front (the Pit's frame: 28 m behind).
  3. **Shipped: up over the fins AND back along the boom until the hull's far end is in front of the camera** (at most
     `HULL_BACK_MAX_M` 40 m back), so the hull lies between him and the fight, under the sight line. **Never in**: if no
     tilt ≤ 70° clears it, the hull is let pass (`hull_passing`). Damped per axis (`ease_hull_lift`: 0.3 s rise, 2 s
     hold, 2 s settle), measured from the pose WITHOUT the lift so rising out of the box cannot talk it back down.
  Tests: lifted above the top, never nearer the fight; the hull behind the camera at three yaws still ends in frame
  (≥ 25 % of its samples lengthways, ≥ 8 % broadside, where it runs off both sides); an unclearable hull is let pass;
  three minutes of the real flight past a parked camera at 60 fps do not pump and put the camera inside the hull on
  almost no frames.
- **S6.** `airship-shot` poses every frame through `clear_pose` with the airship as an occluder. `SEQUENCE=1` flies ahead
  to find (a) the first time the hull's footprint goes from open ground onto a roof and shoots the approach from a fixed
  camera, and (b) the first moment the hull reaches his camera, shot as it was (inside) and as the lift has it.
  `CLIP=1` drives the scene's own `RtsCamera` — the real damping — through the meeting at 10 fps into `clip.mp4`.
  Benches that jump about in time set `exact_replay` (a long catch-up otherwise skips planning to avoid a hitch, which
  flies a slightly different line — found because the first "lifted" frame was not lifted).

### Frames for the lead — `assets/review/airship_r11_frames/` (laptop render, `1a79f392`)
- `1_…BEFORE_inside` / `2_…AFTER_up_and_back` — the Pit, the tick his camera meets the hull: before, the camera is
  inside it; after, the hull fills the right third of the frame over the fight.
- `3_pit_climbs_over_ad_screen_*` — the hull rising ahead of a 20.7 m ad screen, passing over it clear, settling back.
- `4_terminus_camera_meets_hull_AFTER`, `5_terminus_hull_up_over_the_roofs_110m_boom` — the Terminus trade-off in one
  picture: even from a 110 m boom the hull is up over the roofs at the top edge.
- `6_pit_live_camera_meets_hull_20s.mp4` — **the one to watch.** 20 s of the live camera: the hull arrives, the camera
  rises and backs off, the hull passes, it settles; the hull comes round again and for several seconds it fills most
  of the frame (dish, fins, the flank screen playing the feed). That second pass is his "see the cool airship" and it
  also hides the fight: **his call** (question 3).
- Known bench artifact: in the Terminus meet frames at ±2 s the camera sits 2 m over a block roof (the round-9
  building rule) and the roof fills the frame; the game's `BlockCutaway` removes that block, the bench camera does not.

### The numbers (240 s per map, four one-minute legs; laptop; before = `a04d75c0`, after = `c58aaf16`)
`make airship-report` — inside % (any part of the hull inside anything drawn; must be 0), cruise % (at the low
cruise height), seen % (in his frame at his pose, averaged over 4 camera yaws; an upper bound, no occlusion):

| map | inside % | cruise % | seen % |
|---|---|---|---|
| terminus | 31.2 → **0** | 6.7 → 0 | 2.7 → 0 |
| yard | 0 → 0 | 100 → 77 | 31 → 26 |
| pit | 22.7 → **0** | 91 → 43 | 29 → 16 |
| boneyard | 0.9 → **0** | 100 → 91 | 34 → 34 |
| boulevard | 39.8 → **0** | 56 → 8 | 24 → 6 |
| crossing | 49.0 → **0** | 47 → 5 | 16 → 1 |
| sumps | 43.8 → **0** | 56 → 26 | 17 → 14 |
| maze, barriers | 0 → 0 | 100 → 100 | 33 → 32 |

**Read it honestly: much of the old "cruise" and "seen" was the hull flying through buildings.** It no longer does
anywhere, and on the dense maps it pays for that in time up over the roofs, where his frame cannot reach it (at his
pose the frame's top edge is 3.5° below the horizon from 17.6 m up, so anything above ~15 m at 45 m range is out).

### Questions for the lead (each with my recommendation)
1. ~~The Terminus~~ **RULED (2026-09-24, via the orchestrator): keep it as a zoomed-out sight there.** Written into
   `syndicate_ad_airship.gd`'s header with the numbers that force it.
2. **Climb speed 3.2 m/s** (was 2.4). **Recommendation: keep 3.2.** It measured better on all six maps with tall props
   (yard cruise 52 → 61 %, pit 28 → 32 %, sumps 12 → 18 %, 45 s legs, laptop) with still 0 % inside anything, and a real
   airship manages 3–5 m/s. Drop to 2.8 only if, in play, the rise over an ad screen reads as a lift rather than a drift.
3. **The camera and the hull.** **Answered: he watched `6_…mp4` and said "it looks fine"; S5 is approved as shipped.**
   (My recommendation had been: no change — `HULL_BACK_MAX_M` 40 m and the 2 s hold stay.)

### Time at cruise, before and after, per map (the part he will notice in play)
`make airship-report`, 240 s per map (four one-minute legs), laptop; before = `a04d75c0`, after = `c58aaf16`. Cruise % is
the share of the flight at the low cruise height (centre 18.2 m, belly 6.2–7.4 m), where he can see it.

| map | cruise % before → after | in frame % before → after | inside something % before → after |
|---|---|---|---|
| terminus | 6.7 → 0 | 2.7 → 0 | 31.2 → 0 |
| yard | 100 → 77 | 31 → 26 | 0 → 0 |
| pit | 91 → 43 | 29 → 16 | 22.7 → 0 |
| boneyard | 100 → 91 | 34 → 34 | 0.9 → 0 |
| boulevard | 56 → 8 | 24 → 6 | 39.8 → 0 |
| crossing | 47 → 5 | 16 → 1 | 49.0 → 0 |
| sumps | 56 → 26 | 17 → 14 | 43.8 → 0 |
| maze, barriers | 100 → 100 | 33 → 32 | 0 → 0 |

**Two corrections to the brief's expectation, so HANDOFF does not repeat them:**
- **The floodlight is not 3 m. It is a 16.05 m mast** (a 3 m footing, a 15 m mast and a lamp head, measured off
  `KitYard.floodlight_mesh()`). 3 m is only its collision box. The fix was 24 m → 16 m, not 24 m → 3 m, so it saves
  far less climbing than the brief predicted: a 57 m hull still has to go over or round each mast.
- **Cruise time went DOWN, not up.** The old "cruise" numbers were high because the hull flew through whatever was in
  its way at cruise height (the yard's 100 % included time inside ad screens). Now nothing is flown through, so every
  map with tall props spends time climbing. The honest headline for him: **it never goes through anything any more;
  on open maps he still sees it low most of the time (yard 77 %, boneyard 91 %, maze and barriers 100 %); on the
  dense maps it is up over the roofs more.** The climb and settle rate (2.4 → 3.2 m/s), the 1 m roof clearance and the
  orbit that bends toward open ground were each chosen because they won back cruise time without letting it go
  through anything.

### Known issues
- A mid-match dressing rebuild re-flies the flight from tick 0; with the planner that is 0.6–1.0 s of work on the laptop
  under load (≈0.2–0.4 s on builder0-class hardware) for a 40 000-tick match. The catch-up already skips planning;
  bounding it further would change what `advance_to(tick)` means for the shot tool, so it is left and reported.
- Live cost: 80–250 µs per 30 Hz tick on the laptop (boulevard is the worst: many masts).

### What to playtest
- `make skirmish ARENA=pit` (and `yard`, `boneyard`): watch the airship climb over the ad screens and settle; pan the
  camera onto its path and let it come through — the camera should rise and back off with the hull in front of it.
- `make skirmish ARENA=terminus`: it should never be inside a block; it will be up over the roofs, seen by zooming out.
- Numbers: `make airship-report` (headless, ~2 min on builder0 for nine maps). Frames: `make remote T="airship-shot
  ARENA=pit CLIP=1"`.

### Merge notes
- Shared file edits: none. `arena_dressing.gd` is untouched (the carve-out was not needed). `rts_camera.gd` is ours this
  round; `clear_pose`'s new parameters default to the old behaviour, so the six other callers are unchanged.
- `SyndicateAdAirship.seen_fraction` now takes the layout first (`seen_fraction(layout, action, seconds)`); its only
  callers are ours. `blockers`, `required_altitude`, `start_position`, `clearance_at` and `TALL_PROPS` are gone
  (replaced by `AirshipFlight`).
- C11.1: when arena's rotation merge is announced, `git merge main` and re-run `make airship-report` and the airship
  tests (they already walk crossing and sumps).

### Next steps
- Stretch, if the lead wants more of it on dense maps: a per-map
  "cruise corridor" planner (the orbit choice is local; a global route through the green of the cruise-clear map would
  raise cruise % on the Boulevard and Crossing).
