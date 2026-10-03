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

- **Even the same binary disagrees across machines with different system math libraries** (measured 2026-09-15): the
  laptop (Ubuntu 24.04, glibc 2.39) and builder0 (Ubuntu 26.04, glibc 2.43) produce different sim-baseline hashes
  (`772dfb5198e15909` vs `c9cfbb1a221f5c94`) while each is repeatable. Godot calls the system's `libm` for trig, and
  glibc versions differ in the last bits. So `tests/baselines/sim_state_hash.txt` holds one line per glibc version
  (`glibc-2.43 <hash>`); builder0's is canonical, and `make sim-baseline` skips machines with no recorded line.

## Same binary, same machine, same seed: the witness and what broke it (round 17, sim)

**The witness.** `--hash-every=N --hash-until=T` makes any mode print `SIM_HASH tick=<t> <state_hash> frames=<p>/<f>`
every N ticks and quit at T (the frame counters ride after the hash and are not compared). `--hash-detail-from=T0` adds,
from T0, every unit's hashed fields, velocity, command (aim point included) and intent, every shell, each team's intel
contacts, and a `clock` line (the nav map's iteration, the tick's `delta`, `Engine.time_scale`, the fog field's
`enabled`/`threaded`), all at full bits, plus a one-shot census of every collision object in the tree. `--hash-buffer`
keeps all of it in memory and prints it at quit, so printing does not change the frame pacing being observed.
`make windowed-series` runs N windowed `--scripted` skirmishes of one command and reports the fork rate (k of N pairs),
the trajectory classes and each run's first divergence; `tests/scale/witness_first_field.py` names the first tick and
the first field two dumps disagree on. A `--scripted` run has no recorder: this is the witness for "is a windowed A/B
one fight or two".

**Mechanism 1 (round 16, fixed `0010bcb4`):** the skirmish's fire RNG was unseeded (only the match runner called
`seed_spawns`).

**Mechanism 2 (round 17, fixed `eab2e906`): `Engine.time_scale` is simulation input.** Godot hands every
`_physics_process` `physics_step * time_scale` (it scales the step, not the tick rate: measured), and the simulation
keeps ticking after `Match.finished`. The kill-cam slowed time to 0.2 at a decided elimination and restored it on a
WALL-CLOCK schedule, so how many ticks integrated a shortened step depended on how fast the frames came. builder0's
windowed frames crawl at ~1 s, so ~3 ticks ran slowed, a different number from run to run: the same windowed Sumps
seed gave two outcomes from tick 625 on (5 of 6 runs one way, 1 of 6 the other), headless a third (no kill-cam). It
showed as every moving unit off in the last bits at once. The kill-cam now counts ticks (`HOLD_TICKS`, `RAMP_TICKS`);
`Match` warns once if a LIVE tick runs at `time_scale != 1` (unless `--slow-motion=`). Writers of `Engine.time_scale`:
the kill-cam (after `finished` only), tactics' `--slow-motion=` (live, deliberate), and the look tools (only with the
tree paused). Ruled out with evidence on the way: instance ids and heap layout (`--perturb-ids`, `--perturb-heap`), the
fog field's worker thread (it writes only its own image), frame/tick alignment (1:1 in every run), nav syncs.
**A rule follows:** nothing outside the simulation may write engine state the simulation reads (`Engine.time_scale`,
`physics_ticks_per_second`, the tree's pause) on a schedule that is not a function of ticks.

**Determinism is per mode** (same build, same machine, same seed):

| Mode | Covered by | Notes |
|---|---|---|
| Match runner, headless (`--match`) | `make determinism`, `make sim-baseline` (foundry) | seeds every RNG via `seed_spawns` |
| Skirmish, headless | the witness, by hand (`--skirmish --scripted --hash-every`) | not in `check`; foundry's baseline never covered the Sumps |
| Skirmish, windowed `--fixed-fps` | `make windowed-elimination-pair` (past an elimination: the kill-cam) | needs a display; requested for `check-all` |
| Skirmish, windowed real time | nothing (frame timing decides ticks per frame) | lockstep needs the port (D3/D4) |
| Host (`--host`), headless | by hand: 2 runs identical to tick 600 (laptop, 2026-10-03) | not in `check` |
| Garage fight | nothing: it opens in the planning pause and never ticks unattended | a scripted garage fight would cover it |
| Windowed vs headless, same seed | equal UNTIL a decided elimination with a recent kill | after it, by design: headless has no kill-cam |

**Every simulation feature we build on Godot's engine is future porting work.** That's accepted (find the fun first,
then port a settled design), but we keep the debt visible and cheap to pay.

## Where the simulation touches engine math today (inventory)

Update this table whenever simulation code adds an engine dependency.

| System | File(s) | Engine dependency | Port to |
|---|---|---|---|
| Movement and collision | `game/tank/tank.gd`, `game/tank/tank_motion.gd` | round 3 (combat X4): heading, speed, turning circles, and drift are pure `TankMotion.step_in_place` over vectors (`+ − × ÷ √`, no per-tick trig); the body's basis is set with `Basis.looking_at` (cross products); `move_and_slide` collisions; `rotation.y` (an euler extraction) is read only for sync and the state hash | integer kinematics on the same step, circle vs segment collision (detcore has arena walls) |
| Weapons timing and events (combat, round 3) | `game/tank/tank.gd`, `game/match/match.gd` | reloads and bursts in whole ticks; `incoming_projectiles` is pure 2D dot/cross geometry; shells still sweep engine raycasts | shells as integer segment tests |
| Shells | `game/combat/shell.gd` | physics raycasts per step | integer segment vs box/circle tests |
| Line of sight, perception | `game/ai/perception.gd`, `game/match/visibility_field.gd` | physics raycasts | detcore grid line of sight |
| Pathing | `game/ai/pathing.gd`, `game/ai/tank_brain.gd` | `NavigationServer3D` navmesh queries | grid A* or a baked integer graph |
| Match rules | `game/match/match.gd` | raycasts, float timers by tick | integer rules on the core |
| Randomness | `game/units/army.gd` and brains | Godot `RandomNumberGenerator` (seeded) | one PRNG we implement, seeded by the match |
| Brain scoring | `game/ai/tank_brain.gd`, `order_controller.gd` | float utility math, trig for angles | fixed point, or floats restricted to `+ − × ÷ √` (measure on ARM first) |
| Cover line of sight and tactical positions (ai, round 2) | `game/ai/cover_map.gd`, `game/ai/tactical_query.gd` | none at decision time: pure 2D boxes/segments (slab tests, dot and cross products, `√` for normalizing), quantized memo keys; one `cos`/`sin` per obstacle at arena load (layout rotation) | integer segment-vs-box on the core; rotations as integer axis vectors in layout data |
| Line of fire (ai) | `game/ai/fire_lanes.gd` | pure segment-vs-circle with a small-angle spread (no trig); defers to `Match.friendlies_in_line_of_fire` | fixed point |
| Matchups and squad tactics (ai) | `game/ai/matchups.gd`, `game/ai/squad_tactics.gd` | floats; `log` in the penetration curve (mirrors `Armor.penetration_multiplier`); arcs and aim by dot products | a penetration lookup table; fixed point |
| Brain LOD, variants, per-tick caches (ai) | `game/ai/tank_brain.gd`, `brain_variants.gd`, `ai_tick_cache.gd` | tick counts and command-line flags only | nothing to port |

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
