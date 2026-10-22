# Latch locks a one-update terrain read (lab; laptop GDScript f8bf6aaad)

The full check of f8bf6aaad (latch ON by default; builder0 native, `make native check exited 2`, 3049 passed / 1 failed)
failed `test_tactics_scenarios_2::test_a_move_ends_formed_up_on_the_spot_and_stops_issuing`: formation coil, 4 orders in the
last 10 s (limit 2); centre: herringbone, 0. Deterministic (reproduced on the laptop both ways).

`latch.txt` / `centre.txt`, one line a second (`test_zz_latch_debug.gd.txt`, the scenario's own setup, lab seed 17): the four
tanks drive down a lane (live terrain read `lanes` every second) except t=11, when their centroid crosses an `open` pocket.
The element stands arrived at t=12, so latch keeps t=11's `open`: coil, deployed at t=22 (inside the test's last 10 s).
Centre re-reads at t=12 (`lanes`): herringbone, deployed at t=13.

What he would see: a squad parked in a lane opening out into a ring that does not fit the lane, now and then, where the
crews were crossing a gap when they stopped. The judged probe (3821-3832) did not see it: its deciding lines count flips
and relays, which latch removes, not a wrong first shape.

Fix candidates (round 38, a new arm and bar): latch the read the deploy decides on (at all-in), or latch only a read that
has held for the last N updates (the centroid's terrain over ~2 s).
