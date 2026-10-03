> **ARCHIVED (round 16, CLOSED 2026-10-03).** This brief ran as stream `sim` in round 16; every item is merged to `main`
> (`HANDOFF.md` *ROUND 16*). The Status below is the worker's final report. Kept for its numbers and decisions.

# Stream: sim (the rest of the tick: Match, intel, the visibility field, tanks, shells; then Law's APC on tracks)

> Read `_agents/orchestration.md` (the worker contract), `_agents/architecture.md`, `_agents/sim_tick_rate.md`,
> `_agents/determinism.md`, `_agents/verification.md` (rule 3, *Attributing a behaviour's cost*), `_agents/balance.md`
> *X5: what the simulation costs at scale*, `_agents/workstreams.md` *Round 16*. You own `game/match/**`
> (including `visibility_field.gd` and `sim_profile.gd`), `game/tank/**`, `game/combat/**`, `game/arena/**`,
> `game/units/**`, `tests/test_match*.gd`, `tests/test_combat*.gd`, `tests/test_tank*.gd`, `tests/test_arena*.gd`,
> `tests/test_units*.gd`, `tests/combat/**`, `tests/arena/**`, `tests/scale/**`, `mk/match.mk`, `mk/arena.mk`,
> `tools/sim_profile_report.py`, and the `[physics]` keys of `project.godot` (a carve-out: list every edit in merge
> notes). Contracts C16.1–C16.5. **The one rule: the sim baseline is UNMOVED by every perf commit (C16.2); the ONE
> behaviour change in this stream (S9, Law's APC) is its own commit, pre-registered, merged alone as CP2.**

## The lead's direction (2026-10-02)

> *"the game is getting extremely choppy … it's likely that we just haven't done the work latley to optimize our code to
> just find basic efficiencies we can gain across the codebase - before sacrificing any of the existing graphics or
> gameplay let's find (or profile our code) where we can just get better performance out of our application"*

And, decided in chat on 2026-10-02 (`game_design.md` *Round 15: … Law's APC handling*): *"For the law's tracked APC if it
is now a tracked vehicle it should behave as one."*

He plays `make skirmish` natively on his laptop (Intel UHD 620, window 1854×1011), default armies (24–27 a side at the
start), choppy from the first second. Nothing is cut: not a rule, not a raycast that decides something, not a unit.

## Where things stand (measured today, 2026-10-02, at `1efa9940`)

- **The tick is the wall.** On his laptop at his window with his flags (`streams/references/perf/r16-before-1080-his-flags.json`):
  at 30 vehicles `tick_script_ms` **24.0 ms** of a 36.9 ms frame; at 52 vehicles 35 ms and 3.5 ticks a frame. Budget:
  ≤ 5 ms a tick at 60 vehicles, the non-brain part of which round 5 measured at **2.7 ms headless at 58 vehicles**
  (laptop; `sim_tick_rate.md:79`). Brains are the other stream's; your lines are `match`, `match/intel`,
  `match/suppression`, `match/squads`, `match/land_rounds`, `tank`, `tank/drive`, `tank/publish_state`, `shell` in
  `make sim-profile` (`SimProfile.MARKERS`, `sim_profile.gd:38-40`) — **and one thing none of the headless instruments
  can see.**
- **`VisibilityField` runs only in the game he plays** (`game/match/visibility_field.gd:60-152`, created by
  `skirmish_mode.gd:253-254`, never in `sim-profile`/`ai-perf`/`scale-bench`/`perf-scene --player=cpu`?). Per tick it
  runs `look_from(one viewer)`: `ray_count = ceili(TAU * sight_radius / 2.0)` ≈ **346 `intersect_ray` calls** at a
  110 m sight radius (`units.gd:166`), then `_mark()` scans the viewer's bounding box of cells (≈ 12 100 at 110 m) with a
  `sqrt` and an `atan2` per cell, then `_finish_refresh` rebuilds a full `cells×cells` `PackedByteArray` and re-uploads
  the image. **Top suspect for "choppy in the skirmish while the match runner looks fine" — measure it first, by
  switching it off inside one run** (a switch in your file, `--sim-off=visfield` or similar, read by play's harness).
- **`Match._update_intel` is O(viewers × enemies) with an allocation inside the loop** (`match.gd:1018-1061`):
  `sorted_team_tanks(1 - team)` is called INSIDE the viewer loop (`:1030`) — a fresh typed Array and a name-sort walk per
  viewer per intel tick; each pair does `distance_to` then `Perception.has_line_of_sight` (an uncached raycast); a 12-key
  Dictionary per visible contact per pass (`:1044-1052`); `known.keys()` for expiry. Round 5 already found and fixed
  the same shape once (`_sorted_tanks` cached per tick; the idle-guns readout sampled every 10th pass — `balance.md`
  *X5*). `sorted_team_tanks` (`:701-707`) re-filters the cached sort into a new array on every call.
- **Allocating accessors called per tick AND per frame by the HUD:** `tanks_by_name` (`:661-665`: a Dictionary +
  `String(tank.name)` per tank, from `_update_squads`, `squad_context`, and the tactical map every frame),
  `team_squads` (`:639-647`: `keys()` + `sort()` every call), `team_tanks`/`alive_count` (`:1098-1112`: a typed Array
  and a `get_children()` walk; `hud.gd` calls `alive_count` twice a frame), `is_visible_to` (`:1063-1066`:
  `String(tank.name)` + a `{}` default literal per call, per tank per frame from four widgets).
- **`Units.stat` formats a String key on every call** (`units.gd`: `"%s.%s" % [unit_id, key]` + `_ensure_env_tuning()`),
  and it is called per tank per frame by `unit_bars`, `selection_markers`, `radar`, `CommandIcons.role_of`, and per
  think by brains. **A cached, allocation-free stat is CP1b — land it early (first hours), the orchestrator merges it
  and tells hud and brains to `git merge main`.** Keep the tuning semantics (`--tune=…`) identical; a test that the
  tuned path still wins.
- **Physics:** Jolt, 30 Hz, interpolation on, `max_physics_steps_per_frame=3` (`sim_tick_rate.md:106-125`: above ~100 ms
  a frame the game runs in slow motion rather than spiralling — document it for him, do not change it without a
  measured reason). Count the bodies and shapes alive in his match (6 000 crowd figures are MultiMesh, not bodies —
  confirm); shells as bodies vs rays; the arena's collision shapes; `move_and_slide` per tank per tick
  (`tank.gd:375-430`, the cheapest band at ~1.3 ms at 31 v 27 — re-measure).
- **The recorder** (`build/recordings/*.jsonl`): a census every second with every unit's state serialised to JSON
  (591 KB over his 124 s match). Measure its cost on the census tick (a hitch every second is exactly "choppy");
  if it is visible, spread or defer the serialisation — the file stays byte-identical.
- **Instruments:** `make sim-profile` (`PROFILE_FLAGS=--no-brains` isolates your lines; add sections with
  `SimProfile.add`), `make scale-bench`, `tests/test_combat_sim_profile.gd`, `tests/scale/cover_bench.gd`; play's
  `make perf-play` (CP1) for the skirmish-only cost on the laptop; `make remote T=…` for everything heavy.

## Backlog (in order)

Every item: measure FIRST (a section, a counter, a switch-off within one run), change, `make remote T=check` with the
baseline read from the wrapper's line (UNMOVED), `make determinism`, the number again; commit with both numbers, their
commit, machine, workload, sample.

- **S1. The visibility field, priced and switched.** A `--sim-off=visfield` switch (your file) and a `SimProfile`
  section `match/visfield`; `tick_script_ms` with and without it in one `make perf-play` run on the laptop (ask the
  orchestrator for the quiet-window run) and in a headless skirmish on builder0. If it is what the numbers say it is:
  (a) rays only where the answer can change (the viewer moved more than a cell, or a solid changed) — a per-viewer
  memo keyed by quantised position and heading, deterministic; (b) `_mark` without `atan2` per cell (precomputed
  per-ray cell lists, or a polar sweep that writes each cell once); (c) `_finish_refresh` touching only the cells
  that changed (a dirty rect) and uploading once per refresh cadence, not per tick. **The image the radar and the
  fog-of-war visual read must be identical frame for frame** — a test that hashes the field after N ticks before and
  after (the baseline does not cover it: it is skirmish-only; write the parity test first).
- **S2. `_update_intel` without the allocation inside the loop and without the repeated raycast:** the enemy list
  built once per team per pass; `has_line_of_sight` through ONE per-tick LOS service (a memo keyed by the quantised
  pair, deterministic, shared with brains by request — coordinate the key with brains' A3 so the two memos are one);
  the contact Dictionary reused per pair. Queries per pass before/after; the baseline unmoved.
- **S3. The accessors the HUD calls every frame return cached values**: `tanks_by_name`, `team_squads`,
  `team_tanks`, `alive_count`, `is_visible_to` keyed on the tick (invalidated exactly as `_sorted_tanks` is: tick +
  child count + `remove_player`). Hud's per-frame calls then cost a lookup. Document each accessor's cache rule at the
  code site.
- **S4. CP1b: `Units.stat` without a String format per call** (a two-level Dictionary, or a per-unit stat record
  built once; the tuning env read once). Merged EARLY and alone; the orchestrator relays.
- **S5. Shells and impacts:** `Shell` per tick, `Impact` (`game/combat/impact.gd` allocates a `SphereMesh` +
  `StandardMaterial3D` per hit — the visual half is render's: file the request; the sim half is the body/ray per round),
  `_land_rounds` every tick (is there anything to land?), `match/suppression` samples.
- **S6. Per-tick allocations in `Tank` and `Match`:** `_publish_state` (what it builds per tick), `to_local` per
  tick, Dictionaries built to be read once; `Performance.get_monitor(OBJECT_COUNT)` flat over 60 s.
- **S7. The recorder's census tick** (above) — measured, then spread or deferred; the file identical.
- **S8. Physics bodies and shapes**: the census of what Jolt steps each tick in his match; anything static that is a
  rigid body, any shell that could be a ray (ONLY if the baseline proves identical — otherwise leave it and report).
- **S9. CP2 — Law's APC behaves as tracked** (his words above): `law_ifv` locomotion `wheels → tracks` in
  `units.gd`, whatever the tracked turning model implies for a 6.26 m hull (`navigation.md`, the rig's and the Law
  tank's handling as the precedents); frames at his pose (`make remote T=skirmish-shots` with a Law army); the
  sim baseline pre-registered by the path (is `law_ifv` in the 40 s baseline match? name the unit and the second);
  **its own commit, merged ALONE, the baseline recorded twice if it moves.** Last, so every perf commit before it is
  baseline-neutral by the wrapper's line.
- **S10 (stretch).** The arena's collision layout: merged static shapes where Jolt would step fewer; the navmesh
  region count. Measure first; only if `tank/drive` is a visible line.

## How to verify

- `make remote T=check` green on your last commit; `sim-baseline 05df1d55ba49cde1 (baseline unmoved)` from the
  wrapper's line on EVERY perf commit; `make remote T=determinism`.
- `make remote T="sim-profile TIME=60 PROFILE_FLAGS=--no-brains"` before and after each item, same seed, same
  armies (his: Law v Condemned, sumps, seed 92721, the default budget), plus `make remote T=scale-bench`.
- A parity test for S1 (the field's hash after N ticks) and for S3 (accessors return what the walk returns, under
  spawn/death/tick change); mutation-check each (it must fail without the fix).
- `make perf-play` (play's CP1) on the laptop: `tick_script_ms` at 30 and 52 vehicles, with and without
  `--sim-off=visfield`, is the line you report. Your own laptop runs carry a load caveat; the orchestrator's quiet-window
  runs are the record.
- S9: `make remote T=skirmish-shots` with `--player-faction=law`, looked at; the handling tests for tracked hulls.

## Don't touch

`game/ai/**`, `game/tactics/**` (brains: request a shared LOS key in Status + a message), `game/ui/**`,
`game/control/**`, `game/camera/**` (hud), `game/theme/**` (render; `game/theme/fx/bench/**` play), `game/modes/**`,
`game/audio/**`, `mk/fx.mk`, `mk/play.mk` (play), the `[rendering]` keys of `project.godot` (render), `mk/core.mk`,
`game/main.gd` (orchestrator; additive edits in merge notes only).

## Waiting on the lead

Nothing. S9 is decided (his words above).

## Status

_Updated 2026-10-03 ~03:00 by the sim worker. Numbers carry commit, machine, workload, sample._

**REPORT (done):** every backlog item is complete or measured-and-closed; S9/CP2 merged ALONE (`c7d450ee` → main
`f24ced45`); code green at `9c1c65d0` and this report checked at `3e8300b3` (builder0 1883/0, baseline unmoved), merged `f7a9928e`. Merged before that:
`00f43ed3` (S4/CP1b+S1+S2+S3), `5829902c` (S7, S6/S8), `0010bcb4` (fire-RNG fix). The round's sim win in his units:
**the fog field 1.85 → 0.36 ms a tick on the main thread** (builder0) / ~3.4 → 1.2 (laptop); the recorder's census
hitch 3.0 → 1.24 ms once a second; the HUD's accessors and the per-tick sort cached. Open: one intermittent
windowed-only fork on the sumps (below) — round 17.

**Plan (order):** S4 first (CP1b, early and alone) → S1 → S2 → S3 → S5 → S6 → S7 → S8 → S9 (CP2, last, alone) → S10.

**Start:** `8318b9db` builder0 `make check` exited 0, 1856/0, sim-baseline `05df1d55ba49cde1` unmoved.

### Done

- **S4 / CP1b `60f00f7b`: `Units.stat` without a String per call.** Untuned (normal play) `stat()`/`armor()` skip the
  `"unit.key"` lookup; any write to `Units.tuning` (apply_tuning, `TUNE=`, a direct write) takes the keyed path as
  before. Laptop microbench (`tests/scale/stat_bench.gd`, loaded, 200k calls, best of 5): **2.04 → 0.75 µs a call**.
  `tests/test_units_stat_fast.gd` (catalog parity for every unit/key + three tuned paths), mutation-checked.
- **S1 `00b2a2cf`: the visibility field, priced, switched, cheaper; the picture identical.**
  - Switches: `--sim-off=visfield` (play's `no_visfield`), `--sim-off=visfield_thread`, `VisibilityField.enabled`;
    `--visfield` / `--visfield=reference` add Green's field (new / pre-S1) to a headless match, so
    `make sim-profile PROFILE_FLAGS=--visfield` prices it. Sections `visfield`, `visfield/{rays,mark,dispatch,join,finish}`.
  - **Priced** (laptop, load ~8, tree = S1, `sim-profile` Law 27 v Condemned 29, sumps, seed 92721, budget 5200, 30 s,
    899 ticks, brains ON): **pre-S1 field ≈ 3.4 ms a tick; S1 inline 3.07 (rays 0.77, mark 2.14); S1 threaded 1.21 ms
    on the main thread (rays 0.94)**. Brains OFF (tanks stand still, the memo's case): 4.4 → 0.54. Bench
    (`tests/scale/visfield_bench.gd`, laptop loaded): refresh **1.8 → 0.5 ms**, a still viewer **2.9 → 0.03 ms**.
  - What changed: an exact memo for a viewer whose eye and radius are unchanged (world layer static; exact, not
    quantised); marks as row runs filled natively; the refresh is three native blits; the per-cell rule verbatim, its
    marks on a `WorkerThreadPool` thread (native builds with the `threads` feature; **the web build has none and runs
    inline**), joined before every refresh and every `state_at` — the texture (radar, fog visual) changes only in the
    refresh, on the same tick as before. The camera's vision cap does not read the field (`vision_region.gd`: sight discs).
  - **Tried and reverted:** a quadtree that decides whole blocks without `atan2`: LOST in GDScript (3.7 vs 1.9 ms a
    look; ~4 µs of interpreted bookkeeping a node against a star of ~350 shadow spokes at spawn). Documented at the site.
  - `tests/test_match_visfield_parity.gd`: the shipping field beside the pre-S1 copy (`tests/scale/visfield_reference.gd`)
    on sumps and terminus, image + fans every tick, every cell's state every 15 ticks, drivers + standing viewers + a
    death; mutation-checked (block bound, memo key).
- **S2 `3852f906`:** the enemy list once per team per intel pass (was rebuilt inside the viewer loop); `SimProfile.count`
  + `counters_per_tick` (intel/los_queries ≈ 36.6 a tick in his matchup). **An exact LOS memo (key = both eye points)
  was built, proven equal to the ray, and dropped: 0.6 of 36.6 queries a tick hit** — pairs are asked only inside sight
  radius, i.e. while both move. The contact Dictionary is still built per contact (readers may keep a reference;
  reusing it in place would change what they hold). `match/intel` ≈ 0.6–0.9 ms a tick (laptop, loaded) — small.
- **S3 `00f43ed3`:** `tanks_by_name`, `sorted_team_tanks`, `team_tanks` cached on `_sorted_tanks()`'s own list (rebuilt
  exactly when it is); `team_squads` on version + size + tick; `alive_count` without allocation; `is_visible_to`
  without `{}`. Every cached value read-only (a mutating caller errors). `tests/test_match_accessor_cache.gd` against
  the pre-S3 walks under load/ticks/spawn/squad/death/intel/remove_player; mutation-checked. Saves HUD per-frame work
  (hud's `process_game_ui_ms`; play's perf-play measures it).

- **S5 measured, no change:** `shell` 0.016 ms a tick, `match/land_rounds` 0.017 (laptop, his matchup). The brief's
  `Impact` allocation is gone already: `Impact` is a bare Node3D that calls the pooled FX once and frees itself (no
  mesh, no material; ~0.06 a tick) — nothing to file with render. `match/suppression` 0.28 ms at 20 Hz is the per-tank
  sample over an active-cell `ThreatField`: nothing wasted.
- **S6 measured:** `_publish_state` allocates nothing (property writes, 3 µs); `tank/drive` (1.45 ms / 54 hulls,
  laptop loaded) is `move_and_slide` after round 5's CP1 (parked hulls skip it; the basis is set only on a turn) —
  nothing left to cut without touching the physics. **Objects alive** now in every `sim-profile` (`c140b668`): 20 s +7,
  60 s +63 with 16 units destroyed, 60 s with no fighting −259 → growth follows kills (~4 objects each), no per-tick leak.
- **S7 `439963d3`: the recorder's census, 3.0–3.3 → 1.24 ms (worst 6.5 → 2.2)** — once a second, so a hitch gone
  (`tests/scale/recorder_bench.gd`, laptop loaded, his armies at 5200 on sumps, 60 units, 200 censuses). It built
  `Movement.state()` (a ~25-key reading) per unit to keep two fields; now it reads `phase`/`blocked_by` with the
  reading's own rule. Same bytes (`test_match_recorder_census.gd`, five phases, value and JSON; mutation-checked). The
  rest: JSON 0.9 ms, store+flush 0.06, the every-tick task scan 0.01 ms.
- **S8 measured, no change (`c140b668`, `tests/scale/physics_census.gd`):** every shipping arena with his armies holds
  21–74 `StaticBody3D` (24–125 box shapes), 60 `CharacterBody3D`, no rigid bodies, no areas; shells are rays; the
  crowd is MultiMesh. Nothing static is a rigid body; no shell is a body. **S10 closed by the same numbers:** merging
  ≤125 static boxes would not move `tank/drive`, which is the hulls' own `move_and_slide`.
- **S9 / CP2 `c7d450ee`: the Law's Retired APC drives on tracks** (his words). `law_ifv`: wheels → tracks,
  `min_turn_radius_m` 7.5 → 0.0, `lateral_grip` 0.8 → 1.0 (the dozer tank's handling, the one tracked precedent;
  `TankMotion` ignores radius and grip for tracks, the planner and settle radius read the radius). `hull_turn_rate_deg`
  stays 95 (see Questions). `tests/test_units_law_apc_tracked.gd` written first and failing on the old catalog
  (asked to pivot for a second the wheeled APC shuffled 1.41 m and turned 13°; tracked: < 0.3 m, > 45°).
  **Baseline pre-registered UNMOVED by the path** (`law_ifv` is not in the 40 s baseline match: Green artillery,
  gang_tank, scout, syn_scout, tank; Rust gang_scout, ifv, law_tank, syn_scout, tank); laptop (glibc 2.39) hash of that
  match `5f81684d9c38cb45` before and after; builder0's line from check4. Frames: `make remote T=law-apc-shots`
  (a scripted Law skirmish at his window, 8 s and 20 s) — see Checks.

### Repeatability: the same skirmish seed was a different fight (the orchestrator's question, found 2026-10-02/03)

- **Mechanism 1, FIXED `0010bcb4`: the skirmish's fire RNG was unseeded.** `Match._fire_rng` (shot spread, lobbed
  scatter) was seeded only by `seed_spawns()`, which only the match runner calls; a skirmish kept
  `RandomNumberGenerator.new()`'s random seed. Witness (laptop, headless, `--skirmish --scripted --seed=3
  --budget=6500 --arena=sumps`, a state hash every tick): three runs agreed in every hashed field to tick 253 and forked
  at the match's first round (Green_Alpha_1's shell left in a different direction from the same muzzle and turret yaw;
  Rust_Hunters_3 dodged in one run and not the other). The same at `8318b9db` (pre-S1) and with `--sim-off=visfield`:
  older than the round, not the field. Now seeded in `Match._ready` from the launch `--seed` with the value
  `seed_spawns` gives it (which still overrides it identically): three headless runs identical to tick 900;
  `test_match_fire_rng_seeded.gd`, mutation-checked; baseline pre-registered UNMOVED (the runner seeds explicitly).
- **Mechanism 2, OPEN and INTERMITTENT (windowed only, sumps only) — a ROUND-17 ITEM:** builder0 windowed pairs
  (`make windowed-repeat`): at `0010bcb4` terminus identical to tick 870 but **sumps forked at tick 630**; at `9c1c65d0`
  a sumps pair with a per-unit dump from tick 560 (`REPEAT_EVERY=1 REPEAT_UNTIL=640 REPEAT_FLAGS=--hash-detail-from=560`)
  was **identical** through 640 (3 872/3 872 lines). Headless sumps: three runs identical to 900. So one windowed pair
  in two forked, late, on the map with water and swing bridges (render's theme side). Nothing on the decision path
  reads frame time, frame count or the wall clock (grep of game/ai, tactics, control, match, tank, combat, units,
  arena: every `Time.get_ticks_*` is profiling; nothing in `game/arena` reads the camera or a frame time);
  `--scripted`'s orders are `create_timer`s in idle frames, deterministic under `--fixed-fps`. Next step for whoever
  takes it: repeat sumps pairs with `--hash-detail-from=560 REPEAT_UNTIL=700` until one forks, then the first
  `SIM_HASH_DETAIL` line that differs names the unit and the field (command vs position vs a shell). A further pair at
  `9c1c65d0` to tick 900 **forked at tick 630 again** (sampled every 30: the fork is in ticks 601–630). So 2 of 3
  windowed sumps pairs fork at the same sampled tick, and the one that did not was the pair hashing AND dumping every
  tick from 560 — the printing changes the frame pacing, which points at a **timing-dependent input on the windowed
  path** (vsync'd frames on builder0 crawl at ~1/10 real time), not at a seeded RNG. Next: dump every 5 ticks from 600
  (less perturbation), or bisect by switching off windowed-only layers (`--sim-off=visfield` already excluded headless;
  try the airship, the cutaway, the swing bridges' theme side).
  Until it is found, a windowed A/B on the sumps is two fights (play is told).
- **The witness** (for `determinism.md`, the orchestrator folds it in): *`--hash-every=N --hash-until=T` makes any
  mode print `SIM_HASH tick=<t> <state_hash>` every N ticks and quit at T; `--hash-detail-from=T0` adds every unit's
  hashed fields, velocity, command and intent and every shell, full bits. `make windowed-repeat ARENA=… REPEAT_FLAGS=…`
  runs a windowed `--scripted` skirmish twice and prints the first tick the hashes differ. A `--scripted` run has no
  recorder, so this is the witness for "is a windowed A/B one fight or two". Determinism is per mode: `make
  determinism` and the baseline run the match runner, which seeds every RNG; a mode that skips `seed_spawns` was
  never covered (mechanism 1).*
- **Web build, not mine, reported and fixed on main:** `web-smoke`/`garage-web-smoke` failed at `5829902c` —
  `export_presets.cfg` excluded `game/theme/factions/*` while `tank.gd` has called `FactionArt` since 2026-09-22.

**Where the tick goes (laptop, loaded, S1 tree, sim-profile his matchup, brains on):** controllers segment (brains)
32.5 ms; `tank` 2.27 (drive 1.45, publish_state 0.16); `match` 1.26 (intel 0.62, suppression 0.28, resupply… 0.20);
the field (skirmish only) 1.21 after S1.

### Checks
- `8318b9db` (start): builder0 check exited 0, 1856/0, baseline unmoved.
- `00f43ed3` (S4+S1+S2+S3): builder0 check exited 0, **1864/0**, sim-baseline `05df1d55ba49cde1` unmoved, determinism
  `762a0576f944f5b7` (1 NOT JUDGED = `scenario_perf` refusing under load, as at the start). Merged by the orchestrator.
- `5829902c` (+ main/CP1, S7, S6/S8): check exited 0, **1878/0**, baseline unmoved, determinism `762a0576f944f5b7`.
  `command-playtest` exited 0, no script errors (both squads framed: 0.13 s, 0.03 s). `web-smoke`/`garage-web-smoke`
  failed for the pre-existing export filter (above), not this branch.
- `0010bcb4` (witness + fire-RNG fix): check3 RUNNING; windowed-repeat terminus none / sumps tick 630 (above).
- `0010bcb4`: check exited 0, **1880/0**, baseline unmoved, determinism `762a0576f944f5b7`. Merged.
- `9c1c65d0` (S9 + S3b): check exited 0, **1883/0**, baseline `05df1d55ba49cde1` **unmoved on builder0 too** (S9
  pre-registered unmoved), determinism `762a0576f944f5b7`. Merged: `c7d450ee` alone (`f24ced45`), then `f7a9928e`.
- `make remote T=law-apc-shots` (builder0, 1854×1011, a scripted Law army on the sumps, 8 s and 20 s; looked at):
  the Law army renders and fights normally; the scripted camera follows group 1 (the rocket battery), so the APC is
  not clearly in frame — handling is not judgeable from a still. The test proves the pivot; the feel is his playtest.
- **The field priced on builder0** (`9c1c65d0`/`75e4fd0f`, `sim-profile` his matchup, 60 s, brains on, 1800 ticks;
  a shared box, so each arm against its own run's `tank` line): none — ; pre-S1 ≈ 1.85 ms/tick (1.17× tank);
  S1 inline 1.87 (rays 0.58, mark 1.23; 1.04×); **S1 threaded (default) 0.36 (rays 0.32; 0.40×)**.

- **S3b `9c1c65d0`:** brains' script profile of his path (`dd63e277`) counted 354 sort-comparator calls a frame in
  `_sorted_tanks` — one full sort of ~56 tanks per tick on a one-tick-a-frame path, not a cache miss. The tick rule is
  unchanged; a re-validation that finds the same tanks keeps the sorted list (and its identity, so S3's caches hold
  across ticks). `team_frame` returns one of two read-only constants. The profiler rerun on main is the orchestrator's
  (brains' `ai-script-profile-play`).

### What to playtest (the lead)
- `make skirmish`, a **Law** army (`--player-faction=law`): order the APC squad (Retired APC) to turn in place; it
  should pivot like the Condemned dozer, not shuffle. If it spins too eagerly: `units.gd` `law_ifv.hull_turn_rate_deg`.
- The fog of war and the radar should look exactly as before (the parity test says identical, tick for tick).

### Next steps (round 17)
- The windowed-only sumps fork (above), with the witness already built.
- If the laptop's quiet-window `perf-play` arm `--sim-off=visfield_thread` shows the worker thread contending on his
  4 cores, flip `VisibilityField.threaded` off (the arm is the switch).
- The field's rays (0.32 ms/tick builder0) are the field's remaining main-thread cost; an exact skip (rays whose
  segment no static box can touch) is possible but needs an occupancy structure — measure first.

### Requests to other streams
- play: `--sim-off=visfield` kept; `--sim-off=visfield_thread` is the second arm (told by message).
- brains: the exact LOS memo does not pay in intel (above); `Match.line_of_sight` exists as the counted entry point.
  The read-only caches mean a brain that mutated `tanks_by_name()`'s Dictionary would now error — none found.

### Questions for the lead
- S9: the Retired APC on tracks keeps its 95°/s turn rate, now as a pivot from a standstill (the Condemned dozer
  pivots at 80°/s). Play it in a Law army; if it spins too eagerly for a 6.26 m hull, the number is
  `units.gd` `law_ifv.hull_turn_rate_deg`.

### Merge notes
- `game/match/match.gd` `_ready`: reads `--visfield` (profiling only). `tests/scale/visfield_reference.gd` is a
  verbatim copy of the pre-S1 field: never edit it.
