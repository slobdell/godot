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

_Updated 2026-09-24 (afternoon) by the fleet worker. Numbers: laptop unless marked builder0; commit named._

### Where it stands (read this first)

| item | state | commit |
|---|---|---|
| T1 turrets buried in hulls | **done, merged** | `03d3a839` + `8991e0c9` |
| T2 stray barrels | **done, merged** | `03d3a839` |
| T5 nose check | **done, merged** (syn_ifv turned round) | `03d3a839` |
| T3 + T4 = CP1 v2 | **done, merged** (main `9f867385`; baseline `01ab39b592cc9837` recorded on main `9ed7fccf`) | `2cc44030` |
| War Rig "disconnected and floating" (live feedback) | **done, merged** (main `3f878009`) | `f222b7c8` |
| War Rig simulated muzzle vs drawn gun | **round-12 candidate** (ruled not this round), in verification.md | `397de636` |
| T6 the bus's own mesh | **waiting on the lead**: bus b built but van-shaped (1.85:1); D recommended; H and I on page 2 | `eb82692d` |
| the burner as a fire engine | **waiting on the lead**: burner_r11_a/b/c on page 2 | `5426558d` |

**Review page (all rounds): https://claude.ai/artifact/JPb1bfR79qKr5amxeEG7RS** (version 5, db; read taps with
`read_db` into a folder, then `make art-apply-decisions DIR=... URL=...`). Page 2 carries `q_r11_bus_fit` (D
recommended: regenerate; A/B/C all deform or break a ruling), `bus_r11_h` (right length, look drifted), `bus_r11_i`
(bus b's look, partly lengthened) and the three fire-engine burners. **Next after his taps:** a picked burner -> 3D
(15 credits) -> its own hull art and box (a CP: the burner's box moves); a picked bus concept -> 3D -> `unit.tank.hull`
(a CP if its proportions move the 9.70 x 2.90 x 4.08 box). **Credits this round:** concepts 9 each (burner x3,
bus x6 of which 4 superseded), bus b 3D 15; see `assets/meshy_ledger.md`.
**The rule the bus bought** is in `art_direction.md`: the reference decides proportion, the prompt decides detail.

**The lead's answers on page 1** (https://claude.ai/artifact/JPb1bfR79qKr5amxeEG7RS, recorded with
`make art-apply-decisions`): Law 1.25x APPROVED; burner same-shape REJECTED ("I had no idea these were 2 separate unit
... We will want to create a different unit type for the burner because it looks identical to the tank"); burner
concepts all REJECTED ("To keep things ridiculous this should be based off of an actual fire engine"); bus_r10_b
APPROVED, a and c rejected.

**CP1 v2 = `2cc44030`** (builder0): `>> remote: make check exited 2`, 1695 passed, 0 failed, 17 of 18 targets; the one
red is sim-baseline `01ab39b592cc9837` (intended; the orchestrator records it on main after nav's branch, which moves it
too -- do not chase this hash). Contents: bus 4.76 -> 4.08 m; burner unchanged at 2.40 (exempt from the shared shape
until its own mesh); `Units.FACTION_SCALE = {law: x1.25, roles [tank, ifv], approved ...}` read by
`target_length_m`, `tools/roster_scale.py` and `tests/scale/roster_boxes.gd`: law_tank 3.36 x 3.79 x 7.30 (Centauro
II 8.26 m x K x 1.25), law_ifv 3.44 x 4.11 x 6.26 (Cougar 7.08 x K x 1.25) -- the IFV comes out wider and taller than
the tank (both are their meshes' proportions). Measured, not tuned: spawn grid (War Rig 14.0 m) and lane bar (widest,
syn_artillery 4.07 m) unmoved; navmesh bake 2.0 m unchanged, the half-diagonal the Law needs grows (tank 3.03 -> 4.02,
IFV 2.86 -> 3.57 m). A 7.30 m Law tank in the Terminus streets is NOT yet driven: the next map walk after the merges.

**War Rig** (the lead: "the tank barrel and the turret ... disconnected and floating relative to the rigger"). The
orchestrator's hypothesis (gun rides the tractor, not the trailer) is WRONG: `_cut_trailer` already moves the GunPivot
onto the trailer. Measured causes: the generated gun stands on nothing (base y 1.12 vs tanker top < 1.00: +0.19 m at
scale) and the cut box took a tail fitting the 180 rest yaw put on the cab. `GUN_CUTS` `drop` seats it (+0.01 m), the
box ends at z +1.28. Float bound tightened 0.4 -> 0.1 m for non-hover units (it had passed the rig as "design").
Reported, not changed: the SIMULATED pivot stays in the tractor frame, ~0.45 m sideways of the drawn gun at a 35 deg
bend (a sim change; the orchestrator's call).

**Page 2 (same URL, version 2), waiting on the lead:** `q_r11_bus_fit` -- bus b as built is ~1.85:1, so at 9.70 m it is
A 5.24 m wide / B 5.37 m long / C stretched into today's box (RECOMMENDED: moves no box); burner_r11_a/b/c.
Next after his taps: normalize bus b into `unit.tank.hull` per his fit answer (C = art only, no CP), then 3D the
picked burner and give the burner its own hull.

### What was actually wrong (the survey's numbers checked, several corrected)

**T1 -- "the Law's IFV turret is not spinning".** The brief's fix (add `turret_mount` to seven units) was right for
none of the worst five. `make facing-audit TINT=1` (new: turret part magenta, weapon part yellow, cut gun cyan)
showed that on **law_ifv, law_suppressor, syn_tank, syn_ifv and gang_artillery the visible gun is HULL MESH** and the
splitter's "turret" part is a fragment (roof rails, spikes among the horns, a deck-sized slab, a 10 cm chip). No mount
could make those turn. Fixed with five new `FactionArt.GUN_CUTS` authored from `make assets-profile` (the Law IFV's
weapon station, the suppressor's horn array, the Syndicate railgun and roof pod, the gang crane-catapult -- cuts may now
list several boxes). law_tank's turret was fine (97% above its roof; the brief's "half buried" read the mast in its
AABB). Round 10's comment that the Syndicate IFV's "roof gun is its real turret part (it traverses)" was wrong and is
corrected in place.
- **The test** (`test_what_turns_with_every_turret_is_drawn_above_its_hull`, derived per unit, no list): whatever
  turns must be >= 80% drawn above the hull's height field under it, at 0 and 90 deg, and not float more than 0.4 m.
  Measured: good units 86-100%, the five buried ones 31-69%. Mutation: the Condemned tank's turret sunk 1 m fails.
  New instrument `TurretFit` (`make turret-probe` prints `TURRET_PROBE_ABOVE`).
- Simulated pivots moved under the cut guns only where that moves the pivot AFT (law_ifv +0.5, law_suppressor +1.14,
  gang_artillery +0.26; none in the sim-baseline match). syn_tank/syn_ifv keep today's pose: combat's round-10
  condition (`test_tank_turret_mount`) caught that their mounts moved the muzzle 0.2 m further past the nose.

**T2 -- "a floating piece of the barrel that stays fixed in front of the tank".** Two causes on the Law tank: the
14-triangle weapon stick AND **a barrel tip left in the hull mesh** (142 triangles, z -0.65..-1.70 model space) -- the
second is the piece that "stays fixed": it does not turn. `STRAY_WEAPONS` (a one-entry list) is replaced by a rule,
`FactionArt.is_stray_stick`: thinnest side under 3% of the length. Every generated stick measures 0.4-1.9%, the real
guns 4.7% (Condemned IFV barrel), 15% (scout), 39% (lancer). `FactionArt.HULL_TRIMS` drops the tip. Tests for both,
mutation-checked (rule off: the Law tank's 7.07 m stick is caught).

**T5 -- "Syndicate has some backwards vehicles".** `FacingCheck` judges each drawn nose from geometry, independent of
the tables that set it: end taper (front end lower than rear) AND tall-mass position (aft of centre); both must agree.
The Syndicate IFV was the only unit both called backwards -- and it was (long hood, headlights and intake at +Z in its
ruled profile): `MODEL_YAW_DEG` turns it. Now 15 units forward by geometry, 0 backwards, 6 "unsure" with a recorded
human look (`FACING_EYE_CHECKED`); all 4 models tried turned round are caught.
**Models I LOOKED at** (`make facing-audit`, all 21 side-on, plus quarter views): every unit's nose leads. Checked
against the approved concepts for the three the brief doubted: law_scout (push bar and hood lead, law_scout_a.jpg),
syn_scout (pointed nose with its gun leads, syndicate_scout_a.jpg), syn_artillery (grille leads,
syndicate_artillery_b.jpg). syn_special's round-7 correction still right.

**T3 -- "They need to be uniform, but ... the busses slightly taller ... not quite so tall".** The bus and the burner
wear the same dozer and had two shapes (bus 1.63x taller than its width asked, burner 1.0x). Read as: ONE shape for
every unit wearing the shared hull. `Tank.SHARED_HULL_HEIGHTEN = 1.40` is the one declared distortion;
`Tank.shared_hull_box` derives the height; `test_units_bus_eye.gd` holds every wearer to it (found from the theme).
**Why 1.40:** between the undeformed dozer (1.0, a 2.92 m bus) and round 10's 1.63 (4.76 m, "not quite so tall"),
the lowest round tenth that keeps the bus clearly over the 3.70 m garbage truck. Bus 4.76 -> **4.08 m**, burner
2.40 -> **3.38 m**; widths and lengths unchanged (spawn grid untouched). The skipped units are now covered by the
box-fill test. Before/after on the review page (`assets/review/images/r11_fleet_bus_before_after.jpg`).

**T4 -- "The tanks for the law should be bigger".** `units.gd`: under K both were ALREADY at their references (Centauro
B1 hull 7.85 m -> 5.55; Cougar 6x6 7.08 m -> 5.01). The Law tank moves to the **Centauro II** (current 120 mm, 30 t;
published 8.26 m with barrel, as the mesh's length includes its gun): **5.84 m, box 2.69 x 3.03 x 5.84** (+5%). The
IFV is **not** moved: the cited bigger 6x6 (Buffalo, 8.2 m) gives 3.18 x 3.80 x 5.80, wider and taller than the
tank -- the opposite of his sentence. No 8x8 in service is longer; the K rule caps this. See the question below.

### Questions for the lead (on the review page too)
1. **The Law's size.** The real-world rule puts the Law's Assault Gun at 5.84 m beside a 9.7 m bus and a 14 m War Rig.
   Bigger means a declared exaggeration of the rule for the Law (like the bus's 1.4x height). Want one, and how much
   (e.g. 1.25x makes the tank 7.3 m, the IFV 6.3 m)?
2. **The burner grew with the bus** (2.40 -> 3.38 m tall) because they wear one mesh and he asked for them to be
   uniform. If he meant only the bus, set the burner back and give it its own shape (or build one of its concepts).
3. **T6's concepts** (round 10's, never shown): pick at most one bus and one burner. All three buses are stubbier than
   a 45 ft coach (about 2:1 against 3.3:1); built as-is, the model would be fitted by length and come out too wide.

### The review page (lead gate: T3's before/after, T4's question, T6's concepts)
**Published 2026-09-24 at the orchestrator's request (the lead was awake): https://claude.ai/artifact/JPb1bfR79qKr5amxeEG7RS**
(db declared; taps land in `decisions/<id>`; read them with `read_db` and `make art-apply-decisions`). It opens with two
question cards with recommendations (`q_r11_law_size`: RECOMMENDED yes, the Law 1.25x the rule -- tank 7.30 m, IFV
6.26 m, another baseline move; `q_r11_burner_shape`: RECOMMENDED keep 3.38 m), then the figures and the six concepts.
Question cards are review.json items with `buttons` and `cost` (new, optional). The build below is superseded by:
`python3 tools/assets/review_page.py build --title "Round 11: vehicle sizes and the bus's own mesh" --figure ... --figure ...` (no GROUPS).
Nothing new was generated: round 10's six concepts (3 bus, 3 burner; 54 credits, in `assets/meshy_ledger.md`) were
briefed from the approved dozer images and never shown to him. Build and publish (orchestrator):
`make art-review-page TITLE="Round 11: the Condemned bus and burner" GROUPS="R6 the Condemned" FIGURE="assets/review/images/r11_fleet_bus_before_after.jpg::The bus and burner beside the garbage truck, before and after" FIGURE2="assets/review/images/r11_fleet_roster_lineup.jpg::Every unit at the current scale"`
plus `INTRO="The bus and the burner wear the same prison dozer and were drawn in two different shapes (the bus
stretched 1.63:1 tall). They now share one shape with a declared 1.4x height: bus 4.08 m (was 4.76), burner 3.38 m (was
2.40), both still taller than the 3.70 m garbage truck. The six concepts are round 10's own mesh for each (never shown
to you): approve at most one per group. The Law's Assault Gun is 5.84 m because the real-world rule caps an 8x8 assault
gun there; if you want the Law bigger than that, say by how much and it becomes a declared exaggeration like the
bus's."` (Rendered in Chrome and looked at: figures labelled, cards render.) Publish as a private Artifact with `{"db": {}}`, then `make art-apply-decisions`.

### Known issues / not done on purpose
- Four turret units draw a gun that cannot turn because it is hull mesh and nobody asked: syn_scout (nose gun),
  syn_artillery (missile wings on the ring), syn_lancer (emitter grown out of the tail fin) and gang_support (the spray
  arm on the cab). They read as fixed-weapon designs; gang_support's arm is the one plausible cut if he wants it.
- The Condemned IFV's barrel is real (4.7% thin, kept by the stick rule) but reaches 2.4 m past its nose at rest, and
  the scout's guns sit ahead of its bumper: both are round-2 art stretched to the contract's muzzle point. Not his
  complaint; noted.
- The orchestrator session refused cross-session delivery twice (SendMessage "Failed to send to godot-83") when fleet
  announced 8991e0c9; this Status is the announcement of record.

### Requests to other streams
None. (CP1 needs the orchestrator: below.)

### Merge notes
- **Merge order:** `03d3a839` + `8991e0c9` (art only; sim-baseline UNMOVED -- `03d3a839` read 457b5e830708b439 on
  builder0) first, then **CP1 = `1c2e514f` ALONE**: it moves the sim baseline by construction (tank and law_tank are in
  the baseline match; the burner and law_tank colliders change). The orchestrator records the baseline.
- Shared files touched: `game/units/units.gd` (values + comments only: hull_size, turret_mount, scale_reference of
  law_tank), `game/tank/tank.gd` (a constant and a static beside `_apply_hull_size`, carve-out).
  `game/theme/factions/syndicate/parts/ifv_hull.tscn` regenerated by `tools/assets/build_faction_parts.py`.
- Known issue fixed on the way: `test_every_unit_with_art_is_drawn_inside_its_own_box_on_every_axis` failed
  intermittently (artillery "4.74 m wide"): the outriggers start down and are stowed on the first _process frame; the
  test waited a physics frame only.

### What to playtest
- `make skirmish` as the Law: the IFV's weapon station and the suppressor's horn array turn toward targets; the Law tank
  has no stick and no fixed barrel tip. As the Syndicate: the Limousine drives nose-first, its pod and the railgun turn.
- Any Condemned army: bus and burner are one shape at two sizes; the bus still tops the garbage truck.
- Pictures: `make facing-audit TINT=1 VIEW=quarter TURRET=90` (turning parts in colour), `make roster-lineup`.

### Next steps
- Orchestrator: merge `8991e0c9`, then CP1 `1c2e514f` alone and record the baseline.
- T6: the lead's picks -> `make art-apply-decisions` -> image-to-3D (Meshy) for the picked bus/burner.
