# O2 dev reads (round 41, orders): the departure order, three variants, all OFF

Workload: `make orders-group` (his five full squads, crew headings, one click across the map, 180 s window), crossing /
locks / sumps / terminus, dev seeds 7001-7006, n 6 a map; builder0 light lane, native on. `main` runs are dev read 1's
(25525980a; main's code is unchanged by every later commit, all OFF). Judge: `tests/control/orders_group_judge.py` (group
part only; parts B / C were never run). judge.txt in each folder.

| read | commit | arm | paired all-in (s) | never-in squads | waited (of 120) | wait median | cap releases |
|---|---|---|---|---|---|---|---|
| 1 | 25525980a | `--group-depart=queue` (front first, 30 m corridor) | -7.9 +/- 7.6 | 15 -> 14 | 18 | 5.1 s | 0 |
| 2 | 3d35eee6f | + `--group-depart-rank=drive` | -1.0 +/- 2.0 | 15 -> 11 | 16 | 3.7 s | 2 |
| 3 | b8116ec21 | `--group-depart=merge` (merge-point timing) | -8.7 +/- 6.6 | 15 -> 8 | 40 | 18.0 s | 17 |

Read 1's locks got worse (median 73.5 -> 87.6 s) and sumps better (120.0 -> 56.5). Read 3 is the only one that moves
never-in, and it does so by holding squads a median 18 s (17 of 40 released by the 20 s cap, 18 of 24 clicks with a
squad waiting > 5 s): he would see squads that did not hear him. Three variants on the same seeds: read 3's gain is
partly fitted. Conclusion: departure order is not where the time goes; the time is crews meeting inside the merges
(manoeuvre's Q1 census: stalled / crossing / same_way blockers), which is what a blocked crew does, not when it left.
