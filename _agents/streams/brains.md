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

**Start (2026-10-19 08:40 PDT):** worktree `godot-brains` on `stream/brains` at `a0ae0aafd`; launch baseline is main's inherited
green (HANDOFF), no baseline check run.

**Plan (in order):**
1. E1 trace: reproduce law/faced_attack_move-614 on `lab/cpf4` `e76f6dab6` (the tree R34.18 traced) and on today's main, with a
   measurement-only leg-gate trace (`ElementPlan._advance`: `reached`, `_cohesive`, which crew fails it by how much), then the
   26-pair attack-move set on builder0 to see whether the hold still exists on main. Reason: the seam with manoeuvre must name
   the rule that actually holds, not the one the README guessed.
2. E1 seam note to the orchestrator; tests first; code only after the seam is agreed.
3. E2 only if CP-F 5 ships. 4. E3 write-up (no code without a bar). 5. Merge fallout from orders' D1.

**E1 trace (R35.3, agreed: the seam is decoupled).** law/faced_attack_move-614 on `lab/cpf4` `e76f6dab6`, laptop, GDScript, both
arms, leg-gate trace `c23acdbe2`: the leg is held by `ElementPlan._advance`'s `_cohesive`, never by a face. `reached` is true at
every hold; `_cohesive` fails on one crew over its allowance (20 m x 1.0 / 12 m/s = 1.33 s, ~16 m); each step fires the moment
the laggard gets inside. The crew on `face from sector` stood 3-4 m from its slot (closed up). Base arm: element 3 waits t 37 to
past 75 on Green_Guns_4 WEDGED at (18, 87.5) (plant 9.25 m/s, real 1.17, 30 m off, re-seat budget spent). The 128-run census
(builder0, seeds 601-616 x 4 factions x CP-F on/off, `leg_wait_table.py`) is running.

**E1 design: the straggler release.** `_advance`'s gate stops waiting for a crew that has not come STRAGGLER_GAIN_M (2 m) closer
to its slot in STRAGGLER_S (8 s) while the element stands at its anchor: closed-up is judged over the others, the element steps,
and the straggler is sent to its slot on the next leg (it catches up; a wedged crew gets a new goal, which is also its best
chance to come unstuck). Both sides (symmetric AI). `--straggler=off` is main's gate (the base arm and the attribution).

**Bar E1 (filed 2026-10-19 before any number).** One commit, builder0, native, both arms the same tree (base `--straggler=off`).
Workload: hull-rest drawn, `faced_attack_move` + `faced_move`, FRESH seeds 701-716 x gangs/law/syndicate/condemned (128 runs an
arm), `--element-trace=all --turn-states`; fights: `manoeuvre-fights`' census on fresh seeds 720-743 (24 an arm). Paired by seed;
se of the paired sum.
- (0) FIRST (R35.5's rule): straggler releases > 0 in the new arm (LEG_GATE `released`), else the A/B is vacuous.
- (a) DECIDING: long-hold seconds (leg waits >= 10 s, `leg_wait_table.py`) summed over attack-move runs: new <= 0.6 x base AND the
  paired difference < 0 by > 2 se.
- (b) the same on faced_move: not worse by > 2 se (report the size).
- (c) GUARD, left behind: crews > 25 m off their slot in their element's last trace row before the judge, new - base <= max(2, 2 se)
  on each task.
- (d) GUARD, late movers at 75 s: crews with real_mps >= 0.3 at the judge, new - base <= 2 se on each task; settled-in-75 s counts
  the same.
- (e) GUARD, squads arrived (judge rows): base - new <= 2 se.
- (f) GUARD, fights: kills and deaths each side within 2 se (paired).
- (g) `make check` green on the hash; sim-baseline maps that move are attributed with `--straggler=off` on the same tree.
