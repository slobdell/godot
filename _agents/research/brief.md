# Research brief: deterministic real-time tactical simulation with high per-agent and per-formation intelligence

## What we want from you

We are building a real-time tactical simulation and we want an aggressive, wide-ranging set of **design and algorithmic
proposals** to raise the apparent intelligence of its agents — both **individually** and as **coherent higher-order
structures** (fire teams, squads, companies).

Please return **as many concrete, named techniques as you can justify**, each with: the canonical reference, what it
would replace or augment here, what it costs at runtime, whether it survives our determinism constraint, and — this
matters — **how we would know it worked**. We would rather have twenty candidates with honest trade-offs than three
recommendations.

Assume we are competent at implementation and weak at knowing what exists. Breadth is more valuable than depth. If a
technique is standard in robotics, operations research, control theory, computational geometry or animation and we have
not listed it, we probably have not heard of it.

---

## 1. The system, abstractly

- **Continuous 3D ground domain**, bounded arena, static obstacle geometry, no terrain deformation during a run.
- **Heterogeneous vehicle agents**, order 40–90 per side. They differ by an order of magnitude in every physical
  dimension: hull lengths from ~2.8 to ~14 metres, tracked / wheeled / hover locomotion, turreted or hull-fixed weapons,
  differing turn rates, turning circles, speeds, sensor ranges and weapon envelopes.
- **Three-layer decision stack**: a per-agent policy; an element/squad layer issuing shared tasks with formation slots;
  an army layer allocating elements to objectives.
- **A human player issues orders** at squad granularity (move, attack-move, hold, screen, ambush, support-by-fire,
  follow) and expects them to be obeyed *and to look obeyed*.
- **Fixed-timestep simulation** at 30 Hz. Physics is a commodity rigid-body engine; navigation is a commodity navmesh
  service with A\* over polygons.

## 2. The hard constraint: bit-level determinism

**Identical inputs must produce bit-identical state, on the same binary.** This underwrites replays, lockstep networked
play, and a regression fingerprint we hash every build against.

Consequences we have already lived:
- Transcendental functions differ across standard-library versions, so our fingerprint is keyed per library version.
- Any iteration over a hash map must be ordered explicitly.
- Iteration counts must be fixed, not convergence-based.
- Wall-clock time may never enter the simulation.

**This rules out runtime-learned policies and anything with nondeterministic parallelism or floating-point reduction
order.** We would be very interested in techniques that recover the expressiveness we lose — in particular
**fixed-point or integer arithmetic** in the simulation core, and **deterministic replacements for convergence loops**.

## 3. The offline budget is effectively unlimited — this is the opening we most want exploited

We accept **arbitrary offline computation**: search, optimisation, simulation-based tuning, and machine learning of any
scale, **provided the artefact that ships and executes inside the tick is deterministic**.

This is the single most important framing in this brief. We want proposals of the form *"compute something expensive
offline; ship a frozen, deterministic artefact; execute it cheaply and reproducibly at runtime."* Candidates we have
thought of, to show the shape rather than to bound it:

- Policies distilled from expensive offline search into decision trees, lookup tables, or quantised fixed-point networks
  evaluated in a fixed order.
- Behaviour parameters tuned by offline optimisation against measured objectives rather than by hand.
- Precomputed spatial structures: corridor decompositions, clearance-aware roadmaps, visibility and threat fields,
  per-hull-class navigation graphs.
- Offline trajectory libraries indexed by vehicle class and manoeuvre, executed by table lookup at runtime.

**Tell us what else this framing unlocks.** Where is the state of the art in "expensive offline, deterministic online"?

## 4. What is already in place

So you propose additions rather than re-derive what we have:

**Navigation and motion**
- A\* over a navigation mesh, with corridor-funnel path smoothing.
- Reciprocal collision avoidance (ORCA-family) between agents.
- PID control for formation station-keeping.
- Context steering (a direction ring scored by interest and danger) for movement during engagements.
- Arrival-with-standoff for hull-fixed weapons: stop inside the effective band and fire rather than closing to contact.
- A rate limit on angular acceleration in the vehicle plant.
- A heading-aware arrival: a car-like hull routes to a gate short of its goal along the desired final heading and drives
  the last leg straight, so it arrives pointed correctly rather than rotating on arrival.
- A multi-point-turn "creep" for car-like hulls asked to rotate near a point.

**Decision**
- Per-agent utility scoring over discrete options, with a commitment/hysteresis term favouring the incumbent option.
- A doctrinal layer of battle drills triggered by situation (react to contact, break contact, ambush, support by fire).
- Influence fields for threat, cover and fire lanes — **computed but not yet used for route selection**.

**Known gaps we have named but not built:** hierarchical pathfinding; model-predictive lookahead over candidate
manoeuvres; curvature-continuous path generation for car-like hulls; clearance that accounts for hull *length* rather
than width alone.

## 5. Measured pathologies — the honest state

All of these are measured, not impressions. We would value proposals aimed at them specifically, and proposals that
suggest we are measuring the wrong things.

1. **Direction churn.** Under a fight-your-way-there order, roughly **6% of an agent's travelling time** is spent
   oscillating — eight metres of path in four seconds yielding less than a quarter of that in net displacement.
   Decomposed: about **70% is motion re-planning inside a single unchanged decision**, and 30% genuine option switching.
   Agents re-aim roughly **45 times per agent-minute**.
2. **Gear flipping.** Car-like hulls reverse and re-advance within the same two-second window **9–19 times per
   agent-minute**, depending on class. Roughly a third of these are under orders that legitimately request reverse; a
   third are the multi-point-turn creep; the remainder are unexplained.
