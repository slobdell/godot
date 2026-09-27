# Stream: fleet (the fire engine he approved and the bus he approved, built)

> Read [`game_design.md`](../game_design.md) *Round 12 direction* (both parts), *Round 11: the lead's verdicts* and
> *Factions*; then [`art_direction.md`](../art_direction.md), [`workstreams.md`](../workstreams.md) (round 12: ownership,
> CP1, C12.1, C12.6, C12.7), and the archived round-11 brief `archive/round11/fleet.md` for the survey, the tools and
> the pipeline as they stood (do NOT work from its backlog). **You own** the vehicle art and its proportions:
> `game/theme/factions/**`, `game/theme/roster/**`, `game/theme/prison_dozer/**`, `game/theme/cyberpunk/dozer_part.gd`,
> `game/theme/gallery/**`, `assets/pipeline/**`, `assets/review/**`, `assets/meshy_ledger.md`, `tools/assets/**`,
> `mk/assets.mk`, `mk/scale.mk`, the gallery/audit/probe targets in `mk/fx.mk`, `tools/roster_scale.py`,
> `tests/test_theme_unit_scale.gd`, `tests/test_units_*.gd`; **plus two carve-outs**: the `hull_size`, `muzzle_height`,
> `turret_mount` and `scale_reference` VALUES of `tank` and `burner` in `game/units/units.gd`, and
> `Tank._apply_hull_size` / `Tank.turret_pose` in `game/tank/tank.gd`. Not the rest of `tank.gd`, not `game/ai/`.

## The lead's direction

2026-09-26, asking for this round: *"I believe I'd approved a render for a fire truck for the condemned and I haven't
seen that materialize yet."*

2026-09-24, on the fleet page, in order: on the burner sharing the bus's shape — *"I had no idea these were 2 separate
unit that all makes more sense now. We will want to create a different unit type for the burner because it looks
identical to the tank"*; on the round-10 burner concepts — *"I had no idea there was a dedicated burner yet. To keep
things ridiculous this should be based off of an actual fire engine."*

Round 11's standing direction on proportions still holds (his words in `game_design.md` *Round 11 direction*): uniform
within a faction, real-world relative scale (K = 14.0 / 19.8, the round-9 rule), the bus longer than the garbage truck.

## Where things stand (verified 2026-09-26 by the orchestrator; re-verify before acting)

**He is right. The approval exists and nothing was built.** The fleet review page
(https://claude.ai/artifact/JPb1bfR79qKr5amxeEG7RS, `db` declared) holds these taps at **2026-09-24 17:27 UTC**,
dumped verbatim to `_agents/streams/references/round12/fleet_page_db/decisions/*.json`:

| id | decision | what it is |
|---|---|---|
| **`burner_r11_b`** | **APPROVED** | the turntable-ladder fire engine: crew cab forward, the aerial ladder folded back over the body, **the flamethrower nozzle at the ladder's base on the turntable — so the turret turns for free**. Your own page note: *"a ladder truck is really a longer vehicle than a 32 ft pumper, so the model will be squashed a little to fit the box"* |
| `burner_r11_a`, `burner_r11_c` | rejected | the pumper and the 1950s open-cab |
| **`bus_r11_i`** | **APPROVED** | bus b's look (two refs: the long side-on bus for shape, bus b for look), only partly lengthened; *"it would still need some stretch to fill the box"* |
| `bus_r11_h` | rejected | the right length in the wrong look (yellow school bus) |
| **`q_r11_bus_fit`** | **APPROVED** | the question "bus b came out van-shaped — regenerate it long and narrow?" with option D recommended: regenerate, then build the one he picks. He picked I. |

The round-11 stream read the page at 16:00 UTC (the Law size, the round-10 taps, `bus_r10_b` approved and run to 3D at
16:08) and never again; the round closed the same day. So `assets/review/review.json` says `waiting` for all six,
`make art-apply-decisions` was never run on them, and **no image-to-3D was requested for any fire engine, ever.**

**Assets on disk** (`assets/incoming/meshy/`, git-ignored, backed up to builder0 by the 30-minute timer): the three
burner concepts (`burner_r11_{a,b,c}.concept.png/.json`), `bus_r10_b.glb` + textures (the van-shaped 3D, 1.00 × 0.54 ×
0.62 — 1.85:1 against a coach's 3.3:1; never wired in), `bus_r11_{d..i}.concept.png`. **Meshy balance: 809 credits**
(`assets/meshy_ledger.md`, last row 2026-09-24 16:49). An image-to-3D run is ~15 credits.

**What the burner is today:** `Units.PROFILES["burner"]` (`units.gd:360`) is already its own unit type — role
`burner`, faction `condemned`, blurb *"Plow-nosed fire truck with a flamethrower"* — with **no mesh of its own**: it
wears the shared prison dozer, stretched non-uniformly into `hull_size` 2.40 × 2.40 × 6.89 (round 11 set the height back
to 2.40 and exempted it from the shared shape "until it has a mesh"). `tank` (the prison bus) is the same: dozer,
stretched, box 2.90 × 4.08 × 9.70, `bus_r10_b` approved but unusable at its proportions. Both are the only two hulls in
the game that take `Tank._apply_hull_size`'s non-uniform branch, and `tests/test_theme_unit_scale.gd`'s "drawn inside
its own box on every axis" guard skips exactly these two (no hull slot). **The burner has a `turret_mount`** (`units.gd`,
round 10) placed for the dozer roof; it will be wrong for a ladder truck.

**The tools you have** (round 11 built or proved them): `make art-review-status`, `make art-decide ID= DECISION= WORDS=`,
`make art-apply-decisions DIR=<the dump dir> URL=<the page>`, `make assets-generate PROVIDER=meshy` (image-to-3D; every
request appends to the ledger), `make assets-view IN= SPLIT=1` (turnaround, island split), `make assets-inspect`,
`make assets-normalize SLOT=`, `make assets-profile` (slice a model to author a cut box), `make facing-audit` (−Z
arrow), `make turret-probe` (pivot vs roof vs turret art, headless), `make roster-scale` (the table and the lineup
frame), `make assets-check` (slot contracts), `tools/assets/build_factions.sh` (orientation per model, typed by hand).
Round 11's lessons 214–219 are about your paths; 215 (image-to-image keeps the reference's proportions; multiple
references AVERAGE) and 216 (a side view hides a width fault) are the two you will meet again.

