# Arenas: what makes a map tactical

> The arena stream's design doc (round 5, X2). Owner: arena (`game/arena/`, `arenas/`, `tools/make_arenas.py`,
> `mk/arena.mk`). Schema and API: contract **M2** in [workstreams.md](workstreams.md) and the header of
> `game/arena/arena.gd`. Doctrine's terrain needs: [doctrine.md](doctrine.md). Measurements for each shipped arena are
> at the end and are filled from runs, never from intent.

## Start here

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

## Shipped arenas

Pick one with `--arena=<name>`; `--arena=random` picks a seeded arena from `Arena.ROTATION` (yard, boulevard, pit,
boneyard), and `make skirmish` does that by default. **Invariants:** Arena owns the roll (launchers pass `random` through and read
`Arena.active["name"]` back, which is always the resolved name); the roll comes from `--seed`, so every launcher that
shows or records a seed passes it; and **the loader refuses `random`: only `Arena.resolve_name` understands it**. That
separation is what keeps "unknown names fail loudly" true while random stays the default. Don't make the loader
forgiving. Headless runs, tests and the sim baseline keep `foundry`
(`Arena.DEFAULT_LAYOUT`). Regenerate with `make arenas`, analyse with `make arena-report`, prove with
`make arena-series`, look with `make remote T=arena-shots`.

| Arena | Character | The fight it wants |
|---|---|---|
| **yard** (the Container Yard) | Six staggered container walls base to base, alleys that never line up, a walled plaza | Dense lanes and short sightlines: fights at corners and alley mouths; whoever scouts the next lane gets the ambush. Scouts, IFVs, burners |
| **boulevard** (the Boulevard) | Three avenues with low barricade medians, a roundabout of screens, walled service roads on the flanks | Long fire lanes broken by screens, kiosks and wrecks: spot first, cross the avenues under cover. Artillery and long guns |
| **pit** (the Pit) | A ring of stacked containers around the control point with four gates; open ground outside | A control-point brawl behind walls: hold a gate and own the approach; inside is knife range |
| **boneyard** (the Boneyard) | Wrecks and tipped containers at odd angles, no pattern of shape, symmetric in value | Local fights that read differently every match; small elements and spotting win |
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
contested field spent at |x| > 60 m, and not visible to the enemy. Raw runs: `build/arena-series-seeds*.json`.

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

