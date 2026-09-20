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

### REPORT — read this first (nav, round 9, 2026-09-20)

**Nothing nav built this round is on the default path, and that is the report, not an apology.** Two catalogue rows
were built, verified against the plant, measured against pre-registered behaviour scenarios, and left behind their
switches with what they cost written down. `main` takes **no behaviour change** from this branch: the sim baseline
does not move, and the default path reproduces the pristine scenario numbers exactly. That is round 8's shape on
purpose — *three things were built, measured and thrown away, and all three were cheap because they were measured
before shipping.*

| Item | State |
|---|---|
| **N0** ground rules, gate counter, facings in the probe | **done and shipped** — the only behaviour-affecting work that is on by default, and it is instrumentation |
| **N1a** A7's priority table | **done**, reviewed by combat and feel, both reviews folded in, contract **S5** adopted from it |
| **N1b** A7 in code | **built, measured, opt-in.** Waiting on squad's leash commit to re-measure and flip |
| **N2** A11 dynamic window | **built, measured, opt-in.** One open behaviour question (the duel's 6.3 s) |
| **N3** A1 event-triggered replanning | **not started, and deliberately** — see below |
| **N4** A4 clothoids | **not started**; its motivation is now *measured* rather than inherited (70% of gate refusals are `off_mesh`) |
| **N5** A6 | **blocked on S4**: nav has signed, feel authored, control signs with two requirements; its shopping list is collected below |
| stretch: `NavigationAgent3D` vs our ORCA | **done** — compared, not swapped, with the verdict and what would change it |

**Why N3 is not started, on the brief's own reasoning rather than on the clock.** The sequencing argument nav made
and `workstreams.md` adopted says A1 goes third because *"its latency falsifier needs a stable decision layer
underneath it"*, and it is *"the row most likely to look like a win while hiding a regression"*. **A7 and A11 are
both parked pending measurement decisions, so that layer is not stable.** Building A1 on top of two switched-off
rows would mean measuring a cadence against a decision layer that is about to change — which is how round 7 spent a
round measuring a term that was never in the code path. The precondition is a fact about the branch, not a
preference.

**The single most useful measurement of the round**, because it turns a zero into a mechanism: the arrival arc fired
**5168 times** in a 45 s fight where round 8 measured **`gates aimed 0` in both arms of an A/B** and could not tell a
broken instrument from an inert mechanism. **70% of its refusals are `off_mesh`** — the gate lands inside geometry —
which makes A4 (N4) a measured row rather than an inherited one, and disproves squad's round-8 prediction that
element spacing would refuse most slot gates (`on_approach` is 49 of 6364, under 1%).

**What to playtest** (the lead, when any of this is on — none of it is yet): `make skirmish` is unchanged by this
branch. To see A7: `make nav-fight NAV_FLAGS=--nav-off=a7`; A7+A11: `--nav-off=a7,a11`. Both print `NAV_FIGHT_ARM`
with the live treatment and report `arms` counters, so an arm that did not engage says so.

**Merge notes (shared files):** `game/ai/combat_motion.gd`, `game/ai/movement.gd`, `tests/nav/fight_probe.gd`
(metrics' S3 emitter hook is expected here at CP1 — I review it at merge), `_agents/navigation.md`,
`_agents/streams/nav.md`. **No file outside nav's ownership was touched.** `tests/baselines/sim_state_hash.txt` is
deliberately NOT re-recorded: nothing on the default path moves it.

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

### N4 GROUNDWORK, measured: 43% of off-mesh gates have NO straight run-in at any length — that is A4's case

Laptop, `57b8e89b`, `nav-fight` yard seed 3, 45 s, default path (deterministic — `offered` and `aimed` reproduce the
earlier run exactly):

    gates  offered 6364 = aimed 5168 + refused 1196
    refusals    off_mesh 835 (70%), reached 312, on_approach 49
    off_mesh_fit  fits_at_75%: 474      none (not at 75, 50 or 25%): 361

**Two different bugs, and until now they were one number.**

- **474 of 835 (57%) would have fitted with a shorter run-in.** Recoverable cheaply — and *not for free*:
  `APPROACH_RADII` 2.5 was measured, and at **1.5 radii an IFV still arrived 63° off** (dot 0.45). 75% of 2.5 is
  1.875 radii, between the value that works and the value that does not, and **arrival accuracy there is
  unmeasured**. So the cheap fix trades refusals for heading error and needs its own A/B before it ships. It is not
  a free 9% more gates aimed (5168 → 5642); it is a trade whose other side nobody has measured.
- **361 of 835 (43%) fit at NO length tried.** The approach corridor itself is blocked, so **no straight gate can
  fix them at any length** — which is precisely the case a continuous-curvature approach exists for. **This is A4's
  measured motivation**, and it is now a count rather than an argument from first principles.

**What this changes about how N4 should be built:** A4 is not "replace the straight approach because clothoids are
better". It is *"43% of the arrival arc's failures are geometrically unreachable by any straight line, and a curved
approach is the only thing that reaches them"* — with a cheap partial fix available for the other 57% whose cost in
arrival heading has to be measured first, separately, so the two are never credited to each other.

### REQUEST TO SQUAD (2): the combat request needs the hull's live motion state

**Measured, on the A7+A11 arm** (laptop, `d4201b64`, `nav-fight` yard seed 3, 45 s, `--nav-off=a7,a11`):

    arms  a7_projected 3264, a11_lattices 3264, dwa_candidates_reachable 262565,
          a11_with_live_state 0, a7_holds_scored 0, a7_region_rejected 0
    gates offered 6448 = aimed 5226 + refused 1222 (off_mesh 901, reached 277, on_approach 44)

**`a11_with_live_state` is 0**, and the counter exists so that is a number rather than a surprise. `_combat_move`
(`tank_brain.gd:2296`, squad's) builds the request from individual fields, so A11 has to synthesise a motion state —
and the synthesised one has **`yaw_rate` 0**, because nothing in the request carries it. A hull already turning is
therefore given a window as if it were not, which **understates what it can reach** — the same flaw, one level up,
as the one-tick window that offered a tracked hull 21° over a 2 s arc.

**The ask is one line:** `request["motion"] = TankMotion.state_of(tank)`. `state_of` already carries `yaw_rate`
(round 8 put it there), plus braking and grip, which the synthesised state also guesses. A11 reads it when present
and falls back when absent, so this can land whenever squad likes and nothing breaks in between.

**Two other things that run says, both worth knowing before anyone reads a verdict off this arm:**
- **`a7_holds_scored` 0** — no `standoff` hull was inside its hold band while fighting in this seed, so **the hold
  candidate, and with it the commitment-on-a-hold claim, is UNTESTED in this configuration.** It is exercised by the
  unit tests and by `scenario_motion`'s scout, not here. Do not read "commitment now reaches holds" off this run.
- **`a7_region_rejected` 0** — the level-0 task region never engaged, exactly as predicted, because `element_slot()`
  returned null for attacking roles on this tree. squad's leash commit is what turns this counter on, and it is the
  number that will say whether it did.

### CORRECTION from metrics' A12 (2026-09-20): the shuffler is the WHEELED hull, not the LIGHT one

nav has been carrying round 8's *"the scout is the shuffler"* — squad's briefs aim A8/A9 at light hulls on it.
metrics re-ran round 8's exact configuration (yard, GREEN, attack_move, seed 3, 120 s, builder0) on a **Condemned
roster that fields no scout at all** and reproduced the same shape:

| unit | units | eff_mean | eff_p10 | oscillating | cusps/agent-min |
|---|---|---|---|---|---|
| ifv | 7 | 0.624 | 0.250 | 12.1 % | 35.8 |
| lancer | 6 | 0.619 | 0.216 | 9.4 % | 34.8 |
| tank | 21 | 0.798 | 0.388 | 4.9 % | 7.4 |

**It is a locomotion property, not a unit property.** That is the axis A11's lattice already splits on — a car's yaw
is `|speed| / radius`, a tracked hull's is a ramped rate — so the mechanism was aimed correctly by accident and the
description was wrong.

**And the number A11 is actually for: 56 % of all reversals are the wheeled creep** (665 creep / 234 ordered / 293
unexplained of 1192 cusps; `tank` produces **zero** creep cusps). Cusp density reads the *motion*, so it names flips
round 8's gear-flip counter had to call unexplained — P2's "unexplained third" is now about a quarter.
**A11 makes the creep a scored candidate rather than a plant reflex, so this is the number that should move**, and
whether `WHEEL_CREEP_THROTTLE` survives is a finding rather than a decision.

**Three instructions from metrics about how to read any of this, taken as instructions:**
1. **Pre-register on the p10 of windowed efficiency, not the threshold share** — the old threshold understates the
   problem ~4×.
2. **Never pre-register a bar on "units that ever oscillated"** — it moves by ±1 with a ±1 window-length change while
   the share stays put. The oscillating *share* is robust (metrics' tool and nav's own counter agree to 0.05 pp).
3. **Station-holding windows are refused, not scored** — 27,500 of them; folding them in at 1.0 or 0.0 would move an
   army-level mean more than the pathology does.

### N2: A11 is BUILT, MEASURED, and NOT SHIPPED ON either

**`--nav-off=a11` turns A11 ON, inside A7's chooser (itself opt-in). The default path is untouched.** The lattice is
generated in command space and evaluated through `TankMotion`, so **nothing in A11 models the plant and nothing in
A11 can drift from it** — five tests drive the plant itself and agree with every cell to 1e-4.

| | A7 | A7 + A11 | pristine `9f864474` |
|---|---|---|---|
| scout standoff: closest / in-band / nose-on / shots | 22.7 / 0.92 / 0.92 / 225 | **25.5 / 0.93 / 0.92 / 227** | 26.9 / 0.92 / 0.91 / 226 |
| slot drift / shots | 42.1 m / 5 | **38.7 m / 6** | blend 15.4 / 10 |
| turreted duel, front hits | 100% / 100% over 20 s | **67% over 6.3 s** ✗ | 100% / 80% |

**The open question, stated as the number that matters:** the duel's bar is ≥ 80% and A11 reads 67% — on **three
hits**. The real finding is that **the fight ends at 6.3 s of a 20 s scenario** with both hulls moving markedly more
(0.77/0.76 against 0.67/0.73). Arc candidates make two tanks close and settle a duel three times faster. **First
thing to look at when A11 resumes.** It is a behaviour question, not a tolerance, and I did not tune it away.

**Two things building it taught the layer, both in `navigation.md`:** the wheeled creep hijacks the throttle, so a
hand-written inverse of the plant cannot see it (the first lattice promised 3.53 m/s and the plant delivered 4.30);
and **the window is over the CONTROL PERIOD, not one tick** — a one-tick window offered a tracked hull 21° of heading
change over a 2 s arc when it can swing 160°.

### ⚠ N1b: A7 is BUILT, MEASURED, and NOT SHIPPED ON — the headline, so nobody reads past it

**`--nav-off=a7` turns A7 ON. The default is the additive blend, and the default path reproduces the pristine
numbers exactly, so the sim baseline does not move and `main` takes no behaviour change from this.**

A7 fails one pre-registered behaviour scenario and passes everything else, and the rule when a ladder and a
behaviour assertion disagree is to believe the behaviour assertion (lesson 150):

| `scenario_elements::test_a_unit_fighting_from_a_formation_slot_stays_in_it` | blend | A7 |
|---|---|---|
| in-slot drift (bar ≤ 16 m) | **15.4 m** | **42.1 m** ✗ |
| in-slot shots (bar ≥ 6) | **10** | **5** ✗ |

**Passing on A7:** six A7 unit tests; all four `scenario_motion` scenarios including both of combat's pre-registered
ones — scout standoff **22.7 m / 0.92 / 0.92 / 225 shots** (pristine `9f864474`: 26.9 / 0.92 / 0.91 / 226) and the
turreted duel, the armour demotion's falsifier, **front hits 100% / 100%** (pristine 100% / 80%).

**Cause, localised by switching each level off in turn rather than guessed: level 2.** Weapon level inactive → drift
back to 16.3 m; level 3 inactive → still 37.6 m. Strict *weapon above formation* makes a unit hold its band around
the enemy, and holding a band around an enemy is what takes it out of its slot. The blend compromised by accident.

**REQUEST TO SQUAD, and it is the thing that unblocks A7: should an attacking element's members carry a leash?**
`TankBrain.element_slot()` returns null for the `bound` and `maneuver` roles, so an attacking element's members
arrive here with **no leash**, and level 0 therefore has no task region to state. The ruled fix for exactly this
failure — the leash as a level-0 feasibility bound — is implemented and correct and simply never engages. Under the
blend the answer did not matter because `WEIGHTS["range"]` and `continuity` compromised by accident; under A7 it
decides the behaviour. **nav has not tuned a tolerance to make the scenario green, and will not.**

### N1b: A7 in code — what landed, and the three things a reviewer should check

`CombatMotion.choose()` now dispatches: `choose_projected()` (A7) or `choose_blended()` (**the round 3–8 additive
score, kept whole** — a control that is also rewritten is not a control). `--nav-off=a7` selects the blend.

**The shape.** A tolerance-banded lexicographic filter over candidates — the discrete form of null-space projection,
because our candidate set is finite (the ring today, A11's lattice at N2). Level 0 feasibility, then SURVIVAL,
WEAPON, ARC/ARMOUR, FORMATION, PREFERENCE; each level keeps everything within `TOLERANCE[level]` of its own best and
hands that set down. `TOLERANCE` **is** the null space: `{survival: 0.0, weapon: 0.15, arc: 0.25, formation: 0.2}`.

**Three things that are easy to get wrong and were done deliberately:**

1. **The hold is a candidate, not an early exit — and it carries `index = -1`, so the commitment term matches it.**
   Round 8's clearest finding was that `COMMIT_BONUS` had *never executed*, because a hold returned before the ring
   was scored. `a7_holds_scored` and `a7_holds_won` report it, so "it is reachable now" is a number rather than a
   claim (combat's condition).
2. **combat's blocking objection is answered by a statement, not a constant:** for `standoff`, level 5's `tangent`
   and `side` apply only while the weapon level is UNSATISFIED. A fixed gun's nose is its aim; in band, tangential
   motion costs the shot. "Slide when rounds are incoming" still happens, because level 1 filters first.
3. **The leash binds at level 0 for a leashed unit, and needs no new request field.** squad established that
   `TankBrain.element_slot()` returns null for the `bound` and `maneuver` roles, so **a leash in the request already
   means "you were given a position to fight from"**. The radius used is the one that ARRIVES (squad derives it per
   formation from member hulls), never `SLOT_LEASH` read as a constant. It binds only a unit currently inside its
   leash: if every candidate is outside, level 0's release drops the bound and level 4's soft term pulls the unit
   back — which is X1's *"pulled back rather than frozen"* falling out of the structure instead of being special-cased.

**The defect A7's own falsifier test found, twice — and it is the round's most transferable lesson** (recorded as
orchestration lesson 153): **a term that merely SATURATES as one addend among many goes BLIND when it is promoted to
a priority level, because inside a level a cost only ever competes with itself.**

- `PENALTY_LEASH` clamps at `LEASH_FALLOFF` (10 m) past the slot radius. As a penalty that was harmless — other terms
  still separated the candidates. As level 4 it is fatal: a unit 36 m outside its slot has **every** candidate clamped
  to 1.0, the level ranks nothing, hands a fully-tied set down, and level 5 keeps the unit exactly where it is.
  **That is the stall A7 exists to make impossible, reappearing inside the fix.** Caught by
  `test_a_gun_held_outside_its_slot_slides_back_into_it_instead_of_standing_still`, which was written before the code.
- `_band()` floors at 0 twelve metres below the band and twenty above, so a unit 60 m from its target would have every
  candidate tied at the maximum band cost — **no pressure to close, on the level whose entire job is the radial
  component.** Found by re-auditing the other levels for the same shape rather than by a failing test, and then given
  one (`test_a_gun_far_outside_its_band_still_closes_on_the_target`).

Both are now uncapped and monotone over the whole range they can see, keeping the blend's scales (leash in
`LEASH_FALLOFF` units with crowding quoted in the same currency at `PENALTY_CROWD / PENALTY_LEASH`; the band at 12 m
below / 20 m above). Level 1 is binary and dictatorial by design, and level 3's `1 − front` cannot saturate.

**Pre-registered acceptance, to be reported before/after with the hash** (combat's and squad's baselines, pristine
`9f864474`, laptop): `scenario_motion::test_a_scout_holds_a_firing_position_instead_of_ramming` — 26.9 m closest,
0.92 in-band, 0.91 nose-on, 226 shots; `scenario_motion::test_two_tanks_duel_on_the_move_front_armor_first` — front
hits 100% (a6) / 80% (x3), which is **the honest falsifier for the armour demotion** (all three scouts are
`mount: "fixed"` → `standoff`, so the engine-deck scenario cannot reach it);
`scenario_elements::test_the_base_of_fire_keeps_firing_while_the_others_move` — base shots 5 then 4, through a
friend 0.

**What A7 does NOT do:** it does not touch `RING` or the `min_cos` chord test (A11's, at N2), it does not touch
`run` (the A/B control for round 7's standoff), and it does not change `COMMIT_BONUS`'s value — combat's A2 replaces
that expression at level 5 under contract S5.

### For control and metrics (T1/CP3): a wall-clock-bounded test that already flakes under load

`test_control_facing_camera::test_the_camera_turns_to_face_where_the_selection_faces` **fails about 1 run in 3 on
the laptop under load, at the branch point as well as on this branch** — measured, three runs at `9f864474`:
pass / pass / **fail**. It is green on builder0 (1261 passed, 0 failed) and green on a quiet laptop.

The mechanism is in the test, not in nav: it waits `Time.get_ticks_msec() + 3000` while spinning on
`tree.process_frame`, so how far the camera turns depends on **how many frames a loaded machine delivers in three
wall-clock seconds**. It is control's test and control's harness; nav is reporting it, not fixing it.

**Why it matters beyond one test: T1 parallelises `check`.** `workstreams.md` already warns that *"determinism is
safe; TIMING is not"* — this is a concrete instance waiting for that change, and a faster check that flakes once is
worse than a slow one, because a flake costs a re-run plus a false investigation. It cost exactly that here.

**And the lesson nav paid for it, which is lesson 26 in a new place:** nav concluded *"my branch broke it"* from
**one** passing run at the branch point against two failing runs on the branch. Three runs at the branch point
overturned it. **A one-run control is not a control**, and the rule about stating the sample size applies to the
runs you use to rule something out, not only to the numbers you publish.

### N5's shopping list, collected from the S4 signatures (build it all in one commit, after control's hash)

Nothing of A6 is in code and nothing will be until the page carries three signatures. nav has signed; control has
signed with two requirements; feel authored it. **These four are one commit, because three of them are only
checkable with the fourth:**

1. **The corridor tangent, published by nav** (`Movement.reading()`). `path_points` is already sliced from
   `_path_index`, so `path_points[0]` IS the next waypoint and the current leg runs from the hull's projection onto
   it — but one publisher should mean one *interpretation*, not one array three streams each project onto slightly
   differently.
2. **`"legibility": {"active": bool, "why": StringName}`** in `Movement.state(unit)`, `why` from a closed set
   (`band`, `survival`, `armour`, …) naming **which level took the nose**. control will not infer cause from geometry
   and will not build its readout without it. nav owns the level order, so nav owns this answer — nobody else can
   produce it without re-deriving A7's filter.
3. **The inactive flag and its reason** (feel's §5): no order, `phase == "blocked"`, no path yet, a reflex owning the
   heading, or `run` style. The falsifier is computed over active ticks only with the active fraction beside it —
   *a number that improves because the law switched itself off more often is not a pass*, which is round 8's
   `gates aimed 0` in a new place.
4. **⚠ The arrival arc's ticks must be flagged ORDERED, not off-corridor.** A wheeled hull under an ordered `facing`
   drives the last leg along that heading, so it is off-corridor **by construction** at the end of every dragged
   move. That is obedience, not the pathology, and A12 must not charge it to A6's off-corridor fraction. nav's
   trajectory emitter flags those ticks (arc active + facing ordered); the orchestrator has told metrics the same.

**Sequencing:** control's desktop right-drag facing merges alone as **CP2c** and control will send the hash. **No
arrival-arc A/B before it** — a facing enters a move from one place today and the lead never runs it (lesson 149).

### Questions for the lead

**None.** Nothing this round reached a point where his judgement was the missing input: both rows failed a behaviour
scenario, and a failing behaviour scenario is an engineering answer, not a taste question. The moment either row is
on by default and the frames look wrong at his pose, that is his call and he gets frames, not adjectives.

### Requests to other streams (all live; status as of 2026-09-20)

| To | Request | State |
|---|---|---|
| **squad** | **Do attacking-element members carry a leash?** A7's level-0 task region cannot engage without one. | **ANSWERED — yes.** `6e0c9968` on `stream/squad` (leash only, check running). nav cherry-picks that one commit for measurement, does not ship it. |
| **squad** | `request["motion"] = TankMotion.state_of(tank)` in `_combat_move` — A11 needs the hull's live `yaw_rate` or it builds the window as if a turning hull were at rest (`a11_with_live_state` is **0** today). | **DONE**, deliberately in squad's *second* commit so the leash A/B has one variable. |
| **squad** | Pre-`standable` slot positions, to split nav's 70% `off_mesh` gate refusals into "always in geometry" and "your push moved it". | **DONE** — `Element.state()["slots_asked"]`, squad's second commit. |
| **combat** | Review A7's priority table; run `scenario_motion`'s two on nav's real commit. | **DONE** — review folded in; contract **S5** adopted (`seconds_for()` not `penalty()`, no stance floor, no lay term, a price with a ceiling, never a veto). |
| **feel** | Review A6's place in the table. | **DONE** — level 3 confirmed; feel's one change (level 3's null space is *speed alone*; A6-b claims the sign of the arc) accepted and it is the right call. **nav has signed `legibility.md`.** |
| **metrics** | — | Format frozen; nav's probe already emits `facing`, the key A12 reads. Three instructions taken: pre-register on **p10**, never on "units that ever oscillated", station-holding windows refused not scored. |
| **control** | — | Right-drag facing merges alone as **CP2c**; **no arrival-arc A/B before it** (lesson 149). control signs S4 with two requirements, both in *N5's shopping list*. |
| **scale** | Nothing until CP2. nav publishes no size-dependent number and touches `NAV_AGENT_RADIUS` only in coordination. | — |

### Next steps, in order, for whoever picks this up

1. **squad's `6e0c9968` is green → cherry-pick it for measurement only**, re-run the drift scenario on the
   **`--nav-off=a7`** arm (not `a7,a11` — A11 moves that number too, 42.1 → 38.7, and the leash must be the only
   variable). Report drift, shots, the leash radius **as it arrived in the request**, and `a7_region_rejected`.
   **If that counter is 0, report no drift number at all** — the region did not engage and anything that moved was
   something else. If it passes, flip A7's default in a commit naming both hashes.
2. **A11's open question: the duel ends at 6.3 s of 20.** Front hits 67% on a three-hit sample is not the finding;
   the fight finishing three times faster, with both hulls moving markedly more, is. Behaviour question, not a
   tolerance.
3. **N3 (A1) only after 1 and 2** — its own adopted sequencing says it needs a stable decision layer beneath it.
4. **N4 (A4)** — motivation now measured, not inherited: 70% of gate refusals are `off_mesh`, and the diagnostic
   splits them **474 recoverable by a shorter run-in / 361 reachable by no straight line at any length**.
   **⚠ The positive control is pre-registered by the orchestrator and it is the whole point:** report how many of
   **exactly those 361** the clothoid reaches, **not** the aggregate `aimed` count — otherwise the 474 leak into the
   number and the cheap fix takes credit for the expensive one's territory. The two are A/B'd separately and never
   shipped together.
5. **N5 (A6)** after control's CP2c hash: build the corridor publisher, `legibility: {active, why}`, the inactive
   flag and the arc's `facing_ordered` tick flag **in one commit**, because three are only checkable with the fourth.

### Known issues carried in from round 8, and their state now

- **The clearance gap** (`_chord_slack()` uses hull WIDTH; one `NAV_AGENT_RADIUS` 2.0 for a 5× footprint range).
  Untouched, worse after CP2 by construction. squad now has a placeholder (`SlotGround.corridor_width`) waiting to be
  deleted against a real clearance in `Movement.state()`; nav owes that **after CP2**, because any width measured
  against a roster about to change has to be retaken.
- **A `face` order has no unstick recovery under a wheeled hull.** Untouched.
- ~~The arrival arc has never executed in a CPU fight.~~ **CLOSED.** It fires 5168 times in 45 s on yard; the
  instrument was the bug, not the mechanism. What replaces it as an open issue: **70% of its refusals are
  `off_mesh`**, which is N4's.
- **New, and nav's own:** `a7_holds_scored` is 0 in a CPU fight, so *"commitment now reaches a hold"* is proven by
  unit tests and `scenario_motion`'s scout and **not** by a fight. Do not cite a fight run for it.
