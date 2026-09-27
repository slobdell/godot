# Stream: nav (the War Rig's refused back-ups)

> Read [`navigation.md`](../navigation.md) first (the planned reverse, the drive test, the counters, the noise note),
> then [`algorithms.md`](../algorithms.md) (what was parked and why), [`game_design.md`](../game_design.md) *Round 11
> direction* (*The 2-part problem he suspects in the Terminus*) and *Round 12 direction*; [`workstreams.md`](../workstreams.md)
> (round 12: ownership, CP2, C12.6; the round-6 N1 contract; Invariant 2 on the sim baseline). The archived
> `archive/round11/nav.md` is the round that built the planned reverse — read its Status for the measurement method.
> **You own** `game/ai/movement.gd`, `pathing.gd`, `steering.gd`, `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`,
> `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`, `_agents/algorithms.md`.

## The lead's direction

Round 11 (2026-09-23): the Terminus drive — hulls reversing *before* they touch a wall was his acceptance test, and it
shipped. Round 12 (2026-09-26): the War Rig's refused back-ups were on the list he approved for this round. His
standing words on the rig: it stays 14 m (ruled twice); *"a 4s slower march for a tidier traversal is better, yes."*

## Where things stand (`navigation.md`; re-verify on today's `main`)

- **The planned reverse (round 11):** a wheeled hull whose steering point is > 45° off the nose sweeps its full-lock
  forward arc against the navmesh with its LEADING end; if that would hit, it searches the reverse arc with its
  TRAILING end and, finding one, drives it as a leg with its own completion (distance, a rear contact, or a timeout).
  Nothing found → `kturn_none`, and the reactive rules (1 s no motion, 1 s wall contact) stand as before.
- **Measured (builder0, `38c385d5`, 8 seeds × 2 squads per arm, planned reverse off → on):** mixed squad arrivals
  170 → 177 of 192, press/unstick-driven contacts 88 → 1, reverse-gear contacts 671 → 206, cusps 2260 → 1978; **War
  Rigs** arrivals 99 → 104 of 128, contacts 9678 → 6917, press/unstick 393 → 227, reverse-gear 2240 → 946, cusps
  1585 → 1202. **The rigs' `kturn_none` (130) exceeds their `kturns` (64): a single back-up rarely clears a 14 m hull's
  arc in these streets.** That is the round's one measured sign that a longer search or a kinematic planner would earn
  its keep — and the honest answer to "is the planned reverse enough".
- **Noise:** the rig drive is chaotic (one change touching a handful of legs moved one seed's total contacts
  1002 → 3163 on the laptop). Read the NAMED numbers (press/unstick-driven, reverse-gear contacts, `kturn_none`,
  `kturns`, arrivals), take 8+ seeds per arm, compare arms on the same seeds.
- **Counters live in `movement.gd`** (`kturns`, `kturn_none`, `kturn_aborted`, `kturn_ticks`, `circle_reverse_ticks`,
  `by_gear`), published through `Movement.state()` and `make nav-terminus-drive`'s `NAV_DRIVE` lines.
