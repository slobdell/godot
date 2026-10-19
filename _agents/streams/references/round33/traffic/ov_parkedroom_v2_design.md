# Round 33 overnight (traffic item 1): parkedroom v2's design reads (exploration, never judged)

Both reads: X3's OLD fights 700–723 × {terminus, locks, random} (n 72, 180 s), parkedroom v1 ON, builder2, native,
--fixed-fps 30, `make traffic-far-census FAR_FLAGS=--traffic-on=parkedroom`. Tree: stream/traffic-overnight (main
`e46f1720` merged), far_census `2910985f` (read 1) / `c367dc10e` (read 2: the order at the 30 s read too). 2632 room
give-ways each. Every FAR_ROOM row carries the crew's state the tick it was asked.

## Read 1: no "at a post" gate rescues L6 as written

Back within 3 m of the post at 30 s (alive and back / all), by the crew's state when asked:

| group | n | back | rate |
|---|---|---|---|
| all | 2632 | 265 | 10 % |
| option HOLD | 2036 | 259 | 13 % |
| engaged | 795 | 22 | 3 % |
| still < 0.5 s / < 2 s / < 5 s / < 10 s / < 30 s / ≥ 30 s | 652 / 829 / 545 / 283 / 251 / 72 | | 4 / 7 / 9 / 15 / 25 / 32 % |
| within 3 m of its slot | 1219 | 166 | 14 % |
| HOLD, still ≥ 10 s, at its slot (alive) | 161 | 58 | 36 % (median 5.3 m v a 6.0 m room leg) |

Most crews never drive back. The brain returns a crew only for a hold ORDER beyond max(HOLD_TOLERANCE 3 m, settle + 1)
(tank_brain.gd:2854); an idle crew has a 30 m leash and doesn't care about 6 m.

## Read 2: the order changes under it

Of 1972 room crews alive at 30 s, only **359** had the same order (goal moved ≤ 1 m). Of those, 235 (65 %) stood inside
the brain's own hold line and 53 % within 3 m (hold verb, goal ≤ 3 m when asked, still ≥ 2 s: 69 % / 61 %, n 194). So
even judged only on unchanged orders, leaving the return to the brain brings back two in three.

## What v2 does (`593f8f4b5`)

1. **Gate:** a room give-way only for a crew still ≥ 2.0 s (Traffic's table clock, refreshed on both drive paths; the
   ordinary give-way otherwise).
2. **Return:** once the asker is past, the crew drives back to the post it left (the give-way drive with the post as
   its spot), unless the brain has sent it somewhere new (a move_to > 3 m from the post). A new order (`reset`) forgets
   the post. Never after a give-way that timed out.
3. `test_traffic_neck`: main's merge moved the element's arrival (the scout parked 4.7 m from where it used to; the tank
   squeezed past OFF), so the stage now puts the scout on its pre-merge post (51.5, 55.3) with his hold order. Plus three
   tests: a crew still under 2 s makes no room; a crew drives back to its post; a crew sent somewhere new doesn't.

## Dev reads 3–5: closing the way back (v2 ON, the same old fights, builder0, native, never judged)

| read | tree | rooms | ways back | L6: unchanged order, alive, within 3 m at 30 s | all alive within 3 m |
|---|---|---|---|---|---|
| dev 1 | `593f8f4b5` (v2 first build) | 798 | 34 | 78 / 156 = 50 % | 17 % |
| dev 2 | `7a8563a22` (a re-sent order keeps the post) | 780 | 135 | 99 / 170 = 58 % | 20 % |
| dev 4 | `0733a45ce` (+ read fields only) | 780 | | 99 / 170 = 58 % | |
| dev 5 | `20b1cc113` (owed way back checked at Traffic.refresh) | 792 | 559 | **142 / 183 = 78 %** | 29 % |

(v1 for reference: 2632 rooms, 42 a fight median; v2 12 a fight.)

- **Dev 2 → 4:** 65 of the 71 unreturned crews still OWED their post, with the asker past by v2's own rule (more than
  9 m away and arrived, or dead). The owed check ran only in GDScript's `right_of_way`, which a holding crew the NATIVE
  drive runs never reaches. Dev 5 also checks at Traffic.refresh (both paths; once it gives way, native hands it back).
- **Dev 5's 41 left out:** 17 went back (last spot `room-back`) and stand 3–8 m off at 30 s (they returned, then the
  brain moved them again); most of the rest are giving way again to someone else at the read (a new `room(..)` or
  `spot(..)`).

## The native ask bypasses it (found before the series; nothing judged ran)

Native's N5.Y (`4d2781e30`, `BrainSwitches.native_yield` default ON) moved `Movement.ask`, `_negotiate`'s body and
`_begin_yield` into C++. `Drive::ask` (drive_native.cpp:2465) has no parkedroom, so on the shipping path v1 and v2 act
only on the asks still made in GDScript. Fresh-native dev census (`make remote T="native traffic-far-census"`, old fights
700–707 × 3 arenas, builder0, v2 ON, n 24): **36 room give-ways (1.5 a fight)**, against ~12 a fight in the dev reads
above. Those reads ran a native library built before N5.Y (builder0's folder, no `native` step) or none at all
(builder2's freshly seeded folder: NATIVE_EXEC in 0 of 72 logs). So they show what v2 does when it runs, not what ships.
Every run replays (twice → identical); the library is what differs. Raised with the orchestrator: (a) native hands the ask
to GDScript when parkedroom applies; (b) judge on the GDScript yield path; (c) park.
