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
- **Settle (C38.3) asked whether O7 v2 changes the deploy heading:** no; the column changes only each squad's place; `lay`
  stays round 34's B8 approach. Settle's deploy-fit (stream/settle ac36add58, OFF) sits on top; agreed, no new key.

### Bars (filed here before any judged number; the orchestrator records them on main)
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

