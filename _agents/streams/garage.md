# Stream: Garage (pre-match equipping and squad building)

> Read [../workstreams.md](../workstreams.md), [../tank_brain.md](../tank_brain.md) (directives,
> doctrines), and [look_and_feel.md](look_and_feel.md). You own `game/garage/` (new) and
> `mk/garage.mk` (new); you produce player doctrine/loadout JSON consumed by skirmish.

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

## Overnight backlog (2026-09-14): work top to bottom, then keep going

Rules: *Unattended runs* in workstreams.md. Landed on main for you: **`game/units/units.gd`** (unit catalog schema v0: `tank` only, with hardpoints, `DEFAULT_BUDGET`), and **`--player=` accepting a full path** (`make skirmish` → `--skirmish --player=user://doctrines/mine.json`). Gameplay grows the catalog in parallel (scouts, artillery, components), so code against the catalog's *shape*, never against a fixed list of units.

1. **GA0 loadout model** (`game/garage/loadout.gd`): an army = squads of units, each with `unit`, `weapons` by hardpoint, `components`, `paint`, and optional directive/role. Validate against `Units` + `Weapons`, compute cost vs budget, and serialize to **doctrine JSON that today's `Doctrine.parse` still loads** (keep `weapon` for the main hardpoint, add the new keys; that's the proposed "Loadout fields" contract in workstreams.md). Unit tests, including a round trip save → `Doctrine.load_file` → `Match.load_doctrine`. Note `Doctrine.MAX_TANKS` caps army size today; respect it and note a request if budgets want more.
2. **GA1 garage scene, touch first** (`game/garage/`): a budget bar, catalog cards with stat bars, add/remove units, pick weapons per hardpoint, drag units into squads, pick formation/role presets, and clear validation messages. Save/load under `user://doctrines/`. Placeholder styling from `GameTheme.ui`; 3D turntable preview via visual slots.
3. **GA2 flow:** a `--garage` launch flag (a minimal additive edit to `game/modes/game_mode.gd`, noted in merge notes) → garage → **FIGHT** → skirmish with the saved army. A `make garage` target in `mk/garage.mk`. Screenshot tests at desktop and phone aspect.
4. **GA3 end-to-end test:** a garage-built army runs a full headless match (match runner with the saved doctrine path; if the match runner only takes `res://` names, add a small adapter in your paths or note a request to gameplay).
5. **GA4 CPU armies:** seeded budget-constrained army archetypes (balanced, rush, turtle, flamers) so skirmish opponents vary. Offer them as presets in the garage too.
- **Stretch:** shareable army codes (a compact string that encodes an army), unit comparison view, cosmetics (paint via `set_team_color`-style slot methods), and a first-run tutorial hint flow using `Hud.post_message`.
