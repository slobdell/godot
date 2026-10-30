# Stream: orders (his group click: the veto ships ON, nobody across the drop or sent back, every other click unchanged; then a tighter file)

> Read `_agents/orchestration.md` (the worker contract; **lessons 339, 345, 348**), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 46** (C46.1-C46.8, R46.1, R46.2), R45.31 and Bar G2 in *Bars (round 45)*, your last brief
> `streams/archive/round45/orders.md` (FINAL REPORT: what failed on the streets and why; the round-46 plan you wrote), and
> `game_design.md` *His answers at round 46's prep*. **You own:** `game/control/**` (incl. `selection_squads.gd`, `group_formation.gd`,
> `rts_controls.gd`) EXCEPT engage's grant in `order_executor.gd` (crew orders) and native's C++ seams (the GDScript bodies stay yours);
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`; GRANT `game/ai/planner/**` for a group
> order's departure order and route spread only. **Model:** Fable. **Machine:** builder3 (checks, series; never builder2 for a bar).
> **Seeds:** 11801-11848 (Bar V1), 11849-11896 (Bar V2 / reserve). Dev 7001-7006 (never a bar).

## The lead's direction

2026-10-29 (Gorge, verbatim): "I selected 3 squads and had them all go to a target waypoint that was south of the bridge. What
waypoint selection algorithm chose a far away waypoint that was north of the bridge for one of the squads. This was precisely the
behavior I had asked to fix."

2026-10-30, his picks (R46.1, R46.2): **the veto-only guard, ON** ("ONLY re-places a squad when it would land across a drop/water or
behind where it started — every other click, all streets included, stays exactly as today"), and **a tighter group file** ("Squads
pack closer (roughly half the length): the whole group is at your click sooner and fights together, at the cost of a bit more bumping
in tight spots").

He asked for the group click in rounds 37, 41, 43, 44 and 45 and **has never played a fix**. Lesson 348: the smallest ON change is a
veto, not a new layout.

## Where things stand (main at launch: see HANDOFF; code 96f199c45 GREEN builder3 3470/0)

- **His case:** Gorge seed 91711 recording `references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl`; one click at (-43.2, 53.2):
  today's `ranks` lay sends Hunters to (-76.0, 101.0) (48 m back, behind his start z 90) and Wrenches to (-10.4, 5.4) (across the drop).
- **G2** (the fitted file, ranks straight back from the click) is on branch `round45/orders` (2b95f6f27, default ON there), not on
  main. Its bar passed every line on his case (D1-D6, D5b 24/24) and failed the streets (places outside the corridor 7 -> 33, Terminus
  5-click all-in 11.7 -> 47.4 s): `references/round45/orders/bar-g2-builder3-03d1ddbc5/`. G2's `guard_failures` is exactly the veto's
  test; its re-deal is the seat source.
- **Spacing:** coil ranks are 33-50 m deep, so a 3-4 squad file is 66-150 m long. **The fit's ~60 path queries at his click cost 4.9 ms**
  (native's N1 this round moves them to C++; give native the seam early).
- Tools: `tests/control/orders_geometry_table.py` / `orders_geometry_judge.py`, `make orders-geometry`, `tests/control/orders_bar.sh`,
  `tests/orders_probe_group.gd`, `make replay-match`.

## Backlog (in order)

1. **V1 the veto-only guard, ON by default, `--group-veto=off` the escape (R46.1).** On today's default lay: for each squad's place,
   run G2's failure test (across a drop / water / neck from the click: ground path much longer than the line or the line crosses a
   pit; or > 10 m behind its own start along the approach). Only a failing place is re-dealt, to the nearest free seat on the click's
   side; **every passing place is byte-identical to today**, and a click with no failing place is byte-identical as a whole. Symmetric
   (C46.6). Tests first: his Gorge geometry (unit), a click beside a lock, a click on a bridge deck, a Terminus street click whose
   output must equal today's exactly.
2. **V2 Bar V1**, filed in `workstreams.md` *Bars (round 46)* BEFORE any number on 11801-11848, NARROW: deciding lines = his failure
   (places across a gap from the click: 0; places behind the start > 10 m: 0; D5b his exact Gorge click), on a corpus with Gorge (his
   click and clicks either side of each gap), Locks (his round-43 clicks), Crossing, Terminus. Guards: **part B's street lines as a
   byte-identity check** (every street click's places equal to base: by construction, so any difference is a bug), all-in / never-in
   on the cells the veto touched (<= base x 1.2 + 3 s), friendly contacts, engage's authority probe and manoeuvre's one-squad arrival
   (C46.3). Native's twin if it touches a C++ seam (C46.4). Ships ON the minute it passes; message the orchestrator the green hash.
3. **V3 his acceptance read:** the shipped tree on his Gorge replay and his two round-43 Locks clicks; top-down shots before/after,
   looked at; a table in Status.
4. **V4 the tighter file (R46.2), its own switch `--group-pack`, ON when its bar passes.** About half today's length: a 3-squad file
   <= ~50 m, 4 squads <= ~75 m (shorter rank depth between squads, not a new layout). Bar V2 on 11849-11896: deciding = file length
   and all-in time; guards = friendly contacts (<= base x 1.25 + 5: the "bit more bumping" he accepted is bounded), never-in, wedged
   seconds, the fight probe, the street lines. On top of V1.
5. **V5 the street lay (G2's file along the road)** behind `--group-guard=on`: rear ranks along the street corridor (the column's
   `_walk_back`), what part B wants. Dev reads only this round unless V1-V4 are done.
6. **Stretch:** more than two abreast on a wide yard (a feel question for him in player terms, one recommendation); the departure
   order (nearest leaves first).

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote` to iterate; `make
replay-match RECORDING=...`; the geometry probe and judge; `make control-playtest`; top-down shots at his click, looked at. Every number
with its commit, machine, workload and n.

## Don't touch

`order_executor.gd`'s crew-order branches (engage's grant), `game/tactics/**` (engage / manoeuvre), movement / traffic (manoeuvre),
`native/**`, `game/camera/**`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch (both questions answered 2026-10-30). If Bar V1 fails, write in player terms what he would see ON v OFF and message
the orchestrator the same hour (C46.2): it goes to him the same day.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### NOW (2026-10-30 ~07:00 PDT): BAR V1 PASSES; merge 12bd0c68f; V2 next

- **VERDICT Bar V1: PASS** (builder3, frozen **12bd0c68f** = GREEN builder3 `make check exited 0`, 3483 passed / 0 failed; 11801-11848;
  every part try 1, 3672 runs). D1 across 0 (base 303); D2 sent back 0 (base 126); D5b his exact Gorge click 24/24; I1 the OFF
  path == main 1224/1224; I2 0 differ (914 untouched, 310 changed); G1 PASS on 13 touched cells; B- no street run failing. Terminus
  untouched (0 of 144 geometry runs, 0 street runs). Evidence: `references/round46/orders/bar-v1-builder3-12bd0c68f/`.
- **Merge = 12bd0c68f alone** (told to the orchestrator; the veto ON by default, `--group-veto=off` the escape; G2 OFF behind
  `--group-guard=on`). Reported, not a line (the orchestrator's ruling before the verdict): Crossing route first-waypoint re-deals
  (22 of 24 3-squad routes), paired no harm (outside 1.23 v 1.23, metres outside 67.2 v 75.8, all-in 17.1 v 18.6 s).
- **Next: V2 (the tighter file).** Bar V2 filed (below, recorded on main 0af02e7ff). Its freeze is built on main AFTER V1's merge
  (main has engage's L1c, which changes fights: part C). Named risk: L1b his click 49.1 m v <= 50 m.
- Side trees removed (godot-orders-main, godot-orders-v1; laptop + builder3 + builder0 folders).

### V3 HIS ACCEPTANCE READ (the shipped candidate 12bd0c68f's places; laptop flightdeck, native on)

**His Gorge click** (recording `references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl`, seed 91711, one click at
(-43.2, 53.2) for Hunters + Spears + Wrenches):

| | Hunters (start -14.6, 92.6) | Spears (14.6, 92.6) | Wrenches (43.9, 93.6) | all in (probe, 7001) |
|---|---|---|---|---|
| today / `--group-veto=off` = his match | (-76.0, 101.0): 61 m west, north of their spawn row | his click | (-10.4, 5.4): through the neck, across the drop | 26.1 s |
| **veto ON (default)** | (-16.2, 71.7): 33 m behind his click | his click (today's) | (10.8, 90.3): 66 m behind | **8.2 s** |

- `make replay-match` of his match, 30 s, every crew (laptop): veto OFF = his match exactly (DIVERGENCE 20/20 crews within 3 m,
  PASS); veto ON: his order row at tick 0 carries exactly the table's places (it diverges from his match from tick 1, as meant).
- **Top-down shots, looked at** (`references/round46/orders/v3-gorge-shots/`): OFF one squad's crews beyond the pit row toward the
  enemy; ON every crew on his side below the pits, one group back from his click at the west neck, on open ground.
- **His click's own cost:** 8.8-9.2 ms ON v 10.4 ms OFF (laptop, native on, n 1 each; R46.13: no port).
- **His Locks clicks** (round 43, `tests/test_control_his_locks_click.gd`'s inferred clicks (-35, 97) and (-61, 59)): in the geometry
  probe with his north-edge row (`his` starts), (-61, 59) has no failing place (today's exactly); (-35, 97) had one squad sent back
  22 m south; the veto re-deals it to (-27.1, 96.2) beside his click (laptop, 7003: all-in 4.6 v 5.3 s, contacts 7 v 6). Both
  are Bar V1 cells (fixed clicks), read on 24 fresh seeds in the series.

### EARLIER (2026-10-30 ~04:45 PDT)

- **FROZEN 12bd0c68f GREEN builder3: `make check exited 0`, 3483 passed / 0 failed** (`~/orders-r46/check-v1-12bd0c68f.log`).
  **Bar V1's series RUNNING on builder3 since 04:35** (`~/orders-r46/bar-v1/run.log`, BAR_DONE ends it; verdict in
  `verdict.txt`). Dev read 4 on 12bd0c68f (builder0, 7004 / 7006, n 1 a cell): VERDICT PASS on every line. 12bd0c68f = 6acba040e +
  a seat is taken within the LARGER of the two squads' half-widths (dev reads 1-3: Locks -35/97 contacts 16 v 6 every seed).
- **Earlier candidate f77e16230 GREEN builder3: `make check exited 0`, 3481 passed / 0 failed.** Since then, code only (lines
  unchanged, amendment 0, each told to the orchestrator):
  - 40d4b9dec: the base-edge "sent back" also needs the place > 5 m farther from his click (dev read 2, Crossing 5-squad click:
    two column-tail holds 1.8 m farther were re-dealt, one outside the street corridor).
  - f6bb52518: the seats are today's ranks (`rank_slots_for`, pure geometry) asked of the ground lazily, not G2's guard_lay:
    **his failing click cost 45-66 ms on the laptop (native on) v 10 ms with the veto off; now 8.8-9.2 ms v 10.4 ms** (native's
    ask, R46.13: no port).
  - 6acba040e: the seats in FILE (one abreast): two abreast put the Hunters inside the Spears' halt at the neck and the Spears
    never settled (laptop, his exact click, 7001). Now: Spears on his click (today's), Hunters (-16.2, 71.7), Wrenches (10.8,
    90.3); **all in 8.2 s v today's 26.1 s**; top-down shot looked at (one group behind his click on open ground, every crew on
    his side).
- **Dev read 2 (builder0, f77e16230, 7002 / 7004, n 1 a cell): every deciding line PASS** (D1 0 v base 13, D2 0 v base 6, D5b),
  I1 51/51, I2; G1 / B- misses on single runs (Locks -35/97 contacts 16 v 6; the Crossing column-tail case, fixed in 40d4b9dec).
- **V4 (OFF, `--group-pack=on`):** the front rank keeps today's step (at his neck a packed second rank stood in the front
  squad's halt), the ranks behind it halve, floored at GAP_M. His Gorge file 65.5 -> 49.1 m (laptop lab). **Named risk (Bar V2
  L1b, his click <= 50 m): 49.1 m is on the edge; not amended after numbers.** At 7001 the Spears' crews still string into the
  neck in one packed run (never-in guard's risk).

### REPORT (2026-10-30 ~02:30 PDT, Fable, worktree `godot-orders`, branch `stream/orders`)

- **Plan (in order):** V1 the veto (built, 47cae3725) -> Bar V1 filed (below) -> a dev read of the bar's runner on 7001-7002 (the
  pipeline, not a number for the bar) -> freeze on a green check -> the series on 11801-11848 (builder3) -> ship ON / message the
  orchestrator -> V3 his acceptance read (his Gorge replay, his two round-43 Locks clicks, top-down shots) -> V4 the tighter file
  (`--group-pack`) and Bar V2 -> V5 the street lay (dev reads only) -> stretch.
- **V1 BUILT, ON by default (`--group-veto=off` / `GROUP_VETO=off` the escape).** `SelectionSquads.veto_failures(anchors, blocks,
  click, approach, forward, data)` -> failing indices; `veto_refuses(at, centre, front, came, forward)`; `veto_front(click, came)`;
  `veto_redeal(...)`; `RtsControls._veto` the last pass on a plain group click (>= 2 squads, not a shifted leg, guard OFF). A place
  fails when (a) across a gap from his click (G2's `guard_across_gap`: water / pit / deck mouth / wet leg / through a neck), read from
  the first dry, non-deck point back along the approach when he clicked on water or a deck; or (b) SENT BACK: farther from his click
  than the squad stands AND > 10 m behind its start along the approach OR > 5 m behind it toward its own base edge (a click toward
  the enemy). Only failing places are re-dealt, nearest squad first, to the free seat of G2's fitted body (`guard_lay`, its fit read
  at the click) nearest his click that passes the same test; none -> the squad holds where it stands. No failing place -> no scan,
  no path query, the anchors returned as they came.
- **Decision (mine): (b)'s "toward its own base edge" reading.** On the brief's literal test (> 10 m behind along the approach) his
  Gorge Hunters PASS: their place (-76.0, 101.0) is level with his click along the diagonal approach, 61 m west and 8.4 m north of
  their start (-14.6, 92.6), 9.3 m farther from his click. He picked "ONLY re-places a squad when it would land across a drop/water or
  behind where it started": north of their spawn row is behind where they started. Threshold 5 m (about half a squad's depth), only
  on a click toward the enemy and only when the place is farther from his click (a squad past his click called back is not "sent back").
- **His Gorge click (laptop lab, 47cae3725, his squads at his recorded tick-0 starts, real Gorge navmesh):** today Spears on the click,
  Hunters (-76.0, 101.0), Wrenches (-10.4, 5.4) across the drop; veto ON: Spears (-43.2, 53.2) exactly today's, Hunters (-16.2, 71.7)
  33 m behind, Wrenches (10.8, 90.3) 66 m behind: one file along his approach, every place on his side.
- **Tests (laptop, 47cae3725): 10 passed / 0 failed** over `test_control_group_veto` (Terminus his round-37 click and an east-street
  click byte-identical ON v OFF; Locks beside the lock identical; on the swing bridge's deck today sends the Spears to the south bank
  (-71.5, -20.5) and the veto keeps them north (-60.9, 31.1)), `test_control_his_gorge_click` (5), `test_control_guard_locks` (2).
  `make quick-remote` on a9fb6c0ef (builder3): 34 passed / 0 failed, lint, smoke, `quick passed`.
- **G2's code is merged OFF** (pair/native-g2-final: G2's freeze + native's gate_width_edge_on swap); `--group-guard=on` lays it.
- **Two instrument findings (round 45's Bar G2, told to the orchestrator):** (1) `orders_probe_geometry.gd`'s ORDERS_GEOMETRY line
  prints on the order's tick BEFORE the probe reads the anchors, so its per-squad `across_gap` was always false (G2's D1 "0 across"
  read nothing); V1's reads are on the squad rows (`veto_fail`, `veto_across`). (2) G2's his3 cell's `--probe-stand` was read by no
  code and starts mode `recorded` matched no case: D5b's squads stood at the army's centre. Implemented: dev read 7001 (laptop,
  47cae3725, n 1) base = his recorded places exactly; veto: Wrenches on his side, all-in 26.1 -> 17.6 s (a dev read, not the bar).
- **Requests to other streams:** native: twin of `veto_failures` optional (not a V1 gate; R46.9).
- **Questions for the lead (stretch, not blocking; player terms, one recommendation):**
  1. *Wide open ground, four or five squads, one click:* today they form up three side by side with the rest in a second row
     behind (about 160 m wide for three of your 44 m gang squads). Would you rather they spread four or five side by side when the
     ground is wide enough? **Recommended: keep three side by side.** Four abreast is ~220 m wide: on a phone or the laptop the
     ends of the line leave the screen, and the outer squads reach the click last because they drive the long way round.

### Bar V2 THE TIGHTER FILE (orders, round 46; filed here BEFORE any number on 11849-11896; dev reads on 7001-7006 only)

**What he would see:** with two or more squads selected and one click, the squads behind the first stand closer: the group's file
is about half as long behind the front squad (his Gorge click: 65.5 -> 50.8 m), so the whole group is at his click sooner and
fights together; a bit more bumping in tight spots. The front squad keeps today's room at his click (at a neck a packed second
rank stood in its halt). Nothing else changes: same places across, same order, the veto as shipped.
- **Arms:** `base:` (the frozen tree's default: V1's veto ON, today's file) v `pack:--group-pack=on`, on a frozen tree whose check
  is green (`make remote T=check`), V1 merged.
- **Runner:** `tests/control/orders_v2_bar.sh <frozen tree> "11849 ... 11872" "11873 ... 11896" "11873 ... 11884" <out> 8`;
  judge `tests/control/orders_v2_judge.py <out>` (its docstring is the lines below, verbatim in code). Parts: A geometry (Bar V1's
  corpus: 24 cells + the 10 fixed clicks + his exact Gorge click), seeds 11849-11872; B streets (locks / crossing / terminus /
  yard_open x 3 / 5 x click / route), seeds 11873-11896; C fight (terminus / locks, 5 squads, click, `--probe-fight=on
  --probe-budget=3000`), seeds 11873-11884.
- **Deciding:** **L1** 4-squad file length (the farthest place from his click among the squads it moves) pooled median over part
  A's cells <= 75 m AND <= 0.7 x base's; **L1b** his exact Gorge click median <= 50 m; **L2** all-in sooner or identical: over A + B
  runs where both arms got every squad in, paired, pack mean <= base mean (strictly sooner reported).
- **Guards:** friendly contacts a run (A + B pooled) <= base x 1.25 + 5 (the "bit more bumping" he accepted, bounded); never-in
  runs <= base x 1.2 + 1; wedged crew-seconds a run (the probe's `wedged_s`, Movement.wedged), paired, <= base + 2 se; part B's
  street lines (places outside the corridor, metres driven outside it, all-in), paired, <= base + 2 se; the fight (part C): green
  lost <= base + 2 se, green kills >= base - 2 se; V1 under the pack: places across a gap 0 and sent back 0.
- **C46.4:** the pack changes the lay's step only (no drive, no brain, no new C++ seam): no native twin required.
- **Ship rule:** ON (`GROUP_PACK` default flipped, `--group-pack=off` the escape) if every line passes; any FAIL -> what he would see
  ON v OFF in player terms to the orchestrator the same hour (C46.2).

### Bar V1 THE VETO-ONLY GROUP GUARD (orders, round 46; filed here BEFORE any number on 11801-11848; dev reads on 7001-7006 only)

**What he would see:** he selects two or more squads and clicks once. Every squad goes where today's game sends it, EXCEPT a squad
today's game would send across a drop, water or a neck from his click, or back behind where it started: that squad takes the free
spot nearest his click in a file on his side (or holds where it stands if the ground has none). His Gorge click: Spears on the click
as today, Hunters 33 m behind it, Wrenches 66 m behind, nobody across the drop, nobody sent north of his spawn row. On streets and
every other click: exactly today's places.
- **Arms:** `base:--group-veto=off` (today's lay) v `veto:` (the tree's default, the veto ON) on the frozen tree; `main:` on main's
  tree (7189e3ff3, code cb1014bed; instruments only: mk/command.mk's fixed-click folders, the his3 army / starts JSON and the
  recorded-starts patch to the geometry probe, no game file) for I1.
- **Tree:** a frozen detached worktree at the commit named green here (`make remote T=check`, builder3), or a docs-only descendant.
- **Runner:** `tests/control/orders_v1_bar.sh <frozen tree> <main tree> "11801 ... 11824" "11825 ... 11848" <out> 8`, builder3 (no
  Spot); judge `tests/control/orders_v1_judge.py <out>` (its docstring is the lines below, verbatim in code).
- **Part A, geometry (DECIDING), seeds 11801-11824, n 24 a cell:** `make orders-geometry` gorge / locks / crossing / terminus x his /
  along / across x reach 20 / 80 (24 cells), plus 10 fixed clicks: his Gorge click from his spawn rows (`gorge:spawn:-43.2/53.2`) and
  a click either side of each neck (`gorge:across:-40/58`, `-40/30`, `40/58`, `40/30`); Locks `his:-62/50` (round 44), his round-43
  clicks `his:-35/97` and `his:-61/59`, beside the lock `his:-22/13`, on the west swing bridge's deck `his:-92/0`; plus his EXACT
  Gorge click with his three squads at their recorded tick-0 starts (`gorge:recorded:-43.2/53.2`, his3 army, `--probe-stand`).
- **Part B, streets (GUARD), seeds 11825-11848, n 24 a cell:** `make orders-probe` locks / crossing / terminus / yard_open x 3 / 5
  squads x click / route (16 cells).
- **Deciding lines (veto arm, every geometry run; base printed beside):**
  - **D1** places across a gap from the click (row `veto_across`) = 0.
  - **D2** places sent back (row `veto_fail` and not `veto_across`) = 0.
  - **D5b** his exact Gorge click: every place on his side of the drop (z > 50) and passing the veto in 24 of 24 runs.
- **Guards:**
  - **I1 the default OFF path is main's:** every squad's place in `base` equals `main`'s (0.1 m, the probe's print) in every run of
    both parts, and both arms hold the same runs. (G2's merged code, OFF, never leaks into the default path; R46.9.)
  - **I2 byte-identity:** in `veto`, every squad whose `base` place passes the veto has exactly its base place, every run of both
    parts (the streets by construction: any difference is a bug).
  - **G1 on the touched cells** (a geometry cell, or a streets map x squads x route, where some base run has a failing place), each:
    all-in median (runs where every squad arrived) <= base x 1.2 + 3 s; never-in runs <= base x 1.2 + 1; friendly contacts a run
    (mean) <= base x 1.2 + 5.
  - **B- (R46.10 b) part B's street lines on the TOUCHED street runs** (base has a failing place), paired run by run: places outside
    the click's corridor a run (`anchor_outside`), metres driven outside it a run (`route_left_m`), all-in (runs where both arms got
    every squad in): veto mean <= base mean + 2 se of the paired differences (n < 2: veto <= base).
  - **Reported (R46.10 a):** per part and arena (the streets per map x squads x route: Terminus / Crossing / Locks separately), base
    runs with a failing place / veto runs the veto re-dealt on / runs. If Terminus 5-squad clicks fail en masse in the dev read, the
    orchestrator hears it before the freeze.
  - **C46.3, by construction (said, not run):** the veto reads only group clicks of >= 2 squads (engage's crew orders and authority
    probe untouched; manoeuvre's one-squad arrival never enters it); its re-deal changes a place, never the drive.
- **C46.4:** the veto touches neither the drive nor the brain and adds no C++ seam: no native twin required to ship (R46.9); native's
  optional twin of `veto_failures` is output-identical only.
- **Ship rule:** ON (it is the default in the frozen tree) if D1, D2, D5b, I1, I2, G1 and the three B- lines all pass; any FAIL -> the stream writes
  what he would see ON v OFF in player terms and messages the orchestrator the same hour (C46.2).
