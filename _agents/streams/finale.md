# Stream: finale (the game freezes for seconds at the final kill: find what is used for the first time there, and make it not the first time)

> Read `_agents/orchestration.md` (the worker contract), `_agents/streams/archive/round17/sim.md` (*The kill-cam as he
> will see it*: where this was found, and the kill cam's tick schedule you must not break), `_agents/determinism.md`
> (the kill cam's rule), `_agents/metrics.md`, `_agents/workstreams.md` *Round 18*, and the memory note that the
> laptop is the test bed (he plays on an Intel UHD 620 on purpose; cuts ship as hardware presets, the look stays on
> better GPUs). You own `game/theme/fx/**`, `tests/test_fx*.gd`, `tests/test_render*.gd`, `mk/fx.mk`,
> `_agents/metrics.md`. **Reading is unrestricted and the fix lands where the cost is:** in an unowned path
> (`game/theme/**` outside fx, `game/camera/**`, `game/garage/**`, `game/announcer/**`, `game/audio/**`) you make the
> minimal fix and list it in merge notes; in `game/ui/**` (picker's: the DEFEAT / VICTORY banner,
> `game/ui/widgets/hud_skin.gd`) or `game/match/**` / `game/modes/**` you send the finding and the smallest patch to
> the orchestrator, who lands it (C18.6).

## The lead's direction

No words of his. He was offered it as *"the game freezes for two or three seconds at the final kill; it happens at the
end of every match on your laptop"*, with the orchestrator's recommendation to include it, and did not object
(2026-10-04; `game_design.md` *Round 18 direction*, *His pick*). Why it matters to him: it is the last thing he sees
in every match, on the machine he plays on.

## Where things stand (sim, round 17; laptop, his window 1854×1011, desktop preset, real time, sumps seed 1
`--scripted`, a SceneTree probe logging every `time_scale` change; **the laptop was LOADED, load 5.5–16.8**)

- **The two frames around the last kill took 1.7 s and 3.4 s**, on the old (wall-clock) kill cam and the fixed
  (tick-counted) one alike. Sim's guess, untested: a first-use FX or shader compile at the kill burst or the DEFEAT
  banner. Nobody has measured it on a quiet laptop, and nobody has measured it on builder0's GPU at all.
- **What happens at that moment** (read the code; this list is a set of suspects, not a finding): the last unit's
  death burst and wreck (`burst_system.gd`, `wreck_field.gd`, `fire_sites.gd`); the kill cam's slow motion
  (`game/theme/fx/kill_cam.gd`: `Engine.time_scale` 0.2, sound at 0.55, HOLD_TICKS 42, RAMP_TICKS 18, a real-time
  bound at `WALL_STRETCH` 1.5); the DEFEAT / VICTORY banner (`game/ui/widgets/hud_skin.gd`; a font size or glyph
  set first shaped there is a classic stall); the announcer's and the music's end-of-match lines (a stream loaded
  on first play); round 17's new kill sound; the results flow (`game/garage/results_screen.gd`,
  `game/modes/skirmish_mode.gd`); the recorder's or the booth's end-of-match write.
- **The kill cam's determinism rule stands** (`determinism.md`): its schedule counts simulation ticks; a
  `--fixed-fps` run is never wall-bounded; `Match` warns on a live tick at `time_scale ≠ 1`. `make
  windowed-elimination-pair` (in `check-all`) asserts the slow-motion length in ticks. Your fix must leave it green.
- **Instruments that exist:** `make perf-play` (his path: his flags, his window, uncapped and capped, layers by
  removal; `mk/fx.mk:102`), `perf_overlay.gd`, `frame_target.gd`, `fx_auto_quality.gd`, `make perf-scene`. None
  records a per-frame time series through the END of a match: that is your first item.
- **A windowed run on the laptop opens on his desktop.** Keep each under a minute or two, say when in Status, and
  state the load (`uptime`) beside every number. The record run is the orchestrator's quiet-window run: ask for it
  with the exact command.

## Backlog (in order)

- **E1. See it, with a number.** A per-frame trace through the end of a match on his path: frame time, the tick, and
  a marker at each end-of-match event (last hit, the death, `finished`, kill-cam start, the banner shown, the first
  sound, the results screen). A scripted skirmish that ends by elimination quickly (a seed and budget that finish in
  under a minute; the round-17 witness was sumps seed 3, elimination at tick ~625). Laptop first (his GPU is the
  subject), then builder0 for contrast. The stall as: the largest frame within ±1 s of the final kill, k of N runs,
  quiet and loaded. If it does not reproduce on a quiet laptop, say so plainly: then it is a load problem, and E2
  asks what the load starves.
- **E2. Name the cause by removal, one suspect at a time, inside one setup** (never by a ratio): each suspect
  switched off or pre-used at load, the largest end-frame against E1's, N stated, with an arm assertion that the
  suspect really was off (lesson 247). Split shader or pipeline compilation (the renderer's first use of a material
  variant; Godot reports pipeline compilations in the rendering monitors) from resource loading (a first `load()` of
  a scene, stream or font on the main thread) from script work (the results flow building its screen in one frame)
  from a synchronous file write.
