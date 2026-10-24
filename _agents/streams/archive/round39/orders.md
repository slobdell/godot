> **ARCHIVED (round 39 closed 2026-10-24).** Final state of this brief; round 39's results are in `workstreams.md` *Bars (round 39)* and *Rulings (round 39)*.

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

## Requests to other streams

- **settle (G3 v6): DONE** (4066132c4, `ElementPlan.deploy_preview`). Merge note: orders carries a verbatim copy in
  `element_plan.gd` (da9591207); keep one copy.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### CLOSE (round 39, 2026-10-24): every backlog item done; round-40 input below
- **Green:** 632724c90 (builder2 full check, 3169/0, 24 passed + 3 NOT JUDGED), main 2518811d0 merged (CP39.1). HEAD's
  descendants since then are docs, evidence and test tooling only (`tests/control/orders_bar.sh`, judge text). All of
  orders' round-39 switches stay OFF: `--group-lead=drive`, `--group-route-corner=line`, `--place-clear-seat=on`.
- **Backlog:**
  1. G1 v5: built, judged, FAIL.
  2. G2 v2c: built, dev-read. No bar this round; its block 6225-6236 is unused, and round 40 gets fresh blocks.
  3. G3 v6: built, judged, FAIL.
  4. Judged on CP39.1: done, in parallel per R39.8.
  5. Stretch R38.44: not taken. G1 v5's failures are not the plain-click v route-leg trade-off.
