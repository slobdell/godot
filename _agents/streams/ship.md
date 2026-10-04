# Stream: ship (what the browser player actually gets, and a check that judges everything it runs)

> Read `_agents/orchestration.md` (the worker contract), `_agents/verification.md`, `_agents/remote_builds.md`,
> lesson 239 in `orchestration.md` (the browser build was dead for eleven days and nothing said so),
> `_agents/streams/archive/round16/booth.md` (merge notes: the Web preset's exclude) and `archive/round16/play.md`
> (`web-smoke` into `check`), `_agents/workstreams.md` *Round 17*. You own `export_presets.cfg`, `mk/web.mk`, the web
> smoke scripts under `tools/`, `tools/slot.sh`, `tools/remote.sh`, **`mk/core.mk`'s `check` / `check-all` composition
> (the orchestrator's file, lent to you this round)**, the `ai-perf*` / `scenario_perf` targets of `mk/ai.mk` and
> `tests/ai_scenarios/perf_nominal.json` (lent by brains), `_agents/verification.md`, `_agents/remote_builds.md`. One
> carve-out: the clip-loading path of `game/announcer/announcer_booth.gd` / `announcer_voice.gd` (where the clips come
> from on the web — additive, listed).

## The lead's direction

No words of his on these items; he put the stream in round 17 on 2026-10-03 (*"I want all 5"*). What binds it from his
earlier words: *"The announcers absolutely make the game"* (2026-10-02) — so a build with a silent booth is missing
the thing he says makes the game; and the cost strategy in `vision.md` / `server_management.md` (free static hosting
for the web build, so its download size is a real cost and **the web pack's size is his call**).

## Where things stand (read at `6adf94bb`)

- **The Web preset excludes the announcer's voice.** `export_presets.cfg` `Web` `exclude_filter`: `tests/*, build/*,
  assets/pipeline/*, game/theme/kitbash/*, game/theme/neon_kit/*, game/theme/factions/gangs/*,
  game/theme/factions/law/*, game/theme/factions/syndicate/*, assets/announcer/clips/*, assets/announcer/masters/*`.
  `assets/announcer/clips` is **80 MB**; the booth's default is `res://assets/announcer/clips`
  (`announcer_booth.gd` `DEFAULT_CLIPS`), and `AnnouncerVoice.load_clips` returns false "(and silence) when there are no
  clips yet". So the expectation is a browser match with no caller, no colour and no PA — **an expectation from reading
  the preset, not yet an observation**: nobody has listened to the web build. The same preset excludes three factions'
  art; what a browser player sees for the Gangs, the Law and the Syndicate is equally unobserved.
- **`web-smoke` is in `check`** since round 16 (`mk/core.mk` ~294; 21 targets): it boots the export in headless Chrome,
  screenshots it and fails on errors. It does not start a match, and it does not know whether anything can be heard.
  `garage-web-smoke`, `web-net-smoke`, `web-relay-smoke`, `web-host-smoke` are in `check-all` or standalone.
- **`scenario_perf` refuses to judge under load.** It measures its reference workload first and refuses its budget when
  the box is busy (`mk/ai.mk` ~16, round 14); under five or six streams it refused in most full checks of rounds 15 and
  16 (brains: `perf_reference` 1.68–1.93× all night; it judged PASS once at 1.17×). A check that usually declines to
  judge one of its targets is a check with a hole in it. builder0 runs 3 heavy slots (`TANK_SQUAD_SLOTS=3`,
  `tools/slot.sh`); `CHECK_JOBS` fans the targets out.
- **The garage tour is outside `check`**, and in round 16 it caught a regression nothing else did (white portraits from
  a change-only redraw and a freed texture). It needs a display (builder0 has one).
- **A `Linux Desktop` preset exists** (`make export-desktop`, `mk/assets.mk`; it keeps the clips and every faction's
  art); no target BOOTS the exported binary and it is in neither `check` nor `check-all`. He plays from the editor binary (`make skirmish`), so a broken
  desktop export would also go unseen.

## Backlog (in order)

- **W1. Observe it: what does the browser player get?** Export, serve, and play a skirmish to first contact in headless
  Chrome (and once in a real browser window on builder0 if headless audio says nothing): does the booth speak, do
  subtitles appear, what does the log say when the clips are missing, which factions can he pick and what do they look
  like, do the sound effects and the music play. Screenshots looked at; the facts as a table in Status, each row
  observed or marked unobserved. Send it to the orchestrator.
- **W2. The options for the voice, each built far enough to be priced, on a page.** At least: **(a)** the clips in the
  main pack (size and first-load seconds on a stated connection); **(b)** a web-grade re-encode (what bitrate still
  sounds like the booth — he judges by ear: put the same three lines at each bitrate on the page) in the pack;
  **(c)** a separate voice pack fetched after the title screen is up (`ProjectSettings.load_resource_pack` on the web,
  or per-clip HTTP fetch), the game playable before it lands and the booth joining when it does; **(d)** as today, with
  subtitles made the deliberate experience. For each: pack MB, time to the title, time to the first spoken line, what
  breaks offline, and what free static hosting allows (file-size and bandwidth limits of the hosts `server_management.md`
  names). **Build the one you recommend behind a switch**, default unchanged until he taps; the same question, same
  page, for the three excluded factions' art. One Artifact page (`artifact-design`, `artifact-capabilities`, `db` for his
  taps; C15.2); the link to the orchestrator.
- **W3. The smoke asserts what the player gets.** After W1: `web-smoke` (or a sibling in `check`) starts a match and
  fails if the booth is expected to speak and no clip loads, if a sound effect or the music fails to load, or if a
  pickable faction has no art — the class of lesson 239: an export exclude silently removing something the game reaches
  for. A static guard too: every `res://` path the game loads at runtime against each preset's excludes (it would have
  caught both of 2026-09-22's breaks). Mutation-check each (exclude something, the guard goes red).
- **W4. A check that judges `scenario_perf` every time.** Measure first: across the round-16 check logs on builder0,
  how often it judged versus refused, and at what load. Then make refusal rare by construction — the perf scenario runs
  first and alone holding every slot before the fan-out, or in a quiet slot the wrapper waits for — and report the
  check's wall time before and after (one loaded, one idle; the round's checks are the load test). It must still
  refuse rather than lie when the box is truly busy, and say so in the summary line the orchestrator reads
  (`ALL JUDGED` versus named refusals). This round's five streams are the test: the judged rate over their checks.
- **W5. The tour and the desktop export, priced for `check-all`.** `garage-tour` minutes on builder0 and what it
  asserts today; put it in `check-all` (or `check` if it is cheap and stable — say which and why). An `export-desktop`
  + boot smoke (does the exported binary reach the title and a match's first tick) in `check-all`.
- **W6. The rules where a fresh agent finds them.** `verification.md` and `remote_builds.md` say what is now in `check`
  and `check-all`, what each smoke proves and does not, and how to read the summary line.
- **Stretch.** The web build's frame time on his path (a browser on builder0's desktop with `--perf`, one number with
  its conditions) so the next round knows how far the browser is behind native; the Android export's first blocker
  (`roadmap.md` *Next*: an Android paid app) as a written list, nothing built.

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe), `make remote T=check-all` once before you report done, the smokes' screenshots
opened and looked at. The sim baseline is UNMOVED by everything here: pre-register it. **You are changing the
instrument every other stream trusts**: land `mk/core.mk` changes in small commits, each with a check run before and
after, and message the orchestrator before the first one merges so the other four can be told.

## Don't touch

`game/announcer/**` beyond the clip-loading carve-out, and no announcer generation · `game/ai/**`, `game/tactics/**`,
the rest of `mk/ai.mk` (brains) · `game/match/**` (sim) · `game/arena/**`, `arenas/**` (yard) · `game/theme/audio/**`,
`assets/audio/**` (guns; guns will report its pack MB to you). No money: hosting is priced, not bought.

## Waiting on the lead

- His taps on the W2 page (the web voice; the web factions' art). The pack size is his call.

## Status

_Updated 2026-10-03 21:36 PDT (by `date`; worker, session 1). Every number carries its commit and machine._

**Correction to *Where things stand*** ("the Desktop preset keeps the clips"): the clips folder is `.gdignore`d, so **no
export carries them, desktop included**. Observed on builder0 by `desktop-smoke`'s control run: the exported binary
without `voice/` beside it logs `ANNOUNCER no recorded clips … subtitles only`; with it, `ANNOUNCER voice: 3112 clips`.
**The desktop voice is ON by default** (a defect fixed, not a lever; the orchestrator agreed): `make desktop-smoke`
exports and puts `build/desktop/voice/` (80 MB, the clips as recorded) beside `tank_squad.x86_64`; the lead's Q4 tap
(`beside`, 21:11 UTC) keeps it as recorded.

### The lead's taps (W2 page https://claude.ai/artifact/CzFkHbMyKs7cuPM3oQnbWR, db `choices`)

C15.2 reads: by ship at 2026-10-03 14:12:45 PDT (two taps); by the orchestrator at 14:16:41 PDT (all five) and 17:48
PDT (Q5's re-tap). **The page writes ONE collection, `choices`** (docs voice, bitrate, factions, desktop, mix), so a
list of `choices` is a complete read (lesson 248). Page
republished v1-v9 (last 16:05 PDT) showing each as applied, being built, or set aside.

| Question | His tap (UTC) | What it did |
|---|---|---|
| Q1 web voice | **D** (each line fetched the first time), 21:14:02 | range 2: ON on the web by default; the manifest in the pack, the voice joins at boot; opening prefetch |
| Q2 bitrate | **24k**, 21:13:46 | range 2: `tools/web_pack/voice_web.py` (ffmpeg libvorbis `-ac 1 -ar 22050 -b:a 24k` from the as-recorded clips, incremental) → 61.4 MB served beside the page |
| Q3 factions' art | **later** (second pack), 21:12:26 | range 1 (merged): `packs/factions.pck` 21.3 MB patch, loaded at runtime |
| Q4 desktop voice | **beside** (as recorded), 21:11:49 | already the build |
| Q5 browser mix | ~~stream~~ 21:16:07, set aside 14:56 PDT (made on guns' wrong Stream measurement; original in `references/round17/ship/` and the orchestrator's 14:16 dump -- the page's re-tap REPLACED the db document) → **sample-duck** 23:59:33 UTC (16:59:33 PDT; read by the orchestrator 17:48 PDT) | decided: Sample with guns' script duck, which is what is built (guns, on main). Option A has been `sample-duck` since page v7, same three options in the same order through v13 |

### Done

- **W1 observed.** `tools/web_smoke/observe.mjs` (+ `make web-observe`, `web-observe-w1`, `web-audio-ab`): screenshots,
  console, requests, an audio-thread energy tap (AudioWorklet), fps, every source start and AudioContext state. The
  table is below. The pack: **175.6 MB, 107 MB of it `_agents/` docs** → 68.2 MB (`43390f5c`, laptop exports).
- **W2.** Options priced on the page (5 questions; hosts: Cloudflare Pages cannot host the build at all, 25 MiB/file;
  GitHub Pages 100 MB/file; itch.io 1,000 files). Built: **D** per-line voice fetch (`?web-voice=fetch`, OFF): browser
  fetch(), opening prefetch (gangs v law on the yard: 273 clips, 6.79 MB), LATE_S 1.5 s; measured at 4 fps on the
  laptop GPU (the browser's match rate there): 11 of 14 lines spoken 0.44-1.09 s late, 3 missed at 1.36-1.40 (before
  LATE_S went 1.2 → 1.5). **Q3's second pack** (built, then ON by his tap). Bitrate ladder: re-encoding saves 16-34 %
  (every clip carries ~3.5 KB of Vorbis header; no Opus in Godot 4.7).
- **W3.** `export-guard` in `check` (static; every game script, every `res://` literal, scenes' ext_resources,
  project.godot's paths and `default_bus_layout.tres`, against every preset; 0 disagreements against the real pack
  over 732 files; mutation-checked: both 2026-09-22 breaks, music/sfx/cyberpunk excluded, a deleted fallback, a stale
  declaration, the bus layout excluded). `web-match-smoke` inside `web-smoke`: boot, no console error/failed request,
  music found, armies, booth = declared, packs loaded, sound **MEASURED** (`web_expect.json "sound": "measure"`) until
  guns' bus-layout fix is on main, then flipped to require in its own commit (orchestrator's order).
- **W4.** `perf-judge` before check's fan-out: scenario_perf pinned to builder0's P-cores, a wait (≤120 s ×3) for them,
  a machine-wide flock; refuses only when the box never quietens; supersedes the suite's own loaded refusal; summary
  `>> check: N targets, all passed, ALL JUDGED [ctx]` (old prefix kept) or `N passed, M NOT JUDGED` + named rows.
  Plus `MEASURE ai_usec_per_ref_ms` (lent scenario_perf.gd, not judged; for the orchestrator's spread at close).
- **W5.** `garage-tour` + `desktop-smoke` in `check-all`; the exported booth reads `voice/` beside its binary.
- **W6.** `verification.md` *Bundles* + *Reading the summary line*; `remote_builds.md` *builder0 is two machines*,
  *The light lane*, scratch-script rules.
- **Asked for during the round, built:** the light lane (`make remote LIGHT=1`: own slot pool, own builder0 folder,
  own copy-back `build/light/build/`, ports +500, own Godot user dir; `--jobs` answers 1); its soak below.

### W1 at the END of the round vs the START (re-observed 21:24-21:36 PDT on the CP2 tree, ship `1700bf77` = main-checked `90c289f2` + ship's docs; builder0, headless Chrome/SwiftShader at 2-3 fps, `make remote LIGHT=1 T=web-observe-w1`; reports in the scratchpad `w1-final/`)

| | Start of round (`3713fdaa`) | End of round (`1700bf77`, everything on) |
|---|---|---|
| Main pack | 175.6 MB (107 MB of it docs) | **90.1 MB** (+21.3 MB factions pack after boot, kept; voice clips line by line) |
| Boot | READY, no console error | READY 7-15 s, no console error, no failed request, every page |
| Sound | none until the fight music (every sample-mode sound silent) | **every page sounds**: first sound 5-13 s after READY (bare, menu, title, garage, 4 matches), peaks -6.5 to -23 dBFS, 400-600 sources a match |
| Factions | Gangs/Law/Syndicate drawn as the Condemned | own art: pack fetched in ~7 s (26 s once); frames at 90 s show the Law's APCs vs the Condemned's buggies |
| Booth | subtitles only | the voice joins at boot; at 2 fps 1-2 lines spoken and 1-2 too late per 90 s match (at ~57 fps: 24 of 25 on cue) |
| Title / garage | (not observed at the start) | both sound; the title loads no pack (a menu, not a match), the garage page none within its 10 s |

### What the browser player gets NOW (main after 9b404030 + guns' ranges; observed, conditions per row)

| What | Observed |
|---|---|
| Download | main pack **88 MB** (guns' sounds + the voice's 1.7 MB manifest; 12 MB under GitHub Pages' 100 MB/file -- a standing constraint) + 39.5 MB wasm (10.1 gzipped); then, after boot, `packs/factions.pck` 21.3 MB once (kept), and the voice's clips line by line (24 kbit/s set, 61.4 MB on the host; the opening ~6.8 MB prefetched) |
| Boot | READY 5-14 s after load (builder0 SwiftShader and laptop GPU), no console error |
| Factions | all four pickable; Gangs/Law/Syndicate in their own art once the pack lands (fetched in 5.8-34 s depending on frame rate; from the device after); a match started before it lands uses the Condemned's models |
| Sound | every sound plays (guns' bus layout): first sound 6.2 s after READY on builder0 SwiftShader, 9.7/15.4 s locally; 52-72 effects started per 45 s; peak -11 to -14 dBFS; Sample mode with guns' script duck under the booth (his Q5) |
| The booth | joins at boot (manifest in the pack). At small armies (~55-59 fps) every line spoken on cue (24/25, worst 0.11 s late); at his army size the browser runs **2-5 fps** and a fetched clip arrives seconds late (16-21 s observed at 2 fps), so a first match is mostly subtitles and later matches speak more |
| Frame rate at his army size | real Chrome window on the laptop 3.3 fps mean (2-5 in the fight); headless laptop GPU 3.6-4.0; builder0 window ~2; desktop game ~20-25. Round-18 candidate (orchestrator) |
| Joining a server in the browser | `?connect` drops a connection the server accepted at low frame rates (the 3 s WebSocket handshake; flaky on the launch tree too: 1 of 3); sim's 9f6976cd raises it to 15 s (2 of 2 in a scratch test) |
| The kill cam | lasts several times longer at low frame rates (inferred from the music clock: ~1.3 s lost at 58.7 fps, ~7-8 s at 15.3 fps); sim's 9f6976cd bounds it in real time |

### W1: what the browser player gets (builder0 `c2dd1737`, headless Chrome/SwiftShader unless said)

| What | Observed |
|---|---|
| Pack | 68.2 MB pck + 39.5 MB wasm (10.1 gzipped); +13.6 MB with guns' sounds (orchestrator relay) |
| Boot | READY 5-12 s after load in every page (bare, title, menu, garage, 4 faction matches), no console error |
| Bare URL | OfflineMode (one tank vs a bot), not the title: the title is `?title`, the garage `?garage` |
| Factions | all four pickable; Gangs/Law/Syndicate drawn as the Condemned's prison buses (laptop frame) → their own art with the second pack (laptop GPU frame: Road Gangs' trucks) |
| Booth | subtitles only (`no recorded clips`); with `?web-voice=fetch` the voice joins and speaks (laptop GPU) |
| Sound | **every sample-mode sound inaudible** (924 sources started in 60 s, AudioContext running from creation, autoplay allowed + a click); only the engine-mixed fight music heard; first sound 16-60 s or never (builder0 SwiftShader 46-50 s ×3; builder0 GPU headless 16-35 s ×3; builder0 window at 2 fps 47.5/60.0/never; laptop GPU 29-60 s ×6). Stream mode 8-18 s. **Cause found by guns with this observer: a runtime `set_bus_send()` silences every sample playback; fixed on guns' branch (`96c37137`), not on main yet** |
| Frame rate (stretch) | a 40-v-24 browser match: **2 fps** SwiftShader (builder0, laptop), **4-11 fps** on the laptop's GPU headless, 50-60 fps in menus; native on the laptop is ~20-25 fps on his path (round 16 record). Sample vs Stream frame time: 204 vs 195 ms mean (N=3 each, laptop GPU, `d2ce2399`): no measurable cost |

### W4: judged vs refused

| Run | Commit | Load | Verdict |
|---|---|---|---|
| my baseline check (unpinned, suite only) | `3713fdaa` | 5 streams | refused 1.84× |
| perf-judge in check | `9a575a26` | 2.41 | **JUDGED PASS 1.07×** after 48 s wait; the suite's own run refused 2.03× in the same check |
| perf-judge in check (soak 1) | `ccb1cae1`+dirty | 10.98 | **JUDGED PASS 1.07×** after 84 s wait; suite refused 2.03× |
| other streams' unpinned round-17 checks (last per folder) | various | — | 4 of 6 judged (two at 1.48×, just under 1.5), 2 refused (1.84, 1.85) |

`make perf-cores` (`43390f5c`, builder0, load 6.7-10.5, N=3/arm): E-cores 1.76-1.93× every run; P-cores 1.10× free,
1.83-1.87× shared. Wall time of perf-judge in check: 65 s and 100 s (incl. 48/84 s waits).

### After main f93f3cb4 (guns' browser fix)

- **sound=require** (`588d37e6`): heard above -60 dBFS, first sound within 30 s of READY, at least one sound EFFECT
  started (a short buffer), not only music. Local SwiftShader, merged tree, 2 runs: first sound 9.7 / 15.4 s after
  READY, every block loud, 65 / 52 effects. Mutation: two pre-fix reports fail.
- **Joint run, voice D + guns' script duck** (`references/round17/ship/joint_voice_duck.txt`, 17:35-17:47 PDT, laptop
  GPU, small armies ~54-57 fps): 24 of 25 lines spoken, worst 0.11 s late, peak -2.7 dBFS; the battle alone dipped 11.1
  and 18.2 dB under the two isolated lines (design 12.7 dB at MID). N=2 (the booth rarely pauses 1.5 s).
- **Browser kill cam** (sim's fix merged): timed from the music director's scaled clock (an inference; the kill cam
  prints nothing): ~1.3 s lost at 58.7 fps, ~7-8 s at 15.3 fps (CPU throttled 8×): the tick-counted slow motion lasts
  several times longer at low frame rates. Sent to sim via the orchestrator (17:35 PDT).
- Main pack 88 MB on the merged build (guns' sounds + the 1.7 MB voice manifest): 12 MB under GitHub Pages' cap.

### Decisions (one line each)

- `_agents/*` excluded from every preset without a page: docs nobody loads; nothing a player gets changes.
- Voice option built = D (per-line fetch): the only one every host serves; OFF until he taps.
- Factions' art as a patch pack (Godot's `--export-patch` against the main pack), not a hand-listed preset.
- `web-match-smoke` inside `web-smoke`'s recipe: two exports into `build/web` at once would race.
- desktop-smoke reports `ERROR: N resources still in use at exit` (the scripted quit at tick 90) as KNOWN, not failed.
- LATE_S 1.5 s (from 1.2) on the laptop measurement; MAX_IN_FLIGHT 6 (a browser's per-host limit).

### Windowed runs on the laptop (the lead's desktop)

- 2026-10-03 ~15:36 PDT: ONE real Chrome window (~70 s, 1280×720) opened on the laptop's desktop by the observer, to
  measure the browser build's frame rate in a real window at his army size (the orchestrator's frame-rate row).

### Known issues

- The exported desktop binary leaks 1-2 resources at a scripted quit (above).
- The web voice (D) misses lines at very low frame rates (2-4 fps); its latency is frames, not network.
- Window-mode observations on builder0 run at 2 fps (its desktop crawls); no "normal frame rate" browser row exists
  from builder0. The laptop's own windowed browser was not used (it opens on the lead's desktop).

### Requests to other streams (all sent to the orchestrator)

- guns: the browser silence (found + fixed by guns); Q5 is guns' setting.
- sim: `check-all` runs a one-process target in its own slot like any target (the light lane is only for separate
  `make remote` runs); send the `windowed-repeat` pair and I add it.

### Stretch

- Web frame time on his path: in the W1 table (headless GPU, laptop; a real window on the laptop not run: his desktop).
- **Android export, the first blockers (nothing built):** (1) `make bootstrap` extracts only linux + web templates, so
  `android_*.apk` / `android_source.zip` are missing; (2) no Android SDK on the laptop or builder0 (JDK 17 is there;
  `adb` on the laptop); editor settings need `android_sdk_path` / `java_sdk_path`; (3) no Android preset (package name,
  arm64-v8a, INTERNET permission for relay/broker); (4) **textures**: the project imports only desktop VRAM formats;
  Android needs `rendering/textures/vram_compression/import_etc2_astc=true` and a full re-import (minutes, a bigger
  `.godot`); (5) a release keystore and a Play Console account are money/accounts (lead gate 3); (6) the voice: res:// is
  not a filesystem on Android, so the clips need the D path (user:// cache) or an asset pack, and the Play base size
  (200 MB) rules the pack; (7) touch: the round-2 grammar exists, untested on a device. Renderer is already
  Compatibility (GLES3), which Android runs.

### Merge notes (shared files)

- `mk/core.mk` (lent): `CHECK_TARGETS` + `export-guard`; `perf-judge` before the fan-out + its supersede rule; `check-all`
  + `garage-tour desktop-smoke`; `make remote LIGHT=1`. `tools/check_verdict.sh`: `, ALL JUDGED` on the all-pass line.
  `tools/slot.sh`, `tools/remote.sh`: the light lane (inert without LIGHT=1). `tests/ai_scenarios/scenario_perf.gd`
  (lent): one additive MEASURE line + `_cpu_kind()`.
- `game/announcer/` (carve-out): `voice_fetch.gd` (new), `announcer_voice.gd` (fetch path, LATE_S), `announcer_booth.gd`
  (`--web-voice`, `clips_folder`, the voice-loaded line). `game/web/web_packs.gd` (new, unowned path) + `game/main.gd`
  one additive line. `export_presets.cfg`: `_agents/*` excluded; new patch preset `Web Factions`.

### W4 (final): judged rate

perf-judge (pinned, first, alone) judged **4 of 4** checks of range 1 and the range-2 check made it 5 of 5 (PASS
1.07×, 1.07×, 1.14×, 1.47× after one refusal at 2.13×, 1.18×; waits 48/84/48/108/24 s; 65-158 s a check), while
the suite's own unpinned run in the SAME checks judged 1 of 4 (refused 2.03×, 2.03×, 1.99×); main's unpinned check
after sim's merge refused 2.01× (orchestrator): unpinned 1 of 5. Check wall time on a loaded builder0 1385-1576 s
against 1306 s for the baseline without it. Normalised MEASURE ai_usec_per_ref_ms: 13580, 13187, 15377, 14360,
12761, 15286 -- a ~20 % spread, NOT tight enough to judge on; it could only catch a regression well over 20 %.

### Q5 frame-rate sweep (references/round17/ship/q5_stream_sweep.txt)

Laptop, headless Chrome on the GPU, his army size (40 v 24, Yard, seed 7), guns' 4448e2c7 tree exported from a scratch
copy, CPU throttle 1/2/4×, N=2 interleaved, mode asserted per run (24 of 24 correct). At 1× the match runs 3.4-4.9
fps: Sample 100 %; Stream 50 ms 6-7 %, 150 ms 24-38 %, 300 ms 50-74 % of the time with sound; throttled lower, worse.
Real window on the laptop (Sample, same match, 15:34 PDT, one ~70 s window on his desktop): **3.3 fps** mean (2-5 in
the fight); the game's own overlay read 10 fps / 101 ms at one moment (unreconciled). The browser's frame rate is filed
as a round-18 candidate (orchestrator).

### W4: every judged-or-refused reading (builder0)

| Check | Commit | perf-judge (pinned, first) | suite's own unpinned run | wall |
|---|---|---|---|---|
| ship | 9a575a26 | PASS 1.07× (48 s wait) | refused 2.03× | 1385 s |
| ship soak 1 | ccb1cae1+dirty | PASS 1.07× (84 s) | refused 2.03× | 1523 s |
| ship soak 3/1 | 64a7e769 | PASS 1.14× (48 s) | refused 1.99× | 1396 s |
| ship soak 3/2 | 64a7e769 | refused 2.13×, PASS 1.47× (108 s) | judged | 1536 s |
| ship range 2 (old base) | 88b70106 | PASS 1.18× (24 s) | (superseded) | 1576 s |
| ship range 2 | 576cc6f1 | refused 1.99×, PASS 1.30× | (superseded) | 1329 s |
| ship tip | 9b404030 | PASS 1.09× | refused 2.84× | 1820 s |
| check-all's check | 9b404030 | refused 1.81×, PASS 1.35× | **judged FAIL** (ref 1.46×, 21444 usec: false) | -- |
| ship fix | 6da99d45 | PASS 1.46× (120 s) | refused `unpinned` (by design now) | 1806 s |

Pinned: judged 9 of 9 checks. Unpinned (same checks + main's after sim's merge): judged 2 of 9, one of them a FALSE FAIL.
The baseline check without perf-judge: 1306 s (3713fdaa, five streams); perf-judge costs 16-288 s a check.

### Green hashes

- **Range 1: this commit is green, merge here: `64a7e769`** -- soak on builder0, tree clean at both launches: round 1
  `>> remote: make check exited 0` | `>> check: 23 targets, all passed, ALL JUDGED [test x4, lint -P6, 2 at once,
  builder0]` (15:20 PDT, 1396 s, 1925/0, sim-baseline `05df1d55ba49cde1` unmoved), 21 light web smokes beside it all
  passing; round 2 the same verdict (15:53 PDT, 1536 s, 1925/0); its light runs after ~15:23 carried my in-progress
  range-2 tree (not evidence for `64a7e769`; they found two range-2 bugs). **MERGED to main** as `ddf710b2` (15:56 PDT).
- **Range 2 on top of main `ddf710b2`: this commit is green, merge here: `576cc6f1`** -- `>> remote: make check exited 0` |
  `>> check: 23 targets, all passed, ALL JUDGED [test x5, lint -P6, 2 at once, builder0]` (17:30 PDT, 1329 s, 1938/0,
  baseline unmoved; perf-judge refused 1.99× then PASS 1.30×). `check-all` of `99813480` (+ an identical .uid
  sidecar) running since 17:30.
- **Tip: this commit is green, merge here: `9b404030`** (18:55 PDT, 1820 s, 1979/0, ALL JUDGED) -- MERGED to main as
  `fa7a1c9c` (18:58 PDT).
- **The scenario_perf fix: this commit is green, merge here: `6da99d45`** (20:41 PDT, 1806 s, 1979/0, ALL JUDGED;
  the unpinned run refused and was superseded). After it, unchecked: `8c027ee8` (the supersede line names its reason;
  the copy-back skips build/desktop).
- (history) After 576cc6f1: main `f93f3cb4` merged (`9eca36de`: guns' bus layout, script duck, web trim);
  `588d37e6` sound=require; `74e1128a` the joint-run evidence.
- Range 2 (`3ba814b7`, `88b70106`) was first checked on the OLD base: `>> remote: make check exited 0` | `>> check: 23
  targets, all passed, ALL JUDGED [test x5, lint -P6, 2 at once, builder0]` (16:30 PDT, 1576 s, 1925/0, baseline
  unmoved); its browser smoke on builder0: voice joined, 1 line spoken (1.39 s late), factions pack in 7.3 s. To be
  re-checked on top of main after the orchestrator announces the merge, with `windowed-elimination-pair` in check-all.
