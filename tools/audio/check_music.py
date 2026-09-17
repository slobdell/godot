#!/usr/bin/env python3
"""Checks every track in a music manifest against the contract in assets/music/PROMPTS.md.

    python3 tools/audio/check_music.py assets/music

Fails when a file is missing, the loudness is more than TOLERANCE_LU off target, a true peak is over the ceiling,
the loop points don't fit inside the file, or a loop seam would click. A track the director can't crossfade cleanly
is worse than no music, and none of this is audible in a unit test.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

TOLERANCE_LU = 2.0
PEAK_CEILING_DB = -1.5
## A loop seam louder than this jump (relative to the track's own peak) clicks on every repeat.
SEAM_JUMP = 0.25
## How much audio either side of the seam is compared.
SEAM_WINDOW_S = 0.01
REQUIRED = ("file", "bpm", "beats_per_bar", "loop_start_s", "loop_end_s", "intensity", "states", "rights")


def decode(path: Path) -> tuple[list[float], int]:
    """The file as mono samples, through ffmpeg so any format works."""
    with tempfile.TemporaryDirectory() as scratch:
        wav = Path(scratch) / "decoded.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(path), "-ac", "1", "-c:a", "pcm_s16le", str(wav)],
                       check=True)
        with wave.open(str(wav), "rb") as handle:
            rate = handle.getframerate()
            frames = handle.readframes(handle.getnframes())
    count = len(frames) // 2
    return [s / 32768.0 for s in struct.unpack("<%dh" % count, frames[:count * 2])], rate


def seam_jump(samples: list[float], rate: int, loop_start_s: float, loop_end_s: float) -> float:
    """How far the signal jumps where the loop wraps, as a fraction of the track's peak. 0 is seamless."""
    window = max(1, int(rate * SEAM_WINDOW_S))
    end = int(loop_end_s * rate)
    start = int(loop_start_s * rate)
    if end - window < 0 or start + window > len(samples) or end > len(samples):
        return math.inf
    peak = max(abs(s) for s in samples) or 1.0
    before = sum(samples[end - window:end]) / window
    after = sum(samples[start:start + window]) / window
    return abs(after - before) / peak


def measure_lufs_peak(path: Path) -> tuple[float, float]:
    result = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                            capture_output=True, text=True)
    text = result.stderr
    summary = text[text.rfind("Integrated loudness"):] if "Integrated loudness" in text else text
    import re
    lufs = re.search(r"I:\s*(-?\d+\.?\d*)\s*LUFS", summary)
    peak = re.search(r"Peak:\s*(-?\d+\.?\d*)\s*dBFS", summary)
    return (float(lufs.group(1)) if lufs else 0.0, float(peak.group(1)) if peak else 0.0)


def check_stems(folder: Path, name: str, track: dict, target: float) -> list[str]:
    """A stem set (X5, round 5): every stem there and the same length, the full arrangement meets the loudness and
    peak contract (so any subset of it stays under the ceiling), the quietest arrangement is still music, and the
    summed loop seam is clean. Stems are summed sample by sample, the way AudioStreamSynchronized plays them."""
    problems: list[str] = []
    for field in REQUIRED:
        if field != "file" and field not in track:
            problems.append("%s: missing %s" % (name, field))
    if problems:
        return problems
    decoded, rate = [], 44100
    for stem in track["stems"]:
        path = folder / stem.get("file", "")
        if not path.exists():
            problems.append("%s: stem %s is not there" % (name, stem.get("file")))
            continue
        if "from" not in stem and "states" not in stem:
            problems.append("%s: stem %s needs a `from` intensity or `states`" % (name, stem["file"]))
        samples, rate = decode(path)
        decoded.append((stem, samples))
    if problems or not decoded:
        return problems or ["%s: no stems" % name]
    lengths = [len(samples) / rate for _, samples in decoded]
    if max(lengths) - min(lengths) > 0.03:
        problems.append("%s: stems differ in length (%.2f-%.2f s); they must line up sample for sample"
                        % (name, min(lengths), max(lengths)))
    count = min(len(samples) for _, samples in decoded)

    def mixed(parts):
        return [sum(samples[i] for _, samples in parts) for i in range(count)]

    def loudness(samples):
        with tempfile.TemporaryDirectory() as scratch:
            wav = Path(scratch) / "mix.wav"
            with wave.open(str(wav), "wb") as handle:
                handle.setnchannels(1)
                handle.setsampwidth(2)
                handle.setframerate(rate)
                handle.writeframes(struct.pack("<%dh" % len(samples), *(int(max(-1.0, min(1.0, x)) * 32767) for x in samples)))
            return measure_lufs_peak(wav)

    full = mixed(decoded)
    lufs, _ = loudness(full)
    peak = 20 * math.log10(max(max(abs(x) for x in full), 1e-9))
    if abs(lufs - target) > TOLERANCE_LU:
        problems.append("%s: the full arrangement is %.1f LUFS, %.1f LU off the %.1f target" % (name, lufs, lufs - target, target))
    if peak > PEAK_CEILING_DB:
        problems.append("%s: the full arrangement peaks at %.1f dB, over the %.1f ceiling" % (name, peak, PEAK_CEILING_DB))
    floor = [part for part in decoded if "from" in part[0] and float(part[0]["from"]) <= 0.0]
    quiet = loudness(mixed(floor))[0] if floor else -70.0
    if quiet < target - 18.0:
        problems.append("%s: with only the always-on stems it is %.1f LUFS, which is silence, not a lull" % (name, quiet))
    if not 0.0 <= track["loop_start_s"] < track["loop_end_s"] <= count / rate + 0.05:
        problems.append("%s: loop does not fit the stems" % name)
    else:
        jump = seam_jump(full, rate, track["loop_start_s"], track["loop_end_s"])
        if jump > SEAM_JUMP:
            problems.append("%s: the summed loop seam jumps %.2f of the peak" % (name, jump))
    print("  %-12s %d stems  full %5.1f LUFS  peak %5.1f dB  floor %5.1f LUFS  loop %5.2f s  %s"
          % (name, len(decoded), lufs, peak, quiet, track["loop_end_s"], ",".join(track["states"])))
    return problems


