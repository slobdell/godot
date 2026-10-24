# G1 v5 dev read 1 (orders, round 39; DEV seeds, not judged)

- Machine: builder0 light lane, J4, load 20-47 (other lanes and doctrine's full check). Tree: 93a6c2283.
- Workload: `make native orders-probe`, locks / crossing / terminus x 3 / 5 squads x click / route, dev seeds 3804-3809, n 6.
- Arms: `main:`; `v4:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached`; `v5:` v4 + `--group-lead=drive`.
- Judge: `orders_judge.py g1v4` (judge-*.txt).

| line | main | v4 | v5 |
|---|---|---|---|
| places outside the corridor (click cells) | 14 | 1 | 1 |
| metres outside after being in (click cells) | 1,011 | 145 | 168 |
| re-dealt (click cells) | 12 | 0 | 0 |
| friend contacts | 5,970 | 5,651 | 5,013 |
| never-in, terminus 5 route | 1 | 2 | 2 |

- v4 -> v5: every probe guard passes and contacts fall 5,651 -> 5,013. The v4-v-v5 "deciding" FAILs are the main-bar
  lines read against v4 as base (1 -> 1 outside; 145 -> 168 m): not a bar here.
- The one guard both arms fail against main: terminus 5 route s3805 squad 1 (start (-58.1, 95.8), anchor (-38.5, 24.3),
  stopped 18.2 m off it). No column was laid on that run (columns_laid 0) and v4 / v5 rows match, so G1 v5's lead
  ordering is not the cause. It is v4's squads-whole on the route's first plain click (R38.44), and it is not traced yet.
