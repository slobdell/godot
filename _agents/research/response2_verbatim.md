# **Resolving the Intent-Execution Seam in Deterministic Multi-Agent Simulation**

The breakdown observed across the experimental motion stack does not stem from isolated flaws in individual algorithms, but from a fundamental architectural mismatch: the decoupling of high-level tactical intent from low-level physical execution across an unbuffered temporal and spatial boundary. In the current engine, the tactical layer operates intermittently at approximately 3 Hz to produce unconstrained point waypoints, while the reactive movement layer executes at 30 Hz using local gradient descent and move-and-slide routines. Because the reactive layer lacks awareness of formation geometry, spatial funnels, or operational posture, it overrides tactical intent during nine tenths of all simulation ticks. The systemic failure is compounded by treating vehicle hulls as sliding kinematic points with decoupled, unconditioned orientation snaps. While mathematically convenient for small isotropic units, this simplification fails for vehicles whose length exceeds their width by four- to five-fold. Yawing an elongated body sweeps an extensive collision envelope through adjacent space; attempting to arrest this sweep via discrete penetration checks guarantees deadlock in dense formations where vehicles operate near collision margins.

Eliminating these pathologies requires replacing unconstrained point targets with contract-based invariant funnels, substituting discrete yaw checks with continuous configuration-space envelope reservations, and replacing omnidirectional local avoidance in narrow defiles with directional right-of-way token protocols. The simulation stack must transition from myopic, reactive recovery to a feedforward paradigm where traversability, turning envelopes, and clearance footprints are certified offline and strictly preserved at runtime. Grounding the plant in non-linear kinematic differential equations for articulated bodies, decoupling operational arrival from terminal heading dressing, and instituting metamorphic testing with positive controls guarantees bit-level determinism at 30 Hz while ensuring vehicle maneuvers remain physically viable and tactically legible.

## **1\. The Architectural Seam and Intent-Execution Duality**

### **Reframing the Execution Disconnect**

The experimental failure across the motion stack is an instance of the unbuffered three-tier decoupling pathology. In hierarchical agent architectures, when a deliberative layer emits isolated spatial setpoints without explicit continuous state bounds, the execution layer must construct its own trajectory between those setpoints. Because the reactive mover operates primarily through obstacle repulsion, path tracking, and unsticking heuristics, it treats the high-level intent—such as formation preservation, corridor adherence, and visual legibility—as completely malleable. Framing the remedy as moving intent down or moving execution up misdiagnoses the problem: executing tactical context steering at 30 Hz exhausts frame compute, while running obstacle avoidance at 3 Hz induces catastrophic collision latency.

The control-theoretic remedy is contract-based funnel control implemented via an explicit reference governor. Under this paradigm, the deliberative layer does not emit discrete coordinates; it synthesizes a continuous safe invariant set—a polyhedral spatial corridor equipped with a Lyapunov stationarity bound. The 30 Hz movement layer operates as a constrained tracking governor, projecting nominal control inputs onto the forward-invariant set defined by that corridor. This prevents the reactive mover from selecting velocity vectors that violate high-level tactical constraints.

| Architectural Pattern | Deliberative Role (3 Hz) | Execution Role (30 Hz) | Shared State Contract | Failure Mode |
| :---- | :---- | :---- | :---- | :---- |
| **Decoupled Stack** | Context-steering evaluation; emits point targets | Move-and-slide integration; myopic avoidance; unstuck states | Discrete coordinates and destination vectors | Command-blind reactive drift; intent overwritten in 90% of ticks |
| **Monolithic Reactive Push** | Merged into execution; scores all weights per frame | Evaluates tactical and physical fields simultaneously | Unified weight vectors and scalar potential fields | Excessive computational cost; rapid, high-frequency action churn |
| **Hierarchical State Export** | Emits waypoints alongside operational behavioral tags | Switches state machines based on categorical tags | Finite-state machine enumerations and leashes | Brittle transitions at geometric boundaries; priority inversions |
| **Contract Invariant Funnel** | Generates polyhedral safe corridors and terminal bounds | Projects nominal control inputs onto invariant sets | Convex polyhedral funnels and dynamic safety margins | Corridor starvation if deliberative planner drops frames |

### **Technical Proposal: Explicit Reference Governor with Convex Polyhedral Funnels**

The explicit reference governor operates as an add-on supervisory filter between the tactical planner and the vehicle plant. At each deliberative step, the tactical layer computes a safe operational tube composed of connected convex spatial polytopes and an associated Lyapunov stationarity bound. At each 30 Hz simulation tick, the execution layer evaluates the vehicle state against the dynamic safety margin of the corridor. If the nominal tracking input threatens the boundary, the governor modulates the reference position along the corridor centerline via a closed-form scalar parameter, scaling vehicle speed to preserve output admissibility without deviating from the corridor geometry.

* **Canonical Reference**: Kolmanovsky, I., Garone, E., & Di Cairano, S. (2014). *Reference and Command Governors: A Survey on Enforcing Constraints on Prestabilized Systems*. IEEE Transactions on Automatic Control; Burridge, R. R., Rizzi, A. A., & Koditschek, D. E. (1999). *Sequential Composition of Dynamically Safe Behaviors*. IJRR.  
* **What It Replaces**: The context-steering waypoint emitter, the decoupled unstuck heuristic state machine, and unconstrained local avoidance overrides.  
* **Runtime Cost**: Evaluates $m$ half-space dot products per agent per tick, where $m$ is the number of planes defining the local polytope (typically $m \\le 8$). For 90 agents at 30 Hz, execution overhead remains below 0.08 ms per frame.  
* **Bit-Level Determinism Survival**: Fully deterministic. Projections and scalar governor updates use fixed-point arithmetic without iterative loops, wall clocks, or dynamic heap allocations.  
* **Pre-registered Falsifier Metric**: The standard deviation of lateral trajectory error relative to the squad corridor centerline across 1,000 multi-agent runs must decrease by at least 85% compared to the baseline context-steerer, while unstuck-trigger events must decrease by at least 90%.

## **2\. Rotational Kinematics, Turning Envelopes, and Collective Deadlock**

### **Reframing Rotational Collision Deadlock**

