# Stream: brains (the simulation tick's biggest line: the AI, without changing one decision)

> Read `_agents/orchestration.md` (the worker contract), `_agents/unit_ai.md`, `_agents/tank_brain.md`,
> `_agents/navigation.md` *Measuring*, `_agents/sim_tick_rate.md`, `_agents/verification.md` (rule 3, *Attributing a
> behaviour's cost*), `_agents/determinism.md`, `_agents/workstreams.md` *Round 16*. You own `game/ai/**`,
> `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai_*.gd`,
> `tests/test_nav_*.gd`, `tests/test_tactics_*.gd`, `mk/ai.mk`, `mk/nav.mk`, `tools/tactics_ladder.py`. Contracts
> C16.1–C16.5 in `workstreams.md`. **The one rule of this round: every decision a brain makes stays identical — the sim
> baseline is UNMOVED by every commit you make (C16.2).**

## The lead's direction (2026-10-02)

> *"the game is getting extremely choppy … it's likely that we just haven't done the work latley to optimize our code to
> just find basic efficiencies we can gain across the codebase - before sacrificing any of the existing graphics or
> gameplay let's find (or profile our code) where we can just get better performance out of our application"*

He plays `make skirmish` natively on his laptop (Intel UHD 620, window 1854×1011), default armies (~24–27 a side at the
start), and it is choppy from the first second. Nothing is cut: not a behaviour, not a think, not a unit. The work is
finding what the brains compute that is never used, compute twice, compute every tick when its answer cannot have
changed, or allocate on the way.

## Where things stand (measured today, 2026-10-02, at `1efa9940`)

- **The simulation tick is the wall, and the brains are ~85 % of it.** `make perf-scene` on his laptop at his window
  with his flags (`_agents/streams/references/perf/r16-before-1080-his-flags.json`): at 30 vehicles a frame averages
  36.9 ms of which `tick_script_ms` is **24.0 ms** (every `_physics_process` in one tick); at 24 vehicles 19.8 ms; at
  52 vehicles 35 ms with 3.5 ticks a frame (the sim falls behind; `max_physics_steps_per_frame=3` then runs the game in
  slow motion). The budget is **≤ 5 ms a tick at 60 vehicles** (`fx_tricks.md` *The budget*), brains ≤ 4 ms inside it.
  Round 5 measured brains at 85 % of a headless tick (`sim_tick_rate.md:79`: 18.4 ms with brains, 2.7 without, 58
  vehicles, laptop); nothing since has re-measured that split — **your first number is that split again, today.**
- **`make ai-perf` at round 15's close** (`streams/archive/round15/squad.md` Status, `e05a44fc`, builder0, a quiet
  window): `ai_usec_per_tick` **10 022** against the budget of 4 000, `perf_reference` 1.01× (judged). builder0 is
  ~2.75× faster than his laptop for this work, so that is ~27 ms of brains a tick for him at 60 units.
- **LOS is the known hot query**: `_agents/streams/references/round15/squad/p3_perf_leak_runs.txt` — 60 brains, 712
  ticks, **148 100 LOS queries, 96 532 computed** (~208 queries, ~136 raycast walks a tick). `CoverMap.clear_line`
  memoises on quantised grids (`game/ai/cover_map.gd:157-198`, flushed wholesale at `MEMO_LIMIT`: a thrash is
  possible); `Perception.has_line_of_sight` (`game/ai/perception.gd:15-20`) has **no memo at all** and `nearest_enemy`
  allocates an Array per call and raycasts per enemy.
- **Cadence exists**: brains think every `THINK_EVERY_TICKS` (3 at contact, 6 idle, 1.5 near; `tank_brain.gd:17-30`,
  `_due_to_think`), staggered by `think_offset`; `OrderController` holds the last command on non-due ticks
  (`order_controller.gd:190-205`); elements decide on `(tick + id) % UPDATE_TICKS` (`elements.gd:149-173`). So the
  question is what a think costs and what runs *outside* the cadence every tick.
- **Suspects from a read of the code** (hypotheses, each to be measured by removal or by a counter, never asserted):
  - 49 `distance_to` in `tank_brain.gd`, 10 in `cpu_commander.gd`, 9 in `combat_motion.gd`, 8 in `gunnery.gd` against
    4 `distance_squared_to` in all of `game/ai` — many are threshold compares.
  - `movement.gd` makes 13 `NavigationServer3D.map_get_closest_point` calls plus `Pathing.map_get_path` inside the
    re-plan path; round 9 showed re-plans fire on events ~97 % of the time (`movement.gd:2225-2250`), so count how many
    nav queries a tick actually makes at 30 a side, and which are repeated for the same point in the same tick.
  - Per-think allocations: Arrays and Dictionaries built to be read once (option tables, candidate lists, `enemies_of`),
    `String` keys formatted per call, lambdas in `filter`/`sort_custom` on hot paths.
  - What every brain does on a NON-think tick (`order_controller.gd` per-tick reflexes, `Steering`, `CombatMotion`):
    is any of it the same answer as last tick?
- **Instruments you have:** `make ai-perf` (`MEASURE ai_usec_per_tick`, `ai_usec_per_tick_parts` with `DETAIL=1`,
  the LOS counters; refuses under load — take judged numbers in a quiet window on builder0 and say so); `make
  sim-profile` with and without `PROFILE_FLAGS=--no-brains` (`unattributed_ms` ≈ brains); `make scale-bench`;
  `tests/test_ai_perf_equivalence.gd`. None of them is the game he plays (headless `--match`); play's `make perf-play`
  (CP1, early) is, and `tick_script_ms` there is the number he feels. Builder0 for ratios; the laptop before/after is the
  orchestrator's quiet-window run.

