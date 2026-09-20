# Stream: squad (formations that deform, arrive together, and never swap seats — A8 → A9 → A10)

> Read `HANDOFF.md`, `_agents/orchestration.md` (*The worker contract*), `_agents/game_design.md` (*Round 9
> direction*, *Ruling: offline compute is unlimited*), `_agents/workstreams.md` (*Round 9: the seven streams* — CP1,
> CP2, contracts S1, S3, S4 — and *Round 9 goal*), and `_agents/research_catalog.md` rows **A8, A9, A10** (with Part 2,
> the composition hazard). Your round-8 brief is archived at `_agents/streams/archive/round8/squad.md`; its Status
> holds the *Round 9 plan* table you wrote yourself, and this brief is that table made into a backlog.
>
> **You own** (unchanged from the round-6 table in `workstreams.md`): `game/tactics/**`, `game/ai/{formations, squad,
> squad_tactics, cpu_commander, tank_brain, directives, utility_curves, brain_variants, element_feed, matchups,
> difficulty, tactical_query, cover_map, fire_lanes, perception, suppression_feed, incoming_fire, ai_tick_cache,
> ai_explain_overlay}.gd`, `doctrines/`, `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`,
> `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,unit_ai,doctrine}.md`.
>
> **Invariant 0c governs this brief.** Every backlog item below names what it REPLACES, by file and function. You
> wrote those answers in round 8; this round holds you to them. *"Replaces: nothing"* is the answer the orchestrator
> interrogates.

## The lead's direction (2026-09-19)

Rulings already made that this round builds on, quoted from `game_design.md` and `research_catalog.md`:

- On element flow (round 8): *"a 4s slower march for a tidier traversal is better, yes."* — `ElementPlan.FLOW_ENABLED`
  stays true; A8's continuous deformation is the version of that trade that costs less than 4 s.
- On manoeuvre (round 8): *"making the units appear smart is better, so flanking and maneuvering is fine."* — a
  flanker carrying its target is obeying. The boundary is *manoeuvring is smart, churn is not.*
- The round's headline, unchanged since round 7: *"they still generally don't do what I command them."* A9's bounding
  overwatch is the single row that most directly buys his stated goal of *base-of-fire-and-manoeuvre legible to a
  spectator*.
- Round 9's new item that reaches you: *"We need to do proportional, real-world relative sizing for all of our
  vehicles."* The scale stream resizes the roster (CP2); **formation slot spacing must be a function of the members'
  hulls before that lands**, or every formation will overlap the day it merges.
- On per-faction gains (round 6, by name): *"we might even be able to differentiate units of different factions by PID
  values."* — the stretch item.

## Where things stand (surveyed 2026-09-19, on `main` at `f49aa08a`)

**What round 8 landed** (all on `main`, archived brief for detail): orphans consolidated (`SquadConsolidation`, 0
keyless units every faction × 3 seeds); an explicit attack order aims every drill at the task target
(`test_attack_order_obeyed`); a wheeled hull with a turret gets `stop` instead of `face` (`d8581532`); rig placement
in `ArmyLayout` (rank overhangs, anisotropic pitch, deploy guard); the acquire-dwell veto **measured and reverted**;
`COMMIT_BONUS` 1.15 → 1.35 adopted then **reverted to 1.15** (`game/ai/tank_brain.gd:41`; 1.35 survives only as
variant `x5c` in `brain_variants.gd:75`).

**The commit-bonus knee is now combat's problem, and your two scenarios are its acceptance test.** 1.35 halved the
churn metric and a 48-match ladder said it does not lose — and then `scenario_squad.gd::test_a_squad_focuses_its_fire`
(focus share fell to brains-alone) and `scenario_cp2.gd::test_a_scout_works_onto_a_tanks_engine_deck` (41 hits / 23 on
the deck → 3 / 0) both failed on it. Catalogue **A2** (combat) replaces the flat bonus with a state-dependent
switching cost, and **those two scenarios are A2's pre-registered falsifier.** Keep them green, keep them honest, and
do not tune them to make anyone's number look better. You do not touch `COMMIT_BONUS` or `CombatMotion.COMMIT_BONUS`
(`game/ai/combat_motion.gd:58`) this round.

**Where the code you are replacing lives today:**

| Row | What it replaces | Where |
|---|---|---|
| **A8** | rigid offsets scaled by ONE spacing; "shrink the whole rank to fit" as the only deformation | `TacticsFormation.group_offsets()` (`game/tactics/tactics_formation.gd:294`), `offsets()`/`offset()` (`:61`, `:70`, one scalar `spacing`); `ArmyLayout._scale_for()` (`game/tactics/army_layout.gd:195` — the round-8 plan called it `ElementPlan._scale_for`; it lives in `ArmyLayout`). `ArmyLayout`'s round-8 anisotropic pitch (`spacing` across, `deep_pitch` along, `:97–100`) is already a fixed diagonal 2×2 — A8 makes it continuous and corridor-driven |
| **A9** | pacing toward the laggard by heuristic; bounding with no phase state | `Element._pace_leader_for_flow()` (`game/tactics/element.gd:202`, `FLOW_LAG_SLACK_M` 6 / `FALLOFF_M` 20 / `MIN_PACE` 0.75), `Element.form_up_eta()` (`:223`, `FormUp.group_eta` = the worst ETA), `FormUp.paces()` (`game/tactics/form_up.gd:42`); the implicit `bounding_overwatch` technique in `ElementPlan._plan_movement` (`game/tactics/element_plan.gd:143`, `:487`, `:529`) — halves swap by leg with nothing guaranteeing anyone is stationary |
| **A10** | Hungarian matching plus two hysteresis patches | `TacticsFormation.seat()` (`tactics_formation.gd:346`): `_hungarian(cost)` at `:386`; `STABLE_MARGIN` 0.5 (`:325`, applied `:405`); the `fixed` flag (`:405`, set by `ElementPlan._group(..., fixed)` `element_plan.gd:626–633`, added round 7 `3a0590e1` because seating re-shuffled around CPU drift). **Both patches are symptoms of what A10 replaces. They are deleted with it, not layered under it** |

**Spacing today is a doctrine number, not a hull number.** `DoctrineTable.SPACING_DEFAULTS` = open 14 / lanes 11 /
dense 8 m (`game/tactics/doctrine_table.gd:86`), `TacticsFormation.DEFAULT_SPACING` 12 m, and `Element.formation_group()`
hands `_doctrine().spacing("open")` straight to the formation (`element.gd:229`). The only place hull size reaches
spacing is `ArmyLayout._shape()` (`army_layout.gd:150–170`: `floor_m = max(5, widest + HULL_CLEAR_M)`, `deep_floor =
longest + HULL_CLEAR_M`) — the start-of-match layout, not the moving formation. **After CP2 a 14 m rig and an ~8 m
bus at 8 m "dense" spacing overlap nose to tail.** That is backlog item 1.

**Aim A8/A9 at the light hulls.** combat measured in round 8 (its numbers, cited from
`_agents/streams/references/round8/combat/` with commit and machine — re-quote from there, not from here): under
orders the 14 m War Rig converts **0.95** of path to net displacement and oscillates in **0.9%** of windows, the best
of any gang type; the gang **scout** is the shuffler at **0.68** and **13.3%**. Formation work that assumes the big
hulls are the coherence problem is aimed backwards.

**Instruments you have:** `make tactics-test`, `tactics-drills`, `tactics-measure`, `tactics-ladder`,
`squad-coherence` (off-slot, thrash, drill flip-flops), `squad-decisions` (option/target switches vs motion inside a
decision, A→B→A reversals) — all in `mk/tactics.mk`; arena's `make nav-maze` (`mk/arena.mk:56`) for a defile; nav's
`nav-fight` / `nav-fight-maps` for the fight configuration. **From CP1, metrics' `tools/metrics/` (contract S3) is the
only source for affine formation residual, cusp density, displacement efficiency and spectral arc length** — and
`ai-scenarios` is still not in `make check` (lesson 42): baseline it before you touch anything (lesson 38).

## Backlog (in order)

Each item: a failing test or a before-measurement first, then build, `make remote T=check`, smoke like a player,
commit, Status. **The K1 guarantee holds throughout**: every unit steers toward a new order within
`Orders.RESPONSE_MS` (100 ms) — `tests/test_control_response.gd:100` and `test_control_commands.gd:140` must stay
green, unweakened. **Pair every ladder with a behaviour assertion and prefer the assertion when they disagree**
(lesson 150). **Nothing here touches nav's velocity layer** (`movement.gd`, `combat_motion.gd`, `steering.gd`,
`tank_motion.gd`) — A7 is rewriting it; you hand down goals, slots and a `facing`, as before.

### X1. Slot spacing is a function of the members' hulls (small; first; what CP2 needs)

**Replaces:** the scalar doctrine spacing as the *only* input to `TacticsFormation.place()` / `offsets()`.
**Do not replace** the doctrine's `spacing_m` table — it stays as the *tactical* spacing (open / lanes / dense); the
hull floor sits under it.

- Derive a per-formation floor from the members: side by side a vehicle needs its width plus a clearance, nose to tail
  its length plus a clearance — the same rule `ArmyLayout._shape()` already applies at deploy, hoisted to where
  `TacticsFormation.offsets()` lays slots, and **anisotropic** (across vs along the heading), because a column of rigs
  needs length and a line of rigs needs width. Read `hull_size` through `Units.stat` — never copy it (Invariant 0).
