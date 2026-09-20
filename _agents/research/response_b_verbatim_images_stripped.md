# **Deterministic Real-Time Tactical Simulation Architecture**

Tactical fidelity and kinematic plausibility in real-time simulation do not fail because agent policies lack complexity; they fail because reactive steering architectures conflate topological routing, non-holonomic trajectory tracking, and tactical decision dynamics into uncoordinated, high-frequency local loops1. The observed pathologies—such as a 6% traveling oscillation rate, 45 re-aims per agent-minute, gear flipping up to 19 times per minute, and silent cover failures for 14-meter hulls1—stem directly from coupling discrete decision selection to instantaneous velocity obstacles on a single-radius navigation mesh1. Under strict bit-level determinism at 30 Hz, reactive steering rings and unconstrained local replanning inevitably induce limit cycles and high-frequency thrash1.

The primary operational remedy is a decoupled hierarchical architecture operating on frozen offline artifacts. Global route topology must be separated from local non-holonomic tracking by establishing clearance-annotated swept-volume corridor roadmaps. Simultaneously, local reactive steering rings must be replaced with offline-generated curvature-continuous motion lattices and deterministic priority-space reservations. Discrete decision thrash must be stabilized by routing utility deltas through leaky-integrator drift-diffusion accumulators rather than hard temporal vetoes1.

By shifting spatial search, continuous curvature optimization, and behavioral parameter extraction into precomputed offline pipelines, online execution is reduced to deterministic table lookups, fixed-iteration linear solvers, and fixed-point polynomial evaluations. This architecture scales predictably across 180 active agents (40–90 per side)1, satisfies bit-level cross-platform determinism invariants, and delivers tactical formations that appear deliberate, legible, and physically grounded.

## **Resolving Foundational Simulation Architectures**

Addressing the three foundational design questions requires establishing rigorous kinematic and operational invariants before selecting individual algorithms.

### **Corridor Allocation with Per-Agent Trajectory Ownership**

Shared cost-to-goal gradient fields (crowd-flow Dijkstra fields) measured as an operational null—reducing stuck-time by merely 1% across multiple seeds1—because the fundamental assumptions of continuum crowd dynamics fail in tactical ground combat. Continuum crowd formulations require homogeneous agents sharing identical velocity profiles, unified target sinks, and isotropic turning capabilities. In tactical domains, 40–90 agents per side possess radically heterogeneous physical footprints (2.8 to 14 meters), distinct locomotion dynamics (tracked, wheeled, hover), and disparate standoff envelopes1. More critically, agents do not seek the same goal point; they pursue distinct tactical micro-destinations (cover wedges, firing gates, formation slot offsets) under dynamically opposing threat vectors1.

The correct structural paradigm is a Hierarchical Topology-Corridor Sharing with Per-Agent Trajectory Ownership architecture. At the squad and element layer, agents share a topological corridor: a sequence of convex 3D polygonal portals and bounding medial-axis channels. This corridor defines the mutual homotopy class of the maneuver, preventing the formation from splintering around obstacles. Inside that shared corridor, each agent owns an independent, dynamically feasible space-time trajectory parameterized as a continuous curvature curve ![][image1]. Local interactions between friendly agents are resolved not by re-evaluating global gradients, but by time-parameterized along-track phase adjustments (speed profiling and longitudinal braking) within the allocated spatial tube.

### **Kinematic Commitment Horizons as Principled Decision Cadences**

Arbitrary fixed-interval polling (such as re-evaluating utility every ![][image2] ticks) and hard temporal vetoes (such as locking decisions for the duration of a weapon reload or target-acquisition timer) consistently fail1. A hard veto acts as an infinite-slope potential barrier on an underlying continuous utility landscape; when an alternate target becomes objectively superior, the agent's internal scoring continues to accrue preference differential. The instant the veto timer elapses, the latent pressure discharges, flipping the decision immediately, only to flip back when transient local conditions alter the balance, doubling switch-and-switch-back oscillations1.

A principled re-decision cadence must couple directly to the agent's kinematic commitment horizon, defined by the time required to dissipate current mechanical momentum or traverse the non-holonomic turning radius. For a vehicle with forward velocity ![][image3], maximum longitudinal deceleration ![][image4], minimum turning radius ![][image5], and heading error to target ![][image6], the kinematic commitment horizon ![][image7] is governed by the stopping and turning horizons:

![][image8]

An agent cannot execute a new spatial maneuver until its current commitment horizon has dropped below a critical threshold or a catastrophic hazard invalidates the current state trajectory. Furthermore, high-frequency option evaluation must be passed through a continuous leaky integrator rather than a discrete gate. The decision state transitions only when the accumulated evidence exceeds a threshold calibrated to the mechanical time constant of the plant, matching the Nyquist rate of the physical vehicle.

### **Curvature-Constrained Swept-Volume Capsule Decompositions**

Representing clearance for hulls ranging from 2.8 to 14 meters on a shared navigation mesh cannot be achieved via uniform polygon shrinking or scalar agent radius inflations1. A single scalar radius bakes an implicit circular assumption into the spatial graph, causing 14-meter hulls to scrape corners or falsely report corridors as navigable when their articulation limits prevent turning.

The robust spatial representation decomposes each vehicle into an oriented chain of spheres (or swept-sphere capsules) along its longitudinal axis. A 2.8-meter scout is represented by two overlapping bounding spheres of radius ![][image9]; a 14-meter heavy combat hauler is parameterized as a kinematic chain of five bounding spheres of radius ![][image10] separated by fixed chord lengths ![][image11]. Corridor traversability is governed by the swept volume of this capsule chain along a path segment with local curvature ![][image12].

The shared navigation structure remains a single, un-inflated Medial Axis Transform (MAT) skeleton graph computed on the static obstacle geometry. Each edge in the MAT graph stores a continuous clearance function ![][image13] representing the distance to the nearest static boundary. An edge is traversable by a vehicle of length ![][image14], width ![][image15], and minimum turning radius ![][image5] if and only if three geometric invariants hold:

![][image16]

![][image17]

![][image18]

Where ![][image19] is the kinematic position of the ![][image20]\-th capsule center along the curve at path coordinate ![][image21]. By precomputing the MAT graph and evaluating the capsule chain sweep against annotated edge bounds, a single static navigation representation guarantees strict clearance verification for arbitrary hull dimensions without maintaining separate physical navmeshes for every unit class.

## **Root Causes of Measured Simulation Pathologies**

The pathologies reported in system telemetry1 are mathematically coupled symptoms of reactive steering and unconstrained discrete scoring. The operational failure modes and structural remedies are detailed below.

&nbsp;

| Measured Pathology | Empirical Telemetry | Algorithmic Root Cause | Structural Remedy |
| :---- | :---- | :---- | :---- |
| **Direction Churn** | 6% time oscillating; 45 re-aims/min; 70% motion replan, 30% option switch1. | Context-steering direction rings re-sample local danger/interest fields every tick without curvature constraints or trajectory memory1. The velocity vector hunts across local optima. | Continuous-Curvature (CC) Clothoid paths coupled with a Leaky-Integrator Decision Accumulator. Path re-planning is restricted to path-parameter updates. |
| **Gear Flipping** | Car-like hulls switch forward/reverse 9–19 times/min1. | Standard Reeds-Shepp metrics evaluate shortest geometric distance without a gear-shift penalty (![][image22]). Small target shifts invert arrival tangent signs. | Reeds-Shepp metric with high explicit cusp penalty (![][image23]) and a dynamic hysteresis band on reversing maneuvers. |
| **Veto Backfire** | Hard switch vetoes doubled switch-and-switch-back oscillations1. | Hard temporal locks suppress expression while underlying utility deltas continue to integrate unchecked. The accumulated pressure forces an immediate snap back1. | Continuous Drift-Diffusion Leaky Integrator. Latent utility deltas must continuously overcome a dynamic decay leakage rate before a switch triggers. |
| **Crowd-Flow Routing Null** | Shared Dijkstra fields yielded \-1% stuck-time improvement1. | Uniform potential gradients cannot accommodate heterogeneous footprints, non-holonomic limits, or disparate tactical goals1. | Homotopy Class Corridor Funneling with Per-Agent Space-Time Reservation intervals inside the allocated topological tube. |
| **Silent Cover Failure** | Long hulls (14m) register as "at cover" while protruding beyond obstacles1. | Cover queries evaluate scalar point-in-polygon or single-ray line-of-sight tests against cover objects shorter than vehicle hulls1. | Oriented Bounding Box (OBB) shadow projection and Multi-Capsule Threat-Ray Casting against extruded obstacle shadow volumes. |
| **Clearance Breakdown** | Corner clipping and hull collisions in tight terrain1. | Shared navmesh baked with a single agent radius; corridor clearance evaluates width only, ignoring non-holonomic swept chord length1. | Swept-Volume Capsule-Chain clearance checks over an offline-annotated Medial Axis Transform (MAT) topology. |
| **Perceived Disobedience** | Agents drive 30–36% off-axis under attack-move orders1. | Tactical standoff, threat evasion, and weapon-alignment context vectors override the primary formation transit vector1. | Legible Motion Optimization (Dragan formulation) combined with decoupled Turret/Hull orientation controllers and explicit Standoff Gates. |

