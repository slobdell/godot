# Stream: combat (make the fight a fight, not two masses)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 5 direction*, *Units*, *Factions*), [../workstreams.md](../workstreams.md) (you consume arena's M2 and render's
> M1), [../balance.md](../balance.md), [../doctrine.md](../doctrine.md) and your round-4 report
> [archive/round4/combat.md](archive/round4/combat.md). You own `game/units/`, `game/combat/`, `game/match/`,
> `game/tank/`, `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, `_agents/balance.md`.

## The lead's direction (2026-09-17)

> *"right now, I can't tell if perhaps the vehicles have too much range, but when I play the game now it's just these 2
> masses shooting at each other."*

That's the whole brief in one sentence: **if both armies can hurt each other from where they start, there is no
maneuver, no flanking, no reason for cover, and doctrine has nothing to decide.** Everything else here is secondary.

## Where things stand

- Round 4 landed suppression, three playable factions, heavies shielding the fragile, and a 30–58% cheaper simulation.
- **Ranges were never re-tuned for 30 a side on a 240 m map.** A tank's shell reaches 70 m, a Lancer 90 m, artillery
  160 m; with 30 vehicles a side the front is wide and everything is in range of everything at contact.
- **The road gangs win 23%** (Condemned 70%, Law 63%, Syndicate 47%). Two real defects were fixed without moving it.
- The Lancer role sits in both the Condemned and the Syndicate; the lead may want one of them to lose it.
- ai reports two behaviour gates that are partly yours: SUPPRESS is unreachable in a duel because the "killing this is
  slow going" test reads a matchup table the champion runs without, and a pinned enemy doesn't pull units out of cover.

## Backlog (in order)

**X1. Make range and sight produce maneuver.** Measure first: in a 30-a-side match, how far apart do the armies stop,
how much of the match is spent in one static exchange, and what fraction of shots are taken from inside cover? Then
tune the levers — weapon ranges, sight radii, accuracy at range versus moving, time-to-kill, and (with arena) the
distances their maps create — until the fight has phases: approach, contact, maneuver, decision. **Target to state in
balance.md:** a majority of kills come from the flank or rear, and the armies' centre of mass moves during the fight.

**X2. Cover has to be worth using.** With arena's new layouts (M2), check that hard cover blocks shots, that a unit
behind it is meaningfully safer, and that crossing open ground is a decision. If suppression plus cover doesn't change
where units die, say so with numbers and fix the mechanic.

**X3. The gangs at 23%.** Re-run `make faction-matrix SEEDS=5 TIME=150` on today's `main` (suppression, drills and
avoidance all landed after those numbers), then fix what the data shows. Swarms should trade numbers for reach: cheap,
fast, lethal up close, punished at range. If the counter to a swarm is "stand still and shoot", the swarm has no game.

**X4. The duplicated Lancer.** Decide with evidence whether the Condemned or the Syndicate keeps it (or what replaces
it), and write the reasoning in balance.md.

**X5. Behaviour gates that are really rules** (with ai): give brains a matchup-free way to know "I can't kill this
quickly" (penetration against armour) so SUPPRESS is reachable, and make being pinned actually worth exploiting.

**X6. Re-measure and write it down.** The matchup matrix, a faction-versus-faction series and the engagement-range
numbers from X1, after arena's maps land. balance.md gets the story, not just tables.

- **Stretch:** wrecks as cover (the prop exists); a ram or boost if the driving wants it (propose first).

## How to verify

`make remote T=check` with the sim baseline updated on purpose; `make duel` timelines; seeded series and the matrix on
builder0; and **watch a 30-a-side match** (`make skirmish` or `make cinematic`) and describe its phases in Status.

## Don't touch

Arena layouts (arena; request shapes you need), vehicle art and effects (render), brains (ai; request changes), UI and
camera (control), audio (audio).

## Status

- 2026-09-17: brief written for round 5. Nothing started.