- The effective spacing is `max(doctrine spacing, hull floor)`, per axis. Say so in `Element.state()` so control's
  readout can show it.
- **Test first, deriving the expectation from the catalogue** (lesson 3): for every shipped formation × every faction's
  five-unit squad, the closest pair of placed hull boxes (`TacticsFormation.closest_pair`, `:204`, extended to boxes) is
  ≥ the clearance — and the test reads `Units.PROFILES` so **CP2 changes no code here and the test keeps passing on the
  resized roster by construction.** Mutation-check it: shrink the floor and it must go red.
- Also: `CoherenceProbe.OFF_SLOT_SPACINGS` (`game/tactics/coherence_probe.gd:25`) measures "off slot" in doctrine
  spacings; make sure a hull-floored spacing does not silently change what the probe calls off-slot. Print the
  spacing it resolved to.
- Merge note: `ArmyLayout` should call the same floor rather than keep its own copy — one derivation, two callers.

### X2. A8 — affine deformable formations

**Replaces:** `TacticsFormation.group_offsets()`'s rigid offsets × one spacing, and `ArmyLayout._scale_for()`'s
uniform shrink. A uniform scale is the degenerate affine transform; A8 generalises code that exists rather than sitting
beside it. **The nominal shape tables stay**; the transform is what changes.

- A formation is a nominal shape plus a per-element 2×2 transform (lateral compression, longitudinal elongation, and
  the shear a heading change needs), **continuous in the corridor width**: a wedge becomes a column through a defile
  and re-expands after, without dissolving and without re-seating (A10 handles the seats; until it lands, keep the
  seating fixed through a deformation).
- Corridor width comes from nav's layer: `Movement.state(unit)` (contract N1) and the navmesh clearance it reports
  (`movement.gd:42`, agent radius 2.0 — after CP2, ask nav what it reports for a wider hull; do not read the navmesh
  yourself unless nav says the seam is not there, and then record the request). Where the width is unknown, the
  transform is the identity: the formation must never be *worse* than today for lack of a number.
- Closed-form 2×2 algebra only; no iteration to tolerance (determinism, `determinism.md`).
- **Before building, measure today:** slot crossings and rank inversions through a defile (the maze via `make nav-maze`,
  yard's bridge, pit's gaps) and recovery time after it, so the falsifier has a before. **After CP1**, the affine
  residual per element comes from metrics' tool, not from a number of your own.
- **Falsifier (pre-registered, catalogue A8):** zero slot crossings / rank inversions during defile passage, and
  post-defile recovery time **−60%**, on the maze and yard, ≥ 5 seeds, both machines named. If crossings go to zero
  and the march gets slower than the lead's 4 s allowance, say so rather than hiding it in the mean.
- The lead already ruled the trade (*"a 4s slower march for a tidier traversal is better, yes"*); you are buying the
  same tidiness for less.

### X3. A9 — time-synchronised co-arrival, and bounding overwatch as an explicit two-phase machine

**Replaces:** `Element._pace_leader_for_flow()` and `FormUp.paces()`/`group_eta()` (pace toward the laggard by
heuristic → parameterise every member's longitudinal profile to hit phase waypoints at the bottleneck arrival time,
from nav's `Movement.eta()`); and the implicit `bounding_overwatch` in `ElementPlan._plan_movement` (→ an explicit
two-phase state: one fire-team stationary on overwatch while the other advances, alternating every 5–8 s, with the
phase in `Element.state()` so control can draw it and the announcer can call it).

- Tick-count phase synchronisation, not wall clock (Invariant 7).
- The laggard drives flat out and nobody is paced below `TacticsFormation.PACE_FLOOR` (the round-7 rule in
  `form_up.gd:39–41` stays true).
- The K1 100 ms guarantee is about the *first* response to an order; co-arrival slows the *cruise*, never the start.
  Write the test that isolates that (lesson 47: mechanism, not outcome).
- **Before building, measure today:** inter-element arrival dispersion at an objective line, and the share of squad
  firepower stationary per tick during an advance, on today's code (`tactics-measure` or a new probe in
  `tests/ai_scenarios/`).
- **Falsifier (pre-registered, catalogue A9):** arrival dispersion **> 12 s → < 1 s**, and **≥ 50% of squad firepower
  stationary at every tick** of a bounding advance. And the exchange ratio must not fall: an overwatch that never
  fires is a parked squad. `test_the_overwatch_element_covers_from_cover` (`scenario_squad.gd:81`) is the existing
  behaviour assertion; extend it, do not replace it.
- Lesson 17 applies: before adding phase logic, log what *selects* the technique each tick and check nothing upstream
  (`react_to_contact` restarting, `near_ambush` pre-empting) keeps cancelling it. Round 4 found this three times.

### X4. A10 — deterministic auction assignment with an incumbent bonus

**Replaces:** `_hungarian(cost)` inside `TacticsFormation.seat()`, **and both hysteresis patches** — `STABLE_MARGIN`
and the `fixed` flag (delete the constant, the flag, its plumbing through `ElementPlan._group`, and the `opts["fixed"]`
callers). If a caller still needs "hold this seating whatever it costs", that is a bug in the incumbent bonus, not a
reason to keep the flag.

- Integer utilities (scaled by 10⁴), a fixed ε, a hard iteration cap, a bid queue ordered by unit name on ties, warm-
  startable from the previous seating — the four determinism properties the catalogue chose auction for. Rules 1–3 of
  `seat()`'s precedence (leader keeps slot 0; toughness vs exposure tiers via `TIER_COST`; then least total driving,
  which is what makes paths not cross) are **kept as the cost structure**; only the solver and the hysteresis change.
- The incumbent bonus is the principled form of both patches: a re-solve cannot swap two units for a marginal gain
  because the seat a unit holds is worth its switching cost.
- **Before building, measure today:** spurious re-assignments under a small perturbation (nudge every member 0.5 m,
  re-seat, count changes) and path-crossing assignments on a formation change, on today's `seat()`.
- **Falsifier (pre-registered, catalogue A10):** zero path-crossing slot assignments on a formation transition, and
  spurious re-assignments under a small perturbation at **0%**; and the CPU five-squad idle-order count that `fixed`
  was added for (round 7: 4–6 → 0 on the laptop) must still be 0 without it. `test_a_move_order_beats_every_brain_state`
  and `test_attack_order_obeyed` stay green.
- **Composition (0c):** A10 and A8 both touch seating during deformation. Land A8 with seating pinned, then A10, then
  re-run A8's crossing count with A10's solver. The two are sequenced, not merged in one commit.

### X5. The facing on holds and stations stays populated

