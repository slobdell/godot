# G1 v3 judged read: FAILS as filed (Bar G1 v3, amended tree 23983ab5b, latch ON)

- Code: f2a94b6cc's G1 v3 (`--group-lay=column`) on tree 23983ab5b; probe ran on b55757fee (docs-only over
  a67afc951, whose `make native check` exited 0 on builder0, 3112 passed, 0 failed).
- Machine: builder0, light lane, ORDERS_PROBE_JOBS=4, TANK_SQUAD_SLOT_TIMEOUT=14400, 2026-10-23 ~05:00-05:57 PDT.
- Workload: seeds 3951-3962 (judged), locks crossing terminus yard_open, 3 and 5 squads, click and route, arms
  `main:` v `column:--group-lay=column` (`streets/`); his click (-29.3/85.8) on terminus 3/5 (`his/`). n 12 per cell.
- Judge: `orders_judge.py g1` (streets + his rows; yard_open rows as the no-change cell). Output in verdict.txt.

```
PASS counter: columns_laid 82 (bodies kept 134)
PASS deciding: places outside the corridor (click cells) 99 -> 18 (<= 24.8)
PASS deciding: metres driven outside the corridor after being in it (click cells) 6567 -> 1233 (<= 3283)
PASS deciding: squads with crews re-dealt (arm) 0 (base 71)
PASS guard friend_contacts 15614 -> 12519 (<= 17180.4)
  FAIL guard never-in     crossing 5 route: 1 v 2
  FAIL guard never-in     locks 3 click: 0 v 1
PASS guard no-change cell yard_open: 192 of 192 squad rows identical
VERDICT g1: FAIL
```

What failed:
- Every deciding line passes by a wide margin. The FAILs are two never-in seeds.
- Crossing 5 route: column s3951, squad 5 at the west bridge mouth (-70.6/30.5); s3957, squad 3. Main's own never-in
  is s3958, squad 4, at the same mouth (-65.1/29.5).
- Locks 3 click s3960: column squad 3 is placed 79.5 m from the click (76.4/23.2) and never gets in.
- Terminus 5 route: main never-in 4 (s3953, s3955, s3957, s3962), column 1. Not a guard fail, but the arm gets in more.
