# Stream: ai (unit and squad behavior)

> Read [../game_design.md](../game_design.md) ("Unit AI"), [../workstreams.md](../workstreams.md),
> [../tank_brain.md](../tank_brain.md), and [../squad_ai_design.md](../squad_ai_design.md).
> You own `game/ai/` (except `doctrine.gd`), `game/agent/`, `tools/agent.py`, `_agents/tank_brain.md`,
> `_agents/squad_ai_design.md`, and a new `_agents/unit_ai.md`.

## The lead's direction (2026-09-15)

> *"On the gameplay front in general, we need the heuristic based, weighted tree decision to be really good and
> sophisticated. Even before we introduce AI, all of the vehicles on the board should behave smartly, i.e. taking
> advantage of cover, going in and out of cover to shoot, etc. … the tanks should be smart enough that they avoid
> shooting their own friendlies or at least account for the risk of shooting friendlies in their decision making
> … for the in-game AI (not LLM AI) I want this to be really sophisticated … I'm sure there's a ton of gaming
> literature for making individual units in the game behave very smartly."*

## Where things stand (round 1)

`TankBrain` is a deterministic utility AI: pure `decide()` over options (RETREAT, TAKE_COVER, ENGAGE, FLANK,
INVESTIGATE, REGROUP, ADVANCE, KEEP_SLOT, HOLD, plus RECHARGE, RESUPPLY, SPOT, BOMBARD, SHADOW, CONTEST), with
directives, commitment, team intel, and turret watch points. `Squad` runs commanders, formations, and drills;
`CpuCommander` issues squad orders (opt-in, at parity). Measured problems: fights snowball; shields made
coordinated doctrines lose to individuals (~5–10%) unless the control point is on; idle guns 70–90%.
Cover today is crude (TAKE_COVER picks a nearby obstacle side).

## Backlog (in order)

