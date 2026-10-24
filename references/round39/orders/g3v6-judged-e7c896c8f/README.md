# Bar G3 v6 judged read (orders, round 39): FAIL

- Tree: as Bar G1 v5's (game code 632724c90, CP39.1 with DEPLOY_HOLD ON in both arms; `>> orders-probe on builder2 | commit
  e7c896c8f | native on`).
- Machine: builder2 (e2-highcpu-32 Spot), J14, `TANK_SQUAD_SLOT_TIMEOUT=14400`. It ran beside doctrine's D4 series; the load
  was 19 at launch.
  - The streets part was preempted on try 1 (exit 255, 32 of 384 runs; builder2 then showed "up 42 min").
  - The driver re-ran it whole: try 2 ran 384 of 384 and exited 0. His click ran 48 of 48 and exited 0.
- Seeds: fresh 6213-6224, n 12 a cell. Arms: `main:` v
  `g3:--place-clear=on,--place-clear-trigger=near,--place-clear-reach=on,--place-clear-seat=on`.
- Judge: `orders_judge.py g3` over the 18 cells (streets + yard_open + his click as terminus_his).

**VERDICT g3: FAIL** on two guards, both on crossing 5 route.
- FAIL never-in: 8 -> 10 overall; crossing 5 route 0 v 1.
  - g3 lost s6213 squads 4 and 5, and s6218 squad 4.
  - main lost s6218 squad 4 as well.
- FAIL twitch: crossing 5 route median 18.9 v 22.9 m (bar base + 3). The worst g3 rows are s6220 squad 5 (42.5 v main 0.1) and
  s6223 squad 4 (34.7 v 3.2).
- PASS:
  - deciding: place pairs closer than 12 m 48 -> 12 (<= 12.0)
  - counter: places_cleared 59
  - offsets: 0 of 864 more than 40 m further; worst +19.9 m
  - contacts: 13763 -> 13556
- Reported: parked_redeals (duck-excluded) 675 -> 643; ducks 0 -> 0.
- Likely cause, untraced: settle's S1 cause (B). A cleared place's own leg meets a passing squad head-on, and G3 checks nothing
  for it (orders Status, the S1 trace read). The dry run (s3801) showed the same cell's twitch.
