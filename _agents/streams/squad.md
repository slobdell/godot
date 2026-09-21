# Stream: squad (a transient element from any selection, and a player's order that pre-empts everything)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*, *Controlling units*), [workstreams.md](../workstreams.md) (*Round 10: the eight streams*,
> contracts **R1**, **R2**, checkpoint **CP1**; *What reads `hull_size`*), [squad_ai_design.md](../squad_ai_design.md),
> and your round-9 brief in [archive/round9/squad.md](archive/round9/squad.md) — its "ROUND 10 STARTS HERE" list is
> folded into the backlog below.
>
> **You own** `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,cpu_commander,tank_brain,directives,
> utility_curves,brain_variants,element_feed,matchups,difficulty,tactical_query,cover_map,fire_lanes,perception,
> suppression_feed,incoming_fire,ai_tick_cache,ai_explain_overlay}.gd`, `doctrines/`, `game/agent/`,
> `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`, `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,
> unit_ai,doctrine}.md`. **Invariant 0c governs the brief:** every item names what it REPLACES, by file and function.

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> When I select a set of units that doesn't necessarily belong to a squad, the buttons to do support by fire or
> whatever the case is is disabled - any way we can make that usable for new, random selections?

> I'm also trying to move units, and they weren't responding (I can see improvement for sure in formation generation
> and stuff). But I had a selection and the yellow X's on the map were in the center, that's where they were driving
> to, and I was trying to right click to move them in a different direction and they didnt respond

> I want to gauge how smart units are by trying to navigate them through the city.

The orchestrator's reading: he noticed the formations (that is your round 9 landing). What blocks him now is that the
element layer only exists for numbered squads, and that a task in flight can outlive his next order. **Your first live item
is the task half of the round's first blocker (R2)**; control owns the input side.

## Where things stand

