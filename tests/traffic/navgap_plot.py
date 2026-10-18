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


def hulls(ax, trace_log, at_s):
    """Round 33 (X1): the hulls of a FAR_TRACE log (tests/traffic/far_census.gd) at second `at_s`, as boxes with a nose."""
    import math
    rows = {}
    for line in open(trace_log, errors="replace"):
        if line.startswith("FAR_TRACE "):
            r = json.loads(line[len("FAR_TRACE "):])
            if abs(r.get("s", -1) - at_s) < 0.26 and "at" in r:
                rows[r["unit"]] = r
    for name, r in rows.items():
        x, z = r["at"]
        w, length = r["box"]
        h = math.radians(r["hdg"])
        fx, fz = math.sin(h), -math.cos(h)  # heading 0 = north (-z); positive = clockwise seen from above
        rx, rz = -fz, fx
        ring = [(x + fx * length / 2 + rx * w / 2 * s, z + fz * length / 2 + rz * w / 2 * s) for s in (1, -1)]
        ring += [(x - fx * length / 2 + rx * w / 2 * s, z - fz * length / 2 + rz * w / 2 * s) for s in (-1, 1)]
        ax.add_patch(Polygon(ring, closed=True, facecolor="#31a354", edgecolor="k", lw=1, alpha=0.6))
        ax.plot([x, x + fx * length / 2], [z, z + fz * length / 2], "k-", lw=2)
        ax.text(x, z, "%s\n%s %s" % (name, r.get("phase", ""), r.get("verb", "")), fontsize=7, ha="center")
        if r.get("goal"):
            ax.annotate("", xy=r["goal"], xytext=(x, z), arrowprops=dict(arrowstyle="->", color="#31a354", lw=0.8))


def main(path, out, title="", trace_log="", at_s=0.0):
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
    if trace_log:
        hulls(ax, trace_log, at_s)
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
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "", sys.argv[4] if len(sys.argv) > 4 else "",
         float(sys.argv[5]) if len(sys.argv) > 5 else 0.0)