### **The Dynamics of Churn and Oscillations**

Direction churn occurs when an agent's steering vector is updated at the simulation tick rate (30 Hz)1 using instantaneous potential fields or context rings. Context steering maps candidate headings into discrete directional bins, evaluating an objective function ![][image24]. When an obstacle or another vehicle crosses a ray, ![][image25] changes discontinuously. Because the vehicle plant has an angular acceleration limit1 but the planner outputs an unconstrained instantaneous target velocity, the controller enters a persistent limit cycle: the planner commands an immediate heading switch, the rigid-body plant begins slewing toward it, the resulting displacement alters the context ray scoring, and the planner commands a reverse slew before the vehicle ever aligns with the original vector.

### **The Mathematics of Veto Failures**

Let ![][image26] and ![][image27] represent the continuous utility scores of incumbent target ![][image28] and challenger target ![][image29]. Suppose a temporal veto enforces ![][image30] before an agent may switch targets. If ![][image31] at time ![][image32], the agent is forbidden from switching until ![][image33]. During this latency, if ![][image27] remains higher than ![][image26], the underlying preference gradient points entirely toward ![][image29]. At ![][image33], the switch to ![][image29] fires instantly. If the agent's initial motion toward ![][image29] marginally elevates the threat score or breaks line of sight, ![][image26] momentarily exceeds ![][image27], initiating another veto cycle back to ![][image28]. Suppressing the switch does not dampen the high-frequency components of ![][image34]; it acts as a sample-and-hold phase lag, which destabilizes closed-loop feedback systems.

## **Precomputed Spatial Structures and Offline Artifact Distillation**

An unconstrained offline budget transforms real-time simulation architecture: instead of evaluating complex, iterative non-linear programs inside the 30 Hz tick1, the online runtime evaluates frozen geometric structures, deterministic lookup tables, and quantized fixed-point networks.

The offline pipeline generates four categories of immutable runtime artifacts:

> 1. **Pre-Baked Signed Distance and Curvature Fields (SDF-CF):** Static obstacle geometry is discretized into high-resolution 3D signed distance fields stored as uniform grid octrees. In addition to scalar distance ![][image35], cells store principal curvature vectors ![][image36], enabling vehicles to compute exact analytic obstacle normals and clearance gradients in ![][image37] time without runtime polygon intersection tests.  
> 2. **Homotopy-Annotated Medial Axis Skeleton:** The arena's free space is skeletonized into a 1D Medial Axis graph. Every edge is pre-annotated with:  
   * Bottleneck clearance width ![][image38] and clearance length ![][image39].  
   * Maximum allowable vehicle wheelbase ![][image40] and articulation angle ![][image41].  
   * Topological homotopy winding numbers relative to static terrain obstacles.  
> 3. **Discrete Non-Holonomic Motion-Primitive State Lattices:** For each vehicle class, millions of two-point boundary value problems (BVP) are solved offline to construct a regular state lattice. The online runtime ships with an immutable lookup table storing trajectories parameterized by initial curvature, terminal pose, path length, and swept capsule bounding boxes.  
> 4. **Distilled Policy Partition Trees via Evolutionary Optimization:** Utility scoring weight vectors and tactical drill transition thresholds are not hand-tuned. Instead, Covariance Matrix Adaptation Evolution Strategies (CMA-ES) optimize behavioral parameters offline across tens of thousands of automated multi-agent skirmishes. The resulting policies are distilled into exact, branchless binary decision trees evaluated via integer bit-masks.

## **Non-Holonomic Path Generation and Motion Control**

The proposals in this section eliminate gear flipping, hunting, and kinematic snapping by generating paths that are strictly curvature-continuous (![][image42] or ![][image43]) and dynamically executable by the underlying vehicle physics.

### **Continuous-Curvature Clothoid Steer Paths**

* **Canonical Reference:** Fraichard, T., & Scheuer, A. (2004). *From Reeds and Shepp's to continuous-curvature paths*. IEEE Transactions on Robotics, 20(6), 1025–1035.  
* **Replaces / Augments:** Replaces corridor-funnel path smoothing combined with multi-point-turn creep1.  
* **Mechanics & Implementation:** Standard Dubins and Reeds-Shepp paths connect straight lines to circular arcs of minimum radius ![][image5]. This produces step discontinuities in curvature ![][image12] at transition points, demanding infinite steering rate ![][image44], which physical vehicles cannot track. Continuous-Curvature (CC) paths insert clothoid (Euler spiral) segments between lines and circular arcs. Along a clothoid, curvature varies linearly with arc length: ![][image45], where ![][image46] is the sharpness parameter2. Sharpness is bounded by the vehicle's physical steering actuation rate ![][image47] and speed ![][image3]2:

![][image48]

Online, the path generator connects the current vehicle pose ![][image49] to the local goal pose ![][image50] using precomputed elementary CC-turns.

* **Runtime Cost & Profiling:** Evaluated in ![][image51] per agent on an x86-64 core. For 90 agents at 30 Hz, execution consumes ![][image52] per tick. State memory is 128 bytes per active trajectory.  
* **Determinism Assessment:** Survives. The Fresnel integrals underlying clothoid computation are precomputed offline into a 1D lookup table (64 KB, 4096 samples) using fixed-point Q16.16 values. Online path evaluation uses deterministic linear interpolation on integer indices.  
* **Pre-Registered Falsification Metric:** Direction churn drops from 6% to ![][image53] of traveling time1; vehicle plant tracking error ![][image54] decreases by ![][image55]. Revert if path generation failure rate exceeds ![][image56] in cluttered terrain.

### **Reeds-Shepp Metric with High Cusp Penalties**

* **Canonical Reference:** Reeds, J. A., & Shepp, L. A. (1990). *Optimal paths for a car that goes both forwards and backwards*. Pacific Journal of Mathematics, 145(2), 367–393; augmented with gear-shift cost models (Fraichard & Mermond, 1998).  
* **Replaces / Augments:** Augments the heading-aware arrival logic and multi-point-turn creep1.  
* **Mechanics & Implementation:** The standard Reeds-Shepp metric identifies the path minimizing total length ![][image57]. In tactical spaces, this causes extreme gear flipping: selecting a path that reverses 0.3 meters to save 0.5 meters of forward turning. The metric is redefined to penalize cusps (gear transitions):

![][image58]

Where ![][image59] is the cusp penalty, and ![][image60] penalizes reverse driving. Paths requiring gear switches are rejected unless forward-only paths are geometrically obstructed by static obstacles.

* **Runtime Cost & Profiling:** Reeds-Shepp analytic word selection evaluates 46 motion primitives. Analytical evaluation costs ![][image61] per query. Re-planning is evaluated only upon path initialization, not per tick.  
* **Determinism Assessment:** Fully deterministic. Word selection relies entirely on closed-form algebraic and trigonometric evaluations executed via fixed-point math tables.  
* **Pre-Registered Falsification Metric:** Unexplained gear flipping drops from 9–19 times/min1 to zero. Intentional reversals occur only when clearance constraints prevent a pure forward loop. Revert if unnavigable goal errors increase by ![][image62].

### **Offline Precomputed Motion-Primitive State Lattice**

* **Canonical Reference:** Pivtoraiko, M., Knepper, R. A., & Kelly, A. (2009). *Differentially flat motion control for wheeled mobile robots via state lattices*. Journal of Field Robotics, 26(3), 307–333.  
* **Replaces / Augments:** Replaces context-steering direction rings for movement during engagements1.  
* **Mechanics & Implementation:** Vehicle kinematics are discretized into a regular state lattice ![][image63]. Offline, a boundary value problem solver generates the exact, dynamically feasible, minimum-time trajectory connecting every local lattice node within an 8-meter horizon (generating 32 to 64 discrete trajectories per vehicle class). Each trajectory primitive stores its swept bounding volume (capsule chain), entry/exit kinematic states, and profile duration. Online, the agent evaluates the static clearance and threat score of the 32 precomputed trajectories using SIMD integer operations and selects the optimal primitive.  
* **Runtime Cost & Profiling:** Evaluating 32 precomputed primitives costs ![][image64] per agent. For 90 agents, online search requires ![][image65] per tick. Static memory footprint is ![][image66] per vehicle class.  
* **Determinism Assessment:** Survives. The search evaluates a static array in a fixed sequential loop. Trajectory selection uses strict lexicographic tie-breaking: ![][image67].  
* **Pre-Registered Falsification Metric:** Re-aiming frequency drops from 45 times per agent-minute1 to ![][image68] times per agent-minute. Revert if search fails to find a collision-free primitive in open terrain (![][image69] clearance).

