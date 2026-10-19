# Stream: orders (one click, several squads: everyone goes where he clicked, never across a bridge he didn't pick)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 34** (C34.11), and
> `_agents/game_design.md` *Round 34, his playtest words during the round: one click, several squads* (verbatim, with
> what was decided). History of this code: round 19–23 orders briefs in `streams/archive/round19/` … `round23/` (O1 ranks,
> O1b untangle, O3, O4 nesting), whose lead quotes sit in the file headers of `game/control/selection_squads.gd`.
> **You own:** `game/control/**` EXCEPT manoeuvre's additive fields in `game/control/screen_playtest.gd` (round 34 grant;
> don't edit that file), `tests/test_control*.gd`, `mk/command.mk`, `references/round34/orders/**`.
> **Granted (C34.11):** READ-ONLY calls into `game/tactics/slot_ground.gd` (`path_length`, `reached_directly`),
> `game/ai/pathing.gd` and the navmesh; for O4 only, the queued-move "done" rule in `game/tactics/element.gd`
> (`_next_queued` and a helper beside it; brains owns the file: merge note, and tell the orchestrator before you edit it).
> **Model:** Opus.

## The lead's direction (2026-10-18, verbatim in game_design.md)

> "If I select 3 squads and then tell them all to move to some point on the map, there's some algorithm that
> automatically determines new points for each squad … in my last game I told 3 squads to go to a single waypoint, but
> because there were 3 squads, 3 waypoints were selected, where one of them was all the way across the bridge, thus
> causing one of my squads of scouts to go on a suicidal mission. How can we get behavior closer to starcraft, where I
> can click some target waypoint and have all units go to it? … The current setup makes it impossible for me to select a
> bunch of units and have them follow some target route."

His corrections: "Must we assume that the squads can't overlap with each other? … isn't there enough spacing where we
could intersect two wedges basically?" and "if we overcorrect on this term then we might have 25 vehicles all trying to
roll through the same waypoint. The waypoints are obviously sort of loose guidelines, and it's more about the squad
moving through that waypoint versus individual vehicles." Then: all four recommendations stand, with those two
corrections folded in. **He says the game is unplayable while this is wrong: this is the round's most player-visible item.**

What he will notice: three squads sent to one point all end up near that point, on the side of the river he clicked;
a shift-clicked route is followed by the squads as squads, not funnelled vehicle by vehicle through each point.

## Where things stand (main at the round-34 docs commit)

- `RtsControls._order_squads` (`game/control/rts_controls.gd` ~1086): one click with several squads → `SelectionSquads.ranks`
  (≤3 abreast, ranks behind, `nested_offsets` nests ranks since round 23) → `fit_inside` slides the body off the ARENA
  WALLS only → `untangle` re-deals vehicles whose straight paths cross → one task per squad to its own anchor.
- Each squad is priced by `_squad_width` at a LINE's frontage under AUTO (the widest shape the leader might pick): five
  crews at 14 m ≈ 56 m, plus `GAP_M` 14 between squads. Three squads abreast put the outer anchors ~70 m from the click.
- **Nothing asks the ground.** An anchor 70 m sideways can be hundreds of metres by road, over a bridge, into the enemy.
  That is his scout squad. `SlotGround.path_length` / `reached_directly` (REACH_DETOUR, REACH_SLACK_M) already answer
  "how far by ground" and "is this a detour" for slots; nothing in control calls them.
- Shift-queued moves (`_queue_task_for`) give each squad its own anchor at EVERY waypoint (the same `ranks` spread), and
  an element's queued move is "done" only when the element has `arrived` (formed up) at it (`Element._next_queued`), so
  a route of waypoints is a series of stop-and-form-ups.
