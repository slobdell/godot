# Bar G1 v9 (orders, round 41): PASS

- Tree: frozen detached worktree at 872dab643 (full check green on builder0: exited 0, 25 passed, 2 NOT JUDGED for a busy box).
- Machine: builder2 (e2-highcpu-32, Spot), native on, seeds 9101-9112, n 12 per cell, jobs 8.
- Arm: `v9:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached,--group-lead=drive,--group-sides=both,--group-column-toward=stay` v `main:`.
- Runner: `tests/control/orders_bar.sh b2 g1v8 <arm> "9101 ... 9112" <out> 8`; judge `orders_judge.py g1v8`.
- `verdict.txt` is the judge's output. `streets/` and `his/` are the raw rows/runs. The judged_* / yard_rows files
  are rebuilt from them by the python block in `orders_bar.sh`.
