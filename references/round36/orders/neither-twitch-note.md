# The twitch the deploy move doesn't explain (orders, R36.6; 2026-10-20)

**His concern (2026-10-20, verbatim):** "My concern here is basically giving some squads an order and then feeling like
they're not actually following it, making the game appear dumb".

**What this is.** In builder0's O2 cause count (`f5aa89ecd`, 12 street cells x seeds 3621–3626, 287 deployed squads),
57 squads had a crew still moving >= 15 m after the 8 s place window (the "twitch"). 27 of those 57 were explained by
neither the deploy's seating nor its depth. DEPLOY_COMPACT then failed (R36.6). It shortened the deploy move but not the
twitch, which is mostly what happens AFTER the move. This note splits that twitch by what the off-seat crews were
doing.

## Tooling (all in `tests/`, measurement only)

- `tests/orders_probe.gd` columns:
  - `twitch_seen`: brain option ticks while a crew stands > 3 m off its placed seat, "@goal" when it has an order goal.
  - `redealt`: crews untangle dealt to another squad's element.
  - `away_m`: metres the worst crew drove AWAY from its own order goal.
  - Since `acd95603d`, the place move and twitch are read over each squad's OWN element's crews.
- `make orders-probe-trace TRACE_CASES="map:squads:route:seed:squad"` (squad N every second, with each crew's element).
- `tests/control/neither_twitch.py` (the split, per cell, examples).

## The kinds, each with a traced example (builder0 light lane, native, `2196919cb`, main)

1. **A crew driving with ANOTHER squad (a measurement artefact, now excluded).** Terminus 5 route s3624, Delta (twitch
   69.8 m): Delta_2 was in element **Echo** from the order on. Round 22's untangle deals vehicles between squads so their
   drives don't cross. It drove to Echo's place, 70 m from Delta's. The probe grouped by his control groups and read it as
   Delta's twitch. Crossing 5 click s3625 is the same (an Echo crew in element Charlie). The squad itself did nothing
   wrong. Whether a vehicle visibly leaving its control group to drive with another squad looks "dumb" is a separate
   question for the lead.
2. **LOOP: a turn-around loop to a seat behind the crew.**
   - Locks 3 click s3624, Bravo (33.1 m): Bravo_1's goal is 7 m NORTH of it at (−3.6, 18.4). It drives 30 m SOUTH, over
     the lock, to (−7.3, −18.4), and back (t 20–40).
   - Terminus 5 route s3623, Bravo (46.5 m): Bravo_4's goal (−7.5, 68.5) is ~10 m away. It drives 45 m south to
     (−22.6, 24.3) and back (t 26–40). Bravo_1 and Bravo_3 do the same on a smaller scale.
   - The navmesh path to the seat is short (the detour column reads < 3 m), so this is the vehicle's drive, not the
     ground. It is exactly "nobody drives a 20–30 m loop to reach a seat 10 m away" from the brief.
3. **ENGAGEMENT: a crew leaves its seat to fight (ADVANCE), then sits where the fight left it.** Laptop Locks 5 click
   seed 34, Bravo_1: it holds its seat to t 20, ADVANCEs at t 23 with no order goal, is sent back at t 27, and stops 12.7 m
   short. That is brains' engagement code (no owner this round). It may be correct play.
4. **STOPPED SHORT: a crew holding off its seat with no order goal** (it was sent, got near, and its order ended).
5. **TRAFFIC: still driving to its seat among other crews.** Crossing 3 click seed 34 (laptop), Alpha_1: an 8.7 m straight
   leg, wandering round the deck mouth among squads 2 and 3 for t 18–36, ending 14 m short.

## Counts (builder0, `55c973cd4`, seeds 3621–3626, main): PENDING
