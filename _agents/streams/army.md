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

_(the worker keeps this current: plan, per-item results with commit + machine + sample, decisions with one-line
reasons, questions for the lead, requests to other streams, known issues, what to playtest, next steps, merge notes)_