### **Homotopy Class Corridor Funneling**

* **Canonical Reference:** Bhattacharya, S., Likhachev, M., & Kumar, V. (2012). *Topological constraints in search-based robot path planning*. Autonomous Robots, 33(3), 273–290.  
* **Replaces / Augments:** Replaces navmesh polygon corridor-funnel smoothing1.  
* **Mechanics & Implementation:** Standard funnel smoothing snaps string-pulled paths tightly against obstacle vertices, leaving zero clearance for long hulls. Homotopy funneling computes corridors characterized by Cauchy's integral theorem / winding numbers across static obstacle poles. It finds the optimal topological channel that maintains a guaranteed clearance tube ![][image70] around the homotopy center-line, generating smooth bounding polygons through which the vehicle's capsule chain can pass without touching boundary corners.  
* **Runtime Cost & Profiling:** Computed once per squad movement order via topological graph search. Amortized runtime is ![][image71] per squad order.  
* **Determinism Assessment:** Fully deterministic graph search. Obstacle poles and winding numbers are evaluated in fixed coordinate space using integer cross products.  
* **Pre-Registered Falsification Metric:** Corner clipping incidents for 14-meter hulls drop to exactly zero in 500 automated play-test hours. Revert if path compute latency exceeds 5 ms for an entire squad.

## **Spatial Clearance and Threat Topology Integration**

These proposals upgrade static navigation meshes to support variable vehicle scale and ensure influence fields directly inform route selection1.

### **Swept-Volume Capsule-Chain Corridor Clearance**

* **Canonical Reference:** Schulman, J., Ho, J., Lee, A., & Abbeel, P. (2014). *Finding locally optimal, collision-free trajectories with sequential convex programming*. Robotics: Science and Systems (RSS).  
* **Replaces / Augments:** Replaces single-radius navmesh corridor clearance1.  
* **Mechanics & Implementation:** Hulls are parameterized as an ordered sequence of spheres ![][image72] defined in vehicle-local coordinates. For an agent traversing path ![][image73], the swept volume is the Minkowski sum of the capsule chain along the curve. Clearance validation against static polyhedral obstacles evaluates the sphere-to-segment distance for each capsule center:

![][image74]

Because the capsule centers are kinematically linked by the vehicle's wheelbase and articulation angle, turns naturally push rear capsules inward along the turning curve (off-tracking).

* **Runtime Cost & Profiling:** Precomputed during motion primitive validation. Online validation takes 40–80 ns per trajectory primitive using AVX2 vectorized distance calculations.  
* **Determinism Assessment:** Survives. Distance calculations use fixed-point dot products and square-root evaluations from an integer LUT.  
* **Pre-Registered Falsification Metric:** Hull collisions in static geometry for heavy haulers drop to zero. Revert if corridor rejection rate exceeds 20% in standard passages.

### **Medial Axis Transform Graph Clearance Profiles**

* **Canonical Reference:** Lee, D. T. (1982). *Medial axis transformation of a planar shape*. IEEE Transactions on Pattern Analysis and Machine Intelligence, 4(4), 363–369.  
* **Replaces / Augments:** Augments the commodity navmesh graph1.  
* **Mechanics & Implementation:** During the offline build, the 2D arena floor plan is processed into a Voronoi diagram of static obstacle edges, yielding the Medial Axis Transform (MAT). Each edge on the MAT represents the path of maximal clearance between obstacles and is annotated with its continuous clearance profile ![][image13]. Navmesh polygons are cross-linked to their nearest MAT ridge. Path searches for large hulls route through high-clearance MAT ridges rather than string-pulling across polygon corners.  
* **Runtime Cost & Profiling:** Zero online allocation. A\* search runs over the pre-annotated MAT graph edges. Search time is 20–40% faster than standard navmesh A\* due to a ![][image75] reduction in node count.  
* **Determinism Assessment:** Offline artifact is completely static and frozen. Graph traversals follow strict node-ind order.  
* **Pre-Registered Falsification Metric:** Elimination of all tight-radius turn requests for vehicles whose length-to-clearance ratio ![][image76]. Revert if A\* search latency increases by ![][image77].

### **Anisotropic Threat-Field Fast Marching Routing**

* **Canonical Reference:** Sethian, J. A. (1996). *A fast marching level set method for monotonically advancing fronts*. Proceedings of the National Academy of Sciences, 93(4), 1591–1595.  
* **Replaces / Augments:** Bridges the gap where influence fields were computed but unused for route selection1.  
* **Mechanics & Implementation:** Converts static and dynamic threat fields into an anisotropic continuous Riemannian metric space. The cost of traversing point ![][image78] in direction ![][image79] is:

![][image80]

Where ![][image81] integrates line-of-sight exposure to known enemy firing arcs. The optimal route solves the Eikonal equation ![][image82]. The Eikonal solver runs offline for static terrain exposure, while dynamic threat updates update local cost weights online.

* **Runtime Cost & Profiling:** Evaluating a precomputed anisotropic field costs a single 2D bilinear lookup per search node (![][image83]).  
* **Determinism Assessment:** The online search evaluates a deterministic cost function on a uniform grid or MAT graph with fixed integer priority queues.  
* **Pre-Registered Falsification Metric:** Formation attrition while in transit under "move" orders decreases by ![][image55], while average transit time increases by ![][image84]. Revert if path generation latency exceeds 2 ms.

### **Length-Aware Shadow Extrusion for Cover Queries**

* **Canonical Reference:** Tovar, B., Freda, L., & LaValle, S. M. (2008). *Visibility-based pursuit-evasion with targets of unknown speed*. The International Journal of Robotics Research, 27(11-12), 1353–1373.  
* **Replaces / Augments:** Replaces scalar point-in-polygon cover checks1.  
* **Mechanics & Implementation:** For each threat vector ![][image85], static cover obstacles project a 2D polygonal shadow volume (concealment frustum). A vehicle is verified as "at cover" if and only if the convex hull of its entire capsule chain lies strictly inside the extruded shadow polygon:

![][image86]

If the shadow polygon's maximal inscribed circle is smaller than the vehicle's bounding radius, or if its length along the threat vector is less than ![][image87], the cover point is flagged as invalid for that vehicle class, forcing the agent to seek deep cover.

* **Runtime Cost & Profiling:** Point-in-polygon tests on precomputed shadow wedges cost ![][image88] for a 5-capsule hull.  
* **Determinism Assessment:** Deterministic geometry: shadow polygons are evaluated via integer 2D cross-product half-plane tests.  
* **Pre-Registered Falsification Metric:** Protrusion exposure rate of long hulls (percentage of hull exposed to line-of-sight while reporting "at cover") drops from current levels to exactly 0%. Revert if long hulls fail to locate any valid cover within 40 meters in urban maps.

## **Heterogeneous Multi-Agent Local Avoidance**

Standard reciprocal collision avoidance schemes (such as standard ORCA) assume identical agents sharing equal reciprocity coefficients (![][image89]) and holonomic instant velocity changes, causing deadlocks and oscillations when 2.8m light scouts interact with 14m heavy haulers1.

### **Asymmetric Kinematic Velocity Obstacles**

* **Canonical Reference:** Alonso-Mora, J., Breitenmoser, A., Beardsley, P., & Siegwart, R. (2013). *Reciprocal collision avoidance for multiple car-like robots*. IEEE International Conference on Robotics and Automation (ICRA), 1979–1986.  
* **Replaces / Augments:** Replaces standard ORCA reciprocal avoidance1.  
* **Mechanics & Implementation:** Generalizes Velocity Obstacles to account for non-holonomic turning bounds and mass/class asymmetry. For two interacting agents ![][image28] and ![][image29], the reciprocal responsibility factor ![][image90] is weighted by mass and maneuverability:

![][image91]

