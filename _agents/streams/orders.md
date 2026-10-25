# Stream: orders (his group click and route put every squad in, the far one first, without stepping into a friend's road)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 40** (C40.1, C40.3, CP40.1)
> and *Rulings (round 39)*. Your round-39 brief: `streams/archive/round39/orders.md` (Status: *CLOSE* and its round-40 input), traces in
> `references/round39/orders/bar-traces-builder0-e7c896c8f/README.md`. **You own:** `game/control/**` (group lay, untangle,
> `selection_squads.gd`, `rts_controls.gd`), `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`. NOT
> the deploy/halt functions (settle's). **Model:** Opus. **Machines:** builder0 light (J4) and builder2 (`make gcp-start`, Spot; your
> `tests/control/orders_bar.sh` re-runs a preempted part). **Seeds:** 8201-8236 (registered, C40.1).

## The lead's direction

His standing bar: "the feel of the game needs to have the user perceive that the units are smart and under their control". His lead
item for two rounds: a group click puts every squad in, the far place to the squad that gets there first, and on a shift-click route the
rear places stay on his route at corners.

## Where things stand (main at launch: see HANDOFF)

All three of round 39's switches are OFF: `--group-lead=drive` (G1 v5), `--group-route-corner=line` (G2 v2c), `--place-clear-seat=on` (G3 v6).
- **G1 v5 FAILED** (places outside 100 -> 28 v bar 25). Two causes: (a) terminus his-5 twitch 28.4 m on all 12 seeds = settle's deploy
  trigger (Bravo_2 holds 3.83 m v the 3.5 m all-in radius, waits the 10 s cap). Settle fixes it as T1 (**CP40.1**). (b) locks 5 places
  outside 8 -> 8: the column is not laid on s6204-6207 (rows identical to main), untraced; with those the line is 28 v 25.
- **G3 v6 FAILED** its guards on crossing 5 route (deciding passed 48 -> 12): v6's step-back parks a place on the approach of the squads
  still to come (s6213; s6220's twitch probably the same).
- **G2 v2c** dev-read only; its guard fails (end foreign, twitch) were the kind CP39.1 (DEPLOY_HOLD) was meant to fix.

## Backlog (in order)

1. **O1 trace locks 5 (s6204-6207): why the column doesn't lay.** Dev, no bar. Fix in G1 if it is orders' cause; file it if not.
2. **O2 G3 v7: no step-back inside a still-to-arrive squad's corridor;** otherwise keep the given place. Trace s6220 first to confirm it
   is the same cause. Lab s6213/s6220, then Bar G3 v7 on 8213-8224.
3. **O3 G1 v6 on CP40.1** (settle's T1 ON both arms) + O1's fix: Bar G1 v6 on 8201-8212. Before CP40.1 lands, dev reads with
   `--deploy-arrive=near` passed in both arms are fine; the judged series waits (C40.3).
4. **O4 G2 v2c re-read on main (DEPLOY_HOLD ON)** on dev seeds 3801-3803, then Bar G2 on 8225-8236 if the re-read holds.
5. **Stretch:** a pass of any bar ships ON with one full check; tell the orchestrator the hash.

## How to verify

`make quick-remote`; one full check per named hash; bars with `tests/control/orders_bar.sh <b0|b2> ...` and `orders_judge.py`. Smoke:
`make skirmish ARENA=terminus SKIRMISH_FLAGS="--group-lead=drive --deploy-arrive=near"`, box five squads, click once; shift-click a
corner route on crossing.

## Don't touch

settle's deploy/halt functions (`element_plan.gd`'s deploy-step, halt-lay, seat-deal; `deploy_preview` is settle's, you read it),
manoeuvre's movement/traffic, balance's brains, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
