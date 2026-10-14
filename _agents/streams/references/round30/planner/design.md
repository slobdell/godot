# P1 — The design: a local lattice planner on the plant's own arcs

_Planner stream, round 30 (Fable 5.1). Against `problem.md` (P0). Decisions here are reversible by the orchestrator;
each carries its reason._

## 0. The decision in one paragraph

**A hybrid-A* search over a motion lattice whose primitives are exactly the legs the drive executes** — short arcs
and straights on the plant's own yaw law (`turn / R` per metre, either gear) — with a Reeds–Shepp-flavoured
admissible heuristic, a TIME cost (forward metres at the leg throttle's speed, reverse metres at the reverse cap's,
a cusp's braking and spin-up, a clearance band, squadmate space), a hull OBB footprint checked against a lazy
clearance field (walls from the navmesh in play, exact rectangles in the tests) and squadmates as oriented boxes, a
goal that is a POSE with a tolerance, a budget in EXPANSIONS (deterministic; the ms measured, never read), re-planned
on an event. Chosen over the two alternatives below because it is the only one of the three that answers every
fixture in P0 with ONE mechanism and ONE cost, which is the whole lesson of four rounds of local rules.

## 1. The candidates, weighed on the fixtures

| | A. lattice / hybrid-A* on (x, z, θ, gear) | B. a primitive set (Reeds–Shepp / clothoid words) searched directly | C. a sampling planner (RRT-style) |
|---|---|---|---|
| F1 creep at a corner (carrot inside the circle, low speed) | finds the one back-up + arc, or the arc that fits, by cost | RS gives the open-ground answer; in a street the word that fits must be found by trying all 48 with the footprint | finds something; the path quality is random |
| F2 wedge between two hulls | expands from a touching pose (the start's own margin is allowed, as today), finds reverse-on-lock then forward; reports NO_PATH when boxed | RS words start from a free pose; with obstacles, the only option is "try each word, shorten the first leg" — the planned-reverse rules of rounds 11–14, again | needs many samples in a pocket; an honest NO_PATH needs a budget it cannot interpret |
| F3 the boxed face (neighbours 4.7 m away each side) | the lattice turns in as many short legs as the gaps allow; the cost model says whether a 5-leg turn beats waiting | `plan_face` IS this candidate (equal legs on one lock, then greedy): it refuses when its two patterns do not fit | random |
| F4 the 180° arrival 9 m away | a goal pose; the plan is 2–3 legs, ~15 m (an RS CCC-type), no gate | RS's own case: good in the open, no answer with a wall beside the slot | fine but not deterministic by nature |
| F5 a hull across a street mouth | the OBB obstacle leaves a 6–7 m gap; the search either threads it (a 3.3 m hull can; a 14 m rig may not) or says NO_PATH | the word must be guessed | fine |
| F6 the street turn-round in 20 m / 12 m | the lattice finds the 5-leg half turn in 20 m and the 7–9-leg one in 12 m, or NO_PATH for a rig in 12 m | RS has ≤ 2 cusps: no half turn for a rig in 20 m at all | slow in a corridor |
| F7 the short move behind | the same search (today: a plant simulation of two options, open ground only) | RS exactly | fine |
| determinism (orientation 28, 52) | fixed expansion order, integer cell keys, no trig in the loop beyond the heading step (the plant's own `turn_heading`): the same bits everywhere | closed forms use `acos`/`atan2` (lesson 52: trig differs across builds) | needs a seeded RNG and is still order-sensitive |
| time | the cost: ~1–2 k expansions a plan in GDScript ≈ 50–150 ms (estimated, measured in P2); in C++ ≈ 1 ms | cheapest when the first word fits; unbounded fallbacks otherwise | the most expensive for an honest answer |
| what it reuses | `TankMotion.turn_heading` (the heading step), the k-turn's outline samples and margin, `Manoeuvre._others` for the hull list, `NavigationServer3D.map_get_closest_point` (`Pathing.closest_point`) for the field | `clothoid.gd` (the A4 row) for continuous-curvature legs | nothing |

**Why not clothoids now:** the plant has NO steering-rate limit (the lock changes in one tick; §1 of P0), so arcs and
straights are exact for it and a clothoid buys nothing until the plant gets one. `clothoid.gd` stays the arrival
curve for the route; a lattice primitive set can take a clothoid leg later without changing the search.

**Why a lattice and not "RS as the heuristic + hybrid-A* only in the hard case":** the hard case is the only case
this stream exists for, and the fixtures say the easy cases are the same search with fewer expansions.

## 2. The planner, precisely

### 2.1 State, primitives, lattice

- State `(x, z, θ, gear)`: continuous pose, discretised for the closed set to `(floor(x / 1 m), floor(z / 1 m),
  floor(θ / 15°), gear)` packed into one integer key (a Dictionary keyed by int; fixed iteration order is never
  relied on). θ is carried as the SUM of the commanded heading steps (no `atan2` per node; the start and goal
  headings are the only trig, once per plan).
- Primitives from a node are whole LEGS: `gear ∈ {+1, −1}` × `steer ∈ {−1, 0, +1}` (full lock either way or
  straight: the legs the lead asked for), each swept in `0.5 m` sub-steps with the plant's own
  `turn_heading(heading, sub · steer / R)` up to 16 m, a successor emitted at 1, 2, 3, 5, 8, 12 and 16 m and wherever
  the sweep meets the goal pose. **Revised in P2 (run 4):** on a one-metre lattice the search decided a cusp per metre
  and an IFV turned round in fourteen one-metre legs — the lead's N-point shuffle, found by a planner; with legs as
  primitives a cusp is a per-leg decision and costs what it costs. Six sweeps per expansion, up to 42 successors.
  The ω_max clamp is applied once per request: `PlanRequest.for_unit` lowers a hull's leg throttle until `v / R`
  is under its yaw cap on full lock (the Rat Rod: 0.7 → 0.64), and the plan carries the throttle for the executor.
- **The plant's heading lag (P2 finding, run 1):** `step_in_place` turns the heading by the speed at a tick's START
  and moves by the speed at its END, so while accelerating the heading lags the arc by `Δv · dt / R`, stays lagged
  through the cruise, and catches up while braking: a leg driven to rest ends on the arc's heading but its position
  drifts inside the ideal arc by ~`λ · cruise metres` (a War Rig at 8.4 m/s: λ = 1.3°, 0.3–0.5 m on a 19 m arc). The
  planner models it as a constant lag of the MOVE direction per gear (`v · dt / R`); the residual over spin-up and
  braking is under 1 % of a leg for the long hulls (`test_planner_model`), ~4 % for a short arc of the Rat Rod.
- Horizon: a `30 m` window round the start (the brief's bound); anything outside is NO_PATH's business.

### 2.2 The world: `PlannerWorld`

One object the search queries, two sources:
- **Walls:** `clearance(x, z) → metres to the nearest wall face`, from a lazily filled `0.5 m` grid over the window
  (a cell is computed the first time it is read: in play `bake_radius − |off mesh|` via `Pathing.closest_point` —
  exactly `_outline_offs`' arithmetic, cached; in tests the exact distance to a list of rectangles). A sample is the
  nearest cell's value minus the half-diagonal `0.36 m` (conservative: the true clearance at any point of the cell
  is at least that, by the 1-Lipschitz property of a distance field).
- **Hulls:** every other living hull as an oriented box `(x, z, heading, half_w, half_l)` plus `HULL_MARGIN 0.5 m`;
  an OBB-vs-OBB separating-axis test (4 axes, no trig). A moving hull's box is extended along its velocity by
  `v · 1.0 s` (where it will be while the first leg is driven); re-plan on the event `obstacle moved > 1 m`.
- **The footprint test** at a pose: each SIDE of the hull box walked from corner to corner by a sphere walk — a
  sample with clearance `c` covers the side for `c − margin` either way, so the next sample is that far on (one read
  per corner in the open, every 0.5 m beside a wall), and a block corner cannot slip between fixed samples (it did,
  between the quarter points of a 14 m side, in run 3) — each sample `clearance ≥ MARGIN_M 0.4` (the k-turn's
  `KTURN_MARGIN_M`, so bars compare) **or that side no deeper than it was at the start** (a nose parked against a
  face may not get deeper: today's rule, kept, so a wedged start is plannable) — and the OBB clear of every hull box.
  Checked every 0.5 m along a sweep and at the end of a leg's ROLL (§2.5). The field's bilinear sample overestimates
  by ≤ ~0.1 m at a convex corner; `SAMPLE_SLACK_M 0.15` covers it, and the tests audit every plan exactly.

### 2.3 Cost (seconds)

`g(node) = Σ legs: metres / v(gear)` with `v(+1) = throttle_fwd · max_forward_speed`, `v(−1) = throttle_rev ·
max_reverse_speed` (the executor's throttles: 0.7 both, so a rig reverses at 2.8 m/s and drives at 8.4: reverse
metres cost 3× forward metres, which is why the planner prefers short back-ups — the lead's "back up ENOUGH")
`+ CUSP_S` per gear change (`v_fwd / braking + v_fwd / accel` for the hull: the rig 2.2 s; a scout 1.1 s)
`+ STEER_CHANGE_S 0.3` per lock change on the same gear (fewer, longer legs; the executor's lock change is free but a
plan of forty 1 m legs is not what he asked for)
`+ BAND_S_PER_M · max(0, BAND_M − clearance)` per metre with `BAND_M 1.5`, `BAND_S_PER_M 0.5` (a leg 0.4 m from a
wall costs as if 55 % slower: the "grinds along walls" penalty, the margin itself stays hard)
`+ SQUAD_S` 1.0 per metre inside a squadmate's box grown by 2 m (space other crews need; soft, so a packed line can
still turn).

### 2.4 Heuristic: `h = max(d, R · |Δθ|) / v_fwd` + the cusps the room allows for

`d` the flat distance to the goal, `|Δθ|` the smallest heading difference. Both are lower bounds on the time of any
path the plant can drive (length ≥ d; heading change per metre ≤ 1 / R in either gear, so length ≥ R · |Δθ|; the
fastest metre is a forward one). **Plus (P2, run 2)** the cusps the remaining turn needs in the lateral room the hull
had at the START of the plan (`c`): one full-lock swing in that room is at most `acos(1 − c/R)` (taken as
`sqrt(2c/R)`, trig-free), so `ceil(|Δθ| / swing) − 1` cusps at `cusp_s` each. Informed, not admissible (room grows
along a path) — without it a rig's turn-round in a 20 m street was a 4000-expansion breadth search, because cusps
cost 2.2 s each and the core heuristic knew nothing of them; read per NODE it rose beside every wall (where a turn's
cusps are) and misled the search, so it is one number per plan. Weighted A* with `ε = 2.0` (the plan is within
twice the best the lattice holds). No trig in `h`: Δθ is the wrapped difference of the carried heading sums.

### 2.5 Goal, legs, and the executor's roll

- Goal test: `d ≤ TOL_M` and `|Δθ| ≤ TOL_DEG` (per request; defaults 1.0 m / 8° — the face's `FACE_ALIGNED_DEG`).
  A node in tolerance ends the search; its path's leg list is **merged** (consecutive primitives with the same
  `(gear, steer)` become one leg) and **rolled**: each leg's end is where the executor will STOP, i.e. the planner
  plans the leg `metres` and the executor drives `metres − stopping_distance` then brakes, as `_kturn_stopping` does
  today; the plan's leg lengths are the plant's distances, the executor's braking rule is unchanged. The footprint at
  `metres + ROLL_SLACK 0.5 m` along the same arc must also be clear (the roll past a leg's end at these throttles is
  under 0.5 m once the stopping rule is on; a hull without it rolls 4 m, which is P4's first finding against
  `kturn_brake_on()` being hull-gated at 10 m).
- `PackedPlan`: `legs: Array[Vector3]` (`x` = gear ±1, `y` = steer in [−1, 1], `z` = metres), `code` (`OK`,
  `NO_PATH`, `BUDGET`, `START_BLOCKED`, `GOAL_BLOCKED`, `ALREADY_THERE`), `why` (one line for a trace),
  `expansions`, `cost_s`, `end_pose`, and `ascii()` (the plan drawn on the world, for logs and the lab).
- **The executor contract** (today's `Vector2(gear, metres)` on ONE lock becomes `Vector3(gear, steer, metres)`):
  `cmd.throttle = throttle · gear`, `cmd.turn = steer`; when `driven + stopping ≥ metres` the leg BRAKES ON ITS OWN
  LOCK with the opposite throttle until all but stopped (0.3 m/s), then the next leg's gear and steer begin, or
  zero/zero after the last; aborted on a stall (2 s under 0.15 m of progress) or a timeout
  `metres · KTURN_SECONDS_PER_M + 1 s`; an abort is an EVENT (re-plan from the pose). Three things differ from
  today's executor (P2 findings, runs 2–4, all in `PlannerExecutor`): (1) today the next leg's throttle starts at
  once, which is right only because its legs share one lock — with a steer per leg the braking metres would be
  turned the wrong way; (2) throttle 0 with the lock on is the plant's CREEP (0.5 forward), not a brake — the face
  plan's last leg today ends on throttle 0 / turn 0 and coasts its stopping distance straight; (3) the discrete
  plant's stopping distance is `v²/2b − v·dt/2`, so today's `v²/2b` stops a rig at 8.4 m/s 0.14 m short. This is
  the P3 harness, line for line, so P4 can show the diff against `_planned_reverse`.

### 2.6 The interface (one seam)

```
# game/ai/planner/planner.gd
static func plan(request: PlanRequest) -> PackedPlan
# PlanRequest: start (Vector3 pos, Vector3 forward), goal (pos, forward, tol_m, tol_deg), hull (half_w, half_l, R,
#   v_fwd, v_rev, accel, brake, omega_max), world (PlannerWorld), budget (expansions), weights (optional overrides)
```
`PlanRequest.for_tank(tank, goal_pos, goal_forward, world)` fills the hull from `Units.stat` and the throttles from the
executor's constants, so manoeuvre's seam is one call. **Events that ask for a plan:** a goal pose within the horizon
(the route's last 30 m, a face, a slot with a facing); a leg aborted; an obstacle in the plan moved > 1 m; a new goal.
Nothing asks per tick.

### 2.7 Budget

`budget` is a count of expansions (default `1500`; a fixture states its own). The search is resumable: `plan()` may be
called with a `PlanSession` and a per-call slice (`200` expansions ≈ 10–15 ms in GDScript, by P2's measurement),
so one hull's plan spreads over several ticks and no tick carries two hulls' slices (a one-deep queue in the seam,
P4). The expansion count is the SAME on every machine for the same request; the ms per expansion is a per-machine
number recorded with its commit.

### 2.8 Goal poses for a drawn facing and a 180° arrival

- **A drawn facing on a slot:** goal pose = (slot, facing), `tol 1.0 m / 8°`. No approach gate: the route brings the
  hull to within the horizon; the plan takes it onto the pose. The 180° case plans itself (F4: drive past, reverse
  arc, forward onto the slot — or reverse straight onto it if the facing says so: a goal pose with the tail first is
  the same pose with `gear −1` allowed on the last leg; the request's `arrive_gear ∈ {any, forward, reverse}`).
- **A SIDE gate instead of a gate beyond the goal:** where the planner is not reached (a hull beyond the horizon),
  brains' gate rule can keep a gate, but placed to the SIDE: `slot + perp · R` on the side with room (the circle
  tangent to the facing at the slot), length `R`, never along the facing axis behind the slot. This is a note to
  brains (C30.5 keeps the gate theirs); the planner itself needs no gate.
- **A face at rest:** goal pose = (home, want), `tol = settle_radius − 1 m` (as `plan_face`'s `stay`), `8°`.

## 3. What the tests hold the design to (P2's pass lines, pre-registered here; the MEASURED results against each
## line are in `planner.md` Status *The report*: met for the twin, the T-junction, the mouth, the corner, the packed
## line, the slot's metres and the honest answers; not met for the wedge (4 legs), the causeway slot (4), the rig's
## 20 m turn-round (9; the lattice's best 8) and the IFV's 12 m turn-round (not found), each recorded)

| fixture | pass line |
|---|---|
| kinematic twin | a 20 m straight, a 90° full-lock arc, a 10 m reverse arc: planner end pose within 1 % of distance of `TankMotion.step_in_place` at the leg throttle (position) and 1° (heading) |
| F6a turn-round, War Rig, 20 m street | reaches within 2 m / 8°, ≤ 6 legs, no outline point < 0.4 m from a face (exact check, every 0.25 m), expansions ≤ 1500 |
| F6b turn-round, War Rig, 12 m street | `NO_PATH` or ≤ 9 legs within the same bounds (the geometry decides; the test asserts the honest answer, and that an IFV (R 7) DOES turn in 12 m) |
| T-junction, War Rig (20 m streets), 90° into the side street from 10 m short | ≤ 3 legs, clear |
| street mouth with a squadmate stopped in it (a rig across half a 20 m street) | an IFV threads the gap in ≤ 2 legs; a rig gets `NO_PATH` or a clear plan (asserted either way: no penetration) |
| yard corner (L of two faces), War Rig entering, goal round the corner | ≤ 4 legs, clear |
| 180° arrival onto a slot 9 m ahead (law_scout) | ≤ 3 legs, total ≤ 25 m (today's gate route: 21.6 m to the gate + 12.5 back = 34 m), within 1 m / 8° |
| wedge: nose touching a wall, 0.2 m, 30° to it | a plan that starts in reverse, clear, ≤ 3 legs |
| packed line of four 14 m trucks at 12 m, each to face east (planned one at a time with the others as boxes) | each ≤ 6 legs, clear of the neighbours' boxes, or `NO_PATH` with the reason; the stretch note says who goes first |
| time | expansions per fixture printed; ms per expansion on builder0 recorded in Status with the commit |

Every fixture prints its plan as ASCII (the window at 1 m per column, walls `#`, hulls `H`, the path's poses as
`>`/`<` by gear, the goal `G`).
