> **ARCHIVED (round 19; stream closed 2026-10-06).** This brief ran as stream `garage` in round 19; every item is merged to
> `main` (`HANDOFF.md` *ROUND 19* has the merge table; `main-checked` at the close = `635d9d9b`). The Status below is the
> worker's final report. Its worktree and branch are removed; evidence is under `streams/references/round19/`.

# Stream: garage (1000 credits a game; every vehicle has a price; squads however he likes, up to five; one simple screen in our theme, with a kit the rest of the game builds on)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 19 direction* (item 3) and
> *Army, squads, budget* / *Progression*, `_agents/balance.md` *Economy*, `_agents/art_direction.md`,
> `_agents/legibility.md`, `_agents/workstreams.md` *Round 19*, and the garage's history
> (`streams/archive/round1/garage.md`, `round2/army.md`, `round14/garage.md`, `round15/garage.md`). You own
> `game/garage/**`, `game/progression/**`, `game/units/units.gd` PRICES ONLY (C19.2), `game/ui/widgets/cyber_frame.gd`,
> `cyber_ui_theme.gd`, `cyber_style.gd`, `cyber_banner.gd`, `conductors.gd` (the kit; additive, C19.5),
> `game/ui/widgets/title/**`, `game/theme/game_theme.gd`'s `ui` palettes, `doctrines/player_*.json`,
> `tests/test_army*.gd`, `tests/test_units_catalog.gd`, `tests/garage/**`, `mk/garage.mk`, `_agents/ui_kit.md` (new),
> `_agents/balance.md` *Economy*.

## The lead's direction (2026-10-05, in chat; verbatim)

> *"the garage as it stands is not what I envision - if this is already meant to satisfy my intent then the UX is no
> good. The way I imagine this game is that each player is given 1000 credits per game (and we might change this in the
> future so that as players advance they get more credits or something). Each vehicle has a cost, and they allocate so
> many credits to buy the units they want, and the player should be able to group squads however they want (we have max
> 5 I think?) That means that squads can get created with a mix of vehicles. This UX should be relatively simple, the
> beauty of this game is its simplicity. In the UI in the garage we also want chamfered borders and stuff, and I think
> we have enough content now where we have a theme to build off of."*

His standing words it joins: *"a budget, buy any mix of units, and divide them into up to 5 squads"* (2026-09-15);
pillar 1, no money in the loop; *"matches are fought at a shared budget tier"* (fairness); the humour and
legibility rules in `game_design.md`.

## Where things stand (read at `93ec68b4` by the orchestrator; `make garage` not played by him this round)

