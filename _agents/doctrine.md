# Doctrine: formations, movement techniques and battle drills

> **What this is.** The doctrine stream's design doc (round 4). It holds the real-world doctrine we encoded,
> where it comes from, how it becomes data (`doctrines/doctrine_<name>.json`), how the code runs it
> (`game/tactics/`), and the measurements that say whether a formation actually pays off.
> The lead (2026-09-16): *"this game will get its novelty from the use of sophisticated battle drills and
> formations still … I'm certain all military formations and battle drills are on a degree of science for
> their effectiveness … it's way too much micromanaging to get the units into a specific formation; we should
> generally treat the game as cases where we're commanding well trained battle squads who operated based on
> standard operating procedures (like the army does) … if a unit gets ambushed, the standard operating
> procedure is to face the direction of the ambush and charge forward."*

## The one-paragraph version

The player gives an **element** (a cluster of vehicles with a leader) a **task**: move here, attack that,
screen this flank, support by fire, hold. The leader looks at the task, the terrain, the threat and what it is
commanding, reads its **doctrine table**, and picks a **movement formation** (the shape) and a **movement
technique** (how carefully the shape moves). On contact it stops choosing and starts *reacting*: a **battle
drill** runs, the same one every time, because that is what training is for. Every decision produces exactly
one K1 order per vehicle, so the brains keep doing their own cover, peeking, strafing and weak-spot work
inside it. The player never drags anyone into a formation, and the CPU has no tactic the player's elements
don't run automatically.

## Where the doctrine comes from

These are US Army publications; they are the "science" the lead expected. We use them for the *shapes and the
sequences*, not for the numbers (a 30-ton arena machine is not a Bradley).

| Source | What we took |
|---|---|
| **ATP 3-20.15, _Tank Platoon_** (HQDA; supersedes FM 3-20.15) | Platoon movement formations — column, wedge, line, echelon left/right, vee — with what each is for; the **coil** and **herringbone** halt formations; movement techniques; actions on contact; support by fire |
| **ATP 3-21.8, _Infantry Platoon and Squad_** (HQDA, 2016) | Movement formations and their trade-offs (control vs. firepower vs. flexibility); the three **movement techniques** (traveling, traveling overwatch, bounding overwatch) and when each is used; **actions on contact**; the battle drills (react to contact, react to ambush, break contact) in its drills appendix |
| **TC 3-21.76, _Ranger Handbook_** | The battle drills as step-by-step immediate action, including **near vs. far ambush** and the clock-direction break-contact sequence |
| **FM 3-90-1, _Offense and Defense_** | **Support by fire** and attack by fire as tactical tasks; the base-of-fire / maneuver-element split |
| **TC 3-22.240 / FM 3-22.68, _Machine Gun Employment_** | Cone of fire, **beaten zone**, grazing fire, and what "suppression" buys you — the vocabulary combat's L2 field is built in |
| **ADP 1-02 / FM 3-90 terminology** | "Suppress": temporarily degrade a force's performance below the level needed to do its job — i.e. suppression is a *behaviour* effect, not damage |

**Honesty about citations:** drill *numbering* moves between editions (what one edition calls Battle Drill 2
another calls Battle Drill 1A), so this doc cites publications and drill **names**, never paragraph numbers we
can't verify offline. Everything below is doctrine as commonly published in those manuals; the game-specific
choices are marked **(ours)**.

## Movement formations

A formation answers: where is our firepower pointed, how much of the circle can we see, how easy are we to
control, and how much of us can one shell or one burst reach? Each row's *frontage* and *depth* are what
`TacticsFormation.frontage/depth` compute at 12 m spacing for 5 vehicles.

| Formation | What it is for | Fires | Control | Frontage × depth (5 at 12 m) | Our data name |
|---|---|---|---|---|---|
| **Column** | Speed and control through lanes, close country, or when contact is unlikely | Flanks, little to the front | Easiest | 0 × 48 m | `column` |
| **Wedge** | The default when contact is *possible*: fire to the front, security to both flanks | Front + both flanks | Easy | 43 × 24 m | `wedge` |
| **Vee** | Two vehicles forward when contact is expected from the front; the leader sees over them | Heavy to the front | Harder | 43 × 24 m | `vee` |
| **Line** | Maximum fire forward: the assault, the base of fire, the screen | Front only | Hard (no depth) | 48 × 0 m | `line` |
| **Echelon L/R** | Covering one open flank while moving — a march along a threat | Front + one flank | Moderate | 43 × 48 m | `echelon_left` / `echelon_right` |
| **Herringbone** | A halt in a lane or column: the middle vehicles alternate 90° left and right, clearing the route and watching both flanks while the lead watches ahead and the tail behind | All round | Easy | 13 × 38 m | `herringbone` |
| **Coil** | A halt in the open: a ring, guns out, 360° security | All round | Easy | ~24 × 24 m | `coil` |

### Spacing is a doctrine number with a hull floor under it (round 9, X1)

A doctrine's spacing (`DoctrineTable.SPACING_DEFAULTS`: open 14 / lanes 11 / dense 8 m) is a **tactical** number —
how dispersed the element wants to be — and it says nothing about how big its vehicles are. A 14 m War Rig at 8 m
"dense" spacing stands inside the rig in front of it, and the round-9 resize puts the whole mid-roster in the same
position. So every formation is laid out at a **pitch**, `TacticsFormation.pitch(members, spacing)`, which is the
doctrine's number raised per axis to what the members' own hulls fit in:

- **across the heading** the widest member's width plus `HULL_CLEAR_M`, because side by side a vehicle needs its width;
- **along the heading** the longest member's length plus the same, because nose to tail it needs its length.

The pitch is therefore **anisotropic**: a column of rigs needs length between slots and a line of rigs needs width.
The floor never *reduces* the doctrine's number, and for every squad whose hulls fit inside it — today, everything but
the War Rig — the slots are laid out exactly as they were before, on the same code path. That is why X1 does not move
the sim baseline: its match fields only `tank` hulls, whose floor never binds.

Two consequences worth knowing:

- **The clearance rule is the separating axis, not centre distance.** Two hull boxes along one heading are clear when
  *either* axis separates them by `HULL_CLEAR_M`. `TacticsFormation.closest_boxes` measures that, and
  `tests/test_tactics_hull_spacing.gd` asserts it for every shipped shape × every faction's squad × every terrain
  spacing, with the expectations read from `Units.PROFILES` so the resize cannot invalidate them.
- **"One formation spacing" is now a real number.** `TankBrain.slot_leash(element)` is the element's own pitch rather
  than the flat 14 m `SLOT_LEASH` that used to approximate it, and `ArmyLayout` calls the same floor at deploy instead
  of keeping its own copy. The leash is what nav's A7 priority table bounds every candidate against at level 0, and
  **every** element member carries one now, including the `bound` and `maneuver` roles: the slot an element publishes
  for those is the ground it told them to cover (a bound's next anchor, a manoeuvre element's flank), so bounding them
  to it converges them rather than caging them.

### A formation deforms to fit its corridor (round 9, X2, catalogue A8)

A formation is a nominal shape **plus a per-element deformation**, continuous in the width of the corridor it is
driving through, so a wedge narrows to fit a defile and re-expands after it — without dissolving, without changing
formation, and without re-seating anybody. `TacticsFormation.fit_to_corridor` is the whole policy and
`offsets_deformed` applies it.

**It is not a 2×2 alone, and that is a design finding worth keeping.** A wedge has pairs of slots at the *same depth*
(slot 1 at −0.9 s, slot 2 at +0.9 s, both at y = s). No matrix can separate two points that differ only across the
heading while squeezing that axis toward zero: at the limit they land on top of each other. "A wedge becomes a
column" is therefore **false for an affine map**, and a version that assumed otherwise would stand its own hulls
inside each other in the narrowest corridors — exactly what the hull floor above exists to prevent. What is
continuous, closed-form and crossing-free is two terms, in order:

1. **File** — the nominal shape is pulled toward single file, its ranks splitting apart *along* the heading before
   the shape closes *across* it, because splitting is what makes closing safe. The file's target order is the shape's
   **own depth order**, not the slot index: a vee has slots ahead of its leader, and filing those to `(0, index)`
   would drive slot 1 from in front of the leader to behind it — a rank inversion, which is the thing A8's falsifier
   forbids.
2. **Pitch** — the result is scaled per axis (the diagonal 2×2 above), elongated along the heading as it is
   compressed across it, and sheared by whatever the caller's heading change needs.

Neither term can re-seat a unit or invert a rank, so *zero slot crossings and zero rank inversions* hold **by
construction** rather than by measurement; `tests/test_tactics_deform.gd` sweeps corridor widths and asserts the
hulls stay clear, the depth order never inverts, and the frontage is monotone with no snap. A corridor too narrow for
even the tightest clear deformation returns `fits: false` — information for the element, not a licence to stack
vehicles. **A halt does not deform**: it is standing in an area, not filing through a gap, and its all-round sectors
are the point of it.

**A8 SHIPS OFF** (`TacticsFormation.DEFORM_ENABLED := false`), and the reason is a measurement, not a doubt. Through
the maze's gap (5.0 m of navmesh) a forced wedge of five wheeled Condemned hulls got **0 of 5** through with the
deformation on and **4 of 5** with it off, and crossings went **up** (6 against 1) rather than to the zero the
falsifier promised. One configuration, not a seed sweep — three seeds returned byte-identical numbers because that
scenario has no enemies and hand-placed units, so the seed varies nothing. The geometry above is right and asserted;
what is wrong is that **a slot layout is the wrong place to express a formation intent.** nav reached the same
conclusion the same night from the other end: `CombatMotion` decides under a tenth of a hull's ticks and `Movement`,
which drives the rest, has no notion of a formation leash at all. Both A8's deformation and A7's region belong in
`Movement`'s goal selection, and that seam is round 10's first candidate. Turning A8 back on is one constant.

Also worth knowing before anyone measures it again: **A8 never applied to a plain right-click move.** `_plan_form_up`
sets the corridor to INF on purpose, because a plain move's slots are the formation that STANDS at the destination
rather than a transit shape — so the lead's commonest order was never in scope. Deforming the FLOW offsets, which are
the real transit shape of a plain move, is the follow-on.

The corridor width itself is measured by `SlotGround.corridor_width` (the standable width across the heading,
bisected off the navigation mesh, narrowest of three samples along the leg) because nav's `Movement.state()` does not
report a clearance yet. `Element` takes one measurement per **leg**, not per update. Where the width is unknown the
deformation is the identity, so a formation is never worse than today for the lack of a number.

**Sectors of fire.** A formation is only half the answer; the other half is who watches what.
`TacticsFormation.sectors()` assigns every slot an azimuth relative to the direction of travel (0 = ahead,
+ = right), 90° wide each, so neighbours interlock. `coverage()` is the share of the full circle the element
watches: a **column covers ~1.0** of the circle (lead ahead, middles on alternate flanks, tail behind), a
**line ~0.42** (everything forward, nothing behind). That is the trade the player is making without having to
think about it, and it is a measured property of the data, not a bonus number.

