# Arenas: what makes a map tactical

> The arena stream's design doc (round 5, X2). Owner: arena (`game/arena/`, `arenas/`, `tools/make_arenas.py`,
> `mk/arena.mk`). Schema and API: contract **M2** in [workstreams.md](workstreams.md) and the header of
> `game/arena/arena.gd`. Doctrine's terrain needs: [doctrine.md](doctrine.md). Measurements for each shipped arena are
> at the end and are filled from runs, never from intent.

## Start here

> **Making or changing a map?** Read *Designing a new map: start here* below first — it carries the lead's verdict
> on all seven arenas, the one number that predicted it, and the two measures that will mislead you.
> **Changing the arena's SHAPE** (he wants an octagon or hexagon)? Read *Why the navmesh is baked as one half plus
> a mirror* as well. It is not an art task.


- **What maps are:** `arenas/<name>.json` layouts (schema v2: kit `props`, `spawn_zones`, `lanes`, `regions`), authored
  as half a layout plus its 180° mirror in `tools/make_arenas.py`, validated and built by `game/arena/arena.gd` from
  the physical truth of each prop in `game/arena/arena_kit.gd`.
- **Commands:** `make arenas` (regenerate), `make arena-report` (static measures and top-down plots, no Godot),
  `make arena-test`, `make arena-series` (fairness and fight shape; **counterbalance armies**), `make remote
  T=arena-shots` (pictures), `make arena-candidates` (parked generator). Play: `make skirmish ARENA=<name>`.
- **What we know (round 5):** all four new arenas are fair (paired base-swap margin, re-checked under Jolt); maps change
  hidden time, the long tail of hit ranges and how matches end, but not median hit range (39-43 m everywhere) and not
  much who wins; flank routes go unused while the control point funnels brains-only CPUs down the middle.
- **Read in order:** mechanics → vocabulary → rules of thumb → how we test → shipped arenas and their numbers →
  destructible cover design (approved, not built) → the generator → what to build next.
- **Invariants not to break:** everything that collides is point-symmetric; spawns stay 6 m clear of cover; the
  loader refuses unknown names including `random` (only `Arena.resolve_name` knows it); the random roll comes from
  `--seed`; `Arena.DEFAULT_LAYOUT` (foundry) keeps headless runs and the sim baseline stable.

## The lead's direction (2026-09-17)

> *"the maps are just too simple. We probably need a dedicated agent to formulate maps. I'm also not seeing the assets
> I asked for earlier like the big dystopian TV screen in the match or the shipping containers as re-usable components
> in the arena. As far as I know there's only one map right now and it's boring and doesn't provide any meaningful way
> to do tactics."*

## The mechanics a map has to work with (measured from the code, 2026-09-17)

A map can only create tactics out of mechanics that exist. These are the ones terrain touches:

| Mechanic | Number | What it means for a map |
|---|---|---|
| The field | 240 m square (`Match.ARENA_HALF_SIZE` 120), drivable to ±116 m | Fixed: perimeter, radar and fog are sized for it. Character comes from what's inside, not from size |
| Bases | Front rows at z = ±90, 13 × 4 slots across ±66 m | 180 m between front lines. A spawn zone must stay clear of cover (`Arena.SPAWN_CLEARANCE`, 6 m) |
| Sight | `Perception.EYE_HEIGHT` 1.3 m ray on the world layer; `sight_radius` 55–135 m by unit | **Anything taller than 1.3 m blocks sight.** Vision is a resource (round 4): a sightline break forces a scout forward |
| Direct fire | Muzzles 1.05–1.27 m; weapon ranges 14–170 m (most 30–90) | Anything taller than a muzzle stops shells. A ray under 1.3 m that clears a 0.9 m barricade still hits a hull behind it: low cover protects only what hugs it |
| Hulls | 1.4–1.6 m tall, 1.8–2.6 m wide, 2.8–4.6 m long; nav agent radius 2 m | A gap narrower than ~5 m is closed to vehicles. Wheeled units need turning room (`min_turn_radius_m`) |
| Arcs and splash | Artillery and mortars ignore cover on the way in | A map dense with walls favours artillery **if** someone spots for it |
| Suppression (L2) | Near-misses pin; `Match.is_beaten_zone` | An open crossing under fire is a real cost; cover on the far side makes a bound possible |
| Doctrine terrain | Cover features within 45 m: 0–1 open, 2–4 lanes, 5+ dense (`ElementSituation`) | Each container stack is one feature. The leader picks column/bounding overwatch in dense ground and line/wedge in the open, so a map's density directly changes formations |
| Bounding overwatch | `support_range_m` 85 m | Bounds need covered positions under 85 m apart, or the overwatch can't cover the mover |
| Cover map (AI) | `CoverMap`: features at or above eye height block sight; tactical points ring each feature at 3.5 and 7.5 m | Every cover feature creates places a brain can peek from. Isolated boxes are peek points; clusters are positions |

**Consequence (the honest version):** the world is flat, so there is no true hull-down and no high ground. "Low" cover
(a 0.9 m barricade) shapes where vehicles *drive* while leaving fire and sight open; "hard" cover (a container, a
wall) blocks all three. A "pit" or "overlook" has to be built from walls around a basin, not from elevation.

## The vocabulary

| Term | Definition in this game | Built from | Tactical effect we expect (and will measure) |
|---|---|---|---|
| **Lane** | A drivable corridor between the bases, bounded by hard cover on at least one side | Container rows, walls | Concentrates movement; frontage is limited to the lane width, so a column or wedge beats a line |
| **Chokepoint** | A place where a lane narrows below ~2 vehicle widths (≈ 10–14 m) | Two stacks with a gap, barricades | Whoever holds the far side of it with guns set wins the crossing; base-of-fire plus maneuver has a reason to exist |
| **Cover cluster** | ≥ 3 hard features within ~25 m, with drivable gaps | Container stacks, wrecks | A position: an element can halt in cover (herringbone), peek, and rotate damaged units back |
| **Sightline break** | Hard cover that interrupts a line longer than most sight radii (> 60 m) | A long wall, a 2-high stack, a screen plinth row | Denies the "two masses at max range" fight; spotting has to be earned by moving |
| **Open ground** | A region with no feature in 45 m | Nothing: deliberately left empty | Exposure: crossing it under fire costs suppression and hull. Fast units and artillery like it |
| **Flank route** | A lane away from the centre that reaches the enemy's side of a central position | Perimeter lanes, container alleys | Rewards splitting the force; must be *longer or more exposed* than the centre, or it's simply the better centre |
| **Centre** | The control point ring (radius 16 m) and what surrounds it | Whatever the arena's character asks for | The second win condition pulls both sides in; the centre's cover decides how that brawl plays |
| **Hard cover / low cover** | ≥ 1.3 m (blocks sight, fire, hulls) / < 1.05 m (blocks hulls only) | See `ArenaKit.PROPS` | Hard: positions. Low: channel movement without hiding anyone |
| **Overlook** | A position with sight over a region the enemy has to cross, reachable from cover | A gap in a wall line facing open ground | Overwatch: the set element in bounding overwatch sits here |

## Rules of thumb (to test, not to trust)

1. **Break long sightlines** between the bases: the mean eye-level view should sit well under sight radii (55-135 m). With sight to 135 m and ranges to 170 m,
   an unbroken 180 m axis is the "two masses" fight the lead saw.
2. **Every crossing of open ground has cover on the far side within bounding range** (≤ 85 m), or doctrine's bounds
   become a charge.
3. **Three routes, not one:** a centre and two flanks, with the flanks longer but more hidden. If one route is both
   shortest and safest, every match goes through it.
4. **Spawn zones are safe but not hidden forever:** no cover inside the zone (a clean start), a cover line 20–40 m in
   front of it so an army can form up out of the enemy's first volley.
5. **Density per character, not per map:** a yard wants dense lanes (5+ features within 45 m most places); a boulevard
   wants long open lanes with breaks; a pit wants open flanks and a dense centre.
6. **Symmetry of value, not only of shape:** everything that collides is point-symmetric (the validator enforces it);
   decoration isn't. Navigation is symmetric by construction (half bake + mirror), but the swap-bases control still
   runs on every arena.
7. **Props are cheap per kind, not per instance:** every kit kind is one MultiMesh (1-2 draws for a whole map, render,
   2026-09-17) with no real lights, so stacked containers and barricade runs are nearly free; unique lit props are what
   breaks M1 (≤ 350 draws, ≤ 6 real lights a frame; `_agents/streams/references/fx_tricks.md`). The boulevard, the
   busiest map, measured 8.7-10.7 ms GPU in a battle.
8. **Screens face their own half's base.** A screen faces -Z at rotation 0 and point symmetry turns its mirror around,
   so each player sees the fronts of the screens on their side and the backs of the far ones.

## How we test that a map delivers (X4)

Static measures run on the layout alone (fast, in `make test` and `make arena-report`):

| Measure | How | What good looks like |
|---|---|---|
| **View distance** | Eye-level rays from drivable points every 12 m, 16 directions, clipped at 170 m: mean, and share ≥ 120 m. (The single longest line was tried first and dropped: one diagonal through a 4 m gap survives even a 96-container yard, so it says nothing about the map) | Per character: yard ≈ half of foundry's 78 m; boulevard the longest of the new maps |
| **Exposure of a crossing** | Share of the navmesh route base-to-base that's visible from the enemy's covered positions | Centre route more exposed than flank routes |
| **Route count** | Distinct lanes (authored) and their length ratio to the shortest | ≥ 3 routes; flanks 1.1–1.4× the centre |
| **Terrain class along the routes** | Doctrine's own feature count at 10 m steps | The class the character promises (dense / lanes / open) |
| **Cover within bounding range** | Largest gap between cover clusters along each route | ≤ 85 m |

