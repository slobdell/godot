# Stream: camera (rounding a building's corner, the view swings to the side the wall was hiding)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 43** (C43.1, C43.2, C43.6), your round-42
> brief `streams/archive/round42/camera.md` (Status: the danger camera K4 v2, its watch items, the clip recipe, the off-screen marker
> proposal, the copy-back wipe) and the camera history in `game/camera/rts_camera.gd`'s header (his pose: pitch 21, 49 m, FOV 35: do
> NOT change the pose or the lens). **You own:** `game/camera/**`, `game/theme/fx/camera_shake.gd`, `game/ui/camera_readout.gd`,
> `tests/test_camera*.gd`, `tests/camera/**`, `mk/camera.mk`; GRANT read-only feed lines in `game/modes/skirmish_mode.gd` beside
> `rig.facing`; GRANT (C43.2) a `cam` row in `game/match/match_recorder.gd`. **Model:** Opus. **Machine:** builder0 light lane (J<=4);
> a clip needs the laptop (one Godot run under the laptop lock). **Seeds:** 10501-10536 (Bar K5, 36 an arm), 10537-10572 (one re-file).
> Dev 7001-7012, 9501-9512 (never a bar).

## The lead's direction (2026-10-27 ~20:10, verbatim)

"the camera work is definitely good, but I have a request - there are cases where a squad rounds a building's corner (if you want to
look at the recording, example case is toward the end of the game for the last kill); in other words my vehicles were driving north,
and a building was to the east of it, when they got past the building there were enemies hiding to the east. The camera was still
just angled toward the building, and ideally the camera would have recognized the blind spot and rotated clockwise such that it ended
up pointing east as well"

"North" and "east" are his screen's, not the arena's. He rejects "cheating" visuals (memory): the swing may read the walls, never an
unseen enemy.

## Where things stand (main at launch: see HANDOFF)

- `--camera-danger` ON (Bar K4 v2 PASS, R42.22): the view turns to KNOWN contacts (rear included); a retreat looks back at the fight.
  His case is the corner BEFORE contact, which K4 cannot see: no contact, so the yaw follows the heading and stares at the wall.
- **The recording holds no camera yaw**, so his moment cannot be scrubbed; it ends at 49 s with his last loss (War Rig 3 at (-56, 62),
  tick 1371) and holds no enemy deaths ("the last kill" is his memory of the screen). `_agents/streams/references/round42/playtest/`.
- Watch items from K4 v2: clicks on the aimed unit 76.1 v 83.8 %; ambush building-clearance jerks 1.88/min v 0.07; seconds the camera
  sits inside a building rose (dev ~26 s v ~5 s in 27 min). The cover map (`game/ai/cover_map.gd`) knows walls and their sides.

## Backlog (in order)

1. **K5.1 the camera in the recording (C43.2).** A `{"t":"cam", tick, yaw, pitch, dist, target:[x,z], mode}` row every CENSUS_S and at
   each automatic turn's start (mode = follow / danger / manual / aim-hold / corner); a recorder test; old recordings still read. This
   ships ON at once (it is a record, not a behaviour): name its green hash early so the orchestrator merges it alone and his next
   playtest carries the yaw.
