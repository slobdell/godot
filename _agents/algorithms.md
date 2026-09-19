# The algorithm roster: what the industry does, what we have, what we owe

> **Why this file exists.** The lead set the standard of work on 2026-09-19
> ([game_design.md](game_design.md) *Standard of work*): *"We want to use the best algorithms, no matter how difficult
> they might be to implement… it's all well established industry knowledge."* The orchestrator then named the specific
> gaps **in a message to one stream**, which is exactly the failure this project keeps writing lessons about — knowledge
> that lives in a conversation and not in a document. So it lives here.
>
> **This is a roster, not a schedule.** Every row is an established technique with a canonical reference. **Adopting one
> is a decision for its owning stream** (`_agents/workstreams.md`), and the acceptance for each is a measurement, not a
> merge. Rows marked **OWED** are things we have decided we want and have not built.
>
> **The one hard constraint:** determinism ([determinism.md](determinism.md)). Replays, networked play and the sim
> baseline require identical output from identical input, and `sin`/`cos` already differ across builds. **A technique that
> cannot be made deterministic is not available to us** — that rules out learned policies, and rules out none of the rows
> below. When implementing any of these: fixed iteration counts, neighbours ordered by unit name, `dt` from the fixed
> tick, never the wall clock.

## What the engine already gives us (probed on our pinned Godot 4.7.2, 2026-09-19)

**Asked by the lead — "are some of these available as Godot libraries we can just install?" The answer is better than
libraries: several are already in the engine we ship, unused.** Probed with `ClassDB` rather than read from docs:

| Engine feature | Status here | Note |
|---|---|---|
| **`PATH_POSTPROCESSING_CORRIDORFUNNEL`** on `NavigationPathQueryParameters3D` | **already in effect — this row was wrong** | ~~unused~~. **`map_get_path(..., optimize=true)`, which `Pathing` already calls, *is* the corridor funnel** — `optimize` selects it. nav established this, 2026-09-19. So we have had funnel smoothing since round 1 and did not know it. The query-parameters form is still worth moving to, but for **`PATH_METADATA_INCLUDE_*`** and for the *option* of `..._EDGECENTERED` / `..._NONE` — **not** for the funnel |
| **`NavigationAgent3D` avoidance** (`avoidance_enabled`, `radius`, `avoidance_layers`/`mask`, **`avoidance_priority`**, `use_3d_avoidance`) | **unused — we wrote our own ORCA** | Godot's avoidance is RVO2 internally. **`avoidance_priority` is engine-side right-of-way**, which we also built by hand. Worth a deliberate comparison: ours is deterministic by construction and we know its cost; the engine's is C++ and maintained. **Do not swap without measuring both — but do not leave the comparison unmade either** |
| **`NavigationObstacle3D`** | **unused, and deliberately** | dynamic obstacles have no consumer: nothing blocks drivable space mid-match, and the lead's destructible-cover design was chosen to avoid it (arena's X9 ruling). Kept here so nobody re-derives the question |
| **`NavigationLink3D`** | **unused** | off-mesh connections — the natural expression of a **bridge**, a jump, or a tunnel. Relevant to arena's water/pits work |
| **`PATH_METADATA_INCLUDE_*`** (types, RIDs, owners) | **unused** | per-point provenance on a returned path: which region/link each point came from. **This is how a caller can tell "the path ends at the goal" from "the path ends at the closest reachable point"** (lesson 76) without inferring it from distance |
| `AStar3D`, `AStarGrid2D` | unused | general-purpose graph search, if a hand-rolled grid is ever wanted. The determinism note in `determinism.md` names "grid A\* or a baked integer graph" as the eventual replacement for `NavigationServer3D` |

**The rule this suggests: prefer an engine feature to a hand-rolled one, and a hand-rolled one to a third-party addon.**
Engine features are deterministic-by-version, maintained, and already shipped. **Third-party Godot addons are the worst
option for simulation code** — unpinned float behaviour, no determinism guarantee, and an upstream we do not control. For
*tools* (editor helpers, generators) an addon is fine; for anything inside the tick, it is not.

## Movement and pathfinding

