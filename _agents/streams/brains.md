# Stream: brains (the computer defends and lies in wait; a tasked squad never stops short; the element machinery cheaper on his laptop)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 18 direction* (*His pick*: smart
> on both sides) and *Round 19 direction* (item 2's second path is yours to guard), `_agents/doctrine.md`,
> `_agents/navigation.md`, `_agents/workstreams.md` *Round 19*, and your round-18 brief's final report
> (`streams/archive/round18/brains.md`: B4, B5(a), the price of CPU squad leaders). You own `game/ai/**`,
> `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`,
> `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`.
> **Lent to orders (C19.1):** one guard line in `Elements.form` (`game/tactics/elements.gd:80`): an element is never
> formed with more than `Formations.MAX_MEMBERS` members. You do not edit that line this round; you re-read it after
> orders' checkpoint.

## The lead's direction (standing, 2026-10-04; and 2026-10-05)

> *"Yes make the CPU smarter, this would apply to all units. We want to make the computer opponents hard, but kind of
> like in Gears of War, our friendly players are just as smart, so it just makes the game better."*

And on 2026-10-05, after two games on the twelve maps, his second item (the orchestrator read both paths; the
second is in your paths): *"I selected 2 squads and right clicked a point on the map - the resultant indicator dots
for all the units was all over the map, and a bunch of vehicles just basically ran off to the middle of the map."*
Orders owns the fix (one order per squad); the element machinery must make the bad case impossible (C19.1).

## Where things stand (read at `93ec68b4`)

- **Your round-18 ambush work is unmerged**, on branch `brains-r18-ambush` (renamed from `stream/brains` at the
  launch; `brains-wip-backup` also exists): `AmbushSite`, the commander choosing an ambush, the in-time rule
  (`4b060f00`), `ambush_probe.gd`, `ai-element-perfplay`, `element-digest` (`d6c7f3e1` is its tip). D1 on that
  branch (`6e0e116f`) is on `main` as `a122d6ff`: cherry-pick the rest onto this round's branch (which starts at
  `main`) and do not merge the old branch wholesale.
- **Measured (your own, round 18):** with elements on, the CPU takes 0 ambushes in his frame on parade over 8 seeds
  with the in-time rule; before it, 7 of 8 taken, 5 sprung, from a bay never: both sides race for the centre; the CPU
  needs about 100 m at 7–8 m/s to reach a bay, his line about 77 m at 9 m/s to reach the kill zone. **A bay ambush
  needs a CPU that DEFENDS.** The price of CPU squad leaders on his laptop (quiet window, equal vehicle counts, 23
  bins): mean +6.5 ms a tick (+20 %), median +4.6; of a sampled frame's +3.0 ms self: navmesh grounding of every
  slot +0.87, the tactics layer +0.92, the feeds +0.4, the brain's order paths +0.37, the ambush search +0.07.
- **In his skirmish today the CPU runs no squad leaders** (elements off on the CPU side); its commander never issued
  an ambush. Whether to turn CPU elements on for him is HIS decision; it was not put to him in round 18 because it
  would have cost him 20 % and shown him no ambush. This round makes the question answerable: a posture that
  produces ambushes he meets, at a price that is measured and cut.
- **One spot on the Cut** (roadmap round 19 candidate 4): seed 3, at (−4.1, 44.9), open ground 6 m from a city
  block's face; the re-seat fires its 3 allowed times and the squad stops 105 m short, one crew 18.5 m off its slot.
- Orders found in your paths (do not fix before O3 merges; judge and reply): `ElementPlan.clamp_to_arena`
  (`element_plan.gd:1298`) is the old square ±116 clamp, not the arena shape's; `Element.remove` (`element.gd:580`)
  emits no `element_changed`, so a brain can hold a stale station for one poll; `Elements.form` takes any number of
  members and `ElementPlan.build` never passes `TacticsFormation.auto`, so a 10-vehicle wedge is 126 × 70 m.
- The twelve-map rotation is dealt (`da0bdef3`): thirteen baseline lines (foundry + twelve), every one of your
  changes to fights is declared and merged alone (C19.3), as in round 18.
- The per-map 40 s baselines hold no bait on four of the six older maps (roadmap candidate 5): a decision change
  needs its own series. `make sim-variants` (ship, round 18) is the instrument.

## Decided by the orchestrator (broad strokes are ours; record a reason if you overturn one)

- **The posture comes before the price question.** A CPU side that is ahead on points, or whose zone is
  threatened, HOLDS: its line elements take positions covering its zone, and one lies in ambush on the flank of the
  open ground the enemy must cross (B5(a) as built, now with a reason to be there in time). A CPU behind on points
  attacks as today. The trigger is the match's own score (read `Match.control_score` / the objectives' owners; the
  board stream adds a `score_changed` signal, C19.4: read it when it lands, poll until then).
