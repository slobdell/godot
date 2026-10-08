> **ARCHIVED (round 22; stream closed 2026-10-07/08).** This brief ran as stream `perf` in round 22; every item is merged to
> `main` (`HANDOFF.md` *ROUND 22 IS CLOSED* has the merge table). The Status below is the worker's final report. Its
> worktree and branch are removed; evidence is under `streams/references/round22/perf/`.

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

_Updated 2026-10-07 night, stream/perf._

## FINAL REPORT (round 22, perf)

**Green:** `906287fd` (builder0, `make check` exited 0, 2218/0, 23 targets ALL JUDGED, thirteen lines + determinism
`762a0576f944f5b7` UNMOVED) holds every code change (instruments, edge markers). Above it: docs, evidence, two make
targets, and the merge of main `249e103f` (`587e2d00`); the merged tip `ff237169` is green too (builder0, exited 0, 2245/0, ALL JUDGED, thirteen unmoved, determinism `762a0576f944f5b7`): **merge here: `ff237169`** (everything above it is this Status).

**Done, with numbers (all builder0 unless said; laptop ~2.75x slower):**
- **P0 (the orchestrator's, ahead of P1): his choppy Sumps match = the sim tick at 41 vehicles in contact.** Not his
  airship flag, not the CPU's leaders, not a regression from round 20 (table below, *P0 table*). Tick by script:
  tank_brain +16.9 ms a tick, match.gd +12.1 (brains', C22.4/C22.7). The booth's +2.3 was noise (+0.35 over 8 cycles).
- **P1 (C22.3): 50 a side fails the bar by ~3x on builder0; nothing above 25 holds it on the foundry; the tick sets
  it** (~0.8 ms a tick per vehicle a side). Recommendation: cap stays 25 until brains' tick cut; laptop run after.
- **P2:** 50 v 50 = GPU 8.5 ms (live) / 18 ms (frozen, 100 alive), ui 4.4 / 11.8, fx 1.1 / 2.0, beside a tick of 25 /
  106 ms a tick. Largest GPU items: venue, ground, vehicles (~2 ms each). HUD at 50 a side 6.0 ms (perf's 0.56).
- **P3:** no equal-output cut worth shipping (reasons in *P3 / P4 decisions*). **P4:** no new preset before the laptop
  JSON (the tick is what is over). **P5:** show_dials.md, legibility.md section 9. **Stretch (a):** priced, unchanged.
- **Orders' request:** the alert strip clears the group bar (EdgeMarkers.alert_y; looked at: ten squads, his window
  and phone, `make perf-hud-shots`).

**Instruments left for the next round:** `make perf-fight` (arms main / asplayed / noleaders / asplayednoleaders /
procs / physprocs / layers / booth / noui / frozen; PERF_FIGHT=his-sumps|size), `make perf-hud`, `make
perf-hud-shots`, perf_scene `--perf-layers=none|procs|physprocs|hide:<Class>`, `--perf-drive=S`, `summary.run`,
`tools/perf_armies.py`, `tools/perf_fight_report.py` (+ `tools/test_perf_fight_report.sh`).

**Waiting on the lead / orchestrator:** the laptop runs (the orchestrator's quiet window): P0's
`make perf-fight PERF_FIGHT_ARMS="asplayed main noleaders" PERF_FIGHT_NAME=pf-arms` and
`make perf-fight PERF_FIGHT_ARMS=procs PERF_FIGHT_PHASE=2.5 PERF_FIGHT_CYCLES=2 PERF_FIGHT_NAME=pf-procs` (settles
whether his 20-60 ms of ui is laptop-only); P1's `make perf-fight PERF_FIGHT=size PERF_FIGHT_SIZES="25 30 40 50"
PERF_FIGHT_NAME=pf-cap` best AFTER brains' tick cut. JSONs to `streams/references/round22/perf/laptop/`.

**Questions for the lead:** none of perf's own (the cap is the orchestrator's call from the table).

**Requests to other streams:** brains: the tick (tank_brain, match.gd per-tick paths) is the whole of his 50-a-side
problem; the `physprocs` arm prices any cut within a run. Orders: the HUD's top lines at 50 a side are theirs
(controls.process 1.27 ms, radar 0.63 + blips 0.57, selection markers 0.63, panel 0.58, awareness 0.58; legibility.md
section 9).

**Known issues:** (1) an off-screen element chip on the bottom edge can sit behind the alert strip (the strip and the
edge chips share a height; seen in `perf-hud-desktop-30.png`, India's chip under "Bravo under fire"); pre-existing,
perf's file, small: next round. (2) builder0 p95s swing 2x under load between identical series: quote means and the
tick; p95 ratios need a quiet box. (3) Removal deltas in a live 50-a-side fight are dominated by the tick's drift;
use the frozen arm and >= 3 cycles, and read GPU/ui, not the frame.

**What to playtest:** nothing visible changed except the alert strip at ten squads (`make garage`, ten squads, wait for
an alert: it sits above the group bar's two rows).

**Merge notes:** shared files: `mk/fx.mk` (perf's), `game/theme/fx/bench/perf_scene.gd` (perf's), `game/ui/edge_markers.gd`
(perf's), `tests/test_hud_widgets.gd` (one test added), `tests/test_fx_perf_cap.gd` (new), `_agents/legibility.md`
(section 9 added), `_agents/show_dials.md` (a round-22 subsection). No edits outside perf's paths; `game/announcer`
untouched (C22.7 not used). Evidence: `streams/references/round22/perf/builder0/` (~30 JSONs, ~1 MB).

---

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

### P0 table (sent to the orchestrator 2026-10-07; evidence `streams/references/round22/perf/builder0/`)

His fight rebuilt (`make perf-fight`: his Law 24 v the Syndicate 17 from the recording's header, the Sumps, seed 5988,
laptop preset, his window 1854x1011, the next group attack-moved every 12 s), **builder0 (Iris Xe), 1 run per arm,
12 x 10 s of plain phases (~118 s of `all` frames)**, load 3-9 during the arms. Frame ms pooled over every frame; tick =
the sim's scripts, ms a TICK; ui/fx = `_process` ms a frame.

| commit | arm | avg | p95 | tick | t/f | ui | fx | gpu | vehicles |
|---|---|---|---|---|---|---|---|---|---|
| `6013c134`+dirty (main 2760d17a + perf's instruments) | asplayed (his airship flag) | 17.17 | 37.30 | 14.46 | 0.53 | 3.52 | 0.84 | 6.64 | 37->8 |
| same | main (flag off) | 19.06 | 41.07 | 15.55 | 0.59 | 3.51 | 0.88 | 7.16 | 37->10 |
| same | noleaders (`--no-element-cpu`) | 18.62 | 37.96 | 15.64 | 0.58 | 3.46 | 0.81 | 6.21 | 40->18 |
| same | asplayed + noleaders | 18.65 | 34.60 | 15.46 | 0.58 | 3.46 | 0.82 | 5.65 | 40->13 |
| `8ba5405a` (round 20's main 0a9ce446 + the same instruments) | main (leaders OFF by default then) | 26.22 | 48.29 | 18.32 | 0.81 | 3.93 | 0.94 | 7.91 | 41->7 |
| same | noleaders | 38.77 | 94.03 | 22.24 | 1.18 | 4.81 | 0.95 | 10.51 | 41->8 (load 9, 26 Godot) |

- **Neither his airship flag nor the CPU's leaders moves the frame** (all four arms within run-to-run noise, tick
  14.5-15.6 ms, ui 3.5 ms). **Round 20's main is not faster** on this fight (tick 18-22 ms): on builder0 there is no
  regression in code for this fight. What changed is the FIGHT: 41 vehicles against his foundry games' 9-13.
- **The tick is the frame's problem, and it scales with vehicles in contact:** main arm by phase, builder0: 26 ms a
  tick at 37 vehicles, 20 at 23, 14 at 15, 9 at 10 (~0.7 ms a vehicle a tick). x2.75 on his laptop = ~70 ms a tick
  at 37, which is his log (60-72 ms a tick at 21-24 mid-fight) and 2 s of tick per second of play: slow motion.
- **The tick by script** (`physprocs`, within the run, `e9b06847`, builder0, 1 run, 52 s of `all` frames, removals
  overlap so they do not sum): `ai/tank_brain.gd` +16.9 ms a tick, `match/match.gd` +12.1, `tank/tank.gd` +3.2,
  `tactics/elements.gd` +2.5, `announcer/announcer_booth.gd` +2.3 (!), `match/visibility_field.gd` +1.5,
  `match/announcer.gd` +0.9. Brains' (C22.4): tank_brain and elements; nobody's: match.gd, the booth (a request).
- **ui:** the `procs` sweep (`94fb1fab`+dirty, loaded box) found no widget over +2.1 ms a frame (rts_camera 2.1,
  arc_round_visual 1.5, block_cutaway 1.2, booth 1.0, rts_controls 0.9, unit_portraits 0.8). His 20-60 ms of ui did
  NOT reproduce on builder0 in any arm (3-9 ms all run). Open: it may be laptop-only (contention with the tick's
  threads when ticks_per_frame is pinned at 3); the laptop `procs` run below answers it.
- **For P1 this means the cap is set by the TICK, not the render**: 50 a side is ~2.4x his 41-vehicle fight.

**The laptop commands (for the orchestrator, a quiet window; ~25 min total; files `build/pf-*.json`):**
```
make perf-fight PERF_FIGHT_ARMS="asplayed main noleaders" PERF_FIGHT_NAME=pf-arms
make perf-fight PERF_FIGHT_ARMS=procs PERF_FIGHT_PHASE=2.5 PERF_FIGHT_CYCLES=2 PERF_FIGHT_NAME=pf-procs
```

### P1 (the cap's number, C22.3): builder0 series 1

`make perf-fight PERF_FIGHT=size` at `f6e47603` (main 2760d17a + perf's instruments; the sim untouched), **builder0
(Iris Xe), LOADED (load 5-19, 11-39 other Godot: three streams' checks)**, his window 1854x1011, laptop preset, gangs
(his side, driven) v condemned (CPU, leaders on), army files of exactly N a side (`tools/perf_armies.py size N`,
`--budget=100000`, the garage's FIGHT flags), 3 seeds (92721 31337 5988) x 120 s of `all` frames, 25 and 50
alternating seed by seed. Before army's CP1 his 50 fold into five squads of ten (SquadConsolidation); the count is
what costs. Vehicles = both sides alive (the census at the first phase, after a 6 s warm-up).

| arena | size | avg (3 seeds) | p95 pooled mean | tick ms a tick | ui | fx | gpu |
|---|---|---|---|---|---|---|---|
| foundry | 25 | 28.8 | 98.8 | 19.5-24.8 | 3.6-5.0 | 0.9-1.0 | 7.3-10.0 |
| foundry | 50 | 80.2 | 286.4 | 35.8-46.6 | 6.0-8.2 | 1.2-1.5 | 11.9-14.1 |
| parade | 25 | 17.0 | 54.7 | 14.6-22.0 | 2.6-5.0 | 0.7-1.1 | 5.8-7.8 |
| parade | 50 | 43.8 | 187.9 | 29.4-39.4 | 4.9-6.8 | 1.0-1.2 | 10.4-12.2 |

**Ratios 50/25 (builder0): p95 2.90 foundry, 3.43 parade; mean 2.8 / 2.6; tick 1.9 / 2.0. The bar is 1.25: 50 a
side is far OVER on builder0 already.** The tick alone at 50 a side (30-47 ms) exceeds a 30 Hz frame on builder0; x2.75
on the laptop is ~80-130 ms a tick. The frame's own cost (render + HUD + FX) at 50 a side on builder0 is ~17-24 ms of
which GPU 10-14: what remains when the tick is cut. Series 2 (25 / 30 / 40) running for the largest size that holds.

### P1 series 2 (25 / 30 / 40) and the reading

`b282d00b`+dirty (instruments only; the sim untouched), builder0, load 6-16 (other streams' checks), same protocol,
3 seeds x 120 s each, sizes alternating seed by seed. Pooled over 3 seeds (run mean / pooled p95 / tick ms a tick):

| arena | 25 (series 1) | 25 (series 2) | 30 | 40 | 50 (series 1) |
|---|---|---|---|---|---|
| foundry | 28.8 / 98.8 / 22.0 | 24.6 / 85.6 / 20.8 | 38.0 / 156.0 / 27.2 | 76.0 / 240.9 / 38.5 | 80.1 / 286.4 / 41.7 |
| parade | 17.0 / 54.7 / 17.2 | 28.2 / 87.4 / 21.2 | 24.6 / 90.4 / 22.5 | 45.4 / 152.4 / 29.2 | 43.8 / 187.9 / 33.1 |

- **Reading:** on a loaded builder0 the p95 swings 2x between two 25-a-side series (parade 54.7 vs 87.4): p95 ratios
  are noise-limited, the run MEANS and the tick are steadier. Against series 2's own 25: 30 a side is 1.55x (foundry)
  / 0.87x (parade) on the mean; 40 is 3.1x / 1.6x. **No size above 25 holds the 1.25 bar on the foundry; 30 holds on
  the parade.** The tick grows ~0.8 ms a tick per extra vehicle a side and is past 33 ms at 40.
- **Recommendation to the orchestrator (the cap is his/the orchestrator's): keep the cap at 25 a side (today's) until
  brains' tick cut lands, then re-run `make perf-fight PERF_FIGHT=size` on the laptop.** Army builds for 10 squads
  regardless (C22.3). Even 25 a side is slow motion on the laptop in contact (his Sumps match at 41 vehicles total):
  the bar is relative, and the absolute number is the tick's.

### C22.7 the announcer booth: priced, NOT a defect, no cut

`make perf-fight PERF_FIGHT_ARMS=booth PERF_FIGHT_CYCLES=8` (his Sumps fight, `2b41cfbd`, builder0, one run, the
booth's `_physics_process` removed in 8 bracketed 2.5 s phases): **+0.35 ms a tick** mean; per cycle -0.50, +0.75,
+1.85, -0.11, +0.52, -0.22, -0.41, +0.91 (signs disagree). The +2.3 of the 2-cycle sweep was the fight's own drift.
The grant (C22.7) is not used; `game/announcer/**` untouched.

### P2 (the frame at 50 a side by removal), first pass

`pf-p2` (`26ddd9a8`, builder0, 50 v 50 foundry seed 92721, 2 cycles x 2.5 s, the census falling 97 -> 25): frame
24.1 ms mean = tick 24.8 ms a tick x 0.72 ticks a frame + **GPU 8.5, ui 4.4, fx 1.1, CPU render 2.0** (draws 281).
Frame-level removal deltas swing +-36 ms with the tick (the fight changes phase to phase): unusable at 2 cycles in a
live fight. GPU/ui deltas, read with that caveat: no layer above ~1.6 ms GPU (streaks 1.6, crowd 1.2, portraits 0.9,
ground 0.9, underglow 0.9) or ~0.9 ms ui (edge markers 0.9, streaks 0.7, the HUD canvas 0.6). Second pass running
FROZEN (`--tune=match.no_damage=1`, 3 cycles: a constant census, the trailer bench's rule).

### P2 second pass: FROZEN 50 v 50 (the worst case: 100 vehicles alive all run)

`pf-p2f` (`f443dc55`, builder0, load 5-9, foundry seed 92721, `--tune=match.no_damage=1`, 2 cycles x 1.5 s, census
100 -> 100): **frame 343 ms mean, tick 105.7 ms a tick (3.9 ticks a frame, game speed 0.31)**, GPU 18.1, ui 11.8, fx
2.0, CPU render 3.6, 591 draws. At ~3 fps a 1.5 s phase holds ~14 frames: tick and ui removal deltas are noise
(+-20 / +-3.5 ms); the GPU deltas hold. **The three largest by GPU (frozen, 50 a side): the venue +2.1 ms (87 draws),
the ground +2.0, the vehicles +1.9 (46 draws)**; then effects +0.9, the HUD canvas +0.9 (232 draws), glow +0.8, the
player's controls layer +0.8 (146 draws). On the CPU side the player's controls layer (orders': radar, chips, markers,
awareness; and my unit bars) reads +4.4 ms ui (noisy).

**The P2 reading:** at 50 a side the render+HUD+FX side is ~18 ms GPU (in parallel) + ~17 ms CPU on builder0, beside
a tick of 25 ms a tick (live fight, ~0.7 ticks a frame) to 106 ms a tick (frozen, all in contact). The HUD is at its
GDScript floor since round 18 (picker); equal-output cuts in perf's paths are worth <= 1 ms there. **Nothing perf can
cut changes his 50-a-side frame until the tick is cut (brains, C22.4).** P3 therefore targets the GPU's three (venue,
ground, vehicles) only if the laptop JSON shows the laptop GPU over budget at the cap; the laptop runs decide P4.

### P3 / P4 decisions

- **The HUD at 50 a side** (`make perf-hud`, `714afe02`, builder0, headless, 100 vehicles, 30 s, 1 run; JSON
  `references/round22/perf/builder0/hud-profile-50.json`): 58.6 refs = 6.0 ms a frame. Perf's widgets: unit_bars.draw
  0.32 ms, edge_markers.draw 0.24 ms; the rest is orders' (controls, radar, selection markers/panel, awareness,
  callouts, group bar) and the camera's (nobody's). Numbers for orders in `legibility.md` section 9.
- **P3 decision: no equal-output cut shipped.** Reason: the largest items at 50 a side are the tick (25-106 ms a tick,
  brains') and GPU items that change the picture (venue, ground, vehicles ~2 ms each: presets, not equalities).
  Perf's own HUD lines are 0.56 ms; unit_bars already draws only merged rects, and its remaining lever (one triangle
  array a frame) is ~0.1 ms with a pixel risk the digest (which hashes inputs, not pixels) cannot see. Not worth it.
- **P4 decision: no new preset until the laptop JSON.** The laptop preset (round 16) stays his; what is over the bar
  at 50 a side is the tick, which no render preset touches. If the laptop runs show his GPU over budget at the cap
  the orchestrator sets, the venue/ground/vehicles levers are the candidates (a page for him: C18.3).
- **P5:** `show_dials.md` *What it costs* (round 22: the picture vs the tick) and `legibility.md` section 9 *The HUD's
  cost* written.
- **Stretch (a):** the camera's sixth-frame zoom-cap search stays priced as round 18 left it (~1.2 refs of cam.vision,
  `game/camera` nobody's; spreading it is a look-and-feel change). Today cam.vision is 5.65 refs at 50 a side, of
  which vision_call 4.45: the per-unit part grew, the search did not. No request filed: it is not where his frame goes.
- **Stretch (b):** nothing (browser parked, C18.7).
