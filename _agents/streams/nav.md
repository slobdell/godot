# Stream: nav (round 9 — the desired-velocity layer, rebuilt in the catalogue's order: A7 → A11 → A1 → A4)

> Read `HANDOFF.md`, [orientation.md](../orientation.md), [orchestration.md](../orchestration.md) (the worker contract),
> [game_design.md](../game_design.md) (*Round 9 direction*, *Round 8 direction*), [workstreams.md](../workstreams.md)
> (*Round 9: the seven streams* — checkpoints CP1/CP2/CP3, contracts **S2/S3/S4**, the standing rules; then *Round 9
> goal* — your own sequencing argument, adopted), [research_catalog.md](../research_catalog.md) (rows **A1, A4, A7,
> A11**, Part 1 §5, Part 2), [navigation.md](../navigation.md), [algorithms.md](../algorithms.md), and your round-8
> brief in [archive/round8/nav.md](archive/round8/nav.md) (its Status is the ground truth for where the layer stands).
>
> **You own** the desired-velocity layer: `game/ai/{pathing,steering,combat_motion,movement,avoidance,pid,control_gains,
> order_controller,order_feed}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk`, `tests/nav/`, `tests/test_*` for those
> files, `_agents/navigation.md`. `game/ai/gunnery.gd` is combat's; `tank_brain.gd` (the caller of `CombatMotion.choose`,
> `MOTION_REPLAN_TICKS`, the brain's `COMMIT_BONUS` 1.15) is squad's — request, do not edit. The `hull_size` values and
> `min_turn_radius_m` are combat's data, and this round the sizes are **scale**'s (S1): read them, never set them.

## The lead's direction (2026-09-19)

Round 9 is the research catalogue plus two items he added. None of the two is yours to build, but both shape your work:

> *"The semi trucks for the road gangs are still one long box itself of a truck / trailer combination."*

