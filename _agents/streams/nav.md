# Stream: nav (units still drive into walls: the Terminus drive test, and every clearance number names its motion)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*), [workstreams.md](../workstreams.md) (*Round 10: the eight streams*, contracts **R3**, **R4**,
> checkpoint **CP2**, **CP4**; *What reads `hull_size`*), [navigation.md](../navigation.md), and your round-9 brief
> [archive/round9/nav.md](archive/round9/nav.md) — its "Next steps, in order" and the pre-registered wheeled-facing row
> are folded in below.
>
> **You own** the desired-velocity layer: `game/ai/{pathing,steering,combat_motion,movement,avoidance,pid,
> control_gains,order_controller,order_feed}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk`, `tests/nav/`, `tests/test_*`
> for those files, `_agents/navigation.md`. Not yours: `game/ai/gunnery.gd` (combat), `tank_brain.gd` (squad),
> `game/tank/tank.gd` and the plant constraint (combat), `hull_size` values (feel's carve-out for two units, combat
> otherwise), the bake radius in `arena.tscn` (arena's; you read it live).

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> Units are still driving into walls.

> I want to gauge how smart units are by trying to navigate them through the city.

And his afternoon acceptance: *"I'll know that they units are doing what I want when I can navigate them through the
Terminus streets."* The round's bar for you is that sentence, measured.

## Where things stand

- **The map was against you.** Containers sit in the Terminus lanes (arena's brief, item 1; CP2 clears them and asserts
  every lane's drivable width ≥ 6.64 m). Until CP2 merges, measure on the ring road and the clear halves of the
  avenue, and say so beside every number; after it, the whole grid.
- **"Driving into walls" has no counter.** Nothing on the tree counts a hull-wall contact per tick, per unit, per
  cause. `Tank`'s plant (combat's) knows when `move_and_slide` collided; `Movement` knows the route and the corridor;
  neither publishes "this hull touched a wall at this tick while doing X". The first thing this round is that
  instrument, published in `Movement.state(unit)` and on `--nav-off` telemetry, so "still driving into walls" becomes
  a number with a cause split (routing: the path ran through the wall; steering: the desired velocity pointed at it;
  avoidance: ORCA deflected into it; the plant: the hull could not follow; the arena: the box was not in the bake).
- **What you already know:** the `wedged` regime detector (round 9, fires 8× in the defile run; all three
  pre-registered hypotheses dead; 61 % ORCA deflection with no arrival); `Arena._obstacle_shapes()` tiles big boxes
  because the baker ignores them (arena's; a hull "pinned against an obstacle its path insists is not there" is the
  failure it prevents); `clearance_shortfall()` and the routing refusal behind `--nav-off=clearance` (off on
  measurement: progress −35 %, 90.9 % of consultations refused, and your own correction that `radius_of` is a
  ROTATIONAL envelope compared against a LATERAL clearance); `Movement.hull_box()` as the one accessor; the clothoids
  (A4) off; the arrival arc's `off_mesh` refusals split 474/361.
- **The plant is combat's and its constraint is OFF** (`Tank.yaw_fit_enabled`, `game/tank/tank.gd:683-710`): with it
  on, four of five squads froze at spawn (the refusal never resets); combat's round-10 first item is the predicate.
  Your round-9 endorsement of a world-only mask stands as an ARM, not a default, and only with `test_move` in both
  arms and "the corridor must not move" as the arm proof. **Relay rule:** when your drive test shows a hull rotating
  through a wall, that is combat's row; when it shows a hull DRIVEN into a wall by its desired velocity, it is yours.
- **Every clearance constant must say which motion it licenses** (your lesson 197): `HULL_CLEAR_M` (squad's: its pitch
  is being derived from the turning envelope this round), the bake radius (arena's, 2.0 m, driving), `Avoidance.
  radius_of` `(w + l)/4 + margin` (yours: the seventh disc site, 4.58 m for the rig against a 1.66 m half-width, too
  wide abeam, too narrow end-on, with its own falsifier).
- **The held wheeled hull's facing** (pre-registered in round 9): crews end at tank 1.4°/16.2°, ifv 41.4°/28.5° after a
  hold with a drawn heading; a wheeled hull cannot neutral-steer. Falsifier: all four crews within 10° within 5 s on the
  default arena; `face_giveups` stays zero; time-on-station and shots not reduced; a bounded, visible three-point turn.
- **The seam** (round 9's structural finding, yours and squad's): `CombatMotion` decides under a tenth of a hull's
  ticks and `Movement` drives the rest knowing no leash; every one of your five rows trips on it. Not a first item;
  the first candidate once the drive test says where the wall contacts come from.

## Backlog (in order)

1. **The wall-contact instrument.** Per unit per tick: contact yes/no (from the plant's collision report; ask combat
   for one getter if `Tank` does not expose it, stub by reading `get_slide_collision_count()` through the unit),
   the cause class (route / steer / avoid / plant / bake), the corridor and the lane name if arena's `lanes` cover
   the point. Published in `Movement.state()` and summed in the `--nav-off` arm report. A test that drives one hull
   at a wall and reads the counter is the mutation check.
2. **The Terminus drive test** (the round's bar). A scripted default-path run (`make skirmish`-equivalent flags:
   none) on Terminus: a mixed squad ordered street to street (spawn → ring road → west street → plaza → the far ring
   road), then a squad of War Rigs the same way. Pass: every unit arrives, zero wall contacts for the mixed squad,
   the rigs' contacts named by cause. Run it on the pre-CP2 map on the clear streets first, then on CP2's map; both
   numbers in Status with the commit and machine. This is the test the orchestrator reads before merging anything of
   yours.
3. **Fix what the instrument names, one cause at a time, each as an arm.** Expect: routing corners cut through a
   kerb container (the chord slack against the hull's WIDTH plus the bake, not `radius_of`); ORCA deflecting into a
   wall in a corridor (the navmesh refusal's fallback); the wedged regime (something must notice it; today nothing
   does). Every fix has a before/after on item 2 and the sim baseline pre-registered UNMOVED unless the fix is a
   default-path behaviour change, in which case it is pre-registered MOVED with one cause and merged alone.
4. **`Avoidance.radius_of` (the seventh disc site).** An oriented capsule or box abeam vs end-on, behind a knob, with
   its falsifier (the defile dispersion and the yard oscillation share must not worsen; the rig's abeam clearance
   falls from 4.58 to ~2 m + margin). Off until the numbers say.
5. **The held wheeled hull's facing** (the pre-registered row above), after items 1–3.
6. **The seam.** Measure first: what fraction of Terminus drive ticks is `CombatMotion` deciding, and does a leash
   or corridor exist in `Movement` for those ticks? Then the smallest change that lets `Movement`'s goal selection
   see the formation leash (A7's level-0 region), as an arm with A12's four metrics from `make metrics`.
7. **Stretch:** A6's falsifier once squad's field emits `corridor`; N4's 361 unreachable gates against the clothoid
   arm; `facing_arc` in `Movement.state()` for metrics (owed from round 9, cheap: publish it).

## How to verify

- `make check` green (`make remote T=check`); `make nav-fight-maps`, `make metrics LOGS=…` for A12; the drive test
  as its own make target (`make nav-terminus-drive` or the name you choose, in `mk/nav.mk`), run on builder0.
- `make skirmish ARENA=terminus` and drive them yourself; look at frames at his pose.
- Every number: commit, machine, sample size, the arm proven applied (round 9: five green zero-reading arms).

## Don't touch

`game/tank/tank.gd` and the plant (combat's: send combat the contact log and a failing test), `game/tactics/**`,
`tank_brain.gd` (squad's), `arenas/`, `game/arena/`, `arena.tscn`'s bake radius (arena's; a change there is a
request with your falsifier), `game/theme/**`.

## Waiting on the lead

Nothing blocks. "Heavies in alleys" (should hulls above the bake radius not route through alleys narrower than their
clearance) is DECIDED for this round: after CP2 there are no lanes narrower than the rig; alleys off the lanes are
priced by your instrument and reported, not refused.

## Research addendum (brief 2, 2026-09-20 evening; rows B1, B4, B5, B6, B7, B14)

**The seam has a shape now (B1): an explicit reference governor over a funnel.** The element publishes a chain of
convex corridor polytopes plus a leash (squad's publisher); `Movement` projects its nominal velocity onto that
admissible set every tick, scaling speed along the centreline and never leaving the corridor; the unstick heuristics
run only outside it. Neither intent down nor execution up: one shared object both layers read. Item 6 is that, with
A7's projection, A6's corridor and the leash as consumers of the same object. Bars: off-corridor share and unstick
triggers fall on the Terminus drive test and five_squads with the active fraction beside them; A12's formation
residual does not rise; no new freeze. Composition rule (B14): a right-of-way hold line is a barrier INSIDE the
admissible set, never an "obstacle" that trips unsticking.

**The defile gets a new arm (B6): a corridor right-of-way TOKEN, zone-triggered.** In any passage narrower than twice
the swept width, reciprocal avoidance is OFF and a single-lane exclusion zone with two terminals arbitrates: the
leader takes the token with a polarity, squadmates inherit at ≥ 1.5 L headway, the token frees when the last rear
axle exits, ties by unit id. This is why the round-9 right-of-way "never asked": it was stall-triggered. Falsifier on
`make squad-defile`: every unit arrives within 1.25× its unimpeded transit, zero head-on deadlocks over 200 opposing
runs, `wedged` fires 0 times. Item 3's "ORCA deflecting into a wall in a corridor" is this arm.

**Item 5 (the held wheeled hull's facing) is narrowed (B7):** turreted wheeled hulls keep their approach heading on
arrival and the turret covers; only HULL-FIXED wheeled units whose weapon arc the residual exceeds do the bounded
three-point turn. Falsifier unchanged for that case; the others are out of the row.

**Corners (B4):** arena is certifying lane corners with the rig's turning template offline; your drive test with
rigs is its runtime check. The per-class routing table (an edge certified or not per class, priced at corners) is
next round's row and the reframe of `clearance_shortfall`. **Vocabulary (B5):** every clearance constant you touch
names its tier: static footprint, swept travel ribbon, turning envelope, combat signature.

## Research addendum 2 (brief 3, 2026-09-20 late; rows C1–C5 in the catalog's *Round 10 addendum, part 2*)

**The funnel has a construction and a cost (C1), and you already compute most of it.** From the navmesh corridor the
route already has: run the portal funnel (`pathing.gd`'s string-puller) with the apex offsets shifted inward by
`r_eff = r_a + R_min·(sec(Δψ/2) − 1)` per portal turn (the off-tracking term; `R_min` is the unit's
`min_turn_radius_m`), shrink each corridor polygon's boundary half-spaces by `r_eff`, intersect neighbours around each
portal into a convex overlap polytope; 3–6 half-spaces each, 6–20 polytopes for a 3–5 s horizon, one fixed pass.
That chain is the funnel B1's governor projects onto. Cost claim to measure: under 12 polytopes and under 12
half-spaces per polytope per agent; the executor's projection is a 2-variable QP with ≤ 12 constraints (a fixed
Seidel pass), which is deterministic by construction.

**"Who yields" is a deterministic key (C2), and it is the rule B2's reservation and B6's token both lacked:**
(in-emergency-brake, −clearance slack, stopping distance v/a, distance to goal, unit id); higher-priority reservations
are immutable within a step and lower agents take one half-space cut per conflicting neighbour, zero iterations. A
buffered Voronoi cell asymmetric by priority is the geometric form of the same cut. Hard rule: a higher agent's cut
may never slice a lower agent's CURRENT braking set; truncate the higher's reservation instead. Counter: an active
polytope sliced empty is the freezing-robot cascade, and the count must be zero.

**Starvation is safe by construction (C3):** every deliberative packet carries a braking trajectory ending
stationary inside its last polytope; a missed deliberative step degrades to a stop, never to an unstick heuristic.
Positive control for the seam item: drop a deliberative step on purpose and show a stop, not a wedge.

**The corner pinch (C5) is arena's certification and your drive test's corner case:** the same `sec(Δψ/2) − 1`
term decides whether a junction is drivable for the rig.

**Next round (C4):** per-class eroded meshes and precomputed portal-pair polytopes; the bake stays 2.0 m now.

## Status

_(the worker keeps this current)_

**Plan (2026-09-22, nav worker, round 10), smallest foundation first:**
1. `WallContact` (`game/ai/wall_contact.gd`, new, nav's) read by `Movement.observe_contact()` from the controller's
   `_physics_process` before the stride skip; the decision it judges is `Movement.note_decision()` at the end of
   `compute_command`. Published in `Movement.state()` (`wall_contact*` keys) and summed in `NAV_FIGHT` (`wall_contacts`).
   *Decision:* a stub read of `Tank.get_slide_collision_count()` (public on `CharacterBody3D`), no edit to `tank.gd`;
   staleness guarded by `Tank.is_parked(tank.command)` (a parked hull skips `move_and_slide`). Request to combat below.
2. `make nav-terminus-drive` (`tests/nav/terminus_drive.gd`): mixed squad and rigs, spawn → ring road → west street →
   plaza → far ring road, through `Orders`; pre-CP2 numbers first.
3. Fix by cause, one arm each, with before/after on item 2.
4. `radius_of` oriented (knob, off). 5. Held wheeled facing (narrowed by B7). 6. The seam, measured first. 7. Stretch.

### The Terminus drive test (item 2): before/after, pre-CP2 and CP2

`make nav-terminus-drive`, builder0, seed 1, 90 s per leg, legs spawn → ring road (-40, 30) → west street (-70, -10) →
plaza (0, 0) → far ring road (40, -30). Deterministic (two runs of one tree byte-identical). Contacts = **unit-ticks
with a wall contact** (30 Hz) of observed unit-ticks; arrival per leg (within 7 m of the crew's own slot, order done).
"arms" = item 3's `press,inflate` (pressed-wall escape, corner inflation), proven applied by their counters.

| map | tree | arms | squad | arrived per leg | contacts / observed | by cause | top colliders (steer) | hull-hull |
|---|---|---|---|---|---|---|---|---|
| pre-CP2 | `95ae1ce6` | off | mixed ×6 | 5, 5, 6, 4 | 7866 / 39472 | steer 6529, plant 1301, avoid 36 | Block_1 2279, Block_7 1890, Block_0 1766 | 3398 |
| pre-CP2 | `95ae1ce6` | off | rigs ×4 | 1, 1, 0, 0 | 15691 / 24463 | plant 8893, steer 6790, avoid 7, route 1 | Container40_19 2326, Block_6 2215, Block_1 1960 (plant: Floodlight_44 7839) | 8620 |
| CP2 | `c91d8039` | off | mixed ×6 | 5, 3, 6, 4 | **4957** / 36146 | steer 4632, plant 306, avoid 19 | Block_1 2384, Block_7 2184, Floodlight_35 52 | 6123 |
| CP2 | `c91d8039` | off | rigs ×4 | 2, 2, 1, 3 | **8139** / 23349 | steer 6200, plant 1864, avoid 75 | Block_1 3929, Floodlight_31 2150, Block_0 58 | 9518 |
| CP2 | `c91d8039` | ON (56 / 67 escapes, 231 / 278 corners) | mixed ×6 | 5, 4, 6, 4 | **1575** / 33298 | steer 954, plant 618, avoid 3 | Block_7 394, Block_1 306, Container40_8 196 | 5999 |
| CP2 | `c91d8039` | ON | rigs ×4 | 1, 3, 2, 3 | **3839** / 26599 | plant 2599, steer 1165, avoid 75 | Block_1 486, Floodlight_31 313, Block_0 255 | 8092 |

**CP2 alone: −37 % (mixed), −48 % (rigs). The arms on top: −68 % / −53 %.** Still short of the bar (zero contacts for
the mixed squad, every unit arriving). What remains is mostly a hull at the END of a route that lies on the mesh edge
against a kerb, its slot 8–14 m away (probably off the mesh: the miss report now prints `reachable` and the slot's
off-mesh gap, for squad) — item 3c, the nose stop, is that row.

**MERGE HERE: `f386c63e`** — builder0 check (REMOTE_SLOTS=5): 1634 passed / 0 failed, ai-scenarios 44,0 unchanged,
**sim-baseline MOVED `1ea332e7bc268d2a` → `7574ac017c17265b`, the ONE pre-registered cause: the not-ready route retry**
(`--nav-off=notready` reads the recorded hash back exactly). Merge alone and adopt the baseline (`make
sim-baseline-adopt`). Arms opt-in in that hash; the per-arm `tactics_elements` bisect (arm alone ON): press 8/0,
nosestop 8/0, **inflate 7/1** (the element's drive north) — inflation stays opt-in until that is understood.

**The arms are OPT-IN (inverted switches, like `a7`) until their own A/B clears**, because default-on at `c91d8039`
they reddened two `test_tactics_elements` tests (bisected: corner inflation delays the element's drive north; the
dragged-heading hold is under bisection) and moved the sim baseline. **The sim baseline's one pre-registered cause is
the not-ready route retry** (combat's relay): hash with arms off = `7574ac017c17265b` (builder0), vs recorded
`1ea332e7bc268d2a`; per-arm hashes: `--nav-off=press` → `630c4d0f0227bdc7`, `inflate` → `53ae702d4f43e232`
(each arm moves it on its own too; `make nav-sim-arms`).

### On main's current map and roster (CP2 + CP3 bus + turret mounts), tree `0e53c0c2` code (= main `709cbeb9` + opt-in rows)

builder0, seed 1, same course; arms proven by their counters (zero in the default row).

| arms | mixed contacts (of observed) | mixed arrived | rigs contacts | rigs arrived |
|---|---|---|---|---|
| default path (retry only) | 5959 / 34317 | 5, 4, 6, 4 | 8139 / 23349 | 2, 2, 1, 3 |
| press + nosestop | 599 / 26252 (−90 %) | 5, 4, 4, 2 | 8079 / 24550 | 0, 1, 2, 0 |
| press + nosestop + inflate | 424 / 29150 (−93 %) | 5, 4, 5, 3 | 2428 / 19128 (−70 %) | 0, 3, 1, 2 |

**Arrival is confounded by off-mesh goals:** most misses in every arm are crews whose controller's goal is 4–10 m off
the navmesh (`reachable=false`, the miss report's `goal_off_mesh_m`). squad grounds slots through
`SlotGround.standable` (to the mesh EDGE, bake-radius clear only) and is adding the hull's clearance; the re-read of
the miss list against each crew's actual move order and Orders verb (squad's two questions) is queued. Until then
the arrival columns are not a nav finding and press/nosestop stay opt-in.

**Inflation and the element's drive north:** on main's re-specified test (a speed bar, 21.6 m) the leader makes
9.3 m with inflation ON and 9.2 m with it OFF (builder0 traces, same tree): the test is red on this tree either way
(main's check lists it among CP3's REASON'd reds). The old 7/1 against inflation was on the pre-CP3 literal.

### Item 5, the held wheeled hull (B7), `--nav-off=wheelhold` (opt-in)

A turreted wheeled hull under a `face` keeps its heading and its turret takes the spot; a hull-fixed wheeled hull
(the three scouts) turns only until the facing is inside its fire arc. `make nav-facing VERB=hold`, yard, builder0,
tree `f056f342` code, 30 units, one seed:

| arm | shuffle after arrival median / worst | covering error within 10° at +5 s | hull error median +10 s | face_giveups |
|---|---|---|---|---|
| off | 2.02 m / 8.38 m | 5 of 25 | 2.2° | 0 |
| ON (18631 holds, 11136 arc stops) | 0.07 m / 4.45 m | 14 of 24 | 7.6° | 0 |

The shuffle is gone and coverage nearly triples. Not yet default: the falsifier's "time-on-station and shots not
reduced" needs a fight (`nav-fight-ab AB_OFF=wheelhold`), and the worst covering error (138°) is a turret engaged or
held elsewhere, unread.

### Item 4, the oriented pair radius, `--nav-off=oriented` (opt-in) — FALSIFIED as a default

Built and unit-tested (two rigs: 3.82 m abeam, 14.5 m end-on, against the disc's 9.16 m both ways). Falsifier, `make
nav-defile-ab` (squad's defile probe through `tests/nav/defile_arm_probe.gd`, builder0, tree `31e9d83c` code, arm
proven: `oriented_pairs` 6483 tracked / 7206 wheeled vs 0): **tracked arrivals 4 → 2 of 5, inversions 22 → 37**
(dispersion 14.0 → 3.93 s over the fewer arrivals); wheeled 0 of 5 arrive in BOTH arms (the scenario fails on this tree
either way). Worse on the pre-registered bar, so it stays opt-in. The probe ignores `--seed` (8 seeds byte-identical):
n = 1 per locomotion, stated.

### Item 6, the seam — measured first

`make nav-fight ARENA=terminus` (seed 3, 120 s, both armies, builder0, tree `31e9d83c`), unit-ticks by the layer that
produced the motion (`Movement.driver_ticks`): **route 131379 (47.6 %), direct = CombatMotion's hops 47374 (17.2 %)**,
face 42813 (15.5 %), yield 30939 (11.2 %), stop 23298 (8.4 %), unstick 56. On Terminus CombatMotion decides about a
sixth of fight ticks, not "under a tenth". **`Movement` has no leash or corridor input on ANY tick** — structural: the
leash exists only inside `CombatMotion.choose`. Fight wall contacts 16725 of 233122 observed: by driver route 10712,
yield 3079, direct 2128, face 739. **Finding: 10 % of yielding ticks touch a wall** — `_free_spot` checks the navmesh
and other hulls, not the hull's clearance from walls.

### The check on the merged tree

**`d2bd7ac3`** (items 4+5 opt-in, main `f29c5b7c` merged), builder0, REMOTE_SLOTS=5: 1652 passed / 2 failed,
sim-baseline PASSES `11c479c3bec77082`, ai-scenarios 40,4 vs the recorded 44,0. Every red is main's CP3 set with its
REASON (units: parked-friend lane, tactics_elements drive-north; scenarios: formation-slot, base-of-fire,
parked-friend, perf under load; main's own record reads 39,5). No red is nav's.

### The yield-spot clearance row, `--nav-off=yieldclear` (opt-in) — PRE-REGISTERED before its A/B

A yield spot must be on the mesh with the hull's turning-envelope shortfall clear in eight directions. Falsifier on
`make nav-fight ARENA=terminus` (seed 3, 120 s, builder0, both arms on one tree, arm proven by `yield_spots_refused`
> 0): **wall-contact ticks with driver `yield` fall by ≥ 50 %**, the `progressing` share does not drop by more than
0.02, and `blocked_friend` does not rise by more than 0.01. Any of the three missed = it stays opt-in.

**Result, seed 3 (builder0, tree `5e6e608e` code, arm proven: 75 spots refused vs 0):** yield-driver wall contacts
**3079 → 1289 (−58 %)** ✓; `progressing` 0.428 → 0.412 (−0.016) ✓; `blocked_friend` 0.007 → 0.007 ✓; all wall
contacts 16725 → 13640. **Not pre-registered and stated:** `blocked_no_path` 0.091 → 0.128. One seed is not a series
(C6): the paired A/B over seeds 1, 3, 5, 7, 9 (`nav-fight-ab AB_OFF=yieldclear ARENA=terminus`) is running; the row
stays opt-in until it and the `blocked_no_path` rise are read.