- Tests on this path: `tests/test_control_squad_ranks.gd`, `test_control_two_squads.gd`, `test_control_untangle.gd`,
  `test_control_oversize_squad.gd`, `tests/test_tactics_squad_split.gd` (brains'; read it). Probe: `make squad-orders-test`
  (needs a display: laptop, not builder0); `make squad-partial`, `squad-settle` (tactics.mk, brains') as references.

## Backlog (in order)

1. **O1 The ground cap (ship first, small).** After `fit_inside`, any squad's anchor whose drive from the CLICK is more
   than ~1.5× its straight offset (+ slack), or more than ~30 m straight, comes back toward the click along the ground
   (nearest point that passes). Test first: a stage with a river and a bridge (crossing / locks have them: arenas JSON
   names "west bridge", "west swing bridge"), three squads clicked on the near bank beside the bridge: today one anchor is
   across (the failing test), after O1 none is. Pure where it can be (the length callable injected, as `untangle`'s
   position callable). Commit, quick-remote, name a hash, tell the orchestrator: it can merge alone.
2. **O2 Places found by driving distance, with hull clearance (his correction 1).** Replace "lay a block in the air, then
   clamp" with: flood outward from the click over drivable ground (navmesh / the ground grid) by DRIVING distance; seat
   squads into the nearest free ground in order of arrival along their approach. The constraint between squads is
   **hull-to-hull clearance between vehicles of different squads (~9 m, decide and record)**, NOT squad boxes: two
   wedges may nest and overlap footprints. Each squad takes places on its own side of the approach so paths don't cross
   (`untangle` stays as the backstop). Never across a choke the click is not beyond: tight ground stacks later squads
   back along the road they came in on, near the click (decided; StarCraft's "everyone goes to the click, space settles
   on arrival"). A drawn facing still lays them out as drawn (round 10's rule), capped by O1.
   **Brains' B6 finding (2026-10-18, stream/brains 661be82f7, trace references/round34/brains/b6_relay_trace_sumps41t3_laptop.txt):**
   an AUTO element travels in a wedge and, the tick its centre enters the arrival radius, `_halt` re-lays every seat in
   the doctrine's HOLD shape (herringbone, ±16–17 m along v the wedge's ±9.3): crews swerve 4–10 m outward as they
   "arrive". Brains' B6 will lay the halt shape from the final approach. **Pack O2 to the HALT shape, not the travel
   shape**, and read O3's "shape it will arrive in" as the halt pick.
3. **O3 Price a squad at the shape it will arrive in.** Under AUTO, the shape its leader will halt in (the doctrine's
   pick for that terrain, and `min_step`'s halt depth), not a line's frontage. Record the footprint before/after for 3×5.
4. **O4 Waypoints are the squad's (his correction 2).** For a shift-clicked route: an in-between waypoint is passed when
   the SQUAD's centre is within about its own width of it (crews keep their slots, never aim at the point, no stop to form
   up); for several squads, a waypoint is a GATE as wide as the ground there: abreast or in ranks in the open, single file
   only where the terrain narrows (a bridge, a gap; traffic's give-way decides who goes first). Only the LAST waypoint
   packs by O2. This touches `Element._next_queued` (grant above): agree the rule with the orchestrator before editing
   brains' file; if brains needs to own the edit, write the request and build the control side against it.
5. **O5 The player test.** A scripted probe in your paths (or extend `--squad-orders-test`): 3 and 5 squads, one click
   and a 3-waypoint shift route, on the Locks, the Crossing and the Terminus; report per squad: straight offset from the
   click, drive length, whether it crossed a bridge, arrival time, nearest foreign hull. Screenshots at desktop and phone
   aspect, top-down, at arrival; look at them. This is what he will judge by eye.
6. **Stretch:** the order markers (the dots he sees at the click) show each squad's real place before he lets go of the
   button, so a bad spread is visible before it happens.

## How to verify

Tests first for each item; `make quick-remote` while iterating; `make remote T=check` for a hash you will name.
`make sim-baseline` must not move (the CPU orders through `cpu_commander`, not `RtsControls`; if it moves, find out why
before anything else). The probe (O5) on the laptop with a display; every number with commit, machine, map, n. This is
a feel item: no judged series bar unless the orchestrator asks for one. His eye is the check that counts.

## Don't touch

`game/ai/**`, `game/tactics/**` (except the O4 grant), `game/control/screen_playtest.gd`, other streams' tests and mk
files, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

(the worker keeps this current)