The failure of the penetration-refusal yaw rule stems from two incorrect assumptions: first, that collision resolution can treat translation and rotation as decoupled sequential operations; second, that vehicles in a formation begin maneuvering from zero penetration. A rigid body with length $L \= 14\\text{ m}$ and width $W \= 3.3\\text{ m}$ has an aspect ratio of $4.24:1$ and a circumscribed turning radius $R\_{diag} \= \\sqrt{L^2 \+ W^2} / 2 \\approx 7.19\\text{ m}$. Applying an unconditioned yaw rotation $\\Delta \\theta$ sweeps an area proportional to $(R\_{diag}^2 \- (W/2)^2) \\Delta \\theta$. In tight formations where inter-vehicle clearance margins are smaller than 1.0 m, this swept envelope immediately intersects the collision hulls of adjacent units.

When rotation is conditioned on discrete penetration checks, a catastrophic failure sequence occurs:

1. Vehicles in formation spawn or settle within each other's resting collision margins, establishing an initial non-zero penetration baseline ($d\_0 \> 0$).  
2. Agent A attempts to yaw toward its destination, yielding candidate penetration depths $d\_{cand} \\ge d\_0$ due to contact with Agent B.  
3. The rotational step is rejected at $1.0\\times$, $0.6\\times$, and $0.3\\times$, locking Agent A's heading.  
4. Agent B executes the identical check against Agent A and similarly locks.  
5. Lateral clearance to static geometry becomes irrelevant: the deepest contact point is inter-agent, masking wall proximity and freezing entire formations regardless of available open space.

Decoupling translation from rotation is fundamentally ill-posed for elongated vehicles. In real non-holonomic systems, yaw is kinematically coupled to longitudinal motion via curvature constraints ($\\dot{\\theta} \= \\frac{v}{L} \\tan \\phi$). A formation cannot rotate in place unless its slot pitch exceeds $2 R\_{diag}$, or unless members execute coordinated, staggered forward sweeps.

| Collision Resolution Strategy | Computational Paradigm | Monotonicity with Respect to Yaw | Formation Behavior | Confined Defile Behavior |
| :---- | :---- | :---- | :---- | :---- |
| **Unconditioned Yaw Snap** | Instantaneous transform update | Non-monotone; discontinuous jumps | Eliminates deadlocks; severe visual clipping | Extreme hull penetration through walls |
| **Discrete OBB Penetration Rejection** | Multi-step candidate probing | Non-monotone; sensitive to non-convexities | Universal deadlock; mutual blocking freezes squads | Prevents clipping; traps hulls at entry corners |
| **Capsule String Continuous Distance** | Multi-circle bounding approximation | Piecewise monotone and differentiable | Smooth repulsive sliding; stable settlement | Natural guidance along defile centerlines |
| **Configuration-Space Envelope Reservation** | Spatio-temporal reservation grid | Discrete mutual exclusion lock | Staggered pivots; priority-based rotations | Guaranteed collision-free corridor transit |

### **Decoupled Path Tracking and Swept Continuous Physics**

Autonomous vehicle simulations avoid unconditioned kinematic transform updates and iterative dynamic joint solvers, both of which risk non-deterministic divergence across platforms. Instead, standard practice relies on a decoupled reference path combined with swept-envelope verification and tracking control.

The simulation plant represents the vehicle using Ackermann or differential-drive kinematics where angular velocity is bounded by forward speed ($\\omega \\le \\frac{v}{R\_{min}}$). In-place rotation is prohibited for elongated vehicles ($L \> 4\\text{ m}$) unless configured as tracked units with verified envelope clearances. For collision queries, oriented bounding boxes are replaced by a symmetric multi-circle or capsule-string model consisting of three to five overlapping interior discs along the longitudinal centerline. The distance field between capsule strings and static geometry is smooth and monotone with respect to heading adjustments, eliminating the discontinuity and contact masking inherent to discrete box tests. Furthermore, before initiating any rotation, an agent must secure a spatial reservation over its swept turning envelope within the local navigation mesh. If the reservation is denied, the vehicle maintains its current heading, halts longitudinal translation, and yields to higher-priority units.

### **Technical Proposal: Configuration-Space Capsule Decomposition and Turning Allocations**

This method replaces single oriented bounding boxes with an analytic 4-capsule string along the longitudinal centerline and scales formation slot pitch based on the swept turning radius rather than hull width.

* **Canonical Reference**: Kanayama, Y., Kimura, Y., Miyazaki, F., & Noguchi, T. (1990). *A Stable Tracking Control Method for an Autonomous Mobile Robot*. IEEE Transactions on Robotics and Automation; Martinez-Alfaro, H. et al. (2001). *Multi-Circle Robot Approximation for Real-Time Collision Avoidance*.  
* **What It Replaces**: Decoupled move-and-slide routines with retroactive unconditioned yaw clamping.  
* **Runtime Cost**: Distance queries between 4-capsule strings and 2D environmental line segments require four point-segment distance calculations, totaling approximately 32 floating-point operations per pair. Broadphase pruning maintains execution under 0.12 ms per tick for 90 agents.  
* **Bit-Level Determinism Survival**: Fully deterministic. Capsule-to-capsule and capsule-to-segment distance formulas are closed-form, division-by-zero protected, and free of iterative convergence loops.  
* **Pre-registered Falsifier Metric**: Zero occurrences of consecutive yaw refusals exceeding 3 ticks ($0.1\\text{ s}$) across 500 formation-turn scenarios; static wall penetrations must remain identically 0.00 mm.

## **3\. The Articulated Vehicle: Kinematics and Swept-Path Verification**

### **Reframing Articulated Vehicle Mechanics**

Treating a 14 m articulated tractor-trailer as a single rigid box distorts gameplay, while introducing a second dynamic body governed by iterative joint solvers threatens platform determinism. Dynamic multi-body physics are unnecessary: heavy vehicle mechanics at tactical ground speeds ($v \\le 15\\text{ m/s}$) are governed primarily by kinematic constraints where the fifth-wheel hitch acts as a holonomic velocity link.

The vehicle is modeled as a master kinematic body (the tractor) driving a passive secondary body (the trailer) through closed-form non-linear hitch kinematics. The trailer does not execute independent collision sweeps; its pose is derived analytically from the tractor's trajectory, and its physical collider is integrated as an independent, hinged oriented bounding box.

### **Minimal Deterministic Articulated Equations of Motion**

