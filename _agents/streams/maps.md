# Stream: maps (new maps by experiment: room to manoeuvre, a few chokepoints, and first an open centre where a line abreast can be ambushed from the flank)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 18 direction* (item B and
> *His pick*) and *The lead's arena verdict*, `_agents/arenas.md` (all of it: *Designing a new map: start here*, *Can
> this map host an ambush?*, *Streets are lanes*, *Why the navmesh is baked as one half plus a mirror*, the Terminus'
> baker trap), `_agents/workstreams.md` *Round 18*. You own `tools/make_arenas.py`, `tools/arena_generator.py`,
> `tools/terrain_maps.py`, `arenas/**`, `game/arena/**`, `tests/arena/**`, `tests/test_arena*.gd`, `mk/arena.mk`,
> `_agents/arenas.md`.

## The lead's direction (2026-10-04, in chat, after playing round 17; verbatim)

> *"As another work item, I think we need to have an agent get creative with some other map alternatives and ideas. We
> would basically experiment by just making creative maps and then playing them. The general feedback with the current
> set of maps is that a the navigable spaces are really low and they obstacles are sort of just making navigation hard.
> Part of the reason why we did this is for testing, but at this point the vehicles are pretty smart at moving around. I
> think the best maps will be ones where there is room for vehicles to maneuver, perhaps some chokepoints in the map,
> and opportunities to really use formations like screens and ambushes; I don't know what this means exactly relative to
> what we have, but basically with the narrow corridors that exist on all the maps currently I never get to just have
> vehicles move line abreast - which one that note, I think a generally good idea for a map would be a large open center
> that allows us to use these big formations, but then create the necessary cover such that any team using a line
> abreast formation could easily be ambushed from cover (i.e. a line abreast formation could get ambushed by another
> formation that was orthogonal)"*

**The method is his: make creative maps, then play them.** Rough and many beats polished and one. His play is the
judge. Nothing joins the rotation except on his word (C18.2).

## Where things stand

- **Every dealt map is corridors** (the six in `Arena.ROTATION`, `arenas/*.json` at `c1cb2adb`; every map 280 m square):

  | Map | Lanes | Lane width, narrowest / median / widest |
  |---|---|---|
  | yard | 7 | 26 / 28 / 30 m |
  | pit | 4 | 12 / 30 / 30 m |
  | terminus | 7 | 18 / 18 / 20 m |
  | crossing | 2 | 14 / 14 / 14 m |
  | sumps | 6 | 14 / 14 / 16 m |
  | locks | 3 | 14 / 14 / 16 m |

  A squad's default spacing is 12 m (`TacticsFormation.DEFAULT_SPACING`): four vehicles line abreast need about 36 m
  of frontage plus their hulls, a wedge of four about 24 m. **No lane on any dealt map fits a line of four at its own
  spacing; four of the six do not fit a line of two.** `arenas.md` itself says of a lane: *"frontage is limited to the
  lane width, so a column or wedge beats a line"*.