Dynamic measures come from seeded match series (the match runner with `--arena=`). **Counterbalance what isn't the
map.** Each seed gives each team its own army, and army strength decides most matches, so: swap bases per seed (the
per-arena fairness control), and when comparing arenas or factions, also swap armies or colours (combat's
`--swap-armies`/`--same-army`, as `faction_matrix.py` swaps colours), or a per-arena series measures the army draw as
much as the map. The same seeds on several arenas are the same army pairings repeated, not new samples.

| Measure | Source | What good looks like |
|---|---|---|
| **Fairness** | Swap-bases control: same seeds with `--swap-bases` | South vs north within noise of 50% |
| **Engagement range** | Distance at each hit | Differs by arena: the yard short, the boulevard long |
| **Flank use** | Share of unit-seconds inside flank lanes | > 0 in every arena; high where flanks are meant to matter |
| **Time hidden** | Share of unit-seconds not visible to any enemy | Higher in dense arenas |
| **Match shape** | Duration, first contact time, share decided by the control point | Different per arena, and never a stalemate by default |

## Designing a new map: start here (round 6's verdict, 2026-09-18)

**The lead judged all seven arenas and kept two.** His words: *"the only two maps worth keeping were the last one
and the one with the octagon of shipping containers. All the maps need to be higher quality regardless."*

| Arena | Share of the field its centre can see | His call |
|---|---|---|
| Boulevard | **0.64** | cut |
| Foundry (and Furnace) | **0.56** | cut |
| Boneyard | **0.40** | cut |
| Scrapyard | **0.29** | cut |
| **Pit** | 0.30 | **keep** |
| **Yard** | 0.20 | **keep** |

**He cut the four most open maps and kept two of the three least open — with those numbers on the page in front of
him and no way to sort by them.** He was not reading the metric; he arrived at it.

> ### So `centre_sees_share` is a DESIGN TARGET, not a description.
> **Aim below ~0.30 for any new map. Above ~0.50 the lead has already rejected it twice.**
> It is the single most predictive number this stream has, it is pure geometry (no weapons, no balance, nothing
> that can go stale when a band moves), and it costs one `make arena-report` to check before anyone models a prop.

**Nothing is being deleted.** The four are *do-not-invest*; Foundry stays `Arena.DEFAULT_LAYOUT` (every headless
run, the sim baseline and most tests use it) until the lead rules deliberately on that infrastructure change.

### The measure that will mislead you

`centre_sees_share` is the reliable one. **The exposure and route numbers below are only half a metric**, and the
lead's own words are what exposed it:

> *"Clearly crossing a bridge is risky, so you don't want a simple map with 2 sides connecting two bridges. There
> generally has to be some compelling reason to cross the bridge to take some advantageous ground."*

**Terrain creates risk; objectives create reason; neither works alone; the prize goes where the risk is.**

X2 scores a route by **what it costs** — exposure, detour — and never by **what it reaches**. That is why it
reports an affordable flank on every arena (1.0–1.1× detour) while the game plays as one brawl: *a route that is
cheap and leads nowhere worth going is not a tactical option, it is scenery.* Both statements are true and the
metric cannot see the contradiction. **Do not read "this map already offers cheap flanks" as "this map is fine."**
Any round-7 version needs a term for the value at the end of the route, and the objective work and the terrain work
are **one job** — measuring either alone under-reads it.

## Why the navmesh is baked as one half plus a mirror (read before changing the arena's SHAPE)

The lead wants an **octagonal or hexagonal arena**, and said plainly he does not know what this construction is. It
is load-bearing for fairness, so here it is in plain language.

**The problem.** Godot bakes a navigation mesh by carving walkable ground into polygons. That carving depends on
the order it walks the geometry, so **baking a perfectly symmetrical arena does not give you a symmetrical mesh**:
one side ends up with slightly different polygon edges from the other. Paths follow polygon edges, so the same trip
measured from the north and from the south came out **up to 4.4 m different** — and the south base won **64% of
140 bot matches**. A map that is fair on paper was not fair in play, and nothing in the layout was wrong.

**The fix** (`Arena._bake()`): bake **only the southern half** (z ≥ 0), then add **the same mesh rotated 180°** as a
second navigation region. Both halves are now the same polygons by construction, not by luck, so a route and its
mirror are identical to the millimetre. `SEAM_BORDER` (2.5 m) is extra bake margin past z = 0 so the agent radius
does not shrink the half-mesh where it meets its twin.

**What this means for a shape change.** An octagon and a hexagon both contain a 180° rotation, so **the
construction survives** — point symmetry is the only property it needs, and `Arena.validate()` already enforces
that for every layout. **The seam is the part needing care:** the half must be cut along a line through the centre
that the shape maps onto itself under 180°, and `filter_baking_aabb` plus `SEAM_BORDER` are currently written for
a rectangle. Do not "just change the perimeter" and re-bake whole — **that silently reintroduces the 64% bias, and
the swap-bases fairness control is the only thing that would catch it** ([verification.md](verification.md),
invariant 4). Run it on any shape change.

### Other things that assume the arena is a square

Found while answering the shape question. A shape change is **not an art task**:

- **`Arena.validate()` refuses any layout whose `half_size` is not `Match.ARENA_HALF_SIZE`** (`arena.gd:351`), with
  the reason in its own error text: *"the perimeter, radar, and fog are sized for it."* Three systems read that one
  number.
- **`RtsCamera` computes the wall cutaway from the distance to the perimeter *square*** (`rts_camera.gd:231-241`,
  `perimeter_half()`). At the lead's low 21° pitch the camera sits *past* the wall, and this is what stops the wall
  filling the screen. A non-square perimeter needs a distance-to-edge that matches the new shape, or the cutaway
  cuts in the wrong place — visibly, at exactly the camera angle he chose.

## Can this map host an ambush? (X2, round 6; `make arena-report`)

The lead wants ambush and flanking to be *possible*. That is a property of **sightlines, not of prop count**, and it
is measurable before anyone plays the map. `make arena-report` answers it per arena; `make arena-pytest` guards the
instrument itself.

### Two reaches, because they are two tactical situations

Every exposure number below is reported twice, and **the difference between them is the interesting figure**:

| Reach | Who | The question |
|---|---|---|
| **idle, 45 m** | a defender acting on its **own judgement** — `Engagement.covering_range()`, the median of `min(effective_range, sight_radius)` over all 14 units in four rosters | **The ambush question.** Can an element cross unpunished if the enemy has not specifically set up to cover this approach? |
| **posted, 60 m** | an element the commander has **spent a support-by-fire task on** — squad's `TankBrain._order_weapon` sets `long_shot: true` for an SBF task, lifting fire discipline to the weapon's full range | **The overwatch question.** Which positions are worth posting, and therefore which approaches a competent opponent can deny? |

A map where the two agree has **no positions worth posting**. A map where they diverge makes the defender choose and
lets the attacker read the choice. An approach denied at 45 m by anyone standing nearby is just bad terrain.

> **An approach that is safe at 45 m is not absolutely safe.** It is safe from crews using their own judgement. A
> commander who spends a support-by-fire task reaches further. That caveat travels with every "covered approach"
> number here, or it reads as a guarantee.

**Both numbers come from the catalog, not from this file.** `make arena-reach` runs `Engagement.covering_range()`
and writes `build/arena-reach.json`; `arena-report` reads it (`--reach idle=…,posted=…` still overrides). The
constants in `arena_report.py` are only a fallback, and keeping them as the source of truth is exactly what went
wrong once: **"posted" was hand-set to 70 m from "a cannon's full range", where the catalog's own median of
`min(full range, sight radius)` is 60 m** — several units cannot *see* as far as they can shoot. That 10 m
inflated every posting figure by about half. A number derived from data belongs in one place.

### What the shipping arenas measure (re-derived 2026-09-18 after CP4, at the catalog's 45 m / 60 m; static geometry, no match run)

| Arena | centre sees | longest sightline | crossing exposure idle → posted | **posting buys** | covered route | best overwatch: unseen approach |
|---|---|---|---|---|---|---|
| **boulevard** | **0.64** | 236 m | 0.070 → 0.137 | **+0.067 (2.0×)** | 0.069 at 1.00× | **0.12** |
| **foundry** / **furnace** | **0.56** | 236 m | 0.118 → 0.195 | **+0.077 (1.7×)** | 0.070 at 1.07× | 0.25 |
| boneyard | 0.40 | 216 m | 0.069 → 0.118 | +0.049 | 0.045 at 1.05× | 0.42 |
| scrapyard | 0.29 | 198 m | 0.081 → 0.120 | +0.039 | 0.060 at 1.06× | 0.33 |
| pit | 0.30 | 230 m | 0.092 → 0.127 | +0.035 | 0.073 at 1.02× | 0.50 |
| **yard** | **0.20** | 184 m | 0.052 → 0.069 | **+0.017** | 0.019 at 1.10× | 0.40 |
| *maze* (fixture) | *0.15* | *52 m* | *0.036 → 0.047* | *+0.011* | *0.021 at 1.02×* | *0.69* |

