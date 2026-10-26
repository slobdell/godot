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

**2026-10-26: K1 DONE (report below, sent to the orchestrator); K2 in progress.**

### Plan (in order; reasons in one line)
1. K1 instruments: `CameraTrace` (per frame, the screen motion of the ground under the cursor split by WHO moved it, by
   replaying the rig's pose math one part at a time so the parts sum to the whole) + `CameraPlaytest` (a scripted player in
   his case) + `make camera-trace` (headless, builder0 light lane) + `tests/camera/camera_report.py`. DONE.
2. K1 census on dev seeds 7001-7006 (never a bar), default camera v a held camera (the floor). DONE.
3. K2 one switch `--camera-glide=on|off` (ON): critically damped glide for every automatic move, a leash on the vision
   frame, hold while he aims, eased building clearance, a shake pivoted on the cursor's ground. IN PROGRESS.
4. K3: bar lines written before any fresh number (9501-9512), then the clip / contact sheet for him.

### K1 report: what moves the camera under his cursor (round-40 main = de509b00f code; builder0; headless 1920x1080 at 60 fps)

Workload: `make camera-trace CAMERA_SEEDS="7001 ... 7006"` (Terminus, CPU enemy, the default army, his pose: pitch 21,
49 m, FOV 35, auto_frame and yaw follow ON). The autoplay (CameraPlaytest): every 1-3 s select (ctrl+A half the time, else
a group key), then if an enemy is on screen move the cursor onto it, hold 0.5 s, right-click it (attack); else right-click
the ground up-screen (move). 150 s a seed, 9.9 min of play, 189 clicks (74 attacks). Numbers are px at 1080 rows.
A JERK = a frame where one source's screen velocity changes faster than 15,000 px/s^2 (an eased move of the same size
peaks near 5,000; a lerp from rest at the rig's smoothing is ~200,000); a SNAP = one frame moving the ground > 24 px.

| source | jerk events | per min | dv p50 (px/s) | dv p95 | snaps | reversals/min | px moved/min |
|---|---|---|---|---|---|---|---|
| auto_frame (vision camera re-framing) | 134 | 13.6 | 510 | 1507 | 69 | 11.4 | 5274 |
| yaw_follow (turning to the selection's facing) | 34 | 3.5 | 371 | 893 | 0 | 3.0 | 7681 |
| solid (keeping out of buildings) | 56 | 5.7 | 1646 | 4692 | 22 | 3.2 | 201 |
| all together | 224 | 22.7 | 506 | 2479 | 182 | 15.8 | 11600 |

No player-input, follow, order-tracking or cap events in this workload (the autoplay never pans; cap moved 65 px/min in
the held arm only). 106 of 134 auto_frame events are ONE frame (the goal jumps: a contact appears or drops, the destination
is set, the selection changes, and the lerp leaves at full speed); the largest auto_frame event moved the ground 780 px.

**Target slip** (the ground point under the cursor 0.5 s before the click, how far it slid by the click): p50 30.8 px,
p95 388.5, max 1087; 166 of 189 clicks over 10 px, 69 over 50 px. Slip by source (p95 over the clicks it touched):
yaw_follow 468.5 px (74 clicks), auto_frame 100.2 (187), solid 33.4 (11). **Attack clicks still on the aimed unit: 37 of
74 (50 %).** Held camera (`CAMERA_FLAGS=--camera-hold`: auto_frame and yaw follow off; same seeds, machine): slip p50 0,
p95 0, max 14.3 (cap); **49 of 62 (79 %)** still on the unit, the rest is the unit's own motion. So the camera's own moves
cost him about 3 attack clicks in 10.

Not measured headless: **camera shake** (FxWorld, and so CameraShake, exists only with a renderer): `make
camera-trace-windowed` measures it on a display (pending: builder0's desktop or the laptop under its lock).

### Decisions
- Jerk/snap thresholds are perceptual and fixed BEFORE any K2 number (JERK_PX_S2 15,000, SNAP_PX 24, at 1080 rows).
- The aiming signal (C41.4): an adapter in the rig until orders' getter exists (a button held, an armed `mode`, the
  cursor on a unit via the public `pick_unit`, or the hand moved in the last 0.6 s); it reads `game/control/**`, never edits.
- His own input (keys, wheel, drag, F follow, O overview, jumps) keeps its quick smoothing: not the jerk he reported.

### Requests to other streams
- **orders (C41.4):** a read-only `RtsControls.is_aiming() -> bool` (cursor on a unit, a box or right-drag in progress, an
  armed order), and one line in `skirmish_mode.gd` next to `rig.facing = ...`: `rig.aiming = controls.is_aiming`. Until it
  lands the rig's adapter does the same from public members.

### Questions for the lead
_(none yet)_
