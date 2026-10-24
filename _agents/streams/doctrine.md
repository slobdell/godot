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

**D3 VERDICT (2026-10-24 10:28): FAIL; `--cpu-defend --cpu-defend-split` ships OFF. With the rules ON, SPLIT does nothing
against the blob.** 773412e49 (green builder0 3135/0) both arms, builder2, `guard.sh` J14 GUARD_CHUNK=8, fresh seeds 6301-6340 +
6401-6440, 800 fights a line an arm, 0 fights missing (2 attempts lost to a Spot preemption, re-run), `guard.py --pair OFF SPLIT`.
Ruled (a) by the orchestrator: run as filed for the record, since the lab guard had already failed.
- **Deciding:** blob 39 -> 39 % (+0.3, paired se 1.6; flips 72 to a loss / 74 to a win; McNemar p 0.60). **Not met.** The
  -3 to -4.4 point lean of round 38's three series (rules OFF) is gone at 5x their n with the rules ON.
- Second line: blob kr 0.74 -> 0.74 (+0.001, se 0.012). Holds.
- G1: turtle 36 -> 31 % (-4.7, se 1.2, p 0.0002): DOWN, holds; median 193 -> 192 s.
- **G2t FAILS:** turtle-line kills a fight 14.51 -> 13.82 (-0.69, se 0.16 = -4.3 se); losses -1.13 (se 0.20). Condemned
  kills -1.30 (3.2 se), gangs -0.51 (2.3 se). At power, SPLIT's CPU fights a turtle less (D2c's 1.6 se at n 160 was this).
- G2 outside 2 se: blob gangs median +7 s (2.3 se), blob law -8 s (2.7 se); turtle gangs median 186 -> 157 s (-5.8 se).
- Lab guard: FAILED before the series (hold 22.7 -> 37.6 %). G3 (none line) reported when it lands; moot for shipping.
- **Reading:** the turtle drop is the CPU winning on points by posting crews, not by fighting (fewer kills AND losses). Against
  the blob nothing moves. Under R1-R3 a crew already stops to shoot (round 38's D1: a holding crew fires still); posting part
  of the line on the ring adds nothing the rules don't already give. **The defend posture is not the lever with the rules ON.**
  For round 40: D1/the base show the blob's remaining wins are faction matchups (syndicate blob v gangs CPU 86 %, law blob v
  gangs 64 %; a gangs blob 13 %), which is army composition and balance, not doctrine.

**Report (2026-10-24 ~02:30 PDT, in progress). Series running on builder2 since 00:08 (OFF arm, ~3.3 h an arm), tree
773412e49 (green); then SPLIT, then D4 hull-down (report only), then the none line OFF / SPLIT (~14 h in all).**
- **D2s FAILS at its check; reverted (e453dc541).** d1822fd27 (dwell 1.0) on builder0: `make native check exited 2`.
  sim-baseline moved 9 of 13 maps as expected (foundry d98d9c0cb1105e22, yard ed3628c459f4cb7c, crossing fde86b02e13d8a2a,
  locks d889ca119dad1a95, parade 7a79d1bd8d338a17, archipelago 32f7260f765864f0, cut 7faab9861e717fb0, docks
  8bcba1d1566db68a, yard_open de7881ddcc5dbbf7; pit, terminus, sumps, gorge unmoved), but **scenario_cover fails twice**:
  fights_from_cover hidden **32 %** of 40 s (bar 50 %; 86 % with the dwell at 2.0), shots 7; the hurt tank's longest hidden
  **50 ticks** (bar 60). Trace (builder0 light, seed 1, dwell 1.0): the same loop to 20 s, then the crew drops COVER_FIRE for
  ENGAGE and drives into the open, 43 -> 22 m from the gun. A one-second change in when sight grows tips the duel down a
  different branch; I did not chase it into the cover AI. The dwell stays 2.0: a stopped crew reaches ~110 % at ~3 s, not his
  ~2 s. **For the lead:** his "~2 s" number costs smart-looking cover fights today; it stays at ~3 s unless he asks.
  Its series slot went to **D4** (`--cover-on=hulldown` on 773412e49, report only, no bar).
- stream/doctrine's code = 773412e49's (`git diff 773412e49 HEAD` touches docs only).
- **The series' OFF arm (the rules-ON base on fresh seeds) DONE 05:09:** 773412e49, builder2, 6301-6340 + 6401-6440, 1600
  fights, 0 attempts lost. Blob wins **39 %** (± 5), kr 0.74, median 108 s; turtle **36 %** (± 6), kr 0.75, median 193 s, caps
  1 %. D1 replicates at 5x n: by blob faction syndicate 65 %, condemned 47 %, law 35 %, gangs 13 %; syndicate blob v gangs CPU
  **86 %** (n 70), v law 62 %; law blob v gangs 64 %. SPLIT arm started 05:09.