## Movement techniques

The technique is *how carefully* the formation moves, and doctrine picks it from one thing: how likely is
contact?

| Technique | When | What happens | Cost |
|---|---|---|---|
| **Traveling** | Contact not likely | The whole element moves together, continuously | Fastest, least secure |
| **Traveling overwatch** | Contact possible | The lead section moves; the trail section follows at a distance where it can support by fire, ready to fire | Slower, one section always able to shoot back |
| **Bounding overwatch** | Contact expected | One section moves a short bound while the other is **set** and covering it; then they swap | Slowest, safest: someone is always watching over the gun |

**Bounds are limited by supporting fire, not by patience** — a bound never goes further from the overwatch
element than it can be covered (`legs.support_range_m`, default 85 m). Our elements also *close up before they
bound again*: the next leg waits until every vehicle is within `legs.cohesion_m` of its slot. That is the
doctrinal "close up", and it is also what stops a fast scout from arriving alone.

**(Ours) Legs, not sliding destinations.** Movement runs as discrete legs (45 m traveling, 34 m traveling
overwatch, 22 m bounding). Orders are re-issued only when a leg changes, because every new order resets what a
brain was doing (round-3 lesson). The element therefore *flows* without its vehicles being nudged every tick.

### Bounding overwatch is an explicit two-phase machine (round 9, X3, catalogue A9)

Before round 9 bounding overwatch was a technique *name* and a boolean: `bounding` said which half had the current
leg, the halves swapped the moment the movers closed up, and **nothing guaranteed that anybody was stationary** or
that a phase lasted long enough for a spectator to see it. The lead's standing complaint is that
base-of-fire-and-manoeuvre is not legible, and this is the row that buys it.

`ElementPlan.bound_teams(ordered)` splits the element, and a phase runs between `BOUND_MIN_TICKS` (5 s) and
`BOUND_MAX_TICKS` (8 s) — the minimum stops a shimmer when both teams close up at once, the maximum stops a team that
never closes up from parking the element. `Element.state()` publishes
`bound: {phase, since_tick, movers, overwatch, base, stationary_share}`, so control can draw the phase and the
announcer can call it.

**An odd-sized element leaves a permanent base of fire**, and the reason is worth keeping because it is a case of a
falsifier's wording changing a design for the better. A9's bar is *"≥ 50% of squad firepower stationary at every
tick"*, and two alternating halves of an odd-sized element cannot meet it: `split` gives ceil(n/2) and floor(n/2), so
whichever phase moves the three-vehicle half of a five-vehicle squad leaves 2 of 5 = **40%** still, and swapping which
half goes first only moves the 40% to the other phase. So a five-vehicle element bounds as **1 + 2 + 2**: a base that
never bounds and two equal teams that alternate, which leaves **3 of 5 stationary in both phases**. That is what a
platoon actually does — it leaves a support-by-fire element and bounds its sections — and the base is the vehicle
worth most from a static position (the most protected role: artillery, then lancer, which are also the guns the
element exists to protect and the ones that shoot worst on the move). A two-vehicle element alternates singles; a
single vehicle does not bound, and the plan says so rather than pretending to.

### Arriving together is one bottleneck, counted in ticks (round 9, X3)

`FormUp.bottleneck_ticks(etas)` is the element's bottleneck arrival time in **ticks**, not seconds, so every member's
pace is a ratio of two integers and cannot drift with float order (`determinism.md`). `FormUp.paces` paces every
member — **the leader included** — by its share of it: the laggard drives flat out and the rest arrive with it. Round 7
had a *second* rule for the same vehicle, `Element._pace_leader_for_flow`, which eased the leader off by how far the
worst follower trailed its follow offset; it is deleted, because one bottleneck is what A9 is. The K1 100 ms response
guarantee is untouched by construction: a member within `PACE_NEAR` of its slot drives flat out, so co-arrival slows
the **cruise**, never the start.

### A plain move travels AS a formation: the travelling anchor (round 12, 2026-09-26)

The lead, playing: *"my first action was to click a location for a squad, they were in auto formation … and they all
split apart and navigated their own way to the destination."* They did, and it was a design choice, not a defect: a
plain move (`ElementPlan._plan_form_up`) laid ONE shape on the click and sent every crew to its final slot by its own
route, and the round-7 flow (followers keeping station on the leader) only ran when the leader's slot was at the
FRONT of the shape — which round 10's least-driving seating made rare (`_leads_from_the_front`). So a 60–150 m order
had no formation in its transit, which is most of what he watches; the shape formed only at the end, and there it was
the doctrine's **column** (both the default arena and the Terminus classify as *dense*), not the wedge the AUTO icon
shows.

**The mechanism.** `Element._advance_transit` gives a plain move at least `TRANSIT_MIN_M` (25 m) long a **travelling
anchor**: a point that drives the navmesh route from the squad's centre to the click (the one impure step, like the
corridor measurement) at the slowest member's cruise (`TRANSIT_CRUISE` 0.85 × top speed), held back by the crew
furthest BEHIND its place along the route (`TRANSIT_LAG_SLACK_M` 8 m, falling to `TRANSIT_MIN_PACE` 0.35 over 30 m
more — never zero, lesson 17). `ElementPlan.stations_along` lays every crew's **station** on the route around it,
each slot at its own distance along the route and its lateral offset across the tangent *there*, so a column takes a
corner as a column does instead of the shape swinging rigidly. The K1 orders are untouched: one `move` per crew to its
final slot, issued once, completion judged against it. The brain (`TankBrain._order_context`) simply drives to its
published station (`ElementFeed` "station", `Element.state()["stations"]`) while one exists, at the near think rate,
with the goal handed to nav on every think (`sliding`) so its station PID reads the goal's speed cleanly. Co-arrival
pacing is off in transit: the anchor is the pace. `TRANSIT_HANDOFF_M` (12 m) before the click the stations stop and the
standing moves do the last metres as an ordinary approach. Seating is fixed from the first update (a translation
along the heading does not change the least-driving seating, so this costs nothing at t0). `TRANSIT_ENABLED` is the
A/B switch; the settle probe's `--transit=off` is round 10's path, byte for byte (its numbers reproduce exactly).

**Three rules the first build got wrong, each read from a `make squad-settle ... TRACE=on` trace and fixed:**

1. **A crew AHEAD of its station waits** (`TRANSIT_WAIT_M`). The column's tail crew turned round to drive back to a
   station that was driving toward it, then turned again — two U-turns and 19 m of lag, and the anchor slowed for it.
2. **A crew beside its station aims ahead of it by the lateral gap** (`TRANSIT_LEAD_MAX_M`). Sixteen metres to the
   side of its place, a tracked tank was asked to turn 90° toward a point beside it and PIVOTED for 4 s while its
   station drove off; the anchor then ran at 0.5–0.8 pace for the whole trip waiting for it. Aiming at a point ahead
   by the lateral gap makes the merge a diagonal, and the lead shrinks to nothing as the crew closes.
3. **Hand over short of the click, not on it.** On the click, a wheeled scout met its final slot at cruise 4 m ahead
   of it and circled it for 15 s (mixed squad stopped 28.6 s against 15.0 without the anchor). **Braking the anchor
   into the click was tried first and was worse everywhere** (a station creeping at 2 m/s sits inside a wheeled
   settle radius for seconds, so the mover parks on it and the order completes up to 4 m off); it is written up in
   `transit_speed` and not repeated.

**The anchor starts half a shape AHEAD of the squad's centre** (`ElementPlan.transit_start_m`): at the moment of the
order every station is in front of every crew, so the squad moves off the way a column does — the head first, each crew
falling in behind. Started ON the centre, half the crews were ahead of their stations and waiting, and the middle pair
converging onto the line from either side met head-on and yielded to each other for 8 s while the anchor idled at its
floor pace (yard, forward from the spawn, seed 1). The cost of the ahead start is a looser shape in the first seconds
(the mean station error over the transit rose from 6–9 m to 10–14 m) for a start that does not tangle.

**Measured — the paired series (`make squad-transit-series`, `tools/tactics/transit_series.py`; builder0, uncommitted
tree over `37698d7d` with the ahead start, 80 m plain moves, 4 jittered seeds per cell, both arms on the same seeds;
medians, s; `gap` = the ON arm's mean distance from station while travelling; the two maps he plays most — the default
scene is the foundry, which is not dealt):**

| arena | dir | squad | arrived off / on | stopped off / on | gap | stopped: off faster / on faster / tie |
|---|---|---|---|---|---|---|
| Terminus | forward | tank·tank·ifv·ifv | 11.0 / 12.8 | 13.5 / 14.9 | 9.8 m | 1 / 1 / 2 |
| Terminus | forward | scout·scout·ifv·ifv·tank | 10.7 / **9.9** | 23.8 / **21.8** | 11.2 m | 2 / 2 / 0 |
| Terminus | side | tank·tank·ifv·ifv | 13.8 / **10.6** | 15.2 / 15.2 | 12.6 m | 2 / 1 / 1 |
| Terminus | side | scout·scout·ifv·ifv·tank | 10.1 / 10.4 | 31.3 / **30.2** | 13.1 m | 0 / 3 / 1 |
| yard | forward | tank·tank·ifv·ifv | 14.5 / 16.1 | 29.4 / **19.3** | 14.1 m | 2 / 2 / 0 |
| yard | forward | scout·scout·ifv·ifv·tank | 14.0 / 14.4 | 29.0 / 33.5 | 13.9 m | 2 / 2 / 0 |
| yard | side | tank·tank·ifv·ifv | 9.8 / **9.3** | 11.1 / 14.1 | 11.4 m | 3 / 0 / 1 |
| yard | side | scout·scout·ifv·ifv·tank | 10.4 / **10.1** | 30.5 / **29.2** | 13.8 m | 0 / 3 / 1 |

