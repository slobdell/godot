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

**Report (2026-10-23 ~21:45 PDT, in progress).**

**Plan (ordered; reason):** D5 first (builder0 light, no wait) -> D2 read + bar -> D3 + D2's arm in ONE powered series on
builder2 (one shared OFF arm saves 1600 fights) -> D1 when native's CP39.0 lands (it doesn't gate the series: D3's seeds are
fresh, so its OFF arm is our own run on them, not CP39.0's file) -> D4 if budget -> stretch.

**D5 DONE (36b3adb14).** builder0 light, the wall duel traced tick by tick (906557c06 + probe, seeds 1-4, 45 s, sight OFF v ON):
- R1 does not break the loop. Seed 1: the same option/why sequence in both arms to 18 s (bait 0.1 s, duck 1.4, shot 1.5,
  reload in cover, "waiting for its reload" 6.9-15.9 s, ADVANCE, peek, shot ~18 s, duck). After the first shot the crew sits
  ~9 s behind the wall because the gun is laid on its peek spot and loaded: round 18's B1 no_loaded_peek, by design.
- The old bar (2 returns in 20 s) was fragile before R1: with sight OFF it held on seeds 1 and 3 only, and seed 1's second
  return was a 0.6 s flicker while backing in (19.4-20.0 s). With sight ON, 1 return on every seed at 25 s.
- Over 45 s: sight ON returns 2 on all four seeds, hidden 86-89 %, shots 3; sight OFF returns 1-4, hidden 62-66 % (it drifts
  into the open after ~35 s), shots 5.
- **Decided: the scenario's window changes, not the loop.** fights_from_cover now runs with R1 ON (the pin is gone), measured
  over 40 s (5-45 s), the same bars (hidden >= 50 %, shots >= half its reload allows in 20 s, returns >= 2). builder0 light:
  4 passed / 0 failed, hidden 86 %, shots 3, returns 2.
- scout_suppress::test_target_crossing PROMOTED: builder0 light 4/0, crossing on_point 0.60 (bar 0.50), first 1.0 s, n=3.

**D2 his numbers v the constants (read of 906557c06's code):**
- Moving fire: spread x(1 + RULES_MOVING_SPREAD_FACTOR x speed fraction) = **4.0x at full speed** (3.0; OFF was 1.5 = 2.5x).
  His number was ~4x at full speed (game_design.md Q2: "MOVING_SPREAD_FACTOR 1.5 -> ~3.0"). **Matches.**
- Suppression: throttle capped at 1 - PIN_SLOW_MAX x suppression, 0.4 = **up to 40 % slower, never stops**. **Matches.**
- Sight: MOVING 0.85, HALTED 1.10. **Matches.** **Timing short:** the factor only starts rising after HALT_DWELL_SECONDS (2.0)
  halted, then blends at 0.25/s, so a crew that stops after driving sees **85 % for its first 2 s and 110 % at ~3 s** (his
  "stopped ~2 s ~110 %"). HALT_DWELL_SECONDS 2.0 -> 1.0 keeps the blend (the edge never jumps) and reaches 110 % at 2.0 s;
  a stop under 1 s still changes nothing. SIGHT_BLEND_PER_SECOND alone (granted) can't get there without a near-jump edge
  (1.0/s gives 2.25 s and a 0.25 s drop). **Needs HALT_DWELL_SECONDS added to the C39.4 grant** (requested; constants only).

**Bar D2s (FILED 2026-10-23 before any number): R1's dwell at his number.** Change: Tank.HALT_DWELL_SECONDS 2.0 -> 1.0 (its
own tree, the D3 tree + that one constant; its own full check). Since the change only brings a constant to his stated
number (C39.4), it ships unless it breaks something; the bar is guards only:
- Workload: D3's (below), paired with D3's OFF arm.
- G0 (deciding for a ship): the blob's win rate NOT UP by > 2 paired se (McNemar p not < 0.05 in its favour).
- G1: turtle win rate not up by > 2 paired se; G2/G2t: kills a fight and median length per faction within 2 paired se on
  both lines (a faction outside is named); G3: none line caps <= OFF + 2, median <= OFF x 1.2; G4: perf unchanged (one
  constant). Reported, not gating: blob win rate down (the direction it should lean).

**Bar D3 (FILED 2026-10-23 before any number; D2c's shape, powered).** Change: `--cpu-defend --cpu-defend-split` ON v OFF,
rules ON (the default), one tree (this branch, after its full check). Workload: **seeds 6301-6340 + 6401-6440** (80 seeds,
fresh, C39.1 registry) x 5 maps x both sides x blob/turtle = **1600 fights an arm**; none line (CPU v CPU) on 6301-6340
(400 fights an arm). builder2, `guard.sh` GUARD_CHUNK=8, `guard.py --pair OFF ON`.
- **Deciding:** blob win rate DOWN by > 2 paired se AND McNemar p < 0.05.
- Second line: blob kill ratio not UP by > 2 paired se. G1 turtle win rate not UP > 2 se, median length not up > 2 se.
- G2 / G2t: kills a fight and median length per faction within 2 paired se on both lines; turtle-line kills a fight within
  2 paired se. G3: none line caps ON <= OFF + 2, median ON <= OFF x 1.2.
- Lab guard (turtle line, hold_fire_probe, builder0 light, 2601-2602, 20 fights an arm): CPU task verb `hold` <= OFF + 10 pts.
- G4 perf: commander-only code, OFF path unchanged; G4 judged only if it passes. A pass ships ON (symmetric).
- Sizing check (lesson R35): D2c's paired se was 3.8 points at 160 blob fights; at 800 it is ~1.7, so a 4-point effect is
  ~2.3 se: reachable, not certain.

**Questions for the lead:** none.

**Requests:** orchestrator: add `Tank.HALT_DWELL_SECONDS` to C39.4's grant (D2s); builder2 slot for D3 + D2s after native's
CP39.0 (~19 h at J14: 3 arms x 1600 + none 3 x 400).

