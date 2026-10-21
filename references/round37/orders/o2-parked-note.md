# O2 design note: parked squads stay put and shoot (orders, round 37)

**His words (2026-10-20):** "Stay put and shoot". A squad he parked holds its ground and fires from its spot. If it
ever moves to fight, it drives all the way back. HE decides when it moves.

## What leaves a parked seat today (builder0, native, light lane, `3e43c4a24`)

The workload: `make native orders-probe` with `--probe-fight=on --probe-budget=1500` (his three squads, 10 crews incl.
7 scouts, parked by one click near the river; a real CPU army of 15 comes to them; watched 120 s after all are in).
Cells: locks / crossing / terminus x 3 squads x click x seeds 3621-3626 = **18 fights, 54 squads, 129 placed crews**.
Rows: `o2-fight-sizing-builder0-3e43c4a24/`.

A crew counts as having LEFT its seat when it is more than 6 m from where it stood at the end of the place window
while it has **no order goal**. `left_by` is the brain's option at that tick.

| left by | crews | per fight | whose |
|---|---|---|---|
| SPOT (scouts keep a stand-off, opening distance) | 23 | 1.28 | **brains' idle-crew options (orders' O2)** |
| ENGAGE | 4 | 0.22 | O2 |
| RETREAT | 4 | 0.22 | O2 (survival: a question below) |
| RECHARGE (breaks contact for its shield) | 2 | 0.11 | O2 |
| COVER_FIRE | 1 | 0.06 | O2 |
| **own options, total** | **34** | **1.89** | |
| GIVEWAY (gave way to a friend within 3 s before) | 10 | 0.56 | manoeuvre's M5 (R37.6), counted apart |
| MOVE (its seat moved under it: the order had just completed) | 42 | 2.33 | the halt re-lay: O1's flicker, see below |

- 27 of 54 squads had a crew leave by its own option. The worst crew per such squad sat a median 23.0 m off its seat
  (max 49.2 m).
- **Coming back:** at the window's end the worst surviving crew was 6.9-33.7 m off its seat in 8 squads. The fights are
  lethal (90 of 129 placed crews died; green lost 141 v rust 93 over 18 fights), so "came back" is read on survivors only.
- **Mechanism (code reading, tank_brain.gd):** an idle crew (its order complete) gets the post `objective` = its station
  (Orders.station, the seat it was sent to), radius 5 m, IDLE_LEASH 30 m. Within the leash every option competes:
  SPOT, ENGAGE, FLANK, INVESTIGATE, CLEAR_LANE, COVER_FIRE, RECHARGE, RETREAT. ADVANCE is the way BACK (0.45 / 0.25 off
  the post, 0.95 past the leash), and it stops at 5 m from the post, not on the seat. The element's own arrival watch
  rests while arrived, so nothing else brings it all the way back.
- **For O1:** the same fights carry 175 halt-shape flips and 446 re-lays over 27 of 51 placed squads. That is far more
  than the no-fight probe's 18, because crews moving in a fight drag the centroid across terrain lines. It is most of
  the MOVE row above. O1's anchor read removes it.

## Proposal (the grant to ask for: tank_brain.gd, one guarded seam)

**PARKED_HOLD (switch `--parked-hold=on|off`, OFF until its bar passes).** For an IDLE crew whose station is a seat of
HIS element that has arrived (the player's orders, `Orders` as the order source; CPU elements unchanged):

1. **Gate:** each option whose action drives the hull to a point more than PARKED_HOLD_M (4 m) from its station scores 0:
   SPOT, ENGAGE (its moving form), FLANK, INVESTIGATE, CLEAR_LANE, COVER_FIRE, SUPPRESS (moving), RECHARGE, TAKE_COVER
   beyond 4 m. HOLD (turns, shoots from the seat) is what remains. The gate is a filter on candidates, the way `_obey`
   is for an order: a crew still shoots everything it can see from the seat.
2. **All the way back:** an idle crew off its station returns to the station itself (its order's arrive radius,
   TankBrain.ORDER_ARRIVE), not to within 5 m (the ADVANCE seam, already granted).
3. **RETREAT** (critical hull, under fire): kept by default; a crew that retreats comes all the way back by (2) when it
   can. Question for the lead below.

**Bar (to file before any arm number):** the same fight probe on fresh seeds (12 a cell, n 36 fights), arms main v
`--parked-hold=on`. Deciding: own-option leaves per fight, arm <= 10 % of base. Guards: his kills and his losses per
fight within base +/- 1.645 se (sized from the base arm's per-fight sd), the CPU's losses likewise. Symmetric? No: the
gate reads HIS orders only (his control, not the AI's smarts), so no CPU guard is needed beyond the kill/loss line.

## Question for the lead (player terms)

*"When one of the vehicles in a squad you've parked is about to be destroyed, should it pull back on its own and then
return to its spot, or stay and fight to the end where you put it?"* Recommendation: pull back and return (a crew that
dies standing still looks dumb too, and it comes all the way back).
