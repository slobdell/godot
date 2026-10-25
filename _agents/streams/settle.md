# Stream: settle (a squad that stops counts its crews in, and never parks on a road a friend still drives)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 40** (C40.1, C40.2,
> CP40.1) and *Rulings (round 39)*. Your round-39 brief and its traces: `streams/archive/round39/settle.md` (Status: *Round-40 input:
> why route-clear lost three squads* and *What round 40 should try*), evidence under `references/round39/settle/`. **You own:** in
> `game/tactics/element_plan.gd` the deploy-step, halt-lay and seat-deal functions (DEPLOY_CAP_S and the all-in test included);
> `game/tactics/element_situation.gd`; `game/tactics/deploy_passers.gd`; the PARKED_HOLD seam in `tank_brain.gd`; `tests/settle/**`,
> `tests/test_settle*.gd`, `mk/settle.mk`; you may run orders' probe (`make native orders-probe`) and judge (`orders_judge.py`).
> **Model:** Fable (the lingering problem: S1 failed in six versions over two rounds). **Machine:** builder0 light lane (J<=4).
> **Seeds:** 8001-8024 (registered, C40.1); round 38/39 dev blocks for dev reads only.

## The lead's direction

His standing bar: "the feel of the game needs to have the user perceive that the units are smart and under their control". Parked
squads: "Stay put and shoot". What he'd see today: (1) on his 5-squad click at terminus, one squad sits for ten seconds and then
reshuffles its tanks (the twitch), because one tank stopped 3.8 m from its spot and the squad waits for it; (2) on a 5-squad click or
route, a squad that stops first can still park a tank where the last squad has to drive, and that squad never gets in.

## Where things stand (main at launch: see HANDOFF)

- **ON since round 39:** DEPLOY_HOLD (a squad that loses a tank keeps its seats; `--deploy-hold=off` is round 38's re-lay). Latch at the
  anchor (round 38). Fog, rules R1-R3 ON.
- **The deploy trigger (orders' trace, `references/round39/orders/bar-traces-builder0-e7c896c8f/README.md`):** a deploy waits until every
  living crew is within max(TankBrain.ORDER_ARRIVE 3.5 m, its settle radius) of its travel seat, or DEPLOY_CAP_S (10 s) after arrival.
  On terminus his-5 click, Bravo_2 holds 3.83 m off its seat on all 12 seeds; the halt waits out the cap and re-deals: a 28.4 m twitch.
  G1 v5's whole guard failure is this.
- **S1 route-clear v2 FAILED (never-in 1 -> 3)**, stays OFF (`--seat-route-clear`). Traced in time (your archived Status): **cause A**,
  the corridor is one centre line from the squad's centre, but crews drive their own paths (terminus click s6003, route s6003); **cause
  B**, a cleared seat's own leg crosses a live route head-on while the passer drives it (crossing route s6009). Main got in on all three.

## Backlog (in order)

1. **T1 the deploy trigger (`--deploy-arrive=near`, new switch; small, FIRST).** A crew that is HOLDING (speed ~0, not driving to its
   seat, a few ticks running) within ~5 m of its travel seat counts as in. Pure test first (the 3.83 m Bravo_2 case and a crew still
   rolling at 4 m must not count). Lab: terminus his-5 click s6201-6212 (the 12 deterministic runs), twitch 28.4 -> ~0. Then a bar on
   8001-8012 (deciding: his-5 click twitch; guards: never-in, all-in time, places outside, first shape, contacts, the fights). A pass
   ships ON with one full check = **CP40.1**; tell the orchestrator the minute it's green (orders re-reads G1 on it).
2. **S1 v3 per-crew corridors (`--seat-route-clear`, v3).** (a) the corridor from each passing CREW's own path to its own slot and its
   queued legs' slots, not one centre line; (b) move a seat only if the crew's leg to it is short (<= ~one spacing) or crosses no live
   corridor, else keep main's seat; (c) failing both, a seat on a live corridor waits where the crew stands until the passer is past.
   Lab FIRST on the three traced never-ins (terminus click s6003, terminus route s6003, crossing route s6009) plus s4505/s3958/s3806:
   every squad in on every one. Then a bar on 8013-8024 (deciding as round 39's: never-in on 5-squad cells clear <= main - 1, main >= 2,
   no run never-in that main gets in; report deploy legs >= 25 m, which v2 raised 64 -> 100). Name manoeuvre's switch state (C40.2).
3. **Stretch:** if T1 ships and S1 v3 fails, file what the trace says next (no re-run on the same seeds).

## How to verify

Pure tests; `make settle-lab` / `make quick-remote`; one full check of every hash you name before a judged series; probe series on
your fresh seeds with `settle_judge.py`. Smoke like a player: `make skirmish ARENA=terminus SKIRMISH_FLAGS="--deploy-arrive=near"`,
box five squads, click once, watch no squad reshuffle; then five squads down one route with `--seat-route-clear`.

## Don't touch

orders' group lay (`game/control/**`), manoeuvre's movement and traffic blocks, balance's brains beyond the parked-hold seam, `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