## Backlog (in order)

Every item: a counter or a profile FIRST (what runs how often, how long), then the change, then `make remote T=check`
with the sim baseline read from the wrapper's line (`sim-baseline <hash> (baseline unmoved)`), `make determinism`,
`ai-scenarios-check` counts, `tactics-drills`, `nav-scenario-arms` — then the number again. Commit with before/after
numbers, their commit, machine, workload, sample.

- **A1. The split, today.** `make remote T="sim-profile TIME=60"` with and without `--no-brains` at 30 a side (his
  army sizes: `--budget` at the default, Law v Condemned as in his recording `build/recordings/2026-10-02T18-59-00-sumps.jsonl`,
  seed 92721, arena sumps) and at 60; `make remote T=ai-perf DETAIL=1`; the LOS counters. Write the table in Status:
  ms a tick for brains, per part, per unit, queries a tick. This is the before; every later item is measured against it.
- **A2. A per-brain tick profile by section** (`SimProfile.add` is sim's, additive sections in YOUR files are yours:
  `brain/think`, `brain/perceive`, `brain/los`, `brain/nav`, `brain/steer`, `brain/execute`) so `make sim-profile`
  attributes `unattributed_ms` instead of guessing. Counters for nav queries and LOS queries per tick.
- **A3. LOS once per pair per tick, memoised where the answer cannot have moved.** `Perception.has_line_of_sight`
  gets the same quantised memo as `CoverMap.clear_line` (same grid, same flush rule, **deterministic**: keyed by
  quantised positions, never by wall clock or iteration order); the memo thrash at `MEMO_LIMIT` measured (hit rate per
  tick before and after). The ratio of queries computed falls; the baseline does not move (a memo that changes an
  answer is a bug: the quantisation must be the one already accepted for `clear_line`, or finer).
- **A4. Distance thresholds without the square root** where the compare is against a constant or a squared radius
  (`distance_squared_to`); the same for any `normalized()` whose length is then discarded. Mechanical, baseline-neutral
  by construction (float results identical for compares; NOT for anything that feeds a decision through the value
  itself — leave those).
- **A5. Allocation per think and per tick:** reuse pre-sized Arrays/Dictionaries (the `TankCommand.sanitize_into`
  pattern in `tank.gd`), remove `String` keys formatted per call, replace lambda `filter`/`sort_custom` on hot paths
  with loops. Measure with `Performance.get_monitor(OBJECT_COUNT)` / `MEMORY_STATIC` over 60 s and the tick ms.
- **A6. Nav queries per tick:** one `map_get_closest_point` per hull per tick at most (memo the answer for the tick);
  re-plans that recompute a path identical to the one held (same goal, same start cell) skip; count before/after.
- **A7. The non-think tick:** what `OrderController` and `CombatMotion` compute on held ticks that equals last tick's
  answer; hold it (`executed_held` already exists — extend the held set) ONLY where the sim baseline proves equality.
- **A8. Elements and commanders** (`game/tactics`, `cpu_commander.gd`): `ElementPlan` and `TacticsFormation` per
  decide — allocations, repeated slot solves, `distance_to` tables rebuilt per member.
- **A9 (stretch). Think LOD by what the player can see?** NO — that changes behaviour (C16.1). Instead: a think whose
  inputs have not changed since the last think (same contacts, same order, same cell) may reuse its last utility
  table — propose with the equality proof, ship only if the baseline is unmoved across 8 seeds × 3 maps.

## How to verify

- `make remote T=check` green on your last commit; the sim baseline `05df1d55ba49cde1` (glibc 2.43) UNMOVED on every
  commit — read it from the wrapper's line, never from a pipe. `make remote T=determinism`.
- `make remote T=ai-perf` judged (PASS, `perf_reference` ≤ 1.5×) in a quiet window: before and after each item, same
  commit pair, same units; `make remote T="sim-profile …"` both arms; `tests/test_ai_perf_equivalence.gd`.
- `make remote T=ai-scenarios-check` (counts), `make remote T=tactics-drills`, `make remote T=nav-scenario-arms`,
  `make remote T="tactics-ladder …"` only if a brain file you touched is in the ladder's path (identical md5 across
  three runs is the proof).
- **On the laptop, in the game he plays:** after CP1, `make perf-play` once per merged item (the orchestrator takes the
  quiet-window before/after; your own laptop runs carry the load caveat). `tick_script_ms` at 30 and at 52 vehicles is
  the line you report.
- Behaviour parity beyond the baseline match: the recording replay (`make rig-vanish REPLAY=…` is airship's; the
  recorder's census is enough: a 60 s `--match` at seeds 1–8 on yard/terminus prints identical `MATCH_RESULT` json
  before and after — write `make ai-parity SEEDS=1-8` in `mk/ai.mk` as A1's second half).

## Don't touch

`game/match/**`, `game/tank/**`, `game/combat/**`, `game/arena/**`, `game/units/**` (sim's; request a cached-stat
API or a per-tick LOS service from sim in Status + a message to the orchestrator; build an adapter in your paths
meanwhile), `game/ui/**`, `game/control/**`, `game/camera/**` (hud), `game/theme/**` (render; `game/theme/fx/bench/**`
is play's), `game/modes/**`, `game/audio/**`, `mk/fx.mk`, `mk/play.mk` (play), `project.godot`, `mk/core.mk`,
`game/main.gd` (orchestrator; additive edits listed in merge notes only).

## Waiting on the lead

Nothing. No lead gate in this stream. Design questions go in Status; take the baseline-neutral option.

## Status

(the worker keeps this current: plan, done with numbers, decisions, questions for the lead, requests to other streams,
known issues, what to playtest, next steps, merge notes, the green hash)
