# The 30 Hz simulation tick: what it cost and what it bought

> **Done and merged, round 5 (2026-09-17).** The simulation runs at 30 Hz with physics interpolation; the lead asked
> for it the day it was proposed. This file is the record: the numbers, the two latent defects the refactor exposed,
> how tick counts are written now, and what is still on the table. Combat owned the work; render, control and audio
> each converted what they draw or hear. If you are changing the tick rate again, read *How tick counts are written*
> and *The interpolation checklist* first — everything else here is history and evidence.
>
> **In one line:** script cost per simulated second fell 27%, a locked 30 fps at 1080p went from never to about 29
> vehicles on a quiet laptop, the lead's 60-vehicle target is still roughly 2× away, and ~85% of what is left is the
> brains — whose cost per second the tick rate cannot touch.

## What it cost (so the next refactor of this size can be estimated)

One agent-day, in three steps, each verified before the next: **(1)** every hard "60 per second" rewritten in terms
of `SimClock.TICK_RATE`, rate unchanged, **sim baseline unchanged** — which is the proof the conversion was exact;
**(2)** the same for ~70 per-tick cadences and ~40 test files, again with the baseline unchanged; **(3)** the flip,
with the baseline re-recorded on purpose. About 40 files of code and 40 of tests, across every stream's paths.

Two **latent defects** surfaced, both wrong at 60 Hz too, neither found by a year of play (details in
[balance.md](balance.md) *Round 5*):
- **Guns fired a tick late** — controllers ask `ready_to_fire()` before the tank counts its reload down, so every
  trigger pull waited an extra tick. A 0.1 s machine gun fired 8.6 rounds a second instead of 10, a tank cannon lost
  under 0.5%: a handicap **differential by archetype**, worst for the swarm.
- **Going round a beaten zone thrashed** — a pulsing threat reading looked like the fire lifting, so a unit dropped
  its step round and picked the other side on the next check.

The lesson worth keeping: *a refactor that forces every timing assumption into the open pays for itself in what it
finds, independently of the change it was for.*

## What it bought (measured 2026-09-17, the lead's laptop; settled with render)

**Per simulated second, the simulation's script cost fell by a quarter to a third.** Two A/B pairs, each the same
laptop, build, seed and 60 simulated seconds with only the tick rate flipped (`make sim-profile`): **513 → 377 ms/s
(−27%)** on the round-5 branch, and **490 → 329 ms/s (−33%)** repeated on the tip with a quieter machine. Compare
within a pair only — `perf-scene` and `sim-profile` both run a live battle, so two runs diverge and that spread is
where the 6 points come from. Both pairs, with their band breakdowns, are in
[streams/references/combat/tick-rate-ab-2026-09-17.json](streams/references/combat/tick-rate-ab-2026-09-17.json).
The first pair, by band:

| | 60 Hz | 30 Hz |
|---|---|---|
| per tick | 8.56 ms | 12.56 ms |
| **per simulated second** | **513 ms** | **377 ms (−27%)** |
| controllers (OrderController executing + TankBrain thinking) | 417 ms/s | 318 ms/s |
| tanks (driving, turret, gun) | 66 ms/s | 34 ms/s (halved) |
| match rules (intel, suppression, control) | 20 ms/s | 20 ms/s (unchanged) |

**The ceiling, and why it was always going to be one:** only work that happens *per tick* halves. Anything on a wall-clock cadence — brains
thinking 10 times a second, intel 10/s, suppression 20/s — costs the same per second by construction, and it is most
of the tick. The controllers band is both: executing every tick (halves) and thinking on a cadence (doesn't).
An earlier note here said 47%; that compared two builder0 runs of *different fights* and was wrong — the same trap
the pair discipline above exists to avoid.

Put the other way round: **of a 60 Hz tick's cost, only the per-tick part could ever have been halved.** On the
laptop that part was ~96 ms/s of the 513 (tanks 66, match rules are cadence-bound, the controllers' *executing* half
the rest), so the tick change alone could never have bought much more than it did — and **no further tick-rate change
can buy the brains' thinking, which is ~85% of a tick and runs on a wall clock.** If round 6 needs another step
change in frame rate, it has to come from brains thinking less often, thinking more cheaply, or fewer vehicles.

**In the game, on the lead's laptop, at 1080p** (`make perf-scene`, merged build: armies hold until ordered, guns at
their real rate of fire). **The answer depends on what else is running on the machine, and that is worth more than
the average:**

| Vehicles | Frame (quiet laptop) | |
|---|---|---|
| 19–29 | **33.3 ms, p95 33.5** | a genuinely locked 30 fps |
| 33–35 | 37.8 ms (26.5 fps) | just misses |
| 41 | 55 ms | |
| 65 | 100 ms (10 fps) | |

