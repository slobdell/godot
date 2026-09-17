# Proposal: run the simulation at 30 Hz with physics interpolation

> **Status: approved by the lead and in progress on `stream/combat`** (2026-09-17; combat owns it). Steps 1–2 (every
> tick count derived from `SimClock.TICK_RATE`, still 60 Hz, sim baseline unchanged) are done for match, tank, combat,
> ai, tactics, control's three constants and the announcer; step 3 (the flip) is being measured on a scratch copy.
> Not merged to `main` until the orchestrator clears it. The original proposal follows, then the checklist that
> render and control worked out.

## What it bought (measured 2026-09-17, the lead's laptop and builder0)

**The simulation's CPU per second roughly halved, as designed.** `make remote T="sim-profile TIME=60"` on builder0,
Condemned 31 v 27: the whole tick costs 6.68 ms at 30 Hz against 5.7-6.4 ms at 60 Hz on the same machine, so per-tick
cost is about the same and there are half as many ticks: **200 ms of simulation per second against 378**.

**On the lead's laptop the frame improves everywhere, by less than half**, because the GPU and the renderer don't
care about the tick rate (`make perf-scene`, same build, same seed, 30 Hz vs 60 Hz at 720p):

| Vehicles | 60 Hz frame | 30 Hz frame |
|---|---|---|
| 59 | 134 ms (7.5 fps) | 101 ms (10 fps) |
| 41 | 80 ms | 38 ms (26 fps) |
| 34 | 33 ms | 27 ms (37 fps) |

**Against the lead's target** (a locked 30 fps at 1080p with 60 vehicles; before: 60 fps held at 13 vehicles at 720p
and never at 1080p): at 1080p, 30 Hz holds **30 fps to about 30 vehicles** (29 ms at 30, 34 ms at 34) and **10 fps at
60** (98 ms). 60 fps at 720p now holds to about 22 vehicles. So the tick change is a large step and **not enough on
its own**: at 60 vehicles a tick still costs ~31 ms on the laptop, of which **~85% is the unit controllers** (brains).
The next lever is brain cost per second, not the tick rate. A think rate of 5/s instead of 10/s was tried and the
measurement was inconclusive — `perf-scene` is a live battle, so two runs diverge and equal vehicle counts are not
equal fights; it needs `make sim-profile` or `make ai-perf`, which measure a fixed workload.

**What the think rate is worth** (ai, `make ai-perf UNITS=60`, fixed workload, interleaved runs, thread CPU per living
unit per second of match time): the champion thinks 7.5 times a second and costs ~9 800 µs; 5 times a second costs
~8 300 (-15%); 3.75 times a second costs ~7 000 (-29%). **Halving how often a brain thinks buys ~29% of the brains,
about 25% of the tick** — a real lever, and not enough to take 30 vehicles to 60. Closing that gap needs structural
work on what a brain does per think. Variants `x6t5` and `x6t4` carry the two lower rates; neither is adopted, because
the trade (fewer units that react, or more units that react late) is the lead's to make.

**What the tick change cost in behaviour: nothing measurable, and the checking found something else.** Dodging was the
behaviour most at risk, since a brain in contact now thinks every 133 ms. Counting dodge *attempts* rather than shells
that missed (`tests/ai_scenarios/scenario_dodge_rate.gd`, 8 seeds): a tank spent **0 of 502 inbound ticks dodging at
30 Hz — and 0 of 893 at 60 Hz** on a pre-30 Hz snapshot of the same code. Inside `CombatMotion` every candidate
direction scores "would still be hit" (254 of 254 evaluations at 30 Hz, 248 of 248 at 60). A shell crosses 50 m in
~0.7 s; a hull needs ~0.8 s to swing perpendicular. **Dodging as designed has never worked at either tick rate**, and
the "dodge rates" quoted since round 3 are shells missing for other reasons (the differences between rates are inside
the noise of a 45-shell sample). Avoidance of a beaten zone, which reacts over seconds rather than tenths, is intact:
0 ticks in the zone against a control's 16, under denser fire than before. The fix is a round-6 design item in
[unit_ai.md](unit_ai.md): dodging has to begin before the shot is fired, not after.

