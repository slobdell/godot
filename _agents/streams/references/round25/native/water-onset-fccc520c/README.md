# Where the opening clash sits on the water maps (round 25, native N5a)

`fccc520c`, builder0 light lane (windowed, DISPLAY :0), `perf-fight` 25 a side, his preset, `main` arm, load ~16-19
(all three streams' launch checks): **absolute ms are not comparable to the laptop or between sessions; shares are.**

- `onset.txt` (`tests/native/fight_onset.py` over the six recordings `*.jsonl.gz`): first hits at 8-10 s on the Locks
  (like foundry), **12-14 s on the Crossing** (the armies meet across the river), hits per 2 s lighter on the
  Crossing. So the water workload's window is **12-24 s** (`NATIVE_TP_WATER_WINDOW`): 12 s long like the bar's 8-20,
  starting where the later map's fight starts.
- `scope-25-*.log`: the TickProfile 8-20 s lines of that run (load 16-19).
- `scope2/`: one session alternating foundry, parade, locks (seeds 92721, 31337; 8-20 s): **elements 22 % of the tick
  on the Locks v 15-18 % on foundry/parade** (7.0 v 4.4 ms): water loads the segment `native_el` replaces.
