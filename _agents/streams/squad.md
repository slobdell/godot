# Stream: squad (the formation he sees is the one the squad forms)

> Read [`doctrine.md`](../doctrine.md) *A plain move travels AS a formation* (round 12's travelling anchor: the
> mechanism, the three rules, the paired table, and its **Not done, deliberately** list — your backlog is that list),
> then the rest of `doctrine.md`; [`game_design.md`](../game_design.md) *Round 12 direction* (both parts) and the
> 2026-09-25 and 2026-09-20 formation notes in *Round 10/11 direction*; [`workstreams.md`](../workstreams.md)
> (round 12: ownership, C12.4, C12.5; round 10's R1, R2, R2a, R2b). **You own** `game/tactics/**`,
> `game/ai/{formations,squad,squad_tactics,tank_brain,element_feed,directives}.gd`, `doctrines/`, `mk/tactics.mk`,
> `tools/tactics/**`, `tests/test_tactics_*.gd`, `tests/ai_scenarios/`, `_agents/{doctrine,tank_brain,squad_ai_design}.md`.
> **Carve-outs into control's paths (no control stream runs; the orchestrator reviews at merge):** `game/ui/command_icons.gd`
> (the AUTO glyph and label) and the formation readout on the selection card in `game/control/` (the consumer of
> `UnitCommand.AUTO` there); and, only if S4's answer is "give it the anchor", one function routing a partial selection
> from `RtsControls.order_selection` into a transient element.

## The lead's direction

2026-09-26, playing: *"it seems to take a long time for units to form up in the desired formation. It's hard to tell if
the formations even work — I think they do but I think the units are just so inefficient at getting to that state that
it's almost unusable … I just started a game where my first action was to click a location for a squad, they were in
auto formation (which I assume is a wedge based on the UI), and they all split apart and navigated their own way to
the destination."* After the anchor: *"ok commit your changes, this is now really good."*

2026-09-25: *"are you saying that we're not adequately applying our squad properties to a unit I've regrouped as squad
1? … they're still not really forming up when I give them a formation to use"*.

2026-09-26, asking for this round: *"I believe direct path doesn't scatter of the last fix."*

## Where things stand (2026-09-26; verify before acting)

- **The travelling anchor is on `main`** (`0299e05e`, `Element._advance_transit`, `ElementPlan.stations_along`,
  `TankBrain._order_context` driving to the published station, `TRANSIT_ENABLED`); measured in `doctrine.md`'s paired
  table (builder0, 4 jittered seeds, yard + Terminus, both squads: stop time a wash, the shape 10–14 m mean station
  error against a 10.6 m pitch where before there was none). `make squad-settle TRANSIT=off` is the control arm;
  `make squad-transit-series` the paired series; `TRACE=on` prints the trace that found the three rules.
- **The AUTO icon lies** (`game/ui/command_icons.gd:396`: `var shape := "wedge" if formation == UnitCommand.AUTO else
  formation`). The doctrine picks a **column** for a plain move on *dense* terrain, and both the default arena and the
  Terminus classify as dense (cover features within 45 m: 5+). So on the maps he plays the card shows a wedge and the
  squad forms a column, which is exactly the sentence in his complaint ("which I assume is a wedge based on the UI").
  `Element.state()["formation"]` already publishes the leader's pick.
- **A G-chosen formation is overridden at the halt** (`ElementPlan._halt`, `element_plan.gd:564`): it takes the table's
  `hold` pick (coil, herringbone) and ignores `task.formation`, so a chosen wedge dissolves into a coil on arrival of a
  drills-on move. Round 11 (`db930f84`) made the task CARRY the shape (`ElementTask.formation`) so choosing one no
  longer dissolves the squad; the halt is the phase it missed.
- **The direct path — he is right for his selections.** Round 8 puts every spawned squad on a number key
  (`ControlGroups`, `groups.save(number, roster)`), and `RtsControls._is_task()` (`rts_controls.gd:578`) sends any move
  whose selection is a whole element or a whole control group down the TASK path, where the anchor lives. So a
  box-select of a whole squad travels as a formation. The direct path (`Orders._resolve_group`, one route per vehicle
  to its slot) is reached only by a **partial** squad, a **mixed** selection or a **shift-queued** order. Whether a
  partial selection deserves the anchor is a question (S4), not a defect.
- **The weak phase is the first seconds of a move from the spawn line** (an abreast line becoming a column): paths
  cross, ORCA yields, and on some seeds the middle pair stall together for several seconds (yard forward seed 1, both
  starts); under the anchor the stall also holds the squad back through the lag rule (yard forward arrival 1.6 s
  later). `doctrine.md` names the answer: **a fall-in rule** — a crew does not close on the line until the crew whose
  station is ahead of it has passed.
- **The 2026-09-26 session's own suggestion, recorded as a QUESTION:** whether *dense → column* is the right row for a
  plain move on the yard-type maps at all. The table's reason for a column in dense terrain is real (a column takes a
  corner); the maps are 240 m squares where a 60–150 m move rarely takes one.

