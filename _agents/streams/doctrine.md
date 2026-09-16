# Stream: doctrine (elements, formations, battle drills)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 4 direction*: doctrine, suppression, factions), [../workstreams.md](../workstreams.md) (**L1 is yours and is
> CP1**), [../squad_ai_design.md](../squad_ai_design.md) and [../tank_brain.md](../tank_brain.md) (what exists today).
> You own `game/tactics/` (new), `doctrines/`, `game/ai/doctrine.gd`, `mk/tactics.mk` (new), and a new
> `_agents/doctrine.md` (your design doc).

## The lead's direction (2026-09-16)

> *"this game will get its novelty from the use of sophisticated battle drills and formations still (i.e. I'm certain
> all military formations and battle drills are on a degree of science for their effectiveness). So if we do our jobs
> right, battle formations should be a tactical advantage - the key is to figure out how to intertwine this with our UX
> and playability (and also, if the opposing computer player can easily create sophisticated formations all the time
> while the player can't or the player's units don't automatically do the same formations a computer does, it would be
> no good) … it's way too much micromanaging to get the units into a specific formation; we should generally treat the
> game as cases where we're commanding well trained battle squads who operated based on standard operating procedures
> (like the army does) where there's essentially always a formation for any given task OR there's always a central
> decision maker per cluster of vehicles that automatically determines what the formation is based on their own decision
> matrix … if a unit gets ambushed, the standard operating procedure is to face the direction of the ambush and charge
> forward."* Also: *"the intelligence of all units is crucial"*, and factions *"can definitely have different automated
> tactics"*.

## Where things stand (round 3)

`game/ai/squad.gd` has squads, formations (`Formations.offsets`) and drills (move, bound, hold, assault, break contact)
from round 2, but the player never sees them and the CPU barely uses them. Control's `Orders` (K1) is how orders reach
units; brains (`TankBrain`) execute one order at a time and handle their own micro (cover, strafing, dodging, weak
spots). `CpuCommander` assigns squad-level orders. Suppression doesn't exist yet (combat's L2 this round).

## Backlog (in order)

**X1. The element API and doctrine data (L1; CP1).** `game/tactics/`: `Element` (units + a leader), `Elements` (form,
lookup, disband), tasks (`move`, `attack`, `screen`, `support_by_fire`, `hold`), and a doctrine table loaded from
`doctrines/doctrine_<name>.json` choosing a **formation** and **movement technique** from terrain, threat, task and
composition. The leader issues per-unit orders through `Orders` (K1) so brains still obey exactly one thing.
`element.state()` and `element_changed` for the HUD. Tests: the same inputs pick the same formation; every unit gets a
slot; the leader dies and another takes over. **Announce CP1 as soon as it's green.**

**X2. Doctrine from the literature.** Research real doctrine (Army field manuals on movement formations, movement
techniques and battle drills) and encode it in `_agents/doctrine.md` with citations, then as data:
- **Formations:** column, wedge, line, echelon, herringbone, each with what it's for, its frontage, and its sectors of fire.
- **Movement techniques:** traveling, traveling overwatch, bounding overwatch, and when each applies (contact likely?).
- **Selection rules:** terrain (open, lanes, dense cover), threat, task, composition.
Each entry says *why* in one line; the player-facing reason string comes from it.

**X3. Battle drills on contact.** Triggered automatically, the way trained crews react:
- **React to contact:** return fire, take cover, report.
- **Near ambush** (close, sudden, deadly): turn into it and assault through, as the lead described.
- **Far ambush:** cover, suppress, and flank.
- **Break contact:** smoke or suppression, bound away, spread.
- **Support by fire:** one element pins, the other maneuvers.
- **Herringbone** on a halt: alternate facings, watch the flanks.
Drills need entry conditions, an abort condition, and a timeout, and they must yield instantly to a player order
(K1's response guarantee).

**X4. Why formations pay off.** With combat's L2 suppression, make the advantage measurable, not a bonus number:
mutual support, sectors of fire, armor facing, spacing versus splash, frontage and spotting. Write the measurements in
`_agents/doctrine.md` (wedge versus clump, bounding versus traveling into contact, herringbone versus parked).

**X5. Parity and the CPU.** The CPU commander assigns **tasks** to elements, exactly as the player does; everything
below is the shared library. Show it: a scripted match where both sides run doctrine, and a note on what a spectator
sees. Never give the CPU a tactic the player's elements can't run automatically.

**X6. Faction doctrines (with combat's L3).** One doctrine file per faction, differing where it matters: gangs swarm,
encircle and circle to spread damage ("a pack of hyenas"); the Law advances by bounds behind suppression; the Syndicate
kites, keeps range and repositions; the Condemned hold ground and grind. Same engine, different tables.

- **Stretch:** a doctrine editor view for the lead (read-only is fine) that shows the table and the current pick;
  first sketches for the offline tactics-discovery harness (ai owns the harness itself).

## How to verify

`make remote T=check`; unit tests for selection rules, slots and drill triggers; seeded scenario tests per drill (a
near ambush ends with the element assaulting through within N s); measured comparisons in `_agents/doctrine.md`; a
watched match (`make ai-shots` or a scripted run) whose screenshots you look at, plus a spectator's description.

## Don't touch

Brains and their micro (ai: you issue orders, they execute), the camera and HUD (control), weapons, suppression and
rosters (combat), audio (audio).

## Status

- 2026-09-16: brief written for round 4. Nothing started.
