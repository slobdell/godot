# Research brief 2: what we measured after adopting your proposals, and the questions we cannot frame ourselves

## What we want from you this time

Our first brief asked for breadth and got it: fifty named techniques, twelve adopted with a pre-registered falsifier
each. This brief is different. **We built and measured, and most of what we built failed its own bar or was inert.**
We think the reason is not the techniques but the frame we put them in, and we cannot see our own frame. So:

- **Tell us what we did not consider.** Every section below ends with a question. We would rather have one reframing
  that makes a question dissolve than ten techniques that answer it as posed.
- Where you propose something, keep the form we asked for before: the canonical reference, what it replaces, the
  runtime cost, whether it survives bit-level determinism (identical inputs → bit-identical state at a fixed 30 Hz
  step; no wall clock, no unordered iteration, no convergence loops), and **the metric that would falsify it**.
- Assume the same system as before: a bounded continuous 3D ground arena with static obstacles; 40–90 heterogeneous
  vehicle agents per side spanning ~2.8 to ~14 m in length, tracked / wheeled / hover, turreted or hull-fixed; a
  three-layer stack (per-agent policy, element/squad with formation slots, army allocation); a human issuing orders
  at squad granularity who expects them obeyed **and seen to be obeyed**; commodity rigid-body physics and a commodity
  navmesh; unlimited offline compute, deterministic artefacts online.
- Two things the first brief omitted and you told us so: the heaviest vehicle is an **articulated tractor and
  trailer**, and **balance moved when the roster was rescaled** and we still do not know why. Both are below.

---

## 1. What happened when we built your round: an honest ledger

We adopted twelve rows. Here is what each did when measured on the configuration a player actually experiences, with
the pre-registered bar it was measured against. We include this because the pattern across them is the first question.

| Row | Built | Measured | State |
|---|---|---|---|
| Self-triggered replanning (state-error tube) | yes | the real driver of re-plans was a sliding station, not the rate; fixing that removed 62 % of re-decides with latency intact; the tube itself killed four more agents on one seed | off behind a multi-seed gate |
| State-dependent switching cost (multiple-Lyapunov dwell) | yes | suppresses about half the churn a flat commitment bonus does; costs nothing where the bonus already applied; the dwell timer was measured inert across two rounds and deleted | opt-in |
| Hull-chord cover (directional summed-area tables) | yes | correct; the previous cover check had never measured cover | on |
| Clothoid primitives with priced cusps | yes | fails its arrival bar: the curved entry does not arrive; 70 % of arc refusals are "off mesh", split 474 recoverable / 361 unreachable by any straight run-in | off |
| Anisotropic route selection over influence fields | not built | — | candidate |
| Legibility objective + dual-heading law | contract signed, code opt-in | honestly inert: it needs a corridor the movement layer does not publish | off |
| Null-space priority projection | yes | cannot go on by default: the movement layer that runs nine ticks in ten has no leash to project against | opt-in |
| Affine deformable formations | yes | **made a wedge fail a defile it passes without it**; never applied to a plain move at all | off |
| Co-arrival + explicit bounding overwatch | yes | works; but a 20 m move now takes ~40 s to settle (22 s to declare arrival, ~20 s for crews to stop) because pacing waits on the slowest member | on |
| Deterministic auction with incumbent bonus | yes | broke an unwritten rule ("heavies in front") that the old matcher's tie order had enforced by accident for months | stood down |
| Dynamic-window arcs | yes | cannot act without the projection row | opt-in |
| Trajectory-space metrics | yes | reproduced our earlier oscillation numbers to 0.05 points and showed the threshold understated the problem ~4×; found the shuffler is the wheeled hull, not the light one | on; every verdict reads from it |

Beside these, three findings from the same weeks:

- **Every one of the motion rows trips on one seam.** The layer that *decides* a hull's motion (a context-steering
  scorer with the tactical picture) is active in under a tenth of a hull's ticks; a lower movement layer (route
  following, avoidance, unsticking) drives the other nine tenths and knows nothing about formation, leash, corridor or
  legibility. Rows that express intent at the decision layer are inert; rows that express it in the slot layout are
  overridden by the mover.
