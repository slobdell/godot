# Bar G1 v5 judged read (orders, round 39): FAIL

- Tree: game code 632724c90 = main 2518811d0 merged (CP39.1, settle's DEPLOY_HOLD ON in both arms; `--giveway-chain` and
  `--seat-route-clear` OFF). Its builder2 full check is green: 3169/0, 24 passed + 3 NOT JUDGED. e7c896c8f is its
  docs + driver descendant (`>> orders-probe on builder0 | commit e7c896c8f | native on`).
- Machine: builder0, light lane, J4, `TANK_SQUAD_SLOT_TIMEOUT=14400`. It ran beside main's batch check and a builder2 series.
  Driver: `tests/control/orders_bar.sh b0 g1v4 ...` (both parts `exited 0`, 384 + 48 runs).
- Seeds: fresh 6201-6212, n 12 a cell. Arms: `main:` v
  `column:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached,--group-lead=drive`.
- Judge: `orders_judge.py g1v4 judged_rows main column judged_runs yard_rows`. His click rows are relabelled terminus_his.

**VERDICT g1v4: FAIL** on one deciding line and one guard cell.
- FAIL deciding: places outside the corridor, click cells, 100 -> 28. The bar is <= 25.0.
  - Per cell, main -> column:
    - crossing 3: 14 -> 0
    - crossing 5: 26 -> 5
    - locks 3: 4 -> 3
    - locks 5: 8 -> 8
    - his 3: 12 -> 0
    - his 5: 36 -> 12
- FAIL guard: twitch on terminus_his 5 click, median 2.0 v 8.2 m; worst 13.8 v 28.4 m. Squad 2 twitches 28.4 m on every seed
  (main: 0.0), so it is one deterministic layout of his click, not seed noise.
- PASS:
  - metres outside after being in it: 6490 -> 1832 (<= 3245)
  - re-dealt: 0 (base 48)
  - contacts: 14280 -> 11413
  - yard_open: 192 of 192 rows identical
  - every other guard cell
- Reported: parked_redeals (duck-excluded) 487 -> 511; ducks 0 -> 0.
