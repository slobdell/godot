# Stream: orders (five squads, one click: they go as a body, not 400 m abreast)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 19 direction* (item 2: two
> squads, one click) and *Round 20, afternoon* / *Round 20, evening* (the ±116 m spread in his recordings),
> `_agents/workstreams.md` *Round 21* (C21.1, C21.2, C21.4), and your round-19 final report
> (`streams/archive/round19/orders.md` Status: O3's row, `SelectionSquads.row`, the probe `make two-squads-playtest`,
> the known issues). You own `game/control/**`, `game/ui/formation_picker.gd`, `selection_panel.gd`,
> `command_icons.gd`, `tactical_map.gd`, `radar.gd`, `task_preview.gd`, `control_hints.gd`,
> `game/theme/fx/order_feedback.gd`, `tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_tactical_map.gd`,
> `tests/test_element_preview.gd`, `tests/test_touch.gd`, `mk/command.mk`. `game/tactics/**` is brains' (read it; a
> change is a request).

## The lead's direction

Round 19 (2026-10-05), the rule your row answers: *"I selected 2 squads and right clicked a point on the map - the
resultant indicator dots for all the units was all over the map, and a bunch of vehicles just basically ran off to the
middle of the map."* Round 20 (2026-10-06), playing 25 Rat Rods in five squads: *"they all just spread out and drove
away"* (mostly the bait drill, brains' fix; the rest is your row), and after the close, *"A lot of vehicles didn't
actually drive toward the target they just circled around"* (brains' pursuit; your row sent Bravo_4 to the wall at
x = −96 first). Nothing new from him for your paths beyond that; this is what he sees every time he moves his whole
army with one click.

## Where things stand (read at `366bef66`)

- **The row scales with the squads.** `RtsControls._order_squads` lays `SelectionSquads.row` for any several-squad
  `move`/`attack_move`/task with a `to`: each squad's frontage (`_squad_width`: the chosen shape, or a LINE when AUTO,
  at the element's pitch) plus `GAP_M` 14 m. A gang vee of five at 18 m pitch is ≈ 72 m; five squads need ≈ 400 m;
  `Orders.clamp_to_arena` then pins the outer squads at ±116 m on foundry (his recordings
  `2026-10-06T14-59-04.jsonl`, transit points ±60/±68/±116 m, and `2026-10-06T18-38-40.jsonl`, tick 474). The outer
  squads drive 100 m sideways before they turn toward the click, and one crew was `blocked/terrain` against the wall.
- **A named-target `attack` lays no row** (`extra` has `target`, no `to`): every squad gets the target. That path is
  brains' pursuit (C21.1); nothing to change here except not to break it.
- The row's two-squad case is his approved behaviour (round 19: side by side, each in its own shape, never one
  element). Keep it for two.
- Known issues from round 19: a slot grounded against the Parade bay's containers; `control_scale` click-to-order
  timing unjudged (needs an idle builder0); the probe's real-time cases want a 720 s timeout.

## Backlog (in order)

**O1. Cap the row: a body of squads, not a line across the map (CP1).** Decide and record the design; the
recommendation: at most THREE squads abreast (two for two, as today), further squads in a second rank one formation
depth plus `GAP_M` behind the first, centred, in the same left-to-right order; the total frontage never exceeds a cap
(say 200 m, a constant with a reason) and never needs the clamp. Alternatives to measure against it: shrink the
per-squad width to the shape's REAL frontage when the squad's chosen shape is a column or wedge (a vee's rear is
wider than its lead; today AUTO is priced as a line); or a fixed gap scaled down with the count. Pure first:
`SelectionSquads.row` (or a sibling `ranks`) with tests for 2, 3, 5 squads, a drawn facing, the clamp never reached on
foundry/parade/yard; then the controls path; then the dots (`task_preview`, order feedback) draw the ranks. The
pre-registration: the thirteen lines UNMOVED (CPU-v-CPU never issues through `_order_squads`); if one moves, stop and
message the orchestrator (C21.2). **Merged ALONE as CP1**; brains merges main after it.

