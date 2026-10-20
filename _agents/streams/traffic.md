# Stream: traffic (a crew being shot while it waits its turn in a street mouth drives on)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 36** (C36.1,
> CP36.1, C36.2) and in *Round 35*: the T8 bar in *Bars (round 35)*, R35.69 (the seed swap), R35.78 (X1b: why T8). Then your round-35
> brief `streams/archive/round35/traffic.md`: its Status is the close-out and holds T8's whole plan (code, tooling, driver, reader).
> **You own:** the give-way block in `game/ai/movement.gd` (`_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`, `_negotiate`,
> ask, `_begin_yield`, `right_of_way`), `game/ai/traffic.gd`, `tests/traffic/**`, `tests/test_traffic*.gd`, `mk/traffic.mk`.
> **Model:** Opus. **Machine:** builder2 for T8's check and series (C36.1); light runs on either builder.

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking (memory: *smart AI on both sides*). For round 36 he chose "use the
agents' list" (2026-10-20): no new playtest words. His standing rule: a firing mortar truck keeps its spot.

What he will notice: a crew that is being shot while it waits its turn at a street mouth stops waiting and drives on, instead of
sitting there until it dies.

## Where things stand

- **Shipped in round 35:** T7 (a crew under fire doesn't step aside into a killing zone when the one behind can go round). **T9**
  (a give-way that ends with the asker not past is not recorded, so the next ask is honoured) ships inside the joint W1c + T9 at
  **CP36.1** (the orchestrator merges it; you are told when).
- **Why T8 is the answer (R35.78, X1b):** a held, still wheeled hull takes ~2x the hits per exposed second (builder0 native, Locks x
  4300–4323, n 24 paired: 0.117 -> 0.249/s); manoeuvre's alternative (W1b, the wheeled halt) is dropped. From W1: 33 of 81
  stuck:wedged deaths were HELD by the T1 street-mouth hold under fire, a median 5.4 s in.
- **T8 is coded and its bar is filed** (round 35 Status): `1a1bd58bf` (`--traffic-on=holdfire`, DEFAULT_OFF; `Traffic.hold_of`
  releases a held crew hit within `Movement.UNDER_FIRE_S`, counter `released_fire`), `tests/test_traffic_holdfire.gd` (+ .uid
  `41f637d8e`), jam_census's `held_deaths` / `held_3s`, `jam_ab.py --bar t8` (`06144d171`), `tests/traffic/t8_series.sh`. All on
  `round35/traffic`, none on main.

## Backlog (in order)

1. **Carry over (C36.1), after CP36.1 lands on main and the orchestrator tells you:** `git merge main`, then bring `round35/traffic`'s
   T8 code and tooling across. Read `git diff main...round35/traffic` first: T9's commits arrive through the joint, so take the rest
   (T8 OFF, the jam tooling, t8_series.sh, test_jam_ab, the judging.md measurement notes). `make quick-remote`.
2. **T8 judged (C36.2).** Cut `pair/holdfire-r36` from that commit + the ON flip (holdfire out of `DEFAULT_OFF`); base arm
   `--traffic-off=holdfire`. Driver `tests/traffic/t8_series.sh` on **builder2** under systemd-run: wait for builder2's checks → `make
   native check` (stop if red beyond sim-baseline) → switch-OFF `sim-variants --traffic-off=holdfire` → the series → `jam_ab --bar t8`.
   The bar is exactly as filed (fresh fixed arenas {terminus, locks, crossing, gorge, parade} x 1800–1827, locks 1801–1828, n 140).
   Counter first. Report every line with commit, machine, n. **A pass:** name the green hash of the hand-over (the ON flip on current
   main) and send it to the orchestrator; it ships ON. **A fail:** trace the worst fight first, write it up, no re-read on the same
   seeds.
3. **Perf-judge for T8 before the ship:** ask the orchestrator for a quiet slot (it is owed alone on a quiet builder).
4. **The seed_twins call in every series reader** that pools a folder that could hold random-arena fights (far_ab, far_kills,
   jam_ab, jam_table), if `round35/traffic` didn't already carry it (small commit, test).
5. **Stretch: the next held-crew loss.** With T8's series in hand, read `jam:held` and the held deaths that T8 did NOT release
   (hit before the hold, or held without being hit while its neighbour was): a design note to the orchestrator, no code before it.

## How to verify

Tests first; `make quick-remote`; one full check at a time a builder; the series pinned, fresh seeds, no random twins. Every number:
commit, machine, workload, n. Smoke: `make skirmish ARENA=terminus` on the T8 hand-over; a held crew that's hit should drive on.

## Don't touch

Manoeuvre's drive and unstick, orders' paths, brains' paths (no owner this round, C36.6), `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Switch-OFF inertness: `a2de32420`, builder2, `sim-variants --traffic-off=holdfire`: base40 = the ON check's sim-baseline on 13 of 13 maps (T8 is inert off, and moves no sim-baseline map on). Series started ~14:53.** **T8 PAIR GREEN for the series: `pair/holdfire-r36` `a2de32420`, builder2, `make native check` exited 0, 2963 passed 0 failed, 25 targets passed + 2 NOT JUDGED (perf-judge, scenario_perf: load), sim-baseline 13 of 13 unmoved with T8 ON. Driver resumed 14:44:45 as unit `t8-series-r36d` (the stream copy of t8_series.sh, `7da1ab88e`: its NOT RUN guard had misread the green line; run with cwd = the pair tree, so h stays `a2de32420`).** **Quick of the merged carry-over GREEN: `c9b2fab03`, builder0, `make quick-remote` QUICK_BASE=main, 83 passed 0 failed (16 traffic/native/manoeuvre test files + lint, 1279 s).** **2026-10-20 ~14:10 PDT (traffic). Builder2 was preempted at 14:07:35, 4 min into the first check (void); the driver read the exit 255 as done, so it was fixed (`ee30b2194`: verdict line only, 3 tries, NOT RUN stops, series loops to completion) and the pair re-cut as `pair/holdfire-r36` `a2de32420` (same game code), unit `t8-series-r36c`, check from 14:10:30.** Earlier, ~14:00: CP36.1 landed (main `a318a2cd3`, adoption `e45bb6632`); merged into stream/traffic
(`4a2a0d349`, DEFAULT_OFF `["holdfire"]`). **Pair cut: `pair/holdfire-r36` `46e6ba8a9`** = `4a2a0d349` + the ON flip, worktree
`../godot-traffic-t8` (remove it and builder2's `~/tank_squad/godot-traffic-t8` after the series). **Driver** `t8_series.sh` running
as systemd unit `t8-series-r36b` (needs `--setenv=PATH` for gcloud: the first unit died on `gcloud: command not found`), out
`~/overnight-traffic/r36/t8series/`; its check started 14:00:43 on builder2 (the only full check there). Light quick of
`4a2a0d349`'s carry-over on builder0 running (`~/overnight-traffic/r36/quick1.log`).

**2026-10-20 (traffic, Opus).** Oriented. **Waiting on CP36.1** (main still `582650b36` at my start; the joint not merged).
**Done meanwhile:** item 1's carry-over STAGED as `6a564673a` on current main (not checked yet): T8's traffic.gd hunk with
`DEFAULT_OFF := ["holdfire"]` (T9's yieldfit2 comes through the joint, so not in my list), test_traffic_holdfire (+uid), the jam
tooling (jam_census `held_deaths`/`holdfire_on`, jam_ab `--bar t8` + seed twins, jam_table, test_jam_ab: OK locally, python),
t8_series.sh (OUT now `~/overnight-traffic/r36/t8series`), t7_clip + `make traffic-t7-clip`, round-35 references, judging.md's
notes. round35/traffic's judging.md ended in a stray `||||||| c55471a5e` merge marker: left behind. movement.gd is identical to
the joint's. When CP36.1 lands: `git merge main` (one expected conflict, the DEFAULT_OFF line: keep `["holdfire"]`) ->
`make quick-remote`.
**Item 4 (seed twins), read:** jam_ab and jam_table carry `seed_twins.filter_logs` (in the carry-over); far_table already has it on
main; "far_ab"/"far_kills" don't exist as files (far_table is the far census reader). seq_hook reads runner rows of scenario cases,
never a random arena: not applicable. Nothing more to code; closed with the carry-over.

**Plan (ordered).** 1 carry-over (staged) -> merge main at CP36.1 + quick -> 2 cut `pair/holdfire-r36` + ON flip, t8_series.sh on
builder2 under systemd-run -> 3 ask for a quiet perf-judge slot -> 5 stretch: the held deaths T8 did not release (design note).

**2026-10-20 (orchestrator, at launch).** Not started. CP36.1 (the joint ship) was checking on builder0 at launch.
