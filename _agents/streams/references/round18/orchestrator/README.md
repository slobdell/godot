# The orchestrator's laptop runs, round 18

## perf-play, the Parade Ground against the Sumps (2026-10-05 03:02–03:09 PDT) — NOT a quiet window

`make perf-play PERF_PLAY_SEEDS=<seed> PERF_PLAY_ARENA=<map> PERF_PLAY_ARMS=uncapped` at main `773ab8b7`
(main-checked `b24ff1aa` + finale's hold contract), his window 1854x1011, desktop preset, Law v Condemned, his launch
flags, interleaved sumps / parade per seed, after one throwaway run to warm the shader cache. Sound went to a
temporary null sink (`PULSE_SINK`), unloaded afterwards; his default sink was unchanged. His desktop had been idle
96 minutes; the screen does not blank.

**Contaminated:** two of brains' headless probes were running on the laptop throughout (`2 other godot` on every
run line; load 2.8–3.3). The absolute frame times (69–105 ms) are about twice what he sees and mean nothing. What the
pairs can say, with that caveat and N=2 seeds: under the same load parade was not slower than the Sumps in either
pair (avg frame 68.8 v 90.3 ms; 92.9 v 105.4 ms), with fewer vehicles alive on parade because its fights go faster
(31 v 37; 33 v 38), and the GPU's share was the same within about 2 ms (15.5 v 14.8; 13.6 v 15.4 ms). A windowed
match is not repeatable past ~tick 150, so two runs are two fights. To be re-run in a real quiet window.

Files: the four JSONs and `perf-play-parade-v-sumps-0305.txt` (tools/perf_play_report.py's table).

## perf-play, the Parade Ground against the Sumps, RE-RUN in a quiet window (2026-10-05 03:28–03:33 PDT)

The same command at main `776a759e` (main-checked `b24ff1aa` + finale's hold contract, ship's final plumbing, brains'
D5b), same window, flags and seeds, sumps then parade per seed, sound to a temporary null sink (removed after; his
default sink unchanged). **No other Godot was alive before or after any of the four runs** (`pgrep -c Godot_v4` = 0
each time; brains had stopped its laptop runs); load at each start 0.5 / 1.5 / 2.3 / 2.0 (the later ones are the
runs' own tail). The recipe's "3 other godot" on its header line is its own pgrep matching the launch.

| run | avg frame ms | p95 | tick ms | ticks a frame | gpu ms | ui ms | draws | vehicles alive (avg) |
|---|---|---|---|---|---|---|---|---|
| sumps 92721 | 76.95 | 94.33 | 28.52 | 2.46 | 15.76 | 4.44 | 324 | 37 |
| parade 92721 | 63.55 | 76.69 | 24.18 | 2.08 | 15.41 | 5.15 | 288 | 31 |
| sumps 31337 | 101.33 | 124.38 | 31.37 | 3.00 | 15.29 | 7.58 | 345 | 38 |
| parade 31337 | 66.36 | 82.56 | 26.62 | 2.15 | 13.36 | 4.36 | 204 | 33 |

Read: on his laptop, at his army size, the open map is not the expensive case: parade's frame is 13 and 35 ms
shorter than the Sumps' on the same seeds, its tick 4–5 ms lower with fewer vehicles alive (its fights end sooner),
and the GPU's share is the same or lower (15.4 v 15.8; 13.4 v 15.3 ms) with fewer draw calls. N = 2 pairs; a
windowed match is not repeatable past ~tick 150, so each pair is two different fights; uncapped. These frames
(64–101 ms) are with the armies near full strength; they are his frame early in a match, not a claim about a whole
game. Files: `pp2-*.json`, `perf-play-parade-v-sumps-0328-quiet.txt`.
