# Crossing's west bridge mouth: builder0 traces (diagnosis, no verdict)

- Code: f0a70f544 (main e1f602fbf merged, latch ON), builder0 light lane, J2, crossing 5 route, `--probe-trace=4`.
- dev-*: dev seeds 3801/3802, arms main and G3 v4. Main's squad 4 gets in on both (25.1 s, 20.1 s); every never-in there in
  rounds 37-38 predates the latch. On s3802, squads 3 and 4 touch the deck's north end at 44-46 s, after arriving.
- judged-main-*: main only, judged seeds 4108 (G3) and 3958 (G1 v3), read for diagnosis of main, not for any arm.
  - s4108: squad 4 gets in at 53.7 s, a thin margin.
  - s3958: squad 4 never in. Places: squad 3 (-74.0, 37.8), squad 4 (-65.1, 29.5), 12.2 m apart. From t ~49 s, Delta_4
    holds a move order 8 m short of its seat (-62.0, 31.2). Delta_2 holds one toward (-81.1, 34.1), 7 m from squad 3's
    place, inside squad 3's parked halt. Neither crew reports giving way, and neither moves again before 90 s.
- Reading: the deploy seats a squad inside its neighbour's parked halt at a pinch (water + the deck mouth), and nothing
  moves the parked crews. That belongs to the halt seat (settle) and give-way among squads (manoeuvre), for round 39.
  It is not G1's or G3's.