- **Elements exist only for numbered groups.** `RtsControls.assign_task` (`game/control/rts_controls.gd:519-528`,
  control's) forms an element from a numbered control group; an unnumbered box-drag selection has no path to one, so
  the task buttons grey out (`selected_element()` demands exactly one element and all its members). R1 asks you for
  ONE call: form an element from any list of friendly units with a task, base and manoeuvre split by role and position,
  its split published in `Element.state()`, dissolved when any member gets a non-element order. Nothing about the
  element machinery itself needs to change; what changes is who is allowed to create one.
- **A task in flight can swallow a fresh move.** `Element.assign()` (`game/tactics/element.gd:145-163`) resets leg,
  route and drill; crews' orders are re-derived by the leader, and the re-issue suppression at `element.gd:562-583`
  (`_same_place(..., REISSUE_M)`, the `"hold"` handling) can keep crews on the old geometry after a new task. R2:
  after a fresh player task every crew's order changes within 2 ticks. control reproduces on the default path and
  sends you the per-crew log; do not wait for it to start, the mechanism is readable in your file.
- **Hold-on-arrival** (`d29115ae`, round 9): a dragged heading reaches every crew as a standing `hold`. A hold is a
  standing order and must yield to the next player order instantly (R2); check that it does.
- **40 s from a right-drag to a settled squad on a 20 m move** (round 9, orchestrator's item found on the way): 22.3 s
  for the element to declare arrival, ~20 s more for the crews to stop; A9's co-arrival pacing waits on the slowest
  member (`game/tactics/form_up.gd:55-64`). He will feel that before he sees any heading.
- **Your round-9 list**, folded in below: slot pitch from the turning envelope (item 1, DECIDED for you: hulls do not
  clip while dressing; the pitch gives a hull room to rotate, `half_diagonal − half_width` beside it, tank +1.27 m,
  War Rig +3.53 m; the roominess is the price and he sees it on the field); `_is_clear` ignores each placed vehicle's
  forward (item 3); Delta's margin at 62 % of budget (item 4); the base-of-fire scenario
  (`scenario_elements::test_the_base_of_fire_keeps_firing_while_the_others_move`) was passing on a neighbour's leaked
  navigation state and fails in 1.4 s once drained (metrics' four-run table in
  [archive/round9/metrics.md](archive/round9/metrics.md) "The one finding to carry into round 10"): a behaviour
  finding, yours. `test_tactics_deform`'s `super.teardown()` (item 5) is done under nav's seal.
- **Stood-down rows** (A10's `fixed` guarantee at `c0f22597`, A8 off the switch or off the branch, the tube's
  five-seed gate, A9's cost against the 4 s drill allowance) are stretch; the round's bar is his playtest, not a row.

## Backlog (in order)

1. **WITHDRAWN (the lead, 2026-09-20 night): no transient-element API.** He found that regrouping a mixed
   selection (Ctrl+1–5) already makes it a squad with formation and element orders, calls that good behaviour, and
   wants only the UX to say so; control owns that. Nothing to build here; keep `Element.state()` publishing the
   base/manoeuvre split for control's readout, and take the fitness split (research row B8) only if a numbered group's
   element formation lacks one today.
2. **R2 on your side.** A fresh task on an element re-derives every crew's order on the next tick; the re-issue
   suppression yields to a task with a new id; a standing hold yields to any player order. The integration test is
   control's (item 1 of its brief) and it runs on the default path; your unit test asserts the ORDER on each crew two
   ticks after `assign()`. Mutation-check both.
3. **The settle time.** Measure the 20 m move end to end (order → arrival declared → crews stopped) on the default
   arena and Terminus, then cut it: arrival declared when the leader's slot is reached, not the slowest member's;
   co-arrival pacing bounded (A9 keeps its shape; a bound is a number with a reason). Bar: a 20 m move settles in
   under 10 s on flat ground; print the three times on every run.
4. **Slot pitch from the turning envelope** (your round-9 item 1, decided). `TacticsFormation.HULL_CLEAR_M` stays a
   name that says which motion it licenses (nav's lesson 197): the lateral pitch is `max(width + HULL_CLEAR_M,
   2 × (half_diagonal − half_width) + width)` or the form you can defend, with a test that a formed squad can be
   ordered to a new heading and no pair's turning envelopes intersect. Pre-register the baseline: a pitch change
   moves the sim baseline (CPU armies use it); merge alone, tell the orchestrator.
5. **The base-of-fire scenario, honestly.** Reproduce with the drain (`make ai-scenarios` on a sealed tree); the
   base stops firing while the others move because of what? Fix the behaviour or re-specify the scenario with the
   reason; the count baseline is re-recorded by the orchestrator with your REASON.
6. **`_is_clear` compares rotated boxes as aligned** (item 3) and **Delta's margin** (item 4): the first is a test
   with an arena whose spawn zones are not opposed; the second is a measurement that says what Delta's worst crew is
   doing at 22 m, then the fix or the number written down.
7. **Stretch, in your round-9 order:** A10's `fixed` guarantee (`c0f22597`); A8 off the switch or off the branch;
   the tube's five-seed gate; the duel bar to a rate; A9's cost against the 4 s allowance.

## How to verify

- `make check` green (`make remote T=check`), `make ai-scenarios` with the count beside the hash.
- `make skirmish ARENA=terminus`: box-select units from two squads, give support-by-fire, watch the split; give a
  move mid-task, watch every crew turn within a tick. `make squad-defile` for the maze. Frames at his pose for anything
  visual.
- Every number: commit, machine, sample size; every arm proven applied (round 9's rule).

## Don't touch

`game/control/`, `game/ui/` (control's: send the API and a failing test), `game/ai/{movement,combat_motion,pathing,
steering,avoidance,pid,control_gains,order_controller,order_feed}.gd`, `game/tank/tank_motion.gd` (nav's),
`game/tank/`, `game/units/`, `game/combat/`, `game/match/` (combat's; the spawn grid constants are arena's this round),
`arenas/`, `game/arena/` (arena's), `game/theme/**`.

## Waiting on the lead

Nothing blocks. The pitch decision (item 4) was made for him; he overrules on the field.

## Research addendum (brief 2, 2026-09-20 evening; rows B1, B2, B7, B8, B14)

**R1 gets its default split (B8):** fitness S = (range × DPS) / (speed × agility), agility 1.0 tracked/hover, 0.5
wheeled, 0.2 articulated; sort descending, ties by unit id; the top ⌈n/2⌉ are the base element; then match the
assignments to positions projected on the normal of the target vector so deployment paths do not cross. Falsifier:
zero crossing deployment paths on five random selections.

**Item 3 (the settle time) is re-specified (B7): arrival is three phases.** Transit under pacing → OPERATIONAL
ARRIVAL the instant the formation centroid enters the destination zone and every hull is braking: the player's order
is COMPLETED here, pacing lifts, weapons free → INDEPENDENT DRESSING per crew: tracked and hover hulls neutral-steer
to the facing; wheeled hulls stop on their slot and keep their approach heading, accepting a residual (the turret
covers the sector). Our bar: a 20 m move on flat ground reports COMPLETED in ≤ 8 s with no rise in collisions. This
replaces the round-9 ruling that a held wheeled hull manoeuvres to its facing, EXCEPT for hull-fixed wheeled units
whose weapon arc the residual exceeds (nav's row). Composition rule (B14): during dressing, tracked hulls hold
turning-room priority and wheeled hulls never claim it.

**Item 4 (pitch) is confirmed as an invariant (B2):** lateral slot pitch ≥ the turning envelope's diameter unless
the element is deliberately single file.

**Acknowledgement within one second (B7):** on any player order a crew shows visible intent within 1 s on the default
path (turret slews toward the destination, the nose begins to turn) before the hull moves; control draws the pin at
the next tick. Cheap; it buys tolerance for everything slower.

**The funnel (B1) is what you publish for nav's seam item:** the element's corridor as a chain of convex polytopes
plus the leash, in `Element.state()`, so the mover can project onto it. Build the publisher when nav asks; the shape
is in the catalog row.

## Research addendum 2 (brief 3, 2026-09-20 late; rows C1, C2, C6)

**The funnel you publish (B1) has a construction (C1):** it is the string-pulled corridor's polygons shrunk by the
member's effective clearance and intersected around each portal; nav owns the construction, you publish the
element's corridor and leash so nav can build it per member. **`incoming_fire.gd:101` is one arm of combat's series
(C6):** give it its own knob so the disc can be swapped at that one site with the others held; the series pairs
arms by seed. **"Who yields" during dressing (C2):** the deterministic key nav adopts; tracked hulls hold turning
room (B14) and the key breaks the rest.

## Status

_(the worker keeps this current)_
