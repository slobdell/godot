# P0 — The problem: a long wheeled hull in tight space

_Planner stream, round 30 (Fable 5.1). Written against main `bd05077d`, 2026-10-14. Every number below carries its
source: a line of code, an arena file, a judged table, or a run (commit, machine, n)._

## 1. The vehicle model, as the game integrates it

The plant is `TankMotion.step_in_place` (`game/tank/tank_motion.gd`), stepped once a physics tick (30 Hz,
`SimClock.TICK_RATE`) by `Tank._drive` (`game/tank/tank.gd` ~655), then `move_and_slide`. For `locomotion: wheels`:

1. **Yaw rate** `ω = clamp(|v|·turn / R, ±ω_max)` with `v` the hull speed at the START of the tick, `turn ∈ [-1, 1]`
   the lock, `R = min_turn_radius_m`, `ω_max = hull_turn_rate_deg`. The heading is turned by `ω·dt` (a small-angle step,
   renormalised). **A wheeled hull cannot yaw standing still, and the yaw per metre travelled is `turn / R` in EITHER
   gear** (`turn` is the way the hull should swing; the plant inverts the wheels in reverse for the brain). Below the
   clamp a leg is therefore an exact circle arc of radius `R / |turn|`; the clamp only bites at full lock above
   `ω_max·R` (the War Rig: 55°/s × 12 m = 11.5 m/s, so only in the last 0.5 m/s of its top speed).
2. **Speed** along the NEW heading: `along = move_toward(carried·forward, throttle·v_max, a·dt)` with `a` the
   acceleration, or the braking when shedding speed or crossing zero (`next_speed_braking`). Forward and reverse have
   separate caps (`max_forward_speed`, `max_reverse_speed`).
3. **Slip:** the carried velocity's sideways part survives the heading change and decays by `(1 − grip)^(dt·60)` a
   tick (the rig: grip 0.9 → ×0.316 per 30 Hz tick). Position += velocity·dt.
4. **The creep (X4):** when `|throttle| < 0.5·|turn|` the plant REPLACES the throttle with `0.5·|turn|` in alternating
   gears every 0.5 s (`CREEP_LEG_TICKS` 15), anchored to where it began (`creepbound`). That is the shuffle the lead
   named in round 26. Any leg a planner emits must be driven at `|throttle| ≥ 0.5·|turn|` (today's executors: the
   k-turn 0.7, the face 0.55).
5. **Then the world:** `_fitting_forward` refuses the part of a yaw that would push a hull already touching geometry
   deeper (fractions 1.0 / 0.6 / 0.3; untested for a free hull whose sweep clips something: ~0.65 m of tip per tick at
   160°/s), `move_and_slide` resolves translation only, and for wheels `_speed = estimated_velocity · forward` after the
   slide: **a wall eats a wheeled hull's momentum**. Round 29's M4 found the hole: a slide fully blocked by another
   BODY hands `velocity` back unchanged, so a pinned truck carries 12 m/s of phantom speed at zero displacement
   (`references/round29/manoeuvre/m4_judged.txt`; the fix that zeroed `_speed` on every wall brush made rigs grind,
   so C30.6 gives the real displacement only to the progress readers).

**The wheeled hulls that matter** (`game/units/units.gd`; `hull_size` is the collision box [w, h, l] in metres):

| id | name | w × l (m) | R (m) | fwd / rev (m/s) | accel / brake (m/s²) | ω_max (°/s) | grip |
|---|---|---|---|---|---|---|---|
| `gang_tank` | War Rig | 3.32 × **14.00** | **12.0** | 12 / 4 | 7 / 8 | 55 | 0.90 |
| `artillery` | Artillery (crane carrier, the mortar battery) | 2.90 × 8.20 | 9.0 | 6.5 / 3.5 | 6 / 10 | 60 | 0.85 |
| `law_tank` | Assault Gun (8×8) | 3.36 × 7.30 | 8.0 | 12 / 5 | 9 / 12 | 85 | 0.85 |
| `ifv` | IFV (crash tender) | 3.75 × 7.54 | 7.0 | 11 / 5 | 9 / 14 | 100 | 0.70 |
| `burner` | Burner (fire truck) | 2.99 × 7.54 | 7.0 | 10 / 5 | 9 / 14 | 110 | 0.65 |
| `gang_artillery` | Wrecker Catapult | 2.91 × 6.89 | 9.0 | 9 / 4 | 7 / 10 | 65 | 0.85 |
| `law_suppressor` | Sonic Emitter | 3.32 × 6.86 | 7.0 | 10 / 5 | 8 / 13 | 90 | 0.80 |
| `gang_support` | Resupply Tanker | 3.18 × 6.58 | 8.0 | 11 / 5 | 8 / 11 | 70 | 0.80 |
| `lancer` | Lancer (utility truck) | 2.76 × 6.46 | 7.5 | 8.5 / 4 | 8 / 12 | 80 | 0.75 |
| `law_artillery` | Gas Rocket Truck | 2.09 × 4.95 | 9.0 | 9 / 4 | 7 / 10 | 60 | 0.85 |
| `scout` / `gang_scout` / `law_scout` | the cars | 1.5–1.8 × 3.0–3.8 | 4.5–5.5 | 13–18 / 6–8 | 15–18 / 20–22 | 130–150 | 0.40–0.55 |

