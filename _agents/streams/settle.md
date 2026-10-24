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

### Report (2026-10-24)
- **GREEN: 6ab14f1ac** (builder0, `make native check exited 0`, 3,145 passed / 0 failed, 27 targets ALL JUDGED, sim-baseline unmoved
  on every map, 3,419 s). Everything past main is OFF by default.
- **S1 route-clear v2: FAILED its bar; stays OFF** (`--seat-route-clear`; series on 6ab14f1ac's tree, builder0 light, J 4, seeds
  6001-6024, 576 squads an arm + 36 + 36 fights an arm; `>> remote: make native settle-s1c ... exited 0`, verdict FAIL). Deciding:
  never-in runs on the 5-squad cells 1 -> 3, three NEW (terminus 5 click s6003, terminus 5 route s6003, crossing 5 route s6009) and
  main's one (crossing 5 route s6006) got in. Guards otherwise pass: all-in 25.8 -> 24.7 s (140 runs in on both), twitch >= 15 m
  108 -> 103, friend contacts 11,944 -> 10,623, foreign 6,548 -> 5,436, fights flat (3-squad his kills 5.06 -> 4.83, losses 7.83 ->
  8.31; 5-squad 9.78 -> 10.08, 15.44 -> 15.44). Reported: deploy legs >= 25 m **64 -> 100**. No ship, no re-file on these seeds.
  What the three new never-ins share (the deploy traces, not yet traced in time): the halt ahead cleared 2-3 seats and each
  cleared seat sent its crew 13-20 m along or across the lane the blocked squad still had to drive (click s6003: Bravo_4
  (3.6, 75.1) -> (-0.6, 57.9), down Alpha's lane at x 4-7; route s6003: Delta_1 (3.2, 80.0) -> (19.1, 74.4) across the junction
  Echo needed). The clear judges where a seat STANDS, not the drive to it, and the 7 m corridor is judged from the centre line
  in lanes narrower than that. Next (a later round): judge the crew's leg to its cleared seat against the same corridor, and
  only clear when the leg is shorter than the one it replaces; trace the three runs in time first. References:
  `references/round39/settle/s1-route-clear-builder0/`.
- **Item 2 (`--deploy-fit=street` on top of 1): not run** — the brief's rule (no new bar if 1 fails). The lab's `fitclear` arm
  (table below, n 1) is the only read.
- **Item 3 traced (o2's crossing re-deals):** dev read on rules-ON main (builder0 light, 82c0a9db2 tree, crossing 3 click fights,
  dev seeds 3891-3902, n 12 an arm): parked re-deals held 22 -> o2 35. Traced s3895 Alpha (0 -> 4): every counted re-deal is ONE
  crew's seat moving 14-18 m off and back with anchor, shape, latched spacing and seat index unchanged. Probable cause:
  UnansweredFire's duck (a crew ON ITS POST under fire it can't return goes to cover <= 25 m; PARKED_HOLD keeps more crews on posts),
  which orders' probe counts as a parked re-deal. **Confirmed by the control** (doctrine's `--duck=off`, 47ce8d229 applied
  uncommitted to cd7a272d0; builder0 light, same workload, n 12 an arm): parked re-deals held 22 -> 9, o2 35 -> 7 with ducks off,
  so o2's surplus is all ducks (`references/round39/settle/duck-control-builder0/`). **No Bar H re-file:** its re-deal line counts duck moves (R38.42's rule: the trace changes it). References:
  `references/round39/settle/o2-redeal-trace-builder0/`.
