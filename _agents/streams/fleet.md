# Stream: fleet (the vehicles are wrong in five ways, and four of them are one missing check)

> Read [`game_design.md`](../game_design.md) *Round 11 direction* and *Factions*, then
> [`art_direction.md`](../art_direction.md) and [`workstreams.md`](../workstreams.md). **You own** the vehicle art and
> its proportions: `game/theme/factions/**`, `game/theme/roster/**`, `game/theme/prison_dozer/**`,
> `game/theme/cyberpunk/dozer_part.gd`, `game/theme/gallery/**`, `assets/pipeline/**`, `tools/assets/**`,
> `mk/assets.mk`, `mk/scale.mk`, `mk/fx.mk`'s gallery/audit/probe targets, `tools/roster_scale.py`,
> `tests/test_theme_unit_scale.gd`, `tests/test_units_*.gd`; **plus two carve-outs**: the `hull_size`,
> `muzzle_height` and `turret_mount` VALUES in `game/units/units.gd`, and `Tank._apply_hull_size` /
> `Tank.turret_pose` in `game/tank/tank.gd`. You do not own the rest of `tank.gd` or anything in `game/ai/`.

## The lead's direction (2026-09-23, night)

> *"Syndicate has some backwards vehicles."*

> *"The turret on the Law's IFV is not spinning."*

> *"The vehicle sizes on the tanks for The Condemned are not consistent. THere is some variant of the tank which is
> quite tall. Then there are the previously sized units. They need to be uniform, but also it was good for the busses
> to be slightly taller (as in the deformed version, but not quite so tall)."*

> *"The tanks for the law should be bigger, and the IFVs probably should also then be bigger."*

> *"It also looks like the turret on the law tank is disconnected (i.e. the barrel of the tank is detached at the tip,
> there's a floating piece of the barrel that stays fixed in front of the tank)."*

## Where things stand (surveyed before this brief; verify every number, do not trust it)

**The frame for all of it:** round 9 set the sizing rule and it stands — *one scale factor for the whole world,
anchored by the War Rig at 14.0 m; `SCALE_K = 14.0 / 19.8`; every unit's length = its real-world reference length ×
K; width and height come from the approved mesh at that length* (`game_design.md` *Proportional, real-world relative
sizing*; the table is `Units.PROFILES` and `make roster-scale` prints it). **Nothing below re-opens that rule.** Four
of his five complaints are units that escaped it, and the fifth is a reference vehicle chosen wrong.

### 1. The turrets are spinning. They are spinning *inside the hull*. (his "not spinning")

`law_ifv` has a turret mesh (`unit_law_ifv_turret.glb`), it is parented under `Turret/TurretVisual`, and it rotates.
But `Tank.turret_pose()` (`tank.gd:244-249`) pins the pivot at `muzzle_height − 0.05 = 1.09 m` with `lift = 0`
unless the unit has a `turret_mount`, and **only four units in the whole catalogue have one** (`units.gd:209` tank,
`:365` burner, `:457` gang_ifv, `:504` gang_tank — round 10's feel stream did the Condemned and the gangs and
stopped). The drawn turret then sits at `fit × (1.09 + local_y)`, which for most of the roster is below the roof:

| unit | hull roof (m) | turret art y-span (m) | verdict |
|---|---|---|---|
| **law_ifv** | 3.29 | 1.92 → 3.09 | **fully buried — his complaint** |
| law_tank | 2.88 | 1.53 → 3.61 | half buried |
| law_suppressor | 6.18 | 3.92 → 5.81 | buried |
| law_artillery | 2.64 | 2.02 → 2.40 | buried |
| syn_ifv | 1.34 | 0.83 → 1.19 | buried |
| syn_tank | 1.85 | 1.28 → 1.71 | buried |
| gang_artillery | 3.36 | 1.29 → 2.76 | buried |
| gang_ifv, gang_tank | — | — | have `turret_mount`; correct |

