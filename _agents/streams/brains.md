# Stream: brains (a squad forms up on the move; the computer's opening lets it be ahead; the transit never sends a crew away from the click)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 18 direction* (*His pick*),
> *Round 19 direction* (item 2) and *Round 20 direction*, `_agents/doctrine.md`, `_agents/navigation.md`,
> `_agents/workstreams.md` *Round 20*, and round 19's final reports: yours (`streams/archive/round19/brains.md`
> Status: the four known limits, the series) and orders' (`streams/archive/round19/orders.md` Status: the three
> requests to you, the probe `make two-squads-playtest`). You own `game/ai/**`, `game/tactics/**`,
> `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
> `tests/test_nav*.gd`, `mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines you
> declare. Orders' probe files (`game/control/two_squads_playtest.gd`, `tests/test_control_two_squads.gd`) are
> READ-ONLY instruments for you; a change to them is a request.

## The lead's direction (standing)

> *"Yes make the CPU smarter, this would apply to all units… our friendly players are just as smart"* (2026-10-04).
> On round 19's main: *"ok this is much better."* (2026-10-06). Nothing new from him for your paths this round: the
> items below are round 20 candidates 1 and 2, launched on his standing rule because they are what he sees when he
> orders a squad and when he crosses the floor.

## Where things stand (read at `c355a41e`; your own numbers)

- **The form-up stray (candidate 2):** a travelled move forms the shape around the travelling anchor at the spawn and
  then moves (round 12's transit design): orders measured crews 12–20 m off a straight line in the first 5 s and a
  Sumps straggler driving 17.7 m AWAY from the click to its seat before its squad moved off; your option (b) (tie-break
  by travel within a role) changed nothing (12.1 → 12.1, 20.0 → 20.0, 13.6 → 13.3 m) and was reverted. The fix you
  named: form up on the move, stations that start where the crews stand and converge on the shape over the first leg.
- **The computer's opening (your limit 2):** it attacks first, turns to HOLD only when its zone is threatened (an enemy
  33–35 m off), and by then its line is in contact, where the commander refuses an ambush; in his frame it took 0
  ambushes (in-contact refusals 148 / no-site 11 / late 18 on parade). The bay ambush fires only when the CPU is
  ahead before he arrives (8 of 8 in that stage). The price in his frame: +5.1 ms a tick mean, +3.4 median, sd 4.5
  (23 bins). CPU elements OFF on his path; his switch `make skirmish ARENA=parade CPU_LEADERS=1`. **His answer on the
  default is pending**; nothing here changes the default.
- Your other limits: the ambush spot hides one point, not the line; the hold costs vehicles in the 8-v-4 stage
  (−1.4 ± 1.2 alive per pair).
- Thirteen baseline lines; C19.3's rule (declared, alone, adopted) carries as C20.2.

## Decided by the orchestrator (each reversible; record a reason if you overturn one)

- **Form up on the move is the round's centre.** A travelled move starts every crew toward the click at once; the
  stations begin where the crews stand and converge on the formation over the first leg (or by a distance, say the
  formation's depth), so no crew drives away from the click and no squad shuffles before it sets off. Both sides.
  The acceptance is orders' probe: worst off-line distance in the first 5 s and worst "away from the click", before
  and after, three selection shapes, parade and the Sumps; and the arrive series (100 of 100) unchanged.
- **The opening:** a CPU that spawns nearer a ring than the enemy does takes it first and HOLDS from the start when
  the map gives it a bay or a flank site (parade, the Open Yard), rather than racing to the centre and turning only
  when threatened; otherwise it attacks as today. Declared; a paired series on parade and the Sumps (ambushes taken,
  sprung, the outcome per seed with its spread); the price re-measured only if the tick's work changes (ask for a
  quiet window through the orchestrator).
- **The ambush hides the line, not a point** (your limit 1): the site search tests every slot of the element's
  formation at the site, or the element takes a coil / column that fits what the site hides. Stretch if the first
  two take the night.

## Backlog (in order)

