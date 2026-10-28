#!/usr/bin/env python3
"""Round 43 (camera K5, C43.6): the corner swing reads no unseen enemy.

Bar K5's no-fog-cheat line: the same corner lanes run twice, the hidden squad parked behind the wall (WITH) and not staged
at all (`--camera-corner-hidden=off`, WITHOUT). CameraCorner writes every frame's [frame, tick, shown yaw, wanted yaw,
known enemies] to camera_yaw_<seed>.jsonl. Up to the first frame EITHER run knows any enemy, the two yaw columns must be
identical to the last digit: the camera cannot have reacted to something his team had not seen.

    python3 tests/camera/corner_nocheat.py <with dir> <without dir>     exit 0 = identical on every seed
"""
import glob
import json
import os
import sys


def rows(path):
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    with_dir, without_dir = sys.argv[1:]
    bad = 0
    seeds = 0
    print("| seed | frames compared (until an enemy is known) | first differing frame |")
    print("|---|---|---|")
    for path in sorted(glob.glob(os.path.join(with_dir, "camera_yaw_*.jsonl"))):
        name = os.path.basename(path)
        other = os.path.join(without_dir, name)
        if not os.path.exists(other):
            continue
        a, b = rows(path), rows(other)
        seeds += 1
        compared = 0
        differ = None
        for ra, rb in zip(a, b):
            if ra[4] > 0 or rb[4] > 0:
                break
            if ra[:4] != rb[:4]:
                differ = ra[0]
                break
            compared += 1
        if differ is not None:
            bad += 1
        print(f"| {name[11:-6]} | {compared} | {differ if differ is not None else '-'} |")
    print(f"NOCHEAT seeds={seeds} differing={bad} {'PASS' if seeds and not bad else 'FAIL'}")
    return 0 if seeds and not bad else 1


if __name__ == "__main__":
    sys.exit(main())