- **A rotation constraint froze an army.** Our plant resolves a hull's *translation* against collision every tick and
  applies its *rotation* unconditionally, so long hulls rotate through walls (a 14 m hull yawing in a 4.8 m corridor
  sweeps 12 m of footprint through the building). We added a rule: a candidate yaw that increases penetration is
  refused, retrying at 0.6 and 0.3 of the wanted step. In a corridor it removed 74 % of the illegal yaw. In a formed-up
  army it **froze four of five squads at their spawn positions**: their first turn toward the goal was refused, and the
  refusal counter never reset for 1100+ consecutive ticks. We ranked the refusing hulls by lateral room: a hull with
  3.19 m of clear space beside it refused as long as one with 0.06 m. The only hull that seated was in the squad
  ordered *first*. We have no mechanism. The rule is off.
- **Eleven measurements were retracted in one week, all one shape:** the thing under test was never selected (a
  tuning knob written to a static that a later initialiser clobbered; a control arm in which the mechanism could not
  act; a lint that checked zero files; a scenario passing on a neighbour's leaked state; a "frozen" capture pair that
  was not frozen). The null looked like a measurement every time.

**Q1. Is there a name for what we are doing wrong?** We adopt a technique, build it in the layer it is described for,
measure it on the configuration a player experiences, and find it inert or harmful because a lower layer that was
"just execution" is where the behaviour actually lives. Is this a known architectural failure in layered agent
systems, and what is the known remedy: move intent down, move execution up, a shared constraint object both layers
read, something else? We are asking about the *shape* of the fix, not a technique.

---

## 2. Rotation is not collision-resolved, and making it so deadlocks

