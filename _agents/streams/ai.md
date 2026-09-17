# Stream: ai (cost at scale, the gates that block behaviour, the tactics ladder)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*, *Unit AI*, *What earns a place in doctrine*), [../workstreams.md](../workstreams.md),
> [../unit_ai.md](../unit_ai.md) and [../doctrine.md](../doctrine.md), and your round-4 report
> [archive/round4/ai.md](archive/round4/ai.md). **Doctrine had no stream this round, so you inherit it:** you own
> `game/ai/`, `game/tactics/`, `doctrines/`, `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`,
> `tests/ai_scenarios/`, and `_agents/{tank_brain,squad_ai_design,unit_ai,doctrine}.md`.

## The lead's direction (2026-09-17)

Frame rate is the blocker this round, and the brains are part of it: *"right now for this many vehicles the framerate
drops substantially."* The simulation's share is yours. The lead also still wants what he asked for in round 4: units
that look intelligent, and eventually *"an offline simulation … to discover novel tactics and formalize those
discoveries into deterministic heuristics."*

## Where things stand (round 4, measured)

| Item | State |
|---|---|
| Brains execute doctrine (L1), suppression-aware movement and deliberate suppression (L2) | done and measured |
| **CPU cost** | **5.4–6.2 ms per tick at 60 units, against a 4 ms target** |
| **SUPPRESS unreachable in a duel** | a gate, not a weight: the "killing this is slow going" test reads `Matchups.kill_rate`, and the champion runs with `matchups: false` |
| **A pinned enemy doesn't pull a unit out of cover** | the 1.5× flank bonus exists but COVER_FIRE wins the choice 1435 ticks of 1440 |
| Tactics ladder (X4), faction behaviour (X5), offline discovery groundwork (X6) | **not started** |
| Champion | `x4t9` (thinks every 9 ticks in a fight) |

## Backlog (in order)

**X1. 4 ms at 60 units.** The named levers, in priority order from your own report: `_cover_fire_spot` runs a tactical
query for every brain with a target in reach, including ones that will never choose COVER_FIRE; a shared per-team
contact table instead of per-unit scans; typed arrays and precomputed matchup tables in `decide()`; order execution at
a lower rate for units that aren't firing. **Measure behaviour, not just the clock** (round 4's lesson: two cost cuts
silently removed most of a behaviour). `make ai-perf UNITS=60` before and after, plus the scenarios.

