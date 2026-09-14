# Stream: Gameplay (make squad-vs-squad fun)

> Read [../workstreams.md](../workstreams.md), [../tank_brain.md](../tank_brain.md),
> [../tactical_map.md](../tactical_map.md), and [../squad_ai_design.md](../squad_ai_design.md).
> You own `game/match/`, `game/ai/`, `game/combat/` (except `impact.gd`), `game/tank/` logic,
> `game/arena/` layout, `doctrines/`, `game/ui/tactical_map.gd` behavior, and the offline/skirmish/
> match-runner modes.

## Where things stand

The lead, 2026-09-13: *"it's really not that fun to play yet."* After the first skirmish
the game gained elimination, 400 HP, shot spread, a doubled arena, and a tactical pause
(tactical_map.md "Iteration 2"). Measured pace now: first shot ~8 s, first kill ~32 s, and
coordinated doctrine beats uncoordinated 60% (T1 v2).

## Known problems (measured or observed)

- **Snowballing:** the losing side usually kills only ~1 tank; the first loss decides the match.
- **Front-armor slugfests:** 80%+ of hits land on front armor; flanking rarely completes.
- **Hurt tanks camp at base;** CPU-vs-CPU elimination often hits the time limit.
- **The flamethrower is strictly worse than the cannon** (6% / 0% win rates).
- **Few meaningful decisions after the opening orders;** elimination is the only objective.
- Readability: is it clear why a tank died or why a squad did something?

## Directions to evaluate (don't build them all; measure and playtest)

- **Objectives:** capture zones or a control point in the middle; gives reasons to move and to take risks.
- **Squad abilities on cooldowns** (a few per squad): smoke (blocks LOS), repair, sprint, "focus fire" mark. More decisions with few inputs.
- **Anti-snowball:** reinforcements by objective, diminishing focus fire, repair at base.
- **Weapon and hull trade-offs** that make the flamethrower (and future weapons) real choices.
- **Better CPU commander:** issue SquadCommands over time (the enemy uses the same tactical tools).

## How to work

- **Playtest with the lead** after each meaningful change; ask what they tried and what felt bad.
- **Measure:** match stats (`first_shot_seconds`, `first_kill_seconds`, loser kills, hits by face, idle guns) via `tools/match_series.py`; always with the swap-bases control; counterbalance team identity.
- **Record** the new determinism baseline hash in `workstreams.md` when you intentionally change the simulation.

## Don't touch

`game/theme/**`, `game/ui/hud.tscn` styling, `game/network/`, server/client modes (coordinate through the contracts).

## Status

- 2026-09-13: brief written. Nothing started on this branch.