Derived numbers a planner lives by (the War Rig, the hardest case): a full-lock leg turns 4.77° per metre; a 90°
swing is 18.8 m of arc and sweeps the hull centre 12 m sideways; a half turn is 37.7 m of arc however the legs are
cut. At the k-turn's 0.7 throttle (8.4 m/s) the stopping distance is 4.4 m and the spin-up 1.2 s; at the face's 0.55
(6.6 m/s) 2.7 m; in reverse at 0.7 (2.8 m/s) 0.5 m. **A cusp (forward → reverse) costs ~1.5–2.2 s of braking and
spin-up at these throttles**, and the executor ends a leg a stopping distance early (`_kturn_stopping`), so a leg's
driven length is the plan's only if the plan knows the speed it will be driven at.

What the drive feeds the plant (`game/ai/movement.gd` `drive()`): a routed `move_to` steers at a carrot on the navmesh
route (`Steering.drive_toward_wheels`: pure pursuit, full lock beyond 45° of error, `WHEELS_MIN_THROTTLE` 0.35 in a
hard turn — under the creep line at full lock, which is where in-drive creeps come from), the circle rule backs a hull
whose point lies inside its forward turning circle (`Steering._wheels`, reactive, one tick at a time), the planned
reverse / back-and-fill / circle plan (`_planned_reverse`, `_plan_fill`, `_plan_circle`: legs `Vector2(gear, metres)`
on ONE lock, swept against the navmesh with the hull's 10-point outline, driven by `_kturn_start_leg`), the face at
rest (`face_turn` → `Manoeuvre.plan_face`: ≤ 5 legs on one lock, each ≤ π/3 of swing, the end within the settle
radius − 1 m of home), the pressed-wall escape (`_pressing_escape`: 1 s of contact with < 0.75 m of progress → back
off 1.5 m), unstick (2 s under `STUCK_SPEED` at > 0.5 throttle → reverse 1 turn), and give-way (traffic's).

**The clearance test every planned leg uses today** (`_outline_ok`): ten outline points (corners, end middles, side
quarters) each within `bake_radius − KTURN_MARGIN_M = 2.0 − 0.4 = 1.6 m` of the navmesh, or no deeper than at the
start. The mesh is baked at `agent_radius` 2.0 m from every face (`game/arena/arena.tscn`; cells 0.5 m), so the rule
is **every outline point ≥ 0.4 m from a wall** (±0.5 m of cell quantisation), with squadmates as discs of both
half-widths + 1 m (`Manoeuvre._others`).

## 2. The environments

Measured from the arena files (`arenas/*.json`; props are axis-aligned boxes from `ArenaKit.PROPS`, a `block` is
40 × 40 m, a `container_40` 12.19 × 2.44 m, a `container_20` 6.06 × 2.44 m):

- **The Terminus** (`terminus.json`, "20 m streets"): blocks at (±40, 0) and (±30, ±62) and (±100, 0). The avenue
  (x = 0) runs between block faces at x = ±20 → **20.0 m wall to wall**; the ring road (z = 30) between faces at z = 20
  and z = 42 → **22.0 m**; the west street (x = −70) between faces at x = −60 and −80 → **20.0 m**, narrowed to
  **17.6 m** beside the container at (−78.8, 8) (z 2–14). Lane widths declared 18–20. For a 14 m hull: 20 − 0.8 m of
  margins leaves 19.2 m of outline room; the hull fits across the street with 2.6 m to spare each end, so a turn-round
  is geometrically possible but every leg is short.
- **The Container Yard** (`yard.json`): container rows along z at x = ±98, ±84, ±50, ±17, 2.44 m thick, so the lanes
  are **30.6 m** (inner, declared 28) and **31.6 m** (outer) wall to wall; the rows have 14 m gaps (the "yard gate"
  chokepoints at (∓34, ±38), radius 8) and cross-pieces (a container along x at (−34, −56)): a lane end with a
  cross-piece is **the yard corner**, an L of two faces 2.44 m thick.
- **The Sumps** (`sumps.json`): causeways 14 m wide between pits (`terrain: pit`): not a wall but off-mesh ground a
  hull can drive onto and jam on (brains' B5c worst run). The catwalk lane is 14 m.
- **The navmesh margin** everywhere: 2.0 m (so a 20 m street is a 16 m strip of mesh; the hull's outline may stand
  1.6 m outside it).

## 3. The squad context

A squad is an element of 2–5 crews in a formation (`game/tactics/`): default slot spacing **12 m**
(`TacticsFormation.DEFAULT_SPACING`), floored by the members' hulls; brains' round-29 B4 gives gang trucks 6 m screen
slots side-on. Each crew gets its own `move_to` with the element's facing when one was drawn (round 9: right-drag;
round 26: every armed order). A wheeled crew with a facing is sent to an **approach gate** first: a point
`clamp(2.5·R, 4, 20)` m BACK along the facing from its slot (`_approach_gate`: the rig 20 m, an IFV 17.5 m, a scout
12.5 m), reached within 2.5 m, then the straight run onto the slot. Arrived, a crew holds its sector; a drawn facing
for a wheeled turreted hull is declined (`TankBrain._order_move`: the turret takes it) — his round-28 call 2 (turn the
whole hull) is round 29's M1, judged and not shipped. Who moves when: every crew at once, steering round squadmates by
ORCA (`_avoid`) and giving way by traffic's convention; nothing schedules the turns of neighbouring hulls.

## 4. The failure modes, as fixtures

Each fixture: a start pose (x, z, heading), a goal pose, the obstacles, what today's code does, and how it was read.
Coordinates are the arena's (x east, z south; forward is −z; a heading in degrees is measured from north, clockwise).

### F1 — The creep in a street (M2; `manoeuvre-m2-r29`)

- **Pose:** a War Rig mid-street on the Terminus west street, nose 45–70° off its route's carrot (a corner ahead or a
  squadmate beside it), speed < 3 m/s. **Goal:** the carrot 8–15 m ahead round the corner. **Obstacles:** the two
  street faces 20 m apart, often a squadmate within 8 m.
- **Today:** pure pursuit asks full lock; avoidance's pace or the hard-turn easing drops the throttle under
  `0.5·|turn|`; the plant's creep alternates 0.5 s legs about an anchor; the heading comes round 1–2° a leg. Base
  census (round 28, `c6e32d03`, builder0): 917 turn episodes, 121 creep, long ones 10–20 legs. Round 28's lift (roll
  the arc at the creep line) fixed open ground (long episodes −72 %) and rolled rigs into walls (contact-ticks 3938 →
  6494, round 29 M2 judged); round 26's hold-still rule (M3) left crews parked at the bridge mouth (bridge 9/18).
