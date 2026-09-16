#!/usr/bin/env python3
"""Mixes a called match into one audio file: the director's cues placed on a timeline from the clip manifest.

    python3 tools/announcer/mixdown.py --match build/announcer/demo/data/comeback_seed1.json \
        --manifest build/announcer/mock/manifest.json --out build/announcer/demo/data/comeback_seed1.ogg

Each cue plays its line's parts in order (carrier segments, and filler clips for the slot values the director
chose, in the intonation the line needs), starting at the cue's time. A cut cue stops at its end with a short fade,
the way the booth sounds when the caller jumps in. The page (make announcer-demo) plays the result in sync.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import recording_plan  # noqa: E402

PART_GAP_S = 0.02
FADE_S = 0.06
## The rendered mix must be this close to the length the match asked for, or render() raises. A mix that ends with
## the last clip instead of the match desyncs the demo page's audio from its transcript, and used to happen silently
## on a loaded builder0 (the orchestrator, 2026-09-16).
LENGTH_TOLERANCE_S = 0.1


def cue_clips(cue: dict, manifest: dict) -> list[str]:
    """The clip to play for a cue — one whole sentence. A list of one, so the schedule below is unchanged.

    Until round 4 this returned carrier segments and filler words to be joined at playback. That is gone: a word
    lifted out of one recording carries the wrong intonation into another, and it was audible
    (_agents/streams/audio.md, *Why stitching failed*)."""
    line = manifest["lines"][cue["line_id"]]
    key = cue.get("variant_key")
    if key is None:
        key = recording_plan.variant_key(cue.get("slots", {}), line.get("bases", []))
    clip = line.get("variants", {}).get(key)
    if clip is None:
        raise KeyError("%s has no recording for %r (have %s)"
                       % (cue["line_id"], key, ", ".join(sorted(line.get("variants", {}))) or "none"))
    if clip not in manifest["clips"]:
        raise KeyError("%s needs clip %s, which the manifest doesn't have" % (cue["line_id"], clip))
    return [clip]


def schedule(match: dict, manifest: dict) -> list[dict]:
    """[{t, file, max_s}] for every clip in the match, cut cues limited to their spoken time."""
    placed = []
    for cue in match["cues"]:
        clock = float(cue["t"])
        stop = float(cue["end"]) if cue.get("cut") else None
        for clip in cue_clips(cue, manifest):
            info = manifest["clips"][clip]
            length = float(info["duration_s"])
            if stop is not None and clock >= stop:
                break
            placed.append({"t": round(clock, 3), "file": info["file"],
                           "max_s": round(stop - clock, 3) if stop is not None and clock + length > stop else None})
            clock += length + PART_GAP_S
    return placed


def render(placed: list[dict], clips_dir: Path, out: Path, duration_s: float) -> None:
    """Mixes the scheduled clips into `out`, exactly `duration_s` long. Raises when it isn't."""
    if not placed:
        raise ValueError("nothing to mix")
    # Input 0 is generated silence as long as the match. Mixing against it is what makes the output the right
    # length: `apad` after `amix` plus `-t` did the same job but dropped the padding under load, leaving a mix that
    # ended with its last clip. Silence we generate ourselves is not load-dependent.
    command = ["ffmpeg", "-v", "error", "-y",
               "-f", "lavfi", "-t", "%.3f" % duration_s, "-i", "anullsrc=r=44100:cl=mono"]
    filters = ["[0:a]aresample=44100[a0]"]
    for index, item in enumerate(placed, start=1):
        command += ["-i", str(clips_dir / item["file"])]
        chain = "[%d:a]aresample=44100" % index
        if item["max_s"] is not None:
            chain += ",atrim=0:%.3f,afade=t=out:st=%.3f:d=%.3f" % (item["max_s"], max(0.0, item["max_s"] - FADE_S), FADE_S)
        delay = int(item["t"] * 1000)
        chain += ",adelay=%d|%d[a%d]" % (delay, delay, index)
        filters.append(chain)
    inputs = len(placed) + 1
    mix = "".join("[a%d]" % i for i in range(inputs))
    filters.append("%samix=inputs=%d:duration=longest:normalize=0:dropout_transition=0[out]" % (mix, inputs))
    script = out.with_suffix(".filter.txt")
    out.parent.mkdir(parents=True, exist_ok=True)
    script.write_text(";\n".join(filters))
    command += ["-filter_complex_script", str(script), "-map", "[out]", "-t", "%.3f" % duration_s,
                "-ac", "1", "-c:a", "libvorbis", "-b:a", "48k", str(out)]
    try:
        subprocess.run(command, check=True)
    finally:
        script.unlink(missing_ok=True)
    check_length(out, duration_s)


def check_length(out: Path, duration_s: float) -> float:
    """Fails loudly when a mix came out shorter or longer than the match; returns the measured length."""
    import voice_client  # here, so importing mixdown never needs the audio tooling

    actual = voice_client.probe_duration(out)
    if abs(actual - duration_s) > LENGTH_TOLERANCE_S:
        raise RuntimeError("%s is %.3f s, not the %.3f s the match asked for: the mix would play out of sync with "
                           "the transcript" % (out, actual, duration_s))
    return actual


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--match", type=Path, nargs="+", required=True, help="director output JSON (announcer_cli.gd --out)")
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args(argv)
    manifest = json.loads(args.manifest.read_text())
    for path in args.match:
        match = json.loads(path.read_text())
        placed = schedule(match, manifest)
        end = max(float(c["end"]) for c in match["cues"]) + 1.0
        out = path.with_suffix(".ogg")
        render(placed, args.manifest.parent, out, end)
        print("mixed %s: %d clips over %.1f s" % (out, len(placed), end))
    return 0


def needed_lines(matches: list[Path]) -> list[str]:
    ids = set()
    for path in matches:
        ids.update(cue["line_id"] for cue in json.loads(path.read_text())["cues"])
    return sorted(ids)


def missing_lines(manifest_path: Path, matches: list[Path]) -> list[str]:
    """Lines the matches use that the manifest can't play yet (no line entry, or a clip of it or its fillers missing)."""
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"lines": {}, "clips": {}}
    missing = set()
    for path in matches:
        for cue in json.loads(path.read_text())["cues"]:
            try:
                if cue["line_id"] not in manifest["lines"]:
                    raise KeyError(cue["line_id"])
                cue_clips(cue, manifest)
            except KeyError:
                missing.add(cue["line_id"])
    return sorted(missing)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--needed-lines":
        print(",".join(needed_lines([Path(p) for p in sys.argv[2:]])))
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[1] == "--missing-lines":
        print(",".join(missing_lines(Path(sys.argv[2]), [Path(p) for p in sys.argv[3:]])))
        sys.exit(0)
    sys.exit(main(sys.argv[1:]))