> **What CP4 moved, and what it could not.** Re-deriving at the catalog's real 60 m (from my hand-set 70 m) cut
> every posting figure by roughly a third and **changed no ranking**. `centre_sees_share` did not move at all and
> cannot: it is pure geometry with no weapon in it. So the two claims the lead's review page leads with —
> boulevard and foundry are the open maps, and boulevard's best position cannot be flanked back — survive any band
> change. The figures that *do* depend on the catalog now read it rather than restate it.

### What it says

1. **At realistic ranges, the crossing is not very exposed, and flanking buys almost nothing.** Exposure on the
   direct route is 0.05–0.12 idle, and the most covered route the map allows only takes it to 0.02–0.07 for a
   1.0–1.1× detour. **This reverses the picture at 110 m**, where flanking looked like it bought a lot and cost a
   1.8–2.1× detour (see *A number that changed when its assumption did*, below). The honest reading: at 45 m most of
   a 200 m crossing is simply out of anyone's reach, so terrain is not what decides whether you get across.
2. **Posting an element is what actually covers ground, and open maps reward it most.** On boulevard a
   support-by-fire task covers **2.0×** as much of the crossing as crews watching on their own, and on foundry
   **1.7×**; in the yard it buys almost nothing (+0.017), because the containers stop the extra 15 m from reaching
   anything. That is a concrete answer to "what should the support-by-fire button do for me" — it depends on the
   map, and today only the open ones pay for it.
3. **boulevard is the one to change.** The centre sees **64%** of the field, and its best overwatch position can be
   approached unseen from only **0.12** of directions — it dominates and cannot be flanked back. foundry is second
   on both counts. These are the two maps where the lead's *"one big open brawl"* is a property of the geometry.
4. **The centre is still the best place to stand on every arena.** Every top overwatch position sits within ~40 m of
   the centre. Combined with the control point being *at* the centre, a unit that flanks arrives late to the only
   thing worth holding. **Terrain is not what is missing — a reason to be anywhere else is**, which is what X3 tests.

### A number that changed when its assumption did

The first version of this table used a **110 m** watcher reach, inherited from `exposure()`. It reported that
flanking cost a **1.8–2.1× detour** on six of seven arenas and concluded that cover was priced out of reach. At the
45 m a defender actually covers, the same maps price a flank at **1.0–1.1×**. Same geometry, same code, opposite
conclusion — the whole finding lived in one constant nobody had derived. This is why `WATCHER_REACH_M` is named,
documented, overridable from the command line, and marked as the one thing CP4 changes.

### Other assumptions

- Defending positions are 4 m out from each piece of hard cover on the enemy half plus its front spawn row,
  **subsampled to 24** evenly by position so the pass stays a few seconds and does not shift when a prop is added
  elsewhere. Exposure is therefore optimistic in absolute terms: compare arenas with each other, not against 1.0.
- Overwatch reports **two different things** and they must not be conflated. `covers_*` is the share of the *whole*
  crossing a position denies — bounded by `2 × reach / route length`, so at 45 m over a 200 m crossing nothing can
  exceed ~0.45 however well placed. `commands_*` is, of the samples *inside* its reach, the share it can see: the
  geometry alone. Reading the first as "how good is this spot" scored four different arenas at exactly 0.48.

### Three bugs this instrument had, and the discipline that caught them

All three produced plausible-looking JSON. None survives checking the tool against maps whose character was already
written down in this file:

1. **`centre_sees_share` was 0.000 for foundry** — the most open arena in the game. Foundry has a crate on the exact
   centre and the observer stood *inside* it, so every ray was blocked at the first step. An eye has to be somewhere
   a vehicle could be (`standing_point`).
2. **The route optimiser and the report measured different things.** A* minimised the grid-marched exposure field
   while the report printed the independent box test, so the middle route came out *more* exposed than the direct
   one — arithmetically impossible for the quantity being optimised.
3. **Overwatch dominance was measuring route length.** Four arenas scored exactly 0.48 because at a 45 m reach no
   position can cover more than ~45% of a 200 m crossing. Split into `covers` and `commands`.

A fourth was cut rather than fixed: a `can_cross_unseen` boolean that came out **True for all eight arenas**. A
measure that never varies is not a measure. `tools/test_arena_report.py` now encodes the map rankings this file
documents, so the instrument cannot silently invert itself again.

## What slope the ground can have (X4, round 6; `make slope-probe`)

Everything in the arena kit is a box on a flat floor. Before authoring sunken lanes, raised platforms and ramps, the
brief says to find out what the engine survives. Measured, not guessed — laptop, commit `775b9ce2`, `make
slope-probe` (a ramp spanning the arena, leading onto a platform, in a real arena with the real bake and real
physics):

| Slope | Ramp surface on the navmesh | Vehicle climbed (of the rise) |
|---|---|---|
| 5° | 1.00 | 102% |
| 8–12° | 0.95 | 94–97% |
| 15° | 0.90 | 91% |
| **20°** | **0.85** | **85%** |
| 25° | 0.75 | 77% |
| **30°** | **0.05** | 67% |

**The navmesh is the constraint, never the vehicles.** A tank climbed 85% or more of the rise at every angle the
navmesh supports, and still managed 67–77% at angles it does not — vehicles will happily drive terrain that pathing
refuses to route them over, which is the worst of both worlds: units grind at a slope the player can see is
drivable.

**The ceiling is `atan(agent_max_climb / cell_size)`, and it is a knob.** The baker rasterises a slope into steps of
`cell_size × tan(angle)` and rejects a step taller than `agent_max_climb`. With today's `arena.tscn` (0.25 / 0.5)
that predicts **26.6°**, and the measured cliff sits exactly between 25° and 30°. Confirmed by moving the knob:
at `agent_max_climb = 0.5` the predicted ceiling is 45° and 30° coverage goes from **0.05 to 0.65**.

### What to do with that

- **Author terrain at 20° or less.** 0.85 coverage at 20° is already showing erosion; 15° and below is clean.
- **Do not raise `agent_max_climb` casually.** It re-bakes every arena's navmesh, and the navmesh is baked as a half
  plus its 180° mirror precisely to keep the two bases fair (trip-up 21). Any change to bake settings needs the
  swap-bases fairness control re-run, and may move the sim baseline (invariant 2).
- A ramp must lead **onto a flat shelf**, not to a cliff edge: the navmesh is eroded back from every drop by the 2 m
  agent radius, so a ramp that ends at a precipice has no mesh at the top to arrive on.

### How this number was wrong three times first

The vehicle answer was stable from the start. The navmesh answer was not, and every wrong version looked like a
clean engine limit:

1. **The ramp was a bridge.** A 1 m slab pitched at 10° has its far end 4 m up with open ground beneath. The tank
   drove *under* it and arrived at the goal's x/z at y = 0.3 — reported as "cannot climb above 5°".
2. **The tank drove around it.** Made solid but only 24 m wide, the vehicle went round the embankment on the flat.
   A vehicle that goes around is not a vehicle that cannot climb, and the two are identical in the output unless the
   geometry forbids one. The ramp spans the arena now.
3. **The goal sat in the erosion band.** Pathing to a point 1 m from the crest measured the agent-radius erosion
   along the drop edge, not the slope — and because the tolerance scaled with the rise, it got worse with angle and
   read as a slope limit. Three geometries gave three different "limits": 25°, 25°, then 5°.

The fix was to stop pathing to a point and **measure coverage along the ramp's own centreline** — a quantity with no
edges in it. The tell that something was wrong throughout: *a tank that cannot climb 10° is not believable*, since a
real one manages 30°. The check that settled it was moving `agent_max_climb` and predicting where the cliff would
land. **An instrument that cannot reproduce a known quantity is not measuring the thing it is named after** — and
note that this same knob test, run against the broken measure, came back *negative* and nearly retired the correct
hypothesis.

## The Maze: a test fixture, not a map (X1, round 6; contract N3, checkpoint CP2)

`arenas/maze.json` is the quasi-maze the lead asked for by name — *"we might even want a map that's a quasi maze just
for test purposes to ensure units can get through it."* It is **not a shipping map**, it is **nav's acceptance test**,
and both the layout's `note` and a test (`test_the_maze_is_a_fixture_and_never_ships`) say so. It is not in
`Arena.ROTATION`, so `--arena=random` never picks it; you reach it only with `--arena=maze`.

It carries `"fixture": true`, which is the field tools should ask rather than parsing the prose — `Arena.is_fixture()`
and `Arena.shipping_layout_names()` read it. **That flag exists because the maze broke the announcer's "every arena
the booth can name" test on the day it landed.** The fix was not to spend an ElevenLabs recording on a map nobody
plays; it was to give the announcer's test a way to tell a fixture from an arena. Anything that offers arenas to a
human wants `shipping_layout_names()`, not `layout_names()`.

It has no cover design, no balance and no art pass, and it should not get any. Its job is to answer one question —
**can a horde of 30+ vehicles get from its spawn zone to the far base through gaps it has to file through?** — and
every property below exists to keep that question hard and well-posed.

### The shape

Four container bands run across the field at **z = 74, 52, 30, 10**, each two containers high, out to the drivable
edge at x = ±116 so no band can be rounded. Point symmetry gives four more at z = −10, −30, −52, −74 with their gaps
mirrored to −x. **A gap at +x therefore has its mirror at −x, so crossing the arena is a serpentine:** every band
forces a lateral run to reach the next gap. The navmesh route base-to-base is **424 m against a 204 m crow flight
(2.08×)**.

