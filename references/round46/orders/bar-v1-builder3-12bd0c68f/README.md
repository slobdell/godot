# Bar V1 THE VETO-ONLY GROUP GUARD: PASS (round 46, orders)

Frozen tree 12bd0c68f (its check GREEN builder3: `make check exited 0`, 3483 passed / 0 failed). Series on builder3 (light),
2026-10-30 04:35-06:45 PDT, `tests/control/orders_v1_bar.sh`, every part complete on try 1: geometry 1632, his3 48, streets 768,
main-geometry 816, main-his3 24, main-streets 384 runs. Seeds A 11801-11824, B 11825-11848. Judge `tests/control/orders_v1_judge.py`
(`verdict.txt`). The rows stay on the laptop in `~/orders-r46/bar-v1/`.

- D1 places across a gap 0 (base 303); D2 sent back 0 (base 126); D5b his exact Gorge click 24 of 24 (base: 24 of 24 had a
  failing place); I1 the default OFF path == main (7189e3ff3 + instruments) in 1224 of 1224 runs; I2 0 passing places differ
  (914 runs untouched, 310 changed); G1 PASS on the 13 touched cells; B- no street run has a failing base place.
- Touched (base runs failing / veto runs re-dealt / runs): geometry crossing 93/93/144, gorge 144/144/288, locks 73/73/264,
  terminus 0/0/144; every street cell 0 failing.
- Reported, not a line (R46 ruling): on Crossing 3-squad routes the veto re-dealt the FIRST waypoint in 22 of 24 runs (5-squad
  routes 2 of 24); the last places are identical. Paired on those runs, veto v base: places outside the corridor 1.23 v 1.23,
  metres driven outside 67.2 v 75.8 a run, all-in 17.1 v 18.6 s, contacts 31.9 v 32.9, never-in 0 v 0 (n 22).
