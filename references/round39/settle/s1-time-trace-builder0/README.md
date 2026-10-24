# S1 route-clear: time trace of the three never-in runs (round 39, settle) — round-40 input

- Tree: a52661bf3 (main 2316bc4f7's code + settle docs), builder0 light, J 4, `orders-probe` terminus/crossing x 5 squads x
  click/route x seeds 6003/6009, arms main v clear (`--seat-route-clear`), both `--deploy-trace --deploy-hold=off
  --element-trace=all` (hold off = the series' state; no fights, so no losses either way). Dev trace, not judged.
- The three never-in runs reproduce on this tree exactly (arrival times identical to the series on 6ab14f1ac).
- Read with `python3 tests/settle/settle_stuck.py <log> <Squad> <every_s>` (each crew: position, metres off its slot, speed,
  the two nearest friendly crews of other squads).
- Findings: settle.md Status, "Round-40 input".
