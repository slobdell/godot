# element-play series on his laptop, main `5619363f`, 2026-10-06 01:30:41–01:40:47 PDT (the orchestrator)

`make ai-element-perfplay ELEMENT_PLAY_DIR=/tmp/claude-1000/element-play-r19` (8 windowed runs: parade + Sumps × seeds
92721, 1801 × CPU squad leaders on/off, interleaved), sound to a temporary null sink (his default sink read before and
after: `alsa_output.pci-0000_00_1f.3.analog-stereo`, restored). His desktop idle 125 min at the first attempt.

**Window: HELD.** `samples.tsv` samples every 10 s (61 samples): load 0.82–2.76, all ours. The `FOREIGN 76774` on every
line is NOT a Godot: it was the orchestrator's own `until ! pgrep -f "Godot…"` wait loop, whose command line matched the
sampler's pattern (`ps` showed `bash -c … pgrep`; its child was `sleep 10`). No other Godot ran: brains' only local run
(`FILTER=tactics_cpu_hold`, pid 75956) ended before 01:30:28, inside the FIRST attempt (01:26–01:28), which was stopped
and discarded (kept at `/tmp/claude-1000/element-play-r19-contaminated-0126/` on the laptop until it is cleaned, not in
the repo). `window.log`'s `godot_before 3` / `godot_after 2` count shell wrappers of the sampler and the check watcher,
not engines (the pattern was too loose; the per-sample `FOREIGN` list is the record).

Arm assertion: four "on" logs print `BRAINS_AMBUSH team 1` (taken 0, sprung 0, hold_s 0 / 38 / 33 / 26); four "off"
logs print none. Binning by equal vehicle counts is brains' (`make.log`, `perfplay-*.json`).
