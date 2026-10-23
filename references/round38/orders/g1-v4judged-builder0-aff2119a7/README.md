# Bar G1 v4 judged read (orders, round 38)

- Tree: game code ab31e9bc2 (builder0 full check green); aff2119a7 is its docs-only descendant.
- Machine: builder0, light lane, J4, `TANK_SQUAD_SLOT_TIMEOUT=14400`. Workload: `make native orders-probe`.
- Cells: 12 street cells plus his click (`his/`, judged as terminus_his) and yard_open.
- Seeds: fresh 4701-4712, n 12 a cell.
- Arms: `main:` v `column:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached`.
- Judge: `orders_judge.py g1v4`. Verdict: `verdict.txt` in this dir.

**VERDICT g1v4: FAIL** on one guard cell. Never-in on crossing 3 click: 0 v 1.
- The squad: s4710 squad 2. It drove 113 m and stopped 12.9 m off its anchor without arriving.
- Every other line passes:
  - places outside the corridor: 82 -> 20 (bar <= 20.5);
  - metres driven outside it after once inside: 4974 -> 1328 (bar <= 2487);
  - re-dealt: 0;
  - contacts: 12910 -> 10746;
  - yard_open: 192 of 192 rows identical.
