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
- **Stretch: matchup view done.** COMPARE now ends with a MATCHUPS grid (your unit vs theirs): "beats" / "loses" /
  "even" from design intent today, and win rates (≥ 60% green, ≤ 40% red) as soon as rules publishes a measured
  matrix at `res://game/units/matchups.json` (`{"win_rate": {unit: {opponent: 0..1}}}`, see Requests). Checked at
  1920×1080 and 1200×540. 1 test.

### Report (2026-09-15, end of run)

**Done:** the whole backlog (Y1–Y6) and both stretch items. `make check` passes on the last commit (299 tests +
`army-loop-smoke`); `make garage-web-smoke` (browser loop), `make garage-e2e`, and `make economy-sim` pass;
`make web-smoke` passes; screenshots reviewed: builder at 1920×1080 / 1800×810 / 1280×720 (browser too), compare (desktop and 1200×540), unlocks, challenges,
FIGHT handover, results at desktop and 20:9, browser loop. Sim baseline unchanged (`e5cf33921713b657`).

**Decisions** (each reversible):
- The army builder keeps the path `game/garage/` and class `GarageScreen`/`GarageMode`; players see "ARMY".
  `Loadout`/`GarageCatalog` are gone (`ArmyDraft`/`ArmyCatalog`).
- Until checkpoint 1: `ArmyCatalogStub` (C1 shape) and `ArmyFormat.to_game_doctrine` (v2 → v1 stand-ins, each no
  dearer in v1 points) keep FIGHT working. Both switch off by themselves once `Units.PROFILES` is v2.
- Tier 0 is 800 (4–5 units a side: small first fights); tiers go to 3,200 (~21 units, the C2 cap is 25).
- Units unlock independently of budget tiers (a real choice); CPU opponents may field units the player hasn't
  unlocked (sidegrades, and meeting a unit is how you learn to want it).
- Match pay: loss 10 + 6 per kill (a thrown match never out-earns trying); nothing under 60 s; one award per match.
- Opponents in the builder are CPU archetypes only; hand-written doctrines don't fit a shared budget.
- REMATCH = same saved army, same seeded opponent, same tier; restarts are in-process scene reloads.
- Challenge rewards pay once; challenge matches pay no match credits (no farming solved puzzles).
- Army saves add `"verb": "hold"` per squad and a top-level `"garage": {schema: 2, budget, cost, tier}`.
- Profile JSON (C8) gained additive keys: `draws`, `last_award`, `completed_challenges`.

**Questions for the lead:**
1. **How long should unlocking take?** Today ~3.7 h at a 50% win rate (everything), ~1 h for every unit type
   (balance.md "Economy"). I chose short on purpose (unlocks are options, not power). Longer = raise tier prices.
2. **Tier names** (Scrapyard, Pit, Arena, Colosseum, Grand Circus): keep, or name them yourself?
3. Should challenge missions be required before ranked/online play (a tutorial path), or stay optional?

**Requests to other streams:**
- *Rules (checkpoint 1):* (a) keep accepting a squad `"verb": "hold"` and ignoring the top-level `"garage"` object
  in army JSON v2; (b) `unlock_tier` values: my stub assumes scout/IFV/tank = 0, artillery = 1, Lancer = 2;
  (c) C3 fields in `Match.result()`: `MatchReport` reads `units_left`/`units_lost`/`kills` as `{green, rust}` if
  present, else counts them; a `kills_by_unit` in the same shape would replace my recorder; (d) R7: please also
  write the matrix as `res://game/units/matchups.json` `{"win_rate": {unit: {opponent: 0..1}}}` so COMPARE shows
  measured rates; (e) `game_design.md` has tanks weak vs scouts, so scout `good_vs` should include `tank`.
- *Rules/merge:* when R1 touches `game/garage/` or `tests/test_garage_*` to keep them compiling, those files are
  replaced here (`test_garage_*` → `test_army_*`); at the merge take the army stream's side, then delete
  `ArmyCatalogStub` and the v1 branch of `ArmyFormat.to_game_doctrine`.
- *Art:* (a) **title screen → ARMY**: add `["ARMY", "garage", "Build an army, then fight"]` first in
  `title_screen.gd` `MENU` (Y3's "title → army"; I didn't edit your file); (b) the builder, results screen, and
  overlays read `GameTheme.ui` `garage_bg`, `garage_panel`, `garage_text_dim`, `friendly`, `enemy`, `commander`; a
  CyberFrame pass would be welcome; (c) unit cards and results would love per-unit icons (C6 `unit.<id>.*`).
- *Command:* (a) an in-match "surrender / back to army" button would let a player leave a lost fight
  (the loop pays nothing under 60 s, so it can't be abused); (b) `GarageSettings.MATCH_TIPS` now says "Tap a
  squad, then tap the ground to send it there." (your round-2 grammar); tell me if the words change.
- *Orchestrator:* C8 row in workstreams.md: add the additive profile keys above; verification.md row 6h could list
  `army-loop-smoke`.

**Shared-file edits:** `game/main.gd` (+`static var next_flags` and 2 lines in `_ready`), `mk/core.mk`
(`army-loop-smoke` added to `check`), `_agents/balance.md` (new "Economy" section at the end).

**Known issues:**
- Challenge missions aren't balance-checked yet: until R2's counter mechanics land, stand-ins (an IFV fights as
  a v1 scout) make the lessons untrue in play. Re-run them after checkpoint 1 (`make garage ...` → CHALLENGES,
  or `--challenge=ID`).
- A player can reach a tier and then open an old army that's over its budget: it shows "Over budget by N" (not
  auto-trimmed).
- Tips restart in `--garage-scratch` runs (in-memory settings), by design.
- Headless loop smoke uses 6 s matches, so it checks flow, not credit amounts (unit tests cover the math).

**What to playtest:**
- `make garage`: a new profile opens at Scrapyard (800) with Anvil & Hammer. Tap a unit chip (matchups + hints),
  PRESETS, COMPARE (scroll to MATCHUPS), CREDITS → UNLOCKS, CHALLENGES → Scout Hunt, then FIGHT a CPU army. When
  it ends: the results screen → REMATCH → ARMY. Your real profile is `user://profile.json` in this checkout's user dir.
- Give yourself credits to try unlocks without touching your profile:
  `.tools/godot-4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --path . -- --garage --garage-scratch --credits=2000`.
- Browser: `make garage-web-smoke`, or `make serve-web` then `http://localhost:8060/?garage`.
- `make economy-sim`, `make army-loop-shots` (two 76 s windowed runs), `make garage-shots`.

**Next steps:** merge main at checkpoint 1 and switch to the real catalog (delete the stub and adapter); play each
challenge and tune the opponents so the lesson holds; re-run `make economy-sim` when units or costs change; add
the ARMY entry to the title (art) and a leave-match button (command).
