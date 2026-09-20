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

_Last updated 2026-09-20 (worker, `stream/combat` at `9f864474`)._

### The plan (worker contract step 2)

Ordered smallest-foundation-first. Where the brief left a choice, the one-line reason is on the item.

1. **X1a — the cost function before the counter.** `game/combat/switching_cost.gd`: a pure static
   `seconds(situation, from, to)` and `penalty(...)`, unit-tested on hand-computed cases. Written first because
   the X1 counter has to report *this* quantity, not a placeholder.
2. **X1b — the arm counter.** `decide()` returns a `"switch"` telemetry dict; a probe of mine aggregates it per
   hull class over a real fight (`make switch-arm`). Null A/B (same build twice) asserted as a test.
3. **X2 — replace the seam.** The flat `COMMIT_BONUS` multiplier (`tank_brain.gd:1174-1180`), the `CLEAR_LANE`
   bake (`:1044`) and the dwell timer (`MIN_COMMIT_TICKS`/`EMERGENCY_MARGIN`) go; the cost lands in their place.
   Then the two acceptance scenarios, churn from `make squad-decisions`, and the counterbalanced ladder.
4. **X2b — REVISIT_S/REVISIT_FACTOR, measured as its own arm.** Decision recorded below; it is removed in a
   *separate* commit with its own before/after so the round knows which term did what.
5. **X3 — the resized roster** (blocked on CP2), **X4 — A3's consumer** (blocked on scale's seam), **X5** stretch.

### Decisions taken (with reasons)

- **The cost is a price in utility, never a veto.** Linear in the discarded work with a hard cap, so a big enough
  utility advantage always wins. P3 measured what a veto does; the cap is the structural guarantee it cannot recur.
- **`CLEAR_LANE` is exempt from the cost.** It does not change *what* this crew is fighting — it clears the lane to
  the fight it is already in. That is why it carried a doubled commitment bake; the exemption replaces the bake
  with a single documented edge constant instead of a bonus-on-a-bonus.
- **The `commit_bonus` brain-variant key keeps working and selects the OLD path.** So `x5c` (1.35) still runs, and
  the round gets both arms in one build for a counterbalanced A/B without editing squad's `brain_variants.gd`.
- **REVISIT_S/REVISIT_FACTOR: retire it** — a 3 s window that discounts returning to what you just left is a second
  treatment for the pathology A2 prices physically (you pay the work going to B and the work coming back), and the
  catalogue's own rule is one treatment per pathology per round (Part 2, composition hazard). Removed in its own
  commit, with the measurement, so the claim is falsifiable rather than asserted.

### Baselines, taken before anything changed (cite these, not prose)

**`make ai-scenarios` on the PRISTINE tree at `9f864474`, laptop (lesson 38 — it is not in `check`, so it drifts):**
**44 passed, 1 failed, 2 pending.**

- The one failure is `scenario_perf::test_the_brains_stay_inside_the_cpu_budget` (**22162 µsec per tick**) and it is
  **pre-existing on this machine** — laptop speed, not behaviour (the laptop is ~2.75× slower than builder0). It does
  mean A2 has to prove it costs no measurable CPU, and that proof comes from `make ai-perf` **on builder0**, not here.
- The two pending are `scenario_cp2::test_a_scout_guns_down_a_lancer` and
  `scenario_evasion::test_a_light_unit_dodges_most_tank_shells`. Both pending before this stream touched anything.

**The two acceptance scenarios, before (same run):**

| scenario | MEASURE line | bar | margin |
|---|---|---|---|
| `test_a_squad_focuses_its_fire` | `without squad tactics 69% [403.0, 0.0, 894.0], with 100% [1374.0, 0.0, 0.0]` | squad ≥ 60% and > alone + 15 pts | **31 points** |
| `test_a_scout_works_onto_a_tanks_engine_deck` | `x4mw { "deck": 23, "hits": 41, "shots": 45 }; x3m { "deck": 0, "hits": 0, "shots": 0 }` | deck share ≥ 0.50 | **0.56, six hits** |

