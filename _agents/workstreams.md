# Workstreams: the current round

> **Round 10, launched 2026-09-20 (evening).** How rounds work (roles, lifecycle, the worker contract, the kickoff
> prompt) is in [orchestration.md](orchestration.md): read it first. **Round 10's streams, checkpoints, ownership and
> contracts are in the next section.** The round-9 section after it (S1–S6, the research-catalogue sequencing) is
> still in force where it is not superseded here; rounds 1–9 are archived in `streams/archive/round1..9/`; the
> round-6 material further down (contracts N1–N7, ownership, invariants) is still in force where it is not superseded.

## Round 10: the nine streams (launched 2026-09-20, evening)

**Goal: the playability blockers he named, in the order they block him.** His words are in
[`game_design.md`](game_design.md) *Round 10 direction*. He cannot judge unit intelligence until a right-click is obeyed
at once, any selection can carry an element order, and a squad can be driven through the Terminus streets; after that
come the walls and the yaw, then the look (walls of light, the blimp, the turrets, the bus), then the announcer. Every
stream's first backlog item is one of his sentences. **The acceptance test for the round is his: `make skirmish
ARENA=terminus`, drive squads through the streets, give ad-hoc selections element orders, and see the lights.**

| Stream | Brief | Round 10 | Checkpoint |
|---|---|---|---|
| **control** | [streams/control.md](streams/control.md) | **The unanswered right-click** (a player's order replaces an in-flight one within one input frame, on the default path, with the readout saying what was ISSUED); **squad orders for a mixed selection** (R1 narrowed: a Form-squad action and a reason on the greyed buttons; the regroup behaviour stays); the refused-order banner and `ungrouped=N` readout | — |
| **squad** | [streams/squad.md](streams/squad.md) | **a player's order pre-empts a task, a hold and co-arrival pacing**; the 40 s settle on a 20 m move; slot pitch from the turning envelope (decided: hulls do not clip while dressing); the base-of-fire scenario; `_is_clear`; Delta's margin | — (CP1 withdrawn) |
| **arena** | [streams/arena.md](streams/arena.md) | **The Terminus streets are lanes** (containers off the lanes; every lane's narrowest drivable width asserted, not watched; the arena page shows the before/after at his pose); **prop collision parity** (R3: what a hull can touch has a collider; the lamps); the spawn grid gives a hull room to turn (the half-diagonal, scale's round-9 handover) | **CP2** = the Terminus lanes green, merged alone, early (nav's drive test runs on it) |
| **nav** | [streams/nav.md](streams/nav.md) | **Units still drive into walls**: the Terminus drive test (a squad ordered street to street on the default path: zero wall contacts, arrival, measured), what a wall contact IS (a counter on the plant, published), the wedged regime, the obstacle-tiling row; every clearance constant names the motion it licenses; `Avoidance.radius_of` (the seventh disc site); the held wheeled hull's facing; the seam (Movement vs CombatMotion) as the structural item, measured before moved | — |
| **combat** | [streams/combat.md](streams/combat.md) | **The rigs yaw through walls**: the plant predicate (why a clear hull refuses every candidate yaw for 1135 ticks), the ordering, then diagonal spacing as a candidate; the constraint returns ON only when five_squads passes with the corridor numbers kept; ORBIT radius reads hull length (the engine-deck scenario); the artillery scenario; the gangs-vs-law series with `match.hull_disc` (stretch) | **CP4** = the constraint ON (baseline moves), merged alone if it happens |
| **feel** | [streams/feel.md](streams/feel.md) | **The blimp he asked for, in HIS frame** (R7); **the turret mounts** (R5: a per-unit mount in the hull frame, derived from the mesh, applied on all three axes; Condemned and gangs first); **the Condemned bus reads bigger than the garbage truck** (R6: his eye rules over the reference for `tank` and `burner`; concept page for a paid bus mesh); the per-faction rim light | **CP3** = the bus box (baseline moves), merged alone; the orchestrator records |
| **show** | [streams/show.md](streams/show.md) | **The light show on the building WALLS**: per-window addressable primitives (custom data per instance, the S6 hook rule), effects composed from them (chases, waves, sweeps, sign flicker, a kill ripple that crosses a facade), judged by HIS eye against a 1990s-baseline frame, not a luminance bar; the frozen re-shoot and the louder pair first (the fastest thing he can see) | — |
| **announcer** | [streams/announcer.md](streams/announcer.md) | **More lines on the same themes** (deepen every thin moment to a real pool; same voices, same humour direction), audited, on the review page, **generated this round** (R8: he authorised the spend); the ledger; speech-to-text verified; the transcripts and the Booth Monitor re-cut | — (runs in total isolation against fixtures) |
| **terrain** | [streams/terrain.md](streams/terrain.md) | **The maps with water, pits and bridges that never materialised** (added 2026-09-20 evening on his ask): the `arena.terrain` art first (the reason he could not see it), then two maps that use the round-7 mechanism with mirrored objective pairs (a river with two bridges; pits as kill zones), each judged by `spread` > 0, a paired series showing the expensive route used, and his eye on the arena page; bridges are lanes under R4 | — (its maps are new files; Godot on builder0) |

**Why nine (the ninth added the same evening):** the lead asked for the bridge/pit/water maps he had asked for before; the mechanism has existed since round 7 with no map and no art, so it is a stream of its own on new files, with Godot on builder0. **Why eight before that:** commanding is one problem with two owners (control's input path, squad's task layer) and a contract
between them, so both run; the Terminus streets are the map's fault (arena) before they are nav's; the yaw is combat's
plant and the walls are nav's mover, and round 9 showed they must be measured apart; the look is three streams' paths
(feel, show, announcer's carve-out). Nine sessions are ~3.6 GB on the laptop: **show runs every Godot process on
builder0; announcer is Python and fixtures and runs no Godot beyond `announcer-check`.** If the laptop swaps, start
control, squad, arena and nav first; terrain and show last.

### Checkpoints (round 10)

- **CP1 — WITHDRAWN (2026-09-20 night):** R1 narrowed to a UX item on control's side; nothing of squad's to merge early. control's Form-squad action lands with its own check.
- **CP2 — the Terminus lanes (arena).** Containers off the lanes, the lane-width assertion, R3's parity test, the
  before/after frames at his pose. Merged alone, early; nav's drive test runs on the new map from then on (before it,
  nav measures on the ring road and the avenue's clear halves, and says so). Moves no baseline (the sim baseline's
  match runs on the foundry; pre-registered, and a move is a finding).
- **CP3 — the bus box (feel).** A `hull_size` change is a sim-baseline move by construction (spawn grid, collider);
  merged alone with the lineup frame beside it; the orchestrator records the baseline twice in the same session.
- **CP4 — the plant constraint ON (combat), only if** five_squads passes with the constraint on AND the corridor
  numbers (44.0° → 11.6°, 12.1 → 6.1 m) are re-measured on the same build. Baseline moves; merged alone.

### Who owns what (round 10) — changes to the round-6 table below

| Path | Owner (round 10) |
|---|---|
| `arenas/`, `game/arena/` (including `arena_kit.gd`'s `PROPS` sizes: the collider boxes), `tools/make_arenas.py`, `tools/arena_report.py` and siblings, `mk/arena.mk`, `_agents/arenas.md`, `tests/arena/`, `tests/test_arena*.gd`; **carve-out from combat's C1 (as scale had it in round 9):** the three spawn-grid constants `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING` in `game/match/match.gd` (combat reviews at merge). `tools/roster_scale.py`, `mk/scale.mk` rest with arena (read, not changed). | **arena** |
| `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `tests/announcer/`, `mk/announcer.mk`, and the announcer targets in `mk/audio.mk` (`announcer-*`, `audio-launch-smoke`); `_agents/streams/archive/round3/announcer.md` is its reference. **Carved out of feel for the round**; feel reviews nothing here (the voices and humour direction are the lead's, recorded in `game_design.md`). | **announcer** |
| `game/theme/**` except show's carve-outs (unchanged from round 9) and the announcer paths above; `game/audio/`, `assets/{audio,music}/`, `tools/{assets,audio}/`, `mk/{fx,assets}.mk`, the art docs. **Carve-outs granted 2026-09-20:** (a) an optional `turret_mount: [x, y, z]` key per `Units.PROFILES` entry and its consumer in `Tank._apply_hull_size` (`game/tank/tank.gd`, the three-axis write; combat reviews at merge, mutation-checked test required); (b) the `hull_size` (and `muzzle_height`) VALUES of `tank` and `burner` in `game/units/units.gd` (R6; combat reviews; CP3). | **feel** |
| `game/theme/show/`, `mk/show.mk`, `_agents/lighting.md`, `_agents/show_dials.md`, the `show` key per arena, and the round-9 emission carve-outs from feel (`CityBlock`'s emission paths and `city_block.gdshader`, the perimeter rim, `NeonSigns`, the pools, `CyberMaterials.neon()`). **Extended 2026-09-20 for per-window addressing:** `CityBlock`'s window MESH construction may gain per-instance custom data (a MultiMesh where it is a mesh today) — additive, the silhouette unchanged, feel reviews the look at merge. | **show** |
| New arena layouts (`arenas/<new>.json`; their functions in `tools/make_arenas.py`, ADDITIVE, arena reviews the diff), `game/arena/arena_terrain.gd`, `tests/arena/water_probe.gd`, new `game/theme/arena_kit/terrain/` (the `arena.terrain` slot; feel reviews the look), the `water-probe`/`terrain-*` targets in `mk/arena.mk` (additive), a *Terrain maps* section of `_agents/arenas.md`. Not the existing layouts, not `arena.gd`/`arena_kit.gd` (arena's). | **terrain** |
| everything else | as the round-6 table below: nav, squad, control, combat, orchestrator, shared |

### New contracts (round 10)

| Contract | Owner, where | Consumers |
|---|---|---|
| **R1 Squad orders for a mixed selection (NARROWED 2026-09-20 night, on the lead's words in `game_design.md`).** No transient element is formed automatically: assigning a selection a control group (1–5) already makes it a squad that carries formation and element orders, and the lead calls that good behaviour. The contract is now UX: the greyed task buttons carry a one-line reason the player reads ("these units are in different squads: press Form squad or Ctrl+1–5"), and the card offers a one-click **Form squad** action that assigns the next free group number to the selection and enables the buttons in the same frame. Numbered groups keep today's path unchanged. | control: `SelectionPanel`, `RtsControls.assign_task` | squad (nothing to build; `Element.state()` keeps publishing its split for the readout) |
| **R2 A player's order pre-empts everything.** A new order from the player on a unit or selection replaces that unit's in-flight order, task, hold and pacing within one input frame, always. `Orders._same_order()` never drops a `player` order (its 3 m dedup compares slots, not clicks: two clicks metres apart on a moving squad compare equal); an armed mode (`mode != ""`) cancelled by a right press still issues the move on the NEXT press, and the readout says which happened; `Element.assign()` re-derives every crew's order on the next tick and the re-issue suppression (`element.gd` `_same_place`/`REISSUE_M`) yields to a fresh task. Test: the round-10 regression is an integration test on the default `make skirmish` path — a squad en route, a right-click 40 m off its line, every crew's order changes within 2 ticks. | control: `game/control/orders.gd`, `rts_controls.gd`; squad: `game/tactics/element.gd` | the lead |
| **R3 Prop collision parity.** For every kit prop, the drawn geometry a hull can reach (everything below the tallest hull's height, `law_suppressor` 6.18 m, plus the tallest hull's reach when it yaws) lies inside the prop's collider footprint in `ArenaKit.PROPS`, or the prop is declared `drive_through` and placed where no lane runs. A test asserts it per prop by measuring feel's mesh AABB against the box (arena writes it; a failure names the prop and the overhang in metres). The floodlight is the known offender (footing 2.4 × 3.0 × 2.4; the mast and the 4.2 m head have no collider): arena widens the box or asks feel to raise the head above 6.2 m; either way the test decides. | arena: `game/arena/arena_kit.gd`, `tests/arena/` | feel (meshes), nav (the bake reads the same boxes) |
| **R4 Streets are lanes.** Every declared lane in an arena's `lanes` (Terminus: the avenue, west street ×2, the ring road ×2, and arena adds the east street and the plaza crossings) keeps a continuous drivable width of at least **2 × the widest hull's width after the bake radius** (CORRECTED 2026-09-22 by arena: the widest hull is `syn_artillery` at 4.07 m, so the bar is 8.14 m drivable, physical ≥ 12.14 m at a 2.0 m bake; it is read live from `ArenaLanes.bar()` in `game/arena/arena_lanes.gd`, never from this prose) along its whole length; containers, wrecks and barricades stand on lots, against walls and at kerbs, parallel to the street, never across it. `tools/arena_report.py`'s corridor WATCH line becomes a failing assertion for lanes (it stays a watch line for the open field, the reason it was a watch line still holds there). The arena page shows the before/after pair at his pose (21°, FOV 35, 49 m) for each changed street. Authored chokepoints are allowed only OFF the declared lanes and are listed in `arenas.md` by name. | arena: `tools/make_arenas.py`, `tools/arena_report.py`, `tests/arena/` | nav (the drive test), the lead |
| **R5 Turret mount.** `Units.PROFILES[id]` gains an optional `turret_mount: [x, y, z]` in metres in the hull frame (x right, y up, z forward, the hull's origin at its box centre on the ground); `Tank._apply_hull_size` applies all three (today only y is written and z stays at `tank.tscn`'s +0.2 m for every hull from 2.9 to 14 m). Default when absent: today's `[0, muzzle_height − 0.05, 0.2]`, so nothing moves until a unit is measured. feel derives each value from the mesh's ring (the pipeline's `driving_bounds()` pattern), records it in `slot_contracts.md`, and the sim baseline is pre-registered UNMOVED (the turret is visual; the muzzle height is unchanged; a move is a finding, not a record). | feel: values and the write (carve-out); combat reviews `tank.gd` | control (the marker reads the hull, not the turret), combat |
| **R6 The bus is his eye.** S1's derivation (reference × K) stands for every unit with a mesh; for `tank` and `burner` (no mesh of their own) the lead's ruling on the lineup frame is the source: **the bus must read LONGER than the garbage truck (the Condemned `ifv`, 7.54 m) and TALLER in proportion.** feel picks the numbers (start: length ≥ 1.25 × the ifv's, height ≥ the ifv's 3.70 scaled by the same ratio, width from a coach's proportions), shoots the lineup at his pose, records the chosen reference beside the box, and CP3 merges it alone with the baseline recorded. A paid bus mesh goes through the concept page (2–3 directions) before any 3D. | feel: `units.gd` values (carve-out), `slot_contracts.md`, the concept page | combat (reviews), arena (spawn grid), squad (slot pitch), nav (clearance) |
| **R7 The blimp.** The lead's blimp is a thing he sees while he PLAYS, at his pose (21°, FOV 35, 49 m), not a title element. Geometry: the frame's top edge is 3.5° below the horizon there, so nothing at or above the camera's own height (~17.5 m at his boom) is ever in frame; a blimp that shows in play flies LOW, among the Terminus blocks (24 m tall) and over the far half of the frame, ~10–14 m up, slow, with its own lights and screens, no collider (pre-registered: the sim baseline does not move). feel builds it and proves it with the airship-look sweep: in frame at his pose for a stated fraction of a match, with the frame beside the number. The round-9 airship at 560 m stays as the city's. If the geometry refuses at every candidate, the frames go to him and the choice (title/results element) is his. | feel: `game/theme/arena_kit/airship/`, `arena_dressing.gd` | show (its screens are fixtures), control (the cutaway must not cut it) |
| **R8 Announcer generation is authorised this round.** His words: *"let's burn through some ElevenLabs credits."* Lead gate 1's text approval is satisfied by the standing humour direction (`game_design.md` *The arena announcer*, the 2026-09-15 ruling) plus `make announcer-audit` plus the review page; the announcer stream generates in batches (`APPROVED=1`) without waiting, appends every run to `assets/announcer/ledger.md` with the balance before and after, verifies every clip with speech-to-text, and puts the new lines on the Booth Monitor page for his veto. Spend guidance: the balance is ~109 k credits at launch; the round's target is the thin moments deepened to real pools, roughly 400–600 lines (~30–50 k credits); **stop at half the remaining balance and ask** unless he says otherwise. | announcer: its paths | the lead (veto), feel (nothing to review) |
| **R9 Terrain maps.** A map that carries `terrain` (water, pit, bridge rectangles, mirrored) must also carry a mirrored objective pair so the crossing has a reason (his rule; N7's `objectives` list); every bridge deck and its approaches are LANES under R4 (≥ 6.64 m drivable at the live bake, corners certified with the rig's turning radius, C5); the rim stays below the 1.3 m eye line; the art in the `arena.terrain` slot adds no lights and one draw call per surface kind. Acceptance is three things together: `spread` > 0 on the arena report, unit-time on the expensive route in a paired series against the same map with `terrain: []`, and the lead's eye on the page. Pre-registered: the sim baseline does not move (the baseline match runs on the foundry). | terrain: its layouts and art | arena (reviews the generator diff), nav (the drive test on a bridge), control (the menu, later) |
| **R2a K1 gains `task` (added 2026-09-22 night, squad's request, control's file).** `UnitCommand.KEYS` gains an optional integer `task` (the element's task sequence); `Orders._same_order()` returns false whenever `current.task != order.task`, whatever the source, so an element re-issue that changes only the facing (or an unchanged `follow`) after a fresh player task is never deduplicated. Squad sends the key through a runtime adapter until control's commit lands; control lands it inside its R2 item. | control: `orders.gd`, the K1 keys | squad (`element.gd` sends it) |

### Standing rules for round 10 (in addition to *The standing rules for this round* below)

- **Play the default path.** Every fix in this round is judged on `make skirmish ARENA=terminus` with no flags: a
  behaviour behind a flag the default path never passes has not shipped (lesson 165's shape).
- **A readout says what was ISSUED, not what was intended** (lesson 183): control's banner, squad's element split,
  nav's wall-contact counter, combat's refusal counter all report the thing that happened.
- **Every visual claim is a pair** (show's rule 12): before/after at his pose, one variable moved, the dial and the file
  named in the caption.
- **Baseline moves are pre-registered and merged alone** (CP3, CP4); every other stream pre-registers UNMOVED and
  treats a move as a finding.
- **Every number carries its commit and its machine**; merge at the hash whose check went green; read the wrapper's
  own line.
- **Every A/B states its positive control** (research addendum B12): before an arm's null is reported, a known
  disturbance must move the metric; an arm proves it applied with a counter; shared state is hashed or drained between
  tests. A null without a positive control is "not measured", never "no effect".
- **Series compare arms on the SAME seeds and report discordant pairs** (C6): a cell is a paired comparison over a
  fixed seed list, never two unpaired batches; ~32 paired seeds for a large shift, ~64 to size a component; the
  report prints the discordant counts beside any rate.
- **The clearance vocabulary is four names** (B5): static footprint, swept travel ribbon, turning envelope, combat
  signature. A constant or a reader that does not say which it is gets a comment or a rename in the commit that touches it.

## Round 9: the seven streams (launched 2026-09-19 evening)

**Goal: the research catalogue lands against metrics that can see what the lead sees — and the roster is drawn at
real relative scale.** The catalogue ([`research_catalog.md`](research_catalog.md)) is the algorithm backlog; the lead
added two items while asking for the round ([`game_design.md`](game_design.md) *Round 9 direction*): the War Rig is
still one rigid box, and **every vehicle needs proportional, real-world relative sizing** — the semi resize *"makes the
game much cooler and awesome"* and he wants it for the whole roster.

| Stream | Brief | Round 9 | Checkpoint |
|---|---|---|---|
| **metrics** | [streams/metrics.md](streams/metrics.md) | **A12** trajectory-space metrics (windowed displacement efficiency, signed cusp density, spectral arc length, affine formation residual) that reproduce round 8's oscillation finding from the saved replays; then **T1** parallelise `make check` | **CP1** = A12 green; **CP3** = T1 green |
| **scale** | [streams/scale.md](streams/scale.md) | **The roster at real relative scale** (one factor K anchored by the 14 m rig; every hull = reference length × K; boxes from the mesh via `SizeLook.box_at_length`), the review frame for the lead, and everything that was sized for a 4 m hull: spawn grid, navmesh agent radius, muzzle heights; then **A3** hull-chord cover tables and the `arena-report` WATCH line | **CP2** = the resized roster green |
| **nav** | [streams/nav.md](streams/nav.md) | **A7 → A11 → A1 → A4**, in nav's own order (argued below), A7's priority table written and reviewed before code | — |
| **combat** | [streams/combat.md](streams/combat.md) | **A2** state-dependent switching cost (falsifier: squad's fire-concentration and engine-deck scenarios), then **A3's consumer**; the balance consequences of the resized roster measured, not tuned | — |
| **squad** | [streams/squad.md](streams/squad.md) | **A8 → A9 → A10**, each naming what it replaces by file; formation spacing derived from hull length after CP2 | — |
| **feel** | [streams/feel.md](streams/feel.md) | **The articulated War Rig** (visual hinge at the fifth wheel, tractor simulated, trailer follows; the 14 m box stays), the **A6 motion-law contract** with control and nav, the void below the near wall; stretch: the Syndicate airship from primitives | — |
| **show** | [streams/show.md](streams/show.md) | **Added 2026-09-20:** the arena as a light show — fixtures, channels, patches and cues over the Terminus blocks, the perimeter neon and the signage, driven by match mood and events, at zero added draw calls and lights ([game_design.md](game_design.md) *Round 9 addition*) | — |
| **control** | [streams/control.md](streams/control.md) | **Desktop right-drag facing** with the test that makes the arc's A/B live by construction; the **A6 readout**; the camera, HUD, selection and radar checked at his pose against the resized roster after CP2 | — |

**Why seven and not six:** the lead asked for *"as many workstreams as necessary"*. The resize touches five owners'
paths and is the item he will judge the round by, so it gets an owner rather than being combat's first task; and A12
gates every falsifier in the catalogue, so it gets an owner rather than the orchestrator's spare time. Seven Claude
sessions are ~2.8 GB on a 7.6 GB laptop with heavy runs on builder0. **If the laptop swaps, start metrics, scale, nav
and feel first and the other three after CP1.** **An eighth stream, `show`, was added mid-round on 2026-09-20 at the lead's request; with seven live the laptop had ~2.2 GB free, so show runs every Godot process on builder0 and starts when a slot is free.** arena's paths are scale's this round; the `stream/arena` branch rests.

### Checkpoints (round 9)

- **CP1 — A12 metrics (metrics). FORMAT STABLE 2026-09-20 (`tools/metrics/FORMAT.md`, `7f2ec225` on `stream/metrics`); positive control PASSED** — round 8's 7.2 / 6.6 / 5.8 / 5.3% reproduced at 7.16 / 6.65 / 5.81 / 5.30 from the same run on builder0 at `aa984edd` + emitter (bar ±0.5, ordering kept); replays in `streams/references/round9/metrics/`. A producer adds two lines (`TRAJECTORY.install(match, path, producer, knobs)`); `make metrics LOGS=…` reads. **The continuous metric says the threshold understated the problem ~4×:** a tenth of every wheeled unit's 4 s windows sit at or below 0.25 efficiency against 7.2% of ticks flagged — the lead watches the p10, not the mean. Merge hash follows the green check. Every catalogue falsifier that names cusp density, displacement efficiency,
  spectral arc length or formation residual is read from A12. **Streams build and iterate before CP1; nobody publishes
  a falsifier verdict before it merges.** Its own acceptance: it reproduces the round-8 oscillation finding
  (5.3–7.2% on four maps) from the saved replays in `streams/references/round8/`.
- **CP2 — the resized roster (scale).** It moves the sim baseline (the orchestrator records it, Invariant 2), the
  spawn grid, cover, clearance and every size-dependent number. Lands **once, early**; every stream `git merge main`
  and re-runs anything size-dependent after it. **Nobody publishes a size-dependent number measured across CP2.**
  The lead sees the side-by-side frame before it merges (a look, not a number: the numbers are derived).
  **Pre-registered before CP2 (2026-09-20):** combat's `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` WILL
  move — the Condemned tank's collider grows 0.8 m in height — and nobody attributes that to A2 or A7. scale's check on
  `b7055602` found exactly two failures, both size-dependent literals in other streams' tests (control's 12 s group-move
  budget, feel's tracer window at −21.5…−17.0 written for a 3.8 m IFV); **ruled: scale lands both inside the CP2
  commit in derived form, owners review at merge**, and scale greps every test for the same shape (a distance, window,
  duration or budget derived once and then typed) and sends each stream its list before CP2 merges.
- **CP2b — squad's attacking-element leash (added 2026-09-20).** `TankBrain.element_slot()` no longer returns null for
  `bound`/`maneuver`, so every element member carries a leash to its published slot at `slot_leash(element)`; the
  drift bar becomes `slot_leash(element) + 2.0`. nav's A7 cannot go on by default without it. Merged alone, early, the
  day squad names its green hash; nav cherry-picks it for measurement only until then.
- **CP2c — control's desktop right-drag facing (added 2026-09-20).** Press = destination, release > 18 px away = the
  drag's ground direction becomes `facing` (pixels, not metres: at his pose 18 px is 0.3 m at the bottom of the frame
  and 40 m at the top); inside = a plain move with the key absent. Merged alone the day control names its green hash;
  it is the live arm for nav's arrival-arc A/B, which must not run before it.
- **CP3 note (2026-09-20 02:20):** T1's profile says `test` is **92%** of a check (2388 of 2584 s, builder0 `c21d0256`), so
  T1 is test sharding, not target concurrency. **After CP3 a slot holds six to eight processes, so CP3 sets
  `REMOTE_SLOTS=3`, not 6 or 8** — same box saturation, half the latency per check (metrics' arithmetic: 3 slots → ~5
  shards → ~10 min; 6 → ~2 shards → ~22 min); `tools/slot.sh --jobs` divides the *memory* budget by the live slot count
  so the two knobs cannot multiply into an OOM. **A separate follow-up checkpoint after CP3:** `make test` passes no
  `--fixed-fps`, so the suite waits on wall-clock 30 Hz physics — measured ~5× on simulated time; landed alone with
  three consecutive runs because it can change a test's *result* where sharding cannot.
- **CP3 — T1 parallel `check` (metrics).** Merged the moment it is green over three consecutive runs with a
  bit-identical sim hash; every stream benefits and every stream re-times its wall-clock assumptions after it.

### Who owns what (round 9) — changes to the round-6 table below

| Path | Owner (round 9) |
|---|---|
| `tools/metrics/` (new), `mk/metrics.mk` (new), `_agents/metrics.md` (new); **granted for T1 only:** the `check` recipe in `mk/core.mk`, `tools/slot.sh`, and timeouts in any smoke it has to raise — each listed in merge notes, and a raised timeout named with its before/after. **Granted for the S3 emitter (2026-09-19, at launch):** no per-tick trajectory log exists anywhere in the repo (round 8's JSONs are per-run aggregates), so metrics may add a **few-line emitter hook** — one call per tick into its own `tools/metrics/` writer, behind a flag off by default — in nav's `tests/nav/fight_probe.gd` and combat's `game/modes/match_runner_mode.gd`. Nothing else in those files; the owners review the hook at merge. | **metrics** |
| `arenas/`, `game/arena/`, `tools/make_arenas.py`, `mk/arena.mk`, `_agents/arenas.md` (arena's paths, resting this round), **plus a carve-out from combat's C1: the `hull_size` and `muzzle_height` values of every `Units.PROFILES` entry, and the three spawn-grid constants `SLOT_X`, `SPAWN_ROWS`, `SPAWN_ROW_SPACING` in `game/match/match.gd`**; `tools/roster_scale.py` (new), `mk/scale.mk` (new). combat reviews the `units.gd`/`match.gd` diff at merge and owns the files again afterwards. **Also granted (2026-09-19, at launch): a `lineup` view in feel's `game/theme/fx/bench/size_look.gd`** — the 21-unit side-by-side frame for the lead — additive, calling `box_at_length` rather than copying it; feel reviews at merge. Do not build a second renderer. **Granted retroactively (2026-09-20): `Tank._apply_hull_size` in `game/tank/tank.gd`** — two silent mirrors blocked the resize (an early return that let tank.tscn's authored 1.6 m-tall box win over the catalog's 2.4 m for the Condemned tank alone, i.e. the one unit the baseline match fields; and shared hull art fitted to that catalog entry rather than its own mesh). combat and feel review at CP2 merge; each mirror gets a mutation-checked regression test. **K = 0.707071** (rig 14.0 m over a 19.80 m tractor + DOT-406 tanker); judgment calls approved: Syndicate platforms referenced by role, `law_tank` = Centauro B1 8×8 at 7.85 m. | **scale** |
| `game/theme/show/` (new: fixtures, channels, patches, cues, the show director), `mk/show.mk` (new), `_agents/lighting.md` (new), a `show` section per arena in `arenas/*.json` (additive key, validated by arena's loader — scale reviews); **carve-outs from feel's `game/theme/**`, granted 2026-09-20:** the emission paths of `game/theme/arena_kit/` `CityBlock` (edges, window grid), the perimeter rim in `arena_dressing.gd` (`_build_perimeter`'s neon), `NeonSigns`, the floodlight pools, and `CyberMaterials.neon()` — **additive** (a fixture hook that feel's materials expose), never a restyle; feel reviews at merge and keeps the look | **show** |
| everything else | as the round-6 table below: nav, squad, control, combat, feel, orchestrator, shared |

### New contracts (round 9)

| Contract | Owner, where | Consumers |
|---|---|---|
| **S1 Roster scale** (CP2). `Units.PROFILES[id]` gains an optional documented key `scale_reference: {"vehicle": str, "length_m": float}` — the real-world vehicle the unit is drawn as and its cited length. `Units.SCALE_K` is the one world factor, fixed from the War Rig's reference at its ruled 14.0 m. **`hull_size[2] == scale_reference.length_m × SCALE_K` is asserted by a test for every unit that carries a reference, and width/height are asserted to be the mesh's proportions at that length (`SizeLook.box_at_length`) within a stated tolerance** — so the numbers are derived and checked, not mirrored (Invariant 0). `make roster-scale` prints the whole table (reference, K, length, box, drawn box) and renders the side-by-side frame. Units without an approved mesh keep their box and say so in the table. | scale: `game/units/units.gd` values, `tools/roster_scale.py`, `mk/scale.mk` | combat (C1 owner, reviews at merge), feel (the fit is automatic: `_fit_to_hull` scales by length), squad (formation spacing from `hull_size`), nav (clearance), control (framing) |
| **S2 Articulation is visual this round.** The War Rig's tractor is the simulated body and its 14.0 m box is the collider; the trailer is a theme part cut from the approved mesh at the fifth wheel and yawed per frame by tractor-trailer kinematics from the drawn motion. `articulated` in `Units.LOCOMOTIONS` stays reserved; nothing under `game/tank/`, `game/ai/`, `game/units/` changes for it. **Pre-registered: the sim hash does not move.** The follow-on (a second body with its own collider, and the plant's articulated locomotion) is recorded, not scheduled. | feel: `game/theme/` | nav (none this round), combat (none) |
| **S3 A12 metrics** (CP1). `tools/metrics/` reads a per-tick trajectory log (position, heading, speed, gear, order/goal, element and slot per unit per tick) and reports, per unit and per match: windowed displacement efficiency (4 s window), signed cusp density (per agent-minute, split ordered / creep / unexplained where the log carries the cause), spectral arc length of the speed profile, and the affine formation residual per element. **The log format is metrics' to define and every producer's to emit**: metrics ships a reference emitter for `nav-fight` and the match runner; if a stream's harness cannot produce it, that stream asks metrics rather than inventing a second format. Every falsifier in the catalogue that names one of these four quantities is read from this tool and no other. | metrics: `tools/metrics/`, `mk/metrics.mk` | nav, combat, squad, feel (every falsifier), orchestrator (the round's verdicts) |
| **S6 The light show** (added 2026-09-20). `Show` owns a set of **channels** (named scalar/colour signals computed once per frame on the CPU: breathe, chase, strobe, sweep, cycle) and **cues** (channel programmes bound to `MatchMood.current().state` and K5 events). A **fixture** is any emissive surface that exposes `set_show_channel(name)` or reads a per-instance custom-data slot; feel's materials expose the hook, show drives it. **Patches are data** per arena. **Hard rules:** zero added draw calls and zero real lights (M1's budget, measured with `make perf-scene` on builder0 before and after); the expensive part is baked once and only a scalar animates per frame (the widget spec's architecture); visual only, frame time not tick time, **pre-registered: the sim hash does not move**. `_agents/lighting.md` documents the vocabulary so a road or a bridge can be patched later without new abstractions. **The hook rule (feel, 2026-09-20):** a value that differs between instances is per-instance custom data on the MultiMesh (`use_custom_data`, how the crowd is already driven); a value that is one number for the whole fixture is a material uniform (`CyberMaterials.neon()`); show never adds a MultiMesh or a light to get variation a custom-data channel could carry. **`AdBroadcast` already drives the ground wash from the ad's average colour** — an arena-wide cue is a second writer to the same quantity, so `lighting.md` names one owner (recommended: the show director owns the wash and reads the ad colour as an input). And `make perf-scene`'s *"Too many instances using shader instance variables"* counter is a first-class number: read it, not only the frame time. | show: `game/theme/show/` | feel (materials, the look; reviews at merge), scale (arena JSON schema), control (the cutaway must not fight a cue) |
| **S5 One commitment term, two seams** (ruled 2026-09-20, from nav's A7 table). A2's switching cost is **one expression owned by combat** (braking energy plus turret/hull slew from `Units` physics, in combat's paths), consumed at **exactly two seams and nowhere else**: the brain's option scorer (`tank_brain.gd` `COMMIT_BONUS` 1.15 — squad's file, combat's seam, landed as a proposed commit squad takes or reverts) and nav's **level-5** commitment term in `combat_motion.gd` (today's additive 0.35). nav adopts combat's expression verbatim and keeps no constant beside it — **refined 2026-09-20 (nav + combat):** nav consumes `SwitchingCost.seconds_for()`, not `penalty()`, because the *seconds* are portable and combat's price (0.07/s, cap 0.35) is calibrated to the brain's 0..1.2 score range; nav publishes its exchange rate and the tree it was calibrated on, and keeps the shape (a capped price, never a veto). Under A7 a standoff HOLD is no longer an early `index −1` return but the zero-radial-speed candidate at level 2, so the term is consulted on holds by construction; nav lands a counter proving it. Table committed at `7edec4fb` on `stream/nav`. **combat's review (2026-09-20) produced two rulings written into the table before code:** (i) a standoff HOLD scored as a candidate needs a **hold term at level 5** in the same commit or the standoff weights vote it out every tick — acceptance is `scenario_motion::test_a_scout_holds_a_firing_position_instead_of_ramming` at 26.9 m closest / 0.92 in-band / 0.91 nose-on / 226 shots vs the run control's 6.0 m / 13 shots, before and after; (ii) **under a hold or station the leash is a level-0 feasibility bound on every candidate, dodges included** — a held unit dodges within its leash and never leaves it (product constraint 4; squad's base-of-fire scenario, base shots 5 then 4, is the test). Also corrected: the scouts are **fixed-mount**, so the armour demotion for turreted hulls cannot reach the engine-deck scenario; its falsifier is the turreted duel (front hits 100%/80%). **A7 lands first**, leaving the motion term in one named line; combat wires that seam the day nav names the A7 hash. An A2 penalty anywhere else in either scorer is the catalogue Part 2 failure by construction. Also settled from the same table: the dodge is strictly dominant at level 1; armour-toward-threat is a null-space preference for turreted hulls (combat runs squad's two scenarios on nav's actual A7 commit); **A6's motion law sits at level 3** — above formation, below the weapon band — unless feel's `legibility.md` argues otherwise before A7 is coded. | combat (expression), nav (level 5), squad (the brain seam) | feel (A6's level), orchestrator |
| **S4 A6 is a contract before it is code.** One written page, `_agents/legibility.md`, owned by feel with control and nav as signatories, stating: the motion law (a turreted hull fighting off-axis keeps its nose within ~25° of the ordered corridor tangent; a hull-fixed vehicle is bounded forward-oblique), who executes it (nav's velocity layer — as a priority in A7's table, named there), and what the player is shown (control's readout). **No stream writes A6 motion code until all three have signed the page.** control's right-drag facing lands first regardless, because it is the prerequisite for any facing A/B. **Page written at `4ec341d2` on `stream/feel` (2026-09-20); feel signed, nav reviewed.** Settled there: A6 sits at **level 3** (feel confirms: its own falsifier bars trading exchange ratio for a tidy line, and a law above the band would point the three hull-fixed scouts' guns down the corridor). A6 has **two clauses**: A6-a the nose clause (turreted within 25° of the corridor tangent, hull-fixed bounded forward-oblique at 75°), and **A6-b the sign of the arc** — when both shoulders serve the band equally, take the one that advances along the corridor, so level 3's null space becomes speed alone; **A6-b is the cell that makes the law reach the velocity falsifier at all**, and nav adds it to the A7 table as a row. The corridor is N1's `path_points` current leg, one publisher. Control's half is exactly three things: draw the corridor at **the lead's pose — 21° pitch, FOV 35, 49 m** (NOT 12°, the camera he played and rejected; corrected by control 2026-09-20), attribute a level-1/2 override in the existing "why did my element do that" vocabulary, nothing new on the command card. Active ticks are flagged with a reason and the falsifier is computed over active ticks with the active fraction beside it. **Invariant 0c answer: A6 replaces nothing** (no heading law or corridor exists today, and A7 already deletes `PENALTY_SIDE_ON`) — accepted as an addition **with A5's pre-registered revert:** if the velocity-opposing fraction does not fall below 10% without an exchange-ratio fall, it comes out with its switch. **control signed 2026-09-20 with one condition on nav:** `Movement.state(unit)` carries `"legibility": {"active": bool, "why": StringName}` (`why` from a closed set: `band`, `survival`, `armour`, …) so the readout names which level took the nose rather than inferring it from geometry. **And a rule for A12:** an arrival arc under an *ordered* facing is off-corridor by construction — those ticks are flagged by nav's emitter and counted as ordered, never charged to A6's fraction. | feel (author), control, nav | squad (a facing on holds) |

### The round's structural finding so far (2026-09-20, nav and squad independently)

**Intent does not reach the layer that moves the hull.** nav: `CombatMotion` decides under a tenth of a hull's ticks
in a fight; `Movement` drives the other nine tenths and has no notion of a formation leash, so A7's level-0 region
must move into `Movement`'s goal selection. squad: A8's deformation, measured, makes a wedge *fail* a defile it passes
without it, because a slot layout is the wrong place to express intent the mover cannot see — and it never applied
to a plain right-click move at all. **Same seam, from both ends, within an hour.** Not a tonight-sized change; it is
the first candidate for round 10, ahead of retrying either row.
**The defile failure, MEASURED (nav, 02:50, squad's tree and configuration, maze, wheeled, seed 3, 70 s; reproduces
squad's result exactly — artillery never arrives, dispersion 41.4 s):** three hypotheses were pre-registered with their
signatures before the run, and two died. Chord guard starving wide hulls: `guard_rescues` **1** all run — dead.
Right-of-way impossible in a 5 m corridor (4.55 m of clearance needed; nav's and the orchestrator's favourite): `asks_refused`
**0**, `yields_started` **0** — dead, **because nobody ever asks**: right-of-way triggers on stall or on being held below
the ask pace, and a unit ORCA is deflecting is neither. **ORCA: `orca_deflected` 1330 of `orca_solved` 2172 — 61% —
alive.** The hull sits in a regime no recovery mechanism recognises: not stalled (it moves), not blocked (it
progresses a little), not slow enough to ask; every safety net watches for a different symptom. Two consequences: the
pre-approved "strict file order" fix would fix a deadlock that is not happening and is withdrawn; the real question is
why ORCA's deflected velocity does not resolve in a corridor — whether the navmesh refusal (`AVOID_MESH_PROBE`) should
return a slower but legal velocity instead of falling back to the route at reduced pace — and **something must notice
the regime** (61% deflection with no arrival in 70 s trips nothing). The method is the finding: signatures written
before the run killed the two stories their authors believed. **Then the third died too (nav, 03:10):** the ORCA
navmesh refusal fires twice in 70 s; making it return a slower-but-legal velocity changed nothing (identical arrivals,
identical 40.57 s dispersion) and was reverted as a null. **All three pre-registered hypotheses are dead and the cause is
unknown.** What survives is `wedged`, a `Movement` regime detector that fires 8 times in the run and gives the failure a
name in the state machine, so the next investigation starts from a counter rather than a story.

### Standing rules for round 9 (in addition to *The standing rules for this round* below)

- **CP1 before verdicts, CP2 before size-dependent numbers.** Build freely; publish after.
- **The orchestrator records the sim baseline in the same session as CP2 and any sim-moving merge** (Invariant 2 as
  amended). A merge that moves it says so in its subject.
- **Every number carries its commit and its machine**, and after CP3 lands, wall-clock figures taken before it are
  retired (T1's note in *Round 9 goal* below).

## Round 6 goal

**Movement you can trust, and a squad that forms up.** The lead played round 5 and stopped at vehicles that get stuck
behind each other, formations that never form, buttons he can't name, a long dead pause after FIGHT, a camera too far
above the fight, empty stands, and weapons that open fire the moment anyone is visible
([game_design.md](game_design.md) *Round 6 direction*). Frame rate is **not** on his list this round — the locked 30 fps
held — so this round spends its budget on behaviour, not on the frame.

The stack the lead described, top to bottom, is the shape of this round:

```
  player order  ──▶  squad: target formation, a slot per unit, form-up ETA     (squad)
                     └─▶ unit: path to my slot, avoid, negotiate, unstick      (nav)
                         └─▶ hull: throttle and turn from a regulated error    (nav, PID)
  read and issued through the task palette, symbols and camera                 (control)
  over terrain that makes ambush and flanking possible                         (arena)
  at ranges where closing is a decision                                        (combat)
  in a place that feels inhabited                                              (feel)
```

## Round 6 streams

| Stream | Brief | Outcome |
|---|---|---|
| **nav** | [streams/nav.md](streams/nav.md) | A horde gets where it is sent: real path planning, local avoidance with peer-to-peer right-of-way, nothing stuck, and one regulated control law (PID) from the wheels up. Proven on a maze. |
| **squad** | [streams/squad.md](streams/squad.md) | A squad order is a *formation* order: a target formation anchored on the destination, a slot per unit, a form-up formula and ETA, and every named task producing the behaviour its name claims |
| **control** | [streams/control.md](streams/control.md) | The squad UX earns every button: military task symbology, nothing the mouse already does, a camera between StarCraft 2 and Twisted Metal, and loading that shows its progress |
| **arena** | [streams/arena.md](streams/arena.md) | Terrain that makes ambush and flanking possible instead of one open brawl, plus the maze arena nav is measured against |
| **combat** | [streams/combat.md](streams/combat.md) | Engagement ranges where seeing an enemy is not the same as opening fire: closing, breaking contact and cover become decisions |
| **feel** | [streams/feel.md](streams/feel.md) | The arena is inhabited: a crowd in the stands that can be seen and heard, and the place reacts to the match |

**Paused:** netcode, the garage and progression loop, new Meshy *models* (88 credits left). ElevenLabs has credits and
feel may use them for crowd beds under the standing text-approval gate.

**Why this split:** the lead's message is one stack with six layers, and each layer fails on its own terms. Getting a
vehicle around another vehicle (nav) is a different craft from deciding where five vehicles should stand (squad), from
naming that task on screen (control), from the ground it happens on (arena), from when a gun is allowed to speak
(combat), from whether the arena feels like a place (feel).

## Checkpoints

- **CP1, nav's Movement API (N1)** — the seam every other stream's movement runs through. nav lands the interface and a
  working default first, before the clever parts, so squad is never coding against a stub.
- **CP2, arena's maze (N3)** — a small data job arena does on day one, because it is nav's acceptance test.
- **CP3, squad's slot contract (N2)** — control's task palette and the CPU commander both read it.
- **CP4, combat's engagement envelope (N5)** — it re-times every fight. It lands **once**, early, and every stream
  re-runs its measurements after; nobody publishes a number that straddles it (round 5 lost days to exactly this).

## Product constraints every stream designs for (the lead)

1. **"Even smarter than StarCraft 2."** The bar is legibility: a unit must look like it knows what it is doing. No unit
   standing still in a fight, no unit stuck behind a friend, no element flip-flopping between drills.
2. **A locked 30 fps at 1080p with 30 a side** (the lead's round-5 sign-off), and a 720p 60 fps option. Anything added
   this round is measured against it; the simulation tick is 30 Hz.
3. **Orders obey instantly**: the K1 response guarantee is **100 ms of wall clock**, asserted in milliseconds.
4. **The player's units hold until ordered** (round-5 ruling). An army that moves without being told is not an army.
5. **Fun first, desktop first; no unearned god view; CPU and player run the same doctrine.**
6. **The vibe** ([art_direction.md](art_direction.md)) and **die-hard, no pay-to-win** ([vision.md](vision.md)).

## Lead gates this round

1. **The camera look is the lead's call.** control puts a page of screenshots (pitch × height × FOV, the same moment of
   the same fight) in front of him rather than guessing at "between StarCraft 2 and Twisted Metal".
2. **Paid generation:** no new Meshy models (88 credits). ElevenLabs crowd beds need the usual text approval, and a
   cheap pilot before any batch (lesson 19).
3. **Design pillars**, money, accounts, and anything destructive outside your worktree.

## Who owns what (round 6)

| Path | Owner |
|---|---|
| `game/ai/{pathing,steering,combat_motion,order_controller,order_feed}.gd`, new `game/ai/{avoidance,movement,pid,control_gains}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk` (new), `_agents/navigation.md` (new) — **one exception, granted 2026-09-18:** with no nav session running and two streams holding for CP4, combat made four surgical edits to `order_controller.gd` (an `engagement_lay` member, an `Engagement.is_seen` early-out in `_shootable`, an `envelope` term in the trigger line, and a seconds helper with `lose`/`forget`). Every rule lives in combat's `game/combat/engagement.gd`; the controller only holds state and calls it, and none of the edits touches a path, waypoint or throttle. nav reviews them when it starts and owns the file. The seam combat wants for the `gunnery.gd` split is written into [streams/nav.md](streams/nav.md). | **nav** |
| **Contract, agreed 2026-09-19 (nav + squad):** a move order may carry `"facing": [x, z]`. squad populates it from `TankBrain.intended_facing()` at its `_move_to`/`_order_move` choke point; nav consumes it in `Movement` so a WHEELED hull rolls onto that heading on its last leg (a Dubins-style arc) instead of creeping round after it arrives (measured: an IFV 45° off at arrival, ~6 s to correct). Tracked and hover hulls ignore it and pivot as they do now. | **nav** (the arc) + **squad** (the facing) |
| `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,cpu_commander,tank_brain,directives,utility_curves,brain_variants,element_feed,matchups,difficulty,tactical_query,cover_map,fire_lanes,perception,suppression_feed,incoming_fire,ai_tick_cache,ai_explain_overlay}.gd` (**not** `doctrine.gd`: the army-JSON loader is combat's, C2), `doctrines/`, `game/agent/`, `tools/{agent,ai_ladder}.py`, `mk/{ai,tactics}.mk`, `tests/ai_scenarios/`, `_agents/{tank_brain,squad_ai_design,unit_ai,doctrine}.md` | **squad** |
| `game/control/`, `game/ui/` (HUD, widgets, title screen, loading screen), `game/camera/`, `game/controllers/`, `game/modes/{skirmish,offline,title}_mode.gd`, `mk/command.mk`, `_agents/tactical_map.md` — **one exception, granted 2026-09-18:** squad rewrites `game/control/group_formation.gd` into a thin adapter over N2's `TacticsFormation.slots()`, keeping its public API unchanged, because N2 cannot collapse three formation systems into one while one of them lives behind another stream's wall. control reviews that diff at merge and owns the file again afterwards. **Reviewed and cleared 2026-09-18:** control confirms the shim suits `Orders._resolve_group()` — pacing carried over exactly (`PACE_NEAR` 8 m, `PACE_FLOOR` 0.35, same formula) and seating through `TacticsFormation.place(..., {"policy": "front"})` keeping heavies forward with non-crossing seats; all 141 control formation/orders/group tests pass on the merged tree. No objection — the exception is discharged and the file is control's again. | **control** |
| `game/arena/`, `arenas/`, `tools/make_arenas.py`, `mk/arena.mk`, `_agents/arenas.md` | **arena** |
| `game/units/`, `game/combat/`, `game/match/`, `game/tank/` **except `tank_motion.gd`**, `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`, `_agents/balance.md` | **combat** |
| `game/theme/**` (materials, shaders, effects, props, the crowd's MultiMesh **and its voice**), `game/audio/`, `game/announcer/`, `assets/{announcer,audio,music}/` and art paths, `tools/{assets,announcer,audio}/`, `mk/{fx,assets,announcer,audio}.mk`, `export_presets.cfg` art filters, `_agents/{art_direction,slot_contracts}.md` — **one exception, granted 2026-09-18:** arena edited four lines of `tools/announcer/test_arena_names.py` to skip layouts flagged `"fixture": true`, because its maze is a test fixture that must never get a spoken name (the booth should not name a map nobody plays) or a recorded clip (paid ElevenLabs time behind a lead gate), and it had turned `main`'s check red. feel reviews it at merge and owns the file. | **feel** |
| `game/garage/`, `game/progression/`, `game/network/`, `server/`, net modes, `mk/{garage,net}.mk` | **paused**: minimal compatibility fixes only |
| `_agents/game_design.md`, `vision.md`, `roadmap.md`, `workstreams.md`, `orchestration.md`, `backups.md`, `HANDOFF.md` | orchestrator |
| **Shared:** `project.godot`, `game/main.gd`, `game/main.tscn`, `game/modes/game_mode.gd`, `Makefile`, `mk/core.mk`, `tests/run_tests.gd`, `tools/{remote,slot,backup_assets}.sh`, `CLAUDE.md` | nobody alone: minimal edits, listed in merge notes |

`game/theme/audio/` and `engine_system.gd` stay with the sound owner, which is **feel** this round (round 5's audio
stream folds into it; round 5's render stream folds into it too — the frame-rate work is done and the remaining
presentation job is the arena as a place).

## New contracts (round 6)

| Contract | Owner, where | Consumers |
|---|---|---|
| **N1 Movement API** (CP1). One seam between *where a unit is told to be* and *how it gets there*. `Movement.request(unit, to: Vector3, opts) -> void` where `opts` may carry `{"arrive_radius", "facing", "pace", "priority"}`; `Movement.state(unit) -> {"phase": "pathing" \| "driving" \| "yielding" \| "blocked" \| "arrived", "eta_s", "remaining_m", "path_points", "blocked_by"}`; `Movement.eta(unit, to) -> float` (the lead's "estimate the position and time at which a unit would converge"); `Movement.cancel(unit)`. Guarantees nav owes every consumer: a unit given a reachable destination **arrives or reports `blocked` with a reason** — it never stands still silently, and never remains stuck. Local avoidance and right-of-way are always on; no consumer opts in. | nav: `game/ai/movement.gd` | squad (slots), control (orders, markers), combat (none), arena (none) |
| **N2 Slot contract** (CP3). A squad/element order is a formation order. `TacticsFormation.slots(element, anchor, heading, count) -> [{"unit", "to", "facing", "role"}]`, recomputed as the anchor moves; assignment **minimises crossing** (a unit keeps its relative place) and is stable tick to tick; `element.form_up_eta() -> float` from N1's ETAs; the group paces to its slowest member (`Orders.pace_factor`). The two formation systems that exist today (`game/ai/formations.gd`, squad-level, 5 slots; `game/tactics/tactics_formation.gd`, element-level) become **one**. | squad: `game/tactics/`, `game/ai/formations.gd` | control (palette, markers), nav (consumes slot targets), combat (none) |
| **N3 Maze arena** (CP2, day one). `arenas/maze.json` — a quasi-maze the lead asked for by name, built from the existing kit, point-symmetric like every arena, with a start zone and a far objective and gaps a horde must file through. Plus `make nav-maze`, a headless run that sends N units across it and reports how many arrive, when, and how many were ever stuck. It is nav's acceptance test, not a shipping map. | arena: `arenas/`, `mk/arena.mk` | nav (acceptance), squad (form-up under constraint) |
| **N4 Task palette and symbology.** The final task vocabulary, one row per task: the verb (`ElementTask.VERBS`), its **military symbol** (APP-6 / MIL-STD-2525 tactical task graphic), its hotkey, one line of player-facing text, and the behaviour the player is entitled to see. A verb may only appear in the palette when squad can demonstrate its behaviour; a verb the mouse already expresses (`move`, `follow`, `attack`) gets **no button**. control owns the table and draws the symbols; squad owns the behaviour behind each row. | control + squad, table in `_agents/tactical_map.md` | all |
| **N5 Engagement envelope** (CP4). Per-weapon *effective* range, acquisition range and the rule that decides when a unit opens fire, such that seeing an enemy is not the same as shooting at it. Lands once, early, with the before/after measured on the configuration players actually get. | combat: `game/combat/`, `game/units/`, `game/match/` | all (every measurement re-runs after it) |
| **N7 Objectives are the arena's, not a constant** (added 2026-09-18, arena proposing, combat scheduling). `Match` hard-codes `CONTROL_CENTER := Vector3.ZERO` and `CONTROL_RADIUS := 16.0`, and a layout's `control_point` reaches only the *dressing* — **an arena cannot move its own objective today; the field is decorative.** arena has landed its half: `arenas/` gains `objectives: [{name, position, radius}]` with `Arena.objectives_of()`, validated so off-centre objectives come in **mirrored pairs** (a lone one is owned by whichever base is nearer, preserving the fairness invariant), and a layout with no `objectives` list reports exactly the single central zone `Match` already hard-codes — asserted for every shipped layout. **combat's half is a pure read-through with no behaviour change on any existing arena:** read `Arena.objectives_of(Arena.active)` instead of the two constants, and hold a per-objective owner instead of one scalar. It is combat's to schedule; arena's X3 (objectives off the centre line) is blocked on it *and* on CP4. | arena: `arenas/`, `game/arena/` → combat: `game/match/` | squad (what to take), feel (dressing) |
| **N6 PID as the house control law.** `Pid` (a small, deterministic, tick-based regulator: gains, integral clamp, derivative on measurement, reset) used where there is a continuous error to regulate — slot station-keeping, speed matching, turret lay — and **not** where the problem is discrete choice. Gains live in **data**, per faction, so the lead's idea that factions differ by their gains is reachable: the Syndicate crisp, the gangs loose. Default gains ship stable first; per-faction gains are a stretch. | nav: `game/ai/{pid,control_gains}.gd` | squad (station-keeping), control (camera smoothing), feel (none) |

## Round 9 goal (2026-09-19): the research catalogue, sequenced — and the metrics BEFORE the mechanisms

**Read [`research_catalog.md`](research_catalog.md) first.** It is the backlog: 12 ADOPT rows, each with a canonical
reference, what it replaces, an owner and a **pre-registered falsifier**. This section is only the *split and the
order*, which the catalogue deliberately does not fix.

**A12 (the trajectory-space metric suite) LANDS FIRST, and it is the orchestrator's, not a stream's.** Everything below
is judged against it, and round 8 proved twice over why:
- **We measured time-allocation while his complaint was about the shape of the motion.** A unit that jerks for 0.5 s
  costs almost nothing in "6% of travel time" and ruins the next fifteen seconds of watching.
- **squad's churn lever is the proof** (lesson 150): `commit_bonus` 1.35 halved the churn metric, passed a 48-match
  ladder, and cost a squad its fire concentration and a scout its engine-deck targeting (41/23 → 3/0). **The metric
  improved while the behaviour degraded.** A12's own acceptance is that it reproduces the round-8 oscillation finding
  from the same replays — *a metric that cannot see a pathology we already found is the wrong metric.*

### The split

| Stream | Round 9 | Order and why |
|---|---|---|
| **orchestrator** | **A12 metrics suite**, then **T1 parallelise `check`** | Windowed displacement efficiency (the 8 m/2 m signature measured directly), signed cusp density, spectral arc length, affine formation residual. **Before anything else ships.** |

**T1 — PARALLELISE `make check`. The lead asked for this directly (2026-09-19) and it is worth more than any single
algorithm on this list.** Measured at the close of round 8: a `check` on builder0 is **one single-threaded Godot
process at ~7% CPU on a 12-thread machine** — latency-bound on awaiting fixed-tick physics frames, not compute-bound.
**We gate an entire round on ~8% of the build machine for 30–50 minutes.**

- **This is the knob the slot question was really reaching for.** Raising `TANK_SQUAD_SLOTS` (2 → derived, now 4)
  shortens the QUEUE. **Only inner parallelism shortens the RUN**, and the run is what everyone waits on.
- **What a 40 → 10 minute check would have changed on the night of round 8's close, concretely:** combat would not
  have had to abandon a 590-test run when the network dropped and start over; the orchestrator's own lint mess would
  have been caught in one cycle instead of three wrong diagnoses; and the round would not have needed a two-hour tail
  that the lead had to cut short.
- **Shape:** the targets in `check` are largely independent (`lint`, `test`, the smokes, `determinism`,
  `announcer-check`, `audio-check`, the pytest suites). Run independent targets concurrently under the slot budget
  rather than serially. **Memory is the constraint, not cores** (~735 MB a Godot run against 11.9 GB available on
  builder0), so the budget is roughly 8–10 concurrent runs there and far fewer on the laptop — **derive it the way
  `tools/slot.sh` now derives its slot count, do not hard-code it** (lesson 148).
- **⚠ Determinism is safe; TIMING is not.** Separate processes on a fixed tick produce identical hashes under any
  load. What breaks is anything sampling wall-clock inside a run — profiling, timeouts, real-second budgets. Three
  garage liveness timeouts already went 60/120 s → 600 s for this reason, and **control measured that a
  reference-workload ratio corrects for "busy machine" but NOT for "every thread busy"** (~14× vs 2× under 7 burners
  on 8 threads). **Expect to raise timeouts, and expect wall-clock figures taken before this change to be retired**
  (nav catalogued which of its own survive, in `verification.md`).
- **Falsifier:** wall-clock for a full `check` on builder0 drops by **≥ 50%** with **zero new flakes over three
  consecutive runs**, and the sim baseline hash is **bit-identical** to the serial run's. A faster check that flakes
  once is worse than a slow one, because a flake costs a re-run plus a false investigation.
| **nav** | **A7 → A11 → A1 → A4** | **This order is nav's, adopted over the orchestrator's A1-first proposal — see below.** |
| **combat** | **A2**, then A3's consumer | A2 replaces the flat `commit_bonus` (**1.15** on main; 1.35 reverted) with a state-dependent switching cost. **Its falsifier is inherited, not invented: squad's two behaviour scenarios** — fire concentration and the scout's engine decks — because that is exactly what the crude version cost |
| **arena** | **A3's summed-area tables**, + the **Syndicate airship** | A3 retires the 12.19 m cover cliff at any hull length. **The `make arena-report` WATCH line must be revised in the same commit as the tables** or it becomes a confident false alarm. Airship: primitives, no Meshy, no collision body ([game_design.md](game_design.md)) |
| **squad** | **A8 → A9 → A10** | squad's own plan names what each REPLACES **by file** — A8 replaces `TacticsFormation.group_offsets` and `ArmyLayout._scale_for` (`game/tactics/army_layout.gd:195` — the round-8 plan misnamed it `ElementPlan._scale_for`); A9 replaces `Element.form_up_eta` and `_pace_leader_for_flow`; **A10 replaces `TacticsFormation.seat()`'s Hungarian matching AND BOTH its hysteresis patches** (`STABLE_MARGIN` and round 8's `fixed` flag, which is deleted with it, not layered on). **Aim A8/A9 at WHEELED hulls** (re-aimed 2026-09-20 from *light* hulls on metrics' CP1 evidence: on a Condemned roster with no scout, yard efficiency ifv/lancer 0.62 with ~35 cusps per agent-minute against the tracked tank's 0.80 and 7.4 — a **locomotion** effect, not a unit; and 56% of all reversals are the wheeled creep, `tank` producing zero) — round 8's *scout is the shuffler* (0.68 net/path, 13.3%) was the same effect seen through one unit |
| **feel + control** | **A6 legibility — as a CONTRACT first** | See below; this one does not start as code |

### nav's sequencing, adopted over the orchestrator's — and the argument, because the argument is the artefact

The orchestrator proposed A1 (cadence) then A4 (clothoids). **nav argued A7 → A11 → A1 → A4 and was right.** Recorded
here rather than left in a message, because the reasoning is what a fresh orchestrator needs:

1. **A7 (null-space priority projection) first, alone.** It is the only architectural row, and **everything else is
   priced wrongly until it lands.** Round 8's clearest finding is a cancellation failure: *standoff HOLD returns index
   −1 and never consults the commitment bonus*, so we shipped a term that was never in the code path and measured it
   twice for nothing. That IS "opposing goals cancel to zero", which priority projection makes structurally
   impossible. Its falsifier is also already measurable with nav's `travelled` counter and arena's stall counters.
2. **A11 (dynamic-window arcs) second, because it replaces the ring A7 has just re-plumbed.** The other order means
   fitting priority projection to a scoring structure we are about to delete.
3. **A1 (event-triggered replanning) third.** Worth the most on paper (70% of churn) but **the row most likely to look
   like a win while hiding a regression** — nav's hold-hysteresis A/B is the cautionary case: churn down 6–22% and it
   still failed its bar. A1's latency falsifier (≤ 2 ticks to a new contact) needs a stable decision layer beneath it.
4. **A4 (clothoids) last, after A11.** Clothoids are a primitive; the thing that consumes them is the arc chooser.
   Landing them first writes them into the ring we are removing. Round 8's arrival arc is the natural first consumer.

**⚠ nav's caution against its own recommendation, which is the part to brief hardest:** A7 replaces additive blending,
and **that is also what `CombatMotion`'s entire weight table is.** Those weights encode behaviour the lead has already
approved — standoff, commitment, armour toward threats. *"Six multiply-adds"* badly understates the blast radius.
**A7's brief must name which of those become priorities and which become null-space tasks BEFORE any code**, reviewed
against combat's and feel's contracts. That is where round 7's approved behaviour either survives or quietly does not.

**nav's Invariant 0c declaration, for reuse as the template:** *it owns the desired-velocity layer (`movement.gd`,
`combat_motion.gd`, `steering.gd`, `tank_motion.gd`); it assumes above it that squad hands down goals and a `facing`,
and below it that the plant honours (throttle, turn) with a bounded yaw rate; A7 replaces its additive blend, A11 its
direction ring, A1 its fixed repath/re-aim cadence, A4 the straight approach in its arrival arc.* **None of the four
adds alongside.** That is the answer Invariant 0c is looking for.

### A6 is a contract before it is code — feel, control and nav together

feel raised this and it is right: **the motion code is nav's and combat's, not feel's**, so A6 cannot be three parallel
adoptions. It starts as one written contract — feel owns the motion law, control owns the readout, nav owns the layer
it executes in — and **control's prerequisite lands first**, because of lesson 149:

**The arrive-on-heading arc cannot fire in the game the lead plays.** A `facing` enters a move from exactly one place,
`game/ui/tactical_map.gd:269`, the touch map's right-drag, and the touch map is behind `--touch-map`. His desktop
`RtsControls` only ever *reads* `facing`. **So control's first round-9 commit gives the desktop right-click the touch
map's grammar** (press = destination, drag = the facing to arrive on) **with a test asserting
`orders.current(unit)["facing"]` after a real drag — so the next A/B has a live arm BY CONSTRUCTION.** An arm you have
to remember to check will eventually not be checked. And note: even then, `nav-fight` issuing a plain `move` measures
nothing — **the live cases are a player drag and a squad hold. Do not re-measure zero twice.**

### The standing rules for this round

- **Invariant 0c governs.** A brief that adopts a catalogue row names what it **replaces**; *"nothing"* is the answer
  the orchestrator interrogates. Rows touching one code path are **sequenced, not parallelised**.
- **Pair every outcome ladder with a behaviour assertion**, and prefer the behaviour assertion when they disagree
  (lesson 150). A ladder is a safety net against making things worse, never evidence of having made things better.
- **Prove the arm is distinguishable before believing any comparison** (lesson 147). An arm-engagement counter costs
  four lines and is the difference between a finding and a fiction.
- **Play the default path** before reporting anything as shipped (lesson 149).
- **Never quote the external reviews' audit counts or Elo figures.** They are unverifiable assertions about a codebase
  neither service has seen. The reasoning stands on its own; the digits do not.

## Round 8 goal (2026-09-19): the owed algorithms, and the eight things he listed

**The lead: *"it still sucks"*, and *"my expectation was that you would have gotten all this working while I was away."***
**Round 7 merged seventeen branches and did not change his verdict.** Round 8 is the algorithm roster plus his eight
items, and **nothing else**. No instrument work that is not in service of one of them.

**Why the roster slipped, stated plainly so it is not repeated:** round 7 spent its capacity on *merging* and on
*instruments* — six measuring tools were found broken — and the owed algorithms were deferred as too large to land
alongside that. **That was defensible once. It is not defensible twice**, and the four missing algorithms map directly
onto his complaints:

| his complaint | the owed algorithm |
|---|---|
| *"the semi trucks are yawing in place"* | **angular acceleration limit** on the plant |
| trucks turn like tracked vehicles | **Reeds–Shepp** |
| *"stuck behind basic barriers… back and forth indefinitely"* | **flow fields** |
| long routes, repathing every second | **HPA\*** |

| Stream | Round 8 |
|---|---|
| **nav** | **The three motion algorithms, in this order: (1) angular-acceleration limit in `TankMotion.step_in_place` — and a wheeled hull must NOT rotate without translating, which is a class bug, not a semi bug; (2) Reeds–Shepp for car-like hulls; (3) FLOW FIELDS as its own checkpoint.** Flow fields are no longer deferrable — they are the named answer to his loudest complaint |
| **arena** | **A REPRO MAP for the barrier stall, in the configuration he plays.** nav measured blocked-by-terrain to zero in `nav-fight` while he watches it happen in `make skirmish` — **the instrument and the game disagree and the game is right.** Build the barrier that stalls units and make it a probe nav can run |
| **squad** | **Orphaned units: every unit belongs to a squad, and 1–4 selects all of them.** Then **an explicit attack order must override an existing target** — `test_a_move_order_beats_every_brain_state` has no attack sibling and needs one |
| **control** | **The selection side of the orphans**, and whatever makes an ignored order visible: if a unit cannot obey, the HUD must say so rather than leaving him to infer it |
| **feel** | **MAKE THE SEMI HUGE.** 3.14× satisfied the number he gave in round 6 and not the intent, and **he has removed balance as a constraint**. Then the articulated tractor/trailer, which he offered to shelve — **treat it as a stretch** |
| **combat** | **`hull_size` for the semi** (the catalog is combat's, and it is the collision box), and **the balance consequences of a huge semi, which he has explicitly deferred** — measure, do not tune |

**The standing rule for this round: every item is something he named. If a stream wants to do something he did not name,
it asks first.**

## New contracts (round 7)

| Contract | Owner, where | Consumers |
|---|---|---|
| **M4 Arena containment is a predicate, not a scalar** (added 2026-09-19; combat found it, arena owns it). `Arena.contains(point) -> bool` and `Arena.clamp_into(point) -> Vector3`, working for **every** shape including the existing square, so no caller knows what shape the arena is. **Why it exists:** `DRIVABLE_LIMIT` is used as a *square* clamp in six places — three `absf(x) > DRIVABLE_LIMIT or absf(z) > ...` checks in `arena.gd`'s validate, and `clampf` in `orders.gd`, `rts_controls.gd` and `army_layout.gd`. A regular hexagon of circumradius 139.7 m has an **inradius of 121.0**, so its boundary is 139.7 m toward a vertex and 121.0 m toward a flat edge, while **a square clamp at ±136 permits points 192 m from centre on the diagonal** — every one of those call sites would place an obstacle, clamp an order or lay out an army outside the playable arena, and `Arena.validate` would approve it. `DRIVABLE_LIMIT` survives only as the conservative **inscribed** bound: 121.0 − 4.0 clearance = **117**, which is barely different from today's 116. **⚠ Scaling it 116 → 136 in proportion with `ARENA_HALF_SIZE` makes the clamp about three times too permissive, not slightly.** `clamp_into` must document whether it returns the nearest boundary point or the ray-to-centre crossing — they differ sharply near a corner; nearest-boundary is what a player means by *"go as far that way as you can"*. The water and pit footprints belong behind the same predicate: a point inside a pit is not a point a player can be ordered into. | arena: `game/arena/` | **control** (`orders.gd` ✅, `rts_controls.gd` ✅ via `Orders.clamp_to_arena`: the shape inset by a 4 m hull clearance (exactly ±116 on the square), then `Arena.clamp_into` for water and pits; `radar.gd` has no clamp), **arena** (`validate`), **squad** (`army_layout.gd`, `agent_bridge.gd`), **combat** (`match.gd` constants, `visibility_field.gd` ✅, `match_runner_mode.gd` bench spread — still a square clamp, harmless today, **unmigrated**), nav |

## Round 5's contracts (still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **M1 Performance budget.** `make perf-scene` reports frame time, draw calls, primitives and real-light count for a 30-a-side battle; the written budget is in `_agents/streams/references/fx_tricks.md`. The target is the lead's: **a locked 30 fps at 1080p with 30 a side**, plus a 720p 60 fps option. | feel | all |
| **M2 Arena layout v2.** `arenas/<name>.json` with the arena kit: `props` (`container_20`/`container_40` with `stack`, `ad_screen`, `barricade`, `sign`, `wreck`), lanes and cover annotations for the AI, per-arena spawn zones sized for 30+ a side, validated point-symmetric; `--arena=<name>`. | arena | combat (collision, nav), nav (navigation), feel (props), squad (cover, lanes) |
| **M3 Team identity without glare.** Vehicles read as vehicles at play distance; team accent is a hint. Settled by the lead: **rim tint is enough**, no per-team hull paint. | feel + control | all |

## Round 4's contracts (still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **L1 Elements and doctrine.** *Sharp edge (control, 2026-09-16): an element with no task still runs its SOP, so forming one before it has a task makes its leader fight the player for the wheel. Form lazily, on the first task.* An `Element` is a cluster of units with a leader: `Elements.form(units, name)`, `Elements.of(unit)`, `element.assign(task)` where a task is `{"verb": "move" \| "attack" \| "screen" \| "support_by_fire" \| "hold", "to"?, "target"?}`; the leader picks a **formation** (`column`, `wedge`, `line`, `echelon_left/right`, `herringbone`) and a **movement technique** (`traveling`, `traveling_overwatch`, `bounding_overwatch`) from doctrine data, and runs **battle drills** on triggers (`react_to_contact`, `near_ambush`, `far_ambush`, `break_contact`, `support_by_fire`, `assault_through`). It issues per-unit orders through control's K1 `Orders`. Read-only for UI: `element.state() -> {formation, technique, drill, reason, slots}` and signal `element_changed(id)`. Doctrine data lives in `doctrines/doctrine_<name>.json` with a `faction` field. **Round 6 puts this contract on trial: the verbs must do what they say (N4), and the formations must actually form (N2).** | squad: `game/tactics/` | control (HUD, task issuing), nav (executes), combat |
| **L2 Suppression and effective fire.** `Tank.suppression` (0–1, decays), raised by near-misses and rounds passing close; accuracy penalty and a `pinned` state above a threshold. `Match.threat_field(team)`, `Match.is_beaten_zone(team, from, to)`, `Match.threat_along(team, from, to)`, `Match.shot_spread(weapon, moving, suppression)`, `Weapons.suppression(weapon)`, `Tank.suppression`/`is_pinned()`/`suppress()`. `projectile_impact` and `weapon_fired` carry `suppression_applied`. | combat | squad, feel |
| **L3 Faction rosters.** `Units.PROFILES` entries carry `faction` (`condemned` \| `gangs` \| `law` \| `syndicate`), per-faction costs and stats; `Units.roster(faction)`; `--green-faction=` / `--rust-faction=`; `Army` builds faction armies to a budget. | combat: `game/units/` | squad, control, feel, nav (per-faction gains, N6) |
| **L4 Vision-framed camera.** `RtsCamera.frame_vision(element)`, `Camera.max_zoom_in`, `Match.visible_region(team, units)`. Off-screen markers and alerts come from control. | control | — |
| **L5 Match mood.** `MatchMood.current() -> {intensity 0..1, state: "lull" \| "skirmish" \| "battle" \| "last_stand" \| "victory" \| "defeat", reasons[]}` from the K5 event stream. | feel: `game/audio/` | announcer, crowd, screens |

## Standing contracts (from rounds 2–3, still in force)

| Contract | Owner, where | Consumers |
|---|---|---|
| **K1 Orders API** (control). `UnitCommand` = `{"units": [names], "verb": "move" \| "attack" \| "attack_move" \| "follow" \| "hold" \| "stop", "to"?, "target"?, "queue": bool, "formation"?, "source"?: "player" \| "element" \| "", "facing"?: [x, z]}`. **The response guarantee is 100 ms of wall-clock time, not a tick count** — at 30 Hz that is exactly 3 ticks with nothing spare, so 30 Hz is the floor for the simulation rate. `Match.orders` holds `Orders`: `issue`, `current(unit)`, `queue(unit)`, `complete(unit)`, signal `order_changed(unit)`, plus `pace_factor` and `station` for group moves. | control: `game/control/` | nav (executes), squad (elements issue), combat, feel (markers) |
| **K2 Weapon events** (combat). `Weapons.PROFILES` fire model fields; `Match.weapon_fired(event)`, `Match.projectile_impact(event)` (faces, `weak_spot`, `suppression_applied`), `Match.incoming_projectiles(unit)`. | combat | squad (dodging, weak spots), feel (effects) |
| **K3 Locomotion** (combat). `locomotion` (`tracks` \| `wheels`), `min_turn_radius_m`, acceleration, braking, `lateral_grip`; `TankMotion.predict/state_for/step`. **`tank_motion.gd` moves to nav for round 6** (it is the plant the controller regulates); its data fields stay combat's. | combat (data) + nav (motion) | nav, control, squad |
| **K4 Faction art slots** (feel). `unit.<faction>.<role>.hull/turret/weapon`; `make vehicle-gallery FACTION=<id>`. | feel: `game/theme/factions/` | combat (rosters) |
| **K5 Match events for the announcer** (feel). JSON-line events from fixtures or `Match`; `element_formation` and `element_drill` carry the table's reason. | feel: `game/announcer/` | squad (publishes), combat (adapter) |
| **C1 Unit catalog v2.** `Units.PROFILES[id]` = `display_name`, `role`, `blurb`, `cost`, `unlock_tier`, `hull_size`, `max_health`, `max_shield`, `shield_recharge_delay`, `shield_recharge_rate`, `max_forward_speed`, `max_reverse_speed`, `hull_turn_rate_deg`, `sight_radius`, `weapon`, `mount`, `turret_turn_rate_deg`, `fire_arc_deg`, `muzzle_height`, optional `heat_capacity`/`heat_dissipation`, `good_vs`/`weak_vs`, `armor` `{front, side, rear}`, `locomotion`, `min_turn_radius_m`, optional `faction`. Weapons carry `penetration` and `splash_radius`. | combat: `game/units/units.gd`, `game/combat/weapons.gd` | all |
| **C2 Army JSON v2.** `{"name", "squads": [{"name", "formation"?, "directive"?, "units": [{"unit": id, "paint"?, "directive"?}]}]}`; ≤ 5 squads, ≤ 5 units per squad; cost ≤ the match budget. | combat + squad | garage (paused), skirmish, match runner |
| **C3 Match result for progression.** `Match.finished(result)` includes `winner`, `reason`, per-team `units_lost`/`units_left`, kills by unit type, `duration_seconds`, `budget`. | combat | control (results), progression (paused) |
| **C4 Combat queries for AI.** `Match.friendlies_in_line_of_fire(shooter, aim_point)`, `Arena.cover_features()`, `Tank.mount`/`fire_arc_deg`/`turret_turn_rate`/`muzzle_height`, `Tank.can_bear_on(point)`, `Arena.hazards()`, `Units.armor(unit, face)`, `Match.armor_multiplier(weapon, unit, face)`. | combat | squad, nav |
| **C5 Arena layouts.** `arenas/<name>.json` = `{name, half_size, obstacles: [{type, position, rotation_deg, size?}], spawns: {green, rust}, control_point?, hazards?}`, validated point-symmetric; `--arena=<name>`; obstacle `type` maps to visual slot `prop.<type>`; `arena.dressing.setup(layout)`. | arena | feel (props), squad (cover), nav (navigation), control (radar outline) |
| **C6 Visual slots**, including per-unit ids `unit.<id>.hull/turret/weapon`; `set_team_color`, `set_paint`, `set_shield`, `set_heat`, `set_firing`, `setup`. | feel: [slot_contracts.md](slot_contracts.md) | all |
| **C7 Command API.** `SquadCommand` `{squad, verb, to, facing, formation, commander}`; `Formations.offsets(formation, count)`; `TacticalMap.command_issued`, `squad_selected(squad_key)`; `RtsCamera.follow(target)` / `focus_on(point)` / `frame(points)`. | control, squad | agent bridge |
| **C8 Progression profile.** `user://profile.json`; `Progression.BUDGET_TIERS`; `Progression.award(report, team, tier)`. | paused | — |
| **HUD messages:** `Hud.post_message(text, severity)` → cyber banners | control posts; feel renders | everyone |
| **Visibility / radar data:** `VisibilityField`, `Match.is_visible_to`, `Match.intel`, `Radar.blips()`, slot `fx.fog_of_war` | combat (field), control (radar) | feel (skin) |
| **Launch flags and console markers** (`TANK_SQUAD_*`, `MATCH_RESULT`, `GARAGE_FIGHT`, …) | each mode's owner; list in `game/main.gd` header | smoke tests, `match_series.py` |

## Invariants every stream must keep

0. **A value with a single owner is READ, not mirrored. Where it must be mirrored, the mirror FAILS LOUDLY — or it is
   not a mirror, it is a second source of truth.** (arena + combat, adopted as house policy 2026-09-19 after **five
   instances in five streams in two days**.)

   | the copy | how it failed |
   |---|---|
   | feel's copied `ROSTER` table | drifted from the catalog |
   | `make_arenas.py` mirroring `Match.SLOT_X` / `SPAWN_ROWS` / `SPAWN_ROW_SPACING` behind a comment saying *"must mirror"* | **the copy WON** — baked spawn lists beat the constants, so changing a constant changed nothing in a real match |
   | `arena_report.KIT` mirroring `ArenaKit.PROPS` | **the original was ABSENT** — `block` was missing, so the cityscape could not be authored |
   | hull sizes | read rather than copied, and **re-answered themselves** the moment the 14 m rig landed |
   | `faction_matrix.py`'s hard-coded `FACTIONS = [...]` | **adding a faction would have produced a smaller table that looked complete** |

   **The second clause is the one that bites.** Everyone already agrees copies are bad; the copies that *hurt* are the
   ones that fail **without a symptom** — where the copy silently **wins**, or where the original is silently **absent**.
   **A copy that disagrees loudly is an annoyance. A copy that disagrees quietly is a wrong number with evidence
   attached.**

   Three clauses that are part of the rule, not craft around it:
   - **A reader must NOT fall back to a hard-coded list when the parse fails. Raise.** A fallback restores the exact bug
     silently the moment the parse breaks — that is how a guard becomes decoration.
   - **Mutation-check the reader BOTH directions:** add a value and confirm the tool picks it up; rename the source and
     confirm it refuses. Otherwise the reader is no better than the copy it replaced and you will not find out until it
     matters.
   - **Prove a guard can go red before trusting it.** arena shipped **two guards that could not fire** in one session —
     four tests `unittest discover` never collected because they were bare functions, and a `WATCH` line whose value its
     own `_`-prefix convention stripped before the notes were built. **Both were green by absence, and both were found
     because a COUNT did not move, not because anything failed.**

0b. **A check must not encode a decision nobody has made.** arena declined to make the hull-cover finding a failing test:
   a red `make check` would be the tooling taking a position on a question the lead has not ruled on, **and would force
   the very fix two streams had agreed to hold.** It prints loudly on every report, stays out of `check`, and **becomes
   an assertion the day he rules.** **A tool that fails on an open question is an advocate, not an instrument.**

0c. **A technique adopted in one stream is checked against the techniques adopted in the others BEFORE either merges —
   and a brief that adopts one must name what it REPLACES.** Adopted 2026-09-19 from the external research review
   ([`research_catalog.md`](research_catalog.md) Part 2), which audited its own proposals against each other and found
   that **a majority of combinations of individually-valid techniques violate a cross-layer invariant.**

   The examples are ours and they are concrete:
   - A **space-time reservation** scheme assumes an agent executes the plan it committed to. An **event-triggered
     replanner** assumes it may abandon one at any tick. Each is correct alone. Together, one agent reserves a corridor
     slot and the other never arrives to use it. *(This pairing is why catalogue C8 is held out of round 9 while A1 is
     in it.)*
   - **Null-space priority projection** guarantees safety dominates formation-keeping. **Additive context steering**
     guarantees the opposite, by summing them. Adopt both and you get neither.

   **This is lesson 116 — *inertness does not compose* — in the design layer rather than the test layer**, and it is a
   hazard aimed squarely at how this project works: **five or six streams adopting techniques independently, in
   parallel worktrees, from one shared catalogue.** That is the organisational structure most likely to produce exactly
   this failure, and **no worker is positioned to see it. The orchestrator is.** So:
   - A brief that adopts a catalogue row states **the layer it owns**, **what it assumes the layers above and below
     will do**, and **which already-adopted mechanism it replaces**.
   - **"Replaces: nothing" is the answer to interrogate**, not the answer to accept. *Replacing* is safe; *adding
     alongside* is where two correct techniques fight.
   - Rows that touch the same code path are **sequenced, not parallelised**. A1, A7 and A11 all rewrite how a desired
     velocity is chosen; they do not go to three streams in one round.


1. **`make remote T=check` passes before merging** (lint, tests, network + relay + lobby smoke, combat, match,
   determinism, sim baseline, garage smoke). Paused areas keep their tests green.
2. **The sim baseline is recorded ONCE, by the orchestrator, on `main`, after the last simulation-changing merge of
   the round.** No stream records it — not even a stream entitled to move it. **Ruling made 2026-09-18** (combat
   proposed it; the round had three streams each about to record, and every per-stream hash was guaranteed stale):
   - **A per-stream hash is correct on a tree that will not exist by the time anything checks it.** With three
     streams moving the simulation, "whoever merges second re-records" is undefined — nobody can know at record time
     whether they are last.
   - **It fails safe.** A stale committed hash turns `sim-baseline` red on `main`, and *"the simulation broke"* and
     *"the hash is old"* look identical from the outside. That ambiguity cost round 5 a day.
   - **INERTNESS DOES NOT COMPOSE, and this is the deep reason the rule exists** (combat, 2026-09-19). *"'A is inert'
     and 'B is inert' does not give 'A+B is inert', because A can be inert only in the absence of B."* Three streams
     each measuring a green `sim-baseline` on their own branch **predicts nothing about `main` after merge** — each was
     measured against a different baseline, on a different tree, alone. **A hash that differs from what the branches
     implied is not evidence of a defect; it is the expected result of composing changes measured separately.** The
     orchestrator treated one such gap as an anomaly and sent a stream a message implying its correct claim was wrong.
   - **A change can be genuinely inert in BEHAVIOUR and not inert in the HASH.** arena's `_build_perimeter()` generates
     the arena wall from the shape polygon instead of using boxes authored in the scene: geometrically identical walls,
     **different collision bodies created in a different order, which is enough for Jolt.** Expect this from any change
     to how the physics world is *built*, even one that changes nothing about how it behaves.
   - **Nothing local can catch the mistake.** The file is keyed per glibc; the laptop is **2.39** and there is no
     2.39 line, so `sim-baseline` **silently skips locally** — every stream can commit a stale hash and watch a green
     local check.
   A stream whose change moves the simulation says so in its green report — *"the sim baseline moves and is
   deliberately NOT recorded here"* — and the orchestrator records it with `make remote T=sim-baseline-record`
   (twice, confirming it repeats) in a commit that names every change it covers.
   **AMENDED 2026-09-19, after the orchestrator read "after the last simulation-changing merge" as licence to defer
   to round close.** It does not mean that. It means *do not record repeatedly mid-round*, and it silently assumed
   merges arrive **batched at the end of a round**. In round 7 they trickled in across a long round, and the result was
   that **`main` sat red on `sim-baseline` for hours** — so every stream that merged `main` afterwards inherited a
   failure that had nothing to do with its work, could not tell whose it was, and had to ask.
   - **The orchestrator records the baseline in the same working session as any sim-changing merge to `main`** — not at
     round close. One record per *session of merging*, not one per round.
   - **A merge commit that moves the simulation says so in its subject or body.** Then a stream hitting a red
     `sim-baseline` runs `git log main --grep` and answers the question **without a round trip to the orchestrator**.
     Invariant 2 already asks streams to declare it in their green report; the merge commit needs the same declaration.
   - **The rule looked cheap because of a cost asymmetry** (combat's framing): *"the orchestrator who defers pays
     nothing, and the cost lands on every stream that merges `main` afterwards."* **A rule whose cost falls entirely on
     people who did not make the decision will always look cheaper than it is.**
   - **And a stream's red `sim-baseline` may be over-determined, so it is evidence of nothing.** combat's `d21a3d86`
     carried three of its own hash-moving changes (N7's per-objective owner, the designator's effect on *when* units
     fire, and `hull_size` as the collision box), so it would have failed *whether `main` were green or red*. **Only a
     check on `main` itself can establish `main`'s state.** Do not let a stream's failure stand in for that.
   **While the baseline is stale, THREE targets fail and two of them lie about why** (found by combat, 2026-09-18):
   `sim-baseline` says what is actually wrong, but `announcer-record-smoke` announces *"the booth changed the
   simulation"* and `music-smoke` announces *"the soundtrack changed the simulation"* — **both computing exactly the
   same hash `sim-baseline` computed, which is the proof they changed nothing.** They are feel's targets, so a feel
   agent would go hunting in audio code for a bug that does not exist. **If you see either of those messages, check
   whether the three hashes agree before believing the accusation.**
   **The root defect named (combat, 2026-09-19, after both targets PASSED on a current baseline): those two targets ask a
   DIFFERENTIAL question — "does the booth/soundtrack change the simulation?" — and implement it as an ABSOLUTE comparison
   against a shared file.** So they misfire **every time the baseline moves, i.e. once a round by design**, and they have
   been carried in feel's brief as broken for two rounds when nothing was ever wrong with the components. **The fix is to
   make the comparison differential too: run the match twice in one invocation, with and without the subsystem, and
   compare the two hashes to EACH OTHER.** A latent trap rather than a live failure — it blocks nothing. The underlying defect and its fix are in
   [orchestration.md](orchestration.md) lesson 65.
2b. **The old text, for the rules it still carries:** the baseline (`tests/baselines/sim_state_hash.txt`, one hash per glibc version; builder0 canonical) changes
   only on purpose, recorded with `make remote T=sim-baseline-record`, in the same commit as the reason.
   **Round 6: nav, squad and combat will move it** (movement and ranges are the simulation); control, arena and feel
   must not.
3. The web build still boots (`make remote T=web-smoke`) and the server still exports. Visual slots load headless.
4. Fairness: arena, spawn, or navigation changes re-run the swap-bases control ([verification.md](verification.md)).
5. Docs move with code: your brief's Status and any stale `_agents/` doc, in the same merge.
6. **Design follows [game_design.md](game_design.md)**; propose changes with evidence in your Status.
7. **Portable simulation code** (combat, nav, squad, control's order execution): [determinism.md](determinism.md)
   guidelines, and add new engine dependencies to its inventory. **Decisions must never read the wall clock** — a PID's
   `dt` is the fixed tick, not a frame delta.
8. **Heavy runs go to builder0** (`make remote T=…`, [remote_builds.md](remote_builds.md)); this laptop is for editing.
9. **Every number carries its commit, its machine, its workload and its sample size** (orchestration.md lesson 10).
   Nobody publishes a number measured across CP4.

## How to set up parallel copies: git worktrees, not folder copies

Copies drift and can't merge back cleanly. **Worktrees** are extra checkouts of the *same* repository, each on its own
branch. One command creates an isolated one:

```bash
cd ~/projects/godot                       # the main checkout, on main: the orchestrator's home
make worktree STREAM=nav     OFFSET=1     # → ../godot-nav on branch stream/nav
make worktree STREAM=squad   OFFSET=2
make worktree STREAM=control OFFSET=3
make worktree STREAM=arena   OFFSET=4
make worktree STREAM=combat  OFFSET=5
make worktree STREAM=feel    OFFSET=6
make worktrees                            # status of all of them
```

What `tools/worktree.sh` isolates:

| Shared resource | Collision risk | Isolation |
|---|---|---|
| Files and branch | agents overwrite each other | separate folder + `stream/<name>` branch |
| Network ports (servers, smoke tests, agent bridge) | two `make check`s fight over 9181/8061/8765 | `local.mk`: every port + `10 × OFFSET` |
| CPU (match series) | 6 agents × parallel matches thrash | `local.mk`: `JOBS := 2` |
| Godot `user://` (saves, logs) | garage saves / logs collide | `override.cfg`: `tank_squad_<stream>` user dir |
| `.godot/` import cache | a stale cache for another branch | per worktree (not shared) |
| `.tools/` Godot toolchain (300 MB) | none (read-only use) | shared by symlink |

## Running the agents

1. One terminal per stream: `cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`, then the `/goal`
   prompt from `HANDOFF.md` (the same text for every stream; the agent reads its stream from its folder).
2. Agents commit to their own branch as they go (they may `git push -u origin stream/<stream>` for backup).
3. **The orchestrator** reviews and integrates; after every merge, the other streams `git merge main`.
4. When a stream is finished: `make worktree-remove STREAM=<name>` (refuses with uncommitted work; keeps the branch).

**Git facts that bite with worktrees:**
- A branch can be checked out in only ONE worktree. Don't `git checkout main` inside a stream worktree.
- `git stash`, hooks, and `git config` are **shared** across worktrees. Prefer WIP commits on the stream branch.
- Deleting a worktree folder by hand leaves stale metadata; use `make worktree-remove` (or `git worktree prune`).

## What reads `hull_size`, and what each use assumes

**Written after round 9's resize landed in three places nobody was looking** (the spawn grid's "widest hull", the
asset contract's refit, the screening bar) — so the next resize has a checklist instead of three surprises.
`Units.PROFILES[*]["hull_size"]` is `[width, height, length]` in metres and **it is the collision box**, so it is not
a display number: 42 call sites read it. One line each, with the assumption that makes it a consumer rather than a
reader.

| consumer | reads | assumes |
|---|---|---|
| `tank.gd::_apply_hull_size` | all three | **`hull_size` IS the collider**; box bottom at the unit origin (`position.y = h/2`), hull art scaled to the box |
| `match.gd:1383` friendly-fire risk | w, l | the hull is a **disc** of the box's diagonal — see the hazard below |
| `match.gd:1450` `incoming_projectiles` | w, l | same disc |
| `ai/incoming_fire.gd:101` | w, l | same disc, and **caches it per `unit_id`** (`_radius_by_unit`) — a size that changed at runtime would not be re-read |
| `match.gd::screen_for` + screening geometry | w | a wider screen shadows more; the 0.35 bar in `test_combat_screening` was calibrated against a 2.40 m dozer |
| `match.gd:1637` `tank_destroyed` payload | all three | FX size the wreck from the event, not the catalog |
| `theme/fx/weapon_fx.gd:337,342` | from the event | fire shape scales to the dead hull |
| `ai/avoidance.gd:54` | w, l | avoidance radius `(w + l) / 4 + margin`; **fallback `[2.4, 1.6, 3.8]`** |
| `ai/movement.gd:708, 1700` | w, l | routing clearance; **same stale fallback** |
| `tactics/tactics_formation.gd:90` | w, l | `hull_extent` / `hull_floor` → formation spacing; fallback `[0,0,0]` is the deliberate `NO_HULL` sentinel |
| `tactics/army_layout.gd:302` | w, l | assembly depth and frontage; **fallback `[2.6, 1.8, 4.0]`** |
| `arena/arena.gd` + `cover_tables.gd` | l | `cover_fraction(..., hull_length)` — A3 chord cover is a function of length |
| `control/rts_controls.gd:1075` | h | HUD bar sits at `hull[1] + BAR_ABOVE_M` |
| `control/rts_controls.gd:1202` | all three | selection picking |
| `assets/pipeline/asset_contracts.gd` + `asset_checker.gd` | all three | art **refitted by LENGTH** must match the box's width and height; refits from the mesh's *authored* pose |
| `theme/fx/bench/size_look.gd` | all three | `box_at_length` — the function the numbers come FROM |
| `theme/cyberpunk/dozer_part.gd`, `factions/faction_art.gd` | l | `_fit_to_hull` scales art by `hull_size[2] / FactionArt.hull_length` |
| `garage/catalog_stub.gd` | — | **hardcodes pre-CP2 boxes** for the garage stub |
| `tools/roster_scale.py`, `tools/arena_report.py` | all three | the table and the reports |
| `Match.SLOT_X` clearance (spawn grid) | w, l | adjacent columns and rows must clear the widest/longest hull |

**⚠ THE HAZARD THE LIST FOUND, unflagged until now: three consumers model a hull as a DISC of its diagonal**
(`Vector2(w, l).length() / 2`). That is fine for a roughly square hull and wrong for a slab:

| unit | w × l | disc radius used | real half-width | error |
|---|---|---|---|---|
| `gang_tank` | 3.32 × 14.00 | **7.19 m** | 1.66 m | **4.3×** |
| `tank` | 2.40 × 8.62 | 4.47 m | 1.20 m | 3.7× |
| *pre-CP2 worst* | 2.4 × 4.2 | 2.42 m | 1.20 m | 2.0× |

So the AI treats a War Rig as a **14.4 m-wide circle** for friendly-fire avoidance and incoming-shell threat. Before
CP2 the worst case was 2× and the error was centimetres; now it is metres. **Not fixed here and not this stream's
files** — recorded so it is a decision rather than a discovery.

**⚠ ONE NUMBER, TWO SITES, OPPOSITE ERRORS — whoever fixes the disc sites must NOT "fix" the turning envelope the
same way.** The half-diagonal above is *also* the room a hull needs to **turn**, and there it is the **right**
number: on a tree where hulls start where they were placed, four crews overlap at spawn (−1.36, −0.02, −0.01,
−0.77 m) and the off-slot crews of the five-squads test never depart — their first turn refused in the press —
because **the spawn grid and the formation both space by WIDTH**. So:

| the same `Vector2(w, l).length() / 2` | at `match.gd:1383`, `match.gd:1450`, `incoming_fire.gd:101` | at the spawn grid and `TacticsFormation` |
|---|---|---|
| **overstates where a hull IS** | friendly-fire refuses safe shots; shells read as threats they are not | — |
| **correctly states the room to TURN** | — | spacing by width under-provisions it, and a hull cannot make its first turn |

**Fix the first by using an oriented box; fix the second by spacing on the half-diagonal.** Doing either
substitution at the other site makes it worse.

**⚠ AND THE STALE FALLBACKS:** `[2.4, 1.6, 3.8]` (three sites) and `[2.6, 1.8, 4.0]` are **pre-CP2 sizes** that apply
silently when a `unit_id` is unknown. They cannot be reached by a shipped unit today, which is exactly why nothing
catches them — a fallback that never fires is indistinguishable from a correct one.