Where ![][image92] is an agility coefl to maximum lateral acceleration). A 14-meter hauler (![][image93]) interacting with a 2.8-meter scout (![][image94]) yields ![][image95] and ![][image96]. The scout takes 95% of the avoidance burden. Furthermore, the permissible velocity space for car-like hulls is constrained to an arc of kinematically achievable velocities within time horizon ![][image97], eliminating demands for orthogonal sideways motion.

* **Runtime Cost & Profiling:** Half-plane linear programming in 2D velocity space via fixed-iteration Seidel's algorithm. Evaluates in ![][image98] per agent pair. Total tick runtime for 90 agents is ![][image99].  
* **Determinism Assessment:** Survives. The 2D linear program uses a fixed-order constraint list sorted by time-to-collision and executes a fixed maximum of 8 iterations with fixed-point arithmetic.  
* **Pre-Registered Falsification Metric:** Avoidance-induced direction churn drops by ![][image100] for heavy and medium hulls; deadlocks in narrow passages drop to ![][image68] per 10 hours. Revert if collision frequency between friendly agents rises above zero.

### **Time-to-Collision Energy Landscapes**

* **Canonical Reference:** Karamouzas, I., Skinner, B., & Guy, S. J. (2014). *Universal power law governing pedestrian interactions*. Physical Review Letters, 113(23), 238701\.  
* **Replaces / Augments:** Augments local steering during multi-agent transit1.  
* **Mechanics & Implementation:** Replaces hard geometric clipping with a smooth anticipatory energy potential based on Time-to-Collision (![][image101]). The interaction energy between agents ![][image102] and ![][image103] obeys a universal power-law potential:

![][image104]

Where ![][image101] is the positive real root of ![][image105]. The gradient ![][image106] provides a repulsive force that acts along the anticipated impact vector rather than the instantaneous relative position vector. This prevents agents from oscillating when passing each other on parallel headings.

* **Runtime Cost & Profiling:** Analytical quadratic solution requires ![][image107] per neighbor pair. With spatial hashing restricting checks to the nearest 6 neighbors, cost is ![][image108] per agent.  
* **Determinism Assessment:** Evaluated via fixed-point quadratic equation solvers and exponential lookup tables.  
* **Pre-Registered Falsification Metric:** Lateral clearance variation during head-on bypass maneuvers drops by ![][image55], exhibiting smooth anticipatory divergence rather than last-second dodging. Revert if path length increases by ![][image77].

### **Priority-Based Space-Time Reservation Intervals**

* **Canonical Reference:** van den Berg, J., & Overmars, M. (2005). *Prioritized trajectory planning for multiple robots*. IEEE Transactions on Robotics, 21(4), 741–747.  
* **Replaces / Augments:** Replaces local reactive negotiation in narrow choke points1.  
* **Mechanics & Implementation:** When a corridor's width ![][image109], two-way passing is physically impossible. Rather than relying on local avoidance (which causes head-on standoffs), the squad coordination layer assigns deterministic priority tokens based on squad rank, vehicle class, and direction of travel. The higher-priority agent reserves a space-time tube ![][image110]. The lower-priority agent adjusts its along-track speed profile ![][image111] to hold short of the bottleneck at a pre-designated passing bay until the tube clears.  
* **Runtime Cost & Profiling:** 1D interval overlap test along the corridor axis. Costs ![][image61] per corridor entry query.  
* **Determinism Asseval testing are discrete integer comparisons ordered by unique agent ID.  
* **Pre-Registered Falsification Metric:** Standoff deadlocks inside narrow defiles drop from current baseline to zero. Revert if high-priority agent experiences deceleration inside the choke point.

## **Decision Dynamics and Deterministic Lookahead**

These proposals replace unstable utility scoring and temporal vetoes with continuous, actuation-coupled decision mechanics1.

### **Continuous Drift-Diffusion Leaky Integrator**

* **Canonical Reference:** Bogacz, R., Brown, E., Moehlis, J., Holmes, P., & Cohen, J. D. (2006). *The physics of optimal decision making: A review of the drift-diffusion model*. Cognitive Psychology, 52(2), 156–209.  
* **Replaces / Augments:** Replaces discrete utility scoring with hysteresis and hard target vetoes1.  
* **Mechanics & Implementation:** Eliminates hard switch vetoes. Instead of evaluating target switching instantaneously, the decision state evolves as a continuous Drift-Diffusion / Leaky-Integrator process2. Let ![][image112] be the raw utility differential. The accumulated evidence state ![][image113] updates according to2:

![][image114]

Where ![][image115] is a leakage dissipation rate calibrated to tactical decay. A target switch executes if and only if ![][image116], where ![][image117] is an evidence threshold2. If ![][image118] spikes transiently (due to fleeting visibility or a momentary turn), ![][image119] rises slightly but decays back to zero without triggering an action. Only persistent, sustained superiority pushes ![][image119] across ![][image117].

* **Runtime Cost & Profiling:** A single multiply-accumulate and branch per evaluated target: ![][image120] per candidate. Total per-agent evaluation is ![][image121].  
* **Determinism Assessment:** Implemented with 32-bit fixed-point integer math (![][image122]). Bit-identical across platforms.  
* **Pre-Registered Falsification Metric:** Eliminates target switch-and-switch-back oscillations (measured doubling under veto1 drops to ![][image123] of all target switches) without delaying valid target switches by more than ![][image124] the target-acquisition duration. Revert if target re-acquisition latency under clear line-of-sight exceeds 1.5 seconds.

### **Dynamic Actuation-Coupled Boundary Horizons**

* **Canonical Reference:** Slotine, J. J. E., & Li, W. (1991). *Applied nonlinear control*. Prentice Hall; Chapter 7: Sliding Mode Control and Phase-Plane Switching Surfaces.  
* **Replaces / Augments:** Replaces fixed-cadence tick polling for tactical decisions1.  
* **Mechanics & Implementation:** The cadence of tactical re-decision is tied to the phase-plane state of the vehicle plant. An agent is defined as "kinematically committed" when its current state lies within a switching boundary layer where control inputs cannot alter the immediate topology of the path without violating lateral acceleration bounds:

![][image125]

While ![][image126], the agent suppresses tactical re-aiming and option-space branching, focusing the controller entirely on trajectory tracking. Tactical re-evaluation is scheduled dynamically at the exit of the boundary layer, ensuring decisions are made when the vehicle possesses the control authority to execute them.

* **Runtime Cost & Profiling:** Evaluates in ![][image83] from current kinematic state variables.  
* **Determinism Assessment:** Simple scalar arithmetic comparisons on fixed-point state vectors.  
* **Pre-Registered Falsification Metric:** Trajectory oscillation during combat maneuvers drops to z weapon engagement opportunities are missed by ![][image128].

### **Fixed-Iteration Lemke LCP Model Predictive Control**

* **Canonical Reference:** Bemporad, A., Morari, M., Dua, V., & Pistikopoulos, E. N. (2002). *The explicit linear quadratic regulator for constrained systems*. Automatica, 38(1), 3–20.  
* **Replaces / Augments:** Fills the named gap for model-predictive lookahead over candidate maneuvers1.  
* **Mechanics & Implementation:** Manages local multi-agent engagement maneuvers via explicit, fixed-iteration Model Predictive Control (MPC). The continuous vehicle tracking problem over horizon ![][image129] (![][image130]) is formulated as a quadratic program with linear complementarity constraints (LCP) enforcing acceleration, steering, and obstacle boundaries. Instead of solving an interior-point method to convergence, the system uses a fixed-iteration Lemke solver (strictly bounded at 12 pivot steps). If the optimal solution is not reached within 12 steps, the solver returns the safe fallback: maximum permissible deceleration along the current arc.  
* **Runtime Cost & Profiling:** Bounded at ![][image131] per agent. For 90 agents, online budget is ![][image132] per tick.  
* **Determinism Assessment:** Strict fixed-iteration loop (12 pivots) on pre-conditioned fixed-point matrices guarantees bit-level identical outputs regardless of runtime hardware.  
* **Pre-Registered Falsification Metric:** Plan tracking overshoot at corners decreases by ![][image55]. Revert if pivot limit truncation induces control chattering in ![][image133] of frames.

### **Distilled Fixed-Point Decision Trees via Exact Disjunctive Partitioning**