- **The rules already allow what he asks** (`game/garage/army_draft.gd`: `MAX_SQUADS = 5`, `MAX_SQUAD_SIZE = 5`,
  mixed squads never refused; `army_format.gd` v2; `army_code.gd` TS2 codes). **Almost everything around them does
  not:**
  - The budget is a bought TIER (800 / 1200 / 1700 / 2400 / 3200: `game/progression/progression.gd:19-25`), paid
    with a persistent "credits" currency earned by winning (`AWARD`, `:34`); `Units.DEFAULT_BUDGET = 1000` is
    overridden by `Progression.catalog_for` (`:158`), so a new player sees 800.
  - Three of the six Condemned units are LOCKED behind that currency (`UNIT_UNLOCK_CREDITS` `:28`; cards say
    "UNLOCK n CR"; `ArmyDraft.unit_problem` refuses them; the results screen's `next_goal` sells the next unlock).
  - Only the Condemned are offered (`army_catalog.gd:66-75`); `make skirmish` picks any faction.
  - The screen (`garage_screen.gd`, 1293 lines): three columns, a name field, PRESETS, LOAD, SAVE, DELETE, SHARE, a
    credits button, a tip bar, TIER and ENEMY menus, COMPARE / CHALLENGES / UNLOCKS / SHARE overlays, stat bars, a
    turntable inspector, per-squad Formation and Role dropdowns, "+ ADD" that spills into the next squad with room,
    drag chips between squads.
  - Its panels are rounded `StyleBoxFlat` (`garage_screen.gd:160-170`, same in `results_screen.gd`) and it sets its
    own `Theme.new()`: **the chamfered kit exists and the garage does not use it**: `CyberFrame` (chamfered
    translucent panel with glowing corner brackets, `cyber_frame.gd:19,114,126`; the HUD and the title use it),
    `CyberUiTheme` (45° cuts on Button / OptionButton / MenuButton / PanelContainer / Label, Share Tech Mono,
    `cyber_ui_theme.gd:46-53`; HudSkin applies it to the window), `CyberStyle` (palette, font, `ui_scale`),
    `CyberBanner`, `Conductors` (breathing traces), `GameTheme._cyber_panel_style()` (`game_theme.gd:181`), and the
    `ui` palettes with `garage_bg`, `garage_panel`, `garage_text_dim` (`:117-123`).
- **1000 credits at today's prices buys five tanks.** Prices (`units.gd` PROFILES): Condemned scout 110, IFV 150,
  tank 200, lancer 200, artillery 220, burner 220; Gangs 70 / 110 / 175 / 170 / 130; Law 140 / 195 / 260 / 250 /
  230; Syndicate 210 / 300 / 470 / 380 / 340. The army he plays in `make skirmish` is a FACTION army at
  `Units.BASELINE_BUDGET = 5200` (about 39 Gangs, 28 Condemned, 24 Law, 15 Syndicate vehicles). The match runner,
  the baselines and every series buy CPU armies at these prices with `Army.cpu_army` (buys down a list until the
  budget runs out, `army.gd:155`), so **a price change can move every baseline line** (C19.2).
- `_agents/balance.md` *Economy* disagrees with the code on the Lancer's tier (doc 2, code 1). Fix the doc.
- Screens: `make garage-shots` (desktop, phone, compare, unlocks, challenges, fight), `make garage-tour` (title →
  garage → FIGHT → results → REMATCH → ARMY at both aspects), `make army-loop-shots`, `make title-shot`,
  `make hud-gallery`. Tests: `tests/test_army_draft.gd`, `test_army_screen.gd`, `test_army_progression.gd`,
  `test_army_results.gd`, `test_army.gd`, `test_army_challenges.gd`, `test_units_catalog.gd`, `tests/garage/*`
  (first visit, centre tip, hud clean, loader, sense of size, time limit, turntable; `economy_sim.gd`).
- The squads' size cap is the formations' (`Formations.MAX_MEMBERS = 5`; brains): keep five.

## Decided by the orchestrator (each reversible; he overrules any; record a reason if you overturn one)

- **1000 credits a game, both sides, called credits.** The per-game spend is "credits" everywhere he reads. The
  bought tiers are retired from the garage; the earned profile total stays in `user://profile.json` (read, migrated,
  never shown as a currency to spend) for his later layer, "as players advance they get more credits".
- **1000 credits buys the army he plays today** (RECOMMENDED to him, with the alternative). Prices are re-expressed
  so a faction army at 1000 credits is about the size a skirmish fields now: one proportional scale, relative
  prices kept to the rounding (C12.6: balance is his; a uniform rescale keeps it). **Decide the mechanism by
  measurement:** if a real rescale (`cost` and `BASELINE_BUDGET` together) buys IDENTICAL CPU armies for every
  archetype, faction and seed the baselines and series use, do it and pre-register UNMOVED; if any composition
  changes, keep the internal points and present credits as the scaled price (one function, one place, a test that
  the display is monotone and the budget bar is exact), OR declare the move and merge alone (C19.2). Say which.
- **Every vehicle is buyable from the first game.** The unlock ladder leaves the garage (no locked cards, no UNLOCK
  overlay, no next-goal sell); `Progression` keeps the record of wins and the earned total.
- **He picks a faction first, then buys from its roster.** All four factions; the CPU takes a faction as skirmish
  does (random, or his choice, at the same 1000).
- **One screen, three questions, then FIGHT:** which faction; which vehicles (the credits left always visible, a
  price on every card, tap to buy, tap the chip to sell); which squads (up to five, any mix, five vehicles each:
  drag a chip into a squad, or tap a squad then tap chips; an empty squad disappears; "squad however they want").
  Squad formation and role are NOT set in the garage (he sets formations in the match now; the role dropdown goes).
  Presets become one "suggested army" button per faction; codes, load/save, compare, challenges and the turntable
  are folded away (a small "more" if they survive) or dropped; saved armies stay readable (v2 format unchanged,
  `tier` kept for migration). The results screen keeps its outcome and its reason line; its credit breakdown goes.
- **The kit is a kit.** `_agents/ui_kit.md`: the chamfer, the brackets, the palette, the font sizes, the button
  states, the spacing, with one screenshot per element from `make ui-kit-shots` (new): the document the board stream
  and the next screens build from (C19.5). The garage is its first full consumer. Additive only: the HUD's and the
  title's output unchanged frame for frame (`make hud-digest` before and after; a title frame diffed).
- **Phone aspect is first-class** (vision.md): every screen at desktop and phone aspect, tap targets at the sizes
  `test_army_screen.gd` already pins.

## Backlog (in order)

- **G1. The economy, decided and tested.** `ArmyCatalog` at 1000 credits for any faction; no tiers, no unlocks; the
  CPU opponent at the same 1000 and a faction; the price mechanism chosen by the measurement above (table in Status:
  archetype × faction × seed, identical or not). Tests first: a new profile sees 1000 and every vehicle; the budget
  bar is exact; `Army.cpu_army` compositions before/after; `economy_sim.gd` re-pointed or retired. **Merged alone
  at CP3 with its pre-registration** (UNMOVED, or declared with the lines adopted).
- **G2. The kit, documented.** `_agents/ui_kit.md` + `make ui-kit-shots`; any additions to `CyberFrame` /
  `CyberUiTheme` / `CyberStyle` the garage needs (a chamfered card, a chip, a price tag, a filled meter for the
  credits, a faction crest slot) built as kit elements with a gallery frame each. HUD digest and title frame
  unchanged. **CP1**: merged early so board can build on it.
- **G3. The screen.** Faction → vehicles → squads → FIGHT, in the kit, at both aspects; the credits meter always
  visible; the picked army saved as before. Tests: every gesture (buy, sell, drag to squad, tap-tap to squad, remove
  from squad, new squad, FIGHT refused over budget with the reason in words); tap sizes; `garage-tour` at both
  aspects re-recorded. Look at every frame.
- **G4. The results screen in the kit**, and the title screen's path to it (title → garage → fight → results →
  again). `make garage-tour` is the proof; frames looked at.
