# Stream: airship, round 14 (the airship steers clear of the player's view)

> Read [`game_design.md`](../game_design.md) *Round 14 direction, first item* (his words, verbatim), `HANDOFF.md`
> *THE AIRSHIP, PASS 2: IT FLIES ITSELF* (how it flies today, why the gains are what they are, the two wrong turns kept
> in the code), the archived round-11 brief `archive/round11/airship.md` and its Status, and the headers of
> `game/theme/arena_kit/airship/{airship_pilot,syndicate_ad_airship,airship_report}.gd`. **You own** what round 11's
> airship stream owned: `game/theme/arena_kit/airship/**`, `tests/test_theme_ad_airship.gd`, `tests/test_theme_airship.gd`,
> `game/theme/fx/bench/airship_shot.gd`, the airship targets in `mk/fx.mk`, and the `_build_airship` carve-out in
> `game/theme/cyberpunk/arena_dressing.gd`. **Read-only:** `game/camera/**` (no camera stream runs; if the pilot needs
> the live camera pose and no accessor exists, add ONE additive static accessor to `RtsCamera`, list it in merge
> notes, and the orchestrator reviews it at merge).

## The lead's direction (2026-09-27, evening)

> *"frequently when we're playing the airship flies right in front of the camera and disrupting the game. I had asked
> for this because it was better than making the airship transparent, and ensuring it was visible in the game. But can
> we take a different approach here and make the aircraft choose its flight path such that it doesn't go directly into
> the player's view? IN other words, instead of trying to work around the blocking visibility from the airship, can we
> just make the airship smarter and try to avoid blocking the player's field of view?"*

Standing (round 10–12): the airship is opaque and visible, in the venue, at 1.5×; no transparency; the cutaway never
touches it; it flies from the FIXED tick (30 fps and 144 fly the same line); it climbs over what it cannot go round.

## Where things stand (verify on main)

- `AirshipPilot` is a PID rudder chasing a carrot that circles the fight's centre (`ORBIT_RADIUS`, `_read_action` in
  `syndicate_ad_airship.gd` clamps how far the orbit follows the action). **Today the CAMERA gives way**:
  `RtsCamera.clear_pose` lifts the camera out of the hull's drawn box. Nothing in the pilot knows where the camera is.
- The instrument exists: `make airship-report` (headless; per map: inside %, cruise %, **seen %** = share of the
  flight inside his frame, `SyndicateAdAirship.in_frame`, averaged over four camera yaws, an UPPER bound that ignores
  occlusion); `make airship-look` (a display; sweeps every camera yaw × the orbit at his pose); `make airship-shot`
  (frames and `CLIP=1` a 20 s clip of the live camera meeting the hull). His pose: pitch 21°, distance 72 m, FOV 35°.
- His complaint is about the LIVE camera in play, which follows his selection and orders, not the report's four
  fixed yaws. The report's "seen %" is the number to extend, not the number to trust.

## Backlog (in order)

**A0. FIRST: two War Rigs turned invisible during his play (2026-09-27 evening).** His words, verbatim, in
`game_design.md` *Round 14 direction, second item*: *"I have 2 war rigs for the game that turned invisible during
gameplay"*. He has a recording; the map and the moment go in `HANDOFF.md` when he answers. Reproduce before you
explain: a War Rig squad on the Terminus and the maps with cover (the Locks' covered swing bridges, the Crossing), his
pose, following the squad, 240 s, and a per-tick log of each rig's `visible`, its mesh instances' visibility and
cull state, whether the cutaway hides anything that is not a building, and what the camera is inside. Candidates to
KILL by measurement, not to assume (lesson 219): the cutaway (`BlockCutaway`, round 12's verdict is buildings-only);
the rig's hull art (`game/theme/` rig files: a mesh that stops drawing, a LOD or visibility range at 72 m, the trailer
vs the tractor); the airship's occlusion logic; a rig under a covered bridge. The fix lands in whichever file it is
in — **carve-out for A0 only:** `game/camera/block_cutaway.gd` (or wherever the cutaway lives) and the rig's theme
files, additive, listed in merge notes, the orchestrator reviews — with a regression test that fails without it, and
frames before/after at his pose. Report in Status with the mechanism named; message the orchestrator when it is known.

**A1. Measure the disruption as he sees it.** Extend `airship-report` (or add `airship-view`) so the camera is the
REAL one: a scripted match on the Terminus (and the yard, the Crossing) with the camera driven the way he drives it
(follow the selected squad, his pitch/distance/FOV), 240 s, and per map: **share of ticks the hull is inside the
frustum**, share it is between the camera and its focus (the disruptive case: hull nearer than the fight), longest
single intrusion in seconds, count of intrusions. Frames of the three worst moments. Numbers in Status before design,
with commit and machine. Pre-register what "fixed" means: the between-camera-and-focus share falls by most of itself,
intrusions shorter than N s, and the airship is still SEEN somewhere in his frame a fair share of the match (he wants
it visible: the venue's broadcast ship, not a ghost).

**A2. The carrot avoids the view.** The pilot's goal gets a "not in the player's view" term: given the live camera pose
(position, forward, FOV, aspect) the carrot is placed on the orbit where the hull will NOT cross the wedge between the
camera and its focus — behind or beside the camera, or across the far side of the fight only when it is above the top
of the frame. The hull's LENGTH (57 m) and the ~5 s it takes to answer the rudder mean the term must look AHEAD (the
same look-ahead the climb-over uses, 8.7 s), not react. The fight-following and the climb-over stay; the PID gains
stay (he liked the wallow). Behind a switch (`--airship-off=viewavoid` or a `static var`, name it) so A1's instrument
runs both arms from one build. Deterministic from the fixed tick still: the camera pose is sampled at the tick, and
`test_the_same_ticks_always_fly_the_same_path` must still hold given the same camera track.

**A3. Measure again, both arms, same seeds and camera track; the clip.** `airship-shot CLIP=1` of the live camera on
the Terminus, both arms, looked at; the frames of A1's worst moments re-shot. Ship ON only if A1's pre-registration
holds AND the airship is still seen. If "follow the fight" and "stay out of the view" cannot both hold on a map, say
which wins where and why, with the number.

**A4 (stretch).** When the player's camera swings onto the hull (he turns, it did not move): does the airship drift out
of the way, at what rate, and does that read as fleeing? Measure the drift rate that keeps it stately (mean |yaw rate|
today 8.5°/s; do not exceed it).

## How to verify

`make remote T=check` green on every named commit; `airship-report` and your A1 instrument both arms with commit and
machine; `test_theme_ad_airship.gd` (the determinism property, the screens-in-frame assertion) still green; the sim
baseline `6313a38d7ecd99bb` pre-registered UNMOVED (the airship is dressing; nothing in the simulation reads it).
Look at your frames and the clip.

## Don't touch

`game/camera/**` beyond one additive accessor for A2 and the A0 fix in the cutaway (both listed); `game/theme/` rig files beyond the A0 fix; `game/arena/**`, `arenas/`; `game/ai/**`; `game/garage/**`;
`game/tactics/**`. No transparency, no fade, no cutaway of the hull: his words.

## Waiting on the lead

Nothing. His words are in. If A3 finds the two goals cannot both hold, the trade goes in Status for him with frames.

## Status

_(the worker keeps this current)_
