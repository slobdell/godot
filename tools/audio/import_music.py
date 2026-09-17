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


def seconds(text: str) -> float:
    """"1:32" or "92" or "92.5" -> seconds."""
    if not text:
        return 0.0
    if ":" in text:
        minutes, rest = text.split(":", 1)
        return int(minutes) * 60 + float(rest)
    return float(text)


def section(start_s: float, end_s: float, cut_from: float, cut_to: float) -> tuple[float, float]:
    """The part of the audible track to use: FROM/TO when given (a Suno track's intro and outro fade, which is not
    a loop), else all of it."""
    lo = max(start_s, cut_from) if cut_from > 0 else start_s
    hi = min(end_s, cut_to) if cut_to > 0 else end_s
    if hi - lo < 1.0:
        raise SystemExit("FROM/TO leave less than a second of audio (%.1f-%.1f of %.1f-%.1f)" % (cut_from, cut_to, start_s, end_s))
    return lo, hi


def retire_placeholders(manifest: dict, kept: str, states: list[str]) -> list[str]:
    """A real track takes its states away from every placeholder, and a placeholder left with none is dropped.
    Without this a placeholder stem set (which outranks any single bed) keeps playing over the lead's real lull bed,
    and a placeholder fight set ties with a real one and rotates back in. Returns what it dropped."""
    dropped = []
    for track_id in list(manifest.get("tracks", {})):
        track = manifest["tracks"][track_id]
        if track_id == kept or not track.get("placeholder"):
            continue
        track["states"] = [state for state in track.get("states", []) if state not in states]
        if not track["states"]:
            del manifest["tracks"][track_id]
            dropped.append(track_id)
    return dropped


def parse_layers(spec: str) -> list[tuple[str, dict]]:
    """"Synth=0 Drums=0.35 Bass=0.5 FX=last_stand" -> [(name, {"from": 0.0}), ..., ("FX", {"states": [...]})]."""
    layers = []
    for part in spec.split():
        name, _, when = part.partition("=")
        if not name or not when:
            raise SystemExit("--layers wants NAME=FROM or NAME=state[,state]: %r" % part)
        try:
            layers.append((name, {"from": float(when)}))
        except ValueError:
            layers.append((name, {"states": when.split(",")}))
    return layers


def find_stem(folder: Path, name: str) -> Path:
    """Suno names stem files after the instrument ("... (Drums).wav"); match the name loosely."""
    hits = [p for p in sorted(folder.iterdir()) if p.is_file() and name.lower() in p.stem.lower()]
    if len(hits) != 1:
        raise SystemExit("stem %r matches %d files in %s: %s" % (name, len(hits), folder, [h.name for h in hits]))
    return hits[0]


