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

_Worker report, 2026-09-16. **Every backlog item is done**; X4's suppression half is waiting on combat's L2
(CP2). `make remote T=check` is green on the last commit (687 passed, 0 failed, determinism and the sim
baseline unchanged), both before and after merging `main` at CP1._

### Plan (ordered)

X1 element API and doctrine data (CP1) → X2 doctrine from the literature → X3 battle drills → X5 parity and
the CPU (moved ahead of X4 because it needs no other stream) → X4 why formations pay off (partly blocked on
combat's L2 suppression, CP2) → X6 faction doctrines → stretch (doctrine view, discovery sketches).

### Done

- **X1, the element API (CP1).** `game/tactics/`: `ElementTask` (move, attack, screen, support_by_fire, hold),
  `TacticsFormation` (geometry, sectors of fire, frontage/depth/dispersion), `DoctrineTable` (the doctrine
  files, strict validation, rule selection), `ElementSituation` (the only impure step), `Drills` (triggers,
  aborts, timeouts), `ElementPlan` (the leader's decision, pure), `Element`, `Elements`.
- **X2, doctrine from the literature.** `_agents/doctrine.md`: sources, formations, movement techniques,
  selection rules, drills, and what each one is for.
- **X6, faction tables.** `doctrines/doctrine_{standard,condemned,gangs,law,syndicate}.json`.

### Decisions (and why)

1. **Movement runs in legs, not a sliding destination.** The element's formation anchor jumps one leg forward
   (45 m traveling, 34 m traveling overwatch, 22 m bounding) and only once everyone has closed up. Re-issuing
   an order resets a brain's commitment (round-3 lesson), so a sliding goal would nudge units every second.
2. **Per-unit orders, not group orders.** The leader computes its own slots (K1's group formations are
   control's automatic ones) and issues one single-unit K1 command each, so doctrine owns the geometry.
3. **A player order always wins.** A vehicle whose current order id is not the one the element issued is
   detached until that order finishes; then the element takes it back. No new contract needed.
4. **Facing comes from travelling.** K1 carries no facing, so halt formations send each vehicle a few metres
   out along its sector: it arrives pointing the right way (request to control below).
5. **The herringbone is a halted column's security**: lead watches ahead, middles turn out to alternate
   flanks, tail watches the rear. What makes it a herringbone is that the hulls physically turn out.

### Measured (all in _agents/doctrine.md "Measurements"; raw values in build/tactics/measurements.json)

- **Wedge at 14 m into two dug-in guns:** 0.75 of the element left, first hit at 3.6 s — against 0.63 (line),
  0.57 (column), and 0.67 for the same wedge bunched to 3 m, which hurt nothing for 7.4 s.
- **Herringbone at a halt, jumped from the flank:** 0.93 left, against 0.69 for the same element parked in
  the column it drove in.
- **Bounding overwatch, re-measured with CP2 merged: 0.51 → 0.60** against 0.75 for traveling (which did not
  move). A third of the gap closed on *incidental* near-miss suppression alone; the rest waits on a brain
  option that fires at ground, since nothing is ever deliberately suppressed (combat measures 0.03 mean).
  The drills themselves are unchanged by suppression — all five still pass, same numbers.
- **Dispersion versus splash shows nothing yet** (0.91 spread, 0.93 bunched, against artillery).
- **Drills:** ambushed at 25 m → through the ambush 6.3 s later, both ambushers dead, no losses; far ambush →
  base of fire 4.6 m off the line of contact while the other half swings 24.3 m round; bounding keeps a
  section set 38% of samples; an outgunned pair breaks contact from 76 m to 106 m.

### New since the lead's steer (2026-09-16): doctrine publishes, the booth talks

The lead asked for a hybrid of "keep the doctrine page as a dev tool" and "explain elements in game", with the
explaining done **by the announcer rather than the HUD**: *"we can use that information to generate scripted
statements from the announcers about how a squad is lining up in whatever formation for whatever reason.
Presumably we at least want the structured data publishable."* The plumbing is in:

- `Elements.element_reported(event)` publishes every decision as a **K5-shaped event** — `element_formation`
  (shape or technique changed, first task taken, drill ended) and `element_drill` (a drill started, with the
  distance and what set it off). Both carry the doctrine table's own `reason`, so the booth quotes the
  element's logic rather than inventing one. Full field list in _agents/doctrine.md *Publishing decisions*.
- `game/tactics/element_report.gd` decides what is worth saying: no task = nothing to say, a reason changing
  on its own is not a call, a leader change is the HUD's business, the same call is not repeated within 10 s,
  and `element_drill` always means a drill *started*. That filtering is deliberately on the producing side —
  an announcer repeating itself is the lead's own complaint about the PA.
- `make tactics-parity` writes a real timeline to `build/tactics/element_events.jsonl` (36 events from a 45 s
  five-element match), so audio can write lines against a timeline instead of a guess.
- Five tests in `tests/test_tactics_reports.gd`, including one that fails if doctrine ever starts writing
  sentences instead of values.

**Done by audio (2026-09-16):** both types are in the K5 validators, and `MatchEventAdapter` connects and
stamps `tick`/`t`. It finds the publisher by the `elements` group (it can't name the class before CP1
merges), so `Elements` joins that group on `_ready`. Two constraints came back that shape what is worth
putting in an event: the booth **records every word in advance**, so only the enumerated fields can be
spoken (`reason` is subtitle-only), and **matches are always between different factions** — nothing in the
tables assumed otherwise, but the parity fixture uses two Condemned armies and is a doctrine isolation, not
a matchup. The value sets a shipped table can emit are **frozen** at audio's request (8 formations, 3 techniques, 8
drills): `test_every_value_the_booth_has_to_speak_is_from_a_closed_set` asserts them exactly and fails the
build with the reason, because an unrecorded value degrades silently rather than erroring. **Adding a shape
or a drill to a shipped table now needs audio's sign-off**, and the frozen list changes in the same commit as
the table. The correction was worth real money: they had 6/3/6 from the round-4 brief and would have recorded
`encircle`, `ring` and `echelon_left` — 24 clips for shapes nothing selects — while missing `vee`, `coil`,
`swarm` and `bait`, which would have left the gangs mute.

**Originally needed from audio (two small things, both in their paths):** add `element_formation` and `element_drill` to
`AnnouncerEvents.REQUIRED` (and the Python twin in `tools/announcer/events.py`), and have
`MatchEventAdapter` connect to `Elements.element_reported` and stamp `tick`/`t` the way it already does. Then
it's line-writing. **Proposed contract wording** for workstreams.md, as an extension of L1: *"L1 also
publishes element decisions as K5 events on `Elements.element_reported(event)`: `element_formation`
{team, element, size, formation, technique, reason, changed[]} and `element_drill` {team, element, size,
drill, formation, reason, distance, target}. Doctrine rate-limits and filters; audio adds the types to the
K5 validator and writes the lines."*

### The lead's faction feedback (2026-09-16), answered

*"All of the standard operating procedures for all the factions look quite similar ... the street gangs ...
should be noticeably less military disciplined ... spreading out their formations wide ... or do circular
swarms ... I don't know if your doctrines are accounting for how to manage formations with multiple vehicles
(i.e. heavy armor on the outside of a column, light armor on the inside) ... the street gang would also be
more likely to create tactics of having a vehicle draw fire to try and lead the opponents into an ambush."*

He was right on all three counts. The tables differed only in numbers, and the shapes all came from the same
eight military formations. What changed (full numbers in _agents/doctrine.md *Faction doctrines*):

1. **Placement by armour, every faction.** Each slot is scored for exposure (how far out of the middle, how
   far toward the front) and the best-protected vehicle takes the worst place. Artillery and Lancers go
   inboard whatever their armour says — a gun being shot at is not shooting.
2. **A `swarm` shape for the gangs**: wide, ragged, staggered, nearly twice a line's frontage. Kept: it is
   the character the lead asked for and costs no damage. It does survive worse than military shapes today
   (0.47 vs 0.62), for the same reason dispersion shows nothing elsewhere — splash and suppression don't yet
   punish bunching. Re-measure when they do; if it still loses, it goes.
3. **A `bait` drill**: the fastest non-leader draws and leads them back over the pack. Kept — 0.58 of the
   pack alive against 0.43 without it (one seed). Its first version baited *dug-in guns*, which is suicide:
   a lure needs something that will follow, so it now requires a contact that is actually moving and gives up
   if it doesn't close.
4. **An `encircle` drill: built, measured, switched off.** Same units, same enemy, same seed: turning it off
   left survival unchanged (0.47) and took enemy survival from 0.66 to 0.19 — circling stops the pack
   shooting, and the coverage it was meant to buy was already there (a standard element covers the same seven
   arcs by fighting). The drill stays in the engine behind its flag with the numbers recorded; no shipped
   table selects it. Same lesson as bounding overwatch: a drill earns its place by deciding where an element
   goes and what it points at, not by driving vehicles that already fight well.
5. **The doctrine page now says what each faction does differently** from standard doctrine, in words, so the
   character reads without diffing five tables. The page's mirrored constants are checked against the
   GDScript at build time, so it can't quietly start lying.

### Standing arrangement with audio

Measured facts are the Veteran's material: doctrine sends anything surprising, **marked stable or
likely-to-move**, and only stable ones get recorded (a recorded line outlives the number that justified it).
The split is in _agents/doctrine.md *Which of these the booth can quote*. Today: the coverage, first-hit and
herringbone numbers are stable; everything resting on suppression or splash is not, and nothing depending on
them should be voiced until combat's L2 is finished. If a measurement ever means "the booth should always say
this", ask audio for a tag priority rather than more lines.

### Questions for the lead

1. **Should an element's shape be visible on the HUD, or only its reason?** Every element carries a
   plain-language line ("contact likely: bound forward, one element always overwatching the other"). My
   recommendation: show the reason, keep the jargon in the selection panel.
2. **Read-only doctrine view:** `make doctrine-page` → `build/doctrine/index.html` shows every table, its
   rules, its drill numbers and a picture of each formation with its sectors of fire. Worth growing into a
   "why did my element do that" page, or throwaway?

### Requests to other streams

- **combat (L2, CP2):** two measured gaps. (a) Splash does not punish bunching: 0.91 survival spread out
  versus 0.93 at 3 m spacing against artillery. If dispersion is meant to be a real trade, splash or
  suppression has to bite at `closest_pair_m` scale (4 m versus 19 m here). (b) Bounding overwatch currently
  loses (0.51 versus 0.74): it only pays when the overwatch element's fire degrades the enemy. Both get
  re-measured the day L2 lands — `make tactics-measure` is the harness.
- **ai:** `ElementCommander.install(game_match, team)` is a drop-in element-level commander that only ever
  assigns tasks. If the CPU commander moves onto elements, brains keep executing exactly one K1 order each and
  nothing else changes. Happy for ai to own the policy; doctrine owns what happens below the task.
- **control:** (a) K1 has no facing, so halt formations make each vehicle drive a few metres along its sector
  to end up pointing the right way; an optional `facing` in `UnitCommand` would remove that hack. (b) For the
  HUD: `Elements.of_match(match)`, `elements.of(unit)`, `element.state()` (formation, technique, drill,
  reason, slots, sectors, detached) and signal `elements.element_changed(id)`. (c) The player's own orders
  always win: an element stops commanding any unit whose current order id is not the one it issued, and takes
  it back when that order finishes.

### Known issues

- Elements are **not wired into the real game yet** (skirmish, the CPU commander and the HUD belong to other
  streams). `make tactics-parity`, `make tactics-drills` and `make tactics-shots` are how to see them until
  ai and control adopt them.
- An artillery element under threat spends most of a match in break contact (correct, but it never gets to
  fire). Worth a rule of its own for support elements: displace, then set up again.
- Terrain is judged by counting cover features within 45 m; it does not understand lanes or walls as shapes.

### What to playtest (exact commands)

```bash
make tactics-parity SECONDS=60       # both sides run doctrine; read the transcript
make tactics-drills                  # the five battle drills, seeded
make tactics-measure                 # what each shape and technique is worth
make remote T=tactics-shots          # pictures: wedge advance, bounding, near ambush, herringbone, parity
make doctrine-page                   # build/doctrine/index.html: every table, with the shapes drawn
```

### Merge notes (shared files)

- **Known conflict, `tests/test_match_spawns_and_results.gd`:** combat rewrote the same fixture in d916dc2
  (`test_a_full_faction_army_a_side_spawns_clear_of_itself`, deriving from `Army.MAX_ARMY_UNITS` = 45, and the
  front-row test from `Match.SLOT_X.size()`). **Take combat's version** — it is the same fix by a better
  constant — and keep the invariant they named: `Army.MAX_ARMY_UNITS <= Doctrine.MAX_UNITS` (45 <= 52 with
  their spawn grid). Mine only exists because my branch has to be green before theirs merges.
- `tests/test_match_spawns_and_results.gd`: the full-army fixture and its assertion now come from
  `Doctrine.MAX_UNITS` instead of a typed-in 50, so the test follows the caps (it was `5 x 5 = 50`, which the
  squad-cap change would have broken, and combat's 52-slot grid would have broken again). The method is now
  `test_a_full_army_a_side_spawns_clear_of_itself`.
- `tests/test_army.gd`: one line — the army-JSON sweep skips `doctrine_*.json`, which are doctrine TABLES
  (contract L1), a different schema in the same folder. `tests/test_tactics_doctrine.gd` validates those.
- `Makefile`: one word — `doctrine-page` joins `LIGHT_GOALS` (it is a one-second Python script and should not
  take a machine-wide heavy-run slot).
- New paths: `game/tactics/`, `doctrines/doctrine_*.json`, `mk/tactics.mk` (picked up by the root Makefile's
  `mk/*.mk` include, no Makefile edit), `tests/tactics/`, `tests/test_tactics_*.gd`, `_agents/doctrine.md`,
  and `tools/tactics/` (proposed ownership: doctrine).
- The sim baseline is untouched: nothing installs Elements in the shipped modes yet.

### After CP2 (combat's suppression landed on stream/combat, 2026-09-16)

Combat reports L2 measured and biting — a pinned tank hits 5 of 13 shells where a calm one hits 13 of 13 —
but **mean suppression per living unit across 16 matches is 0.03 and nothing is ever pinned**, because no unit
fires at ground it wants denied. The plan, with the API names, is in _agents/doctrine.md *Next: what
suppression changes*. Short version: a base of fire needs a brain-level "keep firing into that lane" option
(ai's, requested by combat); doctrine then decides where it points, triggers drills off `Tank.is_pinned()`,
routes the far-ambush flank around `Match.is_beaten_zone(team, from, to)`, and re-runs `make tactics-measure`.

**Done for combat (their X3 request):** `Doctrine.MAX_SQUADS` is 12, not 5 — a faction army at the baseline
budget is ~28 vehicles and does not fit in five squads of five, and `Match.load_doctrine` never cared. The
lead's "say 5" is now `Doctrine.PLAYER_MAX_SQUADS`, which is what the garage offers (`army_catalog.gd` already
takes the smaller of its own cap and this file's, so the builder is unchanged). `MAX_UNITS` is now
`Match.SPAWN_SLOTS` — as many units as the arena has places to put them — so it follows combat's spawn grid
from 27 to 52 without another edit here. `Army.parse_scaled` can go.

### Next steps

1. ~~Re-measure bounding the day CP2 merges~~ **done 2026-09-16: 0.51 → 0.60.** Re-measure again when brains
   can fire at ground; dispersion against splash still shows nothing and wants the same option.
2. A support-element doctrine rule (displace and set up, instead of breaking contact).
3. Faction tables want a real roster to sit on (combat's L3): today every unit is `condemned`, so
   `Elements._table_for` always loads the Condemned table in a real match.

### Proposed edits to workstreams.md (orchestrator's call)

- **L1, as built:** `element_changed(id)` and `leader_lost(id, fallen, successor)` are signals on **`Elements`**
  (the per-match registry the HUD holds), not on each `Element`; `Elements.install(match, orders)` /
  `Elements.of_match(match)` reach it. `element.state()` returns the contract's fields plus `sectors`,
  `detached`, `leader`, `members`, `task`. Tasks are exactly `{"verb", "to"?, "target"?}` — a task may not name
  a formation (the leader decides; `ElementTask.validate` rejects it).
- **Ownership:** add `tools/tactics/` (the read-only doctrine page) to doctrine's paths.
- **Note for the table:** `doctrines/` now holds two schemas — armies (C2) and doctrine tables (L1,
  `doctrine_*.json`). Anything that sweeps that folder must filter (two tests did; both fixed).
