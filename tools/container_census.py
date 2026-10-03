#!/usr/bin/env python3
"""Container census (yard, round 17, Y1): how square to the grid every layout's containers sit.

The lead (2026-10-03): *"in all cases they are completely aligned and completely orthogonal, and it looks completely
synthetic"*. This counts, per layout in `arenas/*.json`: containers, the share within `--square-tol` degrees of a
multiple of 90 (square to the grid), the distribution of how far off square the rest are, stacks and levels. It is
static (no Godot) and reads only the JSON, the single truth of where a container stands.

**It can fail.** `--max-square-share S` exits 1 when any layout in `--scope` (rotation: the maps `Arena.ROTATION` deals
him; shipping: every non-fixture layout; all) has more than S of its containers square. That is the regression that
matters: a future layout written with `c40(x, z, 0)` and no skew is the synthetic look coming back.

Usage: python3 tools/container_census.py arenas/*.json [--json out.json] [--max-square-share 0.25 --scope rotation]
       (or `make container-census`)"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gdscript_source

KINDS = ("container_20", "container_40")
## Degrees off square, as bins: [0, 0.5] reads as square; the rest are upper bounds.
BINS = (0.5, 1.0, 2.0, 3.0, 5.0, 10.0, 45.0)


def off_square(rotation_deg):
    """How far a yaw is from the nearest multiple of 90 degrees, in [0, 45]."""
    r = float(rotation_deg) % 90.0
    return min(r, 90.0 - r)


def census(layout, tol=0.5, kinds=KINDS):
    """The census of one layout dict: counts, square share, the off-square histogram, stacks and levels."""
    boxes = [p for p in layout.get("props", []) + layout.get("obstacles", []) if p.get("type") in kinds]
    offs = [off_square(p.get("rotation_deg", 0.0)) for p in boxes]
    hist = {}
    for off in offs:
        for edge in BINS:
            if off <= edge + 1e-9:
                key = "<=%g" % edge
                hist[key] = hist.get(key, 0) + 1
                break
    stacks = [max(1, int(p.get("stack", 1))) for p in boxes]
    levels = {}
    for s in stacks:
        levels[s] = levels.get(s, 0) + 1
    square = sum(1 for off in offs if off <= tol)
    return {
        "name": layout.get("name", "?"),
        "fixture": bool(layout.get("fixture", False)),
        "containers": len(boxes),
        "square": square,
        "square_share": round(square / len(boxes), 4) if boxes else 0.0,
        "mean_off_deg": round(sum(offs) / len(offs), 3) if offs else 0.0,
        "max_off_deg": round(max(offs), 3) if offs else 0.0,
        "off_hist": hist,
        "stacked": sum(1 for s in stacks if s > 1),
        "drawn": sum(stacks),
        "by_height": {str(k): v for k, v in sorted(levels.items())},
    }



def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("layouts", nargs="+")
    ap.add_argument("--json")
    ap.add_argument("--square-tol", type=float, default=0.5, help="degrees from a multiple of 90 that count as square")
    ap.add_argument("--max-square-share", type=float, help="fail when a layout in --scope is squarer than this")
    ap.add_argument("--types", help="comma-separated prop types to count instead of containers (stretch: the other props)")
    ap.add_argument("--scope", choices=("rotation", "shipping", "all"), default="rotation")
    args = ap.parse_args(argv)
    rotation = gdscript_source.const(gdscript_source.GAME / "arena" / "arena.gd", "ROTATION")
    rows = []
    for path in sorted(args.layouts):
        with open(path) as f:
            row = census(json.load(f), args.square_tol, tuple(args.types.split(",")) if args.types else KINDS)
        row["dealt"] = row["name"] in rotation
        rows.append(row)
    total = sum(r["containers"] for r in rows)
    square = sum(r["square"] for r in rows)
    for r in rows:
        if not r["containers"]:
            continue
        tag = "dealt" if r["dealt"] else ("fixture" if r["fixture"] else "cut")
        print("CONTAINER_CENSUS %-15s %-7s n=%3d square=%3d (%5.1f%%) mean_off=%5.2f max_off=%5.2f stacked=%3d drawn=%3d hist=%s"
              % (r["name"], tag, r["containers"], r["square"], 100 * r["square_share"], r["mean_off_deg"],
                 r["max_off_deg"], r["stacked"], r["drawn"], json.dumps(r["off_hist"], separators=(",", ":"))))
    print("CONTAINER_CENSUS_TOTAL layouts=%d containers=%d square=%d (%.1f%%) stacked=%d tol=%g"
          % (sum(1 for r in rows if r["containers"]), total, square, 100.0 * square / max(1, total),
             sum(r["stacked"] for r in rows), args.square_tol))
    if args.json:
        with open(args.json, "w") as f:
            json.dump({"tol_deg": args.square_tol, "layouts": rows, "containers": total, "square": square}, f, indent=1)
    if args.max_square_share is not None:
        def in_scope(r):
            return {"rotation": r["dealt"], "shipping": not r["fixture"], "all": True}[args.scope]
        bad = [r for r in rows if r["containers"] and in_scope(r) and r["square_share"] > args.max_square_share]
        for r in bad:
            print("CONTAINER_CENSUS_FAIL %s: %.1f%% of %d containers square (limit %.1f%%, scope %s)"
                  % (r["name"], 100 * r["square_share"], r["containers"], 100 * args.max_square_share, args.scope))
        if bad:
            return 1
        print("CONTAINER_CENSUS_OK no %s layout above %.1f%% square" % (args.scope, 100 * args.max_square_share))
    return 0


if __name__ == "__main__":
    sys.exit(main())
