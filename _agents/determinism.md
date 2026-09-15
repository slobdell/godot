# Determinism: what we have, what lockstep needs, and the follow-up

> Written 2026-09-15 after the lead's cost strategy (*"making the game servers strictly match makers and packet
> routers"*, [server_management.md](server_management.md) §5). **Status: open follow-up.** Round 2 follows the
> guidelines below; the port itself comes after the core loop is fun.

## The short version

- **Same build, same seed → same match.** This holds today and is enforced: `make determinism` (twice in a row,
  byte-identical results) and `make sim-baseline` (a recorded state hash), both in `make check`.
- **Different builds do *not* agree.** The same seeded match on native Linux and WebAssembly in Chrome, on the same
  machine, diverged (measured 2026-09-13: different shots and damage; archive/round1/netcode.md). Phones (ARM) are
  unmeasured and should be assumed to differ too.
- **Why:** not floating point as such. The round-1 control experiment (`FloatProbe`, printed by `make det-spike`) showed
  `+ − × ÷ √` hash identically native vs wasm, while `sin`/`cos`/`atan2`/`exp` don't. The divergence comes from
  library math inside Godot's physics, navigation, and trig, which each compiler builds differently. ARM compilers may
  also fuse multiply-adds, which changes results even for plain arithmetic.
- **Why it matters:** player-hosted matches (built) don't need cross-build agreement, because only the host
  simulates. **Lockstep does**, and lockstep is how ranked play works on relay-only servers: every device simulates
  from the command stream and compares hashes ([references/netcode_designs.md](streams/references/netcode_designs.md)
  §1). A match between a phone and a browser would desync within seconds on today's simulation.
- **What's proven:** an integer core (`game/network/detcore/`: Q16.16 fixed point, integer CORDIC trig, grid line
  of sight) is bit-identical native vs wasm (`make det-spike`, hash `ea02d9652cc08086`) at 485 µs per tick in wasm
  for 20 tanks. Only a spike: the real game's movement, combat, pathing, perception, and brains are not ported.

**Every simulation feature we build on Godot's engine is future porting work.** That's accepted (find the fun first,
then port a settled design), but we keep the debt visible and cheap to pay.

## Where the simulation touches engine math today (inventory)

Update this table whenever simulation code adds an engine dependency.

| System | File(s) | Engine dependency | Port to |
|---|---|---|---|
| Movement and collision | `game/tank/tank.gd`, `game/tank/tank_motion.gd` | physics body motion, trig for heading | integer kinematics, circle vs segment collision (detcore has arena walls) |
| Shells | `game/combat/shell.gd` | physics raycasts per step | integer segment vs box/circle tests |
| Line of sight, perception | `game/ai/perception.gd`, `game/match/visibility_field.gd` | physics raycasts | detcore grid line of sight |
| Pathing | `game/ai/pathing.gd`, `game/ai/tank_brain.gd` | `NavigationServer3D` navmesh queries | grid A* or a baked integer graph |
| Match rules | `game/match/match.gd` | raycasts, float timers by tick | integer rules on the core |
| Randomness | `game/units/army.gd` and brains | Godot `RandomNumberGenerator` (seeded) | one PRNG we implement, seeded by the match |
| Brain scoring | `game/ai/tank_brain.gd`, `order_controller.gd` | float utility math, trig for angles | fixed point, or floats restricted to `+ − × ÷ √` (measure on ARM first) |

## Guidelines for simulation code from now on (rules and ai streams)

These are about *portability*, not a ban on the engine. When two approaches cost about the same, pick the portable one.

1. **Put new simulation math in pure classes over plain numbers** (like `TankMotion`), not inside scene-tree or
   physics callbacks. Pure code ports and tests without a scene.
2. **Prefer simple geometry we own:** grids, line segments, circles, and axis-aligned boxes. Examples: cover features
   as segments and boxes, `friendlies_in_line_of_fire` as segment-vs-circle, splash as a distance check.
3. **Route engine queries through one seam each.** One line-of-sight function, one path query, one ray or shape
   query per purpose, so a later port replaces one function instead of fifty call sites. Don't scatter
   `intersect_ray` or `NavigationServer3D` calls through new code.
4. **Avoid trig where vector math works.** Use dot and cross products for "is it in my firing arc", "which side of
   the wall", and turret tracking instead of `atan2`, `angle_to`, or `sin`/`cos`. Compare squared distances instead of
   taking square roots when possible.
5. **Keep the existing rules:** decisions read `Match.tick`, never the clock; iterate in sorted order; randomness
   only from match-seeded generators; no async engine features in the simulation (orientation trip-up 57).
6. **Record new engine dependencies** in the inventory above, in the same commit.

## The follow-up (after round 2, before ranked play)

| Step | What | Done when |
|---|---|---|
| **D1: Measure the gap continuously** | A cross-build check: the same seeded match exported to web, run in headless Chrome, hash compared with native (like `make det-spike`, but on the real simulation). Expected to fail today; it's a tracked number, not a gate. Add an ARM phone run. | a make target reporting the first diverging tick and system |
| **D2: Decide the port boundary** | Which systems move to the integer core, and whether "floats without library math" is enough for some of them (measure on ARM) | a written decision in this doc |
| **D3: Port behind the seams** | System by system, running old and new side by side on seeded matches until behavior matches closely enough (it won't be identical; re-balance with the matchup matrix after) | the full simulation runs on the core; native, wasm, and ARM hashes agree |
| **D4: Lockstep play** | The protocol in netcode_designs.md §1 on the ported simulation | a browser and a phone finish a match with matching hashes |

Owner: a future netcode stream (paused in round 2). Until then the orchestrator checks at each merge that new
simulation code follows the guidelines and updates the inventory.
