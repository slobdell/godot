> **ARCHIVED (round 43 closed 2026-10-28).** Final state of this brief; round 43's results are in `workstreams.md` *Bars (round 43)* and *Rulings (round 43)*.

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

**2026-10-28, FINAL: every backlog item DONE or stopped by ruling. K5.1 (the camera in the recording) is ON MAIN; the corner
swing (K5.3) ships OFF (Bar K5 FAILED at 08931da4e; v2 STOPPED unspent on the second dev block, R43.29/R43.30); the corner
workload, its census, the no-cheat check and Bar K5's judge go to main OFF for round 44's rebuild from his recording.
Merge candidate: f9758b051 (`main` 893f45ab9 merged in). Its full check on builder2: `>> remote: make check exited 2`, test
3383 passed / 0 failed, 25 passed + 1 FAILED + 2 NOT JUDGED (perf on builder2; scenario_perf loaded); the FAILED target,
remote-guard-test (tools/test_full_check_lock.sh "atomic claim: 19 of 20 races", a load-timed race at load ~48 on 16
cores), rerun alone at the same commit on builder2: `>> remote: make remote-guard-test exited 0`, full-check-lock 22/0.
Later commits are this Status only.**

**For him (player terms):** the camera now writes where it was looking into every match recording, once a second and every
time it starts turning by itself, so the next time a squad rounds a building and the view stays on the wall, we can see
exactly what it was doing at that second. The swing toward the hidden side that I built for his request did one thing he
would notice: on Locks, the moment his crews spotted a squad hiding behind a building it was on his screen in about half
a second instead of about four (36 matches each way). But it also turned the view toward the next building on tight
streets, swung back after every corner, and sometimes turned during fights, so it is switched off. The next try starts
from his own recorded corner. **To scrub his next corner moment:** after `make skirmish ARENA=locks`, run
`python3 tests/camera/camera_recording.py "$(cat build/recordings/latest.txt)" --from 40 --to 60` (seconds of the match;
`look` is where the view pointed, in screen terms N/E/S/W with N = up his screen at the start, `want` where it was turning,
`mode` who turned it, `TURN` the moment a turn began). `--camera-corner=on` in `SKIRMISH_FLAGS` tries the swing.

**Done (every number with commit, machine, workload, n):**
- **K5.1 DONE, merged** (d489eaa2b, GREEN builder0, `>> remote: make check exited 0`, test 3360/0, 27 passed + 1 NOT JUDGED;
  main b31d3ddea, R43.10). The `cam` row: `{"t":"cam", tick, yaw, want, pitch, dist, target:[x,z], mode, turn?}`, the SHOWN
  pose (yaw degrees, 0 = north/-Z, +left: -90 looks east), `mode` follow / danger / manual / aim-hold / corner; every 1 s and at
  each automatic turn's start; no rig, no rows. Smoke: Locks 7001 30 s, 34 rows, 3 turns; recording_arrivals.py still reads.
- **K5.2 DONE** (census sent): `--camera-scenario=corner` + `CameraCorner` (lanes from the cover map, his half only, 4 m off
  water; hidden squad behind the far end; `--camera-corner-hidden=off` = the empty corner). Today's camera, 9e14c3ade, dev
  7001-7012, builder0 light: Terminus seen->on screen 0.2 s, facing the building 53 % of the corner seconds; Locks 0.8 s, 57 %.
- **K5.3 built, OFF.** v1 (aim round the far end) and v2 (R43.27/R43.29: quiet move only, the open side's normal once the
  squad's centre is past the end where a 30 m sight line is clear, held until his next order / a 45 deg turn / a contact,
  none within 6 s of an order). `--camera-corner=on`.
