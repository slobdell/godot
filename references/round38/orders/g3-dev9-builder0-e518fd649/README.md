# G3 v4 dev read 9: PASS (dev seeds, not judged)

- Code: e518fd649, `--place-clear=on,--place-clear-trigger=near` v `main:`. The tree is main e1f602fbf with the latch ON.
- Machine: builder0, light lane, J4, TANK_SQUAD_SLOT_TIMEOUT=14400, 2026-10-23 06:05-06:35 PDT.
- Workload: dev seeds 3804-3809, n 6 per cell, locks crossing terminus yard_open, 3/5 squads, click/route, plus his click
  (`../g3-dev9his-builder0-e518fd649/`), 18 cells. Judge `orders_judge.py g3`; output in verdict.txt.
- Every line passes: close pairs 25 -> 1, never-in 1 -> 1, 0 of 432 rows placed > 40 m further, worst +25.2 m,
  contacts 7,183 -> 6,832, probe guards PASS (twitch included).
