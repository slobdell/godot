# Bar M (round 47, manoeuvre M3): a station pinned in a building follows the squad's track — PASSES on every line

Frozen tree **1aa41aeaf** (check builder3 `>> remote: make check exited 0`, 3522 passed / 0 failed). Arms BASE v BURIED
(`--traffic-on=buried`), both `--noprogress-census`, native ON (no twin needed: the rule changes the goal TankBrain hands the drive, in
GDScript on every path; native confirmed, R47.x). Filed in streams/manoeuvre.md before any number; amendment 1 (the pinned trigger)
before any number.

- **W1** (deciding): orders' group-order probe, terminus / crossing / locks / sumps, crew headings, seeds 12401-12424, 96 paired cells,
  series tree 4ab917680 (1aa41aeaf's code + the series make target + a staged test), `make manoeuvre-bar-m-series` exited 0.
  `w1-g8-judge.txt`, `w1-runs.jsonl`, `w1-census-rows.txt`.
- **G8**: engage's authority probe 12443-12448, both arms: 6 of 6 identical (`w1-g8-judge.txt`).
- **W2** (G7, both sides): route's `route-census` (CPU v CPU, 150 s), seeds 12425-12448, tree 5f96c2d45 (4ab917680 + main for the census
  tool; movement.gd and tank_brain.gd byte-identical to 1aa41aeaf), both `route-census` runs exited 0: 24 fights paired, 0 swaps,
  every line identical (the flag reached the arm: its `flags` echo; the census ran). `w2-judge.txt`, `w2-run.txt`.

| Line | Read | Verdict |
|---|---|---|
| D1 his staged Locks case | Burners2_4 0.0 s (BASE 3.47) | PASS |
| D2 touched cells noprog_s | -24.9 crew-s a cell (se 28.5), sooner-or-identical 54 % | PASS |
| D3 all cells noprog_s | z -0.87 | PASS |
| G1 all_in_s | z -0.20 | PASS |
| G2 never_in | 25 -> 23 | PASS |
| G3 contact_s | 6589 -> 6249 s, z -0.77 | PASS |
| G4 blocked_s / yielding_s | z -0.77 / -0.43 | PASS |
| G5 untouched identical | the rule swapped in all 96 W1 cells; W2's 24 fights untouched and identical | vacuous in W1 (said) |
| G6 Crossing guard | 1.0 / 0 / 1.97 / 0 s | PASS |
| G7 W2 team 0 / team 1 noprog_s | identical (0 swaps) | PASS |
| G8 authority probe | identical | PASS |
| G9 check / SCRIPT ERROR | exited 0 / none | PASS |

**In his terms:** his fire truck that drove nose-first into the building beside a container and sat there while its squad left now
swings round the container with its squad; across 96 of his group clicks crews spend a little less time not getting closer to their
spot (terminus clearest), brush walls a little less, and the group is in no later. The CPU's own fights never met the case (0 swaps).
