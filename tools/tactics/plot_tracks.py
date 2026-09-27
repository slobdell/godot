#!/usr/bin/env python3
"""Round 12, S3: a top-down plot of a `make squad-settle ... TRACE=on` run: the arena's obstacles (boxes), each crew's
track (a colour per crew, a dot every 0.25 s, darker with time), the anchor's track, and the shape's stations at a few
moments. Usage: plot_tracks.py <settle log> <arena name> <out.png> [--until=S]
"""
import json
import math
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon

SIZES = {"container_20": (6.1, 2.5), "container_40": (12.2, 2.5), "barricade": (6.0, 1.0), "wreck": (6.0, 3.0)}


def main(log, arena, out, until=1e9):
    tracks = []
    for line in open(log):
        if line.startswith("SETTLE_TRACK "):
            row = json.loads(line.split(" ", 1)[1])
            if float(row["t"]) <= until:
                tracks.append(row)
    layout = json.load(open("arenas/%s.json" % arena))
    fig, ax = plt.subplots(figsize=(9, 9))
    xs = [p[0] for r in tracks for p in r["crews"].values()]
    zs = [p[1] for r in tracks for p in r["crews"].values()]
    pad = 15
    box = (min(xs) - pad, max(xs) + pad, min(zs) - pad, max(zs) + pad)
    for o in layout.get("obstacles", []) + layout.get("props", []):
        size = SIZES.get(o.get("type"))
        pos = o.get("position")
        if size is None or pos is None:
            continue
        x, z = pos[0], pos[-1]
        if not (box[0] - 10 < x < box[1] + 10 and box[2] - 10 < z < box[3] + 10):
            continue
        a = math.radians(-float(o.get("rotation_deg", 0.0)))
        w, d = size[0] / 2, size[1] / 2
        corners = [(x + cx * math.cos(a) - cz * math.sin(a), z + cx * math.sin(a) + cz * math.cos(a))
                   for cx, cz in ((-w, -d), (w, -d), (w, d), (-w, d))]
        ax.add_patch(Polygon(corners, closed=True, color="#888", alpha=0.6))
        ax.text(x, z, o["type"].replace("container_", "c"), fontsize=6, ha="center", va="center")
    colours = ["tab:blue", "tab:orange", "tab:green", "tab:red", "tab:purple", "tab:brown"]
    names = sorted({n for r in tracks for n in r["crews"]})
    for i, name in enumerate(names):
        pts = [(r["t"], r["crews"][name]) for r in tracks if name in r["crews"]]
        ax.plot([p[1][0] for p in pts], [p[1][1] for p in pts], "-", color=colours[i % 6], lw=1, label=name)
        for t, p in pts:
            if abs(t - round(t)) < 0.01:
                ax.text(p[0], p[1], "%d" % round(t), fontsize=6, color=colours[i % 6])
        for t, p in pts:
            if abs(t - round(t)) < 0.01 and round(t) % 2 == 0:
                ax.plot(p[0], p[1], "o", color=colours[i % 6], ms=3)
    anchor = [r["anchor"] for r in tracks if r["anchor"]]
    if anchor:
        ax.plot([p[0] for p in anchor], [p[1] for p in anchor], "k--", lw=0.8, label="anchor")
    ax.set_xlim(box[0], box[1])
    ax.set_ylim(box[3], box[2])  # -Z (forward for green) up
    ax.set_aspect("equal")
    ax.legend(fontsize=7)
    ax.set_title("%s (numbers: seconds; -Z up)" % log.split("/")[-1])
    fig.savefig(out, dpi=110)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    until = [float(a.split("=")[1]) for a in sys.argv[1:] if a.startswith("--until=")]
    main(args[0], args[1], args[2], until[0] if until else 1e9)