- **Reproduced on main:** `make remote LIGHT=1 T=planner-repro-creep` (the Terminus mixed drive, seed 1, `--turn-log`)
  → see §4.1 below for the run's rows.

### F2 — The wedge (M4; `manoeuvre-m4-r29`)

- **Pose:** a War Rig with its nose pressed on a squadmate or a block face, full throttle commanded. **Goal:** its
  route carrot beyond the obstacle. **Obstacles:** the body it is pressed on; the street faces.
- **Today:** `move_and_slide` returns the wanted velocity when fully blocked by a BODY, so the plant reads 12 m/s,
  `unstick` (needs `estimated_velocity < STUCK_SPEED`) never fires, the pressed-wall escape fires only on a WALL
  contact (the collider must not be a Tank); the rig presses for seconds to minutes. Round 29's fix (honest velocity
  everywhere) freed the open-ground pins (pinned crew-seconds 2902 → 1040) but zeroed `_speed` on every wall brush and
  rigs ground along walls (Terminus rigs arrived 81 → 64/96). Manoeuvre's M4b this round: real displacement to the
  progress readers only.
- **Reproduced on main:** `make remote LIGHT=1 T=planner-repro-wedge` (the Terminus rigs drive, seed 9, GDScript plant,
  `DRIVE_TRACE` on every rig) → §4.2.

