#!/usr/bin/env python3
"""look_parity.py -- is the picture unchanged? (render, round 16, R1; contract C16.6)

Compares two shot sets taken by `make look-parity-shots` (same file names in each) pixel by pixel and decides each
pair against a stated tolerance:

  * a pixel is CHANGED when any channel differs by more than --threshold (default 8 of 255);
  * a pair PASSES when the changed pixels are at most --max-share of the frame (default 0.5 %).

For every pair it writes a diff image to --out: the BEFORE frame dimmed to grey, with every changed pixel painted
red (brighter = a bigger difference), so a reviewer sees WHERE it changed, not just how much. The per-pair numbers
go to stdout as LOOK_PARITY_PAIR lines and to <out>/report.json. Exit 0 when every pair passes and both sets hold
the same frames; 1 otherwise (a frame missing from one side is a failure, never a skip).

Pillow only (no numpy): it runs on the laptop and on builder0 as they are.

  python3 tools/look_parity.py build/look-parity/before build/look-parity/after --out build/look-parity/diff
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageChops


def compare(before_path, after_path, threshold, diff_path):
    a = Image.open(before_path).convert("RGB")
    b = Image.open(after_path).convert("RGB")
    if a.size != b.size:
        return {"error": "size %s vs %s" % (a.size, b.size)}
    diff = ImageChops.difference(a, b)
    r, g, bl = diff.split()
    worst = ImageChops.lighter(ImageChops.lighter(r, g), bl)  # per-pixel max channel difference
    hist = worst.histogram()
    total = a.size[0] * a.size[1]
    changed = sum(hist[threshold + 1:])
    max_diff = max((i for i, n in enumerate(hist) if n), default=0)
    mean_diff = sum(i * n for i, n in enumerate(hist)) / float(total)
    if diff_path:
        mask = worst.point(lambda v: 255 if v > threshold else 0)
        base = a.convert("L").point(lambda v: v // 3).convert("RGB")
        red = Image.merge("RGB", (worst.point(lambda v: min(255, 96 + v * 4)), Image.new("L", a.size, 0),
                                  Image.new("L", a.size, 0)))
        Image.composite(red, base, mask).save(diff_path)
    return {"pixels": total, "changed": changed, "share": changed / float(total), "max": max_diff,
            "mean": round(mean_diff, 4)}


def pngs(root):
    """Every .png under root, as a path relative to it (sets are laid out <arena>-<res>/<pose>_t<tick>.png)."""
    found = []
    for folder, _dirs, files in os.walk(root):
        for f in files:
            if f.endswith(".png"):
                found.append(os.path.relpath(os.path.join(folder, f), root))
    return sorted(found)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("before")
    ap.add_argument("after")
    ap.add_argument("--out", default="", help="directory for diff images and report.json")
    ap.add_argument("--threshold", type=int, default=8, help="a channel difference above this marks a pixel changed")
    ap.add_argument("--max-share", type=float, default=0.005, help="changed-pixel share a pair may have and pass")
    args = ap.parse_args()

    names_a, names_b = pngs(args.before), pngs(args.after)
    if args.out:
        os.makedirs(args.out, exist_ok=True)
    pairs, failed = [], 0
    for name in sorted(set(names_a) | set(names_b)):
        if name not in names_a or name not in names_b:
            side = "before" if name not in names_a else "after"
            print("LOOK_PARITY_PAIR %s MISSING from %s" % (name, side))
            pairs.append({"name": name, "error": "missing from " + side, "pass": False})
            failed += 1
            continue
        diff_path = os.path.join(args.out, name.replace(os.sep, "__").replace(".png", "_diff.png")) if args.out else ""
        row = compare(os.path.join(args.before, name), os.path.join(args.after, name), args.threshold, diff_path)
        row["name"] = name
        row["pass"] = "error" not in row and row["share"] <= args.max_share
        failed += 0 if row["pass"] else 1
        pairs.append(row)
        if "error" in row:
            print("LOOK_PARITY_PAIR %s ERROR %s" % (name, row["error"]))
        else:
            print("LOOK_PARITY_PAIR %-44s %s changed %6.3f%% (%d px) max %3d mean %.3f" % (
                name, "PASS" if row["pass"] else "FAIL", row["share"] * 100.0, row["changed"], row["max"],
                row["mean"]))
    worst = max((p.get("share", 1.0) for p in pairs), default=0.0)
    verdict = "PASS" if failed == 0 and pairs else "FAIL"
    summary = {"before": args.before, "after": args.after, "threshold": args.threshold, "max_share": args.max_share,
               "pairs": len(pairs), "failed": failed, "worst_share": worst, "verdict": verdict}
    print("LOOK_PARITY %s pairs=%d failed=%d worst=%.3f%% (a pixel changes above %d/255; a pair passes at <= %.2f%%)" % (
        verdict, len(pairs), failed, worst * 100.0, args.threshold, args.max_share * 100.0))
    if args.out:
        with open(os.path.join(args.out, "report.json"), "w") as f:
            json.dump({"summary": summary, "pairs": pairs}, f, indent=1)
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
