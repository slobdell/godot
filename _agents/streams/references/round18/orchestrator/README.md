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
