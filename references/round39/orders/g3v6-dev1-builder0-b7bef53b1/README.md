# G3 v6 dev read 1 (orders, round 39; DEV seeds, not judged)

- Machine: builder0 light lane, J4. Tree: b7bef53b1 (game code da9591207).
- Workload: `make native orders-probe`, 12 cells, dev seeds 3804-3809, n 6.
- Arms: `main:`; `g3:--place-clear=on,--place-clear-trigger=near,--place-clear-reach=on` (v5); `g3v6:` g3 + `--place-clear-seat=on`.
- Judge `orders_judge.py g3`: main -> g3 PASS, main -> g3v6 PASS (judge-*.txt).

| line | main | g3 (v5) | g3v6 |
|---|---|---|---|
| places cleared | - | 33 | 25 |
| place pairs < 12 m | 25 | 1 | 4 |
| never-in | 1 | 1 | 1 |
| contacts | 5,970 | 5,625 | 5,714 |
| crossing 5 route worst twitch | 43.2 | 42.9 | 29.9 |
| locks 5 route median twitch | 17.4 | 19.6 | 17.4 |
| crossing 3 route median / worst twitch | 12.7 / 22.5 | 7.9 / 13.0 | 7.9 / 15.6 |

v6 refuses the 8 moves whose deploy would re-seat (another shape or spacing at the moved place). It keeps those pairs close
(25 -> 4 v v5's 1, still inside the bar's 6.2). These seeds don't contain R38.51's failing cell (crossing 3 route s5201):
the guard is read on fresh seeds once CP39.1 lands (C39.3).
