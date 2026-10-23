# G3 judged read: FAILS as filed (Bar G3, amended tree 23983ab5b, latch ON)

- Code: 695d3d482's G3 (`--place-clear=on`) on tree 23983ab5b; probe ran on a67afc951 (docs-only over it), whose
  `make native check` exited 0 on builder0 (3112 passed, 0 failed; perf-judge NOT JUDGED, box busy).
- Machine: builder0, light lane, ORDERS_PROBE_JOBS=4, 2026-10-23 03:57-05:00 PDT (another stream's probes on the box).
- Workload: seeds 4101-4112 (judged), maps locks crossing terminus yard_open, 3 and 5 squads, click and route, arms
  `main:` v `g3:--place-clear=on`; plus his click (-29.3/85.8) on terminus 3/5 in `../g3-judgedhis-builder0-a67afc951/`.
  n 12 per cell, 18 cells.
- Judge: `orders_judge.py g3` over both (his rows renamed terminus_his).

```
PASS counter: places_cleared 106
PASS deciding: place pairs closer than 12 m 52 -> 4 (<= 13.0)
FAIL guard never-in squads 3 -> 4 (no more)
PASS guard worst place-to-click median per cell <= base + 15 m
PASS guard squads placed > 40 m further than main 0 of 864 (<= 43.2)
PASS guard no place > 100 m further than main (worst +25.4 m)
PASS guard friend_contacts 14677 -> 13808 (<= 16149.7)
  FAIL guard twitch       crossing 5 click: 20.4 v 26.4
  FAIL guard never-in     crossing 5 route: 0 v 1
  FAIL guard twitch       terminus_his 5 click: 13.8 v 26.0
VERDICT g3: FAIL
```

What failed:
- His 5 click is the same every seed. G3 moves squads 2 and 3. The worst twitch is squad 5's, whose place did not
  move: 26.0 m against main's 13.8 m (squad 3). With the latch ON, this is G3's own re-deal, not the deploy.
- Crossing 5 click: G3 moves squad 3 on every seed. The neighbour (mostly squad 2) twitches 30-37 m on 6 of 12 seeds.
- Crossing 5 route s4104: squads 4 and 5 never in. Squad 4 is at the west bridge mouth (-70/29.5), where main's own
  never-in sits on s4108.
