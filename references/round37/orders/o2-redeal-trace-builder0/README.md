# O2's parked re-deals (R37.28), traced: Crossing 3 click s3747 squad 1, fight v parked (builder0 light, native, stream/orders
# a87449d6b; n 1 each; the run is not byte-identical to the judged one: here 4 v 5 re-deals, judged 3 v 8).
- Every re-deal is the SQUAD (element Alpha) issuing a new order goal to a crew sitting on its seat ("MOVE - ordered"), never
  the drive-back.
- parked: halt re-lays 4 (base 0), reseats 3 (base 2). Alpha_2 is shuttled between two seats ~10-14 m apart three times in
  33 s (t=77 to (-101.3, 50.4), t=107 back to (-98.2, 40.8), t=110 to (-103.0, 54.3)); Alpha_1 sent three times t=99-118.
- base: the re-deals come in bursts after losses (t=20, t=82, t=107-132) while crews are off fighting.
- Reading: with crews holding their posts the squad stands "arrived" longer, its halt re-lays (O1's flicker) and re-seats land
  on crews that are actually parked. The O2-on-latch read (filed, 2477c46e7) is the test.
