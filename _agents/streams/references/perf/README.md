# The labelled `perf-scene` baselines

Each file is a `make perf-scene` run kept on purpose, so a later run can be compared against the same scene rather
than against a number in a commit message. They are all `--skirmish --player=cpu --enemy=cpu --seed=3 --budget=6500
--cinematic` (34 a side at the start, dropping as vehicles die), tier **high**, on **the lead's laptop** — Mesa Intel
UHD 620 (WHL GT2), shared with the other agents' work, so CPU numbers are pessimistic and GPU numbers are the GPU's.
**Read the machine factor in `../fx_tricks.md` before quoting any of these against a builder0 number: the laptop is
~2.75× slower for identical headless work.**

Shape of a file: `{"phases": [...one entry per measured phase...], "summary": {...}}`. Reproduce any of them with
`PERF_RES=<res> PERF_NAME=<name> make perf-scene` plus the flags below, then compare `summary`.

| File | What it is | Taken at | Headline |
|---|---|---|---|
| `baseline-60hz-preinterp.json` | 720p, **60 Hz simulation, before physics interpolation** — the "old world" reference | `47e3efa1` | avg 46.61, p95 63.15, GPU 9.86 |
| `baseline-60hz-preinterp-1080.json` | the same run at the laptop's native 1080p | `47e3efa1` | avg 57.74, p95 66.48, GPU 13.88 |
| `hz30-720.json` | 720p **after the 30 Hz tick + interpolation**, uncapped | `9b07d107` | avg 29.27, p95 42.08, GPU 8.93; holds 60 fps at 14, locked 30 at 18 |
| `hz30-1080.json` | the same at 1080p, uncapped | `9b07d107` | avg 39.0, p95 48.26, GPU 14.85; holds 60 fps at 8, locked 30 at 12 |
| `hz30-locked30-1080.json` | `FrameTarget.LOCKED_30` (the default) at 1080p, 30 Hz era | `9b07d107` | avg 41.35, p95 47.41, GPU 14.17 — **above the 33 ms cap: it did not hold at these counts** |
| `hz30-perf60-720.json` | `FrameTarget.PERFORMANCE_60` (~720 lines), uncapped | `9b07d107` | avg 27.04, p95 34.05, GPU 8.91; locked 30 at 13 |
| `locked30-capped-60hz-1080.json` | **before 30 Hz**: capped at 30 at 1080p on the 60 Hz simulation | `15e048d8` | avg 106.05, p99 94–144 at 36–64 vehicles — the 60 Hz spiral; the line the 30 Hz work had to clear |
| `r16-before-720-cinematic.json` | **Round 16's before**, round 5's scene (720p, `--cinematic --mute`, uncapped), taken by the orchestrator with one other agent's shell commands running | `1efa9940` | all avg 40.66, p95 51.1, **GPU 12.1 flat at every count** (was 8.5–9.6 after round 5); holds 60 at 12, locked 30 at 23; at 32 vehicles avg 29, `tick_script_ms` 22.4, ticks/frame 1.03; at 66 avg 100, tick 38.9, 3.3 ticks/frame — the round-5 numbers again |
| `r16-before-1080-his-flags.json` | **Round 16's before at HIS window and flags**: 1854×1011 (the window maximised), `--announcer=voice --music=on --camera-readout=on`, unmuted, `--player=cpu --cinematic` (the player's own layer may not be in it: play's `make perf-play` is the run that has it), uncapped | `1efa9940` | all avg 46.5, p95 56.0, **GPU 19.1** (layers: arena 3.9, glow 3.3, effects 3.1, pool lights 1.5, shadows 0.6; ~8–9 ms base unattributed); holds 60 at none, locked 30 at **10**; at 30 vehicles avg 36.9, tick 24.0, ui 2.6, fx 1.0, cpu render 1.6; at 52 avg 100.6, tick 35.2, 3.55 ticks/frame |
| `r16-play-laptop-loaded-{92721,31337}[-capped].json` | **Round 16, `make perf-play` (CP1): HIS path** — human-side skirmish, Law v Condemned on the Sumps, his flags and window 1854×1011, the controls/fog field/booth/music/recorder live, his camera on group 1 (21°, 70 m); two seeds × uncapped/capped; layers `no_visfield,no_controls,no_audio,no_recorder`. **Frame times are WALL CLOCK** (see below). Laptop SHARED: load ~8, 4–10 other Godot processes from other streams | `67f072cc`+ (play branch, pre-merge) | **saturated in every arm: 163–174 ms real frames, the battle at 0.59–0.64× speed, 3.4–3.5 ticks a frame, 100 % of frames over the 34 ms line**; tick 45–48 ms a tick (loaded; the quiet before-run read 24), GPU 17.7–22.5, game+UI 10–14 ms, FX ~1.0, 40–42 vehicles averaged over the run. Layer costs at this saturation are ±15 ms noise on the frame; read the `tick`/`ui` columns. The quiet-window rerun is the orchestrator's |
| `feel-r6-venue-1080.json` | **Round 6, the arena the player can now see**: control's low camera (default pitch, FOV 60) over 30 a side, with feel's round-6 venue (6,005 figures on four sides of stands), night sky and city skyline; layers `no_crowd,no_venue,no_sky` | `cf6b079a`, laptop shared with other agents' runs, one run of 2 cycles (plus a first run of `no_venue,no_sky`: venue 4.44, sky 0.63) | GPU 18.45; **venue 3.54 GPU (crowd 1.05, stands/gates/screens ~2.5), sky + skyline 0.45**; frame avg 50 ms but it tracks vehicle count (100 ms at 67, 25 ms at 23): CPU-bound. **Not comparable to the rows above**: the camera changed at control's merge |