⚠ **The engine-deck scenario has six hits of margin, and its control (`x3m`) fires zero rounds** — a control that
never fires proves nothing, so only the treatment arm carries information. Relayed to nav and the orchestrator.

### A7 review (nav's `7edec4fb`), sent 2026-09-20 — one blocking objection, one correction

- **Blocking:** A7 makes `standoff_holds()` "a candidate like any other", but level 5's `standoff` weights then vote
  against the hold every tick (a hold scores 0 on `tangent`, a circling candidate the full 0.5, and both clear level 2
  equally). That puts round 7's largest measured win up for re-election. Acceptance bar handed to nav:
  `scenario_motion::test_a_scout_holds_a_firing_position_instead_of_ramming`, today **closest 26.9 m, in-band 0.92,
  nose-on 0.91, 226 shots** against the `run` control's 6.0 m / 13 shots. A `standoff` hull is a *fixed gun*, so
  nose-on **is** its aim.
- **Correction:** the scout is **not** a turreted hull — `Units.PROFILES["scout"]["mount"] == "fixed"` (all three
  scouts), and `TankBrain.motion_style():2238` sends every fixed mount to `standoff`, where nav keeps armour at level
  3. The armour demotion **cannot reach the engine-deck scenario**; it applies only to `strafe`, whose armour weight is
  already **0.15**, the smallest term in that vector. Its real falsifier is the turreted duel
  `test_two_tanks_duel_on_the_move_front_armor_first` (today **front hits 100% (a6) / 80% (x3)**).
- **N5 confirmed rather than assumed:** level 2's band is `[weapon.preferred_min, weapon.preferred_max]` read straight
  from `Weapons.PROFILES` (`tank_brain.gd:2315`), so level 2 *is* the engagement envelope. No objection, on two
  conditions given to nav (keep reading the weapon profile; check the tolerance against `TankBrain.fire_band`).
- **L2 suppression: no objection.** And `beaten` is **already** a hard filter today (`combat_motion.gd:313-316`), so
  promoting it to level 1 is a rename, not a win. `PENALTY_HIT` 3.0 against a maximum achievable `strafe` sum of ~3.25
  is a real change but a tail effect.
- Cross-stream finding relayed to the orchestrator (squad's, not mine): level 1 filters before level 4, so a unit
  ordered to hold a firing line could be pulled off it by fire without the leash being consulted. **Ruled**: under a
  hold or station the leash becomes a level-0 feasibility bound, so a held unit dodges *within* its leash.

### Contract S5 (orchestrator ruling, 2026-09-20), and how this stream complies

A2 is **one expression**, owned here (`game/combat/switching_cost.gd`), consumed at exactly two seams: (a) the brain's
option scorer — mine, done; (b) nav's level-5 commitment term in `combat_motion.gd`, the day nav's A7 commit exists.
nav takes `seconds_for()` (the seconds are portable; the utility price is calibrated to the brain's 0..1.2 score range
and is not) and **drops the stance floor**, because nav's candidates are directions and every direction change already
carries its own Δθ — the floor would charge every candidate the full velocity and flatten the ring.

### Done so far (commits on `stream/combat`)

| commit | what | green |
|---|---|---|
| `ea792b2e` | **X1a — the switching cost as one expression** (`game/combat/switching_cost.gd`), its unit tests, the `switch.*` tune namespace in `units.gd`, and `--tune` on `tools/faction_matrix.py`. Inert: nothing called it. | `make test FILTER=switching_cost` **12 passed, 0 failed** (laptop) |
| `b69d081b` | **X2 seam + X1b — the brain's commitment term is the switching cost** (`tank_brain.gd`, squad's file, combat's seam — **on its own commit for squad to take, replace or revert**, per S5 and round 6's CP4 precedent), plus the arm counter and `make switch-arm`. | `make test FILTER=switch` **20 passed, 0 failed** (laptop, `b69d081b`) |

