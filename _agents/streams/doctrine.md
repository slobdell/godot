# Stream: doctrine (tactics beat a charging blob, with his R1-R3 rules ON)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/game_design.md` (*OPEN QUESTIONS for him before
> round 37*, *Summary of his answers*, *His call on R1-R3*), `_agents/workstreams.md` **Round 39** (C39.0, C39.1, C39.4) and in
> *Rulings (round 38)*: R38.14, R38.29, R38.30, R38.41, R38.48, R38.55. Your round-38 brief: `streams/archive/round38/doctrine.md` (the
> design note *why DEFEND made the CPU passive*, Bar D2c). **You own:** brains (`game/ai/**`, `game/tactics/**` outside settle's and
> manoeuvre's carve-outs: `tank_brain.gd`, `element_commander.gd`, `cpu_commander.gd`, `gunnery.gd`, doctrine tables),
> `tests/tactics/**`, `tests/test_tactics*.gd`, `tests/ai_scenarios/**` you add, `tests/rules/**`, `mk/tactics.mk`, `mk/rules.mk`;
> GRANT (C39.4): `game/combat/rule_switches.gd` and the R1-R3 constants in `tank.gd` / `match.gd`. **Model:** Fable. **Machine:**
> builder2 (guard series), builder0 light for labs. **Seeds:** 6301-6340 + 6401-6440 (the powered series).

## The lead's direction

2026-10-20: a blob frontal assault wins too often, "one big slug fest". 2026-10-23, turning R1-R3 ON: "Regardless of whether or not
this makes the game better right now, it's the correct direction to move in, and we'll continue iterating to ensure that tactics and
strategy win our as opposed to full frontal assault slug ests". His pattern: rules that show on screen and need no new UI; nothing that
looks like the game cheating. Smart AI on both sides: symmetric improvements ship without asking.

## Where things stand

- **R1-R3 ON by default since R38.55** (sight, spread, pin_slow). D3 (R38.48, rules OFF base): they make blob fights a little longer and
  turtle fights shorter without moving who wins. K2 hull-down is OFF and stops ~1 round a fight.
- **The blob wins ~47 %, the turtle ~41 %** (native's row 686150ed2, rules OFF). Native's N1 files the rules-ON base first (CP39.0).
- **D2 / D2b / D2c FAILED** on the deciding line: blob -4.4 / -3.1 / -4.4 points, never 2 se (R38.41). D2c's SPLIT fixed the passivity
  (every guard held) and CLOSING undid SPLIT in the labs. A ~4-point effect needs ~4x the fights for 2 se.
- Lab reads on 2 seeds are not evidence (D2c's lab said 9 -> 4, the series 51 -> 47 %).

## Backlog (in order)

1. **D1 the rules-ON base (read only).** When native's CP39.0 row lands, read it against 686150ed2 per faction: who the rules now favour,
   fight lengths, and where the blob still wins (map, faction). Write it up; it chooses D2's target.
2. **D2 R1-R3 at his numbers (C39.4).** Check each constant against his answer (sight ~85 % driving / ~110 % stopped ~2 s; moving fire
   ~4x spread at full speed, today RULES_MOVING_SPREAD_FACTOR 3.0 on a base 1.5; suppression slows up to ~40 %). Where one is short of
   his number, file a bar to bring it there (deciding: blob down; guards as D2c's) and judge on the powered workload.
3. **D3 the powered SPLIT series (R38.41).** `--cpu-defend --cpu-defend-split` ON v OFF, on top of rules ON, fresh seeds 6301-6340 +
   6401-6440 (4x the fights), paired against CP39.0's base; D2c's bar shape (deciding blob down > 2 paired se AND McNemar p < 0.05; G1
   turtle not up; G2/G2t kills and length per faction; G3 none line; the lab guard; G4 perf). A pass ships ON (symmetric).
4. **D4 hull-down re-read with rules ON** (K2, `--hulldown`), on the same base, if the series budget allows. Report only unless a bar
   is filed first.
5. **D5 the peek-and-return loop under R1 (from R38.55's check).** With sight ON, scenario_cover's fights_from_cover went back to
   cover 1 time against its bar of 2, so R38.55 pinned sight OFF in that one scenario. Find out why: a stopped crew sees ~110 %
   only after ~2 s, so a short peek may be blind. Decide whether the loop or the scenario's bar should change, and unpin it.
   Also, scout_suppress::test_target_crossing (pending) passes with the rules ON; promote it if it holds.
6. **Stretch:** CPU low-cover seats when defending (gate: 2 se or cover_struck >= 8 a fight).

## How to verify

`make quick-remote`; one full check per named hash before every series (C31.1); `guard.sh` on builder2 (GUARD_CHUNK=8),
`guard.py --pair`. Playtest: `make skirmish SKIRMISH_FLAGS="--cpu-defend --cpu-defend-split"` (after C39.6) and play the blob into it.
`make doctrine-shots` needs the laptop's GPU.

## Don't touch

settle's, manoeuvre's and orders' paths; `game/match/**` and `game/tank/**` beyond the named constants; `native/**`;
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
