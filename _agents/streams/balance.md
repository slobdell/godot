# Stream: balance (no army wins by charging just because of which faction it is; tactics decide)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/game_design.md` (*Summary of his answers*, *His
> call on R1-R3*, *His round-39 calls*), `_agents/workstreams.md` **Round 40** (C40.1, C40.4, C40.5, CP40.0). Round 39's doctrine brief is
> your predecessor: `streams/archive/round39/doctrine.md` (Status: *ROUND-40 CANDIDATE* faction table, *What round 40 should try first*).
> **You own** doctrine's round-39 paths: brains (`game/ai/**` and `game/tactics/**` outside settle's and manoeuvre's carve-outs:
> `tank_brain.gd`, `element_commander.gd`, `cpu_commander.gd`, `gunnery.gd`, doctrine tables), `tests/tactics/**`, `tests/test_tactics*.gd`,
> `tests/ai_scenarios/**` you add, `tests/rules/**`, `mk/tactics.mk`, `mk/rules.mk`, `tools/balance/**` (new), `mk/balance.mk` (new);
> the C39.4 grant (rule constants) carries over as C40.4. **GRANT C40.5:** `game/units/**` (unit stats, `army.gd`'s CPU army deal) behind
> a lead gate: you may READ it and build tooling against it; nothing in it changes on main until he answers (below). **Model:** Fable
> (the lingering problem: two rounds of tactics moved the blob line 0-6 points). **Machine:** builder2 for series (`make gcp-start`;
> Spot, re-queue on preemption), builder0 light for quick reads. **Seeds:** 8301-8340 + 8401-8440 (registered, C40.1); round 39's 6301-6340
> + 6401-6440 for the RE-READ of its own fights only.

## The lead's direction

R1-R3 (verbatim, 2026-10-23): "Regardless of whether or not this makes the game better right now, it's the correct direction to move in,
and we'll continue iterating to ensure that tactics and strategy win our as opposed to full frontal assault slug ests". Earlier (Q10):
"the problem is not the units, but the rules". Pillar: fixed StarCraft-style units, no pay-to-win. Memory: hard CPU, friendly units
equally smart; symmetric AI improvements ship without asking.

## Where things stand (main at launch: see HANDOFF)

Rules-ON base, 773412e49, builder2, 1600 fights: a blob wins 39 %, a turtle 36 %. By faction it is a matchup table, not a doctrine
problem: any blob v a gangs CPU wins 72 % (syndicate's blob 86 %); v a syndicate CPU 12 %; a gangs army loses charging (13 %) or
turtling (17 %). Blob kill ratio by blob faction: syndicate 2.62, law 0.98, condemned 0.83, gangs 0.15. Every doctrine lever tried
(D2/D2b/D2c/SPLIT, R1-R3, hull-down) moved the whole line 0-6 points and left the table's shape alone.

## Backlog (in order)

1. **B1 the per-unit tally (no build of the game).** Native adds per-unit kills/losses/damage dealt to GUARD_RESULT (**CP40.0**, native's N1,
   first). Re-run round 39's OFF-arm fights (773412e49's workload on main) with it and write, per faction: the dealt army (units, cost),
   and by unit type kills, losses, damage dealt per credit. Name which gangs units die without trading and what syndicate's army has
   that the others don't. Before CP40.0 lands: read `army.gd`/`units.gd` and tabulate each faction's dealt army by seed (no fights needed).
2. **B2 his decision page (lead gate).** One page, in player terms, one recommendation, e.g. "a gangs army loses whether it charges or
   holds: make gangs' tanks tougher, change what gangs fields, or keep gangs as the hard faction?". Give the orchestrator the text and the
   numbers; the orchestrator publishes it and brings back his answer. Don't wait: go on with 3.
3. **B3 a faction-aware CPU (symmetric, ships without asking if it passes).** Each faction plays to its army: per-faction ambush/hold
   tables in the doctrine (e.g. gangs holds and ambushes rather than trading in the open), on both sides' brains. Bar on 8301-8340 +
   8401-8440 (deciding: the gangs-CPU cells' blob win rate down by > 2 paired se; guards as Bar D3: blob kr, turtle line, kills and
   length per faction, the none line, perf).
4. **B4 the balance search harness (tooling, OFF).** `tools/balance/`: given his bounds on unit stats (e.g. +/-15 % hp, damage, cost),
   run N sims a candidate on builder2 and score the faction table's flatness. Build and dry-run it on two candidates; NO stat changes
   on main until he answers B2.
5. **Stretch:** after his answer, the change he picks behind a switch with its own bar.

**Open question for him (doctrine's, carried):** R1's full sight after a halt comes at ~3 s; his number was ~2 s, and ~2 s pulled a crew
out of cover in scenario_cover. Doctrine recommended keeping ~3 s. Until he answers, the dwell stays 2.0.

## How to verify

Every series: a full check of the named hash first, `guard.sh` on builder2 (GUARD_CHUNK=8), `guard.py --pair`; one full check + one
judged series per builder at a time. Smoke: `make skirmish SKIRMISH_FLAGS="..."` with a syndicate army blobbing a gangs CPU, then a
gangs army blobbing a syndicate CPU.

## Don't touch

settle's deploy/halt functions and PARKED_HOLD seam, manoeuvre's movement/traffic, orders' `game/control/**`, `native/**` (request),
`tests/ai_scenarios/guard_line.gd` (native's), `game/units/**` beyond C40.5, `tests/baselines/**`. Don't push.

## Waiting on the lead

B2 (faction balance); R1's timing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
