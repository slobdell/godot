# Bar shortfwd (round 46, manoeuvre M5): his short move to a wheeled crew drives toward his click — FAILED as filed on D1 alone

Frozen tree **adeb71696** (wip/manoeuvre-shortfwd-bar = native's twin pair 4ac0236bd + SHORT_POSES + the holdway cache fix 258ce00f0);
check builder3 `>> remote: make check exited 0`, 3478 passed / 0 failed, sim-baseline unmoved. Native's twin EQUAL on this hash (19 / 0;
the corpus 14 / 14 native v GDScript). Arms base (no flag) v sf `--traffic-on=shortfwd`, the C++ drive in all 48 rows. Series on
builder0 light 04:08-04:31 PDT 2026-10-30 (`bars_sf_series.sh`). Filed in streams/manoeuvre.md, recorded on main 30eda013f; no amendment.

| Line | Read | Verdict |
|---|---|---|
| Floor: OFF reverses in >= 4 of 12 (deciding, his two in-reach clicks) | 6 of 12 | MET |
| D1 metres driven away from his click (12121-12132), paired <= -2 se AND pooled ARM < BASE | pooled 5.7 -> 2.4 m; paired -0.27 m, se 0.17 (**-1.6 se**); 3 cells better, 9 identical, 0 worse | **FAIL** |
| G1 arrival sooner or identical >= 10 / 12, none > 30 ticks later, never-arrived | 12 / 12 (3 strictly sooner, by 2-15 ticks); worst later 0; 0 -> 0 | PASS |
| G2 metres off the navmesh (the drop), every cell <= +0.25 m | +0.00 (deciding and guard blocks) | PASS |
| G3 his other five clicks (12133-12144) | 12 / 12 within the lines (every row identical) | PASS |
| G4 default orders probe | 96 / 96 byte-identical | PASS |
| G5 engage's authority probe (12121-12144) | every row and line identical | PASS |
| G6 frozen tree's check / G7 SCRIPT ERROR | exited 0 / 0 | PASS |

**Per cell (deciding):** his 83.7 s click (pose 0): 12123 reverse 31 -> 17 ticks, 2.2 -> 0.6 m away, arrived 67 -> 52; 12131 33 -> 20,
2.3 -> 0.9 m, 67 -> 52; 12129 22 -> 19, 0.9 -> 0.6 m, 55 -> 53; 12121 / 12125 / 12127 identical (the forward arc's clearance test kept
today's planner: no shortfwd tick). His 87.0 s click (pose 2): OFF never reverses, identical. The rule changed 3 of 24 cells, each for
the better; the line's se is set by those 3 among 9 ties.
