# Stream: settle (a squad that has stopped stays settled: right shape, own spots, no tank crossing the squad)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1, C38.3) and
> in *Round 37*: R37.13, R37.17, R37.28, R37.37, R37.40, R37.42 (and the O1 / O1-LATCH / O2 bars). Orders' round-37 close notes:
> `streams/archive/round37/orders.md` (its traces are yours now). **You own:** in `game/tactics/element_plan.gd` the deploy-step,
> halt-lay and seat-deal functions; `game/tactics/element_situation.gd`; `game/tactics/deploy_passers.gd`; the PARKED_HOLD seam in
> `tank_brain.gd` (one guarded function, merge note to doctrine); `tests/settle/**`, `tests/test_settle*.gd`, `mk/settle.mk`; you may
> run orders' probe (`make native orders-probe`) and judge (`orders_judge.py`). **Model:** Opus. **Machine:** builder0.

## The lead's direction

His standing bar: "the feel of the game needs to have the user perceive that the units are smart and under their control". Parked
squads: "Stay put and shoot"; a nearly dead parked crew pulls back and returns (round 37). The defects below are things he'd see.

## Where things stand (switches on main, OFF)

- **The deploy deal crossing (R37.37):** at the deploy, the seat deal can send a stopped tank 47 m across its own squad to the far seat
  (terminus 5-squad click, squad 4, Delta_2). On main today.
- **Latch (`--halt-terrain=latch`, R37.40/R37.42):** removes shape flips and relays (143 -> 2), but its full check caught a wrong FIRST
  shape: crossing an `open` pocket at t=11 then arriving in a lane latched a coil (test_tactics_scenarios_2::test_a_move_ends_formed_up_
  on_the_spot_and_stops_issuing). Fix candidates: latch the read the deploy decides on (at all-in), or a read held ~2 s.
- **Parked hold (`--parked-hold=on`, R37.28):** passed its bar (off-seat 172.6 -> 20.0 s a fight) but doubles real parked re-deals (50 ->
  105); hypothesis: the halt is re-planned when a pulled-back crew returns, re-dealing crews that never moved. Untraced.

## Backlog (in order)

1. **S1 the deploy deal:** seats dealt nearest-first without crossing the squad; lab of the traced case; bar (deciding: a stopped crew's
   longest post-arrival drive; guards: all-in, contacts, the first shape, fights). Symmetric: a pass ships ON.
2. **S2 latch v2:** lab of the failing test's geometry FIRST (it must form herringbone), then the arm and a bar whose guards include the
   first shape (C38.1); fresh seeds.
3. **S3 O2's re-deals:** trace one (the returning crew hypothesis), fix, then O2 (+ latch v2 if it passed) on fresh seeds.
4. **Stretch:** a parked crew re-dealt after a loss (bursts after deaths).

## How to verify

Lab both paths; `make quick-remote`; one full check per named hash (this stream's last red came from the full check: run it before any
"ships ON"); probe series on fresh seeds. Smoke: `make skirmish ARENA=terminus`, park 5 squads and watch them settle.

## Don't touch

orders' group lay, doctrine's brains paths beyond the parked-hold seam, manoeuvre's movement blocks, `native/**`, `tests/baselines/**`.
Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
