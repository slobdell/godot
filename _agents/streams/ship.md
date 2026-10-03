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

_Updated 2026-10-03 ~12:45 PDT (worker, session 1). Numbers carry commit and machine. **Correction to *Where things
stand*:** "the Desktop preset keeps the clips" is false in effect — the clips folder is `.gdignore`d, so **no export
carries them, desktop included**; the exported booth is silent unless the clips sit beside the binary (code reading at
`3713fdaa`; observed by `desktop-smoke`'s control run, which boots the exported binary without them — see W5)._

### Done (commit → what; checks named below)

| Item | State | Commits |
|---|---|---|
| W1 observe | instrument built; laptop observations in the table; builder0 set queued | `43390f5c`, `ee6984a1` |
| W2 voice | on-demand fetch built behind `--web-voice=fetch` (default unchanged); page being written | `6413b280` |
| W3 guards | `export-guard` in check (static, mutation-checked); `web-match-smoke` inside `web-smoke` (runtime, mutation-checked; sound = MEASURE until guns' playback decision) | `43390f5c`, `ee6984a1` |
| W4 perf | `perf-judge` first and alone, P-core pinned, quiet-wait, flock; ALL JUDGED line; normalised MEASURE line (lent) | `bdb0fe09`, `9a575a26` |
| W5 | `garage-tour` + `desktop-smoke` in check-all; exported booth reads `voice/` beside the binary | `6413b280`, `9a575a26`, `ff774fb1` |
| W6 | `verification.md` *Bundles* + *Reading the summary line*; `remote_builds.md` *builder0 is two machines* | `ff774fb1` |

### W1: what the browser player gets (laptop rows: headless Chrome; builder0 rows pending)

| What | Observed | Conditions |
|---|---|---|
| The pack | **175.6 MB pck, 107 MB of it `_agents/` docs** → 68.2 MB after the exclude (+39.5 MB wasm, 10.1 MB gzipped; the pck barely compresses: 65.6 MB gzipped) | `3713fdaa` / `43390f5c`, laptop export, `pck_ls.py` |
| Boot | READY 6–11 s after load, no console error, no failed request | laptop, SwiftShader and GPU |
| Factions he can pick | all four in the faction menu (Condemned 27, Gangs 44, Law 24, Syndicate 17 vehicles) | `?skirmish`, laptop |
| What a Gangs/Law/Syndicate army looks like | **the Condemned's dozers**: their art is excluded and `FactionArt` falls back (a Gangs army of rat rods, gun trucks, war rigs drawn as prison buses) | `?skirmish&player-faction=gangs`, laptop screenshot |
| The booth | **subtitles only**: `ANNOUNCER no recorded clips in res://assets/announcer/clips yet: subtitles only`; PA and CALLER lines appear as HUD text | every run |
| Music + SFX | `MUSIC on: 23 beds`; **digitally silent until the fight music**: exact zeros on the audio thread from load to the pre_match → fight switch (43 s), then peak −13.3 dBFS. With Stream playback (scratch export) first sound at 13.7 s, peak −7.2. At 2 fps (SwiftShader) silent for the whole 45 s | laptop, `9a575a26` tree, N=1 per arm; relayed to guns; builder0 A/B with a real window queued (`make web-audio-ab`) |
| Title, garage | pending (builder0 `web-observe-w1`) | |

### W4: scenario_perf, measured

- Before: last check per builder0 folder since round 14: **10 judged, 7 refused** (1.68–2.14×); my baseline at
  `3713fdaa` refused at 1.84× (builder0, five streams, 1306 s).
- `make perf-cores` (`43390f5c`, builder0, load 6.7–10.5, 3 interleaved rounds): **E-cores 1.76–1.93× every run**,
  P-cores 1.10× free / 1.83–1.87× shared. µs/tick ÷ the run's reference: 12.4k–14.6k (raw 11.0k–21.7k).
- After (`perf-judge` in check): pending — wall time with/without the wait, judged rate over this round's checks.

### Decisions (one line each)

- `_agents/*` excluded from all presets without a page: it removes docs nobody loads; nothing a player gets changes.
- Voice option built = on-demand fetch (c'): the only option under every host's per-file cap and the cheapest per
  player; default OFF (C17.4).
- `web-match-smoke` lives inside `web-smoke`'s recipe (two exports into `build/web` at once would race).
- Sound is MEASURED, not required, until guns' playback decision (a red gate on a healthy tree helps nobody).

### Requests to other streams (also sent to the orchestrator)

- guns: the web build's opening silence (above), via the orchestrator 12:30.
- orchestrator: `_agents/.gdignore` — done on main as `30a2ffe1`.

### Merge notes (shared files)

- `mk/core.mk` (lent): `CHECK_TARGETS` + `export-guard`; `perf-judge` before the fan-out and its supersede rule;
  `check-all` + `garage-tour desktop-smoke`. `tools/check_verdict.sh`: the all-pass line gains `, ALL JUDGED`
  (old prefix kept). `tests/ai_scenarios/scenario_perf.gd` (lent): one additive MEASURE line + `_cpu_kind()`.
- `game/announcer/` (carve-out): `voice_fetch.gd` (new), `announcer_voice.gd` (fetch path), `announcer_booth.gd`
  (`--web-voice`, `clips_folder`, the voice-loaded line). Additive; default path unchanged.

### Green hashes

_(pending: the check of `ee6984a1` covers both core.mk changes)_
