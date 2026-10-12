# Stream: scout (fixed guns that keep shooting while suppressing; every scout passes its duel bars)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 27 direction*,
> `_agents/workstreams.md` *Round 28*, and round 27's scout report (`streams/archive/round27/scout.md`: CP-S, the census,
> S4's write-up). **You own:** `game/ai/combat_motion.gd`; in `game/ai/tank_brain.gd` the fight-motion hunk
> (`_combat_move`, `_hold_motion_plan`, the ORBIT controller and its constants, the SUPPRESS motion for a fixed gun —
> agree the exact hunk with brains through the orchestrator before editing); `tests/test_ai_combat_motion.gd`,
> `tests/test_scout*.gd`, `tests/scout/**`, `tests/ai_scenarios/scenario_scout*.gd`, `mk/scout.mk`. `decide` is C++: a
> change to it goes to native as a diff first (C28.2).

## The lead's direction (2026-10-11, watching `make showmatch`)

> the scouts absolutely suck at attacking targets … they drive super close to their target, leaving no room for them to
> turn and maintain their target, and they don't seem to drive backwards when they have that option

Round 27 shipped the lay planner (CP-S): gun on target in reach +16 pts, contacts down; kills/damage unchanged within noise.
What he will notice next: scouts that also keep their gun on target while suppressing, and fewer scouts dying for nothing.

## Where things stand (main `ecc0d6e0`, green)

- CP-S: `CombatMotion.plan_lay`, a 2.1 s rollout over the fixed gun's plant (`--scout-off=gunlay`); only ENGAGE uses it.
- Census (seeds 13–36): 45 % of a scout's fight time is outside the planner: ENGAGE out of reach/sight 24 %, **SUPPRESS
  20 %**, FLANK 9 %, CLEAR_LANE 4 %. Flat kills/damage most likely sit there.
- S4 (the short-halt gate) not shipped (`scout-s4-halt`): gang_scout's spear gun lost standing shots on crossing targets.
  law_scout passes 4/5 duel bars, gang_scout 3/5.

## Backlog (in order)

**S1 — a fixed gun under SUPPRESS lays itself.** The planner (or its idea) for SUPPRESS: hull on the suppressed point,
turning room kept. Bar before numbers: on fresh census seeds, fixed-gun gun-on-point share during SUPPRESS up ≥ 10 pts
outside 2 se; all-fight on target not down; contacts not up; outcomes (kills, damage, deaths) reported. DECLARED.

**S2 — outcomes.** Why kills/damage stayed flat: per-seed, where scouts die and what they were doing (option × motion at
death). If a rule follows, its own declared change.

**S3 — law_scout and gang_scout duel bars** (stretch): the halt gate on turning room only (round 27's untested
candidate), judged on fresh seeds.

## How to verify

`make remote T=check`; `make scout-census` (fresh seeds after any tuning), `scenario_scout_cross` per unit; a before/after
showmatch clip of a suppressing scout for him.

## Don't touch

Brains' tactics/elements and the rest of `tank_brain.gd`; manoeuvre's and traffic's movement blocks; `native/**`.

## Waiting on the lead

Nothing.

## Status

_Not started._
