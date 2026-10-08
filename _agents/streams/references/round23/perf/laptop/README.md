# Round 23: the laptop baseline (`pf-r23-base`), 2026-10-07 23:38 → 00:18 PDT

**Command:** `make perf-fight PERF_FIGHT=size PERF_FIGHT_SIZES="25 30" PERF_FIGHT_NAME=pf-r23-base` on the laptop
(Intel UHD 620, 1854×1011, his `laptop` preset, `--perf-drive=12`, 12 phases × 10 s, foundry + parade, seeds 92721
31337 5988, arm `main` = CPU leaders ON). **Code = main `68b97663`** (the tree at `46764993`, docs only above
`68b97663`; the report's header says `1c14fd5a` because the orchestrator committed docs and `tools/remote.sh` while
the run was going; no game file changed). Load 0.26 before, 0.90 after; during the series the three round-23 workers
were reading and using builder0 (no local Godot; load 2.8 at the first run's end, their Claude processes). n = 3 seeds
per (size, arena). Files: `pf-r23-base-<size>-<arena>-main-<seed>.json` + `.txt`, the log with the table and the
per-phase timelines.

| size (a side) | arena | avg frame ms (3 seeds) | p95 frame ms | tick ms (run mean) | tick at the start, everyone alive | speed |
|---|---|---|---|---|---|---|
| 25 | foundry | 27.7 / 28.2 / 33.7 | 73 / 75 / 114 | 22.5 / 22.9 / 24.7 | **39–40 ms at 37–41 alive** (frame 141–149, 3.1 ticks a frame) | 0.94–0.96 |
| 25 | parade | 30.4 / 32.2 / 32.3 | 95 / 108 / 112 | 22.8 / 23.0 / 24.3 | (see the log) | 0.94–0.95 |
| 30 | foundry | 29.4 / 37.6 / 38.9 | 103 / 127 / 133 | 23.6 / 25.7 / 26.8 | ~50 alive at the start | 0.92–0.94 |
| 30 | parade | 34.0 / 35.4 / 46.6 | 113 / 124 / 145 | 24.5 / 24.7 / 27.5 | | 0.91–0.93 |

**The fact for the cap (C23.3):** on the laptop, 25 a side (50 vehicles on the field, all alive and in contact in
the first 20 s) costs **~40 ms a tick** and the frame runs three catch-up ticks (147 ms); once the fight thins to
~20 alive the tick is 17–20 ms and the frame 20–23 ms. The run means (22–27 ms a tick) are dominated by the thinned
fight. The bar for 50 a side (100 vehicles) is ≤ 25 ms a tick in contact: today's cost at 50 alive is 40, so the
per-vehicle cost must fall by roughly 3–4× (0.8 → 0.25 ms a vehicle a tick on the laptop) for 50 a side; for 25 a
side to hold 30 fps in contact it must fall by ~1.6×. ui 3–8 ms, gpu 9–13 ms a frame: the tick is the whole problem
(perf's P2 verdict holds on the laptop).
