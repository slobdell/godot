#!/usr/bin/env python3
"""The web's voice set: every announcer clip re-encoded at the lead's chosen web bitrate (ship, round 17).

Usage: voice_web.py <clips_dir> <out_dir> [--kbps 24] [--rate 22050] [--jobs N]

The lead tapped 24k on the W2 page (Q2, 2026-10-03 21:13:46 UTC): the browser fetches the clips at 24 kbit/s, mono,
22.05 kHz; the desktop keeps them as recorded (Q4). The source is the AS-RECORDED clip set (assets/announcer/clips,
itself cut from the git-ignored masters), so this can be regenerated any time from what is in the repo:

    ffmpeg -i <clip.ogg> -ac 1 -ar 22050 -c:a libvorbis -b:a 24k <out.ogg>

Incremental: a clip is re-encoded only when its output is missing or older than its source, so the first run costs
a few minutes and every later export seconds. manifest.json is copied as is (a clip's duration does not change).
Prints one VOICE_WEB line: clips, MB, how many encoded this run.
"""
import argparse
import concurrent.futures
import os
import shutil
import subprocess
import sys


def encode(src, dst, kbps, rate):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    tmp = dst + ".part.ogg"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-ac", "1", "-ar", str(rate), "-c:a", "libvorbis",
                    "-b:a", f"{kbps}k", tmp], check=True)
    os.replace(tmp, dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("clips")
    ap.add_argument("out")
    ap.add_argument("--kbps", type=int, default=24)
    ap.add_argument("--rate", type=int, default=22050)
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    a = ap.parse_args()
    if shutil.which("ffmpeg") is None:
        sys.exit("voice_web: ffmpeg is not installed (it is on the laptop and builder0)")
    todo, total = [], 0
    for dirpath, _dirs, files in os.walk(a.clips):
        for name in files:
            if not name.endswith(".ogg"):
                continue
            src = os.path.join(dirpath, name)
            dst = os.path.join(a.out, os.path.relpath(src, a.clips))
            total += 1
            if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(src):
                todo.append((src, dst))
    with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
        list(pool.map(lambda job: encode(job[0], job[1], a.kbps, a.rate), todo))
    os.makedirs(a.out, exist_ok=True)
    shutil.copy2(os.path.join(a.clips, "manifest.json"), os.path.join(a.out, "manifest.json"))
    size = sum(os.path.getsize(os.path.join(d, f)) for d, _s, fs in os.walk(a.out) for f in fs if f.endswith(".ogg"))
    print(f"VOICE_WEB {total} clips at {a.kbps} kbit/s {a.rate} Hz mono, {size / 1e6:.1f} MB, {len(todo)} encoded this run -> {a.out}")


if __name__ == "__main__":
    main()
