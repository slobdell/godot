> **ARCHIVED (round 22; stream closed 2026-10-07/08).** This brief ran as stream `orders` in round 22; every item is merged to
> `main` (`HANDOFF.md` *ROUND 22 IS CLOSED* has the merge table). The Status below is the worker's final report. Its
> worktree and branch are removed; evidence is under `streams/references/round22/orders/`.

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

**REPORT (round 22, orders): every backlog item done or ruled. GREEN, merge here: `07c14a19`** (main `249e103f`
merged; builder0, `make check exited 0`, 2242 passed 0 failed, 23 targets ALL JUDGED, thirteen sim-baseline lines
unmoved, determinism `762a0576f944f5b7`; CPU-v-CPU never issues through these paths). Above it: this Status only. O1 ten groups on 1–9 and 0 (`MAX_GROUPS` reads `Units.MAX_SQUADS`) and O1b
(two interleaved squads dealt by position: 3 → 0 crossings on his six) are on main (`1655e93b`). Since: O3 nested
ranks (ten vees: the front back ON the click, 33.8 → 0.2 m; every squad closer and arriving), O2 (two-row bar, the x50
portrait, the squad count; frames at both aspects), O4 (radar squares per squad past ten selected, no web of lines on
the floor; cost flat), O5 (marker ring 120, formation cards as keys), stretch (a) measured not changed, (b) traced not
wired, (c) needs a window. One question for him (two columns' spacing); one request to perf (the alert strip).

_Worker (godot-orders-4b), started 2026-10-07 ~13:45 PDT from `32748a0c`._

**Plan (in order):** O1 ten groups (keys 1–9, 0) → **O1b** (the orchestrator's new item from the lead, ahead of O2: two
interleaved squads ordered into lines drive through each other) → O2 ten chips (group bar rows; the panel at ten) → O3
the body at ten (pure ranks now; the ten-squad probe needs army's CP1: until then `SquadConsolidation` folds ten
squads to five) → O4 the radar and tactical map at 50 a side → O5 pins and the readout at ten → stretch (a)–(c).

**Decisions (one-line reasons):**
- **Group 10 is the 0 key**, shown as "0" on its chip and in every "press N" line: the keyboard's order, StarCraft's.
  `ControlGroups.MAX_GROUPS` = 10 (army reads it; becomes `Units.MAX_SQUADS` once CP1 is on main, TODO in the code).
- **The garage's squads land in groups by name** (Alpha … Juliet = 1 … 10; Juliet on 0), names compared as numbers
  ("Guns2" before "Guns10"): the garage shows no numbers, the NATO names are already in that order.
- **The group bar: two rows of five rather than narrower chips** (decided from the arithmetic, frames to follow):
  one row of ten is 1765 px at his 1854x1011 window against 1206 px between the radar and its mirror; two rows keep
  every chip's pictograms and its IDLE/UNDER FIRE word at the size he already reads; five or fewer stay one row,
  exactly as now. A squad wholly inside a bigger selection (Ctrl+A) is lit too, so ten selected read as ten lit chips.
- **Ranks fill front first** (ten Law wedges 3 + 3 + 3 + 1, the brief's shape: the most guns arrive on his click first;
  round 21's even deal would be 3 + 3 + 2 + 2, the same depth). His five are unchanged (3 + 2; gang vees 2 + 2 + 1).
- **Past six squads the slots are assigned by the Hungarian method** (least total driving, as the exhaustive search
  below seven): round 21's greedy deal sent an abreast army's west squads to the front across the middle ones.
- **O1b: interleaved squads are dealt by position for the order, the control groups are not rewritten.** Squads that
  will stand abreast are re-dealt by where their vehicles stand across the heading (pieces of the squads' own sizes,
  each keeping the number of the squad whose place it takes); his number keys still recall the squads he made, and the
  next order re-forms an element from its group. Squads that do not interleave are untouched.

**Baseline:** `32748a0c`, builder0, `make check exited 0`, 2211 passed 0 failed, 23 targets ALL JUDGED, thirteen lines
unmoved, determinism `762a0576f944f5b7`.

**O1b (his six on the Sumps): done, on main.** `SelectionSquads.untangle`: once the body's places
are laid (row or ranks; move, attack-move, any verb with a point), if vehicles of two DIFFERENT squads would cross
driving straight to their squads' places, those squads (only those: a knot of crossing squads) are dealt to their own
places by least total driving (Hungarian), which crosses no two paths; each piece keeps the number of the squad laid on
its place. `make interleaved-probe` (his six as two squads of three Retired APCs at their tick-4410 positions, line
picked, right-click at (96.0, 23.6) between his two points; `--untangle=off` = before; builder0 light lane, 3 repeats
per arm, at `8b488408`'s probe, real time):

| arm | crew paths crossing the OTHER line | crossing inside a line | hull contacts in 10 s (centres < 5.3 m) | blocked | all six within 6 m of their slots | pins |
|---|---|---|---|---|---|---|
| before (row, squads as they were) | **3 / 3 / 3** | 4 / 4 / 4 | 0 / 0 / 0 | 0 | 13.5 / 13.5 / 13.5 s | 2 |
| after (dealt) | **0 / 0 / 0** | 1 / 1 / 1 | 3 / 0 / 0 samples (one pair, 4.25–4.75 s, r1) | 0 | 14.0 / 14.0 / 13.5 s | 2 |

- The fix removes every crossing between the two lines. Within a line one crossing remains: two vehicles that stood
  one behind the other (0.7 m apart across the heading) swap seats under brains' "travel" seating (least SQUARED
  driving, chosen to keep a column's order); not a crossing through the other line.
- **The bumping did not reproduce on builder0** in the before arm (0 hull contacts at 5.3 m): the crews' steering
  avoids each other at full frame rate. His match ran at 4–10 fps on the Sumps (game_design.md, the choppy match), where
  the same crossing paths have far fewer steering ticks to avoid each other in. So the measure that moved is the
  crossing count; contacts are honest zeros on this machine. The closest approach between lines (from 2 s) is being
  added as a continuous measure.
- **What the chips and readout show mid-move (the orchestrator's check 1):** each group-bar chip reads ITS GROUP's
  vehicles (ElementAwareness describes control groups, not elements): squad 1's chip shows squad 1's three wherever
  they drive, MOVING because each has an order (its leader's), its health its own; so a chip never shows the other
  squad's states, and neither squad reads IDLE while its members drive in the other line. The movement readout is per
  vehicle. The pins are per element: `selected_elements()` takes any element wholly inside the selection, so the two
  dealt lines show two pins (before this, a dealt piece matched no group and the pins fell back to one per crew,
  round 19's "dots all over the map"; the probe checks `pins == 2`). The next order he gives group 1 re-forms its
  element from group 1 (and deals again if they still interleave).
- **Closest approach and mixed time (one click, from 2 s / whole drive, same runs re-done with the measures added):**
  before 5.5 / 5.5 / 5.7 m, lines mixed 2.75 / 2.75 / 2.75 s; after 5.1 / 4.5 / 4.5 m, mixed 1.0 / 0.5 / 1.0 s.
  The deal unmixes the lines sooner, but the boundary crews (the rightmost of one line, the leftmost of the other) now
  drive side by side a little closer: no better on proximity.
- **His real sequence (`make interleaved-probe REPLAY=1`: his six at their tick-3600 positions, his five clicks at his
  times; AUTO for two, then the COLUMN he picked at tick 3782 — the recording's tasks say column, not line; builder0
  light lane, 3 repeats per arm):** crew paths into the other line (all on his fifth click) before 3 / 1 / 1, after
  0 / 1 / 0; lines mixed before 5.75 / 6.0 / 4.75 s, after 8.5 / 6.0 / 3.5 s; closest between lines before 5.3 /
  4.8 / 5.2 m, after 5.2 / 5.1 / 5.3 m; hull contacts 0–1 samples in both; two pins on every order in both.
  **Reading:** the deal removes the crossings it can see (paths to each squad's PLACE); the one left in after-r2 is to
  a crew's SEAT, which in a column lies along the heading behind the place (brains' seating inside the line). On this
  machine at full frame rate neither arm bumps, and how long the lines drive mixed and how close they come do not
  measurably change (n = 3, spread larger than the difference). What made his columns crowd is more likely how close
  two columns are laid: a column has no frontage, so `row` puts the two centre lines one GAP_M (14 m) apart, and two
  three-vehicle columns snaking at 30 km/h come within 5 m. Not changed this round (a wider column gap is a layout
  change for every column order; the lead's eye first: question 1).
- **Dealing to the shapes' SEATS: built, measured, REVERTED** (the orchestrator's next step). Each squad's seats at its
  place (its shape at its pitch, facing the way it drives), crossings looked for to the seat each vehicle would take,
  a knot dealt over all its seats. On his replay (builder0 light lane, 3 repeats per arm, same runs): crossings into
  the other column 0 / 0 / 1 (before 3 / 1 / 1); **lines mixed 4.5 / 9.0 / 6.0 s (before 5.75 / 6.25 / 6.0 s);
  closest between columns 5.3 / 5.1 / 5.1 m (before 5.3 / 5.0 / 5.1 m)**: what he felt did not move. And it broke
  round 21's five-squad body (`test_five_squads_one_click_go_as_a_body`: "squad of Green_S1_1 stays exactly itself"):
  at seat level, five vee squads laid in ranks cross each other's seats in ordinary orders, so the deal reshuffled
  squads that were never interleaved. Reverted to the deal by places (the line case: 3 → 0; squads untouched when
  nothing crosses). On this machine the two columns drive mixed for ~6 s of his 45 s whoever is in which squad; the
  lever left is the spacing of two columns (question 1), or the crews' steering (brains').
- Tests: `tests/test_control_untangle.gd` (his six pure: between-line crossings 3 → 0; squads apart untouched; a body
  of six where only the two interleaved squads are dealt; through the controls: two lines, no crossing, two pins,
  groups unchanged).

**O1 + O1b GREEN, merged:** `8b488408` (builder0, `make check exited 0`, 2227 passed 0 failed, 23 targets ALL JUDGED,
thirteen lines unmoved, determinism `762a0576f944f5b7`; CPU-v-CPU never issues through these paths) → main `1655e93b`.

**O3 (done; numbers on main's merged CP1 tree, uncommitted trial merge, builder0 light lane):** ten gang
vees (`five-squads-series SQUADS=10`, 50 Rat Rods, vee, 150 m ahead) first stood two abreast in five ranks 50 m
apart: 250 m deep, so the floor behind a click 150 m from his base could not hold it and `fit_inside` slid the body
forward, the front rank **33.5 m past his click** and two rear squads ending farther from it than they started.
The orchestrator's ruling, in order: **(c) ranks of the same shape nest** — the rank behind steps back only as far
as keeps every slot one pitch (18 m for the gangs) from every slot of the rank in front (a vee's wings reach up beside
the vee ahead): **26 m a rank instead of 50 m, five ranks 104 m instead of 200 m** (`SelectionSquads.rank_step`,
`nested_offsets`; AUTO and mixed shapes step their depth plus a gap as round 21). Foundry vee, one run: depth 104 m,
**0.2 m past the click** (was 33.5), all ten end closer (was 8), none blocked (was 1–3), the last squad there in 17.75 s.
Parade (14 m pitch, three abreast): 61.5 m deep, nothing past, all closer, last in 14.75 s. **(a) is the fallback**,
in the words for him: "with ten vee squads, a short order puts the front a little past your click, because the
army is longer than the floor behind it". Not (b) (three abreast at 222 m: the outer squads at the side walls, round
20's complaint). His five vees nest too (2 + 2 + 1, two 26 m steps instead of 50 m). 
**O3 series** (`five-squads-series`, builder0 light lane, 3 repeats per cell, 150 m ahead, seed 3, on `436e09dc` + main
`7766f53c` merged uncommitted (CP1: ten squads); before = `NEST=off` (ranks a depth plus a gap apart), after = nested;
per repeat):

| squads, map, shape | arm | depth behind the click | **past the click** | squads ending closer | last squad there (s) | worst sideways 10 s | blocked |
|---|---|---|---|---|---|---|---|
| 10, foundry, vee | before | 166.5 ×3 | **33.8 / 33.9 / 33.8** | 8 / 8 / 8 | 64.0 / 15.5 / never | 50 / 60 / 50 | 0 / 2 / 2 |
| 10, foundry, vee | after | 104.0 ×3 | **0.0 / 0.2 / 0.2** | **10 / 10 / 10** | 14.0 / 18.8 / 19.8 | 52 / 20 / 20 | 0 / 0 / 1 |
| 10, parade, vee | before | 126.0 ×3 | 0 | 10 | 17.0 / 20.0 / 13.5 | 26 / 20 / 26 | 0 |
| 10, parade, vee | after | 61.5 ×3 | 0 | 10 | 18.0 / 12.3 / 17.0 | 29 / 26 / 19 | 1 / 3 / 3 |
| 10, foundry, AUTO | (no nesting: the leader picks) | 166.5 | **33.5 ×3** | 8 | 14.8 / 18.0 / 18.3 | 26 | 1 / 0 / 0 |
| 10, parade, AUTO | (no nesting) | 167.7 | **32.3 ×3** | 8 | 22.3 / 25.5 / 25.0 | 23 | 2 |
| 5, foundry, vee | before | 100.0 | 0.1–0.3 | 5 | 12.0 / 16.8 / 13.8 | 40 / 73 / 39 | 0 / 2 / 1 |
| 5, foundry, vee | after | 76.0 | 0.1–0.3 | 5 | 21.3 / 12.5 / 12.5 | 71 / 37 / 37 | 1 / 0 / 0 |
| 5, parade, vee | before | 42.2 | 0.4 | 5 | 18.0 / 11.3 / 11.5 | 22 / 42 / 18 | 0 / 1 / 0 |
| 5, parade, vee | after | 40.7 | 0.4 | 5 | 13.0 / 11.5 / 13.5 | 19 / 42 / 22 | 0 |

- **Ten vees on foundry, his playtest's case: the front rank is on the click again (33.8 → 0.2 m), every squad ends
  closer, every squad arrives (the before arm had one never and one at 64 s).** Five squads: unchanged within the
  spread (the nesting only shortens the body: 100 → 76 m).
- **Ten AUTO squads (his garage's default: the leaders pick their shape) still stand 32–34 m past a click 150 m from his
  base**: AUTO has no known shape to nest, so its ranks step a depth plus a gap and the body is longer than the floor
  behind the click: the ruling's fallback (a), in the words for him above. A click farther from his base is unaffected.
- Every cell dealt all its squads on the first order (ten: two rows of five laid into ranks; five: one row of five
  laid 2 + 2 + 1): the design (ruling above).
- Sideways in 10 s stays 20–60 m: the gangs fight the scout ahead under his attack-move (round 21's reading), and
  the deal moves a vehicle to the squad on its side.

**Frames (ten squads, 50 Rat Rods, on the same merged tree, looked at;
`_agents/streams/references/round22/orders/`):** `ten_desktop_selected.jpg` / `ten_desktop_5s.jpg` (his 1854x1011):
the bar's two rows 1–5 over 6–0, the panel "50 UNITS · 10 SQUADS" with one "x50" portrait, ten pins apart and
readable at 5 s; `ten_phone_selected.jpg` (1200x540, no touch scale: two rows fit, the chips' text small) and
`ten_phone_touch_5s.jpg` (1200x540 with `--ui-touch`, the phone's 1.5x: two rows of five, 700 of 1200 px, keys and
state words readable); `radar_squares_34_a_side.jpg` (Ctrl+A at 34 a side: one square per squad, not the blob).
Found in the frames and fixed: two dashed fire-arc edges per selected vehicle (a hundred lines at fifty selected):
past ten selected each keeps its facing arrow only. Still there (perf's, requested): the alert strip over the bar's
second row, and at phone aspect over the panel's header line.
The deal at ten **is the design (the orchestrator's ruling):** ArmyLayout starts ten squads in two rows of five (no
hulls overlap, brains measured), and two rows of five laid into ranks cross by construction whatever the gap, so the
first Ctrl+A order deals 6–10 of the 10 squads by position (their keys, chips and names untouched; the elements that
drive are re-formed for the order). Expected behaviour, not a finding.

**O2 (frames, ten squads, his window, on the trial merge):** the bar stands 1–5 over 6–0, group 10 shows "0"; the panel
says "50 UNITS · 10 SQUADS · HOLDING". Found and fixed: fifty of one type are ONE grouped portrait ("x50") and the
layout placed portraits only for two or more, so the panel was blank under his Ctrl+A (round 21's 25 Rat Rods too).
**Request to perf (sent via the orchestrator):** the alert strip (`EdgeMarkers._draw_alerts`, fixed `ALERT_Y`) is
drawn over the bar's second row, covering chips 7–9.

**O4 (done):** the radar's selection rings at fifty selected were one yellow blob (frame at 34 a side, the
largest the pre-CP1 budget gives: `control-scale-shots CONTROL_SCALE_BUDGET=11000`, builder0, 8_whole_army.png).
Past `Radar.RINGS_UP_TO` (10) selected, each selected squad gets one square round its dots instead and vehicles in
no squad keep their rings; group 10's label reads "0"; the selected set is a dictionary (50 x 50 array scans a frame
before). Frame after (same command at `883d0c05`'s tree): five boxes, one per group, instead of the blob. **Cost** (`make hud-profile`, lent, read-only; builder0
light lane, one run per arm, CPU v CPU at `CONTROL_SCALE_BUDGET=30000` = 57 a side, on the merged tree; before = the
same tree with `RINGS_UP_TO` effectively infinite): `radar.draw` 6.56 → 6.67 reference units a frame, the whole HUD
65.6 → 67.1 (machine load moved the reference 93.7 → 98.6 µs): no rise beyond one run's spread, and the squares only
draw past ten selected. Said to perf: nothing to absorb. The floor (`_draw_waypoints`, `_draw_facing`) past ten
selected: slot dots and facing arrows only, so it draws less with fifty selected.

**O5 (done):** the order markers are a ring of 48 reused oldest first; Ctrl+A over fifty dropped the first two
select pulses. Now `(MAX_GROUPS × MAX_MEMBERS + MAX_GROUPS) × 2` = 120. Pins: one per squad (element); at ten squads
they stand apart and read ("ATTACK-MOVE · 0/5 there · 65 m", `ten_desktop_5s.jpg`). Formation cards name the squads
standing in a shape as their keys with runs joined ("SQ 1–4 6 8–0"; ten did not fit as "SQ 1 2 … 10"). The task
preview (a tooltip loop per verb) does not change with the squad count.

**Stretch (a), AUTO's price: measured, NOT changed** (`five-squads-series FIVE_SHAPES=auto FIVE_REPS=1`, builder0 light
lane, at `883d0c05`'s tree, one run per map): under his attack-move the five AUTO gang squads end in coil (4–5 of 5)
and swarm (0–1); the body is 86 m across, nobody stands past the click, every squad ends closer. Pricing AUTO as the
widest shape the table can pick (the gangs' swarm, ≈ 137 m at 18 m) would put one squad per rank under the 200 m cap
(≈ 350 m deep for five, twice that for ten): far worse than the occasional swarm's wings reaching a neighbour's
(slots stay 14 m+ apart). Kept: AUTO priced as a line.

**Stretch (b), the army file's `formation`: traced, NOT wired.** Path: the doctrine squad's `"formation"` →
`Match.load_doctrine` → the legacy `Squad.apply_command` (its `formation` field) and nowhere else; `ControlGroups`
starts every group at AUTO. But the garage writes `Formations.DEFAULT` (wedge) on EVERY squad (`ArmyDraft.new_squad`)
and its screen offers no formation choice (`ArmyDraft.set_formation` has no caller), so the file's formation is the
garage's default, not his pick: wiring it into the groups would turn every squad of his from AUTO (the leader picks
by terrain and threat) into a fixed wedge. When the garage lets him pick a squad's shape (army's), the wiring is
three lines in `ControlGroups.from_squads` (`set_formation(number, squad.formation)` when it is a
`TacticsFormation` name and not the garage default).

**Stretch (c), `control_scale` timing on an idle builder0:** not run; builder0 has had every slot full of worker checks
all round. Needs a window from the orchestrator (`make remote T=control-timing` with the machine to itself).

**Questions for the lead:**
1. **Two squads in column side by side stand 14 m apart, centre line to centre line** (a column has no width, so the
   gap between squads, 14 m, is all there is between the two files; in your Sumps match the two files' vehicles came
   within 5 m of each other while driving). Would you rather two columns kept further apart (say 28 m: the two files
   read as two and drive without brushing), at the cost of a wider body? Recommended: try 28 m. Nothing changed
   until you say.

**Requests to other streams:**
1. (routed into army's CP1, done) `SquadConsolidation.MAX_SQUADS` folded ten garage squads into five; it reads
   `Units.MAX_SQUADS` now.
2. **perf (open):** the alert strip (`EdgeMarkers._draw_alerts`, fixed `ALERT_Y`) is drawn over the group bar's second
   row (chips 7–9) at his window and over the panel's header at phone aspect; put its bottom just above the bar's top.
3. (brains, answered by ruling) the ten-squad spawn in two rows makes the first Ctrl+A order deal its squads: design.
4. (the orchestrator, fixed on main `9ad6d65e`) `music_director.gd:616` index error every frame.

**Known issues:**
1. **Ten AUTO squads ordered less than ~200 m from his base stand 32–34 m past the click** (the ruling's fallback (a):
   AUTO has no shape to nest; the body is longer than the floor behind the click). Vee (or any one shape he picks for
   all) nests and stands on the click.
2. Two columns side by side are 14 m apart (question 1); the deal by places does not change how close two columns
   come while driving (his Sumps case, measured).
3. Within one line a seat swap can still cross two vehicles that stood one behind the other (brains' "travel" seating).
4. `control_scale` timing still unjudged (stretch c, needs an idle builder0).

**What to playtest (his eye is the check):** `make garage` → Road Gangs → CLEAR → tap the Rat Rod 50 times (ten squads)
→ FIGHT. Keys 1–9 and 0 select each squad (0 is squad 10; twice quickly centres the camera); Ctrl+0 / Shift+0 work like
the others. The bar shows two rows, 1–5 over 6–0. Ctrl+A: the panel reads "50 UNITS · 10 SQUADS" with one x50 portrait;
the radar shows one square per squad, not a blob; the floor shows each vehicle's slot dot, no web of lines. Pick Vee for
all (Formation panel), A, click 150 m ahead: ten pins in ranks of two, the front two on your click, nothing past it.
Then the same with AUTO: the front stands ~33 m past a click that close to your base (known issue 1). Two squads
standing mixed (survivors of two squads), ordered into lines: each line takes the vehicles on its own side.
Desktop frames: `references/round22/orders/ten_desktop_*.jpg`; phone: `ten_phone_touch_5s.jpg`.

**Merge notes:** changed in my paths only: `game/control/control_groups.gd`, `rts_controls.gd`, `selection_squads.gd`,
`two_squads_playtest.gd`, `squad_orders_playtest.gd`; `game/ui/group_bar.gd`, `selection_panel.gd`, `radar.gd`,
`control_hints.gd`, `tactical_map.gd`, `formation_picker.gd`; `game/theme/fx/order_feedback.gd`; `mk/command.mk`
(`interleaved-probe`, `SQUADS`, `NEST`, `REPLAY`, `FIVE_FLAGS`; `hud-profile`/`hud-digest` untouched); tests
`test_control_groups.gd`, `test_control_squad_ranks.gd`, `test_control_untangle.gd` (new), `test_control_form_squad.gd`,
`test_control_every_unit_on_a_key.gd`, `tests/support/{ten_gangs,interleaved}_army.json` (new). Shared:
`tests/test_every_unit_selectable.gd` (unowned; merged on main already). Frames: `references/round22/orders/*.jpg`
(5, 1.5 MB).
