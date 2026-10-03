# Stream: hud (the main thread's per-frame scripts: HUD, tactical map, controls, camera — redraw what changed)

> Read `_agents/orchestration.md` (the worker contract), `_agents/tactical_map.md`, `_agents/legibility.md`,
> `_agents/streams/references/fx_tricks.md` *The budget* (the Control (HUD) rule), `_agents/verification.md` (*Timing in
> tests*, rule 3), `_agents/workstreams.md` *Round 16*. You own `game/ui/**` EXCEPT `game/ui/faction_picker.gd`,
> `game/ui/loading_screen.gd` and `game/ui/widgets/title/**` (play's this round), `game/control/**`, `game/camera/**`,
> `tests/test_ui*.gd`, `tests/test_hud*.gd`, `tests/test_control*.gd`, `tests/test_camera*.gd`,
> `tests/test_tactical*.gd`, `tests/support/control_fixture.gd`, `mk/command.mk`. Contracts C16.1–C16.6. **The rule:
> every pixel the HUD draws and every order it issues is unchanged (C16.1, C16.6) — the work is drawing it only when
> it changed, and asking the match for what it already knows.**

## The lead's direction (2026-10-02)

> *"the game is getting extremely choppy … it's likely that we just haven't done the work latley to optimize our code to
> just find basic efficiencies we can gain across the codebase - before sacrificing any of the existing graphics or
> gameplay let's find (or profile our code) where we can just get better performance out of our application"*

He plays `make skirmish` natively on his laptop (Intel UHD 620, 1854×1011), default armies, choppy from the first
second.

## Where things stand (measured today, 2026-10-02, at `1efa9940`, his laptop)

- `process_game_ui_ms` is **2.5–3.3 ms a frame** at 19–52 vehicles (`streams/references/perf/r16-before-1080-his-flags.json`)
  against the budget of **≤ 1.5 ms** for game + UI `_process` (`fx_tricks.md` *The budget*; the Control (HUD) rule:
  "panels that don't change don't redraw; per-unit widgets are pooled or batched"). `cpu_render_ms` 1.5–2.0 ms with
  the HUD ~82 of 280–440 draw calls (budget: HUD ≤ 130, met). **And the bench runs `--player=cpu --cinematic`: the
  player's own control layer (`RtsControls`, `TacticalMap`, `SelectionPanel`, `GroupBar`, selection markers, unit bars,
  the camera readout) may not even be in that 3 ms** — play's `make perf-play` (CP1) runs the skirmish as he plays it;
  until it lands, `make hud-cost` (`game/ui/hud_cost_probe.gd`, per-widget draws and `_process` cost in a 30-a-side
  skirmish, needs a display) is your instrument. Take its before on day one.
