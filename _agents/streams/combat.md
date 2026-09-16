# Stream: combat (suppression, faction rosters, scale)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 4 direction*: suppression, army size and factions; *Factions*), [../workstreams.md](../workstreams.md)
> (**L2 and L3 are yours and are CP2**), [../balance.md](../balance.md) and [../determinism.md](../determinism.md).
> You own `game/units/`, `game/combat/` except `impact.gd`, `game/match/`, `game/tank/`, `game/arena/` + `arenas/`,
> `tools/{match_series,matchup_matrix,make_arenas,combat_duel,matchup_search}.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, `_agents/balance.md`. Round 3: [archive/round3/combat.md](archive/round3/combat.md).

## The lead's direction (2026-09-16)

> *"This game should have real concepts of suppressive fire and effective fire (i.e. vehicles make decisions to avoid
> walking into a wall of bullets that will kill them, and opposing forces could concentrate their fire power to create
> those suppressive fire effects or cut off an avenue) … tanks would probably want to provide protective cover for
> weaker units … I basically want a lot of units but I don't want to stress the performance of the game … a baseline of
> 30 units per side … different factions should have different unit sizes based on the effectiveness of each unit (i.e.
> the gang is diluted with cheaper units, so it should be a bigger swarm, the condemned have more expensive and smaller
> unit counts from there, then the law has more expensive and smaller unit counts from there, and the syndicate would
> have the fewest number of units)."*
>
> And on balance: *"it's also probably not worth trying to balance anything out substantively yet"*, because doctrine
> will change every number. Measure, keep it sane, don't chase perfection.

## Where things stand (round 3)

Tank shells (320 damage, 5 s reload, 75 m/s), 25 mm bursts, machine-gun streams, weak spots, armor by face, wheels with
turning circles and multi-point turns, artillery deploy, friendly fire, arenas as data with hazards, K2 weapon events
and `incoming_projectiles`, K3 locomotion and `TankMotion.predict`, the matchup matrix (8 of 12 counters hold), the
control point on by default. 15 faction vehicles exist as **art only** (`game/theme/factions/`, K4 slots).

## Backlog (in order)

**X1. L2 suppression and L3 roster schema (CP2).** Skeleton first, with the sim baseline updated once, on purpose:
- **Suppression:** `Tank.suppression` (0–1, decays), raised by near-misses and by rounds passing close; above a
  threshold a unit is `pinned` (accuracy penalty, and the brains will avoid it). `Match.threat_field(team)` (a cheap
  grid of incoming-fire density) and `Match.is_beaten_zone(from, to)`. K2 events gain `suppression_applied`.
- **Rosters:** `Units.PROFILES` entries carry `faction`; `Units.roster(faction)`; `--green-faction=`/`--rust-faction=`
  on the match runner; `Army` builds a faction army to a budget. The Condemned keep today's stats.
Tests for every field. **Announce CP2 as soon as it's green.**

**X2. Suppression that changes decisions.** Tune it so a machine gun's value is volume, not damage: a stream across a
lane should make crossing it a bad idea, concentrated fire should pin, and pinning should be worth doing. Work with ai
(they consume `threat_field`) and doctrine (support-by-fire drills). Measure: time to cross a suppressed lane, hit rate
while pinned, and whether "pin then flank" beats "everyone shoots" in a seeded series.

**X3. Heavies protect the fragile.** Give the mechanics that make interposing worthwhile: hull size and line of fire
already block shots; consider armor facing rules for taking hits meant for a neighbor. Don't invent a "guard" buff:
make position do the work, and measure that a tank in front of a Lancer actually saves it.

**X4. Faction rosters (L3).** Three new rosters on the existing art (`game/theme/factions/`), each with its own costs,
stats and feel:
- **Road gangs:** cheapest, fastest, most numerous; light armor; short range; the swarm.
- **The Condemned:** today's roster, the mid-point (~30 units a side at the baseline budget).
- **The Law:** fewer, tougher, disciplined; suppression tools (their special is the sonic emitter).
- **The Syndicate:** fewest, most expensive, best per unit; energy weapons; the Lancer is their special.
The lead's baseline is ~30 a side for the mid faction, and the counts fall out of cost and effectiveness, not fixed
numbers. Fill `good_vs`/`weak_vs` only where the mechanics really deliver it (game_design.md's ruling; the
`scout > lancer` claim is still owed a mechanic or removal).

**X5. Scale.** With ai's cost work, make 30 a side (and more for the gangs) actually run: spawn zones and arena sizes
that fit ~60–90 vehicles, match lengths that stay fun, and the sim cost per tick measured at 25 / 40 / 60 / 100 a side
(report the numbers; ai owns the brain cost, you own the simulation's).

**X6. Re-measure, don't over-tune.** Re-run the matchup matrix and a faction-versus-faction series (each faction at the
same budget, both bases) after doctrine lands, and write what you see in balance.md. Fix only what's broken
(a unit that wins everything, a faction that can't win); leave fine balance for a later round.

- **Stretch:** wrecks as cover (the husk prop exists); arena layouts sized for bigger armies.

## How to verify

`make remote T=check` with the sim baseline updated on purpose and the reason recorded; unit tests per mechanic;
`make duel` timelines; seeded series on builder0; screenshots of a 30-a-side fight **looked at**.

## Don't touch

Elements, formations and drills (doctrine), brains (ai), the camera and HUD (control), audio (audio), Meshy art
(no stream this round; 88 credits left).

## Status

- 2026-09-16: brief written for round 4. Nothing started.
