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


def speaking_window(mix: np.ndarray, booth: np.ndarray, rate: int, seconds: float, skip_s: float = 10.0) -> int:
    """The booth item's window: where the caller speaks most over the loudest fight (booth activity x mix loudness)."""
    hop = int(0.1 * rate)
    n = min(len(mix), len(booth)) // hop
    level = lambda x: 20 * np.log10(np.maximum(np.sqrt((weapon_sheet.mono(x)[: n * hop].reshape(n, hop) ** 2).mean(axis=1)), 1e-9))
    b, m = level(booth), level(mix)
    score = (b > b.max() - 20.0) * (10 ** (m / 20))
    width = int(seconds * 10)
    sums = np.convolve(score, np.ones(width), mode="valid")
    start = int(skip_s * 10)
    return (start + int(np.argmax(sums[start:]))) * hop if len(sums) > start else 0


def cut(fight: Path, start: int, seconds: float, folder: Path) -> dict:
    import wave
    y, rate = weapon_sheet.read(fight)
    clip = y[start: start + int(seconds * rate)]
    name = fight.stem.replace("fight_", "")
    out = folder / ("clip_%s.mp3" % name)
    wav = folder / ("clip_%s.wav" % name)
    with wave.open(str(wav), "wb") as handle:
        handle.setnchannels(clip.shape[1])
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes((np.clip(clip, -1, 1) * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libmp3lame", "-b:a", "192k", str(out)], check=True)
    row = {"file": out.name, "start_s": round(start / rate, 1), "seconds": seconds,
           "integrated_lufs": round(weapon_sheet.integrated_lufs(clip, rate), 1),
           "true_peak_db": round(weapon_sheet.true_peak_db(clip, rate), 1),
           "short_term_max_lufs": round(weapon_sheet.short_term_max_lufs(clip, rate), 1)}
    print("%-16s %6.1f LUFS  TP %5.1f dBTP  at %5.1f s -> %s" % (name, row["integrated_lufs"], row["true_peak_db"], row["start_s"], out.name))
    return row


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--seconds", type=float, default=15.0)
    parser.add_argument("--reference", default="")
    args = parser.parse_args(argv)
    folder = Path(args.folder)
    fights = sorted(f for f in folder.glob("fight_*.wav") if f.stem.count(".") == 0)
    if not fights:
        print("no fight_*.wav in %s" % folder)
        return 1
    reference = folder / args.reference if args.reference else next((f for f in fights if f.stem.endswith("~0")), fights[0])
    x, rate = weapon_sheet.read(reference)
    start = loudest_window(x, rate, args.seconds)
    report = {"window_s": [round(start / rate, 1), round(start / rate + args.seconds, 1)], "reference": reference.name, "clips": {}}
    ducks = [f for f in fights if f.stem.startswith("fight_duck_")]
    duck_start = None
    booth = folder / "fight_duck_launch.booth.wav"
    if ducks and booth.exists():
        mix, rate = weapon_sheet.read(folder / "fight_duck_launch.wav")
        duck_start = speaking_window(mix, weapon_sheet.read(booth)[0], rate, 20.0)
        report["duck_window_s"] = [round(duck_start / rate, 1), round(duck_start / rate + 20.0, 1)]
    music = [f for f in fights if f.stem.startswith("fight_music_")]
    music_start = None
    if music and (folder / "fight_music_now.wav").exists():
        mx, rate = weapon_sheet.read(folder / "fight_music_now.wav")
        music_start = loudest_window(mx, rate, 20.0)
        report["music_window_s"] = [round(music_start / rate, 1), round(music_start / rate + 20.0, 1)]
    for fight in fights:
        if fight in music and music_start is not None:
            report["clips"][fight.stem.replace("fight_", "")] = cut(fight, music_start, 20.0, folder)
            continue
        if fight in ducks and duck_start is not None:
            report["clips"][fight.stem.replace("fight_", "")] = cut(fight, duck_start, 20.0, folder)
        else:
            report["clips"][fight.stem.replace("fight_", "")] = cut(fight, start, args.seconds, folder)
    (folder / "clips.json").write_text(json.dumps(report, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
