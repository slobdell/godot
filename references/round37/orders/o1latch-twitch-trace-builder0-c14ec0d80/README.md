# O1-latch's failed guard traced: terminus 5 click, squad 4 (Delta) (builder0 light, c14ec0d80, seeds 3767 / 3772)

`ORDERS_PROBE_ARMS="main:--probe-trace=4 latch:--halt-terrain=latch,--probe-trace=4"`; `delta-<arm>-s<seed>.txt` is one line a
second per Delta crew: position, verb, goal, seat.

**The slide is neither the group lay nor a latch shape change.** Squad 4's place (22.0, 84.5) is the back rank, 55 m behind
the click (4.8, 29.7), in the same street; the squad starts on it (arrived 1.5 s). At the deploy (all_in, ~7-11 s) the
deploy's seat deal sends Delta_2 from the east end of the first halt (41.7, 90.1) to the far west-front seat (3.3, 63.3),
47 m ACROSS its own squad. Same seats, same crew, both arms, both seeds.

**What latch changes is when that drive happens, and so which column it is counted in.** The probe splits the movement after
the deploy at PLACE_S (8 s): before is `place_m`, after is `twitch_m`. In main, Delta_2 first overshoots to (55, 79) and is
already rolling when the deal fires; in latch it holds at its first seat and then waits ~4 s behind Delta_3 before it drives,
so most of the same 47 m lands after 8 s:

| | place_m | twitch_m | sum |
|---|---|---|---|
| main s3767 | 34.9 | 22.8 | 57.7 |
| latch s3767 | 8.9 | 35.7 | 44.6 |
| main s3772 | 26.8 | 13.5 | 40.3 |
| latch s3772 | 8.8 | 35.7 | 44.5 |

The whole judged cell (12 seeds, median of each run's worst crew): twitch 16.8 -> 28.0 m, place + twitch 46.2 -> 44.8 m (3
squads: 31.8 -> 28.2). Latch does not move crews more after they arrive; it moves the same drive later.

**The real defect** (both arms): the deploy's deal hands the crew at one end of the halt the seat at the other end, so one
tank crosses its whole squad after it has stopped. That is what he would see as "one tank wanders off after they arrive".
