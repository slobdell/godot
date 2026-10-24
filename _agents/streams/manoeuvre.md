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

**2026-10-23 (orchestrator R39.2, main 784e32eff), noted:** CP39.0 pairing base landed: 8952c3d64 on builder2, 320/320 fights,
blob 41 %, turtle 38 %; file `references/scoreboard/guards/8952c3d64.fights.jsonl` (stream/native 407a156cb). This is the base my
bar's fight guards pair against. Native's givewaychain twin (N3): `pair/native-givewaychain` 37735bf4b, 0 mismatches, quick-remote
pending. Once it's green, the `native_yield` bypass in `Traffic._chain_native` comes out on merge (native's mirror runs the rule).
The laptop-v-builder pairing ban still stands until native's N4 merges. Still PAUSED on laptop memory (above).

**Native's N3 (pair/native-givewaychain 37735bf4b, on my 14a10e719):** the C++ copy of the rule, in drive_native.cpp
begin_yield at my two places. Native removes `Traffic._chain_native`, so asks run in C++ again with the switch on; my last test
becomes test_the_switch_leaves_native_yield_alone. Twin: 105 forced poses an arm, 0 mismatches on the laptop. Its quick-remote
failed lint on MY census line (`started` couldn't be typed from an untyped Array). Fixed the same way here as d7259b161, so
**14a10e719 is not nameable; d7259b161 is the code to check.** Waiting for native's green hash.

**Native's N3 quick GREEN: pair/native-givewaychain bb8043686** (= 37735bf4b + the same census lint fix as my d7259b161), builder0
quick-remote `exited 0`, 104 passed / 0 failed, lint clean. Chain stages ON / ON owned / OFF: 105 drives each, 0 mismatches.
A full check of bb8043686 is running on builder2; that's native's merge hash for the orchestrator. Until the merge, my ON arms can
run on the native path from that branch (C++ runs the rule; native_yield stays on). This is native's evidence, not a check of my
branch: d7259b161 itself has no builder result. Still PAUSED on laptop memory, waiting for the lead's OK to restart builder0 runs.

**bb8043686 GREEN on builder2 (native's full check):** `make check exited 0`, 3143 passed / 0 failed, sim-baseline 13/13
unmoved. It holds my M1 code (14a10e719 + the d7259b161 census fix) plus native's mirror; native has given it to the
orchestrator as the pair's merge hash. This is the first full check covering givewaychain (OFF by default). Still PAUSED on laptop
memory until the lead OKs restarting builder0 runs.

**2026-10-24: merged main 76f42a9c3 (green builder0 3169/0) as c35cc93ac.** Clean merge: the tree = main + Status +
`tests/traffic/chain_table.py`. givewaychain now runs through native's C++ mirror (no `_chain_native` bypass). I stopped my
pre-merge light test job; main's check covers this code.
**Seeds:** the census (`manoeuvre-census-base`, builder0 light J4, c35cc93ac, switch OFF, terminus/locks/sumps x 7001-7008) is a
DEV read on my round-38 dev block 7001-7008 (allowed by the registry note). Nothing judged runs on it; the bar's series uses
6101-6124 only.
**M1 bar ETA (2026-10-24 11:00 PDT):** verdict ~16:30-17:00 PDT (census started 10:29 PDT and is nearly done; then s3866, the bar
filed, the series). It is CP39.1: I send the verdict and the tree's green hash to the orchestrator AND orders (godot-orders-db) at
once, pass or fail (with the cause if traced).

### M1 census (base, DEV): c35cc93ac, builder0 light J4, native, switch OFF, terminus/locks/sumps x 7001-7008, 24 fights
(`~/overnight-manoeuvre/r39/census_base/`, `tests/traffic/chain_table.py`). Give-ways by a crew with a seat: 4,505 (travelling
3,312, parked 1,193). Parked: 2,886 m of drift left off seats (mean 2.42 m a give-way). By off-seat at the start: 0-2 m 245
(3.46 m each), 2-4 m 499 (2.78), 4-6 m 189 (1.89), 6-10 m 58, 10-20 m 66, 20+ m 136. **Chained (> 4 m off): 449 give-ways,
650.5 m out, 27.1 +/- 22.7 m a fight.** By chain index among those: 0 = 328 (never back within 2 m), 1 = 73, 2 = 30, 3+ = 18. The
biggest single pushes are lead-outs (spot(16,0) / (24,0): 10-14 m). Deaths jam:yielding 48, jam:friend 16, stuck:* 162;
parked refusals 1,246. **CHAIN_M stays 4.0:** 2-4 m is where loosely seated crews take their FIRST give-way (the lead's "steps
aside once"), and lowering it would refuse those.

### M1 lab s3866 (builder0 light, native, 2677407d8 = c35cc93ac + Status, n 1 an arm; `~/overnight-manoeuvre/r39/s3866/`)
crossing 5 click, squad 4 traced: **switch OFF, squad 4 never in (90 s); ON, in at 83.2 s.** Squads 1/2/3/5 identical. Late: the
rule keeps the parked crew from being pushed down the street, but squad 4 still queues round the anchor for ~50 s. The bar
guards all-in time.

### Bar M1 (filed 2026-10-24 ~11:25 PDT, BEFORE any series number)
- **Tree / arms:** c35cc93ac's code (later commits on the branch are Status / docs); OFF (default) v ON `--giveway-chain`; native
  ON (C++ mirror, bb8043686 in main). **settle's `--seat-route-clear`: OFF in both arms** (main's default; S1 not passed).
  builder0 light lane, J 4. Seeds: the registered block 6101-6124, split: A on 6101-6112, B on 6113-6124.
- **A, jam census** (`traffic-jam-census`, terminus/locks/sumps x 6101-6112, 180 s, 36 fights an arm; paired by fight):
  - **D (deciding): chained seat drift** = sum of `giveway_chain["parked:chained"].out_m`. PASS: ON <= 0.5 x OFF AND the paired
    per-fight mean difference < 0 by >= 2 se.
  - G1 deaths in give-ways (`jam:yielding` + `jam:friend`): ON - OFF <= max(2 paired se, 3).
  - G2 stuck deaths (`stuck:*`, the asker that can't get round a refuser): ON - OFF <= max(2 paired se, 3).
  - G3 friendly contacts: ON <= 1.10 x OFF.
  - G4 the fights: each team's kill share within +/- 0.03 of OFF; total deaths within +/- 5 %.
- **B, orders probe** (`orders-probe`, locks/crossing/terminus x 3,5 squads x click,route x 6113-6124, 144 runs an arm):
  - G5 never-in runs (a run where some squad never arrives): ON <= OFF.
  - G6 all-in time (the run's last arrival), runs where both arms got all in: paired median ON - OFF <= +2.0 s, and no cell's
    median worse by more than 10 s.
- **Reported, not judged:** chained n, chain_in_play / skipped / refusals, parked_refusals, all parked drift, s3866's arrival.
- **Not paired against CP39.0** (the 320-fight guard lines are builder2 scoreboard series; A's fight rows pair the same tree and
  seeds). If the orchestrator wants a CP39.0 guard line on ON before merge, that is a builder2 run.
- **Verdict:** every line passes -> PASS (ship ON is the orchestrator's / the lead's call: symmetric AI, CP39.1). Any FAIL ->
  no re-run on these seeds; the cause traced and written up. Judge: `tests/manoeuvre/chain_judge.py` (committed before the run).
**Bar M1 series STARTED 2026-10-24 ~11:35 PDT** (`manoeuvre-bar-m1`, builder0 light J4, native, judge 879caa818 committed first;
code = c35cc93ac). Order: census OFF, census ON (6101-6112), orders probe both arms (6113-6124), then the judge. Out:
`~/overnight-manoeuvre/r39/bar_m1/verdict.txt`. ETA ~16:30 PDT.

### M3 (M7 re-file): NOT re-filed; stays written up as blocked (decision 2026-10-24, no new runs)
Round 38's dev read (builder0 native, 53159326e v b5775051e, locks/gorge/terminus x 3801-3806, 18 fights) already has the
seated half: SEATED screen give-ways (seat_m < 10) **v1 250 -> v2 241 (-3.6 %)**. Re-filing the deciding line on the seated half
would still ask a series to find a ~50 % cut where the dev read shows ~4 %. That's a fail by construction and not worth builder0
time in a round where the light lane is the bottleneck. `--seat-aside=v2` stays on main, OFF. If he reports CPU screens blocking
their own traffic, the lever is the off-seat half (screen crews >= 10 m off their seats while driving: 48-50 % of screen
give-ways), not the seat choice.
**Bar M1 tree note:** each leg of the series rsyncs the branch as it stands when that leg starts. Commits after c35cc93ac
(879caa818 judge, f22e662e7 wedge_trace partner classes, Status) touch no game code, so every leg runs c35cc93ac's game code. No
game-code commit until the series ends.

### Stretch (the 82 long ORCA episodes): instrument READY, run after the bar
`tests/manoeuvre/wedge_trace.gd` now records, for each wedged tick, the partner: the friendly hull touched, else the nearest friend
ahead within 8 m. Each is classed `state/way/mutual`, and `tests/manoeuvre/partner_table.py` tables it over round 37's target
(touching, net < 0.5 m, >= 3 s). Laptop smoke only (f22e662e7, locks 6640, 90 s: 250 episodes, 2 target). The trace runs on
builder0 light (`native manoeuvre-wedge-trace`, locks/terminus/sumps x round 37's 6640-6663) once the bar series frees the lane.
