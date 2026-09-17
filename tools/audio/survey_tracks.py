#!/usr/bin/env python3
"""Sorts a folder of generated music: how long, how loud, how fast, and where a loopable section sits.

    python3 tools/audio/survey_tracks.py ~/projects/godot/assets/incoming/music

For each track it prints the tempo (onset autocorrelation), the loudness and tone (centroid, share under 250 Hz), how
much silence or fade sits at each end, and the **best steady window**: the longest stretch whose level holds within a
few dB, snapped to whole bars, with the seam discontinuity it would have as a loop. That window is what to pass to
`make music-import FROM=… TO=…`, and the seam is what `make music-check` will measure afterwards.

Sorting hint, not a verdict: tempo from an onset envelope halves and doubles easily, and nothing here hears whether a
track is any good.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sfx_layer  # noqa: E402

RATE = 22050  # plenty for tempo and tone, and four times faster to load
WINDOW_S = 30.0  # the shortest loop worth shipping
MAX_WINDOW_S = 90.0


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def onset_envelope(x: np.ndarray, hop: int = 256, frame: int = 1024) -> np.ndarray:
    """Spectral flux: how much the spectrum brightens frame to frame. Percussive music makes a clear pulse."""
    frames = 1 + (len(x) - frame) // hop
    window = np.hanning(frame)
    spectra = np.abs(np.fft.rfft(np.lib.stride_tricks.as_strided(
        x, (frames, frame), (x.strides[0] * hop, x.strides[0])) * window, axis=1))
    flux = np.maximum(np.diff(spectra, axis=0), 0).sum(axis=1)
    return flux - flux.mean()


def tempo_bpm(flux: np.ndarray, hop: int = 256) -> tuple[float, float]:
    """(bpm, confidence 0-1) from the onset envelope's autocorrelation over 55-190 BPM."""
    if len(flux) < 100:
        return 0.0, 0.0
    auto = np.correlate(flux, flux, "full")[len(flux) - 1:]
    lo, hi = int(60.0 / 190 * RATE / hop), int(60.0 / 55 * RATE / hop)
    band = auto[lo:hi]
    if not len(band) or auto[0] <= 0:
        return 0.0, 0.0
    lag = int(np.argmax(band)) + lo
    return 60.0 * RATE / hop / lag, float(band.max() / auto[0])


def level_db(x: np.ndarray, window_s: float = 1.0) -> np.ndarray:
    """Level per second, in dB."""
    n = int(window_s * RATE)
    usable = len(x) // n * n
    if usable == 0:
        return np.array([-120.0])
    blocks = x[:usable].reshape(-1, n)
    return 10 * np.log10(np.maximum((blocks ** 2).mean(axis=1), 1e-12))


def steady_window(levels: np.ndarray, spread_db: float = 6.0) -> tuple[int, int]:
    """The longest run of seconds whose level stays within `spread_db` of its own median, at least WINDOW_S long."""
    best = (0, 0)
    start = 0
    for end in range(1, len(levels) + 1):
        run = levels[start:end]
        if run.max() - run.min() > spread_db:
            start += 1
            continue
        if end - start > best[1] - best[0]:
            best = (start, end)
        if end - start >= MAX_WINDOW_S:
            start += 1
    return best


def snap_to_bars(start_s: float, end_s: float, bpm: float, beats_per_bar: int = 4) -> tuple[float, float]:
    bar = beats_per_bar * 60.0 / bpm if bpm > 0 else 2.0
    bars = int((end_s - start_s) / bar)
    return (round(start_s, 2), round(start_s + max(bars, 1) * bar, 2))


def seam_jump(x: np.ndarray, start_s: float, end_s: float) -> float:
    window = int(0.01 * RATE)
    a, b = int(start_s * RATE), int(end_s * RATE)
    if b + window > len(x) or a + window > len(x):
        return float("inf")
    peak = max(np.abs(x).max(), 1e-9)
    return float(abs(x[a:a + window].mean() - x[b - window:b].mean()) / peak)


def survey(path: Path) -> dict:
    x = decode(path)
    seconds = len(x) / RATE
    flux = onset_envelope(x)
    bpm, confidence = tempo_bpm(flux)
    spectrum = np.abs(np.fft.rfft(x[: RATE * 60]))
    freqs = np.fft.rfftfreq(min(len(x), RATE * 60), 1 / RATE)
    centroid = float((spectrum * freqs).sum() / max(spectrum.sum(), 1e-9))
    low_share = float((spectrum[freqs < 250] ** 2).sum() / max((spectrum ** 2).sum(), 1e-9))
    levels = level_db(x)
    loud = float(np.median(levels))
    head = int(np.argmax(levels > loud - 12)) if (levels > loud - 12).any() else 0
    tail = len(levels) - int(np.argmax(levels[::-1] > loud - 12)) if (levels > loud - 12).any() else len(levels)
    first, last = steady_window(levels[head:tail])
    start_s, end_s = snap_to_bars(head + first, head + last, bpm)
    return {"file": path.name, "seconds": round(seconds, 1), "bpm": round(bpm, 1), "tempo_confidence": round(confidence, 2),
            "median_db": round(loud, 1), "centroid_hz": int(centroid), "low_share": round(low_share, 2),
            "quiet_head_s": head, "quiet_tail_s": round(seconds - tail, 1),
            "loop_from": start_s, "loop_to": min(end_s, round(seconds, 2)),
            "loop_seconds": round(min(end_s, seconds) - start_s, 1),
            "seam": round(seam_jump(x, start_s, min(end_s, seconds - 0.05)), 3)}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--json", type=Path, default=None)
    args = parser.parse_args(argv)
    rows = [survey(p) for p in sorted(args.folder.iterdir()) if p.suffix.lower() in (".mp3", ".wav", ".ogg", ".flac")]
    rows.sort(key=lambda r: r["bpm"])
    print("%-34s %6s %6s %5s %7s %8s %6s %6s  %-18s %5s" % (
        "file", "len", "bpm", "conf", "med dB", "centroid", "low", "head", "loop (from-to)", "seam"))
    for r in rows:
        print("%-34s %6.1f %6.1f %5.2f %7.1f %8d %5.0f%% %6d  %6.1f-%-7.1f (%4.0f) %5.3f" % (
            r["file"][:34], r["seconds"], r["bpm"], r["tempo_confidence"], r["median_db"], r["centroid_hz"],
            r["low_share"] * 100, r["quiet_head_s"], r["loop_from"], r["loop_to"], r["loop_seconds"], r["seam"]))
    if args.json:
        args.json.write_text(json.dumps(rows, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
