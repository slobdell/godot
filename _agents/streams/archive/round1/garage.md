> **Archived round-1 brief (2026-09-14 overnight run), kept as history.** Current plan: [../../../workstreams.md](../../../workstreams.md) and [../../../game_design.md](../../../game_design.md).

# Stream: Garage (pre-match equipping and squad building)

> Read [../workstreams.md](../../../workstreams.md), [../tank_brain.md](../../../tank_brain.md) (directives,
> doctrines), and [look_and_feel.md](look_and_feel.md). You own `game/garage/` (new) and
> `mk/garage.mk` (new); you produce player doctrine/loadout JSON consumed by skirmish.

**Art direction:** vehicles, previews, and garage visuals follow [../art_direction.md](../../../art_direction.md)
(the "Death Race prison dozer" north star, 2026-09-14): each unit class is a brutally converted real vehicle.

## Goal

Before a match, the player **spends a budget** on an army (the lead, 2026-09-14): scouts, tanks,
artillery, possibly chassis configured with weapons MechWarrior-style. They assign units to squads
and roles, plus cosmetics. The output is **data**: a doctrine the match loads
(`--player=<name>`), so the garage never touches simulation code.

Loadouts include **weapons** (cannon with finite ammo, laser with heat, flamethrower…) and
**components** such as **heat sinks** (MechWarrior-style), extra ammo, and shield boosters
(gameplay G6/G7 and directive set 2). The garage should make the trade-offs readable: a laser boat
needs heat sinks, and a cannon build needs ammo.

**Mobile first** (workstreams.md): the garage is tap and drag only (drag a component onto a
hardpoint, tap to pick) and readable on a phone.

## Dependencies, and what can start now

| Needs | From | Until then |
|---|---|---|
| The **unit catalog**: classes (scout, tank, artillery…), costs, stats, hardpoints, and the per-match **budget** (gameplay directive set 2) | gameplay | Build the UI skeleton against today's weapons (`Weapons.PROFILES`) and a stub catalog; adopt the real one when it lands |
| The look (turntable scene, UI style) | look & feel | Use the `default` theme through visual slots, so art swaps in later for free |
| Where saved squads live for online play | netcode | Save locally under `user://` |

## First milestone

1. **Loadout schema:** extend the doctrine format (e.g. per tank: `hull`, `weapon`, `utility`, `paint`), validated in `Doctrine.parse`. Agree on the fields with gameplay; that's a contract change (workstreams.md).
2. **A garage scene:** a squad roster with add/remove tank, weapon pick, squad and role assignment, and a 3D turntable preview built from visual slots. Save/load to `user://doctrines/`.
3. **Launch the skirmish with the saved squad** (`--skirmish --player=<saved>`), and a test that a garage-built doctrine loads and validates.

## Status

- 2026-09-13: brief written. Blocked on nothing for the data model; art waits for look & feel v1.
- 2026-09-14: overnight backlog added; unit catalog v0 and `--player=<path>` landed on main.

### Overnight run 2026-09-14 (garage agent): morning report

**Plan** (backlog order): GA0 loadout model → GA1 garage screen → GA2 `--garage` flow + `make garage` →
GA3 end-to-end match → GA4 CPU armies → stretch (army codes, comparison, paint, tutorial hints).

**Progress:** (updated after each step, newest last)

- Baseline `make check` green (91 tests) at `ee20791`.
- **GA0 done.** `game/garage/garage_catalog.gd` (reads `Units`/`Weapons` by shape; optional `Units.COMPONENTS`,
  weapon `cost`, else stub components), `loadout.gd` (army in doctrine shape: costs, budget, caps, player-readable
  problems, edits that refuse with a reason), `army_store.gd` (`user://doctrines/`). 8 tests in
  `tests/test_garage_loadout.gd`, incl. save → `Doctrine.load_file` → `Match.load_doctrine` (the tank fights with the
  garage-picked flamethrower); mutation-checked (breaking weapon mirroring / budget refusal turns 2 red).
  Contract row "Loadout fields in doctrine JSON" in workstreams.md now lists the exact fields.
