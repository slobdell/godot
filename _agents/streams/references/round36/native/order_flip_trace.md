# Who writes Bravo_2's second order (round 36, R36.24's flicker; a TRACE for round 37, no code)

**The writer:** the crew's element, in GDScript (not the native execute). Its halt formation flips between **herringbone and
coil** because the element's terrain reading flips between **"lanes" and "open"**: one cover feature sits on the 45 m
`TERRAIN_RADIUS` line of the squad's centroid. The two formations seat Bravo_2 17.6 m apart, so each flip re-issues its order
to the other seat.

## The run

- **Commit:** stream/native cb9aef5aa (main e778ca5c6 merged; T10's switches OFF, so main's behaviour), plus local print-only
  probes (never committed).
- **Machine:** builder0, light lane, native library loaded.
- **Workload:** `make orders-probe` on locks / 3 squads / click / seed 3664, arm `main`, with `--arrive-trace --probe-trace=2`
  (`--element-trace=Bravo` in a second run); one `make orders-probe-trace` run of the same case. n = 3 runs. Every run flipped
  at the same ticks.
- **The laptop does not reproduce it:** the same case there holds Bravo_2 still at (-16.2, 16.6) from t 37 to t 43, with no
  flip. Sim state differs by machine, so use builder0.

## The chain, from backtraces

A print-only probe in `Orders._start` captured `Engine.capture_script_backtraces()` for every goal change of
`Green_Bravo_2`. The crew names are `Green_`-prefixed; the probe trace prints them short.

    ORDER_WRITE tick=1159 Green_Bravo_2 goal [-19.07, 17.90] -> [-5.78, 29.49] verb move source element id 22
      <- _start (game/control/orders.gd) <- issue (orders.gd:183) <- _issue (game/tactics/element.gd:1932)
      <- update (element.gd:644) <- _physics_process (game/tactics/elements.gd:239)

All writes after the ADVANCE return carry the same stack:

| match tick | tick / 60 (s) | goal | id |
|---|---|---|---|
| 1018 | 17.0 | → the seat (-19.07, 17.90) | 21 |
| 1159 | 19.3 | → (-5.78, 29.49) | 22 |
| 1276 | 21.3 | → the seat | 28 |
| 1288 | 21.5 | → (-5.78, 29.49) | 30 |
| 1294 | 21.6 | → the seat | 32 |

Each one is a new order id from `Element._issue`. Clocks: these are match ticks; `--arrive-trace` and `--element-trace` print
physics-frame seconds (about 20.7 s later here, so tick 1159 is ARRIVE_GOAL t 40.0), and the probe trace counts from the order. The probe trace's 1 s samples (t 38 to t 43 in its own clock) make this
look like "every second". The flips are really irregular, 0.1–2 s apart.

## Why the desired goal changes

1. `Element._count_goal_move` keys each of these moves **`reseat`, 17.6 m** (`--arrive-trace`: t 40.0, 43.9, 44.3, 44.5).
   Bravo_2's seat index changed; its anchor and task did not.
2. `--element-trace=Bravo` shows the seat change is the **formation**. The task is the same, `move to (-2.76, 18.57)`, with
   arrived true, and the anchor is the same, (-4.07, 22.35):
   - **herringbone** (t 38, t 44–45): Bravo_2 is seat ["herringbone", 3, 1], slot (-19.1, 17.9);
   - **coil** (t 39–43): Bravo_2 is seat ["coil", 3, 2], slot (-5.8, 29.5).

   The other two crews' slots move by only 1 m.
3. The halt formation comes from the doctrine table: `ElementPlan` (element_plan.gd:251) runs
   `table.select({"task", "threat", "terrain", "composition"})`. In every doctrine's `movement` table, a halt in
   `"terrain": ["dense", "lanes"]` is a herringbone ("halted in cover") and a halt anywhere else is a coil ("halted in the
   open").
4. `situation["terrain"]` is `ElementSituation.terrain_at(center)` (element_situation.gd:145). It counts the arena cover
   features with any box within `TERRAIN_RADIUS` = 45 m of `center`. Two or more make "lanes", five or more "dense".
   `center` is the mean position of the live crews. **There is no hysteresis.**

A print-only probe in `ElementSituation.build` printed every terrain change for Bravo, the features' distances, and where
the crews stood:

    tick 1159 lanes -> open  centre (-10.30, 21.45) features 45.2, 4.0         | B1 (0.7,16.0)  B2 (-35.1,15.0) B3 (3.5,33.4)
    tick 1276 open -> lanes  centre (-9.01, 18.63)  features 45.5, 5.2, 45.0   | B1 (0.7,16.0)  B2 (-31.9,11.5) B3 (4.2,28.4)
    tick 1288 lanes -> open  centre (-9.08, 18.63)  features 45.5, 5.1, 45.0   | B1 (0.7,16.0)  B2 (-31.7,11.6) B3 (3.8,28.3)
    tick 1294 open -> lanes  centre (-8.99, 18.65)  features 45.4, 5.2, 45.0   | B1 (0.7,16.0)  B2 (-31.3,11.6) B3 (3.6,28.3)

These are the same ticks as the order writes. **The condition that flips it back** is one feature's nearest box crossing
45.0 m from the centroid. Between 1276 and 1288 the centroid moved 0.07 m. Bravo_2 stands ~30 m from its squadmates and
creeps 0.2–0.4 m, which moves a 3-crew centroid by a third of that: enough to put the feature in or out. Each re-issue then
sends Bravo_2 the other way, so the crew's own motion keeps re-crossing the line. Bravo_3, also drifting, adds to it.

**Why only after ADVANCE:** the ADVANCE (t ≈ 32) took Bravo_2 west to x −35, which dragged the centroid (and so the 45 m
circle) next to that feature's edge. Before it, the centroid sat well inside lanes.

## For round 37 (brains' paths: game/tactics/element_situation.gd, element_plan.gd; no owner this round)

1. **Hysteresis on the terrain reading:** a halted element keeps its terrain class until the count is past the threshold by a
   margin, for example `TERRAIN_RADIUS` ± 5 m for a feature entering or leaving. Or latch the halt formation per arrival at
   an anchor; `ROUTE_SEAT_ONCE` and `GROUND_LATCH` already latch other seat inputs. The latch is the smaller change: a squad
   that has arrived doesn't re-pick its shape because a crew wandered.
2. **Or read terrain at the anchor, not the crews' centroid,** once arrived: the anchor is fixed while the centroid follows
   whoever is out fighting. This is the root of the feedback loop, since the reading moves with the crew it re-seats.
3. **Size it first:** count `reseat` goal moves (`Element.goal_moves["reseat"]`) whose cause was a terrain flip, across a
   series. Locks click is one cell; any arena whose cover sits ~45 m from a halt anchor is exposed.
4. **orders' away_m** (traffic's note, item 1) counts these flips as driving; this explains its Locks rise in base as well
   as under G.

Reproduce: `make remote LIGHT=1 T='orders-probe ORDERS_PROBE_MAPS=locks ORDERS_PROBE_SQUADS=3 ORDERS_PROBE_ROUTES=click
ORDERS_PROBE_SEEDS=3664 ORDERS_PROBE_ARMS=main:--arrive-trace,--element-trace=Bravo,--probe-trace=2'`. Then grep
`ARRIVE_GOAL.*Bravo_2` (key `reseat` 17.6 m) and `ELEMENT_TRACE t=3[89]\|t=4[34]` (herringbone ↔ coil). The two probes above
are print-only and are described here, not committed.