**Contract S2: articulation is VISUAL this round** (feel's). The tractor stays the simulated body, the 14 m box stays the
collider, `articulated` in `Units.LOCOMOTIONS` stays reserved. **You do nothing for it** — no trailer in the plant, no
hinge in `TankMotion`. The follow-on (a second body, the plant's articulated locomotion) is recorded in
`game_design.md`, not scheduled. If feel asks you for the tractor's drawn motion, that is `Tank`'s pose and
`estimated_velocity`, already public.

> *"We need to do proportional, real-world relative sizing for all of our vehicles."*

**Checkpoint CP2 (scale's) will resize most of the roster by 1.5–2×.** Your clearance gap from round 8 (`_chord_slack()`
uses WIDTH; the navmesh is baked at `NAV_AGENT_RADIUS` 2.0 for every hull; a long hull's tail sweeps outside the line its
centre follows) becomes twice as consequential. **Build against the current roster; re-measure everything after CP2;
publish no size-dependent number measured across it.**

And the standing verdicts that this round's rows exist to answer, all his:

> *"they still generally don't do what I command them"* · *"moving back and forth indefinitely"* · *"the semi trucks are
> yawing in place (should be impossible, they're not a tracker vehicle)"* · manoeuvres should look **intended**.

## Where things stand (on `main` at `f49aa08a`, round 8 closed)

**The layer.** `Movement.drive()` (`movement.gd:425`) composes, in this order: the arrival gate (`_approach_gate`, only
when the order carries a `facing`), the route carrot (`_next_waypoint`, repath on goal-moved/off-path/stalled or every
`REPATH_SECONDS` 4.0), `_around_fire`, ORCA (`_avoid`), the chord guard, then `Steering` (P law for tracks; pure pursuit
plus three-point turns for wheels), then PID station-keeping on a sliding goal. In a fight, squad's `TankBrain._combat_move`
(`tank_brain.gd:2219`) builds a request and calls **`CombatMotion.choose`** (`combat_motion.gd:168`): a 16-direction ×
{forward, reverse} ring scored by **additive weights** (`WEIGHTS`, `:97`: range, tangent, side, flank, armour, continuity,
reverse, turn) minus penalties (side-on, ram, crowd, leash, hit), plus `COMMIT_BONUS` 0.35 for last plan's index, re-planned
every `MOTION_REPLAN_TICKS` (= TICK_RATE/4, squad's file) unless the key changes. The plant (`tank_motion.gd:110`) turns
(throttle, turn) into motion: tracks/hover with a yaw ramp (round 8), wheels at yaw = |speed| × turn / radius with the
multi-point **creep** (`WHEEL_CREEP_THROTTLE`, 0.5 s legs alternating gear).

**What round 8 measured (all builder0 unless said; commits named; the raw JSONs are in
`_agents/streams/references/round8/nav/`):**

| finding | number | where |
|---|---|---|
| the back-and-forth is real, on every map, on nearly every unit | attack-move `oscillating_share` **7.2 / 6.6 / 5.8 / 5.3 %** on yard / boneyard / pit / boulevard, 25–28 units per map; tree `aa984edd`, Condemned mirror, seed 3, 120 s | archive Status *The headline* |
| it is not terrain and not the hold path | `blocked_terrain` 0.000–0.010; Condemned oscillation identical to 3 decimals between hold-hysteresis arms on 3 of 4 maps | same |
| the mechanism is gear-shuffling | scout in-place events: 7 of 11 windows had both gears > 0.5 m/s (laptop `3018e993`); gear flips **9–19 per agent-minute** in a 2 s window, ~⅓ ordered reverse, ⅓ creep K-turn, ⅓ unexplained (P2) | archive *Round 8 report* §6 |
| commitment was never consulted by a hold | a standoff HOLD returns `index −1`; ~40% of wheeled events happen while holding; commit on/off moved scout wobble −14 % … +19 % (inconclusive by rule) | archive *Results of the commit/wobble A/B* |
| the semi does not yaw in place; the small cars do | 0.11–0.74 events per semi-minute vs 3.4–3.7 per scout-minute (`3018e993`); the 14 m rig's "pivot" on yard is the creep's legs cancelling against scenery: 26° within 1.5 m on yard, **7° on bare ground** at every length (`81f87186`) | archive *The War Rig's pivot is length-driven* |
| a veto backfires | forbidding fast target switches more than doubled switch-and-switch-back (P3) | catalogue P3 |
| hold hysteresis: built, measured, **not a win** | scout events −22/−19.5/−8/−6 %, 1 of 4 maps at the bar, kills guard tripped (2–5 lost of 90: no power) → opt-in via `--nav-off=holdband` | archive *Hold hysteresis A/B* |
| flow fields: **a null**, reverted with their switch | stuck_share −10 / −1 / +9 % over three seeds; the field answered 70–75 % of plans | archive *Flow fields* |
| **the arrival arc has never executed in a fight** | `gates aimed 0, gates refused 0` in BOTH arms of its A/B (`a35cf487` vs `777574e5`); a facing enters a move from **one** place, the touch map (`--touch-map`), which the lead never runs (lesson 149) | HANDOFF *Three claims…*; archive *Round 8 wrap-up* |
| the yaw ramp shipped | tracked pivot 90 % of peak in 7 ticks (was 1), `9f8c21e2` | archive *Round 8 report* §1 |

**Round 8's lesson for this round, in one line:** three things were built, measured and thrown away (flow fields, a
gear-change cost, a target-switch floor), and **all three were cheap because they were measured before shipping**.
Keep that shape.

**Two things that are NOT established, written so you do not inherit them as facts:**
- *"the facing pair is inert"* was measured against the old `sim-baseline` match, which was blind to 5 of 6 mutations
  (wheeled turn rate among them). The baseline is now combat's widened match (`04414f5d6a6dfa7c`). Re-run, do not cite.
- *"the arc is measured inert"* — it is **measured to never execute in a CPU fight; untested under player facings.**

**Instruments you have** (`mk/nav.mk`): `nav-fight` / `nav-fight-maps` (per-unit-tick buckets, `NAV_FIGHT_ARM` read live,
`travelled` = path vs net displacement over 4 s windows, `oscillating_share`, in-place-yaw and gear-flip counters,
`FIGHT_REQUIRE` refusal), `nav-fight-ab` (fails when the arms are the same treatment or every seed is identical),
`nav-rotation-numbers` (unwrapped headings; `--empty` strips scenery), `nav-suite` / `nav-where` / `nav-orders` /
`nav-facing`, and `--nav-off=<name>` with `OFF_NAMES` refusing unknown names. **`gates_aimed` / `gates_refused`
(`movement.gd:1072`) are the model for every arm counter this round.**

## Backlog (in order)

Each row states **what it REPLACES by file and function** (Invariant 0c; *"nothing"* is the answer the orchestrator
interrogates), a **pre-registered falsifier**, and the **arm counter** that proves the treatment engaged. Until **CP1**
(metrics' A12 tool) merges, read the falsifiers from your existing counters and mark every number **provisional**;
after CP1, the verdict is read from `tools/metrics/` and nowhere else (contract S3). After **CP2** (scale's resized
roster), re-run every measurement below before publishing it.

### N0. Ground rules for the round (day one, an hour)

- Start from a green `make remote T=check` on your branch. Merge `main` **only at announced checkpoints** (CP1, CP2,
  CP3) — the orchestrator messages you.
- Write your Status plan first. Add `_agents/navigation.md` a *Round 9* section that carries your Invariant 0c
  declaration verbatim (workstreams *Round 9 goal*): you own the desired-velocity layer; above you squad hands down goals
  and a `facing`; below you the plant honours (throttle, turn) with a bounded yaw rate; A7 replaces the additive blend,
  A11 the ring, A1 the fixed cadence, A4 the straight approach. **None of the four adds alongside.**
- **Every A/B this round issues at least one order that carries a `facing`** (a squad hold via `Orders.station`, or a
  `UnitCommand` with `facing` set in the probe) so the arrival path is a live arm by construction. `nav-fight`'s plain
  `move` measures the arc as zero, and zero has been measured twice. Build the three-way gate counter agreed with squad
  in round 8 (**offered / aimed / refused**, refusals by reason) in the same commit.
- Wall-clock: none inside a decision. `dt` is the tick. Neighbours ordered by name. A fixed iteration count everywhere.

### N1. A7 — null-space priority projection. FIRST AS A TABLE, THEN AS CODE

**Replaces:** the additive score in `CombatMotion.choose` (`combat_motion.gd:168–349`: `WEIGHTS`, the penalties, and
`COMMIT_BONUS`), and the PID station override's precedence over avoidance in `Movement.drive` (`movement.gd:483`).
**Pathology:** P1, and the stall case (opposing goals cancelling to zero — round 8's clearest instance is a HOLD that
returns −1 and is never in the commitment path).

**N1a — the priority table, no code (½–1 day).** A section in `_agents/navigation.md`, one row per term in
`CombatMotion.WEIGHTS` and each `PENALTY_*` / leash / commit / hit / beaten / sight check, stating for every one:
*priority level* (safety > weapon-arc/standoff > formation slot > preference) **or** *null-space task* (executed only in
what the higher tasks leave free) **or** *deleted*, and **which lead-approved behaviour it encodes** — standoff and
shoot-and-scoot (round 7: closest approach 3.0 → 27.7 m, shots 29 → 211), commitment (round 7), armour toward threats
and the busy-target flank (X3), the leash (X1), don't-walk-into-a-wall-of-bullets (L2), the dodge (`would_be_hit`). Say
what each becomes for `strafe`, `angle` and `standoff` styles. **Send it to the orchestrator; it goes to combat and feel
for review against N5 (engagement envelope), L2 (suppression) and S4 (the legibility contract, where the A6 motion law
must appear as a priority in this table) before you write a line of A7.** *"Six multiply-adds"* understates the blast
radius: round 7's approved behaviour either survives in this table or quietly does not.

**N1b — A7 in code.** Rank-1 projection per level; no convergence loop; ties by lower index. Keep `--nav-off=a7` in
`OFF_NAMES` from the first commit so the old blend is one flag away for the A/B, and **an arm counter** (`a7_projected`
per tick, per level that was active) so the two arms are distinguishable (lesson 147). Tests first: a case where a
standoff and a slot pull exactly opposite must produce a non-zero velocity; a case where safety alone is active must
produce the same answer as the old blend within 0.1 m/s (regression, not equivalence).
**Falsifier (pre-registered):** zero ticks where a unit with an unreached goal holds |v| < 0.2 m/s with no blocking
geometry (`blocked_by` empty, `blocked_terrain` 0) — read from arena's stall counters in `nav-fight-maps` now,
from A12's displacement efficiency after CP1. **Guard:** shots fired both sides within 15 % per seed (the commitment A/B's
guard), and squad's two behaviour scenarios (fire concentration; the scout's engine-deck hits, 41/23 on `main`) unchanged
— ask squad to run them on your commit rather than inventing a copy.

### N2. A11 — dynamic-window arcs in place of the ring

**Replaces:** `CombatMotion.RING` (`combat_motion.gd:71`) and the `wheels`/`min_cos` chord test (`:191–195`, `:225`) — the
ring scores *directions*, some of which the plant cannot take this tick, which is why a heavy hull picks a heading and
then hunts toward it. **Pathology:** P1, P2.
Score a fixed **9 × 9 lattice of (speed, yaw-rate)** pairs that `TankMotion.step_in_place` can reach this tick from the
live state (`TankMotion.state_of` already carries `yaw_rate`), as constant-curvature arcs over ~2 s, with a
**gear-continuity bonus** priced, not a reversal veto (P3). Fixed grid, row-major, deterministic. Wheels get the lattice
their `min_turn_radius_m` and `hull_turn_rate_deg` admit — *the creep is then a candidate the scorer sees, not a reflex the
plant takes*; whether `WHEEL_CREEP_THROTTLE` survives is a finding, not a decision. A11 consumes A7's priorities: the
lattice is scored per level and projected, never re-summed.
**Falsifier:** angular-acceleration saturation events in close quarters reach **zero**, and steering oscillation −60 %
(A12's signed cusp density and spectral arc length after CP1; `gear_detail` and in-place events until then). **Arm
counter:** `dwa_candidates_reachable` per plan. `--nav-off=a11` restores the ring.

### N3. A1 — event-triggered replanning (a state-error tube, not a rate)

**Replaces:** the fixed `REPATH_SECONDS` 4.0 / off-path 5 m / stalled cadence in `Movement._next_waypoint`
(`movement.gd:1122–1140`) and — by **request to squad** — `TankBrain.MOTION_REPLAN_TICKS` (`tank_brain.gd:196`) and the
incoming-count in its cache key. **Pathology:** P1 — 70 % of churn is re-planning inside one unchanged decision.
When a plan is computed at state *x*, store the radius within which it stays near-optimal; skip replanning while the
integer squared-norm of the state error stays inside it. Contact arrival is an **event**, never gated by the tube.
**Falsifier:** intra-decision re-plan rate **−60 %** (theirs ≥ 80 %), path-tracking error ≤ **0.15 m**, and reaction
latency to a new contact **≤ 2 ticks** (write the latency test first: a contact appears; assert the tick the plan
changes). *If churn falls and latency rises, this is stubbornness wearing a hat and it reverts.* The hold-hysteresis
A/B (churn −6 … −22 %, still a fail) is the cautionary case: **pair the ladder with the behaviour assertion and prefer
the assertion when they disagree** (lesson 150).

### N4. A4 — clothoid primitives with priced cusps, consumed by the arrival arc

**Replaces:** the straight approach in `_approach_gate` (`movement.gd:1076–1103`: a gate 2.5 radii short of the goal
and a straight run onto the heading) and the arc/line joins pure pursuit implies. **Pathology:** P2 and *"manoeuvres
should look intended"*. Not Reeds–Shepp (Part 1 §5: curvature-discontinuous joins are exactly the visible correction he
complains about). Fresnel integrals from a **fixed-size lookup table with fixed-order interpolation**, never a series to
tolerance. Cusps are **priced** (a gear change costs), never prohibited (P3). Consumers: the arrival arc first; A11's arc
chooser second.
**The A/B must carry facings** (N0): a squad hold and a probe move with `facing`; primaries per wheeled type
`net_over_path` ↑ and `oscillating_share` ↓ with the attack-move `progressing` guard (−10 % on ≥ 2 maps fails), exactly as
pre-registered in round 8. **Falsifier:** signed cusp density **< 1.5 per agent-minute with zero unexplained cusps**
(9–19 today, a third unexplained), and peak steering rate never saturates on a nominal traverse.

### N5. A6 as nav executes it — only after S4 is signed

feel authors `_agents/legibility.md`; control and you sign it. Your part: the motion law (a turreted hull fighting off-axis
keeps its nose within ~25° of the ordered corridor tangent; a hull-fixed vehicle bounded forward-oblique) enters **A7's
priority table** as a named level — not as a new additive term. **No motion code for A6 until the page is signed by
all three.** Falsifier (feel's, read from A12): time with velocity opposing the corridor tangent under attack-move
30–36 % → **< 10 %** *without* a fall in exchange ratio.

### Stretch

- The **clearance gap** (round 8 Status *Nav's next work*): `_chord_slack()` from half-LENGTH at corners, and a
  per-hull-class agent radius once scale (CP2) and the baker's ≥ 8 m footprint bug (`algorithms.md`) are understood.
  Coordinate with scale before touching `NAV_AGENT_RADIUS`.
- A `face` order with no recovery under a wheeled hull (unstick runs only for a MOVE).
- The Godot `NavigationAgent3D` avoidance / `avoidance_priority` comparison against our ORCA (`algorithms.md`): make the
  comparison, do not swap.

## How to verify

- `make remote T=check` for every merge candidate; iterate locally with `make test FILTER=…` but **never claim ready from a
  filtered run** (lesson 45). Read the wrapper's `>> remote: make check exited <N>` and the runner's `N passed, M failed`.
- `make remote T="nav-fight-maps FIGHT_BUSY_LEVELS=0"` (4 maps, seed 3, 120 s) is the round-8 baseline instrument;
  `nav-fight-ab AB_OFF=<a7|a11|a1|a4>` for each row, arms read from `NAV_FIGHT_ARM` **plus your row's own arm counter**.
  A run whose arms show the same treatment, or a counter at 0 in both arms, is not a comparison (lesson 147).
- `make remote T=nav-rotation` and look at the frames at the lead's pose (pitch 21°, 49 m, FOV 35); `nav-rotation-numbers
  ROT_CASES=pivot,car,wheel,truck` for the seconds.
- After CP1: `make metrics …` (metrics' target; S3) on the same runs — the falsifier verdicts come from it.
- `_agents/verification.md` names which of your numbers survive builder0's 4 slots and which do not (times do not).
- **Every number carries its commit, its machine, its workload and its sample size.** Ask yourself the sample size before
  the orchestrator has to (lesson 26). Attribute a cost to a mechanism only by removing it (lesson 25).
- Play the default path (`make skirmish`) before reporting anything as shipped (lesson 149).

## Don't touch

- `game/ai/tank_brain.gd`, `game/tactics/**`, `doctrines/` (**squad**) — `MOTION_REPLAN_TICKS`, `COMMIT_BONUS` 1.15 and the
  request `_combat_move` builds are requests to squad, written in Status *and* messaged to the orchestrator.
- `game/ai/gunnery.gd`, `game/combat/`, `game/units/` (**combat**; `hull_size` / `muzzle_height` values are **scale**'s
  this round).
- `game/theme/**` (**feel** — the articulated trailer is theirs, S2), `game/control/`, `game/ui/`, `game/camera/` (**control**).
- `tools/metrics/`, `mk/metrics.mk`, the `check` recipe, `tools/slot.sh` (**metrics**). **One grant runs the other
  way:** no per-tick trajectory log exists anywhere (round 8's JSONs are per-run aggregates), so metrics may add a
  few-line emitter hook — one call per tick into its own `tools/metrics/` writer, behind a flag off by default — in your
  `tests/nav/fight_probe.gd` (workstreams *Who owns what (round 9)*). You review that hook at merge; expect a `git merge
  main` at CP1 to bring it, and emit the log from your A/B runs from then on rather than inventing a second format (S3).
- `tests/baselines/sim_state_hash.txt`: A7/A11/A1/A4 all move the sim; say so in your green report (*"the sim baseline
  moves and is deliberately NOT recorded here"*) and the orchestrator records it (Invariant 2).

## Waiting on the lead

Nothing at start. A7's priority table is reviewed by combat and feel through the orchestrator, not by him. If a row's
falsifier passes but the frames look wrong at his pose, that is his call — send frames, not adjectives.

## Status

_nav worker, round 9, started 2026-09-19 evening on `stream/nav` at `9f864474` (= `main`'s tip; the branch was
fast-forwarded at worktree creation). A baseline `make remote T=check` was started before any edit._

### The plan (written first, N0)

Smallest foundation first, and the brief's order is the order — it was argued in round 8 and adopted in
`workstreams.md` *Round 9 goal*, so it is not re-litigated here.

| # | Item | What it is | Gate |
|---|---|---|---|
| **N0** | ground rules | this plan; the Invariant 0c declaration in `_agents/navigation.md`; **the three-way gate counter** (offered / aimed / refused-by-reason) and **facings in the probe's orders**, in one commit | — |
| **N1a** | A7's priority table | one row per `CombatMotion.WEIGHTS` term and every penalty / leash / commit / hit / beaten / sight check: *priority level* or *null-space task* or *deleted*, and the lead-approved behaviour it encodes | **sent to the orchestrator for combat's and feel's review before any A7 code** |
| **N1b** | A7 in code | rank-1 projection per level, `--nav-off=a7`, arm counter `a7_projected` | tests first |
| **N2** | A11 arcs | 9×9 reachable (speed, yaw-rate) lattice replacing `RING` + the `min_cos` chord test, `--nav-off=a11`, arm counter `dwa_candidates_reachable` | after N1b |
| **N3** | A1 tube | state-error tube replacing `REPATH_SECONDS` / off-path / stalled cadence, `--nav-off=a1`; **latency test written first** | after N2 |
| **N4** | A4 clothoids | Fresnel from a fixed table, priced cusps, consumed by `_approach_gate` then A11, `--nav-off=a4` | after N2 |
| **N5** | A6 as nav executes it | the motion law as a named level in A7's table | **blocked on S4** (`_agents/legibility.md` signed by feel, control, nav) |
| stretch | clearance, `face` recovery, `NavigationAgent3D` comparison | | clearance waits on scale (CP2) |

**Decisions taken where the brief left a choice** (one line each, the worker contract's rule 2):
1. **The gate counter is three-way with reasons, and it lands before A7**, not with it. It is the instrument that
   proved round 8's facing A/B was a positive-control failure; every A/B this round is read through it, so it is
   foundation, not part of a treatment.
2. **Every A/B arm counter is a static `int` on the class that owns the mechanism**, reported by `fight_probe` in the
   `NAV_FIGHT` JSON under `arms`, exactly as `gates_aimed` / `gates_refused` are today. One shape for all four rows
   means the A/B reader is the same code each time (lesson 147).
3. **`--nav-off=<row>` restores the OLD mechanism, never disables the new one into nothing.** A7 off = the additive
   blend; A11 off = the ring; A1 off = the fixed cadence; A4 off = the straight approach. An arm that is "the new
   thing, broken" is not a control.
4. **Provisional until CP1, re-run after CP2.** Every number below carries `provisional (pre-CP1)` until metrics'
   A12 merges, and any size-dependent number is re-measured after scale's roster lands.

### FINDING: the arrival arc fires 5168 times in a fight that used to measure ZERO

**Laptop, `7edec4fb`, `make nav-fight NAV_TIME=45`, yard, seed 3, 34 GREEN units. Provisional (pre-CP1), and the
numbers below are counts of PLAN TICKS, not of orders.**

| | |
|---|---|
| `gates_offered` | **6364** |
| `gates_aimed` | **5168** |
| `gates_refused` | **1196** — `off_mesh` 835, `reached` 312, `on_approach` 49 |
| `facings_issued` / `holds_issued` | 72 / 5 |

Round 8 ran this same instrument on four maps and got **`gates aimed 0, gates refused 0` in both arms of an A/B**,
and could not tell a broken instrument from an inert mechanism. It was the instrument: no order in a CPU fight ever
carried a `facing`. With the probe issuing them, the arrival arc is live, and `offered == aimed + refused` holds
exactly (6364 = 5168 + 1196), which is the counter checking itself.

**The finding inside the finding, and it is nav's to fix, not squad's:** **70% of all refusals are `off_mesh`** — the
gate is placed one approach-length back along the ordered heading and lands inside geometry. squad predicted that
element spacing would refuse most slot gates (`on_approach`); that prediction is **not** what the data shows —
`on_approach` is 49 of 6364, under 1%. The approach length is `clampf(radius × 2.5, 4, 20)` and it is placed without
ever asking whether the ground it lands on exists. **A4 (N4) is the right answer: a clothoid approach curves onto the
heading instead of requiring a straight run backwards into whatever is behind the goal**, and it is now a measured
motivation for that row rather than an inherited one.

**What this does NOT yet say:** whether the arc *helps*. It says the arc executes. The A/B that asks whether
`net_over_path` rises and `oscillating_share` falls is pre-registered in the brief (N4) and runs after CP1, read
through A12.

### Questions for the lead

None yet.

### Requests to other streams

- **squad** (via the orchestrator): nothing yet. `MOTION_REPLAN_TICKS` and the brain's `COMMIT_BONUS` 1.15 become a
  request at **N3**, not before.
- **combat, feel** (via the orchestrator): **N1a's priority table needs your review before A7 is written.** It is the
  point where round 7's approved behaviour (standoff, shoot-and-scoot, commitment, armour toward threats, the leash,
  the dodge, don't-walk-into-a-wall-of-bullets) either survives as a named priority or quietly does not.

### Known issues carried in from round 8

- The clearance gap (`_chord_slack()` uses WIDTH; one `NAV_AGENT_RADIUS` 2.0 for a 5× footprint range) — worse after
  CP2 by construction, and coordinated with scale before `NAV_AGENT_RADIUS` is touched.
- A `face` order has no unstick recovery under a wheeled hull.
- The arrival arc has **never executed in a CPU fight** (`gates aimed 0` in both arms of its round-8 A/B). N0 fixes
  the instrument; whether the arc does anything is then measurable for the first time.
