# Stream: Garage (pre-match equipping and squad building)

> Read [../workstreams.md](../workstreams.md), [../tank_brain.md](../tank_brain.md) (directives,
> doctrines), and [look_and_feel.md](look_and_feel.md). You own `game/garage/` (new) and
> `mk/garage.mk` (new); you produce player doctrine/loadout JSON consumed by skirmish.

## Goal

Before a match, the player **spends a budget** on an army (the lead, 2026-09-14): scouts, tanks,
artillery, possibly chassis configured with weapons MechWarrior-style. They assign units to squads
and roles, plus cosmetics. The output is **data**: a doctrine the match loads
(`--player=<name>`), so the garage never touches simulation code.

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
