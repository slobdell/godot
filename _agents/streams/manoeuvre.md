# Stream: manoeuvre (a wheeled turret vehicle told to face a direction ends facing it and sits still: a better ruler, the arrival flicker, then CP-F attempt 4)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 28 direction* (his call 2: turn
> the whole vehicle), `_agents/judging.md`, `_agents/workstreams.md` **Round 34** (C34.1, C34.4; R33.2, R33.21, R33.23,
> R33.34, R33.35 in *Round 33*), `_agents/roadmap.md` *Round 34 candidates* (the hull-rest entries, the k-turn flicker),
> your round-33 brief `streams/archive/round33/manoeuvre.md` (its close-out Status), and planner's diagnosis
> `references/round33/planner/face-flip-s69/`. Evidence: `references/round33/manoeuvre/` (cpf3b-series, cpf-arriveleg-dev,
> c339-judged). Raw runs (1.4 GB): `/home/slobdell/overnight-manoeuvre`, outside the repo.
> **You own:** round 33's manoeuvre paths (`game/ai/movement.gd`'s `drive()` body, `_nose_stop`, `unstick`,
> `_pressing_escape`, H1/H1b, the k-turn / planned-reverse / circle executor; `game/ai/manoeuvre*.gd`, `clothoid.gd`,
> `wall_contact.gd`; the face-at-rest path and C33.9's turn-in in `order_controller.gd`; `tests/test_manoeuvre*.gd`,
> `tests/test_kturn*.gd`, `tests/manoeuvre/**`, `tests/ai_scenarios/scenario_manoeuvre*.gd`, `mk/manoeuvre.mk`).
> **Granted (round 34):** `game/control/screen_playtest.gd`, ADDITIVE only: `real_mps` per hull-rest crew row (1B) and
> `--faced-shift-m` (2B); defaults unchanged, merge note. Still granted: gunnery's two aim-lead lines and the `_order_move`
> decline for wheeled turret hulls under turnhull (C31.8). **The C++ (C31.2):** send native each settled diff.
> **Model: FABLE** (CP-F has parked three times).

## The lead's direction

Round 28, call 2: **turn the whole vehicle to his drawn facing.** At round 33's close (2026-10-18) he chose to keep CP-F
parked and give it a fourth try now, on top of the herringbone fix. What he will notice: a War Rig, gang tank or IFV he
tells to face a direction ends with its hull pointing there and then sits still. With brains' B11b on top, one pushed off
its post goes back and faces his way again.

## Where things stand (main at the round-34 docs commit)

- **C33.9 (his scout report) did NOT ship (R33.38, R33.39).** He said ship attempt 1. Its whole suite with the switch
  ON then went red: the turn-in took every plain face and every `stop` swing, so a wheeled hull turning in place drove
  24.5 m (creep_bound), and a tracking scout rolled in a swept lane. Both narrowings tried at the close flipped judged
  lines on seeds 31–36 (`fc809b60a`: (c) worst in-reach cell −46 %, (d) max 13 reverse ticks). C31.1 had not been run
  before the judged series. Carry: `pair/c339-ship` `fc809b60a`, `lab/c339-turnin` `781801da0`, refs
  `references/round33/manoeuvre/c339-narrow/`. Native's stop hand-back (`pair/native-c339` `2f9ad0fb9`) covers any
  narrowing.
- **CP-F attempt 3 PARKED narrowly (R33.34):** turrets end 3–4° off the drawn facing (93–96 % within 15°) against
  60–100° today. It missed one line, gang crews still driving at 75 s on attack-move (+7 against 6.5). The trace (R33.35)
  showed those late movers came from the herringbone re-lay, which brains fixed on main (`7f27a479c`; seat jumps 107 v 2342).
- **The judge was part of every miss.** R33.21's series ran unpinned on a loaded box. hull-rest's "still" reads reported
  velocity, so a wedged hull counts as moving. Seeds 40 = 43 and 44 = 45 row for row. Your judge fixes (`cpf_judge.py`:
  jitter, `--wedged`, `--distinct`) and the CP-F code are on `round33/manoeuvre` `18e37ec76`, default OFF.
- **The k-turn arrival flicker (planner's s69):** a k-turn leg that crosses the 6 m arrival circle turns the order into a
  face nobody wanted. Your lab is `lab/cpf-arriveleg` `7e0953f9d`: one condition in `TankBrain._act`'s arrived branch, which
  is brains' code.

## Backlog (in order)

0. **M0 C33.9, the scout turn-in, done right (his report; he already said ship it).** Scope it to the case he reported:
   a scout's crew facing a live threat it can't yaw onto at rest. Never a plain face, a static spot or a `stop` with
   nothing to face. The order: (1) the WHOLE suite with the switch ON first (C31.1), and every test and scenario passes
   unchanged; (2) a fresh bar, filed before any number, on FRESH orbit seeds (not 11–36), keeping R33.24's lines; (3) the
   judged series on one machine; (4) the pair with native's hand-back. It ships ON when it passes. Out of reach, brains' scout
   try 2 decides whether the scout leaves (C34.5), so agree with brains which arm each judges on.
1. **M1 The ruler (C34.4 (1)).** Rebase `round33/manoeuvre`'s judge onto main (`git merge main` on a branch from it). Add 1B
   (`real_mps`) and 2B (`--faced-shift-m`) in screen_playtest. "Still" reads real velocity, wedged crews get their own line,
   the seed varies the geometry, and every hull-rest target is pinned. Then an A/A (OFF v OFF) on the new ruler on builder2,
   sized like planner's P1 (n ≥ 36 paired). The sd rows go to planner for `judging.md`. Ship the ruler alone (tests plus a
   check; it changes no game behaviour).
2. **M2 The flicker (C34.4 (2)).** Restate planner's s69 on current main. Agree the seam with brains through the orchestrator
   BEFORE code (brains owns `_act`'s arrived branch and `_order_move`'s held-post refusal; you own WHEN a faced finish runs,
   R33.2). A test that fails without the fix. If it's a bug fix, it ships alone with its check, before M3.
3. **M3 CP-F attempt 4 (C34.4 (3)).** On main (herringbone and M1/M2 in), a fresh bar filed before any number, on the new
   ruler. Fresh seeds, not 41/44/45/66/67. One machine. The pair = main + CP-F ON + native's mirrors only. Ships ON. **Tell
   brains the merge hash the day it lands** (B11b).
4. **M4 Help B11b:** answer brains' questions on the face step.
5. **Stretch:** a short clip of a War Rig told to face behind, before and after, for him (builder0 renders; builder2 has no
   display).

## How to verify

`make quick-remote` to iterate; `make native check` on the pair tree (switch ON) before any series, only for named hashes.
`make manoeuvre-hull-rest`, `manoeuvre-fights`, `manoeuvre-census`, `cpf_judge.py`, `test_manoeuvre_face_behind`,
`native-verify-scenarios`. Build squad-facing fixes on stages that form elements. Long remote runs under `systemd-run
--user`. Every number: commit, machine, workload, n, its row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; planner's `game/ai/planner/**`; brains' `tank_brain.gd` (beyond the
granted decline and an AGREED flicker seam), elements, `game/tactics/**`; native's `native/**`; `game/match/**`;
`game/control/**` beyond the 1B/2B grant; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
