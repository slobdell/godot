# Stream: army (army builder, progression, the match loop)

> Read [../game_design.md](../game_design.md) ("Army, squads, budget" and "Progression"), [../vision.md](../vision.md)
> (no pay-to-win), and [../workstreams.md](../workstreams.md). The round-1 garage report is
> [archive/round1/garage.md](archive/round1/garage.md). You own `game/garage/` (keep the path; players see
> "Army"), `game/progression/` (new), `game/modes/garage_mode.gd`, new flow and results modes and screens, and `mk/garage.mk`.

## The lead's direction (2026-09-15)

> *"The player will have some set budget to spend on units per round, and I think the way the game can progress is
> that a player gets credits for winning matches, and so as they get better they'll be able to play with bigger
> budgets, more and better units to use, etc. … a player can have up to some finite numbers of squads (say 5).
> There will be a budget to spend on units before gameplay, the player will buy whatever units they want, and the
> player will divide those up into squads as the player sees fit."* And on money: *"we want a die-hard gamer's game"*.
> Nothing is ever sold for real money.

## Where things stand (round 1)

The garage is a touch-first army builder for **loadouts** (weapons per hardpoint, components, paint), with per-army
saves, army codes, presets, comparison tables, tips, and FIGHT → skirmish. Loadouts are gone in round 2, so much
of the equip UI goes; the squad and army mechanics, saving, codes, and flow stay.

## Backlog (in order)

**Y1. Army builder on catalog v2** (contracts C1, C2).
- Remove weapon, component, and hardpoint editing.
- A unit grid shows role, cost, a short blurb, and **what it's good and weak against**.
- Buy units and put them into up to 5 squads (tap, or drag), with a budget bar and clear problems ("Squad 3 is empty").
- Saves write army JSON v2.
- Until checkpoint 1, build against a stub catalog in your own paths that matches C1.

**Y2. Progression** (C8).
- A `user://profile.json` holds credits, unlocked units, budget tier, and win/loss.
- Award credits from the match result (C3): winning earns more; losing still earns a little.
- Unlock units and budget tiers with credits. Locked units show what unlocks them.
- **Fairness rule:** both sides fight at the same budget tier; unlocks add options, not power.
- Tests for award math, unlocks, and profile migration.

**Y3. The match loop:** title → army (choose tier and opponent) → skirmish → **results screen** (win/loss,
credits earned, units lost and killed, best unit) → rematch or back to army. It must work in the browser (IndexedDB
`user://`) and at phone aspect.

**Y4. CPU opponents at the player's tier:** use rules' `Army` archetypes on the new roster, at the same budget;
variety by seed; the opponent's composition is shown after the match (so players learn counters).

**Y5. Economy design note** in `_agents/balance.md` (a section you own): credits per win and loss, unlock costs, the
tier curve, and a simulated player's time-to-unlock. No grind walls, no pay shortcuts.

**Y6. Presets and army codes v2:** starter armies per tier that teach a composition idea; shareable codes on the
new format.

- **Stretch:** challenge missions (fixed armies against scripted opponents, each teaching one counter), and a
  matchup view built from rules' matrix.

## How to verify

`make check`, `make garage-smoke`, `make garage-web-smoke`, the army tests, and screenshots at desktop and phone aspect.
A full loop played from title to results to rematch (scripted smoke + screenshots).

## Don't touch

Unit stats and the army JSON parser (rules), squad behavior (ai), the in-match UI and camera (command), art
(art; use `GameTheme.ui` keys and the cyber widgets for styling, and request new looks).

## Status

- 2026-09-15: brief written for round 2. Nothing started.
