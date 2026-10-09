# Stream: orders (two columns apart; ten AUTO squads on the click; the chip under the alert; the held crew's readout)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 23 direction: the launch*
> (his two answers), *Round 21: the close* (the front rank stays ON the click), `_agents/workstreams.md` *Round 23*
> (C23.1–C23.4), and your round-22 final report (`streams/archive/round22/orders.md` Status: `SelectionSquads.ranks`,
> the nesting, the untangle, question 1, known issues 1–4). You own `game/control/**`, `game/ui/formation_picker.gd`,
> `selection_panel.gd`, `group_bar.gd`, `squad_chip.gd`, `selection_markers.gd`, `command_icons.gd`, `tactical_map.gd`,
> `radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`, **this round also
> `game/ui/edge_markers.gd`** (perf is not running; C23.4), `tests/test_control*.gd`, `tests/test_command*.gd`,
> `tests/test_tactical_map.gd`, `tests/test_element_preview.gd`, `tests/test_touch.gd`, `tests/test_hud_edge*.gd` if
> one exists for the strip, `mk/command.mk`.

## The lead's direction (2026-10-07)

Your round-22 question 1 (*two squads in column side by side stand 14 m apart … would you rather two columns kept
further apart, say 28 m … recommended: try 28 m*) was put to him at the launch with the recommendation:

> *"ok, the two decisions that are mine, I go with your recommendations."*

So: **28 m between two columns driving side by side.** His eye refines the number later if 28 reads too wide; one
constant, named in Status. Standing: *"units getting into formation is getting better"* (2026-10-08, his pacing item,
brains' this round); the front rank stays on his click (round 21's ruling); a direct order of his still wins (lesson 264).

## Where things stand (read at `68b97663`, main-checked; verify)

