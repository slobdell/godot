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

**N6 (added 2026-09-26 late by the orchestrator, from squad's S6 measurement). A no-pivot hull's turn-in-place does
not walk it off its spot.** After arrival, scouts (wheeled, fixed gun) get idle `face` orders with no enemy in sight, and
`TankMotion`'s multi-point turn (the creep) walks them 1.5 m -> 8.6 m off their slot over 15 s at 2.8 m/s — most of the
mixed squad's 30 s stop time (squad.md Status on `stream/squad`). The orchestrator's ruling: nav owns the bound (N1's
guarantee: a hull that has arrived stays arrived), as its own commit behind `--nav-off`, pre-registered as a baseline
move under CP2 if the baseline match ever multi-point-turns a scout, measured with `make squad-settle
UNITS=scout:scout:ifv:ifv:tank` both arms, same seeds. squad keeps its half (dropping the idle face) as a candidate to
measure AFTER nav's lands.

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
machine. **Merge point: `5b5e3a6a`** (see "Green hash")._

### Green hash

**`5b5e3a6a` is green, merge here** (builder0, 2026-09-27): `>> remote: make check exited 2` with **1748 passed, 0
failed**; the two reds are (1) **sim-baseline MOVED `01ab39b592cc9837 -> 6313a38d7ecd99bb`, the declared CP2 move**
(causes: the steering-guard fix and blockreach; `make nav-sim-arms` on `5b5e3a6a`: HEAD `6313a38d…`, `--nav-off=guardnear`
`8c10f21d…`, `--nav-off=blockreach` `3db293a3…`, `kturnfill` / `creepbound` / `kturnslide` off: unchanged, all five off
`01ab39b5…`) and (2) `scenario_perf`'s CPU budget under load (29.8 s; accepted by the orchestrator as load this round).
It carries main `9afb507f`. Commits after it are documentation and measurement records only (`_agents/`).
**Merge it alone and record the baseline twice (CP2).**

### Report in one screen

- **N1, why the rig refused:** every refusal logged with what the search saw (`make nav-kturn-buckets`). Builder0
  reproduces round 11 exactly (130 refusals). Most are a 14 m rig lying across a ~21 m street at the START of a leg,
  its rear corner blocking the back-up; 40 are the search aiming at a route corner under the hull. A three-point turn
  would clear 26 of 130, five points 39, sixteen 78; 52 have no manoeuvre of this family at all.
- **N2, the back-and-fill** (`_plan_fill`, `--nav-off=kturnfill`): up to five legs on one lock, each validated with
  the whole outline against the navmesh, driven as legs. On its own it takes the rigs' refusals 130 -> 70 and their
  press/unstick-driven contacts 227 -> 95, and does not move the sim baseline.
- **Found tracing it, and fixed:** the steering guard handed back the route vertex UNDER a hull (a rig sat 80 s at
  zero throttle); a stalled hull could not see a 14 m friend ahead of it (8 m centre-to-centre reach), so rigs pushed
  into a parked friend's tail for whole legs — the rigs' largest arrival loss; a planned leg aborted on ANY contact at
  its leading end, including a face it was sliding along.
- **N6 (added by the orchestrator from squad):** an arrived wheeled hull's turn-in-place no longer walks it off its
  spot (scout 1.5 -> 8.6 m before; bounded at its settle radius now). Mixed squad all-stopped 18.9 -> 12.1 s (laptop).
- **HEAD against round 11 (builder0, 8 seeds x 2 squads):** rigs arrivals **104 -> 115**/128, refusals **130 -> 56**,
  press/unstick contacts **227 -> 83**; mixed **172 -> 179**/192, press/unstick **170 -> 60**. **Cost:** rigs'
  reverse-gear contacts +57 % (a rig giving way backs into walls: round 6's yield spots are sized for small hulls).
- **N5:** the kinematic planner is written up, not built: refusals barely cost arrivals now (1 of 21 refusing
  crew-legs missed), so the drive test could not show it (`algorithms.md`).
- **CP2:** sim baseline `01ab39b592cc9837 -> 6313a38d7ecd99bb`, two causes (the guard fix, blockreach), attributed
  with `make nav-sim-arms`; the orchestrator records it alone.

### What to playtest (exact commands)

- `make skirmish` on the Terminus with the Condemned: a War Rig squad (number key), ordered back the way it came and
  round the plaza's corners. Expect five-point shuffles where it used to bump; rigs no longer sit nose-to-tail pushing.
- `make nav-rig-clip` (display; builder0: `make remote T=nav-rig-clip`) — the rig case at his pose, both arms ->
  `build/nav-rig-clip/rigfill_{off,on}.mp4`.
- `make nav-drive-arms DRIVE_SEEDS="1 2 3 4 5 6 7 8"` (default arms: fill off/on) and `make nav-kturn-buckets`.
- Every mechanism is switchable: `--nav-off=kturnfill,guardnear,blockreach,creepbound,kturnslide` is round 11.

### Next steps (not done, in order)

1. **Right-of-way sized for long hulls:** `YIELD_SPOTS` / `YIELD_BACK_UP` are fixed offsets for small hulls and only
   the spot's centre is checked against the mesh; a rig giving way in a 22 m street backs into walls (the +57 %).
   Validate a yield leg with the outline sweep the planned reverse uses, and scale the offsets with the hull.
2. **The search aims at a corner under the hull** (40 of 130 refusals): candidate (b) in the pre-registration — give
   the planned reverse the route point a lookahead (1.2 R) along, not the carrot.
3. The rigs' remaining misses are slot fit (four 14 m hulls, "arrived" 7-15 m from a slot): squad's formation spacing
   for the rig class, or nav's goal grounding with the apart rings, measured on the drive test.
4. The kinematic planner (`algorithms.md`): only if 1-3 leave refusal-driven misses.

### Merge notes

- Only nav's paths: `game/ai/movement.gd`, `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`,
  `_agents/{navigation,algorithms}.md`, this brief. `TankMotion` reads `Movement.switched_off`, `WHEELS_SETTLE_RADII` and
  `WHEELS_SETTLE_MAX` (the creep bound). No shared file touched.
- New `--nav-off` names (in `OFF_NAMES`): `kturnfill`, `kturnslide`, `guardnear`, `blockreach`, `creepbound`.
- New tests: `tests/nav/test_nav_back_and_fill.gd`, `test_nav_guard_corner.gd`, `test_nav_blocker_reach.gd`,
  `test_nav_creep_bound.gd` — each has a control arm that reproduces the defect (the mutation check built in).
- New targets: `nav-kturn-buckets`, `nav-drive-ab`, `nav-drive-arms`, `nav-rig-clip`; `terminus_drive.gd` gains
  `--kturn-log`, `--trace=<unit>` and `touching` on every miss.

### Questions for the lead

- None blocking. For his eye: `nav-rig-clip` (a War Rig's five-point turn against round 11's scrape), and the trade
  above — the rigs arrive more often and refuse less, and back into walls more when they give way to each other.

### Plan (the brief's order)

| # | item | state |
|---|---|---|
| 0 | green start: `make remote T=check` on `46bac1a3` | **exited 2 on unmodified main**: 1726 passed / 0 failed, baseline + determinism unmoved, ai-scenarios `scenario_perf` over budget under load (below) |
| N1 | log every `kturn_none` (`--kturn-log`), bucket it | **done on the laptop** (below); builder0 re-run owed |
| N2 | the back-and-fill for the bucket the data names | built, `tests/nav/test_nav_back_and_fill.gd` (mutation-checked); measuring |
| N3 | drive test both arms, 8 seeds, builder0; `nav-wall-clip` looked at | **done** (builder0 tables below); clips + `nav-fight-maps` last |
| N4 | `make nav-sim-arms` with the arm | **done**: `01ab39b5 -> 6313a38d`, guard fix + blockreach |
| N5 | the planner write-up in `algorithms.md` | **written** (`0a19a612`): not built, the arithmetic says the drive test would not show it |
| N6 | a no-pivot hull's turn-in-place stays near its spot (orchestrator, from squad) | **done** `25fdd0fe` (laptop measured; builder0 drive rows above) |

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

**Builder0 confirms the shape** (`0a19a612`, the control arm `--nav-off=kturnfill,guardnear` with `--kturn-log`, i.e.
round 11's behaviour; 8 seeds): rigs **130** refusals (round 11 published 130 on `38c385d5`: the control reproduces
round 11's rig row EXACTLY — 104/128, 6917 contacts, 227 press/unstick, 946 reverse, 1202 cusps, 64 legs), buckets
near-point 40 / pressed 29 / no room 16 / cap 3 / short room 42; a fill of <=3 legs clears 26, <=5 legs 39, <=16 legs
78; 64 distinct episodes. Mixed 34 refusals (laptop 24), 14 with a <=3-leg plan.

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

### N3: the drive on builder0 (`11d6a3c7`, 8 seeds x 2 squads, four arms of ONE build, `make nav-drive-arms`)

Arms: **base** = round 11's behaviour (`--nav-off=kturnfill,guardnear,blockreach`), **fill** = + the back-and-fill,
**fillguard** = + the steering-guard fix, **all** = + blockreach. N6 is not in this build.

| squad | arm | arrived | leg s | contacts | press/unstick | reverse-gear | cusps | kturns | multi | none | aborted |
|---|---|---|---|---|---|---|---|---|---|---|---|
| rigs | base | 104/128 | 1277 | 6917 | 227 | 946 | 1202 | 64 | 0 | 130 | 2 |
| rigs | fill | 105/128 | 1476 | **5182** | **158** | 911 | 1143 | 55 | 20 | **75** | 9 |
| rigs | fillguard | **112/128** | 1218 | 8133 | 340 | 1298 | 1257 | 54 | 14 | 74 | 8 |
| rigs | all | 109/128 | 1079 | 9064 | 300 | 2052 | 1414 | 67 | 18 | 71 | 11 |
| mixed | base | 172/192 | 1617 | 1939 | 170 | 315 | 2164 | 67 | 0 | 34 | 1 |
| mixed | fill | 175/192 | 1516 | 1571 | 169 | 229 | 2043 | 66 | 13 | 16 | 4 |
| mixed | fillguard | 172/192 | 1362 | 5374 | **1346** | 374 | 2058 | 38 | 16 | 11 | 4 |
| mixed | all | **185/192** | 927 | 2219 | 95 | 163 | 1888 | 38 | 15 | 7 | 1 |

**The fill's pre-registration, scored on builder0 (base -> fill):** `kturn_none` 130 -> 75 (bar <= 105: **pass**);
`kturn_multi` 20 (>= 20: **pass**); press/unstick 227 -> 158 (not up: **pass**, -30 %); reverse-gear 946 -> 911 (**pass**);
arrivals 104 -> 105 (**pass**); aborted 2 -> 9, i.e. 7 of 20 plans (< 1/3: **FAIL, narrowly**, 35 %). Mixed: `kturn_none`
34 -> 16 (bar <= 12 from a laptop base of 24: **fail** against the number, the base itself was 34 here), multi 13 (**pass**),
arrivals 172 -> 175 (**pass**). Total contacts fall 25 % (rigs) and 19 % (mixed).

**Misses by kind** (the drive test now records what a missing crew is pressed against): base rigs 10 "arrived" 7-15 m
from the slot + **14 pinned against a friend**; all rigs 14 + 4. Mixed base 6 + 9 + 5 driving; all 5 + 2. **blockreach
does what it is for** (pinned-by-a-friend 14 -> 4 rigs, 9 -> 2 mixed), and the mixed squad's arrivals go 172 -> 185; its
cost is the rigs' reverse-gear contacts (a rig giving way backs into the street's walls: 1298 -> 2052).

**The guard fix's cost is the one unexplained number:** mixed press/unstick 169 -> 1346, almost all one artillery
scraping `Block_0`'s south face for 745 ticks with a route 1.96 m off it (seeds 2 and 7). The laptop's same arm read 0:
trajectory-specific. Traced on builder0 next (r3) before any default is decided.

**Sim baseline attribution** (`make nav-sim-arms`, builder0, `0a19a612`): none `3db293a32607fdcf`, `--nav-off=kturnfill`
`3db293a3…` (the fill does NOT move it), `--nav-off=guardnear` `01ab39b5…`, both off `01ab39b5…` = the recorded
baseline. **The guard fix alone moves it.** blockreach and N6 are re-read at HEAD (r4).

### N3 at HEAD: every mechanism attributed on builder0 (`6cb00162`, r4b, 8 seeds x 2 squads, six arms of ONE build)

Each row ADDS one mechanism to the row above (the `--nav-off` list shrinks); **base** is round 11's behaviour.

| squad | arm | arrived | leg s | contacts | press/unstick | reverse-gear | cusps | kturns | multi | none | aborted |
|---|---|---|---|---|---|---|---|---|---|---|---|
| rigs | base | 104/128 | 1277 | 6917 | 227 | 946 | 1202 | 64 | 0 | 130 | 2 |
| rigs | + creepbound (N6) | 110/128 | 1472 | 6558 | 344 | 1111 | 1220 | 58 | 0 | 95 | 0 |
| rigs | + kturnfill | 107/128 | 1590 | 3196 | 95 | 626 | 1004 | 37 | 19 | 70 | 6 |
| rigs | + kturnslide | 110/128 | 1533 | 3518 | 70 | 844 | 1034 | 40 | 19 | 66 | 4 |
| rigs | + blockreach | 106/128 | 1293 | 8464 | 149 | 1820 | 1344 | 63 | 19 | 77 | 4 |
| rigs | **+ guardnear = HEAD** | **115/128** | 1140 | **5715** | **83** | 1488 | 1267 | 57 | 9 | **56** | 4 |
| mixed | base | 172/192 | 1617 | 1939 | 170 | 315 | 2164 | 67 | 0 | 34 | 1 |
| mixed | + creepbound (N6) | 171/192 | 1458 | 3354 | 410 | 564 | 2084 | 47 | 0 | 48 | 1 |
| mixed | + kturnfill | 170/192 | 1435 | 3034 | 411 | 691 | 1957 | 41 | 11 | 22 | 3 |
| mixed | + kturnslide | 169/192 | 1560 | 4497 | 468 | 533 | 1990 | 44 | 14 | 19 | 1 |
| mixed | + blockreach | 178/192 | 1243 | 1306 | 52 | 241 | 1887 | 51 | 12 | 9 | 1 |
| mixed | **+ guardnear = HEAD** | **179/192** | 1009 | 2660 | **60** | 284 | 2111 | 39 | 12 | **4** | 0 |

**HEAD against round 11 (base), the named numbers:** rigs arrivals **104 -> 115** of 128, refusals **130 -> 56**,
press/unstick-driven contacts **227 -> 83**, total contacts 6917 -> 5715, reverse-gear contacts **946 -> 1488 (+57 %)**,
cusps 1202 -> 1267; mixed arrivals **172 -> 179** of 192, press/unstick **170 -> 60**, refusals 34 -> 4, total contacts
1939 -> 2660 (+37 %), reverse-gear 315 -> 284. Leg time falls on both (rigs 1277 -> 1140 s, mixed 1617 -> 1009 s).

**Decision: all ON by default.** The complete set is the best arrivals on both squads; every mechanism keeps its own
switch. **The cost, declared:** the rigs' reverse-gear contacts rise, and the rows put it on blockreach (844 -> 1820):
a rig asked to give way uses round 6's yield spots, fixed offsets sized for small hulls, and backs into the street's
walls. Sizing right-of-way for long hulls is the next step (below), not this round's. The drive is chaotic (single
mechanisms swing a squad's contacts by 2x between adjacent rows); read the endpoints and the named numbers, 8 seeds.

**`kturnslide` kept:** builder0 aborts 6 -> 4 (rigs), 3 -> 1 (mixed), arrivals +3 / -1: small, no cost; the laptop's
null is outweighed by the machine the numbers are published from.

**Sim baseline (CP2), builder0 `nav-sim-arms` at `6cb00162`:** HEAD **`6313a38d7ecd99bb`**; `--nav-off=creepbound`,
`kturnslide`: the same (they do not move it); `--nav-off=blockreach` `3db293a32607fdcf`; `--nav-off=guardnear`
`8c10f21dfb0e43c4`; all five off `01ab39b592cc9837` = the recorded baseline. **Two causes, both nav's: the steering
guard fix and blockreach.** The fill and N6 do not move it.

**The mixed squad's guard-fix contacts, traced on builder0** (the same arm re-run with `--trace`, reproduced exactly):
not the guard steering along a wall. The artillery reaches `Block_0`'s corner (20, -20) with three friends, yields, is
shoved, and ends squeezed between a friend and the block face (`press` contacts). The guard changed an earlier leg's
trajectory and this is where one seed's squad landed; with blockreach on, the same squad reads 95.

**`kturnslide` (a leg aborts only when its leading end drives INTO a wall), `6cb00162`: a laptop NULL** — mixed
byte-identical in both arms, rigs aborts 6 -> 5, everything else within noise. The builder0 aborts were not mostly
sliding contacts. Builder0 (r4b) shows a small gain; kept (above).

**Lost run (not nav's):** arena's misdirected rsync deleted the source in every stream's builder0 folder at ~23:28; my
r4 at 23:29 failed at once (`No rule to make target`), nothing half-ran; relaunched as r4b at `6cb00162`.

### Found on the way: the steering guard undid round 11's "never under the hull" rule (`203db8d8`)

Tracing the fill arm's one new miss (rigs seed 3, plaza leg, a rig 79 m from its goal at 90 s, laptop): after a
back-and-fill it sat at speed 0 in phase `driving` for 80 s, steering at a route vertex **0.47 m** from its centre
(2371 ticks). `_guard_steer` (round 7: the last word on a steering point) falls back to `_path[_path_index]` when the
carrot's chord leaves the mesh — and round 11's `_corner_beyond` guard runs BEFORE it, so the vertex under the hull came
back. Fixed with round 11's own rule inside the guard; `--nav-off=guardnear` restores the old pick (the attribution
arm, since it can move the sim baseline). `tests/nav/test_nav_guard_corner.gd` at that rig's pose: the control
reproduces the vertex under the hull, the fix steers at the next corner up the street. Not a rig-only bug: any hull
whose carrot chord leaves the mesh while it sits on a route vertex.

### N6: the creep's bound (laptop, `25fdd0fe`, `squad-settle` default arena, forward 20 m, `scout:scout:ifv:ifv:tank`)

8 seeds, both arms (`--nav-off=creepbound` the control): **time until every crew has stopped, mean 18.9 s -> 12.1 s**
(sum 151.3 -> 96.9; better on 6 seeds, 0.6 s and 1.2 s worse on seeds 2 and 4); **the worst crew's distance off its
slot 3.8-9.1 m -> 2.9-3.5 m** (the scout's settle radius); arrival time identical on every seed. `nav-rotation`
(pivot, car, wheel x4, truck) identical in both arms. The allowance is the hull's settle radius, NOT a flat metre: the
first build (1 m) made the War Rig turn 63 deg within 1.5 m of its start — the lead's round-8 "yawing in place" —
which `nav-rotation`'s truck case caught. Builder0 numbers owed (r4 carries it in every arm but base).

### Checks (read from the wrapper's own line)

| commit | machine | verdict |
|---|---|---|
| **`5b5e3a6a`** (HEAD + main `9afb507f` merged at the orchestrator's checkpoint) | builder0, 2 checks at once | `make check exited 2`: 16 of 18, **1748 passed, 0 failed**; sim-baseline **MOVED `01ab39b592cc9837 -> 6313a38d7ecd99bb`** (CP2, declared; the merge did not change it); determinism `550d53790035ddb4`; `ai-scenarios-check` 42,2 = `scenario_perf` 29.8 s under load + the baselined `scenario_cover`. `nav-sim-arms` on this tree reproduces the attribution exactly (below) |
| `be7e556f` (pre-merge HEAD) | builder0 | `make check exited 2`: 17 of 18, **1735 passed, 0 failed**; the one red: sim-baseline MOVED to `6313a38d7ecd99bb` (CP2); `ai-scenarios-check` passed; determinism `550d53790035ddb4` |
| `0a19a612` | builder0 | `ai-scenarios-check` ALONE: 43,1 unchanged against its baseline, exit 0 (lesson 218: the full check's red was load) |
| `203db8d8` (fill + guard fix) | builder0, loaded | `make check exited 2`: 16 of 18, **1731 passed, 0 failed**; **sim-baseline MOVED `01ab39b592cc9837 -> 3db293a32607fdcf`** (CP2, expected: attribution below); determinism `3996fb15c03ca932`; `ai-scenarios-check` 42,2 exactly as on unmodified main (`scenario_perf` 22842 us/tick + `scenario_cover`, the baselined expected failure) |
| `46bac1a3` (start, unmodified main) | builder0, 3 other checks beside it | `make check exited 2`: 17 of 18 targets, **1726 passed, 0 failed**, sim-baseline `01ab39b592cc9837` unmoved, determinism `b83a374ce2fcde37`; the one red is `ai-scenarios-check` 43,1 -> 42,2: `scenario_perf` read **21620 us/tick** over its CPU budget (load: round 11's nav recorded the same test as load, 22.0 ms at load 12.5) |

### Requests to other streams / the orchestrator

- **`scenario_perf` is red on `main` under round-12 load** (above), not by any code change: every stream's check can
  trip on it. It likely wants `verification.md`'s rule 3 (refuse, not judge, when the reference workload says the box
  is loaded). The orchestrator's session refused a direct message (2026-09-26 22:10, as in round 11), so this is its
  only copy. Until told otherwise nav reads "17 of 18, the only red `scenario_perf`'s budget" as green and names it.

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
