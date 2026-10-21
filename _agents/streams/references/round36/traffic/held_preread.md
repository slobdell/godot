# Stretch 5 pre-read: held deaths T8 cannot release (REPORTED, not a bar line)

Source: round 35's T7 series logs (pair `e95179252`, builder0, native, fixed arenas {terminus, locks, sumps, gorge, parade} x
1600-1627, n 140 a arm, 180 s), `~/overnight-traffic/r35/t7series/{base,arm}`, JAM_DEATH rows with `held` (Traffic.holding the
tick before). Read on the laptop, 2026-10-20, from the files (no new fights). The arm = T7 ON = today's main behaviour.

| arm | held deaths | hits in last 10 s: 1 | 2-3 | 4+ | stuck:wedged | open:driving |
|---|---|---|---|---|---|---|
| base (T7 off) | 166 | 49 | 21 | 96 | 94 | 70 |
| arm (T7 on) | 159 | 44 | 17 | 98 | 85 | 69 |

- **~28 % die on the hit that would release them** (one hit in the last 10 s): T8 releases on the next `hold_of` after a hit, so a
  one-shot kill is out of its reach. These are the "hit before the hold" class's neighbours: nothing a hold rule can do.
- **~60 % took 4+ hits in the last 10 s while held:** T8's target. The series' released_fire and held-deaths lines say how many it saves.
- **43 % of held deaths are `open:driving`**, still_s median 0: a held crew is usually creeping to its hold spot, not parked. The
  hold spot itself may be in the line of fire (a question for after T8: is the spot chosen blind to where the shots come from?).

Next (after T8's series): the same table on T8's arm, split by released-then-died v never released; the never-released with
4+ hits are the design note's subject (held without being hit while a neighbour was?).