| Band | Gaps (physical width) | Drivable corridor (physical − 2 × the 2 m agent radius) |
|---|---|---|
| z = 74 | x ≈ −56 (12 m), **x ≈ 11.5 (7 m)** | 7 m, **3 m** ← the tight gate |
| z = 52 | x ≈ −98 (12 m, the dead end), x ≈ −15 (10 m), x ≈ 65 (10 m) | 8 m, 6 m, 6 m |
| z = 30 | x ≈ −67 (10 m), x ≈ 29.5 (10 m) | 4 m, 5 m |
| z = 10 | x ≈ −32.5 (10 m), x ≈ 90.5 (10 m) | 5 m, 5 m |

**The tight gate is the point of the fixture.** 7 m of physical gap leaves a **3 m** drivable corridor — narrower
than two hulls side by side (the widest hull is 3.0 m, the common one 2.6 m), so a horde has to file through it. And
it is on the *shorter* of the two routes, so a horde will choose it. **Do not narrow it below ~6 m physical without
re-running `make nav-maze`:** under that the bake starts losing the corridor to rasterisation (`cell_size` 0.5), and a
disconnected navmesh reads as a nav bug for a day before anyone suspects the fixture.

**The dead end** is the pocket behind the z = 52 band's westmost gap (x ≈ −98), closed by band z = 30 to the south,
the arena edge to the west and a wall at x = −86 to the east. A unit that drives in has to come back out the way it
came: leaving it means backtracking north of z = 52, which `test_the_dead_end_has_no_back_door` asserts.

**The two routes are alternatives of different length**, and the honest way to measure that is the *whole* route —
spawn to the gate, then gate to the far base. Measured only from the gate mouths they read 350 m against 359 m and
look like one route with two mouths; measured whole they differ by ~40 m, because what a unit pays for choosing a
gate is mostly the leg to it. **The shared corridor between the bands is deliberate:** two squads sent through
different gates meet head-on in it, which is the peer-to-peer right-of-way case nav owes us. A maze of separate pipes
would never exercise it.

### Running it

```bash
make nav-maze                          # 30 units, 180 s -> build/nav-maze.json
make nav-maze UNITS=60 NAV_TIME=240    # a fuller horde
make nav-maze ARENA=yard OUT=nav-yard  # the same probe against a shipping arena, as a control
make remote T=nav-maze                 # on builder0 (the laptop is ~2.75x slower)
```

> **Ask for more units than the layout has spawn points and they land on top of each other.** A layout has 52
> (`Arena.spawn_spot` wraps with `slot % spots.size()`), so `NAV_UNITS=60` put eight pairs of hulls in eight
> positions, and those never moved at all — 8 phantom stragglers in every 60-unit run until nav fixed it on
> 2026-09-18. Any probe that spawns by slot has this; check N against the layout before reading its tail.

`tests/arena/maze_probe.gd` spawns N vehicles on the green side, orders each to the **180° mirror of its own spawn
point** (one shared goal would measure a pile-up at the destination, not the crossing), holds fire so a firefight
can't end the run early, and reports:

| Field | What it means |
|---|---|
| `arrived`, `arrived_fraction` | how many got within 8 m of their goal |
| `t50_s`, `t90_s`, `t100_s` | seconds until 50 / 90 / 100% had arrived (−1 = never) |
| `crawl_unit_seconds`, `crawl_share` | unit-seconds under 0.5 m/s **while still under way** |
| `stuck_events`, `stuck_units` | times a unit made no progress toward its goal for 3 s, and how many did |
| `off_navmesh` | units further than 3 m from the navmesh at the end (pushed off the drivable surface) |
| `worst` | the five that got least far, with their final distance |
| `progress_m`, `distance_m` | metres advanced vs metres of route they were given |

Progress is measured against **the best a unit has ever done**, not against the last tick: a unit shuffling back and
forth in a gap moves every tick and arrives never, and that is exactly the failure worth counting.

The probe deliberately measures **only positions over time**. nav can rewrite everything under the order — path
planning, avoidance, the control law — and the numbers keep meaning the same thing. It exits non-zero only when it
could not run at all (no arena, no navmesh); a bad result is a finding for nav, not a broken tool.

## Shipped arenas

Pick one with `--arena=<name>`; `--arena=random` picks a seeded arena from `Arena.ROTATION` (**yard, pit and
terminus** — narrowed in round 8 to the two the lead kept, boulevard and boneyard were CUT on the review page and
the rotation kept dealing them for a full round; **terminus is the one entry he has not ruled on**, added after its
render was reviewed so that he actually meets the cityscape he asked for twice), and `make skirmish` does that by
default. **Invariants:** Arena owns the roll (launchers pass `random` through and read
`Arena.active["name"]` back, which is always the resolved name); the roll comes from `--seed`, so every launcher that
shows or records a seed passes it; and **the loader refuses `random`: only `Arena.resolve_name` understands it**. That
separation is what keeps "unknown names fail loudly" true while random stays the default. Don't make the loader
forgiving. Headless runs, tests and the sim baseline keep `foundry`
(`Arena.DEFAULT_LAYOUT`). Regenerate with `make arenas`, analyse with `make arena-report`, prove with
`make arena-series`, look with `make remote T=arena-shots`.

| Arena | Character | The fight it wants |
|---|---|---|
| **yard** (the Container Yard) | Six staggered container walls base to base, alleys that never line up, a walled plaza | Dense lanes and short sightlines: fights at corners and alley mouths; whoever scouts the next lane gets the ambush. Scouts, IFVs, burners |
| **pit** (the Pit) | A ring of stacked containers around the control point with four gates; open ground outside | A control-point brawl behind walls: hold a gate and own the approach; inside is knife range |
| **terminus** (the Terminus) | Eight neon-edged city blocks on the 140 m hexagon, 20 m streets, a plaza at the crossroads, a ring road across each half | Sightlines end at the next corner: a flank is a street away and an ambush is a doorway. Scouts and IFVs own the grid; artillery has to be walked into it |
| boneyard (the Boneyard) | Wrecks and tipped containers at odd angles, no pattern of shape, symmetric in value | **CUT by the lead.** Loads by name; `random` never deals it |
| boulevard (the Boulevard) | Three avenues with low barricade medians, a roundabout of screens | **CUT by the lead.** Loads by name; `random` never deals it |
| foundry | Round 1's arena (v1), the default for headless runs | Mid-range with a little cover: the baseline the others are compared to |
| scrapyard | Round 2's dense layout (v1) | Short fights at corners |
| furnace | Foundry plus fire pits (v1) | Route around the pits |

### Static measures (`make arena-report`, 2026-09-17)

Views are eye-level rays from drivable points every 12 m in the contested field (|z| ≤ 84), 16 directions, clipped at
170 m. Doctrine terrain is the share of the field that `ElementSituation` would call dense today, and with touching
boxes merged into one piece of cover (the change suggested to ai).

| Arena | Pieces (low) | Mean view | Views ≥ 120 m | Dense today | Dense, merged |
|---|---|---|---|---|---|
| yard | 96 (4) | **44 m** | 6% | 95% | 86% |
| boneyard | 69 (6) | 61 m | 13% | 88% | 88% |
| pit | 54 (4) | 70 m | 17% | 56% | 45% |
| boulevard | 72 (28) | 72 m | 21% | 92% | 46% |
| scrapyard | 36 | 63 m | 13% | 50% | 50% |
| foundry | 19 | **78 m** | 22% | 16% | 16% |

### Dynamic measures (`make arena-series`, Condemned vs Condemned at 5200, elimination + control, 180 s)

Each seed is played twice, bases swapped. New arenas: seeds 1-18 (18 pairs, 36 matches); foundry: seeds 1-6.
Ranges are muzzle to impact of rounds that hit a vehicle. Flank share and hidden share are unit-seconds inside the
contested field spent at |x| > 60 m, and not visible to the enemy. Raw runs (240 matches, every field these numbers are computed from):
[`streams/references/arena_series_round5.json`](streams/references/arena_series_round5.json); recompute with
`tools/arena_series.py`'s `summarize` / `south_advantage` / `green_margin` over entries grouped by arena.

| Arena | South advantage (surviving share, mean ± SE) | Winner flips on swap | Median length | Decided by | Median / p90 hit range | Flank share | Hidden share |
|---|---|---|---|---|---|---|---|
| yard | −0.04 ± 0.05 | 2 / 18 | 114 s | control 24, elimination 12 | 40 / **64 m** | 4% | **58%** |
| boulevard | +0.01 ± 0.02 | 0 / 18 | **98 s** | elimination 26, control 10 | **43** / 73 m | 5% | 41% |
| pit | +0.03 ± 0.04 | 1 / 18 | 108 s | elimination 20, control 16 | 41 / **64 m** | **18%** | 56% |
| boneyard | −0.05 ± 0.03 | 2 / 18 | 108 s | elimination 19, control 16, time 1 | 41 / 68 m | 5% | 50% |
| foundry (6 pairs) | −0.00 ± 0.02 | 0 / 6 | 101 s | elimination 9, control 3 | 39 / 74 m | 14% | 36% |

