# M3: what a fresh stall net (S1 v2) would do differently. A design note to the orchestrator; no code before a ruling

## What R36.27 found
S1 stallnet (net-motion stall clock: a one-tick "pop" over STUCK_SPEED no longer resets the stall clock while the hull is within
STUCK_NET_M of where the clock started) passed its deciding lab stage and failed two series guards (builder0 native, ON 78a93fdb4 v
base 9564cc66e, 72 fight pairs): unstick fires 157717 -> 192380 (+22 %, up in 47 of 72 pairs, all three maps) and team 0 kills
1607 -> 1557. Its aim did not move: stuck:wedged deaths 251 -> 256. So the rule fired in many places it was not aimed at, and
where it was aimed it did not free anyone.

## A measurement caveat found this round (M2)
`Movement.unstick_fires` is a STATIC (one game-wide count; native adds to it too). The S1 tree's WEDGE_TRACE helper summed
`mover.unstick_fires` over every crew, so its "unstick fires" was the game's total times the number of crews counted: the +22 %
is the static's rise scaled by the crew count, which also differs between arms (fewer kills, more crews). The direction (up in 47
of 72 pairs, and escape fires per hull 1741 -> 2187 in the wedge rows) still says S1 fired more; the size of the breach is not
exact. Likewise WEDGE_EP's per-episode `unstick_fires` (and R36.32's "fires inside wedged episodes" rebuilt from it) counts every
crew's fires during that episode's window, not the wedged crew's. M2 prints the plain static total in WEDGE_TRACE, which is what a
v2 bar should quote; a per-crew count needs a native twin (an instance counter beside the static), a request to native if wanted.

## What v2 would do differently
1. **Narrow the target to friendly contact.** Hold the clock across a pop only while the hull's slide colliders include a FRIEND
   that has moved < H1B_MOVED_M (the X1(d) pinch: wedged between friends). Terrain, walls, enemies and moving traffic keep the
   round-29 reset bit for bit. This is the case the lab stage injected; the series' extra fires came from everywhere else.
2. **Route the fire to the friend logic, not a reverse.** When the held clock fills on a friend, the fire goes through H1's ask
   (and H1b / the side rule) like any honest hull fire, so the new fires are asks and side steps, not reverses into traffic.
3. **Cap per crew per goal.** At most N (2) net-held fires per goal per friend, the same bookkeeping as H1b's failed asks, so a
   v2 cannot storm.
4. **Base rate first (R36.23).** Before any bar: count, on main, wedged episodes where the clock was reset by a pop while in
   friendly contact with an unmoved friend, and how many of those crews died wedged. If that count is a handful in 72 fights,
   v2 has no workload and should not be built (the R35.77 lesson: the stage proved a rule whose target is rare).

## Recommendation
Do step 4 only (a trace on main with M2's totals, light lane, ~1 h); build v2 only if the base rate is worth a series. I will
not start it without a ruling.
