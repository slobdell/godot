C32.7's laptop price (the orchestrator's slot, 2026-10-16 05:25-05:28 PDT).
Machine: laptop (flightdeck, i5-8365U, 8 threads). Commit 65cc43dd (pair/planner-queue) run with
--planner-slice=1 --planner-queue=fifo (= the FIFO default at the slower slice; the probe's per-expansion
price does not depend on the slice). Command:
  taskset -c 0-3 make planner-census PLANNER_CENSUS_PROBE=30 'PLANNER_FLAGS=--planner-slice=1 --planner-queue=fifo'
Sumps, 25 a side, seeds 92721 / 31337, 120 s each. Native library built on the laptop (29 s, godot-cpp cached).
Load 2.66 at start (the build's tail) falling to 1.55 at end (laptop_load.tsv): above ~2 for the first minute,
so an UPPER BOUND (R31.6).
The seam's own request (the longest live hull's face-about, native): us an expansion warm (late median) 89 / 79,
early 122 / 121; n 112 / 116 plans. SLICE 2 = ~0.18-0.24 ms a tick: under C31.5's 0.5 ms.
Ruling (the orchestrator): C32.7 resolved, SLICE 2 on every preset; the knob and --planner-slice kept.
