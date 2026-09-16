# Stream: control (the vision-framed camera, command at scale)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 4 direction*: camera and vision, doctrine, army size), and [../workstreams.md](../workstreams.md) (L4 is
> yours; you consume doctrine's L1 and combat's L3). You own `game/control/`, `game/ui/` except `widgets/**` and
> `hud.tscn`, `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline}_mode.gd`, `mk/command.mk`, and
> `_agents/tactical_map.md`. Round 3's brief and report: [archive/round3/control.md](archive/round3/control.md).

## The lead's direction (2026-09-16)

> *"the game is still fairly unplayable because the camera doesn't really track the vehicles … we should optimize for
> the game being more zoomed in in general (i.e. closer to a Twisted Metal versus Starcraft if we put those 2 on a
> spectrum) … it really should automatically track the entire set of friendly units, and basically always zoom in as
> close as possible with the constraint can see the same horizon as what all units can collectively see (that in itself
> is actually a large and difficult problem, but you can do it). Basically zooming in and constraining the user's view
> is a legitimate limitation that the player would have to overcome by actually pointing in the correct direction (i.e.
> a bird's eye view is just an unearned god view; we want to actually make the users expend their sentries to be able to
> see, that sort of thing)."*
>
> On scattered forces, the lead agreed with: **frame the element you're commanding**, with off-screen markers and
> alerts for everyone else. On command at scale: *"we keep control groups plus automatic elements"*; a named hierarchy
> is out *"unless there's a sleek way we can figure that out from a UX perspective"*.

## Where things stand (round 3)

Selection (click, box, shift, double-click by type), right-click orders, attack-move, shift-queued waypoints, follow,
stop, hold, ctrl+1–9 groups, group moves with automatic formation slots and regrouping, the selection panel and command
card, order markers and acks (feel's), `RtsCamera` with framing and order tracking, the control point on by default.
Orders go through `Orders` (K1). Playtest: `make control-playtest-shots`.

## Backlog (in order)

**X1. The vision-framed camera (L4).** The camera fits what the commanded element can currently see: its units' sight
radii, its spotted contacts, and its destination, then zooms as close as that region allows (a `max_zoom_in` the player
can't exceed by scrolling). Smooth, no lurching as units turn; manual pan and zoom always win and hand back after a
pause. Write the fitting as pure math with tests (region → camera pose), then wire it. Include a "look" mode that can
peek beyond the region **only** where the team already has vision.

**X2. Element focus and awareness.** Switching elements (control groups, Tab, or clicking a unit) moves the camera to
that element. Everyone else gets **off-screen markers** on the screen edge (element, health, contact state) and
**alerts** you can jump to ("Bravo under fire", "contact north"), rate-limited. The radar keeps the whole arena; it is
now the main way to read the map, so make it excellent: contacts, last-known enemies, element positions and facings,
click to look, right-click to order.

**X3. Tasks, not geometry (with doctrine's L1).** The command card issues **tasks** (move, attack, screen, support by
fire, hold) to an element, not formations. Show the element's current formation, movement technique and drill with a
one-line reason ("bounding overwatch: contact ahead"). Let the player override the formation, but never require it.
Build against L1's contract with a stub until CP1 lands.

**X4. Command at 30+ units a side.** Selection, groups, the selection panel and the HUD stay readable and fast with
30–60 units: grouped portraits with counts, per-element health, no per-unit spam. Measure input-to-order latency and
frame cost with 60 units selected. Keep a "select all combat units" and "next idle element" key.

**X5. Faction pick in skirmish (with combat's L3).** `make skirmish` takes a faction per side (flag and a simple menu);
army size follows the faction's roster and budget, not a fixed count.

**X6. Readability at close zoom.** With the camera close, nameplates, selection rings, health and order markers must
stay legible without hiding the models; far-out icons matter less now. Re-tune with screenshots at 1920×1080 and
1280×720, and at the new default zoom.

- **Stretch:** a "cinematic" camera mode that follows the fighting on its own for spectating and trailers; smart-cast
  quality of life (a mixed selection right-clicking an enemy sends only units that can hurt it).

## How to verify

`make remote T=check`; your control tests with real mouse and keyboard events; a playtest script that drives a match
with 30 a side, switching elements, with screenshots **looked at**; a short written description of what the player can
and can't see at the new default zoom, and what it costs to see more.

## Don't touch

Doctrine data and element leaders (doctrine), weapons, suppression and rosters (combat), brains (ai), audio (audio).

## Status

- 2026-09-16: brief written for round 4. Nothing started.
