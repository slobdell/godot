#!/usr/bin/env python3
"""K1 (cover, round 37): the lead's low-cover page -- every dealt map from above, its low cover drawn bright, where hulls
were hit (cover-heat) as a heat layer, and the numbers beside it. One self-contained HTML file (images inlined).

    python3 tests/cover/cover_page.py build/cover/heat.json build/cover-page/index.html [--title ...]

Reads the JSON `low_cover_census.py --heat` writes. North (-z) is at the top: green attacks upward.
"""
import argparse, base64, html, io, json, math, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import arena_terrain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OBSTACLE_SIZES = {"crate": [4.5, 3.0, 4.5], "wall": [18.0, 3.0, 1.5]}
KIT = {"container_20": [6.06, 2.59, 2.44], "container_40": [12.19, 2.59, 2.44], "ad_screen": [7.8, 1.4, 2.0],
       "barricade": [6.0, 0.9, 0.8], "wreck": [3.2, 2.0, 3.3], "floodlight": [2.4, 3.0, 2.4], "block": [40.0, 24.0, 40.0]}


def corners(pos, size, rot):
    a = math.radians(rot)
    ax, az = math.cos(a), -math.sin(a)        # local x in world (x, z)
    cx, cz = math.sin(a), math.cos(a)         # local z
    hx, hz = size[0] / 2, size[2] / 2
    return [(pos[0] + ax * sx * hx + cx * sz * hz, pos[1] + az * sx * hx + cz * sz * hz)
            for sx, sz in ((1, 1), (-1, 1), (-1, -1), (1, -1))]


def plot(name, row, layout=None):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Polygon, Rectangle
    if layout is None:
        layout = json.load(open(ROOT / "arenas" / f"{name}.json"))
    half = float(layout.get("half_size", 120.0))
    fig, ax = plt.subplots(figsize=(7, 7))
    ax.set_facecolor("#15161a")
    ax.add_patch(Rectangle((-half, -half), 2 * half, 2 * half, fill=False, ec="#888", lw=1.2))
    cells = (row.get("heat") or {}).get("cells", {})
    if cells:
        peak = max(cells.values())
        for key, count in cells.items():
            x, z = (int(v) for v in key.split(","))
            ax.add_patch(Rectangle((x * 10, z * 10), 10, 10, fc="#ff3030", ec="none", alpha=0.08 + 0.6 * count / peak,
                                   zorder=0.4))
    for t in layout.get("terrain", []):  # water blue, pits black, decks steel (arena_report's colours)
        x0, z0, x1, z1 = arena_terrain.bounds(t)
        ax.add_patch(Rectangle((x0, z0), x1 - x0, z1 - z0, fc={"water": "#1f6fb2", "pit": "#050505",
                               "bridge": "#8a8f98"}.get(t["kind"], "#555"), ec="none", alpha=0.9, zorder=0.5))
    for o in layout.get("obstacles", []):
        size = o.get("size", OBSTACLE_SIZES.get(o["type"], [1, 1, 1]))
        ax.add_patch(Polygon(corners(o["position"], size, float(o.get("rotation_deg", 0.0))), closed=True,
                             fc="#6b6b80", ec="black", lw=0.4))
    for p in layout.get("props", []):
        if p["type"] not in KIT:
            continue
        size = KIT[p["type"]]
        low = p["type"] == "barricade"
        ax.add_patch(Polygon(corners(p["position"], size, float(p.get("rotation_deg", 0.0))), closed=True,
                             fc="#00ffd0" if low else ("#7a5a3a" if p["type"] == "wreck" else "#5a5f6a"),
                             ec="#00ffd0" if low else "black", lw=2.5 if low else 0.4, zorder=3 if low else 2))
    for lane in layout.get("lanes", []):
        pts = lane["points"]
        ax.plot([q[0] for q in pts], [q[1] for q in pts], color="#ffd500", lw=0.8, alpha=0.5, ls="--")
    for src in row.get("reshape_sources", []):
        ax.plot(src["pos"][0], src["pos"][1], marker="o", mfc="none", mec="#b388ff", ms=9, mew=1.2)
    ax.set_xlim(-half - 2, half + 2)
    ax.set_ylim(half + 2, -half - 2)
    ax.set_aspect("equal")
    ax.set_xticks([])
    ax.set_yticks([])
    fig.tight_layout()
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=80)
    plt.close(fig)
    return base64.b64encode(buf.getvalue()).decode()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("out")
    ap.add_argument("--title", default="Low cover on every map (round 37, K1)")
    ap.add_argument("--note", default="")
    args = ap.parse_args()
    report = json.load(open(args.report))
    cards = []
    for name, row in report.items():
        heat = row.get("heat") or {}
        share = heat.get("beside_share")
        facts = [f"<b>{row['low_pieces']}</b> low pieces ({row['low_length_m']:.0f} m of jersey barrier), "
                 f"{row['frontal']} facing the enemy's half, {row['near_lane']} within 15 m of a lane"]
        if heat:
            facts.append(f"{heat['hull_hits']} hits on hulls in the sample; "
                         f"<b>{(share or 0) * 100:.1f}%</b> landed on a hull within 4 m of low cover")
        facts.append(f"{len(row['reshape_sources'])} lone wrecks / single containers within 20 m of a lane (circled)")
        cards.append(f"<section><h2>{html.escape(name)}</h2><img src='data:image/png;base64,{plot(name, row)}'>"
                     f"<ul>{''.join(f'<li>{f}</li>' for f in facts)}</ul></section>")
    page = f"""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Low cover census</title><style>
:root{{--bg:#0f1014;--fg:#e8e8ea;--muted:#9aa0aa;--accent:#00ffd0}}
body{{background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,sans-serif;margin:0 auto;max-width:1100px;padding:16px}}
h1{{font-size:22px}} h2{{font-size:18px;margin:4px 0}} .key{{color:var(--muted)}}
main{{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:16px}}
section{{background:#181a20;border-radius:8px;padding:10px}} img{{width:100%;height:auto;border-radius:4px}}
ul{{padding-left:18px;margin:6px 0}} b{{color:var(--accent)}}
</style></head><body><h1>{html.escape(args.title)}</h1>
<p class="key">Seen from above, north at the top. <b>Bright outline</b> = low cover (0.9 m jersey barriers, the only
waist-high cover in the game today). Red = where hulls were hit in sample fights. Circles = lone wrecks and single
containers near a lane that could be RE-SHAPED into low cover (nothing added). Yellow dashes = lanes.</p>
<p>{args.note}</p><main>{''.join(cards)}</main></body></html>"""
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(page)
    print(f"cover page: {args.out} ({len(page) // 1024} KB, {len(cards)} maps)")


if __name__ == "__main__":
    main()