Every phase of both runs (720p and 1080p, vehicles against frame, p95, GPU, tick cost and ticks per frame):
[streams/references/combat/perf-30hz-laptop-2026-09-17.json](streams/references/combat/perf-30hz-laptop-2026-09-17.json).

With five agents sharing the CPU, render measured the same build holding a locked 30 at **12–15 vehicles**. Both
numbers are real; the lead's own machine will be quiet when he plays, and **nobody has yet measured it truly idle**.
Before this round: 60 fps held at 13 vehicles at 720p and never at 1080p.

**The remaining gap is brains, not the tick rate.** At 58 vehicles headless on the laptop a tick costs 18.4 ms with
brains and 2.7 ms without (render, `PROFILE_FLAGS=--no-brains`): ~85%. Thinking less often is the obvious lever and it
is a behaviour decision, not only a cost one. Measure it with `make sim-profile` or `make ai-perf`, never with
`perf-scene`: that is a live battle, so two runs diverge and equal vehicle counts are not equal fights.

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

## What the step cap does when the machine can't keep up (and the measurement trap it creates)

`max_physics_steps_per_frame = 3` chooses **slow motion over a death spiral**. When a frame takes longer than a tick,
the engine runs extra ticks to catch up; with Godot's default of 8 that feeds back (more ticks → longer frame → more
ticks) and pins the game at a few fps. Capped at 3, the simulation simply stops keeping up: **game time advances at
most 3 ticks (100 ms) per rendered frame**, and whatever is left over is lost.

The arithmetic, and it matters for reading any timed run:

| Rendered frame | Game time per second of wall time |
|---|---|
| 33 ms (30 fps) | 1.0× — real time, with headroom |
| 100 ms (10 fps) | 1.0× — exactly at the cap (3 ticks × 33 ms) |
| 300 ms | 0.33× |
| 1 s | **0.1×** |

Audio measured the extreme on builder0 with a window at 30 a side: the music had played **48.8 s while the match
clock read 5.0 s**, i.e. about a tenth of real time — a machine rendering that scene at roughly 1 fps, behaving
exactly as the cap says it should. On the lead's laptop at the sizes that matter the clock stays true (at 65
vehicles, 3.41 ticks per 100 ms frame ≈ real time).

**The trap:** on an overloaded machine, *anything measured per second of WALL time is measuring a slow-motion match*
— kills per minute, shells per second, engagements per match minute would be out by up to 10×. Per-tick and
frame-time measurements are unaffected. Use `sim_seconds` from `MATCH_RESULT`, or count ticks, and never a stopwatch
against a windowed remote run.

**Open for round 6:** the cap is a trade, not a setting with a right answer. 3 keeps the clock honest and lets frames
stutter; 1 keeps frames smooth and lets the clock slip; 8 is the spiral. It only bites where the machine is already
too slow, so it should be decided together with the battle-size question, not before it.

## The interpolation checklist (render + control, 2026-09-17)

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


## Why it was proposed (the state before, kept as history)

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

## How tick counts are written now (read this before changing the rate again)

`game/match/sim_clock.gd` is the one source: `SimClock.TICK_RATE`, `TICK_SECONDS`, `ticks(seconds)`,
`seconds(ticks)`. In shipped code:

- **Durations:** `SimClock.TICK_RATE * 12` for twelve seconds, `SimClock.ticks(0.75)` at runtime.
- **Cadences:** `SimClock.TICK_RATE / 10` for ten times a second (constant expressions can't call functions, but
  `maxi` works), and `maxi(1, (SimClock.TICK_RATE + 10) / 20)` for ~20 Hz so it rounds to whole ticks rather than
  running every tick at 30 Hz.
- **Doctrine tables** keep drill timings in sixtieths of a second; `DoctrineTable.drill_ticks` converts.
- **Announcer fixtures** keep their timelines in sixtieths of a second (recorded data must not move when the rate
  does); `MatchEventAdapter` divides live ticks by `Engine.physics_ticks_per_second` — the *runtime* rate, because
  tests change it.
- **Tools and make targets** read `SIM_HZ` from the Makefile (exported), which every `--fixed-fps` uses.
- `tests/test_sim_clock.gd` fails if `SimClock.TICK_RATE`, `project.godot` and `SIM_HZ` ever disagree.

Settings that ship with it (`project.godot`): `physics_ticks_per_second=30`, `physics_interpolation=true`,
`physics_jitter_fix=0.0`, and **`max_physics_steps_per_frame=3`** — Godot's default of 8 is the catch-up spiral that
pinned a full battle at 7.5 fps, and at 30 Hz a slow frame can now cost at most three ticks.

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

## The plan as written before the work (kept: the estimate was right)

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