- **M1. Form up on the move.** The transit's stations start at the crews and converge; the probe before/after
  (`make two-squads-playtest`, three shapes, two maps); `tests/tactics/` scenario for a line and a wedge from a
  spawn row; the arrive series on one tree. Declared; pre-registered where it moves (every map's CPU armies travel).
- **M1b (added 2026-10-06 afternoon, from his playtest of CP1; after M1, before M2). His attack order is obeyed.**
  His words and the orchestrator's reading of the recording are in `game_design.md` *Round 20, afternoon: his attack
  order and the gangs' bait drill*. 25 Rat Rods, select all, V formation, attack one Law vehicle: Alpha went in alone
  and died; Bravo–Echo each ran the **bait** drill (`Drills.should_bait`: a visible enemy 30–95 m away, a non-leader
  to spare), one scout forward and four holding 45 m back, then backing toward their start line while the Law did not
  chase (`build/recordings/2026-10-06T14-59-04.jsonl`, seed 40047, foundry; the census every 30 ticks from 522).
  **Decided:** a player-given `attack` with a named target does not run the gang's elective drills (bait, encircle);
  they stay for the CPU and for the player's movement without a named target. Acceptance: a `tests/tactics/` scenario
  that replays this shape (five gang squads, one attack order on one target, enemies 30–95 m away, not chasing) and
  asserts every squad closes on the target with no `hold` member and no drill named bait/encircle; `make
  two-squads-playtest`'s numbers unchanged; a declared change (C20.2) if any fight line moves, else pre-registered
  UNMOVED (the thirteen lines are CPU-v-CPU, so expect UNMOVED unless the CPU's own attack tasks carry a player flag).
  Also look at the first leg of that order: four squads were given transit points at x = ±60/±68/±116 m (the whole
  width of foundry) before their attack; if that is the side-by-side spread scaling with five squads, say so in Status
  (orders' paths are closed this round; a request, not a fix).
- **M2. The opening posture** as decided, with the series and the refusal census.
- **M3. The ambush hides the line** (stretch if time is short).
- **M4. The guard tests and the stray numbers in `_agents/doctrine.md`** (a short section: how a squad travels now,
  with the numbers), and `navigation.md` if the transit's routing changed.
- **Stretch.** (a) The hold's vehicle cost in the 8-v-4 stage: can the holding element fall back one bound when it
  is losing the trade? (b) The CPU's squad leaders' price: the next equal-answer cut, if the profiler shows one.

## How to verify

`make remote T=check` green on every commit you report. **Every change to fights is DECLARED, merged alone, lines
adopted with `make sim-baseline-adopt` and named in the commit; everything else pre-registers UNMOVED** (C20.2).
Scenario or probe first; a paired series with its spread for anything that changes who wins (lesson 256); laptop
series only in a quiet window asked for through the orchestrator (lesson 260); the arrive series is part of green for
a movement change (lesson 261). Every number: commit, machine, workload, N, spread.

## Don't touch

`game/control/**`, `game/ui/**` (orders' and board's, closed; the probe is read-only for you) · `game/garage/**`,
`game/progression/**`, `game/units/**` (garage) · `game/match/**` (read; a signal is a request) · `arenas/**`,
`game/arena/**` · `mk/core.mk`, `tests/baselines/**` except declared lines · balance values (C12.6) · the elements
flag's default on his path (his).

## Waiting on the lead

- **CPU squad leaders on by default** (asked with the price; nothing here depends on it).

## Status

_Updated 2026-10-06 ~17:30 PDT (round 20, brains worker). The report first; detail per item after it. Evidence:
`streams/references/round20/brains/`._

### REPORT (M1 on main `29d323a2`; M1b on main `cdc59a84`; M2 green `97a581fb`; M3 `d6cfd29b` checking)

| item | commit | state | what he gets / what was found |
|---|---|---|---|
| **M1** form up on the move (DECLARED) | `4eaf948c`; **green `efc3682d`** (merged main `ea322e9f`) | **on main `29d323a2`** | a squad sets off at once, each crew from where it stands, and forms its shape over the first 30+ m; no crew drives away from the click to its seat |
| **M1b** his attack is obeyed (DECLARED) | **green `8ed06b70`** | **on main `cdc59a84`** | under HIS attack on a named target, no bait or encircle: every squad closes on it |
| **M2** the opening | **green `97a581fb`** (on `8ed06b70`) | built, measured, **shipped OFF** (`--cpu-opening`); the orchestrator accepted the overturn | nothing: it did not beat round 19's posture (below) |
| **M3** the ambush hides the line (DECLARED) | `d6cfd29b` (= dev `3d1caa5c`, on `97a581fb`) | 24-seed series; the orchestrator: ship it; check running | the CPU's ambush line lies where none of its crews can be seen, if one is in reach in time |
| **M4** doctrine.md + numbers | `881dc688` + the round-20 section | done | *Form up on the move* and *Round 20 (brains)* (M1b, M2 off, M3 with its lesson) in `doctrine.md`; navigation.md not stale (routing unchanged) |

**Start:** `make remote T=check` on `0788e268` (the launch tree): builder0, exited 0, 23 targets, 2139 passed 0 failed.

### M1 — form up on the move (DECLARED, `4eaf948c`; green `efc3682d`)

**Built:** `ElementPlan.transit_starts` / `converge` (pure) and `Element._advance_transit` recording each crew's place
in the route's frame. A crew's station starts where it stands, rides the anchor along the route, and eases onto its
seat with a smoothstep over `converge_m` = max(30 m, the shape's depth, 1.5 × the most any crew must fall back + 5 m),
capped so the shape is formed by the hand-off. Round 12's stations after that. Switches `--converge=off`,
`--converge=lead<M>`. Tests `test_tactics_converge` (pure: starts on the crew, never runs back along the route, the
shape after, the control arm, short moves), `test_tactics_form_on_move` (yard, both arms: a line and a wedge forward, a
wedge to the side). Tools: `make converge-probe` (CONVERGE_ARMS, CONVERGE_REPS), `squad-arrive-series`
`ARRIVE_ARM_FLAG` / `ARRIVE_DRILLS`.

**Green:** `efc3682d`, builder0, `>> remote: make check exited 0`, 23 targets all passed, 2158 passed 0 failed, thirteen
lines unmoved (as pre-registered), determinism `762a0576f944f5b7`. Above it: docs only.

**Orders' probe (C20.3), builder0, seed 3, three repeats an arm (real time, so not repeatable run to run):**

| map, case | worst AWAY from the click in 5 s, round 12 → M1 (m) | worst OFF-LINE in 5 s (m) |
|---|---|---|
| parade, selected | 6.3, 6.3, 6.3 → 0.4, 0.4, 1.8 | 12.6–12.7 → 13.8–13.9 |
| parade, one group | 10.2, 10.4, 10.2 → 1.6, 1.7, 1.7 | 15.0–16.1 → 12.0–13.1 |
| parade, one squad | 9.9, 10.1, 10.1 → 1.8, 0.0, 1.7 | 18.5–19.3 → 10.7–11.6 |
| the Sumps, selected | 5.9, 5.9, 4.7 → 4.8, 4.7, 5.1 | 24.4–34.3 → 15.9–17.5 |
| the Sumps, one group | 11.0, 9.5, 6.0 → 8.4, 8.7, 0.2 | 22.5–27.3 → 27.4–28.3 |
| the Sumps, one squad | 3.6, 1.4, 2.9 → 0.0, 1.6, 0.0 | 8.6–11.8 → 7.0–12.2 |

**Arrive series (lesson 261), builder0, `efc3682d`'s tree, five squads × five maps × seeds 1–4:** his attack-move (no
anchor): 100/100 both arms, identical in all 100 pairs; plain move 150 m: 100/100 both arms, median 21.1 s vs 21.75 s,
paired −0.46 ± 2.91 s, earlier in 63 of 100.

**Decided:** lead 0 (each first station on its crew). Leads of 10/20/30 m were measured (one run each, builder0: parade
away 5.9/8.4/6.9, 4.5/9.8/12.0, 3.2/9.5/9.1 against lead 0's 0.4/6.7/0.6; a Sumps run at 10 m sent a crew 18.8 m
away): a station ahead of the crew and off its nose lands inside a wheeled hull's turning circle and it backs round.

**Known limit:** the yard, wedge 100 m forward from the spawn row: away 1.4 → 3.2 m (an IFV backs round once); line
6.1 → 2.7. Next lever if he notices: the brain's aim point on a station kept outside a wheeled hull's turning circle.

### M1b — his attack on a named target is obeyed (DECLARED, green `8ed06b70`)

**Green:** `8ed06b70` (= `af0c2a02` cherry-picked onto main `29d323a2`), builder0, `>> remote: make check exited 0`, 23
targets all passed, 2160 passed 0 failed, thirteen lines unmoved as pre-registered, determinism `762a0576f944f5b7`.

`Drills.obeys_attack(state)`: a squad of HIS (`state.player`, set by Element) with `{"verb": "attack", "target": …}`
runs no `ELECTIVE_DRILLS` (bait, encircle), and one already running stops; reactions to contact are unchanged; the
computer's packs and his movement without a named target keep them. Scenario `test_tactics_attack_obeyed` (yard, seed
3, five squads of five gang scouts, one Law tank 70 m off, laptop): before, squads 1 and 5 ran bait and ended 16.9 m
FARTHER from the target; after, no bait/encircle, every squad closed 10.5–64.6 m in 15 s, the target destroyed; the
computer's attack still baits in all five squads. Pre-registered UNMOVED: thirteen lines, determinism, two-squads
(moves). **The ±116 m spread on foundry:** orders' side-by-side layout gives each squad its formation's width (a gang
vee ≈ 72 m at 18 m pitch), so five squads need ≈ 400 m and the clamp pins the outer two at ±116. My scenario assigns
tasks to elements directly (not through orders' layout), so it cannot measure the detour, and the recording is not on
this laptop: the number on record is the orchestrator's read (transit points ±60/±68/±116 m). Request below.

### M2 — the opening: built, measured, shipped OFF (green `97a581fb`) — the brief's decision overturned, accepted

**Green:** `97a581fb`, builder0, `>> remote: make check exited 0`, 23 targets all passed, 2164 passed 0 failed, thirteen
lines unmoved, determinism `762a0576f944f5b7`.

`Posture.near_ring` and `Posture.decide`'s `opening` (pure, tested); `ElementCommander._opening` (read once per match,
the ambush-site test from the ring). **Series** (`make opening-series`, `tests/tactics/opening_probe.gd`: both sides
from their spawns, 0–0, his eight Law vehicles to the CPU's near ring; builder0, 8 paired seeds):

| stage | ambushes taken (on / off) | CPU-minus-his alive, on − off | score margin, on − off |
|---|---|---|---|
| parade, he sets off at once | 0 / 0 (refusals in contact 384 / 396) | +0.50 ± 1.51 | +2.6 ± 4.3 |
| parade, he sets off after 10 s | 7 / 8 | −2.38 ± 4.07 | +2.0 ± 6.1 |
| the Sumps, at once | 0 / 0, no site at its near ring: identical runs | 0 | 0 |

**Why off:** on parade round 19's attack already goes to that same near depot and turns to hold once ahead, so the
opening adds nothing there, and it traded no better. When he rushes, nothing can be laid in time (round 19's finding
stands); where the map has no site it never engages. Kept behind `--cpu-opening` with its tests and series.

### M3 — the ambush hides the line (DECLARED, `d6cfd29b`)

`AmbushSite.find(…, line, timing)`: candidates ranked by how many of the line's crews (laid at the spot facing the
kill zone, as the plan lays an ambush) the enemy can see, then by distance, keeping only spots the element reaches in
time (the commander's rule, per candidate: the best-hidden spot is often farther toward the enemy and was then refused
as late; the first build lost round 18's ambush that way). No line = round 19's answer exactly (900-case test).
`--ambush-hides=point` / `--hides=point` = control. **Series** (`make hides-series`, round 19's hold stage, builder0, 8
paired seeds, `d5dff94d`): parade sprung 8/8 both arms, median spring 14.6 s vs 13.45 s; his loss line − point +484 ±
525 hit points; CPU-minus-his alive +2.00 ± 3.85; the Open Yard no site (8 identical). Pure: on parade round 19's spot
leaves 1 of 4 crews in his sight, the new one (14 m down the bay) none.

**More seeds (the orchestrator: 8 seeds were inside their noise):** seeds 9–24 on parade, same tree: +79 ± 425 hit
points, +0.88 ± 4.03 alive. **Pooled, n = 24 paired, line − point:** spring +2.20 s (se 1.00), his loss +214 (se 100),
CPU-minus-his alive +1.25 (se 0.80); the CPU better in 11 seeds, worse in 8. **Cost:** none where the map has no site
(identical runs); a search 1.17× / 1.17× / 1.02× the point search's time on parade / the Open Yard / the Sumps (laptop,
cold memo, 300 cases; a test bounds it), only while CPU squad leaders run (OFF on his path). **Verdict: ship it**, on
the mechanism (a hidden line springs later, deeper in the kill zone) with all three measures pointing the same way at
1.6–2.2 se; not on the spring time alone.

### Questions for the lead

- (pending, his) CPU squad leaders on by default.

### Requests to other streams

- **orders (round 21; recorded by the orchestrator):** an attack on a named target ordered to several squads lays
  them side by side at their formation widths, so five gang squads span ≈ 400 m and the outer ones are clamped to
  ±116 m on foundry and drive out there first. Converge on the target, or cap the spread, for a named-target attack.

### What to playtest (exact commands)

- `make skirmish ARENA=parade`: select two squads, right-click across the floor: both set off at once, nobody backs
  away to its seat; the shape forms on the first leg.
- (after M1b) `make garage`, Road Gangs, 25 scouts, select all, attack one vehicle: every squad drives at it.

### Next steps

M1b → check alone after M1 is on main; then M3 alone. Stretch (a) the hold's vehicle cost; (b) the price.
