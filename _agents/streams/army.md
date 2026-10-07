# Stream: army (the army doubles: ten squads of five, 50 vehicles, 2000 credits)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 19 direction* item 3 (the
> garage he imagines), *Round 20 direction* and *Round 20: the cap and the price anchor* (25 scouts = 1000 CR, 1 CR =
> 1.75 points), *Round 22 direction* (his words, the table, "double it"), `_agents/workstreams.md` *Round 22* (C22.1,
> C22.3, C22.5), `_agents/ui_kit.md`, `_agents/balance.md` *Economy*, and the garage's round-19/20 final reports
> (`streams/archive/round19/garage.md`, `streams/archive/round20/garage.md` Status). You own `game/garage/**`,
> `game/progression/**`, `game/units/units.gd` (`DEFAULT_BUDGET` and prices only), `game/ui/widgets/cyber_*.gd`,
> `conductors.gd`, `game/ui/widgets/title/**`, `game/theme/game_theme.gd` `ui` palettes, `doctrines/player_*.json`,
> `tests/test_army*.gd`, `tests/test_units_catalog.gd`, `tests/garage/**`, `mk/garage.mk`, `_agents/ui_kit.md`,
> `_agents/balance.md` *Economy*, `assets/units/thumbs/**`.

## The lead's direction (2026-10-07)

> *"Based on our earlier rule of maxing out at 25 scouts, the only feedback I have now is that the armies I can create
> with tanks are too small, so we need to figure that out. Maybe that means allowing more squads, you had said
> formations are based in groups of 5"* … shown the table and the recommendation to double: *"yeah double it sounds
> good."*

