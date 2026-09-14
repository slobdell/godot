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

- 2026-09-15: brief written for round 2. Nothing started.
