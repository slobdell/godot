# Stream: Garage (pre-match equipping and squad building)

> Read [../workstreams.md](../workstreams.md), [../tank_brain.md](../tank_brain.md) (directives,
> doctrines), and [look_and_feel.md](look_and_feel.md). You own `game/garage/` (new) and
> `mk/garage.mk` (new); you produce player doctrine/loadout JSON consumed by skirmish.

## Goal

Before a match, the player builds their squads: which tanks, what equipment, which squad each
is in and in what role, plus cosmetics. The output is **data**: a doctrine the match loads
(`--player=<name>`), so the garage never touches simulation code.

## Dependencies, and what can start now

| Needs | From | Until then |
|---|---|---|
| What equipment exists and its trade-offs (hull classes, weapons, utilities) | gameplay | Build the data model and UI against today's weapons (`Weapons.PROFILES`) |
| The look (turntable scene, UI style) | look & feel | Use the `default` theme through visual slots, so art swaps in later for free |
| Where saved squads live for online play | netcode | Save locally under `user://` |

## First milestone

1. **Loadout schema:** extend the doctrine format (e.g. per tank: `hull`, `weapon`, `utility`, `paint`), validated in `Doctrine.parse`. Agree on the fields with gameplay; that's a contract change (workstreams.md).
2. **A garage scene:** a squad roster with add/remove tank, weapon pick, squad and role assignment, and a 3D turntable preview built from visual slots. Save/load to `user://doctrines/`.
3. **Launch the skirmish with the saved squad** (`--skirmish --player=<saved>`), and a test that a garage-built doctrine loads and validates.

## Status

- 2026-09-13: brief written. Blocked on nothing for the data model; art waits for look & feel v1.
