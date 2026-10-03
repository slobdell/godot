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

(the worker keeps this current: plan, done with numbers, decisions, questions for the lead, requests to other streams,
known issues, what to playtest, next steps, merge notes, the green hash; CP1b and CP2 announced to the orchestrator by
message, not only here)