* **Canonical Reference:** Verwer, S., & Zhang, Y. (2019). *Learning optimal classification trees using branch-and-bound search*. AAAI Conference on Human Computation and Crowdsourcing.  
* **Replaces / Augments:** Replaces hand-tuned utility scoring weight heuristics1.  
* **Mechanics & Implementation:** Offline, an exhaustive tree-search or evolutionary self-play policy explores billions of combat tactical states, generating an optimal mapping from tactical feature vectors ![][image134] to discrete tactical battle drills (react to contact, advance, hold, flank). This dataset is distilled into a frozen, optimal decision tree of depth ![][image135] using exact disjunctive programming. Online, this tree executes as a nested sequence of 6 integer comparisons and bitwise masks, with zero branching mispredictions on modern SIMD hardware.  
* **Runtime Cost & Profiling:** Evaluates in ![][image136] per agent. Zero dynamic memory allocation.  
* **Determinism Assessment:** Completely deterministic. Evaluates static comparison sequences on integer-quantized input features.  
* **Pre-Registered Falsification Metric:** Tactical decision accuracy (conformance to offline expert rollouts) exceeds ![][image137], while eliminating all utility scoring float drift. Revert if unit survival rate drops compared to legacy heuristic scoring.

## **Formation Coherence and Motion Legibility**

Formations that dissolve during turns or deform unrecognizably around obstacles break tactical legibility1. The following techniques treat formations as deformable structural geometries rather than independent flocking agents.

### **Deformable Virtual Structures with Homographic Morphing**

* **Canonical Reference:** Belta, C., & Kumar, V. (2002). *Trajectory planning for formations of mobile robots*. Proceedings of the IEEE International Conference on Robotics and Automation (ICRA), 1587–1592.  
* **Replaces / Auformation station-keeping1.  
* **Mechanics & Implementation:** A squad formation is parameterized as an affine-deformable virtual structure. Let ![][image138] be the nominal coordinate of slot ![][image20] relative to the formation centroid. The world position of slot ![][image20] at time ![][image139] is governed by an affine transformation matrix ![][image140] and translation ![][image141]:

![][image142]

Matrix ![][image143] encodes scaling, shearing, and rotation. When a formation encounters a narrow passage of width ![][image144], the squad controller does not break the formation into independent agents; it continuously scales the lateral axis of ![][image143] (compressing the line into a column or echelon) while preserving ordinal slot relationships. When clearing the corridor, ![][image143] smoothly expands back to the nominal wedge.

* **Runtime Cost & Profiling:** A single ![][image145] matrix-vector multiplication per slot: ![][image83] per agent.  
* **Determinism Assessment:** Closed-form fixed-point matrix interpolation along the corridor arc length.  
* **Pre-Registered Falsification Metric:** Formation dissolution index (variance of relative distance between adjacent slots) decreases by ![][image55] during corridor navigation. Revert if slot collision envelope overlaps static geometry.

### **Passivity-Based Formation Synchronization with Contraction**

* **Canonical Reference:** Chung, S. J., & Slotine, J. J. E. (2009). *Cooperative robot control and concurrent synchronization of Lagrangian systems*. IEEE Transactions on Robotics, 25(3), 686–700.  
* **Replaces / Augments:** Augments the element/squad layer station-keeping controller1.  
* **Mechanics & Implementation:** Treats formation slot-keeping as a network of passivity-based non-linear springs and dampers interconnecting adjacent vehicles. The tracking error ![][image146] is coupled to neighbors via an interconnected Laplacian matrix ![][image147]. Contraction theory guarantees that the entire formation converges exponentially to a stable geometric trajectory despite persistent disturbances, preventing the "accordion" (string instability) effect where braking by the lead vehicle causes extreme oscillation down the convoy.  
* **Runtime Cost & Profiling:** Vectorized Laplacian state update costs ![][image83] per agent.  
* **Determinism Assessment:** Linear fixed-point state-space updates with fixed iteration counts.  
* **Pre-Registered Falsification Metric:** Convoy string instability (amplification of velocity variance from front to rear of column) drops from ![][image148] to ![][image149]. Revert if steady-state tracking error exceeds 1.5 meters.

### **Legible Motion Optimization via Goal Inference**

* **Canonical Reference:** Dragan, A. D., Lee, K. C., & Srinivasa, S. S. (2013). *Legibility and predictability in robot motion*. ACM/IEEE International Conference on Human-Robot Interaction (HRI), 301–308.  
* **Replaces / Augments:** Directly resolves the pathology where players perceive fighting agents as "disobedient"1.  
* **Mechanics & Implementation:** In human-robot interaction, *predictable* motion minimizes expected cost to a known goal, while *legible* motion maximizes an external observer's confidence in the intended destination early in the trajectory2. A Bayesian observer infers probability of goal ![][image150] from trajectory snippet ![][image151] as2:

![][image152]

Where ![][image153] is the optimal cost-to-go from ![][image78] to ![][image154]2. The tactical motion planner optimizes a composite objective: ![][image155]." order avoids taking local evasion vectors that point directly away from the squad's ordered destination unless physical survival strictly demands it. The trajectory exaggerates movement along the squad's advance vector, making intent obvious to the player.

* **Runtime Cost & Profiling:** Offline trajectory libraries are pre-scored for legibility. Online cost is zero; the agent selects from the subset of motion primitives whose legibility index exceeds ![][image156].  
* **Determinism Assessment:** Evaluated strictly via offline precomputed library tags.  
* **Pre-Registered Falsification Metric:** Perceived disobedience telemetry (time spent driving ![][image157] off-axis from player order during attack-move) drops from 30–36%1 to ![][image123]. Player order-cancellation rate drops by ![][image158]. Revert if agent survivability decreases by ![][image77].

### **Dynamic Standoff Envelopes with Independent Turret Kinematics**

* **Canonical Reference:** Urmson, C., et al. (2008). *Autonomous driving in urban environments: Boss and the Urban Challenge*. Journal of Field Robotics, 25(8), 425–466.  
* **Replaces / Augments:** Replaces arrival-with-standoff for hull-fixed vs. turreted weapons1.  
* **Mechanics & Implementation:** Solves the mechanical conflict between weapon aiming and vehicle heading. For turreted vehicles, the hull trajectory planner solves exclusively for forward formation progression and corridor alignment, completely decoupled from target orientation. A secondary high-frequency turret controller solves the 1D orientation tracking problem: ![][image159]. Hull-fixed weapons, by contrast, project a continuous dynamic standoff arc: the vehicle routes to the envelope of the firing cone while maintaining non-zero forward velocity, circling or weaving within the weapon envelope rather than halting or executing multi-point turns.  
* **Runtime Cost & Profiling:** Analytical geometric projection: ![][image83] per turret per tick.  
* **Determinism Assessment:** Fixed-point 1D rotational integration with clamped acceleration.  
* **Pre-Registered Falsification Metric:** Turret-induced hull oscillation drops to zero; time-on-target during movement increases by ![][image160] for turreted hulls. Revert if hull-fixed weapons experience an aiming duty cycle reduction of ![][image161].

## **Task Allocation and Determinism Engineering**

Task allocation across squads and agents must guarantee conflict-free slot assignments without runtime thrash or order-dependent network desyncs1.

### **Regularized Warm-Start Hungarian Assignment**

* **Canonical Reference:** Munkres, J. (1957). *Algorithms for the assignment and transportation problems*. Journal of the Society for Industrial and Applied Mathematics, 5(1), 32–38; augmented with regularized temporal tracking (Spivey & Powell, 2004).  
* **Replaces / Augments:** Replaces ad-hoc greedy slot claiming and un-stabilized assignment re-solves1.  
* **Mechanics & Implementation:** When formations change topology or casualties occur, formation slots must be reassigned. Re-running a naive Hungarian optimization causes massive agent swapping (agent 1 and 2 swap slots for a 1% global distance saving). The assignment cost matrix ![][image162] is regularized with an incumbent switching penalty:

![][image163]

Where ![][image164] is a switching barrier parameter. The assignment problem is solved using a deterministic, fixed-iteration implementation of the Hungarian algorithm (or Jonker-Volgenant solver). The previous frame's dual variables are used as a warm start, reduciost & Profiling:** For squad sizes ![][image166], Hungarian evaluation requires ![][image167]. Total frame time for all squads is ![][image71].  
* **Determinism Assessment:** The cost matrix entries are quantized to 32-bit integers. Loop traversals and augmenting-path searches follow fixed index order (![][image168]), guaranteeing bit-identical assignment across all clients.  
* **Pre-Registered Falsification Metric:** Slot reassignment thrash (agents crossing paths to swap slots) drops to zero during continuous formation maneuvers. Revert if average distance-to-slot convergence time increases by ![][image169].

### **Consensus-Based Bundle Target Allocation**

