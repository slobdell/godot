# T7 (C35.8): under fire, refuse a give-way only when the asker has another way. The design note, before any code number.

**What he will notice.** A crew being shot at no longer steps aside into the open for a squadmate behind it **when that
squadmate can simply drive round it**; the squadmate drives round. In a lane where there is no way round, the crew still
makes room as today, so nobody stalls behind it.

**Why (round 34's two judged tries, R34.17, R34.20).** Refusing EVERY ask under fire cut jam-under-fire deaths 53–69 % (7 se,
twice), but T6b moved the dying one for one into stuck/blocked/parked deaths: a refused asker stalled behind the refuser
(far loops 96 → 192, stuck deaths 902 → 963). T7 keeps the half that is free (the asker can go round) and drops the half that
costs (a lane: the asker can only wait).

## How "another way" is read: a pass lane beside the refuser, swept for the ASKER's hull

Of the three candidates the brief names:

- **parkedroom's room/route test** answers the wrong question: it finds a spot off the asker's route for the PARKED crew to go
  to. Its reading of the asker's way (the route near me) is the part reused, below.
- **a navmesh detour bound** cannot see hulls: the navmesh is static, so a re-path "round a friend" needs the friend carved
  in per ask (not available deterministically or cheaply in Godot's server).
- **the asker's own route options** (another lane) are brains' and metres-to-hundreds too coarse; B9 (R34.19) showed a lane
  change is not a lever on these deaths.

**Chosen: the pass lane (`Movement._pass_lane(asker, me)`, deterministic, navmesh outline + hull discs, no physics query).**
`way` = the direction the asker asked with (toward its next waypoint; `ask()`'s `direction`), `across` its normal.
For each side, the side the asker already leans to first (ties: its left, as `_begin_yield`):

1. **Abreast point** P = my centre + across · side · L, L = r(me) + r(asker) + `YIELD_LINE_MARGIN` (Avoidance radii: the
   clearance the give-way itself keeps between two hulls passing).
2. **Rejoin point** Q = P + way · (half-length(me) + half-length(asker) + `PASS_BEYOND_M` 2 m): the asker's tail clear of my nose.
3. P must be AHEAD of the asker along `way` (a pass is forward; a crew ahead of me going away needs no pass, so it is
   given way to as today), and for a wheeled asker outside both its turning circles (`_ahead_of_wheels`' arithmetic at the
   asker's pose).
4. **The asker's whole outline** (`_kturn_frame(asker)`, the ten outline points the k-turn and give-way sweeps use) is
   clear (`_outline_ok`, with the asker's own start pose as `start`) at poses every `PASS_STEP_M` 2 m along asker → P → Q,
   heading along each leg.
5. **No third hull** (not me, not the asker) within r(it) + r(asker) of P or of Q (Avoidance neighbours).

A side that passes all five is the asker's way round; the answer carries the side (the asker steers by it). Cost: ≤ 2 sides ×
~12 poses × 10 navmesh points, only when a crew UNDER FIRE is asked (T6: ~19 refusals a fight).

## The rule

Under fire = hit within `UNDER_FIRE_S` 5 s (T6's, unchanged). Switch `--traffic-on=underfire` (DEFAULT_OFF until judged).

- **(a) ask()**: after the battery rule (a set-up firing hull keeps its spot whatever: his round-34 answer), a crew under fire
  refuses ONLY if `_pass_lane(asker)` finds a side. It hands the side back (`pass_offer`). Otherwise the give-way proceeds as
  today (counted `underfire_gives`).
- **The asker after an under-fire refusal goes round (new; T6b had none):** in `_negotiate`, instead of stepping aside itself
  (a mover that refused) or keeping its route to ORCA (a parked one), it takes a **pass**: for up to `PASS_MAX_S` 6 s its
  steering point is the refuser's abreast point on the offered side, recomputed every tick from the refuser's position (it
  may be moving); ORCA still shapes it (`_avoid`, the substitution happens there, before the solve). The pass ends when the
  asker is abreast (its centre past the refuser's along `way`), the refuser is dead or gone, a T1 street-mouth hold takes the
  crew, or the clock runs out (counted: `passes`, `passes_done`, `passes_timeout`). ORCA alone does not do this: behind a slow
  mover the nearest safe velocity is FOLLOWING (T6b's far loops).
- **(b) the asker's own step aside under fire** (`_negotiate` decides I give way): held only if the OTHER has a pass lane
  round me (the same test, roles swapped); otherwise I step aside as today. When it holds, the other meets me, asks, is
  refused with an offer, and passes: one rule, both directions.
- A give-way already begun finishes (T6b's (c) removal stands).
- **Not gated:** `_ask_behind` (`via == "behind"`: an unsticking crew asks the one behind for room to back off; reversing has
  no pass lane), and the T1 hold (`Traffic.holding` returns before any ask).

## Interactions

- **The battery rule** counts first, unchanged: a firing set-up truck refuses with no offer; the asker treats it as parked
  (CP1a2), as today.
- **parkedroom** is not on main (parked, R34.13); T7 is cut on main without it.
- **O4 routes and o4b gates:** `way` is the crew's own drive direction toward its next waypoint, which under O4 is the leg to
  its squad's current gate; nothing about the route changes, and a pass only ever substitutes the steering point for ≤ 6 s.
  A gate as narrow as one hull has no pass lane, so crews in single file over a bridge give way as today.
- **T1 holds / T3 turns:** a held crew never asks; `Traffic.shape` still shapes the pass's preferred velocity.
- **Escape / unstick** (manoeuvre's): untouched; a pass never starts while escaping (`_negotiate` is not reached then).

## Native

`ask()`, `_begin_yield`'s gate and `_negotiate`'s body run natively (Drive::ask / begin_yield / negotiate_body); the pass
substitution is in `_avoid`. Native mirrors from `badfdb978`'s T6b twins with the new gate: `pass_lane` (NavNative::outline_ok
is already the same bits), the offer, and the pass steering point. Spec lines go to native with the first green commit.

## Tests first (`tests/test_traffic_underfire.gd`, extended)

1. A crew under fire asked by a squadmate with open ground beside it refuses, offers a side; the asker passes and ends past it.
2. The same pair in a one-hull lane (walls both sides): the crew under fire gives way as today (`underfire_gives` 1).
3. A third hull standing in the pass lane: no offer, the give-way proceeds.
4. A crew NOT under fire gives way as today on open ground (inert when not hit).
5. Switch off: identical to main (T6's inertness test, kept).
6. (b): a crew under fire that would step aside holds only when the other has a lane; in a lane it steps aside.
7. A pass ends at the clock (6 s) when the refuser keeps pace.
8. `_ask_behind` is never refused for fire.

## The bar (filed in workstreams *Bars (round 35)* before any number)

T6b's lines on a FRESH fixed-arena block `{terminus, locks, sumps, gorge, parade} × 1600–1627` (n 140, no random arena, no
twins; clear of T5 1200–1247, T6 1300–1327, T6b 1500–1527, parkedroom and T4 blocks), native, one machine (builder0),
pinned, 180 s showmatch. k = 1.645, paired se.

- **G (deciding gain):** jam-under-fire deaths (T5's definition) arm < base and (base − arm) − k·se > 0.
- **Guards:** (1) open deaths within ± k·se; (2) stuck deaths ≤ base + k·se; (3) far loops ≤ base + k·se; (4) kills ± k·se
  and hit rate ≥ base − k·se; (5) friendly contacts in the 3 s after a give-way ended on a hit ≤ base + k·se; (6) crossing
  arrivals 44–46 × 6 ≥ base − k·se a case; **(7, new) contacts during a pass** (the passer's friendly hull contacts while
  passing) reported, and all friendly contacts a fight ≤ base + k·se.
- **Reported:** standoffs with durations, all jam deaths, all deaths, deaths by cause, `underfire_refusals` /
  `underfire_gives` / `underfire_holds`, `passes` / `passes_done` / `passes_timeout`.
- **Sizing (from T6b):** G's se ~16 at n 140; a T6b-sized refusal share would be ~7 se; if only a third of the refusals have
  a lane, G still clears at ~2–3 se. Stuck deaths' se ~32 (line ≈ base + 52).

A fail is traced (worst fight first) and reported; no re-read of a line.

## RESULT (2026-10-19 20:18 PDT): T7 PASSES its bar as filed.

Pair `pair/underfire-t7` `e95179252` (C31.1 green: 2902/0, sim-baseline the ON arm's 5 moves, switch-OFF 13 unmoved), builder0 start
to end, native, pinned, 180 s, fixed arenas {terminus, locks, sumps, gorge, parade} × 1600–1627, n 140 paired, none missing;
crossing series 44–46 × 6 both arms. Raw: `t7_series_e95179252.txt`, `t7_series_crossings_e95179252.txt`, `t7_series_driver.log`;
per-fight logs `~/overnight-traffic/r35/t7series/`.

**Counters first:** arm underfire_refusals 427, passes 311 (192 ended abreast, 44 timed out), underfire_gives 1327 (an ask under fire
with no lane: given way as before), holds 68; base all 0.

| line | base → arm | se | verdict |
|---|---|---|---|
| **G jam-under-fire deaths** | **277 → 240 (−37, −13 %)** | 17.65 (drop − k·se = +7.97) | **PASS** (2.1 se) |
| 1 deaths in the open | 4780 → 4746 | 51.8 (band ± 85) | PASS |
| 2 stuck deaths | 958 → 960 | 31.9 (line ≤ 1010) | PASS |
| 3 far loops | 108 → 108 | 23.0 | PASS |
| 4a kills | 6037 → 5979 | 42.4 (band ± 70) | PASS |
| 4b hit rate | 0.732 → 0.731 | 0.0051 (line ≥ 0.723) | PASS |
| 5 contacts in 3 s after a hit-ended give-way | 416 → 407 | 55.5 | PASS |
| 6 crossing arrivals (4 cases × 18) | 180/180 in every case, both arms | | PASS |
| **7 all friendly hull contacts** | 107053 → 107271 (+0.2 %) | 1825 (line ≤ 110055) | PASS |
| R contacts with a crew passing | 0 → 566 | | reported (0.5 % of contacts) |
| R jam deaths, all kinds | 344 → 313 | 19.2 | reported |
| R all deaths | 6082 → 6019 (−63) | 42.6 | reported (1.5 se, not a line) |
| R standoffs | 3 → 3 (same durations) | | reported |
| R held deaths ((D)) | 244 → 238 | 14.6 | reported |

**By arena (reported; the bar is pooled):** G terminus 66 → 49, sumps 71 → 60, gorge 52 → 40, locks 55 → 56, parade 33 → 35; stuck
deaths terminus 187 → 201, locks 210 → 197, sumps 227 → 191, gorge 181 → 196, parade 153 → 175 (each inside its own noise, the pooled
total flat).

**Reading.** The half of T6 that was free is kept and the half that cost is gone: stuck deaths and far loops do not move (T6b had
+61 and ×2), and nothing else moves either. The gain is smaller than T6b's (−13 % v −53 %) because only about 1 in 4 under-fire asks
has a lane (427 refused v 1327 given way): in the lanes where most jam deaths happen the crew still steps aside, by design. The
Terminus carries most of the gain (its streets have room beside a hull); the Locks' one-hull lane mouths give none. **Ship
condition outstanding:** perf-judge alone on a quiet builder0 (owed; the check's three tries were refused for load), and a hand-over
re-cut on current main (the pair's base is c55471a5e; main has since taken D1 and N3) with one fresh check.