| Technique | Canonical reference | State | What it fixes |
|---|---|---|---|
| **A\* over a navigation mesh** | standard | **have** — `Pathing.find_path`, Godot `NavigationServer3D`, baked once at startup as a half plus its 180° mirror (trip-up 21) | routing around static geometry |
| **ORCA** (optimal reciprocal collision avoidance) | van den Berg et al., *Reciprocal n-body Collision Avoidance* (2011) | **have** — `game/ai/avoidance.gd`, round 6 | two units resolving a gap without mirroring each other forever. Took arrival from 33/60 to 60/60 in a hold-fire drive |
| **PID control** | classical | **have** — `game/ai/pid.gd`, round 6; per-faction gains in `control_gains.gd` | station-keeping without oscillation. 0.35 m mean slot gap against 4.58 m for the old proportional law |
| **Context steering** | Andrew Fray, *Context Behaviours* (GDC) | **have** — `game/ai/combat_motion.gd`, 16-direction interest/danger ring | movement while fighting |
| **Funnel algorithm** (path smoothing) | Mononen — shipped in the engine | **have, all along** — `map_get_path(..., optimize=true)` *is* the corridor funnel | ~~waypoints are raw navmesh corners~~. **The premise was false and so was the diagnosis it carried.** "Vehicles saw off turns" was **steering at the corners**, not corner-shaped waypoints, and round 6's carrot/lookahead fixed it. Kept as a row because deleting it would let someone re-derive the same wrong conclusion |
| **Arrival with a standoff, for a fixed gun** (shoot-and-scoot) | Reynolds arrival + gun-truck doctrine | **have** — `CombatMotion` style `standoff`, round 7 | **the lead's loudest bug**: *"scouts are just running directly into their targets and then they have to turn around."* Round 3's `run` style drove at the target, broke off at 9 m and reversed to 22 m with the gun pointing backwards. Measured over 25 s against a durable tank (builder0): closest approach **3.0 m → 27.7 m**, nose on target **17% → 79%**, shots landed **29 → 211**, and **91%** of the time inside the effective band. ~~`--nav-off=standoff` restores the old behaviour for A/B~~ — **⚠ that switch is BROKEN on `main` as of `2cae3bda`** and silently does nothing (nav, 2026-09-19): `CombatMotion.fixed_style` is a static var initialised from `Movement._off`, and those three classes reference each other, so the initialiser can run before `Movement`'s statics are populated and see an empty switch list. **The measurements above stand** — they were taken by assigning the style directly, which tests do — **but the command-line A/B does not work until nav's read-time resolution lands.** |
| **Angular acceleration limit** (rate limiting on the plant) | classical control | **OWED — and now measured** | **`TankMotion`'s plant has NO angular acceleration: yaw rate = turn × max rate, applied instantly.** Measured at the lead's pose (`make nav-rotation`, builder0): a tank pivoting **118°** on a face order reaches **90% of its peak turn rate in ONE tick**. Its *stop* is already smooth (31-tick decay, no overshoot) and it pivots about its own centre, which is correct for tracks — **so the defect is the start, and only the start.** The fix belongs **in the plant** (`TankMotion.step_in_place`), not in `face`: one limit fixes every caller at once rather than masking it in the one that noticed |
| **Reeds–Shepp paths** (Dubins with reverse) | Reeds & Shepp (1990) | **OWED — and now measured** | **A scout K-turning 159° to a point behind it OVERSHOOTS its final heading by 20.7° — it arrives still turning.** Its start is smooth and it drives a real arc, so the defect is purely the *arrival*: either Reeds–Shepp so the K-turn ends **on** the heading, or an arrival that brakes the yaw. `min_turn_radius_m` exists in the data (K3) and the planner ignores it. This is *the* classical answer to a car-like vehicle with a turning circle, and Reeds–Shepp is the version permitting reverse — the three-point-turn case. Listed as unbuilt since round 2 |
| **Flow fields / vector fields** | Supreme Commander 2, Planetary Annihilation; Emerson, *Crowd Pathfinding* | **OWED** | the crowding: **~23% of unit-time stalled at 52 units**, blocked by friends and terrain. One field per destination rather than N paths, so units share a congestion gradient instead of each defending its own line. **An architecture change** — it replaces per-unit path ownership, and touches the Movement API, `blocked_by` attribution and reachability. Lands as its own checkpoint with before/after on `make nav-fight` |
| **Hierarchical pathfinding (HPA\*)** | Botea, Müller & Schaeffer (2004) | **OWED** | long routes across a 242 m arena, and stability under repathing (currently a full search every second) |
| **Velocity obstacles / time-to-collision** | Fiorini & Shiller (1998) | **partial** — inside ORCA | using predicted collision *time* to decide who slows rather than who swerves |

## Decisions

| Technique | Canonical reference | State | What it fixes |
|---|---|---|---|
| **Utility AI** | Dave Mark, *Behavioral Mathematics for Game AI* | **have** — `tank_brain.gd`, `utility_curves.gd` | per-unit option choice |
| **Battle drills / SOP layer** | US Army doctrine, adapted | **have** — `game/tactics/`, rounds 4–6 | element-level responses to triggers |
| **Hysteresis / commitment in scoring** | Dave Mark; standard practice | **OWED** | option thrash. Measured: **46 drive-target jumps per unit-minute**, about a third genuine option switches. The standard treatment is a bonus for the incumbent option or a minimum dwell time. Round 6 found three separate every-tick flip-flops (two drills stealing an element; support-by-fire alternating with near-ambush; 47 idle re-issues) |
| **Model-predictive control / lookahead** | classical; Dubins-style trajectory scoring | **candidate** | the honest version of the lead's *"decision weighing"*: simulate candidate actions forward a fixed horizon, score, pick, re-plan next tick. Deterministic, and what makes units look like they are *anticipating* rather than reacting |
| **Influence maps** | Tozour, *Influence Mapping* (AI Game Programming Wisdom) | **partial** — `Match.threat_field`, `cover_map`, `fire_lanes` | spatial reasoning about danger and control. We have the fields; we do not use them for route choice |

## Explicitly rejected

| Technique | Why not |
|---|---|
| **Reinforcement learning for navigation or steering** | **Determinism is the blocker**: a learned policy is a large pile of floats evaluated in an order we do not control, and replays, lockstep and the sim baseline all require bit-identical output. Beyond that, the problems being hit are missing *numbers* and missing *standard techniques*, not missing models — RL would learn a standoff distance we can write down. Asked and answered with the lead, 2026-09-19 |
| **Learned army-level strategy (AlphaStar-style)** | Where ML genuinely earns its place in games, and **not the current problem.** Revisit only if unit behaviour is solved and the CPU commander is the weak link. The *bring-your-own-Gemini* AI Commander in [vision.md](vision.md) is a different thing: an LLM issuing orders through the existing command API, not a learned policy inside the simulation |

## How to add a row

1. Name the technique and its canonical reference. **If there is no canonical reference, that is a warning sign** — the
   lead's standard is *"take full advantage of the academic knowledge"*, which means finding the established answer, not
   inventing a clever one. A bespoke solution to a solved problem is the failure mode.
2. Say which measured symptom it addresses, with the number.
3. Say how its adoption will be measured — before and after, on the configuration players actually get.
4. Check it against determinism before writing any of it.
