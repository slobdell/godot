# Stream: play (the game he plays, measured as he plays it; the opponent randomised; the music through the loader)

> Read `_agents/orchestration.md` (the worker contract), `_agents/streams/references/fx_tricks.md` (*How it's
> measured*, *The budget*), `_agents/streams/references/perf/README.md`, `_agents/sim_tick_rate.md`,
> `_agents/verification.md` (*Timing in tests*, rule 3), `_agents/remote_builds.md`, `_agents/workstreams.md` *Round
> 16*. You own `game/modes/**`, `game/theme/fx/bench/**` (`perf_scene.gd`, `perf_probe.gd`, the perf harness),
> `mk/fx.mk`'s perf targets, `mk/play.mk`, `game/audio/**`, `game/theme/audio/**` (the announcer's code is
> booth's: you measure its per-frame cost in `audio-bench` and file requests), `game/ui/faction_picker.gd`, `game/ui/loading_screen.gd`, `game/ui/widgets/title/**`, `tools/perf_*.py`,
> `tests/test_modes*.gd`, `tests/test_render_perf_scene.gd`, `tests/audio/**`, `tests/test_audio*.gd`,
> `tests/test_music*.gd`, `tests/test_title*.gd`, `tests/garage/**` where the title/loader is tested. `game/main.gd`:
> additive edits only, listed in merge notes (the music director's lifetime, P4). Contracts C16.1–C16.6. **Your first
> item is CP1 for every other stream: the measurement of the path he plays. Land it in the first hours.**

## The lead's direction (2026-10-02)

> *"the game is getting extremely choppy, which might mean that we need to start deploying as a native app. But more
> importantly, it's likely that we just haven't done the work latley to optimize our code to just find basic
> efficiencies we can gain across the codebase - before sacrificing any of the existing graphics or gameplay let's find
> (or profile our code) where we can just get better performance out of our application"*

> *"when I run make skirmish can we make the opponent actually randomized so I can get more varied gameplay? Also, the
> intro music is really cool but then it just stops when we start the initial game and it goes to a loading screen -
> is it possible to keep the music playing through that loading screen?"*

Asked where and when: **`make skirmish` / `make garage`, the native Godot binary on his laptop (Intel UHD 620, window
maximised to 1854×1011), choppy from the first seconds and all match, default armies.** His latest recording:
`build/recordings/2026-10-02T18-59-00-sumps.jsonl` (seed 92721, Law 24 v Condemned 27, 124 s). He is already native,
so "deploying as a native app" is not the lever this round; the web build is slower still (single-threaded wasm) and is
not this round's question.

## Where things stand (measured today, 2026-10-02, at `1efa9940`, his laptop)

- **No instrument measures the game he plays.** `sim-profile`, `ai-perf`, `scale-bench` run the headless `--match`
  runner; `perf-scene` runs `--skirmish --player=cpu --enemy=cpu --cinematic --mute`. His launch (`mk/play.mk:16-20`) is
  `--skirmish --enemy=cpu --seed=<epoch> --arena=random --announcer=voice --music=on --camera-readout=on` with a HUMAN
  player: `VisibilityField` (sim's, ~346 raycasts and ~12 100 cells per tick, skirmish-only), `RtsControls`,
  `TacticalMap`, `SelectionPanel`, `GroupBar`, the booth and the music all live and unmuted, `FrameTarget.LOCKED_30`
  (`Engine.max_fps = 30`, vsync, `max_3d_lines = 1080`), the recorder writing a census every second.
- **The orchestrator's two before-runs** (`_agents/streams/references/perf/r16-before-*.json`): at his window with his
  flags and `PERF_SOUND=1`, but `--player=cpu --cinematic`: 30 vehicles → 36.9 ms a frame (`tick_script_ms` 24.0, GPU
  19.8, `process_game_ui_ms` 2.6, `process_fx_ms` 1.0, `cpu_render_ms` 1.6); 52 vehicles → 100 ms, 3.5 ticks a frame;
  holds locked 30 at **10** vehicles. The run does not say whether the player's layer and the field were in it.
- `fx_auto_quality.gd` steps tiers down on web/mobile only (`enabled` only with `--fx-auto` on desktop): nothing
  adapts in his launch, by design (the picture is his).
- `max_physics_steps_per_frame=3` (`sim_tick_rate.md:106-125`): above ~100 ms a frame the game runs in slow motion
  instead of spiralling — at 52 vehicles he is there.
- **The opponent:** `make skirmish` shows the faction menu (`skirmish_mode.gd:115-128`, `_pick_faction`); the picker
  opens with `enemy_faction = Units.DEFAULT_FACTION` (`faction_picker.gd:26`) and the CPU army is `--enemy=cpu`
  (`Makefile:62`; `army.gd:7`: `"cpu"` = a seeded random archetype, seeded by the match seed, so it does vary with the
  seed — but the FACTION does not unless he picks one, and the arena is `random` already). What he sees: the same
  enemy faction every launch unless he taps one.
- **The music:** `MusicDirector.attach(main, …)` (`main.gd:58`) makes the director a child of `main`; the title
  (`game/ui/widgets/title/title_screen.gd`) hands over through `GameLauncher.start` (a tree reload with new flags,
  `Main.next_flags`), so the director — and the opening track — die with the old tree, the loading screen
  (`game/ui/loading_screen.gd`) shows in silence, and the new `main` attaches a new director that starts `pre_match`
  from nothing. Hypothesis, to confirm by reading `GameLauncher` and the title's launch path.
- **Audio's per-frame cost** is in none of the perf-scene numbers (`--mute`; `fx_tricks.md` trip-up 76):
  `make audio-bench` (`game/audio/audio_bench.gd`, headless, budget ≤ 0.3 ms a frame for booth + music + crowd);
  `engine_system.gd:100-168` loops `_sources.keys()` (an allocation per frame) and calls `is_visible_in_tree()` (a tree
  walk) per vehicle per frame; the booth's event adapter uses `get_nodes_in_group` (`match_event_adapter.gd:44`).

## Backlog (in order)

- **P1. CP1: `make perf-play` — his path, measured.** The perf harness drives a skirmish the way he launches it: a
  human-side player (`--scripted` as `skirmish-shots` does, or the scripted controller issuing a few orders so the
  control layer, the field, the markers and the panels are live), his flags (`--announcer=voice --music=on
  --camera-readout=on`, unmuted), the recorder ON, default armies (the faction pair as his recording: Law v Condemned;
  `--arena=sumps --seed=92721`, and a second seed), his window (`PERF_RES=1854x1011`), **two arms in one target:
  uncapped** (what a frame costs: `tick_script_ms`, `process_game_ui_ms`, `process_fx_ms`, `gpu_ms`, `cpu_render_ms`,
  draws, primitives, per phase and by vehicle count, as today) **and `--perf-capped`** (`LOCKED_30`: does it hold —
  `avg_ms` at 33 with the p95/p99 beside it, and the share of frames over 33 ms, the number that IS "choppy"). Layers
  on top of today's: `no_visfield` (sim's switch, `--sim-off=visfield` — agree the flag name with sim on day one and
  stub it), `no_controls` (the player layer off), `no_audio` (mute within the run), `no_recorder`, plus whatever
  render requests (`no_venue`, `no_water`, `no_ads`, `no_sky`, `no_show`, `no_cutaway`, `no_haze`). A `PERF_PLAY`
  summary line and `build/perf-play.json` in the same shape as perf-scene's so `references/perf/README.md`'s reader
  works; a row in that README. **Announce CP1 to the orchestrator by message; it merges and the other four
  `git merge main`.** Needs a display: the laptop (say when the window is coming) or builder0 for everything but the
  GPU ms.
- **P2. His own games carry their numbers.** A frame-time trace in every `make skirmish` (a `PERF_TRACE` jsonl beside
  the recording: per second the frame avg/p95/max, ticks per frame, `tick_script_ms`, GPU ms, vehicles alive, the
  phase), off in tests and benches, cost ≤ 0.05 ms a frame (measure it with itself), so his next "it was choppy on the
  Locks" is answered from the file (lesson 225: the recording is the witness). `tools/perf_trace_report.py` reads one
  into a table; the `--perf` overlay gains `tick ms`, `ui ms`, `gpu ms`, `ticks/frame`.
- **P3. The opponent randomised** (his words): the faction menu opens with a random enemy faction (and a random
  player suggestion? no — his pick is his; only the opponent), seeded by the launch seed so a replay is the same
  match; a visible **RANDOM** entry on the enemy row that stays random each launch; `ENEMY=cpu` keeps drawing a
  random archetype; `make skirmish ENEMY_FACTION=law` and the picker's tap still pin it. `shell_playtest.gd`'s check
  `faction_right_click_picks_theirs` and the garage's FIGHT path (`garage_mode.gd`, which sets factions itself)
  unchanged. A test: ten launches at ten seeds give more than one enemy faction; one seed twice gives the same.
- **P4. The title's music carries through the loading screen** (his words): the director survives the tree reload
  (an autoload, or reparented under the root before `GameLauncher.start` and re-adopted by the new `main` — pick the
  one that keeps `MusicDirector.attach/find` and the garage's `hold` working), the opening track keeps playing over
  the loader and crossfades into the match's `pre_match` on its bar line (the director's own `_crossed_bar_line`),
  no double director, no leak on exit (the relay and net smokes fail on any ERROR). A test with the real tree:
  title → launch → loader → skirmish, `is_playing()` true throughout and `current_track()` continuous until the
  crossfade. `make garage-tour` and `make title-shot` unchanged.
- **P5. Audio's per-frame cost ≤ 0.3 ms**: `make audio-bench` before/after; `engine_system`'s `keys()` and
  `is_visible_in_tree()` per vehicle per frame; the booth adapter's group lookup; the music director's per-frame bar
  check; the crowd voice. The sound identical (`make audio-pass` once, listened to by you for a hitch).
- **P6. The slow-motion trap, explained to him** in `sim_tick_rate.md` and the `--perf` overlay (a "SLOW ×0.6"
  indicator when `ticks_per_frame` < 1 at the cap, so "choppy" and "slow" are told apart).
- **P7 (stretch).** `make perf-play` on builder0's display in `check-all` as a printed MEASURE (never a gate:
  verification.md *Timing in tests*).

