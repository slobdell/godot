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

_(the worker keeps this current: plan, done with numbers and hashes, decisions, questions for the lead, requests to
other streams, known issues, what to playtest, merge notes)_
