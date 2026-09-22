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
:root{--ground:#f2f4f6;--surface:#ffffff;--ink:#141a21;--mute:#56616d;--line:#d9dee4;--accent:#0e8f9e;
--ok:#1f7a45;--short:#b8352b;color-scheme:light}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--ground:#0e1217;--surface:#161c23;--ink:#e6ebf0;
--mute:#98a4b1;--line:#27313b;--accent:#3fd6e4;--ok:#5cc98a;--short:#f07a6f;color-scheme:dark}}
:root[data-theme="dark"]{--ground:#0e1217;--surface:#161c23;--ink:#e6ebf0;--mute:#98a4b1;--line:#27313b;
--accent:#3fd6e4;--ok:#5cc98a;--short:#f07a6f;color-scheme:dark}
body{background:var(--ground);color:var(--ink);font:16px/1.55 "IBM Plex Sans",system-ui,sans-serif}
.wrap{max-width:1320px;margin:0 auto;padding-inline:16px;padding-block:24px 48px;display:grid;gap:28px}
h1,h2{font-family:"Barlow Condensed","Arial Narrow",sans-serif;font-weight:600;letter-spacing:.01em;text-wrap:balance;margin:0}
h1{font-size:2.3rem;line-height:1.1}h2{font-size:1.45rem}
.lede{max-width:68ch;color:var(--mute);margin:0}
.eyebrow{font:500 .78rem/1 "IBM Plex Mono",monospace;letter-spacing:.12em;text-transform:uppercase;color:var(--accent)}
.pair{display:grid;gap:10px}
.imgs{display:grid;grid-template-columns:1fr 1fr;gap:12px}
@media (max-width:760px){.imgs{grid-template-columns:1fr}}
figure{margin:0;display:grid;gap:6px}figure img{width:100%;max-width:100%;border-radius:4px;display:block;border:1px solid var(--line)}
figcaption{font-size:.9rem;color:var(--mute)}figcaption b{color:var(--ink)}
.num{font-family:"IBM Plex Mono",monospace;font-variant-numeric:tabular-nums}
.ok{color:var(--ok)}.bad{color:var(--short)}
.table-wrap{overflow-x:auto;border:1px solid var(--line);border-radius:4px;background:var(--surface)}
table{border-collapse:collapse;width:100%;font-size:.92rem}
th,td{padding:8px 12px;text-align:left;border-bottom:1px solid var(--line);white-space:nowrap}
th{font:500 .75rem/1.2 "IBM Plex Mono",monospace;letter-spacing:.08em;text-transform:uppercase;color:var(--mute)}
tr:last-child td{border-bottom:0}
section{display:grid;gap:12px}
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
    return '<span class="num %s">%.2f m physical, %.2f m drivable</span>' % (tone, lane["narrowest_physical_m"],
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
        pairs.append('<section class="pair"><h2>%s</h2><div class="imgs">'
                     '<figure><img src="%s" alt="%s, round 9"><figcaption><b>Before</b> (round 9 layout): %s</figcaption></figure>'
                     '<figure><img src="%s" alt="%s, now"><figcaption><b>After</b>: %s</figcaption></figure></div></section>'
                     % (html.escape(frame["label"]), b, html.escape(frame["label"]), fmt(lane_number(tb, spec)),
                        a, html.escape(frame["label"]), fmt(lane_number(ta, spec))))
    rows = []
    for lane in ta["lanes"]:
        old = lane_number(tb, lane["name"] if lane["name"] != "east street" else "west street (far)")
        rows.append("<tr><td>%s</td><td>%s</td><td>%s</td></tr>" % (html.escape(lane["name"]), fmt(old), fmt(lane)))
    corner_rows = "".join(
        "<tr><td>%s</td><td class=\"num\">%.0f&deg;</td><td class=\"num\">%.2f m</td><td class=\"num %s\">%.2f m</td></tr>"
        % (html.escape(" x ".join(c["lanes"])), c["delta_deg"], c["r_eff_m"], "ok" if c["pass"] else "bad",
           c["clearance_m"]) for c in ta["corners"])
    others = []
    for name in ar.lane_bar()["report_only"]:
        path = ROOT / "arenas" / (name + ".json")
        if not path.exists():
            continue
        tab = table(json.loads(path.read_text()))
        short = [l for l in tab["lanes"] if not l["pass"]]
        bent = [c for c in tab["corners"] if not c["pass"]]
        where = "; ".join("%s %.2f m at (%.0f, %.0f)" % (l["name"], l["narrowest_physical_m"], l["at"][0], l["at"][1])
                          for l in short) or "none"
        others.append("<tr><td>%s</td><td class=\"num\">%d of %d</td><td class=\"num\">%d of %d</td><td>%s</td></tr>"
                      % (html.escape(name), len(short), len(tab["lanes"]), len(bent), len(tab["corners"]), html.escape(where)))
    fonts = ('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600'
             '&family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;600&display=swap">')
    page = """<title>Terminus Streets</title>%s<style>%s</style>
<div class="wrap"><header style="display:grid;gap:10px"><div class="eyebrow">The Terminus &middot; round 10</div>
<h1>The streets, before and after</h1>
<p class="lede">You said the streets were blocked with shipping containers and there was almost no way through. The
containers, lamps and wrecks now stand at the kerbs and on the lots, parallel to the street, never across it. Every
street keeps room for two of the widest hull abreast (%s, <span class="num">%.2f m</span> wide: <span class="num">%.2f m</span>
of road after the <span class="num">%.1f m</span> navmesh margin each side), and a test fails the build if one stops
doing so. Every frame is at your camera: 21&deg; pitch, 35&deg; field of view, 49 m. %s</p></header>
%s
<section><h2>Every street's narrowest point</h2><div class="table-wrap"><table><tr><th>street</th><th>round 9</th><th>now</th></tr>%s</table></div></section>
<section><h2>Every corner and junction, against the War Rig's turn</h2>
<p class="lede">A hull turning through an angle &Delta;&psi; on its tightest circle cuts inside the corner, so it needs
a clear circle around the corner of radius <span class="num">r_eff = r_a + R&middot;(sec(&Delta;&psi;/2) &minus; 1)</span>:
R is the War Rig's minimum turning radius (<span class="num">%.1f m</span>), r_a is half the street-width bar. A
junction is certified for a right-angle turn; a street's own bend at its drawn angle. A corner passes when its
inscribed clearance (the distance to the nearest building, box or wall) is at least r_eff.</p>
<div class="table-wrap"><table><tr><th>where</th><th>&Delta;&psi;</th><th>r_eff (rig needs)</th><th>inscribed clearance</th></tr>%s</table></div></section>
<section><h2>The other maps (reported, not changed)</h2>
<p class="lede">The same test on the maps you have not complained about. A short lane there is a note for a later
round, not a change made without you.</p>
<div class="table-wrap"><table><tr><th>map</th><th>lanes short</th><th>corners short</th><th>where</th></tr>%s</table></div></section>
</div>""" % (fonts, CSS, html.escape(bar["widest_hull"]), bar["widest_hull_m"], bar["drivable_bar_m"],
                          bar["bake_radius_m"], ("Built at " + html.escape(args.commit) + ".") if args.commit else "",
                          "".join(pairs) or '<p class="bad">No frames yet: run make remote T=terminus-streets.</p>',
                          "".join(rows), bar["rig_min_turn_m"], corner_rows, "".join(others))
    out = ROOT / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page)
    if missing:
        print("STREET_PAGE_MISSING %s" % ",".join(missing))
    print("STREET_PAGE %s (%d pairs, %.1f MB)" % (out, len(pairs), out.stat().st_size / 1e6))


if __name__ == "__main__":
    main()