## Backlog (in order)

**S1. The icon and the card tell the truth (C12.4).** For an AUTO selection, the glyph and label read
`Element.state()["formation"]` (the leader's actual pick, updating when it changes); for a G-chosen one, the requested
shape. Before the element exists (a numbered group with no task yet), show AUTO as "auto" — not a wedge — with the
doctrine's likely pick if you can compute it cheaply from `ElementSituation` without side effects, else the word. A test
that the icon for an AUTO squad on the Terminus reads `column`. Frames at his pose: the card during a plain move,
before/after.

**S2. A chosen formation is the shape at every phase (C12.5).** `task.formation`, when present, wins in `_plan_form_up`,
in `stations_along`'s shape and in `_halt`; the table decides only under AUTO. Test first: a wedge ordered with G on a
drills-on move is a wedge at t0, in transit and after arrival (extend `test_a_chosen_formation_*` from round 11 or the
transit tests in `tests/test_tactics_tasks.gd`). Then the drills: a `react_to_contact` may still change the shape (that
is the doctrine's job under fire); say in `doctrine.md` which phases the player's shape governs and which the drill
does, so the readout can say "wedge (yours)" vs "line (react to contact)".

**S3. The fall-in rule.** In `_advance_transit`/`stations_along` or the brain's station following: a crew whose
station is BEHIND another crew's station along the route does not close laterally onto the line until that crew has
passed its lateral position (or a bounded wait, never zero — lesson 17). Build it from the yard forward seed-1 trace
(`make squad-settle ARENA= DIR=forward METRES=80 SEED=1 TRACE=on`), which shows the middle pair tangling; then the
paired series (`make squad-transit-series`, both arms on the same seeds, 4+ seeds; add a `FALLIN=off` arm the same way
`TRANSIT=off` exists). Report stop time, arrival, the mean station error in transit and the first-10-s error
separately — the rule is aimed at the first seconds and must not cost the rest. Pre-register: the sim baseline does
not move (the CPU's tasks run drills and never take the plain-move path) — a move is a finding.

**S4. The partial selection, decided on the default path.** Reproduce what he does: `make skirmish`, box-select three of
a five-unit squad, right-click 80 m away; and box-select units from two squads. Record what happens (the readout, the
routes, the shape). Then decide, and write the reason in `doctrine.md`: (a) leave it — a partial selection is the
player asking for vehicles, not a squad, and the card already says "Part of Squad N: press N, or Form squad" (round
10's R1); or (b) give a multi-unit direct move a transient anchor. Recommended: (a) unless the frames say the scatter is
what he would notice; (b) means a transient element with its SOP off, formed on the order and dissolved on completion,
and it needs R1's UX to say which he has. Either way the roadmap line "the direct path still scatters" is replaced by
what you measured.

**S5. Is *dense → column* the right row for a plain move here?** Measure, do not opine: the doctrine table's row for
`move` × `dense` × each composition, on the yard and the Terminus, with column vs wedge as the two arms of the paired
series (same seeds): stop time, in-transit station error, and — the thing he actually sees — a frame at his pose at
t = 10 s and at arrival for each arm. Then either change the row with the reason, or keep it and make the icon (S1) carry
the reason ("column: dense terrain"). His words on time vs tidiness stand: *"a 4s slower march for a tidier traversal is
better, yes"* (round 9).

**S6 (stretch).** The mixed squad's 22–34 s stop times (a wheeled scout creeping after its order completes, round 10's
known issue) — the same in both arms of the transit series, so not the anchor's; if you have time, the trace and a
proposal to nav in Status, not a fix in nav's files.

## How to verify

- `make remote T=check` green on every named commit; `make tactics-test`; the three transit tests still pass with
  `TRANSIT=off` reproducing round 10's numbers byte for byte (the control arm is the proof the switch is live).
- `make squad-settle` / `squad-settle-series` / `squad-transit-series` on builder0, 4+ seeds, both arms on the same
  seeds, discordant pairs printed; every number with commit and machine.
- `make remote T=tactics-shots` and the skirmish at his pose; look at the frames.
- **Pre-registered UNMOVED:** sim baseline `01ab39b592cc9837` for S1–S4 (the CPU never takes the plain-move path;
  S2's `_halt` change reaches CPU tasks ONLY if a CPU task carries `formation`, which none does today — check that
  claim with `grep` before you rely on it). If it moves, say which item did and why; the orchestrator records it.

## Don't touch

`game/control/**` and `game/ui/**` beyond the two named carve-outs (and S4(b)'s one function if chosen);
`game/ai/movement.gd`, `pathing.gd`, `steering.gd`, `avoidance.gd`, `tank_motion.gd` (nav's); `game/camera/**`;
`game/theme/**`; `game/units/units.gd`.

## Waiting on the lead

Nothing blocks. S5's outcome and S4's decision go into Status with frames; if either is a taste call, a page with `db`.

## Status

_Worker, 2026-09-26/27 (in progress; every number carries its commit and machine; laptop traces are read, not reported)._

**Baseline:** `46bac1a3` on builder0: `>> remote: make check exited 0`, 1726 passed, 0 failed.

### Plan (the order taken, and why)

S1 → S2 (both small, and S2's "wedge (yours)" readout builds on S1's) → S3 (needs the trace) → S4 (a probe on the
default path) → S5 (reuses S2: a G-chosen shape now holds through every phase, so the two arms are two G orders) → S6.

### Done

- **S1 (C12.4) — the card shows the shape the squad forms** (`2d208035`). `CommandIcons.formation_readout`: under AUTO
  with an element the button draws and names the leader's pick (*"Auto: Column"*, live: the panel redraws each frame);
  his G choice reads as itself; a drill that has his squad in another shape reads *"Line: drill"*; before an element
  exists AUTO is its own glyph (a ring round an A), never a wedge. `selection_panel.gd` reads it (the carve-out: the
  consumer of AUTO on the card lives in `game/ui/selection_panel.gd`, not `game/control/`). Tests:
  `tests/test_tactics_formation_readout.gd` (5), including a real element on the yard AND the Terminus reading column.
- **Finding that corrects the brief (S1/S5):** `make tactics-terrain` (new, light): at the spawns only the **yard** is
  *dense*; the Terminus, pit, crossing and locks are *lanes*. And **no squad he fields uses the standard table**: a
  squad fights by its units' FACTION table, and the Condemned and the Law both end in a catch-all **column** in any
  terrain (the Syndicate's is a wedge, the gangs' a swarm). So under AUTO a Condemned or Law squad forms a column on
  every map, and the wedge the card showed was wrong for them everywhere. doctrine.md *Whose shape it is*.
- **S2 (C12.5) — a chosen shape is the shape at every phase** (`2d208035`). `_halt` keeps `task.formation`; the
  traveling-overwatch trail section takes it too; `ElementPlan.chosen_formation` is the one reading. A drill under
  fire still takes the drill's shape (the doctrine's job), and the card says so. Tests in `test_tactics_tasks.gd`
  (wedge at t0 / en route / at the halt and after; AUTO control arm still halts in a coil; a chosen line in transit and
  on the spot; a drill's shape reads "…: drill"). doctrine.md *Whose shape it is, phase by phase* (the table).
  **CPU claim checked:** no `ElementCommander` task carries `formation` (grep: the only `"formation"` keys a CPU sends
  are the opt-in legacy `CpuCommander`'s squad commands), so the halt change cannot reach a CPU element.

### In progress

- **S3 — the fall-in rule** (`0b0124da`, `9aed5a3f`; **shipped OFF** pending the series). `ElementPlan.fall_in` (pure,
  4 tests): in the first 8 s a crew whose sideways path would cross the lane of a crew seated ahead of it that has not
  passed it is held -- `lane` mode (keeps driving in its own lane) or `wait` mode (stands; not a laggard to the lag
  rule). **The trace says the brief's model of the stall is not what happens on the yard**: a top-down plot
  (`tools/tactics/plot_tracks.py` over the new `SETTLE_TRACK` lines) shows the anchor's route threading a ~5 m gap
  between the wreck at (9, 68) and the container stack at x = 17, twenty metres from the spawn; the "middle pair
  stall" is a QUEUE at that gap, while the tail crew takes a different gap west of the wreck and comes out ahead of
  them. Holding a crew in its own lane can aim it into the 20-ft container dead ahead of the spawn. Paired series
  queued on builder0 (`make squad-fallin-series`, and `FALLIN_ARM=wait`).
- **S4 — decided (a), with measurements.** See doctrine.md *A partial or mixed selection*. Builder0 series queued
  (`make squad-partial-series`).
- **S5** — tools built (`161465ef`): `make squad-shape-series` (column vs wedge ordered with G, same seeds) and
  `make formation-shots` (frames at his pose, 10 s and arrival). Queued on builder0.
- **S6 (stretch) — the trace (laptop, Terminus side, mixed, seed 1):** the squad declares arrival at 10.6 s and
  stops at 30.4 s, for three reasons: (1) both **scouts**, with NO order and no enemy anywhere, are handed `face`
  orders by their brains (HOLD/face, then ADVANCE/face: a refused advance becomes a face) -- a scout's gun is fixed
  to its hull, so round 8's "turret wheels decline a face" does not apply -- and a wheeled hull can only face by a
  multi-point turn, which WALKS it: 1.5 m → 8.6 m off its slot over 15 s at a steady 2.8 m/s; (2) an ifv stands wedged
  against a neighbour (`yielding/Green_S_3`) with its position fixed for 5 s while `estimated_velocity` reads 7.7 m/s
  (the post-`move_and_slide` velocity of a hull at full throttle into another), which the settle probe counts as
  moving; (3) the tank's order completed 18.3 m from its element slot. **Proposal (to nav, and partly mine):** (1) is
  decided in the brain (`tank_brain.gd`, squad's) and executed by `TankMotion` (nav's): either the brain stops asking
  a no-pivot hull to face an idle sector when nothing is in sight (a sim-baseline move, since CPU scouts face too), or
  nav bounds a multi-point turn's drift from where it started. (2) is a probe measurement question (mine): stop should
  read position change, not the velocity estimate.

### Questions for the lead

- **S4:** a partial selection's move (3 of a 5-unit squad) or a mixed one (units from two squads) still sends each
  vehicle by its own route -- measured and plotted. Your 2026-09-20 ruling (regroup with Ctrl+N or FORM SQUAD and it
  travels as a formation) stands and the card says so. Do you want a partial selection to travel as a formation too
  (a temporary squad formed on the order and dissolved on arrival), or is FORM SQUAD the answer?

### Merge notes (shared files)

- `game/ui/command_icons.gd` (carve-out): `formation_texture` AUTO glyph, `formation_readout`, the letter "A".
- `game/ui/selection_panel.gd` (the card's formation readout, the carve-out's consumer): `summary()` adds
  `result["formation"]`; the button draws it.
- `_agents/roadmap.md` item 10's table row: replaced by the measurement.

