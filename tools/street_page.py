#!/usr/bin/env python3
"""The Terminus streets, before and after (R4, round 10): one self-contained page for the lead.

    make remote T=terminus-streets    # the frames (needs a display)
    make terminus-streets-page        # build/terminus-streets/index.html

Each street he drives is shown at his pose (21 deg, FOV 35, 49 m) on the round-9 layout and on today's, with the
street's narrowest width on both, measured by the same lane table `make arena-report` prints and
`tests/test_arena_lanes.gd` asserts. One file with the images inlined, so it opens anywhere (round 6 lesson 12).
"""
import argparse
import html
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import arena_report as ar
from arena_page import shrink

BEFORE = ROOT / "tests" / "arena" / "before" / "terminus_round9.json"
AFTER = ROOT / "arenas" / "terminus.json"
## Which lane each frame shows (by lane name prefix), so its caption carries that lane's number.
FRAME_LANE = {"avenue": "the avenue", "west_street": "west street", "east_street": "west street (far)|east street",
              "ring_road": "the ring road", "ring_road_along": "the ring road", "plaza": "plaza crossing west",
              "junction_west": "west street"}

CSS = """
:root{--bg:#101217;--fg:#e8e8ea;--mute:#9aa0aa;--ok:#5ad17a;--bad:#ff6b5a;--card:#181b22}
@media (prefers-color-scheme: light){:root:not([data-theme=dark]){--bg:#f6f6f4;--fg:#15161a;--mute:#5a5f68;--card:#fff}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 system-ui,sans-serif}
.wrap{max-width:1400px;margin:0 auto;padding:16px}
h1{font-size:1.6em;margin:.2em 0}.sub{color:var(--mute)}
.pair{background:var(--card);border-radius:10px;padding:12px;margin:18px 0}
.pair h2{font-size:1.15em;margin:.1em 0 .5em}
.imgs{display:grid;grid-template-columns:1fr 1fr;gap:10px}
@media (max-width:760px){.imgs{grid-template-columns:1fr}}
figure{margin:0}figure img{width:100%;border-radius:6px;display:block}
figcaption{font-size:.9em;color:var(--mute);margin-top:4px}
.ok{color:var(--ok)}.bad{color:var(--bad)}
table{border-collapse:collapse;width:100%;font-size:.92em;background:var(--card);border-radius:10px;overflow:hidden}
th,td{padding:6px 10px;text-align:left;border-bottom:1px solid rgba(128,128,128,.2)}
.table-wrap{overflow-x:auto}
"""


def table(layout):
    ar.use_extent(layout)
    return ar.lane_table(layout, ar.boxes_of(layout))


def lane_number(tab, spec):
    for name in spec.split("|"):
        for lane in tab["lanes"]:
            if lane["name"] == name:
                return lane
    return None


def fmt(lane):
    if lane is None:
        return "not declared"
    tone = "ok" if lane["pass"] else "bad"
    return '<span class="%s">%.2f m physical, %.2f m drivable</span>' % (tone, lane["narrowest_physical_m"],
                                                                        lane["narrowest_drivable_m"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--shots", default="build/terminus-streets")
    parser.add_argument("--out", default="build/terminus-streets/index.html")
    parser.add_argument("--commit", default="")
    args = parser.parse_args()
    shots = ROOT / args.shots
    before, after = json.loads(BEFORE.read_text()), json.loads(AFTER.read_text())
    tb, ta = table(before), table(after)
    bar = ta["bar"]
    meta_path = shots / "after.json"
    frames = json.loads(meta_path.read_text())["frames"] if meta_path.exists() else []
    pairs, missing = [], []
    for frame in frames:
        key = frame["key"]
        b = shrink(shots / ("%s_before.jpg" % key), 1100)
        a = shrink(shots / ("%s_after.jpg" % key), 1100)
        if not (a and b):
            missing.append(key)
            continue
        spec = FRAME_LANE.get(key, "")
        pairs.append('<div class="pair"><h2>%s</h2><div class="imgs">'
                     '<figure><img src="%s" alt="%s, round 9"><figcaption><b>Before</b> (round 9 layout): %s</figcaption></figure>'
                     '<figure><img src="%s" alt="%s, now"><figcaption><b>After</b>: %s</figcaption></figure></div></div>'
                     % (html.escape(frame["label"]), b, html.escape(frame["label"]), fmt(lane_number(tb, spec)),
                        a, html.escape(frame["label"]), fmt(lane_number(ta, spec))))
    rows = []
    for lane in ta["lanes"]:
        old = lane_number(tb, lane["name"] if lane["name"] != "east street" else "west street (far)")
        rows.append("<tr><td>%s</td><td>%s</td><td>%s</td></tr>" % (html.escape(lane["name"]), fmt(old), fmt(lane)))
    corner_rows = "".join(
        "<tr><td>%s</td><td>%.0f&deg;</td><td>%.2f m</td><td class=\"%s\">%.2f m</td></tr>"
        % (html.escape(" x ".join(c["lanes"])), c["delta_deg"], c["r_eff_m"], "ok" if c["pass"] else "bad",
           c["clearance_m"]) for c in ta["corners"])
    page = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Terminus Streets</title><style>%s</style></head>
<body><div class="wrap"><h1>The Terminus streets, before and after</h1>
<p class="sub">You said the streets were blocked with shipping containers and there was almost no way through. The
containers, lamps and wrecks now stand at the kerbs and on the lots, parallel to the street, never across it. Every
street keeps room for two of the widest hull abreast (%s, %.2f m wide, so %.2f m of drivable road after the %.1f m
navmesh margin on each side), and a test fails the build if one stops doing so. Every frame is at your camera:
21&deg; pitch, 35&deg; field of view, 49 m. %s</p>
%s
<h2>Every street's narrowest point</h2><div class="table-wrap"><table><tr><th>street</th><th>round 9</th><th>now</th></tr>%s</table></div>
<h2>Every corner and junction, against the War Rig's turn</h2>
<p class="sub">The rig (minimum turning radius %.1f m) cuts inside a corner; the clear circle it needs is shown beside
the one each corner has.</p>
<div class="table-wrap"><table><tr><th>where</th><th>turn</th><th>rig needs</th><th>corner has</th></tr>%s</table></div>
</div></body></html>""" % (CSS, html.escape(bar["widest_hull"]), bar["widest_hull_m"], bar["drivable_bar_m"],
                          bar["bake_radius_m"], ("Built at " + html.escape(args.commit) + ".") if args.commit else "",
                          "".join(pairs) or '<p class="bad">No frames yet: run make remote T=terminus-streets.</p>',
                          "".join(rows), bar["rig_min_turn_m"], corner_rows)
    out = ROOT / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page)
    if missing:
        print("STREET_PAGE_MISSING %s" % ",".join(missing))
    print("STREET_PAGE %s (%d pairs, %.1f MB)" % (out, len(pairs), out.stat().st_size / 1e6))


if __name__ == "__main__":
    main()
