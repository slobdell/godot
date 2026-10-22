# Stream: manoeuvre (parked crews make way and come straight back; CPU screens out of the way)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1) and in
> *Round 37*: R37.6, R37.10, R37.30, R37.32 and Bar M5. Your round-37 close notes: `streams/archive/round37/manoeuvre.md`; orders'
> O5 notes in `streams/archive/round37/orders.md`. **You own:** `movement.gd`'s drive / unstick / side-step and traffic's give-way
> block, `game/ai/traffic.gd`, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`; GRANT:
> `element_commander.gd`'s screen / support_by_fire seat choice for M7 (merge note to doctrine). **Model:** Opus. **Machine:** builder0.

## The lead's direction

"the general priority is to mitigate vehicle contention with one another"; parked squads "Stay put and shoot"; units must look smart.

What he will notice: a parked crew that makes way for a friend steps aside and reverses straight back instead of leading the friend out
or turning round; CPU squads screening a street don't block their own traffic.

## Where things stand (switches on main, OFF)

- **M5a seatstep (R37.30):** seat metres -8.5 %, lead-outs 747 -> 436, but failed guards: team 1 kills -89 (fights got smaller, not
  one-sided) and faced_ambush never-settled 5 -> 10 (your later read: a redraw on path differences, no mechanism).
- **O5 seat-aside (R37.32):** CPU screen give-ways -23 % (bar asked -50 %): screen->screen 742 -> 438, but screen->support_by_fire
  251 -> 255 (the aside step doesn't see support_by_fire routes).

## Backlog (in order)

1. **M1 M5 v2:** file the bar first with your close notes' changes: (a) kill SHARE per team + both teams' total deaths, not "each team's
   kills not down"; (b) size never-settled (e)'s noise floor first (base v base, two paths). Then the series. Symmetric: a pass ships ON.
2. **M2 M5b the reverse-back:** trace first; native twin request; bar.
3. **M7 O5 v2:** the aside step also reads support_by_fire routes; bar from R37.32's base.
4. **Stretch:** M3's S1 v2 (count the stall base rate with M2's total before building).

## How to verify

Lab both paths; `make quick-remote`; series on fresh seeds; every number with commit, machine, workload, n.

## Don't touch

settle's deploy/halt/seat functions, orders' control paths, doctrine's brains paths beyond your grant, `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
