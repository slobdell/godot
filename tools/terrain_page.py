#!/usr/bin/env python3
"""The terrain maps' page for the lead (terrain, round 10, backlog 5): one self-contained HTML file.

For each terrain map: its title and note; every frame at his pose from `make terrain-shots`, WITH the same frame of
its dry twin beside it (the before/after pair, one variable moved: the water); the overview; and the numbers --
`arena_report`'s centre_sees and decision spread, the ring-of-eyes centre figure and the plain objective routes from
`terrain_measure`, and, if a series has run, the paired series summary. Wet and dry side by side everywhere.

Usage: terrain_page.py --shots build/terrain-shots --out build/terrain-page/index.html [--series build] crossing pits
"""
import argparse
import base64
import html
import json
import os
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import arena_report
import terrain_measure

CSS = """
:root { --bg:#0b0b12; --fg:#e8e8ee; --dim:#9a9aae; --cyan:#00f3ff; --mag:#ff0099; --card:#14141f; }
body { background:var(--bg); color:var(--fg); font:15px/1.5 system-ui, sans-serif; margin:0; padding:24px 16px; }
main { max-width:1500px; margin:0 auto; }
h1 { font-size:26px; margin:0 0 4px; } h2 { font-size:22px; margin:32px 0 4px; color:var(--cyan); }
p.note { color:var(--dim); max-width:900px; }
.pair { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin:14px 0; }
.pair figure { margin:0; background:var(--card); padding:6px; border-radius:6px; }
.pair img { width:100%; display:block; border-radius:3px; }
figcaption { color:var(--dim); font-size:13px; padding:4px 2px 0; }
table { border-collapse:collapse; margin:10px 0; } td, th { padding:4px 12px; border-bottom:1px solid #2a2a3a; text-align:left; }
th { color:var(--dim); font-weight:500; } .wet { color:var(--cyan); } .dry { color:var(--dim); }
@media (max-width:800px) { .pair { grid-template-columns:1fr; } }
"""


def img(path):
    if not path.exists():
        return "<p class='note'>(missing: %s)</p>" % html.escape(str(path))
    data = base64.b64encode(path.read_bytes()).decode()
    return "<img alt='%s' src='data:image/png;base64,%s'>" % (html.escape(path.name), data)


DRY = {"terminus_canal": "terminus"}


def numbers(name):
    rows = []
    for variant in (name, DRY.get(name, name + "_dry")):
        layout = json.load(open(HERE.parent / "arenas" / (variant + ".json")))
        report = arena_report.analyze(layout)
        measured = terrain_measure.measure(layout)
        routes = measured["objective_routes_plain"]
        contested = next((v for k, v in routes.items() if not k.endswith("(far)")), {})
        rows.append((variant, report["ambush"]["centre_sees_share"], measured["centre_ring_sees_mean"],
                     report["ambush"]["decision"]["decision_spread"], contested.get("green_m"), contested.get("rust_m")))
    out = ["<table><tr><th>arm</th><th>centre sees (report)</th><th>centre, ring of eyes</th><th>decision spread</th>"
           "<th>contested objective: green's route</th><th>rust's route</th></tr>"]
    for variant, c, ring, spread, g, r in rows:
        klass = "wet" if variant == rows[0][0] else "dry"
        out.append("<tr class='%s'><td>%s</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%s m</td><td>%s m</td></tr>"
                   % (klass, variant, c, ring, spread, g, r))
    out.append("</table>")
    return "".join(out)


def series(name, folder):
    path = pathlib.Path(folder) / ("terrain-series-%s.json" % name)
    if not path.exists():
        return "<p class='note'>Paired series: not run yet (<code>make remote T=\"terrain-series TERRAIN_MAP=%s\"</code>).</p>" % name
    data = json.load(open(path))
    arms = data["arms"]
    p = data["paired"]
    out = ["<p>Paired series, seeds %d-%d (%s, budget %s, %ss): the same matches with and without the water.</p>"
           % (data["seeds"][0], data["seeds"][-1], data["faction"], data["budget"], data["time_limit"]),
           "<table><tr><th>measure</th><th class='wet'>%s</th><th class='dry'>%s</th><th>seeds wet &gt; dry</th>"
           "<th>wet &lt; dry</th><th>sign test p</th></tr>" % (name, name + "_dry")]
    for key, label in (("crossing_share", "unit-time on the crossings"), ("contested_share", "time at the contested objective"),
                       ("hits", "hits")):
        out.append("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>"
                   % (label, arms[name][key], arms[name + "_dry"][key], p[key]["wet_higher"], p[key]["dry_higher"],
                      p[key]["sign_test_p"]))
    out.append("</table><p class='note'>Winner changed between the arms on %d of %d seeds.</p>" % (data["winner_flips"], len(data["seeds"])))
    return "".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("maps", nargs="+")
    ap.add_argument("--shots", default="build/terrain-shots")
    ap.add_argument("--series", default="build")
    ap.add_argument("--out", default="build/terrain-page/index.html")
    args = ap.parse_args()
    arena_report.WATCHER_REACH_M.update(arena_report.load_reach())
    shots = pathlib.Path(args.shots)
    parts = ["<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
             "<title>Terrain Maps</title><style>%s</style></head><body><main>" % CSS,
             "<h1>Water, pits and bridges</h1><p class='note'>Every frame is at your pose (21°, FOV 35, 49 m). "
             "Left: the map. Right: the same map with the water taken out, same camera, same hulls. "
             "The numbers put each map beside the same dry twin.</p>"]
    for name in args.maps:
        layout = json.load(open(HERE.parent / "arenas" / (name + ".json")))
        parts.append("<h2>%s</h2><p class='note'>%s</p>" % (html.escape(layout.get("title", name)), html.escape(layout.get("note", ""))))
        parts.append(numbers(name))
        parts.append(series(name, args.series))
        dry = DRY.get(name, name + "_dry")
        spots = sorted({p.name[len(name) + 1:-4] for p in shots.glob(name + "-*.png")
                        if not p.name.startswith(name + "_")})
        for spot in spots:
            parts.append("<div class='pair'><figure>%s<figcaption>%s: %s</figcaption></figure><figure>%s<figcaption>%s: %s (before)</figcaption></figure></div>"
                         % (img(shots / ("%s-%s.png" % (name, spot))), name, spot,
                            img(shots / ("%s-%s.png" % (dry, spot))), dry, spot))
    parts.append("</main></body></html>")
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    pathlib.Path(args.out).write_text("".join(parts))
    print("TERRAIN_PAGE", args.out)


if __name__ == "__main__":
    main()