* **Canonical Reference:** Choi, H. L., Brunet, L., & How, J. P. (2009). *Consensus-based decentralized auctions for robust task allocation*. IEEE Transactions on Robotics, 25(4), 912–926.  
* **Replaces / Augments:** Replaces uncoordinated greedy target selection in the element/squad layer1.  
* **Mechanics & Implementation:** Elements in a squad bid on bundles of tactical tasks (suppress enemy ![][image28], screen flank ![][image29]) using an auction phase, followed by a deterministic consensus phase using local communication matrices. The algorithm provably converges to a conflict-free allocation in a fixed number of communication rounds (![][image170]) and achieves ![][image171] optimality bounds compared to global MILP solutions.  
* **Runtime Cost & Profiling:** Evaluates in ![][image172] per squad for 8 agents bidding on 4 tasks. Evaluated only upon contact events or task completion.  
* **Determinism Assessment:** Fully deterministic. Bids are computed via fixed-point utility scoring, and consensus tie-breaking uses unique integer agent IDs: ![][image173].  
* **Pre-Registered Falsification Metric:** Weapon overkill ratio (multiple agents firing simultaneously at an over-matched target while adjacent threats remain unengaged) drops by ![][image55]. Revert if allocation cycle takes ![][image174] of simulation time.

### **Morton-Order Deterministic Spatial Scheduling**

* **Canonical Reference:** Morton, G. M. (1966). *A computer-oriented geodetic data base and a new technique in file sequencing*. IBM Technical Report.  
* **Replaces / Augments:** Replaces arbitrary pointer-addressed or hash-map iterations over agent sets1.  
* **Mechanics & Implementation:** Resolves the determinism requirement that hash maps and agent update sequences must be strictly ordered without performance degradation1. At the start of each simulation tick, active agents are sorted into a contiguous array indexed by their 32-bit Morton code (Z-order curve) computed from their fixed-point Cartesian coordinates ![][image175]. Iterating over agents in Morton order provides three invariants: (1) update ordering is fully invariant to pointer addresses or allocation sequence, guaranteeing determinism; (2) agents that are spatially adjacent are packed contiguously in memory, maximizing CPU L1/L2 cache hit rates during local avoidance and neighbor queries; (3) dynamic load balancing across parallel worker threads is trivially achieved via contiguous index chunking without mutex contention.  
* **Runtime Cost & Profiling:** Computing Morton codes and running an in-place Radix sort (32-bit) on 180 agents takes ![][image61] total.  
* **Determinism Assessment:** Bit-level deterministic spatial sorting across all hardware targets.  
* **Pre-Registered Falsification Metric:** Regression test suite divergence rate drops to exactly zero over ![][image176] automated replay ticks with multithre**Q32.32 Fixed-Point CORDIC Arithmetic Simulation Core**

* **Canonical Reference:** Volder, J. E. (1959). *The CORDIC trigonometric computing technique*. IRE Transactions on Electronic Computers, EC-8(3), 330–334.  
* **Replaces / Augments:** Replaces standard library transcendental functions (sin, cos, atan2, sqrt) in the simulation core1.  
* **Mechanics & Implementation:** Cross-platform floating-point discrepancies arise from differences in standard-library math routines, FMA (Fused Multiply-Add) contraction, and compiler vectorization re-association1. The entire kinematic and trajectory core is ported to 64-bit integer arithmetic (![][image178] format: 32 bits integer, 32 bits fractional). Transcendental functions (sine, cosine, arctangent) are computed using a deterministic, branchless, unrolled 24-iteration CORDIC (Coordinate Rotation Digital Computer) pipeline. Square roots use fixed-iteration integer non-restoring algorithms.  
* **Runtime Cost & Profiling:** CORDIC evaluations execute in ![][image83] on modern x86-64 ALUs using integer registers, completely bypassing the floating-point unit and vector register differences.  
* **Determinism Assessment:** 100% bit-identical cross-platform invariant guaranteed by the integer ALU specification across all x86-64 and ARM64 processors.  
* **Pre-Registered Falsification Metric:** Complete elimination of build fingerprinting dependencies on standard library versions1. Binary replays remain bit-identical across Windows, Linux, and macOS platforms. Revert if CPU budget for physics/motion increases by ![][image179] per tick.

## **Algorithmic Proposal Catalog and Telemetry Matrix**

The techniques outlined above are summarized below in a structured comparative matrix, mapping their architectural targets, runtime profiles, determinism invariants, and pre-registered falsification criteria.

&nbsp;

| Technique | Primary Target Pathology / System Gap | Canonical Reference | Runtime Cost (90 Agents @ 30 Hz) | Determinism Invariants | Pre-Registered Falsification Metric |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **Continuous-Curvature Clothoids** | Direction churn & kinematic snapping1. | Fraichard & Scheuer (2004) | ![][image180] / tick; 128 B / trajectory. | Fixed-point LUT interpolation of Fresnel integrals. | Traveling oscillation drops from 6% to ![][image53]1; tracking error drops ![][image55]. |
| **Cusp-Penalized Reeds-Shepp** | Gear flipping in car-like hulls1. | Reeds & Shepp (1990); Fraichard (1998) | Evaluated on path init (![][image61] / call). | Closed-form algebraic formulas in Q32.32 fixed point. | Unexplained gear flips drop from 9–19/min1 to 0\. |
| **State Lattice Motion Primitives** | Context-steering direction churn1. | Pivtoraiko, Knepper, & Kelly (2009) | ![][image181] / tick; ![][image182] table / class. | Static array sweep; strict lexicographic tie-breaking. | Re-aiming drops from 45/min1 to ![][image68]/min. |
| **Homotopy Corridor Funneling** | Corridor clipping & string-pulling errors1. | Bhattacharya, Likhachev, & Kumar (2012) | ![][image71] / squad order. | Deterministic topological graph search via integer cross products. | Hull corner clipping incidents drop to 0 in 500 hours. |
| **Swept-Volume Capsule Clearance** | Long hull clearance & corner collisions1. | Schulman, Ho, Lee, & Abbeel (2014) | 40–80 ns / primitive check (SIMD). | Vectorized fixed-point distance transforms. | Hull collision rate in static geometry drops to 0\. |
| **Medial Axis Transform Clearance** | Navmesh radius homogenization1. | Lee (1982) | 0 runtic Voronoi skeleton; deterministic edge IDs. | Zero tight-radius path requests where ![][image76]. |
| **Anisotropic Fast Marching** | Influence fields ignored in routing1. | Sethian (1996) | 15 ns / node lookup in A\* search. | Static grid lookups with integer queue sorting. | Transit attrition drops ![][image55]; transit time increases ![][image84]. |
| **Shadow Extrusion Cover Checks** | Silent cover failures for 14m hulls1. | Tovar, Freda, & LaValle (2008) | ![][image88] / cover query. | 2D half-plane intersection tests with integer coordinates. | Long hull protrusion exposure drops to 0%. |
| **Asymmetric Kinematic VO** | Reciprocal avoidance size mismatch1. | Alonso-Mora et al. (2013) | ![][image99] / tick total across all agents. | Fixed 8-iteration Seidel LP solver in fixed-point. | Avoidance churn drops ![][image100]; passage deadlocks drop to ![][image68]/10 hrs. |
| **TTC Energy Landscapes** | Abrupt dodge hunting during passing1. | Karamouzas, Skinner, & Guy (2014) | ![][image108] / agent / tick. | Analytic quadratic solution with integer exponential LUT. | Lateral bypass clearance variance drops by ![][image55]. |
| **Space-Time Interval Tokens** | Choke-point head-on deadlocks1. | van den Berg & Overmars (2005) | ![][image61] / choke-point entry query. | Integer token comparisons sorted by unique ID. | Standoff deadlocks in narrow passages drop to 0\. |
| **Leaky-Integrator Accumulator** | Target thrash & veto backfire1. | Bogacz et al. (2006) | ![][image121] / target evaluation. | 32-bit fixed-point multiply-accumulate loop. | Switch-and-switch-back drops from doubling1 to ![][image123]. |
| **Actuation-Coupled Cadence** | High-frequency replanning thrash1. | Slotine & Li (1991) | ![][image83] / agent check. | Scalar kinematic comparison against acceleration limits. | Re-aiming under fire drops from 45/min1 to ![][image127]/min. |
| **Fixed-Iteration Lemke LCP** | Missing lookahead over maneuvers1. | Bemporad et al. (2002) | ![][image99] / tick (worst case 90 agents). | Strict 12-pivot bounded Lemke algorithm in fixed-point. | Corner overshoot drops ![][image55]; chattering ![][image53]. |
| **Distilled Fixed-Point Trees** | Utility weight heuristics & float drift1. | Verwer & Zhang (2019) | ![][image136] / agent decision. | Depth-6 binary comparison tree on integer features. | Offline rollout match ![][image100]; zero float divergence. |
| **Deformable Virtual Structures** | Formations dissolving at obstacles1. | Belta & Kumar (2002) | ![][image83] / agent / tick. | Affine matrix-vector multiplication in fixed-point. | Formation dissolution index drops by ![][image55]. |
| **Passivity-Based Synchronization** | Convoy string instability (accordion)1. | Chung & Slotine (2009) | ![][image83] / agent / tick. | Linear Laplacian state update in integer math. | Convoy velocity amplification drops from ![][image148] to ![][image149]. |
| **Legible Motion Optimization** | Perceived disobedience in combat1. | Dragan, Lee, & Srinivasa (2013) | Zero runtime (pre-filtered offline libraries). | Offline precomputed trajectory tagging. | Off-axis driving under attack-move drops from 30–36%1 to ![][image123]. |
| **Decoupled Turret Controllers** | Weapon aiming corrupting hull motion1. | Urmson et al. (2008) | ![][image83] / turret / tick. | 1D fixed-point angular integration with clamping. | Turret-induced hull oscillation drops to 0\. |
| **Regularized Hungarian Slots** | Slot-swapping thrash during turns1. | Munkres (1957); Spivey & Powell (2004) | ![][image167] / squad (![][image166]). | Warm-started Hungarian on qvers. |
| **Consensus Bundle Targets (CBBA)** | Element-level target dogpiling1. | Choi, Brunet, & How (2009) | ![][image172] / squad on contact events. | Fixed-point auction rounds; tie-breaking via integer ID. | Target overkill ratio drops by ![][image55]. |
| **Morton-Order Scheduling** | Hash map nondeterminism & cache misses1. | Morton (1966) | ![][image61] / frame (180 agents). | 32-bit integer Radix sort on Morton spatial codes. | Replay divergence across threads drops to 0\. |
| **Q32.32 CORDIC Math Core** | Cross-platform transcendental drift1. | Volder (1959) | ![][image83] / transcendental evaluation. | 24-iteration unrolled integer shift-add CORDIC. | Regression build fingerprints bit-identical across OSes1. |