**X2. The gates that block behaviour** (with combat's X5). Make SUPPRESS reachable with a matchup-free proxy
(penetration against armour), and make a pinned enemy actually pull units out of cover. Both change what the champion
does, so both go through the ladder rather than a late edit.

**X3. The tactics ladder (round 4's X4, unfinished).** `make tactics-ladder`: seeded headless matches sweeping
**doctrine** variants and arenas alongside brain variants, reporting **per drill** rather than per variant, with ELO.
This is how a drill earns its place (game_design.md's rule) and how arena's new maps get judged for the fights they
produce. Arena's M2 layouts land this round: sweep them.

**X4. Faction behaviour that reads.** Gang packs, Law bounds behind suppression, Syndicate kiting — visibly different
at play distance, and measured in the ladder. The gangs' 23% win rate is combat's number, but if the cause is
behaviour, it's yours: a swarm that fights like a line company will lose.

**X5. Offline discovery groundwork** (round 4's X6, unfinished): a match-runner mode where an external process sees a
compact state and issues element tasks on a slow cadence, optional slow motion, and a `(state, decision, outcome)` log.
Write the distillation plan in `unit_ai.md`. **No model runs during live play.**

- **Stretch:** run the discovery experiment once and report what it found; a difficulty knob (reaction time,
  suppression sensitivity); explanation overlays for the lead's playtests.

## How to verify

`make remote T=check`; your scenarios; `make ai-perf` numbers before and after X1; the ladder's tables; a watched match
whose screenshots you look at, with a spectator's description. The sim baseline changes on purpose, recorded on builder0.

## Don't touch

Weapons, armour and rules (combat; request changes), arena layouts (arena), vehicle art and effects (render), UI and
camera (control), audio (audio).

## Status

_Round 5, ai stream. Updated 2026-09-17. Branch `stream/ai`._

### Plan (in order, smallest foundation first)

| # | Item | State |
|---|---|---|
| X1 | 4 ms at 60 units | **exact cuts done; the rest is structural** — opt-in `x5b2` (half-rate controllers) in the ladder; the 30 Hz simulation is the lead's call (below) |
| X2 | SUPPRESS reachable without matchups; a pinned enemy pulls units out of cover | **built as opt-in `x5s`**; first ladder 27-37 against x4t9 (the proxy costs the swarm army): to split and re-run, and to rewire onto combat's `Lethality` when it merges |
| X3 | `make tactics-ladder` | **done** — doctrine beats brains-only 52-28; the skirmish CPU gets doctrine by default (orchestrator ruling, control flips it); drill-variant ladder running |
| X4 | Faction behaviour that reads, measured in the ladder | **in progress** — faction ladder (brains vs faction doctrine, gangs vs law) running on builder0 |
| X5 | Offline discovery groundwork | **done** — `DiscoveryBridge` + `tools/discovery.py`, distillation plan in unit_ai.md; its first policy became the `pin_and_flank` commander variant (in the ladder) |

### X1 — the cost of 60 brains: what was measured

**Measuring first.** Wall time on builder0 swings ±25% between its P-cores and E-cores and with five other agents'
load, which hid every cut under 10%. `make ai-perf` now also prints the **thread CPU time** of the brains' band
(`tests/ai_scenarios/band_probe.gd` brackets the priority -10 band and reads `/proc/thread-self/schedstat`), and that
**per living unit per tick**, so variants that fight different battles still compare. On the idle laptop CPU time
and wall time agree within 1%.

| ai-perf, 60 cannon tanks, laptop, thread CPU per tick | usec | per living unit |
|---|---|---|
| Start of round 5 (x4t9) | 7748 | 188 |
| + exact cuts (typed per-tick columns, feed sources once per tick, no cover-fire search for fast guns, no lambda per option) | ~7400 | ~180 |
| + CoverMap typed features and bucketed tactical points (the yard has 2860 points every query used to scan) | 7260 | 177 |
| x5b2 (whole controller every other tick, staggered), whole scenario suite | | **147 (-21%)** |

Every exact cut kept the battle byte-identical (the LOS query counts and `make sim-baseline` are unchanged) and the
risky ones have equivalence tests against the plain versions (`test_ai_perf_equivalence`,
`test_ai_cover_map_equivalence`, both mutation-checked).

**Where the time goes**, measured by running one piece twice per tick and reading the extra CPU (a lower bound, since
the second call hits warm caches): thinking ~35% (situation 15%, decide 10%, the rest acting and the per-tick polls),
executing ~37% (moving 19%, the gun 14%). No piece dominates: 60 brains are ~180 µs each per tick of GDScript
spread over a few hundred operations. Round 4 already spent the think-rate lever, and holding only the steering at
30 Hz ("exec_stride") bought 6% and was removed.

**So 4 ms at 60 units on the laptop needs about half the work per tick,** and there are two ways to get it:
1. **combat's 30 Hz simulation proposal** (`_agents/sim_tick_rate.md`): halves every band, ai's included. A lead
   decision, now in front of him through the orchestrator.
2. **`x5b2`** (ai-only, opt-in): each brain runs its whole controller every other physics tick, staggered, and the
   tank keeps its last command in between; a new K1 order or element call still runs on the very next tick
   (`ai_order_response` worst 1 tick, unchanged). -21% per unit in the suite (thinking cadence is unchanged, so not
   -50%). It becomes champion only if the ladder says it costs no behaviour. It and (1) don't stack: if the lead takes
   (1), x5b2 goes.

**Found on the way:** `OrderController._shootable` computed "does my team see it" and never used the answer, so a gun
has always fired at anything in range with a clear line. The dead call is gone; whether it should hold fire on things
nobody spotted is a behaviour question for the ladder.

### X3 — the tactics ladder, and what it found

`make tactics-ladder` (unit_ai.md "Tactics ladder"). First full run: 120 matches, combined_arms mirror, foundry, yard,
boulevard, pit and boneyard, 2 seeds × 4 ways per pairing per arena, x4t9 brains throughout.

| Side | W-L | vs brains-only |
|---|---|---|
| faction's own doctrine | 49-31 | 26-14 |
| standard doctrine | 43-37 | 26-14 |
| brains only (what the skirmish CPU ran) | 28-52 | |

**The skirmish CPU had never run doctrine** (brains only unless `--element-cpu`), and the match runner never ran it at
all, so round 4's formations and drills were in no game the lead played: "two masses shooting at each other" is what
armies of brains with no element above them look like. Ruled by the orchestrator: doctrine becomes the skirmish CPU's
default this round (control owns the flag); the match runner stays opt-in (`--green-elements`) until combat
re-baselines deliberately.

Per drill (damage charged to what the units were doing), standard / faction: **support_by_fire 9.4 / 12.1 exchange**,
react_to_contact 1.08 / 1.12, near_ambush 1.16 / 1.18, assault_through 1.22 / 1.08, **break_contact 0.75 / 0.73 over
40% / 15% of drill time**, **far_ambush 0.26 / 0.16 with 16 / 44 deaths**. Exchange is evidence, not a verdict (a drill
that starts when an element is already losing collects its deaths): variants without each drill are in the ladder now.

**Cost of doctrine at 30 a side** (laptop, Jolt, condemned 31 v 27, `make sim-profile`, interleaved, normalised by
the tank band): the elements band averages **1.5-1.8 ms/tick**, about **+15% of the whole tick** with brains running
under orders. It used to arrive as a **~9 ms spike every 6th tick** (every leader decided on the same tick); since
611b380 each element decides on its own tick in the cycle, so the **average is unchanged but the periodic hitch is
gone** — a stutter a player feels even when the mean frame time looks fine. Breakdown of an element update: situation
0.61 ms, plan 0.34, issuing orders 0.24 (per tick).

### X1 — x5b2's behaviour check

`tests/ai_scenarios/scenario_stride.gd`, x5b2 against x4t9 on the same seeds (laptop, Jolt): IFV dodges 14% of 35
tank shells vs 17% of 30, tank 17% vs 17%; crossing a swept lane 10 ticks in the beaten zone vs 10, both arrive.
Brain ladder (4 armies × 16): 31-33 head to head. More seeds (5-12) running before any proposal.

Queued from other streams (after X1, in the doctrine code ai inherits):
- **arena:** `ElementSituation._arena_features` calls 86–95% of the kit-built maps "dense" (it counts boxes; one container
  wall is several). Count touching boxes (1.5 m) as one piece of cover and ignore `cover: "low"` barricades; arena
  measured foundry unchanged at 16% (`make arena-report`).
- **control:** K1 `UnitCommand.facing` has landed; brains turning to `order["facing"]` on arrival and to
  `Orders.station(unit)["heading"]` when idle lets `element_plan.gd` drop the `HALT_*`/`_plan_halt` shuffle.

- **arena (for X3/X4):** flanks are 4–5% of unit-time on the dense kit maps against 14% on foundry (the CPU funnels
  to the control point), and median hit range is 39–43 m on every map. Lanes are annotated (`Arena.lanes_of`): the
  ladder should measure whether elements and brains actually take them.

Decision: X1 before X2 because X2 changes what the champion does, and every X2 ladder run is cheaper once the brains are.