def check(folder: Path, target_lufs: float | None = None) -> list[str]:
    manifest_path = folder / "manifest.json"
    if not manifest_path.exists():
        return ["%s: no manifest" % manifest_path]
    manifest = json.loads(manifest_path.read_text())
    target = target_lufs if target_lufs is not None else float(manifest.get("target_lufs", -16.0))
    problems: list[str] = []
    for name, track in sorted(manifest.get("tracks", {}).items()):
        if "stems" in track:
            problems += check_stems(folder, name, track, target)
            continue
        for field in REQUIRED:
            if field not in track:
                problems.append("%s: missing %s" % (name, field))
        if any(field not in track for field in REQUIRED):
            continue
        path = folder / track["file"]
        if not path.exists():
            problems.append("%s: %s is not there" % (name, track["file"]))
            continue
        samples, rate = decode(path)
        length = len(samples) / rate
        lufs, peak = measure_lufs_peak(path)
        if abs(lufs - target) > TOLERANCE_LU:
            problems.append("%s: %.1f LUFS is %.1f LU off the %.1f target" % (name, lufs, lufs - target, target))
        if peak > PEAK_CEILING_DB:
            problems.append("%s: peaks at %.1f dB, over the %.1f ceiling" % (name, peak, PEAK_CEILING_DB))
        if not 0.0 <= track["loop_start_s"] < track["loop_end_s"] <= length + 0.05:
            problems.append("%s: loop %.2f-%.2f s does not fit a %.2f s file"
                            % (name, track["loop_start_s"], track["loop_end_s"], length))
            continue
        jump = seam_jump(samples, rate, track["loop_start_s"], track["loop_end_s"])
        if jump > SEAM_JUMP:
            problems.append("%s: the loop seam jumps %.2f of the peak and will click every repeat" % (name, jump))
        if float(track["bpm"]) <= 0:
            problems.append("%s: needs a tempo, or the director cannot crossfade on the beat" % name)
        print("  %-12s %5.1f LUFS  peak %5.1f dB  loop %5.2f-%5.2f of %5.2f s  seam %.3f  %s"
              % (name, lufs, peak, track["loop_start_s"], track["loop_end_s"], length, jump,
                 ",".join(track["states"])))
    for id_, sting in sorted(manifest.get("stingers", {}).items()):
        path = folder / sting.get("file", "")
        if not path.exists():
            problems.append("%s: %s is not there" % (id_, sting.get("file")))
            continue
        lufs, peak = measure_lufs_peak(path)
        if peak > PEAK_CEILING_DB:
            problems.append("%s: peaks at %.1f dB, over the %.1f ceiling" % (id_, peak, PEAK_CEILING_DB))
        print("  %-20s %5.1f LUFS  peak %5.1f dB" % (id_, lufs, peak))
    placeholders = [n for n, t in manifest.get("tracks", {}).items() if t.get("placeholder")]
    if placeholders:
        print("  (%d of %d beds are still placeholders: %s)"
              % (len(placeholders), len(manifest.get("tracks", {})), ", ".join(sorted(placeholders))))
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folder", type=Path, nargs="?", default=Path("assets/music"))
    parser.add_argument("--target-lufs", type=float, default=None)
    args = parser.parse_args(argv)
    if not args.folder.exists():
        print("no music yet at %s (make music-placeholders)" % args.folder)
        return 0
    problems = check(args.folder, args.target_lufs)
    for problem in problems:
        print("ERROR   " + problem, file=sys.stderr)
    print("music-check: %d problems" % len(problems))
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
