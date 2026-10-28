#!/usr/bin/env python3
"""Round 43 (camera K5.1): where the camera looked in a match recording, second by second.

Reads the `cam` rows a MatchRecorder writes (C43.2) and prints one line per row: the match second, the shown yaw as a
compass word in HIS screen's terms (the direction the view looks), the yaw it was turning to, the pitch and distance,
the ground point, the mode, and TURN on a row written at an automatic turn's start. Recordings from before round 43
have no `cam` rows and say so.

    python3 tests/camera/camera_recording.py <recording.jsonl[.gz]> [--from S] [--to S]
"""
import argparse
import gzip
import json
import sys

# yaw 0 looks north (-Z); positive turns left (RtsCamera.yaw_facing): +90 looks west, -90 east.
WORDS = ["N", "NW", "W", "SW", "S", "SE", "E", "NE"]


def compass(yaw_deg: float) -> str:
    return WORDS[int(round((yaw_deg % 360.0) / 45.0)) % 8]


def rows(path: str):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as f:
        for line in f:
            line = line.strip()
            if line:
                yield json.loads(line)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("recording")
    ap.add_argument("--from", dest="start", type=float, default=0.0)
    ap.add_argument("--to", dest="end", type=float, default=1e9)
    args = ap.parse_args()
    rate = 30.0
    cams = []
    for r in rows(args.recording):
        if r.get("t") == "match":
            rate = float(r.get("tick_rate", 30))
        elif r.get("t") == "cam":
            cams.append(r)
    if not cams:
        print("no cam rows (a recording from before round 43, or a match with no camera)")
        return 1
    for r in cams:
        s = r["tick"] / rate
        if s < args.start or s > args.end:
            continue
        print("%7.1f s  look %-2s %6.1f  want %-2s %6.1f  pitch %4.1f  dist %5.1f  at (%6.1f, %6.1f)  %-8s %s" % (
            s, compass(r["yaw"]), r["yaw"], compass(r.get("want", r["yaw"])), r.get("want", r["yaw"]),
            r["pitch"], r["dist"], r["target"][0], r["target"][1], r["mode"], "TURN" if r.get("turn") else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
