# Stream: native (the guard lines, the C++ twins, the scoreboard)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/native.md`, `_agents/workstreams.md`
> **Round 37** (C37.1, CP37.1, C37.2, C37.3) and `game_design.md` *OPEN QUESTIONS for him before round 37* (answer 11, the guard).
> Your round-36 brief is `streams/archive/round36/native.md`. **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`,
> `references/scoreboard/**`, `tools/judge/**`, `tests/ai_scenarios/**` (for the guard lines and the scout_suppress promotion), the
> net-test scripts (N4), the test-hygiene grant (C36.5).
> **Model:** Opus. **Machine:** builder2 (shared series queue with rules and cover: say in Status when you start/finish).

## The lead's direction

The measure for every rule change this round (his answer 11): **a blob frontal assault should lose, AND a pure turtle must not
always win.** Native is C++ for core components long-term (memory: stage 1 ON 2026-10-12).

What he will notice: nothing alone; every rule he plays at the round's close was judged on these lines, and the native build stays
identical to the script.

## Where things stand

- The scoreboard (`tools/scoreboard/`, `references/scoreboard/README.md`): a row per main, a noise column from 2 seed blocks.
- Doctrines/archetypes exist (`game/units/army.gd`: an army IS a doctrine; `cpu:<archetype>`), and `tests/ai_scenarios/` runs scripted
  matchups; round 3/8's balance sweeps used them.
- `scenario_scout_suppress::test_target_behind` passes identically while marked PENDING (n=3, shots=101, every check since at least
  2026-10-20, switches either way; manoeuvre's logs): promote it.
- Net-test diagnostics (round 36's sweep): relay_host_up / broker-load / lobby-smoke wait 5 s for BROKER_LISTENING then fall through
  silently (a dead broker surfaces 30 s later as "host never opened a room"); combat-smoke under `-eu -o pipefail` exits on a client
  FAIL before the reap and the server-ERROR grep.
- Round 36 skipped the judging-table re-render (close step 5b).

## Backlog (in order)

1. **CP37.1 the guard lines.** Design note to the orchestrator first: how the BLOB side is ordered (every squad straight at the other
   side's held zones, at once) and the TURTLE side (every squad holds its own zones, never advances) WITHOUT new game code (doctrine,
   army JSON, or the match runner's orders); the TACTICS side is today's CPU at its normal doctrine; both factions, both ways. Then
   read today's main on builder2: win rate and kill ratio per line, n sized from two seed blocks' noise. This is the BASE every rules
   and cover bar quotes. Hand over a green hash; the orchestrator merges it alone.
2. **N2 the twins** for every rules/cover/manoeuvre pair (R1 sight, R2 spread, R3 pin-slow, K2 hull-down, M1): 0 mismatches before
   their series, in the same pair.
3. **N3 the scoreboard row** for every main the round ships, with both guard lines added as columns.
4. **N4 the net-test diagnostics** (above): fail loudly and keep the diagnostics.
5. **N5 promote** `scenario_scout_suppress::test_target_behind` (update `tests/baselines/ai_scenarios_count.txt` through the
   orchestrator).
6. **N6 the judging-table re-render** (orchestration.md close step 5b) with round 36's judged pairs.

## How to verify

Twins 0 mismatches; `make native check` per named hash; the guard lines' noise stated before any rule is judged on them; every number
with commit, machine, workload, n.

## Don't touch

Game GDScript outside your grants (rules', cover's, feedback's, orders', manoeuvre's paths), `tests/baselines/**` (ask). Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
