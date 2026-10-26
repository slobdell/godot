# Bar G3 v9 judged read (orders, round 40): FAIL

- Tree: frozen detached worktree at 893180a31 (code 9076ee2f8; builder0 `make native check exited 0`, 25 passed + 2 NOT
  JUDGED), both parts `>> orders-probe on builder0 | commit 893180a31 | native on`. DEPLOY_HOLD ON both arms; T1, S1,
  every G1 / G2 switch OFF both arms.
- Machine: builder0 light lane, J4, `TANK_SQUAD_SLOT_TIMEOUT=14400`. Streets 384 of 384, his 48 of 48, try 1 each.
- Seeds: fresh 8213-8224, n 12 a cell. Arms `main:` v
  `g3v9:--place-clear=on,--place-clear-trigger=near,--place-clear-reach=on,--place-clear-seat=on,--place-clear-lane=column,--place-clear-after=relay`.
- Judge: `orders_judge.py g3` (verdict.txt), unamended from Bar G3 v6.

**VERDICT g3: FAIL** on the deciding line and one guard.
- FAIL deciding: place pairs < 12 m 48 -> 13 (bar <= 12.0). 12 of the 13 are main's own places, unmoved: crossing route
  cells (3 / 5 squads), where no step was taken. The 13th is new (s8220 crossing 5 route, squads 3 / 4).
- FAIL guard never-in: 5 -> 6; crossing 5 click 0 v 1 (s8220 squad 4, Delta).
- PASS: places_cleared 47; 0 of 864 placed > 40 m further (worst +24.0 m); contacts 15046 -> 15049.

**Traced (laptop, same game code, s8220 crossing 5 click, `--column-trace --probe-trace=4`, reproduces):** G3 moves
Charlie (-77.7, 29.7) -> (-86.4, 43.2) to clear its pair with Delta (-70.2, 29.5). The road test passes it: Delta's
one road (its block centre to its place, navmesh) is not within a column's reach. But Delta_4 and Delta_5 drive in by a
western loop ((-72, 75) -> (-84, 40)), and Delta_4 stands at (-84.3, 41.0), about 3 m from Charlie's halt, MOVE from t 55
to the end of the run. A squad's crews do not drive one road: a centre-to-place road misses the crews that go round.
