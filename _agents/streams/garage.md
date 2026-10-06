# Stream: garage (the vehicles are seen in the garage; 25 scouts is exactly 1000 credits)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 20 direction* and *Round 19
> direction* (item 3), `_agents/ui_kit.md`, `_agents/workstreams.md` *Round 20*, and round 19's garage report
> (`streams/archive/round19/garage.md` Status: decisions, known issues, the frames' folders). You own
> `game/garage/**`, `game/progression/**` (Credits), `game/units/units.gd` PRICES ONLY (never `cost`: C12.6),
> `game/ui/widgets/cyber_*.gd`, `conductors.gd`, `game/ui/widgets/kit/**`, `game/ui/widgets/title/**`,
> `game/theme/game_theme.gd`'s `ui` palettes, `doctrines/player_*.json`, `assets/units/thumbs/**` (new),
> `tools/unit_thumbs.*` (new), `tests/test_army*.gd`, `tests/test_units_catalog.gd`, `tests/garage/**`,
> `mk/garage.mk`, `_agents/ui_kit.md`, `_agents/balance.md` *Economy*. A render target that needs the game's theme
> code reads `game/theme/**` freely and changes nothing there (a request if it must).

## The lead's direction (2026-10-06, morning, in chat, after playing round 19; verbatim)

> *"ok this is much better. 2 feedback items on the garage: We should incorporate the graphics of the vehicles we're
> adding to the squads, and I also wasn't able to spend my entire budget to get the 5 squads of 5 or max vehicle
> count. I assume this means we should change the cost or lower the credits. Basically a player should be able to
> max out their entire set of squads with nothing but scouts. This might also mean changing the assumptions our
> maximum allowable unit count"*

**Read plainly:** (1) every vehicle he buys is SEEN, on its card and in its squad, as the vehicle; (2) five squads of
five scouts cost exactly 1000 credits, and anything dearer buys fewer; (3) the 25 cap is his open question, not
yours (recommended to him: keep 25).

## Where things stand (read at `c355a41e`)

- **Pictures:** the round-19 cards are words (name, length, "×N in the army", good against); squad chips are text.
  The old 3D turntable (`garage_turntable.gd`) was removed with the old screen. The real meshes are theme slots
  (`GameTheme`, `VisualSlot`; `make vehicle-gallery` in `mk/fx.mk` renders every vehicle with team colours; needs a
  display: builder0, whose desktop must be unlocked for windowed renders, else they run at a tenth speed and time
  out: ask the orchestrator, who has asked the lead). Thumbnails per unit exist nowhere yet.
- **Prices:** `Credits` (`game/progression/credits.gd`): ONE CREDIT = FIVE POINTS for every faction, exact;
  `Units.cost` in points is balance (his). Scouts: Gangs 70 pts = 14 CR, Condemned 110 = 22, Law 140 = 28, Syndicate
  210 = 42; 25 scouts = 350 / 550 / 700 / 1050 CR. `ArmyCatalog.for_game(faction)`, `GarageOpponent` (the CPU at the
  same 1000 and five-by-five), `ArmyDraft` refusals in credits, `tests/test_army_economy.gd` pins 21 launch prices,
  `economy_sim.gd`. The "your army is full … can't be spent" line exists.
- The suggested army per faction (`garage_suggest.gd`) spends what it can under the old prices.
- Screens: `make garage-shots`, `make garage-tour`, `make army-loop-shots`, `make ui-kit-shots`; the laptop tour's
  frames and the results frame are in round 19's scratchpad folders (gone with the worktree; re-render).
- Known from round 19: on the phone, five long names in a squad wrap and the five squads scroll; the HUD's status
  block says "Skirmish vs <flag>" briefly before the garage overwrites it (`game/modes`, nobody's: a request).

## Decided by the orchestrator (each reversible; he overrules any; record a reason if you overturn one)

- **HIS RULE (2026-10-06, after the launch; replaces the per-faction rule first written here):** *"for now we will
  assume that an all scout army for the road gangs is 25 vehicles, and all costs and counts can be based on that."*
  So **the Road Gangs' scout (70 points) is the anchor: 25 of them = 1000 credits, ONE CREDIT = 1.75 POINTS for every
  faction** (the Gangs' scout 40 CR, Condemned 63, Law 80, Syndicate 120; a Gangs War Rig 100), every price from its
  points at that one scale, rounded to the credit (say how ties round; one function in `Credits`; a table test that
  prints all 21). `Units.cost` unchanged; baselines UNMOVED; the garage's CPU opponent buys at the same 1000 CR. The
  factions keep their identities by count at 1000 (all-scout: 25 Gangs, ~15 Condemned, 12 Law, 8 Syndicate), as in
  skirmish. "Your army is full" stays for the Gangs' dear mixes that end short of a slot; for the other factions the
  credits run out first (the line says that).
- **The cap is 25** (his: "all costs and counts can be based on that"); five squads of five.
- **Thumbnails, not viewports:** one PNG per unit per faction, rendered from the real mesh by `make unit-thumbs` on
  builder0 (one angle, three-quarter front, the faction's accent, transparent background, two sizes: card and chip),
  committed under `assets/units/thumbs/`, a test that every unit in `Units.ids()` has both files. The chip shows the
  small picture with the name under or beside it; the card shows the large one with the price tag over its corner.
  A live turntable on the ONE selected card only if it costs nothing measurable on the laptop; otherwise none.
- **Phone first-class:** the chip with a picture must still fit five across at the phone aspect; long names go to
  two lines or an abbreviation with the full name on the card.

## Backlog (in order)

- **R1. The price rule.** `Credits` at 1 CR = 1.75 points (the Gangs' scout 40), the table test, `economy_sim`
  re-pointed, `test_army_economy` re-pinned with the new 21 prices and the rule "25 Gangs scouts = 1000" asserted;
  the suggested armies re-fitted; the CPU opponent legal. Pre-register UNMOVED on the 13 lines (display and the
  garage's own catalog only; `Army.cpu_army` for skirmish and the baselines untouched: prove it with the archetype ×
  seed table as in round 19). **Merged alone (CP1).**
- **R2. The thumbnails.** `make unit-thumbs` (builder0, display), the files, the test; the kit gains a picture slot
  on `CyberCard` and the chip (`_agents/ui_kit.md` updated with a frame). Then the cards and chips use them, at both
  aspects; frames looked at (`make garage-shots`, `garage-tour`).
- **R3. Play it like him.** `make garage` on the laptop (windowed; say when): build an all-scout Road Gangs army (it must be
  exactly 1000 and exactly 25), then an all-scout Law one (12, credits run out first), then a mixed one; FIGHT; REMATCH; ARMY. What felt wrong, fixed if small.
- **R4. The phone wrap** (five long names) and the "Skirmish vs <flag>" flash (a request to the orchestrator with the
  line to change in `game/modes`).
- **Stretch.** (a) The selected card's live turntable, priced. (b) The results screen's per-ring stat sheet
  (`final_score.sides[t].zones`). (c) Sound on buy / sell / FIGHT from the existing kit sounds, if any (nothing paid).

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` and `N
passed, M failed`; never a pipe). **Thirteen lines and determinism UNMOVED on every commit; R1 merges alone with its
table.** `make garage-shots`, `make garage-tour`, `make ui-kit-shots`, `make unit-thumbs`; every frame looked at at
both aspects; his eye is the check for the look.

## Don't touch

`game/control/**`, `game/ui/**` except the kit and title files above · `game/ai/**`, `game/tactics/**` (brains) ·
`game/match/**`, `game/ui/hud*.gd`, `game/announcer/**`, `game/theme/arena_kit/**` (board's, closed; a change is a
request) · `game/units/units.gd` beyond prices · `game/theme/**` (read for the render; a change is a request) ·
`arenas/**`, `game/arena/**` · `mk/core.mk`, `tests/baselines/**`.

## Waiting on the lead

- ~~More than 25 vehicles for an all-scout army?~~ **Answered: 25, and all costs and counts based on it.**
- **builder0's desktop unlocked** for the thumbnail render (asked).

## Status

_Updated 2026-10-06 afternoon by the garage worker (session in `godot-garage`)._

**Started from green:** `0788e268` on builder0, `>> remote: make check exited 0`, 2139 passed 0 failed, thirteen
sim-baseline lines unmoved, determinism `762a0576f944f5b7` (perf-judge and one ai perf scenario NOT JUDGED: box busy).

### Plan (ordered; one reason each)

1. **R1 first, alone** (`5c89f03b`): CP1 is what brains waits on, and it must merge with nothing else.
2. **R2** on top (`04f1d5f4`): the renderer, the 42 files, the kit's picture slot, the screen.
3. **R3** play it like him; **R4** the phone wrap and the status-line request; then stretch.

### R1: the price rule (`5c89f03b`; check running)

- `Credits`: one credit = 7/4 points, a price is points × 4/7 **rounded UP** (a shown price never undercharges, so
  1000 CR always fits the fight's 1,750 points; rounding to nearest let Syndicate IFVs exceed it). No ties (every
  cost is a multiple of 5 points). The 21 prices: Condemned 63 / 86 / 115 / 115 / 126 / 126, Gangs 40 / 63 / 100 /
  75 / 98, Law 80 / 112 / 149 / 132 / 143, Syndicate 120 / 172 / 269 / 195 / 218 (table in `balance.md` *Economy*).
- All-scout at 1000: Gangs 25 (exactly 1000), Condemned 15, Law 12, Syndicate 8, bought through the garage in the test.
- `GarageOpponent` buys in credits at the same prices (`MEASURE r20_cpu_armies`, laptop: Gangs 14–17 vehicles,
  Condemned 8–14, Law 8–9, Syndicate 5–6; 926–997 CR). Suggested armies (laptop): Condemned 10 / 999 CR, Gangs 17 /
  997, Law 8 / 995, Syndicate 5 / 997.
- The line when the money ends first: "Your credits have run out: the 40 CR left buys no vehicle. Sell one to buy
  another, or FIGHT." (shown after the last buy too). A full army is refused as full before the money.
- **UNMOVED proof:** `test_army_economy` pins an md5 of `Army.cpu_army` over 15 archetypes × 20 seeds at 5,200 +
  20 plain armies (320 armies) = `5681a05efe937bd22368c0251bae7ea0`, plus the seed-3 sizes (27 / 44 / 24 / 17).
  Neither `Army` nor `Units` is in the diff.

### R2: the thumbnails (`04f1d5f4`; check pending)

`make unit-thumbs` → `build/unit_thumbs/`, `make unit-thumbs-adopt` → `assets/units/thumbs/` (21 × card 320×200 +
chip 128×80, 1.7 MB). The first committed set was rendered on the **laptop** (builder0's desktop gate was still
open; the lead has since turned on caffeinate there). Contact sheet looked at: every vehicle reads, faction paint
true; the IFVs' class-lamp flares drew black quads on transparency and are hidden (domes kept). Kit:
`CyberCard.set_picture` / `pin_to_picture`, `CyberPictureChip`; the garage uses both; frames looked at (desktop
1920×1080 and phone 1800×810 `--ui-touch`): five chips fit across a squad at both aspects; the price tags clear the
scroll bar.

### Questions for the lead

(none yet)

### Requests to other streams

- **Orchestrator, `game/modes` (nobody's):** `skirmish_mode.gd:330` writes "Skirmish vs <the --enemy value>",
  which for the garage is a file path until the garage overwrites it. Ask: read an optional `--enemy-title` flag
  there and use it in place of `lineups[RUST]`; the garage will set it to "The Condemned (CPU)".

### Known issues

- On the phone the five squads still scroll (a squad row with pictures is ~105 px at the touch scale): R4.
- `tests/test_hud_score_bug.gd` (board's, closed) re-pinned in R1: 700 points = 400 CR, 650 = 372 CR. The score bug
  rounds each total up, so "credits destroyed" can differ from the sum of the card prices by a credit or two (3
  Condemned tanks: 343 vs 345). Display only.