## Backlog (in order)

**F0. Record his taps before anything else** (one commit). Apply the six decisions from the dump to `review.json`
(`make art-apply-decisions` if it reads the dump's shape, else `art-decide` per id with `WORDS=` naming the page and the
UTC time), so `make art-review-status` shows two approvals waiting for 3D and nothing `waiting` from round 11. This is
C12.1; it is also the audit trail for the credits you are about to spend.

**F1. The fire engine: `burner_r11_b` → 3D → the burner's own hull.**
1. Image-to-3D from `burner_r11_b.concept.png` (~15 credits; ledger row). Look at the result from FOUR views before
   anything else (lesson 216): three-quarter, side, top, front — is it a ladder truck, is the ladder on top, is the
   turntable where the concept put it, does it face the way the pipeline will call forward.
2. **Its proportions decide its box, not the other way round** (the round-9 rule): pick the real-world reference
   (a turntable-ladder truck is ~10–12 m; say which, cite the length) and record `scale_reference` on `burner`; the
   box comes from `SizeLook.box_at_length` at reference × K. Expect the burner to get LONGER than 6.89 m. If the model
   came back squashed toward the concept's proportions (lesson 215), say by how much and decide: accept the reference
   length with the model refit, or regenerate with a reference that carries the length — **do not stretch it
   non-uniformly**; that is the defect he called deformed.
