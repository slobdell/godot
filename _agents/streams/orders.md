# Stream: orders (his group click: the army goes where he clicked, stacked, whole)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1, C38.3) and
> in *Round 37*: R37.29, R37.38, R37.39 (his click, O7, the real-point read). Your round-37 brief and close notes:
> `streams/archive/round37/orders.md`. The design note: `references/round37/orders/group-click-column-note.md`; the lab:
> `tests/test_control_group_click.gd`; the switch on main: `--group-lay=column` (OFF). **You own:** `game/control/**`,
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`. Not the deploy/halt/seat functions (settle's,
> C38.3). **Model:** FABLE. **Machine:** builder0.

## The lead's direction (2026-10-21, verbatim in game_design.md *his playtest note on a group click*)

"By selecting all units and just clicking on an open space in the East side of the map, the target waypoints for each squad was all
over at far away places ... if there's not enough room for all target vehicles at the target waypoint ... it would make sense to just
have stacks of wedges (i.e. one squad immediately behind the other) ... the squad furthest away to land in the back and the closest squad
to land in the front ... I had a clear intent to navigate my army through a specific path I had in mind, but I immediatley lost control
of the army". And his standing bar: units must look smart and under his control; contention first.

What he will notice: select all, click anywhere on Terminus (or any street map): every squad lands in the space he clicked, stacked
along the approach, nearest in front, each squad with its own vehicles, nobody driving through another street.

## Where things stand

- O7 v1 (`--group-lay=column`, main, OFF) FAILED as filed (R37.38): plain clicks improved (crossing 5 outside 23 -> 2), route cells
  unchanged (squads leave the corridor on the route legs, not at the final click), yard_open changed (the scan's 100 m "open" test; its
  walls are nearer). At HIS real click it works (R37.39: outside 36/60 -> 0, metres outside 2,350 -> 323, re-dealt 24 -> 0).

## Backlog (in order)

1. **G1 O7 v2:** (a) open ground = the clear width fits today's body (not the scan limit), so yard_open stays identical; (b) route
   legs: lay each queued leg's arrival the same way, or keep squads in one column along the route; (c) whole squads (no re-deal).
   Lab first (his click; a route cell; yard_open identical), then a bar (O7's lines + "route metres outside the corridor"; yard_open
   rows identical; contacts; all-in). Paired top-down shots of his click, looked at, for him. A pass ships ON.
2. **G2 the shift-click route** case he described ("navigate my army through a specific path"): a queued route of 2-3 clicks keeps the
   army in one column through each street.
3. **Stretch:** the bridge-mouth lay (a plain click's places kept off the deck; R37.17's O3 trace).

## How to verify

Lab both paths; `make quick-remote`; one full check per named hash; `make native orders-probe` series on fresh seeds; his click as its
own cells (`--probe-click=x/z`); shots looked at. Smoke: `make skirmish ARENA=terminus`, select all, click the east apron.

## Don't touch

settle's deploy/halt/seat functions, doctrine's brains paths, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing (the shots go to him at the close).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### NOW (2026-10-22 late evening)
- **G3 (R38.15; Bar G3 filed 95dd05e36, seeds amended to 4101-4112, deciding line amended before any number):** dev reads only so far.
  - Dev read 1 (builder0 light, 42377862a, dev seeds 3801-3803, n 3): v1's full-depth box stepped squads 60-90 m back.
    14 of 216 rows were > 40 m further than main; crossing 3 route s3802 went 24 -> 91 m. FAIL.
  - v2 (f65b23c26): places only need their short sides clear; a place moves aside first, then back, at most 40 m.
  - Dev read 2 (builder0 light, f65b23c26, n 3): offset guards PASS (none > 40 m further; worst +15.3 m). Close pairs
    17 -> 5; all 5 left were two squads in one element (0.0 m apart), which is a probe reading, not an overlap. Also seen:
    his 5-squad click twitch 11.6 -> 29.9 m, because the old untangle re-dealt squad 4's crew to squad 3's place; one
    never-in on locks 3 route s3802; terminus 5 route end foreign 10.6 -> 6.9.
  - 527d62cd2: where G3 moved a place, untangle swaps squads whole; probe rows name the anchor's element; the judge skips
    pairs sharing an element. Laptop his 5 click s3801 (n 1): nobody re-dealt, all-in 47.4 -> 20.8 s, worst twitch 14.6 m
    (guard line 14.6). Lab 14/14; group/requeue/untangle tests 39 + 2 + 9 pass on the laptop.
  - Dev read 3 (builder0 light, 527d62cd2, dev seeds 3801-3803, n 3): deciding PASS (place pairs closer than 12 m 12 -> 1,
    line 3.0), every offset guard PASS (2 of 216 rows > 40 m further; worst +46.9 m), contacts 3,401 -> 3,643 (line 3,746).
    FAIL on the never-in guard 0 -> 2, and on his 5-squad click twitch 11.6 -> 22.1 m.
    - locks 3 route s3802: g3's places equal main's, and main's squad 1 only got in at 70.1 s (marginal).
    - crossing 5 click s3801: squad 4 moved 20 m aside, never in on builder0; laptop GDScript (n 1) in at 39.6 s, its
      crews crossing the other squads' lanes.
    - his click: squad 3 arrives at 0.1 s on a place its crews already stand on, then the halt reshuffles 20 m. That is
      the deploy (settle's latch question), not a G3 drive.
    - Trying "back first, then aside" (a dev switch) changed neither case on the laptop, so it was not kept.
  - Main merged at 8f0dcb488 (42268e4a1; none of my paths touched). Dev read 4 is running (68ad5df9f, dev seeds 3804-3809,
    outside every registered round-38 block) to read the never-in noise before any judged seeds are spent.
- **G1 v2 judged: FAILS as filed** (R38.12; `g1-judged-builder0-4a765e6e2/README.md`): deciding all pass (click-cell places
  outside 84 -> 18, metres after leaving 6,223 -> 1,393, re-dealt 58 -> 0, contacts 14,004 -> 10,622); guards fail: crossing 3
  route twitch 5.8 -> 10.5 m, his 3-squad click twitch 2.3 -> 11.4 m, yard_open 177/192 identical. Stays OFF.
- **G1 v3 (f2a94b6cc; Bar G1 v3 filed + amended before any number; judged seeds 3951-3962; judged read WAITS for settle's
  deploy latch ON on main, latch-on base):** today's body judged at the click's width; the 2 s first-click re-lay only where
  the column moved a squad > 40 m, and it sends the first click back to today's places. v2's three yard_open misses re-run
  on the laptop: byte-identical to main. quick-remote 6ff215661 (= f2a94b6cc + docs): builder0 279 / 0.
  Dev read 13 (builder0 light, f2a94b6cc, dev seeds 3801-3803, n 3; `g1-dev13-*`): deciding all pass (click cells: outside
  32 -> 7, metres after leaving 2,433 -> 321; re-dealt 20 -> 0), contacts 3,232 -> 2,506, yard_open 48/48; guards left:
  terminus 5 route twitch 18.7 -> 27.6 (no column laid there: whole-squad swaps over a deploy already twitching 0-28 m in
  main) and his 3-squad click 2.3 -> 11.4 (settle's halt flip: the latch base).
- **Full check of the v2 tree (builder2, a68ae8b84 = 4a765e6e2 + docs, load ~24, ~80 other Godots):** two failures OUTSIDE my
  paths, both load-sensitive: `broker-test` (relay subtest "a host that never comes back closes the room": timed out) and
  `shell-tools-test`'s `quiet-window` live sample ("our own are not foreign"). Verdict line: `make native check exited 2`,
  22 passed, 2 FAILED, 0 NOT RUN, 3 NOT JUDGED (perf-judge: builder2 not a judging box; scenario_perf at load; web-smoke
  first sound at load 56); tests 3,061 passed / 0 failed; sim-baseline 13/13 unmoved. The two re-run on builder0's light
  lane (b7d4dcffd): `make broker-test remote-guard-test exited 0`. **The hand-over hash's own full check** (b7d4dcffd: v3 +
  G3 + probe fix, all OFF) is running on builder2. web-smoke already failed there: "first sound 32.3 s after READY (bound
  30 s)" on headless SwiftShader at load ~31. That target is outside my paths and failed the same way on the v2 tree.
- **GREEN HAND-OVER: b7d4dcffd** (G1 v3, G3 and the probe budget print, all OFF).
  - builder2 full check: `make native check exited 2`; 24 passed, 1 FAILED (web-smoke), 2 NOT JUDGED (perf-judge: builder2 is
    not a judging machine; scenario_perf at load 4.76x); tests 3,063 / 0; sim-baseline 13/13 unmoved.
  - web-smoke re-run ALONE per R36.12 (builder0, b7d4dcffd, load ~16): `make web-smoke exited 0`, first sound 17.1 s.
  - Control timing (builder2 printed it over budget, not judged there). builder0, back to back, same load ~16: merge-base
    5b20bfd62 ordering 30 units 109.3 / right click 108.0 / UI 28.88 workloads, 3 failed; head 42377862a (same game code as
    b7d4dcffd) 112.8 / 114.5 / UI under budget, 2 failed. Both trees go over budget at this load; mine is within the
    base's noise. Not a regression from my code. A quiet-box read is owed before G1 or G3 ship ON.
- **Settle's S2 re-read fails one guard, so the latch stays OFF** (settle, ~19:30). The failing guard is first shape: 18 of
  576 rows differ, over the 17.3 line. Most of those are coil -> herringbone in lanes. The orchestrator rules whether that
  bar stands. G1 v3's judged read keeps waiting, as Bar G1 v3 says. No v3 number is taken on a latch that is not ON on main.

### EARLIER (2026-10-22 ~17:40 PDT)
- **G1 judged series RUNNING** (builder0 light lane, J 4 alongside manoeuvre per R38.8; tree 4a765e6e2 = 130cf487f + evidence;
  fresh seeds 3881-3892; amended Bar G1). Its **full check** is queued on builder2 behind doctrine's (R38.2): the verdict counts
  only if that check is green on the same game code. Output: `references/round38/orders/g1-judged-builder0-4a765e6e2/`.
- **Last dev read (130cf487f, builder0 light, dev seeds 3801-3803, n 3; `g1-dev11-*`):** deciding all pass (click cells: places
  outside 32 -> 7, metres after leaving 2,433 -> 321; re-dealt 20 -> 0 over all cells), contacts 3,232 -> 2,680, yard_open
  48/48 identical; guards failing at n 3: crossing 5 route never-in 0 -> 1, terminus 5 route twitch 18.7 -> 27.6 (no column
  laid there: whole-squad swaps v crew re-deals on a deploy already twitching 0-28 m in main), his 3-squad click twitch 2.3 ->
  11.4 (deterministic, n 1: the halt flips herringbone -> coil after the deploy; settle's `--deploy-latch=on` removes it).
- **Shots of his click (laptop, 4a765e6e2, seed 34, top-down at arrival + 5 s, desktop + phone; LOOKED at;
  `references/round38/orders/g1-his-click-shots-laptop-4a765e6e2/`):** 5 squads, main: one squad sent up the street between
  the two blocks (green post) and one piled on the right block's corner (pink); column: all five on the apron in front of
  his base, his click's squad at the click, the rest along the apron, nobody up a street. 3 squads: same pattern.
- **New item G3 (from settle's S2 trace, R38.10):** a place never lands on another squad's halt. crossing 5 click s3866: main
  lays squads 3/4 6.3 m apart (squad 4 never in); the column lays all five >= 22 m apart. G3 is for the today's-body path; after
  G1's verdict, OFF until its own bar. Also owed: the probe prints the `--probe-budget` refusal (not "no RtsControls").

- **G3 built (side worktree `~/projects/godot-orders-g3`, detached, commits 236bcd5b6 + 350939499; moves onto stream/orders
  after G1's series):** `--place-clear=on` (OFF): no two places' footprints overlap (block width across x depth along the
  approach, + GAP_M); nearest the click first, a later overlapping place steps back 4 m at a time onto standable ground (up
  to 100 m). Lab +1. Laptop GDScript crossing 5 click s3866 (n 1): main squad 4 never in, end foreign 4.5 m; ON: all in by 10 s,
  end foreign 12-17 m, twitch 0-3.8 m (but squads 4/5 step ~60 m back: the bar must guard place offsets). Probe: a budget
  his army is over now stops with the reason (settle's report).
- **G2 (his shift-click route) findings, NOT ready, switches OFF:** pieces: `--group-legs=on` (column on shifted legs and
  gates), `--group-route-line=on` (stack back along the clicked route), the 2 s first-click re-lay (in G1), legs cut short
  to a place behind the previous leg's end. Laptop GDScript, terminus 5 squads, his-style routes `--probe-points` east
  `70/50+70/-30+25/-30`, west `-70/50+-70/-30+-25/-30`, avenue `0/30+0/-30+-50/-30`, s3801, n 1 each: metres off the drawn
  path (`route_off_m`) main 577 / 488 / 61 v G2 430 / 256 / 293 (total 1,126 v 979); never-in squads and ~80 s all-ins in
  BOTH arms on the side-street routes. Reading: five squads on a 20 m street route are dominated by traffic (give-ways,
  queues: manoeuvre's paths), not by where the places are; G2's deciding line (route_off_m <= 50 %) is not in reach from the
  lay alone. Next for G2: a bar on 3-squad routes first, and a request to manoeuvre if the traces show queues at corners.

### REPORT (orders, round 38; updated 2026-10-22 ~09:30 PDT)
- **Start:** stream/orders = main 5b20bfd62 (round 38 docs; HANDOFF: main 1c484a525 GREEN on builder0, not re-run).
- **Plan (in order):** G1 (a) open ground, (b) route legs, (c) whole squads -> lab -> dev read (builder0 light) -> bar filed
  here -> full check on the named hash -> judged probe (fresh seeds) -> shots of his click -> ship ON if it passes. Then G2
  (his shift-click route, 2-3 clicks through streets), then the stretch (bridge-mouth lay).
- **G1 built (942533413, `--group-lay=column`, OFF):**
  (a) `SelectionSquads.column_lay(..., today)`: today's body (ranks + fit_inside, what the caller lays without the column)
  is KEPT when every one of its places stands inside the clear width read at its own rank (`on_clear_ground`: the point on
  the approach line level with the place, GROUP_SCAN_M a side, 0.5 m slack). Decision: the place's centre, not its wings,
  because that is what the deciding line counts and the halt shapes (lanes/dense) already narrow a squad at a wall.
  (b) a shifted leg (`queue`) for several squads lays the column too, each squad's block centred where its previous leg
  ends (`_leg_starts`, round 34's route-deal starts), approach from there; round 34/35's gate_order / uncross_paths are
  skipped on a column leg (the column already deals front to back by where each squad comes from). A gate
  (`_relay_previous_waypoint`) whose places stand off the clear ground is laid as a column too.
  (c) whole squads: v1's `untangle_whole` kept; on a shifted leg the vehicles' drives start at their squad's leg start.
  Probe: `route_left_m` (metres a crew drives outside the corridor AFTER it has once stood inside it: "left the street";
  v1's `route_out_m` also counts the drive in from a 200 m-wide start, which no lay can change) and `bodies_kept`.
  Lab `test_control_group_click` 7/0 (laptop GDScript, 942533413): +3 cases (body on clear ground kept although walls
  are inside the scan; a place past a wall -> column inside the walls; a rear place read at its own rank).
- **G1 dev read 1 (builder0 light, native, 942533413, orders-probe locks/crossing/terminus/yard_open x 3/5 x click/route x
  3801-3803, n 3; `references/round38/orders/g1-dev1-builder0-942533413/`; NOT judged, dev seeds):** places outside the
  corridor 41 -> 10; metres outside after being in it 4,974 -> 1,516; squads re-dealt 14 -> 0; yard_open 48/48 rows identical
  (bodies kept 30, no column laid). BUT crowding where the column engaged: contacts 2,842 -> 3,948; all-in up (crossing 5
  click 38.2 -> 51.6 s, locks 5 click 26.4 -> 38.1); end foreign down (locks 3 click 18.3 -> 9.2 m). Traced (laptop, crossing
  5 click s3801): ranks stepped by formation depth (a herringbone of 5 is 54.8 m deep), ranks centred in the clear width slid
  44 m sideways into the arena's edge where the clamp piled them up, and never_behind pulls stacked ranks forward.
- **Fixes (4141ae445):** rank depth = the priced halt's footprint (`column_depth`); a rank slides off his click's line only as
  far as keeps it on the clear ground; the width read stops at the arena's edge (`crosses_or_edge`) and stays inside the
  click's own width (`_within_click`: at his Terminus click a rear rank on open ground spread 3 abreast 130 m wide); never_behind
  is skipped for a column (stacking behind the click is the point). PLACE_SLACK_M 2 m (the scan's step). Lab 8/0 + requeue /
  two-squads / pack 40/0 (laptop GDScript, 4141ae445). His click now: one wedge abreast (the strip is 60 m: arena edge one side,
  a block 16 m the other), four ranks stacked back from the click, nearest squad in front.
- **G1 dev read 2 (builder0 light, native, 4141ae445, same cells/seeds, n 3; `g1-dev2-builder0-4141ae445/`):** crowding gone
  (contacts 2,842 -> 2,291; every click cell's guards pass); places outside 41 -> 11, metres outside after being in 4,974 ->
  2,619. Left: crossing's rear ranks stacked off the map onto the arena corner (67.7, 117.2) (two squads one point), and
  terminus 5 route re-dealt crews (4 squads) on legs whose body was kept (round 22's crew untangle still ran there).
- **Fixes (4e25c1eab):** ranks stand straight back along his click's line while that point is on the map and reached by
  ground without a long way round (`reached_from`, ground_cap's rule); from the first that is not, back along the navmesh
  drive from the click to the body (`path_back`), never past the click; still off the map -> the last inside point.
  Decision: straight first, because "the street he clicked" is what he sees and what the bar reads; the road only where
  straight back is a wall, a river or off the map. Every group move under the switch keeps squads whole (`untangle_whole`),
  a kept body included. Probe (G2): `--probe-points=x/z+x/z+...` (his own shift-click route), `legs_outside`, `gate_columns`.
  Lab 9/0 (laptop GDScript, 4e25c1eab; + a column near the army stays on the map, apart, none past the click).

- **quick-remote 4e25c1eab:** builder0 `make quick exited 0`, 276 passed / 0 failed (35 touched test files + lint + smoke).
- **G1 dev read 3 (builder0 light, native, 4e25c1eab, n 3; `g1-dev3-builder0-4e25c1eab/`):** places outside 41 -> 9, metres
  outside after being in 4,974 -> 2,738 (limit 2,487), re-dealt 14 -> 0, contacts 2,842 -> 2,151, yard_open 48/48. Left:
  where the column ran off the map two squads got ONE place (crossing 5, locks 5 route); route cells slower (terminus 3
  route all-in 16.6 -> 35.8 s: same final places, driven ~110 -> ~216 m, the in-between waypoint's gate column stacked by
  halt depth so squads near their start drove back and forth).
- **Fixes (f215b1772):** a column too long for the ground behind it is laid again with ranks closer (up to 4 squeezes, to
  half the step; at that the rest stand abreast in the last rank); a gate (a waypoint passed through) steps its column by
  the shape squads travel in (`passing`). Lab 10/0 (laptop GDScript).
- **G1 dev reads 4-5 (builder0 light, native, n 3; `g1-dev4-builder0-f215b1772/`, `g1-dev5-builder0-e3389f1fc/`):** every
  deciding line passes (e3389f1fc: places outside 41 -> 5, metres after leaving 4,974 -> 1,367, re-dealt 14 -> 0), contacts
  2,842 -> 1,547, yard_open 48/48 identical, every click cell's guards pass; failing guards only on route cells (crossing 3
  route all-in 15.5 -> 25.4 s; locks 5 route twitch 5.1 -> 21.6 m, end foreign 13.6 -> 9.7 m). quick-remote e3389f1fc:
  builder0 277 / 0.
- **Rules added on the way (each from a laptop trace):** e3389f1fc: a column reaches at most one rank behind its rearmost
  squad (more = squeeze), and a group whose every squad stands within 30 m of the click keeps today's body (terminus 3
  route's first waypoint, 14-25 m from every squad: a column only shuffled them sideways; his own click is 39-45 m).
  e9e8397aa: a SHIFTED leg's column never reaches behind its squads' starts (locks 5 route: a rear squad's final place behind
  its own start, so it drove on through the waypoints and back; now main's final places, twitch 0-5 m); when the last
  squeeze still does not fit, the leftover squads join the last rank laid wider (never two squads one place).
  Known: on the probe's route cells the FIRST waypoint is a plain click, so it stacks per his rule (rear squads may back up
  one rank) even though the probe chains two more clicks the same tick; a running leg can't be re-laid from my paths.
- **Dev read 6 (e9e8397aa) was worse** on route cells (the shifted-leg room rule backfired); reverted to a dev switch.
- **Variant read (builder0 light, native, 62f25938f, street cells x 3801-3803, n 3; `g1-dev7-variants-builder0-62f25938f/`):**
  default column: deciding all pass (outside 41 -> 6, metres after leaving 4,974 -> 2,338, re-dealt 0), contacts 2,842 ->
  1,500; guards fail only crossing 3 route all-in 15.5 -> 25.4 s and locks 5 route end foreign 13.6 -> 10.5 m (line 10.6).
  `--group-legs=off` FAILS the deciding lines (outside 24, metres 2,913): shifted legs need the column. `--group-room=
  rearmost` passes deciding but fails 4 guards. Crossing 3 route's failure persists with legs off: it comes from the route's
  FIRST click (a plain click, stacked per his rule) which the probe chains past in the same tick.
- **G2 pieces built:** `--group-route-line=on` (dev switch, e4a3a5c13): the controls remember his current group route's
  clicks; a shifted leg's column and a gate's stack back along the route he clicked, not the navmesh drive (on Terminus the
  drive cut through the plaza's diagonal streets). Laptop, his east-street route `--probe-points=70/50+70/-30+25/-30`, 5
  squads, s3801, n 1: metres off the drawn path (`route_off_m`, his route's legs read mid-street) main 577, column 754,
  route line 315. 78cdfc71a (default under the switch): a shifted click within 2 s of his plain group click re-lays that
  first click as a waypoint (`Element.retarget` to its gate place); laptop crossing 3 route all-in ~25 -> ~21 s, twitch 0.
- **Settle (C38.3) asked whether O7 v2 changes the deploy heading:** no; the column changes only each squad's place; `lay`
  stays round 34's B8 approach. Settle's deploy-fit (stream/settle ac36add58, OFF) sits on top; agreed, no new key.

### Bars (filed here before any judged number; the orchestrator records them on main)
- **Bar G3 PLACE_CLEAR (orders, R38.15; filed 2026-10-22 late evening, before any G3 number on the judged seeds; code
  258c199c6, `--place-clear=on`, OFF).** What he would see: select all and click; no squad parks on top of another one, and
  every squad gets in. The squads stay where he clicked, not 60 m back down the road.
  **Tree:** a hash at or after 527d62cd2 (G3 v2 + a moved place keeps its own vehicles: untangle swaps squads whole where
  place_clear moved a place) whose full check is green, with main merged; switch OFF by default. G1 is OFF in both arms.
  **Probe:** `make native orders-probe`, arms `main:` v `g3:--place-clear=on`, on builder0's light lane at J <= 4, with FRESH
  seeds 4101-4112 (n 12 a cell; amended before any number from 4011-4022, which collided with settle's S2 v3 4001-4024; R38 seed blocks taken: 3861-3914, 3921-3944, 3951-3962, 4001-4024, 4101-4112, 4801-4808, 4901-4908). Cells: the 12 street cells (locks / crossing / terminus x 3 / 5 squads x click / route),
  his click (`terminus_his`, 3 / 5 squads), and yard_open (3 / 5 x click / route).
  **Judge:** `tests/control/orders_judge.py g3` (all cells).
  **Counter:** places_cleared > 0.
  **Deciding** (all cells, summed; AMENDED before any judged number, after dev read 1 on dev seeds 3801-3803: main parks
  neighbouring squads 4-6 m apart as normal, so 68 of 216 main rows were under the old 8 m end-foreign line):
  1. pairs of squads in a run whose places (`anchor`) are laid closer than 12 m, half a herringbone's short side: arm
     <= 25 % of base (dev read 1, main: 14 such pairs, places 2.8-6.3 m apart);
  2. never-in squads: arm <= base. This is now a guard; the defect is too rare on main to decide on.
  AMENDED 527d62cd2, before any judged number (dev read 2): line 1 skips a pair whose two squads' anchors are read from
  the same element (the probe row's `anchor_element`). Two squads in one element read one place, 0.0 m apart, and drive
  as one body; all 5 g3 pairs left in dev read 2 were such, and so were main's his-click pairs.
  Code amended too, before any number (v2, see Status): no two places closer than their short sides; a place moves aside
  first, then back, at most 40 m.
  **Offset guards** (R38.15: the s3866 lab stepped squads 4/5 back ~60 m):
  1. per cell, the median of the worst place-to-click distance (`worst_offset_m`) <= base + 15 m;
  2. squad rows whose place is > 40 m further from the click than the same seed and squad on main <= 5 % of all squad rows;
  3. no place > 100 m further back than main's.
  **Other guards:** every R36.6 guard per cell (all-in median <= base x 1.2 + 3 s; no more never-in; worst twitch median
  <= base + 3 m; end foreign min median >= base - 3 m; crossed no higher); friendly contacts <= base x 1.1 + 5;
  yard_open no worse on any of these.
  **Reported:** places_cleared per cell, the offset distribution, and route_left_m.
  **Plus:** paired top-down shots of crossing 5 click (main v g3), looked at. A pass ships ON.
- **Bar G1 v3 (orders, R38.12; filed 2026-10-22 evening, before any v3 judged number; code 0e169432f, `--group-lay=column`
  OFF).** Changes from v2: today's body judged at the click's width only (the yard_open container case); the 2 s first-click
  re-lay only where the column moved some squad's place > 40 m (about a rank), and (f2a94b6cc, amended before any number)
  the re-laid first click goes back to the places today's body gave it, out of the gate (v2's judged yard_open misses s3889,
  s3891, s3886 re-run on the laptop: byte-identical to main). **Same cells, counter, deciding lines,
  thresholds and guards as the amended Bar G1** (deciding over click cells + his click; re-dealt 0 over all cells; every
  R36.6 guard + contacts over all 14 cells; yard_open every row identical), **FRESH seeds 3951-3962** (amended before any number: settle's S2 re-read uses 3903-3914), builder0 light lane J
  <= 4, judge `orders_judge.py g1`, paired top-down shots of his click (main v column, looked at). **His-click twitch guard:
  v3 does not change the lay at his click, so it cannot pass that guard on its own: the judged read WAITS for settle's
  deploy latch to ship ON on main and runs on top of it** (both arms on a tree with main merged at that checkpoint; latch-on
  is the base). Until then, dev reads only. A pass ships ON.
- **Bar G1 GROUP_LAY=column v2 (orders, round 38; filed 2026-10-22 ~10:15 PDT, before any judged number; dev reads above
  are on dev seeds 3801-3803 only).** What he would see: select all, click a street: every squad lands in that street,
  stacked back along it, nearest in front, each with its own vehicles; on open ground nothing changes.
  **Tree:** a hash whose builder0 full check is green, switch OFF by default. **Probe:** `make native orders-probe`, arms
  `main:` v `column:--group-lay=column`, builder0, FRESH seeds 3881-3892 (n 12 a cell). Cells: the 12 street cells (locks /
  crossing / terminus x 3 / 5 squads x click / route); his click as its own cells (terminus `--probe-click=-29.3/85.8`, 3 and
  5 squads, click; relabelled `terminus_his`); the open-ground cell yard_open (3 / 5 x click / route). **Judge:**
  `tests/control/orders_judge.py g1` (street + his rows; yard_open rows as the 5th argument).
  **Counter:** columns_laid > 0. **Deciding** (street + his cells): places outside the click's corridor, arm <= 25 % of
  base; metres driven outside the corridor after the crew was once inside it (`route_left_m`), arm <= 50 % of base; squads
  with crews re-dealt, arm 0. **Guards:** R36.6's per cell (all-in median <= base x 1.2 + 3 s; no more never-in; worst
  twitch median <= base + 3 m; end foreign min median >= base - 3 m; crossed no higher); friendly contacts (probe) <= base
  x 1.1 + 5; yard_open: every squad row identical. **Reported:** route_out_m (incl. the drive in), parked re-deals, bodies
  kept, gate columns. **Plus:** paired top-down shots of his click, main v column, looked at, for him. A pass ships ON.
  **AMENDED 2026-10-22 ~16:30 PDT, before any judged number (dev seeds 3801-3803 only so far):** the column on shifted legs
  and gates moves to G2 (`--group-legs=on`, OFF): ten dev reads showed every route-leg rule moving the route cells' guards
  around (the probe chains three clicks in one tick; five squads stack deeper than a 120 m route), and his complaint was a
  plain click. G1 = the plain-click column + squads whole on every group move + the 2 s first-click re-lay (a shifted click
  right after a column click turns it into a waypoint; it keeps G1 from hurting routes). **Deciding lines now over the 6
  click cells + his click cells** (thresholds unchanged: places outside <= 25 % of base, metres after leaving <= 50 %,
  re-dealt 0 over ALL cells). **Every guard still over all 14 cells, route cells included**, and yard_open identical.
  Known before judging: his click cells are effectively n 1 (`--probe-click` disables the seed's jitter; all seeds replay one
  run); their one twitch (3 squads, 11.4 m) is the halt flipping herringbone -> coil after the deploy (settle traced it;
  their `--deploy-latch=on` removes it, in settle's series on builder2).

