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

_Updated 2026-10-02 ~20:30 PDT by the play worker. The green hash is named below once builder0's check lands._

**Plan (in order):** P1 CP1 `make perf-play` ✅ built (check pending) → P3 the random opponent ✅ built → P4 the music
through the loader ✅ built (real-tree smoke owed) → P2 the frame trace beside every recording (in progress) → P6 SLOW
on the overlay (built inside P2's trace line) → P5 audio ≤ 0.3 ms → P7 stretch.

**Done**

- **P1 / CP1 `make perf-play`** (`67f072cc`, `94072ca4`). `perf_scene.gd --perf-play` plays his launch: a human-side
  skirmish (no `--cinematic`), so the fog field, the controls, the markers, the panels, the booth, the music and the
  recorder are all live. It lifts the planning pause, sends every group at the enemy (attack-move, spread 25 m), and
  HIS RtsCamera follows group 1 with vision framing (shot: 21°, 70 m, panel/chips/radar/readout/rings in frame).
  Default layers `no_visfield,no_controls,no_audio,no_recorder`, plus `no_cutaway`. Any unknown name goes to render's
  `RenderLayers` when the tree has it (render's C16.5 request, guarded by class lookup). `mk/fx.mk perf-play`: seeds
  `92721 31337` × arms `uncapped capped` (PERF_PLAY_SEEDS/ARMS/LAYERS/FLAGS); `tools/perf_play_report.py` prints the
  table and the `PERF_PLAY` line. Recordings go to `build/perf-play/recordings`, never his directory; `--hints=off` so his
  hint profile is untouched.
- **The time-base finding (affects every perf-scene number above saturation):** `avg_ms` was `delta`, and above
  `max_physics_steps_per_frame` (3) Godot hands `_process` the simulated time, so a saturated frame read ~100 ms. The
  harness now measures frames by the wall clock and adds `game_ms` and `game_speed`. README note + caveat (relayed by
  the orchestrator).
- **His path, the laptop SHARED** (load ~8, 4–10 other Godot processes; `r16-play-laptop-loaded-*.json`, at
  `67f072cc`+): **saturated in all four arms. Real frames are 163–174 ms, the battle runs at 0.59–0.64× speed,
  3.4–3.5 ticks a frame, and 100 % of frames are over 34 ms.** Tick 45–48 ms a tick (the quiet before-run read 24),
  GPU 17.7–22.5, game+UI 10–14 ms, FX ~1.0, ~40 vehicles. At saturation the layer deltas on the frame are ±15 ms
  noise; per tick, `no_visfield` reads +0.4…+3.8 ms. **The game he plays is tick-bound first:** every ms off the
  tick is ×3.5 on the frame until it drops under 1 tick a frame.
- **P3 the random opponent** (`94072ca4`). The faction menu opens with the enemy on a new **RANDOM** row (theirs only:
  right-click or shift+5). FIGHT rolls **one of the other three** factions from the launch seed (decision: a mirror is
  the least varied match, so his own faction is excluded; the same seed gives the same enemy). `make skirmish
  ENEMY_FACTION=law` pins it with the menu still up (`--pick-faction`). Direct `FactionPicker.new()` keeps
  DEFAULT_FACTION, so control's tests and the shell playtest are unchanged (11/0). `tests/test_modes_enemy_random.gd`
  6/0: ten seeds give more than one faction, and one seed twice gives the same.
- **P4 the music through the loader** (`94072ca4`). Measured first: an `AudioStreamPlayer` keeps playing across
  `reparent()` in 4.7 (position 3.41 → 3.90 s across the move, and after the old parent was freed). So before the
  menu's `GameLauncher.start`, `MusicDirector.carry(main)` moves the director onto the root (`CarriedMusic`, process
  ALWAYS, unhooked from the old mood), and the new main's `attach` adopts it under `Match/Music`. It follows the new
  mood with its draws kept, so the menu's opening IS the match's opening and simply continues; a different state
  crossfades on its bar line. A launch with music off or `--mute` drops it (no leak). `MUSIC_CARRY` lines every 0.5 s
  while it waits. No edit to `GameLauncher` (hud's) or `main.gd`. Tests 30/0 (two new). Decision: carry, not an
  autoload; `find`, `hold` and the garage path are unchanged.

**In progress:** P2 `PerfTrace` (`game/theme/fx/bench/perf_trace.gd`): `<recording>.perf`, one JSON line a second
(wall-clock frames, tick, ui, gpu, game_speed, over34, vehicles, phase, self_ms). With `--perf` it shows a line that
includes **SLOW x0.60** (P6). `tools/perf_trace_report.py` reads it.

**Requests to other streams**

- render (C16.5, done on my side): the default arm hands unknown layers to `RenderLayers.apply/restore`; it activates
  when render's branch merges, and I `git merge main` at that checkpoint.
- render: the `--perf` overlay (`perf_overlay.gd`, yours) could show PerfTrace's numbers (`PerfTrace.latest()`): tick
  ms, ui ms, gpu ms, ticks/frame, SLOW. Until then PerfTrace draws its own line under `--perf`.
- sim (agreed, via the orchestrator): the run-level flag is `--sim-off=visfield` (SimProfile.switched_off); within a run
  `no_visfield` sets process DISABLED (sim confirms it, or `VisibilityField.enabled = false`, stops it). **Next, once sim's
  S1 is on main:** a `no_visfield_thread` layer beside it (the field ON with its cell marks back on the main thread, the
  within-run form of `--sim-off=visfield_thread`), so perf-play prices S1's worker thread on his path. Sim's loaded
  numbers (60f00f7b, uncommitted): field ~3.4 ms a tick pre-S1, 1.21 with the thread.

**Known issues:** at saturation, the layer method's frame deltas are noise (read tick/ui). The capped arm's numbers
equal the uncapped arm's while saturated (the cap never binds). An early slip: a `pkill -P $(pgrep -f …)` meant for my
own check matched brains' process first; verified it did not land; the orchestrator was told.

**Questions for the lead:** none blocking. (P3: should the random roll ever give a mirror match? I excluded it for
variety. One line to flip in `FactionPicker.roll_enemy`.)

**To playtest:** `make skirmish`: the menu shows "Random opponent" as ENEMY. FIGHT, and listen: the menu's music
carries through the loading screen into the match without stopping. `make skirmish ENEMY_FACTION=gangs` pins it.

**Merge notes:** no shared-file edits. `game/main.gd` untouched (attach adopts inside `music_director.gd`).
`mk/fx.mk` (perf-play), `mk/play.mk` (ENEMY_FACTION), both mine.

**Green hash:** (pending builder0)