**What this says (honestly):**
1. **Fairness:** no arena shows a base advantage distinguishable from zero (all within 1.4 standard errors; the
   largest, boneyard's −0.05, would favour the NORTH side). All four go in `Arena.ROTATION`. **Re-checked under Jolt
   physics** (main 8d975fa) on the boneyard, the closest margin: −0.04 ± 0.03 over the same 18 pairs (1 winner flip;
   median hit range 40 m, hidden 48%, flank 5%, all as before). Unchanged within noise, so the other three carry. The win rate is useless
   as the control here: each team's army is seeded separately and army strength decides the match; a swap flipped the
   winner in only 5 of 72 runs, in both directions. The paired surviving-share margin is the measure.
   *Side finding for combat:* with bases cancelled, **Green won only 25-28% on every new arena** (seeds 1-18). Careful
   with the weight of that: armies depend on seed and team, not arena, so it's **18 army pairings seen four times, not
   72 samples** (13 of 18 to Rust is p ≈ 0.05 by chance). Combat is running the controls (`--swap-armies`,
   `--same-army`, `make team-fairness`) to separate army luck from a structural team bias.
2. **The maps change how fights look far more than who wins.** For the same seed and bases, the winner was the same on
   every arena in 26 of 30 cases (seeds 1-6 on all five, seeds 7-18 on the four new ones); only the close seeds (9 and
   17) went different ways on different maps.
   Hidden time rises from 36% (foundry) to 58% (yard), the long tail of hit ranges shortens from 74 m to 64 m, and the
   pit pushes 18% of unit-time out around its ring. What they didn't change: **median hit range sits at 39-43 m on every
   map, foundry included**, so "two masses at max range" isn't a sightline problem the map can fix. It's ranges and
   brains (combat and ai this round).
3. **Flanks are barely used** outside the pit (4-5% on yard, boulevard and boneyard vs 14% on foundry): dense maps
   funnel both armies down the centre toward the control point. The routes exist (arena-report routes them); the CPU
   doesn't choose them. Rule of thumb 3 is delivered in geometry, not yet in behaviour. *How to read this (ai, 2026-09-17):*
   these runs used brains-only CPUs (no elements, no drills), which is what players get today, so 4-5% **describes the
   shipped game**. It is not evidence that "the maps don't get used": the element layer that would pick routes is
   switched off, and at 30 a side with a control point it currently loses to brains-only (32-16). ai and the
   orchestrator suspect the control point is the common cause: everything funnels to the objective. **Re-take flank
   share (and hidden time and hit ranges) if an element layer ships, or if the control point changes.** For ai: the lanes are annotated
   (`Arena.lanes_of`).
4. **Match shape does differ:** the boulevard is the fastest and most decisive (elimination 26 of 36); the yard is the
   control-point map (24 of 36), with the most hidden time and the shortest long shots, which is what its character
   promised. The pit sits between them (16 of 36 by control).
5. **Faction matchups (X6, weak evidence):** gangs (Green) vs syndicate (Rust), seeds 1-6 each way on bases, colours
   NOT counterbalanced. The syndicate won everywhere, as the round-4 faction matrix predicts. The gangs' surviving
   margin was least bad on the **boulevard** (−0.54, 4 of 12 wins) and the pit (−0.69, 3 of 12), worst in the **yard**
   (−0.84, 0 of 12) and the boneyard (−0.82, 2 of 12). That contradicts the brief's guess that a swarm wants lanes: in
   the yard's lanes the gangs feed in a few at a time, while open avenues let 44 cheap vehicles bring their numbers to
   bear at once, and they close to 30 m (median hit range on the boulevard 30 m, the shortest of any series). Treat it
   as a hypothesis to re-test with colours counterbalanced once combat's gangs changes land.
   **For whoever tunes the gangs next:** this sits alongside combat's round-5 findings (the gangs lose under every
   commander; Armor beats Swarm 16-0). A swarm's edge is numbers firing at once. Lanes and chokepoints take that away,
   so terrain built "for a swarm" is where the swarm does worst. Test gang changes on the yard and the boulevard both,
   and don't assume tight terrain helps them.

## Destructible cover: design (approved by the lead 2026-09-17, "Schedule it"; not this round)

Not in round 5 because the 30 Hz simulation tick refactor (combat) touches every per-tick assumption, and two
cross-stream changes in flight at once couldn't be told apart when something breaks. Written so another agent can pick
it up cold.

### What it is

**Container stacks lose levels under heavy fire. A stack never falls below one level.** A 3-high stack that blocks
sight at every height becomes 2-high, then 1-high, and stops there. That one rule is what makes it affordable:

| Property | Before a level falls | After | Why it matters |
|---|---|---|---|
| Blocks hulls and driving | yes | **yes, unchanged** (1 level is 2.59 m) | **Navigation never changes**: no rebake, no broken mirror symmetry, no frames waiting on the nav server (trip-up 57) |
| Blocks eye-level sight (1.3 m) and flat fire | yes | yes | A 1-high container still blocks both, so the *first* collapses change only arcs and tall-target lines |
| Height | 7.8 / 5.2 m | 5.2 / 2.6 m | What changes: artillery arcs clear it sooner, splash reaches over, and the stack stops hiding the ad screen or a tall target behind it |

So in the first version collapse is **mostly spectacle plus arc-fire tactics**. The tactically big version, where a
1-high container is **knocked open** into low cover (0.9 m, a hull stopper that no longer blocks sight), changes sight
and fire lines. It still never changes drivable space, because low cover blocks hulls too. Ship v1 (levels), measure,
then decide on v2 (open) with the lead.

### Rules

- **Which props:** `container_20` / `container_40` with `stack` ≥ 2 (v1); v2 adds the last level turning to low cover.
  Walls, crates, wrecks, barricades, screens and floodlights stay indestructible (layout-authored permanence is a
  design lever).
- **Hit points per level:** by kind in `ArenaKit.PROPS` (proposed: 600 for a 20 ft level, 900 for a 40 ft, about 3-5
  heavy-cannon hits). Only weapons with `penetration` ≥ a threshold or `splash_radius` > 0 damage props: machine guns
  and flamers don't, so "hose the container" isn't a strategy.
- **Symmetry:** layouts stay symmetric; damage is play. Nothing needs mirroring at runtime.
- **Determinism:** damage accumulates on the simulation tick from hit events only; a level falls on the tick its HP
  reaches zero. Prop levels join `Match.state_hash()`, or two builds that disagree about a collapse would hash the same.
- **Networking (paused):** prop levels are replicated state, one small int per destructible prop.

### Who owns which half

| Stream | Work |
|---|---|
| **combat** | Damage to props: route shell/beam/splash hits on a `StaticBody3D` prop into `Arena.damage_prop(index, amount, weapon)`; the penetration/splash threshold; `prop_level_lost(event)` K2-style signal `{tick, prop, type, position, levels_left, by}`; prop levels in `state_hash` |
| **arena** | `Arena.damage_prop` and per-prop HP from `ArenaKit.PROPS`; shrinking the collision box by one level on the tick (a `BoxShape3D` size change plus re-centring, no new nodes); `cover_features()` reporting current height and stack; the rule "never below 1" enforced and tested; `destructible` flag in layout v2 (default true for stacks ≥ 2) |
| **ai** | `CoverMap` is built once and memoizes line of sight: add `CoverMap.feature_changed(index)` that updates one feature's height and drops memo entries touching its broadphase cells; brains stop treating a fallen level as cover the same tick |
| **render** | Container MultiMesh already draws one instance per level: remove the top instance, play a fall and dust effect (pooled), leave a debris decal. No real light |
| **audio** | A metal-collapse cue on `prop_level_lost` |

### Cost per frame (estimates to verify with `make perf-scene`)

- Collision: one shape resize per fallen level (rare, event-driven). Zero steady-state cost.
- CoverMap: one feature update plus memo invalidation per event, O(cells touched).
- Render: one MultiMesh instance removed (a buffer update on that frame), one pooled effect. Nothing per frame.
- Simulation: a damage lookup only when a hit lands on a prop (hits on walls are already detected; they currently
  emit an empty `projectile_impact`).

### How to test that it matters

1. **Unit (arena):** a stack at 3 levels takes enough damage → collision height 5.18 m on that tick → 2.59 m later,
   never below; `cover_features` agrees; a navmesh path across the prop's footprint is unchanged before and after.
2. **Scenario (combat):** a cannon firing at a 2-high stack drops it to 1 level after N hits; a mortar that couldn't
   reach a unit behind a 3-high stack reaches it after the collapse.
3. **Determinism:** same seed twice → same collapse ticks and state hash; `make sim-baseline` moves once, on purpose.
4. **Does it change where units die?** A series (`make arena-series`, counterbalanced armies) with destructible on vs
   off on the yard (the densest stacks): compare the share of deaths within 8 m of a stack, the time units spend
   hidden, and match length. If deaths near stacks don't move, v1 is spectacle only: ship it for the look, and take v2
   (knock-open to low cover) to the lead with those numbers.

## Proposing layouts (stretch: `make arena-candidates`)

`tools/arena_generator.py` hill-climbs random symmetric kit layouts toward a character's measured targets, inside hard
constraints: pieces in the field and 6 m clear of spawns, no overlaps, the control ring drivable, bases, centre and
both flank strips in one drivable region. Candidates land in `build/arena-candidates/` with plots and an `index.html`;
**nothing ships until a human picks one**, copies it into `tools/make_arenas.py` with a name and a fight, and proves it
with `make arena-series`.

