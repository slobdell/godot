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

### Round 2 run (army agent)

**Plan** (backlog order, smallest foundation first):
1. **Y1a model:** `ArmyCatalog` reads catalog v2 (C1) by shape; until checkpoint 1 it falls back to a stub
   in `game/garage/catalog_stub.gd` that matches C1 (scout, tank, IFV, artillery, Lancer). `ArmyDraft` replaces
   `Loadout` (squads of unit ids, ≤ 5 × 5, budget, problems). Saves write army JSON v2 (C2); v1 saves migrate
   on load (`tanks` → `units`, weapons/components dropped, a laser tank becomes a Lancer).
   A temporary adapter (`ArmyFormat.to_game_doctrine`) turns v2 into what today's loader reads, so FIGHT keeps
   working until rules' R1 lands; it disappears at checkpoint 1.
2. **Y1b screen:** unit grid (role, cost, blurb, good/weak vs, stat bars), squads with a budget bar and clear
   problems, a unit detail column (turntable, stats, paint, squad, remove). No weapon/component UI.
3. **Y2 progression:** `game/progression/` (`Progression`, profile JSON C8, award math, unlocks, migration),
   a match report adapter for C3 until rules' result fields land.
4. **Y3 loop:** army (tier + opponent) → skirmish → results screen → rematch / back to army, in-process.
5. **Y4** CPU at the player's tier, opponent composition on the results screen. **Y5** economy note.
   **Y6** presets per tier and army codes v2. Then the stretch items.

**Progress:** (newest last)

- Baseline `make check` green (294 tests) at `e4267ed`.
- **Y1 done: the army builder on catalog v2.** `ArmyCatalog` (reads C1 by shape; `ArmyCatalogStub` until
  checkpoint 1: scout 110, IFV 150, tank 200 as starters; artillery 220 at unlock tier 1; Lancer 190 at tier 2),
  `ArmyDraft` (replaces `Loadout`: buy, move, squads ≤ 5 × 5, budget, locked units, player-readable problems,
  saves army JSON v2), `ArmyFormat` (round-1 saves and `TS1` codes migrate: weapons/components dropped, a laser
  unit becomes a Lancer, unknown units removed with a note; plus the pre-checkpoint v2 → v1 adapter FIGHT uses),
  `ArmyCode` v2 (`TS2…`), role-based `ArmyPresets` (Anvil & Hammer, Scout Screen, Hunter-Killers, Siege Line,
  Lance & Shield; they fall back to unlocked roles and spend the budget), `GarageAdvice` composition hints
  ("Your Tanks are weak vs scouts and nothing here counters them: add an IFV") and a COMPARE table with
  good/weak vs. Screen: unit cards with role, weapon + mount, blurb, good/weak vs, stat bars, LOCKED state;
  squads show n/5 and points; the EQUIP column became UNIT (turntable via C6 `unit.<id>.*` slots, weapon,
  matchups, hints, squad, free paint). 39 army tests (`tests/test_army_draft.gd`, `tests/test_army_screen.gd`),
  including a preset fielded by a real `Match`. `make check` green (279 tests: loadout-only tests removed).
  Screenshots reviewed (desktop, 20:9, compare, fight handover).
  - Decision: opponents are CPU archetypes only (the hand-written doctrines don't fit a shared budget tier).
  - Decision: the Lancer counts as a laser migration target because round-1 lasers were the lead's favorite.
- **Y2 done: progression.** `game/progression/progression.gd` (C8): `user://profile.json` with credits, unlocked
  units, budget tier, wins/losses/draws; `BUDGET_TIERS` Scrapyard 800 → Pit 1,200 (400 cr) → Arena 1,700 (900) →
  Colosseum 2,400 (1,600) → Grand Circus 3,200 (2,500); units unlock by catalog `unlock_tier` (tier 1: 300 cr,
  tier 2: 600), independently of budget tiers, so the player chooses between a new unit and a bigger army.
  `credits_for` / `award`: win 100, draw 30, loss 10, +6 per enemy unit destroyed, +25% base per tier, nothing
  for matches under 60 s; a match key stops double pay. Migration clamps anything; an unreadable profile is moved
  to `.bad`, never wiped. `MatchReport` (C3 adapter): per-team units, left/lost, kills by unit type, best unit,
  preferring the rules stream's result fields when they exist. Screen: CREDITS button → UNLOCKS panel, locked
  cards show `UNLOCK n CR`, a TIER picker (unowned tiers disabled). 10 progression tests.
  - **Measured and fixed:** the first award numbers (loss 15, 20 s minimum) paid a thrown match 45 cr/min vs
    39 cr/min for a real 3-minute win; a test now holds "throwing is never faster than trying".
  - Fairness: the tier sets the budget for BOTH sides (`--budget` goes to the skirmish, which builds the CPU
    army at the same budget).
- **Y3 done: the match loop.** FIGHT → skirmish → (match ends, banner) → `ResultsScreen`: VICTORY/DEFEAT/DRAW,
  reason, duration, tier, opponent; credits earned with the breakdown, balance, and the next unlock to save for;
  both armies fielded/lost/kills; best unit; a counter lesson ("Their army was mostly Tanks. Scouts … are built
  to beat them."). REMATCH (same army, same seeded opponent, same tier) and ARMY restart in-process
  (`ArmyLoop` sets `Main.next_flags` and reloads the scene), so it behaves the same in a browser.
  `make army-loop-smoke` (now in `make check`, ~25 s): FIGHT → results → REMATCH → results → ARMY, no errors.
  `make army-loop-shots` (a real 70 s skirmish) reviewed at desktop and 20:9. 6 results/loop tests.
  - Shared-file edits: `game/main.gd` (+`static var next_flags`, 3 lines), `mk/core.mk` (`army-loop-smoke` in
    `check`).
  - Title → army: the title screen is art's file; see *Requests to other streams*.
- **Browser loop verified.** `make garage-web-smoke` gained a third page: `?garage&garage-autofight&army-loop-*`
  runs FIGHT → results → REMATCH → results → ARMY in Chrome (IndexedDB `user://`, in-process restarts);
  `web-army-loop.png` reviewed (back in the builder with the same army).
- **Y4 done: CPU opponents at the player's tier.** The tier budget goes to the skirmish for both armies (rules'
  `Army` builds the CPU army at that budget, a fresh seed each FIGHT, the same seed on REMATCH);
  `army-loop-smoke` asserts every CPU army's cost ≤ the tier budget (measured 800 ≤ 800). The results screen shows
  the opponent's composition, its losses, and a counter lesson naming the units built to beat what they fielded
  (locked ones marked). Decision: CPU armies may field units the player hasn't unlocked (they're sidegrades, and
  meeting a unit first is how players learn they want it).
  - Fixed: my stub had the scout good vs artillery and Lancer only; game_design.md also has tanks weak vs scouts,
    so starters had no tank counter. The stub is now scout > tank > IFV > scout.