- **Geometry:** the rig is 3.32 × 14.00 m with a 12 m minimum turning radius; the Terminus streets are 18–22 m
  physical (round 10's R4 bar is ≥ 12.14 m physical for the widest hull). A hull that long with that radius in that
  street has, by the current search, often no valid 8 m back-up.
- **What exists to build on:** `Clothoid` (round 9's A4: continuous-curvature primitives; its header says why
  Reeds–Shepp was parked), the navmesh sweep used by the planned reverse, `TankMotion.predict`, the drive test's
  paired-seed harness with a seed knob that moves spawn order, `make nav-sim-arms` for attributing a baseline move.
- **Sim baseline:** the planned reverse moved it (`457b5e83 → bdb21d20 → 814aed46`, attributed by arm). Anything that
  changes WHEN or HOW a hull reverses will move it again (CP2).

## Backlog (in order)

**N1. Why 130.** Instrument before designing: for every `kturn_none` on the rig drive (8 seeds, both squads), log the
geometry the search saw — clearance ahead, the arc it swept, the reverse arcs it tried and what each hit (a wall, a
friend, the mesh edge), the street width there, the hull's heading against the street. Bucket them: no reverse arc of
ANY length clears (the street is too narrow for one back-up), a shorter back-up would have cleared (the 8 m leg is too
long), a friend was in the way (a squad problem, not a planner's), the hull was already pressed to a wall (a recovery
case). Publish the buckets in Status with counts. The design depends on which bucket is big; write the pre-registered
signature for each candidate fix before N2.

**N2. A multi-leg plan.** For the bucket the data names — most likely "no single back-up clears": a **back-and-fill**
(reverse arc one way, forward arc the other, reverse again: a two- or three-cusp manoeuvre), each leg validated against
the navmesh with the END that leads it (rear on reverse, nose on forward), planned once when the single reverse fails,
driven as legs with their own completion like round 11's, abandoned (and counted: `kturn_aborted`) on a contact. If
`Clothoid` gives you the arcs, use it; if the honest primitive is Reeds–Shepp for this hull class, say so in
`algorithms.md` with the reason the round-9 parking no longer holds. **Name what it replaces** (Invariant 0c): the
single planned reverse's "nothing found" branch, and nothing else — the reactive rules stay as the last net.
Pre-register: `kturn_none` falls, `kturns` (or a new `kturn_multi` counter) rises by about the same, press/unstick
contacts do not rise, arrivals do not fall; the mixed squad is a null control (its `kturn_none` is small — state it).

**N3. Measure it the way round 11 did.** `make nav-terminus-drive` over 8+ seeds × both squads, both arms from ONE
build behind a `--nav-off=` name (the arm proves it is live with a counter), same seeds, discordant pairs; the named
numbers with commit and machine. Then `make remote T=nav-wall-clip` (his camera, both arms) and LOOK: a rig doing a
three-point turn in a street should read as a driver, not a robot (round 7's pre-registered "robotic" tests in
`make nav-rotation` are the bar).

**N4. Attribute the baseline move (CP2).** `make nav-sim-arms` with your arm in `SIM_ARMS`; declare the move in your
green report; the orchestrator records it alone. If the baseline does NOT move, that is a finding too (the baseline
match may never field a rig in a street) — say so.

**N5 (stretch). The planner the count is asking for.** If N1 shows a large "no manoeuvre of this family clears" bucket,
write the case for a kinematic planner (state lattice or Reeds–Shepp over the navmesh for the rig class only) in
`algorithms.md`: the cost, what it replaces, its falsifier. Build a prototype only if the arithmetic says the drive test
would show it; otherwise the write-up is the deliverable.

## How to verify

- `make remote T=check` green on every named commit; `tests/nav/` extended with a unit test that a planned multi-leg
  manoeuvre clears a pinch a single reverse cannot (mutation-checked: fails with the multi-leg branch disabled).
- `make nav-terminus-drive DRIVE_SEEDS="1 2 3 4 5 6 7 8"` both arms; `make nav-fight-maps` on the rotation as the
  regression net (arrivals and stall counters on every dealt map, both arms); `make remote T=nav-wall-clip`.
- Every number: commit, machine, seeds, squad, arm. The laptop is ~2.75× slower and its rig numbers are noisy: measure
  on builder0.

## Don't touch

`game/tactics/**`, `game/ai/{squad,tank_brain,element_feed,formations}.gd` (squad's); `game/control/**`; `game/arena/**`
and the navmesh bake parameters (arena's — if the bake radius is the real problem, write the request in Status);
`game/units/units.gd` (the rig stays 14 m, 12 m radius: ruled); `game/camera/**`.

## Waiting on the lead

Nothing. N5 is a write-up unless the numbers say otherwise.

## Status

_Worker: nav, round 12. Started 2026-09-26 21:15 from `46bac1a3` (code = `0299e05e`). Every number names its commit and
machine. **Merge point: see "Green hash" at the end** (none yet)._

### Plan (the brief's order)

| # | item | state |
|---|---|---|
| 0 | green start: `make remote T=check` on `46bac1a3` | queued on builder0 (three other streams' checks held every slot at launch) |
| N1 | log every `kturn_none` (`--kturn-log`), bucket it | **done on the laptop** (below); builder0 re-run owed |
| N2 | the back-and-fill for the bucket the data names | built, `tests/nav/test_nav_back_and_fill.gd` (mutation-checked); measuring |
| N3 | drive test both arms, 8 seeds, builder0; `nav-wall-clip` looked at | `make nav-drive-ab` + `tests/nav/drive_table.py` built for it |
| N4 | `make nav-sim-arms` with the arm | after N3 |
| N5 | the planner write-up in `algorithms.md` | stretch |

### N1: why the rigs refuse (laptop, `54f39923` + the leg stamp, `make nav-kturn-buckets`, 8 seeds; builder0 re-run owed)

The run reproduces round 11's shape: **rigs 132 refusals against 78 single legs** (builder0 `38c385d5`: 130 / 64);
mixed 24 / 65. Repeatable: the same 132 rows on two runs. Buckets for the rigs, first match wins:

| bucket | n | what it is | a longer single back-up clears | a <=3-leg fill (0.75 m margin) | a fill of any length <=16 legs (0.25 m margin) |
|---|---|---|---|---|---|
| steering point < 7 m (a route corner beside the hull; the goal is 20-80 m away in ALL 36) | 36 | the search is asked about a point inside the turning circle: no forward arc ever lines up | 1 | 4 | 17 |
| pressed (outline already deeper than the clear reach) | 35 | a recovery case | 3 | 4 | (in the 77) |
| no room (back-up blocked within 1 m) | 13 | nothing behind | 0 | 0 | |
| cap (8 m run, never clear) | 5 | the 8 m cap | **5** | 5 | |
| short room (blocked 1-8 m, never clear) | 43 | the street is too narrow for ONE back-up | 0 | 7 | |
| **all** | **132** | | 9 | 20 | **77** (29 need <=3 legs, 39 <=5, 57 <=8) |

- **Friends: 12 of 132 have a friend in the box the back-up sweeps; none is caused by one** — the search reads the
  navmesh only, so a friend cannot make a refusal (it can abort a leg).
- **"A shorter back-up would have cleared": 0 by construction** — the search is shortest-first.
- **Where:** 74 on the plaza leg, 44 on the first leg; **90 of 132 within the first 10 s of a leg**: a rig parked by the
  previous leg, handed a point 60-120 deg off its nose. The single back-up is stopped by the REAR CORNER in 84 of 123.
- **Street width at the refusal: median 21-22 m physical** (the narrowest of four spans through the centre, + 2 × bake
  radius). A 14.4 m hull diagonal in 21 m: every leg is 1-2 m, and 1 m of travel yaws a 12 m-radius hull 4.8 deg.
- **The mixed squad is NOT a null control for the fill:** 17 of its 24 refusals have a plan (all <=3 legs; artillery at
  the west street's mouth, 10 m back-ups). State it before measuring rather than discover it.

**Answer to the brief's question:** the big bucket is "no single back-up clears" (short room + no room + cap = 61, plus
35 pressed), as it guessed — but a THREE-point back-and-fill clears only 20-29 of 132. The manoeuvre that exists is
usually a 3-8-leg shuffle of ~10 m total (median). 55 of 132 have no manoeuvre of this family at all: that is N5's
count. And 36 are a different defect: the search aims at a route corner under the hull.

### Pre-registration (written 2026-09-26 ~22:15, BEFORE any drive result with the fill on)

Candidates and their signatures (rigs unless stated; laptop numbers are the base, builder0 re-measures both arms):

- **(a) back-and-fill, <=5 legs, 0.25 m margin, 0.5 m min leg — BUILT (N2), switch `--nav-off=kturnfill`.** N1 says it
  plans 39 of the 132. Expect: `kturn_none` 132 -> <= 105 (a refusal repeats about twice per episode, and a plan
  changes what follows, so not the full 39); `kturn_multi` >= 20; press/unstick-driven contacts NOT up (> +10 % of
  475 is a fail); reverse-gear contacts not up > 10 %; arrivals not down (>= 107/128); `kturn_aborted` small beside
  `kturn_multi` (< 1/3, else the plan's margins are too tight for the plant). Mixed: `kturn_none` 24 -> <= 12,
  `kturn_multi` >= 5, arrivals not down. **Wrong on any of these is reported as measured.**
- **(b) the steering point for the search is at least a lookahead (1.2 R) along the route** (not built). Signature:
  the 36 near-point refusals move into the other buckets or vanish; no effect on the mixed squad (2 rows).
- **(c) a kinematic planner** (N5): the 55 with no manoeuvre of this family. Written up, not built, unless (a)+(b)
  leave the rigs' arrivals short.

### Decisions (one line each)

- **The back-and-fill keeps ONE lock on every leg.** The plant yaws a wheeled hull the way of `turn` in either gear
  (`TankMotion.step`, wheels: *"`turn` is the way the HULL should yaw in either gear"*), so a three-point turn is the
  same `turn` with the gear alternating, exactly as a driver's forward-left / reverse-right. The search is over leg
  LENGTHS and first gear only, which is why it is cheap enough to run in the driver.
- **N1 runs the N2 candidate as a diagnostic** (`_plan_fill`, both first gears, up to five legs) at every refusal, so the
  buckets say directly whether the proposed fix would have found a plan, before any of it drives a hull.
- **Exploration on the laptop, published numbers from builder0.** At launch both machines were saturated (builder0: three
  checks in all three slots; the laptop: two local slots held by other streams), and a rig drive run is ~20 s of laptop
  CPU. Every laptop number below says so; nothing laptop-measured is compared with a builder0 number.