Let the tractor state be defined by $(x\_0, y\_0, \\theta\_0)$ with forward velocity $v\_0$ and steering angle $\\phi\_0$ across wheelbase $L\_0$. The fifth-wheel hitch is positioned along the tractor's longitudinal axis at an offset $d$ behind the rear axle. The trailer possesses an effective wheelbase $L\_1$ and orientation $\\theta\_1$. The articulation angle is defined as $\\psi \= \\theta\_0 \- \\theta\_1$.

The continuous kinematic equations governing the system are:

$$\\dot{x}\_1 \= v\_0 \\cos\\theta\_0 \\cos\\psi \- d \\omega\_0 \\sin\\theta\_0 \\cos\\psi$$

$$\\dot{y}\_1 \= v\_0 \\sin\\theta\_0 \\cos\\psi \+ d \\omega\_0 \\cos\\theta\_0 \\cos\\psi$$

$$\\dot{\\theta}\_1 \= \\frac{v\_0}{L\_1} \\sin\\psi \- \\frac{d}{L\_1} \\omega\_0 \\cos\\psi$$

where the tractor yaw rate is $\\omega\_0 \= \\frac{v\_0}{L\_0} \\tan\\phi\_0$. When the hitch rests directly above the tractor's rear axle ($d \= 0$), the orientation rate reduces to:

$$\\dot{\\theta}\_1 \= \\frac{v\_0}{L\_1} \\sin(\\theta\_0 \- \\theta\_1)$$

During forward motion ($v\_0 \> 0$), the term $\\sin\\psi$ drives $\\theta\_1 \\to \\theta\_0$, pulling the trailer's rear axle toward the inside of the turn (off-tracking). In reverse motion ($v\_0 \< 0$), the alignment $\\psi \= 0$ becomes an unstable equilibrium, causing any angular deviation to amplify exponentially. If $\\vert{}\\psi\\vert{} \\ge \\psi\_{critical}$ (empirically $75^\\circ \\le \\psi\_{critical} \\le 85^\\circ$), the trailer binds against the tractor structure. The simulation catches this condition analytically: when $\\vert{}\\psi\\vert{} \\ge \\psi\_{critical}$ during reverse maneuvers, transmission drive is locked, preventing the trailer from penetrating the tractor cab.

Integration proceeds at a fixed 30 Hz using explicit second-order Runge-Kutta (RK2):

1. Compute the articulation derivative $d\\theta\_1(t) \= \\frac{v\_0}{L\_1} \\sin(\\psi(t)) \- \\frac{d}{L\_1} \\omega\_0 \\cos(\\psi(t))$.  
2. Evaluate midpoint states: $\\psi\_{mid} \= \\psi(t) \+ 0.5 \\Delta t (\\omega\_0 \- d\\theta\_1(t))$.  
3. Re-evaluate the derivative: $d\\theta\_{1,mid} \= \\frac{v\_0}{L\_1} \\sin(\\psi\_{mid}) \- \\frac{d}{L\_1} \\omega\_0 \\cos(\\psi\_{mid})$.  
4. Update trailer orientation: $\\theta\_1(t \+ \\Delta t) \= \\theta\_1(t) \+ \\Delta t \\cdot d\\theta\_{1,mid}$.  
5. Position the trailer collider analytically from the hitch anchor: $\\mathbf{x}\_{trailer} \= \\mathbf{x}\_{hitch} \- \\frac{L\_1}{2} \[\\cos\\theta\_1, \\sin\\theta\_1\]^T$.

Testing ballistic projectiles against two distinct, hinged oriented bounding boxes ensures that munitions passing through the open fold cleanly clear both structures, eliminating phantom hits.

### **Road-Design Practice and Swept-Path Certification**

Civil engineering standards, such as the AASHTO guidelines for WB-62 design vehicles, evaluate road layouts using swept-path analysis. The outer path is defined by the tractor cab's front overhang, while the inner path is traced by the rear trailer axle. Rather than evaluating expensive swept volumes online, map traversability is certified offline per vehicle class:

| Pipeline Stage | Processing Timing | Input Representations | Generated Output | Operational Runtime Consumer |
| :---- | :---- | :---- | :---- | :---- |
| **Turning Template Generation** | Offline Asset Bake | Vehicle wheelbases ($L\_0, L\_1$), track width, maximum steering angle $\\phi\_{max}$ | Discrete swept-polygon templates $\\mathcal{S}\_k(\\alpha)$ across angles $\\alpha \\in \[30^\\circ, 180^\\circ\]$ | Visual affordance renderer and verification tools |
| **Corridor Graph Extraction** | Offline Map Compilation | Arena navigation mesh and static structural boundaries | Centerline graph $\\mathcal{G} \= (\\mathcal{V}, \\mathcal{E})$ storing edge widths $w\_e$ and corner fillet radii $R\_v$ | Global $\\text{A}^\*$ routing planner |
| **Swept-Path Verification** | Offline Certification Pass | Corridor graph $\\mathcal{G}$ and swept templates $\\mathcal{S}\_k(\\alpha)$ | Boolean reachability flags and per-turn speed limits: $v\_{max} \= \\sqrt{\\mu g R\_v}$ | Pruned per-class topological routing tables |
| **Affordance Decal Projection** | Real-Time Render Loop | Selected vehicle class $k$ and active path corridor | Ground-plane overlays highlighting certified lanes and impassable defiles | Player user interface and command validation |

* **Canonical Reference**: Altafini, C. (2001). *Some Properties of the General n-Trailer*. IEEE Transactions on Automatic Control; AASHTO (2018). *A Policy on Geometric Design of Highways and Streets* (7th ed.).  
* **What It Replaces**: Single-box rigid collision volumes, unconstrained runtime trailer physics, and dynamic raycast-based defile testing.  
* **Runtime Cost**: Articulated RK2 kinematic updates require 45 floating-point operations ($\\le 0.002\\text{ ms}$ per vehicle per tick). Swept-path routing queries use standard $\\text{A}^\*$ traversals over a pre-filtered graph.  
* **Bit-Level Determinism Survival**: Fully deterministic across IEEE 754 platforms using standardized, fixed-accuracy trigonometric functions.  
* **Pre-registered Falsifier Metric**: The articulated unit must navigate a $90^\\circ$ street turn of width $w \= 12\\text{ m}$ with zero static penetrations across 100 trials, maintaining hitch separation error at identically $0.000000\\text{ m}$.

