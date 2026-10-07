# Stream: perf (his frame on the laptop at 50 a side: the number that sets the cap, then the cuts)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 16 direction* (the game is
> choppy; find the efficiencies before touching the picture) and *Round 22 direction* ("double it"; the cap is a
> measured number), `_agents/workstreams.md` *Round 22* (C22.3, C22.4), `_agents/show_dials.md` (the render dials and
> *What it costs*), `_agents/legibility.md` (the HUD's cost, round 18's equal-output cuts), the round-16 and round-18
> reports that priced his frame (`streams/archive/round16/`, `streams/archive/round18/picker.md` Status: `hud-profile`,
> the four hottest loops, 2.8 ms of a 40–50 ms frame at ~64 a side), and `tools/perf_play_report.py`. You own
> `game/theme/fx/**` (minus `order_feedback.gd`), `game/theme/cyberpunk/**`, `game/theme/arena_kit/**`, `game/ui/hud.gd`,
> `hud.tscn`, `hud_messages.gd`, `unit_bars.gd`, `unit_portraits.gd`, `edge_markers.gd`, `draw_batch.gd`,
> `hud_cost_probe.gd`, `game/ui/widgets/hud_skin.gd`, `tools/perf*`, `tests/test_hud*.gd`, `tests/test_theme*.gd` (the
> airship two included, at rest), `tests/test_fx*.gd`, `mk/fx.mk`, `_agents/show_dials.md`, `_agents/lighting.md`.
> **Lent to you, read-only for orders:** `mk/command.mk`'s `hud-profile` and `hud-digest`. **Read-only for you:**
> `mk/core.mk` (`perf-play` lives there: a change is a request with the reason), `game/control/**` and the squad-row
> files (`group_bar.gd`, `squad_chip.gd`, `selection_panel.gd`, `radar.gd`, `tactical_map.gd`: orders'; their cost is
> theirs to cut, your profile tells them the number), `game/tactics/**`, `game/ai/**` (brains prices the tick, C22.4).

## The lead's direction

2026-10-07: *"yeah double it sounds good"* (ten squads of five a side, 50 vehicles, 2000 credits), with the
recommendation he accepted: *measure 50-a-side in his frame on the laptop first and set the cap at the biggest size
that still plays smoothly.* Standing: he playtests on a weak Intel UHD 620 laptop on purpose; perf cuts ship as
hardware presets, the full look is kept on better GPUs (memory, round 16); the game is choppy = find efficiencies
before touching the picture; nothing in the sim's answer changes for a render cut (equal-output).

## Where things stand (read at `5beb038f`)

- **The number that exists:** round 18 (picker), his laptop, headless `make hud-profile`, ~64 vehicles a side: the HUD's
  per-unit work ≈ 2.8 ms of a 40–50 ms frame; round 19's measured frame cost of CPU squad leaders in his frame: +5.1 ms
  a tick mean (now ON by default, round 21 P0). Round 16's `make perf-play` is the instrument for his frame (needs a
  display; PERF_PLAY_SEEDS, _ARMS uncapped/capped, _LAYERS no_visfield/no_controls/no_audio/no_recorder, _FLAGS,
  PERF_PLAY_ARENA default sumps). Nothing is measured at 50 a side anywhere.
- **The laptop is the lead's and the orchestrator's machine**, not yours: you cannot run `perf-play` on it. Your
  measurement runs on builder0 (ratios, attribution by removal) and you hand the orchestrator the exact command for
  the laptop run (he or the orchestrator runs it in a quiet window, lesson 260) and read its JSON back from
  `build/perf-play*.json` when it is committed under `streams/references/round22/perf/`.
- FX tiers LOW/MEDIUM/HIGH (`FxQuality`, `fx_auto_quality.gd`), per-tier budgets in crowd, fires, wrecks; the four dials
  in `show_dials.md`; the HUD's draw batching (`draw_batch.gd`, round 18).
