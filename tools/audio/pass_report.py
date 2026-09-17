#!/usr/bin/env python3
"""Measures a recorded match mix (make audio-pass): is it loud enough, does it clip, does the booth sit above it.

    python3 tools/audio/pass_report.py build/audio/pass.wav build/audio/pass.log

Writes pass.mp3 (to listen to), pass.png (spectrogram and waveform, to look at) and pass.json next to the WAV, and
prints a short report: integrated loudness and range, true peak, clipped samples, the loudness every five seconds,
and what the game logged about the booth and the music over the same time.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sfx_layer  # noqa: E402


def ebur128(path: Path) -> dict:
    text = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                          capture_output=True, text=True).stderr
    summary = text[text.rfind("Summary:"):]
    found = {}
    for key, pattern in (("integrated_lufs", r"I:\s*(-?[\d.]+) LUFS"), ("range_lu", r"LRA:\s*(-?[\d.]+) LU"),
                         ("true_peak_dbfs", r"Peak:\s*(-?[\d.]+) dBFS")):
        match = re.search(pattern, summary)
        found[key] = float(match.group(1)) if match else None
    return found


def main(argv: list[str]) -> int:
    wav = Path(argv[0])
    log = Path(argv[1]).read_text(errors="replace") if len(argv) > 1 and Path(argv[1]).exists() else ""
    x = sfx_layer.decode(wav)
    rate = sfx_layer.RATE
    report = ebur128(wav)
    report["seconds"] = round(len(x) / rate, 1)
    report["clipped_samples"] = int(np.sum(np.abs(x) >= 0.999))
    window = 5 * rate
    report["rms_dbfs_every_5s"] = [round(20 * np.log10(max(np.sqrt(np.mean(x[i:i + window] ** 2)), 1e-9)), 1)
                                   for i in range(0, len(x) - window + 1, window)]
    report["booth_lines"] = len(re.findall(r"HUD_MESSAGE \[info\] (CALLER|VETERAN|PA):", log))
    report["music_changes"] = len(re.findall(r"^MUSIC_(TRACK|LAYERS)", log, re.M))
    report["silent_windows"] = sum(1 for level in report["rms_dbfs_every_5s"] if level < -50)
    report["booth_named_arena"] = sorted(set(re.findall(r"\bthe (Foundry|Furnace|Scrapyard|Container Yard|Boulevard|Pit|Boneyard)\b", log)))
    base = wav.with_suffix("")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libmp3lame", "-b:a", "160k",
                    str(base) + ".mp3"], check=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-filter_complex",
                    "[0:a]showspectrumpic=s=1400x360:legend=0:scale=log[s];[0:a]showwavespic=s=1400x160:colors=orange[w];"
                    "[s][w]vstack=inputs=2", str(base) + ".png"], check=False)
    Path(str(base) + ".json").write_text(json.dumps(report, indent=1) + "\n")
    print("audio-pass: %.0f s, %s LUFS integrated, range %s LU, true peak %s dBFS, %d clipped samples, "
          "%d booth lines, %d music changes, %d silent 5 s windows, arena named %s" % (
              report["seconds"], report["integrated_lufs"], report["range_lu"], report["true_peak_dbfs"],
              report["clipped_samples"], report["booth_lines"], report["music_changes"], report["silent_windows"],
              ",".join(report["booth_named_arena"]) or "never"))
    print("  loudness every 5 s (dBFS RMS): %s" % " ".join("%.0f" % v for v in report["rms_dbfs_every_5s"]))
    print("  listen: %s.mp3   look: %s.png" % (base, base))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
