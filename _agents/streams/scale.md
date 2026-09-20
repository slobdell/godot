# Stream: scale (the roster at real relative scale — CP2 — then everything that was sized for a 4 m hull, then A3)

> Read `CLAUDE.md`, `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*),
> [game_design.md](../game_design.md) (*Round 9 direction* — the lead's words and the sizing rule — and *Ruling: the
> War Rig stays at 14 m*, *Factions*), [workstreams.md](../workstreams.md) (*Round 9: the seven streams*: contract
> **S1**, checkpoint **CP2**, the ownership carve-out), [research_catalog.md](../research_catalog.md) (rows **A3**,
> pathologies **P5** and **P6**, Part 1 §4), and [arenas.md](../arenas.md).
>
> **You own** all of arena's paths this round (`arenas/`, `game/arena/`, `tools/make_arenas.py`, `tools/arena_report.py`
> and its siblings, `mk/arena.mk`, `_agents/arenas.md`), plus **a carve-out from combat's C1**: the `hull_size` and
> `muzzle_height` **values** of every `Units.PROFILES` entry and the new optional `scale_reference` key in
> `game/units/units.gd`, and the three spawn-grid constants `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING` in
> `game/match/match.gd` (`SPAWN_JITTER_MAX_X/Z` and `SPAWN_SLOTS` are derived from them — if they must move, they move
> in the same commit with the derivation written beside them). New: `tools/roster_scale.py`, `mk/scale.mk`. combat
> reviews the `units.gd` / `match.gd` diff at merge and owns the files again afterwards.

## The lead's direction (2026-09-19, evening)

> *"We resized the semi trucks for the gang and this makes the game much cooler and awesome. We need to do
> proportional, real-world relative sizing for all of our vehicles. As an example, the bus-tanks and garbage trucks for
> the condemned definitely need resizing, so by extension I'm sure so do the rest."*

And the two rulings this rests on, both his:

> *"Yes the war rig stays at 14m, we can revisit that later if it's still an issue."* (2026-09-19)
>
> *"the intent for the semi trucks is that they're huge — we'll worry about evening up factions later."* (round 8)

**What he confirmed by playing:** the round-8 semi resize worked not because of the number but because a semi finally
*looked like a semi next to a car*. He wants that for every vehicle. He called this "minor"; it is the item he will
judge the round by, and it touches five owners' paths — which is why it has its own stream.

## The sizing rule (decided by the orchestrator; do not re-derive it, apply it)

From [game_design.md](../game_design.md) *Round 9 direction*:

1. **One factor `K` for the whole world, anchored by the War Rig at its ruled 14.0 m.** A real tractor + tanker
   trailer is ~18–21 m; fix the rig's `scale_reference.length_m` from a cited source and publish
   `Units.SCALE_K = 14.0 / that` **once**. Expect K ≈ 0.67–0.78.
2. **Every other unit's length = its real-world reference length × K.** The only judgment per unit is *which* real
   vehicle it is; [game_design.md](../game_design.md) *Factions* names most of them (prison-bus dozer, armored troop
   bus, garbage truck, crane carrier, power-utility truck, plow-nosed fire truck, rat rod, 1950s pickup, tow wrecker,
   rigid fuel tanker, up-armored pursuit sedan, 6×6 MRAP, 8×8 assault gun, rocket truck, riot truck, supercar,
   limousine, teardrop drone, missile wing). Each unit's `blurb` in `units.gd` says what it is. Cite a real length for
   each (manufacturer figure or a well-known type: a Blue Bird school bus, a Stryker MGS, a Cougar 6×6, a Peterbilt 379
   + 42 ft tanker…). Where the design names no real vehicle (the Syndicate hover platforms), choose the nearest real
   analogue by role, say so in the table, and keep it consistent within the faction.
3. **Width and height come from the approved mesh at that length** — `SizeLook.box_at_length(unit, length)`
   (`game/theme/fx/bench/size_look.gd:53`), the tool round 8 used for the rig. **`hull_size` IS the collider**
   (`units.gd:372`): a tidy round number that disagrees with the mesh means shells hitting empty air. Do not round.
4. **Balance is not a constraint.** Measure the consequences; never tune a size to fix a win rate.
5. **The lead sees the roster before it ships** — one side-by-side frame (backlog item 2). A look, not a number.

**Why rig-relative and not real metres** is recorded in game_design.md. The one open question — would he rather have
real metres (K = 1, rig 18–21 m)? — **is the orchestrator's to carry on the decisions page. Do not block on it.** If
he answers "real metres", it is one constant and a re-run of your table, which is the point of building it as a table.

## Where things stand

- **The roster today** (`game/units/units.gd` at `f49aa08a`): 21 units. Every hull except the War Rig
  (`[3.32, 5.24, 14.0]`, line 378) and the Resupply Tanker (`[3.39, 3.59, 7.0]`, line 442) is **2.8–5.0 m long** — the
  armored troop bus (`ifv`, 3.8 m), the 8×8 Assault Gun (4.6 m), the 6×6 Retired APC (4.2 m), the Rat Rod (2.8 m) all
  within two metres of each other. A real school bus is ~12 m; a Stryker ~7 m; a rat rod ~4.5 m.
- **Art already fits itself to length.** `DozerPart._fit_to_hull` (`game/theme/cyberpunk/dozer_part.gd:73`) scales
  every part of a unit uniformly by `hull_size[2] / FactionArt.hull_length(unit)`. **Changing `hull_size` is the whole
  visual change**; nothing in `game/theme/` needs editing for the resize. Round 8 proved it on the rig: 5.6 → 14.0 m,
  drawn 721 × 315 px at the lead's camera against a tank's 199 × 100 (builder0, `14bdb039`).
- **feel's round-8 roster-wide hitbox finding** ([archive/round8/feel.md](archive/round8/feel.md) line 199): **all 19
  art units' boxes disagree with their drawn meshes by more than 5% on some axis** (the rig was +1.7 w / +2.3 h before
  its fix; `law_suppressor` drawn 1.0 m taller than its box). Regenerating every box with `box_at_length` fixes this
  **by construction**, and the every-unit box-fill test feel owed lands with it (`test_the_semis_fill_their_boxes`,
  `feel-rig-check` branch `26e1f26a`, mutation-checked — take it, generalise it, or write your own).
- **Units with no art of their own:** `SizeLook.natural_size` returns zero when a unit has no `model_scene`
  (`size_look.gd:62`) and `box_at_length` then hands back today's `hull_size` unchanged. Find out which of the 21 that
  is (the Condemned's cyberpunk parts under `game/theme/cyberpunk/units/` vs the three faction folders under
  `game/theme/factions/*/parts/`). **Those units get a length from the rule and keep their width/height ratio from
  today's box, and the table says "no mesh" beside them.** Do not invent proportions.
- **Muzzle heights are a roster-wide invariant.** Rounds fly flat at muzzle height; `test_every_muzzle_clears_under_every_hull_top`
  (`tests/test_units_catalog.gd:46`) asserts every `muzzle_height ≤ min(hull_size[1]) − MUZZLE_CLEARANCE (0.1)`.
  Today the shortest hull is 1.4 m (`units.gd:293` says heights are held ≥ 1.4 m for this reason). If K shrinks the
  Rat Rod or the Skimmer below that, **every muzzle in the roster may have to come down** — and `muzzle_height` is
  yours this round for that reason. Re-derive each from the mesh at the new scale where it was measured from the mesh;
  keep the test green without weakening it.
- **The spawn grid was sized for a 2.6 × 4 m hull** (`game/match/match.gd:70–86`): 13 columns 11 m apart, 4 rows
  8 m apart, jitter ±3.5 / ±1.2 m, 52 slots, fourth row at z = 114 against `DRIVABLE_LIMIT` 116. Round 8 found
  *"length was the axis the spawn grid appeared to cap"* for the rig. Arena layouts carry **baked** spawn lists
  regenerated by `tools/make_arenas.py` (**the copy WON once** — Invariant 0's table in workstreams.md: baked spawn
  lists beat the constants). `Arena.spawn_spot` is consulted first (`match.gd:484`); the constants are the fallback.
  Change both in one commit or you have changed nothing on a real map.
- **Assembly and formation spacing already read `hull_size`** (`game/tactics/army_layout.gd:159, 295`): `deep_floor =
  longest + HULL_CLEAR_M`. That is squad's code; it will re-measure after CP2. Note anything you see it get wrong in
  *Requests to other streams*, do not edit it.
- **The navmesh is baked with ONE agent radius, 2.0 m** (`Arena._bake`, `game/arena/arena.gd:141`; consumed as
  `Movement.NAV_AGENT_RADIUS` in `game/ai/movement.gd:43`), for a footprint range that is about to grow from 5× to
  more. That is **P6** in the catalogue. The navmesh is baked as the southern half plus its 180° mirror
  ([arenas.md](../arenas.md) *Why the navmesh is baked as one half plus a mirror*) — **any bake change re-runs the
  swap-bases control** (trip-up 21: the south base once won 64%).
- **Cover is a step function at 12.19 m** (arena, round 8, `b5e52899`; [archive/round8/arena.md](archive/round8/arena.md)
  line 314): share of the field within 45 m of a prop long enough for the hull —

  | hull | 6 m | 7 m | **12.19 m** | **12.5 m** | 14 m |
  |---|---|---|---|---|---|
  | yard | 0.99 | 0.99 | 0.99 | **0.00** | 0.00 |
  | pit | 0.85 | 0.48 | 0.46 | **0.00** | 0.00 |
  | terminus | 0.98 | 0.95 | 0.91 | 0.91 | 0.91 |

  The cliff is `container_40`'s own length, **an artefact of registering cover by sampling the hull's centre point**
  ([research_catalog.md](../research_catalog.md) Part 1 §4). `make arena-report` prints a `WATCH` line for it
  (`tools/arena_report.py:186–195`: *"NOTHING on this map can hide the longest hull"*). **After the resize several
  more hulls cross 12.19 m on yard and pit** — the bus, the garbage truck, the tanker are candidates — so A3 stops
  being a rig-only fix and becomes the roster's. Static geometry; measured at `f49aa08a`'s tree by arena on the
  laptop (pure Python, machine-independent).
- **`gangs vs law` went 9/20 → 0/20 with the 14 m rig** (combat, round 8, [archive/round8/combat.md](archive/round8/combat.md)
  line 323): 20 counterbalanced matches across yard and pit, p ≈ 2×10⁻⁶, builder0. Shuffling evidenced against, splash
  evidenced against, "bigger target" surviving by elimination only. Combat's hypothesis: law is the suppression
  faction and a 14 m hull is a far easier thing to keep suppressed. **Unexplained, and not yours to fix** — yours to
  re-measure on the whole resized roster (stretch item 6), because the resize is the first experiment that changes
  every faction's size at once.
- **The sim baseline WILL move** with CP2 (collision boxes are the simulation). **You do not record it** (Invariant 2,
  workstreams.md): your green report says *"the sim baseline moves and is deliberately NOT recorded here"* and the
  orchestrator records it on `main` in the same session as the merge. On the laptop `sim-baseline` silently skips
  (glibc 2.39 has no line), so a green local check proves nothing about the hash — say so in Status rather than
  "sim-baseline passed".

## Backlog (in order)

Tests first for every item. Each green step is a commit; each report names the commit and the machine.

### 1. The reference table, derived and asserted (S1)

- Add the optional key `scale_reference: {"vehicle": String, "length_m": float, "source": String}` to the C1 schema
  comment in `units.gd` and to every unit. Add `Units.SCALE_K`, computed from `gang_tank`'s reference at 14.0
  (`SCALE_K = 14.0 / PROFILES["gang_tank"]["scale_reference"]["length_m"]`), **derived, not typed**.
- **Tests, written before the numbers change:**
  - every unit with a `scale_reference` has `hull_size[2] == snappedf(length_m × SCALE_K, 0.01)` (tolerance 0.01);
  - every unit with a mesh has `hull_size` equal to `SizeLook.box_at_length(unit, hull_size[2])` within a stated
    tolerance (this is feel's owed box-fill test made roster-wide; it must fail today on the 19 units feel listed —
    **mutation-check it: run it on the current numbers first and record the 19 failures as the "before"**);
  - the muzzle test stays as it is and stays green;
  - a test that the K derivation is used everywhere (rename the rig's reference and the table refuses; Invariant 0's
    "mutation-check the reader both directions").
- `make roster-scale` (`mk/scale.mk` → `tools/roster_scale.py`, reading `units.gd` **the way `arena_report` reads it,
  not a copy**): one row per unit — faction, id, reference vehicle, cited length, K, target length, today's box, the
  mesh's box at the target length (from a headless Godot pass that calls `box_at_length`), and a MISMATCH column.
  Print K and the rig's reference at the top of every run. Units with no mesh print "no mesh" in the box column.
- **Deliverable for the orchestrator before any value changes:** the table, in Status, so the reference choices can be
  read at a glance. Then apply.

### 2. Apply it, and render the frame the lead judges

- Write the new `hull_size` (and `muzzle_height` where the mesh moved it) for all 21 units. `_fit_to_hull` does the
  rest. Run the catalog tests; run `make lint test`.
- **The side-by-side frame:** extend `SizeLook` (or add a mode to it — it is feel's file; ask via Status, or build
  the lineup in your own `tools/`/`mk/scale.mk` target that drives `--size-look-lengths`' machinery) so **all 21
  vehicles stand in one line-up at one camera** — the lead's pose (`SizeLook.PITCH_DEG` 21°, 49 m, FOV 35 is what
  round 8 used; also give him a wider pose that fits 21 hulls), grouped by faction, the War Rig and the Condemned
  `tank` at both ends as references, each labelled. Render on builder0 at 1920×1080 (`make remote T=…`; needs a
  display, see `size-look`'s note in `mk/fx.mk:85` and trip-up 65 about stale frames). **Look at it yourself first**
  (verification.md: look at the screenshots you produce). Then **send the path to the orchestrator** — it goes on the
  lead's review page. **Do not announce CP2 until the frame has been sent.** The numbers need no approval; the look
  does.
- Also re-render `make facing-audit` for the whole roster: a unit that grows 2× can reveal a turret pivot or gun cut
  placed for the old roof (`_fit_to_hull` raises them by `fit`, but check).

### 3. The spawn grid, from the roster's largest hull

- **Test first, and derive the expectation from the data (lesson 3):** for every shipped arena and every faction at
  `Units.BASELINE_BUDGET` (and the gangs' swarm at `Army.MAX_ARMY_UNITS`), every spawned hull — jittered to
  `SPAWN_JITTER_MAX_*` — stands clear of every neighbour by the clearance the comment at `match.gd:70` promises and
  inside `Arena.contains()`. Write it against the roster's largest hull, not against 4 m. Run it on today's
  constants with the new roster: it should fail, and the failure is your "before".
- Fix `SLOT_X` / `SPAWN_ROWS` / `SPAWN_ROW_SPACING` (and the jitter bounds they derive, in the same commit with the
  derivation written down), **regenerate the baked spawn lists** with `tools/make_arenas.py` for every layout, and
  keep the front row at `BASE_Z` so spawn distance and pace are unchanged (or say by how much they changed and why).
  The fourth row must stay inside the arena for every shape (M4: the hexagon's inradius is 121 m; `DRIVABLE_LIMIT`
  116 is the inscribed bound).
- **Re-run the swap-bases fairness control** ([verification.md](../verification.md); `make team-fairness`, `make
  arena-series`), on builder0, and report win rates with N.

### 4. Clearance for the new roster (P6), then announce CP2

- Measure first: `make nav-maze` (30 units, head-on) and `make nav-fight` on yard on the resized roster, against the
  same runs on `main` before your change, same seeds, builder0. Report arrivals, stuck events and `blocked_*`
  buckets side by side. If the widest hulls now scrape or stall in the maze's gaps, that is the P6 finding made
  concrete — **report it with numbers before touching the bake.**
- If the bake must change (agent radius, or the maze's gap widths as a fixture), do it as its own commit, re-run the
  swap-bases control (the half-plus-mirror construction, [arenas.md](../arenas.md)), and update
  `Movement.NAV_AGENT_RADIUS`'s **comment** via a request to nav — the constant is nav's; a mirror that drifts is
  exactly what Invariant 0 forbids, so propose that nav read it from `Arena` instead.
- **Announce CP2** to the orchestrator (SendMessage *and* Status): the green commit hash on builder0 (`>> remote:
  make check exited 0` and the runner's `N passed, 0 failed`, unpiped), the statement *"the sim baseline moves and is
  deliberately NOT recorded here"*, the frame's path, the fairness numbers, and the list of every other stream's
  number that is now stale (spawn, cover, clearance, formation spacing, anything in pixels at his camera).

### 5. A3: hull-chord cover over directional summed-area tables

Catalogue row **A3** ([research_catalog.md](../research_catalog.md)), owner arena → you; combat owns the consumer.
**Replaces** centre-point cover registration (Invariant 0c: say so in the commit).

- **Positive control first, before any code:** reproduce the 12.19 m step on yard with `make arena-report` on the
  resized roster and record it — the treatment has engaged only if the step is gone afterwards (lesson 147's rule:
  prove the arm is distinguishable).
- Build, in `game/arena/`: for K = 8 canonical headings, a directional summed-area table of prop occlusion over the
  arena grid, and a query **`Arena.cover_fraction(from: Vector3, heading: float, hull_length: float, watcher: Vector3)
  -> float`** (name it in Status if you change the signature) returning the fraction of the hull chord occluded from
  the watcher — two lookups and a subtraction, independent of hull length, integer prefix sums (deterministic).
  Tables are built at arena setup from the same obstacle list the collision comes from (read, never copied).
- **Falsifier (pre-registered in the catalogue):** exposed hull fraction for units reporting `AT_COVER` drops below
  5% at every hull length 2.8–14.0 m, and yard's cover score for a 14 m hull rises from 0.00 to within 0.1 of its
  12 m value.
- **`tools/arena_report.py`'s `hull_cover` and its WATCH line change in the same commit** as the tables, or the
  report becomes a confident false alarm (the lead's ruling in game_design.md *Ruling: the War Rig stays at 14 m*).
  Keep the old point-sample number printed **beside** the new fraction for one round so the two can be compared
  (lesson 49: report the split alongside, never instead of).
- Hand combat the seam: a message naming the function, its units, and a one-line example, and where today's
  centre-point registration lives so combat can replace its call. Do not edit `game/combat/` or `game/ai/`.

### 6. Stretch: the 9/20 → 0/20 re-measured on the resized roster

Reproduce combat's round-8 series (per-matchup, counterbalanced, both maps, same seeds and time — their conditions
are in [archive/round8/combat.md](archive/round8/combat.md) and `streams/references/round8/combat/`) on the resized
roster. Report per matchup, with N and p. **Report, do not tune.** If it moved, say which sizes changed on both
sides; if it did not, say that the resize is not the variable.

## How to verify

- `make remote T=check` before every readiness claim, **read the wrapper's own `>> remote: make check exited <N>`
  line and the runner's `N passed, M failed`**, never a pipe's exit code (lesson 28). Iterate locally with
  `make lint test`; a filtered run never establishes readiness (lesson 45).
- `make roster-scale` (yours) prints K, the references, and every box against its mesh.
- The frames: `make remote T=…` for the line-up and `facing-audit`; open every PNG you produce and look at it.
- Fairness after any spawn or bake change: `make team-fairness`, `make arena-series` with `--swap-bases`, builder0,
  N stated.
- `make arena-report` before and after A3, with the WATCH line quoted.
- Every number: commit, machine (laptop is ~2.75× slower than builder0), workload, sample size.

## Don't touch

- `game/units/units.gd` beyond the carved-out keys (`hull_size`, `muzzle_height`, `scale_reference`, `SCALE_K`, and
  the schema comment): no costs, speeds, armor, weapons, turn rates. **No balance tuning of any kind.**
- `game/match/` beyond the three spawn constants and what they derive; `game/combat/`, `game/tank/`, `game/ai/`,
  `game/tactics/`, `game/control/`, `game/ui/`, `game/camera/`, `game/theme/` (feel's — the fit is automatic; if
  `SizeLook` needs a mode, ask feel via Status and build in your own paths meanwhile).
- No Meshy, no ElevenLabs, no new art. The Syndicate airship is feel's this round, not yours.
- `tests/baselines/sim_state_hash.txt` — the orchestrator records it.
- Never `pkill -f`; one `make remote` per worktree at a time (trip-ups 19, 66, 68).

## Waiting on the lead

- **The side-by-side look** (item 2): he taps the frame on the review page. Build everything else while he is away;
  CP2 announces once the frame has been *sent*, not once it has been *approved* — he removed balance and size as
  constraints, and the numbers are derived.
- **Rig-relative K vs real metres:** the orchestrator carries it. Not a block.

## Requests to other streams (fill in as they arise)

- **combat:** reviews the `units.gd` / `match.gd` diff at merge; owns A3's consumer.
- **squad:** formation and assembly spacing re-measured after CP2 (`army_layout.gd` reads `hull_size`).
- **nav:** `Movement.NAV_AGENT_RADIUS` mirrors the bake — propose it read `Arena`'s value.
- **feel:** a 21-unit line-up mode in `SizeLook`, if you cannot build it in your own paths.
- **control:** the camera, HUD, selection boxes and radar at his pose against the new sizes.

## Status

_Updated 2026-09-20 (overnight), worktree `godot-scale`, branch `stream/scale`._

### Decided overnight (the lead was asleep; the orchestrator ruled where a ruling was needed)

1. **CP2 lands as it is.** Every hull length is derived from a cited reference vehicle times one factor; nothing was
   tuned to make a number look better. The look was approved on his behalf from `lineup_pose.png`.
2. **K = 14.00 / 19.80 = 0.707071**, anchored on the War Rig at the 14.0 m he ruled, its reference a standard US
   tractor + 42 ft DOT-406 petroleum tanker. If he prefers real metres it is **one constant** — `Units.RIG_LENGTH_M`
   — plus `make roster-scale` and a rewrite of 21 values from the table.
3. **The Syndicate's hover platforms are referenced BY ROLE** (no road ancestry), consistently, stated on every row.
   **`law_tank` is a Centauro B1 8×8 (7.85 m), not a Stryker MGS (6.95 m)** — at 6.95 the Law's *tank* would be
   shorter than its own 6×6 MRAP.
4. **Three files outside this stream were edited**, each granted explicitly and each reviewed by its owner:
   `game/tank/tank.gd` (two silent mirrors that the resize could not land over), and one test each in control's and
   feel's files (size-dependent literals re-timed with the measurement beside them).
5. **A map-widening change (CP2d) was ruled and then withdrawn**, because the measurement behind it was mine and it
   was wrong. See *The maps' corridors vs the roster* below. **The maps are fine.**
6. **Still open for him, nothing blocked on it:** whether the Condemned `artillery` should carry its outriggers in
   its collider at 4.74 m wide (feel's call, round 10, and they have said so for the record), and whether a
   per-hull-class navmesh radius is wanted (nav's, catalogue C2).

### ⛔ CP2 IS BLOCKED ON A FAILURE I INTRODUCED — read this before merging anything

**`test_ai_player_orders::test_five_squads_ordered_in_quick_succession` fails on `4375a9ad`.**

```
every unit of every squad ends up on its own slot (expected 0, got 1)
MEASURE player_orders_rapid worst gap per squad
      { "Alpha": 3.2, "Bravo": 4.3, "Charlie": 104.9, "Delta": 5.0, "Echo": 4.9 }
```

**One unit 104.9 m from its slot; the other four squads sit at 3–5 m.** On `b7055602` — the resized roster with
the **old** spawn grid — the same test passed with Charlie at **4.5 m**. So it arrived between `b7055602` and the
tip. **Do not merge CP2 until this is understood.**

**Ruled out so far (by reading, not by running — the reproduction had not finished when work paused):**
- **`Arena.SPAWN_CLEARANCE` 6.0 → 4.0** is not it: its only consumers are `arena.gd` itself and two arena tests.
  It does not reach formation slots.
- **`Match.SPAWN_SLOTS` 52 → 57** is not it: its only consumer is `Doctrine.MAX_UNITS`, and this test loads no
  doctrine.
- **The spawn grid's geometry is not obviously it either**, and this is the awkward part: the test places its
  units at fixed coordinates (`Vector3(-90 + index * 6, 0, 95)`) **immediately after spawning them**, overriding
  the grid entirely. All 30 are `"tank"`, so "the widest hull" does not single Charlie out.
- `git show 07f92087 -- game/` contains **only** the spawn constants, the `SPAWN_CLEARANCE_MARGIN` refactor and
  `size_look.gd` (not in the simulation). Plus all ten arenas' baked spawn lists.

**The leading hypothesis, untested: CROSS-TEST COUPLING, not a simulation change.** Every commit in that range
added a new `tests/test_*.gd` file (`test_spawn_grid.gd`, `test_arena_cover_tables.gd`,
`test_arena_layout_keys.gd`), and `run_tests.gd` discovers files in **filesystem order, not alphabetical**. This
project has documented cross-test coupling before — control's facing test *"passed alone and failed in file
order"*. `test_spawn_grid.gd` in particular stands up **two full `Match` scenes with ~30-unit armies** and frees
them. **A test of mine may be leaving state behind.**

**THE EXACT NEXT STEP, in order:**
1. `--filter=ai_player_orders` **alone** (was running when work paused; result unknown).
   **Passes alone → cross-test coupling. Fails alone → a real simulation change, and bisect `b7055602..4375a9ad`.**
2. If it is coupling: run the full suite with my three new test files renamed so `run_tests.gd` cannot discover
   them (the prefix must stop being `test_`), one at a time, to find which one.
3. Fix, then `make lint` **clean on the final commit, with no other local Godot work in the same checkout** —
   the first lint of the night was corrupted exactly that way.
4. Then `make remote T=check` for the CP2 hash.

### Where it stands

**Backlog 1, 2, 3, 4 and 5 are complete. Stretch item 6 is not started.** CP2 is unblocked on the look and waits
only on the green hash: `make remote T=check` is running on `1a298f3d`, and the local `make lint` that lesson 157
requires is running beside it. **No commit is claimed green until both lines exist.**

### The plan, in the order it was worked

1. the reference table, derived and asserted (S1) — **done**, `b7055602`
2. apply it, and render the frame the lead judges — **numbers applied** in `b7055602`; **frame built, not yet rendered**
3. the spawn grid, from the roster's largest hull — **done**, committed with this Status
4. clearance for the new roster (P6), then announce CP2 — **waiting on a builder0 slot**
5. **A3** hull-chord cover over directional summed-area tables — **done**, built to combat's spec
6. stretch: the 9/20 → 0/20 re-measured — not started

### 1. The reference table (S1) — done

**K is fixed: `Units.SCALE_K` = 14.00 / 19.80 = 0.707071.** The anchor is `gang_tank` at the 14.0 m the lead ruled;
its reference is a standard US tractor + 42 ft DOT-406 petroleum tanker semi-trailer at **19.80 m** (65 ft, the
standard legal configuration), so the world is drawn at **70.7% of real size** — inside the 0.67–0.78 the
orchestrator expected. `SCALE_K` is *derived*, never typed: `Units._derive_scale_k()` reads the rig's
`scale_reference` and returns `NAN` loudly if it is ever removed, so every derived length fails rather than
defaulting to something plausible.

`make roster-scale` prints the whole table (reference vehicle, cited source, K, target length, box today, the
mesh's box, MISMATCH). Hull length in metres, today → new:

| faction | unit | today | new | reference vehicle |
|---|---|---|---|---|
| condemned | scout | 3.00 | **3.04** | Dakar-class rally-raid buggy (Prodrive Hunter T1+), 4.30 m |
| condemned | tank | 3.60 | **8.62** | Type D school bus, 40 ft (Blue Bird All American), 12.19 m — *the lead's own example* |
| condemned | ifv | 3.80 | **7.54** | Type C school / prisoner-transport bus, 35 ft, 10.67 m |
| condemned | artillery | 4.00 | **8.20** | four-axle all-terrain crane carrier (Liebherr LTM 1070-4.2), 11.60 m |
| condemned | lancer | 3.80 | **6.46** | utility line truck, 30 ft (International 4300 + Altec boom), 9.14 m |
| condemned | burner | 3.80 | **6.89** | pumper fire engine, 32 ft (Pierce Enforcer), 9.75 m |
| gangs | gang_scout | 2.80 | **2.93** | 1932 Ford Model B hot rod, 4.14 m |
| gangs | gang_ifv | 3.60 | **3.44** | 1955 Chevrolet 3100 half-ton pickup, 4.87 m |
| gangs | gang_tank | 14.00 | **14.00** | tractor + 42 ft DOT-406 tanker semi-trailer, 19.80 m — **the anchor** |
| gangs | gang_artillery | 4.20 | **6.89** | heavy-duty tow wrecker on a 6x4 chassis, 9.75 m |
| gangs | gang_support | 7.00 | **6.58** | rigid 3,000 gal fuel bowser (Freightliner M2 106), 9.30 m |
| law | law_scout | 3.40 | **3.80** | Ford Crown Victoria Police Interceptor, 5.38 m |
| law | law_ifv | 4.20 | **5.01** | Force Protection Cougar 6x6 MRAP, 7.08 m |
| law | law_tank | 4.60 | **5.55** | Centauro B1 8x8 assault gun (hull, gun excluded), 7.85 m |
| law | law_artillery | 4.40 | **4.95** | M142 HIMARS on an FMTV 6x6 chassis, 7.00 m |
| law | law_suppressor | 4.40 | **6.86** | riot-control water cannon (Wasserwerfer 10000, MAN 6x6), 9.70 m |
| syndicate | syn_scout | 3.20 | **4.04** | *by role*: wheeled recon vehicle, Fennek LGS, 5.71 m |
| syndicate | syn_ifv | 4.60 | **4.63** | *by role*: infantry fighting vehicle, CV90 hull, 6.55 m |
| syndicate | syn_tank | 5.00 | **5.44** | *by role*: main battle tank hull, Leopard 2A7, gun excluded, 7.70 m |
| syndicate | syn_artillery | 4.40 | **4.93** | *by role*: rocket artillery, M270 MLRS, 6.97 m |
| syndicate | syn_lancer | 4.40 | **4.04** | *by role*: sensor/designator vehicle, Fennek with the BAA mast, 5.71 m |

**The two judgment calls, both put to the orchestrator and both approved (2026-09-20):**
- **The Syndicate hover platforms have no road ancestry** — game_design.md names them by shape (teardrop, supercar,
  limousine), not by a vehicle they were converted from — so each is referenced to the real vehicle that fills the
  **same role**, consistently across the faction, and every row says so in its own `scale_reference.vehicle`.
- **`law_tank` is the Centauro B1 8x8 (7.85 m), not the Stryker MGS (6.95 m).** game_design.md says "Stryker-style",
  but at 6.95 m the Law's *tank* would be **shorter than its own Cougar 6x6 MRAP** (7.08 m). The blurb is "an 8x8
  with a real gun", which is what a Centauro is.

**The spread the lead asked for now exists.** Before: two vehicles over 5 m and nineteen between 2.8 and 5.0. After:
**2.93 m to 14.0 m with the middle filled in** — a school bus is 8.6 m next to a 2.9 m hot rod and a 14 m semi.

### 2. The numbers applied — done, and two mirrors had to go first

Widths and heights are now **the approved mesh's own proportions at the derived length** (`SizeLook.box_at_length`),
so `hull_size` is what is drawn. That discharges feel's round-8 roster-wide finding **by construction**.

**Recorded "before" (`9f864474`, laptop), so the treatment is known to be distinguishable (lesson 147):** running
the new tests against HEAD's numbers with the references in place failed **20 of 21** on length (only `gang_tank`,
the anchor, passed) and **17 of 19** on the box (only `gang_tank` and `gang_support`, which round 8 had already
fixed), by up to **106%** on an axis — `syn_artillery` was 2.60 m wide against its mesh's 3.64 m.

⚠ **I EDITED `game/tank/tank.gd`, which is not this stream's file** (granted retroactively by the orchestrator;
combat has seen the detail and does not object; combat reviews it at CP2). Two mirrors, both the silent kind, and
the resize could not land over either:

- **`Tank._apply_hull_size` returned early whenever a unit's box equalled `Units.PROFILES[DEFAULT].hull_size`.**
  `DEFAULT` *is* `"tank"`, so that branch fired for the Condemned tank and for nothing else: its collider came from
  `tank.tscn`'s authored `BoxShape3D` (2.4 x **1.6** x 3.6) while the catalog has said 2.4 x **2.4** x 3.6 since
  round 2. **The scene silently WON for the one unit `sim-baseline` fields** (lesson 137), and no edit to
  `hull_size` would have moved it — the lead's bus-tanks would simply not have resized.
- **The shared hull art was fitted against that same catalog entry rather than against the mesh it draws**
  (2.18 x 2.30 x 3.85 m). The moment the Condemned tank stopped being 3.6 m long, every unit without its own art
  would have been drawn at the wrong size, in silence. Measured on the reverted code: a 6.89 m box drew **2.88 m**.

**Consequence to expect, named so nobody re-derives it: the Condemned tank's collider grows 0.8 m in height.** That
is a correctness fix, not a tune, and it is a real combat change (a taller target). combat has already flagged that
`scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` reads that hull's hit distribution with six hits of
margin, and **expects it to move** — so that when it does, nobody attributes it to A2 or A7.

Both mirrors now have a regression test, each mutation-checked by surgically restoring the old behaviour and
watching it go red: `test_the_default_units_collider_comes_from_the_catalog_not_from_the_scene` and
`test_a_unit_wearing_the_shared_hull_art_is_drawn_at_its_own_box` (`tests/test_units_scale.gd`).

**Muzzles came down roster-wide.** The shortest hull is now the Rat Rod's own mesh at **1.24 m** instead of a
hand-held 1.40 m floor, so the ceiling (`MUZZLE_CLEARANCE` under the shortest hull) fell **1.30 → 1.14 m** and the
**18 muzzles above it came down to it**. Rounds fly flat at muzzle height, so this is a real ballistic change and
it is pre-registered, not incidental.

**THE SIM BASELINE MOVES and is deliberately NOT recorded here** (Invariant 2). On the laptop `sim-baseline`
silently skips — glibc 2.39 has no line — so a green local check proves nothing about the hash.

### 2b. The frame the lead judges — RENDERED AND SENT

`make roster-lineup` (builder0, 1920x1080, commit `0e809a09`). Three frames in `build/roster-lineup/`:

| frame | what it answers |
|---|---|
| **`lineup_pose.png`** | **HIS pose** (21°, 49 m, FOV 35 — the same one round 8 shot the rig at) over the size spread. The one to look at. |
| `lineup_factions.png` | four rows, one per faction, each sorted by length: is each faction's roster sensible? |
| `lineup_row.png` | all 21 in one row, the Condemned tank and the War Rig as the bookends the round is anchored on |

**What `lineup_pose.png` shows, left to right:** Rat Rod **2.9 m**, Pursuit Cruiser 3.8, Gun Truck 3.4, Railgun
Platform 5.4, Condemned Tank **8.6**, War Rig **14.0**. A semi looks like a semi next to a car, and the bus-tank he
named reads as a bus rather than a dozer.

**On screen at his camera, against round 8's numbers:** the rig **734 × 279 px**, the Condemned tank **281 × 135**.
Round 8 measured that tank at **199 × 100** — so it grew by half again while the rig kept its dominance. (Round 8's
rig was 721 × 315 at a slightly different framing; the rig's own box did not change.)

**Two cosmetic defects, named rather than hidden:** `lineup_pose.png` clips the Rat Rod slightly at the left edge,
and `lineup_factions.png` clips the Condemned row at both edges — the near row is the widest at 55.7 m and the fit
was computed on the focus plane rather than the near row's, so perspective pushes it past the frame. Labels still
overlap in the two dense back rows. One more render fixes all three; not queued, because the frames are usable and
CP2 is gated on the frame being *sent*.

**It took three renders, and the first two were the interesting part.** Both were unusable: the HUD covered a third
of the image and order beams washed out the labels. The cause was not the layout — `_quieten()` read `Main.hud` and
tested `hud is CanvasItem`, and **`Hud extends CanvasLayer`, which is not a CanvasItem**, so the test was quietly
false and nothing was hidden. It now finds every CanvasLayer by class and hides both marker drawers (feel's
`FxWorld.order_feedback` and control's `SelectionMarkers`), and prints
`SIZE_LOOK_QUIET 1 canvas layers, 2 marker layers` so a future silent no is visible. **A capability test that
silently means "no" is the same shape as every mirror this stream found this round.**

### 3. The spawn grid — done, and it needed less than the brief expected

**Test first, and the first thing the tests established is what the grid actually has to hold.** `ArmyLayout.deploy()`
re-lays every unit by its own hull size at the end of `Match.load_doctrine`, **synchronously, before any physics
step**, so a doctrine army never stands on this grid. What stays here is what `Match.spawn_tank` puts here and
leaves: network players and legacy bots, driving `Units.DEFAULT`. That was combat's round-8 finding, carried as a
comment; it is now a guard —
`test_a_doctrine_army_is_never_left_standing_on_the_grid` spawns a real gangs and a real Condemned army at
`Units.BASELINE_BUDGET` and asserts no two hulls overlap at tick 0.

**What changed:** `Units.DEFAULT` went 3.6 → 8.62 m, longer than the old 8 m rows, and combat's existing
`test_the_spawn_grid_holds_the_unit_a_bare_spawn_drives` went red on it. There is nowhere deeper to go (the back
row was already at z = 114 against `DRIVABLE_LIMIT` 116), so the grid became **shallower and wider**:

| | before | after |
|---|---|---|
| `SLOT_X` | 13 columns, 11 m pitch, ±66 m | **19 columns, 7.5 m pitch, ±67.5 m** |
| `SPAWN_ROWS` × `SPAWN_ROW_SPACING` | 4 × 8.0 m (z = 90, 98, 106, 114) | **3 × 12.0 m (z = 90, 102, 114)** |
| `SPAWN_SLOTS` | 52 | **57** (`Army.MAX_ARMY_UNITS` is 45) |
| jitter x / z | ±3.5 / ±1.2 m | **±1.5 / ±0.6 m** |

**The front row stays at `BASE_Z` = 90 and the back row stays at z = 114, so spawn distance, depth and pace are
unchanged.** The jitter fell out of the pitch: column pitch and row spacing, each minus the bare-spawn hull
(2.40 × 8.62 m) and minus squad's `ArmyLayout.HULL_CLEAR_M` (2.0), halved. A doctrine army's scatter is unaffected
(`ArmyLayout` lays it out itself).

**Why ±67.5 and not wider:** `make arenas` **refused ±72 m**. The Terminus has an ad screen at (76, 100) and a
column at 72 stood 1.3 m from its footprint against a required 4.3. The authoring check earned its place.

**For the record and deliberately NOT asserted** (Invariant 0b — a check must not encode a decision nobody has
made): at the round-9 roster the grid does **not** hold the biggest hull. Adjacent columns leave
7.5 − 2×1.5 − 4.74 = **−0.24 m** for the Condemned artillery's width; adjacent rows leave 12.0 − 2×0.6 − 14.0 =
**−3.2 m** for the War Rig's length. Both are harmless *because* of `deploy()`, and both become findings the day
`deploy()` stops running first — which is exactly what the new guard watches.

**Three mirrors killed on the way**, all of them in this stream's paths and all three mutation-checked:

1. **`tools/make_arenas.py` carried its own copy of `SLOT_X` / `SPAWN_ROWS` / `SPAWN_ROW_SPACING`** behind a comment
   saying *"must mirror"*. It is the worst row in Invariant 0's table because **the copy WON** — `Arena.spawn_spot`
   is consulted before the constants, so the baked lists beat them. It now READS them
   (`tools/gdscript_source.py`), and `test_every_layouts_baked_spawn_list_is_the_grid_the_constants_describe`
   checks every shipped map against the constants. **That guard was green by absence when first written**
   (`Arena.load_layout` returns `{"layout": …}`, not the layout, so it was comparing the constants with
   themselves); it was caught by mutation-checking it, and it fires now.
2. **`make_arenas.check_spawn_clearance(layout, clearance=6.0)`** mirrored `Arena.SPAWN_CLEARANCE`, which is
   `Match.SPAWN_JITTER_MAX_X + 2.5`. The margin is now a named constant (`Arena.SPAWN_CLEARANCE_MARGIN`) and the
   tool reads **both halves** from where they are defined.
3. **`arena_report.py` sliced `layout["spawns"]["rust"][:13]`** in two places — 13 being `Match.SLOT_X.size()` at
   the time, a mirror hidden in a slice with nothing naming it. At 19 columns the slice quietly took two thirds of
   the front row, and the only symptom was the route optimiser's monotonicity test wobbling by 0.001. It reads the
   front row off the points now (`arena_report.front_row`).

**All ten layouts regenerated** (`make arenas`); `make arena-test` 75/75, `tools/test_arena*.py` 19/19,
`--filter=match` 72/72, all on the laptop.

### 4. Clearance for the new roster (P6) — measured

`make nav-maze NAV_UNITS=30 ARENA=maze NAV_TIME=180 SEED=1 NAV_BOTH=1`, builder0, same seed both arms, 30 units
head-on through the maze's defile. The probe spawns `Units.DEFAULT` — the Condemned `tank` — so this is the unit
that went **3.60 → 8.62 m**.

| | BEFORE (`9f864474`) | AFTER (`97b383eb`) | × |
|---|---|---|---|
| arrived | 30 / 30 | 30 / 30 | 1.00 |
| off_navmesh | 0 | 0 | — |
| t50 | 78.03 s | 120.17 s | 1.54 |
| t90 | 95.73 s | 159.40 s | 1.67 |
| **t100** | **104.10 s** | **165.87 s** | **1.59** |
| **stuck_events** | **341** | **678** | **1.99** |
| crawl | 319.2 unit-s (0.133) | 675.3 unit-s (0.185) | 2.12 |
| no_progress | 859.9 unit-s (0.359) | 1682.4 unit-s (0.462) | 1.96 |
| **oscillating** | **10.5 unit-s (0.004), 14 units** | **132.3 unit-s (0.036), 27 units** | **12.60** |
| distance travelled | 11785.3 m | 11636.9 m | 0.99 |
| progress made | 5837.2 m | 5650.1 m | 0.97 |

**Nobody fails to arrive, and nobody is pushed off the navmesh.** What changes is how long it takes and how much
of it is spent stopped: **the same ground covered** (distance ×0.99, progress ×0.97) in **59% more time**, with
**twice the stuck events** and **twelve times the oscillating seconds**, spread over 27 of 30 units instead of 14.

**⚠ THE CONFOUND, named rather than buried: the two arms differ by more than hull length.** The "before" arm is
`main`'s tree, which the brief asked for — so it also carries the **old spawn grid** (4 rows of 13 vs 3 rows of
19) and the old baked spawn lists. `maze_probe` spawns through that grid and orders each unit to the 180° mirror
of **its own spawn point**, so the two arms start in different places and drive to different goals. The result is
real and it is large, but **it is not attributable to hull length alone from these two runs.** A third arm with
only `units.gd` and `tank.gd` reverted — the new grid, the old roster — isolates it, costs one builder0 slot, and
is queued behind the CP2 check.

**No conclusion about the mechanism from me** (nav's request, and their three pre-registered hypotheses for the
defile are all dead). What I will say is what the numbers say: the pathology is **time and stopping**, not
reachability.

### 5. A3: hull-chord cover over directional summed-area tables — done

**REPLACES centre-point cover registration** (Invariant 0c: a brief that adopts a catalogue row must name what it
replaces). `Arena.cover_fraction(viewer, point, heading, length)` returns the fraction of a hull's own centreline
chord occluded from a watcher — combat's signature, taken as they specced it, heading as a flat `Vector3` because
every caller already holds a forward vector. Two array lookups and a subtraction, the same work at 2.93 m and at
14.0 m, integer arithmetic throughout (`game/arena/cover_tables.gd`).

**Positive control first, before any code** (lesson 147). `make arena-report` on the resized roster reproduces
round 8's step exactly — share of the field within 45 m of a prop long enough for the hull (laptop, pure Python):

| hull | 2.93 | 5.0 | 6.0 | 7.0 | 8.62 | 12.0 | **12.19** | **12.5** | 14.0 |
|---|---|---|---|---|---|---|---|---|---|
| yard | 0.99 | 0.99 | 0.99 | 0.99 | 0.99 | 0.99 | **0.99** | **0.00** | 0.00 |
| pit | 0.85 | 0.85 | 0.85 | 0.48 | 0.46 | 0.46 | **0.46** | **0.00** | 0.00 |
| terminus | 0.98 | 0.98 | 0.98 | 0.95 | 0.91 | 0.91 | **0.91** | 0.91 | 0.91 |

**And the resize is what makes A3 stop being a rig-only fix:** pit's score already halves at **7.0 m**
(0.85 → 0.48), and five units are now over 7 m where one was.

**The falsifier is met.** Mean occluded chord fraction over the contested field, watcher on the far side, under the
new query (laptop, this commit):

| hull | 2.93 | 6.0 | 8.62 | 12.0 | 12.19 | 12.5 | 14.0 | spread |
|---|---|---|---|---|---|---|---|---|
| yard | 0.320 | 0.292 | 0.291 | 0.288 | 0.288 | 0.288 | **0.287** | 0.033 |
| pit | 0.31 | 0.38 | 0.34 | 0.36 | 0.36 | 0.36 | **0.36** | — |
| terminus | 0.76 | 0.76 | 0.77 | 0.77 | 0.77 | 0.77 | **0.77** | — |

**Flat.** Where the old rule put yard at 0.99 and then 0.00, the new one puts a 14 m hull within **0.03** of a 12 m
one. `make arena-cover` prints it; `tests/test_arena_cover_tables.gd` asserts it on every shipped map (8 tests) and
**carries the old rule in the same file as the positive control**, so the thing being replaced stays checkable.

**What it costs, reported as two terms because they behave oppositely** (`CoverTables.worst_case_error`): an
**angular** term, `1 − cos(22.5°) ≈ 7.6%` of hull length, constant as a *fraction*; and a **grid** term of one 2 m
cell, constant in *metres*. So the query is **least precise on the shortest hull, not the longest** — the opposite
of the intuition, and combat has said this inverts where they were going to set `hull_hidden`'s threshold.

**One defect found by writing that error report.** The first chord discretisation was
`floor(length / 2 / cell) * 2 + 1`, which collapses every hull shorter than twice the cell to a **single cell** —
i.e. the centre-point query, under a new name, for the Rat Rod and the whole light end of the roster. It is
`max(1, round(length / cell))` now. **A row that replaces a point sample can reintroduce it by arithmetic**, and
only stating the error term out loud caught it.

**`make arena-report`'s WATCH line changed in the same commit as the tables**, as the lead's ruling requires. It no
longer says *"NOTHING on this map can hide the longest hull"* — true under the old definition, **false** under the
new one, and a WATCH line that is confidently wrong is worse than silence. It now names the definition that
produced the number, says it is superseded, and points at `make arena-cover`. The point sample is still **printed
beside** the chord figure for one round (lesson 49) and `hull_cover.definition` says so in the JSON. arena's own
guard against a dead WATCH line keyed on the exact phrase, so it was rewritten to key on the reach reaching the
reader rather than on a form of words.

**⚠ HALF OF A3'S PRE-REGISTERED FALSIFIER IS NOT ACHIEVABLE AS WRITTEN, and it is recorded here rather than
discovered when someone quotes A3 as met** (combat spotted it from the error numbers; the reading is theirs):

- **The half that passed cleanly** is the pathology A3 was adopted for: the 12.19 m step is gone, yard's 14 m
  figure is within 0.03 of its 12 m one against a pre-registered 0.1, and the spread across 2.93–14.0 m is 0.033.
- **The half that cannot pass** is *"exposed hull fraction … below 5% at **every** hull length 2.8–14.0 m"*. At
  2.93 m the worst-case error is **0.759**, because the grid term is a constant 2 m against a hull that is one to
  two cells long: the query cannot distinguish 5% exposure from 50% there. **No threshold fixes that — it is the
  resolution, not the calibration.**
- **The honest statement for the round, which is combat's wording:** *A3 fixes cover for hulls long enough to be
  resolved by the grid, and leaves short hulls where they already were.* It does not make the short end worse — at
  2.93 m it degrades gracefully to roughly the point sample we already had. **The catalogue over-promised the
  range; it did not over-promise the mechanism.**
- **Open, with numbers:** the grid term is exactly the cell size. At 1.0 m cells the Rat Rod's grid error falls
  0.683 → 0.341, at 0.5 m → 0.171. That is 4× and 16× the table memory and build time. Affordability is being
  measured (`tests/scale/cover_bench.gd`); if 1.0 m is cheap it is worth having, because the units that hide for a
  living are the light ones and that is the length the query is currently blindest at. If it is not, the range
  limit goes into `hull_hidden`'s threshold and into `_agents/balance.md` as a known bound rather than a bug.

**Not answered yet, deliberately:** combat's optional second entry point `hull_footprint_clearance(point, heading,
length)`. A prefix sum of occlusion along a heading is not a distance transform, so it is not obviously free from
these tables. I will say yes or no with a reason rather than half-build it; combat keeps the point sample and
renames it honestly in the meantime.

### The maps' corridors vs the roster — and ⚠ a wrong measurement I circulated and retracted

**THE ANSWER: the maps are fine.** Perpendicular free span across the base-to-base route, against the roster's
widest hull (the Condemned `artillery`, 4.74 m with its outriggers deployed). `make arena-report`, laptop, static
geometry, machine-independent:

| map | tightest | slack | hulls passing with 1 m spare |
|---|---|---|---|
| foundry / furnace | 62.50 m | +57.76 | 21/21 |
| boulevard | 59.00 m | +54.26 | 21/21 |
| boneyard | 27.00 m | +22.26 | 21/21 |
| pit | 19.00 m | +14.26 | 21/21 |
| yard | 18.00 m | +13.26 | 21/21 |
| scrapyard | 17.50 m | +12.76 | 21/21 |
| terminus | 11.50 m | +6.76 | 21/21 |
| maze | 7.00 m | +2.26 | 21/21 |
| **barriers** | **5.50 m** | **+0.76** | **20/21** |

**The measure validates itself against the authored geometry:** it reports the maze's tightest point as exactly
**7.00 m**, and `tools/make_arenas.py` authors `MAZE_TIGHT_GAP = 7.0`. `barriers` is the only WATCH, it is 0.76 m
of slack for the single widest hull, and it is not in `Arena.ROTATION`.

**So squad's maze result is entirely the navmesh question, not a map question.** 7.0 m of physical gap minus
`NAV_AGENT_RADIUS` 2.0 m each side leaves 5.0 m of navigable corridor for a 4.74 m hull — 13 cm a side. nav's,
with squad's reproduction.

#### ⚠ The first version of this measurement was wrong, and I circulated it

**It reported that 8 of 10 maps had a tightest point NARROWER than the widest hull.** It went to the orchestrator,
squad and nav, and it produced a ruling to widen the kit's gaps (CP2d) before I caught it. Withdrawn; the ruling is
withdrawn too (lesson 162).

**What was wrong:** the function returned **twice the distance to the nearest obstacle**. That is the corridor
width only when something blocks **both** sides. Where a route passes close to a *single* prop with open ground
beyond, it means nothing. On yard, at the exact point I reported as 4.72 m:

```
nearest tall props to (4, 66):   2.71 m wreck at (9, 68);  the next is 11.78 m away
free span across the route:      20.0 m one way, 3.0 m the other  ->  about 23 m
```

**I reported 4.72 m where there are 23**, and the corrected measure puts yard at 18.00 m.

**The lesson, which is worth more than the number was:**
- **A measure that flags EVERY map is usually measuring the wrong thing.** It was plausible on all ten, and
  plausibility on all ten is the tell.
- **I circulated ten numbers without sanity-checking one against the world.** One `print` of the nearest props at
  one reported pinch would have ended it. And **there was a free positive control available all along** — the maze's
  authored `MAZE_TIGHT_GAP = 7.0` — which the wrong version missed by 2.6 m and the right one hits exactly.
- **I wrote the WATCH line's prose as if the quantity were established** (*"only 19 of 21 hulls pass there"*), which
  made a wrong number legible and quotable. **It is the same failure shape this stream spent the round finding in
  other people's code — the thing under test quietly not being the thing described — and `arena_report` has now had
  two of mine in one night: the `[:13]` slice I fixed, and this one I introduced.**

`corridor_widths()`'s docstring carries the wrong version's history, so the next person to touch it knows what it
looked like when it lied.

### Decisions (with reasons)

- **The two units with no `unit.<id>.hull` art** — `tank` and `burner`, wearing the shared dozer — **take a length
  from the rule and keep the width and height the catalog already had.** Nothing has measured a proportion for
  them and inventing one is opinion, not sizing. `Tank` stretches the shared art to the box on every axis, so what
  is drawn still matches `hull_size`. `test_only_the_two_known_units_have_no_art_of_their_own` pins the list in
  both directions.
- **Appendages are inside the box, because the rule says the box is what is drawn.** Three units grew far more on
  a cross-axis than in length, and they are the art's own proportions, not a choice: `law_suppressor` is now
  **6.18 m tall** (the horn tower really is about as tall as that truck is long in the approved concept), the
  Condemned `artillery` is **4.74 m wide** (deployed outriggers) and `syn_artillery` **4.07 m wide** (missile
  wings). They are flagged here and they are what the lead will see in the line-up. Trimming them would be sizing
  by opinion, which the rule forbids; if anyone wants appendages excluded from the collider that is an extension of
  `FactionArt.GUN_CUTS` and it is feel's, next round.
- **Muzzles: `min(today's, ceiling)`, not scaled.** No muzzle in the catalog was ever measured from a mesh (they
  are 1.05 / 1.12 / 1.20 / 1.27, i.e. a shared barrel height), so there is nothing to re-derive per unit; the only
  real constraint is the roster-wide ceiling, and every muzzle above it came down to it.
- **`tools/gdscript_source.py` is the one Python reader for GDScript constants**, with `units_catalog.py` a thin
  facade over it. Three tools were about to grow three regexes.

### Questions for the lead

- **None blocking.** The one open question — rig-relative K vs real metres — is the orchestrator's to carry. It is
  now genuinely one number: `Units.RIG_LENGTH_M` 14.0 → 19.80 in `units.gd`, then `make roster-scale` and rewrite
  the 21 `hull_size` values from the table. Everything else re-derives.
- **The look** (backlog item 2) is his, and CP2 waits for the frame to be *sent*, not approved.

### Requests to other streams

- **combat** — reviews the `units.gd` / `match.gd` / `tank.gd` diff at merge (already briefed, no objection).
  Expect `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` to move: that hull's collider is 0.8 m taller.
- **combat, A3 consumer spec received (2026-09-20)** and it is what item 5 will be built to:
  `cover_fraction(viewer: Vector3, point: Vector3, heading: Vector3, length: float) -> float` — heading as a flat
  `Vector3`, not radians; the worst-case quantisation error at K = 8 headings reported **as a fraction of hull
  length**; determinism asserted in a test (integer prefix sums, no float reduction order); `0.0` rather than
  garbage, and no error spam, when the hull straddles a table edge or leaves the arena. Second, cheaper-if-free
  entry point: `hull_footprint_clearance(point, heading, length) -> float`. Combat also reports that
  `EngagementStats.near_cover` **has never measured cover** — it measures proximity to an obstacle footprint — and
  owns renaming it; the viewer question is theirs, the hull-aware primitive is mine.
- **feel** — `assets/pipeline/asset_contracts.gd` `UNITS` carries its own copy of `hull_size` and `muzzle_height`
  for five units and **already disagreed** with the catalog before this round (it has `tank` h = 1.6). It is the art
  pipeline's normalization contract, so it is inert for gameplay, but **any new art generated after CP2 would be
  normalized to the old 3.6–4.0 m sizes**, and no test ties it to `Units.PROFILES`, so nothing will say so. Routed
  via the orchestrator.
- **squad** — formation and assembly spacing re-measure after CP2. `army_layout.gd` reads `hull_size` and the
  roster's widest hull is now **4.74 m** and longest **14.0 m**; `deep_floor = longest + HULL_CLEAR_M` will grow.
- **nav** — `Movement.NAV_AGENT_RADIUS` still mirrors the bake at 2.0 m for a footprint range that has grown.
  Proposal unchanged: read it from `Arena`. Numbers come with item 4.
- **control** — the camera, HUD, selection boxes and radar at his pose against the new sizes, after CP2.

### Known issues

- **`make check` has not yet gone green on builder0 for this branch.** A full `make remote T=check` on `b7055602`
  (the roster resize, before the spawn-grid commit) was still running when this Status was written. **No readiness
  claim is made until the wrapper's own `>> remote: make check exited <N>` line and the runner's
  `N passed, 0 failed` say so, unpiped** (lesson 28).
- The line-up frame is built (`make roster-lineup`, three frames) but **not rendered**: it needs a display, so it
  needs builder0, and this worktree already has a `make remote` in flight (trip-up 66).

### What to playtest (exact commands)

```
make roster-scale                         # the table: reference vehicle, K, target length, box, mesh box
make remote T=roster-lineup               # the three line-up frames -> build/roster-lineup/lineup_*.png
make remote T=facing-audit                # every unit side-on at the new scale -> build/facing/<unit>.png
make skirmish --player-faction=condemned  # the bus-tanks, at his camera
```

### Merge notes (shared-file edits)

- **`game/tank/tank.gd`** — `_apply_hull_size` only (the early return removed; the shared-art fit now reads the
  mesh) plus the new `Tank.shared_hull_size()`. Not this stream's file; granted, and combat reviews it.
- **`game/units/units.gd`** — the carved-out keys only: `hull_size` and `muzzle_height` values, the new
  `scale_reference` key on all 21 profiles, `RIG_UNIT` / `RIG_LENGTH_M` / `SCALE_K` / `_derive_scale_k` /
  `target_length_m`, and the schema comment. **No costs, speeds, armor, weapons or turn rates were touched.**
- **`game/match/match.gd`** — the three spawn constants and the two jitter bounds they derive, in one commit, with
  the derivation written beside them. Nothing else.
- **`game/arena/arena.gd`** — `SPAWN_CLEARANCE_MARGIN` extracted so `make_arenas.py` can read it. This stream's file.
- **`game/theme/fx/bench/size_look.gd`** — additive `--size-look-lineup` mode (granted at launch; feel reviews).
- **`arenas/*.json`** — all ten regenerated by `make arenas`; only the `spawns` lists changed.

