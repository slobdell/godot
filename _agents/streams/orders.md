# Stream: orders (his group click and route put every squad in, the far squad first, on his route at corners)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 39** (C39.1, C39.3) and
> in *Rulings (round 38)*: R38.12, R38.39, R38.44, R38.45, R38.47, R38.49, R38.51. Your round-38 brief and traces:
> `streams/archive/round38/orders.md` (Status *NOW*: the causes, traced). **You own:** `game/control/**` (group lay, untangle,
> `selection_squads.gd`, `rts_controls.gd`), `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`.
> NOT the deploy/halt functions (settle's). **Model:** Opus. **Machine:** builder0 light lane (J<=4). **Seeds:** 6201-6224.

## The lead's direction

On Terminus, round 37: "I immediately lost control of the army". His bar: "the feel of the game needs to have the user perceive that
the units are smart and under their control". A group click lands his squads down the street he clicked, nearest in front, each whole.

## Where things stand (all OFF on main)

- **G1 v4 FAILED (R38.51)** on one guard (crossing 3 click never-in 0 v 1, s4710 squad 2): the column gives the near place to squad 1,
  which arrives first and parks in the street; squad 2 wedges behind it. Every other line passed (outside the corridor 82 -> 20,
  route_left 4974 -> 1328).
- **G3 v5 FAILED (R38.51)** on one guard (twitch 5.5 v 8.8 on crossing 3 route): the moved place clears the neighbour but doesn't hold
  the squad's seats, so the deploy re-seats ~24 s in. Pairs closer than 12 m 48 -> 3.
- **G2 carries (R38.47):** on his 5-squad east/west routes main never gets every squad in and G2 does (0/0 over 3 seeds); the cost is
  rear squads standing off the route at the first corner (route-off ~2x).
- **The rest of the never-ins are the bridge mouth** (s3958, s3806, s3809): settle's and manoeuvre's item this round (C39.2).

## Backlog (in order)

1. **G1 v5: who takes the far place.** The squad whose crews lead takes the far place, or the near squad holds until the far one is
   past. Lab s4710 first; dev reads on round-38 dev seeds; judged series only on top of CP39.1 (C39.3), fresh seeds 6201-6224.
2. **G2 v2: rear places on the route line at corners.** Lab the x=70 corner; dev read 3's cells; bar when it holds.
3. **G3 v6: accept a cleared place only where every crew seats without a re-seat** (the ground-cap check), else step it back along
   the squad's own leg. Lab s5201.
4. **Judge G1 v5 / G2 v2 / G3 v6 on top of CP39.1** when the orchestrator says it landed, one series at a time.
5. **Stretch:** the G1 v4 plain-click v route-leg trade-off (R38.44) if G1 v5 needs it.

## How to verify

Lab both paths; `make quick-remote`; one full check per named hash; `make native orders-probe` + `orders_judge.py` on builder0 light.
Control timing is judged on a quiet builder0 only. Smoke: `make skirmish ARENA=terminus SKIRMISH_FLAGS="..."`, select 5 squads, click
down a street, and give a 2-waypoint route round a corner.

## Don't touch

settle's deploy/halt functions, manoeuvre's movement/traffic, doctrine's brains, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### NOW (2026-10-23 ~21:35 PDT)
- **Plan (backlog order):** G1 v5 lab -> dev read -> G2 v2 lab -> dev read -> G3 v6 lab (needs a deploy trace of s5201) -> dev
  read -> full check on a named hash -> wait for CP39.1 (C39.3) -> judged series one at a time.
- **G1 v5 built** (`--group-lead=drive`, OFF; ef68308d1). A column's places go to its squads in the order their crews reach the
  click by ground: under the switch every squad of a column is one knot in `untangle_whole`, and the first key is
  `lead_breaks` (a squad placed behind one it leads by > 6 m), then crossings, then drive. Decided: lead = mean of the
  squad's crews' navmesh drives (the bulk of the squad, not one forward scout).
  - Lab `test_control_group_click` (laptop GDScript): pins today's straight-line swap (Bravo to the head) and the fix.
  - **s4710 lab** (builder0 light J3, ef68308d1 + G2 v2 work OFF, crossing 3 click, n 1; `references/round39/orders/g1v5-lab-s4710-builder0-ef68308d1/`):
    v4 Bravo never in, contacts 3,756 -> v5 all in 9.7 s, twitch 0, contacts 71 (main 875, all in 17.3 s).
  - Dev read 1 running (builder0 light J4, 93a6c2283, dev seeds 3804-3809, 12 street cells, main / v4 / v5).
- **G2 v2 built** (`--group-route-corner=line`, OFF; 93a6c2283). On a leg, the column's room is read along the road (capped
  at its length) instead of the straight line on past the click, and ranks past the road's first corner (> 30 deg) stand single
  file on it. Lab on the Terminus navmesh (his east route's last leg): v1 rear rank two abreast 32 m either side of the x=70
  street (the column ran out of room and merged); v2 every place on the route line.
- **G3 v6 pure step built** (`--place-clear-seat=on`, uncommitted -> next commit): a moved place must pass the caller's seat
  check, else it steps back along the squad's own leg, else it is kept. The check itself waits on a `--deploy-trace` of
  s5201 (what re-seats: the dry-halt anchor step, the deploy fit's turn, or the travel -> halt shape change).

