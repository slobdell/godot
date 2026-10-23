# G1 three-arm dev read: main v v3 v v4 (dev seeds, not judged)

- Code: 7bfb06384 (latch ON). Arms `main:`, `v3:--group-lay=column`, `v4:--group-lay=column,--group-rank-shift=half`.
- Machine: builder0 light J4, TANK_SQUAD_SLOT_TIMEOUT=14400, 2026-10-23 ~07:50-08:20 PDT. Dev seeds 3804-3809, n 6.
  Cells: streets + his click + yard_open. Judge `orders_judge.py g1`, each arm against main; output in verdict.txt.
- Both arms FAIL on the same guards: crossing 5 route never-in (v3 0 -> 2, v4 0 -> 1), crossing 5 route twitch
  (22.2 -> 33.5 both), and yard_open 91/96 (5 click s3806 lays a column in both). Every deciding line passes for both.
- Reading: the rank cap causes none of v4's fails. They belong to the column itself, on these seeds and with the latch ON.