**A0. Design doc `_agents/unit_ai.md`.** Survey the literature and write the architecture you will build,
fitted to our deterministic utility brains. Cover at least:
- utility AI with considerations and response curves (Dave Mark)
- tactical position evaluation (Killzone's position picking, CryEngine's Tactical Point System, Unreal's EQS)
- influence maps (threat, control, exposure)
- line-of-fire and friendly-fire reasoning
- squad coordination (F.E.A.R.'s GOAP squads, bounding overwatch, suppress-and-flank)
- performance budgeting for phones

Say what you'll adopt and why.

**A1. Behavior scenario harness.** Deterministic, seeded mini-battles with assertions, in `tests/` (e.g.
`test_ai_scenarios.gd`) plus `make ai-scenarios` for longer ones. Each future behavior starts as a failing
scenario, for example:
- "a tank under fire moves to cover within N s"
- "peeks, fires, and returns to cover"
- "holds fire while a friendly crosses the line"
- "a scout circles a tank instead of trading frontally"
- "an IFV prioritizes scouts"

**A2. Tactical position evaluation.** Candidate points from cover features (`Arena.cover_features()`, C4) and
navmesh samples, scored by:
- cover from known threats and line of sight to the target
- preferred weapon range and exposure to other threats
- path safety and spacing from friendlies (splash)
- distance from the squad slot, honoring player intent

It must be cheap: cached per team per think interval, with a measured per-tick cost at 50 units.

**A3. Cover discipline: peek and shoot.** Hide → peek when the gun is ready → fire → back into cover while
reloading or recharging shields. Prefer hull-down or front-armor angles.

**A4. Fire discipline and friendly fire.** Never take a shot whose line of fire or splash crosses a friendly
(`Match.friendlies_in_line_of_fire`), or weigh that risk explicitly. Shift to clear a firing lane; artillery checks
splash near friendlies.

**A5. Matchup-aware fighting** (with rules' roster v2).
- Pick targets by what my weapon beats (using both the mechanics and the `good_vs`/`weak_vs` hints) and avoid losing duels.
- Fixed-mount scouts aim with the hull and strafe or orbit slow turrets.
- IFVs screen against scouts; tanks keep their front to threats.
- Lancers and artillery keep their distance and stay protected.

**A6. Squad tactics:** focus fire, suppress-and-flank, covering a retreating teammate, protecting fragile units,
and bounding overwatch that uses A2 positions. Re-measure "coordination beats individuals" (T1) with and without
the control point.

**A7. AI ladder:** `make ai-ladder` runs brain versions or parameter sets against each other (seeded, both sides,
swap bases), keeps an ELO table in `_agents/unit_ai.md`, and a new brain must beat the previous champion before it
replaces it. Report the CPU cost per unit per tick.

- **Stretch:** a smarter `CpuCommander` that uses the new squad tactics (it must beat plain brains before becoming
  the skirmish default); explanations on the map (why a unit is doing what it does) for the lead's playtests.

## Rules of the road

- **Determinism:** decisions read `Match.tick`, never the clock; iterate in sorted order; `make determinism` must stay
  green. Update the sim baseline on purpose, with a reason.
- **Player intent wins:** smart behavior happens *within* the squad's order (G3's responsiveness tests must still pass).
- Until rules' catalog v2 lands (checkpoint 1), build A0–A4 against today's units and C4 stubs in your own paths.

## Don't touch

Unit stats and combat rules (rules; request changes), the UI and camera (command), art (art), the army builder (army).

## Status

- 2026-09-15: brief written for round 2.
- 2026-09-15 (ai agent, unattended run): A0–A4, A6, A7 done and committed on `stream/ai` (pushed as backup);
  A5 groundwork done, the rest waits on checkpoint 1. Numbers in [../unit_ai.md](../unit_ai.md) "Results".

### Plan (ordered, smallest foundation first)

1. A0 design doc `_agents/unit_ai.md` — **done** (literature survey, what we adopt and skip, budgets; an "As built" table maps plan → code).
2. A1 scenario harness — **done**: `AiScenario`, `make ai-scenarios` (faster than real time; `PENDING` lists must fail until promoted), quick subset in `tests/test_ai_scenarios.gd` (runs in `make test`).
3. A2 tactical positions — **done**: `CoverMap` (pure 2D cover, memoized quantized LOS, static tactical points; reads rules' `Arena.cover_features()` when present), `TacticalQuery` (`find_cover`, `find_cover_fire`, `find_overwatch`), `UtilityCurves`, `make ai-perf`.
4. A3 cover discipline — **done**: `COVER_FIRE` (hide → peek when loaded → fire → reverse back), RETREAT breaks line of sight first, withdrawals back away from threats.
5. A4 fire discipline — **done**: `FireLanes`, hold-fire gate, `CLEAR_LANE`, artillery splash check.
6. A5 matchups — **groundwork done, blocked on checkpoint 1**: `Matchups` (pure mechanics-based damage estimates + duel advantage, tested on catalog-v2-shaped data). Wiring into target choice, scout orbiting, IFV screening, and Lancer/artillery standoff needs rules' catalog v2 on `main` (intel `unit`/`role`, `mount`, `fire_arc_deg`). Two scenarios are written and pending.
7. A6 squad tactics — **done**: `SquadTactics` (focus fire, suppress-and-flank, cover a withdrawing squad-mate, fragile threats), bounding overwatch from tactical spots (the bound waits for the overwatch to set); T1 re-measured with and without the control point.
8. A7 ladder — **done**: `BrainVariants` (r1, a4, a6, a6t9), `--green-brain/--rust-brain`, `tools/ai_ladder.py`, `make ai-ladder`; three runs; **champion a6**; CPU cost per tick reported.
9. Stretch: on-map explanations — **done from the AI side** (`tank.intent` carries a short why; the tactical map draws intent; the agent bridge reports teammates' intents). Smarter CpuCommander — **v2 built and measured, not better** (9/32 vs v1's 8/32 against plain brains); stays opt-in; re-measure with multi-squad v2 armies after checkpoint 1.

### Report (kept current)

**Done (measured):**
- A hurt tank under two guns is out of sight in 3.3 s (the round-1 brain backed 100 m across open ground and never hid).
- A cannon tank near a wall is hidden 65–68% of a 20 s duel, fires 9 shots, returns to cover 6–7 times (was 0%).
- Fire discipline: 0 of 7 shots through a crossing friend (was 1); parked friend → sidestep 5.4 m, first shot 2.9 s; artillery won't shell an enemy touching a friend.
- Squad focus: 100% of a squad's damage on one target (66% without squad tactics). Bounding overwatch: the watcher beside a wall hidden 51% of its watch (0% before).
- Ladder: a6 1189 / r1 997 in run 2 (a6 beat r1 7–5, a4 9–7 in run 1; r1 vs a6 14–14 over both runs). In mirrors a6 lands more hits (85% vs 79% accuracy, 25% vs 16% side hits) with 4% fewer shots.
- T1 (Anvil & Hammer vs Individuals, 64 matches per brain): without the control point 16% both before and after squad tactics; with it 69% → 38% after squad tactics.
- AI CPU at 50 brains: ~15.3 ms (round 1 as found) → ~7–9 ms per tick on this shared machine.
- Sim baseline updated on purpose with each behavior change; now `eaef1755546f1eeb`.

**Decisions (with reasons):**
- Line of sight for decisions is pure 2D math (CoverMap): testable on hand-built situations, deterministic, and it matched physics raycasts 139/139.
- Hiding places hide the whole hull (center ± 1.6 m); peeks allow 30–60° off the bearing (tanks can't strafe around a wall's end).
- Brains reason about their nearest 8 contacts; cover queries only for worn tanks; think LOD (18 ticks with no enemy within 130 m): CPU wins with small behavior cost.
- Champion chosen by the ladder, not by intuition: my guess that holding fire for friends was a handicap was wrong (a6 beat no-hold 9–3); a "press instead of duck" tweak lost 0–12 and was deleted; a 9-tick think interval saved 24% CPU but didn't beat a6, so it isn't the default.
- Brain variants are read from `--green-brain/--rust-brain` by the brain itself, so no rules-owned file (match runner) changed.
- `move_to` orders gained an optional `arrive` radius; squads' bound drill waits for the overwatch to set (≥ 1 s, ≤ 4 s).

**Questions for the lead:**
1. **Smart squads vs player coordination (design, pillar-adjacent):** squad tactics made one autonomous 5-tank squad fight nearly as well as a split, coordinated doctrine (T1 with the control point 69% → 38%). That's what "units handle how" implies; it means the player's edge must come from where/when (splits, routes, timing, objectives) and composition counters. OK, or should autonomous squad tactics be weaker (e.g. only when the player orders an assault)? The switch exists (`squad_tactics` in `BrainVariants`).
2. Peeking round a wall's end shows some side armor (60° peeks). Low cover or terrain would allow true hull-down; worth asking rules/art for low cover pieces?

**Requests to other streams:**
- rules: none required. Adapters match your branch (`Arena.cover_features()`, `Match.friendlies_in_line_of_fire()`, intel `unit`/`role`). At checkpoint 1 I'll adapt `AiScenario`/`scenario_perf` to the v2 `spawn_tank`/`add_brain_tank`/`"units"` signatures and wire `Matchups`.
- command (optional): `tank.intent` now reads like "COVER_FIRE Rust_2 - squad focus, peek"; the tactical map's intent text could use an icon or truncation.

**Known issues:**
- CPU: ~7–9 ms per tick at 50 brains (target 1 ms; phones need ≤ ~4 ms). Next levers, in order: `a6t9` (−24%, re-test with more matches), a shared per-team contact table, 30 Hz order execution for units not firing, typed arrays in `decide()`.
- Idle guns read 95% (was 78–89%): by design (holding for friends, reloading in cover), but it makes that stat less useful; a "held for friend" counter would separate it (needs a Match stat, rules-owned).
- A hurt tank that hid eventually leaves cover to repair at base and can re-expose itself on the way.
- A CPU commander doesn't beat plain brains yet (25–28%); keep it off by default.
- A 45 s browser skirmish screenshot hangs under SwiftShader (tried once; `make web-smoke` itself passes). Behavior was verified headless (scenarios, series), not by watching a rendered match.

**What to playtest:** `make skirmish` (tanks should duck behind walls under fire, peek out to shoot, never shoot through a teammate, and a squad should pile onto one enemy). `make watch-match GREEN_DOCTRINE=anvil_hammer RUST_DOCTRINE=individuals` shows intents with reasons on nameplates. `make ai-scenarios`, `make ai-ladder`, `make ai-perf` reproduce the numbers.
