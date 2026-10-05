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

_Updated 2026-10-04 23:1x PDT by the maps worker (times below are read from the run logs). Launch tree `cbda2c6a` checked green on builder0 (14:43–15:13 PDT:
`>> remote: make check exited 0`, 23 targets ALL JUDGED, 2002 passed 0 failed, sim-baseline `05df1d55ba49cde1` unmoved,
determinism `762a0576f944f5b7`)._

### Report (the worker's summary; detail in the sections below)

**Every backlog item is done or waiting on his play.** Page v3 is up (brains' fix main-checked at `b3586415`, merged here). M1 the CANDIDATE class; M2 `make arena-room` (room for a line /
wedge of four, chokepoints with their way round, flank-ambush ground, centre view), calibrated so the corridor maps
read as corridors; M3 the Parade Ground (CP2, on `main` since `23941d90`; v3 bays after picker's seating read); M4 the
Gorge, the Archipelago, the Cut, the Docks; M5 every candidate fair by swapped bases, played CPU v CPU (the CPU crosses
on all of them), frames and windowed smokes with 0 engine lines, contacts 26–215 a minute against the yard's 794,
brains' tasked-squad witness (4/4 in ~14 s on the Parade Ground vs never on the Sumps before its fix); M6 the tooth rule;
M7 the page, v2 live. Stretch: the Container Yard opened up (`yard_open`), contact counts, generator character
`open_centre`. **Waiting on the lead**: played KEEP / CUT (six Keeps in twelve seconds are on record; see Questions).

**Merge notes.** Paths outside the brief's list that this stream changed, all arena tooling nobody else owns this
round: `tools/arena_report.py` (reads `Arena.CANDIDATES`; asserts a candidate's lanes), `tools/arena_series.py`
(reports `crossed_share` / `open_share`), `tools/container_contacts.py` (one-arm summary), `tests/arena/arena_probe.gd`
(the two readings; listens only). New files: `tools/arena_room.py`, `tools/test_arena_room.py`,
`tools/candidate_maps.py`, `tools/candidate_page.py`. `game/arena/arena.gd`: `CANDIDATES`, `is_candidate`,
`lanes_asserted` (additive). No dealt layout, `ROTATION` or `DEFAULT_LAYOUT` changed; every per-map line unmoved.

**Lesson worth keeping (proposed for orchestration.md):** a copy-back MIRRORS builder0's `build/`, so a frame from an
earlier version of a map (the Parade Ground's ladder) survives beside the new ones by file name and a page that globs
by name shows the old map. Read a run's own manifest (`<map>_after.json`), never a directory listing.

### Plan (in order; smallest foundation first)

1. **M1** the CANDIDATE class — built. Arena tests green at `1c5f5786` (builder0, 16:14 PDT: `make test FILTER=arena`
   exited 0, 142 passed, 0 failed); full check green at `b6d817f9` (below). Windowed-skirmish smoke per candidate:
   running (container-frames).
2. **M2** the measures — built (`tools/arena_room.py`, `make arena-room`), calibrated on all ten kit maps.
3. **M3** candidate 1, the Parade Ground — built. **CP2 announced to the orchestrator 16:55 PDT: merge `b6d817f9`.**
4. **M6** the turning pocket — built early (cheap, and candidate 1 had to pass it).
5. **M4** three or four more candidates, different in kind — four built: the Gorge, the Archipelago, the Cut, the Docks.
   Stretch: the Container Yard opened up (`yard_open`) and a generator character `open_centre` — built.
6. **M5** every candidate played by the CPU (`arena-series`, frames at his pose, container contacts) before he sees it.
7. **M7** the page (one card per candidate, KEEP / CUT / notes in a `db`) — generator built
   (`tools/candidate_page.py`); waiting on frames.
8. Stretch: an opened-up yard beside the original; contact counts; an "open centre, covered edges" generator character.

### Decisions (one line each)

- **A candidate is a layout flagged `"fixture": true` AND named in `Arena.CANDIDATES`.** The flag gives every
  never-offer consumer (the booth's name test, `shipping_layout_names()`, the census, the picker) the right answer
  for free with no edit outside my paths; the list is what separates a candidate from an instrument and holds its
  lanes to R4 (`Arena.lanes_asserted`). Ship reads `Arena.CANDIDATES` by that name and shape (flat Array of layout
  names) — keep it so (orchestrator, 14:57 PDT).
- **Room counts a formation that can ADVANCE its own frontage (36 m)**, not one spacing: with 12 m of travel the
  yard read 38 % room (a line standing lengthwise in a 28 m lane shuffling sideways). Frontages are read from
  `TacticsFormation` (line of four: 36 m of hull centres + 1 m margin each side = 38 m drivable ≈ 42 m physical;
  wedge of four: 34.4 m, 24 m deep).
- **A chokepoint is a narrow stretch (< a line's frontage) no longer than 30 m with 15 m of open ground on both
  sides**; longer or between narrow ground it is CORRIDOR (reported as a share of the routes). Routes = base to
  base, base to each objective, and every declared lane driven as declared.
- **Ambush ground** (the measure that separates his request from the maps he cut): a line of four crossing the centre
  on 4 axes, 5 stations each (it must stand AND advance 36 m there); cells off the line's END (±30° of its own
  axis), within posted reach of its nearest hull, seeing ≥ 2 of its hulls, unseen from all of its hulls 50 m back.
  Capacity = hulls standing 8 m apart.
- **The Parade Ground's depots were swept, not guessed** (decision spread): (−45, 62) on the base approach 1.00
  (one free, one impossible); (−50, 20), at the mouth of each side's own ladder, **0.36** (his kept maps: 0.43 /
  0.42).
- **M6's tooth rule asserts on candidates only; the dealt maps are reported.** Fixing a dealt layout moves its sim
  hash, which C18.1 reserves for a commit merged alone on his word.

### M2 — the measures on the maps he has played (laptop, `tools/arena_room.py` at `aa928581`, static geometry)

| map | line of 4 room | wedge of 4 room | widest frontage | corridor share of routes | flank-ambush hulls, base-to-base line | centre sees |
|---|---|---|---|---|---|---|
| yard | 0.06 | 0.07 | 42 m (4 abreast) | 0.53 | 0 (cannot cross) | 0.20 |
| terminus | 0.05 | 0.05 | 47 m | 0.60 | 0 | 0.13 |
| crossing | 0.09 | 0.10 | 51 m | 0.60 | 0 | — |
| sumps | 0.25 | 0.26 | 62 m | 0.38 | 0 | 0.34 |
| locks | 0.41 | 0.43 | 76 m | 0.39 | 0 | 0.45 |
| pit | 0.37 | 0.43 | 88 m | 0.26 | 0 | 0.30 |
| *foundry (cut)* | *0.83* | *0.86* | *192 m* | *0.00* | *27* | *0.56* |
| *boulevard (cut)* | *0.25* | *0.28* | *88 m* | *0.07* | *0* | *0.64* |
| **parade (candidate 1)** | **0.49** | **0.51** | **198 m (17 abreast)** | 0.20 | **17** (best position 3; diagonals 12 / 12) | **0.80** |

Read: the corridor maps score as he described them (a line of four fits nowhere on yard, the Terminus or the Crossing,
and no line can cross any dealt map's centre). The Parade Ground is open AND has hidden flank ground for a line
crossing it; its centre sees 0.80 — far above the old < 0.30 target, by design (*the tension* in this brief). His play
decides; his verdict goes into `arenas.md` as the next version of that target. Centre-sees figures for yard/terminus/
sumps/locks/pit/boulevard/foundry are `arenas.md`'s recorded values; the Parade Ground's is `arena_report` at `aa928581`.

### M6 — the turning pocket

`ArenaLanes.teeth()`: along each lane kerb, a collider corner standing more than 10 cm past its kerb on both sides
within half the k-turn outline's widest side gap (READ: `Movement.KTURN_OUTLINE` samples a hull's side at quarter
lengths, so 7 m for the 14 m rig), the smaller rise under the bake radius. The test builds the round-17 case (a 20 ft
box flush to a kerb, square: no tooth; turned 2.75° so its corner takes 14 cm: one tooth, and the width bar still
passes it). Candidates asserted; dealt maps print `TOOTH_COUNT` (Python prototype: Terminus 4 — the block corners on the
two diagonal plaza crossings; Sumps 2 — west causeway; the rest 0; GDScript numbers to follow from the check log).

### M4 — the candidates (laptop, `tools/arena_room.py` and `arena_report.py` at `1c5f5786`; static geometry)

| map | what it is | line of 4 room | widest | necks (drivable width, way round) | flank-ambush hulls (best axis) | centre sees | objective spread |
|---|---|---|---|---|---|---|---|
| **parade** | open floor 120 m wide between two ladders of container walls; a covered way round behind each ladder past a neck | 0.54 | 17 abreast | way round reads as corridor (0.20 of routes) | 17 base to base (best 3) | 0.80 | 0.36 |
| **gorge** | two bands of pits across the field, two 16 m causeways (the necks) into a wide valley, a straight road round the ends | 0.36 | 8 abreast | 9.5 m × 18 m necks; road round ×2.2–2.9 | 11 on a diagonal; 8 base to base | 0.73 | 0.28 |
| **archipelago** | seven islands of stacked containers in open ground; the forward islands are the objectives | 0.77 | 14 abreast | 4 minor, all with a way round ×1.0–1.08 | 11 (side to side / diagonal) | 0.43 | 0.45 |
| **cut** | city blocks in two opposite corners; an open band corner to corner crossed by a concrete trench (straight `wall`s: turned containers would put teeth along it) | 0.53 | 10 abreast | none | 12 on the band's diagonal; 0 base to base (the trench is in the way) | 0.62 | 0.45 |

Every candidate: lanes pass R4, no tooth (M6), objectives swept to a spread near his kept maps' 0.4, an
authoring-time placement check (the first Parade Ground stood a wall 3.9 m from the slanted hexagon wall, inside
`Arena.PLACEMENT_CLEARANCE`, and reddened 13 arena tests at `aa928581`; `candidate_maps.check_placement` now refuses it).

### M3 revised: the Parade Ground v3, from picker's seating read (`9475c06d`)

Picker measured the game's own seating on parade v1 (orchestrator relay, ~17:50 PDT): at the open centre every
formation "fits here" (Line included: the first map he can play where a line of four seats at its spacing); in a ladder
gap (21 m) only a Column fits. So an ambusher could not stand abreast at right angles to a crossing line, which is what
he described. v2 (a ladder 46 m apart) seated a line but laid its gaps open to the line's start (hidden hulls 17 → 6).
**v3: one BAY a side**, rungs at z = ±23 running in to x = ±56, 44 m apart inside: a line of four seats in the bay
facing the floor; the floor is 112 m wide (21 abreast); a line crossing base to base can be shot down its length by 19
hidden hulls, best spot 6 (v1: 17, best 3); depots re-swept to (−36, 24), spread 0.48; lanes R4, no teeth. Asked
picker (via the orchestrator) to re-read the seating at `bay:-80,0,90`.

### M5 — the CPU plays them (builder0)

**Fairness, swapped bases** (`make arena-series`, Condemned v Condemned, 5200, elimination + control, 180 s, 8 seeds × 2;
tree `adfe794b` + docs, run 17:2x–18:07:46 PDT; parade is **v1, the ladder**):

| map | south advantage (± SE) | winner flips | first hit | median / p90 hit range | flank share | hidden share | length |
|---|---|---|---|---|---|---|---|
| parade v1 | +0.004 ± 0.021 | 0 | 7.3 s | 27 / 67 m | 0.20 | 0.44 | 114 s |
| gorge | −0.027 ± 0.026 | 0 | 5.8 s | 30 / 68 m | 0.34 | 0.41 | 129 s |
| archipelago | +0.078 ± 0.058 | 1 | 5.2 s | 27 / 64 m | 0.42 | 0.42 | 117 s |
| cut | +0.062 ± 0.058 | 0 | 7.4 s | 27 / 56 m | 0.38 | 0.47 | 125 s |
| docks | −0.103 ± 0.071 | 1 | 6.7 s | 26 / 62 m | 0.36 | 0.52 | 123 s |

All within two standard errors of fair on 8 pairs; the Docks is the widest (1.45 SE) and is re-run with the next series.
**What the series could not say: whether a CPU element crossed the open ground** (brains' D1–D4: a mixed squad on the
CPU's drills halts after one leg; lines close up in transit; guns forward on the move). `tests/arena/arena_probe.gd` now
records `crossed_share` (vehicles ever 20 m past the centre line toward the enemy) and `open_share` (unit-seconds on the
layout's declared open ground); the next series (all six, parade v3, on the merged tree) carries them as the before for
brains' fixes. Not tuning any map round D1–D4.

**Frames at his pose** (`make container-frames`, a real windowed skirmish per map, builder0, finished 17:04:29 PDT):
4 frames per candidate, looked at; **0 engine error or warning lines in any of the five logs** (M1's smoke). The
orchestrator separately ran a scripted skirmish on parade to tick 600 on the merged tree: 0 engine lines; ship's
`candidates-smoke` loaded and played all four listed at that time.

**Dealt maps' container hashes** (`tools/remote.sh container-hashes`, tree `adfe794b`, finished 16:54:20 PDT, builder0,
SIM_HASH_READ's match, 1200 ticks): yard `797dc49109a452d8`, pit `098f7d5cb3795e7f`, terminus `8b0309ee85e497dc`,
crossing `efc8449e97b18eb1`, sumps `bf0bdb98568700db`, locks `db5512352146803e`, foundry `05df1d55ba49cde1` (= the sim
baseline). Identical to ship's per-map lines: UNMOVED, as pre-registered.

**Series 2** (`make arena-series`, all six, **CPU brains alone on both sides**: the match runner never runs elements;
Condemned v Condemned, 5200, elimination + control, 180 s, 8 seeds × swapped bases; tree `0901ab64`, builder0, finished
20:30:16 PDT; the new `crossed_share` / `open_share` readings):

| map | south advantage (± SE) | flips | CPU vehicles that got 20 m past the centre | time on declared open ground | median / p90 hit range | length |
|---|---|---|---|---|---|---|
| parade **v3** | +0.011 ± 0.030 | 0 | 0.31 | 0.41 | 26 / 72 m | 120 s |
| gorge | −0.027 ± 0.026 | 0 | 0.36 | 0.13 | 30 / 68 m | 129 s |
| archipelago | +0.078 ± 0.058 | 1 | 0.37 | 0.07 | 27 / 64 m | 117 s |
| cut | +0.062 ± 0.058 | 0 | 0.39 | 0.25 | 27 / 56 m | 125 s |
| docks | −0.103 ± 0.071 | 1 | 0.35 | 0.12 | 26 / 62 m | 123 s |
| yard_open | +0.012 ± 0.065 | 0 | 0.35 | 0.12 | 25 / 55 m | 130 s |

All fair within 2 SE on 8 pairs. The four maps that did not change reproduced series 1 exactly (same seeds; the sim is
deterministic), so the Docks' −0.10 needs NEW seeds: seeds 9–24 queued. The CPU does cross on every candidate (a third
of its vehicles get 20 m past the centre line); `open_share` is the share of time inside each map's declared
`open_ground` region, so it compares a map with itself across brains' fixes, not maps with each other.

**The Docks on new seeds** (seeds 9–24, 16 pairs, same setup, builder0, finished 21:45:45 PDT): south advantage
+0.027 ± 0.026, 0 winner flips; over all 24 pairs about −0.02. Every candidate is fair.

**A squad on a task, 150 m** (brains' lane-deadlock witness, relayed 22:0x PDT; its commit `f4daada0` = the D4+D5 fix on
`f6c6a282`, NOT on main yet; laptop; four Law tanks / a Law IFV mix, attack-move 150 m forward from the green spawn,
seeds 1–4, 180 s; arrived of 4, median s, re-seats): parade 4/4 14.1 s, 0 · yard_open 4/4 13.8, 0 · archipelago 4/4
15.3, 0 · docks 4/4 21.1, 0 · gorge 4/4 35.0, 5 · cut **3/4** 46.1, 25 · the Sumps (dealt) 4/4 39.8, 5 (before the fix
0 of 8). **The Cut's stall at (−4.1, 44.9) is not a neck** (`arena_room`: 111.5 m of drivable width E–W, 133.5 m N–S;
the south-east block's west face 6.1 m away, the nearest trench wall 24 m): brains' re-seat thrash beside a wall
(its D5 limit), so no wall moves. The page carries this line (`--with-witness`) once the fix is on main.

**Long hulls scraping containers** (`tools/remote.sh container-contacts CC_TURNED_ONLY=1 CC_SEEDS=4`, Gangs' War Rigs v the
Condemned, elimination, 180 s cap; tree synced 18:07:48 PDT = parade **v3**; builder0; median per minute of fight over
4 seeds, `long_container`): **yard 794** (the dealt map, same run) · parade v3 215 · docks 184 · archipelago 102 ·
gorge 72 · cut 26. Room to manoeuvre moves the number as the brief expected: 3.7× to 30× fewer than the yard. The
all-contact counts (any collider, every hull) are higher on the Gorge (4,121/min) and the Docks (3,271) than on the yard
(3,538) or the Parade Ground (1,303); pit rims and bridge rails are colliders, so a reading of WHAT they hit is the next
step, not a conclusion here.

**The merged tree is green** (`0901ab64` = `3b4f6502` merge of `main` `23941d90` + Status): builder0 18:35:52–19:22:39 PDT,
`>> remote: make check exited 0`, 23 targets ALL JUDGED, 2016 passed 0 failed, all seven per-map lines unmoved (foundry
`05df1d55ba49cde1`, yard `797dc49109a452d8`, pit `098f7d5cb3795e7f`, terminus `8b0309ee85e497dc`, crossing
`efc8449e97b18eb1`, sumps `bf0bdb98568700db`, locks `db5512352146803e`), determinism `762a0576f944f5b7`. Ship's
`candidates-smoke` on it (19:27:10 PDT): **6 candidate maps loaded and played: parade gorge archipelago cut docks
yard_open**, exited 0. Frames of parade v3 and yard_open: 0 engine error lines, looked at.

### Known issues

- **`arena_room`'s ROOM share uses a centred travel window**, so ground within 18 m of a wall or pit rim never
  counts even where a line could stand; it reads conservatively (the Gorge's valley: 0.36). Stated in the tool.
- **Every candidate's centre sees far more than 0.30** (0.43–0.80): open ground is what he asked for. Whether the
  target moves is his play's answer, not mine.
- **The dealt maps have teeth** (GDScript, builder0, `1c5f5786`): Terminus 4 (block corners on the two diagonal plaza
  crossings), Sumps 2 (west causeway), yard 12 and pit 6 (report-only maps; yard's lanes are AI hints through cover);
  Crossing and Locks 0. Not fixed: a dealt layout change moves its hash (C18.1). For the orchestrator and brains:
  whether these matter is the contact count's question.

### Requests to other streams

- **brains** (via the orchestrator, 20:3x PDT): the lane deadlock it found on the Sumps (a squad on a task squeezed into
  file, crossed seats, 0 of 8 arrive in 180 s): run the same witness on the six candidates beside the Sumps. That is
  the number that says what room to manoeuvre buys him; `arena_probe` cannot see it (the match runner runs no elements).

- **brains** (via the orchestrator, 16:55 PDT): the CPU in open ground measured on `parade` — what the formations
  actually did (did a line form; were the ladders used to ambush).
- **orchestrator**: the quiet-window laptop read, `make perf-play ARENA=parade`.
- **ship**: `Arena.CANDIDATES` grows by `docks` and `yard_open` after `b6d817f9`; same shape.
- **picker** (via the orchestrator, ~18:00 PDT): the seating read on parade v3's bay, `PICKER_SPOTS=bay:-80,0,90`.

### Questions for the lead

- **Did you get to play the new maps, or were those six Keeps a first look?** If you played them: which do you want
  in your random rotation, and should the opened Container Yard replace the one you have or join it? (Recommendation:
  play the Parade Ground first, `make skirmish ARENA=parade`: it is the one you described.)
- When one is dealt: its spoken name is recorded first (paid voice, your approval of the text), then it joins the
  rotation in the same commit.

### The page (M7)

**https://claude.ai/artifact/WenjeeygUULXj5RTSmjXzb** (private to his account; published 20:31 PDT; generator
`tools/candidate_page.py`). Rendered headless before the link left my hands: 6 cards, 12 buttons, 18 verdict choices,
6 note boxes, 29 images. Store: `verdicts/<map>` {verdict KEEP | CUT | AGAIN, notes, at, by}; `meta/read` {read_at},
shown on the page (C15.2). Checked: `verdicts` empty; a write at the `interact` level succeeds (probe written, deleted).
Handed to the orchestrator for its own render and count (lesson 252) before he gets the link; it passed (6 cards, 12
buttons, 18 choices, 6 note boxes, 29 images; `node --check` on its script) and the link went to him.
**Version 2** (~23:0x PDT, same URL): each card leads with a frame of a real match under way from his camera
(`make arena-shots`, 40 s in), the duplicate hidden-vehicle number is gone, one line per card on how the computer played
it (series 2), the Parade Ground's card carries picker's seating read, scrapes a minute against the yard's 794. Render:
6 cards, 12 buttons, 18 choices, 6 note boxes, 29 images. Brains' 150 m squad line is built behind `--with-witness`
until its fix is on main.
**Version 3** (2026-10-05 ~00:4x PDT, same URL; built on `6139f240` = merge of `main-checked` `b3586415`, which carries
brains' "his squads on a task arrive"): brains' 150 m line on every card in his terms with its caveat (4 laptop runs;
the Sumps about 40 s after the fix, never before it; the Cut's one stall said to be a driving fault beside a block
wall, not a narrow place); each card shows its saved state ("Saved: Keep, <time>. Change it any time."); the top line
reads `meta/read` ("Six Keeps were recorded at 20:33 … treating them as a first look until you say you have played
the maps"). Render: 6 cards, 12 buttons, 18 choices, 6 note boxes, 29 images; `node --check` passes. Handed to the
orchestrator for its render. Verdicts re-read then: unchanged.
**His answers, read 23:05 PDT** (`meta/read` updated on the page): KEEP on all six, no notes, tapped 20:32:52–20:33:04
PDT — twelve seconds for six, about two minutes after v1 went up. Not treated as played verdicts; nothing dealt
(ROTATION is his word only). The question is with the orchestrator, below.
**Reading his answers**: `ArtifactData list verdicts` on that URL, then set `meta/read.read_at` to the time read.

### What to playtest

- On `main` (all six are there since `c797dd06`): `make skirmish ARENA=parade`, then `gorge`, `archipelago`, `cut`,
  `docks`, `yard_open`. Each card on the page has its command and a Keep / Cut / Play it again.

### Green hash

- Launch tree `cbda2c6a`: green (above).
- Merged `main` `23941d90` into the branch at `3b4f6502`, and `main-checked` `f6c6a282` at `58352c14` (after series 2
  finished: C18.5), both clean.
- **`a062b052` is green, the last checked commit** (builder0, 23:05:52–23:39:42 PDT, `>> remote: make check exited 0`,
  23 targets ALL JUDGED, 2033 passed 0 failed, all seven per-map lines unmoved, determinism `762a0576f944f5b7`, no
  `test_arena_*` orphans). The tree it ran also carried `tools/candidate_page.py`'s "Version 2" string, committed in
  `503451c7`; the commits after it touch only this Status and `tools/candidate_page.py`, which no check target runs.
  `09cb016c` is on `main` as `377af60a`.
- **`09cb016c` is green** (both merges of `main`, the leak fix, the page generator): builder0, started
  20:32:08 PDT, `>> remote: make check exited 0`, 23 targets ALL JUDGED, 2033 passed 0 failed, all seven per-map lines
  unmoved, determinism `762a0576f944f5b7`. Ship's exit-leak gate: no `test_arena_*` test in its ORPHAN report (the
  random-arena test's 182 nodes are gone; `eb04ab38`). `arena-pytest` (laptop, `9419304d`): 45 tests OK, exit 0.
- **`0901ab64` is green** (the merged tree; above).
- **`b6d817f9` is green, merge here (CP2)**: builder0 16:16–16:52 PDT, `>> remote: make check exited 0`, 23 targets ALL
  JUDGED, 2005 passed 0 failed, sim-baseline `05df1d55ba49cde1` (baseline unmoved, as pre-registered), determinism
  `762a0576f944f5b7`, 0 engine messages. Dealt layouts byte-identical (regenerated, compared).
