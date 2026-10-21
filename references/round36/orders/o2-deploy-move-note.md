# O2: the deploy move across a street (design note, orders, 2026-10-20)

**What he sees:** a squad arrives in its travel wedge, then re-forms into a herringbone. The wing crews drive 20–47 m and
are still driving 8 s later (the "twitch"), past their squadmates, through the street.

## The trace

Laptop GDScript, seed 34 (the dev seed), main `61b6181e2` plus the probe's deploy columns (`tests/orders_probe.gd`
`_deploy_legs`), the 6 click cells (Terminus, Locks, Crossing x 3 / 5 squads), 24 squads. Rows:
`o2-trace-laptop-s34/rows.txt`. The columns are read 1 s after the deploy:

| squad | halt | leg as seated | best seating | half depth | travel width | halt depth | twitch |
|---|---|---|---|---|---|---|---|
| Terminus 5 sq4 (5 crews) | herringbone | 47.4 | 19.2 | 16.7 | 36.3 | 44.7 | 31.3 |
| Locks 5 sq2 (4) | herringbone | 16.4 | 14.1 | 7.3 | 27.8 | 32.8 | 26.5 |
| Crossing 3 sq1 (4) | herringbone | 17.4 | 17.4 | 14.0 | 31.9 | 37.8 | 25.2 |
| Locks 5 sq4 (5) | herringbone | 37.1 | 30.8 | 18.8 | 33.6 | 47.7 | 21.3 |
| Terminus 5 sq2 (4) | herringbone | 18.6 | 14.4 | 7.4 | 27.1 | 33.3 | 6.3 |
| 3-crew squads (9) | herringbone | 9.8–20.1 | same | 7.1–21.1 | 10–17 | 9.5–26 | 0–11.2 |

1. **The halt is deep.** Herringbone depth is (n − 1) x 0.8 x spacing. These squads lay it at the open spacing (14 m), so
   it is 33.6 m deep for 4 crews and 44.8 m for 5, ALONG the street. The wedge they arrive in is 27–39 m wide ACROSS it.
   Every twitch over 20 m is a squad whose halt is at least 33 m deep.
2. **Seating is the second cause, and only in one cell:** Terminus 5 sq4 needs 47.4 m as seated against 19.2 m with the
   best seating. That is D4's case, and D4's minimax seating failed its bar overall (R35, `68d4c06cd`).
3. **Legs seldom go THROUGH a squadmate.** Only 2 of 24 squads have a leg that passes within 4 m of another crew's spot.
   The deploy move is long, but it is not tangled.

## Design: DEPLOY_COMPACT, the deploy's herringbone staggered half as deep (switch, OFF until judged)

The herringbone alternates sides (±0.55 x spacing off the axis). Neighbours on the SAME side are 0.8 x spacing apart along
the axis; neighbours on OPPOSITE sides are much further apart. The compact form halves the along-axis step for the deploy's
halt only (0.4 x spacing):
- Opposite-side neighbours end up √((1.1 s)² + (0.4 s)²) = 1.17 s apart, still MORE than one spacing.
- Same-side neighbours keep 0.8 s, exactly as today, so the closest pair in the halt is unchanged.
- Depth halves: 5 crews in open ground go from 44.8 m to 22.4 m. Per the trace, the worst legs drop roughly in half
  (Locks 5 sq4 37 -> 19 m with best seating, Locks 5 sq2 16 -> 7, Terminus 5 sq2 19 -> 7).

**Where:** ElementPlan's halt lay for a DEPLOYED squad only (`_plan_halt` while `deploy.deployed`, orders' carve-out). The
herringbone in every other use (a CPU hold, an ordered herringbone, the halt with the step off) is untouched.
`TacticsFormation` is unchanged: the deploy rescales its seats along the heading about the anchor. **Seating:** unchanged
(D1's least total). D4 showed that seating alone doesn't decide it, and the shallower shape shortens every assignment.
**Switch:** `--deploy-compact=on` (env DEPLOY_COMPACT=on), OFF until judged; symmetric, though CPU elements rarely deploy (R35.5).

**Not chosen:**
- (a) Keep the travel wedge as the halt in streets: no move at all, but a wedge across a street is exactly what blocks
  the next squad (O1's theme).
- (b) Minimax seating: D4 failed it.
- (c) Lay the herringbone from the wedge's front backward: the squad would no longer stand ON his click (D1's promise).

## Bar (draft, for the orchestrator to file before any builder0 number)

- **Probe:** `make native orders-probe`, arms `main:` v `compact:--deploy-compact=on`, 24 cells (3 maps x {3, 5} x
  {click, route} x 2 arms), fresh seeds 3681–3686 (never run), n 6, medians. Builder0, native.
- **Counter first:** the arms' rows differ in at least half the cells that hold a herringbone deploy. The probe's
  `halt_depth_m` must be lower on compact.
- **Gain:** summed over the cells, the median `twitch worst m` at least 20 % lower on compact, AND the median
  `deploy_leg_m` at least 25 % lower.
- **Guards (each cell):** median all-in <= main x 1.2 + 3 s, with no more never-in seeds; median `twitch worst m` <=
  main + 3 m; median end foreign min >= main − 3 m; deck and far no higher (far bank 0); the closest squadmate pair at the
  end >= 0.75 x spacing (no crowding). Also test_control_scale's 3-tick response.
