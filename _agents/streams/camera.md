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

**2026-10-26: K1 DONE (sent). K2 built (`--camera-glide`, ON). Bar K3 v1 read on 9501-9512: FAILED line 3 (auto_frame
snaps) and showed the camera held 58 % of play; fixed (aim needs orders' getter, a click spends it; a screen-speed cap);
Bar K3 v2 filed below (R41.14: 36 seeds 9513-9548), unread. Clip: `make camera-clip` (laptop) built; re-film after v2.**

### K2 dev read (dev seeds 7001-7006, NEVER a bar; d6f0da32e's code; builder0 headless 1920x1080 60 fps)
Autoplay now carries the cursor onto the target over 0.3 s (a hand's reach) before the 0.5 s aim, both arms.
| | glide OFF (round 40) | glide ON |
|---|---|---|
| jerk events / min (all) | 18.2 (auto_frame 13.1, solid 3.1, yaw 1.7) | 0.08 (solid 0.08) |
| one-frame snaps (all) | 77 | 0 |
| target slip p50 / p95 / max (px) | 19 / 220 / 599 | 0.5 / 7.3 / 66 |
| attack clicks on the aimed unit | 38 / 69 (55 %) | 39 / 54 (72 %) |
| auto_frame px moved / min | 4766 | 2165 (it still re-frames) |
Shake (laptop, windowed 1920x1080 ~28 fps, seed 7001, 60 s each arm): shake moved the cursor's ground <= 0.5 px at any click with the
pivot (0 OFF: no hit landed near the camera during an aim); shake is small at his pose (10-45 px/min of all motion). Note: at
28 fps a smooth fast yaw counts as per-frame "snaps" (24 px/frame = 670 px/s), so snap counts are only read at 60 fps.

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

### Bar K3 v1 (FILED before any fresh number; seeds 9501-9512 unread)

Workload: `make camera-trace CAMERA_SEEDS="9501 ... 9512" CAMERA_FLAGS=--camera-glide=off` (BASE) and `=on` (ARM), builder0
light lane, headless 1920x1080 at 60 fps, Terminus, CPU enemy, the CameraPlaytest autoplay at the commit named with the
result (hand reach 0.3 s, aim 0.5 s, then right-click). Both arms on the same commit and seeds. Each line is read on the
pooled 12 seeds. **Ship ON = every line passes.**
1. **Clicks on the aimed unit** (attack clicks whose cursor still picks the aimed unit at the click): ARM >= 70 % AND ARM >= BASE
   + 15 points (his complaint; K1 read 50 % v a 79 % held-camera floor on dev seeds).
2. **Target slip p95** (px at 1080 rows, all clicks): ARM <= 40 px AND <= half of BASE.
3. **Jerk events per minute, by source**: ARM total (all) <= 3.0 / min; no automatic source (auto_frame, yaw_follow, cap,
   order_track, solid, hull) above 1.5 / min; ARM snaps from automatic sources = 0.
4. **The camera still works** (the vision camera he likes stays): ARM auto_frame px moved / min >= 25 % of BASE's (it still
   finds the action), and no CAMERA_TRACE_DONE ok=false or SCRIPT ERROR in any run.
Shake is judged separately (headless has none): a windowed laptop run, `shake` slip at the cursor ARM <= 1 px p95 (pivot).

### Bar K3 v1 RESULT (FAIL, line 3)
Builder0 light lane, headless 1920x1080 60 fps, Terminus, seeds 9501-9512 pooled. BASE (`--camera-glide=off`) on d08f63317: 15.8 min of
play, 280 clicks; ARM (on) on 01adebec9 (the same camera code; it adds only the clip overlay): 18.6 min, 321 clicks.
| line | BASE | ARM | pass level | |
|---|---|---|---|---|
| 1 attack clicks on the aimed unit | 88/154 = 57.1 % | 113/146 = 77.4 % | >= 70 % and >= 72.1 % | PASS |
| 2 target slip p95 | 308.3 px | 13.9 px | <= 40 and <= 154 | PASS |
| 3 jerk events/min (all; worst automatic source) | 16.90; auto_frame 11.08 | 0.22; solid 0.16 | <= 3.0; <= 1.5 | PASS |
| 3 automatic snaps | 146 | **12 (auto_frame)** | 0 | **FAIL** |
| 4 auto_frame px/min | 4707 | 1922 (41 %) | >= 25 % | PASS |
| 4 DONE ok=false / SCRIPT ERROR | 0 / 0 | 0 / 0 | 0 | PASS |
The 12 snaps: one smooth glide on seed 9509 (t = 97.1 s) peaking at 25.6 px/frame (1530 px/s), 12 frames over SNAP_PX 24 with
no jump in speed (dv 39 px/s). Not a lurch, but a whole screen in 0.7 s is not cinematic either: the spring had no top speed in screen
terms. **Found outside the bar:** ARM held the camera 58.4 % of play (BASE 0), because "his hand moved in the last 0.6 s" counted as
aiming and an RTS hand never rests. ARM made 7.86 attack aims/min against BASE's 9.75 (enemies on screen less often), and 4 of 12
ARM seeds ran to the 150 s cap. The laptop clip (seed 9501, 75 s) shows it: the ON arm never had an enemy on screen.
Fix: hand motion alone is no longer aiming. The hold needs a held button, or orders' `is_aiming` while the hand moved within
HOVER_HOLD_S (1.5 s); a click ends the aim. Automatic focus moves are capped at GLIDE_SCREENS_PER_S 0.6 screen heights/s.

### Bar K3 v2 (FILED before any number on 9513+; amended by R41.14 before any read; seeds 9513-9548, 36 per arm)
Workload: `make camera-trace CAMERA_SEEDS="9513 ... 9548" CAMERA_FLAGS=--camera-glide=off` (BASE) and `=on` (ARM), builder0 light
lane, headless 1920x1080 at 60 fps, Terminus, CPU enemy, the CameraPlaytest autoplay; both arms on one commit (named with the result,
the constants as shipped: GLIDE_SCREENS_PER_S 0.6, HAND_PACE 0.25, DWELL_S 0.1, HOVER_HOLD_S 1.5). Pooled over the 36 seeds.
Lines 1-4 are v1's, unamended. Read off `camera_report.py`'s table and its "Play:" line. **Ship ON = every line passes.**
5. **The camera still finds the action:** ARM held time <= 25 % of play AND the action share (seconds with an aimable enemy on
   screen / seconds of play; `CAMERA_SLIP action_s`) ARM >= BASE - 10 points.
Why 36 seeds and the action share (R41.14): on dev seeds the action share's per-seed SD is ~25 points (a camera change changes the
autoplay's choices and the match diverges: one seed read 0-80 % across arms), so 12 seeds read it +-7 points and v2's first line 5
(aims/min >= 90 % of BASE on 12 seeds) could not tell a camera from noise. **On record: the ARM as filed reads 44.0 % v BASE's
55.8 % on dev seeds 9501-9512 (-11.8 points), which FAILS this line too**: the amendment is about power, not passing. If line 5
fails on the bar, that is a real result for him (the smooth camera costs him some sight of the fight), and the clip must show it.

### K2/K3 dev reads after v1 (dev seeds 9501-9512, NEVER a bar; builder0 light lane, headless 1920x1080 60 fps, 12 seeds per row)
Rows 1-6 at 112b0a339's code, rows 7-10 at 8ffe4651a's (the same camera; dev knobs only). Hits = attack clicks on the aimed unit.
| arm | play min | held | action share | aims/min | hits | slip p95 | jerks/min | auto snaps |
|---|---|---|---|---|---|---|---|---|
| OFF (round 40) | 15.8 | 0 % | 55.8 % | 9.75 | 88/154 57.1 % | 308.3 | 16.90 | 146 |
| ON (as filed) | 20.2 | 15.4 % | 44.0 % | 7.64 | 121/154 78.6 % | 32.4 | 0.40 | 0 |
| ON, no hold (`--camera-aim-hold=off`) | 17.8 | 0 % | 41.4 % | 7.03 | 60/125 48.0 % | 134.3 | 0.22 | 0 |
| ON, cap 1.0 screens/s | 21.4 | 15.0 % | 37.0 % | 6.41 | 104/137 75.9 % | 32.9 | 0.28 | 0 |
| ON, no hand pace (1.0) | 17.5 | 15.5 % | 49.1 % | 8.69 | 108/152 71.1 % | 72.9 | 0.29 | 0 |
| ON, leash 0 | 15.8 | 15.1 % | 44.7 % | 7.77 | 101/123 82.1 % | 34.8 | 0.32 | 0 |
| ON, glide yaw 70 deg/s | 15.9 | 15.6 % | 52.5 % | 9.03 | 105/144 72.9 % | 36.5 | 0.13 | 0 |
| ON, focus omega 5 | 14.7 | 15.8 % | 45.6 % | 8.35 | 99/123 80.5 % | 31.9 | 0.20 | 0 |
| ON, leash 0 + yaw 70 + omega 5 | 17.9 | 15.2 % | 40.7 % | 7.04 | 98/126 77.8 % | 40.4 | 0.67 | 0 |
Read: the hold is what wins the clicks (78.6 % v 48.0 % without it), and the hand pace is what keeps the slip down (32 v 73 px).
No knob moves the action share beyond the noise (the per-seed SD is ~25 points; yaw 70 alone read 52.5 %, yet all three
together read 40.7 %), so no constant was tuned on it. Two dev steps before these rows (580e29909's parent): a hold on the hand's stop
alone (DWELL) read slip p95 73.5 (the camera coasted into the aim: 650 px/s x 0.2 s), and aim = "orders' getter only" read 172.

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
