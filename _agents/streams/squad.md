# Stream: squad (a squad order is a formation order, and every task does what it says)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*, *Unit AI*, *Controlling units*), [../workstreams.md](../workstreams.md) (you own **N2**, and
> half of **N4**; you consume nav's **N1** and arena's **N3**), [../doctrine.md](../doctrine.md),
> [../unit_ai.md](../unit_ai.md), [../squad_ai_design.md](../squad_ai_design.md), and round 5's reports in
> [archive/round5/](archive/round5/) — especially `ai.md`, which records that the element layer does **not** yet beat
> plain brains at 30 a side.
>
> **You own** `game/tactics/**`, the deciding half of `game/ai/` (`formations, squad, squad_tactics, cpu_commander,
> tank_brain, directives, utility_curves, brain_variants, element_feed, matchups, difficulty, tactical_query,
> cover_map, fire_lanes, perception, suppression_feed, incoming_fire, ai_tick_cache, ai_explain_overlay`
> **except `doctrine.gd`**, which is the army-JSON loader and stays combat's, as in round 5),
> `doctrines/`, `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`, `tests/ai_scenarios/`.
>
> **nav owns the wheels; you own the wheel.** You decide where each vehicle should be standing; nav gets it there
> through `Movement` (N1). Do not write path-following or avoidance code.

## The lead's direction (2026-09-18, verbatim)

> *"I don't know if you're managing it like this, but if I select an entire squad and I tell them to move somewhere, I
> would think that there's a higher level abstraction / higher level movement above individual units where there's a
> target formation for the squad and therefore a target position for each individual unit (i.e. no matter where they
> might be currently, there's a formula to "form up"). The more sophisticated we can make this the better. For example,
> it might be easy enough computationally to estimate the position and time at which an individual unit would converge
> with its formation, but we're dealing with a discrete control system, where there should probably be things like PID
> loops all throughout the system somehow… intuitively a PID loop would conceptually be useful for a unit trying to get
> back in his formation."*

> *"we have this concept of quasi military units that should operate with standard operating procedures and so forth.
> The game is still far from coherent in terms of unit behavior. A good standard is Starcraft 2, where the units
> definitely seem smart (but we want our stuff to be even smarter)."*

> *"I finally found the "support by fire button" … and when I clicked it, the units definitely did not form up. In
> general I don't think we have any coherent formations working either."*

> *"We want to be able to set up ambushes, do flanking maneuvers."*

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

**The lead's guess about the architecture is right, and that is the problem: it exists three times.**

- **`game/control/group_formation.gd`** (control's) — a plain player group `move` computes a centroid, a travel
  heading, `choose()` (line when holding, wedge ≤ 5, `rows` beyond), `slots()` centred on the click, `_assign()`
  sorting heavies forward and matching left-to-right *so paths don't cross*, and `pace()` slowing early arrivers
  (`PACE_FLOOR 0.35`). This one is decent and it is the one a plain move uses.
- **`game/ai/formations.gd` + `squad.gd`** (yours) — column/wedge/vee/line/echelon/coil, `DEFAULT_SPACING 12`,
  **`MAX_MEMBERS = 5`**. Followers anchor on the **commander's** position while moving, on the destination when
  halted. `_commander_pace()` slows the leader while followers lag.
- **`game/tactics/tactics_formation.gd`** (yours, newest and best) — the same shapes plus herringbone, swarm and ring,
  **any size**, plus `sectors()` (interlocking arcs of fire), `coverage()`, `frontage()`, `depth()`.

Three shape tables, three assignment rules, three pacing rules. The lead reads the result as "no coherent formations",
and he is describing an architecture he expects to exist — it does, in triplicate, with no single owner.

Three more facts that explain what he saw:

- **A plain `move` deliberately bypasses the element layer.** `rts_controls.gd:42-46`: `attack_move`, `attack`,
  `hold`, `screen` and `support_by_fire` become element tasks; `move` goes straight to `Orders` with
  `GroupFormation` slots, and **a direct order dissolves the element** (`order_selection()`, `rts_controls.gd:607`).
  So the player's most common order is the one that turns his squad back into loose vehicles.
- **Formation slots ignore obstacles.** Both `Squad.context_for` and `GroupFormation` clamp slots to the arena
  rectangle only (`SLOT_LIMIT`), never to the navmesh or a wall. A wedge alongside a container stack puts slots
  *inside* the containers — already logged as a gap at `_agents/tactical_map.md:227`.
- **The element layer does not yet earn its place.** Round 5 measured it: with the control point on, brains-only beat
  faction doctrine 34-14; with it off, 27-21; cutting `break_contact` brings doctrine to parity (24-24), not above.
  Read `archive/round5/ai.md` before you assume elements are the answer — the plan there (an army-level layer above
  the elements) is a *bet*, not a measured fix.

## Backlog (in order)

**X1 — one formation system (N2, CP3).** Collapse the three into one, in `game/tactics/tactics_formation.gd`, and have
control's `GroupFormation` and your `Squad` both call it. Keep the best of each: tactics' shape table and sectors,
GroupFormation's non-crossing assignment and pacing, Squad's leader-anchored movement. The contract:
`slots(element, anchor, heading, count) -> [{"unit", "to", "facing", "role"}]`, recomputed as the anchor moves,
**stable tick to tick** (a unit must not swap slots with its neighbour every frame), and assignment minimising total
travel *and* crossings. Delete the losers; do not leave two live paths. Message the orchestrator when the interface is
on the branch — control reads it for markers.

**X2 — slots must be standable.** Every slot is validated against the navmesh and obstacles before it is issued, and
pushed to the nearest legal point if not. A formation that puts a vehicle inside a wall is the visible half of "no
coherent formations". Use nav's `Movement`/`Pathing` for the query; do not write your own geometry test.

**X3 — form up, with an ETA (the lead's formula).** A squad ordered to move computes the target formation *anchored on
the destination*, assigns slots, and every unit drives to its own slot from wherever it happens to be. Publish
`element.form_up_eta()` built from `Movement.eta(unit, slot)` (N1) — the lead asked for exactly this estimate — and use
it: the group paces to its slowest member (`Orders.pace_factor`), and the leader does not step the next leg until the
element is cohesive (`element_plan.gd`'s `_cohesive()` already does this; make it use the ETA rather than a distance
threshold). Station-keeping inside the formation uses nav's `Pid` (N6) — this is the lead's named use case, and the
acceptance is that a follower settles into its slot without visible oscillation.

**X4 — a plain move must keep the squad a squad.** Change the rule at `rts_controls.gd:42-46` with control: a group
`move` issued to a whole element stays an element move (formation, slots, pacing, a technique), and only an order to
*part* of an element dissolves it. This is the single change most likely to make the lead say formations work, because
`move` is what he presses. Coordinate with control — the ownership seam is theirs, the behaviour is yours.

**X5 — every task does what its name says (N4).** Go verb by verb through `ElementTask.VERBS` and make each one
demonstrably true, with a scenario test per verb in `tests/ai_scenarios/` that asserts the *posture*, not just that
nobody crashed:
- `support_by_fire` — **the one the lead pressed and saw nothing.** Units must take firing positions covering the
  named point, in a line with interlocking sectors, at a standoff, facing it, and *not advance*. Today
  `element_plan.gd:277-290` has the logic; find out why it produced no visible form-up (lesson 17: a behaviour that
  looks under-written is usually being starved by a rule above it — log what *selected* each tick before writing more).
- `screen` — occupy a line across the point, observe, fight only what comes to you.
- `hold`, `attack`, `move` — the boring ones must also be legible.
Then propose the final palette to control: which verbs deserve a button at all (N4 says the mouse's verbs get none),
and what each one promises the player. **A verb without demonstrated behaviour does not get a button.**

**X6 — coherence, measured.** "Even smarter than StarCraft 2" needs a number or it is a mood. Build
`make squad-coherence`: over a match, report unit-seconds spent *idle while in contact*, drill switches per element per
minute (flip-flopping), orders issued per unit per minute (thrash), units outside their slot by more than 2× spacing,
and units whose order is older than 30 s. Publish the baseline, then improve it. Round 4's lesson 17 is your prior:
suspect a precedence rule above a behaviour before writing more behaviour.

**X7 — ambush and flanking, once terrain supports it.** arena is building maps with real approaches; the doctrine
layer should be able to *use* them: an element tasked to a flank takes a covered route rather than the direct one, and
an ambush posture means holding fire until a trigger. Depends on arena's lane/cover annotations (M2) — use them, and
tell arena what annotation you actually need rather than inventing your own.

**X8 (stretch) — the army layer.** `doctrine.md`'s proposal (main effort, base of fire, shaping, reserve) choosing
which elements take the objective and which shape the fight. Round 5 argued this is the missing layer. It is a bet:
if you build it, measure it against brains-only at 30 a side in the configuration players actually get, and report
the result honestly either way.

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `tests/ai_scenarios/` per verb; `make squad-coherence`; `make tactics-parity`; ladders with `tools/ai_ladder.py`.
- **Play it.** `make skirmish`: select a squad, press move, watch whether they form up; press base-of-fire and watch
  whether they take firing positions. Look at your screenshots. This is exactly what the lead did.
- **Measure in the configuration players actually get** (lesson 23): faction armies, 30 a side, control point on,
  default flags. A number from five-vehicle mirrors is not a number about this game.
- Attribute a behaviour's cost only by **removing it** (lesson 25), and never publish a number measured across
  combat's CP4 range change.
- `make ai-perf` / `make perf-scene`: 30 Hz tick, and the brains were 9.3 of 11.6 ms before Jolt. Budget what you add.

## Don't touch

`game/ai/{pathing,steering,combat_motion,order_controller,order_feed,movement,avoidance,pid,control_gains}.gd` and
`game/tank/tank_motion.gd` (nav's), `game/control/` `game/ui/` `game/camera/` (control's), `game/units/`
`game/combat/` `game/match/` (combat's), `arenas/` `game/arena/` (arena's), `game/theme/**` (feel's).

## Waiting on the lead

Nothing blocking. The task palette (N4) goes to him through control's page, not separately.

## Status

_Updated 2026-09-18 by the squad worker._

### Plan and progress (smallest foundation first)

| Item | State |
|---|---|
| **X1** one formation system (N2, **CP3**) | **merged to main** at `df736a8e` (builder0 green, 1030 passed) |
| **X5** support by fire / screen / halts | in CP3; control flipped `earned` on SBF and screen |
| **X5** attack / hold postures (+ herringbone ↔ react-to-contact flip fix) | `16d23375` |
| **X4** a plain move keeps the squad | **done**: `4d734b1e` (47/45 → 0/0 idle orders, five-squad repro); control's windowed five-squad A/B on the merged tree: **0 idle commands** with X4 on — re-landed as `2fa58c01` |
| **X2** standable slots | in CP3 (`SlotGround` over the navmesh's closest point) |
| **X3** form-up ETA + pacing | ETA is nav's `Movement.eta` since CP1 (`0f2d5840`, refreshed 1 Hz; pace = own ETA / slowest ETA); **PID station-keeping waits on nav's N6** |
| **X6** `make squad-coherence` | probe + runner in CP3; attribution + two thrash fixes `824aa258`; **baseline waits for CP4 on main** |
| **X7** covered flanks + ambush task | `a8048028` |
| **CP4 pairing** (fire band, dither, cover timing, suppression threshold) | `1fc83daf`, `5521f741` |
| **Player units hold until ordered** (lesson 47) | `fbf1650a`: a rule, tested as a mechanism |
| Sim baseline | `9ba36681` (8ebbed52, stream/squad pre-CP4; combat's post-CP4 record supersedes it) |
| X8 army layer (stretch) | not started: its measurement needs CP4 on main and N7 (movable objectives) |

**Which instrument caught what (worth knowing before choosing between writing a test and building an instrument):**
`make squad-coherence` (X6) found support by fire and near ambush taking an element from each other every update in a
30-a-side fight — before any scenario did, and hours before combat's CP4 run of the SBF scenario hit the same thing
from the other side (128 orders in 10 s). Scenario tests with four vehicles never put an enemy that close to a firing
line. The posture scenarios (X5) found the herringbone ↔ react-to-contact flip-flop. control's five-squad playtest
found the X4 idle re-issue; the headless five-squad repro now guards it in `make check`.

**Measured (laptop, uncommitted tree on `a975e262`/`df736a8e`, seeded single runs in TacticsLab — posture, not balance):**
support by fire forms a 30 m line 54-56 m off the point, all 4 facing it, 15 shots, no other drill; screen: a 42 m
line 0.5 m deep centred 2.8 m off its point; a plain move ends 0.3 m from the click, worst member 4 m off its slot,
0 orders in the last 10 s; ambush: 0 shots before the enemy entered the kill zone, sprung ~1 s after, 8 after.

### Decisions

- **Seating rule (N2)**, one for everyone, in precedence order: (1) a named leader keeps slot 0 (the point);
  (2) toughness tiers: whatever can take a hit goes where the fire comes from — policy `front` for a group on the
  move (game_design: heavies in front), `exposure` for an element (the lead: heavy armour on the outside);
  (3) within a tier, **minimum total driving** (Hungarian method; a min-total-distance matching provably has no
  crossing paths, so units keep their relative places); (4) the previous seating is kept unless a new one saves
  half a spacing of driving (no tick-to-tick swapping). Why tiers instead of a weighted sum: a weight either lets
  distance override "the tank leads" or lets role override non-crossing among identical vehicles; tiers do neither.
- **`Formations.NAMES` stays the player-pickable subset** (garage, G key, army JSON validation); herringbone, swarm
  and ring are leader choices, not orders. `Formations.MAX_MEMBERS = 5` stays: it is C2's squad-size rule, not
  geometry.
- **The squad wedge changed shape slightly**: one table means the old squad wedge (wing 1.0 × spacing to the side)
  is now the element's (0.9 ×), and the coil radius is the element's. Tests updated to say so.

- **Support by fire's `to` is the point to COVER**; the leader picks the firing line: a line at 0.8 × the element's
  shortest effective range from the point, on the element's side of it, facing it, chosen once and kept. A crew on
  its place holds it; the task outranks react-to-contact and far-ambush (the two rules that used to starve it).
  Control's hint now reads "click what to cover".
- **Base of fire spends `long_shot`** (combat's CP4 override): a support-by-fire element's fire orders carry it, so
  it reaches past the effective band. Only the commander's task spends it, never a crew's judgement.
- **Scenario shooters are props** (`AiScenario.shooter()` defaults to `long_shot`; the orchestrator's option (b));
  a scenario whose subject is fire discipline passes its own weapon order.
- **A plain move is `{"verb": "move", "drills": false}`**: formed-up travel, crews shoot what they pass, no contact
  drill. attack-move stays a move task with drills. (X4; control maps right-click on a whole element to it.)
- **Halts stand on the ordered spot and keep their heading** (round 5's "units end 20-90 m from the click" was the
  halt re-anchoring on the element's drifting centre every update).
- **Flanks go the covered way** (X7): CoveredRoute weighs a meter in the enemy's sight as 4 m of extra driving and
  compares the direct line, wide detours and the arena's annotated lanes; the route is chosen once and kept.
- **Ambush is a task** (X7): a line at 0.6 × effective range from the kill zone, fire held until an enemy is in the
  kill zone (30 m), one is on top of us, or we are hit; once sprung it stays sprung and no timeout ends it.
- **The brain reasons with the band CP4 enforces** (`TankBrain.fire_band`) wherever it asks "can my gun reach that
  far?" for a decision; threat assessment and cover fire keep full range (what can hurt me; a crew under fire may answer
  at any range). Peeks hold until the gun fires and baits stay out until the round is inbound (acquisition takes up to
  1.6 s). The target's `pinned` flag gets hysteresis, which was the real cause of the dither CP4 exposed.
- **Knobs this stream owns carry its prefix** (`AI_*`, `TACTICS_*`, `PARITY_SECONDS`); old names work only from the
  command line.
- **Cohesion is judged in time** (the form-up estimate): allowed = cohesion distance / slowest member's speed.

### Known issues

- control's five-squad windowed run (merged tree, seed 3) shows two outliers 36-39 m from their current slots with X4
  on (mean 6.7 m over 15 element units). Not chased yet: likely stuck or fighting units — nav's `Movement.state`
  can now say which.

- **Thrash with elements on (X6, indicative only):** one smoke match (laptop, `16d23375`, condemned v law, 5200,
  control point, both sides `--*-elements`, seed 1, 60 s, pre-CP4) read ~105 orders per unit-minute and 49-60 drill
  switches per element-minute; `824aa258` fixed the two biggest causes (SBF below near ambush flipping every update;
  the commander re-tasking every second) → 55 / 32 orders and 11.5 / 8.1 switches. Still open: `near_ambush` ending
  without `assault_through` (16 of 19 times) and ~1 order per unit-second of leg re-issues. The published baseline
  waits for CP4 on main.
- **A unit shot at by an enemy it cannot see stands still.** Found staging the attack scenario: a gun at 70 m, past
  the tanks' sight, hit them; the element ran react-to-contact once and then halted in a herringbone. CP4 will mostly
  prevent the situation (a gun may not fire past its crew's sight), but a spotted-by-a-friend gun still can.
  Doctrine says react to contact means moving to cover or toward the fire; worth a scenario after CP4.

- **The dither metric reported double the real rate** from the 30 Hz move until `1fc83daf`; historical dither numbers
  are not comparable with post-fix ones. So did `scenario_evasion`'s duration (ran 60 s saying 30) and the discovery
  bridge's clock (half the real time) and cadence (double) — see unit_ai.md's clock warning.
- `scenario_dodge_rate` finds 0 dodge attempts on CP4 + my fix (raw CP4: 4 of 488 inbound ticks; pre-CP4: 22). A
  4-event sample; combat's X6 (crossing targets harder to acquire) flips the same test. Dodging was already found in
  round 5 to almost never pay. Not in `make check`.
- `ai-scenarios` has 6 failures that pre-date this round (scenario_cp2 ×3, fire_discipline, matchups, squad focus);
  the orchestrator is committing an expected-pass baseline for the suite (lesson 42).

### Questions for the lead

_None yet._

### Requests to other streams

- **nav:** X2 asks the navmesh directly (`NavigationServer3D.map_get_closest_point`) behind `SlotGround.standable()`;
  when N1 exists I'd like `Movement`/`Pathing` to own a "nearest standable point" query and will switch the seam.
  X3's `FormUp.eta()` becomes `Movement.eta()` at CP1; station-keeping waits on `Pid` (N6).
- **control:** X1 rewrote `game/control/group_formation.gd` into an adapter over `TacticsFormation` (its public
  functions and constants are unchanged; `ROLE_RANK` is now TacticsFormation's, where `ifv` ranks one behind
  `burner`). X4 needs the `move` rule in `rts_controls.gd:42-46` changed — see X4 when it lands.

### Merge notes (shared / other streams' files)

- **Green, merge here: `14361035`** (the tip when checked) — builder0 `make check exited 0`, 1081 passed, 0 failed, sim
  baseline 8ebbed52 intact. Includes merged main (CP1), X3 on nav's ETA, and the two band-derived scenario thresholds.
- `game/control/group_formation.gd` (control's, a recorded exception): adapter over TacticsFormation, same API.
- `game/ai/tank_brain.gd` conflicts with combat's proposal `5478fa61` in exactly two lines: **take squad's**
  (`TankBrain.fire_band`, the same expression as `Engagement.effective_range`).
- `tests/baselines/sim_state_hash.txt` → `8ebbed52` for squad's pre-CP4 branch; **combat's post-CP4 record supersedes it**.
- `mk/ai.mk`, `mk/tactics.mk`: knobs renamed `AI_*` / `TACTICS_*` / `PARITY_SECONDS`; old names work from the command
  line only.

### What to playtest (exact commands)

- `make skirmish`, select a squad, press **R** and click an enemy area: the squad drives to a line ~36 m off it (0.8 ×
  its band), faces it and fires; it does not charge in when enemies come close. **E** + click: a wide screen line
  across the point. **B** + click (once control lands the row): an ambush line that holds its fire until an enemy
  reaches the clicked spot.
- Right-click a whole squad somewhere (after control re-lands X4): it forms ONE formation on the click and goes quiet;
  press 1-5 and right-click each in quick succession — nobody should keep re-ordering afterwards.
- At the start of a skirmish, do nothing for 30 s: your units must not move, even with the enemy in sight.
- `make squad-coherence EXTRA="--green-elements --rust-elements"` (after CP4 is on main) for the thrash numbers.

### Next steps

1. After nav's N1 merges: `FormUp.eta` → `Movement.eta` (one line; guard the `{}` a hull nothing drives returns;
   0.85 × top speed is optimistic, don't assert on it), and `SlotGround.standable` onto a nav query if nav adds one.
2. After N6: PID station-keeping in a slot (the lead's named use case). nav measured its PID slot-follower at 0.35 m
   mean gap vs 4.58 m for the old proportional law (slot moving at 5 m/s); N6 is held on a K1-latency trade the lead
   must decide.
3. CP4 is MEASURED (combat's series: kill distance 54 → 40 m; the sight/acquisition gates did most of it, the bands
   little) but its code is **not on main** (orchestrator's correction, 2026-09-18). **Wait for CP4 on main, then the
   orchestrator's sim-baseline record, then** publish the X6 baseline (`make remote T="squad-coherence SEEDS=6"`, both brains-only and
   `--*-elements`), and chase what remains (leg re-issues, ~1 order per unit-second with elements).
4. A unit shot at by a gun it cannot see stands still (Known issues) — a react-to-contact scenario.
5. X8 (stretch): the army layer; arena's measurement says weight support-by-fire by terrain (+0.127 posting value on
   open foundry, +0.024 in dense yard). Needs N7 (movable objectives) for a fair test.