- **E3. Fix it at the cause.** A shader or pipeline: used once at load behind the loading screen (a warm-up pass of
  the end-of-match effects, off-screen or one pixel), in every preset. A resource: preloaded, or loaded on a thread
  before it is needed. Script work: spread over frames or built before the last kill is likely. A write: after the
  slow motion, or off the main thread. **No look changes and no cut on better GPUs; the loading time it adds is
  measured and stated** (his laptop's load time is part of what he feels).
- **E4. It cannot come back unseen.** A test or a `check-all` measure for the class: the largest frame within ±1 s of
  a scripted final kill, printed every run as a MEASURE line, judged only where the machine can judge it (the round-17
  rule: a named NOT JUDGED row, never a silent skip). Ship owns `mk/core.mk`: request the line through the
  orchestrator with its seconds.
- **E5. The same class during the match.** The first shot of each gun family, the first shield break, the first
  smoke, the first burning wreck, the first airship pass, the first of each of round 17's new impact sounds: the
  largest frame at each first use against the tenth use, laptop. Everything that stalls more than two frames joins
  the warm-up. This is what he feels as a hitch at first contact.
- **E6. What he sees at the end, as one sequence.** After the fix, frames from the last kill to the results at his
  pose on the laptop (start, hold, ramp, +1 s): look at them. The slow motion now lasts 60 ticks (~2 s where the
  game keeps up, bounded to ~3 s under load). If, without the stall, it reads long or short, say so with the knob
  (`KillCam.HOLD_TICKS`); the length is his call, so offer it, do not change it.
- **Stretch.** (a) Slow motion is half a simulation (`roadmap.md` candidate 5): during `time_scale < 1` motion slows
  but tick-counted rules (reloads, think cadence, intel) run at full rate; harmless after a decided match, wrong in a
  live one under `--slow-motion=`. A written design for the two fixes with what each touches; build nothing that
  moves a hash. (b) Loading time on the laptop by phase, before and after your warm-up, and the cheapest second to
  remove. (c) The loading screen says what it is doing while it warms.

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe). The sim baseline and determinism UNMOVED on every commit: a presentation fix that
moves a hash is a finding, merged alone. `make remote T=windowed-elimination-pair` green after any change near the
kill cam. Every frame time: commit, machine, GPU, load, window size, preset, seed, N. Look at the frames you produce.

## Don't touch

