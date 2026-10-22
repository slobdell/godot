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

### Report (2026-10-22, in progress)

**S1 the deploy deal: built OFF (`--deploy-fit=on`), lab green, bar filed (below); judged series next.**
- **Trace (laptop GDScript e5c436f46, `make settle-trace` / `--deploy-trace`, terminus 5 click s3767, n 1; same seats as
  builder0's c14ec0d80 trace):** the defect is not the deal's cost alone. (1) The deploy lays its halt (a 5-crew herringbone,
  47 m deep at spacing 10) on the click's heading (0.05, -1.0), i.e. ACROSS the east-west street the squad stopped strung
  along, so its end seats stand in the blocks; Element.ground then moves Delta_2's seat from (28.1, 61.1) to (3.3, 63.2), 25 m
  into the next street. (2) The deploy's `_group` runs `fixed` and the early halt-shape seats are the same shape and size, so
  each crew KEEPS ITS SEAT INDEX from the early halt (laid on another heading and anchor) whatever it costs: Delta_2, at the
  east end, keeps the index that is now the far west end. Greedy nearest-first would deal the same seat (the seat is far
  from everyone), so the fix is where the halt is laid and what the deal pays.
- **The change (ac36add58, OFF):** at the deploy (ElementPlan._deploy_fit), the halt is tried on the ordered heading and on
  the squad's own axis (its crews' principal axis when they stand strung along one: spread ratio >= 1.5), each laid as the
  deploy lays it (stepped dry), each dealt by the least total of the drives the crews will make to their GROUNDED seats
  (ElementSituation hands the plan `ground_seat`, Element.ground's grounding); the ordered heading stands unless the axis
  shortens the longest drive by 8 m. The deal seats the deploy's update (in place of the early halt's indices); fixed after.
  Symmetric (CPU deploys too). GDScript only (element_plan has no native twin).
- **Laptop dev read (GDScript, ac36add58 tree, terminus 5 click s3767, n 1; not a judged number):** squad 4 (Delta)
  place + twitch 27.2 + 24.0 = 51.2 m -> 8.8 + 0 m (deploy leg 47.9 -> 12.5 m; ordered lay's grounded worst 34.0 -> 12.6 m
  turned onto the street); squad 1 20.4 -> 8.6 m (turned); squads 2, 3, 5 identical (not turned).
- Lab: `tests/test_settle_deploy_fit.gd` 5/0 (laptop): the traced crews have an east-west axis; across the street the
  nominal deal's worst drive 31.7 m; the fit turns the halt along the street, worst 13.3 m; a squad that fits keeps its
  heading; the deal pays the grounded drive.

### Plan (ordered; smallest foundation first)
1. S1: bar (filed below) -> quick-remote -> one builder0 full check on the named hash -> `make native settle-series` -> verdict;
   a pass flips DEPLOY_FIT ON (symmetric, his and the CPU's) on a new hash with its own full check.
2. S2 latch v2: lab of test_tactics_scenarios_2's geometry first (must form herringbone); arm = the deploy latches the
   terrain its shape was decided on (at all-in) inside the deploy state (element_plan, mine: no element.gd edit); bar with the
   first-shape guard (C38.1); fresh seeds.
3. S3 O2's re-deals: trace one (crossing 3 click, `--parked-hold=on`), fix, O2 (+ latch v2 if passed) on fresh seeds.
4. Stretch: re-deals after a loss.
Decisions: the axis candidate (not a search over many headings): the squad already stands along the ground it fits on, and
two candidates keep the deploy cheap and its choice explainable; 8 m gain so a squad that fits keeps the heading he gave.

### Bar S1 DEPLOY_FIT (filed 2026-10-22 before any judged number; code ac36add58 + the series tooling)
What he would see: when a squad stops, every tank settles into a spot near where it stopped; no tank drives across or out of
its own squad to reach a seat. **Arms:** `main:--deploy-trace` v `fit:--deploy-fit=on,--deploy-trace`, one tree, builder0
native, on a hash whose builder0 full check is green; `make native settle-series` (mk/settle.mk), judge
`tests/settle/settle_judge.py s1`. **Workloads, FRESH seeds:** the no-fight probe, 12 cells (locks/crossing/terminus x 3/5
squads x click/route) x 3861-3872; the fight probe (`--probe-fight=on --probe-budget=1500`, the 3 maps x 3/5 squads x click)
x 3873-3878 (36 fights an arm); the CPU census (traffic-census' 3 default cases) x 3861-3863. **Counter:** deploys turned > 0
on the arm (DEPLOY_TRACE) and rows differ. **Deciding (a stopped crew's longest post-arrival drive):** per squad place_m +
twitch_m (the most any crew moved after the deploy began); squads with >= 25 m, summed over the no-fight probe: arm <= 50 %
of base, base >= 10 (else "no workload"), and the summed place + twitch lower. **Guards:** per cell (orders' probe_guards,
settle mode): all-in median <= base x 1.2 + 3 s, never-in no more, place + twitch median <= base + 3 m, end foreign min >=
base - 3 m, crossed no higher; **the first shape:** squads whose halt shape differs from base's <= 2 % (the shape choice is
not touched); friend_contacts and friend_contacts_foreign summed <= base x 1.1 + 5; fights: his kills, his losses, the CPU's
losses a fight each within base +/- 1.645 se (base sd, n 36); CPU: friendly contacts <= base x 1.1 + 5, stuck s <= base x
1.2 + 10. **Reported:** relays, shape flips, parked re-deals, redealt; the fight probe's >= 25 m squads. **A pass ships ON**
(symmetric); `--deploy-fit=off` keeps today's. sim-baseline maps that move are attributed with the switch OFF.

### Questions for the lead
None.

### Requests to other streams
None yet. Merge note (C38.3): `ElementSituation.build` adds a `ground_seat` Callable to every element situation (orders and
doctrine read situations; nothing iterates its keys).
