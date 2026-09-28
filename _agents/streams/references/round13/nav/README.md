# Round 13 nav evidence (rescued from the worktree's git-ignored build/ and scratch)

- `rigyield_sheet_seed7_leg0.jpg` — `make nav-yield-clip`, builder0, code `42497bba` (+ the clip case, `8f517ced`):
  the Terminus drive's rigs squad, seed 7, first leg, frames 20/60/100/160 (every 3 ticks: ~1, 3, 5, 8 s). Top row
  `off` = round 12 (`--nav-off=yieldfit`): Green_S0_1 backs its trailer into the block by the container (72 yield
  reverse ticks, the drive's own number). Bottom row `on` = R2: no back-up into the block (0), but the squad is slower
  through this corner (forward route scrapes 108 -> 306 in the 25 s).
- `rigyield_{off,on}.mp4` — the two clips.
- `r1_yield_buckets.txt` — R1's tables (HEAD and round 11's arm).
- `r2_drive_16seeds.txt` — R2's drive table and buckets, 16 seeds x 2 squads, three arms.
- `drive_and_fight_logs.tar.gz` — the raw `nav-terminus-drive` logs behind both (with `NAV_YIELD` / `NAV_YIELD_UNFIT`
  lines) and `nav-fight-maps` rotation both arms (`fm_off` = `--nav-off=yieldfit`, `fm_on` = R2), seed 3.
Numbers and their reading: `_agents/streams/archive/round13/nav.md` (the brief's Status) once archived.