`game/ui/**`, `game/control/**` (picker; the banner fix goes through the orchestrator) · `game/match/**`,
`game/modes/**`, `game/ai/**`, `game/tactics/**` (brains owns the last two; the first two are nobody's this round and a
change there is the orchestrator's to land) · `arenas/**`, `game/arena/**` (maps) · `mk/core.mk`, `tests/baselines/**`
(ship) · `game/theme/audio/**`, `assets/audio/**` (no new sound, no spend) · the kill cam's tick schedule and its
constants (his call).

## Waiting on the lead

- Nothing. E6 may leave him one question (the slow motion's length); it goes in Status with the frames.

## Status

_Worker: finale. Started 2026-10-04 14:40 PDT from the launch tree `cbda2c6a`. **Report below; green hash at the end.**_

### The answer in one paragraph (for the orchestrator and, in his terms, for him)

**The freeze at the final kill does not happen on his laptop as the game stands: 0 of 9 traced endings, warm or cold,
either preset; and his own two most recent real matches (Godot's logs) ran the slow motion exactly to schedule.** What
IS real is the same class one step earlier: **the first time the arena screens' live feed records, the first time a
pooled light touches the arena, the first shield hit and the first shot of a gun compiled shaders mid-match — 1–2.8 s
frozen frames, several per match — whenever the shader cache is cold** (the first match after an update that touches
the game's materials, or after a driver update). Round 17's 1.7 s / 3.4 s at the end were almost certainly this, on a
cold tree at load 5.5–16.8. **Fixed at the cause:** a two-frame warm-up behind the loading screen draws every material
the way the fight will (unlit and lit, by the main camera and the feed) and the effects prewarm now actually draws its
shield. Cold: nothing past load over ~200 ms in two fights, every first use costs what its tenth does; the load gets
~8 s longer ONCE (the compile moved, it was not added). Warm (his normal case): no stalls before or after, no
measurable load cost. No look change, every preset.

### Plan (in order; done unless marked)

1. E1 trace — done. 2. E2 by removal — done. 3. E3 warm-up — done. 4. E4 measure — target done, `check-all` line
**requested from ship through the orchestrator**. 5. E5 first uses — done (shield fix). 6. E6 frames — done, one
question for him. 7. Stretch (a) design, (b) load by phase, (c) loading-screen text — see the end.

### E1: see it, with a number

- **His own play does not show the freeze.** His two most recent real matches on the laptop (Godot's own logs,
  `~/.local/share/godot/app_userdata/Tank Squad/logs/`, 2026-10-04 03:36 terminus and 03:56 yard, `laptop` preset by
  adapter): the slow motion ran **60 ticks in 1994 ms, ended by ticks**, both times. A 1.7 s frame inside it would
  have cost ticks (3-step cap) and stretched that past 2 s. In the yard match the final kill's announcer cut is stamped
  174158 ms and `KILL_CAM start` 174187 ms: 29 ms apart.
- **`make end-trace`** (`FrameTrace`, `game/theme/fx/bench/frame_trace.gd`, `--frame-trace=PATH`): every frame cut at the
  engine's own signals into physics / process / draw / rest, the tick, time scale, draw calls, object / resource counts,
  memory, nodes added, FX state, camera; marks at each kill, `finished`, kill cam (start / ramp / end), banner, results,
  viewports and cameras entering, `first:` / `tenth:` use of each gun and impact kind; `--frame-trace-off=<RenderLayers>`
  removal arms; `--frame-trace-shots=DIR`. Laptop at `4e06a892` (UHD 620, 1854×1011, sumps seed 1 `--scripted` budget
  6500, voice and music on; the largest frame within ±1 s of the final kill vs the median of the 4 s before):

  | Arm | load | N | largest ±1 s (ms) | typical (ms) | kill cam |
  |---|---|---|---|---|---|
  | laptop preset (his), warm | 6.6–8.2 | 3 | 236 / 97 / 139 | 166 / 137 / 104 | 60 ticks in 2.77 / 1.97 / 2.03 s |
  | desktop preset, warm | 3.3–4.6 | 3 | 129 / 115 / 109 | 108 / 53 / 75 | 60 ticks in 2.15 / 1.95 / 1.94 s |
  | desktop, COLD (Godot cache emptied, Mesa's off) | 2.5–2.9 | 3 | 237 / 258 / 130 | 92 / 81 / 118 | 60 ticks in 1.99 / 2.26 / 2.11 s |

  E2–E5's further 30-odd laptop runs (cold and warm, both fights) agree: the end ±1 s was 62–219 ms every time.
- **builder0** (Iris Xe, also integrated): its hidden window runs at **1 fps** unless vsync is off (every frame ~1000 ms
  in the swap; the round-16 `.perf` files dated 2026-10-03 under `~/projects/godot/build/recordings/` are that, not
  his play). With `END_TRACE_ENGINE=--disable-vsync` it runs at a 34–48 ms median and sees the class: cold, no
  warm-up, 1.88 / 1.83 / 1.58 s mid-match; the end ±1 s 141 ms (load 7–13).

### E2: the cause, by removal (laptop UHD 620, his `laptop` preset, COLD cache, sumps seed 1, `5f57e064`, load 2.4–3.7,
arms interleaved, N = 2 each; `--frame-trace-off=<RenderLayers name>`; arm assertion: each layer reported 1 thing
switched, and `lit` stayed 0 with the pool off)

| Arm | draw stalls mid-match (sum, frames whose draw > 100 ms) | largest frame | largest within ±1 s of the final kill |
|---|---|---|---|
| baseline | 6.5 / 7.0 s | 2.1 / 2.0 s | 219 / 77 ms |
| no live feed | 1.9 / 2.1 s | 1.1 / 1.5 s | 77 / 77 ms |
| no pool lights | 2.9 / 3.0 s | 2.2 / 2.1 s | 104 / 79 ms |
| **both off** | **0.8 / 0.8 s** | **0.65 / 0.63 s** | 98 / 75 ms |

- **Two first uses hold ~88 % of it, and both are shader compiles in the DRAW part of the frame** (not resource loading:
  no node, object or resource count moves on those frames; not script: process ≤ 10 ms; not a file write: `rest` ~0):
  1. **The arena screens' live feed** (`game/theme/arena_kit/ads/live_feed.gd`): its slots render the shared world
     under a copy of the environment with **glow off**. In the Compatibility renderer that is another specialisation
     of every scene shader, so the feed's first recordings (it starts once ≥ 3 vehicles cluster, i.e. at first
     contact) compiled every material it saw: one frame with ~+80 draw calls and 2–2.8 s of draw, cold.
  2. **The pooled omni lights** (explosions, lasers, fires): "lit by an omni light" is another variant of every
     material it touches. `FxWorld._prewarm` lit its lights 0.5 m wide 6 m in front of the camera, which reaches none
     of the arena's materials. The first laser (tick ~196) cost 1.2–1.8 s of draw cold with the pool on and 0.25–0.3 s
     with it off.
- Not causes: resource loading, script work, the results flow, a file write, the banner (the banner's frame is a
  normal frame in every run), the music's switch (prefetched on a thread at match start; his log says `cost=3.92` ms).

### E3: the fix, a warm-up behind the loading screen (`game/theme/fx/shader_warmup.gd`, `91208026`)

- Once the match is attached and the live feed has its slots: **frame 1** every visible `GeometryInstance3D` gets a
  16 km `extra_cull_margin` and no visibility range (frustum and light culling treat it as on screen), the pool is
  OFF, one feed slot renders from the main camera's pose; **frame 2** the same, LIT (every pooled light at a 4 km range,
  energy 0.001, priority above any request); **frame 3** everything put back. Slot 0 is not shown until the feed
  records into it, so the warm-up's frames never reach a screen. Every preset; no look change (no setting stays
  changed); `--no-shader-warmup` is the before arm. Tests: `tests/test_fx_shader_warmup.gd` (6).
- Two wrong turns, both caught by the warm-up's own arm assertion (lesson 247): (1) it ran on frame 0, before the feed's
  slots existed (`feed_slots=0`): it now waits for them (≤ 30 frames); (2) its lights lost the pool's tie to the
  prewarm's 0.5 m lights (same priority, nearer the camera): `lights_lit_wide=0`; it now asks above everything and reads
  back the lights the pool really lit. A third: a warm-up that lit everything left the feed's UNLIT variant to compile
  at its first recording (1.9 s, tick 36): lit and unlit are two specialisations, hence two frames.
- **Cold cache, laptop, his preset** (`5f57e064`+warm-up, N = 1 each, load ~2–3): with the warm-up nothing past load
  exceeds **302 ms** (the first laser's 258 ms of draw; was 1.0–1.9 s), against 1.85–2.2 s without. The two warm-up
  frames cost 3.2 + 3.9 s of load, cold, against ~6.2 s of mid-match stalls without it (the compile moves, it is not
  added).
- **Warm caches (his everyday case), laptop, his preset, N = 3 each, `91208026`/`c5f40c82` (same game code), load
  1.7–3.6:** **0 stalls in either arm** (no frame over 250 ms in the match; largest 150 / 210 / 180 ms warm-up on,
  160 / 164 / 144 off). Load: the first four frames sum to 1.8 / 2.1 / 2.3 s on and 2.2 / 2.2 / 1.7 s off, inside the
  spread. **So the hitches are a cold-cache event**: the first match after a driver update or after an update that
  changes the game's shaders (round 17 changed materials; sim's runs were on such a tree). The warm-up moves that cost
  behind the loading screen and costs nothing measurable once warm.

- E3/E5 numbers below supersede the single-run figures above where they differ.

### E3 + E5: the fix and the first uses (laptop, his preset, `258d1f78` = the warm-up with the shield fix; COLD; load
1.3–2.4; two fights: sumps seed 1, and Law vs Condemned seed 92721; N = 1 per arm per fight)