Caveat: the laptop was running this agent's own jobs; the numbers are pessimistic, and the 30 Hz and 60 Hz runs were
taken back to back under the same load.

## Start here: the interpolation checklist (render + control, 2026-09-17)

**The core trap.** With physics interpolation on, Godot *draws* a body at its interpolated transform, but
`global_transform` / `global_position` read in `_process` still return the **last physics tick's** value. Anything
positioned from a body every rendered frame jitters against the vehicle the player sees unless it reads
`get_global_transform_interpolated()`.

| Who | What reads a body per frame | How it's handled |
|---|---|---|
| render | underglow, blob shadows, tracers (follow shell nodes), order markers, motion dust, perf-scene camera | `FxWorld.visual_transform(node)` (interpolated when interpolation is on; identical at 60 Hz) |
| render | muzzle flashes, shell blasts spawned from `weapon_fired` at tick positions | shifted by the shooter's (interpolated − physics) offset; needs `shooter` in `weapon_fired` (K2 keeps it) |
| render | impacts, kills, wrecks at event positions | correct as is: they're world positions of what happened |
| control | RtsCamera follow and vision framing, selection rings, hull bars, picking and box select, center-on, route lines | `Shown` helper → `get_global_transform_interpolated()`; the rig's Camera3D and ring MultiMeshes are `PHYSICS_INTERPOLATION_MODE_OFF` (moved every frame already) |
| control | orders, sight checks, EdgeMarkers/ElementAwareness, Radar, CinematicCamera | stay on tick positions (the simulation never sees the smoothed world) |
| audio | `engine_system.gd` reads `source.global_position` per frame for voice placement and speed | flagged to audio: the speed estimate steps at 30 Hz |
| combat | tank spawn, respawn, bench placement; shell spawn | `reset_physics_interpolation()` after placing (or a one-frame streak from the old place); shells interpolate like bodies so tracers are smooth |
| combat | networked clients' tanks (smoothed toward snapshots in `_process`) | `PHYSICS_INTERPOLATION_MODE_OFF` on non-simulating tanks (no double smoothing) |

**K1 is a wall-clock contract now** (orchestrator, 2026-09-17): "an order takes effect within 100 ms of the input".
At 30 Hz that's exactly 3 ticks, so **30 Hz is the floor**: a 20 Hz tick would break the feel even if it were free.

