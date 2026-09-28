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

**A0. FIRST: two War Rigs' art vanished while he drove them; only the selection ring was left (2026-09-27 evening).**
His words, verbatim, in `game_design.md` *Round 14 direction, second item* and *The lead's correction*: *"the trucks
just became completely invisible when I was moving them around. Their graphic was gone and instead it was just a blue
circle"*. The match is on disk: the Locks, seed 76424, `build/recordings/2026-09-27T23-20-40-locks.jsonl` (census every
second, every order with its tick and target). The two rigs are `Green_Guns_7` and `Green_Guns_9`; he was driving them
with single-unit move orders between ticks 2176 and 2858 (Guns_9 five times across the canal — (−41.9, 15.3), (−25.2,
13.6), (1.4, 15.9), (3.8, −2.6), then (87.9, 9.5); Guns_7 once to (−94.0, 3.2)); Guns_9 logged `blocked terrain` at
tick 2700 near the lock (0, 0). The orchestrator's first guess (parked under a bridge roof) is DEAD by his correction:
the ring was drawn, the art was not, in motion. **Reproduce before you explain:** rebuild the Locks at that seed with a
War Rig squad and replay the recorded orders at their ticks (a headless script that reads the recording's `order`
rows is enough; `detcore/command_replay.gd` may already do it), the camera at his pose following the rig, and per tick
log for each rig: the node's `visible`, every `MeshInstance3D` under it (`is_visible_in_tree`, its `global_transform`
and `get_aabb()` against the camera frustum: **a hull whose AABB is wrong or whose transform is NaN is culled while its
ring, a different node, is not**), whether `BlockCutaway` or the airship's occlusion touched any of its mesh instances,
the tractor/trailer split at that tick (the rig articulates: does the trailer's mesh follow the hitch? is the "own hull
art" swap in `Tank._apply_hull_size(own_hull_art)` re-applied mid-match?), and the hull's yaw/bend. Frames from his pose
at ticks 2200–3300 every 2 s. Candidates to KILL by that log, not to assume (lesson 219): frustum culling on a bad AABB
or a NaN transform after a jackknife; the cutaway hiding a MeshInstance it mistook for a building; the theme swapping
or freeing the hull art on some event (a hit? the `dead` of a neighbour? a rebuild of the dressing mid-match); a LOD or
visibility range; fog-of-war's shown/hidden state applied to a friendly. If the replay does not reproduce it, say so
with the log and widen: every map, a rig squad driven hard (k-turns, back-and-fill, the lock) for 240 s at his pose,
logging the same. **Carve-out for A0 only:** the fix lands where the mechanism is — the rig's theme files
(`game/theme/`), `Tank` (`game/tank/tank.gd`, additive), the cutaway (`game/camera/`) — listed in merge notes, the
orchestrator reviews — with a regression test that fails without it and frames before/after. Report in Status with the
mechanism named and message the orchestrator when it is known; the lead is playing tonight and wants this one.

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

_(the worker keeps this current; newest first within each section)_

**Baseline:** `b5c11813` (branch start) builder0 `>> remote: make check exited 0`, 1790 passed / 0 failed, 18 targets,
sim-baseline `6313a38d7ecd99bb` unmoved.

### Plan (in order)
1. **A0** — replay his Locks match (`make rig-vanish REPLAY=…`), measure, name the mechanism, fix with a regression test.
2. **A1** — `make airship-view`: the live camera in a real skirmish, per map and arm; design seed 7 named before any
   variant; acceptance on fresh seeds 11 and 12 (lesson 224).
3. **A2** — the view term in the orbit chooser (`AirshipFlight`), behind `--airship-off=viewavoid`.
4. **A3** — both arms, same seeds; the clip. **A4** — drift rate against the 8.5°/s stately bound.

### Merge notes (shared files, all additive)
- A0 (`62658311`): `game/tactics/army_layout.gd` (`_clear_spot` → `_clear_of_obstacles`, the `ARMY_LAYOUT_UNCHECKED`
  print), `game/tactics/slot_ground.gd` (`unchecked` counter), `game/tank/tank.gd` (`OFF_FLOOR_M`, `off_floor`,
  `_note_off_floor`, one call after `move_and_slide`), new `tests/test_deploy_faction_armies.gd`, new `make rig-vanish`
  (`mk/fx.mk`, `game/theme/fx/bench/rig_vanish.gd`). Carve-out granted by the orchestrator for army_layout.gd.

### A1–A3 pre-registration (written 2026-09-28 before the first live-camera run; not to be edited after it)
- **Instrument:** `make airship-view` — the real skirmish (`main.tscn`), the live RtsCamera driven like he plays (the next
  group attack-moved at the nearest enemy every 12 s; the vision camera frames it), 240 s, per sim tick the drawn hull
  box against the live camera. **"Hides the fight"** = the hull box cuts any of the sight lines from the camera to a
  3×3 grid over the ground it is aimed at (±15 m, vehicle height) — `AirshipSight.hidden`, the same function the pilot
  avoids. Two earlier definitions were measured and rejected before any arm was compared (a hull 20 m *beyond* the fight
  counted as "in front" by camera depth; a tail clipping the frame's side edge on a flank counted too).
- **Maps:** Terminus, yard, Crossing. **Design seed:** 7 (all tuning on it). **Acceptance seeds:** 11 and 12, never
  looked at before the acceptance run.
- **"Fixed" means, per map where the OFF arm hides the fight ≥ 2 % of ticks:** (a) ON hides-the-fight share ≤ 0.4 × OFF
  (it falls by most of itself); (b) ON's longest intrusion ≤ 3 s; (c) still SEEN: ON's in-frame share ≥ 0.5 × OFF's.
  All three on both acceptance seeds. A map where OFF is under 2 % reports its numbers and is not scored.
- **AMENDED 2026-09-28 ~02:00, before any acceptance seed was run** (the reason, measured on seed 7, builder0: an
  intrusion is rare and lumpy — 1–3 per 240 s run, each hiding 55–100 % of the fight — and two runs of the same seed
  differed, Terminus OFF 4.7 % then 3.2 %, so one or two seeds cannot separate the arms): **design seeds 1–4 and 7;
  acceptance POOLED over eight fresh seeds, 11–18, per map; maps Terminus, yard, pit and the Locks** (Crossing is
  reported, not scored: OFF never hid the fight there on seed 7). Criteria (a)–(c) unchanged, applied to the pooled
  shares and the longest intrusion over all eight seeds; the per-seed paired count is reported beside them.
- **AMENDED again 2026-09-28 ~03:40, before any acceptance seed was run:** criterion (c) counts every tick in frame,
  and on the design seeds more than half of round 13's in-frame time on the yard WAS the intrusions (6.5 of 11.1 %) —
  "seen" that is the complaint. Added **(c′) seen without hiding the fight** (in frame and not hiding it) ≥ 0.5 × OFF's.
  Both (c) and (c′) are reported; (c′) is the one scored, because it is what he asked for: visible, not in the way.
- **A4 bound:** mean |yaw rate| ON ≤ 8.5°/s (today's stately figure).
- **Cost:** the view term's CPU per tick reported both arms (laptop working tree: yard 0.19 → 0.84 ms, Terminus
  0.11 → 0.83 ms, pit 0.42 → 1.28 ms a tick for `AirshipFlight.step` in isolation; builder0 to follow).

### A1: the disruption as he sees it — MEASURED (instrument built; uncommitted until A2's check)
- `make airship-view` (headless, builder0; `game/theme/arena_kit/airship/airship_view.gd`, `airship_sight.gd`,
  `tools/airship_view_pool.py`). His complaint is real in the live game and it is **rare and total**: round 13's
  flight (OFF) hides the fight **1.5 % of the time on the Terminus and 5.5 % on the yard** (seeds 1–4, 7, 240 s each,
  builder0), in 5 and 11 intrusions, longest 9.2 s and 15.6 s, and while it intrudes it hides **74–86 % of the fight**
  (the projected box spans ~75–90 % of the screen). The Crossing: 0.0 % (it is in frame only 2.5 %).
- **Who moves:** of the seed-1–7 intrusions judged over 3 s, the camera travelling to the hull 4, the hull flying into
  the view 5, both at once 7 — the camera moves 17–30 m in the 3 s before one. A hull that takes ~5 s to answer its
  rudder cannot dodge a camera that jumps to another squad; it has to keep out of where the camera is LIKELY to go.
- Instrument lessons, kept: (1) a display run at builder0's iGPU renders ~6 fps — 240 s of match took > 20 min and
  timed out; the measure needs no pixels, so it is headless. (2) A match that ENDS stops ticking and the first loop
  waited forever: runs use `--tune=match.no_damage=1 --no-control` (they manoeuvre and fire, nothing dies) and the
  loop now stops and says so. (3) Headless there is no FxWorld, so the airship never moved (yaw 0.0°/s) until the
  instrument handed it the match (`SyndicateAdAirship.follow_match`).

### A2: the view term — IN PROGRESS (design iterations, all builder0, design seeds only)
- Mechanism: the orbit chooser (`AirshipFlight.choose_orbit`, every 6 ticks) prices candidate circles by flying a
  GHOST of the pilot 10 s ahead toward each (real rudder, real inertia) and counting poses that hide the fight from
  the live camera (1.0) or from any squad's likely view (0.5), × `VIEW_COST` 24 against the existing climb price.
  PID gains, carrot, containment and climb-over untouched. Switch: `--airship-off=viewavoid`. Cost with the early-out
  in `AirshipSight.hidden`: +0.2–0.3 ms a tick for `AirshipFlight.step` in isolation (laptop).
- v0 (samples on the ideal circle, fixed camera): failed — a heavy hull switching circles cuts 10–20 m inside the new
  one and swept through the lens while the samples said "behind the camera". → the ghost.
- v1 (centres toward the live camera; fixed-camera test: yard 11 % → 0–2 %): **live, worse on the yard**, 5.5 → 9.6 %
  (4 of 5 seeds worse), Terminus 1.5 → 1.0 %: a circle toward the camera is a circle over his own squads, and the
  camera travels to them. → squad views priced, and circles pushed away from his army offered too (v2, running).

### A0: the invisible War Rigs — DONE. Green, merge here: `62658311`
(builder0 `>> remote: make check exited 0`, 1792 passed / 0 failed, 18 targets, sim-baseline `6313a38d7ecd99bb` unmoved;
the orchestrator told 2026-09-28 ~01:00.) builder0, live skirmish with his flags, 10 ticks in: **before 4 hulls under the
floor (Guns_9 y −5.79, three Hunters −1.29), after 0 of 41**; frames `references/round14/airship/a0_deploy_*`.
The Gangs army still overflows the 32 m zone forward (front rank z ≈ 75, zone edge 86), now on open ground.
- **What he saw:** *"the trucks just became completely invisible when I was moving them around. Their graphic was gone
  and instead it was just a blue circle"* (Locks, seed 76424, Gangs v Condemned; his log confirms the launch flags).
- **The mechanism, measured:** his two rigs were **deployed inside the city block at (−30, 42)** (40×24×40 m, x −50…−10,
  z 22…62). His recording's tick 0: `Green_Guns_7` (−39.5, 57) and `Green_Guns_9` (−35, 57) — exactly his two — plus
  several Hunters, inside the building. The replay (`make rig-vanish REPLAY=…`, builder0, working tree on `a3aee344`)
  caught the next step: on tick 2 `move_and_slide`'s depenetration separated the buried 14 m hull along its shortest
  way out, **down, 6.24 m under the floor** (Guns_9 y = −6.241 from tick 3 to the end; every other rig y ≤ 0.002).
  Hulls float (`MOTION_MODE_FLOATING`, `velocity.y = 0`) and nothing holds their height, so it drove the whole match
  under the ground: art hidden under the opaque floor and water, ring drawn on top. He noticed when he moved them.
- **Why the deploy put them there:** `ArmyLayout.deploy` promises every slot on standable ground via
  `SlotGround.standable`, which is a navmesh query on the hull's CENTRE only and **returns the point unchanged when the
  navigation map is not baked** — which is when a skirmish deploys. 13 × 14 m rigs overflow the Locks' 32 m-deep zone
  forward into the block. The same measurement found the class wider: on the Locks' chamfered corners three hulls were
  deployed astride the 3 m perimeter wall and physics set them ON it (y = 3.0), and two rigs through the ad screen.
- **The fix** (carve-out granted by the orchestrator, additive): `ArmyLayout._clear_spot` takes a spot only if the whole
  hull clears every layout obstacle and stays inside the arena's shape, off water and pits (`_clear_of_obstacles`: the
  layout's own geometry, no navmesh needed). `SlotGround.standable` counts its unchecked calls (`unchecked`) and the
  deploy prints `ARMY_LAYOUT_UNCHECKED`. `Tank` prints `TANK_OFF_FLOOR` once per hull that leaves the floor by > 0.5 m
  (a log, not a silent correction: the orchestrator's ruling).
- **Regression test:** `tests/test_deploy_faction_armies.gd` — his army on the Locks, deployed before and after the bake:
  no hull inside a collider and every hull on the floor after 10 ticks (FAILS without the fix: 2 inside, 3 off the
  floor at y 1.4–3.0); and every faction × Locks, Terminus, Crossing, yard: 16 of 16 clean (laptop).
- **Killed by reading:** fog of war (enemies only), the cutaway (≥ 6 m solids), a bridge roof (none), LOD/visibility
  ranges (none), the water shader (opaque, no depth writes).
- Instrument: `game/theme/fx/bench/rig_vanish.gd`, `make rig-vanish` (placed, `DRIVE=1`, or `REPLAY=`).

