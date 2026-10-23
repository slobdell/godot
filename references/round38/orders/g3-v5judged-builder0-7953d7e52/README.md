# Bar G3 v5 judged read (orders, round 38)

- Tree: game code ab31e9bc2 (builder0 full check green, 27/27 all judged, 3121/0); 7953d7e52 is its docs/evidence descendant.
- Machine: builder0, light lane, J4, `TANK_SQUAD_SLOT_TIMEOUT=14400`. Workload: `make native orders-probe`, 18 cells.
- Seeds: fresh 5201-5212, n 12 a cell. Arms: `main:` v `g3:--place-clear=on,--place-clear-trigger=near,--place-clear-reach=on`.
- His click cells are in `../g3-v5judgedhis-builder0-7953d7e52/`. Judge: `orders_judge.py g3`. Verdict: `verdict.txt` in this dir.

**VERDICT g3: FAIL** on one guard cell. Twitch on crossing 3 route: 5.5 v 8.8 against base + 3 m.
Every other line passes:
- pairs closer than 12 m: 48 -> 3;
- never-in: 7 -> 7;
- placed more than 40 m further than main: 0 of 864; worst +27.0 m;
- contacts: 14841 -> 14190.

The cause is squad 2 of 3 on crossing route. Its twitch rises to 16-23 m on s5201, 5204, 5208, 5209 and 5212 (main: 0-6 m).
