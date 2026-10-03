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

### Findings

- **The "two fog-of-war walks" are never in the same frame.** `TacticalMap` (round 2's touch map: `--touch-map`,
  `--command-playtest`) and `RtsControls` (desktop, his path) are built by mutually exclusive branches of
  `skirmish_mode.gd` (`_start_touch_map` / `_start_desktop_controls`), both named `TacticalMap`. On his path there is
  one walk a frame (`RtsControls._apply_fog_of_war`); H2 becomes "that walk only when the intel changed".
