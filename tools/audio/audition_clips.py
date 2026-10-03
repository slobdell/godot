#!/usr/bin/env python3
"""Round 17 G4: 15-second clips of a real fight's mix, one per direction, cut at the same moment of the same match.

    python3 tools/audio/audition_clips.py build/audio/audition [--seconds 15] [--reference fight_tank_boom~0.wav]

Every fight_<sound>~<direction>.wav in the folder is the same seeded match recorded through the game's mix with that
direction playing. The window is the loudest 15 s (short-term loudness) of the reference recording after its first
10 s, and the same window is cut from every recording, so the clips are the same moment of the same fight. Nothing is
level-matched away: the loudness of each clip (integrated LUFS and true peak, BS.1770) is written beside it, because
how loud the mix lets a gun be is part of what changed. Writes clip_<name>.mp3 and clips.json.
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
import weapon_sheet  # noqa: E402


def loudest_window(x: np.ndarray, rate: int, seconds: float, skip_s: float = 10.0) -> int:
    y = weapon_sheet.k_weight(x, rate)
    power = (y * y).sum(axis=1)
    n = int(seconds * rate)
    cumulative = np.concatenate([[0.0], np.cumsum(power)])
    start = int(skip_s * rate)
    if len(power) - n <= start:
        return 0
    sums = cumulative[start + n: len(power) + 1] - cumulative[start: len(power) - n + 1]
    return start + int(np.argmax(sums[:: rate // 10]) * (rate // 10))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--seconds", type=float, default=15.0)
    parser.add_argument("--reference", default="")
    args = parser.parse_args(argv)
    folder = Path(args.folder)
    fights = sorted(folder.glob("fight_*.wav"))
    if not fights:
        print("no fight_*.wav in %s" % folder)
        return 1
    reference = folder / args.reference if args.reference else next((f for f in fights if f.stem.endswith("~0")), fights[0])
    x, rate = weapon_sheet.read(reference)
    start = loudest_window(x, rate, args.seconds)
    report = {"window_s": [round(start / rate, 1), round(start / rate + args.seconds, 1)], "reference": reference.name, "clips": {}}
    for fight in fights:
        y, rate = weapon_sheet.read(fight)
        clip = y[start: start + int(args.seconds * rate)]
        name = fight.stem.replace("fight_", "")
        out = folder / ("clip_%s.mp3" % name)
        wav = folder / ("clip_%s.wav" % name)
        import wave
        with wave.open(str(wav), "wb") as handle:
            handle.setnchannels(clip.shape[1])
            handle.setsampwidth(2)
            handle.setframerate(rate)
            handle.writeframes((np.clip(clip, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libmp3lame", "-b:a", "192k", str(out)], check=True)
        report["clips"][name] = {"file": out.name, "integrated_lufs": round(weapon_sheet.integrated_lufs(clip, rate), 1),
                                 "true_peak_db": round(weapon_sheet.true_peak_db(clip, rate), 1),
                                 "short_term_max_lufs": round(weapon_sheet.short_term_max_lufs(clip, rate), 1)}
        print("%-28s %6.1f LUFS  TP %5.1f dBTP  -> %s" % (name, report["clips"][name]["integrated_lufs"],
                                                          report["clips"][name]["true_peak_db"], out.name))
    (folder / "clips.json").write_text(json.dumps(report, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
