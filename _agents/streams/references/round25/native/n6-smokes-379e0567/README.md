# N6 smokes on the laptop (flightdeck, 379e0567 = green 94c26255 + mk help lines and docs), 2026-10-10 ~13:40

All runs: his laptop, `RENDER_PRESET laptop (adapter) 'Mesa Intel(R) UHD Graphics 620'`, the worktree's own user dir
(`tank_squad_native`, not his), 1854x1011.

- `garage-cap.png` / `garage.log`: the garage opening a saved FIVE-squad Road Gangs army (`five_squads.json`: Alpha..
  Echo, 5 Rat Rods each). Looked at: the status line reads "This machine fields 4 squads: kept your first 4, left out
  the last one."; four squads Alpha-Delta of 5/5 (20 Rat Rods); no slot for a fifth; credits as before (2000, 1200 left).
- `garage-fight.log`: the same army, FIGHT (autofight, seed 4242): `ARMY_CAP preset=laptop squads=4 units=20`,
  `ARMY_CAP_FIELDED green_squads=4 green=20 rust_squads=4 rust=17` (the CPU's Condemned ran out of the same 2000 CR at 17).
- `skirmish-faction.png` / `.log`: `--skirmish` Law v Road Gangs (the faction menu's path, baseline budget), seed 4242,
  foundry: 20 v 20 in 4 squads a side (on the desktop the same match is ~30 a side). Looked at: LOOK LIGHT, four squad
  chips (3 + 7 + 7 + 3). The planning hint still says "1-5" (UI text, not native's: noted for the orchestrator).
- `skirmish-plain.log`: `--skirmish` with no factions (player_default v cpu, 1000 pts): 5 v 5, under the cap, unchanged.