| | without warm-up | **with warm-up** |
|---|---|---|
| largest frame past load (tick ≥ 15) | 2.06 s (sumps), 2.09 s (Law) | **128 ms, 194 ms** (the 194 is physics) |
| first cannon / tenth | 1196 / 134 ms | **151 / 112 ms** |
| first laser / tenth | 1046 / 69 ms (Law), 220 / 158 (sumps) | **65 / 83, 115 / 124 ms** |
| first machine gun / tenth | 1196 / 127 ms | **151 / 167 ms** |
| first unit hit / tenth | 1196 / 112, 1046 / 69 ms | **151 / 154, 65 / 82 ms** |
| first wreck, first fire, first kill, ground impact, assault gun, autocannon, rockets, sonic emitter | all within ~2 frames of the tenth | same |
| load to tick 15 | 14.4 s, 16.9 s | **22.6 s, 25.6 s** (+8.2, +8.7 s, once per cold cache) |

- **What the warm-up is** (`game/theme/fx/shader_warmup.gd`): once a match is attached and the live feed has its
  slots, frame 1 widens every visible `GeometryInstance3D` (16 km `extra_cull_margin`, no visibility range) with the
  pool OFF and renders one feed slot from the main camera's pose; frame 2 the same LIT (every pooled light at 4 km,
  energy 0.001, priority above any request); frame 3 everything is put back. It re-arms for every new match (a rematch
  may be another arena). FxWorld's effect prewarm is held through it, and **the prewarm now hits its shield**
  (`ShieldEffect` is drawn only once hit, so the shield shader had never been prewarmed: the last ~250–400 ms at the
  first laser hit, found by removal: not the HUD, not the effects layer). `--no-shader-warmup` is the before arm.
- **Warm caches (his everyday case), laptop, N = 3 per arm, `91208026`/`c5f40c82`, load 1.7–3.6:** 0 stalls in either
  arm (no frame over 250 ms; largest 150 / 210 / 180 ms on, 160 / 164 / 144 off); the first four frames sum to
  1.8 / 2.1 / 2.3 s on and 2.2 / 2.2 / 1.7 s off — no measurable load cost.
- **builder0, cold, vsync off, `91208026`** (load ~10): with the warm-up the worst frame past load 265 / 404 ms (before
  the shield fix), without 1884 ms.