Not a build; a guard. `TankBrain.intended_facing()` (`tank_brain.gd:2351`) and `Squad.apply_command`'s
`facing_on_arrival` (`squad.gd:136`) are today the only *live* sources of a `facing` on an order in a real match —
round 8 found nav's arrival arc reads `aimed 0 / refused 0` in every CPU fight because nothing else sets one. control's
round-9 right-drag adds the player's facing as the second live source. **Write the test that asserts a squad hold and
an ambush line issue orders carrying `facing`**, so the pair stays measurable, and record refusals **by reason** so
your round-8 prediction (*"6.5 m assembly spacing refuses most slot gates"*) is falsifiable. Re-run nav's `make
nav-facing` after X1 (the floor changes the assembly spacing).

### X6 (stretch). Per-faction PID gains, measured

`ControlGains.FACTIONS` already exists (`game/ai/control_gains.gd:15–34`, nav's X8, with `test_station_keeping.gd`
`MEASURE station_faction` lines). What is missing is the measurement that says it is *real*: identical armies with
different gains, on the merged tree, after CP1 — do they win equally often, and does a spectator see a difference
(metrics' spectral arc length and cusp density per faction)? If they look the same on screen, say so; the lead asked
for it by name and deserves the honest answer, not flavour.

## How to verify

- `make remote T=check` on every merge candidate; iterate locally with `make tactics-test` and a `FILTER=`; **never
  claim readiness from a filtered run** (lesson 45).
- `make ai-scenarios` — baseline the count on a pristine tree first (round 7 left it at 45 passed, 2 pending on the
  laptop; re-establish on `main` at your start commit), then attribute only the delta.
- `make squad-coherence EXTRA="--green-elements --rust-elements"` and `make squad-decisions` before and after each of
  X2–X4, same seeds, same machine, commit named. `make tactics-ladder` (heavy: `make remote`) as the safety net only.
- **From CP1:** metrics' tool for the four trajectory quantities. **From CP2:** `git merge main`, re-run X1's test
  (it must pass unchanged), then re-take every spacing- or hull-dependent number. **Nobody publishes a number across
  either checkpoint.**
- Smoke like a player: `make skirmish`, select a squad, order it through the maze's or yard's narrowest gap — it should
  narrow to a column and re-open, nobody swapping places; order a bounding advance (`tactics-shots` frames on builder0)
  and look at the frames: at every moment half the squad is stopped and shooting.
- Every number: commit, machine, workload, sample size (lesson 10). Laptop ≈ 2.75× slower than builder0.

## Don't touch

- nav's `game/ai/{movement,avoidance,pid,control_gains,pathing,steering,combat_motion,order_controller,order_feed}.gd`,
  `game/tank/tank_motion.gd` — A7/A11/A1/A4 are rewriting the velocity layer; you consume `Movement.state/eta`.
- combat's `COMMIT_BONUS` seams (`tank_brain.gd:41` is your file, but that constant and `combat_motion.gd:58` are A2's
  subject this round; leave them at 1.15 / 0.35 and let combat's A2 replace them).
- `game/units/units.gd` — scale's this round (S1); read `hull_size`, never copy it.
- control's `game/control/`, `game/ui/`, `game/camera/`; feel's `game/theme/`; metrics' `tools/metrics/`.
- `tests/baselines/sim_state_hash.txt` — your changes move it; say so in your green report, do not record it
  (Invariant 2).

## Waiting on the lead

_Nothing at launch._ The rulings this brief rests on are already made (flow, manoeuvre, sizing). If X2 finds the
lead's 4 s allowance is exceeded, that is a question for him, recorded here with the numbers.

## Status

**In progress** (started 2026-09-20, worktree `godot-squad`, branch `stream/squad`, from `9f864474` = `main`).

### Read this first if you are picking this up cold

- **`6e0c9968` is committed on `stream/squad`: X1 + the leash change, deliberately small so it can be merged alone**
  as an early checkpoint (the orchestrator's instruction) and cherry-picked by nav for measurement. Its
  `make remote T=check` on builder0 was started from exactly that tree; **the hash is only green when the wrapper's
  own `>> remote: make check exited <N>` line says so**, and until then it is a candidate, not a result. nav and the
  orchestrator are both waiting on that hash.
- **The working tree on top of it holds X5, X2 (A8) and X3 (A9), plus `slots_asked` and the `motion` line for nav,
  uncommitted**, all green on narrow local runs (table below). It needs its own `make remote T=check` before it is
  committed and handed over.
- **X4 (A10) is not started.** Its before-measurements are taken (below). Its implementation and its test are written
  out in this session's scratchpad (`apply_x4.py` and `x4/test_tactics_seating.gd`) — **a scratchpad does not
  survive**, so if they are gone, the design is in this Status and in the catalogue row and it is a rewrite, not a
  recovery. The test is deliberately NOT in the working tree: it asserts A10's falsifier and is **red before A10**, so
  it travels in A10's own commit rather than turning the A8/A9 commit red.
- **Order matters (Invariant 0c):** A8 lands with seating pinned, then A10, then A8's crossing count is re-run with
  A10's solver. Do not merge them in one commit.

### Plan (ordered, smallest foundation first)

| # | Item | Why here | State |
|---|---|---|---|
| 1 | **X1** slot spacing from the members' hulls | CP2 needs it and everything below lays slots through it | in progress |
| 2 | **X5** the facing guard (a test, no build) | small, independent, and X1 changes the assembly spacing it predicts about | queued |
| 3 | **X2** A8 affine deformable formations | the transform generalises X1's diagonal pitch; needs X1's per-axis pitch to exist first | queued |
| 4 | **X3** A9 co-arrival + explicit two-phase bounding | independent of X2, but its before-measurement wants a stable formation geometry | queued |
| 5 | **X4** A10 auction seating + delete both hysteresis patches | 0c: A8 lands with seating pinned, then A10, then re-run A8's crossing count | queued |
| 6 | **X6** (stretch) per-faction PID gains, measured | needs CP1's metrics and a merged tree | queued |

**Decisions taken where the brief left a choice** (one line each):

- **X1 is anisotropic by scaling the shape, not by rewriting each shape's formula.** Every shape in
  `TacticsFormation` is homogeneous of degree 1 in spacing (`ArmyLayout` already relies on it), so a per-axis pitch
  is the shape at the along-axis pitch with the across axis scaled by the ratio — exact, one place, and it *is* the
  degenerate diagonal 2x2 that X2's affine transform generalises. When the two axes are equal it is the old code
  path unchanged, bit for bit.
- **The clearance rule for the test is the separating axis**, not centre distance: two hull boxes are clear when
  either axis separates them by the clearance (side by side needs width, nose to tail needs length), so the pair's
  clearance is the larger of the two axis gaps.
- **`CoherenceProbe.OFF_SLOT_SPACINGS` keeps measuring in DOCTRINE spacings** (so round-8 off-slot numbers stay
  comparable) and the probe now prints the effective pitch it resolved to, per element, so a divergence is visible
  rather than silent.

### Done so far

**X1 — slot spacing is a function of the members' hulls.** `TacticsFormation.pitch(members, spacing)` is the doctrine's
tactical number raised per axis to `hull_floor` (widest width across the heading, longest length along it, each plus
`HULL_CLEAR_M` = 2 m). `offsets_at` lays the shape at that per-axis pitch; `place()` resolves it and every entry now
carries `"pitch"`. `Element.state()` publishes `"pitch": [across, along]`.
**Replaces:** the scalar doctrine spacing as the only input to `place()`/`offsets()`, and `ArmyLayout`'s private copy of
the hull floor — `ArmyLayout._shape_of` now calls `TacticsFormation.hull_floor`/`hull_extent`, and its pass-2 manual
`stretch` is deleted because `place()`'s per-axis pitch IS that stretch (verified equal: ArmyLayout passed
`spacing = max(squad x scale, floor_m)` and `deep_pitch = max(spacing, deep_floor)`, which is exactly what `pitch()`
resolves to, so the deploy layout is unchanged to the bit).
**Pre-registered — AND WRONG, retracted here with the reason, because the reason is the interesting part.** I wrote
that X1 does not move the sim baseline, on the grounds that *"the baseline match fields only `tank` hulls"*. **It does
move it: builder0 reports `04414f5d6a6dfa7c` → `d4c049819a5833d3`.** The prediction came from **lesson 137**
(*"⚠ `sim-baseline` ONLY FIELDS TANKS"*), and **round 8 superseded that lesson and I did not check.** combat widened
the match precisely so it would stop being blind, and it now fields
`tank, gang_tank, scout, artillery, syn_scout` against `law_tank, tank, gang_scout, ifv, syn_scout` — every
locomotion × mount combination, and **`gang_tank` is in it deliberately** because, as that doctrine's own note says,
*"it is the longest hull in the game and the one whose box most recently changed"*. The 14 m War Rig is the ONE hull
whose floor binds against every doctrine spacing. So X1's geometry is visible to the baseline **by construction**,
which is the property combat built it for.
**Worse, my own brief told me so** — *Where things stand* quotes the widened match two paragraphs above the sentence
I relied on. I read the lesson and not the update. **The failure mode: a lesson stated as a standing warning
(`⚠ ONLY FIELDS TANKS`) outlives the thing it warned about, and reads as current because warnings do.** Lesson 137
needs *"superseded in round 8"* written into it, which is the orchestrator's file to change.
**What this does not change:** the geometry is still unchanged for `tank`-sized hulls —
`test_a_formation_of_small_hulls_is_laid_out_exactly_as_before` asserts it slot for slot — and the move is the rig's
pitch going from 14 m to 16 m along the heading, plus the leash now reaching `bound`/`maneuver` roles. Both are
deliberate. **Per Invariant 2 I do not record it; the orchestrator does, in the same session as the merge, and the
merge's subject says it moves.**

**Superseded pre-registration (kept for the record):** X1 does **not** move the sim baseline. The baseline match fields only `tank` hulls,
whose floor is 4.6 m across / 6.0 m along against an 8-14 m doctrine spacing, so the floor never binds and the scalar
code path is taken unchanged. `test_a_formation_of_small_hulls_is_laid_out_exactly_as_before` asserts that by
comparing `offsets_at` against `group_offsets` slot for slot. The only formations that change today are the War Rig's
(16 m along) and the Resupply Tanker's in `dense` (9 m) — and after CP2, the whole mid-roster, which is the point.

**X1 knock-on, and it is the number nav asked for.** `TankBrain.SLOT_LEASH`'s own comment said *"about one formation
spacing"* and the spacing is no longer one number, so `TankBrain.slot_leash(element)` derives it from the element's
pitch (`max(pitch.x, pitch.y, SLOT_LEASH)`) and `ElementFeed` carries the pitch. It is **exactly 14.0 m for every
squad whose hulls fit inside the doctrine spacing**, which today is everything but the rig, so nothing regresses.

**X5 — element orders carry a facing.** `ElementPlan._order` takes one; a halt's crews get their sector of fire (via
`place()`'s documented `halt` option, which `_group` now actually passes — it never did, so `entry["facing"]` was the
direction of travel and the halt expressed its sectors only by driving `FACE_LEAD` metres along them), a firing line's
crews keep the sector they were put there to watch, and a covering crew is told the way it covers. `Element._issue`
puts it on the K1 command as `facing: [x, z]`, and `Element.state()` counts `facings_issued` so *"a squad hold issues a
facing"* is falsifiable in a real match and not only in a unit test. A **move** order deliberately carries none: on the
move the facing is the direction of travel, which nav derives from the path, and an element that set one on every move
would fight nav's arrival arc for the last leg. That pair — my facing, nav's arc — is what read `aimed 0 / refused 0`
in every round-8 CPU fight.

**X2 — A8, the affine deformable formation.** `fit_to_corridor(members, formation, count, spacing, corridor_m, shear)`
→ `{pitch, file, shear, squeeze, fits}`, applied by `offsets_deformed`. Continuous and monotone in the corridor width;
an unknown corridor is the identity, on X1's code path.
**Replaces:** `group_offsets()`'s rigid offsets scaled by one spacing, and `ArmyLayout._scale_for`'s uniform shrink as
the only deformation (a uniform scale is the degenerate case of this transform).
**The design finding, and it is the important part of X2:** *a pure 2x2 cannot turn a wedge into a column.* A wedge has
pairs of slots at the same depth (slot 1 at −0.9 s, slot 2 at +0.9 s, both at y = s); no matrix separates two points
that differ only across the heading while squeezing that axis toward zero, so at the limit they land on top of each
other. A8's headline claim is false for an affine map alone, and a version that took it literally would have stood its
own hulls inside each other in exactly the narrowest corridors — the failure X1 exists to prevent. So the deformation
is **a shape morph plus a diagonal matrix**: the nominal shape is pulled toward single file (`file`), its ranks
splitting apart *along* the heading before the shape closes *across* it, then scaled per axis and sheared. The file's
target order is the shape's **own depth order**, not the slot index — a vee has slots ahead of its leader, and filing
those to `(0, index)` would drive slot 1 from in front of the leader to behind it, which is a rank inversion and is
the thing A8's falsifier forbids. Every slot keeps its index, so **zero slot crossings and zero rank inversions hold by
construction**, and `tests/test_tactics_deform.gd` sweeps 15 corridor widths x 11 shapes x 5 squads x 3 terrain
spacings asserting hull clearance, depth order and frontage monotonicity. A corridor too narrow for even the tightest
clear deformation returns `fits: false` rather than overlapping hulls. A halt does not deform.

**Corridor width: nav's seam is not there, so I measured it here and this is the request.** `Movement.state()`
(`game/ai/movement.gd:9-12`) reports phase, ETA, remaining metres, path points, blocker, goal and stall — **no
clearance**. Per the brief's instruction in that case, `SlotGround.corridor_width(node, from, to, heading)` measures
the standable width across the heading off the navigation mesh (bisected, narrowest of three samples along the leg).
`SlotGround` was already the one seam in this stream that asks the navmesh "can a vehicle stand here", and its own
docstring says it is the line to change when nav grows a query. `Element` takes **one measurement per leg**, not per
update (~40 navmesh queries, and a leg is 22-45 m of driving).

### X3 (A9) is built

**Part A — co-arrival is one rule now, on a tick-counted bottleneck.** `FormUp.bottleneck_ticks(etas)` is the
element's bottleneck arrival time in **ticks** (Invariant 7: tick-count phase synchronisation, not wall clock), so
every member's pace is a ratio of two integers and cannot drift with float order. `FormUp.paces` paces every member —
the leader included — by its share of it.
**Replaces:** `Element._pace_leader_for_flow` and its three constants (`FLOW_LAG_SLACK_M` 6 / `FLOW_LAG_FALLOFF_M` 20
/ `FLOW_MIN_PACE` 0.75), **deleted**. Two rules paced the same vehicle by different arithmetic — `FormUp.paces` by
ETA share and that one by how far the worst follower trailed its follow offset — and one bottleneck is what A9 is.
The K1 100 ms guarantee is untouched by construction: `PACE_NEAR` still short-circuits a member near its slot to full
speed, and the laggard is always 1.0, so co-arrival slows the **cruise**, never the start.

**Part B — bounding overwatch is an explicit two-phase machine**, with the guarantee inside it rather than hoped for.
`ElementPlan.bound_teams(ordered)` → `{teams: [Array, Array], base: Array}`; a phase lasts between
`BOUND_MIN_TICKS` (5 s) and `BOUND_MAX_TICKS` (8 s) — the minimum stops a shimmer when both teams close up at once,
the maximum stops a team that never closes up from parking the element (lesson 17: the gate above a behaviour must
not be able to cancel it forever). `Element.state()` publishes
`bound: {phase, since_tick, movers, overwatch, base, stationary_share}` so control can draw it and the announcer can
call it, plus `bottleneck_ticks`.
**Replaces:** the implicit technique in `_plan_movement` — `bounding` as a bare 0/1 with halves swapping the moment
the movers closed up, nothing guaranteeing anyone was stationary and no phase length at all.

**The falsifier's wording is why the shape changed, and that is recorded deliberately.** A9 pre-registered *"≥ 50% of
squad firepower stationary at every tick"*, and two alternating halves of an **odd-sized** element cannot meet it:
`split` gives ceil(n/2) and floor(n/2), so whichever phase moves the three-vehicle half of a five-vehicle squad leaves
2 of 5 = **40%** still, and swapping which half goes first only moves the 40% to the other phase. So an odd-sized
element leaves a permanent **base of fire** and bounds the rest in two equal teams — 1 + 2 + 2 for a squad of five,
**3 of 5 stationary in both phases** — which is what a platoon actually does, and the falsifier then holds by
construction rather than by a measurement that happens to pass. The base is the vehicle worth most from a static
position (`slot_order`'s last, which is the most protected role: artillery, then lancer — the guns the element already
exists to protect and the ones that shoot worst on the move). A two-vehicle element alternates singles (50%); a single
vehicle does not bound and the plan says so rather than pretending to.
**Ruled by the orchestrator 2026-09-20**, on the reasoning that it is the doctrinal shape, it meets the falsifier by
construction, and it reads better to a spectator than two shuffling halves — which is the lead's actual criterion.
`test_at_least_half_the_element_is_stationary_in_every_phase` asserts it for every squad size from 2 to 8, so the
falsifier is a test rather than a run.

### X3's design note, kept because it was the question that was asked



**Part A, co-arrival, is mostly a deletion.** `FormUp.paces` already paces every member by its share of the
bottleneck ETA (`eta_i / max(eta)`), leader included, which *is* co-arrival at the destination. What A9 adds is
(a) making the bottleneck a **tick count** rather than a float of seconds (Invariant 7: tick-count phase
synchronisation), so the pace is a ratio of integers and cannot drift with float order, and (b) deleting
`Element._pace_leader_for_flow` — the leader's *separate* heuristic (`FLOW_LAG_SLACK_M` 6 / `FALLOFF` 20 /
`MIN_PACE` 0.75), which paces the leader by how far the worst follower trails its follow offset. One bottleneck,
one rule, every member including the leader. The lead's 4 s allowance is the budget.

**Part B, the two-phase machine, has a real problem with its own falsifier.** A9's bar is *"≥ 50% of squad firepower
stationary at every tick of a bounding advance"*, and **two alternating halves of an ODD-sized element cannot meet
it.** `ElementPlan.split` gives `ceil(n/2)` and `floor(n/2)`; for the five-vehicle squad the army JSON caps a squad at,
whichever phase moves the three-vehicle half leaves 2 of 5 = **40%** stationary. Swapping which half bounds does not
help — it just moves the 40% to the other phase. The bar is met for even counts and missed by exactly one vehicle for
odd ones.

**Recommendation, and it is doctrinal rather than a fudge: an odd-sized element leaves a permanent BASE OF FIRE and
bounds the rest in two equal teams.** Five vehicles become a base of 1 plus two teams of 2; the base never bounds, so
**3 of 5 (60%) are stationary at every tick**, in both phases, and the falsifier is met by construction rather than by
a measurement that happens to pass. That is what a platoon actually does — it leaves a support-by-fire element and
bounds its sections — and it costs nothing, because the vehicle that stays is chosen as the one whose firepower is
worth most from a static position (`ROLE_RANK`'s indirect-fire and long-reach roles, which are the ones the element
already exists to protect and the ones that shoot worst on the move). Phases alternate every **5–8 s** as the
catalogue says, bounded at both ends: never swapped before `BOUND_MIN` and forced at `BOUND_MAX`, so a bound that
never closes up cannot park the element (lesson 17: the gate above the behaviour must not be able to cancel it
forever), and the phase goes into `Element.state()` so control can draw it and the announcer can call it.

**If the orchestrator would rather keep two halves and accept 40% for odd counts, that is one constant** and I will
report the measured minimum stationary share either way rather than quietly meeting the bar by redefining it.

### The leash decision (nav's A7), and why it is its own commit

**Answered 2026-09-20, endorsed by the orchestrator: an attacking element's members DO carry a leash, and my
slot-drift scenario's bar stays.** `TankBrain.element_slot()` no longer returns null for the `bound` and `maneuver`
roles, so **every** element member gets `request["leash"] = {center: <its published slot>, radius:
slot_leash(element)}`.

- **Why it is not a cage.** The round-4 exclusion was right when a slot was a static post and is wrong now that the
  slot tracks the element's intent: `_plan_bounding` and `_plan_fire_and_maneuver` both place those members at the
  anchor they are *driving to*, so a bounding team's published slot IS its next bound's anchor and a manoeuvre
  element's IS the flank it was sent to. With nav's level-0 semantics — *inside your region, and if you are outside it
  do not get further outside* — a leash on a slot 40 m ahead is a convergence guarantee.
- **Why it was needed.** nav measured A7 (`stream/nav` at `b6d72f52`, laptop) against the blend on
  `scenario_elements::test_a_unit_fighting_from_a_formation_slot_stays_in_it`: in-slot drift **15.4 → 42.1 m** (bar
  16), in-slot shots **10 → 5** (bar 6), localised to the weapon level by switching levels off in turn. Under the blend
  the weapon band and the slot compromised by *accident*; A7's strict priority removed the accident. **The accident was
  doing load-bearing work** — and my four other elements scenarios passed on both arms, including
  `test_the_base_of_fire_keeps_firing_while_the_others_move` (base shots 5 then 4, reproduced exactly).
- **Why the bar stays.** The scenario is the lead's complaint in miniature: an element told to attack whose members
  each hold their own band 42 m apart *is* *"just these 2 masses shooting at each other"*. 16 m is not arbitrary — it
  is just over one doctrinal open spacing, i.e. *a unit may fight anywhere inside its own slot's share of the
  formation and not in its neighbour's*. **What did move is that the bar is now derived**: `slot_leash(element) + 2.0`
  read from the element's own pitch, so it is the same 16 m for tank hulls today and survives CP2 (lesson 112).
- **`test_ai_elements::test_the_unit_that_is_supposed_to_be_moving_is_not_leashed_to_its_slot` asserted the OPPOSITE**
  and is rewritten (`test_every_element_member_fights_from_the_slot_it_was_given`) with the round-4 intent and the
  reason it was overturned in the test body — a tested decision should not be reversed silently.
- **Prediction for the default path, made before measuring:** it should barely move, because the blend's leash term
  **saturates** (`PENALTY_LEASH * clampf(out / LEASH_FALLOFF, 0, 1)`), so past `LEASH_FALLOFF` it subtracts the same
  constant from every candidate and the argmax is unchanged. That is nav's own lesson 153 in the place it was born:
  fine as one addend, decisive as a level. The identical change is therefore near-inert on the blend and load-bearing
  on A7, which is worth saying out loud or "the default barely moved" reads as "the change did nothing".
- **Commit shape (the orchestrator's instruction):** the leash change lands as **one small commit with X1 only** — the
  hull-derived pitch, `slot_leash`, `element_slot` and the two tests, and **nothing of A8 or A9** — so it can be
  merged to `main` alone as an early checkpoint and nav may cherry-pick it for measurement only. A8/A9/X5 follow in a
  second commit.

### Also for nav: the slot the formation asked for

`Element.state()` carries `"slots_asked": {unit: Vector3}` — the slot the formation wanted, present only for the
members whose slot `SlotGround.standable` had to move. nav measured **835 of 1196 (70%)** of its arrival-arc refusals
as `off_mesh` and could not tell two different bugs apart: a gate behind a slot that was *always* inside geometry,
versus one behind a slot my push *moved*, where the gate is then computed one approach-length back along the ordered
heading into whatever the slot was pushed out of. Now it can.

**And a wrong prediction of mine, recorded as wrong.** Round 8 I predicted that *"6.5 m assembly spacing refuses most
slot gates"* as `on_approach`. nav's fight probe, with orders now carrying facings, measured `on_approach` at **49 of
6364 offers — under 1%**, with the arrival arc firing **5168 times** in a 45 s fight on yard where round 8 measured
exactly zero in both arms. Element spacing is not what refuses slot gates. The useful half is worth more than the
prediction was: the arrival arc is far more available to the KEEP_SLOT path than either of us expected.

### CP1 (metrics) changes two things in this brief

**1. A8/A9 are re-aimed at WHEELED hulls, not light ones.** My brief says *"aim A8/A9 at the light hulls: the gang
scout is the shuffler at 0.68 and 13.3%"*. metrics re-ran round 8's exact configuration on builder0 (yard, GREEN,
attack_move, seed 3, 120 s) on a **Condemned roster that fields no scout at all** and got the same split:
`ifv` 0.624 efficiency / 12.1% oscillating / 35.8 cusps per agent-minute, `lancer` 0.619 / 9.4% / 34.8, `tank`
0.798 / 4.9% / 7.4. With no scout on the field to confound it, **it is a locomotion property, not a size one** —
round 8's conclusion was the same effect seen through one unit.
**What that means for my rows, said honestly rather than optimistically:** A8's spacing is keyed on hull **length and
width** and A9's pacing on **top speed and nav's route ETA**; neither reads locomotion at all. So the expectation is
that A8/A9 help a wheeled squad **less** than the pathology suggests, because what makes a wheeled hull shuffle is its
turning circle and its gear changes — nav's A7/A11 subjects. Every defile and co-arrival measurement fields a **wheeled
squad with a tracked-only control arm**, and if the wheeled arm does not improve I report that rather than averaging it
away with the tracked one.

**2. The affine formation residual will read A8 as a defect unless its reference changes, and I have said so.** The
residual is computed against the **nominal** shape with a best-fit affine, so any affine deformation is exactly 0 —
which is the right design. But A8's deformation is **deliberately not affine**: the file morph is what makes it safe
(see above), and the best-fit affine of a wedge onto a file is singular, so *a wedge that has filed through a defile
perfectly — every unit exactly on its slot, zero crossings, zero inversions — shows a large residual.* That is a false
positive on the one manoeuvre A8 exists to produce. **Requested of metrics:** log each unit's slot in the element
frame as the reference (`place()` returns it as `offset`, and `Element.slots` already holds the world version), so the
residual measures departure from the element's own intent and every deformation the leader commanded is free. If
metrics keeps the nominal reference, I treat the residual as a diagnostic of *"the shape changed"* and A8's falsifier
rests on the geometric invariants instead — I will not quote a number I know misreads the mechanism.

**3. Elements of three or fewer.** The residual is only defined for four or more (a 2-D affine fit has 6 parameters and
3 points determine it exactly), and A8 **can** produce 3-unit elements through attrition. `refused_too_small` is the
right behaviour and reporting 0.000 would be worse than reporting nothing. For those elements the falsifier is carried
by the geometric assertions, which are size-independent and asserted from 2 members up.

**4. Only displacement efficiency is fit to be a target** (metrics' own `_agents/metrics.md`): cusp density, SPARC and
the residual are all optimised by *doing less* — never reversing, never accelerating, disbanding the element. This is
lesson 150 (mine) restated by the data, and it is why none of my falsifiers is phrased as *"make this number go
down"*: A8's are geometric invariants plus a recovery time, and A9's is a structural guarantee. The one number I will
use as a target is **displacement efficiency p10**, never its mean.

### Where verification stands (laptop, 7 streams live, on the full X1+X5+X2+X3 tree)

Every new test green, run narrowly because a full local `make test` on a saturated laptop was taking over an hour and
was being polluted by my own mid-run edits (the run was killed for that reason, not for a failure):

| Filter | Result |
|---|---|
| `tactics_deform` (X2 / A8) | **7 passed, 0 failed** |
| `tactics_facing` (X5) | **5 passed, 0 failed** |
| `tactics_bounding` (X3 / A9) | **8 passed, 0 failed** |
| `tactics_hull_spacing` (X1) | **8 passed, 0 failed** |
| `tactics_formations` (the existing geometry suite) | **12 passed, 0 failed** |

**Lesson 45 applies and I am not claiming readiness from these.** The merge candidates are verified by
`make remote T=check` on builder0, one commit at a time, and I name the hash from the wrapper's own
`>> remote: make check exited <N>` line.

**Two failures found and fixed on the way, both mine and both worth recording:**

1. `_group` never passed `halt` into `place()`, so `place()` computed every entry's `facing` as the direction of
   travel and a halt expressed its sectors of fire *only* by driving `FACE_LEAD` metres along them. X5's test caught
   it immediately — which is the point of asserting the mechanism rather than the outcome.
2. `frontage("block", ...)` read **0 for every count and every spacing**, because `offsets()` has no case for the
   group shapes (`rows`, `block`, `single`) and `frontage`/`depth` went through it rather than `group_offsets`. It had
   been wrong since the group shapes were added and nothing noticed, because nothing asked a group shape for its
   width until A8 did. Fixed in the X1 commit.

### X4 (A10): the before-measurements, taken before writing a line of it

`TacticsFormation.seat()` is pure, so A10's two pre-registered quantities are measured in a unit test rather than in a
match — `tests/test_tactics_seating.gd`, which prints the same MEASURE lines before and after so the two commits
compare on one machine. **Laptop, on `6e0c9968` plus the uncommitted A8/A9 tree, 96 cases, 8 fixed seeds:**

| Quantity | Before A10 | A10's bar |
|---|---|---|
| spurious re-assignments under a 0.5 m nudge | **0 of 512 (0%)** | 0% |
| crossing driving paths on a formation transition | **8** over 96 transitions | 0 |
| transitions keeping a seating the solver would not have chosen | **20 of 96 (21%)** | — (diagnostic) |

**What that changes about A10's case, honestly.** The perturbation number is **already 0** — the two hysteresis
patches do hold a seating still for half a metre, and A10 wins nothing there. The whole measurable gain is the
crossings: the hysteresis keeps a non-minimal seating in **21%** of formation transitions, and in 8 of those the
result is two vehicles driving across each other, which is the thing a spectator sees. So A10's case is *not* "the
seating thrashes" — it is **"the cure for the thrash costs us a crossing one time in twelve"**, and the incumbent
bonus is the version of the cure that does not.

**And the measurement had to be fixed before it meant anything** (worth recording, because the first version would
have been quoted): I first measured crossings between each unit's OLD SLOT and its new one and got 57 of 96, which is
not a defect at all — the units are not standing on their old slots, so those segments are paths nobody drives. The
quantity that matters is the path each unit actually drives, **from where it is now to the slot it was just given**,
which is exactly what a minimum-total-distance matching guarantees will not cross. Measured that way it is 8, and
every one of them is attributable to something above the matching rather than to the matching.

### The goal-move attribution, and the nav bug it found

nav measured A1 (`stream/nav` at `4d72d0e2`, yard, seed 3, 45 s, laptop, per-tick counters): its fixed repath cadence
fired 2222 times, **2144 of those were skipped by A1's tube, and total re-plans moved +0.9%** (2059 vs 2041). So
**nav's route cadence is worth ~3% of re-planning in a fight**, A1 fails its own falsifier there, and — this is the
part that lands on me — **the catalogue's claim that 70% of direction churn is re-planning inside one unchanged
decision is not the cadence.** That claim was partly mine, from round 8's decision probe. The re-plans are *events*,
overwhelmingly "the goal moved", and from nav's side of the seam a changed order and a jittering slot are one number.

**Built tonight, so they are four numbers instead of one.** `Element.state()` carries
`goal_moves: {task, leg, reseat, drift}` — attributed when one of this element's orders is re-issued with a goal more
than **1 m** from the one it previously issued that unit, which is nav's own threshold so both sides count the same
event — and `make squad-coherence` reports it per side:

| cause | what it means |
|---|---|
| `task` | a new task arrived. The commander changed its mind; the re-plan is the system working |
| `leg` | the element advanced its leg, so the formation's anchor moved. Should dominate on a march |
| `reseat` | this unit changed slot inside the same shape. **A10's column** |
| `drift` | same task, same leg, same seat, and the goal moved anyway. **This one is a bug, and it is mine** |

**And `following`, which turned out to matter more than the four.** A member on a K1 `follow` has a goal that slides
with its leader **every tick, by design** — round 7's element flow. nav sees that as continuous goal movement; it is
not a re-issue at all and `_should_issue` never sees it, so no dwell rule of mine should ever touch it. Surfacing that
found a bug in nav's layer: `_next_waypoint` re-planned the whole route on any goal move over 1 m **without asking
whether the goal jumped or was sliding**, so a follower doing exactly what it was told triggered a full A* several
times a second. nav already knew the difference in two other places (`_goal_velocity` for station-keeping,
`NEW_GOAL_JUMP` for the K1 grace window) and has now split `a1_replans` by cause — `cadence`, `goal_jumped`,
`goal_slid`, `off_path`, `stalled`. **The two attributions compose: mine names the issue, nav's names the consequence.
`drift` → `goal_jumped` is a bug in my layer; `following` → `goal_slid` is a bug in nav's.**

**Decided overnight:** `TankBrain.MOTION_REPLAN_TICKS` and the incoming-round count in `_motion_cache`'s key are
**not** changed tonight, though nav is right that the key changes whenever a shell enters or leaves the list. A10's
`reseat` column has to land first: if `drift` and `reseat` both come out small then the cache key is the remaining
suspect, and changing two things inside one measurement is how round 8 lost a day. **No veto and no dwell timer**,
ever, on this: round 8's acquire-dwell floor is my own evidence (switches 19.5 vs 18.1, reversals 0.67 vs 0.30 —
worse on every seed). A veto delays a switch and it returns as a reversal. If something changes it changes the
**score**, not the permission.

**And the catalogue sentence is NOT rewritten yet, deliberately.** "It is not in the cadence" is established; "it is
in the goal" is not, because `goal_slid` may absorb much of it. Replacing one confident claim with another confident
claim is how the first one got there.

### Cross-stream notes taken this round

- **S5 (combat's A2).** Understood: A2 replaces `COMMIT_BONUS` 1.15 in `tank_brain.gd` through a proposed commit I
  take, replace or revert, and the same expression replaces nav's motion-layer constant. I have not touched
  `COMMIT_BONUS` or `CombatMotion.COMMIT_BONUS`. I own the judgement if `scenario_squad::test_a_squad_focuses_its_fire`
  or `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` moves.
- **nav's A7 survival-vs-leash ordering.** Answered to the orchestrator with the numbers (below) and confirmed that
  A9's two-phase bounding overwatch will not change what a held element hands down. I will run
  `scenario_elements::test_the_base_of_fire_keeps_firing_while_the_others_move` on nav's A7 commit when nav names it.
- **Lesson 153 (nav's saturated `PENALTY_LEASH`), and it lands on X4.** A cost that becomes a level, a tie-break or an
  auction utility must be monotone over the whole range it can see. A10's integer utilities must therefore keep the
  distance term **unclamped**: a saturated distance would tie two slots for a far unit and the auction's tie order
  (unit name) would decide the formation. Today's `seat()` cost is already monotone (`distance + TIER_COST x tier gap`,
  no clamp), and that property has to survive the rewrite. Checked against X2 as well: its clamps (`MAX_ELONGATION`,
  `MIN_SQUEEZE`) are geometric outputs, never rankings, and the saturation they do cause is reported as
  `fits: false` rather than hidden.

### What a base-of-fire hold and a squad station hand down today (for nav's A7 level 0)

| Number | Value | Where | What it is |
|---|---|---|---|
| the motion leash nav receives | **14.0 m**, now `slot_leash(element)` | `tank_brain.gd:2296`, `SLOT_LEASH` `:302` | `request["leash"] = {center: <element slot>, radius: ...}`. Gated by `element_slot()` (`:1264`), which returns **null — no leash at all —** for roles `bound` and `maneuver`: under bounding overwatch the moving half is unleashed by design and the covering half is leashed |
| cover-search radius | **18.0 m** | `tank_brain.gd:1522-1523` (`COVER_SEARCH_RADIUS * 0.6`, `:61`) | where a held unit may *look for cover*, not where it may drive. **Not the leash** |
| hold tolerance | 3.0 m | `tank_brain.gd:153` | how close a `hold` order keeps a unit to its spot |
| player post leash | 18.0 m | `tank_brain.gd:161` | a unit the *player* placed |
| idle leash | 30.0 m | `tank_brain.gd:156` | a unit with no order |
| in-position | 8.0 m | `element_plan.gd` `IN_POSITION_M` | **not a leash**: the hysteresis that decides whether a crew on a firing line is told to move to its place or to hold it |

### Baseline on my start commit (`9f864474` = `main`, laptop, 7 streams live)

- `make ai-scenarios`: **44 passed, 1 failed, 2 pending**. The failure is
  `scenario_perf::test_the_brains_stay_inside_the_cpu_budget` (`ai_usec_per_tick` **23390** at 60 brains against a 4000
  budget). It is a per-tick cost on a saturated laptop — `verification.md` *Timing numbers under builder0's 4 heavy
  slots* lists exactly this class as **not safe under concurrency** — and combat reports the same failure at the same
  commit, so it is baselined by two streams as a laptop-speed failure, not a regression. Pending:
  `scenario_cp2::test_a_scout_guns_down_a_lancer`, `scenario_evasion::test_a_light_unit_dodges_most_tank_shells`.
- `make test FILTER=tactics`: 93 passed, 1 failed on the first run of the new tests — the failure was mine and real
  (`_group` never passed `halt` into `place()`, so a halt's crews were handed the direction of travel as their facing
  rather than their sector of fire). Fixed; re-running.

### The measurements, taken overnight (laptop, `make squad-defile`, the maze's gap)

**The instrument, and it had to be fixed three times before a number was worth quoting.** `make squad-defile`
(`tests/tactics/defile_probe.gd`) puts a five-vehicle element through the maze's 11 m gap — 5.0 m of navmesh once the
bake's 2.0 m agent radius comes off each side — and samples every tick. The control arm is **locomotion, not
faction**: both arms are Condemned, so the doctrine table and the faction are held fixed and only the plant differs
(metrics' CP1 finding that the shuffle is a wheels property, not a weight one).

Three defects in my own instrument, each found by checking it against a case whose answer I knew (lesson 34):

1. It reported the corridor as **open**. It sampled a 56 m leg at three fractions and the container bands are a few
   metres thick, so every sample landed in the open ground *between* them. **A probe that can only see a defile if a
   sample happens to land on it reports whatever it stepped over.** It now samples every 4 m, capped at 16.
2. It reported the element's **final** corridor and file rather than the narrowest and furthest of the passage — so a
   traverse that demonstrably went through a gap read `corridor -1, file 0`, because by the last tick the element was
   past the band with open ground ahead. **It was reading the end state and calling it the passage.**
3. It issued the move with `drills: false`, which takes `_plan_form_up` — the plain-move path whose slots are the
   final formation at the destination and which sets `corridor_m` to INF **on purpose**. A8 could not engage. Which
   surfaced a real limitation of A8 rather than only a probe bug: **A8 does not apply to a plain player right-click
   move**, by my own earlier decision, so the lead's commonest order does not get the deformation. Deforming the
   FLOW offsets (the actual transit shape of a plain move) is the follow-on.

**A8: MEASURED AND SWITCHED OFF. `TacticsFormation.DEFORM_ENABLED := false`.**

| forced wedge, wheeled, maze gap, 70 s | arrived | through the gap | crossings | inversions | file |
|---|---|---|---|---|---|
| `deform=on` | **0 / 5** | **no** | **6** | 21 | 1.0 |
| `deform=off` | **4 / 5** | **yes** | **1** | 20 | 0.0 |

**The deformation is the difference between getting through and not getting through**, and it takes the crossings *up*
(6 against 1) rather than to the zero its falsifier promised. **One configuration, not three seeds** — the three seeds
I ran returned byte-identical numbers, because the scenario has no enemies and hand-placed units, so the seed varies
nothing (lesson 22: repeating a measurement across a variant that does not vary is one sample). A deterministic
difference in a deterministic system is enough to switch it off and not enough to explain it.
**What survives:** every geometric invariant A8 pre-registered holds by construction and is asserted over a sweep —
hulls never overlap at any corridor width, the depth order never inverts, the frontage is monotone with no snap. The
geometry is right; **a slot layout is the wrong place to express it.**
**And nav reached the same structural conclusion independently the same night:** it measured `CombatMotion` deciding
under a tenth of a hull's ticks in a fight, with `Movement` driving the other nine tenths and having no notion of a
formation leash at all — so its A7 region belongs in `Movement`'s goal selection. **A8's deformation is the same kind
of thing: a formation-level intent that the layer actually moving the hull cannot see.** Both belong in that seam, and
neither is a tonight-sized change. Turning A8 on again is one constant, and the A/B above is what to re-run.

**A9: FALSIFIER MET, and measured rather than asserted.**

| forced wedge + `bounding_overwatch`, maze, 70 s | bounding ticks | stationary_min | arrived | through | dispersion |
|---|---|---|---|---|---|
| **wheeled** (ifv, lancer, artillery, burner, scout) | 2017 | **0.60** | 4 / 5 | yes | **41.4 s** |
| **tracked** (5 × `tank`, the control) | 1113 | **0.60** | 4 / 5 | yes | **1.23 s** |

- **≥ 50% of the element stationary at every tick: met, at 0.60** — exactly the 3-of-5 the base-of-fire design
  predicts, on both arms. And `bounding_ticks` in the thousands says the phase machine **ran**, which is the check
  round 8's lesson demands before crediting any term.
- **Arrival dispersion is the result of the night, and it is a negative one for my rows and a positive one for the
  diagnosis.** The falsifier's bar is *> 12 s → < 1 s*. The **tracked** arm is at **1.23 s** — essentially at the bar.
  The **wheeled** arm is at **41.4 s**, thirty times worse. Co-arrival paces off top speed and nav's route ETA and
  **reads no locomotion at all**, so it gets a tracked squad to the bar and cannot help a wheeled one.
  **This is metrics' CP1 finding reproduced by a completely independent instrument**, and it is the negative result I
  put on the record *before* running it: what makes a wheeled hull late is its turning circle and its gear changes,
  which are nav's A7/A11 subjects. **A9 is not the fix for a wheeled squad and I am not claiming it is.**

### X4 (A10) is built, and its falsifier is met — after a FOURTH instrument defect, this one in my own test

`TacticsFormation.seat()`'s Hungarian solver is replaced by a **deterministic integer auction** (Bertsekas) with an
**incumbent bonus**, and **both hysteresis patches are deleted**: `STABLE_MARGIN` and round 8's `fixed` flag, the
latter along with its plumbing through `ElementPlan._group` and its caller. The four determinism properties the
catalogue chose auction for are honoured: pure integer utilities (scaled by 10⁴), a fixed ε, a hard bid cap, and bids
taken in member order, which is unit-name order. **Lesson 153 is respected explicitly: nothing in the utility is
clamped**, because a saturated driving term would tie two slots for a far unit and the tie order would silently decide
the formation. `_hungarian` is kept as the reference the auction is tested against and is called by nothing in the
game.

| pre-registered quantity | before A10 | after A10 | bar |
|---|---|---|---|
| spurious re-assignments under a 0.5 m nudge | 0 of 512 | **0 of 512** | 0 |
| crossing driving paths on a formation transition | 0 of 96 | **0 of 96** | 0 |

**The fourth instrument defect, and it is the one I am least comfortable about because I wrote the test.** My first
version of the crossings measurement passed the previous seating across a formation change by hand, and reported **8
crossings before A10 and 47 after** — a regression that would have got A10 reverted. **Both numbers measure a
configuration the game cannot produce:** `ElementPlan._previous_seating` returns `{}` whenever the formation name or
the member count differs from the one the seating was recorded under, so **a formation transition always re-solves
from scratch** and there is no incumbency to cause a crossing. With the test corrected to what the contract actually
does, both solvers read 0 and the interesting quantity was never crossings at all.
**Which means the honest reading of the "8 crossings" I reported earlier in this Status is: that number never
existed.** It is struck, not revised.

**What the corrected measurement did find, and it is a real A10 defect that is now fixed:** at `AUCTION_BIDS_PER_UNIT`
= 8 the auction hit its cap often enough to fall through to the greedy completion and produce **6 spurious
re-assignments in 512** under a half-metre nudge, where Hungarian + `STABLE_MARGIN` produced 0. That is an
**approximation artefact, not a property of the incumbent bonus** — at half a spacing per unit the bonus is far too
strong for a half-metre nudge to overcome. The cap is 64 now; the work is trivial for an element of 3–8 and the
artefact stops showing.

**A10's other falsifier — the CPU five-squad idle-order count the `fixed` flag was added for (round 7: 4–6 → 0) — must
still be 0 without the flag.** `test_tactics_scenarios::test_a_cpu_army_under_the_same_orders_is_not_re_ordered_for_fighting_from_its_slots`
is that assertion and it is running; the result belongs beside A10's hash and A10 is not committed until it is in.

### STRUCK: "the defile finding is roster-wide". It is not — scale's corridor table was retracted

I recorded a scale table here showing eight of ten maps failing a widest-hull fit test after CP2, and built an argument
on it about the A8 follow-on's priority. **scale has retracted that table: its measure was twice the distance to the
nearest obstacle, which is not a passable width** — yard's reported "4.72 m pinch" is a corridor about 23 m wide. **No
maps are changing and no map-wide squeeze has been demonstrated.** The paragraph is struck rather than revised,
because there is nothing in it left standing.

**What does stand is only what I measured myself**, and it is narrower than I let it become: on the maze — a test
fixture nobody plays — a Condemned `artillery` at its **current** 2.6 m width, with about 2.1 m of slack in a 5.0 m
navigable corridor, **never arrived in 70 s while four squadmates used the same gap.** One vehicle, one defile, one
configuration, deterministic. That is an existence proof of a fit-or-yield failure and nothing more.

**And the cause is now nav's, with a named mechanism rather than my speculation:** nav has three instrumented
candidates, the leading one being **right-of-way asking for 4.55 m of lateral clearance inside a 5 m corridor, with
the refused asker yielding** — which explains a queue that never drains without any hull being too wide for anything.
My inference that this was a *width* problem about to be made worse by CP2 was wrong, and it was wrong in the
direction I should be most suspicious of: it made my own measurement sound more important than it was.

**And the correction came with a positive control that validates MY instrument, which is worth more than the retraction
cost.** scale's corrected measure puts the maze's tightest point at **exactly 7.00 m**, and `tools/make_arenas.py`
authors `MAZE_TIGHT_GAP = 7.0` — so the corrected number reproduces the authored one. Subtract `NAV_AGENT_RADIUS` 2.0 m
from each side and you get **5.0 m of navigable corridor**, which is **exactly what `SlotGround.corridor_width`
measured off the baked navmesh**. Two independent instruments, one geometric and one off the mesh, agreeing to the
decimal on a gap whose authored value is known. **That is the check my corridor probe needed and had not had** — after
it had been wrong three times, it is now right against a known answer.

**Lesson for my own reporting, not anyone else's:** I relayed a number from another stream into my brief and reasoned
from it inside the same hour. The rule this project already has (lesson 26 — *a relayed number becomes a fact: ask the
sample size before passing it on*) applies to the measure as well as the sample: **ask what the number is the width
OF.** I did not, and the honest version of my own finding was available without it.

### X6 (stretch): what is answerable tonight, and what needs a hook I do not own

The lead asked for this by name — *"we might even be able to differentiate units of different factions by PID
values"* — so it deserves a real answer rather than a shrug. `ControlGains.FACTIONS` already ships three tables, with
an intent written beside each: the Syndicate crisp and twitchy (kp 1.5, kd 0.9), the gangs loose and overshooting
(kp 0.45, kd 0.05), the Law damped and deliberate (kp 0.7, kd 1.2), and the Condemned as the reference default.

**The regulator half is already answered and asserted**, in nav's `tests/test_station_keeping.gd`
(`test_factions_keep_station_each_in_their_own_way`, `MEASURE station_faction`): the Syndicate sits tighter in its
slot than the default, the gangs overshoot a stopping slot by more than 0.3 m over the default, and the Law never
overshoots more than the reference. **So the gains are real at the loop.** That test drives one hull against a moving
then stopping slot, which is the cleanest possible isolation of the regulator and the right way to establish that.

**The two halves my brief actually asks about are NOT answerable from here tonight, and the reason is a seam rather
than time:**

1. *"Do they win equally often?"* needs a ladder — identical armies, gains the only difference — and that is
   `make tactics-ladder`, hours of builder0, and the wrong use of a contended night.
2. *"Does a spectator see a difference?"* needs metrics' spectral arc length and cusp density per faction, which
   needs CP1 on `main`.

**And both need something neither of them has: a way to hold the ARMY fixed while changing the gains.** Today the
gains are selected by `Units.stat(unit_id, "faction")`, so "a gangs squad" and "a Law squad" differ in gains *and* in
every stat the two factions differ by — which makes the comparison uninterpretable, and is exactly the confound
lesson 23 is about (measure the configuration players get, and know which configuration you measured).
**Request to nav:** a runtime override on `ControlGains` — a `static var override := {}` merged over
`FACTIONS`/`DEFAULT`, or a `--gains=<faction>` launch flag — so one army can be driven by another faction's loop. It
is two lines in `control_gains.gd`, it is nav's file, and **without it X6 cannot be measured at all, only asserted.**

**My prediction, made before I ran it:** identical armies would win equally often, and a spectator would see the
difference *only* in the gangs' overshoot, because that is the one gain set whose intent is a visible signature rather
than a tighter one.

**The regulator numbers, and the prediction is wrong in a specific way** (`MEASURE station_faction`, laptop, one hull
driven against a moving then stopping slot):

| gains | tracking gap | overshoot on stopping | settling |
|---|---|---|---|
| default (Condemned) | 0.20 m | 1.89 m | 3.23 s |
| **syndicate** | **0.09 m** | 1.68 m | 3.23 s |
| **gangs** | 0.81 m | **2.56 m** | 3.30 s |
| **law** | **1.00 m** | **1.56 m** | 3.20 s |

Every intent written beside the tables holds: the Syndicate sits **2.2× tighter** than the reference crew, the gangs
overshoot a stopping slot by **+0.67 m** over it, and the Law overshoots **least of all four**. But the spread that
matters is not the one I predicted: **the tracking gap spans 0.09 m to 1.00 m, an 11× range**, and the loosest tracker
is the **Law**, not the gangs — which is the honest consequence of "damped and deliberate" (heavy D, light I: it never
overshoots and it never quite closes). So **two of the three factions differ from the default visibly, in different
ways**, rather than one.

**Is 11× visible? Yes, and that is the answer for the lead.** A metre of station-keeping slop is a quarter of a hull
length at today's sizes and about a fifth of the way to a neighbour's slot; two and a half metres of overshoot when
stopping is most of a hull length past the mark. At his camera those are not subtle. **Settling time, though, is
indistinguishable — 3.20 to 3.30 s across all four, a 3% spread — so nobody arrives faster, they arrive differently.**
That is a good property: it means the gains are flavour without being a balance lever, which is exactly what he asked
for and what `vision.md`'s no-pay-to-win pillar needs them to be.

**What these numbers are NOT.** One hull, a synthetic slot, no enemies, no terrain, no formation. They establish that
the loops differ and roughly how much. They do not establish that the difference survives a fight, that it is visible
*in* a fight, or that it is balance-neutral in a match — and the second of those is metrics' spectral arc length after
CP1, while the third needs the gains-override hook above before it can even be set up.

### A1's brain half, built behind a switch with the default untouched

`TankBrain._hold_motion_plan` now holds the two rules side by side, and `TUBE_ENABLED` (default **false**) chooses.
The shipped rule is a **cadence** — same cache key, younger than `MOTION_REPLAN_TICKS` — which is a true argument
about *time* that says nothing about whether anything moved. The **tube** is the same argument about *state*: hold the
plan while neither the unit nor its target has left the neighbourhood it was computed in (`TUBE_TARGET_M` /
`TUBE_SELF_M` 8 m, the same order as `Element.REISSUE_M`, because below that the 12 m steer point has not meaningfully
moved), with a `TUBE_MAX_TICKS` ceiling so a held plan cannot become a stuck state.
`redecide_counts()` returns `{redecides, skips}` per brain, so the flip is gated on a counted before/after.

**Why the default is off, and it is evidence rather than caution.** nav's route half of A1 failed its own falsifier in
a fight — the cadence skipped 2144 of 2222 firings and total re-plans moved **+0.9%** — and its cause split then
attributed **968 of 2059** re-plans to `goal_slid`, a goal nav was already regulating. Until nav's fix for that is
re-measured, **the share of re-planning reachable from this side is unknown**, and a mechanism whose falsifier cannot
be evaluated does not ship on. The flip is one constant.

**What the six tests assert is the part that must hold whatever the measurement says** — and it is the part that makes
the flip safe rather than the part that makes it valuable:

- the tube may only ever hold a plan **longer** than the cadence would, never shorter (inside the cadence it cannot
  cause an extra re-decide, whatever the state has done — otherwise turning it on would make the brain think *more*);
- **it can never delay a reaction to something new.** Everything a brain must react to instantly is in the cache key
  — the target's name, the strafe side, the run phase, and the count of rounds on their way — and a key change refuses
  the plan *before* the tube is consulted. A tube that swallowed a new contact would be the dwell timer this project
  has already measured and rejected (round 8's acquire floor: switches 19.5 vs 18.1, reversals 0.67 vs 0.30, worse on
  every seed);
- and it has a ceiling, because a tube without one is lesson 17's shape.

`make test FILTER=motion_tube`: **6 passed, 0 failed.**

### What is NOT done, and the exact commands to do it

Written plainly rather than implied, because the round's headline claims rest on measurements I have not been able to
take. **Everything below is the falsifier evidence, not the build.** The builds are done and their geometric and
structural properties are asserted by tests; what is missing is the behaviour in a real match.

1. **A8's defile falsifier: post-defile recovery time −60%, ≥ 5 seeds, both machines named.** The *crossings and
   inversions* half holds by construction (asserted over a sweep), so what is missing is the **recovery time** and the
   before/after on a real gap. Not taken: the laptop was saturated by seven streams for the whole session and one
   builder0 slot went to each merge candidate's `check`.
   - `make remote T="nav-maze"` for the defile, or yard's bridge and pit's gaps.
   - Field a **wheeled** squad with a **tracked-only control arm** (metrics' CP1 finding: the shuffle is a locomotion
     property, so a tracked-only measurement would flatter A8).
   - Read the affine residual from metrics' tool, **with the reference rank column** — rank 2 is a file and rank 3 a
     real shape, and a small residual means different things at each.
2. **A9's co-arrival falsifier: arrival dispersion > 12 s → < 1 s.** Not taken. A probe is needed that measures
   inter-member arrival at an objective line; `make squad-coherence` does not report it. The **stationary-share** half
   of A9's falsifier *is* asserted (by construction, for every squad size 2–8).
3. **A9's cost, which the lead has a stake in.** Co-arrival now paces every member off the final-slot ETA, and during
   `_flow` a follower's real goal is the leader-relative station, which is nearer — so the follower's ETA is an
   **over**estimate and the leader is paced more conservatively than it needs to be. The lead allowed *"a 4s slower
   march for a tidier traversal"*; **I have not measured what this costs**, and if it exceeds 4 s that is a question
   for him with the numbers. `make squad-coherence EXTRA="--green-elements --rust-elements"` before and after, same
   seeds, same machine.
4. **`make squad-coherence` and `make squad-decisions` before/after each of X2–X4**, which the brief asks for by name.
   Not run. The before-numbers for A10 *are* taken (above) because `seat()` is pure and a unit test could do it.
5. **Smoke it like a player.** `make skirmish`, select a squad, order it through the maze's or yard's narrowest gap —
   it should narrow to a column and re-open with nobody swapping places; then order a bounding advance and look at
   `make remote T=tactics-shots` frames: at every moment half the squad should be stopped and shooting. **Not done: it
   needs a display, and a windowed run opens on the lead's desktop** (trip-up 32). The frames are the part that can be
   done remotely and they are the part worth doing first.
6. **X6 (per-faction PID gains), the stretch item.** Not started. It needs CP1 on `main` and a merged tree.

### Requests to other streams

- **nav:** please report a **clearance / corridor width** from `Movement.state(unit)` — the narrowest drivable width
  across the heading over the next leg, or the navmesh clearance at the unit. A8 deforms a formation as a function of
  it, and `Movement.state()` does not carry it today, so I measure it in `SlotGround.corridor_width` off the navmesh
  instead. Mine is coarse (bisection, 3 samples along the leg) and duplicates knowledge nav's layer already has while
  pathing. **After CP2 this matters more:** the navmesh is baked at one agent radius (2.0 m) for a 5x footprint range,
  so tell me what clearance you report for a wider hull.
- **control:** `GroupFormation.follow_slots` (`game/control/group_formation.gd`) lays rows at the flat
  `GroupFormation.SPACING` (10 m) without the hull floor, so a player's *follow* of War Rigs still packs them nose to
  tail. `GroupFormation.slots` is fine — it goes through `place()` and gets the floor for free, which also means a
  player's group move of rigs now opens out to 16 m along the heading. Worth a look at your framing.
- **metrics (CP1):** `Element.state()` now publishes `"pitch"`, `"corridor_m"` and `"file"`; the affine formation
  residual should be read against the **deformed** nominal shape (`offsets_deformed`), not the rigid one, or a
  correctly-filed element in a defile will read as a large residual.