### F3 — The boxed-in face (M1; `manoeuvre-m1-r29`)

- **Pose:** four 14 m hulls in a line abreast at 12 m pitch (or 6 m screen slots), all heading north, each told to
  face east. **Goal:** heading 90°, within the settle radius of its slot. **Obstacles:** the neighbours (3.3 m wide,
  14 m long, 12 m apart: a 4.7 m gap between hulls side by side... and 90° of swing per hull sweeps 7 m of nose
  across the gap). 
- **Today:** `plan_face` tries n equal legs alternating gear (n = 3 for 90°: each 30° of swing = 6.3 m of arc on
  R 12) with the whole outline clear of walls and of every squadmate disc; any leg meeting a disc refuses the even
  split, then the greedy `_face_legs`; nothing fits → the creep (counted `face_none`). In a packed line the first
  hull's leg sweeps into the second's disc, so both creep or wait: round 29 M1 judged (`m1_judged.txt`, builder0,
  seeds 22–33, 288 runs an arm): point tasks 3.2° median but 8–12 MORE crews still turning at 75 s on attack-move
  (+8 against a +5 guard), wheels/turret +12 (face legs +3, face creep +3, dressing +5, driving +4).
- **Reproduced on main:** `make remote LIGHT=1 T=planner-repro-face` (my TacticsLab probe: four War Rigs in a line at
  12 m, a `face` order east each, `--turn-trace`) → §4.3.

### F4 — The arrival gate (brains' B5c; `lab/brains-r29-gate`)

- **Pose:** a car (law_scout, R 5.5) 9 m from its slot, the slot's facing 180° from its approach. **Goal:** the slot,
  facing the way it came. **Obstacles:** the Sumps causeway edges (off-mesh terrain), a squadmate parked on the old
  slot.