**What the seam replaced, all of it rather than added beside it** (catalogue Part 2): the flat `COMMIT_BONUS` 1.15
multiplier, the `MIN_COMMIT_TICKS`/`EMERGENCY_MARGIN` dwell timer, and `CLEAR_LANE`'s `COMMIT_BONUS × 1.15` bake
(now `CLEAR_LANE_EDGE = 1.15` — it was two 1.15s, one of which existed only to cancel the bonus on the fight it
competed with, and that one had nothing left to cancel).

**Both arms are in one build** (lesson 117): `--tune=switch.legacy=1` is `main`'s pre-A2 behaviour including its dwell
timer, `--tune=switch.price=0` is the cost computed and never charged, and variant `x5c` still selects 1.35. Which arm
ran is never inferred from a checkout.

### Three findings so far, none of them predicted by the brief

**1. The catalogue's A2 is incomplete: braking + slew is not all a weapon switch destroys.**
Priced as specified, a stationary turret swapping between two targets on the **same bearing** pays **exactly zero** —
and squad's `test_brain_decide::test_commitment_prevents_flip_flopping` is exactly that case (two enemies dead ahead
at 30 m and 36 m, crew halted). The third thing a switch throws away is **the gun's lay**: N5's own gate 2, where a
crew must hold a contact for `Engagement.acquire_seconds` before its first round leaves the barrel. Added from
`Engagement`'s own constants, in combat's file, charged **only when the target changes** (ORBIT or SUPPRESS on the
target you are already laid on keeps the lay) and deliberately **backward-looking** — the lay invested in the target
being abandoned, never the time to acquire the next one. A crew laid on nothing pays nothing, so taking up a newly
seen contact is never slowed; a forward-looking term would have spent this round's *reaction latency ≤ 2 ticks*
criterion on something nobody would have thought to check. Recorded by the orchestrator on the catalogue's A2 row.

**2. A score floor is a saturation, and it fell through to array order (lesson 153, found by nav on its leash).**
The price was written `maxf(score − penalty, 0.0)`. That floor ties any two candidates priced below water, after which
the argmax falls through to **whichever appears first in the candidate array** — an arbitrary silent decision. Not
theoretical: `HOLD`'s baseline is 0.1 against a 0.35 cap. **Removed**; the price is a plain subtraction and scores may
go negative (nothing downstream reads a raw score except `_top`, which only sorts).
**The cap itself is safe here and the reasoning is worth keeping:** `MAX_PENALTY` saturates the *penalty*, not the
ranked quantity, so two candidates beyond it lose the same 0.35 and keep their own order — an equal offset preserves
ranking. nav's leash was the opposite: it clamped the thing that *was* the level.
`test_two_candidates_beyond_the_cap_still_rank_by_utility` fails if anyone reintroduces a floor.

**3. `free()` does not exist as a static name.** `Object.free()` is inherited and a static of that name does not parse
— it takes down every file that references the class, which reads exactly like a broken tree. It is `never_charged()`.

### Decision on REVISIT_S / REVISIT_FACTOR (the brief asks, Invariant 0c)

**Retire it — in its own commit, with its own before/after, once the churn A/B has a baseline.** It is a 3 s window
that discounts returning to what a crew just left; A2 prices that return physically and twice over (the work going to
B, and the work coming back), so keeping both is two treatments for one pathology, which is the catalogue's Part 2
hazard and its own stated rule. It is not removed in the same commit as the seam, because then nobody could say which
term did what.

### X1 result — the arm counter on a real fight (and the hole it found in my own pre-registration)

Laptop, `c68b423e`, `make switch-arm ARENA=yard SEED=3`, gangs vs law, 120 s, both armies watched.

