# Stream: combat (a switch pays what it destroys; cover at any hull length; the resized roster measured, not tuned)

> Read `HANDOFF.md`, [orientation.md](../orientation.md), [game_design.md](../game_design.md) (*Round 9 direction*,
> *Ruling: the War Rig stays at 14 m*), [workstreams.md](../workstreams.md) (*Round 9: the seven streams*, then
> *Round 9 goal*), [research_catalog.md](../research_catalog.md) (Part 1 §3, Part 2, rows **A2** and **A3**, P3),
> and your round-8 brief [archive/round8/combat.md](archive/round8/combat.md) — its Status is the measurement record
> this brief builds on. You own `game/units/`, `game/combat/`, `game/match/`, `game/tank/` except `tank_motion.gd`,
> `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, `_agents/balance.md`.
>
> **⚠ Carve-out this round (contract S1):** the **scale** stream owns the `hull_size` and `muzzle_height` VALUES of
> every `Units.PROFILES` entry and the three spawn-grid constants `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING` in
> `game/match/match.gd`. **You do not edit those this round.** You review scale's `units.gd`/`match.gd` diff at merge
> (the orchestrator will send it) and own the files again afterwards.

## The lead's direction (2026-09-19)

Nothing in this brief is a new request from him; it is the catalogue he commissioned, plus two standing rulings.

- On the research review: *"distill and curate the feedback from both responses as it applies to our game and ensure
  this is rigorously documented inside our own codebase."* The curation is `research_catalog.md`; your rows are A2 and
  A3's consumer.
- On the War Rig: *"Yes the war rig stays at 14m, we can revisit that later if it's still an issue."* Closed. The
  cover fix is in the query (A3), not the vehicle.
- On balance, twice: *"we'll worry about evening up factions later"* (round 8) — and this round it extends to the
  whole roster ([game_design.md](../game_design.md) *Round 9 direction*: *"Balance is not a constraint on sizing"*).
  **Measure the consequences of the resized roster; do not tune sizes, costs or stats to fix them.**
- On what he judges by, from round 8: *"they still generally don't do what I command them"* and *"they seem to just
  move back and forth indefinitely"*. A2 is the principled answer to the second, and its acceptance is that it does
  not buy churn at the price of the first.

## Where things stand (surveyed 2026-09-19 on `main` at `f49aa08a`)

**`main` is NOT covered by a green check.** Round 8 merged your widened sim-baseline match unverified on the lead's
explicit call (builder0 was down). The orchestrator is running the first full `make remote T=check` on `f49aa08a`
now; read its result from the wrapper's `>> remote: make check exited <N>` line before believing anything about
`main`'s state. Baseline `glibc-2.43 04414f5d6a6dfa7c`, read twice on builder0.

**The commitment bonus, as it is today — two terms in two files, and one of them is never consulted:**

- `game/ai/tank_brain.gd:41` — `COMMIT_BONUS := 1.15`, applied at `:1174–1180`: the current option+target's score is
  multiplied, then `:1185–1187` holds the committed choice through `MIN_COMMIT_TICKS` unless something beats it by
  `EMERGENCY_MARGIN` (1.6). Also baked into `CLEAR_LANE`'s score at `:1044` (`× COMMIT_BONUS × 1.15`) and reasoned
  about in the comment at `:1118`. **The comment at `:34–40` is the whole 1.35 story**, kept verbatim from round 8:
  1.35 halved the churn (`make squad-decisions`, laptop, yard, seeds 1/3/7: switches/reversals per unit-min
  **18.1/0.30 at 1.15, 12.7/0.17 at 1.35, 12.1/0.27 at 1.60**), a 48-match ladder said "does not lose", and two
  behaviour scenarios said it does — **a squad stops concentrating fire (focus share 69% vs brains-alone 69%) and a
  scout stops working onto engine decks (41 hits / 23 on the deck → 3 / 0)**. 1.35 lives on only as variant `x5c`
  (`game/ai/brain_variants.gd:75`). **This file is squad's.** The seam you replace is the six lines at `:1174–1180`
  plus the `CLEAR_LANE` multiplier; anything else in `tank_brain.gd` is a proposal in your Status, not an edit.
- `game/ai/combat_motion.gd:58` — a second `COMMIT_BONUS := 0.35` (additive, on the direction ring at `:283–284`).
  **Round 8's cancellation finding** (nav, [archive/round8/nav.md](archive/round8/nav.md) *:315, :454, :592*): a
  standoff HOLD returns `{"index": -1}` at `combat_motion.gd:170–171`, so `previous_index == -1` and the hold **never
  consults commitment** — a term shipped, measured twice, and never in the code path. **This file is nav's, and A7
  (priority projection) replaces the additive ring it lives in.** Do not touch it; A2 is about *option* switching in
  the brain, not direction switching in the ring. Say so in your A7 review when nav sends its priority table
  (Invariant 0c).
- The dwell mechanisms A2 also retires: `REVISIT_S`/`REVISIT_FACTOR` (`tank_brain.gd:52–53`, an A→B→A penalty) and
  `MIN_COMMIT_TICKS`/`EMERGENCY_MARGIN` (`:48, :54`). **P3 is the warning:** round 8's hard veto on fast target
  switches *more than doubled* switch-and-switch-back, because a timer delays a switch without pricing it and the
  pressure discharges intact when it clears. A2 is a *cost*, not a *timer*. Whether the revisit penalty survives as a
  degenerate case of the cost or goes is yours to decide and record.

**The two acceptance scenarios, ready-made (squad's files, you run them, you do not edit them):**
- `tests/ai_scenarios/scenario_squad.gd:35` `test_a_squad_focuses_its_fire` — variant `a6` must beat `a4` by
  ≥ 15 points of most-damaged-target share.
- `tests/ai_scenarios/scenario_cp2.gd:126` `test_a_scout_works_onto_a_tanks_engine_deck` — the share of a scout's
  hits landing on the deck (`x4mw` vs `x3m`); `_deck_run` at `:105`.
Run them with `make ai-scenarios` (squad's `mk/ai.mk`); **baseline the suite on a pristine tree first** (lesson 38 —
it is not in `check`, so it drifts) and report pass counts before/after, not just your two.

**Cover today is a point sample with a 1.6 m margin.** `TacticalQuery.hull_hidden` (`game/ai/tactical_query.gd:174`)
tests the centre and `HULL_MARGIN` (1.6 m, `:38`) to either side, *across* the sightline — width, never length. Every
cover figure in the game passes through `_cover` (`:186`) → `hull_hidden` → `CoverMap.clear_line`. That is why arena
measured a **step**: yard cover 0.99 up to 12.19 m (the longest prop, `container_40`) and **0.00** at 12.5 m
([archive/round8/combat.md](archive/round8/combat.md) *:214, :245*). Consumers to migrate (grep `hull_hidden`,
`_cover(`, `find_cover`, `find_cover_fire`, `CoverMap.of`, `near_cover`):
`tactical_query.gd:59, :87, :101, :129, :193` · `tank_brain.gd:1385, :1465, :1506, :1540, :1572, :1586, :1842, :2280`
(squad's file — via the `TacticalQuery` API, not by editing the brain) · `game/tactics/element_plan.gd:571`
(`CoveredRoute.choose`, squad's) · `game/tactics/element_situation.gd:104, :212` (squad's) ·
`game/match/engagement_stats.gd:66, :90, :194, :201` (**yours**: `near_cover` is the instrument, and it has the same
point-sample bias as the behaviour it measures) · `game/ai/gunnery.gd:361` (nav's). **The seam is arena's
`Arena.cover_features()` (`game/arena/arena.gd:396`, scale's this round) → `CoverMap` (`game/ai/cover_map.gd:90`).**
scale builds the summed-area tables behind it; you consume them.

**The rig's cost, still unexplained** ([archive/round8/combat.md](archive/round8/combat.md) *:311*): `gangs vs law`
**9/20 → 0/20 across both maps**, p ≈ 2×10⁻⁶, `make compare-arms` on builder0 with the positive control engaged.
Suppression on the loser is the highest figure in the table (0.077 yard, 0.078 pit). Shuffling is evidenced against
(the rig converts 0.95 of path to net displacement, best of any gang type); splash is evidenced against (indirect
kills 8.4% → 3.7%); *"bigger target"* survives by elimination only. **The raw data is `references/round8/combat/`**
(`faction-matrix*.json`, `engagement*.json`, `recorded.json`, `sim-profile.json`) — cite from those with commit and
machine, not from prose.

**The balance picture on his maps** (*:347*, builder0, n=30 per faction per map, SEEDS=5): the maps disagree more
than the factions do — gangs 63% yard / 30% pit is the only significant difference in the table; every within-map
gap is inside the noise (n≈48 to resolve 20 points). **A faction win rate without a map is not a number.** These are
the pre-CP2 baselines the resized roster gets measured against.

**Instruments you own and their known edges:** `make engagement` (fixed round 6, `VARIANT_FILE`), `matchup-search`
(`SEARCH_UNITS`; every pre-fix conclusion assuming a non-default unit count is suspect), `faction-matrix` /
`faction-matrix-arms` / `compare-arms` (the counterbalanced pair with the positive control — the tool to use for
every before/after this round), `sim-baseline` (widened at `db837581`: every locomotion × mount both sides, 40 s, one
map; the old one saw 5 of 6 mutations as inert). Aggregates that mix mechanisms (lesson 49: `contact_second`,
`engaged_distance_median` sum direct and indirect fire) — split before you compare.

**What the orchestrator owns that touches you:** the sim baseline is recorded once per merging session, on
builder0, by the orchestrator (Invariant 2). A2 moves it (option choice is the simulation); say so in your green
report and do not record it. CP2 moves it; do not measure anything size-dependent across CP2 (below).

## Backlog (in order)

Each item: a failing test or a pre-registered prediction first, then the build, then `make remote T=check`, then a
player's-eye smoke (`make skirmish` gangs vs law, watch a gun truck and a rig fight), commit, Status.

### X1 — Prove the arm engages before building it (day one; lessons 117, 147)

A2 is worthless if it is measured against itself. Before writing the cost:
- Add an engagement counter to the brain's decision (a `Match.stats` entry or the existing `make squad-decisions`
  output): per think, whether the commitment term was **consulted** (a current choice existed and was a candidate)
  and whether it was **non-zero**. Report it per hull class (tracked / wheeled / hover; light / heavy).
- Run it on `main` as-is: the flat 1.15 is consulted on every think with a current fight option, and never varies by
  class. That row is your "before". If the counter reads 0 anywhere it should not (cf. the standoff HOLD), that is a
  finding for nav, relayed through the orchestrator, not a thing you fix.
- Acceptance: the counter exists, is in the output of the tool you will measure A2 with, and reads the same in both
  arms of a null A/B (same build twice). Write it as a test.

### X2 — A2: the switching cost from the vehicle's own physics (the round's main item)

**Replaces:** the flat `COMMIT_BONUS` multiplier at `tank_brain.gd:1174–1180` and the `CLEAR_LANE` bake at `:1044`;
**and** the dwell mechanisms `MIN_COMMIT_TICKS`/`EMERGENCY_MARGIN` — a timer that blocks a switch is exactly the veto P3
measured. State in Status which of `REVISIT_S`/`REVISIT_FACTOR` survives and why (Invariant 0c: "replaces nothing" is
the answer the orchestrator interrogates).

**The rule (catalogue A2, Branicky 1998 / Liberzon 2003):** permit `i → j` only when `utility(j) − utility(i)` exceeds
the physical work the switch discards — the kinetic energy shed to change heading toward the new target
(`½ m v²`-shaped, from `max_forward_speed`, `braking_mps2` and the current speed in the situation) plus the slew cost
(turret: angle to the new target / `turret_turn_rate_deg`; fixed mount: hull angle / `hull_turn_rate_deg`, and on
wheels the turning circle `min_turn_radius_m`). All from `Units.PROFILES` (C1, yours) and the situation dictionary
the scorer already has. **Deterministic by construction:** four multiplies and two adds, stateless, no wall clock, no
float reduction across units. A light scout switching 10° pays nearly nothing; a 14 m rig shedding 12 m/s and slewing
140° pays a lot. **No per-class tuning knobs** — that is the point; the roster's 5× range prices itself.

Where it lives: the cost is **your** function (`game/combat/switching_cost.gd` or in `engagement.gd`: `static func
switch_cost(situation, from_candidate, to_candidate) -> float`, unit-tested on hand-computed cases and
mutation-checked); the brain calls it at the seam. If the seam needs more than replacing those lines — e.g. the
situation lacks current speed or turret bearing — **propose the `tank_brain.gd` diff in Status the way round 6's CP4
did (a commit on your branch, explicitly for squad to take, replace or revert)** and message the orchestrator.

**Acceptance, in this order, and all three must hold:**
1. `test_a_squad_focuses_its_fire` and `test_a_scout_works_onto_a_tanks_engine_deck` pass, with their MEASURE lines
   quoted before/after (the 1.35 knee failed both; that is the bar).
2. The arm counter (X1) shows the cost consulted and **varying by hull class** — assert the rig's median cost is a
   multiple of the scout's in the same situation.
3. Churn: genuine option-switch churn **−60%** and switch-and-switch-back within 4 s below **0.2/agent-min**, reaction
   latency to a new contact **≤ 2 ticks**. **Provisional from `make squad-decisions` until CP1**; the verdict is read
   from the metrics stream's A12 tool once it merges, and not published before. If churn falls and latency rises, it
   is stubbornness wearing a hat and it reverts.
Plus the safety net, never the evidence (lesson 150): a counterbalanced ladder (`faction-matrix-arms` on yard and pit,
SEEDS≥5) must not lose. Pre-register the numbers you expect before the run.

### X3 — After CP2: the resized roster, measured and not tuned

When the orchestrator announces CP2 (the scale stream's roster at real relative scale; every hull except the rig
grows, most by 1.5–2×): `git merge main`, then re-take, on builder0, with commit and machine:
- the sim-baseline match (it moves; the orchestrator records it),
- `make faction-matrix` on yard and pit (the *:347* table is the "before"; same SEEDS, same budget),
- the `gangs vs law` pair (`compare-arms`, positive control engaged), per matchup not per faction,
- `make engagement` for the kill-distance / engaged-distance / cover-use columns, split direct/indirect.
Report deltas with sample sizes and CIs. **Tune nothing.** If a matchup collapses the way `gangs vs law` did, write
the mechanism hypotheses with the evidence for each, and hand any trajectory-level question to the metrics tool.
**Nobody publishes a size-dependent number measured across CP2**: anything you took before it is a "before", never a
"same".

Also at CP2: review scale's `units.gd`/`match.gd` diff (the orchestrator sends it). What you check: `hull_size` is
the mesh's proportions at the chosen length (S1's test proves it), `muzzle_height` stays below every hull's top by
`MUZZLE_CLEARANCE` (`units.gd:59`, trip-up 15), the spawn grid still seats 30 a side without overlap, and nothing
else in your files changed. Approve or object in Status and to the orchestrator the same day.

### X4 — A3's consumer: cover as a fraction of hull length, everywhere the point sample was

When scale hands over the seam (summed-area tables behind `Arena.cover_features()` / a `CoverMap` query returning the
**fraction** of a hull chord occluded from a viewer — the API is scale's to define with you; ask for
`cover_fraction(viewer, point, heading, length) -> float`):
- Migrate **every** consumer listed above (lesson 39: when you change a quantity's definition, grep every consumer of
  the old one, or a rule and a heuristic deadlock). `hull_hidden` becomes a threshold on the fraction; `_cover`'s
  weighting stays. `engagement_stats.near_cover` — your instrument — migrates too, or it will keep reporting the old
  world.
- Re-check the positioning heuristics that stood on the point sample: `find_cover_fire`'s hide/peek pair
  (`tactical_query.gd:73–101`), the retreat-to-cover distance (`tank_brain.gd:1842`, squad's — a proposal if it
  needs to move), and support-by-fire's standoff (`element_plan.gd:334`, squad's).
- **Positive control (catalogue A3):** the 12.19 m step must be gone — yard cover for a 14 m hull rises from **0.00**
  to within 0.1 of its 12 m value, and the exposed fraction of hulls reporting at-cover is < 5% at every length
  2.8–14 m. If the cliff survives, the treatment did not engage. `make arena-report`'s WATCH line is scale's to revise
  in the same commit as the tables; confirm it changed.

### X5 (stretch) — What cost the rig 9/20 → 0/20, with the hull-fraction query as a new arm

With A3 landed, the rival explanations separate: if `gangs vs law` recovers with the fraction query, the loss was
cover the point sample could not see; if it does not, re-open suppression-on-a-big-target with `engagement`'s
suppression columns and the metrics tool's trajectory view of the rig under fire. Design the pair as a
counterbalanced A/B with the positive control, pre-register the prediction, and report the table either way — a
negative result here is worth relaying (lesson 41).

## How to verify

- `make remote T=check` on a merge candidate only; iterate with `make test FILTER=combat|engagement|switch` and
  `make ai-scenarios` locally. **Read the wrapper's `>> remote: make check exited <N>` and the runner's
  `N passed, M failed`** — never a shell exit through a pipe, never a filtered run as a readiness claim (lesson 45).
- `make squad-decisions` (squad's; the churn instrument until CP1), then the metrics stream's A12 target after CP1.
- `make faction-matrix-arms` / `compare-arms` for every before/after; `make engagement` for the range/cover columns.
- Smoke like a player: `make skirmish` gangs vs law on yard; watch whether a gun truck under a squad focus order
  switches onto the focus (X2's first scenario, seen), and whether a rig commits to a fight instead of hunting.
- Every number: commit, machine, workload, sample size. builder0 is ~2.75× the laptop.
- One `make remote` per worktree at a time; budget 30–50 min per check while seven streams are live — ask the
  orchestrator for a window before a big series.

## Don't touch

- `hull_size`, `muzzle_height` values and `SLOT_X`/`SPAWN_ROWS`/`SPAWN_ROW_SPACING` — **scale's** this round (S1).
- `game/ai/{movement,combat_motion,steering,pathing,gunnery}.gd`, `game/tank/tank_motion.gd` — nav's (A7/A11/A1/A4
  rewrite that layer; your `combat_motion.gd` observation goes to nav through the orchestrator).
- `game/ai/tank_brain.gd` and `game/tactics/**` beyond the named `COMMIT_BONUS` seam — squad's; proposals go in
  Status as a commit for squad to take, replace or revert.
- `arenas/`, `game/arena/` — scale's this round (A3's tables live there; you consume the API).
- `tools/metrics/` — metrics'. Ask for a log field rather than inventing a second format (S3).
- The sim baseline file — the orchestrator records it.
- Shared files (`project.godot`, `Makefile`, `mk/core.mk`, `game/main.gd`): minimal additive edits, listed in merge
  notes.

## Waiting on the lead

Nothing at start. Balance is explicitly deferred by him; do not queue a balance question. If X3 or X5 finds a matchup
made unwinnable by scale alone, write it up with the evidence and let the orchestrator put it on his decisions page —
it is his call whether that is a size question or a stats question, and this round's ruling is that it is neither.

## Status

**Not started** (brief written 2026-09-19 by the orchestrator; `main` at `f49aa08a`, first full check in flight).
