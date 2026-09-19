# Round 7 contract proposal: impassable ground, bridges, objectives, and the arena's shape

**From arena to the orchestrator, for review before any of it is built.** Three streams start against this rather
than after it. Nothing here is committed to `main` as behaviour yet — it is the shape of the change.

Two of the four items are **measured, not proposed**: the water mechanism and the navmesh slope ceiling both have
probes and saved results in this directory. The shape change is the one carrying real unknowns, and it is last on
purpose.

---

## A. Layout schema: `terrain` (new key) — arena owns, feel dresses, nav consumes

The lead: *"We need water or pits — these would be elements that units could not cross but they could still fire
over. Useful for setting up kill zones. i.e. we could have a map that required crossing some bridges to get to the
other side."*

**This is geometry, not a mechanic** ([water-carve-2026-09-19.json](water-carve-2026-09-19.json)): navigation bakes
from collision shapes in the `navigation_source` group, sight is a physics ray at 1.3 m. Ground absent from the
bake is unwalkable and carries nothing to block a ray.

```jsonc
"terrain": [
  {"kind": "water",  "footprint": [x, z, width, depth], "rotation_deg": 0},
  {"kind": "pit",    "footprint": [x, z, width, depth]},
  {"kind": "bridge", "footprint": [x, z, width, depth], "over": "<terrain name>"}
]
```

