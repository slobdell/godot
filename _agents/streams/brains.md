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

_Updated 2026-10-03 ~02:30 by the brains worker. Builder0 was loaded all evening (perf_reference 1.68–1.93×, five
other streams' checks), so every **ms** below is a loaded-machine number. The judged before/after needs a quiet
window. **Counts** (calls a tick, the scenario_perf fight, state hashes) don't depend on load._

### Report: the backlog, item by item

| item | state | what, and the number |
|---|---|---|
| **A1** the split | DONE | base `8318b9db`: brains **92 %** of a 17.1 ms tick at 56 vehicles (1.3 ms with `--no-brains`). `make ai-parity` written (the second half). |
| **A2** per-section profile | DONE, and more | `brain/*` parts + calls in `sim-profile`, `nav.closest@<site>`, `--brains-parts` (any run), **`make ai-script-profile` / `-play`** (Godot's script profiler: function-level, the whole tick, headless or on his skirmish). |
| **A3** LOS memo | MEASURED, NOT BUILT | rays are 0.13 ms a tick (46 calls; ~10 repeats a frame): an exact memo buys ~0.03 ms (sim's null agrees); a quantised one changes answers at cover edges. |
| **A4** squared distances | CLOSED ON A MEASUREMENT | `distance_to` 0.031 µs = `distance_squared_to` 0.031 µs (laptop microbench): nothing to buy, and not bit-equal at the boundary. |
| **A5** allocation | DONE (5 switches) | `avoid_halves`, `avoid_neighbours`, `lazy_path`, `direct_calls`, `narrow_state` (+ the Avoidance key as ints). |
| **A6** nav queries | DONE (6 switches) | `ready_memo`, `chord_memo`, `closest_memo`, **`kturn_cap`** (3.2–3.4 % alone), `kturn_lazy`, `ground_memo`. The top function of the tick, `Pathing.closest_point`: 171 → 70 calls a sampled frame (Sumps). |
| **A7** the non-think tick | PARTLY, WRITTEN UP | the per-tick pieces that ARE equalities are in (`narrow_state`, `lazy_path`, `ready_memo`, `chord_memo`). A "held set" is not: a moving hull's inputs (its own pose) change every tick, and a parked one already skips driving; gunnery already holds its pick while reloading. No held tick can be proven equal beyond that. |
| **A8** elements, commanders | PARTLY | `ground_memo` (slot grounding), `preview_memo` (the HUD's task preview). `Elements` is 10 % of script time on his path; the rest is decisions (formation seating, Hungarian assignment) whose inputs change every decision. |
| **A9** (stretch) reuse a utility table | NOT BUILT, WRITTEN UP | a situation is never bit-identical between two thinks while anything moves (positions, ages, the tick); hashing it to prove equality costs about what `decide` does. A behaviour-changing version (similar, not equal) is a C16.1 lever. |

**The total, by removal within one run** (every switch on vs every switch off, 30-tick blocks, the same fight, hash
identical to a plain run; builder0, thread CPU):

| workload | commit | brains' controller band | the whole tick's scripts |
|---|---|---|---|
| his skirmish (`make ai-ab-play`, perf-play's flags, a display, ~2 810 ticks an arm) | `7b8e356e` | 10 314 → 9 685 µs (**6.1 %**) | 13 702 → 12 463 µs (**9.0 %**) |
| his Sumps match (`make ai-ab-match`, 50 vehicles, 180 s) | `319aaa7f` | 13 494 → 12 326 µs (**8.7 %**) | 15 185 → 14 020 µs (**7.7 %**) |
| scenario_perf (`make ai-perf AB=1`, 60 tracked brains) | `a2682209` | 15 684 → 14 313 µs (**8.7 %**) | — |

Single switches: `kturn_cap` 3.2 % (Sumps) / 3.4 % (skirmish) of the band. `ground_memo` is inside the noise on
his skirmish (−0.3 % of the whole tick, ±2 % floor): ~1.2 hits a tick, each worth 10–33 queries, so ~0.2 ms
expected, too small for this ruler. Kept as an equality, NOT claimed as a gain.

**Every green hash:** `156fdcf3` (batch 1), `8864b954` (2), `a2682209` (3), **`319aaa7f` (4/5)**: check exit 0, sim
baseline `05df1d55ba49cde1` UNMOVED, `ai-parity` digest `cf50ef2bbf8a422fe00150d382e5a956` identical to base
`8318b9db`, and identical with `--brains-off=all` (the old paths and the new agree byte for byte).

**What this does NOT do, plainly:** the brains are still ~11–14 ms of thread CPU a tick on builder0 at 50–60 units
(~2.75× that on his laptop) against a 4 ms budget. Equal-answer work found ~9–10 %. The rest needs work that changes
answers: thinking less often far from the fight (the round-17 lever below), the planned-reverse check on a longer
cadence, fewer chord samples, avoidance against fewer neighbours. Each of those is a decision change and goes on a
page for him (C16.1), priced with these instruments.

### Plan (the order taken, and why)

1. **A1 + A2 together**: the base numbers come from a detached base checkout (`../godot-brainsbase` at `8318b9db`, so
   no instrumentation in them), and the per-part split from the A2 commit on this branch.
2. **Measured first, then the backlog's order revised by the measurement**: A3 (the LOS memo) was the brief's
   headline suspect, and the counters say it is small (below). The nav cluster (A6) and the per-tick execute path
   (A7) are the big lines, so they came next. A4 (squared distances) is written up rather than done (below).
3. Every change is an **equality by construction** (the same inputs in the same physics frame or nav iteration give
   the same answer), proven by the sim baseline, `make ai-parity` (new) and scenario_perf's fight fingerprint
   (`712 ticks fighting, 26 alive; LOS 148100 queries, 96532 computed`, deterministic, identical on base and A2).

### A1: the split, today (base `8318b9db`, builder0 loaded, `sim-profile` Sumps seed 92721 Law v Condemned, 60 s = 1800 ticks)

| vehicles (budget) | tick ms, brains | tick ms, `--no-brains` | brains share | controllers segment |
|---|---|---|---|---|
| 10 (1000) | 3.83 | — | — | 3.32 |
| 23 (2200) | 8.11 | — | — | 7.17 |
| 56 (5200, ≈ his 51) | **17.09** | **1.32** | **92 %** | 15.21 |

His armies (24 v 27) take `BUDGET≈4600–5200` in `sim-profile`. `--budget=1000` (the default) gives only 10 vehicles.
`make ai-perf DETAIL=1` at base: `ai_usec_per_tick` 18 486, thread CPU 18 887 µs/tick (loaded 1.68×), parts: move 5393
(friends 2282, path 811, steer 848, fire 698), situation 4297 (contacts 1256, cover_fire 924, cover_spots 618), weapon
2824 (scan 1341), act 1838, decide 1479, motion 884. Check at base: exit 0, baseline `05df1d55ba49cde1`,
scenarios 42/1/3 (the known `scenario_cover` peeking-reload failure, red since round 15), scenario_perf NOT JUDGED (loaded).

### A2: the per-part profile (`791c3001`, builder0 loaded, 50 vehicles, BUDGET=4600, same match)

`--sim-profile` now turns on the brains' detailed laps and reports each as a `brain/<part>` section with calls per
tick (`OrderController.add_part`). `make ai-perf DETAIL=1` prints the same parts and `MEASURE ai_calls_per_tick`.
Tick 12.98 ms; controllers 11.83:

| part | ms/tick | calls/tick | |
|---|---|---|---|
| execute (every unit, every tick) | 6.67 | 50 | move 4.60, weapon 1.62 |
| think (incl. non-think bookkeeping) | 4.76 | 50 | situation 2.17 / decide 0.86 / act 0.59 on 7.7 thinks |
| nav.chord | 1.13 | 24.6 | 46 µs a chord: 2 closest-point probes + is_ready + the slack, per sample |
| nav.closest | 1.07 | 114 | 15.6 of them a point already asked this frame |
| nav.is_ready | 0.46 | 42 | the same answer every call between two nav syncs |
| move.steer / avoid / path / guard | 1.21 / 0.92 / 0.91 / 0.69 | 28.7 | |
| weapon.scan | 0.77 | 29.7 | |
| los.ray (physics rays) | **0.13** | 46 | ~10 repeat a line already asked this frame |
| los.cover (fine memo) | 0.26 + 0.31 computing | 56 | **hit rate 17 %**: 46.6 of 56 computed |

### The lead's question: "lower the thinking frequency, shard the thinking across frames?"

Both already exist, and the measurement says they are not where the time goes now. A brain thinks at 10/s in a fight
(the contact rate is a per-variant feature), 5/s near (within `LOD_RADIUS` 130 m of a known enemy, or keeping
station) and 3.3/s idle (`tank_brain.gd` `_think_rate`). Thinks are staggered by `think_offset` (`_due_to_think`),
elements decide on `(tick + id) % UPDATE_TICKS`, and a new order or an incoming round forces a think on the tick it
arrives. **At 50 vehicles the thinking is 4.8 ms a tick against 6.7 ms for executing orders** (A2 above). Execution
runs for every unit on every tick: following its route, nav probes, ORCA avoidance, aiming. Only 7.7 of the 50
brains think on an average tick, so halving the think rate would buy at most ~2.4 ms, while the execution line plus
nav is where this round's equal-answer savings are. Thinking less often is also a behaviour change (C16.1) and moves
the sim baseline. It goes to him as a priced lever, below.

### Round-17 candidate (a PRICED lever for the lead, not built): a think rate for units far from any fight and off camera

- **What:** a fourth rate below idle (say 1/s) for a unit with no known enemy within `LOD_RADIUS`, no order in
  flight, and nothing of its own in the player's view. It wakes at once on the existing triggers (a new order, an
  element call, a contact refresh that brings an enemy inside `LOD_RADIUS`). The player's own units never drop
  below idle. Execution can't be strided the same way without changing motion (the controller stride, variant
  `brain_stride`, exists and is not the default for that reason).
- **The price, already partly measured** (`sim_tick_rate.md`, round 5, variants `x6t5`/`x6t4`): thinking at 5/s
  instead of 7.5 cost −15 % of the brains, 3.75/s −29 %. A far-and-idle rate only touches units that are idle
  anyway, so expect less than either. At his 51 vehicles, early in a match (everyone idle or travelling) it is the
  biggest share.
- **How its behaviour cost is measured:** `make ai-ladder` (the variant against the champion, 4 runs × seeds, ELO and
  identical-md5 controls); `make tactics-drills` and `make ai-scenarios-check` counts unchanged; arrivals and
  reaction latency (`make nav-scenario-arms`, the K1 response test: a new order is taken up on the tick it
  arrives); `make ai-parity` will DIFFER by design, so the comparison is the ladder plus the first-contact second
  and the first-shot second in `MATCH_RESULT` over 16 seeds. Shipped OFF behind a variant, his call on a page.
- **A9 stays in scope only as an equality:** reuse the last utility table when the inputs are bit-identical, proven by
  the baseline across 8 seeds × 3 maps, or not at all.

### Decisions

- **A3 is small at his scale**: rays cost 0.13 ms a tick, and an exact memo would save ~0.03 (sim measured the same
  null for intel's rays). A quantised memo of `has_line_of_sight` would change answers at cover edges (a ray at
  exact ends vs a grid point), which is a C16.2 question rather than an optimisation, so it is not done.
- **A4 is not done as a sweep**: in GDScript `distance_squared_to` costs one call, the same as `distance_to`, so the
  interpreter's dispatch dominates and the sqrt is noise. The compares aren't strictly bit-equal either
  (`sqrt(x) <= r` vs `x <= r*r` can differ within an ulp of the boundary). Any squared-distance change rides along
  with a hot-path edit that is measured.

### Done

- **A1** (the table above) and **A2** (the sections, the counters, `make ai-parity` = `tools/ai_parity.py`: a digest over
  60 s matches, yard+terminus, seeds 1–8, Law v Condemned at BUDGET 2600; `PARITY_REF=` compares).
- **Batch 1 — GREEN at `156fdcf3`** (`7d0e3411` merged with main c9d0af56): `make remote T=check` exited 0, sim-baseline
  `05df1d55ba49cde1` UNMOVED, tests 1884/0 (5 shards), scenarios 42/1/3 (unchanged; scenario_perf's fight identical:
  712 ticks, 26 alive, LOS 148100/96532; NOT JUDGED for load 1.79×); **`make ai-parity` IDENTICAL to base
  `8318b9db`: 16/16 matches byte-for-byte, digest `cf50ef2bbf8a422fe00150d382e5a956`**. The same Sumps match before
  (`791c3001`) and after (`156fdcf3`), state hash `14ecc9d403f91114` both (the same fight), 50 vehicles: chord checks
  24.6 → 18.2 a tick, closest-point queries 114 → 99, `nav.is_ready` 0.46 → 0.05 ms, `move.guard` 0.69 → 0.51 ms.
  Builder0 was ~1.5× busier during the after-run (untouched sections such as `los.ray` read 1.4–1.6× slower at identical
  call counts), so the tick's ms (12.98 → 17.97) can't be compared. That is why batch 2 adds the in-fight A/B. The
  changes: `Pathing.is_ready` once per nav
  iteration; `_chord_on_mesh` memoised per frame for the same two points, its slack once per chord; Avoidance's
  per-tick key as two ints and hull halves cached by unit; `Movement.repaired_arrival` / `corridor_of` instead of
  a full `state()` (25 fields, a path slice) on every tick of every move order.

- **Batch 2 — GREEN at `8864b954`** (check exit 0, baseline `05df1d55ba49cde1` UNMOVED, 1884/0, scenarios 43/1/3
  unchanged against the count file; scenario_perf JUDGED PASS at 1.17×, fight identical): `Pathing.closest_point`
  memo per frame and nav iteration; **`BrainSwitches`** (`game/ai/brain_switches.gd`): one switch per change of
  the round, the old path kept beside each, `--brains-off=<names>|all`. **`make ai-perf AB=1|<switch>`** flips them in
  30-tick blocks inside ONE deterministic fight and charges each block's band CPU to its arm (C16.3's removal
  within one run; immune to builder0's load because both arms share it).
  **First A/B (builder0, 1.04×, 60 brains, 900 ticks): batches 1+2 save 2.9 % of the brains' band** (thread CPU
  10 800 vs 11 126 µs/tick, 450 ticks an arm, fight identical: 712/26/148100/96532). Real, and small: the memos
  remove repeats, and repeats were a small share.
- **The two instruments that found the real cost:**
  - `nav.closest@<site>` (call-site counts, `26722b91`, Sumps, 50 vehicles): of 99 closest-point queries a tick,
    **58 are the planned-reverse (k-turn) check's**, 34 chord checks', 6 avoidance's; the memos answer 9 more.
  - **`make ai-script-profile`** (`tools/ai_script_profile.py`): Godot's own script profiler (`-d --profiling`,
    the local debugger) summed over the frames it samples in one headless match, setup frames dropped. A
    FUNCTION-level profile of the whole tick. At `966b09ee` (24 fight frames, Sumps, 50 vehicles):
    **`Pathing.closest_point` 13.8 % of all script self-time** (the top function, 171 calls a sampled frame), then
    `TankBrain.decide` 5.5 %, `build_situation` 4.5 % self (25.7 % total), sim's `Tank._drive` 2.8 %, then a flat
    tail (FireLanes.for_shot, CoverMap._features_along, Gunnery._nearest_shootable, SuppressionFeed.beaten ~2 % each).
- **Batch 3** (`a2682209`, check running): **`kturn_cap`**. The planned-reverse check swept its forward full-lock arc
  to its end (up to ¾ of a turning circle, 10 navmesh queries a metre) to measure a hit distance that only matters
  inside `KTURN_HIT_WITHIN_M + stop`. It now stops there (a hit inside the cap is found exactly as before, the value
  beyond it was read only by a leg's diagnosis, and legs are only planned from hits inside the cap), and the outline
  test stops at its first point out. Also `avoid_neighbours` (the nearest six kept as they arrive, the same strict
  order, no lambda sort).
- Laptop microbench (headless, `4.7.2`): `global_position` 0.065 µs, `distance_to` 0.031, `distance_squared_to` 0.031,
  a 3-key Dictionary 0.45, a formatted String 0.52, `Engine.get_physics_frames` 0.03. A navmesh closest-point query
  is ~9–10 µs (1.07 ms / 114, builder0). **A4 is closed on this:** the arithmetic is not where the time is.

- **Batch 3 at `a2682209`**: check exit 0, baseline UNMOVED, 1884/0, scenarios 42 + 1 NOT JUDGED (load) = 43 (matches the
  count file); `ai-parity` identical (`cf50ef2b…`, 16/16). In-fight A/B `all` (scenario_perf, 60 brains, 1.23×):
  **8.7 % of the band saved** (14 313 vs 15 684 µs/tick). `kturn_cap` can't show there: scenario_perf fights with
  tracked tanks only, so its −2.3 % at 1.87× is the A/B's noise floor (±2–3 % under heavy load).
- **His path (skirmish, perf-play's flags, builder0 with a display, `ba4026d9`), new instruments:**
  - `make ai-script-profile-play`: brains are **55 % of all script time** (match 8.9, ui 8.2, theme 6.5, tank 5.6,
    tactics 5.2, control 4.7, camera 2.1). `Pathing.closest_point` is the top function at **12.4 %, 232 calls a
    sampled frame**.
  - `make ai-ab-play AB_SWITCH=kturn_cap` (`--brains-ab-run`, the in-run A/B on the skirmish, ~2 810 ticks an arm):
    **`kturn_cap` saves 3.4 % of the controller band** (13 939 vs 14 426 µs/tick CPU). `--brains-parts` on the same
    run: ~115 navmesh queries a tick (k-turn 53, chord 28, **formation slots 28**, avoidance 6), the frame memo
    answering ~41 more. Move 5.6 ms, situation 2.4, weapon 1.7 ms a tick at ~24 executing units (the counts mix
    both arms).
- **Batch 4/5** (`7b8e356e`, check queued): `lazy_path` (the wall-contact instrument gets the route and an index, not a
  copy every tick for every hull); `ground_memo` (`SlotGround.standable_for`, up to ~33 navmesh queries a call, keeps
  its answer for the nav map's iteration); `direct_calls` (SuppressionFeed.beaten/along and FireLanes.for_shot call
  the Match directly instead of `has_method` + `call()`); `preview_memo` (`ElementPlan.preview`, the HUD's task
  preview, a whole plan build per frame while he holds a task over one spot: the last eight answers kept, handed back
  as deep copies); the `.gd.uid` sidecars of the two new scripts. Instruments: `BrainsAB`
  (`--brains-ab-run[=switch]`, the in-run A/B for any run: it flips the switches at the top of each tick and charges
  the controller band AND the whole tick's scripts per arm), `--brains-parts`, `make ai-ab-match` (his Sumps
  workload, and it FAILS unless the A/B run's state hash equals a plain run's), `make ai-ab-play` (his skirmish).
  - `ai-ab-match AB_SWITCH=all` (builder0, a tip between `75cafc2f` and `4c14445e`): **8.6 % of the band saved**
    (10 953 vs 11 981 µs/tick), state hash `c298b9ae42722210` = the plain run's.
  - `ai-ab-play AB_SWITCH=ground_memo` (`513aa84f`): 0.6 % of the BAND, which is the wrong ruler. The element
    leaders ground their slots at priority −30..−25, outside the band, so the probes now also charge the whole tick
    (`404f2a01`); re-measuring in batch 5.

### Questions for the lead

- None.

### Requests to other streams

- **hud / sim (FYI, sent to the orchestrator):** the script profile of his path ranks their functions beside the brains:
  sim's `Tank._drive` 2.5 %, `VisibilityField._mark` 2.2 %, `Match._sorted_tanks` 1.1 % + its sort lambda 0.6 %,
  `Match.team_frame` 0.6 % (298 calls a frame, a new Dictionary each); hud's `TaskPreview._from_planner` 1.8 %,
  `MovementReadout` lambda 1.2 %, `Radar._draw` 1.1 %, `SelectionMarkers.refresh` 0.8 %, `RtsCamera._process` 0.8 %.
  `make ai-script-profile-play` reruns it on any tip.

### Known issues

- `scenario_cover::test_peeking_while_the_enemy_reloads_takes_fewer_hits` fails at base (round 15's known failure).

### Merge notes

- New: `tools/ai_parity.py` (brains), `make ai-parity` in `mk/ai.mk`. `game/tactics/slot_ground.gd` calls
  `Pathing.closest_point` (the same query, counted).