- Arm assertions printed every run: `SHADER_WARMUP begin frames_waited=… instances=… feed_slots=…` and `done
  lights_lit_wide=N`. They caught two of my three wrong turns (ran before the feed existed; lost the pool's tie to the
  prewarm); the third (one lit frame left the feed's unlit variant) was caught by the trace.
- Tests: `tests/test_fx_shader_warmup.gd` (8: both frames' state, the restore, a freed node, the pool as it was, off,
  no match, a rematch re-arms, the effects hold), `tests/test_fx_frame_trace.gd` (2: the summary's arithmetic).

### The pair re-taken on the merged tree (C18.5: `e631b5fc` = `24c83bcd` + `main-checked` 23941d90), laptop UHD 620,
his preset, sumps seed 1, COLD, load 2.7–4.4 (2–5 other Godot processes), N = 3 per arm, interleaved

- **How "cold" is forced** (`make end-trace END_TRACE_COLD=1`): before each run the recipe deletes this worktree's own
  Godot shader cache (`~/.local/share/<override.cfg custom_user_dir_name>/shader_cache`, never the shared "Tank Squad"
  one) and runs Godot with `MESA_SHADER_CACHE_DISABLE=true` (Mesa's on-disk cache off). **Proof it was cold:** frame 0
  (the scene's first draw) took **15.6–22.3 s** in these six runs against **1.4–1.9 s** on a warm cache (E3's warm
  pair) — the whole scene compiling.

  | arm | largest frame past load (tick ≥ 15) | end ±1 s | load to tick 15 (mean, range) |
  |---|---|---|---|
  | no warm-up | 1410 / 1253 / 1747 ms (ticks 212 / 213 / 198: first laser + light) | 303 / 197 / 156 ms | 20.7 s (16.6–23.5) |
  | **warm-up** | **216 / 208 / 176 ms** | 139 / 147 / 123 ms | **32.3 s (29.2–34.2)** |

  **Cold load cost on this tree: +11.6 s** in a scripted launch (higher than `258d1f78`'s +8.2 / +8.7 s at N = 1: more
  arena and more load now). Through the real launcher the title's backdrop match has already warmed most variants:
  +1.2 s of loading screen there (stretch b, N = 1). Warm: no measurable cost (E3).
- E6 re-looked at on the merged tree (`e631b5fc`, one run with shots): the same clean end; the banner still covers the
  burst (picker's patch is decided, frames: `_agents/streams/references/round18/finale/e6-1_2_hold.jpg` (today) and
  `e6_banner_proposal.jpg`).
- Round 17's 1.7 s / 3.4 s at the final kill: **not reproduced directly** (no cold run of mine put a first live-feed
  recording or first pooled light ON the final kill; the end ±1 s was ≤ 303 ms in every cold run without the warm-up).
  The likely reading stands: cold-cache first uses that landed on the kill on a loaded laptop right after material
  changes.

### E4: it cannot come back unseen

- `make end-frame-measure` (`mk/fx.mk`): one COLD scripted elimination with vsync off; prints `END_FRAME MEASURE
  match_median_ms= match_max_ms= at_tick= final_kill_max_ms=`, then `END_FRAME JUDGED PASS|FAIL` (FAIL: a frame past
  load or within 1 s of the final kill over 1000 ms; calibrated: 128–404 ms with the warm-up, 1.5–2.8 s without) or
  `END_FRAME NOT JUDGED: <reason>` (no trace / no display; the match median over 150 ms, i.e. this machine cannot tell
  a compile from load right now). ~90 s on builder0.
- **Seen pass AND fail (lesson 253), builder0 light lane, `24c83bcd`, load ~3–7:** `END_FRAME MEASURE match_median_ms=33
  match_max_ms=90 … final_kill_max_ms=90` → **`JUDGED PASS`** (exit 0); the same with `END_TRACE_FLAGS=--no-shader-warmup`
  → `match_max_ms=1413 at_tick=235` → **`JUDGED FAIL`** (exit 2). The NOT JUDGED branches were not exercised on a
  machine (no display / median over 150 ms): read from the recipe only.
- **Request to ship (via the orchestrator, C18.6):** add `end-frame-measure` to `CHECK_ALL_EXTRA` in `mk/core.mk`
  (~90 s on builder0 plus import). It needs builder0's display; its own target already prints the NOT JUDGED row.

### E6: what he sees at the end (laptop, his preset, warm, `258d1f78`; frames in
`_agents/streams/references/round18/finale/e6-1_*.jpg`: start, hold, ramp, end, +1 s)

- The kill cam centres the last kill, DEFEAT appears at once, the burst and the fire read through the hold and the ramp,
  the picture keeps moving to the end; nothing freezes. Note: a run WITH shots stalls on each readback (0.6–0.9 s), so
  its kill cam ended by the wall bound — those two runs are for looking only; timing comes from the shot-less runs
  (60 ticks in 1.94–2.26 s, his preset and desktop's).
- **Seen and offered, not changed (picker's banner):** the DEFEAT / VICTORY banner sits at screen centre, and the kill
  cam puts the last kill at screen centre, so the banner covers the explosion the slow motion is showing for its whole
  length. A lower banner (or the kill cam framing the kill a little high) would show both.

### Stretch

- **(a) Slow motion is half a simulation: designed, not built** —
  `_agents/streams/references/round18/finale/slow_motion_design.md`. Recommended: slow the tick RATE
  (`physics_ticks_per_second = 30 f` with `time_scale = f`), so every tick is a full 1/30 s tick and slow motion
  becomes presentation; measured: the step is bit-exact for every whole tick rate 1–30 except 21. Touches the kill
  cam, `--slow-motion=`, and four readers of `Engine.physics_ticks_per_second`. The rejected alternative (rules counted
  in seconds) is a cross-stream rewrite with a new float-drift risk.

- **(b) Loading time through the REAL launcher** (title → SKIRMISH → faction → match by clicks: `shell-playtest`'s
  driver with the trace attached; laptop, his window class 1854×1011, load 0.4–2.0, N = 1 per cell; "screen" = the
  match's loading screen from up to gone, `LOAD_TIMING` from `game/ui/loading_screen.gd`):

  | cache | warm-up | screen up → gone | LOAD_TIMING total (first_frame) | where the warm-up ran |
  |---|---|---|---|---|
  | cold | on, `6b234616` | 5.3 s | 5.0 s (3.1) | **8 ms AFTER the screen was gone** (found here) |
  | cold | on, `7fd82f36` (link fix) | 7.3 s | 5.7 s (3.9) | behind the screen (2.6 s before it went) |
  | cold | off | 6.1 s | 5.9 s (4.0) | — |
  | warm | on, `6b234616` | 2.85 s | 2.5 s (0.5) | just after (warm: ~1 frame) |
  | warm | off | 2.71 s | 2.4 s (0.5) | — |

  **Found and fixed:** `MatchFxLink` looked for a new match every 0.5 s, so through the launcher the warm-up started
  after the loading screen had faded and, cold, its compile would have frozen the first visible frames of the match.
  It now searches every frame (`7fd82f36`). Also seen: the title screen's backdrop match is warmed too (most of the
  arena's variants are compiled before he even clicks SKIRMISH), which is why the cold launcher path costs far less than
  the scripted `end-trace`'s +8 s. **The cheapest second to remove** is not in the warm-up: cold, `first_frame` (the
  scene's own first draw, 3–4 s here, 14–16 s in a scripted launch) is the bulk, and it is the same compile the
  warm-up does, for the camera's view only.
- **(b), continued: HIS path, cold, no screenshots, N = 3 per arm** (`make skirmish` → faction menu → FIGHT through
  `GameLauncher`, driven by `FrameTrace --frame-trace-fight --frame-trace-seconds=75`; laptop 1854×1011, his preset;
  cold = this worktree's Godot cache emptied + `MESA_SHADER_CACHE_DISABLE=true`, every run ended with 36–39 scene
  shader files written):

  | tree | arm | loading screen | largest frame after it | faction menu's largest frame |
  |---|---|---|---|---|
  | `87d90ebc` (load 3.3–4.5) | warm-up | 8.4 / 8.0 / 9.3 s | 151 / 167 / 157 ms | **5.2 s** (the warm-up ran BEHIND THE MENU) |
  | `87d90ebc` | off | 7.9 / 7.5 / 8.3 s | 2369 / 2434 / 2436 ms (draw, < 1 s in) | 0.5 s |
  | `dee645b4` (load 1.2–4.1; menus skipped) | warm-up | 12.9 / 15.6 / 16.6 s | **224 / 163 / 144 ms** | 0.37–0.48 s |
  | `dee645b4` | off | 6.9 / 7.7 / 7.6 s | **2418 / 2205 / 2370 ms** | 0.43–0.49 s |

  - **The 0.86 s past load in the first (playtest-driven) his-path runs was the playtest's own screenshot captures**
    (all in `rest`, ~0.8 s each, in both arms, warm or cold). With no captures nothing is left: 144–224 ms, physics.
  - **Found and fixed (`dee645b4`): the warm-up was warming the faction menu's backdrop match**, with no loading screen
    in front of it: two menu frames of 5.2 s + 5.1 s, cold, before he could click — the earlier "+3.3 s" was hiding
    that. It now warms only a match with controls (`RtsControls` / `TacticalMap`); a menu's backdrop is left alone.
  - **So the honest price on his path is +7.6 s of loading screen, once per cold cache** (15.0 s against 7.4 s mean),
    for no freeze in the match (largest 144–224 ms against 2.2–2.4 s). Warm: no cost (E3).
- **The warm-up priced by parts** (`--shader-warmup-parts`, direct cold launch, `f9671e17`, N = 2; the warm-up's own
  seconds = load to tick 15 minus frame 0): full 11.2 / 10.7 s → largest past load 166 / 144 ms; without the feed
  render 3.7 / 2.9 s → **2.4 / 2.2 s stalls back**; without the lit frame 5.5 / 4.8 s → **0.8 / 1.1 s back**; without
  the unlit frame 10.8 / 8.2 s → 194 / 143 ms; off 1.2 / 1.0 s → 2.5 / 2.2 s. **Dropping the unlit frame was then tried
  on his path, N = 3 (`edbe9f8a`): no saving** (screen 17.2 / 18.2 / 17.7 s against 14.2 / 17.8 / 14.0 s full); kept.
- **The cheapest second, found by removal: the live feed's glow-off environment.** The feed renders the shared world
  under a copy of the environment with glow off (`arena_kit/ads/live_feed.gd` `_feed_environment`), a second
  specialisation of every scene shader. Warm-up OFF, cold, N = 2 (`dee645b4`), with `feed_recorded` per frame as the
  arm assertion: the feed's FIRST recording cost **2097 / 2330 ms** as shipped and **36 / 80 ms** with the feed's
  environment keeping glow (`--frame-trace-feed-glow`). So a feed that keeps glow needs no feed render in the warm-up —
  the bulk of its cost (~7.5 of ~11 s direct, cold). **Not changed: it alters what the arena screens show (glow on the
  feed picture) and costs GPU per feed frame (render's comment: glow per slot would double the feed's cost) — a look and
  laptop-cost trade, his call.** Offered as a question below.
- **(c) The loading screen naming the warm-up:** not built — `game/ui/loading_screen.gd` and `game_launcher.gd` are
  picker's. Offered to the orchestrator: a `"warmup"` stage ("Warming the lights") held until `FxWorld.warmup.done`,
  a 3-line patch in `GameLauncher.start` (await the warm-up before `screen.done()`). Worth it only for the cold case.

### Questions for the lead (in his terms; one recommendation each)

1. **"At the end of a match the game slows down for about two seconds on the last explosion. Now that it no longer
   freezes there, does that feel right, too long, or too short?"** Recommendation: leave it (2 s); the knob is
   `KillCam.HOLD_TICKS` (42 of the 60 ticks).
2. **"The DEFEAT / VICTORY word covers the last explosion while it plays in slow motion. Move the word lower so you
   see the blast?"** Recommendation: yes (picker's banner; a minimal patch through the orchestrator).

   *Frames for question 3 (the same moment, rendered twice with the game paused; `--frame-trace-feed-shot`, Law vs
   Condemned seed 92721, 30 s in, `046c68d2`):* `_agents/streams/references/round18/finale/feed_glow_pair.jpg` (the
   arena screen's picture without glow, as shipped | with glow: the team outlines and vehicle lights glow and the magenta
   wall strip hazes; otherwise the same) and `feed_glow_view.jpg` (the main view at that moment). The GPU cost of glow
   on the feed on his laptop: priced below.
   *The price* (`--frame-trace-feed-glow-ab=5 --frame-trace-uncapped`: the feed's glow alternates OFF / ON every 5 s
   inside one run, read back from the feed camera's environment each frame as the arm assertion; laptop UHD 620, his
   window and preset, Law vs Condemned seed 92721, 60 s of match, uncapped, load 1.5–2.7, N = 3 runs, `31269298`+):
   mean frame time glow OFF 45.4 / 48.5 / 49.8 ms, ON 49.5 / 49.6 / 48.0 ms → **+1.1 ms on average (range −1.8 to +4.1):
   no cost measurable at this N**; the main view's GPU 10.2–10.9 ms either way; the feed rendered 1.9–4.5 times a
   second. Not readable: the feed slot's own GPU ms (sub-viewport timings report 0 in the Compatibility renderer), and a
   per-render comparison is biased (the feed renders only on frames that are not late — its LATE_FRAME guard — so
   frames with a feed render are fast by selection).
   *In his main view* the arena screens are small (the one in `feed_glow_view.jpg` is ~90×150 px at the left edge of
   the 1854-px frame) and often show ads, not the feed (they go back to ads when the feed has nothing recent), so the
   glow difference is not visible at his pose.
   *What it would save:* with glow on the feed its shaders are the main view's, so the warm-up's feed render (≈ 7.5 s
   of ≈ 11 s cold in a direct launch) is no longer needed — most of his +7.6 s once per update; needs two changes:
   the feed's environment keeps glow (`arena_kit/ads/live_feed.gd`, unowned) and the warm-up drops its feed render.
3. **"The first time you play after an update, the loading screen can take about 8 seconds longer, once, so the match
   never freezes later. About 6 of those seconds come from the big arena screens showing the fight without the glow the
   rest of the game has. Give the screens the same glow (they'd look a little softer and brighter, and cost a little
   more on the laptop) to cut most of that wait?"** Recommendation: no change for now. The wait happens once per update,
   and the look of the screens is yours; measure the laptop cost first if you want it.

### Requests to other streams

- **ship** (via the orchestrator): `end-frame-measure` in `check-all` (above).
- **picker** (via the orchestrator, only if he says yes to question 2): the banner lower.

### Laptop windowed runs (each opens on his desktop; ~40 s each)

- 2026-10-04 15:05–15:08 PDT, 3 runs (load 6.6–8.2); 15:08–15:10, 3 runs (3.3–4.6); 15:11–15:14, 3 cold (2.5–2.9);
  15:17–15:21, 4 cold (the lights pair); 15:25–15:33, 8 cold (E2's four arms ×2); 15:34–15:43, 4 cold (warm-up
  attempts); 15:46–15:53, 6 warm (E3's pair ×3).

- 16:00–16:13, 4 cold (E5 warm-up check, shield); 16:15–16:23, 4 cold (E5 final pair); 16:23–16:26, 2 warm with
  shots (E6).

### Decisions

- The trace's report is printed by the node itself (FRAME_TRACE lines), so no new file in `tools/` (not finale's).
- A run that empties a shader cache only ever empties this worktree's own (override.cfg's custom user dir).
- The warm-up waits for the live feed (≤ 30 frames) rather than running on frame 0: it must see the whole scene.
- Two frames, not one: lit and unlit are two specialisations; a single lit frame left the feed's unlit one (measured).
- The first-use measure is cold on purpose: warm, nothing stalls, so a warm measure could never fail.
- Traces of a long series go outside `build/` (`END_TRACE_DIR`): a remote check's copy-back mirrors `build/` with
  `--delete` and erased this stream's first ~40 traces (the numbers had been written here first; lesson below).

### Known issues

- A cold first launch is ~8 s longer at load (the compiles moved behind the loading screen). The loading screen does not
  say what it is doing during those frames (stretch c, picker's screen).
- The feed's tier switch (`FxAutoQuality` → `LiveFeed._build`) rebuilds its viewports; the variants stay compiled, so
  no new cost was seen, but it was not traced separately.
- `UnitPortraits` (own world, two directional lights) and the AdBroadcast 2D feeds are not warmed; neither showed in
  any trace (portrait renders at tick ~15, ≤ 160 ms cold).

- **`end-frame-measure` in a checkout without `override.cfg` (the main one): fixed at `046c68d2`.** Cold mode's
  `sed` on the missing file exited 2 under `set -e` and killed the recipe BEFORE its refusal could print — the
  orchestrator's "end-trace exited 2" on main. Now `|| true`, and the refusal is a named line (`END_TRACE_COLD_REFUSED`,
  exit 3) that the measure reads as `END_FRAME NOT JUDGED: this checkout has no private Godot user dir`. The self-test
  carries its own throwaway cache dir (`END_TRACE_COLD_DIR`) and a third case (`END_TRACE_OVERRIDE_CFG=/nonexistent`);
  it passes in the worktree and with `override.cfg` moved aside.
- **Orphan nodes in `tests/test_fx_crowd.gd`: FIXED (in the test; the game does not leak).** Three tests left
  +112..+361 orphans each (ship's S5 report). Bisected by temporary probes: building the arena dressing and freeing it
  BEFORE ANY FRAME strands nodes the dressing cleans up on its next processed frame; with one frame between, 0 orphans,
  and the next build even reclaimed every earlier test's leftovers (−473). In the game a dressing always lives frames.
  The three tests now let the dressing (and each `setup()` rebuild) live one frame: 0 orphans in all seven tests.
- `make end-trace END_TRACE_COLD=1` (cold, the warm-up on): read `FRAME_TRACE match max_ms`; then the same with
  `END_TRACE_FLAGS=--no-shader-warmup` for the before.
- His real game: `make skirmish` as usual — nothing to notice is the result; the first match after merging will take
  a few seconds longer to load once.

### Merge notes (shared files)

- **For ship (`end-frame-measure` in `check-all`): what "cold" clears and what proves it.** It CLEARS (never
  redirects) this worktree's own Godot shader cache, `$HOME/.local/share/<override.cfg custom_user_dir_name>/shader_cache`
  (builder0's light lane: `tank_squad_finale_light`; on `main`: whatever override.cfg names — without a custom user dir
  the recipe refuses rather than touch the shared "Tank Squad" one), and runs Godot with `MESA_SHADER_CACHE_DISABLE=true`.
  The PROOF is the line `END_TRACE_COLD godot_cache_files_before=0 after=N scene_shader_files=M` (re-printed by the
  measure as `END_FRAME COLD …`): Godot writes a `SceneShaderGLES3` file only for a variant it compiled — measured, a
  WARM run wrote 0 new files (43 before, 43 after) and a cold one wrote 43 (38 scene) from an emptied folder — so
  `before=0` and `M > 0` are this run's compiles. Without that line, or with `before≠0` or `M=0`, the measure prints
  `END_FRAME NOT JUDGED: the run was not proved cold …` and never PASS. Seen: PASS 187 ms on builder0 at `0f276dc7`.
- **Load-bearing, keep both until picker's launcher hold lands:** `MatchFxLink.SEARCH_EVERY = 0.0` is what puts the
  warm-up behind the loading screen today (with 0.5 s it ran after the fade). Once `GameLauncher.start` awaits
  `FxWorld.warmup.done` before `screen.done()`, the launcher hold is the guarantee and the every-frame search is only
  latency; neither is harmful to keep.
- `game/theme/fx/fx_world.gd` (mine): adds `ShaderWarmup` and `FrameTrace` children; the prewarm hits its shield and is
  held through the warm-up. No other stream's file is touched. `mk/fx.mk`: `end-trace`, `end-frame-measure`.
- Baseline and determinism UNMOVED on every checked commit (`05df1d55ba49cde1`): presentation only.

### Green hash (latest first)

**This commit is green, merge here: `4eb6033a`** (the main-checkout self-test fix + the glow frames; builder0 2026-10-04
21:45 PDT: `>> remote: make check exited 0`, 23 targets ALL JUDGED, 2034 passed 0 failed, 7 maps unmoved). Above it:
Status only.

**This commit is green, merge here: `56aacf46`** (`d2bc4bcd`'s code + `main-checked` `f6c6a282`; builder0 2026-10-04
20:42 PDT: `>> remote: make check exited 0`, 23 targets ALL JUDGED, 2034 passed 0 failed, sim-baseline 7 maps unmoved,
ship's leak gate on). Above it: `d2bc4bcd` and later = Status only. `end-frame-measure` at `d2bc4bcd`, builder0:
`godot exited 0`, COLD proved, JUDGED PASS (210 ms); `end-frame-measure-selftest` passes (a stub that exits 134 reads
FAIL with a display, NOT JUDGED without).

Previously:

**This commit is green, merge here: `0f276dc7`** (`24c83bcd` + `main-checked` `d9372259` + the cold proof; builder0
2026-10-04 18:23 PDT: `>> remote: make check exited 0`, 23 targets ALL JUDGED, 2032 passed 0 failed, sim-baseline
7 maps unmoved, engine-log gate 10 allowed lines). Above it: `fbdb6cfe` and this Status commit, docs only.
Earlier greens: `258d1f78` (2012/0; `windowed-elimination-pair` OK, 60/60, no divergence), `24c83bcd` (2012/0),
`e631b5fc` (the 23941d90 merge; 2026/0, 7 maps unmoved). `end-frame-measure` on builder0 at `0f276dc7`: COLD proved
(before=0, 38 scene files), JUDGED PASS, 187 ms.
