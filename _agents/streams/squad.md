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

**Not started** (brief written 2026-09-19 evening by the orchestrator; launch commit to follow).