So this is **one roster-wide defect reported as one unit**, and the fix is the mechanism round 10 already built,
applied to the other seven. `make turret-probe` prints pivot, turret art AABB, weapon art AABB and roof per unit,
headless — that is your instrument, and there is no test using it. The only art-turret test in the tree covers
`gang_tank` alone (`tests/test_theme_unit_scale.gd:110`).

Also suspect the Law IFV's mesh itself: its turret part is 0.34 × 0.77 × 1.55 m with the manifest note *"placed as
generated, moved (0.56, −0.67) onto the turret pivot"*. The splitter labels islands by geometry heuristic
(`assets/pipeline/asset_splitter.gd:22-114`), and it probably picked a roof rail rather than the remote 25 mm
station. Check with `make assets-view SPLIT=1` before you conclude the mount alone fixes it.

### 2. The detached barrel is a 14-triangle stick, and five units have one (his "floating piece")

The muzzle is pure math (`tank.gd:1188`: `turret.global_transform * Vector3(0, 0.05, -3.2)`), and the flash is world
space — so the floating piece is **geometry**. It is the generated weapon part. `unit_law_tank_weapon.glb` is
**0.018 × 0.018 × 4.585 m, 14 triangles**, sitting 0.74 m off the centreline, stretched ×3.75 from its breech to the
contract's muzzle point (`asset_normalizer.gd:223-231`). After `_fit_to_hull`'s ×1.542 it pokes ~1.95 m past the
nose, off to the right, at mid-hull height — while the **real gun is already modelled inside the turret glb** (3982
tris). Two barrels, one of them a stick.

`FactionArt.STRAY_WEAPONS` (`faction_art.gd:18-21`) exists for exactly this and its own comment says *"Every
generated weapon part is such a stick"* — and it blacklists **only `gangs/artillery`**. Still drawn:
`law/tank` (14 tris), `law/ifv` (154 tris, +1.04 m off centre — outside the hull at runtime), `law/special` (30 tris,
≈9.1 m long after fit), `syndicate/tank` (136 tris).

### 3. The Condemned's "quite tall" variant is the only non-uniform scale in the game

`Tank._apply_hull_size` (`tank.gd:277-291`) has two branches, and the one for units **without their own hull art** is
a true stretch:

```gdscript
if not own_hull_art:
    _hull_visual.scale = Vector3(size.x / standard.x, size.y / standard.y, size.z / standard.z)
```

Exactly two units take it — the Condemned **`tank` (the prison bus-tank)** and **`burner`**, the two with no mesh of
their own, both wearing the shared prison dozer (1.591 × 1.600 × 3.074 m):

| Condemned unit | `hull_size` | own art | scale applied |
|---|---|---|---|
| scout | 1.81 × 1.50 × 3.04 | yes | uniform |
| ifv (garbage truck) | 2.86 × 3.70 × 7.54 | yes | uniform ×1.984 |
| artillery | 2.90 × 2.82 × 8.20 | yes | uniform ×2.050 |
| lancer | 2.76 × 3.85 × 6.46 | yes | uniform ×1.782 |
| **tank (prison bus)** | **2.90 × 4.76 × 9.70** | **none** | **STRETCH (1.823, 2.975, 3.155)** ← his tall one |
| **burner** | 2.40 × 2.40 × 6.89 | **none** | **STRETCH (1.508, 1.500, 2.241)** |

The Condemned tank is the dozer squashed **2.98× vertically against 1.82× horizontally — a 1.63:1 aspect
distortion**. That is the "deformed version" in his own sentence, and it is why it reads as a different vehicle from
"the previously sized units". Its height is not derived from any mesh at all: `SizeLook.natural_size()` returns zero
for it, so `box_at_length` falls back to the literal catalogue box, which came from his round-10 ruling
(`units.gd:174-183`, pinned by `tests/test_units_bus_eye.gd:28-44`). And
`tests/test_theme_unit_scale.gd:147` — the "drawn inside its own box on every axis" guard — **skips units with no
hull slot**, i.e. skips exactly these two.

