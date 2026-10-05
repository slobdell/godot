# Determinism: what we have, what lockstep needs, and the follow-up

> Written 2026-09-15 after the lead's cost strategy (*"making the game servers strictly match makers and packet
> routers"*, [server_management.md](server_management.md) §5). **Status: open follow-up.** Round 2 follows the
> guidelines below; the port itself comes after the core loop is fun.

## The short version

- **Same build, same seed → same match.** This holds today and is enforced: `make determinism` (twice in a row,
  byte-identical results, on foundry and crossing) and `make sim-baseline` (a recorded state hash per dealt map, below),
  both in `make check`.
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
  glibc versions differ in the last bits. So `tests/baselines/sim_state_hash.txt` holds lines per glibc version;
  builder0's are canonical, and `make sim-baseline` skips machines with no recorded line.

## Per-map baseline (round 18, ship)

**The baseline is one line per DEALT map, not one match on foundry.** Until round 18 `sim-baseline` ran its match on
`foundry` (`Arena.DEFAULT_LAYOUT`), which has no containers and is never dealt; round 17 turned every container on every
dealt map and the baseline, correctly, did not move. Now:

- **File:** `tests/baselines/sim_state_hash.txt`, one `<glibc> <map> <hash>` line each, with a provenance comment
  (`# glibc-2.43 yard: recorded on builder0 at <commit>, twice, agreeing (<date>)`). A two-column line from before
  round 18 is refused by name, never read as foundry.
- **Maps:** `Arena.DEFAULT_LAYOUT` + every name in `Arena.ROTATION`, read from the game (`tests/support/dealt_layouts.gd`;
  `make sim-baseline-layouts` prints them). **A dealt map with no line FAILS** (the message names
  `make sim-baseline-adopt`); a machine with no lines at all SKIPS (the laptop). `Arena.CANDIDATES` (C18.2) carry no
  line: the check names each one as such, and `candidates-smoke` (check-all) plays each 10 s headless.
- **Match:** the baseline's own (sim_baseline doctrines, seed 3, 40 s, elimination) with `--arena=<map>`; foundry's line
  is the number it always was. All maps at once (fixed tick: load cannot move a hash).
- **Arm assertions:** an "arena: … using foundry" fallback fails that map; two maps with one hash fail.
- **Adopting:** `make sim-baseline-adopt` reads every map twice on builder0 at once, refuses the whole adoption on ANY
  disagreement, merges moved and missing lines, drops lines of maps no longer dealt, keeps other machines' lines, and
  prints one commit message with each map before → after. Every branch is stub-driven in `tools/test_sim_baseline.sh`.
- **Lines recorded** (builder0, glibc 2.43, read twice at `1586d40e`, 2026-10-04 15:32 PDT; the launch tree's gameplay):
  foundry `05df1d55ba49cde1`, yard `797dc49109a452d8`, pit `098f7d5cb3795e7f`, terminus `8b0309ee85e497dc`, crossing
  `efc8449e97b18eb1`, sumps `bf0bdb98568700db`, locks `db5512352146803e`.
- **Proved red** (builder0, 2026-10-04): one mirrored container pair in yard moved 0.5 m and turned 3° (an uncommitted
  scratch edit, reverted) → `yard MOVED … got b4b363f56978cc3f`, the six others unmoved; a stale pit line → `pit MOVED`.
- **Blind spot, known:** 40 s on the Terminus does not reach its turned boxes (round 17: yard's table) — a change there
  can pass its line. The stretch pricing of a longer or second line is in `streams/ship.md` (round 18).

**`make determinism`** runs its two seeded matches on foundry AND on `crossing` (water, two bridges, 24 containers),
all four at once; each pair is judged on its own and a failure names the map (stub-driven: `tools/test_determinism.sh`).
foundry's pair, files and hash (`762a0576f944f5b7`) are unchanged.

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
showed as every moving unit off in the last bits at once. The kill-cam now counts ticks (`HOLD_TICKS`, `RAMP_TICKS`), bounded in real time where ticks do not keep up (progress = max(ticks, wall s ÷ 1.5): the tick schedule leads at ≥ 0.67× speed; below it the wall clock ends it by 3 s; **the wall term is off in a `--fixed-fps` run** (read from `/proc/self/cmdline`: Godot consumes engine arguments before `OS.get_cmdline_args()`, the trap that let the bound fire in the first F5 pair) or with `--kill-cam-ticks-only` (where there is no `/proc` — web, Android, Windows — the bound is ON unless that flag is passed: intended, a browser match must not end in a ten-second slow motion; a witness run there warns if it lacks the flag), so every witness run is the pure tick schedule, and a capped real-time run is presentation after a decided match, not a fork); it prints `KILL_CAM start tick=… ms=…` / `KILL_CAM end tick=… ticks=… ms=… by=ticks|wall`;
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
| Skirmish, headless | `make sumps-witness-hash` (by hand: seed 3, tick-900 hash) | not in `check`; foundry's baseline never covered the Sumps. builder0 glibc 2.43: `441426e6489ed9eb` on the launch tree and the kill-cam fix (unmoved by it); `58cff8d52f018e7b` from `ddf710b2` (yard's CP1 turned the Sumps' containers: a different fight by design), twice; **`882d74cd0ca71201` from `90c289f2` on** (yard's CP2, containers at strength B), twice |
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
