# X3c: the Crossing halt detours (design note only, round 35 extension; laptop, no number)

## What he sees
Three squads clicked to one point near a Crossing bridge. Each one arrives and deploys, and then one or two crews drive a
20–30 m loop to reach a seat that is only 9–19 m away in a straight line. Alpha_1 drives to the end of the west deck and
back over 20 s, and Alpha_3 drives 30 m south and back. It reads as "the squad twitches after it arrived". (Traced in D4:
laptop GDScript, seed 34, the Crossing 3 click cell, stream/orders `9370f5ddb`; the brief's *D4 what's left of the
shuffle*.)

## Cause
The deploy lays the halt geometrically. `ElementPlan._deploy_state` puts the halt ON the spot (within 12 m), and
`_dry_halt_anchor` steps it inland only from WATER and from the far bank. A seat behind a wall, a deck rail or a canal
edge has dry ground and is on the right bank, so it passes, but it can only be reached the long way round. ElementPlan
is pure (no navmesh), so it cannot tell.

## Design: the controls hand the deploy a reached halt (`halt_at`); ElementPlan does not change
Everything this needs already exists in the controls:
- D3 gave the task `halt_at` / `halt_shape` (R35.6), and `_deploy_state` already stands a halt where `halt_at` says.
- `SelectionSquads._reached_from(click, p, drive, crosses)` already measures path length against straight distance on
  the navmesh. The ground cap and the pack's `reached` use it.
- `SelectionSquads.halt_offsets(shape, count)` and `approach_of` lay the halt seats at order time, as the pack does.

The step, at order time in `RtsControls._order_squads`, behind a switch (`REACHED_HALT`, OFF until judged), for every
squad on a plain AUTO move (one squad too, not only the pack's 2+):
1. Lay the squad's halt seats as the deploy will. Shape: `squad_halt_shape`. Heading: the squad's own approach (its
   centre, or the queued last point, to the click). This is the same heading `_deploy_state` derives when the task has
   no `lay`.
2. Test each seat for "reached by a short drive" from the anchor, with a tighter test than the ground cap's (that cap
   lets an 8.7 m seat cost a 21 m drive): `drive(anchor, seat) <= straight * 1.3 + 3 m` and not `crosses`.
3. If every seat passes, set nothing. The deploy behaves exactly as today: switch-OFF inertness in practice, and no
   extra task keys on most orders.
4. If a seat fails, step the anchor 2 m at a time AWAY from the failing seats, up to 24 m, as `_dry_halt_anchor` does
   for water, until every seat passes. Then hand `halt_at` = that anchor and `halt_shape` = the shape. If no step
   passes, set nothing (today's halt) and count it (`reached_halt_none`).

Cost: at most 13 steps × ≤ 6 seats of navmesh path queries per squad, once per click. That is far below `pack_halts`,
which already runs on a 5-squad click. The click's 3-tick response (`test_control_scale`) must be re-read.

## Why not inside ElementPlan
To do it there, the situation would need a reachability map (brains' `element_situation.gd`, not ours), recomputed every
update. The halt is laid once, at the deploy, from a heading fixed at the order. So the order time is the right moment,
and the controls already own the navmesh queries. "ElementPlan stays pure" holds: it reads one more value of an existing
key.

## Known gaps (round 36 reads them first)
- The test runs from the ANCHOR, not from the travel seat each crew arrives on (that seat is ElementPlan's, decided
  later). A seat reached from the anchor but not from the crew's own side can still detour. First falsifier: on the
  Crossing 3 click cell (seed 34), log each crew's travel seat at the deploy, its halt seat, and the drive between them,
  then check that every 20–30 m loop is a seat that step 2 fails. If not, the anchor proxy is wrong and the design needs
  the arrival side.
- `halt_at` also overrides the 12 m on-spot rule (the halt stands at `halt_at` even when the squad deployed on the cap
  far short). That is today's D3 behaviour; keep it, or gate the key on the same 12 m test.
- A drawn facing or an attack is out of scope (no deploy).

## Bar shape for round 36 (to file before any number)
Probe 24 cells × fresh seeds; arms `main:` (REACHED_HALT on) v `reached_off:`.
- Gain: the Crossing cells' `place worst m` and `twitch worst m` medians fall by ≥ 25 %.
- Guards: far bank 0 in every cell; all-in ≤ base × 1.1 + 2 s; `end far max m` ≤ base + 5 m (a halt stepped away from
  the click must not spread the squads); EQUALITY in the Terminus click cells (open ground, no step expected).
- Counter first (R35.5): `reached_halt_stepped` non-zero in the Crossing cells.
