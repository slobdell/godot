# D2: the orders probe on the shipped deploy step (round 35)

**Table** (`table.txt`, rows `rows.jsonl`): builder0, native (the folder's library from the `581b8a396` build: N2/N3 change no
game code), `make orders-probe` on main `977a270fa` (= `1a18dd278`'s code, the deploy step ON), seed 34, n 1 a cell
(deterministic), the 24 cells, arms `main` v `deploy_off` (`--deploy-step=off`, round 34's settle).
**Shots** (`shots/`): the laptop, GDScript, windowed (builder0 has no desktop), the 12 click cells, `stream/orders` with
`--deploy-minimax=off` (= main for a click: the gate deal and uncross act only on queued legs, the pack is off). Top-down at
every squad's arrival and 5 s later, desktop 1280x720 and phone 1560x720. White post = his click; red, yellow, green, blue,
violet = squads 1-5's own spots.

## What he'll see (deploy step ON v OFF), in his terms

- Squads arrive in their travel shape and step once into their halt shape on the spot they were sent to. In a street a Law
  squad stands as a tidy herringbone down the street (Locks 5 click), where round 34 left a loose cluster.
- The settling after the step is smaller on the Crossing (5 squads: worst crew moves 23.3 m after settling v 46.5; 3: 18.3 v
  32.2) and the Locks 3 cells, and LARGER on Locks 5 click (19.6 v 4.4), Terminus 5 click (30.6 v 13.1): there the step
  itself (a wedge, wide across the street, re-forming into a herringbone along it) runs past the probe's 8 s window. D4
  (minimax seating) targets those.
- All in is mostly within a few seconds of round 34; Locks 3 route is slower (38.3 v 18.5 s); the Locks 5 route now finishes
  (45.6 s; round 34's settle never did inside 90 s). D5 (the gate deal) targets the routes.
- Nobody crosses a river in any cell on either arm.
