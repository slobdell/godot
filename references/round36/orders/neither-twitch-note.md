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

## Counts (builder0 light lane, native, `55c973cd4`, main, 12 street cells x seeds 3621–3626, 287 deployed squads)

`neither-builder0-55c973cd4/split.txt`. Crews are scored against their own element. 25 of 287 squads had a crew re-dealt
to another squad (43 crews).

| | LOOP | ENGAGEMENT | STOPPED SHORT | TRAFFIC |
|---|---|---|---|---|
| all twitchy squads (>= 15 m), n 55 | **19** | 16 | **19** | 1 |
| neither seating nor depth, n 26 | 9 | 7 | 10 | 0 |

- **Per cell (neither, loop / engagement / stopped / traffic):** Locks 3 click 3/0/0/0, Locks 3 route 3/0/1/0, Terminus 5
  route 2/1/1/0, Crossing 3 click 0/1/3/0, Crossing 5 click 0/0/2/0; every other cell <= 2 in total.
- **Per squad:** Bravo (squad 2: IFVs plus scouts) carries 8 of the 9 "neither" loops and 18 of the 26 "neither" squads.
- **ENGAGEMENT** is ADVANCE only (2535 ticks).
- **Largest examples:** LOOP Terminus 5 route s3623 Bravo, away 67.8 m; LOOP Locks 3 click s3625 Bravo, away 31.6 m;
  STOPPED SHORT Crossing 5 click s3625 Echo, 37.3 m.
- **TRAFFIC between squads, the round-35 suspicion, is 1 squad in 55.** What looked like traffic in the laptop trace
  (Crossing 3 s34) is rare on builder0.

**STOPPED SHORT is mixed, so trace it before any design.** Its largest example (Crossing 5 click s3625, Echo) is a squad
whose crews were ALL re-dealt: three drive with element Delta, one with Charlie. Echo_3's 30 m drive at t 26–38 is its
share of Delta's capped deploy at 24.5 s running past the place window, not a crew that gave up.

## Design note (no code before the orchestrator rules)

1. **LOOP (19 of 55) is the clear lever, and what he would notice:** "nobody drives a 20–30 m loop to reach a seat 10 m
   away". The navmesh path is short, so the loop is the DRIVE: a crew facing away from a seat a few metres behind it turns
   round forward on its turning circle, sometimes over a lock or into the next street, instead of backing in. Most of it
   is Bravo's wheeled IFVs and scouts. The rule belongs in movement (manoeuvre's paths): **back into a goal that lies
   behind the hull and closer than ~15 m** (a short reverse), with a deterministic lab stage like the herringbone lab: a
   hull with its seat 7 / 10 / 14 m behind it, at 0 / 30 / 60 deg off its tail, open ground and a lane; deciding line
   `away_m` per cell, guards the reverse's own time and contacts. **Orders' fallback, only if manoeuvre declines:** facing-aware
   deploy seating in the deploy carve-out (a leg pointing more than ~120 deg off the crew's facing costs extra). It's
   weaker, since it can only reshuffle seats, not turn the hull.
2. **ENGAGEMENT (16) is brains' code (no owner this round), and may be correct play:** a crew sees an enemy, advances,
   and is left wherever the fight put it. The visible part he'd call "not following the order" is the END: after ADVANCE
   the crew is sent back but stops short (Locks 5 seed 34: 12.7 m off). A round-37 question in player terms:
   *"When a crew in a parked squad spots an enemy, it drives out to fight it and doesn't come all the way back. Should a
   squad you parked stay parked and shoot from where it stands, or chase?"*
3. **Re-dealt crews (25 squads of 287):** round 22's untangle deals vehicles between squads so their drives don't cross,
   so a vehicle can drive off with another squad and stand with it. In his terms: *"When you send several squads at once,
   a vehicle sometimes goes with a neighbouring squad instead of its own, to avoid crossing paths. Is that fine, or should
   every vehicle stay with its own squad?"* (Behaviour on main since round 22; nothing changes until he answers.)
4. **STOPPED SHORT (19):** trace three more examples first (mixed: overrunning deploys of re-dealt squads, crews whose
   order ends off-seat).