- **Today:** `_approach_gate` puts a gate 12.5 m back along the facing (so 17.5 m from the car, BEHIND the goal from
  where it stands), the route goes to the gate (21.6 m round a corner), the car reaches it, turns onto the heading and
  jams on terrain ~8 s (Terminus seed 3, B_4; brains' round-29 Status). Round 29's latch (B5c-v2) won the yard
  (never-in 7/12 → 12/12) and broke the 180° arrival; C30.5 splits it: the gate's placement is brains', the terrain
  escape manoeuvre's. For the planner: **a 180° arrival onto a slot is a goal POSE 9 m away, not a gate 17.5 m away.**
- **Read from:** brains' round-29 brief (`streams/archive/round29/brains.md` lines 234–290) and C30.5. Not run here
  (brains' branch).

### F5 — The street mouth with a squadmate stopped in it (traffic's T3 crawl and the friendly creep)

- **Pose:** a hull entering a 20 m street whose mouth holds a stopped squadmate (yielding, or pressed). **Goal:** the
  carrot past it. **Obstacles:** the street faces and the parked hull (an OBB, not a disc: a 14 m rig across half a
  street leaves a 6.7 m gap).
- **Today:** ORCA slows and sidesteps (`_avoid`), the give-way crawls the whole yielding squad at 0.4 for 30–45 s
  (traffic's round-29 T3 report: 26.5 → 74.7 s and 31.0 → 78.2 s), the creep beside friends is half of all creep
  episodes (81 of 149 in round 26's census). For the planner: **the pass is a geometry problem** (is there an arc
  through the gap?) that today is answered one tick at a time by a velocity obstacle.
- **Read from:** traffic's round-29 brief (lines 210–225) and round 26's census. Traffic's T3b owns the convention; the
  planner owns the hull-as-obstacle geometry.

### F6 — The street turn-round (round 26: a planned three-point turn)

- **Pose:** a War Rig mid-street heading north; **goal:** heading south, within 3 m of its spot; the street 20 m (the
  Terminus) and 12 m (the tight variant: a yard gate, the Sumps catwalk). **Today:** no rule plans a turn-round; the
  route carrot behind the hull triggers the planned reverse once per 45°+ of error (`KTURN_MIN_ERROR_DEG`), the
  back-and-fill at most 5 legs on one lock, then the pursuit law straightens early and meets the wall again (round
  26's census: 5–9-leg "single" turns).

### F7 — The short move behind (round 26 M1, shipped) and a 180° slot in the open

- **Pose:** any wheeled hull; **goal:** 5–20 m astern, with or without a facing; open ground. **Today:**
  `Manoeuvre.choose` simulates reverse v route with the plant and picks the cheaper (shipped, `0845c3c7`); the gate
  and the circle rule take over for a slot with a facing. A planner replaces both with one answer.

## 4.1 The creep run (`make remote LIGHT=1 T=planner-repro-creep`, builder0, `bd05077d`, seed 1, n = 1)

The mixed squad (tank, ifv, scout, lancer, artillery, ifv) across the Terminus on main's code, GDScript path. All four
legs arrived but one (a scout yielding at the west street); 30 turn episodes, **16 over 3 legs**; by cause creep 7,
face 7, yield 6, circle 4, k-turn 5, unstick 1; by kind open 21, friendly 7, static 2. The creep's worst: an IFV
(7.54 m, R 7) at (−54.4, −28.5) on the far ring road, **13 legs in 6.9 s with nothing in the way** (`open`), a lancer
7 legs / 3.8 s at the plaza, the same IFV 7 legs / 3.8 s at (4.4, −21.4). Creep unit-ticks 1734 (58 s of hull time),
79 creep flips. Reading: in this squad the creep is an OPEN-ground event at a corner (the route's carrot inside the
turning circle at low speed: `KTURN_CIRCLE_SPEED` 1.5 gates the planned circle; above it the pursuit law's 0.35
throttle at full lock is under the creep line) — exactly the pose a planner answers with one forward arc or one
back-up, chosen by geometry.

## 4.2 The wedge run (`make remote LIGHT=1 T=planner-repro-wedge`, builder0, `bd05077d`, seed 9, n = 1)

Four War Rigs across the Terminus, GDScript plant, `DRIVE_TRACE` on every rig (`tests/planner/wedge_table.py` reads
it). Legs: ring road 4/4, west street 2/4, plaza 4/4, far ring road 2/4. **Pins** (≥ 1 s asking > 1 m/s and moving
< 1 cm a tick): six, 70.3 s of hull time in all; the worst is **Green_S0_2 from its tick 2841 for 1842 ticks (61.4 s)**
on the far ring road leg at (35.8, −32.9) heading east for a goal at (57.1, −32.7): `throttle 0.57, turn 0.00`, the
plant's `speed 6.87 m/s`, `moved (0.0000, 0.0000)` every tick, two slide contacts the whole time, both squadmates:
Green_S0_3 (normal (−0.81, 0.58): ahead-left) and Green_S0_4 (normal (−0.55, −0.83): ahead-right). Its phase at the
leg's end: `blocked`, `blocked_by Green_S0_4`. Neither unstick (`estimated_velocity` 6.87 > `STUCK_SPEED`) nor the
pressed-wall escape (the colliders are Tanks) can fire. The other pins (Green_S0_3, 3.4 s at 11.5 m/s wanted) are the
same mechanism against a squadmate on the first leg. Census: 26 episodes, creep 4, face 12 (the leg's arrival facing),
k-turn 7, yield 5; worst face 19 legs / 10 s against a wall at (−71.6, 13.9) (the west street beside the container).
Reading: the wedge is TWO failures: the phantom speed (manoeuvre's M4b) and, once the speed is honest, no rule that
plans a way out between two hulls — unstick reverses blind for one turn, the escape backs 1.5 m off a wall. The
planner's job is the second: from a pose touching two OBBs, a plan (reverse on the lock that swings the nose clear,
then forward) or an honest `NO_PATH` the layer above can act on (ask a squadmate to move).

## 4.3 The boxed-in face and the gate (`make remote LIGHT=1 T=planner-repro-face`, builder0, `bd05077d`, n = 1)

`tests/planner/boxed_face_probe.gd`, a TacticsLab on the foundry's open west band, today's drive, GDScript path.

**F3, four War Rigs line abreast at 12 m pitch, all heading north, each a `face` order due east at the same tick:**

| rig | within 8° at | gear changes | creep ticks | farthest from its spot | hull contact ticks |
|---|---|---|---|---|---|
| Green_A_1 (west end) | 17.8 s | **33** | 609 | 6.4 m | 79 |
| Green_A_2 | 7.9 s | 6 | 0 | 5.5 m | 8 |
| Green_A_3 | 6.9 s | 15 | 494 | 6.1 m | 0 |
| Green_A_4 (east end) | 6.9 s | 15 | 561 | 7.8 m | 0 |

`face_plans 6, face_plan_legs 14, face_none 20, face_refused 2`. Reading the per-second rows: A_3 and A_4 got the even
two-leg plan (6.28 m reverse, 6.28 m forward: each leg π/3 of swing) and then CREPT the rest (15 gear changes, ~500
creep ticks each); A_2 got a 4-leg plan and drove it; A_1, boxed by A_2's sweep, got none (`face_none`), crept 33
gear changes and touched A_2 for 79 ticks. **Every rig ended 5.5–7.8 m off its spot** (a 90° swing on R 12 moves the
centre; the creep's anchor is a different rule from the face plan's `stay`). This is M1's cost in miniature: on open
ground, four hulls, no walls, and only one of four turns cleanly.

**F4, a law_scout (R 5.5) 9 m south of its slot, ordered to it with a facing SOUTH:** the gate is placed 13.75 m
NORTH of the slot (`first_steer (−58.0, 0.0, −2.75)`, `on_approach` refusals 1094 of 1350 gate offers as the car then
circles); the car drives past the slot to the gate, is `blocked` by its own circle rule at the gate, loops twice
(farthest **25.1 m** from the slot at (−57.7, −14.1)), **102.4 m driven for a 9 m move**, and arrives on the heading
at 9.6 s, never once reversing. A planner's answer is 2–3 legs and ~15 m (the RS-type arc-reverse-arc, or a reverse
straight onto the slot if the facing says tail-first).

## 5. What a planner must guarantee

1. **No wall penetration:** every pose along every leg keeps the hull's outline ≥ 0.4 m from every wall face
   (today's `KTURN_MARGIN_M` rule, the same number so the bar is comparable), checked at ≤ 0.5 m along each leg and
   at each leg's end INCLUDING the roll past it at the executor's throttle.
2. **Squadmates are oriented boxes**, not discs: a disc of a 14 m rig is a 7 m-radius wall across a street.
3. **Bounded legs:** a plan is ≤ 6 legs for any fixture here (the lead's three-point turn: ≤ 3 in a 20 m street for a
   90° swing; a half turn in 20 m is physically 5), each leg ≥ 1 m (the executor's `KTURN_FILL_LEG_MIN_M` 0.5 is
   under a cusp's roll-out), each driven at a throttle above the creep line.
4. **Bounded work per plan, deterministic:** the search is capped by an EXPANSION count, never by the wall clock
   (`make determinism`: a decision that reads `Time.get_ticks_msec()` desyncs; orientation trip-up 28), and its order
   is fixed, so two machines plan the same legs. The ms are measured per commit and machine and reported, never read.
5. **Executable by today's drive as legs:** `(gear, steer, metres)` per leg, the plant's own arcs; one seam, re-planned
   on an EVENT (a leg done, a block, an obstacle that moved, a new goal), never per tick.
6. **A goal is a POSE** (x, z, heading) with a tolerance; a drawn facing and a 180° arrival are goal poses, not gates.
7. **Time at 25 a side:** the tick on builder0 is ~22 ms at 25 v 25 with leaders (HANDOFF, brains' table, n = 1 ±30 %),
   ~60 ms on his laptop. The claim: one plan ≤ 1 ms on builder0 in C++ (the native port), and in GDScript sliced so
   that no tick carries more than ONE hull's plan step of ≤ 2 ms (≤ 10 % of the builder0 tick); the budget is spent as
   expansions, so the cap converts to ms per machine by one measurement.

## 6. What it must not do

- Change the plant (`tank_motion.gd`, `tank.gd`): the planner models it, it does not edit it.
- Re-plan every tick, or steer every tick: it emits legs; the executor drives them; the planner is asked again on an
  event.
- Read the wall clock, a random number, or anything not in the simulation state.
- Own the route: the navmesh route brings a hull to within the horizon (≤ 30 m) of its goal; the planner owns the
  last 30 m and every turn-in-place.
- Replace traffic's convention (who yields) or brains' gate placement: it answers "how do I get this hull to that pose
  through these obstacles", and reports `NO_PATH` honestly when there is none, so the layer above can ask someone to
  move.