## **4\. Clearance, Spacing, and Non-Holonomic Corridor Coordination**

### **The Multi-Tier Spatial Vocabulary**

Using a vehicle's circumscribed diagonal disc as a universal spatial footprint introduces massive geometric distortions. For a 14 m $\\times$ 3.3 m vehicle, the circumscribed disc ($R \= 7.19\\text{ m}$) encloses an area of $162.4\\text{ m}^2$, compared to the actual hull area of $46.2\\text{ m}^2$. This 351% overestimation causes weapon fire-control systems to falsely identify friendly units as obstructions, while incoming threat routines trigger unnecessary evasion maneuvers. Conversely, deriving formation slot spacing strictly from hull width ($W \= 3.3\\text{ m}$) guarantees that any reorientation maneuver will trigger inter-vehicle collisions.

The simulation must adopt a four-tier clearance vocabulary:

1. **Static Footprint**: The exact oriented bounding box ($L \\times W \\times H$) or interior capsule string. Used exclusively for projectile raycasts, chassis collision resolution, and physical wall contacts.  
2. **Swept Travel Ribbon**: The Minkowski sum of the static footprint and the instantaneous displacement vector $v \\cdot \\Delta t$, buffered by lateral margin $\\delta\_{margin}$. Used for straight-line corridor transit and convoy headway maintenance.  
3. **Turning Envelope**: The asymmetric swept polygon bounded by the exterior cab overhang circle $R\_{ext}$ and the interior trailer axle circle $R\_{int}$. Used for formation slot pitch allocation, intersection clearance reservations, and pivot licensing.  
4. **Combat Signature**: The projected hull silhouette along threat azimuth $\\theta\_{threat}$, computed as $A\_{proj} \= H (L \\vert{}\\sin\\theta\\vert{} \+ W \\vert{}\\cos\\theta\\vert{})$. Used for friendly-fire checks, directional armor evaluations, and tactical cover calculations.

Universal Invariant: Lateral formation slot pitch must equal at least the turning envelope diameter $2 R\_{ext}$, unless the squad is explicitly maneuvering in a single-file forward convoy.

### **Non-Holonomic Corridor Coordination**

The failure of reciprocal velocity obstacles in narrow defiles (yielding a 61% deflection rate and complete transit failure) is a direct consequence of enforcing holonomic assumptions on non-holonomic systems. Standard reciprocal velocity algorithms resolve collisions by commanding instantaneous lateral velocity offsets ($\\dot{y} \\ne 0$). For an elongated car-like hull in a narrow passage, lateral translation is physically impossible. When two vehicles meet head-on, reciprocal avoidance forces both into the adjacent walls; once forward velocity halts against geometry, the algorithms continue commanding lateral avoidance, causing permanent deadlock.

Reciprocal avoidance must be disabled in narrow passages ($W\_{passage} \< 2 W\_{swept}$) and replaced by a corridor right-of-way token protocol adapted from railway signaling and traffic microsimulation:

| Protocol Step | Trigger Event | Operational Logic | State Transition |
| :---- | :---- | :---- | :---- |
| **1\. Zone Detection** | Vehicle route enters passage segment where $W \< 2 W\_{swept}$ | Identify passage as a Single-Lane Exclusion Zone (SLEZ) with terminal nodes Alpha and Beta | Agent registers entry intent at terminal node |
| **2\. Token Arbitrament** | Leading vehicle crosses entrance threshold at Node Alpha | Check SLEZ token state: if Free, grant token with polarity $\\alpha \\to \\beta$; if Busy with opposing traffic, hold | Leading vehicle enters; opposing traffic halts at upstream hold line |
| **3\. Convoy Admittance** | Following friendly units arrive at Node Alpha while token active | Vehicles in the same squad inherit transit rights, entering with headway spacing $d\_{follow} \\ge 1.5 L$ | Convoy forms; directional polarity maintained |
| **4\. Token Relinquishment** | Rear axle of final convoy vehicle exits Node Beta | Detect exit event; set SLEZ token state to Free; evaluate queued requests at opposing terminal | Opposing queue released; directional flow alternates |

* **Canonical Reference**: Dresner, K., & Stone, P. (2008). *A Multiagent Approach to Autonomous Intersection Management*. JAIR; Treiber, M., Hennecke, A., & Helbing, D. (2000). *Congested Traffic States in Empirical Observations and Microscopic Simulations*.  
* **What It Replaces**: Reciprocal Velocity Obstacles (ORCA/RVO) and local unsticking routines in narrow defiles.  
* **Runtime Cost**: $\\mathcal{O}(1)$ bitmask check per vehicle per tick on active corridor tokens.  
* **Bit-Level Determinism Survival**: Fully deterministic. Tokens are awarded via a monotonic simulation tick queue with ties broken by unique vehicle IDs.  
* **Pre-registered Falsifier Metric**: Zero head-on deadlocks across 200 opposing vehicle runs in a 6 m wide, 50 m long defe; transit times for four-vehicle squads must not exceed $1.25\\times$ unimpeded duration.

## **5\. Command Interface Latency, Formation Dressing, and Coalition Splitting**

### **Human-Computer Interaction Latency Thresholds**

The 40-second delay measured on a 20 m squad move stems from tying the player-facing command completion directly to the mechanical settlement of every vehicle's trailing axle. In real-time command interfaces, operator perception operates across two distinct latency regimes:

1. **Perceptual Acknowledgement ($\\le 100\\text{ ms}$)**: The human operator requires immediate, unambiguous feedback confirming that an order was received and parsed. If the interface does not update within 100 ms, users perceive the system as unresponsive, prompting repeated input clicks that disrupt the execution pipeline.  
2. **Intent Manifestation ($\\le 1.0\\text{ s}$)**: The controlled entities must exhibit visible mechanical progress toward the objective within 1.0 s, such as turret slewing, engine throttle response, or steering-rack deflection.

The interface must provide immediate visual acknowledgment on tick $t+1$ ($\\le 33\\text{ ms}$):

* A high-contrast command waypoint anchor renders instantly at the target location.  
* Vehicle turrets immediately align with the destination vector.  
* Steered wheels execute an immediate visual deflection toward the initial heading prior to hull translation.