Targets are view distance (mean, share ≥ 120 m) plus **structure**: sight-blocking pieces per merged cover group.
The structure term exists because view distance alone was met by confetti: the first yard candidate hit 45 m and 6%
exactly with 84 scattered boxes and no lanes at all. With the term and an "extend a container end to end" move, the
candidates grow walls and L-shaped corners. They read as organic yards, not the hand-built yard's staggered lanes; the
generator proposes, the designer decides.

## What I'd build next (the arena worker's judgement, end of round 5)

In order, and why:
1. **Re-measure before building more maps.** Every behaviour number here was taken with brains-only CPUs and the
   centre control point on. If an element layer ships or the control point changes, re-run `make arena-series` (with
   counterbalanced armies) first: flank use and hidden time may change more from that than from any map.
2. **Objectives that pull play off the centre line.** The strongest effect measured in this round is the control
   point funnelling both armies down the middle, which leaves flank routes unused on three of four maps. Layout v2 can
   carry objectives: two mirrored side points, or a point that moves between regions. That's where maps get
   tactical leverage over behaviour, and it's a layout field plus combat's scoring, not new art.
3. **An arena menu with previews** (the lead: "Players pick"): control owns the menu; arena can export each layout's
   top-down plot (`make arena-report` already draws them) as a small thumbnail plus its `title` and `note`.
4. **Destructible cover v1** as designed above, after the 30 Hz tick settles.
5. **A long-range open map** as the contrast the rotation lacks (the boulevard is the longest at 72 m mean view;
   foundry is 78 m). Test there whether artillery and the Syndicate's range actually benefit; nothing measured yet says so.
6. **Elevation**, only if the lead wants it. The world is flat and every system (eye ray, cover map, navmesh bake,
   shells) assumes it. Real hull-down and overlooks need ramps, per-height cover and ballistics changes across combat,
   ai and arena, a round of its own.

**Matchup hypotheses to test** (colours and armies counterbalanced): the gangs' swarm, measured, did least badly on
the **boulevard** and worst in the **yard**, the opposite of the "swarm wants lanes" guess. My reading: numbers need
frontage. The Syndicate's range was assumed to want the boulevard, but median hit range was 30-43 m on every map in
every series, so no faction yet fights at the ranges where a map's long sightlines would favour it. Test once combat's
range work lands: syndicate vs condemned on boulevard vs yard; gangs vs law on the pit (the gates as chokepoints vs a
swarm).


## Streets are lanes (R4, round 10): what every declared lane must keep

**The lead, playing the Terminus (2026-09-20):** *"there streets are blocked with these shipping containers so
there's almost no passageway."* The round-8 layout put furniture IN the streets "so a 20 m street is a fight and
not a corridor"; measured, every Terminus lane was 0.00 m at its narrowest (a container on its centre line).

**The rule, asserted in `make check` by `tests/test_arena_lanes.gd` over `ArenaLanes` (`game/arena/arena_lanes.gd`):**

- **Width.** Along every declared lane (sampled each metre), the free span across it -- every collider counts,
  0.9 m barricades included, and the wall -- minus 2 × the live bake radius is at least **2 × the roster's widest
  hull**. The widest hull is READ from `Units`: it is **`syn_artillery` at 4.07 m**, not the War Rig's 3.32 m that
  contract R4's text quotes, so the bar is **8.14 m drivable, 12.14 m physical** at the 2.0 m bake. (The contract's
  principle, "the widest hull", is what the code implements; the number in its prose was the second-widest.)
- **Corners (C5).** At each lane's own bends (at their authored angle) and at every crossing of two lanes (certified
  for a right-angle turn, `ArenaLanes.JUNCTION_TURN_DEG`: sharper than that at a junction is a three-point turn),
  the clear disc around the vertex is at least `r_eff = r_a + R_min·(sec(Δψ/2) − 1)`, with `R_min` the rig's 12.0 m
  and `r_a` the width bar's half (6.07 m). A 90° junction needs 11.04 m.
