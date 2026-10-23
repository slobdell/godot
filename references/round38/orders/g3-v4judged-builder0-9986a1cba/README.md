# G3 v4 judged read: FAILS as filed (Bar G3 v4, f0a70f544's code, latch ON)

- Code: e518fd649's G3 v4 (`--place-clear=on,--place-clear-trigger=near`). Green tree f0a70f544 (check: 24 passed,
  remote-guard-test re-run alone on the laptop exit 0). The probe ran on 9986a1cba (docs and evidence only over it).
- Machine: builder0, light lane, J4, TANK_SQUAD_SLOT_TIMEOUT=14400, 2026-10-23 08:20-09:03 PDT.
- Workload: seeds 4601-4612 (judged), n 12 per cell, 18 cells (streets + his click in `../g3-v4judgedhis-builder0-9986a1cba/`
  + yard_open). Judge `orders_judge.py g3`; output in verdict.txt.

```
PASS deciding: place pairs closer than 12 m 51 -> 2 (<= 12.8)
FAIL guard never-in squads 3 -> 4
PASS offsets: 0 of 864 > 40 m further; worst +36.3 m
PASS guard friend_contacts 13117 -> 13172
  FAIL guard never-in     crossing 5 click: 0 v 1
  FAIL guard twitch       crossing 5 route: 17.4 v 21.4
  FAIL guard crossed      crossing 5 route: 0 v 1
VERDICT g3: FAIL
```

- His click passes now (v3's twitch fail is gone).
- **A G3 bug:** route s4603, G3 moved squad 4's place 4 m at a time to (-51.2, -3.7), across the river. Its crews crossed
  the bridge (36.5 s) and never got in. The step search checks each step is standable, not that the moved place is
  reached from the original without crossing water.
- The other never-ins are at the west bridge mouth (s4604 squad 4 at (-91.5, 31.4), s4609 at (-68.1, 29.5)). Main got
  everyone in on these seeds this time.
- Twitch: 1 m over the line (base + 3).
