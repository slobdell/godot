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

_(the worker keeps this current: plan, per-item results with commit + machine + sample, decisions with one-line
reasons, questions for the lead, requests to other streams, known issues, what to playtest, next steps, merge notes)_
