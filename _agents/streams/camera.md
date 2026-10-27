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

**2026-10-27: K4.1 DONE; K4.2 DONE OFF at 0e4d4f732, GREEN builder0 (`make check exited 0`, 26 passed, 2 NOT JUDGED:
perf-judge refused on a busy box, scenario_perf unpinned); Bar K4 FILED (R42.5 + G5 amendment recorded on main); **Bar K4 READ: FAIL**
(D2 rear lane, G1 snaps; table below): the danger camera stays OFF by default. Next: fix the solid snap and the rear lane on dev
seeds only, then a fresh series (proposed 9801-9836, Bar K4 text unchanged) on the fixed commit, asked of the orchestrator. K4.4 clips
filmed (dev seed, laptop): `~/camera-clips-round42/retreat_7005.mp4`, `ambush_rear_7001.mp4` (to re-film on the bar commit).**
Start: 18982e8df (= 21b20bdce's code, GREEN builder0 per HANDOFF; no baseline check).

### For him (K4.4; the orchestrator relays, in player terms)
**The clips** (laptop flightdeck, filmed at 0ba17b80a = 0e4d4f732's camera, LEFT round 41 / RIGHT danger camera, a dev seed, not
a bar): `~/camera-clips-round42/retreat_7005.mp4` (his case: scouts take fire, then drive back to his own edge: left stares at the
crowd, right keeps his IFV at the wall with the fight beyond it; still `evidence/retreat_7005_t30_0ba17b80a_FINAL.jpg`) and
`~/camera-clips-round42/ambush_rear_7007.mp4` (a squad driving north is shot at from behind). The white cross is the autoplay's
cursor. The matches diverge after the first seconds (one seed in a window is not deterministic): the bar is the evidence, the clip is
for feel.
**His smoke:** `make skirmish ARENA=terminus SKIRMISH_FLAGS="--camera-danger=on"` v plain `make skirmish ARENA=terminus` (round 41
until the bar ships it ON): drive a squad north and get shot at from a side street or from behind; send scouts at a fight and then
back to your own edge. Watch for: does the view turn to whoever is shooting at the selected squad, does a retreat look back at the
fight, does it ever swing back and forth, does your own squad stay on screen. `--camera-readout=on` adds a DANGER line (the three
pulls and where it looks).
**Merge notes:** shared edit = 3 lines in `game/modes/skirmish_mode.gd` beside `rig.facing` (C42.3: `rig.danger =
DangerFeed...reader()`), plus `game/ui/camera_readout.gd` (owned). New: `game/camera/danger_feed.gd`, `camera_look.gd` (+ .uid),
`tests/test_camera_look.gd`, `tests/test_camera_danger.gd` (+ .uid). Dev-only flags: `--camera-scenario=ambush|retreat`,
`--camera-lane=`, `--camera-ambush-m=`, `--camera-danger-lean=`, `--camera-solid-in=`.

### Bar K4 (FILED before any number on 9701-9736; R42.5 folded in; guards never amended after their numbers)
**Arms:** BASE `--camera-danger=off` (round 41) v ARM `--camera-danger=on`, BOTH on one commit (named with the result; the constants
as committed), builder0 light lane, `make camera-trace` J=4, headless 1920x1080 @60, Terminus, CPU enemy, seeds 9701-9736 (36 an arm).
**Workloads (each run on all 36 seeds, both arms):** AMBUSH = `CAMERA_SECONDS=45 CAMERA_FLAGS="--camera-scenario=ambush
--camera-ambush-m=55"` (lane = seed % 3: 12 right, 12 left, 12 rear); RETREAT = `CAMERA_SECONDS=45 CAMERA_FLAGS="--camera-scenario=retreat"`;
ATTACK (guards only) = round 41's autoplay, `CAMERA_SECONDS=150`. Read off `camera_report.py`.
**Latency** = an off-screen shot's seconds until that shooter is first on screen; never = 20 s (R42.5); mean +- se over episodes;
a set with no off-screen shot at all reads 0 (the best result: the camera faced the gun before it fired).
**Deciding (ship ON = every line passes):**
- D1 latency, AMBUSH + RETREAT pooled: ARM mean < BASE mean by >= 2 se of the difference (sqrt(se_A^2 + se_B^2)).
- D2 read separately (R42.5: a pass carried by the flank lanes is not his fix): on the AMBUSH REAR lane alone AND on RETREAT alone,
  ARM latency mean < BASE's AND ARM blind % of play <= BASE's.
- D3 facing the wall: AMBUSH + RETREAT pooled ARM <= half BASE's; RETREAT alone ARM <= half BASE's.
**Guards (what the rule could break):**
- G1 Bar K3 v2 lines 1-3 at their levels, ARM, ATTACK workload: attack clicks still on the aimed unit >= 70 %; slip p95 <= 40 px;
  jerk events <= 3.0/min all, no automatic source (danger included) > 1.5/min; automatic snaps 0 (snaps 0 on every workload).
- G2 held for his aim <= 25 % of play (ATTACK).
- G3 action share ARM >= BASE - 10 points (ATTACK).
- G4 no swinging: yaw reversals/min ARM <= BASE + 1, on each workload (ATTACK, AMBUSH pooled, RETREAT).
- G5 his own squad stays on screen (the orchestrator's ask: a turn toward a threat while he drives away could lose his squad): own
  on screen % ARM >= BASE - 5 points, on each workload. **Amended before any 9701+ number (4fd517b83):** a unit behind an uncut
  perimeter wall is not on screen (`CameraLook.wall_hides`): projection alone scored the first retreat clip 99.7 % while the wall
  hid his scout.
- G6 every run CAMERA_TRACE_DONE ok=true, no SCRIPT ERROR, every scenario run staged ok, both arms.

### Bar K4 result (9701-9736; camera 0e4d4f732, tip 204a28707 docs-only; GREEN builder0 `make check exited 0`, 26 passed, 2 NOT JUDGED perf; builder0 light J4; 36 runs an arm a workload; out `~/camera-bar-k4/204a28707/`)
| line | BASE (off) | ARM (on) | verdict |
|---|---|---|---|
| D1 latency, ambush+retreat pooled (never = 20 s) | 12.29 +- 0.80 (125 episodes) | 5.63 +- 0.97 (60) | PASS (5.3 se) |
| D2 rear lane latency / blind % of play | 6.5 +- 1.9 (3 never) / 0.8 | 6.6 +- 1.4 (7 never) / 3.2 | **FAIL** |
| D2 retreat latency / blind % | 16.2 +- 0.8 (62 never) / 9.5 | 8.0 +- 2.7 (3 never) / 0.7 | PASS |
| D3 facing wall pooled / retreat | 26.7 / 37.8 % | 7.0 / 0.0 % | PASS |
| G1 attack: on the unit / slip p95 / jerks / top automatic source / snaps | 79.7 % / 34.7 / 0.33 / 0.27 / 0 | 82.7 % / 31.5 / 1.50 / solid 1.500 / **2** (+1 ambush) | **FAIL** (snaps: att 9721, 9731; amb 9732) |
| G2 held (attack) | 15.2 % | 16.0 % | PASS |
| G3 action share (attack) | 42.9 % | 47.5 % | PASS |
| G4 reversals/min attack / ambush / retreat | 10.64 / 5.32 / 1.48 | 4.95 / 2.58 / 1.55 | PASS |
| G5 own on screen attack / ambush / retreat | 97.0 / 99.5 / 97.6 | 96.3 / 96.4 / 94.6 | PASS |
| G6 | 216 runs ok, 0 SCRIPT ERROR, 72/72 staged | | PASS |
Causes: (1) rear: BASE's rear lane on these seeds was already short (6.5 s v 13.5 on dev); ARM fights more (33 off-screen
episodes v 17) and its nevers are mostly a second shooter at a new bearing while the view holds on the first. (2) the solid
(building clearance) source snaps when the danger view faces new ways among buildings (ambush solid jerks 2.31/min ARM v 0.18).

### K4.2 dev reads, as committed (0e4d4f732's camera; dev seeds 7001-7012, NEVER a bar; builder0 light; headless 1920x1080 @60; Terminus; 12 runs a row; 45 s, attack 150 s)
| workload | arm | blind % of play | facing wall % | own on screen % | off-screen shots (never) | latency mean, never=20 s | reversals/min | jerks/min (solid) |
|---|---|---|---|---|---|---|---|---|
| ambush 55 m | OFF | 2.8 | 16.0 | 97.1 | 7 (3) | 9.3 +- 3.8 | 5.18 | 0.22 |
| ambush 55 m | ON | 2.0 | 10.6 | 97.8 | 22 (1) | 2.5 +- 0.9 | 2.09 | 1.83 (1.72) |
| ambush rear | OFF / ON | 6.5 / 3.8 | 5.3 / 11.5 | 94.8 / 95.7 | 3 (2) / 18 (1) | 13.5 +- 6.5 / 2.9 +- 1.1 | 8.91 / 3.68 | |
| retreat | OFF | 8.2 | 37.3 | 94.7 | 29 (17) | 16.3 +- 1.3 | 2.16 | 0 |
| retreat | ON | 0.9 | 0.6 | 95.9 | 1 (0) | 8.6 | 1.36 | 0.22 |
| attack | OFF | 2.2 | 42.4 | 97.3 | 15 (3) | 8.5 +- 2.2 | 11.69 | 0.21 |
| attack | ON | 1.5 | 18.4 | 96.5 | 28 (6) | 5.8 +- 1.5 | 5.48 | 1.20 (1.20) |
Attack guards OFF v ON: clicks on the aimed unit 122/148 82.4 % v 113/147 76.9 %; slip p95 34.6 v 29.6 px; snaps 0 v 0; held 15.1 v
16.2 %; action share 35.9 v 50.2 %. ON has MORE off-screen shots in the ambush (22 v 7): more fights are found and fought (action
share up, the shooters come on screen in ~1-3 s instead of never). The "solid" jerks (building clearance, gentle: dv p50 ~380 px/s)
rose because the danger camera sits at his 49 m pose facing new ways among the buildings: 1.20/min on ATTACK v G1's 1.5 line.
A softer ease-in (`--camera-solid-in=10`) removed them but doubled the seconds the camera sat inside a building (6.6 -> 12.2 s
in 16 min), so SOLID_IN_OMEGA stays 22 (round 41's).
**Three fixes in dev, each from a picture or a number (decisions):**
1. `DangerFeed.reader()`: a Callable on an unheld RefCounted is freed at once (the first ON read matched OFF to the digit).
2. At his edge the frame's mirrors and destination lean lay behind the view and outside the wall, so the cutaway found no wall and
   the wall hid his scout (the first retreat clip, 76cb5053b; frames in `~/camera-clips-round42/evidence/`). Then mirrors kept
   inside the wall left a frame the zoom cap could not fit (his units slid under the HUD, own on screen 55 %).
3. So the danger camera frames HIS units only, centred, no lean (`DANGER_LEAN_M` 0): the yaw facing the danger already shows it.
   Own on screen by lean: 60 m 86 %, 30 m 69 %, 0 m 96 % (retreat). The focus is kept 4 m inside the wall.

### K4.1 census: where the round-41 camera looks (camera code = 4cfadc6ee with `--camera-danger` off = round 41; builder0 light lane; headless 1920x1080 @60; Terminus; CPU enemy; dev seeds 7001-7012, NEVER a bar; 45 s a run)
Workloads (CameraPlaytest `--camera-scenario=`): **ambush** = group 1 ordered 110 m north; 5 s in, up to 3 units of one CPU squad
are set down 40 m (or 55 m) off its right / left / rear (seed % 3; 4 seeds a lane), facing it, told to hold (they fire from there);
the autoplay then attacks enemies it can see on screen (round 41's hand), else waits. **retreat** = his scout group drives north at
a CPU squad held 70 m ahead, takes fire (<= 15 s), fights 4 s, then is ordered to his own (south) edge.
"Under fire" = a known enemy's round passed within 6 m of a commanded unit in the last 3 s. "Blind" = under fire and no known enemy
on screen (clickable: 60 px margin, above the HUD). "Facing the wall" = the arena's middle > 90 deg off the view, units >= 30 m from
it. An off-screen shot = an episode; latency = until that shooter is first on screen ("never" = not by the run's end).

| workload | runs | play s | under fire % | blind % of play (of fire) | facing wall % | off-screen shots | never | latency p50 / p90 s | yaw reversals/min |
|---|---|---|---|---|---|---|---|---|---|
| ambush 40 m, right | 4 | 178 | 36.3 | 0.5 (1.4) | 4.9 | 2 | 0 | 0.7 / 3.4 | 4.71 |
| ambush 40 m, left | 4 | 182 | 28.5 | 0.7 (2.3) | 36.5 | 1 | 0 | 1.6 / 1.6 | 4.61 |
| ambush 40 m, **rear** | 4 | 185 | 49.0 | **9.8 (19.9)** | 11.5 | 9 | **5** | **never / never** | 7.12 |
| ambush 40 m, all | 12 | 546 | 38.0 | 3.7 (9.7) | 17.7 | 12 | 5 | 3.4 / never | 5.49 |
| ambush 55 m, all | 12 | 544 | 37.8 | 2.8 (7.3) | 16.0 | 7 | 3 | 3.5 / never | 5.18 |
| ambush 55 m, rear | 4 | 182 | 51.4 | 6.5 (12.7) | 5.3 | 3 | 2 | never / never | 8.91 |
| **retreat** (his case) | 12 | 528 | 42.8 | 8.2 (19.1) | **37.3** | 29 | **17** | **never / never** | 2.16 |

Read: (1) a FLANK ambush is mostly found already: the vision frame widens to the contacts his units see, and an attack order turns
the heading (so the yaw) onto the target. (2) The **rear** is where it fails: the selection keeps its heading, the shooters stay
behind the camera (5 of 9 never on screen). (3) His **retreat** is the clearest: the view faces the wall/stands 37 % of the run
(~60 % of the time after the retreat order), and 17 of 29 off-screen shots never came on screen. (4) The round-41 yaw already
reverses ~2-9 times a minute in a fight (attack orders re-aim the heading): that is BASE for the swing guard.
Caveat: the autoplay attacks only what it sees, so it never turns the camera by hand; he would (`,` `.`). These numbers are the
camera alone.


### Plan (in order; reasons in one line)
1. `DangerFeed` (`game/camera/danger_feed.gd`): one reader of the danger, used by BOTH the census and the rule (so the bar
   measures what the rule sees). Known enemies of his team (seen now, or last seen within MEMORY_S), each with "fired at the
   selection" and "hit the selection" recency, from `Match.weapon_fired` / `projectile_impact` (read-only signal hooks; a
   shot "at" the selection = an enemy round whose line passes within IncomingFire.DANGER_RADIUS of a selected unit). The
   arena's middle = the origin (arenas are point-symmetric, `Arena` checks it). Unseen shooters do not count (no cheating view).
2. `CameraLook` (`game/camera/camera_look.gd`): the census per frame (bearings from the view's yaw to the nearest shooter, the
   enemy centroid and the middle; shooter-on-screen by projecting it; first-shot-off-screen -> on-screen events; the shares).
3. CameraPlaytest scenarios `--camera-scenario=ambush|retreat`: ambush = group 1 drives north, one CPU squad is placed on its
   flank/rear (lane = seed % 3: right, left, rear) at ~45 m and told to hold (it fires from there); retreat = his scout squad
   drives at a held enemy squad, takes fire, then is ordered back to his own edge. The autoplay's aim/attack loop is round 41's.
4. `camera_report.py` look table; census on dev seeds 7001-7012 -> orchestrator. Then K4.2 (the rule), K4.3 (Bar K4), K4.4 clip.

