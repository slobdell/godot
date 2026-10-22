# O1 traces (R37.17): parade s3704 census fight, locks 5 route s3703 squad 2; arms main / anchor / latch
builder0, light lane, native, commit 52c15e0e1 (latch = ca251254a's switch; nothing else in the arms differs), n = 1 each.
`make native o1-trace`.

## parade s3704 (CPU v CPU, tests/control/contact_trace.gd = census_probe's setup and contact rule)
| arm | contacts_friend | (census, f4365153f) | touching an ARRIVED element | both moving | last contact |
|---|---|---|---|---|---|
| main | 136 | 139 | 44 | 92 | 65.2 s |
| anchor | 298 | 309 | 44 | 254 | 92.4 s |
| latch | 238 | - | 45 | 193 | 105.1 s |

- Contacts with an arrived element (the only state HALT_TERRAIN changes) are flat: 44 / 44 / 45.
- The excess is crews of moving elements, in drills: react_to_contact 31 -> 98 (58), assault_through 17 -> 91 (64).
  Mostly Rust's "Eyes" screen element (34 -> 194 contacts), e.g. Eyes_1 x Eyes_2 rubbing 28 times from 31.5 s to 83.8 s
  while its screen is re-laid through react_to_contact and assault_through.
- The fight runs longer in the other arms (last contact 65 -> 92 / 105 s): per second, 2.1 / 3.2 / 2.3.
- Reading: a different halt read changes the fight's course (one fight, chaotic), and a longer, more mobile fight bumps
  more. There is no halt-time crowding in this fight. (The shape-choice shift found earlier, coil 60 -> 52 in the probe,
  is real, but it isn't what drove this census case.)

## locks 5 route s3703, squad 2 (Bravo, 4 crews)
- main and latch: identical rows (twitch 0, away_seat 0, 8 station changes, same seats).
- anchor: crew 2 is held up at (-28, 85) t=8-11, where main's crew 2 drove on (a neighbour's halt differs). At t=12 the squad
  re-deals seats: crew 3, ALREADY PARKED at its seat, is sent 18 m south; crew 2 takes a seat by crew 3's old one.
  That is the 13.9 m twitch (judged cell median 3.9 -> 10.6 m).