**Read his sentence carefully, because it contains both the bug and the exception:** the *tank* must stop being a
deformed dozer, and the *bus* keeps some of the extra height — *"slightly taller (as in the deformed version, but not
quite so tall)"*. He likes what the height did; he does not like what the stretch did to get there.

### 4. Backwards Syndicate vehicles: two uncoordinated places set forward, and nothing checks

Godot's forward is −Z. Orientation is decided **by hand at build time** in `tools/assets/build_factions.sh:52-70`
(one `forward` axis per model, typed from `make assets-view SPLIT=1`) and baked into the glb, with a **second,
separate runtime correction table** `MODEL_YAW_DEG` in `tools/assets/build_faction_parts.py:18-23` holding exactly
two entries (`gangs/ifv/hull`, `syndicate/special/hull`, both 180°).

The Syndicate batch was typed in one sitting: `syndicate_special_b` was declared `+x` and later needed a 180°
correction, and **`syndicate_ifv_b` (the Limousine Gunship) is the other `+x` in that same batch, never corrected** —
that is the first place to look. The three `−x` Syndicate hulls (scout, tank, artillery) have never been verified by
anything either.

**What "checks" exist and why they did not catch it:** `make facing-audit` renders every unit side-on with a red −Z
arrow and **asserts nothing** (needs a display). `asset_checker.gd:124-130` only asks "is x wider than z", which
cannot see a 180° error. `tests/test_theme_unit_scale.gd:96` pins `rotation.y ≈ π` for the **two known** corrections —
a regression pin, not a check. **There is no test that a model's nose is on −Z**, and the airship lost a night to
this same convention bug last week.

### 5. "The tanks for the law should be bigger"

Under the round-9 rule, a unit's length is its real-world reference × K, so "bigger" is a question about **which real
vehicle the Law's tank and IFV are**, not about a number you may pick. `game_design.md:1427-1434` sketches the Law as
the state's wardens: *"MRAPs, up-armored cruisers, 8×8 assault guns"*, with **the Law's tank = the 8×8 assault gun**.
Run `make roster-scale` and see what reference and length the Law's tank and IFV carry today — if the tank is priced
as something shorter than an 8×8 assault gun (Centauro 7.85 m, Stryker MGS 6.95 m), the rule itself says it should
grow, and you can give him what he asked for **without inventing a number**. His other sentence is the sanity check:
the Law is the state and should look like it outweighs the scrap it polices.

## Backlog (in order)

**T1. The turret mount for the seven buried turrets.** Test first, from `make turret-probe`'s own output: **every
unit with turret art has its turret above its hull roof**, derived per unit from the mesh, no hard-coded list
(lesson 3). Mutation-check it. Then add `turret_mount` per unit the way round 10 did for the Condemned and the
gangs. Look at `make vehicle-gallery FACTION=law` afterwards and confirm with your eyes that a turret is visible and
turning — a passing test here means the number moved, not that he can see a turret (lesson: "accepted with no error"
carries no information).

**T2. Kill the stray barrels.** Test first: no drawn weapon part may sit outside the hull's own box, or be a
degenerate sliver (a triangle count and an aspect bound both catch it; pick the one you can defend). Then extend
`FactionArt.STRAY_WEAPONS` to every slot that fails, or — better, and say which you chose and why — make the rule
derive itself so a future generated stick is refused rather than blacklisted. The gun is already in the turret mesh
for these units, so nothing is lost by not drawing the stick.

**T3. The Condemned tank stops being a deformed dozer.** This one moves the sim baseline, so it is **CP1** and it
merges alone (see *Checkpoint*). Two halves:
- **The art:** `tank` and `burner` should be drawn uniformly, like every other unit. Decide how — a bounded,
  *declared* vertical exaggeration with his quote beside it is acceptable where a 1.63:1 silent stretch is not — and
  put the constant somewhere a reader can find it.