def import_stems(folder: Path, track_id: str, layers: list, bpm: float, beats_per_bar: int, out: Path,
                 rights: str, states: list[str], cut_from: float = 0.0, cut_to: float = 0.0) -> dict:
    """X5 (round 5): one Suno track split into stems becomes a stem set that builds with the fight.

    Every stem is cut at the same offset and to the same loop, and they share **one** gain worked out from their sum,
    so the full arrangement meets the loudness target and the relative balance Suno mixed is kept. There is no
    limiter (a limiter per stem would change the balance), so the gain is also held under the summed peak ceiling."""
    import numpy as np
    sources = [(name, find_stem(folder, name), when) for name, when in layers]
    decoded = [np.array(check_music.decode(path)[0]) for _, path, _ in sources]
    rate = check_music.decode(sources[0][1])[1]
    count = min(len(x) for x in decoded)
    mix = sum(x[:count] for x in decoded)
    threshold = 10 ** (SILENCE_DB / 20.0)
    audible = np.nonzero(np.abs(mix) > threshold)[0]
    start_s, end_s = section(audible[0] / rate, (audible[-1] + 1) / rate, cut_from, cut_to)
    loop_start, loop_end = bar_aligned(0.0, end_s - start_s, bpm, beats_per_bar)
    with tempfile.TemporaryDirectory() as scratch:
        summed = Path(scratch) / "sum.wav"
        segment = mix[int(start_s * rate):int(end_s * rate)]
        import wave
        with wave.open(str(summed), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(rate)
            handle.writeframes((np.clip(segment, -1, 1) * 32767).astype("<i2").tobytes())
        lufs, _ = check_music.measure_lufs_peak(summed)
        peak_db = 20 * np.log10(max(np.abs(segment).max(), 1e-9))
        gain = min(TARGET_LUFS - lufs, check_music.PEAK_CEILING_DB - 0.7 - peak_db)
        stems = []
        for name, path, when in sources:
            destination = out / ("%s_%s.ogg" % (track_id, name.lower().replace(" ", "_")))
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % start_s, "-i", str(path),
                            "-t", "%.3f" % (end_s - start_s), "-af", "volume=%.2fdB" % gain,
                            "-c:a", "libvorbis", "-b:a", BITRATE, str(destination)], check=True)
            stems.append(dict({"file": destination.name}, **when))
    return {"stems": stems, "bpm": bpm, "beats_per_bar": beats_per_bar, "loop_start_s": loop_start,
            "loop_end_s": loop_end, "intensity": 0.6, "states": states,
            "rights": rights or "UNRECORDED: which Suno plan was this generated under?"}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="what Suno gave you (mp3, wav, anything ffmpeg reads)")
    parser.add_argument("--state", required=True, help="which MatchMood state this bed is for (stems: the track id, e.g. fight)")
    parser.add_argument("--bpm", type=float, required=True, help="the tempo you asked Suno for")
    parser.add_argument("--beats-per-bar", type=int, default=4)
    parser.add_argument("--out", type=Path, default=Path("assets/music"))
    parser.add_argument("--rights", default="", help="the Suno plan it was generated under, and the date")
    parser.add_argument("--layers", default="", help="stems mode: SOURCE is a folder of Suno stems, e.g. "
                        "\"Synth=0 Drums=0.35 Bass=0.5 Guitar=0.65 FX=last_stand\" (quietest first)")
    parser.add_argument("--states", default="", help="which MatchMood states it plays under, comma-separated "
                        "(default: the STATE itself for a bed, skirmish,battle for stems)")
    parser.add_argument("--from", dest="cut_from", default="", help="use the track from here (m:ss or seconds): skip Suno's intro")
    parser.add_argument("--to", dest="cut_to", default="", help="and up to here: skip its outro and fade")
    args = parser.parse_args(argv)
    if args.layers:
        manifest_path = args.out / "manifest.json"
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else \
            {"schema": 1, "target_lufs": TARGET_LUFS, "tracks": {}, "stingers": {}}
        existing = manifest["tracks"].get(args.state, {})
        states = [x for x in args.states.split(",") if x] or existing.get("states", ["skirmish", "battle"])
        track = import_stems(args.source, args.state, parse_layers(args.layers), args.bpm, args.beats_per_bar,
                             args.out, args.rights or existing.get("rights", ""), states,
                             seconds(args.cut_from), seconds(args.cut_to))
        manifest["tracks"][args.state] = track
        for gone in retire_placeholders(manifest, args.state, states):
            print("retired placeholder track %s" % gone)
        manifest_path.write_text(json.dumps(manifest, indent=1) + "\n")
        print("imported %d stems as %s: loop %.3f-%.3f s; now run: make music-check" % (
            len(track["stems"]), args.state, track["loop_start_s"], track["loop_end_s"]))
        return 0
    if not args.source.exists():
        raise SystemExit("%s is not there" % args.source)
    args.out.mkdir(parents=True, exist_ok=True)

    start_s, end_s = section(*trimmed_length(args.source), seconds(args.cut_from), seconds(args.cut_to))
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
        "states": [x for x in args.states.split(",") if x] or existing.get("states", [args.state]),
        "lufs": round(final_lufs, 1), "peak_db": round(peak, 1),
        "rights": args.rights or existing.get("rights", "UNRECORDED: which Suno plan was this generated under?"),
    }
    for gone in retire_placeholders(manifest, args.state, manifest["tracks"][args.state]["states"]):
        print("retired placeholder track %s" % gone)
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