- **The tension you must carry, not resolve by guessing.** In round 9 he cut the four most open maps and kept two of
  the three least open; `centre_sees_share` predicted it, and `arenas.md` made it a design target (*"Aim below ~0.30
  … above ~0.50 the lead has already rejected it twice"*). Now he asks for a large open centre. These are not the
  same thing: the cut maps were open with nothing to do in the open (the centre saw everything, so nothing could be
  hidden and no formation mattered); what he describes is open GROUND with cover on its edges that hides a force from
  the centre until it fires. So: report `centre_sees_share` for every candidate, do not gate on it, and add the
  measure that separates the two cases (below, M2). His play decides, and his verdicts go back into `arenas.md` as
  the next version of that target.
- **Long hulls scrape containers 300–500 times a minute on every dealt layout** (yard's count, round 17, `make
  container-contacts`): the standing state of rigs in streets. Room to manoeuvre should move that number, and it is a
  measure you already have.
- **What a new map is invisible to:** `sim-baseline` and `determinism` run on `foundry` only. Ship is building a
  per-map baseline this round (C18.1); candidates are not in it until dealt.
- **The lane validators cannot see a turning pocket** (yard, round 17): a 14 cm intrusion into a 17.56 m avenue passed
  a 12.14 m bar. Yours this round (M6).
- **How layouts are made:** `tools/make_arenas.py` authors one half plus its 180° mirror; `make arenas` regenerates
  `arenas/*.json`; `make arena-report` measures; `make arena-series` plays fairness; `make arena-shots` renders
  (needs builder0's display); `tools/arena_generator.py` (`make arena-candidates`) proposes layouts toward measured
  targets and has an `open` character. `test_arena_kit.gd` holds that every layout is a fixture, CUT, or in
  `ROTATION`: add a fourth class, CANDIDATE (playable by name, never dealt, never in `random`).
- **Traps already paid for:** the navmesh baker silently ignores large boxes (tile a large footprint); the arena is
  assumed square in several places; a dealt map needs its announcer name in the same commit (`arena.gd` `ROTATION`),
  a candidate does not; an objective needs at least two approaches that differ in exposure; the deploy zone cannot
  move forward (`arenas.md`, round 10).
- **Open ground is the laptop's expensive case:** more vehicles in view at once. He plays on an Intel UHD 620 on
  purpose. Every candidate gets a frame-time read on his path before it is offered (the orchestrator runs the
  quiet-window laptop `make perf-play ARENA=<candidate>`; ask with the exact command).

## Backlog (in order)

- **M1. The candidate class, so he can play a map the day it exists.** `Arena.CANDIDATES`; `make skirmish
  ARENA=<name>` plays one; `random` never deals one; the kit test knows the class. The tactical map, the radar, the
  spawn envelope, cover tables and the fog field work on a candidate without a hand edit (run a scripted skirmish on
  the first one and read the terminal for engine errors: lesson 251).
- **M2. The measures he named, as numbers per map, before he plays it.** (a) **Room to manoeuvre:** the share of the
  drivable ground a line of four at 12 m spacing can drive through (frontage ≥ ~40 m), and the same for a wedge.
  (b) **Chokepoints:** how many, how wide, and whether each has a way round and at what detour. (c) **Ambush
  ground:** for a line crossing the centre on each plausible axis, the cover positions within weapon reach that see
  the line's FLANK (bearing within ~30° of the line's own axis) while unseen from the line's start, and how many
  hulls each hides. (d) `centre_sees_share` and the existing report, for the record. Run all four on the six dealt
  maps first: the dealt maps must score as the corridors they are, or the measure is wrong (calibrate on what he
  already told us).
- **M3. Candidate 1, the one he described: the open centre.** Wide enough for two or three squads line abreast
  (110 m or more of frontage), with cover along its edges placed so that a force crossing in line shows its flank to
  whatever waits there; the ambusher's formation sits at right angles to the line's advance. A reason to cross (the
  objective) and a slower covered way round. **This is checkpoint CP2: tell the orchestrator the green hash the day
  it is playable; it merges early so brains can measure the CPU on it and he can play it from `main`.**
- **M4. Three or four more, different in kind, not variations.** Yours to invent; some directions to beat: a wide
  valley with two chokepoints and a ridge road round them; islands of dense cover in open ground (fights jump from
  island to island; screens matter between them); one long diagonal open axis crossed by a covered trench line; a
  walled compound in the centre with open killing ground round it; an asymmetric-feeling map that is still fair by
  the mirror. Use terrain (pits, water, bridges, slopes) where it makes a chokepoint a decision. A bigger field than
  280 m is allowed if the square assumptions hold and the laptop read does.
- **M5. Play each one before he does.** `make arena-series` (fairness by swapped bases, fight shape) on every
  candidate; CPU v CPU matches watched as recordings or frames at his pose; what the formations actually did (ask
  brains, through the orchestrator, for what its open-ground measurement shows on your map). A candidate where the
  CPU never uses the open ground, or where one base wins by the mirror, is fixed or dropped before it is offered.
- **M6. The turning pocket.** The lane validator's blind spot (above): a test that fails on the 14 cm intrusion, the
  validator fixed, the dealt maps re-proved.
- **M7. The page.** One card per candidate: a top-down plot, a frame at his pose (21°, FOV 35, 49 m), M2's numbers in
  plain words, the command to play it (`make skirmish ARENA=<name>`), and KEEP / CUT / notes recorded in a `db`
  (C15.2: the page says when its `db` was last read). Rendered headless and its buttons counted before the link
  leaves your hands (lesson 252). Paired choices per slot are for assets (his standing rule); maps he plays.
- **Stretch.** A dealt-map revision: the one or two dealt maps closest to what he asked for (the Yard's lanes are
  26–30 m) opened up as candidates beside their originals. Container-contact counts on every candidate against the
  dealt maps. A generator character for "open centre, covered edges" so the next candidate is cheap.

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe). **The sim baseline and every dealt map's hash are UNMOVED by your work**
(`make container-hashes` on the dealt maps before and after: identical; a candidate has no line): pre-register it on
every commit; a move is a finding, merged alone. `make arena-test`, `make arena-report`, `make arena-series`,
`make remote T="arena-shots ARENAS=<name>"` and look at the pictures. Every number carries its commit, its machine and
its sample.

## Don't touch

`game/ai/**`, `game/tactics/**`, `tests/nav/**` (brains: if a map shows the CPU doing something wrong, send the
witness, do not tune the map round the bug unless you say so) · `game/ui/**`, `game/control/**` (picker; if the
tactical map or radar draws a candidate wrong, send it through the orchestrator) · `game/theme/fx/**` (finale) ·
`mk/core.mk`, `tests/baselines/**` (ship) · balance values in `game/units/units.gd` (C12.6) · `Arena.ROTATION` and
`Arena.DEFAULT_LAYOUT` (his word only).

## Waiting on the lead

- His play of each candidate, as it lands (the page records it). Nothing blocks you: build the next one.

## Status

_Not started. The worker keeps this section current: plan, done (with measurements), decisions, questions for the
lead, requests to other streams, known issues, what to playtest (exact commands), merge notes, and the green hash._