## **Quantitative Evaluation and Telemetry Formulations**

Evaluating apparent intelligence requires telemetry metrics that isolate physical plausibility and motion legibility from raw economic task allocation1. The metrics defined below replace qualitative impressions with objective geometric and kinematic functionals.

### **Continuous Telemetry Functionals**

Rather than recording aggregate time-allocation metrics (which disguised direction churn as "traveling time")1, the telemetry harness must evaluate five continuous path functionals:

> 1. **Directional Monotonicity Ratio (![][image184]):** Evaluates path waste over sliding window ![][image185]:

![][image186]

A value of ![][image187] indicates pure rectilinear progress; ![][image188] detects the observed pathology where 8 meters of travel yields less than 2 meters of displacement1. 2\. **Curvature Derivative Jitter (![][image189]):** Measures steering hunting by integrating the square of the curvature derivative:

![][image190]

Clothoid paths reduce ![][image189] by an order of magnitude compared to unconstrained reactive steering. 3\. **Dragan Legibility Functional (![][image191]):** Quantifies whether an external spectator can deduce the squad's target objective early in its execution:

![][image192]

Formations with ![][image193] appear visually deliberate and tactical to players. 4\. **Formation Structural Strain (![][image194]):** Measures geometric distortion of an ![][image2]\-vehicle squad relative to nominal virtual structure coordinates ![][image195]:

![][image196]

Formations deforming correctly around obstacles maintain continuous low strain under affine transformations. 5\. **Actuation Reversal Frequency (![][image197]):** Explicit event counter recording the number of times ![][image198] changes within any 2.0-second interval, directly tracking the gear-flipping pathology1.

