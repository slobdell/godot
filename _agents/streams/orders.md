# Stream: orders (ten squads under his hands: groups 1–9 and 0, the chips, the body at ten, 50 a side on the map)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 19 direction* items 1–2,
> *Round 21: the close* (the front rank stays ON the click), *Round 22 direction*, `_agents/workstreams.md` *Round 22*
> (C22.1, C22.5), and your round-21 final report (`streams/archive/round21/orders.md` Status: `SelectionSquads.ranks`,
> `fit_inside`, the three-abreast / 200 m decision, the probes `make two-squads-playtest` and `five-squads-series`,
> known issues 1–3). You own `game/control/**`, `game/ui/formation_picker.gd`, `selection_panel.gd`, `group_bar.gd`,
> `squad_chip.gd`, `selection_markers.gd`, `command_icons.gd`, `tactical_map.gd`, `radar.gd`, `task_preview.gd`,
> `control_hints.gd`, `game/theme/fx/order_feedback.gd`, `tests/test_control*.gd`, `tests/test_command*.gd`,
> `tests/test_tactical_map.gd`, `tests/test_element_preview.gd`, `tests/test_touch.gd`, `mk/command.mk` (`hud-profile`
> and `hud-digest` are LENT to perf this round: read-only for you).

## The lead's direction (2026-10-07)

> *"the armies I can create with tanks are too small … Maybe that means allowing more squads"* → *"yeah double it
> sounds good."* Ten squads of five a side (army's CP1). Nothing else new for your paths; round 21's rulings stand
> (a body of squads, at most three abreast, 200 m, the front rank ON his click, nothing drives past it).

## Where things stand (read at `5beb038f`)

- `ControlGroups.COUNT := 9`; keys `KEY_1..KEY_9` in `rts_controls.gd` (line ~778, `number = keycode - KEY_0`);
  doctrine squads start as groups 1–5. The group bar draws one chip per group with units, bottom centre above the
  selection panel; the selection panel lists the selected squads' chips (round 20: the phone fits five squads).
- `SelectionSquads.ranks`: at most 3 abreast, `fit_inside` 200 m, ranks behind; the five-squad probe
  (`five-squads-series`, `FIVE_*`, the per-squad trace, arrival = centre within 12 m of the task anchor).
- The radar and tactical map draw every unit; 25 a side today, 50 a side after CP1 (and 64 a side was round 19's
  HUD-profile case: 2.8 ms per frame on his laptop for the HUD's per-unit work, perf's this round).
- Known issues (round 21): AUTO priced as a line (two AUTO gang squads abreast can interleave wings); the army file's
  per-squad `formation` reaches the legacy Squad only; `control_scale` timing unjudged.

## Backlog (in order)

**O1. Ten control groups.** `ControlGroups.COUNT` 10 (expose it as the constant army reads, C22.5); key 0 = group 10
(select, Ctrl+0 save, Shift+0 add, double-tap centres); the garage's squads 1–10 land in groups 1–10 (after army's CP1:
merge main when told); hints and the picker's text say 1–9, 0. Tests: groups, keys, the mapping.

**O2. Ten squads shown, desktop and phone.** The group bar with ten chips (two rows, or narrower chips: decide by the
frames, record the reason), the selection panel with up to ten squads selected (Ctrl+A), the squad chips readable at
phone aspect; `make hud-digest` (lent, read-only: run it, do not change it) shows the frame changed where you meant
and nowhere else. Frames at both aspects under `streams/references/round22/orders/`, looked at.

**O3. The body at ten squads.** `ranks` with 10 blocks: 3+3+3+1, the front rank ON the click, the 200 m cap, the depth
(three ranks of a five-vee ≈ 3 × (depth + GAP)); near a wall the body slides in whole; the pure tests for 6, 8, 10
blocks; the probe's ten-squad case (`FIVE_*` → a `SQUADS=` count) with the per-squad trace, before/after on main at
50 v 50 (3 repeats, builder0). Every squad moves toward the click and ends closer (round 21's test) at ten.

**O4. Fifty a side on the map.** The radar and tactical map at 50 v 50: legible (dots not a blob; squads as squares),
and their per-frame cost measured by `make hud-profile` (lent) before/after your change: say the number to perf if it
rose. The selection markers at 50 selected.

**O5. The dots and the readout at ten.** Task preview and order feedback for ten squads at once (pins not on top of
each other); the movement readout's squad list at ten.

**Stretch (a).** AUTO priced as the widest shape the table can pick (round 21's known issue 1), measured on the probe.
**Stretch (b).** The army file's per-squad `formation` reaching the player's control groups (known issue 2): trace the
path, fix if yours. **Stretch (c).** `control_scale` timing on an idle builder0 (ask the orchestrator for a window).

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism UNMOVED as pre-registered (CPU-v-CPU never
  issues through your paths; say so).
- `make five-squads-series` at 5 and at 10 squads, before/after, builder0, 3 repeats, with the trace.
- Play it (after CP1): `make garage` → Road Gangs → CLEAR → 50 Rat Rods in ten squads → FIGHT: keys 1–9 and 0 select
  each squad; Ctrl+A, V, click: ten pins in ranks of three, nothing past the click, nobody to a wall; the group bar
  shows ten chips you can read on the phone; the radar is legible.
- Every number: commit, machine, workload, sample size (C16.3).

## Don't touch

`game/tactics/**`, `game/ai/**` (brains) · `game/garage/**`, `game/units/**` (army) · `game/ui/hud.gd`, `hud.tscn`,
`hud_messages.gd`, `unit_bars.gd`, `unit_portraits.gd`, `edge_markers.gd`, `draw_batch.gd`, `game/theme/fx/**`
except `order_feedback.gd` (perf) · `game/match/**`, `game/modes/**`, `game/camera/**` (nobody) · `arenas/**`,
`game/arena/**` · `mk/core.mk`, `tests/baselines/**`.

## Waiting on the lead

- Nothing blocks you.

## Status

_(the worker keeps this current: plan, per-item results with commit + machine + sample, decisions with one-line
reasons, questions for the lead, requests to other streams, known issues, what to playtest, next steps, merge notes)_