3. **A veto does not work where a preference does.** We tried forbidding target switches faster than the agent's own
   target-acquisition time. Switch-and-switch-back **more than doubled**. Our reading: suppressing the expression of a
   decision the scoring still wants stores up pressure rather than removing it.
4. **Crowd-flow routing was a measured null.** Shared cost-to-goal fields (Dijkstra over navmesh polygons, read as a
   gradient) answered 70–75% of route requests and changed stuck-time by **about −1% across three seeds**. Our reading:
   the technique amortises when many agents share one destination, and in a fight destinations are per-agent.
5. **Scale breaks systems silently.** Three separate subsystems were implicitly sized for a ~4 metre hull: the
   deployment grid, formation spacing, and *cover*. The first two failed loudly. **Cover fails silently** — the longest
   cover object is shorter than our longest hull, so that hull drives to cover, registers as *at cover*, and is not
   covered.
6. **Clearance is under-modelled.** Our corridor clearance uses hull width only, and the navigation mesh is baked with a
   single agent radius for every vehicle regardless of size.
7. **Obeying and looking obedient are different properties.** Under a fight-your-way-there order agents spend 30–36% of
   their time driving somewhere other than the ordered destination — correctly, because they are fighting — and the
   player reads this as disobedience. We have partially addressed this with UI, but we suspect there is a *motion
   planning* answer we are missing.

## 6. The standard we are trying to exceed

The genre's best-regarded exemplars achieve **legible, responsive, individually-plausible unit behaviour** and
**formations that read as deliberate**. Our goal is explicitly to exceed that bar on two axes:

- **Individual plausibility.** Each vehicle should move like the machine it is: an articulated heavy hauler should
  behave nothing like a light scout. Manoeuvres should look *intended* rather than corrected — no visible hunting,
  snapping, or re-deciding.
- **Higher-order coherence.** Squads should hold recognisable shapes in motion, transition between them deliberately,
  and manoeuvre relative to each other in a way a human observer reads as *tactics* rather than as flocking. We want
  base-of-fire-and-manoeuvre to be legible to a spectator.

An important asymmetry: **we are willing to trade raw optimality for legibility.** A formation that arrives four seconds
later but arrives *as a formation* is a better outcome for us. Please weight proposals accordingly, and tell us where
the literature has studied legibility directly (we are aware of legible-motion work in human-robot interaction and would
welcome more).

## 7. Specific areas where we invite proposals

Non-exhaustive; the list is a prompt, not a boundary.

- **Path generation and smoothing.** Curvature-continuous curves for car-like bodies; clothoid/Euler-spiral transitions;
  Dubins/Reeds–Shepp families and their practical failure modes; trajectory optimisation; when splining is the wrong
  abstraction and a trajectory library is better.
- **Waypointing and corridor structure.** Hierarchical decomposition; clearance-aware roadmaps; per-vehicle-class
  graphs; how to represent "a route a 14-metre articulated hull can actually take" as a first-class object.
- **Local avoidance under heterogeneity.** Reciprocal schemes assume comparable agents; ours differ by 5× in footprint
  and cannot all yield equally. What handles asymmetric, non-holonomic, size-heterogeneous crowds?
- **Decision stability.** Hysteresis, dwell, commitment, dominant-option scoring, option-space smoothing — what actually
  prevents thrash without producing stubbornness, given our evidence that a hard veto backfires?
- **Lookahead.** Deterministic, fixed-horizon, fixed-iteration model-predictive approaches; how to score candidate
  manoeuvres cheaply enough for 90 agents at 30 Hz.
- **Formation control.** Virtual structures, leader-follower, behaviour-based and optimisation-based formation keeping;
  formation *transitions*; formations that deform around obstacles without dissolving.
- **Multi-agent task allocation.** Deterministic assignment (auction, Hungarian, and their stable variants) for
  allocating elements to objectives and slots to agents, including stability under re-solve.
- **Spatial reasoning.** Using influence, threat and visibility fields for route *selection* rather than only for target
  selection; tactical position evaluation; cover and concealment as first-class spatial queries for bodies of arbitrary
  length.
- **Offline-to-online distillation.** The framing in §3 — we want this pushed hard.
- **Determinism engineering.** Fixed-point simulation cores; deterministic substitutes for iterative solvers; safe
  parallelism; cross-platform reproducibility strategies.
- **Evaluation.** How to measure "looks intelligent" and "looks coherent" quantitatively. We have found that
  time-allocation metrics and trajectory metrics answer different questions and that we repeatedly measured the former
  while the human complaint was about the latter.

## 8. How we work, so proposals land usefully

- We pre-register a success metric and a revert condition **before** building anything, and we have deleted three
  changes this cycle that failed their own bars.
- We treat a change that cannot be measured on the configuration a player actually experiences as unproven.
- We prefer a smaller mechanism whose failure mode is understood over a larger one that is merely better on average.

**So: for each proposal, tell us the metric that would falsify it.** A technique we cannot test is one we cannot adopt.

---

## 9. Three open questions we cannot answer ourselves

1. **Is per-agent path ownership the right architecture at all** for 40–90 heterogeneous vehicles with per-agent
   destinations, given that shared-gradient routing measured as a null for us?
2. **Is there a principled cadence for re-deciding** — derived from the agent's own sensing and actuation limits rather
   than tuned — that prevents churn without producing stubbornness?
3. **What is the right representation of "a body of length L can pass through here"** when L varies by 5× across the
   roster and the navigation mesh is shared?