- **Bar H v2 DEPLOY_HOLD: PASS -> ON** (series on cd7a272d0 = dbc022357's code, builder0 light J 4, seeds 6025-6048, 72 fights
  an arm; `>> remote: make native settle-h2 ... exited 0`): REDEAL_TRACE re-lays after a loss 288 -> 0 (367 crews moved -> 0),
  other causes 0 -> 0; his kills 5.39 -> 5.31, his losses 6.99 -> 6.64, CPU losses 5.44 -> 5.33 a fight (all within 1.645 se, 0
  runs unstarted). Reported: parked_redeals 172 -> 100, reseats 244 -> 1. Shipped ON at 2478e2eef (main f1fb16131 merged in;
  `--deploy-hold=off` = round 38's re-lay). References `references/round39/settle/h2-deploy-hold-builder0/`. **Full check of the
  ship hash: see the green line above.**
- **Stretch (re-deals after a loss), dev read** (builder0 light, 15ec5b830, fight probe locks/crossing/terminus x 3-squad click x
  dev seeds 3891-3902, n 36 fights an arm; REDEAL_TRACE = the halt's OWN seat moves > 6 m, before ducks): main 144 re-lays after a
  loss (185 crews moved), 0 from any other cause; `--deploy-hold=on` 0. Fights: his kills 4.86 -> 5.42, his losses 7.92 -> 7.36, CPU
  losses 4.97 -> 5.56 a fight. Bar H v2 (deciding on REDEAL_TRACE): seeds 6025-6048 granted; bar filed below before any number (recorded on main 76f42a9c3).
  Target `settle-h2` + judge `h2` at dbc022357. The judge's dry run on the dev read (not judged) reproduces it: re-lays 144 -> 0, but the
  two-sided fight guard FAILS on held fighting BETTER (his kills 4.86 -> 5.42, se 0.29). A risk for the series, as filed.
  A start at ~09:34 was stopped before any number (main's merge check); **series running** after the all-clear (main 76f42a9c3
  green), tree cd7a272d0 (= dbc022357's code), builder0 light J 4, log `build/h2-remote.log`.
- **Orders' request done:** `ElementPlan.deploy_preview` (4066132c4, quick-remote builder0 132/0), pure; orders told.

### S1 route-clear lab (builder0 light, n 1 per run, orders' probe; `make settle-lab`)
| case | main | clear | fit (street) | fit + clear |
|---|---|---|---|---|
| crossing 5 route s3958 (the bridge mouth) | squad 4 NEVER | all in 47.5 s | squad 4 NEVER | all in 47.5 s |
| crossing 5 route s3806 | all in 41.7 s | all in 44.5 s | all in 41.8 s | all in 44.5 s |
| terminus 5 route s4505 | all in 42.2 s | all in 42.2 s | Echo NEVER | all in 42.3 s |
- v1 (886c38c17) lost s4505's squads 1 and 5. Traced (4066132c4, `--deploy-trace`, which now prints the `clear_of` ground):
  (a) the corridor started at Alpha's centre, so a seat cleared 6 m behind it stood on its rear crews' lane; (b) Bravo_1's seat
  grounded onto Alpha's lane from both directions tried and stayed. v2 (daea2cefe) starts the corridor from every crew, searches
  the whole ring (16 ways) nearest first, and keeps each crew's answer in the deploy. The table above is v2.
- Cost seen: s4505 squad 1 is in at 30.6 s v 24.9; s3806 all-in +2.8 s. The guards below judge it.

### Bar S1 route-clear (filed 2026-10-23 before any number on its seeds; code = daea2cefe's)
What he'd see: on a 5-squad click or route, a squad that stops first never parks a tank on the street or bridge mouth the next
squad still has to drive, and every squad gets in. Arms: `main:--deploy-trace` v `clear:--seat-route-clear,--deploy-trace`.
Base: main as launched (8952c3d64: latch ON, R1-R3 ON). **Manoeuvre's `--giveway-chain`: OFF in both arms** (main's state; C39.2).
**Seeds 6001-6024 (registered):** no-fight probe 12 cells x 6001-6012 (576 squads an arm), fights 3-squad (budget 1500) and 5-squad
(budget 3000) click cells x 6013-6024. `tools/remote.sh --light native settle-s1c TANK_SQUAD_SLOT_TIMEOUT=14400`, builder0 light, J 4,
after a full check of the named hash. Judge `settle_judge.py s1c` (dry-run on round 38's S1 v5 rows reproduces R38.40's read).
- Counter: seats cleared > 0.
- **Deciding:** never-in runs on the 5-squad cells (route and click) clear <= main - 1, with main >= 2, and NO run never-in on
  clear that main gets in. (Main < 2 = not decidable: no ship.)
- Guards (judged): never-in over every cell not up; all-in time, the mean over runs in on both arms, <= main x 1.10 + 1 s; twitch
  >= 15 m squads not up; first shape differs <= 3 %; shape flips (the latch) <= main + 3; friend contacts and foreign <= 110 % + 5;
  the fights (both reads, his kills / his losses / CPU losses within 1.645 se, 0 runs that never started).
- Reported: place+twitch and deploy legs >= 25 m.
- A pass ships `--seat-route-clear` ON on a new hash with one full check (CP39.1 with manoeuvre's M1).

### Bar H v2 DEPLOY_HOLD (filed 2026-10-24 before any number on its seeds; code = 6ab14f1ac's)
What he'd see: when a parked tank is killed, the rest of the squad stays where it is (no survivor sent 6 m+ to a new seat).
Arms: `main:--deploy-trace,--probe-fight=on,--probe-budget=1500` v `held:` the same + `--deploy-hold=on`. Base: main as on 6ab14f1ac
(latch ON, R1-R3 ON). **Seeds 6025-6048 (granted by the orchestrator, registered):** fight probe, locks / crossing / terminus x 3
squads x click (72 fights an arm). `tools/remote.sh --light native settle-h2 TANK_SQUAD_SLOT_TIMEOUT=14400`, builder0 light, J 4.
Judge `settle_judge.py h2` (dry run on the stretch dev read's folder only, seeds 3891-3902). Re-deals are REDEAL_TRACE lines (a
deployed halt's own surviving seat moving > 6 m, before any duck), not the probe's `parked_redeals` (which counts ducks, item 3).
- Counter: main's REDEAL_TRACE re-lays after a loss >= 20.
- **Deciding:** held's REDEAL_TRACE re-lays (any cause) <= 20 % of main's.
- Guards: held's re-lays from any other cause <= main's + 3; his kills, his losses, the CPU's losses a fight within main +/- 1.645 se;
  0 runs that never started.
- Reported: the probe's `parked_redeals` and `reseats` per arm (duck-contaminated).
- A pass ships `--deploy-hold` ON on a new hash with one full check.

### Plan (ordered)
1. S1 route-clear: pure lab (`tests/test_settle_route_clear.gd`) -> the traced cases (`make settle-lab`, builder0 light) -> bar
   filed here before numbers -> full check on the named hash -> series on 6001-6024 (builder0 light, J <= 4).
2. S1 on top: `--deploy-fit=street` re-read on 1's arm (the lab's `fitclear` arm first; no new bar if 1 fails).
3. Trace o2's crossing re-deals (R38.42) before any Bar H re-file.
4. Stretch: a parked crew re-dealt after a loss.

### Decisions (S1 route-clear)
- **Who counts as "following":** every other element of the same team with a move still to drive (its transit route from where
  its crews stand, else a navmesh path to its spot, then each queued leg's path). A superset of "same order": `task_frame` can't
  name one order across queued legs (each leg is assigned on its own frame), and a squad of a later order that must pass is
  blocked just the same. Squads with nothing left to drive and arrived count as parked halts (their seats).
- **Widths:** a seat (judged GROUNDED, via the situation's `ground_seat`, so main's relaid seats count) is blocked within 7 m of a
  remaining route's centre line (the group lay's travel clearance, SelectionSquads.PACK_TRAVEL_CLEAR_M) or within 9 m of a
  parked seat (its halt clearance, HALT_CLEAR_M).
- **Where a blocked seat goes:** the nearest clear candidate in 2 m steps out to 24 m, at each distance first straight out of
  what blocks it, then back along the squad's own arrival leg; dry, on its own bank, >= 0.75 spacing from its squad's other
  seats. None found: it stays (counted, `route_seats_unclear`).
- **When:** the ground is read ONCE, on the deploy's own update, and kept in the deploy (`clear_of`); every later update of that
  halt (a re-lay after a loss) clears against the same ground, so a parked squad never shuffles because another squad drives by.
- **Manoeuvre's switch state (C39.2):** the lab and bar run with manoeuvre's chain-aware give-way in main's state (OFF; not on
  main at launch).


### Merge notes
- `ElementPlan.deploy_preview` + `_unit_of` are byte-identical on stream/orders (da9591207, copied by orders): resolve to one copy.
- `ElementSituation.build` adds a `passers` Callable (DeployPassers.of), read only by a `--seat-route-clear` deploy. Nothing iterates
  the situation's keys (as with round 38's `ground_seat`).
- Everything here is OFF by default (`--seat-route-clear`); the sim baseline does not guard settle's paths (round 38's note).

### Requests to other streams
- doctrine: `--duck=off` restored (47ce8d229); item 3's control done with it (dev, uncommitted here).
- orders (note): `parked_redeals` counts UnansweredFire duck moves; Bar H / S3 need them excluded before any re-file.