**What `Arena` builds from it** (all inside `game/arena/`, no other stream's code):

| Piece | Group | Layer | Why |
|---|---|---|---|
| Ground, **minus** every `water`/`pit` footprint, **plus** every `bridge` | `navigation_source` | 1 | the hole in the navmesh *is* the impassability |
| A **0.9 m rim** around each footprint, **cut where a bridge crosses** | *not* a navigation source | 1 | stops a hull, not an eye or a gun — `barricade` semantics, already in the kit |
| A deep floor under each footprint | *not* a navigation source | 1 | belt and braces: nothing leaves the world if a hull is ever shoved in |

**The rim cut is not optional.** The first bridge run in the probe reported a crossing blocked by its own safety
rail. A bridge is a hole in the water *and* a hole in the rim.

**What other streams need from it:**
- **feel** — `terrain.<kind>` visual slots, same pattern as `prop.<type>`. A `water` needs a surface at ~0.2 m
  below the rim and a pit needs a floor; both are cosmetic and neither is a navigation source. **Your cityscape
  block kit wants the same footprint rules:** a block that blocks driving goes in `navigation_source` on layer 1;
  a block that is only scenery goes in neither.
- **nav** — nothing. The mesh is still baked once at startup, still as one half plus its 180° mirror, and a
  carved hole is just mesh that was never there. Confirmed: the water run's route is genuinely unreachable and the
  bridge run's is 1.00× the straight line.
- **combat** — nothing, unless a pit should damage what falls in. The rim means nothing falls in, so I propose
  **no damage** and no new rule.

**Validation** (`Arena.validate()`): every footprint point-symmetric like everything else; a `bridge` must overlap
the terrain it names; and **a bridge's deck must be at least one navmesh corridor wide after the 2 m agent radius**
— the maze's tight gate is the precedent, 7 m physical gives 3 m drivable.

---

## B. Objectives off the centre line (X3) — arena owns the data, combat owns the read

**Landed and tested last round**, waiting only on combat's N7 read-through: `objectives: [{name, position, radius}]`
with `Arena.objectives_of()`, validated so off-centre objectives come in **mirrored pairs** (a lone one is owned by
whichever base is nearer). A layout with no `objectives` list reports exactly the single central zone `Match`
hard-codes, asserted for every shipped layout — **so combat's change cannot move any existing arena.**

What combat still owes: read `Arena.objectives_of(Arena.active)` instead of `Match.CONTROL_CENTER` /
`CONTROL_RADIUS`, and hold a per-objective owner instead of one scalar.

---

## C. The measurement problem, which is mine to solve and is the interesting one

The lead: *"Clearly crossing a bridge is risky, so you don't want a simple map with 2 sides connecting two bridges.
There generally has to be some compelling reason to cross the bridge to take some advantageous ground."*

**Terrain creates risk. Objectives create reason. Neither works alone, and the prize goes where the risk is.**

**My X2 metric scores a route by what it costs and never by what it reaches**, which is why it keeps reporting that
every arena already offers a cheap flank while the game plays as one brawl. *A route that is cheap and leads
nowhere worth going is scenery.* A round-7 metric needs a term for the value at the end of the route — roughly,
**what does this route let me reach, and what does reaching it deny the enemy?** — and until it has one, **A and B
cannot be evaluated separately**: a bridge measured without an objective beyond it will read as a pointless detour,
and an off-centre objective measured without terrain will read as a longer walk.

So **A, B and C are one job and should be briefed as one**, which I think is what you already concluded.

### The metric: classify routes by cost AND reward, in four quadrants

A single score would hide the thing the lead is describing. Two axes:

- **COST** — what X2 already measures: exposure along the route (at the catalog's idle/posted reaches) and the
  detour over the direct line.
- **REWARD** — new, and only computable now that objectives are data: **what does arriving here let me hold or
  deny?** For a route's far end, the share of the map's objective value it commands — being inside an objective's
  radius, or covering it at `Engagement.covering_range()` so the enemy cannot sit in it.

| | low reward | high reward |
|---|---|---|
| **low cost** | **scenery** — a cheap route to nowhere. *Every arena we ship is full of these, and X2 has been reporting them as flanks.* | **dominant** — free and decisive. A design bug: there is no decision to make |
| **high cost** | **trap** — risk with no prize | **the one we want** — *"a compelling reason to cross the bridge to take some advantageous ground"* |

**A map's quality is how much of its route space sits in the bottom-right quadrant**, and that is the number to
report per arena instead of today's exposure figure. It encodes the lead's principle directly: terrain supplies the
cost axis, objectives supply the reward axis, and **a map scoring zero in that quadrant has no tactical decisions in
it however much cover it owns.**

**Why the scoring rule makes this sharper than it would have been:** combat's N7 scores the **share** of objectives
held per tick, so a mirrored pair means **holding both scores at the old rate and holding one scores at half.**
Splitting the force is supposed to be tempting. So reward is not a property of one position — **it is a property of
a position given what the other side is doing**, and the pair is the mechanism that makes "advantageous ground"
mean something.

### What I need from combat, which I cannot build alone

Geometry can predict which quadrant a route is in. It cannot tell me whether anyone actually goes there — and the
whole failure of X2 was believing a prediction nobody checked against play. **Three match-side measures, all of
which combat already has the instruments for:**

1. **Where kills happen relative to objectives** — distance from each kill to the nearest objective zone. If fights
   still cluster at the map's centroid when the objectives are off-centre, the placement has not worked and no
   amount of geometry will say so.
2. **Unit-time on routes classified "high cost, high reward"** — do units actually take the route the map says is
   the interesting one? This is the direct falsification test for the quadrant model.
3. **Objective hold pattern over a match** — per side, how often it holds both / one / neither of a pair. **This is
   the test of whether splitting is really tempting**, and it is the one number that says whether the pair is a
   dilemma or a formality.

I will hand combat the route classification per arena as data (route polyline, cost, reward, quadrant) so its
probe can attribute unit-time without re-deriving my geometry.

### Placement rules for objectives, decided before the shape rather than after

The hexagon is **pinched to 210 m at the approaches** and objectives are now real, so the caveat I filed is live:

1. **No objective inside a base's approach funnel.** In the hexagon that is the pinch; in any shape it is the
   region whose approaches do not offer a genuine alternative.
2. **The test, and it is measurable rather than a feel:** an objective needs **at least two approach corridors
   that do not share their final leg**, with **materially different exposure**. One corridor is a funnel and
   identical exposure is a false choice — that is the boulevard failure restated as a rule, and I will add it to
   `make arena-report` so a layout cannot quietly acquire it.
3. **A mirrored pair should not be placed so that taking both is strictly easier than taking one** — otherwise the
   dilemma the scoring creates is decorative.

---

## D. The arena's shape — the only item with real unknowns

The lead: *"Our environment is very clearly a simple square… the arena could also take on octagon or hexagon-like
shapes."* Agreed with your call not to take the cheap option: a chamfered square reads as a square with its corners
cut, and the moment to change the shape is while the maps are being rebuilt anyway.

**What makes this a contract and not an art task — three couplings, all verified in code:**

1. **`Arena.validate()` pins `half_size` to `Match.ARENA_HALF_SIZE`** (`arena.gd:351`), with the reason in its own
   error text: *"the perimeter, radar, and fog are sized for it."* Three systems read that one number. A non-square
   arena needs a shape descriptor those three can consume, not just a different number.
2. **`RtsCamera`'s wall cutaway measures distance to the perimeter *square*** (`rts_camera.gd:231-241`,
   `perimeter_half()`). At the lead's 21° pitch the camera sits *past* the wall and this is what stops the wall
   filling his screen. **This is control's, and it is load-bearing at exactly the camera angle he chose.**
3. **The navmesh is baked as the southern half plus its 180° rotation** because a whole-arena bake is not
   point-symmetric — mirrored trips differed by up to 4.4 m and the south base won 64% of 140 matches. **An octagon
   and a hexagon both contain a 180° rotation, so the construction survives**; `filter_baking_aabb` and
   `SEAM_BORDER` are currently written for a rectangle and the **seam is the part needing care**.

**The contract, as control counter-proposed and the orchestrator endorsed** (better than my first version, which
offered a per-frame `perimeter_distance(point, heading)` call):

```gdscript
Arena.perimeter() -> PackedVector2Array   # the wall's INNER FACE, world x/z, counter-clockwise, convex
Arena.perimeter_edges() -> Array          # per edge: {from: Vector2, to: Vector2,
                                          #            wall_height_m: float, behind: "stands"|"gate"|"none"}
```

Read **once at load**, not per frame. control does the ray-vs-polygon crossing itself; its argument is that a
6–8-edge convex test costs the same order as today's square, so its per-frame budget does not change — and
**arena then owes it no per-frame performance guarantee.** That is the cleaner ownership line: **the shape is mine,
the maths is theirs**, and it survives the next camera change.

Two fields I would not have thought to provide, and both are real:
- **`wall_height_m` per edge** — the cutaway must clear the wall's *top* edge, and **that stops being one constant
  the moment the perimeter is chamfered or angled.**
- **`behind`** — the occlusion test judges sight lines against the *stands' profile*, and **a gate edge has no
  stands behind it.** A cut that assumes stands everywhere hides nothing at the gates and over-cuts elsewhere.

The layout still gains `"shape": {"kind": "square"|"octagon"|"hexagon", "half_size": 120}`; `square` stays the
default and **control keeps `perimeter_half()` as its fallback when a layout offers no polygon**, so nothing breaks
in the interval and the shape can land whenever it is ready rather than in lockstep. **I am no longer blocked on
this.**

### Which shape: HEXAGON, and the tactics agree with the tiling

feel measured buildability (hexagon: **exactly 6** of its 23.07 m grandstand modules per side, 0.65 m leftover;
octagon: 4 modules and a **3.9 m bespoke gap at all eight corners**). That is its call. **Which shape gives a
better fight is mine**, and I measured it rather than argued it — regular polygons at our 121 m apothem, a flat
side facing each base so the bases stay on a wall as they do today:

| shape | side | area | width at midfield | width at z = ±60 | centre-to-wall variation | corner |
|---|---|---|---|---|---|---|
| square | 242 m | 58,564 m² | 242 m | 242 m | **41.4%** | 90° |
| **hexagon** | 139.7 m | 50,718 m² | **279 m** | **210 m** | 15.5% | 120° |
| octagon | 100.2 m | 48,516 m² | 242 m | 222 m | **8.2%** | 135° |

Base-to-base is 2 × apothem = 242 m in all three, so nothing about the crossing changes.

**The hexagon is the shape that varies most, and variation is what the lead's complaint is about.** It is **wide in
the middle (279 m, 15% more lateral room than either alternative) and pinched at the approaches (210 m)** — an open
midfield for manoeuvre, and two natural funnels in front of the bases. That is the shape itself doing tactical
work: distinct places, without a single prop.

**The octagon is the most uniform arena available** — 8.2% variation in reach, width barely changing from midfield
to approach, 135° corners that shelter almost nothing. It is the closest thing to a featureless disc, and *"the
game is just this big open brawl"* is the complaint we are answering. **Its uniformity is the failure mode, not a
neutral property.**

**So: hexagon.** The tactical answer and the buildability answer point the same way, so there is no trade to
adjudicate — which is worth saying plainly, because a tiling convenience should not decide a tactical question and
here it does not have to.

**One caveat I will not bury:** the hexagon's pinch means **less room for a wide flank near a base** (210 m against
the square's 242 m). Under *the prize goes where the risk is* that is acceptable — even desirable, since it
concentrates the defender's job — **but only while objectives are off the base line.** If a future objective sits
near a base, that pinch turns into a funnel with no way round, which is the boulevard failure in a new shape. Worth
re-checking when B lands.

### It is a three-way seam, not two

**My polygon, feel's stands, control's maths.** The stands' profile (heights by distance out from the wall) is
**feel's venue** — control measures it today from `kit_stands` into `RtsCamera.STANDS_PROFILE`, and a hexagonal
arena needs hexagonally-arranged stands, so feel must hand that profile over as data beside the kit rather than
control inferring it.

**This constrains the edge count before any art exists.** feel's stand module is ~23 m, so an edge whose length is
not near a multiple of ~23 m leaves a part-module gap at every corner — multiplied by six or eight corners. **I
will compute candidate edge lengths for hexagon and octagon at our `half_size` and send them to feel before
choosing**, rather than picking a shape and asking them to make it fit.

---

## Order and what I will do next

**A → B+C → D**, as you set. Concretely:

1. **Rebuild Pit and Yard** — the two he kept — to the `centre_sees_share` target (<0.30), using A where it earns
   its place. *"All the maps need to be higher quality regardless."*
2. **A** as the primitive, with the probe promoted to a real test.
3. **C**, because B cannot be measured without it.
4. **D** — unblocked by control's fallback, but **send feel the candidate edge lengths before choosing a shape**,
   since their ~23 m stand module decides whether a hexagon or an octagon tiles without part-module corners.

**One question for the lead when he is next about, which I will not guess at:** *"the octagon of shipping
containers"* does not map unmistakably onto Pit or Yard in the data — Pit is a ring of containers around the
control point, Yard is container walls base to base. His buttons are the record (KEEP Pit, KEEP Yard), so nothing
is blocked; but if he meant a third thing by that phrase, the rebuild target changes.
