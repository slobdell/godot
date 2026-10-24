# Round 39 bar traces (orders, dev reads after Bars G1 v5 / G3 v6 FAILED)

Machine: builder0 light lane, J2-4, native on. Commit: e7c896c8f (bar tree). Each trace is n 1 on a bar seed, read after the
verdict, so it is not a judged number.

## G1 v5: his click 5, squad 2 (Bravo), twitch 28.4 m on all 12 seeds. Traced, s6201.
Logs: `terminus-5-click-{main,column}-s6201.log.gz` (`--probe-trace=2 --deploy-trace`).

- Both arms deal Bravo the same halt: herringbone, lanes, 10 m spacing, heading (-0.98, -0.22), and Bravo_2's far seat
  (-44.7, 75-77).
- **Main** deploys **all_in** at tick 116 (~3.9 s), while crews still drive in. Bravo_2 parked 3.3 m from its travel seat,
  which is within `TankBrain.ORDER_ARRIVE` 3.5 m.
- **Column** gives Bravo the click itself, (-29.3, 85.8). Bravo_2 goes to HOLD at (-30.0, 88.4), **3.83 m** from its travel
  seat (-33.6, 87.1). That is outside `_deploy_state`'s all-in radius (3.5 m), so the deploy waits for the **cap**
  (DEPLOY_CAP_S 10 s; tick 332).
- The halt deal then moves crews parked about 7 s: Bravo_2 24 m to (-53.7, 75.1), and Bravo_1 15 m. The probe reads that as a
  28.4 m twitch. His click is the same layout on every seed, so it repeats on all 12.
- **Cause:** the brain's stop short (HOLD, 3.83 m) v the deploy's all-in radius (3.5 m). The deploy then waits 10 s and deals
  on parked crews. It is settle's deploy trigger meeting the travel seat the column gave Bravo, not G1's ordering.
- **Round-40 options:**
  - settle: count a crew already holding (no goal) within e.g. 5 m of its seat as in; or
  - orders: no change to G1's ordering. Re-judge G1 once the trigger is fixed.

## G1 v5: locks 5 click places outside, 8 -> 8. Data only (bar rows).
- The 8 are the same rows in both arms (s6204-6207, squads 1 and 2, identical anchors): the column is not laid on those seeds,
  and main's lay places them.
- **Cause:** G1 doesn't engage there. Why the column isn't laid on that click is **untraced**.

## G3 v6: crossing 5 route s6213, squads 4 and 5 never in. Traced.
Logs: `crossing-5-route-{main4,g3t4,main5,g3t5}-s6213.log.gz`.

- In g3, `places_cleared` is 2 and `cleared_legs_back` is 1.
- Delta's element (squad 4) is stepped back along its own leg to (-53.9, 48.4), 28 m west of main's (-25.5, 45.6). Its halt
  deals lanes / 10 m, with legs of about 25 m: seats at (-47.6, 41.0), (-68.8, 29.4), (-32.8, 60.3), (-68.8, 51.5).
- Echo (squad 5) comes from the west along the same approach. From t=40 to t=90 its three crews creep about 15 m east
  through Delta's halt toward their places (-25.5, 38.2), (-13.8, 60.0) and (-13.5, 50.4), and never get in. Echo_4 had been
  re-dealt to Delta.
- **Cause:** v6's step back (no seat-holding step found, so it steps back along the squad's own leg toward home) parks the
  squad on the approach of the squads still to come: its leg home is their road in. This is the inverse of settle's S1 (B).
  The moved place doesn't meet a passer on its own leg; it stands on a later passer's route.
- **Round-40 option:** the step back must not stand within a corridor of any squad still to arrive. Otherwise keep the given
  place, as v5 did before the step back.

## G3 v6: crossing 5 route s6220, squad 5 twitch 42.5 v 0.1. Log only: `crossing-5-route-g3t5-s6220.log.gz`.
- In g3, `places_cleared` is 3 and `cleared_legs_back` is 2. Squad 5 deploys on the cap, where main deploys all_in.
- **Probably the same mechanism:** a stepped-back place on the late squad's road, so a crew can't reach its seat and the
  halt fires on the cap. **Not traced in detail.**