- **Who is asserted.** Every layout except `ArenaLanes.REPORT_ONLY` (boneyard, boulevard, pit, yard: maps he has
  not complained about; their short lanes are listed below and in the arena brief's Status, not redesigned) and
  fixtures (the maze is single-file on purpose). **A new map is asserted by default** (terrain's bridges, R9).
- **The report.** `make arena-report` prints `LANE` and `CORNER` lines for every layout and exits 1 on an asserted
  short lane (`LANE_FAIL`/`CORNER_FAIL`); the round-9 corridor WATCH line stays a watch line for the open field.
  `tools/test_arena_lanes.py` pins the Python copy to the GDScript's Terminus numbers.
- **Authored chokepoints** live only OFF declared lanes and are named here. **The Terminus has none** since round
  10: its two (`avenue mouth` at (0, 42), `west crossing` at (−70, 0)) stood on streets and were dropped.

**The Terminus after R4** (`tools/make_arenas.py`, lanes and furniture): containers stand flush against block faces
parallel to the street (kerb position = face ± 1.22 m); lamps moved to the kerbs, set in so R3 can widen the box;
wrecks in lots; the form-up line and the avenue-mouth barricades are gone. Lanes declared: the avenue, west street,
**east street** (the west street's mirror, named by `mirror_name`), the ring road ×2, **plaza crossing west/east**.

| lane | round 9 | round 10 |
|---|---|---|
| the avenue | 0.00 m | 17.56 m physical, 13.56 drivable |
| west street / east street | 0.00 m | 16.40 m, 12.40 |
| the ring road ×2 | 0.00 m | 22.00 m, 18.00 (bounded by blocks only) |
| plaza crossing west / east | (not declared) | 22.00 m, 18.00 |

**It also READS passable (arena item 3, research C11; `LaneReadability`, `tests/test_arena_lane_readability.gd`).**
Per lane, the narrowest throat is projected to a 1920 x 1080 frame from his pose (with `clear_pose` and the
`BlockCutaway` applied, as the game does) and its ground-contact line traced back to the camera through the
colliders. At his default heading every Terminus throat is 100% visible, and the visible width minus the widest
hull's projected width is +329 to +472 px (the ring road, across the screen, is the narrowest on screen: 405-439 px
for a 22 m gap, against 614 px for the avenue's 17.56 m in depth: C11's foreshortening). The rule that got there:
**no furniture at either kerb of a street stretch bounded by buildings** -- on the near kerb it hides the throat from
his camera, and under 180° symmetry the far kerb's mirror is the other ring road's near kerb. The ring-road lamp at
(−35, 39.4) hid 23% of the throat this way; it and a 20 ft box moved to lots.

Every junction passes (narrowest: the plaza crossings meeting the ring road at (±12, ±30), 12.00 m against 11.04).
Lamps: the ring-road lamp is on the lot at (−55, 45) facing north across the road, the street lamp on the east
street's west kerb (62.4, 6); the plaza lamp (14, 14) was never on a lane.
Two round-8 authoring bugs went with the old list: three prop pairs authored on BOTH halves (so each mirror landed
on another authored prop: two containers in one place), and form-up containers at x = ±42 standing inside the
z = 62 blocks' footprints.

**The before/after pair at his pose:** `make remote T=terminus-streets` (the round-9 layout is frozen in
`tests/arena/before/terminus_round9.json`) then `make terminus-streets-page` → `build/terminus-streets/index.html`.

**The other maps (item 5, reported, not changed; same bar):**

| map | lanes short of the bar | where |
|---|---|---|
| yard | 7 of 7, each 0.00 m (a collider on the lane's line) | centre (0, 81), inner west (−34, 74), outer west (−67, 53), far west (−100, 37), and mirrors |
| pit | south gate 0.00 m; west gate corners 4.88 m clear vs 8.37 m | (0, 81); corners at (±70, ±40) |
| boneyard (cut) | 4 of 4, each 0.00 m | (4, 45), (−3, 61), (−68, 50), (67, 70) |
| boulevard (cut) | 6 of 6, each 0.00 m (the centre avenue since the ad screen's box became 7.8 × 2.0, R3) | (∓4, 31), (−60, 81), (60, 61), (−98, 66), (98, 31) |

**Readability on the other maps** (`LaneReadability` at his default heading, `make terminus-streets-page` →
`tests/arena/lane_read_probe.gd`): every yard lane, boneyard and boulevard lane and pit's south gate is "shut on its
line" (a collider on the lane: nothing to see through). **Pit's west gate is 18.06 m wide but only 16% of its
throat is visible from his camera** (margin −15 px against the widest hull): open, and it reads shut. Pit's flanks
read wide open (+777 / +959 px).

A 0.00 m reading means a collider stands on the lane's centre line. On a map whose lanes were drawn as AI hints
through its cover (yard's run between container walls) that can be the lane line's fault rather than the map's;
deciding which is a redesign question for a map he has complained about, and he has not.

## The deploy zone cannot move forward (round 10, measured for squad's pitch)

Squad's lateral floor at the turning envelope (`max(width + 2, diagonal + 0.30)`: 10.42 m for the bus) needs about
210 m of frontage for five 5-bus wedges; the zone is 150 m, so `ArmyLayout.plan` stepped a rank ~11 m AHEAD of the
zone's front edge (z = 86). Measured from the colliders, the free ground ahead of that edge (worst column across the
zone), on the working tree over main `69c681ac`:

| map | free ahead of z = 86 | what is in the way |
|---|---|---|
| yard | 5.0 m | form-up containers at z = 80 |
| pit | 5.0 m | form-up containers at z = 80 |
| terminus | 4.0 m | the z = 62 blocks' base-side faces at z = 82 (between z = 42 and 82 only the avenue and \|x\| > 50 are open) |
| crossing | 4.0 m | |
| sumps | 0.0 m | |
| foundry | 25.5 m | |

Backwards is capped by `DRIVABLE_LIMIT` (116) and the hexagon; sideways the floor is ±81.1 m at z = 102 against the
zone's ±75, so +12 m of frontage against ~60 m short. **The zone does not move** (the orchestrator's ruling).
This round `ArmyLayout` deploys at the round-9 width floor (squads packed, their first dressing turn clips: the
known cost); `tests/test_arena_deploy_zone.gd` asserts a 25-bus army on yard, pit and the Terminus stands inside its
zone and clear of every collider.

**Round 11 (arena + squad): a checkerboard-staggered deploy at the turning envelope.** Ranks offset half a pitch
across, as the bare-spawn grid now fills (`Match._spawn_cells`): hulls a full diagonal apart within a rank and
diagonal neighbours clear between ranks at a rank depth of ~0.87 × diagonal instead of 1 ×, which removes the
clipping first turn without leaving the zone. The containment test is the gate it must keep green.

## The Terminus, and the trap that kept the city blocks off every map (round 8)

feel built `block` (40 x 24 x 40, `prop.block`/CityBlock) in round 7 — chamfered corners, bevelled roof edges, neon
borders, three facade passes — and it was merged, correct and **placed by not one layout.** The lead asked twice for
sci-fi blocks and then asked what happened to them. Placing eight of them found out why.

### The navmesh baker silently ignores large boxes

Same arena, same obstacle type, same 3 m height, **footprint the only variable.** Distance from the box centre to
the nearest navmesh after baking (`make test FILTER=arena` will not tell you this; it was measured with a probe):

| footprint | 4 m | 8 m | 12 m | 18 m | 26 m | 40 m |
|---|---|---|---|---|---|---|
| distance to navmesh | **4.0 m** (a hole, correct) | 0.5 m | 0.5 m | 0.5 m | 0.5 m | 0.5 m |

0.5 m is the ground surface. **From 8 m upward the box produces no hole and no rooftop — it contributes nothing.**
The collision body is built correctly in every case (verified at runtime: right size, layer 1, not disabled,
parented under a node in `navigation_source`), and neither `border_size` nor `filter_baking_aabb` changes the
result at any value tried.

**Why nobody had hit it.** Every obstacle this project owned is thin on at least one axis — `wall` is 18 x 1.5,
`container_40` is 12.19 x 2.44, `crate` is 4.5 x 4.5, and a stack only grows upward. **The first object with a
genuinely large footprint was the city block**, and it failed on the first attempt to use it.

**Why it could not be shipped around.** Physics and navigation read the same body. A solid block would stop hulls
that the navmesh insists they can drive straight through — *"stuck behind basic barriers... moving back and
forth"*, manufactured on purpose, at the size of a building.

### The fix: tile a large footprint, do not hollow it

`Arena._obstacle_shapes()` builds one box when either horizontal axis is under `SOLID_FOOTPRINT_M` (6 m), and
otherwise **adjacent slabs `SHELL_THICKNESS` (4 m) deep covering the whole footprint.** Each slab is thin on one
axis, which is the only property the baker needs.

**A hollow shell of four walls was tried first and is wrong**: it carves the walls and leaves the interior
walkable — an enclosed, unreachable navmesh island inside every building, which the AI's position queries would
still see. Cover, radar and `arena_report.py` are untouched: they read the layout's single box, and only the
collision is built in pieces.

### What the map is, measured

A hexagon at the 140 m bound like the two he kept. Eight blocks, 20 m streets (16 m drivable after the 2 m agent
radius eats both kerbs), a 40 m plaza at the crossroads, a ring road across each half.

| | terminus | yard | pit |
|---|---|---|---|
| `centre_sees_share` (target < 0.30) | **0.13** | 0.20 | 0.30 |
| longest sightline | **196 m** | 216 m | 276 m |
| mean view | **50.2 m** | 54.3 m | 81.8 m |
| views over 120 m | **0.07** | 0.12 | 0.28 |
| `decision_spread` (target ~0.4) | **0.41** | 0.43 | 0.42 |
| drivable share | 0.44 | 0.51 | 0.55 |

**The geometry is the hexagon's, not a preference.** A 40 m block, a street and another 40 m block need 80 m plus
the street, and there are only 84 m from the centre line to where spawn clearance begins — **so two rows of blocks
per half do not fit at any street width**, which is why the plan is a cross rather than a grid.

**No alley is under 20 m, deliberately.** The maze proves 7 m physical gives 3 m drivable and single-file; this is
a map the lead plays, not a fixture, and with flow fields unstarted a near-impassable alley would be choosing to
reproduce his loudest complaint.

### It is the first shipping map that moves the stall measure

30 of 30 units cross it. `no_progress` **0.091** against yard 0.050, pit 0.028, boneyard 0.005 — and well under the
barrier fixture's 0.192. **Streets are corridors and corridors are where units queue**, so this is the honest test
bed for flow fields: ground where the number is not already at the floor, on a map he can actually play.

### What the Terminus actually looks like (round 8, `make remote T="arena-shots ARENAS=terminus"`)

**Looked at before it went into the rotation**, because every number above is a proxy for a question only a picture
answers. `build/screenshots/arena-terminus-{overview,skirmish}.png`.

**It reads as the venue.** At the player's pose the towers stand well above the hulls, the chamfered corners and
neon base trim catch light, and the stands, crowd and neon barrier sit behind them — the constraint the lead set
(*"match the theme and consistency of our gladiator environment"*) is met, and the street kit (containers,
barricades, wrecks, screens) is the same kit as every other arena, which is what does most of that work. The
streets read as streets from inside one, and the minimap reads as a city grid on a hexagon.

**Two things a human should still rule on, recorded rather than fixed:**

1. **It is dark.** Near-black towers lit by their windows: atmospheric and right for the genre, but the street
   surface is dimmer than yard's, and tactical legibility at a glance is a taste question, not a measurement.
2. **Street level is plain** — flat window grids where a tank actually drives, no balconies, signs or awnings.
   **This is feel's own open question and he has not answered it.** Shipping it plain is deliberate: a cityscape he
   can play beats a detailed one he has never seen, which is the entire lesson of round 8.

## Can a map hide the longest hull? (round 8) — **ANSWERED AND REPLACED in round 9 (A3)**

> **READ THIS FIRST.** Everything in this section below the next three paragraphs is the *old* measure, kept because
> it is the record of what was wrong and because it is still printed beside the new one for one round (lesson 49:
> report the split alongside, never instead of). **It is no longer how the game decides whether a hull is covered.**
>
> **The cliff was in the QUERY, not in the maps**, exactly as the lead's ruling said (game_design.md *Ruling: the War
> Rig stays at 14 m*). Catalogue row **A3** replaced centre-point registration with the fraction of a hull's own
> centreline chord that is occluded from a watcher: `Arena.cover_fraction(viewer, point, heading, length)`, built on
> directional summed-area tables in `game/arena/cover_tables.gd`. Two array lookups and a subtraction, **the same
> work at 2.93 m as at 14.0 m**, integer arithmetic throughout. `make arena-cover` prints it.
>
> **The falsifier the catalogue pre-registered is met.** Mean occluded chord fraction over the contested field,
> watcher on the far side, by hull length (laptop, round 9):
>
> | hull length | 2.93 m | 6 m | 8.62 m | 12 m | 12.19 m | 12.5 m | 14 m |
> |---|---|---|---|---|---|---|---|
> | **yard** | 0.32 | 0.29 | 0.29 | 0.29 | 0.29 | 0.29 | **0.29** |
> | **pit** | 0.31 | 0.38 | 0.34 | 0.36 | 0.36 | 0.36 | **0.36** |
> | **terminus** | 0.76 | 0.76 | 0.77 | 0.77 | 0.77 | 0.77 | **0.77** |
>
> **Flat.** Where the old measure put yard at 0.99 for a 12.19 m hull and **0.00** for a 12.5 m one, the new one puts
> a 14 m hull within 0.03 of a 12 m one. `tests/test_arena_cover_tables.gd` asserts that on every shipped map, and
> carries the old rule's cliff in the same file as the positive control (lesson 147: a treatment that cannot be
> distinguished from its control proves nothing).
>
> **What it costs, because combat's thresholds sit on it.** Two terms, reported apart by
> `CoverTables.worst_case_error()`: an **angular** term, `1 − cos(22.5°) ≈ 7.6%` of hull length, constant as a
> fraction; and a **grid** term of one 2 m cell, constant in **metres**. So the query is **least precise on the
> SHORTEST hull**, not the longest — the opposite of the intuition, and where a threshold will be tightest.
>
> **The standing rule below — do not add a long prop to yard or pit — still holds**, and now for a better reason
> than before: the maps never needed one.

### The old measure, for the record (round 8; `make arena-report` still prints it, labelled SUPERSEDED)


combat, 2026-09-19: the arena kit's longest prop is `container_40` at **12.19 m**, and the War Rig became **14.0 m**.
A hull longer than anything on the map has nowhere to hide — and **cover fails silently**: *"the rig still drives to
cover, still counts as near cover, and simply is not covered."*

Share of the contested field within `TERRAIN_RADIUS` (45 m) of a prop long enough. **Best case by construction** — a
box's screening length is its longest horizontal side, so this assumes the hull is parked along it and the shooter is
square to it. A hull that fails here cannot be hidden at all.

| hull length | 6 m | 7 m | **12.19 m** | **12.5 m** | 14 m |
|---|---|---|---|---|---|
| **yard** | 0.99 | 0.99 | **0.99** | **0.00** | **0.00** |
| **pit** | 0.85 | 0.48 | 0.46 | **0.00** | **0.00** |
| **terminus** | 0.98 | 0.95 | **0.91** | **0.91** | **0.91** |
| boneyard | 1.00 | 0.92 | 0.85 | 0.33 | 0.33 |
| foundry / scrapyard (v1) | — | — | fine | fine | **fine** |

**It is a STEP at 12.19 m, not a slope**, which is what makes it decision-useful: the rig's length is *binary* for
cover. combat's framing — the lead's question stops being *"how much balance is huge worth"* and becomes **"do you
want a truck that can take cover or one that cannot"**, which is answerable by looking.

**The regression arrived WITH the kit.** foundry and scrapyard handle a 14 m hull because the legacy v1 `wall` is
18 m; the kit that replaced it tops out at 12.19 m. **The two maps he kept are exactly the two v2 maps with no long
props**, so it is invisible precisely where it matters most. The general shape, worth more than this instance:
**replacing a prop set silently changed what the world can hide, and nothing in the layout schema records
"longest screening dimension" as a property anyone can check.** `make arena-report`'s `WATCH` line is that check,
and it prints on every run rather than on request.

### ⚠ Do NOT add a long prop to yard or pit before the lead rules

Not caution — the evidence is worth more than the fix, and both of us reached this independently:

1. **At 12 m the problem disappears with no map change at all**, so a map change now may be spent on a length that
   does not survive the week — and yard and pit are maps he **kept**.
2. **Adding a 14 m prop destroys the cleanest evidence he has.** The moment yard can hide a 14 m hull, the **0.00**
   that makes the choice obvious is gone.

If he rules 14 m: a jackknifed trailer, a rail car, or a container **wall** (rather than a stack — stacking adds
height, not length) reads as the same venue. feel sees it before it ships.

### What I ruled out about the baker, for whoever picks up C2

C2 (per-hull-class clearance from a medial-axis decomposition) is blocked on this, so the **eliminated** hypotheses
are worth as much as the finding. Each was tested on a layout built for it, with a positive control asserting the
probe arena was the one named — **the first version of this experiment silently fell back to `foundry` and reported
six clean, wrong rows** (too few spawn points; `Arena` loaded the default and said so only in a line I was not
reading).

**The finding, restated exactly:** a box whose footprint exceeds ~8 m on **both** horizontal axes contributes
**nothing** to the bake — no hole beneath it and no walkable surface on top. Measured as the distance from the box
centre to the nearest navmesh point after baking; 0.5 m is the ground surface, i.e. the floor under the box is
still walkable.

| footprint (square) | 4 m | 8 m | 12 m | 18 m | 26 m | 40 m |
|---|---|---|---|---|---|---|
| distance to navmesh | **4.0** | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 |

**Ruled out, each by direct test:**

1. **Height.** 3, 8, 12, 16, 20 and 24 m at a fixed 40 m footprint: no carve at any height. It is not the box
   exceeding the bake volume vertically.
2. **`filter_baking_aabb`.** Raised the y extent from 20 m to 45 m (verified applied by printing the AABB back):
   **no change**. Also not a z-extent issue — a block sitting entirely inside the southern half fails identically.
3. **`border_size`.** Set to 0.0 instead of `SEAM_BORDER` (2.5): **no change**.
4. **The collision body itself.** Printed at runtime: correct size, `collision_layer = 1`, `disabled = false`,
   parented under `Obstacles`, which **is** in the `navigation_source` group. The body is built correctly.
5. **Build order.** `_build_obstacles()` runs before `_bake()` in `_ready()`.
6. **Obstacle type / explicit size.** Reproduced with a legacy `wall` carrying an explicit `size` and with an
   unknown type carrying one, so it is not `OBSTACLE_SIZES` overriding the layout.

**Not yet tested, and where I would start:** whether Godot's geometry parser drops a shape by some size or
triangle-count criterion; whether `cell_size` 0.5 interacts with large flat spans; and whether the same box carves
when the bake is **not** the half-plus-mirror arrangement (every test above used the shipping bake path). **The
4 m slab tiling in `Arena._obstacle_shapes()` is a workaround, not an explanation**, and C2 should not assume the
baker behaves as documented until someone knows why this happens.

## Terrain maps: water, pits and bridges (terrain stream, round 10)

> Owner: terrain (`game/arena/arena_terrain.gd`, `game/theme/arena_kit/terrain/`, `tools/terrain_maps.py`,
> `tools/arena_terrain.py`, `tools/terrain_measure.py`, the `terrain-*` targets). The lead asked twice; the round-7
> mechanism existed with no art and no map, which is why he never saw it.

**The rule every map here is built to:** terrain makes risk, objectives make reason, the prize goes where the risk
is. Every terrain map carries a mirrored objective pair (R9), and each side's CONTESTED objective sits at the far
mouth of a crossing. `tools/terrain_maps.py` refuses to write a terrain map without one.

**Every terrain map has a DRY TWIN** (`<name>_dry.json`, `fixture: true`, identical but `terrain: []`): the null
arm of the paired series and the before-frame of every picture. Measure the map AND its twin; a number without its
twin's beside it does not say what the terrain did.

### What the mechanism gained in round 10

| Change | Why |
|---|---|
| A rim is cut only by a deck that crosses THAT edge | round 7 cut an edge wherever a deck overlapped its axis: a second river got a gap onto open water at the first one's bridge |
| **Bridge rails** (`rail_slabs`, 0.9 m, on the deck along every side over water) | without them a hull shoved sideways left the deck into the pan for the rest of the match |
| Rims and rails are **navigation sources** (R3) | the mesh reached 0.8 m past the rim's outer face, so a route along a bank scraped the rim |
| `MIN_DECK_M` = R4 bar + 2 × bake radius + 2 rails = **13.14 m** | round 7's 7 m was the maze's single-file gate; a test reads `Units` and fails when a wider hull lands (it caught 4.07 m) |
| `ArenaTerrain.build()` owns floor, rims, rails, pans, art | `Arena._build_terrain()` is a one-line delegate |
| `arena_report` sees terrain (`tools/arena_terrain.py` hook) | it routed straight through rivers: every figure on a river map was measured as if the river were floor |

The Python mirror of the rim/rail geometry is pinned: `tests/fixtures/terrain_golden.json` is reproduced by BOTH
`tests/test_terrain_golden.gd` and `tools/test_arena_terrain.py` (`make terrain-pytest`).

### The art (`arena.terrain`, `game/theme/arena_kit/terrain/`)

Five surface kinds, one draw each, no lights, no textures. **Water and pits are interior-mapped** (van Dongen 2008):
the floor is one plane at y = 0 that feel owns, so a real sunken channel would mean cutting it; instead a quad just
above the floor traces each view ray into the footprint's imaginary box and shades the wall, water line or pan it
hits. From his 21° camera the far bank's wall is in view, so the channel reads as cut into the arena. Water reflects
the venue's neon (fresnel, a horizon band, ripples on one animated scalar `flow`); a pit is a deep shaft with a red
glow at the bottom. Kerbs and rails are built from the SAME boxes as the colliders.

### Measured (laptop, python `arena_report` after CP2's instrument fixes, `terrain_measure`; static geometry, no match)

| map | `centre_sees` | decision spread | contested route, plain (green / rust) | R4 lanes |
|---|---|---|---|---|
| **crossing** | **0.29** | **0.55** | **185 m** / 112 m | west bridge + mirror: pass (13.0 m physical over the deck with rails) |
| crossing_dry | 0.46 | 0.30 | 148 m / 112 m | (fixture: reported only) |
| **sumps** (the brief's "Pits"; renamed so `ARENA=pits` never sits beside the kept `pit`) | **0.34** | 0.35 | 134 m / 94 m | catwalk, west causeway, far causeway + mirrors: pass |
| sumps_dry | 0.34 | 0.35 | 134 m / 94 m | (fixture) |

- **On the Crossing the river IS the decision:** spread 0.55 against the dry twin's 0.30, the contested route grows
  148 → 185 m, and the river halves what the middle sees (0.46 → 0.29).
- **On the Pits the static instruments cannot see the pits:** routes, spread and centre are identical wet and dry,
  because the chain does not lengthen the short route, it EXPOSES it (the causeways are open to the far lips). Whether
  that changes play is the paired series' question.
- **Two instrument findings, fixed by arena in CP2:** `standing_point` snapped 12 m, so the Pits' eye stood inside the
  pump house and read 0.00 (it is 0.48 before the corner stacks, 0.34 after); `decision_report` routed the enemy with
  green's exposure field, flipping the Crossing's spread 0.45 ↔ 0.03 on one alley.
- **Lanes are measured WITH the rims and rails** (`terrain_measure.lanes_with_terrain`, run by `check_terrain`, which
  refuses to write a failing map); `ArenaLanes` sees the carved water but not the rims or rails, so it over-reads a
  lane along a bank by up to 2.4 m. The lanes were found by a clearance-grown A* and simplified, not drawn by hand
  (the first hand-drawn ones clipped a block corner and two barricades 10 m apart).
- Pits' 0.34 sits between the Pit he kept (0.30) and Boneyard he cut (0.40). A kill-zone map is open across its pits
  by design; his eye decides.
