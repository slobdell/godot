# Round 39 settle item 3: o2's crossing re-deals, traced (builder0 light, native)

- Dev read (82c0a9db2 tree = main 8952c3d64 + settle's OFF code; crossing 3-squad click fight probe, budget 1500, round-38 H/S3
  dev seeds 3891-3902, n 12 fights an arm): parked re-deals held 22 -> o2 35 (`dev-rows-3891-3902.jsonl.gz`). Round 38's traced
  cells (s3894/s3895 squad 2) no longer reproduce on rules-ON main (0 and 0).
- Traced: s3895 squad 1 (Alpha; held 0, o2 4, one loss in each) and s3899 squad 1 (0 -> 1), `--element-trace=Alpha --arrive-trace
  --probe-trace=1`; `goals.py <log>` prints each crew's goal changes.
- s3895 o2: every counted re-deal is ONE crew's seat (Alpha_2) moving while the anchor (-85.6, 56.2), heading, shape (herringbone,
  4), the latched lanes / 10 m spacing and its seat index stay: asked (-99.4, 41.8) -> (-101.3, 59.1) at t=48-49, back at t=79, out
  to (-103.5, 53.4) at t=92 (ARRIVE_GOAL key "drift", 18.0 / 18.0 / 14.5 m). No other crew's seat moves.
- Probable cause: UnansweredFire (round 22 B1, doctrine's): a crew ON ITS POST hit by fire it cannot return moves to cover within
  COVER_M 25 m (or falls back), and its slot is set to that point (`_keep`). PARKED_HOLD keeps more crews on their posts, so more
  qualify, and the probe counts the move as a parked re-deal (a parked crew given a goal > 6 m off its station). In held, Alpha_2
  gets the same kind of move at t=78 while not parked: not counted.
- Not confirmed by a control arm: `--duck=off`, named in unanswered_fire.gd's header, no longer exists in tactics_flags.gd.
