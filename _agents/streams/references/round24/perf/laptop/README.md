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

## Re-run after native's drive seam: `pf-r24-n3c`, main `c4f4a50c`, 2026-10-09 00:45 → 01:14 PDT

Same command and arms (`PERF_FIGHT_NAME=pf-r24-n3c`); code = main `c4f4a50c` (+ native N3a–N3c: `native_drive`,
`native_path`, `native_scan` ON; the library rebuilt on flightdeck from that tree, `make native-info` switch on). Load
0.40 before, ~2.2 during (the workers' Claude processes; no other Godot). n = 3.

| size | arena | avg frame ms | p95 | tick (run mean) | tick at 16 s, everyone alive | v `b6bd539a` |
|---|---|---|---|---|---|---|
| 25 | foundry | 25.4 / 22.6 / 21.5 | 64 / 44 / 44 | 20.4 / 18.9 / 19.1 | 32.4 / 32.9 / 31.6 at 39 alive | 33.2–34.3 |
| 25 | parade | 25.5 / 27.4 / 29.3 | 61 / 71 / 69 | 19.9 / 21.2 / 21.0 | 33.1 / 32.7 / 32.2 at 40–42 | 34.0–35.9 |
| 30 | foundry | 29.7 / 29.8 / 26.0 | 104 / 99 / 74 | 23.0 / 22.4 / 21.3 | 39.4 / 38.6 / 37.7 at 48–50 | 39.4–41.3 |
| 30 | parade | 28.6 / 29.9 / 29.8 | 74 / 108 / 96 | 21.3 / 22.5 / 22.7 | 40.1 / 39.4 / 39.6 at 50–52 | 41.8–42.8 |

**Reading:** the tick in contact moved ~−4 to −6 % (25 a side 33–36 → 31.6–33.1 ms), while native's headless brains band
at 25 v 25 fell −34 % (7ebdc122, flightdeck, n = 2). The brains are no longer most of the windowed tick on the laptop
in contact: the rest (physics, elements, match, projectiles, the frame's catch-up overhead) needs its own breakdown
before the next port is chosen. Asked of native: a windowed, in-contact (first 20 s) tick breakdown on the laptop.
The cap stays 25.

## Brains' feed cache priced in contact (`make native-tick-profile`, main `59a161f2`, 2026-10-09 ~03:10 → 03:50 PDT)

Arms `feedon` (default) v `feedoff` (`--feed-cache=off`), laptop flightdeck, his preset, 25 a side, foundry + parade × 3
seeds, window 8–20 s (the opening contact, 49–50 alive at 8 s), native as shipped at `59a161f2` (drive/path ON;
situation/matchups/scan OFF; decide not yet merged). Load 0.5 before. Files: `tp-feed-59a161f2/`.

Tick scripts (ms a tick), paired by arena × seed — off / on: foundry 34.3/34.2, 35.6/33.2, 33.5/33.6; parade 34.9/33.2,
35.0/33.5, **42.6**/34.4. Means 36.0 → 33.7 (−2.3), but the parade-92721 OFF run is an outlier (+8 ms, the box or
the run); **without it the paired saving is −1.1 ms (se 0.47) ≈ −3 % of the tick's scripts**, every pair ≥ −0.1.
Controllers 26.6 → 24.5. Brains' builder0 expectation was ~0.3 ms at 50 v 50 (~0.8 ms on the laptop): the laptop in
contact agrees at about 1 ms. Equal answer (element-digest, thirteen lines, state_hash), so it stays ON.
