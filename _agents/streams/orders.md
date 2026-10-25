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

### NOW (2026-10-24 night)
- **REPORT (2026-10-25): Bar G1 v6 FAILS on one guard** (frozen tree c7d642aeb = green 8bbafb376 + docs; builder2 J4;
  8201-8212, n 12 a cell; evidence `references/round40/orders/g1v6-judged-builder2-c7d642aeb/`). Switch stays OFF.
  - FAIL guard: **terminus 5 route twitch** 20.6 v 25.4 (median of per-run worst; bar base + 3). Four seeds differ
    (8203, 8205, 8206, 8208), worst squad Delta on three.
  - PASS every deciding line: places outside (click cells) 65 -> 8 (<= 16.2); route_left 3864 -> 589 (<= 1932); re-dealt
    0. Contacts 14781 -> 11799; yard_open identical; never-in no more. v5's two failures are gone (his 5 twitch, locks
    5 outside). Old corridor read reported: 98 -> 17, 6174 -> 1209; main v main changed only on locks and terminus_his.
  - **Traced (laptop, c7d642aeb-equivalent code, s8206 terminus 5 route, `--probe-trace=4`; reproduces 21.4 v 35.5):**
    v6's two sides never fire on this cell (every squad's centre 18-31 m short of the click). The difference is v5's
    column on the route's first plain click: it gives Delta a first place (23.4, 84.5) almost on its final one (22.3,
    84.5), so Delta stands at its halt by t 4 while Bravo and Echo still drive through that street. It is never all in,
    deploys on the 10 s cap (13.9 s) with its crews bunched at (24-30, 89-92), and then Delta_2 drives 36 m east to (65,
    68) and Delta_4 29 m south-west to (4.8, 70.8), still moving at t 45. In main its crews come in strung out and deploy
    on the cap at 15.2 s nearer their seats (worst 21.4). So it is a cap deploy among passers, which T1 changes.
  - **Orchestrator's dev read (running):** the G1 v6 arm v main on T1-ON main, terminus 5 route only, dev seeds
    3801-3812, builder2 J4, frozen tree `/home/slobdell/projects/godot-orders-t1` = main 9d5907ddd + c7d642aeb merged
    (a1602cca9, detached, not on any branch). If the twitch gap closes there, round 41's G1 v7 starts from it.
- **Plan:** O1 done -> G1 v6 built + dev-read (deciding lines pass) -> full check of the tip -> **Bar G1 v6 (filed below)** on
  builder0 light J4 -> O2 written up as blocked (dev read failed, cause traced, below) -> O4 G2 v2c re-read (running on
  builder2, `tests/control/orders_g2.sh`) -> its bar if it holds. R40.5 (orchestrator): C40.3 relaxed, G1 v6 judges on
  main as it is unless CP40.1 lands first; the probe's new corridor read decides, the old one is reported beside it.