- **What the survey found running every frame, whether or not anything changed** (hypotheses: measure each with
  `hud-cost` or a probe before and after):
  - `game/ui/tactical_map.gd:97-111`: `_apply_fog_of_war()` — two full loops over all tanks,
    `game_match.sorted_team_tanks()` (allocates), a `MatchAnnouncer.short_name(String(tank.name))` string per tank per
    frame (`:127`); then `queue_redraw()` AND `_refresh_panels()` every frame.
  - `tactical_map.gd:1108-1148` `_refresh_panels`: a linear `_squad()` scan over `team_squads()` (which sorts its keys
    per call, sim's), `squad.alive_members(game_match.tanks_by_name())` (a fresh Dictionary of every tank per frame),
    three `%` formats, `String(id).split(":")` per button per frame.
  - `tactical_map.gd:561-660` `_draw`: every contact, every squad × roster member, each unprojected and drawn;
    `draw_string` per commander per frame.
  - `game/control/rts_controls.gd:174-212`: `_acks` rebuilt via `.filter()` with a lambda, `selection.prune`,
    `groups.prune`, `_update_compliance`, `_note_legibility`, `awareness.update`, **a second `_apply_fog_of_war()`
    over all tanks** (the tactical map does the same loop), then `queue_redraw()` + `_overlay.queue_redraw()`.
  - `game/ui/selection_markers.gd:59-130` `refresh()` per frame over all tanks: `Units.stat(tank.unit_id,
    "hull_size")` (a String format per call — sim's CP1b replaces it; until then cache per tank in your file),
    `Shown.ground(tank)`, a MultiMesh rebuild.
  - `game/ui/unit_bars.gd:44-104`: `queue_redraw()` every frame; `_draw` loops all tanks with `is_visible_to`
    (allocating, sim's S3 caches it), `unproject_position`, `Units.stat`, 4 `draw_rect`s per bar.
  - `game/ui/hud.gd:67-86`: the scoreboard string rebuilt every frame (two `alive_count()` walks, `repeat`s, four
    `%` formats) even when nothing changed.
  - `game/ui/group_bar.gd:34-37` + `summary()`: `_layout()` + `queue_redraw()` per frame; `get_node_or_null(NodePath(
    unit_name))` per group member per frame.
  - `game/ui/selection_panel.gd:70-77` (657 lines): `_layout()` + `queue_redraw()` every frame, unconditionally.
  - Unconditional `queue_redraw()` every frame in `radar.gd:229-238`, `edge_markers.gd:42-44`, `camera_readout.gd:56-58`;
    **`widgets/conductors.gd:35-39` throttles with `REDRAW_SECONDS` — the pattern the others should copy, or better, a
    dirty flag set by the state that changed.**
  - `widgets/hud_skin.gd:128-140`: `get_viewport_rect()`, `FxQuality.tier_name().to_upper()`, `FrameTarget.label()`
    compares, `_fit_status_frame`, `_fit_banner_frame`, `_place_messages` every frame.
  - `game/camera/rts_camera.gd:261-335`: `_update_vision` (throttled by `VISION_CAP_EVERY`), `_update_tracking`,
    `_update_yaw_follow`, 8 `Input.is_key_pressed`, `DisplayServer.window_is_focused()`, `_apply()`;
    `_occluders()` uses `get_tree().get_nodes_in_group(OCCLUDER_GROUP)` per call.
  - `game/camera/block_cutaway.gd:86-116`: every frame loops every city-block solid and every part toggling `visible`;
    `find_child("Obstacles", true, false)` on the fallback path.
- The two fog-of-war loops (tactical map, controls) are the same walk twice; one owner, one result, both consumers.
- `queue_redraw` call sites: 37, all in your paths.

## Backlog (in order)

Every item: the probe FIRST (`hud-cost` per widget: draws, `_process` µs; a counter of redraws per second per widget),
the change, `make control-playtest`, `make command-playtest`, the shots compared (`make look-parity` is render's R1 —
use it once merged; until then your own before/after shots at desktop and phone, diffed), `make remote T=check`,
the number again; commit with both numbers, their commit, machine, workload, sample.

- **H1. The before, per widget.** `make hud-cost` on the laptop (say when a window is coming) and on builder0; a
  redraw counter per widget per second in a 60 s skirmish (how many of the 1 800 frames each widget redrew, and how
  many of those changed a pixel: hash the drawn commands or the control's texture at low rate). The table in Status
  orders H2–H8.
- **H2. One fog-of-war walk per frame, shared.** `RtsControls` and `TacticalMap` consume one computed visibility set
  (your `ElementAwareness` or a small `FogOfWar` service in `game/control`), built once per frame or per intel tick (the
  intel changes on `INTEL_EVERY_TICKS`, sim's — the set cannot change between intel ticks: cache on the tick).
- **H3. Redraw on change, not on time:** a dirty flag per widget set by the state it draws (selection changed, a
  squad's roster or health changed, the camera moved, a tick passed for the things that move), `queue_redraw()` only
  then. Start with the scoreboard (`hud.gd`), `selection_panel`, `group_bar`, `hud_skin`'s fits, the camera readout;
  then the per-frame ones that genuinely move every frame (`unit_bars`, `selection_markers`, `radar`, `edge_markers`,
  the tactical map's `_draw`) get their per-tank work cut instead (H4).
- **H4. Per-tank per-frame work without allocation:** no `String(tank.name)` per frame (cache the name on the tank's
  entry), no `NodePath` per member per frame (hold the node), no `Units.stat` per frame (sim's CP1b; until then a
  per-unit cache in your file), no `.filter()`/`.split()` on hot paths; the accessors sim caches in S3 (`tanks_by_name`,
  `team_squads`, `alive_count`, `is_visible_to`) called once per frame per consumer at most.
- **H5. The tactical map's `_draw`:** unproject once per tank per frame and share with `unit_bars` and the markers (one
  screen-position table per frame, built by whichever runs first in the process order); `draw_string` only when the
  text or position changed (a cached `TextLine`/label).
- **H6. The camera:** `_occluders()` without `get_nodes_in_group` per call (the group changes only when the airship or
  a solid enters/leaves: cache and invalidate on `tree_entered/exited`), `block_cutaway`'s loops only when the camera
  moved more than a threshold or a solid changed (a dirty flag; render may ask for it too), the 8 key reads once.
- **H7. `cpu_render_ms` and the HUD's draws:** the ~82 HUD draws by widget from the census (render's R7 files the
  request to you): panels that could be one draw, fonts switched per label.
- **H8 (stretch).** The selection panel's 657 lines of layout per frame: lay out on change only; the tactical map's
  panels likewise.

## How to verify

- `make remote T=check` green on your last commit (the sim baseline cannot move from your paths: if the wrapper's line
  says it did, stop and tell the orchestrator); `make control-playtest` (every order's response tick unchanged),
  `make command-playtest`, `make remote T=control-playtest-shots`, `make remote T=command-playtest-shots`; `make
  control-timing` on a quiet builder0 (judged, not in check); `make response-test` on the laptop once (needs a display).
- `make hud-cost` before/after per item; `process_game_ui_ms` from play's `make perf-play` (CP1) on the laptop at 30
  and 52 vehicles is the line you report (the orchestrator's quiet-window run is the record).
- Shots at desktop and phone aspect before and after, diffed (`make look-parity` once render merges it); the
  garage tour (`make garage-tour`) if `hud_skin` or any shared widget is touched.

## Don't touch

`game/ai/**`, `game/tactics/**` (brains), `game/match/**`, `game/tank/**`, `game/combat/**`, `game/arena/**`,
`game/units/**` (sim; request the cached accessors in Status + a message, adapt in your paths meanwhile),
`game/theme/**` (render; `game/theme/fx/bench/**` play), `game/ui/faction_picker.gd`, `game/ui/loading_screen.gd`,
`game/ui/widgets/title/**`, `game/modes/**`, `game/audio/**`, `mk/fx.mk`, `mk/play.mk` (play), `project.godot`,
`mk/core.mk`, `game/main.gd` (orchestrator; additive edits in merge notes only).

## Waiting on the lead

Nothing. No lead gate in this stream.

## Status

_Updated 2026-10-02 evening (worker, session 1)._

### Plan (ordered; smallest foundation first)

1. **H1 instrument**: `HudClock` (`game/ui/hud_clock.gd`): a static begin/end counter wrapped around every HUD
   per-frame entry point (`_process`, `_draw`, the overlay draw), off by default (one static call + a bool when off);
   `make hud-profile` (headless, his window 1854×1011, his recorded seed 92721, default armies, `--player=cpu` so the
   fight runs, `--camera-readout=on` as `make skirmish` passes it) reads µs and calls per frame per widget over 60 s.
   **Decision:** counters, not removal — `hud-cost`'s hide-one-widget phases are 8 frames each and paused; a counter
   attributes inside one run (C16.3). "Did a redraw change a pixel" is answered by H3's dirty flags
   (`HudClock.changed(key)` counts state changes), not by hashing textures (no API exposes a CanvasItem's commands).
2. H2: the fog-of-war walk cached on the intel tick.
3. H3: dirty flags (scoreboard, selection panel, group bar, hud_skin fits, camera readout).
4. H4: per-tank per-frame work without allocation.
5. H5: one unproject table per frame.
6. H6: camera group cache, cutaway gating, key reads.
7. H7: HUD draw calls by widget.
8. H8 (stretch): selection panel / map panels laid out on change.

### Done so far (commits on `stream/hud`; numbers carry commit, machine, workload, sample)

**Instrument (H1, `a75be098`):** `HudClock` + `make hud-profile` (headless, 1854×1011, `--skirmish --player=cpu
--enemy=cpu --seed=3 --budget=6500` = 68 vehicles at start, the player's desktop HUD live, 60 s by default). Each widget's
`_process`/`_draw` µs and calls per frame, sub-timers inside the heavy ones, redraws vs state changes, and (since
`5a54e5c8`) every cost also in **reference-workload units** (`HudClock.reference_work` = control_fixture's yardstick,
timed beside the HUD each frame), which cancels machine load. The "before" is branch `hud-before-probe` (= `8318b9db` +
the counter only, NOT for merge).

**Before → after, one machine, back to back, reference units per frame** (laptop, heavily loaded by other streams:
6–9 fps; `hud-before-probe` vs `5a54e5c8`, 30 s each, 68 vehicles; the after side includes sim's merged CP1b/S1–S3
caches, so not all of the drop is hud's):

| widget | before | after |
|---|---|---|
| **HUD total** | **71.4** | **36.5** (−49 %) |
| controls.process | 14.2 | 7.3 |
| radar.draw | 13.3 | 3.2 |
| controls.draw | 11.3 | 4.7 |
| rts_camera.process | 7.9 | 5.9 |
| selection_panel.draw | 6.6 (every frame) | 0.0 (redraws on 0–7 % of frames) |
| selection_markers.process | 5.3 | 4.0 |
| group_bar.draw | 3.4 (every frame) | 0.2 (8–31 % of frames) |
| camera_readout.draw | 1.0 (every frame) | 0.0 (on change) |

builder0 absolute (`make remote T=hud-profile`, 60 s, 1 800 frames, 68→28 vehicles): before **3.34 ms** of HUD script a
frame at `hud-before-probe`; an after run at `c26a3f17` read 3.96 ms but builder0 was loaded (untouched widgets read
1.7× slower in it; 24 fps vs 30) — not comparable; the quiet-window record is the orchestrator's (`remote-quiet` or
`perf-play`).

**What changed (each exact: same pixels, same orders; equivalence tests named):**
- H3 redraw on change: `SelectionPanel` (signature of everything `_draw` reads; the summary computed once a frame),
  `GroupBar`, `CameraReadout`; the radar's static backdrop (frame, fog texture, outline, every obstacle) is a
  `show_behind_parent` child redrawn on change (same draw order as one `_draw`).
- H4 per-unit work: the callouts and the legibility line read the mover's `phase`/`stalled_ticks`/`legibility()`
  directly instead of building `Movement.reading()` (corridor, clearance, merged contact…) per unit per frame
  (`test_the_quick_callout_says_what_the_full_reading_says`, 240 unit-steps incl. YIELDING/BLOCKED); the radar's marks
  in one pass without a Dictionary per blip (`test_control_radar_marks`, 24 passes, 327 contact marks, both bases);
  `Radar._flip` without building `team_frame`'s Dictionary per drawn point; awareness and `vision_state` read positions
  once (not once per pair), awareness resolves members from its own walk; `VisionRegion` stores discs packed
  (`contains` equivalence over 4 000 points incl. the rim); `vision_state` computes the commanded units once; hull
  sizes cached per unit type in markers/bars/radar; markers read the interpolated transform once.
- H6: `BlockCutaway` passes only when the camera pose or the solids changed (0.6 ref units a frame on sumps before).
- The profile closes the planning intro tooltip as his first click does (`SelectionPanel.dismiss_intro`); with it
  open, its animated preview redraws the panel every frame — true in his game too, until his first click.

### Levers that would change what is drawn (C16.1: priced here, NOT built, OFF)

Measured shares, reference units a frame at `4a4a9ec7`, laptop, 68 vehicles (`la2.json`; total ~33):

| lever | what it touches | what it would change on screen | est. saving |
|---|---|---|---|
| L1. Element readouts at the intel rate (10 Hz) instead of every frame | `ElementAwareness.update` 3.3, `_update_compliance` 1.0, `_note_legibility` 1.0 | group-bar state words, edge chips, radar element labels, "under fire"/"contact" alerts and NOT FIRING/legibility lines would appear up to 100 ms later | ~3.5 |
| L2. The selection card's data at 10 Hz (input still immediate) | `SelectionPanel.summary` + signature ~4.0, `GroupBar.summary` 1.5 | the card's hull/shield bars and order words, the chips' health bars, up to 100 ms late | ~3.5 |
| L3. One hull bar per unit (drop the controls' older `_draw_health` where UnitBars already draws) | `ctl.d.health` 0.7 | a hurt friendly loses its second bar (see Findings) | ~0.7 |
| L4. Radar blips at 15 Hz | `radar.blips` 2.6 | the radar's dots step at 15 Hz instead of moving every frame | ~1.3 |

Not built: each is a look change, and together they would buy ~9 of ~33 units, not the ~2.5× the budget still needs
(see *What is left*). If the lead wants any, each is a flag in one file.

### Findings

- **The "two fog-of-war walks" are never in the same frame.** `TacticalMap` (round 2's touch map: `--touch-map`,
  `--command-playtest`) and `RtsControls` (desktop, his path) are built by mutually exclusive branches of
  `skirmish_mode.gd` (`_start_touch_map` / `_start_desktop_controls`), both named `TacticalMap`. On his path there is
  one walk a frame (`RtsControls._apply_fog_of_war`); H2 becomes "that walk only when the intel changed".
- **At his target a tick is a frame.** `SimClock.TICK_RATE` is 30 and the budget is a locked 30, so state that changes
  per tick changes every frame there: "redraw on change" pays only for what is static or input-driven (panel, group
  bar, readout, radar backdrop, cutaway). Everything that follows units must get cheaper per unit, which is where the
  remaining cost is (awareness's friendly × enemy loop, vision, markers, bars, callouts).
- **`UnitBars._top_of` has always floated every bar at 2.0 m + 1.2 m**: it reads `hull_size` as a `Vector3`, but the
  catalogue gives `[w, h, l]`, so `size is Vector3` is never true. Kept exactly (C16.1: no pixel changes); a fix
  (bars at each hull's own height) is a look change → a question for the lead below.
- **H5 (one unproject table) is not exact as briefed:** the three per-unit projections are of DIFFERENT points —
  `UnitBars` projects the physics `global_position` + 3.2 m (the bug above), the controls' health bars
  `Shown.at` (interpolated) + hull height + 0.9 m (and a second point for the width), the callouts `Shown.at` + hull
  height + 2.0 m — so a shared table would move pixels (C16.1). The only shareable read is the interpolated transform,
  one native call per tank per widget; not worth a cross-widget cache keyed by frame (a test that moves a tank and
  draws in the same frame would read it stale). **Also found: a hurt friendly unit gets TWO hull bars** — UnitBars'
  (round 11, over every visible unit) and the controls' own `_draw_health` (older, ours: hurt or selected) at a
  slightly different height. Kept (C16.1); a question for the lead below.
- **Play's CP1 confirms the scale** (`perf-play`, his laptop, ~40 vehicles, loaded): game+UI `_process` 10–14 ms with
  the player's layer live, against perf-scene's 2.6 ms without it.
