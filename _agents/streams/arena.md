# Stream: arena (terrain that makes ambush and flanking possible, and the maze nav is measured against)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*, *The arena*), [../workstreams.md](../workstreams.md) (you own **N3** and **M2/C5**),
> [../arenas.md](../arenas.md), and your round-5 report in [archive/round5/arena.md](archive/round5/arena.md) —
> including the 240-match series saved in [references/arena_series_round5.json](references/arena_series_round5.json).
>
> **You own** `game/arena/`, `arenas/`, `tools/make_arenas.py`, `mk/arena.mk`, `_agents/arenas.md`.

## The lead's direction (2026-09-18, verbatim)

> *"The maps are still pretty basic, right now the game is just this big open brawl with dumb units. We want to be able
> to set up ambushes, do flanking maneuvers."*

> *"We might even want a map that's a quasi maze just for test purposes to ensure units can get through it."*

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

- Seven layouts exist: `boneyard, boulevard, foundry, furnace, pit, scrapyard, yard`. Schema and kit are documented at
  `game/arena/arena.gd:1-30`: `obstacles`, `props`, `spawns`, `spawn_zones`, `lanes`, `regions`, `hazards`.
- `Arena._build_obstacles()` (`arena.gd:100-124`) makes a `StaticBody3D` + `BoxShape3D` per obstacle;
  `OBSTACLE_SIZES` (`arena.gd:35`): crate 4.5×3×4.5, wall 18×3×1.5. The navmesh is baked at startup from the southern
  half plus a 180° mirror (`arena.gd:84-97`), because an asymmetric bake gave the south base a 64% win rate
  (trip-up 21). `validate()` enforces point symmetry.
- **Your own round-5 measurement is the reason this brief is short on "more maps" and long on "shape":** flanking
  routes took 4–5% of unit-time on dense layouts against 14% on foundry, and three streams independently landed on
  the same explanation — **a single central control point overrides every tactical choice**, so terrain has nothing to
  decide. combat separately measured median hit range at 39–43 m on *every* map. More props will not fix that.
- ~~Wrecks are on physics layer 4 **on purpose**, so they never block driving~~ — **this is false**, and it was
  false when the brief was written. See *X9 / dynamic obstacles* in the Status: the `wreck` kit prop is a layer-1
  StaticBody3D under the `navigation_source` group, so it blocks driving and is baked into the navmesh like any
  container; a destroyed vehicle leaves no body at all.

## Backlog (in order)

**X1 — the maze, on day one (N3, CP2).** `arenas/maze.json`: the quasi-maze the lead asked for by name. It is a
**test fixture, not a shipping map** — say so in the file and in `arenas.md`. Requirements:
- built from the existing kit (containers, walls, barricades), point-symmetric like every arena so `validate()`
  passes;
- a start zone big enough for 30+ vehicles and a far objective, with a route that is genuinely non-trivial: at least
  one gap only ~1.5 vehicle-widths wide, at least one dead end, at least two alternative routes of different length;
- reachable — verify the navmesh actually connects start to objective before handing it over (a maze whose navmesh is
  disconnected will read as a nav bug for a day).
Then `make nav-maze` (the target lives in `mk/arena.mk`; nav reads its output): send N units across and report
arrivals, time to 50/90/100%, unit-seconds under 0.5 m/s, stuck events, and any unit that ends up off the navmesh.
**Message the orchestrator the moment it is on the branch** — nav's acceptance test is blocked on it, and this is a
day-one job, not a week-one job.

**X2 — approaches that are not covered from everywhere.** The lead wants ambush and flank to be *possible*, which is a
property of sightlines, not of prop count. For each shipping arena, build and measure:
- **covered approach routes** — a path from a spawn toward the objective along which a unit is exposed to less than
  some fraction of the defending positions;
- **sightline breaks** deep enough that an element can cross without being seen from the centre;
- **overwatch positions** that dominate a lane but can themselves be flanked.
Publish the numbers per arena (extend the existing `make arena-report`): exposure along the best three routes, the fraction of
the map visible from the centre, and the longest sightline. A map where the centre sees everything cannot host an
ambush, and that is measurable before anyone plays it.

**X3 — objectives that pull play off the centre line.** Your own finding, and the orchestrator's pick for the highest-
leverage change this round: the single central control point funnels the whole fight. Try, and measure:
- two or three objectives away from the centre line, or
- an objective that moves or rotates during the match, or
- per-arena objective placement that suits the terrain rather than the map's midpoint.
Measure it as a **control that cancels the suspected cause** (lesson 22): the same arenas with the objective moved,
paired and mirrored — not more seeds of the same thing. The claim to test is "flanking-route unit-time goes up and
median hit range goes down when the objective is off-centre."

**X4 — terrain features, not just props.** Everything in the kit today is a box on a flat floor. What makes an ambush
work is ground that hides an approach: sunken lanes, raised platforms with limited ramps, a long wall with two gaps,
a building footprint you can go around either side of. Check what the navmesh and the vehicles can actually handle
(slopes need `agent_height`/`cell_height` care — trip-up 23) and add what survives. Coordinate with feel on how new
terrain types dress.

**X5 — the arenas the lead will actually play.** He has still never said which arena is fun ("Not played yet", his
round-5 sign-off). `--arena=random` is the default and he picks in control's ARENA row. Make sure every shipping
arena is worth landing on, and cut or fix any that measures as a brawl.

**X6 (stretch) — destructible cover.** Approved by the lead in the round-5 sign-off and deliberately not landed then
(two cross-stream changes at once make failures unattributable). The design is settled: **a stack collapses to a lower
stack, never changing drivable space.** Only start it once X1–X3 are done and nav's avoidance has landed, and
coordinate with nav — anything that changes what blocks driving touches the navmesh.

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `make arena-test` and `make arena-report` (both exist) on every layout you touch; `Arena.validate()` is the point-symmetry gate.
- **The swap-bases fairness control after any arena, spawn or navigation change** (invariant 4,
  [../verification.md](../verification.md)). A symmetric map does not give a symmetric navmesh (trip-up 21).