- **G5. Play it like him.** `make garage` on the laptop (windowed; say when): build a Law army of five squads,
  FIGHT, finish, REMATCH. What felt slow or unclear, in Status, fixed if small.
- **Stretch.** (a) A suggested army per faction that fits 1000 exactly. (b) The army code as a "share" line only.
  (c) His later layer sketched in `game_design.md` *Progression* (credits that grow with advancement), nothing
  built. (d) `_agents/balance.md` *Economy* rewritten to the new numbers.

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` and `N
passed, M failed`; never a pipe). **Thirteen baseline lines and determinism UNMOVED on every commit except G1's,
which is pre-registered either way and merged alone** (C19.2). `make garage-shots`, `make garage-tour`,
`make army-loop-shots`, `make ui-kit-shots`, `make hud-digest` (unchanged), a title frame diffed; every frame looked
at, desktop and phone aspect. His eye is the check for the look (C18.3): there is no page unless you have a real
choice to put to him; if you do, render it headless and count its buttons first (lesson 252).

## Don't touch

`game/control/**`, `game/ui/**` except the kit files and the title named above (orders; board) · `game/ai/**`,
`game/tactics/**` (brains; `Formations.MAX_MEMBERS` read) · `game/match/**`, `game/ui/hud*.gd`, `hud.tscn`,
`game/ui/widgets/hud_skin.gd`, `game/announcer/**`, `game/theme/arena_kit/**` (board) · `game/units/units.gd`
beyond prices (balance values are his, C12.6; `hull_size`, weapons, health untouched) · `arenas/**`, `game/arena/**`
· `mk/core.mk`, `tests/baselines/**` except G1's declared lines.

## Waiting on the lead

- **How big an army 1000 credits buys** (recommended: the army he plays now). Asked by the orchestrator; build the
  recommended one; the other is a number.
- **Every vehicle open from the first game** (recommended) or unlocked by winning. Asked by the orchestrator.

## Status

_Updated 2026-10-06 morning by the garage worker (session in `godot-garage`). Every backlog item and every stretch item is done; the report is at the end._

**Started from green:** `567e1997` on builder0, `>> remote: make check exited 0`, 2057 passed 0 failed, 23 targets ALL
JUDGED, all thirteen sim-baseline lines unmoved (22:20–22:50 PDT).

### Plan (ordered; one reason each)

1. **G2 first, then G1.** CP1 (the kit) is what board waits on, and G1 must merge ALONE: with G2 first on the branch,
   the orchestrator can merge CP1 without carrying G1, and G1 after it without carrying G3.
2. **G1: credits are a presentation, not a rescale** (the measurement below). The garage's catalog is priced in
   credits (points / 5, exact); nothing the simulation reads changes, so G1 pre-registers **UNMOVED**.
3. **G3** the new screen replaces `garage_screen.gd` (old one deleted, not kept beside it); then **G4** the results
   screen; then **G5**; then the stretch items.

### G1: the measurement that decided the mechanism (567e1997, laptop, `scratchpad g1_measure.py`, pure arithmetic)

`Army.cpu_army`'s buy-down replayed for every archetype (15) × every starting point the seed can pick (all of them,
so every seed is covered) × the budgets the baselines and series use (800, 1000, 1200, 1700, 2400, 2600, 3200, 4600,
5200, 6500) × with and without a faction (cap 45 / 25): **1,250 compositions**. A real rescale of every price by
1000/5200 (rounded to whole credits; budgets scaled alike) buys a **different army in 182 of 1,250** (18 of them at
the baselines' 5,200; by archetype: brawl 59, balanced 40, gang_pack 22, siege 20, recon_strike 14, gang_hail 10,
law_cordon 10, syndicate_standoff 5, law_line 1, syndicate_demo 1). **So no real rescale.** Every price is a
multiple of 5 points, so **1 credit = 5 points is exact** (the same table at /5: 0 differences): each card's price,
a squad's sum and the meter agree to the credit, and **1000 credits = 5,000 points** (a faction skirmish is 5,200:
Condemned 27 vs 28 vehicles at the average price). `Credits` (`game/progression/credits.gd`) is the one place;
`tests/test_army_economy.gd` pins the 21 launch prices (C19.2's tripwire), exactness, monotonicity, and that the
skirmish armies are untouched. **Pre-registration for G1: UNMOVED (thirteen lines + determinism).**

**A rule the brief did not settle, decided:** the player has at most five squads of five (25 vehicles). At 5,000
points the Road Gangs' average army is 38 vehicles and the Condemned 27, so **the CPU in the garage buys under the
same caps** (`GarageOpponent`: its faction's archetypes, ≤ 25 vehicles, folded into ≤ 5 squads) instead of the
skirmish's faction buyer (45 a side). Fairness first (his "shared budget tier"). Consequence, put to him below: a
Road Gangs army cannot spend all 1000 credits (25 of their dearest is 875).

### Done (laptop numbers are the laptop's; every builder0 number says so)

The branch, in merge order: **`84f7197d` G2** (the kit) → **`fe32ba38` G2 fix** (a card fits its content) → **`66b8f34a`
G1** (the economy, merge ALONE at CP3) → `7cb17a6e` G3 (the screen) → `e0f1b497` G4 (results) → `790acd84` docs (this
Status, stretch c) → **`d033f71d` G5 fixes**. (History was reordered once, before any push, so CP1 can be taken
without G1; the trees were diffed equal.)

- **G2 (CP1).** `CyberKit` (type scale TITLE 44 / HEADING 28 / BODY 22 / SMALL 18 / MICRO 15; GAP 8/16/24; CUT 10;
  TAP 48; faction colours and crest marks; `box`, `panel_box`, `button`/`style_button`, `chip`, `tag`, `heading`),
  `CyberCard` (fits its content since `fe32ba38`), `CyberMeter` (`ui_scale`), `CyberCrest`, the gallery
  (`game/ui/widgets/kit/`), `make ui-kit-shots`, `_agents/ui_kit.md`. No existing kit file changed
  (`git diff 567e1997 -- cyber_frame cyber_ui_theme cyber_style cyber_banner conductors title/` is empty), so the
  HUD and title draw what they drew; `make hud-digest` ran in the same chain. Frames looked at: the sheet at 1920×1080
  and 1800×810 `--ui-touch`, and each element. Laptop: `test_ui_kit` 6/0.
- **G1 (CP3, pre-registered UNMOVED).** `Credits` (1 credit = 5 points; `game_points()` 5,000), `ArmyCatalog.for_game
  (faction)` (the roster in credits, every vehicle open, `budget_points()`, `money()`, `faction_of_army()`),
  `GarageOpponent` (the CPU at its faction, 5,000 points, ≤ 25 vehicles in ≤ 5 squads), draft refusals in credits.
  `tests/test_army_economy.gd`: 8 tests (pinned prices, exactness, order, a new player sees 1000 and every vehicle of
  every faction, the meter exact over 80 random armies, refusals in credits, the CPU's money/caps/faction/
  determinism, the skirmish untouched: seed 3 at 5,200 = Condemned 27, Gangs 44, Law 24, Syndicate 17).
- **G3.** `garage_screen.gd` rewritten (1293 → ~580 lines): top bar (GARAGE, the credits meter, VS, FIGHT in green),
  the status line (what just happened, or why FIGHT is refused, in words), 1 FACTION (four cards; each faction keeps
  its army while he looks around; one he has not built opens on its suggested army), 2 VEHICLES (a card each: name,
  price, job, length, "×n in the army", what it beats; tap buys into the selected squad, a full squad spills; drag a
  card onto a squad; a card he can't afford dims and says why on a tap), 3 SQUADS (up to five of five, any mix; tap a
  squad to buy into it; tap a vehicle to pick it up, then tap another squad to move it or tap it again to SELL it;
  drag to move, drag back to the vehicles to sell; + NEW SQUAD; an empty squad disappears unless selected;
  SUGGESTED; CLEAR). Dropped: the name field, presets, load/save/delete, codes, compare, challenges, unlocks, tiers,
  the enemy menu, per-squad formation and role, the turntable (deleted), `economy-sim` (deleted). `GarageSuggest`:
  one suggested army per faction (`MEASURE suggested_armies`, laptop: Condemned 874 CR / 25 vehicles, Law 1000 / 23,
  Syndicate 996 / 15, Road Gangs 526 / 25: capped). `tests/test_army_screen.gd` rewritten (18 tests, real input
  events: buy, sell, tap-tap move, drag move, drag sell, drag-buy, new squad, spill, FIGHT refused empty and over
  budget with the reason, faction switch, VS, tap sizes, resize, save/reopen, a round-18 save in credits, REMATCH of
  another faction's army). The tour drives the new gestures.
- **G4.** The results screen in the kit: the outcome in its colour, why and against which faction, each army's
  fielded / lost / destroyed and what it was worth in credits / best vehicle, one lesson, ARMY and REMATCH (green).
  No breakdown, no unlock sell. Another faction's vehicles are named (they were spelled as ids).
- **G5 (laptop, `d033f71d`, the tour's script windowed at 1920×1080 — the lead's machine, this worktree's own user
  dir).** The first run found: **REMATCH of a Law army fought nothing** (the saved army was read through the
  Condemned catalog and lost every vehicle; fixed with `GarageMode.open_saved`, tested); **the match's status line
  said "Skirmish vs user://army_fight/garage_enemy.json"** (the garage now writes "vs The Condemned (CPU)" and the
  arena); "The suggested The Law Army" (reworded); results panels were tall empty boxes (now sized to content). The
  second run: **24/24 tour steps, 0 script errors**, Law army of five squads (23 vehicles, 1000 CR) → FIGHT → results
  → REMATCH → results → ARMY → back in the garage. What felt slow or unclear, honestly: the garage opens in about
  the same time as before (the arena loads behind it); picking up a vehicle and tapping a squad is quick once the
  status line has said it once; the cap-bound gangs army (526 of 1000 CR spent) is the one thing that reads wrong.

### Report (2026-10-06 morning; the garage worker)

**Merged to main by the orchestrator:** CP1 = `84f7197d` (main `94d301ae`), the card fix `fe32ba38` (main `807f90a5`),
CP3 = G1 `66b8f34a` ALONE (main `5a60f032`: exited 0, 2089/0, thirteen lines unmoved, as pre-registered).
**On the branch for the next merge:** G3 → G4 → G5 → the follow-ups → stretch b, then `main` merged in at `90695808`, then `e6a8ffbf` (the score line read at the finish; the tip and lesson say "rings" on two-ring maps).
Green hashes, every one builder0 `make check` (exited 0, ALL JUDGED, thirteen lines + determinism `762a0576f944f5b7`
unmoved): `84f7197d` 2063/0 · `fe32ba38` 2063/0 · `66b8f34a` 2071/0 · `d033f71d` 2066/0 · `4bd6eedb` 2071/0 (the
pre-merge tip) · `90695808` (the merge) 2129/0 · `e6a8ffbf` (the tip: the score line fix and the rings tip) 2131/0, its tour 0 failed at both aspects. **Merge here: `e6a8ffbf`** (the commit after it is this report, docs only).

**Frames looked at** (copied out of `build/` so copy-backs can't erase them:
`/tmp/claude-1000/-home-slobdell-projects-godot-garage/9f8c8188-d1a0-4835-bc95-1e761bb9c0f3/scratchpad/`):
`ui-kit-84f7197d/` and `ui-kit-4bd6eedb/` (the kit sheet and each element), `shots-d033f71d/` and `shots-4bd6eedb/`
(garage desktop, phone, each faction, the fight, results desktop and phone), `tour-d033f71d/`, `tour-4bd6eedb/`, `tour-90695808/`, `tour-e6a8ffbf/` (with `laptop-terminus-results.png`: the rings wording and the score line on a two-ring map)
(the tour at both aspects, 0 failed both times). The HUD is unchanged by the kit: `make hud-digest` at `567e1997`
and at `84f7197d` agree on all 1,122 frames both recorded (the count varies with load).

**Decisions (each reversible; reason in one line)**
- Credits are points / 5, not a rescale: a rescale moved 182 of 1,250 CPU armies; /5 is exact (table above).
- 1000 credits = 5,000 points: the faction skirmish's 5,200 less 4 %, the nearest whole-credit scale.
- The garage's CPU obeys his limits (25 vehicles, 5 squads): fairness; the skirmish and the baselines are untouched.
- Each faction keeps its army while he looks around; a faction he hasn't built opens on its suggested army.
- Moving a vehicle: tap it (it turns pink and says SELL +price), then tap another squad; a second tap sells it.
  Tap-then-confirm keeps a stray tap from selling; dragging works too.
- The suggested army tops up to spend the money only when money is what stops it. A capped army keeps its mix
  (topping up turned the Condemned into 13 artillery out of 25).
- The turntable, presets, load/save/delete, compare, challenges panel, unlocks and tiers are gone from the screen.
  `--challenge=ID` still plays a challenge, and the profile keeps its record.
- His later layer (credits that grow with rank) is sketched in `game_design.md` *Progression*; nothing is built.

**Questions for the lead** (via the orchestrator, who put Q1 to him with a recommendation)
1. *The Road Gangs can field at most 25 vehicles (five squads of five), which leaves part of their 1000 credits
   unspent (their suggested army spends 526).* Built as the orchestrator recommended: 25 is the limit for every
   faction, and the garage says "Your army is full ... can't be spent" in words. Bigger squads would be a brains
   contract (`Formations.MAX_MEMBERS`).

**Requests to other streams:** none open. Board reads `final_score.sides[t].points_destroyed` and shows it with
`Credits.of_points`. The results screen does the same.

**Known issues**
- On the phone, a squad of five long names ("Resupply Tanker") wraps to two lines, so the five squads scroll.
- The skirmish mode prints "Skirmish vs <the enemy flag>" in the HUD's status block. The garage overwrites it
  ("vs The Condemned (CPU) / arena") just after the handover; a cleaner fix is in `game/modes` (not mine).
- `army-loop-shots` takes 10+ minutes on a loaded builder0 (its capture timer counts real time); it does finish.

**What to playtest** (exact commands): `make garage` (windowed). Pick a faction, sell and buy, tap a vehicle and
then a squad to move it, VS, FIGHT, then REMATCH and ARMY. `make garage ENEMY=cpu:law_cordon` pins the CPU's mix.
Open a shared army with `--army=<code from the SHARE line>`.

**Next steps:** none on the backlog. If he wants bigger armies for the gangs, that's brains first, then
`ArmyCatalog.MAX_SQUAD_SIZE` here. The results screen could show board's per-zone stat sheet (`final_score.sides[t].zones`).

**Merge notes (shared files):** none. All paths are garage-owned. New files: `game/ui/widgets/cyber_kit.gd`,
`cyber_card.gd`, `cyber_meter.gd`, `cyber_crest.gd`, `game/ui/widgets/kit/**`, `game/progression/credits.gd`,
`game/garage/garage_opponent.gd`, `garage_suggest.gd`, `_agents/ui_kit.md`. Deleted: `game/garage/garage_turntable.gd`,
`tests/garage/test_garage_turntable.gd`, `tests/garage/economy_sim.gd` (and `make economy-sim`). Docs edited:
`balance.md` *Economy*, `game_design.md` *Progression* (sketch), `orientation.md` (two lines).
