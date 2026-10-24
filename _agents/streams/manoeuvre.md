# Stream: manoeuvre (a parked crew steps aside once for a friend and goes back, never shoved down the street in a chain)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 39** (C39.1, C39.2) and
> in *Rulings (round 38)*: R38.24, R38.26, R38.40, R38.43. Your round-38 brief: `streams/archive/round38/manoeuvre.md` (the s3866 read,
> the M5 v2 series, M7). **You own:** `movement.gd`'s drive / unstick / side-step and traffic's give-way block, `game/ai/traffic.gd`,
> `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`, `mk/manoeuvre.mk`. **Model:** Opus.
> **Machine:** builder0 light lane (J<=4). **Seeds:** 6101-6124 (registered).

## The lead's direction

"the feel of the game needs to have the user perceive that the units are smart and under their control". What he'd see today: a parked
tank backs off for a friend, then for the next, then the next, and ends up ~20 m down the street from its squad.

## Where things stand

- **s3866 (R38.26, `references/round38/manoeuvre/s3866-giveway/`):** crossing 5 click, squad 4 is NEVER in under the latch (both arms)
  because Alpha_3 gives way four times in 10 s to squad-4 crews; its seat distance goes 2.9 -> ~20 m. seatstep ON gets squad 4 in.
- **M5 v2 FAILED (R38.24):** seat metres -5.0 % v the 6.4 % bar; seatstep stays OFF (`--seatstep`).
- **M7 (O5 v2) blocked on the bar's reach**, not judged; v2 stays OFF (`--seat-aside=v2`).
- **82 long wedge episodes** (ORCA slow-down acted in 69, not the stall clock): untraced; only if he reports a tank grinding a friend.

## Backlog (in order)

1. **M1 chain-aware give-way (`--giveway-chain`, new switch).** A parked crew already pushed off its seat (beyond a radius you set
   from the census) does not give way farther from its seat; it gives way along or back toward it, or holds and lets the mover route
   round. Count chained give-ways' seat drift on the jam census FIRST (base numbers, no bar yet), then lab s3866 (squad 4 must get in),
   then the bar (deciding: chained seat drift down; guards: never-in, all-in time, deaths in give-ways, contacts, the fights), fresh
   seeds 6101-6124. Name settle's `--seat-route-clear` state in the bar (C39.2). Native twin: request `begin_yield`'s twin from native
   early (it was requested in round 38).
2. **M1 on top of settle's S1 (CP39.1):** when settle's switch passes, re-read yours on top (or the reverse), as the orchestrator says.
3. **M7 re-file only if worth it:** the seated half as SEATED screen give-ways (seat_m < 10). Otherwise leave it written up.
4. **Stretch:** trace the 82 long episodes' ORCA slow-down (who yields to whom, why neither moves).

## How to verify

Lab both paths; `make quick-remote`; one full check per named hash; the jam census and give-way series on builder0 light. Smoke:
`make skirmish ARENA=locks SKIRMISH_FLAGS="--giveway-chain"`, park a squad at a lane mouth and drive two squads through it.

## Don't touch

settle's seat deal and halt lay, orders' `game/control/**`, doctrine's brains, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Start (worker, 2026-10-23 ~21:15):** stream/manoeuvre = main 8952c3d64 + round-39 docs (906557c06), GREEN per HANDOFF (builder0
3135/0), so no baseline check (contract 1).

**Plan (in order):**
1. **M1 code (OFF), DONE 14a10e719:** `--giveway-chain` (= `--traffic-on=givewaychain`, Traffic.DEFAULT_OFF). A crew parked
   (phase arrived, or an order that is not a move_to) more than `CHAIN_M` (4.0 m, to be set from the census) off its seat
   (`Movement.yield_seat()`: move_to point, else face slot) takes no give-way spot farther from that seat than it stands (+0.5 m):
   along it, back toward it, or today's in-place hold. With none left, it refuses, and the asker treats it as parked (CP1a2:
   keeps its route, ORCA goes round). **Decision:** refuse rather than hold. A parked refuser is already the case the asker
   handles, and a hold would keep the asker waiting on a crew that can't move. **Native:** no C++ mirror yet, so while the
   switch is on it sets `BrainSwitches.native_yield = false` and asks run in GDScript (bit-identical to C++ per seed, R38.24).
   Twin requested from native via the orchestrator (2026-10-23 ~21:45). Test `tests/test_traffic_chain.gd` (5 cases).
2. **Census first (base, no bar):** `jam_census.gd` now prints GIVEWAY_CHAIN rows and `giveway_chain` totals (give-ways by off-seat
   bin and chain index; push_m = farthest from the seat during the give-way minus off_m). Run on main's behaviour (switch OFF),
   builder0 light, dev seeds; pick CHAIN_M from it.
3. **Lab s3866** (crossing 5 click, squad 4 must get in), both arms.
4. **The bar** (filed before numbers; seeds 6101-6124; settle's `--seat-route-clear` state named), then the series.
5. M1 on top of settle's S1 (CP39.1), when the orchestrator says. 6. M7 re-file decision. 7. Stretch: the 82 long ORCA episodes.

**Questions for the lead:** none.
**Requests to other streams:** native: `begin_yield`'s mirror of givewaychain (sent ~21:45).

**2026-10-23 ~22:00: PAUSED, laptop memory.** The builder0 light run of 14a10e719 (`native lint test FILTER=test_traffic|
test_native_yield|test_native_drive|test_native_traffic`) never started. It was still queued for a light slot (orders' and
doctrine's held both) when Claude Code reaped the local wrapper because the laptop was critically low on memory (736 MiB
available, 7.4 GiB total). I stopped the orphaned remote job (my `-light` folder only). So 14a10e719 has no builder0 result
yet: only the laptop GDScript run of test_traffic_chain (5/5). Next: re-run that light job, then the census (step 2), once
the lead OKs a restart.