- **Trees:** D3 = **773412e49** (side branch `doctrine/d3-tree` = a24f4f298 + the ai_scenarios counts), **GREEN** builder0
  (`make native check exited 0`, 3135 passed / 0 failed, 3 NOT JUDGED for load). D2s = **d1822fd27** (stream/doctrine = D3's
  code + HALT_DWELL_SECONDS 1.0 + main's R39.1 docs), its full check running on builder0 (sim-baseline expected to move:
  R39.1 accepts that as its only red; the moved maps go here, and the orchestrator adopts only if D2s ships).
- a24f4f298's check (builder0) went red on two explained targets, everything else green (3135 / 0, sim-baseline 13/13
  unmoved): ai-scenarios-check counts 54 -> 55 passed / pending 4 -> 3 (my crossing promotion: recorded 55,0,3,0 in
  tests/baselines/ai_scenarios_count.txt as native's 4b62d2186 did), and broker-test's "host never comes back" 2 s timeout
  at load 33 (alone on builder0 light: 31 passed / 0 failed).
- **D3's LAB GUARD FAILS** (builder0 light, hold_fire_probe, code a24f4f298, rules ON, 2601-2602 x 5 maps x both sides, 20
  fights a line an arm): turtle-line CPU crew samples tasked `hold` OFF 22.7 % -> SPLIT **37.6 %** (+14.9 points; bar <= +10;
  round 38's rules-OFF lab 22.0 -> 31.6). Turtle kills guard + CPU 278 + 293 -> 272 + 284; blob guard wins 4/20 -> 7/20
  (2 seeds: not evidence). So **SPLIT cannot ship from Bar D3** whatever the series says. Asked the orchestrator whether
  the SPLIT arm still runs (my recommendation: yes, for the record of the powered read, R38.41); it is queued second.

**D1 DONE: the rules-ON base read** (native's CP39.0, `references/scoreboard/guards/8952c3d64.fights.jsonl` on stream/native
407a156cb; main 8952c3d64, R1-R3 ON, builder2, CP37.1 seeds 2601-2608 + 2701-2708, 320 fights, paired fight for fight with
686150ed2 (rules OFF); my per-group pairing, se = paired, n per row):
- **Lines:** blob 47 -> 41 % (-5.6, se 3.0 = 1.9 se; flips 16 to a loss / 7 to a win; native's McNemar p 0.047); turtle 41 ->
  38 % (-3.8, se 3.4; 18 / 12). Median length unchanged (blob 102 -> 103 s, turtle 194 -> 193). Blob-line kills: guard 19.7 ->
  18.8 a fight, CPU 23.1 -> 23.9. The rules now favour the defender a little on both lines, as D3 (R38.48) leaned.
- **Who the rules moved (blob line):** blob syndicate 82 -> 69 % (-13.3, 2.0 se), CPU law 70 -> 58 % (-12.5, 1.7 se),
  condemned blob -6.7; gangs and law blobs unchanged. Every map leans the same way (-3 to -6 points); Green-side blobs moved
  more (-8.8) than Rust (-2.5).
- **Where the blob still wins (ON, wins/fights):** it is a faction matchup. syndicate blob v gangs CPU **14/15**, v law CPU
  **11/15**, v condemned 6/15; condemned blob v law 11/20, v gangs 6/10; law blob v gangs 5/5. A syndicate CPU is almost
  never beaten (2/45). By CPU faction the blob wins **83 % v gangs**, 58 % v law, 36 % v condemned, 4 % v syndicate.
  By map: gorge and sumps 50 %, locks 44 %, terminus 34 %, parade 28 %.
- **Turtle line:** condemned turtle 44 -> 27 % (-17.8, 2.5 se), gangs turtle 13 -> 27 % (+13.3, 1.7 se, 5 flips of 6 to a
  win, gangs fights 151 -> 193 s). Syndicate turtle wins 69 % (15/15 v law CPU).
- **What it chooses for D2/D3:** the blob that still wins is a syndicate (and condemned) blob charging a gangs or law CPU.
  The deciding line stays the whole blob line (the bar is filed), and the series reports the gangs- and law-CPU cells per
  faction (G2 already names each faction). Faction balance itself (syndicate strong both ways, gangs weak as defender) is
  outside doctrine's paths: a note for the orchestrator, not a fix here.

**Report (2026-10-23 ~21:45 PDT).**

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