- **Both sides.** The same posture is available to his squads as an order he can give ("hold here, ambush the
  crossing" = the existing Ambush order with a `from`), so nothing is CPU-only (his rule). No new order button this
  round: orders owns the UI; file a request if the existing Ambush order needs a parameter.
- **The price is cut before it is offered.** Equal-answer work on the element machinery (the navmesh grounding of
  every slot, the situation build, the feeds), proved by `make element-digest` (your round-18 instrument: identical
  decisions, lower cost), each saving stated as ms on his laptop in a quiet window asked for through the orchestrator.
- **His question is prepared, not asked by you:** "the computer sets ambushes on the open maps; it costs about X ms
  a frame on your laptop (after the cuts); recommended on / off". The orchestrator asks it with your numbers.

## Backlog (in order)

- **B1. Carry the ambush work forward.** Cherry-pick the unmerged commits from `brains-r18-ambush` (skip D1), green
  on `main`'s tree, every scenario passing, `--no-cpu-ambush` still the control arm, CPU elements still OFF on his
  path. Pre-register UNMOVED on all thirteen lines (nothing runs on his path or in the baselines' CPU armies unless
  elements are on: say which it is before the check).
- **B2. The posture: hold and lie in wait.** `ElementCommander` chooses HOLD for a side that is ahead on points or
  whose zone is contested, posts its elements over its zone and one ambush on the flank of the enemy's approach
  (site search from the zone, not from the element); ATTACK otherwise. Scenario first (`tests/tactics/`): on parade,
  CPU ahead on points, his line crosses the floor → the ambush is taken in time and sprung from a bay (today: never).
  Then `ambush_probe.gd` in his frame, 8 seeds, parade and the Open Yard: ambushes taken, sprung, and the outcome
  paired per seed against the control arm (lesson 256: paired differences with their spread; an event count under
  about 30 is a count, not a rate).
- **B3. The price, cut.** The element machinery's per-tick cost with elements on: the three largest terms by
  removal inside one run (your profiler split), each cut as equal-answer work proved by `element-digest`; the
  interleaved on/off series again (`ai-element-perfplay`) in a quiet window the orchestrator schedules, equal
  vehicle counts, before and after. Report the new +ms with its spread.
- **B4. The Cut, seed 3.** The squad that stops 105 m short beside a wall: reproduce with the probe, name the cause
  (the re-seat cap? the slot ground beside a face? the corridor?), fix it for both sides, prove it on the Cut and on
  the Sumps and Terminus (D4/D5's 80 of 80 must still hold). Declared if any line moves.
- **B5. Two squads, one element: never.** After orders' checkpoint (CP2) merge `main`, re-read the lent guard, and
  add the tactics-side tests: `Elements.form` refuses more than `MAX_MEMBERS`; an element's transit anchor is its
  own centroid only when its members are within one formation width of each other (otherwise the lead vehicle's
  position); `ElementPlan.clamp_to_arena` uses the arena's shape; `Element.remove` emits `element_changed`. Each
  pre-registered; any line that moves is attributed before the merge.
- **B6. A decision change has its own series** (roadmap candidate 5). Write the rule for this round: the set of
  maps and seeds on which B2's and B4's decision changes are visible (where the 40 s baseline sees nothing,
  `sim-variants` with a longer match or a bait), and run it for each declared change. The orchestrator relays the
  recipe to the handoff.
- **Stretch.** (a) The CPU holds with its artillery registered on the kill zone (the ambush sprung by a barrage).
  (b) The Ambush order for his squads takes a `from` he picks (request to orders for the gesture). (c) The idle
  fallback that sends an ordered CPU unit to the objective (`tank_brain.gd:2487, 2529`): confirm his units can never
  reach it (orders' first suspicion for "ran to the middle"); a test that pins it.

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` and `N
passed, M failed`; never a pipe). **Every change to fights is DECLARED, merged alone, and its moved lines adopted
with `make sim-baseline-adopt`; everything else pre-registers UNMOVED on the thirteen lines and determinism**
(C19.3). Scenario or probe first; a ladder or a paired series for anything that changes who wins; `make
ai-scenarios-check`, `make tactics-drills`, `make element-digest`; the laptop series only in a quiet window asked for
through the orchestrator (lesson 260: the count of other Godot processes read before AND after each run; a run with a
neighbour discarded, kept with that written on it). Every number: commit, machine, workload, N, spread.

## Don't touch

`game/control/**`, `game/ui/**` (orders and board) · `game/garage/**`, `game/progression/**`, `game/units/**`
(garage; `Units` read freely) · `game/match/**` (board; read `Match` freely; a signal you need is a request) ·
`arenas/**`, `game/arena/**` (nobody; a layout defect is a request) · `mk/core.mk`, `tests/baselines/**` except the
lines you declare and adopt (C19.3) · balance values (C12.6; his) · the elements flag's default on his path (his
decision; B3 prepares it).

## Waiting on the lead

- **CPU squad leaders on in his skirmish** (the posture needs them). Asked by the orchestrator with B3's number.

## Status

(the worker keeps this current)