| class | thinks | consulted | priced/think | **flipped/think** | switches/unit-min | rev 4 s/unit-min | offered_s median | p90 |
|---|---|---|---|---|---|---|---|---|
| artillery | 15153 | 0.98 | 12.33 | 0.223 | 8.8 | 0.64 | 2.433 | 3.379 |
| ifv | 13061 | 0.99 | 12.30 | 0.102 | 21.6 | 0.77 | 1.568 | 2.440 |
| scout | 14463 | 0.97 | 14.11 | 0.081 | 12.2 | 2.75 | 1.589 | 3.114 |
| support | 5028 | 0.99 | 11.78 | 0.061 | 7.9 | 1.22 | 1.250 | 2.784 |
| suppressor | 3779 | 0.99 | 11.02 | 0.157 | 17.4 | 1.11 | 1.902 | 2.887 |
| tank | 3772 | 0.98 | 12.63 | 0.132 | 28.5 | 1.93 | 2.662 | 3.773 |

**Against the pre-registration:** `consulted` **0.92–0.99** everywhere against a bar of ≥ 0.80 ✓.
`flipped_per_think` **0.061–0.231**, inside the pre-registered 0.01–0.25 band ✓ — the term changes decisions without
deciding the fight. `paid_s_median` is **0.0** in every class, which is the healthy reading: the median think keeps
its choice and pays nothing. Spread `law_tank` 2.662 s against `gang_support` 1.250 s, **×2.13** ✓.

⚠ **But the claim I pre-registered — the War Rig against the rat rod — was NOT TESTABLE FROM THIS RUN, and nothing in
the output said so.** The seeded `cpu` draft drew `gang_hail` for the gangs, which fields **no `gang_tank` at all**.
The probe's own doc comment claimed "the roster's extremes are both on the field"; the numbers it printed were real,
the claim they were produced to test was unanswerable, and the run exited clean. This is metrics' control lesson in a
different costume — *a run can exit 0, print exactly the expected numbers, and have done none of the thing you asked*.
**Fixed by naming archetypes instead of trusting a draft:** `SWITCH_GREEN_ARMY=gang_ram` (two rigs and a rat rod) vs
`SWITCH_RUST_ARMY=law_line`. The rig-against-rat-rod figure is re-taken on that and is not claimed until it is.
The ×2.13 above stands on its own terms — it is the dearest against the cheapest hull *that was actually present*.

Also fixed in the same pass: every rate is now split **by locomotion** as well as by class (metrics: the creep is a
property of wheels, not of a role — `ifv` and `lancer` are both wheels and `tank` is tracks, so a role split was
reading two mechanisms as one column), and the legacy arm no longer emits `inf` into its own JSON.

### The control arm works exactly as pre-registered — which is the part of X1 that matters most

