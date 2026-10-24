# Stream: settle (a squad that stops never parks on the street the squad behind it still has to drive)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 39** (C39.1, C39.2,
> C39.3) and in *Rulings (round 38)*: R38.26, R38.33, R38.34, R38.36, R38.37, R38.40, R38.42, R38.43. Your round-38 brief and its traces:
> `streams/archive/round38/settle.md` (Status, *S1: BLOCKED*). **You own:** in `game/tactics/element_plan.gd` the deploy-step,
> halt-lay and seat-deal functions; `game/tactics/element_situation.gd`; `game/tactics/deploy_passers.gd`; the PARKED_HOLD seam in
> `tank_brain.gd`; `tests/settle/**`, `tests/test_settle*.gd`, `mk/settle.mk`; you may run orders' probe (`make native orders-probe`)
> and judge (`orders_judge.py`). **Model:** Fable (the lingering problem: five S1 versions failed on it). **Machine:** builder0 light
> lane (J<=4). **Seeds:** 6001-6024 (registered); round 38's dev blocks for dev reads only.

## The lead's direction

His standing bar: "the feel of the game needs to have the user perceive that the units are smart and under their control". Parked
squads: "Stay put and shoot". What he'd see today: on a 5-squad click or route, a squad that arrives first parks a tank in the street
or at the bridge mouth, and the squad behind it never gets in.

## Where things stand (main at launch: see HANDOFF)

- **ON since round 38:** S2 v4, the deploy latch read at the anchor (`--deploy-latch=anchor` is the default): a stopped squad keeps its
  shape and seats (shape flips 51 -> 0; R38.33).
- **S1 v1-v5 FAILED (R38.17, R38.36, R38.37, R38.40)**, each by one marginal never-in, three of them a following squad that couldn't pass
  a squad deploying ahead of it on terminus 5 route. `DEPLOY_FIT` / `DEPLOY_FIT_STREET` stay OFF in the code (`--deploy-fit=on|street`).
- **The cause, traced (s4505; R38.40, R38.43):** a seat of a deploying squad lands on the route that a following squad of the same order
  still has to drive. Not only "across a lane": s4505's blocking seats are ALONG the street, at the junction and lane mouth, and one of
  them (Delta_3 at (3.7, 67.8)) is main's own relaid seat. The bridge mouth (orders' s3958, s3806, s3809) is the same thing: a squad's
  seat inside another squad's parked halt at the pinch, and it never moves again.
- **Bar H / S3 FAILED (R38.42):** the parked hold cut re-deals 36 % but o2 adds re-deals on crossing and locks, untraced.

## Backlog (in order)

1. **S1 route-clear halt seats (`--seat-route-clear`, new switch).** No seat of a deploying squad may land within the route corridor
   that any following squad of the same order still has to drive (its remaining legs from where it is, at the clear width the group
   lay uses), and no seat may land inside another squad's parked halt. Covers main's own relaid seats, every shape, every angle. Where
   no clear seat exists in the shape, step the seat back along the squad's own arrival leg. Lab FIRST on the traced cases (s4505 squad
   4, orders' s3958 squad 4, s3806 squad 5): each must get every squad in. Then the bar (deciding: never-in on his 5-squad routes and
   clicks; guards: all-in time, twitch, first shape, contacts, foreign, the fights, and the latch's shape flips must stay ~0), fresh
   seeds 6001-6024, builder0 light. Name manoeuvre's give-way switch state in the bar (C39.2).
2. **S1 on top (re-read):** once 1 is judged, re-read `--deploy-fit=street` on top of it (no new bar if 1 fails).
3. **Trace o2's crossing re-deals (R38.42) BEFORE any Bar H re-file.** Re-file only on new seeds and only if the trace doesn't change it.
4. **Stretch:** a parked crew re-dealt after a loss (bursts after deaths).

## How to verify

Lab both paths; `make quick-remote`; one full check per named hash before any judged series; probe series on fresh seeds,
`settle_judge.py`. Smoke like a player: `make skirmish ARENA=terminus SKIRMISH_FLAGS="--seat-route-clear"` (once native's C39.6 lands;
until then call Godot directly as doctrine's round-38 brief shows), send 5 squads down one route, watch the last one get in.

## Don't touch

orders' group lay (`game/control/**`), manoeuvre's movement and traffic blocks, doctrine's brains beyond the parked-hold seam,
`native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