Standing (round 20): the Gangs' scout is the anchor at 40 CR; one credit = 1.75 points for every faction; relative
prices are balance (C12.6, his) and do not move. Squads stay FIVE (`Formations.MAX_MEMBERS`, brains' invariant).

## Where things stand (read at `5beb038f`)

- `ArmyCatalog.MAX_SQUADS := 5`, `MAX_SQUAD_SIZE := 5`, `FALLBACK_BUDGET := 1000` (credits); `GarageOpponent.UNIT_CAP`
  derives from them; `Units.DEFAULT_BUDGET := 1000` (points, the flagless `make skirmish`), `Units.BASELINE_BUDGET :=
  5200` (faction armies, the baselines: NOT yours, untouched). With 1000 CR: Gangs 25 scouts / 10 tanks; Law 12 / 6;
  Syndicate 8 / 3. The hint says "up to five squads"; the tour plays five; the phone fits five squads (round 20).
- Garage's known issue from round 20: a suggested army opens saying "the 1 CR left buys no vehicle" (true, odd).
- The garage's fight runs through `skirmish_mode.gd` (nobody's; C20.5's `--enemy-title`); the CPU opponent buys in
  credits at the same budget (C20.1).
- Control groups are 1–9 today (orders adds 0 = group 10 this round, C22.5); the garage's squads map to groups by index.

## Backlog (in order)

**A1. CP1: the constants and the opponent (merged ALONE, first).** `MAX_SQUADS` 10; the budget 2000 CR (one constant;
`Units.DEFAULT_BUDGET` to the matching points, 3500, so a flagless `make skirmish` fields the same size: decide and
record whether that is right for the non-faction path, or leave it and say why); `UNIT_CAP` derives (50); the opponent
buys 2000 in ≤ 10 squads. Tests: the catalog's cap and budget; 50 Gangs scouts = 2000 exactly; the Law 25 scouts / 13
tanks; the Syndicate 16 / 7; the archetype × seed proof that `Army.cpu_army` at `BASELINE_BUDGET` with explicit flags is
IDENTICAL (the baselines' input, C22.1); grep the repo for hard-coded 5/25/1000 army sizes and list every hit in Status
(yours fixed; others' as requests). Pre-register the thirteen lines UNMOVED. **Name the green hash; the orchestrator
merges it alone and tells everyone to merge.**

**A2. The screen at ten squads.** Desktop and phone aspect: ten squad rows (or two columns of five) with the chips and
thumbnails readable; the budget bar at 2000; suggested armies for each faction at 2000 in squads of about three to
five (the Syndicate's seven tanks is two squads); the tour plays ten; the hint text; CLEAR; the results screen's rings
unchanged. Frames of every faction at both aspects under `streams/references/round22/army/`, looked at.

**A3. The CPU opponent at 2000.** It buys a sensible ten-squad army per faction (not 50 scouts unless the archetype
says so); `--enemy-title` unchanged; a fight from the garage with 50 v 50 runs (headless smoke) and the HUD's status
line is right.

**A4. The cap as a number (C22.3).** Build for 10; when the orchestrator sends the measured cap (50, 40 or 30) set
`MAX_SQUADS` and the budget to it in one commit (10/2000, 8/1600, 6/1200) and re-run A1's tests. Until then 10/2000.

**A5. Docs.** `balance.md` *Economy* (the table at 2000); `ui_kit.md` if a kit element changed; `game_design.md`
*Progression* untouched.

**Stretch (a).** The "1 CR left buys no vehicle" caption: say it only when it is useful ("40 CR left: one more Rat
Rod"). **Stretch (b).** The army code (`army_code.gd`) at ten squads within `MAX_CODE_LENGTH`. **Stretch (c).** Rank
raises the credits you bring (his round-19 wish; `game_design.md` *Progression*): nothing built; only sketch the
questions if time allows.

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism UNMOVED as pre-registered.
- `make garage` → every faction → suggested army → FIGHT: ten squads bought, 2000 spent, the fight starts, the status
  line names the opponent. Phone aspect too (`make garage` with the phone flag your round-20 report names).
- `make unit-thumbs` only if a card changed size (builder0, desktop unlocked).
- Every number: commit, machine, workload, sample size (C16.3).

## Don't touch

`game/control/**`, `game/ui/**` except your kit files (orders') · `game/tactics/**`, `game/ai/**` (brains) ·
`game/theme/fx/**`, `game/ui/hud*.gd` (perf) · `game/modes/**` (nobody; if the skirmish's default size needs one
constant, ask) · `game/match/**` · `arenas/**` · `mk/core.mk`, `tests/baselines/**` · `Units.cost` relative prices and
`BASELINE_BUDGET` (C12.6, the baselines).

## Waiting on the lead

- Nothing blocks you. The cap's final number comes from the orchestrator (perf's measurement, C22.3); build for 10.

## Status

**Plan (2026-10-07):** A1 constants + opponent + tests → A2 the screen at ten (layout landed WITH CP1: at ten squads the
phone's panel scrolled and a test went red, so CP1 is not green without it) → A3 the opponent's armies at 2000, the
headless 50 v 50 fight → A5 docs → stretch (a) the "CR left" caption → (b) the army code at 50 → (c) questions only. A4
waits on the orchestrator's number.

**Pre-registered for CP1:** the thirteen sim-baseline lines and determinism UNMOVED (nothing the match runner builds
changes: `Army`, `Units.cost`, `BASELINE_BUDGET`, `DEFAULT_BUDGET` untouched; the fold changes only the skirmish's
GREEN side); the `cpu_army` digest test unchanged and passing.

**Baseline (before any change):** `32748a0c`, builder0, `make check` exited 2: 2210 passed, 1 failed —
`test_announcer_cost` (the booth's tick 0.51 ms v a 0.1 ms budget) while four streams' checks shared builder0; a timing
test under load, not army's code.

### Decisions

- **The one constant is `Units.MAX_SQUADS := 10`** (the orchestrator's ruling: tactics and doctrine must not depend on
  the garage); `ArmyCatalog.MAX_SQUADS`, `SquadConsolidation.MAX_SQUADS`, `Doctrine.PLAYER_MAX_SQUADS` read it.
  `ArmyCatalog.MAX_UNITS` = 50; `Credits.ANCHOR_COUNT` = the cap and `GAME_CREDITS` = cap × 40 CR, so A4 is one number.
- **`Units.DEFAULT_BUDGET` stays 1000 points** (accepted): it is the flagless skirmish's (player_default's five
  vehicles v a CPU at this budget; 3,500 would make it 5 v ~20) and the match runner's experiments', not his army's.
- **Two columns of five squads**, desktop and phone; in two columns a chip is its picture alone (the name wraps
  mid-word at a fifth of half the panel; it is on the card, the tooltip, and the chip when picked up); the phone drops
  the "tap a squad…" hint line to fit the fifth row.
- **Squad order reads left to right, top to bottom** (Alpha | Bravo, Charlie | Delta …): groups 1–10 follow it.

### Results (per item; every number with its commit and machine)

- **A1 (CP1), `85d2b5bb`:** `Units.MAX_SQUADS` 10, 50 vehicles, 2000 CR = 3,500 points. The table at 2000
  (`MEASURE r22_table`, laptop): Gangs 50 scouts (every credit) / 20 tanks; Law 25 (every credit) / 13; Syndicate 16 /
  7; Condemned 31 / 17. The `cpu_army` digest test unchanged and passing (laptop). His ten squads reach the field as ten
  (test; before the fold's edit they reached it as five).
- **A2 (the screen), `85d2b5bb` + `7242d75a` + `53c08c6e`:** two columns of five squads, desktop and phone; ten full
  squads fit both without scrolling (test); every faction fits the phone window, suggested and full (test, `MEASURE
  phone_widths`: vehicles min 505, squads min 903, window 1800); suggested armies in squads of three to five (Condemned
  20 in 5, Gangs 33 in 9, Law 16 in 4, Syndicate 10 in 3; 1990–2000 CR). The tour (`tests/garage/garage_tour.gd`)
  buys 50 Rat Rods by 51 taps (the 51st refused as full), the Syndicate's 16 scouts (80 CR left, the 17th refused for
  the money), and FIGHTs with ten squads, checking 10 squads / 50 vehicles on the field. Frames looked at:
  `streams/references/round22/army/garage-{desktop,phone}-<faction>.png`, `garage-phone-gangs-50.png` (laptop's display,
  `53c08c6e`'s tree); the "before" (builder0, five-squad layout at 2000 CR): the phone scrolled.
- **A3 (the opponent), `9753a54f`:** at 2000 the CPU buys its archetype's mix in at most ten squads, now with no squad
  of one while another has room (it handed its commander a lone Guns3 tank, Spears2 rat rod, Eyes2 scout). n = 12 seeds a
  faction (laptop): Gangs 27–33 vehicles / 1962–1995 CR, Condemned 17–28 / 1949–1983, Law 16–18 / 1923–1992, Syndicate
  10–12 / 1902–1992, 4–7 squads. `garage-smoke` (in check) now also fights 50 Rat Rods in ten squads v the Gangs' CPU:
  laptop, seed 4: `green=50 rust=28 green_squads=10 rust_squads=6 status="vs Road Gangs (CPU)"`, no ERROR line.
- **A5 (docs), `619e765a`:** `balance.md` *Economy* (the round-22 table and the one constant), `ui_kit.md`
  (`CyberPictureChip.set_width`).
- **Stretch (a), `5dab6f6d`:** the line names the money left only when it buys something ("100 CR left: one more War
  Rig", when less than three of the cheapest fit); otherwise "Your credits are spent: FIGHT when ready, or sell a
  vehicle to buy another." (the meter shows the change). No suggested army opens on "buys no vehicle" (test).
- **Stretch (b), `5dab6f6d`:** a full army's share code: 50 Rat Rods 219 characters, the mixed Gangs suggestion 343, of
  `MAX_CODE_LENGTH` 4096; every faction's full and suggested army round-trips (test).
- **Stretch (c): questions only** (nothing built; `game_design.md` *Progression* untouched). Round 19's sketch assumed
  1000 at rank 0 and a 25-vehicle cap that 2000 credits would fill. At round 22's 2000 the Gangs already fill the 50 cap
  and the Law spends exactly 2000 on 25 scouts, so for him: (1) does rank still raise the money, now that more money
  past 2000 buys only a dearer mix, never a bigger crowd (the cap is his frame's, C22.3)? (2) or does a NEW player start
  below 2000 (e.g. 1000, five squads) and rank grow him to the full army, so the doubling is something he earns? (3) is
  the CPU's money his money at every rank (the fairness guard), or does the CPU's difficulty become the lever instead?

### Hard-coded army sizes (grep at `32748a0c`)

Fixed (mine, or granted): `ArmyCatalog.MAX_SQUADS` 5, `Credits.ANCHOR_COUNT` 25 / `GAME_CREDITS` 1000,
`SquadConsolidation.MAX_SQUADS` 5 (brains', granted: it folded his ten squads to five on the field),
`Doctrine.PLAYER_MAX_SQUADS` 5 (brains', granted), the garage hint "up to five squads", the full line "five squads of
five", the match tip "press 1-5", the round-20 tests (`test_army_economy`, `_draft`, `_screen`, garage first-visit,
loader, tour), `test_every_unit_selectable` (cycled keys 1–5; now every `ControlGroups.COUNT`).
Others', left (not army sizes, or theirs to change): `ControlGroups.COUNT := 9` (orders' O1, C22.5: squads past nine
already fold into a group, so nothing is orphaned meanwhile); `tests/support/five_gangs_army.json` and the five-squad
probes (orders' O3); `test_control_squad_ranks`, `test_control_two_squads`, `test_tactics_attack_obeyed`,
`test_arena_deploy_zone` (fixed five-squad stages: inputs, not caps); `Doctrine.MAX_SQUADS` 12 and `MAX_UNITS` 57
(≥ 10 / 50: fine).

