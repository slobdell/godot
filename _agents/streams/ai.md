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
- 2026-09-15 (ai agent, unattended run): A0–A4 done and committed on `stream/ai`; details and numbers below and in
  [../unit_ai.md](../unit_ai.md) "Results".

### Plan (ordered, smallest foundation first)

1. A0 design doc `_agents/unit_ai.md` — **done** (literature survey, what we adopt and skip, budgets).
2. A1 scenario harness — **done**: `AiScenario` (tests/ai_scenarios/ai_scenario.gd), `make ai-scenarios` (faster than real time, `PENDING` lists for not-yet-built behaviors that must fail until promoted), quick subset in `tests/test_ai_scenarios.gd` (runs in `make test`).
3. A2 tactical positions — **done**: `CoverMap` (pure 2D cover + memoized quantized LOS, grid broadphase, static tactical points; reads rules' `Arena.cover_features()` when present, else the arena's Obstacles boxes), `TacticalQuery` (generate/filter/score: `find_cover`, `find_cover_fire`), `UtilityCurves`, `make ai-perf`.
4. A3 cover discipline — **done**: `COVER_FIRE` (hide → peek when loaded → fire → reverse back), RETREAT breaks line of sight first, withdrawals back straight away from threats.
5. A4 fire discipline — **done**: `FireLanes`, OrderController hold-fire gate (`lane_blocked_ticks`), `CLEAR_LANE`, artillery splash check.
6. A5 `Matchups` — **waiting on checkpoint 1** (rules' catalog v2 is on `stream/rules`, not `main` yet). Scenarios written and pending.
7. A6 squad tactics — **done** (`SquadTactics`: focus fire, suppress-and-flank, cover a withdrawing squad-mate, fragile threats); T1 measured before A6 (after-A6 re-measure pending the ladder's champion).
8. A7 ladder — **tooling done** (`BrainVariants`, `--green-brain/--rust-brain`, `tools/ai_ladder.py`, `make ai-ladder`); run 1 says r1 beats a4 13–3 (see unit_ai.md); probe run 2 in progress.
9. Stretch: smarter CpuCommander; on-map explanations.

### Report (kept current)

**Done (measured, seeded scenarios):**
- A hurt tank under two guns is out of sight in 3.3 s (the round-1 brain backed 100 m across open ground and never hid).
- A healthy cannon tank near a wall is hidden 68% of a 20 s duel, fires 9 shots, and returns to cover 7 times (was 0%).
- Fire discipline: 0 of 7 shots through a crossing friend (was 1); a parked friend in the lane → sidestep 5.4 m, first shot 2.9 s; artillery won't shell an enemy touching a friend.
- `CoverMap` agrees with physics raycasts on 139/139 random sight lines.
- AI CPU at 50 brains: ~15.3 → ~7–9 ms per tick (see "Known issues").
- Sim baseline updated on purpose three times (A2+A3, perf, A4): now `a6dff29a834f0628`.

**Decisions (with reasons):**
- Line of sight for decisions is pure 2D math (CoverMap), not physics rays: testable on hand-built situations, deterministic via quantized memo keys, and it matches physics on the real arena.
- Hiding places must hide the whole hull (center ± 1.6 m), not the center point: center-only spots left tanks parked on the shadow's edge.
- Peek spots allow 30–60° off the target bearing (not ≤ 45°): tanks can't strafe, and ≤ 45° can't get around a wall's end; smaller angles are preferred in scoring.
- Brains reason about their nearest 8 contacts (+ current target + artillery), and cover queries run only for worn tanks: the biggest CPU wins with small behavior cost.
- `fire_at_will` re-scans targets every 6 ticks (keeps a still-shootable pick in between): cheaper, ≤ 0.1 s slower target switching.
- `move_to` orders gained an optional `arrive` radius (1 m for hide/peek spots); validated like the other fields.

**Questions for the lead:** none blocking. (Design note for later: peeking shows some side armor when a wall's end forces a 60° peek; low cover or terrain would allow true hull-down.)

**Requests to other streams:**
- rules: none required. My adapters already match your branch: `Arena.cover_features()` (Vector3 size, radians) feeds CoverMap, and `Match.friendlies_in_line_of_fire()` replaces my FireLanes geometry automatically when present. At checkpoint 1 I'll adapt `AiScenario` and `scenario_perf` to the v2 `spawn_tank(name, owner, team, unit_id, paint)` / `add_brain_tank(..., unit_id, ...)` / `"units"` doctrine key.
- command (optional): `tank.intent` now shows COVER_FIRE / CLEAR_LANE; worth an icon or color on the map later.

**Known issues:**
- CPU: ~7–9 ms per tick at 50 brains on the shared dev machine, far above the 1 ms design target (phones need ≤ ~4 ms). Plan in unit_ai.md "Results": think LOD, 30 Hz orders, a shared per-team contact table, typed arrays in decide.
- The hurt-tank scenario still ends with the tank leaving cover to go home once it's hidden (withdraws straight away from the threat, but eventually re-exposes on a long route).

**What to playtest:** `make skirmish` and watch tanks near walls under fire: they should duck behind cover, peek out to shoot, and never shoot through a teammate. Nameplates (`make watch-match GREEN_DOCTRINE=anvil_hammer RUST_DOCTRINE=individuals`) show COVER_FIRE / CLEAR_LANE.