- Army's CP1 (ten squads, 2000 CR) lands early; until then a 50-a-side fight is launched with explicit flags
  (`--budget`, the opponent's archetype; ask army for the exact flags in their Status if unclear).

## Backlog (in order)

**P1. The number (C22.3), the same day.** The protocol, written down first and run on builder0 to prove it: the
garage's path (the same flags `make garage` → FIGHT uses, CPU leaders ON), foundry and parade, 25 v 25 and 50 v 50,
≥ 3 seeds × 120 s each, the camera driven the way he plays (the next group attack-moved every 12 s: `airship-view`'s
driver is one model), mean and p95 frame ms and the sim tick ms separately. Produce the one command for the laptop
(a `make` target of yours in `mk/fx.mk` wrapping `perf-play`, or `PERF_PLAY_*` values) and message the orchestrator;
the builder0 ratios 50/25 go in Status at once. When the laptop JSON lands, the table: machine, commit, size, arena,
mean, p95, tick. The orchestrator reads the cap off it (bar: p95 at 50 ≤ p95 at 25 on round 21's main + 25 %).

**P2. Where the frame goes at 50 a side, by removal.** On builder0 (and on the laptop JSON's layers): the HUD's per-unit
work, unit bars and portraits, edge markers, FX systems (bursts, lights, crowd, fires, wrecks, tracers), the dressing
(blocks, lane marks, the airship), the vision field, audio, the recorder; one removed at a time against the full frame.
A table; the three largest named.

**P3. Equal-output cuts.** For each of the three largest: a cut whose output is identical frame for frame
(`make hud-digest` for the HUD; a frame diff for FX where the FX is deterministic, else a declared visual change that
goes to the lead on a page) and its ms saved at 50 a side on builder0; then the laptop command again. Ship each ON
when the digest is equal and the saving is measured; declare anything visible.

**P4. The hardware preset.** What remains over the bar at 50 a side on the laptop after P3 becomes a preset
(`FxQuality` tier, a dial setting) chosen by the auto-quality on his GPU and left at the full look on better ones;
documented in `show_dials.md` *What it costs* with the before/after frames (a page for him only if a visible choice
is real: C18.3).

**P5. Docs.** `show_dials.md` and `legibility.md` *the HUD's cost* with round 22's numbers.

**Stretch (a).** The camera's sixth-frame zoom-cap search (round 19's held item 3; `game/camera/**` is nobody's: price
it, request the change). **Stretch (b).** The browser is parked on his word (C18.7): nothing.

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism UNMOVED (render cuts never touch the sim;
  say so in every commit).
- `make hud-digest` equal on every HUD cut; a frame diff on every FX cut; `make hud-profile` before/after.
- The laptop JSONs under `streams/references/round22/perf/` with their commit and date; every table names the
  machine, the commit, the size, the arena, the seeds and the seconds (C16.3; the laptop is ~2.75× slower than builder0).
- Look at frames of the full look and of the preset side by side before saying the preset is acceptable.

## Don't touch

`game/control/**`, `group_bar.gd`, `squad_chip.gd`, `selection_panel.gd`, `radar.gd`, `tactical_map.gd`,
`selection_markers.gd` (orders) · `game/tactics/**`, `game/ai/**` (brains) · `game/garage/**`, `game/units/**` (army) ·
`game/match/**`, `game/modes/**`, `game/camera/**`, `game/combat/**`, `game/tank/**` (nobody; a request) · `mk/core.mk`
(`perf-play`: read-only) · `arenas/**`, `game/arena/**` · `tests/baselines/**`.

## Waiting on the lead

- The laptop run of your P1 command (he or the orchestrator runs it). Nothing else.

## Status

_Updated 2026-10-07 evening, stream/perf._

### Plan (ordered)
0. **P0 (the orchestrator, 2026-10-07, ahead of P1): "really choppy" -- his Sumps match attributed by removal** on his
   seed and armies; tick (brains', C22.4) and ui (mine) separately; the table to the orchestrator today.
1. P1 the cap's number (instrument built with P0: `make perf-fight PERF_FIGHT=size`).
2. P2 removal at 50 a side, P3 equal-output cuts, P4 the preset, P5 docs, stretch (a).

### Instruments (committed)
- `make perf-fight` (mk/fx.mk): perf-play's launch with two army FILES (`tools/perf_armies.py`: his armies from a
  recording's header, or P1's N a side), `--render-preset=laptop`, `--perf-layers=none` (PERF_FIGHT_CYCLES plain
  phases), `--perf-drive=12` (the next living group attack-moved every 12 s at the enemy nearest it, camera on it --
  airship-view's driver). Arms = flag sets: `main`, `asplayed` (his airship flag), `noleaders` (`--no-element-cpu`),
  `asplayednoleaders`, `procs`, `noui`, `frozen`. Table: `tools/perf_fight_report.py` (known-answer suite
  `tools/test_perf_fight_report.sh`).
- perf_scene.gd: `--perf-layers=procs` -- every ui-bucket script's `_process` switched off in turn within the run;
  `summary.run` (every `all` frame pooled: mean, p95, p99, over34, tick per tick, ticks per frame).
- Decision: the measured fight is the garage's FIGHT flags (`--player=<file> --enemy=<file> --budget --no-pick-faction
  --seed`) via `make skirmish`'s path, not `--garage`: the garage cannot field 50 before army's CP1, and the flags are
  what FIGHT sets (garage_mode.gd `_start_skirmish`).

### P0 findings so far
- **His file read again:** `perf_trace.gd`'s `tick_ms` is ms a TICK (`tick_usec / ticks`), not a frame. His Sumps
  match: 20 ms a tick at 41 vehicles (t=7 s), 60-72 ms a tick at 21 vehicles (t=64-98 s), 21-43 ms a tick at 14 after
  the end -- on the laptop. At 30 Hz that is 0.6-2.2 s of tick a second: the battle can only run in slow motion
  (game_speed 0.35-0.6). ui 4 -> 20-60 ms a frame. Both grow while the vehicles halve.
- **`procs` sweep, his fight, main arm (no airship flag), builder0 (Iris Xe, LOADED: load 13-22, 36 other Godot),
  `94fb1fab`+dirty, seed 5988, 1 run, 155 s of `all` frames:** frame avg 21.6 / p95 39.7 ms; **tick 13.5 ms a tick**
  (32 ms a tick at 35 vehicles, 9-10 ms at 8); ui 4.45 ms; no ui script above +2.1 ms by removal (rts_camera 2.1,
  arc_round_visual 1.5, block_cutaway 1.2, booth 1.0, rts_controls 0.9). Without his airship flag the ui did NOT grow
  (3-9 ms all run): the tick is the frame's problem, and it is brains' (C22.4).