- **Y5 done: economy note** in `_agents/balance.md` "Economy": award table, tier and unlock prices, and
  `make economy-sim` (400 simulated players per win rate using the real `Progression` numbers): at 50% wins the
  first unlock comes in ~5 matches, every unit type in ~17 matches (0.8 h), everything in ~55 matches (3.7 h);
  35% → 4.6 h, 65% → 3.1 h.
- **Y6 done: presets per tier and codes v2.** Presets carry a tier and adapt to unlocks (Y1); the PRESETS menu now
  says what a preset is built around that you haven't unlocked ("Siege Line (needs Artillery)"). Codes are `TS2`
  (Y1), round-1 `TS1` codes still import.
- **Stretch: challenge missions done.** `game/garage/challenges.gd`: five fixed-army missions, each teaching one
  counter from game_design.md's table: Scout Hunt (IFVs beat scouts), Turret Lag (scouts beat tanks), Hold the
  Front (tanks beat IFVs), Spot for the Guns (artillery needs spotters), Rush the Battery (scouts beat artillery).
  Armies are written by role, so they follow the catalog; opponents move by directive (no formation, trip-up #53).
  CHALLENGES button under the unit cards → panel → PLAY; the results screen shows the challenge's lesson; the first
  win pays 150 credits once (`completed_challenges` in the profile), replays pay nothing (no farming a solved
  puzzle). `--challenge=ID`; `army-loop-smoke` also runs Scout Hunt headless. 3 challenge tests.
  - Overlays (compare, share, unlocks, challenges) are now opaque over a dimming scrim (tap it to close): the
    theme's translucent panel color made overlay text collide with the columns behind.
