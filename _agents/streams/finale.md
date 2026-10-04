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

_Not started. The worker keeps this section current: plan, done (with measurements), decisions, questions for the
lead, requests to other streams, known issues, what to playtest (exact commands), merge notes, and the green hash._