- **Two columns 14 m apart:** `game/control/selection_squads.gd:14` `const GAP_M := 14.0` (`SPACING_M := 14.0` at line
  16 is a different value: the footprint pitch when a squad has no element). `row()` (lines 227–255) places squads by
  `width + GAP_M`; a column has NO width (`game/tactics/tactics_formation.gd:413-414`, `"column": Vector2(0.0, i * s)`),
  so the gap is all there is between two files; `ranks()` uses `row()` for two squads (line 289) and `slot_width +
  GAP_M` for three or more (306, 383). The width comes from `rts_controls.gd:1127-1133` `_squad_width()`. **Changing
  `GAP_M` itself reaches every shape** (rank depth `slot_depth + GAP_M` at 328, the nest clearance floor 372,
  `rank_sizes` / `_fits_one_rank` frontage 399 / 435, the 200 m cap; two gang vees 144 → 158 m): not what he asked.
  The narrow fix is a column-only floor on the width (e.g. `maxf(width, 28 - GAP_M)` when the shape is column, in
  `_squad_width()`), so two columns' centre lines sit 28 m apart and nothing else moves. No test hard-codes 14 for the
  gap (`test_control_squad_ranks.gd:84,105,206,212,306,318` and `test_control_two_squads.gd:59,72,223,284` read
  `SelectionSquads.GAP_M`; `test_control_untangle.gd:45,47`'s 14.0 is the formation pitch). Probe thresholds that may
  move: `two_squads_playtest.gd:27` `AWAY_M := 14.0`, `squad_orders_playtest.gd:23` `ARRIVED_M := 14.0`.
  The doctrine number `GAP_M` mirrors is brains' `game/tactics/doctrine_table.gd:86` (`"open": 14.0`): leave it.
- **Ten AUTO squads past the click** (your known issue 1: 32–34 m past the click under ~200 m from his base): the
  nesting is `selection_squads.gd:321-386`; `rank_step()` (327–346) falls back to `plain = slot_depth + GAP_M` at line
  329 when `nested_offsets()` (356–367) returns `[]`, which it does when a block has no `"shape"` or the shapes
  differ. AUTO loses its shape at `rts_controls.gd:1112-1121` `_squad_block()` (`if shape != UnitCommand.AUTO …`);
  AUTO's depth is priced at 1139–1152. The one-line fix is to give AUTO a nominal shape there
  (`TacticsFormation.auto(count, "move")`, what `SelectionSquads.width/depth` already fall back to at 565 / 574) so all
  ten blocks share a shape and nest. The risk: the leader picks a different shape on the way (gang AUTO squads end in
  coil or swarm) and the clearance assumed the nominal one; measure it. `test_control_squad_ranks.gd:311-318` pins
  AUTO's current step (`4.0 * (VEE_D + GAP_M)`) and 310 pins "mixed shapes don't nest": both change with the fix.
  **The cap is 5 this week** (`Units.MAX_SQUADS := 5`, army's file, "one constant to flip back to 10"); ten squads
  reach the field only when native lands (C23.3). Pure tests build blocks directly and are unaffected; the live probe
  (`make five-squads-series SQUADS=10`) folds to five through `SquadConsolidation` and quits (`two_squads_playtest.gd:288`).
  To measure at ten, flip `Units.MAX_SQUADS` locally in your worktree ONLY (never commit it; say so in Status).
- **The chip under the alert strip** (perf's known issue 1, round 22): the bottom-edge chips are EdgeMarkers'
  off-screen ELEMENT chips, not the group bar: `game/ui/edge_markers.gd:13-15` `CHIP := Vector2(112, 30)`,
  `BOTTOM_FRACTION := 0.22` (the bottom chip centre ≈ 0.78 × screen height); the strip `ALERT_Y := 0.79` (line 23),
  `_draw_alerts()` 221–243, its box from baseline − 1.1·text to + 0.5·text. Round 22's `alert_y()` (252–256) lifts the
  strip above the group bar's top (`_bar_top()` 260–264, `ALERT_GAP := 6.0`, commit `2b41cfbd`) and never considers
  the edge chips. Seen in `streams/references/round22/perf/` `perf-hud-desktop-30.png` (India's chip under "Bravo under
  fire"). Your own note: at phone aspect the strip may still sit over the panel's header line (`alert_y` only checks
  the bar). `make perf-hud-shots` (mk/fx.mk, perf's target, run it read-only) produces both aspects at 50 a side.
- **The held crew's readout says nothing** (brains' known issue, round 22): the doctrine line is
  `selection_panel.gd:281` → `rts_controls.gd:701-703` `doctrine_line()` → `selected_element().describe()` →
  `game/tactics/element.gd:771-777` (brains'; `reason` from the plan's `why`; the text
  `game/tactics/unanswered_fire.gd:78` `WHY_HELD`). His H key (`rts_controls.gd:810-811`) on a single vehicle takes
  the DIRECT path (977–997: `elements.disband` / `owner.remove`, then `UnitCommand.make … issue`); the crew leaves its
  element, `selected_element()` is null, the line is "", and nothing plans for the crew so `UnansweredFire` never
  runs. A readout for a crew on a direct hold is yours (`game/control/movement_readout.gd`'s per-vehicle callouts, or
  the panel's footer when no element is selected); the per-crew "under fire I cannot answer" signal is brains'
  (`ElementSituation.taking_fire` exists per crew; a crew outside an element needs one you can read: C23.2).

## Backlog (in order)

**O1. Two columns 28 m apart.** Test first (`test_control_two_squads.gd`: two column squads ordered abreast → centre
lines 28 m apart; two line/vee squads unchanged to the metre; three columns 28 m each). Build the column-only floor in
`_squad_width()` (or the narrowest place you find; one constant, named `COLUMN_GAP_M` or alike, 28.0, read by nobody
else). Re-run `make interleaved-probe` (his six on the Sumps, round 22's probe) and `make two-squads-playtest` with
both squads in column: closest approach between the two files while driving (before 5.0–5.3 m) is the number for
Status, builder0, 3 repeats. Look at a frame (desktop and phone) of two columns ordered side by side: two files that
read as two. Thirteen lines UNMOVED (CPU-v-CPU never issues through your paths; say so).

**O2. The alert strip clears the edge chips and the panel header.** `edge_markers.gd` is yours this round (C23.4).
Test first (a known-answer test on `alert_y()` / the chip band: with a chip on the bottom edge the strip's box and the
chip's rect do not intersect at 1854×1011 and at 1800×810 `--ui-touch`). Fix: the strip's band avoids the bottom
chips' band (lift the strip above the chips, or pin the bottom chips below the strip; pick what reads best and say
why), and at phone aspect clears the panel's header line. `make perf-hud-shots` at both aspects, looked at, filed
under `streams/references/round23/orders/`.

**O3. The held crew's readout.** When he holds ONE vehicle with H and something it cannot answer shoots it, the panel
(or the movement readout) says so: "under fire from beyond range: holding on your order", the same words as the
element's (`UnansweredFire.WHY_HELD`, read from brains' constant, not copied). Contract C23.2: brains exposes a per-crew
read (`ElementSituation`-level or `TankBrain`-level: *this crew is taking fire it cannot return*, name agreed in
`workstreams.md`); until it lands, stub it in your paths and wire the readout against the stub; write the request in
Status and tell the orchestrator. Test: a scripted single-vehicle hold under a Lancer at range shows the line within a
second of the first hit, and a crew NOT under fire shows nothing.

**O4. Ten AUTO squads stand on the click** (your known issue 1; only visible when the cap is 10, which native's work
restores: build it now, prove it in the pure tests, measure it live with `Units.MAX_SQUADS` flipped locally). Give AUTO
a nominal shape in `_squad_block()`; update `test_control_squad_ranks.gd:310-318` to the new rule and say what the rule
is; `make five-squads-series SQUADS=10` before/after, builder0, 3 repeats: the front rank's distance past the click
(32–34 m before → ~0), everyone closer, arrivals not slower; then watch a run where the gang leaders pick swarm on the
way and report the clearance.

**Stretch (a).** The phone-aspect strip over the panel header, if O2 left it. **(b)** Your round-22 stretch (b) (the
garage's shape → `ControlGroups.from_squads`, three lines) stays NOT wired until army lets him pick a shape: nothing to
do. **(c)** `control_scale` timing on an idle builder0 (`make control-timing`), if you find a quiet hour: report, don't
tune.

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism UNMOVED as pre-registered.
- Probes: `make interleaved-probe`, `make two-squads-playtest`, `make five-squads-series` (5 and 10), builder0, 3
  repeats, before/after, with the trace; `make perf-hud-shots` for the strip (needs a display: builder0 has one for
  perf-fight; or the laptop in a quiet window through the orchestrator).
- Play it: `make garage` → the Law → SUGGESTED → FIGHT: pick two squads, column, order them side by side: two files 28 m
  apart; H on one vehicle under a laser at range: the readout says it is holding on your order.
- Every number: commit, machine, workload, sample size (C16.3). A `.uid` for every new test committed with it (lesson 273).

## Don't touch

`game/tactics/**`, `game/ai/**` (brains) · `native/**`, `game/ai/tank_brain.gd` and its hot loop (native) ·
`game/garage/**`, `game/units/**` (army, not running: `Units.MAX_SQUADS` flips locally only, never committed) ·
`game/ui/hud.gd`, `hud.tscn`, `hud_messages.gd`, `unit_bars.gd`, `unit_portraits.gd`, `draw_batch.gd`,
`game/theme/fx/**` except `order_feedback.gd` (perf, resting) · `game/match/**`, `game/modes/**`, `game/camera/**`
(nobody) · `arenas/**`, `game/arena/**` · `mk/core.mk`, `tests/baselines/**`.

## Waiting on the lead

- Nothing blocks you. He is asleep (2026-10-07 night); no gate tonight; decide, record the reason in Status, keep going.

## Status

**REPORT (round 23, orders): every backlog item done. GREEN, merge here: `e47016c0`** (builder0, `>> remote: make
check exited 0`, 2273 passed 0 failed, 23 targets ALL JUDGED, thirteen sim-baseline lines unmoved, determinism
`762a0576f944f5b7`; CPU-v-CPU never issues through these paths). O1 + O2 (`ea760c03`) are on main at `179d0d8a`;
above them O3 (`1537fb1a`, the held crew's readout against the C23.2 stub), O4 (`9bb0899f` + `e47016c0`: AUTO
bodies nest at the wedge with the coil's depth as the floor; ten AUTO squads on the click), the probes (`03d1177f`),
this Status. **Follow-up GREEN, merge here: `5a36e899`** (main `ebba1465` = brains' CP1 merged in; `CrewFire` reads
the real `crew_reason`; the live Lancer test; builder0, `>> remote: make check exited 0`, 2290 passed 0 failed,
thirteen unmoved, determinism `762a0576f944f5b7`; the check's own tally was 21 passed, 2 NOT JUDGED (perf-judge
refused three times on a box at load 7-10: ratios 2.16 / 1.74 / 2.43), so **`make remote T=perf-judge` was re-run
alone on the same tree: JUDGED, PASS on attempt 2 (ratio 1.35x, load 5.1)**, the verdict ai-scenarios' scenario_perf
row defers to (as the first check's log says of it). Above it this Status line only.

_Worker (session `godot-orders`, round 23), started 2026-10-07 ~23:40 PDT from main `46764993` (main-checked
`68b97663`). He is asleep; no gate; decisions recorded here._

**Plan (in order):** O1 two columns 28 m (pure + through the controls; the probes for the number) → O2 the strip's
floor (pure geometry at both aspects; frames on builder0's display) → O3 the held crew's readout against the C23.2
stub (`CrewFire`, `game/control/crew_fire.gd`) → O4 AUTO's nominal shape (pure tests; the ten-squad series with
`Units.MAX_SQUADS` flipped locally only) → stretch (a) if O2 left it, (c) if builder0 is idle. The laptop is the
orchestrator's until 00:30 (a perf measurement): every run of mine is on builder0.

**Decisions (one-line reasons):**
- **O1: a column is laid as a LANE `COLUMN_GAP_M - GAP_M` = 14 m wide** (`SelectionSquads.width("column", n ≥ 2)`;
  the constant `SelectionSquads.COLUMN_GAP_M := 28.0`, his number), rather than a column-only gap in `row()`: one
  rule reaches `row`, `ranks`, `_fits_one_rank` and `rank_sizes` alike, so two columns' centre lines sit 28 m apart,
  three columns 28 m each, and a column beside a line keeps 7 + 14 = 21 m from the line's edge vehicle (14 before:
  a snaking file wants the same room beside a line as beside a file). Every other shape is unchanged to the metre
  (tests pin two lines and two vees). AUTO is still priced as a line (round 22's ruling), so AUTO squads do not read
  the lane. A single vehicle "column" is no file: width 0.
- **O2: the strip is LIFTED above the chips, not the chips lowered** (`EdgeMarkers._floor_top`): the chips' band
  at 0.78 of the view is already as low as the command card allows (BOTTOM_FRACTION), and the strip's words want the
  eye just above the card either way. The chips' band is the floor ALWAYS (whether a chip is on it now or not), so
  the strip does not hop as chips come and go with the camera; the bar's top (round 22's rule) and the panel's top
  lift it further only when they are up. The strip's resting line moves from 0.79 to ~0.75 of the view (desktop
  1854x1011: baseline 799 → 759 px; phone 1800x810 touch: 640 → 597). The cause, for the record: the bottom chip
  line is `1 − BOTTOM_FRACTION` = 0.78 and `ALERT_Y` = 0.79, the same line at every window size; the strip only
  cleared the chips while something was selected (the panel lifts the bar, the bar lifted the strip).
- **O3: the readout is the panel's footer** (the doctrine line's place: `RtsControls.doctrine_line()` falls through
  to `held_crew_line()` when no element is selected), not a per-vehicle callout: it is where the element's own line
  reads, and his eye is on the card when he has just pressed H. Shown only for crews on a hold of HIS (verb `hold`,
  source `player`) in no element: a crew driving on his order is not "holding on your order", and a crew held
  inside its element is the element's line to tell. One crew: brains' words as they are; several: "N of M " + the
  words. The words are `UnansweredFire.WHY_HELD` read from brains' constant.

**Baseline:** main `46764993` (docs only above main-checked `68b97663`: builder0, 2260/0, thirteen unmoved,
determinism `762a0576f944f5b7`).

**O1 + O2 GREEN, merged: `ea760c03`** (builder0, `>> remote: make check exited 0`, 2267 passed 0 failed, 23
targets ALL JUDGED, sim-baseline lines unmoved; CPU-v-CPU never issues through these paths) → main `179d0d8a`.

**O1 (done):** `8ac79558`. builder0 `make remote T="test FILTER=control_two_squads|control_squad_ranks"` 32/0 (four
new: two columns 28.0 m through the controls, centred on the click; two lines and two vees unchanged; the pure
lane: three columns 28 m each, a column beside a line 21 m file-to-edge). **His replay** (`make interleaved-probe
REPLAY=1`: his six on the Sumps, his five clicks, AUTO for two then the COLUMN he picked; builder0, tree `9bb0899f`,
3 repeats; before = the same build with `INTERLEAVED_FLAGS=--column-gap=14`; the untangle-ON arm):

| arm | closest two vehicles of different files, whole replay | the two files driving MIXED | crew paths into the other file (untangle on / off) |
|---|---|---|---|
| before (14 m) | 5.2 / 5.3 / 5.3 m | 2.75 / 5.0 / 3.0 s | 0 / 0 / 0 (off: 1 / 1 / 3) |
| after (28 m) | 5.5 / 5.5 / 5.7 m | **0.0 / 0.0 / 0.0 s** | 0 / 0 / 0 (off: **0 / 0 / 0**) |

The two files never drive mixed at 28 m and nobody crosses the other file even with the untangle off. The whole-replay
closest number spans all five clicks, so **per click** (the probe reads it since `03d1177f`; same arms, 3 repeats,
untangle on; his formation persists from the third click, so clicks 3-5 are the columns; "closest" from 2 s after
each click until the next):

| click (his) | closest, two files, before (14) | after (28) | files mixed, before | after | into the other file, before | after |
|---|---|---|---|---|---|---|
| 3, the column pick | 9.0 / 9.0 / 9.0 m | **23.8 / 14.7 / 14.8 m** | 0 | 0 | 0 | 0 |
| 4 (7 s later) | 5.0 / 5.0 / 4.9 m | 5.8 / 5.3 / 6.0 m | 3.0 / 4.0 / 2.5 s | **0 / 0 / 0** | 0 | 0 |
| 5 (13 s later) | 5.3 / 5.5 / 5.5 m | 5.7 / 6.3 / 6.2 m | 0.75 / 2.25 / 2.0 s | 2.0 / 0 / 0 | 0 / 1 / 0 | **0 / 0 / 0** |

(the untangle-OFF arm, his recording's code at the time, reads the same within 0.3 m and 1 s; its click-5
crossings 1 / 2 / 3 before → 1 / 0 / 0 after.) Reading: on the column order itself the files go from 9 m to 15-24 m
apart; on his later clicks, given while the six are still sorting out of their interleaved start, the closest pair
is bounded by where they stood (5-6 m either way) but the files stop driving MIXED (3-4 s → 0) and stop crossing.
**The headline, the clean side-by-side case** (`make two-squads-playtest TWO_SHAPES=column,column`: two squads of
five from opposite flanks 136 m apart, both in column, one click 60 m ahead and 35 m toward squad 2, the skirmish
map, seed 3; builder0, tree `03d1177f`, 3 repeats; before = `TWO_FLAGS=--column-gap=14` on the same build; the
nearest two vehicles of DIFFERENT squads from 2 s after the order to the 25 s settle):

| case | closest two vehicles of different columns, before (14 m) | after (28 m) | when (s after the order) |
|---|---|---|---|
| box-selected | 3.8 / 6.7 / 3.7 m | **18.5 / 7.3 / 12.9 m** | 16.5 / 12.8 / 16.3 → 21.5 / 19.0 / 17.5 |
| as one key (Ctrl+3 over both) | 3.5 / 3.1 / 3.4 m | **13.7 / 18.6 / 12.2 m** | 15.3 / 15.5 / 19.3 → 23.3 / 15.0 / 17.3 |

At 14 m the two files touched (3-4 m centre to centre is under a hull's 5.3 m) as they converged on the click;
at 28 m they never come within 7 m. The rear vehicle's slot is 5 m further from the click (28.6 → 33.7 m: the
files sit 7 m further out). Nobody heads away or runs to the middle in either arm (the probe's own checks pass).

**O2 (done):** `ea760c03`. builder0 `test FILTER=hud_edge_strip|hud_widgets|control_awareness` 29/0 (three new in
`tests/test_hud_edge_strip.gd`: at 1854x1011 and 1800x810 `--ui-touch` the old rule's strip box DID intersect a
bottom-edge chip and the new one clears it by ALERT_GAP; the panel's and the bar's tops still lift it; through the
fixture the floor is the chips' band with nothing selected). Frames: pending (below).

**O3 (done, tests green locally):** `1537fb1a`. `CrewFire` (`game/control/crew_fire.gd`, the C23.2 adapter: `source`
for tests, brains' `crew_reason` by name when `UnansweredFire` has it, "" until then), `held_crew_line()` behind
`doctrine_line()`, `tests/test_control_held_crew.gd` (four: one held crew under fire it cannot answer shows brains'
words in the panel's footer at once and clears when the fire stops; a crew under fire on a MOVE, or held inside its
element, is not called held; three held, two under fire: "2 of 3 …"; the adapter reads brains' static when the build
has it, the stub says "" until then: printed in the run). Laptop `make test FILTER=control_held_crew|
control_squad_ranks|control_two_squads` 38/0. The live case (a single-vehicle hold under a Lancer at range, within a
second of the first hit) is written when B2 is on main.

**O2 frames (looked at; `references/round23/orders/strip_{desktop,phone}-{30,45}.jpg`, `make perf-hud-shots` on
builder0's display at tree `e47016c0`, 50 a side, his 1854x1011 and 1800x810 `--ui-touch`):** at 45 s both aspects
have "Foxtrot 6" pinned on the bottom edge and "Hotel under fire (+5) [Q]" sitting just above it (desktop: strip
baseline ≈ 753 px, the chip's top ≈ 775; phone: ≈ 590 / 615), the one-row bar under both, nothing over the panel.
At 30 s the strip ("Delta wiped out (+5) [Q]") stands at the same line with no chip below it: it does not hop.

**O4 (done): `9bb0899f` the nominal shape, `e47016c0` the halt floor.** The rule: an AUTO squad is laid as the shape
it MOVES in when nobody named one (a wedge up to a platoon: `RtsControls.nominal_shape`), so AUTO bodies nest; and
because its leader HALTS in the doctrine's coil (every doctrine's halt), the ranks never step less than the coil's
depth at the squad's pitch (`halt_depth` on the block, `SelectionSquads.min_step`): 32.7 m at the gangs' 18 m, so
ten AUTO gang squads stand 4 x 32.7 = 131 m deep (200 m shapeless; the pure wedge nest's 104 m overlapped the coils).
A shape he picked halts in itself and carries no floor. Pure tests: `test_auto_squads_are_laid_as_their_nominal_
shape_and_nest` (ten AUTO gangs: 131 m, nothing past the click, consecutive rings' vehicles ≥ 10 m apart) and the
block through the controls (AUTO carries "wedge" + the coil's depth; his column carries itself, no floor).

**The series at ten** (`make five-squads-series SQUADS=10 FIVE_SHAPES=auto FIVE_SETTLE=12`: 50 Rat Rods in ten
AUTO squads, one attack-move 150 m ahead, seed 3; builder0; `Units.MAX_SQUADS` flipped to 10 LOCALLY for the runs
and reverted, never committed; before = `AUTO_SHAPE=off` on the same build; the crews read 12 s after the last
squad's centre arrived; per repeat):

| map | arm (tree) | body depth | **front past the click** | squads ending closer | last squad there (s) | crews blocked, settled | crews > 8 m off their seat, settled |
|---|---|---|---|---|---|---|---|
| foundry | before, shapeless (`03d1177f`, 2 + 3 reps) | 166.5 | **33.5 / 33.5 / 33.5** | 8 / 8 / 8 of 10 | 18.3 / 18.0 / 15.5 | 0 / 0 | 4 / 4 (8-11 m) |
| foundry | wedge nest only (`03d1177f`) | 104.0 | 0.0 / 0.0 / 0.0 | 10 / 10 / 10 | 14.5 / 13.5 / 13.5 | **2 / 1** (9-16 m) | 7 / 5 |
| foundry | **after, halt floor (`e47016c0`)** | 131.0 | **0.0 / 0.0 / 0.0** | **10 / 10 / 10** | 14.3 / 11.8 / 11.8 | **0 / 1 / 0** | 8 / 2 / 2 (8-12 m) |
| parade | before, shapeless (`03d1177f`, 2 + 3 reps) | 167.7 | **32.3 / 32.3 / 32.3** | 8 / 8 / 8 | 25.5 / 25.5 / 26.0 | 1 / 1 (16-17 m) | 1 / 1 |
| parade | wedge nest only (`03d1177f`) | 104.0 | 0.0 | 10 | 21.3 / 36.5 / 15.8 | (read at arrival: 1 / 0 / 4) | - |
| parade | **after, halt floor (`e47016c0`)** | 131.0 | **0.0 / 0.0 / 0.0** | **10 / 10 / 10** | 15.5 / 14.8 / 14.3 | 2 / 0 / 2 (9-13 m) | 4 / 3 / 4 |

(The before rows' "settled" columns are the 2-repeat `FIVE_SETTLE=12` re-run; their other columns the 3-repeat run
read at arrival, identical to the metre: the layout is deterministic, the real-time settle is not.) **Ten AUTO
squads stand on the click on both maps (33 m past → 0.0), every squad ends closer (8 → 10 of 10), the last squad
arrives sooner (18 → 12-14 s on foundry, 26 → 14-16 s on parade), and the crews are as seated as before within the
spread (0-2 of 50 blocked either way, 2-8 of 50 more than 8 m from their coil seat against 1-4).** The leaders ended
in coil in every run (one swarm on parade in the wedge-nest arm): the floor is the coil's; a swarm (wider, not
deeper) would reach a neighbour's ring sideways, as round 22 accepted for AUTO's width. Worst sideways in 10 s rose
24-36 m against 23.6-26 (the rear squads of a shorter body start their move earlier and spread round the ones ahead;
not judged, reported).

**Stretch:** (a) the phone-aspect strip over the panel's header: covered by O2 (the panel's top is in the strip's
floor; the band rule already sits above it at every size computed: 1854x1011, 1800x810, 1200x540). (b) nothing to do
(army resting). (c) `control-timing` on an idle builder0: not run; builder0 carried three streams' checks and my
probes all night (load 4-13), never idle. Needs a window from the orchestrator.

**Decisions taken for him (reversible):** the columns' lane 28 m (his answer; `SelectionSquads.COLUMN_GAP_M`, one
constant); the strip rests at ~0.75 of the view instead of 0.79 (it clears the chips always rather than hopping);
the held crew's words live in the panel's footer; AUTO bodies nest at the wedge with the coil's depth as the floor
(131 m for ten gang squads: on the click, crews seated). **Questions for the lead:** none that block; his eye on
the 28 m (two files that read as two, or too far apart?) and on the strip's new line.

**What to playtest (his eye is the check):** `make garage` → the Law → SUGGESTED → FIGHT. (1) Select two squads
(1 then shift-2), G until both read COLUMN, right-click ahead: two files 28 m apart, side by side, neither brushing
the other on the way. (2) With nothing selected, pan so a squad of yours leaves the bottom of the screen: its chip
sits on the bottom edge and the next alert ("… under fire [Q]") stands above it, not on it; same on a phone-shaped
window (`--ui-touch`). (3) Select ONE vehicle, press H, let a Syndicate laser hit it from beyond its range: the card's
footer reads "under fire from beyond range: holding on your order" (needs brains' B2 on main; until then the footer
stays empty for a lone crew). (4) When the cap is 10 again: Ctrl+A, A, click 150 m ahead with every squad on AUTO:
the front rank stands on your click (was ~33 m past it), the ranks ~33 m apart, everyone seated in its coil.

**Merge notes:** changed in my paths only: `game/control/selection_squads.gd`, `rts_controls.gd`,
`two_squads_playtest.gd`, `crew_fire.gd` (new, + `.uid`); `game/ui/edge_markers.gd` (lent, C23.4); `mk/command.mk`
(`TWO_FLAGS`, `INTERLEAVED_FLAGS`, `AUTO_SHAPE`, `FIVE_SETTLE`); tests `test_control_two_squads.gd`,
`test_control_squad_ranks.gd`, `test_control_held_crew.gd` (new, + `.uid`), `test_hud_edge_strip.gd` (new, + `.uid`);
frames `references/round23/orders/strip_*.jpg` (4, 1.5 MB). Nothing shared; `Units.MAX_SQUADS` untouched
(flipped locally for the ten-squad runs, reverted: `git status` clean). When brains' B2 is on main: `CrewFire`
needs no edit (it finds `crew_reason` by name); the stub branch and the "not landed" print can go, and the live
Lancer test is written then (a follow-up commit).

**O3 follow-up (C23.2 landed, brains' CP1 `ebba1465` merged in):** `CrewFire.reason` calls
`UnansweredFire.crew_reason` directly (the test fake in `source` stays; the stub branch is gone). The live test
(`test_one_vehicle_held_under_a_lancer_at_range_reads_holding_on_your_order`, on brains' own stage: a Syndicate
gunship under a Lancer's laser from 84 m, held with H as one vehicle through the controls, no element): the panel's
footer reads brains' words within the grace (1.5 s, brains' rule; the brief's "a second" is the grace's) plus half
a second of the first hit, stays on his hold, and clears once the Lancer is dead and the quiet has passed. Laptop
`make test FILTER=control_held_crew|ai_crew_reason` 7/0.

**Requests to other streams:**
1. **brains (C23.2, DONE on main `ebba1465`):** `UnansweredFire.crew_reason(game_match: Match, unit_name: String) -> String`, static,
   WHY_HELD while the named crew (inside OR outside an element) is being hit by something it cannot return, ""
   otherwise. `CrewFire.available()` finds it by name on the build; nothing of mine needs editing when it lands, and
   the live test (a single-vehicle hold under a Lancer at range) is written then.

**Known issues:**
0. **One machine's `build/` per worktree at a time** (found 00:45): `make remote`'s copy-back of `build/` landed under
   a local `make perf-hud-shots` of mine (its `build/perf-armies/green_50.json` vanished mid-run: "cannot open
   doctrine … File not found" in the phone frame). Trip-up 66 says one `make remote` per worktree; the same holds
   between a remote run and any LOCAL target that reads or writes `build/`. Sequence them.
1. (perf's file, not touched) `hud_skin.gd:413` places the end-of-match banner against `EdgeMarkers.ALERT_Y`, not
   the strip's actual line; with the strip now at ~0.75 of the view they are 24 px apart at his window and touch at
   1200x540 for the banner's moment. A one-line read of `EdgeMarkers.chip_band_top` there when perf wakes.