A caveat on reading **these seven**: they predate the summary carrying it, so the file itself does not say whether the
run was capped — the table above is the record. Runs taken from `f6a0dd40` onwards carry `"capped"` and
`"frame_target"` in their summary, so a new baseline says for itself.

**The trap in the capped runs:** `holds_60fps_at_vehicles` / `holds_30fps_at_vehicles` are 0 in
`hz30-locked30-1080.json` and `locked30-capped-60hz-1080.json`, and that does **not** mean the machine held nothing.
With `--perf-capped` the frame time is pinned at the cap (~33 ms), so the capacity test — "is the median frame under
1000/fps + 1 ms?" — can never pass for 60 and is right at the line for 30. **Capacity comes from uncapped runs; capped
runs answer a different question: does the locked rate hold, i.e. is `avg_ms` at the cap with a p95 that isn't much
worse?**

How the capacity numbers are computed, for reading them honestly (`game/theme/fx/bench/perf_scene.gd`,
`holds_fps_at`): the `all` phases are grouped by vehicle count, and the count is "held" while the **median** of its
frame times stays under `1000/fps + FPS_TOLERANCE_MS` (1.0 ms); it walks counts upward and stops at the first that
fails. **60 fps is judged on `avg_ms`, locked 30 on `p99_ms`** — a locked frame rate is about the worst frames, not
the average one, which is also why the same run can report 30 fps holding at more vehicles than 60 fps does.


**Round 16: wall clock, not `delta` (play, `67f072cc`).** Above `max_physics_steps_per_frame` (3) ticks a frame, Godot
hands `_process` the game time it simulated, not the time the frame took: a saturated frame read ~100 ms whatever it
really cost. `perf_scene.gd` now samples the wall clock between its own `_process` calls (`avg_ms`, `p95_ms`, `p99_ms`,
`max_ms`, hitches) and keeps `delta` as `game_ms` beside it, with `game_speed` = game ÷ wall (1.0 real time; 0.6 = the
battle in slow motion). **Every file above taken before `67f072cc` reads `delta`: identical below saturation, but a
phase at ≥ 3 ticks a frame (e.g. `r16-before-1080-his-flags.json` at 52 vehicles: "100 ms, 3.5 ticks") was really
longer** — tick × ticks + the rest, ~170 ms on the loaded laptop. Read `tools/perf_play_report.py <files>` for a table
of any perf-scene or perf-play files (`over34` = share of frames over the locked-30 line; `speed` = `game_speed`).
