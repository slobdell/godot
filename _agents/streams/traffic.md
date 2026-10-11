# Stream: traffic (friendly vehicles deconflict: keep right head-on, a rule at every crossing, never against enemies)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* (his words and
> readings (1)–(6)), `_agents/navigation.md` (the give-way of rounds 13–14, ORCA, the wedge/unstick counters),
> `_agents/unit_ai.md`, `_agents/workstreams.md` *Round 26* (C26.1, C26.2, C26.4, C26.5 are yours), and round 25's
> brains report (`streams/archive/round25/brains.md` Status: the give-way priced by removal, the deck funnel). You own
> `game/ai/avoidance.gd`, `game/ai/steering.gd`, in `game/ai/movement.gd` the give-way block (`right_of_way` through
> `_blocker`), `_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`; new `game/ai/traffic*.gd`; new
> `tests/test_traffic*.gd`, `tests/test_avoidance.gd`, new `tests/ai_scenarios/scenario_traffic*.gd`; `mk/traffic.mk`
> (new). **C26.2 matters most:** `_avoid` is mirrored inside `native/src/drive_native.cpp` and `Avoidance.solve` is
> `native/src/avoidance.cpp`, both ON by default; perf ports your diff. Decide in GDScript the native drive calls back
> (`_negotiate`, `_blocker`) or in your own new file wherever you can.

## The lead's direction (2026-10-10, playing round 25's checkpoint)

> *"if I take 2 squads and have theme move in opposing directions such that they have to cross each other (i.e. south
> army goes north, north army goes south), there's clearly a problem: vehicles will get stuck bumping into each other
> and figuring out where to go. THis is likely a symptom of a bigger problem across the board with at least teammates
> cooperating with each other. For example, in a real world scenario, people would just generally each turn to the
> right in order to deconflict. The same case might not be said if we're charging toward an enemy (i.e. maybe it is the
> vehicle's intention to block the opponent's movement). If I was able to induce such conestion on a simple case,
> there's likely congestion problems when armies get clumped together"*

> *"Also on my earlier note about congestion, the same behavior applies when one vehicle is making a 90 degree angle
> with another vehicle's path. In the same way it probably makes sense for friendly units to agree on how to
> deconflict"*

The readings (not his words): his reproduction becomes a scenario with a pass line FIRST; friendlies meeting head-on keep
right (both turn the same way); the convention covers ANY crossing angle (his 90° case is a second scenario), with a rule
for who yields; it does NOT apply against enemies; and because he expects the same root cause in every friendly clump,
the round measures congestion in big fights too, before and after.

## Where things stand (VERIFY at main)

- Avoidance is ORCA (`avoidance.gd`, native `avoidance.cpp`, `native_avoid` ON), plus round 13–14's give-way: a crew
  blocked by a friend asks it to yield (`right_of_way`, `ask`, `_begin_yield`, `_yield_fits`…), with counters in
  `Movement.route_arms()` and the switches `yield`, `yieldclear`, `yieldfit`, `yieldhold`, `yieldshort`
  (`--nav-off=…`). Round 25 priced the give-way by removal at ~0 on arrival time.
- `make nav-orders` (5 player squads ordered across each other at once, yard, NAV_ORDERS t50/t90/t100,
  never_completed), `make nav-yield-buckets`, `make nav-yield-clip`, `make two-squads-playtest` (orders' probe of two
  squads given ONE point), `make bridge-pooled` (his bridge drill; must not get worse).
- Nothing today encodes "keep right" or a crossing rule; ORCA's reciprocal split is symmetric per pair, so two hulls
  head-on can each sidestep the same way, or dither.

## Backlog (in order)

**T0 — his two cases, counted, with pass lines first (before any fix).** Two scenarios (TacticsLab or `ai_scenarios`,
your files): (a) **head-on**: two of his squads (5 each, mixed hulls as `make skirmish` deals) ~120 m apart on open
ground, ordered through each other's start; (b) **crossing**: the same at 90°, timed so the squads reach the middle
together. Both also on a street map (Terminus) where the road is ~2 hulls wide. Per run: every crew's arrival time,
stuck crew-seconds against a FRIENDLY (speed < 0.5 m/s with a friendly hull in its way, C26.5's label), friendly
contacts, k-turns started with a friendly as the obstacle, the ratio of the crossing's last arrival to each squad's
solo time. Pool over the pre-registered start ticks (C26.6) and 3 seeds. Pre-register the pass line in Status before the
fix (suggested: every crew arrives; friendly-stuck crew-seconds cut by ≥ 75 %; the crossing's last arrival ≤ 1.2× the
solo time; zero friendly contacts at > 2 m/s). Record what a player would see at main (a his-pose clip at the meeting,
`make` target in `mk/traffic.mk`; look at the frames).

**T1 — the census in big fights.** The same friendly-stuck crew-seconds, friendly contacts and friendly-obstacle k-turns
over Sumps 25 a side (both CPU) and the army series, at main, 3 seeds. This is the "before" of his clump hypothesis;
report what share of all stuck time is friendly.

**T2 — the convention (DECLARED, C26.1; CP1).** Design first, in `navigation.md`, before code (lesson 278: the rule
written before the number): head-on → both keep right (a lateral bias toward each crew's own right, started early
enough to be smooth, not a last-metre swerve); a crossing at any angle → one crew yields by a rule both compute
identically (C26.4: suggestions — the crew with the other on its right yields, as a road "priority to the right"; or the
one arriving later at the conflict point slows; pick by T0's numbers and say why). It is friendlies only (team check at
the source); a crew already yielding or in a k-turn is an input. The CPU uses the same rule. Prefer ORCA's preferred
velocity (a bias) and the callback layer over rewriting the solver; send perf the diff for anything in `_avoid` or
`Avoidance.solve` (C26.2). Pass: T0's pre-registered line on both cases and both maps; `make nav-orders` not worse;
`make bridge-pooled` not worse; the arrive series and the thirteen lines read as declared; a his-pose clip of each case
looked at. Merged alone with perf's port.

**T3 — the census again (after CP1).** Re-run T1; report the friendly share before/after, with manoeuvre's C26.5 labels
once CP3 lands.

**T4 — stretch: the clumps T3 still shows.** The top remaining friendly-jam pattern from T3's traces (a queue at a gap,
a squad overtaking another, a crew backing into a friend), each a scenario first, each its own declared change.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`), your scenarios pooled over
start ticks and seeds on builder0, the his-pose clips on the laptop through the orchestrator (C26.7). Every number
carries commit, machine, workload and n.

## Don't touch

Manoeuvre's `movement.gd` block (`drive()`'s body, `unstick`, the k-turn / planned-reverse / circle block),
`game/tactics/**` (brains'), `native/**` (perf's), `game/control/**` (orders'). A hook you need in `drive()`'s body is a
request to manoeuvre through the orchestrator.

## Waiting on the lead

Nothing. Questions go in Status; take the most reversible option.

## Status

_Not started._