- Judge arena art and shape from `--skirmish` screenshots, not only the follow camera — the overview is orthographic
  at ~3 px per metre and art thinner than 0.5 m vanishes (trip-up 46).
- Match series for tactical claims — and **run the configuration players actually get** (lesson 23): faction armies,
  30 a side, default flags. Never publish a number measured across combat's CP4 range change.
- You **must not** move the sim baseline (invariant 2). If a layout change moves it, that is a finding: say so.

## Don't touch

`game/ai/**` (nav's and squad's), `game/control/` `game/ui/` `game/camera/` (control's), `game/units/` `game/combat/`
`game/match/` (combat's), `game/theme/**` (feel's — including how your props are *dressed*; you place, feel dresses).

## "N passed, 0 failed" can be a TRUNCATED run (round 7)

**`make check` stops at the first failing target.** Its targets run in order — `lint test net-smoke combat-smoke
broker-test relay-smoke lobby-smoke match-smoke determinism sim-baseline garage-smoke army-loop-smoke
announcer-check audio-check` — so a failure at `sim-baseline` means the **four after it never run**, and the
runner still prints `N passed, 0 failed` for the ones that did.

So *"sim-baseline was the only failure"* is indistinguishable from *"sim-baseline was the last target that got a
chance to fail"*. **`0 failed` is a property of the targets that ran, and it passes for the wrong object.** Same
shape as the readiness bug in `ArenaFixture`: a claim built on a property rather than an identity.

**This bites arena specifically.** `announcer-check` and `audio-check` are the last two targets, and the perimeter
work touches the stands and gates feel dresses — and `tools/announcer/test_arena_names.py` is a file this stream
edits by recorded exception, precisely the sort of thing a new arena shape could disturb. **A truncated run cannot
tell you whether your own change broke them.**

**What to do instead of waiting:** the expensive parts need builder0, but the test components run locally in
minutes and cover most of the risk —

```bash
python3 -m unittest discover -s tools/announcer -p 'test_*.py'   # 58 tests, ~2 min
make audio-pytest                                                # 16 tests, ~30 s
```

Both green on the round-7 perimeter and terrain work (2026-09-19), so the hexagon's edge spans do not disturb the
announcer's arena-name handling.

## Round 7 state (2026-09-19, branch merged with main at `4977e991`)

**Built, tested, and needing nobody:**

| Item | What exists |
|---|---|
| **A** water / pits / bridges | `layout.terrain`, carved floor + 0.9 m rim cut at the decks. Measured before built (`make water-probe`) |
| **C** cost-and-reward metric | `make arena-report` emits a `DECISION` line. **Every shipping arena reads `spread 0.00`** |
| **D** perimeter polygon + spans | `Arena.perimeter()` / `perimeter_edges()`, consumed by control (`7dd14aca`) and feel. Hexagon builds and bakes; mirrored trips match to 0.05 m |
| **M4** `contains` / `clamp_into` | Nearest-boundary, allocation-free, answers for the square too, knows about water |

Local: arena 64/64, announcer 58/58, audio 16/16, tactics 10/10, objectives 3/3.

**Blocked on other streams, and both blocks are real rather than cautious:**

1. **The hexagon cannot validate until `Match.ARENA_HALF_SIZE` goes 120 → 140** (combat's). A hexagon at 120 holds
   only 48 of 104 spawn points, and `Arena.validate()` now refuses it — so a map authored at 120 would have to be
   authored again. **This is why Pit and Yard are untouched.**
2. **Off-centre objectives cannot ship until combat's N7 read-through reaches `main`.** `Arena.objectives_of()`
   exists but **nothing in `game/` consumes it**: `Match.in_control_zone` is still static and central, and squad's
   `Objectives` shim deliberately **errors** for a non-central layout rather than answering plausibly. That guard
   is the right design — a CPU competing for the wrong ground looks completely functional — but it means authoring
   a pair now produces a layout that refuses to run.

**So the next map work is gated, and the gate is not mine.** When both land: author Pit and Yard on the hexagon
with a mirrored objective pair, and the `DECISION` spread is how to tell whether it worked.

## A local `make check` does NOT check the simulation baseline (round 7)

**`sim-baseline` SKIPS on this laptop and always will.** The baseline file is keyed by glibc version, builder0 is
`glibc-2.43` and the laptop is `glibc-2.39`, so the target prints *"sim-baseline SKIPPED: no baseline for
glibc-2.39"* and **exits 0** whatever the simulation does. It fails only on builder0 — the machine that gates
merges.

So a local run is silent on exactly the thing most likely to be broken by someone else's merge, which is why a
green local suite is never a substitute for `make remote T=check`. My `FILTER=arena` runs and `--check-only` passes
mean what they say; they simply cannot see this.

**It also means `sim-baseline FAILED` alone, on a branch that merged `main`, is usually not yours** — the orchestrator
records the baseline once per round after the last sim-changing merge, so `main` runs red in between. Anything else
failing is real.

## Resume here (written at the round-6 quota stop, 2026-09-18)

**Branch merged, tree clean, nothing in flight.** The durable knowledge is in
[../arenas.md](../arenas.md) — *Designing a new map: start here* and *Why the navmesh is baked as one half plus a
mirror* — deliberately there rather than only here, because a map author reads that file and not a stream's Status.

**The three things that would hurt most to lose:**
1. **`centre_sees_share` predicted the lead's verdict and is therefore a design target, not a description.** Aim
   below ~0.30; above ~0.50 he has rejected it twice. Pure geometry, cannot go stale, one `make arena-report` to
   check before anyone models a prop.
2. **X2 scores what a route costs and never what it reaches**, so it reports cheap flanks on maps that play as a
   brawl. A cheap route to nowhere is scenery. The objective work and the terrain work are one job.
3. **The 60-unit nav-maze baselines are superseded** (nav's spawn-coincidence fix — 52 spawn points, `slot %
   size` wrapped 8 pairs onto each other); **the 30-unit row is not** (30 < 52). See
   [references/arena/README.md](references/arena/README.md).

**Two knobs, both deliberate:** `WATCHER_REACH_M` is read from the catalog (`make arena-reach` → `Engagement.
covering_range()`), `--reach` overrides; `agent_max_climb` is **untouched on purpose** — raising it lifts the ~20°
terrain ceiling but re-bakes every arena's mirrored-half mesh and needs the swap-bases control re-run.

**Not started, on instruction:** the octagon/hexagon shape change, bridges/water, and X3.

## The lead's answer (2026-09-18, from the review page's own store)

**Asked keep / fix / cut / play-it-first per map, he cut four and kept two.** Read back from `answers/arenas` on
https://claude.ai/artifact/9RrjvWxhXZbu7ngnao5qn4 :

| Arena | centre sees | His call |
|---|---|---|
| **Boulevard** | 0.64 | **CUT** |
| **Foundry** (its card covered the **Furnace**) | 0.56 | **CUT** |
| **Boneyard** | 0.40 | **CUT** |
| **Scrapyard** | 0.29 | **CUT** |
| Pit | 0.30 | **KEEP** |
| Yard | 0.20 | **KEEP** |

No notes given. **The four most open maps are exactly the four he cut** — centre-visibility predicted his answer
better than anything else measured, though scrapyard (0.29) and pit (0.30) are nearly tied and he split them, so it
is not a pure function of the metric.

**Confirmed in words as well as buttons:** *"the only two maps worth keeping were the last one and the one with the
octagon of shipping containers. All the maps need to be higher quality regardless."* **Nothing is being deleted** —
the four are *do-not-invest*, and Foundry stays `DEFAULT_LAYOUT` until he rules on that infrastructure change.
The original caveats, which he has now answered:
1. Taken literally it removes **five of seven** shipping arenas. The page invited "cut" as a real answer but never
   said "you are about to remove most of the game's maps"; he may have meant that, or may have meant "not worth
   fixing, prioritise accordingly".
2. **Foundry is `Arena.DEFAULT_LAYOUT`** — every headless run, the sim baseline and most tests use it. Cutting it
   is an infrastructure change that moves the baseline, not a content change.

If he confirms, X5's remaining scope collapses: *"make every shipping arena worth landing on"* becomes *"make two
good ones"*, and X3's objective work only has to serve pit and yard.

## Waiting on the lead

1. ~~**Which arena is fun**~~ — **answered above.** The page itself is still live — **the page is live and with him: https://claude.ai/artifact/9RrjvWxhXZbu7ngnao5qn4**
   (**version 3**: the first two had no controls at all — the four answers were printed as a *sentence* that looks
   like a control and is not one. He said so: *"doesn't have buttons I can click to give feedback"*. Now radio
   buttons, a summary he copies, and a notes box; no database, because the pick is the whole payload. **Verify an
   interaction by performing it — reading the HTML you wrote cannot tell you the words do nothing.**)
   (`make arena-page` rebuilds it; republish that URL to update it). Six cards, worst first, each asking
   *keep it · fix it · cut it · I'd rather just play it first*. A link rather than a path under `build/` on purpose:
   lesson 12's failure was review pages nobody could open.

## Status

_Round 8, arena. Updated 2026-09-19. Rounds 6–7 below, kept for their reasoning._

### Round 8: making the lead's "stuck" measurable

He played round 7: *"it still sucks… units are still just getting stuck behind basic barriers where they seem to
just move back and forth indefinitely trying to get unstuck."* `nav-fight` reported blocked-by-terrain at **zero**.
My assignment was to make the game's version of stuck measurable **before** nav builds flow fields, so the change
is not shipped against a null.

Definitions were **pre-registered and committed at `01c80365`, before any probe existed**:
[references/arena/stuck_preregistration.md](references/arena/stuck_preregistration.md). They have not moved.

| Commit | What |
|---|---|
| `01c80365` | The definitions, written before measuring |
| `d2d1bc04` | `arenas/barriers.json` — a fixture built around barrier **ends**, where nav's round-7 pins happened |
| `9c22f5e4` | `oscillating` and `no_progress` counters in `maze_probe.gd`, plus the barriers/yard measurement |
| `95b1febd` | The four `--arena=random` maps measured. **Hypothesis 1 refuted** |

**The finding, and it is a gap rather than a number.** On the barrier fixture `crawl` 0.112 + `oscillating` 0.015
do not add up to `no_progress` **0.192**: ~6.5 points of under-way time is units making no progress while neither
slow enough to count as blocked nor travelling far enough to count as shuffling. **`nav-fight` asks "is this unit
blocked" and honestly answers no; the player asks "is this unit arriving" and the answer is no for a fifth of the
time.** A unit fails the second test while passing the first, and that is the whole disagreement between the
instrument and the lead.

**What round 8 cost me, stated plainly.** My hypothesis — that "back and forth" meant oscillation — was right in
direction and wrong in size: oscillation discriminates 15× but is 1.5%, not "indefinitely". And **the four maps he
actually plays are all clean** (`no_progress` ≤ 0.050, 30/30 arriving). So the barriers fixture reproduces a stall
on **ground he never drives**. It is a *sensitivity fixture* — known-stalling ground for detecting whether a
movement change helps — and it is **not** a reproduction of his complaint. The lesson is combat's, from the same
day: *finding the authoritative copy of a value is not the same as checking the value still matters.*

**That gap is now closed, and the answer was the verb.** `nav-fight` run unmodified on the same four maps:
`blocked_terrain` is 0.000–0.010 everywhere, and the time that is not progressing is **`retasked` 0.298–0.364** —
nav's own definition, *driving under a valid path toward a destination the brain chose, not the player's* — of
which about three quarters are `ENGAGE hop`, a destination change every ~1.3 s. The by-verb split is the finding:

| verb | `progressing` | `retasked` | re-tasks per unit-minute |
|---|---|---|---|
| **move** | **0.876 – 0.941** | 0.0 | 0.0 |
| **attack_move** | **0.408 – 0.474** | 0.42 – 0.494 | 43.9 – 47.9 |

**My crossing probe issues a plain move, which is literally the top row** — so every clean number I published this
round was clean for a reason that had nothing to do with the maps. **The untested variable was never the terrain;
it was the verb, and behind the verb, the brain.** `ENGAGE hop` is combat/AI ground and I have not gone near it.

**What I refused to claim:** that a re-task *looks like* "back and forth". I have where the time goes, not what the
trajectory does. That needs the oscillation counter inside the fight probe (extracted for nav at `c0aa421f`) or a
human watching one match.

### Round 8, second half: the things he could see

| Commit | What |
|---|---|
| `de61d04e` | `--arena=random` deals only the maps he kept. His verdict had been in `game_design.md` for a round and had never reached a line of code, so half of every skirmish was a map he had cut |
| `8fda01a8` | **The Terminus** — the cityscape, and the reason no map could place a city block |
| `94ca59bc` | Into the rotation, after the render was looked at |

**The navmesh baker silently ignores boxes larger than about 8 m on both horizontal axes** — no hole, no rooftop,
nothing, while the collision body is built correctly and physics still stops hulls. Every obstacle this project
owned is thin on at least one axis, so nothing had ever crossed the threshold; **feel's city block was the first,
and the first person to place one would have found it did not work.** `Arena._obstacle_shapes()` tiles a large
footprint with thin slabs. A hollow shell of four walls is the version that looks obviously right and is wrong: it
leaves an unreachable navmesh island inside every building. Full measurement table in [../arenas.md](../arenas.md).

**The map, measured and then looked at:** centre_sees 0.13 (yard 0.20, pit 0.30), decision spread 0.41 after
sweeping ten placements, longest sightline 196 m — the shortest of the three. 30/30 cross it. **And it is the first
shipping map that moves the stall measure: `no_progress` 0.091 against yard's 0.050**, which makes it the test bed
flow fields have never had, on ground he plays.

### Round 8, late: instruments, and three of my own mistakes

| Commit | What |
|---|---|
| `f7bff357` | `nav-maze` passes `NAV_FLAGS`, and prints `NAV_MAZE_ARM` from the **live code**, not the flags given. nav's flow-field A/B had run the same treatment twice and come back byte-identical — a clean null with no symptom |
| `daa6bb70` | A watch at the **closed** end of `centre_sees_share`, calibrated on the maps the lead has ruled on (terminus excluded, so it flags itself) |
| `b5e52899` | **Can this map hide the longest hull?** Reads `game/units/units.gd` rather than copying it |
| `172f6150` | A correction: see below |

**The hull-cover cliff, and it is the number to give him.** Share of the field within 45 m of a prop long enough
(best case — the box's longest horizontal side):

| hull | 6 m | 7 m | **12.19 m** | **12.5 m** | 14 m |
|---|---|---|---|---|---|
| yard | 0.99 | 0.99 | **0.99** | **0.00** | 0.00 |
| pit | 0.85 | 0.48 | 0.46 | **0.00** | 0.00 |
| terminus | 0.98 | 0.95 | **0.91** | **0.91** | **0.91** |

**A step at 12.19 m — `container_40`'s own length — not a gradient**, so "12 m or 14 m" for the War Rig is binary
for cover, not stylistic. The Terminus covers it at any length (40 m blocks); yard and pit cover it nowhere. The
v1 maps are fine because the legacy `wall` is 18 m, so **this regression arrived with the arena kit**. On this
tree the rig is still **5.6 m**, so it is a forecast, not a live defect, and the check flips itself when 14 m lands.
**No long prop added to yard or pit**: they are maps he kept, and at 12 m the problem disappears with no map change.

**Three mistakes of mine this round, recorded because the pattern is the same each time:**

1. **Four tests that never ran.** Added as module-level `def test_...()`; `make arena-pytest` is `unittest discover`,
   which collects `TestCase` subclasses and silently ignores bare functions. The count stayed at 14 and they
   "passed" by not existing. Now 18, and verified failable by breaking the kit table on purpose.
2. **A guard calibrated on the thing it watches.** The closed-end watch first took its range over every shipping
   map *including terminus*, so terminus defined the low end and could never trip it.
3. **A tidier story than the truth.** I wrote that the stale objective test was hidden "three reds deep" in
   `make check`. **`arena-pytest` is deliberately not in `make check` at all** — my own note says so. Nothing
   masked it; `make arena-test` is the gate, my brief requires it on every layout change, and I did not run it.

### What is verified, and what is NOT (2026-09-19, end of round 8)

**Branch tip `1858c167`**, on top of `main` merged at the checkpoint (`1c1d30b1`, baseline `glibc-2.43
0cb238bf366e141f`).

| Ran | Result | Where |
|---|---|---|
| `make test` (full Godot suite) | **1261 passed, 0 failed** | laptop |
| `make arena-pytest` | 19 passed | laptop |
| `make announcer-pytest` | 58 passed | laptop |
| `make match-pytest` | 11 passed | laptop |
| `make audio-check` | passed | laptop |
| `make announcer-audit` / `-variance` | passed | laptop |

### ✅ GREEN: `83df0301`

    1261 passed, 0 failed
    sim-baseline passed: 0cb238bf366e141f (glibc-2.43)
    >> remote: make check exited 0 (build/ copied back)

**On builder0, the wrapper's own exit line and the runner's counts**, no `make: ***` in the log. `tools/remote.sh`
captures `git rev-parse --short HEAD` before the rsync and the tree was clean, so the commit identifies what ran
(no `DIRTY`). **This covers all eleven commits ahead of `main`**, `4515bb4b` included — verified with
`git merge-base --is-ancestor`, after I told the orchestrator the reverse and had to correct it.

**Nothing in those eleven commits caused either earlier red.** What follows is kept because the reasoning is the
point, not the history:

---

**⚠ Before that run there was NO green hash for any round-8 arena commit.** Stated exactly, because a pass-count
without an exit line is the thing the contract warns against:

| remote check | covered | runner | wrapper |
|---|---|---|---|
| on `8fda01a8` | the cityscape + carve fix | `1219 passed, 0 failed` | **`exited 2`** — `sim-baseline FAILED` (stale baseline, two recordings behind; not my change, proved by a same-machine A/B) |
| on `94ca59bc` | + the rotation | `1238 passed, 0 failed`, `sim-baseline passed` | **`exited 2`** — `announcer-pytest`: terminus had no spoken name |
| on `cff53fcf` | — | — | **`exited 3`, "cannot reach"** — builder0 down. **Not a check result.** |

**Both failures are now resolved** (the baseline was re-recorded on `main`; feel recorded the 18 clips and
`announcer-pytest` is 58/58 here). **But that is an inference, not a verified green**, and both checked commits
are now on `main` — so **not one of the commits still ahead of `main` has ever been in a remote check.** `builder0` has been unreachable since the
network outage — `ssh: connect to host builder0 port 22: No route to host`, confirmed from combat's session too, so
it is the machine and not this worktree. What is therefore **unverified**: `net-smoke`, `relay-smoke`,
`lobby-smoke`, `broker-test`, `combat-smoke`, `match-smoke`, `determinism`, `garage-smoke`, `army-loop-smoke` and
**`sim-baseline`** — which cannot be checked here at all, because the baseline is keyed by glibc version and this
laptop's libm is not builder0's.

**The first thing to do when builder0 returns: `make remote T=check`, and report it from the wrapper's own
`>> remote: make check exited <N>` line plus the runner's `N passed, M failed`.** Note the wrapper distinguishes
an unreachable host (**exit 3, "cannot reach"**) from a failing check — do not read one as the other.

**Questions for the lead** (not blocking; recorded per the worker contract):

1. **The Terminus is in the rotation and he has not ruled on it.** It is the one entry in `Arena.ROTATION` that is
   not his verdict. Two things a human should judge: **it is dark** (near-black towers lit by their windows; the
   street reads dimmer than yard's), and **street level is plain** — flat window grids where a tank drives, which
   is feel's own open question, unanswered. Removing it is one line and one test expectation, both commented.
2. **Is a hexagon what he wanted?** yard and pit shipped as hexagons and he has not commented either way.

---

_Round 6, arena. Updated 2026-09-18._

### Plan (backlog order, with the reasons where the brief left a choice)

1. **X1 the maze (N3/CP2)** — day one, nav is blocked on it. **In progress, geometry and tooling done.**
2. **X2 approaches that are not covered from everywhere** — extend `make arena-report`.
3. **X3 objectives off the centre line** — the highest-leverage change; measured with a paired mirror control.
4. **X4 terrain features** — only what the navmesh and vehicles survive.
5. **X5 the arenas the lead will play** — plus the arena page he is still owed from round 5.
6. **X6 destructible cover (stretch)** — not before X1–X3 and nav's avoidance.

### Where things are

| Item | State |
|---|---|
| **X1 the maze (N3/CP2)** | **Done.** Layout, `make nav-maze`, baselines, docs. Shipped to nav via the orchestrator (nav had no session; the orchestrator wrote my baseline into `nav.md`) |
| **X2 approaches not covered from everywhere** | **Done.** `make arena-report` answers it at two reaches; `make arena-pytest` guards the instrument |
| **X3 objectives off the centre line** | **Blocked twice over** — see below. Schema and validation are done on my side |
| X4 terrain features | **First step done** — what slope the engine survives is now measured, not guessed. Authoring terrain not started |
| X5 the arenas the lead will play | **Done, with him.** Page live at https://claude.ai/artifact/9RrjvWxhXZbu7ngnao5qn4 — the round-5 gate is finally open |
| X6 destructible cover (stretch) | Not started, correctly — X3 is not done and nav's avoidance has not landed |

**Everything through `d3a42267` is merged into `main`.** The last check on that tree was `1125 passed, 1 failed` —
the one failure was `test_tactics_scenarios::test_an_element_ambushed_at_close_range_assaults_through_it`, which is
**not this stream's**: my diff against `main` under `game/` and `tests/` is a single file the test runner never
collects (`reach_probe.gd`, not `test_*.gd`), and `tests/tactics/` is byte-identical to `main`. The orchestrator
verified that before merging. Cause, confirmed by nav's bisect and reproduced here twice: nav removed round 5's
`_around_friends` sidestep, so a column no longer overtakes and the assault arrives 24 ticks later; squad widened
the window. Earlier greens on this branch: `912f8713`, `5590c465`. — `make remote T=check`, runner `1018 passed, 0 failed`, wrapper
`>> remote: make check exited 0`. Reported to the orchestrator. **`38c15f77` and `13add85d` are RED — do not merge
either** (see *The mistake worth reading* below).

### X1 — the maze (N3/CP2): done

`arenas/maze.json` (authored in `tools/make_arenas.py`), `make nav-maze`, `tests/arena/maze_probe.gd`,
`tests/test_arena_maze.gd`, documented in [../arenas.md](../arenas.md) *The Maze*, five baselines with provenance in
[references/arena/](references/arena/).

Every requirement in the brief is asserted against the **real baked navmesh**, not against `arena_report.py`'s grid
model:

| Brief's requirement | What it is | Test |
|---|---|---|
| built from the kit, point-symmetric | 152 container props, `validate()` passes | `test_every_shipped_layout_is_valid` |
| start zone for 30+, far objective | the standard 52-slot spawn zones; goal is the far base | `test_a_horde_can_get_from_one_base_to_the_other` |
| a gap ~1.5 vehicle-widths | 7 m physical → **3 m drivable** (hulls are 2.6–3.0 m wide) | `test_every_band_gap_is_open_and_the_tight_one_is_still_tight` |
| at least one dead end | the pocket at x ≈ −98, z ≈ 41; leaving means backtracking north of z = 52 | `test_the_dead_end_has_no_back_door` |
| two routes of different length | ~40 m apart measured whole (spawn → gate → far base) | `test_the_two_serpentines_are_different_lengths` |
| **reachable** — verified before handover | 424 m navmesh route vs a 204 m crow flight (2.08×) | `test_a_horde_can_get_from_one_base_to_the_other` |

**The finding that matters is the control, not the maze.** Laptop, `38c15f77`, seed 1, 180 s, hold-fire, driving only:

| run | arrived | t50 | t90 | units that ever stalled 3 s | route travelled |
|---|---|---|---|---|---|
| maze, 30 | 15/30 | 60 s | never | 30 of 30 | 47% |
| maze, 60 | 36/60 | 56 s | never | 60 of 60 | 49% |
| **yard, 60 (control)** | 33/60 | 31 s | never | 27 of 60 | 91% |
| maze, 60, head-on | 23/60 | never | never | 60 of 60 | 39% |
| yard, 60, head-on | 35/60 | 37 s | never | 30 of 60 | 93% |

On **yard, a shipping arena**, with no enemy and nothing to do but drive, **45% of a 60-vehicle force never arrives
in three minutes** and 27 of 60 stall outright. That is the lead's *"a bunch of cars just get stuck or blocked by
other cars"* reproduced headlessly without a shot fired. The maze sharpens it; it does not invent it. Head-on
traffic barely moves yard (55% → 58%, inside noise) and collapses the maze (60% → 38%).

**Decisions, with reasons:**

- **The tight gate is 7 m physical, not the ~4 m "1.5 vehicle widths" reads as literally.** The nav agent radius is
  2 m, so a gap of width W leaves W − 4 m of drivable corridor: a 4 m gap is *disconnected*, not tight. 7 m gives a
  3 m corridor and sits on the shorter route, so a horde chooses it.
- **The two gates share one corridor rather than running as separate pipes**, so two squads sent different ways meet
  head-on — the peer-to-peer right-of-way case. `NAV_BOTH=1` exercises it.
- **The probe measures only positions over time**, so nav can rewrite everything under the order and the numbers
  keep meaning the same thing.

**Looked at, not just measured** (`make remote T=arena-shots ARENAS=maze,boulevard`, builder0, 10:32–10:43, fresh
timestamps checked against the stale-`build/` trap): the maze reads as intended from both the match-runner overview
and a player's skirmish camera. Bands run wall to wall with staggered gaps, the dead-end wall at x = −86 stands,
the fixture names itself in the HUD ("The Maze (nav test fixture)"), and a real fight happened in it — the command
line read *"Alpha: line, near ambush — ambushed at 41 m: turn into it and assault through"*. Geometry confirmed
against the file afterwards: all 152 props are `container_40` stacked 2 high (5.18 m, well over the 1.3 m eye
line), and the tight gate measures 6.8 m edge to edge.

Fair warning for whoever reads it next: **it looks like a set of parallel walls, not a labyrinth.** That is what a
point-symmetric fixture with a 3 m gate comes out as, and the measured properties (2.08× serpentine, one dead end,
two routes) are what nav is judged on — but nobody should expect a hedge maze.

### X2 — can a map host an ambush: done

`make arena-report` now reports `centre_sees_share`, approach routes at three cover penalties, `posting_gain`, and
overwatch positions scored by what they cover *and* whether they can be approached unseen. Full table and the
assumptions: [../arenas.md](../arenas.md) *Can this map host an ambush?*

**Three findings:**

1. **At realistic ranges, terrain is not what decides whether you get across.** Direct-route exposure is 0.05–0.12,
   and the most covered route only reaches 0.02–0.07 for a 1.0–1.1× detour.
2. **Posting an element is what covers ground, and open maps reward it most** — foundry +0.127, boulevard +0.107,
   yard +0.024, maze +0.018. **What a support-by-fire task is worth is a property of the map.** (Useful to squad.)
3. **boulevard is the arena to change:** its centre sees 64% of the field and its best overwatch can be approached
   unseen from only 0.12 of directions — it dominates and cannot be flanked back. foundry is second on both.

And the standing one: **every top overwatch position on every arena is within ~40 m of the centre**, where the
control point also is. Terrain is not what is missing — a reason to be anywhere else is.

### X3 — objectives off the centre line: blocked, and my half is done

**Blocked twice.** (a) It is a tactical claim, so its series must not straddle **CP4** — the orchestrator is holding
me. (b) **`Match` hard-codes `CONTROL_CENTER := Vector3.ZERO` and `CONTROL_RADIUS := 16.0`**, and a layout's
`control_point` reaches only the *dressing*. **The arena cannot move its own objective today; the field is
decorative.** `game/match/` is combat's.

My half is done so combat's is as small as possible: `objectives: [{name, position, radius}]` in the layout schema,
`Arena.objectives_of()`, and validation requiring **mirrored pairs** (a lone off-centre objective is owned by
whichever base is nearer). A layout with no `objectives` list reports exactly the single central zone Match already
hard-codes — asserted for every shipped layout — so combat's change is a read-through that cannot move any existing
arena.

### X4 — what slope the ground can have: measured

`make slope-probe` (laptop, `775b9ce2`), saved at [references/arena/slopes-2026-09-18.json](references/arena/slopes-2026-09-18.json),
written up in [../arenas.md](../arenas.md) *What slope the ground can have*.

| slope | 5° | 8–12° | 15° | 20° | 25° | 30° |
|---|---|---|---|---|---|---|
| ramp surface on navmesh | 1.00 | 0.95 | 0.90 | 0.85 | 0.75 | **0.05** |
| vehicle climbed, of the rise | 102% | 94–97% | 91% | 85% | 77% | 67% |

- **The vehicles are never the constraint.** A tank climbed 85%+ of the rise at every angle the navmesh supports and
  67–77% past it — the worst case for a player, since units grind at slopes they can see are drivable.
- **The ceiling is `atan(agent_max_climb / cell_size)`** = 26.6° today. Confirmed by moving the knob: at
  `agent_max_climb = 0.5` (predicting 45°), 30° coverage goes 0.05 → 0.65. **Not changing it** — it re-bakes every
  arena's navmesh, which is baked half-plus-mirror precisely to keep the bases fair, and would need the swap-bases
  control re-run and possibly move the sim baseline.
- **Author terrain at ≤ 20°**, and make every ramp lead onto a flat shelf, never a cliff: the navmesh is eroded back
  from a drop by the 2 m agent radius, so a ramp ending at a precipice has no mesh at the top to arrive on.

That is X4's gating question answered. Authoring the terrain itself is not started, and should follow X3 — there is
no point adding sunken lanes to a map whose only objective is at the centre.

### X5 — the arena review page: live at https://claude.ai/artifact/9RrjvWxhXZbu7ngnao5qn4

`make arena-page` → `build/arena-page/index.html`: one self-contained file (screenshots inlined) so it can be sent
anywhere. Round 3's review pages sat unseen for a day because nobody could open them.

**Framed as keep / fix / cut / "I'd rather play it first", per map — not "which is fun".** The lead answers a
concrete choice with a stated consequence far better than an open one, and disagreeing with a diagnosis is easier
than inventing one. Each card says what this stream thinks is wrong with that map. Six cards, not seven: Furnace
shares Foundry's card because they are the same shape with different hazards, and saying they are twins is more
useful than asking for two verdicts. **Boulevard leads** — its middle sees 64% of the field and its best firing
position can be approached unseen from only 12% of directions, so it dominates and cannot be flanked back.

**Two changes came from looking at the screenshots, which is the whole reason that step is in the contract.** The
match-runner overview prints every unit's name, health and current AI decision over the terrain — a developer view
that buries the one thing the page asks about — so the cards use the **skirmish camera**, what a player sees. And
each card carries the map's **plan** as well: cover orange, the longest clear shot red, open ground black.
Boulevard's plan is mostly black, which is the entire argument in one image, and it makes the verdict checkable
rather than asserted. That fix also surfaced a real bug: the plan's title printed `direct_route_exposure` (the
legacy 110 m test) beside a card quoting the 45 m measure — **two different numbers with the same name on one
page**. The plot now prints the share of the field the middle can see, which is what the page argues from.

A banner at the top, not a footnote, says **nobody has played these**: everything on the page is measured *shape*,
not measured play, and he is the only one who can supply the rest. That is also why "play it first" is offered as a
real answer — he has never driven any of them, which is the actual reason this has been open since round 5.

### After CP4: X2 re-derived, and it caught an error of mine

Merged `main` at the CP4 checkpoint and re-derived X2's exposure against the settled bands. **45 m (idle) was
right. My 60 m... was not what I had.** I had hand-set "posted" to **70 m** from "a cannon's full range", where the
catalog's median of `min(full range, sight radius)` over all 14 units is **60 m** — several units cannot *see* as
far as they can shoot, and I had not applied the sight cap that `covering_range()` applies to the idle figure. That
inflated every posting figure by about half.

| | before (70 m) | after (60 m) |
|---|---|---|
| boulevard posting gain | +0.107 | **+0.067 (2.0×)** |
| foundry posting gain | +0.127 | **+0.077 (1.7×)** |
| yard posting gain | +0.024 | **+0.017** |
| centre sees | 0.64 / 0.56 / 0.20 | **unchanged** |

**No ranking changed, and `centre_sees_share` cannot change** — it is pure geometry with no weapon in it. So both
claims the lead's page leads with survive any band move. The page was rescaled and republished (version 2).

**This was the fourth instance of one bug in my own output today:** a value derived from data, restated in a second
place, going stale silently. The others were the plot's `direct_route_exposure`, the `UNITS` collision, and the
110 m watcher reach. The fix is the same every time — **put it in one place and read it** — and `make arena-reach`
is that fix here.

### The 60-unit baselines are superseded (nav, 2026-09-18)

A layout has 52 spawn points and `Arena.spawn_spot` wraps with `slot % spots.size()`, so `NAV_UNITS=60` put **eight
pairs of hulls in eight positions** and those never moved. Eight of the stragglers in every 60-unit run of mine were
that, not congestion. **`nav-maze-30` is unaffected** (30 < 52). The direction survives — 33 of 60 arriving on yard
with nobody shooting is still the lead's complaint reproduced — but the numbers are marked superseded rather than
adjusted, because nav's before/after is on a fixed tree.

**What I should have done:** I treated the tail as more of the headline. A stable minority failing the same way is a
defect, not variance, and nav found it by asking *which* units failed rather than how many. Left in a baseline it
would have flattered every later fix by 8 units a run.

### X2's limitation, found by the lead (2026-09-18)

> *"Clearly crossing a bridge is risky, so you don't want a simple map with 2 sides connecting two bridges. There
> generally has to be some compelling reason to cross the bridge to take some advantageous ground."*

**Terrain creates risk, objectives create reason, neither works alone, and the prize goes where the risk is.** That
reframes my own headline. I measured *"covered routes cost a 1.0–1.1× detour on every map and nobody takes them"*
and read it as "flanking is cheap and unused". His framing says the cheapness is the symptom: **a route that is
cheap and leads nowhere worth going is not a tactical option, it is scenery.**

So **X2's analysis measures only half the thing.** It scores a route by what it *costs* — exposure, detour — and
never by what it *reaches*. That is why it reports that every arena already offers an affordable flank while the
game plays as a brawl: both statements are true and the metric cannot see the contradiction. Any round-7 version
needs a term for the value at the end of the route, and **X3 and the bridge/water work are one job** — measuring
either alone will under-read it.

### X9 / dynamic obstacles: keep the navmesh a startup snapshot (arena's ruling, 2026-09-18)

nav asked whether wrecks should become soft nav obstacles and whether anything will stop blocking mid-match.
**Answering it turned up a false premise that is written in both our briefs, including this one.**

**"Wrecks are on physics layer 4 on purpose, so they never block driving" is wrong.** Checked in the code, not
recalled:

- **Nothing in `game/` sets a collision layer** except `tank.tscn` (`collision_layer = 2`). `Arena._build_obstacles()`
  makes a plain `StaticBody3D` per obstacle, which defaults to **layer 1**.
- The `Obstacles` node carries the `navigation_source` group (`arena.tscn:64`), and the bake parses layer-1 shapes
  in that group. So **the `wreck` kit prop is baked into the navmesh and does block driving**, exactly like a
  container.
- Independent confirmation already in the suite: `ArenaFixture.inside_cover()` picks the widest collidable prop,
  which on **boneyard and yard is a wreck** (min dimension 3.2 m), and asserts a point at its centre is off the
  navmesh. `test_every_shipped_layout_connects_both_bases_and_the_centre` runs that for every layout and passes.
- **A destroyed vehicle leaves no body at all.** `game/theme/fx/fire_sites.gd:7`: *"Visual only: a site is just
  where a kill explosion happened. (Keeping a wreck MODEL there needs rules to leave the…)"*

Two different things share the name: the **kit prop** (static scenery, permanent cover, in the mesh) and a
**destroyed vehicle's husk** (does not exist). The layer-4 claim looks like a design that was discussed and never
built, and it has been repeated for at least two rounds.

**So both of nav's questions dissolve.** There is nothing to make "soft" — the props are already hard and already
baked — and the dynamic thing is not there to be avoided.

**The ruling, with the reason, so it is chosen rather than inherited: nothing should block drivable space
mid-match, and the navmesh stays a startup snapshot.**

1. Wrecks as permanent props already buy the tactical value (hard cover at 2.0 m, above the 1.3 m eye line) at zero
   dynamic cost.
2. The lead's approved destructible-cover design (X6) **deliberately never changes drivable space** — a stack
   collapses to a lower stack, the footprint stays. So X6 will not create a consumer for X9 either.
3. nav reached 100% arrival on a static mesh.
4. **The real blocker is fairness, not performance, and nobody had written it down.** The navmesh is baked from the
   southern half plus its 180° rotation *as a second region* precisely because a normal bake is not point-symmetric
   — an asymmetric bake gave the south base a 64% win rate (trip-up 21). **Any mid-match re-bake would have to
   reproduce that construction, or it silently reintroduces the bias**, and it would have to do so while units are
   standing on the mesh. That is the argument against dynamic obstacles, and it is much stronger than the cost of
   the bake.
5. `NavigationObstacle3D` (soft avoidance, no re-bake) sidesteps 4 — but it overlaps with nav's ORCA, which already
   steers around every living hull as of `7cce78af`.

**If round 7 revisits this, revisit it with `agent_max_climb`**: both are consequences of "the navmesh is a startup
snapshot baked in two mirrored halves", and both are cheap to change and expensive to get wrong.

### The mistake worth reading

I told the orchestrator CP2 was ready at `38c15f77` on the strength of 5/5 laptop tests. The full check came back
**1013 passed, 2 failed**. `Pathing.is_ready()` only answers *"does the world's navigation map have polygons"*, and
the previous test's arena is freed a frame or two before the server drops its regions — so it returns true against
the **old** map and every path is a straight line. Alone, my file passed. After `test_arena_layouts`, the maze
reported a 1.00× detour and a dead end with no walls.

**The general form is not about navmeshes.** The same flaw sat in `test_arena_kit`'s all-layouts connectivity test
— the one claiming *"every shipped layout connects both bases and the centre"*. It has **never failed**, and that is
the problem: it was proving the *previous* arena connected, once per layout. My maze tests only caught it because a
maze has a **known wrong answer** (a straight line) where a normal arena's wrong answer looks like a right one.
Fixed in `tests/support/arena_fixture.gd`; mutation-checked.

Third: the slope probe's navmesh answer was **wrong three times**, and each wrong version looked like a clean engine
limit — a ramp that was really a bridge (the tank drove under it), a ramp the tank drove around, and a goal point
inside the agent-radius erosion at the crest. Three geometries, three confident limits: 25°, 25°, 5°. The tell was
that *a tank unable to climb 10° is not believable* — a real one manages 30 — and the fix was to stop pathing to a
point and measure coverage along the ramp's own centreline, a quantity with no edges in it. Worth remembering that
the `agent_max_climb` knob test, run against the broken measure, came back **negative** and nearly retired the
hypothesis that turned out to be correct: **a good experiment against a broken instrument produces a confident wrong
answer.**

Second of the same shape: at a **110 m** watcher reach I had written up "flanking costs a 1.8–2.1× detour, cover is
priced out of reach". At the **45 m** a defender actually covers, the same maps price a flank at 1.0–1.1×. Same
geometry, same code, opposite conclusion — the finding lived entirely in one constant nobody had derived.

### Questions for the lead

1. **Which arena is fun** — still owed from round 5, and I now have measured shape to put beside the screenshots.
   The measurements say **boulevard and foundry are the two open ones**; his *"one big open brawl"* is most literally
   true of those. I would like to know whether that matches what he felt before I change either.
2. **Is the maze worth keeping visible?** It is a fixture and excluded from `--arena=random`, but it is a fast way
   to *see* whether movement has improved between rounds.

### Requests to other streams

- **combat:** read `Arena.objectives_of(Arena.active)` instead of `Match.CONTROL_CENTER` / `CONTROL_RADIUS`, and
  hold a per-objective owner instead of one scalar. Pure read-through; no existing arena changes. Blocks X3.
- ~~**combat:** ship `Engagement.covering_range()` with CP4~~ — **done.** `make arena-reach` now reads it from the
  catalog into `build/arena-reach.json` and `arena_report` reads that file, so nothing here restates it.

### Next

1. Green hash for `f8680e21` to the orchestrator.
2. `make remote T=arena-shots ARENAS=maze` and **look at them** — the maze has not been seen by a human yet.
3. Authoring terrain (X4's second half) — but it should follow X3, since sunken lanes do not help a map whose only
   objective is at the centre. X5 (the arena page the lead is owed) is the better unblocked next job.

