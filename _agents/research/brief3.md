# Four open problems in deterministic multi-agent simulation, posed abstractly

For each problem we want: the canonical references, the standard methods, the known failure modes, and a measurable
criterion by which a proposed answer could be shown wrong. Breadth over depth; name what exists rather than derive it.

## 1. Authoring safe corridors for many agents under a fixed compute budget

Consider a layered motion architecture in which a slow deliberative layer (~3 Hz) hands a fast execution layer
(30 Hz) a *safe invariant set*: a chain of convex polytopes along a route, plus a stationarity bound, onto which the
executor projects its control inputs. The literature on reference governors and sequential composition of funnels
treats such a set as given. **Who computes it, and at what cost, for 40–90 heterogeneous non-holonomic agents with
distinct destinations, each deliberative step, deterministically (fixed iteration counts, no wall clock, ordered
iteration)?** Inputs available: a polygonal navigation mesh with per-polygon clearance, static obstacle geometry,
each agent's footprint and turning envelope, and the other agents' current reservations. Questions: (a) what is the
standard construction of a corridor polytope chain from a navmesh corridor (portal funnels, Minkowski-shrunk
polygons, safe-flight-corridor style decompositions), and its complexity per agent; (b) how are corridors kept
disjoint or prioritised between agents without an iterative negotiation; (c) what degrades gracefully when the
deliberative layer misses a step (corridor starvation); (d) what is the offline/online split — can corridor
families be precomputed per vehicle class per map and selected at runtime by lookup? Falsifiable claim wanted: a
cost model in polytope count per agent per step, and the condition under which the executor's projection is
guaranteed feasible.

## 2. Attributing an outcome shift to geometry versus the agents' model of geometry

Two symmetric-rules teams of simulated vehicles fight repeated matches; every rule and controller is unchanged
except that every body's physical dimensions were rescaled by realistic ratios (lengths now span 5×). One team's win
rate fell from ~45 % to ~0 %. The agents' own decision code represents bodies by simplified proxies (a bounding disc)
for line-of-fire and threat evaluation, so the shift may come from (i) physical exposure, (ii) the proxies' error,
(iii) an interaction with formation and movement behaviour, or (iv) a change in which behaviours the controllers
select. A 2 × 2 factorial over {physical size} × {proxy model} is the obvious design. **What is the principled
methodology beyond that factorial?** Sensitivity analysis and variance decomposition over behavioural mediators in
agent-based combat models; mediation analysis for simulated interventions; counterfactual replay (re-simulating one
team with the other's perception); how to size the experiment when each match is minutes long and determinism
removes within-seed variance; and known results on how target geometry (aspect-dependent exposure) enters engagement
models. Falsifiable claim wanted: an attribution estimate with an uncertainty, and a pre-registrable prediction for
an arm we have not yet run.

## 3. Perceived variety in finite-library procedural speech

A commentary system plays pre-recorded whole-sentence clips selected by a tag grammar with memory (moment, speaker
role, intensity, context flags), with recency penalties, over sessions of 5–15 minutes and across many sessions.
Three fixed speaker roles with distinct registers (an excitable play-by-play caller, a dry expert, a polished
corporate host whose lines are ordinary except for one flat, slightly wrong detail). **What is known about when
listeners perceive repetition, and how to measure the perceived variety of a finite library without a user study
each time?** Recency-priming and working-memory models of phrase recognition; pool size per context needed for a
target repeat-perception rate; whether variation in delivery (prosody, timing) substitutes for variation in text;
information-theoretic or n-gram measures of a library's diversity that correlate with listener judgements; and, on
the authoring side, methods for generating and auditing hundreds of lines against a fixed register (deadpan, no
punchline) with an automatic classifier as the gate. Falsifiable claim wanted: a proxy measure of perceived
repetition validated against human ratings, with the pool sizes at which it saturates.

## 4. Measuring the legibility of traversable space from a fixed overhead camera

A player views a cluttered urban ground scene from a fixed elevated camera (~21° pitch, narrow field of view) and
must judge, without probing, whether a street is passable for vehicles of various sizes. Design languages exist
(material, lighting temperature, obstacle height, kerb marking), but we want **measurement**: can a viewer predict
passability correctly from one frame, which visual features predict correct judgement, and is there an automated
proxy? Relevant: environmental affordance and wayfinding studies in level design; visual attention and saliency
models applied to traversability; psychophysics of gap and passage judgement (perceived passability of apertures
relative to body size, extended to vehicles the viewer does not embody); and image-based predictors (contrast,
silhouette continuity, ground-plane visibility) that could be computed in a render test. Falsifiable claim wanted: a
per-frame score that predicts human passability judgements above chance, and the feature it depends on most.
