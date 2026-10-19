# Stream: orders (squads arrive in their travel shape and deploy as one move, packed close; routes that don't jam)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 35** (C35.1, C35.2, C35.4, C35.5),
> `_agents/game_design.md` *Round 34, his playtest words during the round* and *Round 34 close* (his answers, verbatim), and the
> round-34 briefs `streams/archive/round34/orders.md` and `streams/archive/round34/brains.md` (B6, B8, B8b, O1–O4, R34.12: the
> whole history of this code, with every trace). Evidence: `references/round34/orders/` (planner's probe, the lead's pass and its
> screenshots), `_agents/streams/references/round34/brains/` (B6/B8 traces and tables).
> **You own:** `game/control/**` (except manoeuvre's additive fields in `game/control/screen_playtest.gd`), `tests/test_control*.gd`,
> `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`, and in `game/tactics/element_plan.gd` the deploy-step and
> halt-lay functions (`DEPLOY_STEP`, the deploy step's helpers, the halt seat lay for a plain AUTO move; merge note to brains).
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

His round-34 report, verbatim: *"If I select 3 squads and then tell them all to move to some point on the map, there's some
algorithm that automatically determines new points for each squad … one of them was all the way across the bridge, thus causing
one of my squads of scouts to go on a suicidal mission. How can we get behavior closer to starcraft…"* His corrections: squads may
nest (*"isn't there enough spacing where we could intersect two wedges basically?"*), and waypoints are the squad's (*"it's more
about the squad moving through that waypoint versus individual vehicles"*). His answer at round 34's close: **"Yes, use the deploy
step"**: a squad arrives in its travel shape and spreads into its halt shape as one deliberate move.

What he will notice this round: squads that arrive and deploy once, with no twitching afterwards; several squads sent to one point
packed close but never on top of each other; five squads on a Locks route that don't jam at a junction.

## Where things stand (main at the round-35 docs commit)

- **Shipped in round 34:** O1 the ground cap (no squad sent over a bridge it wasn't clicked across), O3 squads priced at their halt
  shape, O4 routes are the squad's (passed at about its width, gates), o4b, brains' two Locks fixes (stations and order goals stay
  on the anchor's bank), the rank fix + rank depth (the back rank comes up), ground_anchors (an anchor on a building stands beside
  it), the player-route stall fallback (12 s settled), gate order (first through a shared gate takes the farthest place). The
  lead's pass on main 62d90dc97: no crossing in 24 cells; five squads all go; routes finish except the Locks cells below.
- **The deploy step:** B8b is on main OFF. `round34/brains` `07c029732` is the WIP that flips it ON (tests updated, `test_on_by_default`),
  **no check run**. It reaches CPU elements too (ElementCommander gives plain moves), so sim-baseline WILL move.
- **The shuffle:** post-arrival seat moves 19–38 m worst with 3 squads, up to 87 m with 5 (main); with B8b, the twitch after the
  deploy is ~0 in 4 of 6 cells, the deploy move itself 16–30 m. Remaining causes known (B6/B8b traces): the halt re-seat after 2 s,
  travel seats re-grounded while the slowest crew arrives, the Locks strip between canal and building squeezing seats.
- **O2 packing (parked R34.12):** an AUTO pack before the deploy step was neither tighter nor fast enough (the heading isn't known at
  order time). With the deploy step, it is: the halt seats are laid on the order's approach heading. `wip/brains-o2` holds the
  attempt and the rotation-tolerant core.
- **Locks 5-squad route:** squads 3 and 5 jam for ~55 s at (5, 65); their drives cross though their anchors' lines don't
  (planner's trace, `references/round34/orders/gate-order-f1034b904/`).

## Backlog (in order)

1. **D1 Ship the deploy step ON (C35.2).** Start from `round34/brains` `07c029732` (cherry-pick or merge onto your branch). Laptop
   tests, then the full check on builder0 under systemd-run; attribute every moved sim-baseline map with `DEPLOY_STEP=off` on the same
   tree. A REPORTED fights census beside it (fresh fixed arenas, both sides, deaths/kills/stuck), since the CPU gets it too; bring a
   gross regression (> 2 se) to the orchestrator before shipping. Name the hash; the orchestrator adopts the baseline.
2. **D2 The probe on the shipped hash.** `make orders-probe` (planner's, now yours): 24 cells, main v `--deploy-step=off`, with the
   screenshots at arrival and +5 s. File as the "before" for D3.
3. **D3 Tight packing (C35.4).** On the deploy step: the order fixes each squad's approach heading; the halt seats are known at
   order time; pack by hull clearance (~9 m between crews of different squads), his 28 m between two columns, each squad on its own
   side of the approach, back ranks no farther back than their own squad, nothing on a building. The click's 3-tick response kept.
   Bar filed with the orchestrator before any number (the probe's cells + the squad-arrive / settle series, both arms).
4. **D4 What's left of the shuffle.** Trace the 5-squad cells' remaining post-deploy moves and the Locks strip; fix what the trace
   names (likely seats re-grounded during the wait, and the halt re-seat).
5. **D5 Crossing drives on the last leg (C35.5).** Deal the last leg by navmesh paths where they cross; a length guard; the Locks
   5-squad route as the test; probe before/after.
6. **Stretch:** the order markers show each squad's real halt place before he lets go of the button.

## How to verify

Tests first; `make quick-remote` while iterating; `make remote T=check` only for a hash you'll name (one at a time on builder0).
`make orders-probe` for anything he'll see, with screenshots looked at. Every number: commit, machine, map, n.

## Don't touch

`game/ai/**`, the rest of `game/tactics/**` (brains), `screen_playtest.gd`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing (his deploy-step yes is the go).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### D3 bar (C35.4), FILED BEFORE ANY NUMBER (2026-10-19 ~09:20 PDT)
- **Probe:** `make orders-probe` on builder0 (native), seed 34, n 1 a cell (deterministic): Locks / Crossing / Terminus x 3 / 5
  squads x click / route = 24 cells, arms `main:` (pack on) v `pack_off:--pack=off`, the same tree, the deploy step ON in both.
- **Gain (must pass):** over the 6 CLICK cells, the median of each cell's `end far max m` (the farthest crew from the click at
  the window's end) at least 15 % below pack_off's; and in EVERY cell `end foreign min m` >= 7 m (the 9 m design, less
  grounding slop), on both arms reported.
- **Guards (each must hold in every cell):** all-in <= pack_off x 1.2 + 3 s, and no cell all-in on pack_off but not on main;
  far bank 0; `toward min m` >= 0 (nobody sent away from the click); `twitch worst m` <= pack_off + 5 m.
- **Response:** `test_control_scale` (the click's 3-tick response) passes in the check of the named hash.
- **Single squads:** the pack acts only on 2+ squads; `make squad-arrive-series ARRIVE_ARM_FLAG=pack ARRIVE_MAPS="terminus sumps"
  ARRIVE_SEEDS="1 2"` both arms must be byte-identical (an equality check, reported).
- Screenshots (`orders-probe-shots`, arrival and +5 s, desktop and phone) looked at for every 5-squad click cell.

### D1 census bar (C35.2), FILED AFTER THE READING (said plainly)
The census ran (`e9066083a`, builder0) before the orchestrator asked for the bar, so this bar is written after its numbers.
It is moot in this instance: the two arms are byte-identical (below), so no line could read differently.
- **Probe:** `make deploy-census`: CPU v CPU (both sides ElementCommander), Locks / Terminus / Sumps x fresh seeds 3501-3516,
  factions rotated by seed, 1000 credits, 150 s, paired by (arena, seed), on v `--deploy-step=off`; n 48 pairs.
- **Gross (blocks shipping, to the orchestrator):** per side or pooled, deaths UP or kills DOWN by more than 2 se of the
  summed paired difference; stuck crew-seconds UP by more than 2 se. Alive and deploys are reported only.
- **Reading:** every line diff +0.0, se 0.0: arms byte-identical, 0 deploys on either side. The census's CPU gives
  screen / attack / support_by_fire / ambush tasks, never a plain move (`--trace=on`, laptop, Locks s3501, 40 s), so the deploy
  step never fires in a fight. **Not gross: D1 passes.** Rows: `references/round35/orders/d1-census-e9066083a/`.

### Plan (2026-10-19, round 35)
1. **D1** the flip (`ee16b1b1e` = main a0ae0aafd + 07c029732's code; brains' brief left out) → quick-remote → full check on
   builder0 (one at a time: the orchestrator's C35.3 pair check is on the box at launch) → attribute moved sim-baseline maps
   with `make remote T="native sim-variants VARIANTS_EXTRA=--deploy-step=off VARIANTS_TAG=deployoff"` (off must read the
   recorded lines) → the REPORTED fights census (`make deploy-census`, new: CPU v CPU, Locks/Terminus/Sumps x fresh seeds
   3501–3516, factions rotated, on v off, deaths/kills/stuck/deploys by side, > 2 se = gross) → name the hash.
   *Decided:* own census probe (`tests/control/deploy_census.gd`) rather than manoeuvre's fight_census (random arenas deal
   twins, R34.15; it has no stuck count) or traffic's jam census (not on main).
2. **D2** `make orders-probe` arms `main:` v `deploy_off:--deploy-step=off` on the shipped hash + shots (arrival, +5 s).
3. **D3** tight packing (bar filed first). 4. **D4** shuffle trace. 5. **D5** crossing drives. 6. Stretch: halt markers.