2. **K5.2 the corner census (report first).** A "clearing a corner" workload on Locks (and terminus): a squad driving along a building's
   wall past its corner, a CPU squad parked out of sight behind it (2-3 lanes, both sides). Per frame: the bearing from the view's yaw to
   the side the wall is uncovering, the seconds from the corner opening (the first of his crews past the wall's end) to the hidden squad
   being (i) seen by his units and (ii) on screen; the share of the corner seconds facing the wall. Send the table first.
3. **K5.3 the rule, OFF behind `--camera-corner` (ON when its bar passes).** When the selection moves along a wall the cover map knows
   and nears its end, add a pull toward the side the wall hides (weighted by how close the lead crew is to clearing it, decaying once
   past), in the same weighted sum as K4 (one yaw writer); C43.6: walls and his units only, the danger turn outranks it, no turn while
   he aims, manual yaw wins, the glide's cap. Constants with reasons; a readout line. Dev reads on 7001-7012 only.
4. **K5.4 Bar K5, filed before any number on 10501-10536.** BASE `--camera-corner=off` v ARM on, one commit, `make camera-trace`, the
   corner workload + K4's ambush / retreat / attack workloads. Deciding (name before numbers, e.g.): seconds from a hidden squad being
   seen to its being on screen ARM < BASE by >= 2 se; share of corner seconds facing the wall ARM <= half BASE. Guards (filed first,
   unamended): Bar K4 v2's deciding lines held, Bar K3 v2's lines (clicks on the aimed unit, slip p95, jerks, snaps 0), yaw reversals a
   minute <= BASE + 1 on every workload, no SCRIPT ERROR.
5. **K5.5 the clip for him.** `make camera-clip` on a corner seed, LEFT off, RIGHT on; film outside `build/`; the orchestrator relays.
6. **Stretch:** the seconds inside a building (the K4 v2 watch item) on dev seeds; the off-screen hit marker stays a proposal (needs
   `game/ui/**`).

## How to verify

`tests/test_camera*.gd` for the pure math (the corner pull, its decay, the priorities); the trace; `make quick-remote`; a full check of
every hash you name. Smoke like a player: `make skirmish ARENA=locks`, drive a squad north along a warehouse with its wall on the east;
as it clears the end, does the view swing east, smoothly, without swinging back and forth?

## Don't touch

The pose / lens defaults (his), `game/control/**`, `game/ui/**` except camera_readout, `game/tactics/**` (engage), `game/ai/**` (read
only), `native/**`, `game/match/**` but the `cam` row, `tests/baselines/**`. Don't push.

## Waiting on the lead

The clip, when K5.5 has one.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-27 ~22:30 (in progress): K5.1 MERGED (main b31d3ddea); K5.2 census sent; K5.3 built OFF; Bar K5 FILED; its
series runs on builder2 after 65e6e7e92's full check there.**
- **K5.1 DONE, green, merged.** d489eaa2b (K5.1 + native's 2fd2e5d4e recorder keys + K5.2/K5.3 OFF): builder0
  `>> remote: make check exited 0`, test 3360 passed / 0 failed, 27 passed + 1 NOT JUDGED (remote-guard-test quiet window);
  merged alone by the orchestrator (main b31d3ddea, R43.10). The `cam` row: `{"t":"cam", tick, yaw, want, pitch, dist,
  target:[x,z], mode, turn?}`, the SHOWN pose (yaw in degrees, 0 = north/-Z, positive turns left: -90 looks east), `want` the
  yaw it is turning to, `mode` follow / danger / manual / aim-hold / corner, `turn: true` on a row written as an automatic turn
  starts; every CENSUS_S (1 s) and at each turn start; no rig, no rows. Scrub: `python3 tests/camera/camera_recording.py <file>`.
- **K5.2 census DONE (sent to the orchestrator).** `--camera-scenario=corner` (CameraPlaytest + `CameraCorner`), dev 7001-7012,
  builder0 light, today's camera (9e14c3ade): Terminus open->seen 1.0 s, seen->on screen 0.2 s, facing the building 53 % of the
  corner seconds, toward the hidden side 79 %; Locks (left lanes) open->seen 5.2 s, seen->on screen 0.8 s, facing 57 %,
  toward 48 %. In player terms: once the enemy shows itself the camera already finds it in about a second; the fix is the
  seconds before, when it stares at the wall half the time.
- **K5.3 built, OFF** (`--camera-corner=on`). Dev, ON v OFF (f8166f5e8 / b931bbf52's OFF, builder0 light, 7001-7012): toward the
  hidden side Locks 6.4 -> 34.9 %, Terminus 78.7 -> 81.6; seen->on screen Locks 6.8 -> 0.2 s, Terminus 0.2 -> 0.4; EMPTY corner
  facing after the opening Locks 0.0 -> 7.3 %, Terminus 22.2 -> 13.3; EMPTY Terminus reversals 2.67 -> 3.89 /min (over G1's
  BASE + 1 on dev: a swing out and back is one reversal a corner). No-fog-cheat yaw equality: 24/24 dev seeds (6847581f7).
- **Bar K5 FILED** (below, eb6deaf78; one workload fix before any number, 65e6e7e92: lanes from his half only). Judge:
  `python3 tests/camera/bar_k5.py ~/camera-bar-k5/<hash>`. Driver `~/camera-r43/bar_k5.sh` (not in the repo: it holds paths).

**Decisions (one line each):** the recorder reads `controls.rig` (no skirmish_mode edit; the camera stays unaware of the
recorder); the corner pull aims at a spot 8 m round the far end behind the wall (straight at the hidden face put the view
through the wall); facing the building is judged after the opening on the EMPTY corner (with a squad there the danger
turn rightly looks at it against the corner); lanes keep 4 m from water (Locks' canal) and come from his half.
**Watch items:** `camera-trace` runs now carry a per-run timeout (a parse error had hung the light lane 90 minutes);
the corner workload's staging jump is skipped by the trace (it read as 12 snaps).
**Questions for the lead:** none blocking.

**Plan (in order; reasons in one line):**
1. K5.1 the `cam` row (C43.2): first, so his next playtest records the yaw (the orchestrator merges it alone).
2. K5.2 the corner workload: `--camera-scenario=corner` (CameraPlaytest) + `CameraCorner` census; the lane is found from
   the cover map (`CameraCorner.lanes`: a wall >= 12 m, a lane 9 m off its long face, a hiding spot behind its far end that
   the lane cannot see until the corner), so it runs on any arena (Locks and Terminus); side = seed % 2 (right/left), one of
   the 3 nearest lanes by seed. His crews (group 1) are set down in a column at the lane's start; one CPU squad holds at the
   spot. Table first (to the orchestrator).
3. K5.3 the rule: a fourth pull in `danger_look`'s sum (CORNER_W 3.0 x a ramp from 14 m short of the far end, full to 8 m
   past, out by 30 m) toward the blind spot behind the far end (`CameraCorner.pull`: the cover map and his units only);
   a gun firing at him drops it; `--camera-corner=on`, OFF until Bar K5. Reason for "toward the spot" rather than "the
   face's normal": just past the corner the hidden squad lies ESE of the lead crew (behind the wall), not E.
4. K5.4 Bar K5 filed before any 10501+ number; 5. K5.5 the clip; 6. stretch.

### Bar K5 (FILED before any number on 10501-10536, 2026-10-27; R-lines from the orchestrator folded in; guards never amended after their numbers)
**Arms:** BASE `--camera-corner=off` (round 42's danger camera) v ARM `--camera-corner=on`, BOTH on one commit: f8166f5e8's
rule plus one workload fix made before any bar number (the corner lanes are drawn from his half only: Locks' far-bank lane
opened 0 of 6 dev runs; named with the result; its full check greens first, C31.1), `make camera-trace`, headless 1920x1080 @60,
CPU enemy, seeds 10501-10536 (36 an arm a workload). **Machine: builder2** (builder0 reads load ~15; CAMERA_JOBS=8; camera
traces are frame-paced, so the box's speed moves no number); a re-queue on preemption reruns the whole workload.
**Workloads:** CORNER = `--camera-scenario=corner`, 45 s, on Locks and on Terminus (side = seed % 2, falling back to the
side the arena has; the lane by seed among the 3 nearest); EMPTY = the same with `--camera-corner-hidden=off` (nobody
behind the wall); and K4's AMBUSH (`--camera-scenario=ambush --camera-ambush-m=55`, 45 s), RETREAT (45 s), ATTACK (150 s)
on Terminus, as Bar K4 v2 ran them. Read off `tests/camera/camera_report.py` (+ `corner_nocheat.py`).
**Deciding (ship ON = every line passes):**
- D1 toward the hidden side (his "rotated clockwise ... pointing east as well"): the share of the corner seconds the view
  looks within 45 deg of the side the wall is uncovering, CORNER pooled over both arenas: ARM >= BASE + 10 points, and ARM
  > BASE on each arena.
- D2 facing the building once past it (his "still just angled toward the building"): the share of the seconds after the
  corner opens that the view faces the building, EMPTY pooled over both arenas (the swing alone; with the squad there the
  danger turn rightly looks at it against the corner): ARM <= 0.75 x BASE.
- D3 on screen when it shows itself: seen -> on screen, CORNER pooled, never = 20 s: ARM mean <= BASE mean (no worse;
  dev: today's camera already ~0.2-1 s on Terminus).
**Guards (what the swing could break):**
- G0 NO FOG CHEAT (C43.6, the orchestrator's): CORNER (ARM) v EMPTY (ARM), same seeds and lanes: the per-frame shown and
  wanted yaw identical to the last digit up to the first frame either run knows any enemy (`corner_nocheat.py`, every
  seed of both arenas). Pinned also by `test_no_fog_cheat_an_unseen_enemy_changes_no_yaw`.
- G1 the empty corner is not seasick (EMPTY, each arena): yaw reversals/min ARM <= BASE + 1; seconds looking more than
  135 deg off the travel ARM <= BASE + 3 points; jerks <= 3.0/min all and the corner source <= 1.5/min; snaps 0.
- G2 Bar K4 v2's deciding lines held (AMBUSH + RETREAT, ARM v BASE): pooled latency ARM <= BASE + 2 se; rear lane and
  retreat latency ARM <= BASE + 2 se each; facing the wall pooled ARM <= BASE + 5 points.
- G3 Bar K3 v2's lines at their levels, ARM, ATTACK: clicks still on the aimed unit >= 70 %; slip p95 <= 40 px; jerks <=
  3.0/min all, no automatic source (corner included) > 1.5/min; automatic snaps 0 on every workload.
- G4 no swinging: yaw reversals/min ARM <= BASE + 1 on CORNER (each arena), AMBUSH, RETREAT, ATTACK.
- G5 his own squad on screen: own on screen % ARM >= BASE - 5 points on every workload.
- G6 every run CAMERA_TRACE_DONE ok=true, no SCRIPT ERROR; every corner/empty run staged ok; the corner opened in >= 80 %
  of each arm's corner and empty runs.
**Lines most at risk (dev, f8166f5e8 / b931bbf52's BASE, 7001-7012, builder0 light, NEVER a bar):** D1 Locks 6.4 -> 34.9,
Terminus 78.7 -> 81.6 (pooled ~45 -> ~62); D2 EMPTY Locks 0.0 -> 7.3 %, Terminus 22.2 -> 13.3 % (pooled at the line's edge);
G1 Terminus EMPTY reversals 2.67 -> 3.89 /min (BASE + 1.22: over the line on dev); D3 Locks 6.8 -> 0.2 s, Terminus 0.2 -> 0.4.