- **The box:** his ruling set the bus at 4.76 m and his new words move it down: *"slightly taller… but not quite so
  tall"*. Pick a height that keeps the bus reading taller than the garbage truck (3.70 m) and stops it reading
  deformed, change `hull_size` and whatever `tests/test_units_bus_eye.gd` pins, and **say in one line why that
  number**. `make size-look` and `make roster-lineup` are how you judge it; put the before/after on the review page.
- **Also fix the hole that hid it:** `tests/test_theme_unit_scale.gd:147` skips units with no hull slot. Make it
  cover them.

**T4. The Law's tank and IFV, re-derived.** Report what `make roster-scale` says their reference and length are, pick
the right reference vehicle from the faction sketch with a cited real-world length, and let K do the arithmetic. If
the resulting hull box changes, it rides **in CP1 with T3** — one baseline move for the round, not three. Do not tune
sizes for balance (his standing ruling: *"we'll worry about evening up factions later"*); measure the consequences
and report them.

**T5. A test that a nose points at −Z.** Not a pin on the two known corrections — a check. The honest options: assert
each faction hull's **drawn** forward against something independent of the table that produced it (the asymmetry of
the mesh along Z, the position of the turret pivot relative to the hull centroid, or the cannon island's direction
from the splitter, which is derived from geometry rather than typed by hand). Build the one you can defend, run it
over every faction unit, and fix whatever it catches — starting with `syndicate_ifv`. Then look at
`make facing-audit` output with your own eyes, all of it, and say in Status which models you *looked* at, because a
geometric proxy can be right and still disagree with a human.

**T6 (stretch, and a lead gate). The prison bus deserves its own mesh.** Round 10 queued a concept page for a paid
bus mesh and it did not ship; T3 is a good fix on a shared dozer, not the real one. Standing gate: **concepts go on
the review page before any image-to-3D** — two or three directions per slot, generated at best quality, logged in
`assets/meshy_ledger.md`. The path is `make art-concept-batch SPEC=assets/review/batches/<name>.json` (or
`make art-concept` per image, with `REFS=` pointing at the approved Condemned art — **brief from the IMAGES, never
from adjectives**, which is round 11's own airship lesson in `art_direction.md`), then `make art-review-page`, then
`make art-apply-decisions` once he has tapped. Generate the concepts, put them on the page, tell the orchestrator,
and **keep going**; never wait.

## Checkpoint

**CP1 — the size changes (T3 + T4), merged alone.** Any `hull_size` move changes the spawn grid, the collider and the
sim baseline by construction. Land T1, T2 and T5 first and separately (they draw art and move no box), then put
every box change in one commit, name the hash its check went green on, and **tell the orchestrator** — the baseline is
recorded twice in one session by the orchestrator, not by you. **Nobody publishes a size-dependent number measured
across CP1**, including you.

## How to verify

- `make remote T=check` — read the wrapper's own `>> remote: make check exited <N>` line and the runner's
  `N passed, M failed`. **Never through a pipe.**
- Headless: `make turret-probe`, `make roster-scale`, `make roster-boxes`, `make assets-check`.
- With a display (`make remote T=<target>`): `make vehicle-gallery FACTION=law|syndicate|gangs`,
  `make roster-lineup`, `make facing-audit`, `make size-look`, `make assets-unit`, `make faction-shots`.
- **Look at every picture you produce.** Four of these five defects were invisible to a green suite and obvious to
  the first person who looked at the game.

## Don't touch

`game/ai/**` (nav's), `arenas/` and `game/arena/**` (arena's), `game/camera/**` and
`game/theme/arena_kit/airship/**` (airship's), `game/theme/cyberpunk/arena_dressing.gd` (arena's tower and airship's
build call). Combat rules, weapons and balance are nobody's this round: if a size change looks like it changes a
matchup, report the number, don't tune it.

## Waiting on the lead

T6's concepts (paid generation gate). The T3 before/after lineup goes on the review page for his morning — his eye is
the only check that counts for proportions.

## Status

_(the worker keeps this current: plan, what's done with measurements, decisions and their reasons, questions for the
lead, requests to other streams, known issues, what to playtest, next steps, merge notes, and the commit hash whose
own check went green)_
