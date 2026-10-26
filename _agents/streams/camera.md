# Stream: camera (the camera looks where the danger is: an ambush from the side is on screen; a retreat looks back at the fight)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 42** (C42.1, C42.3), your round-41 brief
> `streams/archive/round41/camera.md` (Status: K1 census, K2's glide, Bar K3 v2, the clip recipe, the copy-back wipe) and the camera
> history in `game/camera/rts_camera.gd`'s header (his pose: pitch 21, 49 m, FOV 35: do NOT change the pose or the lens). **You own:**
> `game/camera/**`, `game/theme/fx/camera_shake.gd`, `game/ui/camera_readout.gd`, `tests/test_camera*.gd`, `tests/camera/**`,
> `mk/camera.mk`; GRANT (C42.3) read-only feed lines in `game/modes/skirmish_mode.gd` beside `rig.facing` (:564). **Model:** Opus.
> **Machine:** builder0 light lane (J<=4); a clip needs the laptop (one Godot run under the laptop lock). **Seeds:** 9701-9736 (Bar K4,
> 36 an arm: R41.14's lesson). Dev 7001-7012, 9501-9512 (never a bar).

## The lead's direction (2026-10-26, verbatim)

"ok, I want to say the camera work needs improvement, but I don't know exactly how to describe what's wrong or how to fix. Maybe you
can make some suggestions. Basically the camera is in line with my initial guidance that perspective is actually a limitation of the
game, but basically we get impractical camera angles relative to where the actual fight is happening. THis is a subtle detail that
will make a player feel like the game is no good - if the camera is following the direction at which a squad is moving, and then
there's an ambush from the east (assuming we're driving north), the camera doesn't end up pointing at the action. In general, action
is usually happening in the middle of the map sow hen the camera is pointing outward it's a little impractical. All to say: I know the
camera behavior is currently in line with my previous guidance which was correct in spirit. What do you recommend here?"

His follow-up: "ok great - would it otherwise make sense to just take some sort of weighted average of where the danger is or
something? Key use case I just experienced: I had a group of scouts drive back behind my own lines to the edge of the map, and the
camera pointed out completely to the audience. This of course has no meaningful utility, but it miht be correct behavior in order to
maintain abstractions and mitigate special cases"

**Agreed design (the orchestrator with him; his OK pending only in that he hasn't played it): one rule, no special cases.** The look
direction is a weighted sum of unit vectors from the selection: (a) its heading, weighted by speed and lightly; (b) each known enemy,
weighted by threat (closer, firing at us, recently hit us weigh more; memory decays over seconds); (c) a "where the war is" pull, toward
the centroid of known enemies, else the arena's middle. His retreat-to-the-edge case falls out: (b)+(c) outweigh a backward heading.
Guards: when the sum nearly cancels (threats on opposite sides) keep the current yaw; a deadband and a minimum hold time stop it
swinging; no turn while he aims (C41.4's `aiming` stands); his manual yaw wins for the hand-back time; the turn speed is the glide's.

## Where things stand (main at launch: see HANDOFF)

- `--camera-glide` ON (Bar K3 v2 PASS, R41.17): every automatic move is a critically damped glide capped at 0.6 screen heights/s;
  held while he aims. The yaw comes ONLY from the selection's facing: `_update_yaw_follow` (rts_camera.gd:1237, `facing` from
  `controls.selection_facing`, YAW_FOLLOW_DEG_PER_S 70, deadband 12, settle 2). Enemies move the frame's centre and zoom (`auto_frame`,
  `rig.vision = controls.vision_state`: what his units see), never its direction. At pitch 21 with a 35 deg lens the view is a narrow
  wedge: a fight 90 deg off the heading is simply off screen.
- Feeds the rig has: `facing`, `aiming`, `vision` (his team's sight), `hud_bottom`; the arena's bounds for the clamp. Feeds it lacks:
  who is shooting at the selection / who hit it lately (the match has shell and hit events; `game/ai/incoming_fire.gd` reads
  projectiles toward a unit), the arena's middle as a point.
- Your instruments: `CameraTrace`, `CameraPlaytest`, `make camera-trace`, `camera_report.py`, `make camera-clip` (film outside `build/`
  or copy the mp4 out before any `make remote`: the copy-back wipes it).

## Backlog (in order)

1. **K4.1 the look census (report first).** Add to the trace, per frame: the bearing from the view's yaw to (i) the nearest enemy
   shooting at the selection, (ii) the centroid of known enemies, (iii) the arena's middle; and the events: an enemy's first shot at
   the selection from outside the view, and when that shooter is first on screen. Workload: an ambush autoplay (the selection drives
   north on terminus / locks, a CPU squad seeded on its flank or rear; 2-3 lanes), plus his retreat case (a scripted retreat of a
   scout squad to the arena's edge behind his lines). Report on dev seeds: seconds from first shot to shooter on screen (p50 / p90),
   the share of play with no enemy on screen while one is firing at the selection, the share of play facing the wall (the arena's
   middle behind the camera). Send the table to the orchestrator before building.
2. **K4.2 the rule, OFF behind `--camera-danger` (ON when its bar passes; `=off` = round 41).** The agreed design above, in `rts_camera.gd`
   beside `_update_yaw_follow` (the yaw's one writer). Data in through read-only Callables set in `skirmish_mode.gd` beside
   `rig.facing` (GRANT, listed in merge notes): known enemies of his team with position, "firing at us" and "hit us" recency, and the
   arena's middle; nothing in `game/control/**` or `game/match/**` changes behaviour. Weights as constants with reasons; a readout line
   in `camera_readout.gd` (dev only) showing the three pulls. Dev reads on 7001-7012 only.
3. **K4.3 Bar K4, filed before any number on 9701-9736.** BASE `--camera-danger=off` v ARM on, one commit, both arms, `make camera-trace`,
   builder0 light, headless 1920x1080 @60, the ambush autoplay + his retreat case, 36 seeds an arm. Deciding: seconds from first shot
   to the shooter on screen (p50 and p90) ARM < BASE by >= 2 se; share of play facing the wall ARM <= half BASE. Guards (filed first,
   unamended): Bar K3 v2's lines 1-3 at their levels (clicks on the aimed unit >= 70 %, slip p95 <= 40 px, jerks <= 3/min, automatic
   snaps 0), held <= 25 % of play, action share >= BASE - 10 points, yaw reversals per minute <= BASE + 1 (no swinging), no SCRIPT
   ERROR. A pass ships ON.
4. **K4.4 the clip for him.** `make camera-clip` on an ambush seed and on his retreat case, LEFT round 41 (danger off), RIGHT on; film
   outside `build/`; the orchestrator puts it in front of him with the `make skirmish` commands. He is the only check for feel.
5. **Stretch:** an edge marker for an off-screen hit (needs a UI file: request it through the orchestrator; `game/ui/**` is nobody's).

## How to verify

`tests/test_camera*.gd` for the pure math (the weighted sum, the cancel guard, the deadband); the trace; `make quick-remote`; a full
check of every hash you name. Smoke like a player: `make skirmish ARENA=terminus` v `SKIRMISH_FLAGS="--camera-danger=off"`: drive a
squad north, get ambushed from a side street, retreat a scout squad to the edge: does the view turn to the shooter, does it look back
at the fight on the retreat, does it ever swing?

## Don't touch

The pose / lens defaults (his), `game/control/**`, `game/ui/**` except camera_readout, `game/tactics/**` (engage), `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

The clip, when K4.4 has one.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
