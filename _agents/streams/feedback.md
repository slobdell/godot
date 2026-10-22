# Stream: feedback (he can't miss the match ending; the support trucks read in a real fight)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 38** (C38.1) and `game_design.md` *his
> playtest note, mid-round* (round 37) and *his picks on feedback's directions page*. Your round-37 close notes:
> `streams/archive/round37/feedback.md`. **You own:** `game/ui/**`, `game/theme/**`, `game/audio/**`, `game/announcer/**`,
> `tests/feedback/**`, `tests/test_feedback*.gd`, new assets for your items. Presentation only: sim-baseline must not move.
> **Model:** Opus. **Machine:** builder0 checks; the laptop for looking (his test bed, Intel UHD 620).

## The lead's direction

His round-37 playtest: he kept ordering his last two artillery trucks after the match had ended on zone points (game_design.md, R37.27:
the match ended at 195.4 s; his later clicks still echoed "move"). His standing rules: concept choices on a tap-to-approve page before
anything final; he limits asset COUNT, not spend; announcer satire subtle, the caller authentic UFC hype.

What he will notice: when a match ends, he knows at once (who won, why), and clicks after the end don't pretend to give orders.

## Where things stand

- His picks are ON (hit C ring, pinned A, repair A, cone C), six sounds/lines live, `marks` OFF.
- The end screen exists (`game/ui/scoreboard_bug.gd` and the match result) but he missed it in a real game.
- Finding (round 37): the Resupply Tanker rarely gets to repair in real fights (3 s quiet rule); that is a RULES question for him, not
  a look: write it up for the orchestrator to ask, don't change the rule.

## Backlog (in order)

1. **F1 the end of a match:** read his recording (`build/recordings/2026-10-21T21-43-57-archipelago.jsonl`, the end at 195.4 s) and the
   current end flow; propose 2-3 end treatments (a clear banner + reason, the announcer's call, input that says "match over") on a
   directions page; the orchestrator relays; build his pick.
2. **F2 orders after the end:** a click after the match ends says so instead of echoing "move".
3. **F3 the Tanker question** written up in player terms with a recommendation (for the orchestrator to ask him).
4. **Stretch:** any rough edge in his picks seen in real fights at his laptop preset.

## How to verify

Tests; screenshots and clips LOOKED at on his laptop preset; perf on the laptop preset (`make control-timing`); `make skirmish` to the
end of a match.

## Don't touch

Simulation code, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

F1's page when it exists (the orchestrator relays).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