Overall, on the stop time: off faster 12, on faster 14, tie 6 — **a wash in time, with the shape as the difference.**
(The same series with the anchor started on the centre read off faster 18 / on faster 11 / tie 3, gap 6–9 m; it is
in the session's HANDOFF entry.) The mixed squad's 22–34 s stop times are the same in both arms: a wheeled scout
creeping after its order completes, round 10's known issue, not the anchor's. Round 9's ruling is the frame: *"a 4s
slower march for a tidier traversal is better, yes."*

**The weak phase is the first five seconds of a move from the spawn line** — an abreast line becoming a column — and it
is the same in kind for both arms: paths cross, ORCA yields, and on some seeds the middle pair stall together for
several seconds (yard forward seed 1 trace, both starts). Under the anchor that stall also holds the squad back
(the lag rule), which is why the yard forward arrival is 1.6 s later. Round 12 built the fall-in rule proposed here (a crew
does not close on the line until the crew whose station is ahead of it has passed) and measured it worse: the stall is a
queue at a chokepoint, not a lane conflict (*The fall-in rule: built, measured, rejected* below).

**What the anchor buys is not speed but the shape: the same order now reads as a squad moving off together and closing
up on the spot**, which is the visible half of his "formula to form up". The mean station error while travelling is
6–9 m against a 10.6 m pitch; the control arm has no shape to measure. A human watching it is the check that counts.

**Not done, deliberately:** ~~the AUTO icon still shows a wedge whatever the table picks~~ (done in round 12, S1: the
card reads the leader's pick); ~~a G-chosen formation is still overridden by the halt shape at the end of a drills-on
move (`_halt`)~~ (done in round 12, S2: *Whose shape it is, phase by phase* below); ~~the direct path~~ (measured and
decided in round 12, S4: *A partial or mixed selection* below -- it does scatter, and it is left as his 2026-09-20 ruling
has it); the direct path (a box-selection that is not a numbered squad, `Orders._resolve_group`) still sends each
vehicle to its slot on its own.

### Form up on the move (round 20, brains M1; DECLARED, `4eaf948c`)

**What he saw (round 19, orders' probe):** a squad standing abreast at its spawn first shuffled into its wedge, then
set off; crews ran 12–20 m off their straight lines in the first 5 s, and a Sumps straggler drove 17.7 m AWAY from
the click to its seat. Cause: round 12's stations were the finished shape from the first tick, laid round an anchor
half a depth ahead of the squad's centre, so a crew seated behind (or across) where it stood went there first.

**How a squad travels now.** `Element._advance_transit` records each crew's place in the route's frame when the
anchor is created (`ElementPlan.transit_starts`: lateral offset and distance along the route from the anchor's start).
Every update, `ElementPlan.converge` eases each crew's station from *its own place carried along the route by the
anchor* onto *its seat in the shape* (`stations_along`, unchanged) with a smoothstep over `converge_m` of the anchor's
travel: at least `CONVERGE_MIN_M` (30 m), the shape's depth, and 1.5 × the most any crew must fall back + 5 m (the
smoothstep's steepest slope is 1.5× its mean, so no station ever runs backwards along the route: tested), capped so
the shape is formed by the hand-off. After that, round 12's stations exactly. The lag rule reads the eased stations.
So at the order every crew's station is where it stands, every station moves toward the click from the first tick,
and the shape forms over the first leg. Both sides (an element is an element). Switches: `--converge=off` (round 12),
`--converge=lead<M>` (each first station M m ahead along the route; measured, 0 kept).

**Numbers** (`make converge-probe CONVERGE_REPS=3`: orders' read-only two-squad probe, seed 3, builder0, at `0788e268` +
M1; the probe runs in real time, so each arm three times; worst metres any crew got FARTHER from the click in its
first 5 s, round 12 → now):

| map | selected together | one group over both | one squad alone |
|---|---|---|---|
| parade | 6.3, 6.3, 6.3 → 0.4, 0.4, 1.8 | 10.2, 10.4, 10.2 → 1.6, 1.7, 1.7 | 9.9, 10.1, 10.1 → 1.8, 0.0, 1.7 |
| the Sumps | 5.9, 5.9, 4.7 → 4.8, 4.7, 5.1 | 11.0, 9.5, 6.0 → 8.4, 8.7, 0.2 | 3.6, 1.4, 2.9 → 0.0, 1.6, 0.0 |

Worst off the straight line (start → slot) in 5 s, round 12 → now: parade 12.6–12.7 → 13.8–13.9 (selected), 15.0–16.1
→ 12.0–13.1 (grouped), 18.5–19.3 → 10.7–11.6 (single); the Sumps 24.4–34.3 → 15.9–17.5, 22.5–27.3 → 27.4–28.3, 8.6–11.8
→ 7.0–12.2. Off-line is mostly the ROUTE (on the Sumps the navmesh route leaves the spawn round the water), so it moves
less than "away".

**The lead distance, measured (one run each, builder0):** parade away selected/grouped/single: lead 0 0.4/6.7/0.6, lead
10 5.9/8.4/6.9, lead 20 4.5/9.8/12.0, lead 30 3.2/9.5/9.1; a Sumps run at lead 10 sent a crew 18.8 m away. A station
ahead of the crew and off its nose lands inside a WHEELED hull's turning circle, and `Steering._wheels` backs it round
(a three-point turn): the crews heading away were the IFVs every time.

**Known limit:** the yard, a wedge sent 100 m forward from the spawn row (`test_tactics_form_on_move`, laptop, seed 3):
away 1.4 m (round 12) → 3.2 m now, the middle IFV backing round once; the line 6.1 → 2.7 m. The yard's route leaves
the spawn on a diagonal that squeezes an 8 m row into 5.7 m lanes. The next lever, if he notices: the brain's aim
point on a station (`TankBrain`, `TRANSIT_LEAD_MAX_M`) kept outside a wheeled hull's turning circle.

### The fall-in rule: built, measured, rejected (round 12, S3)

The anchor's weak phase is the first seconds of a move from the spawn line. The brief's model was **two crews
converging onto the same lane from either side**, and its answer a fall-in rule. `ElementPlan.fall_in` (pure, 4 tests):
in the first `FALLIN_MAX_S` (8 s), a crew whose sideways path onto its station would cross the lane of a crew seated
AHEAD of it that has not yet passed it (`FALLIN_CLEAR_M` 6 m) is held, either **lane** (keeps driving in its own lane)
or **wait** (stands, and is not a laggard to the lag rule). `FALLIN_ENABLED` (**false**), `FALLIN_MODE`; `make
squad-fallin-series [FALLIN_ARM=wait]`.

**Measured (builder0, 80 m plain moves, 4 jittered seeds x 8 cells, both arms on the same seeds; `gap10` = the mean
distance from the SHAPE's station over the first 10 s, the rule's own target):**

| arm | stopped: off faster / on faster / tie | gap10, cells worse / better |
|---|---|---|
| lane (`0b0124da`) | 9 / 9 / 14 | 6 / 1 (yard forward mixed 16.0 -> 19.0 m) |
| wait (`9aed5a3f`) | **19 / 9 / 4** | 7 / 0 (yard forward mixed 16.0 -> 23.7 m; Terminus side tracked stop 15.2 -> 27.1 s) |

**Neither ships.** The rule costs the shape in exactly the seconds it aims at and buys no time.

**Why: the model was wrong.** A top-down plot of the yard trace (`make squad-settle ARENA=yard DIR=forward METRES=80
SEED=1 TRACE=on`, then `tools/tactics/plot_tracks.py <log> yard out.png`) shows what the middle pair are doing: the
anchor's route threads a ~5 m gap between the wreck at (9, 68) and the container stack at x = 17, twenty metres from
the spawn, behind a 20-ft container that sits dead ahead of the spawn's centre. The "stall" is a QUEUE at that gap.
Meanwhile the column's TAIL crew, path-finding to a station already past the gap, takes a different gap west of the
wreck and comes out AHEAD of the middle pair. Holding a crew in its lane aims it into the container; standing it still
makes the queue longer.

**Next, if anyone takes it up:** the shape of the fix the plot suggests is *join the route, behind the crew ahead*: a crew
far off the anchor's route drives to the route first, at a point behind the crew seated ahead of it, instead of
path-finding to a station on the far side of a chokepoint (which is how the tail finds its own gap). Not built; the
code above stays behind its switch as the measured control, the way the braking attempt is recorded in `transit_speed`.

### Column or wedge for a plain move: measured, and put to him (round 12, S5)

The row that decides his squads' plain move is not the standard table's `dense -> column` (no squad he fields uses the
standard table) but the **Condemned and Law catch-all: column in any terrain** ("column when nothing is in sight", X6).
Measured as two G orders on the same seeds (`make squad-shape-series`; C12.5 holds each shape through every phase):

**builder0, `161465ef`, 80 m plain moves, 4 jittered seeds x 8 cells, column "off" / wedge "on", medians:**

| arena | dir | squad | stopped col / wedge | gap10 col / wedge | stop: col faster / wedge faster |
|---|---|---|---|---|---|
| Terminus | forward | mixed | 21.8 / 20.1 | 11.5 / 9.9 | 1 / 3 |
| Terminus | forward | tracked | 14.9 / 18.1 | 11.1 / 8.7 | 2 / 2 |
| Terminus | side | mixed | 30.2 / **18.8** | 13.2 / 11.6 | 0 / 4 |
| Terminus | side | tracked | 15.2 / **12.1** | 12.6 / 12.5 | 0 / 4 |
| yard | forward | mixed | **33.5** / 38.3 | 16.0 / **9.1** | 4 / 0 |
| yard | forward | tracked | 19.3 / 23.9 | 16.4 / **10.4** | 2 / 2 |
| yard | side | mixed | 29.2 / **25.2** | 13.8 / **9.2** | 0 / 4 |
| yard | side | tracked | 14.1 / **11.4** | 11.4 / 10.4 | 0 / 4 |

Overall on the stop time: **column faster 9, wedge faster 23**; the first-10-s station error is lower in the wedge in 7 of
8 cells. The exception is the yard's forward move -- the chokepoint 20 m from the spawn (*The fall-in rule*) -- where a
column is the natural shape and the wedge stops 4-5 s later. The frames at his pose (`make formation-shots`, 10 s and
arrival; `streams/references/round12/squad/s5_*_sheet.jpg`) show the other side: in the Terminus's 20 m street the
column rides tidily down the middle and the wedge spans it wall to wall, one hull against a block.

**Kept, for now, and put to the lead.** The row is faction character he approved on the doctrine page, and the
orchestrator's ruling is that he decides on the picture. Recommendation: a **wedge** for the Condemned/Law plain move in
lanes and open ground (faster to settle and tidier by the number almost everywhere), keeping the **column in dense
terrain** (the yard, where the chokepoint is) -- i.e. the standard table's own two rows. Until he answers, the card says
which it is and why: "Auto: Column", with the doctrine line's reason under the header (S1).

### Round 13: the wedge is the default plain move (the lead: *"Default wedge."*)

The Condemned, Law and standard catch-alls (a move with nothing in sight) are a **wedge in every terrain**, with the
reason `wedge (default), ...` in the row's `why`; under AUTO a plain move's card line carries that row's reason
(`ElementPlan._plan_form_up`: "moving as ordered: wedge (default), nothing in sight: quickest to settle, and it keeps its
shape on the way"), so the card reads "Auto: Wedge" and says it is the default. The contact rows are untouched (the
Law's `possible + dense -> column` bounding, the standard's `likely + dense -> column`): those are doctrine under a
threat, not the plain-move default. The Syndicate's catch-all was already a wedge and the Gangs' a swarm.

**Dense was re-measured before it was decided**, on the rule pre-registered in the squad brief (keep a column for
`dense` only if, over the yard's 16 paired runs, it stops first in 9 or more AND its first-10-s station error is lower
in at least 2 of the 4 cells). `make squad-shape-series`, builder0, the working tree of `736ea624` with Q1's edits
(G-ordered shapes do not read the table), seeds 1-4, 80 m:

| arena | dir | squad | stopped col / wedge | gap10 col / wedge | stop: col faster / wedge faster / tie |
|---|---|---|---|---|---|
| Terminus | forward | mixed | 20.2 / 19.9 | 11.4 / 9.8 | 1 / 1 / 2 |
| Terminus | forward | tracked | 14.0 / 13.4 | 10.9 / 8.6 | 1 / 2 / 1 |
| Terminus | side | mixed | 19.6 / 19.6 | 13.3 / 12.3 | 0 / 1 / 3 |
| Terminus | side | tracked | 16.6 / 13.2 | 13.0 / 12.4 | 2 / 2 / 0 |
| yard | forward | mixed | **21.0** / 23.1 | 14.8 / **8.4** | 3 / 0 / 1 |
| yard | forward | tracked | 19.7 / **15.5** | 15.8 / **10.3** | 2 / 2 / 0 |
| yard | side | mixed | 19.4 / **18.5** | 13.9 / **9.1** | 0 / 4 / 0 |
| yard | side | tracked | 14.1 / **11.4** | 11.4 / **10.4** | 0 / 4 / 0 |

The yard: column first in **5** of 16, lower gap10 in **0** of 4 -- the bar was not met, so the wedge is the default in
dense ground too. Overall 9 / 16 / 7 (round 12 at `161465ef`, before nav's N6: 9 / 23). The column still
wins the yard's forward move for the mixed squad (the chokepoint 20 m from the spawn), as in round 12, and nowhere
else. Since nav's N6 is on this tree the mixed squad's Terminus side-move stop fell from ~30 s (round 12, column) to
~20 s for both shapes.

### S6: an arrived scout with nothing in sight is not told to face (round 13, Q2; ON)

**What it was.** After a plain move arrives, each crew with nothing in sight is handed its formation sector as a `face`
(`TankBrain`'s idle branch: "covering its sector"). For a wheeled hull with a FIXED gun (the scouts: `scout`,
`gang_scout`, `law_scout`) that face is a multi-point turn (it cannot pivot; round 8 already declined it for a turret on
wheels, whose gun aims by itself). Round 12 traced it walking the scouts off their slots; nav's N6 then bounded the
drift, so on this tree the cost is TIME: the squad is not "stopped" until the scouts finish shuffling.

**The lead's toggle (decided 2026-09-27 evening):** *"ok go ahead and turn it on, but let's make sure it's documented in
our codebase that this behavior can be toggled I might want to change it later."* ON stays. The switch is the one line
`static var IDLE_FACE_NO_PIVOT := true` in `game/ai/tank_brain.gd`, with both behaviours described in the comment above
it; no test pins the value. Record: `game_design.md` *Round 13: S6 decided*.

**The rule** (`TankBrain.IDLE_FACE_NO_PIVOT`, ON; `no_pivot_fixed_gun`): a face for such a hull while no enemy is
VISIBLE becomes a stop, unless the facing is ORDERED -- the unit's current K1 order carries a `facing`, or its element's
task is a posture (hold, ambush, screen, support by fire), whose sector is the facing it was given. What is left
declinable is exactly a move's (or attack's) arrival sector and a post's travel heading. Counters by source
(`idle_faces`: sector / squad / post / order) and `idle_faces_declined` are on every brain.

**Measured** (`make squad-idleface-series`, builder0, `fda69463`, both arms on the same seeds 1-8, 80 m plain moves,
AUTO; medians):

| arena | dir | squad | stopped off / on | on faster / slower / tie | scouts' off-slot at stop off / on |
|---|---|---|---|---|---|
| Terminus | forward | mixed | 20.0 / **13.6** | 8 / 0 / 0 | 0.9 / 2.7 |
| Terminus | side | mixed | 19.7 / **12.9** | 8 / 0 / 0 | 1.1 / 2.6 |
| yard | forward | mixed | 22.8 / **15.1** | 8 / 0 / 0 | 0.9 / 2.6 |
| yard | side | mixed | 18.8 / **11.3** | 8 / 0 / 0 | 0.7 / 2.6 |
| all four | | tracked (no scouts) | identical | 0 / 0 / 32 | -- |

Arrival is unmoved in every cell, and so is the worst crew's off-slot (3.0 m forward, ~12 m on side moves in BOTH arms
and in the tracked control: a slot the probe reads at the stop, not this change). The cost is the scouts' own distance
from their slots, 0.9 → 2.7 m, inside the probe's 3 m in-slot bar: the face's creeping turn used to finish the last
metre too. The scouts now point along their arrival heading rather than their sector until something is in sight, and
then they face it as before. `make tactics-drills IDLE_FACE=off|on` prints identical results; a hold with a `facing`
still reaches the scouts as an ordered facing and nothing is declined (`test_tactics_idle_face`).

**Against the round-12 pre-registration** (stop ~30 s toward ~15 s, arrival unmoved, scouts under 4 m): nav's N6 had
already taken the stop from ~30 s to ~20 s and the scouts' drift under 1 m; S6 takes the rest of the stop time
(~20 → ~13 s), at +1.8 m on the scouts.

**The sim baseline did NOT move**, against the pre-registration (MOVED, because the baseline match fields `scout` and
`gang_scout`): builder0, switch OFF `57ab6597` → `6313a38d7ecd99bb`, switch ON `21864680` → `6313a38d7ecd99bb`. Not
verified why; the likely reason is that in the 40 s elimination match the baseline's scouts are never idle with nothing
in sight and without an ordered facing (it runs no `--*-elements`, so their idle face would be the legacy squad's).

**The frames** (`make formation-shots SHAPES=auto UNITS=scout:scout:ifv:ifv:tank IDLE_FACE=off|on SETTLE=on`, builder0,
`aefa9a1c`, seed 3, slots drawn as crosses; `streams/references/round13/squad/q2_*`): with S6 OFF the scouts stand
angled ~45 degrees outward to their wing's sector; ON they point the way the squad travelled. On the yard the ON scout
stands on its cross; on the Terminus one ON scout (F_1) stands visibly ~2-3 m short of its cross by the block corner.
In that seed the OFF squad on the yard had not settled by 25 s; ON settled at 16.3 s (yard) and 13.4 s (Terminus, OFF
18.6 s). Whether the tidier-looking, faster stop is worth the scouts no longer pointing along their sectors is his call
(his standing words favour tidiness over time).

### Whose shape it is, phase by phase (round 12, S1/S2; C12.4, C12.5)

**The player's G choice (`task.formation`) is the shape at every phase of the move; the doctrine table decides only
under AUTO; a battle drill under fire may take the squad into its own shape, and the card says so.**

| Phase | Under AUTO | With a shape chosen with G |
|---|---|---|
| the order (t0), the plain move's form-up (`_plan_form_up`) | the faction table's `move` pick | **his shape** (round 11) |
| in transit (`Element._advance_transit`, `stations_along`) | the same pick, fixed at the order | **his shape** (round 12) |
| a drills-on move's legs (`_plan_movement`, traveling / bounding) | the table's pick; a traveling-overwatch trail section in a wedge | **his shape**, trail section included (round 12) |
| the halt on arrival, or a hold (`_halt`) | the table's `hold` pick (herringbone in cover, coil in the open) | **his shape** (round 12: before this a chosen wedge dissolved into a coil on arrival) |
| a battle drill (react to contact, ambushes, assault, break contact) | the drill's shape | **the drill's shape**: that is the doctrine's job under fire |
| an attack inside its guns' band | a line (every gun in the fight) | a line: the verb's posture, not a table pick |

**The card reads the same truth** (`CommandIcons.formation_readout`): *"Auto: Column"* under AUTO with an element (the
leader's actual pick, updated as it changes), *"Auto"* on its own glyph (a ring round an A) before the squad has an
element, *"Wedge"* for his choice, and *"Line: drill"* while a drill has his squad in another shape (the doctrine line
under the header names the drill). The AUTO glyph used to be a wedge whatever the leader picked.

**What AUTO actually picks for his squads (measured, `make tactics-terrain`, 2026-09-26).** The brief assumed the
yard and the Terminus both classify as *dense*, so the standard table's `dense -> column` row picks a column there.
Two corrections: (1) at the spawns only the **yard** (and the sumps' centre slot) is dense; the Terminus, the pit, the
crossing and the locks are *lanes*; (2) more to the point, **no squad he fields uses the standard table**: a squad
fights by its units' FACTION table (`Elements._table_for`), and the Condemned and the Law both end in a catch-all
**column** whatever the terrain; the Syndicate's is a wedge and the gangs' a swarm. So a Condemned or Law squad under
AUTO forms a column on every map, and the wedge the card showed was wrong for both factions on every map. *(Round 13:
the catch-alls are now a wedge -- his answer "Default wedge" -- so the card reads "Auto: Wedge"; next section.)*

### A partial or mixed selection: measured on the default path, and left as he ruled (round 12, S4)

**What happens** (`make squad-partial CASE=partial|mixed|whole`, `tests/tactics/partial_probe.gd`: a Condemned army of
Alpha (tank, tank, ifv, ifv, scout) and Bravo (tank, ifv, scout), deployed and put on number keys exactly as skirmish
does, the order through the real `RtsControls.order_selection`, 80 m toward the enemy, yard):

| selection | path | the card | what the crews do |
|---|---|---|---|
| all of Alpha | TASK (a numbered squad) | "Auto: Column", the doctrine line | one column on one route, riding the anchor |
| 3 of Alpha's 5 | DIRECT (`Orders._resolve_group`) | "Part of Alpha: press 1, or [FORM SQUAD]" | a GroupFormation wedge laid on the click; **each crew by its own navmesh route** -- on the yard two went west of the container stack and one east of it; all three **leave Alpha's element** |
| 2 of Alpha + 2 of Bravo | DIRECT | "In different squads: Ctrl+1-9 or [FORM SQUAD]" | each pair takes its own lane from its own spawn and they meet only at the click |

So the scatter he described is real for a partial or mixed selection, and it is what he would notice (plots from
`tools/tactics/plot_tracks.py` over the probe's `SETTLE_TRACK` lines; builder0 numbers in the brief's Status).

**Decision: (a), leave it.** The brief recommended (a) unless the frames showed a scatter he would notice, and they do;
but the transient element that (b) needs is exactly what **the lead withdrew himself on 2026-09-20**: *"if I just
regroup the unit, they can operate as a formation. That is good behavior, but the UX just needs to clarify that"*
(`game_design.md`, *Squad orders for a mixed selection*; round 10 R1 narrowed). Reversing his ruling is his call, not a
stream's. What stands: Ctrl+N or the card's one-click FORM SQUAD makes any selection a numbered squad, and from then on
it travels as a formation; the card already says so for both partial and mixed selections. The question -- *"a
partial selection's move still scatters; do you want it to travel as a formation too (a temporary squad formed on the
order and dissolved on arrival), or is FORM SQUAD the answer?"* -- is in the brief's Status for him, with the plots.

## Selection rules: how a leader chooses

Inputs, all computed in `ElementSituation.build()`:

| Input | Values | How it is judged |
|---|---|---|
| **task** | move, attack, screen, support_by_fire, hold | What the commander asked for |
| **threat** | none, possible, likely, contact | `contact` = taking fire, or a visible enemy within 75 m; `likely` = visible within 130 m; `possible` = something known; `none` = nothing |
| **terrain** | open, lanes, dense | Cover features within 45 m of the element (0–1 = open, 2–4 = lanes, 5+ = dense) |
| **composition** | heavy, balanced, light, support | The roles in the element: artillery and Lancers make it `support`, mostly scouts make it `light`, mostly tanks `heavy` |

The doctrine table is a list of rules tried **in order, first match wins**, ending in a catch-all — so the same
situation always picks the same row (determinism) and every situation has an answer. Every row carries its own
`why`, and that string is what the player reads on the element ("contact likely: bound forward, one element
always overwatching the other"). The standard table, in words:

1. halted in cover → **herringbone**; halted in the open → **coil**
2. screening → **line**, traveling overwatch (widest frontage, most eyes)
3. support by fire → **line**, traveling (every gun on the objective, nobody advances)
4. in contact → **line**, traveling (get every gun into the fight)
5. contact likely, dense → **column**, bounding overwatch (lanes; bound between covered positions)
6. contact likely → **wedge**, bounding overwatch
7. contact possible + light element → **vee**, traveling overwatch (*the lead's "a V formation of scouts coming at you would be scary"*)
8. contact possible + support element → **column**, traveling overwatch (artillery and Lancers move behind the guns)
9. contact possible → **wedge**, traveling overwatch
10. anything else → **wedge (default)**, traveling (round 13: the `dense → column` row before it was removed; *Round 13: the wedge is the default plain move*)

## Battle drills

A drill is not a decision, it is a reflex: a trigger, a fixed action, an abort condition and a timeout. All of
them are pure functions in `game/tactics/drills.gd`, so each one has a unit test on a hand-built situation and
a seeded scenario in a real match. **Every drill yields instantly to a player order**: the element stops
commanding any vehicle whose current order did not come from it (`Element._adopt`), so a drill can never hold
a unit against its commander (K1's response guarantee).

| Drill | Trigger | Action | Abort / timeout |
|---|---|---|---|
| **React to contact** | Taking fire, or an enemy inside fighting range, and no drill running | Deploy: vehicles in range engage, the rest hold. This is the "deploy and report" step of *actions on contact* — a short pause while the leader evaluates | After `react_ticks` (1.2 s) it becomes fire-and-maneuver; ends at once if the contact is gone |
| **Near ambush** | A contact appears *suddenly* within `near_ambush_m` (38 m standard), or one that close while we are being hit | **Turn into it.** Every vehicle drives at the ambush, which swings its hull and its armour to face the threat | Becomes *assault through* after the turn (0.5 s) |
| **Assault through** | Follows a near ambush | Abreast in **line**, drive *through* the ambush position and `assault_through_m` past it | Ends when the element is through, nothing is visible, or the timeout |
| **Far ambush** | Visible enemy beyond near-ambush range after react-to-contact | **Fire and maneuver**: the heavy half becomes the base of fire and suppresses; the other half swings `flank_m` off the line of contact and turns in | Ends when nothing is visible |
| **Support by fire** | The task itself is `support_by_fire` | The whole element takes a firing position and suppresses; nobody advances | Ends when the task changes |
| **Break contact** | Our strength below `break_contact_ratio` of what we can see, **and** the nearest enemy beyond `disengage_m` | Bound back by sections toward a rally point: one half moves, the other covers, then swap | Ends when the contact is broken (`broken_contact_m`) or the odds recover (25% hysteresis) |
| **Herringbone** | Halted with a threat known | Lead watches ahead, the middle vehicles turn out to alternate flanks, the tail watches the rear | Ends on contact or on a new movement task |

**Why near ambushes are charged.** Doctrine is blunt about it: in the kill zone of a near ambush you cannot
outrun the fire, so you return fire and **assault through**. That is exactly the lead's instruction, and it is
the most visible piece of doctrine in the game: an element that gets jumped at 25 m turns as one and drives at
whatever is shooting at it.

**(Ours) Facing comes from driving.** K1 orders carry no facing, so a halt formation's crews are given a goal
a few metres out along their sector: they arrive pointing the right way. A `facing` field in K1 would do this
properly — a request to control (see *Requests* below).

## Why formations pay off (X4)

The rule from game_design.md: *"Formations must pay off through mechanics that already exist or are being
added … never a 'formation bonus' number."* The mechanics they lean on:

| Property | The mechanic it pays off in | Measured by |
|---|---|---|
| **Sectors of fire / coverage** | Spotting and intel: an element that watches its flanks sees an approach earlier | `TacticsFormation.coverage()`; scenario: who spots first |
| **Frontage** | How many guns can bear forward at once, and how much ground is screened | `frontage()`; damage in the first seconds of contact |
| **Depth** | How few vehicles are exposed to fire from the front (a column presents one) | `depth()` |
| **Dispersion (closest pair)** | Splash radius and machine-gun beaten zones reach what is bunched | `closest_pair()`; suppression and splash damage per volley (needs combat's L2) |
| **Armour facing** | Turning into an ambush presents front armour; a flanked column presents sides | `Armor` / `Match.armor_multiplier`; damage taken per facing |
| **Mutual support** | The overwatch element can actually cover the bound (`support_range_m`) | Kills by the overwatch element while the other bounds |
| **Suppression** | Base of fire pins them so the maneuver element lives (combat's L2, CP2) | Suppression applied per drill |

Measurements land in *Measurements* below as they are run. Some of them (dispersion vs. splash, suppression)
are only meaningful once combat's **L2 suppression** merges at CP2.

## Parity: the same library for both sides (X5)

The CPU commander assigns **tasks** to elements exactly as the player does; everything below that line —
formation, technique, drills — is this shared library. There is no CPU-only path, and no player-only one.
`ElementCommander` (`game/tactics/element_commander.gd`) is the whole CPU side of it: classify each element
(line, recon, support), pick an objective, hand out move / attack / screen / support-by-fire, and stop.

**What a spectator sees.** `make tactics-parity` runs a scripted match with a commander on both sides and
prints every element's shape, technique, drill and reason. From one run (seed 5, combined_arms vs
anvil_hammer, `build/tactics-parity.log`):

```
PARITY t=10s score 0:0 alive 5:5
  GREEN Battery: column, break contact — outgunned here: break contact and bound back | task support by fire
  GREEN Eyes:    column, break contact — outgunned here: break contact and bound back | task screen
  GREEN Guns:    line, near ambush — ambushed at 36 m: turn into it and assault through | task attack Rust_Anvil_1
  RUST  Anvil:   line, react to contact — contact: return fire, take cover, report | task attack Green_Guns_1
  RUST  Hammer:  line, far ambush — far ambush: pin them by fire, flank with the rest | task support by fire
PARITY t=40s score 2:4 alive 1:3
  GREEN Eyes:    column, break contact — outgunned here: break contact and bound back | task screen
  RUST  Anvil:   herringbone, traveling — halted in cover: herringbone, alternate flanks watched | task move
```

In one match the two sides between them used the wedge, the column, the line and the herringbone, and ran
react to contact, near ambush, far ambush, support by fire and break contact — all from the same tables. Every
line also carries the *reason*, which is what the HUD shows the player: nobody has to know what "echelon" means
to see that their element is refusing a flank because contact is likely.

## Faction doctrines (X6)

**The gangs are not a platoon (the lead, 2026-09-16).** Reviewing the doctrine page, the lead said the
factions read too alike: *"the street gangs for example should be noticeably less military disciplined and
intuitively I'm thinking they might use tactics of spreading out their formations wide for better
survivability or do circular swarms ... I suspect the street gang would also be more likely to create tactics
of having a vehicle draw fire to try and lead the opponents into an ambush."* That was fair: the tables
differed in *numbers* (spacing, legs, trigger distances) while every faction drew from the same eight
military formations. Three things came out of it, and one of them failed.

| Added | What it is | Verdict |
|---|---|---|
| **`swarm` shape** | Wide, ragged, staggered fore and aft: no line to shoot along, nearly twice a line's frontage. Not a formation any manual would recognise, which is the point | **Kept** — it is the gangs' character, and it costs no damage output (0.185 enemy survival against standard's 0.187) |
| **`bait` drill** | The fastest non-leader vehicle runs at them and leads them back over the pack, which waits off the line it returns along | **Kept** — against an enemy that chases: 0.58 of the pack alive against 0.43 without it, three survivors against two (one seed) |
| **`encircle` drill** | The pack rings the target and circles it, to spread incoming fire | **Switched off** — measured strictly worse (below) |

### Why encircle is off, and what it cost to find out

Same four vehicles, same enemy, same seed, only the doctrine differing:

| Doctrine | Pack survived | Enemy left | Arcs covered |
|---|---|---|---|
| gangs, swarm + encircle | 0.47 | 0.66 | 7 of 8 |
| gangs, **encircle off** | 0.47 | **0.19** | 5 of 8 |
| standard doctrine | **0.62** | 0.19 | 7 of 8 |

Turning encircle off left survival untouched and **tripled the damage the pack dealt**. Circling does not
protect them; it stops them shooting. And the coverage it was supposed to buy was already there without it —
the brains flank on their own, so a standard element covered the same seven arcs by simply fighting.

Two fixes were tried before giving up on it: slowing the ring from a turn every 1.5 s to every 4 s (a new
goal four times a minute throws away what a brain was doing — the round-3 lesson), and leaving any vehicle
already in range to fight instead of driving it to a place on the ring. Survival improved (0.35 → 0.47); the
damage loss did not. **The drill stays in the engine behind its table flag, with these numbers, so the
tactics-discovery harness or a suppression-era re-measure can revisit it — but no shipped table chooses it.**

The deeper lesson is the same one bounding overwatch taught: *doctrine that drives vehicles around fights the
brains that are already fighting well*. A drill earns its place by deciding **where an element goes and what
it points at**, not by micromanaging vehicles that have their own tactics.

### Round 14 (squad Q1): the drill that judged this was stale from birth, and today's numbers disagree

`make tactics-drills` failed two gang-pack assertions (*"the pack rings them or baits them"*, *"from more sides
than a standard element would"*). Bisected on builder0: **red at `9247ef48`, the commit that wrote them**, and at
every commit tested since (12 bisect steps plus that endpoint run directly). That same commit switched encircle off
(above) and made bait require a contact that follows, while the drill stages two dug-in guns, so neither drill
could fire there by design. The assertion was stale, not the behaviour. Now: against guns the pack must NOT lure,
must NOT circle, must fight (react to contact) from at least three arcs; against chasers (`bait_chase`) the gangs
must lure and the no-bait arm must not. Mutation-checked on builder0: bait without the follower rule, the gangs
without bait, and the gangs with encircle each turn it red. "More sides than standard" was dropped: it read 4–8
arcs across commits on one seed.

**Two readings for the lead, NOT acted on (C12.6; one seed each, builder0, the squad branch at `dca1d6cc`):**

| Arm | Pack survived | Enemy left | Note |
|---|---|---|---|
| gangs vs guns (encircle off, shipped) | 0.629 | 0.067 | today |
| gangs vs guns, **encircle switched on** | 0.632 | **0.002** | the 09-16 table read 0.66 with it on |
| gangs vs chasers, bait on (shipped) | **0.196** | 0.773 | 09-16: 0.58 alive with bait |
| gangs vs chasers, bait off | 0.258 | 0.541 | 09-16: 0.43 |

Both of the 09-16 verdicts have flipped since, on one seed each. Whether to re-measure them over seeds (and ship
encircle / drop bait) is a design question, written up for the lead in the squad brief.

### Round 15 (squad P1): over seeds, the 09-16 verdicts stand

`make squad-doctrine-series` re-measured round 14's two one-seed readings over 16 paired fights per opponent on the
yard and the Terminus (builder0, `efa49762`, seeds 1–8 each map, only the table differing; raw rows in
`streams/references/round15/squad/`). **Encircle stays off:** no gain against dug-in guns, worse against chasers
(enemy stronger in 12 of 15 fights that differed, p 0.035), the pack 6 % left against a standard element where the
shipped table keeps 19 %. **Bait stays on:** switching it off is a coin toss (6 / 9 against chasers, 8 / 8 against a
standard element), and flipping both is the worst arm against chasers (13 of 16, p 0.021). Round 14's 0.002 and
0.196 were single fights. **The lead chose "As shipped" on the decision page (2026-10-02 02:09 PDT); the table is
unchanged.**

### Round 15 (squad P4, P5): two drills that did not do what they say

Both found by measuring the gang pack over seeds (`make squad-doctrine-series`, `make gang-trace`), both fixed in the
plan rather than the table (no number in any `doctrine_*.json` changed), both with a flag that restores the old
behaviour as the mutation arm. The sim baseline is unmoved by both (builder0, `cf574701`, `make sim-hash-arm` with
each fix on and off: `6313a38d7ecd99bb` ×2 every arm): the baseline match never reaches either state.

- **Far ambush's maneuver half circled instead of turning in (P4, `--flank-turn-in=distance`).** It was told to turn
  in on the target only while within 18 m (`FLANK_ARRIVE`) of the flank point; turning in carried it out of that radius
  and the next update sent it back. The eastern scout's order flipped every 1.5–3 s and it drove circles by a crate
  (round 14's frames). Now it has turned the flank once it bears ≥ 65° off the line of contact from the target
  (`ElementPlan.turned_the_flank`); driving at the target keeps that bearing. The drill's own fight on builder0: guns
  dead at 21.3 s instead of 27.3 s, pack 0.748 left instead of 0.629. Over the series (yard + Terminus, 16 paired
  fights each) it took the enemy left against chasers from 0.63 to 0.42 and against a standard element from 0.56 to
  0.39, every arm sharing it.
- **Bait had no return leg (P5, `--bait-return=off`).** `_plan_bait` only ever ordered the runner AT them; the pack
  drove 55 m away to a hiding place re-taken from its own moving centre, and the drill ended when the chasers reached
  the runner, which was fighting alone. The lead's idea (*"a vehicle draw fire to try and lead the opponents into an
  ambush"*) had its first half only. Now the hiding place is fixed at the drill's start and the runner turns for it
  (a named move, gun on them) once it reaches the lure point or the live contact is inside 1.25 × `bait_min_m`.

### What the swarm costs today

The gangs' loose shape survives worse than military shapes in the one scenario measured (0.47 against 0.62)
while dealing the same damage. That is consistent with everything else here: **dispersion only pays against
weapons that punish bunching**, and splash does not yet (0.91 spread versus 0.93 bunched) and suppression
barely does. The shape is kept because it is the faction's character and the mechanic that should reward it
is being built; it goes back on the bench the day splash and suppression bite and it still loses.

### Who stands where inside a shape

The lead also asked whether formations account for composition: *"heavy armor on the outside of a column,
light armor on the inside."* They didn't; slots were handed out front-to-back by role. Now every shape scores
each slot's **exposure** — how far out of the middle it sits, and how far toward the front — and the
best-protected vehicle takes the most exposed one (`ElementPlan.by_exposure`). Artillery and Lancers are
pushed inboard whatever their armour says: on paper artillery out-armours a scout, but it is the thing the
element is out there to keep alive, and a gun being shot at is not shooting. The leader keeps slot 0, because
a leader that cannot see its element cannot lead it.

Same engine, different tables (`doctrines/doctrine_<faction>.json`).

| Faction | How they move | How they react |
|---|---|---|
| **The Condemned** | Close up (12 m in the open), line up and grind forward; a wedge when nothing is in sight (round 13: the default plain move; a column until then) | Charge ambushes from 42 m; `break_contact_ratio` 0.25 — they almost never withdraw |
| **Road gangs** | Vee at every threat level, always traveling, widest spacing (18 m), longest legs: a pack that never stops to cover itself | Charge from 55 m, flank 60 m wide, react in 0.7 s, and **no break-contact drill at all** |
| **The Law** | Bounding overwatch whenever contact is possible or worse, longest bounds with the widest supporting range | Deliberate: react for 1.5 s, flank 48 m, withdraw at 0.6 — the professionals leave a losing fight |
| **The Syndicate** | Echelon and line, traveling overwatch, stand-off ranges (110 m supporting range) | Only charge an ambush inside 22 m; `break_contact_ratio` 0.75 and a 115 m break distance: they reposition constantly |

## Publishing decisions: doctrine talks to the announcer (the lead, 2026-09-16)

> *"Rather than cluttering the UI, we can use that information to generate scripted statements from the
> announcers about how a squad is lining up in whatever formation for whatever reason. Presumably we at
> least want the structured data publishable."*

Every decision an element takes is published as **structured data in the K5 event shape**, on
`Elements.element_reported(event)`. Doctrine publishes values; the words belong to audio's line library. The
announcer's `MatchEventAdapter` already works this way for everything else — it only listens to signals and
never writes to the simulation — so wiring is one `connect`.

**Two event types.** Both carry `team`, `element`, `size` (vehicles alive) and `reason` (the doctrine table's
own `why`, so the booth can quote the element's logic instead of inventing one):

| Type | When | Extra fields |
|---|---|---|
| `element_formation` | The element changed shape or movement technique, took its first task, or came off a drill | `formation`, `technique`, `changed` (which of task/formation/technique moved) |
| `element_drill` | A battle drill **started** | `drill`, `formation`, `distance` (how far off the trigger was), `target` (what set it off) |

`tick` and `t` are not included: whoever puts an event into a timeline stamps them, exactly as
`MatchEventAdapter` does today. `make tactics-parity` writes a real one to
`build/tactics/element_events.jsonl` — 36 events from a 45 s, five-element match — so lines can be written
against a timeline instead of a guess:

```json
{"changed":["task","formation","technique"],"element":"Eyes","formation":"line","technique":"traveling_overwatch",
 "reason":"screening: a line watches the widest frontage","size":1,"t":1.0,"team":"green","type":"element_formation"}
{"drill":"break_contact","element":"Battery","formation":"column","distance":118.7,"target":"Rust_Anvil_1",
 "reason":"outgunned here: break contact and bound back","size":1,"t":5.3,"team":"green","type":"element_drill"}
```

**What the booth can actually say.** The announcer records every word in advance — there is no runtime
speech — so a *spoken* line can only key on the **enumerated** fields, and `reason` is subtitle-only (audio,
2026-09-16). The sets a shipped match can produce, which is the recording matrix:

| Field | Values a shipped table can emit |
|---|---|
| `formation` | `wedge`, `column`, `line`, `vee`, `echelon_right`, `herringbone`, `coil`, `swarm` (8) |
| `technique` | `traveling`, `traveling_overwatch`, `bounding_overwatch` (3) |
| `drill` | `react_to_contact`, `near_ambush`, `assault_through`, `far_ambush`, `support_by_fire`, `break_contact`, `herringbone`, `bait` (8) |

`ring` and `encircle` exist in the engine but **no shipped table selects them** (see *Why encircle is off*),
so nothing should be recorded for them; `echelon_left` is in the vocabulary but unused today. **These sets are FROZEN** by agreement with audio (2026-09-16):
`test_every_value_the_booth_has_to_speak_is_from_a_closed_set` asserts them exactly, and adding a shape or a
drill to a shipped table fails the build with an explanation. That is deliberate — the cost is invisible from
this side (each value is 8-16 recordings across the lines that name it) and the failure is silent (a value
with no clip doesn't error, it just makes those lines ineligible and the booth says something blander). To
add one: ask audio, then change the frozen list in the same commit as the table.

**The publisher is found by group, not by class.** `Elements` joins the `elements` group
(`Elements.GROUP`), because a listener on another branch cannot name a class that doesn't exist there yet.

**What doctrine filters out, so the booth doesn't have to.** An announcer that repeats itself is the exact
complaint the lead made about the PA, so the noise is cut where it is generated:
- an element with **no task** says nothing (before its first order it is parked, not "halting in cover");
- a **reason changing on its own** is not a call (the same wedge for a slightly different reason);
- a **leader change** is the HUD's business, not the booth's;
- the **same call is not repeated within 10 s** per element (`ElementReport.COOLDOWN_TICKS`), which is what
  stops an element that halts, moves and halts again from announcing the same herringbone three times;
- `element_drill` always means a drill **started**; coming off one reports as a shape change.

That took the sample from 43 events to 36 with nothing interesting lost.

## The code

| File | What it does |
|---|---|
| `game/tactics/element_task.gd` | The commander's task: verb, destination, target. Validates, so a typo fails loudly |
| `game/tactics/tactics_formation.gd` | Formation geometry, sectors of fire, frontage/depth/dispersion. Pure math |
| `game/tactics/doctrine_table.gd` | The doctrine files: parsing, strict validation, rule selection |
| `game/tactics/element_situation.gd` | The only impure step: what the element knows (members, contacts, terrain, threat) |
| `game/tactics/drills.gd` | Drill triggers, aborts and timeouts. Pure |
| `game/tactics/element_plan.gd` | The leader's decision: formation + technique + drill → one order per vehicle. Pure |
| `game/tactics/element.gd` | One element: roster, leader succession, task, plan state, issuing K1 orders, `state()` for the HUD |
| `game/tactics/elements.gd` | All elements of a match: form/of/disband, the update cadence, `element_changed`, `element_reported` |
| `game/tactics/element_report.gd` | A decision as a K5-shaped event for the announcer, and what is not worth saying |
| `game/tactics/element_commander.gd` | A CPU commander that assigns *tasks* to elements (parity demo, X5) |
| `doctrines/doctrine_*.json` | The tables: standard plus one per faction |

## Sketch: what an offline discovery harness would search (stretch)

game_design.md wants a harness that plays tactics against each other and distils what wins into deterministic
rules. Doctrine is already the right shape for that, because a doctrine is **data**:

- **The search space** is a doctrine table: the order of the movement rules, the formation and technique each
  one picks, the spacing per terrain, the leg lengths, and the drill numbers (`near_ambush_m`,
  `break_contact_ratio`, `flank_m`, `react_ticks`, …). A candidate is one JSON file.
- **The fitness** is the tournament ai already runs: table A against table B, same armies, same seeds, both
  sides swapped, scored on wins and on what survived.
- **The moves** are small and safe: change one number, swap one rule's formation, reorder two rules. Every
  candidate is still a valid table (the parser rejects anything that is not), and every candidate is still
  *readable* — which is the point, because what the harness finds has to end up as a rule a player can be told
  ("in close country, bound").
- **What must not happen:** a search that produces a table nobody can explain, or one that only wins because
  the CPU can run it and the player's elements can't. Parity is checked by construction: the player's elements
  use the same tables.

ai owns the harness; doctrine owns the format and will take its findings as new rows with a `why`.

## Measurements (X4)

Every number below comes from `make tactics-measure` (seeded, headless, `build/tactics/measurements.json`)
and `make tactics-drills`. Same arena strip, same enemy, same seed per trial: only the doctrine changes.

### Formations: four tanks walking into two dug-in guns at 80 m (seed 29, 20 s)

| Shape | Spacing | Survived (hull + shield) | First hit on them | Sector coverage | Frontage |
|---|---|---|---|---|---|
| **Wedge** | 14 m | **0.75** | **3.6 s** | 0.63 | 37.8 m |
| Line | 14 m | 0.63 | 3.8 s | 0.42 | 42.0 m |
| Column | 14 m | 0.57 | 8.0 s | 1.00 | 0 m |
| Wedge, bunched | 3 m | 0.67 | 7.4 s | 0.63 | 8.1 m |

The wedge at doctrinal spacing is the best of the four *into contact*: most of its guns bear forward, it is
still deep enough not to be one target, and it hurt the enemy in half the time the bunched element took. The
column is the safest shape for *seeing* (it watches the whole circle) and the worst for a fight to the front:
eight seconds before it did any damage, because only the lead vehicle can shoot. That is the trade the
doctrine table makes when it picks a column for a road march and a wedge when contact is possible.

**Dispersion versus splash: no effect yet.** Against artillery the same wedge survived 0.91 spread out and
0.93 bunched — inside the noise. Today's splash and the absence of suppression mean bunching is not punished,
so "spread out" currently rests on frontage and armour facing alone. *This is combat's L2 (CP2): re-measure
suppression and splash against `closest_pair_m` when it lands.*

### Movement techniques: the same advance into the same guns (seed 31, 24 s)

| Technique | Ground taken | Survived (before suppression) | Survived (with L2, 2026-09-16) |
|---|---|---|---|
| Traveling | 50–59 m | 0.74 | 0.75 |
| Traveling overwatch | 96–97 m | 0.74 | 0.74 |
| **Bounding overwatch** | 63–65 m | **0.51** | **0.60** |

**Bounding buys safety by having one element *set* and able to cover the other — and covering fire only means
something when it makes the enemy shoot worse or stop shooting.** Before suppression existed, the overwatch
element was simply a stationary target that was not advancing, and bounding cost a quarter of the element
against just driving.

**Re-measured with combat's L2 merged (2026-09-16): bounding went from 0.51 to 0.60, closing about a third of
the gap, while traveling did not move.** So the mechanism works in the direction doctrine says it should —
but bounding still loses, and the reason is known and specific: nothing deliberately suppresses. Combat
measures a mean of 0.03 suppression per living unit across 16 matches, with nothing ever pinned, because
brains only fire at things they can kill. What moved this number is *incidental* near-misses from ordinary
fire. The rest of the gap is the missing "keep firing into that lane" option (see below). If bounding still
loses once that exists — especially with a Law element and its sonic emitter behind it — then the honest
answer is that the tables should stop choosing it, and they will.

### A halt: jumped from the flank at 45 m (seed 37, 14 s)

| Shape at the halt | Survived | First shot back |
|---|---|---|
| **Herringbone** (hulls turned out to their sectors) | **0.93** | 1.62 s |
| Column (parked as it drove in) | 0.69 | 1.35 s |

Facing your flanks at a halt is worth about a quarter of the element. The parked column got its first shot
away marginally sooner (its guns were already pointed down the lane the enemy came from) and then paid for
every second afterwards, because its flank armour was toward the guns.

### Next: what suppression changes (combat's L2, measured on their branch)

Combat measured that suppression bites: a pinned tank hits 5 of 13 shells at 60 m where a calm one hits 13 of
13, and takes 208 ticks instead of 105 to swing its turret 90°; one machine gun settles a tank at 0.42
suppression, two at 0.82. **But over 16 seeded matches the mean suppression per living unit is 0.03 and
nothing is ever pinned**, because no unit ever fires at *ground it wants denied* — brains only shoot at
things they can kill. So the base of fire in a far ambush or a support-by-fire task suppresses nobody.

What that means for the drills, in order:

1. **A base of fire needs an order that means "keep firing into that lane".** K1 has no such verb and the
   brains have no such option (`fire_at_will`, `target`, `hold_fire`, and `aim` never fires — trip-up 25).
   ai owns that option; doctrine owns *where* it points, which is the drill's job. Until it exists,
   `support_by_fire` and the base of fire half of `far_ambush` are engagement orders, not suppression.
2. **Trigger drills off suppression, not just hits.** `Tank.is_pinned()` (above 0.6) is the honest trigger
   for react-to-contact and break-contact; `ElementSituation.suppression_of()` already reads `Tank.suppression`
   when the build has it and falls back to recent hits when it doesn't.
3. **Route the maneuver element around the beaten zone.** `Match.is_beaten_zone(team, from, to)` and
   `Match.threat_along(team, from, to)` let the far-ambush flank pick a lane that is not being swept; today it
   swings a fixed `flank_m` off the line of contact and takes whatever ground is there. (Note the signature:
   the contract wrote `is_beaten_zone(from, to)`, and combat added the team first, because incoming fire has
   to belong to somebody.)
4. **Then re-measure**, with `make tactics-measure`: bounding overwatch (0.51 today against 0.74 for
   traveling) is the number that should move, and dispersion against splash is the other. Both halves of the
   trade should flip together — the base of fire starts buying something, and the element that bounds behind
   it starts surviving.
5. **The sharpest test will be a Law element** (combat's X4 rosters): the **sonic emitter** applies 4.0
   suppression per second in a cone, about ten times a machine gun, and the **gas rocket truck** 5.0 a burst
   over 14 m — both with almost no damage. They are suppression *delivery systems*, so an element built
   around "shut it down, then walk in" is where support by fire either pays or visibly doesn't. The Law's
   table already bounds at every threat level; if suppression works, that table should stop being the
   cautious one and start being the effective one.

### Which of these the booth can quote (audio, 2026-09-16)

Audio takes measured facts as the Veteran's material — he is the only one in the booth allowed to be precise,
and a number a player can act on beats one that merely sounds authoritative. Recording is expensive and
permanent, so each measurement is marked with whether it is expected to **hold**:

| Measurement | Quote it? | Why |
|---|---|---|
| A column watches the whole circle, a line 0.42 of it | **Stable** | Pure geometry: it follows from the shapes, not from any tuning |
| A column takes ~8 s to hurt anything; a wedge 3.6 s | **Stable** | Frontage and how many guns can bear — mechanics that exist today |
| Halting in a herringbone keeps 0.93 against 0.69 parked | **Stable** | Armour facing, which is real and measured |
| Bunching to 3 m shoots later (7.4 s) as well as dying more | **Stable** on the timing | The delay is frontage; the survival half is not (see below) |
| Circling an enemy deals a third of the damage | **Stable** | It is about interrupting brains, not about a pending mechanic |
| Bounding overwatch costs survival (0.60 vs 0.75) | **Will move** | Suppression is half-built; nothing deliberately suppresses yet |
| Dispersion does nothing against splash | **Will move** | Splash and suppression are being changed by combat |
| The gangs' swarm survives worse than military shapes | **Will move** | Same reason: it is waiting on the mechanic that rewards spreading |

**The standing arrangement:** a measurement that surprises us goes to audio, marked stable or not; only the
stable ones are worth recording, because a recorded line outlives the number that justified it. If a
measurement ever says "the booth should *always* mention this", that is a request for a tag priority, not for
more lines — volume doesn't get a line past the priority queue.

### Drills (seed per scenario, `make tactics-drills`)

| Drill | What happened |
|---|---|
| Near ambush | Sprung at 25 m; the element turned into it, drove through to 1.9 m of the ambush position and out the far side **6.3 s** later; both ambushers destroyed, no losses |
| Far ambush | React to contact, then fire and maneuver: the base of fire held **4.6 m** off the line of contact while the other half swung **24.3 m** round; both guns destroyed, 3 of 4 alive |
| Bounding | A section was **set 38%** of samples while the other moved, and the element still made 50 m |
| Break contact | Outgunned pair broke from 76 m to **106 m**, both alive |
| Herringbone | Halted, all-round security, **1.0** of the circle watched |

## Who may command the player's army (ruled 2026-09-17, enforced in code)

The lead, after playing: *"if they get sucked into combat I have no control whatsoever."* Three rules, each with a test:

1. **An `ElementCommander` never runs on the player's team.** It is the CPU's commander; the player's army takes its
   orders from the player (`ElementCommander._physics_process`, `OrderFeed.player_team`).
2. **An element never takes a unit off an order whose `source` is `"player"`,** and on the player's team a leader with
   no task commands nobody at all. This is L1's round-4 sharp edge — *"an element with no task still runs its SOP, so
   forming one before it has a task makes its leader fight the player for the wheel"* — which was written down for a
   round and broken anyway. A rule that isn't enforced by code is a rule that will be broken.
3. **A leader re-issues only when the intention changed.** "Attack" and "attack-move" at one target, and "move" and
   "hold" at one place, are the same intention; a standing order already follows a moving target, so the same intention
   is not handed over again inside `Element.RE_ISSUE_TICKS` (2 s). Everything an element issues carries
   `source: "element"`. Before this, an army with nobody touching the controls produced ~35 order changes a second,
   each one a marker redrawn and a cue played on the player's screen (*"these blue dots ... they just keep repeating"*)
   — and the frames to draw them.

Tests: `tests/test_tactics_reissue.gd` (nothing but the player orders the player's squad; no repeat of an intention a
unit is already carrying), `tests/test_ai_player_orders.gd` (ordered across contact and arrives; squads land on their
slots and stay). The other half of that bug was control's: a plain right-click on a squad was an element task by
construction, so the invariant had nothing to protect until they made it a direct player order.

## Round 15 (squad P2): the ladder's reference, and the rule it was taken under

**A ladder's ELO is a statement about `Match.result`'s winner rule, and that rule changed at `5f562dd0`** (garage G3: an
elimination match that hits the time limit is judged on points destroyed, equal = draw; before, on tanks standing then
total health). So `tools/tactics_ladder.py` now hashes the code that decides `winner` (`result` up to the winner,
`_points_lost`, `_team_standing`; comments ignored), prints `WINNER RULE <hash> <name>` and a rule column beside every
ELO, stores it in the json, and `--compare REF.json` (`make tactics-ladder LADDER_COMPARE=…`) **refuses, exit 3**, to
set a run beside a reference taken under another rule or another workload (army, arenas, factions, budget, control,
runs, first seed, time limit, extra flags, sides). Known rules: `8013ff13f91d` r13 (before `5f562dd0`), `cc490e53eeb9` r14.
`tactics-pytest` (in `check`) holds the refusal and the kept reference to the current rule: **a change to the winner
rule turns `check` red until the ladder is re-baselined** (`make remote T=tactics-ladder-reference`, copy the json).

The reference, `tools/tactics/ladder_reference.json` (builder0, game code = main `85703220`, rule r14, the defaults:
brains / standard / faction on x4t9, `combined_arms` mirror, foundry yard boulevard pit boneyard, 2 seeds × 4, 240 s;
120 matches, 0 failures):

| Side | ELO | W–L–D | vs brains | vs standard | vs faction |
|---|---|---|---|---|---|
| brains (no elements) | 1032 | 47–33–0 | — | 29–11 | 18–22 |
| faction (each faction's own table) | 1014 | 44–36–0 | 22–18 | 22–18 | — |
| standard | 954 | 29–51–0 | 11–29 | — | 18–22 |

Round 5's "doctrine beats brains 52–28" in this mirror was taken under the r13 rule and an older tree, so it is
**not comparable** with these rows (the script would refuse); taken at face value they say the brains have caught up
with the standard table, and a faction's own table still edges them. Every number above is on the code before this
round's P4/P5 drill fixes: re-run the ladder on the merged tree before reading a drill change into it.

## Round 5: what the tactics ladder says doctrine is worth (ai, 2026-09-17)

`make tactics-ladder` (unit_ai.md) plays doctrine variants, brains and arenas against each other and charges every
landed round to what the units were doing. Three results, in the order they changed what we believed:

1. **Doctrine wins small and loses large.** In five-vehicle `combined_arms` mirrors with no objective, armies under
   doctrine beat the same army on brains alone 52-28 (120 matches, five arenas). In faction armies at the 5200 budget
   with the control point on — the game the lead plays — brains alone beat faction doctrine 32-16 (48 matches, gangs vs
   law both ways; gangs under doctrine 6-18). These are two different games, and the second is the one that counts.
   Whether the control-point objective or the drills at scale is to blame is being isolated (control point off, and
   trimmed tables, all from one snapshot) — see the ai brief's Status for the answer. The skirmish CPU stays on brains
   until a doctrine beats them in that setup.
2. **An exchange ratio attributes an outcome to whatever was selected, not to what caused it.** far_ambush traded
   0.16-0.26 over 44 deaths and looked like the worst drill in the book. Removing it changed nothing (standard without
   far_ambush 55-65 overall, 20-20 head to head against standard): it is chosen in fights that are already going badly.
   **The only way to know what a behaviour costs is to remove it and measure the army with and without.**
3. **break_contact is a net loss** in the mirror ladder: standard without it went 91-29, and beat standard on every
   arena (30-10 head to head). Cut pending the faction runs at scale, where it traded 1.27.

**The rows behind all of this are kept**: `streams/references/round5_ai_ladders.json` has one line per match for the
five ladders (the mirror doctrine run, the 240-match drill-variant run, and the fac1b / fac2 / fac3 faction runs, all
three from one snapshot, `fc88c24`) — sides, arena, seed, swapped bases, factions and winner, with each run's ELO and
head-to-head. The full logs and per-drill ledgers lived in a worktree's git-ignored `build/` and are gone; these are
what a round-6 re-run compares against without spending the machine time again. Reading them caught one mis-stated
number in the ai brief (fac3's trimmed table went 23-25 against brains, not 24-24).

**The discovery loop produced a candidate, and the ladder rejected it.** The scripted `pin_and_flank` policy
(tools/discovery.py) beat standard doctrine in its first exploratory run, was distilled into
`ElementCommander._pin_and_flank` (behind `traits.commander`), and then lost 43-77 across 240 matches. That is the loop
working: it finds candidates, not answers, and a candidate ships only if it wins the ladder.

### Proposal for round 6: an army-level decision above the elements

**Why.** Doctrine was written for, and wins at, the scale of a platoon: a few elements with one task each. At 30 a
side every element runs the same `ElementCommander` plan — line elements attack the nearest contact or move on the
objective, the rest support by fire — so a whole army converges on one point, and the drills that decide *where an
element goes* (the round-4 rule) all decide the same place. Arena measured the symptom from the map side: flanking
lanes used 4-5% of unit-time on the dense maps. What's missing is not a better drill; it's the decision a company
commander makes before any drill runs: **which elements take the objective, which shape the fight around it, and
which stay back.**

**What it would be.** An `ArmyPlan` (pure, like `ElementPlan`) that the `ElementCommander` consults every
THINK_TICKS, over the army's elements and the arena's annotations (`Arena.lanes_of`, `regions_of`: centre,
chokepoint, flank, overlook, cover_cluster):
- **Main effort:** the strongest one or two elements take the objective (the control point, or the enemy's mass).
- **Supporting effort / base of fire:** elements with long reach take overlooks or cover clusters with a line on the
  main effort's objective (`support_by_fire` there, not at the nearest contact).
- **Shaping:** one element per annotated flank lane, sized by composition (light and fast first), with a timing
  rule — it moves before the main effort commits, and attacks only once the base of fire has the enemy pinned
  (the pinned signal x5p now keeps).
- **Reserve:** whatever is left holds back and is committed where the exchange is going best.
- **Faction flavour lives here,** not in drills: gangs put most elements on the lanes (the pack gets around you),
  the Law keeps a large base of fire and bounds the main effort, the Syndicate trades main effort for overlooks and
  standoff.

**Before building it, re-run the verdict.** Every ladder behind "doctrine loses at scale" was played by armies that
charged from the first second (the player's army was built by the CPU generator, fixed 2026-09-17) and by x4t9 brains,
not today's champion. **The prediction, recorded before the run:** doctrine gains, and may pass brains-only with the
control point off. If it still loses with an approach phase, the drills are exonerated and this layer is the remaining
explanation.

**How it would be proven.** The same bar as everything else: a table trait (`traits.army`) the tactics ladder turns
on, played in faction armies at the 5200 budget with the control point on, against brains-only and against the
current commander, counterbalanced both ways, and adopted only if it wins. The discovery harness is the right tool
to explore allocations first (`tools/discovery.py` commands whole elements; the pin-and-flank result is a reminder
that its candidates must be ladder-proven, not trusted).

### Round 7 result: the verdict re-run, and the army layer measured (X8)

Both on builder0, trees at squad `1d011765`, faction armies gangs v law at 5200, control point on, yard/boulevard/pit/
boneyard, 2 seeds × 4 ways per pairing, x5p brains, armies starting as an army (ArmyLayout, the approach phase):
- **The verdict:** brains-only 51-13 over the faction doctrine (64 matches). The prediction above (doctrine gains with an
  approach phase) is **refuted**. The ledger named the direct commander: support by fire held 72% of doctrine's time at
  exchange 0.58.
- **The army layer** (`ArmyPlan`, `traits.commander = "army"`, the ladder's `+army`: main effort, base of fire, shaping on
  the lanes with a pin-then-go rule, reserve): 192 matches, brains 108-20, faction direct 51-77, **army 33-95**, army v
  faction 26-38. It fixed the allocation (SBF 72% → 25%) and lost more: far ambush took over (54% of time, exchange 0.92),
  and **every drill traded below the brains' 1.24** (SBF 0.97, bait 0.72, react to contact 0.50, assault through 0.38).
- **So:** at 30 a side the element layer's drills cost more than any allocation above them buys. The next question is
  per-drill, not per-army: which drill, removed (lesson 25), stops costing exchange — far ambush first, by time.
  `+army` stays off; the code is the measured candidate, not a default.

## Round 20 (brains): his attack obeyed, the computer's opening measured, the ambush hides its line

**His attack on a named target runs no elective drill (M1b, DECLARED, `8ed06b70`, main `cdc59a84`).** He ordered 25 Rat
Rods to attack one Law vehicle and four squads ran the gangs' BAIT on sight (one scout forward, four holding 45 m back
and backing toward their start line while the Law did not chase): *"they all spread out and drove away"*. The drills
a pack CHOOSES (`Drills.ELECTIVE_DRILLS`: bait, encircle) give way when the element is his (`state.player`) and the task
is `attack` with a `target` (`Drills.obeys_attack`); one already running stops. Reactions to contact are unchanged.
The computer's packs keep them, and so does his movement without a named target (an attack-move into the open), which
is where "spread wide" and "one draws them on" are the gang feel he asked for. Scenario `test_tactics_attack_obeyed`.

**The opening (M2): built, measured, shipped OFF (`--cpu-opening`).** A side nearer a ring than the enemy, with an
ambush site on the way to it, takes that ring and holds from the start (`Posture.near_ring`, `Posture.decide`'s
`opening`). `make opening-series` (both sides from their spawns at 0–0, builder0, 8 paired seeds): he rushes at once →
no ambush in either arm (always in contact first), score margin +2.6 ± 4.3; he sets off after 10 s → the round-19
posture already ambushes 8 of 8 and the opening 7 of 8, CPU-minus-his alive −2.38 ± 4.07; the Sumps' near ring has no
site → identical. On parade round 19's attack already heads for that same near depot and holds once ahead. **Lesson:
"lie in wait from the start" adds nothing where the attack objective is already the near ring, and nothing can be
laid against a rush.**

**The ambush hides the LINE (M3, DECLARED).** `AmbushSite.find(…, line, timing)` ranks spots by how many of the
element's crews — its line laid at the spot facing the kill zone, as `ElementPlan` lays an ambush — the enemy can see,
then by distance, keeping only spots it can reach in time (the commander's in-time rule, per candidate: the first build
picked the best-hidden spot, which was farther toward the enemy, and the commander then refused it as late, losing
round 18's ambush). No line = round 19's answer exactly. On parade round 19's spot left 1 of 4 crews in his sight; the
new one, 14 m down the bay, none. **Series** (`make hides-series`: round 19's hold stage, parade, builder0, 24 paired
seeds, line − point): spring +2.20 s (se 1.00), his loss +214 hit points (se 100), CPU-minus-his alive +1.25 (se
0.80), the CPU better in 11 seeds and worse in 8; the Open Yard has no site (identical runs). **Cost:** none where the
map has no site; a search 1.17× / 1.17× / 1.02× the point search's time on parade / the Open Yard / the Sumps (laptop,
cold memo, 300 cases; `test_the_line_search_costs_little_more_than_the_point_search` bounds it), and only while CPU
squad leaders run. **Lesson: 8 seeds put each measure inside its noise; 24 put all three on one side at 1.6–2.2 se.
Ship on a mechanism you can see (a hidden line springs later, deeper in the kill zone) plus measures that agree.**

## Open questions and requests

_See the stream's Status in `_agents/streams/archive/round4/doctrine.md`._
