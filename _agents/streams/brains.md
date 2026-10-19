# Stream: brains (a scout stands and trades when it can win and leaves when it can't; the flicker's seam; B11b once CP-F lands)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/doctrine.md`,
> `_agents/workstreams.md` **Round 34** (C34.4, C34.5, C34.9; R33.31 and R33.24 in *Round 33*), `_agents/game_design.md`
> (C33.9, his scout report, verbatim), `_agents/roadmap.md` *Round 34 candidates*, and your round-33 brief
> `streams/archive/round33/brains.md` (*ROUND 33 CLOSE*: what round 34 should carry). Evidence:
> `streams/references/round33/brains/`.
> **You own:** `game/ai/**` EXCEPT traffic's, manoeuvre's, native's and planner's carve-outs (*Round 33* ownership),
> `game/tactics/**`, `tests/ai_scenarios/**` (others add their own `scenario_<stream>*.gd`), `tests/tactics/**`,
> `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`,
> `tests/test_wheeled_arrival.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`.
> **The C++ (C31.2):** `decide`, `build_situation`, TacticalQuery and `_approach_gate` run in C++. Every change there
> ships with native's mirror. **Model:** Opus.

## The lead's direction

His scout report (C33.9, verbatim in `game_design.md`): a scout being circled was "repeatedly driving forward and
backward trying to yaw right... The obvious correct behavior... drive straight forward and to the right... and also some
sort of evasive manoeuvre." Manoeuvre's turn-in (C33.9) did NOT ship at round 33's close (R33.39). It's manoeuvre's first
round-34 item (C34.10). **His answer (2026-10-18, "go
with both of your recommendations"), read as: a scout that can win the duel stands and trades; one that is outgunned
leaves.** Standing rule: smart AI on both sides, and symmetric improvements ship without asking.

## Where things stand (main at the round-34 docs commit)

- **Round 33 shipped from brains:** R1 respawns, R33.9 arrive latch, R33.6 coordinated groups, R4 approach gate, battery
  seat (a), rejoin, War Rig edge inset (4-of-5), herringbone halt fix.
- **Scout fights back, try 1 PARKED (R33.31):** at SPOT 0.15, ENGAGE won 90 % of firing ticks and shots rose ×1.62, but
  damage rose, and 3 close-orbit cells against the faster, longer-ranged syn_scout were > 20 % worse. Base:
  `lab/brains-scout` `0565d1a89` (GDScript + native pair).
- **B11b** waits on CP-F (manoeuvre's M3). **B10b** parked twice (R33.18, R33.22); its code is on `round33/brains`
  `78e9b59af` (`--ground-latch`). Not for main as written.
- `lab/brains-r33-battery` `ee18403b9` holds battery (c), parked. `lab/brains-r32-swap` `f2cc956d3` holds the inert
  swap seam (R5). Neither is this round's work unless named.

## Backlog (in order)

1. **B1 Scout try 2: stand when it can win, leave when it can't (C34.5).** Rebase `lab/brains-scout` on main (C33.9's
   turn-in is OFF there; agree with manoeuvre which arms report it ON). ENGAGE beats SPOT only with duel advantage ≥ 1.0 AND the contact in reach over the next 1–2 s;
   otherwise SPOT 0.88 and open distance. A pure test for each side of the rule. The bar is filed before any number: orbit
   seeds 73–79 (fresh), the shots ratio, damage taken (no cell worse by > 20 % on cells with base hits ≥ 10), scout survival,
   and team enemy-seen seconds ≥ base − 1.645 se. Native's mirror before the pair's check. One machine.
2. **B2 The flicker's seam (C34.4 (2)), with manoeuvre.** You own `_act`'s arrived branch and `_order_move`'s held-post
   refusal. Agree the seam with manoeuvre through the orchestrator before either side writes code. Review
   `lab/cpf-arriveleg` `7e0953f9d`'s one condition.
3. **B3 War Rig trace: log the inset's engage distance** (small; round 33's (1b) was reported only).
4. **B4 B11b (C33.3 stands) once CP-F merges:** HOLD's return honours the post's facing for `mount == "turret"` wheeled
   hulls only. Pass case s66 Green_Guns_5 ≤ 90° in ≥ 2 of 3; no class worse at p < 0.05; on a base with CP-F ON.
5. **B5 T4's body stage, on traffic's request** (C34.3): an order-free body stage if traffic's trace needs one.
6. **Stretch:** B10b's new form (re-ground with hysteresis, not the hold), with a fresh bar on fresh seeds.

## How to verify

`make quick-remote`; `make native check` on the pair tree (switch ON) before any series. `make scout-census`, the orbit
cells target (manoeuvre's `mk/manoeuvre.mk` c339 cells), `ground-series`, the fights guard. Long runs under `systemd-run
--user`. Every number: commit, machine, workload, n.

## Don't touch

Traffic's give-way block; manoeuvre's drive body, executor, the turn-in in `order_controller.gd`; planner's
`game/ai/planner/**`; native's `native/**`; `game/match/**`; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
