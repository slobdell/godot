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

_(the worker keeps this current: plan, baseline, done with numbers, decisions, questions for the lead, requests to
other streams, known issues, what to playtest, merge notes; "GREEN, merge here: <sha>")_
