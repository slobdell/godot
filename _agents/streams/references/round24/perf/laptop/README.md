# Round 24: the laptop table with native ON (`pf-r24-base`), 2026-10-08 ~22:50 → ~23:50 PDT

**Command:** `make perf-fight PERF_FIGHT=size PERF_FIGHT_SIZES="25 30" PERF_FIGHT_NAME=pf-r24-base` on the laptop
(Intel UHD 620, 1854×1011, his `laptop` preset, 12 phases × 10 s, foundry + parade, seeds 31337 5988 92721, arm
`main` = CPU leaders ON). **Code = main `b6bd539a`** (round 23's close + brains CP1, the bridge: no perf change
expected). **Native ON:** `make native-info` → `built on flightdeck`, gcc 13.3.0, switch on (every round-23 port that
ships ON: dodge, ORCA, cover, the navmesh index; `native_move` OFF). Load 0.50 before; ~2.4 during (the two workers'
Claude processes; no other Godot on the laptop, checked). n = 3 seeds per (size, arena). The per-run JSON is the
`PERF_FIGHT {...}` line in `pf-r24-base.log`.

| size (a side) | arena | avg frame ms (31337 / 5988 / 92721) | p95 frame ms | tick ms (run mean) | tick at 16 s, everyone alive |
|---|---|---|---|---|---|
| 25 | foundry | 28.3 / 23.4 / 20.8 | 85 / 50 / 46 | 21.8 / 19.9 / 17.9 | **33.9 / 34.3 / 33.2 ms** at 41 / 39 / 37 alive |
| 25 | parade | 26.7 / 26.7 / 24.6 | 65 / 70 / 59 | 20.4 / 20.3 / 19.6 | **35.9 / 34.1 / 34.0 ms** at 40 / 43 / 41 alive |
| 30 | foundry | 28.3 / 30.3 / 28.3 | 106 / 102 / 104 | 22.1 / 23.5 / 22.0 | **40.7 / 41.3 / 39.4 ms** at 50 / 49 / 47 alive |
| 30 | parade | 29.3 / 28.5 / 36.3 | 91 / 90 / 116 | 22.0 / 21.8 / 24.3 | **42.4 / 42.8 / 41.8 ms** at 49 / 50 / 52 alive |

**Against round 23's baseline** (`references/round23/perf/laptop/`, main `68b97663`, no native): 25 a side, everyone
alive in contact, **39–40 → 33–36 ms a tick (−10 to −15 %)**; run means 22.5–24.7 → 17.9–21.8 ms; avg frame 27.7–33.7 →
20.8–28.3 ms; still ~3 catch-up ticks a frame in the first 20 s (frame 122–136 ms). Less than round 23's "~30 ms by
proportion" (the headless band's −25 % does not carry whole to the windowed tick: the rest of the tick is physics,
elements, match).

**For the cap (C24.4):** the bar is 50 a side in contact ≤ 25 ms a tick; 25 a side in contact is 33–36 ms today, so
the per-vehicle cost must still fall ~2.7–3× for 50 a side. **The cap stays 5 squads / 25.** N3 (native's drive and
think) is what this table is re-run against.
