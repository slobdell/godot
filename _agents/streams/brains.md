# Stream: brains (squads on a route don't hang at each leg; the CPU's squad decisions)

> Read `_agents/orchestration.md` (the worker contract), `_agents/doctrine.md`, `_agents/workstreams.md` **Round 35** (C35.1, C35.7;
> R34.18, R34.19 in *Round 34*), and your round-34 brief `streams/archive/round34/brains.md` (its Status is the close-out).
> Evidence: `_agents/streams/references/round34/brains/`, manoeuvre's `references/round34/manoeuvre/cpf4-series/`.
> **You own:** `game/ai/**` EXCEPT traffic's, manoeuvre's, native's carve-outs, `game/tactics/**` EXCEPT orders' deploy-step and
> halt-lay functions in `element_plan.gd`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`,
> `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`.
> **The C++:** `decide`, `build_situation`, TacticalQuery and `_approach_gate` run in C++; every change there ships with native's mirror.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. His round-34 answers: the scout turn-in ships, the deploy
step is ON (orders owns it this round), a firing mortar truck keeps its spot.

What he will notice: squads on an attack-move or a route that move on to the next leg when they've arrived, instead of hanging
~30 s while one crew finishes turning to its arc.

## Where things stand

- **Shipped in round 34:** B1 scout try 2 (stand when it can win), B2's arrive-leg adapter (live with M2), B3, the Locks fixes, rank
  depth, ground_anchors, the stall fallback, gate order (with orders' code now owned by orders).
- **Parked:** B6 (early halt lay; superseded by the deploy step), B9 lane spread (R34.19: the mechanism works, the outcome doesn't
  follow), O2 (now orders' D3).
- **The sector-face step (R34.18):** attack-move elements step to the next leg ~30 s later when their arrived crews sit on a `face
  from sector` (tank_brain.gd ~2960's sector watch) instead of a stop; law/faced_attack_move-614 stepped at t 60 v t 32; 7 of 26
  pairs ≥ 10 s later.

## Backlog (in order)

1. **E1 The element step doesn't wait on a sector face (C35.7, your side).** Trace the hold in faced_attack_move-614 (which rule keeps
   `arrived` false or the step from firing), then agree the seam with manoeuvre through the orchestrator before code (their side: a
   face that gives up after N refused plans). Tests first; then CP-F 5's bar (manoeuvre files it).
2. **E2 B11b** (HOLD's return honours the post's facing for turret-mounted wheeled hulls) only if CP-F 5 ships.
3. **E3 The CPU commander and lanes, a second look (stretch).** B9's census showed stacking correlates with losing; the A/B showed
   spreading doesn't help. If you see a cause the census missed (the piecemeal arrival in locks-1404), write it up; no code without
   a bar.
4. **Merge fallout:** the deploy step ON (orders' D1) reaches CPU elements; answer orders' questions about element internals.

## How to verify

Tests first; `make quick-remote`; one full check at a time on builder0; series pinned, fresh seeds, no random twins. Every number:
commit, machine, workload, n.

## Don't touch

Orders' paths (game/control, the deploy/halt functions), traffic's, manoeuvre's and native's paths, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
