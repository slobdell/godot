# Bar H v2 DEPLOY_HOLD series (round 39, settle) — PASS

- Tree: cd7a272d0 (code = dbc022357's = 6ab14f1ac's game code; settle-h2 target + h2 judge). builder0 light lane, J 4,
  `tools/remote.sh --light native settle-h2 TANK_SQUAD_SLOT_TIMEOUT=14400` (`>> remote: make native settle-h2 ... exited 0`), 2026-10-24.
- Fight probe locks/crossing/terminus x 3 squads x click x seeds 6025-6048 (72 fights an arm), budget 1500.
  Arms main:--deploy-trace v held:--deploy-trace,--deploy-hold=on. Judge `settle_judge.py h2` -> verdict.txt.
- REDEAL_TRACE re-lays after a loss 288 -> 0 (crews moved 367 -> 0); other causes 0 -> 0; fights flat (his kills 5.39 -> 5.31,
  his losses 6.99 -> 6.64, CPU losses 5.44 -> 5.33, se 0.26/0.35/0.26). Reported: parked_redeals 172 -> 100, reseats 244 -> 1.
- Shipped ON at 2478e2eef (merged with main f1fb16131).