Providing rapid visual acknowledgment decouples user perception of responsiveness from physical transit time. Players readily tolerate extended maneuvers if units immediately signal comprehension of the command.

### **Decoupling Operational Arrival from Terminal Heading Dressing**

The root cause of extended settlement times is combining co-arrival pacing with rigid terminal heading alignment. The pacing system constrains all squad members to the velocity of the slowest unit, while the movement task remains active until every vehicle matches its ordered position ($\\epsilon\_p \\le 0.25\\text{ m}$) and heading ($\\epsilon\_\\theta \\le 5^\\circ$).

For non-holonomic wheeled vehicles, correcting residual heading errors requires multi-point turns (Dubins or Reeds-Shepp maneuvers). Forcing an entire formation to wait while a wheeled vehicle completes a multi-point turn to eliminate a minor heading deviation creates severe pacing bottlenecks.

The lifecycle of a movement task must be divided into three distinct operational phases:

1. **Phase 1 (Transit Run)**: Formation members maintain co-arrival speed matching along the global approach corridor.  
2. **Phase 2 (Operational Arrival)**: The instant the formation centroid enters the destination zone ($R\_{arrival} \\le 1.5 R\_{formation}$) and all vehicles enter their braking profiles, the player command is marked **COMPLETED**. Pacing constraints are lifted, and weapons are freed to engage targets.  
3. **Phase 3 (Independent Terminal Dressing)**: Each vehicle completes its final positioning independently. Tracked and hover units neutral-steer to the exact ordered heading. Wheeled vehicles stop at their slot coordinates and clamp their heading to their arrival direction, accepting residual heading deviations up to $\\pm 45^\\circ$. Vehicle turrets rotate to offset any residual hull misalignment, maintaining designated field-of-fire coverage.  
* **Canonical Reference**: Reeds, J., & Shepp, L. (1990). *Optimal paths for a car that goes both forwards and backwards*. Pacific Journal of Mathematics; Card, S. K., Moran, T. P., & Newell, A. (1983). *The Psychology of Human-Computer Interaction*.  
* **What It Replaces**: Rigid co-arrival completion gates and mandatory uniform heading alignment.  
* **Runtime Cost**: Distance-squared evaluation against formation centroid: $\\mathcal{O}(1)$ per squad; per-agent tolerance checks: $\\mathcal{O}(N)$. Overhead remains under 0.01 ms per frame.  
* **Bit-Level Determinism Survival**: Fully deterministic. State transitions rely exclusively on squared Euclidean thresholds and fixed-point dot products.  
* **Pre-registered Falsifier Met time to signal command completion for a 20 m squad move on level terrain must drop from $\\approx 40\\text{ s}$ to $\\le 6.5\\text{ s}$, with zero increase in collision rates.

### **Deterministic Ad-Hoc Coalition Role Splitting**

When an operator selects an arbitrary heterogeneous group of vehicles and issues a tactical order (such as "Support by Fire"), the engine must deterministically split the selection into a Base Element (support by fire) and a Manoeuvre Element (flanking/assault). The assignment must remain computationally minimal and align with intuitive tactical roles: heavy, long-range, or hull-locked platforms anchor to provide fire support, while fast, agile units maneuver.

Deterministic Role Assignment Algorithm

\========================================================================================

Input: Selected Vehicle Set V, Target Vector T (from Squad Centroid to Objective)

&nbsp;

1\. For each vehicle i in V, compute the Support-by-Fire Fitness Metric (S\_i):

&nbsp;&nbsp;&nbsp;S\_i \= (D\_i \* DPS\_i) / (V\_i \* M\_i)

&nbsp;&nbsp;&nbsp;where:

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;D\_i   \= Maximum effective weapon range (meters)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;DPS\_i \= Sustained weapon damage per second

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;V\_i   \= Maximum forward road speed (m/s)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;M\_i   \= Kinematic agility factor (1.0 hover/tracked, 0.5 wheeled, 0.2 articulated)

&nbsp;

2\. Sort vehicles by S\_i in descending order.

&nbsp;&nbsp;&nbsp;Determinism Rule: Resolve ties using immutable vehicle instance IDs in ascending order.

&nbsp;

3\. Partition Elements:

&nbsp;&nbsp;&nbsp;Assign the first k \= ceil(|V| / 2\) vehicles to the BASE ELEMENT.

&nbsp;&nbsp;&nbsp;Assign the remaining |V| \- k vehicles to the MANOEUVRE ELEMENT.

&nbsp;

4\. Spatial Topology Optimization:

&nbsp;&nbsp;&nbsp;Project vehicle coordinates onto the normal of target vector T. Match assignments

&nbsp;&nbsp;&nbsp;to relative positions to prevent trajectory crossings during initial deployment.

\========================================================================================

&nbsp;

## **6\. Combat Balance Attribution Under Geometric Rescaling**

### **Reframing the Combat Balance Collapse**

The collapse of the heavy-hull faction from a 45% win rate (9/20) to zero (0/20) following realistic scale normalization was attributed to physical target size. In combat simulations with symmetric projectile mechanics, an increase in target area produces a gradual, approximately linear decline in survivability—not an immediate collapse to zero wins.

The failure was driven by AI fire-control and evasion systems evaluating friendly fire and incoming threats against the inflated diagonal bounding disc rather than the true hull geometry:

1. Rescaling expanded the heavy vehicle's bounding disc to $R \= 7.19\\text{ m}$ ($162.4\\text{ m}^2$).  
2. The weapon fire-control system casts safety cylinders along planned firing vectors. Because adjacent friendly units were modeled as 14.4 m spheres, safe firing lanes were falsely marked as obstructed, preventing heavy vehicles from returning fire.  
3. Simultaneously, evasion routines projected incoming enemy trajectories against the same inflated disc. Heavy hulls registered false incoming hits from rounds that would physically miss, trapping them in continuous evasion cycles that disrupted formations and exposed their flanks.

### **Decoupling Physical Area from AI Geometric Perception**

To isolate the root cause of the balance shift without exhaustive parametan orthogonal $2 \\times 2$ factorial attribution experiment:

| Experimental Arm | Physical Collider Model | AI Spatial Evaluation Model | Target Outcome Evaluated |
| :---- | :---- | :---- | :---- |
| **Arm A (Baseline)** | Rescaled True Mesh ($L \= 14\\text{ m}$) | Circumscribed Diagonal Disc ($R \= 7.19\\text{ m}$) | Replicates the 0/20 collapse state |
| **Arm B (AI Rectification)** | Rescaled True Mesh ($L \= 14\\text{ m}$) | Oriented Bounding Box / Chord SAT | Determines if AI perception errors caused the defeat |
| **Arm C (Pure Scaling)** | Unscaled Legacy Mesh ($L \= 8\\text{ m}$) | Scaled Diagonal Disc ($R \= 7.19\\text{ m}$) | Determines if AI weapon suppression alone causes defeat |
| **Arm D (Legacy Control)** | Unscaled Legacy Mesh ($L \= 8\\text{ m}$) | Unscaled Legacy AI Model | Re-establishes historical baseline (9/20 wins) |

If **Arm B** restores win rates to the 35–50% baseline, the performance drop is confirmed to stem from algorithmic perception errors rather than physical target geometry.

### **Aspect-Dependent Silhouette Exposure Mechanics**

Ground vehicle target exposure is highly anisotropic. For a rectangular hull with length $L$, width $W$, and height $H$, the presented target area $A\_{proj}$ at an azimuth $\\theta$ relative to the hull centerline and an elevation angle $\\phi$ is:

$$A\_{proj}(\\theta, \\phi) \= \\left( L \\vert{}\\sin\\theta\\vert{} \+ W \\vert{}\\cos\\theta\\vert{} \\right) H \\cos\\phi \+ (L \\cdot W) \\sin\\phi$$

In level engagements ($\\phi \\approx 0$):

$$A\_{proj}(\\theta) \= H \\left( L \\vert{}\\sin\\theta\\vert{} \+ W \\vert{}\\cos\\theta\\vert{} \\right)$$

For a 14 m $\\times$ 3.3 m $\\times$ 3.0 m vehicle:

* **Head-On Profile ($\\theta \= 0^\\circ$)**: $A\_{proj} \= 3.0 \\times 3.3 \= 9.9\\text{ m}^2$  
* **Broadside Profile ($\\theta \= 90^\\circ$)**: $A\_{proj} \= 3.0 \\times 14.0 \= 42.0\\text{ m}^2$

Exposing the broadside increases target area by **424%**. When elongated vehicles fail to maintain head-on orientation toward threats—due to rotational deadlocks or flawed evasion routines—they expose over four times their frontal area, resulting in rapid attrition.

* **Canonical Reference**: Przemieniecki, J. S. (1994). *Mathematical Methods in Defense Analyses*. AIAA Education Series; Ball, R. E. (2003). *The Fundamentals of Aircraft Combat Survivability Analysis and Design*.  
* **What It Replaces**: Isotropic disc-based line-of-fire checks and scalar radial threat spheres.  
* **Runtime Cost**: Evaluating projected chord area requires two absolute values and two multiply-accumulate operations per target candidate ($\\le 0.02\\text{ ms}$ for all active pairs).  
* **Bit-Level Determinism Survival**: Fully deterministic using standard fixed-point trigonometric lookups.  
* **Pre-registered Falsifier Metric**: Replacing the disc model with exact chord SAT in Arm B must recover the heavy vehicle faction win rate to $\\ge 35\\%$ across 50 simulated tournament matches.

## **7\. Zero-Cost Architectural Lighting and Environmental Traversability**

### **Procedural Instanced Surface Shading**

Driving architectural media facades by updating uniform buffers across entire city blocks produces flat, uniform lighting, while instantiating dynamic scene lights quickly exhausts GPU fill capacity. High-performance media facades avoid dynamic scene lights by utilizing procedural instanced surface shaders driven by closed-form wave functions.

Window meshes are rendered in a single instanced draw call where each instance buffer contains a packed 32-bit attributarchitectural zone or lighting circuit (0–255).  
* **Bits 8–15 (Spatial Phase Offset)**: Encodes spatial phase shift $\\psi\_i \\in \[0, 2\\pi)$ for traveling chase sequences.  
* **Bits 16–23 (Palette Index)**: Indexes into an offline color lookup table.  
* **Bits 24–31 (Wave Mode)**: Selects the waveform profile (0: Static, 1: Chase, 2: Strobe, 3: Triangle Pulse).

The vertex or fragment shader evaluates emissive intensity $I\_i(t)$ analytically using a single global float uniform representing simulation time u\_time:

$$I\_i(t) \= \\text{saturate}\\left( \\sin\\left(\\omega\_{mode} \\cdot \\text{u\\\_time} \+ \\frac{2\\pi \\cdot \\psi\_i}{255}\\right) \\cdot \\text{Contrast} \+ \\text{Bias} \\right)$$

This delivers dynamic per-window animations across thousands of architectural elements at **zero additional draw calls and zero runtime CPU cost**.

### **Tactical Contrast and the Weber-Fechner Readability Rule**

To prevent background facades from interfering with tactical clarity, lighting rendering must adhere to established visual hierarchy and stage lighting principles:

1. **Luminance Separation**: Under the Weber-Fechner Law ($\\Delta I / I \= k$), visual saliency depends on relative luminance contrast. Combat elements (muzzle flashes, tracers, hit impacts, and unit silhouettes) must maintain at least a **$3:1$ luminance ratio** over background architectural structures in HDR space.  
2. **Camera Alignment Attenuation**: Facade emissive shaders attenuate output intensity based on the angle between the surface normal and the camera view vector:  
3. $$C\_{emissive} \= C\_{base} \\cdot \\max\\left(0.1, 1.0 \- \\mathbf{N}\_{surface} \\cdot \\mathbf{V}\_{camera}\\right)$$  
4. Surfaces facing the tactical camera dim automatically, preventing broadside facades from dominating viewport contrast.  
5. **Automated Readability Verification**: A continuous integration render test captures viewports under default camera angles, verifying that the 95th-percentile luminance of static scenery never exceeds 35% of the 5th-percentile luminance of active combat effects.

### **Environmental Affordance and Traversability Legibility**

A player's inability to tell whether a debris-strewn street is traversable represents a failure of environmental affordance design. When passable clutter shares visual language, material textures, and silhouettes with impassable barriers, players are forced to probe geometry via trial-and-error pathfinding.