**O2. The five-squad case in the probe (C21.4).** `make two-squads-playtest` gains a case: five gang squads of five,
one attack-move 150 m across foundry and parade; it reports each squad's worst SIDEWAYS detour (distance from the
straight line click-to-squad-centre) in the first 10 s and the time the last squad arrives, before/after O1, three
repeats, builder0. Brains reads the numbers; `tests/test_control_two_squads.gd` pins the five-squad layout.

**O3. The slot grounded against the Parade bay's containers** (your round-19 known issue): reproduce it with the
probe, name the mechanism (a station laid inside a container's footprint and ground-snapped to its face, or the
clamp), fix it in your paths or write the request to brains with the seed and the slot.

**Stretch (a).** The probe's real-time cases under a 720 s timeout (and `TIMEOUT` documented in `mk/command.mk`).
**Stretch (b).** The dots for several squads: the ranks drawn as the squads will stand, not as one row (if O1 did not
already do it). **Stretch (c).** Shift+N: today ADDS to group N (StarCraft's meaning), decided in round 19 and kept;
a one-line hint in `control_hints.gd` the first time he does it, if cheap.

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism UNMOVED as pre-registered.
- `make two-squads-playtest` before and after O1 (the numbers in Status with commit + machine + repeats).
- Play it: `make garage` → Road Gangs → CLEAR → tap the Rat Rod 25 times → FIGHT; select all (Ctrl+A or drag), V, click
  across the floor: the five squads set off toward the click as a body; nobody drives to a wall first. Then with two
  squads: unchanged from round 19. Screenshots at desktop and phone aspect of the dots the moment after the click, and
  look at them.
- Every number: commit, machine, workload, sample size (C16.3).

## Don't touch

`game/tactics/**`, `game/ai/**` (brains; a request) · `game/theme/**` (airship's and nobody's) · `game/ui/**` except
your files · `game/garage/**`, `game/units/**`, `game/match/**`, `game/modes/**`, `game/camera/**` (nobody) ·
`arenas/**`, `game/arena/**` · `mk/core.mk`, `tests/baselines/**`.

## Waiting on the lead

- Nothing blocks you. If three abreast feels wrong to him he will say so after playing; build the recommendation.

## Status

**GREEN, merge here: `11a90600`** (builder0, `make check exited 0`, 2185 passed 0 failed, 23 targets ALL JUDGED,
thirteen lines unmoved, determinism `762a0576f944f5b7`; main `ace70c1b` merged at `4bfba462`). Above it, unchecked:
`8d9f7831` (docs, traces) and `8be7d470` (probe only: arrival = the squad centre within 12 m of its task anchor).
Waiting: brains' R1 and R2 on main → merge main → the series on R2 + O3's close row + `make check`.

_Worker, 2026-10-06 night. Started from `0c243e8a`; baseline `make remote T=check` there: builder0, `make check exited
0`, 2166 passed 0 failed, 23 targets ALL JUDGED._

**Plan:** (1) O2's probe case first, committed alone, run on the unchanged code for the "before" numbers; (2) O1 pure
(`SelectionSquads.ranks`, `rank_sizes`, `fit_inside`) with tests, then the controls path; (3) `make check` + the
"after" series; (4) frames of the dots at desktop and phone aspect; (5) CP1 to the orchestrator; (6) O3 with the
probe; (7) stretch.

**O1 design (decided; one-line reasons):**
- Two squads: round 19's row, unchanged (his approved case), even when two chosen shapes are wider than a rank.
- Three or more: the row while it fits ONE rank (at most `MAX_ABREAST` = 3 squads AND at most `MAX_FRONTAGE_M` = 200 m);
  else the fewest even ranks that fit, the front one fullest (5 = 3 + 2 when three fit, else 2 + 2 + 1). Three: a front,
  two flanks and a centre is still one body; 200 m: the body fits foundry's 232 m drivable middle with room to spare.
  His gang vees at 18 m are 65 m each, so three abreast is 222 m: his five stand **2 + 2 + 1**; the Law's wedges at
  15 m (54 m) stand 3 + 2.
- The front rank on the click, each further rank one slot depth + `GAP_M` behind, TOWARD where they came from.
  **Asked and ruled (for the close to quote):** O1b (`edd98b85`) put the click at the body's CENTRE, because in the
  wall frame the rear squad reached its slot 48 m away in ~4 s and stood IDLE while the rest drove 150 m (one of five
  looked as if it ignored the click), and because one squad's centre lands on the click. **The orchestrator ruled
  against it:** on an attack-move the front rank would drive 50 m PAST where he pointed, into contact he did not
  choose; round 19's rule is "arrive at the point he clicked", nothing beyond it; a rear squad with a short way to go
  simply gets there first. Reverted in the next commit; the per-squad trace kept; the test is now "every squad moves
  TOWARD the click and ends closer to it than it started".
- Who stands where: the assignment with the least total straight-line driving (exhaustive up to 6 blocks, greedy
  beyond); its paths never cross (a crossing pair can always be uncrossed for less). On his start line that sends the
  outer squads to the front rank, the next two to the second and the centre squad to the rear: everyone moves inward
  or straight, nobody outward.
- `fit_inside`: a body near a wall slides inward whole instead of the clamp pushing its outer squads onto their
  neighbours (applies to two squads as well; only ever moves a body that would have been clamped).
- Pricing: unformed squads (no task yet, so no element) at their FACTION's open spacing (gangs 18 m, not 14 m); AUTO's
  width a line as in round 19, AUTO's depth the deeper of its standing shape and a wedge.
- Alternatives considered against it, on paper: shrinking each squad to its shape's real frontage does not help his
  case (his vees were already priced as vees: 5 × 65 + 56 = 380 m); a gap scaled with the count still leaves 5 × 65 =
  325 m > 232 m. Only ranks take five squads off the wall.

**O2: the probe case** (`e7caffad`): `make two-squads-playtest` now also runs the five-squad case once on foundry
(vee); `make five-squads-series` runs `FIVE_MAPS` (foundry parade) × `FIVE_SHAPES` (vee auto) × `FIVE_REPS` (3).
Army: `tests/support/five_gangs_army.json` (25 Rat Rods, five squads of five); vee is picked in the Formation panel
for all five (the army file's `formation` only reaches the legacy Squad, never the player's control groups). Order:
all 25 selected, A, click 150 m straight ahead. Per squad: worst sideways detour of its centre in the first 10 s (from
the straight line start-centre → click); arrival = every crew within 12 m of the slot it will stand in (90 s limit).

**Before O1** (`0c243e8a` + the probe, builder0, 3 repeats each, real time; detours per squad west→east, metres):

| map, shape | anchor span | detours in 10 s (r1 / r2 / r3) | worst |
|---|---|---|---|
| foundry, vee | 232 m (x = ±116, the wall) | 80/74/13/44/81 · 89/75/17/63/80 · 80/74/13/44/82 | **89.3** |
| parade, vee | 218 m | 68/82/4/65/78 · 75/66/2/67/62 · 84/63/2/62/70 | **84.1** |
| foundry, auto | 232 m (±116) | 86/53/1/48/79 · 86/51/1/47/79 · 85/52/1/48/78 | **86.1** |
| parade, auto | 223 m | 68/55/2/46/78 · 77/55/2/43/77 · 68/55/2/46/78 | **77.9** |

Arrival: the two outer (clamped) squads "arrive" in 12–50 s; the inner three mostly never stood in their slots within
90 s (12 of 18 runs had a squad not there): their elements were in `swarm`/`herringbone`/`coil` (the gangs' drills
under his attack-move, brains' P1), so the time the last squad arrives is a brains-side number until P1 lands.

**O1 DONE, CP1 MERGED** (green `360c3f06`: builder0, `make check exited 0`, 2176 passed 0 failed, 23 targets ALL
JUDGED, all thirteen sim-baseline lines **unmoved** as pre-registered, determinism `762a0576f944f5b7`; the orchestrator
merged it alone as `6d8071c4`). Tests: `tests/test_control_squad_ranks.gd` (9: rank sizes, two squads = the old row,
three that fit = one row, five gang vees = 2 + 2 + 1 within 200 m with no overlapping slots and no crossing paths,
ranks centred and stepped, a drawn heading, nobody moves outward, a body near a wall slides whole, > 6 squads);
`test_control_two_squads.gd::test_five_squads_one_click_go_as_a_body` (25 vehicles through `order_selection`: five
elements of five, ranks, no anchor needs the clamp, nobody past the click, slots not mixed); **mutation-checked**: with
the controls back on `row` it fails (builder0, light lane). All 314 `test FILTER=control` pass (builder0).

**Before / after O1, the acceptance (C21.4)** (builder0, `make five-squads-series FIVE_REPS=3`, the probe of
`8a7e5c94` in both arms; BEFORE = that tree with `selection_squads.gd`, `rts_controls.gd` and the O1 tests put
back to `0c243e8a` for the rsync (the run's header says 8a7e5c94, DIRTY); AFTER = `8a7e5c94` as committed. Both
arms BEFORE the merge of main at `4bfba462`, i.e. CPU leaders OFF and no brains P1; seed 3; 150 m straight ahead;
three repeats each; worst over the five squads, metres, per repeat):

| map, shape | before: span | **before: worst sideways in 10 s** | before: worst detour from start→click | after: span | **after: worst sideways** | after: worst detour | crews blocked/pushed (sum of 3) |
|---|---|---|---|---|---|---|---|
| foundry, vee | 232 m | **58 / 58 / 58** | 90 / 90 / 90 | 79 m | **17 / 16 / 17** | 41 / 43 / 45 | 0 → 0 |
| parade, vee | 218 m | **47 / 45 / 49** | 84 / 82 / 73 | 129 m | **22 / 24 / 22** | 58 / 60 / 59 | 1 → 1 |
| foundry, auto | 232 m | **43 / 43 / 43** | 86 / 86 / 86 | 86 m | **25 / 15 / 15** | 27 / 28 / 28 | 1 → 0 |
| parade, auto | 223 m | **40 / 41 / 41** | 77 / 78 / 78 | 86 m | **15 / 15 / 15** | 50 / 49 / 46 | 5 → 0 |

- **Sideways** (what he saw: a squad driving across his army's forward from where it stood) falls from 40–58 m to
  15–25 m on both maps and both shapes. The rest of it is a squad moving to its place in the body (±39 m on foundry).
- **Detour from start→click** (C21.4's measure as written) counts that place too, so it stays 27–60 m after; it
  roughly halves on foundry, and the before arm's number was the wall.
- **Span:** 218–232 m (the wall: anchors at ±116 on foundry) → 79–86 m (2 + 2 + 1); Parade with vees 129 m because
  there the gangs lay at their 14 m "lanes" pitch, so three vees fit a rank (3 + 2).
- **Arrival** stays mostly "never within 12 m of the slot in 90 s" in both arms: before brains' P1 the gangs' drills
  (swarm/herringbone/coil) took the crews off their slots. A re-run on the merged tree (P0 + P1) is running; numbers
  there will be listed separately, not compared with these.

**On the merged tree (main `ace70c1b` merged at `4bfba462`: CPU leaders ON (P0), no bait/encircle under his
orders (P1); the layout as O1, front rank on the click; probe `2b435567`, builder0, 3 repeats; reported on its own,
NOT compared with the table above, which was taken before both):**

| map, shape | span | **worst sideways in 10 s** | worst detour start→click | last squad arrived (s) | crews blocked/pushed (sum) |
|---|---|---|---|---|---|
| foundry, vee | 79 m | **46 / 47 / 46** | 70 / 70 / 70 | 13.0 / n/a / 13.0 | 0 |
| parade, vee | 129 m | **32 / 44 / 32** | 46 / 68 / 47 | 19.2 / 21.5 / 19.2 | 1 |
| foundry, auto | 86 m | **24 / 24 / 26** | 32 / 32 / 33 | 19.2 / 19.2 / 14.2 | 4 |
| parade, auto | 86 m | **34 / 34 / 34** | 18 / 18 / 18 | 20.0 / 20.0 / 20.0 | 6 |

- **P1 shows:** every squad now arrives (the last in 13–21 s; before the merge most never stood in their slots in 90 s).
- **Sideways went UP on foundry vee (46 m vs 16–17 m before the merge, same anchors to the decimetre).** The per-squad
  trace (`references/round21/orders/trace_foundry_{vee,auto}_merged.jsonl`, light lane, `11a90600`'s probe, one run)
  says it is the elements', not the layout's: **squad 1** (anchor (−39.4, −57.2), from (−56.6, 89.1)) drives WEST to
  x = −101 by 7 s with no drill, formation vee, `in_transit` false, crews on plain `move` orders, and only then turns
  for its anchor; **squad 2** runs `far_ambush` under his attack-move for its first 4 s, then reads `arrived` with NO
  order from 5 to 9 s while it stands at (12.7, 41.5), 56 m short of its anchor (−39, −7.2), and drives again at 10 s.
  No squad is ever `in_transit` under an attack-move (the travelling anchor is for a plain move only).
  **Written to brains via the orchestrator (R2):** (a) `far_ambush` still fires under his attack-move after P1; (b) a
  squad declared "arrived" with no order 56 m from its task's destination; (c) the westward swing of squad 1 (a route?
  the trace has the centre each second). The "arrived" times of 3–4 s in this table are (b): crews within 12 m of a
  slot their element laid where it stood, not at the click.

**On main with brains' R1 + R2 (this branch at `a0ce2fb2` = main `d25d0579` merged; builder0; 3 repeats; arrival =
the squad's CENTRE within 12 m of its task anchor, `8be7d470`; reported on its own):**

| map, shape | span | **worst sideways in 10 s** | worst detour start→click | **last squad arrived (s)** | crews blocked/pushed (sum) |
|---|---|---|---|---|---|
| foundry, vee | 79 m | **34 / 44 / 41** | 26 / 28 / 24 | **12.8 / 13.8 / 17.0** | 1 |
| parade, vee | 129 m | **45 / 42 / 39** | 43 / 44 / 46 | **13.2 / 12.0 / 19.5** | 2 |
| foundry, auto | 86 m | **22 / 22 / 22** | 33 / 33 / 33 | **12.8 / 12.8 / 12.8** | 3 |
| parade, auto | 86 m | **23 / 23 / 23** | 32 / 32 / 32 | **12.2 / 12.0 / 12.2** | 3 |

- **Every squad arrives, the last in 12–20 s** (R2's leg reset; before R2 the 3–4 s "arrivals" were the old measure).
- **The start→click detour on foundry vee falls 70 → 24–28 m** (R2's (a)–(c)).
- **Worst sideways is still 34–45 m with vees, from the inner squads (2 and 4), and it is the attack-move fighting,
  not the layout:** the trace (`references/round21/orders/trace_foundry_vee_r2merged.jsonl`) shows squad 2 meeting the
  CPU scout at 1 s, `react_to_contact` → `assault_through` (1–4 s), then driving on east to the assault's point (x
  +14 at 9 s; its anchor is (−39, −7)) because a leg anchor a drill set is kept (brains' rule: assault-through's point
  past an ambush). On an attack-move that is "fight what you meet"; the probe's enemy is one scout ahead of them.
  Not a request: noted to brains and the orchestrator as what he will see.

**The dots, looked at** (`make five-squads-shots`, builder0, at `8a7e5c94`'s probe on O1; 1854x1011 and 1200x540):
- Seed 3, foundry, 150 m ahead: at 5 s two pins in front ("ATTACK-MOVE · 0/5 there · 85 m / 98 m"), two in the second
  rank (32 / 43 m) and the fifth "ARRIVED" behind them; the radar shows the five squares as a 2 + 2 + 1 block around the
  click and every cross inside it; the whole body is in his frame at phone aspect too. Once there, crews spread into the
  gangs' drills ("Bravo contact north", "dressing 1/5"): brains' P1, not the layout.
- **Near a wall (the orchestrator's ask): his round-20 foundry seed 29989, click (95, −40), 21 m from the east wall:**
  the body stays a body: it slides 10.9 m west whole, the front-right squad's anchor exactly on the wall's clearance
  line (x = 116), the other four in their ranks back toward the start; anchor span 93 m along the diagonal; nobody
  blocked or pushed (`blocked_or_pushed: []`); worst detour 27 m. Before O1 the same order would have put two squads
  on the wall at ±116 and run 380 m of row through the clamp.
- Frames kept (JPEG): `_agents/streams/references/round21/orders/` — `wall_seed29989_desktop_ordered.jpg`,
  `wall_seed29989_desktop_5s.jpg` (near the wall), `plain_seed3_desktop_5s.jpg`, `plain_seed3_phone_5s.jpg`.
  Regenerate: `make remote T="five-squads-shots FIVE_SEED=29989 FIVE_CLICK=95,-40"` / `make remote T=five-squads-shots`
  → `build/five-squads-shots/<size>/*.png`.

**O3: the Parade bay slot, REPRODUCED and NAMED** (`make two-squads-playtest TWO_ARENA=parade TWO_CLICK=36,-24
TWO_SHAPES=line,wedge`, builder0 light lane, at `8a7e5c94`'s probe on O1, seed 3, one run). The mechanism: **the squad's
anchor lands ON the bay's container row, so its wedge straddles a 45 m wall, and grounding pushes the slots past it to
the far side.** The row: five stacked `container_40` at z = −23, x = 61.5…94.5 (rotation ≈ 176°: a wall along x from
≈ 55 to ≈ 101). His click (36, −24) puts squad 2's anchor at x ≈ 71, z ≈ −24, inside it. Squad 2's Wedge lead slots fall
just south of the wall (asked (75.4, −26.5)); `SlotGround.standable_for` moves each to the NEAREST standable point,
which is the far side (1.8 m: (75.4, −28.3)), not the side the squad drives in from. Bravo_3 then has to go round the
row's west end and ends **`blocked` / `terrain` at (49.6, −31.6), 26.1 m short of its slot** (selected case; in the
grouped case its neighbour Bravo_2 got round: asked (75.4, −26.5) → (75.4, −32.1), arrived). It is not the clamp (no
anchor touched the boundary) and not the row's arithmetic (the anchor is where his click put it).
- **Request to brains (R1, written here and sent):** ground a slot to the standable point on the side its element
  reaches it from: the nearest one connected to the element's anchor/approach without crossing an obstacle (e.g. the
  navmesh closest point along the segment anchor → asked slot, or reject a candidate whose straight line from the
  anchor is blocked), not the nearest one overall. Repro: the command above; Parade, seed 3, squad 2 Wedge, Bravo_3.
- **O3's close row (brains' fix on main, `cf6955a2`; this branch at `a0ce2fb2`; builder0 light lane; the same command,
  one run): `two-squads-playtest` exited 0, every check true.** Bravo_3 (squad 2, Wedge): slot asked (75.5, −26.7) →
  grounded on the NEAR face (72.7, −17.6) (pushed 9.5 m, toward the squad), ends 1.6 m from it, `arrived` (selected);
  grouped: (72.8, −17.6), 1.9 m, `arrived`. Before: (75.4, −28.3) on the far face, `blocked`/`terrain` 26.1 m short.
- **O3 CLOSED: named, requested to brains (relayed by the orchestrator as brains' stretch (d)), repro + probe columns
  shipped.** The orders-side alternative (pull an anchor out of a prop's footprint) is NOT built, the orchestrator's
  decision: an order goes where he clicked.
- The probe now reports per crew `slot_asked`, `slot_pushed_m`, `from_slot_m`, `phase`, `blocked_by` (two-squad rows)
  and `blocked_or_pushed` (five-squad summary), so a re-run after brains' fix reads the same numbers.

**Stretch:** (a) DONE `6f995679`: `TWO_TIMEOUT ?= 720` bounds every Godot run of `two-squads-playtest`,
`two-squads-shots`, `five-squads-series` and `five-squads-shots` (documented in `mk/command.mk`). (b) DONE by O1, no
new code: the ground dots are each crew's arrival slot and the pins are one per squad, so the ranks are drawn as they
will stand (frames above: two pins far ahead, two in the middle rank, the fifth behind). (c) DONE `6f995679`: the first
Shift+N of a session says "Added to group N (k units). Shift+N adds, Ctrl+N replaces" (one notice, then silent; test
`test_control_groups::test_shift_number_says_once_that_it_added`). StarCraft's meaning of Shift+N kept.

**What to playtest (his eye is the check):** `make garage` → Road Gangs → CLEAR → tap the Rat Rod 25 times → FIGHT;
Ctrl+A, A, click across the floor 150 m ahead: five pins, two far ahead, two behind them, one behind those, all inside
about 80 m across; nobody drives toward a wall first. Then a click near a side wall: the whole body shifts in from
the wall and keeps its shape. Then two squads: unchanged from round 19 (side by side).

**Questions for the lead:** none needed. Choice made for him (reversible: two constants): at most three squads abreast
and at most 200 m wide; his Rat Rod vees at 18 m are 65 m each, so his five stand two, two and one.

**Requests to other streams:** brains R1 (O3 above, relayed by the orchestrator as brains' stretch (d)): ground a slot
on the side its element reaches it from. Round 19's requests 1–3 to brains are unchanged (`ElementPlan.clamp_to_arena`
square vs the map shape: now mostly moot for bodies because `fit_inside` keeps anchors inside orders' own clamp).

**Known issues:** (1) AUTO is still priced as a line across (round 19's rule); the gangs' table picks `swarm` on a
move (≈137 m wide at 18 m), so two AUTO gang squads side by side can interleave their wings (not overlap hulls: slots
are 14 m+ apart). Pricing AUTO as the widest shape the table can pick would stand five AUTO gang squads one per rank
(≈ 350 m deep): not done; with P1 the drills no longer fire under his orders, so the leader's pick is the table's
default row. (2) The army file's per-squad `formation` reaches only the legacy Squad, never the player's control
groups (so the probe picks vee through the Formation panel). His round-20 tasks did carry `"formation": "vee"`; which path
put it there was not traced.
(3) `control_scale` frame timing still unjudged (round 19's open item, needs an idle builder0).

**Merge notes:** new files `tests/test_control_squad_ranks.gd`, `tests/support/five_gangs_army.json`,
`_agents/streams/references/round21/orders/*.jpg` (four frames, 1.4 MB). Changed in my paths only:
`game/control/selection_squads.gd` (`ranks`, `rank_sizes`, `fit_inside`, `depth`, constants), `rts_controls.gd`
(`_order_squads` uses `ranks` + `fit_inside`; `_squad_depth`, `_squad_pitch`; the Shift+N notice),
`two_squads_playtest.gd` (the five-squad case; ground facts per crew), `mk/command.mk` (`five-squads-series`,
`five-squads-shots`, `FIVE_*`, `TWO_TIMEOUT`), `tests/test_control_two_squads.gd`, `tests/test_control_groups.gd`.
No shared files touched.
