# Workstreams: the current round

> **Round 24 is RUNNING (launched 2026-10-08 ~21:00 PDT): two streams, brains and native** (the section below). Round 23
> is CLOSED (its briefs in `streams/archive/round23/`, its contracts C23.1–C23.5, C23.1a kept below).

## Round 24: two streams (launched 2026-10-08 night)

**Goal: his bug from playing round 23's close (`game_design.md` *Round 24 direction*: crews ordered across the Locks'
bridge drive into the river and stick; one squad of a big group takes another route and leaves the army) and his
decision of round 23 (the whole per-vehicle tick in C++, `native.md` N3). The bridge goes FIRST (CP1), because the
native rewrite freezes the files it lives in (`roadmap.md` *Round 24 candidates* 1b).**

| Stream | Brief | Round 24 | Checkpoint |
|---|---|---|---|
| **brains** | [streams/brains.md](streams/brains.md) | **R0** his bridge case reproduced from the recording, the layer named; **R1** the fix, a scenario on the Locks, a nav check on every map with water; **R2** squads ordered together keep to the body's route (a cost on detaching, DECLARED, symmetric); stretch: the nav guard in `make check`, B1's 0.75 s priced | **CP1**: R1 merged ALONE → native merges main, the freeze starts |
| **native** | [streams/native.md](streams/native.md) | **N3a** the per-tank record + contacts table + the execute step's map (equal / declared), before CP1; **N3b** the execute step's leaves; **N3c** `Movement.drive` as one native call per tank; **N3d** think's `situation` | each step priced at three sizes on builder0 → the orchestrator's laptop table |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
brains `game/ai/**` minus native's below, `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`,
`tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `mk/ai.mk`, `mk/nav.mk`,
`mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares · native `native/**`, `game/ai/native/**`,
`mk/native.mk`, `avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `brain_switches.gd` (additive),
`incoming_fire.gd`'s seam, the C23.1a seam in `pathing.gd`, `tests/test_native*.gd`, `tests/native/**`,
`_agents/native.md`, and after CP1 the freeze set (C24.1). **Nobody this round** (a request through the orchestrator):
`game/control/**`, `game/ui/**`, `game/theme/**`, `game/match/**`, `game/tank/**`, `game/units/**` (`MAX_SQUADS` is the
orchestrator's, C24.4), `game/garage/**`, `game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`,
`game/announcer/**`, `arenas/**`, `game/arena/**`, `tests/baselines/**` (except declared lines), `tools/remote.sh`,
`tools/slot.sh`, `mk/core.mk` (native's `check` → `native` hook stands).

**Contracts (round 24):**

- **C24.1 The freeze.** The freeze set is the per-vehicle tick: `game/ai/movement.gd`, `tank_brain.gd`, `gunnery.gd`,
  `perception.gd`, `ai_tick_cache.gd`, `bot_controller.gd`, `wall_contact.gd`, `pid.gd`, `clothoid.gd` (plus native's
  own `avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `incoming_fire.gd`). **Until CP1** they are
  brains' (the bridge fix), and native does not edit `movement.gd` or `tank_brain.gd`. **From CP1 to the round's
  close** native owns them for porting: seams and the GDScript reference paths; no behaviour changes except a port's
  DECLARED one (C24.2). Brains changes no behaviour in them after CP1; a fix it needs there (R2, or a bug) is a
  request through the orchestrator, applied by native or by the orchestrator on main and merged into both. Brains
  keeps `squad.gd`, `order_controller.gd`, `formations.gd`, `cpu_commander.gd`, `element_feed.gd`, `order_feed.gd`,
  `squad_tactics.gd`, `tactical_query.gd`, `pathing.gd` (minus C23.1a) and `game/tactics/**` all round.
- **C24.2 Every port is equal or DECLARED** (C22.2, C23.1 carried). Equal = bit-exact against the LIVE GDScript (the
  N2b proof pattern: the test calls the live function, so a later edit to it that the C++ does not follow fails
  the check), the hashes equal in `native-proof`, `ai-parity` and `element-digest` unchanged. A port that cannot be
  exact (Dictionary-ordered tie-breaks) is said in advance in `native.md`'s map, lands as one commit behind its own
  switch with the paired series (equal outcomes), and the orchestrator rules ON/OFF and takes it to him.
- **C24.3 Every change to fights is declared** (C22.2, C23.5 carried): brains' R1 (if it moves crews) and R2 each one
  commit, merged alone, a scenario and a paired series, the arrive series part of green for a movement change; the
  CPU gets the same behaviour (symmetric). Everything else pre-registers UNMOVED on the thirteen lines and
  determinism.
- **C24.4 The cap is a measured number, the laptop is the fact** (C23.3 carried). The orchestrator runs the laptop
  table with native ON at the launch (`make native` on the laptop, then `make perf-fight PERF_FIGHT=size
  PERF_FIGHT_SIZES="25 30" PERF_FIGHT_NAME=pf-r24-base`, his preset, a quiet window; the laptop is the orchestrator's
  until it says done) and after each native step on main; files it under `streams/references/round24/perf/laptop/`.
  The bar: 50 v 50 leaders in contact ≤ 25 ms a tick on the laptop → `Units.MAX_SQUADS` → 10 (army's A4 recipe),
  by the orchestrator, alone, checked; until then the cap moves to the largest size under the bar, if any.
- **C24.5 Squads ordered together** (brains' R2): the route choice for a group order prefers the body's route; the
  cost is a cost (a real split that saves time is allowed and written down), applies to the CPU's grouped orders,
  and is measured with `game/tactics/coherence_probe.gd` on his case.
- **C24.6 (granted 2026-10-09 ~05:00, brains' request after measuring): two seams in `game/ai/tactical_query.gd`.**
  Native may add, at the top of `TacticalQuery.find_cover_fire` and `TacticalQuery.find_cover`, a seam `if
  BrainSwitches.native and BrainSwitches.native_tq: return NativeBridge.impl.<fn>(...)` over a C++ port of those
  functions with their helpers (`hull_hidden`, `peek_from`, `_cover`, `_candidates`: pure over `CoverMap` + the
  request), equal answer by the live-function proof (`tests/test_ai_tactical_query.gd` cases plus seeded requests
  from real situations), ruled ON/OFF by the in-contact laptop rule. Nothing else in that file; brains does not edit
  those functions while the seam is open (it tells the orchestrator first). Brains' measurement (builder0, 50 v 50
  leaders, pinned, n = 1, profiling on, `9cc1aca7`): `find_cover_fire` ~1.1 ms a call (~15 hidden/peek searches),
  0.86 ms a tick; `find_cover` ~0.7 ms a call, 0.21 ms a tick; every crew asks its own question, the sight lines
  under them already native: what is left is GDScript loop overhead (lesson 276's whole-loop shape).
- **C24.7 (2026-10-09, his decision): the round's bar is 25 a side with no slow motion in the opening clash on his
  laptop.** Measured by the orchestrator with `make native-tick-profile` (his preset, 25 a side, foundry + parade × 3
  seeds, window 8–20 s, n = 6, uninstrumented frame from `perf-fight`'s per-phase timeline as the second reading):
  **game speed in the window ≥ 0.97** (ticks a frame × 33.3 ms ÷ frame ms; today 2.94 × 33.3 / 124 ≈ 0.79, pinned at
  the catch-up cap). `Units.MAX_SQUADS` stays 5. **The think-rate change (brains' L1)** is a DECLARED behaviour change
  (C24.3): one commit, alone, both sides, decided from simulation state only (contact, reach, distance, orders;
  never the camera, the selection or the machine), with a scenario and the paired series (arrive, the beaten zone,
  the pursuit, his recordings' cases), priced in contact on the laptop. **Ownership for it:** brains owns, in
  `tank_brain.gd`, the think-scheduling hunk (the `*_THINK_*` constants, `_think_hz` and the rate choice around
  `t.rate_progress`, `brain_stride`) and whatever new per-crew urgency read it needs in its own files; native owns
  the rest of the freeze set as before and does not edit that hunk. A conflict in that file resolves by hunk owner.
- **C24.8 (granted 2026-10-09 ~09:00, from native's elements breakdown): the element's grounding and plan, ported.**
  Native may add seams (behind a new switch `native_el`, ruled by the in-contact laptop rule) at the top of
  `SlotGround.standable_from`, `standable_for` / `_standable_for` (with `_settle`, `_fits`, `_off_mesh`, `wet`,
  `over_water`, `on_anchor_side`, `pulled_dry` as the C++ needs them) in `game/tactics/slot_ground.gd`, and of
  `ElementPlan.build` in `game/tactics/element_plan.gd`, over C++ ports proven equal against the LIVE functions on
  requests seeded from real fights (every map with water among them: CP1's rules must survive bit for bit). Nothing
  else in those files. Brains does not edit those functions while the seams are open (tells the orchestrator first).
  The measurement (native, builder0 headless, Sumps 25 a side + leaders, 8–20 s, 3 seeds, throwaway laps on
  `c8ca14dc`): elements = 21.7 % of the tick's scripts; `Element.update` → `u.ground` 1.57 ms (37 % of elements:
  apply_swap + ground + ground_stations → SlotGround per slot and per order goal), `u.plan` 1.07 (25 %),
  `u.situation` 0.63, `u.issue` 0.34, `u.etas` 0.23 (absolute ms on a lighter run; read the shares).
- **C23.1a, C23.2, C22.4–C22.7, C21.1, C21.3–C21.5, C20.1, C20.4, C20.5, C19.3–C19.7, C18.7, C16.3, C12.6, C18.3 stand.**

**Bar (from 2026-10-09, his decision):** C24.7 supersedes C24.4's 50-a-side bar for this round.

**Checkpoints:** **CP1** brains' R1 (the bridge) merged ALONE the moment it is green → native told to merge main; the
freeze starts. **The laptop table** (the orchestrator's, the launch night) → native's bar; re-run per native step on main.

**Decided for him (reversible, recorded in `game_design.md` *Round 24 direction: the launch*):** the bridge first, the
rewrite second; two streams (orders, army, perf rest); R2 as a cost on detaching, not a rule that squads never split.

**Standing rules:** rounds 12–23's (lessons 225–278).

> **No round is running. Round 23 is CLOSED (2026-10-08): three streams, brains, native and orders, all merged;** its
> briefs are in `streams/archive/round23/`, its contracts (C23.1–C23.5, C23.1a) kept below. Round 24 is planned: the
> per-vehicle tick rewritten in C++ (the lead's decision; `roadmap.md` *Round 24 candidates*, `native.md` N3).

> **Round 23 is RUNNING (launched 2026-10-07 ~23:45 PDT): three streams, brains, native and orders** (the section
> below). Round 22 is CLOSED (its briefs in `streams/archive/round22/`, its contracts C22.1–C22.7 kept). Rounds 21
> (C21.1–C21.5), 20 (C20.1–C20.5) and 19 (C19.1–C19.7) stand.

> **No round is running. Round 22 is CLOSED (2026-10-08): four streams, army, brains, orders and perf, all merged;**
> its briefs are in `streams/archive/round22/`, its contracts (C22.1–C22.7) kept below. Rounds 21 (C21.1–C21.5), 20
> (C20.1–C20.5) and 19 (C19.1–C19.7) stand.

## Round 23: three streams (launched 2026-10-07 night, CLOSED 2026-10-08; briefs in `streams/archive/round23/`)

**Goal: his first item after playing round 22's close (`game_design.md` *Round 23 direction, first item*: a line
abreast only formed at the end because the lead vehicle was already nearest the target; some vehicles should slow so
the squad forms on the way) and the per-vehicle tick that caps the army at 25 (round 22's verdict: ~0.6–0.8 ms per
vehicle per tick on builder0, four fifths the vehicle brain, the profile flat, equal-answer cuts ≤ 2 %, native code
the candidate). Three streams, one problem each: brains (the squad paces itself on the way; the per-crew fire read;
the grace under three guns), native (a C++/godot-cpp toolchain, then the brain's hot loop ported where it pays, the
sim hash + the full suite the proof, priced by in-run A/B), orders (two columns 28 m apart, decided by him; the alert
strip clears the edge chips; the held crew's readout; ten AUTO squads on the click). The laptop baseline at 25 and 30
a side is the orchestrator's first measurement, run the launch night (lesson 271).**

| Stream | Brief | Round 23 | Checkpoint |
|---|---|---|---|
| **brains** | [streams/archive/round23/brains.md](streams/archive/round23/brains.md) (CLOSED) | **B0** his case reproduced and measured; **B1** the fast crew slows, the anchor paces to the slowest seat (DECLARED, alone); **B2** `UnansweredFire.crew_reason` for orders (C23.2); **B3** under three guns act inside the grace (DECLARED, alone) | **CP1**: B1 (+ B2 if ready) merged ALONE → native merges main before touching `movement.gd` |
| **native** | [streams/archive/round23/native.md](streams/archive/round23/native.md) (CLOSED) | **N0** the toolchain priced by a no-op (godot-cpp 4.7, `make native`, `make check` with and without the `.so`); **N1** Avoidance native; **N2** Movement's geometry; **N3** the data reshaped (the execute step as one native call per tank); the number per step at 50 v 50, builder0 | N0 green → merged early (everyone's `make check` changes) |
| **orders** | [streams/archive/round23/orders.md](streams/archive/round23/orders.md) (CLOSED) | **O1** two columns 28 m apart (his answer); **O2** the alert strip clears the edge chips and the panel header (`edge_markers.gd` lent, C23.4); **O3** the held crew's readout (consumer of C23.2); **O4** ten AUTO squads stand on the click | C23.2 consumer (stub until B2 lands) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
brains `game/ai/**` minus native's files below, `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`,
`tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`,
`mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares, and in
`game/ai/movement.gd` the `speed_factor` / `_keep_station` / station-PID hunks · native `native/**`,
`game/ai/native/**`, `mk/native.mk`, `game/ai/avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`,
`brain_switches.gd` (additive), `incoming_fire.gd`'s `closest_approach` only, and in `game/ai/movement.gd` the
pure-geometry seams (`_chord_compute`, `_arc_hit`, `_outline_ok`, the call into `Avoidance`), `tests/test_native*.gd`,
`tests/native/**`, `_agents/native.md`; `Makefile`, `mk/core.mk` (the `check` → `native` dependency), `project.godot`,
`.gitignore`, `export_presets.cfg` additive in merge notes · orders `game/control/**`, `game/ui/formation_picker.gd`,
`selection_panel.gd`, `group_bar.gd`, `squad_chip.gd`, `selection_markers.gd`, `command_icons.gd`, `tactical_map.gd`,
`radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`, **`game/ui/edge_markers.gd`
(lent from perf this round)**, `tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_tactical_map.gd`,
`tests/test_element_preview.gd`, `tests/test_touch.gd`, `mk/command.mk`. **Nobody this round** (a request through the
orchestrator): `game/match/**`, `game/tank/**`, `game/announcer/**`, `game/garage/**`, `game/units/**` (army resting:
`Units.MAX_SQUADS` flips back to 10 at the close by the orchestrator; orders may flip it LOCALLY to measure at ten,
never committed), `game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`, `game/web/**`, the rest of
`game/ui/**` and `game/theme/**` (perf resting), `arenas/**`, `game/arena/**`, `tests/baselines/**` (except declared
lines), `tools/remote.sh`, `tools/slot.sh` (the orchestrator's; native's build dir may need an rsync rule: a request).

**Contracts (round 23):**

- **C23.1 Two streams in `game/ai/`, one file shared by hunk.** Brains owns the brain's behaviour (`tank_brain.gd`,
  the element/transit code, `movement.gd`'s speed and station-keeping); native owns the pure pieces it ports
  (`avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `brain_switches.gd` additive) and, in
  `movement.gd`, ONLY the pure-geometry functions named above, wrapped as `if NativeBridge.available: return
  Native.x(...)` seams. Each lists its `movement.gd` hunks in merge notes; the orchestrator resolves a conflict in
  favour of the owner of the hunk. Native does not touch `movement.gd` before CP1 (brains' B1) is on main and merged
  into its branch. Native never changes an answer (equal hash in `ai-ab-match`, the full check, `ai-parity`,
  `element-digest`); if a piece cannot be bit-exact it is a DECLARED change under C22.2, said in advance.
- **C23.1a (granted 2026-10-08 01:45, native's request): one function in `game/ai/pathing.gd`.** Native may add,
  above the engine call in `Pathing.closest_point`, the three-line seam `if BrainSwitches.native and
  BrainSwitches.native_nav: return NativeBridge.impl.closest_point(map, point)` (its N2a: a grid-indexed closest
  point equal to the engine's linear scan by construction, 13 maps × 961 points 0 mismatches). Nothing else in that
  file; brains' B1 does not touch it (checked); listed in native's merge notes. Finding filed: Godot 4.7.2's
  `map_get_closest_point` scans every navmesh polygon with no broadphase (429 calls a tick at 14.5 µs = 14.5 % of
  the brains' work at 50 v 50).
- **C23.2 The per-crew "fire I cannot answer" read.** Brains provides
  `UnansweredFire.crew_reason(game_match: Match, unit_name: String) -> String` (static; returns
  `UnansweredFire.WHY_HELD` while the named crew is being hit by something it cannot return, by B1's own test, for a
  crew inside OR outside an element; "" otherwise; no cost unless called). Orders reads it for the selected crew(s)
  under a direct hold and shows the same words; until it lands, orders stubs it in its paths (a static in
  `game/control/` returning "") and wires the readout against the stub. B2 merges with CP1 or as its own
  equal-answer merge.
- **C23.3 The cap is a measured number, and the laptop is the fact** (C22.3 carried, lesson 271). The orchestrator
  runs the laptop baseline (`make perf-fight PERF_FIGHT=size PERF_FIGHT_SIZES="25 30" PERF_FIGHT_NAME=pf-r23-base`,
  his preset, a quiet window) the launch night and files it under `streams/references/round23/perf/laptop/`; native
  reports builder0's controller band per step (his Sumps, 25 v 25, 50 v 50; `taskset -c 0-3`; n = 3); when a step
  lands on main the orchestrator re-runs the laptop command. The bar: 50 v 50 with leaders in contact ≤ 25 ms a tick on
  the laptop (p95 frame at 50 ≤ p95 at 25 on round 21's main + 25 %, perf's bar, as the second reading). When met,
  `Units.MAX_SQUADS` → 10 (army's A4 recipe, `streams/archive/round22/army.md`), by the orchestrator, alone, checked.
  Until then the cap moves to the largest size under the bar in the table, if any.
- **C23.4 `edge_markers.gd` is orders' this round** (perf resting): the alert strip and the off-screen element chips.
  Perf's round-22 `alert_y()` rule (the strip clears the group bar's top) stays; orders adds the chips and the
  panel header. Frames at both aspects filed.
- **C23.5 Every change to fights is declared** (C22.2 carried): brains' B1 and B3 each one commit, merged alone, a
  scenario and a paired series, the arrive series part of green for a movement change; everything else, every
  stream, pre-registers UNMOVED on the thirteen lines and determinism (the match runner forms no elements: brains'
  transit change is expected UNMOVED and still declared).
- **C22.4–C22.7, C21.1, C21.3–C21.5, C20.1, C20.4, C20.5, C19.3–C19.7, C18.7, C16.3, C12.6, C18.3 stand.**

**Checkpoints:** **CP1** brains' B1 (his item) merged ALONE the moment it is green → native and orders told to merge
main. **N0** (the toolchain) merged early on its own, checked with and without the `.so` → everyone's `make check`
builds the `.so` on builder0; told. **The laptop table** (the orchestrator's) → native's bar; re-run per native
step on main.

**Decided by him at the launch (2026-10-07 ~23:00):** two columns 28 m apart (yes); the Syndicate range gap stays.
**Decided for him (reversible, recorded in `game_design.md` *Round 23 direction: the launch*):** C++ through
godot-cpp for native code (he asked whether it meant Rust; the recommendation stands unless he says otherwise).

**Standing rules:** rounds 12–22's (lessons 225–274).

## Round 22: four streams (launched 2026-10-07 afternoon, CLOSED 2026-10-08; briefs in `streams/archive/round22/`)

**Goal: his two items after playing round 21 (`game_design.md` *Round 22 direction*): the army DOUBLES (ten squads of
five, 50 vehicles, 2000 credits; the final cap set by his frame on the laptop at 50 a side), and a vehicle that is
being shot by something it cannot answer does not sit on its post until it dies. Four streams, one problem each:
army (the garage, the budget, the cap), brains (the sitting duck; the commander at ten squads; the sim's tick at 50 a
side), orders (ten control groups, ten squads selected and shown, the body at ten), perf (his frame on the laptop at
50 a side: measured, then cut as equal-output changes and hardware presets).**

| Stream | Brief | Round 22 | Checkpoint |
|---|---|---|---|
| **army** | [streams/archive/round22/army.md](streams/archive/round22/army.md) (CLOSED) | `MAX_SQUADS` 10, the budget 2000 CR, the cap 50, in ONE place each (C22.1); the garage fits ten squads on desktop and phone; the CPU opponent buys 2000; suggested armies and the tour at ten; the hint text | **CP1**: the constants + the opponent, merged ALONE → everyone merges |
| **brains** | [streams/archive/round22/brains.md](streams/archive/round22/brains.md) (CLOSED) | **the sitting duck** (B1: a crew under fire it cannot return closes, breaks the line of fire or falls back, both sides; from his recording); the commander and `ArmyLayout` at ten elements a side (B2); the sim's tick at 50 v 50 with leaders on builder0 and the slot-grounding cut (B3); the Syndicate range gap measured for him (B4) | B1 and B3 declared, alone (C22.2) |
| **orders** | [streams/archive/round22/orders.md](streams/archive/round22/orders.md) (CLOSED) | control groups 1–9 and 0 (O1); the selection panel, group bar and squad chips at ten squads, desktop and phone (O2); the body at ten squads (ranks of three, O3); the radar and tactical map at 50 a side (O4); the probes at ten | CP1 consumer |
| **perf** | [streams/archive/round22/perf.md](streams/archive/round22/perf.md) (CLOSED) | his frame on the laptop at 25 v 25 and 50 v 50 with leaders on (P1: the number that sets the cap, C22.3); the frame's cost by removal (P2); equal-output cuts in render, FX and the HUD's per-unit work (P3); what remains as a hardware preset (P4) | P1's number to the orchestrator the same day |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
army `game/garage/**`, `game/progression/**`, `game/units/units.gd` (`DEFAULT_BUDGET` and prices only), `game/ui/widgets/cyber_*.gd`,
`conductors.gd`, `game/ui/widgets/title/**`, `game/theme/game_theme.gd` `ui` palettes, `doctrines/player_*.json`,
`tests/test_army*.gd`, `tests/test_units_catalog.gd`, `tests/garage/**`, `mk/garage.mk`, `_agents/ui_kit.md`,
`_agents/balance.md` *Economy*, `assets/units/thumbs/**` · brains `game/ai/**`, `game/tactics/**`, `tests/ai_scenarios/**`,
`tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`,
`mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares · orders `game/control/**`,
`game/ui/formation_picker.gd`, `selection_panel.gd`, `group_bar.gd`, `squad_chip.gd`, `selection_markers.gd`,
`command_icons.gd`, `tactical_map.gd`, `radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`,
`tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_tactical_map.gd`, `tests/test_element_preview.gd`,
`tests/test_touch.gd`, `mk/command.mk` (its `hud-profile` and `hud-digest` targets are LENT to perf, read-only for orders this round) · perf `game/theme/fx/**` (minus `order_feedback.gd`),
`game/theme/cyberpunk/**`, `game/theme/arena_kit/**`, `game/ui/hud.gd`, `hud.tscn`, `hud_messages.gd`, `unit_bars.gd`,
`unit_portraits.gd`, `edge_markers.gd`, `draw_batch.gd`, `hud_cost_probe.gd`, `game/ui/widgets/hud_skin.gd`,
`tools/perf*`, `tests/test_hud*.gd`, `tests/test_theme*.gd` (minus the airship two, still airship-owned at rest),
`tests/test_fx*.gd`, `mk/fx.mk`, `_agents/show_dials.md`, `_agents/lighting.md`, `_agents/legibility.md` *the HUD's
cost*. **Nobody this round** (a change there is a request through the orchestrator): `game/match/**`, `game/announcer/**`,
`game/ui/scoreboard*.gd`, `arenas/**`, `game/arena/**`, `game/tank/**`, `game/combat/**`, `game/modes/**` (one
constant for army if the skirmish's default army size lives there, listed), `game/camera/**`, `game/network/**`,
`game/audio/**`, `game/web/**`, `export_presets.cfg`, `mk/core.mk` (`perf-play` is read-only for perf; a change is a
request), `mk/web.mk`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`. `game/main.gd`,
`project.godot`: additive only, in merge notes. Tests: each stream owns the `tests/test_*.gd` of its area; a test another
stream's change breaks is fixed by the owner of the behaviour, by request.

**Contracts (round 22):**

- **C22.1 The army's size lives in one place each, and CP1 is the constants.** **Amended at launch+1 h (army's finding):** the
  squad count is `Units.MAX_SQUADS := 10` in `game/units/units.gd` (army's), read by `ArmyCatalog.MAX_SQUADS`,
  `SquadConsolidation.MAX_SQUADS` (which folds HIS army before it spawns) and `Doctrine.PLAYER_MAX_SQUADS` (two
  one-line edits in brains' paths, granted, in army's merge notes); tactics never imports the garage. `Units.DEFAULT_BUDGET`
  STAYS 1000 points (the flagless skirmish's fixed 5-vehicle player_default v a 1000-pt CPU and every match-runner
  experiment lean on it; army's decision, accepted); the garage alone goes to 2000 CR. Original text: `ArmyCatalog.MAX_SQUADS` (10),
  `ArmyCatalog.MAX_SQUAD_SIZE` (5, unchanged: `Formations.MAX_MEMBERS` stays 5, brains' invariant), the garage's budget
  (2000 CR; `Units.DEFAULT_BUDGET` follows in points so `make skirmish` without a faction fields the same size, army
  decides and records), and the CPU opponent's purchase (`GarageOpponent.UNIT_CAP` derives). Everyone else READS them;
  nobody hard-codes 5, 10, 25, 50, 1000 or 2000 for an army size (grep in the merge). CP1 = those constants + the
  opponent + the catalog's tests, merged ALONE with the archetype × seed proof that `Army.cpu_army` for the baselines
  (`Units.BASELINE_BUDGET`, explicit flags) is untouched; the thirteen lines UNMOVED. The garage's screen for ten
  squads follows CP1 on the same branch.
- **C22.2 Every change to fights is declared** (C21.2 carried): brains' B1 and any B3 cut that is not equal-answer are
  each one commit, merged alone, lines adopted and named; B1 has a scenario from his recording AND a paired series
  (hold stage, parade and foundry, 8 then 24 seeds); the arrive series for any movement change. Everything else, every
  stream, pre-registers UNMOVED on the thirteen lines and determinism.
- **C22.3 The cap is a measured number.** Perf's P1 measures his frame on the laptop (his preset, his window, the
  garage's path, CPU leaders on) at 25 v 25 and 50 v 50 (and 40 v 40 if 50 fails): mean and p95 frame ms over ≥ 3
  seeds × 120 s, with `make perf-play` (read-only, nobody's `mk/core.mk`; perf asks for a target of its own in
  `mk/fx.mk` if it needs one). The orchestrator runs the laptop half in a quiet window (lesson 260) or hands him the
  command; builder0 gives ratios only. If 50 a side is not smooth at the laptop preset after P3's cuts (bar: p95 ≤ the
  25-a-side p95 at round 21's main + 25 %), the cap drops to the largest size that is, and army scales the credits
  (40 → 1600, 30 → 1200). The orchestrator decides the number and tells army; army builds for 10 regardless, with
  the constant.
- **C22.4 The sim's tick is brains', the frame is perf's.** Brains prices the simulation at 50 v 50 with leaders
  (`sim-profile`, `ai-ab-match`, builder0) and cuts there; perf prices everything else (render, FX, HUD, dressing) and
  cuts there; neither quotes the other's number as its own, and both put their numbers in the same table in HANDOFF
  (commit, machine, workload, n).
- **C22.5 Ten groups, one keyboard.** Orders: keys 1–9 and 0 (0 = group 10); `ControlGroups` holds ten; the group bar,
  squad chips and selection panel lay out ten on desktop and at phone aspect; the garage's squads 1–10 map to groups
  1–10 (army reads `ControlGroups.MAX_GROUPS`, orders' constant; until it lands, 10 literal in army's tests only).
  The HUD files perf owns are not where the squad row is drawn (`group_bar.gd`, `squad_chip.gd` are orders'); if
  perf's HUD cut touches their layout it is a request.
- **C22.6 Symmetric, and a direct order still wins** (lesson 264): brains' B1 runs for his crews under a hold too, and
  under his explicit order a crew does what he said (a `hold` he gave is his; the element's hold is the leader's and
  may be left). The scenario states both arms.
- **C22.7 (granted at launch+2 h, from perf's P0): the tick's hot paths outside brains' tree.** `game/match/match.gd`'s
  per-tick paths (+12.1 ms a tick at 41 vehicles in contact, builder0) are brains' for EQUAL-ANSWER cuts (declared if a
  line moves; in merge notes); `game/announcer/announcer_booth.gd` WAS perf's for one equal-answer cut of a measured +2.3 ms of
  TICK; **withdrawn**: re-measured alone over 8 bracketed cycles it is +0.35 ms mean with per-cycle signs disagreeing
  (the 2-cycle sweep read the fight's own drift); not a defect, no edit. `game/tank/tank.gd` (+3.2) stays nobody's: named, requested.
  **B3 is the round's critical path:** the tick costs ~0.7 ms per vehicle in contact on builder0 (~2 ms on his laptop),
  so 50 a side cannot ship at today's cost; the cap (C22.3) is decided after B3's first cut, not before.
- **C21.1, C21.3–C21.5, C20.1, C20.4, C20.5, C19.4–C19.7, C18.7, C16.3, C12.6, C18.3 stand.**

**Checkpoints:** **CP1** army's constants + opponent → merged alone, checked, everyone told to merge (brains' B2 and
orders' O2–O4 read the real cap; perf's P1 50-a-side runs need it). Perf's **P1 number** → the orchestrator the same day
→ the cap decided → army told. Brains' declared changes: whichever is green first, each alone.

**Questions to him this round (asked in the launch message, one recommendation each):** the airship on the Cut /
Docks / Sumps (round 22 candidate 1; recommended: try the flag in one game and say); the Syndicate-over-gangs range
gap (candidate 2; recommended: leave it, a 120 CR platform should beat 40 CR scouts in the open).

**Standing rules:** rounds 12–21's (lessons 225–270).

## Round 21: three streams (launched 2026-10-06 evening, CLOSED 2026-10-07; briefs in `streams/archive/round21/`)

**Goal: the two things he saw in his two games after round 20 (`game_design.md` *Round 20, afternoon* and *Round 20,
evening*), and the one thing he never saw. (1) When he attacks a vehicle that runs, his scouts circle instead of
chasing it, and an attack-move still sends one scout forward per squad and holds the rest: brains. (2) When five
squads are ordered together the outer squads first drive 100 m sideways: orders. (3) He played whole matches on the
built-up maps and the airship was never in his frame (0–3 % of the flight on five rotation maps): airship. Each stream
is one independent problem; brains and orders share the attack order and have a contract (C21.1).**

| Stream | Brief | Round 21 | Checkpoint |
|---|---|---|---|
| **airship** | [streams/archive/round21/airship.md](streams/archive/round21/airship.md) (CLOSED 2026-10-07) | the airship is in his frame for a real share of every rotation map at his pose, without hiding the fight more than today; the report reads the live rotation; frames looked at | none needed (isolated) |
| **brains** | [streams/archive/round21/brains.md](streams/archive/round21/brains.md) (CLOSED 2026-10-07) | no bait/encircle under ANY player order (attack-move included); an attack on a named target that moves is a PURSUIT; stretch: the hold falls back when losing; the in-run A/B for the leaders' price | each declared change alone (C21.2) |
| **orders** | [streams/archive/round21/orders.md](streams/archive/round21/orders.md) (CLOSED 2026-10-07) | several squads, one click: the row's width capped (a second rank behind, not 400 m abreast); a probe case for it; the Parade bay slot | **CP1**: O1 merged → brains told to merge (its five-squad scenarios read the real layout) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
airship `game/theme/arena_kit/airship/**`, `tests/test_theme_ad_airship.gd`, `tests/test_theme_airship.gd`,
`game/theme/fx/bench/airship_shot.gd`, `game/theme/fx/bench/rig_vanish.gd`, `tools/airship_view_pool.py`, the airship
targets in `mk/fx.mk`, the `_build_airship` carve-out in `game/theme/cyberpunk/arena_dressing.gd`; `game/camera/**` is
READ-ONLY for it (one additive accessor allowed, listed in merge notes) · brains `game/ai/**`, `game/tactics/**`,
`tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
`tests/test_nav*.gd`, `mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it
declares · orders `game/control/**`, `game/ui/formation_picker.gd`, `selection_panel.gd`, `command_icons.gd`,
`tactical_map.gd`, `radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`,
`tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_tactical_map.gd`, `tests/test_element_preview.gd`,
`tests/test_touch.gd`, `mk/command.mk`. **Nobody this round** (a change there is a request through the orchestrator):
`game/garage/**`, `game/progression/**`, `game/units/**`, `game/ui/**` except orders' files, `game/match/**`,
`game/announcer/**`, the rest of `game/theme/**`, `arenas/**`, `game/arena/**`, `game/tank/**`, `game/combat/**`,
`game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`, `game/web/**`, `export_presets.cfg`,
`mk/core.mk`, `mk/web.mk`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh`.
`game/main.gd`, `project.godot`: additive only, in merge notes. Tests: each stream owns the `tests/test_*.gd` of its
area; a test another stream's change breaks is fixed by the owner of the behaviour, by request.

**Contracts (round 21):**

- **C21.1 The attack order, split at the task.** Orders decides WHAT each squad is told (one task per squad; for a
  named-target `attack` the task carries `target` and no `to`, as today; for a `move`/`attack_move` with several
  squads the row's anchors, capped by O1). Brains decides HOW an element carries a task out: for an `attack` with a
  `target` the element follows the target's live or last-known position (never a fixed point), does not "arrive"
  outside weapon range, and runs no elective drill under any player task. Neither edits the other's files; the task
  dictionary's keys (`verb`, `to`, `target`, `facing`, `formation`) do not change this round.
- **C21.2 Every change to fights is declared** (C20.2 carried): brains' P1, P2 and any stretch behaviour each one
  commit, merged alone, lines adopted and named; the arrive series is part of green for a movement change (lesson
  261) and a decision change has its own paired series (lesson 263 family: a behaviour change gets a scenario AND a
  series). Everything else, every stream, pre-registers UNMOVED on the thirteen lines and determinism. Orders' O1
  changes where squads are sent, so it is a declared change too if any line moves (the baselines are CPU-v-CPU and
  should not; say so in the pre-registration).
- **C21.3 The airship is seen, not in the way.** Round 14's instrument stands as the acceptance in both directions:
  `make airship-view` *hides the fight %* per map does not rise above main's at `0a9ce446` (same seeds, same arms), and
  `make airship-report` *in his frame %* rises on every rotation map where it is under 10 % today. The report's
  default map list is the live `Arena.ROTATION` (lesson 265). The camera's lift (round 11) is read-only: a fix on the
  camera's side is a request.
- **C21.4 The probe is the acceptance for orders' O1** (C20.3 carried, the other way round): orders adds the five-squad
  case to `make two-squads-playtest`; brains reads the before/after numbers, edits nothing there.
- **C21.5 CPU squad leaders on by default (his answer, 2026-10-06 evening).** Brains may edit `game/modes/skirmish_mode.gd`
  for exactly one thing: `ELEMENT_CPU_DEFAULT := true` (and its comment), with a test pinning that a launch with no
  flag runs the CPU's elements and `--no-element-cpu` does not. It is a DECLARED change (C21.2) if any baseline line
  moves (the baselines launch their own flags; say which in the pre-registration), merged ALONE, the file listed in
  brains' merge notes. The garage's fight goes through the same mode and so turns on with it.
- **C19.4–C19.7 stand** (one score read everywhere; the kit additive; questions through the orchestrator in his terms;
  shared files by area). **C20.1, C20.4, C20.5, C18.7, C16.3, C12.6, C18.3 stand.**

**Checkpoints:** **CP1** orders' O1 → merged alone, checked, brains told to merge (so brains' pursuit scenarios with
five squads start from where orders now sends them). Brains' declared changes: whichever is green first, each alone.
Airship: merged when green; nobody depends on it.

**His answers, minutes after the launch (2026-10-06 evening):** CPU squad leaders ON by default (C21.5, brains P0);
the airship *"same as other maps"* (airship V2's bar: the open maps' 24–31 % in frame, the fight never hidden).

**Standing rules:** rounds 12–20's (lessons 225–266).

## Round 20: two streams (launched 2026-10-06, CLOSED 2026-10-06; briefs in `streams/archive/round20/`)

**Goal: his two garage items after playing round 19 (`game_design.md` *Round 20 direction*): the vehicles are SEEN on
their cards and in their squads, and five squads of five scouts is exactly 1000 credits (prices per faction: the
scout is 40 CR, relative prices kept; the 25 cap stays unless he says otherwise). Brains runs beside it on his
standing rule: a squad forms up on the move (no shuffle before it sets off, no crew driving away from the click), and
the computer's opening lets it be ahead so its ambush can fire.**

| Stream | Brief | Round 20 | Checkpoint |
|---|---|---|---|
| **garage** | [streams/archive/round20/garage.md](streams/archive/round20/garage.md) (CLOSED 2026-10-06) | the per-faction price rule (scout = 40 CR); unit thumbnails from the real meshes on every card and chip; the phone wrap | **CP1**: R1 (the prices) merged ALONE |
| **brains** | [streams/archive/round20/brains.md](streams/archive/round20/brains.md) (CLOSED 2026-10-06) | form up on the move (M1); the opening posture (M2); the ambush hides the line (M3) | each declared change alone (C20.2) |

**Ownership:** as round 19's garage and brains (above), plus garage's `assets/units/thumbs/**` and `tools/unit_thumbs.*`.
Orders' and board's paths are **nobody's** this round (closed): `game/control/**`, `game/ui/**` except the kit and
title files, `game/match/**`, `game/announcer/**`, `game/theme/arena_kit/**`; a change there is a request through the
orchestrator. `game/modes/**`, `game/theme/**`, `arenas/**`, `mk/core.mk`, `tests/baselines/**` (except declared
lines): nobody.

**Contracts (round 20):**

- **C20.1 Prices per faction, points untouched.** `Credits.of_unit` is the only place a credit price is computed;
  `Units.cost` (points) is balance (C12.6) and the baselines' input; the garage's CPU opponent buys at the same 1000 CR
  under the same faction prices. R1 merges ALONE with the 21-price table and the archetype × seed proof that
  `Army.cpu_army` for skirmish and the baselines is untouched.
- **C20.2 Every change to fights is declared** (C19.3 carried): brains' M1, M2, M3 each one commit, merged alone, lines
  adopted and named; the arrive series is part of green for a movement change (lesson 261); everything else
  pre-registers UNMOVED on the thirteen lines and determinism.
- **C20.3 The probe is the acceptance.** Orders' `make two-squads-playtest` and `tests/test_control_two_squads.gd` are
  read-only instruments for brains; their numbers (worst off-line in 5 s; worst away-from-click) before and after are
  in every M1 report.
- **C20.4 Thumbnails are assets.** `assets/units/thumbs/**` is generated by `make unit-thumbs` on builder0 and
  committed; a test fails when a unit has no thumbnail; nothing is rendered at runtime for the chips.
- **C20.5 The garage names the opponent (granted 2026-10-06, garage's request R4).** garage may edit
  `game/modes/skirmish_mode.gd` for exactly one thing: the HUD status line reads an optional `enemy-title` launch flag
  in place of `lineups[RUST]` (a no-op without the flag), so the garage's fight says "Skirmish vs The Condemned (CPU)"
  instead of flashing the enemy file path. A test pins it; the file is listed as a shared-file edit in garage's merge notes.
- **C19.4–C19.7 stand** (one score read everywhere; the kit additive and documented; questions through the
  orchestrator in his terms; shared files by area). **C18.7, C16.3, C12.6, C18.3 stand.**

**Checkpoints:** **CP1** garage's R1 → merged alone, checked, brains told to merge (its CPU opponent reads the same
prices). Brains' declared changes: whichever is green first, each alone.

**Standing rules:** rounds 12–19's (lessons 225–263).


## Round 19: four streams (launched 2026-10-05, CLOSED 2026-10-06; briefs in `streams/archive/round19/`)

**Goal: the four things he said after two games on the twelve-map rotation (`game_design.md` *Round 19 direction*):
a formation belongs to the squad he gave it to; two squads ordered together stay two squads and arrive side by side;
the garage he imagines (1000 credits a game, every vehicle priced, squads however he likes up to five, one simple
screen in our theme, with the theme written down as a kit); and a scoreboard he can read all match, in the register
of a televised sport. Brains runs beside them on his standing rule (smart on both sides): the computer defends and
lies in wait on the open maps, the price of its squad leaders cut and measured so he can be asked.**

| Stream | Brief | Round 19 | Checkpoint |
|---|---|---|---|
| **orders** | [streams/archive/round19/orders.md](streams/archive/round19/orders.md) (CLOSED 2026-10-06) | **A formation lives on the squad** (a pick applies to the selected squad at once; selecting another shows its own; G cycles the selected squad's); **several squads, one click: one order per squad**, side by side across the approach, each transiting from its own position, never one element over `MAX_MEMBERS`; the dots per vehicle and per squad | **CP2**: O2+O3 merged → brains told to merge |
| **brains** | [streams/archive/round19/brains.md](streams/archive/round19/brains.md) (CLOSED 2026-10-06) | **The CPU holds and lies in wait** when ahead on points or its zone is threatened (B5(a) carried forward from `brains-r18-ambush`); **the element machinery's price cut** as equal-answer work and re-measured in his frame; the Cut's stop-short; the tactics-side guards for the two-squad case; a decision change's own series | CP2 consumer; C19.3 for every declared change |
| **garage** | [streams/archive/round19/garage.md](streams/archive/round19/garage.md) (CLOSED 2026-10-06) | **1000 credits a game, both sides**; every vehicle priced and buyable; faction → vehicles → squads → FIGHT on one screen in the kit; the kit documented (`_agents/ui_kit.md`, `make ui-kit-shots`); tiers and unlocks retired from the garage | **CP1**: the kit merged early → board told to merge. **CP3**: the prices (G1) merged ALONE, pre-registered |
| **board** | [streams/archive/round19/board.md](streams/archive/round19/board.md) (CLOSED 2026-10-06) | **A score bug** (each side's progress to the win as a meter with the zones named as the map names them, kills, credits destroyed), redrawn on change; **the celebration** on a kill in the broadcast register (the caller's line wired to it); one score snapshot and signal from `Match`; the arena screens and the results screen read it | CP1 consumer; its signal is read by brains (C19.4) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
orders `game/control/**`, `game/ui/formation_picker.gd`, `selection_panel.gd`, `command_icons.gd`, `tactical_map.gd`,
`radar.gd`, `task_preview.gd`, `control_hints.gd`, `game/theme/fx/order_feedback.gd`, `tests/test_control*.gd`,
`tests/test_command*.gd`, `tests/test_tactical_map.gd`, `tests/test_element_preview.gd`, `tests/test_touch.gd`,
`mk/command.mk` · brains `game/ai/**`, `game/tactics/**` (minus the lent guard line), `tests/ai_scenarios/**`,
`tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `mk/ai.mk`,
`mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines it declares · garage `game/garage/**`,
`game/progression/**`, `game/units/units.gd` prices only, `game/ui/widgets/cyber_*.gd`, `conductors.gd`,
`game/ui/widgets/title/**`, `game/theme/game_theme.gd` `ui` palettes, `doctrines/player_*.json`,
`tests/test_army*.gd`, `tests/test_units_catalog.gd`, `tests/garage/**`, `mk/garage.mk`, `_agents/ui_kit.md`,
`_agents/balance.md` *Economy* · board `game/match/**` (additive), `game/ui/hud.gd`, `hud.tscn`, `hud_messages.gd`,
`game/ui/widgets/hud_skin.gd`, `game/ui/scoreboard*.gd`, `game/announcer/**`, `assets/announcer/**`,
`game/theme/arena_kit/**`, `tests/test_control_point.gd`, `tests/test_hud*.gd`, `tests/test_match*.gd`,
`tests/test_assets_ad_screens.gd`, `tests/announcer/**`, `mk/announcer.mk`. **Nobody:** `arenas/**`, `game/arena/**`,
`game/tank/**`, `game/combat/**`, `game/modes/**`, `game/camera/**`, `game/network/**`, `game/audio/**`,
`game/theme/fx/**` (minus order_feedback), the rest of `game/theme/**`, `game/web/**`, `export_presets.cfg`,
`mk/core.mk`, `mk/web.mk`, `tests/baselines/**` (except declared lines), `tools/remote.sh`, `tools/slot.sh` — a change
there is requested through the orchestrator. `game/main.gd`, `project.godot`: additive only, in merge notes. Tests:
each stream owns the `tests/test_*.gd` of its area; a test another stream's change breaks is fixed by the owner of
the behaviour, by request.

**Contracts (round 19):**

- **C19.1 Several squads are never one element.** Orders issues one order per squad for any selection that holds
  several (both selection shapes); `Elements.form` refuses more than `Formations.MAX_MEMBERS` members, loudly. That
  one guard line in `game/tactics/elements.gd` is LENT to orders; brains re-reads it at CP2 and adds the
  tactics-side tests (B5). Partial squads (`partial_probe.gd --case=mixed`) keep their behaviour.
- **C19.2 Prices move once, on purpose: garage's CP3.** `Units.cost` is balance (C12.6, his); a proportional
  re-expression to the 1000-credit scale is allowed when it buys IDENTICAL CPU armies for every archetype, faction
  and seed the baselines and series use (the table is in garage's Status before the commit); otherwise credits are a
  presentation of the internal points, or the move is declared and merged alone with its lines adopted. G1 merges
  ALONE either way with its pre-registration.
- **C19.3 Every change to fights is declared** (C18.1 carried): brains' B2, B4 and any B3 cut that is not
  equal-answer are each one commit, merged alone, lines adopted with `make sim-baseline-adopt` and named in the
  commit. Every other commit of every stream pre-registers UNMOVED on the thirteen lines (foundry + the twelve) and
  determinism; an unplanned move is a finding: stop, attribute, message the orchestrator. CPU elements stay OFF on
  his path until he answers (brains' B3 prepares the number).
- **C19.4 One score, read everywhere.** `Match` gains `score_snapshot()` and `score_changed(snapshot)` (board, S1,
  additive; the rules of winning untouched: `CONTROL_*`, `_check_finished`, `result()` are his). The HUD bug, the
  radar, the arena screens, the results screen and brains' posture read the snapshot; nobody keeps a second tally.
  Until S1 lands brains polls `control_score` and the objectives' owners. A kill's value on the board is
  `Units.cost` as the garage prices it after CP3.
- **C19.5 The kit is additive and documented.** `CyberFrame`, `CyberUiTheme`, `CyberStyle`, `CyberBanner`,
  `Conductors` are garage's this round; every change is additive (new elements, new parameters with today's
  defaults) and the HUD's and title's output are unchanged frame for frame (`make hud-digest`; a title frame
  diffed) on every garage commit. `_agents/ui_kit.md` + `make ui-kit-shots` are CP1; board builds on them after
  CP1 and on HudSkin's use of `CyberFrame` before it. A kit element board needs is a request to garage.
- **C19.6 Questions to him go through the orchestrator**, in his terms, one recommendation each (lesson 254);
  briefs' *Waiting on the lead* lists them; the worker builds the recommended option meanwhile.
- **C19.7 Shared files and carve-outs.** `game/ui/**` is split by file as above; a new file in `game/ui/` belongs to
  the stream that creates it and is named in its merge notes. `game/match/**` is board's but ADDITIVE only. `mk/*.mk`
  by area as above; a new target in another stream's makefile is a request with its seconds. The kit files are
  garage's; HudSkin is board's. `game/theme/fx/order_feedback.gd` is orders'. `tests/baselines/**` is nobody's
  except declared lines (C19.2, C19.3).
- **C18.7 stands** (the native game never bends for the browser; `web-smoke` stays in `check` unchanged), **C16.3
  stands** (every number: commit, machine, load, workload, sample), **C12.6 stands** (balance values are his),
  **C18.3 stands** (his eye is the check; a page only for a real choice, rendered and counted first).

**Checkpoints:** **CP1** garage's kit (G2) → merged, `make remote T=check` on `main`, board told to merge.
**CP2** orders' O2+O3 → merged, checked, brains told to merge. **CP3** garage's G1 (the prices) → merged ALONE,
checked, lines adopted if declared, every stream told to merge. Order between them: whichever is green first.

**Laptop runs this round.** He plays on the laptop. Windowed laptop runs open on his desktop: under two minutes
each, logged in Status with `uptime`'s load, announced to the orchestrator first. Quiet-window series (brains' B3
before/after; garage's G5 and board's S5 are plays, not series) are scheduled by the orchestrator (lesson 260).

**Standing rules:** rounds 12–18's (the slot; builder0 one invocation at a time across all of a stream's folders and
one slot hold ≤ ~30 min; `make remote` one per worktree, always backgrounded; no `pkill -f`; scratch scripts named
with the stream and stopped only by a PID file, lesson 244; every time written down comes from `date`, lesson 243;
scratch deleted when its number is written, `df -h /` before anything over ~200 MB and never start under 3 GB free,
lesson 249; a check is read as its verdict line AND its engine-error count AND the wrapper's exit, lessons 251, 255,
257; an intermittent red recorded as `seen k of N`, lesson 258; lessons 225–260).


## Round 18: five streams (launched 2026-10-04, CLOSED 2026-10-05; briefs in `streams/archive/round18/`)

**Goal: the two things he asked for after playing round 17 — a formation picker he can see, and maps with room to
manoeuvre and an open centre a line abreast can be ambushed in — plus his pick from the candidates: every unit stops
peeking at a loaded gun (*"Yes make the CPU smarter, this would apply to all units"*), and no browser work (*"I don't
want to sacrifice anything on our game to accomodate browser play"*).** The freeze at the final kill is in on the
orchestrator's recommendation; a baseline that sees every dealt map and the CPU's doctrine in open ground are in
because his map item cannot be checked or played without them. His words: `game_design.md` *Round 18 direction*.

| Stream | Brief | Round 18 | Checkpoint |
|---|---|---|---|
| **picker** | [streams/archive/round18/picker.md](streams/archive/round18/picker.md) (CLOSED 2026-10-05) | **The Formation button becomes a picker:** opens on hover (tap on touch), every formation as its shape from one shared list (AUTO first, echelons and coil included), the current one marked, one click picks, the animated preview on each card built from the real geometry; G still cycles; nothing per frame while closed | — (baseline UNMOVED) |
| **maps** | [streams/archive/round18/maps.md](streams/archive/round18/maps.md) (CLOSED 2026-10-05) | **New maps by experiment:** a CANDIDATE class he can play by name the day a map exists; the qualities he named as numbers per map (room for a line of four, chokepoints with a way round, flank-ambush ground); candidate 1 = the open centre; three or four more, different in kind; each played by the CPU before him; a page with KEEP / CUT; the lane validator's turning-pocket hole | **CP2** candidate 1 playable, merged early (brains measures on it; he plays it from `main`) |
| **brains** | [streams/archive/round18/brains.md](streams/archive/round18/brains.md) (CLOSED 2026-10-05; branch `stream/brains` KEPT for the unmerged ambush work) | **No unit shows itself to a loaded gun** (rule A: peek only while the enemy reloads; rule B if A loses a ladder), in the champion, for both sides, with the scenario rewritten and a two-target stage; then **the CPU in open ground, measured for the first time**: drills and seating read for wall assumptions, a line of four at its own spacing, the CPU on maps' candidate 1, and the fixes he would notice | **CP1** the peeking fix + its declared hashes, ONE commit, merged alone |
| **ship** | [streams/archive/round18/ship.md](streams/archive/round18/ship.md) (CLOSED 2026-10-05) | **A baseline line per dealt map** (rotation + foundry, read from the game; a rotation map with no line fails), the adopter for many lines with every branch stub-driven; candidates stay out, visibly; the test shards exit clean and their allow-list lines go; `round-status` prints the disk. No browser work | **CP0** the per-map lines on the launch tree (before CP1 if first; re-recorded by the orchestrator otherwise) |
| **finale** | [streams/archive/round18/finale.md](streams/archive/round18/finale.md) (CLOSED 2026-10-05) | **The freeze at the final kill** (1.7 s and 3.4 s frames on a loaded laptop): a per-frame trace through the end of a match on his path, the cause by removal, the fix at the cause (a warm-up at load, a preload, work spread over frames), a measure that keeps it out; the same class at first use during a match | — (baseline UNMOVED; windowed laptop runs open on his desktop) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
picker `game/ui/**`, `game/control/**`, `tests/test_control*.gd`, `tests/test_command*.gd`, `tests/test_hud*.gd`,
`tests/test_tactical_map.gd`, `tests/test_element_preview.gd`, `tests/test_touch.gd` · maps `tools/make_arenas.py`,
`tools/arena_generator.py`, `tools/terrain_maps.py`, `arenas/**`, `game/arena/**`, `tests/arena/**`,
`tests/test_arena*.gd`, `mk/arena.mk`, `_agents/arenas.md` · brains `game/ai/**`, `game/tactics/**`,
`tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
`tests/test_nav*.gd`, `mk/ai.mk` minus the perf targets, `mk/nav.mk`, `mk/tactics.mk`, and the `sim_state_hash.txt`
line at CP1 · ship `mk/core.mk`, `tests/baselines/**`, `tools/slot.sh`, `tools/remote.sh`, `tools/round_status.sh`,
`tools/engine_log_gate.py`, `tests/run_tests.gd`, `tests/support/**`, the perf targets of `mk/ai.mk` · finale
`game/theme/fx/**`, `tests/test_fx*.gd`, `tests/test_render*.gd`, `mk/fx.mk`. **Nobody:** the rest of `game/theme/**`,
`game/match/**`, `game/tank/**`, `game/combat/**`, `game/units/**`, `game/modes/**`, `game/camera/**`,
`game/garage/**`, `game/network/**`, `game/progression/**`, `game/announcer/**`, `game/audio/**`, `game/web/**`,
`export_presets.cfg`, `mk/web.mk` — a change there is requested through the orchestrator. Tests: each stream owns the
`tests/test_*.gd` files of its area; a test another stream's change breaks is fixed by the stream that owns the
behaviour, by request.

**Contracts (round 18):**

- **C18.1 The hashes move once, on purpose: brains' CP1.** The launch baseline is `05df1d55ba49cde1` (glibc 2.43,
  builder0), determinism `762a0576f944f5b7`, on `foundry`. Brains' peeking fix is the round's one planned change of
  fights: one commit, merged alone, its moved lines adopted with `make sim-baseline-adopt` and declared (it may leave
  foundry's line unmoved; brains says which before the run). Ship's per-map lines (CP0) are recorded on the launch
  tree; **whichever of CP0 and CP1 merges second, the orchestrator re-records every line on the merged tree, twice.**
  Brains' later open-ground changes (B5) are declared one at a time the same way. Every other commit of every stream
  pre-registers UNMOVED (picker and finale change what is drawn; maps adds candidates nobody is dealt; ship changes
  the instrument). An unplanned move is a finding: stop, attribute it, message the orchestrator; it merges alone.
- **C18.2 A candidate map is never dealt.** `Arena.ROTATION` and `Arena.DEFAULT_LAYOUT` change only on his word. A
  candidate is playable by name (`make skirmish ARENA=<name>`), never by `random`, carries no baseline line, and has
  no announcer name until dealt. The day one is dealt, ship's rule makes its missing line a failure.
- **C18.3 His play and his eye are the checks.** The picker is judged in the game; the maps on a page that records
  KEEP / CUT / notes per candidate in a `db` (**C15.2 stands**: the page says when its `db` was last read; the
  orchestrator reads it at close). A page is rendered headless and its buttons counted by the worker before the first
  publish and by the orchestrator before the link goes to him (lesson 252). A question to him is written as what he
  would notice when playing, with one recommendation (lesson 254).
- **C18.4 Smart on both sides ships on our evidence** (his words, `game_design.md` *His pick*): a decision change that
  applies to every unit on both sides needs a scenario, a ladder or paired series, and a declared hash move, not his
  tap. Still his: anything that makes the sides unequal, what a difficulty setting means, balance values (**C12.6
  stands**), and round 17's levers that trade behaviour for cost (C17.4 stands for those; all OFF).
- **C18.5 One tree per comparison** (C17.2 carried). Streams `git merge main` when the orchestrator says: after CP0,
  after CP1, after CP2. No A/B, ladder, series or frame-time comparison has arms on both sides of a merge.
- **C18.6 Shared files and carve-outs.** `game/ui/**` is picker's; finale's fix to the DEFEAT / VICTORY banner, if the
  stall is there, is a minimal patch landed by the orchestrator and listed in finale's merge notes. `mk/core.mk` is
  ship's: anyone else's target or measure line is added by request with its seconds (finale's end-frame measure; a
  candidate-loads smoke for `check-all`). `mk/arena.mk`'s `container-hashes` is maps'; ship calls or copies it and
  says which. `tests/baselines/**` is ship's; the `sim_state_hash.txt` line is brains' at CP1 only. The tactical map
  or radar drawing a candidate wrong is picker's, by request. `game/main.gd` and `project.godot`: additive only, in
  merge notes. A request to another stream goes in Status AND as a message to the orchestrator.
  **Added 2026-10-04 14:57 PDT (ship's request):** `mk/match.mk`'s `determinism` recipe, and only that recipe, is lent to ship to add
  a second pair of runs on `crossing` beside foundry's: foundry's pair unchanged (the hash stays `762a0576f944f5b7`),
  crossing's pair with its own files and a failure that names the map, both statuses captured, every branch
  stub-driven, the added seconds measured on builder0. **And the candidate list's name is fixed:** `Arena.CANDIDATES`,
  a flat Array of layout names in `game/arena/arena.gd` (maps writes it; ship's per-map baseline and its `check-all`
  `candidates-smoke` read it); either stream changes it only with the other told first.
  **Added 2026-10-04 18:41 PDT (ship's exit-code audit):** the status-capture lines of every check / check-all recipe that reads a
  Godot run's markers and drops its exit code are lent to ship, wherever the recipe lives: `mk/garage.mk`
  (army-loop-smoke, garage-smoke), `mk/tactics.mk:8-9` (tactics-drills; brains' file, this one recipe),
  `mk/metrics.mk` (ai-scenarios-check), `mk/audio.mk` (music-smoke's garage part), `mk/match.mk`
  (windowed-elimination-pair), `mk/net.mk` (the background servers of net-, combat- and relay-smoke are reaped and
  their exit read; a trap's own SIGTERM is the one named expected code), `mk/web.mk` desktop-smoke only (a native
  export; the web-net / web-relay smokes stay as they are under C18.7 and are listed, not fixed). Picker fixes its own
  three in `mk/command.mk` (picker-playtest, picker-shots, shell-playtest). The pattern: `s=0; godot … > log 2>&1 ||
  s=$?; grep … log; [ $s -eq 0 ] || { echo "<target>: exited $s"; exit 1; }`; `|| true` stays only where a comment
  names the non-zero code that is expected. Each fix is proved red once by a stub that exits non-zero after printing
  its markers. **A crash this makes visible is a finding for the path's owner, sent through the orchestrator; ship
  does not fix the game to get its own change green.**
  **Added and CLOSED 2026-10-04 23:38 PDT (picker, at the end of its brief):** the "+188 orphan nodes" a full unit setup leaves were
  assigned to picker with a carve-out in `game/theme`; picker proved they are not a leak (188 of 213 are already
  `queue_free()`d `StaticBatcher.merge` sources; +0 after two process frames; the runner samples after a physics
  frame, before the delete queue runs). No change in `game/theme`; the carve-out is withdrawn; the sampler is ship's.
  **Added 2026-10-05 02:46 PDT:** `game/audio/music_director.gd` and the music's playing path (`game/audio/**`; the soundtrack
  code under `game/theme/audio/**` if the holder is there) are lent to finale for a MINIMAL fix to the exported
  build's intermittent exit leak (attributed to music playing: 0 of 14 runs with music off against 18 of 46 on). No
  change to what he hears, the mix or the bus layout.
  **Added 2026-10-05 02:58 PDT:** the game's quit paths are lent to finale for ONE awaited call each
  (`MusicDirector.quiet_for_quit`): `game/match/match.gd`'s `--hash-until` quit, and a window close / menu Quit
  wherever they live (`game/main.gd`, `game/ui/**`, `game/modes/**`). The leak is the music's Ogg playback held by the
  audio server at exit (`stop()` only marks it; the mix that deletes it does not run again under the headless Dummy
  driver). Conditions: the simulation does not notice (no extra tick, the same hashes), bounded, no change to what
  he hears.
  **Picker's next item, by the orchestrator's word:** roadmap candidate 2 (the HUD's per-unit work) as far as it
  goes without native code, in its own paths: today's table at his army size, equal-output savings shipped (the HUD's
  output identical frame for frame, proved by a digest), anything that changes what he sees priced and listed.
- **C18.7 The native game never bends for the browser** (his words). No browser work this round; `web-smoke` stays in
  `check` unchanged. If a native change turns a web target red, the stream reports the line and keeps the feature.
- **C16.3 stands** (every number: commit, machine, load, workload, sample; a cost or effect attributed only by removal
  inside one run, with an arm assertion; the orchestrator's quiet-window laptop runs are the record).

**Checkpoints:** **CP0** ship's per-map baseline → merged, `make remote T=check` on `main`, every stream told to merge.
**CP1** brains' peeking fix → merged alone, checked, lines re-recorded if CP0 is already in, every stream told to
merge. **CP2** maps' candidate 1 → merged early; brains is told to merge and measures on it; the lead is told the
command to play it. Order between them is whichever is green first.

**Laptop runs this round.** He plays on the laptop and it is finale's subject machine. Windowed laptop runs open on
his desktop: under two minutes each, logged in Status with `uptime`'s load. The quiet-window record runs are the
orchestrator's: finale's end-frame trace, maps' `perf-play ARENA=<candidate>`, brains' open-ground lever arm. Ask
with the exact command.

**Standing rules:** rounds 12–17's (the slot; builder0 one invocation at a time across all of a stream's folders and
one slot hold ≤ ~30 min; `make remote` one per worktree; no `pkill -f`; scratch scripts named with the stream and
stopped only by a PID file, lesson 244; every time written down comes from `date`, lesson 243; scratch deleted when
its number is written, `df -h /` before anything over ~200 MB and never start under 3 GB free, lesson 249; a check is
read as its verdict line AND its engine-error count, lesson 251; lessons 225–254).

## Round 17: five streams (launched 2026-10-03, CLOSED 2026-10-04; briefs in `streams/archive/round17/`)

**Goal: two things he said after playing round 16 — the containers look synthetic, the guns have no power — and the
three items round 16 left for him to order, which he took whole (*"I want all 5, go"*).** While the round was being
briefed he widened the sound item (where a round lands, a full audit of silent events) and authorised the spend
(*"we have Elevenlabs credits to burn so we should use them"*).

| Stream | Brief | Round 17 | Checkpoint |
|---|---|---|---|
| **yard** | [streams/archive/round17/yard.md](streams/archive/round17/yard.md) | **Containers placed by people:** 93 % of 668 sit at exactly 0° or 90° and a stack moves ±0.6° / ±4 cm, which nobody can see. Upper levels visibly offset (visual); the ground level turned for real by a few seeded degrees, authored in the half so the mirror stays fair; walls stay walls (no ray through a joint); lanes, nav, cover, fairness re-proved; before/after frames at his pose on a page | **CP1** the layouts + the new sim baseline, ONE commit, merged alone |
| **guns** | [streams/archive/round17/guns.md](streams/archive/round17/guns.md) | **Sound he can feel on a living-room system:** source, mix and format separated on one sheet first; the mix lets a gun be the loudest thing; tanks → Abrams, 25 mm → Bradley / Apache chain gun, scouts → heavy machine guns, explosions, in layers (crack, body, sub, mechanism, stereo tail); **impacts by surface** (ground, building, steel, water, armour, shield, kill); **the audit of silent events**; an audition page for his ear | — (baseline UNMOVED; spend authorised, on the ledger) |
| **brains** | [streams/archive/round17/brains.md](streams/archive/round17/brains.md) | **The tick's last big line, as prices:** the far-and-idle think rate, three execution levers (k-turn check, chord samples, ORCA neighbours), their bundles — each OFF behind a switch, cost by removal and behaviour on one table, in his frame; a decision page; equal-answer leftovers ship | — (default path UNMOVED on every commit) |
| **sim** | [streams/archive/round17/sim.md](streams/archive/round17/sim.md) | **The same windowed fight twice:** the Sumps fork at ticks 601–630 — a rate first, the unit and the field, a bisect by removal, the fix at the cause, a regression that keeps it out | — (headless baseline UNMOVED, pre-registered; a move is a finding) |
| **ship** | [streams/archive/round17/ship.md](streams/archive/round17/ship.md) | **What the browser player gets, and a check with no holes:** the web build observed (the preset excludes the booth's clips and three factions' art); the voice options priced and the recommended one built behind a switch, on a page; smokes that assert what the player gets; `scenario_perf` judged every time; the garage tour and a desktop boot in `check-all` | — (announce before the first `mk/core.mk` change merges) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
yard `tools/make_arenas.py`, `tools/terrain_maps.py`, `arenas/**`, `game/arena/**`, `game/theme/arena_kit/containers/**`,
`tests/arena/**`, `tests/test_arena*.gd`, `mk/arena.mk`, `tests/baselines/**` (CP1 only) · guns `game/theme/audio/**`,
`game/audio/**`, `assets/audio/**`, `tools/audio/**`, `tests/audio/**`, `mk/audio.mk`, `project.godot [audio]`, the
sound-selection lines of `game/theme/fx/weapon_fx.gd` · brains `game/ai/**`, `game/tactics/**`, `tests/ai_scenarios/**`,
`tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `mk/ai.mk` minus the perf targets, `mk/nav.mk`, `mk/tactics.mk` ·
sim `game/match/**`, `game/tank/**`, `game/combat/**`, `game/units/**`, `game/modes/**`, `tests/combat/**`,
`tests/scale/**`, `mk/match.mk`, `mk/scale.mk`, `project.godot [physics]`, plus a minimal-fix carve-out wherever the
fork's cause lives in an unowned path · ship `export_presets.cfg`, `mk/web.mk`, `mk/core.mk`'s check composition (lent
by the orchestrator), the `ai-perf*` / `scenario_perf` targets of `mk/ai.mk` and `perf_nominal.json` (lent by brains),
`tools/slot.sh`, `tools/remote.sh`, the announcer's clip-loading path, and (lent 2026-10-03, one additive MEASURE line,
not judged) `tests/ai_scenarios/scenario_perf.gd`. Also lent to ship (2026-10-03, evening): the status-capture lines
`mk/net.mk:167`, `:241`, `:265` and `mk/tactics.mk:64` (`cmd || status=$$?` so a failing recipe prints its reason). **Nobody:** the rest of `game/theme/**`,
`game/ui/**`, `game/control/**`, `game/camera/**`, `game/garage/**`, `game/network/**`, `game/progression/**`,
`game/announcer/**` — a change there is requested through the orchestrator. Tests: each stream owns the
`tests/test_*.gd` files of its area; a test another stream's change breaks is fixed by the stream that owns the
behaviour, by request.

**Contracts (round 17):**

- **C17.1 One planned change of fights: yard's CP1.** The launch baseline is `05df1d55ba49cde1` (glibc 2.43).
  **CORRECTED 2026-10-03 (yard's finding, verified): the baseline and `make determinism` run on `foundry`
  (`Arena.DEFAULT_LAYOUT`), which holds zero containers — so CP1 is pre-registered UNMOVED on the baseline while it
  changes every fight on the dealt container maps.** The baseline therefore proves nothing about those maps: CP1 carries
  its own table (one seeded headless hash per layout before and after: dealt maps CHANGE, foundry / furnace / scrapyard
  and the fixtures maze / barriers IDENTICAL), and every other stream's equality claim names a hash or `ai-parity` on a
  map he plays, not the baseline alone. (As launched this line read: yard moves the baseline once, in the commit that
  turns the layouts, recorded twice and declared.) Every other commit of every stream
  pre-registers UNMOVED on the default path (brains' levers are OFF by default; guns reads the fight and never writes
  it; ship changes the instrument, not the game; sim's fix is expected to leave the headless path alone). An unplanned
  move is a finding: stop, attribute it (the unit, the state, the second), message the orchestrator; it merges alone.
- **C17.2 One tree per comparison.** Until CP1 is merged and announced, every series runs on the launch tree; after
  it, streams `git merge main` **when the orchestrator says**, and no A/B, ladder, price or fork rate compares arms
  across that merge. Sim does not take CP1 until its fork is localised on the launch tree's Sumps (the turned
  containers are a different fight). Brains re-states its table's tree in every row.
- **C17.3 His eye and his ear are the checks.** Yard's frames page and guns' audition page are the verification of
  those streams; a worker looks at / measures everything first and says plainly what it cannot judge. Pages carry a
  `db` for his taps; **C15.2 stands** (each page records when its `db` was last read; the orchestrator reads every page
  at close). Four pages this round: yard Y5, guns G4, brains T5, ship W2.
- **C17.4 A lever is priced, never shipped on our call** (C16.1 carried): anything that changes a decision, the look
  or the web pack's size is built OFF / behind a switch and put on a page with its price. Equalities (the baseline and
  `ai-parity` identical) ship.
- **C17.5 Paid generation.** ElevenLabs **sound effects are authorised for this round by his words** (guns only, on
  `assets/audio/elevenlabs/ledger.md`, credits before → after on every run). Everything else under lead gate 1 is
  unchanged: no announcer generation, no Meshy, no new voices, no hosting bought.
- **C17.6 Shared files.** `game/theme/fx/weapon_fx.gd`: guns' carve-out is the sound keys and `_sound` call sites only.
  `game/theme/fx/shield_effect.gd`: lent to guns 2026-10-03 for one additive call (`shield_up` when a shield returns
  from zero, in `set_shield`), with a test that it fires once per return and never on a mere recharge tick.
  `mk/ai.mk`: brains owns it minus the perf targets (ship's). `mk/core.mk`: ship's check composition; anyone else's
  target is added by request (sim's `windowed-repeat` pair for `check-all`). `project.godot`: `[audio]` guns (and the new root file `default_bus_layout.tres`, guns', 2026-10-03),
  `[physics]` sim. `export_presets.cfg`: ship; guns reports its pack MB. `game/main.gd`: additive only, in merge notes.
  A request to another stream goes in Status AND as a message to the orchestrator.
- **C16.3 stands** (every number: commit, machine, load, workload, sample; a cost attributed only by removal inside
  one run; the orchestrator's quiet-window laptop runs are the record). **C12.6 stands** (nobody tunes balance).

**Checkpoints:** CP1 yard's Y3 (layouts + baseline, one commit) → merged alone, `make remote T=check` on `main`, then
each stream is told when to merge `main` (sim last, by its own word).

**The builder0 queue rule (added 2026-10-03, +2 h):** one builder0 invocation at a time across ALL of a stream's
folders (a `-before` / `-base` / `-price` folder counts), and one slot hold ≤ ~30 min — split chains and series into
separate `make remote` calls. Measured cause: load 0.78 on 12 threads with all 3 slots held by long light jobs (a
20-run windowed series, a four-target frames chain) and five jobs waiting 18–30 min; the slot kills any command at
5400 s. The mechanism (a light lane, a per-run series runner) is ship's to price (W4).

**Scratch scripts (added 2026-10-03 after an incident):** named with the stream (`yard-chain3.sh`), stopped only by a
PID the script wrote to a file at start, never by a name pattern (lesson 244). Every time written down comes from
`date` (lesson 243).

**The laptop's disk (added 2026-10-03 after it filled):** scratch copies of the project, exports, raw recordings and
frame sets are deleted as soon as the number or page asset they exist for is written down; `build/light/build` is
emptied after each light job; before anything that writes more than ~200 MB, `df -h /`, and do not start under 3 GB
free (lesson 249).

**Standing rules:** rounds 12–16's (the slot, builder0, `make remote` one per worktree, no `pkill -f`, detach long runs,
lessons 225–242); a windowed run on the laptop opens on his desktop — say so in Status and keep it short; the laptop
was rebooted 2026-10-03 (the wedged-directory hazard of lesson 240 is cleared, the lesson stands).

## Round 16: six streams (launched 2026-10-02 evening, CLOSED 2026-10-03; briefs in `streams/archive/round16/`)

**Goal: the frame he feels, on his laptop, along his path, without cutting a pixel or a decision.** His words are in
[`game_design.md`](game_design.md) *Round 16 direction*. Measured at launch (`1efa9940`, his laptop, his window 1854×1011,
his flags; `streams/references/perf/r16-before-1080-his-flags.json`): at 30 vehicles a frame is **36.9 ms** — the
simulation tick **24.0 ms** (brains ~85 % of it, round 5's split), the GPU **19.8 ms** flat at every count, game+UI
`_process` 2.6 ms, FX 1.0, draw submission 1.6; at 52 vehicles 3.5 ticks a frame (the frame read 100 ms but was LONGER: see the caveat in `references/perf/README.md` — a saturated perf-scene phase reports game time); a locked 30 holds at
**10** vehicles. His matches start at ~51. Round 5's budget (`fx_tricks.md` *The budget*) stands: tick ≤ 5 ms at 60,
GPU ≤ 10 ms at 1080p, game+UI ≤ 1.5, FX ≤ 1.0, frame ≤ 33 at a locked 30 with headroom.

| Stream | Brief | Round 16 | Checkpoint |
|---|---|---|---|
| **brains** | [streams/archive/round16/brains.md](streams/archive/round16/brains.md) | **The tick's biggest line without changing one decision:** the brains' split re-measured today, a per-section brain profile, LOS memoised once per pair per tick, squared distances, allocation per think, nav queries per tick, the non-think tick; `ai_usec_per_tick` 10 022 → toward 4 000 (builder0) | — (baseline UNMOVED on every commit) |
| **sim** | [streams/archive/round16/sim.md](streams/archive/round16/sim.md) | **The rest of the tick, and the thing no headless instrument sees:** `VisibilityField` (~346 rays + ~12 100 cells a tick, skirmish-only) priced and made incremental; `_update_intel`'s allocation inside the loop and uncached LOS; the HUD's per-frame accessors cached on the tick; `Units.stat` without a String per call; shells, the recorder's census tick, Jolt's bodies; then **Law's APC on tracks** (his words) | **CP1b** `Units.stat` cached (early, alone); **CP2** Law's APC = a sim change, pre-registered, merged alone |
| **render** | [streams/archive/round16/render.md](streams/archive/round16/render.md) | **The GPU's 20 ms at his window, the picture unchanged:** `make look-parity` first (pixel diff at his pose); the ~8 ms base split by layer; work that renders nothing he sees (viewport feeds, FX with nothing alive, unchanged shader writes); fragment cost on the big surfaces; draws; glow and pool lights; a priced-levers page ONLY if the budget is still missed | — (baseline cannot move; parity on every item) |
| **hud** | [streams/archive/round16/hud.md](streams/archive/round16/hud.md) | **The main thread's per-frame scripts:** one fog-of-war walk shared by controls and map; redraw on change not on time (37 `queue_redraw` sites, 10 unconditional); per-tank per-frame work without allocation; one unproject table a frame; the camera's group lookups and the cutaway's loops gated; `process_game_ui_ms` 2.6–3.3 → ≤ 1.5 | — |
| **play** | [streams/archive/round16/play.md](streams/archive/round16/play.md) | **His path, measured as he plays it** (`make perf-play`: human-side skirmish, his flags, his window, capped and uncapped, layers `no_visfield/no_controls/no_audio/no_recorder`); a frame-time trace beside every recording; **the opponent randomised; the title music through the loader** (his words); audio ≤ 0.3 ms a frame; the slow-motion trap explained | **CP1** `make perf-play` (first hours; everyone measures with it) |
| **booth** | [streams/archive/round16/booth.md](streams/archive/round16/booth.md) | **The announcers repeat:** the effective pool at each pick over HIS matches, ranked; memory across launches (the free half); new lines for the thin pools in the voice, through his veto page; generation after his taps on the ledger; the director falls through rather than repeats | — (a review page: lead gate 1) |

**Ownership (every path exactly one owner; the full lists are in each brief's header and *Don't touch*):**
brains `game/ai/**`, `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `mk/ai.mk`,
`mk/nav.mk` · sim `game/match/**` (incl. `visibility_field.gd`, `sim_profile.gd`), `game/tank/**`, `game/combat/**`,
`game/arena/**`, `game/units/**`, `tests/combat/**`, `tests/arena/**`, `tests/scale/**`, `mk/match.mk`, `mk/arena.mk`,
`project.godot [physics]` · render `game/theme/**` minus `audio/**` and `fx/bench/**`, `project.godot [rendering]`,
`mk/show.mk`, `tools/look_parity.py` · hud `game/ui/**` minus `faction_picker.gd`, `loading_screen.gd`, `widgets/title/**`;
`game/control/**`, `game/camera/**`, `mk/command.mk` · play `game/modes/**`, `game/theme/fx/bench/**`, `mk/fx.mk`'s perf
targets, `mk/play.mk`, `game/audio/**`, `game/theme/audio/**`, the three `game/ui` carve-outs, `tools/perf_*.py`,
`game/main.gd` additive (the director's lifetime) · booth `game/announcer/**`, `assets/announcer/**`, `tests/announcer/**`,
`mk/announcer.mk`. Nobody: `game/garage/**`, `game/network/**`, `game/progression/**`, `mk/core.mk` (orchestrator).
Tests: each stream owns the `tests/test_*.gd` files of its area; a test another stream's change breaks is fixed by the
stream that owns the behaviour, by request.

**Contracts (round 16):**

- **C16.1 Nothing is cut.** His words: *"before sacrificing any of the existing graphics or gameplay"*. No behaviour, no
  think, no unit, no pixel at his pose goes to buy a frame. A lever that changes the look or a decision is PRICED and
  put on a decision page (OFF by default), never shipped on a worker's call.
- **C16.2 The sim baseline is UNMOVED by every performance commit** (`05df1d55ba49cde1`, glibc 2.43, read from the
  wrapper's line), and `make determinism` holds. Pre-register UNMOVED per item; a move means the optimisation changed a
  decision: find why and fix it, or — if it is a genuine behaviour fix — its own commit, declared, merged alone as a CP
  with the attribution (lesson 230's rule: name the unit, the state, the second). The ONE planned move is sim's S9
  (Law's APC on tracks, CP2), last in its backlog.
- **C16.3 Every number carries its commit, machine, workload and sample.** A cost is attributed only by removal within
  one run (perf-scene's layer alternation, a `--*-off=` switch) or a counter — never a ratio read off a combined run.
  builder0 for CPU ratios and counts (2.75× faster than his laptop); the laptop for GPU ms and for the before/after he
  will feel; **the orchestrator's quiet-window laptop runs are the record** (the two `r16-before-*` files at launch; the
  afters at close). A worker's own laptop run states the load.
- **C16.4 Shared files.** `game/units/units.gd` is sim's (CP1b: `Units.stat` cached — hud and brains adapt in their
  paths until it merges); `project.godot`: `[physics]` sim's, `[rendering]` render's, every edit in merge notes;
  `game/main.gd` additive only (play's director lifetime); `mk/core.mk` the orchestrator's; `export_presets.cfg` by
  merge note. A request to another stream goes in Status AND as a message to the orchestrator.
- **C16.5 The perf harness is play's** (`game/theme/fx/bench/**`, `mk/fx.mk`'s perf targets): `make perf-play` is CP1;
  other streams add layers through their own switch tables (`--sim-off=visfield`, FxWorld's switches) and ask play to
  expose them; nobody else edits `perf_scene.gd`.
- **C16.6 The picture is proven unchanged**: render's `make look-parity` (R1, early) diffs shot sets at his pose with
  a stated tolerance; every render and hud item ships with its parity line; until R1 merges, before/after shots diffed
  by hand. A diff outside the tolerance is a C16.1 question, not a judgment call.
- **C12.7, C15.2 stand** (paid generation on the ledger after his taps; every decision page records when its `db` was
  last read; the orchestrator reads every page at close).

**Checkpoints:** CP1 play's `make perf-play` → merged early, every stream `git merge main`; CP1b sim's `Units.stat`
cached → early, alone; CP2 sim's S9 → last, alone, the baseline recorded twice if it moves.

**Standing rules:** rounds 12–15's (the slot, builder0, `make remote` one per worktree, no `pkill -f`, detach long runs,
lessons 225–234); a windowed run on the laptop opens on his desktop — say so in Status and keep it short.


## Round 15: five streams (launched 2026-10-01 evening, CLOSED 2026-10-02; briefs in `streams/archive/round15/`)

**Goal: round 14's own list, built overnight; nothing from his play (*"playin right now feels good"*).** His words are
in [`game_design.md`](game_design.md) *Round 15 direction*; the list is `roadmap.md` *Round 15 candidates*. Same rules
as rounds 12–14; memory *overnight autonomy*: every agent working, decide rather than block, validated work by morning.

| Stream | Brief | Round 15 | Checkpoint |
|---|---|---|---|
| **nav** | [streams/archive/round15/nav.md](streams/archive/round15/nav.md) | **One exit test cannot serve the rig and the scout:** N3 keyed by hull class or plan purpose, the scenario gate green; then N5, the planner that looks earlier from a moving hull; acceptance seeds 17–24 | **CP1** = a baseline move, declared and attributed, merged alone |
| **airship** | [streams/archive/round15/airship.md](streams/archive/round15/airship.md) | **The view-climb is ON; now the 39–49 s intrusion cluster it does not fix, and buying back the seen-share** without putting the hull in the way; the clip for his morning | — (dressing; baseline UNMOVED) |
| **squad** | [streams/archive/round15/squad.md](streams/archive/round15/squad.md) | **The gangs' flipped verdicts measured over seeds** and put on a decision page for him (C12.6: no table ships); the ladder re-baselined with the winner rule printed; `scenario_perf` pinned to one fight; the flanker's loop by the crate | — (baseline UNMOVED unless a brain defect is fixed: declare it) |
| **garage** | [streams/archive/round15/garage.md](streams/archive/round15/garage.md) | **The second tour's list:** the centre scores, said before the fight; the sense of size on the card/turntable; the loader's hint on a phone; the status box at 20:9; the tour again and the next list | — (UI; baseline UNMOVED) |
| **fleet** | [streams/archive/round15/fleet.md](streams/archive/round15/fleet.md) | **Tanks and IFVs that read apart from the play camera:** measure the confusion per faction pair, fix what is free (markings, lamps, paint) first, prepare the paid route on a review page for his morning (concepts only; image-to-3D waits for his tap); no box changes | — (art; baseline UNMOVED) |

**Ownership:** as rounds 12–14 for nav, airship, squad, garage; fleet as round 12's fleet row **minus the `units.gd` /
`tank.gd` carve-outs** (no box changes this round). Garage's carve-outs: `game/ui/loading_screen.gd` (the hint line),
`game/ui/widgets/hud_skin.gd` (the status box), one additive hook in `game/modes/skirmish_mode.gd` if the tip is shown
at the planning pause. Squad adds `tools/tactics_ladder.py`. Airship adds `game/theme/fx/bench/rig_vanish.gd` and
`tools/airship_view_pool.py`.

**Contracts:** C12.6 (nobody tunes balance — squad's page is a RECOMMENDATION, his tap changes a table), C12.7
(generation on the ledger; **concept images only tonight, image-to-3D after his tap**), C14.1 (the baseline
`6313a38d7ecd99bb`; only nav may move it on purpose; pre-register with the path; design seeds named before the first
variant, acceptance on seeds the design never saw), C14.2 (the airship opaque and visible), C14.3 (S6 is his toggle),
**C15.1** the view-climb default is his toggle (`AirshipFlight.view_climb`): airship measures around it, nobody flips
it. **C15.2** every decision page records in Status the time its `db` was last read; the orchestrator reads every page's
`db` at close (step 5a) and lists unconsumed taps in HANDOFF.

## Round 14: four streams (launched 2026-09-27 evening, CLOSED 2026-09-28; briefs in `streams/archive/round14/`)

**Goal: his airship item, and round 13's own list.** His words are in [`game_design.md`](game_design.md) *Round 14
direction, first item*; the list is `roadmap.md` *Round 14 candidates*. Same rules as rounds 12–13.

| Stream | Brief | Round 14 | Checkpoint |
|---|---|---|---|
| **airship** | [streams/archive/round14/airship.md](streams/archive/round14/airship.md) | **A0 first: two War Rigs turned invisible in his play** (defect; measured, not guessed; a carve-out into the cutaway and the rig's theme files for the fix only). Then **the airship steers clear of the player's view** (his words): measure the intrusion with the LIVE camera first, then the carrot avoids the wedge between camera and focus, looking ahead; opaque, visible, in the venue; the PID and the climb-over stay | — (dressing; baseline UNMOVED) |
| **garage** | [streams/archive/round14/garage.md](streams/archive/round14/garage.md) | **The list a player's first visit produced** (round 13's G1 table): room to build, the turntable at match proportions, a stalemate is a draw, a clean HUD at 20:9, the loader, the dead stub | — (baseline UNMOVED; the time-limit rule is outside the 40 s baseline match) |
| **nav** | [streams/archive/round14/nav.md](streams/archive/round14/nav.md) | **The other 53 %**: route-driver circle reverses and k-turn legs, instrumented then validated with the sweep; the stall share re-read on more seeds; does a holding rig block the street | **CP1** = a baseline move, declared and attributed, merged alone |
| **squad** | [streams/archive/round14/squad.md](streams/archive/round14/squad.md) | **Two red instruments**: the gang-pack drills bisected and fixed; `scenario_perf` refuses under load (rule 3); the ladder variants' stale row | — (a drill change may move the baseline: declare it) |

**Ownership:** as round 11's table for airship (`game/theme/arena_kit/airship/**`, its tests and bench, the airship
targets in `mk/fx.mk`, the `_build_airship` carve-out) with `game/camera/**` READ-ONLY (one additive accessor allowed,
listed); as rounds 12–13 for nav and squad; garage as round 1's garage stream (`game/garage/**`,
`game/modes/garage_mode.gd`, `mk/garage.mk`, `tests/garage/**`) **plus three carve-outs** (the time-limit winner rule in
`game/match/match.gd`, `game/ui/camera_readout.gd`, and a read of `Tank._apply_hull_size` — additive, listed, the
orchestrator reviews at merge). Squad's carve-out: the `scenario_perf` targets in `mk/ai.mk` and an additive read of the
box's load.

**Contracts:** C12.6 (nobody tunes balance) and C12.7 (generation on the ledger) stand. **C14.1** the sim baseline is
`6313a38d7ecd99bb`; only nav may move it on purpose; anyone else pre-registers UNMOVED **with the path** or treats a
move as a finding (lesson 223); design seeds are named before the first variant and acceptance runs on seeds the design
never saw (lesson 224). **C14.2** the airship stays opaque and visible, never faded or cut away (the lead, rounds 10 and
14). **C14.3** `TankBrain.IDLE_FACE_NO_PIVOT` is the lead's toggle: nobody flips it.



## Round 13: three streams (launched and CLOSED 2026-09-27; briefs in `streams/archive/round13/`)

**Goal: the lead's answers to round 12's candidate list, built.** His words are in [`game_design.md`](game_design.md)
*Round 13 direction*. Small round, small items, the same rules as round 12 (ownership below is round 12's for these
three streams, plus the garage carve-out).

| Stream | Brief | Round 13 | Checkpoint |
|---|---|---|---|
| **squad** | [streams/archive/round13/squad.md](streams/archive/round13/squad.md) | **The default plain-move shape is the wedge** (his answer 2), on the paired series; then **S6 measured** (stop issuing an idle `face` to a no-pivot hull with nothing in sight) | — (a sim move is possible on S6: declare it) |
| **nav** | [streams/archive/round13/nav.md](streams/archive/round13/nav.md) | **Right-of-way sized for long hulls**: a 14 m rig yields into room it fits in; the +57 % reverse-gear contacts are the number to move; started on the orchestrator's recommendation, his veto stands | **CP1** = a baseline move, declared, merged alone |
| **audio** | [streams/archive/round13/audio.md](streams/archive/round13/audio.md) | **The garage, smoke-tested like a player, then given music** (his answer 6: *"I've never even smoke tested the garage"*): title → GARAGE → build → FIGHT on the default path, frames, what breaks; then the `garage` state plays a bed and rotates | — (isolated) |

**Ownership:** as round 12's table for squad, nav and audio, **plus a carve-out for audio:** `game/garage/**`, the garage
targets in `mk/garage.mk`, and `game/modes/garage_mode.gd` (the paused stream's paths) for the smoke test and the music
hook only — no garage feature work; anything bigger is written up as a round-14 item.

**Contracts:** C12.6 (nobody tunes balance) and C12.7 (generation on the ledger) stand; the sim baseline is
`6313a38d7ecd99bb` and only nav may move it.
 How rounds work (roles, lifecycle, the worker contract, the
> kickoff prompt) is in [orchestration.md](orchestration.md): read it first. **Round 12's six streams, ownership,
> checkpoints and contracts are in the next section.** Round 11's section follows it (closed; its record is
> `HANDOFF.md` *ROUND 11*), then round 10's (closed, kept for its contracts R1–R9); the round-9 section after that
> (S1–S6, the research-catalogue sequencing) is still in force where it is not superseded; rounds 1–11 are archived in
> `streams/archive/round1..11/`; the round-6 material further down (contracts N1–N7, ownership, invariants) is still
> in force where it is not superseded.

## Round 12: the six streams (launched 2026-09-26, CLOSED 2026-09-27; briefs in `streams/archive/round12/`)

**Goal: every pending item on the list he approved, after his two corrections.** His words are in
[`game_design.md`](game_design.md) *Round 12 direction* (both parts: the fine-tuning session and *Round 12 becomes a
round*). The list is `roadmap.md` *Now* as it stood on 2026-09-26, minus "the direct path still scatters" (a whole-squad
box-select already takes the task path; a partial one is a question, not a defect) and plus **the fire engine he
approved on 2026-09-24 that nobody built** (the page's `db` held the tap; the repo never read it).

**The acceptance test for the round is his:** the Condemned field a fire engine that is not a prison bus and a bus that
is not a van; the water on the Crossing and the Locks reads wet at his pose; the camera never sits inside a floodlight's
lamp head and an ad screen between him and the fight is cut away; the AUTO icon shows the shape the squad is actually
forming and a G-chosen wedge is still a wedge when the squad halts; a War Rig squad gets through the Terminus streets
with fewer refused back-ups; the booth stops saying *"they are trading"* every match and the opening music is not the
same track every time.

| Stream | Brief | Round 12 | Checkpoint |
|---|---|---|---|
| **fleet** | [streams/archive/round12/fleet.md](streams/archive/round12/fleet.md) | **The fire engine he approved and the bus he approved, built** (`burner_r11_b` → 3D → the burner's own hull, turntable turret and box; `bus_r11_i` → 3D → `unit.tank.hull`; his taps recorded first); the burner's `turret_mount` and the −Z test; stretch: the War Rig's muzzle, measured before moved | **CP1** = the burner's (and the bus's, if it moves) `hull_size`, merged alone; the orchestrator records the baseline |
| **arena** | [streams/archive/round12/arena.md](streams/archive/round12/arena.md) | **Water reads wet** (the Crossing, the Locks, the canal fixture) at his pose, judged as pairs on his page with `db`; the Locks' open-canal question re-put with the exposure number; pits stay dark and read as pits | — (visual; sim baseline pre-registered UNMOVED, navmesh untouched) |
| **camera** | [streams/archive/round12/camera.md](streams/archive/round12/camera.md) | **The camera asks the drawing, not the collider**: `RtsCamera.roof_over` / `clear_pose` / `sight_blocked` and `BlockCutaway._gather` read a drawn-extent table (floodlight 16 m, ad screen 20.7 m, sign 7.65 m) instead of the collision boxes; measured over the Terminus pose sweep; **no collider grows** | — (visual; baseline UNMOVED) |
| **squad** | [streams/archive/round12/squad.md](streams/archive/round12/squad.md) | **The formation he sees is the one the squad forms**: the AUTO icon and card show the leader's actual pick (control's `command_icons.gd`, a carve-out); a G-chosen formation survives `_halt`; the fall-in rule for the first seconds of a move from the spawn line; the partial-selection question answered on the default path; whether *dense → column* is the right row for a plain move on the maps he plays | — (a sim move is a finding; declare it) |
| **nav** | [streams/archive/round12/nav.md](streams/archive/round12/nav.md) | **The War Rig's refused back-ups** (`kturn_none` 130 against 64 `kturns` on the Terminus drive): why the single planned reverse finds nothing in an 18–22 m street, then a multi-leg plan (back-and-fill) validated against the navmesh with both ends, measured on the drive test over 8+ seeds; stretch: the kinematic planner the count is asking for | **CP2** = any change that moves the sim baseline, declared, merged alone; attributed with `make nav-sim-arms` |
| **audio** | [streams/archive/round12/audio.md](streams/archive/round12/audio.md) | **The trade call and the opening track**: the `trade` pool (5 lines: 3 caller, 2 color) deepened and the director's pick audited with the pool report; the 23 Suno tracks in `assets/incoming/music/` imported and assigned so every state with one bed has several and the per-match rotation is TESTED to rotate; generation authorised under his round-10 words, on the ledger, on the Booth Monitor for his veto | — (runs in isolation; `music-smoke` and `announcer-record-smoke` prove the sim unmoved) |

**Why six, and why these six:** each is one problem with one owner and one set of paths — the vehicles (fleet), the
water (arena, holding the terrain art this round since no feel stream runs), the camera's occlusion rules (camera),
the formation the player sees and gets (squad, with one carve-out into control's icon file), the rig's manoeuvre
planner (nav), the booth and the soundtrack (audio). No stream needs another's output to start. Six sessions are
~2.1 GB on this 7.6 GB laptop, which had ~2 GB free at launch with Chrome open: **start fleet, squad and audio first;
camera, arena and nav when memory allows**, and every Godot run of any size goes to builder0.

### Checkpoints (round 12)

- **CP1 — fleet's hull boxes.** A `hull_size` change is a sim-baseline move by construction (spawn grid, collider).
  fleet lands its art first, then puts every box change in ONE commit and names the green hash; **the orchestrator
  records the baseline twice in the same session** (`make sim-baseline-adopt`, never a copied file). Nobody publishes
  a size-dependent number measured across CP1.
- **CP2 — nav's planner.** A manoeuvre plan that changes when a hull reverses moves the sim baseline (round 11's did:
  `457b5e83 → 814aed46`). nav declares it in its green report, attributes it with `make nav-sim-arms`, and the
  orchestrator records it alone. Not before nav's drive-test numbers are in its Status.
- Everything else pre-registers **UNMOVED** (`01ab39b592cc9837`) and treats a move as a finding.

### Who owns what (round 12) — changes to the tables below

| Path | Owner (round 12) |
|---|---|
| `game/theme/factions/**`, `game/theme/roster/**`, `game/theme/prison_dozer/**`, `game/theme/cyberpunk/dozer_part.gd`, `game/theme/gallery/**`, `assets/pipeline/**`, `assets/review/**`, `assets/meshy_ledger.md`, `tools/assets/**`, `mk/assets.mk`, `mk/scale.mk`, the gallery/audit/probe targets in `mk/fx.mk`, `tools/roster_scale.py`, `tests/test_theme_unit_scale.gd`, `tests/test_units_*.gd`; **carve-outs:** the `hull_size` / `muzzle_height` / `turret_mount` / `scale_reference` VALUES of `tank` and `burner` in `game/units/units.gd`, and `Tank._apply_hull_size` / `Tank.turret_pose` in `game/tank/tank.gd` | **fleet** |
| `arenas/`, `game/arena/`, `game/theme/arena_kit/terrain/**` (the water and pit art, the shaders), `tools/make_arenas.py`, `tools/terrain_maps.py`, `tools/arena_report.py`, `mk/arena.mk`, `tests/arena/`, `tests/test_arena*.gd`, `_agents/arenas.md`; **carve-out:** the lamp-pool and environment inputs the water shader reads from `game/theme/cyberpunk/arena_dressing.gd` / `arena_environment` (ADDITIVE accessors only, listed in merge notes) | **arena** |
| `game/camera/**`, `tests/test_control_camera_solids.gd`, the camera tests under `tests/`; **read-only:** `AirshipFlight.DRAWN` (`game/theme/arena_kit/airship/airship_flight.gd`) — see C12.2 | **camera** |
| `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,tank_brain,element_feed,directives}.gd`, `doctrines/`, `mk/tactics.mk`, `tools/tactics/**`, `tests/test_tactics_*.gd`, `tests/ai_scenarios/`, `_agents/{doctrine,tank_brain,squad_ai_design}.md`; **carve-outs into control:** `game/ui/command_icons.gd` (the AUTO glyph and its label) and the formation readout on the selection card in `game/control/` (the consumer of `UnitCommand.AUTO` there) — additive, no other control paths; **and, if the partial-selection answer is "give it the anchor":** the route from `RtsControls.order_selection` into a transient element, one function, listed in merge notes (the orchestrator reviews at merge; no control stream runs) | **squad** |
| `game/ai/movement.gd`, `pathing.gd`, `steering.gd`, `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`, `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`, `_agents/algorithms.md` | **nav** |
| `game/announcer/`, `assets/announcer/`, `tools/announcer/`, `tests/announcer/`, `mk/announcer.mk`; `game/audio/`, `assets/music/`, `assets/incoming/music/` (ignored), `tools/audio/`, `mk/audio.mk`, `tests/test_audio_*.gd`, `assets/announcer/ledger.md` | **audio** |
| everything else | orchestrator / shared, as the round-6 table below |

### Contracts (round 12)

- **C12.1 — the fleet page's taps are the lead's decisions.** `burner_r11_b`, `bus_r11_i` and `q_r11_bus_fit` are
  APPROVED (2026-09-24 17:27 UTC; the dump is in `streams/references/round12/fleet_page_db/`). fleet records them with
  `make art-apply-decisions` (or `art-decide` per id) as its first commit, so `review.json` and the page agree. Lead
  gate 1 is satisfied for exactly those two image-to-3D runs; any further concept or 3D goes back to a page with `db`.
- **C12.2 — one drawn-extent table, read, not copied** (Invariant 0). `AirshipFlight.DRAWN` is held against the kit's
  meshes by `test_the_flights_table_of_drawn_props_covers_what_the_kit_draws`. camera READS it. If camera needs it
  somewhere the airship's file is the wrong home for, it moves it in ONE additive commit to a `drawn` field beside
  `ArenaKit.PROPS` (arena's file; arena reviews at merge) with the test moving with it, and the airship reads the new
  home. Two tables of drawn heights is the defect this round exists to fix, one layer up.
- **C12.3 — the collider never grows to fix a picture.** Nothing in `ArenaKit.PROPS` sizes, `Arena.active["obstacles"]`
  or the `Obstacles` bodies changes for a visual reason. camera and arena pre-register the sim baseline UNMOVED.
- **C12.4 — the icon shows what the leader picked.** squad publishes the element's chosen formation where the card
  can read it (`Element.state()["formation"]` already exists; the icon must read THAT for an AUTO selection, and the
  requested shape for a G-chosen one). control's file changes only in the glyph/label lookup; the palette, hotkeys and
  the six-verb popup are untouched.
- **C12.5 — a G-chosen formation is the shape at every phase.** `task.formation`, when present, wins over the table's
  pick in `_plan_form_up`, `_advance_transit`'s stations AND `_halt`; the table decides only under AUTO. Test: a wedge
  ordered with G is a wedge at t0, in transit and after arrival, on a drills-on move.
- **C12.6 — nobody tunes balance.** fleet's sizes reach matchups; nav's planner reaches arrivals. Report the number;
  do not chase it (*"we'll worry about evening up factions later"*).
- **C12.7 — generation is authorised, scoped by count, on the ledger.** ElevenLabs for audio under his round-10
  words (*"let's burn through some ElevenLabs credits"*) and the standing humour direction: text through
  `make announcer-audit`, every run on `assets/announcer/ledger.md` with the balance before and after, every clip
  speech-to-text verified, the new lines on the Booth Monitor for his veto. Meshy for fleet: the two approved runs
  (~15 credits each) plus what the splitter needs; balance 809. Both streams stop and ask at half the remaining
  balance.

### Standing rules for round 12

- **Play the default path** (`make skirmish` with no flags, the maps in the rotation) before reporting anything
  shipped; a behaviour behind a flag the default path never passes has not shipped.
- **Every visual claim is a pair at his pose** (21°, FOV 35, 49 m): before/after, one variable moved, on a page with
  `db` so his tap is recorded — and **the orchestrator reads that page's `db` at the round's close** (lesson 220).
- **Every number carries its commit and its machine**; the laptop is ~2.75× slower than builder0; merge at the hash
  whose check went green; read the wrapper's own `>> remote: make check exited <N>` line.
- **Baseline moves are declared and merged alone** (CP1, CP2); every other stream pre-registers UNMOVED.
- **Series compare arms on the same seeds** and print discordant pairs; nav's drive test takes 8+ seeds per arm.
- **A hypothesis from the orchestrator is labelled as one** (lesson 219), with the measurement that would kill it.

## Round 11: the four streams (launched 2026-09-24, CLOSED 2026-09-24; briefs in `streams/archive/round11/`)

**Goal: the eleven defects he named in one playtest, and the maps he has asked for three times.** His words are in
[`game_design.md`](game_design.md) *Round 11 direction*. He called it a light workload and it is: no new mechanic, no
new system, no design argument to settle. **Three of the four streams are finishing work that already exists and does
not reach him**; the fourth is driver intelligence he has now described precisely enough to build.

**The acceptance test for the round is his:** pick each map from the faction picker and see the bridges, the water and
a pit; drive a squad through the Terminus streets and watch a hull reverse *before* it touches a wall; look at the
three factions parked side by side; and watch the airship fly the Terminus without passing through a block, with the
camera lifting over it when they meet.

| Stream | Brief | Round 11 |
|---|---|---|
| **arena** | [streams/archive/round11/arena.md](streams/archive/round11/arena.md) | **The maps he has never been dealt** (`Arena.ROTATION` is three names and `arenas/` holds fifteen; round 10's Crossing and Sumps — water, bridges and the only real pits in the game — have never been reachable), each played on the default path and judged on the arena page; **the venue floodlight towers are solid** (21 m of steel with no collider, standing 7.8 m inside the Terminus wall) and the parity test extended to the dressing layer that hid them; then one genuinely new terrain map |
| **nav** | [streams/archive/round11/nav.md](streams/archive/round11/nav.md) | **His two-part Terminus problem, measured apart.** R2: the goal repair (`squad.gd:272` grounds a slot on the mesh centre, so a War Rig's nose is in the building; `source != "player"` is not grounded at all; `_reachable == false` is computed and thrown at a readout). R1: **a reverse decided at plan time** — run the turning-circle test against the route's first leg and emit an explicit reverse leg, instead of discovering it at the bumper through `unstick` and the pressed-wall escape |
| **fleet** | [streams/archive/round11/fleet.md](streams/archive/round11/fleet.md) | **The vehicles, five complaints and four causes:** seven turrets spinning *inside* their hulls for want of a `turret_mount`; five stray generated barrel sticks (the Law tank's is 14 triangles, 1.8 cm across, 0.74 m off centre); the Condemned tank and burner as the only non-uniformly **stretched** meshes in the game (1.63:1 on the tank — his "deformed" one); the Law's tank and IFV re-derived under the round-9 K rule; and **a test that a nose points at −Z**, which has never existed |
| **airship** | [streams/archive/round11/airship.md](streams/archive/round11/airship.md) | **It flies through the blocks and the camera flies through it.** Real rotated footprints instead of a circle table that is 7.28 m short at every block corner; a look-ahead by the 8.7 s it takes to climb; `contain` no longer erasing `avoid` at the (±100, 0) blocks; a 3 m floodlight no longer entered as 24 m (which is most of why it cruises low only 52 % of the time on the Terminus); and **the camera lifting over the hull** through the round-9 solid rule, which today cannot see a moving occluder at all |

**Why four, and why these four:** each is one independent problem with one owner and almost no overlap — the maps and
their props (arena), the driver and the goal (nav), the vehicles (fleet), the airship and the camera (airship). The
two smallest shared files are split by function and named below. No stream needs another's output to start.

### The one checkpoint

**CP1 — fleet's size changes (its T3 + T4), merged alone.** Any `hull_size` move changes the spawn grid, the collider
and the sim baseline by construction. fleet lands its art items first, then puts every box change in one commit and
names the green hash; **the orchestrator records the baseline twice in one session**, never the worker. Nobody
publishes a size-dependent number measured across CP1. Everything else merges when it is green.

### Who owns what (round 11) — changes to the tables below

| Path | Owner (round 11) |
|---|---|
| `arenas/`, `game/arena/`, `tools/make_arenas.py`, `tools/terrain_maps.py`, `tools/arena_report.py`, `mk/arena.mk`, `tests/arena/`, `tests/test_arena*.gd`, `_agents/arenas.md`; **carve-outs:** `_build_tower` and the venue placement calls in `game/theme/cyberpunk/arena_dressing.gd`, and `tests/test_arena_prop_parity.gd` | **arena** |
| `game/ai/movement.gd`, `pathing.gd`, `steering.gd`, `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`, `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`, `_agents/algorithms.md`; **carve-out for R2 only:** `game/tactics/slot_ground.gd`, `Orders.ground_goal` in `game/control/orders.gd`, and the call site `game/ai/squad.gd:272` (no control or squad stream runs; the orchestrator reviews these three at merge) | **nav** |
| `game/theme/factions/**`, `game/theme/roster/**`, `game/theme/prison_dozer/**`, `game/theme/cyberpunk/dozer_part.gd`, `game/theme/gallery/**`, `assets/pipeline/**`, `tools/assets/**`, `mk/assets.mk`, `mk/scale.mk`, the gallery/audit/probe targets in `mk/fx.mk`, `tools/roster_scale.py`, `tests/test_theme_unit_scale.gd`, `tests/test_units_*.gd`; **carve-outs:** the `hull_size` / `muzzle_height` / `turret_mount` VALUES in `game/units/units.gd`, and `Tank._apply_hull_size` / `Tank.turret_pose` in `game/tank/tank.gd` | **fleet** |
| `game/theme/arena_kit/airship/**`, `game/camera/**`, `tests/test_theme_ad_airship.gd`, `tests/test_control_camera_solids.gd`, `game/theme/fx/bench/airship_shot.gd`, the airship targets in `mk/fx.mk`; **carve-out:** `_build_airship` in `game/theme/cyberpunk/arena_dressing.gd` | **airship** |
| everything else | orchestrator / shared, as the round-6 table below |

### The two shared files, split by function

- **`game/theme/cyberpunk/arena_dressing.gd`:** arena owns `_build_tower` and the venue placement calls that site the
  towers; airship owns `_build_airship` (`:140-155`). Neither touches the other's function; both list the file in
  their merge notes.
- **`game/units/units.gd`:** fleet changes VALUES only (`hull_size`, `muzzle_height`, `turret_mount`). Nobody changes
  the catalogue's shape, weapons or balance this round.

### Contracts (round 11)

- **C11.1 — the rotation is published early.** arena's first item adds `crossing` and `sumps` to `Arena.ROTATION`.
  Every stream that walks "every shipping map" (`SyndicateAdAirship.flies_on`/`route_for`, `make nav-fight-maps`,
  fleet's galleries) re-runs its map walk after the orchestrator announces that merge. Until then, **say which map
  list a number was taken on.**
- **C11.2 — the camera's solid rule stays pure and headless.** `RtsCamera.clear_pose` is a static function over data,
  which is why it has tests at all. airship may add a dynamic occluder parameter or registry; it may not make the rule
  require a physics space or a running tree.
- **C11.3 — the airship gets no collider,** and the sim baseline `457b5e830708b439` does not move for any reason
  except CP1.
- **C11.4 — nobody tunes balance.** fleet's sizes and arena's navmesh both reach matchups. Report the number; do not
  chase it (his standing ruling: *"we'll worry about evening up factions later"*).

## Round 10: the nine streams (launched 2026-09-20 evening, run 2026-09-22, CLOSED 2026-09-23; briefs in `streams/archive/round10/`) — CLOSED, kept for its contracts

**Goal: the playability blockers he named, in the order they block him.** His words are in
[`game_design.md`](game_design.md) *Round 10 direction*. He cannot judge unit intelligence until a right-click is obeyed
at once, any selection can carry an element order, and a squad can be driven through the Terminus streets; after that
come the walls and the yaw, then the look (walls of light, the blimp, the turrets, the bus), then the announcer. Every
stream's first backlog item is one of his sentences. **The acceptance test for the round is his: `make skirmish
ARENA=terminus`, drive squads through the streets, give ad-hoc selections element orders, and see the lights.**

| Stream | Brief | Round 10 | Checkpoint |
|---|---|---|---|
| **control** | [streams/archive/round10/control.md](streams/archive/round10/control.md) | **The unanswered right-click** (a player's order replaces an in-flight one within one input frame, on the default path, with the readout saying what was ISSUED); **squad orders for a mixed selection** (R1 narrowed: a Form-squad action and a reason on the greyed buttons; the regroup behaviour stays); the refused-order banner and `ungrouped=N` readout | — |
| **squad** | [streams/archive/round10/squad.md](streams/archive/round10/squad.md) | **a player's order pre-empts a task, a hold and co-arrival pacing**; the 40 s settle on a 20 m move; slot pitch from the turning envelope (decided: hulls do not clip while dressing); the base-of-fire scenario; `_is_clear`; Delta's margin | — (CP1 withdrawn) |
| **arena** | [streams/archive/round10/arena.md](streams/archive/round10/arena.md) | **The Terminus streets are lanes** (containers off the lanes; every lane's narrowest drivable width asserted, not watched; the arena page shows the before/after at his pose); **prop collision parity** (R3: what a hull can touch has a collider; the lamps); the spawn grid gives a hull room to turn (the half-diagonal, scale's round-9 handover) | **CP2** = the Terminus lanes green, merged alone, early (nav's drive test runs on it) |
| **nav** | [streams/archive/round10/nav.md](streams/archive/round10/nav.md) | **Units still drive into walls**: the Terminus drive test (a squad ordered street to street on the default path: zero wall contacts, arrival, measured), what a wall contact IS (a counter on the plant, published), the wedged regime, the obstacle-tiling row; every clearance constant names the motion it licenses; `Avoidance.radius_of` (the seventh disc site); the held wheeled hull's facing; the seam (Movement vs CombatMotion) as the structural item, measured before moved | — |
| **combat** | [streams/archive/round10/combat.md](streams/archive/round10/combat.md) | **The rigs yaw through walls**: the plant predicate (why a clear hull refuses every candidate yaw for 1135 ticks), the ordering, then diagonal spacing as a candidate; the constraint returns ON only when five_squads passes with the corridor numbers kept; ORBIT radius reads hull length (the engine-deck scenario); the artillery scenario; the gangs-vs-law series with `match.hull_disc` (stretch) | **CP4** = the constraint ON (baseline moves), merged alone if it happens |
| **feel** | [streams/archive/round10/feel.md](streams/archive/round10/feel.md) | **The blimp he asked for, in HIS frame** (R7); **the turret mounts** (R5: a per-unit mount in the hull frame, derived from the mesh, applied on all three axes; Condemned and gangs first); **the Condemned bus reads bigger than the garbage truck** (R6: his eye rules over the reference for `tank` and `burner`; concept page for a paid bus mesh); the per-faction rim light | **CP3** = the bus box (baseline moves), merged alone; the orchestrator records |
| **show** | [streams/archive/round10/show.md](streams/archive/round10/show.md) | **The light show on the building WALLS**: per-window addressable primitives (custom data per instance, the S6 hook rule), effects composed from them (chases, waves, sweeps, sign flicker, a kill ripple that crosses a facade), judged by HIS eye against a 1990s-baseline frame, not a luminance bar; the frozen re-shoot and the louder pair first (the fastest thing he can see) | — |
| **announcer** | [streams/archive/round10/announcer.md](streams/archive/round10/announcer.md) | **More lines on the same themes** (deepen every thin moment to a real pool; same voices, same humour direction), audited, on the review page, **generated this round** (R8: he authorised the spend); the ledger; speech-to-text verified; the transcripts and the Booth Monitor re-cut | — (runs in total isolation against fixtures) |
| **terrain** | [streams/archive/round10/terrain.md](streams/archive/round10/terrain.md) | **The maps with water, pits and bridges that never materialised** (added 2026-09-20 evening on his ask): the `arena.terrain` art first (the reason he could not see it), then two maps that use the round-7 mechanism with mirrored objective pairs (a river with two bridges; pits as kill zones), each judged by `spread` > 0, a paired series showing the expensive route used, and his eye on the arena page; bridges are lanes under R4 | — (its maps are new files; Godot on builder0) |

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
| **R2b One grounding call for per-unit goals (added 2026-09-22 night, nav's finding).** Every per-unit goal issued to a crew (Element slots, the right-click formation slots from `Orders._resolve_group`, the drills' stations, a follow station) is grounded onto the navmesh with the HULL's own clearance (the turning-envelope tier) through squad's `SlotGround.standable_for(point, hull)` (public, usable without an Element), and the readout says when a goal was moved and by how much. Found because the drive test's misses were all ungrounded right-click goals inside blocks. | squad: `SlotGround.standable_for` | control (`orders.gd`), squad's Element and drills |
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
| **nav** | [streams/archive/round10/nav.md](streams/archive/round10/nav.md) | **A7 → A11 → A1 → A4**, in nav's own order (argued below), A7's priority table written and reviewed before code | — |
| **combat** | [streams/archive/round10/combat.md](streams/archive/round10/combat.md) | **A2** state-dependent switching cost (falsifier: squad's fire-concentration and engine-deck scenarios), then **A3's consumer**; the balance consequences of the resized roster measured, not tuned | — |
| **squad** | [streams/archive/round10/squad.md](streams/archive/round10/squad.md) | **A8 → A9 → A10**, each naming what it replaces by file; formation spacing derived from hull length after CP2 | — |
| **feel** | [streams/archive/round10/feel.md](streams/archive/round10/feel.md) | **The articulated War Rig** (visual hinge at the fifth wheel, tractor simulated, trailer follows; the 14 m box stays), the **A6 motion-law contract** with control and nav, the void below the near wall; stretch: the Syndicate airship from primitives | — |
| **show** | [streams/archive/round10/show.md](streams/archive/round10/show.md) | **Added 2026-09-20:** the arena as a light show — fixtures, channels, patches and cues over the Terminus blocks, the perimeter neon and the signage, driven by match mood and events, at zero added draw calls and lights ([game_design.md](game_design.md) *Round 9 addition*) | — |
| **control** | [streams/archive/round10/control.md](streams/archive/round10/control.md) | **Desktop right-drag facing** with the test that makes the arc's A/B live by construction; the **A6 readout**; the camera, HUD, selection and radar checked at his pose against the resized roster after CP2 | — |

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
| **nav** | [streams/archive/round10/nav.md](streams/archive/round10/nav.md) | A horde gets where it is sent: real path planning, local avoidance with peer-to-peer right-of-way, nothing stuck, and one regulated control law (PID) from the wheels up. Proven on a maze. |
| **squad** | [streams/archive/round10/squad.md](streams/archive/round10/squad.md) | A squad order is a *formation* order: a target formation anchored on the destination, a slot per unit, a form-up formula and ETA, and every named task producing the behaviour its name claims |
| **control** | [streams/archive/round10/control.md](streams/archive/round10/control.md) | The squad UX earns every button: military task symbology, nothing the mouse already does, a camera between StarCraft 2 and Twisted Metal, and loading that shows its progress |
| **arena** | [streams/archive/round10/arena.md](streams/archive/round10/arena.md) | Terrain that makes ambush and flanking possible instead of one open brawl, plus the maze arena nav is measured against |
| **combat** | [streams/archive/round10/combat.md](streams/archive/round10/combat.md) | Engagement ranges where seeing an enemy is not the same as opening fire: closing, breaking contact and cover become decisions |
| **feel** | [streams/archive/round10/feel.md](streams/archive/round10/feel.md) | The arena is inhabited: a crowd in the stands that can be seen and heard, and the place reacts to the match |

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
| `game/ai/{pathing,steering,combat_motion,order_controller,order_feed}.gd`, new `game/ai/{avoidance,movement,pid,control_gains}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk` (new), `_agents/navigation.md` (new) — **one exception, granted 2026-09-18:** with no nav session running and two streams holding for CP4, combat made four surgical edits to `order_controller.gd` (an `engagement_lay` member, an `Engagement.is_seen` early-out in `_shootable`, an `envelope` term in the trigger line, and a seconds helper with `lose`/`forget`). Every rule lives in combat's `game/combat/engagement.gd`; the controller only holds state and calls it, and none of the edits touches a path, waypoint or throttle. nav reviews them when it starts and owns the file. The seam combat wants for the `gunnery.gd` split is written into [streams/archive/round10/nav.md](streams/archive/round10/nav.md). | **nav** |
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
| ~~`garage/catalog_stub.gd`~~ | — | deleted in round 14 (garage G6): its pre-CP2 boxes were unreachable |
| `garage/garage_turntable.gd` | all three | round 14 (G2): the preview IS a `Tank` (simulate off), so it draws `hull_size` through `apply_unit`; the camera frames the box |
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