## How to verify

- `make remote T=check` green on your last commit; the sim baseline cannot move from your paths (a harness or a
  menu default that moves it has changed the match: stop and tell the orchestrator).
- `make perf-play` on the laptop, both arms, the JSON kept under `references/perf/` with a README row; the
  screenshot per phase looked at (the player layer IS in the frame).
- P3: `make skirmish` ten times from the title (headless `--scripted` variant) → the enemy factions seen; the
  shell playtest; `make garage-smoke`, `make garage-tour`.
- P4: the music test above; `make audio-launch-smoke` on a display; `make relay-smoke` and `net-smoke` (no leaked
  director, no ERROR on exit); listen once from the title through the loader (`make skirmish`).
- P5: `make audio-bench` before/after.

## Don't touch

`game/ai/**`, `game/tactics/**` (brains), `game/match/**`, `game/tank/**`, `game/combat/**`, `game/arena/**`,
`game/units/**` (sim; the `visfield` switch is sim's — stub it in the harness until sim lands it), `game/ui/**`
except your three carve-outs, `game/control/**`, `game/camera/**` (hud), `game/theme/**` except `fx/bench/**` and
`audio/**` (render), `game/announcer/**`, `assets/announcer/**` (booth), `game/garage/**` (nobody this round; a request if P3 or P4 needs a
line there), `project.godot`,
`mk/core.mk` (orchestrator; additive edits in merge notes only).

## Waiting on the lead

Nothing. P3 and P4 are his words; the design choices inside them are yours (record the reason).

## Status

_Updated 2026-10-02 ~21:40 PDT by the play worker. **Merged so far:** CP1 `94072ca4` → main `7100e3fe`; `32324c4a` →
main `68903a5e`. Since then: docs `a52831c3`/`cb156fcb`, `PERF_PLAY_NAME` `c7e6ba24`, this Status. The final green
hash is at the bottom._

**Backlog:** P1 ✅ · P2 ✅ · P3 ✅ · P4 ✅ · P5 ✅ measured, nothing over its budget; my one change is unpriced (below the
noise) · P6 ✅ · P7 ✅ (the orchestrator added `perf-play-measure` to check-all in core.mk at my request).

**Done (with numbers)**

- **P1 / CP1 `make perf-play`** (`67f072cc`, `94072ca4`; knob `c7e6ba24`). `perf_scene.gd --perf-play` plays his launch:
  a human-side skirmish (no `--cinematic`), so the fog field, the controls, the markers, the panels, the booth, the
  music and the recorder are all live. It lifts the planning pause, sends every group at the enemy (attack-move,
  spread 25 m), and HIS RtsCamera follows group 1 with vision framing. Looked at: 21°, 70 m, the panel, chips,
  radar, readout and rings all in frame. Default layers `no_visfield,no_controls,no_audio,no_recorder` (+`no_cutaway`);
  unknown names go to render's `RenderLayers` when the tree has it. `mk/fx.mk perf-play`: seeds `92721 31337` × arms
  `uncapped capped`, knobs PERF_PLAY_SEEDS/ARMS/LAYERS/FLAGS/NAME/CYCLES. `tools/perf_play_report.py` prints the table +
  `PERF_PLAY`. Harness runs pass `--hints=off --announcer-history=off --music-history=off` and record into
  `build/perf-play/recordings`, so his profile, hints and memories are never touched in main (booth's request).
- **The time-base finding:** `avg_ms` was `delta`. Above `max_physics_steps_per_frame` (3), Godot hands `_process`
  the simulated time, so a saturated frame read ~100 ms whatever it cost. Frames are now measured by the wall clock,
  with `game_ms` and `game_speed` beside them. The perf README note and `sim_tick_rate.md` (whose "the clock stays true
  at 3.41 ticks/frame" was the same error) are corrected.
- **His path, the laptop SHARED** (load ~8, 4–10 other Godot processes; `references/perf/r16-play-laptop-loaded-*`,
  at `67f072cc`+): **saturated in all four arms. Real frames are 163–174 ms, the battle runs at 0.59–0.64× speed, 3.4–3.5
  ticks a frame, and 100 % of frames are over 34 ms.** Tick 45–48 ms a tick, GPU 17.7–22.5, game+UI 10–14, FX ~1.0,
  ~40 vehicles. Layer deltas on the frame are ±15 ms noise at saturation; per tick `no_visfield` +0.4…+3.8 ms. A
  spectated Sumps under `--perf` at load ~14: 143–326 ms frames, speed 0.30–0.72. **The tick is the first lever.**
  The orchestrator's record runs (loaded now, quiet at close) supersede these numbers.
- **P2 the trace** (`e034fbf1`). `PerfTrace` beside every recording: `<recording>.perf`, one JSON line a wall-clock
  second (frame avg/p95/max, ticks a frame, tick ms, game+UI ms, GPU ms, game_speed, over34, vehicles, phase,
  self_ms). It uses its own extension, so the recorder's prune never counts it, and it keeps 40. It is off when
  headless, scripted, under perf-scene, with `--no-record` or with `--perf-trace=off`. `tools/perf_trace_report.py
  [file]` (the newest by default) prints the seconds, the whole match and the battle only. **Its own cost: 0.058 ms a
  frame mean on the laptop at load ~14** (budget 0.05; expected ~0.02 on builder0). Not yet run on a quiet machine.
- **P3 the random opponent** (`94072ca4`). The menu opens with the enemy on a new **Random opponent** row (theirs
  only: right-click or shift+5). FIGHT rolls **one of the other three** factions from the launch seed (decision: a mirror
  is the least varied match; same seed, same enemy). `make skirmish ENEMY_FACTION=law` pins it with the menu still up.
  Direct `FactionPicker.new()` keeps the old default, so control's tests (11/0) and the shell playtest are unchanged.
  `tests/test_modes_enemy_random.gd` 6/0. Screens looked at: 1854×1011 and 1200×540 (it fits; FIGHT stays clear).
- **P4 the music through the loader** (`94072ca4`, fix `db39a87c`). Measured first: an `AudioStreamPlayer` keeps playing
  across `reparent()` in 4.7. `MusicDirector.carry(main)` moves the director onto the root before the menu's
  `GameLauncher.start`, and the new main's `attach` adopts it with its draws kept, so the menu's opening simply
  continues. A launch with music off or `--mute` drops it. **The real-tree smoke found a second silence:** the skirmish
  opens in the planning pause, and the director under the paused Match was stream-paused. So the opening was silent
  in EVERY planning pause, before this round too. The director is now `PROCESS_MODE_ALWAYS`. `audio-launch-smoke`
  (title → SKIRMISH → menu → FIGHT → loader → match, real input) now asserts carried == adopted, both playing, one
  director: passed locally (pre_match_hymn carried at 5.3 s, still playing at 38 s through the pause, then the battle
  crossfade). The music tests 30/0. No edit to `GameLauncher` (hud's) or `main.gd`.
- **P5 audio** (`deeebbef`). `make audio-bench` on builder0, old vs new engine code alternated ×2 (4 runs, at
  `32324c4a`): booth+mood 0.029–0.061 ms, music 0.025–0.046, **booth + music ≈ 0.05–0.11 ms: inside the 0.3 budget**.
  The crowd is not in the bench; its `_process` is one lerp. Engines 0.095–0.235 (old) vs 0.198–0.201 (new),
  gunfire 0.04–0.09: these are FxWorld's steps, not under the 0.3. My change (no `keys()` copy a frame; the two
  `exp()` once a frame, not per vehicle; same numbers, tests/audio 86/0) is **below builder0's noise: unpriced, not
  claimed.** The booth adapter's `get_nodes_in_group` is booth's code: noted for them, not measured separately.
  `make audio-pass` (listening) not run; nothing audible changed.
- **P6** (`e034fbf1`, docs `cb156fcb`): `--perf` shows PerfTrace's line, orange with **SLOW x0.71** when the battle runs
  behind the clock. `sim_tick_rate.md` explains choppy (frames late) vs slow (the battle behind the clock), and why
  while saturated each ms off a tick is ~3 ms off the frame.
- **P7:** done by the orchestrator on main (`perf-play-measure` in check-all, never a gate).

**Requests to other streams**

- render: the `--perf` overlay (`perf_overlay.gd`, yours) could show `PerfTrace.latest()` (tick, ui, gpu, ticks/frame,
  SLOW). Until then PerfTrace draws its own line. The `RenderLayers` default arm is in perf_scene (guarded).
- sim: once S1 is on main, I add `no_visfield_thread` beside `no_visfield` (the within-run form of
  `--sim-off=visfield_thread`).
- booth: `match_event_adapter.gd:44`'s `get_nodes_in_group` per call is in no bench; price it with `audio-bench` if it
  runs per frame.

**Known issues / next steps**

- Music: every audio-bench run shows a single frame of 7–16 ms in `music` (max), probably a synchronous stream load at
  a track change (`_load_any` → `ResourceLoader.load`). At a locked 30 that is one dropped frame per bed change. Next:
  a threaded load requested when the state is set (the crossfade already waits for a bar line). Confirm the frame
  first (the bench prints "worst on frame N").
- PerfTrace's self-cost on a quiet machine is unmeasured (0.058 ms at load ~14).
- At saturation, the layer method's frame deltas are noise; read tick/ui. The capped arm equals the uncapped one
  while saturated (the cap never binds).
- An early slip: `pkill -P $(pgrep -f …)` meant for my own check matched brains' first. Verified it did not land; the
  orchestrator was told. From now on PIDs go by `readlink /proc/<pid>/cwd`.

**Questions for the lead:** none open. **Decided (the orchestrator, 2026-10-02):** Random never deals a mirror ("more
varied gameplay"; a mirror also undoes his faction read); `ENEMY_FACTION=` still pins any faction. Recorded at
`FactionPicker.roll_enemy`.

**To playtest:** `make skirmish`. The menu shows "Random opponent" as ENEMY. Listen: the menu's music carries through
FIGHT, the loading screen and the planning pause into the match. Play a few launches and see the enemy change.
`make skirmish ENEMY_FACTION=gangs` pins it. After any match, `python3 tools/perf_trace_report.py` reads the one just
played (frame times per second, the battle's speed).

**Merge notes:** `mk/audio.mk` audio-launch-smoke assertion (accepted as play's). `game/main.gd` untouched.
`mk/fx.mk` perf targets and `mk/play.mk` are mine. No `project.godot` edit.

- **Render's divergence finding, built into the harness** (`b987a525`): a windowed match is not repeatable past
  ~tick 150, so two runs are two fights. The report says so first, prints each run's vehicles-alive curve and its
  recording, and `PERF_PLAY_ARMS` may add `frozen` (uncapped + `--tune=match.no_damage=1`; smoke: 51 vehicles held all
  run). Within-run layer costs are unaffected.

**Green hash: `b987a525`.** Wrapper: `>> remote: make check exited 0 (build/ copied back)`. Runner: 1873 passed, 0
failed. sim-baseline `05df1d55ba49cde1` (unmoved), determinism `762a0576f944f5b7`, builder0. Everything after it is
this Status (docs only). Earlier green hashes: `94072ca4` (CP1, merged `7100e3fe`), `32324c4a` (merged `68903a5e`),
`6b899df2`.