**How tick counts are written** (`game/match/sim_clock.gd`): seconds of ticks as `SimClock.TICK_RATE * 12`, cadences as
`SimClock.TICK_RATE / 10` (constant expressions can't call functions; `maxi` works), ~20 Hz cadences as
`maxi(1, (SimClock.TICK_RATE + 10) / 20)` so they round to whole ticks at 30 Hz instead of running every tick, runtime
conversions with `SimClock.ticks(seconds)` / `SimClock.seconds(ticks)`. Doctrine tables keep drill timings in
sixtieths of a second and `DoctrineTable.drill_ticks` converts. The Makefile's `SIM_HZ` drives every `--fixed-fps`
and the Python tools; `tests/test_sim_clock.gd` checks it matches `project.godot` and `SimClock`.

---


## Why

CP1 ([streams/references/fx_tricks.md](streams/references/fx_tricks.md), M1) made the simulation tick the frame-rate
blocker: every `_physics_process` together must fit **5 ms at 60 vehicles** on the lead's laptop, and a tick costs
~12–20 ms there today. `make sim-profile` splits it (laptop, Condemned 31 v 27):

| Band | ms per tick | Owner |
|---|---|---|
| Unit controllers (OrderController + TankBrain, priority −10) | ~9.3 | ai |
| Tanks (driving, turret, gun) | ~1.7 → ~1.3 after CP1 cuts | combat |
| Match (suppression, intel, rules) | ~0.5 | combat |
| Elements, order executor, shells | < 0.1 | tactics, control, combat |

Every line of that table is paid **per tick**. Trimming each band buys tens of percent. Halving the tick rate buys
50% of all of it at once, including ai's four-fifths. There's no other single change that does this: the vehicles'
own cost is mostly `move_and_slide` (engine code), and the brains are already thinking every 6–18 ticks.

## What 30 Hz means

- `physics/common/physics_ticks_per_second=30` in `project.godot`.
- **`physics/common/physics_interpolation=true`** so rendering stays smooth at 60+ fps: Godot 4.4+ interpolates
  `Node3D` transforms between ticks. Nothing in the project uses it today (no `reset_physics_interpolation` anywhere).
- Every tick-count that means a *duration* is halved, or better, derived from one constant
  (`Match.TICKS_PER_SECOND`, read from `Engine.physics_ticks_per_second`), so the game plays the same in seconds.
- Match-runner and smoke targets pass `--fixed-fps 30` instead of 60.

## Where the 60s live (inventory)

Legend: **hard** = a literal 60 (or `60 * n`) meaning one second, which silently changes behaviour at 30 Hz;
**cadence** = "every N ticks", whose real-time meaning doubles; **fine** = already scaled by `delta` or read from the
engine.

| Area | hard | cadence | Notes |
|---|---|---|---|
| `game/match/` | 16 | 6 | contact memory `60 * 12`, resupply / repair / control-capture seconds, artillery flight ticks, threat-field decay `ticks / 60.0`, `EngagementStats.SAMPLE_TICKS`, the announcer's cooldowns; cadences `INTEL_EVERY_TICKS` 6, `SUPPRESSION_SAMPLE_TICKS` 3, `CONE_EVENT_TICKS` 6, `VisibilityField.REFRESH_TICKS` 30 |
| `game/tank/`, `game/combat/` | 8 | 4 | `TankMotion.TICK_SECONDS = 1/60` (ai's `predict()` uses it), reload / burst `_ticks_of(seconds * 60)`, shield delay, deploy rates; `lateral_grip * delta * 60` is a linearisation tuned at 60 Hz (use `1 - pow(1 - grip, delta * 60)`); cadences `DEPLOY_SETTLE` 15, `PACK_SETTLE` 30, `CREEP_LEG` 30, and `ticks_since_hit` read in ticks by tactics, control, camera and UI |
| `game/ai/` | 9 | ~41 | think rates (`THINK_EVERY_TICKS` 6/12/18, `think_ticks` 9 in the champion variant), commit, stall, jink, peek, bait and suppress timers, `OPTION_TIMEOUT_TICKS`, order-controller lane / fire checks (`FIRE_CHECK_TICKS` 3 is a **measured behaviour tuning**: round 4 lesson 20), `IncomingFire.HORIZON_TICKS`, CPU commander think / muster / freshness |
| `game/tactics/` (+ `doctrines/doctrine_*.json`) | 0 | 11 (+3 JSON) | element `UPDATE_TICKS` 6, report cooldown 600, drills' sudden / turn ticks, orbit 240, `react_ticks` / `bait_patience_ticks` / `timeout_ticks` in the doctrine tables |
| `game/control/`, `camera/`, `ui/` | 0 | 4 | mostly `_process(delta)` already; `RESPONSE_TICKS` 3 (the **K1 3-tick response guarantee**), element awareness 90, cinematic camera 120, squad chip 180 |
| `game/announcer/` + `tools/announcer/events.py` | 2 | 0 | `TICKS_PER_SECOND := 60` in GDScript and its Python twin: event `t` = tick / 60 |
| `game/network/`, `modes/`, `main.gd` | 1 | 1 | the combat-log pose timer; `detcore` already runs at 30 Hz; `main.gd` reads the engine rate |
| `tests/` | ~240 lines in ~60 files | a handful | exact per-tick assertions (locomotion accel/tick, reload ticks, heat per second, shield recharge, control point, deploy, `decay(60)`), and "N seconds" loops written as `60 * n` frames |
| `tools/*.py`, `mk/*.mk` | 9 + 19 | — | `--fixed-fps 60` in every headless target, `1000/(60 × speedup)` ms-per-tick maths |

## What breaks with interpolation on, and what to do

| Thing | What happens | Fix |
|---|---|---|
| **Teleports** (spawns, respawns, bench placement, tests that set `global_position`) | The hull visibly slides from its old pose for one tick | `reset_physics_interpolation()` after every teleport (`Match._build_tank`, `Tank.respawn`, `_bench_army`) |
| **Cameras** that follow a hull in `_process` | Follow the interpolated transform: smooth, as long as they read `global_transform` in `_process`, not in `_physics_process` | Audit `FollowCamera`, `RtsCamera.follow`, `CinematicCamera` |
| **Effects spawned at a muzzle / impact** in a signal during the tick | Spawn at the tick's pose while the hull renders up to one tick behind (≤ 0.33 m at 20 m/s): a flash can sit ahead of the barrel | Spawn effects as children of the weapon node, or accept it; render's pools own this |
| **Shells** (`Node3D` moved in `_physics_process`) | Interpolate for free | None |
| **Beams, arcs, tracers** drawn from two points | Endpoints come from tick positions | Negligible at 30 Hz |
| **Turret yaw** set in `_physics_process` | Interpolated with the node | None |
| **Order latency / the K1 3-tick response guarantee** | 3 ticks becomes 100 ms instead of 50 ms | Restate the guarantee in ms (≤ 100 ms still feels instant for RTS orders) or make it 2 ticks. **Control decides** |
| **Brain reaction time** | Thinks every 6 ticks become 200 ms instead of 100 ms, unless halved to 3 | Convert every cadence to seconds through one constant, then re-tune only what measures worse (lesson 20: measure behaviour, not only the clock) |
| **Fast rounds** | Shells sweep a ray per tick, so there's no tunnelling, just longer rays | None |
| **Collision** | `move_and_slide` steps twice as far per tick (≤ 0.67 m at 20 m/s). Hulls still stop at walls; contact jitter may rise a little | Watch `test_combat_sim_cost` and the ramming tests |
| **Determinism and the sim baseline** | Every baseline hash, every `MEASURE` in ai scenarios and tactics parity moves | Re-record once, on purpose, on builder0 (twice), in the same commit that flips the rate |
| **Networking** | `Replication.TANK_SYNC_INTERVAL` 0.033 s ≈ every tick; client smoothing already runs on `_process` delta | None expected; run `net-smoke`, `relay-smoke` |
| **Web export** | No threads; interpolation is main-thread | None expected; `web-smoke` |

## What it would cost to do properly

1. **One stream owns it** (combat is the natural owner: `Match`, `Tank`, `TankMotion`, the runner and `mk/match.mk`),
   and the others merge it the day it lands.
2. **Step 1 (no behaviour change, ~half a day):** add `Match.TICKS_PER_SECOND` (from the engine) and `Ticks.of(seconds)`,
   and convert every *hard* 60 in every stream to it, with the rate still 60. The sim baseline must not move: that
   proves the conversion is exact. Each stream reviews its own files. Tools and make targets read the rate from one
   variable (`SIM_HZ`).
3. **Step 2 (~half a day):** convert every *cadence* to seconds (`THINK_EVERY_SECONDS := 0.1`), still at 60 Hz. The
   baseline still must not move.
4. **Step 3 (a day, mostly measuring):** flip to 30 Hz with interpolation on, add `reset_physics_interpolation()` at
   teleports, re-record the baseline, then re-run the behaviour gates that were tuned in ticks: ai scenarios, tactics
   parity, `make faction-matrix`, `make engagement`, control's response playtest and a windowed look at the camera
   and effects.
5. **Tests:** ~60 files assert per-tick numbers. Steps 1–2 rewrite them in seconds, so step 3 only changes the rate.

**Expected result:** ~50% off the whole tick (by the table above, ~12 ms → ~6 ms on the laptop, in reach of M1's
5 ms together with ai's own work). The risk is concentrated in step 3's behaviour re-measurement, not in the code.

**Not recommended:** flipping the rate without steps 1–2. About 70 durations would quietly double: reloads, shield
delays, contact memory, brain reaction times.