- **GA1 + GA2 done.** `garage_screen.gd` (built from code, no .tscn): UNITS cards (stat bars + numbers, ADD, drag a
  card onto a squad), SQUADS (≤ `Doctrine.MAX_SQUADS`; formation + role pickers; unit chips: tap = equip, drag = move squad), EQUIP (turntable
  from visual slots, swipe to spin; weapon per hardpoint by tap or drag; components; per-unit role; paint swatches;
  REMOVE), top bar (name, budget bar, LOAD, SAVE), bottom (problems / READY, enemy picker, FIGHT). UI scales with
  screen height (1.5× at 1080 → ≥48 px taps). `garage_mode.gd`: `--garage` → garage → FIGHT saves to
  `user://doctrines/<slug>.json` and starts `SkirmishMode` in-process (prints `GARAGE_FIGHT`). `make garage`,
  `make garage-smoke` (now in `make check`), `make garage-shots`. 10 screen tests push real taps/drags through the
  viewport (drag tests mutation-checked). Screenshots reviewed at 1920×1080 and 20:9.
  - Decision: first visit opens a ready starter army (3+2 tanks, the cheapest class) so FIGHT works immediately.
  - Decision: REMOVE moved into the EQUIP header after a test caught it scrolled off-screen at 720p.
  - Decision: FIGHT saves the army (superseded in the morning by per-army files; see *Saving* below).
- **GA3 done.** `make garage-e2e`: `tests/garage/build_army.gd` builds a mixed army (3 squads, 2 flamethrowers,
  roles, paint) through `Loadout`, saves it to `user://doctrines/garage_e2e.json`, then the match runner fights it
  (`--green-doctrine=user://…` already worked, no adapter needed) vs Individuals to elimination; asserts 5 green tanks,
  shots fired, no ERROR. Measured: elimination at 95 s sim, Rust won 5-0 (green fired 58 shots). Expected: player
  squads are saved with `verb: hold`, so with nobody giving orders they sit at base. Not in `make check` (~20 s).
- **GA4 done.** `army_presets.gd`: archetypes as data (balanced, rush, turtle, flamers) that name *preferences*
  (fastest/toughest/cheapest class, shortest/longest-range weapon a hardpoint accepts, components by stat keyword:
  heat weapons → heat components, ammo weapons → ammo), rolled with a seed (formations, objectives mirrored
  left/right, directive weights) and filled to the budget. Garage: PRESETS menu (player versions hold, no
  objectives; each pick rolls the next seed) and enemy picker `cpu:<archetype>` (default `cpu:balanced`, a fresh seed
  each FIGHT, `--seed=N` to pin; saved to `user://doctrines/cpu/<archetype>.json`). `make garage-cpu-army PRESET= SEED=`
  writes one for `make skirmish ENEMY=<path>`. 8 tests in `tests/test_garage_presets.gd`, incl. a richer "future"
  catalog (scout/brute/laser/heat sink) proving archetypes adapt. `Loadout.problems(with_loader=false)` checks garage
  rules without today's `Doctrine.parse` (which rejects weapons the game doesn't have yet).
  - **Bug found by measuring, fixed:** the first archetype series had every CPU army lose 0-6 to Individuals and
    every CPU-vs-CPU match end in a 0-shot draw. Cause: a doctrine squad's `formation` alone means *form up and hold
    here* (`Squad.apply_command`), so CPU squads never left base. CPU armies now carry no formation (player presets
    keep it); regression test added. Re-measured series below.
- **Stretch: army codes done.** `army_code.gd`: `TS1` + 8-hex checksum + base64url(deflate(compact JSON)), ~150-200
  chars for a 5-unit army; URL/filename-safe; checksum refuses truncated pastes before decoding; inflate capped at
  16 KB. Garage SHARE panel (code shown, COPY to clipboard, paste + IMPORT) and `--army=CODE` (browser
  `?garage&army=CODE`). `make garage-cpu-army` prints a `GARAGE_CODE`. Anything the garage opens (load, preset, code)
  becomes a player army (`Loadout.make_player_army`: hold, formation, no CPU objectives). 5 tests.