3. Split hull from ladder/turret (`assets-view SPLIT=1`, `assets-profile` for the cut box): the turntable and nozzle are
   the turret part (`unit.burner.turret`), the ladder rides WITH the turret if it is on the turntable in the model,
   else stays on the hull. Normalise into `unit.burner.hull` (+ turret), `assets-check` green, the −Z facing test
   (`tests/test_units_*` from round 11) extended to `burner`, `turret-probe` showing the pivot ON the turntable and
   above the roof; a new `turret_mount` derived from the mesh (R5's `driving_bounds()` pattern), recorded in
   `slot_contracts.md`.
4. The muzzle: the flamethrower's `muzzle_height` from the mesh; the flame FX origin must leave the nozzle, not the
   dozer's old roof point (check `make fx-shots SHOWCASE=` for the burner, or the gallery).
5. **The lineup frame** at his pose: burner beside tank (bus) and ifv (garbage truck), before/after. He must be able to
   tell the burner from the bus at 49 m — that was the whole complaint.
6. The `hull_size` change is **CP1**: put it (with the bus's, if F2 moves it) in ONE commit after the art commits, name
   the green hash, and pre-register the baseline MOVED. The orchestrator records it; you never do.

**F2. The bus: `bus_r11_i` → 3D → `unit.tank.hull`.** Same steps. Its known caveat is on the page: I is bus b's look at
part of a coach's length, so it "would still need some stretch to fill the box" — measure the 3D's aspect first. The
box is 2.90 × 4.08 × 9.70 (his ruling: longer than the 7.54 m garbage truck, taller in proportion, `R6`). Options, in
order of preference: (a) refit uniformly by length and let width/height fall where the mesh puts them, then re-derive
the box from the mesh at 9.70 m and see whether it still tops the garbage truck in height (if it does, the box moves in
CP1 and the readout says so); (b) a mild uniform-then-length stretch ≤ 1.2:1 stated in the manifest note; (c) if the
mesh is still a van (< 2.5:1), do NOT ship it — put a pair on a page with `db` (the van at its own shape vs today's dozer)
and let him pick, and say so in Status. `bus_r10_b.glb` stays on disk as the record of why.

**F3. The burner in play.** `make skirmish` as the Condemned (`--player-faction=condemned` or the picker): does it
drive, turn, aim and burn like a fire engine, does the ladder clip its own cab when the turret traverses (the traverse
limit in the profile if it does, stated), does the 14-triangle-sliver rule from round 11 refuse any new stray stick.
Frames at his pose in Status.

**F4 (stretch). The War Rig's muzzle** (`verification.md` *A drawn gun is not a simulated muzzle*): the simulated pivot
is in the tractor frame; the drawn gun rides the trailer; ~0.45 m sideways at a 35° bend, ~0.7 m at 65°. **Measure
whether a player can feel it before changing the simulation**: a scripted rig firing at a fixed target through a bend,
frames at his pose with the tracer and the drawn muzzle. If the gap reads on screen, the fix is the simulated pivot
following the hinge — a SIM change that moves the baseline and belongs in its own commit behind CP1, declared. If it
does not read at 49 m, write that down with the frames and stop.

## How to verify

- `make remote T=check` green on every commit you name; `make assets-check`, `make turret-probe UNITS=burner,tank`,
  `make facing-audit UNITS=burner,tank`, `make roster-scale` (the table AND the lineup frame — look at it).
- `make remote T=vehicle-gallery` / `assets-unit UNIT=burner` for the close-up; `make skirmish` for the default path.
- Every Meshy request on `assets/meshy_ledger.md` with the balance after; every decision in `review.json` with his
  words and the UTC time; C12.7's half-balance stop.
- The sim baseline: pre-registered MOVED at CP1 (boxes), UNMOVED for every art-only commit (a move there is a finding).

## Don't touch

`game/ai/**`, `game/tactics/**` (squad's), `game/camera/**` (camera's), `game/theme/arena_kit/**` (arena's terrain,
airship's airship), `game/audio/**` and `game/announcer/**` (audio's), `game/units/units.gd` beyond the two units'
named values, `game/tank/tank.gd` beyond the two functions. No balance changes (C12.6).

## Waiting on the lead

Nothing blocks F0–F3: the two approvals are recorded (C12.1). F2(c) and any NEW concept go to a page with `db`.

## Status

_Updated 2026-09-26 (late evening, laptop clock) by the fleet worker. Numbers: laptop unless marked builder0; commit
named. The fleet page's `db` was last read **2026-09-27 06:08 UTC**: `decisions/bus_r12_mv` absent (UNCONSUMED); at 04:1x UTC all
14 older decisions were identical to the round-12 dump._

### Where it stands

**Tip green, merge here: `a765143b`**: builder0 `>> remote: make check exited 0`, 18 targets, **1732 passed, 0 failed**
(test_units_burner's 6 in the log), sim-baseline `01ab39b592cc9837` unmoved, determinism `b83a374ce2fcde37`. Everything
after it is docs (this Status). CP1 (`3b2fb346`) is already on main as `0d5abb4e`.


| item | state | commit |
|---|---|---|
| F0 his taps recorded | **done** (6 decisions from the dump; nothing from round 11 left `waiting`) | `d4f7cfc9` (builder0 check green: 1726 passed, 0 failed, sim-baseline `01ab39b592cc9837` unmoved) |
| F1 the fire engine | **built** -- art `fcb1a725`, **CP1 = `3b2fb346`**: builder0 `>> remote: make check exited 0`, 18 targets, **1732 passed, 0 failed**, sim-baseline `01ab39b592cc9837` **UNMOVED** (the burner is not in the baseline match), determinism `b83a374ce2fcde37` | see below |
| F2 the bus | **not shipped (F2(c))**: bus I's 3D is a van (2.04:1). A turnaround of the same design (`bus_r12_mv`) is registered for his page | `093ef868`, `cfe8d947` |
| F3 the burner in play | **done (measured, not tuned)**: matchups before/after below; flame frames | `d0979a20` |
| F4 War Rig muzzle (stretch) | **measured, NOT changed**: does not read at 49 m (below) | this commit |

**Credits:** 809 -> 779 (the two approved image-to-3D, 15 each) -> 770 (the bus turnaround concept, 9). All on
`assets/meshy_ledger.md`. Half-balance stop (C12.7) would be ~385; nowhere near.

### F1: what the fire engine is, measured

- **The model** (`burner_r11_b`, image-to-3D `01a0e118-15ff-...`, meshy-t2): a red two-axle fire engine, nose -X,
  spiked plow, crew cab, pump panel, a ladder RACK on the rear body (not on the turntable), and the flamethrower as a
  monitor on a pedestal column behind the cab. Raw proportions 1.00 x 0.55 x 0.42 (l x h x w) -- looked at from four
  views plus split views (`make assets-view`), then side, top and quarter in-game frames (`make facing-audit TINT=1`).
- **Split** (`ONLY=burner tools/assets/build_roster.sh`, region boxes from `make assets-profile` slices): the head on the
  pedestal = `unit.burner.turret` (527 tris), the nozzle = `unit.burner.weapon`, the ladder rack, pedestal column and
  cab = hull (9,857 tris). The ladder stays on the hull because in the model it is not on the turntable.
- **Its box, from its proportions (the round-9 rule, no stretch):** reference changed to a *rear-mount aerial ladder
  truck on a single rear axle (75 ft quint class), 35 ft = 10.67 m* (a class figure: single-axle 75 ft aerials run
  ~34-36 ft; the model has two axles, so a tandem 100 ft aerial would overstate it) -> 10.67 x K = **7.54 m**, and
  `SizeLook.box_at_length` gives **2.99 x 3.30 x 7.54** (was 2.40 x 2.40 x 6.89). Squashed? Yes, like every Meshy
  vehicle: a real 35 ft aerial is ~4:1 long:wide, the model 2.4:1, so at 7.54 m it is 2.99 m wide -- in line with the
  roster's trucks (gang_support 3.18 at 6.58, gang_artillery 2.91 at 6.89), narrower than nothing that matters. Not
  regenerated: the width is the roster's convention, not a defect of this model.
- **The ring:** `turret_mount` [0, 3.20, 0.23] (the head's ring at model x +0.03, y 0.145). `make turret-probe`
  (laptop, `3b2fb346` tree): above 100%, lowest -0.01 m, seat gap -0.15 m (seated, not floating). The simulated pivot
  is under the drawn head; with turret scale 1.25 the muzzle (unchanged height 1.14) is at z -3.76, the plow's front.
- **The fire leaves the drawn nozzle:** `game/theme/roster/burner_nozzle.gd` draws the model's nozzle and carries the
  theme's `weapon.flamethrower` fire (cone, glow, light, roar) with its flame starting at the nozzle's tip, at the
  weapon's own length (it undoes the turret's 1.25 scale). `make fx-shots SHOWCASE=burner_flame` (new scene; the
  showcase could not stage a flamethrower before -- it waited for `fired`, which sprays never emit).
- **A pipeline bug found on the way, fixed:** `AssetContracts.unit_pivot` placed turret art at a fixed z 0.2 and
  divided it by min(w,l) against the BUS's box (0.78 here), while the game draws generated parts at the hull's one
  fit and honours `turret_mount`. First result: the head floated **1.39 m** over its pedestal. It now reads
  `Tank.turret_pose` at scale 1. No existing art was regenerated, so nothing else moved.
- **Tests:** `tests/test_units_burner.gd` (6: own art; box = mesh at reference x K and longer than 6.89; every part at
  the hull's one scale -- fails on the old placement; the head seated on its ring; the fire starts at the nozzle tip and
  burns at scale 1; the pipeline's anchor is the tank's pose). Round-11 tests that named the burner as a dozer wearer
  now name the bus only (`test_units_scale.gd`, `test_units_bus_eye.gd`).

### F2: the bus, honestly

`bus_r11_i` 3D (`01a0e118-1600-...`) measures 1.00 x 0.55 x 0.49: **2.04:1 including its blade**, the body alone ~1.5:1.
Brief F2(c): not shipped; the bus keeps today's stretched dozer (2.90 x 4.08 x 9.70, unchanged). The mechanism is
lesson 215 one step further: the image-to-3D service squashes a three-quarter picture the way image-to-image copies a
reference. **The better method:** `bus_r12_mv`, a multi-view turnaround of bus I (refs: bus I + the in-game side view),
whose side and top views DO carry a coach's length (~2.9:1 from above). Building it with multi-image-to-3D (the three
views at once, ~30 credits) is the likeliest way to keep that length. It is a lead gate (C12.1: any further 3D goes to
a page with `db`), registered in `review.json` as `waiting`, going on the page with the burner's frames.

### F3: the burner in play (C12.6: reported, not tuned)

`make remote T="matchups FOCUS=burner SEEDS=3 JOBS=4"` on builder0, the same command on `d4f7cfc9` (before) and on this
branch after CP1; 12 matches a pair (3 seeds x both bases x both colours), W:L:D for the burner:

| vs | before | after | | vs | before | after |
|---|---|---|---|---|---|---|
| gang_scout | 8:0:4 | 11:0:1 | | law_artillery | 12:0:0 | 12:0:0 |
| gang_ifv | 7:5:0 | 8:4:0 | | law_suppressor | 3:9:0 | 6:6:0 |
| gang_tank | 6:6:0 | 7:5:0 | | syn_scout | 12:0:0 | 12:0:0 |
| gang_artillery | 12:0:0 | 12:0:0 | | syn_ifv | 8:4:0 | 6:6:0 |
| gang_support | 10:2:0 | 9:3:0 | | syn_tank | 0:12:0 | 0:12:0 |
| law_scout | 12:0:0 | 12:0:0 | | syn_artillery | 12:0:0 | 12:0:0 |
| law_ifv | 10:2:0 | 10:2:0 | | syn_lancer | 10:2:0 | 7:5:0 |
| law_tank | 8:4:0 | 8:4:0 | | | | |

**130 -> 132 wins of 180: a wash overall**; the largest moves (law_suppressor +3, gang_scout +3, syn_lancer -3) are
inside what 12 matches can resolve. It drives, reaches and burns as it did; the new box (wider, 0.65 m longer) and the
muzzle at the plow's edge change no matchup a series this size can see. Both arms also print 12 `FAILED ... unknown unit
'law'` lines for a `law.json` pairing -- a pre-existing fault of `tools/matchup_matrix.py` (not fleet's file), identical
before and after. Turret traverse: the ladder rides the hull, the nozzle turns above the rack (nozzle underside 3.59 m
over a 3.30 m roof, `make turret-probe`), and `test_what_turns_with_every_turret_is_drawn_above_its_hull` holds it at 0
and 90 deg -- no traverse limit needed. Not done: an interactive `make skirmish` on the laptop (it opens on the lead's
desktop, trip-up 32) -- that is his playtest below.

### F4: the War Rig's muzzle, measured before moved -- and left alone

New instrument: `make facing-audit UNITS=gang_tank VIEW=top TINT=1 BEND=<deg> TURRET=<deg> MUZZLE=1` draws the
SIMULATED muzzle (`Tank.muzzle_position`) as a green ball and prints `FACING_MUZZLE ... gap_m`, the ground-plane
distance between the drawn gun's pivot (on the trailer) and the simulated pivot (tractor frame). Laptop, this tree:
**bend 0: 0.00 m; bend 35 deg: 0.47 m; bend 65 deg (jackknife limit): 0.84 m** (round 11 estimated ~0.45 / ~0.7).
Frames: `_agents/streams/references/round12/fleet_f4/` (top view, turret 70 and 0).
**Does a player feel it?** At his pose (FOV 35, 49 m, 1080 rows) the frame is 30.9 m tall, ~35 px/m: 0.47 m is ~16 px,
0.84 m ~29 px, and only while the rig is bent AND firing. For scale, every unit's rounds already leave from
`3.2 x turret scale` ahead of the pivot -- for the rig ~2 m past its drawn barrel tip, even straight (the bend-0 frame)
-- and the muzzle fireballs are 2.2-3.4 m across. With the turret at 70 deg the bend's offset lies mostly ALONG the
barrel line (~0.3 m across it). Verdict: **it does not read at 49 m; no simulation change** (the fix would make the
hinge simulation on every peer, S2, and move the baseline for an offset hidden inside the flash). Not rendered: a
firing frame at his exact pose with the tracer -- the arithmetic above is the evidence; if he ever says "the rig's shots
come from the wrong place", that frame is the next step.

### The page (lead gate; `db` declared)

**https://claude.ai/artifact/JPb1bfR79qKr5amxeEG7RS, version 6** (published 2026-09-27 ~05:40 UTC, the same page as
round 11, so his old taps stay in its `db`): the Burner before/after at his pose (`r12_fleet_burner_before_after.jpg`,
`lineup_bus.png` from builder0 on `d4f7cfc9` vs `3b2fb346`), the turret + flame frames, bus I's van-shaped 3D, and ONE
card: `bus_r12_mv`. **Read its `db` (`decisions/bus_r12_mv`) before this brief is archived** (lesson 220), then
`make art-apply-decisions DIR=<read_db dir> URL=<page>`; on APPROVE:
`tools/assets/generate.py --provider meshy --slot tank.hull --multi-image --review-item bus_r12_mv --ai-model meshy-7
--view <concept.png> --view <concept1.png> --view <concept2.png> --name meshy/bus_r12_mv` (views in
`assets/incoming/meshy/`, git-ignored; the concept task is `01a0e138-20b2-777c-8371-c86a2f66e1c3`).

### Questions for the lead

1. **The bus:** approve `bus_r12_mv` for 3D (~30 credits)? It replaces today's bus only if the 3D measures >= 2.8:1.
   (On the page. UNCONSUMED until the repo has read its `db`.)

### Requests to other streams

None. The orchestrator merged CP1 as main `0d5abb4e` (`3b2fb346`, --no-ff). A first SendMessage by name failed; the reply
to its own address worked (page URL and db time sent 06:08 UTC).

### What to playtest

- `make garage` (tier 2 unlocks the Burner): buy Burners, FIGHT, and pick the Condemned in the faction picker; or `make skirmish` and pick the Condemned:
  a red fire engine with a ladder rack, its flamethrower head turning on the pedestal behind the cab, the flame leaving
  the nozzle. Beside the bus it should never be mistaken for one.
- Pictures without playing: the review page above; `make remote T=roster-lineup` (`lineup_bus.png`);
  `make fx-shots SHOWCASE=burner_flame`; `make facing-audit UNITS=burner VIEW=quarter TINT=1`.

### Known issues

- The bus is still the stretched dozer (by design until he answers `bus_r12_mv`).
- The flame cone reads faintly side-on (`burner_flame_stream`); it is the theme's flamethrower unchanged, only moved.
- `tools/matchup_matrix.py` fails its `law.json` pairings (`unknown unit 'law'`), before and after this work.
- Pipeline note: parts normalised BEFORE round 12 were placed with the old `unit_pivot` formula; they were not
  regenerated and draw as before. Re-running `build_roster.sh` for them would now place their turrets as generated
  relative to the hull at the tank's pivot -- look at the turret-probe numbers before committing such a rebuild.

### Merge notes

- **Merge `fcb1a725` (art) and CP1 `3b2fb346` together, CP1 last**; the art commit is inert without CP1's wiring.
  Pre-registered MOVED "if the burner is in the baseline match"; measured **UNMOVED** (`01ab39b592cc9837` on
  builder0 at `3b2fb346`) -- it is not in that match. So CP1 needs no baseline record; it still changes every
  burner's collider (2.40 x 2.40 x 6.89 -> 2.99 x 3.30 x 7.54) and muzzle reach (turret scale 1.00 -> 1.25, muzzle
  from 0.65 m inside the plow to its front edge) in any match that fields one.
- Shared files touched: `game/theme/game_theme.gd` (three slot lines, additive); `game/units/units.gd` (burner's
  `hull_size`, `scale_reference`, `turret_mount` values + comments); new wrappers in `game/theme/cyberpunk/units/`
  (`unit_burner_{hull,turret,weapon}.tscn`); `tests/test_assets_factions.gd` (the pipeline's own test, one assertion
  replaced); `game/theme/fx/bench/weapon_showcase.gd` (a `burner_flame` scene and a `sprayed` hook, additive);
  `_agents/verification.md` (the War Rig section closed with F4's numbers).
