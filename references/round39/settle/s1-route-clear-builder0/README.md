# Bar S1 route-clear series (round 39, settle) — FAIL

- Code: 6ab14f1ac (route-clear v2 = daea2cefe's), full check green on builder0 before the series.
- Machine: builder0 light lane, J 4. `tools/remote.sh --light native settle-s1c TANK_SQUAD_SLOT_TIMEOUT=14400`
  (`>> remote: make native settle-s1c ... exited 0`), 2026-10-24.
- Arms: `main:--deploy-trace` v `clear:--seat-route-clear,--deploy-trace`. Seeds 6001-6012 no-fight probe (12 cells, 576
  squads an arm), 6013-6024 fights (3-squad budget 1500, 5-squad budget 3000, 36 fights an arm each).
- `verdict.txt` = `settle_judge.py s1c`. `table.txt`, `halt_flips.txt`, `rows.jsonl.gz`, `runs.jsonl.gz` as the probe wrote them.
- `logs/`: terminus 5 click, terminus 5 route, crossing 5 route x main/clear x s6003/6006/6009 (every never-in run on both arms,
  with the deploy traces).
