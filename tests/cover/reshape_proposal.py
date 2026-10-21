#!/usr/bin/env python3
"""K5 (cover, round 37): a RE-SHAPE proposal per dealt map for the lead's before/after page -- nothing added, nothing
committed. Per map, the PAIRS lone clutter pieces (a single-level container_20 or a wreck, and its 180-degree mirror) that sit
in the hottest fighting (cover-heat's hull hits within HEAT_RADIUS_M, summed over the piece and its mirror) each become one
jersey barricade on the same spot, its long side square to the base axis (rotation 0 / 180: a crew behind it faces the
enemy's half).

    python3 tests/cover/reshape_proposal.py <heat.json> <out_dir> [--pairs 2]

Writes <out_dir>/<map>.json (the proposed layout) and <out_dir>/index.html (before | after, both from above, with the heat).
What a swap costs is stated on the page: a container is hard cover (it blocks sight); a barricade is not.
"""
import argparse, base64, copy, html, json, math, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cover_page  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
HEAT_RADIUS_M = 12.0
## A swap must sit where fighting happens: at least this many sampled hull hits near it and its mirror together.
MIN_HEAT = 50
## A container with another container this close is part of a run (a street wall): not lone clutter.
RUN_GAP_M = 4.0


def heat_near(cells, pos):
    total = 0
    for key, count in cells.items():
        x, z = (int(v) for v in key.split(","))
        if math.hypot(x * 10 + 5 - pos[0], z * 10 + 5 - pos[1]) <= HEAT_RADIUS_M:
            total += count
    return total


def propose(name, row, pairs):
    layout = json.load(open(ROOT / "arenas" / f"{name}.json"))
    cells = (row.get("heat") or {}).get("cells", {})
    props = layout.get("props", [])
    candidates = []
    for i, p in enumerate(props):
        lone = (p["type"] == "container_20" and int(p.get("stack", 1)) == 1) or p["type"] == "wreck"
        if not lone:
            continue
        x, z = p["position"]
        if p["type"] == "container_20" and any(q is not p and q["type"].startswith("container")
                                               and math.dist(q["position"], p["position"]) < 6.06 / 2 + RUN_GAP_M
                                               for q in props):
            continue
        if (x, z) < (-x, -z):  # each mirror pair once: keep the member with the larger (x, z)
            continue
        mirror = next((j for j, q in enumerate(props) if q["type"] == p["type"]
                       and abs(q["position"][0] + x) < 0.01 and abs(q["position"][1] + z) < 0.01), None)
        if mirror is None or mirror == i:
            continue
        heat = heat_near(cells, p["position"]) + heat_near(cells, props[mirror]["position"])
        if heat < MIN_HEAT:
            continue
        candidates.append((heat_near(cells, p["position"]) + heat_near(cells, props[mirror]["position"]), i, mirror))
    candidates.sort(key=lambda c: (-c[0], c[1]))
    after = copy.deepcopy(layout)
    swaps = []
    for heat, i, j in candidates[:pairs]:
        for k, rot in ((i, 0.0), (j, 180.0)):
            old = after["props"][k]
            after["props"][k] = {"type": "barricade", "position": old["position"], "rotation_deg": rot}
        swaps.append({"from": props[i]["type"], "at": props[i]["position"], "heat": heat})
    return layout, after, swaps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("heat")
    ap.add_argument("out")
    ap.add_argument("--pairs", type=int, default=2)
    args = ap.parse_args()
    report = json.load(open(args.heat))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    cards = []
    for name, row in report.items():
        before, after, swaps = propose(name, row, args.pairs)
        (out / f"{name}.json").write_text(json.dumps(after, indent=1))
        img_before = cover_page.plot(name, row)
        img_after = cover_page.plot(name, row, layout=after)
        if swaps:
            what = "; ".join(f"{s['from'].replace('_', ' ')} at ({s['at'][0]:.0f}, {s['at'][1]:.0f}) and its mirror"
                             f" ({s['heat']} hits near)" for s in swaps)
        else:
            what = "nothing to re-shape near the fighting (no lone wreck or single container where the fighting is)"
        cards.append(f"<section><h2>{html.escape(name)}</h2><div class='pair'><figure><img src='data:image/png;base64,"
                     f"{img_before}'><figcaption>today</figcaption></figure><figure><img src='data:image/png;base64,"
                     f"{img_after}'><figcaption>proposed</figcaption></figure></div><p>{html.escape(what)}</p></section>")
    page = f"""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Low cover re-shape</title><style>
:root{{--bg:#0f1014;--fg:#e8e8ea;--muted:#9aa0aa;--accent:#00ffd0}}
body{{background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,sans-serif;margin:0 auto;max-width:1100px;padding:16px}}
h1{{font-size:22px}} h2{{font-size:18px;margin:4px 0}} .key{{color:var(--muted)}}
section{{background:#181a20;border-radius:8px;padding:10px;margin-bottom:16px}}
.pair{{display:grid;grid-template-columns:1fr 1fr;gap:8px}} figure{{margin:0}} img{{width:100%;height:auto;border-radius:4px}}
figcaption{{color:var(--muted);text-align:center}} @media (max-width:640px){{.pair{{grid-template-columns:1fr}}}}
</style></head><body><h1>Proposed: low cover where the fighting is (round 37, K5 draft)</h1>
<p class="key">Nothing added: each change turns a lone wreck or single container (and its mirror) into a waist-high jersey
barrier on the same spot, facing the enemy. <b>The trade:</b> a container hides a crew completely; a barrier hides only the
lower part of its front, but the crew can shoot over it. Bright outline = low cover; red = where hulls were hit.</p>
{''.join(cards)}</body></html>"""
    (out / "index.html").write_text(page)
    print(f"reshape proposal: {out / 'index.html'} ({len(page) // 1024} KB)")


if __name__ == "__main__":
    main()