- **Round-40 input (traced causes; `references/round39/orders/bar-traces-builder0-e7c896c8f/README.md`):**
  - **G1 his-5 twitch (28.4 m, all 12 seeds):** column gives Bravo the click, and Bravo_2 holds 3.83 m from its travel seat.
    The deploy's all-in radius is 3.5 m (ORDER_ARRIVE), so the halt waits for DEPLOY_CAP_S (10 s), then deals on parked
    crews. Fix: settle's trigger (count a holding crew within ~5 m as in). G1's ordering itself is fine.
  - **G1 locks 5 outside 8 -> 8:** the column is not laid on s6204-6207 (rows identical to main). Why is untraced. With
    those 8 the deciding line is 28 v 25; it would pass if the column engaged there.
  - **G3 crossing 5 route never-in (s6213):** v6's step back along the squad's own leg parks it on the approach of the
    squads still to come (Delta 28 m west, across Echo's road; Echo never in). Fix: no step back inside a later squad's
    corridor; otherwise keep the given place. The s6220 twitch (cap deploy, 2 legs stepped back) is probably the same, but
    not traced in detail.
  - **G2 v2c:** re-read on CP39.1 before a bar. Its dev read 3's guard fails (end foreign, twitch) are the kind CP39.1 was
    meant to fix.
  - **Tooling:** `orders_bar.sh` runs a bar on either builder and re-runs a preempted part (it caught one builder2
    preemption). `parked_redeals` is duck-excluded; `parked_ducks` is reported beside it.

### NOW (2026-10-24, before the bars)
- **GREEN: ebfe98d18** (builder0 full check `make native check`, load 6-12, 18 other godot): 3140 passed, 0 failed; scenarios
  53 passed, 0 failed, 3 pending; `>> remote: make native check exited 0`. All three switches OFF; main's behaviour unchanged.
- **Orchestrator (2026-10-24):** Bars G1 v5 / G3 v6 recorded on main as filed at ebfe98d18. ebfe98d18 merges after settle's
  6ab14f1ac; settle's `deploy_preview` is kept as the one copy. **G2 v2c's bar block: seeds 6225-6236.** CP39.1 is not here
  (settle's S1 failed its bar; it waits on manoeuvre's M1 or settle's next version). The G2 bar file waits on its re-read on
  CP39.1. R39.3: one laptop Godot run at a time,
  `flock /tmp/tank-squad-laptop-godot.lock <cmd>`; everything else on the builders.
- **REPORT (2026-10-24): Bars G1 v5 and G3 v6 both FAIL** (tree 632724c90 green, e7c896c8f descendant, CP39.1 with
  DEPLOY_HOLD ON both arms; n 12 a cell; evidence `references/round39/orders/g1v5-judged-e7c896c8f/` and
  `g3v6-judged-e7c896c8f/`). Both switches stay OFF.
  - **G1 v5** (builder0 light J4, 6201-6212):
    - FAIL deciding: places outside, click cells, 100 -> 28 (bar <= 25). Locks 5 stays 8 -> 8 and his 5 goes 36 -> 12.
    - FAIL guard: terminus_his 5 click twitch median 2.0 v 8.2. Squad 2 twitches 28.4 m on all 12 seeds (main 0.0): one
      deterministic layout of his click.
    - PASS: route_left 6490 -> 1832, re-dealt 0, contacts 14280 -> 11413, yard_open identical.
  - **G3 v6** (builder2 J14, 6213-6224; one Spot preemption, re-run whole by the driver):
    - PASS deciding: pairs < 12 m 48 -> 12 (bar <= 12.0).
    - FAIL guards, both on crossing 5 route: never-in 0 v 1 (s6213 squads 4 and 5) and twitch 18.9 v 22.9 (worst s6220 squad
      5, 42.5 v 0.1).
  - **Next (dev only; a new version needs a fresh bar block from the orchestrator):** trace his-click 5 squad 2's 28.4 m
    twitch, which is deterministic and cheap to trace, and locks 5's places outside for G1. Trace s6213 / s6220 on crossing 5
    route for G3: settle's cause (B), a cleared place's leg meeting a passer head-on, is the first suspect.
- **GREEN: 632724c90** (main 2518811d0 merged, CP39.1 with DEPLOY_HOLD ON; builder2 `make native check`, load 31-22, 46
  other godot): 3169 passed, 0 failed; 24 passed + 3 NOT JUDGED (perf-judge, scenario_perf, remote-guard-test: machine and
  load refusals); `>> remote: make native check exited 0`. **Bars G1 v5 (builder0 light J4) and G3 v6 (builder2 J14) started
  together on this tree** (results in `~/overnight-orders/bar-g1v5-<hash>` / `bar-g3v6-<hash>`, filed under references/ when
  read).
- **CP39.1 was further off (2026-10-24, earlier):** manoeuvre's Bar M1 FAILED on its never-in guard (2 -> 7; `--giveway-chain` stays OFF).
  Manoeuvre is tracing it. My bars still wait.
- **Dependency:** manoeuvre's `tests/manoeuvre/probe_wedge.gd` (stream/manoeuvre f3dfa1e64) extends `tests/orders_probe.gd` and
  reads `_match`, `_squads` and `_order_tick`. Don't rename those without telling manoeuvre.
- **On CP39.1 (orchestrator, approved):** merge main only after native's 0bb755a4f (full-check lock + relay-smoke race fix) is
  on it. Run the tree's full check on whichever builder's check lock frees first (`make gcp-remote T="native check"` on
  builder2 is fine), not in builder0's queue. The orchestrator announces both.
- **Settle's S1 trace (A / B) read against G3 / G2 (code read, no run):** G3's place_clear never tests against a passing
  squad's path. It clears place-to-place spacing (`_too_close`) and checks for decks on the moved place's own step, so (A),
  a corridor as one centre line, has no counterpart. (B), a cleared place's leg meeting a passer head-on, applies in kind: G3
  checks nothing for it. It is a candidate for the dry run's crossing 5 route twitch (untraced). G2 lays places on his drawn
  route, the same assumption as a plain route. No code change before the bars (G3 v6 is filed as built).
- **R39.8: the two bars run IN PARALLEL** when CP39.1 lands: G1 v5 on builder0 light J4, G3 v6 on builder2 (J ~14, Spot:
  re-queue on preemption). Driver: `tests/control/orders_bar.sh <b0|b2> <g1v4|g3> <arm> "<seeds>" <out dir outside build/>
  [jobs]`. It runs streets + his click, re-runs a part that is incomplete or preempted, splits terminus_his and yard_open, and
  judges. Native's builder2 row yields to the G3 series.
  - **Dry run** (builder2, J14, 2fedb9b65 = main 76f42a9c3 + orders, dev seed 3801, n 1, G3 v6's arm): 36 of 36 runs, native on;
    the judge reads 18 cells. Not a verdict (n 1, dev seed). Its one failing line is a known risk for Bar G3 v6: worst twitch on
    crossing 5 route 10.7 v 22.1 m (as G3 v5's crossing 3 route; DEPLOY_HOLD ON may move it). Results:
    `~/overnight-orders/dry-b2-2fedb9b65/` (outside the repo). **Settle's DEPLOY_HOLD (2478e2eef) ships ON before CP39.1**, so both
  arms of both bars carry it; name it in each bar's run line.
- **parked_redeals duck exclusion** (ea51cc7c5; settle's o2 trace: every o2 "re-deal" was one crew's UnansweredFire duck,
  14-18 m out and back, with the halt's seats unchanged): a parked crew's goal move out to its duck point, or back from a seat
  that was one, now counts in `parked_ducks`, not `parked_redeals`. The judge reports both. No bar of mine judges either
  (reported only).
- **Where the backlog stands:** items 1-3 built, labbed and dev-read (below); item 4 is **waiting on CP39.1** (C39.3: judged series
  only on top of it). Bars G1 v5 and G3 v6 are filed (below). G2 v2 re-reads on CP39.1 before its bar, on a fresh seed block
  from the orchestrator. Stretch (R38.44) not needed so far: G1 v5 holds its deciding lines without it.
- **Next for a fresh agent:** when the orchestrator announces CP39.1, merge main (keep ONE `ElementPlan.deploy_preview`: settle's),
  run a full check, name the green hash, then Bar G1 v5 (6201-6212) and, after it, Bar G3 v6 (6213-6224), each with
  `tools/remote.sh --light` direct (the arms contain spaces once commas expand; `make remote T=` word-splits them), J4,
  `TANK_SQUAD_SLOT_TIMEOUT=14400`. Then G2 v2c's re-read on dev seeds 3801-3803.
- **Smoke (lead / next agent):** `make skirmish ARENA=terminus SKIRMISH_FLAGS="--group-lay=column --group-rank-shift=half
  --group-whole=click --group-clear=reached --group-lead=drive"`, select all, click down a street; for G2 add
  `--group-route-corner=line` and give a 2-waypoint route round a corner; for G3 `--place-clear=on --place-clear-trigger=near
  --place-clear-reach=on --place-clear-seat=on`. Needs native's N2 SKIRMISH_FLAGS passthrough.
- **Plan (backlog order, history):** G1 v5 lab + dev read (done) -> G2 v2 lab + dev reads 1-3 (done) -> G3 v6 lab + dev read
  (done) -> full check (ebfe98d18 green) -> wait for CP39.1 (C39.3) -> judged series one at a time.
- **G1 v5 `--group-lead=drive`** (ef68308d1): a column's places go to its squads in the order their crews reach the click by
  ground. In `untangle_whole` every squad of a column is one knot, and the first key is `lead_breaks` (a squad placed behind
  one it leads by > 6 m), then crossings, then drive. Decided: lead = the mean of the squad's crews' navmesh drives (the bulk
  of the squad, not one forward scout).
  - Lab (laptop GDScript): pins today's straight-line swap (Bravo to the head) and the fix.
  - **s4710 lab** (builder0 light J3, ef68308d1 + G2 work OFF, crossing 3 click, n 1;
    `references/round39/orders/g1v5-lab-s4710-builder0-ef68308d1/`): v4 Bravo never in, contacts 3,756 -> v5 all in 9.7 s,
    twitch 0, contacts 71 (main 875, all in 17.3 s).
  - **Dev read 1** (builder0 light J4 at load 20-47, 93a6c2283, dev seeds 3804-3809, n 6, 12 cells;
    `references/round39/orders/g1v5-dev1-builder0-93a6c2283/`):
    - v5 keeps v4's deciding lines v main: outside 14 -> 1; metres outside 1,011 -> 168; re-dealt 12 -> 0.
    - Contacts: main 5,970, v4 5,651, v5 5,013. v4 -> v5 passes every probe guard.
    - Both arms fail one guard: terminus 5 route never-in 1 v 2 (s3805 squad 1). No column was laid on that run and v4 / v5
      rows match, so it's v4's squads-whole on the route's first plain click (R38.44), not v5. Not traced yet.
- **G2 v2 `--group-route-corner=line`** (v2c, 6ac4b67d2): on a leg the column's room is read along the road (his route), no
  further back than its squads' rearmost start; ranks past the route's first corner (> 30 deg) stand centred on it.
  - Lab (Terminus navmesh, his east route's last leg): v1's rear rank stood two abreast 32 m either side of the x=70 street;
    v2 puts every place on the route line.
  - **Dev read 1** (builder0 light J4, da9591207, dev seeds 3801-3803, n 3; `references/round39/orders/g2v2-dev1-builder0-da9591207/`):
    - his routes' metres off his drawn path: main 5,022, g2 v1 5,107, v2 3,302; never-in 9 / 6 / 3;
    - his 5-squad east: 2,965 / 3 never -> 876 / 0; his 5-squad west: 1,127 / 6 -> 849 / 0;
    - route cells: off 2,404 -> 1,462, never-in 1 -> 0.
    - Costs: his 5 avenue 142 -> 682 m (the rear squad's place at the army's start); his 3 east never-in 3 (g2 v1's
      too: a whole-squad swap on a leg); terminus 5 route worst twitch 18.7 -> 34.1.
  - **Dev read 2** (4ce8784d5; `g2v2b-dev2-builder0-4ce8784d5/`): v2b (rank centred, not single file) = v2 on every cell.
    `--group-lead=drive` on legs is worse (his routes never-in 3 -> 6), so G1 v5 stays a plain-click rule.
  - v2c fixes the avenue cause (laptop trace, not pairable: squad 4 on the route, every squad in).
  - **Dev read 3** (builder0 light J4, 584d23588, dev seeds 3801-3803, n 3; `g2v2c-dev3-builder0-584d23588/`): his routes off
    5,022 -> 2,523, never-in 9 -> 3; his 5 east 2,965 -> 207; his 5 avenue 536 (main 142); route cells off 2,404 -> 1,432,
    never-in 1 -> 0. `orders_judge.py g2`: both deciding lines PASS, guards fail on 9 cells (end foreign, twitch). His 3 east
    never-in: a squad's halt seat stands on the next squad's route (CP39.1's cause), so it re-reads on CP39.1.
- **G3 v6 `--place-clear-seat=on`** (da9591207): a moved place must deploy in the given place's shape and spacing, worst leg
  <= given + 2 m (or 8 m); else it steps back along the squad's own leg; else it's kept. It uses settle's
  `ElementPlan.deploy_preview`, built on my request and copied verbatim from stream/settle 4066132c4.
  - Trace (laptop, n 1, not pairable; `references/round39/orders/g3v6-trace-laptop-650e43521/`): v5's moved place read
    lanes / 10 m v the given place's dense / 7.5 m, so the deploy dealt the crews across (worst leg 16 m v main's 6.7).
  - With v6 (laptop, n 1): squad 2 keeps its place, all in at 17.3 s.
  - A shapes-only estimate (no preview) couldn't separate the places (11.0 v 13.0 m); removed.
  - **Dev read** (builder0 light J4, b7bef53b1, dev seeds 3804-3809, n 6): main -> g3v6 PASSES `orders_judge.py g3`; places
    cleared 25 (v5 33); pairs < 12 m 25 -> 4; crossing 5 route worst twitch v5 42.9 -> v6 29.9.
- **Merge notes:** `element_plan.gd` carries a verbatim copy of settle's `deploy_preview` + `_unit_of` (keep settle's, drop mine);
  `orders_judge.py` probe_guards' all-in guard passes a cell where the base never got all in (be1219fa7).

### Bars (filed here before any judged number; the orchestrator records them on main)
- **Amended by R39.9 (2026-10-24, before any number on 6201-6224):** CP39.1 = main with settle's DEPLOY_HOLD ON. Tree for
  both bars: stream/orders with main merged at >= 2316bc4f7 (0fc1d7fb3, main 2518811d0 with the full-check lock), green full check on either builder.
  Both arms: DEPLOY_HOLD ON (default), `--giveway-chain` OFF, `--seat-route-clear` OFF. G1 v5 on builder0 light J4, G3 v6 on
  builder2 J14, run together (`tests/control/orders_bar.sh`). Everything else as filed.
- **Bar G1 v5 GROUP LEAD (orders, round 39; filed 2026-10-24 before any number on its seeds; code ef68308d1, all OFF).**
  What he would see: select all and click a street. Every squad lands in that street, stacked back along it, the squad in
  front taking the far place, so no squad parks on the way of one still to pass, and every squad gets in.
  - **Arm:** `column:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached,--group-lead=drive`
    (G1 v4's arm + v5).
  - **Tree:** the first commit at or after CP39.1 merged into stream/orders (C39.3) whose builder0 full check is green. G2 and
    G3 switches OFF in both arms; settle's and manoeuvre's CP39.1 switches as main has them, both arms.
  - **Probe:** `make native orders-probe`, arms `main:` v the arm above, builder0 light lane J <= 4,
    `TANK_SQUAD_SLOT_TIMEOUT=14400` as a make variable, **FRESH seeds 6201-6212** (n 12 a cell). Cells: as Bar G1 v4 (the 12
    street cells, his click as `terminus_his` 3 / 5, yard_open 3 / 5 x click / route).
  - **Judge:** `orders_judge.py g1v4` (street + his rows; yard_open rows as the 5th argument). Counter, deciding lines (over
    the click cells + his click: places outside <= 25 % of base; route_left_m <= 50 %; re-dealt 0 over the click cells) and
    guards (every R36.6 guard per cell over all 14 cells, as filed; contacts <= base x 1.1 + 5; yard_open identical) are G1
    v4's, unamended. The judge's all-in guard now passes a cell where the base never got every squad in (be1219fa7); the
    never-in line still judges that cell.
  - **Known risk:** terminus 5 route never-in (dev read 1: s3805 squad 1, v4's whole first click, not v5's ordering; laptop
    does not reproduce). Taken as the honest price of a fresh read, as R38.44.
  - **Plus:** paired top-down shots of his click, main v column, looked at. A pass ships ON.
- **Bar G3 v6 PLACE_CLEAR SEAT (orders, round 39; filed 2026-10-24 before any number on its seeds; code da9591207, all
  OFF).** What he would see: no squad parks on top of another, and a squad moved to make room parks the way it would have
  where it was sent, with no shuffle after it stops.
  - **Arm:** `g3:--place-clear=on,--place-clear-trigger=near,--place-clear-reach=on,--place-clear-seat=on`.
  - **Tree:** as Bar G1 v5 (after CP39.1, green builder0 full check; G1 / G2 OFF in both arms).
  - **Probe:** as Bar G3 v5 (the same 18 cells), **FRESH seeds 6213-6224** (n 12 a cell).
  - **Judge:** `orders_judge.py g3`: the counter, deciding line (pairs < 12 m <= 25 % of base), offset guards, R36.6 guards
    (twitch included) and contacts as Bar G3 v5, unamended.
  - **Dev evidence:** dev read 1 (builder0, b7bef53b1, dev seeds 3804-3809): main -> g3v6 PASS.
  - A pass ships ON.
- **G2 v2: no bar yet.** Dev read 3 (584d23588) passes both deciding lines (his routes off 5,022 -> 2,523, <= 60 %; route
  cells 2,404 -> 1,432, <= 75 %) and fails guards on 9 cells (end foreign, twitch). A column stands squads closer than
  main's spread body, and the stops in the street are CP39.1's cause. It re-reads on CP39.1 first; its bar block is 6225-6236 (reserved by the orchestrator).
