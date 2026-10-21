# Stream: rules (stop to be strong: sight, accuracy and suppression follow motion)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 37** (C37.1, CP37.1,
> C37.2) and `_agents/game_design.md` *OPEN QUESTIONS for him before round 37* (his answers to 1, 2, 8, 11) and *Summary of his
> answers*. **You own:** `game/tank/tank.gd` (sight, suppression's effects, the drive speed cap), `game/match/match.gd`'s
> intel/spotting pass and `shot_spread` (+ `MOVING_SPREAD_FACTOR`), `game/ai/fire_lanes.gd`'s spread line, `game/combat/**` except
> cover's damage seam (C37.3), `tests/rules/**`, `tests/test_rules*.gd`, `mk/rules.mk`. **Grant:** in `game/ai/gunnery.gd` /
> `game/ai/order_controller.gd` the "stop before a long shot" choice, one guarded seam, merge note. C++ twins are native's (you
> declare, native writes; 0 mismatches before a series).
> **Model:** Opus. **Machine:** builder2 for series (shared queue with native and cover: say in Status when you start/finish);
> light runs on either builder.

## The lead's direction (2026-10-20 / 21, verbatim in game_design.md)

"the problem is not the units, but the rules of the game." On sight, his own reframe: **"isn't a much more coherent version of this
idea simply that a unit's vision shrinks a little when moving / expands a little when stopped?"** (he rejected hiding a parked enemy
inside a range the player was shown: "the cognitive disconnect"). On accuracy: **"yes, firing on the move should be a lot less
accurate"**. On suppression: slow, never stop, and show it ("ok yeah, let's go with your recommendation"). The guard (11): a blob
frontal assault should lose AND a pure turtle must not always win.

What he will notice: a squad that halts at a crossroads sees a column coming before the column sees it, and shoots first and
straighter; a blob charging and firing on the move mostly hits dirt beyond mid-range; a charge into heavy machine-gun fire bogs down.

## Where things stand

- **Sight:** `Tank.sight_radius` from `Units.stat(unit, "sight_radius")` (60–110 m); team vision = inside radius AND line of sight
  (`Match` intel pass ~1215–1290, `Perception.has_line_of_sight`); fog hides unseen enemies in 3D (`rts_controls._apply_fog_of_war`).
  X5 already scales sight with suppression (`SUPPRESSION_SIGHT_PENALTY` 0.4, the `_calm_sight` block ~1119–1134): R1 extends that
  block, not a new mechanism.
- **Spread:** `Match.shot_spread` = spread_deg x (1 + `MOVING_SPREAD_FACTOR` x moving + suppression term) x range term;
  `MOVING_SPREAD_FACTOR := 1.5` (2.5x at full speed). `fire_lanes.gd:94` repeats the formula. Native: `gun_native` / `combat_native`.
- **Suppression:** rise 0.6/s, recover 0.3/s; shrinks sight, slows hull turn 50 %, widens spread; **never slows driving**.
  Native: `tank_drive_native`.

## Backlog (in order)

1. **R1 own-motion sight.** Switch `--rules-sight` (OFF). Driving: ~85 % of the calm radius; stopped for ~2 s (a dwell; brief halts
   don't count): ~110 %; blend smoothly, never flicker; composes with the suppression penalty. Lab test first (two tanks, one parked,
   one approaching: the parked one spots first by the stated metres, both paths). Declare the twin to native.
2. **R2 moving spread.** Switch `--rules-spread` (OFF): `MOVING_SPREAD_FACTOR` -> ~3.0 (4x at full speed), still scaled by speed; the
   fire_lanes copy follows. First MEASURE (light, today's main): what share of a blob charge's damage comes from movers; if it is
   small, say so before building (question 3 then matters more). The AI part: crews stop before a long shot when the shot is worth
   it (the grant); a lab case shows a CPU tank halting to fire at 120 m. A fast unit that becomes useless gets its own lower
   penalty (a stabilised gun), never a softer rule for all; report it, don't decide it alone.
3. **R3 suppression slows.** Switch `--rules-pin-slow` (OFF): the drive speed cap scales down to ~60 % at full suppression, never 0;
   an ordered move still completes. Feedback shows it (C37.6); you expose `Tank.pin_slow()` (0..1) for them.
4. **Bars and series (after CP37.1 merges):** one bar per rule in workstreams *Bars (round 37)*, shape C37.2, sized from native's
   noise. Rules may be judged one at a time or as a package if you argue it in the bar; each keeps its switch either way.
5. **Stretch:** the "stabilised gun" exception if R2's series names a victim; R1's numbers re-tuned only on the guard lines.

## How to verify

Lab tests both paths; `make quick-remote`; one full check per named hash; series on builder2 against CP37.1's lines; every number
with commit, machine, workload, n. Smoke like a player: `make skirmish ARENA=terminus`, halt a squad at a crossroads, send the CPU
in; then charge a parked CPU squad across open ground.

## Don't touch

Cover's damage seam and paths, feedback's presentation, orders'/manoeuvre's movement code, `native/**`, `tests/baselines/**`.
Don't push.

## Waiting on the lead

Nothing (his answers are recorded). His playtest at the round's close is the subjective check.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
