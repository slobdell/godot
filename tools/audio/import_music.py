#!/usr/bin/env python3
"""Turns one track the lead generated in Suno into a bed the music director can use.

    python3 tools/audio/import_music.py ~/Downloads/battle.mp3 --state battle --bpm 110

Decodes whatever Suno returned, trims the silence off both ends, picks loop points on **bar lines** so the
director's beat-aligned crossfade lands where it should, normalises to the manifest's loudness target with a
limiter, encodes Ogg Vorbis, and writes (or replaces) the manifest row. It never edits a row's `states` or
`intensity` if one is already there, so re-importing a better take keeps the tuning.

The contract every field has to satisfy is in assets/music/PROMPTS.md; `make music-check` enforces it afterwards.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_music  # noqa: E402

TARGET_LUFS = -16.0
LIMITER_DB = -3.5
BITRATE = "112k"
## Silence quieter than this at either end is trimmed before the loop points are chosen.
SILENCE_DB = -50.0
## Defaults for a state the manifest has never seen; the lead tunes them afterwards.
DEFAULT_INTENSITY = {"garage": 0.1, "pre_match": 0.25, "lull": 0.3, "skirmish": 0.55, "battle": 0.8,
                     "last_stand": 0.95, "victory": 0.7, "defeat": 0.2}


def trimmed_length(path: Path) -> tuple[float, float]:
    """(start, end) of the audio once the silent head and tail are ignored."""
    samples, rate = check_music.decode(path)
    threshold = 10 ** (SILENCE_DB / 20.0)
    first = next((i for i, s in enumerate(samples) if abs(s) > threshold), 0)
    last = next((i for i in range(len(samples) - 1, -1, -1) if abs(samples[i]) > threshold), len(samples) - 1)
    return first / rate, (last + 1) / rate


def bar_aligned(start_s: float, end_s: float, bpm: float, beats_per_bar: int) -> tuple[float, float]:
    """Loop points on whole bars inside the audible part: the crossfade lands on a bar line or it sounds wrong."""
    bar = beats_per_bar * 60.0 / bpm
    first_bar = -(-start_s // bar) * bar          # the first bar line at or after the audio starts
    bars = int((end_s - first_bar) / bar)
    if bars < 1:
        raise SystemExit("the audible part is shorter than one bar at %g bpm: check the tempo" % bpm)
    return round(first_bar, 3), round(first_bar + bars * bar, 3)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="what Suno gave you (mp3, wav, anything ffmpeg reads)")
    parser.add_argument("--state", required=True, help="which MatchMood state this bed is for")
    parser.add_argument("--bpm", type=float, required=True, help="the tempo you asked Suno for")
    parser.add_argument("--beats-per-bar", type=int, default=4)
    parser.add_argument("--out", type=Path, default=Path("assets/music"))
    parser.add_argument("--rights", default="", help="the Suno plan it was generated under, and the date")
    args = parser.parse_args(argv)
    if not args.source.exists():
        raise SystemExit("%s is not there" % args.source)
    args.out.mkdir(parents=True, exist_ok=True)

    start_s, end_s = trimmed_length(args.source)
    loop_start, loop_end = bar_aligned(0.0, end_s - start_s, args.bpm, args.beats_per_bar)
    destination = args.out / ("bed_%s.ogg" % args.state)
    with tempfile.TemporaryDirectory() as scratch:
        trimmed = Path(scratch) / "trimmed.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % start_s, "-i", str(args.source),
                        "-t", "%.3f" % (end_s - start_s), "-ac", "2", "-c:a", "pcm_s16le", str(trimmed)], check=True)
        lufs, _ = check_music.measure_lufs_peak(trimmed)
        limit = 10 ** (LIMITER_DB / 20.0)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(trimmed),
                        "-af", "volume=%.2fdB,alimiter=limit=%.4f:attack=5:release=60:level=disabled"
                        % (TARGET_LUFS - lufs, limit),
                        "-c:a", "libvorbis", "-b:a", BITRATE, str(destination)], check=True)
    final_lufs, peak = check_music.measure_lufs_peak(destination)

    manifest_path = args.out / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else \
        {"schema": 1, "target_lufs": TARGET_LUFS, "tracks": {}, "stingers": {}}
    existing = manifest["tracks"].get(args.state, {})
    manifest["tracks"][args.state] = {
        "file": destination.name, "bpm": args.bpm, "beats_per_bar": args.beats_per_bar,
        "loop_start_s": loop_start, "loop_end_s": loop_end,
        "intensity": existing.get("intensity", DEFAULT_INTENSITY.get(args.state, 0.5)),
        "states": existing.get("states", [args.state]),
        "lufs": round(final_lufs, 1), "peak_db": round(peak, 1),
        "rights": args.rights or existing.get("rights", "UNRECORDED: which Suno plan was this generated under?"),
    }
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n")
    print("imported %s -> %s" % (args.source.name, destination))
    print("  %.1f LUFS, peak %.1f dB, loop %.3f-%.3f s (%d bars at %g bpm), %.0f KB"
          % (final_lufs, peak, loop_start, loop_end,
             round((loop_end - loop_start) / (args.beats_per_bar * 60.0 / args.bpm)), args.bpm,
             destination.stat().st_size / 1024))
    if not args.rights and "UNRECORDED" in manifest["tracks"][args.state]["rights"]:
        print("  NOTE: pass --rights \"Suno <plan>, <date>\" before this ships (PROMPTS.md, Rights)")
    print("  now run: make music-check")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
