# Stream: camera (the camera glides; what he is about to click stays still under his cursor)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 41** (C41.1, C41.4), and the camera history
> in `game/camera/rts_camera.gd`'s header (his settled pose: pitch 21, distance 49 m, FOV 35, auto_frame on; do NOT change the pose or
> the lens). **You own:** `game/camera/**`, `game/theme/fx/camera_shake.gd`, `game/ui/camera_readout.gd`, `tests/test_camera*.gd`,
> `tests/camera/**`, `mk/camera.mk` (new). **Model:** Opus. **Machine:** builder0 light lane (J<=4); a render or a played session needs
> a display (laptop, one Godot run at a time under the laptop lock; builder2 has no desktop). **Seeds:** 9501-9512 if you need seeded
> matches (C41.1).

## The lead's direction

His playtest of round-40 main (2026-10-26, verbatim in `game_design.md`): "we have some pretty good camera work, but it also jerks
around a lot, which becomes problematic if I'm trying to command a bunch of units to attack a target, and then it's hard to click on the
target because the camera jerks. I think ideally the camera moves around in smooth cinematic motion (unless there's a good reason not
to)."

So: keep the camera work he likes (it finds the action; his pose), lose the jerks. Two bars in his words: (1) the view moves in smooth,
eased motion: no snaps, sudden swings or jitter in play; (2) while he is commanding (aiming at a target, dragging, an order pending)
the target under his cursor doesn't slide away. A cut is allowed only for a reason he'd accept (he pressed a key to jump).

## Where things stand (main at launch: see HANDOFF)

- `rts_camera.gd` (the skirmish camera, 1452 lines): pan / zoom / tilt / rotate / follow (F) / overview (O), plus the "vision camera"
  `auto_frame` that takes the view to his units' sight (on by default: his pose line). `cinematic_camera.gd` is the spectator director
  (`--cinematic`, shots and cuts: not his play camera). `camera_shake.gd` (hit shake), `block_cutaway.gd`, `camera_looks.gd`.
- No one has measured the camera's motion. Nothing on main tells a jerk from a glide.

## Backlog (in order)

1. **K1 find every jerk (report first).** Instrument the play camera: per frame, the change in pose (position, yaw, pitch, distance,
   FOV) and its second difference (acceleration), plus WHO moved it (player input, auto_frame, follow, shake, cutaway, clamp/bounds).
   Run his case: a played skirmish at his pose, many squads, orders onto targets (an autoplay that issues orders like a player is fine;
   say what it does). Report the jerk events by source: size, how often, and the frames. Also measure "target slip": how far (screen
   px) a fixed ground point under the cursor moves in the 0.5 s before a click. Send the table to the orchestrator before fixing.
2. **K2 smooth it.** Fix each source K1 names: eased (critically damped) motion instead of snaps; a dead zone and slower re-framing for
   auto_frame; no re-framing while he is aiming (C41.4: ask orders for a read-only "player is aiming" getter if you need one; don't
   edit `game/control/**`); shake that never moves the ground under the cursor. Every behaviour behind one switch with an =off escape;
   approved-looking changes ship ON (his rule: approved content ships ON).
3. **K3 judge it.** Before numbers, write the lines (jerk events per minute by source, target slip p95) with their pass levels, on fresh
   runs (9501-9512 if seeded). Then the frames: a short before/after clip or contact sheet for the lead. **He is the only check that
   counts for feel**: the orchestrator puts the clip and the `make skirmish` commands in front of him.

## How to verify

`tests/test_camera*.gd` for the pose math (pure, no screen); K1's trace for numbers; `make quick-remote`; a full check of every hash you
name. Smoke he can run: `make skirmish ARENA=terminus` with and without your switch: select all, attack a target, click it.

## Don't touch

`game/control/**` (orders'; C41.4), the pose/lens defaults (his), `game/ui/**` except camera_readout, `native/**`, `tests/baselines/**`.
Don't push.

## Waiting on the lead

The clip, when K3 has one.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