The path to apparent unit intelligence does not require non-deterministic heuristics or runtime neural inference; it requires strictly respecting the non-holonomic kinematics of physical bodies and filtering decision dynamics through the time constants of the vehicle plant1. When continuous-curvature path geometry, swept-volume spatial clearance, and leaky-integrator evidence accumulation are enforced as first-class constraints, the visual pathologies of churn, gear flipping, and perceived disobedience dissolve1. Offline computation allows complex spatial fields, collision envelopes, and optimal decision partitions to be distilled into frozen, deterministic artifacts that execute via bounded integer operations within the 30 Hz tick1. The resulting simulation satisfies the dual standards of military engineering: bit-level cross-platform reproducibility under lockstep constraints1, and visible, tactical legibility that reads to human observers as authentic l-time tactical simulation with high per-agent and per-formation intelligence, [https://drive.google.com/open?id=1VLuon742SRRzBMfRdv\_jxx07PgU8e48Y25VJpQy4a18](https://drive.google.com/open?id=1VLuon742SRRzBMfRdv_jxx07PgU8e48Y25VJpQy4a18)  
> 2. [unknown\_url](http://docs.google.com/unknown_url)

[image1]: <[EMBEDDED-IMAGE]>

[image2]: <[EMBEDDED-IMAGE]>

[image3]: <[EMBEDDED-IMAGE]>

[image4]: <[EMBEDDED-IMAGE]>

[image5]: <[EMBEDDED-IMAGE]>

[image6]: <[EMBEDDED-IMAGE]>

[image7]: <[EMBEDDED-IMAGE]>

[image8]: <[EMBEDDED-IMAGE]>

[image9]: <[EMBEDDED-IMAGE]>

[image10]: <[EMBEDDED-IMAGE]>

[image11]: <[EMBEDDED-IMAGE]>

[image12]: <[EMBEDDED-IMAGE]>

[image13]: <[EMBEDDED-IMAGE]>

[image14]: <[EMBEDDED-IMAGE]>

[image15]: <[EMBEDDED-IMAGE]>

[image16]: <[EMBEDDED-IMAGE]>

[image17]: <[EMBEDDED-IMAGE]>

[image18]: <[EMBEDDED-IMAGE]>

[image19]: <[EMBEDDED-IMAGE]>

[image20]: <[EMBEDDED-IMAGE]>

[image21]: <[EMBEDDED-IMAGE]>

[image22]: <[EMBEDDED-IMAGE]>

[image23]: <[EMBEDDED-IMAGE]>

[image24]: <[EMBEDDED-IMAGE]>

[image25]: <[EMBEDDED-IMAGE]>

[image26]: <[EMBEDDED-IMAGE]>

[image27]: <[EMBEDDED-IMAGE]>

[image28]: <[EMBEDDED-IMAGE]>

[image29]: <[EMBEDDED-IMAGE]>

[image30]: <[EMBEDDED-IMAGE]>

[image31]: <[EMBEDDED-IMAGE]>

[image32]: <[EMBEDDED-IMAGE]>

[image33]: <[EMBEDDED-IMAGE]>

[image34]: <[EMBEDDED-IMAGE]>

[image35]: <[EMBEDDED-IMAGE]>

[image36]: <[EMBEDDED-IMAGE]>

[image37]: <[EMBEDDED-IMAGE]>

[image38]: <[EMBEDDED-IMAGE]>

[image39]: <[EMBEDDED-IMAGE]>

[image40]: <[EMBEDDED-IMAGE]>

[image41]: <[EMBEDDED-IMAGE]>

[image43]: <[EMBEDDED-IMAGE]>

[image44]: <[EMBEDDED-IMAGE]>

[image45]: <[EMBEDDED-IMAGE]>

[image46]: <[EMBEDDED-IMAGE]>

[image47]: <[EMBEDDED-IMAGE]>

[image48]: <[EMBEDDED-IMAGE]>

[image49]: <[EMBEDDED-IMAGE]>

[image50]: <[EMBEDDED-IMAGE]>

[image51]: <[EMBEDDED-IMAGE]>

[image52]: <[EMBEDDED-IMAGE]>

[image53]: <[EMBEDDED-IMAGE]>

[image54]: <[EMBEDDED-IMAGE]>

[image55]: <[EMBEDDED-IMAGE]>

[image56]: <[EMBEDDED-IMAGE]>

[image57]: <[EMBEDDED-IMAGE]>

[image58]: <[EMBEDDED-IMAGE]>

[image59]: <[EMBEDDED-IMAGE]>

[image60]: <[EMBEDDED-IMAGE]>

[image61]: <[EMBEDDED-IMAGE]>

[image62]: <[EMBEDDED-IMAGE]>

[image63]: <[EMBEDDED-IMAGE]>

[image64]: <[EMBEDDED-IMAGE]>

[image65]: <[EMBEDDED-IMAGE]>

[image66]: <[EMBEDDED-IMAGE]>

[image67]: <[EMBEDDED-IMAGE]>

[image68]: <[EMBEDDED-IMAGE]>

[image69]: <[EMBEDDED-IMAGE]>

[image70]: <[EMBEDDED-IMAGE]>

[image71]: <[EMBEDDED-IMAGE]>

[image72]: <[EMBEDDED-IMAGE]>

[image73]: <[EMBEDDED-IMAGE]>

[image74]: <[EMBEDDED-IMAGE]>

[image75]: <[EMBEDDED-IMAGE]>

[image76]: <[EMBEDDED-IMAGE]>

[image77]: <[EMBEDDED-IMAGE]>

[image78]: <[EMBEDDED-IMAGE]>

[image79]: <[EMBEDDED-IMAGE]>

[image80]: <[EMBEDDED-IMAGE]>

[image81]: <[EMBEDDED-IMAGE]>

[image82]: <[EMBEDDED-IMAGE]>

[image83]: <[EMBEDDED-IMAGE]>

[image84]: <[EMBEDDED-IMAGE]>

[image85]: <[EMBEDDED-IMAGE]>

[image86]: <[EMBEDDED-IMAGE]>

[image87]: <[EMBEDDED-IMAGE]>

[image89]: <[EMBEDDED-IMAGE]>

[image90]: <[EMBEDDED-IMAGE]>

[image91]: <[EMBEDDED-IMAGE]>

[image92]: <[EMBEDDED-IMAGE]>

[image93]: <[EMBEDDED-IMAGE]>

[image94]: <[EMBEDDED-IMAGE]>

[image95]: <[EMBEDDED-IMAGE]>

[image96]: <[EMBEDDED-IMAGE]>

[image97]: <[EMBEDDED-IMAGE]>

[image98]: <[EMBEDDED-IMAGE]>

[image99]: <[EMBEDDED-IMAGE]>

[image100]: <[EMBEDDED-IMAGE]>

[image101]: <[EMBEDDED-IMAGE]>

[image102]: <[EMBEDDED-IMAGE]>

[image103]: <[EMBEDDED-IMAGE]>

[image104]: <[EMBEDDED-IMAGE]>

[image105]: <[EMBEDDED-IMAGE]>

[image106]: <[EMBEDDED-IMAGE]>

[image107]: <[EMBEDDED-IMAGE]>

[image108]: <[EMBEDDED-IMAGE]>

[image109]: <[EMBEDDED-IMAGE]>

[image110]: <[EMBEDDED-IMAGE]>

[image111]: <[EMBEDDED-IMAGE]>

[image112]: <[EMBEDDED-IMAGE]>

[image113]: <[EMBEDDED-IMAGE]>

[image114]: <[EMBEDDED-IMAGE]>

[image115]: <[EMBEDDED-IMAGE]>

[image117]: <[EMBEDDED-IMAGE]>

[image118]: <[EMBEDDED-IMAGE]>

[image119]: <[EMBEDDED-IMAGE]>

[image120]: <[EMBEDDED-IMAGE]>

[image121]: <[EMBEDDED-IMAGE]>

[image122]: <[EMBEDDED-IMAGE]>

[image123]: <[EMBEDDED-IMAGE]>

[image124]: <[EMBEDDED-IMAGE]>

[image125]: <[EMBEDDED-IMAGE]>

[image126]: <[EMBEDDED-IMAGE]>

[image127]: <[EMBEDDED-IMAGE]>

[image128]: <[EMBEDDED-IMAGE]>

[image129]: <[EMBEDDED-IMAGE]>

[image130]: <[EMBEDDED-IMAGE]>

[image131]: <[EMBEDDED-IMAGE]>

[image132]: <[EMBEDDED-IMAGE]>

[image133]: <[EMBEDDED-IMAGE]>

[image134]: <[EMBEDDED-IMAGE]>

[image135]: <[EMBEDDED-IMAGE]>

[image136]: <[EMBEDDED-IMAGE]>

[image137]: <[EMBEDDED-IMAGE]>

[image138]: <[EMBEDDED-IMAGE]>

[image139]: <[EMBEDDED-IMAGE]>

[image140]: <[EMBEDDED-IMAGE]>

[image141]: <[EMBEDDED-IMAGE]>

[image142]: <[EMBEDDED-IMAGE]>

[image143]: <[EMBEDDED-IMAGE]>

[image144]: <[EMBEDDED-IMAGE]>

[image145]: <[EMBEDDED-IMAGE]>

[image146]: <[EMBEDDED-IMAGE]>

[image147]: <[EMBEDDED-IMAGE]>

[image148]: <[EMBEDDED-IMAGE]>

[image149]: <[EMBEDDED-IMAGE]>

[image150]: <[EMBEDDED-IMAGE]>

[image151]: <[EMBEDDED-IMAGE]>

[image152]: <[EMBEDDED-IMAGE]>

[image153]: <[EMBEDDED-IMAGE]>

[image154]: <[EMBEDDED-IMAGE]>

[image155]: <[EMBEDDED-IMAGE]>

[image156]: <[EMBEDDED-IMAGE]>

[image157]: <[EMBEDDED-IMAGE]>

[image158]: <[EMBEDDED-IMAGE]>

[image159]: <[EMBEDDED-IMAGE]>

[image160]: <[EMBEDDED-IMAGE]>

[image161]: <[EMBEDDED-IMAGE]>

[image163]: <[EMBEDDED-IMAGE]>

[image164]: <[EMBEDDED-IMAGE]>

[image165]: <[EMBEDDED-IMAGE]>

[image166]: <[EMBEDDED-IMAGE]>

[image167]: <[EMBEDDED-IMAGE]>

[image168]: <[EMBEDDED-IMAGE]>

[image169]: <[EMBEDDED-IMAGE]>

[image170]: <[EMBEDDED-IMAGE]>

[image171]: <[EMBEDDED-IMAGE]>

[image172]: <data:image/pKGgoAAAANSUhEUgAAADwAAAAXCAYAAABXlyyHAAABQ0lEQVR4AeyTrUuDURjFh8EgFvVPUDQbFS0aDDYxahAMglgFFZNFwSSoSUEUwWgw+BVW9tG2trA+2MrYWBgMtt8JD4x3bPDG590d57dnd3eDc+6570RqzF4hcNILDw2HhhN2AuFKJ6zQgTjW8Bw7X9CFJuThEiYhKv3nPPqll7XMy+sVbxVYhRk4hUXIwTL065hFHVzKAs/i/hCy0IE07MM9/MAf3IEOYJf5BC5lga+HuFewefZeoQa65pvMNriUBS7g/gR+4R0OwJ7fBp9fQNde+7oB26xdygLv4F4hv5lqdYH5D2sQlRpfiX7pZW2B9VyuY/oWFPSCqQM4YqrxDeY0KOwz8w1cygIXcd+CfpVZ7MEHPEIVHuAMSuBSFvhmhPtP9pZgCrYgA16VssBuA8Q1HgLHPTFvvw8Ne2ssrt+xa7gHAAD//xR4kGsAAAAGSURBVAMAEikvL8IjjCEAAAAASUVORK5CYII=>

[image173]: <[EMBEDDED-IMAGE]>

[image174]: <[EMBEDDED-IMAGE]>

[image175]: <[EMBEDDED-IMAGE]>

[image176]: <[EMBEDDED-IMAGE]>

[image177]: <[EMBEDDED-IMAGE]>

[image178]: <[EMBEDDED-IMAGE]>

[image179]: <[EMBEDDED-IMAGE]>

[image180]: <[EMBEDDED-IMAGE]>

[image181]: <[EMBEDDED-IMAGE]>

[image182]: <[EMBEDDED-IMAGE]>

[image183]: <[EMBEDDED-IMAGE]>

[image184]: <[EMBEDDED-IMAGE]:image/png;base64,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>

[image186]: <[EMBEDDED-IMAGE]>

[image187]: <[EMBEDDED-IMAGE]>

[image188]: <[EMBEDDED-IMAGE]>

[image189]: <[EMBEDDED-IMAGE]>

[image191]: <[EMBEDDED-IMAGE]>

[image192]: <[EMBEDDED-IMAGE]>

[image193]: <[EMBEDDED-IMAGE]>

[image194]: <[EMBEDDED-IMAGE]>

[image195]: <[EMBEDDED-IMAGE]>

[image196]: <[EMBEDDED-IMAGE]>

[image197]: <[EMBEDDED-IMAGE]>

[image198]: <[EMBEDDED-IMAGE]>