`--tune=switch.price=0` against the treatment, same fight. The control runs the **same code path** (`arm: cost`,
consulted 0.96–0.99), computes and reports the cost it would have charged (`offered_s_median` 1.244–2.569 against the
treatment's 1.250–2.662), and **flips exactly 0.000 decisions per think in every class**. That is the pre-registered
prediction met to the digit, and it is what makes every later A/B readable: the control is the treatment's own build
with one number set to zero, not a different checkout.

### ✅ X2 acceptance 1: BOTH behaviour scenarios pass, unchanged — the 1.35 trade is not repeating

`make ai-scenarios` on `c68b423e` (laptop), against the pristine baseline at `9f864474`:

| scenario | pristine `9f864474` | A2 `c68b423e` | bar |
|---|---|---|---|
| `test_a_squad_focuses_its_fire` | alone 69%, squad **100%** `[1374, 0, 0]` | alone 69%, squad **100%** `[1399, 0, 0]` | ≥ 60% and > alone + 15 pts ✓ |
| `test_a_scout_works_onto_a_tanks_engine_deck` | `deck 23, hits 41, shots 45` (0.56) | `deck 23, hits 41, shots 45` (**bit-identical**) | share ≥ 0.50 ✓ |

**This is the bar that killed round 8's 1.35 knee, and A2 does not move it at all.** The mechanism is not luck: a
squad's focus target is usually already the nearest threat, so the bearing change — and therefore the cost — is
small; and a scout orbiting one target never *changes target*, so ORBIT → ORBIT is free by construction. The thing
the flat bonus bought its churn reduction with, A2 does not spend.

⚠ Both were run **before** CP2 and before nav's A7. They are re-run on nav's A7 commit (promised to nav and the
orchestrator, with the hash) and again after CP2 — scale's `_apply_hull_size` fix grows the Condemned `tank`'s
collider by 0.8 m in height, and that hull is the *target* in the engine-deck scenario, so its hit distribution moves
for reasons that have nothing to do with A2.

### ⚠ REGRESSION FOUND, AND IT IS IN A TERM THAT IS NOT CATALOGUE A2 — IT IS MINE

`make ai-scenarios` on `c68b423e` is **42 passed / 3 failed / 2 pending** against the baseline's **44 / 1 / 2**. I
checked my two named scenarios and reported the acceptance before checking the suite total; that was the wrong order
and this section is the correction.

**Failure 1, `scenario_dodge_rate::test_who_dodges_and_how_often_they_try` — documented noise, with evidence.** The
scenario's own header says the attempt count *"reshuffles with any change at all"* and it is deliberately not in
`make check`. Dodge **effectiveness** is identical between the runs — `ifv x5p`: **48 fired, 41 hit, 15% dodged** in
both — and five of its six rows were already `0 of ~500` in the baseline. Only the label count moved, 9 of 451 → 0 of
444. Not a regression; do not tune anything to it (the header says so in more detail).

**Failure 2, `scenario_motion::test_two_tanks_duel_on_the_move_front_armor_first` — a real regression.**

| | pristine `9f864474` | A2 `c68b423e` |
|---|---|---|
| shots (`x3`) | [4, 3] = 7 | **[3, 2] = 5** (bar ≥ 6) |
| duel length | 20.0 s | **15.2 s** |
| **flank seconds** | **[6.27, 5.27]** | **[2.07, 3.53]** |
| front hits | 80% | 75% (bar ≥ 50%) |
| moving share | [0.685, 0.665] | [0.725, 0.679] |

The firing **rate** barely moved (0.35/s → 0.33/s); the duel ended sooner because one tank died. What changed is that
the tanks spend **60% less time** working round to each other's side or rear — they trade frontally instead.

**The suspect is the stance floor, which is this stream's addition and not catalogue A2.** It charges the whole
current velocity whenever the *option* changes on one target, and I added it to price `ENGAGE ↔ SUPPRESS` thrash.
`ENGAGE → FLANK` on the same target is a way of *prosecuting* the fight, not a change of mind — and because both
options aim at the same contact, the bearing term is zero and the floor charges a full stop for a manoeuvre that
never stops. **This is round 8's 1.35 knee in a new costume:** a churn term buying its improvement with positioning
behaviour, against a behaviour the lead named in round 3 (*"no intent of trying to circle your opponent"*), where
every churn table says nothing at all.

**Orchestrator's ruling (2026-09-20):** the floor is not in the catalogue and it taxes prosecution of the fight, so it
**earns its place by removal** (lesson 25), and the flank-seconds number outranks any churn ladder (lesson 150).

**One correction to that ruling's premise, recorded so a later reader is not misled.** It assumed the lay term already
prices `ENGAGE ↔ SUPPRESS`. **It does not** — the lay is charged only when the *target* changes, and a suppressing
crew still has its gun on the same contact, so it has not abandoned its acquisition. If the floor goes wholesale,
`ENGAGE ↔ SUPPRESS` on one target is priced at **exactly zero**, and that is one of the two thrash shapes round 7
measured.

**And the code says something sharper than "the floor is a tax".** `_act` (`tank_brain.gd:1833`, `:1845`): ENGAGE and
SUPPRESS share their band logic exactly, but inside the band **SUPPRESS halts** (*"Standing still is what makes fire
effective"*) while **ENGAGE manoeuvres** (`_combat_move`). So the floor is *right* for `ENGAGE → SUPPRESS`, which
genuinely discards the velocity, and *wrong* for `ENGAGE → FLANK`, which does not. **If the `cost-nostance` arm shows
the floor buying something, the refinement is to charge the velocity discard only for options that fight from a
standstill** (`SUPPRESS`, `COVER_FIRE`'s hide/peek, `BOMBARD`) — a physical property of the option, stated in one
place, not a per-class knob. Not built yet: lesson 25 says removal first.

**Instrumented rather than argued.** `--tune=switch.stance=0` gates the floor; `make switch-arms` carries a
`cost-nostance` arm; and the probe now reports `option_share` (how long each class actually **runs** each option) and
`transitions_per_unit_min` (which option → option transitions happen). A suppressed manoeuvre is invisible to every
switch counter and visible in those two.

### ⚠ NEGATIVE RESULT: A2 does not hit the −60% churn bar, and the bar was asking the wrong question

Laptop, `c68b423e`, yard, seed 3, gangs vs law, 120 s, both armies watched. **Switches per unit-minute:**

| class | A2 (cost) | legacy (flat 1.15 **+ dwell timer**) | price=0 (no commitment at all) | A2 vs nothing |
|---|---|---|---|---|
| artillery | 8.8 | 6.8 | 11.0 | **−20%** |
| ifv | 21.6 | 11.7 | 27.7 | **−22%** |
| scout | 12.2 | 8.2 | 16.8 | **−27%** |
| support | 7.9 | 6.7 | 7.8 | +1% |
| suppressor | 17.4 | 6.5 | 18.1 | −4% |
| tank | 28.5 | 20.7 | 48.9 | **−42%** |

**Reversals within 4 s per unit-minute** (the shape the lead actually complains about):

| class | A2 | legacy | price=0 |
|---|---|---|---|
| artillery | 0.64 | 0.10 | 0.87 |
| ifv | 0.77 | 0.61 | 1.31 |
| scout | 2.75 | 0.86 | 3.49 |
| support | 1.22 | 1.28 | 1.72 |
| suppressor | 1.11 | 0.51 | 1.62 |
| **tank** | **1.93** | 0.82 | **0.70** |

**Read plainly: A2 reduces churn against no commitment at all, by about half as much as the flat bonus plus its dwell
timer does, and for `tank` it produces MORE switch-and-switch-back than having no commitment term whatsoever.** The
brief's −60% bar was set against the flat 1.15 and A2 goes the other way. I pre-registered a −30% to −50% miss; the
truth is worse than my own pessimistic prediction, and the `tank` reversal row is a result I would not have guessed.

**The bar conflates two mechanisms, and that is a measurement fault I am fixing rather than an excuse.** `main`'s
commitment is a flat bonus **and** a hard dwell timer; A2 replaces both. So "A2 against legacy" charges A2 with
beating two mechanisms while being one, and any churn credited to the bonus may belong to the timer — the very timer
P3 says works by storing pressure up. Added `--tune=switch.dwell=0`, which takes the timer out of the legacy arm and
leaves the flat bonus alone, so the round can say which term did what:

| arm | what it is |
|---|---|
| default | A2's switching cost |
| `switch.legacy=1` | flat 1.15 **+** dwell timer (`main`) |
| `switch.legacy=1,switch.dwell=0` | flat 1.15 alone |
| `switch.price=0` | no commitment term at all |

**Caveats that must travel with these numbers.** Three different fights: the arms diverge after the first differing
decision, so unit-minutes are not distributed identically and a class that dies early contributes little. One seed,
one map, one matchup, laptop. `tank`, `suppressor` and `support` have the smallest samples (3.7k–5.0k thinks against
13–15k). **None of this is a verdict** — the falsifier verdict waits for CP1 (metrics' A12), per the standing rule.

**And the distinction that decides it is one my instrument cannot draw.** Label-counted switches cannot separate
genuine re-targeting from the wheeled creep, and metrics has just measured that **56% of all reversals are the creep**
and that it is a property of **wheels** rather than of a role. Every class above except `tank` is wheeled. So the
`tank` row — tracks, the one hull that produces **zero** creep cusps — is the only row in these tables that is
unambiguously about decisions, and it is the worst one. That is where I will look first.

### X2 pre-registration — written BEFORE the runs, 2026-09-20

The brief asks for the numbers expected before the run, so here they are, including the one I expect to miss. All on
the laptop unless a line says builder0; arm A = default (the switching cost), arm B = `--tune=switch.legacy=1`
(`main`'s pre-A2 flat 1.15 plus its dwell timer), arm C = `--tune=switch.price=0` (cost computed, never charged).

**Arm counter** (`make switch-arm`, yard, seed 3, gangs vs law, 120 s):
- `consulted` ≥ **0.80** for every hull class on the field — a crew in a fight nearly always has a current choice.
- `offered_s_median` for `gang_tank` (the 14 m War Rig) ≥ **2×** `gang_scout` (the rat rod). The unit test already
  says ×2.09 in a hand-built 140° case; this is the same claim in a real fight, where the angles are whatever they are.
- `flipped_per_think` between **0.01 and 0.25**. Below 0.01 the term is inert and A2 is not an arm; above 0.25 it is
  deciding the fight rather than pricing it, and that would be a different problem.
- Arm C: `flipped_per_think` **exactly 0.000** with `offered_s_median` **unchanged** from arm A — that is what makes it
  a control rather than a different build.

**Churn** (same probe, arm A against arm B; round 8's yard figures at 1.15 were 18.1 switches / 0.30 reversals per
unit-minute):
- switches per unit-minute: the brief's bar is **−60%**, i.e. ≤ 7.2. **I predict I will miss it: −30% to −50%.** A
  price that a decisive option can always pay cannot buy the silence a veto buys, and it should not. Recording the
  miss in advance is the point — if it comes in at −60% I want that to be a surprise, not a target I drifted toward.
- reversals within 4 s per unit-minute: **< 0.20** (the bar). This one I expect to hit, because A→B→A pays twice.
- The honesty check that goes with it: `flipped_per_think` and the switch rate are printed side by side, so churn that
  fell because every crew froze is visible as such.

**The two acceptance scenarios** (`make ai-scenarios`):
- `ai_focus_fire`: **unchanged** (100% with squad tactics vs 69% alone). A squad's focus target is usually already the
  nearest threat, so the angle — and therefore the cost — is small.
- `ai_cp2_scout_engine_deck`: **0.50–0.60**, i.e. it holds but stays tight. Orbiting re-chooses ORBIT on the same
  target, which is free; only the first ENGAGE → ORBIT pays, via the stance floor. **This is the one at risk**, and it
  had six hits of margin before I touched anything.

**Ladder** (`make faction-matrix` on yard and pit, SEEDS ≥ 5, arm A against arm B, builder0): **no significant change
in any faction pair**, |Δ| < 15 points, which at n ≈ 30 is inside the noise this tool resolves. It is the safety net,
never the evidence (lesson 150).

**And the one that is not optional:** `make ai-perf` on **builder0**. A2 adds one `acos`, a handful of multiplies and
a dictionary per think. Predicted cost: **under 2%** of `ai_usec_per_tick`. The perf scenario already fails on this
laptop for speed alone, so that number is worth nothing from here.

### Questions for the lead

None. (Balance is explicitly deferred by him; nothing here queues a balance question.)