- **G1 v6 dev read 1** (builder0 light J4, 2eedf9f7f, dev seeds 3804-3806, n 3, `orders_bar.sh b0 g1v4`; evidence
  `references/round40/orders/g1v6-dev1-builder0-2eedf9f7f/`): v6 v main passes every deciding line:
  - places outside (click cells): new read 13 -> 1; old read 19 -> 1;
  - route_left_m 684 -> 35 (old read 1116 -> 45);
  - re-dealt 0; yard_open 48 of 48 rows identical; contacts 2996 -> 2315.
  - **His 5 click: Bravo's twitch 28.4 -> 9.7 m, every squad in** (worst Alpha 14.2 v main's worst 13.8; probe guards pass).
  - The read changed main v main only on his click (terminus_his 3 / 5: the floodlight-type post there too).
  - **One guard fails: terminus 5 route never-in 0 v 1** (s3805 squad 1), the same cell and squad v4 / v5 failed in round
    39's dev read. Traced (builder0 light, 3b4f03053, `--probe-trace=1`): every leg is identical across arms, and an arm
    with every G1 switch but `--group-whole=click` fails the same way (not a switches-OFF arm: the `main:` arm matches main,
    23.1 / 7.8 / 5.0 / 3.3 / 63.7 s, as manoeuvre's main read on 479bf90f9). The difference is the crew deal: under
    GROUP_LAY the route's first plain click keeps squads whole (`untangle_whole`, whole_still_crossed 1), where main
    re-deals crews. Alpha_3 follows the legs into the x = 0 street and wedges at (7, 83)
    from t 40 to t 90, among squads parked at (-7.5, 72) and (21.2, 84.5), still bound for (-28.6, 34.9). This is R38.44's
    trade-off ending in a traffic wedge; not v6's two-sided lay. Carried as the bar's known risk.
- **O2 G3 v7: BLOCKED (dev read FAILED; cause traced; switch OFF, no bar filed).** Dev read 1 (builder2 J14, 4c672deca,
  dev seeds 3804-3809, n 6, `orders_bar.sh b2 g3`, evidence `references/round40/orders/g3v7-dev1-builder2-4c672deca/`):
  every guard passes (never-in 1 -> 1, contacts 7183 -> 7025, 18 probe cells), but **deciding pairs < 12 m 25 -> 17**
  (bar <= 6.2; v6's dev read 25 -> 4): the road test refuses moves next to every neighbour. Laptop traces (crossing 5
  route s6213 / s6220, `--column-trace`; legs identical to the bar's):
  - The moves that put Delta on Echo's road were **v5's aside/back steps, accepted by v6's seat check, not the step back
    along the leg** (s6213: Delta (-66.9, 29.5) -> (-53.9, 38.8); s6220: (-68.6, 29.5) -> (-55.4, 38.5)). So v7 tests
    every step.
  - **On a route, G3 runs before `_relay_previous_waypoint` re-lays the previous waypoints.** Every squad's road in
    starts from a stale point: s6213's Echo road started at (-41.9, 40), not its relaid (-53.7, 70.5). A road test on
    those inputs is either too wide (dev read 1) or misses s6213 (a trimmed variant, laptop, not committed).
  - **Next (a fresh version):** run place_clear on a shifted leg after the relay, reading roads from the relaid
    waypoints; or G3 on plain clicks only. Both change v6's tested order of operations: a new design, not a tweak.
- **O1 DONE (c08d8f720): locks 5 "places outside 8 -> 8" is the probe's corridor stopping at a floodlight, not G1.**
  Laptop trace (`--column-trace`, s6204-6207, n 1 each): his click lands on the open west quay 4-6 m east of the
  floodlight at (-14, 20). `gate_width` stops at the post's navmesh hole (corridor left 4-6 m, right 92-94 m), so the
  probe counts squads 1 and 2's places, 19.7 and 39.4 m west on the same quay, as outside. The column rightly keeps
  today's body (`--group-clear=reached`; bodies_kept 1 on all 12 bar runs). Fix, measurement only:
  `gate_width(..., past_posts)` (default 0: every game caller unchanged); the probe reads past obstacles <= `POST_SPAN_M`
  8 m (`--probe-corridor=gate` = round 39's read). Test `test_control_corridor_posts` (builder0 light, 2/0). R40.5: the
  probe reports the old read beside it (`anchor_outside_gate`, `route_out_gate_m`, `route_left_gate_m`), and
  `orders_judge.py g1v4` prints both reads per cell plus the cells where main v main's read changed.
- **G1 his-5 twitch traced: G1 v5's own lay, not settle's trigger.** From round 39's e7c896c8f logs (s6201): the body comes
  in from the east, but Alpha starts at (-58, 96), 29 m WEST of the click. v5's column (lead=drive) gives it the 2nd
  place, 34 m east, so Alpha drives 62 m through Bravo's halt at the click. Bravo gives way t1-t10, is never all in, and
  deploys on the 10 s cap; Bravo_2's 24 m leg falls after the probe's place window.
- **G1 v6 `--group-sides=both` (88b413ec4 + 2eedf9f7f, OFF):** a squad whose centre stands > 15 m past the click is laid
  on its own side, a column out from the click the other way. Its front stands at the near side's own rank spacing,
  squeezed toward half where the ground runs out (a full 69 m rank stood off Terminus' west edge). Either side failing
  falls back to v5's lay. `untangle_whole` counts `misplaced` (a place across the click from its squad) ahead of the
  lead rule. Probe: `columns_two_sided`. Tests `test_control_group_click` 31/0. Shots (laptop, his click 5,
  `make orders-probe-shots`): v6 has Alpha's squad on its own west side and the rest stacked east along the street.

- **O4 G2 v2c re-read: does NOT hold, no bar** (builder2 J10, 78eeea863 = main as launched + orders, all OFF, dev seeds
  3801-3803, n 3, `tests/control/orders_g2.sh b2`; evidence `references/round40/orders/g2v2c-reread-builder2-78eeea863/`).
  Every number repeats round 39's dev read 3 (584d23588) exactly: his routes off 5,022 -> 2,523 and route cells 2,404 ->
  1,432 (both deciding lines PASS); contacts 4,046 -> 3,403. DEPLOY_HOLD acts only when a squad loses a tank, and the probe
  has no fights, so it can't move them. **Guards fail on 10 cells:** end foreign on 7 (e.g. terminus 5 east 9.8 v 4.5,
  locks 5 route 13.6 v 7.1) and twitch on 4 (terminus 5 avenue 0.0 v 15.1, locks 5 route 8.1 v 15.4). A column parks
  squads nearer each other than main's spread body. **R40.10:** no G2 bar this round. Its one later re-read runs on
  top of settle's S1 v3 (`--seat-route-clear=v3`) if Bar S1 v3 passes (end foreign is S1's kind of failure); the
  orchestrator says when.
- **G3 v8 `--place-clear-after=relay` (5bc304738, OFF; R40.9): dev read FAILED, no bar.** On a shifted leg the G3 block
  (now `_place_clear()`) runs after `_relay_previous_waypoint`, each squad's road read from its relaid previous waypoint
  and short of its own halt (`lane_skip`). Dev read 1 (builder2 J4, 5bc304738, 3804-3809, n 6, `orders_bar.sh b2 g3`;
  evidence `references/round40/orders/g3v8-dev1-builder2-5bc304738/`): every guard passes (never-in 1 -> 1, contacts
  7183 -> 6857, 18 probe cells, worst +16.9 m), **deciding pairs < 12 m 25 -> 10** (bar <= 6.2; v7 17). All 10 left
  are on crossing and are main's own places, unmoved. 8 of the 10 are runs where every step was refused for standing on
  a road (places_cleared 0, places_off_lanes 1-3). Laptop trace (crossing 3 click s3806, `--column-trace`): squad 0's
  three steps lie on squads 1 and 2's roads, read 17.2 and 19.7 m either side (`lane_reach` = half the driver's parked
  width + half the halt's short side), a band as wide as a herringbone around every road on a crossing.
- **G3 v9 `--place-clear-lane=column` (9076ee2f8, OFF): dev read PASSES -> Bar G3 v9 filed below.** A road in reads
  as wide as the column driving it (`ROAD_HALF_M` 4 m + half the halt's short side; ~10 m on crossing, v8 17-20 m).
  v7's case still holds (test). `test_control` 526/0 (laptop). Dev read 1 (builder2 J4, code 9076ee2f8; parts synced
  743f86a4a / c6dfbd42e, docs only after it; 3804-3809, n 6; evidence
  `references/round40/orders/g3v9-dev1-builder2-9076ee2f8/`): **pairs < 12 m 25 -> 6 (<= 6.2), PASS**; places_cleared
  20; never-in 1 -> 1; 18 probe cells (twitch included) pass; worst +24.0 m (0 of 432 > 40 m); contacts 7183 -> 6801;
  route_left_m 6000 -> 5734. The streets part was preempted once (Spot, exit 255) and re-ran whole.
- **Full check of 8bbafb376 (builder0, load ~10): `make native check exited 0`, 25 passed, 2 NOT JUDGED** (perf-judge
  refused 3 times on a busy box, 1.52-1.84x; scenario_perf unpinned on the hybrid). Green: the G1 v6 series' tree.
- **CP40.1 on main (orchestrator, 2026-10-25):** main 9d5907ddd = settle's cab85debf (T1 `--deploy-arrive=settled` ON)
  + manoeuvre's M1 v2 (OFF). G1 v6 and G3 v9 stay on their frozen trees (T1 OFF, as filed). A pass ships with its
  check on a T1-ON main. **After G1 v6's verdict:** one dev read of its arm on T1-ON main (his click 5 + terminus 5
  route), for the merge.
- **Settle's Bar T1 passed (orchestrator, 2026-10-25):** `--deploy-arrive=settled` ships ON as CP40.1 after its flip
  check. The G1 v6 series stays on its frozen tree, T1 OFF both arms as filed (R40.4); main is not merged into it.
- **Bar G1 v6 series: running on builder2 J4 from a frozen tree** (orchestrator, after 893850559: a judged series runs ONE
  tree; builder0 was over R40.11's cap). Detached worktree `/home/slobdell/projects/godot-orders-g1v6` at c7d642aeb
  (= green 8bbafb376 + docs), synced to builder2:~/tank_squad/godot-orders-g1v6; every part runs from it
  (`~/overnight-orders/barg1v6-b2-c7d642aeb`). The first builder0 start (light, c7d642aeb) was stopped mid-streets by my
  PIDs; no part of it stands. Shots (laptop, c7d642aeb, his click 5, seed 34, `orders-probe-shots`, arrival + 5 s):
  main knots the squads in the centre street between the blocks; sides keeps Alpha's squad west of the click and lays the
  rest east along the front street.

### Bars (filed here before any judged number; the orchestrator records them on main)
- **Bar G1 v6 TWO SIDES (orders, round 40; filed 2026-10-24 before any number on 8201-8212; code 2eedf9f7f, all OFF).**
  What he would see: select all and click a street. Every squad lands in that street, the squad nearest the click on it,
  the others stacked back along their own way in. A squad that stood past the click stays on its side, so none drives
  through another's halt, and every squad gets in without a reshuffle.
  - **Arm:** `sides:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached,--group-lead=drive,--group-sides=both`
    (G1 v5's arm + v6). Base `main:`.
  - **Tree:** stream/orders at the commit whose full check is named green below (main as launched, 68d0410d3 code;
    DEPLOY_HOLD ON both arms; `--giveway-chain`, `--seat-route-clear`, `--deploy-arrive=near` OFF both arms, as main has
    them; R40.5: on main as it is unless CP40.1 lands first, then on it, both arms).
  - **Probe:** `tests/control/orders_bar.sh b0 g1v4 <arm> "8201 ... 8212" <out> 4` (builder0 light J4,
    `TANK_SQUAD_SLOT_TIMEOUT=14400`), **FRESH seeds 8201-8212** (n 12 a cell). Cells as Bars G1 v4 / v5: the 12 street
    cells, his click (terminus_his 3 / 5), yard_open 3 / 5 x click / route.
  - **Judge:** `orders_judge.py g1v4`, unamended from G1 v5. Deciding (click cells + his click): places outside the
    corridor <= 25 % of base; route_left_m <= 50 %; re-dealt 0. Guards: every R36.6 guard per cell over all 14 cells;
    contacts <= base x 1.1 + 5; yard_open identical. **Corridor (R40.5):** the deciding lines read the probe's new
    corridor (past posts <= 8 m). The old read's places outside and route_left_m are reported beside them, per cell. One
    line shows main v main, new v old read, and names the cells where the read changed (it must be only cells with a
    post inside the scan).
  - **Known risk:** terminus 5 route never-in (dev read 1 s3805 squad 1, also in v4 / v5's dev reads): the whole-squad
    deal on the route's first plain click (R38.44) wedges a crew in the x = 0 street. Taken as the honest price, as round 39.
  - **Plus:** paired top-down shots of his click, main v sides, looked at. A pass ships ON.
  - **R40.11 (tree after builder0's crash):** the b4da041c4 check died to the watchdog at load 26. The tree is now
    8bbafb376, if its check goes green. `git diff b4da041c4 8bbafb376 -- game/` (2 files, +99 / -46) is G3 v8 only:
    rts_controls.gd moves the G3 block unchanged into `_place_clear()`, still reached only under `--place-clear=on`, and
    adds the deferred call under `--place-clear=on` AND `--place-clear-after=relay`. selection_squads.gd adds `on_road`'s
    `skip_end` (default 0, unchanged), `lane_skip` and `PLACE_CLEAR_AFTER`. Every G3 switch is OFF in both G1 v6 arms, so
    neither arm reaches the changed code. Lane (R40.11): builder0 light only when one of the two lanes allowed beside a
    full check is free; otherwise builder2 once G3 v8's dev read ends.
- **Bar G3 v9 ROAD A COLUMN WIDE (orders, round 40; filed 2026-10-25 before any number on 8213-8224; code 9076ee2f8,
  all OFF).** What he would see: no squad parks on top of another; a squad moved to make room parks the way it would
  have where it was sent, and never on the road another squad still has to drive in, on a click and on a shift-click
  route alike.
  - **Arm:** `g3v9:--place-clear=on,--place-clear-trigger=near,--place-clear-reach=on,--place-clear-seat=on,--place-clear-lane=column,--place-clear-after=relay`.
    Base `main:`.
  - **Tree:** a frozen detached worktree at the commit whose full check is named green here (code 9076ee2f8; main as
    launched; DEPLOY_HOLD ON both arms; every G1 / G2 switch, `--giveway-chain`, `--seat-route-clear`,
    `--deploy-arrive` OFF both arms, as filed for G1 v6; R40.4). Every part runs from it.
  - **Probe:** `tests/control/orders_bar.sh b2 g3 <arm> "8213 ... 8224" <out> 4` (builder2 J4,
    `TANK_SQUAD_SLOT_TIMEOUT=14400`), **FRESH seeds 8213-8224** (n 12 a cell), the 18 cells of Bars G3 v5 / v6.
  - **Judge:** `orders_judge.py g3`, unamended from Bar G3 v6: counter; deciding pairs < 12 m <= 25 % of base; never-in
    no more; offset guards (worst place-to-click median per cell <= base + 15 m; > 40 m further <= 5 % of rows; none
    > 100 m); R36.6 guards per cell (twitch included); contacts <= base x 1.1 + 5.
  - **Dev evidence:** dev read 1 above (25 -> 6, PASS by 0.2 of a pair: the margin is thin).
  - **Known risk:** Bar G3 v6's crossing 5 route never-in / twitch (round 39, untraced: a cleared place's own leg meets a
    passing squad head-on). v9 keeps every moved place off the others' roads in, which should answer it; the dev read's
    crossing 5 route cell passed, at n 6.
  - **Lane (orchestrator, C40.1: one judged series per builder):** recorded as filed at 893180a31. After its full check
    goes green, it runs from the frozen tree on builder0 light J4 in the lane manoeuvre's M1 v2 frees, or on builder2
    once G1 v6 ends, whichever comes first.
  - A pass ships ON.