- **GA4 measured** (after the fix; seed-1 armies; elimination, 300 s cap; every pairing in both team orders; Individuals
  6+6, archetype pairs 4+4). vs Individuals: Balanced 12-0, Rush 11-1, Flamers 12-0, Turtle 3-9. Round robin (24 games
  each): **Rush 22 wins, Flamers 17, Balanced 7, Turtle 2**; no draws. Reading: rush and flamers close fast, which the
  current rules reward (fights 30-80 s sim); turtle is too passive and loses long (160-290 s) matches. Balance is
  gameplay's call (their backlog item 13); CPU variety is what GA4 is for. Reproduce: build armies with
  `make garage-cpu-army PRESET=<p> SEED=1`, then `tools/match_series.py --extra="--elimination --green-doctrine=user://doctrines/cpu/<a>_1.json --rust-doctrine=…"`.
  - One time-boxed Turtle pass (objectives -18..-10 forward instead of -32..-22, caution 0.55-0.7, support targets
    most_exposed): vs Individuals 5/12 (was 3/12), vs Balanced 2/8 (same), vs Rush 0/8 (same). Kept; further balance
    is gameplay's.
- **Stretch: readable trade-offs, comparison, paint, first-run tips done.** `garage_advice.gd`: per-unit hints from stat
  keywords ("Laser runs hot: add a heat sink", "finite ammo: consider extra ammo", "close range: flank or ambush"),
  shown in EQUIP; COMPARE (bottom of UNITS) opens unit and weapon tables with derived damage/s and the best value
  per column highlighted. Paint shows in the skirmish via `GarageMode.paint_tanks` (visual only, deferred after
  Match's team paint; an adapter until Match reads `paint`). `garage_tutorial.gd` (now `garage_settings.gd`): a 3-step tip bar that advances
  as the player selects, edits, and fights (X skips), progress in `user://garage.cfg`; the first skirmish posts 3
  `Hud.post_message` tips. `--garage-panel=compare|share` for screenshots. 7 tests (paint test mutation-checked).
- **Browser verified.** `make garage-web-smoke`: `?garage` boots (turntable renders under WebGL/SwiftShader) and
  `?garage&garage-autofight&enemy=cpu:rush` saves to `user://` (IndexedDB) and starts the skirmish with 5 v 5.
  `make web-smoke` passes. Screenshots reviewed.

### After the lead's answers (2026-09-14, morning)

- **Saving.** An army remembers the file it came from: SAVE and FIGHT update that file (even after a rename); a new
  army (starter, preset, code) gets an unused file name on first save (`my_army`, `my_army_2`…), so two armies with
  the same name never overwrite each other. The garage reopens on the army you last fought with. DELETE takes a
  confirming second tap and leaves the army open, unsaved, so SAVE undoes a mistake. `GarageTutorial` became
  `GarageSettings` (tips + last army). `--garage-scratch` (smoke, screenshots, browser smoke) uses in-memory
  settings and an emptied `user://garage_scratch/`, so automated runs never touch the player's saves or tips.
  4 tests.
- **Big armies (up to 20).** Limits live in `GarageCatalog` (`max_units`, `max_squads` from `Doctrine`; new
  `max_squad_size` = `Formations.MAX_MEMBERS` = 5, since formations place at most 5). Loadout refuses a 6th unit in a
  squad (add or move) and flags oversized squads; 10 phonetic squad names. The screen: squad panels wrap
  (`HFlowContainer`), ADD spills into the next squad with room (starting a squad if allowed) with a toast, and EQUIP
  has a **Squad** picker so moving a unit doesn't need a drag. The starter buys what the budget allows in squads of
  3 (more when needed); presets split an archetype squad into several capped squads. `GarageCatalog.preview()`: 20
  units / 6 squads / scouts, artillery, lasers, machine guns, mortars, for `make garage CATALOG=preview` (not
  playable: FIGHT is refused). 7 tests, incl. layout at 1280×720 and 2400×1080.

**Summary for the integrator:** the whole overnight backlog (GA0-GA4) and all four stretch items are done, plus the
morning follow-ups from the lead's answers (per-army saving, big armies up to 20). Nothing blocked. `make check`
(141 tests + `garage-smoke`), `make web-smoke`, and `make garage-web-smoke` pass on the last commit; sim baseline
unchanged (`e69acc63a64f319a`). Not rebased on `main`.

**Shared-file edits (all additive):** `game/modes/game_mode.gd` (`--garage` → `GarageMode`, after `--match`),
`game/main.gd` (one flag comment line), `Makefile` (`garage` in `LIGHT_GOALS`), `mk/core.mk` (`garage-smoke` added
to `check`), `_agents/workstreams.md` (Loadout fields contract row), `_agents/verification.md` (row 6e),
`_agents/orientation.md` (common-task row, trip-ups 38-39). Everything else is in `game/garage/`, `mk/garage.mk`,
`tests/test_garage_*.gd`, `tests/garage/`.

**Next steps:** adopt gameplay's real catalog when it lands (scouts, lasers, `COMPONENTS`, weapon costs) and delete
`STUB_COMPONENTS`; once gameplay raises `Doctrine.MAX_TANKS`/`MAX_SQUADS` (and spawn slots), playtest a real 20-unit
army end to end (today only `CATALOG=preview` shows one, and it can't fight); remove `GarageMode.paint_tanks` once Match reads `paint`; try the garage on a real phone (drag inside
scrolling columns); a "rematch / back to garage" button after VICTORY/DEFEAT (needs a hook in skirmish); look & feel's
styling pass.

**What to playtest** (morning):
- `make garage`: the starter army is ready, so tap FIGHT → planning pause with your army vs a fresh CPU Balanced army.
  Try: PRESETS → Flamers, tap a unit, swap its weapon, drag a unit chip to another squad, drag the TANK card onto a
  squad, COMPARE, SHARE → COPY, paint a tank pink and find it in the skirmish.
- Saving: SAVE, pick a preset, SAVE again (a second file, nothing overwritten); quit and `make garage` again (it
  reopens the army you last fought with); DELETE twice, then SAVE to bring it back.
- Big armies: `make garage CATALOG=preview` (20 units, 6 squads, scouts/artillery/lasers; FIGHT is refused). Tap ADD
  with a full squad selected (it spills into the next one) and use EQUIP → Squad to move a unit.
- Opponents: `make garage ENEMY=cpu:rush` (or turtle / flamers / a doctrine name); pin one with `--seed` by hand.
- Browser: `?garage` (and `?garage&army=<code>` from `make garage-cpu-army PRESET=flamers SEED=2`).
- Automated: `make garage-smoke` (in `make check`), `make garage-e2e`, `make garage-shots` → `build/screenshots/garage-*.png`.

**Decisions** (beyond the ones inline above):
- The army IS a doctrine dict (no parallel model), so save/load/match share one format and nothing converts.
- Garage UI built entirely from code in `game/garage/` (no `.tscn`), so look & feel can restyle via `GameTheme.ui`
  keys without merge conflicts; no shared scene edited.
- Taps and drags use Godot's GUI drag-and-drop (touch arrives as emulated mouse), with `set_drag_forwarding`
  instead of subclassing every control.
- FIGHT hands over in-process (GarageMode → SkirmishMode) instead of reloading the scene with new flags.
- CPU opponents default to `cpu:balanced` with a random seed per fight (variety), printed in `GARAGE_FIGHT`.

**The lead's answers (2026-09-14 morning):**
1. **Paint stays full-body.** Friend or foe will be shown by *accent lights* (look & feel), not by hull color.
2. **Armies will get much bigger: "maybe max 20"** once scouts and other cheap vehicles exist. The garage now handles
   that (see *Big armies* below); the cap itself is gameplay's `Doctrine.MAX_TANKS`.
3. **Saving: "go with what you'd recommend."** Done: armies keep their own file (see *Saving* below).

**Questions for the lead:** none open.

**Requests to other streams** (nothing edited in their paths):
- *Gameplay:* (0) **the lead wants armies of up to ~20 units**: raise `Doctrine.MAX_TANKS` (and `MAX_SQUADS`, e.g.
  6; squads stay ≤ 5 for formations), and give `Match.SLOT_X` more than 9 spawn slots (it wraps with `%` today, so a
  10th tank spawns on top of the first); the garage picks the new limits up automatically. (a) read `unit`,
  `weapons`, `components`, `paint` from doctrine tanks when classes land (fields in workstreams.md); (b) put `cost` on weapon profiles and `COMPONENTS` (id → {display_name, cost, description, stats})
  in `Units`, which the garage already picks up; (c) apply `paint` in `Match._build_tank` (full body, the lead
  confirmed), then `GarageMode.paint_tanks` can go; (d) consider letting a doctrine squad start in a formation *without* holding
  (today `formation` alone = hold at base, which silently parked every CPU army); (e) skirmish's status line
  shows the enemy's path (`user://doctrines/cpu/rush.json`); showing the doctrine `name` would read better;
  (f) backlog item 12 (CPU armies in skirmish) can call `ArmyPresets.build(archetype, GarageCatalog.from_game(), seed)`;
  (g) archetype results above: Rush 22/24, Turtle 2/24 in the round robin.
- *Look & feel:* **friend or foe is shown by accent lights, not hull color** (the lead: players paint their whole
  tank), so team identity needs a light/emissive accent on tank visuals, separate from paint. Style the garage by adding `garage_bg`, `garage_panel`, `garage_text_dim` to
  `GameTheme.ui` (read with fallbacks); the turntable uses theme slots, so new hull/turret art shows up there; a CyberFrame around panels would
  be welcome. Garage tips go through `Hud.post_message` after FIGHT.
- *Netcode:* army codes (`ArmyCode`, `TS1…`) are a compact portable format if armies ever travel over the wire or live
  server-side.

**Known issues:**
- Not verified on a real touchscreen: on a phone, a drag that starts inside a scrolling column might scroll the column
  instead of starting a drag (headless tests use emulated mouse events). Tap-based paths (ADD, tap to select, tap a
  weapon) work either way.
- Windows can't exceed the monitor, so `garage-shots` uses a 20:9 1800×810 window for the phone aspect; tap sizes at a
  true 2400×1080 are asserted in tests.
- The arena still renders behind the opaque garage screen (wasted GPU on phones); hide it if it matters.
- CPU archetypes are unbalanced under current rules (see GA4 measurements).

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. Landed on main for you: **`game/units/units.gd`** (unit catalog schema v0: `tank` only, with hardpoints, `DEFAULT_BUDGET`), and **`--player=` accepting a full path** (`make skirmish` → `--skirmish --player=user://doctrines/mine.json`). Gameplay grows the catalog in parallel (scouts, artillery, components), so code against the catalog's *shape*, never against a fixed list of units.

1. **GA0 loadout model** (`game/garage/loadout.gd`): an army = squads of units, each with `unit`, `weapons` by hardpoint, `components`, `paint`, and optional directive/role. Validate against `Units` + `Weapons`, compute cost vs budget, and serialize to **doctrine JSON that today's `Doctrine.parse` still loads** (keep `weapon` for the main hardpoint, add the new keys; that's the proposed "Loadout fields" contract in workstreams.md). Unit tests, including a round trip save → `Doctrine.load_file` → `Match.load_doctrine`. Note `Doctrine.MAX_TANKS` caps army size today; respect it and note a request if budgets want more.
2. **GA1 garage scene, touch first** (`game/garage/`): a budget bar, catalog cards with stat bars, add/remove units, pick weapons per hardpoint, drag units into squads, pick formation/role presets, and clear validation messages. Save/load under `user://doctrines/`. Placeholder styling from `GameTheme.ui`; 3D turntable preview via visual slots.
3. **GA2 flow:** a `--garage` launch flag (a minimal additive edit to `game/modes/game_mode.gd`, noted in merge notes) → garage → **FIGHT** → skirmish with the saved army. A `make garage` target in `mk/garage.mk`. Screenshot tests at desktop and phone aspect.
4. **GA3 end-to-end test:** a garage-built army runs a full headless match (match runner with the saved doctrine path; if the match runner only takes `res://` names, add a small adapter in your paths or note a request to gameplay).
5. **GA4 CPU armies:** seeded budget-constrained army archetypes (balanced, rush, turtle, flamers) so skirmish opponents vary. Offer them as presets in the garage too.
- **Stretch:** shareable army codes (a compact string that encodes an army), unit comparison view, cosmetics (paint via `set_team_color`-style slot methods), and a first-run tutorial hint flow using `Hud.post_message`.