- **K5.4 Bar K5: FAIL, 6 lines** (table below; 10501-10536, 08931da4e, builder2). Kept: D3 seen->on screen 3.98+-0.99 ->
  0.49+-0.10 s (pooled; Locks' gain), G0 no fog cheat 72/72 identical, no snaps. **v2 STOPPED unspent** (R43.30): on
  9501-9512 (e6c12fb8d, builder0 light, n 12) D1 pooled 56.3 v 57.6 %, D2 9.5 v 0.0 %, G4 ambush 5.68 v 3.61 /min,
  G1 Terminus > 135 deg 18.8 v 11.8 %: the 7001-7012 gains did not hold on a second block.
- **K5.5 clips** (laptop flightdeck, 08931da4e v1, dev, feel only, NOT for him as evidence): `~/camera-clips-round43/
  corner_locks_7002_08931da4e.mp4` (both takes reach the corner; ON faces the next block: the D2 cause),
  `corner_locks_7003_08931da4e.mp4` (OFF never reached the corner). No v2 clip (stopped).
- **Stretch: seconds inside a building** (K4 v2 watch item): dev flag `--camera-solid-escape=on` (OFF) lifts the clearance's
  glide cap x3 while the camera is inside a solid. e6c12fb8d, builder0 light, Terminus, 7001-7012, n 12: inside ambush 1.59
  -> 0.86 % of play, attack 1.03 -> 0.62 %; but solid jerks ambush 1.39 -> 2.25 /min (over K3's 1.5 automatic-source line),
  attack 0.70 -> 1.15; snaps 0; attack clicks on the unit 125/143 v 125/144. A proposal for a bar, not shipped.
- The off-screen hit marker stays a proposal (needs `game/ui/**`; round 42's text in `streams/archive/round42/camera.md`).

**Decisions (one line each):** the recorder reads `controls.rig` (the camera stays unaware of it); the census is the
instrument and may know the hidden squad, the rule never (C43.6, pinned by a unit test and G0); lanes from his half
and 4 m off water (Locks); the staging jump is skipped by the trace; `camera-trace` runs carry a per-run timeout (a
parse error had hung the light lane 90 min).
**Questions for the lead:** none blocking. When he next plays, a corner moment like his ("driving north, enemies hiding
east of the building") with the time in the match lets round 44 build the swing from what actually happened.
**Requests to other streams:** none. (Native's laptop kill of my check wrapper cost one full check; native was told.)
**Known issues:** Terminus' K4 war pull looks across buildings toward the arena's middle (traces 130412bdf): it is why
"facing the building" is high in both arms; a round-44 item if he notices it.
**Merge notes:** shared edits: `game/match/match_recorder.gd` (the `cam` row, C43.2, merged), `game/modes/skirmish_mode.gd`
(4 lines beside `rig.facing`: `rig.order_now`, read-only, C42.3), `game/ui/camera_readout.gd` (corner pull on the DANGER
line). New: `game/camera/camera_corner.gd`, `tests/test_camera_corner.gd`, `tests/test_camera_record.gd` (+ .uid),
`tests/camera/{camera_recording,corner_nocheat,bar_k5}.py`. All behaviour OFF by default.
**Next steps (round 44):** take his next recorded corner (cam rows) and rebuild the rule from it; the solid-escape bar.

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

### Bar K5 v2 (FILED before any number on 10537-10572, 2026-10-28; R43.27; the LAST re-file: a fail ships the corner swing OFF with the Locks result for him)
**Unchanged from Bar K5** (below) except the rule it judges and D1's per-arena clause. Arms BASE `--camera-corner=off` v ARM
`--camera-corner=on`, BOTH on one commit (the K5 v2 rule, bb4c83e56's or a later commit named with the result, whose full
check greens first); **machine builder2**, CAMERA_JOBS=8; seeds **10537-10572** (36 an arm a workload); the same seven
workloads (CORNER and EMPTY on Locks and Terminus; AMBUSH, RETREAT, ATTACK on Terminus); judge `tests/camera/bar_k5.py --v2`.
**What changed (R43.27, the three causes of Bar K5's fail):** (a) the look only under a move / attack-move order with no
known enemy (never mid-fight: G4 ambush / attack); (b) once past the far end, along the open side's outward normal, only
where a 30 m sight line that way is clear of walls, else none (D2: the next block); (c) the look held until his next
order, the squad's heading turning > 45 deg, or a contact (K4 takes over), not eased back (one reversal fewer a corner,
G1). CORNER_W 4.0 (from 3.0: past the corner the view turns ~68 deg toward the open side on a north drive).
**D1 (R43.27, ruled before any v2 number; reason: Terminus sits at an 85 % ceiling):** CORNER pooled ARM >= BASE + 10
points (unchanged), and on EACH arena ARM >= BASE - 2 se of the difference (per-run shares, mean +- se).
**Everything else as filed:** D2 (EMPTY pooled, facing the building after the opening, ARM <= 0.75 x BASE), D3, G0-G6.

### Bar K5 result: FAIL, 6 lines (10501-10536; series commit 08931da4e = 65e6e7e92's code + docs, GREEN builder2 `>> remote: make check exited 0`, test 3362/0, 26 passed + 2 NOT JUDGED (perf on builder2, scenario_perf loaded); builder2 J8; 36 runs an arm a workload; every wrapper exited 0, 36/36 CAMERA_TRACE_DONE in all 14 dirs; out `~/camera-bar-k5/08931da4e/`, table `references/round43/camera/bar_k5_verdict_08931da4e.md`)
| line | ARM (on) | BASE (off) | verdict |
|---|---|---|---|
| D1 toward the hidden side, CORNER pooled (% of corner s) | 65.6 | 56.7 | **FAIL** (+8.9 v +10) |
| D1 Locks / Terminus | 48.4 / 83.3 | 27.6 / 85.0 | PASS / **FAIL** |
| D2 facing the building after the opening, EMPTY pooled | 13.8 % | 11.4 % | **FAIL** (line 0.75 x) |
| D3 seen -> on screen, CORNER pooled (never = 20 s) | 0.49 +- 0.10 s | 3.98 +- 0.99 s | PASS |
| G0 no fog cheat, Locks / Terminus | 36/36 identical / 36/36 identical | | PASS |
| G1 EMPTY reversals/min Locks / Terminus | 5.53 / 4.38 | 5.56 / 2.76 | PASS / **FAIL** |
| G1 EMPTY > 135 deg off travel Locks / Terminus; jerks all / corner | 17.2 / 8.4 %; 1.57 / 0.00, 0.76 / 0.04 | 18.0 / 9.0 % | PASS |
| G2 latency ambush+retreat / rear / retreat; facing the wall | 4.39 +- 0.79 / 4.87 +- 1.16 / 8.58 +- 3.22; 7.8 % | 4.27 +- 0.72 / 4.28 +- 1.08 / 8.58 +- 3.22; 6.5 % | PASS |
| G3 attack on the unit / slip p95 / jerks all, top automatic / snaps | 73.7 % (306/415) / 33.6 px / 0.49, solid 0.49 / 0 everywhere | | PASS |
| G4 reversals/min corner Locks / corner Terminus / ambush / retreat / attack | 6.08 / 4.61 / 4.73 / 3.07 / 7.01 | 6.67 / 3.65 / 2.91 / 2.35 / 5.98 | PASS / PASS / **FAIL** / PASS / **FAIL** |
| G5 own on screen (every workload) | 94.2-99.0 | 94.2-98.7 | PASS |
| G6 | all done, staged, opened >= 80 % | | PASS |
**Causes (read before any v2):** (1) D1 Terminus: today's danger camera already looks to the hidden side 85 % of the corner
seconds there (the squad is seen ~1 s after the opening and K4 turns to it), so the swing has nothing to add; the gain is
Locks' (+21 points) and D3 (Locks seen -> on screen 4 s -> 0.5). (2) D2: the pull aims round the far end, and on blocks
set close together that direction lands on the NEXT building (seen in the laptop clip 7002 at t10: OFF looks over open
ground, ON at the back of the neighbouring block). (3) G1 / G4: the swing out to the side and back is one reversal per
corner by construction (Terminus empty +1.6/min), and the pull also fires near buildings in fights (ambush +1.8, attack
+1.0/min), where no corner is being cleared. **Ships OFF** (`--camera-corner` default off, as on main).
**v2 directions (for the orchestrator's ruling; one re-file left, 10537-10572):** (a) only on a quiet move (a move order,
no known enemy), so fights never see it (G4 ambush/attack); (b) aim at the open side: the hidden face's outward normal
once past the far end ("ended up pointing east"), not a spot round it, and only where the ray toward it is clear of
other walls for ~30 m (D2); (c) hold the look until his next order or a heading change instead of easing back (removes
the out-and-back reversal, G1); D1's Terminus clause would need re-thinking (it has no room there).
**Clips (laptop flightdeck, 08931da4e, dev, feel only):** `~/camera-clips-round43/corner_locks_7002_08931da4e.mp4` (both arms
reach the corner; shows cause 2), `corner_locks_7003_08931da4e.mp4` (OFF never reached the corner).

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
