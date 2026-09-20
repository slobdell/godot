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

**Not started.**