Detail for the freeze above. The plant is a kinematic body: each tick it computes a desired velocity and yaw rate,
sweeps the translation against static and dynamic colliders (the engine's move-and-slide), and applies the yaw as an
unconditioned transform update. Long hulls therefore rotate through geometry; short hulls never notice.

The rule we tried: before applying a yaw step, test the hull's box at the candidate orientation against the world and
against other hulls; if penetration increases relative to the current pose, try 0.6× and 0.3× of the step; if all
three increase penetration, refuse the step this tick. This is correct in a corridor and catastrophic in a
formation. Our best reading: two hulls formed up nose-to-tail or abreast are already *in contact* (or within the
collision margin), so every candidate compares against a non-zero current penetration and the deepest contact
(a squadmate) masks the wall term; and because *both* hulls refuse, neither ever moves, so neither ever clears the
other. A "world-only" mask removed the freeze in one arm and produced a frozen hull in the corridor case in another,
which told us our two arms were two different penetration measurements, not one mask.

**Q2. How do others make rotation collision-aware for long kinematic bodies in dense groups without deadlock?**
Rotational depenetration, swept rotation tests, capsule or multi-circle hull approximations that make yaw monotone in
penetration, penalty-based rotation, "who yields" rules for mutual blocking (priority, ordering, randomised but
deterministic tie-breaks), reservation of a turning envelope before the turn. Which of these are standard in
vehicle-crowd simulation and in multi-robot manoeuvring in confined space? Is the right answer that a formation must
*assign turning room* (a slot pitch derived from the half-diagonal, not the width) before any rotation rule can be
correct, or is there a rule that is correct at any spacing?

**Q3. Is a kinematic body with a separate rotation step the wrong plant altogether** for vehicles whose length is
5× their width? What do vehicle-crowd simulations at this heterogeneity use: full dynamic bodies, kinematic bodies
with swept-box tests, or a decoupled "reference path + tracking controller" where geometry is checked on the path and
the body only follows?

---

## 3. The articulated vehicle

The heaviest unit is a tractor and a 12 m trailer. Today the tractor is the simulated body and its collider is one
14 m box; the trailer is *drawn* hinged at the fifth wheel by tractor-trailer kinematics from the drawn motion, so it
looks articulated and collides as a rigid slab. A shell can pass through the empty air inside a fold. We accepted
that for a round; we would like to know what the honest next step is.

**Q4. What is the minimal deterministic articulated model** that gives us off-tracking, a jackknife limit, reverse
behaviour a player recognises, and a collider that follows the trailer, without a second dynamic body and a joint
solver (iterative, therefore suspect under our determinism rule)? Two kinematic bodies with an analytic hinge
constraint? A single body with a swept "trailer path" collider recomputed from the tractor's path history? Where is
this done well in games or simulators, and what does routing look like for such a vehicle (turning templates, swept
path analysis)?

**Q5. Road-design practice.** Civil engineers design intersections and streets so that a chosen *design vehicle*
can make every turn (turning templates, swept-path analysis). Our arena is a small city with 20 m streets and 40 m
blocks and the player drives a 14 m articulated hull through it. Is there a compact, deterministic version of swept-
path analysis we can run **offline per map per vehicle class** to certify each street, corner and gap as drivable,
refuse routes that are not, and tell the *player* (a legibility problem: he cannot tell whether a street is blocked
or merely narrow)? What is the canonical reference, and what does the artefact look like: a per-class navmesh, a
corridor graph with per-edge minimum clearance and maximum curvature, a turning-template lookup?

---

## 4. Clearance, spacing, and the number that is right in one place and wrong in another

We found that one geometric quantity, the disc of a hull's box diagonal, is used in two roles with opposite errors:
as *where the hull is* (friendly-fire and incoming-fire tests: it overstates a 14 m × 3.3 m hull as a 14.4 m circle,
so gangs refuse safe shots) and as *the room the hull needs to turn* (correct). Our formation spacing, spawn grid and
navmesh bake all derive from *width*; our avoidance radius derives from *(width + length)/4*; the navmesh is baked at
one agent radius for a roster whose avoidance radii range 1.2–4.6 m. We have written a rule: every clearance constant
must state which motion it licenses (driving straight: width; turning in place: the half-diagonal; a swept turn:
something between).

**Q6. Is there a standard vocabulary and a standard set of objects** for this (footprint, swept footprint, turning
envelope, minimum passage width, configuration-space obstacle per orientation) that a game should adopt wholesale, so
that "clearance" stops being one number? In particular: per-class navigation meshes vs one mesh with per-edge
clearance annotations vs a 3-D (x, y, θ) configuration-space grid computed offline — what do practitioners use at
90 agents and 30 Hz, and how do they keep the runtime query cheap and deterministic?

**Q7. Local avoidance across a 5× footprint range and non-holonomic kinematics.** Reciprocal schemes measured as
the live mechanism in our worst failure (61 % of ticks deflected in a corridor, no arrival in 70 s, and none of our
three pre-registered explanations survived). What replaces or constrains reciprocal avoidance for long car-like bodies
in corridors: right-of-way protocols, corridor reservations, lane discipline, velocity obstacles in (v, ω) space,
something from traffic microsimulation rather than from crowd simulation?

---

## 5. The player's order, the squad's task, and the forty seconds

The player right-clicked while a squad was en route and nothing changed. We found three candidate mechanisms in our
own code (an order de-duplicator comparing formation slots rather than clicks; a squad task whose per-crew orders
are re-derived by a leader that suppresses re-issue; an armed command mode that spends the click on a cancel) and
we are fixing all three. But the deeper number is: **a 20 m move takes ~40 s to settle** with co-arrival pacing on,
because arrival is declared when the slowest member could reach its slot and crews only stop when every slot is
dressed. He felt that before he saw any heading.

**Q8. What does the literature say about acknowledgement vs execution latency in real-time command interfaces?**
Thresholds at which a player judges units "not responding"; whether an immediate visible acknowledgement (a crew
turning its nose, a pin) buys tolerance for slow execution; how formation assembly time should be traded against
arriving as a formation (we have said we will trade optimality for legibility, and we now suspect we traded too much).

**Q9. When should a formation declare arrival, and who stops when?** Assembly and dressing of a formation at a
destination, especially with non-holonomic members that cannot neutral-steer to an ordered facing (a wheeled hull
holds whatever heading its last travel left it on: our crews end 1°, 16°, 41° and 28° off the ordered facing). Is
there a standard treatment of terminal-heading assembly for car-like agents in formation (a short arc off the slot
and back, a three-point turn, a slot pitch that leaves room for it, an assembly order)?

**Q10. Forming an element from an arbitrary selection.** The player box-selects any units and wants fire-and-
manoeuvre orders (support by fire, screen, ambush). We must split any heterogeneous set into base and manoeuvre
elements on the fly. Role assignment for ad-hoc coalitions under heterogeneity: is there a principled, deterministic
assignment (by weapon envelope, mobility, position relative to the approach) that the player will read as sensible,
and a literature on how players *expect* such splits to be made?

---

## 6. Balance moved when scale moved, and we do not know why

We rescaled every vehicle to real relative size (one factor, anchored on the 14 m tractor-trailer). One matchup went
from 9 wins in 20 to 0 in 20 on one map, unchanged on another; the faction with the long hull lost. We have
evidence against "shuffling" and against splash; "bigger target" survives by elimination only; the disc-of-diagonal
error above (the long hull's AI refusing safe shots and over-reacting to incoming fire) is a candidate mechanism we
will test with an oriented-box arm. Balance is explicitly not being tuned; we want the cause.

**Q11. How does hull geometry enter engagement outcomes** in symmetric-rules vehicle combat: exposure as a function
of aspect, hit probability against long vs short targets, the value of length as cover for followers, and how AI
target selection interacts with target size? Is there a methodology for attributing a win-rate shift to geometry vs
to the AI's *reading* of geometry, short of the full factorial we are about to run?

---

## 7. Lighting a venue for readability, at zero runtime cost

The arena is a night venue: neon-edged towers, shopfronts, signage. The player asked for a light show on the building
walls, "basic primitives to adjust individual lights on the building" composed into effects. We built a channel
engine (breathe, chase, strobe, sweep, cycle; cues bound to match mood and events) that drives per-fixture uniforms at
zero added lights and zero added draw calls, and it reads as nothing because one uniform breathes every window on a
block together. We are moving to per-window addressing (per-instance data on instanced meshes). Our hard rule is that
the fight must remain the brightest read on screen: a gate measures the luminance of the venue against its own null.

**Q12. What do stage lighting, architectural media facades and the demoscene know** that a game team would not think
to ask? Cue-list and fixture vocabularies (DMX-style patching), chase and effect engines, low-cost per-pixel facade
animation (flipbook textures, precomputed light animation baked offline, signed-distance-based emissive masks),
readability rules from lighting design (value contrast, silhouette, where the eye goes), and how to *measure* that a
venue supports rather than competes with the action. Anything on "expensive offline, one scalar per frame online".

**Q13. Legibility of passable space.** The player could not tell whether a container-strewn street was blocked or
merely cluttered. What does level-design and environmental-storytelling literature say about signalling
traversability (affordance cues, kerb vs road, lit vs unlit, colour and material language), and is there any
measurement of it?

---

## 8. Commentary

A recorded-clip commentary system (three voices; tagged clips stitched at runtime by a beat grammar with memory,
callbacks and anti-repetition) whose limit is pool size per moment: the player hears repetition within a match at
small pools. We are about to generate more lines.

**Q14. What is known about perceived repetition in procedural commentary:** pool sizes at which listeners stop
noticing repeats, the value of variation in delivery vs variation in text, memory and callback structures that make a
fixed library feel unbounded, and how sports-game commentary systems structure their libraries (moment taxonomies,
slot fillers, intensity ladders)? We are also interested in the *authoring* side: how to generate hundreds of lines
on a fixed comedic register (understated, one detail slightly wrong, never a punchline) and audit them.

---

## 9. Measurement

**Q15. We keep measuring nulls that look like results.** A control arm in which the mechanism could not act; a
knob that never reached its predicate; a test passing on a neighbour's leaked state; a capture pair that was not
frozen. We now require every arm to *prove it applied* (a counter that moves, a differ-assertion first). Is there a
discipline or literature for experimental hygiene in simulation A/B work (positive controls, arm-proof, pre-
registration) that we should be copying rather than rediscovering one lesson at a time?

**Q16. Perceived intelligence.** We measure trajectory efficiency, cusp density, spectral arc length and formation
residual, and they agree with the player's complaints better than time-allocation metrics did. What is known about
which measurable properties of NPC motion predict a human rating of "smart" and "obedient", and is there a cheap
proxy for the rating itself short of user studies?

---

## 10. How to answer

Breadth still matters, but **reframings matter more**. For each section: first tell us if the question is wrong, then
answer the right one. Assume competent implementers who are weak at knowing what exists outside their field, and who
will pre-register a falsifier for anything they build. Where two of your proposals would compose badly, say so; the
composition hazard cost us more than any single technique did.
