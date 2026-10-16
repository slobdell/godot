"""Round 32 (traffic, C32.6): draw tests/traffic/navgap_probe.gd's NAVGAP line, top-down.

The navmesh polygons (both regions: the baked half and its 180-degree mirror) filled, every navigation_source collision
box's footprint outlined, the box grown by the bake's agent radius dashed (where the baker carves), the spot and the
closest navmesh point to it marked.

    python3 tests/traffic/navgap_plot.py <navgap.json> <out.png> [title]
"""
import json
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Polygon, Rectangle  # noqa: E402


def main(path, out, title=""):
    d = json.load(open(path))
    sx, sz = d["spot"]
    r = d["bake"]["agent_radius"]
    fig, ax = plt.subplots(figsize=(8, 8))
    for ring in d["polys"]:
        ax.add_patch(Polygon(ring, closed=True, facecolor="#9ecae1", edgecolor="#3182bd", lw=0.6, alpha=0.8))
    for box in d["boxes"]:
        if box["size"][0] > 100:  # the ground slab
            continue
        xs = [p[0] for p in box["ring"]]
        zs = [p[1] for p in box["ring"]]
        ax.add_patch(Polygon(box["ring"], closed=True, facecolor="none", edgecolor="#d62728", lw=2))
        ax.add_patch(Rectangle((min(xs) - r, min(zs) - r), max(xs) - min(xs) + 2 * r, max(zs) - min(zs) + 2 * r,
                               facecolor="none", edgecolor="#d62728", lw=1, ls="--"))
        ax.text(sum(xs) / 4, sum(zs) / 4, box["name"].split("/")[-2], ha="center", va="center", fontsize=8,
                color="#d62728", clip_on=True)
    cx, _, cz, gap = d["closest"]
    ax.plot([sx], [sz], "k*", ms=14, label="spot (%.1f, %.1f)" % (sx, sz))
    ax.plot([cx], [cz], "o", color="#ff7f0e", ms=9, label="closest navmesh point, gap %.1f m" % gap)
    ax.plot([sx, cx], [sz, cz], color="#ff7f0e", lw=1)
    ax.set_xlim(sx - 16, sx + 16)
    ax.set_ylim(sz + 16, sz - 16)  # north (-z) up, as his default camera
    ax.set_aspect("equal")
    ax.set_xlabel("x (m)")
    ax.set_ylabel("z (m), north up")
    b = d["bake"]
    ax.set_title("%s\nbake: cell %.2f m, agent radius %.1f m, height %.2f, climb %.2f, source group '%s' (collision)"
                 % (title or d["arena"], b["cell_size"], b["agent_radius"], b["agent_height"], b["agent_max_climb"],
                    b["group"]), fontsize=9)
    ax.legend(loc="lower right", fontsize=8)
    ax.grid(True, lw=0.3)
    fig.savefig(out, dpi=110, bbox_inches="tight")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
