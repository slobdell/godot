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

_Updated 2026-10-02 ~10:30 UTC by the fleet worker. Numbers: builder0 unless marked laptop; commit named._

**Tip green, merge here: `40a2cb3d`** -- builder0 `>> remote: make check exited 0`, **1831 passed, 0 failed**, 18 targets
passed + `scenario_perf` NOT JUDGED (loaded, ref 1.83x; it refused the same way on the untouched baseline `85703220`),
sim-baseline UNMOVED (pre-registered: art only). After it: this Status, the taps in `review.json`, reference frames.
`b082a464` (F1+F2) is already on main.

### Where it stands

| item | state | commit |
|---|---|---|
| F1 measure the confusion | **done**: `make class-look` (new); it is a Condemned AND a Law problem, worst from behind | `130f42ed` (+ fixes in `b082a464`) |
| F2 what is free | **built**: amber class lamps on the Condemned and Law IFVs; tanks unmarked | `b082a464` |
| F3 the paid route | **HE TAPPED (09:34 UTC): `ifv_r15_a` and `law_ifv_r15_a` APPROVED**, the other three rejected; recorded. Image-to-3D (≈30 credits) waits for the orchestrator's daytime go | `58a20f98`, taps in the commit after `40a2cb3d` |
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

### Next steps (the approved two, for the daytime go; nothing spent on them yet)

1. `tools/assets/generate.py --provider meshy --slot unit.tank --review-item ifv_r15_a --smart-topology --polycount 15000
   --name meshy/ifv_r15_a_t2` (and `law_ifv_r15_a`): ~15 credits each, ledger 725 → ~695. The Meshy concept tasks
   expire ~2026-10-05; after that pass `--image assets/review/images/<id>.jpg`.
2. Look at the raw models (`make assets-view IN=… SPLIT=1`): the squash lesson (215) -- measure length:height before
   anything else; both were asked LOW, so a squashed result is the risk to check.
3. Split and fit: the Condemned IFV through `build_roster.sh` (slot `unit.ifv.*`), Law's through
   `build_faction_parts.py`; −Z test, `test_theme_unit_scale`, `make turret-probe`, `make facing-audit TINT=1`.
4. **The box is a CP:** both are lower than today's colliders (3.70 m and 4.11 m tall); `SizeLook.box_at_length` gives
   the new boxes; the change moves the sim baseline and is the orchestrator's call (`units.gd` is not fleet's this
   round). Until then the art would be drawn inside the old box: say so, don't ship that silently.
5. `ClassMark.MARKS`: decide with him whether the lamps stay once the shapes differ (the new concepts carry amber
   beacons in their own art); `test_units_class_lineup.gd`: drop each pair's KNOWN_ALIKE line once its new IFV is in
   and measure it against 0.80.

### Questions for the lead

- ANSWERED on the page 09:34 UTC: the crash-tender wedge and the tracked APC. Words optional; none given.
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

- `assets/incoming/meshy/{ifv,law_ifv}_r15_*.concept{.png,.json}`: the five raw concepts (their Meshy task ids are in
  the `.json`, needed for `--image-task` within ~3 days; after that `--image assets/review/images/<id>.jpg`, which is
  committed). Nothing else under `assets/incoming/` is new.

### Merge notes

- **`b082a464` is already on main** (the orchestrator merged it, 2026-10-02). The tail after it: F3's page record,
  F4's test and lineup, docs.

- Shared-file edits: `mk/fx.mk` (the `class-look` target, additive). `game/theme/cyberpunk/dozer_part.gd` is fleet's.
- New: `game/theme/roster/class_mark.gd`, two shaders beside it, `game/theme/gallery/class_look.gd`,
  `tools/assets/class_look_sheet.py`, three tests (`test_units_class_{look,mark,lineup}.gd`), `assets/review/batches/round15_ifvs.json`, five concept images.
