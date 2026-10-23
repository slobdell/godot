# G1 v4 dev read 1: FAIL (dev seeds, not judged)

- Code: 087cd20b7's `--group-rank-shift=half` with `--group-lay=column` v `main:`, on f0a70f544. Builder0 light J4,
  TANK_SQUAD_SLOT_TIMEOUT=14400, 2026-10-23 ~06:50-07:18 PDT.
- Workload: dev seeds 3804-3809, n 6, streets + his click + yard_open. Judge `orders_judge.py g1`; output in verdict.txt.
- Deciding lines all pass. Guards fail: crossing 5 route never-in 0 -> 1, twitch 22.2 -> 33.5, and yard_open 91/96 rows
  identical (5 click s3806).
- On the laptop, v3 lays a column on yard_open s3806 as well, so that miss is v3's own on this seed. A three-arm read
  (main v v3 v v4) separates the two.