| Environmental Category | Physical Metric | Material and Visual Language | Illumination Treatment | Affordance Signal |
| :---- | :---- | :---- | :---- | :---- |
| **Certified Main Route** | Width $W \\ge W\_{swept} \+ 2.0\\text{ m}$ | Smooth asphalt/concrete; painted yellow curbs; unbroken pavement | Warm street-level lighting (3000 K); high ground specular response | Primary transit corridor; supports full formation movement |
| **Passable Clutter** | Obstacle height $\< 0.3\\text{ m}$; passage $W \\ge W\_{hull}$ | Crushed wooden pallets, light gravel, scattered trash, low cables | Grazing, low-angle light; soft contact shadows below axle height | Traversable with minor speed penalty; hulls push through |
| **Impassable Choke Point** | Structural height $\\ge 1.2\\text{ m}$; passage $W \< W\_{swept}$ | Corrugated containers, concrete Jersey barriers, twisted rebar | Cold blue perimeter security light; high-contrast warning stencils | Rigid physical barrier; pathfinding generates automatic detour |

Level design guidelines must also enforce the **Silhouette Ground Rule**: any passain an unbroken line of ground visibility from the overhead tactical camera. If a turn blocks ground visibility, lighting artists must place a distinct high-contrast light fixture behind the corner to silhouette the corridor entrance.

## **8\. Procedural Commentary Architecture**

### **Mitigating Perceived Repetition in Procedural Audio**

Human listeners do not perceive repetition based purely on overall phrase frequency; repetition perception is driven by short-term recency priming and working memory decay. Hearing the same phrase repeated within three minutes breaks player immersion, whereas the same line repeated hours apart passes unnoticed.

Sports game commentary architectures (such as EA Sports FC) mitigate repetition through intensity-tiered syntactic slotting combined with exponential recency decay:

Procedural Commentary Selection Engine

\========================================================================================

1\. Game Event Detected:

&nbsp;&nbsp;&nbsp;Event Type E (e.g., "Heavy Armor Penetrated", "Defile Blocked", "Formation Broken")

&nbsp;

2\. Compute Tactical Intensity Tier:

&nbsp;&nbsp;&nbsp;Evaluate match state into an intensity level Gamma in {1, 2, 3, 4, 5}

&nbsp;&nbsp;&nbsp;based on local combat density and recent hull attrition.

&nbsp;

3\. Contextual Voice Selection:

&nbsp;&nbsp;&nbsp;\- Voice 1 (Play-by-Play): Immediate tactical event description (\< 250 ms)

&nbsp;&nbsp;&nbsp;\- Voice 2 (Technical Analyst): Systems analysis and match context (delayed by 1.5 s)

&nbsp;&nbsp;&nbsp;\- Voice 3 (Field Radio Dispatch): Distant, filtered situational reports

&nbsp;

4\. Recency Penalty Evaluation:

&nbsp;&nbsp;&nbsp;For each candidate clip k in category (E, Gamma):

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Penalty\_k \= Sum\_over\_j \[ exp( \- (t\_current \- t\_fired\_j) / tau\_memory ) \]

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Score\_k   \= BaseWeight\_k \- (alpha \* Penalty\_k) \- (beta \* TotalTimesFired\_k)

&nbsp;&nbsp;&nbsp;Select clip deterministically using a pseudo-random hash over positive scores.

\========================================================================================

&nbsp;

### **Combinatorial Utterance Assembly**

Recording entire pre-scripted sentences severely restricts audio variety. Modern commentary systems maximize combinatorial diversity using dynamic clause concatenation:

$$\\text{Utterance} \= \\langle\\text{Observation Prefix}\\rangle \+ \\langle\\text{Subject Platform}\\rangle \+ \\langle\\text{Kinetic Action}\\rangle \+ \\langle\\text{Understated Commentary}\\rangle$$

By recording modular audio segments with matched vocal pitch, tempo, and acoustic reverb profiles, a focused library of 15 observation prefixes, 30 vehicle descriptors, 20 tactical actions, and 25 observational clauses yields:

$$15 \\times 30 \\times 20 \\times 25 \= 225,000\\text{ unique commentary variations}$$

This combinatorial scale ensures that players rarely encounter the same compound line within a single playthrough.

### **Authoring Guide for Understated Technical Commentary**

To maintain a deadpan, understated comedic tone across hundreds of voice lines without relying on explicit punchlines, writers must adhere to a strict editorial framework:

* **The Core Voice**: Commentators speak as detached, mildly bureaucratic technical inspectors. They treat catastrophic battlefield losses as minor maintenance deviations, logistical scheduling problems, or chassis stress non-compliances.  
* **The Structural Rule**: Never write an overt joke or punchline. Htic banality, technical precision, and emotional detachment from the combat situation.  
* **The Technical Discrepancy Principle**: Every line must focus on a technically accurate observation that downplays the severity of the crisis.  
  * *Banned (Overt Punchline)*: "Boom\! That heavy tank just got turned into scrap metal\!"  
  * *Approved (Bureaucratic Banality)*: "Unit Four has reported an unscheduled chassis separation. That will complicate their post-action maintenance log."  
  * *Approved (Technical Detachment)*: "A significant kinetic transfer has occurred on the port drive sprocket. Forward mobility is degraded, though the hull remains compliant with stationary cover protocols."  
  * *Approved (Understated Inconvenience)*: "The trailer assembly has exceeded allowable articulation margins. The driver will find that difficult to correct without a maintenance winch."

## **9\. Simulation Experiment Hygiene and Objective Motion Metrics**

### **Eliminating Spurious Experimental Results via Metamorphic Testing**

The retraction of eleven experimental results in a single week highlights a critical validation deficit: the lack of metamorphic relations and positive control assertions within the simulation test harness. In continuous, multi-agent systems, simple scalar assertions fail because correct continuous behavior cannot be captured by static values. When an experimental feature is silently bypassed—due to an overridden configuration static, an unmet conditional predicate, or leaked memory state—the simulation defaults to baseline routines, producing plausible outputs that are easily mistaken for valid test results.

Software quality assurance for autonomous vehicle simulation relies on metamorphic testing with positive controls:

| Testing Safeguard | Mechanism and Implementation | Failure Condition Detected | Enforced Action on Violation |
| :---- | :---- | :---- | :---- |
| **Activation Assertion** | Atomic execution counter $C\_{arm}$ placed inside the active code path | Test arm configuration failed to load, was overwritten, or predicate evaluated to false | Test run immediately aborted; marked TEST\_ARM\_UNEXECUTED |
| **Differ Assertion** | Mandatory state trajectory delta between control and test: $\\Vert{}S\_{test} \- S\_{ctrl}\\Vert{} \> 10^{-4}$ | Feature code ran but produced zero physical effect on the simulation state | Result rejected; flagged as an inert experimental branch |
| **Positive Sensitivity Control** | Injected intentional disturbance (e.g., \+50% drag, inverted yaw rate command) | The metric harness lacks the sensitivity to detect meaningful operational changes | Validation suite fails; metrics recalibrated before testing |
| **Hermetic State Verification** | CRC32 memory hashing of global singletons and heap pools between seed runs | Scenario passed due to uncleaned state from a preceding test execution | Test fixture failed; memory sandbox re-initialized |

### **Perceived Motion Intelligence: SPARC and Intention Legibility**

Evaluating path-planning performance purely through travel time or path length rewards erratic, twitching trajectories that human observers rate as robotic or erratic. Human perception of agent intelligence is governed by two measurable kinematic properties: motion smoothness and intention legibility.

Movement smoothness is quantified by the Spectral Arc Length (SPARC) metric applied to the vehicle's speed profile. Unlike jerk derivatives, which amplify high-frequency discretization noise, SPARC evaluates the arc length of the Fourier magnitude spectrum ta\_{SPARC} \\triangleq \-\\int\_0^{\\omega\_c} \\sqrt{\\left(\\frac{1}{\\omega\_c}\\right)^2 \+ \\left(\\frac{d\\hat{V}(\\omega)}{d\\omega}\\right)^2} d\\omega$$

where $\\hat{V}(\\omega)$ is the normalized Fourier velocity spectrum. Discontinuous acceleration, heading oscillations, and micro-hesitations introduce complex high-frequency spectral harmonics, driving $\\eta\_{SPARC}$ to more negative values. Natural, proficient vehicle motions yield SPARC scores closer to zero.

Intention legibility measures how quickly an observer can infer an agent's intended goal $\\mathbf{G}^\*$ from an initial segment of its trajectory $\\mathbf{T}\_{0 \\to t}$:

$$L\_{motion}(\\mathbf{T}) \= \\frac{\\int\_0^T P(\\mathbf{G}^\* \\mid \\mathbf{T}\_{0 \\to t}) f(t) dt}{\\int\_0^T f(t) dt}$$

where the probability distribution $P(\\mathbf{G} \\mid \\mathbf{T}\_{0 \\to t})$ is evaluated using an optimal-control cost function comparing the observed trajectory against optimal direct paths to all candidate goals. Trajectories that commit decisively to their destination alley score near 1.0, whereas paths that meander or initially head toward alternative defiles score near 0.0.

To monitor movement quality without manual user studies, the automated test harness computes a composite Perceived Obedience Index (POI):

$$\\text{POI} \= w\_1 \\cdot \\text{SPARC}\_{yaw} \+ w\_2 \\cdot \\text{SPARC}\_{linear} \+ w\_3 \\cdot L\_{motion} \- w\_4 \\cdot \\text{Latency}\_{ack}$$

where the weights $w\_i$ are calibrated once against baseline human preference evaluations and tracked across continuous integration builds.

## **10\. Architectural Composition Hazards**

Combining multiple autonomous behaviors can produce secondary interactions where individual systems undermine each other. The table below outlines these composition hazards and defines the required architectural resolution rules:

| Interacting Modules | Hazard Mechanism | Systemic Failure | Priority Resolution Rule |
| :---- | :---- | :---- | :---- |
| **Funnel Reference Governor** $\\times$ **Corridor Right-of-Way (RoW)** | The Reference Governor maintains forward progress along the safe corridor funnel, while the RoW system mandates a full stop at a hold line outside the defile entry. | The Governor misinterprets the RoW stop as an obstacle blockage, triggering unsticking routines that break the vehicle queue. | **RoW Priority Override**: The RoW gate introduces a virtual static barrier into the Governor's admissible set $\\mathcal{C}\_{safe}$ at the hold line, smoothly ramping reference speed to zero without triggering unsticking states. |
| **Capsule Turning Envelopes** $\\times$ **Arrive-and-Anchor Dressing** | Wheeled vehicles attempting terminal dressing request turning envelope reservations, competing with adjacent tracked vehicles executing neutral-steering pivots. | Vehicles grant and revoke reservations cyclically, creating reservation flapping that prevents formation settlement. | **Asymmetric Dressing Priority**: Tracked vehicles hold absolute reservation priority during dressing; wheeled vehicles yield turning envelope claims and lock their heading to their approach direction ($\\pm 45^\\circ$). |
| **Articulated Kinematics** $\\times$ **Terminal Dubins Entry Curves** | Planning terminal maneuvers using single-body Dubins or Reeds-Shepp curves ignores trailer off-tracking. | The tractor reaches its slot while the trailer swings wide, colliding with adjacent squadmates or static walls. | **Trailer-Centric Planning**: Terminal paths are planned for the trailer rear axle as the ps bounded by $\\vert{}\\psi\\vert{} \\le 0.5 \\psi\_{critical}$. |
| **Metamorphic Sensitivity Controls** $\\times$ **Deterministic Replays** | Metamorphic testing introduces intentional physical mutations (positive controls) to verify metric sensitivity. | Mutated state variables leak into global pools or affect pseudo-random number generator alignment, causing replay desynchronization. | **Sandboxed State Allocations**: Mutation runs execute in isolated memory arenas; simulation state structs are cleared via explicit memory reset and verified by CRC32 hashes before each seed run. |

Robust agency in deterministic multi-agent simulation does not arise from layering reactive heuristics onto an uncoordinated physics plant, nor from endlessly tuning local avoidance weights. When an architecture bridges the gap between deliberative planning and execution using invariant funnels, couples vehicle orientation directly to translation through verified turning reservations, models heavy transport via closed-form kinematic constraints, and enforces experimental validity through metamorphic controls, the simulation achieves high behavioral fidelity, spatial legibility, and bit-level determinism within a fixed 30 Hz budget.

&nbsp;
