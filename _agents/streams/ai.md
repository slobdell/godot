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
| X1 | 4 ms at 60 units: profile first (`make ai-perf DETAIL=1`), then cut the biggest parts, each cut measured against behaviour (scenarios) as well as the clock | in progress |
| X2 | SUPPRESS reachable without matchups (penetration vs armour proxy); a pinned enemy pulls units out of cover; both through the ladder | not started |
| X3 | `make tactics-ladder`: doctrine variants x arenas x brains, per-drill report, ELO | not started |
| X4 | Faction behaviour that reads, measured in the ladder | not started |
| X5 | Offline discovery groundwork (external decision-maker mode, slow motion, `(state, decision, outcome)` log, distillation plan) | not started |

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

