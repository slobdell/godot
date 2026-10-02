# Stream: fleet, round 15 (tanks and IFVs that read apart from the play camera)

> Read [`art_direction.md`](../art_direction.md), the archived round-12 fleet brief `archive/round12/fleet.md` and its
> Status (the fire engine; the pipeline fix; the bus that came back a van; how a review page with `db` is made and how
> `art-apply-decisions` reads it), `assets/meshy_ledger.md`, and garage's round-14 G7 item 5
> (`archive/round14/garage.md`): *"My tanks and IFVs look the same in the fight."* **You own** round 12's fleet paths:
> `game/theme/factions/**`, `game/theme/roster/**`, `game/theme/prison_dozer/**`, `game/theme/cyberpunk/dozer_part.gd`,
> `game/theme/gallery/**`, `assets/pipeline/**`, `assets/review/**`, `assets/meshy_ledger.md`, `tools/assets/**`,
> `mk/assets.mk`, `mk/scale.mk`, the gallery/audit/probe targets in `mk/fx.mk`, `tools/roster_scale.py`,
> `tests/test_theme_unit_scale.gd`, `tests/test_units_*.gd`. **NOT this round:** `hull_size` / `muzzle_height` /
> `turret_mount` values in `game/units/units.gd` (a box change moves the sim baseline and needs a CP; only with the
> orchestrator's call and never blind).

## The lead's direction

2026-10-01: *"playin right now feels good, so we should go ahead and set up a bunch of workstreams I can kick off for
the night."* Standing (memory: *production quality over credits*; *concept choices review page*): paid generation is
best quality, the lead limits scope not spend — **but every paid image-to-3D needs his tap on a review page first**,
and he is asleep. Standing (round 12): *"there was nothing wrong with the tank"* — the Condemned tank stays the dozer.

## Where things stand (verify on main)

- The Condemned `tank` and `ifv` both draw from the dozer-bus family; from his play camera (pitch 21°, 72 m, FOV 35°)
  garage's tour frames show them as the same long bus. The turntable tells them apart (different turrets, lengths
  8.62 vs the IFV's), the fight does not.
- Round 12's pipeline: concept images → the review page (`db`) → his tap → image-to-3D → the hull's own art, the
  −Z test, `test_theme_unit_scale`. Meshy ledger at 779 credits after round 12.
- `make remote T=formation-shots` and `tactics-shots … --pose=his` give frames at his pose; `make gallery` the roster.

## Backlog (in order)

**F1. Measure the confusion.** At his pose, the Condemned tank and IFV side by side and in a mixed squad (the frames
garage saw), at desktop and phone: what differs in pixels — silhouette (length, turret, gun), colour, markings, lights?
A contact sheet with the two outlined. Then the same for the other factions' tank/IFV pairs (Law, Gangs, Syndicate): is
this a Condemned problem or a roster problem? Numbers: the pair's silhouette IoU at his pose, drawn length ratio.

**F2. What is FREE first.** Without new generation: a faction-consistent marking that reads at 72 m (a roof stripe,
a turret band, a number plate the dozer family already has slots for), a lamp colour per class, the IFV's turret
scale/profile from the art already in the repo, the paint slots the garage exposes (`PAINT` is per unit already).
Build the cheapest one that moves F1's number, frames before/after at his pose, `test_theme_unit_scale` and the −Z
test green, the gallery re-shot. **No hull_size change.**

**F3. The paid route, prepared not spent.** If F1 says silhouette is the problem (a marking cannot fix a shape at 72 m),
prepare the review page for his morning: 2–3 concept directions per slot (the Condemned IFV as its own vehicle — an
armoured troop bus is the catalogue's word; the Law/Gangs pairs if F1 names them), the first line of every card saying
what APPROVE costs in credits and what it changes (lesson 222), the page with `db`, the URL and the last-read time in
Status. **Concept images are the only paid step allowed tonight** (log every one in the ledger); image-to-3D waits for
his tap.

**F4 (stretch).** The gallery as a lineup at his pose (every faction's tank/IFV/scout in one frame at 72 m) as a
standing test of readability: a measured silhouette-distance floor per pair, failing when a future mesh makes two
classes alike.

## How to verify

`make remote T=check`; the frames looked at; `test_theme_unit_scale`, `test_units_*` green; sim baseline
`6313a38d7ecd99bb` pre-registered UNMOVED (art only; no box changes). The ledger updated for every paid call.

## Don't touch

`game/units/units.gd` values; `game/tank/tank.gd`; `game/garage/**`; `game/arena/**`; `game/theme/arena_kit/airship/**`.

## Waiting on the lead

F3's page, if it is built — his morning. Nothing blocks F1–F2.

## Status

_Updated 2026-10-02 afternoon (UTC) by the fleet worker. Numbers: builder0 unless marked laptop; commit named._

**Merge here: `d7b52675`** (the box CP; builder0 1831 passed / 0 failed, only sim-baseline moved as pre-registered,
`05df1d55ba49cde1`; the orchestrator adopts it). Everything after it is docs and reference frames.
Earlier: **`40a2cb3d` was green** -- builder0 `>> remote: make check exited 0`, **1831 passed, 0 failed**, 18 targets
passed + `scenario_perf` NOT JUDGED (loaded, ref 1.83x; it refused the same way on the untouched baseline `85703220`),
sim-baseline UNMOVED (pre-registered: art only). After it: this Status, the taps in `review.json`, reference frames.
`b082a464` (F1+F2) is already on main.

### Where it stands

| item | state | commit |
|---|---|---|
| F1 measure the confusion | **done**: `make class-look` (new); it is a Condemned AND a Law problem, worst from behind | `130f42ed` (+ fixes in `b082a464`) |
| F2 what is free | **built**: amber class lamps on the Condemned and Law IFVs; tanks unmarked | `b082a464` |
| F3 the paid route | **BUILT**: he approved `ifv_r15_a` and `law_ifv_r15_a` (09:34 UTC); the orchestrator's go; image-to-3D (30 credits, ledger 695); art `acfb2412`, **box CP `d7b52675` (moves the baseline)** | `acfb2412`, `88725af4`, `498cbbd5`, `d7b52675` |
| F4 lineup as a standing test | **done**: `tests/test_units_class_lineup.gd` (headless raster, every faction pair under a ceiling) + `make class-look LINEUP=1` | `f4434764` (1831/0 builder0), labels `40a2cb3d` |

Plan (decided at the start, smallest first): the instrument (F1) before any fix, so every fix has a number; then the
free fix measured with the same instrument; then the paid page only for the pairs F1 names.

### F1: what differs, measured (`make class-look`, builder0, `b082a464` tree, `--no-class-mark` arm)

His pose (pitch 21°, FOV 35°, **72 m**), each unit alone under the arena's night environment, five headings relative to
the camera (away = driving away from him, how he follows his squad). Silhouette IoU = the two units' masks laid on
their centroids (1 = same shape, same size). Lit difference = mean RGB distance (0–255) over the union of the two
lit, centred units. Desktop 1920×1080; phone 1800×810 within ±0.01 IoU and ±2 of every number below.

| pair | IoU away | IoU mean / max | drawn length (tank / IFV) | mean lit colour distance | lit difference mean / worst |
|---|---|---|---|---|---|
| Condemned bus / garbage truck | **0.89** | 0.72 / 0.89 | 9.70 / **9.92 m** (0.98) | 79 | 84.1 / 69.3 |
| Law Assault Gun / Retired APC | **0.83** | 0.78 / **0.87** (toward) | 7.30 / 6.26 m (1.17) | **6.9** | 102.2 / 91.8 |
| Syndicate Railgun / Limousine | 0.43 | 0.45 / 0.51 | 5.44 / 4.63 m | 89 | — |
| Gangs War Rig / Gun Truck | 0.16 | 0.12 / 0.16 | 17.50 / 3.44 m | 79 | — |

- **A roster problem in two factions, not one.** The Condemned pair is the same tall box from behind (0.89) and the
  same drawn length: the IFV's long autocannon barrel adds ~2.4 m to its 7.54 m box, so it DRAWS as long as the bus.
  Law's pair are both dark-blue eight-wheelers (colour 6.9 apart: the same paint). Gangs and Syndicate read apart by
  shape and size and were left alone.
- Side-on the Condemned pair differ more (0.67: dozer blade and tracks vs truck wheels), but side-on is the rarer view.
- Sheets: `build/class-look/<size>/sheet.png` (copied to `_agents/streams/references/round15/fleet/`).

### F2: the class lamp (free; art only)

`ClassMark` (`game/theme/roster/class_mark.gd`, hooked from `dozer_part.gd`): rotating amber beacons on the roof of
the two confused IFVs (a pair at the rear, one forward), seated on the drawn roof by a vertex scan, with an additive
flare that flashes as each lamp turns (phases differ per vehicle). The tanks carry none: *the one with amber lights is
the IFV*. Amber because it is neither team colour, it is the Condemned's hazard amber, a garbage truck wears them, and
`art_direction.md` already lists "amber beacons" in the look. `--no-class-mark` turns them off (his A/B).

| pair (72 m, desktop) | lit difference mean before → after | worst heading before → after | IoU |
|---|---|---|---|
| Condemned | 84.1 → **92.4** | 69.3 → **77.0** | unchanged (0.72 / 0.89) |
| Law | 102.2 → **112.0** | 91.8 → **107.8** | unchanged (0.78 / 0.87) |

The number moves ~10 % because the lamp is a few dozen pixels of a ~7,000-pixel vehicle; the eye picks it out first
(see the frames). It cannot change a shape, which is what F3 is for.

Tests: `tests/test_units_class_look.gd` (5, the instrument's arithmetic), `tests/test_units_class_mark.gd` (3: the
marked IFVs carry lamps and no tank does; every lamp sits on the drawn roof within 0.12 m -- it failed with the lamps
placed before the tank had sized its hull, front and rear swapped; the collider is the catalog's box).

**Sim baseline: pre-registered UNMOVED** (art only: no collider, nothing the simulation reads).

### F3: the page (`db` declared)

**https://claude.ai/artifact/KDZKwAhyD1JNAnySsfwMeh** (version 1, private, `db` declared; collection `decisions/<id>`).
**`db` last read 2026-10-02 09:59 UTC: five decisions, all tapped 09:34 UTC, no words** (dump:
`references/round15/fleet/page_db/`; applied with `make art-apply-decisions`, `assets/review/review.json`):
- **APPROVED `ifv_r15_a`**, the crash-tender wedge, as the Condemned IFV (rejected: `ifv_r15_b` half-track, `ifv_r15_c` van).
- **APPROVED `law_ifv_r15_a`**, the tracked police APC, as Law's IFV (rejected: `law_ifv_r15_b` MRAP).

(At 09:31 UTC, minutes after publishing, it was empty.) On it: the BEFORE and AFTER class-look
sheets, then five cards, each opening with what APPROVE costs and changes (lesson 222):

| group | ids | APPROVE |
|---|---|---|
| The Condemned · IFV | `ifv_r15_a` crash-tender wedge, `ifv_r15_b` caged half-track, `ifv_r15_c` stubby prison van | ~15 credits: replaces the garbage truck |
| The Law · IFV | `law_ifv_r15_a` tracked police APC, `law_ifv_r15_b` 4×4 riot MRAP | ~15 credits: replaces the Retired APC |

At most one per faction, so at most 30 credits more. **The orchestrator (2026-10-02): no image-to-3D and no box
change tonight even if a tap lands** -- read the `db`, record the tap here, leave the paid step for its daytime
message. **After that message:** read the `db`, `make art-apply-decisions`, then
image-to-3D, the split (`build_roster.sh` / `build_faction_parts.py`), the −Z test, `test_theme_unit_scale`, and the
class-look numbers again. **Its box is not tonight's:** a low concept fit at today's 7.54 m length draws lower than
the 3.70 m collider; the box change is a CP for the orchestrator (it moves the sim baseline), never folded in silently.

### F4: the lineup as a standing test

- **The number, headless:** `ClassLook.raster_silhouette` projects every drawn triangle through his camera (21°, FOV
  35°, 72 m, 810 rows) and fills a bitmap, no renderer, so it runs in `make test` (~16 s laptop, both tests).
  `tests/test_units_class_lineup.gd`: every faction's scout, IFV and tank, every pair, five headings, worst heading
  must stay under **0.80**, except the two pairs on the page, held at today's + 0.03 so they cannot get worse
  (`tank/ifv` 0.93, `law_tank/law_ifv` 0.90). When an approved IFV lands, drop its line.
- **Raster vs renderer** (worst heading): Condemned 0.90 vs 0.89, Law 0.87 vs 0.87, Gangs 0.16 vs 0.16, Syndicate
  0.50 vs 0.51. Mutation: a 0.70 ceiling fails naming `gang_ifv/gang_scout` 0.73 (away) and `syn_ifv/syn_scout`
  0.72 (toward).
- **A finding nobody asked for:** the Gangs' Gun Truck and Rat Rod (0.73) and the Syndicate's Limousine and Skimmer
  (0.72) are the nearest pairs after the two on the page — small, close in size, from behind. Not reported by
  him; under the ceiling; worth his eye on the lineup frame.
- **For his eye:** `make remote T="class-look LINEUP=1 CLASS_LOOK_SIZES=1920x1080"` → `lineup_away.png`,
  `lineup_quarter_away.png`: all twelve in one frame at his pose, labelled (`references/round15/fleet/lineup_*.jpg`).
  Looked at: from behind, the lamps separate both IFVs from their tanks; the Rat Rod/Gun Truck and Skimmer/Limousine
  are the closest remaining pairs, as the test's numbers say.

### F3 built (2026-10-02, after the orchestrator's go)

- **Image-to-3D:** `ifv_r15_a_t2` (task `01a0fc3a-5f39-700f-...`), `law_ifv_r15_a_t2` (`01a0fc3a-5f39-7010-...`), 15 each,
  ledger 725 → **695**. Raw: wedge 1.00 × 0.46 × 0.71 (l × h × w) -- the 0.71 is its lowered side ramp lying on the
  ground; the body is 0.49 wide. Tracked APC 1.00 × 0.62 × 0.62 (an M113 is 1 : 0.51 : 0.55: barely squashed).
- **Split by regions** (the tank heuristic took a roof plate / a roof cable for the gun): wedge = 318 hull, 9 turret,
  3 gun, **3 dropped** (the ramp: `--drop-box`, new in the region splitter); APC = 330 hull, 23 turret (its weapon
  station and gun are one island, so no weapon part; round 11's `law/ifv` gun cut and weapon files are gone).
- **The box (CP, `d7b52675` alone):** lengths held, width/height from the meshes: ifv 3.75 × 3.08 × 7.54 (was
  2.86 × 3.70), law_ifv 3.86 × 3.56 × 6.26 (was 3.44 × 4.11). The wider boxes raise the turret scale (Tank:
  min(w/2.4, l/3.6), the simulated muzzle reach) 1.19 → 1.56 and 1.43 → 1.61: **that is the sim change, pre-registered
  MOVED** (ifv is in the baseline match). **Simulated pivots unchanged**: the drawn turrets are centred on them
  (`--center`, the gun `--shift-from`); `turret_mount` carries only the drawing lift (y). Probe: rings 0.00 / 0.12 m
  from the pivots, 99 % / 98 % above the roof. Not changed: law_ifv `locomotion: wheels` (his call).
- **A first CP (`0cb15621`, never merged, removed from the branch)** put the pivots under the turrets as modelled
  (TURRET_PROBE_RING, new): builder0 failed combat_mechanics' autocannon range and IFV tracking and
  test_tank_turret_mount (muzzles 2.8 / 2.5 m past the noses). The lesson: on a unit combat tuned, the drawn turret
  moves to the pivot, never the pivot to the drawing (the burner could move its pivot because its muzzle stayed in its box).
- **The number (laptop raster, his pose, worst heading):** Condemned tank/IFV **0.90 → 0.69**, Law **0.87 → 0.79**.
- **Rendered at his pose (`make class-look`, builder0, `d7b52675`, desktop; phone within ±0.01):**

  | pair | IoU max before → after | IoU mean | drawn length ratio | lit difference mean |
  |---|---|---|---|---|
  | Condemned bus / IFV | 0.89 → **0.69** | 0.72 → 0.61 | 0.98 → **1.29** | 92.4 (lamps) → 79.8 |
  | Law Assault Gun / IFV | 0.87 → **0.79** | 0.78 → 0.77 | 1.17 | 112.0 → 116.0 |

  The Condemned pair is now told apart by shape from every side and by length; its lit difference fell because the
  new IFV is the bus's own blackened gunmetal (the garbage truck was grey) -- the lamps carry the colour cue. Law's is
  told apart by running gear and height; from a quarter they are still the most alike pair in the roster (0.79).
- **Looked at** (`references/round15/fleet/`): `class_look_new_ifvs.jpg` (five headings), `lineup_new_ifvs_*.jpg`
  (all twelve at his pose), `facing_new_ifvs_tint.jpg` (noses −Z, turrets magenta centred on the roof, guns yellow
  forward, lamps clear of the sweep).
- **builder0 check of `d7b52675`:** `make check exited 2` with ONLY sim-baseline failing, as pre-registered
  (`6313a38d7ecd99bb` → **`05df1d55ba49cde1`**, glibc-2.43); **1831 passed, 0 failed**; scenario_perf NOT JUDGED
  (loaded, 1.81×). The orchestrator records the baseline (`make sim-baseline-adopt`).
- The drawn barrel tips are short of where rounds leave (the pipeline warns: ifv and law_ifv by ~1.5 m in turret
  space): not stretched -- round 2's stretched barrel is what made the old IFV draw as long as the bus.

### Next steps

1. The orchestrator records the baseline twice after `d7b52675` merges (the CP).
2. His eye on the two new IFVs in play (What to playtest), and whether the lamps stay now the shapes differ.
3. If he wants law_ifv to drive like a tracked vehicle: locomotion `tracks` is a handling change (its own CP).

### Questions for the lead

- ANSWERED on the page 09:34 UTC: the crash-tender wedge and the tracked APC; both now built.
- Law's tracked APC still handles as `wheels` (and the lengths were held, not re-derived from the new vehicles):
  his call if either should change.
- The lamps themselves are his to judge in play: `make skirmish` (Condemned or Law; IFVs and tanks), against
  `CLASS_MARK=off make skirmish`. Shipped ON (free, reversible, measured); say "lamps off" and the default flips.

### Requests to other streams

None.

### What to playtest

- The page above (his phone is fine): judge the lamps on the AFTER sheet, and pick a shape or none.
- `make skirmish`, pick the Condemned, an army with Tanks and IFVs: from behind, the IFVs carry flashing amber lamps;
  `CLASS_MARK=off make skirmish` is the same game without them.
- Pictures without playing: the page; `make remote T=class-look` (sheets per size).

### Known issues

- An approved concept would need a box change for its collider (a CP, the orchestrator's call): the page says so.

### Git-ignored files that exist ONLY in this worktree (rescue before removing it)

- `assets/incoming/meshy/{ifv_r15_a,law_ifv_r15_a}_t2.{glb,json,base_color.png,metallic.png,normal.png,roughness.png}`:
  the two approved 3D models (30 credits; `build_roster.sh ONLY=ifv` and `build_factions.sh ONLY=law_ifv` rebuild
  from them). Also copied to `builder0:~/tank_squad/fleet_models/` for the turnarounds.
- `assets/incoming/meshy/{ifv,law_ifv}_r15_*.concept{.png,.json}`: the five raw concepts (their Meshy task ids are in
  the `.json`, needed for `--image-task` within ~3 days; after that `--image assets/review/images/<id>.jpg`, which is
  committed). Nothing else under `assets/incoming/` is new.

### Merge notes

- **On main already:** `b082a464`, `40a2cb3d`, `912f9097` (the orchestrator). After them: `acfb2412` (art, red
  alone), `88725af4`, `498cbbd5`, **`d7b52675` the box CP (merge here; baseline MOVED)**, then docs.
- `game/units/units.gd` edited in `d7b52675` only (ifv, law_ifv: hull_size, turret_mount lift, blurb; the recipes and rebuilt parts ride with it because a centred turret is placed against the pivot), with the
  orchestrator's go for this CP.

- Shared-file edits: `mk/fx.mk` (the `class-look` target, additive). `game/theme/cyberpunk/dozer_part.gd` is fleet's.
- New: `game/theme/roster/class_mark.gd`, two shaders beside it, `game/theme/gallery/class_look.gd`,
  `tools/assets/class_look_sheet.py`, three tests (`test_units_class_{look,mark,lineup}.gd`), `assets/review/batches/round15_ifvs.json`, five concept images.
